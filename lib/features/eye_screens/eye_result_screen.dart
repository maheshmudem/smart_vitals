import 'package:flutter/material.dart';

import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/eye_session_builder.dart'
    show fdiToothName;
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/entities/anaemia_result.dart' show EyeSide;
import '../../core/domain/entities/marker_envelope.dart';
import '../../core/domain/entities/case_record.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/eye_photo_protocol.dart';
import '../../core/domain/entities/eye_photo_session.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import 'eye_illustrations.dart';
import 'eye_intro_screen.dart' show resultIconFor;
import 'eye_stepper_screen.dart';

/// S-R01 result for any [EyeProtocol] (T-RES template).
///
/// Order: urgency banner → result card → your eyes (per-eye) → reading scale
/// → what was found → inputs used → photo quality → how this result is made
/// → how to read it → checked by → next steps (§13) → quality & versions →
/// disclaimer. Save / Retake live in a sticky bottom bar.
class EyeResultScreen extends StatefulWidget {
  const EyeResultScreen({super.key, required this.result});

  final EyeSessionResult result;

  @override
  State<EyeResultScreen> createState() => _EyeResultScreenState();
}

class _EyeResultScreenState extends State<EyeResultScreen> {
  static const double _gap = 20;
  bool _saved = false;
  VoiceCoachController? _voice;

  /// Dental: tooth tapped on the FDI chart (S-F05 inline detail).
  int? _selectedFdi;

  EyeSessionResult get r => widget.result;
  EyeProtocol get p => widget.result.protocol;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voice ??= VoiceCoachController(
      languageCode: ttsLocaleFor(AppStateScope.of(context).localeCode),
    );
  }

  @override
  void dispose() {
    _voice?.dispose();
    super.dispose();
  }

  void _readAloud() {
    final next = r.band == SemanticBand.notAssessed
        ? p.nextStepsNotAssessed.first
        : r.urgency == UrgencyLevel.none
        ? p.nextStepsNormal.first
        : (p.bannerCopy[r.urgency]?.$1 ?? r.bandSubline);
    _voice?.announce(
      '${p.shortTitle} result for ${r.subjectName}. ${r.bandTitle}. ${r.whatItMeans} Next step: $next',
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
        title: Text('${p.shortTitle} result'),
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
              p.perSideTitle,
              p.perSideCaption ??
                  (p.bothEyesInOneFrame
                      ? 'Both eyes from the same photos · the band above combines them'
                      : '${p.views.first.ofPerEye} photo${p.views.first.ofPerEye == 1 ? '' : 's'} per eye · the band above combines both eyes'),
            ),
            _eyesCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Algorithm outputs',
              'Every output marker of ${p.algorithmId} (Spec ${MarkerReadings.fromEye(r).first.card.specRef}) with the value the ${p.partnerModel ? 'partner AI' : 'model'} produced',
            ),
            AlgorithmOutputsSection(
              groups: MarkerReadings.fromEye(r),
              showHeader: false,
            ),
            for (final card in r.extraCards) ...[
              const SizedBox(height: _gap),
              ..._extraCard(card),
            ],
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              p.readsTitle,
              'Where this result sits on the scale',
            ),
            _scaleCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Inputs used',
              'Everything the result was based on',
            ),
            _inputsCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Photo quality',
              p.partnerModel
                  ? 'Gradability checks for each image'
                  : 'On-device checks for each photo (ALG-CAP-06…10)',
            ),
            _photoQualityCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'How this result is made',
              '${p.howMade.length} steps, in order',
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
              builder: (_) => EyeStepperScreen(
                protocol: p,
                startAtHowTo: true,
                onRequest: r.answers.onRequest,
              ),
            ),
          );
        },
        onPressed: _saved
            ? null
            : () {
                appState.saveEyeSession(r);
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
    final (title, subtitle) =
        p.bannerCopy[r.urgency] ??
        p.bannerCopy.values.firstOrNull ??
        (r.bandTitle, r.bandSubline);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UrgencyBanner(
        urgency: r.urgency,
        title: title,
        subtitle: subtitle,
        ruleCodes: r.firedRuleCodes,
      ),
    );
  }

  // --- 2. Result card -----------------------------------------------------

  SemanticBand get _displayBand => r.band;

  IconData get _bandIcon {
    if (r.band == SemanticBand.notAssessed) return Icons.help_rounded;
    if (r.urgency == UrgencyLevel.urgent) return Icons.error_rounded;
    return switch (r.band) {
      SemanticBand.high ||
      SemanticBand.refer ||
      SemanticBand.ulcer ||
      SemanticBand.suspicious => Icons.error_rounded,
      SemanticBand.borderline ||
      SemanticBand.mild ||
      SemanticBand.atRisk => Icons.warning_rounded,
      _ => Icons.check_circle_rounded,
    };
  }

  Widget _resultCard() {
    final style = BandVisualStyle.forBand(_displayBand);
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
              AnaemiaUi.iconTile(resultIconFor(p), AnaemiaUi.accent, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.title} · ${p.algorithmId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
                      '$time · ${r.durationSeconds} s · ${r.acceptedPhotoCount} of ${p.photoCount} photos',
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
                        r.bandTitle,
                        style: TextStyle(
                          color: style.foreground,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.bandSubline,
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
              if (p.partnerModel)
                AnaemiaUi.tag(
                  'Partner result · shown as given',
                  color: MirrorColors.infoFg,
                  icon: Icons.verified_user_rounded,
                )
              else
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
              if (r.answers.onRequest)
                AnaemiaUi.tag(
                  'On request (G-09)',
                  color: MirrorColors.warningFg,
                  icon: Icons.front_hand_rounded,
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
            r.whatItMeans,
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
    final anySimulated = r.photos.any((x) => x.quality.isSimulated);
    if (p.zonesInsteadOfSides) {
      final zones = p.zoneLabelsInOrder;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: AnaemiaUi.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < zones.length; i++) ...[
              if (i > 0) const Divider(height: 22),
              _zoneRow(zones[i]),
            ],
            const SizedBox(height: 10),
            Text(
              '${p.gauge.title}: ${p.gaugeExplainer}. The Spec reports one combined band per session; per-area values are shown for transparency.'
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.bothEyesInOneFrame) ...[
            Row(
              children: [
                for (var i = 0; i < 2; i++) ...[
                  SizedBox(
                    width: 60,
                    child: _thumb(r.photos.length > i ? r.photos[i] : null),
                  ),
                  const SizedBox(width: 4),
                ],
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Both pupils are measured in each photo; the two photos must agree before a band is given.',
                    style: TextStyle(
                      color: AnaemiaUi.muted,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
          ],
          _eyeRow(EyeSide.left),
          const Divider(height: 22),
          _eyeRow(EyeSide.right),
          const SizedBox(height: 10),
          Text(
            '${p.gauge.title}: ${p.gaugeExplainer}. The Spec reports one combined band per session; per-side values are shown for transparency.'
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

  /// Zone row (newborn forehead / chest, skin close-up / angled / context).
  Widget _zoneRow(String zone) {
    final z = r.perZone[zone];
    final band = z?.band ?? SemanticBand.notAssessed;
    final gauge = z?.gauge;
    final photos = r.photosForZone(zone);
    final assessed = band != SemanticBand.notAssessed && gauge != null;
    final g = p.gauge;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 124,
          child: Row(
            children: [
              Expanded(child: _thumb(photos.isNotEmpty ? photos[0] : null)),
              const SizedBox(width: 4),
              Expanded(
                child: photos.length > 1
                    ? _thumb(photos[1])
                    : const SizedBox.shrink(),
              ),
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
                      zone,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  BandChip(band: band, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              RangeGauge(
                scale: RangeScale(
                  breakpoints: g.breakpoints,
                  labels: g.labels,
                  colors: [
                    for (final b in g.bands)
                      BandVisualStyle.forBand(
                        b,
                      ).foreground.withValues(alpha: 0.45),
                  ],
                ),
                value: gauge ?? 0,
                pinColor: BandVisualStyle.forBand(band).foreground,
                showPin: assessed,
              ),
              const SizedBox(height: 4),
              Text(
                z?.note ?? '',
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

  Widget _eyeRow(EyeSide eye) {
    final band = r.perEyeBand[eye] ?? SemanticBand.notAssessed;
    final gauge = r.perEyeGauge[eye];
    final note = r.perEyeNote[eye] ?? '';
    final photos = r.photosFor(eye);
    final assessed = band != SemanticBand.notAssessed && gauge != null;
    final g = p.gauge;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!p.bothEyesInOneFrame)
          SizedBox(
            width: 124,
            child: Row(
              children: [
                Expanded(child: _thumb(photos.isNotEmpty ? photos[0] : null)),
                const SizedBox(width: 4),
                Expanded(
                  child: photos.length > 1
                      ? _thumb(photos[1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          )
        else
          AnaemiaUi.iconTile(
            eye == EyeSide.left
                ? Icons.arrow_circle_left_outlined
                : Icons.arrow_circle_right_outlined,
            AnaemiaUi.accent,
            size: 36,
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
                      p.sideLabel(eye),
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  BandChip(band: band, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              RangeGauge(
                scale: RangeScale(
                  breakpoints: g.breakpoints,
                  labels: g.labels,
                  colors: [
                    for (final b in g.bands)
                      BandVisualStyle.forBand(
                        b,
                      ).foreground.withValues(alpha: 0.45),
                  ],
                ),
                value: gauge ?? 0,
                pinColor: BandVisualStyle.forBand(band).foreground,
                showPin: assessed,
              ),
              const SizedBox(height: 4),
              Text(
                note,
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

  Widget _thumb(EyePhoto? x) {
    final accepted = x?.accepted ?? false;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: x == null
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
            if (x?.bytes != null)
              Image.memory(x!.bytes!, fit: BoxFit.cover)
            else
              FittedBox(
                fit: BoxFit.cover,
                child: EyeIllustrationView(
                  kind: accepted
                      ? (x?.view.illustration ?? p.examples.first.illustration)
                      : EyeIllustration.blurryExample,
                  size: 120,
                ),
              ),
            if (x != null)
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
                    x.shortLabel,
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

  // --- 3b. Protocol-specific extra cards -----------------------------------

  List<Widget> _extraCard(EyeExtraCard card) {
    return switch (card) {
      NeonatalChartCard c => [
        AnaemiaUi.sectionHeader(
          'Phototherapy line for this baby',
          '${c.bucketLabel} · ${c.ageHours} h old · ${c.hasRiskFactors ? 'with risk factors' : 'no risk factors'}',
        ),
        _neonatalChartCard(c),
      ],
      FootRiskCard c => [
        AnaemiaUi.sectionHeader(
          'Foot-risk category',
          'IWGDF 2023 category from your answers, plus what the photos showed',
        ),
        _footRiskCard(c),
      ],
      SkinMatchesCard c => [
        AnaemiaUi.sectionHeader(
          'Possible matches',
          'Closest-looking conditions — matches, not a diagnosis',
        ),
        _skinMatchesCard(c),
      ],
      OralSitesCard c => [
        AnaemiaUi.sectionHeader(
          'Site by site',
          'What the classifier saw at each of the six sites · red flags from your answers',
        ),
        _oralSitesCard(c),
      ],
      DentalChartCard c => [
        AnaemiaUi.sectionHeader(
          'Tooth chart (FDI)',
          '${c.dentitionLabel} · tap a tooth for its detail (S-F05)',
        ),
        _dentalChartCard(c),
      ],
    };
  }

  // --- Oral: six sites, red flags, patch glossary --------------------------

  Widget _oralSitesCard(OralSitesCard c) {
    final usesTobacco = r.answers.usesTobacco;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < c.sites.length; i++) ...[
            _oralSiteRow(c.sites[i]),
            if (i != c.sites.length - 1) const Divider(height: 14),
          ],
          const Divider(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Red flags from your answers',
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AnaemiaUi.tag(
                c.redFlags.isEmpty ? 'None' : '${c.redFlags.length} flagged',
                color: c.redFlags.isEmpty
                    ? MirrorColors.successFg
                    : MirrorColors.dangerFg,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (c.redFlags.isEmpty)
            AnaemiaUi.bullet(
              'No symptom, duration or habit red flags reported.',
              icon: Icons.check_circle_rounded,
              color: MirrorColors.successFg,
            )
          else
            for (final f in c.redFlags)
              AnaemiaUi.bullet(
                f,
                icon: Icons.flag_rounded,
                color: MirrorColors.dangerFg,
              ),
          const Divider(height: 22),
          const Text(
            'What these patches are',
            style: TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          AnaemiaUi.kvRow(
            'Leukoplakia',
            'White patch that cannot be wiped off · 1–5 % turn into cancer over years — biopsy decides',
          ),
          AnaemiaUi.kvRow(
            'Erythroplakia',
            'Red velvety patch · the highest-risk pattern, often already dysplasia',
          ),
          AnaemiaUi.kvRow(
            'OSMF',
            'Oral submucous fibrosis: stiff bands from areca (supari) · burning, cannot open wide',
          ),
          AnaemiaUi.kvRow(
            'Non-healing ulcer',
            'A sore that has not healed in 3 weeks · needs an in-person look',
          ),
          const SizedBox(height: 8),
          InfoNote(
            icon: usesTobacco
                ? Icons.smoke_free_rounded
                : Icons.photo_library_outlined,
            color: usesTobacco ? MirrorColors.dangerFg : MirrorColors.infoFg,
            background: usesTobacco
                ? MirrorColors.dangerBg
                : MirrorColors.infoBg,
            title: usesTobacco ? 'Quitting matters most' : null,
            text: usesTobacco
                ? 'Tobacco, gutka, paan and areca cause 9 in 10 mouth cancers here. Stopping now halves the risk within 5 years — the national quitline (1800-11-2356) and your PHC can help. Repeat this check every 6 months.'
                : 'A Grad-CAM heat-map of the region the classifier looked at will appear on each photo when the model ships; today the marked box is a stand-in. Repeat yearly, or at once if you notice a new patch or sore.',
          ),
        ],
      ),
    );
  }

  Widget _oralSiteRow(OralSiteResult s) {
    final photos = r.photosForZone(s.zone);
    final photo = photos.isNotEmpty ? photos.first : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Stack(
            children: [
              _thumb(photo),
              if (s.lesionBox != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LesionBoxPainter(
                      box: s.lesionBox!,
                      color: BandVisualStyle.forBand(s.band).foreground,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.zone,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  BandChip(
                    band: s.band,
                    compact: true,
                    customLabel: s.classLabel,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                s.note,
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
    );
  }

  // --- Dental: FDI chart, tooth detail, gums, sealants, change -------------

  Widget _dentalChartCard(DentalChartCard c) {
    final exam = c.exam;
    final selected = _selectedFdi;
    final finding = selected == null
        ? null
        : exam.toothFindings.where((f) => f.toothFdi == selected).firstOrNull;
    final lowModHigh = RangeScale(
      breakpoints: const [0, 1, 2, 3],
      labels: const ['Low', 'Moderate', 'High'],
      colors: [
        MirrorColors.successFg.withValues(alpha: 0.45),
        MirrorColors.warningFg.withValues(alpha: 0.45),
        MirrorColors.dangerFg.withValues(alpha: 0.45),
      ],
    );
    double pinFor(SemanticBand b) => switch (b) {
      SemanticBand.low => 0.5,
      SemanticBand.moderate => 1.5,
      SemanticBand.high => 2.5,
      _ => 0,
    };
    Widget bandGauge(String title, SemanticBand b, String note) {
      final assessed = b != SemanticBand.notAssessed;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              BandChip(band: b, compact: true),
            ],
          ),
          const SizedBox(height: 6),
          RangeGauge(
            scale: lowModHigh,
            value: pinFor(b),
            pinColor: BandVisualStyle.forBand(b).foreground,
            showPin: assessed,
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      );
    }

    final riskColor = BandVisualStyle.forBand(exam.cariesRiskBand).foreground;
    final interval = switch (exam.cariesRiskBand) {
      SemanticBand.high => 'dentist within 4 weeks',
      SemanticBand.moderate => 'dentist within 3 months',
      SemanticBand.low => 'check-up yearly',
      _ => 'retake the photos',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exam.isPartial) ...[
            InfoNote(
              icon: Icons.visibility_off_rounded,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              title: 'Partial exam · ${exam.viewsCompleted} of 4 views',
              text:
                  'Teeth not seen (marked "?"): ${exam.unseenTeethFdi.join(', ')}. Retake only the missing view to complete the chart (E-DEN-001).',
            ),
            const SizedBox(height: 12),
          ],
          FdiToothChartWidget(
            isChildMode: exam.isChildMode,
            mixedDentition: c.mixedDentition,
            findings: exam.toothFindings,
            unseenTeeth: exam.unseenTeethFdi,
            sealantTeeth: exam.sealantNeededTeethFdi,
            onToothSelected: (fdi) =>
                setState(() => _selectedFdi = _selectedFdi == fdi ? null : fdi),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _legend('Sound', SemanticBand.normal),
              _legend('White spot', SemanticBand.borderline),
              _legend('Enamel break', SemanticBand.moderate),
              _legend('Cavity', SemanticBand.high),
              _legend('Broken / black', SemanticBand.severe),
              _legend('Abscess sign', SemanticBand.critical),
              _legend('Sealant', SemanticBand.inValidation),
              _legend('Not seen', SemanticBand.notAssessed),
            ],
          ),
          const SizedBox(height: 12),
          if (selected == null)
            const Text(
              'Tap any tooth above to see its FDI number, name, finding and what changed.',
              style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
            )
          else
            _toothDetail(exam, selected, finding),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Caries risk (ALG-DEN-06 · BR-DEN)',
                  style: const TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              BandChip(band: exam.cariesRiskBand, compact: true),
            ],
          ),
          const SizedBox(height: 6),
          RangeGauge(
            scale: lowModHigh,
            value: pinFor(exam.cariesRiskBand),
            pinColor: riskColor,
            showPin: exam.cariesRiskBand != SemanticBand.notAssessed,
          ),
          const SizedBox(height: 4),
          Text(
            '${c.cariesReason} Habits: ${c.habitsSummary}.',
            style: const TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          bandGauge(
            'Gum inflammation (ALG-DEN-04)',
            exam.gumInflammationBand,
            exam.gumInflammationBand == SemanticBand.notAssessed
                ? 'Needs a front view — not assessed in this exam.'
                : exam.gumInflammationBand == SemanticBand.high
                ? 'Red, swollen gum margins in the front views (Löe & Silness grade 2–3). Periodontal probing at the dentist; brush the gum line gently twice a day.'
                : exam.gumInflammationBand == SemanticBand.moderate
                ? 'Mild redness at the gum line. Brush along the gum line and clean between teeth — it usually settles in 2 weeks.'
                : 'Pink, firm gum margins.',
          ),
          const SizedBox(height: 12),
          bandGauge(
            'Plaque (ALG-DEN-04)',
            exam.plaqueBand,
            exam.plaqueBand == SemanticBand.notAssessed
                ? 'Needs a front view — not assessed in this exam.'
                : exam.plaqueBand == SemanticBand.high
                ? 'Thick plaque or tartar along the gum line — scaling at the dentist and better brushing.'
                : exam.plaqueBand == SemanticBand.moderate
                ? 'Some plaque near the gum line; brushing at a 45° angle to the gums clears it.'
                : 'Little plaque visible.',
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sealant candidates (ALG-DEN-05 · ages 6–9)',
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (exam.sealantNeededTeethFdi.isNotEmpty)
                AnaemiaUi.tag(
                  '${exam.sealantNeededTeethFdi.length} teeth',
                  color: MirrorColors.infoFg,
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (exam.sealantNeededTeethFdi.isEmpty)
            Text(
              r.ageYears >= 6 && r.ageYears <= 9
                  ? 'No deep-groove first molars found that need a sealant.'
                  : 'Sealants are assessed for the first permanent molars (16, 26, 36, 46) between ages 6 and 9 — not applicable at ${r.ageLabel}.',
              style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in exam.sealantNeededTeethFdi)
                  AnaemiaUi.tag(
                    'Tooth $t · ${fdiToothName(t)}',
                    color: MirrorColors.infoFg,
                    icon: Icons.shield_rounded,
                  ),
              ],
            ),
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Changed since last exam (ALG-DEN-07)',
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (c.previousExamAt != null)
                AnaemiaUi.tag(
                  'vs ${_dateLabel(c.previousExamAt!)}',
                  color: AnaemiaUi.muted,
                  icon: Icons.history_rounded,
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (c.previousExamAt == null)
            AnaemiaUi.bullet(
              'First dental baseline recorded — the next exam will compare each tooth with this one.',
              icon: Icons.flag_circle_rounded,
              color: MirrorColors.infoFg,
            )
          else if (c.changes.isEmpty)
            AnaemiaUi.bullet(
              'No tooth changed since the last exam.',
              icon: Icons.check_circle_rounded,
              color: MirrorColors.successFg,
            )
          else
            for (final ch in c.changes)
              AnaemiaUi.bullet(
                'Tooth ${ch.$1} · ${ch.$2}',
                icon: ch.$2.startsWith('Resolved')
                    ? Icons.check_circle_rounded
                    : ch.$2.startsWith('Not comparable')
                    ? Icons.help_rounded
                    : Icons.trending_up_rounded,
                color: ch.$2.startsWith('Resolved')
                    ? MirrorColors.successFg
                    : ch.$2.startsWith('Not comparable')
                    ? AnaemiaUi.muted
                    : MirrorColors.dangerFg,
              ),
          const SizedBox(height: 10),
          InfoNote(
            icon: Icons.tips_and_updates_rounded,
            title: 'Keeping the risk down',
            text:
                'Brush twice a day for 2 minutes with fluoride toothpaste (1000 ppm+; a pea-sized amount for children), spit but do not rinse. Sweets and sugary drinks only at mealtimes. '
                '${r.ageYears < 6 ? 'No bottle or feeding in bed after the first teeth appear. ' : ''}'
                'Next: $interval; repeat these photos in 6 months.',
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, SemanticBand band) {
    final style = BandVisualStyle.forBand(band);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: band == SemanticBand.normal
            ? MirrorColors.successBg
            : band == SemanticBand.inValidation
            ? MirrorColors.infoBg
            : band == SemanticBand.notAssessed
            ? MirrorColors.neutralBg
            : style.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              (band == SemanticBand.normal
                      ? MirrorColors.successFg
                      : band == SemanticBand.inValidation
                      ? MirrorColors.infoFg
                      : band == SemanticBand.notAssessed
                      ? MirrorColors.neutralFg
                      : style.foreground)
                  .withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: band == SemanticBand.normal
              ? MirrorColors.successFg
              : band == SemanticBand.inValidation
              ? MirrorColors.infoFg
              : band == SemanticBand.notAssessed
              ? MirrorColors.neutralFg
              : style.foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// S-F05 tooth detail, inline.
  Widget _toothDetail(DentalExamResult exam, int fdi, ToothFinding? finding) {
    final unseen = exam.unseenTeethFdi.contains(fdi);
    final sealant = exam.sealantNeededTeethFdi.contains(fdi);
    final upper =
        fdi ~/ 10 == 1 || fdi ~/ 10 == 2 || fdi ~/ 10 == 5 || fdi ~/ 10 == 6;
    final anterior = fdi % 10 <= 3;
    final seenIn = [
      if (anterior) 'Front · closed, Front · open',
      upper ? 'Upper teeth' : 'Lower teeth',
    ].join(' · ');
    final band = unseen
        ? SemanticBand.notAssessed
        : finding?.band ??
              (sealant ? SemanticBand.inValidation : SemanticBand.normal);
    final headline = unseen
        ? 'Not seen in this exam'
        : finding?.findingLabel ??
              (sealant ? 'Sound · sealant candidate' : 'Sound');
    final zonePhotos = r.photosForZone(upper ? 'Upper teeth' : 'Lower teeth');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AnaemiaUi.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AnaemiaUi.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: _thumb(zonePhotos.isNotEmpty ? zonePhotos.first : null),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tooth $fdi · ${fdiToothName(fdi)}',
                        style: const TextStyle(
                          color: AnaemiaUi.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    BandChip(
                      band: band,
                      compact: true,
                      customLabel: unseen
                          ? 'Not seen'
                          : finding == null
                          ? (sealant ? 'Sealant' : 'Sound')
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  headline,
                  style: const TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    'Seen in: $seenIn',
                    if (finding != null)
                      'Confidence: band only until validation (G-24)',
                    if (finding != null) 'Change: ${finding.changeVsPrevious}',
                    if (finding?.findingCode == 'white_spot')
                      'Early decay — fluoride varnish and twice-daily brushing can reverse it',
                    if (finding?.findingCode == 'cavity')
                      'Needs a filling — dentist within 4 weeks (T14)',
                    if (finding?.findingCode == 'abscess_sign')
                      'Infected tooth — dentist within 3 days (T13)',
                    if (sealant) 'Deep grooves — ask about a fissure sealant',
                  ].join('\n'),
                  style: const TextStyle(
                    color: AnaemiaUi.muted,
                    fontSize: 11,
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

  String _dateLabel(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';

  Widget _neonatalChartCard(NeonatalChartCard c) {
    final style = BandVisualStyle.forBand(r.band);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.chartApplies) ...[
            RangeGauge(
              scale: const RangeScale(
                breakpoints: [0, 0.60, 0.75, 1.0],
                labels: ['Below the line', 'Near', 'At / above'],
                colors: [
                  AnaemiaUi.segNormal,
                  AnaemiaUi.segBorder,
                  AnaemiaUi.segHigh,
                ],
              ),
              value: c.positionFraction,
              pinColor: style.foreground,
              showPin: r.band != SemanticBand.notAssessed,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            c.statusLine,
            style: const TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Line by age in hours (${c.bucketLabel}${c.hasRiskFactors ? ', with risk factors' : ''})',
            style: const TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in c.rows)
            _refRowPlain(
              '${row.$1} hours',
              '${row.$2.toStringAsFixed(1)} mg/dL',
              highlight:
                  (c.ageHours - row.$1).abs() <= 12 &&
                  c.rows.every(
                    (o) =>
                        (c.ageHours - o.$1).abs() >=
                        (c.ageHours - row.$1).abs(),
                  ),
            ),
          const SizedBox(height: 8),
          const InfoNote(
            icon: Icons.info_outline_rounded,
            text:
                'Stand-in copy of the AAP 2022 phototherapy thresholds sampled every 12 hours and interpolated. The reference-range master replaces it before clinical use. Babies under 35 weeks and over 28 days are referred to the clinic instead.',
          ),
        ],
      ),
    );
  }

  Widget _footRiskCard(FootRiskCard c) {
    final catBand = c.category >= 2
        ? SemanticBand.atRisk
        : c.category == 1
        ? SemanticBand.borderline
        : SemanticBand.normal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(
                Icons.directions_walk_rounded,
                AnaemiaUi.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.categoryLabel,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      c.recheck,
                      style: const TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BandChip(band: catBand, compact: true),
            ],
          ),
          const Divider(height: 22),
          for (final side in EyeSide.values) ...[
            Text(
              p.sideLabel(side),
              style: const TextStyle(
                color: AnaemiaUi.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            if ((c.perFootFindings[side] ?? const []).isEmpty)
              AnaemiaUi.bullet(
                r.perEyeBand[side] == SemanticBand.notAssessed
                    ? 'Not assessed'
                    : 'No callus, cracks, colour change or wound seen',
                icon: r.perEyeBand[side] == SemanticBand.notAssessed
                    ? Icons.help_outline_rounded
                    : Icons.check_circle_rounded,
              )
            else
              for (final f in c.perFootFindings[side]!)
                AnaemiaUi.bullet(
                  f,
                  icon:
                      f.toLowerCase().contains('ulcer') ||
                          f.toLowerCase().contains('redness')
                      ? Icons.error_rounded
                      : Icons.warning_amber_rounded,
                  color:
                      f.toLowerCase().contains('ulcer') ||
                          f.toLowerCase().contains('redness')
                      ? MirrorColors.dangerFg
                      : MirrorColors.warningFg,
                ),
            const SizedBox(height: 6),
          ],
          if (c.woundAreaCm2 != null) ...[
            const Divider(height: 18),
            Text(
              'Wound area · ${c.woundSite ?? ''}',
              style: const TextStyle(
                color: AnaemiaUi.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            RangeGauge(
              scale: const RangeScale(
                breakpoints: [0, 1.0, 3.0, 8.0],
                labels: ['Small < 1 cm²', '1–3 cm²', 'Large > 3 cm²'],
                colors: [
                  AnaemiaUi.segBorder,
                  AnaemiaUi.segHigh,
                  Color(0xFFF87171),
                ],
              ),
              value: c.woundAreaCm2!,
              pinColor: MirrorColors.dangerFg,
            ),
            const SizedBox(height: 4),
            Text(
              '${c.woundAreaCm2!.toStringAsFixed(1)} cm² measured with the card scale (ALG-CAP-10). The clinic re-measures weekly to track healing.',
              style: const TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          const InfoNote(
            icon: Icons.event_repeat_rounded,
            text:
                'The app asks for new foot photos every 30 days for people with diabetes (G-34). Daily self-checks: look between the toes and under the sole with a mirror; never walk barefoot.',
          ),
        ],
      ),
    );
  }

  Widget _skinMatchesCard(SkinMatchesCard c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < c.matches.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? AnaemiaUi.primary.withValues(alpha: 0.14)
                        : AnaemiaUi.outline,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i == 0 ? AnaemiaUi.primary : AnaemiaUi.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.matches[i].$1,
                        style: TextStyle(
                          color: AnaemiaUi.ink,
                          fontSize: 13,
                          fontWeight: i == 0
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                      Text(
                        c.matches[i].$2,
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
            ),
            if (i != c.matches.length - 1) const Divider(height: 16),
          ],
          const Divider(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ABCDE checklist',
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AnaemiaUi.tag(
                '${c.abcdeFlags.length} of 5 ticked',
                color: c.abcdeFlags.length >= 2
                    ? MirrorColors.dangerFg
                    : c.abcdeFlags.isEmpty
                    ? MirrorColors.successFg
                    : MirrorColors.warningFg,
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in c.abcdeItems)
            AnaemiaUi.bullet(
              item.$2,
              icon: c.abcdeFlags.contains(item.$1)
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: c.abcdeFlags.contains(item.$1)
                  ? MirrorColors.dangerFg
                  : AnaemiaUi.muted,
            ),
          const SizedBox(height: 8),
          AnaemiaUi.kvRow(
            'Spot size',
            c.lesionMm == null
                ? 'Not measured (no card or coin beside the spot)'
                : '${c.lesionMm!.toStringAsFixed(1)} mm across',
          ),
          if (c.bodyLocation != null)
            AnaemiaUi.kvRow('Location', c.bodyLocation!),
          if (c.duration != null) AnaemiaUi.kvRow('How long', c.duration!),
          const SizedBox(height: 8),
          const InfoNote(
            icon: Icons.photo_library_outlined,
            text:
                'Photograph the same spot again in 4 weeks from the same distance — change over time (E of ABCDE) is the strongest warning sign. A heat-map of the model\'s attention will appear here when the classifier ships.',
          ),
        ],
      ),
    );
  }

  Widget _refRowPlain(String k, String v, {bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AnaemiaUi.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? AnaemiaUi.accent.withValues(alpha: 0.5)
              : AnaemiaUi.outline,
        ),
      ),
      child: Row(
        children: [
          Icon(
            highlight ? Icons.child_care_rounded : Icons.circle,
            size: highlight ? 14 : 6,
            color: highlight ? AnaemiaUi.accent : AnaemiaUi.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              highlight ? '$k (this baby)' : k,
              style: TextStyle(
                color: highlight ? AnaemiaUi.accent : AnaemiaUi.ink,
                fontSize: 12,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            v,
            style: TextStyle(
              color: highlight ? AnaemiaUi.accent : AnaemiaUi.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. Reading scale ---------------------------------------------------

  Widget _scaleCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        style: TextStyle(
                          color: p.scale.bands[i] == r.band
                              ? AnaemiaUi.ink
                              : AnaemiaUi.muted,
                          fontSize: 10.5,
                          fontWeight: p.scale.bands[i] == r.band
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      BandChip(band: p.scale.bands[i], compact: true),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
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
          const SizedBox(height: 10),
          if (p.noNumberNote != null)
            InfoNote(
              icon: Icons.lock_outline_rounded,
              title: 'What the numbers mean',
              text: p.noNumberNote!,
            )
          else
            const InfoNote(
              icon: Icons.verified_user_rounded,
              title: 'Partner grades shown as given',
              text:
                  'The licensed partner AI returns ICDR grades and flags; the app displays them unchanged and adds the referral rules. A dilated eye exam confirms them.',
            ),
        ],
      ),
    );
  }

  Widget _refRow(String k, String v) {
    final isYou = _refRowMatches(k);
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
              : AnaemiaUi.outline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              isYou ? Icons.person_rounded : Icons.circle,
              size: isYou ? 14 : 6,
              color: isYou ? AnaemiaUi.accent : AnaemiaUi.muted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              isYou ? '$k (you)' : k,
              style: TextStyle(
                color: isYou ? AnaemiaUi.accent : AnaemiaUi.ink,
                fontSize: 12,
                fontWeight: isYou ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isYou ? AnaemiaUi.accent : AnaemiaUi.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Highlights the reference row that matches this result (fundus grades,
  /// jaundice threshold, cataract age rule, child white pupil).
  bool _refRowMatches(String key) {
    final k = key.toLowerCase();
    switch (p.id) {
      case 'eye_fundus':
        final worst = r.findings
            .where((f) => f.code.startsWith('DR_GRADE_'))
            .map((f) => f.valueText.toLowerCase())
            .toList();
        if (r.urgency == UrgencyLevel.urgent) return k.startsWith('pdr');
        if (k.startsWith('glaucoma')) {
          return r.findings.any(
            (f) => f.code == 'GLAUCOMA_SUSPECT' && f.band == SemanticBand.refer,
          );
        }
        if (k.startsWith('severe')) {
          return worst.any((w) => w.startsWith('severe'));
        }
        if (k.startsWith('moderate')) {
          return worst.any((w) => w.startsWith('moderate')) &&
              !worst.any((w) => w.startsWith('severe') || w.startsWith('pdr'));
        }
        if (k.startsWith('mild')) return r.band == SemanticBand.mild;
        if (k.startsWith('no dr')) return r.band == SemanticBand.normal;
        return false;
      case 'eye_jaundice':
        if (r.band == SemanticBand.high) {
          return k.startsWith('this screen flags');
        }
        if (r.band == SemanticBand.normal) return k.startsWith('normal');
        return false;
      case 'eye_cataract':
        if (r.answers.onRequest) return k.startsWith('on request');
        if (r.answers.operatedEyes.isNotEmpty && k.startsWith('operated')) {
          return true;
        }
        return k.startsWith('offered') && !r.answers.onRequest;
      case 'eye_child':
        if (r.urgency == UrgencyLevel.urgent) {
          return k.startsWith('white pupil');
        }
        if (r.band == SemanticBand.refer) return k.startsWith('flash dot');
        if (r.band == SemanticBand.normal) return k.startsWith('red reflex');
        return false;
      case 'body_newborn':
        final c = r.extraCard<NeonatalChartCard>();
        if (c == null) return false;
        if (!c.chartApplies) return k.startsWith('under 35');
        if (c.hasRiskFactors && k.startsWith('with risk')) return true;
        final nearest = ((c.ageHours / 24).round() * 24).clamp(24, 96);
        return k.startsWith('$nearest hours');
      case 'body_foot':
        final c = r.extraCard<FootRiskCard>();
        if (c == null) return false;
        if (r.band == SemanticBand.ulcer) return k.startsWith('open wound');
        return k.startsWith('${c.category} ·');
      case 'body_skin':
        final c = r.extraCard<SkinMatchesCard>();
        if (c == null) return false;
        final letter = k.isNotEmpty ? k[0] : '';
        final key = switch (letter) {
          'a' => 'asymmetry',
          'b' => 'border',
          'c' => 'colour',
          'd' => 'diameter',
          'e' => 'evolving',
          _ => '',
        };
        if (key.isNotEmpty && k.contains(' · ')) {
          return c.abcdeFlags.contains(key);
        }
        return k.startsWith('pearly') && r.band == SemanticBand.refer;
      case 'dental_oral':
        final c = r.extraCard<OralSitesCard>();
        if (c == null) return false;
        final nonHealing = r.answers.durationBucket == 'Over 3 weeks';
        final trismus = r.answers.questionIds.contains('trismus');
        if (r.band == SemanticBand.high) {
          return k.startsWith('mixed red-white') ||
              k.startsWith('ulcer not healed');
        }
        if (r.band == SemanticBand.suspicious) {
          return k.startsWith('white patch');
        }
        if (r.band == SemanticBand.refer) {
          return (nonHealing && k.startsWith('ulcer not healed')) ||
              (trismus && k.startsWith('stiff bands'));
        }
        if (r.band == SemanticBand.normal) return k.startsWith('even pink');
        return false;
      case 'dental_caries':
        final c = r.extraCard<DentalChartCard>();
        if (c == null) return false;
        final codes = c.exam.toothFindings.map((f) => f.findingCode).toSet();
        if (k.startsWith('white spot')) return codes.contains('white_spot');
        if (k.startsWith('enamel break')) return codes.contains('enamel_break');
        if (k.startsWith('cavity')) return codes.contains('cavity');
        if (k.startsWith('broken')) return codes.contains('broken_black');
        if (k.startsWith('abscess')) return codes.contains('abscess_sign');
        if (k.startsWith('low risk')) return r.band == SemanticBand.low;
        if (k.startsWith('moderate risk')) {
          return r.band == SemanticBand.moderate;
        }
        if (k.startsWith('high risk')) return r.band == SemanticBand.high;
        return false;
      default:
        return false;
    }
  }

  // --- 6. Inputs used -----------------------------------------------------

  Widget _inputsCard() {
    final a = r.answers;
    final ticked = a.ticked(p);
    final reliability = ticked.where((q) => q.affectsReliability).toList();
    final escalating = ticked.where((q) => q.escalates).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnaemiaUi.kvRow(
            'Person',
            '${r.subjectName} · ${r.ageLabel} · ${r.sex.label}',
          ),
          if (p.newbornOnly) ...[
            AnaemiaUi.kvRow(
              'Baby',
              '${r.extraCard<NeonatalChartCard>()?.ageHours ?? a.newbornAgeHours ?? '?'} hours old · born at ${r.extraCard<NeonatalChartCard>()?.gestationWeeks ?? a.gestationWeeks ?? '?'} weeks${a.birthWeightKg != null ? ' · ${a.birthWeightKg!.toStringAsFixed(1)} kg' : ''}',
            ),
          ],
          AnaemiaUi.kvRow(
            'Eligibility',
            '${p.eligibilityLabel()}${a.onRequest ? ' · taken on request (G-09)' : ''}${p.recheckLabel != null ? ' · ${p.recheckLabel!.toLowerCase()}' : ''}',
          ),
          AnaemiaUi.kvRow(
            'Photos',
            '${r.acceptedPhotoCount} of ${p.photoCount} accepted · ${p.views.any((v) => v.flash ?? p.flash)
                ? (p.views.every((v) => v.flash ?? p.flash) ? 'flash on' : 'flash on some shots')
                : p.partnerModel
                ? 'camera-lit'
                : 'flash off'} · ${r.retakeTotal} retake${r.retakeTotal == 1 ? '' : 's'}',
          ),
          if (p.extraInputs.contains(EyeExtraInput.tobaccoStatus))
            AnaemiaUi.kvRow(
              'Tobacco / areca',
              '${a.tobaccoStatus ?? 'Not recorded'}${a.usesTobacco ? ' · recommended every 6 months (G-10)' : ''}',
            ),
          if (a.bodyLocation != null)
            AnaemiaUi.kvRow('Location of the spot', a.bodyLocation!),
          if (a.durationBucket != null)
            AnaemiaUi.kvRow(
              p.id == 'dental_oral' ? 'Noticed' : 'How long',
              a.durationBucket!,
            ),
          if (p.extraInputs.contains(EyeExtraInput.dentalHabits)) ...[
            AnaemiaUi.kvRow(
              'Brushing',
              a.brushingPerDay == null
                  ? 'Not answered'
                  : a.brushingPerDay == 0
                  ? 'Not daily'
                  : a.brushingPerDay == 1
                  ? 'Once a day'
                  : 'Twice or more a day',
            ),
            AnaemiaUi.kvRow('Fluoride toothpaste', switch (a.fluoridePaste) {
              'yes' => 'Yes',
              'no' => 'No',
              'unknown' => "Don't know (scored as no)",
              _ => 'Not answered',
            }),
            AnaemiaUi.kvRow(
              'Sweets / sugary drinks',
              a.sweetsPerDay == null
                  ? 'Not answered'
                  : '${a.sweetsPerDay! >= 5 ? '5 or more' : a.sweetsPerDay} a day',
            ),
            if (r.ageYears < 6)
              AnaemiaUi.kvRow(
                'Night feeding',
                a.nightFeeding ? 'Yes — bottle or breast in bed' : 'No',
              ),
            AnaemiaUi.kvRow(
              'Last dentist visit',
              a.lastDentalVisit ?? 'Not answered',
            ),
          ],
          if (a.skinType != null)
            AnaemiaUi.kvRow('Skin type', 'Fitzpatrick ${a.skinType}'),
          if (p.extraInputs.contains(EyeExtraInput.abcde))
            AnaemiaUi.kvRow(
              'ABCDE signs',
              a.abcdeFlags.isEmpty ? 'None ticked' : a.abcdeFlags.join(', '),
            ),
          if (p.cardOffered)
            AnaemiaUi.kvRow(
              'Colour card',
              a.hasColourCard
                  ? 'Used · ΔE ${(a.colourErrorDe ?? 0).toStringAsFixed(1)} (≤ 5 pass, ALG-CAP-10)'
                  : 'Not used',
            ),
          if (p.guardianRequired || a.photographerRole != null)
            AnaemiaUi.kvRow(
              'Photo taken by',
              a.photographerRole ?? 'Not recorded',
            ),
          if (p.partnerModel)
            AnaemiaUi.kvRow(
              'Partner sharing',
              a.partnerConsent
                  ? 'Agreed · de-identified images only'
                  : 'Not agreed',
            ),
          if (a.operatedEyes.isNotEmpty)
            AnaemiaUi.kvRow(
              'Operated ${p.partNoun}',
              a.operatedEyes.map(p.sideLabel).join(' and '),
            ),
          AnaemiaUi.kvRow(
            'Questions',
            ticked.isEmpty
                ? (a.questionIds.contains('none')
                      ? 'None of these'
                      : 'Not answered')
                : ticked.map((q) => q.label).join(' · '),
          ),
          if (a.otherNote != null) AnaemiaUi.kvRow('Your note', a.otherNote!),
          AnaemiaUi.kvRow(
            'Consent',
            a.consentGiven
                ? '${p.consentType == ConsentType.dentalGuardian
                      ? 'Dental${a.photographerRole != null ? ' & guardian' : ''}'
                      : p.guardianRequired
                      ? 'Guardian'
                      : 'Screening'} consent given (${p.consentType.gateCode})'
                : 'Not recorded',
          ),
          if (reliability.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoNote(
              icon: Icons.warning_amber_rounded,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              title: 'May affect this result',
              text: reliability.map((q) => q.note).join(' '),
            ),
          ],
          if (escalating.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoNote(
              icon: Icons.priority_high_rounded,
              color: MirrorColors.dangerFg,
              background: MirrorColors.dangerBg,
              title: 'Reported risk factors',
              text: escalating.map((q) => q.note).join(' '),
            ),
          ],
        ],
      ),
    );
  }

  // --- 7. Photo quality ---------------------------------------------------

  Widget _photoQualityCard() {
    final qualityOk = r.captureQualityScore >= 0.7;
    final covLabel = switch (p.views.first.target.coverageLabel) {
      'White of eye' => 'White',
      'Pupil found' => 'Pupil',
      'Both pupils' => 'Pupils',
      'Retina area' => 'Retina',
      'Skin area' => 'Skin',
      'Foot in frame' => 'Foot',
      'Spot centred' => 'Spot',
      'Mouth lining in frame' => 'Lining',
      'Teeth in frame' => 'Teeth',
      _ => 'Lid',
    };
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
                  _th(covLabel),
                  _th('Tries', align: TextAlign.right),
                ],
              ),
              for (final x in r.photos) _photoRow(x),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p.partnerModel
                ? 'Gradability proxy: sharpness ≥ 100 · glare ≤ 5 % · dark ≤ 10 % · retina area ≥ 80 %. The partner\'s own gradability flag replaces this when the SDK is wired. Up to 3 attempts per view (G-25).'
                : 'Pass rules: sharpness ≥ 100 (ALG-CAP-06) · glare ≤ 5 % and dark ≤ 10 % (CAP-07) · image quality ≥ 0.70 (CAP-08) · ${p.views.first.target.coverageLabel.toLowerCase()} ≥ 80 % (CAP-09). Up to 3 attempts per photo (G-25).',
            style: const TextStyle(
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AnaemiaUi.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  TableRow _photoRow(EyePhoto x) {
    final q = x.quality;
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
        color: x.accepted
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
              x.shortLabel,
              color: x.accepted ? AnaemiaUi.primary : MirrorColors.dangerFg,
            ),
          ),
        ),
        cell(q.blurScore.round().toString(), q.blurPassed),
        cell('${q.glarePct.toStringAsFixed(1)}%', q.glarePassed),
        cell('${q.darkPct.toStringAsFixed(1)}%', q.darkPassed),
        cell('${q.coveragePct.round()}%', q.coveragePassed),
        Text(
          x.accepted ? '${x.attempts}×' : 'N/A',
          textAlign: TextAlign.right,
          style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11),
        ),
      ],
    );
  }

  // --- 8. How this result is made ----------------------------------------

  Widget _howMadeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        children: [
          for (var i = 0; i < p.howMade.length; i++)
            AnaemiaUi.numberedStep(i + 1, p.howMade[i].$1, p.howMade[i].$2),
        ],
      ),
    );
  }

  // --- 9. How to read it --------------------------------------------------

  SemanticBand get _highlightBand => r.highlightBand;

  Widget _howToReadCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in p.bands) _readRow(b),
          const Divider(height: 20),
          AnaemiaUi.bullet(
            'Confidence = photo quality × model confidence. Results under 60 % are hidden (G-23).',
            icon: Icons.speed_rounded,
          ),
          AnaemiaUi.bullet(
            p.partnerModel
                ? 'Partner grades are licensed results shown as given; the app adds only the referral rules and specialist routing.'
                : '“In clinical validation” means the model has not yet passed its study, so only a band — never a number — is shown (G-24).',
            icon: Icons.science_outlined,
          ),
          AnaemiaUi.bullet(
            'This is a screening band, not a diagnosis. Your doctor\'s or lab\'s findings take precedence.',
            icon: Icons.health_and_safety_outlined,
          ),
        ],
      ),
    );
  }

  Widget _readRow(EyeBandInfo info) {
    final isThis = info.band == _highlightBand;
    final style = BandVisualStyle.forBand(info.band);
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
                BandChip(
                  band: info.band,
                  compact: true,
                  customLabel: info.title,
                ),
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
              info.meaning,
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

  // --- 10. Checked by -----------------------------------------------------

  Widget _checkedByCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        children: [
          _checkedRow(
            Icons.phone_android_rounded,
            const Color(0xFF2563EB),
            p.partnerModel ? 'Gradability checks' : 'On-device quality checks',
            p.partnerModel
                ? 'Every image checked for focus, exposure and retina area before upload (partner CAP-08 equivalent)'
                : 'ALG-CAP-06 blur · CAP-07 glare/dark · CAP-08 image quality · CAP-09 ${p.views.first.target.coverageLabel.toLowerCase()}${p.cardOffered ? ' · CAP-10 colour card' : ''}',
            'Passed ${r.acceptedPhotoCount}/${p.photoCount}',
            r.acceptedPhotoCount == p.photoCount
                ? MirrorColors.successFg
                : MirrorColors.warningFg,
          ),
          const Divider(height: 18),
          _checkedRow(
            p.partnerModel ? Icons.handshake_rounded : Icons.memory_rounded,
            AnaemiaUi.primary,
            p.algorithmName,
            '${p.algorithmId} ${p.algorithmVersion} · ranges ${p.rangeVersion}',
            p.partnerModel ? 'Licensed partner' : 'In validation',
            MirrorColors.infoFg,
          ),
          const Divider(height: 18),
          _checkedRow(
            Icons.how_to_reg_rounded,
            const Color(0xFF7C3AED),
            'Specialist reviewer (IMG-10)',
            r.specialistReviewRequired
                ? 'De-identified photos, quality metrics and model outputs are queued. Status updates here and in History.'
                : 'Review is required only for High / Refer bands or probabilities within ±0.10 of the threshold.',
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

  // --- 11. Next steps -----------------------------------------------------

  List<ConfirmatoryInvestigationSpec> get _specs {
    final flagged = {
      SemanticBand.high,
      SemanticBand.refer,
      SemanticBand.borderline,
      SemanticBand.atRisk,
      SemanticBand.ulcer,
      SemanticBand.suspicious,
      SemanticBand.moderate,
    }.contains(r.band);
    if (p.id == 'dental_caries') {
      final gumHigh = r.findings.any(
        (f) => f.code == 'GUM_INFLAM_BAND' && f.band == SemanticBand.high,
      );
      return [
        if (flagged) ConfirmatoryInvestigationsRegistry.forCode('COND_CARIES'),
        if (gumHigh)
          ConfirmatoryInvestigationsRegistry.forCode('COND_GUM_DISEASE'),
      ];
    }
    if (!flagged) return const [];
    if (p.id != 'eye_fundus') {
      return [ConfirmatoryInvestigationsRegistry.forCode(p.conditionCode)];
    }
    final out = <ConfirmatoryInvestigationSpec>[];
    final referable = r.findings.any(
      (f) => f.code == 'DR_REFERABLE' && f.valueText == 'Yes',
    );
    final glaucoma = r.findings.any(
      (f) => f.code == 'GLAUCOMA_SUSPECT' && f.band == SemanticBand.refer,
    );
    if (referable) {
      out.add(ConfirmatoryInvestigationsRegistry.forCode('COND_DR'));
    }
    if (glaucoma) {
      out.add(ConfirmatoryInvestigationsRegistry.forCode('COND_GLAUCOMA'));
    }
    return out;
  }

  Widget _nextStepsCard() {
    final specs = _specs;
    final urgent = r.urgency == UrgencyLevel.urgent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (specs.isNotEmpty) ...[
            for (var i = 0; i < specs.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              _specBlock(specs[i], urgent),
            ],
            const SizedBox(height: 8),
            AnaemiaUi.bullet(
              'Enter the result in the app (S-R06) to close the case and improve your baseline.',
              icon: Icons.edit_note_rounded,
            ),
          ] else if (r.band == SemanticBand.notAssessed) ...[
            for (var i = 0; i < p.nextStepsNotAssessed.length; i++)
              AnaemiaUi.bullet(
                p.nextStepsNotAssessed[i],
                icon: i == 0
                    ? Icons.replay_rounded
                    : Icons.local_hospital_outlined,
              ),
          ] else ...[
            for (var i = 0; i < p.nextStepsNormal.length; i++)
              AnaemiaUi.bullet(
                p.nextStepsNormal[i],
                icon: i == 0
                    ? Icons.event_repeat_rounded
                    : Icons.medical_information_outlined,
              ),
          ],
          if (r.isPartiallyAssessed) ...[
            const SizedBox(height: 8),
            InfoNote(
              icon: Icons.visibility_off_outlined,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              text:
                  '${r.notAssessedEyes.map(p.sideLabel).join(' and ')} could not be assessed; the band is based on the other ${p.partNoun}. Retake for a stronger result.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _specBlock(ConfirmatoryInvestigationSpec spec, bool urgent) {
    final urgencyText = urgent
        ? 'Urgent — within days.'
        : spec.defaultUrgency == UrgencyLevel.urgent
        ? 'Urgent — within ${spec.maxPairingGapLabel.replaceAll('<= ', '')}.'
        : 'Routine — within ${spec.maxPairingGapLabel.replaceAll('<= ', '')}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnaemiaUi.iconTile(Icons.biotech_rounded, AnaemiaUi.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm: ${spec.markerOrScreenName}',
                    style: const TextStyle(
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
          '${spec.pairingReferenceTest} within ${spec.maxPairingGapLabel.replaceAll('<= ', '')}; ${spec.pairingExclusions == 'None' ? 'no exclusions' : 'not valid after ${spec.pairingExclusions.toLowerCase()}'}.',
        ),
      ],
    );
  }

  // --- 12. Quality & versions --------------------------------------------

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
              '${p.algorithmId} ${p.algorithmVersion} · ${p.partnerModel ? 'partner result (displayed)' : 'release: bandOnly (G-24)'}',
            ),
            AnaemiaUi.kvRow('Range version', p.rangeVersion),
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
            AnaemiaUi.kvRow(
              'Demo outcome',
              '${p.demoOutcomeLabels[r.demoOutcome.name] ?? r.demoOutcome.name} · static model stand-in',
            ),
            if (r.internalFindings.isNotEmpty) ...[
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
              for (final f in r.internalFindings)
                AnaemiaUi.kvRow(f.code, '${f.valueText} · ${f.label}'),
            ],
            AnaemiaUi.kvRow(
              'Proxies',
              'Part coverage and image-quality scores are pixel proxies for CAP-08/09 until the classifiers ship.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed box over a thumbnail marking the region the oral classifier
/// flagged (stand-in for the Spec `lesion_regions` overlay).
class _LesionBoxPainter extends CustomPainter {
  const _LesionBoxPainter({required this.box, required this.color});

  final (double, double, double, double) box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      box.$1 * size.width,
      box.$2 * size.height,
      box.$3 * size.width,
      box.$4 * size.height,
    );
    canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.18));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()..addRect(r);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + 4).clamp(0, m.length)), p);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LesionBoxPainter old) =>
      old.box != box || old.color != color;
}
