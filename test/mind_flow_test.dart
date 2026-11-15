// End-to-end guided flows for the Brain & Mind section (S-G12, S-G13 /
// S-G14, S-G15, S-H06) on the simulated services and the auto-run.
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/mind_protocol.dart';
import 'package:algoritam/core/services/motion_sensor_service.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/mind/crisis_support_screen.dart';
import 'package:algoritam/features/mind/mind_intro_screen.dart';
import 'package:algoritam/features/mind/mind_result_screen.dart';
import 'package:algoritam/features/results_cases/results_cases_screens.dart'
    show EmergencyAlertScreen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppState> pumpIntro(
    WidgetTester tester,
    MindProtocol p, {
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
          home: MindIntroScreen(protocol: p),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return appState;
  }

  Future<void> throughPrepareAndHowTo(
    WidgetTester tester,
    MindProtocol p, {
    bool onset = false,
    bool education = false,
  }) async {
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Step 1 · Set up'), findsOneWidget);
    for (var i = 0; i < p.prepareChecklist.length; i++) {
      await tester.ensureVisible(find.byKey(ValueKey('mind_check_$i')));
      await tester.tap(find.byKey(ValueKey('mind_check_$i')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));
    if (education) {
      await tester.enterText(
        find.byKey(const ValueKey('mind_education')),
        '10',
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (onset) {
      // the chip row sits under the app bar after scrolling; select directly
      (tester.widget(find.byKey(const ValueKey('mind_onset_0'))) as ChoiceChip)
          .onSelected!(true);
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (p.requiredGates.contains(GateId.g18)) {
      expect(find.byKey(const ValueKey('mind_noise_check')), findsOneWidget);
      (tester.widget(find.byKey(const ValueKey('mind_noise_check')))
              as FilledButton)
          .onPressed!();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.textContaining('Quiet enough'), findsOneWidget);
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

  /// Pump in 500 ms steps until the result / emergency / crisis screen or
  /// [until] appears.
  Future<void> pumpSeconds(WidgetTester tester, int s, {String? until}) async {
    for (var i = 0; i < s * 2; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(MindResultScreen).evaluate().isNotEmpty) return;
      if (find.byType(EmergencyAlertScreen).evaluate().isNotEmpty) return;
      if (find.byType(CrisisSupportScreen).evaluate().isNotEmpty) return;
      if (until != null && find.text(until).evaluate().isNotEmpty) return;
    }
  }

  Future<void> finishToResult(WidgetTester tester, MindProtocol p) async {
    for (var i = 0; i < p.analysisStages.length + 3; i++) {
      await tester.pump(const Duration(milliseconds: 450));
    }
    expect(find.byType(MindResultScreen), findsOneWidget);
    expect(find.text(p.resultTitle), findsOneWidget);
    expect(find.text('Algorithm outputs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  group('Brain & Mind guided flows', () {
    testWidgets(
      'S-G12 cognitive: education + language → two speech tasks → values, no band',
      (tester) async {
        final appState = await pumpIntro(tester, MindProtocols.cognitive);
        expect(find.textContaining('ALG-AUD-10'), findsWidgets);
        await throughPrepareAndHowTo(
          tester,
          MindProtocols.cognitive,
          education: true,
        );
        expect(appState.activeSubject.educationYears, 10);
        await openControls(tester, ['Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 160);
        await finishToResult(tester, MindProtocols.cognitive);
        expect(
          find.byKey(const ValueKey('mind_tile_FLUENCY_COUNT')),
          findsOneWidget,
        );
        expect(find.text('18'), findsWidgets);
        expect(find.text('Age/education norms pending'), findsOneWidget);
        await tester.ensureVisible(find.text('Save to profile'));
        await tester.tap(find.text('Save to profile'));
        await tester.pump(const Duration(milliseconds: 300));
        final rec = appState.screeningRecords.first;
        expect(rec.category, 'Brain & Mind');
        expect(rec.title, MindProtocols.cognitive.recordTitle);
        expect(
          appState.cases.any((c) => c.conditionCode == 'COND_COG'),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'room-noise calibration marks a quiet room as 35 dBA (CAP-12)',
      (tester) async {
        await pumpIntro(tester, MindProtocols.cognitive);
        await tester.ensureVisible(find.byType(FilledButton).last);
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.drag(find.byType(ListView), const Offset(0, -900));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Reads too high? Calibrate here'), findsOneWidget);
        (tester.widget(find.byKey(const ValueKey('mind_noise_calibrate')))
                as OutlinedButton)
            .onPressed!();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.textContaining('Quiet enough: 35 dBA'), findsOneWidget);
        expect(find.textContaining('offset'), findsOneWidget);
      },
    );

    testWidgets(
      'S-G13 mood normal: 16 questions + 60 s speech → gauges, no case',
      (tester) async {
        final appState = await pumpIntro(tester, MindProtocols.mood);
        await throughPrepareAndHowTo(tester, MindProtocols.mood);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 300));
        // answer the first question by hand, then let auto-run finish
        expect(find.byKey(const ValueKey('mind_q_phq9_1')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('mind_answer_1')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const ValueKey('mind_q_phq9_2')), findsOneWidget);
        await openControls(tester, ['Auto-run (simulated)']);
        await pumpSeconds(tester, 120);
        await finishToResult(tester, MindProtocols.mood);
        expect(find.text('PHQ-9'), findsWidgets);
        expect(find.text('GAD-7'), findsWidgets);
        expect(find.byType(CrisisSupportScreen), findsNothing);
        await tester.ensureVisible(find.text('Save to profile'));
        await tester.tap(find.text('Save to profile'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          appState.cases.any((c) => c.conditionCode == 'COND_MOOD'),
          isFalse,
        );
      },
    );

    testWidgets(
      'S-G13 crisis: item 9 > 0 → S-G14 immediately, back blocked, acknowledged → emergency case',
      (tester) async {
        final appState = await pumpIntro(tester, MindProtocols.mood);
        await throughPrepareAndHowTo(tester, MindProtocols.mood);
        await openControls(tester, ['Outcome: Crisis', 'Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 30);
        expect(find.byType(CrisisSupportScreen), findsOneWidget);
        expect(find.text("You're not alone"), findsOneWidget);
        // back does not dismiss it
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        expect(await nav.maybePop(), isTrue); // handled by PopScope → stays
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CrisisSupportScreen), findsOneWidget);
        // continue is disabled until "I'm safe right now"
        expect(
          (tester.widget(find.byKey(const ValueKey('mind_crisis_continue')))
                  as FilledButton)
              .onPressed,
          isNull,
        );
        await tester.ensureVisible(find.byKey(const ValueKey('mind_safe_now')));
        await tester.tap(find.byKey(const ValueKey('mind_safe_now')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.ensureVisible(
          find.byKey(const ValueKey('mind_crisis_continue')),
        );
        await tester.tap(find.byKey(const ValueKey('mind_crisis_continue')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(CrisisSupportScreen), findsNothing);
        await pumpSeconds(tester, 120);
        await finishToResult(tester, MindProtocols.mood);
        expect(find.textContaining('question 9'), findsWidgets);
        expect(
          find.textContaining('clinician has been notified'),
          findsWidgets,
        );
        await tester.ensureVisible(find.text('Save to profile'));
        await tester.tap(find.text('Save to profile'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          appState.cases.any((c) => c.conditionCode == 'COND_MOOD'),
          isTrue,
        );
        expect(appState.screeningRecords.first.urgency, UrgencyLevel.emergency);
        expect(appState.screeningRecords.first.screenId, 'S-R02');
      },
    );

    testWidgets(
      'S-G15 HF: baseline complete → deviation shown; building when < 14 days',
      (tester) async {
        final appState = await pumpIntro(tester, MindProtocols.hfVoice);
        expect(find.textContaining('Baseline complete'), findsOneWidget);
        await throughPrepareAndHowTo(tester, MindProtocols.hfVoice);
        await openControls(tester, ['Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 60);
        await finishToResult(tester, MindProtocols.hfVoice);
        expect(
          find.byKey(const ValueKey('mind_hf_trend')),
          findsOneWidget,
        ); // today's deviation is the first trend point
        expect(find.textContaining('SD'), findsWidgets);
        await tester.ensureVisible(find.text('Save to profile'));
        await tester.tap(find.text('Save to profile'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(appState.hfCheckDoneToday('subj_senior_62'), isTrue);
        expect(appState.hfSamplesFor('subj_senior_62').length, 15);

        // a subject still building the baseline
        final other = appState.subjects.firstWhere(
          (x) => x.id == 'subj_senior_62',
        );
        appState.updateActiveSubject(
          other.copyWith(hfBaselineDaysCompleted: 5),
        );
        appState.hfVoiceBaselines.remove('subj_senior_62');
        await tester.pumpWidget(
          AppStateScope(
            notifier: appState,
            child: MaterialApp(
              key: UniqueKey(),
              home: const MindIntroScreen(protocol: MindProtocols.hfVoice),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Day 6 of 14'), findsOneWidget);
      },
    );

    testWidgets(
      'S-H06 stroke negative: face, both arms, sentence → Negative result',
      (tester) async {
        final appState = await pumpIntro(tester, MindProtocols.stroke);
        expect(find.byKey(const ValueKey('mind_intro_call')), findsOneWidget);
        await throughPrepareAndHowTo(tester, MindProtocols.stroke, onset: true);
        await openControls(tester, ['Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 90);
        await finishToResult(tester, MindProtocols.stroke);
        expect(find.byType(EmergencyAlertScreen), findsNothing);
        expect(
          find.text('No warning sign in the three checks'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Save to profile'));
        await tester.tap(find.text('Save to profile'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          appState.cases.any((c) => c.conditionCode == 'COND_STROKE'),
          isFalse,
        );
      },
    );

    testWidgets(
      'S-H06 stroke positive: emergency screen first (BR-SCR-01), then result with signs',
      (tester) async {
        final appState = await pumpIntro(tester, MindProtocols.stroke);
        await throughPrepareAndHowTo(tester, MindProtocols.stroke, onset: true);
        await openControls(tester, ['Outcome: Refer', 'Auto-run (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 90);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 450));
          if (find.byType(EmergencyAlertScreen).evaluate().isNotEmpty) break;
        }
        expect(find.byType(EmergencyAlertScreen), findsOneWidget);
        expect(find.textContaining('BR-SCR-01'), findsWidgets);
        // the first positive sign (face) stopped the check: the session is
        // already saved and the case opened before the member acts
        expect(
          appState.cases.any((c) => c.conditionCode == 'COND_STROKE'),
          isTrue,
        );
        expect(appState.screeningRecords.first.urgency, UrgencyLevel.emergency);
        expect(
          find.textContaining('stopped at the first sign'),
          findsOneWidget,
        );
        // real dial buttons; back is locked until acknowledged (G-37)
        expect(
          find.byKey(const ValueKey('emergency_call_108')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('emergency_call_112')),
          findsOneWidget,
        );
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        expect(await nav.maybePop(), isTrue);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(EmergencyAlertScreen), findsOneWidget);
        // acknowledge → result
        await tester.ensureVisible(
          find.byKey(const ValueKey('emergency_acknowledge')),
        );
        await tester.tap(find.byKey(const ValueKey('emergency_acknowledge')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(MindResultScreen), findsOneWidget);
        expect(find.text('Call emergency services now'), findsOneWidget);
        expect(find.textContaining('Warning sign'), findsWidgets);
        expect(find.textContaining('Started:'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('mind_partial_banner')),
          findsOneWidget,
        );
        expect(find.text('Saved'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-H06 stroke: no speech recognition → helper judges the sentence',
      (tester) async {
        await pumpIntro(tester, MindProtocols.stroke);
        await throughPrepareAndHowTo(tester, MindProtocols.stroke, onset: true);
        await openControls(tester, [
          'Simulate no speech recognition',
          'Auto-run (simulated)',
        ]);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 120);
        await finishToResult(tester, MindProtocols.stroke);
        expect(find.textContaining('helper judged'), findsWidgets);
        expect(find.textContaining('Helper: Clear'), findsOneWidget);
        expect(find.byType(EmergencyAlertScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-H06 stroke: no motion sensor → arm steps not assessed, partial copy',
      (tester) async {
        final appState = await pumpIntro(tester, MindProtocols.stroke);
        await throughPrepareAndHowTo(tester, MindProtocols.stroke, onset: true);
        await openControls(tester, [
          'Simulate no motion sensor',
          'Auto-run (simulated)',
        ]);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 120);
        await finishToResult(tester, MindProtocols.stroke);
        expect(find.textContaining('not a full check'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('mind_partial_banner')),
          findsOneWidget,
        );
        expect(find.textContaining('Motion sensor unavailable'), findsWidgets);
        await tester.ensureVisible(find.text('Save to profile'));
        await tester.tap(find.text('Save to profile'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          appState.cases.any((c) => c.conditionCode == 'COND_STROKE'),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-H06 stroke: step by step by hand — late sensor start still reaches Speech',
      (tester) async {
        // The real accelerometer often delivers its first sample 1–3 s after
        // listen(); the arm step must still produce a reading, not a retry.
        final motion = MotionSensorService.instance;
        addTearDown(() => motion.simulatedStartDelay = Duration.zero);
        await pumpIntro(tester, MindProtocols.stroke);
        await throughPrepareAndHowTo(tester, MindProtocols.stroke, onset: true);
        // face (simulated sensor in tests)
        await tester.tap(find.byType(FilledButton).first);
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 20, until: 'Next: Right arm');
        expect(find.text('Next: Right arm'), findsWidgets);
        // right arm: stream comes up 2.5 s late
        motion.simulatedStartDelay = const Duration(milliseconds: 2500);
        await tester.tap(find.byType(FilledButton).first);
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 25, until: 'Next: Left arm');
        expect(find.text('Next: Left arm'), findsWidgets);
        expect(find.text("Let's try that again"), findsNothing);
        // left arm: stream comes up 4 s late (baseline window missed)
        motion.simulatedStartDelay = const Duration(milliseconds: 4000);
        await tester.tap(find.byType(FilledButton).first);
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 25, until: 'Next: Speech');
        expect(find.text('Next: Speech'), findsWidgets);
        expect(find.text("Let's try that again"), findsNothing);
        // speech runs to the result
        await tester.tap(find.byType(FilledButton).first);
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 30);
        await finishToResult(tester, MindProtocols.stroke);
        expect(find.textContaining('Held steady'), findsNWidgets(2));
        expect(find.textContaining('not a full check'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'S-H06 stroke: helper "could not speak" is a sign → emergency',
      (tester) async {
        final appState = await pumpIntro(tester, MindProtocols.stroke);
        await throughPrepareAndHowTo(tester, MindProtocols.stroke, onset: true);
        await openControls(tester, ['Simulate no speech recognition']);
        // skip face and both arms by hand, then judge the speech
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        for (var i = 0; i < 3; i++) {
          await pumpSeconds(tester, 4, until: 'Skip this step');
          await tester.tap(find.byKey(const ValueKey('mind_skip')));
          await tester.pump(const Duration(milliseconds: 300));
          if (i < 2) {
            await tester.tap(find.byType(FilledButton).first);
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        // speech task: start → helper card
        await tester.tap(find.byType(FilledButton).first);
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 20, until: 'What did you hear?');
        expect(find.byKey(const ValueKey('mind_helper_title')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('mind_speech_judge_2')));
        await tester.pump(const Duration(milliseconds: 100));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 450));
          if (find.byType(EmergencyAlertScreen).evaluate().isNotEmpty) break;
        }
        expect(find.byType(EmergencyAlertScreen), findsOneWidget);
        expect(appState.screeningRecords.first.urgency, UrgencyLevel.emergency);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
