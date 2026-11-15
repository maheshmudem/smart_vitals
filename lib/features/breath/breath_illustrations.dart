import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/entities/breath_protocol.dart';

/// Flat instructional drawings for the Breathing & Voice screens (same
/// style as the Brain & Mind / hearing pictures).
class BreathIllustrationView extends StatelessWidget {
  const BreathIllustrationView({
    super.key,
    required this.kind,
    this.size = 96,
    this.background,
    this.wide = false,
  });

  final BreathIllustration kind;
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
        child: CustomPaint(painter: BreathPainter(kind)),
      ),
    );
  }
}

class BreathPainter extends CustomPainter {
  const BreathPainter(this.kind);

  final BreathIllustration kind;

  static const Color _skin = Color(0xFFF3CDA9);
  static const Color _skinLine = Color(0xFFC98A5B);
  static const Color _ink = Color(0xFF1E293B);
  static const Color _phoneBody = Color(0xFF1F2937);
  static const Color _screen = Color(0xFFFFFFFF);
  static const Color _teal = Color(0xFF0B7A75);
  static const Color _amber = Color(0xFFD97706);
  static const Color _mute = Color(0xFF94A3B8);
  static const Color _hair = Color(0xFF3F2E25);
  static const Color _red = Color(0xFFDC2626);
  static const Color _green = Color(0xFF16A34A);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _shirt = Color(0xFF0E9F94);
  static const Color _pink = Color(0xFFF9A8D4);

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
      case BreathIllustration.phoneAtArm:
        _phoneAtArm(canvas, h);
      case BreathIllustration.coughCircle:
        _coughCircle(canvas, h);
      case BreathIllustration.sayAaa:
        _say(canvas, h, 'aaa', _teal);
      case BreathIllustration.saySss:
        _say(canvas, h, 'sss', _blue);
      case BreathIllustration.sayZzz:
        _say(canvas, h, 'zzz', _amber);
      case BreathIllustration.readSentence:
        _readSentence(canvas, h);
      case BreathIllustration.deepBreaths:
        _deepBreaths(canvas, h);
      case BreathIllustration.blowHard:
        _blowHard(canvas, h);
      case BreathIllustration.micSweep:
        _micSweep(canvas, h);
      case BreathIllustration.quietRoom:
        _quietRoom(canvas, h);
      case BreathIllustration.questionnaire:
        _questionnaire(canvas, h);
      case BreathIllustration.tbSymptoms:
        _tbSymptoms(canvas, h);
      case BreathIllustration.lungs:
        _lungs(canvas, h);
      case BreathIllustration.noSmoke:
        _noSmoke(canvas, h);
      case BreathIllustration.bodyProfile:
        _bodyProfile(canvas, h);
      case BreathIllustration.clinician:
        _clinician(canvas, h);
      case BreathIllustration.micLevel:
        _micLevel(canvas, h);
      case BreathIllustration.xray:
        _xray(canvas, h);
    }
    canvas.restore();
  }

  // ── parts ──────────────────────────────────────────────────────────────

  void _rrect(Canvas c, Rect r, double radius, Paint p) =>
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p);

  void _label(
    Canvas c,
    String text,
    Offset center, {
    double size = 8,
    Color color = _ink,
    FontWeight weight = FontWeight.w800,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _face(
    Canvas c,
    Offset center,
    double r, {
    bool openMouth = false,
    bool puffed = false,
  }) {
    c.drawCircle(center, r, _fill(_skin));
    c.drawCircle(center, r, _stroke(_skinLine, 1.4));
    final hair = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: r),
        math.pi * 1.05,
        math.pi * 0.9,
      )
      ..close();
    c.drawPath(hair, _fill(_hair));
    for (final dx in [-0.33, 0.33]) {
      final at = center + Offset(r * dx, r * 0.05);
      c.drawOval(
        Rect.fromCenter(center: at, width: r * 0.36, height: r * 0.22),
        _fill(Colors.white),
      );
      c.drawCircle(at, r * 0.08, _fill(_ink));
    }
    if (puffed) {
      c.drawOval(
        Rect.fromCenter(
          center: center + Offset(r * 0.1, r * 0.5),
          width: r * 0.5,
          height: r * 0.36,
        ),
        _fill(_pink),
      );
      c.drawCircle(center + Offset(r * 0.55, r * 0.45), r * 0.12, _fill(_ink));
    } else if (openMouth) {
      c.drawOval(
        Rect.fromCenter(
          center: center + Offset(0, r * 0.5),
          width: r * 0.42,
          height: r * 0.38,
        ),
        _fill(_ink),
      );
    } else {
      final mouth = Path()
        ..moveTo(center.dx - r * 0.3, center.dy + r * 0.42)
        ..quadraticBezierTo(
          center.dx,
          center.dy + r * 0.62,
          center.dx + r * 0.3,
          center.dy + r * 0.42,
        );
      c.drawPath(mouth, _stroke(_skinLine, 1.8));
    }
  }

  void _phone(Canvas c, Rect r, {Color screen = _screen}) {
    final radius = math.min(r.width, r.height) * 0.18;
    _rrect(c, r, radius, _fill(_phoneBody));
    final inset = math.min(r.width, r.height) * 0.09;
    _rrect(c, r.deflate(inset), radius * 0.6, _fill(screen));
    c.drawCircle(
      Offset(r.center.dx, r.top + inset * 1.8),
      inset * 0.45,
      _fill(_phoneBody),
    );
  }

  void _waves(
    Canvas c,
    Offset from,
    double dir, {
    Color color = _teal,
    int n = 3,
  }) {
    for (var i = 1; i <= n; i++) {
      c.drawArc(
        Rect.fromCircle(center: from, radius: 5.0 * i + 2),
        dir - 0.55,
        1.1,
        false,
        _stroke(color, 2.0),
      );
    }
  }

  void _mic(Canvas c, Offset at, double h, {Color color = _ink}) {
    _rrect(
      c,
      Rect.fromCenter(center: at, width: h * 0.4, height: h),
      h * 0.2,
      _fill(color),
    );
    c.drawArc(
      Rect.fromCircle(center: at + Offset(0, h * 0.2), radius: h * 0.38),
      0,
      math.pi,
      false,
      _stroke(color, 2),
    );
    c.drawLine(
      at + Offset(0, h * 0.58),
      at + Offset(0, h * 0.8),
      _stroke(color, 2),
    );
  }

  // ── drawings ───────────────────────────────────────────────────────────

  void _phoneAtArm(Canvas c, double h) {
    final cy = h / 2 + 4;
    _face(c, Offset(22, cy - 14), 11, openMouth: true);
    _rrect(c, Rect.fromLTWH(13, cy - 2, 18, 28), 5, _fill(_shirt));
    c.drawLine(Offset(31, cy + 4), Offset(74, cy), _stroke(_skin, 6));
    _phone(c, Rect.fromLTWH(72, cy - 12, 14, 24));
    // distance bracket
    c.drawLine(Offset(34, cy + 20), Offset(72, cy + 20), _stroke(_teal, 1.6));
    c.drawLine(Offset(34, cy + 16), Offset(34, cy + 24), _stroke(_teal, 1.6));
    c.drawLine(Offset(72, cy + 16), Offset(72, cy + 24), _stroke(_teal, 1.6));
    _label(c, '30 cm', Offset(53, cy + 29), size: 8, color: _teal);
    _waves(c, Offset(36, cy - 12), 0, color: _amber, n: 2);
  }

  void _coughCircle(Canvas c, double h) {
    final cy = h / 2;
    c.drawCircle(Offset(50, cy), 30, _fill(_green.withValues(alpha: 0.15)));
    c.drawCircle(Offset(50, cy), 30, _stroke(_green, 3));
    _face(c, Offset(50, cy - 2), 15, openMouth: true);
    _waves(c, Offset(70, cy + 4), 0, color: _amber, n: 2);
    _label(c, 'cough', Offset(50, cy + 24), size: 8, color: _green);
    for (var i = 0; i < 3; i++) {
      final x = 20.0 + i * 10;
      c.drawCircle(Offset(x, h - 9), 3.2, _fill(i < 2 ? _green : _mute));
    }
  }

  void _say(Canvas c, double h, String text, Color color) {
    final cy = h / 2 + 2;
    _face(c, Offset(30, cy), 18, openMouth: true);
    _waves(c, Offset(52, cy + 6), 0, color: color, n: 3);
    _rrect(
      c,
      Rect.fromLTWH(60, cy - 12, 32, 24),
      8,
      _fill(color.withValues(alpha: 0.14)),
    );
    _label(c, text, Offset(76, cy), size: 13, color: color);
    // timer bar
    _rrect(c, Rect.fromLTWH(14, h - 12, 72, 5), 2.5, _fill(_mute));
    _rrect(c, Rect.fromLTWH(14, h - 12, 48, 5), 2.5, _fill(color));
  }

  void _readSentence(Canvas c, double h) {
    final cy = h / 2;
    _phone(
      c,
      Rect.fromCenter(center: Offset(36, cy), width: 38, height: h * 0.84),
    );
    for (var i = 0; i < 4; i++) {
      _rrect(
        c,
        Rect.fromLTWH(24, cy - 16 + i * 8, i == 3 ? 14 : 24, 3.5),
        1.5,
        _fill(i == 0 ? _teal : _ink),
      );
    }
    _face(c, Offset(76, cy + 2), 16, openMouth: true);
    _waves(c, Offset(62, cy + 6), math.pi, color: _amber, n: 2);
  }

  void _deepBreaths(Canvas c, double h) {
    final cy = h / 2 + 4;
    for (var i = 3; i >= 1; i--) {
      c.drawCircle(
        Offset(32, cy),
        7.0 * i + 4,
        _fill(_teal.withValues(alpha: 0.08 * (4 - i))),
      );
    }
    _face(c, Offset(32, cy), 14, openMouth: true);
    // in / out arrows
    c.drawLine(Offset(58, cy - 10), Offset(80, cy - 10), _stroke(_blue, 2.4));
    c.drawPath(
      Path()
        ..moveTo(58, cy - 10)
        ..lineTo(64, cy - 15)
        ..lineTo(64, cy - 5)
        ..close(),
      _fill(_blue),
    );
    c.drawLine(Offset(58, cy + 10), Offset(80, cy + 10), _stroke(_amber, 2.4));
    c.drawPath(
      Path()
        ..moveTo(80, cy + 10)
        ..lineTo(74, cy + 5)
        ..lineTo(74, cy + 15)
        ..close(),
      _fill(_amber),
    );
    _label(c, 'in', Offset(88, cy - 10), size: 7, color: _blue);
    _label(c, 'out', Offset(89, cy + 10), size: 7, color: _amber);
    _label(c, '×4 breaths', Offset(50, h - 8), size: 7.5, color: _teal);
  }

  void _blowHard(Canvas c, double h) {
    final cy = h / 2 + 2;
    _face(c, Offset(28, cy), 17, puffed: true);
    // strong air stream
    for (var i = 0; i < 3; i++) {
      final y = cy + 4 + (i - 1) * 6.0;
      c.drawLine(
        Offset(48, y),
        Offset(66.0 + (i == 1 ? 10 : 0), y),
        _stroke(_amber, 2.6),
      );
    }
    _phone(c, Rect.fromLTWH(80, cy - 13, 14, 26));
    _label(c, 'BLOW!', Offset(50, h - 9), size: 9, color: _red);
  }

  void _micSweep(Canvas c, double h) {
    final cy = h / 2;
    // speaker
    _rrect(c, Rect.fromLTWH(10, cy - 8, 10, 16), 2, _fill(_ink));
    c.drawPath(
      Path()
        ..moveTo(20, cy - 8)
        ..lineTo(30, cy - 16)
        ..lineTo(30, cy + 16)
        ..lineTo(20, cy + 8)
        ..close(),
      _fill(_ink),
    );
    // sweep curve rising
    final p = Path()..moveTo(36, cy + 10);
    for (var x = 36.0; x <= 70; x += 1) {
      final t = (x - 36) / 34;
      final f = 1 + 7 * t * t;
      p.lineTo(x, cy + 10 - 20 * t + 4 * math.sin(f * t * math.pi * 2));
    }
    c.drawPath(p, _stroke(_teal, 2));
    _mic(c, Offset(84, cy - 2), 22);
    _label(c, '100 Hz → 8 kHz', Offset(50, h - 8), size: 7, color: _teal);
  }

  void _quietRoom(Canvas c, double h) {
    final cy = h / 2 + 6;
    final rect = Rect.fromCircle(center: Offset(50, cy + 10), radius: 30);
    c.drawArc(rect, math.pi, math.pi * 0.62, false, _stroke(_green, 7));
    c.drawArc(rect, math.pi * 1.62, math.pi * 0.14, false, _stroke(_amber, 7));
    c.drawArc(rect, math.pi * 1.76, math.pi * 0.24, false, _stroke(_red, 7));
    final a = math.pi * 1.25;
    c.drawLine(
      Offset(50, cy + 10),
      Offset(50, cy + 10) + Offset.fromDirection(a, 24),
      _stroke(_ink, 2.4),
    );
    c.drawCircle(Offset(50, cy + 10), 3, _fill(_ink));
    _label(c, '≤ 45 dBA', Offset(50, cy + 24), size: 8, color: _green);
    final tv = Rect.fromLTWH(10, 10, 20, 14);
    _rrect(c, tv, 2, _stroke(_mute, 1.6));
    c.drawLine(const Offset(12, 8), const Offset(30, 26), _stroke(_red, 2));
  }

  void _questionnaire(Canvas c, double h) {
    final card = Rect.fromLTWH(14, 10, 72, h - 20);
    _rrect(c, card, 6, _fill(Colors.white));
    _rrect(c, card, 6, _stroke(_mute, 1.2));
    _rrect(c, Rect.fromLTWH(20, 16, 60, 5), 2, _fill(_ink));
    _rrect(c, Rect.fromLTWH(20, 24, 44, 4), 2, _fill(_mute));
    for (var i = 0; i < 4; i++) {
      final y = 36.0 + i * (h - 50) / 4;
      _rrect(
        c,
        Rect.fromLTWH(20, y, 60, (h - 50) / 4 - 4),
        4,
        _fill(i == 1 ? _teal.withValues(alpha: 0.15) : const Color(0xFFF1F5F9)),
      );
      c.drawCircle(
        Offset(27, y + ((h - 50) / 4 - 4) / 2),
        3,
        i == 1 ? _fill(_teal) : _stroke(_mute, 1.2),
      );
      _rrect(
        c,
        Rect.fromLTWH(34, y + ((h - 50) / 4 - 4) / 2 - 1.5, 30, 3),
        1.5,
        _fill(i == 1 ? _teal : _mute),
      );
    }
  }

  void _tbSymptoms(Canvas c, double h) {
    final cy = h / 2;
    // thermometer
    _rrect(c, Rect.fromLTWH(14, cy - 22, 7, 34), 3.5, _stroke(_ink, 1.6));
    _rrect(c, Rect.fromLTWH(16, cy - 6, 3, 16), 1.5, _fill(_red));
    c.drawCircle(Offset(17.5, cy + 14), 5, _fill(_red));
    // calendar "2 wk"
    _rrect(c, Rect.fromLTWH(32, cy - 16, 30, 28), 4, _fill(Colors.white));
    _rrect(c, Rect.fromLTWH(32, cy - 16, 30, 28), 4, _stroke(_mute, 1.2));
    _rrect(c, Rect.fromLTWH(32, cy - 16, 30, 7), 3, _fill(_teal));
    _label(c, '2 wk', Offset(47, cy + 2), size: 7.5, color: _ink);
    _label(c, 'cough', Offset(47, cy + 18), size: 6.5, color: _mute);
    // scale (weight)
    _rrect(c, Rect.fromLTWH(70, cy - 2, 22, 12), 3, _fill(_ink));
    c.drawLine(Offset(81, cy - 2), Offset(84, cy - 10), _stroke(_amber, 2));
    _label(c, 'weight', Offset(81, cy + 18), size: 6.5, color: _mute);
    // night sweats moon
    c.drawCircle(Offset(80, cy - 20), 7, _fill(_amber));
    c.drawCircle(Offset(83, cy - 22), 6, _fill(const Color(0xFFF1F5F9)));
  }

  void _lungs(Canvas c, double h) {
    final cy = h / 2 + 2;
    c.drawLine(Offset(50, cy - 26), Offset(50, cy - 6), _stroke(_ink, 3));
    for (final side in [-1, 1]) {
      final cx = 50 + side * 15;
      final lung = Path()
        ..moveTo(50 + side * 3, cy - 8)
        ..quadraticBezierTo(cx + side * 16, cy - 12, cx + side * 14, cy + 10)
        ..quadraticBezierTo(cx + side * 10, cy + 26, cx - side * 2, cy + 22)
        ..quadraticBezierTo(50 + side * 2, cy + 16, 50 + side * 3, cy - 8)
        ..close();
      c.drawPath(lung, _fill(const Color(0xFFFCA5A5)));
      c.drawPath(lung, _stroke(_red, 1.6));
      c.drawLine(
        Offset(50 + side * 3, cy - 6),
        Offset(cx + side * 4, cy + 6),
        _stroke(_red, 1.4),
      );
    }
    _label(c, 'FEV1 · FVC', Offset(50, h - 8), size: 7.5, color: _teal);
  }

  void _noSmoke(Canvas c, double h) {
    final cy = h / 2;
    _rrect(c, Rect.fromLTWH(26, cy - 4, 40, 8), 2, _fill(Colors.white));
    _rrect(c, Rect.fromLTWH(26, cy - 4, 40, 8), 2, _stroke(_ink, 1.4));
    _rrect(c, Rect.fromLTWH(56, cy - 4, 10, 8), 2, _fill(_amber));
    for (var i = 0; i < 3; i++) {
      c.drawArc(
        Rect.fromLTWH(68.0 + i * 3, cy - 18 + i * 4, 8, 10),
        0,
        math.pi,
        false,
        _stroke(_mute, 1.4),
      );
    }
    c.drawCircle(Offset(50, cy), 30, _stroke(_red, 3.5));
    c.drawLine(Offset(29, cy - 21), Offset(71, cy + 21), _stroke(_red, 3.5));
    _label(c, 'no smoke 1 h', Offset(50, h - 7), size: 7, color: _red);
  }

  void _bodyProfile(Canvas c, double h) {
    final cy = h / 2 + 2;
    // ruler
    _rrect(c, Rect.fromLTWH(16, cy - 26, 8, 52), 2, _fill(_amber));
    for (var i = 0; i < 9; i++) {
      c.drawLine(
        Offset(16, cy - 24 + i * 6),
        Offset(i.isEven ? 22 : 19, cy - 24 + i * 6),
        _stroke(_ink, 1),
      );
    }
    // person
    _face(c, Offset(50, cy - 14), 9);
    _rrect(c, Rect.fromLTWH(42, cy - 4, 16, 22), 5, _fill(_shirt));
    _rrect(c, Rect.fromLTWH(43, cy + 18, 6, 10), 2, _fill(_ink));
    _rrect(c, Rect.fromLTWH(51, cy + 18, 6, 10), 2, _fill(_ink));
    _label(c, 'cm · age · sex', Offset(72, cy - 10), size: 6.5, color: _teal);
    _label(c, '% predicted', Offset(72, cy + 2), size: 6.5, color: _mute);
  }

  void _clinician(Canvas c, double h) {
    final cy = h / 2 + 4;
    _face(c, Offset(50, cy - 14), 14);
    _rrect(c, Rect.fromLTWH(32, cy + 2, 36, 26), 8, _fill(Colors.white));
    _rrect(c, Rect.fromLTWH(32, cy + 2, 36, 26), 8, _stroke(_mute, 1.2));
    c.drawArc(
      Rect.fromCircle(center: Offset(44, cy + 10), radius: 7),
      0,
      math.pi,
      false,
      _stroke(_teal, 1.8),
    );
    c.drawLine(Offset(51, cy + 10), Offset(56, cy + 18), _stroke(_teal, 1.8));
    c.drawCircle(Offset(57, cy + 20), 2.5, _fill(_teal));
  }

  void _micLevel(Canvas c, double h) {
    final cy = h / 2;
    _mic(c, Offset(34, cy - 4), 26);
    for (var i = 0; i < 6; i++) {
      final x = 54.0 + i * 7;
      final bh = 6.0 + (i < 4 ? i * 6 : 10 - i * 2);
      _rrect(
        c,
        Rect.fromLTWH(x, cy + 10 - bh, 5, bh),
        2,
        _fill(i < 4 ? _green : _mute),
      );
    }
  }

  void _xray(Canvas c, double h) {
    final cy = h / 2;
    _rrect(
      c,
      Rect.fromLTWH(22, 8, 56, h - 16),
      5,
      _fill(const Color(0xFF0F172A)),
    );
    c.drawLine(
      Offset(50, cy - 22),
      Offset(50, cy + 20),
      _stroke(Colors.white70, 2.2),
    );
    for (var i = 0; i < 5; i++) {
      final y = cy - 16 + i * 8.0;
      c.drawArc(
        Rect.fromCenter(center: Offset(50, y), width: 40, height: 10),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        _stroke(Colors.white54, 1.6),
      );
    }
    // sputum pot
    _rrect(c, Rect.fromLTWH(82, cy - 4, 12, 14), 3, _fill(Colors.white));
    _rrect(c, Rect.fromLTWH(82, cy - 4, 12, 14), 3, _stroke(_mute, 1.2));
    _rrect(c, Rect.fromLTWH(80, cy - 8, 16, 5), 2, _fill(_teal));
    _label(c, 'NAAT + X-ray', Offset(50, h - 5), size: 6.5, color: _teal);
  }

  @override
  bool shouldRepaint(covariant BreathPainter old) => old.kind != kind;
}
