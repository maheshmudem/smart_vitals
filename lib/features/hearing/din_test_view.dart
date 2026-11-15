import 'package:flutter/material.dart';

import '../../core/domain/algorithms/hearing_engines.dart';
import 'hearing_run_controller.dart';

/// S-G10 Test area for Mode B: three digit slots, a 0–9 keypad with
/// backspace, and Next.
class DinTestView extends StatelessWidget {
  const DinTestView({super.key, required this.run});

  final HearingRunController run;

  @override
  Widget build(BuildContext context) {
    final active = run.dinAwaitingAnswer && run.phase == HearingPhase.running;
    return Column(
      children: [
        const SizedBox(height: 100),
        Text(
          'Round ${run.dinRound.clamp(1, DigitsInNoise.totalTriplets)} of ${DigitsInNoise.totalTriplets}',
          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 56,
                height: 68,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: i == run.typed.length && active
                        ? const Color(0xFF0B7A75)
                        : Colors.white24,
                    width: 2,
                  ),
                ),
                child: Text(
                  i < run.typed.length ? '${run.typed[i]}' : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          run.dinSpeaking
              ? 'Listen…'
              : active
              ? 'Type the three numbers you heard'
              : ' ',
          style: TextStyle(
            color: run.dinSpeaking ? const Color(0xFFFBBF24) : Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _keypad(active),
        const SizedBox(height: 176),
      ],
    );
  }

  Widget _keypad(bool enabled) {
    Widget key(int d) => SizedBox(
      width: 68,
      height: 52,
      child: FilledButton.tonal(
        key: ValueKey('hear_digit_$d'),
        onPressed: enabled ? () => run.typeDigit(d) : null,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
          disabledForegroundColor: Colors.white30,
        ),
        child: Text(
          '$d',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ]) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in row) ...[
                key(d),
                if (d != row.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 68,
              height: 52,
              child: IconButton.filledTonal(
                key: const ValueKey('hear_backspace'),
                onPressed: enabled && run.typed.isNotEmpty
                    ? run.backspace
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
            const SizedBox(width: 8),
            key(0),
            const SizedBox(width: 8),
            SizedBox(
              width: 68,
              height: 52,
              child: FilledButton(
                key: const ValueKey('hear_din_next'),
                onPressed: enabled && run.typed.length == 3
                    ? run.submitDin
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B7A75),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                  disabledForegroundColor: Colors.white30,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
