// Movement-test signal processing (Doc 09 §9, ALG-MOV-01..05).
//
// Pure Dart, no Flutter imports, so every analyzer is unit-testable with the
// synthetic generators at the bottom. Units: time in seconds, accelerometer
// in m/s² (gravity included, as sensors_plus reports), gyroscope in deg/s.
import 'dart:math' as math;

/// One tri-axial sample at time [t] seconds.
class MotionSample {
  const MotionSample(this.t, this.x, this.y, this.z);

  final double t;
  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

/// One frame of the finger-tapping video: normalised thumb–index distance.
class TapSample {
  const TapSample(this.t, this.normDistance);

  final double t;
  final double normDistance;
}

/// One touch on the two-target pad.
class TouchTap {
  const TouchTap(this.tMs, this.target);

  final int tMs;

  /// 0 = target A, 1 = target B.
  final int target;
}

// ---------------------------------------------------------------------------
// DSP primitives
// ---------------------------------------------------------------------------

class Dsp {
  Dsp._();

  static double mean(List<double> x) =>
      x.isEmpty ? 0 : x.reduce((a, b) => a + b) / x.length;

  static double sd(List<double> x) {
    if (x.length < 2) return 0;
    final m = mean(x);
    var s = 0.0;
    for (final v in x) {
      s += (v - m) * (v - m);
    }
    return math.sqrt(s / (x.length - 1));
  }

  /// Coefficient of variation in percent.
  static double cvPct(List<double> x) {
    final m = mean(x);
    return m == 0 ? 0 : sd(x) / m * 100;
  }

  static double rms(List<double> x) {
    if (x.isEmpty) return 0;
    var s = 0.0;
    for (final v in x) {
      s += v * v;
    }
    return math.sqrt(s / x.length);
  }

  static double median(List<double> x) {
    if (x.isEmpty) return 0;
    final s = [...x]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }

  /// Second-order Butterworth low-pass, applied forward and backward
  /// (zero phase).
  static List<double> lowPass(List<double> x, double fs, double fc) =>
      _filtFilt(x, _biquadLowPass(fs, fc));

  static List<double> highPass(List<double> x, double fs, double fc) =>
      _filtFilt(x, _biquadHighPass(fs, fc));

  static List<double> bandPass(
    List<double> x,
    double fs,
    double lo,
    double hi,
  ) => lowPass(highPass(x, fs, lo), fs, hi);

  static List<double> _biquadLowPass(double fs, double fc) {
    final w = math.tan(math.pi * fc / fs);
    final k = 1 + math.sqrt2 * w + w * w;
    final b0 = w * w / k;
    return [
      b0,
      2 * b0,
      b0,
      2 * (w * w - 1) / k,
      (1 - math.sqrt2 * w + w * w) / k,
    ];
  }

  static List<double> _biquadHighPass(double fs, double fc) {
    final w = math.tan(math.pi * fc / fs);
    final k = 1 + math.sqrt2 * w + w * w;
    final b0 = 1 / k;
    return [
      b0,
      -2 * b0,
      b0,
      2 * (w * w - 1) / k,
      (1 - math.sqrt2 * w + w * w) / k,
    ];
  }

  static List<double> _biquad(List<double> x, List<double> c) {
    final b0 = c[0], b1 = c[1], b2 = c[2], a1 = c[3], a2 = c[4];
    final y = List<double>.filled(x.length, 0);
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    // Start from the first sample to limit the step transient.
    if (x.isNotEmpty) {
      x1 = x.first;
      x2 = x.first;
      y1 = x.first;
      y2 = x.first;
    }
    for (var i = 0; i < x.length; i++) {
      final v = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1;
      x1 = x[i];
      y2 = y1;
      y1 = v;
      y[i] = v;
    }
    return y;
  }

  static List<double> _filtFilt(List<double> x, List<double> c) {
    if (x.length < 4) return List<double>.from(x);
    final f = _biquad(x, c);
    final r = _biquad(f.reversed.toList(), c);
    return r.reversed.toList();
  }

  /// Linear resampling of irregular samples to a uniform [fs] grid.
  static List<MotionSample> resample(List<MotionSample> s, double fs) {
    if (s.length < 2) return List<MotionSample>.from(s);
    final out = <MotionSample>[];
    final dt = 1 / fs;
    var j = 0;
    for (var t = s.first.t; t <= s.last.t + 1e-9; t += dt) {
      while (j < s.length - 2 && s[j + 1].t < t) {
        j++;
      }
      final a = s[j];
      final b = s[j + 1];
      final span = b.t - a.t;
      final f = span <= 0 ? 0.0 : ((t - a.t) / span).clamp(0.0, 1.0);
      out.add(
        MotionSample(
          t,
          a.x + (b.x - a.x) * f,
          a.y + (b.y - a.y) * f,
          a.z + (b.z - a.z) * f,
        ),
      );
    }
    return out;
  }

  /// Achieved sample rate from timestamps (Hz) and the count of gaps longer
  /// than 2.5× the median period (dropped samples).
  static (double, int) rateAndDrops(List<MotionSample> s) {
    if (s.length < 3) return (0, 0);
    final gaps = <double>[];
    for (var i = 1; i < s.length; i++) {
      gaps.add(s[i].t - s[i - 1].t);
    }
    final med = median(gaps);
    if (med <= 0) return (0, 0);
    var drops = 0;
    for (final g in gaps) {
      if (g > 2.5 * med) drops += (g / med).round() - 1;
    }
    return (1 / med, drops);
  }

  static List<double> hann(int n) => [
    for (var i = 0; i < n; i++)
      0.5 - 0.5 * math.cos(2 * math.pi * i / math.max(1, n - 1)),
  ];

  /// Welch power spectral density (one-sided, Hann segments with overlap).
  /// Returns parallel lists of frequencies and power.
  static (List<double>, List<double>) welchPsd(
    List<double> x,
    double fs, {
    double segmentSeconds = 3.0,
    double overlap = 0.5,
    double maxFreq = 30,
  }) {
    final n = math.max(8, (segmentSeconds * fs).round());
    if (x.length < n) return (const [], const []);
    final hop = math.max(1, (n * (1 - overlap)).round());
    final w = hann(n);
    final wPow = w.map((v) => v * v).reduce((a, b) => a + b);
    final bins = math.min(n ~/ 2, (maxFreq * n / fs).floor());
    final psd = List<double>.filled(bins + 1, 0);
    var segs = 0;
    final cosT = List<double>.generate(n, (i) => 2 * math.pi * i / n);
    for (var start = 0; start + n <= x.length; start += hop) {
      final seg = List<double>.generate(n, (i) => x[start + i] * w[i]);
      final m = mean(seg);
      for (var i = 0; i < n; i++) {
        seg[i] -= m;
      }
      for (var k = 0; k <= bins; k++) {
        var re = 0.0, im = 0.0;
        for (var i = 0; i < n; i++) {
          final ang = cosT[i] * k;
          re += seg[i] * math.cos(ang);
          im -= seg[i] * math.sin(ang);
        }
        final p = (re * re + im * im) / (fs * wPow);
        psd[k] += k == 0 || k == n ~/ 2 ? p : 2 * p;
      }
      segs++;
    }
    if (segs == 0) return (const [], const []);
    final freqs = List<double>.generate(bins + 1, (k) => k * fs / n);
    return (freqs, psd.map((p) => p / segs).toList());
  }

  /// Indices of local maxima with a minimum separation and prominence.
  static List<int> findPeaks(
    List<double> x, {
    required int minDistance,
    required double minProminence,
  }) {
    final cand = <int>[];
    for (var i = 1; i < x.length - 1; i++) {
      if (x[i] > x[i - 1] && x[i] >= x[i + 1]) {
        final lo = math.max(0, i - 2 * minDistance);
        final hi = math.min(x.length - 1, i + 2 * minDistance);
        var minL = x[i], minR = x[i];
        for (var j = lo; j < i; j++) {
          if (x[j] < minL) minL = x[j];
        }
        for (var j = i + 1; j <= hi; j++) {
          if (x[j] < minR) minR = x[j];
        }
        final prominence = x[i] - math.max(minL, minR);
        if (prominence >= minProminence) cand.add(i);
      }
    }
    // Enforce minimum distance, keeping the taller peak.
    final kept = <int>[];
    for (final i in cand) {
      if (kept.isNotEmpty && i - kept.last < minDistance) {
        if (x[i] > x[kept.last]) kept[kept.length - 1] = i;
      } else {
        kept.add(i);
      }
    }
    return kept;
  }

  /// Best normalised autocorrelation in a lag window → (lag seconds, r).
  static (double, double) periodicity(
    List<double> x,
    double fs, {
    required double minLagS,
    required double maxLagS,
  }) {
    final n = x.length;
    if (n < 8) return (0, 0);
    final m = mean(x);
    final c = x.map((v) => v - m).toList();
    var denom = 0.0;
    for (final v in c) {
      denom += v * v;
    }
    if (denom == 0) return (0, 0);
    var bestR = -1.0;
    var bestLag = 0;
    final lo = (minLagS * fs).round();
    final hi = math.min(n - 2, (maxLagS * fs).round());
    for (var lag = lo; lag <= hi; lag++) {
      var num = 0.0;
      for (var i = 0; i + lag < n; i++) {
        num += c[i] * c[i + lag];
      }
      final r = num / denom;
      if (r > bestR) {
        bestR = r;
        bestLag = lag;
      }
    }
    return (bestLag / fs, bestR);
  }

  /// Vertical (gravity-axis) acceleration: project each sample on the
  /// low-passed gravity direction and remove the static 1 g.
  static List<double> verticalAxis(List<MotionSample> s, double fs) {
    final gx = lowPass(s.map((e) => e.x).toList(), fs, 0.25);
    final gy = lowPass(s.map((e) => e.y).toList(), fs, 0.25);
    final gz = lowPass(s.map((e) => e.z).toList(), fs, 0.25);
    final out = List<double>.filled(s.length, 0);
    for (var i = 0; i < s.length; i++) {
      final g = math.sqrt(gx[i] * gx[i] + gy[i] * gy[i] + gz[i] * gz[i]);
      if (g == 0) continue;
      final dot = (s[i].x * gx[i] + s[i].y * gy[i] + s[i].z * gz[i]) / g;
      out[i] = dot - g;
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// ALG-MOV-01 — finger tapping (video)
// ---------------------------------------------------------------------------

class TapMetrics {
  const TapMetrics({
    required this.count,
    required this.freqHz,
    required this.decrementPct,
    required this.cvPct,
    required this.intervalsS,
    required this.durationS,
    required this.fps,
  });

  final int count;
  final double freqHz;
  final double decrementPct;
  final double cvPct;
  final List<double> intervalsS;
  final double durationS;
  final double fps;

  static const TapMetrics empty = TapMetrics(
    count: 0,
    freqHz: 0,
    decrementPct: 0,
    cvPct: 0,
    intervalsS: [],
    durationS: 0,
    fps: 0,
  );
}

/// Incremental tap detector on the normalised thumb–index distance.
///
/// A tap is one open → close swing. Instead of a fixed threshold, the
/// detector follows the signal's reversals ("zigzag"): a peak is confirmed
/// once the distance has fallen by [threshold] below the running maximum,
/// a trough once it has risen by [threshold] above the running minimum.
/// The threshold is a fraction of the recent tap size (EMA) with a floor,
/// so taps that shrink (decrement) still count while landmark jitter does
/// not. It needs no uniform sampling and only one sample per half-cycle,
/// which keeps it accurate at the 12–30 fps a phone actually delivers.
/// Used live (per frame) and by [TapSeriesAnalyzer] on the full series.
class TapReversalCounter {
  TapReversalCounter({
    this.floor = 0.05,
    this.fraction = 0.12,
    this.minIntervalS = 0.07,
  });

  /// Smallest swing ever counted (normalised units; rest jitter ≈ 0.02).
  final double floor;

  /// Threshold as a share of the recent tap amplitude.
  final double fraction;

  /// Refractory period between counted peaks (≈ 14 Hz ceiling).
  final double minIntervalS;

  final List<int> peakIndices = [];
  final List<double> peakTimes = [];
  final List<double> amplitudes = [];

  double _ampEma = 0;
  bool _seekPeak = true;
  bool _started = false;
  double _max = 0, _min = 0, _lastTrough = 0;
  int _maxIdx = 0;
  double _maxT = 0;
  double _lastPeakT = -1e9;

  int get count => peakIndices.length;

  /// Recent tap amplitude (EMA) and the last confirmed amplitude.
  double get recentAmplitude => _ampEma;
  double get lastAmplitude => amplitudes.isEmpty ? 0 : amplitudes.last;

  /// End of recording: a hand left open at the last peak has not fallen
  /// back yet, so the peak would never confirm. Count it if it is a real
  /// swing above the trough before it.
  bool flush() {
    if (!_started || !_seekPeak) return false;
    final amp = _max - _lastTrough;
    if (amp >= threshold && _maxT - _lastPeakT >= minIntervalS) {
      _seekPeak = false;
      _lastPeakT = _maxT;
      peakIndices.add(_maxIdx);
      peakTimes.add(_maxT);
      amplitudes.add(amp);
      return true;
    }
    return false;
  }

  double get threshold =>
      _ampEma <= 0 ? floor : math.max(floor, fraction * _ampEma);

  /// Feed one sample; returns true when a tap (peak) was just confirmed.
  bool add(int index, double t, double d) {
    if (!_started) {
      _started = true;
      _max = _min = _lastTrough = d;
      _maxIdx = index;
      _maxT = t;
      return false;
    }
    final thr = threshold;
    if (_seekPeak) {
      if (d > _max) {
        _max = d;
        _maxIdx = index;
        _maxT = t;
      } else if (_max - d >= thr) {
        // Peak confirmed at the running maximum.
        _seekPeak = false;
        _min = d;
        if (_maxT - _lastPeakT >= minIntervalS) {
          final amp = _max - _lastTrough;
          _lastPeakT = _maxT;
          peakIndices.add(_maxIdx);
          peakTimes.add(_maxT);
          amplitudes.add(amp);
          _ampEma = _ampEma <= 0 ? amp : 0.5 * _ampEma + 0.5 * amp;
          return true;
        }
      }
    } else {
      if (d < _min) {
        _min = d;
      } else if (d - _min >= thr) {
        // Trough confirmed; the next peak's amplitude is measured from it.
        _lastTrough = _min;
        _seekPeak = true;
        _max = d;
        _maxIdx = index;
        _maxT = t;
      }
    }
    return false;
  }
}

class TapSeriesAnalyzer {
  TapSeriesAnalyzer._();

  /// Reversals of the normalised thumb–index distance are taps
  /// ([TapReversalCounter]). Amplitude of a tap = peak minus the trough
  /// before it; decrement = % drop of the mean amplitude from the first 3 s
  /// to the last 3 s (Spec §9 MOV-01).
  static TapMetrics analyze(List<TapSample> samples) {
    if (samples.length < 6) return TapMetrics.empty;
    final t0 = samples.first.t;
    final duration = samples.last.t - t0;
    if (duration <= 0.5) return TapMetrics.empty;
    final fps = (samples.length - 1) / duration;
    // Median-of-3 kills single-frame landmark glitches and, unlike a moving
    // average, keeps the peaks of fast taps. Below 24 fps a tap can be only
    // three samples long, which a median would flatten, so the raw series
    // is used there and the reversal threshold alone rejects glitches.
    final d = samples.map((s) => s.normDistance).toList();
    final sm = fps < 24
        ? d
        : List<double>.generate(d.length, (i) {
            final a = d[math.max(0, i - 1)];
            final b = d[i];
            final c = d[math.min(d.length - 1, i + 1)];
            return math.max(math.min(a, b), math.min(math.max(a, b), c));
          });
    final sorted = List<double>.from(sm)..sort();
    final robustRange =
        sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)] -
        sorted[(sorted.length * 0.05).floor().clamp(0, sorted.length - 1)];
    if (robustRange < 0.03) return TapMetrics.empty;
    final counter = TapReversalCounter(
      floor: math.max(0.05, 0.10 * robustRange),
    );
    for (var i = 0; i < sm.length; i++) {
      counter.add(i, samples[i].t - t0, sm[i]);
    }
    counter.flush();
    final peaks = counter.peakIndices;
    if (peaks.isEmpty) return TapMetrics.empty;
    final times = counter.peakTimes;
    final amps = counter.amplitudes;
    final intervals = <double>[];
    for (var i = 1; i < times.length; i++) {
      intervals.add(times[i] - times[i - 1]);
    }
    final first = <double>[], last = <double>[];
    for (var i = 0; i < times.length; i++) {
      if (times[i] <= 3.0) first.add(amps[i]);
      if (times[i] >= duration - 3.0) last.add(amps[i]);
    }
    var decrement = 0.0;
    if (first.isNotEmpty && last.isNotEmpty) {
      final f = Dsp.mean(first);
      final l = Dsp.mean(last);
      if (f > 0) decrement = ((f - l) / f * 100).clamp(0.0, 100.0);
    }
    return TapMetrics(
      count: peaks.length,
      freqHz: peaks.length / duration,
      decrementPct: decrement,
      cvPct: Dsp.cvPct(intervals),
      intervalsS: intervals,
      durationS: duration,
      fps: fps,
    );
  }
}

// ---------------------------------------------------------------------------
// ALG-MOV-02 — finger tapping (touch)
// ---------------------------------------------------------------------------

class TouchMetrics {
  const TouchMetrics({
    required this.alternatingCount,
    required this.interTapCvPct,
    required this.misses,
    required this.intervalsMs,
  });

  final int alternatingCount;
  final double interTapCvPct;

  /// Taps on the same target twice in a row (not counted).
  final int misses;
  final List<double> intervalsMs;

  bool get tooFew => alternatingCount < 5;
}

class TouchTapAnalyzer {
  TouchTapAnalyzer._();

  static TouchMetrics analyze(List<TouchTap> taps) {
    if (taps.isEmpty) {
      return const TouchMetrics(
        alternatingCount: 0,
        interTapCvPct: 0,
        misses: 0,
        intervalsMs: [],
      );
    }
    final counted = <TouchTap>[taps.first];
    var misses = 0;
    for (var i = 1; i < taps.length; i++) {
      if (taps[i].target != counted.last.target) {
        counted.add(taps[i]);
      } else {
        misses++;
      }
    }
    final intervals = <double>[];
    for (var i = 1; i < counted.length; i++) {
      intervals.add((counted[i].tMs - counted[i - 1].tMs).toDouble());
    }
    return TouchMetrics(
      alternatingCount: counted.length,
      interTapCvPct: Dsp.cvPct(intervals),
      misses: misses,
      intervalsMs: intervals,
    );
  }
}

// ---------------------------------------------------------------------------
// ALG-MOV-03 — gait (10-metre walk)
// ---------------------------------------------------------------------------

class GaitMetrics {
  const GaitMetrics({
    required this.steps,
    required this.cadenceSpm,
    required this.stepCvPct,
    required this.speedMs,
    required this.walkDurationS,
    required this.periodic,
    required this.achievedHz,
    required this.droppedSamples,
  });

  final int steps;
  final double cadenceSpm;
  final double stepCvPct;
  final double speedMs;
  final double walkDurationS;

  /// A walking rhythm was found (autocorrelation in the step band).
  final bool periodic;
  final double achievedHz;
  final int droppedSamples;

  bool get valid => periodic && steps >= 5;
}

class GaitAnalyzer {
  GaitAnalyzer._();

  static GaitMetrics analyze(
    List<MotionSample> raw, {
    double distanceM = 10.0,
    double fs = 50.0,
  }) {
    final (hz, drops) = Dsp.rateAndDrops(raw);
    if (raw.length < fs * 2) {
      return GaitMetrics(
        steps: 0,
        cadenceSpm: 0,
        stepCvPct: 0,
        speedMs: 0,
        walkDurationS: 0,
        periodic: false,
        achievedHz: hz,
        droppedSamples: drops,
      );
    }
    final s = Dsp.resample(raw, fs);
    final vert = Dsp.verticalAxis(s, fs);
    final bp = Dsp.bandPass(vert, fs, 0.5, 3.0);
    // Heel strikes: at least 0.8 m/s² above the surrounding troughs so
    // sensor noise while standing still never counts as steps [DER].
    final peaks = Dsp.findPeaks(
      bp,
      minDistance: (0.25 * fs).round(),
      minProminence: math.max(0.8, 0.3 * Dsp.rms(bp)),
    );
    final (_, r) = Dsp.periodicity(bp, fs, minLagS: 0.33, maxLagS: 1.0);
    final periodic = r >= 0.35 && peaks.length >= 5;
    final times = peaks.map((i) => s[i].t).toList();
    final intervals = <double>[];
    for (var i = 1; i < times.length; i++) {
      intervals.add(times[i] - times[i - 1]);
    }
    var duration = 0.0;
    if (times.length >= 2) {
      // First to last heel strike plus one mean step (the step that ends at
      // the finish line) [DER].
      duration = times.last - times.first + Dsp.mean(intervals);
    }
    return GaitMetrics(
      steps: peaks.length,
      cadenceSpm: duration > 0 ? peaks.length / duration * 60 : 0,
      stepCvPct: Dsp.cvPct(intervals),
      speedMs: duration > 0 ? distanceM / duration : 0,
      walkDurationS: duration,
      periodic: periodic,
      achievedHz: hz,
      droppedSamples: drops,
    );
  }
}

// ---------------------------------------------------------------------------
// ALG-MOV-04 — 30-second sit-to-stand
// ---------------------------------------------------------------------------

class StsMetrics {
  const StsMetrics({
    required this.count,
    required this.cycleTimesS,
    required this.dropout,
    required this.achievedHz,
    required this.droppedSamples,
  });

  final int count;
  final List<double> cycleTimesS;
  final bool dropout;
  final double achievedHz;
  final int droppedSamples;
}

class StsCycleCounter {
  StsCycleCounter._();

  /// Counts completed stand–sit cycles from vertical acceleration low-passed
  /// to 0.2–2 Hz (Spec §9 MOV-04). A cycle is a rise peak at least 1.0 m/s²
  /// above its surrounding troughs and ≥ 0.8 s after the previous one [DER].
  static StsMetrics analyze(List<MotionSample> raw, {double fs = 50.0}) {
    final (hz, drops) = Dsp.rateAndDrops(raw);
    var gap = 0.0;
    for (var i = 1; i < raw.length; i++) {
      gap = math.max(gap, raw[i].t - raw[i - 1].t);
    }
    final dropout = raw.length < fs * 2 || gap > 0.5 || hz < 25;
    if (raw.length < fs * 2) {
      return StsMetrics(
        count: 0,
        cycleTimesS: const [],
        dropout: true,
        achievedHz: hz,
        droppedSamples: drops,
      );
    }
    final s = Dsp.resample(raw, fs);
    final vert = Dsp.verticalAxis(s, fs);
    final bp = Dsp.bandPass(vert, fs, 0.2, 2.0);
    final peaks = Dsp.findPeaks(
      bp,
      minDistance: (0.8 * fs).round(),
      minProminence: 1.0,
    );
    return StsMetrics(
      count: peaks.length,
      cycleTimesS: peaks.map((i) => s[i].t - s.first.t).toList(),
      dropout: dropout,
      achievedHz: hz,
      droppedSamples: drops,
    );
  }
}

// ---------------------------------------------------------------------------
// ALG-MOV-05 — postural / rest tremor
// ---------------------------------------------------------------------------

class TremorMetrics {
  const TremorMetrics({
    required this.freqHz,
    required this.ampDegS,
    required this.peakAboveFloor,
    required this.grossMovement,
    required this.floorPsd,
    required this.peakPsd,
    required this.achievedHz,
    required this.droppedSamples,
  });

  /// Dominant 3–12 Hz peak (null when nothing rises above the floor).
  final double? freqHz;
  final double? ampDegS;
  final bool peakAboveFloor;

  /// Voluntary gross arm movement (< 2 Hz, high amplitude) → restart.
  final bool grossMovement;
  final double floorPsd;
  final double peakPsd;
  final double achievedHz;
  final int droppedSamples;

  /// Peak-to-floor power ratio (shown in the quality expander).
  double get peakRatio => floorPsd > 0 ? peakPsd / floorPsd : 0;
}

class TremorAnalyzer {
  TremorAnalyzer._();

  /// [raw] in deg/s. Welch PSD over 3–12 Hz; the device noise floor is the
  /// median PSD between 14 Hz and the Nyquist limit [DER]; a peak counts when
  /// it is at least [floorRatio]× the floor.
  static TremorMetrics analyze(
    List<MotionSample> raw, {
    double fs = 100.0,
    double floorRatio = 6.0,
  }) {
    final (hz, drops) = Dsp.rateAndDrops(raw);
    if (raw.length < fs * 3) {
      return TremorMetrics(
        freqHz: null,
        ampDegS: null,
        peakAboveFloor: false,
        grossMovement: false,
        floorPsd: 0,
        peakPsd: 0,
        achievedHz: hz,
        droppedSamples: drops,
      );
    }
    final s = Dsp.resample(raw, fs);
    // The spec's resultant |ω| rectifies an oscillation (doubling its
    // frequency), so the spectrum is taken per axis and summed — the PSD of
    // the angular-velocity vector — which keeps the true tremor frequency
    // [DER]. Amplitudes combine the axes as a vector RMS.
    final axes =
        [
          s.map((e) => e.x).toList(),
          s.map((e) => e.y).toList(),
          s.map((e) => e.z).toList(),
        ].map((a) {
          final m = Dsp.mean(a);
          return a.map((v) => v - m).toList();
        }).toList();

    // Gross voluntary movement: 0.3–2 Hz vector RMS above 40 deg/s in any
    // 1-s window.
    final slow = axes.map((a) => Dsp.bandPass(a, fs, 0.3, 2.0)).toList();
    var gross = false;
    final win = fs.round();
    for (var start = 0; start + win <= slow[0].length; start += win ~/ 2) {
      var sq = 0.0;
      for (final a in slow) {
        final r = Dsp.rms(a.sublist(start, start + win));
        sq += r * r;
      }
      if (math.sqrt(sq) > 40) {
        gross = true;
        break;
      }
    }

    List<double> freqs = const [];
    List<double> psd = const [];
    for (final a in axes) {
      final (f, p) = Dsp.welchPsd(a, fs, maxFreq: math.min(30, fs / 2));
      if (f.isEmpty) continue;
      if (freqs.isEmpty) {
        freqs = f;
        psd = List<double>.from(p);
      } else {
        for (var k = 0; k < psd.length && k < p.length; k++) {
          psd[k] += p[k];
        }
      }
    }
    if (freqs.isEmpty) {
      return TremorMetrics(
        freqHz: null,
        ampDegS: null,
        peakAboveFloor: false,
        grossMovement: gross,
        floorPsd: 0,
        peakPsd: 0,
        achievedHz: hz,
        droppedSamples: drops,
      );
    }
    var peakIdx = -1;
    var peakPsd = 0.0;
    final floorVals = <double>[];
    final floorHi = math.max(16.0, fs / 2 - 1);
    for (var k = 0; k < freqs.length; k++) {
      final f = freqs[k];
      if (f >= 3 && f <= 12 && psd[k] > peakPsd) {
        peakPsd = psd[k];
        peakIdx = k;
      }
      if (f >= 14 && f <= floorHi) floorVals.add(psd[k]);
    }
    final floor = floorVals.isEmpty ? 0.0 : Dsp.median(floorVals);
    final above = peakIdx >= 0 && floor > 0 && peakPsd >= floorRatio * floor;
    var bandSq = 0.0;
    for (final a in axes) {
      final r = Dsp.rms(Dsp.bandPass(a, fs, 3.0, 12.0));
      bandSq += r * r;
    }
    return TremorMetrics(
      freqHz: above ? freqs[peakIdx] : null,
      ampDegS: above ? math.sqrt(bandSq) : null,
      peakAboveFloor: above,
      grossMovement: gross,
      floorPsd: floor,
      peakPsd: peakPsd,
      achievedHz: hz,
      droppedSamples: drops,
    );
  }
}

// ---------------------------------------------------------------------------
// Deterministic synthetic signals for tests and simulated runs
// ---------------------------------------------------------------------------

class MovementSynthetic {
  MovementSynthetic._();

  static math.Random _rng(int seed) => math.Random(seed);

  static double _gauss(math.Random r) {
    final u1 = 1 - r.nextDouble();
    final u2 = r.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  /// Thumb–index distance series: taps at [hz] with the amplitude falling by
  /// [decrementPct] % over the recording.
  static List<TapSample> tapping({
    double fps = 30,
    double hz = 4,
    double decrementPct = 10,
    double seconds = 10,
    int seed = 1,
  }) {
    final r = _rng(seed);
    final out = <TapSample>[];
    final n = (fps * seconds).round();
    for (var i = 0; i <= n; i++) {
      final t = i / fps;
      final amp = 1 - decrementPct / 100 * (t / seconds);
      final v =
          0.5 +
          0.4 * amp * (0.5 + 0.5 * math.sin(2 * math.pi * hz * t)) +
          0.01 * _gauss(r);
      out.add(TapSample(t, v));
    }
    return out;
  }

  /// Phone in a pocket while walking: vertical 1 g plus a step oscillation.
  static List<MotionSample> walking({
    double stepHz = 1.8,
    double seconds = 8,
    double fs = 50,
    int seed = 2,
  }) {
    final r = _rng(seed);
    final out = <MotionSample>[];
    final n = (fs * seconds).round();
    for (var i = 0; i <= n; i++) {
      final t = i / fs;
      out.add(
        MotionSample(
          t,
          0.3 * _gauss(r) + 0.8 * math.sin(2 * math.pi * stepHz / 2 * t),
          0.3 * _gauss(r),
          9.81 + 2.5 * math.sin(2 * math.pi * stepHz * t) + 0.3 * _gauss(r),
        ),
      );
    }
    return out;
  }

  /// Standing still (no walking rhythm).
  static List<MotionSample> standingStill({
    double seconds = 8,
    double fs = 50,
    int seed = 3,
  }) {
    final r = _rng(seed);
    return [
      for (var i = 0; i <= (fs * seconds).round(); i++)
        MotionSample(
          i / fs,
          0.15 * _gauss(r),
          0.15 * _gauss(r),
          9.81 + 0.15 * _gauss(r),
        ),
    ];
  }

  /// [cycles] stand–sit cycles over [seconds].
  static List<MotionSample> sitToStand({
    int cycles = 12,
    double seconds = 30,
    double fs = 50,
    int seed = 4,
  }) {
    final r = _rng(seed);
    final f = cycles / seconds;
    final out = <MotionSample>[];
    final n = (fs * seconds).round();
    for (var i = 0; i <= n; i++) {
      final t = i / fs;
      out.add(
        MotionSample(
          t,
          0.2 * _gauss(r),
          0.2 * _gauss(r),
          9.81 + 2.0 * math.sin(2 * math.pi * f * t) + 0.2 * _gauss(r),
        ),
      );
    }
    return out;
  }

  /// Gyroscope (deg/s) with a tremor at [hz] of [ampDegS] on top of noise.
  static List<MotionSample> tremor({
    double hz = 5,
    double ampDegS = 30,
    double noiseDegS = 2,
    double seconds = 20,
    double fs = 100,
    int seed = 5,
  }) {
    final r = _rng(seed);
    final out = <MotionSample>[];
    final n = (fs * seconds).round();
    for (var i = 0; i <= n; i++) {
      final t = i / fs;
      final trem = ampDegS * math.sin(2 * math.pi * hz * t);
      out.add(
        MotionSample(
          t,
          trem * 0.8 + noiseDegS * _gauss(r),
          trem * 0.5 + noiseDegS * _gauss(r),
          noiseDegS * _gauss(r),
        ),
      );
    }
    return out;
  }

  /// A steady hand: sensor noise only.
  static List<MotionSample> stillHand({
    double seconds = 20,
    double fs = 100,
    double noiseDegS = 1.5,
    int seed = 6,
  }) => tremor(
    hz: 5,
    ampDegS: 0,
    noiseDegS: noiseDegS,
    seconds: seconds,
    fs: fs,
    seed: seed,
  );

  /// Slow voluntary arm movement (1 Hz, 80 deg/s).
  static List<MotionSample> grossMovement({
    double seconds = 20,
    double fs = 100,
    int seed = 7,
  }) => tremor(
    hz: 1,
    ampDegS: 80,
    noiseDegS: 2,
    seconds: seconds,
    fs: fs,
    seed: seed,
  );
}
