import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/algorithms/vision_engines.dart';
import '../../core/services/screen_metrics_service.dart';
import 'vision_run_controller.dart';

/// S-H09 Test area: a 10 × 10 cm Amsler grid (physical size from the screen
/// scale) with a central dot; drag to paint cells that look wavy, blurred
/// or missing.
class AmslerGridView extends StatelessWidget {
  const AmslerGridView({super.key, required this.run, required this.metrics});

  final VisionRunController run;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final active = run.phase == VisionPhase.running;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 92),
          Text(
            'Keep your eye on the dot · phone at 30 cm',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  final wanted = metrics.mmToLogicalPx(100);
                  final side = math.min(
                    wanted,
                    math.min(c.maxWidth - 24, c.maxHeight - 48),
                  );
                  final clipped = side < wanted - 1;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Grid(
                        side: side,
                        marks: run.marks,
                        enabled: active,
                        onCell: (cell, on) => run.markCell(cell, on: on),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        clipped
                            ? '${metrics.logicalPxToMm(side).toStringAsFixed(0)} mm square (screen narrower than 10 cm)'
                            : '10 cm square',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('vis_amsler_normal'),
                onPressed: active
                    ? () => run.amslerDone(declaredNormal: true)
                    : null,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Looks normal'),
              ),
              FilledButton.icon(
                key: const ValueKey('vis_amsler_done'),
                onPressed: active && run.marks.marked.isNotEmpty
                    ? () => run.amslerDone()
                    : null,
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: const Text('Done marking'),
              ),
            ],
          ),
          if (run.marks.marked.isNotEmpty)
            TextButton(
              onPressed: active ? run.clearMarks : null,
              child: const Text('Clear marks'),
            ),
          const SizedBox(height: 170),
        ],
      ),
    );
  }
}

class _Grid extends StatefulWidget {
  const _Grid({
    required this.side,
    required this.marks,
    required this.enabled,
    required this.onCell,
  });

  final double side;
  final AmslerMarks marks;
  final bool enabled;
  final void Function(int cell, bool on) onCell;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  bool _painting = true;

  int? _cellAt(Offset p) {
    final n = widget.marks.cells;
    final step = widget.side / n;
    final col = (p.dx / step).floor();
    final row = (p.dy / step).floor();
    if (col < 0 || row < 0 || col >= n || row >= n) return null;
    return row * n + col;
  }

  void _hit(Offset p, {bool start = false}) {
    if (!widget.enabled) return;
    final c = _cellAt(p);
    if (c == null) return;
    if (start) _painting = !widget.marks.marked.contains(c);
    widget.onCell(c, _painting);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('vis_amsler_grid'),
      onPanStart: (d) => _hit(d.localPosition, start: true),
      onPanUpdate: (d) => _hit(d.localPosition),
      onTapDown: (d) => _hit(d.localPosition, start: true),
      child: SizedBox(
        width: widget.side,
        height: widget.side,
        child: CustomPaint(painter: AmslerPainter(marks: widget.marks)),
      ),
    );
  }
}

/// Amsler grid painter, also used for the small replica on the result.
class AmslerPainter extends CustomPainter {
  const AmslerPainter({required this.marks, this.lineColor = Colors.black});

  final AmslerMarks marks;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final n = marks.cells;
    final step = size.width / n;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final mark = Paint()
      ..color = const Color(0xFFDC2626).withValues(alpha: 0.42);
    for (final c in marks.marked) {
      final row = c ~/ n;
      final col = c % n;
      canvas.drawRect(Rect.fromLTWH(col * step, row * step, step, step), mark);
    }
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = math.max(0.8, size.width / 400);
    for (var i = 0; i <= n; i++) {
      final x = i * step;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      canvas.drawLine(Offset(0, x), Offset(size.width, x), line);
    }
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      math.max(3, size.width * 0.018),
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant AmslerPainter old) => true;
}
