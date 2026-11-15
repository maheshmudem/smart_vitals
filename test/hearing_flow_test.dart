// End-to-end guided flows for the hearing screen (S-G10 → S-G11) on the
// simulated route / noise services and the auto listener.
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/hearing_protocol.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/hearing/hearing_intro_screen.dart';
import 'package:algoritam/features/hearing/hearing_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppState> pumpIntro(WidgetTester tester) async {
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
        child: MaterialApp(key: UniqueKey(), home: const HearingIntroScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return appState;
  }

  Future<void> throughPrepareAndHowTo(
    WidgetTester tester,
    HearingProtocol p, {
    bool noisy = false,
  }) async {
    await tester.ensureVisible(find.text('Ready'));
    await tester.tap(find.text('Ready'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Step 1 · Set up'), findsOneWidget);
    for (var i = 0; i < p.prepareChecklist.length; i++) {
      await tester.ensureVisible(find.byKey(ValueKey('hear_check_$i')));
      await tester.tap(find.byKey(ValueKey('hear_check_$i')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Earphones (simulated)'), findsOneWidget);
    // G-18: the 3 s room check must run and pass before Continue.
    expect(find.text('Run the 3-second room check (G-18)'), findsOneWidget);
    // The check button sits at the bottom of the list; call it directly.
    (tester.widget(find.byKey(const ValueKey('hear_noise_check')))
            as FilledButton)
        .onPressed!();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    if (noisy) return;
    expect(find.textContaining('Quiet enough'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Step 2 · How to do the test'), findsOneWidget);
    expect(find.text('Play instructions aloud'), findsOneWidget);
    await tester.tap(find.text('Start test'));
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

  /// Pump in 500 ms steps until the result screen or [until] appears.
  Future<void> pumpSeconds(WidgetTester tester, int s, {String? until}) async {
    for (var i = 0; i < s * 2; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(HearingResultScreen).evaluate().isNotEmpty) return;
      if (until != null && find.text(until).evaluate().isNotEmpty) return;
    }
  }

  Future<void> finishToResult(WidgetTester tester, HearingProtocol p) async {
    for (var i = 0; i < p.analysisStages.length + 3; i++) {
      await tester.pump(const Duration(milliseconds: 450));
    }
    expect(find.byType(HearingResultScreen), findsOneWidget);
    expect(find.text(p.resultTitle), findsOneWidget);
    expect(find.textContaining(p.algorithmId), findsWidgets);
    expect(find.text('Algorithm outputs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  group('Hearing screen (S-G10 → S-G11) guided flows', () {
    testWidgets(
      'pure tone: intro → prepare (G-18/G-19) → test → result → save',
      (tester) async {
        final appState = await pumpIntro(tester);
        final p = HearingProtocols.pureTone;
        expect(find.text(p.title), findsWidgets);
        expect(find.textContaining('ALG-AUD-09'), findsWidgets);
        await throughPrepareAndHowTo(tester, p);
        expect(find.text('Start'), findsOneWidget);
        await openControls(tester, ['Auto-listen (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 120, until: 'Start left ear');
        expect(find.text('Start left ear'), findsOneWidget);
        expect(find.text('Now the left ear'), findsWidgets);
        await tester.tap(find.text('Start left ear'));
        await tester.pump(const Duration(milliseconds: 100));
        await pumpSeconds(tester, 120);
        await finishToResult(tester, p);
        expect(find.byKey(const ValueKey('hear_audiogram')), findsOneWidget);
        expect(find.text('Right ear'), findsWidgets);
        expect(find.text('Left ear'), findsWidgets);
        expect(find.textContaining('within the normal line'), findsWidgets);
        await tester.ensureVisible(find.text('Save to profile'));
        await tester.tap(find.text('Save to profile'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Saved'), findsOneWidget);
        final rec = appState.screeningRecords.first;
        expect(rec.category, 'Hearing');
        expect(rec.title, p.recordTitle);
        expect(rec.screenId, 'S-G11');
        expect(rec.markers.where((m) => m.code.startsWith('HEAR_')).length, 8);
        expect(appState.hearingSessions.first.protocol.id, p.id);
        expect(appState.deviceProfile.lastRoomNoiseDba, closeTo(36, 0.5));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('pure tone refer outcome → COND_HEARING_LOSS case', (
      tester,
    ) async {
      final appState = await pumpIntro(tester);
      await throughPrepareAndHowTo(tester, HearingProtocols.pureTone);
      await openControls(tester, ['Outcome: Refer', 'Auto-listen (simulated)']);
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpSeconds(tester, 120, until: 'Start left ear');
      await tester.tap(find.text('Start left ear'));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpSeconds(tester, 120);
      await finishToResult(tester, HearingProtocols.pureTone);
      expect(
        find.textContaining('hearing loss in the better ear'),
        findsWidgets,
      );
      expect(find.textContaining('Confirm: Hearing loss'), findsOneWidget);
      await tester.ensureVisible(find.text('Save to profile'));
      await tester.tap(find.text('Save to profile'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        appState.cases.any((c) => c.conditionCode == 'COND_HEARING_LOSS'),
        isTrue,
      );
      expect(appState.screeningRecords.first.urgency, UrgencyLevel.routine);
    });

    testWidgets(
      'pause on simulated unplug (E-AUD-004), resume, skip left ear',
      (tester) async {
        await pumpIntro(tester);
        await throughPrepareAndHowTo(tester, HearingProtocols.pureTone);
        await openControls(tester, ['Auto-listen (simulated)']);
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 1500));
        await openControls(tester, ['Simulate unplug']);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Earphones disconnected'), findsOneWidget);
        expect(find.text('Paused — earphones'), findsOneWidget);
        await openControls(tester, ['Simulate unplug']);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Earphones disconnected'), findsNothing);
        // G-18 mid-test: a noisy room pauses after 1 s, quiet resumes.
        await openControls(tester, ['Simulate noisy room']);
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.text('Paused — too noisy'), findsOneWidget);
        expect(find.text('Too noisy'), findsOneWidget);
        await openControls(tester, ['Simulate noisy room']);
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.text('Too noisy'), findsNothing);
        await pumpSeconds(tester, 120, until: 'Start left ear');
        expect(find.text('Skip this ear'), findsOneWidget);
        await tester.tap(find.text('Skip this ear'));
        await tester.pump(const Duration(milliseconds: 300));
        await finishToResult(tester, HearingProtocols.pureTone);
        expect(find.text('Not assessed (skipped)'), findsWidgets);
        expect(find.textContaining('One ear was not assessed'), findsOneWidget);
      },
    );

    testWidgets('digits in noise: keypad flow → DIN_SRT_DB without a band', (
      tester,
    ) async {
      final appState = await pumpIntro(tester);
      await tester.tap(find.byKey(const ValueKey('hear_mode_digitsInNoise')));
      await tester.pump(const Duration(milliseconds: 200));
      final p = HearingProtocols.digitsInNoise;
      expect(find.text(p.title), findsWidgets);
      await throughPrepareAndHowTo(tester, p);
      await openControls(tester, ['Auto-listen (simulated)']);
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpSeconds(tester, 120);
      await finishToResult(tester, p);
      expect(find.textContaining('Speech in noise'), findsWidgets);
      expect(find.textContaining('dB SNR'), findsWidgets);
      await tester.ensureVisible(find.text('Save to profile'));
      await tester.tap(find.text('Save to profile'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(appState.screeningRecords.first.category, 'Hearing');
      expect(appState.screeningRecords.first.title, p.recordTitle);
      expect(
        appState.cases.any((c) => c.conditionCode == 'COND_HEARING_LOSS'),
        isFalse,
      );
    });

    testWidgets('manual taps drive the staircase; manual DIN keypad', (
      tester,
    ) async {
      await pumpIntro(tester);
      await throughPrepareAndHowTo(tester, HearingProtocols.pureTone);
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('hear_tap')), findsOneWidget);
      expect(find.text('RIGHT EAR'), findsOneWidget);
      // Tap "I heard it" on every presentation for a while: the level drops.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 2600));
        await tester.tap(find.byKey(const ValueKey('hear_tap')));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Pitch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
