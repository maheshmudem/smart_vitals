import 'package:flutter/material.dart';

import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/algorithms/movement_session_builder.dart'
    show stsAgeNorm;
import '../../core/domain/entities/case_record.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/marker_catalogue.dart';
import '../../core/domain/entities/movement_protocol.dart';
import '../../core/domain/entities/movement_result.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'movement_capture_screen.dart';

/// S-R01 result for a movement test (T-RES): urgency → hero (plain sentence,
/// band, confidence) → per side with document-only gauges → algorithm
/// outputs → what the numbers mean → Parkinson's composite → reference →
/// personal baseline → next steps (§13) → quality & versions → disclaimer;
/// Save / Retake.
class MovementResultScreen extends StatefulWidget {
  const MovementResultScreen({super.key, required this.result});

  final MovementSessionResult result;

  @override
  State<MovementResultScreen> createState() => _MovementResultScreenState();
}

class _MovementResultScreenState extends State<MovementResultScreen> {
  static const double _gap = 20;
  bool _saved = false;
  VoiceCoachController? _voice;

  MovementSessionResult get r => widget.result;
  MovementProtocol get p => widget.result.protocol;

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
    _voice?.announce(
      '${p.shortTitle} result for ${r.subjectName}. ${r.bandSubline}. ${r.whatItMeans}',
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
        title: Text(p.resultTitle),
        actions: [
          IconButton(
            tooltip: 'Read aloud',
            icon: const Icon(Icons.record_voice_over_rounded),
            onPressed: _readAloud,
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
            _resultCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              p.twoSided ? 'Each hand' : 'Your number',
              p.twoSided
                  ? '${p.secondsPerSide} s per hand · the result above follows the worse hand'
                  : 'Against the line in the algorithm document',
            ),
            _sidesCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Algorithm outputs',
              'Every output marker of ${p.algorithmId} (Spec §9) with the value measured',
            ),
            AlgorithmOutputsSection(
              groups: MarkerReadings.fromMovement(r),
              showHeader: false,
            ),
            const SizedBox(height: 12),
            _meaningsCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              "Parkinson's composite (ALG-MOV-13)",
              'Runs only when tapping, voice and face tasks all exist',
            ),
            _pdCard(context),
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
                MovementCaptureScreen(protocol: p, startAtHowTo: true),
          ),
        ),
        onPressed: _saved
            ? null
            : () {
                appState.saveMovementSession(r);
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

  Widget _resultCard() {
    final style = BandVisualStyle.forBand(r.band);
    final rec = r.recordedAt;
    final time =
        '${rec.day.toString().padLeft(2, '0')}/${rec.month.toString().padLeft(2, '0')}/${rec.year} · '
        '${rec.hour.toString().padLeft(2, '0')}:${rec.minute.toString().padLeft(2, '0')}';
    final assessed = r.perSide.where((s) => s.assessed).length;
    final meta = p.twoSided
        ? '$time · ${r.durationSeconds} s · $assessed of 2 hands'
        : '$time · ${r.durationSeconds} s';
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
                      if (r.ageNormLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          r.ageNormLabel!,
                          style: TextStyle(
                            color: style.foreground.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
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
              if (r.quality.backend == 'proxy')
                AnaemiaUi.tag(
                  'Landmark model pending — motion proxy',
                  color: MirrorColors.warningFg,
                  icon: Icons.science_outlined,
                ),
              if (r.quality.sensorSimulated)
                AnaemiaUi.tag(
                  'Simulated sensors',
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
    MovementTestKind.tappingVideo => Icons.back_hand_rounded,
    MovementTestKind.tappingTouch => Icons.touch_app_rounded,
    MovementTestKind.gait => Icons.directions_walk_rounded,
    MovementTestKind.sitToStand => Icons.chair_alt_rounded,
    MovementTestKind.tremor => Icons.vibration_rounded,
  };

  // --- per side ------------------------------------------------------------

  Widget _sidesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < r.perSide.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            _sideRow(r.perSide[i]),
          ],
          if (_gaugeCaption != null) ...[
            const SizedBox(height: 10),
            Text(
              _gaugeCaption!,
              style: const TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? get _gaugeCaption => switch (p.kind) {
    MovementTestKind.tappingVideo =>
      'Line from the document: decrement under 20 % is normal (Spec §9).',
    MovementTestKind.gait =>
      'Line from the document: 0.8 m/s or more is normal for older adults (Spec §9).',
    MovementTestKind.sitToStand =>
      stsAgeNorm(r.ageYears) == null
          ? 'The document gives a norm only for ages 60–64 (≥ 12); other ages are pending (Q-COHORT).'
          : 'Line from the document: ≥ ${stsAgeNorm(r.ageYears)} stands for age 60–64 (Spec §9).',
    MovementTestKind.tremor =>
      'Document bands inside the 3–12 Hz window: Parkinsonian 4–6 Hz, essential postural 5–10 Hz. Normal = no peak above the sensor noise floor (Spec §9).',
    MovementTestKind.tappingTouch =>
      'No cut-off in the document yet (age norms pending); your count is kept for your own baseline.',
  };

  Widget _sideRow(MovementSideResult s) {
    final gauge = _gaugeFor(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                p.twoSided ? '${s.label} hand' : p.shortTitle,
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
        if (s.restarts > 0)
          Text(
            '${s.restarts} restart${s.restarts == 1 ? '' : 's'} (G-25 max 3)',
            style: const TextStyle(color: MirrorColors.warningFg, fontSize: 11),
          ),
        if (gauge != null) ...[const SizedBox(height: 10), gauge],
      ],
    );
  }

  /// Gauges show only the lines the algorithm document gives — no invented
  /// middle zones.
  Widget? _gaugeFor(MovementSideResult s) {
    if (!s.assessed) return null;
    final style = BandVisualStyle.forBand(s.band);
    switch (p.kind) {
      case MovementTestKind.tappingVideo:
        final v = s.values['TAP_DECREMENT'];
        if (v == null) return null;
        return RangeGauge(
          scale: const RangeScale(
            breakpoints: [0, 20, 50],
            labels: ['< 20 % normal', '≥ 20 % refer'],
            colors: [AnaemiaUi.segNormal, AnaemiaUi.segHigh],
          ),
          value: v,
          pinColor: style.foreground,
        );
      case MovementTestKind.gait:
        final v = s.values['GAIT_SPEED'];
        if (v == null) return null;
        return RangeGauge(
          scale: const RangeScale(
            breakpoints: [0.2, 0.8, 1.6],
            labels: ['< 0.8 m/s refer', '≥ 0.8 m/s normal'],
            colors: [AnaemiaUi.segHigh, AnaemiaUi.segNormal],
          ),
          value: v,
          pinColor: style.foreground,
        );
      case MovementTestKind.sitToStand:
        final v = s.values['STS_COUNT_30S'];
        final norm = stsAgeNorm(r.ageYears);
        if (v == null || norm == null) return null;
        return RangeGauge(
          scale: RangeScale(
            breakpoints: [0, norm.toDouble(), norm * 2.0],
            labels: ['< $norm below norm', '≥ $norm normal'],
            colors: const [AnaemiaUi.segHigh, AnaemiaUi.segNormal],
          ),
          value: v,
          pinColor: style.foreground,
        );
      case MovementTestKind.tremor:
        final v = s.values['TREMOR_FREQ'];
        if (v == null) return null;
        return RangeGauge(
          scale: const RangeScale(
            breakpoints: [3, 4, 6, 10, 12],
            labels: ['3–4 Hz', '4–6 Hz PD', '6–10 Hz ET', '10–12 Hz'],
            colors: [
              AnaemiaUi.segBorder,
              AnaemiaUi.segHigh,
              AnaemiaUi.segHigh,
              AnaemiaUi.segBorder,
            ],
          ),
          value: v,
          pinColor: style.foreground,
        );
      case MovementTestKind.tappingTouch:
        return null;
    }
  }

  // --- what the numbers mean -------------------------------------------------

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

  // --- PD composite ----------------------------------------------------------

  Widget _pdCard(BuildContext context) {
    final pd = r.pd;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pdTick('Tapping', pd.hasTapping),
              const SizedBox(width: 8),
              _pdTick('Voice', pd.hasVoice),
              const SizedBox(width: 8),
              _pdTick('Face', pd.hasFace),
            ],
          ),
          const SizedBox(height: 10),
          if (pd.complete && pd.band != null) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Parkinson's signs band (PD_BAND)",
                    style: TextStyle(
                      color: AnaemiaUi.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                BandChip(band: pd.band!),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Stand-in rule until the MOV-PD-01 classifier ships: refer when tap decrement ≥ 20 % or a 4–6 Hz tremor peak is present [DER]. PD_PROB stays internal [OPEN].',
              style: TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ] else
            InfoNote(
              icon: Icons.pending_actions_rounded,
              title: 'Not run yet',
              text:
                  'Complete the missing sub-test: ${pd.missing.join(' · ')}. The composite score needs all three (Spec §9 MOV-13).',
            ),
        ],
      ),
    );
  }

  Widget _pdTick(String label, bool ok) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: ok ? MirrorColors.successBg : MirrorColors.neutralBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: ok ? MirrorColors.successFg : MirrorColors.neutralFg,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ok ? MirrorColors.successFg : MirrorColors.neutralFg,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // --- reference / baseline / next steps -----------------------------------

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
      MovementTestKind.tappingVideo => '% decrement',
      MovementTestKind.tappingTouch => 'taps',
      MovementTestKind.gait => 'm/s',
      MovementTestKind.sitToStand => 'stands',
      MovementTestKind.tremor => 'Hz',
    };
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
                  '${b.baselineMedian!.toStringAsFixed(2)} $unit (median of last 3)',
                ),
                AnaemiaUi.kvRow(
                  'This test',
                  '${r.heroValue!.toStringAsFixed(2)} $unit',
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
            AnaemiaUi.bullet(
              'If the test keeps failing, an operator can run it with you.',
              icon: Icons.support_agent_rounded,
            ),
          ] else ...[
            AnaemiaUi.bullet(
              'No confirmatory test is needed from this result.',
              icon: Icons.check_circle_rounded,
            ),
            AnaemiaUi.bullet(
              'Repeat in about 3 months, or sooner if you notice a change, to build your baseline.',
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
                  'One hand was not assessed; the result rests on the other hand. Retake for a stronger result.',
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
            'Sensor rates, tracking, restarts, algorithm and rules (operator view)',
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
              '${r.confidence.toStringAsFixed(2)} = capture ${q.captureQualityScore.toStringAsFixed(2)} × model ${q.backend == 'proxy' ? '0.70' : '0.90'} (hidden below 0.60, G-23)',
            ),
            if (q.achievedAccelHz != null)
              AnaemiaUi.kvRow(
                'Accelerometer',
                '${q.achievedAccelHz!.toStringAsFixed(0)} Hz achieved (50 Hz asked)',
              ),
            if (q.achievedGyroHz != null)
              AnaemiaUi.kvRow(
                'Gyroscope',
                '${q.achievedGyroHz!.toStringAsFixed(0)} Hz achieved (100 Hz asked)',
              ),
            if (q.framesPerSecond != null)
              AnaemiaUi.kvRow(
                'Camera',
                '${q.framesPerSecond!.toStringAsFixed(0)} frames/s tracked',
              ),
            if (q.handVisiblePct != null)
              AnaemiaUi.kvRow(
                'Hand visible',
                '${q.handVisiblePct!.toStringAsFixed(0)} % of frames',
              ),
            if (q.noiseFloorPsd != null)
              AnaemiaUi.kvRow(
                'Noise floor',
                'PSD ${q.noiseFloorPsd!.toStringAsExponential(2)} · peak ratio ${q.peakRatio?.toStringAsFixed(1) ?? '—'} (≥ 6 counts)',
              ),
            if (p.kind == MovementTestKind.tremor)
              AnaemiaUi.kvRow(
                'Tremor method',
                'Welch PSD per gyroscope axis, summed [DER]; the document\'s step 1 uses the |ω| magnitude, whose rectification doubles the peak frequency',
              ),
            if (p.kind == MovementTestKind.gait)
              AnaemiaUi.kvRow(
                'Walk timing',
                'First to last heel strike plus one mean step interval; speed = 10 m ÷ time [DER]',
              ),
            AnaemiaUi.kvRow('Dropped samples', '${q.droppedSamples}'),
            AnaemiaUi.kvRow(
              'Restarts / retakes',
              '${q.restarts} / ${q.retakes} (G-25 max 3)',
            ),
            AnaemiaUi.kvRow('Backend', q.backend),
            AnaemiaUi.kvRow(
              'Demo outcome',
              '${p.demoOutcomeLabels[r.demoOutcome.name] ?? r.demoOutcome.name}${q.sensorSimulated ? ' · simulated sensors' : ''}',
            ),
          ],
        ),
      ),
    );
  }
}
