import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/algorithms/hearing_engines.dart';
import '../../core/domain/entities/hearing_protocol.dart';

/// Clinical-style audiogram: frequency across (500 Hz → 4 kHz, log-spaced),
/// hearing level down (−10 … 90 dB HL), shaded normal zone below the WHO
/// 20 dB line, right ear red circles, left ear blue crosses, "no response"
/// arrows.
class AudiogramPainter extends CustomPainter {
  const AudiogramPainter({
    required this.right,
    required this.left,
    this.rightNoResponse = const {},
    this.leftNoResponse = const {},
    this.compact = false,
  });

  final Map<int, double> right;
  final Map<int, double> left;
  final Set<int> rightNoResponse;
  final Set<int> leftNoResponse;
  final bool compact;

  static const Color rightColor = Color(0xFFDC2626);
  static const Color leftColor = Color(0xFF2563EB);

  static const double _minDb = -10;
  static const double _maxDb = 90;

  @override
  void paint(Canvas canvas, Size size) {
    final padL = compact ? 26.0 : 34.0;
    final padR = 10.0;
    final padT = compact ? 16.0 : 20.0;
    final padB = compact ? 16.0 : 22.0;
    final plot = Rect.fromLTRB(
      padL,
      padT,
      size.width - padR,
      size.height - padB,
    );
    double x(int hz) {
      final t =
          (math.log(hz) - math.log(500)) / (math.log(4000) - math.log(500));
      return plot.left + plot.width * (0.08 + 0.84 * t);
    }

    double y(double db) =>
        plot.top + plot.height * ((db - _minDb) / (_maxDb - _minDb));

    // normal zone (< 20 dB HL)
    canvas.drawRect(
      Rect.fromLTRB(
        plot.left,
        y(_minDb),
        plot.right,
        y(HearingGrading.whoNormalMaxDbHl),
      ),
      Paint()..color = const Color(0xFF16A34A).withValues(alpha: 0.10),
    );
    final grid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.2;
    for (var db = 0.0; db <= 90; db += 10) {
      canvas.drawLine(
        Offset(plot.left, y(db)),
        Offset(plot.right, y(db)),
        db == 20 ? axis : grid,
      );
      if (!compact || db % 20 == 0) {
        _text(
          canvas,
          db.toStringAsFixed(0),
          Offset(plot.left - 6, y(db)),
          align: TextAlign.right,
          size: compact ? 8 : 9,
        );
      }
    }
    for (final hz in hearingFrequenciesHz) {
      canvas.drawLine(
        Offset(x(hz), plot.top),
        Offset(x(hz), plot.bottom),
        grid,
      );
      _text(
        canvas,
        hz >= 1000 ? '${hz ~/ 1000}k' : '$hz',
        Offset(x(hz), plot.bottom + (compact ? 8 : 10)),
        align: TextAlign.center,
        size: compact ? 8 : 9,
      );
    }
    _text(
      canvas,
      'dB HL',
      Offset(plot.left - 6, plot.top - (compact ? 7 : 9)),
      align: TextAlign.right,
      size: compact ? 7 : 8,
      muted: true,
    );
    canvas.drawRect(
      plot,
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    void series(
      Map<int, double> m,
      Set<int> nr,
      Color color, {
      required bool circle,
    }) {
      final line = Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      Offset? prev;
      for (final hz in hearingFrequenciesHz) {
        final v = m[hz];
        if (v == null) {
          prev = null;
          continue;
        }
        final isNr = nr.contains(hz) || v >= ToneLevel.noResponseDbHl;
        final at = Offset(
          x(hz),
          y(isNr ? ToneLevel.maxDbHl : v.clamp(_minDb, _maxDb)),
        );
        if (prev != null && !isNr) canvas.drawLine(prev, at, line);
        prev = isNr ? null : at;
        final r = compact ? 4.0 : 5.5;
        if (circle) {
          canvas.drawCircle(at, r, Paint()..color = Colors.white);
          canvas.drawCircle(at, r, line);
        } else {
          canvas.drawLine(at + Offset(-r, -r), at + Offset(r, r), line);
          canvas.drawLine(at + Offset(-r, r), at + Offset(r, -r), line);
        }
        if (isNr) {
          // arrow pointing down-outward = no response
          final tip = at + Offset(circle ? -6 : 6, 9);
          canvas.drawLine(at + const Offset(0, 5), tip, line);
          canvas.drawLine(tip, tip + const Offset(0, -4), line);
          canvas.drawLine(tip, tip + Offset(circle ? 4 : -4, 0), line);
        }
      }
    }

    series(left, leftNoResponse, leftColor, circle: false);
    series(right, rightNoResponse, rightColor, circle: true);
  }

  void _text(
    Canvas c,
    String s,
    Offset at, {
    TextAlign align = TextAlign.left,
    double size = 9,
    bool muted = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: muted ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          fontSize: size,
          fontWeight: FontWeight.w700,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => -tp.width,
      TextAlign.center => -tp.width / 2,
      _ => 0.0,
    };
    tp.paint(c, at + Offset(dx, -tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant AudiogramPainter old) =>
      old.right != right || old.left != left || old.compact != compact;
}

/// Legend chips for the audiogram.
class AudiogramLegend extends StatelessWidget {
  const AudiogramLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, bool circle, HearingEar ear) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CustomPaint(painter: _LegendMark(color, circle)),
        ),
        const SizedBox(width: 5),
        Text(
          '${ear.label} ear',
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: 14,
      children: [
        item(AudiogramPainter.rightColor, true, HearingEar.right),
        item(AudiogramPainter.leftColor, false, HearingEar.left),
        const Text(
          'green = normal zone (< 20 dB HL)',
          style: TextStyle(color: Color(0xFF16A34A), fontSize: 11),
        ),
      ],
    );
  }
}

class _LegendMark extends CustomPainter {
  const _LegendMark(this.color, this.circle);
  final Color color;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final c = Offset(size.width / 2, size.height / 2);
    if (circle) {
      canvas.drawCircle(c, 5, p);
    } else {
      canvas.drawLine(c + const Offset(-5, -5), c + const Offset(5, 5), p);
      canvas.drawLine(c + const Offset(-5, 5), c + const Offset(5, -5), p);
    }
  }

  @override
  bool shouldRepaint(covariant _LegendMark old) => old.color != color;
}
