import 'dart:math' as math;

import 'package:algoritam/core/domain/algorithms/hearing_engines.dart';
import 'package:algoritam/core/domain/algorithms/hearing_session_builder.dart';
import 'package:algoritam/core/domain/algorithms/risk_engine.dart';
import 'package:algoritam/core/domain/entities/case_record.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/hearing_protocol.dart';
import 'package:algoritam/core/domain/entities/marker_catalogue.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hearing engines (ALG-AUD-09, CAP-12)', () {
    test('tone level: gain from dB HL with the assumed full scale', () {
      expect(ToneLevel.gainFor(90), closeTo(1.0, 1e-9));
      expect(ToneLevel.gainFor(40), closeTo(math.pow(10, -50 / 20), 1e-9));
      expect(ToneLevel.gainFor(0), closeTo(math.pow(10, -90 / 20), 1e-12));
      expect(ToneLevel.gainFor(100), 1.0);
      expect(ToneLevel.fullScaleFromKnown(knownDbHl: 15, measuredDbHl: 25), 80);
    });

    test('Hughson–Westlake converges on simulated listeners', () {
      for (final t in [10.0, 25.0, 45.0, 70.0]) {
        final rng = math.Random(3);
        final s = HughsonWestlake(ear: HearingEar.right, hz: 1000, seed: 5);
        while (!s.done) {
          final isCatch = s.nextIsCatch();
          s.answer(HearingSimulated.hears(s.level, t, rng, isCatch: isCatch));
        }
        expect(s.threshold, isNotNull, reason: 'listener $t');
        expect(
          (s.threshold! - t).abs(),
          lessThanOrEqualTo(5),
          reason: 'listener $t → ${s.threshold}',
        );
        expect(s.presentations.length, lessThanOrEqualTo(22));
        expect(s.toneTrials, greaterThan(3));
      }
      // up 5 / down 10 (Spec §8): a miss after a hit climbs by 5
      final s = HughsonWestlake(ear: HearingEar.left, hz: 500, seed: 1);
      s.nextIsCatch();
      final l0 = s.level;
      s.answer(true);
      expect(s.level, l0 - 10);
      s.nextIsCatch();
      final l1 = s.level;
      s.answer(false);
      expect(s.level, l1 + 5);
    });

    test('no response at 80 dB HL and catch trials', () {
      final s = HughsonWestlake(ear: HearingEar.right, hz: 4000, seed: 2);
      while (!s.done) {
        s.nextIsCatch();
        s.answer(false);
      }
      expect(s.noResponse, isTrue);
      expect(s.threshold, ToneLevel.noResponseDbHl);
      // catch trials appear and false taps are counted
      final c = HughsonWestlake(ear: HearingEar.right, hz: 1000, seed: 9);
      var catches = 0;
      while (!c.done) {
        final isCatch = c.nextIsCatch();
        if (isCatch) catches++;
        c.answer(true);
      }
      expect(c.catchTrials, catches);
      expect(c.falsePositives, catches);
      expect(c.threshold, ToneLevel.minDbHl);
    });

    test('grading: PTA4, WHO grades [DER] and asymmetry', () {
      expect(HearingGrading.pta4({500: 10, 1000: 20, 2000: 30, 4000: 40}), 25);
      expect(HearingGrading.pta4({500: 10}), isNull);
      expect(HearingGrading.grade(19.9), HearingGrade.normal);
      expect(HearingGrading.grade(20), HearingGrade.mild);
      expect(HearingGrading.grade(34), HearingGrade.mild);
      expect(HearingGrading.grade(35), HearingGrade.moderate);
      expect(HearingGrading.grade(49), HearingGrade.moderate);
      expect(HearingGrading.grade(50), HearingGrade.severe);
      final r = {
        500: 40,
        1000: 45,
        2000: 50,
        4000: 60,
      }.map((k, v) => MapEntry(k, v.toDouble()));
      final l = {
        500: 25,
        1000: 30,
        2000: 30,
        4000: 40,
      }.map((k, v) => MapEntry(k, v.toDouble()));
      expect(HearingGrading.maxAsymmetry(r, l), 20);
      expect(HearingGrading.asymmetric(r, l), isTrue);
      expect(HearingGrading.asymmetric(r, r), isFalse);
    });

    test('digits in noise: staircase and SRT on a simulated listener', () {
      final rng = math.Random(4);
      final d = DigitsInNoise(seed: 2);
      while (!d.done) {
        final digits = d.next();
        expect(digits.length, 3);
        expect(digits.toSet().length, 3);
        final ok = HearingSimulated.dinCorrect(d.snrDb, -8, rng);
        d.answer(ok ? digits : digits.map((x) => (x + 1) % 10).toList());
      }
      expect(d.trials.length, DigitsInNoise.totalTriplets);
      expect(d.srtDb, isNotNull);
      expect(d.srtDb!, closeTo(-8, 2.0));
      // step rule: correct → −2 dB, wrong → +2 dB
      final e = DigitsInNoise(seed: 1);
      e.answer(e.next());
      expect(e.snrDb, -2);
      e.next();
      e.answer(const [0, 0, 0]);
      expect(e.snrDb, 0);
      expect(
        DigitsInNoise.speechGain(0),
        closeTo(DigitsInNoise.noiseGain(), 1e-9),
      );
      expect(DigitsInNoise.speechGain(-6), lessThan(DigitsInNoise.noiseGain()));
    });

    test('room noise: dBFS → dBA, 3 s window pass / fail', () {
      expect(NoiseLevel.dbaFromDbfs(-40), 35);
      expect(NoiseLevel.dbaFromDbfs(-40, offset: 90), 50);
      expect(NoiseLevel.passes(45), isTrue);
      expect(NoiseLevel.passes(45.1), isFalse);
      final w = NoiseWindow();
      for (var t = 0.0; t <= 3.2; t += 0.2) {
        w.add(t, 36 + (t * 10) % 4);
      }
      expect(w.complete, isTrue);
      expect(w.passes, isTrue);
      final loud = NoiseWindow();
      for (var t = 0.0; t <= 3.2; t += 0.2) {
        loud.add(t, 52);
      }
      expect(loud.passes, isFalse);
    });

    test('risk rules T35–T36 [DER], registry row, catalogue markers', () {
      final mild = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(ptaBetterEarDbHl: 22),
        sessionId: 's',
        timestamp: DateTime(2026, 11, 6),
      );
      expect(mild.highestUrgency, UrgencyLevel.routine);
      expect(
        mild.orderedFlags.any((f) => f.conditionCode == 'COND_HEARING_LOSS'),
        isTrue,
      );
      final fine = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(ptaBetterEarDbHl: 12),
        sessionId: 's',
        timestamp: DateTime(2026, 11, 6),
      );
      expect(fine.highestUrgency, UrgencyLevel.none);
      final asym = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(ptaBetterEarDbHl: 12, hearingAsymmetry: true),
        sessionId: 's',
        timestamp: DateTime(2026, 11, 6),
      );
      expect(asym.highestUrgency, UrgencyLevel.routine);
      expect(
        ConfirmatoryInvestigationsRegistry.byCondition['COND_HEARING_LOSS'],
        isNotNull,
      );
      for (final ear in ['R', 'L']) {
        for (final hz in [500, 1000, 2000, 4000]) {
          expect(MarkerCatalogue.byCode('HEAR_${ear}_$hz'), isNotNull);
        }
      }
      expect(HearingProtocols.forScreenId('S-G11')!.mode, HearingMode.pureTone);
      expect(HearingProtocols.forScreenId('S-G01'), isNull);
    });

    test('session builder: better-ear band, markers, DIN mode', () {
      final appState = AppState();
      final subj = appState.subjects.firstWhere(
        (s) => s.id == 'subj_senior_62',
      );
      final th = HearingSimulated.thresholds(HearingDemoOutcome.refer);
      final r = buildHearingSession(
        protocol: HearingProtocols.pureTone,
        subject: subj,
        captures: [
          HearingPartCapture(
            ear: HearingEar.right,
            thresholds: th[HearingEar.right]!,
          ),
          HearingPartCapture(
            ear: HearingEar.left,
            thresholds: th[HearingEar.left]!,
          ),
        ],
        demoOutcome: HearingDemoOutcome.refer,
        earphoneType: 'wired',
        earphonesVerified: true,
      );
      // better ear = left (PTA4 31.25) → mild
      expect(r.grade, HearingGrade.mild);
      expect(r.band, SemanticBand.mild);
      expect(r.heroValue, closeTo(31.25, 1e-9));
      expect(r.urgency, UrgencyLevel.routine);
      expect(r.asymmetric, isTrue);
      expect(r.markers['HEAR_R_4000']!.value, 60);
      expect(r.markers['HEAR_L_500']!.value, 25);
      expect(r.markers['HEARING_BAND']!.value, 'mild');
      expect(r.bandSubline, contains('Mild'));

      final normal = buildHearingSession(
        protocol: HearingProtocols.pureTone,
        subject: subj,
        captures: [
          HearingPartCapture(
            ear: HearingEar.right,
            thresholds: const {500: 10, 1000: 5, 2000: 10, 4000: 15},
          ),
          const HearingPartCapture(ear: HearingEar.left, skipped: true),
        ],
        demoOutcome: HearingDemoOutcome.normal,
      );
      expect(normal.band, SemanticBand.normal);
      expect(normal.isPartiallyAssessed, isTrue);
      expect(normal.urgency, UrgencyLevel.none);

      final rng = math.Random(1);
      final d = DigitsInNoise(seed: 3);
      while (!d.done) {
        final digits = d.next();
        d.answer(
          HearingSimulated.dinCorrect(d.snrDb, -6, rng)
              ? digits
              : const [0, 0, 0],
        );
      }
      final din = buildHearingSession(
        protocol: HearingProtocols.digitsInNoise,
        subject: subj,
        captures: [HearingPartCapture(dinTrials: d.trials, srtDb: d.srtDb)],
        demoOutcome: HearingDemoOutcome.normal,
      );
      expect(din.band, SemanticBand.rangeNotAvailable);
      expect(din.markers['DIN_SRT_DB']!.value, isNotNull);
      expect(din.markers['HEARING_BAND']!.value, isNull);
      expect(din.urgency, UrgencyLevel.none);
    });
  });
}
