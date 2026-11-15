import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/algorithms/sleep_engines.dart';
import '../../core/domain/entities/case_record.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/sleep_protocol.dart';
import '../../core/domain/entities/sleep_result.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'sleep_capture_screen.dart';

/// T-RES Sleep Report (S-G09): urgency → hero (AHI + OSA band, or
/// breathing rate only for a short night) → the night at a glance →
/// breathing-rate chart per 30-s epoch → events → how it was worked out →
/// algorithm outputs → meanings → reference → baseline → next steps
/// (§13.2) → quality; Save / Retake.
class SleepResultScreen extends StatefulWidget {
  const SleepResultScreen({super.key, required this.result});

  final SleepSessionResult result;

  @override
  State<SleepResultScreen> createState() => _SleepResultScreenState();
}

class _SleepResultScreenState extends State<SleepResultScreen> {
  static const double _gap = 20;
  bool _saved = false;
  VoiceCoachController? _voice;

  SleepSessionResult get r => widget.result;
  SleepProtocol get p => widget.result.protocol;

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
    final saved =
        _saved || appState.sleepSessions.any((s) => s.sessionId == r.sessionId);
    return Scaffold(
      backgroundColor: MirrorColors.backgroundLight,
      appBar: AppBar(
        title: Text(p.resultTitle),
        actions: [
          IconButton(
            tooltip: 'Read aloud',
            icon: const Icon(Icons.record_voice_over_rounded),
            onPressed: () => _voice?.announce(
              '${p.shortTitle} for ${r.subjectName}. ${r.bandSubline}. ${r.whatItMeans}',
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
                title: 'Routine follow-up — ${p.shortTitle}',
                subtitle: r.bandSubline,
                ruleCodes: r.firedRuleCodes,
              ),
              const SizedBox(height: 12),
            ],
            _heroCard(),
            if (r.partial) ...[
              const SizedBox(height: 12),
              InfoNote(
                key: const ValueKey('sleep_partial_banner'),
                icon: Icons.warning_amber_rounded,
                color: MirrorColors.warningFg,
                background: MirrorColors.warningBg,
                text:
                    'Not a full night — valid sleep under 4 h, so APNOEA_EVENTS, HYPOPNOEA_EVENTS, AHI_EST and OSA_BAND are not assessed (E-AUD-003). Repeat the night with the phone plugged in on the bedside table.',
              ),
            ],
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Your night at a glance',
              'Valid hours, breathing rate and events against the document lines',
            ),
            _glanceCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Breathing rate through the night',
              'SONAR_RR per 30-s epoch · grey = no clear echo · red = apnoea · amber = hypopnoea',
            ),
            _chartCard(),
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
              groups: MarkerReadings.fromSleep(r),
              showHeader: false,
            ),
            const SizedBox(height: 12),
            _meaningsCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'How to read it',
              'Document values first; research references marked [DER]',
            ),
            _referenceCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Your personal baseline',
              'Spec §10 RSK-03 / RSK-04 · median of your last 3 nights within 180 days',
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
        label: saved ? 'Saved' : 'Save to profile',
        icon: saved ? Icons.check_rounded : Icons.save_alt_rounded,
        secondaryLabel: 'Retake',
        onSecondary: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SleepCaptureScreen(protocol: p, startAtHowTo: true),
          ),
        ),
        onPressed: saved
            ? null
            : () {
                appState.saveSleepSession(r);
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
    String two(int v) => v.toString().padLeft(2, '0');
    final s = r.startedAt, e = r.endedAt;
    final when =
        '${two(e.day)}/${two(e.month)}/${e.year} · ${two(s.hour)}:${two(s.minute)} → ${two(e.hour)}:${two(e.minute)}';
    final measured = r.partial || r.ahiEst == null
        ? 'SONAR_RR ${_f(r.medianRr, 0)} br/min · ${_f(r.validSleepH, 1)} h valid'
        : 'AHI_EST ${_f(r.ahiEst, 1)} /h · OSA_BAND ${OsaBands.label(r.osaBand!)} · ${_f(r.validSleepH, 1)} h valid';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(
                Icons.bedtime_rounded,
                AnaemiaUi.primary,
                size: 44,
              ),
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
                      when,
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
                        key: const ValueKey('sleep_hero_subline'),
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
                        'Measured: $measured',
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
                r.quality.audioSource == 'stream'
                    ? '48 kHz sonar stream'
                    : 'Simulated night',
                color: MirrorColors.infoFg,
                icon: r.quality.audioSource == 'stream'
                    ? Icons.graphic_eq_rounded
                    : Icons.tune_rounded,
              ),
              if (r.quality.sonarCheckPassed == false)
                AnaemiaUi.tag(
                  'Weak sonar echo on this phone',
                  color: MirrorColors.warningFg,
                  icon: Icons.warning_amber_rounded,
                ),
              if (r.quality.unpluggedSeconds > 0)
                AnaemiaUi.tag(
                  'Unplugged ${(r.quality.unpluggedSeconds / 60).ceil()} min',
                  color: MirrorColors.warningFg,
                  icon: Icons.power_off_rounded,
                ),
            ],
          ),
          const SizedBox(height: 12),
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
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // --- glance ----------------------------------------------------------------

  Widget _tile(String code, String label, String value, {Color? color}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: (color ?? AnaemiaUi.primary).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AnaemiaUi.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                key: ValueKey('sleep_tile_$code'),
                style: TextStyle(
                  color: color ?? AnaemiaUi.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Text(
                code,
                style: const TextStyle(color: AnaemiaUi.muted, fontSize: 9.5),
              ),
            ],
          ),
        ),
      );

  Widget _glanceCard() {
    final rrColor = r.medianRr == null
        ? AnaemiaUi.muted
        : (r.medianRr! >= 12 && r.medianRr! <= 20)
        ? MirrorColors.successFg
        : MirrorColors.warningFg;
    final ahiColor = r.osaBand == null
        ? AnaemiaUi.muted
        : switch (r.osaBand!) {
            OsaBand.normal => MirrorColors.successFg,
            OsaBand.mild => MirrorColors.warningFg,
            OsaBand.moderate => MirrorColors.warningFg,
            OsaBand.severe => MirrorColors.dangerFg,
          };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Column(
        children: [
          Row(
            children: [
              _tile(
                'VALID_SLEEP_H',
                'Valid sleep',
                '${_f(r.validSleepH, 1)} h',
                color: r.partial
                    ? MirrorColors.warningFg
                    : MirrorColors.successFg,
              ),
              const SizedBox(width: 8),
              _tile(
                'SONAR_RR',
                'Breathing rate',
                r.medianRr == null ? '—' : '${_f(r.medianRr, 0)} /min',
                color: rrColor,
              ),
              const SizedBox(width: 8),
              _tile(
                'AHI_EST',
                'AHI',
                r.ahiEst == null ? 'n/a' : '${_f(r.ahiEst, 1)} /h',
                color: ahiColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _tile(
                'APNOEA_EVENTS',
                'Apnoeas',
                r.partial ? 'n/a' : '${r.apnoeaEvents}',
                color: r.apnoeaEvents == 0 ? MirrorColors.successFg : ahiColor,
              ),
              const SizedBox(width: 8),
              _tile(
                'HYPOPNOEA_EVENTS',
                'Hypopnoeas',
                r.partial ? 'n/a' : '${r.hypopnoeaEvents}',
                color: r.hypopnoeaEvents == 0
                    ? MirrorColors.successFg
                    : ahiColor,
              ),
              const SizedBox(width: 8),
              _tile(
                'OSA_BAND',
                'OSA band',
                r.osaBand == null ? 'n/a' : OsaBands.label(r.osaBand!),
                color: ahiColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AnaemiaUi.kvRow(
                  'Recorded',
                  '${_f(r.recordedH, 1)} h · ${r.epochValid.length} epochs · ${r.quality.invalidEpochs} without echo',
                  keyWidth: 80,
                ),
              ),
            ],
          ),
          if (r.longestEvent != null)
            AnaemiaUi.kvRow(
              'Longest event',
              '${r.longestEvent!.durationS.toStringAsFixed(0)} s ${r.longestEvent!.type.name} (${r.longestEvent!.dropPct.toStringAsFixed(0)} % drop)',
              keyWidth: 80,
            ),
          if (r.quality.snoreFraction > 0.02)
            AnaemiaUi.kvRow(
              'Snore-like sound',
              '${(r.quality.snoreFraction * 100).toStringAsFixed(0)} % of valid time (support value, not a marker)',
              keyWidth: 80,
            ),
        ],
      ),
    );
  }

  // --- chart -----------------------------------------------------------------

  Widget _chartCard() {
    final hours = r.recordedH;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: CustomPaint(
              key: const ValueKey('sleep_rr_chart'),
              size: const Size(double.infinity, 150),
              painter: SleepRrChartPainter(
                rr: r.rrEpochs,
                events: r.events,
                startS: 0,
                endS: math.max(1, r.epochValid.length * 30.0),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'start',
                style: TextStyle(color: AnaemiaUi.muted, fontSize: 10.5),
              ),
              Expanded(
                child: Text(
                  '${hours.toStringAsFixed(1)} h recorded · band 12–20 br/min shaded',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AnaemiaUi.muted,
                    fontSize: 10.5,
                  ),
                ),
              ),
              const Text(
                'end',
                style: TextStyle(color: AnaemiaUi.muted, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- meanings / reference / baseline / next steps / quality ------------------

  Widget _meaningsCard() {
    final entries = p.markerMeanings.entries.toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What each marker means',
            style: TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${e.key} — ',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: e.value),
                  ],
                ),
              ),
            ),
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
    final rb = r.rrBaseline;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: (b == null || !b.hasBaseline) && (rb == null || !rb.hasBaseline)
          ? const Text(
              'No baseline yet — save at least 3 nights within 180 days and the app will compare each new AHI and breathing rate with your own median (RSK-03) and flag a meaningful change (RSK-04).',
              style: TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (b != null && b.hasBaseline) ...[
                  AnaemiaUi.kvRow(
                    'AHI baseline',
                    '${b.baselineMedian!.toStringAsFixed(1)} /h (median of last 3)',
                  ),
                  AnaemiaUi.kvRow('This night', '${_f(r.ahiEst, 1)} /h'),
                  AnaemiaUi.kvRow(
                    'Change',
                    '${b.changePct!.toStringAsFixed(0)} % · ${b.isMeaningfulChange ? 'meaningful change (RSK-04)' : 'within your usual range'}',
                  ),
                ],
                if (rb != null && rb.hasBaseline) ...[
                  AnaemiaUi.kvRow(
                    'Breathing baseline',
                    '${rb.baselineMedian!.toStringAsFixed(0)} br/min',
                  ),
                  AnaemiaUi.kvRow('This night', '${_f(r.medianRr, 0)} br/min'),
                ],
              ],
            ),
    );
  }

  Widget _nextStepsCard() {
    final spec =
        ConfirmatoryInvestigationsRegistry
            .byCondition[ConfirmatoryInvestigationsRegistry.aliases[p
                .conditionCode] ??
            p.conditionCode];
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
              'Pair with this night',
              '${spec.pairingReferenceTest} within ${spec.maxPairingGapLabel.replaceAll('<= ', '')}; not valid after ${spec.pairingExclusions.toLowerCase()}.',
            ),
            const SizedBox(height: 6),
            AnaemiaUi.bullet(
              'A case was opened under ${p.conditionCode}; enter the clinician result (S-R06) to close it.',
              icon: Icons.folder_open_rounded,
            ),
            if (r.osaBand == OsaBand.severe)
              AnaemiaUi.bullet(
                'Severe range: avoid driving or operating machinery when sleepy until a clinician has seen you.',
                icon: Icons.car_crash_outlined,
              ),
          ] else if (r.isNotAssessed || r.partial) ...[
            AnaemiaUi.bullet(
              'Repeat the night: phone flat on the bedside table, 30 cm to 1 m from the chest, plugged in, for at least 4 hours (G-30).',
              icon: Icons.replay_rounded,
            ),
            if (r.quality.sonarCheckPassed == false)
              AnaemiaUi.bullet(
                'The sonar echo was weak on this phone — try a higher media volume or another phone on the bedside table.',
                icon: Icons.volume_up_rounded,
              ),
          ] else ...[
            AnaemiaUi.bullet(
              'No confirmatory test is needed from this night.',
              icon: Icons.check_circle_rounded,
            ),
            AnaemiaUi.bullet(
              r.osaBand == OsaBand.mild
                  ? 'Mild range: repeat in a few weeks; side-sleeping, less alcohol in the evening and weight loss help. See a clinician if you are sleepy by day.'
                  : 'Repeat a few nights over the year to build your own baseline; sooner if snoring, choking at night or daytime sleepiness appear.',
              icon: Icons.event_repeat_rounded,
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
            'Valid hours, echo, charger, interruptions, sonar check, algorithm and rules (operator view)',
            style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            AnaemiaUi.kvRow('Session', r.sessionId),
            AnaemiaUi.kvRow(
              'Algorithm',
              '${p.algorithmLabel} ${p.algorithmVersion} · release: in validation (G-24)',
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
              'Valid sleep',
              '${_f(r.validSleepH, 1)} h of ${_f(r.recordedH, 1)} h recorded · ${q.invalidEpochs} of ${q.totalEpochs} epochs without echo · stop: ${q.stopReason}',
            ),
            AnaemiaUi.kvRow(
              'Sonar check',
              q.sonarCheckPassed == null
                  ? 'not run'
                  : '${q.sonarCheckPassed! ? 'passed' : 'weak'} · ${_f(q.sonarCheckDb, 0)} dB above floor (≥ 15)',
            ),
            AnaemiaUi.kvRow(
              'Mic self-check (CAP-11)',
              q.micSelfCheckPassed == null
                  ? 'not run'
                  : q.micDeviationDb == null
                  ? (q.micSelfCheckPassed! ? 'manual confirmation' : 'failed')
                  : '${q.micSelfCheckPassed! ? 'passed' : 'failed'} · deviation ${q.micDeviationDb!.toStringAsFixed(1)} dB (≤ 6)',
            ),
            AnaemiaUi.kvRow(
              'Audio',
              '${q.audioSource} · ${q.sampleRate ~/ 1000} kHz · chirp ${q.chirpPlayed ? 'played' : 'not played'} · ${q.interruptions} restart${q.interruptions == 1 ? '' : 's'}',
            ),
            AnaemiaUi.kvRow(
              'Charger (G-30)',
              '${q.chargingAtStart ? 'charging at start' : 'not charging at start'} · unplugged ${(q.unpluggedSeconds / 60).ceil()} min',
            ),
            AnaemiaUi.kvRow(
              'Screen off',
              q.keepAliveUsed
                  ? 'foreground service on${q.notificationAllowed == false ? ' (notification denied)' : ''}'
                  : 'night screen kept on',
            ),
            AnaemiaUi.kvRow(
              'Do-not-disturb',
              q.dndOn == null ? 'unknown' : (q.dndOn! ? 'on' : 'off'),
            ),
            AnaemiaUi.kvRow(
              'Ring SpO2 (G-32)',
              r.ringConnected ? 'paired' : 'not paired',
            ),
            AnaemiaUi.kvRow('Input', q.simulated ? 'simulated' : 'member'),
          ],
        ),
      ),
    );
  }
}

/// SONAR_RR per epoch with the 12–20 band shaded, invalid epochs grey and
/// events as red (apnoea) / amber (hypopnoea) ticks.
class SleepRrChartPainter extends CustomPainter {
  const SleepRrChartPainter({
    required this.rr,
    required this.events,
    required this.startS,
    required this.endS,
  });

  final List<double?> rr;
  final List<SleepEvent> events;
  final double startS;
  final double endS;

  @override
  void paint(Canvas canvas, Size size) {
    const minRr = 4.0, maxRr = 34.0;
    double yFor(double v) =>
        size.height -
        ((v - minRr) / (maxRr - minRr)).clamp(0.0, 1.0) * size.height;
    // normal band
    canvas.drawRect(
      Rect.fromLTRB(0, yFor(20), size.width, yFor(12)),
      Paint()..color = const Color(0xFF16A34A).withValues(alpha: 0.08),
    );
    final grid = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final g in [12.0, 20.0]) {
      canvas.drawLine(Offset(0, yFor(g)), Offset(size.width, yFor(g)), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: '${g.toInt()}',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, yFor(g) - tp.height - 1));
    }
    if (rr.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'No epochs recorded',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2));
      return;
    }
    final n = rr.length;
    final dx = size.width / n;
    // invalid epochs
    final invalid = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.25);
    for (var i = 0; i < n; i++) {
      if (rr[i] == null) {
        canvas.drawRect(
          Rect.fromLTWH(i * dx, 0, dx + 0.5, size.height),
          invalid,
        );
      }
    }
    // events
    final span = math.max(1.0, endS - startS);
    for (final e in events) {
      final x = ((e.startS - startS) / span).clamp(0.0, 1.0) * size.width;
      final w = math.max(2.0, e.durationS / span * size.width);
      canvas.drawRect(
        Rect.fromLTWH(x, 0, w, size.height),
        Paint()
          ..color =
              (e.type == SleepEventType.apnoea
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFD97706))
                  .withValues(alpha: 0.35),
      );
    }
    // rr line
    final line = Paint()
      ..color = const Color(0xFF0B7A75)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    Path? path;
    for (var i = 0; i < n; i++) {
      final v = rr[i];
      if (v == null) {
        if (path != null) canvas.drawPath(path, line);
        path = null;
        continue;
      }
      final pt = Offset(i * dx + dx / 2, yFor(v));
      if (path == null) {
        path = Path()..moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    if (path != null) canvas.drawPath(path, line);
    // frame
    canvas.drawRect(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant SleepRrChartPainter old) =>
      old.rr != rr || old.events != events;
}
