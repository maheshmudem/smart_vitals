// Output of one hearing session (Doc 11 HearingResult: earphones_verified,
// thresholds_left/right_db_hl, din_srt_db, hearing_band).
import '../algorithms/hearing_engines.dart';
import '../algorithms/risk_engine.dart' show PersonalBaselineResult;
import 'enums.dart';
import 'hearing_protocol.dart';
import 'marker_envelope.dart';

/// One ear (pure tone) or the digits-in-noise block.
class HearingPartResult {
  const HearingPartResult({
    required this.label,
    required this.assessed,
    this.ear,
    this.skipped = false,
    this.thresholds = const {},
    this.noResponse = const {},
    this.pta4,
    this.grade,
    this.band = SemanticBand.notAssessed,
    this.note = '',
    this.presentations = const [],
    this.dinTrials = const [],
    this.srtDb,
  });

  final String label;
  final bool assessed;
  final HearingEar? ear;
  final bool skipped;

  /// dB HL by frequency (500, 1000, 2000, 4000).
  final Map<int, double> thresholds;

  /// Frequencies with no response at 80 dB HL.
  final Set<int> noResponse;
  final double? pta4;
  final HearingGrade? grade;
  final SemanticBand band;
  final String note;
  final List<TonePresentation> presentations;
  final List<DinTrial> dinTrials;
  final double? srtDb;

  int get catchTrials => presentations.where((p) => p.isCatch).length;
  int get falsePositives =>
      presentations.where((p) => p.isCatch && p.heard).length;
}

class HearingQualityFacts {
  const HearingQualityFacts({
    required this.mode,
    this.earphoneType = 'simulated',
    this.earphonesVerified = false,
    this.volumeAtMax = false,
    this.fullScaleDbHl = ToneLevel.defaultFullScaleDbHl,
    this.calibrationSource = 'assumed',
    this.ambientMeanDba,
    this.ambientMaxDba,
    this.ambientSource = 'simulated',
    this.catchTrials = 0,
    this.falsePositives = 0,
    this.pauses = 0,
    this.trials = 0,
    this.retakes = 0,
    this.simulated = true,
  });

  final HearingMode mode;

  /// 'wired' | 'bluetooth' | 'usb' | 'manual' | 'simulated' | 'none'.
  final String earphoneType;
  final bool earphonesVerified;
  final bool volumeAtMax;
  final double fullScaleDbHl;

  /// 'assumed' (90 dB HL [DER]) | 'entered' (clinic audiogram).
  final String calibrationSource;
  final double? ambientMeanDba;
  final double? ambientMaxDba;

  /// 'microphone' | 'simulated' | 'manual'.
  final String ambientSource;
  final int catchTrials;
  final int falsePositives;
  final int pauses;
  final int trials;
  final int retakes;
  final bool simulated;

  /// Capture-quality score fed into RSK-06 result confidence.
  double get captureQualityScore {
    var s = 0.95;
    if (!earphonesVerified) s -= 0.10;
    if (mode == HearingMode.pureTone && calibrationSource == 'assumed') {
      s -= 0.10;
    }
    if (mode == HearingMode.pureTone && !volumeAtMax) s -= 0.05;
    if (ambientSource != 'microphone') s -= 0.05;
    if (ambientMaxDba != null && ambientMaxDba! > NoiseLevel.maxDba) s -= 0.10;
    if (catchTrials > 0 && falsePositives / catchTrials > 0.34) s -= 0.15;
    if (pauses > 2) s -= 0.05;
    return s.clamp(0.4, 1.0);
  }
}

class HearingSessionResult {
  const HearingSessionResult({
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
    this.grade,
    this.asymmetric = false,
    this.baseline,
  });

  final String sessionId;
  final String subjectId;
  final String subjectName;
  final int ageYears;
  final BiologicalSex sex;
  final HearingProtocol protocol;
  final DateTime recordedAt;
  final int durationSeconds;
  final List<HearingPartResult> parts;

  /// PTA4_R, PTA4_L, ASYMMETRY_DB, DIN_SRT_DB, BETTER_EAR_PTA4.
  final Map<String, double> overall;
  final Map<String, MarkerEnvelope<dynamic>> markers;
  final SemanticBand band;
  final String bandTitle;
  final String bandSubline;
  final String whatItMeans;
  final UrgencyLevel urgency;
  final List<String> firedRuleCodes;
  final double confidence;
  final HearingQualityFacts quality;
  final PersonalBaselineResult? baseline;
  final HearingDemoOutcome demoOutcome;
  final String heroCode;
  final double? heroValue;
  final String heroLabel;

  /// Better-ear WHO grade (pure tone).
  final HearingGrade? grade;
  final bool asymmetric;

  bool get isPartiallyAssessed =>
      parts.length > 1 && parts.any((p) => !p.assessed);
  bool get isNotAssessed => parts.every((p) => !p.assessed);

  HearingPartResult? ear(HearingEar e) {
    for (final p in parts) {
      if (p.ear == e) return p;
    }
    return null;
  }
}
