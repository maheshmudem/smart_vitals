import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_ui.dart';
import 'operator_store.dart';

/// One input on the reading form.
class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label,
    this.unit,
    this.min,
    this.max, {
    this.optional = false,
    this.decimal = false,
  });

  final String key;
  final String label;
  final String unit;
  final double min;
  final double max;
  final bool optional;
  final bool decimal;
}

const Map<ReadingKind, List<_FieldSpec>> _fields = {
  ReadingKind.bpCuff: [
    _FieldSpec('sys', 'Top number', 'mmHg', 60, 260),
    _FieldSpec('dia', 'Bottom number', 'mmHg', 30, 160),
    _FieldSpec('pulse', 'Pulse', 'beats/min', 30, 220, optional: true),
  ],
  ReadingKind.oximeter: [
    _FieldSpec('spo2', 'Oxygen (SpO2)', '%', 50, 100),
    _FieldSpec('pulse', 'Pulse', 'beats/min', 30, 220, optional: true),
  ],
  ReadingKind.haemoglobin: [
    _FieldSpec('hb', 'Haemoglobin', 'g/dL', 3, 25, decimal: true),
  ],
  ReadingKind.hba1c: [_FieldSpec('a1c', 'HbA1c', '%', 3, 20, decimal: true)],
  ReadingKind.glucose: [
    _FieldSpec('glucose', 'Blood glucose', 'mg/dL', 20, 600),
  ],
};

IconData readingIcon(ReadingKind k) => switch (k) {
  ReadingKind.bpCuff => Icons.speed_rounded,
  ReadingKind.oximeter => Icons.fingerprint_rounded,
  ReadingKind.haemoglobin => Icons.bloodtype_outlined,
  ReadingKind.hba1c => Icons.science_outlined,
  ReadingKind.glucose => Icons.water_drop_outlined,
};

Color readingColor(ReadingKind k) => switch (k) {
  ReadingKind.bpCuff => const Color(0xFFDC2626),
  ReadingKind.oximeter => const Color(0xFF0284C7),
  ReadingKind.haemoglobin => const Color(0xFFBE123C),
  ReadingKind.hba1c => const Color(0xFF7C3AED),
  ReadingKind.glucose => const Color(0xFFD97706),
};

String _rangeHint(ReadingKind k, WalkIn p) => switch (k) {
  ReadingKind.bpCuff => 'Normal is below 130/80 mmHg',
  ReadingKind.oximeter => 'Normal is 95% or above',
  ReadingKind.haemoglobin =>
    'Normal is ${p.sex == WalkInSex.male ? "13" : "12"} g/dL or above',
  ReadingKind.hba1c => 'Normal is below 5.7%',
  ReadingKind.glucose => 'Fasting normal is below 100 mg/dL',
};

/// Record readings taken with the person's own devices or from a lab report,
/// and review the ones already saved.
class ReferenceReadingsScreen extends StatefulWidget {
  const ReferenceReadingsScreen({
    super.key,
    required this.person,
    this.store,
    this.justCreated = false,
    this.initialKind,
  });

  final WalkIn person;
  final OperatorStore? store;

  /// Shows a "profile created" confirmation at the top.
  final bool justCreated;

  /// Reading type to pre-select (from the quick-reading chips).
  final ReadingKind? initialKind;

  @override
  State<ReferenceReadingsScreen> createState() =>
      _ReferenceReadingsScreenState();
}

class _ReferenceReadingsScreenState extends State<ReferenceReadingsScreen> {
  late final OperatorStore _store = widget.store ?? OperatorStore.instance;
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _ctrls = {};
  late ReadingKind _kind = widget.initialKind ?? ReadingKind.bpCuff;
  GlucoseTiming _timing = GlucoseTiming.fasting;
  bool _consent = false;
  bool _consentError = false;

  TextEditingController _c(String key) =>
      _ctrls.putIfAbsent('${_kind.name}.$key', TextEditingController.new);

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() {
    final ok = _form.currentState?.validate() ?? false;
    setState(() => _consentError = !_consent);
    if (!ok || !_consent) return;

    final values = <String, double>{
      for (final f in _fields[_kind]!)
        if (double.tryParse(_c(f.key).text) != null)
          f.key: double.parse(_c(f.key).text),
    };
    final r = _store.addReading(
      widget.person,
      _kind,
      values,
      glucoseTiming: _timing,
    );
    for (final f in _fields[_kind]!) {
      _c(f.key).clear();
    }
    setState(() => _consent = false);
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${r.kind.shortLabel} saved · ${readingValueText(r)}'),
      ),
    );
  }

  Future<void> _delete(ReferenceReading r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Delete this reading?'),
        content: Text(
          '${r.kind.shortLabel} · ${readingValueText(r)} will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('reading_delete_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: MirrorColors.dangerFg,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) _store.deleteReading(widget.person, r);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = widget.person;

    return Scaffold(
      appBar: AppBar(title: const Text('Reference readings')),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _personCard(context, p),
              const SizedBox(height: 22),
              Text(
                'Add a reading',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'From their own device or a recent lab report',
                style: t.bodySmall,
              ),
              const SizedBox(height: 12),
              _kindPicker(context),
              const SizedBox(height: 12),
              _entryCard(context, p),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saved readings',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (p.readings.isNotEmpty)
                    Text('${p.readings.length}', style: t.bodySmall),
                ],
              ),
              const SizedBox(height: 10),
              if (p.readings.isEmpty)
                const EmptyState(
                  icon: Icons.monitor_heart_outlined,
                  title: 'No readings yet',
                  message: 'Add the first one above.',
                )
              else
                for (final r in p.readings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _savedCard(context, p, r),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _personCard(BuildContext context, WalkIn p) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final facts = [
      p.summary,
      if (p.heightCm != null) '${p.heightCm!.toStringAsFixed(0)} cm',
      if (p.weightKg != null) '${p.weightKg!.toStringAsFixed(1)} kg',
      p.language,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.justCreated) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: MirrorColors.successFg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(MirrorRadius.pill),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: MirrorColors.successFg,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Profile created',
                      style: TextStyle(
                        color: MirrorColors.successFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                MemberAvatar(name: p.fullName, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.fullName,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        facts.join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.phone != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.phone_outlined, size: 15, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(p.phone!, style: t.bodySmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kindPicker(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dark = scheme.brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, box) {
        final tileW = (box.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final k in ReadingKind.values)
              Builder(
                builder: (context) {
                  final selected = k == _kind;
                  final base = readingColor(k);
                  final c = dark ? Color.lerp(base, Colors.white, 0.3)! : base;
                  return GestureDetector(
                    key: ValueKey('reading_kind_${k.name}'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _kind = k;
                        _consentError = false;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: tileW,
                      height: 88,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? Color.alphaBlend(
                                c.withValues(alpha: 0.12),
                                scheme.surface,
                              )
                            : scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? c : scheme.outline,
                          width: selected ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: c.withValues(
                                    alpha: selected ? 1 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  readingIcon(k),
                                  size: 17,
                                  color: selected ? Colors.white : c,
                                ),
                              ),
                              const Spacer(),
                              if (selected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: c,
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            k.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelMedium?.copyWith(
                              height: 1.2,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _entryCard(BuildContext context, WalkIn p) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final specs = _fields[_kind]!;

    Widget field(_FieldSpec f) => TextFormField(
      key: ValueKey('reading_field_${f.key}'),
      controller: _c(f.key),
      keyboardType: TextInputType.numberWithOptions(decimal: f.decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          f.decimal ? RegExp(r'^\d*\.?\d{0,1}') : RegExp(r'\d*'),
        ),
      ],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: f.optional ? '${f.label} (optional)' : f.label,
        suffixText: f.unit,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return f.optional ? null : 'Required';
        }
        final n = double.tryParse(v);
        if (n == null || n < f.min || n > f.max) {
          return '${f.min.toStringAsFixed(0)}–${f.max.toStringAsFixed(0)}';
        }
        return null;
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            key: ValueKey(_kind),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(readingIcon(_kind), size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_kind.label, style: t.titleSmall)),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(_rangeHint(_kind, p), style: t.bodySmall),
              ),
              const SizedBox(height: 14),
              if (_kind == ReadingKind.glucose) ...[
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<GlucoseTiming>(
                    showSelectedIcon: false,
                    segments: [
                      for (final g in GlucoseTiming.values)
                        ButtonSegment(value: g, label: Text(g.label)),
                    ],
                    selected: {_timing},
                    onSelectionChanged: (s) =>
                        setState(() => _timing = s.first),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_kind == ReadingKind.bpCuff) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field(specs[0])),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                      child: Text(
                        '/',
                        style: t.headlineSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: field(specs[1])),
                  ],
                ),
                const SizedBox(height: 12),
                field(specs[2]),
              ] else
                for (var i = 0; i < specs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  field(specs[i]),
                ],
              const SizedBox(height: 14),
              // Consent
              Material(
                color: _consentError
                    ? MirrorColors.warningBg
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(MirrorRadius.md),
                child: InkWell(
                  key: const ValueKey('reading_consent'),
                  borderRadius: BorderRadius.circular(MirrorRadius.md),
                  onTap: () => setState(() {
                    _consent = !_consent;
                    _consentError = false;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _consent,
                          onChanged: (v) => setState(() {
                            _consent = v ?? false;
                            _consentError = false;
                          }),
                        ),
                        Expanded(
                          child: Text(
                            'The person agrees to store this reading. They can ask to delete it.',
                            style: t.bodySmall?.copyWith(
                              color: _consentError
                                  ? MirrorColors.warningFg
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_consentError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Ask for agreement before saving.',
                    style: t.bodySmall?.copyWith(color: MirrorColors.warningFg),
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('reading_add'),
                onPressed: _add,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add reading'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _savedCard(BuildContext context, WalkIn p, ReferenceReading r) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final verdict = interpretReading(r, p);
    final style = BandVisualStyle.forBand(verdict.band);
    final bandColor = dark
        ? Color.lerp(style.foreground, Colors.white, 0.35)!
        : style.foreground;
    final base = readingColor(r.kind);
    final c = dark ? Color.lerp(base, Colors.white, 0.3)! : base;
    final detail = readingDetailText(r);
    final time =
        '${r.recordedAt.hour % 12 == 0 ? 12 : r.recordedAt.hour % 12}:${r.recordedAt.minute.toString().padLeft(2, '0')} ${r.recordedAt.hour < 12 ? "AM" : "PM"}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(readingIcon(r.kind), color: c, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.kind.shortLabel,
                    style: t.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    readingValueText(r),
                    style: t.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: bandColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            MirrorRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(style.icon, size: 13, color: bandColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                verdict.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: bandColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text([?detail, time].join(' · '), style: t.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('reading_delete_${r.id}'),
              tooltip: 'Delete reading',
              onPressed: () => _delete(r),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
