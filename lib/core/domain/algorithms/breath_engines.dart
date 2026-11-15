// Pure-Dart engines for the Breathing & Voice section (Doc 09 §8
// ALG-AUD-01, -03, -04, -05, -06, §2 ALG-CAP-11, §5 ALG-FRM-13). No Flutter
// imports; unit-tested in test/breath_engines_test.dart.
//
// The trained models of the document (log-mel CNN cough detector, TB
// classifier / partner API, gradient-boosting obstruction model, SpiroSmart
// regression, GLI-2012 coefficients) are not shipped; every stand-in below
// is marked [DER] and surfaces as such on the result screens.
import 'dart:math' as math;

import '../entities/breath_protocol.dart';
import '../entities/enums.dart';
import 'fft.dart';
import 'mind_engines.dart' show VoiceFeatures;

double _log10(double x) => math.log(x) / math.ln10;
double _dbOfRms(double rms) => 20 * _log10(math.max(rms, 1e-3) / 32768);

double _percentile(List<double> xs, double p) {
  if (xs.isEmpty) return 0;
  final s = List<double>.from(xs)..sort();
  final i = ((s.length - 1) * p).round().clamp(0, s.length - 1);
  return s[i];
}

/// Start index of the quietest run of [window] consecutive frames.
int _quietWindowStart(List<double> db, int window) {
  if (db.length <= window) return 0;
  var best = 0;
  var bestSum = double.infinity;
  var sum = 0.0;
  for (var i = 0; i < window; i++) {
    sum += db[i];
  }
  bestSum = sum;
  for (var i = window; i < db.length; i++) {
    sum += db[i] - db[i - window];
    if (sum < bestSum) {
      bestSum = sum;
      best = i - window + 1;
    }
  }
  return best;
}

double _meanOf(List<double> xs, int start, int count) {
  if (xs.isEmpty) return 0;
  final a = start.clamp(0, xs.length - 1);
  final b = math.min(xs.length, a + math.max(1, count));
  var s = 0.0;
  for (var i = a; i < b; i++) {
    s += xs[i];
  }
  return s / (b - a);
}

/// Noise floor in dB: the lower of the 10th percentile and the quietest
/// [window]-frame run, so a recording that is voiced almost throughout
/// (a long "aaa") still finds its silence.
double _floorDb(List<double> db, {int window = 30}) {
  if (db.isEmpty) return -96;
  final w = math.min(window, db.length);
  final q = _meanOf(db, _quietWindowStart(db, w), w);
  return math.max(math.min(_percentile(db, 0.10), q), -90.0);
}

/// RMS level per frame in dBFS (10 ms frames by default).
List<double> _frameDb(List<int> s, int sr, {double frameMs = 10}) {
  final len = math.max(1, (frameMs / 1000 * sr).round());
  final frames = s.length ~/ len;
  final out = List<double>.filled(frames, -96);
  for (var f = 0; f < frames; f++) {
    var acc = 0.0;
    final off = f * len;
    for (var i = 0; i < len; i++) {
      final v = s[off + i].toDouble();
      acc += v * v;
    }
    out[f] = _dbOfRms(math.sqrt(acc / len));
  }
  return out;
}

/// Mean absolute amplitude per frame (0..32768), the rectified-and-smoothed
/// envelope the exhale analyser uses as a flow proxy.
List<double> _frameEnv(List<int> s, int sr, {double frameMs = 10}) {
  final len = math.max(1, (frameMs / 1000 * sr).round());
  final frames = s.length ~/ len;
  final out = List<double>.filled(frames, 0);
  for (var f = 0; f < frames; f++) {
    var acc = 0.0;
    final off = f * len;
    for (var i = 0; i < len; i++) {
      acc += s[off + i].abs();
    }
    out[f] = acc / len;
  }
  return out;
}

double _clipPct(List<int> s) {
  if (s.isEmpty) return 0;
  var c = 0;
  for (final v in s) {
    if (v.abs() >= 32700) c++;
  }
  return c * 100 / s.length;
}

/// Spectral centroid (Hz) and the share of power below [splitHz] for a
/// 512-point frame at [offset].
({double centroidHz, double lowShare}) _spectrum(
  List<int> s,
  int sr,
  int offset, {
  double splitHz = 500,
  double maxHz = 6000,
}) {
  const n = 512;
  if (offset < 0) offset = 0;
  if (offset + n > s.length) offset = math.max(0, s.length - n);
  if (s.length < n) return (centroidHz: 0, lowShare: 0);
  final frame = [for (var i = 0; i < n; i++) s[offset + i].toDouble()];
  final ps = Fft.powerSpectrum(frame);
  var num = 0.0, den = 0.0, low = 0.0;
  for (var k = 1; k < ps.length; k++) {
    final hz = k * sr / n;
    if (hz > maxHz) break;
    num += hz * ps[k];
    den += ps[k];
    if (hz < splitHz) low += ps[k];
  }
  if (den <= 0) return (centroidHz: 0, lowShare: 0);
  return (centroidHz: num / den, lowShare: low / den);
}

// ---------------------------------------------------------------------------
// ALG-AUD-01 cough detector [DER stand-in for the log-mel CNN]
// ---------------------------------------------------------------------------

class CoughEvent {
  const CoughEvent({
    required this.startMs,
    required this.endMs,
    required this.prob,
    required this.riseDb,
    required this.loudnessDb,
    required this.centroidHz,
    required this.wetness,
    required this.peakAtMs,
  });

  final int startMs;
  final int endMs;

  /// Detector probability 0–1 (Spec: accept when ≥ 0.5).
  final double prob;

  /// Onset sharpness: rise within 30 ms above the preceding level.
  final double riseDb;

  /// Peak above the noise floor.
  final double loudnessDb;
  final double centroidHz;

  /// Low-frequency energy share in the tail (0 dry … 1 wet) [DER].
  final double wetness;
  final int peakAtMs;

  int get durationMs => endMs - startMs;
  bool get durationOk =>
      durationMs >= CoughDetector.minMs && durationMs <= CoughDetector.maxMs;
  bool get valid => durationOk && prob >= CoughDetector.probThresh;

  /// Spec output row: [start_ms, end_ms, prob].
  List<num> get row => [startMs, endMs, double.parse(prob.toStringAsFixed(2))];
}

class CoughDetection {
  const CoughDetection({required this.candidates, required this.events});

  /// Every burst that was examined.
  final List<CoughEvent> candidates;

  /// Bursts accepted as coughs (COUGH_COUNT_VALID = events.length).
  final List<CoughEvent> events;

  int get count => events.length;
  bool get enough => count >= CoughDetector.minValidCoughs;
  double get meanWetness => events.isEmpty
      ? 0
      : events.map((e) => e.wetness).reduce((a, b) => a + b) / events.length;
  double get meanDurationMs => events.isEmpty
      ? 0
      : events.map((e) => e.durationMs).reduce((a, b) => a + b) / events.length;
  double get meanRiseDb => events.isEmpty
      ? 0
      : events.map((e) => e.riseDb).reduce((a, b) => a + b) / events.length;

  static const CoughDetection none = CoughDetection(candidates: [], events: []);
}

class CoughDetector {
  CoughDetector._();

  static const int minMs = 150; // Spec §8 AUD-01 duration_ms = [150, 800]
  static const int maxMs = 800;
  static const double probThresh = 0.50;
  static const int minValidCoughs = 3;
  static const int maxAttempts = 3; // E-AUD-001
  static const double onsetRiseDb = 12.0; // [DER] rise within 30 ms
  static const double aboveFloorDb = 8.0; // [DER] event threshold

  /// Energy-onset event detector on 10 ms frames: an event is a burst above
  /// floor + 8 dB; its probability combines onset sharpness (≥ 12 dB within
  /// 30 ms), loudness, a cough-like spectrum (centroid well above a hum)
  /// and an early peak. Duration outside 150–800 ms is rejected [DER].
  static CoughDetection detect(List<int> s, int sr) {
    final db = _frameDb(s, sr);
    if (db.length < 20) return CoughDetection.none;
    final floor = _floorDb(db);
    final thresh = math.max(floor + aboveFloorDb, -58.0);
    final candidates = <CoughEvent>[];
    var f = 0;
    const gapFrames = 5; // 50 ms of dip tolerated inside an event
    while (f < db.length) {
      if (db[f] <= thresh) {
        f++;
        continue;
      }
      final start = f;
      var last = f;
      var peak = f;
      var g = f;
      while (g < db.length && g - last <= gapFrames && g - start < 150) {
        if (db[g] > thresh) {
          last = g;
          if (db[g] > db[peak]) peak = g;
        }
        g++;
      }
      final end = last + 1;
      f = g;
      // onset rise within 30 ms over the level just before the event
      final before = start > 0 ? db[start - 1] : floor;
      var rise = 0.0;
      for (var k = start; k < math.min(start + 3, db.length); k++) {
        rise = math.max(rise, db[k] - before);
      }
      final frameLen = (0.010 * sr).round();
      final spec = _spectrum(s, sr, peak * frameLen - 128);
      final tailAt = start + ((end - start) * 0.6).round();
      final tail = _spectrum(s, sr, tailAt * frameLen - 128);
      final loud = db[peak] - floor;
      final durationMs = (end - start) * 10;
      final peakAtMs = (peak - start) * 10;
      final riseScore = ((rise - 8) / 10).clamp(0.0, 1.0);
      final loudScore = ((loud - 15) / 15).clamp(0.0, 1.0);
      final specScore = ((spec.centroidHz - 400) / 800).clamp(0.0, 1.0);
      final shapeScore = peakAtMs <= durationMs * 0.5 ? 1.0 : 0.4;
      var prob =
          0.25 * riseScore +
          0.25 * loudScore +
          0.30 * specScore +
          0.20 * shapeScore;
      if (durationMs < minMs || durationMs > maxMs) prob *= 0.3;
      candidates.add(
        CoughEvent(
          startMs: start * 10,
          endMs: end * 10,
          prob: prob.clamp(0.0, 1.0),
          riseDb: rise,
          loudnessDb: loud,
          centroidHz: spec.centroidHz,
          wetness: tail.lowShare.clamp(0.0, 1.0),
          peakAtMs: peakAtMs,
        ),
      );
    }
    return CoughDetection(
      candidates: candidates,
      events: candidates.where((e) => e.valid).toList(),
    );
  }
}

/// Provisional cough counter for the live "0 / 3" display, fed with the
/// recorder level (0..1 ≈ (dBFS + 50) / 50) every 100 ms. The final count
/// always comes from [CoughDetector] on the full recording.
class LiveBurstCounter {
  LiveBurstCounter({this.riseAbove = 0.25, this.minS = 0.1, this.maxS = 1.0});

  final double riseAbove;
  final double minS;
  final double maxS;

  double floor = 0.12;
  int count = 0;
  final List<double> burstTimes = [];
  bool _inBurst = false;
  double _burstStart = 0;
  double _lastT = 0;

  /// Seconds since the last accepted burst ended.
  double quietFor(double t) =>
      burstTimes.isEmpty ? t : t - burstTimes.last - 0.3;

  void add(double t, double level) {
    _lastT = t;
    if (!_inBurst) {
      if (level - floor >= riseAbove) {
        _inBurst = true;
        _burstStart = t;
      } else {
        floor = 0.9 * floor + 0.1 * level;
      }
      return;
    }
    if (level - floor < riseAbove * 0.5) {
      final dur = t - _burstStart;
      if (dur >= minS && dur <= maxS) {
        count++;
        burstTimes.add(_burstStart);
      }
      _inBurst = false;
    } else if (t - _burstStart > maxS + 0.3) {
      _inBurst = false;
    }
  }

  double get lastT => _lastT;
}

// ---------------------------------------------------------------------------
// ALG-AUD-04 wheeze detector (continuous tonal peak ≥ 100 ms)
// ---------------------------------------------------------------------------

class WheezeResult {
  const WheezeResult({
    required this.segments,
    required this.wheezeMs,
    required this.breathingMs,
    required this.dominantHz,
  });

  final int segments;
  final int wheezeMs;
  final int breathingMs;
  final double dominantHz;

  double get wheezeShare => breathingMs <= 0 ? 0 : wheezeMs / breathingMs;
  bool get heard => breathingMs >= 500;

  static const WheezeResult none = WheezeResult(
    segments: 0,
    wheezeMs: 0,
    breathingMs: 0,
    dominantHz: 0,
  );
}

class WheezeDetector {
  WheezeDetector._();

  static const int minDurationMs = 100; // Spec §8 AUD-04
  static const double fMinHz = 150; // [DER] wheeze band
  static const double fMaxHz = 1000;
  static const double peakAboveDb = 8.0; // [DER]

  /// 512-point frames with a 256-sample hop: a bin 8 dB above its
  /// neighbours (±2–4 bins) is a tonal peak; a peak that stays on the same
  /// bin (±1) for ≥ 100 ms is a wheeze segment.
  static WheezeResult detect(List<int> s, int sr) {
    const n = 512, hop = 256;
    if (s.length < n * 4) return WheezeResult.none;
    final hopMs = hop * 1000 / sr;
    final frames = (s.length - n) ~/ hop + 1;
    final energy = List<double>.filled(frames, -96);
    final spectra = <List<double>?>[];
    for (var f = 0; f < frames; f++) {
      final off = f * hop;
      var acc = 0.0;
      for (var i = 0; i < n; i++) {
        final v = s[off + i].toDouble();
        acc += v * v;
      }
      energy[f] = _dbOfRms(math.sqrt(acc / n));
      spectra.add(null);
    }
    final floor = _floorDb(energy, window: 20);
    final active = math.max(floor + 6, -60.0);
    final kMin = (fMinHz * n / sr).ceil();
    final kMax = (fMaxHz * n / sr).floor();
    final peakBin = List<int>.filled(frames, -1);
    var breathing = 0;
    for (var f = 0; f < frames; f++) {
      if (energy[f] <= active) continue;
      breathing++;
      final off = f * hop;
      final frame = [for (var i = 0; i < n; i++) s[off + i].toDouble()];
      final ps = Fft.powerSpectrum(frame);
      final db = [for (final p in ps) 10 * _log10(p + 1e-9)];
      var best = -1;
      var bestRise = 0.0;
      for (var k = math.max(kMin, 5); k <= math.min(kMax, db.length - 6); k++) {
        if (db[k] < db[k - 1] || db[k] < db[k + 1]) continue;
        final neigh = [
          db[k - 4],
          db[k - 3],
          db[k - 2],
          db[k + 2],
          db[k + 3],
          db[k + 4],
        ]..sort();
        final median = (neigh[2] + neigh[3]) / 2;
        final rise = db[k] - median;
        if (rise >= peakAboveDb && rise > bestRise) {
          bestRise = rise;
          best = k;
        }
      }
      peakBin[f] = best;
    }
    var segments = 0;
    var wheezeFrames = 0;
    final minFrames = (minDurationMs / hopMs).ceil();
    var run = 0;
    var runBin = -1;
    final hzHist = <int, int>{};
    void closeRun() {
      if (run >= minFrames) {
        segments++;
        wheezeFrames += run;
        hzHist[runBin] = (hzHist[runBin] ?? 0) + run;
      }
      run = 0;
      runBin = -1;
    }

    for (var f = 0; f < frames; f++) {
      final b = peakBin[f];
      if (b >= 0 && (runBin < 0 || (b - runBin).abs() <= 1)) {
        if (runBin < 0) runBin = b;
        run++;
      } else {
        closeRun();
        if (b >= 0) {
          runBin = b;
          run = 1;
        }
      }
    }
    closeRun();
    var domBin = -1;
    var domCount = 0;
    hzHist.forEach((k, v) {
      if (v > domCount) {
        domCount = v;
        domBin = k;
      }
    });
    return WheezeResult(
      segments: segments,
      wheezeMs: (wheezeFrames * hopMs).round(),
      breathingMs: (breathing * hopMs).round(),
      dominantHz: domBin < 0 ? 0 : domBin * sr / n,
    );
  }
}

// ---------------------------------------------------------------------------
// ALG-AUD-05 forced exhale (Hilbert-envelope proxy) + ALG-FRM-13 reference
// ---------------------------------------------------------------------------

class ExhaleEffort {
  const ExhaleEffort({
    required this.durationS,
    required this.onsetS,
    required this.peakAtS,
    required this.peakLevel,
    required this.area,
    required this.area1s,
    required this.curve,
    required this.clipPct,
    required this.snrDb,
  });

  /// Blow length from onset to the end of audible flow.
  final double durationS;
  final double onsetS;

  /// Time from onset to the loudest point (peak flow).
  final double peakAtS;

  /// Envelope peak as a share of full scale (0..1).
  final double peakLevel;

  /// Envelope area above the floor (volume proxy) and the same over the
  /// first second.
  final double area;
  final double area1s;

  /// Envelope from onset to end, normalised to the peak (for the chart).
  final List<double> curve;
  final double clipPct;
  final double snrDb;

  /// First-second share of the envelope area ≈ FEV1/FVC [DER].
  double get fev1Fraction => area <= 0 ? 0 : (area1s / area).clamp(0.2, 0.98);
  bool get heard => durationS >= 0.3;
  bool get longEnough => durationS >= ExhaleAnalyzer.minBlowS;
  bool get qualityOk =>
      clipPct <= VoiceFeatures.maxClipPct && snrDb >= VoiceFeatures.minSnrDb;

  static const ExhaleEffort silent = ExhaleEffort(
    durationS: 0,
    onsetS: 0,
    peakAtS: 0,
    peakLevel: 0,
    area: 0,
    area1s: 0,
    curve: [],
    clipPct: 0,
    snrDb: 0,
  );
}

class ExhaleAnalyzer {
  ExhaleAnalyzer._();

  static const double minBlowS = 3.0; // Spec §8 AUD-05 failure rule
  static const double smoothingMs = 10; // hilbert_window_ms

  /// Rectified envelope with 10 ms smoothing. Onset = first 50 ms above
  /// floor + 10 dB; end = last frame above it (gaps ≤ 300 ms bridged).
  static ExhaleEffort analyze(List<int> s, int sr) {
    final env = _frameEnv(s, sr, frameMs: smoothingMs);
    final db = _frameDb(s, sr, frameMs: smoothingMs);
    if (env.length < 30) return ExhaleEffort.silent;
    final quiet = _quietWindowStart(db, 30);
    final floorDb = math.min(_percentile(db, 0.10), _meanOf(db, quiet, 30));
    final floorLin = math.min(_percentile(env, 0.10), _meanOf(env, quiet, 30));
    final thresh = math.max(floorDb + 10, -55.0);
    var onset = -1;
    for (var f = 0; f + 5 <= db.length; f++) {
      var ok = true;
      for (var k = f; k < f + 5; k++) {
        if (db[k] <= thresh) {
          ok = false;
          break;
        }
      }
      if (ok) {
        onset = f;
        break;
      }
    }
    if (onset < 0) {
      return ExhaleEffort(
        durationS: 0,
        onsetS: 0,
        peakAtS: 0,
        peakLevel: 0,
        area: 0,
        area1s: 0,
        curve: const [],
        clipPct: _clipPct(s),
        snrDb: 0,
      );
    }
    var last = onset;
    var peak = onset;
    for (var f = onset; f < db.length; f++) {
      if (db[f] > thresh) {
        last = f;
        if (env[f] > env[peak]) peak = f;
      } else if (f - last > 30) {
        break;
      }
    }
    final dt = smoothingMs / 1000;
    var area = 0.0, area1 = 0.0;
    for (var f = onset; f <= last; f++) {
      final v = math.max(env[f] - floorLin, 0);
      area += v * dt;
      if (f - onset < 100) area1 += v * dt;
    }
    final span = last - onset + 1;
    final step = math.max(1, (span / 100).ceil());
    final peakEnv = math.max(env[peak] - floorLin, 1e-6);
    final curve = [
      for (var f = onset; f <= last; f += step)
        (math.max(env[f] - floorLin, 0) / peakEnv).clamp(0.0, 1.0),
    ];
    return ExhaleEffort(
      durationS: span * dt,
      onsetS: onset * dt,
      peakAtS: (peak - onset) * dt,
      peakLevel: (env[peak] / 32768).clamp(0.0, 1.0),
      area: area,
      area1s: area1,
      curve: curve,
      clipPct: _clipPct(s),
      snrDb: db[peak] - floorDb,
    );
  }
}

/// Predicted spirometry values and lower limits of normal.
class SpirometryPrediction {
  const SpirometryPrediction({
    required this.fev1,
    required this.fvc,
    required this.ratio,
    required this.pef,
    required this.fev1Lln,
    required this.fvcLln,
    required this.ratioLln,
    required this.ageInRange,
    required this.source,
  });

  final double fev1;
  final double fvc;

  /// Predicted FEV1/FVC as a fraction (0–1).
  final double ratio;
  final double pef;
  final double fev1Lln;
  final double fvcLln;
  final double ratioLln;
  final bool ageInRange;
  final String source;
}

/// ALG-FRM-13 stand-in: ECSC-1993 (Quanjer et al.) adult reference
/// equations, LLN = predicted − 1.645 × RSD. The document's GLI-2012
/// coefficients are "to be built" (Doc 08 §12) [DER].
class SpirometryReference {
  SpirometryReference._();

  static const String source = 'ECSC-1993 (GLI-2012 stand-in)';
  static const int minAge = 18;
  static const int maxAge = 70;

  static SpirometryPrediction predict({
    required BiologicalSex sex,
    required double heightCm,
    required int ageYears,
  }) {
    final h = heightCm / 100;
    final a = ageYears.clamp(minAge, maxAge).toDouble();
    final male = sex == BiologicalSex.male;
    final fev1 = male
        ? 4.30 * h - 0.029 * a - 2.49
        : 3.95 * h - 0.025 * a - 2.60;
    final fvc = male
        ? 5.76 * h - 0.026 * a - 4.34
        : 4.43 * h - 0.026 * a - 2.89;
    final ratioPct = male ? -0.18 * a + 87.21 : -0.19 * a + 89.10;
    final pef = male
        ? 6.14 * h - 0.043 * a + 0.15
        : 5.50 * h - 0.030 * a - 1.11;
    final fev1Rsd = male ? 0.51 : 0.38;
    final fvcRsd = male ? 0.61 : 0.43;
    final ratioRsd = male ? 7.17 : 6.51;
    return SpirometryPrediction(
      fev1: math.max(fev1, 0.5),
      fvc: math.max(fvc, 0.6),
      ratio: (ratioPct / 100).clamp(0.4, 0.98),
      pef: math.max(pef, 1.0),
      fev1Lln: math.max(fev1 - 1.645 * fev1Rsd, 0.3),
      fvcLln: math.max(fvc - 1.645 * fvcRsd, 0.3),
      ratioLln: ((ratioPct - 1.645 * ratioRsd) / 100).clamp(0.3, 0.95),
      ageInRange: ageYears >= minAge && ageYears <= maxAge,
      source: source,
    );
  }
}

class EffortValues {
  const EffortValues({
    required this.index,
    required this.effort,
    required this.fev1,
    required this.fvc,
    required this.ratio,
    required this.pef,
  });

  final int index;
  final ExhaleEffort effort;
  final double fev1;
  final double fvc;
  final double ratio;
  final double pef;

  bool get valid => effort.longEnough;
}

class SpirometryEstimate {
  const SpirometryEstimate({
    required this.efforts,
    required this.bestIndex,
    required this.repeatable,
    required this.repeatabilityDiffPct,
    required this.prediction,
  });

  final List<EffortValues> efforts;
  final int bestIndex;
  final bool repeatable;
  final double? repeatabilityDiffPct;
  final SpirometryPrediction prediction;

  EffortValues? get best => bestIndex < 0 ? null : efforts[bestIndex];
  int get validCount => efforts.where((e) => e.valid).length;
  double? get fev1 => best?.fev1;
  double? get fvc => best?.fvc;
  double? get ratio => best?.ratio;
  double? get pef => best?.pef;
  double? get fev1PredPct =>
      fev1 == null ? null : fev1! / prediction.fev1 * 100;
  double? get fvcPredPct => fvc == null ? null : fvc! / prediction.fvc * 100;
  bool get belowLln => ratio != null && ratio! < prediction.ratioLln;
}

/// ALG-AUD-05 regression stand-in: the envelope is uncalibrated, so the
/// volume scale is anchored on the predicted values and modulated by the
/// blow [DER]: FEV1/FVC = first-second area share; FVC = predicted FVC ×
/// (0.62 + 0.075 × blow seconds); FEV1 = ratio × FVC; PEF = predicted PEF ×
/// (0.6 + envelope peak).
class AudioSpirometry {
  AudioSpirometry._();

  static const double maxRepeatabilityDiffPct = 10.0; // Spec §8 AUD-05
  static const int numEfforts = 3;
  static const int maxEfforts = 5;

  static EffortValues values(
    int index,
    ExhaleEffort e,
    SpirometryPrediction pred,
  ) {
    final ratio = e.fev1Fraction;
    final durFactor = (0.62 + 0.075 * e.durationS).clamp(0.5, 1.25);
    final fvc = (pred.fvc * durFactor).clamp(0.3, 8.0);
    final fev1 = (ratio * fvc).clamp(0.3, 7.0);
    final pefFactor = (0.6 + e.peakLevel).clamp(0.4, 1.3);
    final pef = (pred.pef * pefFactor).clamp(0.5, 15.0);
    return EffortValues(
      index: index,
      effort: e,
      fev1: fev1,
      fvc: fvc,
      ratio: ratio,
      pef: pef,
    );
  }

  /// ATS/ERS repeatability: the two largest FEV1 values within 10 %.
  static double? repeatabilityDiffPct(List<EffortValues> valid) {
    if (valid.length < 2) return null;
    final f = valid.map((e) => e.fev1).toList()..sort((a, b) => b.compareTo(a));
    return (f[0] - f[1]) / f[0] * 100;
  }

  static SpirometryEstimate estimate(
    List<ExhaleEffort> efforts,
    SpirometryPrediction pred,
  ) {
    final vals = [
      for (var i = 0; i < efforts.length; i++) values(i, efforts[i], pred),
    ];
    final valid = vals.where((v) => v.valid).toList();
    final diff = repeatabilityDiffPct(valid);
    var best = -1;
    for (final v in valid) {
      if (best < 0 || v.fev1 + v.fvc > vals[best].fev1 + vals[best].fvc) {
        best = v.index;
      }
    }
    return SpirometryEstimate(
      efforts: vals,
      bestIndex: best,
      repeatable: diff != null && diff <= maxRepeatabilityDiffPct,
      repeatabilityDiffPct: diff,
      prediction: pred,
    );
  }
}

// ---------------------------------------------------------------------------
// ALG-AUD-06 voice quality
// ---------------------------------------------------------------------------

class PhonationSpan {
  const PhonationSpan(this.startS, this.endS);
  final double startS;
  final double endS;
  double get durationS => endS - startS;
}

class VoiceQualityResult {
  const VoiceQualityResult({
    required this.f0Hz,
    required this.jitterPct,
    required this.shimmerPct,
    required this.hnrDb,
    required this.cppsDb,
    required this.mptS,
    required this.sS,
    required this.zS,
    required this.szRatio,
    required this.middle,
    required this.adult,
  });

  final double f0Hz;
  final double jitterPct;
  final double shimmerPct;
  final double hnrDb;
  final double cppsDb;
  final double mptS;
  final double? sS;
  final double? zS;
  final double? szRatio;

  /// Features of the analysed middle 3 s.
  final VoiceFeatures middle;
  final bool adult;

  bool get phonationOk => mptS >= VoiceQuality.minPhonationS;

  SemanticBand bandOf(String code) => switch (code) {
    'JITTER_PCT' =>
      jitterPct < VoiceQuality.jitterMaxPct
          ? SemanticBand.normal
          : SemanticBand.borderline,
    'SHIMMER_PCT' =>
      shimmerPct < VoiceQuality.shimmerMaxPct
          ? SemanticBand.normal
          : SemanticBand.borderline,
    'HNR_DB' =>
      hnrDb > VoiceQuality.hnrMinDb
          ? SemanticBand.normal
          : SemanticBand.borderline,
    'MPT_S' =>
      !adult
          ? SemanticBand.rangeNotAvailable
          : mptS >= VoiceQuality.mptMinAdultS
          ? SemanticBand.normal
          : SemanticBand.borderline,
    'SZ_RATIO' =>
      szRatio == null
          ? SemanticBand.notAssessed
          : szRatio! < VoiceQuality.szMaxRatio
          ? SemanticBand.normal
          : SemanticBand.borderline,
    _ => SemanticBand.rangeNotAvailable,
  };

  int get outsideNormCount => [
    'JITTER_PCT',
    'SHIMMER_PCT',
    'HNR_DB',
    'MPT_S',
    'SZ_RATIO',
  ].where((c) => bandOf(c) == SemanticBand.borderline).length;
}

/// Cycle-by-cycle period and peak-to-peak amplitude (Praat-style local
/// jitter / shimmer) [DER approximation]: cycle marks are the waveform
/// peaks found one period apart with parabolic sub-sample interpolation.
class CyclePerturbation {
  const CyclePerturbation({
    required this.cycles,
    required this.f0Hz,
    required this.jitterPct,
    required this.shimmerPct,
    required this.hnrDb,
  });

  final int cycles;
  final double f0Hz;
  final double jitterPct;
  final double shimmerPct;

  /// Harmonics-to-noise from the correlation of consecutive cycles.
  final double hnrDb;

  static const CyclePerturbation none = CyclePerturbation(
    cycles: 0,
    f0Hz: 0,
    jitterPct: 0,
    shimmerPct: 0,
    hnrDb: 0,
  );

  static CyclePerturbation measure(
    List<int> s,
    int sr, {
    required double f0Hint,
  }) {
    final n = s.length;
    if (f0Hint <= 0 || n < sr ~/ 4) return none;
    final t0 = sr / f0Hint;
    int argmax(int lo, int hi) {
      lo = lo.clamp(0, n - 1);
      hi = hi.clamp(lo + 1, n);
      var best = lo;
      for (var i = lo; i < hi; i++) {
        if (s[i] > s[best]) best = i;
      }
      return best;
    }

    double refined(int p) {
      if (p <= 0 || p >= n - 1) return p.toDouble();
      final a = s[p - 1].toDouble(),
          b = s[p].toDouble(),
          c = s[p + 1].toDouble();
      final den = a - 2 * b + c;
      if (den == 0) return p.toDouble();
      return p + 0.5 * (a - c) / den;
    }

    final marks = <double>[];
    final intMarks = <int>[];
    var p = argmax(0, (2 * t0).round());
    marks.add(refined(p));
    intMarks.add(p);
    var period = t0;
    while (true) {
      final center = (marks.last + period).round();
      final lo = (center - 0.3 * period).round();
      final hi = (center + 0.3 * period).round();
      if (hi >= n - 1) break;
      final q = argmax(lo, hi + 1);
      marks.add(refined(q));
      intMarks.add(q);
      final last = marks[marks.length - 1] - marks[marks.length - 2];
      period = (0.8 * period + 0.2 * last).clamp(0.7 * t0, 1.3 * t0);
    }
    if (marks.length < 6) return none;
    final periods = [
      for (var i = 1; i < marks.length; i++) marks[i] - marks[i - 1],
    ];
    final amps = <double>[];
    for (var i = 1; i < intMarks.length; i++) {
      var mx = -1e9, mn = 1e9;
      for (var k = intMarks[i - 1]; k < intMarks[i]; k++) {
        final v = s[k].toDouble();
        if (v > mx) mx = v;
        if (v < mn) mn = v;
      }
      amps.add(mx - mn);
    }
    double mean(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
    final meanT = mean(periods);
    final meanA = mean(amps);
    var dj = 0.0, ds = 0.0;
    for (var i = 1; i < periods.length; i++) {
      dj += (periods[i] - periods[i - 1]).abs();
    }
    for (var i = 1; i < amps.length; i++) {
      ds += (amps[i] - amps[i - 1]).abs();
    }
    // consecutive-cycle correlation → harmonics-to-noise ratio
    final rs = <double>[];
    for (var i = 1; i + 1 < intMarks.length; i++) {
      final a0 = intMarks[i - 1], a1 = intMarks[i], b1 = intMarks[i + 1];
      final len = math.min(a1 - a0, b1 - a1);
      if (len < 8) continue;
      var ab = 0.0, aa = 0.0, bb = 0.0;
      for (var k = 0; k < len; k++) {
        final x = s[a0 + k].toDouble(), y = s[a1 + k].toDouble();
        ab += x * y;
        aa += x * x;
        bb += y * y;
      }
      if (aa > 0 && bb > 0) rs.add(ab / math.sqrt(aa * bb));
    }
    final r = rs.isEmpty ? 0.0 : mean(rs).clamp(0.0, 0.9999);
    final hnr = r <= 0 ? 0.0 : 10 * _log10(r / (1 - r));
    return CyclePerturbation(
      cycles: periods.length,
      f0Hz: meanT > 0 ? sr / meanT : 0,
      jitterPct: meanT > 0 ? dj / (periods.length - 1) / meanT * 100 : 0,
      shimmerPct: meanA > 0 ? ds / (amps.length - 1) / meanA * 100 : 0,
      hnrDb: hnr.clamp(0.0, 45.0),
    );
  }
}

class VoiceQuality {
  VoiceQuality._();

  static const double jitterMaxPct = 1.04; // Spec §8 AUD-06 adult norms
  static const double shimmerMaxPct = 3.81;
  static const double hnrMinDb = 20.0;
  static const double mptMinAdultS = 15.0;
  static const double szMaxRatio = 1.4;
  static const double minPhonationS = 3.0;
  static const double holdForS = 5.0;
  static const double f0MinHz = 75;
  static const double f0MaxHz = 500;

  /// Continuous voiced spans (10 ms frames above floor + 12 dB, gaps ≤
  /// [gapS] bridged).
  static List<PhonationSpan> voicedSpans(
    List<int> s,
    int sr, {
    double gapS = 0.15,
    double minSpanS = 0.2,
  }) {
    final db = _frameDb(s, sr);
    if (db.length < 10) return const [];
    final floor = _floorDb(db);
    final peak = _percentile(db, 0.95);
    final thresh = math.max(floor + 12, floor + (peak - floor) * 0.35);
    final voiced = [for (final d in db) d > thresh && d > -55];
    final spans = <PhonationSpan>[];
    var start = -1;
    var last = -1;
    final gap = (gapS * 100).round();
    for (var f = 0; f < voiced.length; f++) {
      if (voiced[f]) {
        if (start < 0) start = f;
        last = f;
      } else if (start >= 0 && f - last > gap) {
        spans.add(PhonationSpan(start / 100, (last + 1) / 100));
        start = -1;
      }
    }
    if (start >= 0) spans.add(PhonationSpan(start / 100, (last + 1) / 100));
    return spans.where((x) => x.durationS >= minSpanS).toList();
  }

  static PhonationSpan? longestSpan(List<int> s, int sr) {
    PhonationSpan? best;
    for (final x in voicedSpans(s, sr)) {
      if (best == null || x.durationS > best.durationS) best = x;
    }
    return best;
  }

  /// Total phonated time (all spans) — used for "sss" / "zzz".
  static double phonatedS(List<int> s, int sr) =>
      voicedSpans(s, sr).fold(0.0, (a, x) => a + x.durationS);

  /// The middle [seconds] of a span (Spec: analysis_segment = middle_3s).
  static List<int> middleSeconds(
    List<int> s,
    int sr,
    PhonationSpan span, {
    double seconds = 3,
  }) {
    final startS = span.durationS <= seconds
        ? span.startS
        : span.startS + (span.durationS - seconds) / 2;
    final a = (startS * sr).round().clamp(0, s.length);
    final b = ((startS + math.min(seconds, span.durationS)) * sr).round().clamp(
      0,
      s.length,
    );
    return s.sublist(a, b);
  }

  /// Smoothed cepstral peak prominence [DER approximation]: 1024-point
  /// log-power spectra (hop 512) averaged over the voiced frames (within
  /// 20 dB of the loudest), power cepstrum of the mirrored log spectrum in
  /// dB, 5-point quefrency smoothing, peak in the 75–500 Hz quefrency band
  /// minus a straight line fitted over 1–26 ms.
  static double cppsDb(List<int> s, int sr) {
    const n = 1024, hop = 512;
    if (s.length < n * 2) return 0;
    final frames = (s.length - n) ~/ hop + 1;
    final half = n ~/ 2;
    final energies = <double>[];
    final specs = <List<double>>[];
    for (var f = 0; f < frames; f++) {
      final off = f * hop;
      var acc = 0.0;
      final frame = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        final v = s[off + i].toDouble();
        frame[i] = v;
        acc += v * v;
      }
      energies.add(_dbOfRms(math.sqrt(acc / n)));
      specs.add(Fft.powerSpectrum(frame));
    }
    final loud = _percentile(energies, 0.95);
    final thresh = math.max(loud - 20, -55.0);
    final mean = List<double>.filled(half + 1, 0);
    var used = 0;
    for (var f = 0; f < frames; f++) {
      if (energies[f] <= thresh) continue;
      used++;
      final ps = specs[f];
      for (var k = 0; k <= half; k++) {
        mean[k] += 10 * _log10(ps[k] + 1e-9);
      }
    }
    if (used == 0) return 0;
    for (var k = 0; k <= half; k++) {
      mean[k] /= used;
    }
    // mirrored log spectrum → its power spectrum is the power cepstrum
    final arr = List<double>.filled(n, 0);
    for (var i = 0; i < half; i++) {
      arr[i] = mean[half - i];
      arr[half + i] = mean[i];
    }
    final pc = Fft.powerSpectrum(arr);
    final qMin = (sr / f0MaxHz).floor(); // 32 @16 kHz
    final qMax = (sr / f0MinHz).ceil(); // 214 @16 kHz
    final qFit0 = (0.001 * sr).round(); // 1 ms
    final qFit1 = math.min((0.026 * sr).round(), half - 1); // 26 ms
    final cep = List<double>.filled(qFit1 + 1, 0);
    for (var q = qFit0; q <= qFit1; q++) {
      cep[q] = 10 * _log10(pc[q] + 1e-12);
    }
    final sm = List<double>.filled(cep.length, 0);
    for (var q = qFit0; q <= qFit1; q++) {
      var acc = 0.0;
      var c = 0;
      for (var d = -2; d <= 2; d++) {
        final j = q + d;
        if (j >= qFit0 && j <= qFit1) {
          acc += cep[j];
          c++;
        }
      }
      sm[q] = acc / c;
    }
    // least-squares line over the fit range
    var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    var cnt = 0;
    for (var q = qFit0; q <= qFit1; q++) {
      sx += q;
      sy += sm[q];
      sxx += q * q;
      sxy += q * sm[q];
      cnt++;
    }
    final den = cnt * sxx - sx * sx;
    final slope = den == 0 ? 0 : (cnt * sxy - sx * sy) / den;
    final icpt = (sy - slope * sx) / cnt;
    var peak = -1e9;
    var peakQ = qMin;
    for (var q = math.max(qMin, qFit0); q <= math.min(qMax, qFit1); q++) {
      if (sm[q] > peak) {
        peak = sm[q];
        peakQ = q;
      }
    }
    return (peak - (icpt + slope * peakQ)).clamp(0.0, 40.0);
  }

  static double? szRatio(double? sS, double? zS) =>
      sS == null || zS == null || zS <= 0.2 ? null : sS / zS;

  /// The analysed segment is fully voiced, so [VoiceFeatures.extract] (which
  /// takes its floor from the quietest 10 % of frames) gets [padS] of the
  /// recording's own quietest audio on both sides.
  static List<int> padWithQuiet(
    List<int> s,
    int sr,
    List<int> segment, {
    double padS = 0.5,
  }) {
    final db = _frameDb(s, sr);
    final frames = (padS * 100).round();
    final frameLen = (0.010 * sr).round();
    List<int> pad;
    if (db.length > frames) {
      final start = _quietWindowStart(db, frames) * frameLen;
      pad = s.sublist(start, math.min(s.length, start + frames * frameLen));
    } else {
      final rng = math.Random(1);
      pad = [for (var i = 0; i < frames * frameLen; i++) rng.nextInt(7) - 3];
    }
    return [...pad, ...segment, ...pad];
  }

  static VoiceQualityResult analyze({
    required List<int> aaa,
    List<int>? sss,
    List<int>? zzz,
    required int sr,
    bool adult = true,
  }) {
    final span = longestSpan(aaa, sr);
    final mpt = span?.durationS ?? 0;
    final mid = span == null ? <int>[] : middleSeconds(aaa, sr, span);
    final f = VoiceFeatures.extract(
      mid.isEmpty ? mid : padWithQuiet(aaa, sr, mid),
      sr,
    );
    final pert = mid.isEmpty
        ? CyclePerturbation.none
        : CyclePerturbation.measure(mid, sr, f0Hint: f.meanF0Hz);
    final cycleBased = pert.cycles >= 20;
    final cpps = mid.isEmpty ? 0.0 : cppsDb(mid, sr);
    final sS = sss == null ? null : phonatedS(sss, sr);
    final zS = zzz == null ? null : phonatedS(zzz, sr);
    return VoiceQualityResult(
      f0Hz: cycleBased ? pert.f0Hz : f.meanF0Hz,
      jitterPct: cycleBased ? pert.jitterPct : f.jitterPct,
      shimmerPct: cycleBased ? pert.shimmerPct : f.shimmerPct,
      hnrDb: cycleBased ? pert.hnrDb : f.hnrDb,
      cppsDb: cpps,
      mptS: mpt,
      sS: sS,
      zS: zS,
      szRatio: szRatio(sS, zS),
      middle: f,
      adult: adult,
    );
  }
}

// ---------------------------------------------------------------------------
// ALG-AUD-03 TB risk [DER stand-in] and symptom rule
// ---------------------------------------------------------------------------

class TbSymptoms {
  TbSymptoms._();

  static const List<String> ids = [
    'tb_cough2w',
    'tb_fever',
    'tb_sweats',
    'tb_weight',
    'tb_blood',
  ];

  static int count(Map<String, int> a) =>
      ids.where((id) => (a[id] ?? 0) > 0).length;

  /// Classic TB symptoms [DER, WHO four-symptom screen]: cough ≥ 2 weeks or
  /// blood in the phlegm, or two of fever / night sweats / weight loss.
  static bool classic(Map<String, int> a) {
    if ((a['tb_cough2w'] ?? 0) > 0 || (a['tb_blood'] ?? 0) > 0) return true;
    final other = [
      'tb_fever',
      'tb_sweats',
      'tb_weight',
    ].where((id) => (a[id] ?? 0) > 0).length;
    return other >= 2;
  }

  static List<String> positives(Map<String, int> a) => [
    if ((a['tb_cough2w'] ?? 0) > 0) 'cough ≥ 2 weeks',
    if ((a['tb_fever'] ?? 0) > 0) 'fever',
    if ((a['tb_sweats'] ?? 0) > 0) 'night sweats',
    if ((a['tb_weight'] ?? 0) > 0) 'weight loss',
    if ((a['tb_blood'] ?? 0) > 0) 'blood in phlegm',
  ];
}

class TbModel {
  TbModel._();

  /// Document: threshold set on the validation set for ≥ 90 % sensitivity;
  /// 0.50 is the catalogue placeholder [DER].
  static const double tau = 0.50;

  /// 0–1 score from cough acoustics and the symptom count [DER].
  static double prob({
    required CoughDetection? coughs,
    required Map<String, int> symptoms,
  }) {
    var p = 0.08 + 0.12 * TbSymptoms.count(symptoms);
    if (coughs != null && coughs.count > 0) {
      if (coughs.meanWetness > 0.45) p += 0.15;
      if (coughs.meanDurationMs > 450) p += 0.08;
      if (coughs.count >= 5) p += 0.04;
    }
    return p.clamp(0.02, 0.95);
  }

  static SemanticBand band(double prob, {required bool classicSymptoms}) =>
      classicSymptoms || prob >= tau ? SemanticBand.high : SemanticBand.low;
}

// ---------------------------------------------------------------------------
// ALG-AUD-04 airway obstruction [DER stand-in]
// ---------------------------------------------------------------------------

class ExposureScore {
  ExposureScore._();

  /// 0–1 from Q_EXPOSURE: smoking status × years, biomass, dust [DER].
  static double of(Map<String, int> a) {
    final status = (a['exp_smoke'] ?? 0).clamp(0, 2);
    final years = (a['exp_years'] ?? 0).clamp(0, 3);
    final smoke = status == 0 ? 0.0 : (status == 1 ? 0.5 : 1.0);
    final s = smoke * (0.4 + 0.2 * years);
    final biomass = (a['exp_biomass'] ?? 0) > 0 ? 0.35 : 0.0;
    final dust = (a['exp_dust'] ?? 0) > 0 ? 0.25 : 0.0;
    return (s + biomass + dust).clamp(0.0, 1.0);
  }

  static List<String> labels(Map<String, int> a) => [
    switch ((a['exp_smoke'] ?? 0)) {
      1 => 'ex-smoker',
      2 => 'current smoker',
      _ => 'never smoked',
    },
    if ((a['exp_smoke'] ?? 0) > 0)
      switch ((a['exp_years'] ?? 0)) {
        1 => '< 10 years',
        2 => '10–20 years',
        3 => '> 20 years',
        _ => '',
      },
    if ((a['exp_biomass'] ?? 0) > 0) 'biomass cooking smoke',
    if ((a['exp_dust'] ?? 0) > 0) 'dust / fumes at work',
  ].where((x) => x.isNotEmpty).toList();
}

class OadScore {
  const OadScore({
    required this.prob,
    required this.band,
    required this.asthmaVsCopd,
    required this.exposure,
    required this.inputs,
  });

  final double prob;
  final SemanticBand band;
  final double asthmaVsCopd;
  final double exposure;

  /// Feature contributions for the "how it was worked out" row.
  final Map<String, double> inputs;
}

class OadModel {
  OadModel._();

  static const double lowMax = 0.33; // [DER] band cut-offs
  static const double moderateMax = 0.66;

  static SemanticBand bandOf(double p) => p < lowMax
      ? SemanticBand.low
      : p < moderateMax
      ? SemanticBand.moderate
      : SemanticBand.high;

  static OadScore score({
    double? wheezeShare,
    double? coughWetness,
    double? ratio,
    double? ratioLln,
    int? mmrc,
    Map<String, int> exposureAnswers = const {},
    int ageYears = 40,
  }) {
    final wheeze = ((wheezeShare ?? 0) / 0.3).clamp(0.0, 1.0);
    double ratioTerm;
    if (ratio == null || ratioLln == null) {
      ratioTerm = 0;
    } else if (ratio < ratioLln) {
      ratioTerm = 1;
    } else if (ratio < ratioLln + 0.05) {
      ratioTerm = 0.4;
    } else {
      ratioTerm = 0;
    }
    final m = ((mmrc ?? 0) / 4).clamp(0.0, 1.0);
    final exp = ExposureScore.of(exposureAnswers);
    final wet = (coughWetness ?? 0).clamp(0.0, 1.0);
    final p =
        (0.05 +
                0.30 * wheeze +
                0.30 * ratioTerm +
                0.20 * m +
                0.15 * exp +
                0.05 * wet)
            .clamp(0.0, 0.98);
    final asthma =
        (0.5 + 0.3 * wheeze - 0.3 * exp + (ageYears < 40 ? 0.1 : -0.1)).clamp(
          0.05,
          0.95,
        );
    return OadScore(
      prob: p,
      band: bandOf(p),
      asthmaVsCopd: asthma,
      exposure: exp,
      inputs: {
        'wheeze': 0.30 * wheeze,
        'exhale ratio': 0.30 * ratioTerm,
        'mMRC': 0.20 * m,
        'exposure': 0.15 * exp,
        'cough wetness': 0.05 * wet,
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ALG-CAP-11 microphone self-check
// ---------------------------------------------------------------------------

class MicSelfCheckResult {
  const MicSelfCheckResult({
    required this.deviationDb,
    required this.processingDetected,
    required this.sweepHeard,
    required this.bandsDb,
    required this.source,
    this.comparedToProfile = false,
    this.fixedProfileDeviationDb,
    this.manual = false,
  });

  /// mic_response_dev_db (0–40): against this phone's own stored sweep
  /// profile when one exists, otherwise 0 (the run records the profile).
  final double deviationDb;

  /// audio_processing_detected (advisory [DER heuristic]).
  final bool processingDetected;
  final bool sweepHeard;

  /// Relative band levels 250–500, 500–1k, 1k–2k, 2k–4k, 4k–8k Hz.
  final List<double> bandsDb;

  /// 'microphone' | 'simulated' | 'manual' | 'session'.
  final String source;

  /// True when [deviationDb] was measured against the stored profile.
  final bool comparedToProfile;

  /// Deviation from the generic phone profile, for information only.
  final double? fixedProfileDeviationDb;

  /// Member confirmed the test sound and an uncovered mic (fallback).
  final bool manual;

  /// Gate G-17: the sweep was heard and, once this phone is profiled, the
  /// response matches that profile within 6 dB. Processing detection is
  /// shown but never blocks [DER].
  bool get passed =>
      manual ||
      (sweepHeard &&
          (!comparedToProfile || deviationDb <= MicSelfCheck.maxDeviationDb));

  /// First passing run on an unprofiled phone.
  bool get profileRecorded => passed && !manual && !comparedToProfile;

  String get fixTip => !sweepHeard
      ? 'Test sound not heard — turn the volume up, uncover the speaker and microphone, and run the check again.'
      : comparedToProfile && deviationDb > MicSelfCheck.maxDeviationDb
      ? 'The microphone sounds different from this phone\'s profile (${deviationDb.toStringAsFixed(1)} dB, limit 6) — remove any case flap or finger covering the mic, clear the mic port, and run the check again.'
      : processingDetected
      ? 'Phone audio processing may be active — if you can, turn off noise suppression / sound enhancements in the phone settings.'
      : 'Microphone ready.';

  MicSelfCheckResult copyWith({String? source, bool? manual}) =>
      MicSelfCheckResult(
        deviationDb: deviationDb,
        processingDetected: processingDetected,
        sweepHeard: sweepHeard,
        bandsDb: bandsDb,
        source: source ?? this.source,
        comparedToProfile: comparedToProfile,
        fixedProfileDeviationDb: fixedProfileDeviationDb,
        manual: manual ?? this.manual,
      );

  /// The member's manual confirmation (recorded as such).
  static const MicSelfCheckResult manualConfirmation = MicSelfCheckResult(
    deviationDb: 0,
    processingDetected: false,
    sweepHeard: true,
    bandsDb: [0, 0, 0, 0, 0],
    source: 'manual',
    manual: true,
  );
}

class MicSelfCheck {
  MicSelfCheck._();

  static const double maxDeviationDb = 6.0; // Spec §2 CAP-11
  static const double sweepFromHz = 100;
  static const double sweepToHz = 8000;
  static const double sweepS = 1.5;

  /// Typical phone speaker→mic path, relative dB per band, used instead
  /// of the per-device profile of mst_device_model [DER].
  static const List<double> expectedProfileDb = [-5, -1, 0, 0, -1];
  static const List<double> bandEdgesHz = [250, 500, 1000, 2000, 4000, 8000];

  /// Octave-band energies over the frames where the sweep is audible,
  /// relative to their mean. With [baselineRel] (this phone's stored
  /// profile from its first passing run) the deviation is
  /// max |band − baseline| — a covered mic or case flap drops the 2–8 kHz
  /// bands and fails; the phone's own uneven response does not. Without a
  /// baseline the run only needs the sweep to be heard and records the
  /// profile. Processing (AGC / noise suppression) is suspected when the
  /// gain pumps down during the sweep (first third > last third by 8 dB)
  /// and is reported as advice only [DER heuristic].
  static MicSelfCheckResult evaluate(
    List<int> s,
    int sr, {
    String source = 'microphone',
    List<double>? baselineRel,
  }) {
    const n = 512, hop = 256;
    if (s.length < n * 8) {
      return MicSelfCheckResult(
        deviationDb: 40,
        processingDetected: false,
        sweepHeard: false,
        bandsDb: const [0, 0, 0, 0, 0],
        source: source,
      );
    }
    final frames = (s.length - n) ~/ hop + 1;
    final energy = List<double>.filled(frames, -96);
    for (var f = 0; f < frames; f++) {
      final off = f * hop;
      var acc = 0.0;
      for (var i = 0; i < n; i++) {
        final v = s[off + i].toDouble();
        acc += v * v;
      }
      energy[f] = _dbOfRms(math.sqrt(acc / n));
    }
    final floor = _floorDb(energy, window: 12);
    final thresh = math.max(floor + 10, -60.0);
    final sweepFrames = [
      for (var f = 0; f < frames; f++)
        if (energy[f] > thresh) f,
    ];
    final minFrames = (0.4 * sr / hop).round();
    if (sweepFrames.length < minFrames) {
      return MicSelfCheckResult(
        deviationDb: 40,
        processingDetected: false,
        sweepHeard: false,
        bandsDb: const [0, 0, 0, 0, 0],
        source: source,
      );
    }
    final bands = List<double>.filled(bandEdgesHz.length - 1, 0);
    for (final f in sweepFrames) {
      final off = f * hop;
      final frame = [for (var i = 0; i < n; i++) s[off + i].toDouble()];
      final ps = Fft.powerSpectrum(frame);
      for (var k = 1; k < ps.length; k++) {
        final hz = k * sr / n;
        for (var b = 0; b < bands.length; b++) {
          if (hz >= bandEdgesHz[b] && hz < bandEdgesHz[b + 1]) {
            bands[b] += ps[k];
            break;
          }
        }
      }
    }
    final db = [for (final b in bands) 10 * _log10(b + 1e-9)];
    final mean = db.reduce((a, c) => a + c) / db.length;
    final rel = [for (final d in db) d - mean];
    var fixedDev = 0.0;
    for (var b = 0; b < rel.length; b++) {
      fixedDev = math.max(fixedDev, (rel[b] - expectedProfileDb[b]).abs());
    }
    var dev = 0.0;
    final compared = baselineRel != null && baselineRel.length == rel.length;
    if (compared) {
      for (var b = 0; b < rel.length; b++) {
        dev = math.max(dev, (rel[b] - baselineRel[b]).abs());
      }
    }
    final levels = [for (final f in sweepFrames) energy[f]];
    final third = math.max(1, levels.length ~/ 3);
    final first = _meanOf(levels, 0, third);
    final last = _meanOf(levels, levels.length - third, third);
    return MicSelfCheckResult(
      deviationDb: dev.clamp(0.0, 40.0),
      processingDetected: first - last > 8.0,
      sweepHeard: true,
      bandsDb: rel,
      source: source,
      comparedToProfile: compared,
      fixedProfileDeviationDb: fixedDev.clamp(0.0, 40.0),
    );
  }

  /// Exponential sine sweep 100 Hz → 8 kHz, 1.5 s, for the speaker.
  static List<double> sweep(int sr, {double amplitude = 0.7}) {
    final n = (sweepS * sr).round();
    final k = math.log(sweepToHz / sweepFromHz);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final phase =
          2 *
          math.pi *
          sweepFromHz *
          sweepS /
          k *
          (math.exp(k * t / sweepS) - 1);
      var env = 1.0;
      final ramp = (0.02 * sr).round();
      if (i < ramp) env = i / ramp;
      if (n - i < ramp) env = (n - i) / ramp;
      out[i] = math.sin(phase) * amplitude * env;
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Live recogniser on streamed frames (same thresholds as the engines)
// ---------------------------------------------------------------------------

/// What the live recogniser is listening for.
enum LiveMode { cough, phonation, breath, exhale }

/// Fed with RMS dBFS frames as they arrive (10 ms from the PCM stream, 100 ms
/// from the amplitude fallback). Keeps an adaptive floor and reports:
/// coughs — provisional bursts accepted / rejected with a reason;
/// phonation — voiced seconds and the silence since the voice stopped;
/// exhale — blow start, length, normalised flow level and the end of flow.
class LiveFrameDetector {
  LiveFrameDetector(this.mode, {this.frameMs = 10});

  final LiveMode mode;
  final double frameMs;

  final List<double> _frames = [];
  double floorDb = -60;
  bool _floorInit = false;

  // cough
  int accepted = 0;
  int rejected = 0;
  String? lastRejectReason;
  double? lastEventEndS;
  double? lastAcceptedAtS;
  bool _inBurst = false;
  bool _burstOverflow = false;
  int _burstStart = 0;
  int _burstLastAbove = 0;
  double _burstPeak = -96;
  double _burstBefore = -96;

  // phonation
  double voicedS = 0;
  double longestRunS = 0;
  double _runS = 0;
  int _silentFrames = 0;
  double? lastVoiceAtS;

  // exhale
  bool blowing = false;
  bool blowEnded = false;
  double blowStartS = 0;
  double peakDb = -96;
  int _aboveRun = 0;
  int _belowRun = 0;

  double get elapsedS => _frames.length * frameMs / 1000;
  double? get currentDb => _frames.isEmpty ? null : _frames.last;
  bool get warmedUp => elapsedS >= 0.4;

  int _framesFor(double ms) => math.max(1, (ms / frameMs).round());

  /// 0..1 above the floor (50 dB span) for bars and the flow meter.
  double get levelNorm =>
      currentDb == null ? 0 : ((currentDb! - floorDb) / 50).clamp(0.0, 1.0);

  /// Seconds since the last accepted or examined burst ended.
  double get quietForS {
    if (_inBurst) return 0;
    final t = lastEventEndS;
    return t == null ? elapsedS : elapsedS - t;
  }

  double get silentForS =>
      lastVoiceAtS == null ? elapsedS : elapsedS - lastVoiceAtS!;
  bool get hearingVoice =>
      currentDb != null && currentDb! > math.max(floorDb + 12, -58);
  double get blowS => blowing ? elapsedS - blowStartS : 0;

  void addFrames(Iterable<double> dbs) {
    for (final d in dbs) {
      _add(d);
    }
  }

  void _add(double db) {
    _frames.add(db);
    // adaptive floor: minimum of the first 0.4 s, then slow tracking
    if (!_floorInit) {
      floorDb = db;
      _floorInit = true;
    } else if (!warmedUp || db < floorDb) {
      floorDb = math.min(floorDb, db);
      if (!warmedUp && db < floorDb + 6) floorDb = math.min(floorDb, db);
    } else if (db < floorDb + 8) {
      floorDb += 0.02 * (db - floorDb);
    }
    floorDb = floorDb.clamp(-96.0, -20.0);
    switch (mode) {
      case LiveMode.cough:
        _coughStep(db);
      case LiveMode.phonation:
        _voiceStep(db);
      case LiveMode.exhale:
        _exhaleStep(db);
      case LiveMode.breath:
        break;
    }
  }

  void _coughStep(double db) {
    final n = _frames.length;
    final thresh = math.max(floorDb + CoughDetector.aboveFloorDb, -58.0);
    if (!_inBurst) {
      if (db > thresh && warmedUp) {
        _inBurst = true;
        _burstStart = n - 1;
        _burstLastAbove = n - 1;
        _burstPeak = db;
        final back = _framesFor(30) + 1;
        _burstBefore = n - back - 1 >= 0 ? _frames[n - back - 1] : floorDb;
      }
      return;
    }
    if (db > thresh) {
      _burstLastAbove = n - 1;
      if (db > _burstPeak) _burstPeak = db;
    }
    final gapFrames = n - 1 - _burstLastAbove;
    final tooLong = (n - _burstStart) * frameMs > 1200;
    if (_burstOverflow) {
      // an over-long sound was already rejected: wait for real silence
      if (gapFrames > _framesFor(50)) {
        _inBurst = false;
        _burstOverflow = false;
        lastEventEndS = (_burstLastAbove + 1) * frameMs / 1000;
      }
      return;
    }
    if (gapFrames > _framesFor(50) || tooLong) {
      if (tooLong) {
        _burstOverflow = true;
        rejected++;
        lastRejectReason = 'too long';
        lastEventEndS = elapsedS;
        return;
      }
      final end = _burstLastAbove + 1;
      final durationMs = (end - _burstStart) * frameMs;
      var rise = 0.0;
      final onsetFrames = _framesFor(30);
      for (
        var k = _burstStart;
        k < math.min(_burstStart + onsetFrames, _frames.length);
        k++
      ) {
        rise = math.max(rise, _frames[k] - _burstBefore);
      }
      final loud = _burstPeak - floorDb;
      _inBurst = false;
      lastEventEndS = end * frameMs / 1000;
      if (durationMs < CoughDetector.minMs) {
        rejected++;
        lastRejectReason = 'too short';
      } else if (durationMs > CoughDetector.maxMs) {
        rejected++;
        lastRejectReason = 'too long';
      } else if (rise < CoughDetector.onsetRiseDb || loud < 20) {
        rejected++;
        lastRejectReason = 'too soft';
      } else {
        accepted++;
        lastAcceptedAtS = lastEventEndS;
        lastRejectReason = null;
      }
    }
  }

  void _voiceStep(double db) {
    final voiced = db > math.max(floorDb + 12, -58);
    final dt = frameMs / 1000;
    if (voiced) {
      voicedS += dt;
      _runS += dt;
      if (_runS > longestRunS) longestRunS = _runS;
      _silentFrames = 0;
      lastVoiceAtS = elapsedS;
    } else {
      _silentFrames++;
      if (_silentFrames > _framesFor(150)) _runS = 0;
    }
  }

  void _exhaleStep(double db) {
    if (db > peakDb) peakDb = db;
    final on = math.max(floorDb + 15, -55.0);
    if (!blowing) {
      if (db > on && warmedUp) {
        _aboveRun++;
        if (_aboveRun >= _framesFor(50)) {
          blowing = true;
          blowStartS = elapsedS - 0.05;
        }
      } else {
        _aboveRun = 0;
      }
      return;
    }
    if (db < floorDb + 10) {
      _belowRun++;
    } else {
      _belowRun = 0;
    }
    if (blowS >= 1.0 && _belowRun >= _framesFor(800)) blowEnded = true;
  }
}

// ---------------------------------------------------------------------------
// Simulated audio (Test Controls / FLUTTER_TEST)
// ---------------------------------------------------------------------------

class BreathSimulated {
  BreathSimulated._();

  static List<int> _clampAll(List<double> xs) => [
    for (final x in xs) (x * 32767).round().clamp(-32768, 32767),
  ];

  static void _floor(List<double> out, math.Random rng, [double a = 0.0012]) {
    for (var i = 0; i < out.length; i++) {
      out[i] += (rng.nextDouble() - 0.5) * 2 * a;
    }
  }

  static List<int> silence({double seconds = 3, int sr = 16000, int seed = 1}) {
    final out = List<double>.filled((seconds * sr).round(), 0);
    _floor(out, math.Random(seed));
    return _clampAll(out);
  }

  /// [n] cough bursts (sharp onset, ~[burstMs] decay, high-frequency
  /// noise) spaced 2.5 s apart from t = 2 s; [wetness] adds low-frequency
  /// rumble to the tail.
  static List<int> coughs({
    int n = 3,
    double seconds = 12,
    int sr = 16000,
    double wetness = 0.2,
    double amplitude = 0.55,
    double burstMs = 320,
    double spacingS = 2.5,
    int seed = 3,
  }) {
    final rng = math.Random(seed);
    final out = List<double>.filled((seconds * sr).round(), 0);
    var prev = 0.0;
    for (var c = 0; c < n; c++) {
      final t0 = 2.0 + c * spacingS;
      final start = (t0 * sr).round();
      final len = (burstMs / 1000 * sr).round();
      for (var i = 0; i < len && start + i < out.length; i++) {
        final t = i / sr;
        final attack = math.min(1.0, t / 0.004);
        final decay = math.exp(-t / (burstMs / 1000 * 0.35));
        final env = attack * decay;
        // high-passed white noise (first difference) = harsh cough spectrum
        final white = rng.nextDouble() - 0.5;
        final hp = white - prev;
        prev = white;
        var v = hp * 1.6 * env;
        if (t > burstMs / 1000 * 0.4) {
          v += wetness * 0.6 * env * math.sin(2 * math.pi * 180 * t);
        }
        out[start + i] += v * amplitude;
      }
    }
    _floor(out, rng);
    return _clampAll(out);
  }

  /// A steady 150 Hz hum with harmonics (rejected: too long).
  static List<int> hum({double seconds = 2, int sr = 16000, double f0 = 150}) {
    final out = List<double>.filled((seconds * sr).round(), 0);
    for (var i = 0; i < out.length; i++) {
      final t = i / sr;
      var v = 0.0;
      for (var h = 1; h <= 4; h++) {
        v += math.sin(2 * math.pi * f0 * h * t) / h;
      }
      out[i] = v / 2.08 * 0.4;
    }
    _floor(out, math.Random(5));
    return _clampAll(out);
  }

  /// A short click (rejected: too short).
  static List<int> click({double ms = 60, int sr = 16000}) {
    final rng = math.Random(9);
    final out = List<double>.filled((1.0 * sr).round(), 0);
    final start = (0.4 * sr).round();
    final len = (ms / 1000 * sr).round();
    for (var i = 0; i < len; i++) {
      out[start + i] = (rng.nextDouble() - 0.5) * 1.2;
    }
    _floor(out, rng);
    return _clampAll(out);
  }

  /// Sustained vowel: harmonic tone with per-cycle jitter / shimmer and
  /// additive noise (lower HNR), preceded and followed by silence.
  static List<int> phonation({
    double seconds = 12,
    int sr = 16000,
    double f0 = 140,
    double jitterPct = 0.3,
    double shimmerPct = 1.5,
    double noise = 0.01,
    double amplitude = 0.4,
    double leadS = 0.5,
    double tailS = 0.5,
    int seed = 11,
  }) {
    final rng = math.Random(seed);
    final total = ((leadS + seconds + tailS) * sr).round();
    final out = List<double>.filled(total, 0);
    final start = (leadS * sr).round();
    final n = (seconds * sr).round();
    var phase = 0.0;
    var cycleF = f0;
    var cycleA = 1.0;
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final env = math
          .min(1.0, math.min(t / 0.08, (seconds - t) / 0.12))
          .clamp(0.0, 1.0);
      phase += 2 * math.pi * cycleF / sr;
      if (phase >= 2 * math.pi) {
        phase -= 2 * math.pi;
        final gj = (rng.nextDouble() + rng.nextDouble() - 1) * 1.7;
        final gs = (rng.nextDouble() + rng.nextDouble() - 1) * 1.7;
        cycleF = f0 * (1 + jitterPct / 100 * gj);
        cycleA = 1 + shimmerPct / 100 * gs;
      }
      var v = 0.0;
      for (var h = 1; h <= 5; h++) {
        v += math.sin(phase * h) / h;
      }
      v = v / 2.28 * amplitude * cycleA * env;
      v += (rng.nextDouble() - 0.5) * 2 * noise * env;
      out[start + i] = v;
    }
    _floor(out, rng);
    return _clampAll(out);
  }

  /// "sss" (voiceless) or "zzz" (voiced) held for [seconds].
  static List<int> fricative({
    double seconds = 10,
    int sr = 16000,
    bool voiced = false,
    double amplitude = 0.22,
    int seed = 13,
  }) {
    final rng = math.Random(seed);
    final total = ((0.5 + seconds + 0.5) * sr).round();
    final out = List<double>.filled(total, 0);
    final start = (0.5 * sr).round();
    final n = (seconds * sr).round();
    var prev = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final env = math
          .min(1.0, math.min(t / 0.1, (seconds - t) / 0.15))
          .clamp(0.0, 1.0);
      final white = rng.nextDouble() - 0.5;
      final hp = (white - prev) * 1.4;
      prev = white;
      var v = hp * amplitude;
      if (voiced) v += 0.22 * math.sin(2 * math.pi * 115 * t);
      out[start + i] = v * env;
    }
    _floor(out, rng);
    return _clampAll(out);
  }

  /// Breath sounds: filtered noise with a 4 s in/out cycle; [wheeze] adds a
  /// 420 Hz tone during the out-breaths.
  static List<int> breathSounds({
    double seconds = 16,
    int sr = 16000,
    bool wheeze = false,
    double amplitude = 0.12,
    int seed = 17,
  }) {
    final rng = math.Random(seed);
    final out = List<double>.filled((seconds * sr).round(), 0);
    var lp = 0.0;
    for (var i = 0; i < out.length; i++) {
      final t = i / sr;
      final cyc = (t % 4) / 4; // 0..0.5 in, 0.5..1 out
      final env = math.pow(math.sin(math.pi * cyc * 2 / 2), 2).toDouble();
      final white = rng.nextDouble() - 0.5;
      lp = 0.85 * lp + 0.15 * white;
      var v = lp * 2.5 * amplitude * (0.3 + env);
      if (wheeze && cyc > 0.55 && cyc < 0.95) {
        v += 0.18 * amplitude / 0.12 * 0.5 * math.sin(2 * math.pi * 420 * t);
      }
      out[i] = v;
    }
    _floor(out, rng);
    return _clampAll(out);
  }

  /// Forced exhale: noise under an envelope with a 0.12 s attack and
  /// exponential decay to a small plateau; [obstructed] blows are longer and
  /// slower (first-second share ≈ 0.47 vs ≈ 0.77).
  static List<int> exhale({
    int sr = 16000,
    bool obstructed = false,
    bool borderline = false,
    double amplitude = 0.6,
    double? seconds,
    int seed = 19,
  }) {
    final rng = math.Random(seed);
    final tau = obstructed ? 1.2 : (borderline ? 0.65 : 0.45);
    final plateau = obstructed ? 0.05 : (borderline ? 0.03 : 0.02);
    final dur = seconds ?? (obstructed ? 7.0 : 5.0);
    final total = ((0.6 + dur + 0.8) * sr).round();
    final out = List<double>.filled(total, 0);
    final start = (0.6 * sr).round();
    final n = (dur * sr).round();
    var lp = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final attack = math.min(1.0, t / 0.12);
      var env = (math.exp(-t / tau) + plateau) * attack;
      if (dur - t < 0.2) env *= (dur - t) / 0.2;
      final white = rng.nextDouble() - 0.5;
      lp = 0.6 * lp + 0.4 * white;
      out[start + i] = lp * 2.2 * amplitude * env;
    }
    _floor(out, rng);
    return _clampAll(out);
  }

  static Map<String, int> tbAnswers(BreathDemoOutcome o) => switch (o) {
    BreathDemoOutcome.normal => const {
      'tb_cough2w': 0,
      'tb_fever': 0,
      'tb_sweats': 0,
      'tb_weight': 0,
      'tb_blood': 0,
    },
    BreathDemoOutcome.borderline => const {
      'tb_cough2w': 0,
      'tb_fever': 1,
      'tb_sweats': 0,
      'tb_weight': 0,
      'tb_blood': 0,
    },
    BreathDemoOutcome.refer => const {
      'tb_cough2w': 1,
      'tb_fever': 1,
      'tb_sweats': 1,
      'tb_weight': 0,
      'tb_blood': 0,
    },
  };

  static Map<String, int> mmrcAnswers(BreathDemoOutcome o) => {
    'mmrc': switch (o) {
      BreathDemoOutcome.normal => 0,
      BreathDemoOutcome.borderline => 1,
      BreathDemoOutcome.refer => 3,
    },
  };

  static Map<String, int> exposureAnswers(BreathDemoOutcome o) => switch (o) {
    BreathDemoOutcome.normal => const {
      'exp_smoke': 0,
      'exp_years': 0,
      'exp_biomass': 0,
      'exp_dust': 0,
    },
    BreathDemoOutcome.borderline => const {
      'exp_smoke': 1,
      'exp_years': 1,
      'exp_biomass': 1,
      'exp_dust': 0,
    },
    BreathDemoOutcome.refer => const {
      'exp_smoke': 2,
      'exp_years': 3,
      'exp_biomass': 1,
      'exp_dust': 1,
    },
  };

  static Map<String, int> answersFor(
    String questionnaireId,
    BreathDemoOutcome o,
  ) => switch (questionnaireId) {
    'Q_TB_SYMPTOMS' => tbAnswers(o),
    'Q_MMRC' => mmrcAnswers(o),
    'Q_EXPOSURE' => exposureAnswers(o),
    _ => const {},
  };

  /// Voice parameters per outcome: normal → inside every norm, borderline →
  /// jitter just over, refer → hoarse (high jitter / shimmer, low HNR,
  /// short MPT).
  static ({double f0, double jitter, double shimmer, double noise, double mpt})
  voiceParams(BreathDemoOutcome o) => switch (o) {
    BreathDemoOutcome.normal => (
      f0: 140.0,
      jitter: 0.25,
      shimmer: 1.2,
      noise: 0.004,
      mpt: 18.0,
    ),
    BreathDemoOutcome.borderline => (
      f0: 150.0,
      jitter: 1.9,
      shimmer: 2.5,
      noise: 0.01,
      mpt: 13.0,
    ),
    BreathDemoOutcome.refer => (
      f0: 128.0,
      jitter: 2.6,
      shimmer: 6.0,
      noise: 0.05,
      mpt: 7.0,
    ),
  };
}
