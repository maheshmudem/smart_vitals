import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which scan a trend comes from.
enum TrendCheck {
  face('Face check', 'Face', Icons.face_retouching_natural_rounded, 1),
  eye('Eye check', 'Eye', Icons.visibility_outlined, 3),
  fingertip('Fingertip', 'Fingertip', Icons.fingerprint_rounded, 2),
  tapping('Finger tapping', 'Tapping', Icons.touch_app_outlined, 3),
  reaction('Reaction time', 'Reaction', Icons.bolt_outlined, 3),
  walk('Walk speed', 'Walk', Icons.directions_walk_rounded, 4),
  chair('Chair stands', 'Chair', Icons.event_seat_outlined, 5),
  hands('Steady hands', 'Steady hands', Icons.back_hand_outlined, 4),
  nearVision(
    'Vision at reading distance',
    'Reading vision',
    Icons.menu_book_outlined,
    7,
  ),
  voice('Voice check', 'Voice', Icons.mic_none_rounded, 3);

  const TrendCheck(this.label, this.short, this.icon, this.everyDays);

  /// Full name (records, empty states).
  final String label;

  /// Tile label in the check picker.
  final String short;
  final IconData icon;

  /// How often the demo data has a scan of this kind.
  final int everyDays;
}

/// Time window shown on the chart.
enum TrendRange {
  today('Today', 1),
  week('7 days', 7),
  month('30 days', 30),
  quarter('90 days', 90);

  const TrendRange(this.label, this.days);
  final String label;
  final int days;
}

/// One measurable value that can be trended.
class TrendMetric {
  const TrendMetric({
    required this.key,
    required this.label,
    required this.short,
    required this.unit,
    required this.icon,
    required this.color,
    required this.check,
    required this.base,
    required this.amp,
    required this.lo,
    required this.hi,
    this.drift = 0,
    this.decimals = 0,
    this.higherIsBetter,
  });

  final String key;
  final String label;
  final String short;
  final String unit;
  final IconData icon;
  final Color color;
  final TrendCheck check;
  final int decimals;

  /// `true`/`false` colours the change chip; `null` keeps it neutral.
  final bool? higherIsBetter;

  // Demo-data shape: baseline, wave size, change over 90 days, clamp.
  final double base;
  final double amp;
  final double drift;
  final double lo;
  final double hi;

  String format(double v) => v.toStringAsFixed(decimals);
}

const _teal = Color(0xFF0B7A75);
const _rose = Color(0xFFE11D48);
const _sky = Color(0xFF0284C7);
const _violet = Color(0xFF7C3AED);
const _amber = Color(0xFFD97706);
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _indigo = Color(0xFF4C5BD4);

const kTrendMetrics = <TrendMetric>[
  // Face check
  TrendMetric(
    key: 'readiness',
    label: 'Readiness',
    short: 'Ready',
    unit: '/100',
    icon: Icons.bolt_rounded,
    color: _teal,
    check: TrendCheck.face,
    higherIsBetter: true,
    base: 66,
    amp: 6,
    drift: 8,
    lo: 30,
    hi: 98,
  ),
  TrendMetric(
    key: 'hr',
    label: 'Heart rate',
    short: 'HR',
    unit: 'bpm',
    icon: Icons.favorite_rounded,
    color: _rose,
    check: TrendCheck.face,
    base: 72,
    amp: 4,
    drift: -3,
    lo: 50,
    hi: 110,
  ),
  TrendMetric(
    key: 'br',
    label: 'Breathing',
    short: 'BR',
    unit: 'br/min',
    icon: Icons.air_rounded,
    color: _sky,
    check: TrendCheck.face,
    decimals: 1,
    base: 15,
    amp: 1,
    lo: 9,
    hi: 22,
  ),
  TrendMetric(
    key: 'hrv',
    label: 'HRV',
    short: 'HRV',
    unit: 'ms',
    icon: Icons.monitor_heart_outlined,
    color: _violet,
    check: TrendCheck.face,
    higherIsBetter: true,
    base: 46,
    amp: 5,
    drift: 5,
    lo: 15,
    hi: 110,
  ),
  TrendMetric(
    key: 'stress',
    label: 'Stress index',
    short: 'Stress',
    unit: '',
    icon: Icons.psychology_alt_outlined,
    color: _amber,
    check: TrendCheck.face,
    higherIsBetter: false,
    base: 120,
    amp: 18,
    drift: -15,
    lo: 40,
    hi: 400,
  ),
  TrendMetric(
    key: 'perfusion',
    label: 'Perfusion',
    short: 'PI',
    unit: '%',
    icon: Icons.water_drop_outlined,
    color: _red,
    check: TrendCheck.face,
    decimals: 1,
    higherIsBetter: true,
    base: 2.4,
    amp: 0.4,
    lo: 0.3,
    hi: 8,
  ),

  // Eye check
  TrendMetric(
    key: 'comfort',
    label: 'Eye comfort',
    short: 'Comfort',
    unit: '/100',
    icon: Icons.spa_outlined,
    color: _green,
    check: TrendCheck.eye,
    higherIsBetter: true,
    base: 74,
    amp: 6,
    drift: 4,
    lo: 30,
    hi: 99,
  ),
  TrendMetric(
    key: 'redness',
    label: 'Redness',
    short: 'Red',
    unit: '%',
    icon: Icons.opacity_rounded,
    color: _red,
    check: TrendCheck.eye,
    higherIsBetter: false,
    base: 20,
    amp: 5,
    drift: -4,
    lo: 3,
    hi: 60,
  ),
  TrendMetric(
    key: 'blink',
    label: 'Blink rate',
    short: 'Blink',
    unit: '/min',
    icon: Icons.remove_red_eye_outlined,
    color: _amber,
    check: TrendCheck.eye,
    base: 15,
    amp: 2,
    lo: 5,
    hi: 30,
  ),

  // Fingertip
  TrendMetric(
    key: 'tip_hr',
    label: 'Heart rate',
    short: 'HR',
    unit: 'bpm',
    icon: Icons.favorite_rounded,
    color: _rose,
    check: TrendCheck.fingertip,
    base: 71,
    amp: 4,
    drift: -2,
    lo: 50,
    hi: 110,
  ),
  TrendMetric(
    key: 'tip_hrv',
    label: 'HRV',
    short: 'HRV',
    unit: 'ms',
    icon: Icons.monitor_heart_outlined,
    color: _violet,
    check: TrendCheck.fingertip,
    higherIsBetter: true,
    base: 48,
    amp: 5,
    drift: 4,
    lo: 15,
    hi: 110,
  ),
  TrendMetric(
    key: 'tip_pi',
    label: 'Perfusion',
    short: 'PI',
    unit: '%',
    icon: Icons.water_drop_outlined,
    color: _red,
    check: TrendCheck.fingertip,
    decimals: 1,
    higherIsBetter: true,
    base: 3.1,
    amp: 0.5,
    lo: 0.3,
    hi: 10,
  ),

  // Finger tapping
  TrendMetric(
    key: 'taps',
    label: 'Tapping speed',
    short: 'Taps',
    unit: 'taps/10s',
    icon: Icons.speed_rounded,
    color: _indigo,
    check: TrendCheck.tapping,
    higherIsBetter: true,
    base: 52,
    amp: 4,
    drift: 3,
    lo: 20,
    hi: 80,
  ),
  TrendMetric(
    key: 'rhythm',
    label: 'Rhythm',
    short: 'Rhythm',
    unit: '%',
    icon: Icons.graphic_eq_rounded,
    color: _teal,
    check: TrendCheck.tapping,
    higherIsBetter: true,
    base: 86,
    amp: 4,
    drift: 2,
    lo: 40,
    hi: 99,
  ),

  // Reaction time
  TrendMetric(
    key: 'react_ms',
    label: 'Reaction time',
    short: 'Avg',
    unit: 'ms',
    icon: Icons.timer_outlined,
    color: _amber,
    check: TrendCheck.reaction,
    higherIsBetter: false,
    base: 285,
    amp: 18,
    drift: -12,
    lo: 160,
    hi: 600,
  ),
  TrendMetric(
    key: 'react_var',
    label: 'Consistency',
    short: 'Spread',
    unit: 'ms',
    icon: Icons.stacked_line_chart_rounded,
    color: _sky,
    check: TrendCheck.reaction,
    higherIsBetter: false,
    base: 42,
    amp: 6,
    drift: -4,
    lo: 10,
    hi: 150,
  ),

  // Walk speed
  TrendMetric(
    key: 'gait_speed',
    label: 'Walk speed',
    short: 'Speed',
    unit: 'm/s',
    icon: Icons.directions_walk_rounded,
    color: _green,
    check: TrendCheck.walk,
    decimals: 2,
    higherIsBetter: true,
    base: 1.22,
    amp: 0.06,
    drift: 0.04,
    lo: 0.4,
    hi: 2,
  ),
  TrendMetric(
    key: 'cadence',
    label: 'Cadence',
    short: 'Cadence',
    unit: 'steps/min',
    icon: Icons.directions_run_rounded,
    color: _indigo,
    check: TrendCheck.walk,
    base: 108,
    amp: 4,
    drift: 2,
    lo: 70,
    hi: 140,
  ),

  // Chair stands
  TrendMetric(
    key: 'stands',
    label: 'Stands in 30 s',
    short: 'Stands',
    unit: 'reps',
    icon: Icons.repeat_rounded,
    color: _teal,
    check: TrendCheck.chair,
    higherIsBetter: true,
    base: 14,
    amp: 1.5,
    drift: 2,
    lo: 4,
    hi: 30,
  ),
  TrendMetric(
    key: 'five_stand',
    label: '5 stands time',
    short: '5x time',
    unit: 's',
    icon: Icons.timer_outlined,
    color: _amber,
    check: TrendCheck.chair,
    decimals: 1,
    higherIsBetter: false,
    base: 11.2,
    amp: 0.8,
    drift: -1,
    lo: 5,
    hi: 30,
  ),

  // Steady hands
  TrendMetric(
    key: 'steadiness',
    label: 'Steadiness',
    short: 'Steady',
    unit: '/100',
    icon: Icons.back_hand_outlined,
    color: _sky,
    check: TrendCheck.hands,
    higherIsBetter: true,
    base: 82,
    amp: 4,
    drift: 3,
    lo: 30,
    hi: 99,
  ),
  TrendMetric(
    key: 'sway',
    label: 'Hand sway',
    short: 'Sway',
    unit: 'mm',
    icon: Icons.waves_rounded,
    color: _violet,
    check: TrendCheck.hands,
    decimals: 1,
    higherIsBetter: false,
    base: 2.6,
    amp: 0.4,
    drift: -0.3,
    lo: 0.5,
    hi: 10,
  ),

  // Vision at reading distance
  TrendMetric(
    key: 'reading_score',
    label: 'Reading score',
    short: 'Score',
    unit: '/100',
    icon: Icons.menu_book_outlined,
    color: _indigo,
    check: TrendCheck.nearVision,
    higherIsBetter: true,
    base: 84,
    amp: 3,
    lo: 30,
    hi: 100,
  ),
  TrendMetric(
    key: 'contrast',
    label: 'Contrast',
    short: 'Contrast',
    unit: '%',
    icon: Icons.contrast_rounded,
    color: _teal,
    check: TrendCheck.nearVision,
    higherIsBetter: true,
    base: 88,
    amp: 3,
    lo: 30,
    hi: 100,
  ),

  // Voice check
  TrendMetric(
    key: 'voice_clarity',
    label: 'Clarity',
    short: 'Clarity',
    unit: '/100',
    icon: Icons.record_voice_over_outlined,
    color: _green,
    check: TrendCheck.voice,
    higherIsBetter: true,
    base: 78,
    amp: 5,
    drift: 3,
    lo: 30,
    hi: 99,
  ),
  TrendMetric(
    key: 'pitch',
    label: 'Pitch',
    short: 'Pitch',
    unit: 'Hz',
    icon: Icons.music_note_outlined,
    color: _violet,
    check: TrendCheck.voice,
    base: 128,
    amp: 6,
    lo: 70,
    hi: 300,
  ),
  TrendMetric(
    key: 'speech_rate',
    label: 'Speech rate',
    short: 'Rate',
    unit: 'words/min',
    icon: Icons.speed_rounded,
    color: _sky,
    check: TrendCheck.voice,
    base: 142,
    amp: 8,
    lo: 60,
    hi: 220,
  ),
];

List<TrendMetric> metricsFor(TrendCheck c) =>
    kTrendMetrics.where((m) => m.check == c).toList();

/// One finished scan with its values.
class TrendScan {
  const TrendScan({
    required this.at,
    required this.check,
    required this.values,
  });

  final DateTime at;
  final TrendCheck check;
  final Map<String, double> values;
}

/// A chart point (raw scan for "Today", daily average otherwise).
class TrendPoint {
  const TrendPoint(this.at, this.value);
  final DateTime at;
  final double value;
}

/// Demo data so the Trends screen has something to show.
///
/// Deterministic per member (seeded from the member id) so the chart stays
/// stable between rebuilds. Not real measurements.
class TrendsMockData {
  TrendsMockData._(this.scans);

  final List<TrendScan> scans;

  factory TrendsMockData.forMember(String seedKey, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final rnd = math.Random(seedKey.hashCode & 0x7fffffff);
    final scans = <TrendScan>[];

    double noise(double amp) => (rnd.nextDouble() * 2 - 1) * amp;

    // Per-member shift and wave period for each metric.
    final shift = {for (final m in kTrendMetrics) m.key: noise(m.amp * 1.2)};
    final period = {
      for (final m in kTrendMetrics) m.key: 7 + rnd.nextDouble() * 9,
    };
    final offset = {
      for (final c in TrendCheck.values) c: rnd.nextInt(c.everyDays),
    };

    for (var d = 89; d >= 0; d--) {
      final day = DateTime(today.year, today.month, today.day - d);
      final progress = 1 - d / 89; // 0 → 1 across the quarter

      for (final c in TrendCheck.values) {
        int count;
        if (c.everyDays == 1) {
          count = d == 0 ? 2 : (rnd.nextDouble() < 0.18 ? 0 : 1);
        } else {
          count = ((d + offset[c]!) % c.everyDays == 0 || d == 0) ? 1 : 0;
        }
        for (var i = 0; i < count; i++) {
          final hour = c == TrendCheck.face
              ? (i == 0 ? 8 + rnd.nextInt(2) : 13 + rnd.nextInt(2))
              : 10 + rnd.nextInt(5);
          final at = day.add(Duration(hours: hour, minutes: rnd.nextInt(60)));
          if (at.isAfter(today)) continue;
          final values = <String, double>{};
          for (final m in metricsFor(c)) {
            final v =
                m.base +
                shift[m.key]! +
                math.sin(d / period[m.key]! * 2 * math.pi) * m.amp +
                m.drift * progress +
                noise(m.amp * 0.7);
            final clamped = v.clamp(m.lo, m.hi).toDouble();
            values[m.key] = double.parse(clamped.toStringAsFixed(m.decimals));
          }
          scans.add(TrendScan(at: at, check: c, values: values));
        }
      }
    }
    scans.sort((a, b) => b.at.compareTo(a.at)); // newest first
    return TrendsMockData._(scans);
  }

  /// Scans of [check] inside [range], newest first.
  List<TrendScan> scansIn(TrendCheck check, TrendRange range, DateTime now) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: range.days - 1));
    return scans
        .where((s) => s.check == check && !s.at.isBefore(start))
        .toList();
  }

  /// Every value of [m] this person has (for the usual range).
  List<double> allValues(TrendMetric m) => [
    for (final s in scans)
      if (s.check == m.check && s.values[m.key] != null) s.values[m.key]!,
  ];

  /// Chart series, oldest first.
  List<TrendPoint> series(TrendMetric m, TrendRange range, DateTime now) {
    final inRange = scansIn(
      m.check,
      range,
      now,
    ).where((s) => s.values.containsKey(m.key)).toList().reversed.toList();
    if (range == TrendRange.today) {
      return [for (final s in inRange) TrendPoint(s.at, s.values[m.key]!)];
    }
    final byDay = <DateTime, List<double>>{};
    for (final s in inRange) {
      final day = DateTime(s.at.year, s.at.month, s.at.day);
      (byDay[day] ??= []).add(s.values[m.key]!);
    }
    return [
      for (final e in byDay.entries)
        TrendPoint(e.key, e.value.reduce((a, b) => a + b) / e.value.length),
    ];
  }
}
