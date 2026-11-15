import 'package:flutter/material.dart';

import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/algorithms/mind_engines.dart';
import '../../core/domain/entities/case_record.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/marker_catalogue.dart';
import '../../core/domain/entities/mind_protocol.dart';
import '../../core/domain/entities/mind_result.dart';
import '../../core/services/emergency_contacts.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'mind_capture_screen.dart';
import 'mind_illustrations.dart';

/// T-RES result for a Brain & Mind check: urgency → hero sentence → per-kind
/// detail (values with "norms pending", PHQ/GAD gauges and answer grid, HF
/// baseline progress or deviation trend, FAST sign tiles) → algorithm
/// outputs → meanings → reference → baseline → next steps (§13.2) → quality;
/// Save / Retake.
class MindResultScreen extends StatefulWidget {
  const MindResultScreen({super.key, required this.result});

  final MindSessionResult result;

  @override
  State<MindResultScreen> createState() => _MindResultScreenState();
}

class _MindResultScreenState extends State<MindResultScreen> {
  static const double _gap = 20;
  bool _saved = false;
  VoiceCoachController? _voice;

  MindSessionResult get r => widget.result;
  MindProtocol get p => widget.result.protocol;

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
    final saved =
        _saved || appState.mindSessions.any((s) => s.sessionId == r.sessionId);
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
                  UrgencyLevel.emergency =>
                    r.crisis
                        ? 'Crisis support shown — ${p.shortTitle}'
                        : 'Emergency — ${p.shortTitle}',
                  UrgencyLevel.urgent => 'Urgent — ${p.shortTitle}',
                  _ => 'Routine follow-up — ${p.shortTitle}',
                },
                subtitle: r.bandSubline,
                ruleCodes: r.firedRuleCodes,
              ),
              const SizedBox(height: 12),
            ],
            if (r.crisis) ...[_crisisCard(), const SizedBox(height: 12)],
            if (p.kind == MindKind.stroke && r.isEmergency) ...[
              _emergencyCallCard(),
              const SizedBox(height: 12),
            ],
            _heroCard(),
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(switch (p.kind) {
              MindKind.cognitive => 'Your speech values',
              MindKind.mood => 'Your questionnaires',
              MindKind.hfVoice => 'Your voice vs baseline',
              MindKind.stroke => 'The three signs',
            }, 'Against the lines in the algorithm document'),
            _partsCard(),
            if (p.howWorkedOut.isNotEmpty) ...[
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
            ],
            const SizedBox(height: _gap),
            AnaemiaUi.sectionHeader(
              'Algorithm outputs',
              'Every output marker of ${p.algorithmLabel} with the value measured',
            ),
            AlgorithmOutputsSection(
              groups: MarkerReadings.fromMind(r),
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
        label: saved ? 'Saved' : 'Save to profile',
        icon: saved ? Icons.check_rounded : Icons.save_alt_rounded,
        secondaryLabel: 'Retake',
        onSecondary: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => MindCaptureScreen(
              protocol: p,
              language: r.language,
              startAtHowTo: true,
              onsetLabel: r.onsetLabel,
            ),
          ),
        ),
        onPressed: saved
            ? null
            : () {
                appState.saveMindSession(r);
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

  // --- top cards ----------------------------------------------------------

  Widget _crisisCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0F3D4C),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.favorite_rounded, color: Color(0xFFFCA5A5)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "You're not alone",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'PHQ-9 question 9 was answered. Helplines were shown; ${r.clinicianNotified ? 'your pathway clinician has been notified (G-37)' : 'clinician notification was declined'}. Talk to someone you trust today.',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final c in EmergencyContacts.crisis.take(2))
              OutlinedButton.icon(
                onPressed: () => EmergencyContacts.dial(c.number),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.call_rounded, size: 16),
                label: Text(c.label),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _emergencyCallCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFDC2626),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Call emergency services now',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Say "possible stroke". ${r.onsetLabel != null ? 'Symptoms started: ${r.onsetLabel}. ' : ''}Do not eat, drink or drive.',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final c in EmergencyContacts.emergency) ...[
              Expanded(
                child: FilledButton.icon(
                  key: ValueKey('mind_result_call_${c.number}'),
                  onPressed: () => EmergencyContacts.dial(c.number),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text(
                    c.number,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (c != EmergencyContacts.emergency.last)
                const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    ),
  );

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
              const BandChip(
                band: SemanticBand.inValidation,
                compact: true,
                customLabel: 'In clinical validation',
              ),
              if (p.languages.length > 1)
                AnaemiaUi.tag(
                  r.language.label,
                  color: MirrorColors.infoFg,
                  icon: Icons.translate_rounded,
                ),
              if (p.kind == MindKind.cognitive)
                AnaemiaUi.tag(
                  r.quality.sttAvailable
                      ? 'Speech recognition on-device'
                      : 'No speech recognition — acoustic only',
                  color: r.quality.sttAvailable
                      ? MirrorColors.successFg
                      : MirrorColors.warningFg,
                  icon: Icons.record_voice_over_rounded,
                ),
              if (r.quality.simulated)
                AnaemiaUi.tag(
                  'Simulated input',
                  color: MirrorColors.infoFg,
                  icon: Icons.tune_rounded,
                ),
              if (p.kind == MindKind.stroke && r.onsetLabel != null)
                AnaemiaUi.tag(
                  'Started: ${r.onsetLabel}',
                  color: MirrorColors.warningFg,
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
          if (p.kind == MindKind.stroke && r.parts.any((x) => !x.assessed)) ...[
            const SizedBox(height: 12),
            InfoNote(
              key: const ValueKey('mind_partial_banner'),
              icon: Icons.warning_amber_rounded,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              text:
                  'Not a full check — ${r.parts.where((x) => !x.assessed).map((x) => '${x.label}: ${x.note}').join(' · ')}',
            ),
          ],
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
    MindKind.cognitive => Icons.psychology_rounded,
    MindKind.mood => Icons.self_improvement_rounded,
    MindKind.hfVoice => Icons.monitor_heart_rounded,
    MindKind.stroke => Icons.emergency_rounded,
  };

  // --- parts --------------------------------------------------------------

  Widget _partsCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: AnaemiaUi.card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.kind == MindKind.cognitive) _cognitiveTiles(),
        if (p.kind == MindKind.hfVoice) _hfSummary(),
        for (var i = 0; i < r.parts.length; i++) ...[
          if (i > 0 ||
              p.kind == MindKind.cognitive ||
              p.kind == MindKind.hfVoice)
            const Divider(height: 18),
          _partRow(r.parts[i]),
        ],
        const SizedBox(height: 10),
        Text(switch (p.kind) {
          MindKind.cognitive =>
            'Lines from the document: values are shown and the band waits for the age / education norms and the released classifier (G-24, Q-COHORT).',
          MindKind.mood =>
            'Lines from the document: PHQ-9 and GAD-7 below 5 are normal; 10 or more is moderate (Spec §8). Labels for 5–9, 15–19 and ≥ 20 are the standard PHQ bands [DER].',
          MindKind.hfVoice =>
            'Line from the document: HF_ALERT = false is normal; no alert during the 14-day baseline (G-28). The 2.0 SD / two-day rule is a stand-in [DER].',
          MindKind.stroke =>
            'Line from the document: any single sign above its threshold is positive (OR gate, MOV-09). Thresholds 0.50 / 10 cm / 0.50 are stand-ins [DER].',
        }, style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11, height: 1.3)),
      ],
    ),
  );

  Widget _cognitiveTiles() {
    Widget tile(String code, String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AnaemiaUi.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              key: ValueKey('mind_tile_$code'),
              style: const TextStyle(
                color: AnaemiaUi.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
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
    final o = r.overall;
    String f(String code, int dec) =>
        o[code] == null ? '—' : o[code]!.toStringAsFixed(dec);
    return Column(
      children: [
        Row(
          children: [
            tile('FLUENCY_COUNT', 'animals / 60 s', f('FLUENCY_COUNT', 0)),
            const SizedBox(width: 8),
            tile('PAUSE_RATE', 'pauses > 2 s / min', f('PAUSE_RATE', 1)),
            const SizedBox(width: 8),
            tile('SPEECH_RATE', 'words / min', f('SPEECH_RATE', 0)),
            const SizedBox(width: 8),
            tile('LEXICAL_DIV', 'word variety', f('LEXICAL_DIV', 2)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            AnaemiaUi.tag(
              'Age/education norms pending',
              color: MirrorColors.infoFg,
              icon: Icons.hourglass_empty_rounded,
            ),
            const BandChip(
              band: SemanticBand.inValidation,
              compact: true,
              customLabel: 'COG_BAND on release',
            ),
          ],
        ),
      ],
    );
  }

  Widget _hfSummary() {
    final hist = r.hfHistory;
    final devs = [
      for (final s in hist)
        if (s.deviation != null) s.deviation!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.hfBuilding) ...[
          Row(
            children: [
              const MindIllustrationView(
                kind: MindIllustration.calendar14,
                size: 56,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${r.hfBaselineDay ?? '—'} of ${HfBaseline.baselineDays}',
                      key: const ValueKey('mind_hf_day'),
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'Building your personal voice baseline — no alerts yet (G-28)',
                      style: TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ((r.hfBaselineDay ?? 0) / HfBaseline.baselineDays).clamp(
                0,
                1,
              ),
              minHeight: 10,
              backgroundColor: AnaemiaUi.outline,
              color: AnaemiaUi.primary,
            ),
          ),
        ] else ...[
          RangeGauge(
            scale: const RangeScale(
              breakpoints: [0, 2, 3, 5],
              labels: ['< 2 usual', '2–3 watch', '> 3 alert'],
              colors: [
                AnaemiaUi.segNormal,
                AnaemiaUi.segBorder,
                AnaemiaUi.segHigh,
              ],
            ),
            value: (r.overall['HF_VOICE_DEV'] ?? 0).clamp(0, 5),
            pinColor: BandVisualStyle.forBand(r.band).foreground,
          ),
          const SizedBox(height: 8),
          if (devs.isNotEmpty) ...[
            const Text(
              'Deviation over the last days',
              style: TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 54,
              child: CustomPaint(
                key: const ValueKey('mind_hf_trend'),
                painter: _TrendPainter(
                  devs.length > 14 ? devs.sublist(devs.length - 14) : devs,
                  HfBaseline.alertThreshold,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _partRow(MindPartResult s) {
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
                  : s.band == SemanticBand.inValidation
                  ? 'Not used (G-24)'
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
        if (s.answers.isNotEmpty) ...[
          const SizedBox(height: 8),
          _answerGrid(s),
        ],
        if (s.items.isNotEmpty && p.kind == MindKind.cognitive) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final it in s.items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AnaemiaUi.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    it,
                    style: const TextStyle(
                      color: AnaemiaUi.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (p.kind == MindKind.hfVoice &&
            s.values.keys.any((k) => k.startsWith('F_'))) ...[
          const SizedBox(height: 8),
          _hfFeatureTable(s),
        ],
        if (s.texts['transcript'] != null) ...[
          const SizedBox(height: 6),
          Text(
            '“${_excerpt(s.texts['transcript']!)}”',
            style: const TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
        ],
        if (s.texts['recognised'] != null) ...[
          const SizedBox(height: 6),
          AnaemiaUi.kvRow('Target', s.texts['target'] ?? ''),
          AnaemiaUi.kvRow('Heard', s.texts['recognised']!),
        ],
        if (p.kind == MindKind.mood && s.values.containsKey('PHQ9')) ...[
          const SizedBox(height: 8),
          RangeGauge(
            scale: const RangeScale(
              breakpoints: [0, 5, 10, 15, 27],
              labels: ['< 5 normal', '5–9 mild', '10–14 mod.', '≥ 15 severe'],
              colors: [
                AnaemiaUi.segNormal,
                AnaemiaUi.segBorder,
                AnaemiaUi.segHigh,
                AnaemiaUi.segHigh,
              ],
            ),
            value: s.values['PHQ9']!.clamp(0, 27),
            pinColor: style.foreground,
          ),
        ],
        if (p.kind == MindKind.mood && s.values.containsKey('GAD7')) ...[
          const SizedBox(height: 8),
          RangeGauge(
            scale: const RangeScale(
              breakpoints: [0, 5, 10, 15, 21],
              labels: ['< 5 normal', '5–9 mild', '10–14 mod.', '≥ 15 severe'],
              colors: [
                AnaemiaUi.segNormal,
                AnaemiaUi.segBorder,
                AnaemiaUi.segHigh,
                AnaemiaUi.segHigh,
              ],
            ),
            value: s.values['GAD7']!.clamp(0, 21),
            pinColor: style.foreground,
          ),
        ],
        if (p.kind == MindKind.stroke && s.assessed) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in s.values.entries)
                if (!e.key.startsWith('DROP') && e.key != 'WER')
                  AnaemiaUi.tag(
                    '${e.key} ${e.value.toStringAsFixed(e.key.contains('ARM') ? 0 : 2)}${e.key.contains('ARM') ? ' cm' : ''}',
                    color: style.foreground,
                    icon: Icons.analytics_outlined,
                  ),
              if (s.texts['FACE_ASYM_SIDE'] != null)
                AnaemiaUi.tag(
                  'FACE_ASYM_SIDE ${s.texts['FACE_ASYM_SIDE']}',
                  color: style.foreground,
                  icon: Icons.face_rounded,
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// The six AUD-12 features: today's value and, after the baseline, the
  /// distance from the member's own mean in standard deviations.
  Widget _hfFeatureTable(MindPartResult s) {
    const units = ['Hz', '%', '%', 'Hz', 'dB', ''];
    const labels = [
      'Pitch',
      'Jitter',
      'Shimmer',
      'Spectral centroid',
      'Harmonic ratio',
      'Pause share',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Voice features (AUD-12)',
          style: TextStyle(
            color: AnaemiaUi.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < VoiceFeatures.hfVectorNames.length; i++)
          Builder(
            builder: (context) {
              final name = VoiceFeatures.hfVectorNames[i];
              final v = s.values['F_$name'];
              final z = s.values['Z_$name'];
              if (v == null) return const SizedBox.shrink();
              final shown = i == 5
                  ? '${(v * 100).toStringAsFixed(0)} %'
                  : '${v.toStringAsFixed(i == 1 || i == 2 ? 2 : 0)} ${units[i]}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        labels[i],
                        style: const TextStyle(
                          color: AnaemiaUi.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      shown,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 74,
                      child: Text(
                        z == null ? 'baseline' : '${z.toStringAsFixed(1)} SD',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: z != null && z >= HfBaseline.alertThreshold
                              ? MirrorColors.warningFg
                              : AnaemiaUi.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  static String _excerpt(String t) {
    final ws = t.trim().split(RegExp(r'\s+'));
    return ws.length <= 24 ? t.trim() : '${ws.take(24).join(' ')} …';
  }

  Widget _answerGrid(MindPartResult s) {
    final q = s.id == 'phq9' ? MindTexts.phq9 : MindTexts.gad7;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < q.questions.length; i++)
          Builder(
            builder: (context) {
              final v = s.answers[q.questions[i].id] ?? 0;
              final crisis = q.crisisItemId == q.questions[i].id && v > 0;
              final color = crisis
                  ? MirrorColors.emergencySolid
                  : v == 0
                  ? AnaemiaUi.segNormal
                  : v == 1
                  ? AnaemiaUi.segBorder
                  : AnaemiaUi.segHigh;
              return Tooltip(
                message: q.questions[i].text,
                child: Container(
                  width: 38,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Q${i + 1}',
                        style: const TextStyle(
                          color: AnaemiaUi.muted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$v',
                        style: TextStyle(
                          color: AnaemiaUi.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
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
      MindKind.cognitive => ('animals', 0),
      MindKind.mood => ('points', 0),
      MindKind.hfVoice => ('SD', 1),
      MindKind.stroke => ('', 0),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: p.kind == MindKind.stroke
          ? const Text(
              'The stroke check is yes / no, so no baseline is built. Each check is kept in History.',
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
              'No confirmatory test is needed from this result.',
              icon: Icons.check_circle_rounded,
            ),
            AnaemiaUi.bullet(switch (p.kind) {
              MindKind.cognitive =>
                'Repeat in 6 months to build your own baseline; sooner if you notice memory or word-finding problems. A clinician MoCA is the confirmatory test.',
              MindKind.mood =>
                'Repeat in 2 weeks or when your clinician asks. Helplines stay one tap away.',
              MindKind.hfVoice =>
                'Record again tomorrow, same place and time. Keep your daily weight and symptom diary.',
              MindKind.stroke =>
                'If any symptom appears or changes, repeat the check or call emergency services at once.',
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
            'Language, recognition, audio quality, room noise, sensors, algorithm and rules (operator view)',
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
              '${r.confidence.toStringAsFixed(2)} = capture ${q.captureQualityScore.toStringAsFixed(2)} × model ${p.kind == MindKind.mood ? '0.95' : '0.85'} (hidden below 0.60, G-23)',
            ),
            if (p.languages.length > 1)
              AnaemiaUi.kvRow(
                'Language',
                '${q.language.label} (${q.language.localeId})',
              ),
            if (p.tasks.any((t) => t.type == MindTaskType.speechTranscribe))
              AnaemiaUi.kvRow(
                'Speech recognition',
                q.sttAvailable
                    ? 'on-device recogniser'
                    : 'not available — simulated / helper',
              ),
            if (p.usesMicrophone)
              AnaemiaUi.kvRow(
                'Audio (CAP-13)',
                '${q.audioSource}${q.clipPct != null ? ' · clipping ${q.clipPct!.toStringAsFixed(1)} % (≤ 1 %)' : ''}${q.snrDb != null ? ' · SNR ${q.snrDb!.toStringAsFixed(0)} dB (≥ 15)' : ''}',
              ),
            if (p.requiredGates.contains(GateId.g18))
              AnaemiaUi.kvRow(
                'Room noise (G-18)',
                q.ambientDba != null
                    ? '${q.ambientDba!.toStringAsFixed(0)} dBA · limit 45'
                    : 'not measured',
              ),
            if (p.requiredGates.contains(GateId.g17))
              AnaemiaUi.kvRow(
                'Mic self-check (G-17)',
                q.micSelfCheck ? 'passed' : 'not run (advisory)',
              ),
            if (p.usesCamera)
              AnaemiaUi.kvRow(
                'Camera (MOV-06)',
                q.cameraUsed
                    ? 'front camera landmarks'
                    : 'not available — simulated face',
              ),
            if (p.usesMotion)
              AnaemiaUi.kvRow(
                'Motion (MOV-07)',
                q.motionUsed
                    ? 'accelerometer, 10 s hold'
                    : 'not available — simulated',
              ),
            if (r.onsetLabel != null)
              AnaemiaUi.kvRow('Onset time', r.onsetLabel!),
            if (q.taskSeconds.isNotEmpty)
              AnaemiaUi.kvRow(
                'Task durations',
                q.taskSeconds.entries
                    .map((e) => '${e.key} ${e.value.toStringAsFixed(0)} s')
                    .join(' · '),
              ),
            AnaemiaUi.kvRow('Retakes', '${q.retakes} (G-25 max 3)'),
            AnaemiaUi.kvRow('Input', q.simulated ? 'simulated' : 'member'),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values, this.threshold);
  final List<double> values;
  final double threshold;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = [threshold * 1.5, ...values].reduce((a, b) => a > b ? a : b);
    double y(double v) => size.height - (v / maxV) * (size.height - 6) - 3;
    double x(int i) => values.length == 1
        ? size.width / 2
        : i * size.width / (values.length - 1);
    final thr = Paint()
      ..color = const Color(0xFFDC2626).withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, y(threshold)),
      Offset(size.width, y(threshold)),
      thr,
    );
    final line = Paint()
      ..color = const Color(0xFF0B7A75)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      if (i == 0) {
        path.moveTo(x(i), y(values[i]));
      } else {
        path.lineTo(x(i), y(values[i]));
      }
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(
        Offset(x(i), y(values[i])),
        i == values.length - 1 ? 4 : 2.5,
        Paint()
          ..color = values[i] >= threshold
              ? const Color(0xFFDC2626)
              : const Color(0xFF0B7A75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.values != values;
}
