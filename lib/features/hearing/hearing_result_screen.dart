import 'package:flutter/material.dart';

import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/hearing_engines.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/entities/case_record.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/hearing_protocol.dart';
import '../../core/domain/entities/hearing_result.dart';
import '../../core/domain/entities/marker_catalogue.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'audiogram_painter.dart';
import 'hearing_capture_screen.dart';

/// S-G11 Hearing Results (T-RES): urgency → hero sentence → audiogram per
/// ear with document-only lines → algorithm outputs → what the numbers mean
/// → reference → personal baseline → next steps (§13.2) → quality &
/// versions → disclaimer; Save / Retake.
class HearingResultScreen extends StatefulWidget {
  const HearingResultScreen({super.key, required this.result});

  final HearingSessionResult result;

  @override
  State<HearingResultScreen> createState() => _HearingResultScreenState();
}

class _HearingResultScreenState extends State<HearingResultScreen> {
  static const double _gap = 20;
  bool _saved = false;
  VoiceCoachController? _voice;

  HearingSessionResult get r => widget.result;
  HearingProtocol get p => widget.result.protocol;
  bool get _pure => p.mode == HearingMode.pureTone;

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
            tooltip: 'Screen spec & gates (${p.resultScreenId})',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () =>
                showScreenGateLifecycleSheet(context, p.resultScreenId),
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
              _pure ? 'Your audiogram' : 'Your number',
              'Against the line in the algorithm document',
            ),
            _partsCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Algorithm outputs',
              'Every output marker of ${p.algorithmId} (Spec §8) with the value measured',
            ),
            AlgorithmOutputsSection(
              groups: MarkerReadings.fromHearing(r),
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
              'Confirmatory steps from Spec §13.2',
            ),
            _nextStepsCard(),
            const SizedBox(height: _gap),
            _qualityExpander(appState),
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
                HearingCaptureScreen(protocol: p, startAtHowTo: true),
          ),
        ),
        onPressed: _saved
            ? null
            : () {
                appState.saveHearingSession(r);
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
    final meta = _pure ? '$time · $assessed of 2 ears' : time;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(
                Icons.hearing_rounded,
                AnaemiaUi.primary,
                size: 44,
              ),
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
              AnaemiaUi.tag(
                r.quality.earphonesVerified
                    ? 'Earphones ${r.quality.earphoneType}'
                    : 'Earphones not verified',
                color: r.quality.earphonesVerified
                    ? MirrorColors.successFg
                    : MirrorColors.warningFg,
                icon: Icons.headphones_rounded,
              ),
              if (_pure)
                AnaemiaUi.tag(
                  r.quality.calibrationSource == 'entered'
                      ? 'Earphone level calibrated'
                      : 'Earphone level assumed [DER]',
                  color: r.quality.calibrationSource == 'entered'
                      ? MirrorColors.successFg
                      : MirrorColors.warningFg,
                  icon: Icons.tune_rounded,
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
              fontSize: 13.5,
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

  // --- parts -------------------------------------------------------------

  Widget _partsCard() {
    final right = r.ear(HearingEar.right);
    final left = r.ear(HearingEar.left);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pure) ...[
            SizedBox(
              height: 220,
              child: CustomPaint(
                key: const ValueKey('hear_audiogram'),
                painter: AudiogramPainter(
                  right: right?.thresholds ?? const {},
                  left: left?.thresholds ?? const {},
                  rightNoResponse: right?.noResponse ?? const {},
                  leftNoResponse: left?.noResponse ?? const {},
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 6),
            const AudiogramLegend(),
            const Divider(height: 18),
          ],
          for (var i = 0; i < r.parts.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            _partRow(r.parts[i]),
          ],
          const SizedBox(height: 10),
          Text(
            _pure
                ? 'Line from the document: every threshold below 20 dB HL is normal (WHO 2021, better ear; Spec §8). Grades mild / moderate / severe are research cut-offs [DER].'
                : 'No cut-off in the document yet for digits in noise (OQ-FEA-01); the value is kept for your own baseline.',
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

  Widget _partRow(HearingPartResult s) {
    final earColor = s.ear == HearingEar.right
        ? AudiogramPainter.rightColor
        : s.ear == HearingEar.left
        ? AudiogramPainter.leftColor
        : AnaemiaUi.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (s.ear != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: earColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
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
              customLabel: s.skipped
                  ? 'Not assessed (skipped)'
                  : s.grade?.label,
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
        if (s.assessed && s.ear != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final hz in hearingFrequenciesHz)
                if (s.thresholds[hz] != null)
                  _thresholdChip(
                    hz,
                    s.thresholds[hz]!,
                    s.noResponse.contains(hz),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          RangeGauge(
            scale: const RangeScale(
              breakpoints: [0, 20, 35, 50, 90],
              labels: [
                '< 20 normal',
                '20–34 mild',
                '35–49 mod.',
                '≥ 50 severe',
              ],
              colors: [
                AnaemiaUi.segNormal,
                AnaemiaUi.segBorder,
                AnaemiaUi.segHigh,
                AnaemiaUi.segHigh,
              ],
            ),
            value: s.pta4!.clamp(0, 90),
            pinColor: earColor,
          ),
        ],
        if (s.assessed && s.ear == null && s.dinTrials.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < s.dinTrials.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (s.dinTrials[i].correct
                                ? AnaemiaUi.segNormal
                                : AnaemiaUi.segHigh)
                            .withValues(
                              alpha: i < DigitsInNoise.scoredFrom ? 0.3 : 0.8,
                            ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${s.dinTrials[i].snrDb >= 0 ? '+' : ''}${s.dinTrials[i].snrDb.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Each chip is one round at its signal-to-noise ratio (green = all three digits right). The first three rounds are practice and faded.',
            style: TextStyle(color: AnaemiaUi.muted, fontSize: 11, height: 1.3),
          ),
        ],
      ],
    );
  }

  Widget _thresholdChip(int hz, double v, bool nr) {
    final normal = v < HearingGrading.whoNormalMaxDbHl;
    final color = normal ? MirrorColors.successFg : MirrorColors.warningFg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${hz >= 1000 ? '${hz ~/ 1000} kHz' : '$hz Hz'} · ${nr || v >= ToneLevel.noResponseDbHl ? 'no response' : '${v.toStringAsFixed(0)} dB'}',
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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
                              '${entries[i].key.startsWith('HEAR_') ? 'Hearing threshold' : MarkerCatalogue.byCode(entries[i].key)?.label ?? entries[i].key} — ',
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
          if (_pure) ...[
            const SizedBox(height: 8),
            const Text(
              'PTA4 = average of the 0.5, 1, 2 and 4 kHz thresholds. The band uses the better ear, as the document says; the worse ear still shows on the chart.',
              style: TextStyle(
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
    final unit = _pure ? 'dB HL' : 'dB SNR';
    final dec = _pure ? 0 : 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: b == null || !b.hasBaseline
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
                  '${b.baselineMedian!.toStringAsFixed(dec)} $unit (median of last 3)',
                ),
                AnaemiaUi.kvRow(
                  'This test',
                  '${r.heroValue!.toStringAsFixed(dec)} $unit',
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
                        'Trigger: ${spec.appTrigger}',
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
            const SizedBox(height: 12),
            AnaemiaUi.kvRow('Tests', spec.investigations),
            AnaemiaUi.kvRow('Usual cut-offs', spec.usualDiagnosticCutoffs),
            AnaemiaUi.kvRow(
              'Pair with this test',
              '${spec.pairingReferenceTest} within ${spec.maxPairingGapLabel.replaceAll('<= ', '')}; not valid after ${spec.pairingExclusions.toLowerCase()}.',
            ),
            const SizedBox(height: 6),
            if (r.asymmetric)
              AnaemiaUi.bullet(
                'The two ears differ by 15 dB or more at two pitches — ask for an ENT review of the weaker ear [DER].',
                icon: Icons.hearing_disabled_rounded,
              ),
            AnaemiaUi.bullet(
              'A case was opened under ${p.conditionCode}; enter the clinician result (S-R06) to close it.',
              icon: Icons.folder_open_rounded,
            ),
          ] else if (r.isNotAssessed) ...[
            AnaemiaUi.bullet(
              'Check the setup steps and repeat the test.',
              icon: Icons.replay_rounded,
            ),
            AnaemiaUi.bullet(
              'Both earphones in, volume at maximum, room below 45 dBA.',
              icon: Icons.headphones_rounded,
            ),
          ] else ...[
            AnaemiaUi.bullet(
              'No confirmatory test is needed from this result.',
              icon: Icons.check_circle_rounded,
            ),
            AnaemiaUi.bullet(
              _pure
                  ? 'Repeat yearly, or sooner if you notice you ask people to repeat themselves or turn the TV up.'
                  : 'Repeat in about 6 months to build your own baseline; the clinic can grade hearing with calibrated headphones.',
              icon: Icons.event_repeat_rounded,
            ),
          ],
          if (r.isPartiallyAssessed) ...[
            const SizedBox(height: 8),
            const InfoNote(
              icon: Icons.hearing_disabled_rounded,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              text:
                  'One ear was not assessed; the result rests on the other. Retake for a complete result.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _qualityExpander(AppState appState) {
    final q = r.quality;
    final presentations = r.parts.expand((x) => x.presentations).toList();
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
            'Earphones, level calibration, room noise, catch trials, algorithm and rules (operator view)',
            style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            AnaemiaUi.kvRow('Session', r.sessionId),
            AnaemiaUi.kvRow(
              'Algorithm',
              '${p.algorithmId} ${p.algorithmVersion} · ${_pure ? 'Mode A pure tone' : 'Mode B digits in noise'} · release: in validation (G-24)',
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
            AnaemiaUi.kvRow(
              'Earphones (G-19)',
              '${q.earphoneType}${q.earphonesVerified ? ' · verified' : ' · not verified'}${_pure ? (q.volumeAtMax ? ' · volume at max' : ' · volume not confirmed at max') : ''}',
            ),
            if (_pure)
              AnaemiaUi.kvRow(
                'Earphone level',
                'Full-scale tone = ${q.fullScaleDbHl.toStringAsFixed(0)} dB HL (${q.calibrationSource == 'entered' ? 'entered from a clinic audiogram' : 'assumed [DER], OQ-REQ-15'})',
              ),
            AnaemiaUi.kvRow(
              'Room noise (G-18)',
              '${q.ambientSource}${q.ambientMeanDba != null ? ' · mean ${q.ambientMeanDba!.toStringAsFixed(0)} dBA' : ''}${q.ambientMaxDba != null ? ' · max ${q.ambientMaxDba!.toStringAsFixed(0)} dBA' : ''} · limit 45 · pauses ${q.pauses}',
            ),
            if (_pure)
              AnaemiaUi.kvRow(
                'Catch trials',
                '${q.catchTrials} silent · ${q.falsePositives} false tap${q.falsePositives == 1 ? '' : 's'}',
              ),
            AnaemiaUi.kvRow('Trials', '${q.trials}'),
            AnaemiaUi.kvRow('Retakes', '${q.retakes} (G-25 max 3)'),
            AnaemiaUi.kvRow('Input', q.simulated ? 'simulated' : 'member'),
            if (presentations.isNotEmpty)
              AnaemiaUi.kvRow(
                'Staircase',
                presentations
                    .map(
                      (t) => t.isCatch
                          ? '(${t.heard ? '✗' : '·'})'
                          : '${t.dbHl.toStringAsFixed(0)}${t.heard ? '✓' : '✗'}',
                    )
                    .join(' '),
              ),
            if (_pure) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('hear_calibrate'),
                  onPressed: () => _showCalibration(appState),
                  icon: const Icon(Icons.straighten_rounded, size: 18),
                  label: const Text('Calibrate from a clinic audiogram'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// OQ-REQ-15 stand-in: the member enters the clinic's right-ear 1 kHz
  /// threshold; the difference to this phone's reading corrects the
  /// assumed full-scale level for these earphones.
  Future<void> _showCalibration(AppState appState) async {
    final measured =
        r.ear(HearingEar.right)?.thresholds[1000] ??
        r.ear(HearingEar.left)?.thresholds[1000];
    final ctl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calibrate the earphone level',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AnaemiaUi.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              measured == null
                  ? 'Complete a pure-tone test first; the 1 kHz reading of this phone is compared with a clinic audiogram.'
                  : 'This phone found ${measured.toStringAsFixed(0)} dB HL at 1 kHz (right ear). Enter the 1 kHz threshold from a recent clinic audiogram for the same ear; the difference corrects the assumed level of these earphones (Spec §8 AUD-09, OQ-REQ-15 [DER]).',
              style: const TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Clinic threshold at 1 kHz (dB HL)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: measured == null
                  ? null
                  : () {
                      final known = double.tryParse(ctl.text.trim());
                      if (known == null) return;
                      final fs = ToneLevel.fullScaleFromKnown(
                        knownDbHl: known,
                        measuredDbHl: measured,
                        assumedFullScaleDbHl: r.quality.fullScaleDbHl,
                      );
                      appState.setEarphoneCalibration(fs);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Earphone level stored: full scale = ${fs.toStringAsFixed(0)} dB HL. Retake to apply.',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Store calibration'),
            ),
          ],
        ),
      ),
    );
  }
}
