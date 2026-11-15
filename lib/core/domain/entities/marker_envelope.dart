import 'enums.dart';

class MarkerEnvelope<T> {
  const MarkerEnvelope({
    required this.code,
    required this.displayName,
    required this.algorithmId,
    required this.algorithmVersion,
    required this.rangeVersion,
    required this.unit,
    required this.decimals,
    required this.band,
    required this.confidence,
    required this.displayStatus,
    this.value,
    this.formattedOverride,
    this.normalRangeLabel,
    this.statusReason,
    this.conditionsInformed = const [],
    this.isEstimate = false,
  });

  final String code;
  final String displayName;
  final String algorithmId;
  final String algorithmVersion;
  final String rangeVersion;
  final String unit;
  final int decimals;
  final T? value;
  final String? formattedOverride;
  final SemanticBand band;
  final double confidence; // 0.0 - 1.0 (ALG-RSK-06: hidden if < 0.6)
  final MarkerDisplayStatus displayStatus;
  final String? normalRangeLabel;
  final String? statusReason;
  final List<String> conditionsInformed;
  final bool isEstimate;

  /// Gate G-23 & G-24 enforcement: can the numeric value be displayed?
  bool get shouldShowNumericValue {
    if (confidence < 0.60) return false;
    return displayStatus == MarkerDisplayStatus.ok ||
        displayStatus == MarkerDisplayStatus.rangeNotAvailable ||
        displayStatus == MarkerDisplayStatus.needsConfirmation;
  }

  /// Formatted display string respecting decimals, band-only, and G-23/G-24.
  String get displayText {
    if (confidence < 0.60 ||
        displayStatus == MarkerDisplayStatus.lowConfidenceHidden) {
      return 'Hidden (Low confidence < 0.60)';
    }
    switch (displayStatus) {
      case MarkerDisplayStatus.lowConfidenceHidden:
        return 'Hidden (Low confidence < 0.60)';
      case MarkerDisplayStatus.bandOnly:
        return band.label;
      case MarkerDisplayStatus.qualityRetakeRequired:
        return statusReason ?? 'Retake required';
      case MarkerDisplayStatus.notAvailable:
        return statusReason ?? 'Not available';
      case MarkerDisplayStatus.notAssessed:
        return statusReason ?? 'Not assessed';
      case MarkerDisplayStatus.inValidation:
        return 'In validation';
      case MarkerDisplayStatus.internalOnly:
        return 'Internal marker';
      case MarkerDisplayStatus.underSpecialistReview:
        return '${band.label} (Specialist review)';
      case MarkerDisplayStatus.ok:
      case MarkerDisplayStatus.rangeNotAvailable:
      case MarkerDisplayStatus.needsConfirmation:
        if (formattedOverride != null) return formattedOverride!;
        if (value == null) return band.label;
        if (value is double) {
          return (value as double).toStringAsFixed(decimals);
        }
        return value.toString();
    }
  }
}

class ToothFinding {
  const ToothFinding({
    required this.toothFdi,
    required this.findingCode,
    required this.findingLabel,
    required this.probability,
    required this.band,
    this.changeVsPrevious = 'Unchanged',
  });

  final int toothFdi; // Primary 51-85, Permanent 11-48
  final String
  findingCode; // white_spot, enamel_break, cavity, broken_black, abscess_sign
  final String findingLabel;
  final double probability;
  final SemanticBand band;
  final String changeVsPrevious; // New, Progressed, Unchanged (ALG-DEN-07)
}

class DentalExamResult {
  const DentalExamResult({
    required this.examId,
    required this.subjectId,
    required this.recordedAt,
    required this.isChildMode,
    required this.viewsCompleted,
    required this.isPartial,
    required this.unseenTeethFdi,
    required this.toothFindings,
    required this.gumInflammationBand,
    required this.plaqueBand,
    required this.sealantNeededTeethFdi,
    required this.cariesRiskBand,
    required this.cariesRiskReason,
    required this.urgency,
  });

  final String examId;
  final String subjectId;
  final DateTime recordedAt;
  final bool isChildMode;
  final int viewsCompleted; // out of 4
  final bool isPartial;
  final List<int> unseenTeethFdi;
  final List<ToothFinding> toothFindings;
  final SemanticBand gumInflammationBand;
  final SemanticBand plaqueBand;
  final List<int> sealantNeededTeethFdi; // 16, 26, 36, 46 for ages 6-9
  final SemanticBand cariesRiskBand;
  final String cariesRiskReason;
  final UrgencyLevel urgency;
}

/// One capture-quality check (Spec §2, ALG-CAP-01…05) as stored with the session
/// for QA and for the RSK-06 capture-quality score.
class CaptureQualityCheck {
  const CaptureQualityCheck({
    required this.algorithmId,
    required this.code,
    required this.label,
    required this.valueText,
    required this.passRuleText,
    required this.passed,
  });

  final String algorithmId;
  final String code;
  final String label;
  final String valueText;
  final String passRuleText;
  final bool passed;
}

/// Capture-quality summary for a face / finger session (Spec §2 + RSK-06 input).
class CaptureQualitySummary {
  const CaptureQualitySummary({
    required this.framesPassedPct,
    required this.captureQualityScore,
    required this.discardedLeadInSeconds,
    required this.checks,
  });

  /// ≥ 80% of frames must pass every check for the capture to be accepted.
  final double framesPassedPct;

  /// Aggregate 0–1 score fed into RSK-06 result confidence.
  final double captureQualityScore;
  final double discardedLeadInSeconds;
  final List<CaptureQualityCheck> checks;
}

/// Per-ROI weight from ALG-PUL-01 (SNR < 0 dB → weight 0; < 4 usable → fail).
class RoiWeight {
  const RoiWeight({
    required this.roi,
    required this.weight,
    required this.snrDb,
  });

  final String roi;
  final double weight;
  final double snrDb;
}

/// `PulseSignalSummary` — the F-10 output of the pulse pipeline (Spec §3, ALG-PUL-01…10).
class PulseSignalSummary {
  const PulseSignalSummary({
    required this.roiWeights,
    required this.extractionMethod,
    required this.neuralFallback,
    required this.neuralProcessingSeconds,
    required this.hrSpecBpm,
    required this.hrPosBpm,
    required this.hrNeuralBpm,
    required this.beatsDetected,
    required this.cleanBeatCount,
    required this.templateCorrMean,
    required this.pulseSnrDb,
    required this.ibiCount,
    required this.validIbiPct,
    required this.ectopicCount,
    required this.meanIbiMs,
  });

  final List<RoiWeight> roiWeights;

  /// "POS" or "CHROM" (CHROM only when its SNR beats POS, ALG-PUL-04).
  final String extractionMethod;

  /// EfficientPhys failed or exceeded 20 s → POS only + flag (ALG-PUL-05).
  final bool neuralFallback;
  final double neuralProcessingSeconds;
  final double hrSpecBpm;
  final double hrPosBpm;
  final double hrNeuralBpm;
  final int beatsDetected;
  final int cleanBeatCount;
  final double templateCorrMean;
  final double pulseSnrDb;
  final int ibiCount;
  final double validIbiPct;
  final int ectopicCount;
  final double meanIbiMs;

  double get hrSpecBeatDiffBpm => (hrSpecBpm - hrPosBpm).abs();
  double get hrNeuralPosDiffBpm => (hrNeuralBpm - hrPosBpm).abs();
}

class VitalsSessionResult {
  const VitalsSessionResult({
    required this.sessionId,
    required this.subjectId,
    required this.captureMode,
    required this.recordedAt,
    required this.pulseSnrDb,
    required this.cleanBeatCount,
    required this.validIbiPct,
    required this.hadRecentContextFactor,
    required this.markers,
    required this.derivedFormulas,
    required this.overallUrgency,
    required this.firedRuleCodes,
    required this.retakeRequired,
    this.retakeReason,
    this.diagnosticMarkers = const {},
    this.captureQuality,
    this.pulseSignal,
    this.recordingSeconds = 60,
    this.bpCuffCalibrationNote,
  });

  final String sessionId;
  final String subjectId;
  final VitalsCaptureMode captureMode;
  final DateTime recordedAt;
  final double pulseSnrDb;
  final int cleanBeatCount;
  final double validIbiPct;
  final bool
  hadRecentContextFactor; // 0.8 multiplier if caffeine/smoke/exercise < 30m
  final Map<String, MarkerEnvelope<dynamic>> markers;
  final Map<String, MarkerEnvelope<dynamic>> derivedFormulas;
  final UrgencyLevel overallUrgency;
  final List<String> firedRuleCodes;
  final bool retakeRequired;
  final String? retakeReason;

  /// Internal / diagnostic markers (HR_POS, RR_RIIV, IRREG_PROB, SBP/DBP …)
  /// that the Spec stores but does not show to members (R-9). Shown only in
  /// the operator QA expander on S-D07.
  final Map<String, MarkerEnvelope<dynamic>> diagnosticMarkers;
  final CaptureQualitySummary? captureQuality;
  final PulseSignalSummary? pulseSignal;
  final int recordingSeconds;
  final String? bpCuffCalibrationNote;
}

class ScreeningSessionRecord {
  const ScreeningSessionRecord({
    required this.sessionId,
    required this.subjectId,
    required this.featureId,
    required this.screenId,
    required this.title,
    required this.category,
    required this.recordedAt,
    required this.primaryBand,
    required this.urgency,
    required this.confidence,
    required this.summaryText,
    required this.markers,
    this.isUnderSpecialistReview = false,
    this.firedRules = const [],
  });

  final String sessionId;
  final String subjectId;
  final String featureId;
  final String screenId;
  final String title;
  final String category;
  final DateTime recordedAt;
  final SemanticBand primaryBand;
  final UrgencyLevel urgency;
  final double confidence;
  final String summaryText;
  final List<MarkerEnvelope<dynamic>> markers;
  final bool isUnderSpecialistReview;
  final List<String> firedRules;
}
