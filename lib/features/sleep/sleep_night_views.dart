import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/entities/sleep_protocol.dart';
import 'sleep_illustrations.dart';
import 'sleep_run_controller.dart';

const Color _teal = Color(0xFF0B7A75);
const Color _tealBright = Color(0xFF2DD4BF);

/// Before the night starts: what to do, then Start in the dock.
class SleepReadyView extends StatelessWidget {
  const SleepReadyView({super.key, required this.protocol, required this.run});
  final SleepProtocol protocol;
  final SleepRunController run;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 84, 20, 230),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: SleepIllustrationView(
                kind: SleepIllustration.bedsideTable,
                size: 132,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Ready for the night',
              key: ValueKey('sleep_ready_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              run.phase == SleepPhase.stopped
                  ? run.coaching
                  : 'The screen dims to a clock once monitoring starts',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WHAT TO DO',
                    style: TextStyle(
                      color: _tealBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < protocol.whatToDo.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: _teal,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              protocol.whatToDo[i],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// S-G08 night mode: clock, "Monitoring" pulse, elapsed, valid hours ring,
/// status chips, optional live breathing strip.
class SleepNightClockView extends StatelessWidget {
  const SleepNightClockView({
    super.key,
    required this.run,
    required this.showLive,
    required this.keepAlive,
  });

  final SleepRunController run;
  final bool showLive;
  final bool keepAlive;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final el = run.elapsedS.round();
    final elapsed = '${el ~/ 3600} h ${(el % 3600) ~/ 60} min';
    final paused = run.phase == SleepPhase.paused;
    final interrupted = run.phase == SleepPhase.interrupted;
    final dotColor = paused
        ? const Color(0xFFF59E0B)
        : interrupted
        ? const Color(0xFFEF4444)
        : const Color(0xFF22C55E);
    final pulseOn = el % 2 == 0;
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 3),
          Text(
            clock,
            key: const ValueKey('sleep_clock'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 72,
              fontWeight: FontWeight.w200,
              height: 1,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: pulseOn ? 1 : 0.35,
                duration: const Duration(milliseconds: 600),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  paused
                      ? 'Paused — charger disconnected'
                      : interrupted
                      ? 'Interrupted — restarting'
                      : 'Monitoring',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  key: const ValueKey('sleep_state_label'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            elapsed,
            key: const ValueKey('sleep_elapsed'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: run.validProgress,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: run.enoughForAhi ? _tealBright : _teal,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      run.validSleepH.toStringAsFixed(1),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    Text(
                      'h valid',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            run.enoughForAhi
                ? 'Enough for the apnoea estimate'
                : '4 h needed for the apnoea estimate',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _chip(
                run.charging ? Icons.bolt_rounded : Icons.power_off_rounded,
                run.charging
                    ? 'Charging${run.batteryPct >= 0 ? ' ${run.batteryPct} %' : ''}'
                    : 'Unplugged!',
                run.charging
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFF59E0B),
                key: const ValueKey('sleep_chip_charger'),
              ),
              _chip(
                run.echoOk
                    ? Icons.wifi_tethering_rounded
                    : Icons.wifi_tethering_off_rounded,
                run.echoOk ? 'Echo OK' : 'Echo lost',
                run.echoOk ? _tealBright : const Color(0xFFF59E0B),
                key: const ValueKey('sleep_chip_echo'),
              ),
              _chip(
                keepAlive
                    ? Icons.notifications_active_rounded
                    : Icons.screen_lock_portrait_rounded,
                keepAlive ? 'Runs with screen off' : 'Keep the screen on',
                Colors.white54,
              ),
            ],
          ),
          if (showLive) ...[const SizedBox(height: 18), _liveStrip()],
          const Spacer(flex: 4),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color, {Key? key}) =>
      Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _liveStrip() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Breathing rate · last hour',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            Text(
              run.liveRr == null
                  ? '— br/min'
                  : '${run.liveRr!.toStringAsFixed(0)} br/min',
              key: const ValueKey('sleep_live_rr'),
              style: const TextStyle(
                color: _tealBright,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: CustomPaint(
            size: const Size(double.infinity, 44),
            painter: RrStripPainter(run.recentRr),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${run.apnoeas} apnoea · ${run.hypopnoeas} hypopnoea so far',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

/// Breathing-rate strip (null = invalid epoch, drawn as a gap).
class RrStripPainter extends CustomPainter {
  const RrStripPainter(this.rr, {this.color = _tealBright});
  final List<double?> rr;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      base,
    );
    if (rr.isEmpty) return;
    final n = math.max(rr.length, 2);
    final dx = size.width / (n - 1);
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Path? path;
    for (var i = 0; i < rr.length; i++) {
      final v = rr[i];
      if (v == null) {
        if (path != null) canvas.drawPath(path, line);
        path = null;
        canvas.drawRect(
          Rect.fromLTWH(i * dx, 0, dx, size.height),
          Paint()..color = Colors.white.withValues(alpha: 0.05),
        );
        continue;
      }
      final y =
          size.height - ((v - 6) / 30).clamp(0.0, 1.0) * (size.height - 4) - 2;
      if (path == null) {
        path = Path()..moveTo(i * dx, y);
      } else {
        path.lineTo(i * dx, y);
      }
    }
    if (path != null) canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant RrStripPainter old) => old.rr != rr;
}

/// Long-press Stop with a filling ring (Doc 05 S-G08: long-press to avoid
/// accidental taps).
class SleepStopButton extends StatelessWidget {
  const SleepStopButton({
    super.key,
    required this.progress,
    required this.onHoldStart,
    required this.onHoldCancel,
  });

  final double progress;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('sleep_stop'),
      onLongPressStart: (_) => onHoldStart(),
      onLongPressEnd: (_) => onHoldCancel(),
      onLongPressCancel: onHoldCancel,
      onTapUp: (_) => onHoldCancel(),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.6),
          ),
        ),
        child: Stack(
          children: [
            if (progress > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                  ),
                ),
              ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop_circle_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      progress > 0 ? 'Keep holding…' : 'Hold to stop (2 s)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
