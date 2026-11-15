// Renders non-scanning screens to PNG for visual review.
//
// Run with:
//   flutter test test/ui_preview_test.dart --dart-define=UI_PREVIEW=true
// Output: build/ui_previews/*.png
//
// Skipped during normal `flutter test` runs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:algoritam/core/design_system/mirror_theme.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/health_package.dart';
import 'package:algoritam/core/domain/entities/marker_envelope.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/access_profile_settings/access_profile_settings_screens.dart';
import 'package:algoritam/features/anaemia/anaemia_intro_screen.dart';
import 'package:algoritam/features/dental/dental_screens.dart';
import 'package:algoritam/features/results_cases/results_cases_screens.dart';
import 'package:algoritam/features/members/member_screens.dart';
import 'package:algoritam/features/shell/main_shell_screen.dart';

const _enabled = bool.fromEnvironment('UI_PREVIEW');

Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? r'D:\flutter';
  final dir = '$sdk/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String name) async =>
      ByteData.view(File('$dir/$name').readAsBytesSync().buffer);

  final roboto = FontLoader('Roboto')
    ..addFont(f('roboto-regular.ttf'))
    ..addFont(f('roboto-medium.ttf'))
    ..addFont(f('roboto-bold.ttf'))
    ..addFont(f('roboto-black.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(f('materialicons-regular.otf'));
  await icons.load();
}

void main() {
  const size = Size(390, 1500);
  final outDir = Directory('build/ui_previews');

  setUpAll(() async {
    if (!_enabled) return;
    await _loadFonts();
    outDir.createSync(recursive: true);
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget screen, {
    bool dark = false,
    Future<void> Function(WidgetTester)? before,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    final appState = AppState();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: AppStateScope(
          notifier: appState,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: MirrorTheme.light(),
            darkTheme: MirrorTheme.dark(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: screen,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    if (before != null) await before(tester);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${outDir.path}/$name${dark ? '_dark' : ''}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> Function(WidgetTester) tab(String label) => (tester) async {
    await tester.tap(find.text(label));
    await tester.pump(const Duration(milliseconds: 400));
  };

  final screens = <String, (Widget, Future<void> Function(WidgetTester)?)>{
    '01_home': (const MainShellScreen(), null),
    '02_packs': (const MainShellScreen(), tab('Packs')),
    '03_scans': (const MainShellScreen(), tab('Scans')),
    '04_history': (const MainShellScreen(), tab('History')),
    '05_more': (const MainShellScreen(), tab('More')),
    '06_package_detail': (
      PackageDetailAndRunnerScreen(
        package: HealthPackagesRegistry.packages.first,
      ),
      null,
    ),
    '07_consent': (const ConsentCenterScreen(), null),
    '08_profile': (const ProfileAndHealthContextScreen(), null),
    '09_devices': (const DeviceReadinessAndHardwareScreen(), null),
    '10_cases': (const CasesListScreen(), null),
    '11_anaemia_intro': (const AnaemiaIntroScreen(), null),
    '12_shared_result': (
      SharedScreeningResultScreen(
        record: ScreeningSessionRecord(
          sessionId: 'preview',
          subjectId: 'self',
          featureId: 'F-00',
          screenId: 'S-R01',
          title: 'Oral lesion check',
          category: 'Skin & Body',
          recordedAt: DateTime(2026),
          primaryBand: SemanticBand.high,
          urgency: UrgencyLevel.routine,
          confidence: 0.82,
          summaryText:
              'A white patch was seen on the left cheek lining. See a dentist within 2 weeks.',
          markers: const [],
          isUnderSpecialistReview: true,
        ),
      ),
      null,
    ),
    '14_dental': (
      DentalResultsScreen(exam: AppState().dentalExams.first),
      null,
    ),
    '15_members': (const ManageMembersScreen(), null),
    '16_member_form': (const MemberFormScreen(), null),
    '17_member_edit': (MemberFormScreen(member: AppState().subjects[1]), null),
    '18_switcher': (
      const MainShellScreen(),
      (WidgetTester tester) async {
        await tester.tap(find.byKey(const ValueKey('member_switcher_pill')));
        await tester.pumpAndSettle();
      },
    ),
    '19_scans_eyes': (
      const MainShellScreen(),
      (WidgetTester tester) async {
        await tester.tap(find.text('Scans'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('area_Eyes')));
        await tester.pumpAndSettle();
      },
    ),
    '20_scan_preview': (
      const MainShellScreen(),
      (WidgetTester tester) async {
        await tester.tap(find.text('Scans'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Anaemia Screen (Lower Eyelid)').first);
        await tester.pumpAndSettle();
      },
    ),
    '13_case_detail': (
      CaseDetailScreen(caseRecord: AppState().cases.first),
      null,
    ),
  };

  for (final dark in [false, true]) {
    for (final e in screens.entries) {
      testWidgets('preview ${e.key}${dark ? ' dark' : ''}', skip: !_enabled, (
        tester,
      ) async {
        await capture(
          tester,
          e.key,
          e.value.$1,
          dark: dark,
          before: e.value.$2,
        );
      });
    }
  }
}
