import 'dart:math' as math;

import 'package:algoritam/core/domain/algorithms/movement_engines.dart';
import 'package:algoritam/core/domain/algorithms/movement_session_builder.dart';
import 'package:algoritam/core/domain/algorithms/risk_engine.dart';
import 'package:algoritam/core/domain/entities/case_record.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/marker_catalogue.dart';
import 'package:algoritam/core/domain/entities/movement_protocol.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Movement engines (ALG-MOV-01..05) on synthetic signals', () {
    test(
      'tapping: 4 Hz for 10 s with 30 % decay → ~40 taps, ~4 Hz, decrement ≥ 20 %',
      () {
        final m = TapSeriesAnalyzer.analyze(
          MovementSynthetic.tapping(fps: 30, hz: 4, decrementPct: 40),
        );
        expect(m.count, inInclusiveRange(38, 42));
        expect(m.freqHz, closeTo(4.0, 0.3));
        expect(m.decrementPct, greaterThanOrEqualTo(20));
        expect(m.cvPct, lessThan(15));
        final steady = TapSeriesAnalyzer.analyze(
          MovementSynthetic.tapping(fps: 30, hz: 4, decrementPct: 5),
        );
        expect(steady.decrementPct, lessThan(20));
        expect(TapSeriesAnalyzer.analyze(const []).count, 0);
      },
    );

    test(
      'tapping: fast taps at phone frame rates (12–20 fps) are still counted',
      () {
        for (final (fps, hz) in [(12.0, 4.0), (15.0, 5.0), (20.0, 6.0)]) {
          final m = TapSeriesAnalyzer.analyze(
            MovementSynthetic.tapping(fps: fps, hz: hz, decrementPct: 50),
          );
          final expected = (hz * 10).round();
          expect(
            m.count,
            inInclusiveRange(expected - 3, expected + 2),
            reason: '$fps fps / $hz Hz',
          );
        }
        // Live counter fed frame by frame matches the batch count.
        final series = MovementSynthetic.tapping(
          fps: 15,
          hz: 5,
          decrementPct: 40,
        );
        final live = TapReversalCounter();
        for (var i = 0; i < series.length; i++) {
          live.add(i, series[i].t, series[i].normDistance);
        }
        expect(live.count, inInclusiveRange(47, 52));
        // Rest jitter alone never counts.
        final still = TapReversalCounter();
        final r = math.Random(3);
        for (var i = 0; i < 300; i++) {
          still.add(i, i / 30, 0.6 + 0.015 * (r.nextDouble() - 0.5));
        }
        expect(still.count, 0);
      },
    );

    test(
      'touch tapping: alternating taps only, CV of intervals, < 5 flagged',
      () {
        final m = TouchTapAnalyzer.analyze(const [
          TouchTap(0, 0),
          TouchTap(250, 1),
          TouchTap(500, 0),
          TouchTap(750, 1),
          TouchTap(1000, 0),
          TouchTap(1100, 0), // same target → miss
          TouchTap(1250, 1),
        ]);
        expect(m.alternatingCount, 6);
        expect(m.misses, 1);
        expect(m.interTapCvPct, closeTo(0, 0.01));
        expect(m.tooFew, isFalse);
        expect(
          TouchTapAnalyzer.analyze(const [
            TouchTap(0, 0),
            TouchTap(300, 1),
          ]).tooFew,
          isTrue,
        );
      },
    );

    test(
      'gait: 1.8 Hz steps for 8 s → ~14 steps, cadence ~105, speed ~1.2 m/s; standing still → no rhythm',
      () {
        final m = GaitAnalyzer.analyze(
          MovementSynthetic.walking(stepHz: 1.8, seconds: 8),
        );
        expect(m.valid, isTrue);
        expect(m.steps, inInclusiveRange(13, 16));
        expect(m.cadenceSpm, inInclusiveRange(95, 118));
        expect(m.speedMs, inInclusiveRange(1.05, 1.40));
        expect(m.achievedHz, closeTo(50, 2));
        final still = GaitAnalyzer.analyze(
          MovementSynthetic.standingStill(seconds: 8),
        );
        expect(still.valid, isFalse);
      },
    );

    test('sit-to-stand: 12 cycles in 30 s → 12; dropout flagged on gaps', () {
      final m = StsCycleCounter.analyze(
        MovementSynthetic.sitToStand(cycles: 12, seconds: 30),
      );
      expect(m.count, inInclusiveRange(11, 13));
      expect(m.dropout, isFalse);
      final gapped = MovementSynthetic.sitToStand(
        cycles: 12,
        seconds: 30,
      ).where((s) => s.t < 10 || s.t > 11).toList();
      expect(StsCycleCounter.analyze(gapped).dropout, isTrue);
    });

    test(
      'tremor: 5 Hz 30 deg/s → peak 5.0 Hz above floor; still hand → no peak; 1 Hz 80 deg/s → gross movement',
      () {
        final t = TremorAnalyzer.analyze(
          MovementSynthetic.tremor(hz: 5, ampDegS: 30),
        );
        expect(t.peakAboveFloor, isTrue);
        expect(t.freqHz, closeTo(5.0, 0.25));
        expect(t.ampDegS, greaterThan(10));
        expect(t.grossMovement, isFalse);
        final still = TremorAnalyzer.analyze(MovementSynthetic.stillHand());
        expect(still.peakAboveFloor, isFalse);
        expect(still.freqHz, isNull);
        final gross = TremorAnalyzer.analyze(MovementSynthetic.grossMovement());
        expect(gross.grossMovement, isTrue);
        final essential = TremorAnalyzer.analyze(
          MovementSynthetic.tremor(hz: 8, ampDegS: 12),
        );
        expect(essential.freqHz, closeTo(8.0, 0.25));
      },
    );

    test(
      'risk rules T30 / T31 [DER]: fall risk and Parkinson signs → Routine with COND_FALL / COND_PD',
      () {
        final fall = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(gaitSpeedMs: 0.7),
        );
        expect(fall.highestUrgency, UrgencyLevel.routine);
        expect(fall.orderedFlags.first.conditionCode, 'COND_FALL');
        final sts = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(stsCount: 9, stsAgeNormMin: 12),
        );
        expect(sts.orderedFlags.first.markerCode, 'STS_COUNT_30S');
        final pd = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(tapDecrementPct: 24, tremorPeakHz: 5.1),
        );
        expect(pd.highestUrgency, UrgencyLevel.routine);
        expect(
          pd.orderedFlags.every((f) => f.conditionCode == 'COND_PD'),
          isTrue,
        );
        expect(pd.orderedFlags.length, 2);
        final ok = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(
            gaitSpeedMs: 1.2,
            tapDecrementPct: 8,
            tremorPeakHz: 8.0,
          ),
        );
        expect(ok.highestUrgency, UrgencyLevel.none);
        expect(
          ConfirmatoryInvestigationsRegistry.byCondition['COND_PD'],
          isNotNull,
        );
        expect(
          ConfirmatoryInvestigationsRegistry.byCondition['COND_FALL'],
          isNotNull,
        );
      },
    );

    test('protocols and catalogue aliases', () {
      expect(MovementProtocols.all.length, 5);
      for (final id in ['S-H01', 'S-H02', 'S-H03', 'S-H04', 'S-H05']) {
        expect(MovementProtocols.forScreenId(id), isNotNull, reason: id);
      }
      expect(MovementProtocols.forScreenId('S-H06'), isNull);
      expect(MovementProtocols.gait.requiredGates, contains(GateId.g13));
      expect(
        MovementProtocols.tappingVideo.requiredGates,
        contains(GateId.g11),
      );
      expect(MarkerCatalogue.cardOf('TREMOR_FREQ_L')!.id, 'ALG-MOV-05');
      expect(MarkerCatalogue.cardOf('TAP_DECREMENT_R')!.id, 'ALG-MOV-01');
      expect(
        MarkerCatalogue.byCode('TOUCH_TAP_COUNT_L')!.code,
        'TOUCH_TAP_COUNT',
      );
      expect(stsAgeNorm(62), 12);
      expect(stsAgeNorm(45), isNull);
    });

    test(
      'session builder: tremor refer, gait normal, STS below norm, skipped hand',
      () {
        final appState = AppState();
        final senior = appState.subjects.firstWhere(
          (s) => s.id == 'subj_senior_62',
        );
        final tremor = buildMovementSession(
          protocol: MovementProtocols.tremor,
          subject: senior,
          captures: [
            MovementSideCapture(
              side: MovementSide.right,
              motion: MovementSynthetic.tremor(hz: 5, ampDegS: 30),
            ),
            const MovementSideCapture(side: MovementSide.left, skipped: true),
          ],
          backend: 'sensors',
          demoOutcome: MovementDemoOutcome.refer,
        );
        expect(tremor.band, SemanticBand.refer);
        expect(tremor.urgency, UrgencyLevel.routine);
        expect(tremor.firedRuleCodes, contains('BR-SCR-04'));
        expect(tremor.markers['TREMOR_FREQ_R']!.value, closeTo(5.0, 0.25));
        expect(
          tremor.markers['TREMOR_FREQ_L']!.displayStatus,
          MarkerDisplayStatus.notAssessed,
        );
        expect(tremor.isPartiallyAssessed, isTrue);

        final gait = buildMovementSession(
          protocol: MovementProtocols.gait,
          subject: senior,
          captures: [
            MovementSideCapture(
              side: null,
              motion: MovementSynthetic.walking(seconds: 8),
            ),
          ],
          backend: 'sensors',
          demoOutcome: MovementDemoOutcome.normal,
        );
        expect(gait.band, SemanticBand.normal);
        expect(gait.heroCode, 'GAIT_SPEED');
        expect(gait.markers['GAIT_SPEED']!.value, inInclusiveRange(1.05, 1.40));
        expect(gait.markers['STEPS'], isNotNull);
        expect(gait.pd.complete, isFalse);

        final sts = buildMovementSession(
          protocol: MovementProtocols.sitToStand,
          subject: senior,
          captures: [
            MovementSideCapture(
              side: null,
              motion: MovementSynthetic.sitToStand(cycles: 8, seconds: 30),
            ),
          ],
          backend: 'sensors',
          demoOutcome: MovementDemoOutcome.refer,
        );
        expect(sts.band, SemanticBand.refer);
        expect(sts.ageNormLabel, contains('12'));
        expect(sts.urgency, UrgencyLevel.routine);
      },
    );
  });
}
