// Output of one Breathing & Voice session (Doc 11 AudioScreeningResult:
// cough & TB, obstruction & spirometry, voice quality).
import '../algorithms/breath_engines.dart';
import '../algorithms/mind_engines.dart' show VoiceFeatures;
import '../algorithms/risk_engine.dart' show PersonalBaselineResult;
import 'breath_protocol.dart';
import 'enums.dart';
import 'marker_envelope.dart';

/// One task of the session (questionnaire, coughs, "aaa", breaths, blows…).
class BreathPartResult {
  const BreathPartResult({
    required this.id,
    required this.label,
    required this.assessed,
    this.skipped = false,
    this.values = const {},
    this.flags = const {},
    this.texts = const {},
    this.answers = const {},
    this.items = const [],
    this.band = SemanticBand.notAssessed,
    this.note = '',
    this.attempts = 1,
  });

  final String id;
  final String label;
  final bool assessed;
  final bool skipped;
  final Map<String, double> values;
  final Map<String, bool> flags;
  final Map<String, String> texts;

  /// Questionnaire answers by item id (option index).
  final Map<String, int> answers;

  /// Symptoms present, exposures, wheeze segments…
  final List<String> items;
  final SemanticBand band;
  final String note;
  final int attempts;
}

class BreathQualityFacts {
  const BreathQualityFacts({
    required this.kind,
    this.audioSource = 'simulated',
    this.micDeviationDb,
    this.micProcessingDetected = false,
    this.micSelfCheckPassed = false,
    this.ambientDba,
    this.clipByTask = const {},
    this.snrByTask = const {},
    this.attemptsByTask = const {},
    this.effortsDone = 0,
    this.repeatable,
    this.repeatabilityDiffPct,
    this.bodyProfile,
    this.predictedSource,
    this.retakes = 0,
    this.simulated = true,
    this.micSource,
    this.durationByTask = const {},
    this.clipAcceptedTasks = const [],
  });

  final BreathKind kind;

  /// 'microphone' (profiled) | 'manual' | 'simulated' | 'session' | null.
  final String? micSource;

  /// Seconds of recording per task.
  final Map<String, double> durationByTask;

  /// Tasks kept despite clipping > 1 % after two re-records (CAP-13).
  final List<String> clipAcceptedTasks;

  /// 'microphone' | 'simulated'.
  final String audioSource;
  final double? micDeviationDb;
  final bool micProcessingDetected;
  final bool micSelfCheckPassed;
  final double? ambientDba;
  final Map<String, double> clipByTask;
  final Map<String, double> snrByTask;
  final Map<String, int> attemptsByTask;
  final int effortsDone;
  final bool? repeatable;
  final double? repeatabilityDiffPct;

  /// "170 cm · 62 y · male" when the predicted values used the profile.
  final String? bodyProfile;
  final String? predictedSource;
  final int retakes;
  final bool simulated;

  bool get audioQualityOk =>
      clipByTask.values.every((c) => c <= VoiceFeatures.maxClipPct) &&
      snrByTask.values.every((s) => s >= VoiceFeatures.minSnrDb);

  double? get worstClipPct => clipByTask.isEmpty
      ? null
      : clipByTask.values.reduce((a, b) => a > b ? a : b);
  double? get worstSnrDb => snrByTask.isEmpty
      ? null
      : snrByTask.values.reduce((a, b) => a < b ? a : b);

  double get captureQualityScore {
    var s = 0.95;
    if (audioSource != 'microphone') s -= 0.05;
    if (!audioQualityOk) s -= 0.15;
    if (ambientDba != null && ambientDba! > 45) s -= 0.10;
    if (!micSelfCheckPassed) s -= 0.05;
    if (micSource == 'manual') s -= 0.03;
    if (clipAcceptedTasks.isNotEmpty) s -= 0.10;
    if (repeatable == false) s -= 0.10;
    if (kind == BreathKind.lungFunction && bodyProfile == null) s -= 0.15;
    return s.clamp(0.4, 1.0);
  }
}

class BreathSessionResult {
  const BreathSessionResult({
    required this.sessionId,
    required this.subjectId,
    required this.subjectName,
    required this.ageYears,
    required this.sex,
    required this.protocol,
    required this.recordedAt,
    required this.durationSeconds,
    required this.parts,
    required this.overall,
    required this.markers,
    required this.band,
    required this.bandTitle,
    required this.bandSubline,
    required this.whatItMeans,
    required this.urgency,
    required this.firedRuleCodes,
    required this.confidence,
    required this.quality,
    required this.demoOutcome,
    required this.heroCode,
    required this.heroValue,
    required this.heroLabel,
    this.baseline,
    this.heightCm,
    this.coughs,
    this.wheeze,
    this.spirometry,
    this.voice,
    this.oad,
    this.tbClassicSymptoms = false,
    this.tbSymptoms = const [],
    this.exposures = const [],
  });

  final String sessionId;
  final String subjectId;
  final String subjectName;
  final int ageYears;
  final BiologicalSex sex;
  final BreathProtocol protocol;
  final DateTime recordedAt;
  final int durationSeconds;
  final List<BreathPartResult> parts;
  final Map<String, double> overall;
  final Map<String, MarkerEnvelope<dynamic>> markers;
  final SemanticBand band;
  final String bandTitle;
  final String bandSubline;
  final String whatItMeans;
  final UrgencyLevel urgency;
  final List<String> firedRuleCodes;
  final double confidence;
  final BreathQualityFacts quality;
  final PersonalBaselineResult? baseline;
  final BreathDemoOutcome demoOutcome;
  final String heroCode;
  final double? heroValue;
  final String heroLabel;
  final double? heightCm;

  /// Raw engine outputs for the detail cards.
  final CoughDetection? coughs;
  final WheezeResult? wheeze;
  final SpirometryEstimate? spirometry;
  final VoiceQualityResult? voice;
  final OadScore? oad;
  final bool tbClassicSymptoms;
  final List<String> tbSymptoms;
  final List<String> exposures;

  bool get isPartiallyAssessed =>
      parts.length > 1 && parts.any((p) => !p.assessed);
  bool get isNotAssessed => parts.every((p) => !p.assessed);

  BreathPartResult? part(String id) {
    for (final p in parts) {
      if (p.id == id) return p;
    }
    return null;
  }
}
