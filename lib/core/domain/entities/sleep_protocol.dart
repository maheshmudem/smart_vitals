// Overnight Sleep Sonar & Apnoea Screen (Doc 04 F-21; Doc 05 S-G07 Sleep
// Setup → S-G08 Sleep Monitoring (night mode) → S-G09 Sleep Report; Doc 07
// G-12 / G-30 / G-32 / G-24; Doc 09 §8 ALG-AUD-07 sleep sonar + ALG-AUD-08
// sleep apnoea; Doc 08 markers; Doc 12 E-AUD-003). Data only — the intro,
// setup, night and report screens read all copy, pictures, gates and
// reference rows from this record, like the Breathing & Voice protocols.
import 'enums.dart';

/// Stand-in nights for Test Controls / FLUTTER_TEST.
enum SleepDemoOutcome {
  /// ≈ 6 h valid, AHI ≈ 2 → normal.
  normal,

  /// AHI ≈ 9 → mild (warning colour, no case).
  mild,

  /// AHI ≈ 20 → moderate (Routine referral, COND_OSA case).
  moderate,

  /// AHI ≈ 38 → severe (red, Routine referral per §13.2).
  severe,

  /// 2.5 h valid → breathing rate only, AHI not computed (E-AUD-003).
  shortNight,
}

/// Every drawing the sleep screens can show
/// (`lib/features/sleep/sleep_illustrations.dart`).
enum SleepIllustration {
  bedsideTable,
  charger,
  distance,
  doNotDisturb,
  speakerVolume,
  noEarphones,
  sonarWaves,
  nightClock,
  longPressStop,
  report,
  ring,
  micSweep,
  sleeper,
  notification,
}

class SleepStep {
  const SleepStep(this.illustration, this.caption);
  final SleepIllustration illustration;
  final String caption;
}

class SleepHowToStep {
  const SleepHowToStep(this.illustration, this.title, this.body);
  final SleepIllustration illustration;
  final String title;
  final String body;
}

class SleepNeedTile {
  const SleepNeedTile(this.illustration, this.title, this.sub);
  final SleepIllustration illustration;
  final String title;
  final String sub;
}

class SleepPrepareItem {
  const SleepPrepareItem(this.illustration, this.text);
  final SleepIllustration illustration;
  final String text;
}

class SleepReferenceRow {
  const SleepReferenceRow(this.label, this.value, {this.provenance = 'DOC'});
  final String label;
  final String value;
  final String provenance;
}

class SleepProtocol {
  const SleepProtocol({
    required this.id,
    required this.setupScreenId,
    required this.nightScreenId,
    required this.resultScreenId,
    required this.catalogueId,
    required this.title,
    required this.shortTitle,
    required this.recordTitle,
    required this.algorithmIds,
    required this.conditionCode,
    required this.featureId,
    required this.requiredGates,
    required this.optionalGates,
    required this.purpose,
    required this.whoFor,
    required this.whatYouDo,
    required this.measures,
    required this.markerMeanings,
    required this.needs,
    required this.prepareChecklist,
    required this.setupHint,
    required this.howTo,
    required this.whatToDo,
    required this.voiceStart,
    required this.voiceDone,
    required this.unpluggedWarning,
    required this.echoLostHint,
    required this.shortNightCopy,
    required this.analysisStages,
    required this.referenceRows,
    required this.referenceNote,
    required this.resultTitle,
    required this.durationLabel,
    required this.whatYouGet,
    required this.howWorkedOut,
    this.algorithmVersion = 'v0.9.0',
    this.rangeVersion = 'mst_ref_2026.10',
  });

  final String id;
  final String setupScreenId;
  final String nightScreenId;
  final String resultScreenId;
  final String catalogueId;
  final String title;
  final String shortTitle;
  final String recordTitle;
  final List<String> algorithmIds;
  final String conditionCode;
  final String featureId;
  final List<GateId> requiredGates;
  final List<GateId> optionalGates;
  final String purpose;
  final String whoFor;
  final List<SleepStep> whatYouDo;
  final List<String> measures;
  final Map<String, String> markerMeanings;
  final List<SleepNeedTile> needs;
  final List<SleepPrepareItem> prepareChecklist;
  final String setupHint;
  final List<SleepHowToStep> howTo;

  /// Short steps read aloud when the night starts.
  final List<String> whatToDo;
  final String voiceStart;
  final String voiceDone;
  final String unpluggedWarning;
  final String echoLostHint;

  /// E-AUD-003 copy when VALID_SLEEP_H < 4.0 h.
  final String shortNightCopy;
  final List<String> analysisStages;
  final List<SleepReferenceRow> referenceRows;
  final String referenceNote;
  final String resultTitle;
  final String durationLabel;
  final List<String> whatYouGet;
  final List<String> howWorkedOut;
  final String algorithmVersion;
  final String rangeVersion;

  /// Entry screen id used by the catalogue (S-G07).
  String get screenId => setupScreenId;
  String get algorithmLabel =>
      '${algorithmIds.first}..${algorithmIds.last.split('-').last}';
  bool get hasCondition => conditionCode.isNotEmpty;

  String get plainSensorLine =>
      'Phone on the bedside table, plugged in, listens all night';

  String get sensorSummary =>
      '18–20 kHz inaudible chirps from the speaker, native 48 kHz microphone stream → chest-motion breathing wave and SONAR_RR per 30-s epoch (AUD-07) · breathing-amplitude drops ≥ 90 % / ≥ 30 % for ≥ 10 s → APNOEA_EVENTS, HYPOPNOEA_EVENTS, AHI_EST = events ÷ VALID_SLEEP_H (≥ 4 h), OSA_BAND (AUD-08) · phone charging 0.3–1 m from the chest (G-30) · ring SpO2 optional (G-32)';

  /// Minimum valid sleep for the apnoea estimate (Doc 09 AUD-08).
  static const double minValidSleepH = 4.0;
}

class SleepProtocols {
  SleepProtocols._();

  static const List<SleepProtocol> all = [sonar];

  static SleepProtocol? forScreenId(String screenId) => switch (screenId) {
    'S-G07' || 'S-G08' || 'S-G09' => sonar,
    _ => null,
  };

  static SleepProtocol? forCatalogueId(String id) =>
      id == sonar.catalogueId ? sonar : null;

  static const SleepProtocol sonar = SleepProtocol(
    id: 'sleep_sonar',
    setupScreenId: 'S-G07',
    nightScreenId: 'S-G08',
    resultScreenId: 'S-G09',
    catalogueId: 'cat_sleep_sonar',
    title: 'Overnight sleep check',
    shortTitle: 'Sleep check',
    recordTitle: 'Overnight sleep sonar & apnoea screen',
    algorithmIds: ['ALG-AUD-07', 'ALG-AUD-08'],
    conditionCode: 'COND_OSA',
    featureId: 'F-21',
    requiredGates: [GateId.g04, GateId.g12, GateId.g30],
    optionalGates: [GateId.g32],
    purpose:
        'While you sleep, the phone sends inaudible sound pulses and listens for the echo from your chest. From the echo it follows your breathing all night, counts pauses in breathing, and estimates how many pauses happen per hour (the apnoea–hypopnoea index). Nothing touches you.',
    whoFor:
        'Adults who snore, wake up tired, stop breathing in their sleep according to a partner, or have high blood pressure, diabetes or a large neck. Not for children. A home sleep test or sleep-lab study confirms the result.',
    whatYouDo: [
      SleepStep(
        SleepIllustration.bedsideTable,
        'Phone flat on the bedside table, plugged in',
      ),
      SleepStep(SleepIllustration.sleeper, 'Sleep as usual, 4 hours or more'),
      SleepStep(
        SleepIllustration.longPressStop,
        'Long-press Stop when you wake',
      ),
    ],
    measures: [
      'ALG-AUD-07 Sleep sonar: 18–20 kHz chirps from the speaker, echo tracked in the 48 kHz microphone stream → breathing wave and SONAR_RR (br/min) per 30-s epoch. Epochs with no echo (rolled > 1 m away, blanket over the phone) are invalid and excluded from VALID_SLEEP_H.',
      'ALG-AUD-08 Sleep apnoea: apnoea = breathing amplitude drop ≥ 90 % for ≥ 10 s; hypopnoea = drop ≥ 30 % for ≥ 10 s ending in a snore / gasp (or a ≥ 3 % SpO2 dip when a ring is worn) → AHI_EST = events ÷ VALID_SLEEP_H; OSA_BAND < 5 normal · 5–14 mild · 15–29 moderate · ≥ 30 severe.',
      'VALID_SLEEP_H ≥ 4.0 h is required for the apnoea estimate; a shorter night reports SONAR_RR only (E-AUD-003).',
      'Chest-motion tracking uses the echo amplitude envelope rather than FMCW phase demodulation [DER]; thresholds are the document\'s.',
    ],
    markerMeanings: {
      'SONAR_RR':
          'Your breathing rate while asleep, averaged over the night from the chest echo. 12–20 breaths per minute is the normal range.',
      'APNOEA_EVENTS':
          'Times your breathing almost stopped (≥ 90 % smaller breaths) for 10 seconds or more.',
      'HYPOPNOEA_EVENTS':
          'Times your breathing became much shallower (≥ 30 % smaller) for 10 seconds or more and ended with a snore or gasp.',
      'AHI_EST':
          'Apnoea–hypopnoea index: pauses and shallow spells per hour of valid sleep. Under 5 is normal.',
      'OSA_BAND':
          'Severity band from the AHI: normal, mild, moderate or severe. Moderate and severe deserve a sleep test.',
      'VALID_SLEEP_H':
          'Hours of the night where the echo was clear enough to follow your breathing. At least 4 are needed for the apnoea estimate.',
    },
    needs: [
      SleepNeedTile(
        SleepIllustration.bedsideTable,
        'Bedside table',
        'Flat surface 0.3–1 m from your chest',
      ),
      SleepNeedTile(
        SleepIllustration.charger,
        'Charger',
        'Plugged in all night (G-30)',
      ),
      SleepNeedTile(
        SleepIllustration.noEarphones,
        'Speaker free',
        'No earphones · media volume up',
      ),
    ],
    prepareChecklist: [
      SleepPrepareItem(
        SleepIllustration.bedsideTable,
        'Phone flat on the bedside table, screen up, nothing on top of it',
      ),
      SleepPrepareItem(
        SleepIllustration.distance,
        'Between 30 cm and 1 m from your chest, with a clear line to you (no blanket or pillow in between)',
      ),
      SleepPrepareItem(
        SleepIllustration.charger,
        'Charger plugged in and staying in all night',
      ),
      SleepPrepareItem(
        SleepIllustration.noEarphones,
        'No earphones or Bluetooth speaker connected — the phone\'s own speaker sends the pulses',
      ),
      SleepPrepareItem(
        SleepIllustration.doNotDisturb,
        'Do-not-disturb on so calls and alerts do not interrupt the night',
      ),
    ],
    setupHint:
        'If you share the bed, place the phone on your side; the echo follows the nearest chest. Pets and fans in the room are fine; a second person within 1 m may blend into the reading.',
    howTo: [
      SleepHowToStep(
        SleepIllustration.bedsideTable,
        'Place the phone',
        'Lie down as you will sleep. Put the phone flat on the bedside table, screen up, 30 cm to 1 m from your chest, plugged into the charger.',
      ),
      SleepHowToStep(
        SleepIllustration.sonarWaves,
        'Start the night',
        'Tap "Start sleep monitoring". The screen goes dark and shows a clock. The pulses are above hearing range; a dog or a child may notice a faint hiss.',
      ),
      SleepHowToStep(
        SleepIllustration.nightClock,
        'Sleep as usual',
        'Leave the phone where it is. You can press the power button; monitoring keeps running and a notification stays in the shade. If the charger falls out, the screen warns you.',
      ),
      SleepHowToStep(
        SleepIllustration.longPressStop,
        'In the morning',
        'Tap the screen, then press and hold Stop for two seconds. After 4 hours or more of clear echo the report shows your apnoea index; a shorter night shows the breathing rate only.',
      ),
    ],
    whatToDo: [
      'Phone flat on the bedside table, plugged in, 30 cm to 1 m from your chest',
      'Sleep as usual for at least 4 hours',
      'In the morning, tap the screen and hold Stop for two seconds',
    ],
    voiceStart:
        'Sleep monitoring started. Leave the phone on the bedside table, plugged in. Good night.',
    voiceDone: 'Monitoring stopped. Analysing your night.',
    unpluggedWarning:
        'The charger is disconnected. Plug it back in so the phone lasts the night (G-30).',
    echoLostHint:
        'No chest echo — the phone may be too far, covered, or you rolled away. Those minutes are not counted.',
    shortNightCopy:
        'Insufficient valid sleep time (< 4 h) — please repeat overnight session. The breathing rate is shown; the apnoea index needs at least 4 hours of clear echo.',
    analysisStages: [
      'Checking each 30-s epoch for a clear chest echo',
      'Breathing rate per epoch (SONAR_RR)',
      'Finding breathing drops ≥ 90 % and ≥ 30 % lasting ≥ 10 s',
      'Counting apnoeas and hypopnoeas per valid hour (AHI_EST)',
      'Assigning the OSA band and checking the referral rule',
    ],
    referenceRows: [
      SleepReferenceRow('Sleep breathing rate', '12–20 br/min normal'),
      SleepReferenceRow(
        'OSA band',
        'AHI < 5 normal · 5–14 mild · 15–29 moderate · ≥ 30 severe',
      ),
      SleepReferenceRow('Apnoea', 'breathing amplitude drop ≥ 90 % for ≥ 10 s'),
      SleepReferenceRow(
        'Hypopnoea',
        'drop ≥ 30 % for ≥ 10 s + SpO2 dip ≥ 3 % (ring) or snore / gasp at the end',
      ),
      SleepReferenceRow('Valid sleep', '≥ 4.0 h for the apnoea estimate'),
      SleepReferenceRow(
        'Referral',
        'Moderate–severe → home sleep test or polysomnography ≤ 60 days (Routine)',
      ),
      SleepReferenceRow(
        'Echo validity',
        'epoch valid when echo ≥ floor + 6 dB and breathing peak ≥ 2.5 × spectrum median',
        provenance: 'DER',
      ),
      SleepReferenceRow(
        'Hypopnoea end',
        'snore / gasp = audible band ≥ baseline + 10 dB within 15 s',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'Bands follow the AASM grading named in the algorithm document (ALG-AUD-08). The sonar breathing wave is estimated from the echo amplitude [DER]; the study AUD-OSA-01 (vs polysomnography, 150 people) has not been run, so the result carries the "In clinical validation" badge (G-24).',
    resultTitle: 'Sleep report',
    durationLabel: 'Overnight · 4 h or more',
    whatYouGet: [
      'Your breathing rate while asleep, epoch by epoch',
      'How many times breathing paused or became shallow, and per hour',
      'An OSA band with the next step from the algorithm document',
      'Hours of valid sleep the estimate rests on',
    ],
    howWorkedOut: [
      'The speaker sends inaudible 18–20 kHz pulses; the microphone records the room at 48 kHz. Your chest moving changes the echo, and that change is the breathing wave (ALG-AUD-07).',
      'Every 30 seconds the app checks the echo is clear and reads the breathing rate from the strongest rhythm between 6 and 42 breaths per minute. Unclear epochs are dropped from the valid hours.',
      'Breath size is compared with the previous minute. A drop of 90 % or more for 10 seconds counts as an apnoea; a drop of 30 % or more for 10 seconds that ends in a snore or gasp counts as a hypopnoea (ALG-AUD-08).',
      'AHI = (apnoeas + hypopnoeas) ÷ valid hours, only when valid hours ≥ 4. Band: < 5 normal, 5–14 mild, 15–29 moderate, ≥ 30 severe.',
      'Moderate or severe opens a COND_OSA case with a Routine referral for a home sleep test or polysomnography (§13.2).',
    ],
  );
}
