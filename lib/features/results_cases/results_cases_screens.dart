import 'package:flutter/material.dart';
import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/design_system/mirror_ui.dart';
import '../../core/domain/entities/case_record.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/marker_envelope.dart';
import '../../core/services/emergency_contacts.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';

/// S-R01 Shared Screening Result Screen (T-RES Template + Specialist Review IMG-10).
class SharedScreeningResultScreen extends StatelessWidget {
  const SharedScreeningResultScreen({super.key, required this.record});

  final ScreeningSessionRecord record;

  bool get _isOralLesion =>
      record.title.toLowerCase().contains('oral') ||
      record.markers.any((m) => m.code == 'ALG-IMG-04');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final confPct = (record.confidence * 100).round().clamp(0, 100);
    final isHigh =
        record.primaryBand == SemanticBand.high ||
        record.primaryBand == SemanticBand.refer ||
        record.urgency != UrgencyLevel.none;
    final band = BandVisualStyle.forBand(record.primaryBand);
    final dialColor = isHigh ? MirrorColors.dangerFg : scheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(record.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'About this screen',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-R01'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: MirrorSpace.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Summary card: confidence dial + band
            Card(
              child: Padding(
                padding: const EdgeInsets.all(MirrorSpace.lg),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: (confPct / 100.0).clamp(0.1, 1.0),
                              strokeWidth: 6,
                              strokeCap: StrokeCap.round,
                              backgroundColor: scheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                dialColor,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$confPct%',
                                    style: t.titleLarge?.copyWith(
                                      color: dialColor,
                                      height: 1.0,
                                    ),
                                  ),
                                  Text('confidence', style: t.labelSmall),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: MirrorSpace.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(record.title, style: t.titleMedium),
                          const SizedBox(height: MirrorSpace.xs),
                          Text(record.category, style: t.bodySmall),
                          const SizedBox(height: MirrorSpace.sm),
                          BandChip(band: record.primaryBand),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (record.urgency == UrgencyLevel.none) ...[
              const SizedBox(height: MirrorSpace.md),
              Container(
                padding: const EdgeInsets.all(MirrorSpace.md + 2),
                decoration: BoxDecoration(
                  color: band.background,
                  borderRadius: BorderRadius.circular(MirrorRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(band.icon, size: 18, color: band.foreground),
                    const SizedBox(width: MirrorSpace.sm),
                    Expanded(
                      child: Text(
                        record.summaryText,
                        style: TextStyle(
                          color: band.foreground,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MirrorSpace.xl),

            if (record.urgency != UrgencyLevel.none) ...[
              UrgencyBanner(
                urgency: record.urgency,
                title: '${record.title} flag',
                subtitle: record.summaryText,
                ruleCodes: record.firedRules,
                primaryActionLabel: 'Open cases',
                onPrimaryAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CasesListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: MirrorSpace.xl),
            ],
            if (record.isUnderSpecialistReview) ...[
              const InfoNote(
                title: 'Sent for specialist review',
                icon: Icons.medical_services_outlined,
                text:
                    'High or borderline results are checked by a specialist. You will be notified when the review is done.',
              ),
              const SizedBox(height: MirrorSpace.xl),
            ],

            if (_isOralLesion) ...[
              _buildOralLesionDetailCard(context, isHigh),
              const SizedBox(height: MirrorSpace.xl),
            ],

            const SectionHeader(
              title: 'Algorithm outputs',
              subtitle:
                  'Markers stored with this result · tap a row for detail',
            ),
            AlgorithmOutputsSection(
              groups: MarkerReadings.fromRecord(record),
              showHeader: false,
            ),
            const SizedBox(height: MirrorSpace.lg),
            const DisclaimerFooter(),
          ],
        ),
      ),
      bottomNavigationBar: PrimaryBottomButton(
        label: 'Save to Profile',
        icon: Icons.check_circle_rounded,
        secondaryLabel: 'Retake Scan',
        onSecondary: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${record.title} saved to profile')),
          );
        },
      ),
    );
  }

  Widget _buildOralLesionDetailCard(BuildContext context, bool isHigh) {
    final t = Theme.of(context).textTheme;
    final markerPct = isHigh ? 0.84 : 0.18;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MirrorSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: Icons.auto_awesome_motion_rounded,
                  size: 36,
                ),
                const SizedBox(width: MirrorSpace.md),
                Expanded(
                  child: Text('Mouth lining classifier', style: t.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: MirrorSpace.md),
            Text(
              isHigh
                  ? 'High risk: a leukoplakia / erythroplakia pattern was seen on the cheek or tongue lining.'
                  : 'Not suspicious across all 5 mouth sites (both cheeks, tongue side, floor of mouth, palate).',
              style: t.bodyMedium,
            ),
            const SizedBox(height: MirrorSpace.lg),
            RangeGauge(
              scale: const RangeScale(
                breakpoints: [0, 1, 2, 3],
                labels: ['Not suspicious', 'Suspicious', 'High risk'],
                colors: [
                  AnaemiaUi.segNormal,
                  AnaemiaUi.segBorder,
                  AnaemiaUi.segHigh,
                ],
              ),
              value: markerPct * 3,
              pinColor: isHigh ? MirrorColors.dangerFg : MirrorColors.successFg,
            ),
          ],
        ),
      ),
    );
  }
}

/// S-R02 Emergency Alert (Full-Screen Red Safety Override — Gate G-37).
class EmergencyAlertScreen extends StatefulWidget {
  const EmergencyAlertScreen({
    super.key,
    required this.title,
    required this.reasons,
    this.nextRouteBuilder,
    this.onAcknowledged,
  });

  final String title;
  final List<String> reasons;
  final Widget Function()? nextRouteBuilder;

  /// Called once when the member taps "I understand" (logs the
  /// acknowledgement, G-37).
  final VoidCallback? onAcknowledged;

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

/// S-R02: full-screen emergency red; the call buttons open the dialler
/// (108 / 112). Back is locked until the member acknowledges (Gate G-37,
/// NFR-023).
class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> {
  bool _acknowledged = false;
  String? _called;

  Future<void> _call(String number) async {
    final ok = await EmergencyContacts.dial(number);
    if (!mounted) return;
    setState(() => _called = number);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No dialler on this device — call $number.')),
      );
    }
  }

  void _acknowledge() {
    setState(() => _acknowledged = true);
    widget.onAcknowledged?.call();
    final next = widget.nextRouteBuilder;
    if (next != null) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => next()));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _acknowledged,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please call for help or tap "I understand" first (G-37).',
            ),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: MirrorColors.emergencySolid,
        appBar: AppBar(
          backgroundColor: MirrorColors.emergencySolid,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: const Text(
            'Emergency',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
              onPressed: () => showScreenGateLifecycleSheet(context, 'S-R02'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height - 180,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.emergency_rounded,
                    color: Colors.white,
                    size: 72,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your results need emergency attention',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final r in widget.reasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.circle,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      for (final c in EmergencyContacts.emergency) ...[
                        Expanded(
                          child: FilledButton.icon(
                            key: ValueKey('emergency_call_${c.number}'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: MirrorColors.emergencySolid,
                              minimumSize: const Size(0, 56),
                            ),
                            icon: const Icon(Icons.call_rounded),
                            label: Text(
                              'Call ${c.number}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: () => _call(c.number),
                          ),
                        ),
                        if (c != EmergencyContacts.emergency.last)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _called == null
                        ? 'Ambulance 108 · national emergency 112. Say "possible stroke" and where you are.'
                        : 'Dialler opened for $_called. Stay with the person; do not give food or drink.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('emergency_acknowledge'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _acknowledge,
                      child: const Text(
                        'I understand — view confirmatory details',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Back is locked until you acknowledge this screen (G-37).',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// S-R04 Cases List (30-Day Condition Merge ALG-RSK-07, Sorted Urgency First per Case T15)
/// + S-R03 Urgent Rescan Banner + S-R07 Sampled Negatives Invitation.
class CasesListScreen extends StatelessWidget {
  const CasesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final openCases = appState.cases;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Cases'),
        actions: [
          IconButton(
            tooltip: 'About this screen',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-R04'),
          ),
        ],
      ),
      body: ListView(
        padding: MirrorSpace.screen,
        children: [
          PageHeading(
            title: 'Condition cases',
            subtitle:
                'Flags for the same condition within 30 days are merged into one case. Urgent cases are listed first.',
          ),
          if (openCases.isEmpty)
            const EmptyState(
              icon: Icons.folder_open_rounded,
              title: 'No open cases',
              message: 'Flagged results that need a lab test appear here.',
            )
          else
            ...openCases.map((c) {
              final u = _urgencyColor(c.highestUrgency);
              return Padding(
                padding: const EdgeInsets.only(bottom: MirrorSpace.md),
                child: Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CaseDetailScreen(caseRecord: c),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(MirrorSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconBadge(
                                icon: Icons.folder_copy_outlined,
                                color: u,
                                size: 34,
                              ),
                              const SizedBox(width: MirrorSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.conditionTitle,
                                      style: t.titleMedium,
                                    ),
                                    Text(
                                      '${c.flags.length} merged ${c.flags.length == 1 ? "flag" : "flags"} · ${c.conditionCode}',
                                      style: t.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: MirrorSpace.sm),
                              MirrorPill(
                                label: c.highestUrgency.label,
                                color: u,
                              ),
                            ],
                          ),
                          const SizedBox(height: MirrorSpace.md),
                          for (final f in c.flags.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: MirrorSpace.sm),
                                  Expanded(
                                    child: Text(
                                      f.triggerDescription,
                                      style: t.bodyMedium?.copyWith(
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: MirrorSpace.sm),
                          const Divider(),
                          const SizedBox(height: MirrorSpace.md),
                          Row(
                            children: [
                              Icon(
                                Icons.science_outlined,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  c.confirmatorySpec.investigations,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.labelMedium?.copyWith(
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: MirrorSpace.md),
          // S-R07 Sampled Negatives Invitation (Spec §14, FRS REF-03)
          MirrorGroupCard(
            children: [
              MirrorNavTile(
                icon: Icons.science_outlined,
                title: 'Reference test invitations',
                subtitle:
                    'Some members with normal results are invited to a lab test so accuracy can be measured.',
                trailing: Icon(
                  Icons.info_outline_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => showScreenGateLifecycleSheet(context, 'S-R07'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _urgencyColor(UrgencyLevel u) {
    return switch (u) {
      UrgencyLevel.none => MirrorColors.successFg,
      UrgencyLevel.routine => MirrorColors.warningFg,
      UrgencyLevel.urgent || UrgencyLevel.emergency => MirrorColors.dangerFg,
    };
  }
}

/// S-R05 Case Detail & Confirmatory Tests + S-R06 Lab / Reference Result Entry (§14 Pairing).
class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.caseRecord});

  final CaseRecord caseRecord;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _labValueCtrl = TextEditingController(
    text: 'Hb 11.4 g/dL (Venous CBC)',
  );
  int _gapHours = 12;
  bool _hasExclusion = false;

  @override
  void dispose() {
    _labValueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final t = Theme.of(context).textTheme;
    final c =
        appState.cases
            .where((item) => item.caseId == widget.caseRecord.caseId)
            .firstOrNull ??
        widget.caseRecord;
    final spec = c.confirmatorySpec;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.conditionTitle, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'About this screen',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-R05'),
          ),
        ],
      ),
      body: ListView(
        padding: MirrorSpace.screen,
        children: [
          UrgencyBanner(
            urgency: c.highestUrgency,
            title: '${c.conditionTitle} (${c.conditionCode})',
            subtitle:
                'Opened ${c.openedAt.toLocal().toString().substring(0, 16)} · ${c.flags.length} flag(s) merged within 30 days.',
            ruleCodes: c.flags.map((f) => f.ruleCode).toSet().toList(),
          ),
          const SizedBox(height: MirrorSpace.xl),
          const SectionHeader(
            title: 'Confirmatory tests',
            subtitle: 'What your doctor will usually order',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MirrorSpace.lg),
              child: Column(
                children: [
                  AnaemiaUi.kvRow('Why', spec.appTrigger, keyWidth: 96),
                  const Divider(height: 16),
                  AnaemiaUi.kvRow('Tests', spec.investigations, keyWidth: 96),
                  const Divider(height: 16),
                  AnaemiaUi.kvRow(
                    'Cut-offs',
                    spec.usualDiagnosticCutoffs,
                    keyWidth: 96,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MirrorSpace.xl),
          SectionHeader(
            title: 'Add a lab result',
            subtitle: 'Pairs the lab test with your scan',
            actionLabel: 'Rules',
            onAction: () => showScreenGateLifecycleSheet(context, 'S-R06'),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MirrorSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnaemiaUi.kvRow(
                    'Reference',
                    spec.pairingReferenceTest,
                    keyWidth: 96,
                  ),
                  AnaemiaUi.kvRow(
                    'Max gap',
                    '${spec.maxPairingGapLabel} (${spec.maxPairingHours} h)',
                    keyWidth: 96,
                  ),
                  AnaemiaUi.kvRow(
                    'Exclusions',
                    spec.pairingExclusions,
                    keyWidth: 96,
                  ),
                  const SizedBox(height: MirrorSpace.lg),
                  TextField(
                    controller: _labValueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lab result summary',
                    ),
                  ),
                  const SizedBox(height: MirrorSpace.lg),
                  Text(
                    'Time between scan and lab test: $_gapHours h',
                    style: t.titleSmall,
                  ),
                  Slider(
                    value: _gapHours.toDouble(),
                    min: 1,
                    max: (spec.maxPairingHours * 2).clamp(12, 1000).toDouble(),
                    onChanged: (v) => setState(() => _gapHours = v.round()),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('An exclusion applies'),
                    subtitle: const Text(
                      'Pairs outside the window or with an exclusion are graded D and kept for monitoring only.',
                    ),
                    value: _hasExclusion,
                    onChanged: (v) => setState(() => _hasExclusion = v),
                  ),
                  const SizedBox(height: MirrorSpace.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Pair lab result'),
                      onPressed: () {
                        final now = DateTime.now();
                        final pair = ReferenceLabPairingRecord(
                          id: 'pair_${now.millisecondsSinceEpoch}',
                          caseId: c.caseId,
                          referenceTestName: spec.pairingReferenceTest,
                          resultSummary: _labValueCtrl.text,
                          scanTimestamp: now.subtract(
                            Duration(hours: _gapHours),
                          ),
                          referenceTimestamp: now,
                          hasExclusionPresent: _hasExclusion,
                          maxAllowedHours: spec.maxPairingHours,
                        );
                        appState.addLabPairingToCase(c.caseId, pair);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (c.pairedLabResults.isNotEmpty) ...[
            const SizedBox(height: MirrorSpace.xl),
            const SectionHeader(title: 'Paired results'),
            MirrorGroupCard(
              children: c.pairedLabResults.map((p) {
                final gradeD = p.pairingGrade.startsWith('Grade D');
                return MirrorNavTile(
                  icon: gradeD
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  color: gradeD
                      ? MirrorColors.warningFg
                      : MirrorColors.successFg,
                  title: p.resultSummary,
                  subtitle: 'Gap ${p.gapHours} h · ${p.pairingGrade}',
                  trailing: const SizedBox.shrink(),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
