import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/entities/mind_protocol.dart';

/// Flat instructional drawings for the Brain & Mind screens (same style as
/// the hearing / vision pictures), plus the park-scene picture stimulus.
class MindIllustrationView extends StatelessWidget {
  const MindIllustrationView({
    super.key,
    required this.kind,
    this.size = 96,
    this.background,
    this.wide = false,
  });

  final MindIllustration kind;
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
        child: CustomPaint(painter: MindPainter(kind)),
      ),
    );
  }
}

/// The park scene used for the picture-description task (AUD-10 stimulus
/// stand-in [DER]): 12 information units — child, kite, dog, man reading on
/// a bench, woman watering flowers, pond with ducks, ice-cream cart, tree,
/// sun.
class ParkSceneView extends StatelessWidget {
  const ParkSceneView({super.key, this.width = 320});
  final double width;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      width: width,
      height: width * 0.72,
      child: const CustomPaint(
        painter: MindPainter(MindIllustration.parkScene),
      ),
    ),
  );
}

class MindPainter extends CustomPainter {
  const MindPainter(this.kind);

  final MindIllustration kind;

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

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, [double w = 2.4]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (kind == MindIllustration.parkScene) {
      _park(canvas, size);
      return;
    }
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s, s);
    final h = size.height / s;
    switch (kind) {
      case MindIllustration.speakToPhone:
        _speakToPhone(canvas, h);
      case MindIllustration.animals:
        _animals(canvas, h);
      case MindIllustration.quietRoom:
        _quietRoom(canvas, h);
      case MindIllustration.questionnaire:
        _questionnaire(canvas, h);
      case MindIllustration.calmBreath:
        _calm(canvas, h);
      case MindIllustration.readSentence:
        _readSentence(canvas, h);
      case MindIllustration.smileCamera:
        _smileCamera(canvas, h);
      case MindIllustration.armsOutEyesClosed:
        _armOut(canvas, h);
      case MindIllustration.clock:
        _clock(canvas, h);
      case MindIllustration.callEmergency:
        _callEmergency(canvas, h);
      case MindIllustration.supportHands:
        _supportHands(canvas, h);
      case MindIllustration.micLevel:
        _micLevel(canvas, h);
      case MindIllustration.calendar14:
        _calendar(canvas, h);
      case MindIllustration.clinician:
        _clinician(canvas, h);
      case MindIllustration.graduation:
        _graduation(canvas, h);
      case MindIllustration.parkScene:
        break;
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
    bool smile = true,
    bool eyesClosed = false,
    double droopLeft = 0,
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
      if (eyesClosed) {
        c.drawArc(
          Rect.fromCenter(center: at, width: r * 0.34, height: r * 0.2),
          0.2,
          math.pi - 0.4,
          false,
          _stroke(_ink, 1.4),
        );
      } else {
        c.drawOval(
          Rect.fromCenter(center: at, width: r * 0.36, height: r * 0.22),
          _fill(Colors.white),
        );
        c.drawCircle(at, r * 0.08, _fill(_ink));
      }
    }
    final mouth = Path()
      ..moveTo(center.dx - r * 0.3, center.dy + r * 0.42 + droopLeft * r)
      ..quadraticBezierTo(
        center.dx,
        center.dy + r * (smile ? 0.68 : 0.46),
        center.dx + r * 0.3,
        center.dy + r * 0.42,
      );
    c.drawPath(mouth, _stroke(_skinLine, 1.8));
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

  void _speakToPhone(Canvas c, double h) {
    final cy = h / 2 + 2;
    _face(c, Offset(32, cy), 22, smile: false);
    // open mouth + sound
    _waves(c, Offset(58, cy + 6), 0, color: _amber, n: 2);
    _phone(
      c,
      Rect.fromCenter(center: Offset(80, cy), width: 24, height: h * 0.62),
    );
    _mic(c, Offset(80, cy - 4), 12, color: _teal);
  }

  void _animals(Canvas c, double h) {
    // cat, dog, bird silhouettes as simple shapes with labels
    final cy = h / 2;
    // cat
    c.drawCircle(Offset(22, cy), 11, _fill(const Color(0xFFF59E0B)));
    c.drawPath(
      Path()
        ..moveTo(14, cy - 8)
        ..lineTo(16, cy - 18)
        ..lineTo(22, cy - 10)
        ..close(),
      _fill(const Color(0xFFF59E0B)),
    );
    c.drawPath(
      Path()
        ..moveTo(30, cy - 8)
        ..lineTo(28, cy - 18)
        ..lineTo(22, cy - 10)
        ..close(),
      _fill(const Color(0xFFF59E0B)),
    );
    c.drawCircle(Offset(18, cy - 2), 1.6, _fill(_ink));
    c.drawCircle(Offset(26, cy - 2), 1.6, _fill(_ink));
    // dog
    c.drawCircle(Offset(52, cy + 2), 12, _fill(const Color(0xFF92400E)));
    c.drawOval(
      Rect.fromCenter(center: Offset(40, cy + 2), width: 8, height: 16),
      _fill(const Color(0xFF78350F)),
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(64, cy + 2), width: 8, height: 16),
      _fill(const Color(0xFF78350F)),
    );
    c.drawCircle(Offset(48, cy), 1.6, _fill(Colors.white));
    c.drawCircle(Offset(56, cy), 1.6, _fill(Colors.white));
    c.drawCircle(Offset(52, cy + 6), 2.2, _fill(_ink));
    // bird
    c.drawCircle(Offset(82, cy - 6), 8, _fill(_blue));
    c.drawPath(
      Path()
        ..moveTo(90, cy - 6)
        ..lineTo(96, cy - 4)
        ..lineTo(90, cy - 2)
        ..close(),
      _fill(_amber),
    );
    c.drawCircle(Offset(84, cy - 8), 1.4, _fill(Colors.white));
    c.drawLine(Offset(82, cy + 2), Offset(82, cy + 10), _stroke(_amber, 1.6));
    _label(c, '60 s', Offset(50, h - 10), size: 9, color: _teal);
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

  void _calm(Canvas c, double h) {
    final center = Offset(50, h / 2);
    for (var i = 3; i >= 1; i--) {
      c.drawCircle(
        center,
        10.0 * i + 4,
        _fill(_teal.withValues(alpha: 0.08 * (4 - i))),
      );
    }
    _face(c, center, 16, smile: true, eyesClosed: true);
    _label(c, 'breathe', Offset(50, h - 9), size: 7.5, color: _teal);
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
    _face(c, Offset(76, cy + 2), 16, smile: false);
    _waves(c, Offset(62, cy + 6), math.pi, color: _amber, n: 2);
  }

  void _smileCamera(Canvas c, double h) {
    final cy = h / 2;
    _phone(
      c,
      Rect.fromCenter(center: Offset(50, cy), width: 48, height: h * 0.9),
      screen: const Color(0xFF0F172A),
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(50, cy), width: 28, height: 40),
      _stroke(_teal, 1.8),
    );
    _face(c, Offset(50, cy), 12, smile: true);
    _label(c, 'smile', Offset(50, h - 10), size: 7, color: Colors.white);
  }

  void _armOut(Canvas c, double h) {
    final cy = h / 2 + 4;
    // side view: head, body, arm straight out holding the phone
    _face(c, Offset(28, cy - 18), 11, smile: false, eyesClosed: true);
    _rrect(c, Rect.fromLTWH(20, cy - 6, 16, 30), 5, _fill(_shirt));
    c.drawLine(Offset(36, cy), Offset(78, cy - 2), _stroke(_skin, 6));
    _phone(c, Rect.fromLTWH(74, cy - 8, 16, 10));
    // dashed drift arrow
    for (var y = cy + 6; y < cy + 24; y += 5) {
      c.drawLine(Offset(82, y), Offset(82, y + 2.5), _stroke(_red, 1.6));
    }
    c.drawPath(
      Path()
        ..moveTo(78, cy + 26)
        ..lineTo(86, cy + 26)
        ..lineTo(82, cy + 31)
        ..close(),
      _fill(_red),
    );
    _label(c, '10 s', Offset(60, cy + 24), size: 8, color: _teal);
  }

  void _clock(Canvas c, double h) {
    final center = Offset(50, h / 2);
    c.drawCircle(center, 28, _fill(Colors.white));
    c.drawCircle(center, 28, _stroke(_ink, 2.2));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      c.drawLine(
        center + Offset.fromDirection(a, 22),
        center + Offset.fromDirection(a, 25),
        _stroke(_ink, 1.4),
      );
    }
    c.drawLine(
      center,
      center + Offset.fromDirection(-math.pi / 2 + 0.6, 14),
      _stroke(_ink, 2.6),
    );
    c.drawLine(
      center,
      center + Offset.fromDirection(-math.pi / 2 + 2.4, 20),
      _stroke(_red, 2.2),
    );
    c.drawCircle(center, 2.4, _fill(_ink));
    _label(c, 'when?', Offset(50, h - 8), size: 7.5, color: _red);
  }

  void _callEmergency(Canvas c, double h) {
    final r = Rect.fromCenter(center: Offset(50, h / 2), width: 76, height: 34);
    _rrect(c, r, 17, _fill(_red));
    final handset = Path()
      ..moveTo(24, h / 2 - 4)
      ..quadraticBezierTo(30, h / 2 + 8, 38, h / 2 + 4)
      ..lineTo(36, h / 2)
      ..quadraticBezierTo(31, h / 2 + 2, 28, h / 2 - 4)
      ..close();
    c.drawPath(handset, _fill(Colors.white));
    _label(c, '108 / 112', Offset(60, h / 2), size: 9, color: Colors.white);
    _label(c, 'call now', Offset(50, h / 2 + 26), size: 7.5, color: _red);
  }

  void _supportHands(Canvas c, double h) {
    final cy = h / 2 + 6;
    // two hands cupping a heart
    for (final side in [-1, 1]) {
      final cx = 50 + side * 22;
      final p = Path()
        ..moveTo(cx - side * 10, cy + 20)
        ..quadraticBezierTo(cx + side * 16, cy + 22, cx + side * 14, cy)
        ..quadraticBezierTo(cx + side * 4, cy - 8, cx - side * 6, cy + 4)
        ..close();
      c.drawPath(p, _fill(_skin));
      c.drawPath(p, _stroke(_skinLine, 1.4));
    }
    final heart = Path()
      ..moveTo(50, cy + 4)
      ..cubicTo(50, cy - 2, 42, cy - 10, 38, cy - 2)
      ..cubicTo(34, cy + 6, 50, cy + 14, 50, cy + 14)
      ..cubicTo(50, cy + 14, 66, cy + 6, 62, cy - 2)
      ..cubicTo(58, cy - 10, 50, cy - 2, 50, cy + 4)
      ..close();
    c.drawPath(heart, _fill(const Color(0xFFFCA5A5)));
    c.drawPath(heart, _stroke(_red, 1.4));
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

  void _calendar(Canvas c, double h) {
    final r = Rect.fromLTWH(14, 10, 72, h - 20);
    _rrect(c, r, 6, _fill(Colors.white));
    _rrect(c, r, 6, _stroke(_mute, 1.2));
    _rrect(c, Rect.fromLTWH(14, 10, 72, 12), 4, _fill(_teal));
    var n = 1;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 7; col++) {
        if (n > 21) break;
        final x = 19.0 + col * 9.4;
        final y = 28.0 + row * 12;
        final done = n <= 14;
        _rrect(
          c,
          Rect.fromLTWH(x, y, 7.5, 9),
          2,
          _fill(done ? _teal.withValues(alpha: 0.2) : const Color(0xFFF1F5F9)),
        );
        if (done) {
          c.drawLine(
            Offset(x + 1.5, y + 4.5),
            Offset(x + 3.2, y + 6.5),
            _stroke(_teal, 1.1),
          );
          c.drawLine(
            Offset(x + 3.2, y + 6.5),
            Offset(x + 6, y + 2.5),
            _stroke(_teal, 1.1),
          );
        }
        n++;
      }
    }
    _label(c, '14 days', Offset(50, h - 9), size: 7.5, color: _teal);
  }

  void _clinician(Canvas c, double h) {
    final cy = h / 2 + 4;
    _face(c, Offset(50, cy - 14), 14, smile: true);
    _rrect(c, Rect.fromLTWH(32, cy + 2, 36, 26), 8, _fill(Colors.white));
    _rrect(c, Rect.fromLTWH(32, cy + 2, 36, 26), 8, _stroke(_mute, 1.2));
    // stethoscope
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

  void _graduation(Canvas c, double h) {
    final cy = h / 2;
    final cap = Path()
      ..moveTo(50, cy - 16)
      ..lineTo(80, cy - 4)
      ..lineTo(50, cy + 8)
      ..lineTo(20, cy - 4)
      ..close();
    c.drawPath(cap, _fill(_ink));
    _rrect(c, Rect.fromLTWH(36, cy - 2, 28, 10), 3, _fill(_ink));
    c.drawLine(Offset(78, cy - 4), Offset(78, cy + 12), _stroke(_amber, 2));
    c.drawCircle(Offset(78, cy + 14), 2.5, _fill(_amber));
    _label(c, 'years of school', Offset(50, h - 9), size: 7, color: _mute);
  }

  // ── park scene (picture description stimulus) ───────────────────────────

  void _park(Canvas c, Size size) {
    final s = size.width / 200;
    c.save();
    c.scale(s, s);
    final h = size.height / s;
    // sky and grass
    c.drawRect(Rect.fromLTWH(0, 0, 200, h), _fill(const Color(0xFFDDEFFB)));
    c.drawRect(
      Rect.fromLTWH(0, h * 0.55, 200, h * 0.45),
      _fill(const Color(0xFFBBE3A6)),
    );
    // sun
    c.drawCircle(Offset(176, 22), 12, _fill(const Color(0xFFFACC15)));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(
        Offset(176, 22) + Offset.fromDirection(a, 15),
        Offset(176, 22) + Offset.fromDirection(a, 20),
        _stroke(const Color(0xFFF59E0B), 2),
      );
    }
    // tree
    c.drawRect(Rect.fromLTWH(150, h * 0.42, 8, h * 0.2), _fill(_hair));
    c.drawCircle(Offset(154, h * 0.38), 22, _fill(const Color(0xFF15803D)));
    c.drawCircle(Offset(140, h * 0.44), 14, _fill(const Color(0xFF16A34A)));
    c.drawCircle(Offset(168, h * 0.44), 14, _fill(const Color(0xFF16A34A)));
    // pond with ducks
    c.drawOval(
      Rect.fromLTWH(112, h * 0.74, 78, h * 0.2),
      _fill(const Color(0xFF7DD3FC)),
    );
    for (final dx in [128.0, 146.0, 164.0]) {
      final y = h * 0.84;
      c.drawOval(
        Rect.fromCenter(center: Offset(dx, y), width: 12, height: 7),
        _fill(Colors.white),
      );
      c.drawCircle(Offset(dx + 5, y - 4), 3.2, _fill(Colors.white));
      c.drawPath(
        Path()
          ..moveTo(dx + 8, y - 4)
          ..lineTo(dx + 12, y - 3)
          ..lineTo(dx + 8, y - 2)
          ..close(),
        _fill(_amber),
      );
    }
    // bench with man reading
    c.drawRect(
      Rect.fromLTWH(20, h * 0.6, 44, 5),
      _fill(const Color(0xFF92400E)),
    );
    c.drawRect(
      Rect.fromLTWH(20, h * 0.5, 44, 5),
      _fill(const Color(0xFF92400E)),
    );
    c.drawRect(
      Rect.fromLTWH(22, h * 0.6, 3, 12),
      _fill(const Color(0xFF78350F)),
    );
    c.drawRect(
      Rect.fromLTWH(59, h * 0.6, 3, 12),
      _fill(const Color(0xFF78350F)),
    );
    _face(c, Offset(42, h * 0.41), 8, smile: false);
    _rrect(c, Rect.fromLTWH(35, h * 0.47, 14, 16), 4, _fill(_blue));
    _rrect(c, Rect.fromLTWH(30, h * 0.5, 12, 9), 1.5, _fill(Colors.white));
    _rrect(c, Rect.fromLTWH(30, h * 0.5, 12, 9), 1.5, _stroke(_ink, 0.8));
    for (var i = 0; i < 3; i++) {
      c.drawLine(
        Offset(32, h * 0.5 + 2 + i * 2.3),
        Offset(40, h * 0.5 + 2 + i * 2.3),
        _stroke(_mute, 0.7),
      );
    }
    // child with kite
    _face(c, Offset(96, h * 0.56), 6, smile: true);
    _rrect(c, Rect.fromLTWH(91, h * 0.6, 10, 14), 3, _fill(_red));
    c.drawLine(Offset(94, h * 0.74), Offset(92, h * 0.84), _stroke(_skin, 2.2));
    c.drawLine(
      Offset(98, h * 0.74),
      Offset(100, h * 0.84),
      _stroke(_skin, 2.2),
    );
    c.drawLine(
      Offset(101, h * 0.62),
      Offset(118, h * 0.24),
      _stroke(_ink, 0.8),
    );
    final kite = Path()
      ..moveTo(118, h * 0.12)
      ..lineTo(128, h * 0.24)
      ..lineTo(118, h * 0.36)
      ..lineTo(108, h * 0.24)
      ..close();
    c.drawPath(kite, _fill(const Color(0xFFF97316)));
    c.drawPath(kite, _stroke(_ink, 0.8));
    c.drawLine(
      Offset(118, h * 0.36),
      Offset(114, h * 0.44),
      _stroke(_ink, 0.8),
    );
    // dog
    c.drawOval(
      Rect.fromCenter(center: Offset(76, h * 0.8), width: 20, height: 10),
      _fill(const Color(0xFF92400E)),
    );
    c.drawCircle(Offset(86, h * 0.76), 5, _fill(const Color(0xFF92400E)));
    c.drawLine(
      Offset(66, h * 0.78),
      Offset(60, h * 0.72),
      _stroke(const Color(0xFF92400E), 2),
    );
    for (final dx in [70.0, 82.0]) {
      c.drawLine(
        Offset(dx, h * 0.84),
        Offset(dx, h * 0.9),
        _stroke(const Color(0xFF78350F), 2),
      );
    }
    // woman watering flowers
    _face(c, Offset(28, h * 0.72), 7, smile: true);
    _rrect(
      c,
      Rect.fromLTWH(22, h * 0.77, 12, 18),
      4,
      _fill(const Color(0xFF7C3AED)),
    );
    c.drawLine(Offset(34, h * 0.82), Offset(44, h * 0.86), _stroke(_skin, 2.2));
    _rrect(
      c,
      Rect.fromLTWH(42, h * 0.84, 10, 7),
      2,
      _fill(const Color(0xFF0EA5E9)),
    );
    for (var i = 0; i < 3; i++) {
      c.drawLine(
        Offset(52 + i * 1.5, h * 0.86 + i * 2),
        Offset(54 + i * 1.5, h * 0.92 + i),
        _stroke(const Color(0xFF38BDF8), 1),
      );
    }
    for (var i = 0; i < 4; i++) {
      final x = 52.0 + i * 8;
      c.drawLine(
        Offset(x, h * 0.98),
        Offset(x, h * 0.92),
        _stroke(const Color(0xFF15803D), 1.4),
      );
      c.drawCircle(
        Offset(x, h * 0.91),
        3,
        _fill(
          [
            _red,
            const Color(0xFFF472B6),
            const Color(0xFFFACC15),
            const Color(0xFFF97316),
          ][i],
        ),
      );
    }
    // ice cream cart
    _rrect(c, Rect.fromLTWH(150, h * 0.62, 30, 14), 2, _fill(Colors.white));
    _rrect(c, Rect.fromLTWH(150, h * 0.62, 30, 14), 2, _stroke(_ink, 0.8));
    final awning = Path()
      ..moveTo(146, h * 0.62)
      ..lineTo(184, h * 0.62)
      ..lineTo(180, h * 0.56)
      ..lineTo(150, h * 0.56)
      ..close();
    c.drawPath(awning, _fill(_red));
    for (var i = 0; i < 4; i++) {
      c.drawRect(
        Rect.fromLTWH(151 + i * 8.5, h * 0.565, 4, h * 0.05),
        _fill(Colors.white),
      );
    }
    c.drawCircle(Offset(156, h * 0.79), 3, _fill(_ink));
    c.drawCircle(Offset(174, h * 0.79), 3, _fill(_ink));
    c.drawCircle(Offset(165, h * 0.6), 3, _fill(const Color(0xFFF472B6)));
    c.drawPath(
      Path()
        ..moveTo(162, h * 0.6)
        ..lineTo(168, h * 0.6)
        ..lineTo(165, h * 0.66)
        ..close(),
      _fill(_amber),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(covariant MindPainter old) => old.kind != kind;
}
