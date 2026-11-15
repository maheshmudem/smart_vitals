import 'dart:math' as math;

import 'package:algoritam/core/domain/algorithms/mind_engines.dart';
import 'package:algoritam/core/domain/algorithms/mind_session_builder.dart';
import 'package:algoritam/core/domain/algorithms/risk_engine.dart';
import 'package:algoritam/core/domain/entities/case_record.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/mind_protocol.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brain & Mind engines (ALG-AUD-10/11/12, MOV-06..09)', () {
    test('voice features: pauses, pitch, quality on synthetic PCM', () {
      final pcm = MindSimulated.pcm(seconds: 30, f0: 150, longPauses: 2);
      final f = VoiceFeatures.extract(pcm, 16000);
      expect(f.heardSpeech, isTrue);
      expect(f.pauseCount, 2);
      expect(f.meanF0Hz, closeTo(150, 8));
      expect(f.jitterPct, lessThan(3));
      expect(f.clipPct, lessThan(0.1));
      expect(f.snrDb, greaterThan(VoiceFeatures.minSnrDb));
      expect(f.qualityOk, isTrue);
      expect(f.syllablesPerSec, greaterThan(1));
      expect(f.hfVector.length, 6);
      // clipping detection
      final loud = MindSimulated.pcm(seconds: 5, amplitude: 3.0);
      final fl = VoiceFeatures.extract(loud, 16000);
      expect(fl.clipPct, greaterThan(VoiceFeatures.maxClipPct));
      expect(fl.qualityOk, isFalse);
      // silence
      final silent = List<int>.filled(16000 * 3, 0);
      expect(VoiceFeatures.extract(silent, 16000).heardSpeech, isFalse);
    });

    test('fluency scorer: plurals, repeats, intrusions, hi/te lists', () {
      final en = FluencyScorer.score(
        TranscriptAnalysis.tokenize(
          'dog cats cow dog lion table guinea pig horses',
        ),
        MindLanguage.en,
      );
      expect(en.valid, ['dog', 'cat', 'cow', 'lion', 'guinea pig', 'horse']);
      expect(en.count, 6);
      expect(en.repetitions, 1);
      expect(en.intrusions, 1);
      final hi = FluencyScorer.score(
        TranscriptAnalysis.tokenize('कुत्ता बिल्ली गाय कुत्ता elephant'),
        MindLanguage.hi,
      );
      expect(hi.count, 4);
      expect(hi.repetitions, 1);
      final te = FluencyScorer.score(
        TranscriptAnalysis.tokenize('కుక్క పిల్లి ఆవు'),
        MindLanguage.te,
      );
      expect(te.count, 3);
    });

    test('transcript metrics and picture units', () {
      final (partials, text) = MindSimulated.pictureTranscript(
        MindDemoOutcome.normal,
      );
      final m = TranscriptAnalysis.analyze(
        finalText: text,
        partials: partials,
        durationS: 60,
      );
      expect(m.totalWords, greaterThan(40));
      expect(m.lexicalDiversity, inInclusiveRange(0.4, 1.0));
      expect(m.wordsPerMin, greaterThan(50));
      expect(PictureScorer.infoUnits(m.tokens).length, greaterThanOrEqualTo(9));
      final (p2, t2) = MindSimulated.fluencyTranscript(
        MindDemoOutcome.refer,
        MindLanguage.en,
      );
      final m2 = TranscriptAnalysis.analyze(
        finalText: t2,
        partials: p2,
        durationS: 60,
      );
      expect(m2.longPauses, greaterThan(2));
      expect(FluencyScorer.score(m2.tokens, MindLanguage.en).count, 7);
    });

    test('PHQ-9 / GAD-7 totals, crisis item and bands', () {
      final a = MindSimulated.moodAnswers(MindDemoOutcome.crisis);
      expect(Phq9Gad7.total(MindTexts.phq9, a), 15);
      expect(Phq9Gad7.total(MindTexts.gad7, a), 11);
      expect(Phq9Gad7.crisis(a), isTrue);
      expect(
        Phq9Gad7.crisis(MindSimulated.moodAnswers(MindDemoOutcome.refer)),
        isFalse,
      );
      expect(Phq9Gad7.band(4), MoodSeverity.normal);
      expect(Phq9Gad7.band(5), MoodSeverity.mild);
      expect(Phq9Gad7.band(10), MoodSeverity.moderate);
      expect(Phq9Gad7.band(15), MoodSeverity.moderatelySevere);
      expect(Phq9Gad7.band(20), MoodSeverity.severe);
      expect(Phq9Gad7.band(15, gad: true), MoodSeverity.severe);
      expect(MindTexts.phq9.questions.length, 9);
      expect(MindTexts.gad7.questions.length, 7);
    });

    test('HF baseline: building, deviation, two-day alert', () {
      final today = DateTime(2026, 11, 7);
      final base = MindSimulated.hfBaseline(today);
      expect(base.length, 14);
      expect(
        HfBaseline.deviation(
          MindSimulated.hfToday(MindDemoOutcome.normal),
          base.sublist(0, 10),
        ),
        isNull,
      );
      final stable = HfBaseline.deviation(
        MindSimulated.hfToday(MindDemoOutcome.normal),
        base,
      )!;
      expect(stable, lessThan(HfBaseline.alertThreshold));
      final shifted = HfBaseline.deviation(
        MindSimulated.hfToday(MindDemoOutcome.refer),
        base,
      )!;
      expect(shifted, greaterThanOrEqualTo(HfBaseline.alertThreshold));
      expect(HfBaseline.alert(shifted, null), isFalse);
      expect(HfBaseline.alert(shifted, 1.0), isFalse);
      expect(HfBaseline.alert(shifted, 2.4), isTrue);
    });

    test('face asymmetry, arm drift, speech WER, stroke OR gate', () {
      final even = FaceAsymmetry.compute(
        rest: MindSimulated.faceRest(),
        smile: MindSimulated.faceSmile(),
      );
      expect(even.score, lessThan(FaceAsymmetry.threshold));
      expect(even.side, 'none');
      final droop = FaceAsymmetry.compute(
        rest: MindSimulated.faceRest(droopLeft: true),
        smile: MindSimulated.faceSmile(droopLeft: true),
      );
      expect(droop.score, greaterThanOrEqualTo(FaceAsymmetry.threshold));
      expect(droop.side, 'left');
      final (s0, e0) = MindSimulated.armHold();
      expect(
        ArmDrift.dropCm(ArmDrift.dropDegrees(s0, e0)),
        lessThan(ArmDrift.thresholdCm),
      );
      final (s1, e1) = MindSimulated.armHold(drifts: true);
      final deg = ArmDrift.dropDegrees(s1, e1);
      expect(deg, closeTo(18, 3));
      expect(ArmDrift.dropCm(deg), greaterThanOrEqualTo(ArmDrift.thresholdCm));
      expect(ArmDrift.dropCm(90), closeTo(60, 1e-9));
      final target = MindTexts.sentence('strokeSentence', MindLanguage.en);
      expect(SpeechAbnormality.wordErrorRate(target, target), 0);
      expect(
        SpeechAbnormality.prob(target, target, syllablesPerSec: 4),
        lessThan(0.2),
      );
      final garbled = MindSimulated.strokeSentence(
        MindDemoOutcome.refer,
        MindLanguage.en,
      );
      expect(
        SpeechAbnormality.prob(target, garbled),
        greaterThanOrEqualTo(SpeechAbnormality.threshold),
      );
      expect(
        StrokeDecision.evaluate(
          faceScore: 0.1,
          armDriftLCm: 2,
          armDriftRCm: 3,
          speechProb: 0.1,
        ).positive,
        isFalse,
      );
      final pos = StrokeDecision.evaluate(
        faceScore: null,
        armDriftLCm: 14,
        armDriftRCm: null,
        speechProb: null,
      );
      expect(pos.positive, isTrue);
      expect(pos.signs, ['arm']);
      expect(StrokeDecision.evaluate().positive, isFalse);
    });

    test('stroke engines on the phone: pitch drop, frame medians, helper', () {
      // pitch-only drift: a wrist roll (x) does not count, a dip (y) does
      final (s0, e0) = MindSimulated.armHold();
      expect(
        ArmDrift.dropCm(ArmDrift.pitchDropDegrees(s0, e0)),
        lessThan(ArmDrift.thresholdCm),
      );
      final (s1, e1) = MindSimulated.armHold(drifts: true);
      expect(
        ArmDrift.dropCm(ArmDrift.pitchDropDegrees(s1, e1)),
        greaterThanOrEqualTo(ArmDrift.thresholdCm),
      );
      final rolled = [4.0, 1.2, 8.9]; // phone rolled sideways, same pitch
      expect(ArmDrift.pitchDropDegrees(s0, rolled), lessThan(1.0));
      expect(ArmDrift.dropDegrees(s0, rolled), greaterThan(15));
      // frame medians: one noisy smile frame cannot create a sign
      final rest = [for (var i = 0; i < 6; i++) MindSimulated.faceRest()];
      final smile = [
        for (var i = 0; i < 6; i++) MindSimulated.faceSmile(),
        MindSimulated.faceSmile(droopLeft: true),
      ];
      final r = FaceAsymmetry.computeFrames(rest: rest, smile: smile);
      expect(r.smileDetected, isTrue);
      expect(r.score, lessThan(FaceAsymmetry.threshold));
      expect(r.restFrames, 6);
      expect(r.smileFrames, 7);
      // no smile (rest frames again) → not detected, no false sign
      final flat = FaceAsymmetry.computeFrames(rest: rest, smile: rest);
      expect(flat.smileDetected, isFalse);
      expect(flat.score, lessThan(FaceAsymmetry.threshold));
      expect(
        FaceAsymmetry.computeFrames(rest: const [], smile: smile).smileFrames,
        0,
      );
      // Hindi danda is a separator; word rate from partials
      expect(TranscriptAnalysis.tokenize('आज आसमान नीला है।'), [
        'आज',
        'आसमान',
        'नीला',
        'है',
      ]);
      expect(
        SpeechAbnormality.wordsPerSecond([
          const TimedWords(1.0, 2),
          const TimedWords(3.0, 8),
        ], 8),
        closeTo(3.5, 0.01),
      );
      final target = MindTexts.sentence('strokeSentence', MindLanguage.en);
      expect(
        SpeechAbnormality.prob(target, target, wordsPerSec: 0.5),
        lessThan(SpeechAbnormality.threshold),
      );
      expect(
        SpeechAbnormality.prob(target, target, wordsPerSec: 0.5),
        greaterThan(SpeechAbnormality.prob(target, target, wordsPerSec: 3)),
      );
      expect(SpeechAbnormality.helperProbs[2], 1.0);
      expect(
        SpeechAbnormality.helperProbs[1],
        greaterThanOrEqualTo(SpeechAbnormality.threshold),
      );
      expect(
        SpeechAbnormality.helperProbs[0],
        lessThan(SpeechAbnormality.threshold),
      );
    });

    test('risk rules T37–T39 [DER], registry rows and aliases', () {
      final ts = DateTime(2026, 11, 7);
      final crisis = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(phq9Total: 15, phq9Item9: 1),
        sessionId: 's',
        timestamp: ts,
      );
      expect(crisis.highestUrgency, UrgencyLevel.emergency);
      expect(
        crisis.orderedFlags.any((f) => f.conditionCode == 'COND_MOOD'),
        isTrue,
      );
      final moderate = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(phq9Total: 11, phq9Item9: 0, gad7Total: 4),
        sessionId: 's',
        timestamp: ts,
      );
      expect(moderate.highestUrgency, UrgencyLevel.routine);
      final fine = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(phq9Total: 3, phq9Item9: 0, gad7Total: 2),
        sessionId: 's',
        timestamp: ts,
      );
      expect(fine.highestUrgency, UrgencyLevel.none);
      final hf = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(hfAlert: true),
        sessionId: 's',
        timestamp: ts,
      );
      expect(hf.highestUrgency, UrgencyLevel.urgent);
      expect(
        hf.orderedFlags.any((f) => f.conditionCode == 'COND_HF_DECOMP'),
        isTrue,
      );
      expect(
        ConfirmatoryInvestigationsRegistry.byCondition['COND_MOOD'],
        isNotNull,
      );
      expect(
        ConfirmatoryInvestigationsRegistry.byCondition['COND_HF_DECOMP'],
        isNotNull,
      );
      expect(
        ConfirmatoryInvestigationsRegistry.forCode(
          'COND_COGNITIVE',
        ).conditionCode,
        'COND_COG',
      );
      for (final id in ['S-G12', 'S-G13', 'S-G14', 'S-G15', 'S-H06']) {
        expect(MindProtocols.forScreenId(id), isNotNull, reason: id);
      }
      expect(MindProtocols.forScreenId('S-G10'), isNull);
    });

    test(
      'session builder: cognitive, mood crisis, HF building/alert, stroke',
      () {
        final appState = AppState();
        final senior = appState.subjects.firstWhere(
          (s) => s.id == 'subj_senior_62',
        );
        // cognitive: values without a band
        final (fp, ft) = MindSimulated.fluencyTranscript(
          MindDemoOutcome.normal,
          MindLanguage.en,
        );
        final (pp, pt) = MindSimulated.pictureTranscript(
          MindDemoOutcome.normal,
        );
        final cog = buildMindSession(
          protocol: MindProtocols.cognitive,
          subject: senior,
          captures: [
            MindTaskCapture(
              taskId: 'fluency',
              transcript: ft,
              partials: fp,
              durationS: 60,
            ),
            MindTaskCapture(
              taskId: 'picture',
              transcript: pt,
              partials: pp,
              durationS: 60,
            ),
          ],
          demoOutcome: MindDemoOutcome.normal,
          sttAvailable: true,
        );
        expect(cog.band, SemanticBand.rangeNotAvailable);
        expect(cog.overall['FLUENCY_COUNT'], 18);
        expect(cog.markers['COG_BAND']!.value, isNull);
        expect(cog.urgency, UrgencyLevel.none);
        // mood crisis
        final mood = buildMindSession(
          protocol: MindProtocols.mood,
          subject: senior,
          captures: [
            MindTaskCapture(
              taskId: 'phq9',
              answers: MindSimulated.moodAnswers(MindDemoOutcome.crisis),
            ),
            MindTaskCapture(
              taskId: 'gad7',
              answers: MindSimulated.moodAnswers(MindDemoOutcome.crisis),
            ),
            MindTaskCapture(
              taskId: 'free_speech',
              features: VoiceFeatures.extract(
                MindSimulated.pcm(seconds: 20),
                16000,
              ),
              durationS: 60,
            ),
          ],
          demoOutcome: MindDemoOutcome.crisis,
        );
        expect(mood.crisis, isTrue);
        expect(mood.urgency, UrgencyLevel.emergency);
        expect(mood.markers['PHQ9']!.value, 15);
        expect(
          mood.markers['MOOD_VOICE_SCORE']!.displayStatus,
          isNot(MarkerDisplayStatus.ok),
        );
        // HF building (10 days) vs alert (14 days + yesterday high)
        final today = DateTime(2026, 11, 7);
        final f = VoiceFeatures.extract(MindSimulated.pcm(seconds: 30), 16000);
        final building = buildMindSession(
          protocol: MindProtocols.hfVoice,
          subject: senior,
          captures: [
            MindTaskCapture(taskId: 'hf_sentence', features: f, durationS: 30),
          ],
          demoOutcome: MindDemoOutcome.normal,
          hfBaseline: MindSimulated.hfBaseline(today, days: 10),
          now: today,
        );
        expect(building.hfBuilding, isTrue);
        expect(building.hfBaselineDay, 11);
        expect(building.urgency, UrgencyLevel.none);
        expect(building.markers['HF_ALERT']!.value, isNull);
        final base = MindSimulated.hfBaseline(today);
        final yesterday = HfDailySample(
          day: today.subtract(const Duration(days: 1)),
          vector: MindSimulated.hfToday(MindDemoOutcome.refer),
          deviation: 2.6,
        );
        // today's real features will not match the seeded baseline → high deviation
        final alert = buildMindSession(
          protocol: MindProtocols.hfVoice,
          subject: senior,
          captures: [
            MindTaskCapture(taskId: 'hf_sentence', features: f, durationS: 30),
          ],
          demoOutcome: MindDemoOutcome.refer,
          hfBaseline: [...base, yesterday],
          now: today,
        );
        expect(alert.hfBuilding, isFalse);
        expect(alert.overall['HF_VOICE_DEV'], greaterThan(0));
        // stroke positive with skipped parts
        final stroke = buildMindSession(
          protocol: MindProtocols.stroke,
          subject: senior,
          captures: [
            MindTaskCapture(
              taskId: 'face',
              faceRest: MindSimulated.faceRest(droopLeft: true),
              faceSmile: MindSimulated.faceSmile(droopLeft: true),
            ),
            const MindTaskCapture(taskId: 'arm_right', skipped: true),
            const MindTaskCapture(taskId: 'arm_left', skipped: true),
            const MindTaskCapture(taskId: 'speech', skipped: true),
          ],
          demoOutcome: MindDemoOutcome.refer,
          onsetLabel: 'Just now',
        );
        expect(stroke.isEmergency, isTrue);
        expect(stroke.positiveSigns, ['face']);
        expect(stroke.markers['STROKE_POSITIVE']!.value, true);
        expect(stroke.markers['FACE_ASYM_SIDE']!.value, 'left');
        expect(stroke.firedRuleCodes, contains('BR-SCR-01'));
        final negative = buildMindSession(
          protocol: MindProtocols.stroke,
          subject: senior,
          captures: [
            MindTaskCapture(
              taskId: 'face',
              faceRest: MindSimulated.faceRest(),
              faceSmile: MindSimulated.faceSmile(),
            ),
            MindTaskCapture(
              taskId: 'arm_right',
              armStart: MindSimulated.armHold().$1,
              armEnd: MindSimulated.armHold().$2,
            ),
            MindTaskCapture(
              taskId: 'arm_left',
              armStart: MindSimulated.armHold().$1,
              armEnd: MindSimulated.armHold().$2,
            ),
            MindTaskCapture(
              taskId: 'speech',
              transcript: MindTexts.sentence('strokeSentence', MindLanguage.en),
            ),
          ],
          demoOutcome: MindDemoOutcome.normal,
        );
        expect(negative.isEmergency, isFalse);
        expect(negative.band, SemanticBand.normal);
        expect(
          math.max(
            negative.overall['ARM_DRIFT_L']!,
            negative.overall['ARM_DRIFT_R']!,
          ),
          lessThan(ArmDrift.thresholdCm),
        );
      },
    );
  });
}
