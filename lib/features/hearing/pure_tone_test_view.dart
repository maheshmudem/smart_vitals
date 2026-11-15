import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/domain/algorithms/hearing_engines.dart';
import '../../core/domain/entities/hearing_protocol.dart';
import 'hearing_run_controller.dart';

/// S-G10 Test area for Mode A: ear badge, pitch progress, a listening ring
/// that pulses while a tone plays, and the big "I heard it" button.
class PureToneTestView extends StatelessWidget {
  const PureToneTestView({super.key, required this.run, this.ambientDba});

  final HearingRunController run;
  final double? ambientDba;

  @override
  Widget build(BuildContext context) {
    final ear = run.currentEar ?? HearingEar.right;
    final earColor = ear == HearingEar.right
        ? const Color(0xFFEF4444)
        : const Color(0xFF3B82F6);
    final playing = run.tone == ToneState.playing;
    final feedback = run.tone == ToneState.feedback;
    return Column(
      children: [
        const SizedBox(height: 96),
        // ear badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: earColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: earColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: earColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${ear.label.toUpperCase()} EAR',
                style: TextStyle(
                  color: earColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // pitch progress
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < hearingTestOrderHz.length; i++)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < run.freqIndex
                      ? const Color(0xFF0B7A75)
                      : i == run.freqIndex
                      ? Colors.white
                      : Colors.white24,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Pitch ${run.freqIndex + 1} of 4 · ${run.currentHzLabel}',
          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
        if (ambientDba != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: NoiseLevel.passes(ambientDba!)
                  ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                  : const Color(0xFFDC2626).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'room ${ambientDba!.toStringAsFixed(0)} dBA',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
        Expanded(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: playing ? 210 : 150,
                  height: playing ? 210 : 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: earColor.withValues(alpha: playing ? 0.18 : 0.06),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: playing ? 150 : 120,
                  height: playing ? 150 : 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: earColor.withValues(alpha: playing ? 0.8 : 0.3),
                      width: 3,
                    ),
                  ),
                ),
                Icon(
                  feedback
                      ? (run.lastHeard == true
                            ? Icons.check_rounded
                            : Icons.remove_rounded)
                      : Icons.hearing_rounded,
                  size: 52,
                  color: feedback
                      ? (run.lastHeard == true
                            ? const Color(0xFF22C55E)
                            : Colors.white38)
                      : Colors.white70,
                ),
              ],
            ),
          ),
        ),
        // big button
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
          child: SizedBox(
            height: 92,
            child: FilledButton(
              key: const ValueKey('hear_tap'),
              onPressed: run.phase == HearingPhase.running
                  ? () {
                      HapticFeedback.lightImpact();
                      run.onTap();
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B7A75),
                disabledBackgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(46),
                ),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 30),
                    SizedBox(width: 10),
                    Text(
                      'I heard it',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 196),
      ],
    );
  }
}
