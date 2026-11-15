// Breathing & Voice protocols (Doc 09 §8 ALG-AUD-01..06 + §5 ALG-FRM-13;
// Doc 05 S-G01..S-G06; Doc 07 F-19 / F-20). Data only — the intro, capture
// and result screens read all copy, pictures, gates, tasks and reference
// rows from these records, exactly like the Brain & Mind protocols.
import 'enums.dart';

enum BreathKind { coughTb, airway, lungFunction, voice }

enum BreathTaskType {
  /// One answer card per item (Q_TB_SYMPTOMS, Q_MMRC, Q_EXPOSURE).
  questionnaire,

  /// Voluntary coughs with a live valid-cough counter (AUD-01).
  cough,

  /// Sustained "aaa" / "sss" / "zzz" or a fixed sentence (AUD-06).
  phonation,

  /// Quiet / deep breathing through the mouth for the wheeze detector
  /// (AUD-04).
  breathSounds,

  /// Forced exhalation at arm's length (AUD-05).
  forcedExhale,
}

/// What the member phonates in a [BreathTaskType.phonation] task.
enum PhonationKind { aaa, sss, zzz, sentence }

/// Static stand-in outcomes for Test Controls / FLUTTER_TEST.
enum BreathDemoOutcome { normal, borderline, refer }

/// Every drawing the breathing screens can show (see
/// `lib/features/breath/breath_illustrations.dart`).
enum BreathIllustration {
  phoneAtArm,
  coughCircle,
  sayAaa,
  saySss,
  sayZzz,
  readSentence,
  deepBreaths,
  blowHard,
  micSweep,
  quietRoom,
  questionnaire,
  tbSymptoms,
  lungs,
  noSmoke,
  bodyProfile,
  clinician,
  micLevel,
  xray,
}

class BreathStep {
  const BreathStep(this.illustration, this.caption);
  final BreathIllustration illustration;
  final String caption;
}

class BreathHowToStep {
  const BreathHowToStep(this.illustration, this.title, this.body);
  final BreathIllustration illustration;
  final String title;
  final String body;
}

class BreathNeedTile {
  const BreathNeedTile(this.illustration, this.title, this.sub);
  final BreathIllustration illustration;
  final String title;
  final String sub;
}

class BreathPrepareItem {
  const BreathPrepareItem(this.illustration, this.text);
  final BreathIllustration illustration;
  final String text;
}

class BreathReferenceRow {
  const BreathReferenceRow(this.label, this.value, {this.provenance = 'DOC'});
  final String label;
  final String value;
  final String provenance;
}

/// One questionnaire item; the answer is the index into [options].
class BreathQuestion {
  const BreathQuestion(this.id, this.text, this.options, {this.help = ''});
  final String id;
  final String text;
  final List<String> options;
  final String help;
}

class BreathQuestionnaire {
  const BreathQuestionnaire({
    required this.id,
    required this.title,
    required this.stem,
    required this.questions,
  });
  final String id;
  final String title;
  final String stem;
  final List<BreathQuestion> questions;
}

/// Plain-language brief shown (and read aloud) right before a task.
class BreathTaskBrief {
  const BreathTaskBrief({
    required this.whatToDo,
    required this.listensFor,
    required this.stopsWhen,
  });

  /// Two or three short steps.
  final List<String> whatToDo;

  /// What the phone is listening for.
  final String listensFor;

  /// When the task ends.
  final String stopsWhen;

  String get spoken => '${whatToDo.join('. ')}.';
}

class BreathTask {
  const BreathTask({
    required this.id,
    required this.type,
    required this.title,
    required this.instruction,
    this.seconds = 15,
    this.minSeconds = 3,
    this.attempts = 3,
    this.efforts = 1,
    this.maxEfforts = 1,
    this.questionnaire,
    this.phonation,
    this.illustration,
    this.voiceLine = '',
    this.brief,
  });

  final String id;
  final BreathTaskType type;
  final String title;
  final String instruction;

  /// Recording window (cough / breath sounds / phonation ceiling / one
  /// exhale).
  final int seconds;

  /// Minimum content before the task counts (phonation ≥ 3 s, blow ≥ 3 s).
  final int minSeconds;

  /// Retries allowed after a failed validation (E-AUD-001: 3 attempts).
  final int attempts;

  /// Forced exhale: efforts required (3) and the ceiling when not
  /// repeatable (5, Spec §8 AUD-05).
  final int efforts;
  final int maxEfforts;
  final BreathQuestionnaire? questionnaire;
  final PhonationKind? phonation;
  final BreathIllustration? illustration;

  /// Spoken before the task starts (voice coach).
  final String voiceLine;

  /// Steps / listens-for / stops-when card before the task.
  final BreathTaskBrief? brief;
}

class BreathProtocol {
  const BreathProtocol({
    required this.id,
    required this.kind,
    required this.screenId,
    required this.resultScreenId,
    required this.catalogueId,
    required this.title,
    required this.shortTitle,
    required this.recordTitle,
    required this.algorithmIds,
    required this.conditionCode,
    required this.featureId,
    required this.requiredGates,
    required this.purpose,
    required this.whoFor,
    required this.whatYouDo,
    required this.measures,
    required this.markerMeanings,
    required this.needs,
    required this.prepareChecklist,
    required this.howTo,
    required this.tasks,
    required this.voiceStart,
    required this.voiceDone,
    required this.analysisStages,
    required this.referenceRows,
    required this.referenceNote,
    required this.resultTitle,
    required this.durationLabel,
    required this.whatYouGet,
    required this.howWorkedOut,
    this.setupHint = '',
    this.retryNote = '',
    this.algorithmVersion = 'v0.9.0',
    this.rangeVersion = 'mst_ref_2026.10',
    this.needsBodyProfile = false,
    this.referenceTitle = 'How to read it',
  });

  final String id;
  final BreathKind kind;
  final String screenId;
  final String resultScreenId;
  final String catalogueId;
  final String title;
  final String shortTitle;
  final String recordTitle;
  final List<String> algorithmIds;

  /// Condition the result can open a case for; empty for voice quality
  /// (the document names no COND_* for AUD-06).
  final String conditionCode;
  final String featureId;
  final List<GateId> requiredGates;
  final String purpose;
  final String whoFor;
  final List<BreathStep> whatYouDo;
  final List<String> measures;
  final Map<String, String> markerMeanings;
  final List<BreathNeedTile> needs;
  final List<BreathPrepareItem> prepareChecklist;
  final String setupHint;
  final String retryNote;
  final List<BreathHowToStep> howTo;
  final List<BreathTask> tasks;
  final String voiceStart;
  final String voiceDone;
  final List<String> analysisStages;
  final String referenceTitle;
  final List<BreathReferenceRow> referenceRows;
  final String referenceNote;
  final String resultTitle;
  final String durationLabel;
  final List<String> whatYouGet;
  final List<String> howWorkedOut;
  final String algorithmVersion;
  final String rangeVersion;

  /// Height, age and sex needed for % predicted (G-02, FRM-13).
  final bool needsBodyProfile;

  String get algorithmId => algorithmIds.first;
  String get algorithmLabel => algorithmIds.length == 1
      ? algorithmIds.first
      : '${algorithmIds.first}..${algorithmIds.last.split('-').last}';

  bool get hasCondition => conditionCode.isNotEmpty;

  String get plainSensorLine => switch (kind) {
    BreathKind.coughTb => 'Five questions, then three coughs into the phone',
    BreathKind.airway =>
      'Questions, coughs, a held "aaa", deep breaths and one hard blow',
    BreathKind.lungFunction => 'Three hard, fast blows at arm\'s length',
    BreathKind.voice => 'Hold "aaa", "sss" and "zzz", then read a sentence',
  };

  String get sensorSummary => switch (kind) {
    BreathKind.coughTb =>
      '≥ 3 valid coughs (AUD-01) + Q_TB_SYMPTOMS → TB_PROB / TB_BAND (AUD-03) · mic ≤ 6 dB (G-17) · room ≤ 45 dBA (G-18) · clip ≤ 1 %, SNR ≥ 15 dB (G-21)',
    BreathKind.airway =>
      'Coughs, "aaa", breath sounds (wheeze ≥ 100 ms), forced exhale + Q_MMRC / Q_EXPOSURE → OAD_PROB / OAD_BAND / ASTHMA_VS_COPD_PROB (AUD-04)',
    BreathKind.lungFunction =>
      '3 forced exhalations at ~30 cm, best of 3 within 10 % → FEV1, FVC, FEV1/FVC, PEF (AUD-05) · % predicted and RATIO_LLN (FRM-13, G-02)',
    BreathKind.voice =>
      '"aaa" ≥ 3 s (middle 3 s), "sss", "zzz", sentence → F0, jitter, shimmer, HNR, CPPS, MPT, s/z (AUD-06)',
  };
}

/// Questionnaire wording — the document marks the item lists OPEN
/// (OQ-REQ-14, Q-QUEST); these follow the WHO four-symptom TB screen, the
/// standard mMRC 0–4 scale and a short smoke / biomass / dust exposure
/// history [DER].
class BreathTexts {
  BreathTexts._();

  static const List<String> yesNo = ['No', 'Yes'];

  static const BreathQuestionnaire tbSymptoms = BreathQuestionnaire(
    id: 'Q_TB_SYMPTOMS',
    title: 'TB symptoms',
    stem: 'In the last few weeks, have you had…',
    questions: [
      BreathQuestion(
        'tb_cough2w',
        'A cough lasting 2 weeks or more?',
        yesNo,
        help: 'Any cough, with or without phlegm',
      ),
      BreathQuestion('tb_fever', 'Fever, on most days?', yesNo),
      BreathQuestion(
        'tb_sweats',
        'Sweating at night so the clothes or bed get wet?',
        yesNo,
      ),
      BreathQuestion(
        'tb_weight',
        'Losing weight without trying?',
        yesNo,
        help: 'Clothes feel loose, or the scale shows a drop',
      ),
      BreathQuestion(
        'tb_blood',
        'Blood in the phlegm when coughing?',
        yesNo,
        help: 'Even a streak of blood counts',
      ),
    ],
  );

  static const BreathQuestionnaire mmrc = BreathQuestionnaire(
    id: 'Q_MMRC',
    title: 'Breathlessness (mMRC)',
    stem: 'Which sentence fits you best?',
    questions: [
      BreathQuestion('mmrc', 'How breathless do you get?', [
        'Only with hard exercise',
        'Hurrying on flat ground or walking up a slight hill',
        'Walk slower than people my age on the flat, or must stop for breath at my own pace',
        'Stop for breath after about 100 m or a few minutes on the flat',
        'Too breathless to leave the house, or breathless when dressing',
      ]),
    ],
  );

  static const BreathQuestionnaire exposure = BreathQuestionnaire(
    id: 'Q_EXPOSURE',
    title: 'Smoke & dust exposure',
    stem: 'Tell us about smoke and dust in your life.',
    questions: [
      BreathQuestion('exp_smoke', 'Do you smoke (cigarettes, beedi, hookah)?', [
        'Never',
        'Used to, stopped',
        'Yes, currently',
      ]),
      BreathQuestion('exp_years', 'For how many years in total?', [
        'Never smoked',
        'Less than 10 years',
        '10 to 20 years',
        'More than 20 years',
      ]),
      BreathQuestion(
        'exp_biomass',
        'Is cooking or heating at home done with wood, dung, coal or kerosene?',
        yesNo,
        help: 'Biomass smoke indoors',
      ),
      BreathQuestion(
        'exp_dust',
        'Do you breathe dust, fumes or chemicals at work?',
        yesNo,
        help: 'Mining, construction, farming, factories, welding',
      ),
    ],
  );

  /// Fixed reading sentence for the voice task (document text pending)
  /// [DER]: all voiced sounds, no plosives, so pitch tracking stays
  /// continuous.
  static const String voiceSentence = 'We were away a year ago.';

  static String phonationLabel(PhonationKind k) => switch (k) {
    PhonationKind.aaa => 'aaa',
    PhonationKind.sss => 'sss',
    PhonationKind.zzz => 'zzz',
    PhonationKind.sentence => voiceSentence,
  };
}

class BreathProtocols {
  BreathProtocols._();

  static const List<BreathProtocol> all = [
    coughTb,
    airway,
    lungFunction,
    voice,
  ];

  static BreathProtocol? forScreenId(String screenId) => switch (screenId) {
    'S-G01' || 'S-G03' || 'S-G06' => coughTb,
    'S-G02' => airway,
    'S-G04' => voice,
    'S-G05' => lungFunction,
    _ => null,
  };

  static BreathProtocol? forCatalogueId(String id) {
    for (final p in all) {
      if (p.catalogueId == id) return p;
    }
    return null;
  }

  static BreathProtocol? forId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static const List<BreathPrepareItem> _audioChecklist = [
    BreathPrepareItem(
      BreathIllustration.quietRoom,
      'The room is quiet: TV, fan and music off',
    ),
    BreathPrepareItem(
      BreathIllustration.phoneAtArm,
      'I will hold the phone at arm\'s length (about 30 cm), screen facing me',
    ),
    BreathPrepareItem(
      BreathIllustration.micLevel,
      'Nothing covers the microphone — no case flap, no finger, no mask',
    ),
  ];

  // ── 1. Cough & TB priority screen (AUD-01..03, S-G02 / S-G03) ───────────
  static const BreathProtocol coughTb = BreathProtocol(
    id: 'breath_cough_tb',
    kind: BreathKind.coughTb,
    screenId: 'S-G03',
    resultScreenId: 'S-G06',
    catalogueId: 'cat_aud_tb',
    title: 'Cough & TB check',
    shortTitle: 'Cough & TB',
    recordTitle: 'Cough & TB Priority Screen',
    algorithmIds: ['ALG-AUD-01', 'ALG-AUD-03'],
    conditionCode: 'COND_TB',
    featureId: 'F-20',
    requiredGates: [GateId.g04, GateId.g12, GateId.g17, GateId.g18],
    durationLabel: 'about 2 min',
    purpose:
        'Five yes / no questions about cough, fever, night sweats, weight loss and blood in the phlegm, then three coughs into the phone. The app counts the valid coughs and, together with your answers, decides whether a sputum test and chest X-ray should be arranged quickly.',
    whoFor:
        'Anyone with a cough, or anyone in a TB screening drive. A high result is not a diagnosis: it means the sputum test (CBNAAT / TrueNat) and a chest X-ray should happen within two weeks. People already on TB treatment should tell the clinic instead.',
    whatYouDo: [
      BreathStep(BreathIllustration.tbSymptoms, '5 yes / no questions'),
      BreathStep(BreathIllustration.coughCircle, 'Cough 3 times'),
      BreathStep(BreathIllustration.xray, 'High → sputum test + X-ray'),
    ],
    measures: [
      'COUGH_COUNT_VALID — cough events 150–800 ms with probability ≥ 0.5; the task needs ≥ 3 (AUD-01)',
      'TB_PROB 0–1 and TB_BAND low / high from cough acoustics + Q_TB_SYMPTOMS (AUD-03); the number is not member-facing until validated (G-24)',
      'High band or classic TB symptoms → BR-SCR-02 Urgent (T15): sputum NAAT + chest X-ray within 14 days (Spec §13.2)',
    ],
    markerMeanings: {
      'COUGH_COUNT_VALID':
          'How many of your coughs were clear enough to analyse. Three are needed; the app asks you to cough again if fewer were heard.',
      'TB_BAND':
          'Low or high. High means the sputum test and chest X-ray should be arranged urgently; it is a priority flag, not a diagnosis.',
      'TB_PROB':
          'The model\'s 0–1 score. The document keeps the number internal until the TB study (AUD-TB-01) is complete; only the band is shown.',
    },
    needs: [
      BreathNeedTile(
        BreathIllustration.quietRoom,
        'Quiet room',
        'Below 45 dBA (G-18)',
      ),
      BreathNeedTile(
        BreathIllustration.phoneAtArm,
        'Phone at arm\'s length',
        'About 30 cm from the mouth',
      ),
      BreathNeedTile(
        BreathIllustration.micSweep,
        'Microphone check',
        'A short test sound (G-17)',
      ),
    ],
    prepareChecklist: _audioChecklist,
    setupHint:
        'Cough as you normally would — not forced, not held back. Cover your mouth with your elbow if you are unwell; the phone stays at arm\'s length.',
    retryNote:
        'If fewer than 3 clear coughs are heard the task repeats, up to 3 attempts (E-AUD-001). After that the questions alone decide the referral.',
    howTo: [
      BreathHowToStep(
        BreathIllustration.tbSymptoms,
        'Answer five questions',
        'Each asks about the last few weeks: a cough of 2 weeks or more, fever, night sweats, weight loss, blood in the phlegm. Tap Yes or No.',
      ),
      BreathHowToStep(
        BreathIllustration.coughCircle,
        'Cough when the circle turns green',
        'Hold the phone at arm\'s length. When the circle is green, cough naturally three times, with a short pause between coughs. The counter shows each cough the phone accepted.',
      ),
      BreathHowToStep(
        BreathIllustration.micLevel,
        'Watch the level bars',
        'If the bars go red the sound is clipping: hold the phone a little further away. If a cough is not counted, it was too short, too long or too soft — just cough again.',
      ),
    ],
    tasks: [
      BreathTask(
        id: 'q_tb',
        type: BreathTaskType.questionnaire,
        title: 'TB symptoms',
        instruction: 'Five questions about the last few weeks.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Read each question about the last few weeks',
            'Tap Yes or No — there are five',
            'Use Back if you want to change an answer',
          ],
          listensFor: 'Nothing yet — the microphone starts with the coughs',
          stopsWhen: 'After the fifth answer',
        ),
        questionnaire: BreathTexts.tbSymptoms,
        illustration: BreathIllustration.tbSymptoms,
      ),
      BreathTask(
        id: 'cough',
        type: BreathTaskType.cough,
        title: 'Three coughs',
        instruction: 'Cough naturally three times when the circle is green.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Hold the phone at arm\'s length, screen towards you',
            'Wait for the circle to turn green',
            'Cough three times, a short pause between coughs — do not speak',
          ],
          listensFor:
              'Sudden loud bursts of 0.15–0.8 s; words and throat-clearing do not count',
          stopsWhen: 'After 3 clear coughs and a moment of quiet, or at 15 s',
        ),
        seconds: 15,
        attempts: 3,
        illustration: BreathIllustration.coughCircle,
        voiceLine:
            'Hold the phone at arm\'s length. When the circle turns green, cough three times, with a short pause between each cough.',
      ),
    ],
    voiceStart:
        'Five questions about the last few weeks. Tap Yes or No for each one.',
    voiceDone: 'Done. Counting your coughs.',
    analysisStages: [
      'Audio quality: clipping ≤ 1 %, SNR ≥ 15 dB (CAP-13)',
      'Cough events 150–800 ms (AUD-01)',
      'Cough acoustics: wetness, length, onset',
      'Symptom rule and TB band (AUD-03)',
      'Referral rule BR-SCR-02',
    ],
    referenceRows: [
      BreathReferenceRow(
        'Valid cough',
        'Event 150–800 ms with detector probability ≥ 0.5; task passes at ≥ 3 valid coughs (Spec §8 AUD-01)',
      ),
      BreathReferenceRow('Normal', 'TB_BAND = low (Spec §8 AUD-03)'),
      BreathReferenceRow(
        'Urgent',
        'High TB risk or classic TB symptoms → BR-SCR-02; sputum NAAT (CBNAAT / TrueNat) + chest X-ray ≤ 14 days (Spec §8, §13.2, T15)',
      ),
      BreathReferenceRow(
        'Validation target',
        'Sensitivity ≥ 90 % (WHO triage target), study AUD-TB-01 (500 presumptive TB patients)',
      ),
      BreathReferenceRow(
        'Fallback',
        'If audio fails after 3 attempts the symptom-only rule decides the referral (Spec §8 AUD-03)',
      ),
      BreathReferenceRow(
        'Symptom rule',
        'Cough ≥ 2 weeks or blood in phlegm, or any two of fever / night sweats / weight loss → classic symptoms (WHO four-symptom screen; document items OPEN)',
        provenance: 'DER',
      ),
      BreathReferenceRow(
        'Cough detector',
        'Energy-onset event detector with duration and spectral checks stands in for the log-mel CNN until the model ships',
        provenance: 'DER',
      ),
      BreathReferenceRow(
        'TB score',
        'Cough wetness, length and symptom count combined 0–1; the document sets the threshold on the validation set (≥ 90 % sensitivity)',
        provenance: 'DER',
      ),
    ],
    whatYouGet: [
      'COUGH_COUNT_VALID: how many clear coughs the phone accepted (needs 3).',
      'TB_BAND: low or high. High opens an urgent case for a sputum test and chest X-ray within 14 days.',
      'Your five answers, kept with the result so the clinic sees the symptoms too.',
      'The 0–1 probability stays internal until the TB study is complete (G-24).',
    ],
    howWorkedOut: [
      'Each cough is found as a sudden loud burst: a rise of 12 dB or more within 30 ms, lasting 150–800 ms, with the harsh, high-pitched spectrum of a cough rather than a hum or a word.',
      'From the accepted coughs the app measures wetness (low-frequency energy in the tail), length and how sharp the onset was.',
      'Classic symptoms — a cough of 2 weeks or more, blood in the phlegm, or two of fever, night sweats and weight loss — set the band to high on their own.',
      'Otherwise the acoustic features and symptom count form a 0–1 score; 0.50 or more is high [DER stand-in until the trained model or partner API (Swaasa) is connected].',
      'High → BR-SCR-02 Urgent: sputum NAAT and chest X-ray. Low → no referral from this check.',
    ],
    referenceNote:
        'A low band does not rule TB out. If the cough continues beyond two weeks, or you cough blood, see a clinic regardless of this result.',
    resultTitle: 'Cough & TB result',
  );

  // ── 2. Airway obstruction (AUD-04, S-G02..S-G05) ────────────────────────
  static const BreathProtocol airway = BreathProtocol(
    id: 'breath_airway',
    kind: BreathKind.airway,
    screenId: 'S-G02',
    resultScreenId: 'S-G06',
    catalogueId: 'cat_aud_oad',
    title: 'Airway check (COPD / asthma)',
    shortTitle: 'Airway',
    recordTitle: 'Airway Obstruction (COPD / Asthma) Screen',
    algorithmIds: ['ALG-AUD-04'],
    conditionCode: 'COND_OAD',
    featureId: 'F-20',
    requiredGates: [GateId.g04, GateId.g12, GateId.g17, GateId.g18],
    durationLabel: 'about 4 min',
    purpose:
        'Two short questionnaires (how breathless you get, and smoke or dust exposure), then four sounds: three coughs, a held "aaa", four deep breaths and one hard blow. The app listens for wheeze and for a slow, long exhale — the signs of narrowed airways in COPD or asthma.',
    whoFor:
        'Adults who get breathless, wheeze, cough for weeks, or have smoked or cooked over wood smoke. A moderate or high band is confirmed with spirometry before and after an inhaler at a clinic.',
    whatYouDo: [
      BreathStep(BreathIllustration.questionnaire, 'Breathlessness + exposure'),
      BreathStep(BreathIllustration.deepBreaths, 'Coughs, "aaa", deep breaths'),
      BreathStep(BreathIllustration.blowHard, 'One hard blow'),
    ],
    measures: [
      'OAD_PROB 0–1 and OAD_BAND low / moderate / high — coughs, sustained vowel, breath sounds (wheeze ≥ 100 ms), forced exhale + Q_MMRC + Q_EXPOSURE (AUD-04)',
      'ASTHMA_VS_COPD_PROB 0–1 — which of the two is more likely (display policy OPEN in the document)',
      'FEV1/FVC from the exhale against RATIO_LLN (AUD-05 / FRM-13) as an input feature',
      'Moderate / high → COND_OAD routine: pre- and post-bronchodilator spirometry, CBC with eosinophils, chest X-ray (Spec §13.2)',
    ],
    markerMeanings: {
      'OAD_BAND':
          'Low, moderate or high likelihood of narrowed airways. Moderate or high means a clinic spirometry test should confirm it.',
      'OAD_PROB':
          'The 0–1 score behind the band. Shown as "in validation" until study AUD-OAD-01 is complete.',
      'ASTHMA_VS_COPD_PROB':
          'Above 0.5 leans towards asthma (wheeze, younger, less smoke exposure); below leans towards COPD. The document has not fixed how to display it.',
    },
    needs: [
      BreathNeedTile(
        BreathIllustration.quietRoom,
        'Quiet room',
        'Below 45 dBA (G-18)',
      ),
      BreathNeedTile(
        BreathIllustration.phoneAtArm,
        'Phone at arm\'s length',
        'About 30 cm from the mouth',
      ),
      BreathNeedTile(
        BreathIllustration.noSmoke,
        'No inhaler for 4 h',
        'If you use one, note it',
      ),
    ],
    prepareChecklist: [
      ..._audioChecklist,
      BreathPrepareItem(
        BreathIllustration.noSmoke,
        'I have not smoked or used an inhaler in the last hour (note it if you have)',
      ),
    ],
    setupHint:
        'Sit upright. Breathe through your mouth for the breathing step so the phone can hear the air moving.',
    retryNote:
        'The document needs at least coughs, one exhale and the questionnaires for a result; skipped sounds lower the confidence.',
    howTo: [
      BreathHowToStep(
        BreathIllustration.questionnaire,
        'Two short questionnaires',
        'First choose the sentence that best describes your breathlessness (mMRC 0–4). Then four questions about smoking, years smoked, cooking smoke and dust at work.',
      ),
      BreathHowToStep(
        BreathIllustration.coughCircle,
        'Cough, then hold "aaa"',
        'Cough three times when the circle is green. Then take a breath and say "aaa" steadily for about 8 seconds.',
      ),
      BreathHowToStep(
        BreathIllustration.deepBreaths,
        'Breathe deeply with the ring',
        'Breathe in through your mouth as the ring grows and out as it shrinks, four times. The app listens for a whistling (wheeze) sound.',
      ),
      BreathHowToStep(
        BreathIllustration.blowHard,
        'One hard, fast blow',
        'Take the deepest breath you can, then blow out as hard and fast as possible until your lungs feel empty — at least 3 seconds.',
      ),
    ],
    tasks: [
      BreathTask(
        id: 'q_mmrc',
        type: BreathTaskType.questionnaire,
        title: 'Breathlessness',
        instruction: 'Choose the sentence that fits you best.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Read the five sentences about breathlessness',
            'Tap the one that fits your usual days best',
          ],
          listensFor: 'Nothing yet — this is a question (mMRC 0–4)',
          stopsWhen: 'After your answer',
        ),
        questionnaire: BreathTexts.mmrc,
        illustration: BreathIllustration.questionnaire,
      ),
      BreathTask(
        id: 'q_exposure',
        type: BreathTaskType.questionnaire,
        title: 'Smoke & dust',
        instruction: 'Four questions about smoke and dust.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Answer four questions: smoking, years, cooking smoke, dust at work',
            'Be honest — the answers only shape the airway score',
          ],
          listensFor: 'Nothing yet — these are questions',
          stopsWhen: 'After the fourth answer',
        ),
        questionnaire: BreathTexts.exposure,
        illustration: BreathIllustration.noSmoke,
      ),
      BreathTask(
        id: 'cough',
        type: BreathTaskType.cough,
        title: 'Three coughs',
        instruction: 'Cough naturally three times when the circle is green.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Hold the phone at arm\'s length, screen towards you',
            'Wait for the circle to turn green',
            'Cough three times, a short pause between coughs — do not speak',
          ],
          listensFor:
              'Sudden loud bursts of 0.15–0.8 s; words and throat-clearing do not count',
          stopsWhen: 'After 3 clear coughs and a moment of quiet, or at 15 s',
        ),
        seconds: 15,
        attempts: 3,
        illustration: BreathIllustration.coughCircle,
        voiceLine:
            'Hold the phone at arm\'s length. When the circle turns green, cough three times.',
      ),
      BreathTask(
        id: 'aaa',
        type: BreathTaskType.phonation,
        title: 'Say "aaa"',
        instruction:
            'Take a breath and say "aaa" steadily until the bar fills.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Take a comfortable breath',
            'Say "aaa" at a normal pitch and loudness',
            'Keep it steady until the bar is full (about 8 s)',
          ],
          listensFor: 'A steady voice — pitch, jitter, shimmer, harmonics',
          stopsWhen: 'After 1 s of silence once you stop, or at 8 s',
        ),
        seconds: 8,
        minSeconds: 3,
        phonation: PhonationKind.aaa,
        illustration: BreathIllustration.sayAaa,
        voiceLine:
            'Take a deep breath and say aaa, steadily, until the bar is full.',
      ),
      BreathTask(
        id: 'breath',
        type: BreathTaskType.breathSounds,
        title: 'Deep breaths',
        instruction:
            'Breathe deeply in and out through your mouth with the ring, four times.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Open your mouth and breathe through it, not the nose',
            'Breathe in as the ring grows, out as it shrinks',
            'Four deep breaths, phone at arm\'s length',
          ],
          listensFor:
              'A whistling tone (wheeze) lasting 100 ms or more inside your breathing',
          stopsWhen: 'After 16 s (four breaths)',
        ),
        seconds: 16,
        illustration: BreathIllustration.deepBreaths,
        voiceLine:
            'Breathe in through your mouth as the ring grows, and out as it shrinks. Four breaths.',
      ),
      BreathTask(
        id: 'exhale',
        type: BreathTaskType.forcedExhale,
        title: 'Hard blow',
        instruction:
            'Deepest breath in, then blow out as hard and fast as you can until empty.',
        seconds: 10,
        minSeconds: 3,
        efforts: 1,
        maxEfforts: 3,
        brief: BreathTaskBrief(
          whatToDo: [
            'Phone at arm\'s length, microphone towards your mouth',
            'On "3, 2, 1" take the deepest breath you can',
            'On "Blow!" blast the air out hard and fast until empty — at least 3 s',
          ],
          listensFor: 'How fast the sound falls in the first second (FEV1/FVC)',
          stopsWhen: 'When the air stops, or at 10 s',
        ),
        illustration: BreathIllustration.blowHard,
        voiceLine:
            'Take the deepest breath you can. When I say blow, blow out as hard and fast as possible until your lungs are empty.',
      ),
    ],
    voiceStart: 'Choose the sentence that best describes your breathlessness.',
    voiceDone: 'Done. Listening for wheeze and measuring the blow.',
    analysisStages: [
      'Audio quality per task (CAP-13)',
      'Cough events and wetness (AUD-01)',
      'Wheeze: tonal peaks lasting ≥ 100 ms',
      'Exhale shape: FEV1/FVC vs lower limit of normal',
      'Questionnaires: mMRC and exposure',
      'Obstruction score and asthma-vs-COPD (AUD-04)',
    ],
    referenceRows: [
      BreathReferenceRow('Normal', 'OAD_BAND = low (Spec §8 AUD-04)'),
      BreathReferenceRow(
        'Wheeze',
        'Continuous tonal spectral peak lasting ≥ 100 ms (Spec §8 AUD-04)',
      ),
      BreathReferenceRow(
        'Minimum inputs',
        'Coughs + forced exhale + questionnaires; voice and breath sounds improve the estimate (Spec §8 AUD-04)',
      ),
      BreathReferenceRow(
        'Confirmation',
        'Routine: spirometry before and after bronchodilator, CBC with eosinophils, chest X-ray · FEV1/FVC < 0.70 or < LLN post-bronchodilator = obstruction; reversibility ≥ 12 % and ≥ 200 mL suggests asthma · pairing ≤ 14 days (Spec §13.2)',
      ),
      BreathReferenceRow(
        'Validation target',
        'Sensitivity ≥ 80 % and specificity ≥ 80 %, study AUD-OAD-01 (300 participants, ≥ 100 confirmed obstruction)',
      ),
      BreathReferenceRow(
        'Band cut-offs',
        'OAD_PROB < 0.33 low · 0.33–0.66 moderate · ≥ 0.66 high (document values pending)',
        provenance: 'DER',
      ),
      BreathReferenceRow(
        'Score',
        'Wheeze share, exhale ratio vs LLN, mMRC grade, exposure and cough wetness combined 0–1 stand in for the gradient-boosting + CNN model',
        provenance: 'DER',
      ),
      BreathReferenceRow(
        'Questionnaires',
        'Standard mMRC 0–4 wording and a 4-item exposure history (document items OPEN, OQ-REQ-14)',
        provenance: 'DER',
      ),
    ],
    whatYouGet: [
      'OAD_BAND: low, moderate or high likelihood of narrowed airways, with the 0–1 score marked "in validation".',
      'ASTHMA_VS_COPD_PROB: which of the two the pattern leans towards.',
      'Wheeze: how much of your breathing had a whistling tone, and FEV1/FVC from your blow against the lower limit of normal.',
      'Your mMRC grade and exposure answers, kept with the result.',
    ],
    howWorkedOut: [
      'Wheeze: the breath-sound recording is split into 32 ms slices; a narrow tone between 150 and 1000 Hz that stays for 100 ms or more counts as wheeze. The share of breathing time with wheeze is the feature.',
      'Blow: the loudness curve of the forced exhale is a stand-in for airflow; the share of the sound in the first second against the whole blow approximates FEV1/FVC and is compared with your lower limit of normal (height, age, sex).',
      'Coughs give a wetness index; "aaa" gives the voice features of AUD-06.',
      'The mMRC grade (0–4) and the exposure answers (smoking, years, biomass, dust) are added as clinical features.',
      'All features form a 0–1 obstruction score; < 0.33 low, < 0.66 moderate, else high. Wheeze with little smoke exposure leans the asthma-vs-COPD score towards asthma [DER stand-in for the trained model].',
      'Moderate or high → routine case COND_OAD: clinic spirometry before and after an inhaler decides.',
    ],
    referenceNote:
        'Only clinic spirometry can diagnose COPD or asthma. A low band with ongoing breathlessness still deserves a clinic visit.',
    resultTitle: 'Airway check result',
  );

  // ── 3. Forced-exhale lung function (AUD-05 + FRM-13, S-G05) ─────────────
  static const BreathProtocol lungFunction = BreathProtocol(
    id: 'breath_lung_function',
    kind: BreathKind.lungFunction,
    screenId: 'S-G05',
    resultScreenId: 'S-G06',
    catalogueId: 'cat_aud_spirometry',
    title: 'Lung function (blow test)',
    shortTitle: 'Lung function',
    recordTitle: 'Forced Exhale Lung Function (SpiroSmart)',
    algorithmIds: ['ALG-AUD-05', 'ALG-FRM-13'],
    conditionCode: 'COND_OAD',
    featureId: 'F-20',
    requiredGates: [GateId.g02, GateId.g04, GateId.g12, GateId.g17, GateId.g18],
    needsBodyProfile: true,
    durationLabel: 'about 2 min',
    purpose:
        'Three hard, fast blows at arm\'s length. The phone records the sound of the air leaving your lungs and estimates FEV1, FVC, their ratio and peak flow, then compares them with what is expected for your height, age and sex.',
    whoFor:
        'Adults aged 18 and over with a complete profile (height, age, sex). Not during a chest infection or an asthma attack. The blow test is an estimate from sound; a clinic spirometer with a mouthpiece is the confirmatory test.',
    whatYouDo: [
      BreathStep(BreathIllustration.phoneAtArm, 'Phone at 30 cm'),
      BreathStep(BreathIllustration.blowHard, '3 hard blows'),
      BreathStep(BreathIllustration.lungs, 'FEV1, FVC, ratio, peak flow'),
    ],
    measures: [
      'FEV1_L, FVC_L, FEV1_FVC, PEF_LS from the best of 3 efforts; top two efforts must agree within 10 % (AUD-05, ATS/ERS repeatability)',
      'fev1_pred_pct, fvc_pred_pct and RATIO_LLN from height, age, sex (FRM-13 GLI-2012; G-02)',
      'Normal: FEV1/FVC ≥ RATIO_LLN; below → COND_OAD routine (Spec §8, §13.2)',
      'Blow < 3 s or repeatability > 10 % → coach a deeper breath and a harder blow, up to 5 blows (Spec §8, E-AUD-002)',
    ],
    markerMeanings: {
      'FEV1_L':
          'Litres of air blown out in the first second. Narrowed airways lower it most.',
      'FVC_L': 'Total litres blown out from a full breath to empty.',
      'FEV1_FVC':
          'The share of your air that comes out in the first second. Below your lower limit of normal suggests obstruction.',
      'PEF_LS': 'Peak flow, litres per second, at the very start of the blow.',
      'fev1_pred_pct':
          'Your FEV1 as a percentage of the value expected for your height, age and sex.',
      'ratio_lln':
          'The lowest FEV1/FVC still normal for someone like you (5th percentile).',
    },
    needs: [
      BreathNeedTile(
        BreathIllustration.bodyProfile,
        'Height, age, sex',
        'For % predicted (G-02)',
      ),
      BreathNeedTile(
        BreathIllustration.phoneAtArm,
        'Phone at 30 cm',
        'Straight arm, mic towards you',
      ),
      BreathNeedTile(
        BreathIllustration.quietRoom,
        'Quiet room',
        'Below 45 dBA (G-18)',
      ),
    ],
    prepareChecklist: [
      ..._audioChecklist,
      BreathPrepareItem(
        BreathIllustration.lungs,
        'I am sitting upright, loose clothing, nothing in my mouth',
      ),
    ],
    setupHint:
        'Blow like you are trying to blow out every candle on a cake in one go — hard at the start, then keep pushing until empty.',
    retryNote:
        'The best two of three blows must agree within 10 %. If not, the app asks for one more (up to 5). A blow shorter than 3 s is repeated.',
    howTo: [
      BreathHowToStep(
        BreathIllustration.phoneAtArm,
        'Arm straight, phone at 30 cm',
        'Hold the phone in your outstretched hand with the bottom microphone pointing at your mouth. Keep it there for every blow.',
      ),
      BreathHowToStep(
        BreathIllustration.blowHard,
        'Deepest breath, then BLOW',
        'When the countdown reaches "Blow!", blast the air out as hard and fast as you can, and keep pushing until nothing is left — at least 3 seconds, ideally 6.',
      ),
      BreathHowToStep(
        BreathIllustration.lungs,
        'Three blows, rest between',
        'Rest for 20–30 seconds between blows. Each blow gets a card with a tick; the app checks that the best two agree.',
      ),
    ],
    tasks: [
      BreathTask(
        id: 'exhale',
        type: BreathTaskType.forcedExhale,
        title: 'Hard blow',
        instruction:
            'Deepest breath in, then blow out as hard and fast as you can until empty.',
        seconds: 10,
        minSeconds: 3,
        efforts: 3,
        maxEfforts: 5,
        brief: BreathTaskBrief(
          whatToDo: [
            'Phone at arm\'s length, microphone towards your mouth',
            'On "3, 2, 1" take the deepest breath you can',
            'On "Blow!" blast the air out hard and fast until empty — at least 3 s; three blows with a 20 s rest between',
          ],
          listensFor:
              'The sound of the air: peak, first second and total (FEV1, FVC, PEF)',
          stopsWhen:
              'When the air stops, or at 10 s; the best two blows must agree within 10 %',
        ),
        illustration: BreathIllustration.blowHard,
        voiceLine:
            'Take the deepest breath you can. When I say blow, blow out as hard and fast as possible until your lungs are empty.',
      ),
    ],
    voiceStart:
        'Three hard blows. Hold the phone at arm\'s length and take the deepest breath you can.',
    voiceDone: 'Done. Working out your lung volumes.',
    analysisStages: [
      'Audio quality per blow (CAP-13)',
      'Exhale envelope: onset, peak, end (Hilbert proxy)',
      'FEV1, FVC, FEV1/FVC and PEF per effort',
      'Repeatability: best two within 10 %, best effort',
      'Predicted values and lower limit of normal (FRM-13)',
    ],
    referenceRows: [
      BreathReferenceRow(
        'Normal',
        'FEV1/FVC ≥ RATIO_LLN (Spec §8 AUD-05, §5 FRM-13)',
      ),
      BreathReferenceRow(
        'Repeatability',
        'Top two of 3 efforts within 10 %, best effort reported; else coach and blow again, up to 5 (Spec §8 AUD-05, E-AUD-002)',
      ),
      BreathReferenceRow(
        'Confirmation',
        'Routine: clinic spirometry (post-bronchodilator for obstruction) ≤ 14 days; not valid after an exacerbation or a new inhaler (Spec §13.2, §15)',
      ),
      BreathReferenceRow(
        'Validation target',
        'FEV1/FVC MAE ≤ 0.08 and FEV1 relative error ≤ 10 % vs ATS/ERS spirometer, study AUD-OAD-01',
      ),
      BreathReferenceRow(
        'Predicted values',
        'ECSC-1993 (Quanjer) adult equations with LLN = predicted − 1.645 × RSD stand in until the GLI-2012 coefficients are supplied (Doc 08 §12 "to be built")',
        provenance: 'DER',
      ),
      BreathReferenceRow(
        'Volume scale',
        'Uncalibrated: FVC = predicted FVC × a factor from blow length; FEV1/FVC from the first-second share of the sound envelope; PEF from the envelope peak',
        provenance: 'DER',
      ),
      BreathReferenceRow(
        'Age range',
        'Equations cover 18–70 years; outside that the values are shown with a warning',
        provenance: 'DER',
      ),
    ],
    whatYouGet: [
      'FEV1 and FVC in litres, their ratio and peak flow, from your best blow.',
      'Each as a percentage of what is expected for your height, age and sex, plus the lower limit of normal for the ratio.',
      'A tick per blow and whether the best two agreed within 10 %.',
      'Ratio below the lower limit → routine case for clinic spirometry.',
    ],
    howWorkedOut: [
      'The loudness curve of each blow (10 ms smoothing) stands in for airflow; its area is the volume proxy and its peak the peak-flow proxy (SpiroSmart method, AUD-05).',
      'FEV1/FVC = share of the curve\'s area in the first second. FVC = predicted FVC scaled by how long you kept blowing; FEV1 = ratio × FVC; PEF = predicted PEF scaled by the peak [DER — uncalibrated until the regression is trained on study AUD-OAD-01].',
      'Predicted values come from your height, age and sex (ECSC-1993 equations as the GLI-2012 stand-in); the lower limit of normal is predicted − 1.645 × the residual spread.',
      'The two best blows must agree within 10 % (ATS/ERS); the best one is reported.',
      'Ratio below the lower limit → routine case COND_OAD. Nothing is diagnosed from sound alone.',
    ],
    referenceNote:
        'Sound-based volumes are estimates. Clinic spirometry with a mouthpiece, before and after an inhaler, is the confirmatory test.',
    resultTitle: 'Lung function result',
  );

  // ── 4. Acoustic voice quality (AUD-06, S-G04) ───────────────────────────
  static const BreathProtocol voice = BreathProtocol(
    id: 'breath_voice',
    kind: BreathKind.voice,
    screenId: 'S-G04',
    resultScreenId: 'S-G06',
    catalogueId: 'cat_aud_voice',
    title: 'Voice quality check',
    shortTitle: 'Voice',
    recordTitle: 'Acoustic Voice Quality Analysis',
    algorithmIds: ['ALG-AUD-06'],
    conditionCode: '',
    featureId: 'F-20',
    requiredGates: [GateId.g04, GateId.g12, GateId.g17, GateId.g18],
    durationLabel: 'about 2 min',
    purpose:
        'Hold "aaa" for as long as you can, then "sss" and "zzz", then read one sentence. The app measures how steady your voice is — pitch, jitter, shimmer, harmonics-to-noise — and how long you can phonate.',
    whoFor:
        'Anyone with hoarseness, a tired voice, or as a baseline for later checks. The values also feed the airway, heart-failure voice and Parkinson\'s checks. There is no referral rule for voice in the document; a clinician reads the values.',
    whatYouDo: [
      BreathStep(BreathIllustration.sayAaa, 'Hold "aaa"'),
      BreathStep(BreathIllustration.saySss, '"sss" and "zzz"'),
      BreathStep(BreathIllustration.readSentence, 'Read a sentence'),
    ],
    measures: [
      'F0_HZ, JITTER_PCT, SHIMMER_PCT, HNR_DB, CPPS_DB from the middle 3 s of "aaa" (AUD-06, F0 tracked 75–500 Hz)',
      'MPT_S — longest continuous "aaa" phonation; SZ_RATIO — "sss" duration divided by "zzz" duration (AUD-06)',
      'Adult norms: jitter < 1.04 %, shimmer < 3.81 %, HNR > 20 dB, MPT ≥ 15 s, s/z < 1.4 (Spec §8)',
      'No COND_* code or referral rule in the document; values feed AUD-04, AUD-12 and MOV-13',
    ],
    markerMeanings: {
      'F0_HZ':
          'Your average speaking pitch. No normal range — it depends on sex, age and habit.',
      'JITTER_PCT':
          'Cycle-to-cycle wobble in pitch. Under 1.04 % is normal; higher can mean the vocal folds are not vibrating evenly.',
      'SHIMMER_PCT':
          'Cycle-to-cycle wobble in loudness. Under 3.81 % is normal.',
      'HNR_DB':
          'How much of the sound is clean harmonics rather than breathy noise. Above 20 dB is normal.',
      'CPPS_DB':
          'Cepstral peak prominence — a robust measure of how periodic the voice is. Higher is clearer; the document gives no cut-off.',
      'MPT_S':
          'How long you could hold "aaa" in one breath. 15 s or more is the adult norm.',
      'SZ_RATIO':
          '"sss" time divided by "zzz" time. Under 1.4 is normal; higher suggests the folds leak air when voicing.',
    },
    needs: [
      BreathNeedTile(
        BreathIllustration.quietRoom,
        'Quiet room',
        'Below 45 dBA (G-18)',
      ),
      BreathNeedTile(
        BreathIllustration.phoneAtArm,
        'Phone at arm\'s length',
        'Same distance for every sound',
      ),
      BreathNeedTile(
        BreathIllustration.sayAaa,
        'One big breath',
        'Hold each sound as long as you can',
      ),
    ],
    prepareChecklist: [
      ..._audioChecklist,
      BreathPrepareItem(
        BreathIllustration.sayAaa,
        'I have had a sip of water and will sit upright',
      ),
    ],
    setupHint:
        'Use a comfortable pitch and loudness — not a whisper, not a shout. Stop when you run out of air; the app notices the silence.',
    retryNote:
        'Each sound must last at least 3 seconds; the app asks you to hold it for at least 5 if it was shorter (Spec §8 AUD-06).',
    howTo: [
      BreathHowToStep(
        BreathIllustration.sayAaa,
        'Hold "aaa" as long as you can',
        'Take the deepest breath you can and say "aaa" at a comfortable pitch, steady and smooth, until you run out of air. The timer counts while the phone hears you.',
      ),
      BreathHowToStep(
        BreathIllustration.saySss,
        'Then "sss" and "zzz"',
        'Deep breath, then a long "sss" like a snake until empty. Deep breath again, then a long "zzz" like a bee. The app divides one time by the other.',
      ),
      BreathHowToStep(
        BreathIllustration.readSentence,
        'Read the sentence',
        'Read "We were away a year ago." at your normal pace and volume.',
      ),
    ],
    tasks: [
      BreathTask(
        id: 'aaa',
        type: BreathTaskType.phonation,
        title: 'Hold "aaa"',
        instruction:
            'Deep breath, then "aaa" steadily until you run out of air.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Take the deepest breath you can',
            'Say "aaa" at a comfortable pitch and loudness',
            'Hold it steady until you run out of air — the timer counts while it hears you',
          ],
          listensFor:
              'How long you hold it (MPT) and how steady it is: pitch, jitter, shimmer, HNR, CPPS',
          stopsWhen: 'After 1 s of silence once you stop, or at 30 s',
        ),
        seconds: 30,
        minSeconds: 3,
        phonation: PhonationKind.aaa,
        illustration: BreathIllustration.sayAaa,
        voiceLine:
            'Take the deepest breath you can, then say aaa, steady and smooth, for as long as you can.',
      ),
      BreathTask(
        id: 'sss',
        type: BreathTaskType.phonation,
        title: 'Hold "sss"',
        instruction: 'Deep breath, then "sss" like a snake until empty.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Take the deepest breath you can',
            'Hiss "sss" like a snake — a soft hiss is enough',
            'Keep going until you run out of air',
          ],
          listensFor: 'How long the hiss lasts (for the s/z ratio)',
          stopsWhen: 'After 1 s of silence once you stop, or at 30 s',
        ),
        seconds: 30,
        minSeconds: 2,
        phonation: PhonationKind.sss,
        illustration: BreathIllustration.saySss,
        voiceLine:
            'Deep breath, then sss, like a snake, for as long as you can.',
      ),
      BreathTask(
        id: 'zzz',
        type: BreathTaskType.phonation,
        title: 'Hold "zzz"',
        instruction: 'Deep breath, then "zzz" like a bee until empty.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Take the deepest breath you can',
            'Buzz "zzz" like a bee, with your voice on',
            'Keep going until you run out of air',
          ],
          listensFor: 'How long the buzz lasts (s/z = "sss" time ÷ "zzz" time)',
          stopsWhen: 'After 1 s of silence once you stop, or at 30 s',
        ),
        seconds: 30,
        minSeconds: 2,
        phonation: PhonationKind.zzz,
        illustration: BreathIllustration.sayZzz,
        voiceLine: 'Deep breath, then zzz, like a bee, for as long as you can.',
      ),
      BreathTask(
        id: 'sentence',
        type: BreathTaskType.phonation,
        title: 'Read the sentence',
        instruction: 'Read the sentence at your normal pace.',
        brief: BreathTaskBrief(
          whatToDo: [
            'Read the sentence on the screen once',
            'Normal pace and normal loudness',
          ],
          listensFor:
              'Pitch and rhythm in connected speech (kept for the clinician)',
          stopsWhen: 'A second after you finish, or at 8 s',
        ),
        seconds: 8,
        minSeconds: 1,
        phonation: PhonationKind.sentence,
        illustration: BreathIllustration.readSentence,
        voiceLine: 'Now read the sentence on the screen at your normal pace.',
      ),
    ],
    voiceStart:
        'Take the deepest breath you can, then say aaa, steady and smooth, for as long as you can.',
    voiceDone: 'Done. Measuring your voice.',
    analysisStages: [
      'Audio quality per sound (CAP-13)',
      'Longest "aaa" phonation → MPT',
      'Middle 3 s: pitch 75–500 Hz, jitter, shimmer, HNR',
      'Cepstral peak prominence (CPPS)',
      '"sss" / "zzz" durations → s/z ratio',
      'Compare with the adult norms',
    ],
    referenceRows: [
      BreathReferenceRow('Jitter', '< 1.04 % normal (adult, Spec §8 AUD-06)'),
      BreathReferenceRow('Shimmer', '< 3.81 % normal (Spec §8 AUD-06)'),
      BreathReferenceRow('HNR', '> 20 dB normal (Spec §8 AUD-06)'),
      BreathReferenceRow(
        'MPT',
        '≥ 15 s normal for adults; child norm not given (Spec §8 AUD-06)',
      ),
      BreathReferenceRow('s/z ratio', '< 1.4 normal (Spec §8 AUD-06)'),
      BreathReferenceRow(
        'F0 and CPPS',
        'Analysis range 75–500 Hz; no normal value in the document (OPEN)',
      ),
      BreathReferenceRow(
        'Validation target',
        'All 7 markers within ≤ 2 % of Praat on 50 recordings',
      ),
      BreathReferenceRow(
        'Method',
        'Autocorrelation pitch, local jitter / shimmer and autocorrelation HNR on 40 ms frames; CPPS from a 1024-point cepstrum with a regression line — an approximation of the Praat values',
        provenance: 'DER',
      ),
      BreathReferenceRow(
        'Sentence',
        'Fixed in-app sentence (document text pending)',
        provenance: 'DER',
      ),
    ],
    whatYouGet: [
      'F0: your average pitch in hertz.',
      'Jitter, shimmer and HNR from the steadiest 3 seconds of your "aaa", each against the adult norm.',
      'CPPS: a clarity measure with no cut-off yet.',
      'MPT: how long you held "aaa"; s/z: "sss" time divided by "zzz" time.',
      'No referral from this check: a clinician reads the values. They are kept as your baseline.',
    ],
    howWorkedOut: [
      'The phone finds the longest stretch of continuous voicing in your "aaa" — that is MPT — and analyses its middle 3 seconds.',
      'Pitch is tracked every 20 ms by autocorrelation between 75 and 500 Hz; jitter is the average change in period between neighbouring cycles, shimmer the average change in loudness, both as a percentage.',
      'HNR compares the periodic part of the signal with the rest; CPPS measures how sharp the peak of the cepstrum stands above its background [DER approximation of the Praat algorithms].',
      '"sss" and "zzz" are timed from the first sound to the last; the ratio shows whether voicing shortens the breath.',
      'Each value is compared with the document\'s adult norms; outside counts as borderline here, not as a diagnosis.',
    ],
    referenceNote:
        'A hoarse voice for more than three weeks deserves an ENT examination regardless of these numbers.',
    resultTitle: 'Voice quality result',
  );
}
