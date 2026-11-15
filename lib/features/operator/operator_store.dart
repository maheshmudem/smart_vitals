import 'package:flutter/foundation.dart';

import '../../core/domain/entities/enums.dart';

/// Operator mode (field / clinic staff) — walk-in profiles and the reference
/// readings recorded for them. In-memory for now; one store per app session.

enum WalkInSex { female, male, other }

extension WalkInSexLabel on WalkInSex {
  String get label => switch (this) {
    WalkInSex.female => 'Female',
    WalkInSex.male => 'Male',
    WalkInSex.other => 'Other',
  };
}

class WalkIn {
  WalkIn({
    required this.id,
    required this.fullName,
    required this.sex,
    required this.ageYears,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    this.phone,
    this.language = 'English',
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final WalkInSex sex;
  final int ageYears;
  final DateTime? dateOfBirth;
  final double? heightCm;
  final double? weightKg;
  final String? phone;
  final String language;
  final DateTime createdAt;
  final List<ReferenceReading> readings = [];

  String get summary => '$ageYears years · ${sex.label}';
}

/// The kinds of reference reading an operator can record.
enum ReadingKind { bpCuff, oximeter, haemoglobin, hba1c, glucose }

extension ReadingKindInfo on ReadingKind {
  String get label => switch (this) {
    ReadingKind.bpCuff => 'BP cuff',
    ReadingKind.oximeter => 'Fingertip oximeter',
    ReadingKind.haemoglobin => 'Lab haemoglobin',
    ReadingKind.hba1c => 'Lab HbA1c',
    ReadingKind.glucose => 'Blood glucose',
  };

  String get shortLabel => switch (this) {
    ReadingKind.bpCuff => 'Blood pressure',
    ReadingKind.oximeter => 'Oxygen (SpO2)',
    ReadingKind.haemoglobin => 'Haemoglobin',
    ReadingKind.hba1c => 'HbA1c',
    ReadingKind.glucose => 'Blood glucose',
  };
}

enum GlucoseTiming { fasting, afterMeal, random }

extension GlucoseTimingLabel on GlucoseTiming {
  String get label => switch (this) {
    GlucoseTiming.fasting => 'Fasting',
    GlucoseTiming.afterMeal => '2 h after meal',
    GlucoseTiming.random => 'Random',
  };
}

class ReferenceReading {
  ReferenceReading({
    required this.id,
    required this.kind,
    required this.values,
    required this.recordedAt,
    this.glucoseTiming,
  });

  final String id;
  final ReadingKind kind;

  /// Field key → value (e.g. 'sys', 'dia', 'pulse').
  final Map<String, double> values;
  final DateTime recordedAt;
  final GlucoseTiming? glucoseTiming;
}

/// Plain-language interpretation of a reading.
class ReadingVerdict {
  const ReadingVerdict(this.band, this.text);

  final SemanticBand band;
  final String text;
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Main value shown for a reading, e.g. "128/84 mmHg".
String readingValueText(ReferenceReading r) => switch (r.kind) {
  ReadingKind.bpCuff =>
    '${_fmt(r.values['sys']!)}/${_fmt(r.values['dia']!)} mmHg',
  ReadingKind.oximeter => '${_fmt(r.values['spo2']!)}%',
  ReadingKind.haemoglobin => '${_fmt(r.values['hb']!)} g/dL',
  ReadingKind.hba1c => '${_fmt(r.values['a1c']!)}%',
  ReadingKind.glucose => '${_fmt(r.values['glucose']!)} mg/dL',
};

/// Secondary detail, e.g. pulse or glucose timing.
String? readingDetailText(ReferenceReading r) {
  final pulse = r.values['pulse'];
  return switch (r.kind) {
    ReadingKind.bpCuff ||
    ReadingKind.oximeter => pulse == null ? null : 'Pulse ${_fmt(pulse)} bpm',
    ReadingKind.glucose => r.glucoseTiming?.label,
    _ => null,
  };
}

/// Simple adult reference bands used to explain a reading. Screening aid
/// only — the source of truth is the clinician / lab report.
ReadingVerdict interpretReading(ReferenceReading r, WalkIn person) {
  final v = r.values;
  switch (r.kind) {
    case ReadingKind.bpCuff:
      final sys = v['sys']!, dia = v['dia']!;
      if (sys >= 180 || dia >= 120) {
        return const ReadingVerdict(
          SemanticBand.critical,
          'Very high — needs urgent care',
        );
      }
      if (sys >= 140 || dia >= 90) {
        return const ReadingVerdict(SemanticBand.high, 'High blood pressure');
      }
      if (sys >= 130 || dia >= 80) {
        return const ReadingVerdict(
          SemanticBand.elevated,
          'Slightly high — recheck later',
        );
      }
      if (sys < 90 || dia < 60) {
        return const ReadingVerdict(SemanticBand.borderline, 'On the low side');
      }
      return const ReadingVerdict(SemanticBand.normal, 'Normal range');
    case ReadingKind.oximeter:
      final s = v['spo2']!;
      if (s < 90) {
        return const ReadingVerdict(
          SemanticBand.critical,
          'Low oxygen — needs urgent care',
        );
      }
      if (s < 95) {
        return const ReadingVerdict(SemanticBand.borderline, 'Slightly low');
      }
      return const ReadingVerdict(SemanticBand.normal, 'Normal range');
    case ReadingKind.haemoglobin:
      final hb = v['hb']!;
      final cut = person.sex == WalkInSex.male ? 13.0 : 12.0;
      if (hb < 8) {
        return const ReadingVerdict(SemanticBand.high, 'Severely low — refer');
      }
      if (hb < cut) {
        return const ReadingVerdict(
          SemanticBand.moderate,
          'Below normal — possible anaemia',
        );
      }
      return const ReadingVerdict(SemanticBand.normal, 'Normal range');
    case ReadingKind.hba1c:
      final a = v['a1c']!;
      if (a >= 6.5) {
        return const ReadingVerdict(SemanticBand.high, 'In the diabetes range');
      }
      if (a >= 5.7) {
        return const ReadingVerdict(
          SemanticBand.borderline,
          'Pre-diabetes range',
        );
      }
      return const ReadingVerdict(SemanticBand.normal, 'Normal range');
    case ReadingKind.glucose:
      final g = v['glucose']!;
      final (warn, high) = switch (r.glucoseTiming ?? GlucoseTiming.random) {
        GlucoseTiming.fasting => (100.0, 126.0),
        GlucoseTiming.afterMeal => (140.0, 200.0),
        GlucoseTiming.random => (140.0, 200.0),
      };
      if (g < 70) {
        return const ReadingVerdict(SemanticBand.borderline, 'Low sugar');
      }
      if (g >= high) {
        return const ReadingVerdict(
          SemanticBand.high,
          'High — check for diabetes',
        );
      }
      if (g >= warn) {
        return const ReadingVerdict(SemanticBand.borderline, 'Above normal');
      }
      return const ReadingVerdict(SemanticBand.normal, 'Normal range');
  }
}

class OperatorStore extends ChangeNotifier {
  OperatorStore._() {
    walkIns.add(
      WalkIn(
        id: 'walkin_seed',
        fullName: 'User',
        sex: WalkInSex.male,
        ageYears: 25,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );
  }

  /// Single in-memory store for the app session.
  static final OperatorStore instance = OperatorStore._();

  /// Creates an isolated store (tests).
  @visibleForTesting
  factory OperatorStore.fresh() => OperatorStore._();

  String facilityName = 'Mayura Hospitals';
  String operatorName = 'Operator';

  final List<WalkIn> walkIns = [];
  int _seq = 0;

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  /// Readings saved today across all walk-ins.
  int get checksToday {
    final now = DateTime.now();
    return walkIns
        .expand((w) => w.readings)
        .where(
          (r) =>
              r.recordedAt.year == now.year &&
              r.recordedAt.month == now.month &&
              r.recordedAt.day == now.day,
        )
        .length;
  }

  int get walkInsToday {
    final now = DateTime.now();
    return walkIns
        .where(
          (w) =>
              w.createdAt.year == now.year &&
              w.createdAt.month == now.month &&
              w.createdAt.day == now.day,
        )
        .length;
  }

  List<WalkIn> search(String query) {
    final q = query.trim().toLowerCase();
    final list = [...walkIns]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (q.isEmpty) return list;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return list
        .where(
          (w) =>
              w.fullName.toLowerCase().contains(q) ||
              (digits.isNotEmpty &&
                  (w.phone ?? '')
                      .replaceAll(RegExp(r'\D'), '')
                      .contains(digits)),
        )
        .toList();
  }

  WalkIn addWalkIn({
    required String fullName,
    required WalkInSex sex,
    required int ageYears,
    DateTime? dateOfBirth,
    double? heightCm,
    double? weightKg,
    String? phone,
    String language = 'English',
  }) {
    final w = WalkIn(
      id: _id('walkin'),
      fullName: fullName,
      sex: sex,
      ageYears: ageYears,
      dateOfBirth: dateOfBirth,
      heightCm: heightCm,
      weightKg: weightKg,
      phone: (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      language: language,
      createdAt: DateTime.now(),
    );
    walkIns.add(w);
    notifyListeners();
    return w;
  }

  ReferenceReading addReading(
    WalkIn person,
    ReadingKind kind,
    Map<String, double> values, {
    GlucoseTiming? glucoseTiming,
  }) {
    final r = ReferenceReading(
      id: _id('reading'),
      kind: kind,
      values: values,
      recordedAt: DateTime.now(),
      glucoseTiming: kind == ReadingKind.glucose ? glucoseTiming : null,
    );
    person.readings.insert(0, r);
    notifyListeners();
    return r;
  }

  void deleteReading(WalkIn person, ReferenceReading r) {
    person.readings.remove(r);
    notifyListeners();
  }
}
