// Vision-test protocols (Doc 09 §9 ALG-MOV-10..12 + ALG-CAP-15, Doc 05
// S-H07..S-H10). Data only — the intro, capture and result screens read all
// copy, pictures, gates and reference rows from these records, exactly like
// the movement protocols. Member-facing copy is plain language; codes live
// in [measures], [referenceRows] and [markerMeanings].
import 'enums.dart';

enum VisionTestKind { acuity, colour, amsler, reaction }

enum VisionEye {
  right('Right'),
  left('Left');

  const VisionEye(this.label);
  final String label;
  String get suffix => this == VisionEye.left ? 'L' : 'R';
  VisionEye get other =>
      this == VisionEye.left ? VisionEye.right : VisionEye.left;

  /// The eye the member covers while this eye is tested.
  String get coveredLabel => other.label.toLowerCase();
}

/// Reaction-time block (ALG-MOV-12).
enum ReactionBlock {
  visual('Visual'),
  audio('Sound');

  const ReactionBlock(this.label);
  final String label;
}

/// Static stand-in outcomes for Test Controls / FLUTTER_TEST.
enum VisionDemoOutcome { normal, borderline, refer }

/// Every drawing the vision screens can show (see
/// `lib/features/vision/vision_illustrations.dart`).
enum VisionIllustration {
  coverEye,
  phoneAt40cm,
  tumblingE,
  swipeArrows,
  glassesOn,
  colourPlate,
  brightnessMax,
  noFilter,
  amslerGrid,
  phoneAt30cm,
  markWavy,
  tapFlash,
  speaker,
  waitThenTap,
  tapeMeasure,
  eyeLeft,
  eyeRight,
  readingGlasses,
}

class VisionStep {
  const VisionStep(this.illustration, this.caption);
  final VisionIllustration illustration;
  final String caption;
}

class VisionHowToStep {
  const VisionHowToStep(this.illustration, this.title, this.body);
  final VisionIllustration illustration;
  final String title;
  final String body;
}

class VisionNeedTile {
  const VisionNeedTile(this.illustration, this.title, this.sub);
  final VisionIllustration illustration;
  final String title;
  final String sub;
}

class VisionPrepareItem {
  const VisionPrepareItem(this.illustration, this.text);
  final VisionIllustration illustration;
  final String text;
}

/// A row on the reference card. 'DOC' = in the algorithm document, 'DER' =
/// research / derived reference.
class VisionReferenceRow {
  const VisionReferenceRow(this.label, this.value, {this.provenance = 'DOC'});
  final String label;
  final String value;
  final String provenance;
}

class VisionProtocol {
  const VisionProtocol({
    required this.id,
    required this.kind,
    required this.screenId,
    required this.catalogueId,
    required this.title,
    required this.shortTitle,
    required this.recordTitle,
    required this.algorithmId,
    required this.conditionCode,
    required this.perEye,
    required this.requiredGates,
    required this.purpose,
    required this.whatYouDo,
    required this.measures,
    required this.markerMeanings,
    required this.needs,
    required this.prepareChecklist,
    required this.howTo,
    required this.voiceStart,
    required this.voiceSwitch,
    required this.voiceDone,
    required this.analysisStages,
    required this.referenceTitle,
    required this.referenceRows,
    required this.referenceNote,
    required this.resultTitle,
    required this.durationLabel,
    this.extraAlgorithmIds = const [],
    this.featureId = 'F-28',
    this.algorithmVersion = 'v0.9.0',
    this.rangeVersion = 'mst_ref_2026.10',
    this.setupHint = '',
    this.usesCamera = false,
    this.usesSound = false,
    this.needsMaxBrightness = false,
  });

  final String id;
  final VisionTestKind kind;
  final String screenId;
  final String catalogueId;
  final String title;
  final String shortTitle;
  final String recordTitle;
  final String algorithmId;

  /// Other cards shown on the result (e.g. ALG-CAP-15 for acuity).
  final List<String> extraAlgorithmIds;
  final String conditionCode;
  final String featureId;
  final String algorithmVersion;
  final String rangeVersion;

  /// Right eye then left eye (acuity, Amsler).
  final bool perEye;
  final List<GateId> requiredGates;
  final String purpose;
  final List<VisionStep> whatYouDo;
  final List<String> measures;
  final Map<String, String> markerMeanings;
  final List<VisionNeedTile> needs;
  final List<VisionPrepareItem> prepareChecklist;
  final String setupHint;
  final List<VisionHowToStep> howTo;
  final String voiceStart;
  final String voiceSwitch;
  final String voiceDone;
  final List<String> analysisStages;
  final String referenceTitle;
  final List<VisionReferenceRow> referenceRows;
  final String referenceNote;
  final String resultTitle;
  final String durationLabel;
  final bool usesCamera;
  final bool usesSound;
  final bool needsMaxBrightness;

  String get plainSensorLine => switch (kind) {
    VisionTestKind.acuity => 'Uses the front camera to check your distance',
    VisionTestKind.colour => 'Uses the screen at full brightness',
    VisionTestKind.amsler => 'Uses the touch screen',
    VisionTestKind.reaction => 'Uses the touch screen and the speaker',
  };

  String get sensorSummary => switch (kind) {
    VisionTestKind.acuity =>
      'Front camera distance 40 ± 5 cm (CAP-15) · screen DPI · 4-way swipe',
    VisionTestKind.colour => 'Screen brightness 100 % · 12 plates',
    VisionTestKind.amsler => 'Touch screen · 10 × 10 cm grid at 30 cm',
    VisionTestKind.reaction => 'Touch latency ms · 10 visual + 10 sound',
  };

  /// Headline for the live Test screen.
  String get runHeadline => switch (kind) {
    VisionTestKind.acuity => 'Which way does the E point?',
    VisionTestKind.colour => 'What number do you see?',
    VisionTestKind.amsler => 'Look only at the dot',
    VisionTestKind.reaction => 'Tap as soon as you see or hear it',
  };
}

class VisionProtocols {
  VisionProtocols._();

  static const List<VisionProtocol> all = [acuity, colour, amsler, reaction];

  static VisionProtocol? forScreenId(String screenId) {
    for (final p in all) {
      if (p.screenId == screenId) return p;
    }
    return null;
  }

  static VisionProtocol? forId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ── 1. Visual acuity — tumbling E (ALG-MOV-10, S-H07) ───────────────────
  static const VisionProtocol acuity = VisionProtocol(
    id: 'vis_acuity',
    kind: VisionTestKind.acuity,
    screenId: 'S-H07',
    catalogueId: 'cat_vis_acuity',
    title: 'Visual acuity',
    shortTitle: 'Visual acuity',
    recordTitle: 'Visual Acuity (Tumbling-E logMAR)',
    algorithmId: 'ALG-MOV-10',
    extraAlgorithmIds: ['ALG-CAP-15'],
    conditionCode: 'COND_CATARACT',
    perEye: true,
    requiredGates: [GateId.g04, GateId.g11, GateId.g16, GateId.g33],
    usesCamera: true,
    needsMaxBrightness: true,
    durationLabel: 'about 2 min',
    purpose:
        'Letters shaped like an E get smaller while you say which way the E points. The camera keeps you at 40 cm so the size is exact.',
    whatYouDo: [
      VisionStep(VisionIllustration.coverEye, 'Cover one eye'),
      VisionStep(VisionIllustration.phoneAt40cm, 'Hold at 40 cm'),
      VisionStep(VisionIllustration.swipeArrows, 'Swipe the way the E points'),
    ],
    measures: [
      'Acuity per eye in logMAR (LOGMAR_R, LOGMAR_L; −0.3 to 1.3, normal ≤ 0.2 ≈ 6/9.5)',
      'Face distance 40 ± 5 cm live (face_distance_cm, CAP-15 / G-33)',
      'Optotype height 5 arcmin · stroke 1 arcmin at logMAR 0.0, sized by screen DPI',
    ],
    markerMeanings: {
      'LOGMAR_R':
          'How small an E your right eye could still read at 40 cm. 0.0 is standard sight; 0.2 or less is normal; higher numbers mean smaller letters were missed.',
      'LOGMAR_L': 'The same for your left eye.',
    },
    needs: [
      VisionNeedTile(
        VisionIllustration.glassesOn,
        'Your usual glasses',
        'Wear distance glasses or lenses if you normally do',
      ),
      VisionNeedTile(
        VisionIllustration.phoneAt40cm,
        'Arm\'s length',
        'The camera checks you stay at 40 cm',
      ),
    ],
    prepareChecklist: [
      VisionPrepareItem(
        VisionIllustration.glassesOn,
        'I am wearing the glasses or lenses I normally use for distance',
      ),
      VisionPrepareItem(
        VisionIllustration.brightnessMax,
        'The room is bright and there is no glare on the screen',
      ),
      VisionPrepareItem(
        VisionIllustration.coverEye,
        'I can cover one eye with my palm without pressing on it',
      ),
    ],
    setupHint:
        'The screen goes to full brightness by itself. Hold the phone straight in front of you at arm\'s length.',
    howTo: [
      VisionHowToStep(
        VisionIllustration.coverEye,
        'Cover your left eye first',
        'Cover the left eye with your palm. The right eye is tested first, then you swap.',
      ),
      VisionHowToStep(
        VisionIllustration.phoneAt40cm,
        'Keep the phone at 40 cm',
        'Hold the phone at arm\'s length. The badge at the top turns green at the right distance; the letters pause if you drift.',
      ),
      VisionHowToStep(
        VisionIllustration.swipeArrows,
        'Swipe the way the E points',
        'An E appears pointing up, down, left or right. Swipe in that direction or tap the matching arrow. If you cannot tell, tap "Not sure". The E gets smaller until you miss.',
      ),
    ],
    voiceStart:
        'Cover your left eye. Hold the phone at arm\'s length and swipe the way the E points.',
    voiceSwitch: 'Now cover your right eye. Testing the left eye.',
    voiceDone: 'Done. Both eyes tested.',
    analysisStages: [
      'Checking distance was 35–45 cm for each letter',
      'Letter sizes from screen DPI and distance',
      'Staircase threshold per eye (logMAR)',
      'Banding against the 0.2 line and personal baseline',
    ],
    referenceTitle: 'How to read it',
    referenceRows: [
      VisionReferenceRow('Normal', '≤ 0.2 logMAR (≈ 6/9.5 Snellen) (Spec §9)'),
      VisionReferenceRow('Range', '−0.3 (very sharp) to 1.3 logMAR (Spec §9)'),
      VisionReferenceRow(
        'Distance',
        '40 ± 5 cm, letters pause outside it (Spec §9, G-33)',
      ),
      VisionReferenceRow(
        'Snellen guide',
        '0.0 = 6/6 · 0.2 = 6/9.5 · 0.3 = 6/12 · 0.5 = 6/19 · 1.0 = 6/60',
        provenance: 'DER',
      ),
      VisionReferenceRow(
        'Staircase',
        'Each size shown up to 3 times; 2 right → smaller, 2 wrong → larger; stops at the second turn',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'A screening check at 40 cm, not a glasses prescription. Tiredness, dry eyes and glare make letters harder to read.',
    resultTitle: 'Visual acuity result',
  );

  // ── 2. Colour vision plates (ALG-MOV-11, S-H08) ─────────────────────────
  static const VisionProtocol colour = VisionProtocol(
    id: 'vis_colour',
    kind: VisionTestKind.colour,
    screenId: 'S-H08',
    catalogueId: 'cat_vis_colour',
    title: 'Colour vision',
    shortTitle: 'Colour vision',
    recordTitle: 'Colour Vision Deficiency Plates',
    algorithmId: 'ALG-MOV-11',
    conditionCode: 'COND_COLOUR_VISION',
    perEye: false,
    requiredGates: [GateId.g04],
    needsMaxBrightness: true,
    durationLabel: 'about 1 min',
    purpose:
        'You read the number hidden in 12 plates of coloured dots, like the printed plates at an optometrist. Ten plates use colours that look alike to people with red–green colour deficiency; two are easy control plates that check the screen.',
    whatYouDo: [
      VisionStep(VisionIllustration.brightnessMax, 'Screen at full brightness'),
      VisionStep(VisionIllustration.colourPlate, 'Find the hidden number'),
      VisionStep(VisionIllustration.waitThenTap, 'Tap the number you see'),
    ],
    measures: [
      'Plates read correctly out of 12 (COLOUR_PLATE_SCORE; normal = all correct)',
      '10 red–green screening plates in three colour pairs: orange on green, red-brown on olive, pink on grey-green',
      '2 control plates (readable by everyone) check brightness, filters and attention',
      'After the test every plate is shown again with its number revealed next to your answer',
    ],
    markerMeanings: {
      'COLOUR_PLATE_SCORE':
          'How many of the 12 plates you read correctly. All 12 is normal. Missing 3 or more of the 10 red–green plates suggests a colour deficiency; 1–2 missed → repeat in good light. A missed control plate means the screen, not your eyes, needs checking.',
    },
    needs: [
      VisionNeedTile(
        VisionIllustration.brightnessMax,
        'Full brightness',
        'Set automatically; keep the phone out of direct sun',
      ),
      VisionNeedTile(
        VisionIllustration.noFilter,
        'No colour filters',
        'Turn off night mode, blue-light or reading filters',
      ),
    ],
    prepareChecklist: [
      VisionPrepareItem(
        VisionIllustration.noFilter,
        'Night mode, blue-light and colour filters are off',
      ),
      VisionPrepareItem(
        VisionIllustration.brightnessMax,
        'I am in normal room light, not direct sunlight',
      ),
      VisionPrepareItem(
        VisionIllustration.glassesOn,
        'I am wearing my usual glasses (not tinted)',
      ),
    ],
    setupHint:
        'Both eyes stay open. The first two plates are easy on purpose — they check the screen.',
    howTo: [
      VisionHowToStep(
        VisionIllustration.colourPlate,
        'Look for a number in the dots',
        'Each plate hides one number from 1 to 9. Take a few seconds, then tap the number you see. Do not tilt the phone.',
      ),
      VisionHowToStep(
        VisionIllustration.waitThenTap,
        'Tap "I see nothing" if there is none',
        'Do not guess. If no number stands out, tap "I see nothing". There are 12 plates.',
      ),
      VisionHowToStep(
        VisionIllustration.noFilter,
        'Keep the screen clean and bright',
        'Smudges, dim light and colour filters change the colours. The test checks this with two easy plates.',
      ),
    ],
    voiceStart: 'Look for the number in the dots and tap it. Twelve plates.',
    voiceSwitch: '',
    voiceDone: 'Done. All plates answered.',
    analysisStages: [
      'Checking the two control plates',
      'Tallying correct plates',
      'Red–green screening plates missed',
      'Banding and personal baseline',
    ],
    referenceTitle: 'How to read it',
    referenceRows: [
      VisionReferenceRow('Normal', 'All screening plates correct (Spec §9)'),
      VisionReferenceRow(
        'Screen',
        'Brightness 100 %, colour filters off; low brightness is boosted before the test (Spec §9)',
      ),
      VisionReferenceRow(
        'Condition informed',
        'Red–green colour vision deficiency (Spec §9)',
      ),
      VisionReferenceRow(
        'Validation target',
        'Agreement ≥ 90 % with an optometrist'
            's Ishihara book (Spec §9)',
      ),
      VisionReferenceRow(
        'Plates',
        'Drawn in-app: 2 control + 10 red–green confusion plates. Clinical Ishihara plates pending [OPEN]',
        provenance: 'DER',
      ),
      VisionReferenceRow(
        'Screening line',
        '3 or more red–green plates missed suggests a deficiency; 1–2 → repeat',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'Screen colours vary by phone. A deficiency found here should be confirmed with printed plates by an optometrist.',
    resultTitle: 'Colour vision result',
  );

  // ── 3. Amsler grid (ALG-MOV-11, S-H09) ──────────────────────────────────
  static const VisionProtocol amsler = VisionProtocol(
    id: 'vis_amsler',
    kind: VisionTestKind.amsler,
    screenId: 'S-H09',
    catalogueId: 'cat_vis_amsler',
    title: 'Amsler grid',
    shortTitle: 'Amsler grid',
    recordTitle: 'Amsler Grid Macular Check',
    algorithmId: 'ALG-MOV-11',
    conditionCode: 'COND_MACULA',
    perEye: true,
    requiredGates: [GateId.g04],
    needsMaxBrightness: true,
    durationLabel: 'about 1 min',
    purpose:
        'You look at the dot in the middle of a square grid, one eye at a time, and mark any lines that look wavy, blurred or missing.',
    whatYouDo: [
      VisionStep(VisionIllustration.coverEye, 'Cover one eye'),
      VisionStep(VisionIllustration.amslerGrid, 'Stare at the centre dot'),
      VisionStep(VisionIllustration.markWavy, 'Mark anything wavy or missing'),
    ],
    measures: [
      'Distortion marked per eye (AMSLER_ABNORMAL_R, AMSLER_ABNORMAL_L; normal = none)',
      'Grid 10 × 10 cm at 30 cm, central fixation dot (Spec §9)',
    ],
    markerMeanings: {
      'AMSLER_ABNORMAL':
          'Whether you marked any part of the grid as wavy, blurred or missing while looking at the dot. "No" is normal.',
    },
    needs: [
      VisionNeedTile(
        VisionIllustration.readingGlasses,
        'Reading glasses',
        'Wear them if you use them for reading',
      ),
      VisionNeedTile(
        VisionIllustration.phoneAt30cm,
        'Phone at 30 cm',
        'About the distance you read a book',
      ),
    ],
    prepareChecklist: [
      VisionPrepareItem(
        VisionIllustration.readingGlasses,
        'I am wearing my reading glasses if I use them',
      ),
      VisionPrepareItem(
        VisionIllustration.phoneAt30cm,
        'I will hold the phone about 30 cm away, in good light',
      ),
      VisionPrepareItem(
        VisionIllustration.coverEye,
        'I can cover one eye with my palm',
      ),
    ],
    setupHint:
        'Keep looking only at the dot while you judge the lines around it. Mark with a finger, then tap Done.',
    howTo: [
      VisionHowToStep(
        VisionIllustration.coverEye,
        'Cover your left eye first',
        'The right eye is tested first. Cover the other eye with your palm, not your fingers.',
      ),
      VisionHowToStep(
        VisionIllustration.amslerGrid,
        'Stare at the dot',
        'Keep your eye on the centre dot. Without looking away, notice whether all the lines look straight and all the small squares are there.',
      ),
      VisionHowToStep(
        VisionIllustration.markWavy,
        'Mark what looks wrong',
        'Drag your finger over any area that looks wavy, blurred, dark or missing. If everything looks fine, tap "Looks normal". Then the other eye.',
      ),
    ],
    voiceStart:
        'Cover your left eye. Look at the centre dot and mark anything that looks wavy or missing.',
    voiceSwitch: 'Now cover your right eye and do the same with the left eye.',
    voiceDone: 'Done. Both eyes checked.',
    analysisStages: [
      'Reading the marked squares per eye',
      'Central 5° versus outer field',
      'Banding and personal baseline',
    ],
    referenceTitle: 'How to read it',
    referenceRows: [
      VisionReferenceRow('Normal', 'No distortion marked (Spec §9)'),
      VisionReferenceRow(
        'Grid',
        '10 × 10 cm with a central dot, held at 30 cm, each eye (Spec §9)',
      ),
      VisionReferenceRow(
        'What it screens',
        'Macular degeneration and diabetic macular oedema (Spec §9 conditions)',
      ),
      VisionReferenceRow(
        'Next step',
        'Any new distortion → dilated eye exam / OCT within weeks',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'Lines can look faint at the edge of vision for everyone; only mark what looks wavy, bent or missing while you stare at the dot.',
    resultTitle: 'Amsler grid result',
  );

  // ── 4. Reaction time (ALG-MOV-12, S-H10) ────────────────────────────────
  static const VisionProtocol reaction = VisionProtocol(
    id: 'vis_reaction',
    kind: VisionTestKind.reaction,
    screenId: 'S-H10',
    catalogueId: 'cat_vis_reaction',
    title: 'Reaction time',
    shortTitle: 'Reaction time',
    recordTitle: 'Visual & Auditory Reaction Time',
    algorithmId: 'ALG-MOV-12',
    conditionCode: 'COND_COG',
    perEye: false,
    requiredGates: [GateId.g04, GateId.g12],
    usesSound: true,
    durationLabel: 'about 2 min',
    purpose:
        'You tap the screen as fast as you can when it flashes, then when it beeps. The app measures the delay in milliseconds.',
    whatYouDo: [
      VisionStep(VisionIllustration.waitThenTap, 'Wait for the signal'),
      VisionStep(VisionIllustration.tapFlash, '10 flashes — tap fast'),
      VisionStep(VisionIllustration.speaker, '10 beeps — tap fast'),
    ],
    measures: [
      'Median visual reaction time (RT_VISUAL_MS) over 10 flashes',
      'Median auditory reaction time (RT_AUDIO_MS) over 10 beeps',
      'Taps under 100 ms discarded as anticipation and replaced (Spec §9)',
    ],
    markerMeanings: {
      'RT_VISUAL_MS':
          'Your typical delay between the flash and your tap, in thousandths of a second. Lower is faster.',
      'RT_AUDIO_MS': 'The same for the beep.',
    },
    needs: [
      VisionNeedTile(
        VisionIllustration.speaker,
        'Sound on',
        'Media volume up; no headphones needed',
      ),
      VisionNeedTile(
        VisionIllustration.tapFlash,
        'One finger ready',
        'Phone on a table or held firmly, finger hovering over the screen',
      ),
    ],
    prepareChecklist: [
      VisionPrepareItem(
        VisionIllustration.speaker,
        'Media volume is up and the room is quiet',
      ),
      VisionPrepareItem(
        VisionIllustration.tapFlash,
        'The phone is on a table or held firmly, one finger ready',
      ),
      VisionPrepareItem(
        VisionIllustration.waitThenTap,
        'I will wait for the signal — tapping early does not count',
      ),
    ],
    setupHint:
        'The gap before each signal is random (1–4 s). Tap anywhere on the screen.',
    howTo: [
      VisionHowToStep(
        VisionIllustration.waitThenTap,
        'Wait…',
        'The screen says "Wait". Keep your finger just above the screen and do not tap until the signal.',
      ),
      VisionHowToStep(
        VisionIllustration.tapFlash,
        'Flash — tap at once',
        'The screen turns green. Tap as fast as you can. Ten flashes.',
      ),
      VisionHowToStep(
        VisionIllustration.speaker,
        'Beep — tap at once',
        'Then the phone beeps instead. Tap as fast as you can. Ten beeps. A tap before the signal is a false start and is repeated.',
      ),
    ],
    voiceStart: 'Wait for the flash, then tap as fast as you can.',
    voiceSwitch: 'Now listen. Tap as soon as you hear the beep.',
    voiceDone: 'Done. Twenty signals recorded.',
    analysisStages: [
      'Discarding taps under 100 ms',
      'Median of 10 visual trials',
      'Median of 10 sound trials',
      'Personal baseline (age norms pending)',
    ],
    referenceTitle: 'How to read it',
    referenceRows: [
      VisionReferenceRow(
        'Trials',
        '10 visual + 10 sound, random 1–4 s gaps (Spec §9)',
      ),
      VisionReferenceRow(
        'Anticipation',
        'Taps < 100 ms discarded and replaced (Spec §9)',
      ),
      VisionReferenceRow(
        'Norms',
        'Age norms pending (Q-COHORT) — value recorded, no band',
      ),
      VisionReferenceRow(
        'Typical adults',
        'Simple visual ≈ 200–300 ms, sound ≈ 150–250 ms; slows with age and tiredness',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'Recorded for your personal baseline. A clear slowing against your own earlier tests matters more than one number.',
    resultTitle: 'Reaction time result',
  );
}
