import 'dart:typed_data';

import '../algorithms/photo_quality_analyzer.dart';
import 'enums.dart';
import 'marker_envelope.dart';

/// Which eye a lower-eyelid photo belongs to (ALG-IMG-01: 2 photos per eye).
enum EyeSide {
  left('Left eye'),
  right('Right eye');

  const EyeSide(this.label);
  final String label;
}

/// Recent-treatment questions asked before the anaemia photos. These mirror
/// the reference-pairing exclusions in Spec §14 ("transfusion, iron infusion
/// or acute bleeding") plus common factors that change eyelid colour.
enum RecentTreatment {
  transfusion3m(
    'Blood transfusion (last 3 months)',
    'A transfusion raises haemoglobin for weeks, so the result may not show your usual level.',
    true,
  ),
  ironInfusion3m(
    'Iron infusion or injection (last 3 months)',
    'Iron treatment changes haemoglobin quickly; the screen may read higher than before treatment.',
    true,
  ),
  recentBleeding(
    'Recent heavy bleeding (injury, surgery, heavy period)',
    'Blood loss can lower haemoglobin faster than eyelid colour changes.',
    true,
  ),
  onIronTablets(
    'Taking iron tablets now',
    'Noted for context — tablets act slowly and do not block the screen.',
    false,
  ),
  eyeInfectionToday(
    'Red, sore or infected eye today',
    'Inflammation makes the eyelid redder and can hide pallor.',
    true,
  ),
  contactLensOrMakeup(
    'Wearing contact lenses or eye make-up',
    'Remove lenses and wipe make-up near the lower lid before the photos.',
    false,
  ),
  none('None of these', '', false);

  const RecentTreatment(
    this.label,
    this.reliabilityNote,
    this.affectsReliability,
  );
  final String label;
  final String reliabilityNote;
  final bool affectsReliability;
}

/// Answers collected in the "Prepare" step (S-E01/E02).
class AnaemiaPreTestAnswers {
  const AnaemiaPreTestAnswers({
    this.treatments = const {},
    this.otherNote,
    this.hasColourCard = true,
    this.colourErrorDe,
    this.consentGiven = false,
  });

  final Set<RecentTreatment> treatments;
  final String? otherNote;
  final bool hasColourCard;
  final double? colourErrorDe;
  final bool consentGiven;

  bool get anyReliabilityFactor => treatments.any((t) => t.affectsReliability);

  AnaemiaPreTestAnswers copyWith({
    Set<RecentTreatment>? treatments,
    String? otherNote,
    bool? hasColourCard,
    double? colourErrorDe,
    bool? consentGiven,
  }) {
    return AnaemiaPreTestAnswers(
      treatments: treatments ?? this.treatments,
      otherNote: otherNote ?? this.otherNote,
      hasColourCard: hasColourCard ?? this.hasColourCard,
      colourErrorDe: colourErrorDe ?? this.colourErrorDe,
      consentGiven: consentGiven ?? this.consentGiven,
    );
  }
}

/// One of the four lower-eyelid photos (L1, L2, R1, R2).
class EyelidPhoto {
  const EyelidPhoto({
    required this.eye,
    required this.index,
    required this.quality,
    required this.attempts,
    required this.accepted,
    this.bytes,
  });

  final EyeSide eye;

  /// 1 or 2 within the eye.
  final int index;
  final PhotoQualityReport quality;

  /// Attempts used for this view (G-25: max 3).
  final int attempts;

  /// False when the view was marked "not assessed" after 3 failed attempts.
  final bool accepted;
  final Uint8List? bytes;

  String get label => '${eye.label} · photo $index of 2';
  String get shortLabel => '${eye == EyeSide.left ? 'L' : 'R'}$index';
}

/// Per-eye roll-up shown on S-R01 [DER — the Spec defines one combined
/// ANAEMIA_BAND per session; per-eye values are shown for transparency only].
class AnaemiaEyeSummary {
  const AnaemiaEyeSummary({
    required this.eye,
    required this.pallorIndex,
    required this.meanAStar,
    required this.photosUsed,
    required this.band,
  });

  final EyeSide eye;

  /// 0 = rich pink (well perfused) … 1 = very pale.
  final double pallorIndex;
  final double meanAStar;
  final int photosUsed;
  final SemanticBand band;
}

/// WHO haemoglobin cut-off for a subject (Spec §6.1 / ALG-RSK-01).
class AnaemiaWhoThreshold {
  const AnaemiaWhoThreshold({
    required this.cutoffGdL,
    required this.groupLabel,
  });

  final double cutoffGdL;
  final String groupLabel;

  static AnaemiaWhoThreshold forSubject({
    required int ageYears,
    required BiologicalSex sex,
    required bool isPregnant,
  }) {
    if (ageYears < 5) {
      return const AnaemiaWhoThreshold(
        cutoffGdL: 11.0,
        groupLabel: 'Child 6–59 months',
      );
    }
    if (ageYears <= 11) {
      return const AnaemiaWhoThreshold(
        cutoffGdL: 11.5,
        groupLabel: 'Child 5–11 years',
      );
    }
    if (sex == BiologicalSex.female && isPregnant) {
      return const AnaemiaWhoThreshold(
        cutoffGdL: 11.0,
        groupLabel: 'Pregnant woman',
      );
    }
    if (sex == BiologicalSex.female) {
      return const AnaemiaWhoThreshold(
        cutoffGdL: 12.0,
        groupLabel: 'Non-pregnant woman',
      );
    }
    return const AnaemiaWhoThreshold(cutoffGdL: 13.0, groupLabel: 'Man');
  }

  /// All WHO rows for the reference table on S-E01 / S-R01.
  static const List<AnaemiaWhoThreshold> table = [
    AnaemiaWhoThreshold(cutoffGdL: 13.0, groupLabel: 'Men'),
    AnaemiaWhoThreshold(cutoffGdL: 12.0, groupLabel: 'Non-pregnant women'),
    AnaemiaWhoThreshold(cutoffGdL: 11.0, groupLabel: 'Pregnant women'),
    AnaemiaWhoThreshold(cutoffGdL: 11.5, groupLabel: 'Children 5–11 years'),
    AnaemiaWhoThreshold(cutoffGdL: 11.0, groupLabel: 'Children 6–59 months'),
  ];
}

/// Demo outcome selector for the static model stand-in (no trained
/// ALG-IMG-01 CNN is shipped yet).
enum AnaemiaDemoOutcome { normal, borderline, high }

/// Full output of one anaemia session (F-16 · ALG-IMG-01 · S-R01).
class AnaemiaSessionResult {
  const AnaemiaSessionResult({
    required this.sessionId,
    required this.subjectId,
    required this.subjectName,
    required this.ageYears,
    required this.sex,
    required this.isPregnant,
    required this.pregnancyWeeks,
    required this.recordedAt,
    required this.answers,
    required this.photos,
    required this.perEye,
    required this.threshold,
    required this.hbEstInternalGdL,
    required this.anaemiaProb,
    required this.decisionThreshold,
    required this.band,
    required this.confidence,
    required this.captureQualityScore,
    required this.modelConfidence,
    required this.urgency,
    required this.firedRuleCodes,
    required this.specialistReviewRequired,
    required this.specialistReviewStatus,
    required this.retakeTotal,
    required this.durationSeconds,
    required this.algorithmVersion,
    required this.rangeVersion,
    required this.markers,
  });

  final String sessionId;
  final String subjectId;
  final String subjectName;
  final int ageYears;
  final BiologicalSex sex;
  final bool isPregnant;
  final int? pregnancyWeeks;
  final DateTime recordedAt;
  final AnaemiaPreTestAnswers answers;
  final List<EyelidPhoto> photos;
  final List<AnaemiaEyeSummary> perEye;
  final AnaemiaWhoThreshold threshold;

  /// HB_EST — g/dL, 1 decimal, INTERNAL ONLY (Spec §6.1, R-9).
  final double hbEstInternalGdL;

  /// ANAEMIA_PROB 0–1 (not member-facing, R-9).
  final double anaemiaProb;
  final double decisionThreshold;

  /// ANAEMIA_BAND — normal / borderline / high (band only, G-24).
  final SemanticBand band;
  final double confidence;
  final double captureQualityScore;
  final double modelConfidence;
  final UrgencyLevel urgency;
  final List<String> firedRuleCodes;

  /// IMG-10: high band or |p − τ| ≤ 0.10.
  final bool specialistReviewRequired;
  final String specialistReviewStatus;
  final int retakeTotal;
  final int durationSeconds;
  final String algorithmVersion;
  final String rangeVersion;
  final Map<String, MarkerEnvelope<dynamic>> markers;

  List<EyelidPhoto> photosFor(EyeSide eye) =>
      photos.where((p) => p.eye == eye).toList();

  List<EyeSide> get notAssessedEyes => [
    for (final eye in EyeSide.values)
      if (photosFor(eye).every((p) => !p.accepted)) eye,
  ];

  bool get isNotAssessed => notAssessedEyes.length == EyeSide.values.length;
  bool get isPartiallyAssessed => notAssessedEyes.isNotEmpty && !isNotAssessed;

  int get acceptedPhotoCount => photos.where((p) => p.accepted).length;
}
