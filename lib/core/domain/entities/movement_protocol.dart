// Movement-test protocols (Doc 09 §9 ALG-MOV-01..05, Doc 05 S-H01..S-H05).
//
// Data only — the capture, intro and result screens read everything (copy,
// voice script, pacing, gates, reference rows, pictures) from these records.
// Member-facing copy is plain language; algorithm codes live in [measures],
// [referenceRows] and [markerMeanings] for the clinician expander.
// Copy marked [DER] comes from MDS-UPDRS / mPower / CDC STEADI wording where
// the document gives none.
import 'enums.dart';

enum MovementTestKind { tappingVideo, tappingTouch, gait, sitToStand, tremor }

enum MovementSide {
  left('Left'),
  right('Right');

  const MovementSide(this.label);
  final String label;

  String get suffix => this == MovementSide.left ? 'L' : 'R';
  MovementSide get other =>
      this == MovementSide.left ? MovementSide.right : MovementSide.left;
}

enum MovementSensor { frontCamera, touch, accelerometer, gyroscope }

/// How the app paces the test (Spec §9 intro: "voice instructions +
/// metronome").
enum MovementPacing {
  /// Voice start / stop only (gait: the walk itself sets the rhythm).
  none,

  /// A soft tick every second while recording, plus voice start / stop.
  metronome,

  /// Each counted repetition is spoken aloud, plus voice start / stop.
  voiceCount,
}

/// Static model stand-in outcomes for Test Controls / FLUTTER_TEST.
enum MovementDemoOutcome { normal, borderline, refer }

/// Every drawing the movement screens can show (see
/// `movement_illustrations.dart`).
enum MovementIllustration {
  handInFrame,
  handTapping,
  tapOpenClose,
  twoTargets,
  tableFlat,
  phoneInPocket,
  walk10m,
  measureTape,
  chairArmless,
  sitReady,
  standUp,
  armOutstretched,
  bubbleLevel,
  holdStill,
  countdown,
  switchHands,
  handLeft,
  handRight,
  restartHand,
  lightEven,
  phoneStand,
}

/// One illustrated step on the intro ("What you'll do") strip.
class MovementStep {
  const MovementStep(this.illustration, this.caption);

  final MovementIllustration illustration;
  final String caption;
}

class MovementHowToStep {
  const MovementHowToStep(this.illustration, this.title, this.body);

  final MovementIllustration illustration;
  final String title;
  final String body;
}

class MovementNeedTile {
  const MovementNeedTile(this.illustration, this.title, this.sub);

  final MovementIllustration illustration;
  final String title;
  final String sub;
}

/// One tick-to-continue row on the Prepare step, with its picture.
class MovementPrepareItem {
  const MovementPrepareItem(this.illustration, this.text);

  final MovementIllustration illustration;
  final String text;
}

/// A row on the result's reference card. [provenance] is 'DOC' when the
/// value is in the algorithm document and 'DER' for research references.
class MovementReferenceRow {
  const MovementReferenceRow(this.label, this.value, {this.provenance = 'DOC'});

  final String label;
  final String value;
  final String provenance;
}

class MovementProtocol {
  const MovementProtocol({
    required this.id,
    required this.kind,
    required this.screenId,
    required this.catalogueId,
    required this.title,
    required this.shortTitle,
    required this.recordTitle,
    required this.algorithmId,
    required this.conditionCode,
    required this.twoSided,
    required this.secondsPerSide,
    required this.pacing,
    required this.sensors,
    required this.requiredGates,
    required this.purpose,
    required this.whatYouDo,
    required this.measures,
    required this.markerMeanings,
    required this.needs,
    required this.prepareChecklist,
    required this.howTo,
    required this.voiceGo,
    required this.voiceMid,
    required this.voiceStop,
    required this.analysisStages,
    required this.referenceTitle,
    required this.referenceRows,
    required this.referenceNote,
    required this.resultTitle,
    this.countdownSeconds = 3,
    this.maxSeconds,
    this.featureId = 'F-26',
    this.algorithmVersion = 'v0.9.0',
    this.rangeVersion = 'mst_ref_2026.10',
    this.setupHint = '',
    this.demoOutcomeLabels = const {
      'normal': 'Normal',
      'borderline': 'Borderline',
      'refer': 'Refer',
    },
  });

  final String id;
  final MovementTestKind kind;
  final String screenId;
  final String catalogueId;
  final String title;
  final String shortTitle;
  final String recordTitle;
  final String algorithmId;
  final String conditionCode;
  final String featureId;
  final String algorithmVersion;
  final String rangeVersion;

  /// Left and right hand in turn.
  final bool twoSided;

  /// Recording length per side (gait: target; see [maxSeconds]).
  final int secondsPerSide;
  final int countdownSeconds;

  /// Hard stop for open-ended recordings (gait auto-stop).
  final int? maxSeconds;
  final MovementPacing pacing;
  final List<MovementSensor> sensors;
  final List<GateId> requiredGates;

  /// One plain sentence: what the test looks for.
  final String purpose;

  /// Three illustrated steps shown on the intro.
  final List<MovementStep> whatYouDo;

  /// Clinician list with the spec codes.
  final List<String> measures;

  /// Plain one-liner per spec marker code ("What the numbers mean").
  final Map<String, String> markerMeanings;
  final List<MovementNeedTile> needs;
  final List<MovementPrepareItem> prepareChecklist;
  final String setupHint;
  final List<MovementHowToStep> howTo;
  final String voiceGo;
  final String voiceMid;
  final String voiceStop;
  final List<String> analysisStages;
  final String referenceTitle;
  final List<MovementReferenceRow> referenceRows;
  final String referenceNote;
  final String resultTitle;
  final Map<String, String> demoOutcomeLabels;

  bool get usesCamera => sensors.contains(MovementSensor.frontCamera);
  bool get usesMotion =>
      sensors.contains(MovementSensor.accelerometer) ||
      sensors.contains(MovementSensor.gyroscope);
  bool get usesTouch => sensors.contains(MovementSensor.touch);

  String get sensorSummary => switch (kind) {
    MovementTestKind.tappingVideo => 'Front camera · ≥ 30 fps · hand tracking',
    MovementTestKind.tappingTouch => 'Touch screen · millisecond timestamps',
    MovementTestKind.gait => 'Accelerometer 50 Hz · phone in front pocket',
    MovementTestKind.sitToStand => 'Accelerometer 50 Hz · armless chair',
    MovementTestKind.tremor => 'Gyroscope 100 Hz · phone held at arm\'s length',
  };

  /// Plain-language version of [sensorSummary] for member screens.
  String get plainSensorLine => switch (kind) {
    MovementTestKind.tappingVideo => 'Uses the front camera',
    MovementTestKind.tappingTouch => 'Uses the touch screen',
    MovementTestKind.gait => 'Uses the phone\'s motion sensor',
    MovementTestKind.sitToStand => 'Uses the phone\'s motion sensor',
    MovementTestKind.tremor => 'Uses the phone\'s motion sensor',
  };

  String get durationLabel => switch (kind) {
    MovementTestKind.gait => 'about 1 min',
    MovementTestKind.tremor => 'about 1 min',
    MovementTestKind.sitToStand => '30 s',
    _ => '10 s per hand',
  };

  /// Headline shown on the live Test screen while recording.
  String get runHeadline => switch (kind) {
    MovementTestKind.tappingVideo => 'Tap big and fast',
    MovementTestKind.tappingTouch => 'Tap A, then B',
    MovementTestKind.gait => 'Walk now',
    MovementTestKind.sitToStand => 'Stand up, sit down',
    MovementTestKind.tremor => 'Hold still',
  };
}

class MovementProtocols {
  MovementProtocols._();

  static const List<MovementProtocol> all = [
    tappingVideo,
    tappingTouch,
    gait,
    sitToStand,
    tremor,
  ];

  static MovementProtocol? forScreenId(String screenId) {
    for (final p in all) {
      if (p.screenId == screenId) return p;
    }
    return null;
  }

  static MovementProtocol? forId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ── 1. Finger tapping — video (ALG-MOV-01, S-H01) ─────────────────────
  static const MovementProtocol tappingVideo = MovementProtocol(
    id: 'mov_tap_video',
    kind: MovementTestKind.tappingVideo,
    screenId: 'S-H01',
    catalogueId: 'cat_mov_tap_video',
    title: 'Finger tapping — video',
    shortTitle: 'Finger tapping (video)',
    recordTitle: 'Finger Tapping — Video (Bradykinesia)',
    algorithmId: 'ALG-MOV-01',
    conditionCode: 'COND_PD',
    twoSided: true,
    secondsPerSide: 10,
    pacing: MovementPacing.metronome,
    sensors: [MovementSensor.frontCamera],
    requiredGates: [GateId.g04, GateId.g11, GateId.g21],
    purpose:
        'The camera watches you tap your thumb and index finger together and checks whether the taps slow down or get smaller.',
    whatYouDo: [
      MovementStep(MovementIllustration.handInFrame, 'Show one hand'),
      MovementStep(MovementIllustration.handTapping, 'Tap big and fast 10 s'),
      MovementStep(MovementIllustration.switchHands, 'Then the other hand'),
    ],
    measures: [
      'Taps in 10 s and tap frequency (TAP_COUNT 0–80, TAP_FREQ Hz)',
      'Amplitude decrement, first 3 s vs last 3 s (TAP_DECREMENT %, normal < 20 %)',
      'Inter-tap interval variability (TAP_CV %)',
    ],
    markerMeanings: {
      'TAP_COUNT': 'How many taps you made in 10 seconds',
      'TAP_FREQ': 'Taps per second',
      'TAP_DECREMENT':
          'How much smaller your taps got from the first 3 s to the last 3 s. Under 20 % is normal.',
      'TAP_CV': 'How uneven the gaps between taps were. Lower is steadier.',
    },
    needs: [
      MovementNeedTile(
        MovementIllustration.phoneStand,
        'Phone propped up',
        'Front camera facing you, about chest height',
      ),
      MovementNeedTile(
        MovementIllustration.lightEven,
        'Good light',
        'Light on your hand, no window behind it',
      ),
    ],
    prepareChecklist: [
      MovementPrepareItem(
        MovementIllustration.phoneStand,
        'The phone is propped upright with the front camera facing me',
      ),
      MovementPrepareItem(
        MovementIllustration.lightEven,
        'The light is on my hand, not behind it',
      ),
      MovementPrepareItem(
        MovementIllustration.handInFrame,
        'I can hold one hand up, palm to the phone, about an arm\'s length away',
      ),
    ],
    setupHint:
        'A phone stand or a propped-up book works. Someone can also hold the phone for you.',
    howTo: [
      MovementHowToStep(
        MovementIllustration.handInFrame,
        'Show your whole hand',
        'Hold one hand up with the palm facing the phone. Keep the whole hand inside the outline until the app says "Hand found".',
      ),
      MovementHowToStep(
        MovementIllustration.handTapping,
        'Tap big and fast',
        'Tap your index finger and thumb together as big and as fast as you can for 10 seconds. Open wide between taps.',
      ),
      MovementHowToStep(
        MovementIllustration.switchHands,
        'Then the other hand',
        'After 10 seconds the app says "Stop" and asks for the other hand. If your hand leaves the outline for over a second, that hand starts again.',
      ),
    ],
    voiceGo: 'Go. Tap as big and as fast as you can.',
    voiceMid: 'Keep going, big and fast.',
    voiceStop: 'Stop. Relax your hand.',
    analysisStages: [
      'Tracking 21 hand landmarks per frame',
      'Thumb–index distance normalised by hand size',
      'Detecting tap peaks · count, frequency, rhythm',
      'Amplitude decrement first 3 s vs last 3 s',
      'Banding and personal baseline',
    ],
    referenceTitle: 'How to read it',
    referenceRows: [
      MovementReferenceRow('Amplitude decrement', '< 20 % normal (Spec §9)'),
      MovementReferenceRow(
        'Taps, frequency, rhythm',
        'Age norms pending (Q-COHORT)',
      ),
      MovementReferenceRow(
        'Clinical reference',
        'MDS-UPDRS item 3.4: speed, amplitude, hesitations, decrement rated 0–4',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'A screening signal, not a diagnosis. Tiredness, arthritis or a cold hand also slow tapping.',
    resultTitle: 'Finger tapping result',
  );

  // ── 2. Finger tapping — touch (ALG-MOV-02, S-H02) ─────────────────────
  static const MovementProtocol tappingTouch = MovementProtocol(
    id: 'mov_tap_touch',
    kind: MovementTestKind.tappingTouch,
    screenId: 'S-H02',
    catalogueId: 'cat_mov_tap_touch',
    title: 'Finger tapping — touch',
    shortTitle: 'Finger tapping (touch)',
    recordTitle: 'Finger Tapping — Touch Rhythm',
    algorithmId: 'ALG-MOV-02',
    conditionCode: 'COND_PD',
    twoSided: true,
    secondsPerSide: 10,
    pacing: MovementPacing.metronome,
    sensors: [MovementSensor.touch],
    requiredGates: [GateId.g04],
    purpose:
        'You tap two circles on the screen in turn. The app counts the taps and checks how even your rhythm is.',
    whatYouDo: [
      MovementStep(MovementIllustration.tableFlat, 'Phone flat on a table'),
      MovementStep(MovementIllustration.twoTargets, 'Tap A, B, A, B for 10 s'),
      MovementStep(MovementIllustration.switchHands, 'Then the other hand'),
    ],
    measures: [
      'Alternating taps in 10 s (TOUCH_TAP_COUNT)',
      'Inter-tap interval variability (INTER_TAP_CV %)',
    ],
    markerMeanings: {
      'TOUCH_TAP_COUNT':
          'How many times you tapped A then B (or B then A) in 10 seconds',
      'INTER_TAP_CV':
          'How uneven the gaps between taps were. Lower is steadier.',
    },
    needs: [
      MovementNeedTile(
        MovementIllustration.tableFlat,
        'Phone flat on a table',
        'Screen up, within easy reach',
      ),
      MovementNeedTile(
        MovementIllustration.twoTargets,
        'One finger',
        'Tap the two circles in turn, as fast as you can',
      ),
    ],
    prepareChecklist: [
      MovementPrepareItem(
        MovementIllustration.tableFlat,
        'The phone is lying flat on a table, screen up',
      ),
      MovementPrepareItem(
        MovementIllustration.sitReady,
        'I am sitting comfortably with my forearm resting on the table',
      ),
      MovementPrepareItem(
        MovementIllustration.twoTargets,
        'I will use the index finger of one hand at a time',
      ),
    ],
    setupHint: 'Only taps that go A, B, A, B are counted.',
    howTo: [
      MovementHowToStep(
        MovementIllustration.twoTargets,
        'Tap the two circles in turn',
        'Rest your hand on the table. With your index finger tap circle A, then B, then A again, as fast as you can for 10 seconds.',
      ),
      MovementHowToStep(
        MovementIllustration.countdown,
        'Wait for "Go"',
        'The app counts three, two, one. Taps before "Go" are not counted. You need at least 5 taps for the hand to count.',
      ),
      MovementHowToStep(
        MovementIllustration.switchHands,
        'Then the other hand',
        'After 10 seconds the app says "Stop" and asks for the other hand.',
      ),
    ],
    voiceGo: 'Go. Tap the two circles in turn, as fast as you can.',
    voiceMid: 'Keep going.',
    voiceStop: 'Stop.',
    analysisStages: [
      'Reading millisecond tap timestamps',
      'Keeping alternating taps only',
      'Inter-tap interval variability',
      'Banding and personal baseline',
    ],
    referenceTitle: 'How to read it',
    referenceRows: [
      MovementReferenceRow('Taps and rhythm', 'Age norms pending (Q-COHORT)'),
      MovementReferenceRow('Valid hand', '≥ 5 alternating taps (Spec §9)'),
      MovementReferenceRow(
        'Research reference',
        'Healthy adults: about 60–90 single-finger alternating taps per 30 s between well-separated targets',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'Recorded for your personal baseline; the count is compared with your own earlier tests.',
    resultTitle: 'Touch tapping result',
  );

  // ── 3. 10-metre gait walk (ALG-MOV-03, S-H03) ─────────────────────────
  static const MovementProtocol gait = MovementProtocol(
    id: 'mov_gait',
    kind: MovementTestKind.gait,
    screenId: 'S-H03',
    catalogueId: 'cat_mov_gait',
    title: '10-metre walk test',
    shortTitle: 'Walk test',
    recordTitle: '10-Metre Gait Walk Test',
    algorithmId: 'ALG-MOV-03',
    conditionCode: 'COND_FALL',
    twoSided: false,
    secondsPerSide: 60,
    maxSeconds: 60,
    countdownSeconds: 5,
    pacing: MovementPacing.none,
    sensors: [MovementSensor.accelerometer],
    requiredGates: [GateId.g04, GateId.g13],
    purpose:
        'With the phone in your pocket you walk 10 metres at your normal pace. The app times the walk and counts your steps.',
    whatYouDo: [
      MovementStep(MovementIllustration.measureTape, 'Mark out 10 metres'),
      MovementStep(MovementIllustration.phoneInPocket, 'Phone in front pocket'),
      MovementStep(MovementIllustration.walk10m, 'Walk at your normal pace'),
    ],
    measures: [
      'Walking speed (GAIT_SPEED m/s, ≥ 0.8 normal for older adults)',
      'Steps and cadence (STEPS, CADENCE steps/min)',
      'Step-time variability (STEP_CV %)',
    ],
    markerMeanings: {
      'GAIT_SPEED':
          'How fast you walked: 10 metres divided by the time taken. 0.8 m/s or more is normal for older adults.',
      'STEPS': 'How many steps the 10 metres took',
      'CADENCE': 'Steps per minute',
      'STEP_CV': 'How uneven the time between steps was. Lower is steadier.',
    },
    needs: [
      MovementNeedTile(
        MovementIllustration.measureTape,
        '10 m straight path',
        'Measure it, or count 13 adult paces, and mark both ends',
      ),
      MovementNeedTile(
        MovementIllustration.phoneInPocket,
        'Front trouser pocket',
        'Screen towards your leg',
      ),
    ],
    prepareChecklist: [
      MovementPrepareItem(
        MovementIllustration.measureTape,
        'A clear, straight 10-metre path is marked at both ends',
      ),
      MovementPrepareItem(
        MovementIllustration.walk10m,
        'I have my usual shoes on, and my walking aid if I normally use one',
      ),
      MovementPrepareItem(
        MovementIllustration.phoneInPocket,
        'I will put the phone in my front trouser pocket, screen towards my leg',
      ),
    ],
    setupHint:
        'After you tap Start you have 5 seconds to pocket the phone. Walk at your normal pace; the app stops by itself when you stand still.',
    howTo: [
      MovementHowToStep(
        MovementIllustration.measureTape,
        'Mark 10 metres',
        'Use a tape, or count 13 adult paces, and mark the start and the end. Stand at the start.',
      ),
      MovementHowToStep(
        MovementIllustration.phoneInPocket,
        'Pocket the phone',
        'Tap Start, then put the phone in your front trouser pocket with the screen towards your leg. You have 5 seconds.',
      ),
      MovementHowToStep(
        MovementIllustration.walk10m,
        'Walk at your normal pace',
        'When you hear "Start walking", walk the 10 metres as you normally would, then stop and stand still. The app says "Stop" when it is done.',
      ),
    ],
    voiceGo: 'Start walking.',
    voiceMid: 'Keep walking at your normal pace.',
    voiceStop: 'Stop. You can take the phone out now.',
    analysisStages: [
      'Aligning the vertical axis to gravity',
      'Band-pass 0.5–3 Hz · heel-strike peaks',
      'Steps, cadence, step-time variability',
      'Speed = 10 m ÷ walk time',
      'Banding and personal baseline',
    ],
    referenceTitle: 'Reference ranges',
    referenceRows: [
      MovementReferenceRow(
        'Gait speed',
        '≥ 0.8 m/s normal, older adults (Spec §9)',
      ),
      MovementReferenceRow(
        'Fall-risk cut-off',
        '< 0.8 m/s (World Falls Guidelines); < 1.0 m/s flags more fallers',
        provenance: 'DER',
      ),
      MovementReferenceRow(
        'Usual speed by age (m/f)',
        '60–69: 1.34 / 1.24 · 70–79: 1.26 / 1.13 · 80+: 0.97 / 0.94 m/s',
        provenance: 'DER',
      ),
      MovementReferenceRow(
        'Timing',
        'Clinics time the middle 6 m; this app times the full 10 m from the first to the last step',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'A change of 0.13 m/s or more between your own tests is meaningful.',
    resultTitle: 'Walk test result',
  );

  // ── 4. 30-second sit-to-stand (ALG-MOV-04, S-H04) ─────────────────────
  static const MovementProtocol sitToStand = MovementProtocol(
    id: 'mov_sts',
    kind: MovementTestKind.sitToStand,
    screenId: 'S-H04',
    catalogueId: 'cat_mov_sts',
    title: '30-second sit-to-stand',
    shortTitle: 'Sit-to-stand',
    recordTitle: '30-Second Sit-to-Stand Test',
    algorithmId: 'ALG-MOV-04',
    conditionCode: 'COND_FALL',
    twoSided: false,
    secondsPerSide: 30,
    pacing: MovementPacing.voiceCount,
    sensors: [MovementSensor.accelerometer],
    requiredGates: [GateId.g04, GateId.g13],
    purpose:
        'You stand up from a chair and sit back down as many times as you can in 30 seconds. The app counts each stand.',
    whatYouDo: [
      MovementStep(MovementIllustration.sitReady, 'Sit, arms crossed'),
      MovementStep(MovementIllustration.standUp, 'Stand up, sit down'),
      MovementStep(
        MovementIllustration.countdown,
        'As many as you can in 30 s',
      ),
    ],
    measures: ['Full stands in 30 s (STS_COUNT_30S, ≥ 12 for age 60–64)'],
    markerMeanings: {
      'STS_COUNT_30S':
          'How many times you stood up fully in 30 seconds. The document gives a norm of 12 or more for ages 60–64.',
    },
    needs: [
      MovementNeedTile(
        MovementIllustration.chairArmless,
        'Chair without arms',
        'Seat about knee height, back against a wall',
      ),
      MovementNeedTile(
        MovementIllustration.phoneInPocket,
        'Phone in front pocket',
        'Or held flat to your chest under crossed arms',
      ),
    ],
    prepareChecklist: [
      MovementPrepareItem(
        MovementIllustration.chairArmless,
        'An armless chair stands with its back against a wall',
      ),
      MovementPrepareItem(
        MovementIllustration.sitReady,
        'I am sitting in the middle of the seat, feet flat, arms crossed on my chest',
      ),
      MovementPrepareItem(
        MovementIllustration.phoneInPocket,
        'The phone is in my front trouser pocket',
      ),
    ],
    setupHint:
        'If you need your arms to stand up, stop — the test is not safe for you today.',
    howTo: [
      MovementHowToStep(
        MovementIllustration.sitReady,
        'Sit ready',
        'Sit in the middle of the chair with your feet flat on the floor and your arms crossed on your chest.',
      ),
      MovementHowToStep(
        MovementIllustration.standUp,
        'On "Go", stand and sit',
        'Stand up fully, then sit back down. Repeat as many times as you can in 30 seconds. The app counts each stand aloud.',
      ),
      MovementHowToStep(
        MovementIllustration.chairArmless,
        'Stop on "Stop"',
        'When you hear "Stop", stay seated. A stand that is more than halfway up when time runs out still counts.',
      ),
    ],
    voiceGo: 'Go. Stand up and sit down as many times as you can.',
    voiceMid: 'Halfway. Keep going.',
    voiceStop: 'Stop. Stay seated.',
    analysisStages: [
      'Aligning the vertical axis to gravity',
      'Low-pass 0.2–2 Hz · stand–sit cycles',
      'Counting completed cycles',
      'Age / sex norm and personal baseline',
    ],
    referenceTitle: 'Reference ranges',
    referenceRows: [
      MovementReferenceRow('Age 60–64', '≥ 12 stands (Spec §9)'),
      MovementReferenceRow('Other ages', 'Age / sex norm pending (Q-COHORT)'),
      MovementReferenceRow(
        'CDC STEADI below-average (m / f)',
        '60–64 < 14 / < 12 · 65–69 < 12 / < 11 · 70–74 < 12 / < 10 · 75–79 < 11 / < 10 · 80–84 < 10 / < 9 · 85–89 < 8 / < 8 · 90–94 < 7 / < 4',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'A below-average score indicates a risk for falls (CDC). Not a diagnosis.',
    resultTitle: 'Sit-to-stand result',
  );

  // ── 5. Postural hand tremor (ALG-MOV-05, S-H05) ───────────────────────
  static const MovementProtocol tremor = MovementProtocol(
    id: 'mov_tremor',
    kind: MovementTestKind.tremor,
    screenId: 'S-H05',
    catalogueId: 'cat_mov_tremor',
    title: 'Postural hand tremor',
    shortTitle: 'Tremor test',
    recordTitle: 'Postural Hand Tremor Test',
    algorithmId: 'ALG-MOV-05',
    conditionCode: 'COND_PD',
    twoSided: true,
    secondsPerSide: 20,
    pacing: MovementPacing.metronome,
    sensors: [MovementSensor.gyroscope, MovementSensor.accelerometer],
    requiredGates: [GateId.g04, GateId.g13],
    purpose:
        'You hold the phone in your outstretched hand for 20 seconds. The phone\'s sensor looks for a shaking rhythm.',
    whatYouDo: [
      MovementStep(MovementIllustration.armOutstretched, 'Arm out, palm down'),
      MovementStep(MovementIllustration.holdStill, 'Hold still for 20 s'),
      MovementStep(MovementIllustration.switchHands, 'Then the other hand'),
    ],
    measures: [
      'Tremor frequency if a peak rises above the sensor noise (TREMOR_FREQ Hz, 3–12 Hz band)',
      'Tremor amplitude as angular speed (TREMOR_AMP deg/s)',
    ],
    markerMeanings: {
      'TREMOR_FREQ':
          'How many times per second the hand shook, if a shake was found. "No peak" means none was found.',
      'TREMOR_AMP': 'How strong the shake was, as turning speed of the phone.',
    },
    needs: [
      MovementNeedTile(
        MovementIllustration.armOutstretched,
        'Arm straight out',
        'Phone flat in the hand, palm down, 20 s per hand',
      ),
      MovementNeedTile(
        MovementIllustration.bubbleLevel,
        'Hold as still as you can',
        'A bubble on screen helps you keep the phone level',
      ),
    ],
    prepareChecklist: [
      MovementPrepareItem(
        MovementIllustration.sitReady,
        'I am sitting with my back supported',
      ),
      MovementPrepareItem(
        MovementIllustration.holdStill,
        'The phone is lying flat in one hand, screen up',
      ),
      MovementPrepareItem(
        MovementIllustration.armOutstretched,
        'I will hold the arm straight out in front at shoulder height, palm down',
      ),
    ],
    setupHint:
        'The first 2 seconds measure the sensor\'s own noise — keep still from the start.',
    howTo: [
      MovementHowToStep(
        MovementIllustration.armOutstretched,
        'Arm straight out',
        'Hold the phone flat in your hand and stretch the arm straight out in front, palm down. Keep the bubble in the circle.',
      ),
      MovementHowToStep(
        MovementIllustration.holdStill,
        'Hold still for 20 seconds',
        'Breathe normally and hold as still as you can. A big slow movement starts the 20 seconds again.',
      ),
      MovementHowToStep(
        MovementIllustration.switchHands,
        'Then the other hand',
        'The app says "Switch hands". Pass the phone to the other hand and do the same. You can skip a hand you cannot use.',
      ),
    ],
    voiceGo: 'Go. Hold the arm out and keep as still as you can.',
    voiceMid: 'Halfway. Keep holding still.',
    voiceStop: 'Stop. Lower your arm.',
    analysisStages: [
      'Angular speed at 100 Hz',
      'Welch spectrum 3–12 Hz · noise floor',
      'Dominant peak and band-passed amplitude',
      'Banding and personal baseline',
    ],
    referenceTitle: 'How to read it',
    referenceRows: [
      MovementReferenceRow(
        'Normal',
        'No spectral peak above the sensor noise floor (Spec §9)',
      ),
      MovementReferenceRow(
        'Analysis band',
        '3–12 Hz · Parkinsonian rest / re-emergent 4–6 Hz · essential postural 5–10 Hz (Spec §9)',
      ),
      MovementReferenceRow(
        'Note',
        'Frequency alone cannot tell Parkinson\'s from essential tremor; strength and context matter',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'Caffeine, anxiety, cold and some medicines increase tremor. A screening signal, not a diagnosis.',
    resultTitle: 'Tremor result',
  );
}
