import 'package:flutter/material.dart';

import '../domain/algorithms/marker_readings.dart';
import '../domain/entities/case_record.dart';
import '../domain/entities/enums.dart';
import '../domain/entities/marker_catalogue.dart';
import 'mirror_theme.dart';
import 'mirror_widgets.dart';

const Color _ink = MirrorColors.inkLight;
const Color _muted = MirrorColors.inkMutedLight;
const Color _outline = MirrorColors.outlineLight;
const Color _surface = MirrorColors.surfaceLight;

BoxDecoration _cardBox() => BoxDecoration(
  color: _surface,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: _outline),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);

String displayRuleText(MarkerDisplay d, {bool bpReleased = false}) =>
    switch (d) {
      MarkerDisplay.shown => 'Displayed value (spec output)',
      MarkerDisplay.bandOnly => 'Band only — release gate G-24',
      MarkerDisplay.internal => 'Internal only — never shown to members (R-9)',
      MarkerDisplay.diagnostic => 'Diagnostic — operator QA only',
      MarkerDisplay.internalUntilValidated =>
        bpReleased
            ? 'Numeric display enabled after ISO 81060-2 validation'
            : 'Internal until numeric validation (ISO 81060-2, G-24)',
    };

bool _bandMeaningful(SemanticBand b) =>
    b != SemanticBand.hidden &&
    b != SemanticBand.notAvailable &&
    b != SemanticBand.notAssessed &&
    b != SemanticBand.rangeNotAvailable;

/// T-RES "markers grid": one card per algorithm with every spec output
/// marker, value, band and normal range; internal / diagnostic markers fold
/// into one operator expander at the end.
class AlgorithmOutputsSection extends StatelessWidget {
  const AlgorithmOutputsSection({
    super.key,
    required this.groups,
    this.title = 'Algorithm outputs',
    this.caption = 'Every output marker from the spec cards, with its value',
    this.showHeader = true,
    this.showInternalExpander = true,
    this.gap = 10,
  });

  final List<ReadingGroup> groups;
  final String title;
  final String caption;
  final bool showHeader;
  final bool showInternalExpander;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final visible = groups.where((g) => g.memberReadings.isNotEmpty).toList();
    final internal = [for (final g in groups) ...g.internalReadings];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) _header(title, caption),
        for (var i = 0; i < visible.length; i++) ...[
          AlgorithmOutputCard(group: visible[i]),
          if (i != visible.length - 1) SizedBox(height: gap),
        ],
        if (showInternalExpander && internal.isNotEmpty) ...[
          SizedBox(height: gap),
          InternalMarkersExpander(readings: internal),
        ],
      ],
    );
  }

  Widget _header(String t, String c) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t,
          style: const TextStyle(
            color: _ink,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(c, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    ),
  );
}

/// One algorithm card: id chip, title, spec reference and its output rows.
class AlgorithmOutputCard extends StatelessWidget {
  const AlgorithmOutputCard({super.key, required this.group});

  final ReadingGroup group;

  @override
  Widget build(BuildContext context) {
    final rows = group.memberReadings;
    final c = group.card;
    return Container(
      decoration: _cardBox(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _idChip(c.id),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Spec ${c.specRef} · ${c.purpose}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++) ...[
            MarkerReadingRow(reading: rows[i]),
            if (i != rows.length - 1) const Divider(height: 1, color: _outline),
          ],
        ],
      ),
    );
  }

  static Widget _idChip(String id) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: MirrorColors.primaryContainer,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      id,
      style: const TextStyle(
        color: MirrorColors.primary,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    ),
  );
}

/// Label + code on the left, value + band on the right, caption beneath.
class MarkerReadingRow extends StatelessWidget {
  const MarkerReadingRow({super.key, required this.reading, this.onTap});

  final MarkerReading reading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final has = r.hasValue;
    final style = BandVisualStyle.forBand(r.band);
    final normalText = r.spec.normalRange == null
        ? null
        : (r.spec.kind == MarkerKind.band ||
                  r.spec.kind == MarkerKind.classCode ||
                  r.spec.kind == MarkerKind.flag
              ? 'Normal: ${r.spec.normalRange}'
              : r.spec.normalRange);
    final caption = has ? (r.thresholdNote ?? normalText) : r.formatted;
    return InkWell(
      onTap: onTap ?? () => showMarkerDetailSheet(context, r),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.label,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.code,
                        style: const TextStyle(color: _muted, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        has ? r.formatted : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: has ? style.foreground : _muted,
                          fontSize: has && r.spec.kind == MarkerKind.number
                              ? 15
                              : 12.5,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (has && _bandMeaningful(r.band)) ...[
                        const SizedBox(height: 3),
                        BandChip(band: r.band, compact: true),
                      ],
                      if (!has)
                        const Text(
                          'not available',
                          style: TextStyle(color: _muted, fontSize: 10.5),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (caption != null && caption.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                has ? caption : 'Why: $caption',
                style: TextStyle(
                  color: has ? _muted : MirrorColors.warningFg,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Operator-only list of internal / diagnostic markers (R-9).
class InternalMarkersExpander extends StatelessWidget {
  const InternalMarkersExpander({super.key, required this.readings});

  final List<MarkerReading> readings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.visibility_off_outlined, color: _muted),
          title: const Text(
            'Internal & diagnostic markers',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${readings.length} markers the spec keeps off the member view (R-9 · operator QA)',
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          children: [
            for (final r in readings)
              InkWell(
                onTap: () => showMarkerDetailSheet(context, r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 128,
                        child: Text(
                          r.code,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${r.hasValue ? r.formatted : (r.reason ?? 'Not available')} · ${r.label} · ${displayRuleText(r.spec.display, bpReleased: r.bpNumericReleased)}',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
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
}

// ---------------------------------------------------------------------------
// S-D08 Marker Detail
// ---------------------------------------------------------------------------

Future<void> showMarkerDetailSheet(BuildContext context, MarkerReading r) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MirrorColors.backgroundLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: MarkerDetailView(reading: r),
      ),
    ),
  );
}

/// Full-screen S-D08 for the vitals report (also hosts the waveform view).
class MarkerDetailScreen extends StatelessWidget {
  const MarkerDetailScreen({super.key, required this.reading, this.extra});

  final MarkerReading reading;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MirrorColors.backgroundLight,
      appBar: AppBar(
        title: Text(reading.label),
        actions: [
          IconButton(
            tooltip: 'Screen spec & gates (S-D08)',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-D08'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (extra != null) ...[extra!, const SizedBox(height: 14)],
            MarkerDetailView(reading: reading),
          ],
        ),
      ),
    );
  }
}

/// Definition, value / band, range bar, how computed, conditions informed and
/// confirmatory investigations (§13) for one marker.
class MarkerDetailView extends StatelessWidget {
  const MarkerDetailView({super.key, required this.reading});

  final MarkerReading reading;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final s = r.spec;
    final card = MarkerCatalogue.card(s.algorithmId);
    final style = BandVisualStyle.forBand(r.band);
    final has = r.hasValue;
    final gauge = s.thresholds;
    final num = r.numericValue;
    final conditions = {
      ...s.conditions,
      ...?r.envelope?.conditionsInformed,
    }.toList();
    final investigations = [
      for (final c in conditions)
        if (ConfirmatoryInvestigationsRegistry.byCondition[c] != null)
          ConfirmatoryInvestigationsRegistry.byCondition[c]!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero
        Container(
          decoration: _cardBox(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AlgorithmOutputCard._idChip(s.algorithmId),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${card?.title ?? s.algorithmId} · Spec ${s.specRef}',
                      style: const TextStyle(color: _muted, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                r.label,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                r.code,
                style: const TextStyle(color: _muted, fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      has ? r.formatted : '—',
                      style: TextStyle(
                        color: has ? style.foreground : _muted,
                        fontSize: has && s.kind == MarkerKind.number ? 34 : 22,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (has && _bandMeaningful(r.band)) BandChip(band: r.band),
                ],
              ),
              if (!has) ...[
                const SizedBox(height: 8),
                Text(
                  r.formatted,
                  style: const TextStyle(
                    color: MirrorColors.warningFg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (r.thresholdNote != null) ...[
                const SizedBox(height: 6),
                Text(
                  r.thresholdNote!,
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
              ],
              if (gauge != null && num != null && has) ...[
                const SizedBox(height: 14),
                _Gauge(thresholds: gauge, value: num, pin: style.foreground),
              ],
              if (gauge == null &&
                  s.kind == MarkerKind.number &&
                  s.normalRange == null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MirrorColors.infoBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Reference range not yet available — age-band tables are built from the Mayura healthy cohort (medical safety rule).',
                    style: TextStyle(
                      color: MirrorColors.infoFg,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Definition
        Container(
          decoration: _cardBox(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What it is',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              if (card != null) _kv('Purpose', card.purpose),
              if (s.howComputed.isNotEmpty) _kv('How computed', s.howComputed),
              if (card != null && card.classification.isNotEmpty)
                _kv('Method', card.classification),
              _kv(
                'Unit · decimals',
                '${s.unit.isEmpty ? '—' : s.unit} · ${s.decimals} dp',
              ),
              if (s.validRangeLabel.isNotEmpty)
                _kv('Valid range', s.validRangeLabel),
              _kv(
                'Normal range',
                s.normalRange ?? 'Reference range not yet available',
              ),
              if (s.allowedValues.isNotEmpty)
                _kv('Values', s.allowedValues.join(' / ')),
              _kv(
                'Display rule',
                displayRuleText(s.display, bpReleased: r.bpNumericReleased),
              ),
              if (card != null && card.failureRule.isNotEmpty)
                _kv('If it fails', card.failureRule),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // This reading
        Container(
          decoration: _cardBox(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This reading',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              _kv('Status', _statusText(r)),
              if (r.reason != null && r.reason!.isNotEmpty)
                _kv('Note', r.reason!),
              if (r.envelope != null) ...[
                _kv(
                  'Algorithm',
                  '${r.envelope!.algorithmId} ${r.envelope!.algorithmVersion}',
                ),
                _kv('Range version', r.envelope!.rangeVersion),
                _kv(
                  'Confidence',
                  '${r.envelope!.confidence.toStringAsFixed(2)} (hidden below 0.60, G-23)',
                ),
                if (r.envelope!.isEstimate) _kv('Label', 'Estimate'),
              ],
              if (conditions.isNotEmpty)
                _kv('Conditions informed', conditions.join(', ')),
            ],
          ),
        ),

        // Confirmatory investigations
        if (investigations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: _cardBox(),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'If this is out of range (§13)',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                for (final inv in investigations) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${inv.markerOrScreenName} · trigger: ${inv.appTrigger} · ${inv.defaultUrgency.label}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    inv.investigations,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Usual cut-offs: ${inv.usualDiagnosticCutoffs}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    'Reference pairing: ${inv.pairingReferenceTest} · ${inv.maxPairingGapLabel}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                const Text(
                  "Your lab's ranges and your doctor's judgement take precedence.",
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _statusText(MarkerReading r) => switch (r.status) {
    MarkerDisplayStatus.ok => 'Displayed',
    MarkerDisplayStatus.bandOnly => 'Band only (G-24)',
    MarkerDisplayStatus.rangeNotAvailable =>
      'Value shown · reference range pending cohort',
    MarkerDisplayStatus.needsConfirmation => 'Needs a confirmation scan (G-27)',
    MarkerDisplayStatus.underSpecialistReview =>
      'Sent for specialist review (IMG-10)',
    MarkerDisplayStatus.lowConfidenceHidden =>
      'Hidden — confidence < 0.60 (G-23)',
    MarkerDisplayStatus.qualityRetakeRequired => 'Retake required (G-25)',
    MarkerDisplayStatus.notAvailable => 'Not available',
    MarkerDisplayStatus.notAssessed => 'Not assessed',
    MarkerDisplayStatus.inValidation => 'In validation (G-24)',
    MarkerDisplayStatus.internalOnly => 'Internal marker (R-9)',
  };

  static Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(k, style: const TextStyle(color: _muted, fontSize: 11.5)),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.thresholds,
    required this.value,
    required this.pin,
  });

  final MarkerThresholds thresholds;
  final double value;
  final Color pin;

  @override
  Widget build(BuildContext context) {
    final t = thresholds;
    final segs = t.labels.length;
    double pos() {
      if (value <= t.breakpoints.first) return 0;
      if (value >= t.breakpoints.last) return 1;
      for (var i = 0; i < segs; i++) {
        final lo = t.breakpoints[i];
        final hi = t.breakpoints[i + 1];
        if (value <= hi) {
          final f = hi > lo ? (value - lo) / (hi - lo) : 0.0;
          return (i + f) / segs;
        }
      }
      return 1;
    }

    final p = pos();
    return Column(
      children: [
        SizedBox(
          height: 18,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  for (var i = 0; i < segs; i++)
                    Expanded(
                      child: Container(
                        height: 8,
                        margin: EdgeInsets.only(right: i == segs - 1 ? 0 : 2),
                        decoration: BoxDecoration(
                          color: BandVisualStyle.forBand(t.bands[i]).background,
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(i == 0 ? 99 : 2),
                            right: Radius.circular(i == segs - 1 ? 99 : 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Align(
                alignment: Alignment((p.clamp(0.02, 0.98) * 2) - 1.0, 0),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: pin, width: 3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final l in t.labels)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 10.5),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
