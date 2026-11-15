import 'package:flutter/material.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/entities/anaemia_result.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/member_profile.dart';
import '../../core/state/app_state.dart';
import 'anaemia_illustrations.dart';
import 'anaemia_stepper_screen.dart';
import 'anaemia_ui_kit.dart';

/// S-E01 — Anaemia (lower eyelid) intro: who is being screened, what the
/// screen reads (haemoglobin band from eyelid colour, WHO cut-offs), what
/// goes in / comes out, who checks it, and the algorithm card (ALG-IMG-01).
class AnaemiaIntroScreen extends StatelessWidget {
  const AnaemiaIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final subj = appState.activeSubject;
    final thr = AnaemiaWhoThreshold.forSubject(
      ageYears: subj.ageYears,
      sex: subj.sex,
      isPregnant: subj.isPregnant,
    );
    final consent = subj.hasConsent(ConsentType.screening);

    return Scaffold(
      backgroundColor: MirrorColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Anaemia screening'),
        actions: [
          IconButton(
            tooltip: 'Screen spec & gates (S-E01)',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-E01'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _subjectCard(context, appState, subj, thr),
          if (!consent) ...[
            const SizedBox(height: 10),
            _consentCard(appState, subj),
          ],
          const SizedBox(height: 20),
          AnaemiaUi.sectionHeader(
            'Haemoglobin band from lower-eyelid colour',
            'What this screen reads and the ranges it uses',
          ),
          _bandCard(thr),
          const SizedBox(height: 12),
          _inputsOutputsCard(),
          const SizedBox(height: 20),
          AnaemiaUi.sectionHeader(
            'Algorithm',
            'How the app turns a photo into a result',
          ),
          _algorithmCard(),
          const SizedBox(height: 20),
          AnaemiaUi.sectionHeader('You will need', 'About 2 minutes in total'),
          _needsCard(),
          const SizedBox(height: 12),
          const DisclaimerFooter(),
        ],
      ),
      bottomNavigationBar: PrimaryBottomButton(
        label: 'Ready',
        helper: consent
            ? 'Next: one quick question, then 4 flash photos of the lower eyelids'
            : 'Tick the screening consent above to continue (G-04)',
        onPressed: !consent
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AnaemiaStepperScreen(),
                  ),
                );
              },
      ),
    );
  }

  // --- Subject -----------------------------------------------------------

  Widget _subjectCard(
    BuildContext context,
    AppState appState,
    SubjectProfile subj,
    AnaemiaWhoThreshold thr,
  ) {
    final initials = subj.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((p) => p.isEmpty ? '' : p[0].toUpperCase())
        .join();
    final meta = [
      '${subj.ageYears} y',
      subj.sex.label,
      if (subj.isPregnant)
        'Pregnant${subj.pregnancyWeeks != null ? ' ${subj.pregnancyWeeks} wk' : ''}',
    ].join(' · ');
    final consent = subj.hasConsent(ConsentType.screening);

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
                  color: AnaemiaUi.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AnaemiaUi.accent,
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
                      'Screening for',
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
                      meta,
                      maxLines: 2,
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
                '${thr.groupLabel}: cut-off ${thr.cutoffGdL.toStringAsFixed(1)} g/dL',
                color: AnaemiaUi.accent,
                icon: Icons.bloodtype_rounded,
              ),
              AnaemiaUi.tag(
                subj.relationship,
                color: AnaemiaUi.muted,
                icon: Icons.person_rounded,
              ),
            ],
          ),
        ],
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
          'Photos stay on this device for screening only (G-04). A guardian ticks this for a child.',
          style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5, height: 1.3),
        ),
      ),
    );
  }

  void _showSubjectPicker(BuildContext context, AppState appState) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Who is being screened?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AnaemiaUi.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The haemoglobin cut-off depends on age, sex and pregnancy.',
                  style: TextStyle(fontSize: 12, color: AnaemiaUi.muted),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < appState.subjects.length; i++)
                  _subjectOption(ctx, appState, i),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _subjectOption(BuildContext ctx, AppState appState, int index) {
    final s = appState.subjects[index];
    final selected = index == appState.activeSubjectIndex;
    final thr = AnaemiaWhoThreshold.forSubject(
      ageYears: s.ageYears,
      sex: s.sex,
      isPregnant: s.isPregnant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('subject_option_${s.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          appState.selectSubject(index);
          Navigator.of(ctx).pop();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AnaemiaUi.primary.withValues(alpha: 0.08)
                : AnaemiaUi.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AnaemiaUi.primary : AnaemiaUi.outline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AnaemiaUi.primary : AnaemiaUi.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AnaemiaUi.ink,
                      ),
                    ),
                    Text(
                      s.relationship,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AnaemiaUi.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnaemiaUi.tag(
                '< ${thr.cutoffGdL.toStringAsFixed(1)} g/dL',
                color: AnaemiaUi.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Band + WHO table --------------------------------------------------

  Widget _bandCard(AnaemiaWhoThreshold active) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(Icons.visibility_rounded, AnaemiaUi.accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inner lower eyelid colour',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Paler lining usually means less haemoglobin',
                      style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Colour strip pale → pink → red
          Container(
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFBE9EC),
                  Color(0xFFF4B2BD),
                  Color(0xFFE2687C),
                  Color(0xFFC2414F),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(child: _BandColumn('Pale', SemanticBand.high)),
              Expanded(
                child: _BandColumn('Light pink', SemanticBand.borderline),
              ),
              Expanded(child: _BandColumn('Pink-red', SemanticBand.normal)),
            ],
          ),
          const Divider(height: 26),
          const Text(
            'Normal haemoglobin (WHO cut-offs, g/dL)',
            style: TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in AnaemiaWhoThreshold.table)
            _whoRow(
              row,
              highlighted:
                  row.cutoffGdL == active.cutoffGdL &&
                  _sameGroup(row.groupLabel, active.groupLabel),
            ),
          const SizedBox(height: 6),
          const Text(
            'Below the cut-off = anaemia range (High band). Within 0.5 g/dL above it = Borderline. Your row is highlighted.',
            style: TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  bool _sameGroup(String tableLabel, String subjectLabel) {
    final t = tableLabel.toLowerCase();
    final s = subjectLabel.toLowerCase();
    if (s == 'man') return t.startsWith('men');
    if (s == 'non-pregnant woman') return t.startsWith('non-pregnant');
    if (s == 'pregnant woman') return t.startsWith('pregnant');
    if (s.contains('5–11')) return t.contains('5–11');
    return t.contains('6–59');
  }

  Widget _whoRow(AnaemiaWhoThreshold row, {required bool highlighted}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlighted
            ? AnaemiaUi.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted
              ? AnaemiaUi.accent.withValues(alpha: 0.5)
              : AnaemiaUi.outline,
        ),
      ),
      child: Row(
        children: [
          Icon(
            highlighted ? Icons.person_pin_circle_rounded : Icons.circle,
            size: highlighted ? 16 : 7,
            color: highlighted ? AnaemiaUi.accent : AnaemiaUi.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.groupLabel,
              style: TextStyle(
                color: AnaemiaUi.ink,
                fontSize: 12.5,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Normal ≥ ${row.cutoffGdL.toStringAsFixed(1)}',
            style: TextStyle(
              color: highlighted ? AnaemiaUi.accent : AnaemiaUi.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // --- Inputs / Outputs / Checked by --------------------------------------

  Widget _inputsOutputsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        children: [
          _ioRow(
            Icons.input_rounded,
            const Color(0xFF2563EB),
            'Inputs',
            '2 flash photos of each lower eyelid (4 total) · 24-patch colour card (preferred) · your age, sex and pregnancy status',
          ),
          const Divider(height: 18),
          _ioRow(
            Icons.output_rounded,
            const Color(0xFF059669),
            'Outputs',
            'Anaemia band (Normal / Borderline / High) with a confidence level and next steps. The numeric haemoglobin estimate stays internal until the model is validated.',
          ),
          const Divider(height: 18),
          _ioRow(
            Icons.fact_check_rounded,
            const Color(0xFF7C3AED),
            'Checked by',
            'On-device photo quality checks (sharpness, glare, light, framing, colour card) on every photo · a specialist reviewer for High or borderline results (IMG-10)',
          ),
        ],
      ),
    );
  }

  Widget _ioRow(IconData icon, Color color, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnaemiaUi.iconTile(icon, color, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AnaemiaUi.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
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
    );
  }

  // --- Algorithm ---------------------------------------------------------

  Widget _algorithmCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(Icons.memory_rounded, AnaemiaUi.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eyelid colour CNN',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'ALG-IMG-01 · conjunctiva segmentation + colour features',
                      style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              BandChip(
                band: SemanticBand.inValidation,
                compact: true,
                customLabel: 'In clinical validation',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The app looks at the colour of the inner surface of your lower eyelid in two flash photos per eye. '
            'A model turns that colour into a haemoglobin estimate and an anaemia risk band for your age, sex and pregnancy status.',
            style: TextStyle(color: AnaemiaUi.ink, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(
                child: _MiniStep(
                  Icons.photo_camera_rounded,
                  'Photo',
                  'flash on',
                ),
              ),
              _StepArrow(),
              Expanded(
                child: _MiniStep(
                  Icons.palette_rounded,
                  'Colour fix',
                  'card or flash',
                ),
              ),
              _StepArrow(),
              Expanded(
                child: _MiniStep(
                  Icons.memory_rounded,
                  'Model',
                  'eyelid colour',
                ),
              ),
              _StepArrow(),
              Expanded(
                child: _MiniStep(Icons.rule_rounded, 'WHO band', 'for you'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const InfoNote(
            icon: Icons.health_and_safety_outlined,
            text:
                'Screening, not diagnosis. A High or Borderline band is a prompt for a blood test (CBC), not a confirmed result.',
          ),
        ],
      ),
    );
  }

  Widget _needsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                child: _NeedTile(
                  EyelidIllustration.phoneDistanceFlash,
                  'Flash on',
                  'rear camera',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _NeedTile(
                  EyelidIllustration.colourCardBesideEye,
                  'Colour card',
                  'preferred',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _NeedTile(
                  EyelidIllustration.pullLidDown,
                  'Clean finger',
                  'to pull the lid',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'A helper can hold the phone for children or if you find it hard to pull the lid and tap at the same time.',
            style: TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BandColumn extends StatelessWidget {
  const _BandColumn(this.colourLabel, this.band);

  final String colourLabel;
  final SemanticBand band;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          colourLabel,
          style: const TextStyle(
            color: AnaemiaUi.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        BandChip(band: band, compact: true),
      ],
    );
  }
}

class _MiniStep extends StatelessWidget {
  const _MiniStep(this.icon, this.title, this.sub);

  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnaemiaUi.iconTile(icon, AnaemiaUi.primary, size: 34),
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AnaemiaUi.ink,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AnaemiaUi.muted, fontSize: 9.5),
        ),
      ],
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 22),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 16,
        color: AnaemiaUi.muted,
      ),
    );
  }
}

class _NeedTile extends StatelessWidget {
  const _NeedTile(this.kind, this.title, this.sub);

  final EyelidIllustration kind;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) =>
              EyelidIllustrationView(kind: kind, size: c.maxWidth),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AnaemiaUi.ink,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AnaemiaUi.muted, fontSize: 10),
        ),
      ],
    );
  }
}
