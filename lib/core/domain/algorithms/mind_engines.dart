// Pure-Dart engines for the Brain & Mind section (Doc 09 §8 ALG-AUD-10/11/12,
// §9 ALG-MOV-06..09). No Flutter imports; unit-tested in
// test/mind_engines_test.dart.
import 'dart:math' as math;

import '../entities/mind_protocol.dart';
import 'fft.dart';

typedef Pt2 = ({double x, double y});

// ---------------------------------------------------------------------------
// Acoustic features from PCM16 (AUD-06-style voice features, CAP-13 quality)
// ---------------------------------------------------------------------------

class VoiceFeatures {
  const VoiceFeatures({
    required this.durationS,
    required this.speechTimeS,
    required this.voicedRatio,
    required this.pauseCount,
    required this.pauseRatePerMin,
    required this.syllablesPerSec,
    required this.speechRateWpmProxy,
    required this.meanF0Hz,
    required this.f0SdHz,
    required this.jitterPct,
    required this.shimmerPct,
    required this.spectralCentroidHz,
    required this.hnrDb,
    required this.rmsDbfs,
    required this.noiseFloorDbfs,
    required this.snrDb,
    required this.clipPct,
  });

  final double durationS;
  final double speechTimeS;
  final double voicedRatio;

  /// Silent pauses longer than [longPauseS] inside the speech span.
  final int pauseCount;
  final double pauseRatePerMin;
  final double syllablesPerSec;

  /// ≈ syllables / 1.5 per word (stand-in when no transcript exists).
  final double speechRateWpmProxy;
  final double meanF0Hz;
  final double f0SdHz;
  final double jitterPct;
  final double shimmerPct;
  final double spectralCentroidHz;
  final double hnrDb;
  final double rmsDbfs;
  final double noiseFloorDbfs;
  final double snrDb;
  final double clipPct;

  static const double longPauseS = 2.0; // Spec §8 AUD-10
  static const double maxClipPct = 1.0; // CAP-13
  static const double minSnrDb = 15.0; // CAP-13

  bool get qualityOk => clipPct <= maxClipPct && snrDb >= minSnrDb;
  bool get heardSpeech => speechTimeS >= 1.0;

  /// Feature vector for the HF personal baseline (AUD-12).
  List<double> get hfVector => [
    meanF0Hz,
    jitterPct,
    shimmerPct,
    spectralCentroidHz,
    hnrDb,
    1 - voicedRatio,
  ];

  static const List<String> hfVectorNames = [
    'pitch',
    'jitter',
    'shimmer',
    'spectral centroid',
    'harmonic ratio',
    'pause share',
  ];

  /// 25 ms frames, 10 ms hop. Energy-based voicing, autocorrelation pitch
  /// (80–400 Hz), spectral centroid on 512-point frames.
  static VoiceFeatures extract(List<int> samples, int sampleRate) {
    final n = samples.length;
    final frameLen = (0.025 * sampleRate).round();
    final hop = (0.010 * sampleRate).round();
    if (n < frameLen * 4) {
      return const VoiceFeatures(
        durationS: 0,
        speechTimeS: 0,
        voicedRatio: 0,
        pauseCount: 0,
        pauseRatePerMin: 0,
        syllablesPerSec: 0,
        speechRateWpmProxy: 0,
        meanF0Hz: 0,
        f0SdHz: 0,
        jitterPct: 0,
        shimmerPct: 0,
        spectralCentroidHz: 0,
        hnrDb: 0,
        rmsDbfs: -96,
        noiseFloorDbfs: -96,
        snrDb: 0,
        clipPct: 0,
      );
    }
    final frames = (n - frameLen) ~/ hop + 1;
    final rms = List<double>.filled(frames, 0);
    var clipped = 0;
    for (var i = 0; i < n; i++) {
      if (samples[i].abs() >= 32700) clipped++;
    }
    for (var f = 0; f < frames; f++) {
      var acc = 0.0;
      final off = f * hop;
      for (var i = 0; i < frameLen; i++) {
        final v = samples[off + i].toDouble();
        acc += v * v;
      }
      rms[f] = math.sqrt(acc / frameLen);
    }
    double db(double r) => 20 * math.log(math.max(r, 1e-3) / 32768) / math.ln10;
    final sortedDb = rms.map(db).toList()..sort();
    final noiseFloor = sortedDb[(sortedDb.length * 0.10).floor()];
    final peakDb = sortedDb[(sortedDb.length * 0.95).floor()];
    // voiced: 12 dB above the floor and at least a third of the way to the
    // peak; also an absolute floor so silence never counts.
    final thresh = math.max(
      noiseFloor + 12,
      noiseFloor + (peakDb - noiseFloor) * 0.35,
    );
    final voiced = List<bool>.filled(frames, false);
    for (var f = 0; f < frames; f++) {
      final d = db(rms[f]);
      voiced[f] = d > thresh && d > -55;
    }
    // smooth: fill single-frame gaps
    for (var f = 1; f < frames - 1; f++) {
      if (!voiced[f] && voiced[f - 1] && voiced[f + 1]) voiced[f] = true;
    }
    var first = -1, last = -1;
    for (var f = 0; f < frames; f++) {
      if (voiced[f]) {
        if (first < 0) first = f;
        last = f;
      }
    }
    final hopS = hop / sampleRate;
    final durationS = n / sampleRate;
    if (first < 0) {
      return VoiceFeatures(
        durationS: durationS,
        speechTimeS: 0,
        voicedRatio: 0,
        pauseCount: 0,
        pauseRatePerMin: 0,
        syllablesPerSec: 0,
        speechRateWpmProxy: 0,
        meanF0Hz: 0,
        f0SdHz: 0,
        jitterPct: 0,
        shimmerPct: 0,
        spectralCentroidHz: 0,
        hnrDb: 0,
        rmsDbfs: noiseFloor,
        noiseFloorDbfs: noiseFloor,
        snrDb: 0,
        clipPct: clipped * 100 / n,
      );
    }
    // pauses > 2 s inside the speech span
    var pauses = 0;
    var run = 0;
    var voicedFrames = 0;
    for (var f = first; f <= last; f++) {
      if (voiced[f]) {
        voicedFrames++;
        if (run * hopS >= longPauseS) pauses++;
        run = 0;
      } else {
        run++;
      }
    }
    final spanS = (last - first + 1) * hopS;
    final speechTimeS = voicedFrames * hopS;
    // syllable nuclei: energy peaks ≥ 100 ms apart on a 5-frame envelope
    final env = List<double>.filled(frames, 0);
    for (var f = 0; f < frames; f++) {
      var s = 0.0;
      var c = 0;
      for (var k = -2; k <= 2; k++) {
        if (f + k >= 0 && f + k < frames) {
          s += rms[f + k];
          c++;
        }
      }
      env[f] = s / c;
    }
    var syllables = 0;
    var lastPeak = -100;
    for (var f = 1; f < frames - 1; f++) {
      if (voiced[f] &&
          env[f] > env[f - 1] &&
          env[f] >= env[f + 1] &&
          f - lastPeak >= 10) {
        syllables++;
        lastPeak = f;
      }
    }
    final sylPerSec = speechTimeS > 0 ? syllables / speechTimeS : 0.0;
    // pitch: autocorrelation on voiced frames (every 2nd), 40 ms window
    final win = (0.040 * sampleRate).round();
    final minLag = (sampleRate / 400).round();
    final maxLag = (sampleRate / 80).round();
    final f0s = <double>[];
    final r0s = <double>[];
    final ampl = <double>[];
    final centroids = <double>[];
    final fftN = 512;
    for (var f = first; f <= last; f += 2) {
      if (!voiced[f]) continue;
      final off = f * hop;
      if (off + win > n) break;
      var e0 = 0.0;
      for (var i = 0; i < win; i++) {
        final v = samples[off + i].toDouble();
        e0 += v * v;
      }
      if (e0 <= 0) continue;
      var bestR = 0.0;
      var bestLag = 0;
      for (var lag = minLag; lag <= maxLag; lag++) {
        var acc = 0.0;
        for (var i = 0; i + lag < win; i++) {
          acc += samples[off + i] * samples[off + i + lag].toDouble();
        }
        final r = acc / e0;
        if (r > bestR) {
          bestR = r;
          bestLag = lag;
        }
      }
      if (bestLag > 0 && bestR > 0.3) {
        f0s.add(sampleRate / bestLag);
        r0s.add(bestR.clamp(0.0, 0.999));
        ampl.add(rms[f]);
      }
      if (off + fftN <= n && centroids.length < 400) {
        final frame = [
          for (var i = 0; i < fftN; i++) samples[off + i].toDouble(),
        ];
        final ps = Fft.powerSpectrum(frame);
        var num = 0.0, den = 0.0;
        for (var k = 1; k < ps.length; k++) {
          final hz = k * sampleRate / fftN;
          if (hz > 5000) break;
          num += hz * ps[k];
          den += ps[k];
        }
        if (den > 0) centroids.add(num / den);
      }
    }
    double mean(List<double> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
    double sd(List<double> xs) {
      if (xs.length < 2) return 0;
      final m = mean(xs);
      return math.sqrt(
        xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) /
            (xs.length - 1),
      );
    }

    final meanF0 = mean(f0s);
    var jitter = 0.0, shimmer = 0.0;
    if (f0s.length >= 3) {
      var dj = 0.0, ds = 0.0;
      for (var i = 1; i < f0s.length; i++) {
        dj += (1 / f0s[i] - 1 / f0s[i - 1]).abs();
        ds += (ampl[i] - ampl[i - 1]).abs();
      }
      final meanPeriod = mean(f0s.map((f) => 1 / f).toList());
      jitter = meanPeriod > 0 ? dj / (f0s.length - 1) / meanPeriod * 100 : 0;
      final meanAmp = mean(ampl);
      shimmer = meanAmp > 0 ? ds / (f0s.length - 1) / meanAmp * 100 : 0;
    }
    final r = mean(r0s);
    final hnr = r > 0 && r < 1 ? 10 * math.log(r / (1 - r)) / math.ln10 : 0.0;
    final voicedDb = [
      for (var f = 0; f < frames; f++)
        if (voiced[f]) db(rms[f]),
    ];
    final meanVoicedDb = mean(voicedDb);
    return VoiceFeatures(
      durationS: durationS,
      speechTimeS: speechTimeS,
      voicedRatio: spanS > 0 ? (speechTimeS / spanS).clamp(0, 1) : 0,
      pauseCount: pauses,
      pauseRatePerMin: spanS > 0 ? pauses / (spanS / 60) : 0,
      syllablesPerSec: sylPerSec,
      speechRateWpmProxy: sylPerSec * 60 / 1.5,
      meanF0Hz: meanF0,
      f0SdHz: sd(f0s),
      jitterPct: jitter,
      shimmerPct: shimmer,
      spectralCentroidHz: mean(centroids),
      hnrDb: hnr,
      rmsDbfs: meanVoicedDb,
      noiseFloorDbfs: noiseFloor,
      snrDb: meanVoicedDb - noiseFloor,
      clipPct: clipped * 100 / n,
    );
  }
}

// ---------------------------------------------------------------------------
// Transcript metrics (AUD-10): rate, pauses from partial-result timing, TTR
// ---------------------------------------------------------------------------

/// A speech-recognition partial result: cumulative word count at [tSeconds].
class TimedWords {
  const TimedWords(this.tSeconds, this.wordCount);
  final double tSeconds;
  final int wordCount;
}

class TranscriptMetrics {
  const TranscriptMetrics({
    required this.tokens,
    required this.totalWords,
    required this.uniqueWords,
    required this.wordsPerMin,
    required this.longPauses,
    required this.pauseRatePerMin,
    required this.lexicalDiversity,
    required this.activeSeconds,
  });

  final List<String> tokens;
  final int totalWords;
  final int uniqueWords;
  final double wordsPerMin;
  final int longPauses;
  final double pauseRatePerMin;
  final double lexicalDiversity;
  final double activeSeconds;
}

class TranscriptAnalysis {
  TranscriptAnalysis._();

  static final RegExp _split = RegExp(r'''[\s,.;:!?\-–—()\[\]"'।॥]+''');

  static List<String> tokenize(String text) => text
      .toLowerCase()
      .split(_split)
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  static TranscriptMetrics analyze({
    required String finalText,
    required List<TimedWords> partials,
    required double durationS,
  }) {
    final tokens = tokenize(finalText);
    final total = tokens.length;
    final unique = tokens.toSet().length;
    // time between the first and last word growth
    double? firstT, lastT;
    var pauses = 0;
    var prevT = 0.0;
    var prevCount = 0;
    for (final p in partials) {
      if (p.wordCount > prevCount) {
        if (firstT != null && p.tSeconds - prevT > VoiceFeatures.longPauseS) {
          pauses++;
        }
        firstT ??= p.tSeconds;
        lastT = p.tSeconds;
        prevT = p.tSeconds;
        prevCount = p.wordCount;
      }
    }
    // trailing silence counts when the task ran to the end
    if (lastT != null && durationS - lastT > VoiceFeatures.longPauseS) pauses++;
    final active = firstT == null || lastT == null
        ? durationS
        : math.max(lastT - firstT, 1.0);
    final span = firstT == null ? durationS : math.max(durationS - firstT, 1.0);
    return TranscriptMetrics(
      tokens: tokens,
      totalWords: total,
      uniqueWords: unique,
      wordsPerMin: total / (active / 60),
      longPauses: pauses,
      pauseRatePerMin: pauses / (span / 60),
      lexicalDiversity: total == 0 ? 0 : unique / total,
      activeSeconds: active,
    );
  }
}

class FluencyResult {
  const FluencyResult({
    required this.valid,
    required this.repetitions,
    required this.intrusions,
  });

  final List<String> valid;
  final int repetitions;
  final int intrusions;
  int get count => valid.length;
}

/// Semantic verbal fluency: unique animals from the word lists [DER], with
/// plural stripping and two-word names.
class FluencyScorer {
  FluencyScorer._();

  static String _singular(String w) {
    if (w.length > 4 && w.endsWith('ies')) {
      return '${w.substring(0, w.length - 3)}y';
    }
    if (w.length > 3 && (w.endsWith('es') && !w.endsWith('ses'))) {
      final base = w.substring(0, w.length - 2);
      if (base.endsWith('x') || base.endsWith('sh') || base.endsWith('ch')) {
        return base;
      }
    }
    if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }

  static Set<String> _vocabulary(MindLanguage l) => {
    ...MindTexts.animals[MindLanguage.en]!,
    if (l != MindLanguage.en) ...MindTexts.animals[l]!,
  };

  static FluencyResult score(List<String> tokens, MindLanguage language) {
    final vocab = _vocabulary(language);
    final seen = <String>{};
    final valid = <String>[];
    var repetitions = 0;
    var intrusions = 0;
    var i = 0;
    while (i < tokens.length) {
      String? hit;
      var consumed = 1;
      if (i + 1 < tokens.length) {
        final two = '${tokens[i]} ${tokens[i + 1]}';
        if (vocab.contains(two)) {
          hit = two;
          consumed = 2;
        }
      }
      if (hit == null) {
        final w = tokens[i];
        if (vocab.contains(w)) {
          hit = w;
        } else {
          final s = _singular(w);
          if (vocab.contains(s)) hit = s;
        }
      }
      if (hit != null) {
        if (seen.add(hit)) {
          valid.add(hit);
        } else {
          repetitions++;
        }
      } else {
        intrusions++;
      }
      i += consumed;
    }
    return FluencyResult(
      valid: valid,
      repetitions: repetitions,
      intrusions: intrusions,
    );
  }
}

/// Picture-description information units found in the transcript [DER].
class PictureScorer {
  PictureScorer._();

  static List<String> infoUnits(List<String> tokens) {
    final set = tokens.toSet();
    final found = <String>[];
    for (final (unit, words) in MindTexts.parkUnits) {
      if (words.any(
        (w) =>
            set.contains(w) || set.any((t) => t.startsWith(w) && w.length >= 4),
      )) {
        found.add(unit);
      }
    }
    return found;
  }

  static int get totalUnits => MindTexts.parkUnits.length;
}

// ---------------------------------------------------------------------------
// PHQ-9 / GAD-7 (AUD-11)
// ---------------------------------------------------------------------------

enum MoodSeverity {
  normal('Normal'),
  mild('Mild'),
  moderate('Moderate'),
  moderatelySevere('Moderately severe'),
  severe('Severe');

  const MoodSeverity(this.label);
  final String label;
}

class Phq9Gad7 {
  Phq9Gad7._();

  static const int normalMax = 4; // Spec §8: < 5 normal
  static const int moderateCutoff = 10; // Spec §8

  static int total(MindQuestionnaire q, Map<String, int> answers) =>
      q.questions.fold(0, (s, item) => s + (answers[item.id] ?? 0));

  static bool complete(MindQuestionnaire q, Map<String, int> answers) =>
      q.questions.every((item) => answers.containsKey(item.id));

  /// PHQ-9 item 9 > 0 (Spec §8 G-37).
  static bool crisis(Map<String, int> answers) =>
      (answers[MindTexts.phq9.crisisItemId] ?? 0) > 0;

  /// < 5 normal (DOC), 5–9 mild [DER], 10–14 moderate (DOC ≥ 10), 15–19
  /// moderately severe [DER], ≥ 20 severe [DER]. GAD-7 ≥ 15 is severe.
  static MoodSeverity band(int total, {bool gad = false}) {
    if (total <= normalMax) return MoodSeverity.normal;
    if (total < moderateCutoff) return MoodSeverity.mild;
    if (total < 15) return MoodSeverity.moderate;
    if (gad) return MoodSeverity.severe;
    if (total < 20) return MoodSeverity.moderatelySevere;
    return MoodSeverity.severe;
  }
}

/// Prosody stand-in (0–1): low pitch variability, slow rate and long pauses
/// score higher. Recorded only — the document bars its use until it adds
/// ≥ 0.03 AUC over the questionnaires (G-24).
class MoodVoiceModel {
  MoodVoiceModel._();

  static double score(VoiceFeatures f) {
    if (!f.heardSpeech) return 0;
    final flat = (1 - (f.f0SdHz / 40).clamp(0, 1));
    final slow = (1 - (f.syllablesPerSec / 4.5).clamp(0, 1));
    final pausey = (f.pauseRatePerMin / 6).clamp(0, 1);
    return (0.35 * flat + 0.35 * slow + 0.30 * pausey).clamp(0, 1);
  }
}

// ---------------------------------------------------------------------------
// Heart-failure personal baseline (AUD-12)
// ---------------------------------------------------------------------------

class HfDailySample {
  const HfDailySample({
    required this.day,
    required this.vector,
    this.deviation,
  });

  final DateTime day;
  final List<double> vector;

  /// Deviation recorded for that day (null during the baseline window).
  final double? deviation;

  HfDailySample withDeviation(double? d) =>
      HfDailySample(day: day, vector: vector, deviation: d);
}

class HfBaseline {
  HfBaseline._();

  static const int baselineDays = 14; // Spec §8 / G-28
  static const double alertThreshold = 2.0; // [DER]
  static const int consecutiveDays = 2; // [DER]

  static (List<double>, List<double>) stats(List<HfDailySample> baseline) {
    final dims = baseline.first.vector.length;
    final mean = List<double>.filled(dims, 0);
    final sd = List<double>.filled(dims, 0);
    for (var d = 0; d < dims; d++) {
      final xs = baseline.map((s) => s.vector[d]).toList();
      final m = xs.reduce((a, b) => a + b) / xs.length;
      mean[d] = m;
      final v =
          xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) /
          math.max(1, xs.length - 1);
      // floor the sd at 5 % of the mean so a very stable feature cannot
      // explode the score
      sd[d] = math.max(math.sqrt(v), m.abs() * 0.05 + 1e-6);
    }
    return (mean, sd);
  }

  /// Mean |z| of today's vector against the baseline days.
  static double? deviation(List<double> today, List<HfDailySample> baseline) {
    if (baseline.length < baselineDays) return null;
    final (mean, sd) = stats(baseline);
    var acc = 0.0;
    for (var d = 0; d < today.length; d++) {
      acc += ((today[d] - mean[d]) / sd[d]).abs();
    }
    return acc / today.length;
  }

  /// Per-feature |z| for the result breakdown.
  static List<double> zScores(
    List<double> today,
    List<HfDailySample> baseline,
  ) {
    final (mean, sd) = stats(baseline);
    return [
      for (var d = 0; d < today.length; d++)
        ((today[d] - mean[d]) / sd[d]).abs(),
    ];
  }

  static bool alert(double today, double? yesterday) =>
      today >= alertThreshold && (yesterday ?? 0) >= alertThreshold;
}

// ---------------------------------------------------------------------------
// Stroke FAST (MOV-06..09)
// ---------------------------------------------------------------------------

class FaceGeometry {
  const FaceGeometry({
    required this.leftEye,
    required this.rightEye,
    required this.mouthLeft,
    required this.mouthRight,
    this.smileProb = 0,
  });

  final Pt2 leftEye;
  final Pt2 rightEye;
  final Pt2 mouthLeft;
  final Pt2 mouthRight;
  final double smileProb;

  /// Perpendicular distance of [p] to the eye line, normalised by the eye
  /// gap so the camera distance cancels.
  double distanceToEyeLine(Pt2 p) {
    final dx = rightEye.x - leftEye.x, dy = rightEye.y - leftEye.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return 0;
    final cross = (dx * (p.y - leftEye.y) - dy * (p.x - leftEye.x)).abs();
    return cross / len / len;
  }

  double get mouthLeftDrop => distanceToEyeLine(mouthLeft);
  double get mouthRightDrop => distanceToEyeLine(mouthRight);
}

class FaceAsymmetryResult {
  const FaceAsymmetryResult({
    required this.score,
    required this.side,
    required this.restDroopDiff,
    required this.excursionLeft,
    required this.excursionRight,
    this.smileDetected = true,
    this.restFrames = 1,
    this.smileFrames = 1,
  });

  final double score;

  /// 'none' | 'left' | 'right' (member's side).
  final String side;
  final double restDroopDiff;
  final double excursionLeft;
  final double excursionRight;

  /// False when the mouth corners barely moved between rest and "smile"
  /// (the member did not smile, or the face was lost) — the score then
  /// rests on the resting droop only and the step should be repeated.
  final bool smileDetected;
  final int restFrames;
  final int smileFrames;
}

class FaceAsymmetry {
  FaceAsymmetry._();

  static const double threshold = 0.50; // catalogue τ [DER]

  /// Minimum total corner excursion (normalised by the eye gap) for a real
  /// smile [DER]; below it the excursion asymmetry is pure noise.
  static const double minExcursion = 0.05;

  static FaceAsymmetryResult compute({
    required FaceGeometry rest,
    required FaceGeometry smile,
  }) => computeFrames(rest: [rest], smile: [smile]);

  /// Median rest frame vs the median of the five strongest smile frames.
  static FaceAsymmetryResult computeFrames({
    required List<FaceGeometry> rest,
    required List<FaceGeometry> smile,
  }) {
    if (rest.isEmpty || smile.isEmpty) {
      return const FaceAsymmetryResult(
        score: 0,
        side: 'none',
        restDroopDiff: 0,
        excursionLeft: 0,
        excursionRight: 0,
        smileDetected: false,
        restFrames: 0,
        smileFrames: 0,
      );
    }
    double median(List<double> xs) {
      final s = List<double>.from(xs)..sort();
      return s[s.length ~/ 2];
    }

    final restL = median([for (final f in rest) f.mouthLeftDrop]);
    final restR = median([for (final f in rest) f.mouthRightDrop]);
    final top = List<FaceGeometry>.from(smile)
      ..sort((a, b) => b.smileProb.compareTo(a.smileProb));
    final best = top.take(5).toList();
    final smileL = median([for (final f in best) f.mouthLeftDrop]);
    final smileR = median([for (final f in best) f.mouthRightDrop]);
    final smileProb = median([for (final f in best) f.smileProb]);
    final restDiff =
        (restL - restR).abs() / math.max(1e-6, (restL + restR) / 2);
    // smiling raises the corners → the distance to the eye line shrinks
    final exL = restL - smileL;
    final exR = restR - smileR;
    final totalEx = exL.abs() + exR.abs();
    final smiled = totalEx >= minExcursion && smileProb >= 0.2;
    final exAsym = smiled ? (exL - exR).abs() / totalEx : 0.0;
    final score = math.max(exAsym, restDiff * 3).clamp(0.0, 1.0);
    String side = 'none';
    if (score >= threshold) {
      // the weaker side moved less (or hangs lower at rest)
      side = exAsym >= restDiff * 3
          ? (exL < exR ? 'left' : 'right')
          : (restL > restR ? 'left' : 'right');
    }
    return FaceAsymmetryResult(
      score: score,
      side: side,
      restDroopDiff: restDiff,
      excursionLeft: exL,
      excursionRight: exR,
      smileDetected: smiled,
      restFrames: rest.length,
      smileFrames: smile.length,
    );
  }
}

/// Arm drift from the phone's gravity vector while held in the outstretched
/// hand [DER stand-in for the pose-camera method].
class ArmDrift {
  ArmDrift._();

  static const double armLengthCm = 60;
  static const double thresholdCm = 10;
  static const double holdSeconds = 10;

  /// Angle in degrees between the mean gravity vector at the start and at
  /// the end of the hold (any rotation).
  static double dropDegrees(List<double> startVec, List<double> endVec) {
    double dot = 0, na = 0, nb = 0;
    for (var i = 0; i < 3; i++) {
      dot += startVec[i] * endVec[i];
      na += startVec[i] * startVec[i];
      nb += endVec[i] * endVec[i];
    }
    if (na == 0 || nb == 0) return 0;
    final c = (dot / math.sqrt(na * nb)).clamp(-1.0, 1.0);
    return math.acos(c) * 180 / math.pi;
  }

  /// Pitch of the phone's long axis (y) against gravity, degrees: 0 when the
  /// phone lies flat in the palm, growing as the hand tips down (or up).
  static double pitchDegrees(List<double> g) {
    final n = math.sqrt(g[0] * g[0] + g[1] * g[1] + g[2] * g[2]);
    if (n == 0) return 0;
    return math.asin((g[1] / n).clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  /// Change of pitch between the start and the end of the hold — the
  /// forward dip of the hand as the arm drifts down. Roll (wrist turning)
  /// is ignored.
  static double pitchDropDegrees(List<double> startVec, List<double> endVec) =>
      (pitchDegrees(endVec) - pitchDegrees(startVec)).abs();

  static double dropCm(
    double degrees, {
    double armLengthCm = ArmDrift.armLengthCm,
  }) => armLengthCm * math.sin(degrees.clamp(0, 90) * math.pi / 180);

  static List<double> meanVector(List<List<double>> vs) {
    final out = [0.0, 0.0, 0.0];
    for (final v in vs) {
      for (var i = 0; i < 3; i++) {
        out[i] += v[i];
      }
    }
    return vs.isEmpty ? out : [for (final x in out) x / vs.length];
  }
}

class SpeechAbnormality {
  SpeechAbnormality._();

  static const double threshold = 0.50; // [DER]

  static double wordErrorRate(String target, String recognised) {
    final a = TranscriptAnalysis.tokenize(target);
    final b = TranscriptAnalysis.tokenize(recognised);
    if (a.isEmpty) return 0;
    final d = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = math.min(
          math.min(d[i - 1][j] + 1, d[i][j - 1] + 1),
          d[i - 1][j - 1] + cost,
        );
      }
    }
    return (d[a.length][b.length] / a.length).clamp(0.0, 1.0);
  }

  /// Helper judgement when speech recognition is unavailable [DER]:
  /// 0 clear · 1 slurred / wrong words · 2 could not speak.
  static const List<double> helperProbs = [0.1, 0.7, 1.0];
  static const List<String> helperLabels = [
    'Clear',
    'Slurred or wrong words',
    'Could not speak',
  ];

  /// 0–1: word errors weigh 80 %, slow articulation 20 % (< 2 syllables/s
  /// or < 1.5 recognised words/s counts as slow).
  static double prob(
    String target,
    String recognised, {
    double? syllablesPerSec,
    double? wordsPerSec,
  }) {
    final wer = wordErrorRate(target, recognised);
    var slow = 0.0;
    if (syllablesPerSec != null) {
      slow = 1 - (syllablesPerSec / 2.0).clamp(0, 1);
    } else if (wordsPerSec != null) {
      slow = 1 - (wordsPerSec / 1.5).clamp(0, 1);
    }
    return (0.8 * wer + 0.2 * slow).clamp(0.0, 1.0);
  }

  /// Recognised words per second from the timed partial results.
  static double? wordsPerSecond(List<TimedWords> partials, double durationS) {
    if (partials.length < 2) return null;
    final first = partials.firstWhere(
      (p) => p.wordCount > 0,
      orElse: () => partials.first,
    );
    final last = partials.last;
    final span = last.tSeconds - first.tSeconds;
    if (span <= 0.3 || last.wordCount <= 0) return null;
    return (last.wordCount - math.max(0, first.wordCount - 1)) / span;
  }
}

class StrokeDecisionResult {
  const StrokeDecisionResult({required this.positive, required this.signs});
  final bool positive;
  final List<String> signs;
}

/// MOV-09: logical OR across the evaluated signs; skipped parts are ignored.
class StrokeDecision {
  StrokeDecision._();

  static StrokeDecisionResult evaluate({
    double? faceScore,
    double? armDriftLCm,
    double? armDriftRCm,
    double? speechProb,
  }) {
    final signs = <String>[];
    if (faceScore != null && faceScore >= FaceAsymmetry.threshold) {
      signs.add('face');
    }
    if ((armDriftLCm != null && armDriftLCm >= ArmDrift.thresholdCm) ||
        (armDriftRCm != null && armDriftRCm >= ArmDrift.thresholdCm)) {
      signs.add('arm');
    }
    if (speechProb != null && speechProb >= SpeechAbnormality.threshold) {
      signs.add('speech');
    }
    return StrokeDecisionResult(positive: signs.isNotEmpty, signs: signs);
  }
}

// ---------------------------------------------------------------------------
// Simulated inputs (Test Controls / FLUTTER_TEST)
// ---------------------------------------------------------------------------

class MindSimulated {
  MindSimulated._();

  /// Synthetic PCM16: voiced bursts (a harmonic tone at [f0]) separated by
  /// silences; [longPauses] silences last 2.5 s.
  static List<int> pcm({
    int seconds = 30,
    int sampleRate = 16000,
    double f0 = 150,
    int longPauses = 0,
    double burstS = 1.2,
    double gapS = 0.35,
    int seed = 1,
    double amplitude = 0.35,
  }) {
    final rng = math.Random(seed);
    final n = seconds * sampleRate;
    final out = List<int>.filled(n, 0);
    var t = 0.0;
    var pausesLeft = longPauses;
    var burst = 0;
    while (t < seconds) {
      final len = burstS;
      final start = (t * sampleRate).round();
      final end = math.min(n, ((t + len) * sampleRate).round());
      for (var i = start; i < end; i++) {
        final tt = (i - start) / sampleRate;
        final env = math.min(
          1.0,
          math.min(tt / 0.05, (len - tt) / 0.05).clamp(0, 1),
        );
        // slight amplitude modulation makes syllable-like peaks
        final syl = 0.7 + 0.3 * math.cos(2 * math.pi * 3.5 * tt);
        var v = 0.0;
        for (var h = 1; h <= 4; h++) {
          v += math.sin(2 * math.pi * f0 * h * tt) / h;
        }
        v = v / 2.08 * amplitude * env * syl + (rng.nextDouble() - 0.5) * 0.004;
        out[i] = (v * 32767).round().clamp(-32768, 32767);
      }
      burst++;
      // every 4th burst, spend a long pause if any remain
      final gap = (pausesLeft > 0 && burst % 4 == 0) ? 2.5 : gapS;
      if (gap == 2.5) pausesLeft--;
      t += len + gap;
    }
    // room noise floor
    for (var i = 0; i < n; i++) {
      out[i] = (out[i] + (rng.nextDouble() - 0.5) * 60).round().clamp(
        -32768,
        32767,
      );
    }
    return out;
  }

  /// Animal-naming transcript for an outcome: (partials, final text).
  static (List<TimedWords>, String) fluencyTranscript(
    MindDemoOutcome o,
    MindLanguage lang, {
    int seconds = 60,
  }) {
    final list = MindTexts.animals[lang]!;
    final (count, reps, gapS) = switch (o) {
      MindDemoOutcome.normal => (18, 0, 3.0),
      MindDemoOutcome.borderline => (11, 1, 4.5),
      _ => (7, 2, 6.5),
    };
    final words = <String>[];
    for (var i = 0; i < count; i++) {
      words.add(list[i % list.length]);
      if (i < reps) words.add(list[i % list.length]);
    }
    final partials = <TimedWords>[];
    var t = 1.0;
    for (var i = 0; i < words.length; i++) {
      partials.add(TimedWords(t, i + 1));
      t += gapS;
      if (t > seconds - 1) break;
    }
    return (partials, words.join(' '));
  }

  static (List<TimedWords>, String) pictureTranscript(
    MindDemoOutcome o, {
    int seconds = 60,
  }) {
    final text = switch (o) {
      MindDemoOutcome.normal =>
        'I can see a park on a sunny day. A boy is flying a red kite near a tree and a small dog is running beside him. A man is sitting on a bench reading a newspaper. A woman is watering the flowers with a can. There is a pond with three ducks and an ice cream cart at the side.',
      MindDemoOutcome.borderline =>
        'There is a park. A boy with a kite. A dog. Some flowers and a woman. A pond I think and some birds.',
      _ => 'A park. A boy. A dog. A dog. Some water. I am not sure.',
    };
    final n = TranscriptAnalysis.tokenize(text).length;
    final gap = switch (o) {
      MindDemoOutcome.normal => 0.9,
      MindDemoOutcome.borderline => 2.2,
      _ => 3.4,
    };
    final partials = <TimedWords>[];
    var t = 1.0;
    for (var i = 1; i <= n; i++) {
      partials.add(TimedWords(t, i));
      t += gap;
      if (t > seconds - 1) break;
    }
    return (partials, text);
  }

  static Map<String, int> moodAnswers(MindDemoOutcome o) {
    final phq = <String, int>{};
    final gad = <String, int>{};
    final (p, g) = switch (o) {
      MindDemoOutcome.normal => (
        [1, 0, 1, 1, 0, 0, 0, 0, 0],
        [1, 0, 1, 0, 0, 0, 0],
      ),
      MindDemoOutcome.borderline => (
        [1, 1, 1, 2, 1, 1, 1, 0, 0],
        [1, 1, 1, 1, 1, 1, 0],
      ),
      MindDemoOutcome.refer => (
        [2, 2, 2, 2, 1, 2, 1, 2, 0],
        [2, 2, 2, 1, 1, 2, 1],
      ),
      MindDemoOutcome.crisis => (
        [2, 2, 2, 2, 1, 2, 1, 2, 1],
        [2, 2, 2, 1, 1, 2, 1],
      ),
    };
    for (var i = 0; i < 9; i++) {
      phq['phq9_${i + 1}'] = p[i];
    }
    for (var i = 0; i < 7; i++) {
      gad['gad7_${i + 1}'] = g[i];
    }
    return {...phq, ...gad};
  }

  /// 14 stable baseline days for an enrolled patient.
  static List<HfDailySample> hfBaseline(
    DateTime today, {
    int days = 14,
    int seed = 3,
  }) {
    final rng = math.Random(seed);
    return [
      for (var i = days; i >= 1; i--)
        HfDailySample(
          day: DateTime(
            today.year,
            today.month,
            today.day,
          ).subtract(Duration(days: i)),
          vector: [
            150 + rng.nextDouble() * 6 - 3,
            0.9 + rng.nextDouble() * 0.2,
            4.0 + rng.nextDouble() * 0.8,
            1500 + rng.nextDouble() * 120 - 60,
            12 + rng.nextDouble() * 1.5,
            0.20 + rng.nextDouble() * 0.04,
          ],
        ),
    ];
  }

  /// Today's vector: stable, or shifted the way fluid build-up moves the
  /// voice (lower pitch, more jitter/shimmer, lower centroid and HNR,
  /// more pausing).
  static List<double> hfToday(MindDemoOutcome o) => switch (o) {
    MindDemoOutcome.normal => [151, 1.0, 4.3, 1505, 12.5, 0.21],
    MindDemoOutcome.borderline => [146, 1.25, 5.0, 1420, 11.0, 0.26],
    _ => [138, 1.7, 6.5, 1300, 9.0, 0.32],
  };

  static FaceGeometry faceRest({bool droopLeft = false}) => FaceGeometry(
    leftEye: (x: 0.35, y: 0.40),
    rightEye: (x: 0.65, y: 0.40),
    mouthLeft: (x: 0.40, y: droopLeft ? 0.74 : 0.70),
    mouthRight: (x: 0.60, y: 0.70),
    smileProb: 0.05,
  );

  static FaceGeometry faceSmile({bool droopLeft = false}) => FaceGeometry(
    leftEye: (x: 0.35, y: 0.40),
    rightEye: (x: 0.65, y: 0.40),
    mouthLeft: (x: 0.37, y: droopLeft ? 0.735 : 0.66),
    mouthRight: (x: 0.63, y: 0.66),
    smileProb: 0.92,
  );

  /// Gravity vectors (m/s²) at the start and end of a 10 s hold.
  static (List<double>, List<double>) armHold({bool drifts = false}) =>
      ([0.3, 1.2, 9.7], drifts ? [0.3, 4.1, 8.9] : [0.4, 1.4, 9.6]);

  static String strokeSentence(MindDemoOutcome o, MindLanguage l) {
    final target = MindTexts.sentence('strokeSentence', l);
    if (o != MindDemoOutcome.refer && o != MindDemoOutcome.crisis) {
      return target;
    }
    final words = TranscriptAnalysis.tokenize(target);
    // drop and garble half the words
    return [
      for (var i = 0; i < words.length; i++)
        if (i.isEven) '${words[i]}a',
    ].join(' ');
  }
}
