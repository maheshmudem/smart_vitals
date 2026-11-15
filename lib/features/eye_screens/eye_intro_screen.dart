import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/neonatal_bilirubin_chart.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/eye_photo_protocol.dart';
import '../../core/domain/entities/member_profile.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import 'eye_illustrations.dart';
import 'eye_stepper_screen.dart';

/// S-E01 / S-E06 intro for one [EyeProtocol]: who is screened, what the photo
/// reads, inputs / outputs / checked-by, the algorithm card, what you need,
/// then **Ready**.
class EyeIntroScreen extends StatelessWidget {
  const EyeIntroScreen({super.key, required this.protocol});

  final EyeProtocol protocol;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final subj = appState.activeSubject;
    final consent = subj.hasConsent(protocol.consentType);
    final ageBlock = protocol.ageBlockReasonFor(subj);
    final hardBlock = ageBlock != null && !protocol.allowOnRequest;
    final deviceOk =
        !protocol.requiresFundusCamera ||
        appState.deviceProfile.fundusCameraConnected;
    final p = protocol;

    final String? helper;
    if (!consent) {
      helper =
          'Tick the ${p.consentType == ConsentType.dentalGuardian ? 'dental' : 'screening'} consent above to continue (${p.consentType.gateCode})';
    } else if (hardBlock) {
      helper = ageBlock;
    } else if (ageBlock != null) {
      helper = 'Under ${p.minAgeYears} — continue "on request" (G-09)';
    } else if (!deviceOk) {
      helper = 'Connect the clip-on fundus camera in the next step (G-31)';
    } else {
      helper = p.nextHelper;
    }

    return Scaffold(
      backgroundColor: MirrorColors.backgroundLight,
      appBar: AppBar(
        title: Text(p.title),
        actions: [
          IconButton(
            tooltip: 'Screen spec & gates (${p.introScreenId})',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () =>
                showScreenGateLifecycleSheet(context, p.introScreenId),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _subjectCard(context, appState, subj),
          if (!consent) ...[
            const SizedBox(height: 10),
            _consentCard(appState, subj),
          ],
          if (p.newbornOnly && subj.isNewborn) ...[
            const SizedBox(height: 10),
            _BabyDetailsCard(appState: appState, subject: subj),
          ],
          const SizedBox(height: 10),
          _eligibilityCard(subj, ageBlock),
          const SizedBox(height: 20),
          AnaemiaUi.sectionHeader(
            'What this screen reads',
            'And the scale it uses',
          ),
          _readsCard(),
          const SizedBox(height: 12),
          _inputsOutputsCard(),
          const SizedBox(height: 20),
          AnaemiaUi.sectionHeader(
            'Algorithm',
            'How the app turns the photos into a result',
          ),
          _algorithmCard(),
          const SizedBox(height: 20),
          AnaemiaUi.sectionHeader(
            'You will need',
            'About ${p.durationLabel.replaceAll('~', '')} in total',
          ),
          _needsCard(),
          const SizedBox(height: 12),
          const DisclaimerFooter(),
        ],
      ),
      bottomNavigationBar: PrimaryBottomButton(
        label: ageBlock != null && !hardBlock ? 'Request anyway' : 'Ready',
        icon: ageBlock != null && !hardBlock
            ? Icons.front_hand_rounded
            : Icons.arrow_forward_rounded,
        helper: helper,
        onPressed: (!consent || hardBlock)
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EyeStepperScreen(
                      protocol: p,
                      onRequest: ageBlock != null,
                    ),
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
  ) {
    final initials = subj.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((s) => s.isEmpty ? '' : s[0].toUpperCase())
        .join();
    final meta = [
      if (subj.isNewborn)
        '${subj.ageHoursForNewborn} h old · ${subj.gestationWeeksForNewborn ?? '?'} w${subj.weightKg != null ? ' · ${subj.weightKg!.toStringAsFixed(1)} kg' : ''}'
      else
        '${subj.ageYears} y',
      subj.sex.label,
      if (subj.isPregnant) 'Pregnant',
      if (subj.hasKnownDiabetes) 'Diabetes',
      if (subj.usesTobaccoOrAreca) 'Tobacco / areca',
    ].join(' · ');
    final consent = subj.hasConsent(protocol.consentType);
    final guardian = protocol.guardianRequiredFor(subj);
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
                consent
                    ? '${protocol.consentType == ConsentType.dentalGuardian ? 'Dental' : 'Screening'} consent signed'
                    : 'Consent needed (${protocol.consentType.gateCode})',
                color: consent
                    ? MirrorColors.successFg
                    : MirrorColors.warningFg,
                icon: consent
                    ? Icons.verified_rounded
                    : Icons.warning_amber_rounded,
              ),
              if (guardian)
                AnaemiaUi.tag(
                  protocol.newbornOnly
                      ? 'Guardian consent · parent or operator'
                      : protocol.consentType == ConsentType.dentalGuardian
                      ? 'Child mode · guardian holds the phone (G-05)'
                      : 'Guardian consent & helper',
                  color: AnaemiaUi.accent,
                  icon: Icons.family_restroom_rounded,
                ),
              if (protocol.id == 'dental_caries')
                AnaemiaUi.tag(
                  subj.ageYears <= 5
                      ? 'Primary teeth (51–85)'
                      : subj.ageYears <= 12
                      ? 'Mixed teeth (51–85 + first molars)'
                      : 'Permanent teeth (11–48)',
                  color: MirrorColors.infoFg,
                  icon: Icons.grid_view_rounded,
                ),
              if ((protocol.id == 'body_foot' && subj.hasKnownDiabetes) ||
                  (protocol.id == 'dental_oral' && subj.usesTobaccoOrAreca))
                AnaemiaUi.tag(
                  'Recommended for you (G-10)',
                  color: MirrorColors.successFg,
                  icon: Icons.recommend_rounded,
                ),
              if (protocol.recheckLabel != null)
                AnaemiaUi.tag(
                  protocol.recheckLabel!,
                  color: MirrorColors.infoFg,
                  icon: Icons.event_repeat_rounded,
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
            appState.toggleConsent(protocol.consentType, v ?? false),
        title: Text(
          protocol.guardianRequiredFor(subj)
              ? 'I am the parent / guardian and consent to ${protocol.consentType == ConsentType.dentalGuardian ? 'the dental screening of' : 'screening'} ${subj.fullName}'
              : protocol.consentType == ConsentType.dentalGuardian
              ? 'I consent to dental screening for ${subj.fullName} (G-05)'
              : 'I consent to screening for ${subj.fullName}',
          style: const TextStyle(
            color: AnaemiaUi.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          protocol.partnerModel
              ? 'Photos stay on this device; de-identified retina images are shared with the licensed partner AI only after you agree in the next step (G-04).'
              : 'Photos stay on this device for screening only (G-04).',
          style: const TextStyle(
            color: AnaemiaUi.muted,
            fontSize: 11.5,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _eligibilityCard(SubjectProfile subj, String? ageBlock) {
    final p = protocol;
    final ok = ageBlock == null;
    final color = ok
        ? MirrorColors.successFg
        : p.allowOnRequest
        ? MirrorColors.warningFg
        : MirrorColors.dangerFg;
    final who = p.whoText;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnaemiaUi.iconTile(
            ok ? Icons.how_to_reg_rounded : Icons.rule_rounded,
            color,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Who this screen is for',
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnaemiaUi.tag(p.eligibilityLabel(), color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  who,
                  style: const TextStyle(
                    color: AnaemiaUi.muted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                if (ageBlock != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${subj.fullName} is ${subj.isNewborn ? '${subj.ageHoursForNewborn} hours old' : subj.ageYears}. $ageBlock',
                    style: TextStyle(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
                Text(
                  '${protocol.title}: ${protocol.eligibilityLabel().toLowerCase()}.',
                  style: const TextStyle(fontSize: 12, color: AnaemiaUi.muted),
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
    final block = protocol.ageBlockReasonFor(s);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('eye_subject_option_${s.id}'),
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
                block == null
                    ? 'Eligible'
                    : protocol.allowOnRequest
                    ? 'On request'
                    : 'Not eligible',
                color: block == null
                    ? MirrorColors.successFg
                    : protocol.allowOnRequest
                    ? MirrorColors.warningFg
                    : MirrorColors.dangerFg,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- What this reads -----------------------------------------------------

  Widget _readsCard() {
    final p = protocol;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(resultIconFor(p), AnaemiaUi.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.readsTitle,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      p.readsCaption,
                      style: const TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AnaemiaUi.outline),
              gradient: LinearGradient(
                colors: [for (final c in p.scale.gradient) Color(c)],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < p.scale.labels.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        p.scale.labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          color: AnaemiaUi.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      BandChip(band: p.scale.bands[i], compact: true),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 26),
          Text(
            p.referenceTitle,
            style: const TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in p.referenceRows) _refRow(row.$1, row.$2),
          const SizedBox(height: 6),
          Text(
            p.referenceNote,
            style: const TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _refRow(String k, String v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AnaemiaUi.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 7, color: AnaemiaUi.muted),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              k,
              style: const TextStyle(
                color: AnaemiaUi.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AnaemiaUi.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Inputs / Outputs / Checked by ----------------------------------------

  Widget _inputsOutputsCard() {
    final p = protocol;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        children: [
          _ioRow(
            Icons.input_rounded,
            const Color(0xFF2563EB),
            'Inputs',
            p.inputsText,
          ),
          const Divider(height: 18),
          _ioRow(
            Icons.output_rounded,
            const Color(0xFF059669),
            'Outputs',
            p.outputsText,
          ),
          const Divider(height: 18),
          _ioRow(
            Icons.fact_check_rounded,
            const Color(0xFF7C3AED),
            'Checked by',
            p.checkedByText,
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
    final p = protocol;
    const icons = [
      Icons.photo_camera_rounded,
      Icons.palette_rounded,
      Icons.memory_rounded,
      Icons.rule_rounded,
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(
                p.partnerModel ? Icons.handshake_rounded : Icons.memory_rounded,
                AnaemiaUi.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.algorithmName,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      p.algorithmSubtitle,
                      style: const TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (p.partnerModel)
                AnaemiaUi.tag(
                  'Licensed partner AI · displayed as given',
                  color: MirrorColors.infoFg,
                  icon: Icons.verified_user_rounded,
                )
              else
                const BandChip(
                  band: SemanticBand.inValidation,
                  compact: true,
                  customLabel: 'In clinical validation',
                ),
              AnaemiaUi.tag(
                '${p.algorithmId} · ${p.algorithmVersion}',
                color: AnaemiaUi.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.plainMessage,
            style: const TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < p.miniSteps.length; i++) ...[
                Expanded(
                  child: _MiniStep(
                    icons[i % icons.length],
                    p.miniSteps[i].$1,
                    p.miniSteps[i].$2,
                  ),
                ),
                if (i != p.miniSteps.length - 1) const _StepArrow(),
              ],
            ],
          ),
          const SizedBox(height: 12),
          InfoNote(
            icon: Icons.health_and_safety_outlined,
            text: p.disclaimerText,
          ),
        ],
      ),
    );
  }

  Widget _needsCard() {
    final p = protocol;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < p.needs.length; i++) ...[
                Expanded(child: _NeedTile(p.needs[i])),
                if (i != p.needs.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p.helperIntroText,
            style: const TextStyle(
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

/// Icon for the protocol's body part (intro reads-card and result card).
IconData resultIconFor(EyeProtocol p) => switch (p.resultIcon) {
  'baby' => Icons.child_care_rounded,
  'foot' => Icons.healing_rounded,
  'skin' => Icons.texture_rounded,
  'mouth' => Icons.medical_services_rounded,
  'tooth' => Icons.sentiment_satisfied_alt_rounded,
  _ => Icons.visibility_rounded,
};

/// Newborn jaundice: editable age in hours, gestation and birth weight
/// (S-B06 fields the profile screens do not expose yet), with the resulting
/// phototherapy line shown live.
class _BabyDetailsCard extends StatefulWidget {
  const _BabyDetailsCard({required this.appState, required this.subject});

  final AppState appState;
  final SubjectProfile subject;

  @override
  State<_BabyDetailsCard> createState() => _BabyDetailsCardState();
}

class _BabyDetailsCardState extends State<_BabyDetailsCard> {
  late final TextEditingController _hours = TextEditingController(
    text: (widget.subject.ageHoursForNewborn ?? 0).toString(),
  );
  late final TextEditingController _weeks = TextEditingController(
    text: (widget.subject.gestationWeeksForNewborn ?? 38).toString(),
  );
  late final TextEditingController _weight = TextEditingController(
    text: widget.subject.weightKg?.toStringAsFixed(1) ?? '',
  );

  @override
  void dispose() {
    _hours.dispose();
    _weeks.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _save() {
    final hours = int.tryParse(_hours.text.trim());
    final weeks = int.tryParse(_weeks.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    if (hours == null || hours < 0 || hours > 672) return;
    if (weeks == null || weeks < 22 || weeks > 42) return;
    widget.appState.updateActiveSubject(
      widget.subject.copyWith(
        ageHoursForNewborn: hours,
        gestationWeeksForNewborn: weeks,
        weightKg: weight ?? widget.subject.weightKg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours = int.tryParse(_hours.text.trim()) ?? 0;
    final weeks = int.tryParse(_weeks.text.trim()) ?? 0;
    final thr = NeonatalBilirubinChart.phototherapyThreshold(
      gestationWeeks: weeks,
      ageHours: hours,
      hasRiskFactors: false,
    );
    final line = thr == null
        ? (weeks < 35
              ? 'Under 35 weeks — chart not validated; clinic TcB / serum'
              : hours > 672
              ? 'Over 28 days — newborn chart no longer applies'
              : 'Enter hours (0–672) and weeks (22–42)')
        : 'Phototherapy line (no risk factors): ${thr.toStringAsFixed(1)} mg/dL at $hours h, ${NeonatalBilirubinChart.bucketLabel(weeks)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(Icons.child_care_rounded, AnaemiaUi.accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Baby details',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'The treatment line depends on age in hours and weeks of gestation (S-B06)',
                      style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hours,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(_save),
                  style: const TextStyle(fontSize: 14, color: AnaemiaUi.ink),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Age (hours)',
                    helperText: '0–672',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _weeks,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(_save),
                  style: const TextStyle(fontSize: 14, color: AnaemiaUi.ink),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Gestation (weeks)',
                    helperText: '22–42',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(_save),
                  style: const TextStyle(fontSize: 14, color: AnaemiaUi.ink),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Weight (kg)',
                    helperText: 'birth',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InfoNote(
            icon: thr == null
                ? Icons.warning_amber_rounded
                : Icons.timeline_rounded,
            color: thr == null ? MirrorColors.warningFg : MirrorColors.infoFg,
            background: thr == null
                ? MirrorColors.warningBg
                : MirrorColors.infoBg,
            text: line,
          ),
        ],
      ),
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
  const _NeedTile(this.need);

  final EyeNeedTile need;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) =>
              EyeIllustrationView(kind: need.illustration, size: c.maxWidth),
        ),
        const SizedBox(height: 6),
        Text(
          need.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AnaemiaUi.ink,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          need.sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AnaemiaUi.muted, fontSize: 10),
        ),
      ],
    );
  }
}
