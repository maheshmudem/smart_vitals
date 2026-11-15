import 'dart:ui' show Rect;

import '../algorithms/photo_quality_analyzer.dart' show PhotoTarget;
import 'anaemia_result.dart' show EyeSide;
import 'enums.dart';
import 'member_profile.dart' show SubjectProfile;

/// Where the person should look for a given photo (eye screens); body
/// screens use [EyeGaze.straight].
enum EyeGaze { up, towardNose, straight, atLight, sideLight }

/// Extra Prepare-step inputs a protocol needs beyond the checkbox questions.
enum EyeExtraInput {
  newbornDetails,
  bodyLocation,
  duration,
  skinType,
  abcde,

  /// Oral: tobacco / areca status (Spec `tobacco_areca_status`, G-10).
  tobaccoStatus,

  /// Dental: S-F02 caries-risk questionnaire (brushing, fluoride, sweets,
  /// night feeding, last visit).
  dentalHabits,
}

/// Drawn instruction pictures used by the eye flows (painted in
/// `lib/features/eye_screens/eye_illustrations.dart`).
enum EyeIllustration {
  lookUp,
  lookTowardNose,
  cardBesideEye,
  scleraGoodExample,
  scleraYellowExample,
  pupilCentred,
  dimRoom,
  clearLensExample,
  cloudyLensExample,
  childDistance,
  childLookAtLight,
  redReflexNormal,
  redReflexAsymmetric,
  whitePupilExample,
  fundusClipOn,
  fundusFixation,
  fundusMaculaExample,
  fundusDiscExample,
  phoneDistanceFlash,
  holdStill,
  glassesOff,
  glareExample,
  blurryExample,
  // --- body screens (painted by _BodyIllustrationPainter) ---
  cardOnChest,
  babyOnBack,
  daylightWindow,
  noFlashLamp,
  wipeCream,
  footSoleWithCard,
  toesSpread,
  helperHoldsFoot,
  footGoodExample,
  footUlcerExample,
  footCallusExample,
  lesionCentred,
  lesionAngled,
  lesionContextArm,
  lesionGoodExample,
  lesionHairShadowExample,
  abcdeChart,
  coinScale,
  // --- mouth screens (painted by _MouthIllustrationPainter) ---
  mouthOpenWide,
  cheekRetract,
  tongueToSide,
  tongueUpFloor,
  headBackPalate,
  torchMouthDistance,
  dentureOut,
  oralGoodExample,
  oralPatchExample,
  frontBite,
  frontOpen,
  upperArch,
  lowerArch,
  wipeTeeth,
  helperChildMouth,
  dentalGoodExample,
  dentalTongueExample,
  dentalBlurryExample,
  toothChartExample,
}

/// One photo the flow asks for (S-E03 "view").
class EyeView {
  const EyeView({
    required this.id,
    required this.eye,
    required this.index,
    required this.ofPerEye,
    required this.label,
    required this.coaching,
    required this.gaze,
    required this.illustration,
    required this.target,
    this.roi,
    this.flash,
    this.zoneLabel,
    this.zoneCode,
    this.chipLabel,
  });

  final String id;

  /// Left / right side for eyes and feet; `null` = both eyes in one frame
  /// (child eye) or a body zone without a side (newborn skin, skin lesion).
  final EyeSide? eye;
  final int index;
  final int ofPerEye;

  /// e.g. "Left eye · look up".
  final String label;

  /// One-line instruction shown over the camera before the shot.
  final String coaching;
  final EyeGaze gaze;
  final EyeIllustration illustration;
  final PhotoTarget target;
  final Rect? roi;

  /// Per-view flash override (newborn: one shot with and one without).
  final bool? flash;

  /// Body zone name, e.g. 'Forehead', 'Chest', 'Sole & heel', 'Close-up'.
  final String? zoneLabel;

  /// Thumbnail code for zone views, e.g. 'F1', 'C2', 'S1'.
  final String? zoneCode;

  /// Optional two-line name on the capture strip, e.g. 'Front closed'.
  final String? chipLabel;

  String get shortLabel =>
      zoneCode ??
      switch (eye) {
        EyeSide.left => 'L$index',
        EyeSide.right => 'R$index',
        null => 'B$index',
      };

  String get eyeLabel => zoneLabel ?? eye?.label ?? 'Both eyes';
}

/// A pre-test question shown as a checkbox row in the Prepare step.
class EyeQuestion {
  const EyeQuestion({
    required this.id,
    required this.label,
    this.note = '',
    this.affectsReliability = false,
    this.escalates = false,
    this.perEye = false,
  });

  final String id;
  final String label;

  /// Shown on the result ("may affect this result") when ticked.
  final String note;
  final bool affectsReliability;

  /// Symptom that strengthens the urgency message (e.g. dark urine).
  final bool escalates;

  /// When true, ticking it asks which eye (e.g. cataract surgery).
  final bool perEye;
}

class EyeHowToStep {
  const EyeHowToStep(this.illustration, this.title, this.body);

  final EyeIllustration illustration;
  final String title;
  final String body;
}

class EyeExample {
  const EyeExample(this.illustration, this.caption, {this.good = false});

  final EyeIllustration illustration;
  final String caption;
  final bool good;
}

class EyeNeedTile {
  const EyeNeedTile(this.illustration, this.title, this.sub);

  final EyeIllustration illustration;
  final String title;
  final String sub;
}

/// "How to read it" row.
class EyeBandInfo {
  const EyeBandInfo(this.band, this.title, this.meaning);

  final SemanticBand band;
  final String title;
  final String meaning;
}

/// Colour strip + three labelled bands used on the intro and result cards.
class EyeScale {
  const EyeScale({
    required this.labels,
    required this.bands,
    required this.gradient,
  });

  /// Three colour words, left → right (e.g. White · Tinted · Yellow).
  final List<String> labels;
  final List<SemanticBand> bands;

  /// ARGB colours for the gradient strip, left → right.
  final List<int> gradient;
}

/// Per-eye gauge on the result screen.
class EyeGaugeSpec {
  const EyeGaugeSpec({
    required this.title,
    required this.breakpoints,
    required this.labels,
    required this.bands,
  });

  final String title;
  final List<double> breakpoints;
  final List<String> labels;
  final List<SemanticBand> bands;
}

/// Everything a guided eye-photo flow needs to know about one screen.
/// All copy lives here so the intro, stepper and result screens are generic.
class EyeProtocol {
  const EyeProtocol({
    required this.id,
    required this.screenType,
    required this.featureId,
    required this.introScreenId,
    required this.stepScreenIds,
    required this.title,
    required this.shortTitle,
    required this.recordTitle,
    required this.homeSubtitle,
    required this.algorithmId,
    required this.algorithmName,
    required this.algorithmSubtitle,
    required this.algorithmVersion,
    required this.rangeVersion,
    required this.plainMessage,
    required this.partnerModel,
    required this.modelConfidence,
    required this.conditionCode,
    this.extraConditionCodes = const [],
    this.minAgeYears,
    this.maxAgeYears,
    this.allowOnRequest = false,
    this.guardianRequired = false,
    this.operatorLed = false,
    required this.flash,
    required this.dimRoom,
    required this.distanceLabel,
    required this.card,
    this.requiresFundusCamera = false,
    required this.durationLabel,
    required this.questions,
    required this.beforeYouStart,
    required this.beforeIllustrations,
    required this.howTo,
    this.helperTip,
    required this.examples,
    required this.views,
    required this.readsTitle,
    required this.readsCaption,
    required this.scale,
    required this.referenceTitle,
    required this.referenceRows,
    required this.referenceNote,
    required this.inputsText,
    required this.outputsText,
    required this.checkedByText,
    required this.miniSteps,
    required this.needs,
    required this.bands,
    required this.howMade,
    required this.analysisStages,
    required this.gauge,
    this.noNumberNote,
    required this.demoOutcomeLabels,
    required this.checklist,
    required this.equipmentTitle,
    required this.equipmentCaption,
    this.category = 'Eyes',
    this.partNoun = 'eye',
    this.sideLabels,
    this.perSideTitle = 'Your eyes',
    this.perSideCaption,
    this.zonesInsteadOfSides = false,
    this.newbornOnly = false,
    this.recheckLabel,
    this.cardPlacementCopy = 'flat beside the eye, level with it',
    this.cardRequiredNote,
    this.extraInputs = const {},
    this.bodyLocations = const [],
    this.durationOptions = const [],
    this.abcdeItems = const [],
    required this.whoText,
    required this.helperIntroText,
    required this.disclaimerText,
    required this.bannerCopy,
    required this.gaugeExplainer,
    required this.nextStepsNormal,
    required this.nextStepsNotAssessed,
    required this.nextHelper,
    required this.voicePrepare,
    required this.voiceHowTo,
    required this.voiceAnalysing,
    this.notAssessedHint =
        'No attempts left for this photo (G-25). It will be marked "Not assessed" and the test continues.',
    this.resultIcon = 'eye',
    this.torchPreview = false,
    this.consentType = ConsentType.screening,
    this.guardianUnderAge,
    this.detailsTitle = 'About the spot',
    this.detailsCaption = 'Where it is and how long you have had it',
    this.durationPrompt = 'How long have you had it?',
  });

  final String id;

  /// Null for screens that have no image-screen enum entry (dental F-18).
  final ImageScreenType? screenType;
  final String featureId;
  final String introScreenId;

  /// Screen id per stepper step (connect?, prepare, how-to, photos, analyse).
  final List<String> stepScreenIds;
  final String title;
  final String shortTitle;
  final String recordTitle;
  final String homeSubtitle;
  final String algorithmId;
  final String algorithmName;
  final String algorithmSubtitle;
  final String algorithmVersion;
  final String rangeVersion;
  final String plainMessage;

  /// Licensed partner AI → results are "displayed (partner result)", no
  /// "In clinical validation" badge.
  final bool partnerModel;
  final double modelConfidence;
  final String conditionCode;
  final List<String> extraConditionCodes;
  final int? minAgeYears;
  final int? maxAgeYears;
  final bool allowOnRequest;
  final bool guardianRequired;
  final bool operatorLed;
  final bool flash;
  final bool dimRoom;
  final String distanceLabel;
  final ColourCardPolicy card;
  final bool requiresFundusCamera;
  final String durationLabel;
  final List<EyeQuestion> questions;
  final List<String> beforeYouStart;
  final List<EyeIllustration> beforeIllustrations;
  final List<EyeHowToStep> howTo;

  /// Un-numbered helper tip shown after the photo steps (not a photo).
  final (String, String)? helperTip;
  final List<EyeExample> examples;
  final List<EyeView> views;
  final String readsTitle;
  final String readsCaption;
  final EyeScale scale;
  final String referenceTitle;
  final List<(String, String)> referenceRows;
  final String referenceNote;
  final String inputsText;
  final String outputsText;
  final String checkedByText;
  final List<(String, String)> miniSteps;
  final List<EyeNeedTile> needs;
  final List<EyeBandInfo> bands;
  final List<(String, String)> howMade;
  final List<String> analysisStages;
  final EyeGaugeSpec gauge;
  final String? noNumberNote;
  final Map<String, String> demoOutcomeLabels;
  final List<String> checklist;
  final String equipmentTitle;
  final String equipmentCaption;

  // --- region-agnostic presentation (body screens override these) ----------

  /// Screening record category: 'Eyes' or 'Skin & Body'.
  final String category;

  /// Noun used in generic copy: 'eye', 'baby\'s skin', 'foot', 'skin spot'.
  final String partNoun;

  /// Per-side labels when the protocol is left/right based (feet).
  final Map<EyeSide, String>? sideLabels;

  /// Section title for the per-side / per-zone card ('Your eyes', 'Your feet').
  final String perSideTitle;
  final String? perSideCaption;

  /// True when results are per body zone (forehead / chest, close-up /
  /// context) instead of left / right.
  final bool zonesInsteadOfSides;

  /// Only newborns 0–28 days (G-09, newborn jaundice).
  final bool newbornOnly;

  /// e.g. 'Monthly (G-34)'.
  final String? recheckLabel;

  /// Where the 24-patch card goes, used in the equipment copy.
  final String cardPlacementCopy;

  /// Why the card is required (shown under the required-card option).
  final String? cardRequiredNote;
  final Set<EyeExtraInput> extraInputs;
  final List<String> bodyLocations;
  final List<String> durationOptions;

  /// (key, label) rows of the ABCDE checklist (skin lesion).
  final List<(String, String)> abcdeItems;

  /// 'Who this screen is for' sentence on the intro.
  final String whoText;

  /// Helper sentence under the 'You will need' tiles.
  final String helperIntroText;

  /// 'Screening, not diagnosis' note on the algorithm card.
  final String disclaimerText;

  /// Urgency banner title + subtitle per urgency level.
  final Map<UrgencyLevel, (String, String)> bannerCopy;

  /// Explains the per-side gauge: '0 = white sclera, 1 = clearly yellow'.
  final String gaugeExplainer;
  final List<String> nextStepsNormal;
  final List<String> nextStepsNotAssessed;

  /// Helper under the intro Ready button: 'Next: …'.
  final String nextHelper;

  /// Spoken summaries (voice coach).
  final String voicePrepare;
  final String voiceHowTo;
  final String voiceAnalysing;
  final String notAssessedHint;

  /// Result-card icon key: 'eye' | 'baby' | 'foot' | 'skin' | 'mouth' | 'tooth'.
  final String resultIcon;

  /// Keep the LED torch on while framing (mouth photos); the flash still
  /// fires on capture when [flash] is true.
  final bool torchPreview;

  /// Consent gate for this screen: G-04 screening or G-05 dental & guardian.
  final ConsentType consentType;

  /// When set, a guardian / helper is required for subjects up to this age
  /// (dental child mode 1–12, G-05) even though adults self-screen.
  final int? guardianUnderAge;

  /// Copy for the details card that holds [bodyLocations] / [durationOptions].
  final String detailsTitle;
  final String detailsCaption;
  final String durationPrompt;

  /// True when a guardian must take part for this subject (static rule or
  /// age-based rule).
  bool guardianRequiredFor(SubjectProfile s) =>
      guardianRequired ||
      (guardianUnderAge != null && s.ageYears <= guardianUnderAge!);

  bool get cardRequired =>
      card == ColourCardPolicy.required || card == ColourCardPolicy.mandatory;
  bool get cardOffered => card != ColourCardPolicy.none;
  int get photoCount => views.length;
  bool get bothEyesInOneFrame =>
      !zonesInsteadOfSides && views.any((v) => v.eye == null);
  List<String> get allConditionCodes => [conditionCode, ...extraConditionCodes];
  bool get isBodyScreen => category != 'Eyes';

  /// Label for a side: 'Left eye' / 'Left foot'.
  String sideLabel(EyeSide side) => sideLabels?[side] ?? side.label;

  /// Zone labels in view order, de-duplicated (newborn: Forehead, Chest).
  List<String> get zoneLabelsInOrder {
    final out = <String>[];
    for (final v in views) {
      final z = v.zoneLabel;
      if (z != null && !out.contains(z)) out.add(z);
    }
    return out;
  }

  String eligibilityLabel() {
    if (newbornOnly) return 'Newborns 0–28 days';
    if (minAgeYears != null && maxAgeYears != null) {
      return 'Ages $minAgeYears–$maxAgeYears';
    }
    if (minAgeYears != null) {
      return allowOnRequest
          ? 'Ages $minAgeYears+ · or on request'
          : 'Ages $minAgeYears+';
    }
    if (isBodyScreen) return 'All ages';
    return 'Adults';
  }

  /// Full eligibility check for a profile (G-09): newborn window in hours,
  /// otherwise the year-based rule. Returns null when eligible.
  String? ageBlockReasonFor(SubjectProfile s) {
    if (newbornOnly) {
      if (!s.isNewborn) {
        return 'This screen is only for newborns in the first 28 days of life.';
      }
      final h = s.ageHoursForNewborn ?? 0;
      if (h > 672) {
        return 'Baby is older than 28 days (${(h / 24).floor()} days) — the newborn chart no longer applies.';
      }
      return null;
    }
    if (s.isNewborn && (minAgeYears ?? 0) > 0) {
      return 'This screen is for ages ${eligibilityLabel().replaceFirst('Ages ', '')}.';
    }
    return ageBlockReason(s.ageYears);
  }

  /// Age check (G-09). Returns null when eligible, otherwise the reason.
  String? ageBlockReason(int ageYears) {
    if (newbornOnly) {
      return ageYears == 0
          ? null
          : 'This screen is only for newborns in the first 28 days of life.';
    }
    if (minAgeYears != null && ageYears < minAgeYears!) {
      return allowOnRequest
          ? 'Offered from age $minAgeYears — you can still request it.'
          : 'This screen is for ages ${eligibilityLabel().replaceFirst('Ages ', '')}.';
    }
    if (maxAgeYears != null && ageYears > maxAgeYears!) {
      return 'This screen is for ages ${eligibilityLabel().replaceFirst('Ages ', '')}.';
    }
    return null;
  }
}

/// The four protocols. Copy is plain-language; Spec facts are cited inline,
/// protocol details not in the Spec are marked [DER].
class EyeProtocols {
  EyeProtocols._();

  /// Eye-section protocols.
  static const List<EyeProtocol> all = [jaundice, cataract, childEye, fundus];

  /// Skin & Body section protocols (same engine, body regions).
  static const List<EyeProtocol> skinBody = [
    newbornJaundice,
    diabeticFoot,
    skinLesion,
  ];

  /// Dental section protocols (mouth lining and teeth, torch + flash).
  static const List<EyeProtocol> dental = [oralLesion, dentalCaries];

  static const List<EyeProtocol> everything = [...all, ...skinBody, ...dental];

  static EyeProtocol? forScreenType(ImageScreenType? type) {
    if (type == null) return null;
    for (final p in everything) {
      if (p.screenType == type) return p;
    }
    return null;
  }

  static EyeProtocol? forId(String id) {
    for (final p in everything) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // 1. Adult jaundice (sclera) — ALG-IMG-02
  // ---------------------------------------------------------------------
  static const EyeProtocol jaundice = EyeProtocol(
    id: 'eye_jaundice',
    screenType: ImageScreenType.adultJaundice,
    featureId: 'F-16',
    introScreenId: 'S-E01',
    stepScreenIds: ['S-E02', 'S-E01', 'S-E03', 'S-E04'],
    title: 'Adult jaundice screen',
    shortTitle: 'Jaundice',
    recordTitle: 'Jaundice (Adult Sclera)',
    homeSubtitle: '4 photos · Sclera + card',
    algorithmId: 'ALG-IMG-02',
    algorithmName: 'Sclera colour CNN',
    algorithmSubtitle:
        'ALG-IMG-02 · sclera segmentation + CIELab b* (BiliScreen method)',
    algorithmVersion: '0.9.0-dev',
    rangeVersion: 'Bilirubin ref 2026.10',
    plainMessage:
        'The app looks at the colour of the white of your eye (the sclera) in two flash photos per eye, with a colour card in the frame to correct the lighting. '
        'A model measures how yellow the white is and turns that into a jaundice risk band. Yellow sclera usually means bilirubin above about 2.5 mg/dL.',
    partnerModel: false,
    modelConfidence: 0.86,
    conditionCode: 'COND_JAUNDICE',
    flash: true,
    dimRoom: false,
    distanceLabel: '15–20 cm',
    card: ColourCardPolicy.required,
    durationLabel: '~2 min',
    questions: [
      EyeQuestion(
        id: 'liver_disease',
        label: 'Known liver disease or hepatitis',
        note:
            'Known liver disease makes a High band more likely to be real — share it with your doctor.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'symptoms',
        label: 'Dark urine, pale stools, itching or belly pain',
        note:
            'These symptoms together with a High band need a blood test within days, not weeks.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'alcohol_24h',
        label: 'Alcohol in the last 24 hours',
        note: 'Noted for context — it does not change the photo result.',
      ),
      EyeQuestion(
        id: 'carotene_diet',
        label: 'Lots of carrots, papaya or pumpkin recently',
        note:
            'Carotene can tint the skin yellow but not the white of the eye, so the screen still works.',
      ),
      EyeQuestion(
        id: 'red_eye',
        label: 'Red, sore or infected eye today',
        note:
            'Redness and swelling change the sclera colour and can hide or mimic yellowing.',
        affectsReliability: true,
      ),
      EyeQuestion(
        id: 'lenses_makeup',
        label: 'Coloured contact lenses or eye make-up',
        note: 'Remove coloured lenses and wipe make-up before the photos.',
        affectsReliability: true,
      ),
      EyeQuestion(id: 'none', label: 'None of these'),
    ],
    beforeYouStart: [
      'Check the name and age on the first screen — tap Change there if they are wrong.',
      'Sit in neutral white light. Avoid yellow bulbs, candles and yellow walls — they tint the whole photo.',
      'Remove coloured contact lenses and wipe eye make-up. Do not use eye drops in the hour before.',
      'Hold the 24-patch colour card flat beside the eye so it is in every photo — the test cannot run without it (G-20).',
      'Look where the app asks (up, then toward your nose) and keep both lids wide open.',
      'If the app asks, retake — up to 3 attempts per photo. Eyes that still fail are marked "Not assessed".',
    ],
    beforeIllustrations: [
      EyeIllustration.lookUp,
      EyeIllustration.cardBesideEye,
      EyeIllustration.phoneDistanceFlash,
    ],
    howTo: [
      EyeHowToStep(
        EyeIllustration.cardBesideEye,
        'Hold the colour card beside the eye',
        'Keep the card flat, level with the eye and inside the frame. The app reads its 24 patches to correct colours (ΔE ≤ 5).',
      ),
      EyeHowToStep(
        EyeIllustration.lookUp,
        'Photo 1 of each eye: look up',
        'Looking up shows the white below the iris. Keep the lower lid relaxed and the eye wide open. The flash fires automatically.',
      ),
      EyeHowToStep(
        EyeIllustration.lookTowardNose,
        'Photo 2 of each eye: look toward your nose',
        'This exposes the wide outer white of the eye where yellowing shows most evenly [DER]. Order: Left 1, Left 2, Right 1, Right 2.',
      ),
      EyeHowToStep(
        EyeIllustration.holdStill,
        'Hold still until the app accepts',
        'Phone 15–20 cm away, flash on. The frame turns green when light, sharpness and framing pass, then captures after 2 s or when you tap the shutter.',
      ),
    ],
    examples: [
      EyeExample(
        EyeIllustration.scleraGoodExample,
        'Good: white clear, card in frame',
        good: true,
      ),
      EyeExample(EyeIllustration.glareExample, 'Glare: tilt the phone'),
      EyeExample(EyeIllustration.blurryExample, 'Blurry: tap to focus, retake'),
    ],
    views: [
      EyeView(
        id: 'L1',
        eye: EyeSide.left,
        index: 1,
        ofPerEye: 2,
        label: 'Left eye · look up',
        coaching:
            'Left eye: look up, card beside the eye, fill the guide with the eye, then tap the shutter.',
        gaze: EyeGaze.up,
        illustration: EyeIllustration.lookUp,
        target: PhotoTarget.sclera,
      ),
      EyeView(
        id: 'L2',
        eye: EyeSide.left,
        index: 2,
        ofPerEye: 2,
        label: 'Left eye · look toward nose',
        coaching:
            'Left eye: look toward your nose so the outer white shows, then tap the shutter.',
        gaze: EyeGaze.towardNose,
        illustration: EyeIllustration.lookTowardNose,
        target: PhotoTarget.sclera,
      ),
      EyeView(
        id: 'R1',
        eye: EyeSide.right,
        index: 1,
        ofPerEye: 2,
        label: 'Right eye · look up',
        coaching:
            'Right eye: look up, card beside the eye, fill the guide with the eye, then tap the shutter.',
        gaze: EyeGaze.up,
        illustration: EyeIllustration.lookUp,
        target: PhotoTarget.sclera,
      ),
      EyeView(
        id: 'R2',
        eye: EyeSide.right,
        index: 2,
        ofPerEye: 2,
        label: 'Right eye · look toward nose',
        coaching:
            'Right eye: look toward your nose so the outer white shows, then tap the shutter.',
        gaze: EyeGaze.towardNose,
        illustration: EyeIllustration.lookTowardNose,
        target: PhotoTarget.sclera,
      ),
    ],
    readsTitle: 'Colour of the white of the eye',
    readsCaption: 'Yellower sclera usually means more bilirubin in the blood',
    scale: EyeScale(
      labels: ['White', 'Light tint', 'Yellow'],
      bands: [SemanticBand.normal, SemanticBand.borderline, SemanticBand.high],
      gradient: [0xFFFFFFFF, 0xFFFBF3D5, 0xFFF4DD7A, 0xFFE2B91E],
    ),
    referenceTitle: 'Bilirubin reference (serum, mg/dL)',
    referenceRows: [
      ('Normal total bilirubin', '≤ 1.2'),
      ('Raised (lab)', '> 1.2'),
      ('Visible in the eye', '~2.5–3.0'),
      ('This screen flags', '> 2.5'),
    ],
    referenceNote:
        'The screen cannot measure bilirubin. It flags when the sclera colour matches the level at which jaundice becomes visible (~2.5 mg/dL). A blood test confirms.',
    inputsText:
        '2 flash photos of each eye (4 total): looking up, then toward the nose · 24-patch colour card in every photo (required) · your age',
    outputsText:
        'Jaundice band (Normal / Borderline / High) with a confidence level and next steps. The yellowness value and probability are listed under Algorithm outputs; the band is the decision until the model is validated.',
    checkedByText:
        'On-device photo quality checks (sharpness, glare, light, framing, colour card) on every photo · a specialist reviewer for High or borderline results (IMG-10)',
    miniSteps: [
      ('Photo', 'flash + card'),
      ('Colour fix', '24-patch card'),
      ('Model', 'sclera yellow'),
      ('Band', 'vs 2.5 mg/dL'),
    ],
    needs: [
      EyeNeedTile(
        EyeIllustration.phoneDistanceFlash,
        'Flash on',
        'rear camera',
      ),
      EyeNeedTile(EyeIllustration.cardBesideEye, 'Colour card', 'required'),
      EyeNeedTile(EyeIllustration.lookUp, 'Wide-open eye', 'look up / to nose'),
    ],
    bands: [
      EyeBandInfo(
        SemanticBand.normal,
        'Normal',
        'The white of the eye is not yellow. No action from this screen; repeat if you notice yellowing, dark urine or itching.',
      ),
      EyeBandInfo(
        SemanticBand.borderline,
        'Borderline',
        'A slight tint close to the threshold. Get a serum bilirubin test within a few days, or repeat the screen in white daylight.',
      ),
      EyeBandInfo(
        SemanticBand.high,
        'High',
        'The white looks yellow. Book a serum bilirubin and liver function test within 2 days — urgent if you also have dark urine, pale stools, itching or belly pain.',
      ),
      EyeBandInfo(
        SemanticBand.notAssessed,
        'Not assessed',
        'No usable photos (card not read or quality failed). Not a health result — retake in white light with the card flat beside the eye.',
      ),
    ],
    howMade: [
      (
        'Four flash photos with the colour card',
        'Two per eye, looking up then toward the nose. Each photo passed sharpness, glare, light, framing and card checks on the phone.',
      ),
      (
        'Colour correction',
        'The 24 card patches are matched to their known colours and a 3×3 matrix corrects the whole photo (ΔE ≤ 5), so lamp colour cannot fake yellowing.',
      ),
      (
        'Finding the white of the eye',
        'The sclera is segmented; vessels, glare spots and the iris are masked out before colour is measured.',
      ),
      (
        'Sclera colour model (ALG-IMG-02)',
        'Mean CIELab b* (blue–yellow) of the sclera plus a CNN give an internal jaundice probability. In clinical validation (IMG-JA-01, 300 people vs same-day serum bilirubin).',
      ),
      (
        'Risk rules',
        'Probability above the threshold gives a High band and an urgent blood test. Near the threshold the photos go to specialist review (IMG-10).',
      ),
    ],
    analysisStages: [
      'Reading the colour card (3×3 colour correction)',
      'Finding the white of the eye (sclera)',
      'Measuring yellowness (CIELab b*)',
      'Sclera colour model (ALG-IMG-02)',
      'Risk rules & specialist routing',
    ],
    gauge: EyeGaugeSpec(
      title: 'Yellowness index',
      breakpoints: [0, 0.40, 0.60, 1.0],
      labels: ['White', 'Tinted', 'Yellow'],
      bands: [SemanticBand.normal, SemanticBand.borderline, SemanticBand.high],
    ),
    noNumberNote:
        'The yellowness value (SCLERA_BSTAR) and probability (JAUNDICE_PROB) are shown under Algorithm outputs with their threshold τ; only the band drives the decision until the validation study (IMG-JA-01: sensitivity ≥ 85 %, specificity ≥ 90 %) passes — gate G-24.',
    demoOutcomeLabels: {
      'normal': 'Normal',
      'borderline': 'Borderline',
      'high': 'High (yellow)',
      'urgent': 'High + symptoms',
    },
    checklist: [
      'Flash works on the rear camera',
      'Camera lens is clean',
      'White light — no yellow bulbs',
    ],
    equipmentTitle: 'Colour card ready',
    equipmentCaption:
        'The 24-patch colour card is required for this screen (G-20, ALG-CAP-10 ΔE ≤ 5)',
    cardRequiredNote:
        'Yellowing is judged by colour, so the lighting must be corrected with the card. Without it this screen cannot run (G-20) — the result would be "Not assessed".',
    whoText: 'Adults · anyone with yellow eyes, dark urine or liver disease',
    helperIntroText:
        'A helper can hold the phone and the card if you find it hard to look away and tap at the same time.',
    disclaimerText:
        'Screening, not diagnosis. A High band is a prompt for a serum bilirubin test within 2 days, not a confirmed result.',
    bannerCopy: {
      UrgencyLevel.urgent: (
        'Possible jaundice — blood test within 2 days',
        'Rule T17 (BR-SCR-02): a High band on the sclera screen needs serum bilirubin and liver tests within days.',
      ),
      UrgencyLevel.routine: (
        'Possible jaundice — book a blood test',
        'Routine serum bilirubin and liver function tests.',
      ),
    },
    gaugeExplainer: '0 = white sclera, 1 = clearly yellow',
    nextStepsNormal: [
      'No test needed from this screen. Repeat if you notice yellow eyes, dark urine, pale stools or itching.',
      'Your doctor may still request a liver test as part of routine care.',
    ],
    nextStepsNotAssessed: [
      'Retake in white daylight with the colour card flat beside the eye.',
      'If there are symptoms (yellow eyes, dark urine, itching), see a clinician regardless of this screen.',
    ],
    nextHelper:
        'Next: a few questions, then 4 flash photos with the colour card',
    voicePrepare:
        'Jaundice screen. Answer the questions and confirm the colour card is ready, then tap Start the test.',
    voiceHowTo:
        'How to take the photos. Hold the colour card flat beside the eye. For the first photo of each eye look up; for the second look toward your nose. Tap Start photos when you are ready.',
    voiceAnalysing:
        'All four photos taken. Analysing the colour of the white of the eye.',
  );

  // ---------------------------------------------------------------------
  // 2. Cataract / lens opacity — ALG-IMG-03
  // ---------------------------------------------------------------------
  static const EyeProtocol cataract = EyeProtocol(
    id: 'eye_cataract',
    screenType: ImageScreenType.cataract,
    featureId: 'F-16',
    introScreenId: 'S-E01',
    stepScreenIds: ['S-E01', 'S-E01', 'S-E03', 'S-E04'],
    title: 'Cataract screen',
    shortTitle: 'Cataract',
    recordTitle: 'Cataract (Lens Opacity)',
    homeSubtitle: '2 photos · Pupil close-up',
    algorithmId: 'ALG-IMG-03',
    algorithmName: 'Lens opacity classifier',
    algorithmSubtitle:
        'ALG-IMG-03 · pupil crop + EfficientNet-lite, one run per eye',
    algorithmVersion: '0.9.0-dev',
    rangeVersion: 'LOCS-III ref 2026.10',
    plainMessage:
        'The app takes one close-up flash photo of the front of each eye in a dim room, so the pupil is large. '
        'A model looks at the lens behind the pupil and judges whether it looks cloudy (a cataract) or clear, one eye at a time.',
    partnerModel: false,
    modelConfidence: 0.87,
    conditionCode: 'COND_CATARACT',
    minAgeYears: 40,
    allowOnRequest: true,
    flash: true,
    dimRoom: true,
    distanceLabel: '10–15 cm',
    card: ColourCardPolicy.none,
    durationLabel: '~2 min',
    questions: [
      EyeQuestion(
        id: 'surgery_left',
        label: 'Cataract surgery or lens implant — left eye',
        note:
            'An operated eye has an artificial lens and is not screened; it is shown as "Operated".',
        affectsReliability: true,
        perEye: true,
      ),
      EyeQuestion(
        id: 'surgery_right',
        label: 'Cataract surgery or lens implant — right eye',
        note:
            'An operated eye has an artificial lens and is not screened; it is shown as "Operated".',
        affectsReliability: true,
        perEye: true,
      ),
      EyeQuestion(
        id: 'diabetes_steroids',
        label: 'Diabetes or long-term steroid use',
        note:
            'Both raise cataract risk — a High band is more likely to be real.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'symptoms',
        label: 'Blurred vision, glare at night or faded colours',
        note:
            'Typical cataract symptoms. Mention them when you book the eye exam.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'drops_today',
        label: 'Eye drops in the last hour',
        note:
            'Some drops change pupil size or add a film; wait an hour if you can.',
        affectsReliability: true,
      ),
      EyeQuestion(id: 'none', label: 'None of these'),
    ],
    beforeYouStart: [
      'Check the name and age on the first screen — tap Change there if they are wrong.',
      'Dim the room: lights off or curtains drawn. A bigger pupil shows more of the lens.',
      'Take glasses off and contact lenses out.',
      'Look straight at the camera lens — not at the screen — and keep the eye wide open.',
      'Hold the phone 10–15 cm from the eye with the pupil in the centre ring. The flash fires on each photo.',
      'If the app asks, retake — up to 3 attempts per photo. Eyes that still fail are marked "Not assessed".',
    ],
    beforeIllustrations: [
      EyeIllustration.dimRoom,
      EyeIllustration.glassesOff,
      EyeIllustration.pupilCentred,
    ],
    howTo: [
      EyeHowToStep(
        EyeIllustration.dimRoom,
        'Dim the room first',
        'Switch the lights off or draw the curtains and wait 30 seconds. The pupil opens wider so the lens is easier to see.',
      ),
      EyeHowToStep(
        EyeIllustration.pupilCentred,
        'Centre the pupil in the ring',
        'Phone 10–15 cm away, eye wide open, looking straight at the camera lens. The flash fires automatically.',
      ),
      EyeHowToStep(
        EyeIllustration.phoneDistanceFlash,
        'One photo of each eye',
        'Order: Left, then Right. Tilt the phone a little if the flash reflection sits over the pupil.',
      ),
      EyeHowToStep(
        EyeIllustration.holdStill,
        'Hold still until the app accepts',
        'The ring turns green when sharpness, glare and framing pass; the app then captures after 2 s or when you tap the shutter.',
      ),
    ],
    examples: [
      EyeExample(
        EyeIllustration.clearLensExample,
        'Good: pupil centred, lens visible',
        good: true,
      ),
      EyeExample(EyeIllustration.glareExample, 'Glare over pupil: tilt'),
      EyeExample(EyeIllustration.blurryExample, 'Blurry: tap to focus, retake'),
    ],
    views: [
      EyeView(
        id: 'L1',
        eye: EyeSide.left,
        index: 1,
        ofPerEye: 1,
        label: 'Left eye · pupil close-up',
        coaching:
            'Left eye: look straight at the lens, pupil in the ring, 10–15 cm away, then tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.pupilCentred,
        target: PhotoTarget.pupilLens,
      ),
      EyeView(
        id: 'R1',
        eye: EyeSide.right,
        index: 1,
        ofPerEye: 1,
        label: 'Right eye · pupil close-up',
        coaching:
            'Right eye: look straight at the lens, pupil in the ring, 10–15 cm away, then tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.pupilCentred,
        target: PhotoTarget.pupilLens,
      ),
    ],
    readsTitle: 'Clarity of the lens behind the pupil',
    readsCaption: 'A clear lens looks black; a cataract looks grey or white',
    scale: EyeScale(
      labels: ['Clear', 'Slight haze', 'Cloudy'],
      bands: [SemanticBand.normal, SemanticBand.borderline, SemanticBand.high],
      gradient: [0xFF0F172A, 0xFF475569, 0xFFA3B1C6, 0xFFE2E8F0],
    ),
    referenceTitle: 'Who is screened',
    referenceRows: [
      ('Offered routinely', 'Age 40 and over'),
      ('On request', 'Any adult (symptoms, diabetes, steroids)'),
      ('Surgery usually considered', 'Vision worse than 6/12 with opacity'),
      ('Operated eye', 'Not screened — artificial lens'),
    ],
    referenceNote:
        'Each eye gets its own band; the overall band is the worse eye. A High band means "see an eye doctor for a slit-lamp exam", not "you need surgery".',
    inputsText:
        '1 close-up flash photo of each eye (2 total) in a dim room · your age · any previous eye surgery',
    outputsText:
        'Cataract band per eye (Normal / Borderline / High) and an overall band with confidence and next steps. The probabilities are listed under Algorithm outputs; the band is the decision until the model is validated.',
    checkedByText:
        'On-device photo quality checks (sharpness, glare over the pupil, light, pupil framing) on every photo · a specialist reviewer for High or borderline results (IMG-10)',
    miniSteps: [
      ('Photo', 'dim room + flash'),
      ('Pupil crop', 'per eye'),
      ('Model', 'lens clarity'),
      ('Band', 'worse eye'),
    ],
    needs: [
      EyeNeedTile(EyeIllustration.dimRoom, 'Dim room', 'bigger pupil'),
      EyeNeedTile(EyeIllustration.phoneDistanceFlash, 'Flash on', '10–15 cm'),
      EyeNeedTile(EyeIllustration.glassesOff, 'Glasses off', 'lenses out'),
    ],
    bands: [
      EyeBandInfo(
        SemanticBand.normal,
        'Normal',
        'The lens looks clear in both eyes. Repeat every 1–2 years after 40, or sooner if vision changes.',
      ),
      EyeBandInfo(
        SemanticBand.borderline,
        'Borderline',
        'Some haze close to the threshold. A routine eye exam with a slit lamp will tell for sure.',
      ),
      EyeBandInfo(
        SemanticBand.high,
        'High',
        'The lens looks cloudy. Book a visual acuity and slit-lamp exam within 90 days. Surgery is only considered when vision is affected.',
      ),
      EyeBandInfo(
        SemanticBand.notAssessed,
        'Not assessed',
        'No usable pupil photo, or the eye has been operated. Not a health result — retake in a darker room.',
      ),
    ],
    howMade: [
      (
        'One flash photo per eye',
        'Taken in a dim room so the pupil is wide. Each photo passed sharpness, glare, light and pupil-framing checks on the phone.',
      ),
      (
        'Pupil crop',
        'The pupil and lens area is cropped from each photo; flash reflections are masked.',
      ),
      (
        'Lens opacity model (ALG-IMG-03)',
        'An EfficientNet-lite classifier runs once per eye and gives an internal cataract probability. In clinical validation (IMG-CA-01, 300 people vs same-day slit-lamp grading).',
      ),
      (
        'Per-eye bands',
        'Each eye gets Normal / Borderline / High; the overall band is the worse eye. Operated eyes are not graded.',
      ),
      (
        'Risk rules',
        'High means a routine eye exam within 90 days. Near the threshold the photos go to specialist review (IMG-10).',
      ),
    ],
    analysisStages: [
      'Cropping the pupil and lens area (per eye)',
      'Masking flash reflections',
      'Lens opacity model (ALG-IMG-03)',
      'Per-eye bands and overall band',
      'Risk rules & specialist routing',
    ],
    gauge: EyeGaugeSpec(
      title: 'Lens haze index',
      breakpoints: [0, 0.40, 0.60, 1.0],
      labels: ['Clear', 'Haze', 'Cloudy'],
      bands: [SemanticBand.normal, SemanticBand.borderline, SemanticBand.high],
    ),
    noNumberNote:
        'The per-eye probabilities (CATARACT_PROB_L / R) are shown under Algorithm outputs with their threshold τ; only the band drives the decision until the validation study (IMG-CA-01: sensitivity ≥ 85 %) passes — gate G-24.',
    demoOutcomeLabels: {
      'normal': 'Both clear',
      'borderline': 'One eye borderline',
      'high': 'Right eye cloudy',
      'urgent': 'Both eyes cloudy',
    },
    checklist: [
      'Room is dim (lights off / curtains drawn)',
      'Glasses off, contact lenses out',
      'Flash works on the rear camera',
    ],
    equipmentTitle: 'Dim room & flash',
    equipmentCaption:
        'No colour card for this screen. A dark room gives a bigger pupil; the flash lights the lens.',
    whoText:
        'Age 40 and over · younger adults on request (symptoms, diabetes, steroids)',
    helperIntroText:
        'A helper makes the close-up easier: you look at the lens, they hold the phone 10–15 cm away and tap.',
    disclaimerText:
        'Screening, not diagnosis. A High band means "see an eye doctor for a slit-lamp exam", not "you need surgery".',
    bannerCopy: {
      UrgencyLevel.routine: (
        'Possible cataract — book an eye exam',
        'Rule T18 (BR-SCR-04): routine visual acuity and slit-lamp exam within 90 days.',
      ),
      UrgencyLevel.urgent: (
        'Possible cataract — book an eye exam',
        'Rule T18 (BR-SCR-04): visual acuity and slit-lamp exam.',
      ),
    },
    gaugeExplainer: '0 = clear lens, 1 = dense opacity',
    nextStepsNormal: [
      'No test needed from this screen. Repeat every 1–2 years after 40, or sooner if vision changes.',
      'Your doctor may still request an eye exam as part of routine care.',
    ],
    nextStepsNotAssessed: [
      'Retake in a darker room with the pupil centred in the ring, 10–15 cm away.',
      'If vision is blurred or glare bothers you, see an eye doctor regardless of this screen.',
    ],
    nextHelper: 'Next: a few questions, then 1 photo of each eye',
    voicePrepare:
        'Cataract screen. Answer the questions, dim the room and take your glasses off, then tap Start the test.',
    voiceHowTo:
        'How to take the photos. Dim the room first. Look straight at the camera lens with the pupil in the ring, 10 to 15 centimetres away. One photo of each eye. Tap Start photos when ready.',
    voiceAnalysing: 'Both photos taken. Analysing the lens behind the pupil.',
  );

  // ---------------------------------------------------------------------
  // 3. Child eye (red reflex · Hirschberg · white pupil) — ALG-IMG-06
  // ---------------------------------------------------------------------
  static const EyeProtocol childEye = EyeProtocol(
    id: 'eye_child',
    screenType: ImageScreenType.childEye,
    featureId: 'F-16',
    introScreenId: 'S-E01',
    stepScreenIds: ['S-E01', 'S-E01', 'S-E03', 'S-E04'],
    title: 'Child eye screen',
    shortTitle: 'Child eye',
    recordTitle: 'Child Eye Screen (Ages 1–12)',
    homeSubtitle: '2 photos · Both eyes, dim room',
    algorithmId: 'ALG-IMG-06',
    algorithmName: 'Red-reflex & corneal-reflex analyser',
    algorithmSubtitle:
        'ALG-IMG-06 · Brückner red-reflex asymmetry + Hirschberg geometry + leukocoria detector',
    algorithmVersion: '0.9.0-dev',
    rangeVersion: 'Hirschberg 12–15°/mm ref 2026.10',
    plainMessage:
        'A parent takes a flash photo of the child\'s face from about an arm\'s length in a dim room while the child looks at the phone light. '
        'The app compares the red glow in the two pupils (red reflex), checks where the small flash reflection sits on each eye (a squint shifts it), and looks for a white pupil, which always needs an urgent check.',
    partnerModel: false,
    modelConfidence: 0.85,
    conditionCode: 'COND_CHILD_EYE',
    minAgeYears: 1,
    maxAgeYears: 12,
    guardianRequired: true,
    flash: true,
    dimRoom: true,
    distanceLabel: '0.5–1 m',
    card: ColourCardPolicy.none,
    durationLabel: '~1 min',
    questions: [
      EyeQuestion(
        id: 'parent_noticed',
        label: 'A parent has noticed a turned eye or a white glow in photos',
        note:
            'A noticed squint or white glow is itself a reason for a paediatric eye exam.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'family_history',
        label: 'Family history of squint, lazy eye or childhood eye tumour',
        note:
            'Raises the chance that a Refer result is real — share it with the eye doctor.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'glasses_patching',
        label: 'Already wears glasses or has had patching',
        note:
            'Glasses must be off for the photo; previous treatment is useful context for the reviewer.',
        affectsReliability: true,
      ),
      EyeQuestion(
        id: 'drops_today',
        label: 'Eye drops today or a red, sticky eye',
        note:
            'Infection or drops change the reflex and can hide or mimic a problem.',
        affectsReliability: true,
      ),
      EyeQuestion(
        id: 'premature',
        label: 'Born early (before 34 weeks)',
        note:
            'Premature children have a higher risk of eye problems — noted for the reviewer.',
      ),
      EyeQuestion(id: 'none', label: 'None of these'),
    ],
    beforeYouStart: [
      'Check that the child\'s profile is selected on the first screen and that a parent or guardian has given consent (G-04/G-05).',
      'A parent or helper holds the phone — the child never holds it. Say who is taking the photo.',
      'Make the room dim: lights off, curtains drawn. In a bright room the pupils shrink and the red glow disappears.',
      'Take the child\'s glasses off. Sit them facing you, 0.5–1 m away, phone at the child\'s eye level.',
      'Show the phone light so the child looks straight at the camera; both eyes must be in the frame, face straight.',
      'Take two photos. If the app asks, retake — up to 3 attempts per photo. Photos that still fail are marked "Not assessed".',
    ],
    beforeIllustrations: [
      EyeIllustration.dimRoom,
      EyeIllustration.childDistance,
      EyeIllustration.childLookAtLight,
    ],
    howTo: [
      EyeHowToStep(
        EyeIllustration.dimRoom,
        'Dim the room',
        'Lights off, curtains drawn, wait 30 seconds. Big pupils are what makes the red glow visible.',
      ),
      EyeHowToStep(
        EyeIllustration.childDistance,
        'Sit 0.5–1 m away, at eye level',
        'The child faces you squarely. Hold the phone steady at the height of the child\'s eyes, both eyes inside the wide frame.',
      ),
      EyeHowToStep(
        EyeIllustration.childLookAtLight,
        'Get the child to look at the phone light',
        'A short light blinks before the shot so the child looks straight at the camera. Both eyes open, no glasses, nothing in front of the face.',
      ),
      EyeHowToStep(
        EyeIllustration.holdStill,
        'Two photos, hold still',
        'The flash fires on each photo. The frame turns green when the pupils are found; the app captures after 2 s or when you tap the shutter.',
      ),
    ],
    examples: [
      EyeExample(
        EyeIllustration.redReflexNormal,
        'Good: two even red reflexes',
        good: true,
      ),
      EyeExample(
        EyeIllustration.redReflexAsymmetric,
        'Uneven glow: retake, then refer',
      ),
      EyeExample(EyeIllustration.blurryExample, 'Blurry / not looking: retake'),
    ],
    views: [
      EyeView(
        id: 'B1',
        eye: null,
        index: 1,
        ofPerEye: 2,
        label: 'Both eyes · photo 1',
        coaching:
            'Both eyes in the wide frame, child looking at the light, 0.5–1 m away, then tap the shutter.',
        gaze: EyeGaze.atLight,
        illustration: EyeIllustration.childLookAtLight,
        target: PhotoTarget.bothPupils,
      ),
      EyeView(
        id: 'B2',
        eye: null,
        index: 2,
        ofPerEye: 2,
        label: 'Both eyes · photo 2',
        coaching:
            'One more: same position, child looking at the light, then tap the shutter.',
        gaze: EyeGaze.atLight,
        illustration: EyeIllustration.childLookAtLight,
        target: PhotoTarget.bothPupils,
      ),
    ],
    readsTitle: 'Red reflex and corneal light reflex',
    readsCaption:
        'Even red glow + centred flash dots = normal; uneven, shifted or white = refer',
    scale: EyeScale(
      labels: ['Even red', 'Uneven / shifted', 'White pupil'],
      bands: [SemanticBand.normal, SemanticBand.refer, SemanticBand.refer],
      gradient: [0xFFB91C1C, 0xFFE05A3A, 0xFFF5D0A9, 0xFFFFFFFF],
    ),
    referenceTitle: 'What the photo checks',
    referenceRows: [
      ('Red reflex', 'Both pupils glow the same red (Brückner test)'),
      (
        'Flash dot position',
        'Centred in both eyes; ≈ 12–15° of squint per mm of shift (Hirschberg)',
      ),
      ('White pupil', 'Any white or yellow glow — always urgent (T11)'),
      ('Ages', '1–12 years, guardian consent'),
    ],
    referenceNote:
        'This is the photo version of the torch tests a paediatrician does. It does not measure eyesight; a Refer result means "book a children\'s eye exam", a white pupil means "within days".',
    inputsText:
        '2 flash photos of both eyes (dim room, 0.5–1 m, child looking at the phone light) · the child\'s age · who took the photo',
    outputsText:
        'Child eye band (Normal / Borderline / Refer / White pupil — urgent) with confidence and next steps. Reflex asymmetry, squint degrees and the white-pupil probability are listed under Algorithm outputs.',
    checkedByText:
        'On-device photo quality checks (sharpness, flash glare, light, both pupils found) on every photo · a specialist reviewer for Refer results; white pupil is always escalated (IMG-10)',
    miniSteps: [
      ('Photo', 'dim room + flash'),
      ('Pupils', 'find both'),
      ('Reflexes', 'red + flash dot'),
      ('Band', 'refer / urgent'),
    ],
    needs: [
      EyeNeedTile(EyeIllustration.dimRoom, 'Dim room', 'lights off'),
      EyeNeedTile(
        EyeIllustration.childDistance,
        'Parent holds',
        '0.5–1 m away',
      ),
      EyeNeedTile(EyeIllustration.glassesOff, 'Glasses off', 'face straight'),
    ],
    bands: [
      EyeBandInfo(
        SemanticBand.normal,
        'Normal',
        'Both pupils glow evenly and the flash dots are centred. Repeat yearly or if a parent notices an eye turning.',
      ),
      EyeBandInfo(
        SemanticBand.borderline,
        'Borderline',
        'A small difference close to the threshold. A specialist reviews the photos; a routine children\'s eye exam is sensible.',
      ),
      EyeBandInfo(
        SemanticBand.refer,
        'Refer',
        'The flash dot is shifted or the red glow differs between the eyes — possible squint or unequal focus. Book a paediatric eye exam within 30 days.',
      ),
      EyeBandInfo(
        SemanticBand.emergency,
        'White pupil — urgent',
        'A white or yellow pupil glow can be a sign of cataract, retinal disease or a tumour. See a children\'s eye doctor within days (T11).',
      ),
      EyeBandInfo(
        SemanticBand.notAssessed,
        'Not assessed',
        'The child was not looking or the pupils were too small. Not a health result — retake in a darker room.',
      ),
    ],
    howMade: [
      (
        'Two flash photos of both eyes',
        'Dim room, 0.5–1 m, child looking at the phone light. Each photo passed sharpness, glare, light and both-pupils checks on the phone.',
      ),
      (
        'Finding the pupils and limbus',
        'Both pupils and the iris edges are located; the pupil centres and sizes are measured in millimetres.',
      ),
      (
        'Red-reflex comparison',
        'Brightness and colour of the glow in the two pupils are compared (REFLEX_ASYM 0–1). Large differences suggest unequal focus or a blocked light path.',
      ),
      (
        'Corneal light reflex (Hirschberg)',
        'The flash dot offset from each pupil centre is converted to degrees (≈ 12–15° per mm). A consistent offset in one eye suggests a squint.',
      ),
      (
        'White-pupil detector and rules',
        'A trained detector scores leukocoria. White pupil is always Urgent (T11, BR-SCR-02); Refer means a routine exam. Near the threshold the photos go to specialist review (IMG-10).',
      ),
    ],
    analysisStages: [
      'Finding both pupils and iris edges',
      'Comparing the red reflex (Brückner)',
      'Measuring flash-dot offset (Hirschberg)',
      'White-pupil detector (leukocoria)',
      'Risk rules & specialist routing',
    ],
    gauge: EyeGaugeSpec(
      title: 'Reflex difference',
      breakpoints: [0, 0.25, 0.40, 1.0],
      labels: ['Even', 'Slight', 'Uneven'],
      bands: [SemanticBand.normal, SemanticBand.borderline, SemanticBand.refer],
    ),
    noNumberNote:
        'Reflex asymmetry, squint degrees (HIRSCHBERG_DEG) and the white-pupil probability are shown under Algorithm outputs with their threshold τ; only the band drives the decision until the validation study (IMG-CE-01: sensitivity ≥ 80 %, white pupil ≥ 95 %) passes — gate G-24.',
    demoOutcomeLabels: {
      'normal': 'Normal',
      'borderline': 'Borderline',
      'high': 'Refer (squint)',
      'urgent': 'White pupil',
    },
    checklist: [
      'Room is dim (lights off / curtains drawn)',
      'Child\'s glasses are off',
      'Flash works on the rear camera',
    ],
    equipmentTitle: 'Room and phone',
    equipmentCaption:
        'Dim room, flash on the rear camera, held by an adult. No colour card for this screen.',
    whoText: 'Children aged 1–12 · a parent or guardian takes the photo',
    helperIntroText:
        'The child never holds the phone. A second adult can hold the child\'s attention from behind the phone.',
    disclaimerText:
        'Screening, not diagnosis. Refer means "book a children\'s eye exam"; a white pupil always means "within days".',
    bannerCopy: {
      UrgencyLevel.urgent: (
        'White pupil — children\'s eye doctor within days',
        'Rule T11 (BR-SCR-02): a white pupil reflex is always urgent until an eye doctor has looked.',
      ),
      UrgencyLevel.routine: (
        'Possible squint — paediatric eye exam',
        'Rule T19 (BR-SCR-04): routine paediatric eye exam within 30 days.',
      ),
    },
    gaugeExplainer: '0 = identical red reflexes, 1 = one pupil dark or white',
    nextStepsNormal: [
      'No test needed from this screen. Repeat yearly, or sooner if a parent notices an eye turning or a white glow in photos.',
      'Your doctor may still request an eye exam as part of routine care.',
    ],
    nextStepsNotAssessed: [
      'Retake in a darker room, 0.5–1 m away, with the child looking at the phone light.',
      'If a parent has noticed a turned eye or a white glow, see a children\'s eye doctor regardless of this screen.',
    ],
    nextHelper: 'Next: a few questions, then 2 flash photos of both eyes',
    voicePrepare:
        'Child eye screen. Answer the questions, say who is taking the photo, and dim the room. Then tap Start the test.',
    voiceHowTo:
        'How to take the photos. Lights off. Sit the child half a metre to one metre away at eye level. The phone light will blink so the child looks at the camera. Two photos of both eyes. Tap Start photos when ready.',
    voiceAnalysing:
        'Both photos taken. Analysing the red reflex in each pupil.',
  );

  // ---------------------------------------------------------------------
  // 4. Diabetic retinopathy & glaucoma (fundus, partner AI) — ALG-IMG-09
  // ---------------------------------------------------------------------
  static const EyeProtocol fundus = EyeProtocol(
    id: 'eye_fundus',
    screenType: ImageScreenType.fundusDrGlaucoma,
    featureId: 'F-17',
    introScreenId: 'S-E06',
    stepScreenIds: ['S-E06', 'S-E06', 'S-E06', 'S-E06', 'S-E06'],
    title: 'Retina screen (fundus)',
    shortTitle: 'Retina',
    recordTitle: 'Diabetic Retinopathy & Glaucoma (Fundus)',
    homeSubtitle: '4 photos · Clip-on camera',
    algorithmId: 'ALG-IMG-09',
    algorithmName: 'Partner retina AI',
    algorithmSubtitle:
        'ALG-IMG-09 · licensed partner model (Medios-class) via FundusPartnerAdapter',
    algorithmVersion: 'partner_v3.2',
    rangeVersion: 'ICDR 2026',
    plainMessage:
        'A small clip-on camera over the phone lens photographs the back of each eye (the retina) — one picture centred on the macula, one on the optic disc. '
        'A licensed partner AI grades diabetic retinopathy on the international ICDR scale, checks for macular swelling, and flags a large optic-disc cup that can mean glaucoma.',
    partnerModel: true,
    modelConfidence: 0.93,
    conditionCode: 'COND_DR',
    extraConditionCodes: ['COND_GLAUCOMA'],
    operatorLed: true,
    flash: false,
    dimRoom: true,
    distanceLabel: 'Eyepiece on the eye',
    card: ColourCardPolicy.none,
    requiresFundusCamera: true,
    durationLabel: '~3 min',
    questions: [
      EyeQuestion(
        id: 'diabetes_known',
        label: 'Known diabetes',
        note:
            'Years with diabetes and sugar control are the main risk factors — the reviewer will see this.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'hba1c_known',
        label: 'HbA1c result in the last 3 months',
        note:
            'Useful context; enter the value in the Labs section to pair it with this scan.',
      ),
      EyeQuestion(
        id: 'last_exam',
        label: 'Eye exam in the last 12 months',
        note: 'A recent dilated exam may already cover this result.',
      ),
      EyeQuestion(
        id: 'laser_injection',
        label: 'Laser or eye injection treatment before',
        note:
            'Previous treatment changes the retina appearance and the pairing rules (≤ 90 days, no treatment between).',
        affectsReliability: true,
      ),
      EyeQuestion(
        id: 'cataract_known',
        label: 'Known cataract or very small pupils',
        note:
            'A cloudy lens or small pupil can make the retina image ungradable — dilation may be needed.',
        affectsReliability: true,
      ),
      EyeQuestion(
        id: 'symptoms',
        label: 'Sudden blur, floaters or a dark curtain in vision',
        note: 'These symptoms need an eye doctor regardless of this screen.',
        escalates: true,
      ),
      EyeQuestion(id: 'none', label: 'None of these'),
    ],
    beforeYouStart: [
      'An operator runs this screen. Confirm the person\'s profile and that they agree to share de-identified retina images with the partner AI.',
      'Attach the clip-on fundus camera over the rear lens and connect it (G-31). The status chip must read "Connected".',
      'Sit in a dark room for about 5 minutes so the pupils open naturally — no dilating drops are needed for most people.',
      'Glasses off. Rest the eyepiece gently against the eye socket; the person looks at the green fixation light inside.',
      'Take two pictures per eye: macula-centred (look at the central light) then disc-centred (look at the side light).',
      'If the image cannot be graded after 3 attempts, the app suggests dark-room dilation or a dilated eye exam instead.',
    ],
    beforeIllustrations: [
      EyeIllustration.fundusClipOn,
      EyeIllustration.dimRoom,
      EyeIllustration.fundusFixation,
    ],
    howTo: [
      EyeHowToStep(
        EyeIllustration.fundusClipOn,
        'Attach and connect the clip-on camera',
        'Clip it squarely over the rear lens and wait for "Connected". The camera lights the retina with its own infrared and white LEDs — the phone flash stays off.',
      ),
      EyeHowToStep(
        EyeIllustration.dimRoom,
        'Dark room, 5 minutes',
        'Pupils open naturally in the dark. Small pupils or a cataract make the image ungradable — then dilating drops or a dilated exam are needed.',
      ),
      EyeHowToStep(
        EyeIllustration.fundusFixation,
        'Macula photo, then disc photo — each eye',
        'The person looks at the central green light (macula-centred), then at the side light so the optic disc moves to the centre (disc-centred). Left eye first, then right.',
      ),
      EyeHowToStep(
        EyeIllustration.holdStill,
        'Hold the eyepiece steady',
        'Rest it on the eye socket, keep it still until the app accepts the image. Up to 3 attempts per view.',
      ),
    ],
    examples: [
      EyeExample(
        EyeIllustration.fundusMaculaExample,
        'Good: retina sharp, macula centred',
        good: true,
      ),
      EyeExample(
        EyeIllustration.fundusDiscExample,
        'Good: optic disc centred',
        good: true,
      ),
      EyeExample(EyeIllustration.blurryExample, 'Ungradable: dark or blurred'),
    ],
    views: [
      EyeView(
        id: 'L1',
        eye: EyeSide.left,
        index: 1,
        ofPerEye: 2,
        label: 'Left eye · macula-centred',
        coaching:
            'Left eye: look at the central green light. Hold the eyepiece steady, then tap the shutter.',
        gaze: EyeGaze.atLight,
        illustration: EyeIllustration.fundusMaculaExample,
        target: PhotoTarget.fundus,
      ),
      EyeView(
        id: 'L2',
        eye: EyeSide.left,
        index: 2,
        ofPerEye: 2,
        label: 'Left eye · disc-centred',
        coaching:
            'Left eye: look at the side light so the optic disc is centred, then tap the shutter.',
        gaze: EyeGaze.sideLight,
        illustration: EyeIllustration.fundusDiscExample,
        target: PhotoTarget.fundus,
      ),
      EyeView(
        id: 'R1',
        eye: EyeSide.right,
        index: 1,
        ofPerEye: 2,
        label: 'Right eye · macula-centred',
        coaching:
            'Right eye: look at the central green light. Hold the eyepiece steady, then tap the shutter.',
        gaze: EyeGaze.atLight,
        illustration: EyeIllustration.fundusMaculaExample,
        target: PhotoTarget.fundus,
      ),
      EyeView(
        id: 'R2',
        eye: EyeSide.right,
        index: 2,
        ofPerEye: 2,
        label: 'Right eye · disc-centred',
        coaching:
            'Right eye: look at the side light so the optic disc is centred, then tap the shutter.',
        gaze: EyeGaze.sideLight,
        illustration: EyeIllustration.fundusDiscExample,
        target: PhotoTarget.fundus,
      ),
    ],
    readsTitle: 'Retina grade (ICDR) and optic-disc cup',
    readsCaption:
        'From no retinopathy to sight-threatening changes; a large cup suggests glaucoma',
    scale: EyeScale(
      labels: ['None / mild', 'Moderate (referable)', 'Severe · PDR · DME'],
      bands: [SemanticBand.normal, SemanticBand.refer, SemanticBand.refer],
      gradient: [0xFFF59E0B, 0xFFD97706, 0xFFB45309, 0xFF7C2D12],
    ),
    referenceTitle: 'ICDR grades and what they mean',
    referenceRows: [
      ('No DR', 'No changes — screen again in 12 months'),
      (
        'Mild NPDR',
        'A few microaneurysms — not referable, repeat in 12 months',
      ),
      ('Moderate NPDR', 'Referable — eye doctor within 90 days'),
      ('Severe NPDR', 'Referable — eye doctor within weeks'),
      ('PDR or DME', 'Sight-threatening — urgent, within days'),
      (
        'Glaucoma suspect',
        'Large cup-to-disc ratio — routine glaucoma work-up',
      ),
    ],
    referenceNote:
        'Referable = moderate NPDR or worse, or macular oedema (DME). The grades are produced by the licensed partner AI and shown as given; a dilated eye exam confirms them.',
    inputsText:
        '2 retina photos of each eye (macula-centred and disc-centred) from the clip-on fundus camera · diabetes history · partner data-sharing consent',
    outputsText:
        'DR grade per eye (ICDR), referable yes / no, macular oedema flag and glaucoma suspect flag — displayed as partner results with confidence and next steps.',
    checkedByText:
        'Gradability check on every image (partner CAP-08 equivalent) · licensed partner AI (verified on 100 local cases vs dilated exam / OCT) · specialist review when referable or glaucoma suspect (IMG-10)',
    miniSteps: [
      ('Connect', 'clip-on camera'),
      ('4 photos', 'macula + disc'),
      ('Partner AI', 'ICDR grade'),
      ('Rules', 'refer / urgent'),
    ],
    needs: [
      EyeNeedTile(
        EyeIllustration.fundusClipOn,
        'Clip-on camera',
        'connected (G-31)',
      ),
      EyeNeedTile(EyeIllustration.dimRoom, 'Dark room', '5 min, no drops'),
      EyeNeedTile(
        EyeIllustration.fundusFixation,
        'Fixation light',
        'centre, then side',
      ),
    ],
    bands: [
      EyeBandInfo(
        SemanticBand.normal,
        'No referable DR',
        'No or only mild retinopathy and no glaucoma sign. Screen again in 12 months; keep sugar, blood pressure and lipids controlled.',
      ),
      EyeBandInfo(
        SemanticBand.mild,
        'Mild NPDR',
        'Early changes that do not need treatment. Repeat in 12 months (6 if sugar control is poor) and tighten control.',
      ),
      EyeBandInfo(
        SemanticBand.refer,
        'Referable',
        'Moderate NPDR or worse, macular oedema, or a glaucoma suspect disc. Book a dilated eye exam within 90 days — within days if PDR or DME.',
      ),
      EyeBandInfo(
        SemanticBand.notAssessed,
        'Not gradable',
        'The images were too dark or blurred, often because of small pupils or a cataract. Not a health result — dilate in a dark room and retake, or book a dilated exam.',
      ),
    ],
    howMade: [
      (
        'Four retina images',
        'Macula-centred and disc-centred per eye from the clip-on camera. Each image passed the gradability check.',
      ),
      (
        'Upload to the partner AI',
        'De-identified images go to the licensed partner through the FundusPartnerAdapter (consent G-04 partner share). If the partner times out the images are kept and retried.',
      ),
      (
        'Diabetic retinopathy grading',
        'The partner model grades each eye on the ICDR scale (none to PDR) and flags macular oedema (DME).',
      ),
      (
        'Optic-disc analysis',
        'The cup-to-disc ratio and nerve-fibre layer are assessed; a large or asymmetric cup sets the glaucoma-suspect flag.',
      ),
      (
        'Referral rules',
        'Moderate NPDR or worse, or DME, is Referable (Routine, within 90 days). PDR or DME is Urgent. A glaucoma-suspect disc gets a routine work-up. Referable results go to specialist review (IMG-10).',
      ),
    ],
    analysisStages: [
      'Gradability check on 4 images',
      'Uploading de-identified images to the partner AI',
      'Diabetic retinopathy grading (ICDR)',
      'Optic-disc cup analysis (glaucoma)',
      'Referral rules & specialist routing',
    ],
    gauge: EyeGaugeSpec(
      title: 'Retinopathy grade',
      breakpoints: [0, 1.5, 2.5, 5.0],
      labels: ['None · mild', 'Moderate', 'Severe · PDR'],
      bands: [SemanticBand.normal, SemanticBand.refer, SemanticBand.refer],
    ),
    noNumberNote: null,
    demoOutcomeLabels: {
      'normal': 'No DR',
      'borderline': 'Mild NPDR',
      'high': 'Moderate NPDR + glaucoma suspect',
      'urgent': 'PDR + DME',
    },
    checklist: [
      'Clip-on camera attached and connected',
      'Person has been in a dark room for 5 minutes',
      'Glasses off, eyepiece clean',
    ],
    equipmentTitle: 'Clip-on fundus camera',
    equipmentCaption:
        'Non-mydriatic clip-on camera over the rear lens, connected by Bluetooth or USB-C (G-15 / G-31). Partner AI licence active.',
    whoText:
        'People with diabetes or at risk · run by an operator with the clip-on camera',
    helperIntroText:
        'An operator runs this screen. The person only needs to rest against the eyepiece and look at the light.',
    disclaimerText:
        'Screening, not diagnosis. Partner grades are shown as given; a dilated eye exam confirms them and decides treatment.',
    bannerCopy: {
      UrgencyLevel.urgent: (
        'Sight-threatening retinopathy — eye doctor within days',
        'Rule T21 (BR-SCR-02): PDR or macular oedema on the partner grade needs urgent dilated examination.',
      ),
      UrgencyLevel.routine: (
        'Referable retina finding — eye exam within 90 days',
        'Rule T20 / T22 (BR-SCR-04): referable retinopathy or a glaucoma-suspect disc needs a routine dilated exam.',
      ),
    },
    gaugeExplainer: 'ICDR grade 0 (none) to 4 (PDR), +½ for macular oedema',
    nextStepsNormal: [
      'Screen again in 12 months. Keep HbA1c, blood pressure and lipids in range — they protect the retina.',
      'Your doctor may still request an eye exam as part of routine care.',
    ],
    nextStepsNotAssessed: [
      'Wait longer in a dark room so the pupils open, or book a dilated eye exam instead.',
      'If you notice sudden floaters, blur or a dark curtain, see an eye doctor regardless of this screen.',
    ],
    nextHelper: 'Next: connect the camera, then 4 retina photos',
    notAssessedHint:
        'No attempts left for this view (G-25). It will be marked "Not gradable" — consider dark-room dilation or a dilated eye exam.',
    voicePrepare:
        'Retina screen. Answer the questions and confirm the person has been in a dark room for five minutes, then tap Start the test.',
    voiceHowTo:
        'How to take the photos. Rest the eyepiece on the eye socket. The person looks at the central green light for the macula photo, then at the side light for the disc photo. Left eye first, then right. Tap Start photos when ready.',
    voiceAnalysing:
        'All four images taken. Uploading to the partner AI for grading.',
  );

  // =====================================================================
  // Skin & Body section
  // =====================================================================

  // ---------------------------------------------------------------------
  // 5. Newborn jaundice (0–28 days) — ALG-IMG-07
  // ---------------------------------------------------------------------
  static const EyeProtocol newbornJaundice = EyeProtocol(
    id: 'body_newborn',
    screenType: ImageScreenType.newbornJaundice,
    featureId: 'F-16',
    introScreenId: 'S-E01',
    stepScreenIds: ['S-E02', 'S-E01', 'S-E03', 'S-E04'],
    title: 'Newborn jaundice screen',
    shortTitle: 'Newborn jaundice',
    recordTitle: 'Newborn Jaundice (0–28 Days)',
    homeSubtitle: '4 photos · Skin + card',
    algorithmId: 'ALG-IMG-07',
    algorithmName: 'Skin bilirubin regression',
    algorithmSubtitle:
        'ALG-IMG-07 · card-corrected skin colour · bilirubin regression · hour-specific chart',
    algorithmVersion: '0.9.0-dev',
    rangeVersion: 'AAP-2022 chart stand-in',
    plainMessage:
        'The app photographs the skin of the baby\'s forehead and chest next to a colour card, once without and once with the flash (the BiliCam / Picterus method). '
        'The card corrects for the room light and the phone camera; a model turns the corrected skin colour into a bilirubin estimate and compares it with the treatment line for the baby\'s age in hours and weeks of gestation.',
    partnerModel: false,
    modelConfidence: 0.86,
    conditionCode: 'COND_NEO_JAUNDICE',
    guardianRequired: true,
    newbornOnly: true,
    flash: false,
    dimRoom: false,
    distanceLabel: '20–25 cm',
    card: ColourCardPolicy.mandatory,
    durationLabel: '~2 min',
    category: 'Skin & Body',
    partNoun: 'baby\'s skin',
    perSideTitle: 'Forehead and chest',
    perSideCaption:
        'Two photos per area (no flash, then flash) · the band above combines both areas',
    zonesInsteadOfSides: true,
    cardPlacementCopy: 'flat on the baby\'s skin beside the area',
    cardRequiredNote:
        'Bilirubin is judged purely from skin colour, so the card must correct the light in every photo. Without it the screen never shows "Normal" (E-IMG-003) — ask the clinic for a serum or TcB bilirubin instead.',
    extraInputs: {EyeExtraInput.newbornDetails},
    resultIcon: 'baby',
    questions: [
      EyeQuestion(
        id: 'sibling_phototherapy',
        label: 'A brother or sister needed phototherapy',
        note:
            'A sibling who needed light treatment raises the baby\'s risk (AAP risk factor).',
        escalates: true,
      ),
      EyeQuestion(
        id: 'bruising',
        label: 'Bruising or a swollen lump on the head from birth',
        note:
            'Bruises and cephalhaematoma release extra bilirubin as they heal.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'blood_group',
        label:
            'Mother\'s blood group is O or Rh-negative, or incompatibility was mentioned',
        note:
            'Blood-group incompatibility can break down red cells quickly — treat a High band as urgent.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'feeding',
        label: 'Exclusively breastfed with poor feeding or weight loss',
        note: 'Low intake slows bilirubin clearance; feeding support helps.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'ancestry_g6pd',
        label: 'East-Asian ancestry or G6PD deficiency in the family',
        note:
            'Both raise the chance of a high bilirubin peak (AAP neurotoxicity risk list).',
        escalates: true,
      ),
      EyeQuestion(
        id: 'phototherapy_now',
        label: 'Baby has had or is under phototherapy',
        note:
            'Light treatment bleaches the skin faster than the blood clears, so skin colour under-reads. The result is not reliable (pairing exclusion).',
        affectsReliability: true,
      ),
      EyeQuestion(
        id: 'unwell',
        label: 'Baby is sleepy, feeding poorly, has a fever or is hard to wake',
        note:
            'An unwell baby needs a doctor today regardless of the colour result.',
        escalates: true,
      ),
      EyeQuestion(id: 'none', label: 'None of these'),
    ],
    beforeYouStart: [
      'Check the baby\'s age in hours, weeks of gestation and birth weight on the first screen — the treatment line depends on them.',
      'A parent or operator takes the photos; record who (photographer type).',
      'Lay the baby on its back, calm and undressed to the chest, near a window in daylight. No coloured curtains, no yellow bulbs, no phototherapy lamp on.',
      'Wipe cream, oil or vernix off the forehead and chest with a soft cloth.',
      'Place the 24-patch card flat on the skin beside the area so the card and the skin share the same light — it must be in every photo.',
      'Hold the phone 20–25 cm away, parallel to the skin. The app takes one photo without and one with the flash for each area.',
    ],
    beforeIllustrations: [
      EyeIllustration.babyOnBack,
      EyeIllustration.cardOnChest,
      EyeIllustration.daylightWindow,
    ],
    howTo: [
      EyeHowToStep(
        EyeIllustration.daylightWindow,
        'Daylight, no lamps',
        'Sit near a window. Switch off yellow bulbs and any phototherapy light. The card corrects small differences, not a coloured room.',
      ),
      EyeHowToStep(
        EyeIllustration.cardOnChest,
        'Card on the chest, then the forehead',
        'Lay the card flat on the skin beside the breastbone (sternum) with its patches facing up. For the forehead hold it level beside the brow.',
      ),
      EyeHowToStep(
        EyeIllustration.wipeCream,
        'Clean, bare skin',
        'Wipe off cream or vernix. The skin patch between the card and the guide must be bare, dry and not red from rubbing.',
      ),
      EyeHowToStep(
        EyeIllustration.holdStill,
        'Two shots per area — no flash, then flash',
        'Phone 20–25 cm away, parallel to the skin. The app captures when the card and skin are framed; the second shot fires the flash automatically.',
      ),
    ],
    examples: [
      EyeExample(
        EyeIllustration.cardOnChest,
        'Good: card flat on skin, even light',
        good: true,
      ),
      EyeExample(EyeIllustration.glareExample, 'Glare on card: tilt the phone'),
      EyeExample(
        EyeIllustration.blurryExample,
        'Blurry: wait until baby is still',
      ),
    ],
    views: [
      EyeView(
        id: 'F1',
        eye: null,
        index: 1,
        ofPerEye: 2,
        label: 'Forehead · no flash',
        coaching:
            'Forehead: card flat beside the brow, phone 20–25 cm away, parallel to the skin. Tap the shutter — no flash this time.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.cardOnChest,
        target: PhotoTarget.skinPatch,
        flash: false,
        zoneLabel: 'Forehead',
        zoneCode: 'F1',
      ),
      EyeView(
        id: 'F2',
        eye: null,
        index: 2,
        ofPerEye: 2,
        label: 'Forehead · with flash',
        coaching:
            'Same position on the forehead. This shot fires the flash — keep the card in the frame.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.cardOnChest,
        target: PhotoTarget.skinPatch,
        flash: true,
        zoneLabel: 'Forehead',
        zoneCode: 'F2',
      ),
      EyeView(
        id: 'C1',
        eye: null,
        index: 1,
        ofPerEye: 2,
        label: 'Chest · no flash',
        coaching:
            'Chest: lay the card flat beside the breastbone, bare skin in the guide, phone 20–25 cm away. Tap the shutter — no flash.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.cardOnChest,
        target: PhotoTarget.skinPatch,
        flash: false,
        zoneLabel: 'Chest',
        zoneCode: 'C1',
      ),
      EyeView(
        id: 'C2',
        eye: null,
        index: 2,
        ofPerEye: 2,
        label: 'Chest · with flash',
        coaching:
            'Same position on the chest. This shot fires the flash — keep the card and skin together in the frame.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.cardOnChest,
        target: PhotoTarget.skinPatch,
        flash: true,
        zoneLabel: 'Chest',
        zoneCode: 'C2',
      ),
    ],
    readsTitle: 'Yellowness of the baby\'s skin',
    readsCaption:
        'Jaundice spreads from the face down the body as bilirubin rises; forehead and chest are the reference spots',
    scale: EyeScale(
      labels: ['Pink', 'Light yellow', 'Yellow'],
      bands: [SemanticBand.normal, SemanticBand.borderline, SemanticBand.high],
      gradient: [0xFFF8D7C9, 0xFFF6DFA8, 0xFFF2C94C, 0xFFE0A106],
    ),
    referenceTitle: 'Phototherapy line (AAP 2022, 38 weeks, no risk factors)',
    referenceRows: [
      ('24 hours old', '12.3 mg/dL'),
      ('48 hours old', '16.0 mg/dL'),
      ('72 hours old', '18.8 mg/dL'),
      ('96 hours old', '20.7 mg/dL'),
      ('With risk factors', 'Line about 2 mg/dL lower'),
      ('Under 35 weeks', 'Chart not validated — clinic TcB / serum'),
    ],
    referenceNote:
        'The line rises with age in hours and depends on gestation and risk factors. The app uses a stand-in copy of the AAP 2022 tables until the reference-range master is loaded. A baby at or above the line needs a serum bilirubin within 6 hours.',
    inputsText:
        '4 photos: forehead and chest, each without and with flash · 24-patch colour card on the skin (mandatory) · age in hours, gestation weeks, birth weight · risk-factor questions · who took the photo',
    outputsText:
        'Newborn jaundice band (Normal / Borderline / High) against the hour-specific phototherapy line, with confidence and next steps. The bilirubin estimate (NEO_BILI_EST) stays internal until the model is validated.',
    checkedByText:
        'On-device photo quality checks (sharpness, glare, light, skin area, colour card) on every photo · a specialist reviewer for High or borderline results (IMG-10)',
    miniSteps: [
      ('Photos', 'card + skin'),
      ('Colour fix', '24-patch card'),
      ('Bilirubin', 'estimate'),
      ('Chart', 'age in hours'),
    ],
    needs: [
      EyeNeedTile(EyeIllustration.cardOnChest, 'Colour card', 'mandatory'),
      EyeNeedTile(
        EyeIllustration.daylightWindow,
        'Daylight',
        'no yellow lamps',
      ),
      EyeNeedTile(EyeIllustration.babyOnBack, 'Calm baby', 'on its back'),
    ],
    bands: [
      EyeBandInfo(
        SemanticBand.normal,
        'Normal',
        'Skin colour is well below the treatment line for the baby\'s age. Keep feeding well and repeat the screen daily until day 5, or sooner if the baby looks more yellow.',
      ),
      EyeBandInfo(
        SemanticBand.borderline,
        'Borderline',
        'Within about 3 mg/dL of the line. Repeat in 6–12 hours or ask the clinic for a transcutaneous (TcB) check today; the line keeps rising with age, so a repeat usually settles it.',
      ),
      EyeBandInfo(
        SemanticBand.high,
        'High — urgent',
        'At or above the phototherapy-consideration line. Take the baby for a serum bilirubin within 6 hours; the newborn unit decides on phototherapy.',
      ),
      EyeBandInfo(
        SemanticBand.notAssessed,
        'Not assessed',
        'No usable photo, no colour card, or the chart does not apply (under 35 weeks or over 28 days). Not a health result — ask the clinic for a TcB or serum bilirubin.',
      ),
    ],
    howMade: [
      (
        'Four photos with the colour card',
        'Forehead and chest, each without and with flash (BiliCam / Picterus method). Each photo passed sharpness, glare, light, skin-area and card checks on the phone.',
      ),
      (
        'Colour correction',
        'The 24 card patches are matched to their known colours and a 3×3 matrix corrects each photo (ΔE ≤ 5), so the room light and the phone camera cannot tint the skin.',
      ),
      (
        'Skin colour features',
        'The bare skin patch beside the card is measured (CIELab b* yellowness, red/yellow ratio) in the flash and no-flash pairs.',
      ),
      (
        'Bilirubin regression (ALG-IMG-07)',
        'A regression model turns the corrected colour into an internal bilirubin estimate (mg/dL). In clinical validation (IMG-NJ-01, 300 newborns vs same-hour serum bilirubin).',
      ),
      (
        'Hour-specific chart',
        'The estimate is compared with the phototherapy line for the baby\'s age in hours, gestation and risk factors (AAP 2022 stand-in). At or above the line gives a High band and an urgent serum test.',
      ),
    ],
    analysisStages: [
      'Reading the colour card in all 4 photos',
      'Measuring skin yellowness (forehead, chest)',
      'Bilirubin regression (ALG-IMG-07)',
      'Looking up the phototherapy line for this baby',
      'Risk rules & specialist routing',
    ],
    gauge: EyeGaugeSpec(
      title: 'Skin yellowness',
      breakpoints: [0, 0.40, 0.60, 1.0],
      labels: ['Pink', 'Tinted', 'Yellow'],
      bands: [SemanticBand.normal, SemanticBand.borderline, SemanticBand.high],
    ),
    noNumberNote:
        'The bilirubin estimate (NEO_BILI_EST, mg/dL) stays internal until the validation study (IMG-NJ-01: sensitivity ≥ 90 % at the treatment threshold) passes — gate G-24. Until then only the band against the line is shown.',
    demoOutcomeLabels: {
      'normal': 'Below the line',
      'borderline': 'Near the line',
      'high': 'Above the line',
      'urgent': 'Well above + risk factors',
    },
    checklist: [
      'Baby is calm, undressed to the chest, lying on its back',
      'Daylight only — yellow lamps and phototherapy light off',
      'Forehead and chest wiped clean of cream or vernix',
    ],
    equipmentTitle: 'Colour card ready',
    equipmentCaption:
        'The 24-patch colour card is mandatory for this screen (G-20, ALG-CAP-10 ΔE ≤ 5) — never shows Normal without it',
    whoText:
        'Newborns 0–28 days · photos taken by a parent or an operator with guardian consent',
    helperIntroText:
        'Two adults make it easy: one keeps the baby calm and holds the card flat, the other holds the phone and taps.',
    disclaimerText:
        'Screening, not diagnosis. A High band means "serum bilirubin within 6 hours", not "the baby needs phototherapy" — the newborn unit decides.',
    bannerCopy: {
      UrgencyLevel.urgent: (
        'Possible newborn jaundice — serum bilirubin within 6 hours',
        'Rule T23 (BR-SCR-02): skin colour at or above the phototherapy-consideration line for this baby\'s age and gestation.',
      ),
      UrgencyLevel.routine: (
        'Near the treatment line — recheck within 6–12 hours',
        'Rule T23 (BR-SCR-04): borderline skin colour; repeat the screen or ask for a transcutaneous bilirubin today.',
      ),
    },
    gaugeExplainer: '0 = pink skin, 1 = deep yellow',
    nextStepsNormal: [
      'No test needed from this screen. Repeat once a day until day 5 (jaundice peaks on days 3–5), and sooner if the yellow spreads to the belly or legs.',
      'Feed often (8–12 times a day). Sleepiness, poor feeding or a fever need a doctor the same day.',
    ],
    nextStepsNotAssessed: [
      'Retake in daylight with the card flat on the skin beside the area, baby calm and still.',
      'If the baby looks yellow, is sleepy or feeds poorly, ask the clinic for a transcutaneous or serum bilirubin today regardless of this screen.',
    ],
    nextHelper:
        'Next: confirm baby details and risk factors, then 4 photos with the colour card',
    notAssessedHint:
        'No attempts left for this photo (G-25). It will be marked "Not assessed" — without a readable card the screen cannot show Normal (E-IMG-003).',
    voicePrepare:
        'Newborn jaundice screen. Check the baby\'s age in hours and gestation, answer the risk-factor questions, and confirm the colour card is ready. Then tap Start the test.',
    voiceHowTo:
        'How to take the photos. Lay the baby on its back in daylight. Place the colour card flat on the skin beside the forehead, then beside the chest. Hold the phone twenty to twenty-five centimetres away. Each area gets one photo without flash and one with flash. Tap Start photos when ready.',
    voiceAnalysing:
        'All four photos taken. Correcting colours with the card and comparing with the treatment line for this baby.',
  );

  // ---------------------------------------------------------------------
  // 6. Diabetic foot ulcer & callus — ALG-IMG-05
  // ---------------------------------------------------------------------
  static const EyeProtocol diabeticFoot = EyeProtocol(
    id: 'body_foot',
    screenType: ImageScreenType.diabeticFoot,
    featureId: 'F-16',
    introScreenId: 'S-E01',
    stepScreenIds: ['S-E02', 'S-E01', 'S-E03', 'S-E04'],
    title: 'Diabetic foot screen',
    shortTitle: 'Diabetic foot',
    recordTitle: 'Diabetic Foot Ulcer & Callus Screen',
    homeSubtitle: '4 photos · Soles + toes',
    algorithmId: 'ALG-IMG-05',
    algorithmName: 'Foot ulcer & callus detector',
    algorithmSubtitle:
        'ALG-IMG-05 · YOLO detector (ulcer, callus, colour change) + wound segmentation',
    algorithmVersion: '0.9.0-dev',
    rangeVersion: 'IWGDF-2023 risk ref',
    plainMessage:
        'The app photographs the sole, heel and the spaces between the toes of each foot with a colour card lying beside the foot for scale. '
        'A detector looks for ulcers, hard skin (callus), cracks and colour changes, measures any wound in cm², and your answers place you in a foot-risk category that sets how often to check.',
    partnerModel: false,
    modelConfidence: 0.87,
    conditionCode: 'COND_DFU',
    flash: false,
    dimRoom: false,
    distanceLabel: '20–30 cm',
    card: ColourCardPolicy.required,
    durationLabel: '~3 min',
    category: 'Skin & Body',
    partNoun: 'foot',
    sideLabels: {EyeSide.left: 'Left foot', EyeSide.right: 'Right foot'},
    perSideTitle: 'Your feet',
    perSideCaption:
        'Sole & heel and between-toes photo per foot · the band above is the worse foot',
    recheckLabel: 'Monthly (G-34)',
    cardPlacementCopy: 'flat on the floor beside the sole',
    cardRequiredNote:
        'The card gives the millimetre scale used to measure any wound (WOUND_AREA cm²). Without it the screen cannot measure size (G-20).',
    resultIcon: 'foot',
    questions: [
      EyeQuestion(
        id: 'diabetes_years',
        label: 'Diabetes for more than 10 years',
        note:
            'Long-standing diabetes raises nerve and circulation damage risk.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'numbness',
        label: 'Numb, tingling or burning feet',
        note:
            'Loss of feeling (neuropathy) means injuries go unnoticed — IWGDF risk category 1 or higher.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'previous_ulcer',
        label: 'Previous foot ulcer or amputation',
        note:
            'Highest risk group (IWGDF category 3) — foot checks every 1–3 months.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'circulation',
        label: 'Cold feet, or leg pain when walking that eases with rest',
        note:
            'Signs of poor circulation (peripheral artery disease) — slows healing.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'current_wound',
        label: 'A wound, blister, cut or colour change on a foot right now',
        note:
            'Point the camera at it in the sole photo; a wound needs the foot clinic within days.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'footwear',
        label: 'New, tight or worn-out shoes',
        note:
            'Pressure spots from footwear are the usual cause of callus and ulcers.',
      ),
      EyeQuestion(
        id: 'recent_treatment',
        label: 'Foot treated or dressed in the last 3 days',
        note:
            'Dressings and recent treatment change what the photo shows (pairing exclusion).',
        affectsReliability: true,
      ),
      EyeQuestion(
        id: 'cannot_see_soles',
        label: 'I cannot see my own soles easily',
        note: 'Ask a helper to take the photos, or use a mirror on the floor.',
      ),
      EyeQuestion(id: 'none', label: 'None of these'),
    ],
    beforeYouStart: [
      'Socks off, feet washed and dried, no cream or talc. Do not remove dressings — note them instead.',
      'Sit on a chair in bright, even light with the foot resting on the opposite knee, or lie down with a helper holding the phone.',
      'Lay the 24-patch card flat on the floor or bed beside the sole so the whole foot and the card are in the frame.',
      'Hold the phone 20–30 cm away, parallel to the sole. The photo must show the whole sole from toes to heel.',
      'For the toes photo, spread the toes gently with a finger so the skin between them is visible.',
      'If the app asks, retake — up to 3 attempts per photo. Photos that still fail are marked "Not assessed".',
    ],
    beforeIllustrations: [
      EyeIllustration.helperHoldsFoot,
      EyeIllustration.footSoleWithCard,
      EyeIllustration.toesSpread,
    ],
    howTo: [
      EyeHowToStep(
        EyeIllustration.helperHoldsFoot,
        'Get the sole facing the camera',
        'Foot on the opposite knee, or lie down and let a helper photograph. Bright even light, no shadows across the sole.',
      ),
      EyeHowToStep(
        EyeIllustration.footSoleWithCard,
        'Card beside the sole, whole foot in frame',
        'Card flat beside the foot, phone 20–30 cm away and parallel. Toes at the top of the frame, heel at the bottom.',
      ),
      EyeHowToStep(
        EyeIllustration.toesSpread,
        'Between the toes',
        'Spread the toes with a finger and photograph the spaces where the skin is soft and often cracks.',
      ),
      EyeHowToStep(
        EyeIllustration.holdStill,
        'Left foot, then right',
        'Order: left sole & heel, left toes, right sole & heel, right toes. The frame turns green when sharp and framed; capture after 2 s or tap the shutter.',
      ),
    ],
    examples: [
      EyeExample(
        EyeIllustration.footGoodExample,
        'Good: whole sole, card beside it',
        good: true,
      ),
      EyeExample(
        EyeIllustration.footCallusExample,
        'Callus and cracks: still fine to photograph',
      ),
      EyeExample(EyeIllustration.blurryExample, 'Blurry / shadowed: retake'),
    ],
    views: [
      EyeView(
        id: 'L1',
        eye: EyeSide.left,
        index: 1,
        ofPerEye: 2,
        label: 'Left foot · sole & heel',
        coaching:
            'Left foot: whole sole from toes to heel in the frame, card flat beside it, phone 20–30 cm away. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.footSoleWithCard,
        target: PhotoTarget.footSole,
        zoneLabel: 'Sole & heel',
      ),
      EyeView(
        id: 'L2',
        eye: EyeSide.left,
        index: 2,
        ofPerEye: 2,
        label: 'Left foot · between toes',
        coaching:
            'Left foot: spread the toes and show the skin between them. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.toesSpread,
        target: PhotoTarget.footSole,
        zoneLabel: 'Between toes',
      ),
      EyeView(
        id: 'R1',
        eye: EyeSide.right,
        index: 1,
        ofPerEye: 2,
        label: 'Right foot · sole & heel',
        coaching:
            'Right foot: whole sole from toes to heel in the frame, card flat beside it, phone 20–30 cm away. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.footSoleWithCard,
        target: PhotoTarget.footSole,
        zoneLabel: 'Sole & heel',
      ),
      EyeView(
        id: 'R2',
        eye: EyeSide.right,
        index: 2,
        ofPerEye: 2,
        label: 'Right foot · between toes',
        coaching:
            'Right foot: spread the toes and show the skin between them. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.toesSpread,
        target: PhotoTarget.footSole,
        zoneLabel: 'Between toes',
      ),
    ],
    readsTitle: 'Skin of the sole, heel and toes',
    readsCaption: 'Healthy skin · callus, cracks or colour change · open wound',
    scale: EyeScale(
      labels: ['Healthy', 'At risk', 'Ulcer'],
      bands: [SemanticBand.normal, SemanticBand.atRisk, SemanticBand.ulcer],
      gradient: [0xFFF5D6C6, 0xFFE9C39F, 0xFFD98B6A, 0xFFB42318],
    ),
    referenceTitle: 'Foot-risk categories (IWGDF 2023) and how often to check',
    referenceRows: [
      ('0 · No loss of feeling, good circulation', 'Yearly check'),
      ('1 · Loss of feeling or poor circulation', 'Every 6–12 months'),
      ('2 · Both, or with a foot deformity', 'Every 3–6 months'),
      ('3 · Previous ulcer or amputation', 'Every 1–3 months'),
      ('Open wound (ulcer)', 'Foot clinic within 3 days'),
    ],
    referenceNote:
        'The category comes from your answers [DER]; the photo adds what the skin shows today. The app repeats this screen monthly for people with diabetes (G-34).',
    inputsText:
        '4 photos: sole & heel and between the toes of each foot · 24-patch card beside the sole for size (required) · diabetes, nerve, circulation and wound questions',
    outputsText:
        'Foot band per foot (Healthy / At risk / Ulcer) and overall, wound area in cm² when an ulcer is seen, foot-risk category and recheck interval. Detector probabilities are listed under Algorithm outputs.',
    checkedByText:
        'On-device photo quality checks (sharpness, glare, light, whole foot in frame, card) on every photo · a specialist reviewer for ulcer or borderline results (IMG-10)',
    miniSteps: [
      ('Photos', 'soles + toes'),
      ('Scale', 'card mm/px'),
      ('Detector', 'ulcer · callus'),
      ('Risk', 'IWGDF category'),
    ],
    needs: [
      EyeNeedTile(EyeIllustration.footSoleWithCard, 'Colour card', 'for size'),
      EyeNeedTile(
        EyeIllustration.helperHoldsFoot,
        'Helper or mirror',
        'to see the sole',
      ),
      EyeNeedTile(EyeIllustration.daylightWindow, 'Bright light', 'no shadows'),
    ],
    bands: [
      EyeBandInfo(
        SemanticBand.normal,
        'Healthy',
        'No ulcer, callus or colour change seen. Keep the monthly photo check, inspect your feet daily and wear well-fitting shoes.',
      ),
      EyeBandInfo(
        SemanticBand.atRisk,
        'At risk',
        'Callus, dry cracks, redness or a pressure mark was seen, or your answers place you in a higher risk category. Routine foot-clinic review; podiatry can remove callus safely.',
      ),
      EyeBandInfo(
        SemanticBand.ulcer,
        'Ulcer — urgent',
        'An open wound was seen. Keep weight off it, do not treat it yourself, and go to the foot clinic within 3 days — same day if red, hot, smelly or you have a fever.',
      ),
      EyeBandInfo(
        SemanticBand.notAssessed,
        'Not assessed',
        'The sole or toes could not be seen clearly, or the card was missing. Not a health result — retake with a helper in bright light.',
      ),
    ],
    howMade: [
      (
        'Four photos with the card',
        'Sole & heel and between the toes of each foot. Each photo passed sharpness, glare, light, whole-foot and card checks on the phone.',
      ),
      (
        'Scale from the card',
        'The card\'s known patch size gives millimetres per pixel so any wound can be measured in cm² (ALG-CAP-10).',
      ),
      (
        'Ulcer & callus detector (ALG-IMG-05)',
        'A YOLO-family detector marks ulcers, callus, cracks and colour changes; a segmentation model outlines any wound to compute its area. In clinical validation (IMG-DF-01, 300 patients vs same-day foot-clinic exam, ulcer sensitivity ≥ 85 %).',
      ),
      (
        'Per-foot bands',
        'Each foot gets Healthy / At risk / Ulcer; the overall band is the worse foot.',
      ),
      (
        'Risk category and rules',
        'Your answers set the IWGDF foot-risk category (0–3) and recheck interval [DER]. An ulcer is Urgent (foot clinic ≤ 3 days); At risk is Routine.',
      ),
    ],
    analysisStages: [
      'Reading the card for scale (mm per pixel)',
      'Finding each foot and the toe spaces',
      'Ulcer, callus and colour-change detector (ALG-IMG-05)',
      'Measuring any wound area (cm²)',
      'Risk category, rules & specialist routing',
    ],
    gauge: EyeGaugeSpec(
      title: 'Skin damage index',
      breakpoints: [0, 0.35, 0.65, 1.0],
      labels: ['Healthy', 'At risk', 'Ulcer'],
      bands: [SemanticBand.normal, SemanticBand.atRisk, SemanticBand.ulcer],
    ),
    noNumberNote:
        'Detector probabilities (DFU_PROB) are shown under Algorithm outputs with their threshold τ; only the band drives the decision until the validation study (IMG-DF-01: ulcer sensitivity ≥ 85 %) passes — gate G-24. The wound area is shown when an ulcer is seen and the card was read.',
    demoOutcomeLabels: {
      'normal': 'Healthy feet',
      'borderline': 'Callus + cracks (left)',
      'high': 'Ulcer right heel',
      'urgent': 'Infected ulcer',
    },
    checklist: [
      'Socks off, feet washed and dried, no cream',
      'Bright, even light — no shadow across the sole',
      'Helper ready or mirror placed on the floor',
    ],
    equipmentTitle: 'Colour card for size',
    equipmentCaption:
        'The 24-patch card lying flat beside the sole gives the scale for wound area (G-20, ALG-CAP-10)',
    whoText:
        'People with diabetes or a high diabetes-risk band · monthly (G-10 / G-34) · anyone else on request',
    helperIntroText:
        'A helper makes the sole photos much easier: you sit or lie down, they hold the phone 20–30 cm away and tap.',
    disclaimerText:
        'Screening, not diagnosis. An Ulcer band means "foot clinic within 3 days"; At risk means "routine foot review" — do not treat wounds yourself.',
    bannerCopy: {
      UrgencyLevel.urgent: (
        'Foot ulcer seen — foot clinic within 3 days',
        'Rule T24 (BR-SCR-02): an open wound on a diabetic foot needs a clinician exam, monofilament and circulation check within days.',
      ),
      UrgencyLevel.routine: (
        'Foot at risk — book a foot review',
        'Rule T25 (BR-SCR-04): callus, cracks or risk factors need routine podiatry / foot-clinic review.',
      ),
    },
    gaugeExplainer: '0 = healthy skin, 1 = open wound',
    nextStepsNormal: [
      'No clinic visit needed from this screen. The app will ask for the next foot photos in 30 days (G-34).',
      'Check your feet daily, moisturise dry skin (not between the toes), and never walk barefoot.',
    ],
    nextStepsNotAssessed: [
      'Retake with a helper in bright light: whole sole in the frame, card flat beside it.',
      'If you have a wound, redness or pain in a foot, go to the foot clinic regardless of this screen.',
    ],
    nextHelper:
        'Next: a few questions, then 4 photos of your soles and toes with the card',
    voicePrepare:
        'Diabetic foot screen. Answer the questions, take your socks off, and confirm the colour card is ready. Then tap Start the test.',
    voiceHowTo:
        'How to take the photos. Sit with the foot on the opposite knee or lie down with a helper. Lay the card flat beside the sole. Hold the phone twenty to thirty centimetres away with the whole sole in the frame, then spread the toes for the second photo. Left foot first, then right. Tap Start photos when ready.',
    voiceAnalysing:
        'All four photos taken. Looking for ulcers, callus and colour changes, and measuring any wound.',
  );

  // ---------------------------------------------------------------------
  // 7. Skin condition & suspicious lesion — ALG-IMG-08
  // ---------------------------------------------------------------------
  static const EyeProtocol skinLesion = EyeProtocol(
    id: 'body_skin',
    screenType: ImageScreenType.skinLesion,
    featureId: 'F-16',
    introScreenId: 'S-E01',
    stepScreenIds: ['S-E01', 'S-E01', 'S-E03', 'S-E04'],
    title: 'Skin check',
    shortTitle: 'Skin check',
    recordTitle: 'Skin Condition & Lesion Check',
    homeSubtitle: '3 photos · Spot close-up',
    algorithmId: 'ALG-IMG-08',
    algorithmName: 'Skin lesion classifier',
    algorithmSubtitle:
        'ALG-IMG-08 · CNN classifier (ISIC-trained) + suspicious-lesion detector',
    algorithmVersion: '0.9.0-dev',
    rangeVersion: 'ABCDE ref 2026.10',
    plainMessage:
        'You take three photos of one skin spot or rash: a close-up, an angled close-up and a wider shot that shows where it is on the body (the DermAssist / SkinVision method). '
        'A model compares the spot with thousands of dermatologist-labelled images, suggests the most likely common conditions, and separately flags patterns that look like skin cancer so you can be seen quickly.',
    partnerModel: false,
    modelConfidence: 0.84,
    conditionCode: 'COND_SKIN',
    flash: false,
    dimRoom: false,
    distanceLabel: '10–15 cm',
    card: ColourCardPolicy.preferred,
    durationLabel: '~2 min',
    category: 'Skin & Body',
    partNoun: 'skin spot',
    perSideTitle: 'Your skin spot',
    perSideCaption: 'Close-up, angled and context photos of the same spot',
    zonesInsteadOfSides: true,
    cardPlacementCopy: 'flat on the skin beside the spot',
    extraInputs: {
      EyeExtraInput.bodyLocation,
      EyeExtraInput.duration,
      EyeExtraInput.abcde,
      EyeExtraInput.skinType,
    },
    bodyLocations: [
      'Face or scalp',
      'Neck',
      'Chest or back',
      'Arm or hand',
      'Leg or foot',
      'Other',
    ],
    durationOptions: ['Under 1 month', '1–6 months', 'Over 6 months', 'Years'],
    abcdeItems: [
      ('asymmetry', 'A — one half looks different from the other'),
      ('border', 'B — edge is ragged, notched or blurred'),
      ('colour', 'C — more than one colour (brown, black, red, white, blue)'),
      ('diameter', 'D — wider than 6 mm (a pencil eraser)'),
      ('evolving', 'E — changed in size, shape, colour or feel recently'),
    ],
    resultIcon: 'skin',
    questions: [
      EyeQuestion(
        id: 'itch_bleed',
        label: 'Itches, bleeds, crusts or hurts',
        note:
            'Symptoms matter: a mole that bleeds or crusts without injury needs a dermatologist.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'sun_history',
        label: 'Outdoor work or past blistering sunburns',
        note: 'UV exposure is the main risk factor for skin cancers.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'cancer_history',
        label: 'Personal or family history of skin cancer',
        note:
            'Previous skin cancer or a close relative with melanoma raises risk.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'immunosuppressed',
        label:
            'Organ transplant, chemotherapy or long-term immune-suppressing medicine',
        note:
            'Skin cancers are more common and grow faster when the immune system is suppressed.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'treated',
        label: 'Already diagnosed or being treated for this spot',
        note:
            'Creams and treatment change how the spot looks — mention the diagnosis to the reviewer.',
        affectsReliability: true,
      ),
      EyeQuestion(
        id: 'tattoo_makeup',
        label: 'Tattoo, make-up or hair over the spot',
        note:
            'Cover-up and hair hide the pattern; shave or wipe the area if you can.',
        affectsReliability: true,
      ),
      EyeQuestion(id: 'none', label: 'None of these'),
    ],
    beforeYouStart: [
      'Check the name and age on the first screen — tap Change there if they are wrong.',
      'Use daylight near a window, flash off. Wipe make-up or cream off the spot; trim thick hair over it if you can.',
      'Place the colour card (or a coin) flat beside the spot for scale — preferred, not required.',
      'Hold the phone 10–15 cm away, parallel to the skin, with the spot centred in the ring. Your own shadow must not fall on it.',
      'Take the angled close-up and then a wider photo from arm\'s length that shows where the spot is.',
      'If the app asks, retake — up to 3 attempts per photo. Photos that still fail are marked "Not assessed".',
    ],
    beforeIllustrations: [
      EyeIllustration.daylightWindow,
      EyeIllustration.lesionCentred,
      EyeIllustration.lesionContextArm,
    ],
    howTo: [
      EyeHowToStep(
        EyeIllustration.lesionCentred,
        'Close-up, spot in the ring',
        'Phone 10–15 cm away, parallel to the skin, spot centred in the ring with normal skin around it. Flash off, no shadow, no hair across it.',
      ),
      EyeHowToStep(
        EyeIllustration.lesionAngled,
        'Angled close-up',
        'Same distance, phone tilted about 30°. The angle shows whether the spot is raised, scaly or shiny.',
      ),
      EyeHowToStep(
        EyeIllustration.lesionContextArm,
        'Context from arm\'s length',
        'Step back so the body part is visible (arm, back, leg). This records where the spot is and how it compares with your other moles.',
      ),
      EyeHowToStep(
        EyeIllustration.coinScale,
        'Scale beside the spot',
        'Lay the colour card or a coin flat beside the spot in the close-up so the app can measure its size in millimetres.',
      ),
    ],
    examples: [
      EyeExample(
        EyeIllustration.lesionGoodExample,
        'Good: centred, even light, scale beside',
        good: true,
      ),
      EyeExample(
        EyeIllustration.lesionHairShadowExample,
        'Hair or shadow over the spot: fix and retake',
      ),
      EyeExample(EyeIllustration.blurryExample, 'Blurry: tap to focus, retake'),
    ],
    views: [
      EyeView(
        id: 'S1',
        eye: null,
        index: 1,
        ofPerEye: 3,
        label: 'Close-up · spot in the ring',
        coaching:
            'Spot centred in the ring, 10–15 cm away, flash off, no shadow. Card or coin beside it. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.lesionCentred,
        target: PhotoTarget.lesion,
        zoneLabel: 'Close-up',
        zoneCode: 'S1',
      ),
      EyeView(
        id: 'S2',
        eye: null,
        index: 2,
        ofPerEye: 3,
        label: 'Angled close-up',
        coaching:
            'Same spot, phone tilted about 30 degrees to show texture and height. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.lesionAngled,
        target: PhotoTarget.lesion,
        zoneLabel: 'Angled',
        zoneCode: 'S2',
      ),
      EyeView(
        id: 'S3',
        eye: null,
        index: 3,
        ofPerEye: 3,
        label: 'Context · arm\'s length',
        coaching:
            'Step back to arm\'s length so the body part and the spot are both visible. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.lesionContextArm,
        target: PhotoTarget.skinPatch,
        zoneLabel: 'Context',
        zoneCode: 'S3',
      ),
    ],
    readsTitle: 'Pattern, colour and edge of the spot',
    readsCaption:
        'Common rashes and moles look regular; cancers break the ABCDE rules',
    scale: EyeScale(
      labels: ['Benign pattern', 'Needs a look', 'Suspicious'],
      bands: [SemanticBand.normal, SemanticBand.refer, SemanticBand.suspicious],
      gradient: [0xFFF6D5C4, 0xFFD7A98A, 0xFF8B5A3C, 0xFF2B1B14],
    ),
    referenceTitle: 'ABCDE warning signs for melanoma',
    referenceRows: [
      ('A · Asymmetry', 'Two halves do not match'),
      ('B · Border', 'Ragged, notched or blurred edge'),
      ('C · Colour', 'Several shades in one spot'),
      ('D · Diameter', 'Wider than 6 mm'),
      ('E · Evolving', 'Changing in size, shape, colour or symptoms'),
      ('Pearly, scaly or non-healing sore', 'Basal / squamous cell pattern'),
    ],
    referenceNote:
        'Two or more ABCDE signs, or any changing spot, should be checked by a dermatologist even when the app says benign. Suggested conditions are matches, not a diagnosis.',
    inputsText:
        '3 photos of one spot: close-up, angled close-up, context from arm\'s length · colour card or coin for scale (preferred) · body location, how long, ABCDE checklist, symptoms, skin type and history',
    outputsText:
        'Skin band (Benign / Needs a look / Suspicious — urgent), up to three possible matching conditions shown as names, spot size in mm when a scale was present, and next steps. Class probabilities are listed under Algorithm outputs.',
    checkedByText:
        'On-device photo quality checks (sharpness, glare, light, spot centred) on every photo · a specialist reviewer for Suspicious or borderline results (IMG-10)',
    miniSteps: [
      ('3 photos', 'close + context'),
      ('Pattern', 'colour · edge'),
      ('Classifier', 'ISIC-trained'),
      ('Band', 'benign / refer'),
    ],
    needs: [
      EyeNeedTile(EyeIllustration.daylightWindow, 'Daylight', 'flash off'),
      EyeNeedTile(EyeIllustration.coinScale, 'Card or coin', 'for scale'),
      EyeNeedTile(EyeIllustration.lesionContextArm, 'Helper', 'for the back'),
    ],
    bands: [
      EyeBandInfo(
        SemanticBand.normal,
        'Benign pattern',
        'The spot matches common, harmless conditions. Use the suggested matches to read about care; see a doctor if it changes or does not settle in 4 weeks.',
      ),
      EyeBandInfo(
        SemanticBand.refer,
        'Needs a look',
        'The pattern is probably benign but has features worth a routine dermatology or GP review within 4 weeks (for example a growing or scaly patch).',
      ),
      EyeBandInfo(
        SemanticBand.suspicious,
        'Suspicious — urgent',
        'The spot shows patterns seen in skin cancer (ABCDE or non-healing). Book a dermatologist within 2 weeks; most such spots still turn out benign after a proper look.',
      ),
      EyeBandInfo(
        SemanticBand.notAssessed,
        'Not assessed',
        'The spot was not clear enough (blur, shadow, hair). Not a health result — retake in daylight with the spot centred.',
      ),
    ],
    howMade: [
      (
        'Three photos of the spot',
        'Close-up, angled and context. Each passed sharpness, glare, light and spot-centred checks on the phone.',
      ),
      (
        'Scale and colour',
        'If a card or coin is beside the spot, its size is measured in millimetres and colours are corrected; otherwise the context photo gives a rough scale.',
      ),
      (
        'Lesion classifier (ALG-IMG-08)',
        'A CNN trained on dermatologist-labelled images (ISIC archive) scores the most likely conditions and a separate detector scores suspicious (cancer-like) patterns. In clinical validation (pilot vs dermatologist, suspicious-lesion sensitivity ≥ 85 %).',
      ),
      (
        'ABCDE and history',
        'Your checklist answers and history (symptoms, sun, family history, immune status) are combined with the image score.',
      ),
      (
        'Band and rules',
        'Suspicious patterns give an Urgent dermatology referral within 2 weeks (T26); other findings that need a look are Routine (T27). Near the threshold the photos go to specialist review (IMG-10).',
      ),
    ],
    analysisStages: [
      'Finding the spot and measuring its size',
      'Colour and edge pattern features',
      'Skin lesion classifier (ALG-IMG-08)',
      'Suspicious-pattern detector + ABCDE answers',
      'Risk rules & specialist routing',
    ],
    gauge: EyeGaugeSpec(
      title: 'Suspicion index',
      breakpoints: [0, 0.35, 0.65, 1.0],
      labels: ['Benign', 'Needs a look', 'Suspicious'],
      bands: [SemanticBand.normal, SemanticBand.refer, SemanticBand.suspicious],
    ),
    noNumberNote:
        'Class probabilities (SKIN_PROB) are shown under Algorithm outputs with their threshold τ; only the band drives the decision until the pilot validation passes — gate G-24. The app shows the band and up to three possible matches by name only.',
    demoOutcomeLabels: {
      'normal': 'Benign (eczema-like)',
      'borderline': 'Fungal patch (benign)',
      'high': 'Needs a look (BCC-pattern)',
      'urgent': 'Suspicious (melanoma-pattern)',
    },
    checklist: [
      'Daylight, flash off, no shadow on the spot',
      'Make-up or cream wiped off; hair trimmed if thick',
      'Card or coin ready to lay beside the spot',
    ],
    equipmentTitle: 'Scale and light',
    equipmentCaption:
        'Colour card or a coin beside the spot is preferred (size in mm); daylight with flash off is required',
    whoText:
        'All ages · any new, changing or worrying spot, mole, patch or rash',
    helperIntroText:
        'For your back, scalp or other hard-to-reach places ask a helper to take the three photos.',
    disclaimerText:
        'Screening, not diagnosis. Suggested matches are the closest-looking conditions; a Suspicious band means "dermatologist within 2 weeks", not "it is cancer".',
    bannerCopy: {
      UrgencyLevel.urgent: (
        'Suspicious skin spot — dermatologist within 2 weeks',
        'Rule T26 (BR-SCR-02): a cancer-like pattern needs a dermatology exam, dermoscopy and biopsy if indicated.',
      ),
      UrgencyLevel.routine: (
        'Skin spot needs a look — routine review',
        'Rule T27 (BR-SCR-04): routine GP or dermatology review within 4 weeks.',
      ),
    },
    gaugeExplainer: '0 = regular benign pattern, 1 = strongly cancer-like',
    nextStepsNormal: [
      'No referral needed from this screen. Photograph the spot again in 4 weeks to track change (E of ABCDE), and see a doctor if it grows, bleeds or does not settle.',
      'Use sunscreen and cover up outdoors; check your skin monthly in a mirror.',
    ],
    nextStepsNotAssessed: [
      'Retake in daylight with the spot centred in the ring, hair and make-up cleared, no shadow.',
      'If the spot is changing, bleeding or painful, see a doctor regardless of this screen.',
    ],
    nextHelper:
        'Next: tell us about the spot, then 3 photos (close-up, angled, context)',
    voicePrepare:
        'Skin check. Tell us where the spot is, how long you have had it, and tick any ABCDE signs. Then tap Start the test.',
    voiceHowTo:
        'How to take the photos. Daylight, flash off. Hold the phone ten to fifteen centimetres away with the spot centred in the ring and a card or coin beside it. Then an angled close-up, then a wider photo from arm\'s length. Tap Start photos when ready.',
    voiceAnalysing:
        'All three photos taken. Comparing the spot with the dermatologist-labelled image library.',
  );

  // ---------------------------------------------------------------------
  // 8. Oral pre-cancer & lesion — ALG-IMG-04 (6 sites, torch + flash)
  // ---------------------------------------------------------------------
  static const EyeProtocol oralLesion = EyeProtocol(
    id: 'dental_oral',
    screenType: ImageScreenType.oralLesion,
    featureId: 'F-16',
    introScreenId: 'S-E01',
    stepScreenIds: ['S-E01', 'S-E01', 'S-E03', 'S-E04'],
    title: 'Mouth lining check (oral pre-cancer · 6 photos)',
    shortTitle: 'Mouth check',
    recordTitle: 'Oral Pre-Cancer & Lesion Screen',
    homeSubtitle: '6 photos · Torch',
    algorithmId: 'ALG-IMG-04',
    algorithmName: 'Oral lesion classifier',
    algorithmSubtitle:
        'ALG-IMG-04 · DenseNet / Swin multi-view classifier + Grad-CAM heat-map · max over views',
    algorithmVersion: '0.9.0-dev',
    rangeVersion: 'OPMD ref 2026.10',
    plainMessage:
        'You take six flash photos of the inside of the mouth — both cheeks, both edges of the tongue, under the tongue and the roof of the mouth — with the torch lighting the way (the MeMoSA method used in village screening camps). '
        'A model scores each site for the white, red or mixed patches, ulcers and stiff bands of oral pre-cancer; the worst site decides the result, and anything suspicious goes to an oral-medicine specialist.',
    partnerModel: false,
    modelConfidence: 0.82,
    conditionCode: 'COND_ORAL_CA',
    flash: true,
    dimRoom: false,
    distanceLabel: '10–15 cm',
    card: ColourCardPolicy.none,
    durationLabel: '~3 min',
    category: 'Dental',
    partNoun: 'mouth lining',
    perSideTitle: 'Your mouth, site by site',
    perSideCaption:
        'Six photos · the band above is the worst site (max over views)',
    zonesInsteadOfSides: true,
    torchPreview: true,
    resultIcon: 'mouth',
    extraInputs: {EyeExtraInput.tobaccoStatus, EyeExtraInput.duration},
    durationOptions: [
      'Nothing noticed',
      'Under 2 weeks',
      '2–3 weeks',
      'Over 3 weeks',
    ],
    detailsTitle: 'About your mouth',
    detailsCaption: 'Tobacco or areca use, and anything you have noticed',
    durationPrompt: 'Noticed a patch, sore, ulcer or lump? For how long?',
    questions: [
      EyeQuestion(
        id: 'alcohol',
        label: 'Drink alcohol most weeks',
        note: 'Alcohol multiplies the cancer risk of tobacco and areca.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'burning',
        label: 'Burning or pain with spicy food',
        note:
            'Burning with spicy food is an early sign of oral submucous fibrosis (OSMF) from areca nut.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'trismus',
        label: 'Cannot open the mouth as wide as before',
        note:
            'Reduced mouth opening suggests OSMF — a pre-cancer condition that needs an oral-medicine review.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'numb_loose',
        label: 'Numbness, loose teeth or a denture that no longer fits',
        note:
            'Numbness or loosening teeth can mean a lesion is growing into deeper tissue.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'weight_voice',
        label: 'Unexplained weight loss, voice change or a neck lump',
        note: 'General symptoms with a mouth lesion need urgent assessment.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'prior_lesion',
        label: 'Previous mouth lesion, biopsy or treatment',
        note:
            'Scars and healed sites change how the lining looks — tell the reviewer what was treated.',
        affectsReliability: true,
      ),
      EyeQuestion(
        id: 'recent_paan',
        label: 'Ate, smoked or chewed paan / gutka in the last 30 minutes',
        note:
            'Fresh staining and debris hide the lining; rinse and wait 30 minutes for a clearer result.',
        affectsReliability: true,
      ),
      EyeQuestion(id: 'none', label: 'None of these'),
    ],
    beforeYouStart: [
      'Check the name and age on the first screen — tap Change there if they are wrong.',
      'Rinse the mouth with water and remove dentures. No paan, gutka, tobacco or food for 30 minutes; wipe off lipstick.',
      'Sit facing a window in daylight. The torch stays on while you frame and the flash fires on each photo.',
      'Ask a helper if you can: one person pulls the cheek or holds the tongue tip with gauze, the other holds the phone 10–15 cm from the mouth.',
      'Six photos in a fixed order: left cheek, right cheek, left tongue edge, right tongue edge, floor of the mouth, roof of the mouth.',
      'If the app asks, retake — up to 3 attempts per photo. Photos that still fail are marked "Not assessed".',
    ],
    beforeIllustrations: [
      EyeIllustration.dentureOut,
      EyeIllustration.torchMouthDistance,
      EyeIllustration.cheekRetract,
    ],
    howTo: [
      EyeHowToStep(
        EyeIllustration.mouthOpenWide,
        'Open wide, torch on',
        'Sit facing daylight and open as wide as you can. The torch lights the inside; keep the phone 10–15 cm from the lips with the lens pointed into the mouth.',
      ),
      EyeHowToStep(
        EyeIllustration.cheekRetract,
        'Cheek lining — pull the cheek out',
        'Hook a clean finger or a spoon handle inside the corner of the mouth and pull the cheek outwards so the whole inner lining shows, from the lip corner to the back teeth. Left cheek first, then right.',
      ),
      EyeHowToStep(
        EyeIllustration.tongueToSide,
        'Tongue edges',
        'Stick the tongue out and push it hard to the right so the left edge shows; hold the tip with a piece of gauze. Then push it left for the right edge. Most mouth cancers start on these edges.',
      ),
      EyeHowToStep(
        EyeIllustration.tongueUpFloor,
        'Floor of the mouth',
        'Touch the tip of the tongue to the roof of the mouth. Photograph the soft floor under the tongue and the inner gum of the lower front teeth.',
      ),
      EyeHowToStep(
        EyeIllustration.headBackPalate,
        'Roof of the mouth',
        'Tip the head back, open wide and say "aah". Photograph the hard palate and the soft palate behind it.',
      ),
    ],
    examples: [
      EyeExample(
        EyeIllustration.oralGoodExample,
        'Good: lining fills the frame, evenly lit',
        good: true,
      ),
      EyeExample(
        EyeIllustration.oralPatchExample,
        'White or red patch: photograph it fully, do not scrub it',
      ),
      EyeExample(
        EyeIllustration.blurryExample,
        'Blurry or dark: hold still, torch on, retake',
      ),
    ],
    views: [
      EyeView(
        id: 'M1',
        eye: null,
        index: 1,
        ofPerEye: 6,
        label: 'Left cheek lining',
        coaching:
            'Pull the left cheek out with a finger so the inner lining fills the guide, 10–15 cm away. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.cheekRetract,
        target: PhotoTarget.oralMucosa,
        zoneLabel: 'Left cheek',
        zoneCode: 'M1',
      ),
      EyeView(
        id: 'M2',
        eye: null,
        index: 2,
        ofPerEye: 6,
        label: 'Right cheek lining',
        coaching:
            'Now the right cheek: pull it out so the whole lining shows from lip corner to back teeth. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.cheekRetract,
        target: PhotoTarget.oralMucosa,
        zoneLabel: 'Right cheek',
        zoneCode: 'M2',
      ),
      EyeView(
        id: 'M3',
        eye: null,
        index: 3,
        ofPerEye: 6,
        label: 'Tongue · left edge',
        coaching:
            'Stick the tongue out and push it to the right; hold the tip with gauze so the left edge shows. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.tongueToSide,
        target: PhotoTarget.oralMucosa,
        zoneLabel: 'Tongue · left edge',
        zoneCode: 'M3',
      ),
      EyeView(
        id: 'M4',
        eye: null,
        index: 4,
        ofPerEye: 6,
        label: 'Tongue · right edge',
        coaching:
            'Push the tongue to the left so the right edge shows. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.tongueToSide,
        target: PhotoTarget.oralMucosa,
        zoneLabel: 'Tongue · right edge',
        zoneCode: 'M4',
      ),
      EyeView(
        id: 'M5',
        eye: null,
        index: 5,
        ofPerEye: 6,
        label: 'Floor of the mouth',
        coaching:
            'Touch the tongue tip to the roof of the mouth and show the soft floor under the tongue. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.tongueUpFloor,
        target: PhotoTarget.oralMucosa,
        zoneLabel: 'Floor of mouth',
        zoneCode: 'M5',
      ),
      EyeView(
        id: 'M6',
        eye: null,
        index: 6,
        ofPerEye: 6,
        label: 'Roof of the mouth',
        coaching:
            'Tip the head back, open wide and say "aah" — show the hard and soft palate. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.headBackPalate,
        target: PhotoTarget.oralMucosa,
        zoneLabel: 'Palate',
        zoneCode: 'M6',
      ),
    ],
    readsTitle: 'Colour and texture of the mouth lining',
    readsCaption:
        'Healthy lining is an even pink; pre-cancer shows white, red or mixed patches, ulcers or stiff bands',
    scale: EyeScale(
      labels: ['Not suspicious', 'Suspicious', 'High risk'],
      bands: [SemanticBand.normal, SemanticBand.suspicious, SemanticBand.high],
      gradient: [0xFFF4B8C1, 0xFFF1E4E6, 0xFFE0828A, 0xFFB91C1C],
    ),
    referenceTitle: 'Patterns the classifier looks for (OPMD)',
    referenceRows: [
      ('Even pink lining', 'Not suspicious'),
      ('White patch that cannot be wiped off', 'Leukoplakia · suspicious'),
      ('Red velvety patch', 'Erythroplakia · high risk'),
      ('Mixed red-white patch', 'Erythroleukoplakia · high risk'),
      ('Ulcer not healed in 3 weeks', 'Non-healing ulcer · high risk'),
      (
        'Stiff bands, cannot open wide',
        'Submucous fibrosis (OSMF) · suspicious',
      ),
    ],
    referenceNote:
        'Any patch, ulcer or lump that lasts more than 3 weeks should be seen by a dentist or oral-medicine specialist even when the app says not suspicious. Tobacco, areca (supari, gutka, paan) and alcohol are the main causes.',
    inputsText:
        '6 flash photos of the mouth lining: both cheeks, both tongue edges, floor of the mouth and palate · tobacco / areca status, what you have noticed and symptoms',
    outputsText:
        'Class per site and overall (Not suspicious / Suspicious / High risk — urgent), the site that carries the worst class with a lesion marker, red flags from your answers, and next steps. Class probabilities are listed under Algorithm outputs.',
    checkedByText:
        'On-device photo quality checks (sharpness, glare, light, lining in frame) on every photo · an oral-medicine specialist reviewer for Suspicious, High-risk or borderline results (IMG-10)',
    miniSteps: [
      ('6 photos', 'torch + flash'),
      ('Per site', 'classifier'),
      ('Worst site', 'max over views'),
      ('Band', '+ specialist'),
    ],
    needs: [
      EyeNeedTile(
        EyeIllustration.torchMouthDistance,
        'Torch & flash',
        'automatic',
      ),
      EyeNeedTile(EyeIllustration.cheekRetract, 'Helper', 'pulls the cheek'),
      EyeNeedTile(EyeIllustration.dentureOut, 'Clean mouth', 'rinse first'),
    ],
    bands: [
      EyeBandInfo(
        SemanticBand.normal,
        'Not suspicious',
        'No pattern of pre-cancer in any site. Tobacco or areca users should repeat the check every 6 months and see a dentist yearly.',
      ),
      EyeBandInfo(
        SemanticBand.refer,
        'Needs a look',
        'The photos look not suspicious but you reported a patch, sore or lump lasting over 3 weeks — a routine dentist or oral-medicine check within 4 weeks.',
      ),
      EyeBandInfo(
        SemanticBand.suspicious,
        'Suspicious — urgent',
        'A white patch, stiff band or similar pre-cancer pattern (OPMD) was seen. Oral-medicine exam within 2 weeks; the specialist decides on biopsy. Most such patches are not cancer yet.',
      ),
      EyeBandInfo(
        SemanticBand.high,
        'High risk — urgent',
        'A red or mixed patch, non-healing ulcer or lump with the pattern of oral cancer. Oral-medicine biopsy pathway within 1 week.',
      ),
      EyeBandInfo(
        SemanticBand.notAssessed,
        'Not assessed',
        'The lining was not clear enough (blur, dark, lips in the way). Not a health result — retake with a helper and the torch on.',
      ),
    ],
    howMade: [
      (
        'Six photos of the lining',
        'Both cheeks, both tongue edges, floor of the mouth and palate with the torch on and the flash firing. Each passed sharpness, glare, light and lining-in-frame checks on the phone.',
      ),
      (
        'Per-site classifier (ALG-IMG-04)',
        'A DenseNet / Swin network trained on smartphone photos of oral potentially malignant disorders scores each site as not suspicious, suspicious or high risk and marks the region it looked at (Grad-CAM). In clinical validation (IMG-OR-01: 300 people vs oral-medicine exam and biopsy; sensitivity ≥ 85 %, ≥ 80 % for untrained photographers).',
      ),
      (
        'Worst site wins',
        'The six site results are combined by taking the maximum — one suspicious site makes the whole screen suspicious (Spec: max over views).',
      ),
      (
        'Your answers',
        'Tobacco / areca status, how long a patch has been there and symptoms such as burning or reduced opening are added as red flags; a patch over 3 weeks always earns a look.',
      ),
      (
        'Rules and review',
        'Suspicious or high risk gives an Urgent oral-medicine referral (T28, BR-SCR-02). Near the threshold, or whenever suspicious, the photos go to a specialist reviewer (IMG-10).',
      ),
    ],
    analysisStages: [
      'Finding the lining in each photo',
      'Colour and texture features per site',
      'Oral lesion classifier (ALG-IMG-04)',
      'Combining the six sites (max over views)',
      'Risk rules & specialist routing',
    ],
    gauge: EyeGaugeSpec(
      title: 'Suspicion index',
      breakpoints: [0, 0.5, 0.75, 1.0],
      labels: ['Not suspicious', 'Suspicious', 'High risk'],
      bands: [SemanticBand.normal, SemanticBand.suspicious, SemanticBand.high],
    ),
    noNumberNote:
        'Class probabilities (ORAL_PROB_SUSP, ORAL_PROB_HIGH) are shown under Algorithm outputs with their threshold τ; only the class drives the decision until the validation study passes — gate G-24. The app shows the class per site and overall.',
    demoOutcomeLabels: {
      'normal': 'Not suspicious',
      'borderline': 'Near threshold (specialist review)',
      'high': 'Suspicious (white patch, left cheek)',
      'urgent': 'High risk (red-white patch + ulcer)',
    },
    checklist: [
      'Rinsed, dentures out, no paan or gutka for 30 min',
      'Facing daylight, torch on',
      'Helper ready with clean hands or gauze',
    ],
    equipmentTitle: 'Light and a helper',
    equipmentCaption:
        'The torch and flash light the mouth automatically; a helper to pull the cheek and hold the tongue makes the photos much clearer',
    whoText:
        'All ages · always offered to tobacco, gutka, paan, khaini or areca (supari) users and to anyone with a mouth patch, sore or lump',
    helperIntroText:
        'A helper should hold the phone while you pull your cheek or hold your tongue; for children or elders the helper does both.',
    disclaimerText:
        'Screening, not diagnosis. "Suspicious" means an oral-medicine specialist should look within 2 weeks; only a biopsy can say whether a patch is pre-cancer or cancer.',
    bannerCopy: {
      UrgencyLevel.urgent: (
        'Suspicious mouth lesion — oral-medicine clinic within 2 weeks',
        'Rule T28 (BR-SCR-02): a pre-cancer or cancer-like pattern needs an oral-medicine exam and a biopsy if indicated.',
      ),
      UrgencyLevel.routine: (
        'Mouth patch or sore reported — routine check',
        'Rule T29 (BR-SCR-04): a patch, sore or lump lasting over 3 weeks needs a dentist or oral-medicine look within 4 weeks.',
      ),
    },
    gaugeExplainer: '0 = even pink lining, 1 = strongly cancer-like pattern',
    nextStepsNormal: [
      'No referral needed from this screen. Check your mouth in a mirror once a month: cheeks, tongue edges, under the tongue and the roof.',
      'If you use tobacco, gutka, paan or areca, quitting is the single biggest protection — the national tobacco quitline is 1800-11-2356.',
      'Repeat this check every 6 months if you use tobacco or areca, otherwise yearly.',
    ],
    nextStepsNotAssessed: [
      'Retake with a helper: torch on, mouth wide open, cheek pulled out so the lining fills the guide.',
      'If you have a patch, sore or lump for more than 3 weeks, see a dentist regardless of this screen.',
    ],
    nextHelper:
        'Next: tobacco & symptoms, then 6 photos (cheeks, tongue edges, floor, palate)',
    voicePrepare:
        'Mouth check. Tell us about tobacco or areca use and anything you have noticed in your mouth, then answer the symptom questions and tap Start the test.',
    voiceHowTo:
        'How to take the photos. Rinse your mouth and remove dentures. Face a window. The torch lights the inside and the flash fires on each photo. Pull each cheek out with a finger, then push your tongue to each side, then lift the tongue, then tip your head back for the roof of the mouth. Tap Start photos when ready.',
    voiceAnalysing:
        'All six photos taken. Checking each site for pre-cancer patterns.',
  );

  // ---------------------------------------------------------------------
  // 9. 4-view dental & caries — ALG-DEN-01..07 (F-18, torch + flash)
  // ---------------------------------------------------------------------
  static const EyeProtocol dentalCaries = EyeProtocol(
    id: 'dental_caries',
    screenType: null,
    featureId: 'F-18',
    introScreenId: 'S-F01',
    stepScreenIds: ['S-F02', 'S-F01', 'S-F03', 'S-F03'],
    title: 'Dental check (4 teeth photos)',
    shortTitle: 'Dental check',
    recordTitle: '4-View Dental & Caries Screening',
    homeSubtitle: '4 photos · FDI chart',
    algorithmId: 'ALG-DEN-01..07',
    algorithmName: 'Dental 4-view pipeline',
    algorithmSubtitle:
        'ALG-DEN-01..07 · view classifier · tooth detector + FDI · per-tooth caries classifier · gum & plaque · sealant · caries-risk rule · change over time',
    algorithmVersion: '0.9.0-dev',
    rangeVersion: 'ICDAS / BR-DEN 2026.10',
    plainMessage:
        'You take four flash photos of the teeth — front teeth closed, front teeth open, the biting surfaces of the upper teeth and of the lower teeth — with the torch lighting the mouth (the method used by phone dental-check apps and tele-dentistry studies). '
        'The app finds every tooth, numbers it on an FDI chart, flags white spots, cavities, broken teeth and abscess signs, scores gum redness and plaque, and combines the findings with your habits into a caries-risk level.',
    partnerModel: false,
    modelConfidence: 0.84,
    conditionCode: 'COND_CARIES',
    extraConditionCodes: ['COND_GUM_DISEASE'],
    flash: true,
    dimRoom: false,
    distanceLabel: '10–15 cm',
    card: ColourCardPolicy.none,
    durationLabel: '~3 min',
    category: 'Dental',
    partNoun: 'teeth',
    perSideTitle: 'Your teeth, view by view',
    perSideCaption:
        'Front closed, front open, upper and lower biting surfaces · the band above is the caries-risk level',
    zonesInsteadOfSides: true,
    torchPreview: true,
    consentType: ConsentType.dentalGuardian,
    guardianUnderAge: 12,
    recheckLabel: 'Every 6 months',
    resultIcon: 'tooth',
    extraInputs: {EyeExtraInput.dentalHabits},
    questions: [
      EyeQuestion(
        id: 'toothache',
        label: 'Toothache or sensitivity to hot, cold or sweet',
        note:
            'Pain or sensitivity usually means a cavity has reached the dentine — a dentist should check even if the photos look clear.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'swelling',
        label: 'Swelling, pus, a gum boil or a bad taste',
        note:
            'Swelling or pus is an abscess sign — urgent dental care within days, same day with fever.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'bleeding_gums',
        label: 'Gums bleed when brushing',
        note:
            'Bleeding gums are the first sign of gum inflammation (gingivitis); better brushing usually settles it within 2 weeks.',
        escalates: true,
      ),
      EyeQuestion(
        id: 'dry_mouth',
        label: 'Dry mouth, or medicines that dry the mouth',
        note:
            'Less saliva lets decay progress faster — one of the strongest caries-risk factors (CAMBRA).',
        escalates: true,
      ),
      EyeQuestion(
        id: 'braces_dentures',
        label: 'Braces, a retainer or a denture',
        note:
            'Brackets and plates hide tooth surfaces and trap plaque — some teeth may be marked "not seen".',
        affectsReliability: true,
      ),
      EyeQuestion(
        id: 'tobacco',
        label: 'Smoke or chew tobacco / gutka / paan',
        note:
            'Tobacco stains teeth (can look like decay) and causes gum disease; it also calls for the Mouth check.',
        affectsReliability: true,
        escalates: true,
      ),
      EyeQuestion(id: 'none', label: 'None of these'),
    ],
    beforeYouStart: [
      'Check the name and age on the first screen — for a child the parent or guardian ticks the dental consent (G-05) and holds the phone.',
      'Brush or rinse, then dry the teeth with a tissue — wet teeth throw flash glare. Remove a removable denture or retainer.',
      'Sit facing a window. The torch stays on while you frame and the flash fires on each photo, 10–15 cm from the mouth.',
      'Pull the lips back with clean fingers (or a spoon handle) so every tooth shows from one side to the other.',
      'Four photos in order: front teeth biting together, front teeth open, upper biting surfaces (head back), lower biting surfaces (tongue up).',
      'If a view keeps failing you can skip it after 3 attempts — the exam is marked partial and the teeth not seen are listed (E-DEN-001).',
    ],
    beforeIllustrations: [
      EyeIllustration.wipeTeeth,
      EyeIllustration.torchMouthDistance,
      EyeIllustration.frontBite,
    ],
    howTo: [
      EyeHowToStep(
        EyeIllustration.frontBite,
        '1 of 4 · Front teeth, closed',
        'Bite the back teeth together, pull both lips back with clean fingers and show all the front teeth and the gum line. Phone level with the mouth, 10–15 cm away.',
      ),
      EyeHowToStep(
        EyeIllustration.frontOpen,
        '2 of 4 · Front teeth, mouth open',
        'Open about two fingers wide with the tongue resting down. This shows the biting edges, the inner front surfaces and the gums of both jaws.',
      ),
      EyeHowToStep(
        EyeIllustration.upperArch,
        '3 of 4 · Upper biting surface',
        'Tip the head back and open wide. Point the phone up into the mouth so the whole upper arch shows from the back molars on one side to the other — these grooves are where decay starts.',
      ),
      EyeHowToStep(
        EyeIllustration.lowerArch,
        '4 of 4 · Lower biting surface',
        'Chin down, open wide and lift the tongue up and back (or hold it with gauze). Point the phone down so the whole lower arch shows.',
      ),
    ],
    helperTip: (
      'Helper tip — not a photo',
      'A helper can hold the phone while you pull the lips back. For a child, the guardian sits with the child\'s head in their lap, one hand gently holding the lips back and the other holding the phone. Make it a game: "show me your tiger teeth". Only the 4 photos above are taken.',
    ),
    examples: [
      EyeExample(
        EyeIllustration.dentalGoodExample,
        'Good: whole row, dry teeth, gum line visible',
        good: true,
      ),
      EyeExample(
        EyeIllustration.dentalTongueExample,
        'Tongue or lip covering the teeth: lift and retake',
      ),
      EyeExample(
        EyeIllustration.dentalBlurryExample,
        'Blurry or glare: dry the teeth, hold still, retake',
      ),
    ],
    views: [
      EyeView(
        id: 'D1',
        eye: null,
        index: 1,
        ofPerEye: 4,
        label: 'Front teeth, closed',
        chipLabel: '1 Front\nclosed',
        coaching:
            'Bite together, pull both lips back and show all the front teeth with the gum line, 10–15 cm away. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.frontBite,
        target: PhotoTarget.teethArch,
        zoneLabel: 'Front · closed',
        zoneCode: 'D1',
      ),
      EyeView(
        id: 'D2',
        eye: null,
        index: 2,
        ofPerEye: 4,
        label: 'Front teeth, mouth open',
        chipLabel: '2 Front\nopen',
        coaching:
            'Open two fingers wide, tongue down, lips pulled back — show the biting edges of both jaws. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.frontOpen,
        target: PhotoTarget.teethArch,
        zoneLabel: 'Front · open',
        zoneCode: 'D2',
      ),
      EyeView(
        id: 'D3',
        eye: null,
        index: 3,
        ofPerEye: 4,
        label: 'Upper biting surface',
        chipLabel: '3 Upper\nbiting',
        coaching:
            'Head back, open wide, phone pointing up — the whole upper arch from molar to molar in the U-shaped guide. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.upperArch,
        target: PhotoTarget.teethArch,
        zoneLabel: 'Upper teeth',
        zoneCode: 'D3',
      ),
      EyeView(
        id: 'D4',
        eye: null,
        index: 4,
        ofPerEye: 4,
        label: 'Lower biting surface',
        chipLabel: '4 Lower\nbiting',
        coaching:
            'Chin down, tongue lifted back, phone pointing down — the whole lower arch in the guide. Tap the shutter.',
        gaze: EyeGaze.straight,
        illustration: EyeIllustration.lowerArch,
        target: PhotoTarget.teethArch,
        zoneLabel: 'Lower teeth',
        zoneCode: 'D4',
      ),
    ],
    readsTitle: 'Tooth surfaces, gums and your habits',
    readsCaption:
        'Decay shows as chalky white spots first, then brown cavities; red puffy gums and plaque raise the risk',
    scale: EyeScale(
      labels: ['Low risk', 'Moderate', 'High risk'],
      bands: [SemanticBand.low, SemanticBand.moderate, SemanticBand.high],
      gradient: [0xFFF8FAFC, 0xFFF5E6C8, 0xFFC98A5B, 0xFF5B3A1E],
    ),
    referenceTitle: 'Tooth findings (ICDAS) and the caries-risk rule (BR-DEN)',
    referenceRows: [
      ('White spot', 'ICDAS 1–2 · early, reversible with fluoride'),
      ('Enamel break', 'ICDAS 3 · dentist filling or sealant'),
      ('Cavity', 'ICDAS 4–6 · dentist within 4 weeks (T14)'),
      ('Broken / black tooth', 'Dentist exam, X-ray as needed'),
      ('Abscess sign', 'Swelling or gum boil · urgent within 3 days (T13)'),
      ('Low risk', 'No lesions, sweets ≤ 2 / day, brushing twice'),
      ('Moderate risk', '1 white spot, or sugar / brushing / fluoride gaps'),
      (
        'High risk',
        'Any cavity, ≥ 2 white spots, or white spot + night feeding',
      ),
    ],
    referenceNote:
        'Teeth are numbered the dentist\'s way (FDI): adults 11–48, children 51–85; the first number is the quadrant, the second the tooth from the midline. The caries-risk rule follows the Spec\'s six BR-DEN test cases.',
    inputsText:
        '4 flash photos: front closed, front open, upper and lower biting surfaces · brushing, fluoride paste, sweets per day, night feeding (under 6), last dental visit · symptoms',
    outputsText:
        'Every tooth on an FDI chart with any finding (white spot, enamel break, cavity, broken / black, abscess sign), gum-inflammation and plaque bands, sealant candidates (ages 6–9), caries-risk level (Low / Moderate / High), what changed since the last exam, and teeth not seen in a partial exam.',
    checkedByText:
        'On-device photo quality checks (sharpness, glare, light, teeth in frame) and the view classifier on every photo · the caries-risk rule is deterministic (ALG-DEN-06) · the tooth-finding models are in validation (DEN-01 study)',
    miniSteps: [
      ('4 photos', 'torch + flash'),
      ('Teeth', 'FDI numbers'),
      ('Findings', 'per tooth'),
      ('Risk', 'BR-DEN rule'),
    ],
    needs: [
      EyeNeedTile(
        EyeIllustration.torchMouthDistance,
        'Torch & flash',
        'automatic',
      ),
      EyeNeedTile(EyeIllustration.wipeTeeth, 'Dry teeth', 'tissue'),
      EyeNeedTile(EyeIllustration.helperChildMouth, 'Guardian', 'for a child'),
    ],
    bands: [
      EyeBandInfo(
        SemanticBand.low,
        'Low caries risk',
        'No decay seen and protective habits. Keep brushing twice a day with fluoride toothpaste; dental check-up yearly.',
      ),
      EyeBandInfo(
        SemanticBand.moderate,
        'Moderate caries risk',
        'An early white spot, or sugar, brushing or fluoride gaps. Reversible: brush twice with fluoride paste, cut sweets to twice a day, dentist within 3 months.',
      ),
      EyeBandInfo(
        SemanticBand.high,
        'High caries risk',
        'A cavity, several white spots, or a white spot with night feeding. Dentist within 4 weeks for fillings or fluoride varnish; urgent within 3 days if an abscess sign was seen.',
      ),
      EyeBandInfo(
        SemanticBand.notAssessed,
        'Not assessed',
        'No view showed the teeth clearly after 3 attempts. Not a health result — retake with dry teeth, lips pulled back and the torch on.',
      ),
    ],
    howMade: [
      (
        'Four views, checked (ALG-DEN-01)',
        'Each photo passed sharpness, glare, light and teeth-in-frame checks, and a view classifier confirms it shows the view asked for (front closed, front open, upper, lower). A missing view makes the exam partial, never discarded.',
      ),
      (
        'Every tooth found and numbered (ALG-DEN-02)',
        'A detector draws a box around each tooth and an arch-ordering step assigns the FDI number; primary teeth 51–85 under 6, mixed 6–12, permanent 11–48. Teeth hidden by lips, tongue or a missing view are "not seen".',
      ),
      (
        'Per-tooth findings (ALG-DEN-03)',
        'A classifier scores each tooth crop for white spot (ICDAS 1–2), enamel break (3), cavity (4–6), broken / black tooth and abscess sign; the same tooth in two views keeps the worse finding. In clinical validation (DEN-01: 200 children + 100 adults vs dentist ICDAS exam; cavity sensitivity ≥ 85 %).',
      ),
      (
        'Gums, plaque and sealants (ALG-DEN-04/05)',
        'The two front views are segmented for red, swollen gum margins (Löe & Silness index) and plaque; the biting-surface views mark deep grooves on the first permanent molars 16 / 26 / 36 / 46 as sealant candidates for ages 6–9.',
      ),
      (
        'Caries-risk rule and change (ALG-DEN-06/07)',
        'Findings plus brushing, fluoride, sweets and night feeding give Low / Moderate / High by the BR-DEN rule (six Spec test cases). Each tooth is matched to the previous exam by FDI number to report new, progressed, unchanged or resolved. Abscess sign is Urgent (T13); a cavity is Routine (T14).',
      ),
    ],
    analysisStages: [
      'Checking each view (ALG-DEN-01)',
      'Finding and numbering the teeth (ALG-DEN-02)',
      'Scoring each tooth for decay (ALG-DEN-03)',
      'Gums, plaque and sealant need (ALG-DEN-04/05)',
      'Caries-risk rule and change since last exam (ALG-DEN-06/07)',
    ],
    gauge: EyeGaugeSpec(
      title: 'Findings in this view',
      breakpoints: [0, 0.34, 0.67, 1.0],
      labels: ['Sound', 'Early', 'Decay'],
      bands: [SemanticBand.normal, SemanticBand.moderate, SemanticBand.high],
    ),
    noNumberNote:
        'Per-tooth probabilities (finding_prob) are shown under Algorithm outputs with their threshold τ; only the finding and the caries-risk level drive the decision until the DEN-01 validation passes — gate G-24. The app shows each tooth\'s finding and the caries-risk level only.',
    demoOutcomeLabels: {
      'normal': 'Healthy (low risk)',
      'borderline': 'One white spot (moderate)',
      'high': 'Cavity + white spots (high, routine)',
      'urgent': 'Abscess sign (urgent T13)',
    },
    checklist: [
      'Teeth brushed or rinsed and dried with a tissue',
      'Facing daylight, torch on',
      'Lips pulled back with clean fingers; guardian ready for a child',
    ],
    equipmentTitle: 'Light and dry teeth',
    equipmentCaption:
        'The torch and flash light the mouth automatically; dry teeth and lips pulled back are what make the photos readable',
    whoText:
        'All ages · child mode (primary and mixed teeth) for ages 1–12 with a parent or guardian · adults self-screen',
    helperIntroText:
        'For a child the parent or guardian holds the lips back and the phone (knee-to-knee). Adults can do it alone with a mirror, but a helper is easier.',
    disclaimerText:
        'Screening, not diagnosis. Findings mark teeth a dentist should look at with a probe and X-ray; the caries-risk level guides prevention, not treatment.',
    bannerCopy: {
      UrgencyLevel.urgent: (
        'Abscess sign — dentist within 3 days',
        'Rule T13 (BR-SCR-02): swelling, pus or a gum boil means infection — urgent dental care, same day with fever or facial swelling.',
      ),
      UrgencyLevel.routine: (
        'Cavity seen — dentist within 4 weeks',
        'Rule T14 (BR-SCR-04): a cavitated tooth needs a dentist exam (ICDAS) with a bitewing X-ray as needed and a filling.',
      ),
    },
    gaugeExplainer:
        '0 = all teeth in this view sound, 1 = a cavity or worse in this view',
    nextStepsNormal: [
      'No referral needed from this screen. Brush twice a day for two minutes with fluoride toothpaste, spit but do not rinse, and keep sweets and sugary drinks to mealtimes.',
      'Repeat the photos every 6 months — the app compares each tooth with this baseline (ALG-DEN-07). Routine dental check-up once a year.',
    ],
    nextStepsNotAssessed: [
      'Retake with dry teeth, lips pulled right back and the torch on; for a child use the knee-to-knee position.',
      'If there is pain, swelling or a visible hole, see a dentist regardless of this screen.',
    ],
    nextHelper:
        'Next: brushing & sugar questions, then 4 photos (front closed, front open, upper, lower)',
    voicePrepare:
        'Dental check. Answer the brushing, fluoride and sweets questions, then tap Start the test. For a child the parent or guardian answers.',
    voiceHowTo:
        'How to take the photos. Dry the teeth with a tissue and face a window. The torch lights the mouth and the flash fires on each photo. First bite together and pull the lips back, then open wide, then head back for the upper teeth, then chin down with the tongue up for the lower teeth. Tap Start photos when ready.',
    voiceAnalysing:
        'All four photos taken. Finding and numbering the teeth and checking each one for decay.',
  );
}
