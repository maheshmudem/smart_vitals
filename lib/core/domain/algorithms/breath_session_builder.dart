// Turns raw Breathing & Voice task captures into a [BreathSessionResult]
// (Doc 09 §8 AUD-01/03/04/05/06, §5 FRM-13, §10 RSK, Doc 08 §14.2).
import '../entities/breath_protocol.dart';
import '../entities/breath_result.dart';
import '../entities/enums.dart';
import '../entities/marker_envelope.dart';
import '../entities/member_profile.dart';
import 'breath_engines.dart';
import 'marker_readings.dart';
import 'mind_engines.dart' show VoiceFeatures;
import 'risk_engine.dart';

/// Raw capture for one task.
class BreathTaskCapture {
  const BreathTaskCapture({
    required this.taskId,
    this.skipped = false,
    this.skipReason,
    this.answers = const {},
    this.features,
    this.coughs,
    this.wheeze,
    this.efforts = const [],
    this.samples,
    this.durationS,
    this.attempts = 1,
    this.clipAccepted = false,
  });

  final String taskId;
  final bool skipped;
  final String? skipReason;
  final Map<String, int> answers;

  /// Features of the whole take (clip / SNR for CAP-13).
  final VoiceFeatures? features;
  final CoughDetection? coughs;
  final WheezeResult? wheeze;

  /// Every forced-exhale effort of the task (3–5).
  final List<ExhaleEffort> efforts;

  /// Raw PCM16 of phonation tasks (the voice engine runs here).
  final List<int>? samples;
  final double? durationS;
  final int attempts;

  /// Take kept despite clipping > 1 % after two re-records (CAP-13 warning).
  final bool clipAccepted;

  bool get hasAudio => features != null && !skipped;
}

typedef BreathHistory = List<BreathSessionResult>;

BreathSessionResult buildBreathSession({
  required BreathProtocol protocol,
  required SubjectProfile subject,
  required List<BreathTaskCapture> captures,
  required BreathDemoOutcome demoOutcome,
  BreathHistory history = const [],
  String audioSource = 'simulated',
  double? ambientDba,
  MicSelfCheckResult? micCheck,
  int retakes = 0,
  bool simulated = true,
  int durationSeconds = 0,
  String? sessionId,
  DateTime? now,
  int sampleRate = 16000,
}) {
  final at = now ?? DateTime.now();
  final id = sessionId ?? 'breath_${at.millisecondsSinceEpoch}';
  final parts = <BreathPartResult>[];
  final env = <String, MarkerEnvelope<dynamic>>{};
  final overall = <String, double>{};
  final clipByTask = <String, double>{};
  final snrByTask = <String, double>{};
  final attemptsByTask = <String, int>{};
  final byId = {for (final c in captures) c.taskId: c};
  final ver = protocol.algorithmVersion;

  final durationByTask = <String, double>{};
  final clipAcceptedTasks = <String>[];
  for (final c in captures) {
    attemptsByTask[c.taskId] = c.attempts;
    if (c.durationS != null && !c.skipped) {
      durationByTask[c.taskId] = c.durationS!;
    }
    if (c.clipAccepted) clipAcceptedTasks.add(c.taskId);
    if (c.features != null && !c.skipped) {
      clipByTask[c.taskId] = c.features!.clipPct;
      snrByTask[c.taskId] = c.features!.snrDb;
    }
    for (var i = 0; i < c.efforts.length; i++) {
      clipByTask['${c.taskId}_${i + 1}'] = c.efforts[i].clipPct;
      snrByTask['${c.taskId}_${i + 1}'] = c.efforts[i].snrDb;
    }
  }

  BreathPartResult skippedPart(BreathTask t, BreathTaskCapture? c) =>
      BreathPartResult(
        id: t.id,
        label: t.title,
        assessed: false,
        skipped: true,
        note: c?.skipReason ?? 'Skipped',
        attempts: c?.attempts ?? 0,
      );

  void marker(
    String code,
    Object? value, {
    required String alg,
    SemanticBand band = SemanticBand.normal,
    MarkerDisplayStatus? status,
    String? missing,
    double confidence = 0.85,
  }) {
    env[code] = MarkerReadings.synth(
      code,
      value: value,
      algorithmId: alg,
      band: value == null ? SemanticBand.notAssessed : band,
      status:
          status ??
          (value == null
              ? MarkerDisplayStatus.notAssessed
              : MarkerDisplayStatus.ok),
      reason: value == null ? missing : null,
      version: ver,
      confidence: confidence,
    );
  }

  String fmt(double v, int dec) => v.toStringAsFixed(dec);

  var band = SemanticBand.notAssessed;
  var risk = const _BreathRisk();
  CoughDetection? coughs;
  WheezeResult? wheeze;
  SpirometryEstimate? spiro;
  VoiceQualityResult? voice;
  OadScore? oad;
  var tbClassic = false;
  var tbSymptoms = const <String>[];
  var exposures = const <String>[];
  String? bodyProfile;
  String? predictedSource;
  var effortsDone = 0;
  bool? repeatable;
  double? repeatDiff;

  final heightCm = subject.heightCm;
  final pred = SpirometryReference.predict(
    sex: subject.sex,
    heightCm: heightCm ?? 165,
    ageYears: subject.ageYears,
  );
  if (heightCm != null) {
    bodyProfile =
        '${fmt(heightCm, 0)} cm · ${subject.ageYears} y · ${subject.sex.label.toLowerCase()}';
  }

  // Shared cough part (coughTb and airway).
  BreathPartResult coughPart(BreathTask t, BreathTaskCapture c) {
    final d = c.coughs ?? CoughDetection.none;
    final ok = d.enough;
    return BreathPartResult(
      id: t.id,
      label: 'Coughs',
      assessed: true,
      attempts: c.attempts,
      band: ok
          ? SemanticBand.normal
          : d.count > 0
          ? SemanticBand.borderline
          : SemanticBand.notAssessed,
      values: {
        'COUGH_COUNT_VALID': d.count.toDouble(),
        'CANDIDATES': d.candidates.length.toDouble(),
        'WETNESS': d.meanWetness,
        'MEAN_MS': d.meanDurationMs,
      },
      items: [
        for (final e in d.events)
          '${(e.startMs / 1000).toStringAsFixed(1)} s · ${e.durationMs} ms · p ${e.prob.toStringAsFixed(2)}',
      ],
      note: ok
          ? '${d.count} valid cough${d.count == 1 ? '' : 's'} (${d.candidates.length} burst${d.candidates.length == 1 ? '' : 's'} examined) · mean ${fmt(d.meanDurationMs, 0)} ms · wetness ${fmt(d.meanWetness, 2)} · ${c.attempts} attempt${c.attempts == 1 ? '' : 's'}'
          : '${d.count} valid cough${d.count == 1 ? '' : 's'} after ${c.attempts} attempt${c.attempts == 1 ? '' : 's'} — fewer than the 3 the document needs (E-AUD-001)',
    );
  }

  switch (protocol.kind) {
    // ── Cough & TB (AUD-01 + AUD-03) ─────────────────────────────────────
    case BreathKind.coughTb:
      Map<String, int>? answers;
      for (final t in protocol.tasks) {
        final c = byId[t.id];
        if (t.type == BreathTaskType.questionnaire) {
          final q = t.questionnaire!;
          if (c == null ||
              c.skipped ||
              q.questions.any((x) => !c.answers.containsKey(x.id))) {
            parts.add(skippedPart(t, c));
            continue;
          }
          answers = c.answers;
          tbClassic = TbSymptoms.classic(answers);
          tbSymptoms = TbSymptoms.positives(answers);
          parts.add(
            BreathPartResult(
              id: t.id,
              label: 'TB symptoms (Q_TB_SYMPTOMS)',
              assessed: true,
              answers: answers,
              items: tbSymptoms,
              band: tbClassic
                  ? SemanticBand.high
                  : tbSymptoms.isNotEmpty
                  ? SemanticBand.borderline
                  : SemanticBand.normal,
              values: {'SYMPTOM_COUNT': tbSymptoms.length.toDouble()},
              note: tbClassic
                  ? 'Classic TB symptoms: ${tbSymptoms.join(', ')} → high band on the questions alone'
                  : tbSymptoms.isEmpty
                  ? 'No TB symptoms reported'
                  : '${tbSymptoms.join(', ')} — noted, not classic on its own',
            ),
          );
        } else {
          if (c == null || c.skipped || c.coughs == null) {
            parts.add(skippedPart(t, c));
            continue;
          }
          coughs = c.coughs;
          parts.add(coughPart(t, c));
        }
      }
      final enough = coughs?.enough ?? false;
      final prob = answers == null
          ? null
          : TbModel.prob(coughs: enough ? coughs : null, symptoms: answers);
      final tbBand = prob == null
          ? null
          : TbModel.band(prob, classicSymptoms: tbClassic);
      if (prob != null) overall['TB_PROB'] = prob;
      if (coughs != null) {
        overall['COUGH_COUNT_VALID'] = coughs.count.toDouble();
      }
      marker(
        'COUGH_COUNT_VALID',
        coughs?.count,
        alg: 'ALG-AUD-01',
        band: enough ? SemanticBand.normal : SemanticBand.borderline,
        missing: 'Cough task not completed',
        confidence: 0.80,
      );
      marker(
        'TB_PROB',
        prob,
        alg: 'ALG-AUD-03',
        band: SemanticBand.inValidation,
        status: prob == null
            ? MarkerDisplayStatus.notAssessed
            : MarkerDisplayStatus.inValidation,
        missing: 'Questionnaire not completed',
        confidence: 0.70,
      );
      marker(
        'TB_BAND',
        tbBand?.name,
        alg: 'ALG-AUD-03',
        band: tbBand ?? SemanticBand.notAssessed,
        missing: 'Questionnaire not completed',
        confidence: 0.75,
      );
      band = tbBand ?? SemanticBand.notAssessed;
      risk = _BreathRisk(tbBand: tbBand);

    // ── Airway obstruction (AUD-04) ─────────────────────────────────────
    case BreathKind.airway:
      int? mmrc;
      var exposureAnswers = const <String, int>{};
      double? ratio;
      double? wheezeShare;
      for (final t in protocol.tasks) {
        final c = byId[t.id];
        switch (t.type) {
          case BreathTaskType.questionnaire:
            final q = t.questionnaire!;
            if (c == null ||
                c.skipped ||
                q.questions.any((x) => !c.answers.containsKey(x.id))) {
              parts.add(skippedPart(t, c));
              continue;
            }
            if (q.id == 'Q_MMRC') {
              mmrc = c.answers['mmrc'];
              parts.add(
                BreathPartResult(
                  id: t.id,
                  label: 'Breathlessness (Q_MMRC)',
                  assessed: true,
                  answers: c.answers,
                  values: {'MMRC': (mmrc ?? 0).toDouble()},
                  band: (mmrc ?? 0) >= 2
                      ? SemanticBand.borderline
                      : SemanticBand.normal,
                  note:
                      'mMRC grade $mmrc of 4 — ${BreathTexts.mmrc.questions.first.options[(mmrc ?? 0).clamp(0, 4)].toLowerCase()}',
                ),
              );
            } else {
              exposureAnswers = c.answers;
              exposures = ExposureScore.labels(c.answers);
              final score = ExposureScore.of(c.answers);
              parts.add(
                BreathPartResult(
                  id: t.id,
                  label: 'Smoke & dust (Q_EXPOSURE)',
                  assessed: true,
                  answers: c.answers,
                  items: exposures,
                  values: {'EXPOSURE_SCORE': score},
                  band: score >= 0.5
                      ? SemanticBand.borderline
                      : SemanticBand.normal,
                  note:
                      '${exposures.join(' · ')} · exposure score ${fmt(score, 2)}',
                ),
              );
            }
          case BreathTaskType.cough:
            if (c == null || c.skipped || c.coughs == null) {
              parts.add(skippedPart(t, c));
              continue;
            }
            coughs = c.coughs;
            parts.add(coughPart(t, c));
          case BreathTaskType.phonation:
            if (c == null || c.skipped || c.samples == null) {
              parts.add(skippedPart(t, c));
              continue;
            }
            final v = VoiceQuality.analyze(
              aaa: c.samples!,
              sr: sampleRate,
              adult: subject.isAdult,
            );
            voice = v;
            parts.add(
              BreathPartResult(
                id: t.id,
                label: 'Sustained "aaa" (AUD-06 features)',
                assessed: v.phonationOk,
                values: {
                  'F0_HZ': v.f0Hz,
                  'JITTER_PCT': v.jitterPct,
                  'SHIMMER_PCT': v.shimmerPct,
                  'HNR_DB': v.hnrDb,
                  'HELD_S': v.mptS,
                },
                band: v.phonationOk
                    ? (v.bandOf('JITTER_PCT') == SemanticBand.normal &&
                              v.bandOf('HNR_DB') == SemanticBand.normal
                          ? SemanticBand.normal
                          : SemanticBand.borderline)
                    : SemanticBand.notAssessed,
                note: v.phonationOk
                    ? 'Held ${fmt(v.mptS, 1)} s · pitch ${fmt(v.f0Hz, 0)} Hz · jitter ${fmt(v.jitterPct, 2)} % · shimmer ${fmt(v.shimmerPct, 2)} % · HNR ${fmt(v.hnrDb, 1)} dB'
                    : 'Phonation shorter than 3 s — voice features not used',
              ),
            );
          case BreathTaskType.breathSounds:
            if (c == null || c.skipped || c.wheeze == null) {
              parts.add(skippedPart(t, c));
              continue;
            }
            wheeze = c.wheeze;
            wheezeShare = wheeze!.wheezeShare;
            parts.add(
              BreathPartResult(
                id: t.id,
                label: 'Breath sounds · wheeze',
                assessed: wheeze.heard,
                values: {
                  'WHEEZE_SHARE': wheeze.wheezeShare,
                  'WHEEZE_SEGMENTS': wheeze.segments.toDouble(),
                  'WHEEZE_HZ': wheeze.dominantHz,
                  'BREATHING_S': wheeze.breathingMs / 1000,
                },
                band: !wheeze.heard
                    ? SemanticBand.notAssessed
                    : wheeze.wheezeShare >= 0.10
                    ? SemanticBand.borderline
                    : SemanticBand.normal,
                note: !wheeze.heard
                    ? 'Breathing was too quiet to analyse — breathe through the mouth, closer to the phone'
                    : wheeze.segments == 0
                    ? 'No tonal peak lasting ≥ 100 ms in ${fmt(wheeze.breathingMs / 1000, 0)} s of breathing'
                    : '${wheeze.segments} wheeze segment${wheeze.segments == 1 ? '' : 's'} (≥ 100 ms) · ${fmt(wheeze.wheezeShare * 100, 0)} % of breathing time · around ${fmt(wheeze.dominantHz, 0)} Hz',
              ),
            );
          case BreathTaskType.forcedExhale:
            final valid =
                c?.efforts.where((e) => e.longEnough).toList() ??
                const <ExhaleEffort>[];
            if (c == null || c.skipped || valid.isEmpty) {
              parts.add(skippedPart(t, c));
              continue;
            }
            effortsDone = c.efforts.length;
            spiro = AudioSpirometry.estimate(c.efforts, pred);
            predictedSource = pred.source;
            ratio = spiro.ratio;
            parts.add(
              BreathPartResult(
                id: t.id,
                label: 'Hard blow · FEV1/FVC',
                assessed: true,
                attempts: c.attempts,
                values: {
                  'FEV1_FVC': ratio!,
                  'RATIO_LLN': pred.ratioLln,
                  'BLOW_S': spiro.best!.effort.durationS,
                },
                flags: {'BELOW_LLN': spiro.belowLln},
                band: spiro.belowLln
                    ? SemanticBand.borderline
                    : SemanticBand.normal,
                note:
                    'FEV1/FVC ${fmt(ratio, 2)} vs lower limit ${fmt(pred.ratioLln, 2)}${heightCm == null ? ' (profile height missing — 165 cm assumed)' : ''} · blow ${fmt(spiro.best!.effort.durationS, 1)} s${spiro.belowLln ? ' → below the limit' : ''}',
              ),
            );
        }
      }
      final haveMinimum = coughs != null && ratio != null && mmrc != null;
      oad = OadModel.score(
        wheezeShare: wheezeShare,
        coughWetness: coughs?.meanWetness,
        ratio: ratio,
        ratioLln: ratio == null ? null : pred.ratioLln,
        mmrc: mmrc,
        exposureAnswers: exposureAnswers,
        ageYears: subject.ageYears,
      );
      final anyAssessed = parts.any((p) => p.assessed);
      if (anyAssessed) {
        overall['OAD_PROB'] = oad.prob;
        overall['ASTHMA_VS_COPD_PROB'] = oad.asthmaVsCopd;
        if (wheezeShare != null) overall['WHEEZE_SHARE'] = wheezeShare;
        if (ratio != null) overall['FEV1_FVC'] = ratio;
      }
      marker(
        'OAD_PROB',
        anyAssessed ? oad.prob : null,
        alg: 'ALG-AUD-04',
        band: SemanticBand.inValidation,
        status: anyAssessed
            ? MarkerDisplayStatus.inValidation
            : MarkerDisplayStatus.notAssessed,
        missing: 'No task completed',
        confidence: 0.70,
      );
      marker(
        'OAD_BAND',
        anyAssessed ? oad.band.name : null,
        alg: 'ALG-AUD-04',
        band: oad.band,
        missing: 'No task completed',
        confidence: haveMinimum ? 0.75 : 0.6,
      );
      marker(
        'ASTHMA_VS_COPD_PROB',
        anyAssessed ? oad.asthmaVsCopd : null,
        alg: 'ALG-AUD-04',
        band: SemanticBand.inValidation,
        status: anyAssessed
            ? MarkerDisplayStatus.inValidation
            : MarkerDisplayStatus.notAssessed,
        missing: 'No task completed',
        confidence: 0.6,
      );
      band = anyAssessed ? oad.band : SemanticBand.notAssessed;
      risk = _BreathRisk(oadBand: anyAssessed ? oad.band : null);

    // ── Lung function (AUD-05 + FRM-13) ─────────────────────────────────
    case BreathKind.lungFunction:
      final t = protocol.tasks.first;
      final c = byId[t.id];
      final valid =
          c?.efforts.where((e) => e.longEnough).toList() ??
          const <ExhaleEffort>[];
      if (c == null || c.skipped || valid.isEmpty) {
        parts.add(skippedPart(t, c));
      } else {
        effortsDone = c.efforts.length;
        spiro = AudioSpirometry.estimate(c.efforts, pred);
        predictedSource = pred.source;
        repeatable = spiro.repeatable;
        repeatDiff = spiro.repeatabilityDiffPct;
        final b = spiro.best!;
        overall['FEV1_L'] = b.fev1;
        overall['FVC_L'] = b.fvc;
        overall['FEV1_FVC'] = b.ratio;
        overall['PEF_LS'] = b.pef;
        overall['fev1_pred_pct'] = spiro.fev1PredPct!;
        overall['fvc_pred_pct'] = spiro.fvcPredPct!;
        overall['ratio_lln'] = pred.ratioLln;
        final below = spiro.belowLln;
        parts.add(
          BreathPartResult(
            id: t.id,
            label:
                'Best of ${c.efforts.length} blow${c.efforts.length == 1 ? '' : 's'}',
            assessed: true,
            attempts: c.efforts.length,
            values: {
              'FEV1_L': b.fev1,
              'FVC_L': b.fvc,
              'FEV1_FVC': b.ratio,
              'PEF_LS': b.pef,
              'fev1_pred_pct': spiro.fev1PredPct!,
              'fvc_pred_pct': spiro.fvcPredPct!,
              'ratio_lln': pred.ratioLln,
              'BLOW_S': b.effort.durationS,
            },
            flags: {'BELOW_LLN': below, 'REPEATABLE': spiro.repeatable},
            band: below ? SemanticBand.refer : SemanticBand.normal,
            note:
                'Blow ${b.index + 1} · FEV1 ${fmt(b.fev1, 2)} L (${fmt(spiro.fev1PredPct!, 0)} % pred) · FVC ${fmt(b.fvc, 2)} L (${fmt(spiro.fvcPredPct!, 0)} % pred) · ratio ${fmt(b.ratio, 2)} vs LLN ${fmt(pred.ratioLln, 2)} · PEF ${fmt(b.pef, 1)} L/s · ${spiro.repeatable ? 'best two within ${fmt(repeatDiff ?? 0, 0)} %' : 'not repeatable (${repeatDiff == null ? 'one valid blow' : '${fmt(repeatDiff, 0)} % apart'})'}',
          ),
        );
        band = below ? SemanticBand.refer : SemanticBand.normal;
        risk = _BreathRisk(fev1FvcBelowLln: below);
      }
      final b = spiro?.best;
      final below = spiro?.belowLln ?? false;
      marker(
        'FEV1_L',
        b?.fev1,
        alg: 'ALG-AUD-05',
        band: below ? SemanticBand.refer : SemanticBand.normal,
        missing: 'No blow of ≥ 3 s recorded',
      );
      marker(
        'FVC_L',
        b?.fvc,
        alg: 'ALG-AUD-05',
        missing: 'No blow of ≥ 3 s recorded',
      );
      marker(
        'FEV1_FVC',
        b?.ratio,
        alg: 'ALG-AUD-05',
        band: below ? SemanticBand.refer : SemanticBand.normal,
        missing: 'No blow of ≥ 3 s recorded',
      );
      marker(
        'PEF_LS',
        b?.pef,
        alg: 'ALG-AUD-05',
        missing: 'No blow of ≥ 3 s recorded',
      );
      marker(
        'fev1_pred_pct',
        spiro?.fev1PredPct?.roundToDouble(),
        alg: 'ALG-FRM-13',
        band: (spiro?.fev1PredPct ?? 100) < 80
            ? SemanticBand.borderline
            : SemanticBand.normal,
        missing: 'Needs a valid blow and the body profile (G-02)',
      );
      marker(
        'fvc_pred_pct',
        spiro?.fvcPredPct?.roundToDouble(),
        alg: 'ALG-FRM-13',
        band: (spiro?.fvcPredPct ?? 100) < 80
            ? SemanticBand.borderline
            : SemanticBand.normal,
        missing: 'Needs a valid blow and the body profile (G-02)',
      );
      marker(
        'ratio_lln',
        spiro == null ? null : pred.ratioLln,
        alg: 'ALG-FRM-13',
        missing: 'Needs the body profile (G-02)',
        confidence: 0.9,
      );

    // ── Voice quality (AUD-06) ──────────────────────────────────────────
    case BreathKind.voice:
      final aaa = byId['aaa'];
      final sss = byId['sss'];
      final zzz = byId['zzz'];
      final sentence = byId['sentence'];
      List<int>? samplesOf(BreathTaskCapture? c) =>
          c == null || c.skipped ? null : c.samples;
      if (samplesOf(aaa) == null) {
        parts.add(skippedPart(protocol.tasks.first, aaa));
      } else {
        voice = VoiceQuality.analyze(
          aaa: samplesOf(aaa)!,
          sss: samplesOf(sss),
          zzz: samplesOf(zzz),
          sr: sampleRate,
          adult: subject.isAdult,
        );
        final v = voice;
        for (final e in {
          'F0_HZ': v.f0Hz,
          'JITTER_PCT': v.jitterPct,
          'SHIMMER_PCT': v.shimmerPct,
          'HNR_DB': v.hnrDb,
          'CPPS_DB': v.cppsDb,
          'MPT_S': v.mptS,
          if (v.szRatio != null) 'SZ_RATIO': v.szRatio!,
        }.entries) {
          overall[e.key] = e.value;
        }
        final aaaBands = [
          v.bandOf('JITTER_PCT'),
          v.bandOf('SHIMMER_PCT'),
          v.bandOf('HNR_DB'),
          v.bandOf('MPT_S'),
        ];
        parts.add(
          BreathPartResult(
            id: 'aaa',
            label: 'Sustained "aaa" · steadiness',
            assessed: v.phonationOk,
            attempts: aaa!.attempts,
            values: {
              'F0_HZ': v.f0Hz,
              'JITTER_PCT': v.jitterPct,
              'SHIMMER_PCT': v.shimmerPct,
              'HNR_DB': v.hnrDb,
              'CPPS_DB': v.cppsDb,
              'MPT_S': v.mptS,
            },
            band: !v.phonationOk
                ? SemanticBand.notAssessed
                : aaaBands.contains(SemanticBand.borderline)
                ? SemanticBand.borderline
                : SemanticBand.normal,
            note: !v.phonationOk
                ? 'Phonation shorter than 3 s — hold "aaa" for at least 5 s'
                : 'Held ${fmt(v.mptS, 1)} s (MPT) · pitch ${fmt(v.f0Hz, 0)} Hz · jitter ${fmt(v.jitterPct, 2)} % · shimmer ${fmt(v.shimmerPct, 2)} % · HNR ${fmt(v.hnrDb, 1)} dB · CPPS ${fmt(v.cppsDb, 1)} dB',
          ),
        );
        parts.add(
          v.szRatio == null
              ? BreathPartResult(
                  id: 'sz',
                  label: '"sss" / "zzz" ratio',
                  assessed: false,
                  skipped: true,
                  note: samplesOf(sss) == null || samplesOf(zzz) == null
                      ? 'One of the two sounds was skipped'
                      : '"zzz" too short to time',
                )
              : BreathPartResult(
                  id: 'sz',
                  label: '"sss" / "zzz" ratio',
                  assessed: true,
                  values: {'S_S': v.sS!, 'Z_S': v.zS!, 'SZ_RATIO': v.szRatio!},
                  band: v.bandOf('SZ_RATIO'),
                  note:
                      '"sss" ${fmt(v.sS!, 1)} s ÷ "zzz" ${fmt(v.zS!, 1)} s = ${fmt(v.szRatio!, 2)} (normal < 1.4)',
                ),
        );
        final sf = sentence?.features;
        parts.add(
          sentence == null || sentence.skipped || sf == null
              ? skippedPart(protocol.tasks.last, sentence)
              : BreathPartResult(
                  id: 'sentence',
                  label: 'Sentence · connected speech',
                  assessed: sf.heardSpeech,
                  values: {
                    'SPEECH_S': sf.speechTimeS,
                    'F0_HZ': sf.meanF0Hz,
                    'F0_SD': sf.f0SdHz,
                    'SYL_PER_SEC': sf.syllablesPerSec,
                  },
                  band: sf.heardSpeech
                      ? SemanticBand.rangeNotAvailable
                      : SemanticBand.notAssessed,
                  note: sf.heardSpeech
                      ? '${fmt(sf.speechTimeS, 1)} s of speech · pitch ${fmt(sf.meanF0Hz, 0)} Hz (sd ${fmt(sf.f0SdHz, 0)}) · ${fmt(sf.syllablesPerSec, 1)} syllables/s — recorded for the clinician, no norm'
                      : 'Sentence not heard',
                ),
        );
        band = !v.phonationOk
            ? SemanticBand.notAssessed
            : v.outsideNormCount == 0
            ? SemanticBand.normal
            : SemanticBand.borderline;
      }
      final v = voice;
      final ok = v != null && v.phonationOk;
      marker(
        'F0_HZ',
        ok ? v.f0Hz : null,
        alg: 'ALG-AUD-06',
        band: SemanticBand.rangeNotAvailable,
        status: ok
            ? MarkerDisplayStatus.rangeNotAvailable
            : MarkerDisplayStatus.notAssessed,
        missing: '"aaa" shorter than 3 s',
        confidence: 0.9,
      );
      for (final code in ['JITTER_PCT', 'SHIMMER_PCT', 'HNR_DB', 'MPT_S']) {
        marker(
          code,
          ok ? overall[code] : null,
          alg: 'ALG-AUD-06',
          band: v?.bandOf(code) ?? SemanticBand.notAssessed,
          status: !ok
              ? MarkerDisplayStatus.notAssessed
              : v.bandOf(code) == SemanticBand.rangeNotAvailable
              ? MarkerDisplayStatus.rangeNotAvailable
              : MarkerDisplayStatus.ok,
          missing: '"aaa" shorter than 3 s',
          confidence: 0.9,
        );
      }
      marker(
        'CPPS_DB',
        ok ? v.cppsDb : null,
        alg: 'ALG-AUD-06',
        band: SemanticBand.rangeNotAvailable,
        status: ok
            ? MarkerDisplayStatus.rangeNotAvailable
            : MarkerDisplayStatus.notAssessed,
        missing: '"aaa" shorter than 3 s',
        confidence: 0.8,
      );
      marker(
        'SZ_RATIO',
        v?.szRatio,
        alg: 'ALG-AUD-06',
        band: v?.bandOf('SZ_RATIO') ?? SemanticBand.notAssessed,
        missing: '"sss" or "zzz" not recorded',
        confidence: 0.9,
      );
  }

  // --- Risk rules -----------------------------------------------------------
  final evaluation = RiskEngine.evaluateUrgency(
    RiskEvaluationInput(
      tbBand: risk.tbBand,
      oadBand: risk.oadBand,
      fev1FvcBelowLln: risk.fev1FvcBelowLln,
    ),
    sessionId: id,
    timestamp: at,
  );
  if (evaluation.highestUrgency != UrgencyLevel.none &&
      band == SemanticBand.normal) {
    band = SemanticBand.refer;
  }

  // --- Hero -------------------------------------------------------------------
  String heroCode;
  double? heroValue;
  String heroLabel;
  switch (protocol.kind) {
    case BreathKind.coughTb:
      heroCode = 'TB_BAND';
      heroValue = overall['COUGH_COUNT_VALID'];
      final tb = env['TB_BAND']?.value;
      heroLabel = tb == null
          ? 'Not assessed'
          : 'TB band ${tb.toString().toUpperCase()} · ${overall['COUGH_COUNT_VALID']?.toStringAsFixed(0) ?? '0'} valid coughs';
    case BreathKind.airway:
      heroCode = 'OAD_BAND';
      heroValue = overall['OAD_PROB'];
      heroLabel = heroValue == null
          ? 'Not assessed'
          : 'Obstruction band ${band.name.toUpperCase()}';
    case BreathKind.lungFunction:
      heroCode = 'FEV1_FVC';
      heroValue = overall['FEV1_FVC'];
      heroLabel = heroValue == null
          ? 'Not assessed'
          : 'FEV1/FVC ${fmt(heroValue, 2)} vs LLN ${fmt(pred.ratioLln, 2)}';
    case BreathKind.voice:
      heroCode = 'JITTER_PCT';
      heroValue = overall['JITTER_PCT'];
      heroLabel = heroValue == null
          ? 'Not assessed'
          : 'Jitter ${fmt(heroValue, 2)} % · MPT ${fmt(overall['MPT_S'] ?? 0, 1)} s';
  }

  // --- Quality, confidence, baseline ----------------------------------------
  final quality = BreathQualityFacts(
    kind: protocol.kind,
    audioSource: audioSource,
    micDeviationDb: micCheck?.deviationDb,
    micProcessingDetected: micCheck?.processingDetected ?? false,
    micSelfCheckPassed: micCheck?.passed ?? false,
    ambientDba: ambientDba,
    clipByTask: clipByTask,
    snrByTask: snrByTask,
    attemptsByTask: attemptsByTask,
    effortsDone: effortsDone,
    repeatable: repeatable,
    repeatabilityDiffPct: repeatDiff,
    bodyProfile: bodyProfile,
    predictedSource: predictedSource,
    retakes: retakes,
    simulated: simulated,
    micSource: micCheck == null
        ? null
        : micCheck.manual
        ? 'manual'
        : micCheck.source,
    durationByTask: durationByTask,
    clipAcceptedTasks: clipAcceptedTasks,
  );
  final modelConfidence = switch (protocol.kind) {
    BreathKind.coughTb => 0.80,
    BreathKind.airway => 0.78,
    BreathKind.lungFunction => 0.85,
    BreathKind.voice => 0.92,
  };
  final confidence = RiskEngine.computeResultConfidence(
    captureQualityScore: quality.captureQualityScore,
    modelConfidence: modelConfidence,
    hasRecentCaffeineSmokeOrExercise: false,
  );
  PersonalBaselineResult? baseline;
  if (heroValue != null && protocol.kind != BreathKind.coughTb) {
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
    overall,
    parts,
    tbClassic: tbClassic,
    tbSymptoms: tbSymptoms,
    coughs: coughs,
    oad: oad,
    spiro: spiro,
    pred: pred,
    voice: voice,
  );

  return BreathSessionResult(
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
    urgency: evaluation.highestUrgency,
    firedRuleCodes: evaluation.firedRuleCodes,
    confidence: confidence,
    quality: quality,
    baseline: baseline,
    demoOutcome: demoOutcome,
    heroCode: heroCode,
    heroValue: heroValue,
    heroLabel: heroLabel,
    heightCm: heightCm,
    coughs: coughs,
    wheeze: wheeze,
    spirometry: spiro,
    voice: voice,
    oad: oad,
    tbClassicSymptoms: tbClassic,
    tbSymptoms: tbSymptoms,
    exposures: exposures,
  );
}

class _BreathRisk {
  const _BreathRisk({this.tbBand, this.oadBand, this.fev1FvcBelowLln = false});
  final SemanticBand? tbBand;
  final SemanticBand? oadBand;
  final bool fev1FvcBelowLln;
}

(String, String, String) _copy(
  BreathProtocol p,
  SemanticBand band,
  Map<String, double> overall,
  List<BreathPartResult> parts, {
  required bool tbClassic,
  required List<String> tbSymptoms,
  required CoughDetection? coughs,
  required OadScore? oad,
  required SpirometryEstimate? spiro,
  required SpirometryPrediction pred,
  required VoiceQualityResult? voice,
}) {
  String f(double v, int d) => v.toStringAsFixed(d);
  switch (p.kind) {
    case BreathKind.coughTb:
      if (band == SemanticBand.notAssessed) {
        return (
          'Not assessed',
          'The questions were not completed',
          'Answer the five questions; they decide the referral even when the coughs cannot be analysed.',
        );
      }
      final n = coughs?.count ?? 0;
      final coughLine = coughs == null
          ? 'no usable cough recording'
          : '$n valid cough${n == 1 ? '' : 's'}';
      if (band == SemanticBand.high) {
        return (
          'High TB risk',
          tbClassic
              ? 'Classic TB symptoms: ${tbSymptoms.join(', ')}'
              : 'Cough pattern and symptoms score high',
          'This is a priority flag, not a diagnosis. Arrange a sputum NAAT test (CBNAAT / TrueNat) and a chest X-ray within 14 days (BR-SCR-02, urgent). Until then cover your cough and avoid crowded rooms. Recorded: $coughLine.',
        );
      }
      return (
        'Low TB risk',
        tbSymptoms.isEmpty
            ? 'No TB symptoms and an unremarkable cough'
            : '${tbSymptoms.join(', ')} noted; cough unremarkable',
        'Nothing to act on from this check ($coughLine). If the cough lasts beyond two weeks, or you cough blood, lose weight or sweat at night, come back or see a clinic.',
      );
    case BreathKind.airway:
      if (oad == null || band == SemanticBand.notAssessed) {
        return (
          'Not assessed',
          'No task was completed',
          'The document needs at least the questionnaires, three coughs and one hard blow.',
        );
      }
      final top = oad.inputs.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final drivers = top
          .where((e) => e.value > 0.02)
          .take(3)
          .map((e) => e.key)
          .join(', ');
      return switch (band) {
        SemanticBand.low => (
          'Low likelihood',
          'No sign of narrowed airways in the sounds and answers',
          'Score ${f(oad.prob, 2)} (low). Nothing to act on from this check. Keep away from smoke; come back if breathlessness or wheeze starts.',
        ),
        SemanticBand.moderate => (
          'Moderate likelihood',
          'Some signs of narrowed airways: $drivers',
          'Score ${f(oad.prob, 2)} (moderate). A routine clinic spirometry before and after an inhaler decides whether this is COPD or asthma. The pattern leans ${oad.asthmaVsCopd >= 0.5 ? 'towards asthma' : 'towards COPD'} (${f(oad.asthmaVsCopd, 2)}).',
        ),
        _ => (
          'High likelihood',
          'Clear signs of narrowed airways: $drivers',
          'Score ${f(oad.prob, 2)} (high). A routine case is opened: clinic spirometry before and after an inhaler, a blood count with eosinophils and a chest X-ray within 14 days. The pattern leans ${oad.asthmaVsCopd >= 0.5 ? 'towards asthma' : 'towards COPD'} (${f(oad.asthmaVsCopd, 2)}).',
        ),
      };
    case BreathKind.lungFunction:
      final b = spiro?.best;
      if (b == null) {
        return (
          'Not assessed',
          'No blow of at least 3 seconds',
          'Take the deepest breath you can and keep blowing until empty — at least 3 seconds.',
        );
      }
      final rep = spiro!.repeatable
          ? 'The best two blows agreed within 10 %.'
          : 'The blows did not agree within 10 %, so treat the numbers with care.';
      if (spiro.belowLln) {
        return (
          'Below the lower limit',
          'FEV1/FVC ${f(b.ratio, 2)} is under your lower limit of ${f(pred.ratioLln, 2)}',
          'Less of your air came out in the first second than expected for your height, age and sex — the pattern of narrowed airways. A routine case is opened for clinic spirometry before and after an inhaler. $rep FEV1 ${f(spiro.fev1PredPct!, 0)} % and FVC ${f(spiro.fvcPredPct!, 0)} % of predicted.',
        );
      }
      return (
        'Within normal',
        'FEV1/FVC ${f(b.ratio, 2)} is above your lower limit of ${f(pred.ratioLln, 2)}',
        'Your first-second share is in the normal range for your height, age and sex. FEV1 ${f(spiro.fev1PredPct!, 0)} % and FVC ${f(spiro.fvcPredPct!, 0)} % of predicted (sound-based estimates). $rep',
      );
    case BreathKind.voice:
      if (voice == null || !voice.phonationOk) {
        return (
          'Not assessed',
          '"aaa" was shorter than 3 seconds',
          'Take a deep breath and hold "aaa" for at least 5 seconds, then try again.',
        );
      }
      final out = voice.outsideNormCount;
      if (out == 0) {
        return (
          'Within the adult norms',
          'Steady voice: jitter, shimmer, HNR, MPT and s/z all inside the lines',
          'Pitch ${f(voice.f0Hz, 0)} Hz, jitter ${f(voice.jitterPct, 2)} %, shimmer ${f(voice.shimmerPct, 2)} %, HNR ${f(voice.hnrDb, 1)} dB, MPT ${f(voice.mptS, 1)} s${voice.szRatio != null ? ', s/z ${f(voice.szRatio!, 2)}' : ''}. Kept as your baseline; no referral from this check.',
        );
      }
      final which = [
        if (voice.bandOf('JITTER_PCT') == SemanticBand.borderline) 'jitter',
        if (voice.bandOf('SHIMMER_PCT') == SemanticBand.borderline) 'shimmer',
        if (voice.bandOf('HNR_DB') == SemanticBand.borderline) 'HNR',
        if (voice.bandOf('MPT_S') == SemanticBand.borderline) 'MPT',
        if (voice.bandOf('SZ_RATIO') == SemanticBand.borderline) 's/z',
      ].join(', ');
      return (
        'Outside the norm on $out value${out == 1 ? '' : 's'}',
        'Outside the adult lines: $which',
        'A less steady or breathier voice than the adult norms. One recording is not a diagnosis — a cold, tiredness or a dry throat changes these numbers. Repeat on another day; a hoarse voice lasting more than three weeks deserves an ENT examination.',
      );
  }
}
