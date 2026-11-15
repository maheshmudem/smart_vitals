// Turns the night's epochs and events into a [SleepSessionResult]
// (Doc 09 §8 AUD-07 / AUD-08, §10 RSK, Doc 08 §14.1, Doc 12 E-AUD-003).
import '../entities/enums.dart';
import '../entities/marker_envelope.dart';
import '../entities/member_profile.dart';
import '../entities/sleep_protocol.dart';
import '../entities/sleep_result.dart';
import 'marker_readings.dart';
import 'risk_engine.dart';
import 'sleep_engines.dart';

typedef SleepHistory = List<SleepSessionResult>;

SleepSessionResult buildSleepSession({
  required SleepProtocol protocol,
  required SubjectProfile subject,
  required List<SonarEpoch> epochs,
  required List<SleepEvent> events,
  required DateTime startedAt,
  required DateTime endedAt,
  required SleepQualityFacts quality,
  SleepDemoOutcome demoOutcome = SleepDemoOutcome.normal,
  SleepHistory history = const [],
  bool ringConnected = false,
  String? sessionId,
}) {
  final id = sessionId ?? 'sleep_${endedAt.millisecondsSinceEpoch}';
  final d = SleepDecision.compute(epochs, events);
  final ver = protocol.algorithmVersion;
  final env = <String, MarkerEnvelope<dynamic>>{};

  void marker(
    String code,
    Object? value, {
    required String alg,
    SemanticBand band = SemanticBand.normal,
    String? missing,
    double confidence = 0.85,
  }) {
    env[code] = MarkerReadings.synth(
      code,
      value: value,
      algorithmId: alg,
      band: value == null ? SemanticBand.notAssessed : band,
      status: value == null
          ? MarkerDisplayStatus.notAssessed
          : MarkerDisplayStatus.ok,
      reason: value == null ? missing : null,
      version: ver,
      confidence: confidence,
    );
  }

  const shortCopy =
      'Insufficient valid sleep time (< 4 h) — please repeat overnight session';
  final rr = d.medianRr;
  final rrBand = rr == null
      ? SemanticBand.notAssessed
      : (rr >= 12 && rr <= 20)
      ? SemanticBand.normal
      : SemanticBand.borderline;
  marker(
    'SONAR_RR',
    rr == null ? null : double.parse(rr.toStringAsFixed(0)),
    alg: 'ALG-AUD-07',
    band: rrBand,
    missing: 'No epoch with a clear chest echo',
    confidence: quality.sonarCheckPassed == false ? 0.6 : 0.85,
  );
  marker(
    'VALID_SLEEP_H',
    double.parse(d.validSleepH.toStringAsFixed(1)),
    alg: 'ALG-AUD-08',
    band: d.partial ? SemanticBand.borderline : SemanticBand.normal,
    confidence: 0.95,
  );
  final osaSemantic = switch (d.band) {
    null => SemanticBand.notAssessed,
    OsaBand.normal => SemanticBand.normal,
    OsaBand.mild => SemanticBand.mild,
    OsaBand.moderate => SemanticBand.moderate,
    OsaBand.severe => SemanticBand.critical,
  };
  marker(
    'APNOEA_EVENTS',
    d.partial ? null : d.apnoeaEvents.toDouble(),
    alg: 'ALG-AUD-08',
    band: d.apnoeaEvents == 0 ? SemanticBand.normal : osaSemantic,
    missing: shortCopy,
  );
  marker(
    'HYPOPNOEA_EVENTS',
    d.partial ? null : d.hypopnoeaEvents.toDouble(),
    alg: 'ALG-AUD-08',
    band: d.hypopnoeaEvents == 0 ? SemanticBand.normal : osaSemantic,
    missing: shortCopy,
  );
  marker(
    'AHI_EST',
    d.ahi == null ? null : double.parse(d.ahi!.toStringAsFixed(1)),
    alg: 'ALG-AUD-08',
    band: osaSemantic,
    missing: shortCopy,
    confidence: quality.sonarCheckPassed == false ? 0.6 : 0.85,
  );
  marker(
    'OSA_BAND',
    d.band == null ? null : OsaBands.label(d.band!),
    alg: 'ALG-AUD-08',
    band: osaSemantic,
    missing: shortCopy,
    confidence: quality.sonarCheckPassed == false ? 0.6 : 0.85,
  );

  // --- Risk rule (T42 [DER]) ------------------------------------------------
  final evaluation = RiskEngine.evaluateUrgency(
    RiskEvaluationInput(ahiEst: d.ahi),
    sessionId: id,
    timestamp: endedAt,
  );

  // --- Band + copy ------------------------------------------------------------
  final SemanticBand band;
  final String title;
  final String sub;
  final String means;
  if (rr == null) {
    band = SemanticBand.notAssessed;
    title = 'Not assessed';
    sub = 'No clear chest echo during the night';
    means =
        'The phone did not pick up a breathing echo. Place it flat on the bedside table 30 cm to 1 m from your chest with nothing in between, plugged in, and repeat the night (G-30).';
  } else if (d.partial) {
    band = SemanticBand.notAssessed;
    title = 'Breathing rate only';
    sub =
        '${d.validSleepH.toStringAsFixed(1)} h valid sleep — apnoea index not computed';
    means = protocol.shortNightCopy;
  } else {
    band = osaSemantic;
    final ahiTxt = d.ahi!.toStringAsFixed(1);
    switch (d.band!) {
      case OsaBand.normal:
        title = 'Normal';
        sub = 'AHI $ahiTxt per hour — under 5';
        means =
            'Breathing paused or became shallow fewer than 5 times per hour of valid sleep. No sign of sleep apnoea on this night. Repeat if snoring, daytime sleepiness or a partner\'s report persists.';
      case OsaBand.mild:
        title = 'Mild';
        sub = 'AHI $ahiTxt per hour — mild range (5–14)';
        means =
            'Breathing paused or became shallow 5 to 14 times per hour. This is the mild range: no referral rule fires, but discuss snoring, weight, alcohol in the evening and sleeping on your side with a clinician, and repeat the night in a few weeks.';
      case OsaBand.moderate:
        title = 'Moderate';
        sub = 'AHI $ahiTxt per hour — moderate range (15–29)';
        means =
            'Breathing paused or became shallow 15 to 29 times per hour. The document asks for a confirmatory home sleep apnoea test or polysomnography within 60 days (Routine). A COND_OSA case has been opened.';
      case OsaBand.severe:
        title = 'Severe';
        sub = 'AHI $ahiTxt per hour — severe range (≥ 30)';
        means =
            'Breathing paused or became shallow 30 or more times per hour. Book a home sleep apnoea test or polysomnography within 60 days (Routine referral per §13.2); do not drive when sleepy. A COND_OSA case has been opened.';
    }
  }

  // --- Confidence + baselines ------------------------------------------------
  final confidence = RiskEngine.computeResultConfidence(
    captureQualityScore: quality.captureQualityScore,
    modelConfidence: d.partial ? 0.80 : 0.82,
    hasRecentCaffeineSmokeOrExercise: false,
  );
  PersonalBaselineResult? baseline;
  PersonalBaselineResult? rrBaseline;
  List<double> hist(double? Function(SleepSessionResult) pick) => history
      .where(
        (h) =>
            h.protocol.id == protocol.id &&
            pick(h) != null &&
            endedAt.difference(h.recordedAt).inDays <= 180,
      )
      .map((h) => pick(h)!)
      .toList()
      .reversed
      .toList();
  if (d.ahi != null) {
    baseline = RiskEngine.evaluateBaselineAndChange(
      historicalValidValuesWithin180Days: hist((h) => h.ahiEst),
      currentValue: d.ahi!,
    );
  }
  if (rr != null) {
    rrBaseline = RiskEngine.evaluateBaselineAndChange(
      historicalValidValuesWithin180Days: hist((h) => h.medianRr),
      currentValue: rr,
    );
  }

  return SleepSessionResult(
    sessionId: id,
    subjectId: subject.id,
    subjectName: subject.fullName,
    ageYears: subject.ageYears,
    sex: subject.sex,
    protocol: protocol,
    startedAt: startedAt,
    endedAt: endedAt,
    durationSeconds: endedAt.difference(startedAt).inSeconds,
    validSleepH: d.validSleepH,
    recordedH: d.recordedH,
    rrEpochs: [for (final e in epochs) e.valid ? e.rr : null],
    epochValid: [for (final e in epochs) e.valid],
    medianRr: rr,
    apnoeaEvents: d.apnoeaEvents,
    hypopnoeaEvents: d.hypopnoeaEvents,
    ahiEst: d.ahi,
    osaBand: d.band,
    events: events,
    markers: env,
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    urgency: evaluation.highestUrgency,
    firedRuleCodes: evaluation.firedRuleCodes,
    confidence: confidence,
    quality: quality,
    partial: d.partial,
    demoOutcome: demoOutcome,
    ringConnected: ringConnected,
    baseline: baseline,
    rrBaseline: rrBaseline,
  );
}
