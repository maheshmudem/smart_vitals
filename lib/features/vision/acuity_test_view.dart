import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/domain/algorithms/vision_engines.dart';
import '../../core/services/face_distance_service.dart';
import '../../core/services/screen_metrics_service.dart';
import 'vision_run_controller.dart';

/// S-H07 Test area: a tumbling E at the exact size for the current logMAR
/// level, 40 cm and the screen scale; swipe anywhere or tap an arrow.
/// Pauses (blurs the E) while the distance is outside 35–45 cm (G-33).
class AcuityTestView extends StatefulWidget {
  const AcuityTestView({
    super.key,
    required this.run,
    required this.metrics,
    required this.onCalibrate,
  });

  final VisionRunController run;
  final ScreenMetrics metrics;
  final VoidCallback onCalibrate;

  @override
  State<AcuityTestView> createState() => _AcuityTestViewState();
}

class _AcuityTestViewState extends State<AcuityTestView> {
  Offset? _dragStart;

  void _answer(EDirection? d) => widget.run.answerAcuity(d);

  void _onPanEnd(Offset delta) {
    if (delta.distance < 24) return;
    final dx = delta.dx, dy = delta.dy;
    if (dx.abs() > dy.abs()) {
      _answer(dx > 0 ? EDirection.right : EDirection.left);
    } else {
      _answer(dy > 0 ? EDirection.down : EDirection.up);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.run;
    final level = r.staircase?.level ?? Optotype.startLogMar;
    final distance = r.distanceReading.cm ?? FaceDistance.targetCm;
    // Size the E for the *target* distance so the staircase stays on the
    // document's scale; distance drift pauses the trial instead.
    var heightPx =
        Optotype.heightMm(level, FaceDistance.targetCm) /
        widget.metrics.mmPerLogicalPx;
    final minPx = 5.0; // 1 px stroke floor
    final floored = heightPx < minPx;
    heightPx = math.max(minPx, heightPx);
    final dir = r.currentDirection;
    final paused = r.distancePaused;
    final active = r.phase == VisionPhase.running;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _dragStart = d.localPosition,
      onPanEnd: (d) {
        final s = _dragStart;
        _dragStart = null;
        if (s != null && active) {
          _onPanEnd(
            d.velocity.pixelsPerSecond.distance > 0
                ? d.velocity.pixelsPerSecond
                : Offset.zero,
          );
        }
      },
      onPanUpdate: (d) {
        final s = _dragStart;
        if (s == null || !active) return;
        final delta = d.localPosition - s;
        if (delta.distance >= 60) {
          _dragStart = null;
          _onPanEnd(delta);
        }
      },
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 92),
            _distanceBadge(r),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (dir != null)
                      ImageFiltered(
                        imageFilter: paused
                            ? ImageFilter.blur(sigmaX: 6, sigmaY: 6)
                            : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                        child: CustomPaint(
                          key: ValueKey('vis_e_${dir.name}'),
                          size: Size(heightPx, heightPx),
                          painter: TumblingEPainter(direction: dir),
                        ),
                      )
                    else
                      const SizedBox(width: 60, height: 60),
                    if (paused)
                      Positioned(
                        bottom: -56,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            'Hold phone at 40 cm — ${r.distanceReading.tooClose ? 'move further away' : 'move closer'}',
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Text(
              floored
                  ? 'Smallest size this screen can draw — level ${level.toStringAsFixed(1)}'
                  : 'Level ${level.toStringAsFixed(1)} logMAR · letter ${Optotype.heightMm(level, distance).toStringAsFixed(1)} mm',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
            ),
            const SizedBox(height: 10),
            _arrowPad(active && !paused),
            const SizedBox(height: 6),
            TextButton(
              key: const ValueKey('vis_not_sure'),
              onPressed: active && !paused ? () => _answer(null) : null,
              child: const Text('Not sure'),
            ),
            const SizedBox(height: 196),
          ],
        ),
      ),
    );
  }

  Widget _distanceBadge(VisionRunController r) {
    final d = r.distanceReading;
    final manual = d.mode == DistanceMode.manual;
    final ok = d.inRange;
    final Color bg = manual
        ? const Color(0xFFE2E8F0)
        : ok
        ? const Color(0xFFDCFCE7)
        : d.reliable
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFF1F5F9);
    final Color fg = manual
        ? const Color(0xFF334155)
        : ok
        ? const Color(0xFF166534)
        : d.reliable
        ? const Color(0xFF991B1B)
        : const Color(0xFF64748B);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                manual
                    ? Icons.straighten_rounded
                    : ok
                    ? Icons.check_circle_rounded
                    : Icons.social_distance_rounded,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                r.distanceLine,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              if (d.mode == DistanceMode.estimated) ...[
                const SizedBox(width: 6),
                Text(
                  'est.',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.7),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: widget.onCalibrate,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          child: const Text('Calibrate', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _arrowPad(bool enabled) {
    Widget btn(EDirection d, IconData icon) => SizedBox(
      width: 64,
      height: 56,
      child: FilledButton.tonal(
        key: ValueKey('vis_arrow_${d.name}'),
        onPressed: enabled ? () => _answer(d) : null,
        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
        child: Icon(icon, size: 30),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(EDirection.up, Icons.arrow_upward_rounded),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            btn(EDirection.left, Icons.arrow_back_rounded),
            const SizedBox(width: 70),
            btn(EDirection.right, Icons.arrow_forward_rounded),
          ],
        ),
        const SizedBox(height: 6),
        btn(EDirection.down, Icons.arrow_downward_rounded),
      ],
    );
  }
}

/// Tumbling E on a 5 × 5 grid (stroke = height ÷ 5).
class TumblingEPainter extends CustomPainter {
  const TumblingEPainter({required this.direction, this.color = Colors.black});

  final EDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = math.min(size.width, size.height);
    final u = h / 5;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(switch (direction) {
      EDirection.right => 0,
      EDirection.down => math.pi / 2,
      EDirection.left => math.pi,
      EDirection.up => -math.pi / 2,
    });
    final p = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(-2.5 * u, -2.5 * u, u, 5 * u), p);
    for (final row in [-2.5, -0.5, 1.5]) {
      canvas.drawRect(Rect.fromLTWH(-2.5 * u, row * u, 5 * u, u), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TumblingEPainter old) =>
      old.direction != direction || old.color != color;
}
