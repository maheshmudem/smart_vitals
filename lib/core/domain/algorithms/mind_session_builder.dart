// Turns raw Brain & Mind task captures into a [MindSessionResult]
// (Doc 09 §8 AUD-10/11/12, §9 MOV-06..09, §10 RSK, Doc 08 §14.2).
import '../entities/enums.dart';
import '../entities/marker_envelope.dart';
import '../entities/member_profile.dart';
import '../entities/mind_protocol.dart';
import '../entities/mind_result.dart';
import 'marker_readings.dart';
import 'mind_engines.dart';
import 'risk_engine.dart';

/// Raw capture for one task.
class MindTaskCapture {
  const MindTaskCapture({
    required this.taskId,
    this.skipped = false,
    this.skipReason,
    this.answers = const {},
    this.transcript,
    this.partials = const [],
    this.features,
    this.durationS,
    this.faceRest,
    this.faceSmile,
    this.armStart,
    this.armEnd,
    this.sttUsed = false,
    this.manualCount = 0,
    this.source = '',
    this.faceRestFrames = const [],
    this.faceSmileFrames = const [],
    this.helperJudgement,
  });

  final String taskId;
  final bool skipped;
  final String? skipReason;
  final Map<String, int> answers;
  final String? transcript;
  final List<TimedWords> partials;
  final VoiceFeatures? features;
  final double? durationS;
  final FaceGeometry? faceRest;
  final FaceGeometry? faceSmile;
  final List<double>? armStart;
  final List<double>? armEnd;
  final bool sttUsed;

  /// Helper tally of animals when speech recognition was unavailable.
  final int manualCount;

  /// Where the data came from: 'camera' | 'motion' | 'stt' | 'helper' |
  /// 'simulated' | 'none' | '' (not tracked).
  final String source;

  /// All fresh face frames of the rest and smile stages (MOV-06); when
  /// present they take precedence over [faceRest] / [faceSmile].
  final List<FaceGeometry> faceRestFrames;
  final List<FaceGeometry> faceSmileFrames;

  /// Stroke speech judged by a helper when recognition was unavailable:
  /// 0 clear · 1 slurred · 2 could not speak (SpeechAbnormality.helperProbs).
  final int? helperJudgement;

  bool get isSimulated => source == 'simulated';
}

typedef MindHistory = List<MindSessionResult>;

MindSessionResult buildMindSession({
  required MindProtocol protocol,
  required SubjectProfile subject,
  required List<MindTaskCapture> captures,
  required MindDemoOutcome demoOutcome,
  MindHistory history = const [],
  MindLanguage language = MindLanguage.en,
  bool sttAvailable = false,
  String audioSource = 'simulated',
  double? ambientDba,
  bool micSelfCheck = false,
  bool cameraUsed = false,
  bool motionUsed = false,
  List<HfDailySample> hfBaseline = const [],
  DateTime? onsetAt,
  String? onsetLabel,
  int retakes = 0,
  bool simulated = true,
  int durationSeconds = 0,
  String? sessionId,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final id = sessionId ?? 'mind_${at.millisecondsSinceEpoch}';
  final parts = <MindPartResult>[];
  final env = <String, MarkerEnvelope<dynamic>>{};
  final overall = <String, double>{};
  final taskSeconds = <String, double>{};
  double? clipPct, snrDb;
  final byId = {for (final c in captures) c.taskId: c};

  for (final c in captures) {
    if (c.durationS != null) taskSeconds[c.taskId] = c.durationS!;
    if (c.features != null) {
      clipPct = c.features!.clipPct;
      snrDb = c.features!.snrDb;
    }
  }

  MindPartResult skippedPart(MindTask t, MindTaskCapture? c) => MindPartResult(
    id: t.id,
    label: t.title,
    assessed: false,
    skipped: true,
    note: c?.skipReason ?? 'Skipped',
  );

  var band = SemanticBand.notAssessed;
  var crisis = false;
  final signs = <String>[];
  int? hfDay;
  var hfBuilding = false;
  var hfHistory = <HfDailySample>[];
  HearingLikeRisk risk = const HearingLikeRisk();

  switch (protocol.kind) {
    // ── Cognitive (AUD-10) ────────────────────────────────────────────────
    case MindKind.cognitive:
      for (final t in protocol.tasks) {
        final c = byId[t.id];
        if (c == null || c.skipped) {
          parts.add(skippedPart(t, c));
          continue;
        }
        if ((c.transcript ?? '').trim().isEmpty) {
          if (t.id == 'fluency' && c.manualCount > 0) {
            overall['FLUENCY_COUNT'] = c.manualCount.toDouble();
            parts.add(
              MindPartResult(
                id: t.id,
                label: 'Animal naming (60 s)',
                assessed: true,
                band: SemanticBand.rangeNotAvailable,
                values: {'FLUENCY_COUNT': c.manualCount.toDouble()},
                note:
                    '${c.manualCount} animals counted by a helper (speech recognition unavailable) — pauses and rate not measured',
              ),
            );
          } else {
            parts.add(skippedPart(t, c));
          }
          continue;
        }
        final m = TranscriptAnalysis.analyze(
          finalText: c.transcript!,
          partials: c.partials,
          durationS: c.durationS ?? t.seconds.toDouble(),
        );
        if (t.id == 'fluency') {
          final f = FluencyScorer.score(m.tokens, language);
          overall['FLUENCY_COUNT'] = f.count.toDouble();
          overall['PAUSE_RATE'] = m.pauseRatePerMin;
          parts.add(
            MindPartResult(
              id: t.id,
              label: 'Animal naming (60 s)',
              assessed: true,
              band: SemanticBand.rangeNotAvailable,
              values: {
                'FLUENCY_COUNT': f.count.toDouble(),
                'REPETITIONS': f.repetitions.toDouble(),
                'INTRUSIONS': f.intrusions.toDouble(),
                'PAUSE_RATE': m.pauseRatePerMin,
              },
              items: f.valid,
              texts: {'transcript': c.transcript!},
              note:
                  '${f.count} different animal${f.count == 1 ? '' : 's'} · ${f.repetitions} repeated · ${f.intrusions} other word${f.intrusions == 1 ? '' : 's'} · ${m.longPauses} pause${m.longPauses == 1 ? '' : 's'} over 2 s',
            ),
          );
        } else {
          final units = PictureScorer.infoUnits(m.tokens);
          overall['SPEECH_RATE'] = m.wordsPerMin;
          overall['LEXICAL_DIV'] = m.lexicalDiversity;
          overall['INFO_UNITS'] = units.length.toDouble();
          // pause rate across both tasks: mean
          final prev = overall['PAUSE_RATE'];
          overall['PAUSE_RATE'] = prev == null
              ? m.pauseRatePerMin
              : (prev + m.pauseRatePerMin) / 2;
          parts.add(
            MindPartResult(
              id: t.id,
              label: 'Picture description',
              assessed: true,
              band: SemanticBand.rangeNotAvailable,
              values: {
                'SPEECH_RATE': m.wordsPerMin,
                'LEXICAL_DIV': m.lexicalDiversity,
                'INFO_UNITS': units.length.toDouble(),
                'WORDS': m.totalWords.toDouble(),
              },
              items: units,
              texts: {'transcript': c.transcript!},
              note:
                  '${m.totalWords} words · ${m.wordsPerMin.toStringAsFixed(0)} wpm · ${units.length} of ${PictureScorer.totalUnits} picture details · variety ${m.lexicalDiversity.toStringAsFixed(2)}',
            ),
          );
        }
      }
      final assessed = parts.where((p) => p.assessed).toList();
      band = assessed.isEmpty
          ? SemanticBand.notAssessed
          : SemanticBand.rangeNotAvailable;
      for (final code in [
        'FLUENCY_COUNT',
        'PAUSE_RATE',
        'SPEECH_RATE',
        'LEXICAL_DIV',
      ]) {
        final v = overall[code];
        env[code] = MarkerReadings.synth(
          code,
          value: v,
          algorithmId: protocol.algorithmId,
          band: v == null
              ? SemanticBand.notAssessed
              : SemanticBand.rangeNotAvailable,
          status: v == null
              ? MarkerDisplayStatus.notAssessed
              : MarkerDisplayStatus.rangeNotAvailable,
          reason: v == null
              ? 'Task not completed'
              : 'Age/education norms pending (Q-COHORT)',
          version: protocol.algorithmVersion,
          confidence: 0.85,
        );
      }
      env['COG_BAND'] = MarkerReadings.synth(
        'COG_BAND',
        value: null,
        algorithmId: protocol.algorithmId,
        band: SemanticBand.inValidation,
        status: MarkerDisplayStatus.notAssessed,
        reason:
            'Band only when the classifier is released (G-24, study AUD-COG-01)',
        version: protocol.algorithmVersion,
      );

    // ── Mood (AUD-11) ─────────────────────────────────────────────────────
    case MindKind.mood:
      int? phq, gad;
      for (final t in protocol.tasks) {
        final c = byId[t.id];
        if (t.type == MindTaskType.questionnaire) {
          final q = t.questionnaire!;
          if (c == null || c.skipped || !Phq9Gad7.complete(q, c.answers)) {
            parts.add(skippedPart(t, c));
            continue;
          }
          final total = Phq9Gad7.total(q, c.answers);
          final isPhq = q.id == 'PHQ9';
          final sev = Phq9Gad7.band(total, gad: !isPhq);
          if (isPhq) {
            phq = total;
            crisis = Phq9Gad7.crisis(c.answers);
          } else {
            gad = total;
          }
          overall[q.id] = total.toDouble();
          parts.add(
            MindPartResult(
              id: t.id,
              label: q.title,
              assessed: true,
              band: _moodBand(sev),
              values: {q.id: total.toDouble()},
              answers: c.answers,
              flags: {if (isPhq) 'ITEM9_POSITIVE': crisis},
              note:
                  '$total of ${q.maxTotal} · ${sev.label.toLowerCase()}${isPhq && crisis ? ' · question 9 answered — crisis support shown' : ''}',
            ),
          );
        } else {
          if (c == null ||
              c.skipped ||
              c.features == null ||
              !c.features!.heardSpeech) {
            parts.add(skippedPart(t, c));
            continue;
          }
          final f = c.features!;
          final score = MoodVoiceModel.score(f);
          overall['MOOD_VOICE_SCORE'] = score;
          parts.add(
            MindPartResult(
              id: t.id,
              label: 'Free speech (60 s)',
              assessed: true,
              band: SemanticBand.inValidation,
              values: {
                'MOOD_VOICE_SCORE': score,
                'F0_HZ': f.meanF0Hz,
                'F0_SD': f.f0SdHz,
                'PAUSE_RATE': f.pauseRatePerMin,
                'SYL_PER_SEC': f.syllablesPerSec,
              },
              note:
                  'Recorded ${f.speechTimeS.toStringAsFixed(0)} s of speech · pitch ${f.meanF0Hz.toStringAsFixed(0)} Hz (sd ${f.f0SdHz.toStringAsFixed(0)}) · ${f.pauseRatePerMin.toStringAsFixed(1)} long pauses/min · voice score ${score.toStringAsFixed(2)} (not used, G-24)',
            ),
          );
        }
      }
      final sevP = phq == null ? null : Phq9Gad7.band(phq);
      final sevG = gad == null ? null : Phq9Gad7.band(gad, gad: true);
      final worst = [?sevP, ?sevG];
      band = worst.isEmpty
          ? SemanticBand.notAssessed
          : _moodBand(worst.reduce((a, b) => a.index >= b.index ? a : b));
      if (crisis) band = SemanticBand.emergency;
      env['PHQ9'] = MarkerReadings.synth(
        'PHQ9',
        value: phq,
        algorithmId: protocol.algorithmId,
        band: phq == null ? SemanticBand.notAssessed : _moodBand(sevP!),
        status: phq == null
            ? MarkerDisplayStatus.notAssessed
            : MarkerDisplayStatus.ok,
        reason: phq == null ? 'Questionnaire not completed' : null,
        version: protocol.algorithmVersion,
      );
      env['GAD7'] = MarkerReadings.synth(
        'GAD7',
        value: gad,
        algorithmId: protocol.algorithmId,
        band: gad == null ? SemanticBand.notAssessed : _moodBand(sevG!),
        status: gad == null
            ? MarkerDisplayStatus.notAssessed
            : MarkerDisplayStatus.ok,
        reason: gad == null ? 'Questionnaire not completed' : null,
        version: protocol.algorithmVersion,
      );
      env['MOOD_VOICE_SCORE'] = MarkerReadings.synth(
        'MOOD_VOICE_SCORE',
        value: overall['MOOD_VOICE_SCORE'],
        algorithmId: protocol.algorithmId,
        band: SemanticBand.inValidation,
        status: MarkerDisplayStatus.notAssessed,
        reason:
            'Recorded, not used: voice must add ≥ 0.03 AUC over the questionnaires (G-24)',
        version: protocol.algorithmVersion,
      );
      risk = HearingLikeRisk(phq9: phq, phq9Item9: crisis ? 1 : 0, gad7: gad);

    // ── HF voice (AUD-12) ─────────────────────────────────────────────────
    case MindKind.hfVoice:
      final t = protocol.tasks.first;
      final c = byId[t.id];
      hfHistory = List<HfDailySample>.from(hfBaseline);
      if (c == null ||
          c.skipped ||
          c.features == null ||
          !c.features!.heardSpeech) {
        parts.add(skippedPart(t, c));
        band = SemanticBand.notAssessed;
      } else {
        final f = c.features!;
        final today = f.hfVector;
        final baselineDays = hfBaseline
            .where((s) => s.deviation == null)
            .length;
        hfDay = baselineDays + 1;
        hfBuilding = baselineDays < HfBaseline.baselineDays;
        double? dev;
        var alert = false;
        if (!hfBuilding) {
          final base = hfBaseline.where((s) => s.deviation == null).toList();
          dev = HfBaseline.deviation(today, base);
          final yesterday = hfBaseline.isEmpty
              ? null
              : hfBaseline.last.deviation;
          alert = dev != null && HfBaseline.alert(dev, yesterday);
          overall['HF_VOICE_DEV'] = dev ?? 0;
          final z = HfBaseline.zScores(today, base);
          parts.add(
            MindPartResult(
              id: t.id,
              label: 'Today vs your 14-day baseline',
              assessed: true,
              band: alert
                  ? SemanticBand.high
                  : (dev ?? 0) >= HfBaseline.alertThreshold
                  ? SemanticBand.borderline
                  : SemanticBand.normal,
              values: {
                'HF_VOICE_DEV': dev ?? 0,
                for (var i = 0; i < z.length; i++)
                  'Z_${VoiceFeatures.hfVectorNames[i]}': z[i],
                for (var i = 0; i < today.length; i++)
                  'F_${VoiceFeatures.hfVectorNames[i]}': today[i],
              },
              flags: {'HF_ALERT': alert},
              note: alert
                  ? 'Deviation ${dev.toStringAsFixed(1)} SD, high two days running → alert'
                  : (dev ?? 0) >= HfBaseline.alertThreshold
                  ? 'Deviation ${(dev ?? 0).toStringAsFixed(1)} SD today — watch tomorrow (alert needs two days)'
                  : 'Deviation ${(dev ?? 0).toStringAsFixed(1)} SD — within your usual range',
            ),
          );
          band = alert
              ? SemanticBand.high
              : (dev ?? 0) >= HfBaseline.alertThreshold
              ? SemanticBand.borderline
              : SemanticBand.normal;
        } else {
          parts.add(
            MindPartResult(
              id: t.id,
              label: 'Building your baseline',
              assessed: true,
              band: SemanticBand.rangeNotAvailable,
              values: {
                'BASELINE_DAY': hfDay.toDouble(),
                for (var i = 0; i < today.length; i++)
                  'F_${VoiceFeatures.hfVectorNames[i]}': today[i],
              },
              note:
                  'Day $hfDay of ${HfBaseline.baselineDays} — recorded ${f.speechTimeS.toStringAsFixed(0)} s of speech, pitch ${f.meanF0Hz.toStringAsFixed(0)} Hz',
            ),
          );
          band = SemanticBand.rangeNotAvailable;
        }
        hfHistory.add(
          HfDailySample(
            day: at,
            vector: today,
            deviation: hfBuilding ? null : dev,
          ),
        );
        env['HF_VOICE_DEV'] = MarkerReadings.synth(
          'HF_VOICE_DEV',
          value: hfBuilding ? null : dev,
          algorithmId: protocol.algorithmId,
          band: hfBuilding ? SemanticBand.rangeNotAvailable : band,
          status: hfBuilding
              ? MarkerDisplayStatus.notAssessed
              : MarkerDisplayStatus.ok,
          reason: hfBuilding
              ? 'Building personal voice baseline (Day $hfDay of ${HfBaseline.baselineDays})'
              : null,
          version: protocol.algorithmVersion,
          confidence: 0.85,
        );
        env['HF_ALERT'] = MarkerReadings.synth(
          'HF_ALERT',
          value: hfBuilding ? null : alert,
          algorithmId: protocol.algorithmId,
          band: hfBuilding
              ? SemanticBand.rangeNotAvailable
              : alert
              ? SemanticBand.high
              : SemanticBand.normal,
          status: hfBuilding
              ? MarkerDisplayStatus.notAssessed
              : MarkerDisplayStatus.ok,
          reason: hfBuilding
              ? 'No alerts until the 14-day baseline is complete (G-28)'
              : null,
          version: protocol.algorithmVersion,
        );
        risk = HearingLikeRisk(hfAlert: alert);
      }

    // ── Stroke (MOV-06..09) ───────────────────────────────────────────────
    case MindKind.stroke:
      double? faceScore, armL, armR, speechProb;
      String side = 'none';
      for (final t in protocol.tasks) {
        final c = byId[t.id];
        switch (t.type) {
          case MindTaskType.faceSmile:
            final hasFrames =
                c != null &&
                c.faceRestFrames.isNotEmpty &&
                c.faceSmileFrames.isNotEmpty;
            if (c == null ||
                c.skipped ||
                (!hasFrames && (c.faceRest == null || c.faceSmile == null))) {
              parts.add(skippedPart(t, c));
              continue;
            }
            final r = hasFrames
                ? FaceAsymmetry.computeFrames(
                    rest: c.faceRestFrames,
                    smile: c.faceSmileFrames,
                  )
                : FaceAsymmetry.compute(rest: c.faceRest!, smile: c.faceSmile!);
            faceScore = r.score;
            side = r.side;
            final src = c.source == 'simulated' ? ' · simulated face' : '';
            parts.add(
              MindPartResult(
                id: t.id,
                label: 'Face · smile symmetry',
                assessed: true,
                band: r.score >= FaceAsymmetry.threshold
                    ? SemanticBand.emergency
                    : SemanticBand.normal,
                values: {
                  'FACE_ASYM_SCORE': r.score,
                  'REST_FRAMES': r.restFrames.toDouble(),
                  'SMILE_FRAMES': r.smileFrames.toDouble(),
                },
                texts: {'FACE_ASYM_SIDE': r.side},
                flags: {'SMILE_DETECTED': r.smileDetected},
                note: r.score >= FaceAsymmetry.threshold
                    ? 'Uneven smile — weaker ${r.side} side (score ${r.score.toStringAsFixed(2)}, ${r.restFrames} rest + ${r.smileFrames} smile frames)$src'
                    : 'Even smile (score ${r.score.toStringAsFixed(2)}, ${r.restFrames} rest + ${r.smileFrames} smile frames)$src',
              ),
            );
          case MindTaskType.armDrift:
            if (c == null ||
                c.skipped ||
                c.armStart == null ||
                c.armEnd == null) {
              parts.add(skippedPart(t, c));
              continue;
            }
            final deg = ArmDrift.pitchDropDegrees(c.armStart!, c.armEnd!);
            final cm = ArmDrift.dropCm(deg);
            if (t.arm == 'left') {
              armL = cm;
            } else {
              armR = cm;
            }
            parts.add(
              MindPartResult(
                id: t.id,
                label: '${t.arm == 'left' ? 'Left' : 'Right'} arm · 10 s hold',
                assessed: true,
                band: cm >= ArmDrift.thresholdCm
                    ? SemanticBand.emergency
                    : SemanticBand.normal,
                values: {
                  t.arm == 'left' ? 'ARM_DRIFT_L' : 'ARM_DRIFT_R': cm,
                  'DROP_DEG': deg,
                },
                note: cm >= ArmDrift.thresholdCm
                    ? 'Drifted ${cm.toStringAsFixed(0)} cm (${deg.toStringAsFixed(0)}°)'
                    : 'Held steady — ${cm.toStringAsFixed(0)} cm',
              ),
            );
          case MindTaskType.speechTranscribe:
            final target = MindTexts.sentence('strokeSentence', language);
            if (c != null && !c.skipped && c.helperJudgement != null) {
              // recognition unavailable: a helper judged the speech
              final j = c.helperJudgement!.clamp(0, 2);
              final p = SpeechAbnormality.helperProbs[j];
              speechProb = p;
              parts.add(
                MindPartResult(
                  id: t.id,
                  label: 'Speech · sentence repeat (helper judged)',
                  assessed: true,
                  band: p >= SpeechAbnormality.threshold
                      ? SemanticBand.emergency
                      : SemanticBand.normal,
                  values: {'SPEECH_ABN_PROB': p},
                  texts: {
                    'target': target,
                    'recognised':
                        'Helper: ${SpeechAbnormality.helperLabels[j]}',
                  },
                  note:
                      'Speech recognition was not available — a helper judged it "${SpeechAbnormality.helperLabels[j].toLowerCase()}" (SPEECH_ABN_PROB ${p.toStringAsFixed(2)})',
                ),
              );
              continue;
            }
            if (c == null || c.skipped || (c.transcript ?? '').trim().isEmpty) {
              parts.add(skippedPart(t, c));
              continue;
            }
            final wps = SpeechAbnormality.wordsPerSecond(
              c.partials,
              c.durationS ?? t.seconds.toDouble(),
            );
            final p = SpeechAbnormality.prob(
              target,
              c.transcript!,
              syllablesPerSec: c.features?.syllablesPerSec,
              wordsPerSec: wps,
            );
            speechProb = p;
            parts.add(
              MindPartResult(
                id: t.id,
                label: 'Speech · sentence repeat',
                assessed: true,
                band: p >= SpeechAbnormality.threshold
                    ? SemanticBand.emergency
                    : SemanticBand.normal,
                values: {
                  'SPEECH_ABN_PROB': p,
                  'WER': SpeechAbnormality.wordErrorRate(target, c.transcript!),
                  'WORDS_PER_SEC': ?wps,
                },
                texts: {'recognised': c.transcript!, 'target': target},
                note: p >= SpeechAbnormality.threshold
                    ? 'Words missing or unclear (${(p * 100).toStringAsFixed(0)} %${wps != null ? ' · ${wps.toStringAsFixed(1)} words/s' : ''})'
                    : 'Clear (${(p * 100).toStringAsFixed(0)} %${wps != null ? ' · ${wps.toStringAsFixed(1)} words/s' : ''})',
              ),
            );
          default:
            break;
        }
      }
      final d = StrokeDecision.evaluate(
        faceScore: faceScore,
        armDriftLCm: armL,
        armDriftRCm: armR,
        speechProb: speechProb,
      );
      signs.addAll(d.signs);
      final anyAssessed = parts.any((p) => p.assessed);
      band = !anyAssessed
          ? SemanticBand.notAssessed
          : d.positive
          ? SemanticBand.emergency
          : SemanticBand.normal;
      overall['STROKE_POSITIVE'] = d.positive ? 1 : 0;
      if (faceScore != null) overall['FACE_ASYM_SCORE'] = faceScore;
      if (armL != null) overall['ARM_DRIFT_L'] = armL;
      if (armR != null) overall['ARM_DRIFT_R'] = armR;
      if (speechProb != null) overall['SPEECH_ABN_PROB'] = speechProb;
      void m(
        String code,
        Object? v,
        String alg,
        SemanticBand b, {
        String? missing,
      }) {
        env[code] = MarkerReadings.synth(
          code,
          value: v,
          algorithmId: alg,
          band: v == null ? SemanticBand.notAssessed : b,
          status: v == null
              ? MarkerDisplayStatus.notAssessed
              : MarkerDisplayStatus.ok,
          reason: v == null ? missing : null,
          version: protocol.algorithmVersion,
          confidence: 0.85,
        );
      }

      m(
        'FACE_ASYM_SCORE',
        faceScore,
        'ALG-MOV-06',
        faceScore != null && faceScore >= FaceAsymmetry.threshold
            ? SemanticBand.emergency
            : SemanticBand.normal,
        missing: 'Face step skipped',
      );
      m(
        'FACE_ASYM_SIDE',
        faceScore == null ? null : side,
        'ALG-MOV-06',
        side == 'none' ? SemanticBand.normal : SemanticBand.emergency,
        missing: 'Face step skipped',
      );
      m(
        'ARM_DRIFT_L',
        armL,
        'ALG-MOV-07',
        armL != null && armL >= ArmDrift.thresholdCm
            ? SemanticBand.emergency
            : SemanticBand.normal,
        missing: 'Left arm step skipped',
      );
      m(
        'ARM_DRIFT_R',
        armR,
        'ALG-MOV-07',
        armR != null && armR >= ArmDrift.thresholdCm
            ? SemanticBand.emergency
            : SemanticBand.normal,
        missing: 'Right arm step skipped',
      );
      m(
        'SPEECH_ABN_PROB',
        speechProb,
        'ALG-MOV-08',
        speechProb != null && speechProb >= SpeechAbnormality.threshold
            ? SemanticBand.emergency
            : SemanticBand.normal,
        missing: 'Speech step skipped',
      );
      m(
        'STROKE_POSITIVE',
        anyAssessed ? d.positive : null,
        'ALG-MOV-09',
        d.positive ? SemanticBand.emergency : SemanticBand.normal,
        missing: 'No step completed',
      );
      // helper-judged speech carries less confidence than a recogniser
      if (byId['speech']?.helperJudgement != null &&
          env['SPEECH_ABN_PROB'] != null) {
        env['SPEECH_ABN_PROB'] = MarkerReadings.synth(
          'SPEECH_ABN_PROB',
          value: speechProb,
          algorithmId: 'ALG-MOV-08',
          band: speechProb != null && speechProb >= SpeechAbnormality.threshold
              ? SemanticBand.emergency
              : SemanticBand.normal,
          reason: 'Judged by a helper (recognition unavailable)',
          version: protocol.algorithmVersion,
          confidence: 0.6,
        );
      }
      risk = HearingLikeRisk(strokePositive: d.positive);
  }

  // --- Risk rules -----------------------------------------------------------
  final evaluation = RiskEngine.evaluateUrgency(
    RiskEvaluationInput(
      strokePositive: risk.strokePositive,
      phq9Total: risk.phq9,
      phq9Item9: risk.phq9Item9,
      gad7Total: risk.gad7,
      hfAlert: risk.hfAlert,
    ),
    sessionId: id,
    timestamp: at,
  );
  if (evaluation.highestUrgency != UrgencyLevel.none &&
      band == SemanticBand.normal) {
    band = evaluation.highestUrgency == UrgencyLevel.emergency
        ? SemanticBand.emergency
        : SemanticBand.refer;
  }

  // --- Hero -------------------------------------------------------------------
  String heroCode;
  double? heroValue;
  String heroLabel;
  switch (protocol.kind) {
    case MindKind.cognitive:
      heroCode = 'FLUENCY_COUNT';
      heroValue = overall['FLUENCY_COUNT'];
      heroLabel = heroValue == null
          ? 'Not assessed'
          : '${heroValue.toStringAsFixed(0)} animals in 60 s';
    case MindKind.mood:
      heroCode = 'PHQ9';
      heroValue = overall['PHQ9'];
      heroLabel = heroValue == null
          ? 'Not assessed'
          : 'PHQ-9 ${heroValue.toStringAsFixed(0)} · GAD-7 ${overall['GAD7']?.toStringAsFixed(0) ?? '—'}';
    case MindKind.hfVoice:
      heroCode = 'HF_VOICE_DEV';
      heroValue = hfBuilding ? null : overall['HF_VOICE_DEV'];
      heroLabel = hfBuilding
          ? 'Day ${hfDay ?? '—'} of ${HfBaseline.baselineDays}'
          : heroValue == null
          ? 'Not assessed'
          : '${heroValue.toStringAsFixed(1)} SD from baseline';
    case MindKind.stroke:
      heroCode = 'STROKE_POSITIVE';
      heroValue = overall['STROKE_POSITIVE'];
      heroLabel = heroValue == null
          ? 'Not assessed'
          : heroValue > 0
          ? 'Positive · ${signs.join(', ')}'
          : 'Negative';
  }

  // --- Quality, confidence, baseline ----------------------------------------
  final sources = {
    for (final c in captures)
      if (c.source.isNotEmpty) c.taskId: c.source,
  };
  final tracked = sources.isNotEmpty;
  final quality = MindQualityFacts(
    kind: protocol.kind,
    language: language,
    sttAvailable: sttAvailable,
    audioSource: audioSource,
    clipPct: clipPct,
    snrDb: snrDb,
    ambientDba: ambientDba,
    micSelfCheck: micSelfCheck,
    cameraUsed: tracked ? sources['face'] == 'camera' : cameraUsed,
    motionUsed: tracked
        ? sources.entries.any(
            (e) => e.key.startsWith('arm') && e.value == 'motion',
          )
        : motionUsed,
    taskSeconds: taskSeconds,
    retakes: retakes,
    simulated: simulated || sources.values.contains('simulated'),
    sources: sources,
  );
  final confidence = RiskEngine.computeResultConfidence(
    captureQualityScore: quality.captureQualityScore,
    modelConfidence: protocol.kind == MindKind.mood ? 0.95 : 0.85,
    hasRecentCaffeineSmokeOrExercise: false,
  );
  PersonalBaselineResult? baseline;
  if (heroValue != null && protocol.kind != MindKind.stroke) {
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
    crisis: crisis,
    signs: signs,
    hfBuilding: hfBuilding,
    hfDay: hfDay,
  );

  return MindSessionResult(
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
    crisis: crisis,
    onsetAt: onsetAt,
    onsetLabel: onsetLabel,
    positiveSigns: signs,
    hfBaselineDay: hfDay,
    hfBuilding: hfBuilding,
    hfHistory: hfHistory,
    language: language,
  );
}

/// Small holder for the rule inputs collected per kind.
class HearingLikeRisk {
  const HearingLikeRisk({
    this.strokePositive = false,
    this.phq9,
    this.phq9Item9,
    this.gad7,
    this.hfAlert = false,
  });
  final bool strokePositive;
  final int? phq9;
  final int? phq9Item9;
  final int? gad7;
  final bool hfAlert;
}

SemanticBand _moodBand(MoodSeverity s) => switch (s) {
  MoodSeverity.normal => SemanticBand.normal,
  MoodSeverity.mild => SemanticBand.borderline,
  MoodSeverity.moderate => SemanticBand.moderate,
  MoodSeverity.moderatelySevere => SemanticBand.high,
  MoodSeverity.severe => SemanticBand.severe,
};

(String, String, String) _copy(
  MindProtocol p,
  SemanticBand band,
  Map<String, double> overall,
  List<MindPartResult> parts, {
  required bool crisis,
  required List<String> signs,
  required bool hfBuilding,
  required int? hfDay,
}) {
  switch (p.kind) {
    case MindKind.cognitive:
      final f = overall['FLUENCY_COUNT'];
      if (f == null) {
        return (
          'Not assessed',
          'The speaking tasks were not completed',
          'Repeat in a quiet room; speak clearly about 20–30 cm from the phone.',
        );
      }
      final units = overall['INFO_UNITS'];
      return (
        'Recorded',
        '${f.toStringAsFixed(0)} animals in a minute${units != null ? ' · ${units.toStringAsFixed(0)} of ${PictureScorer.totalUnits} picture details' : ''}',
        'The document\'s age- and education-adjusted norms are still being collected, so no band is given today. The values are stored so a change over time can be seen. If you or your family notice memory or word-finding problems, a clinician MoCA is the next step.',
      );
    case MindKind.mood:
      final phq = overall['PHQ9'], gad = overall['GAD7'];
      if (phq == null && gad == null) {
        return (
          'Not assessed',
          'The questionnaires were not completed',
          'Complete both questionnaires to get a result.',
        );
      }
      final scores =
          'PHQ-9 ${phq?.toStringAsFixed(0) ?? '—'} of 27 · GAD-7 ${gad?.toStringAsFixed(0) ?? '—'} of 21';
      if (crisis) {
        return (
          'Crisis support',
          'You said you have had thoughts of self-harm',
          'You are not alone. Helplines are shown on the crisis screen and your pathway clinician has been notified. $scores. Please talk to someone you trust today.',
        );
      }
      return switch (band) {
        SemanticBand.normal => (
          'Normal',
          'Few symptoms over the last two weeks',
          '$scores — both below the line of 5. Nothing to act on from this check; your clinician sees the result.',
        ),
        SemanticBand.borderline => (
          'Mild',
          'Some symptoms over the last two weeks',
          '$scores — between 5 and 9 is mild. Worth mentioning to your clinician; repeat in two weeks.',
        ),
        _ => (
          'Moderate or more',
          'Symptoms that deserve follow-up',
          '$scores — 10 or more is at least moderate. Your pathway clinician will review this and may suggest talking therapy, blood tests or treatment.',
        ),
      };
    case MindKind.hfVoice:
      if (hfBuilding) {
        return (
          'Building baseline',
          'Day ${hfDay ?? '—'} of ${HfBaseline.baselineDays} — building your personal voice baseline',
          'While your clinic says you are stable the app learns your normal voice. No alerts yet. Keep recording once a day, same place and time.',
        );
      }
      final dev = overall['HF_VOICE_DEV'];
      if (dev == null) {
        return (
          'Not assessed',
          'No recording today',
          'Read the sentence for 30 seconds in a quiet room.',
        );
      }
      return switch (band) {
        SemanticBand.high || SemanticBand.refer || SemanticBand.emergency => (
          'Alert',
          'Voice ${dev.toStringAsFixed(1)} SD from your baseline, two days running',
          'Your voice has drifted from your own baseline on consecutive days, which can go with fluid build-up. Your clinic has an urgent review flag: weight, NT-proBNP/BNP, electrolytes. Call sooner if you are more breathless or swollen.',
        ),
        SemanticBand.borderline => (
          'Watch',
          'Voice ${dev.toStringAsFixed(1)} SD from your baseline today',
          'Higher than your usual day-to-day variation. One day is not an alert; tomorrow\'s check decides. Note your weight and symptoms today.',
        ),
        _ => (
          'No alert',
          'Voice within your usual range (${dev.toStringAsFixed(1)} SD)',
          'Today\'s voice matches your baseline. Keep up the daily check.',
        ),
      };
    case MindKind.stroke:
      final assessed = parts.any((x) => x.assessed);
      if (!assessed) {
        return (
          'Not assessed',
          'No step was completed',
          'If you suspect a stroke, call emergency services now.',
        );
      }
      if (signs.isNotEmpty) {
        final names = signs
            .map(
              (s) => switch (s) {
                'face' => 'uneven smile',
                'arm' => 'arm drift',
                _ => 'unclear speech',
              },
            )
            .join(', ');
        return (
          'Act now',
          'Warning sign: $names',
          'Call emergency services (108 / 112) immediately and say "possible stroke". Note the time symptoms started. Do not eat, drink or drive. Treatment works best within 4.5 hours.',
        );
      }
      final done = parts.where((x) => x.assessed).length;
      final missing = parts
          .where((x) => !x.assessed)
          .map((x) => x.label)
          .toList();
      if (missing.isNotEmpty) {
        return (
          'Negative so far',
          '$done of ${parts.length} steps checked — not a full check',
          'No warning sign in the steps that were checked. Not checked: ${missing.join(', ')}. Repeat the missing steps if you can; if symptoms appeared or change, call emergency services — this check cannot rule a stroke out.',
        );
      }
      return (
        'Negative',
        'No warning sign in the three checks',
        'The smile was even, the arms held steady and the sentence was clear. If symptoms appeared or change, repeat the check or call emergency services — this check cannot rule a stroke out.',
      );
  }
}
