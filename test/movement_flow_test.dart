import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/movement_protocol.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/movement/movement_capture_screen.dart';
import 'package:algoritam/features/movement/movement_intro_screen.dart';
import 'package:algoritam/features/movement/movement_result_screen.dart';
import 'package:algoritam/features/results_cases/results_cases_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Movement section (S-H01..S-H05) guided flows', () {
    late AppState appState;

    Future<void> pumpScreen(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        AppStateScope(
          notifier: appState,
          child: MaterialApp(key: UniqueKey(), home: child),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    }

    setUp(() {
      appState = AppState();
      final senior = appState.subjects.firstWhere(
        (s) => s.id == 'subj_senior_62',
      );
      appState.selectSubject(appState.subjects.indexOf(senior));
    });

    Future<void> throughPrepareAndHowTo(
      WidgetTester tester,
      MovementProtocol p,
    ) async {
      expect(find.text('Step 1 · Set up'), findsOneWidget);
      for (var i = 0; i < p.prepareChecklist.length; i++) {
        await tester.ensureVisible(find.byKey(ValueKey('mov_check_$i')));
        await tester.tap(find.byKey(ValueKey('mov_check_$i')));
        await tester.pump();
      }
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Step 2 · How to do the test'), findsOneWidget);
      expect(find.text('Play instructions aloud'), findsOneWidget);
      await tester.tap(find.text('Start test'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    }

    Future<void> tapTargets(WidgetTester tester, int pairs) async {
      for (var i = 0; i < pairs; i++) {
        await tester.tap(find.byKey(const ValueKey('mov_target_0')));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(find.byKey(const ValueKey('mov_target_1')));
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<void> runSide(
      WidgetTester tester,
      MovementProtocol p, {
      bool second = false,
    }) async {
      final startLabel = second ? 'Start left hand' : 'Start';
      await tester.tap(find.text(startLabel));
      await tester.pump(const Duration(milliseconds: 100));
      // countdown
      await tester.pump(Duration(seconds: p.countdownSeconds + 1));
      expect(tester.takeException(), isNull);
      if (p.kind == MovementTestKind.tappingTouch) {
        await tapTargets(tester, 8);
      }
      final seconds = p.kind == MovementTestKind.gait
          ? 16
          : p.secondsPerSide + 2;
      // pump in small steps so the simulated sensor timers run
      for (var s = 0; s < seconds; s++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
    }

    Future<void> finishToResult(WidgetTester tester, MovementProtocol p) async {
      // analysis stages at 420 ms each + navigation
      for (var i = 0; i <= p.analysisStages.length + 1; i++) {
        await tester.pump(const Duration(milliseconds: 450));
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MovementResultScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    for (final p in MovementProtocols.all) {
      testWidgets(
        '${p.screenId} ${p.shortTitle}: intro → prepare → how-to → test → result → save',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await pumpScreen(tester, MovementIntroScreen(protocol: p));
          expect(find.text(p.title), findsWidgets);
          expect(find.textContaining(p.algorithmId), findsWidgets);
          await tester.pump(const Duration(milliseconds: 700)); // motion probe
          await tester.tap(find.text('Ready'));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.byType(MovementCaptureScreen), findsOneWidget);

          await throughPrepareAndHowTo(tester, p);
          await runSide(tester, p);
          if (p.twoSided) {
            expect(find.text('Start left hand'), findsOneWidget);
            await runSide(tester, p, second: true);
          }
          await finishToResult(tester, p);

          expect(find.text(p.resultTitle), findsOneWidget);
          expect(find.textContaining(p.algorithmId), findsWidgets);
          expect(find.text('Algorithm outputs'), findsOneWidget);
          expect(
            find.text("Parkinson's composite (ALG-MOV-13)"),
            findsOneWidget,
          );
          final before = appState.screeningRecords.length;
          await tester.ensureVisible(find.text('Save to profile'));
          await tester.tap(find.text('Save to profile'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Saved'), findsOneWidget);
          expect(appState.movementSessions.length, 1);
          expect(appState.screeningRecords.length, before + 1);
          final rec = appState.screeningRecords.first;
          expect(rec.category, 'Movement');
          expect(rec.title, p.recordTitle);
          expect(rec.markers, isNotEmpty);
          final result = appState.movementSessions.first;
          expect(
            result.perSide.where((s) => s.assessed),
            isNotEmpty,
            reason: 'a side should be assessed',
          );
          if (p.kind == MovementTestKind.gait) {
            expect(result.markers['GAIT_SPEED'], isNotNull);
            expect(result.band, SemanticBand.normal);
          }
          if (p.kind == MovementTestKind.sitToStand) {
            expect(result.markers['STS_COUNT_30S'], isNotNull);
          }
          if (p.kind == MovementTestKind.tappingTouch) {
            expect(result.markers['TOUCH_TAP_COUNT_R'], isNotNull);
            expect(result.markers['TOUCH_TAP_COUNT_L'], isNotNull);
          }
          if (p.kind == MovementTestKind.tappingVideo) {
            expect(result.markers['TAP_COUNT_R'], isNotNull);
            expect(result.quality.backend, 'simulated');
          }
          if (p.kind == MovementTestKind.tremor) {
            expect(result.band, SemanticBand.normal);
          }

          // History renders the saved record with its spec markers.
          await pumpScreen(tester, SharedScreeningResultScreen(record: rec));
          expect(find.textContaining(p.algorithmId), findsWidgets);
        },
      );
    }

    testWidgets('skip a hand: tremor left hand skipped → partial result', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const p = MovementProtocols.tremor;
      await pumpScreen(
        tester,
        const MovementCaptureScreen(protocol: p, startAtHowTo: true),
      );
      await tester.tap(find.text('Start test'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      await runSide(tester, p);
      expect(find.text('Skip this hand'), findsOneWidget);
      await tester.tap(find.text('Skip this hand'));
      await tester.pump(const Duration(milliseconds: 200));
      await finishToResult(tester, p);
      expect(find.text('Not assessed (skipped)'), findsOneWidget);
      expect(find.textContaining('One hand was not assessed'), findsWidgets);
    });

    testWidgets(
      'refer outcome via Test Controls: gait slow walk → Refer, COND_FALL case',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const p = MovementProtocols.gait;
        await pumpScreen(
          tester,
          const MovementCaptureScreen(protocol: p, startAtHowTo: true),
        );
        await tester.tap(find.text('Start test'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byTooltip('Test Controls'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Outcome: Refer'));
        await tester.pump(const Duration(milliseconds: 400));
        await runSide(tester, p);
        // slow walk lasts 14 s before standing still
        for (var s = 0; s < 8; s++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await finishToResult(tester, p);
        expect(find.textContaining('below the 0.8 m/s line'), findsWidgets);
        await tester.ensureVisible(find.text('Save to profile'));
        await tester.tap(find.text('Save to profile'));
        await tester.pump(const Duration(milliseconds: 300));
        final result = appState.movementSessions.first;
        expect(result.band, SemanticBand.refer);
        expect(result.urgency, UrgencyLevel.routine);
        expect(
          appState.cases.any((c) => c.conditionCode == 'COND_FALL'),
          isTrue,
        );
      },
    );
  });
}
