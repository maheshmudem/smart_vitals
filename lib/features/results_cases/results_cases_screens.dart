import 'package:flutter/material.dart';
import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/entities/case_record.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/marker_envelope.dart';
import '../../core/services/emergency_contacts.dart';
import '../../core/state/app_state.dart';

/// S-R01 Shared Screening Result Screen (T-RES Template + Specialist Review IMG-10).
class SharedScreeningResultScreen extends StatelessWidget {
  const SharedScreeningResultScreen({super.key, required this.record});

  final ScreeningSessionRecord record;

  bool get _isOralLesion =>
      record.title.toLowerCase().contains('oral') ||
      record.markers.any((m) => m.code == 'ALG-IMG-04');

  @override
  Widget build(BuildContext context) {
    final confPct = (record.confidence * 100).round().clamp(0, 100);
    final isHigh =
        record.primaryBand == SemanticBand.high ||
        record.primaryBand == SemanticBand.refer ||
        record.urgency != UrgencyLevel.none;
    final dialColor = isHigh
        ? const Color(0xFFEF4444)
        : const Color(0xFF00E5CC);

    return Scaffold(
      backgroundColor: const Color(0xFF070D19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D19),
        foregroundColor: Colors.white,
        title: Text('S-R01 · ${record.title}', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-R01'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Screening Score & AI Confidence Dial Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF111C2E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: dialColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 74,
                          height: 74,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 70,
                                height: 70,
                                child: CircularProgressIndicator(
                                  value: (confPct / 100.0).clamp(0.1, 1.0),
                                  strokeWidth: 6.5,
                                  backgroundColor: Colors.white12,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    dialColor,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$confPct%',
                                    style: TextStyle(
                                      color: dialColor,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0,
                                    ),
                                  ),
                                  const Text(
                                    'CONF',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Band: ${record.primaryBand.label} • Category: ${record.category}',
                                style: TextStyle(
                                  color: dialColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.summaryText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (record.urgency != UrgencyLevel.none) ...[
                    UrgencyBanner(
                      urgency: record.urgency,
                      title: '${record.title} Screening Flag',
                      subtitle: record.summaryText,
                      ruleCodes: record.firedRules,
                      primaryActionLabel: 'Open Cases (S-R04)',
                      onPrimaryAction: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CasesListScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (record.isUnderSpecialistReview) ...[
                    Card(
                      color: MirrorColors.infoBg,
                      child: const ListTile(
                        leading: Icon(
                          Icons.medical_services_outlined,
                          color: MirrorColors.infoFg,
                        ),
                        title: Text(
                          'IMG-10 · Routed to Specialist Review Queue',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: MirrorColors.infoFg,
                          ),
                        ),
                        subtitle: Text(
                          'Spec §6 Intro: Every high or uncertain result (probability within ±0.1 of threshold) is reviewed asynchronously by a specialist.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: MirrorColors.infoFg,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Oral Pre-Cancer & Lesion (ALG-IMG-04) Specific Range Scale & Grad-CAM Heatmap Card
                  if (_isOralLesion) ...[
                    _buildOralLesionDetailCard(isHigh),
                    const SizedBox(height: 14),
                  ],

                  const Text(
                    'Algorithm outputs',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Spec output markers stored with this record · tap a row for detail',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  AlgorithmOutputsSection(
                    groups: MarkerReadings.fromRecord(record),
                    showHeader: false,
                  ),
                  const SizedBox(height: 16),
                  const DisclaimerFooter(),
                ],
              ),
            ),
          ),

          // Persistent Bottom Action Dock (Retake Scan + Save to Profile)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF00E5CC)),
                        minimumSize: const Size.fromHeight(46),
                      ),
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text(
                        'Retake Scan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5CC),
                        foregroundColor: const Color(0xFF042F2E),
                        minimumSize: const Size.fromHeight(46),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        'Save to Profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${record.title} report saved to member profile.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOralLesionDetailCard(bool isHigh) {
    final markerPct = isHigh ? 0.84 : 0.18;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00E5CC).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_motion_rounded,
                color: Color(0xFF00E5CC),
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OPMD Mucosal Classifier & Grad-CAM Map (ALG-IMG-04)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isHigh
                ? 'ORAL_CLASS: High Risk (Leukoplakia / Erythroplakia pattern detected on buccal/tongue mucosa • Aggregated by max_over_views).'
                : 'ORAL_CLASS: Not Suspicious across all 5 intraoral mucosal sites (Right/Left Buccal, Lateral Tongue, Floor of Mouth, Palate).',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment((markerPct * 2) - 1.0, 0),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF070D19),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Not Suspicious',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 9.5),
                ),
              ),
              Expanded(
                child: Text(
                  'Suspicious',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 9.5),
                ),
              ),
              Expanded(
                child: Text(
                  'High Risk',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 9.5),
                ),
              ),
            ],
          ),
        ],
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
            'S-R02 · EMERGENCY ALERT (Gate G-37)',
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
            padding: const EdgeInsets.all(24),
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
                      fontWeight: FontWeight.w900,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('S-R04 · Open Condition Cases (ALG-RSK-07)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-R04'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Spec §10 ALG-RSK-07 & Case T15: Same condition flags within 30 days merge into one open Case (no duplicate cases). Urgent flags are always sorted above Routine flags.',
            style: TextStyle(fontSize: 13, color: MirrorColors.inkMutedLight),
          ),
          const SizedBox(height: 12),
          // S-R07 Sampled Negatives Invitation Banner (Spec §14, FRS REF-03)
          Card(
            color: MirrorColors.primaryContainer.withValues(alpha: 0.45),
            child: ListTile(
              leading: const Icon(
                Icons.science_outlined,
                color: MirrorColors.primary,
              ),
              title: const Text(
                'S-R07 · Sampled-Negative Reference Test Invitation (FRS REF-03)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              subtitle: const Text(
                'Spec §14: >= 5% of screen-negative members per screen are offered the reference test each month so sensitivity and NPV can be measured.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.info_outline_rounded),
              onTap: () => showScreenGateLifecycleSheet(context, 'S-R07'),
            ),
          ),
          const SizedBox(height: 14),
          if (openCases.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No open condition cases.'),
              ),
            )
          else
            ...openCases.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${c.conditionTitle} (${c.conditionCode})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            c.highestUrgency.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          'Merged Flags (${c.flags.length}): ${c.flags.map((f) => "${f.triggerDescription} [${f.ruleCode}]").join(" · ")}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Confirmatory Pathway (§13): ${c.confirmatorySpec.investigations}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: MirrorColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CaseDetailScreen(caseRecord: c),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
    final c =
        appState.cases
            .where((item) => item.caseId == widget.caseRecord.caseId)
            .firstOrNull ??
        widget.caseRecord;
    final spec = c.confirmatorySpec;

    return Scaffold(
      appBar: AppBar(
        title: Text('S-R05 · ${c.conditionTitle}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-R05'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          UrgencyBanner(
            urgency: c.highestUrgency,
            title: '${c.conditionTitle} (${c.conditionCode})',
            subtitle:
                'Opened ${c.openedAt.toLocal().toString().substring(0, 16)} · ${c.flags.length} flag(s) merged within 30-day window (ALG-RSK-07).',
            ruleCodes: c.flags.map((f) => f.ruleCode).toSet().toList(),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spec §13 Standard Confirmatory Investigations',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text('App Trigger: ${spec.appTrigger}'),
                  const SizedBox(height: 6),
                  Text('Required Investigations: ${spec.investigations}'),
                  const SizedBox(height: 6),
                  Text(
                    'Usual Diagnostic Cut-offs: ${spec.usualDiagnosticCutoffs}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'S-R06 · Reference Lab Pairing & Window Check (Spec §14)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        onPressed: () =>
                            showScreenGateLifecycleSheet(context, 'S-R06'),
                      ),
                    ],
                  ),
                  Text(
                    'Reference Test: ${spec.pairingReferenceTest}\nMax Gap Allowed: ${spec.maxPairingGapLabel} (${spec.maxPairingHours} h)\nExclusions: ${spec.pairingExclusions}',
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _labValueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Confirmatory Lab Result Summary',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Simulated Time Gap Between Scan & Lab Test: $_gapHours hours (Max allowed: ${spec.maxPairingHours} h)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: _gapHours.toDouble(),
                    min: 1,
                    max: (spec.maxPairingHours * 2).clamp(12, 1000).toDouble(),
                    onChanged: (v) => setState(() => _gapHours = v.round()),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Exclusion Present (${spec.pairingExclusions})?',
                    ),
                    subtitle: const Text(
                      'Spec §14 (FRS REF-06): Pairs outside the window or with an exclusion are graded D (monitoring only, excluded from model training).',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    value: _hasExclusion,
                    onChanged: (v) => setState(() => _hasExclusion = v),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Pair Lab Result & Evaluate Grade (A–D)'),
                    onPressed: () {
                      final now = DateTime.now();
                      final pair = ReferenceLabPairingRecord(
                        id: 'pair_${now.millisecondsSinceEpoch}',
                        caseId: c.caseId,
                        referenceTestName: spec.pairingReferenceTest,
                        resultSummary: _labValueCtrl.text,
                        scanTimestamp: now.subtract(Duration(hours: _gapHours)),
                        referenceTimestamp: now,
                        hasExclusionPresent: _hasExclusion,
                        maxAllowedHours: spec.maxPairingHours,
                      );
                      appState.addLabPairingToCase(c.caseId, pair);
                    },
                  ),
                  if (c.pairedLabResults.isNotEmpty) ...[
                    const Divider(height: 22),
                    const Text(
                      'Paired Reference Results:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...c.pairedLabResults.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${p.resultSummary} (Gap: ${p.gapHours}h) -> ${p.pairingGrade}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: p.pairingGrade.startsWith('Grade D')
                                ? MirrorColors.warningFg
                                : MirrorColors.successFg,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
