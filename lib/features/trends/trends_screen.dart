import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_ui.dart';
import '../../core/state/app_state.dart';
import 'trends_data.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _time(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _date(DateTime t) => '${t.day} ${_months[t.month - 1]}';

String _dayLabel(DateTime t, DateTime now) {
  final d = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_weekdays[t.weekday - 1]}, ${_date(t)}';
}

/// Trends: how a person's face- and eye-check values change over time.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key, this.onNewScan, this.now, this.data});

  /// Called by "New scan" (e.g. jump to the Scans tab).
  final VoidCallback? onNewScan;

  /// Overrides for tests and previews.
  final DateTime? now;
  final TrendsMockData? data;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  TrendCheck _check = TrendCheck.face;
  TrendMetric _metric = kTrendMetrics.first;
  TrendRange _range = TrendRange.week;
  int? _selected;
  bool _showAll = false;
  TrendsMockData? _data;
  String? _dataKey;

  DateTime get _now => widget.now ?? DateTime.now();

  TrendsMockData _dataFor(String memberId) {
    if (widget.data != null) return widget.data!;
    if (_data == null || _dataKey != memberId) {
      _data = TrendsMockData.forMember(memberId, now: widget.now);
      _dataKey = memberId;
    }
    return _data!;
  }

  void _setCheck(TrendCheck c) {
    if (c == _check) return;
    setState(() {
      _check = c;
      _metric = metricsFor(c).first;
      _selected = null;
      _showAll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final subject = app.activeSubject;
    final data = _dataFor(subject.id);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final series = data.series(_metric, _range, _now);
    final records = data.scansIn(_check, _range, _now);

    // Personal usual range from all of this person's data for the metric.
    final all = data.allValues(_metric);
    (double, double)? usual;
    if (all.length >= 5) {
      final mean = all.reduce((a, b) => a + b) / all.length;
      final sd = math.sqrt(
        all.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            all.length,
      );
      usual = (mean - sd, mean + sd);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trends'),
        actions: [
          IconButton(
            key: const ValueKey('trends_refresh'),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _selected = null);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Trends are up to date'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _subjectStrip(context, subject.fullName, subject.ageYears),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Check'),
          const SizedBox(height: 8),
          _checkPicker(context),
          const SizedBox(height: 14),
          _sectionLabel(context, 'Measure'),
          const SizedBox(height: 8),
          _metricChips(context),
          const SizedBox(height: 12),
          _rangeTabs(context),
          const SizedBox(height: 12),
          _chartCard(context, series, usual),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Records',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${records.length} ${records.length == 1 ? 'scan' : 'scans'} · ${_range == TrendRange.today ? 'today' : 'last ${_range.label}'}',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                key: const ValueKey('trends_new_scan'),
                onPressed: _newScan,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New scan'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    EmptyState(
                      icon: Icons.event_note_outlined,
                      title: _range == TrendRange.today
                          ? 'No scans today'
                          : 'No scans in the last ${_range.label}',
                      message: 'A 60-second scan adds a record here.',
                    ),
                    OutlinedButton(
                      onPressed: _newScan,
                      child: const Text('Start a scan'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            )
          else
            _recordsList(context, records),
          const SizedBox(height: 18),
          Text(
            'Demo trend data · screening only, not a medical diagnosis',
            textAlign: TextAlign.center,
            style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _newScan() {
    HapticFeedback.selectionClick();
    if (widget.onNewScan != null) {
      widget.onNewScan!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  // ── Subject ────────────────────────────────────────────────────────────
  Widget _subjectStrip(BuildContext context, String name, int age) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(MirrorRadius.md),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          MemberAvatar(name: name, radius: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Showing trends for ', style: t.bodySmall),
                  TextSpan(
                    text: '$name, $age',
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Check picker ───────────────────────────────────────────────────────
  /// Lets a horizontal row run edge to edge past the 16px page padding.
  Widget _bleed(double height, Widget child) => SizedBox(
    height: height,
    child: LayoutBuilder(
      builder: (context, box) => OverflowBox(
        maxWidth: box.maxWidth + 32,
        minWidth: box.maxWidth + 32,
        child: child,
      ),
    ),
  );

  Widget _sectionLabel(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _checkPicker(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return _bleed(
      96,
      ListView.separated(
        key: const ValueKey('trends_check_row'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        itemCount: TrendCheck.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = TrendCheck.values[i];
          final selected = c == _check;
          return GestureDetector(
            key: ValueKey('trends_check_${c.name}'),
            onTap: () {
              HapticFeedback.selectionClick();
              _setCheck(c);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 78,
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0B7A75), Color(0xFF0B5F63)],
                      )
                    : null,
                color: selected ? null : scheme.surface,
                borderRadius: BorderRadius.circular(MirrorRadius.lg),
                border: Border.all(
                  color: selected ? Colors.transparent : scheme.outline,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF0B7A75,
                          ).withValues(alpha: dark ? 0.35 : 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.18)
                          : scheme.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      c.icon,
                      size: 18,
                      color: selected ? Colors.white : scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      c.short,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : scheme.onSurface,
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Metric chips ───────────────────────────────────────────────────────
  Color _tone(Color c) => Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(c, Colors.white, 0.35)!
      : c;

  Widget _metricChips(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = metricsFor(_check);
    return _bleed(
      36,
      ListView(
        key: const ValueKey('trends_metric_row'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final m in metrics) ...[
            Builder(
              builder: (context) {
                final selected = m == _metric;
                final c = _tone(m.color);
                return InkWell(
                  key: ValueKey('trends_metric_${m.key}'),
                  borderRadius: BorderRadius.circular(MirrorRadius.pill),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _metric = m;
                      _selected = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                    decoration: BoxDecoration(
                      color: selected
                          ? c.withValues(alpha: 0.14)
                          : scheme.surface,
                      borderRadius: BorderRadius.circular(MirrorRadius.pill),
                      border: Border.all(
                        color: selected ? c : scheme.outline,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(m.icon, size: 16, color: c),
                        const SizedBox(width: 6),
                        Text(
                          m.label,
                          style: TextStyle(
                            color: selected ? c : scheme.onSurface,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  // ── Range tabs ─────────────────────────────────────────────────────────
  Widget _rangeTabs(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(MirrorRadius.pill),
      ),
      child: Row(
        children: [
          for (final r in TrendRange.values)
            Expanded(
              child: GestureDetector(
                key: ValueKey('trends_range_${r.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _range = r;
                    _selected = null;
                    _showAll = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: r == _range ? scheme.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(MirrorRadius.pill),
                    boxShadow: r == _range
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    r.label,
                    style: TextStyle(
                      color: r == _range
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: r == _range
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Chart card ─────────────────────────────────────────────────────────
  Widget _chartCard(
    BuildContext context,
    List<TrendPoint> series,
    (double, double)? usual,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final c = _tone(_metric.color);

    if (series.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: EmptyState(
            icon: Icons.show_chart_rounded,
            title: _range == TrendRange.today
                ? 'No ${_metric.label.toLowerCase()} values today'
                : 'No ${_metric.label.toLowerCase()} values in the last ${_range.label}',
            message:
                'Finish a scan to start your ${_metric.label.toLowerCase()} trend.',
          ),
        ),
      );
    }

    final values = series.map((p) => p.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final sel = _selected != null && _selected! < series.length
        ? _selected!
        : null;
    final shown = series[sel ?? series.length - 1];
    final shownLabel = _range == TrendRange.today
        ? 'Today, ${_time(shown.at)}'
        : sel == null
        ? 'Latest · ${_dayLabel(shown.at, _now)}'
        : _dayLabel(shown.at, _now);

    // Change from first to last point in the window.
    final change = series.length > 1 ? values.last - values.first : 0.0;
    final pct = values.first == 0 ? 0.0 : change / values.first * 100;
    final up = change > 0;
    final flat = pct.abs() < 2;
    final Color changeColor;
    if (flat || _metric.higherIsBetter == null) {
      changeColor = scheme.onSurfaceVariant;
    } else {
      changeColor = _tone(
        up == _metric.higherIsBetter!
            ? MirrorColors.successFg
            : MirrorColors.warningFg,
      );
    }

    // Plain-language insight vs. the personal usual range.
    String insight;
    IconData insightIcon;
    if (usual == null) {
      insight = 'A few more scans will build your usual range.';
      insightIcon = Icons.hourglass_bottom_rounded;
    } else if (values.last > usual.$2) {
      insight = 'Latest value is above your usual range.';
      insightIcon = Icons.north_east_rounded;
    } else if (values.last < usual.$1) {
      insight = 'Latest value is below your usual range.';
      insightIcon = Icons.south_east_rounded;
    } else {
      insight = 'Latest value is within your usual range.';
      insightIcon = Icons.check_circle_outline_rounded;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_metric.icon, size: 16, color: c),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _metric.label,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (series.length > 1)
                  Container(
                    padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(MirrorRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          flat
                              ? Icons.trending_flat_rounded
                              : up
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 14,
                          color: changeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          flat
                              ? 'Steady'
                              : '${up ? '+' : '−'}${pct.abs().toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _metric.format(shown.value),
                    key: ValueKey('${_metric.key}_${shown.at}'),
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(_metric.unit, style: t.bodySmall),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shownLabel,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, box) {
                void pick(double dx) {
                  if (series.length < 2) return;
                  final i = (dx / box.maxWidth * (series.length - 1))
                      .round()
                      .clamp(0, series.length - 1);
                  if (i != _selected) {
                    HapticFeedback.selectionClick();
                    setState(() => _selected = i);
                  }
                }

                return GestureDetector(
                  key: const ValueKey('trends_chart'),
                  onTapDown: (d) => pick(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
                  child: SizedBox(
                    height: 150,
                    width: box.maxWidth,
                    child: CustomPaint(
                      painter: _TrendLinePainter(
                        values: values,
                        band: usual,
                        color: c,
                        grid: scheme.outline,
                        surface: scheme.surface,
                        bandColor: c.withValues(alpha: 0.05),
                        selected: sel,
                        showDots: series.length <= 31,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            _xLabels(context, series),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat(context, 'Low', _metric.format(lo)),
                _statDivider(context),
                _stat(context, 'Average', _metric.format(avg)),
                _statDivider(context),
                _stat(context, 'High', _metric.format(hi)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(insightIcon, size: 16, color: c),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      usual == null
                          ? insight
                          : '$insight  Usual: ${_metric.format(usual.$1)}–${_metric.format(usual.$2)} ${_metric.unit}',
                      style: t.bodySmall?.copyWith(color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _xLabels(BuildContext context, List<TrendPoint> series) {
    final t = Theme.of(context).textTheme;
    String fmt(DateTime d) => switch (_range) {
      TrendRange.today => _time(d),
      TrendRange.week => _weekdays[d.weekday - 1],
      _ => _date(d),
    };
    final labels = <String>[
      fmt(series.first.at),
      if (series.length > 2) fmt(series[series.length ~/ 2].at),
      if (series.length > 1) fmt(series.last.at),
    ];
    return Row(
      mainAxisAlignment: labels.length == 1
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      children: [for (final l in labels) Text(l, style: t.labelSmall)],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 1),
          Text(label, style: t.labelSmall),
        ],
      ),
    );
  }

  Widget _statDivider(BuildContext context) => Container(
    width: 1,
    height: 26,
    color: Theme.of(context).colorScheme.outline,
  );

  // ── Records ────────────────────────────────────────────────────────────
  Widget _recordsList(BuildContext context, List<TrendScan> records) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    const preview = 6;
    final visible = _showAll ? records : records.take(preview).toList();
    final metrics = metricsFor(_check);
    final c = _tone(_metric.color);

    final children = <Widget>[];
    String? lastDay;
    for (var i = 0; i < visible.length; i++) {
      final s = visible[i];
      final day = _dayLabel(s.at, _now);
      if (day != lastDay) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(14, i == 0 ? 12 : 14, 14, 4),
            child: Text(
              day.toUpperCase(),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
        );
        lastDay = day;
      }
      final v = s.values[_metric.key];
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  s.check.icon,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.check.label} · ${_time(s.at)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      [
                        for (final m in metrics)
                          if (m != _metric && s.values[m.key] != null)
                            '${m.short} ${m.format(s.values[m.key]!)}',
                      ].take(3).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (v != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(MirrorRadius.pill),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _metric.format(v),
                          style: TextStyle(
                            color: c,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: ' ${_metric.unit}',
                          style: TextStyle(
                            color: c,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...children,
          if (records.length > preview) ...[
            Divider(height: 16, color: scheme.outline),
            TextButton(
              key: const ValueKey('trends_show_all'),
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll ? 'Show less' : 'Show all ${records.length} records',
              ),
            ),
            const SizedBox(height: 4),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  _TrendLinePainter({
    required this.values,
    required this.band,
    required this.color,
    required this.grid,
    required this.surface,
    required this.bandColor,
    required this.selected,
    required this.showDots,
  });

  final List<double> values;
  final (double, double)? band;
  final Color color;
  final Color grid;
  final Color surface;
  final Color bandColor;
  final int? selected;
  final bool showDots;

  @override
  void paint(Canvas canvas, Size size) {
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (band != null) {
      lo = math.min(lo, band!.$1);
      hi = math.max(hi, band!.$2);
    }
    final pad = (hi - lo).abs() < 1e-6 ? 1.0 : (hi - lo) * 0.15;
    lo -= pad;
    hi += pad;
    const top = 8.0;
    final h = size.height - top - 6;
    double y(double v) => top + (1 - (v - lo) / (hi - lo)) * h;
    double x(int i) => values.length == 1
        ? size.width / 2
        : i / (values.length - 1) * size.width;

    // Grid
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var g = 0; g < 4; g++) {
      final gy = top + g / 3 * h;
      const dash = 4.0;
      for (var gx = 0.0; gx < size.width; gx += dash * 2) {
        canvas.drawLine(Offset(gx, gy), Offset(gx + dash, gy), gridPaint);
      }
    }

    // Usual-range band
    if (band != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(0, y(band!.$2), size.width, y(band!.$1)),
          const Radius.circular(6),
        ),
        Paint()..color = bandColor,
      );
      final edge = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      for (final v in [band!.$1, band!.$2]) {
        final by = y(v);
        for (var gx = 0.0; gx < size.width; gx += 6) {
          canvas.drawLine(Offset(gx, by), Offset(gx + 3, by), edge);
        }
      }
    }

    final pts = [
      for (var i = 0; i < values.length; i++) Offset(x(i), y(values[i])),
    ];

    if (pts.length > 1) {
      // Smooth path
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final p0 = pts[i - 1];
        final p1 = pts[i];
        final mx = (p0.dx + p1.dx) / 2;
        path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
      }
      final area = Path.from(path)
        ..lineTo(pts.last.dx, size.height)
        ..lineTo(pts.first.dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (showDots || pts.length == 1) {
      for (final p in pts) {
        canvas.drawCircle(p, 3.2, Paint()..color = surface);
        canvas.drawCircle(
          p,
          3.2,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
      }
    }

    // Highlight: selected point, or the latest one.
    final hiIndex = selected ?? pts.length - 1;
    final hp = pts[hiIndex];
    if (selected != null) {
      canvas.drawLine(
        Offset(hp.dx, top),
        Offset(hp.dx, size.height),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1.2,
      );
    }
    canvas.drawCircle(hp, 9, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawCircle(hp, 5, Paint()..color = surface);
    canvas.drawCircle(hp, 3.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrendLinePainter old) =>
      old.values != values ||
      old.selected != selected ||
      old.color != color ||
      old.band != band ||
      old.surface != surface;
}
