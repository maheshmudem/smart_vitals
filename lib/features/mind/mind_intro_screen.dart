import 'package:flutter/material.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/mind_engines.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/member_profile.dart';
import '../../core/domain/entities/mind_protocol.dart';
import '../../core/domain/entities/screening_catalogue_item.dart';
import '../../core/domain/gates/gate_evaluator.dart';
import '../../core/services/emergency_contacts.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import 'mind_capture_screen.dart';
import 'mind_illustrations.dart';

/// Intro for a Brain & Mind check (S-G12 / S-G13 / S-G15 / S-H06): who,
/// consent (G-04), what you will do, what you need, gates in plain words,
/// clinician details collapsed, then "Ready". The stroke check shows the
/// emergency bar and is never blocked.
class MindIntroScreen extends StatefulWidget {
  const MindIntroScreen({super.key, required this.protocol});

  final MindProtocol protocol;

  @override
  State<MindIntroScreen> createState() => _MindIntroScreenState();
}

class _MindIntroScreenState extends State<MindIntroScreen> {
  MindProtocol get p => widget.protocol;

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
    // G-17 / G-18 are checked live on the Prepare step; G-37 is the safety
    // override (never a blocker); G-28 / G-34 are status, not blockers.
    final shown = [
      for (final o in outcomes)
        if (o.gate == GateId.g17 ||
            o.gate == GateId.g18 ||
            o.gate == GateId.g37 ||
            o.gate == GateId.g28 ||
            o.gate == GateId.g34)
          GateCheckOutcome(
            gate: o.gate,
            passed: o.passed,
            isAdvisoryOnly: true,
            reason: switch (o.gate) {
              GateId.g18 =>
                'A fresh 3 s room check runs before the test (limit 45 dBA).',
              GateId.g17 =>
                o.passed
                    ? 'Microphone self-check passed (ALG-CAP-11).'
                    : 'Microphone self-check not run yet — advisory; open Audio Readiness (S-G01) to run it.',
              GateId.g37 =>
                'Safety override: a positive sign or a crisis answer opens the emergency / support screen before anything else.',
              GateId.g28 => o.reason,
              _ => o.reason,
            },
          )
        else
          o,
    ];
    final blockers = p.safetyCritical
        ? const <GateCheckOutcome>[]
        : shown.where((o) => !o.passed && !o.isAdvisoryOnly).toList();
    final String? helper = p.safetyCritical
        ? null
        : !consent
        ? 'Sign the screening consent above to continue (G-04)'
        : blockers.isNotEmpty
        ? blockers.first.reason
        : null;
    final language = appState.speechLanguages[subj.id] ?? p.languages.first;

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
        bottom: p.safetyCritical ? _emergencyBar() : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _subjectCard(context, appState, subj, consent),
            const SizedBox(height: 10),
            if (!consent && !p.safetyCritical) ...[
              _consentCard(appState, subj),
              const SizedBox(height: 10),
            ],
            if (p.kind == MindKind.hfVoice) ...[
              _hfStatusCard(appState, subj),
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
              p.safetyCritical
                  ? 'No gate blocks this check (safety)'
                  : 'Green items are ready; grey ones are checked on the next step',
            ),
            _gatesCard(shown),
            const SizedBox(height: 12),
            _detailsExpander(),
            const SizedBox(height: 12),
            const DisclaimerFooter(),
          ],
        ),
      ),
      bottomNavigationBar: PrimaryBottomButton(
        label: p.safetyCritical ? 'Start the check' : 'Ready',
        icon: Icons.arrow_forward_rounded,
        helper: helper,
        onPressed: helper != null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      MindCaptureScreen(protocol: p, language: language),
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _emergencyBar() => PreferredSize(
    preferredSize: const Size.fromHeight(44),
    child: Container(
      color: const Color(0xFFDC2626),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Suspect a stroke? Call first, check second.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('mind_intro_call'),
            onPressed: () => EmergencyContacts.dial('108'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFDC2626),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text(
              'Call 108',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _hfStatusCard(AppState appState, SubjectProfile subj) {
    final samples = appState.hfSamplesFor(subj.id);
    final baselineDays = samples.where((s) => s.deviation == null).length;
    final building = baselineDays < HfBaseline.baselineDays;
    final doneToday = appState.hfCheckDoneToday(subj.id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Row(
        children: [
          AnaemiaUi.iconTile(
            doneToday ? Icons.task_alt_rounded : Icons.today_rounded,
            doneToday ? MirrorColors.successFg : AnaemiaUi.primary,
            size: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  building
                      ? 'Day ${baselineDays + 1} of ${HfBaseline.baselineDays} — building your baseline (G-28)'
                      : 'Baseline complete — comparing each day (G-28)',
                  style: const TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  doneToday
                      ? 'Completed today (G-34)'
                      : 'Due today (G-34 daily reminder)',
                  style: TextStyle(
                    color: doneToday ? MirrorColors.successFg : AnaemiaUi.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
              if (!p.safetyCritical)
                AnaemiaUi.tag(
                  consent
                      ? 'Screening consent signed'
                      : 'Consent needed (G-04)',
                  color: consent
                      ? MirrorColors.successFg
                      : MirrorColors.warningFg,
                  icon: consent
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                ),
              AnaemiaUi.tag(
                p.durationLabel,
                color: MirrorColors.infoFg,
                icon: Icons.timer_outlined,
              ),
              if (p.kind == MindKind.cognitive)
                AnaemiaUi.tag(
                  subj.ageYears >= 50
                      ? 'Age ${subj.ageYears} · eligible (≥ 50)'
                      : 'Age ${subj.ageYears} · offered from 50 (G-09)',
                  color: subj.ageYears >= 50
                      ? MirrorColors.successFg
                      : MirrorColors.warningFg,
                  icon: Icons.cake_outlined,
                ),
              if (p.kind == MindKind.mood)
                AnaemiaUi.tag(
                  subj.hasConsent(ConsentType.clinicianMoodPathway)
                      ? 'Clinician pathway active'
                      : 'Clinician pathway only (G-07)',
                  color: subj.hasConsent(ConsentType.clinicianMoodPathway)
                      ? MirrorColors.successFg
                      : MirrorColors.warningFg,
                  icon: Icons.medical_services_outlined,
                ),
              if (p.safetyCritical)
                AnaemiaUi.tag(
                  'Never blocked · safety',
                  color: MirrorColors.infoFg,
                  icon: Icons.health_and_safety_outlined,
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
                    key: ValueKey('mind_subject_${appState.subjects[i].id}'),
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

  Widget _consentCard(AppState appState, SubjectProfile subj) => MaterialCard(
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
        'Answers and recordings stay on this device for screening only (G-04).',
        style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5, height: 1.3),
      ),
    ),
  );

  Widget _whatYouDoCard() => Container(
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
                      builder: (context, c) =>
                          p.whatYouDo[i].illustration ==
                              MindIllustration.parkScene
                          ? ParkSceneView(width: c.maxWidth)
                          : MindIllustrationView(
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

  Widget _needsCard() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
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
                MindIllustrationView(kind: p.needs[i].illustration, size: 80),
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

  Widget _whoCard(SubjectProfile subj) => Container(
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
                switch (p.kind) {
                  MindKind.cognitive =>
                    'Adults aged 50 and over who can speak into the phone in English, Hindi or Telugu. Not during an acute illness, delirium or a recent change of sedating medicine (the clinic pairing rule).',
                  MindKind.mood =>
                    'Members whose clinician has activated the mood pathway. Answers are private to you and that clinician. If you are in immediate danger, call 112 now.',
                  MindKind.hfVoice =>
                    'Patients enrolled in the heart-failure programme, once a day, ideally the same time each morning. It supports, never replaces, daily weights and your symptom diary.',
                  MindKind.stroke =>
                    'Anyone — member, family member on their behalf, or an operator. If the person cannot smile, lift an arm or speak, call emergency services instead of running the check.',
                },
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

  static String _gatePlain(GateId g) => switch (g) {
    GateId.g04 => 'Screening consent signed',
    GateId.g07 => 'Clinician pathway active',
    GateId.g08 => 'Enrolled in the heart-failure programme',
    GateId.g09 => 'Age 50 or over',
    GateId.g11 => 'Camera allowed',
    GateId.g12 => 'Microphone allowed',
    GateId.g17 => 'Microphone self-check',
    GateId.g18 => 'Room quiet enough',
    GateId.g28 => '14-day voice baseline',
    GateId.g34 => 'Daily schedule',
    GateId.g37 => 'Safety override',
    _ => g.name.toUpperCase().replaceFirst('G', 'G-'),
  };

  Widget _gatesCard(List<GateCheckOutcome> outcomes) => Column(
    children: [
      for (final o in outcomes) ...[
        if (!o.passed && !o.isAdvisoryOnly && !p.safetyCritical)
          GateBlockerCard(outcome: o)
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
                        o.reason,
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
            'No gates apply — this check is always available.',
            style: TextStyle(color: AnaemiaUi.muted),
          ),
        ),
    ],
  );

  Widget _detailsExpander() => Material(
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
          '${p.algorithmLabel} · what is measured, reference lines, release status',
          style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in p.measures)
                AnaemiaUi.bullet(m, icon: Icons.analytics_outlined),
            ],
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
          AnaemiaUi.kvRow('Card', '${p.algorithmLabel} ${p.algorithmVersion}'),
          AnaemiaUi.kvRow('Inputs', p.sensorSummary),
          AnaemiaUi.kvRow('Processing', 'On-device'),
          AnaemiaUi.kvRow('Release', 'In clinical validation (G-24)'),
          AnaemiaUi.kvRow('Range version', p.rangeVersion),
          AnaemiaUi.kvRow(
            'Gates',
            p.requiredGates
                .map((g) => g.name.toUpperCase().replaceFirst('G', 'G-'))
                .join(', '),
          ),
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
