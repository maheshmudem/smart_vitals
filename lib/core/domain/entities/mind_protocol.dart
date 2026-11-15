// Brain & Mind protocols (Doc 09 §8 ALG-AUD-10 / 11 / 12, §9 ALG-MOV-06..09;
// Doc 05 S-G12..S-G15, S-H06; Doc 07 F-23..F-27). Data only — the intro,
// capture and result screens read all copy, pictures, gates, tasks and
// reference rows from these records, exactly like the hearing protocols.
import 'enums.dart';

enum MindKind { cognitive, mood, hfVoice, stroke }

/// Speech-recognition / sentence language (Spec §8 AUD-10: te / hi / en).
enum MindLanguage {
  en('English', 'en_IN', 'English'),
  hi('Hindi', 'hi_IN', 'हिन्दी'),
  te('Telugu', 'te_IN', 'తెలుగు');

  const MindLanguage(this.label, this.localeId, this.nativeLabel);
  final String label;
  final String localeId;
  final String nativeLabel;

  static MindLanguage fromCode(String code) => switch (code) {
    'hi' => MindLanguage.hi,
    'te' => MindLanguage.te,
    _ => MindLanguage.en,
  };
}

enum MindTaskType {
  /// One answer card per item (PHQ-9, GAD-7).
  questionnaire,

  /// Speech recognition with live words (animal naming, picture, stroke
  /// sentence).
  speechTranscribe,

  /// Plain recording analysed acoustically (mood free speech, HF sentence).
  speechRecord,

  /// Front camera: face at rest, then peak smile (MOV-06).
  faceSmile,

  /// Phone held in the outstretched hand, eyes closed, 10 s (MOV-07
  /// stand-in).
  armDrift,
}

/// Static stand-in outcomes for Test Controls / FLUTTER_TEST.
enum MindDemoOutcome { normal, borderline, refer, crisis }

/// Every drawing the mind screens can show (see
/// `lib/features/mind/mind_illustrations.dart`).
enum MindIllustration {
  speakToPhone,
  animals,
  parkScene,
  quietRoom,
  questionnaire,
  calmBreath,
  readSentence,
  smileCamera,
  armsOutEyesClosed,
  clock,
  callEmergency,
  supportHands,
  micLevel,
  calendar14,
  clinician,
  graduation,
}

class MindStep {
  const MindStep(this.illustration, this.caption);
  final MindIllustration illustration;
  final String caption;
}

class MindHowToStep {
  const MindHowToStep(this.illustration, this.title, this.body);
  final MindIllustration illustration;
  final String title;
  final String body;
}

class MindNeedTile {
  const MindNeedTile(this.illustration, this.title, this.sub);
  final MindIllustration illustration;
  final String title;
  final String sub;
}

class MindPrepareItem {
  const MindPrepareItem(this.illustration, this.text);
  final MindIllustration illustration;
  final String text;
}

class MindReferenceRow {
  const MindReferenceRow(this.label, this.value, {this.provenance = 'DOC'});
  final String label;
  final String value;
  final String provenance;
}

class MindQuestion {
  const MindQuestion(this.id, this.text);
  final String id;
  final String text;
}

class MindQuestionnaire {
  const MindQuestionnaire({
    required this.id,
    required this.title,
    required this.stem,
    required this.questions,
    required this.maxTotal,
    this.crisisItemId,
  });

  final String id;
  final String title;
  final String stem;
  final List<MindQuestion> questions;
  final int maxTotal;

  /// Item whose answer > 0 triggers the crisis screen (PHQ-9 item 9, G-37).
  final String? crisisItemId;

  static const List<String> options = [
    'Not at all',
    'Several days',
    'More than half the days',
    'Nearly every day',
  ];
}

class MindTask {
  const MindTask({
    required this.id,
    required this.type,
    required this.title,
    required this.instruction,
    this.seconds = 60,
    this.minSeconds = 5,
    this.questionnaire,
    this.sentenceKey,
    this.illustration,
    this.arm,
    this.scoringHint = '',
    this.whatToDo = const [],
  });

  final String id;
  final MindTaskType type;
  final String title;
  final String instruction;
  final int seconds;

  /// Short steps shown (and read aloud) on the card before the task.
  final List<String> whatToDo;

  /// Minimum voiced seconds before "I'm done" is allowed.
  final int minSeconds;
  final MindQuestionnaire? questionnaire;

  /// Key into [MindTexts.sentences] (hfSentence / strokeSentence).
  final String? sentenceKey;
  final MindIllustration? illustration;

  /// 'right' | 'left' for arm drift.
  final String? arm;
  final String scoringHint;
}

class MindProtocol {
  const MindProtocol({
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
    this.setupHint = '',
    this.whatYouGet = const [],
    this.howWorkedOut = const [],
    this.languages = const [MindLanguage.en],
    this.algorithmVersion = 'v0.9.0',
    this.rangeVersion = 'mst_ref_2026.10',
    this.usesMicrophone = true,
    this.usesCamera = false,
    this.usesMotion = false,
    this.needsEducationYears = false,
    this.needsOnsetTime = false,
    this.dailyCheck = false,
    this.safetyCritical = false,
    this.referenceTitle = 'How to read it',
  });

  final String id;
  final MindKind kind;
  final String screenId;
  final String resultScreenId;
  final String catalogueId;
  final String title;
  final String shortTitle;
  final String recordTitle;
  final List<String> algorithmIds;
  final String conditionCode;
  final String featureId;
  final List<GateId> requiredGates;
  final String purpose;
  final List<MindStep> whatYouDo;
  final List<String> measures;
  final Map<String, String> markerMeanings;
  final List<MindNeedTile> needs;
  final List<MindPrepareItem> prepareChecklist;
  final String setupHint;

  /// Plain-language list of what the check gives you (How-to step).
  final List<String> whatYouGet;

  /// Plain-language list of how each value is worked out (result card).
  final List<String> howWorkedOut;
  final List<MindHowToStep> howTo;
  final List<MindTask> tasks;
  final String voiceStart;
  final String voiceDone;
  final List<String> analysisStages;
  final String referenceTitle;
  final List<MindReferenceRow> referenceRows;
  final String referenceNote;
  final String resultTitle;
  final String durationLabel;
  final List<MindLanguage> languages;
  final String algorithmVersion;
  final String rangeVersion;
  final bool usesMicrophone;
  final bool usesCamera;
  final bool usesMotion;
  final bool needsEducationYears;
  final bool needsOnsetTime;
  final bool dailyCheck;
  final bool safetyCritical;

  String get algorithmId => algorithmIds.first;
  String get algorithmLabel => algorithmIds.length == 1
      ? algorithmIds.first
      : '${algorithmIds.first}..${algorithmIds.last.split('-').last}';

  String get plainSensorLine => switch (kind) {
    MindKind.cognitive =>
      'Uses the microphone and speech recognition in your language',
    MindKind.mood => 'Questions on screen, then a one-minute recording',
    MindKind.hfVoice => 'Uses the microphone for a 30-second sentence',
    MindKind.stroke =>
      'Uses the front camera, the motion sensor and the microphone',
  };

  String get sensorSummary => switch (kind) {
    MindKind.cognitive =>
      'ASR te/hi/en · 60 s animal naming + picture description · room ≤ 45 dBA (G-18)',
    MindKind.mood =>
      'PHQ-9 + GAD-7 (0–3 per item) · 60 s free speech · G-07 pathway · G-37 crisis',
    MindKind.hfVoice =>
      '30 s fixed sentence · 14-day personal baseline (G-28) · daily (G-34)',
    MindKind.stroke =>
      'Face rest vs smile (MOV-06) · 10 s arm hold ×2 (MOV-07) · sentence repeat (MOV-08) · onset time',
  };
}

/// Fixed texts, word lists and scene units the tasks use [DER — the
/// document marks these assets OPEN].
class MindTexts {
  MindTexts._();

  static const Map<String, Map<MindLanguage, String>> sentences = {
    'hfSentence': {
      MindLanguage.en:
          'Every morning I open the window, breathe the cool air slowly, and count the birds on the mango tree.',
      MindLanguage.hi:
          'हर सुबह मैं खिड़की खोलता हूँ, ठंडी हवा को धीरे-धीरे साँस में लेता हूँ, और आम के पेड़ पर चिड़ियों को गिनता हूँ।',
      MindLanguage.te:
          'ప్రతి ఉదయం నేను కిటికీ తెరిచి, చల్లని గాలిని నెమ్మదిగా పీల్చి, మామిడి చెట్టు మీద పక్షులను లెక్కిస్తాను.',
    },
    'strokeSentence': {
      MindLanguage.en: 'The sky is blue and the grass is green today.',
      MindLanguage.hi: 'आज आसमान नीला है और घास हरी है।',
      MindLanguage.te: 'ఈ రోజు ఆకాశం నీలంగా ఉంది, గడ్డి పచ్చగా ఉంది.',
    },
  };

  static String sentence(String key, MindLanguage l) =>
      sentences[key]![l] ?? sentences[key]![MindLanguage.en]!;

  /// Valid animal names per language (singular; English plurals are
  /// stripped by the scorer). Transliterated English names count in every
  /// language because speech recognition often returns them.
  static const Map<MindLanguage, List<String>> animals = {
    MindLanguage.en: [
      'dog',
      'cat',
      'cow',
      'buffalo',
      'goat',
      'sheep',
      'horse',
      'donkey',
      'camel',
      'elephant',
      'lion',
      'tiger',
      'leopard',
      'cheetah',
      'bear',
      'monkey',
      'deer',
      'rabbit',
      'hare',
      'rat',
      'mouse',
      'fox',
      'wolf',
      'snake',
      'cobra',
      'fish',
      'frog',
      'tortoise',
      'turtle',
      'crocodile',
      'lizard',
      'parrot',
      'crow',
      'pigeon',
      'peacock',
      'hen',
      'chicken',
      'rooster',
      'duck',
      'owl',
      'eagle',
      'sparrow',
      'bee',
      'butterfly',
      'ant',
      'mosquito',
      'spider',
      'pig',
      'squirrel',
      'giraffe',
      'zebra',
      'rhinoceros',
      'rhino',
      'hippopotamus',
      'hippo',
      'kangaroo',
      'panda',
      'dolphin',
      'whale',
      'shark',
      'octopus',
      'crab',
      'prawn',
      'shrimp',
      'bull',
      'ox',
      'yak',
      'mongoose',
      'jackal',
      'hyena',
      'swan',
      'crane',
      'heron',
      'cuckoo',
      'bulbul',
      'myna',
      'vulture',
      'hawk',
      'kite',
      'goose',
      'turkey',
      'penguin',
      'ostrich',
      'bat',
      'hamster',
      'guinea pig',
      'gorilla',
      'chimpanzee',
      'orangutan',
      'koala',
      'lemur',
      'otter',
      'beaver',
      'seal',
      'walrus',
      'jellyfish',
      'starfish',
      'eel',
      'salmon',
      'tuna',
      'carp',
      'catfish',
      'lobster',
      'snail',
      'worm',
      'earthworm',
      'caterpillar',
      'moth',
      'beetle',
      'cockroach',
      'fly',
      'wasp',
      'grasshopper',
      'cricket',
      'scorpion',
      'chameleon',
      'iguana',
      'python',
      'viper',
      'alligator',
      'flamingo',
      'pelican',
      'woodpecker',
      'hummingbird',
      'robin',
      'dove',
      'quail',
      'partridge',
      'emu',
      'llama',
      'alpaca',
      'bison',
      'moose',
      'elk',
      'antelope',
      'gazelle',
      'boar',
      'hedgehog',
      'porcupine',
      'mole',
      'raccoon',
      'skunk',
      'weasel',
      'badger',
      'puppy',
      'kitten',
      'calf',
      'lamb',
      'cub',
      'kid',
    ],
    MindLanguage.hi: [
      'कुत्ता',
      'बिल्ली',
      'गाय',
      'भैंस',
      'बकरी',
      'भेड़',
      'घोड़ा',
      'गधा',
      'ऊँट',
      'ऊंट',
      'हाथी',
      'शेर',
      'बाघ',
      'चीता',
      'तेंदुआ',
      'भालू',
      'बंदर',
      'हिरण',
      'खरगोश',
      'चूहा',
      'लोमड़ी',
      'भेड़िया',
      'सांप',
      'साँप',
      'मछली',
      'मेंढक',
      'कछुआ',
      'मगरमच्छ',
      'छिपकली',
      'तोता',
      'कौआ',
      'कौवा',
      'कबूतर',
      'मोर',
      'मुर्गी',
      'मुर्गा',
      'बत्तख',
      'उल्लू',
      'चील',
      'गौरैया',
      'मधुमक्खी',
      'तितली',
      'चींटी',
      'मच्छर',
      'मकड़ी',
      'सुअर',
      'सूअर',
      'गिलहरी',
      'जिराफ',
      'जिराफ़',
      'ज़ेबरा',
      'जेबरा',
      'गैंडा',
      'दरियाई घोड़ा',
      'कंगारू',
      'पांडा',
      'डॉल्फिन',
      'व्हेल',
      'शार्क',
      'ऑक्टोपस',
      'केकड़ा',
      'झींगा',
      'बकरा',
      'बैल',
      'याक',
      'नेवला',
      'सियार',
      'गीदड़',
      'लकड़बग्घा',
      'हंस',
      'सारस',
      'बगुला',
      'कोयल',
      'बुलबुल',
      'मैना',
      'गिद्ध',
      'बाज',
      'बाज़',
      'पेंगुइन',
      'शुतुरमुर्ग',
      'चमगादड़',
      'गोरिल्ला',
      'ऊदबिलाव',
      'घोंघा',
      'केंचुआ',
      'तिलचट्टा',
      'मक्खी',
      'टिड्डा',
      'बिच्छू',
      'गिरगिट',
      'अजगर',
      'कबूतरी',
      'बटेर',
      'सांड',
      'साँड',
      'भेंस',
      'मेमना',
      'बछड़ा',
      'पिल्ला',
    ],
    MindLanguage.te: [
      'కుక్క',
      'పిల్లి',
      'ఆవు',
      'గేదె',
      'మేక',
      'గొర్రె',
      'గుర్రం',
      'గాడిద',
      'ఒంటె',
      'ఏనుగు',
      'సింహం',
      'పులి',
      'చిరుత',
      'ఎలుగుబంటి',
      'కోతి',
      'జింక',
      'కుందేలు',
      'ఎలుక',
      'నక్క',
      'తోడేలు',
      'పాము',
      'చేప',
      'కప్ప',
      'తాబేలు',
      'మొసలి',
      'బల్లి',
      'చిలుక',
      'కాకి',
      'పావురం',
      'నెమలి',
      'కోడి',
      'బాతు',
      'గుడ్లగూబ',
      'గద్ద',
      'పిచ్చుక',
      'తేనెటీగ',
      'సీతాకోకచిలుక',
      'చీమ',
      'దోమ',
      'సాలీడు',
      'పంది',
      'ఉడుత',
      'జిరాఫీ',
      'జీబ్రా',
      'ఖడ్గమృగం',
      'నీటి గుర్రం',
      'కంగారూ',
      'పాండా',
      'డాల్ఫిన్',
      'తిమింగలం',
      'సొరచేప',
      'పీత',
      'రొయ్య',
      'ఎద్దు',
      'ముంగిస',
      'హైనా',
      'హంస',
      'కొంగ',
      'కోకిల',
      'రాబందు',
      'డేగ',
      'పెంగ్విన్',
      'నిప్పుకోడి',
      'గబ్బిలం',
      'గొరిల్లా',
      'నత్త',
      'వానపాము',
      'బొద్దింక',
      'ఈగ',
      'మిడత',
      'తేలు',
      'ఊసరవెల్లి',
      'కొండచిలువ',
      'దున్న',
      'దూడ',
      'కుక్కపిల్ల',
    ],
  };

  /// Park-scene information units: each unit is a list of words (any
  /// language) that count as mentioning it.
  static const List<(String, List<String>)> parkUnits = [
    (
      'child',
      [
        'child',
        'boy',
        'girl',
        'kid',
        'बच्चा',
        'लड़का',
        'लड़की',
        'పిల్లవాడు',
        'పిల్ల',
        'అబ్బాయి',
        'అమ్మాయి',
      ],
    ),
    ('kite', ['kite', 'पतंग', 'గాలిపటం']),
    ('dog', ['dog', 'puppy', 'कुत्ता', 'కుక్క']),
    (
      'man reading',
      [
        'man',
        'reading',
        'book',
        'newspaper',
        'आदमी',
        'पढ़',
        'किताब',
        'अखबार',
        'అతను',
        'చదువు',
        'పుస్తకం',
        'పేపర్',
      ],
    ),
    ('bench', ['bench', 'seat', 'बेंच', 'बैठ', 'బెంచ్', 'కూర్చు']),
    (
      'woman watering',
      [
        'woman',
        'lady',
        'watering',
        'water',
        'can',
        'औरत',
        'महिला',
        'पानी',
        'స్త్రీ',
        'ఆమె',
        'నీళ్లు',
        'నీరు',
      ],
    ),
    (
      'flowers',
      [
        'flower',
        'flowers',
        'plant',
        'plants',
        'garden',
        'फूल',
        'पौध',
        'బగీచా',
        'పూలు',
        'పువ్వు',
        'మొక్క',
      ],
    ),
    ('pond', ['pond', 'lake', 'water', 'तालाब', 'झील', 'చెరువు', 'కొలను']),
    (
      'ducks',
      ['duck', 'ducks', 'birds', 'बत्तख', 'चिड़िया', 'బాతు', 'పక్షులు'],
    ),
    (
      'ice cream cart',
      [
        'ice',
        'cream',
        'cart',
        'vendor',
        'seller',
        'आइसक्रीम',
        'ठेला',
        'ఐస్',
        'క్రీం',
        'బండి',
      ],
    ),
    ('tree', ['tree', 'trees', 'पेड़', 'చెట్టు']),
    ('sun', ['sun', 'sunny', 'सूरज', 'धूप', 'సూర్యుడు', 'ఎండ']),
  ];

  static const MindQuestionnaire phq9 = MindQuestionnaire(
    id: 'PHQ9',
    title: 'PHQ-9',
    stem: 'Over the last 2 weeks, how often have you been bothered by…',
    maxTotal: 27,
    crisisItemId: 'phq9_9',
    questions: [
      MindQuestion('phq9_1', 'Little interest or pleasure in doing things'),
      MindQuestion('phq9_2', 'Feeling down, depressed, or hopeless'),
      MindQuestion(
        'phq9_3',
        'Trouble falling or staying asleep, or sleeping too much',
      ),
      MindQuestion('phq9_4', 'Feeling tired or having little energy'),
      MindQuestion('phq9_5', 'Poor appetite or overeating'),
      MindQuestion(
        'phq9_6',
        'Feeling bad about yourself — or that you are a failure or have let yourself or your family down',
      ),
      MindQuestion(
        'phq9_7',
        'Trouble concentrating on things, such as reading the newspaper or watching television',
      ),
      MindQuestion(
        'phq9_8',
        'Moving or speaking so slowly that other people could have noticed? Or the opposite — being so fidgety or restless that you have been moving around a lot more than usual',
      ),
      MindQuestion(
        'phq9_9',
        'Thoughts that you would be better off dead, or of hurting yourself in some way',
      ),
    ],
  );

  static const MindQuestionnaire gad7 = MindQuestionnaire(
    id: 'GAD7',
    title: 'GAD-7',
    stem: 'Over the last 2 weeks, how often have you been bothered by…',
    maxTotal: 21,
    questions: [
      MindQuestion('gad7_1', 'Feeling nervous, anxious, or on edge'),
      MindQuestion('gad7_2', 'Not being able to stop or control worrying'),
      MindQuestion('gad7_3', 'Worrying too much about different things'),
      MindQuestion('gad7_4', 'Trouble relaxing'),
      MindQuestion('gad7_5', 'Being so restless that it is hard to sit still'),
      MindQuestion('gad7_6', 'Becoming easily annoyed or irritable'),
      MindQuestion(
        'gad7_7',
        'Feeling afraid, as if something awful might happen',
      ),
    ],
  );
}

class MindProtocols {
  MindProtocols._();

  static const List<MindProtocol> all = [cognitive, mood, hfVoice, stroke];

  static MindProtocol? forScreenId(String screenId) => switch (screenId) {
    'S-G12' => cognitive,
    'S-G13' || 'S-G14' => mood,
    'S-G15' => hfVoice,
    'S-H06' => stroke,
    _ => null,
  };

  static MindProtocol? forId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ── 1. Cognitive speech (ALG-AUD-10, S-G12) ─────────────────────────────
  static const MindProtocol cognitive = MindProtocol(
    id: 'mind_cognitive',
    kind: MindKind.cognitive,
    screenId: 'S-G12',
    resultScreenId: 'S-R01',
    catalogueId: 'cat_cognitive',
    title: 'Memory & speech check',
    shortTitle: 'Cognitive speech',
    recordTitle: 'Cognitive Speech Screen',
    algorithmIds: ['ALG-AUD-10'],
    conditionCode: 'COND_COG',
    featureId: 'F-23',
    requiredGates: [GateId.g04, GateId.g09, GateId.g12, GateId.g17, GateId.g18],
    languages: [MindLanguage.en, MindLanguage.hi, MindLanguage.te],
    needsEducationYears: true,
    durationLabel: 'about 3 min',
    purpose:
        'Two short speaking tasks in your own language: name as many animals as you can in one minute, then describe a picture. The app counts your words, pauses and variety — a gentle first check of memory and thinking for people aged 50 and over.',
    whatYouDo: [
      MindStep(MindIllustration.animals, 'Name animals for 60 s'),
      MindStep(MindIllustration.parkScene, 'Describe a picture'),
      MindStep(MindIllustration.speakToPhone, 'Speak clearly to the phone'),
    ],
    measures: [
      'FLUENCY_COUNT — unique valid animal names in 60 s (repetitions and non-animals excluded)',
      'PAUSE_RATE — hesitations / silent pauses longer than 2 s, per minute',
      'SPEECH_RATE — words per minute · LEXICAL_DIV — type–token ratio 0–1 and picture information units',
      'COG_BAND — normal / refer, produced only once the classifier is released (G-24); norms are age- and education-stratified (pending)',
    ],
    markerMeanings: {
      'FLUENCY_COUNT':
          'How many different animals you named in one minute. Most healthy adults manage well over a dozen; the exact line depends on age and schooling, which the document is still collecting.',
      'PAUSE_RATE':
          'How often you paused for more than 2 seconds. Long, frequent pauses can be a sign of word-finding difficulty.',
      'SPEECH_RATE': 'Words per minute while describing the picture.',
      'LEXICAL_DIV':
          'Variety of words used (0–1). Repeating the same few words gives a low value.',
      'COG_BAND':
          'Normal or refer, once the classifier is validated against the clinician MoCA. Until then the values are shown without a band.',
    },
    needs: [
      MindNeedTile(
        MindIllustration.quietRoom,
        'Quiet room',
        'Below 45 dBA (G-18)',
      ),
      MindNeedTile(
        MindIllustration.graduation,
        'Years of schooling',
        'Used for the norms (0–30)',
      ),
      MindNeedTile(
        MindIllustration.speakToPhone,
        'Your language',
        'English, Hindi or Telugu',
      ),
    ],
    prepareChecklist: [
      MindPrepareItem(
        MindIllustration.quietRoom,
        'The room is quiet: TV, fan and music off',
      ),
      MindPrepareItem(
        MindIllustration.speakToPhone,
        'I will hold the phone about 20–30 cm from my mouth',
      ),
      MindPrepareItem(
        MindIllustration.calmBreath,
        'I am rested and not unwell today (acute illness affects the result)',
      ),
    ],
    setupHint:
        'There is no pass or fail today — say whatever comes to mind. The app only counts; a clinician interprets.',
    howTo: [
      MindHowToStep(
        MindIllustration.animals,
        'Name as many animals as you can',
        'When the timer starts, say animal names one after another for one minute — any animal, any size. Do not stop to think too long; keep going.',
      ),
      MindHowToStep(
        MindIllustration.parkScene,
        'Describe the picture',
        'A park scene appears. Tell the phone everything you see happening, in full sentences, for one minute.',
      ),
      MindHowToStep(
        MindIllustration.micLevel,
        'The bars show the phone hears you',
        'Speak at a normal volume. If the bars stay flat, move the phone closer. Tap "I\'m done" if you run out of things to say after 20 seconds.',
      ),
    ],
    tasks: [
      MindTask(
        id: 'fluency',
        type: MindTaskType.speechTranscribe,
        title: 'Animal naming',
        instruction: 'Say as many different animals as you can.',
        seconds: 60,
        minSeconds: 20,
        illustration: MindIllustration.animals,
        scoringHint: 'Unique animals counted live',
      ),
      MindTask(
        id: 'picture',
        type: MindTaskType.speechTranscribe,
        title: 'Picture description',
        instruction: 'Describe everything you see in the picture.',
        seconds: 60,
        minSeconds: 20,
        illustration: MindIllustration.parkScene,
        scoringHint: 'Words and details counted live',
      ),
    ],
    voiceStart:
        'Animal naming. When the timer starts, say as many different animals as you can for one minute.',
    voiceDone: 'Done. Analysing your speech.',
    analysisStages: [
      'Transcribing your speech',
      'Counting valid animal names and repetitions',
      'Measuring pauses, speech rate and word variety',
      'Information units in the picture description',
      'Age and education norms (pending)',
    ],
    referenceRows: [
      MindReferenceRow(
        'Who',
        'Adults aged 50 and over (G-09); years of education recorded (Spec §8)',
      ),
      MindReferenceRow(
        'Tasks',
        '60 s animal naming + picture description, speech recognition te / hi / en (Spec §8)',
      ),
      MindReferenceRow(
        'Norms',
        'Age- and education-stratified norms in mst_reference_range — to be built (Q-COHORT); values shown, band on release (G-24)',
      ),
      MindReferenceRow(
        'Confirmation',
        'Clinician MoCA; B12, folate, TSH, CBC, glucose, electrolytes, calcium; CT or MRI brain · pairing ≤ 30 days (Spec §13.2)',
      ),
      MindReferenceRow(
        'Validation target',
        'Classification accuracy ≥ 80 % vs MoCA, study AUD-COG-01 (300 participants)',
      ),
      MindReferenceRow(
        'Picture',
        'In-app park scene with 12 information units (document stimulus pending, OQ-FEA-02)',
        provenance: 'DER',
      ),
      MindReferenceRow(
        'Research line',
        'Animal fluency below about 12 in a minute is a commonly used screening cut-off for adults; shown for context only, no band',
        provenance: 'DER',
      ),
    ],
    whatYouGet: [
      'Animal count: how many different animals you named in 60 seconds (FLUENCY_COUNT).',
      'Pauses: how many times you stopped for more than 2 seconds, per minute (PAUSE_RATE).',
      'Speech rate: words per minute while describing the picture (SPEECH_RATE).',
      'Word variety: different words divided by all words, 0–1 (LEXICAL_DIV), plus how many of the 12 picture details you mentioned.',
      'No pass / fail today: the document\'s age- and education-adjusted norms are still being built, so the values are kept for your own baseline.',
    ],
    howWorkedOut: [
      'Your speech is turned into text on the phone in the language you chose (te / hi / en). Each word is time-stamped.',
      'Animal naming: every word is checked against an animal list; repeats and non-animals are not counted. Pauses over 2 s between words are counted.',
      'Picture description: words per minute, type–token ratio, and 12 information units (child, kite, dog, man reading, bench, woman watering, flowers, pond, ducks, ice-cream cart, tree, sun).',
      'The document bands the result only after the classifier is validated against the clinician MoCA (study AUD-COG-01, ≥ 80 % agreement). Until then COG_BAND stays "in validation".',
    ],
    referenceNote:
        'Speech recognition quality varies by phone and language. Values are kept for your own baseline; a low count on one day is not a diagnosis.',
    resultTitle: 'Memory & speech result',
  );

  // ── 2. Mood & prosody (ALG-AUD-11, S-G13 / S-G14) ───────────────────────
  static const MindProtocol mood = MindProtocol(
    id: 'mind_mood',
    kind: MindKind.mood,
    screenId: 'S-G13',
    resultScreenId: 'S-R01',
    catalogueId: 'cat_mood',
    title: 'Mood check',
    shortTitle: 'Mood',
    recordTitle: 'Mood & Prosody Check (PHQ-9 / GAD-7)',
    algorithmIds: ['ALG-AUD-11'],
    conditionCode: 'COND_MOOD',
    featureId: 'F-24',
    requiredGates: [GateId.g04, GateId.g07, GateId.g37],
    durationLabel: 'about 4 min',
    purpose:
        'Sixteen short questions about the last two weeks (PHQ-9 for mood, GAD-7 for worry), then one minute of free talking so the app can listen to the tone of your voice. This check is only offered inside a clinician-led pathway, and your answers go to that clinician.',
    whatYouDo: [
      MindStep(MindIllustration.questionnaire, '16 questions, 4 choices each'),
      MindStep(MindIllustration.speakToPhone, 'Talk freely for 60 s'),
      MindStep(MindIllustration.clinician, 'Shared with your clinician'),
    ],
    measures: [
      'PHQ9 — sum of 9 items (0–27); GAD7 — sum of 7 items (0–21); normal < 5, ≥ 10 moderate (Spec §8)',
      'PHQ-9 item 9 > 0 opens Crisis Support (S-G14) immediately — safety gate G-37',
      'MOOD_VOICE_SCORE — prosody, energy, pauses and rate from 60 s of speech; used only if voice adds ≥ 0.03 AUC over the questionnaires (release gate G-24)',
    ],
    markerMeanings: {
      'PHQ9':
          'Depression questionnaire total. Under 5 is normal; 10 or more is at least moderate and your clinician will follow up. Question 9 (thoughts of self-harm) is handled separately and immediately.',
      'GAD7':
          'Anxiety questionnaire total. Under 5 is normal; 10 or more is at least moderate.',
      'MOOD_VOICE_SCORE':
          'A 0–1 estimate from the tone of your voice. The document only allows it to count once a study proves it adds to the questionnaires, so it is shown as "not used".',
    },
    needs: [
      MindNeedTile(
        MindIllustration.clinician,
        'Clinician pathway',
        'Activated by your clinician (G-07)',
      ),
      MindNeedTile(
        MindIllustration.quietRoom,
        'Private, quiet place',
        'Answer honestly; nobody else sees this',
      ),
      MindNeedTile(
        MindIllustration.supportHands,
        'Support any time',
        'Helplines are one tap away',
      ),
    ],
    prepareChecklist: [
      MindPrepareItem(
        MindIllustration.clinician,
        'I understand my answers are shared with my pathway clinician',
      ),
      MindPrepareItem(
        MindIllustration.quietRoom,
        'I am somewhere private and quiet',
      ),
      MindPrepareItem(
        MindIllustration.calmBreath,
        'I will answer about the last two weeks, not just today',
      ),
    ],
    setupHint:
        'There are no right answers. If a question about hurting yourself applies to you, the app pauses and shows people you can talk to right now.',
    howTo: [
      MindHowToStep(
        MindIllustration.questionnaire,
        'Answer 16 questions',
        'Each asks how often something bothered you over the last two weeks: not at all, several days, more than half the days, or nearly every day.',
      ),
      MindHowToStep(
        MindIllustration.speakToPhone,
        'Then talk for one minute',
        'Describe your day, your week or anything on your mind. The app listens to the tone, not the words.',
      ),
      MindHowToStep(
        MindIllustration.supportHands,
        'Help is always one tap away',
        'A support button is on every screen. If you say you have had thoughts of self-harm, the app shows helplines and lets your clinician know.',
      ),
    ],
    tasks: [
      MindTask(
        id: 'phq9',
        type: MindTaskType.questionnaire,
        title: 'PHQ-9',
        instruction:
            'Over the last 2 weeks, how often have you been bothered by…',
        questionnaire: MindTexts.phq9,
      ),
      MindTask(
        id: 'gad7',
        type: MindTaskType.questionnaire,
        title: 'GAD-7',
        instruction:
            'Over the last 2 weeks, how often have you been bothered by…',
        questionnaire: MindTexts.gad7,
      ),
      MindTask(
        id: 'free_speech',
        type: MindTaskType.speechRecord,
        title: 'Free speech',
        instruction: 'Tell the phone about your day or your week.',
        seconds: 60,
        minSeconds: 20,
        illustration: MindIllustration.speakToPhone,
      ),
    ],
    voiceStart:
        'Sixteen questions about the last two weeks. Tap the answer that fits best.',
    voiceDone: 'Done. Scoring your answers.',
    analysisStages: [
      'Safety check: PHQ-9 question 9',
      'PHQ-9 and GAD-7 totals',
      'Voice prosody features (60 s)',
      'Release-gate check for the voice score (G-24)',
    ],
    referenceRows: [
      MindReferenceRow('Normal', 'PHQ-9 < 5 and GAD-7 < 5 (Spec §8)'),
      MindReferenceRow(
        'Moderate',
        'PHQ-9 ≥ 10 or GAD-7 ≥ 10 → clinician follow-up, routine (Spec §8, §13.2)',
      ),
      MindReferenceRow(
        'Crisis',
        'PHQ-9 item 9 > 0 → Crisis Support S-G14 immediately, clinician notified (G-37, E-AUD-005)',
      ),
      MindReferenceRow(
        'Voice score',
        'Used only if it adds ≥ 0.03 AUC over the questionnaires in the 200-participant interview study (G-24)',
      ),
      MindReferenceRow(
        'Confirmation',
        'Clinician assessment with PHQ-9 / GAD-7; TSH, CBC, B12, vitamin D · pairing ≤ 7 days (Spec §13.2)',
      ),
      MindReferenceRow(
        'Severity labels',
        '5–9 mild · 10–14 moderate · 15–19 moderately severe · ≥ 20 severe (standard PHQ-9 bands; the document gives only < 5 and ≥ 10)',
        provenance: 'DER',
      ),
    ],
    whatYouGet: [
      'PHQ-9 total (0–27): nine questions about mood, sleep, energy, appetite, concentration and self-harm thoughts over the last two weeks.',
      'GAD-7 total (0–21): seven questions about worry and restlessness.',
      'Under 5 on each is normal; 10 or more means your clinician follows up (routine). Question 9 is handled at once, separately from the total.',
      'A voice score from your 60 s of free speech, recorded but not used until the document\'s release study proves it helps.',
    ],
    howWorkedOut: [
      'Each answer scores 0 (not at all), 1 (several days), 2 (more than half the days) or 3 (nearly every day); the totals are plain sums.',
      'Question 9 above 0 triggers the crisis screen and the emergency rule before anything else (G-37, E-AUD-005). Your clinician is notified if you leave the switch on.',
      'Severity labels: < 5 normal and ≥ 10 moderate come from the document; 5–9 mild, 15–19 moderately severe and ≥ 20 severe are the standard PHQ bands [DER].',
      'Voice: pitch variability, speaking rate and long pauses are combined into a 0–1 score. The document allows it to count only if it adds ≥ 0.03 AUC over the questionnaires (G-24), so it is shown as not used.',
    ],
    referenceNote:
        'Clinician pathway only. The questionnaires are the result; the voice score is recorded but not used until released.',
    resultTitle: 'Mood check result',
  );

  // ── 3. Heart-failure daily voice (ALG-AUD-12, S-G15) ────────────────────
  static const MindProtocol hfVoice = MindProtocol(
    id: 'mind_hf_voice',
    kind: MindKind.hfVoice,
    screenId: 'S-G15',
    resultScreenId: 'S-R05',
    catalogueId: 'cat_hf_voice',
    title: 'Daily fluid voice check',
    shortTitle: 'HF voice',
    recordTitle: 'Heart-Failure Daily Fluid Voice Check',
    algorithmIds: ['ALG-AUD-12'],
    conditionCode: 'COND_HF_DECOMP',
    featureId: 'F-25',
    requiredGates: [
      GateId.g08,
      GateId.g12,
      GateId.g17,
      GateId.g18,
      GateId.g28,
      GateId.g34,
    ],
    languages: [MindLanguage.en, MindLanguage.hi, MindLanguage.te],
    dailyCheck: true,
    durationLabel: 'about 1 min',
    purpose:
        'Every day you read the same sentence for 30 seconds. Fluid building up in the body changes the voice slightly, so the app compares today with your own first 14 days and warns your clinic early if the voice drifts.',
    whatYouDo: [
      MindStep(MindIllustration.readSentence, 'Read the sentence aloud'),
      MindStep(
        MindIllustration.calendar14,
        'First 14 days build your baseline',
      ),
      MindStep(MindIllustration.clinician, 'Drift alerts your clinic'),
    ],
    measures: [
      'Daily 30 s fixed sentence; days 1–14 build the personal acoustic baseline (G-28, no alerts)',
      'HF_VOICE_DEV — standardised deviation of today\'s voice features (pitch, jitter, shimmer, spectral centroid, harmonic ratio, pause share) from the 14-day baseline',
      'HF_ALERT — true when the deviation stays high across days → urgent pathway (NT-proBNP / BNP, weight, electrolytes, clinician review)',
    ],
    markerMeanings: {
      'HF_VOICE_DEV':
          'How far today\'s voice sits from your own first 14 days, in standard deviations. Around 0–1 is your usual day-to-day variation.',
      'HF_ALERT':
          'Raised when the deviation is high two days running — a signal, not a diagnosis. Your clinic checks weight, blood tests and symptoms.',
    },
    needs: [
      MindNeedTile(
        MindIllustration.clinician,
        'HF programme',
        'Enrolled by your clinic (G-08)',
      ),
      MindNeedTile(
        MindIllustration.quietRoom,
        'Same quiet spot',
        'Same time each morning helps',
      ),
      MindNeedTile(
        MindIllustration.readSentence,
        '30 seconds',
        'Read at your normal pace',
      ),
    ],
    prepareChecklist: [
      MindPrepareItem(
        MindIllustration.quietRoom,
        'The room is quiet and I am sitting upright',
      ),
      MindPrepareItem(
        MindIllustration.calmBreath,
        'I have not just exercised, eaten or had a cold drink',
      ),
      MindPrepareItem(
        MindIllustration.readSentence,
        'I will read the whole sentence, repeating it until the timer ends',
      ),
    ],
    setupHint:
        'Read the sentence as you normally speak. If you cough or stumble, keep going — the app uses the whole 30 seconds.',
    howTo: [
      MindHowToStep(
        MindIllustration.readSentence,
        'Read the sentence shown on screen',
        'Read it aloud at your normal pace and volume. When you reach the end, start again until the 30-second ring completes.',
      ),
      MindHowToStep(
        MindIllustration.calendar14,
        'The first 14 days are your baseline',
        'While your clinic says you are stable, the app learns your normal voice. No alerts are raised during these days; you will see "Day X of 14".',
      ),
      MindHowToStep(
        MindIllustration.clinician,
        'From day 15 the app compares',
        'Each day shows how far today\'s voice is from your baseline. If it drifts two days in a row, your clinic is alerted for an urgent review.',
      ),
    ],
    tasks: [
      MindTask(
        id: 'hf_sentence',
        type: MindTaskType.speechRecord,
        title: 'Read the sentence',
        instruction:
            'Read the sentence aloud, again and again, for 30 seconds.',
        seconds: 30,
        minSeconds: 15,
        sentenceKey: 'hfSentence',
        illustration: MindIllustration.readSentence,
      ),
    ],
    voiceStart: 'Read the sentence on the screen aloud for thirty seconds.',
    voiceDone: 'Done. Comparing with your baseline.',
    analysisStages: [
      'Audio quality (clipping, noise)',
      'Voice features: pitch, jitter, shimmer, spectrum, pauses',
      'Baseline days and personal distribution (G-28)',
      'Deviation score and multi-day drift',
    ],
    referenceRows: [
      MindReferenceRow(
        'Who',
        'Enrolled heart-failure programme patients (G-08), daily (G-34)',
      ),
      MindReferenceRow(
        'Baseline',
        'Days 1–14 build the personal baseline; no alert before it is complete (G-28, E-AUD-006)',
      ),
      MindReferenceRow('Normal', 'HF_ALERT = false — no alert (Spec §8)'),
      MindReferenceRow(
        'Alert pathway',
        'Urgent: NT-proBNP or BNP, echocardiogram, creatinine, electrolytes, chest X-ray, weight · pairing ≤ 3 days (Spec §13.2)',
      ),
      MindReferenceRow(
        'Validation target',
        '≥ 70 % of fluid-overload events detected ≥ 7 days early at ≤ 1 false alert per patient-month (6-month HF cohort)',
      ),
      MindReferenceRow(
        'Deviation rule',
        'Mean |z| over six acoustic features vs the baseline; alert when ≥ 2.0 on two consecutive days (threshold pending, OQ-FEA-03)',
        provenance: 'DER',
      ),
      MindReferenceRow(
        'Sentence',
        'Fixed in-app sentence per language (document text pending, OQ-FEA-03)',
        provenance: 'DER',
      ),
    ],
    whatYouGet: [
      'During days 1–14: a progress line "Day X of 14" while the app learns your normal voice. No alerts in this period (G-28).',
      'From day 15: HF_VOICE_DEV, how far today\'s voice is from your own baseline in standard deviations, and a trend over the last days.',
      'HF_ALERT: raised when the deviation is high two days in a row. An alert opens an urgent case for your clinic (NT-proBNP / BNP, weight, electrolytes).',
    ],
    howWorkedOut: [
      'Six voice features are measured from the 30 s reading: average pitch, jitter (pitch steadiness), shimmer (loudness steadiness), spectral centroid (brightness), harmonic ratio (clarity) and the share of silence.',
      'The first 14 days give a mean and spread for each feature. Each later day is scored as the average distance from that mean in standard deviations.',
      'Fluid build-up tends to lower pitch and clarity and raise jitter, shimmer and pausing, which pushes the deviation up.',
      'Alert rule: deviation ≥ 2.0 on two consecutive days [DER stand-in; the document gives "multi-day drift threshold" without a number]. Audio quality must pass clipping ≤ 1 % and SNR ≥ 15 dB (CAP-13).',
    ],
    referenceNote:
        'The voice check supports, never replaces, daily weights and your symptom diary. Call your clinic if you feel more breathless regardless of this result.',
    resultTitle: 'Daily voice check',
  );

  // ── 4. Stroke act-now (ALG-MOV-06..09, S-H06) ───────────────────────────
  static const MindProtocol stroke = MindProtocol(
    id: 'mind_stroke',
    kind: MindKind.stroke,
    screenId: 'S-H06',
    resultScreenId: 'S-R01',
    catalogueId: 'cat_stroke_fast',
    title: 'Stroke act-now check',
    shortTitle: 'Stroke check',
    recordTitle: 'Stroke Act-Now Check (FAST)',
    algorithmIds: ['ALG-MOV-06', 'ALG-MOV-07', 'ALG-MOV-08', 'ALG-MOV-09'],
    conditionCode: 'COND_STROKE',
    featureId: 'F-27',
    requiredGates: [GateId.g37],
    languages: [MindLanguage.en, MindLanguage.hi, MindLanguage.te],
    usesCamera: true,
    usesMotion: true,
    needsOnsetTime: true,
    safetyCritical: true,
    durationLabel: 'about 1 min',
    purpose:
        'Face, Arms, Speech, Time. A one-minute check for the warning signs of a stroke: a lopsided smile, an arm that drifts down, slurred speech. Any one sign means call emergency services now — do not wait for the other checks.',
    whatYouDo: [
      MindStep(MindIllustration.smileCamera, 'Relax, then smile at the camera'),
      MindStep(
        MindIllustration.armsOutEyesClosed,
        'Hold each arm out, eyes closed',
      ),
      MindStep(MindIllustration.readSentence, 'Repeat a sentence'),
    ],
    measures: [
      'FACE_ASYM_SCORE 0–1 and FACE_ASYM_SIDE — mouth-corner distance to the eye line at rest vs peak smile (MOV-06)',
      'ARM_DRIFT_L / ARM_DRIFT_R in cm — downward drift over a 10 s hold with eyes closed (MOV-07)',
      'SPEECH_ABN_PROB 0–1 — fixed-sentence repetition vs the target (MOV-08)',
      'STROKE_POSITIVE — OR of the three signs, plus onset time and signs[] (MOV-09) → Emergency S-R02 (BR-SCR-01, T10)',
    ],
    markerMeanings: {
      'FACE_ASYM_SCORE':
          'How uneven the smile was between the two sides (0 = even). Above the line counts as a sign.',
      'ARM_DRIFT_L':
          'How far the arm dropped during the 10-second hold, in centimetres.',
      'SPEECH_ABN_PROB':
          'How far the repeated sentence was from the target (0 = clear).',
      'STROKE_POSITIVE':
          'Yes if any single sign was positive. Yes means call emergency services immediately.',
    },
    needs: [
      MindNeedTile(
        MindIllustration.callEmergency,
        'Call button',
        'Always on screen — 108 / 112',
      ),
      MindNeedTile(
        MindIllustration.smileCamera,
        'Front camera',
        'Face in the oval, good light',
      ),
      MindNeedTile(
        MindIllustration.clock,
        'When it started',
        'Needed by the stroke team',
      ),
    ],
    prepareChecklist: [
      MindPrepareItem(
        MindIllustration.callEmergency,
        'If the person cannot speak, smile or lift an arm — call 108 / 112 now, skip the check',
      ),
      MindPrepareItem(
        MindIllustration.clock,
        'I have noted when the symptoms started (or chosen "unknown")',
      ),
    ],
    setupHint:
        'A helper can hold the phone. This check never blocks: skip any step you cannot do; one positive sign is enough to act.',
    howTo: [
      MindHowToStep(
        MindIllustration.smileCamera,
        'Face: relax, then smile',
        'Look straight at the front camera with a relaxed face for 3 seconds, then smile as wide as you can for 3 seconds. The app compares the two mouth corners.',
      ),
      MindHowToStep(
        MindIllustration.armsOutEyesClosed,
        'Arms: hold the phone out, eyes closed',
        'Hold the phone flat in your right hand with the arm straight out in front, close your eyes, and hold for 10 seconds. Then the left arm. An arm that drifts down is a sign.',
      ),
      MindHowToStep(
        MindIllustration.readSentence,
        'Speech: repeat the sentence',
        'Say the sentence on the screen clearly. Slurred or missing words are a sign.',
      ),
    ],
    tasks: [
      MindTask(
        id: 'face',
        type: MindTaskType.faceSmile,
        title: 'Face',
        instruction: 'Relax your face… then smile big.',
        seconds: 7,
        illustration: MindIllustration.smileCamera,
        whatToDo: [
          'Hold the phone at arm\'s length with your face inside the oval, good light',
          'Keep a relaxed face for 3 seconds',
          'When you hear "smile", smile as wide as you can for 4 seconds',
        ],
      ),
      MindTask(
        id: 'arm_right',
        type: MindTaskType.armDrift,
        title: 'Right arm',
        instruction: 'Phone in the right hand, arm straight out, eyes closed.',
        seconds: 10,
        arm: 'right',
        illustration: MindIllustration.armsOutEyesClosed,
        whatToDo: [
          'Hold the phone flat in your right palm, screen up',
          'Stretch the arm straight out in front at shoulder height',
          'Close your eyes and hold still for 10 seconds — the voice counts you down',
        ],
      ),
      MindTask(
        id: 'arm_left',
        type: MindTaskType.armDrift,
        title: 'Left arm',
        instruction: 'Now the left hand, arm straight out, eyes closed.',
        seconds: 10,
        arm: 'left',
        illustration: MindIllustration.armsOutEyesClosed,
        whatToDo: [
          'Move the phone to your left palm, screen up',
          'Stretch the left arm straight out at shoulder height',
          'Close your eyes and hold still for 10 seconds',
        ],
      ),
      MindTask(
        id: 'speech',
        type: MindTaskType.speechTranscribe,
        title: 'Speech',
        instruction: 'Repeat the sentence clearly.',
        seconds: 8,
        minSeconds: 2,
        sentenceKey: 'strokeSentence',
        illustration: MindIllustration.readSentence,
        whatToDo: [
          'Listen to the sentence, then say it back clearly',
          'Normal pace, phone at arm\'s length',
          'A helper can judge the speech if recognition is not available',
        ],
      ),
    ],
    voiceStart: 'Look at the camera with a relaxed face.',
    voiceDone: 'Checking the three signs.',
    analysisStages: [
      'Face symmetry at rest and at peak smile',
      'Arm drift, right and left',
      'Sentence match and articulation',
      'FAST decision (any sign → act now)',
    ],
    referenceRows: [
      MindReferenceRow(
        'Decision',
        'Any single sign above its threshold sets STROKE_POSITIVE, even if other steps were skipped (Spec §9 MOV-09)',
      ),
      MindReferenceRow(
        'Action',
        'Positive → Emergency alert S-R02: call emergency services, stroke unit CT brain (BR-SCR-01, T10)',
      ),
      MindReferenceRow(
        'Confirmation',
        'Emergency: non-contrast CT or MRI brain, glucose, PT/INR, platelets, ECG · same day (Spec §13.2)',
      ),
      MindReferenceRow(
        'Validation target',
        'Combined sensitivity ≥ 95 %, study MOV-STR-01 (200 participants incl. ≥ 100 acute stroke)',
      ),
      MindReferenceRow(
        'Thresholds',
        'Face 0.50 · arm drift 10 cm · speech 0.50 (document values pending, OQ-FEA-05)',
        provenance: 'DER',
      ),
      MindReferenceRow(
        'Arm method',
        'Phone tilt in the outstretched hand (motion sensor) stands in for the pose-camera method; 60 cm arm length',
        provenance: 'DER',
      ),
      MindReferenceRow(
        'Sentence',
        'Fixed in-app sentence per language (document text pending)',
        provenance: 'DER',
      ),
    ],
    whatYouGet: [
      'Face: a smile-symmetry score 0–1 and the weaker side (FACE_ASYM_SCORE, FACE_ASYM_SIDE).',
      'Arms: how many centimetres each arm drifted down during the 10 s hold (ARM_DRIFT_R, ARM_DRIFT_L).',
      'Speech: how far the repeated sentence was from the target, 0–1 (SPEECH_ABN_PROB).',
      'STROKE_POSITIVE with the list of signs and the onset time. Positive means the emergency screen and a call to 108 / 112; negative does not rule a stroke out.',
    ],
    howWorkedOut: [
      'Face: the camera tracks the eyes and mouth corners. The distance of each corner to the eye line is compared at rest and at the biggest smile; a corner that moves much less, or hangs lower, raises the score.',
      'Arms: the phone\'s gravity sensor gives the arm angle at the start and the end of the 10 s hold; the drop in degrees becomes centimetres for a 60 cm arm [DER stand-in for the document\'s pose-camera method].',
      'Speech: the recognised words are matched to the sentence (word error rate) and combined with the speaking rate.',
      'Decision: any sign above its threshold (0.50 / 10 cm / 0.50 [DER]) sets STROKE_POSITIVE, even if the other steps were skipped (OR gate, MOV-09) → BR-SCR-01 emergency (T10).',
    ],
    referenceNote:
        'Time matters: treatment works best within 4.5 hours of the first symptom. If in doubt, call first and check second.',
    resultTitle: 'Stroke check result',
  );
}
