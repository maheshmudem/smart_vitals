import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/entities/sleep_protocol.dart';

/// Flat instructional drawings for the sleep screens (same style as the
/// Breathing & Voice / Brain & Mind pictures).
class SleepIllustrationView extends StatelessWidget {
  const SleepIllustrationView({
    super.key,
    required this.kind,
    this.size = 96,
    this.background,
    this.wide = false,
  });

  final SleepIllustration kind;
  final double size;
  final Color? background;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final h = wide ? size * 0.75 : size;
    return ClipRRect(
      borderRadius: BorderRadius.circular(math.min(size, h) * 0.16),
      child: Container(
        width: size,
        height: h,
        color: background ?? const Color(0xFFF1F5F9),
        child: CustomPaint(painter: SleepPainter(kind)),
      ),
    );
  }
}

class SleepPainter extends CustomPainter {
  const SleepPainter(this.kind);

  final SleepIllustration kind;

  static const Color _skin = Color(0xFFF3CDA9);
  static const Color _ink = Color(0xFF1E293B);
  static const Color _phoneBody = Color(0xFF1F2937);
  static const Color _screen = Color(0xFF0B1220);
  static const Color _teal = Color(0xFF0B7A75);
  static const Color _amber = Color(0xFFD97706);
  static const Color _mute = Color(0xFF94A3B8);
  static const Color _hair = Color(0xFF3F2E25);
  static const Color _red = Color(0xFFDC2626);
  static const Color _green = Color(0xFF16A34A);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _wood = Color(0xFFB08968);
  static const Color _woodDark = Color(0xFF8B6B4E);
  static const Color _blanket = Color(0xFF93C5FD);
  static const Color _pillow = Color(0xFFFFFFFF);
  static const Color _night = Color(0xFF0F172A);

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, [double w = 2.4]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s, s);
    final h = size.height / s;
    switch (kind) {
      case SleepIllustration.bedsideTable:
        _bedside(canvas, h, arrow: false);
      case SleepIllustration.distance:
        _bedside(canvas, h, arrow: true);
      case SleepIllustration.charger:
        _charger(canvas, h);
      case SleepIllustration.doNotDisturb:
        _dnd(canvas, h);
      case SleepIllustration.speakerVolume:
        _speaker(canvas, h, crossed: false);
      case SleepIllustration.noEarphones:
        _speaker(canvas, h, crossed: true);
      case SleepIllustration.sonarWaves:
        _sonar(canvas, h);
      case SleepIllustration.nightClock:
        _nightClock(canvas, h);
      case SleepIllustration.longPressStop:
        _longPress(canvas, h);
      case SleepIllustration.report:
        _report(canvas, h);
      case SleepIllustration.ring:
        _ring(canvas, h);
      case SleepIllustration.micSweep:
        _micSweep(canvas, h);
      case SleepIllustration.sleeper:
        _sleeper(canvas, h);
      case SleepIllustration.notification:
        _notification(canvas, h);
    }
    canvas.restore();
  }

  // --- parts -----------------------------------------------------------------

  void _phoneFlat(Canvas c, Offset center, {double w = 22, double hgt = 11}) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: w, height: hgt),
      const Radius.circular(2.5),
    );
    c.drawRRect(r, _fill(_phoneBody));
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: w - 3, height: hgt - 3),
        const Radius.circular(1.5),
      ),
      _fill(_screen),
    );
  }

  void _phoneUpright(Canvas c, Rect rect, {Color screen = _screen}) {
    c.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      _fill(_phoneBody),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2.2), const Radius.circular(3.5)),
      _fill(screen),
    );
  }

  void _bedAndSleeper(Canvas c, double h, {double bedLeft = 34}) {
    // bed
    final bedTop = h * 0.56;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bedLeft, bedTop, 100 - bedLeft, 18),
        const Radius.circular(3),
      ),
      _fill(_blanket),
    );
    c.drawRect(
      Rect.fromLTWH(bedLeft, bedTop + 18, 100 - bedLeft, 6),
      _fill(_woodDark),
    );
    // pillow
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bedLeft + 3, bedTop - 7, 16, 9),
        const Radius.circular(3),
      ),
      _fill(_pillow),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bedLeft + 3, bedTop - 7, 16, 9),
        const Radius.circular(3),
      ),
      _stroke(_mute, 1),
    );
    // head on the pillow
    c.drawCircle(Offset(bedLeft + 11, bedTop - 3), 5.2, _fill(_skin));
    c.drawArc(
      Rect.fromCircle(center: Offset(bedLeft + 11, bedTop - 3), radius: 5.2),
      math.pi * 1.05,
      math.pi * 0.9,
      true,
      _fill(_hair),
    );
    // closed eye
    c.drawLine(
      Offset(bedLeft + 12.5, bedTop - 3.5),
      Offset(bedLeft + 14.5, bedTop - 3.5),
      _stroke(_ink, 0.9),
    );
    // chest bump under the blanket
    final chest = Path()
      ..moveTo(bedLeft + 20, bedTop)
      ..quadraticBezierTo(bedLeft + 30, bedTop - 7, bedLeft + 40, bedTop);
    c.drawPath(chest, _fill(_blanket));
  }

  void _table(Canvas c, double h, {double x = 6, double w = 24}) {
    final top = h * 0.60;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, w, 4),
        const Radius.circular(1.5),
      ),
      _fill(_wood),
    );
    c.drawRect(Rect.fromLTWH(x + 2, top + 4, w - 4, 14), _fill(_woodDark));
    c.drawRect(Rect.fromLTWH(x + 5, top + 7, w - 10, 3), _fill(_wood));
  }

  void _waves(Canvas c, Offset from, Offset to, {Color color = _teal}) {
    for (var i = 1; i <= 3; i++) {
      final r = 5.0 * i;
      final center = from;
      final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
      c.drawArc(
        Rect.fromCircle(center: center, radius: r),
        angle - 0.55,
        1.1,
        false,
        _stroke(color.withValues(alpha: 1 - i * 0.22), 1.8),
      );
    }
  }

  // --- pictures ----------------------------------------------------------------

  void _bedside(Canvas c, double h, {required bool arrow}) {
    _table(c, h);
    _bedAndSleeper(c, h);
    _phoneFlat(c, Offset(18, h * 0.60 - 6));
    _waves(c, Offset(29, h * 0.60 - 7), Offset(60, h * 0.5));
    if (arrow) {
      final y = h * 0.30;
      c.drawLine(Offset(18, y), Offset(64, y), _stroke(_amber, 2));
      c.drawLine(Offset(18, y - 4), Offset(18, y + 4), _stroke(_amber, 2));
      c.drawLine(Offset(64, y - 4), Offset(64, y + 4), _stroke(_amber, 2));
      _label(c, '0.3–1 m', Offset(41, y - 9), _amber, 9);
    }
  }

  void _charger(Canvas c, double h) {
    _table(c, h, x: 20, w: 60);
    _phoneFlat(c, Offset(44, h * 0.60 - 6), w: 26, hgt: 12);
    // cable from the phone to a wall plug
    final cable = Path()
      ..moveTo(57, h * 0.60 - 6)
      ..cubicTo(70, h * 0.60 - 6, 72, h * 0.30, 84, h * 0.30);
    c.drawPath(cable, _stroke(_ink, 2));
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(88, h * 0.30), width: 10, height: 12),
        const Radius.circular(2),
      ),
      _fill(_ink),
    );
    c.drawRect(Rect.fromLTWH(85.5, h * 0.30 - 11, 2, 5), _fill(_ink));
    c.drawRect(Rect.fromLTWH(89, h * 0.30 - 11, 2, 5), _fill(_ink));
    // lightning badge
    final bolt = Path()
      ..moveTo(44, h * 0.60 - 11)
      ..lineTo(41, h * 0.60 - 5)
      ..lineTo(44, h * 0.60 - 5)
      ..lineTo(42, h * 0.60 - 1)
      ..lineTo(47, h * 0.60 - 7)
      ..lineTo(44, h * 0.60 - 7)
      ..close();
    c.drawPath(bolt, _fill(_green));
    _label(c, 'charging all night', Offset(50, h * 0.86), _ink, 8.5);
  }

  void _dnd(Canvas c, double h) {
    _phoneUpright(
      c,
      Rect.fromCenter(center: Offset(50, h / 2), width: 36, height: 64),
    );
    // moon
    c.drawCircle(Offset(50, h / 2 - 6), 10, _fill(const Color(0xFFFBBF24)));
    c.drawCircle(Offset(54, h / 2 - 9), 9, _fill(_screen));
    // crossed bell
    c.drawCircle(Offset(50, h / 2 + 14), 6, _stroke(_mute, 1.6));
    c.drawLine(
      Offset(44, h / 2 + 8),
      Offset(56, h / 2 + 20),
      _stroke(_red, 1.8),
    );
    _label(c, 'Do not disturb', Offset(50, h - 7), _ink, 8.5);
  }

  void _speaker(Canvas c, double h, {required bool crossed}) {
    _phoneUpright(
      c,
      Rect.fromCenter(center: Offset(32, h / 2), width: 30, height: 56),
    );
    // speaker grille at the bottom edge
    for (var i = 0; i < 4; i++) {
      c.drawCircle(Offset(25 + i * 4.5, h / 2 + 25), 1, _fill(_mute));
    }
    _waves(
      c,
      Offset(50, h / 2),
      Offset(90, h / 2),
      color: crossed ? _green : _teal,
    );
    if (crossed) {
      // earphones with a red cross
      c.drawArc(
        Rect.fromCircle(center: Offset(74, h * 0.28), radius: 9),
        math.pi,
        math.pi,
        false,
        _stroke(_ink, 2),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(63, h * 0.28, 4, 7),
          const Radius.circular(1.5),
        ),
        _fill(_ink),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(81, h * 0.28, 4, 7),
          const Radius.circular(1.5),
        ),
        _fill(_ink),
      );
      c.drawLine(
        Offset(62, h * 0.18),
        Offset(86, h * 0.42),
        _stroke(_red, 2.2),
      );
      _label(c, 'no earphones', Offset(74, h * 0.58), _red, 8);
    } else {
      _label(c, 'volume up', Offset(72, h * 0.70), _ink, 8.5);
    }
  }

  void _sonar(Canvas c, double h) {
    c.drawRect(Rect.fromLTWH(0, 0, 100, h), _fill(_night));
    _phoneFlat(c, Offset(16, h * 0.62));
    for (var i = 1; i <= 5; i++) {
      c.drawArc(
        Rect.fromCircle(center: Offset(27, h * 0.60), radius: 7.0 * i),
        -0.5,
        1.0,
        false,
        _stroke(_teal.withValues(alpha: 1 - i * 0.15), 1.6),
      );
    }
    // chest silhouette
    final chest = Path()
      ..moveTo(70, h * 0.78)
      ..quadraticBezierTo(80, h * 0.35, 94, h * 0.70)
      ..lineTo(94, h * 0.78)
      ..close();
    c.drawPath(chest, _fill(_blanket.withValues(alpha: 0.9)));
    _label(c, '18–20 kHz · inaudible', Offset(50, h * 0.14), Colors.white70, 8);
  }

  void _nightClock(Canvas c, double h) {
    c.drawRect(Rect.fromLTWH(0, 0, 100, h), _fill(_night));
    _phoneUpright(
      c,
      Rect.fromCenter(center: Offset(50, h / 2), width: 40, height: 70),
      screen: Colors.black,
    );
    _label(c, '02:14', Offset(50, h / 2 - 8), Colors.white, 12, bold: true);
    c.drawCircle(Offset(44, h / 2 + 6), 1.6, _fill(_green));
    _label(c, 'Monitoring', Offset(53, h / 2 + 6), Colors.white70, 6);
    _label(c, '3 h 20 min', Offset(50, h / 2 + 16), Colors.white54, 6);
  }

  void _longPress(Canvas c, double h) {
    c.drawRect(Rect.fromLTWH(0, 0, 100, h), _fill(_night));
    _phoneUpright(
      c,
      Rect.fromCenter(center: Offset(40, h / 2), width: 40, height: 70),
      screen: Colors.black,
    );
    // stop ring
    c.drawCircle(Offset(40, h / 2 + 12), 11, _stroke(Colors.white24, 2.4));
    c.drawArc(
      Rect.fromCircle(center: Offset(40, h / 2 + 12), radius: 11),
      -math.pi / 2,
      math.pi * 1.3,
      false,
      _stroke(_red, 2.6),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(40, h / 2 + 12), width: 8, height: 8),
        const Radius.circular(1.5),
      ),
      _fill(_red),
    );
    _label(c, '06:40', Offset(40, h / 2 - 14), Colors.white, 10, bold: true);
    // finger
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(60, h / 2 + 8, 9, 26),
        const Radius.circular(4.5),
      ),
      _fill(_skin),
    );
    c.drawCircle(Offset(64.5, h / 2 + 8), 4.5, _fill(_skin));
    _label(c, 'hold 2 s', Offset(78, h / 2 - 2), Colors.white70, 7);
  }

  void _report(Canvas c, double h) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14, 10, 72, h - 20),
        const Radius.circular(5),
      ),
      _fill(Colors.white),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14, 10, 72, h - 20),
        const Radius.circular(5),
      ),
      _stroke(_mute, 1),
    );
    // breathing-rate trace
    final p = Path()..moveTo(20, h * 0.45);
    for (var x = 20.0; x <= 80; x += 4) {
      final y = h * 0.45 + 5 * math.sin(x / 5) - (x > 56 && x < 66 ? 8 : 0);
      p.lineTo(x, y);
    }
    c.drawPath(p, _stroke(_teal, 1.8));
    c.drawRect(
      Rect.fromLTWH(56, h * 0.30, 10, h * 0.30),
      _fill(_red.withValues(alpha: 0.15)),
    );
    _label(c, 'AHI 3.2', Offset(50, h * 0.72), _green, 9, bold: true);
    _label(c, 'normal', Offset(50, h * 0.84), _ink, 7);
  }

  void _ring(Canvas c, double h) {
    c.drawCircle(Offset(50, h / 2), 22, _stroke(_ink, 6));
    c.drawCircle(Offset(50, h / 2), 22, _stroke(_blue, 2));
    _label(c, 'SpO₂', Offset(50, h / 2 - 2), _ink, 9, bold: true);
    _label(c, 'optional · G-32', Offset(50, h - 8), _mute, 7);
  }

  void _micSweep(Canvas c, double h) {
    _phoneUpright(
      c,
      Rect.fromCenter(center: Offset(30, h / 2), width: 28, height: 54),
    );
    final p = Path()..moveTo(48, h / 2);
    for (var x = 48.0; x <= 92; x += 1) {
      final f = 0.2 + (x - 48) / 44 * 1.4;
      p.lineTo(x, h / 2 + 10 * math.sin((x - 48) * f));
    }
    c.drawPath(p, _stroke(_teal, 1.8));
    _label(c, 'sweep', Offset(70, h * 0.82), _ink, 8);
  }

  void _sleeper(Canvas c, double h) {
    _bedAndSleeper(c, h, bedLeft: 14);
    // zzz
    _label(c, 'z', Offset(30, h * 0.22), _blue, 9, bold: true);
    _label(c, 'z', Offset(36, h * 0.14), _blue, 11, bold: true);
    _label(c, 'z', Offset(44, h * 0.06), _blue, 13, bold: true);
    _label(c, '≥ 4 hours', Offset(66, h * 0.20), _ink, 8.5);
  }

  void _notification(Canvas c, double h) {
    _phoneUpright(
      c,
      Rect.fromCenter(center: Offset(50, h / 2), width: 44, height: 72),
      screen: Colors.black,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(31, h / 2 - 28, 38, 14),
        const Radius.circular(3),
      ),
      _fill(Colors.white),
    );
    c.drawCircle(Offset(36, h / 2 - 21), 2.5, _fill(_teal));
    c.drawRect(Rect.fromLTWH(41, h / 2 - 24, 22, 2), _fill(_ink));
    c.drawRect(Rect.fromLTWH(41, h / 2 - 20, 16, 2), _fill(_mute));
    _label(
      c,
      'runs with screen off',
      Offset(50, h / 2 + 22),
      Colors.white70,
      6,
    );
  }

  void _label(
    Canvas c,
    String text,
    Offset center,
    Color color,
    double size, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant SleepPainter old) => old.kind != kind;
}
