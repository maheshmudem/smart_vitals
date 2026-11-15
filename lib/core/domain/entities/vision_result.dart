// Output of one vision test session (Doc 11 §6.5 vision & reaction fields).
import '../algorithms/risk_engine.dart' show PersonalBaselineResult;
import '../algorithms/vision_engines.dart';
import 'enums.dart';
import 'marker_envelope.dart';
import 'vision_protocol.dart';

/// One eye (acuity, Amsler) or one block (reaction) or the whole set
/// (colour). Values keyed by the spec code without the suffix.
class VisionPartResult {
  const VisionPartResult({
    required this.label,
    required this.assessed,
    this.eye,
    this.block,
    this.skipped = false,
    this.values = const {},
    this.flags = const {},
    this.band = SemanticBand.notAssessed,
    this.note = '',
    this.amsler,
    this.trials = const [],
    this.plateReview = const [],
  });

  final String label;
  final bool assessed;
  final VisionEye? eye;
  final ReactionBlock? block;
  final bool skipped;
  final Map<String, double> values;
  final Map<String, bool> flags;
  final SemanticBand band;
  final String note;

  /// Marked grid for the Amsler replica on the result.
  final AmslerMarks? amsler;

  /// Staircase trials (acuity) for the quality expander.
  final List<AcuityTrial> trials;

  /// Colour plates: every plate with the revealed number and the answer.
  final List<PlateReviewItem> plateReview;
}

class VisionQualityFacts {
  const VisionQualityFacts({
    this.distanceMode = 'manual',
    this.meanDistanceCm,
    this.distanceInRangePct,
    this.dpiSource = 'estimated',
    this.dpi,
    this.brightnessMode = 'manual',
    this.trials = 0,
    this.falseStarts = 0,
    this.controlPlateFailed = false,
    this.medianResponseMs,
    this.retakes = 0,
    this.simulated = true,
  });

  /// 'measured' (calibrated camera) | 'estimated' (camera, FOV guess) |
  /// 'manual' (no camera estimate).
  final String distanceMode;
  final double? meanDistanceCm;
  final double? distanceInRangePct;

  /// 'device dpi' | 'card calibrated' | 'estimated'.
  final String dpiSource;
  final double? dpi;

  /// 'boosted' | 'manual'.
  final String brightnessMode;
  final int trials;
  final int falseStarts;
  final bool controlPlateFailed;

  /// Colour plates: median time from plate shown to answer.
  final double? medianResponseMs;
  final int retakes;
  final bool simulated;

  /// Capture-quality score fed into RSK-06 result confidence.
  double get captureQualityScore {
    var s = 0.95;
    if (distanceMode == 'manual') s -= 0.10;
    if (distanceMode == 'estimated') s -= 0.05;
    if (distanceInRangePct != null && distanceInRangePct! < 80) s -= 0.15;
    if (dpiSource == 'estimated') s -= 0.05;
    if (brightnessMode == 'manual') s -= 0.05;
    if (falseStarts > 3) s -= 0.10;
    if (controlPlateFailed) s -= 0.25;
    return s.clamp(0.4, 1.0);
  }
}

class VisionSessionResult {
  const VisionSessionResult({
    required this.sessionId,
    required this.subjectId,
    required this.subjectName,
    required this.ageYears,
    required this.sex,
    required this.protocol,
    required this.recordedAt,
    required this.durationSeconds,
    required this.parts,
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
    required this.demoOutcome,
    required this.heroCode,
    required this.heroValue,
    required this.heroLabel,
    this.baseline,
  });

  final String sessionId;
  final String subjectId;
  final String subjectName;
  final int ageYears;
  final BiologicalSex sex;
  final VisionProtocol protocol;
  final DateTime recordedAt;
  final int durationSeconds;
  final List<VisionPartResult> parts;
  final Map<String, double> overall;
  final Map<String, MarkerEnvelope<dynamic>> markers;
  final SemanticBand band;
  final String bandTitle;
  final String bandSubline;
  final String whatItMeans;
  final UrgencyLevel urgency;
  final List<String> firedRuleCodes;
  final double confidence;
  final VisionQualityFacts quality;
  final PersonalBaselineResult? baseline;
  final VisionDemoOutcome demoOutcome;
  final String heroCode;
  final double? heroValue;
  final String heroLabel;

  bool get isPartiallyAssessed =>
      parts.length > 1 && parts.any((p) => !p.assessed);
  bool get isNotAssessed => parts.every((p) => !p.assessed);

  VisionPartResult? eye(VisionEye e) {
    for (final p in parts) {
      if (p.eye == e) return p;
    }
    return null;
  }
}
