import 'package:algoritam/core/design_system/mirror_theme.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/shell/main_shell_screen.dart';
import 'package:algoritam/features/trends/trends_data.dart';
import 'package:algoritam/features/trends/trends_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 13, 16, 0);

  test('Mock data is deterministic and covers both checks', () {
    final a = TrendsMockData.forMember('subject_1', now: now);
    final b = TrendsMockData.forMember('subject_1', now: now);
    expect(a.scans.length, b.scans.length);
    expect(a.scans.first.values, b.scans.first.values);
    expect(a.scans.where((s) => s.check == TrendCheck.eye), isNotEmpty);
    for (final c in TrendCheck.values) {
      expect(a.scans.where((s) => s.check == c), isNotEmpty, reason: c.name);
      expect(metricsFor(c), isNotEmpty, reason: c.name);
    }
    expect(
      metricsFor(TrendCheck.face).map((m) => m.label),
      containsAll([
        'Readiness',
        'Heart rate',
        'Breathing',
        'HRV',
        'Stress index',
        'Perfusion',
      ]),
    );
    expect(a.scans.every((s) => !s.at.isAfter(now)), isTrue);

    final hr = kTrendMetrics.firstWhere((m) => m.key == 'hr');
    final week = a.series(hr, TrendRange.week, now);
    expect(week.length, inInclusiveRange(4, 7));
    for (var i = 1; i < week.length; i++) {
      expect(week[i].at.isAfter(week[i - 1].at), isTrue);
    }
    expect(a.series(hr, TrendRange.today, now), isNotEmpty);
  });

  Future<void> pumpTrends(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppStateScope(
        notifier: AppState(),
        child: MaterialApp(
          theme: MirrorTheme.light(),
          home: TrendsScreen(now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Trends switches metric, range and check', (tester) async {
    await pumpTrends(tester);
    expect(find.text('Trends'), findsOneWidget);
    expect(find.text('Readiness'), findsWidgets);
    expect(find.byKey(const ValueKey('trends_chart')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trends_metric_hr')));
    await tester.pumpAndSettle();
    expect(find.text('bpm'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('trends_chart')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trends_range_quarter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trends_range_today')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('trends_check_eye')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trends_metric_comfort')), findsOneWidget);
    expect(find.byKey(const ValueKey('trends_metric_hr')), findsNothing);

    // A check far along the row (needs a scroll) shows its own measures.
    final voice = find.byKey(const ValueKey('trends_check_voice'));
    await tester.scrollUntilVisible(
      voice,
      150,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('trends_check_row')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(voice);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('trends_metric_voice_clarity')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Records expand with Show all', (tester) async {
    await pumpTrends(tester);
    await tester.tap(find.byKey(const ValueKey('trends_range_month')));
    await tester.pumpAndSettle();
    final showAll = find.byKey(const ValueKey('trends_show_all'));
    await tester.scrollUntilVisible(
      showAll,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Show all'), findsOneWidget);
    await tester.ensureVisible(showAll);
    await tester.pumpAndSettle();
    await tester.tap(showAll);
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('More > Trends opens the Trends screen', (tester) async {
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
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('more_trends'));
    await tester.scrollUntilVisible(row, 200);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(TrendsScreen), findsOneWidget);

    // New scan returns to the Scans tab.
    await tester.tap(find.byKey(const ValueKey('trends_new_scan')));
    await tester.pumpAndSettle();
    expect(find.byType(TrendsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
