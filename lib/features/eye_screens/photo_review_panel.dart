import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/domain/algorithms/photo_quality_analyzer.dart';
import '../anaemia/anaemia_ui_kit.dart';

/// S-E04 review panel shown after every capture: thumbnail, verdict,
/// score bars (ALG-CAP-06…10), coaching reasons, and Keep / Retake / Cancel.
/// Shared by the anaemia and the generic eye flows.
class PhotoReviewPanel extends StatelessWidget {
  const PhotoReviewPanel({
    super.key,
    required this.report,
    required this.bytes,
    required this.viewLabel,
    required this.attempt,
    required this.maxAttempts,
    required this.hasCard,
    required this.onKeep,
    required this.onRetake,
    required this.onNotAssessed,
    required this.onCancel,
    required this.placeholder,
    this.notAssessedLabel = 'Mark not assessed & continue',
    this.notAssessedHint =
        'No attempts left for this photo (G-25). It will be marked "Not assessed" and the test continues.',
  });

  final PhotoQualityReport report;
  final Uint8List? bytes;
  final String viewLabel;
  final int attempt;
  final int maxAttempts;
  final bool hasCard;
  final VoidCallback onKeep;
  final VoidCallback onRetake;
  final VoidCallback onNotAssessed;
  final VoidCallback onCancel;

  /// Drawn stand-in shown when no real photo exists (tests / no camera).
  final Widget placeholder;
  final String notAssessedLabel;
  final String notAssessedHint;

  @override
  Widget build(BuildContext context) {
    final passed = report.overallPassed;
    final canRetake = attempt < maxAttempts;
    final verdictColor = passed
        ? MirrorColors.successFg
        : MirrorColors.warningFg;
    final verdictBg = passed ? MirrorColors.successBg : MirrorColors.warningBg;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AnaemiaUi.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 92,
                      height: 69,
                      child: bytes != null
                          ? Image.memory(bytes!, fit: BoxFit.cover)
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                placeholder,
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: AnaemiaUi.tag(
                                    'Simulated',
                                    color: AnaemiaUi.muted,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          viewLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AnaemiaUi.muted,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: verdictBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                passed
                                    ? Icons.check_circle_rounded
                                    : Icons.replay_rounded,
                                size: 16,
                                color: verdictColor,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  passed ? 'Good photo' : 'Needs retake',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: verdictColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Attempt $attempt of $maxAttempts · quality ${(report.qualityScore * 100).round()}%',
                          style: const TextStyle(
                            color: AnaemiaUi.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _scoreRow(
                'Sharpness',
                report.blurScore,
                0,
                400,
                100,
                report.blurPassed,
                '${report.blurScore.round()} (≥ 100)',
              ),
              _scoreRow(
                'Glare',
                report.glarePct,
                0,
                20,
                5,
                report.glarePassed,
                '${report.glarePct.toStringAsFixed(1)}% (≤ 5%)',
                inverted: true,
              ),
              _scoreRow(
                'Dark areas',
                report.darkPct,
                0,
                40,
                10,
                report.darkPassed,
                '${report.darkPct.toStringAsFixed(1)}% (≤ 10%)',
                inverted: true,
              ),
              _scoreRow(
                report.coverageLabel,
                report.coveragePct,
                0,
                100,
                80,
                report.coveragePassed,
                '${report.coveragePct.round()}% (≥ 80%)',
              ),
              if (hasCard)
                _scoreRow(
                  'Colour card ΔE',
                  report.colourErrorDe ?? 0,
                  0,
                  10,
                  5,
                  report.cardPassed,
                  'ΔE ${(report.colourErrorDe ?? 0).toStringAsFixed(1)} (≤ 5)',
                  inverted: true,
                ),
              if (!passed) ...[
                const SizedBox(height: 6),
                for (final r in report.failureReasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 15,
                          color: MirrorColors.dangerFg,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            r,
                            style: const TextStyle(
                              color: MirrorColors.dangerFg,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!canRetake)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      notAssessedHint,
                      style: const TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: passed
                    ? FilledButton.icon(
                        onPressed: onKeep,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'Keep & continue',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    : !canRetake
                    ? FilledButton.tonalIcon(
                        onPressed: onNotAssessed,
                        icon: const Icon(Icons.skip_next_rounded, size: 20),
                        label: Text(
                          notAssessedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    : const FilledButton(
                        onPressed: null,
                        child: Text(
                          'Keep & continue',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: canRetake ? onRetake : null,
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: Text(
                          canRetake
                              ? (passed
                                    ? 'Retake'
                                    : 'Retake ${attempt + 1} of $maxAttempts')
                              : 'No retakes left',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Cancel test'),
                        style: TextButton.styleFrom(
                          foregroundColor: AnaemiaUi.muted,
                        ),
                      ),
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

  Widget _scoreRow(
    String label,
    double value,
    double min,
    double max,
    double threshold,
    bool passed,
    String text, {
    bool inverted = false,
  }) {
    final frac = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final thrFrac = ((threshold - min) / (max - min)).clamp(0.0, 1.0);
    final color = passed ? MirrorColors.successFg : MirrorColors.warningFg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 10,
              child: LayoutBuilder(
                builder: (context, c) => Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AnaemiaUi.outline,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (thrFrac * c.maxWidth - 1).clamp(
                        0.0,
                        c.maxWidth - 2,
                      ),
                      top: -1,
                      bottom: -1,
                      child: Container(
                        width: 2,
                        color: AnaemiaUi.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              text,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            passed ? Icons.check_rounded : Icons.close_rounded,
            size: 14,
            color: color,
          ),
        ],
      ),
    );
  }
}
