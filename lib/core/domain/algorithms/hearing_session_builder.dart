// Turns raw hearing captures into a [HearingSessionResult]
// (Doc 09 §8 ALG-AUD-09, §10 RSK-02/03/04/06, Doc 08 §14.2).
import '../entities/enums.dart';
import '../entities/hearing_protocol.dart';
import '../entities/hearing_result.dart';
import '../entities/marker_envelope.dart';
import '../entities/member_profile.dart';
import 'hearing_engines.dart';
import 'marker_readings.dart';
import 'risk_engine.dart';

/// Raw capture for one ear (pure tone) or the digits-in-noise block.
class HearingPartCapture {
  const HearingPartCapture({
    this.ear,
    this.skipped = false,
    this.skipReason,
    this.thresholds = const {},
    this.noResponse = const {},
    this.presentations = const [],
    this.dinTrials = const [],
    this.srtDb,
  });

  final HearingEar? ear;
  final bool skipped;
  final String? skipReason;
  final Map<int, double> thresholds;
  final Set<int> noResponse;
  final List<TonePresentation> presentations;
  final List<DinTrial> dinTrials;
  final double? srtDb;
}

typedef HearingHistory = List<HearingSessionResult>;

HearingSessionResult buildHearingSession({
  required HearingProtocol protocol,
  required SubjectProfile subject,
  required List<HearingPartCapture> captures,
  required HearingDemoOutcome demoOutcome,
  HearingHistory history = const [],
  String earphoneType = 'simulated',
  bool earphonesVerified = false,
  bool volumeAtMax = false,
  double fullScaleDbHl = ToneLevel.defaultFullScaleDbHl,
  String calibrationSource = 'assumed',
  double? ambientMeanDba,
  double? ambientMaxDba,
  String ambientSource = 'simulated',
  int pauses = 0,
  int retakes = 0,
  bool simulated = true,
  int durationSeconds = 0,
  String? sessionId,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final id = sessionId ?? 'hear_${at.millisecondsSinceEpoch}';
  final parts = <HearingPartResult>[];
  final env = <String, MarkerEnvelope<dynamic>>{};
  final overall = <String, double>{};
  var trials = 0;
  var catchTrials = 0;
  var falsePositives = 0;

  for (final c in captures) {
    if (c.skipped) {
      parts.add(
        HearingPartResult(
          label: c.ear != null ? '${c.ear!.label} ear' : 'Digits in noise',
          ear: c.ear,
          assessed: false,
          skipped: true,
          note: c.skipReason ?? 'Skipped',
        ),
      );
      continue;
    }
    switch (protocol.mode) {
      case HearingMode.pureTone:
        trials += c.presentations.length;
        catchTrials += c.presentations.where((p) => p.isCatch).length;
        falsePositives += c.presentations
            .where((p) => p.isCatch && p.heard)
            .length;
        final pta = HearingGrading.pta4(c.thresholds);
        if (pta == null) {
          parts.add(
            HearingPartResult(
              label: '${c.ear!.label} ear',
              ear: c.ear,
              assessed: false,
              thresholds: c.thresholds,
              presentations: c.presentations,
              note: 'Incomplete — not all four pitches were measured',
            ),
          );
          continue;
        }
        final g = HearingGrading.grade(pta);
        overall['PTA4_${c.ear!.suffix}'] = pta;
        final worst = c.thresholds.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );
        parts.add(
          HearingPartResult(
            label: '${c.ear!.label} ear',
            ear: c.ear,
            assessed: true,
            thresholds: c.thresholds,
            noResponse: c.noResponse,
            pta4: pta,
            grade: g,
            band: _bandFor(g),
            note:
                'PTA4 ${pta.toStringAsFixed(0)} dB HL · ${g.label.toLowerCase()} · softest at ${_hzLabel(worst.key)}: ${worst.value >= ToneLevel.noResponseDbHl ? 'no response' : '${worst.value.toStringAsFixed(0)} dB HL'}',
            presentations: c.presentations,
          ),
        );
      case HearingMode.digitsInNoise:
        trials += c.dinTrials.length;
        if (c.srtDb == null) {
          parts.add(
            const HearingPartResult(
              label: 'Digits in noise',
              assessed: false,
              note: 'Fewer than 4 rounds completed',
            ),
          );
          continue;
        }
        overall['DIN_SRT_DB'] = c.srtDb!;
        final correct = c.dinTrials.where((t) => t.correct).length;
        parts.add(
          HearingPartResult(
            label: 'Digits in noise',
            assessed: true,
            band: SemanticBand.rangeNotAvailable,
            dinTrials: c.dinTrials,
            srtDb: c.srtDb,
            note:
                'SRT ${c.srtDb!.toStringAsFixed(1)} dB SNR · $correct of ${c.dinTrials.length} triplets correct',
          ),
        );
    }
  }

  // --- Overall: better ear, grade, asymmetry -------------------------------
  final assessed = parts.where((p) => p.assessed).toList();
  final right = parts.where((p) => p.ear == HearingEar.right).firstOrNull;
  final left = parts.where((p) => p.ear == HearingEar.left).firstOrNull;
  HearingGrade? grade;
  double? betterPta;
  var asymmetric = false;
  if (protocol.mode == HearingMode.pureTone) {
    final ptas = [
      if (right?.pta4 != null) right!.pta4!,
      if (left?.pta4 != null) left!.pta4!,
    ];
    if (ptas.isNotEmpty) {
      betterPta = ptas.reduce((a, b) => a < b ? a : b);
      grade = HearingGrading.grade(betterPta);
      overall['BETTER_EAR_PTA4'] = betterPta;
    }
    if (right?.assessed == true && left?.assessed == true) {
      final asym = HearingGrading.maxAsymmetry(
        right!.thresholds,
        left!.thresholds,
      );
      if (asym != null) overall['ASYMMETRY_DB'] = asym;
      asymmetric = HearingGrading.asymmetric(right.thresholds, left.thresholds);
    }
  }

  var band = assessed.isEmpty
      ? SemanticBand.notAssessed
      : protocol.mode == HearingMode.digitsInNoise
      ? SemanticBand.rangeNotAvailable
      : _bandFor(grade ?? HearingGrade.normal);

  String heroCode;
  double? heroValue;
  String heroLabel;
  switch (protocol.mode) {
    case HearingMode.pureTone:
      heroCode = 'BETTER_EAR_PTA4';
      heroValue = betterPta;
      heroLabel = betterPta == null
          ? 'Not assessed'
          : '${betterPta.toStringAsFixed(0)} dB HL (better ear)';
    case HearingMode.digitsInNoise:
      heroCode = 'DIN_SRT_DB';
      heroValue = overall['DIN_SRT_DB'];
      heroLabel = heroValue == null
          ? 'Not assessed'
          : '${heroValue.toStringAsFixed(1)} dB SNR';
  }

  // --- Marker envelopes -----------------------------------------------------
  for (final p in parts) {
    if (p.ear != null) {
      final s = p.ear!.suffix;
      for (final hz in hearingFrequenciesHz) {
        final code = 'HEAR_${s}_$hz';
        final v = p.thresholds[hz];
        if (!p.assessed || v == null) {
          env[code] = MarkerReadings.synth(
            code,
            value: null,
            algorithmId: protocol.algorithmId,
            band: SemanticBand.notAssessed,
            status: p.skipped
                ? MarkerDisplayStatus.notAssessed
                : MarkerDisplayStatus.qualityRetakeRequired,
            reason: p.note,
            version: protocol.algorithmVersion,
          );
          continue;
        }
        env[code] = MarkerReadings.synth(
          code,
          value: v >= ToneLevel.noResponseDbHl ? 'No response' : v,
          algorithmId: protocol.algorithmId,
          band: v < HearingGrading.whoNormalMaxDbHl
              ? SemanticBand.normal
              : _bandFor(HearingGrading.grade(v)),
          reason: v >= ToneLevel.noResponseDbHl
              ? 'Not heard at 80 dB HL'
              : null,
          version: protocol.algorithmVersion,
          confidence: 0.85,
        );
      }
    } else if (protocol.mode == HearingMode.digitsInNoise) {
      env['DIN_SRT_DB'] = MarkerReadings.synth(
        'DIN_SRT_DB',
        value: p.srtDb,
        algorithmId: protocol.algorithmId,
        band: p.assessed
            ? SemanticBand.rangeNotAvailable
            : SemanticBand.notAssessed,
        status: p.assessed
            ? MarkerDisplayStatus.rangeNotAvailable
            : MarkerDisplayStatus.notAssessed,
        reason: p.assessed ? 'Normative cut-off pending (OQ-FEA-01)' : p.note,
        version: protocol.algorithmVersion,
        confidence: 0.85,
      );
    }
  }
  env['HEARING_BAND'] = MarkerReadings.synth(
    'HEARING_BAND',
    value: grade?.code,
    algorithmId: protocol.algorithmId,
    band: grade == null ? SemanticBand.notAssessed : _bandFor(grade),
    status: grade == null
        ? MarkerDisplayStatus.notAssessed
        : MarkerDisplayStatus.bandOnly,
    reason: grade == null
        ? (protocol.mode == HearingMode.digitsInNoise
              ? 'Grade needs pure-tone thresholds (Mode A)'
              : 'No ear completed')
        : null,
    version: protocol.algorithmVersion,
  );

  // --- Risk rules -----------------------------------------------------------
  final risk = RiskEngine.evaluateUrgency(
    RiskEvaluationInput(
      ptaBetterEarDbHl: betterPta,
      hearingAsymmetry: asymmetric,
    ),
    sessionId: id,
    timestamp: at,
  );
  if (risk.highestUrgency != UrgencyLevel.none && band == SemanticBand.normal) {
    band = SemanticBand.refer;
  }

  // --- Quality, confidence, baseline ----------------------------------------
  final quality = HearingQualityFacts(
    mode: protocol.mode,
    earphoneType: earphoneType,
    earphonesVerified: earphonesVerified,
    volumeAtMax: volumeAtMax,
    fullScaleDbHl: fullScaleDbHl,
    calibrationSource: calibrationSource,
    ambientMeanDba: ambientMeanDba,
    ambientMaxDba: ambientMaxDba,
    ambientSource: ambientSource,
    catchTrials: catchTrials,
    falsePositives: falsePositives,
    pauses: pauses,
    trials: trials,
    retakes: retakes,
    simulated: simulated,
  );
  final confidence = RiskEngine.computeResultConfidence(
    captureQualityScore: quality.captureQualityScore,
    modelConfidence: 0.90,
    hasRecentCaffeineSmokeOrExercise: false,
  );
  PersonalBaselineResult? baseline;
  if (heroValue != null) {
    final hist = history
        .where(
          (h) =>
              h.protocol.id == protocol.id &&
              h.heroValue != null &&
              at.difference(h.recordedAt).inDays <= 180,
        )
        .map((h) => h.heroValue!)
        .toList()
        .reversed
        .toList();
    baseline = RiskEngine.evaluateBaselineAndChange(
      historicalValidValuesWithin180Days: hist,
      currentValue: heroValue,
    );
  }

  final (title, sub, means) = _copy(
    protocol,
    band,
    grade,
    right,
    left,
    overall,
    asymmetric,
  );

  return HearingSessionResult(
    sessionId: id,
    subjectId: subject.id,
    subjectName: subject.fullName,
    ageYears: subject.ageYears,
    sex: subject.sex,
    protocol: protocol,
    recordedAt: at,
    durationSeconds: durationSeconds,
    parts: parts,
    overall: overall,
    markers: env,
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    urgency: risk.highestUrgency,
    firedRuleCodes: risk.firedRuleCodes,
    confidence: confidence,
    quality: quality,
    baseline: baseline,
    demoOutcome: demoOutcome,
    heroCode: heroCode,
    heroValue: heroValue,
    heroLabel: heroLabel,
    grade: grade,
    asymmetric: asymmetric,
  );
}

SemanticBand _bandFor(HearingGrade g) => switch (g) {
  HearingGrade.normal => SemanticBand.normal,
  HearingGrade.mild => SemanticBand.mild,
  HearingGrade.moderate => SemanticBand.moderate,
  HearingGrade.severe => SemanticBand.severe,
};

String _hzLabel(int hz) => hz >= 1000 ? '${hz ~/ 1000} kHz' : '$hz Hz';

String _ptaText(HearingPartResult? p) =>
    p == null || p.pta4 == null ? '—' : '${p.pta4!.toStringAsFixed(0)} dB HL';

(String, String, String) _copy(
  HearingProtocol p,
  SemanticBand band,
  HearingGrade? grade,
  HearingPartResult? right,
  HearingPartResult? left,
  Map<String, double> overall,
  bool asymmetric,
) {
  if (p.mode == HearingMode.digitsInNoise) {
    final srt = overall['DIN_SRT_DB'];
    if (srt == null) {
      return (
        'Not assessed',
        'The digits-in-noise round was not completed',
        'Repeat the test in a quiet room with both earphones in.',
      );
    }
    return (
      'Recorded',
      'Speech in noise: ${srt.toStringAsFixed(1)} dB SNR',
      'Lower numbers mean you can pick out speech from noise more easily. The document has no cut-off for this mode yet, so the value is kept for your own baseline; a clinic can measure thresholds with calibrated headphones.',
    );
  }
  if (grade == null) {
    return (
      'Not assessed',
      'No ear completed the four pitches',
      'Repeat the test with both earphones in a quiet room.',
    );
  }
  final ears = 'right ${_ptaText(right)} · left ${_ptaText(left)}';
  final asymNote = asymmetric
      ? ' The two ears differ by 15 dB or more at two pitches, which an ENT clinic should look at.'
      : '';
  return switch (grade) {
    HearingGrade.normal => (
      'Normal',
      'Both ears within the normal line',
      'Your better ear needed less than 20 dB to hear the beeps at every pitch, which the WHO grades as normal hearing ($ears).$asymNote',
    ),
    HearingGrade.mild => (
      'Mild loss',
      'Mild hearing loss in the better ear ($ears)',
      'The softest beeps you heard averaged 20–34 dB HL in your better ear. Soft speech and conversation in noise can be hard. Phone earphones are not calibrated, so confirm with a sound-booth audiogram.$asymNote',
    ),
    HearingGrade.moderate => (
      'Moderate loss',
      'Moderate hearing loss in the better ear ($ears)',
      'Beeps had to be 35–49 dB HL on average before you heard them in your better ear. Normal conversation is likely hard to follow; a hearing aid often helps. Confirm with pure-tone audiometry and an ENT review.$asymNote',
    ),
    HearingGrade.severe => (
      'Severe loss',
      'Severe hearing loss in the better ear ($ears)',
      'Beeps had to be 50 dB HL or louder before you heard them in your better ear. Please arrange pure-tone audiometry, tympanometry and an ENT examination.$asymNote',
    ),
  };
}
