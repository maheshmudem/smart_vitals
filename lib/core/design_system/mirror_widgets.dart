import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/entities/enums.dart';
import '../domain/entities/marker_envelope.dart';
import '../domain/entities/screening_catalogue_item.dart';
import '../domain/gates/gate_evaluator.dart';
import 'mirror_theme.dart';

/// Accessible BandChip pairing colour + icon + text (never colour-only).
class BandChip extends StatelessWidget {
  const BandChip({
    super.key,
    required this.band,
    this.compact = false,
    this.customLabel,
  });

  final SemanticBand band;
  final bool compact;
  final String? customLabel;

  @override
  Widget build(BuildContext context) {
    final style = BandVisualStyle.forBand(band);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 2.5 : 5,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: style.foreground.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: compact ? 12 : 15, color: style.foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              customLabel ?? style.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: style.foreground,
                fontSize: compact ? 10.5 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// UrgencyBanner for Emergency / Urgent / Routine notifications (ALG-RSK-02).
class UrgencyBanner extends StatelessWidget {
  const UrgencyBanner({
    super.key,
    required this.urgency,
    required this.title,
    required this.subtitle,
    this.ruleCodes = const [],
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  final UrgencyLevel urgency;
  final String title;
  final String subtitle;
  final List<String> ruleCodes;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    if (urgency == UrgencyLevel.none) return const SizedBox.shrink();

    final isEmergency = urgency == UrgencyLevel.emergency;
    final isUrgent = urgency == UrgencyLevel.urgent;

    final bgColor = isEmergency
        ? MirrorColors.emergencySolid
        : (isUrgent ? MirrorColors.dangerBg : MirrorColors.warningBg);
    final fgColor = isEmergency
        ? Colors.white
        : (isUrgent ? MirrorColors.dangerFg : MirrorColors.warningFg);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fgColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isEmergency
                    ? Icons.emergency_rounded
                    : (isUrgent
                          ? Icons.priority_high_rounded
                          : Icons.info_outline_rounded),
                color: fgColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${urgency.label.toUpperCase()} · $title',
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (ruleCodes.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: fgColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ruleCodes.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: fgColor.withValues(alpha: 0.92),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (primaryActionLabel != null && onPrimaryAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: isEmergency ? Colors.white : fgColor,
                  foregroundColor: isEmergency
                      ? MirrorColors.emergencySolid
                      : Colors.white,
                  minimumSize: const Size(100, 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                ),
                onPressed: onPrimaryAction,
                child: Text(
                  primaryActionLabel!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ConfidenceMeter (0.0 to 1.0) enforcing G-23 (< 0.60 hidden).
class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter({super.key, required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    final isLow = confidence < 0.60;
    final color = isLow
        ? MirrorColors.dangerFg
        : (confidence >= 0.80
              ? MirrorColors.successFg
              : MirrorColors.warningFg);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 34,
          height: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence.clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            isLow ? '$pct% (<60%)' : '$pct% conf.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Standardized MetricTile displaying any `MarkerEnvelope<T>` with G-23 and G-24 rules.
/// Designed to be 100% overflow-free in both 1-column lists and 2-column grids on 360px phones.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.marker, this.onTap});

  final MarkerEnvelope<dynamic> marker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final showNumeric = marker.shouldShowNumericValue;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final range = marker.normalRangeLabel;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: range == null
                          ? marker.displayName
                          : '${marker.displayName} · normal $range',
                      child: Text(
                        marker.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    ),
                  ),
                  if (marker.isEstimate)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: MirrorColors.infoBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'est.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: MirrorColors.infoFg,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      marker.displayText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: showNumeric ? 20 : 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: showNumeric ? scheme.onSurface : muted,
                      ),
                    ),
                  ),
                  if (showNumeric && marker.unit.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        marker.unit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BandChip(band: marker.band, compact: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(marker.confidence * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// GateBlockerCard (T-GATE template) explaining why a Gate (G-xx) blocked or modified access.
class GateBlockerCard extends StatelessWidget {
  const GateBlockerCard({super.key, required this.outcome, this.onFixPressed});

  final GateCheckOutcome outcome;
  final VoidCallback? onFixPressed;

  @override
  Widget build(BuildContext context) {
    final color = outcome.passed
        ? MirrorColors.successFg
        : (outcome.isAdvisoryOnly
              ? MirrorColors.infoFg
              : MirrorColors.warningFg);
    final bg = outcome.passed
        ? MirrorColors.successBg
        : (outcome.isAdvisoryOnly
              ? MirrorColors.infoBg
              : MirrorColors.warningBg);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            outcome.passed
                ? Icons.verified_rounded
                : (outcome.isAdvisoryOnly
                      ? Icons.info_outline_rounded
                      : Icons.lock_outline_rounded),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${outcome.gate.code} · ${outcome.gate.title}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  outcome.reason,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
                if (!outcome.passed &&
                    outcome.fixButtonLabel != null &&
                    onFixPressed != null) ...[
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(100, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    onPressed: onFixPressed,
                    child: Text(outcome.fixButtonLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter for live or static rPPG / PPG / Sonar waveforms.
class WaveformPainterView extends StatelessWidget {
  const WaveformPainterView({
    super.key,
    this.phase = 0.0,
    this.snrDb = 7.4,
    this.height = 90,
    this.light = false,
  });

  final double phase;
  final double snrDb;
  final double height;

  /// Light variant for white report cards (muted panel, teal trace).
  final bool light;

  @override
  Widget build(BuildContext context) {
    final isClean = snrDb >= 3.0;
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: light
            ? MirrorColors.surfaceVariantLight
            : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'BVP Pulse Waveform (POS + EfficientPhys)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: light ? MirrorColors.inkMutedLight : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'SNR ${snrDb.toStringAsFixed(1)} dB ${isClean ? "(PASS)" : "(RETAKE)"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isClean
                        ? (light
                              ? MirrorColors.successFg
                              : const Color(0xFF4ADE80))
                        : (light
                              ? MirrorColors.dangerFg
                              : const Color(0xFFF87171)),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _PpgWavePainter(
                phase: phase,
                isClean: isClean,
                light: light,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PpgWavePainter extends CustomPainter {
  _PpgWavePainter({
    required this.phase,
    required this.isClean,
    this.light = false,
  });

  final double phase;
  final bool isClean;
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isClean
          ? (light ? MirrorColors.primary : const Color(0xFF4FD1C5))
          : (light ? MirrorColors.dangerFg : const Color(0xFFF87171))
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final midY = size.height * 0.55;
    for (int x = 0; x <= size.width.toInt(); x++) {
      final t = (x / 52.0) + phase;
      // Synthetic arterial pulse with systolic peak and dicrotic notch (Spec §4.8)
      final cycle = t % (2 * math.pi);
      final systolic = math.exp(-math.pow(cycle - 1.4, 2) / 0.18);
      final dicrotic = 0.38 * math.exp(-math.pow(cycle - 2.6, 2) / 0.25);
      final noise = isClean ? 0.0 : 0.28 * math.sin(x * 0.9);
      final y =
          midY - (systolic + dicrotic + noise - 0.35) * (size.height * 0.58);
      if (x == 0) {
        path.moveTo(x.toDouble(), y);
      } else {
        path.lineTo(x.toDouble(), y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PpgWavePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.isClean != isClean ||
      oldDelegate.light != light;
}

/// Interactive FDI Tooth Chart (Permanent 11–48 & Primary 51–85, Spec §7.1).
class FdiToothChartWidget extends StatelessWidget {
  const FdiToothChartWidget({
    super.key,
    required this.isChildMode,
    required this.findings,
    required this.unseenTeeth,
    required this.sealantTeeth,
    required this.onToothSelected,
    this.mixedDentition = false,
  });

  final bool isChildMode;

  /// Ages 6–12: primary chart plus the first permanent molars 16/26/36/46
  /// (ALG-DEN-02 `mixed_age_range`).
  final bool mixedDentition;
  final List<ToothFinding> findings;
  final List<int> unseenTeeth;
  final List<int> sealantTeeth;
  final ValueChanged<int> onToothSelected;

  @override
  Widget build(BuildContext context) {
    final upperArch = isChildMode
        ? (mixedDentition
              ? const [16, 55, 54, 53, 52, 51, 61, 62, 63, 64, 65, 26]
              : const [55, 54, 53, 52, 51, 61, 62, 63, 64, 65])
        : const [
            18,
            17,
            16,
            15,
            14,
            13,
            12,
            11,
            21,
            22,
            23,
            24,
            25,
            26,
            27,
            28,
          ];
    final lowerArch = isChildMode
        ? (mixedDentition
              ? const [46, 85, 84, 83, 82, 81, 71, 72, 73, 74, 75, 36]
              : const [85, 84, 83, 82, 81, 71, 72, 73, 74, 75])
        : const [
            48,
            47,
            46,
            45,
            44,
            43,
            42,
            41,
            31,
            32,
            33,
            34,
            35,
            36,
            37,
            38,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isChildMode
              ? (mixedDentition
                    ? 'Mixed Dentition Chart (FDI 51–85 + 16/26/36/46)'
                    : 'Primary Dentition Chart (FDI 51–85)')
              : 'Permanent Dentition Chart (FDI 11–48)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        _buildArchRow('Upper Arch', upperArch),
        const SizedBox(height: 10),
        _buildArchRow('Lower Arch', lowerArch),
      ],
    );
  }

  Widget _buildArchRow(String label, List<int> teeth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: MirrorColors.inkMutedLight,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: teeth.map((fdi) {
            final finding = findings
                .where((f) => f.toothFdi == fdi)
                .firstOrNull;
            final isUnseen = unseenTeeth.contains(fdi);
            final needsSealant = sealantTeeth.contains(fdi);

            Color bg = MirrorColors.successBg;
            Color fg = MirrorColors.successFg;
            if (isUnseen) {
              bg = MirrorColors.neutralBg;
              fg = MirrorColors.neutralFg;
            } else if (finding != null) {
              final style = BandVisualStyle.forBand(finding.band);
              bg = style.background;
              fg = style.foreground;
            } else if (needsSealant) {
              bg = MirrorColors.infoBg;
              fg = MirrorColors.infoFg;
            }

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onToothSelected(fdi),
              child: Container(
                width: 36,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: fg.withValues(alpha: 0.45)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$fdi',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                    Text(
                      isUnseen
                          ? '?'
                          : (finding != null
                                ? finding.findingCode
                                      .substring(0, 3)
                                      .toUpperCase()
                                : (needsSealant ? 'SEAL' : 'OK')),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Medical Disclaimer Footer required by Spec §13 & Phase 6.
class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MirrorColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            size: 18,
            color: MirrorColors.inkMutedLight,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Clinical Safety Notice: VitalsMirror outputs are wellness and screening bands, NOT a confirmed medical diagnosis. Every flag must be confirmed or ruled out by standard laboratory investigations and a qualified clinician\'s judgement (Spec §13).',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: MirrorColors.inkMutedLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inspector BottomSheet showing any Screen's ID (S-xx), Purpose, Gates (G-xx),
/// and Lifecycle States — helpful anytime and anywhere if the user has any doubts.
void showScreenGateLifecycleSheet(BuildContext context, String screenId) {
  final spec = VitalsMirrorCatalogRegistry.findScreen(screenId);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      if (spec == null) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Screen specification not found.'),
        );
      }
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.68,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MirrorColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${spec.screenId} · [${spec.provenanceTag}]',
                      style: const TextStyle(
                        color: MirrorColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    'Feature ${spec.featureId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: MirrorColors.inkMutedLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                spec.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                spec.purpose,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const Divider(height: 24),
              const Text(
                'Entry & Runtime Gates (G-01 .. G-37)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (spec.entryGates.isEmpty && spec.runtimeGates.isEmpty)
                const Text(
                  'No blocking gates — open access (or safety override screen).',
                  style: TextStyle(
                    fontSize: 13,
                    color: MirrorColors.inkMutedLight,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...spec.entryGates.map(
                      (g) => Chip(
                        avatar: const Icon(Icons.login_rounded, size: 15),
                        label: Text('Entry ${g.code}: ${g.title}'),
                      ),
                    ),
                    ...spec.runtimeGates.map(
                      (g) => Chip(
                        avatar: const Icon(Icons.bolt_rounded, size: 15),
                        label: Text('Runtime ${g.code}: ${g.title}'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              const Text(
                'Feature & Screen Lifecycle States',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...spec.lifecycleStates.map(
                (st) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.account_tree_outlined,
                        size: 16,
                        color: MirrorColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${st.label}: ${st.description}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (spec.algorithmsUsed.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Algorithms Executed / Fed',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  spec.algorithmsUsed.join(' · '),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MirrorColors.primary,
                  ),
                ),
              ],
            ],
          );
        },
      );
    },
  );
}
