// Pure-Dart engines for the hearing screen (Doc 09 §8 ALG-AUD-09 and
// ALG-CAP-12). No Flutter imports; unit-tested in test/hearing_engines_test.
import 'dart:math' as math;

import '../entities/hearing_protocol.dart';

/// Test frequencies of the document, in the standard presentation order
/// (1 kHz first, 500 Hz last).
const List<int> hearingFrequenciesHz = [500, 1000, 2000, 4000];
const List<int> hearingTestOrderHz = [1000, 2000, 4000, 500];

// ---------------------------------------------------------------------------
// Tone level ↔ player gain (earphone calibration pending, OQ-REQ-15 [DER])
// ---------------------------------------------------------------------------

class ToneLevel {
  ToneLevel._();

  /// Assumed hearing level of a full-scale tone at maximum phone volume
  /// through typical earphones [DER]; the member can replace it from a
  /// clinic audiogram.
  static const double defaultFullScaleDbHl = 90.0;

  static const double minDbHl = 0.0;
  static const double maxDbHl = 80.0;

  /// Recorded value when the member does not respond at [maxDbHl].
  static const double noResponseDbHl = 85.0;

  /// Linear player gain (0..1) for a tone at [dbHl].
  static double gainFor(
    double dbHl, {
    double fullScaleDbHl = defaultFullScaleDbHl,
  }) {
    final g = math.pow(10, (dbHl - fullScaleDbHl) / 20).toDouble();
    return g.clamp(0.0, 1.0);
  }

  /// Calibration from a known threshold: the clinic says 1 kHz = [knownDbHl]
  /// and this phone found [measuredDbHl] with the assumed full scale.
  static double fullScaleFromKnown({
    required double knownDbHl,
    required double measuredDbHl,
    double assumedFullScaleDbHl = defaultFullScaleDbHl,
  }) => assumedFullScaleDbHl + (knownDbHl - measuredDbHl);
}

// ---------------------------------------------------------------------------
// Mode A — Hughson–Westlake staircase (up 5 / down 10, Spec §8)
// ---------------------------------------------------------------------------

class TonePresentation {
  const TonePresentation({
    required this.ear,
    required this.hz,
    required this.dbHl,
    required this.isCatch,
    required this.heard,
    this.latencyMs,
  });

  final HearingEar ear;
  final int hz;
  final double dbHl;

  /// Silent trial: nothing was played.
  final bool isCatch;
  final bool heard;
  final double? latencyMs;
}

/// One frequency in one ear. Document: up 5 dB on a miss, down 10 dB on a
/// hit. [DER] details: start 40 dB HL, threshold = lowest level heard on 2 of
/// 3 rising runs, range 0–80 dB HL, 1-in-6 silent catch trials.
class HughsonWestlake {
  HughsonWestlake({
    required this.ear,
    required this.hz,
    this.startDbHl = 40,
    int seed = 1,
  }) : _rng = math.Random(seed),
       level = startDbHl;

  final HearingEar ear;
  final int hz;
  final double startDbHl;
  final math.Random _rng;

  static const double stepUp = 5;
  static const double stepDown = 10;
  static const int maxPresentations = 22;
  static const double catchShare = 1 / 6;

  double level;
  bool done = false;
  double? threshold;
  bool noResponse = false;
  final List<TonePresentation> presentations = [];
  final Map<double, int> _ascAsks = {};
  final Map<double, int> _ascHits = {};
  bool _lastMoveUp = false;
  bool _pendingCatch = false;
  int _floorHits = 0;

  int get catchTrials => presentations.where((p) => p.isCatch).length;
  int get falsePositives =>
      presentations.where((p) => p.isCatch && p.heard).length;
  int get toneTrials => presentations.where((p) => !p.isCatch).length;

  /// Decide the next presentation: a tone at [level] or a silent catch.
  /// Returns true when the next trial is silent.
  bool nextIsCatch() {
    final lastWasCatch = presentations.isNotEmpty && presentations.last.isCatch;
    _pendingCatch =
        !lastWasCatch &&
        presentations.isNotEmpty &&
        _rng.nextDouble() < catchShare;
    return _pendingCatch;
  }

  /// Record the member's response to the trial announced by [nextIsCatch].
  void answer(bool heard, {double? latencyMs}) {
    if (done) return;
    final isCatch = _pendingCatch;
    _pendingCatch = false;
    presentations.add(
      TonePresentation(
        ear: ear,
        hz: hz,
        dbHl: isCatch ? level : level,
        isCatch: isCatch,
        heard: heard,
        latencyMs: latencyMs,
      ),
    );
    if (isCatch) {
      _checkCap();
      return;
    }
    if (_lastMoveUp) {
      _ascAsks[level] = (_ascAsks[level] ?? 0) + 1;
      if (heard) _ascHits[level] = (_ascHits[level] ?? 0) + 1;
      if ((_ascHits[level] ?? 0) >= 2) {
        threshold = level;
        done = true;
        return;
      }
    }
    if (heard) {
      if (level <= ToneLevel.minDbHl) {
        _floorHits++;
        if (_floorHits >= 2) {
          threshold = ToneLevel.minDbHl;
          done = true;
          return;
        }
      }
      level = math.max(ToneLevel.minDbHl, level - stepDown);
      _lastMoveUp = false;
    } else {
      if (level >= ToneLevel.maxDbHl) {
        noResponse = true;
        threshold = ToneLevel.noResponseDbHl;
        done = true;
        return;
      }
      level = math.min(ToneLevel.maxDbHl, level + stepUp);
      _lastMoveUp = true;
    }
    _checkCap();
  }

  void _checkCap() {
    if (presentations.length < maxPresentations) return;
    // Best estimate: the lowest level with any rising-run hit, else the
    // current level.
    double? best;
    for (final e in _ascHits.entries) {
      if (e.value > 0 && (best == null || e.key < best)) best = e.key;
    }
    threshold = best ?? level;
    done = true;
  }
}

// ---------------------------------------------------------------------------
// Mode B — digits in noise (hearWHO-style adaptive SNR [DER])
// ---------------------------------------------------------------------------

class DinTrial {
  const DinTrial({
    required this.digits,
    required this.answered,
    required this.snrDb,
  });

  final List<int> digits;
  final List<int> answered;
  final double snrDb;

  bool get correct =>
      answered.length == digits.length &&
      [
        for (var i = 0; i < digits.length; i++) answered[i] == digits[i],
      ].every((x) => x);
}

class DigitsInNoise {
  DigitsInNoise({int seed = 1}) : _rng = math.Random(seed);

  final math.Random _rng;

  static const int totalTriplets = 23;
  static const double startSnrDb = 0;
  static const double stepDb = 2;
  static const int scoredFrom = 3; // rounds 4..23 (0-based index 3)
  static const double minSnrDb = -20;
  static const double maxSnrDb = 10;

  double snrDb = startSnrDb;
  final List<DinTrial> trials = [];
  List<int>? _current;

  bool get done => trials.length >= totalTriplets;

  /// The next triplet (three distinct digits 0–9) at the current SNR.
  List<int> next() {
    if (_current != null) return _current!;
    final pool = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(_rng);
    return _current = pool.take(3).toList();
  }

  void answer(List<int> answered) {
    if (done) return;
    final digits = _current ?? next();
    _current = null;
    final t = DinTrial(digits: digits, answered: answered, snrDb: snrDb);
    trials.add(t);
    snrDb = (snrDb + (t.correct ? -stepDb : stepDb)).clamp(minSnrDb, maxSnrDb);
  }

  /// Speech reception threshold: mean presented SNR of rounds 4–23.
  double? get srtDb {
    if (trials.length <= scoredFrom) return null;
    final scored = trials.sublist(scoredFrom);
    return scored.map((t) => t.snrDb).reduce((a, b) => a + b) / scored.length;
  }

  /// Player gains: noise fixed at −6 dBFS, speech from the SNR [DER].
  static double noiseGain() => math.pow(10, -6 / 20).toDouble();
  static double speechGain(double snrDb) =>
      (noiseGain() * math.pow(10, snrDb / 20)).clamp(0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Grading (WHO 2021, better ear) and asymmetry
// ---------------------------------------------------------------------------

enum HearingGrade {
  normal('normal', 'Normal'),
  mild('mild', 'Mild loss'),
  moderate('moderate', 'Moderate loss'),
  severe('severe', 'Severe loss');

  const HearingGrade(this.code, this.label);
  final String code;
  final String label;
}

class HearingGrading {
  HearingGrading._();

  static const double whoNormalMaxDbHl = 20; // Spec §8: < 20 normal
  static const double mildMaxDbHl = 35; // [DER] WHO 2021 grades
  static const double moderateMaxDbHl = 50;
  static const double asymmetryDb = 15; // [DER]

  /// Four-frequency pure-tone average; "no response" counts as 85.
  static double? pta4(Map<int, double> thresholds) {
    final vals = [
      for (final hz in hearingFrequenciesHz)
        if (thresholds[hz] != null) thresholds[hz]!,
    ];
    if (vals.length < hearingFrequenciesHz.length) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  static HearingGrade grade(double ptaDbHl) => ptaDbHl < whoNormalMaxDbHl
      ? HearingGrade.normal
      : ptaDbHl < mildMaxDbHl
      ? HearingGrade.mild
      : ptaDbHl < moderateMaxDbHl
      ? HearingGrade.moderate
      : HearingGrade.severe;

  /// Largest per-frequency difference between ears.
  static double? maxAsymmetry(Map<int, double> r, Map<int, double> l) {
    double? m;
    for (final hz in hearingFrequenciesHz) {
      final a = r[hz], b = l[hz];
      if (a == null || b == null) continue;
      final d = (a - b).abs();
      if (m == null || d > m) m = d;
    }
    return m;
  }

  /// [DER]: ≥ 15 dB difference at two or more frequencies → ENT note.
  static bool asymmetric(Map<int, double> r, Map<int, double> l) {
    var n = 0;
    for (final hz in hearingFrequenciesHz) {
      final a = r[hz], b = l[hz];
      if (a != null && b != null && (a - b).abs() >= asymmetryDb) n++;
    }
    return n >= 2;
  }
}

// ---------------------------------------------------------------------------
// ALG-CAP-12 room noise
// ---------------------------------------------------------------------------

class NoiseLevel {
  NoiseLevel._();

  static const double maxDba = 45.0; // Spec §2 CAP-12 / G-18
  static const double windowS = 3.0;

  /// Per-device microphone offset: 0 dBFS ≈ [defaultMicOffsetDba] dBA
  /// [DER]; the document's table is per `mst_device_model`.
  static const double defaultMicOffsetDba = 75.0;

  static double dbaFromDbfs(
    double dbfs, {
    double offset = defaultMicOffsetDba,
  }) => (dbfs + offset).clamp(20.0, 100.0);

  static bool passes(double dba) => dba <= maxDba;
}

/// Running 3 s window used for the pre-test check and the in-test monitor.
class NoiseWindow {
  NoiseWindow({this.windowS = NoiseLevel.windowS});

  final double windowS;
  final List<(double t, double dba)> _samples = [];

  void add(double tSeconds, double dba) {
    _samples.add((tSeconds, dba));
    _samples.removeWhere((s) => tSeconds - s.$1 > windowS);
  }

  double? get meanDba => _samples.isEmpty
      ? null
      : _samples.map((s) => s.$2).reduce((a, b) => a + b) / _samples.length;
  double? get maxDba =>
      _samples.isEmpty ? null : _samples.map((s) => s.$2).reduce(math.max);
  double get spanS =>
      _samples.isEmpty ? 0 : _samples.last.$1 - _samples.first.$1;
  bool get complete => spanS >= windowS - 0.3;
  bool get passes => meanDba != null && NoiseLevel.passes(meanDba!);
}

// ---------------------------------------------------------------------------
// Simulated listeners (Test Controls / FLUTTER_TEST)
// ---------------------------------------------------------------------------

class HearingSimulated {
  HearingSimulated._();

  /// True thresholds per ear for a demo outcome.
  static Map<HearingEar, Map<int, double>> thresholds(HearingDemoOutcome o) =>
      switch (o) {
        HearingDemoOutcome.normal => {
          HearingEar.right: {500: 10, 1000: 5, 2000: 10, 4000: 15},
          HearingEar.left: {500: 10, 1000: 10, 2000: 5, 4000: 15},
        },
        HearingDemoOutcome.borderline => {
          HearingEar.right: {500: 20, 1000: 25, 2000: 25, 4000: 30},
          HearingEar.left: {500: 20, 1000: 20, 2000: 25, 4000: 35},
        },
        HearingDemoOutcome.refer => {
          HearingEar.right: {500: 40, 1000: 45, 2000: 50, 4000: 60},
          HearingEar.left: {500: 25, 1000: 30, 2000: 30, 4000: 40},
        },
      };

  /// Hears when the level reaches the threshold (5 % lapses), with 3 %
  /// false alarms on silent trials.
  static bool hears(
    double levelDbHl,
    double thresholdDbHl,
    math.Random rng, {
    bool isCatch = false,
  }) {
    if (isCatch) return rng.nextDouble() < 0.03;
    if (levelDbHl >= thresholdDbHl - 1e-9) return rng.nextDouble() >= 0.05;
    return rng.nextDouble() < 0.03;
  }

  static double dinSrt(HearingDemoOutcome o) => switch (o) {
    HearingDemoOutcome.normal => -10,
    HearingDemoOutcome.borderline => -6,
    HearingDemoOutcome.refer => -2,
  };

  /// Whole-triplet correctness as a logistic of (SNR − SRT).
  static bool dinCorrect(double snrDb, double srtDb, math.Random rng) {
    final p = 1 / (1 + math.exp(-(snrDb - srtDb) / 1.2));
    return rng.nextDouble() < p;
  }
}
