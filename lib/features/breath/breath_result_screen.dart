import 'package:flutter/material.dart';

import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/breath_engines.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/entities/breath_protocol.dart';
import '../../core/domain/entities/breath_result.dart';
import '../../core/domain/entities/case_record.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/marker_catalogue.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'breath_capture_screen.dart';

/// T-RES result for a Breathing & Voice check (S-G06): urgency → hero
/// sentence → per-kind detail (cough tiles + TB band + symptoms; OAD gauge
/// + asthma-vs-COPD; FEV1 / FVC / ratio / PEF tiles + flow curve + effort
/// table; the seven voice markers against the norms) → how it was worked
/// out → algorithm outputs → meanings → reference → baseline → next steps
/// (§13.2) → quality; Save / Retake.
class BreathResultScreen extends StatefulWidget {
  const BreathResultScreen({
    super.key,
    required this.result,
    this.micResult,
    this.roomDba,
  });

  final BreathSessionResult result;

  /// Readiness outcome carried into a retake.
  final MicSelfCheckResult? micResult;
  final double? roomDba;

  @override
  State<BreathResultScreen> createState() => _BreathResultScreenState();
}

class _BreathResultScreenState extends State<BreathResultScreen> {
  static const double _gap = 20;
  bool _saved = false;
  VoiceCoachController? _voice;

  BreathSessionResult get r => widget.result;
  BreathProtocol get p => widget.result.protocol;

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

  String _f(double? v, int d) => v == null ? '—' : v.toStringAsFixed(d);

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
                title: switch (r.urgency) {
                  UrgencyLevel.emergency => 'Emergency — ${p.shortTitle}',
                  UrgencyLevel.urgent => 'Urgent — ${p.shortTitle}',
                  _ => 'Routine follow-up — ${p.shortTitle}',
                },
                subtitle: r.bandSubline,
                ruleCodes: r.firedRuleCodes,
              ),
              const SizedBox(height: 12),
            ],
            _heroCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(switch (p.kind) {
              BreathKind.coughTb => 'Your coughs and answers',
              BreathKind.airway => 'Airway signs',
              BreathKind.lungFunction => 'Your lung values',
              BreathKind.voice => 'Your voice values',
            }, 'Against the lines in the algorithm document'),
            _partsCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'How this result was worked out',
              'In plain words, from the algorithm document',
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AnaemiaUi.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in p.howWorkedOut)
                    AnaemiaUi.bullet(line, icon: Icons.functions_rounded),
                ],
              ),
            ),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Algorithm outputs',
              'Every output marker of ${p.algorithmLabel} with the value measured',
            ),
            AlgorithmOutputsSection(
              groups: MarkerReadings.fromBreath(r),
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
            builder: (_) => BreathCaptureScreen(
              protocol: p,
              startAtHowTo: true,
              micResult: widget.micResult,
              roomDba: widget.roomDba,
            ),
          ),
        ),
        onPressed: _saved
            ? null
            : () {
                appState.saveBreathSession(r);
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

  // --- hero ------------------------------------------------------------------

  Widget _heroCard() {
    final style = BandVisualStyle.forBand(r.band);
    final rec = r.recordedAt;
    final time =
        '${rec.day.toString().padLeft(2, '0')}/${rec.month.toString().padLeft(2, '0')}/${rec.year} · '
        '${rec.hour.toString().padLeft(2, '0')}:${rec.minute.toString().padLeft(2, '0')}';
    final assessed = r.parts.where((x) => x.assessed).length;
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
                      '${p.title} · ${p.algorithmLabel}',
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
                      '$time · $assessed of ${r.parts.length} step${r.parts.length == 1 ? '' : 's'}',
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
              BandChip(
                band: SemanticBand.inValidation,
                compact: true,
                customLabel: p.kind == BreathKind.voice
                    ? 'DSP · Praat-validated'
                    : 'In clinical validation',
              ),
              AnaemiaUi.tag(
                r.quality.audioSource == 'microphone'
                    ? 'Phone microphone'
                    : 'Simulated audio',
                color: r.quality.audioSource == 'microphone'
                    ? MirrorColors.successFg
                    : MirrorColors.infoFg,
                icon: Icons.mic_rounded,
              ),
              if (r.quality.micSelfCheckPassed)
                AnaemiaUi.tag(
                  switch (r.quality.micSource) {
                    'manual' => 'Mic confirmed by you',
                    'microphone' => 'Mic check ✓ (phone profile)',
                    _ => 'Mic check ✓',
                  },
                  color: r.quality.micSource == 'manual'
                      ? MirrorColors.warningFg
                      : MirrorColors.successFg,
                  icon: Icons.graphic_eq_rounded,
                ),
              if (r.quality.clipAcceptedTasks.isNotEmpty)
                AnaemiaUi.tag(
                  'Clipping on ${r.quality.clipAcceptedTasks.join(', ')} (CAP-13)',
                  color: MirrorColors.warningFg,
                  icon: Icons.warning_amber_rounded,
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

  IconData get _icon => switch (p.kind) {
    BreathKind.coughTb => Icons.sick_outlined,
    BreathKind.airway => Icons.air_rounded,
    BreathKind.lungFunction => Icons.speed_rounded,
    BreathKind.voice => Icons.graphic_eq_rounded,
  };

  // --- parts -----------------------------------------------------------------

  Widget _partsCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: AnaemiaUi.card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (p.kind) {
          BreathKind.coughTb => _coughTbSummary(),
          BreathKind.airway => _airwaySummary(),
          BreathKind.lungFunction => _lungSummary(),
          BreathKind.voice => _voiceSummary(),
        },
        for (final part in r.parts) ...[
          const Divider(height: 18),
          _partRow(part),
        ],
        const SizedBox(height: 10),
        Text(switch (p.kind) {
          BreathKind.coughTb =>
            'Lines from the document: ≥ 3 valid coughs (150–800 ms, p ≥ 0.5); TB_BAND low is normal; high or classic symptoms → BR-SCR-02 urgent. The 0.50 threshold and the symptom rule are stand-ins [DER].',
          BreathKind.airway =>
            'Lines from the document: OAD_BAND low is normal; wheeze = tonal peak ≥ 100 ms. The band cut-offs 0.33 / 0.66 and the score are stand-ins for the trained model [DER].',
          BreathKind.lungFunction =>
            'Line from the document: FEV1/FVC ≥ RATIO_LLN is normal; top two blows within 10 %. Predicted values use ECSC-1993 until the GLI-2012 coefficients ship; the litre scale is uncalibrated [DER].',
          BreathKind.voice =>
            'Lines from the document (adult norms): jitter < 1.04 %, shimmer < 3.81 %, HNR > 20 dB, MPT ≥ 15 s, s/z < 1.4. F0 and CPPS have no norm. Outside a line is borderline here, not a diagnosis.',
        }, style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11, height: 1.3)),
      ],
    ),
  );

  Widget _tile(String code, String label, String value, {Color? color}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: (color ?? AnaemiaUi.primary).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  key: ValueKey('breath_tile_$code'),
                  style: TextStyle(
                    color: color ?? AnaemiaUi.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AnaemiaUi.muted,
                  fontSize: 10.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _coughTbSummary() {
    final c = r.coughs;
    final tb = r.markers['TB_BAND']?.value?.toString();
    final high = r.band == SemanticBand.high;
    final style = BandVisualStyle.forBand(r.band);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _tile(
              'COUGH_COUNT_VALID',
              'valid coughs (need 3)',
              c == null ? '—' : '${c.count}',
              color: c != null && c.enough ? null : MirrorColors.warningFg,
            ),
            const SizedBox(width: 8),
            _tile(
              'CANDIDATES',
              'bursts examined',
              c == null ? '—' : '${c.candidates.length}',
            ),
            const SizedBox(width: 8),
            _tile(
              'WETNESS',
              'wetness 0–1',
              c == null || c.count == 0 ? '—' : _f(c.meanWetness, 2),
            ),
            const SizedBox(width: 8),
            _tile(
              'TB_BAND',
              'TB band',
              tb == null ? '—' : tb.toUpperCase(),
              color: tb == null ? null : style.foreground,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                high ? Icons.priority_high_rounded : Icons.check_rounded,
                color: style.foreground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  high
                      ? 'High: always confirm with a sputum NAAT test (CBNAAT / TrueNat) and a chest X-ray within 14 days (Spec §13.2).'
                      : tb == null
                      ? 'Not assessed: complete the questions for a band.'
                      : 'Low: no referral from this check. The probability number stays internal until the TB study (G-24).',
                  style: TextStyle(
                    color: style.foreground,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _airwaySummary() {
    final o = r.oad;
    final style = BandVisualStyle.forBand(r.band);
    if (o == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _tile(
              'OAD_BAND',
              'obstruction band',
              r.band == SemanticBand.notAssessed
                  ? '—'
                  : r.band.name.toUpperCase(),
              color: style.foreground,
            ),
            const SizedBox(width: 8),
            _tile('OAD_PROB', 'score 0–1 (in validation)', _f(o.prob, 2)),
            const SizedBox(width: 8),
            _tile(
              'WHEEZE_SHARE',
              'wheeze share',
              r.wheeze == null
                  ? '—'
                  : '${_f(r.wheeze!.wheezeShare * 100, 0)} %',
            ),
            const SizedBox(width: 8),
            _tile('FEV1_FVC', 'exhale ratio', _f(r.overall['FEV1_FVC'], 2)),
          ],
        ),
        const SizedBox(height: 10),
        RangeGauge(
          scale: const RangeScale(
            breakpoints: [0, 0.33, 0.66, 1],
            labels: ['< 0.33 low', '0.33–0.66 mod.', '≥ 0.66 high'],
            colors: [
              AnaemiaUi.segNormal,
              AnaemiaUi.segBorder,
              AnaemiaUi.segHigh,
            ],
          ),
          value: o.prob.clamp(0, 1),
          pinColor: style.foreground,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'COPD',
              style: TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: o.asthmaVsCopd.clamp(0, 1),
                  minHeight: 10,
                  backgroundColor: const Color(0xFFBFDBFE),
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'asthma',
              style: TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'ASTHMA_VS_COPD_PROB ${_f(o.asthmaVsCopd, 2)} — ${o.asthmaVsCopd >= 0.5 ? 'leans towards asthma' : 'leans towards COPD'} (display policy open in the document)',
          style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in o.inputs.entries)
              AnaemiaUi.tag(
                '${e.key} +${_f(e.value, 2)}',
                color: e.value > 0.05
                    ? MirrorColors.warningFg
                    : AnaemiaUi.muted,
                icon: Icons.add_chart_rounded,
              ),
          ],
        ),
      ],
    );
  }

  Widget _lungSummary() {
    final s = r.spirometry;
    final b = s?.best;
    final pred = s?.prediction;
    final below = s?.belowLln ?? false;
    final style = BandVisualStyle.forBand(r.band);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _tile(
              'FEV1_L',
              'FEV1 L · ${_f(s?.fev1PredPct, 0)} % pred',
              _f(b?.fev1, 2),
            ),
            const SizedBox(width: 8),
            _tile(
              'FVC_L',
              'FVC L · ${_f(s?.fvcPredPct, 0)} % pred',
              _f(b?.fvc, 2),
            ),
            const SizedBox(width: 8),
            _tile(
              'FEV1_FVC',
              'ratio · LLN ${_f(pred?.ratioLln, 2)}',
              _f(b?.ratio, 2),
              color: below ? style.foreground : null,
            ),
            const SizedBox(width: 8),
            _tile('PEF_LS', 'peak flow L/s', _f(b?.pef, 1)),
          ],
        ),
        if (b != null && pred != null) ...[
          const SizedBox(height: 10),
          RangeGauge(
            scale: RangeScale(
              breakpoints: [0.4, pred.ratioLln, 0.9],
              labels: ['< LLN obstruction', '≥ LLN normal'],
              colors: const [AnaemiaUi.segHigh, AnaemiaUi.segNormal],
            ),
            value: b.ratio.clamp(0.4, 0.9),
            pinColor: style.foreground,
          ),
          const SizedBox(height: 10),
          const Text(
            'Flow over time · best blow (sound envelope as the flow proxy)',
            style: TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 92,
            child: CustomPaint(
              key: const ValueKey('breath_curve'),
              painter: _FlowCurvePainter(b.effort.curve, b.effort.durationS),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          _effortTable(s!),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AnaemiaUi.tag(
                s.repeatable
                    ? 'Repeatable: best two within ${_f(s.repeatabilityDiffPct, 0)} %'
                    : s.repeatabilityDiffPct == null
                    ? 'Only one valid blow — not repeatable'
                    : 'Not repeatable: ${_f(s.repeatabilityDiffPct, 0)} % apart (limit 10)',
                color: s.repeatable
                    ? MirrorColors.successFg
                    : MirrorColors.warningFg,
                icon: Icons.compare_arrows_rounded,
              ),
              AnaemiaUi.tag(
                'Predicted: ${pred.source}${pred.ageInRange ? '' : ' · age outside 18–70'}',
                color: MirrorColors.infoFg,
                icon: Icons.functions_rounded,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _effortTable(SpirometryEstimate s) {
    const h = TextStyle(
      color: AnaemiaUi.muted,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
    );
    const c = TextStyle(
      color: AnaemiaUi.ink,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    Widget cell(String t, {TextStyle st = c, int flex = 2}) => Expanded(
      flex: flex,
      child: Text(t, textAlign: TextAlign.center, style: st),
    );
    return Column(
      key: const ValueKey('breath_effort_table'),
      children: [
        Row(
          children: [
            cell('Blow', st: h),
            cell('s', st: h),
            cell('FEV1', st: h),
            cell('FVC', st: h),
            cell('ratio', st: h),
            cell('PEF', st: h),
            cell('', st: h, flex: 1),
          ],
        ),
        for (final e in s.efforts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                cell('${e.index + 1}${s.bestIndex == e.index ? ' ★' : ''}'),
                cell(_f(e.effort.durationS, 1)),
                cell(e.valid ? _f(e.fev1, 2) : '—'),
                cell(e.valid ? _f(e.fvc, 2) : '—'),
                cell(e.valid ? _f(e.ratio, 2) : '—'),
                cell(e.valid ? _f(e.pef, 1) : '—'),
                Expanded(
                  flex: 1,
                  child: Icon(
                    e.valid
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 16,
                    color: e.valid
                        ? MirrorColors.successFg
                        : MirrorColors.warningFg,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _voiceSummary() {
    final v = r.voice;
    if (v == null || !v.phonationOk) return const SizedBox.shrink();
    Widget row(
      String code,
      String label,
      String value,
      String norm,
      RangeScale scale,
      double gaugeValue,
    ) {
      final band = v.bandOf(code);
      final style = BandVisualStyle.forBand(band);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AnaemiaUi.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  value,
                  key: ValueKey('breath_tile_$code'),
                  style: const TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                BandChip(
                  band: band,
                  compact: true,
                  customLabel: band == SemanticBand.rangeNotAvailable
                      ? 'No norm'
                      : band == SemanticBand.borderline
                      ? 'Outside norm'
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            RangeGauge(
              scale: scale,
              value: gaugeValue,
              pinColor: style.foreground,
            ),
            Text(
              norm,
              style: const TextStyle(color: AnaemiaUi.muted, fontSize: 10.5),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _tile('F0_HZ', 'pitch Hz (no norm)', _f(v.f0Hz, 0)),
            const SizedBox(width: 8),
            _tile('CPPS_DB', 'CPPS dB (no norm)', _f(v.cppsDb, 1)),
            const SizedBox(width: 8),
            _tile(
              'OUTSIDE',
              'values outside norms',
              '${v.outsideNormCount} / 5',
              color: v.outsideNormCount == 0
                  ? MirrorColors.successFg
                  : MirrorColors.warningFg,
            ),
          ],
        ),
        const SizedBox(height: 6),
        row(
          'JITTER_PCT',
          'Jitter',
          '${_f(v.jitterPct, 2)} %',
          'Normal < 1.04 % (Spec §8)',
          const RangeScale(
            breakpoints: [0, 1.04, 3],
            labels: ['< 1.04 normal', '≥ 1.04'],
            colors: [AnaemiaUi.segNormal, AnaemiaUi.segBorder],
          ),
          v.jitterPct.clamp(0, 3),
        ),
        row(
          'SHIMMER_PCT',
          'Shimmer',
          '${_f(v.shimmerPct, 2)} %',
          'Normal < 3.81 % (Spec §8)',
          const RangeScale(
            breakpoints: [0, 3.81, 10],
            labels: ['< 3.81 normal', '≥ 3.81'],
            colors: [AnaemiaUi.segNormal, AnaemiaUi.segBorder],
          ),
          v.shimmerPct.clamp(0, 10),
        ),
        row(
          'HNR_DB',
          'Harmonics-to-noise',
          '${_f(v.hnrDb, 1)} dB',
          'Normal > 20 dB (Spec §8)',
          const RangeScale(
            breakpoints: [0, 20, 40],
            labels: ['≤ 20', '> 20 normal'],
            colors: [AnaemiaUi.segBorder, AnaemiaUi.segNormal],
          ),
          v.hnrDb.clamp(0, 40),
        ),
        row(
          'MPT_S',
          'Maximum phonation time',
          '${_f(v.mptS, 1)} s',
          v.adult
              ? 'Adult norm ≥ 15 s (Spec §8)'
              : 'Child norm not given (Spec §8)',
          const RangeScale(
            breakpoints: [0, 15, 30],
            labels: ['< 15', '≥ 15 normal'],
            colors: [AnaemiaUi.segBorder, AnaemiaUi.segNormal],
          ),
          v.mptS.clamp(0, 30),
        ),
        if (v.szRatio != null)
          row(
            'SZ_RATIO',
            's/z ratio',
            _f(v.szRatio, 2),
            'Normal < 1.4 · "sss" ${_f(v.sS, 1)} s ÷ "zzz" ${_f(v.zS, 1)} s (Spec §8)',
            const RangeScale(
              breakpoints: [0.5, 1.4, 2.5],
              labels: ['< 1.4 normal', '≥ 1.4'],
              colors: [AnaemiaUi.segNormal, AnaemiaUi.segBorder],
            ),
            v.szRatio!.clamp(0.5, 2.5),
          ),
      ],
    );
  }

  Widget _partRow(BreathPartResult s) {
    final style = BandVisualStyle.forBand(s.band);
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
              customLabel: s.skipped
                  ? 'Not assessed (skipped)'
                  : s.band == SemanticBand.rangeNotAvailable
                  ? 'Recorded'
                  : s.band == SemanticBand.borderline
                  ? (p.kind == BreathKind.coughTb ? 'Noted' : 'Outside norm')
                  : null,
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
        if (_heardLine(s) != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.hearing_rounded,
                size: 13,
                color: r.quality.clipAcceptedTasks.contains(s.id)
                    ? MirrorColors.warningFg
                    : AnaemiaUi.muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _heardLine(s)!,
                  key: ValueKey('breath_heard_${s.id}'),
                  style: TextStyle(
                    color: r.quality.clipAcceptedTasks.contains(s.id)
                        ? MirrorColors.warningFg
                        : AnaemiaUi.muted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (s.answers.isNotEmpty) ...[
          const SizedBox(height: 8),
          _answerGrid(s),
        ],
        if (s.items.isNotEmpty && s.answers.isEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final it in s.items.take(8))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: style.foreground.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    it,
                    style: TextStyle(
                      color: style.foreground,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// "What the phone heard" for a recorded task: seconds, clipping, SNR,
  /// attempts (CAP-13 quality next to the result, not only in the expander).
  String? _heardLine(BreathPartResult s) {
    final q = r.quality;
    final clip = q.clipByTask[s.id] ?? q.clipByTask['${s.id}_1'];
    final snr = q.snrByTask[s.id] ?? q.snrByTask['${s.id}_1'];
    final dur = q.durationByTask[s.id];
    if (clip == null && snr == null && dur == null) return null;
    final parts = <String>[
      if (dur != null) '${dur.toStringAsFixed(1)} s recorded',
      if (clip != null)
        'clipping ${clip.toStringAsFixed(1)} % (≤ 1)${q.clipAcceptedTasks.contains(s.id) ? ' — kept after 2 re-records' : ''}',
      if (snr != null) 'SNR ${snr.toStringAsFixed(0)} dB (≥ 15)',
      if ((q.attemptsByTask[s.id] ?? 1) > 1)
        '${q.attemptsByTask[s.id]} attempts',
    ];
    return 'Heard: ${parts.join(' · ')}';
  }

  Widget _answerGrid(BreathPartResult s) {
    final q = switch (s.id) {
      'q_tb' => BreathTexts.tbSymptoms,
      'q_mmrc' => BreathTexts.mmrc,
      _ => BreathTexts.exposure,
    };
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in q.questions)
          Builder(
            builder: (context) {
              final v = s.answers[item.id] ?? 0;
              final yesNo = item.options.length == 2;
              final flagged = yesNo ? v > 0 : v >= 2;
              final color = flagged
                  ? (q.id == 'Q_TB_SYMPTOMS'
                        ? AnaemiaUi.segHigh
                        : AnaemiaUi.segBorder)
                  : AnaemiaUi.segNormal;
              return Tooltip(
                message:
                    '${item.text} — ${item.options[v.clamp(0, item.options.length - 1)]}',
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    yesNo
                        ? '${_short(item.id)}: ${v > 0 ? 'Yes' : 'No'}'
                        : '${_short(item.id)}: $v',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AnaemiaUi.ink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  static String _short(String id) => switch (id) {
    'tb_cough2w' => 'Cough ≥ 2 wk',
    'tb_fever' => 'Fever',
    'tb_sweats' => 'Night sweats',
    'tb_weight' => 'Weight loss',
    'tb_blood' => 'Blood in phlegm',
    'mmrc' => 'mMRC grade',
    'exp_smoke' => 'Smoking',
    'exp_years' => 'Years',
    'exp_biomass' => 'Biomass',
    'exp_dust' => 'Dust / fumes',
    _ => id,
  };

  // --- meanings / reference / baseline / next steps --------------------------

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
    final (unit, dec) = switch (p.kind) {
      BreathKind.coughTb => ('coughs', 0),
      BreathKind.airway => ('score', 2),
      BreathKind.lungFunction => ('ratio', 2),
      BreathKind.voice => ('% jitter', 2),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: p.kind == BreathKind.coughTb
          ? const Text(
              'The TB screen is a band (low / high), so no baseline is built. Each check is kept in History.',
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
    final spec = p.hasCondition
        ? ConfirmatoryInvestigationsRegistry
              .byCondition[ConfirmatoryInvestigationsRegistry.aliases[p
                  .conditionCode] ??
              p.conditionCode]
        : null;
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
              '${spec.pairingReferenceTest} within ${spec.maxPairingGapLabel.replaceAll('<= ', '')}${spec.pairingExclusions == 'None' ? '' : '; not valid after ${spec.pairingExclusions.toLowerCase()}'}.',
            ),
            const SizedBox(height: 6),
            AnaemiaUi.bullet(
              'A case was opened under ${p.conditionCode}; enter the clinician result (S-R06) to close it.',
              icon: Icons.folder_open_rounded,
            ),
          ] else if (r.isNotAssessed) ...[
            AnaemiaUi.bullet(
              'Check the setup steps and repeat the check.',
              icon: Icons.replay_rounded,
            ),
          ] else ...[
            AnaemiaUi.bullet(
              p.hasCondition
                  ? 'No confirmatory test is needed from this result.'
                  : 'The document has no referral rule for voice quality; a clinician reads the values.',
              icon: Icons.check_circle_rounded,
            ),
            AnaemiaUi.bullet(switch (p.kind) {
              BreathKind.coughTb =>
                'Come back if the cough lasts beyond two weeks, or with fever, night sweats, weight loss or blood in the phlegm.',
              BreathKind.airway =>
                'Repeat in 6 months, or sooner if breathlessness or wheeze starts. Avoid smoke.',
              BreathKind.lungFunction =>
                'Repeat yearly to build your own baseline; sooner if you become more breathless.',
              BreathKind.voice =>
                'Repeat on another day to build your baseline. Hoarseness lasting more than three weeks deserves an ENT examination.',
            }, icon: Icons.event_repeat_rounded),
          ],
          if (r.isPartiallyAssessed) ...[
            const SizedBox(height: 8),
            const InfoNote(
              icon: Icons.warning_amber_rounded,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              text:
                  'One step was not completed; the result rests on the others. Retake for a complete result.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _qualityExpander() {
    final q = r.quality;
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
            'Microphone check, room noise, clipping / SNR per task, attempts, efforts, algorithm and rules (operator view)',
            style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            AnaemiaUi.kvRow('Session', r.sessionId),
            AnaemiaUi.kvRow(
              'Algorithm',
              '${p.algorithmLabel} ${p.algorithmVersion} · release: ${p.kind == BreathKind.voice ? 'standard DSP' : 'in validation (G-24)'}',
            ),
            AnaemiaUi.kvRow('Range version', p.rangeVersion),
            AnaemiaUi.kvRow(
              'Rules fired',
              r.firedRuleCodes.isEmpty ? 'None' : r.firedRuleCodes.join(', '),
            ),
            AnaemiaUi.kvRow(
              'Result confidence',
              '${r.confidence.toStringAsFixed(2)} = capture ${q.captureQualityScore.toStringAsFixed(2)} × model (hidden below 0.60, G-23)',
            ),
            AnaemiaUi.kvRow(
              'Mic self-check (G-17)',
              q.micDeviationDb == null
                  ? 'not run this session'
                  : '${q.micSelfCheckPassed ? 'passed' : 'failed'} · deviation ${q.micDeviationDb!.toStringAsFixed(1)} dB (≤ 6) · processing ${q.micProcessingDetected ? 'detected' : 'off'}',
            ),
            AnaemiaUi.kvRow(
              'Room noise (G-18)',
              q.ambientDba != null
                  ? '${q.ambientDba!.toStringAsFixed(0)} dBA · limit 45'
                  : 'not measured',
            ),
            AnaemiaUi.kvRow(
              'Audio (CAP-13)',
              q.clipByTask.isEmpty
                  ? q.audioSource
                  : '${q.audioSource} · ${q.clipByTask.entries.map((e) => '${e.key} clip ${e.value.toStringAsFixed(1)} % / SNR ${(q.snrByTask[e.key] ?? 0).toStringAsFixed(0)} dB').join(' · ')}',
            ),
            if (q.attemptsByTask.isNotEmpty)
              AnaemiaUi.kvRow(
                'Attempts',
                q.attemptsByTask.entries
                    .map((e) => '${e.key} ×${e.value}')
                    .join(' · '),
              ),
            if (q.effortsDone > 0)
              AnaemiaUi.kvRow(
                'Blows',
                '${q.effortsDone} recorded · ${q.repeatable == null
                    ? 'repeatability n/a'
                    : q.repeatable!
                    ? 'repeatable'
                    : 'not repeatable'}${q.repeatabilityDiffPct == null ? '' : ' (${q.repeatabilityDiffPct!.toStringAsFixed(0)} % apart)'}',
              ),
            if (p.needsBodyProfile)
              AnaemiaUi.kvRow(
                'Predicted values',
                '${q.bodyProfile ?? 'height missing — 165 cm assumed'} · ${q.predictedSource ?? SpirometryReference.source}',
              ),
            AnaemiaUi.kvRow('Retakes', '${q.retakes} (G-25 max 3)'),
            AnaemiaUi.kvRow('Input', q.simulated ? 'simulated' : 'member'),
          ],
        ),
      ),
    );
  }
}

class _FlowCurvePainter extends CustomPainter {
  const _FlowCurvePainter(this.curve, this.durationS);
  final List<double> curve;
  final double durationS;

  @override
  void paint(Canvas canvas, Size size) {
    if (curve.length < 2) return;
    final axis = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      axis,
    );
    // 1 s marker
    if (durationS > 0) {
      final x1 = (1 / durationS).clamp(0.0, 1.0) * size.width;
      canvas.drawLine(
        Offset(x1, 0),
        Offset(x1, size.height),
        Paint()
          ..color = const Color(0xFFDC2626).withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      final tp = TextPainter(
        text: const TextSpan(
          text: '1 s',
          style: TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x1 + 3, 0));
    }
    final path = Path();
    final fill = Path();
    for (var i = 0; i < curve.length; i++) {
      final x = i / (curve.length - 1) * size.width;
      final y = size.height - 2 - curve[i] * (size.height - 8);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height - 1);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height - 1);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()..color = const Color(0xFF0B7A75).withValues(alpha: 0.15),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0B7A75)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _FlowCurvePainter old) => old.curve != curve;
}
