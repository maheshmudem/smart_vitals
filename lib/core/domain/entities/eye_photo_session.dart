import 'dart:typed_data';

import '../algorithms/photo_quality_analyzer.dart';
import 'anaemia_result.dart' show EyeSide;
import 'enums.dart';
import 'eye_photo_protocol.dart';
import 'marker_envelope.dart';

/// Demo outcome selector for the static model stand-ins. Each protocol maps
/// the four values to its own meaning (see `EyeProtocol.demoOutcomeLabels`).
enum EyeDemoOutcome { normal, borderline, high, urgent }

/// One captured (or not-assessed) view.
class EyePhoto {
  const EyePhoto({
    required this.view,
    required this.quality,
    required this.attempts,
    required this.accepted,
    this.bytes,
  });

  final EyeView view;
  final PhotoQualityReport quality;

  /// Attempts used for this view (G-25: max 3).
  final int attempts;

  /// False when the view was marked "not assessed" after 3 failed attempts.
  final bool accepted;
  final Uint8List? bytes;

  String get shortLabel => view.shortLabel;
  String get label => view.label;
}

/// Answers collected in the Prepare (and Connect) steps.
class EyeAnswers {
  const EyeAnswers({
    this.questionIds = const {},
    this.otherNote,
    this.hasColourCard = false,
    this.colourErrorDe,
    this.photographerRole,
    this.partnerConsent = false,
    this.consentGiven = false,
    this.operatedEyes = const {},
    this.onRequest = false,
    this.bodyLocation,
    this.durationBucket,
    this.skinType,
    this.abcdeFlags = const {},
    this.newbornAgeHours,
    this.gestationWeeks,
    this.birthWeightKg,
    this.tobaccoStatus,
    this.brushingPerDay,
    this.fluoridePaste,
    this.sweetsPerDay,
    this.nightFeeding = false,
    this.lastDentalVisit,
  });

  final Set<String> questionIds;
  final String? otherNote;
  final bool hasColourCard;
  final double? colourErrorDe;

  /// Child eye / newborn: 'Parent / guardian' or 'Operator' (Spec
  /// `photographer_role`).
  final String? photographerRole;

  /// Fundus: consent to share de-identified images with the partner AI.
  final bool partnerConsent;
  final bool consentGiven;

  /// Cataract: eyes with a previous lens implant (not screened).
  final Set<EyeSide> operatedEyes;

  /// Cataract under 40 taken "on request" (G-09 advisory).
  final bool onRequest;

  // --- skin lesion ---
  final String? bodyLocation;
  final String? durationBucket;

  /// Fitzpatrick skin type 'I'…'VI' (fairness audit, not used for the band).
  final String? skinType;

  /// Ticked ABCDE keys: asymmetry / border / colour / diameter / evolving.
  final Set<String> abcdeFlags;

  // --- newborn ---
  final int? newbornAgeHours;
  final int? gestationWeeks;
  final double? birthWeightKg;

  // --- oral lesion ---
  /// 'Never' / 'Former' / 'Smoking' / 'Chewing' / 'Both' (Spec
  /// `tobacco_areca_status`). [durationBucket] holds "noticed for how long".
  final String? tobaccoStatus;

  // --- dental (S-F02 Q_CARIES_RISK) ---
  final int? brushingPerDay;

  /// 'yes' / 'no' / 'unknown'.
  final String? fluoridePaste;
  final int? sweetsPerDay;
  final bool nightFeeding;
  final String? lastDentalVisit;

  bool get usesTobacco =>
      tobaccoStatus != null &&
      tobaccoStatus != 'Never' &&
      tobaccoStatus != 'Former';

  List<EyeQuestion> ticked(EyeProtocol p) => p.questions
      .where((q) => questionIds.contains(q.id) && q.id != 'none')
      .toList();

  bool anyReliabilityFactor(EyeProtocol p) =>
      ticked(p).any((q) => q.affectsReliability);

  bool anyEscalating(EyeProtocol p) => ticked(p).any((q) => q.escalates);
}

/// A single named output of the analysis (per side, per zone or overall).
class EyeFinding {
  const EyeFinding({
    required this.code,
    required this.label,
    required this.valueText,
    required this.band,
    this.memberFacing = true,
    this.gaugeValue,
    this.eye,
    this.specValue,
  });

  final String code;
  final String label;
  final String valueText;
  final SemanticBand band;

  /// False for R-9 internal markers (probabilities, raw indices).
  final bool memberFacing;

  /// Position on the protocol gauge (0..1 or grade number).
  final double? gaugeValue;
  final EyeSide? eye;

  /// Raw spec output value (class code, band string, bool, list) when the
  /// marker is not a plain number; numbers use [gaugeValue].
  final Object? specValue;
}

/// Per-zone result for protocols that report body zones instead of sides
/// (newborn forehead / chest, skin close-up / context).
class EyeZoneResult {
  const EyeZoneResult({
    required this.band,
    required this.gauge,
    required this.note,
  });

  final SemanticBand band;
  final double? gauge;
  final String note;
}

/// Protocol-specific result cards rendered by the generic result screen.
sealed class EyeExtraCard {
  const EyeExtraCard();
}

/// Newborn: the hour-specific phototherapy line for this baby.
class NeonatalChartCard extends EyeExtraCard {
  const NeonatalChartCard({
    required this.gestationWeeks,
    required this.ageHours,
    required this.hasRiskFactors,
    required this.bucketLabel,
    required this.rows,
    required this.thresholdAtAge,
    required this.positionFraction,
    required this.chartApplies,
    required this.statusLine,
  });

  final int gestationWeeks;
  final int ageHours;
  final bool hasRiskFactors;
  final String bucketLabel;

  /// (hours, mg/dL) rows at 24 h steps.
  final List<(int, double)> rows;
  final double? thresholdAtAge;

  /// 0..1 position of the estimate relative to the line (0.75 = on the line).
  final double positionFraction;
  final bool chartApplies;
  final String statusLine;
}

/// Diabetic foot: IWGDF risk category, per-foot findings and wound area.
class FootRiskCard extends EyeExtraCard {
  const FootRiskCard({
    required this.category,
    required this.categoryLabel,
    required this.recheck,
    required this.perFootFindings,
    this.woundAreaCm2,
    this.woundSide,
    this.woundSite,
  });

  final int category;
  final String categoryLabel;
  final String recheck;
  final Map<EyeSide, List<String>> perFootFindings;
  final double? woundAreaCm2;
  final EyeSide? woundSide;
  final String? woundSite;
}

/// Skin lesion: possible matches, ABCDE checklist and size.
class SkinMatchesCard extends EyeExtraCard {
  const SkinMatchesCard({
    required this.matches,
    required this.abcdeFlags,
    required this.abcdeItems,
    this.lesionMm,
    this.bodyLocation,
    this.duration,
  });

  /// (condition name, one-line note), most likely first.
  final List<(String, String)> matches;
  final Set<String> abcdeFlags;
  final List<(String, String)> abcdeItems;
  final double? lesionMm;
  final String? bodyLocation;
  final String? duration;
}

/// Oral lesion: class per site, red flags and the tobacco context.
class OralSitesCard extends EyeExtraCard {
  const OralSitesCard({
    required this.sites,
    required this.redFlags,
    required this.worstSite,
    this.tobaccoStatus,
  });

  /// One row per photographed site, in view order.
  final List<OralSiteResult> sites;

  /// Plain-language red flags from the questions (non-healing > 3 weeks …).
  final List<String> redFlags;

  /// Site label that carries the worst class, or null when nothing was seen.
  final String? worstSite;
  final String? tobaccoStatus;
}

class OralSiteResult {
  const OralSiteResult({
    required this.zone,
    required this.band,
    required this.classLabel,
    required this.note,
    this.lesionBox,
  });

  final String zone;
  final SemanticBand band;

  /// 'Not suspicious' / 'Suspicious' / 'High risk' / 'Not assessed'.
  final String classLabel;
  final String note;

  /// Fractional (l, t, w, h) of the lesion region drawn on the thumbnail
  /// (Spec `lesion_regions` overlay [DER]); null when nothing was marked.
  final (double, double, double, double)? lesionBox;

  bool get hasLesionBox => lesionBox != null;
}

/// Dental: the full S-F04 exam (tooth chart, gum / plaque, sealants, caries
/// risk, change over time).
class DentalChartCard extends EyeExtraCard {
  const DentalChartCard({
    required this.exam,
    required this.dentitionLabel,
    required this.cariesReason,
    required this.changes,
    required this.previousExamAt,
    required this.habitsSummary,
    required this.mixedDentition,
  });

  final DentalExamResult exam;

  /// 'Primary teeth (51–85)' / 'Mixed dentition' / 'Permanent teeth (11–48)'.
  final String dentitionLabel;
  final String cariesReason;

  /// (FDI, change label) rows: 'New', 'Progressed', 'Unchanged', 'Resolved / restored'.
  final List<(int, String)> changes;
  final DateTime? previousExamAt;
  final String habitsSummary;

  /// Ages 6–12: primary chart plus the first permanent molars 16/26/36/46.
  final bool mixedDentition;
}

/// Full output of one guided photo session (S-R01).
class EyeSessionResult {
  const EyeSessionResult({
    required this.protocol,
    required this.sessionId,
    required this.subjectId,
    required this.subjectName,
    required this.ageYears,
    required this.sex,
    required this.recordedAt,
    required this.answers,
    required this.photos,
    required this.findings,
    required this.perEyeBand,
    required this.perEyeGauge,
    required this.perEyeNote,
    required this.band,
    required this.bandTitle,
    required this.bandSubline,
    required this.whatItMeans,
    required this.urgency,
    required this.firedRuleCodes,
    required this.specialistReviewRequired,
    required this.specialistReviewStatus,
    required this.confidence,
    required this.captureQualityScore,
    required this.modelConfidence,
    required this.probability,
    required this.decisionThreshold,
    required this.markers,
    required this.retakeTotal,
    required this.durationSeconds,
    required this.demoOutcome,
    this.perZone = const {},
    this.extraCards = const [],
    this.highlightBandOverride,
    this.ageLabelOverride,
  });

  final EyeProtocol protocol;
  final String sessionId;
  final String subjectId;
  final String subjectName;
  final int ageYears;
  final BiologicalSex sex;
  final DateTime recordedAt;
  final EyeAnswers answers;
  final List<EyePhoto> photos;
  final List<EyeFinding> findings;

  /// Band per side (eyes / feet; child eye uses both sides from the same frames).
  final Map<EyeSide, SemanticBand> perEyeBand;

  /// Gauge position per side (null when not assessed).
  final Map<EyeSide, double?> perEyeGauge;

  /// Short per-side line, e.g. "Moderate NPDR · no DME" or "Operated".
  final Map<EyeSide, String> perEyeNote;

  /// Per-zone results for zone-based protocols (newborn, skin).
  final Map<String, EyeZoneResult> perZone;
  final List<EyeExtraCard> extraCards;
  final SemanticBand band;

  /// Headline such as "High band", "Refer", "White pupil — urgent".
  final String bandTitle;
  final String bandSubline;
  final String whatItMeans;
  final UrgencyLevel urgency;
  final List<String> firedRuleCodes;
  final bool specialistReviewRequired;
  final String specialistReviewStatus;
  final double confidence;
  final double captureQualityScore;
  final double modelConfidence;

  /// Internal probability (null for the partner model).
  final double? probability;
  final double decisionThreshold;
  final Map<String, MarkerEnvelope<dynamic>> markers;
  final int retakeTotal;
  final int durationSeconds;
  final EyeDemoOutcome demoOutcome;
  final SemanticBand? highlightBandOverride;
  final String? ageLabelOverride;

  /// Row to highlight in "How to read it" (child white pupil → emergency row).
  SemanticBand get highlightBand => highlightBandOverride ?? band;

  /// '26 y' or '72 h · 38 w'.
  String get ageLabel => ageLabelOverride ?? '$ageYears y';

  List<EyePhoto> photosFor(EyeSide? eye) =>
      photos.where((p) => p.view.eye == eye).toList();

  List<EyePhoto> photosForZone(String zone) =>
      photos.where((p) => p.view.zoneLabel == zone).toList();

  int get acceptedPhotoCount => photos.where((p) => p.accepted).length;
  bool get isNotAssessed => band == SemanticBand.notAssessed;
  List<EyeSide> get notAssessedEyes => [
    for (final e in EyeSide.values)
      if (perEyeBand[e] == SemanticBand.notAssessed) e,
  ];
  bool get isPartiallyAssessed =>
      !protocol.zonesInsteadOfSides &&
      notAssessedEyes.isNotEmpty &&
      notAssessedEyes.length < EyeSide.values.length;

  List<EyeFinding> get memberFindings =>
      findings.where((f) => f.memberFacing).toList();
  List<EyeFinding> get internalFindings =>
      findings.where((f) => !f.memberFacing).toList();

  /// Primary marker envelope filed on the screening record.
  MarkerEnvelope<dynamic> get primaryMarker => markers.values.first;

  T? extraCard<T extends EyeExtraCard>() {
    for (final c in extraCards) {
      if (c is T) return c;
    }
    return null;
  }
}
