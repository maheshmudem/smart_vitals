// End-to-end guided flow for the overnight sleep check (S-G07 Set up with
// the live checks → How-to → S-G08 night on the simulated sonar → S-G09
// report), on the simulated services with the fast night.
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/sleep/sleep_intro_screen.dart';
import 'package:algoritam/features/sleep/sleep_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppState> pumpIntro(
    WidgetTester tester, {
    String subject = 'subj_senior_62',
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appState = AppState();
    final s = appState.subjects.firstWhere((x) => x.id == subject);
    appState.selectSubject(appState.subjects.indexOf(s));
    await tester.pumpWidget(
      AppStateScope(
        notifier: appState,
        child: MaterialApp(key: UniqueKey(), home: const SleepIntroScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return appState;
  }

  final listScrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;

  Future<void> toPrepare(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Step 1 · Set up'), findsOneWidget);
  }

  Future<void> tapKeyButton(WidgetTester tester, String key, int pumps) async {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(key)),
      200,
      scrollable: listScrollable,
    );
    await tester.pump(const Duration(milliseconds: 100));
    (tester.widget(find.byKey(ValueKey(key))) as FilledButton).onPressed!();
    for (var i = 0; i < pumps; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> tickChecklist(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.ensureVisible(find.byKey(ValueKey('sleep_check_$i')));
      await tester.tap(find.byKey(ValueKey('sleep_check_$i')));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> throughSetupAndHowTo(
    WidgetTester tester, {
    bool weakSonar = false,
  }) async {
    await toPrepare(tester);
    await tickChecklist(tester);
    await tapKeyButton(tester, 'sleep_mic_check', 14);
    expect(find.textContaining('Passed'), findsOneWidget);
    if (weakSonar) {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sleep_sonar_sim_fail')),
        200,
        scrollable: listScrollable,
      );
      await tester.tap(find.byKey(const ValueKey('sleep_sonar_sim_fail')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tapKeyButton(tester, 'sleep_sonar_check', 14);
    if (weakSonar) {
      expect(find.textContaining('Weak echo'), findsOneWidget);
      // start is blocked until the warning is accepted
      final btn = find.widgetWithText(FilledButton, 'Continue');
      expect(tester.widget<FilledButton>(btn).onPressed, isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sleep_sonar_accept')),
        200,
        scrollable: listScrollable,
      );
      await tester.tap(find.byKey(const ValueKey('sleep_sonar_accept')));
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      expect(find.textContaining('Echo strong'), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('sleep_charger_label')),
      200,
      scrollable: listScrollable,
    );
    expect(find.textContaining('Charging'), findsWidgets);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Step 2 · How the night works'), findsOneWidget);
    await tester.tap(find.text('Start sleep monitoring'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('sleep_ready_title')), findsOneWidget);
  }

  Future<void> openControls(WidgetTester tester, List<String> chips) async {
    await tester.tap(find.byTooltip('Test Controls'));
    await tester.pump(const Duration(milliseconds: 200));
    for (final c in chips) {
      await tester.tap(find.text(c));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.byTooltip('Test Controls'));
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> startNight(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('sleep_start')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Pump in 500 ms steps until the report (or [untilContaining]) appears.
  Future<bool> pumpSeconds(
    WidgetTester tester,
    int s, {
    String? untilContaining,
  }) async {
    for (var i = 0; i < s * 2; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(SleepResultScreen).evaluate().isNotEmpty) return true;
      if (untilContaining != null &&
          find.textContaining(untilContaining).evaluate().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> expectReport(WidgetTester tester) async {
    expect(find.byType(SleepResultScreen), findsOneWidget);
    expect(find.text('Sleep report'), findsOneWidget);
    expect(find.text('Algorithm outputs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save to profile'));
    await tester.tap(find.text('Save to profile'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  bool flaggedBySave(AppState s, String cond) {
    final sid = s.screeningRecords.first.sessionId;
    return s.cases.any(
      (c) =>
          c.conditionCode == cond &&
          c.flags.any((f) => f.sourceSessionId == sid),
    );
  }

  group('Overnight sleep guided flow', () {
    testWidgets(
      'S-G07→S-G09 normal night: six markers, Sleep record, no COND_OSA case',
      (tester) async {
        final appState = await pumpIntro(tester);
        expect(find.textContaining('ALG-AUD-07'), findsWidgets);
        await throughSetupAndHowTo(tester);
        await startNight(tester);
        // the clock view: monitoring state, charger chip, valid-hours ring
        expect(find.byKey(const ValueKey('sleep_clock')), findsOneWidget);
        expect(find.text('Monitoring'), findsWidgets);
        expect(
          find.byKey(const ValueKey('sleep_chip_charger')),
          findsOneWidget,
        );
        await pumpSeconds(tester, 150);
        await expectReport(tester);
        expect(find.textContaining('under 5'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('sleep_partial_banner')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('sleep_rr_chart')), findsOneWidget);
        await save(tester);
        final rec = appState.screeningRecords.first;
        expect(rec.category, 'Sleep');
        expect(rec.screenId, 'S-G09');
        final codes = rec.markers.map((m) => m.code).toSet();
        expect(
          codes,
          containsAll([
            'SONAR_RR',
            'APNOEA_EVENTS',
            'HYPOPNOEA_EVENTS',
            'AHI_EST',
            'OSA_BAND',
            'VALID_SLEEP_H',
          ]),
        );
        expect(rec.urgency, UrgencyLevel.none);
        expect(flaggedBySave(appState, 'COND_OSA'), isFalse);
        expect(find.text('Saved'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G09 moderate night: Routine banner, COND_OSA case, BR-SCR-05 (T42)',
      (tester) async {
        final appState = await pumpIntro(tester);
        await throughSetupAndHowTo(tester);
        await openControls(tester, ['Outcome: Moderate']);
        await startNight(tester);
        await pumpSeconds(tester, 150);
        await expectReport(tester);
        expect(find.textContaining('Routine follow-up'), findsOneWidget);
        expect(find.textContaining('moderate range'), findsWidgets);
        expect(find.textContaining('Home sleep apnoea test'), findsWidgets);
        await save(tester);
        final rec = appState.screeningRecords.first;
        expect(rec.urgency, UrgencyLevel.routine);
        expect(rec.firedRules, contains('BR-SCR-05'));
        expect(flaggedBySave(appState, 'COND_OSA'), isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G09 severe night: red band, still Routine (§13.2), driving warning',
      (tester) async {
        final appState = await pumpIntro(tester);
        await throughSetupAndHowTo(tester);
        await openControls(tester, ['Outcome: Severe']);
        await startNight(tester);
        await pumpSeconds(tester, 150);
        await expectReport(tester);
        expect(find.textContaining('severe range'), findsWidgets);
        expect(find.textContaining('avoid driving'), findsOneWidget);
        await save(tester);
        expect(appState.screeningRecords.first.urgency, UrgencyLevel.routine);
        expect(
          appState.screeningRecords.first.primaryBand,
          SemanticBand.critical,
        );
        expect(flaggedBySave(appState, 'COND_OSA'), isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G09 short night (< 4 h): breathing rate only, E-AUD-003 copy',
      (tester) async {
        final appState = await pumpIntro(tester);
        await throughSetupAndHowTo(tester);
        await openControls(tester, ['Outcome: Short night']);
        await startNight(tester);
        await pumpSeconds(tester, 120);
        await expectReport(tester);
        expect(
          find.byKey(const ValueKey('sleep_partial_banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Insufficient valid sleep time'),
          findsWidgets,
        );
        expect(find.text('Breathing rate only'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('sleep_tile_AHI_EST')),
          findsOneWidget,
        );
        expect(
          (tester.widget(find.byKey(const ValueKey('sleep_tile_AHI_EST')))
                  as Text)
              .data,
          'n/a',
        );
        await save(tester);
        final rec = appState.screeningRecords.first;
        expect(rec.urgency, UrgencyLevel.none);
        expect(rec.markers.any((m) => m.code == 'SONAR_RR'), isTrue);
        expect(flaggedBySave(appState, 'COND_OSA'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G08 night: charger out → paused + warning, back in → monitoring; unplugged minutes on the report',
      (tester) async {
        await pumpIntro(tester);
        await throughSetupAndHowTo(tester);
        await startNight(tester);
        await tester.pump(const Duration(seconds: 2));
        // reveal controls and pull the charger
        await tester.tap(find.byKey(const ValueKey('sleep_clock')));
        await tester.pump(const Duration(milliseconds: 300));
        await openControls(tester, ['Simulate unplugged']);
        await pumpSeconds(tester, 8, untilContaining: 'charger disconnected');
        expect(
          find.textContaining('Paused — charger disconnected'),
          findsOneWidget,
        );
        expect(find.text('Unplugged!'), findsOneWidget);
        await tester.pump(const Duration(seconds: 65));
        await openControls(tester, ['Simulate unplugged']);
        await pumpSeconds(tester, 8, untilContaining: 'Monitoring');
        expect(find.text('Monitoring'), findsWidgets);
        await pumpSeconds(tester, 150);
        await expectReport(tester);
        expect(find.textContaining('Unplugged'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G07 weak sonar echo: warning, start allowed after accepting, report shows it',
      (tester) async {
        await pumpIntro(tester);
        await throughSetupAndHowTo(tester, weakSonar: true);
        await startNight(tester);
        await pumpSeconds(tester, 150);
        await expectReport(tester);
        expect(find.textContaining('Weak sonar echo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G07 charger gate (G-30) blocks Continue; early Stop asks to confirm and reports the breathing rate only',
      (tester) async {
        await pumpIntro(tester);
        await toPrepare(tester);
        await tickChecklist(tester);
        await tapKeyButton(tester, 'sleep_mic_check', 14);
        await tapKeyButton(tester, 'sleep_sonar_check', 14);
        // unplug → blocked
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('sleep_sim_unplugged')),
          200,
          scrollable: listScrollable,
        );
        await tester.tap(find.byKey(const ValueKey('sleep_sim_unplugged')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('Not charging'), findsOneWidget);
        expect(find.textContaining('Plug the charger in'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Continue'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byKey(const ValueKey('sleep_sim_unplugged')));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Start sleep monitoring'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 600));
        await openControls(tester, ['Fast night auto-stop']); // manual stop
        await startNight(tester);
        await tester.pump(const Duration(seconds: 3));
        // long-press Stop for 2 s
        await tester.tap(find.byKey(const ValueKey('sleep_clock')));
        await tester.pump(const Duration(milliseconds: 300));
        final g = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('sleep_stop'))),
        );
        await tester.pump(const Duration(milliseconds: 600));
        for (var i = 0; i < 18; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await g.up();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Stop now?'), findsOneWidget);
        expect(
          find.textContaining('Not enough sleep recorded'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('sleep_stop_confirm')));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpSeconds(tester, 20);
        await expectReport(tester);
        expect(
          find.byKey(const ValueKey('sleep_partial_banner')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
