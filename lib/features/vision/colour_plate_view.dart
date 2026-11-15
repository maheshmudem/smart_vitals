import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/algorithms/vision_engines.dart';
import 'vision_run_controller.dart';

/// S-H08 Test area: one pseudoisochromatic plate at a time with a 1–9
/// keypad and "I see nothing".
class ColourPlateView extends StatelessWidget {
  const ColourPlateView({super.key, required this.run});

  final VisionRunController run;

  @override
  Widget build(BuildContext context) {
    final p = run.currentPlate;
    final active = run.phase == VisionPhase.running && p != null;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 92),
          // progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < run.plateSet.plates.length; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < run.plateIndex
                        ? const Color(0xFF0B7A75)
                        : i == run.plateIndex
                        ? const Color(0xFF0B7A75).withValues(alpha: 0.45)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            active
                ? (run.plateHintDue
                      ? 'No number? Tap "I see nothing"'
                      : 'Which number do you see?')
                : ' ',
            style: TextStyle(
              color: run.plateHintDue
                  ? const Color(0xFF92400E)
                  : const Color(0xFF475569),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  final side = math.max(
                    120.0,
                    math.min(c.maxWidth - 32, c.maxHeight - 4),
                  );
                  return p == null
                      ? const SizedBox.shrink()
                      : RepaintBoundary(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: CustomPaint(
                              key: ValueKey('vis_plate_${p.index}'),
                              painter: ColourPlatePainter(plate: p),
                            ),
                          ),
                        );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          _keypad(active),
          const SizedBox(height: 172),
        ],
      ),
    );
  }

  Widget _keypad(bool enabled) {
    Widget key(int d) => SizedBox(
      width: 64,
      height: 54,
      child: FilledButton.tonal(
        key: ValueKey('vis_digit_$d'),
        onPressed: enabled ? () => run.answerPlate(d) : null,
        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
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
        OutlinedButton(
          key: const ValueKey('vis_digit_none'),
          onPressed: enabled ? () => run.answerPlate(null) : null,
          child: const Text('I see nothing'),
        ),
      ],
    );
  }
}

/// Draws a plate from its cached [PlateDotLayout]: a cream disc and the dot
/// mosaic. Dots inside the numeral use the figure family, the rest the
/// ground family; both share the same lightness levels [DER].
class ColourPlatePainter extends CustomPainter {
  const ColourPlatePainter({required this.plate, this.revealDigit = false});

  final ColourPlate plate;

  /// Result view: draw the numeral outline on top so the answer is visible
  /// to everyone.
  final bool revealDigit;

  static const Color disc = Color(0xFFF4EFE3);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, r, Paint()..color = disc);
    final layout = PlateDotLayout.of(plate, r);
    final paint = Paint();
    for (final d in layout.dots) {
      paint.color = Color(d.argb);
      canvas.drawCircle(center + Offset(d.x, d.y), d.r, paint);
    }
    if (revealDigit) {
      final glyph = DigitGlyph.of(plate.digit);
      const h = 1.05;
      final stroke = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * 0.05)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final s in glyph.strokes) {
        final path = Path();
        for (var i = 0; i < s.length; i++) {
          final x = (s[i].x - DigitGlyph.boxWidth / 2) * h * r + center.dx;
          final y = (s[i].y - 0.5) * h * r + center.dy;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ColourPlatePainter old) =>
      old.plate.seed != plate.seed || old.revealDigit != revealDigit;
}

/// Small plate replica (result "Plate review", intro picture).
class ColourPlateReplica extends StatelessWidget {
  const ColourPlateReplica({
    super.key,
    required this.plate,
    this.size = 60,
    this.revealDigit = false,
  });

  final ColourPlate plate;
  final double size;
  final bool revealDigit;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ColourPlatePainter(plate: plate, revealDigit: revealDigit),
      ),
    ),
  );
}
