import 'package:algoritam/core/design_system/mirror_theme.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/members/member_screens.dart';
import 'package:algoritam/features/shell/main_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppState family-member management', () {
    test('removeMember keeps the active member and protects Self', () {
      final s = AppState();
      final count = s.subjects.length;
      final selfId = s.subjects.first.id;
      s.selectSubject(2);
      final activeId = s.activeSubject.id;

      expect(s.removeMember(selfId), isFalse);
      expect(s.subjects.length, count);

      expect(s.removeMember(s.subjects[1].id), isTrue);
      expect(s.subjects.length, count - 1);
      expect(s.activeSubject.id, activeId, reason: 'active member kept');

      expect(s.removeMember(activeId), isTrue);
      expect(s.activeSubject.id, selfId, reason: 'falls back to Self');
      expect(s.removeMember('nope'), isFalse);
    });

    test('consentsFor signs every consent and records a guardian', () {
      final s = AppState();
      final c = s.consentsFor(guardian: 'Arjun Rao');
      expect(c.length, ConsentType.values.length);
      expect(c.values.every((r) => r.isSigned), isTrue);
      expect(c.values.first.guardianName, 'Arjun Rao');
    });

    test('buildRelationshipLabel follows the stored style', () {
      expect(
        buildRelationshipLabel('Daughter', ageYears: 7),
        'Daughter (7y Child)',
      );
      expect(
        buildRelationshipLabel('Father', ageYears: 62),
        'Father (62y Senior)',
      );
      expect(
        buildRelationshipLabel('Son', ageYears: 0, newbornHours: 48),
        'Son (Newborn 48h)',
      );
    });
  });

  testWidgets('Add, edit and remove a family member from the shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appState = AppState();
    final startCount = appState.subjects.length;
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

    // 1. Open the account switcher and start "Add member".
    await tester.tap(find.byKey(const ValueKey('member_switcher_pill')));
    await tester.pumpAndSettle();
    expect(find.text('Who is checking in?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('member_switch_add')));
    await tester.pumpAndSettle();
    expect(find.text('Add Member'), findsOneWidget);

    // 2. Saving empty shows validation instead of saving.
    await tester.tap(find.text('Add member').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Choose a relationship'), findsOneWidget);
    expect(appState.subjects.length, startCount);

    // 3. Fill the form and save.
    await tester.enterText(
      find.byKey(const ValueKey('member_name')),
      'Kavya Rao',
    );
    await tester.enterText(find.byKey(const ValueKey('member_age')), '9');
    await tester.tap(find.byKey(const ValueKey('member_relation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daughter').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add member').last);
    await tester.pumpAndSettle();
    expect(appState.subjects.length, startCount + 1);
    expect(appState.activeSubject.fullName, 'Kavya Rao');
    expect(appState.activeSubject.ageYears, 9);
    expect(appState.activeSubject.relationship, 'Daughter (9y Child)');
    expect(
      appState.activeSubject.consents.values.first.guardianName,
      appState.subjects.first.fullName,
      reason: 'minors get a guardian on their consents',
    );
    expect(find.text('Kavya'), findsOneWidget);

    // 4. Open Manage members from the switcher and edit the name.
    await tester.tap(find.byKey(const ValueKey('member_switcher_pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member_switch_manage')));
    await tester.pumpAndSettle();
    expect(find.text('Family Members'), findsOneWidget);
    final newId = appState.activeSubject.id;
    await tester.tap(find.byKey(ValueKey('member_row_$newId')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Member'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('member_name')),
      'Kavya R',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(appState.activeSubject.fullName, 'Kavya R');
    expect(appState.subjects.length, startCount + 1);

    // 5. Self has no Remove option.
    final selfId = appState.subjects.first.id;
    await tester.tap(find.byKey(ValueKey('member_menu_$selfId')));
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 6. Remove the new member with confirmation.
    await tester.tap(find.byKey(ValueKey('member_menu_$newId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Kavya?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('member_remove_confirm')));
    await tester.pumpAndSettle();
    expect(appState.subjects.length, startCount);
    expect(appState.subjects.any((s) => s.id == newId), isFalse);
    expect(appState.activeSubject.id, selfId);
    expect(tester.takeException(), isNull);
  });
}
