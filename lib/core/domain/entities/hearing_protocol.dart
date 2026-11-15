// Hearing-screen protocols (Doc 09 §8 ALG-AUD-09, Doc 05 S-G10/S-G11,
// Doc 07 F-22, gates G-18 / G-19). Data only — the intro, capture and
// result screens read all copy, pictures, gates and reference rows from
// these records, exactly like the movement and vision protocols.
import 'enums.dart';

/// Mode A pure-tone staircase, or Mode B digits-in-noise (document fallback
/// for uncalibrated earphones).
enum HearingMode { pureTone, digitsInNoise }

enum HearingEar {
  right('Right', 'R'),
  left('Left', 'L');

  const HearingEar(this.label, this.suffix);
  final String label;
  final String suffix;
  HearingEar get other =>
      this == HearingEar.left ? HearingEar.right : HearingEar.left;
}

/// Static stand-in outcomes for Test Controls / FLUTTER_TEST.
enum HearingDemoOutcome { normal, borderline, refer }

/// Every drawing the hearing screens can show (see
/// `lib/features/hearing/hearing_illustrations.dart`).
enum HearingIllustration {
  earphonesIn,
  bothEars,
  volumeMax,
  quietRoom,
  tapWhenBeep,
  earLeft,
  earRight,
  digitsKeypad,
  noiseWaves,
  phoneOnTable,
  earphoneUnplugged,
  micCheck,
}

class HearingStep {
  const HearingStep(this.illustration, this.caption);
  final HearingIllustration illustration;
  final String caption;
}

class HearingHowToStep {
  const HearingHowToStep(this.illustration, this.title, this.body);
  final HearingIllustration illustration;
  final String title;
  final String body;
}

class HearingNeedTile {
  const HearingNeedTile(this.illustration, this.title, this.sub);
  final HearingIllustration illustration;
  final String title;
  final String sub;
}

class HearingPrepareItem {
  const HearingPrepareItem(this.illustration, this.text);
  final HearingIllustration illustration;
  final String text;
}

/// A row on the reference card. 'DOC' = in the algorithm document, 'DER' =
/// research / derived reference.
class HearingReferenceRow {
  const HearingReferenceRow(this.label, this.value, {this.provenance = 'DOC'});
  final String label;
  final String value;
  final String provenance;
}

class HearingProtocol {
  const HearingProtocol({
    required this.id,
    required this.mode,
    required this.title,
    required this.shortTitle,
    required this.recordTitle,
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
    required this.referenceRows,
    required this.referenceNote,
    required this.durationLabel,
    this.screenId = 'S-G10',
    this.resultScreenId = 'S-G11',
    this.catalogueId = 'cat_hearing',
    this.algorithmId = 'ALG-AUD-09',
    this.conditionCode = 'COND_HEARING_LOSS',
    this.featureId = 'F-22',
    this.algorithmVersion = 'v0.9.0',
    this.rangeVersion = 'mst_ref_2026.10',
    this.requiredGates = const [GateId.g04, GateId.g12, GateId.g18, GateId.g19],
    this.setupHint = '',
    this.referenceTitle = 'How to read it',
    this.resultTitle = 'Hearing result',
  });

  final String id;
  final HearingMode mode;
  final String screenId;
  final String resultScreenId;
  final String catalogueId;
  final String title;
  final String shortTitle;
  final String recordTitle;
  final String algorithmId;
  final String conditionCode;
  final String featureId;
  final String algorithmVersion;
  final String rangeVersion;
  final List<GateId> requiredGates;
  final String purpose;
  final List<HearingStep> whatYouDo;
  final List<String> measures;
  final Map<String, String> markerMeanings;
  final List<HearingNeedTile> needs;
  final List<HearingPrepareItem> prepareChecklist;
  final String setupHint;
  final List<HearingHowToStep> howTo;
  final String voiceStart;
  final String voiceSwitch;
  final String voiceDone;
  final List<String> analysisStages;
  final String referenceTitle;
  final List<HearingReferenceRow> referenceRows;
  final String referenceNote;
  final String resultTitle;
  final String durationLabel;

  /// Right ear then left ear (pure tone only).
  bool get perEar => mode == HearingMode.pureTone;

  String get plainSensorLine => switch (mode) {
    HearingMode.pureTone =>
      'Plays soft beeps through your earphones and checks the room noise',
    HearingMode.digitsInNoise =>
      'Plays spoken numbers in noise through your earphones',
  };

  String get sensorSummary => switch (mode) {
    HearingMode.pureTone =>
      'Earphones (G-19) · room ≤ 45 dBA (G-18, CAP-12) · 0.5/1/2/4 kHz each ear · up 5 / down 10 dB',
    HearingMode.digitsInNoise =>
      'Earphones (G-19) · room ≤ 45 dBA (G-18) · 23 digit triplets · adaptive SNR',
  };

  /// Headline for the live Test screen.
  String get runHeadline => switch (mode) {
    HearingMode.pureTone => 'Tap when you hear a beep',
    HearingMode.digitsInNoise => 'Type the three numbers you heard',
  };
}

class HearingProtocols {
  HearingProtocols._();

  static const List<HearingProtocol> all = [pureTone, digitsInNoise];

  /// S-G10 (test) and S-G11 (result) both open the pure-tone intro; the
  /// member can switch to digits-in-noise there.
  static HearingProtocol? forScreenId(String screenId) =>
      screenId == 'S-G10' || screenId == 'S-G11' ? pureTone : null;

  static HearingProtocol? forId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ── Mode A · pure-tone staircase ────────────────────────────────────────
  static const HearingProtocol pureTone = HearingProtocol(
    id: 'hear_pure_tone',
    mode: HearingMode.pureTone,
    title: 'Hearing check',
    shortTitle: 'Hearing',
    recordTitle: 'Pure-Tone Hearing Screen',
    durationLabel: 'about 3 min',
    purpose:
        'You listen for soft beeps at four pitches in each ear and tap each time you hear one. The quietest beep you can hear at each pitch is your hearing threshold, graded against the WHO line (20 dB).',
    whatYouDo: [
      HearingStep(HearingIllustration.earphonesIn, 'Earphones in, volume up'),
      HearingStep(HearingIllustration.quietRoom, 'Quiet-room check'),
      HearingStep(HearingIllustration.tapWhenBeep, 'Tap when you hear a beep'),
    ],
    measures: [
      'Hearing threshold at 0.5, 1, 2 and 4 kHz in each ear (HEAR_R_500…4000, HEAR_L_500…4000, dB HL, 5 dB steps)',
      'Hughson–Westlake staircase: down 10 dB when heard, up 5 dB when missed; threshold = level heard on 2 of 3 rising runs',
      'Pure-tone average (PTA4) per ear and the WHO 2021 grade of the better ear (HEARING_BAND)',
      'Silent catch trials count false taps; room noise is watched throughout (G-18)',
    ],
    markerMeanings: {
      'HEAR_R_1000':
          'The softest beep you heard at that pitch, in decibels of hearing level. 0–19 dB HL is normal hearing; higher numbers mean louder beeps were needed.',
      'HEARING_BAND':
          'The WHO 2021 grade of your better ear from the average of the four pitches: normal (< 20), mild (20–34), moderate (35–49) or severe (50 and above).',
      'DIN_SRT_DB':
          'Only measured in the digits-in-noise mode: how much louder than the noise the numbers had to be for you to get half of them right.',
    },
    needs: [
      HearingNeedTile(
        HearingIllustration.earphonesIn,
        'Earphones',
        'Wired or Bluetooth, in both ears (G-19)',
      ),
      HearingNeedTile(
        HearingIllustration.quietRoom,
        'Quiet room',
        'Below 45 dBA — no TV, fan or traffic (G-18)',
      ),
      HearingNeedTile(
        HearingIllustration.volumeMax,
        'Volume at maximum',
        'Set automatically on Android',
      ),
    ],
    prepareChecklist: [
      HearingPrepareItem(
        HearingIllustration.earphonesIn,
        'Earphones are in both ears — the red or "R" side in the right ear',
      ),
      HearingPrepareItem(
        HearingIllustration.volumeMax,
        'Phone volume is at maximum and no music or video app is playing',
      ),
      HearingPrepareItem(
        HearingIllustration.quietRoom,
        'The room is quiet: TV, fan and music off, door closed',
      ),
      HearingPrepareItem(
        HearingIllustration.phoneOnTable,
        'I am sitting comfortably and will not talk during the test',
      ),
    ],
    setupHint:
        'The beeps get very soft on purpose. Tap even when you are only fairly sure — a few silent trials check for guessing.',
    howTo: [
      HearingHowToStep(
        HearingIllustration.tapWhenBeep,
        'Tap the big button when you hear a beep',
        'Beeps come at random moments, some loud and some very faint. Tap as soon as you hear one, even if it is barely there.',
      ),
      HearingHowToStep(
        HearingIllustration.earRight,
        'Right ear first, then left',
        'Each ear is tested at four pitches. The app tells you when to switch; keep both earphones in the whole time.',
      ),
      HearingHowToStep(
        HearingIllustration.earphoneUnplugged,
        'The test pauses if something is wrong',
        'If an earphone disconnects or the room gets loud, the beeps stop and a message tells you what to fix. You carry on from the same place.',
      ),
    ],
    voiceStart:
        'Right ear first. Tap the button every time you hear a beep, even a faint one.',
    voiceSwitch: 'Now the left ear. Tap every time you hear a beep.',
    voiceDone: 'Done. Analysing your hearing thresholds.',
    analysisStages: [
      'Checking the silent catch trials',
      'Thresholds at 0.5, 1, 2 and 4 kHz per ear',
      'Pure-tone average and WHO 2021 grade',
      'Better-ear band and personal baseline',
    ],
    referenceRows: [
      HearingReferenceRow(
        'Normal',
        'All thresholds < 20 dB HL — WHO 2021 grading, better ear (Spec §8)',
      ),
      HearingReferenceRow(
        'Staircase',
        'Up 5 dB on a miss, down 10 dB on a hit (Spec §8 AUD-09)',
      ),
      HearingReferenceRow(
        'Room and earphones',
        'Room ≤ 45 dBA (G-18, CAP-12); earphones connected (G-19); unplug or noise pauses the test (E-AUD-004)',
      ),
      HearingReferenceRow(
        'Confirmation',
        'Hearing loss ≥ 20 dB HL in the better ear → pure-tone audiometry, tympanometry, ENT exam; routine (Spec §13.2)',
      ),
      HearingReferenceRow(
        'Validation target',
        'Sensitivity ≥ 80 % for ≥ 35 dB HL loss vs sound-booth audiometry (study AUD-HEAR-01)',
      ),
      HearingReferenceRow(
        'WHO grades',
        'Mild 20–34 · moderate 35–49 · severe ≥ 50 dB HL (better-ear PTA4; grades not listed in the Spec)',
        provenance: 'DER',
      ),
      HearingReferenceRow(
        'Earphone level',
        'Full-scale tone at maximum volume assumed = 90 dB HL (calibration table pending, OQ-REQ-15); enter a clinic 1 kHz threshold to calibrate',
        provenance: 'DER',
      ),
      HearingReferenceRow(
        'Staircase details',
        'Start 40 dB HL, 2-of-3 rising-run rule, 0–80 dB HL range, 1-in-6 silent catch trials',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'Phone earphones are not calibrated like clinic headphones, so the dB HL values are approximate. A loss found here is confirmed with pure-tone audiometry in a sound booth.',
  );

  // ── Mode B · digits in noise ────────────────────────────────────────────
  static const HearingProtocol digitsInNoise = HearingProtocol(
    id: 'hear_digits_in_noise',
    mode: HearingMode.digitsInNoise,
    title: 'Hearing check · digits in noise',
    shortTitle: 'Digits in noise',
    recordTitle: 'Digits-in-Noise Hearing Screen',
    durationLabel: 'about 2 min',
    purpose:
        'You hear three spoken numbers inside a rushing noise and type them. The noise gets harder when you are right and easier when you are wrong, until the app finds the level where you get half of them right — your speech reception threshold.',
    whatYouDo: [
      HearingStep(HearingIllustration.earphonesIn, 'Earphones in, volume up'),
      HearingStep(HearingIllustration.noiseWaves, 'Listen for three numbers'),
      HearingStep(HearingIllustration.digitsKeypad, 'Type what you heard'),
    ],
    measures: [
      'Speech reception threshold in noise (DIN_SRT_DB, dB SNR, 1 decimal): mean signal-to-noise ratio of triplets 4–23',
      'Adaptive staircase: 23 triplets, start 0 dB SNR, 2 dB step down on a fully correct triplet, 2 dB up otherwise',
      'Works with any earphones — no level calibration needed (document fallback mode)',
    ],
    markerMeanings: {
      'DIN_SRT_DB':
          'How much louder (or softer, when negative) than the noise the numbers had to be for you to get half of them right. Lower is better. No cut-off is set in the document yet, so the value builds your own baseline.',
      'HEARING_BAND':
          'Not graded in this mode — the WHO grade needs pure-tone thresholds.',
    },
    needs: [
      HearingNeedTile(
        HearingIllustration.earphonesIn,
        'Earphones',
        'Any kind, in both ears (G-19)',
      ),
      HearingNeedTile(
        HearingIllustration.quietRoom,
        'Quiet room',
        'Below 45 dBA (G-18)',
      ),
      HearingNeedTile(
        HearingIllustration.volumeMax,
        'Comfortable volume',
        'Loud enough to hear the noise clearly',
      ),
    ],
    prepareChecklist: [
      HearingPrepareItem(
        HearingIllustration.earphonesIn,
        'Earphones are in both ears',
      ),
      HearingPrepareItem(
        HearingIllustration.volumeMax,
        'Volume is comfortable and no other app is playing sound',
      ),
      HearingPrepareItem(
        HearingIllustration.quietRoom,
        'The room is quiet: TV, fan and music off',
      ),
    ],
    setupHint:
        'Guess when you are unsure — every triplet needs three digits. The noise is meant to make it hard.',
    howTo: [
      HearingHowToStep(
        HearingIllustration.noiseWaves,
        'Listen for three numbers in the noise',
        'A rushing noise plays, then a voice says three numbers, for example "4 – 9 – 1".',
      ),
      HearingHowToStep(
        HearingIllustration.digitsKeypad,
        'Type the three numbers, then Next',
        'Use the keypad in the order you heard them. If you missed one, guess. There are 23 rounds.',
      ),
      HearingHowToStep(
        HearingIllustration.earphoneUnplugged,
        'The test pauses if something is wrong',
        'If an earphone disconnects or the room gets loud, the sound stops and a message tells you what to fix.',
      ),
    ],
    voiceStart:
        'Listen for three numbers in the noise, then type them. Twenty-three rounds.',
    voiceSwitch: '',
    voiceDone: 'Done. Analysing your speech-in-noise threshold.',
    analysisStages: [
      'Checking the 23 triplets',
      'Tracking the signal-to-noise staircase',
      'Speech reception threshold (mean of rounds 4–23)',
      'Personal baseline',
    ],
    referenceRows: [
      HearingReferenceRow(
        'Normal',
        'Below the normative cut-off — value not yet provided in the Spec (OQ-FEA-01)',
      ),
      HearingReferenceRow(
        'Mode',
        'Digits-in-noise fallback for uncalibrated earphones (Spec §8 AUD-09)',
      ),
      HearingReferenceRow(
        'Room and earphones',
        'Room ≤ 45 dBA (G-18); earphones connected (G-19)',
      ),
      HearingReferenceRow(
        'Staircase',
        '23 triplets, start 0 dB SNR, ±2 dB steps, SRT = mean SNR of rounds 4–23 (hearWHO-style)',
        provenance: 'DER',
      ),
      HearingReferenceRow(
        'Speech level',
        'Spoken digits use the phone voice at a fixed level relative to the noise; SNR is therefore app-relative',
        provenance: 'DER',
      ),
    ],
    referenceNote:
        'The document gives no cut-off for this mode yet, so the number is shown without a band and compared with your own earlier results.',
  );
}
