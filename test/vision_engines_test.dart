import 'dart:math' as math;

import 'package:algoritam/core/domain/algorithms/risk_engine.dart';
import 'package:algoritam/core/domain/algorithms/vision_engines.dart';
import 'package:algoritam/core/domain/algorithms/vision_session_builder.dart';
import 'package:algoritam/core/domain/entities/case_record.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/marker_catalogue.dart';
import 'package:algoritam/core/domain/entities/vision_protocol.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vision engines (ALG-MOV-10..12, CAP-15)', () {
    test('optotype: 5 arcmin at logMAR 0.0 and 40 cm = 0.58 mm', () {
      expect(Optotype.heightMm(0.0, 40), closeTo(0.582, 0.005));
      expect(Optotype.heightMm(1.0, 40), closeTo(5.82, 0.05));
      // 1 px stroke at 160 dpi needs ≈ 0.16 mm stroke → 0.79 mm letter.
      expect(Optotype.strokePx(0.0, 40, 160), closeTo(0.73, 0.05));
      expect(Optotype.snellen(0.0), '6/6');
      expect(Optotype.snellen(0.2), '6/9.5');
      expect(Optotype.snellen(1.0), '6/60');
    });

    test('face distance: pinhole model and calibration round-trip', () {
      final f = FaceDistance.focalPxFromCalibration(
        featurePx: 90,
        knownDistanceCm: 40,
      );
      expect(
        FaceDistance.distanceCm(featurePx: 90, focalPx: f),
        closeTo(40, 1e-9),
      );
      expect(
        FaceDistance.distanceCm(featurePx: 120, focalPx: f),
        closeTo(30, 1e-6),
      );
      expect(FaceDistance.inRange(35), isTrue);
      expect(FaceDistance.inRange(45.5), isFalse);
    });

    test(
      'staircase converges on a simulated observer and never passes the floor',
      () {
        for (final trueLogMar in [0.0, 0.3, 0.7]) {
          final rng = math.Random(5);
          final s = TumblingEStaircase(seed: 9);
          var n = 0;
          while (!s.done && n < 60) {
            final shown = s.next();
            s.answer(
              VisionSimulated.acuityAnswer(shown, s.level, trueLogMar, rng),
            );
            n++;
          }
          expect(s.done, isTrue, reason: 'observer $trueLogMar did not finish');
          expect(n, lessThanOrEqualTo(40));
          expect(s.thresholdLogMar, isNotNull);
          expect(
            s.thresholdLogMar!,
            closeTo(trueLogMar, 0.15),
            reason: 'observer $trueLogMar',
          );
          expect(
            s.trials.every((t) => t.logMar >= Optotype.minLogMar - 1e-9),
            isTrue,
          );
        }
        // A perfect observer bottoms out at −0.3.
        final s = TumblingEStaircase(seed: 2);
        while (!s.done) {
          s.answer(s.next());
        }
        expect(s.thresholdLogMar, closeTo(-0.3, 1e-9));
      },
    );

    test('digit glyphs: rounded numerals 1–9 with sensible ink share', () {
      for (var d = 1; d <= 9; d++) {
        final g = DigitGlyph.of(d);
        // centre of the first stroke is inside; far corners are outside
        final s = g.strokes.first;
        final mid = s[s.length ~/ 2];
        expect(g.signedDistance(mid.x, mid.y), lessThan(0), reason: '$d');
        expect(g.signedDistance(-0.5, -0.5), greaterThan(0));
        expect(g.signedDistance(1.2, 1.4), greaterThan(0));
        final share = g.areaShare();
        expect(share, inInclusiveRange(0.10, 0.80), reason: 'digit $d $share');
        // plate placement: ink stays inside the disc
        for (final st in g.strokes) {
          for (final p in st) {
            final lx = (p.x - DigitGlyph.boxWidth / 2) * 1.05;
            final ly = (p.y - 0.5) * 1.05;
            expect(math.sqrt(lx * lx + ly * ly), lessThan(0.9));
            expect(g.plateSignedDistance(lx, ly), lessThan(0));
          }
        }
      }
    });

    test('palettes: figure and ground share lightness; controls differ', () {
      for (final t in [PlateType.a, PlateType.b, PlateType.c]) {
        final p = ColourPlate(index: 0, digit: 5, type: t, seed: 1);
        for (var l = 0; l < 3; l++) {
          for (final f in p.figureLevels[l]) {
            for (final gnd in p.groundLevels[l]) {
              expect(
                (PlateColours.luminance(f) - PlateColours.luminance(gnd)).abs(),
                lessThan(0.02),
                reason: '$t level $l',
              );
            }
          }
        }
      }
      const c = ColourPlate(
        index: 0,
        digit: 5,
        type: PlateType.control,
        seed: 1,
      );
      expect(
        PlateColours.luminance(c.groundLevels[0][0]) -
            PlateColours.luminance(c.figureLevels[2][0]),
        greaterThan(0.4),
      );
    });

    test('dot layout: dense, no dot crosses the numeral outline', () {
      final set = ColourPlateSet.generate();
      for (final p in set.plates) {
        final l = PlateDotLayout.build(p, 150);
        expect(l.coverage, greaterThan(0.55), reason: 'plate ${p.index}');
        expect(l.dots.length, greaterThan(500));
        final g = DigitGlyph.of(p.digit);
        for (final d in l.dots) {
          final sd = g.plateSignedDistance(d.x / 150, d.y / 150) * 150;
          expect(sd < 0, d.figure);
          expect(sd.abs() + 1e-6, greaterThanOrEqualTo(d.r));
          expect(
            math.sqrt(d.x * d.x + d.y * d.y) + d.r,
            lessThanOrEqualTo(150.01),
          );
        }
      }
      // cached lookup returns the same object
      expect(
        identical(
          PlateDotLayout.of(set.plates[1], 120),
          PlateDotLayout.of(set.plates[1], 120),
        ),
        isTrue,
      );
    });

    test(
      'colour plates: 12 plates with 2 controls; scoring and screening line',
      () {
        final set = ColourPlateSet.generate(seed: 7);
        expect(set.plates.length, 12);
        expect(set.plates.where((p) => p.isControl).length, 2);
        expect(set.plates[0].isControl && set.plates[6].isControl, isTrue);
        final screeningDigits = set.plates
            .where((p) => !p.isControl)
            .map((p) => p.digit)
            .toSet();
        expect(screeningDigits, {1, 2, 3, 4, 5, 6, 7, 8, 9});
        for (var i = 1; i < set.plates.length; i++) {
          expect(set.plates[i].digit, isNot(set.plates[i - 1].digit));
        }
        for (final t in [PlateType.a, PlateType.b, PlateType.c]) {
          expect(set.plates.where((p) => p.type == t).length, greaterThan(2));
        }
        for (var s = 1; s < 6; s++) {
          final other = ColourPlateSet.generate(seed: s);
          expect(
            other.plates.where((p) => !p.isControl).map((p) => p.digit).toSet(),
            {1, 2, 3, 4, 5, 6, 7, 8, 9},
          );
          for (var i = 1; i < other.plates.length; i++) {
            expect(other.plates[i].digit, isNot(other.plates[i - 1].digit));
          }
        }
        final normal = ColourPlateScorer.score(
          set,
          VisionSimulated.plateAnswers(set, redGreenDeficient: false),
        );
        expect(normal.score, 12);
        expect(normal.allCorrect, isTrue);
        expect(normal.controlFailed, isFalse);
        expect(normal.screeningCorrect, 10);
        expect(normal.controlCorrect, 2);
        expect(normal.review.length, 12);
        expect(normal.review.every((r) => r.correct), isTrue);
        expect(normal.medianResponseMs, isNotNull);
        final rg = ColourPlateScorer.score(
          set,
          VisionSimulated.plateAnswers(set, redGreenDeficient: true),
        );
        expect(rg.score, lessThanOrEqualTo(9));
        expect(rg.likelyRedGreen, isTrue);
        expect(rg.controlFailed, isFalse);
        expect(rg.missed.length, 10);
        expect(
          rg.missed.every((r) => !r.isControl && r.answered == null),
          isTrue,
        );
        // Missing a control plate flags the screen, not the member.
        final bad = ColourPlateScorer.score(set, [
          for (final p in set.plates)
            ColourPlateAnswer(
              plateIndex: p.index,
              answered: p.isControl ? null : p.digit,
            ),
        ]);
        expect(bad.controlFailed, isTrue);
        expect(bad.controlCorrect, 0);
        expect(bad.screeningCorrect, 10);
      },
    );

    test('amsler: marks → abnormal, central involvement, quadrants', () {
      final none = AmslerMarks(declaredNormal: true);
      expect(none.abnormal, isFalse);
      final centre = AmslerMarks(marked: {9 * 20 + 9, 10 * 20 + 10});
      expect(centre.abnormal, isTrue);
      expect(centre.centralInvolved, isTrue);
      final corner = AmslerMarks(marked: {0, 1, 20});
      expect(corner.centralInvolved, isFalse);
      expect(corner.quadrants, ['upper left']);
    });

    test('reaction time: median of valid trials, < 100 ms discarded', () {
      final trials = [
        ...VisionSimulated.reactionTrials(
          block: ReactionBlock.visual,
          meanMs: 250,
          falseStarts: 2,
        ),
        const ReactionTrial(
          block: ReactionBlock.visual,
          gapS: 2,
          latencyMs: 80,
          falseStart: false,
        ),
      ];
      final r = ReactionTimeAnalyzer.analyzeBlock(trials, ReactionBlock.visual);
      expect(r.validCount, 10);
      expect(r.discarded, 3);
      expect(r.medianMs!, closeTo(250, 30));
      expect(ReactionTimeAnalyzer.median([3, 1, 2]), 2);
      expect(ReactionTimeAnalyzer.median([4, 1, 2, 3]), 2.5);
    });

    test('risk rules T32–T34 [DER] and registry rows', () {
      final acuity = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(logMarWorse: 0.7),
        sessionId: 's',
        timestamp: DateTime(2026, 11, 6),
      );
      expect(acuity.highestUrgency, UrgencyLevel.routine);
      expect(
        acuity.orderedFlags.any((f) => f.conditionCode == 'COND_CATARACT'),
        isTrue,
      );
      final fine = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(logMarWorse: 0.3),
        sessionId: 's',
        timestamp: DateTime(2026, 11, 6),
      );
      expect(fine.highestUrgency, UrgencyLevel.none);
      final amsler = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(amslerAbnormal: true),
        sessionId: 's',
        timestamp: DateTime(2026, 11, 6),
      );
      expect(
        amsler.orderedFlags.any((f) => f.conditionCode == 'COND_MACULA'),
        isTrue,
      );
      final colour = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(colourPlateMisses: 3),
        sessionId: 's',
        timestamp: DateTime(2026, 11, 6),
      );
      expect(
        colour.orderedFlags.any((f) => f.conditionCode == 'COND_COLOUR_VISION'),
        isTrue,
      );
      expect(
        ConfirmatoryInvestigationsRegistry.byCondition['COND_MACULA'],
        isNotNull,
      );
      expect(
        ConfirmatoryInvestigationsRegistry.byCondition['COND_COLOUR_VISION'],
        isNotNull,
      );
      expect(
        MarkerCatalogue.byCode('AMSLER_ABNORMAL_L')!.code,
        'AMSLER_ABNORMAL',
      );
      expect(VisionProtocols.forScreenId('S-H09')!.kind, VisionTestKind.amsler);
    });

    test(
      'session builder: acuity hero / markers, colour control fail, reaction',
      () {
        final appState = AppState();
        final subj = appState.subjects.firstWhere(
          (s) => s.id == 'subj_senior_62',
        );
        final r = buildVisionSession(
          protocol: VisionProtocols.acuity,
          subject: subj,
          captures: [
            VisionPartCapture(
              eye: VisionEye.right,
              thresholdLogMar: 0.1,
              acuityTrials: const [
                AcuityTrial(
                  logMar: 0.1,
                  shown: EDirection.up,
                  answered: EDirection.up,
                  correct: true,
                  distanceCm: 40,
                  distanceInRange: true,
                ),
              ],
            ),
            VisionPartCapture(
              eye: VisionEye.left,
              thresholdLogMar: 0.6,
              acuityTrials: const [
                AcuityTrial(
                  logMar: 0.6,
                  shown: EDirection.up,
                  answered: EDirection.up,
                  correct: true,
                  distanceCm: 41,
                  distanceInRange: true,
                ),
              ],
            ),
          ],
          demoOutcome: VisionDemoOutcome.refer,
          distanceMode: 'measured',
        );
        expect(r.band, SemanticBand.refer);
        expect(r.heroValue, closeTo(0.6, 1e-9));
        expect(r.markers.containsKey('LOGMAR_L'), isTrue);
        expect(r.markers.containsKey('LOGMAR_R'), isTrue);
        expect(r.markers.containsKey('face_distance_cm'), isTrue);
        expect(r.urgency, UrgencyLevel.routine);
        expect(r.bandSubline, contains('Left eye'));

        final set = ColourPlateSet.generate();
        final bad = buildVisionSession(
          protocol: VisionProtocols.colour,
          subject: subj,
          captures: [
            VisionPartCapture(
              plateSet: set,
              plateAnswers: [
                for (final p in set.plates)
                  ColourPlateAnswer(
                    plateIndex: p.index,
                    answered: p.isControl ? null : p.digit,
                  ),
              ],
            ),
          ],
          demoOutcome: VisionDemoOutcome.normal,
        );
        expect(bad.isNotAssessed, isTrue);
        expect(bad.quality.controlPlateFailed, isTrue);

        final rt = buildVisionSession(
          protocol: VisionProtocols.reaction,
          subject: subj,
          captures: [
            VisionPartCapture(
              block: ReactionBlock.visual,
              reactionTrials: VisionSimulated.reactionTrials(
                block: ReactionBlock.visual,
              ),
            ),
            VisionPartCapture(
              block: ReactionBlock.audio,
              reactionTrials: VisionSimulated.reactionTrials(
                block: ReactionBlock.audio,
                meanMs: 210,
              ),
            ),
          ],
          demoOutcome: VisionDemoOutcome.normal,
        );
        expect(rt.overall['RT_VISUAL_MS'], isNotNull);
        expect(rt.overall['RT_AUDIO_MS'], isNotNull);
        expect(
          rt.markers['RT_AUDIO_MS']!.displayStatus,
          MarkerDisplayStatus.rangeNotAvailable,
        );
        expect(rt.urgency, UrgencyLevel.none);
      },
    );
  });
}
