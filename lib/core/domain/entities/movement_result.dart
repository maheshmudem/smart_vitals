// Output of one movement test session (Doc 11 §6.5 MovementResult).
import '../algorithms/risk_engine.dart' show PersonalBaselineResult;
import 'enums.dart';
import 'marker_envelope.dart';
import 'movement_protocol.dart';

/// Per-hand (or whole-body) values keyed by spec marker code without the
/// side suffix, e.g. {'TAP_COUNT': 38, 'TAP_FREQ': 3.8}.
class MovementSideResult {
  const MovementSideResult({
    required this.side,
    required this.assessed,
    this.skipped = false,
    this.restarts = 0,
    this.values = const {},
    this.band = SemanticBand.notAssessed,
    this.note = '',
  });

  final MovementSide? side;
  final bool assessed;
  final bool skipped;
  final int restarts;
  final Map<String, double> values;
  final SemanticBand band;
  final String note;

  String get label => side?.label ?? 'Overall';
}

class MovementQualityFacts {
  const MovementQualityFacts({
    this.achievedAccelHz,
    this.achievedGyroHz,
    this.droppedSamples = 0,
    this.framesPerSecond,
    this.handVisiblePct,
    this.backend = 'simulated',
    this.restarts = 0,
    this.retakes = 0,
    this.sensorSimulated = true,
    this.noiseFloorPsd,
    this.peakRatio,
  });

  final double? achievedAccelHz;
  final double? achievedGyroHz;
  final int droppedSamples;
  final double? framesPerSecond;
  final double? handVisiblePct;

  /// 'landmarks' | 'proxy' | 'simulated' | 'sensors'
  final String backend;
  final int restarts;
  final int retakes;
  final bool sensorSimulated;
  final double? noiseFloorPsd;
  final double? peakRatio;

  /// Capture-quality score fed into RSK-06 result confidence.
  double get captureQualityScore {
    var s = 0.95;
    if (framesPerSecond != null && framesPerSecond! < 15) s -= 0.15;
    if (handVisiblePct != null && handVisiblePct! < 90) s -= 0.10;
    if (achievedAccelHz != null && achievedAccelHz! < 40) s -= 0.15;
    if (achievedGyroHz != null && achievedGyroHz! < 80) s -= 0.15;
    if (droppedSamples > 20) s -= 0.10;
    if (backend == 'proxy') s -= 0.10;
    return s.clamp(0.4, 1.0);
  }
}

/// ALG-MOV-13: only runs when tapping + voice + face all exist.
class PdCompositeStatus {
  const PdCompositeStatus({
    required this.hasTapping,
    required this.hasVoice,
    required this.hasFace,
    this.band,
    this.prob,
  });

  final bool hasTapping;
  final bool hasVoice;
  final bool hasFace;
  final SemanticBand? band;

  /// Internal only [OPEN].
  final double? prob;

  bool get complete => hasTapping && hasVoice && hasFace;
  List<String> get missing => [
    if (!hasTapping) 'Finger tapping (S-H01 / S-H02)',
    if (!hasVoice) 'Voice task (S-G04)',
    if (!hasFace) 'Face video (S-D03)',
  ];
}

class MovementSessionResult {
  const MovementSessionResult({
    required this.sessionId,
    required this.subjectId,
    required this.subjectName,
    required this.ageYears,
    required this.sex,
    required this.protocol,
    required this.recordedAt,
    required this.durationSeconds,
    required this.perSide,
    required this.overall,
    required this.markers,
    required this.band,
    required this.bandTitle,
    required this.bandSubline,
    required this.whatItMeans,
    required this.urgency,
    required this.firedRuleCodes,
    required this.confidence,
    required this.quality,
    required this.pd,
    required this.demoOutcome,
    required this.heroCode,
    required this.heroValue,
    required this.heroLabel,
    this.baseline,
    this.ageNormLabel,
  });

  final String sessionId;
  final String subjectId;
  final String subjectName;
  final int ageYears;
  final BiologicalSex sex;
  final MovementProtocol protocol;
  final DateTime recordedAt;
  final int durationSeconds;

  /// Two entries for hand tests (left, right); one `null`-side entry otherwise.
  final List<MovementSideResult> perSide;

  /// Whole-body values (gait, STS) keyed by spec code.
  final Map<String, double> overall;

  /// Spec-coded envelopes (`TAP_COUNT_L`, `GAIT_SPEED`, …).
  final Map<String, MarkerEnvelope<dynamic>> markers;
  final SemanticBand band;
  final String bandTitle;
  final String bandSubline;
  final String whatItMeans;
  final UrgencyLevel urgency;
  final List<String> firedRuleCodes;
  final double confidence;
  final MovementQualityFacts quality;
  final PersonalBaselineResult? baseline;
  final PdCompositeStatus pd;
  final MovementDemoOutcome demoOutcome;

  /// The one number the hero card shows (spec code, value, display text).
  final String heroCode;
  final double? heroValue;
  final String heroLabel;

  /// 'Age 60–64 norm ≥ 12' or 'Age / sex norm pending'.
  final String? ageNormLabel;

  bool get isPartiallyAssessed =>
      protocol.twoSided && perSide.any((s) => !s.assessed);
  bool get isNotAssessed => perSide.every((s) => !s.assessed);

  MovementSideResult? side(MovementSide s) {
    for (final r in perSide) {
      if (r.side == s) return r;
    }
    return null;
  }
}
