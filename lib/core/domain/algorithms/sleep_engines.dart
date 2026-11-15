// Pure-Dart engines for the overnight sleep sonar (Doc 09 §8 ALG-AUD-07)
// and apnoea screen (ALG-AUD-08).
//
// Signal path (all on-device, nothing stored but features):
//   PCM16 @ 48 kHz ─► SonarFrameAnalyzer ─► SonarFeature @ 20 Hz
//     (echo amplitude in 18–20 kHz, audible band level 80–1500 Hz)
//   600 features (30 s) ─► BreathWaveExtractor ─► SonarEpoch
//     (breathing wave, SONAR_RR, validity, 1 Hz breath amplitude)
//   epochs ─► ApnoeaScorer ─► SleepEvent list ─► SleepDecision
//
// The document specifies FMCW phase tracking; this implementation follows
// the echo amplitude envelope instead [DER] and keeps the document's
// thresholds (90 % / 30 % drops, ≥ 10 s, AHI bands, ≥ 4 h valid sleep).
import 'dart:math' as math;

import 'fft.dart';
import 'movement_engines.dart' show Dsp;

// ---------------------------------------------------------------------------
// Features
// ---------------------------------------------------------------------------

/// One 50 ms feature of the microphone stream.
class SonarFeature {
  const SonarFeature(this.t, this.sonarAmp, this.sonarDb, this.audibleDb);

  /// Seconds since the night started.
  final double t;

  /// Linear echo amplitude in the 18–20 kHz band (0..1 of full scale).
  final double sonarAmp;

  /// Same in dBFS.
  final double sonarDb;

  /// Audible band (80–1500 Hz) level in dBFS (snore / gasp).
  final double audibleDb;
}

/// Streams PCM16 at 48 kHz into 20 features per second: a 2048-sample Hann
/// frame every 2400 samples (50 ms).
class SonarFrameAnalyzer {
  SonarFrameAnalyzer({
    this.sampleRate = 48000,
    this.frameSize = 2048,
    this.hop = 2400,
    this.sonarLowHz = 18000,
    this.sonarHighHz = 20000,
    this.audibleLowHz = 80,
    this.audibleHighHz = 1500,
  });

  final int sampleRate;
  final int frameSize;
  final int hop;
  final double sonarLowHz;
  final double sonarHighHz;
  final double audibleLowHz;
  final double audibleHighHz;

  final List<int> _carry = [];
  int _consumed = 0;

  double get elapsedS => _consumed / sampleRate;

  /// Pushes samples and returns the features completed by them.
  List<SonarFeature> push(List<int> samples) {
    _carry.addAll(samples);
    final out = <SonarFeature>[];
    while (_carry.length >= frameSize) {
      final frame = [for (var i = 0; i < frameSize; i++) _carry[i] / 32768.0];
      final spec = Fft.powerSpectrum(frame);
      final binHz = sampleRate / frameSize;
      double band(double lo, double hi) {
        final a = (lo / binHz).floor().clamp(0, spec.length - 1);
        final b = (hi / binHz).ceil().clamp(0, spec.length - 1);
        var acc = 0.0;
        for (var k = a; k <= b; k++) {
          acc += spec[k];
        }
        // Hann window energy ≈ 0.375 · N; two-sided → amplitude estimate
        return math.sqrt(acc) / (frameSize * 0.375);
      }

      final sonarAmp = band(sonarLowHz, sonarHighHz);
      final audibleAmp = band(audibleLowHz, audibleHighHz);
      final t = (_consumed + frameSize / 2) / sampleRate;
      out.add(SonarFeature(t, sonarAmp, _db(sonarAmp), _db(audibleAmp)));
      final drop = math.min(hop, _carry.length);
      _carry.removeRange(0, drop);
      _consumed += drop;
    }
    return out;
  }

  static double _db(double amp) =>
      20 * math.log(math.max(amp, 1e-7)) / math.ln10;

  void reset() {
    _carry.clear();
    _consumed = 0;
  }
}

// ---------------------------------------------------------------------------
// Epochs (ALG-AUD-07)
// ---------------------------------------------------------------------------

class SonarEpoch {
  const SonarEpoch({
    required this.index,
    required this.startS,
    required this.valid,
    required this.rr,
    required this.echoDb,
    required this.peakRatio,
    required this.amplitude,
    required this.ampPerSecond,
    required this.audiblePerSecond,
    required this.wave,
    this.invalidReason,
  });

  final int index;
  final double startS;

  /// Echo clear and a breathing rhythm found.
  final bool valid;

  /// SONAR_RR in br/min (null when invalid).
  final double? rr;
  final double echoDb;
  final double peakRatio;

  /// Mean relative breathing amplitude of the epoch.
  final double amplitude;

  /// 1 Hz relative breathing amplitude (30 values).
  final List<double> ampPerSecond;

  /// 1 Hz audible level dBFS (30 values).
  final List<double> audiblePerSecond;

  /// Breathing wave downsampled to 2 Hz (60 points) for the chart.
  final List<double> wave;
  final String? invalidReason;

  static const int seconds = 30;
}

/// 30-s epoch → breathing wave, SONAR_RR and validity [DER echo-envelope
/// method; thresholds: echo ≥ floor + 6 dB, spectral peak ≥ 2.5 × median].
class BreathWaveExtractor {
  const BreathWaveExtractor({
    this.featureHz = 20,
    this.floorDb = -80,
    this.minEchoAboveFloorDb = 6,
    this.minPeakRatio = 2.5,
    this.minRrBrMin = 6,
    this.maxRrBrMin = 42,
  });

  final double featureHz;

  /// Echo floor with the chirp off (from the sonar check), dBFS.
  final double floorDb;
  final double minEchoAboveFloorDb;
  final double minPeakRatio;
  final double minRrBrMin;
  final double maxRrBrMin;

  BreathWaveExtractor withFloor(double db) => BreathWaveExtractor(
    featureHz: featureHz,
    floorDb: db,
    minEchoAboveFloorDb: minEchoAboveFloorDb,
    minPeakRatio: minPeakRatio,
    minRrBrMin: minRrBrMin,
    maxRrBrMin: maxRrBrMin,
  );

  SonarEpoch epoch(int index, List<SonarFeature> f) {
    final n = f.length;
    final startS = f.isEmpty ? index * 30.0 : f.first.t;
    if (n < featureHz * 10) {
      return _invalid(index, startS, 'Too few samples', f);
    }
    final x = [for (final s in f) s.sonarAmp];
    final meanAmp = x.reduce((a, b) => a + b) / n;
    final echoDb = f.map((s) => s.sonarDb).reduce((a, b) => a + b) / n;
    final wave = bandPass(x, featureHz);
    final ampPerSecond = _perSecond(wave, f, meanAmp);
    final audiblePerSecond = _audiblePerSecond(f);
    final waveDown = _downsample(wave, 60);
    if (echoDb < floorDb + minEchoAboveFloorDb) {
      return SonarEpoch(
        index: index,
        startS: startS,
        valid: false,
        rr: null,
        echoDb: echoDb,
        peakRatio: 0,
        amplitude: 0,
        ampPerSecond: ampPerSecond,
        audiblePerSecond: audiblePerSecond,
        wave: waveDown,
        invalidReason: 'No chest echo',
      );
    }
    final (rr, ratio) = dominantRate(wave, featureHz);
    final valid = rr != null && ratio >= minPeakRatio;
    final amp = ampPerSecond.isEmpty
        ? 0.0
        : ampPerSecond.reduce((a, b) => a + b) / ampPerSecond.length;
    return SonarEpoch(
      index: index,
      startS: startS,
      valid: valid,
      rr: valid ? rr : null,
      echoDb: echoDb,
      peakRatio: ratio,
      amplitude: valid ? amp : 0,
      ampPerSecond: ampPerSecond,
      audiblePerSecond: audiblePerSecond,
      wave: waveDown,
      invalidReason: valid ? null : 'No breathing rhythm in the echo',
    );
  }

  SonarEpoch _invalid(
    int index,
    double startS,
    String why,
    List<SonarFeature> f,
  ) => SonarEpoch(
    index: index,
    startS: startS,
    valid: false,
    rr: null,
    echoDb: f.isEmpty
        ? -120
        : f.map((s) => s.sonarDb).reduce((a, b) => a + b) / f.length,
    peakRatio: 0,
    amplitude: 0,
    ampPerSecond: const [],
    audiblePerSecond: _audiblePerSecond(f),
    wave: const [],
    invalidReason: why,
  );

  /// Detrend with a 4 s moving average, smooth with a 0.7 s one
  /// (≈ 0.1–0.7 Hz band).
  static List<double> bandPass(List<double> x, double fs) {
    final slow = _movingAverage(x, math.max(3, (4 * fs).round() | 1));
    final hp = [for (var i = 0; i < x.length; i++) x[i] - slow[i]];
    return _movingAverage(hp, math.max(3, (0.7 * fs).round() | 1));
  }

  /// Strongest rhythm between 6 and 42 br/min and its ratio to the median
  /// spectrum; prefers the fundamental when the half-rate bin is strong
  /// (interference doubles the envelope rate when the chest swing exceeds
  /// half a wavelength).
  (double?, double) dominantRate(List<double> wave, double fs) {
    final (freqs, psd) = Dsp.welchPsd(
      wave,
      fs,
      segmentSeconds: 15,
      overlap: 0.5,
      maxFreq: 1.5,
    );
    if (freqs.length < 3) return (null, 0);
    final lo = minRrBrMin / 60, hi = maxRrBrMin / 60;
    var best = -1;
    for (var k = 0; k < freqs.length; k++) {
      if (freqs[k] < lo || freqs[k] > hi) continue;
      if (best < 0 || psd[k] > psd[best]) best = k;
    }
    if (best < 0) return (null, 0);
    final body = [
      for (var k = 0; k < freqs.length; k++)
        if (freqs[k] >= lo) psd[k],
    ]..sort();
    final median = body.isEmpty ? 0.0 : body[body.length ~/ 2];
    final ratio = median <= 0 ? 0.0 : psd[best] / median;
    // parabolic interpolation of the log-power peak for sub-bin accuracy
    final df = freqs[1] - freqs[0];
    var f = freqs[best];
    if (best > 0 && best < psd.length - 1) {
      final a = math.log(psd[best - 1] + 1e-30);
      final b = math.log(psd[best] + 1e-30);
      final c = math.log(psd[best + 1] + 1e-30);
      final den = a - 2 * b + c;
      if (den.abs() > 1e-12) {
        final delta = (0.5 * (a - c) / den).clamp(-0.5, 0.5);
        f = (best + delta) * df;
      }
    }
    // fundamental check: half-rate bin with ≥ 40 % of the peak
    final halfK = (best / 2).round();
    if (halfK > 0 &&
        freqs[halfK] >= lo &&
        psd[halfK] >= 0.4 * psd[best] &&
        (freqs[halfK] * 2 - f).abs() < fs / wave.length * 2) {
      f = freqs[halfK];
    }
    return (f * 60, ratio);
  }

  static List<double> _movingAverage(List<double> x, int win) {
    final n = x.length;
    if (n == 0) return const [];
    final half = win ~/ 2;
    final prefix = List<double>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      prefix[i + 1] = prefix[i] + x[i];
    }
    return [
      for (var i = 0; i < n; i++)
        (() {
          final a = math.max(0, i - half), b = math.min(n - 1, i + half);
          return (prefix[b + 1] - prefix[a]) / (b - a + 1);
        })(),
    ];
  }

  List<double> _perSecond(
    List<double> wave,
    List<SonarFeature> f,
    double mean,
  ) {
    final per = featureHz.round();
    final out = <double>[];
    for (var s = 0; s + per <= wave.length; s += per) {
      var acc = 0.0;
      for (var i = s; i < s + per; i++) {
        acc += wave[i] * wave[i];
      }
      final rms = math.sqrt(acc / per);
      out.add(mean <= 0 ? 0 : rms / mean);
    }
    return out;
  }

  List<double> _audiblePerSecond(List<SonarFeature> f) {
    final per = featureHz.round();
    final out = <double>[];
    for (var s = 0; s + per <= f.length; s += per) {
      var mx = -140.0;
      for (var i = s; i < s + per; i++) {
        mx = math.max(mx, f[i].audibleDb);
      }
      out.add(mx);
    }
    return out;
  }

  static List<double> _downsample(List<double> x, int points) {
    if (x.isEmpty) return const [];
    final step = x.length / points;
    return [
      for (var i = 0; i < points; i++)
        x[math.min(x.length - 1, (i * step).floor())],
    ];
  }
}

// ---------------------------------------------------------------------------
// Events (ALG-AUD-08)
// ---------------------------------------------------------------------------

enum SleepEventType { apnoea, hypopnoea }

class SleepEvent {
  const SleepEvent({
    required this.type,
    required this.startS,
    required this.durationS,
    required this.dropPct,
    this.terminatedBy = '',
  });

  final SleepEventType type;
  final double startS;
  final double durationS;

  /// Median breathing amplitude drop during the event, %.
  final double dropPct;

  /// 'gasp' | 'snore' | 'spo2' | '' (apnoea needs no termination evidence).
  final String terminatedBy;

  double get endS => startS + durationS;
}

/// A ring SpO2 desaturation (G-32) — interface only; no ring is paired.
class SpO2Dip {
  const SpO2Dip(this.onsetS, this.durationS, this.dipPct);
  final double onsetS;
  final double durationS;
  final double dipPct;
}

/// Scores apnoeas / hypopnoeas on the 1 Hz breathing-amplitude track.
class ApnoeaScorer {
  const ApnoeaScorer({
    this.apnoeaDropPct = 90,
    this.hypopnoeaDropPct = 30,
    this.minEventS = 10,
    this.maxEventS = 120,
    this.baselineWindowS = 60,
    this.minBaselineSeconds = 20,
    this.terminationWindowS = 15,
    this.terminationRiseDb = 10,
    this.ringDipPct = 3,
  });

  final double apnoeaDropPct;
  final double hypopnoeaDropPct;
  final int minEventS;
  final int maxEventS;
  final int baselineWindowS;
  final int minBaselineSeconds;
  final int terminationWindowS;
  final double terminationRiseDb;
  final double ringDipPct;

  List<SleepEvent> score(
    List<SonarEpoch> epochs, {
    List<SpO2Dip> ringDips = const [],
  }) {
    // 1 Hz tracks
    final amp = <double>[];
    final valid = <bool>[];
    final audible = <double>[];
    final t0 = <double>[];
    for (final e in epochs) {
      final secs = SonarEpoch.seconds;
      for (var s = 0; s < secs; s++) {
        amp.add(s < e.ampPerSecond.length ? e.ampPerSecond[s] : 0);
        valid.add(e.valid);
        audible.add(
          s < e.audiblePerSecond.length ? e.audiblePerSecond[s] : -120,
        );
        t0.add(e.startS + s);
      }
    }
    final n = amp.length;
    final events = <SleepEvent>[];
    var i = 0;
    while (i < n) {
      if (!valid[i]) {
        i++;
        continue;
      }
      final base = _baseline(amp, valid, i);
      if (base == null) {
        i++;
        continue;
      }
      final drop = 1 - amp[i] / base;
      if (drop < hypopnoeaDropPct / 100) {
        i++;
        continue;
      }
      // candidate: extend while the drop holds against the frozen baseline
      var j = i;
      final drops = <double>[];
      while (j < n &&
          valid[j] &&
          (1 - amp[j] / base) >= hypopnoeaDropPct / 100) {
        drops.add(1 - amp[j] / base);
        j++;
        if (j - i > maxEventS) break;
      }
      final dur = j - i;
      if (dur > maxEventS || dur < minEventS) {
        i = math.max(j, i + 1);
        continue;
      }
      final sorted = List<double>.from(drops)..sort();
      final medDrop = sorted[sorted.length ~/ 2];
      final startS = t0[i];
      if (medDrop >= apnoeaDropPct / 100) {
        events.add(
          SleepEvent(
            type: SleepEventType.apnoea,
            startS: startS,
            durationS: dur.toDouble(),
            dropPct: medDrop * 100,
          ),
        );
      } else {
        final by = _termination(audible, valid, j, startS + dur, ringDips);
        if (by.isNotEmpty) {
          events.add(
            SleepEvent(
              type: SleepEventType.hypopnoea,
              startS: startS,
              durationS: dur.toDouble(),
              dropPct: medDrop * 100,
              terminatedBy: by,
            ),
          );
        }
      }
      i = j + 1;
    }
    return events;
  }

  double? _baseline(List<double> amp, List<bool> valid, int i) {
    final vals = <double>[];
    for (var k = math.max(0, i - baselineWindowS); k < i; k++) {
      if (valid[k] && amp[k] > 0) vals.add(amp[k]);
    }
    if (vals.length < minBaselineSeconds) return null;
    vals.sort();
    return vals[vals.length ~/ 2];
  }

  String _termination(
    List<double> audible,
    List<bool> valid,
    int end,
    double endS,
    List<SpO2Dip> dips,
  ) {
    for (final d in dips) {
      if (d.dipPct >= ringDipPct &&
          d.onsetS <= endS + terminationWindowS &&
          d.onsetS + d.durationS >= endS - terminationWindowS) {
        return 'spo2';
      }
    }
    final ref = <double>[];
    for (var k = math.max(0, end - baselineWindowS - 1); k < end; k++) {
      ref.add(audible[k]);
    }
    if (ref.isEmpty) return '';
    ref.sort();
    final baseDb = ref[ref.length ~/ 2];
    var peak = -200.0;
    for (
      var k = end;
      k < math.min(audible.length, end + terminationWindowS);
      k++
    ) {
      peak = math.max(peak, audible[k]);
    }
    if (peak >= baseDb + terminationRiseDb) {
      return peak >= baseDb + terminationRiseDb + 8 ? 'gasp' : 'snore';
    }
    return '';
  }
}

/// Per-epoch snore fraction: seconds whose audible level sits ≥ 8 dB above
/// the epoch median (support value only — the document names no snore
/// marker).
class SnoreDetector {
  const SnoreDetector({this.riseDb = 8});
  final double riseDb;

  double fraction(SonarEpoch e) {
    final a = e.audiblePerSecond;
    if (a.length < 5) return 0;
    final s = List<double>.from(a)..sort();
    final med = s[s.length ~/ 2];
    final loud = a.where((v) => v >= med + riseDb).length;
    return loud / a.length;
  }

  double nightFraction(List<SonarEpoch> epochs) {
    final v = epochs.where((e) => e.valid).toList();
    if (v.isEmpty) return 0;
    return v.map(fraction).reduce((a, b) => a + b) / v.length;
  }
}

// ---------------------------------------------------------------------------
// Decision
// ---------------------------------------------------------------------------

enum OsaBand { normal, mild, moderate, severe }

class OsaBands {
  OsaBands._();

  /// AHI < 5 normal · 5–14 mild · 15–29 moderate · ≥ 30 severe (AASM).
  static OsaBand band(double ahi) => ahi < 5
      ? OsaBand.normal
      : ahi < 15
      ? OsaBand.mild
      : ahi < 30
      ? OsaBand.moderate
      : OsaBand.severe;

  static String label(OsaBand b) => switch (b) {
    OsaBand.normal => 'normal',
    OsaBand.mild => 'mild',
    OsaBand.moderate => 'moderate',
    OsaBand.severe => 'severe',
  };
}

class SleepDecisionResult {
  const SleepDecisionResult({
    required this.validSleepH,
    required this.recordedH,
    required this.medianRr,
    required this.apnoeaEvents,
    required this.hypopnoeaEvents,
    required this.ahi,
    required this.band,
    required this.partial,
    required this.invalidEpochs,
  });

  final double validSleepH;
  final double recordedH;
  final double? medianRr;
  final int apnoeaEvents;
  final int hypopnoeaEvents;

  /// null when VALID_SLEEP_H < 4.0 h (E-AUD-003).
  final double? ahi;
  final OsaBand? band;
  final bool partial;
  final int invalidEpochs;

  int get events => apnoeaEvents + hypopnoeaEvents;
  bool get referable => band == OsaBand.moderate || band == OsaBand.severe;
}

class SleepDecision {
  SleepDecision._();

  static const double minValidSleepH = 4.0;

  static SleepDecisionResult compute(
    List<SonarEpoch> epochs,
    List<SleepEvent> events,
  ) {
    final valid = epochs.where((e) => e.valid).toList();
    final validH = valid.length * SonarEpoch.seconds / 3600;
    final recordedH = epochs.length * SonarEpoch.seconds / 3600;
    double? medianRr;
    if (valid.isNotEmpty) {
      final rrs = valid.map((e) => e.rr!).toList()..sort();
      medianRr = rrs[rrs.length ~/ 2];
    }
    final a = events.where((e) => e.type == SleepEventType.apnoea).length;
    final h = events.where((e) => e.type == SleepEventType.hypopnoea).length;
    final enough = validH >= minValidSleepH;
    final ahi = enough ? (a + h) / validH : null;
    return SleepDecisionResult(
      validSleepH: validH,
      recordedH: recordedH,
      medianRr: medianRr,
      apnoeaEvents: a,
      hypopnoeaEvents: h,
      ahi: ahi,
      band: ahi == null ? null : OsaBands.band(ahi),
      partial: !enough,
      invalidEpochs: epochs.length - valid.length,
    );
  }
}

// ---------------------------------------------------------------------------
// Simulation (tests, desktop, Test Controls)
// ---------------------------------------------------------------------------

/// Synthetic nights. Feature nights feed the real extractor / scorer;
/// [pcm] builds a short 48 kHz take for the analyzer tests.
class SleepSimulated {
  SleepSimulated._();

  static const double featureHz = 20;

  /// Target shape per demo outcome: hours recorded, apnoeas / h,
  /// hypopnoeas / h, echo-lost fraction.
  static ({double hours, double apnoeaPerH, double hypoPerH, double lost})
  shape(String outcome) => switch (outcome) {
    'mild' => (hours: 6.0, apnoeaPerH: 5.0, hypoPerH: 4.0, lost: 0.05),
    'moderate' => (hours: 6.0, apnoeaPerH: 12.0, hypoPerH: 8.0, lost: 0.05),
    'severe' => (hours: 6.0, apnoeaPerH: 30.0, hypoPerH: 16.0, lost: 0.05),
    'shortNight' => (hours: 2.5, apnoeaPerH: 1.0, hypoPerH: 1.0, lost: 0.05),
    _ => (hours: 6.0, apnoeaPerH: 1.0, hypoPerH: 1.0, lost: 0.04),
  };

  /// Features of epoch [index] of a simulated night.
  static List<SonarFeature> epochFeatures(
    String outcome,
    int index, {
    int seed = 7,
    bool echoLost = false,
    double? rr,
  }) {
    final s = shape(outcome);
    final rng = math.Random(seed * 1000 + index);
    final lost = echoLost || rng.nextDouble() < s.lost;
    final rate = rr ?? 13.5 + 4 * rng.nextDouble(); // 13.5–17.5 br/min
    // events this epoch: Poisson-ish from the hourly rate (120 epochs / h)
    final pA = s.apnoeaPerH / 120, pH = s.hypoPerH / 120;
    final r = rng.nextDouble();
    final kind = r < pA
        ? 'apnoea'
        : r < pA + pH
        ? 'hypopnoea'
        : '';
    // kept inside the epoch so the terminating snore / gasp is seen too
    final evStart = 3 + rng.nextDouble() * 5; // 3–8 s
    final evDur = 12 + rng.nextDouble() * 6; // 12–18 s
    final n = (SonarEpoch.seconds * featureHz).round();
    final out = <SonarFeature>[];
    for (var i = 0; i < n; i++) {
      final t = i / featureHz;
      final abs = index * SonarEpoch.seconds + t;
      var breath = 0.012 * math.sin(2 * math.pi * rate / 60 * t);
      var audible = -62.0 + rng.nextDouble() * 2;
      if (kind.isNotEmpty && t >= evStart && t < evStart + evDur) {
        breath *= kind == 'apnoea' ? 0.04 : 0.45;
      }
      if (kind.isNotEmpty &&
          t >= evStart + evDur &&
          t < evStart + evDur + 2.5) {
        audible += kind == 'apnoea' ? 22 : 13; // gasp / snore
      }
      final jitter = (rng.nextDouble() - 0.5) * 0.0015;
      final amp = lost
          ? 0.00004 + rng.nextDouble() * 0.00002
          : 0.10 + breath + jitter;
      final db = 20 * math.log(math.max(amp, 1e-7)) / math.ln10;
      out.add(SonarFeature(abs, amp, db, lost ? -70 : audible));
    }
    return out;
  }

  /// Number of epochs in a simulated night.
  static int epochCount(String outcome) =>
      (shape(outcome).hours * 3600 / SonarEpoch.seconds).round();

  /// Short synthetic 48 kHz take: a 19 kHz carrier whose amplitude is
  /// modulated by breathing at [rr] br/min, with optional apnoea windows
  /// (breathing stops) each followed by a 300 Hz gasp burst.
  static List<int> pcm({
    required double seconds,
    double rr = 15,
    int sampleRate = 48000,
    List<(double, double)> apnoeas = const [],
    bool echo = true,
    int seed = 3,
  }) {
    final rng = math.Random(seed);
    final n = (seconds * sampleRate).round();
    final out = List<int>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var breath = 0.012 * math.sin(2 * math.pi * rr / 60 * t);
      var gasp = 0.0;
      for (final (a, d) in apnoeas) {
        if (t >= a && t < a + d) breath = 0;
        if (t >= a + d && t < a + d + 1.5) {
          gasp = 0.15 * math.sin(2 * math.pi * 300 * t);
        }
      }
      final carrier = echo
          ? (0.10 + breath) * math.sin(2 * math.pi * 19000 * t)
          : 0.0;
      final noise = (rng.nextDouble() - 0.5) * 0.0004;
      out[i] = ((carrier + gasp + noise) * 32767).round().clamp(-32768, 32767);
    }
    return out;
  }
}
