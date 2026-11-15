import 'package:flutter/material.dart';

import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/algorithms/vision_engines.dart';
import '../../core/domain/entities/case_record.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/marker_catalogue.dart';
import '../../core/domain/entities/vision_protocol.dart';
import '../../core/domain/entities/vision_result.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'amsler_grid_view.dart' show AmslerPainter;
import 'colour_plate_view.dart' show ColourPlateReplica;
import 'vision_capture_screen.dart';

/// S-R01 result for a vision test (T-RES): urgency → hero sentence → per
/// eye / block with document-only gauges → algorithm outputs → what the
/// numbers mean → reference → personal baseline → next steps (§13) →
/// quality & versions → disclaimer; Save / Retake.
class VisionResultScreen extends StatefulWidget {
  const VisionResultScreen({super.key, required this.result});

  final VisionSessionResult result;

  @override
  State<VisionResultScreen> createState() => _VisionResultScreenState();
}

class _VisionResultScreenState extends State<VisionResultScreen> {
  static const double _gap = 20;
  bool _saved = false;
  VoiceCoachController? _voice;

  VisionSessionResult get r => widget.result;
  VisionProtocol get p => widget.result.protocol;

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

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Scaffold(
      backgroundColor: MirrorColors.backgroundLight,
      appBar: AppBar(
        title: Text(p.resultTitle),
        actions: [
          IconButton(
            tooltip: 'Read aloud',
            icon: const Icon(Icons.record_voice_over_rounded),
            onPressed: () => _voice?.announce(
              '${p.shortTitle} result for ${r.subjectName}. ${r.bandSubline}. ${r.whatItMeans}',
              tone: VoiceCueTone.completed,
              force: true,
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
            if (r.urgency != UrgencyLevel.none) ...[
              UrgencyBanner(
                urgency: r.urgency,
                title: r.urgency == UrgencyLevel.urgent
                    ? 'Urgent — ${p.shortTitle}'
                    : 'Routine follow-up — ${p.shortTitle}',
                subtitle: r.bandSubline,
                ruleCodes: r.firedRuleCodes,
              ),
              const SizedBox(height: 12),
            ],
            _heroCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              p.perEye
                  ? 'Each eye'
                  : p.kind == VisionTestKind.reaction
                  ? 'Each block'
                  : 'Your number',
              'Against the line in the algorithm document',
            ),
            _partsCard(),
            if (_plateReview.isNotEmpty) ...[
              const SizedBox(height: _gap),
              AnaemiaUi.sectionHeader(
                'Plate review',
                'Every plate with its number revealed, next to what you answered',
              ),
              _plateReviewCard(),
            ],
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Algorithm outputs',
              'Every output marker of ${p.algorithmId} (Spec §9) with the value measured',
            ),
            AlgorithmOutputsSection(
              groups: MarkerReadings.fromVision(r),
              showHeader: false,
            ),
            const SizedBox(height: 12),
            _meaningsCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              p.referenceTitle,
              'Document values first; research references marked [DER]',
            ),
            _referenceCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Your personal baseline',
              'Spec §10 RSK-03 / RSK-04 · median of your last 3 tests within 180 days',
            ),
            _baselineCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Next steps',
              'Confirmatory steps from Spec §13',
            ),
            _nextStepsCard(),
            const SizedBox(height: _gap),
            _qualityExpander(),
            const SizedBox(height: 16),
            const DisclaimerFooter(),
          ],
        ),
      ),
      bottomNavigationBar: PrimaryBottomButton(
        label: _saved ? 'Saved' : 'Save to profile',
        icon: _saved ? Icons.check_rounded : Icons.save_alt_rounded,
        secondaryLabel: 'Retake',
        onSecondary: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                VisionCaptureScreen(protocol: p, startAtHowTo: true),
          ),
        ),
        onPressed: _saved
            ? null
            : () {
                appState.saveVisionSession(r);
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

  // --- hero --------------------------------------------------------------

  Widget _heroCard() {
    final style = BandVisualStyle.forBand(r.band);
    final rec = r.recordedAt;
    final time =
        '${rec.day.toString().padLeft(2, '0')}/${rec.month.toString().padLeft(2, '0')}/${rec.year} · '
        '${rec.hour.toString().padLeft(2, '0')}:${rec.minute.toString().padLeft(2, '0')}';
    final assessed = r.parts.where((x) => x.assessed).length;
    final meta = p.perEye
        ? '$time · $assessed of 2 eyes'
        : p.kind == VisionTestKind.reaction
        ? '$time · $assessed of 2 blocks'
        : time;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(_icon, AnaemiaUi.primary, size: 44),
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
                      meta,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BandChip(
                        band: r.band,
                        compact: true,
                        customLabel: r.bandTitle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r.bandSubline,
                        style: TextStyle(
                          color: style.foreground,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Measured: ${r.heroLabel} · ${r.heroCode}',
                        style: TextStyle(
                          color: style.foreground.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
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
                  child: Icon(style.icon, color: style.foreground, size: 30),
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
              if (p.kind == VisionTestKind.acuity)
                AnaemiaUi.tag(
                  switch (r.quality.distanceMode) {
                    'measured' => 'Distance measured (calibrated)',
                    'estimated' => 'Distance estimated [DER]',
                    _ => 'Distance not measured — manual 40 cm',
                  },
                  color: r.quality.distanceMode == 'measured'
                      ? MirrorColors.successFg
                      : MirrorColors.warningFg,
                  icon: Icons.social_distance_rounded,
                ),
              if (r.quality.simulated)
                AnaemiaUi.tag(
                  'Simulated input',
                  color: MirrorColors.infoFg,
                  icon: Icons.tune_rounded,
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

  IconData get _icon => switch (p.kind) {
    VisionTestKind.acuity => Icons.remove_red_eye_rounded,
    VisionTestKind.colour => Icons.palette_rounded,
    VisionTestKind.amsler => Icons.grid_on_rounded,
    VisionTestKind.reaction => Icons.bolt_rounded,
  };

  // --- parts -------------------------------------------------------------

  Widget _partsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < r.parts.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            _partRow(r.parts[i]),
          ],
          const SizedBox(height: 10),
          Text(
            _caption,
            style: const TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  String get _caption => switch (p.kind) {
    VisionTestKind.acuity =>
      'Line from the document: 0.2 logMAR or better is normal (≈ 6/9.5) (Spec §9).',
    VisionTestKind.colour =>
      'Line from the document: all plates correct is normal (Spec §9). Plates are drawn in-app [DER].',
    VisionTestKind.amsler =>
      'Line from the document: no distortion marked is normal (Spec §9).',
    VisionTestKind.reaction =>
      'No cut-off in the document yet (age norms pending); values are kept for your own baseline.',
  };

  Widget _partRow(VisionPartResult s) {
    final gauge = _gaugeFor(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.label,
                style: const TextStyle(
                  color: AnaemiaUi.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            BandChip(
              band: s.band,
              compact: true,
              customLabel: s.skipped ? 'Not assessed (skipped)' : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          s.note,
          style: const TextStyle(
            color: AnaemiaUi.muted,
            fontSize: 12,
            height: 1.3,
          ),
        ),
        if (gauge != null) ...[const SizedBox(height: 10), gauge],
        if (p.kind == VisionTestKind.colour && s.plateReview.isNotEmpty) ...[
          const SizedBox(height: 10),
          AnaemiaUi.kvRow(
            'Red–green screening plates',
            '${_i(s.values['SCREENING_CORRECT'])} of ${_i(s.values['SCREENING_TOTAL'])} read',
          ),
          AnaemiaUi.kvRow(
            'Control plates',
            '${_i(s.values['CONTROL_CORRECT'])} of ${_i(s.values['CONTROL_TOTAL'])} read${s.values['CONTROL_CORRECT'] == s.values['CONTROL_TOTAL'] ? ' · screen OK' : ' · check the screen'}',
          ),
          if (s.values['MEDIAN_RESPONSE_MS'] != null)
            AnaemiaUi.kvRow(
              'Median time per plate',
              '${(s.values['MEDIAN_RESPONSE_MS']! / 1000).toStringAsFixed(1)} s',
            ),
        ],
        if (s.amsler != null && s.assessed) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: AmslerPainter(
                    marks: s.amsler!,
                    lineColor: const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.amsler!.abnormal
                      ? 'Red = the squares you marked.${s.amsler!.centralInvolved ? ' The marked area includes the centre of vision.' : ''}'
                      : 'Nothing marked in this eye.',
                  style: const TextStyle(
                    color: AnaemiaUi.muted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<PlateReviewItem> get _plateReview =>
      r.parts.expand((x) => x.plateReview).toList();

  /// Colour plates: 12 tiles, number revealed, answer and tick / cross.
  Widget _plateReviewCard() {
    final items = _plateReview;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              const cols = 4;
              final w = (c.maxWidth - 8 * (cols - 1)) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final it in items)
                    SizedBox(
                      key: ValueKey('vis_review_${it.index}'),
                      width: w,
                      child: _plateTile(it, w),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Numbers are revealed only after the test (white outline). "C" marks the two control plates that everyone can read; the other ten are red–green screening plates in three colour pairs [DER].',
            style: TextStyle(color: AnaemiaUi.muted, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _plateTile(PlateReviewItem it, double w) {
    final ok = it.correct;
    final fg = ok ? AnaemiaUi.segNormal : AnaemiaUi.segHigh;
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ColourPlateReplica(plate: it.plate, size: w, revealDigit: true),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: fg,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  ok ? Icons.check_rounded : Icons.close_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
            if (it.isControl)
              Positioned(
                left: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AnaemiaUi.ink,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'C',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '#${it.index + 1} · ${it.digit}',
          style: const TextStyle(
            color: AnaemiaUi.ink,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          ok ? 'you: ${it.digit}' : 'you: ${it.answered ?? 'none'}',
          style: TextStyle(
            color: fg,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget? _gaugeFor(VisionPartResult s) {
    if (!s.assessed) return null;
    final style = BandVisualStyle.forBand(s.band);
    switch (p.kind) {
      case VisionTestKind.acuity:
        final v = s.values['LOGMAR'];
        if (v == null) return null;
        return RangeGauge(
          scale: const RangeScale(
            breakpoints: [-0.3, 0.2, 0.5, 1.3],
            labels: ['≤ 0.2 normal', '0.3–0.5', '> 0.5 refer'],
            colors: [
              AnaemiaUi.segNormal,
              AnaemiaUi.segBorder,
              AnaemiaUi.segHigh,
            ],
          ),
          value: v,
          pinColor: style.foreground,
        );
      case VisionTestKind.colour:
        final v = s.values['COLOUR_PLATE_SCORE'];
        if (v == null) return null;
        return RangeGauge(
          scale: const RangeScale(
            breakpoints: [0, 9, 12, 12.01],
            labels: ['≤ 9 refer', '10–11 repeat', '12 normal'],
            colors: [
              AnaemiaUi.segHigh,
              AnaemiaUi.segBorder,
              AnaemiaUi.segNormal,
            ],
          ),
          value: v,
          pinColor: style.foreground,
        );
      case VisionTestKind.amsler:
      case VisionTestKind.reaction:
        return null;
    }
  }

  // --- meanings / reference / baseline / next steps ------------------------

  Widget _meaningsCard() {
    final entries = p.markerMeanings.entries.toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What the numbers mean',
            style: TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.circle, size: 7, color: AnaemiaUi.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${MarkerCatalogue.byCode(entries[i].key)?.label ?? entries[i].key} — ',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: entries[i].value),
                      ],
                    ),
                    style: const TextStyle(
                      color: AnaemiaUi.ink,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (p.kind == VisionTestKind.acuity) ...[
            const SizedBox(height: 8),
            Text(
              'Snellen guide [DER]: ${[0.0, 0.2, 0.3, 0.5, 1.0].map((l) => '${l.toStringAsFixed(1)} = ${Optotype.snellen(l)}').join(' · ')}',
              style: const TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _referenceCard() {
    final doc = p.referenceRows.where((x) => x.provenance != 'DER');
    final der = p.referenceRows.where((x) => x.provenance == 'DER');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in doc) AnaemiaUi.kvRow(row.label, row.value),
          if (der.isNotEmpty) ...[
            const Divider(height: 16),
            for (final row in der)
              AnaemiaUi.kvRow('${row.label} [DER]', row.value),
          ],
          const SizedBox(height: 6),
          InfoNote(text: p.referenceNote),
        ],
      ),
    );
  }

  Widget _baselineCard() {
    final b = r.baseline;
    final unit = switch (p.kind) {
      VisionTestKind.acuity => 'logMAR',
      VisionTestKind.colour => 'plates',
      VisionTestKind.amsler => '',
      VisionTestKind.reaction => 'ms',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: p.kind == VisionTestKind.amsler
          ? const Text(
              'The Amsler check is yes / no, so no baseline is built; compare the marked areas with your earlier results in History.',
              style: TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          : b == null || !b.hasBaseline
          ? const Text(
              'No baseline yet — save at least 3 tests within 180 days and the app will compare each new result with your own median (RSK-03) and flag a meaningful change (RSK-04).',
              style: TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnaemiaUi.kvRow(
                  'Baseline',
                  '${b.baselineMedian!.toStringAsFixed(p.kind == VisionTestKind.acuity ? 1 : 0)} $unit (median of last 3)',
                ),
                AnaemiaUi.kvRow(
                  'This test',
                  '${r.heroValue!.toStringAsFixed(p.kind == VisionTestKind.acuity ? 1 : 0)} $unit',
                ),
                AnaemiaUi.kvRow(
                  'Change',
                  '${b.changePct!.toStringAsFixed(0)} % · ${b.isMeaningfulChange ? 'meaningful change (RSK-04)' : 'within your usual range'}',
                ),
              ],
            ),
    );
  }

  Widget _nextStepsCard() {
    final spec =
        ConfirmatoryInvestigationsRegistry.byCondition[p.conditionCode];
    final flagged = r.urgency != UrgencyLevel.none && spec != null;
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
                      Text(
                        'Confirm: ${spec.markerOrScreenName}',
                        style: const TextStyle(
                          color: AnaemiaUi.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${spec.defaultUrgency.label} — within ${spec.maxPairingGapLabel.replaceAll('<= ', '')}.',
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
              'Pair with this test',
              '${spec.pairingReferenceTest} within ${spec.maxPairingGapLabel.replaceAll('<= ', '')}; not valid after ${spec.pairingExclusions.toLowerCase()}.',
            ),
            const SizedBox(height: 6),
            AnaemiaUi.bullet(
              'A case was opened under ${p.conditionCode}; enter the clinician result (S-R06) to close it.',
              icon: Icons.folder_open_rounded,
            ),
          ] else if (r.isNotAssessed) ...[
            AnaemiaUi.bullet(
              'Check the setup steps and repeat the test.',
              icon: Icons.replay_rounded,
            ),
            if (p.kind == VisionTestKind.colour)
              AnaemiaUi.bullet(
                'Turn off night mode and colour filters, set brightness to full, clean the screen.',
                icon: Icons.brightness_high_rounded,
              ),
          ] else ...[
            AnaemiaUi.bullet(
              'No confirmatory test is needed from this result.',
              icon: Icons.check_circle_rounded,
            ),
            AnaemiaUi.bullet(
              p.kind == VisionTestKind.amsler
                  ? 'Repeat monthly if you are over 50 or have diabetes, and sooner if lines start to look wavy.'
                  : 'Repeat in about 6 months, or sooner if you notice a change, to build your baseline.',
              icon: Icons.event_repeat_rounded,
            ),
          ],
          if (r.isPartiallyAssessed) ...[
            const SizedBox(height: 8),
            const InfoNote(
              icon: Icons.visibility_off_outlined,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              text:
                  'One side was not assessed; the result rests on the other. Retake for a complete result.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _qualityExpander() {
    final q = r.quality;
    final acuityTrials = r.parts.expand((x) => x.trials).toList();
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
            'Distance, screen scale, brightness, trials, algorithm and rules (operator view)',
            style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            AnaemiaUi.kvRow('Session', r.sessionId),
            AnaemiaUi.kvRow(
              'Algorithm',
              '${p.algorithmId} ${p.algorithmVersion} · release: in validation (G-24)',
            ),
            AnaemiaUi.kvRow('Range version', p.rangeVersion),
            AnaemiaUi.kvRow(
              'Rules fired',
              r.firedRuleCodes.isEmpty ? 'None' : r.firedRuleCodes.join(', '),
            ),
            AnaemiaUi.kvRow(
              'Result confidence',
              '${r.confidence.toStringAsFixed(2)} = capture ${q.captureQualityScore.toStringAsFixed(2)} × model 0.90 (hidden below 0.60, G-23)',
            ),
            if (p.kind == VisionTestKind.acuity) ...[
              AnaemiaUi.kvRow(
                'Distance',
                '${q.distanceMode}${q.meanDistanceCm != null ? ' · mean ${q.meanDistanceCm!.toStringAsFixed(0)} cm' : ''}${q.distanceInRangePct != null ? ' · ${q.distanceInRangePct!.toStringAsFixed(0)} % of letters within 35–45 cm' : ''}',
              ),
              AnaemiaUi.kvRow(
                'Distance method',
                'Eye-landmark spacing (IPD 63 mm) through a pinhole model [DER]; document specifies MediaPipe Iris (11.7 mm) with a per-device focal length',
              ),
              AnaemiaUi.kvRow('Letters shown', acuityTrials.length.toString()),
            ],
            if (p.kind != VisionTestKind.reaction)
              AnaemiaUi.kvRow(
                'Screen scale',
                '${q.dpiSource}${q.dpi != null ? ' · ${q.dpi!.toStringAsFixed(0)} dpi' : ''}',
              ),
            if (p.needsMaxBrightness)
              AnaemiaUi.kvRow('Brightness', q.brightnessMode),
            AnaemiaUi.kvRow('Trials', '${q.trials}'),
            if (p.kind == VisionTestKind.reaction)
              AnaemiaUi.kvRow('False starts replaced', '${q.falseStarts}'),
            if (p.kind == VisionTestKind.colour) ...[
              AnaemiaUi.kvRow(
                'Control plates',
                q.controlPlateFailed ? 'failed' : 'passed',
              ),
              AnaemiaUi.kvRow(
                'Plate set',
                '12 drawn in-app [DER]: ${_plateReview.where((x) => x.plate.type == PlateType.a).length} type A, ${_plateReview.where((x) => x.plate.type == PlateType.b).length} type B, ${_plateReview.where((x) => x.plate.type == PlateType.c).length} type C, 2 control · numerals 1–9, matched lightness levels',
              ),
              if (q.medianResponseMs != null)
                AnaemiaUi.kvRow(
                  'Median response',
                  '${(q.medianResponseMs! / 1000).toStringAsFixed(1)} s per plate',
                ),
              AnaemiaUi.kvRow(
                'Answers',
                _plateReview
                    .map((x) => '${x.digit}${x.correct ? '✓' : '✗'}')
                    .join(' '),
              ),
            ],
            AnaemiaUi.kvRow('Retakes', '${q.retakes} (G-25 max 3)'),
            AnaemiaUi.kvRow('Input', q.simulated ? 'simulated' : 'member'),
            if (acuityTrials.isNotEmpty)
              AnaemiaUi.kvRow(
                'Staircase',
                acuityTrials
                    .map(
                      (t) =>
                          '${t.logMar.toStringAsFixed(1)}${t.correct ? '✓' : '✗'}',
                    )
                    .join(' '),
              ),
          ],
        ),
      ),
    );
  }
}

String _i(double? v) => v == null ? '—' : v.toStringAsFixed(0);
