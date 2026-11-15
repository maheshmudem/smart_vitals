// End-to-end guided flows for the Breathing & Voice section (S-G02..S-G06
// with the S-G01 readiness checks in Prepare) on the simulated services
// and the auto-run.
import 'package:algoritam/core/domain/entities/breath_protocol.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/breath/breath_intro_screen.dart';
import 'package:algoritam/features/breath/breath_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppState> pumpIntro(
    WidgetTester tester,
    BreathProtocol p, {
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
        child: MaterialApp(
          key: UniqueKey(),
          home: BreathIntroScreen(protocol: p),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return appState;
  }

  Future<void> toPrepare(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Step 1 · Set up'), findsOneWidget);
  }

  /// The Prepare list's own scrollable (the first Scrollable under the
  /// ListView; text fields inside the list have their own).
  final listScrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;

  Future<void> runMicCheck(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('breath_mic_check')),
      200,
      scrollable: listScrollable,
    );
    await tester.pump(const Duration(milliseconds: 100));
    (tester.widget(find.byKey(const ValueKey('breath_mic_check')))
            as FilledButton)
        .onPressed!();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> runRoomCheck(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('breath_noise_check')),
      200,
      scrollable: listScrollable,
    );
    await tester.pump(const Duration(milliseconds: 100));
    (tester.widget(find.byKey(const ValueKey('breath_noise_check')))
            as FilledButton)
        .onPressed!();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> throughPrepareAndHowTo(
    WidgetTester tester,
    BreathProtocol p,
  ) async {
    await toPrepare(tester);
    for (var i = 0; i < p.prepareChecklist.length; i++) {
      await tester.ensureVisible(find.byKey(ValueKey('breath_check_$i')));
      await tester.tap(find.byKey(ValueKey('breath_check_$i')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await runMicCheck(tester);
    expect(find.textContaining('Passed'), findsOneWidget);
    await runRoomCheck(tester);
    expect(find.textContaining('Quiet enough'), findsOneWidget);
    if (p.needsBodyProfile) {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('breath_height')),
        200,
        scrollable: listScrollable,
      );
      await tester.enterText(
        find.byKey(const ValueKey('breath_height')),
        '170',
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Step 2 · How to do the check'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
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

  /// Pump in 500 ms steps until the result screen or [untilContaining]
  /// appears.
  Future<bool> pumpSeconds(
    WidgetTester tester,
    int s, {
    String? untilContaining,
  }) async {
    for (var i = 0; i < s * 2; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(BreathResultScreen).evaluate().isNotEmpty) return true;
      if (untilContaining != null &&
          find.textContaining(untilContaining).evaluate().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> finishToResult(WidgetTester tester, BreathProtocol p) async {
    for (var i = 0; i < p.analysisStages.length + 3; i++) {
      await tester.pump(const Duration(milliseconds: 450));
    }
    expect(find.byType(BreathResultScreen), findsOneWidget);
    expect(find.text(p.resultTitle), findsOneWidget);
    expect(find.text('Algorithm outputs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save to profile'));
    await tester.tap(find.text('Save to profile'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// True when a case for [cond] holds a flag raised by the newest record
  /// (the seeded profile already carries older TB / anaemia cases).
  bool flaggedBySave(AppState s, String cond) {
    final sessionId = s.screeningRecords.first.sessionId;
    return s.cases.any(
      (c) =>
          c.conditionCode == cond &&
          c.flags.any((f) => f.sourceSessionId == sessionId),
    );
  }

  group('Breathing & Voice guided flows', () {
    testWidgets(
      'Prepare: mic self-check failure blocks Continue (G-17), pass unblocks',
      (tester) async {
        final appState = await pumpIntro(tester, BreathProtocols.coughTb);
        expect(find.textContaining('ALG-AUD-01'), findsWidgets);
        await toPrepare(tester);
        for (var i = 0; i < 3; i++) {
          await tester.ensureVisible(find.byKey(ValueKey('breath_check_$i')));
          await tester.tap(find.byKey(ValueKey('breath_check_$i')));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('breath_mic_sim_fail')),
          200,
          scrollable: listScrollable,
        );
        (tester.widget(find.byKey(const ValueKey('breath_mic_sim_fail')))
                as ChoiceChip)
            .onSelected!(true);
        await tester.pump(const Duration(milliseconds: 100));
        await runMicCheck(tester);
        expect(find.textContaining('Failed'), findsOneWidget);
        expect(appState.deviceProfile.micSelfCheckPassed, isFalse);
        await runRoomCheck(tester);
        final continueButton = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Continue'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(continueButton.onPressed, isNull);
        expect(find.textContaining('Microphone check failed'), findsOneWidget);
        // fix and pass
        (tester.widget(find.byKey(const ValueKey('breath_mic_sim_fail')))
                as ChoiceChip)
            .onSelected!(true);
        await tester.pump(const Duration(milliseconds: 100));
        await runMicCheck(tester);
        expect(find.textContaining('Passed'), findsOneWidget);
        expect(appState.deviceProfile.micSelfCheckPassed, isTrue);
        final enabled = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Continue'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(enabled.onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Prepare: manual mic confirmation unblocks Continue and is recorded as manual',
      (tester) async {
        final appState = await pumpIntro(tester, BreathProtocols.voice);
        await toPrepare(tester);
        for (
          var i = 0;
          i < BreathProtocols.voice.prepareChecklist.length;
          i++
        ) {
          await tester.ensureVisible(find.byKey(ValueKey('breath_check_$i')));
          await tester.tap(find.byKey(ValueKey('breath_check_$i')));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('breath_mic_sim_fail')),
          200,
          scrollable: listScrollable,
        );
        (tester.widget(find.byKey(const ValueKey('breath_mic_sim_fail')))
                as ChoiceChip)
            .onSelected!(true);
        await tester.pump(const Duration(milliseconds: 100));
        await runMicCheck(tester);
        expect(find.textContaining('Failed'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('breath_mic_manual')),
          200,
          scrollable: listScrollable,
        );
        (tester.widget(find.byKey(const ValueKey('breath_mic_manual')))
                as CheckboxListTile)
            .onChanged!(true);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.textContaining('Confirmed by you'), findsOneWidget);
        expect(appState.deviceProfile.micSelfCheckPassed, isTrue);
        await runRoomCheck(tester);
        final enabled = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Continue'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(enabled.onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'first passing mic check records the phone profile; the next compares to it',
      (tester) async {
        final appState = await pumpIntro(tester, BreathProtocols.coughTb);
        expect(appState.deviceProfile.micSweepProfileDb, isNull);
        await toPrepare(tester);
        await runMicCheck(tester);
        expect(find.textContaining('profile recorded'), findsOneWidget);
        expect(appState.deviceProfile.micSweepProfileDb, isNotNull);
        await runMicCheck(tester);
        expect(find.textContaining('matches this phone'), findsOneWidget);
      },
    );

    testWidgets(
      'S-G03 clipping (CAP-13): re-record twice with the document line, then kept with a warning',
      (tester) async {
        await pumpIntro(tester, BreathProtocols.coughTb);
        await throughPrepareAndHowTo(tester, BreathProtocols.coughTb);
        await openControls(tester, [
          'Simulate clipping',
          'Auto-run (simulated)',
        ]);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        final seen = await pumpSeconds(
          tester,
          60,
          untilContaining: 'Move phone further / quieter room',
        );
        expect(seen, isTrue);
        await pumpSeconds(tester, 150);
        await finishToResult(tester, BreathProtocols.coughTb);
        expect(find.textContaining('Clipping on cough'), findsOneWidget);
        expect(find.textContaining('kept after 2 re-records'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('S-G05 rest countdown between blows with "skip rest"', (
      tester,
    ) async {
      await pumpIntro(tester, BreathProtocols.lungFunction);
      await throughPrepareAndHowTo(tester, BreathProtocols.lungFunction);
      expect(find.byKey(const ValueKey('breath_brief_title')), findsOneWidget);
      expect(find.text('WHAT TO DO'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 100));
      final seen = await pumpSeconds(tester, 40, untilContaining: 'Rest ·');
      expect(seen, isTrue);
      expect(find.byKey(const ValueKey('breath_rest_left')), findsOneWidget);
      expect(find.textContaining('Skip rest'), findsOneWidget);
      expect(find.textContaining('Blow 1:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'S-G03 cough & TB normal: questions + 3 coughs → low band, no case',
      (tester) async {
        final appState = await pumpIntro(tester, BreathProtocols.coughTb);
        await throughPrepareAndHowTo(tester, BreathProtocols.coughTb);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 300));
        // first question by hand, then auto-run
        expect(
          find.byKey(const ValueKey('breath_q_tb_cough2w')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('breath_answer_0')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const ValueKey('breath_q_tb_fever')), findsOneWidget);
        await openControls(tester, ['Auto-run (simulated)']);
        await pumpSeconds(tester, 120);
        await finishToResult(tester, BreathProtocols.coughTb);
        expect(
          find.byKey(const ValueKey('breath_tile_COUGH_COUNT_VALID')),
          findsOneWidget,
        );
        expect(find.text('3'), findsWidgets);
        expect(find.text('LOW'), findsOneWidget);
        expect(find.text('Low TB risk'), findsOneWidget);
        await save(tester);
        final rec = appState.screeningRecords.first;
        expect(rec.category, 'Breathing & Voice');
        expect(rec.title, BreathProtocols.coughTb.recordTitle);
        expect(rec.screenId, 'S-G06');
        expect(rec.markers.any((m) => m.code == 'TB_BAND'), isTrue);
        expect(flaggedBySave(appState, 'COND_TB'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G03 cough & TB refer: classic symptoms → urgent COND_TB case (BR-SCR-02)',
      (tester) async {
        final appState = await pumpIntro(tester, BreathProtocols.coughTb);
        await throughPrepareAndHowTo(tester, BreathProtocols.coughTb);
        await openControls(tester, ['Outcome: Refer', 'Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 120);
        await finishToResult(tester, BreathProtocols.coughTb);
        expect(find.textContaining('BR-SCR-02'), findsWidgets);
        expect(find.text('HIGH'), findsOneWidget);
        expect(find.textContaining('sputum NAAT'), findsWidgets);
        await save(tester);
        expect(flaggedBySave(appState, 'COND_TB'), isTrue);
        expect(appState.screeningRecords.first.urgency, UrgencyLevel.urgent);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G03 cough retry: fewer than 3 coughs → cough again (E-AUD-001), then result',
      (tester) async {
        await pumpIntro(tester, BreathProtocols.coughTb);
        await throughPrepareAndHowTo(tester, BreathProtocols.coughTb);
        await openControls(tester, [
          'Simulate few coughs',
          'Auto-run (simulated)',
        ]);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        final seen = await pumpSeconds(
          tester,
          60,
          untilContaining: 'Only 2 clear coughs',
        );
        expect(seen, isTrue);
        expect(find.textContaining('attempt 2 of 3'), findsOneWidget);
        await pumpSeconds(tester, 120);
        await finishToResult(tester, BreathProtocols.coughTb);
        expect(find.textContaining('2 attempts'), findsWidgets);
        expect(
          find.byKey(const ValueKey('breath_heard_cough')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G02 airway refer: questionnaires, coughs, "aaa", breaths, blow → high band, routine COND_OAD',
      (tester) async {
        final appState = await pumpIntro(tester, BreathProtocols.airway);
        await throughPrepareAndHowTo(tester, BreathProtocols.airway);
        await openControls(tester, ['Outcome: Refer', 'Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 200);
        await finishToResult(tester, BreathProtocols.airway);
        expect(
          find.byKey(const ValueKey('breath_tile_OAD_BAND')),
          findsOneWidget,
        );
        expect(find.textContaining('likelihood'), findsWidgets);
        expect(find.textContaining('wheeze segment'), findsOneWidget);
        await save(tester);
        expect(flaggedBySave(appState, 'COND_OAD'), isTrue);
        expect(appState.screeningRecords.first.urgency, UrgencyLevel.routine);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('S-G02 airway normal: low band, no case', (tester) async {
      final appState = await pumpIntro(tester, BreathProtocols.airway);
      await throughPrepareAndHowTo(tester, BreathProtocols.airway);
      await openControls(tester, ['Auto-run (simulated)']);
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpSeconds(tester, 200);
      await finishToResult(tester, BreathProtocols.airway);
      expect(find.text('LOW'), findsOneWidget);
      expect(find.text('Low likelihood'), findsOneWidget);
      await save(tester);
      expect(flaggedBySave(appState, 'COND_OAD'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'S-G05 lung function normal: 3 blows, repeatable, ratio ≥ LLN, curve + table',
      (tester) async {
        final appState = await pumpIntro(tester, BreathProtocols.lungFunction);
        await throughPrepareAndHowTo(tester, BreathProtocols.lungFunction);
        expect(appState.activeSubject.heightCm, 170);
        await openControls(tester, ['Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 120);
        await finishToResult(tester, BreathProtocols.lungFunction);
        expect(
          find.byKey(const ValueKey('breath_tile_FEV1_L')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('breath_tile_FEV1_FVC')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('breath_curve')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('breath_effort_table')),
          findsOneWidget,
        );
        expect(find.textContaining('Repeatable'), findsWidgets);
        expect(find.text('Within normal'), findsOneWidget);
        expect(find.textContaining('Best of 3 blows'), findsOneWidget);
        await save(tester);
        expect(flaggedBySave(appState, 'COND_OAD'), isFalse);
        final rec = appState.screeningRecords.first;
        expect(rec.markers.any((m) => m.code == 'fev1_pred_pct'), isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G05 lung function refer: ratio < LLN → routine COND_OAD (T40)',
      (tester) async {
        final appState = await pumpIntro(tester, BreathProtocols.lungFunction);
        await throughPrepareAndHowTo(tester, BreathProtocols.lungFunction);
        await openControls(tester, ['Outcome: Refer', 'Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 150);
        await finishToResult(tester, BreathProtocols.lungFunction);
        expect(find.text('Below the lower limit'), findsOneWidget);
        await save(tester);
        expect(flaggedBySave(appState, 'COND_OAD'), isTrue);
        expect(appState.screeningRecords.first.urgency, UrgencyLevel.routine);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G05 lung function: blows not repeatable → 4th blow (E-AUD-002)',
      (tester) async {
        await pumpIntro(tester, BreathProtocols.lungFunction);
        await throughPrepareAndHowTo(tester, BreathProtocols.lungFunction);
        await openControls(tester, [
          'Simulate unrepeatable blows',
          'Auto-run (simulated)',
        ]);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        final seen = await pumpSeconds(
          tester,
          90,
          untilContaining: 'one more blow is needed',
        );
        expect(seen, isTrue);
        await pumpSeconds(tester, 120);
        await finishToResult(tester, BreathProtocols.lungFunction);
        expect(find.textContaining('Best of 4 blows'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G04 voice normal: "aaa", "sss", "zzz", sentence → seven markers inside the norms, no case',
      (tester) async {
        final appState = await pumpIntro(tester, BreathProtocols.voice);
        final casesBefore = appState.cases.length;
        await throughPrepareAndHowTo(tester, BreathProtocols.voice);
        await openControls(tester, ['Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 200);
        await finishToResult(tester, BreathProtocols.voice);
        for (final code in [
          'JITTER_PCT',
          'SHIMMER_PCT',
          'HNR_DB',
          'MPT_S',
          'SZ_RATIO',
        ]) {
          expect(find.byKey(ValueKey('breath_tile_$code')), findsOneWidget);
        }
        expect(find.text('Within the adult norms'), findsOneWidget);
        expect(find.text('0 / 5'), findsOneWidget);
        await save(tester);
        final rec = appState.screeningRecords.first;
        expect(rec.category, 'Breathing & Voice');
        expect(
          rec.markers.where((m) => m.algorithmId == 'ALG-AUD-06').length,
          7,
        );
        expect(appState.cases.length, casesBefore);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-G04 voice refer: hoarse voice → outside the norms, still no case',
      (tester) async {
        final appState = await pumpIntro(tester, BreathProtocols.voice);
        final casesBefore = appState.cases.length;
        await throughPrepareAndHowTo(tester, BreathProtocols.voice);
        await openControls(tester, ['Outcome: Refer', 'Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 200);
        await finishToResult(tester, BreathProtocols.voice);
        expect(find.textContaining('Outside the norm on'), findsOneWidget);
        await save(tester);
        expect(appState.cases.length, casesBefore);
        expect(appState.screeningRecords.first.urgency, UrgencyLevel.none);
      },
    );
  });
}
