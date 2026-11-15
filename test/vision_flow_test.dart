// End-to-end guided flows for the vision section (S-H07..S-H10) on the
// simulated distance service and the auto-answer observer.
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/vision_protocol.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/vision/colour_plate_view.dart';
import 'package:algoritam/features/vision/vision_intro_screen.dart';
import 'package:algoritam/features/vision/vision_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppState> pumpIntro(WidgetTester tester, VisionProtocol p) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appState = AppState();
    final senior = appState.subjects.firstWhere(
      (s) => s.id == 'subj_senior_62',
    );
    appState.selectSubject(appState.subjects.indexOf(senior));
    await tester.pumpWidget(
      AppStateScope(
        notifier: appState,
        child: MaterialApp(
          key: UniqueKey(),
          home: VisionIntroScreen(protocol: p),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return appState;
  }

  Future<void> throughPrepareAndHowTo(
    WidgetTester tester,
    VisionProtocol p,
  ) async {
    await tester.ensureVisible(find.text('Ready'));
    await tester.tap(find.text('Ready'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Step 1 · Set up'), findsOneWidget);
    for (var i = 0; i < p.prepareChecklist.length; i++) {
      await tester.ensureVisible(find.byKey(ValueKey('vis_check_$i')));
      await tester.tap(find.byKey(ValueKey('vis_check_$i')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Step 2 · How to do the test'), findsOneWidget);
    expect(find.text('Play instructions aloud'), findsOneWidget);
    await tester.tap(find.text('Start test'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> enableAuto(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Test Controls'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Auto-answer (simulated)'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Test Controls'));
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Pump in 500 ms steps until the result screen or [until] appears.
  Future<void> pumpSeconds(WidgetTester tester, int s, {String? until}) async {
    for (var i = 0; i < s * 2; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(VisionResultScreen).evaluate().isNotEmpty) return;
      if (until != null && find.text(until).evaluate().isNotEmpty) return;
    }
  }

  Future<void> finishToResult(WidgetTester tester, VisionProtocol p) async {
    for (var i = 0; i < p.analysisStages.length + 3; i++) {
      await tester.pump(const Duration(milliseconds: 450));
    }
    expect(find.byType(VisionResultScreen), findsOneWidget);
    expect(find.text(p.resultTitle), findsOneWidget);
    expect(find.textContaining(p.algorithmId), findsWidgets);
    expect(find.text('Algorithm outputs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  group('Vision section (S-H07..S-H10) guided flows', () {
    for (final p in VisionProtocols.all) {
      testWidgets(
        '${p.screenId} ${p.title}: intro → prepare → how-to → test → result → save',
        (tester) async {
          final appState = await pumpIntro(tester, p);
          expect(find.text(p.title), findsWidgets);
          expect(find.textContaining(p.algorithmId), findsWidgets);
          await throughPrepareAndHowTo(tester, p);
          expect(find.text('Start'), findsOneWidget);
          await enableAuto(tester);
          await tester.tap(find.text('Start'));
          await tester.pump(const Duration(milliseconds: 100));
          await pumpSeconds(tester, 40);
          // second eye / block
          if (p.perEye || p.kind == VisionTestKind.reaction) {
            final second = p.perEye ? 'Start left eye' : 'Start sound block';
            expect(find.text(second), findsOneWidget, reason: '${p.id} switch');
            await tester.tap(find.text(second));
            await tester.pump(const Duration(milliseconds: 100));
            await pumpSeconds(tester, 40);
          }
          await finishToResult(tester, p);
          if (p.kind == VisionTestKind.colour) {
            expect(find.text('Plate review'), findsOneWidget);
            for (var i = 0; i < 12; i++) {
              expect(find.byKey(ValueKey('vis_review_$i')), findsOneWidget);
            }
            expect(find.text('Red–green screening plates'), findsOneWidget);
          }
          await tester.ensureVisible(find.text('Save to profile'));
          await tester.tap(find.text('Save to profile'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Saved'), findsOneWidget);
          final rec = appState.screeningRecords.first;
          expect(rec.category, 'Vision');
          expect(rec.title, p.recordTitle);
          expect(rec.markers, isNotEmpty);
          expect(appState.visionSessions.first.protocol.id, p.id);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('S-H07 refer outcome: left eye poor → COND_CATARACT case', (
      tester,
    ) async {
      final appState = await pumpIntro(tester, VisionProtocols.acuity);
      await throughPrepareAndHowTo(tester, VisionProtocols.acuity);
      await tester.tap(find.byTooltip('Test Controls'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Outcome: Refer'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Auto-answer (simulated)'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byTooltip('Test Controls'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpSeconds(tester, 70, until: 'Start left eye');
      await tester.tap(find.text('Start left eye'));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpSeconds(tester, 70);
      await finishToResult(tester, VisionProtocols.acuity);
      expect(find.textContaining('below the 0.2 line'), findsWidgets);
      await tester.ensureVisible(find.text('Save to profile'));
      await tester.tap(find.text('Save to profile'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        appState.cases.any((c) => c.conditionCode == 'COND_CATARACT'),
        isTrue,
      );
      expect(appState.screeningRecords.first.urgency, UrgencyLevel.routine);
    });

    testWidgets('S-H09 refer outcome: distortion marked → COND_MACULA case', (
      tester,
    ) async {
      final appState = await pumpIntro(tester, VisionProtocols.amsler);
      await throughPrepareAndHowTo(tester, VisionProtocols.amsler);
      await tester.tap(find.byTooltip('Test Controls'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Outcome: Refer'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Auto-answer (simulated)'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byTooltip('Test Controls'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpSeconds(tester, 10, until: 'Start left eye');
      await tester.tap(find.text('Start left eye'));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpSeconds(tester, 10);
      await finishToResult(tester, VisionProtocols.amsler);
      expect(find.textContaining('Distortion marked'), findsWidgets);
      await tester.ensureVisible(find.text('Save to profile'));
      await tester.tap(find.text('Save to profile'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        appState.cases.any((c) => c.conditionCode == 'COND_MACULA'),
        isTrue,
      );
    });

    testWidgets(
      'S-H08 manual keypad: three plates read, the rest "I see nothing" → refer',
      (tester) async {
        final appState = await pumpIntro(tester, VisionProtocols.colour);
        await throughPrepareAndHowTo(tester, VisionProtocols.colour);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Which number do you see?'), findsOneWidget);
        for (var i = 0; i < 12; i++) {
          final paint = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is ColourPlatePainter,
          );
          expect(paint, findsOneWidget, reason: 'plate $i');
          final plate =
              ((tester.widget(paint) as CustomPaint).painter
                      as ColourPlatePainter)
                  .plate;
          // Read the two controls and the first screening plate; miss the rest.
          if (plate.isControl || i == 1) {
            await tester.tap(find.byKey(ValueKey('vis_digit_${plate.digit}')));
          } else {
            await tester.tap(find.byKey(const ValueKey('vis_digit_none')));
          }
          await tester.pump(const Duration(milliseconds: 120));
        }
        await finishToResult(tester, VisionProtocols.colour);
        expect(find.textContaining('3 of 12 plates read'), findsWidgets);
        expect(find.text('Plate review'), findsOneWidget);
        expect(find.textContaining('you: none'), findsNWidgets(9));
        await tester.ensureVisible(find.text('Save to profile'));
        await tester.tap(find.text('Save to profile'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          appState.cases.any((c) => c.conditionCode == 'COND_COLOUR_VISION'),
          isTrue,
        );
      },
    );

    testWidgets(
      'S-H07 manual answers: arrow buttons drive the staircase; skip the left eye',
      (tester) async {
        await pumpIntro(tester, VisionProtocols.acuity);
        await throughPrepareAndHowTo(tester, VisionProtocols.acuity);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 300));
        // Answer "up" a few times: the E is keyed by its direction.
        for (var i = 0; i < 6; i++) {
          final e = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('vis_e_'),
          );
          if (e.evaluate().isEmpty) break;
          final dir =
              ((e.evaluate().first.widget.key as ValueKey<String>).value)
                  .replaceFirst('vis_e_', '');
          await tester.tap(find.byKey(ValueKey('vis_arrow_$dir')));
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Skip this eye'), findsOneWidget);
        await tester.tap(find.text('Skip this eye'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Start left eye'), findsOneWidget);
        await tester.tap(find.text('Skip this eye'));
        await tester.pump(const Duration(milliseconds: 300));
        await finishToResult(tester, VisionProtocols.acuity);
        expect(find.text('Not assessed (skipped)'), findsWidgets);
      },
    );
  });
}
