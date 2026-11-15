import 'package:flutter/material.dart';

import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/entities/anaemia_result.dart';
import '../../core/domain/entities/case_record.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import 'anaemia_illustrations.dart';
import 'anaemia_stepper_screen.dart';
import 'anaemia_ui_kit.dart';

/// S-R01 — Anaemia screening result (light theme, T-RES template).
///
/// Order: urgency banner → result card (band · confidence · what it means) →
/// your eyes (per-eye, [DER]) → haemoglobin band on the WHO scale → inputs
/// used → photo quality → how the result is made → how to read it → checked
/// by → next steps (§13) → quality & versions (expand) → disclaimer.
/// Save / Retake live in a sticky bottom bar.
class AnaemiaResultScreen extends StatefulWidget {
  const AnaemiaResultScreen({super.key, required this.result});

  final AnaemiaSessionResult result;

  @override
  State<AnaemiaResultScreen> createState() => _AnaemiaResultScreenState();
}

class _AnaemiaResultScreenState extends State<AnaemiaResultScreen> {
  static const double _gap = 20;
  bool _saved = false;
  VoiceCoachController? _voice;

  AnaemiaSessionResult get r => widget.result;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = AppStateScope.of(context).localeCode;
    _voice ??= VoiceCoachController(
      languageCode: switch (code) {
        'te' => 'te-IN',
        'hi' => 'hi-IN',
        _ => 'en-US',
      },
    );
  }

  @override
  void dispose() {
    _voice?.dispose();
    super.dispose();
  }

  void _readAloud() {
    _voice?.announce(
      'Anaemia result for ${r.subjectName}. $_bandHeadline. $_whatItMeans',
      tone: VoiceCueTone.completed,
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Scaffold(
      backgroundColor: MirrorColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Anaemia result'),
        actions: [
          IconButton(
            tooltip: 'Read aloud',
            icon: const Icon(Icons.record_voice_over_rounded),
            onPressed: _readAloud,
          ),
          IconButton(
            tooltip: 'Share report',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report exported to PDF summary.')),
            ),
          ),
          IconButton(
            tooltip: 'Screen spec & gates (S-R01)',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-R01'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _urgencyBanner(),
            _resultCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Algorithm outputs',
              'Every output marker of ALG-IMG-01 (Spec §6.1) with the value the model produced',
            ),
            AlgorithmOutputsSection(
              groups: MarkerReadings.fromAnaemia(r),
              showHeader: false,
            ),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Your eyes',
              'Two photos per eye · the band above combines both eyes',
            ),
            _eyesCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Haemoglobin band',
              'Where this result sits on the WHO scale for you',
            ),
            _hbBandCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Inputs used',
              'Everything the result was based on',
            ),
            _inputsCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Photo quality',
              'On-device checks for each photo (ALG-CAP-06…10)',
            ),
            _photoQualityCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'How this result is made',
              'Five steps, in order',
            ),
            _howMadeCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'How to read it',
              'What each band and the confidence level mean',
            ),
            _howToReadCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Checked by',
              'Automatic checks and human review',
            ),
            _checkedByCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Next steps',
              'Confirmatory tests from Spec §13',
            ),
            _nextStepsCard(),
            const SizedBox(height: _gap),
            _qualityVersionsExpander(),
            const SizedBox(height: 16),
            const DisclaimerFooter(),
          ],
        ),
      ),
      bottomNavigationBar: PrimaryBottomButton(
        label: _saved ? 'Saved' : 'Save to profile',
        icon: _saved ? Icons.check_rounded : Icons.save_alt_rounded,
        secondaryLabel: 'Retake',
        onSecondary: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const AnaemiaStepperScreen(initialStep: 1),
            ),
          );
        },
        onPressed: _saved
            ? null
            : () {
                appState.saveAnaemiaSession(r);
                setState(() => _saved = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Saved to profile and History.'),
                  ),
                );
              },
      ),
    );
  }

  // --- 1. Urgency ---------------------------------------------------------

  Widget _urgencyBanner() {
    if (r.urgency == UrgencyLevel.none) return const SizedBox.shrink();
    final pregnant = r.isPregnant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UrgencyBanner(
        urgency: r.urgency,
        title: pregnant && r.urgency == UrgencyLevel.urgent
            ? 'Possible anaemia in pregnancy'
            : 'Possible anaemia — book a blood test',
        subtitle: pregnant
            ? 'Rule T12 (BR-SCR-03): a High band during pregnancy needs a CBC within days, not weeks.'
            : 'Rule T15 (BR-SCR-04): routine confirmation with a CBC and ferritin.',
        ruleCodes: r.firedRuleCodes,
      ),
    );
  }

  // --- 2. Result card -----------------------------------------------------

  String get _cutoff => r.threshold.cutoffGdL.toStringAsFixed(1);
  String get _group => r.threshold.groupLabel.toLowerCase();

  String get _bandHeadline => switch (r.band) {
    SemanticBand.notAssessed => 'Not assessed',
    _ => '${r.band.label} band',
  };

  String get _bandSubline => switch (r.band) {
    SemanticBand.high => 'Haemoglobin likely below $_cutoff g/dL',
    SemanticBand.borderline => 'Close to the $_cutoff g/dL cut-off',
    SemanticBand.notAssessed => 'No usable photos — not a health result',
    _ => 'Haemoglobin likely at or above $_cutoff g/dL',
  };

  IconData get _bandIcon => switch (r.band) {
    SemanticBand.high => Icons.error_rounded,
    SemanticBand.borderline => Icons.warning_rounded,
    SemanticBand.notAssessed => Icons.help_rounded,
    _ => Icons.check_circle_rounded,
  };

  String get _whatItMeans => switch (r.band) {
    SemanticBand.high =>
      'The inner eyelid looks paler than expected for a $_group. '
          'This points to haemoglobin below $_cutoff g/dL and needs a blood test (CBC) to confirm.',
    SemanticBand.borderline =>
      'Eyelid colour is close to the cut-off for a $_group. '
          'A blood test (CBC) will tell for sure; repeat the screen in 2–4 weeks if you cannot test now.',
    SemanticBand.notAssessed =>
      'None of the eyelid photos passed the quality checks after 3 attempts, so no band was produced. '
          'Please retake in better light with the lid pulled well down.',
    _ =>
      'Eyelid colour is within the normal range for a $_group. '
          'No anaemia signal was found in this screen.',
  };

  Widget _resultCard() {
    final style = BandVisualStyle.forBand(r.band);
    final rec = r.recordedAt;
    final time =
        '${rec.day.toString().padLeft(2, '0')}/${rec.month.toString().padLeft(2, '0')}/${rec.year} · '
        '${rec.hour.toString().padLeft(2, '0')}:${rec.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(
                Icons.visibility_rounded,
                AnaemiaUi.accent,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Anaemia screen · lower eyelid',
                      style: TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      r.subjectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$time · ${r.durationSeconds} s · ${r.acceptedPhotoCount} of 4 photos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: style.foreground.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR RESULT',
                        style: TextStyle(
                          color: style.foreground.withValues(alpha: 0.8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bandHeadline,
                        style: TextStyle(
                          color: style.foreground,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _bandSubline,
                        style: TextStyle(
                          color: style.foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_bandIcon, color: style.foreground, size: 30),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConfidenceMeter(confidence: r.confidence),
              const BandChip(
                band: SemanticBand.inValidation,
                compact: true,
                customLabel: 'In clinical validation',
              ),
              if (r.specialistReviewRequired)
                AnaemiaUi.tag(
                  'Under specialist review',
                  color: MirrorColors.infoFg,
                  icon: Icons.how_to_reg_rounded,
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'What this means',
            style: TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _whatItMeans,
            style: const TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Your eyes -------------------------------------------------------

  Widget _eyesCard() {
    final anySimulated = r.photos.any((p) => p.quality.isSimulated);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eyeRow(EyeSide.left),
          const Divider(height: 22),
          _eyeRow(EyeSide.right),
          const SizedBox(height: 10),
          Text(
            'Pallor index: 0 = rich pink lining, 1 = very pale. The Spec reports one combined band per session; per-eye values are shown for transparency.'
            '${anySimulated ? ' Thumbnails are simulated — no camera in this build.' : ''}',
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

  Widget _eyeRow(EyeSide eye) {
    final summary = r.perEye.firstWhere((e) => e.eye == eye);
    final photos = r.photosFor(eye);
    final assessed = summary.band != SemanticBand.notAssessed;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 124,
          child: Row(
            children: [
              Expanded(child: _thumb(photos.isNotEmpty ? photos[0] : null)),
              const SizedBox(width: 4),
              Expanded(child: _thumb(photos.length > 1 ? photos[1] : null)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      eye.label,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  BandChip(band: summary.band, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              RangeGauge(
                scale: const RangeScale(
                  breakpoints: [0, 0.4, 0.6, 1.0],
                  labels: ['Pink', 'Borderline', 'Pale'],
                  colors: [
                    AnaemiaUi.segNormal,
                    AnaemiaUi.segBorder,
                    AnaemiaUi.segHigh,
                  ],
                ),
                value: summary.pallorIndex,
                pinColor: BandVisualStyle.forBand(summary.band).foreground,
                showPin: assessed,
              ),
              const SizedBox(height: 4),
              Text(
                assessed
                    ? 'Pallor index ${summary.pallorIndex.toStringAsFixed(2)} · ${summary.photosUsed} photo${summary.photosUsed == 1 ? '' : 's'} · a* ${summary.meanAStar.toStringAsFixed(1)}'
                    : 'Not assessed — photos failed the quality checks',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AnaemiaUi.muted,
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumb(EyelidPhoto? p) {
    final accepted = p?.accepted ?? false;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: AnaemiaUi.conjunctivaPale,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: p == null
                ? AnaemiaUi.outline
                : accepted
                ? MirrorColors.successFg.withValues(alpha: 0.5)
                : MirrorColors.dangerFg.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (p?.bytes != null)
              Image.memory(p!.bytes!, fit: BoxFit.cover)
            else
              FittedBox(
                fit: BoxFit.cover,
                child: EyelidIllustrationView(
                  kind: accepted
                      ? EyelidIllustration.goodExample
                      : EyelidIllustration.blurryExample,
                  size: 120,
                  background: AnaemiaUi.conjunctivaPale,
                ),
              ),
            if (p != null)
              Positioned(
                left: 3,
                top: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: accepted
                        ? MirrorColors.successFg
                        : MirrorColors.dangerFg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.shortLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- 4. Haemoglobin band on WHO scale -----------------------------------

  int get _whoRowIndex => switch (r.threshold.groupLabel) {
    'Man' => 0,
    'Non-pregnant woman' => 1,
    'Pregnant woman' => 2,
    'Child 5–11 years' => 3,
    _ => 4,
  };

  Widget _hbBandCard() {
    final c = r.threshold.cutoffGdL;
    final scale = RangeScale(
      breakpoints: [c - 3.0, c, c + 0.5, c + 3.5],
      labels: [
        'High  < $_cutoff',
        'Borderline',
        'Normal  ≥ ${(c + 0.5).toStringAsFixed(1)}',
      ],
      colors: const [
        AnaemiaUi.segHigh,
        AnaemiaUi.segBorder,
        AnaemiaUi.segNormal,
      ],
    );
    final assessed = r.band != SemanticBand.notAssessed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(Icons.bloodtype_rounded, AnaemiaUi.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.threshold.groupLabel,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Your WHO cut-off $_cutoff g/dL',
                      style: const TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BandChip(band: r.band, compact: true),
            ],
          ),
          const SizedBox(height: 16),
          RangeGauge(
            scale: scale,
            // Pin sits in the middle of the band segment — the exact number is internal.
            value: switch (r.band) {
              SemanticBand.high => c - 1.5,
              SemanticBand.borderline => c + 0.25,
              _ => c + 2.0,
            },
            pinColor: BandVisualStyle.forBand(r.band).foreground,
            showPin: assessed,
          ),
          const SizedBox(height: 14),
          const Text(
            'WHO cut-offs (g/dL)',
            style: TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < AnaemiaWhoThreshold.table.length; i++)
            _whoRow(AnaemiaWhoThreshold.table[i], i == _whoRowIndex),
          const SizedBox(height: 10),
          const InfoNote(
            icon: Icons.lock_outline_rounded,
            title: 'Why no number?',
            text:
                'The numeric haemoglobin estimate (HB_EST, ALG-IMG-01) stays internal until the validation study (IMG-AN-01: sensitivity and specificity ≥ 85 %) passes — gate G-24. Until then only the band is shown.',
          ),
        ],
      ),
    );
  }

  Widget _whoRow(AnaemiaWhoThreshold t, bool isYou) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isYou
            ? AnaemiaUi.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isYou
              ? AnaemiaUi.accent.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isYou ? Icons.person_rounded : Icons.circle,
            size: isYou ? 14 : 6,
            color: isYou ? AnaemiaUi.accent : AnaemiaUi.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isYou ? '${t.groupLabel} (you)' : t.groupLabel,
              style: TextStyle(
                color: isYou ? AnaemiaUi.accent : AnaemiaUi.ink,
                fontSize: 12,
                fontWeight: isYou ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Normal ≥ ${t.cutoffGdL.toStringAsFixed(1)}',
            style: TextStyle(
              color: isYou ? AnaemiaUi.accent : AnaemiaUi.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. Inputs used -----------------------------------------------------

  Widget _inputsCard() {
    final a = r.answers;
    final treatmentText = a.treatments.isEmpty
        ? 'Not answered'
        : a.treatments.map((t) => t.label).join(' · ');
    final reliability = a.treatments
        .where((t) => t.affectsReliability)
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnaemiaUi.kvRow(
            'Person',
            '${r.subjectName} · ${r.ageYears} y · ${r.sex.label}',
          ),
          AnaemiaUi.kvRow(
            'Pregnancy',
            r.isPregnant
                ? 'Yes${r.pregnancyWeeks != null ? ' · ${r.pregnancyWeeks} weeks' : ''}'
                : 'No',
          ),
          AnaemiaUi.kvRow(
            'WHO group',
            '${r.threshold.groupLabel} · cut-off $_cutoff g/dL',
          ),
          AnaemiaUi.kvRow(
            'Photos',
            '${r.acceptedPhotoCount} of 4 accepted · flash on · ${r.retakeTotal} retake${r.retakeTotal == 1 ? '' : 's'}',
          ),
          AnaemiaUi.kvRow(
            'Colour card',
            a.hasColourCard
                ? 'Used · ΔE ${(a.colourErrorDe ?? 0).toStringAsFixed(1)} (≤ 5 pass, ALG-CAP-10)'
                : 'Not used · flash white-balance normalisation',
          ),
          AnaemiaUi.kvRow('Recent treatment', treatmentText),
          if (a.otherNote != null) AnaemiaUi.kvRow('Your note', a.otherNote!),
          AnaemiaUi.kvRow(
            'Consent',
            a.consentGiven ? 'Screening consent given (G-04)' : 'Not recorded',
          ),
          if (reliability.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoNote(
              icon: Icons.warning_amber_rounded,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              title: 'May affect this result',
              text: reliability.map((t) => t.reliabilityNote).join(' '),
            ),
          ],
        ],
      ),
    );
  }

  // --- 6. Photo quality ---------------------------------------------------

  Widget _photoQualityCard() {
    final qualityOk = r.captureQualityScore >= 0.7;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Capture quality',
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AnaemiaUi.tag(
                '${(r.captureQualityScore * 100).round()}% · ${qualityOk ? 'good' : 'low'}',
                color: qualityOk
                    ? MirrorColors.successFg
                    : MirrorColors.warningFg,
                icon: qualityOk
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FixedColumnWidth(46),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(),
              3: FlexColumnWidth(),
              4: FlexColumnWidth(),
              5: FixedColumnWidth(40),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AnaemiaUi.outline)),
                ),
                children: [
                  _th('Photo', align: TextAlign.left),
                  _th('Sharp'),
                  _th('Glare'),
                  _th('Dark'),
                  _th('Lid'),
                  _th('Tries', align: TextAlign.right),
                ],
              ),
              for (final p in r.photos) _photoRow(p),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Pass rules: sharpness ≥ 100 (ALG-CAP-06) · glare ≤ 5 % and dark ≤ 10 % (CAP-07) · image quality ≥ 0.70 (CAP-08) · lid visible ≥ 80 % (CAP-09). Up to 3 attempts per photo (G-25).',
            style: TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          color: AnaemiaUi.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  TableRow _photoRow(EyelidPhoto p) {
    final q = p.quality;
    Widget cell(String text, bool ok) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 13,
            color: ok ? MirrorColors.successFg : MirrorColors.dangerFg,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AnaemiaUi.ink,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return TableRow(
      decoration: BoxDecoration(
        color: p.accepted
            ? Colors.transparent
            : MirrorColors.dangerBg.withValues(alpha: 0.45),
        border: const Border(
          bottom: BorderSide(color: AnaemiaUi.outline, width: 0.6),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnaemiaUi.tag(
              p.shortLabel,
              color: p.accepted ? AnaemiaUi.primary : MirrorColors.dangerFg,
            ),
          ),
        ),
        cell(q.blurScore.round().toString(), q.blurPassed),
        cell('${q.glarePct.toStringAsFixed(1)}%', q.glarePassed),
        cell('${q.darkPct.toStringAsFixed(1)}%', q.darkPassed),
        cell('${q.lidCoveragePct.round()}%', q.coveragePassed),
        Text(
          p.accepted ? '${p.attempts}×' : 'N/A',
          textAlign: TextAlign.right,
          style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11),
        ),
      ],
    );
  }

  // --- 7. How this result is made ----------------------------------------

  Widget _howMadeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        children: [
          AnaemiaUi.numberedStep(
            1,
            'Four flash photos of the lower eyelids',
            'Two per eye with the lid pulled down. Each photo passed sharpness, glare, light and framing checks on the phone before it was kept.',
          ),
          AnaemiaUi.numberedStep(
            2,
            'Colour correction',
            r.answers.hasColourCard
                ? 'The 24-patch card in the photo was used to fit a 3×3 colour matrix so the lid colour is true (ΔE ≤ 5).'
                : 'No card was used, so colours were normalised from the flash white balance (slightly lower confidence).',
          ),
          AnaemiaUi.numberedStep(
            3,
            'Finding the inner eyelid',
            'The pink conjunctiva area is segmented; its colour (CIELab a*, red/green ratio, redness index) and vessel pattern are measured.',
          ),
          AnaemiaUi.numberedStep(
            4,
            'Eyelid colour model (ALG-IMG-01)',
            'A CNN turns those features into an internal haemoglobin estimate and an anaemia probability. It is in clinical validation (IMG-AN-01).',
          ),
          AnaemiaUi.numberedStep(
            5,
            'WHO cut-off and risk rules',
            'The estimate is compared with the WHO cut-off for your age, sex and pregnancy ($_cutoff g/dL). High or borderline results go to a specialist reviewer; in pregnancy a High band is Urgent (T12).',
          ),
        ],
      ),
    );
  }

  // --- 8. How to read it --------------------------------------------------

  Widget _howToReadCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _readRow(
            SemanticBand.normal,
            'Eyelid colour matches normal haemoglobin for your group. No action from this screen; repeat as part of your usual check-ups.',
          ),
          _readRow(
            SemanticBand.borderline,
            'Close to the cut-off. Get a CBC when convenient, or repeat the screen in 2–4 weeks in good light.',
          ),
          _readRow(
            SemanticBand.high,
            'Likely below the cut-off. Book a CBC with ferritin. Urgent in pregnancy or if you feel breathless, dizzy or very tired.',
          ),
          _readRow(
            SemanticBand.notAssessed,
            'No usable photos. Not a health result — retake in daylight with the lid pulled well down.',
          ),
          const Divider(height: 20),
          AnaemiaUi.bullet(
            'Confidence = photo quality × model confidence. Results under 60 % are hidden (G-23).',
            icon: Icons.speed_rounded,
          ),
          AnaemiaUi.bullet(
            '“In clinical validation” means the model has not yet passed its study, so only a band — never a number — is shown (G-24).',
            icon: Icons.science_outlined,
          ),
          AnaemiaUi.bullet(
            'This is a screening band, not a diagnosis. Your lab\'s ranges and your doctor\'s judgement take precedence.',
            icon: Icons.health_and_safety_outlined,
          ),
        ],
      ),
    );
  }

  Widget _readRow(SemanticBand band, String text) {
    final isThis = band == r.band;
    final style = BandVisualStyle.forBand(band);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isThis
            ? style.background.withValues(alpha: 0.6)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isThis
              ? style.foreground.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BandChip(band: band, compact: true),
                if (isThis)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 2),
                    child: Text(
                      'Your result',
                      style: TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AnaemiaUi.ink,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: isThis ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 9. Checked by ------------------------------------------------------

  Widget _checkedByCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        children: [
          _checkedRow(
            Icons.phone_android_rounded,
            const Color(0xFF2563EB),
            'On-device quality checks',
            'ALG-CAP-06 blur · CAP-07 glare/dark · CAP-08 image quality · CAP-09 lid coverage · CAP-10 colour card',
            'Passed ${r.acceptedPhotoCount}/4',
            r.acceptedPhotoCount == 4
                ? MirrorColors.successFg
                : MirrorColors.warningFg,
          ),
          const Divider(height: 18),
          _checkedRow(
            Icons.memory_rounded,
            AnaemiaUi.primary,
            'Eyelid colour model',
            'ALG-IMG-01 v${r.algorithmVersion} · ranges ${r.rangeVersion}',
            'In validation',
            MirrorColors.infoFg,
          ),
          const Divider(height: 18),
          _checkedRow(
            Icons.how_to_reg_rounded,
            const Color(0xFF7C3AED),
            'Specialist reviewer (IMG-10)',
            r.specialistReviewRequired
                ? 'De-identified photos, quality metrics and model heat-maps are queued. Status updates here and in History.'
                : 'Review is required only for High bands or probabilities within ±0.10 of the threshold.',
            r.specialistReviewStatus,
            r.specialistReviewRequired ? MirrorColors.infoFg : AnaemiaUi.muted,
          ),
        ],
      ),
    );
  }

  Widget _checkedRow(
    IconData icon,
    Color color,
    String title,
    String body,
    String status,
    Color statusColor,
  ) {
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
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: AnaemiaUi.tag(status, color: statusColor),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  color: AnaemiaUi.muted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 10. Next steps -----------------------------------------------------

  Widget _nextStepsCard() {
    final spec = ConfirmatoryInvestigationsRegistry.forCode('COND_ANAEMIA');
    final flagged =
        r.band == SemanticBand.high || r.band == SemanticBand.borderline;
    final urgencyText = r.isPregnant
        ? 'Urgent in pregnancy — book within days.'
        : r.band == SemanticBand.high
        ? 'Routine — book within 2–4 weeks. Urgent if Hb < 7 g/dL on the lab test or if you feel unwell.'
        : 'Routine.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (flagged) ...[
            Row(
              children: [
                AnaemiaUi.iconTile(Icons.biotech_rounded, AnaemiaUi.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Confirm with a blood test',
                        style: TextStyle(
                          color: AnaemiaUi.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        urgencyText,
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
            const SizedBox(height: 12),
            AnaemiaUi.kvRow('Tests', spec.investigations),
            AnaemiaUi.kvRow('Usual cut-offs', spec.usualDiagnosticCutoffs),
            AnaemiaUi.kvRow(
              'Pair with this scan',
              '${spec.pairingReferenceTest} within ${spec.maxPairingGapLabel.replaceAll('<= ', '')}; not valid after ${spec.pairingExclusions.toLowerCase()}.',
            ),
            const SizedBox(height: 8),
            AnaemiaUi.bullet(
              'Enter the lab result in the app (S-R06) to close the case and improve your baseline.',
              icon: Icons.edit_note_rounded,
            ),
          ] else if (r.band == SemanticBand.notAssessed) ...[
            AnaemiaUi.bullet(
              'Retake in daylight. Pull the lower lid well down and keep the phone 15–20 cm away.',
              icon: Icons.replay_rounded,
            ),
            AnaemiaUi.bullet(
              'If you feel tired, breathless or dizzy, see a clinician for a CBC regardless of this screen.',
              icon: Icons.local_hospital_outlined,
            ),
          ] else ...[
            AnaemiaUi.bullet(
              'No test needed from this screen. Repeat every 6 months, or sooner in pregnancy or if symptoms appear.',
              icon: Icons.event_repeat_rounded,
            ),
            AnaemiaUi.bullet(
              'Keep an iron-rich diet; your doctor may still request a CBC as part of routine care.',
              icon: Icons.restaurant_rounded,
            ),
          ],
          if (r.isPartiallyAssessed) ...[
            const SizedBox(height: 8),
            InfoNote(
              icon: Icons.visibility_off_outlined,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              text:
                  '${r.notAssessedEyes.map((e) => e.label).join(' and ')} could not be assessed; the band is based on the other eye. Retake for a stronger result.',
            ),
          ],
        ],
      ),
    );
  }

  // --- 11. Quality & versions --------------------------------------------

  Widget _qualityVersionsExpander() {
    final rec = r.recordedAt;
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
            Icons.tune_rounded,
            AnaemiaUi.muted,
            size: 36,
          ),
          title: const Text(
            'Quality & versions',
            style: TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: const Text(
            'Session, algorithm, rules and internal markers (operator view)',
            style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            AnaemiaUi.kvRow('Session', r.sessionId),
            AnaemiaUi.kvRow(
              'Recorded',
              rec.toIso8601String().substring(0, 16).replaceAll('T', ' '),
            ),
            AnaemiaUi.kvRow(
              'Algorithm',
              'ALG-IMG-01 v${r.algorithmVersion} · release: bandOnly (G-24)',
            ),
            AnaemiaUi.kvRow('Range version', r.rangeVersion),
            AnaemiaUi.kvRow(
              'Rules fired',
              r.firedRuleCodes.isEmpty ? 'None' : r.firedRuleCodes.join(', '),
            ),
            AnaemiaUi.kvRow(
              'Result confidence',
              '${r.confidence.toStringAsFixed(2)} = quality ${r.captureQualityScore.toStringAsFixed(2)} × model ${r.modelConfidence.toStringAsFixed(2)} × context 1.00',
            ),
            AnaemiaUi.kvRow(
              'Specialist review',
              '${r.specialistReviewStatus} (margin ±0.10)',
            ),
            AnaemiaUi.kvRow(
              'Retakes',
              '${r.retakeTotal} total (max 3 per photo, G-25)',
            ),
            const Divider(height: 18),
            const Text(
              'Internal markers (R-9: not shown to members)',
              style: TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            AnaemiaUi.kvRow(
              'HB_EST',
              '${r.hbEstInternalGdL.toStringAsFixed(1)} g/dL · static demo value until the model ships',
            ),
            AnaemiaUi.kvRow(
              'ANAEMIA_PROB',
              '${r.anaemiaProb.toStringAsFixed(2)} (τ = ${r.decisionThreshold.toStringAsFixed(2)})',
            ),
            AnaemiaUi.kvRow(
              'Proxies',
              'Lid coverage and image-quality scores are pixel proxies for CAP-08/09 until the classifiers ship.',
            ),
          ],
        ),
      ),
    );
  }
}
