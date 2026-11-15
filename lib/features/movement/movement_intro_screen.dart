import 'package:flutter/material.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/member_profile.dart';
import '../../core/domain/entities/movement_protocol.dart';
import '../../core/domain/entities/screening_catalogue_item.dart';
import '../../core/domain/gates/gate_evaluator.dart';
import '../../core/services/motion_sensor_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import 'movement_capture_screen.dart';
import 'movement_illustrations.dart';

/// Intro for one movement test (S-H01..S-H05): who, consent (G-04), what it
/// measures, what you need, gate status (G-11 / G-13 probed live), how it is
/// read, then "Ready".
class MovementIntroScreen extends StatefulWidget {
  const MovementIntroScreen({super.key, required this.protocol});

  final MovementProtocol protocol;

  @override
  State<MovementIntroScreen> createState() => _MovementIntroScreenState();
}

class _MovementIntroScreenState extends State<MovementIntroScreen> {
  MovementProtocol get p => widget.protocol;
  MotionAvailability? _motion;

  @override
  void initState() {
    super.initState();
    if (p.usesMotion) _probeMotion();
  }

  Future<void> _probeMotion() async {
    final a = await MotionSensorService.instance.probe();
    if (!mounted) return;
    AppStateScope.of(
      context,
    ).setMotionSensorsAvailable(a != MotionAvailability.unavailable);
    setState(() => _motion = a);
  }

  ScreeningCatalogueItem? get _item {
    for (final i in VitalsMirrorCatalogRegistry.catalogueItems) {
      if (i.id == p.catalogueId) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final subj = appState.activeSubject;
    final consent = subj.hasConsent(ConsentType.screening);
    final item = _item;
    final outcomes = item == null
        ? const <GateCheckOutcome>[]
        : appState.evaluateGatesForItem(item);
    final blockers = outcomes
        .where((o) => !o.passed && !o.isAdvisoryOnly)
        .toList();
    final String? helper = !consent
        ? 'Sign the screening consent above to continue (G-04)'
        : blockers.isNotEmpty
        ? blockers.first.reason
        : null;

    return Scaffold(
      backgroundColor: MirrorColors.backgroundLight,
      appBar: AppBar(
        title: Text(p.title),
        actions: [
          IconButton(
            tooltip: 'Screen spec & gates (${p.screenId})',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, p.screenId),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _subjectCard(context, appState, subj, consent),
            const SizedBox(height: 10),
            if (!consent) ...[
              _consentCard(appState, subj),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
            AnaemiaUi.sectionHeader(
              'What you\'ll do',
              '${p.durationLabel} · ${p.plainSensorLine.toLowerCase()}',
            ),
            _whatYouDoCard(),
            const SizedBox(height: 20),
            AnaemiaUi.sectionHeader('You will need', ''),
            _needsCard(),
            const SizedBox(height: 10),
            _whoCard(subj),
            const SizedBox(height: 20),
            AnaemiaUi.sectionHeader(
              'Checks before you start',
              'Everything here must be green to begin',
            ),
            _gatesCard(context, outcomes),
            const SizedBox(height: 12),
            _detailsExpander(),
            const SizedBox(height: 12),
            const DisclaimerFooter(),
          ],
        ),
      ),
      bottomNavigationBar: PrimaryBottomButton(
        label: 'Ready',
        icon: Icons.arrow_forward_rounded,
        helper: helper,
        onPressed: helper != null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MovementCaptureScreen(protocol: p),
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------

  Widget _subjectCard(
    BuildContext context,
    AppState appState,
    SubjectProfile subj,
    bool consent,
  ) {
    final initials = subj.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((s) => s.isEmpty ? '' : s[0].toUpperCase())
        .join();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AnaemiaUi.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AnaemiaUi.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Testing',
                      style: TextStyle(color: AnaemiaUi.muted, fontSize: 11),
                    ),
                    Text(
                      subj.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${subj.ageYears} y · ${subj.sex.label} · ${subj.relationship}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showSubjectPicker(context, appState),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Change'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AnaemiaUi.tag(
                consent ? 'Screening consent signed' : 'Consent needed (G-04)',
                color: consent
                    ? MirrorColors.successFg
                    : MirrorColors.warningFg,
                icon: consent
                    ? Icons.verified_rounded
                    : Icons.warning_amber_rounded,
              ),
              AnaemiaUi.tag(
                p.twoSided
                    ? 'Both hands · ${p.secondsPerSide} s each'
                    : p.durationLabel,
                color: MirrorColors.infoFg,
                icon: Icons.timer_outlined,
              ),
              if (subj.isChild)
                AnaemiaUi.tag(
                  'Dependant · guardian helps [OPEN]',
                  color: AnaemiaUi.accent,
                  icon: Icons.family_restroom_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSubjectPicker(BuildContext context, AppState appState) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Who is being tested?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AnaemiaUi.ink,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < appState.subjects.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    key: ValueKey('mov_subject_${appState.subjects[i].id}'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: i == appState.activeSubjectIndex
                            ? AnaemiaUi.primary
                            : AnaemiaUi.outline,
                      ),
                    ),
                    leading: Icon(
                      i == appState.activeSubjectIndex
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: AnaemiaUi.primary,
                    ),
                    title: Text(appState.subjects[i].fullName),
                    subtitle: Text(appState.subjects[i].relationship),
                    onTap: () {
                      appState.selectSubject(i);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _consentCard(AppState appState, SubjectProfile subj) {
    return MaterialCard(
      padding: EdgeInsets.zero,
      child: CheckboxListTile(
        value: false,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.fromLTRB(8, 2, 14, 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onChanged: (v) =>
            appState.toggleConsent(ConsentType.screening, v ?? false),
        title: Text(
          'I consent to screening for ${subj.fullName}',
          style: const TextStyle(
            color: AnaemiaUi.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Text(
          'Sensor and camera data stay on this device for screening only (G-04).',
          style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5, height: 1.3),
        ),
      ),
    );
  }

  Widget _whoCard(SubjectProfile subj) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnaemiaUi.iconTile(
            Icons.how_to_reg_rounded,
            MirrorColors.successFg,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Who this is for',
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.kind == MovementTestKind.gait ||
                          p.kind == MovementTestKind.sitToStand
                      ? 'Adults. The cut-off lines are for older adults. Stop if you feel unsteady or need your arms to stand up.'
                      : 'Anyone who can follow the voice instructions. Age-based norms are still being collected.',
                  style: const TextStyle(
                    color: AnaemiaUi.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Three pictures with a few words each, then one plain sentence.
  Widget _whatYouDoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < p.whatYouDo.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, c) => MovementIllustrationView(
                          kind: p.whatYouDo[i].illustration,
                          size: c.maxWidth,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${i + 1}. ${p.whatYouDo[i].caption}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AnaemiaUi.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.purpose,
            style: const TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Codes, reference rows and release status, collapsed by default.
  Widget _detailsExpander() {
    return Material(
      color: AnaemiaUi.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AnaemiaUi.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: AnaemiaUi.iconTile(
            Icons.biotech_outlined,
            AnaemiaUi.muted,
            size: 36,
          ),
          title: const Text(
            'Details for clinicians',
            style: TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${p.algorithmId} · what is measured, reference lines, release status',
            style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final m in p.measures)
                    AnaemiaUi.bullet(m, icon: Icons.analytics_outlined),
                ],
              ),
            ),
            const Divider(height: 18),
            for (final r in p.referenceRows)
              AnaemiaUi.kvRow(
                r.provenance == 'DER' ? '${r.label} [DER]' : r.label,
                r.value,
              ),
            const SizedBox(height: 6),
            InfoNote(text: p.referenceNote),
            const Divider(height: 18),
            AnaemiaUi.kvRow('Card', '${p.algorithmId} ${p.algorithmVersion}'),
            AnaemiaUi.kvRow('Inputs', p.sensorSummary),
            AnaemiaUi.kvRow(
              'Processing',
              'On-device signal processing (Spec §9)',
            ),
            AnaemiaUi.kvRow(
              'Release',
              'In clinical validation (G-24) — study MOV-PD-01',
            ),
            AnaemiaUi.kvRow('Range version', p.rangeVersion),
            AnaemiaUi.kvRow('Gates', _gateCodes),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                const BandChip(
                  band: SemanticBand.inValidation,
                  compact: true,
                  customLabel: 'In clinical validation',
                ),
                AnaemiaUi.tag(
                  'Feeds ${p.conditionCode}',
                  color: MirrorColors.infoFg,
                  icon: Icons.account_tree_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _gateCodes => p.requiredGates
      .map((g) => g.name.toUpperCase().replaceFirst('G', 'G-'))
      .join(', ');

  /// Plain-words name for a gate, with the code kept small.
  static String _gatePlain(GateId g) => switch (g) {
    GateId.g04 => 'Screening consent signed',
    GateId.g11 => 'Camera allowed',
    GateId.g13 => 'Motion sensors found',
    GateId.g21 => 'Hand can be seen in the frame',
    _ => g.name.toUpperCase().replaceFirst('G', 'G-'),
  };

  Widget _needsCard() {
    return Row(
      children: [
        for (var i = 0; i < p.needs.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: AnaemiaUi.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MovementIllustrationView(
                    kind: p.needs[i].illustration,
                    size: 80,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.needs[i].title,
                    style: const TextStyle(
                      color: AnaemiaUi.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.needs[i].sub,
                    style: const TextStyle(
                      color: AnaemiaUi.muted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _gatesCard(BuildContext context, List<GateCheckOutcome> outcomes) {
    final motionText = switch (_motion) {
      null => p.usesMotion ? 'Checking motion sensors…' : null,
      MotionAvailability.available => 'Accelerometer and gyroscope responding',
      MotionAvailability.simulated =>
        'Simulated sensors (desktop / test build)',
      MotionAvailability.unavailable =>
        'Motion sensors unavailable on this device',
    };
    return Column(
      children: [
        for (final o in outcomes) ...[
          if (!o.passed && !o.isAdvisoryOnly)
            GateBlockerCard(
              outcome: o,
              onFixPressed: o.gate == GateId.g13 ? _probeMotion : null,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: AnaemiaUi.card(),
              child: Row(
                children: [
                  Icon(
                    o.passed
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: o.passed
                        ? MirrorColors.successFg
                        : MirrorColors.infoFg,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_gatePlain(o.gate)} · ${o.gate.name.toUpperCase().replaceFirst('G', 'G-')}',
                          style: const TextStyle(
                            color: AnaemiaUi.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          o.gate == GateId.g13 && motionText != null
                              ? motionText
                              : o.reason,
                          style: const TextStyle(
                            color: AnaemiaUi.muted,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (outcomes.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AnaemiaUi.card(),
            child: const Text(
              'No gates apply.',
              style: TextStyle(color: AnaemiaUi.muted),
            ),
          ),
      ],
    );
  }
}
