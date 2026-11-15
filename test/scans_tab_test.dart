import 'package:algoritam/core/design_system/mirror_theme.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/shell/main_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Scans tab groups by category, searches and filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppStateScope(
        notifier: AppState(),
        child: MaterialApp(
          theme: MirrorTheme.light(),
          home: const MainShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scans'));
    await tester.pumpAndSettle();

    // Grouped list starts with the Vitals section.
    expect(find.text('Screenings'), findsOneWidget);
    expect(find.text('Vitals Scan (Face rPPG)'), findsOneWidget);

    // Search narrows the list.
    await tester.enterText(
      find.byKey(const ValueKey('scans_search')),
      'cataract',
    );
    await tester.pumpAndSettle();
    expect(find.text('Cataract Lens Opacity Screen'), findsOneWidget);
    expect(find.text('Vitals Scan (Face rPPG)'), findsNothing);

    // No match shows the empty state.
    await tester.enterText(
      find.byKey(const ValueKey('scans_search')),
      'zzz-nothing',
    );
    await tester.pumpAndSettle();
    expect(find.text('No screenings found'), findsOneWidget);

    // Clear restores the list.
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Vitals Scan (Face rPPG)'), findsOneWidget);

    // "Recently done" shows the seeded vitals session.
    expect(find.text('Recently done'), findsOneWidget);

    // Locked filter lists only scans this member can't take.
    await tester.tap(find.byKey(const ValueKey('scans_filter_Locked')));
    await tester.pumpAndSettle();
    expect(find.text('Locked for now'), findsOneWidget);
    expect(find.text('Vitals Scan (Face rPPG)'), findsNothing);

    // Tapping a locked row opens the preview sheet with Start disabled.
    await tester.tap(find.textContaining('Child Eye Screen').first);
    await tester.pumpAndSettle();
    final start = tester.widget<FilledButton>(
      find.byKey(const ValueKey('scan_preview_start')),
    );
    expect(start.onPressed, isNull);
    expect(find.text('Not available right now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('History explains the trend and filters the timeline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppStateScope(
        notifier: AppState(),
        child: MaterialApp(
          theme: MirrorTheme.light(),
          home: const MainShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Your heart rate is higher than usual'), findsOneWidget);
    expect(find.text('Resting heart rate'), findsOneWidget);
    expect(find.textContaining('vs baseline'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Dental check'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Finger SpO2'), findsOneWidget);
    expect(find.text('Worth keeping an eye on'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('history_kind_Dental')));
    await tester.pumpAndSettle();
    expect(find.text('Dental check'), findsOneWidget);
    expect(find.text('Finger SpO2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('More shows the profile, status and theme choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appState = AppState();
    await tester.pumpWidget(
      AppStateScope(
        notifier: appState,
        child: MaterialApp(
          theme: MirrorTheme.light(),
          home: const MainShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Arjun Rao'), findsOneWidget);
    expect(find.text('178 cm'), findsOneWidget);
    expect(find.text('Consents'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('theme_dark')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('theme_dark')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme_dark')));
    await tester.pumpAndSettle();
    expect(appState.themeMode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });
}
