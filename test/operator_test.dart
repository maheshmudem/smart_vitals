import 'package:algoritam/core/design_system/mirror_theme.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/features/operator/operator_home_screen.dart';
import 'package:algoritam/features/operator/operator_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reading interpretation', () {
    final man = WalkIn(
      id: 'm',
      fullName: 'A',
      sex: WalkInSex.male,
      ageYears: 40,
      createdAt: DateTime(2026),
    );
    ReferenceReading r(
      ReadingKind k,
      Map<String, double> v, [
      GlucoseTiming? g,
    ]) => ReferenceReading(
      id: 'x',
      kind: k,
      values: v,
      recordedAt: DateTime(2026),
      glucoseTiming: g,
    );

    test('blood pressure bands', () {
      expect(
        interpretReading(
          r(ReadingKind.bpCuff, {'sys': 118, 'dia': 76}),
          man,
        ).band,
        SemanticBand.normal,
      );
      expect(
        interpretReading(
          r(ReadingKind.bpCuff, {'sys': 145, 'dia': 92}),
          man,
        ).band,
        SemanticBand.high,
      );
      expect(
        interpretReading(
          r(ReadingKind.bpCuff, {'sys': 185, 'dia': 100}),
          man,
        ).band,
        SemanticBand.critical,
      );
    });

    test('glucose depends on timing', () {
      final fasting = r(ReadingKind.glucose, {
        'glucose': 130,
      }, GlucoseTiming.fasting);
      final random = r(ReadingKind.glucose, {
        'glucose': 130,
      }, GlucoseTiming.random);
      expect(interpretReading(fasting, man).band, SemanticBand.high);
      expect(interpretReading(random, man).band, SemanticBand.normal);
    });

    test('value text', () {
      expect(
        readingValueText(r(ReadingKind.bpCuff, {'sys': 128, 'dia': 84})),
        '128/84 mmHg',
      );
      expect(readingValueText(r(ReadingKind.hba1c, {'a1c': 6.2})), '6.2%');
    });
  });

  testWidgets('Operator flow: create profile, add and delete a reading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = OperatorStore.fresh();
    await tester.pumpWidget(
      MaterialApp(
        theme: MirrorTheme.light(),
        home: OperatorHomeScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mayura Hospitals'), findsOneWidget);
    expect(find.text('Recent walk-ins'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);

    // Create a profile; validation first.
    await tester.tap(find.byKey(const ValueKey('operator_create_profile')));
    await tester.pumpAndSettle();
    expect(find.text('New profile'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the full name'), findsOneWidget);
    expect(find.text('Choose one'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('op_name')),
      'Lakshmi Devi',
    );
    await tester.tap(find.text('Female'));
    await tester.enterText(find.byKey(const ValueKey('op_age')), '45');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('op_phone')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('op_phone')),
      '9876543210',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Lands on reference readings for the new person.
    expect(find.text('Reference readings'), findsOneWidget);
    expect(find.text('Profile created'), findsOneWidget);
    expect(store.walkIns.length, 2);
    final person = store.walkIns.last;
    expect(person.fullName, 'Lakshmi Devi');
    expect(person.ageYears, 45);
    expect(person.sex, WalkInSex.female);

    // Adding without consent is blocked.
    await tester.enterText(
      find.byKey(const ValueKey('reading_field_sys')),
      '146',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reading_field_dia')),
      '94',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('reading_add')));
    await tester.tap(find.byKey(const ValueKey('reading_add')));
    await tester.pumpAndSettle();
    expect(find.text('Ask for agreement before saving.'), findsOneWidget);
    expect(person.readings, isEmpty);

    await tester.tap(find.byKey(const ValueKey('reading_consent')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reading_add')));
    await tester.pumpAndSettle();
    expect(person.readings.length, 1);
    await tester.scrollUntilVisible(
      find.text('146/94 mmHg'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('High blood pressure'), findsOneWidget);
    expect(store.checksToday, 1);

    // Delete it again.
    final id = person.readings.first.id;
    await tester.tap(find.byKey(ValueKey('reading_delete_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reading_delete_confirm')));
    await tester.pumpAndSettle();
    expect(person.readings, isEmpty);
    expect(find.text('No readings yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vitals icon on a walk-in opens reference readings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = OperatorStore.fresh();
    await tester.pumpWidget(
      MaterialApp(
        theme: MirrorTheme.light(),
        home: OperatorHomeScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    final seed = store.walkIns.first;
    await tester.tap(find.byKey(ValueKey('walkin_vitals_${seed.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Reference readings'), findsOneWidget);
    expect(find.text('Add a reading'), findsOneWidget);

    // Switching reading type changes the fields.
    await tester.tap(find.byKey(const ValueKey('reading_kind_glucose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reading_field_glucose')), findsOneWidget);
    expect(find.text('Fasting'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick reading chip opens readings with that type selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = OperatorStore.fresh();
    await tester.pumpWidget(
      MaterialApp(
        theme: MirrorTheme.light(),
        home: OperatorHomeScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('quick_reading_glucose')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick_reading_glucose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick_pick_new')), findsOneWidget);
    final seed = store.walkIns.first;
    await tester.tap(find.byKey(ValueKey('quick_pick_${seed.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Reference readings'), findsOneWidget);
    expect(find.byKey(const ValueKey('reading_field_glucose')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Follow-up filter lists only out-of-range people', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = OperatorStore.fresh();
    final high = store.addWalkIn(
      fullName: 'Hari High',
      sex: WalkInSex.male,
      ageYears: 50,
    );
    store.addReading(high, ReadingKind.bpCuff, {
      'sys': 150,
      'dia': 96,
      'pulse': 80,
    });
    final ok = store.addWalkIn(
      fullName: 'Nina Normal',
      sex: WalkInSex.female,
      ageYears: 30,
    );
    store.addReading(ok, ReadingKind.oximeter, {'spo2': 98, 'pulse': 72});

    await tester.pumpWidget(
      MaterialApp(
        theme: MirrorTheme.light(),
        home: OperatorHomeScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('walkin_filter_row')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('walkin_filter_Follow-up')),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('walkin_filter_row')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('walkin_filter_Follow-up')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('walkin_filter_Follow-up')));
    await tester.pumpAndSettle();
    expect(find.text('Hari High'), findsOneWidget);
    expect(find.text('Nina Normal'), findsNothing);
    expect(find.text('User'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
