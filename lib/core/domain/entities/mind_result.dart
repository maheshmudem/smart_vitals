// Output of one Brain & Mind session (Doc 11: CognitiveResult, Mood &
// Crisis, HeartFailureVoice, StrokeFastResult).
import '../algorithms/mind_engines.dart';
import '../algorithms/risk_engine.dart' show PersonalBaselineResult;
import 'enums.dart';
import 'marker_envelope.dart';
import 'mind_protocol.dart';

/// One task of the session (questionnaire, speech task, face, arm…).
class MindPartResult {
  const MindPartResult({
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
  });

  final String id;
  final String label;
  final bool assessed;
  final bool skipped;
  final Map<String, double> values;
  final Map<String, bool> flags;

  /// Transcript excerpt, recognised sentence, side, etc.
  final Map<String, String> texts;

  /// Questionnaire answers by item id.
  final Map<String, int> answers;

  /// Animals found, information units, positive signs…
  final List<String> items;
  final SemanticBand band;
  final String note;
}

class MindQualityFacts {
  const MindQualityFacts({
    required this.kind,
    this.language = MindLanguage.en,
    this.sttAvailable = false,
    this.audioSource = 'simulated',
    this.clipPct,
    this.snrDb,
    this.ambientDba,
    this.micSelfCheck = false,
    this.cameraUsed = false,
    this.motionUsed = false,
    this.taskSeconds = const {},
    this.retakes = 0,
    this.simulated = true,
    this.sources = const {},
  });

  final MindKind kind;

  /// Data source per task id ('camera' | 'motion' | 'stt' | 'helper' |
  /// 'simulated' | 'none'); empty when not tracked.
  final Map<String, String> sources;
  final MindLanguage language;
  final bool sttAvailable;

  /// 'microphone' | 'simulated' | 'none'.
  final String audioSource;
  final double? clipPct;
  final double? snrDb;
  final double? ambientDba;
  final bool micSelfCheck;
  final bool cameraUsed;
  final bool motionUsed;
  final Map<String, double> taskSeconds;
  final int retakes;
  final bool simulated;

  bool get audioQualityOk =>
      (clipPct ?? 0) <= VoiceFeatures.maxClipPct &&
      (snrDb ?? 99) >= VoiceFeatures.minSnrDb;

  double get captureQualityScore {
    var s = 0.95;
    if (audioSource != 'microphone' && kind != MindKind.mood) s -= 0.05;
    if (!audioQualityOk) s -= 0.15;
    if (ambientDba != null && ambientDba! > 45) s -= 0.10;
    if (kind == MindKind.cognitive && !sttAvailable) s -= 0.25;
    if (kind == MindKind.stroke && !cameraUsed) s -= 0.10;
    return s.clamp(0.4, 1.0);
  }
}

class MindSessionResult {
  const MindSessionResult({
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
    this.crisis = false,
    this.clinicianNotified = false,
    this.onsetAt,
    this.onsetLabel,
    this.positiveSigns = const [],
    this.hfBaselineDay,
    this.hfBuilding = false,
    this.hfHistory = const [],
    this.language = MindLanguage.en,
  });

  final String sessionId;
  final String subjectId;
  final String subjectName;
  final int ageYears;
  final BiologicalSex sex;
  final MindProtocol protocol;
  final DateTime recordedAt;
  final int durationSeconds;
  final List<MindPartResult> parts;
  final Map<String, double> overall;
  final Map<String, MarkerEnvelope<dynamic>> markers;
  final SemanticBand band;
  final String bandTitle;
  final String bandSubline;
  final String whatItMeans;
  final UrgencyLevel urgency;
  final List<String> firedRuleCodes;
  final double confidence;
  final MindQualityFacts quality;
  final PersonalBaselineResult? baseline;
  final MindDemoOutcome demoOutcome;
  final String heroCode;
  final double? heroValue;
  final String heroLabel;

  /// PHQ-9 item 9 > 0 (G-37).
  final bool crisis;
  final bool clinicianNotified;
  final DateTime? onsetAt;
  final String? onsetLabel;
  final List<String> positiveSigns;

  /// HF: day number of this recording (1-based), building while ≤ 14.
  final int? hfBaselineDay;
  final bool hfBuilding;
  final List<HfDailySample> hfHistory;
  final MindLanguage language;

  bool get isPartiallyAssessed =>
      parts.length > 1 && parts.any((p) => !p.assessed);
  bool get isNotAssessed => parts.every((p) => !p.assessed);
  bool get isEmergency => urgency == UrgencyLevel.emergency;

  MindPartResult? part(String id) {
    for (final p in parts) {
      if (p.id == id) return p;
    }
    return null;
  }

  MindSessionResult copyWith({bool? clinicianNotified}) => MindSessionResult(
    sessionId: sessionId,
    subjectId: subjectId,
    subjectName: subjectName,
    ageYears: ageYears,
    sex: sex,
    protocol: protocol,
    recordedAt: recordedAt,
    durationSeconds: durationSeconds,
    parts: parts,
    overall: overall,
    markers: markers,
    band: band,
    bandTitle: bandTitle,
    bandSubline: bandSubline,
    whatItMeans: whatItMeans,
    urgency: urgency,
    firedRuleCodes: firedRuleCodes,
    confidence: confidence,
    quality: quality,
    demoOutcome: demoOutcome,
    heroCode: heroCode,
    heroValue: heroValue,
    heroLabel: heroLabel,
    baseline: baseline,
    crisis: crisis,
    clinicianNotified: clinicianNotified ?? this.clinicianNotified,
    onsetAt: onsetAt,
    onsetLabel: onsetLabel,
    positiveSigns: positiveSigns,
    hfBaselineDay: hfBaselineDay,
    hfBuilding: hfBuilding,
    hfHistory: hfHistory,
    language: language,
  );
}
