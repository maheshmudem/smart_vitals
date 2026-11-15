import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/entities/hearing_protocol.dart';

/// Flat instructional drawings for the hearing screen, in the same style as
/// the movement and vision pictures: one painter, one `switch` per kind,
/// logical 100-unit width scaled uniformly ([wide] = 4:3).
class HearingIllustrationView extends StatelessWidget {
  const HearingIllustrationView({
    super.key,
    required this.kind,
    this.size = 96,
    this.background,
    this.wide = false,
  });

  final HearingIllustration kind;
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
        child: CustomPaint(painter: _HearingPainter(kind)),
      ),
    );
  }
}

class _HearingPainter extends CustomPainter {
  const _HearingPainter(this.kind);

  final HearingIllustration kind;

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
  static const Color _blue = Color(0xFF2563EB);
  static const Color _green = Color(0xFF16A34A);

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
      case HearingIllustration.earphonesIn:
      case HearingIllustration.bothEars:
        _earphones(canvas, h);
      case HearingIllustration.volumeMax:
        _volume(canvas, h);
      case HearingIllustration.quietRoom:
        _quietRoom(canvas, h);
      case HearingIllustration.tapWhenBeep:
        _tapWhenBeep(canvas, h);
      case HearingIllustration.earLeft:
        _earBadge(canvas, h, left: true);
      case HearingIllustration.earRight:
        _earBadge(canvas, h, left: false);
      case HearingIllustration.digitsKeypad:
        _keypad(canvas, h);
      case HearingIllustration.noiseWaves:
        _noiseWaves(canvas, h);
      case HearingIllustration.phoneOnTable:
        _phoneOnTable(canvas, h);
      case HearingIllustration.earphoneUnplugged:
        _unplugged(canvas, h);
      case HearingIllustration.micCheck:
        _micCheck(canvas, h);
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
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _face(Canvas c, Offset center, double r) {
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
    c.drawArc(
      Rect.fromCenter(
        center: center + Offset(0, r * 0.45),
        width: r * 0.5,
        height: r * 0.3,
      ),
      0.2,
      math.pi - 0.4,
      false,
      _stroke(_skinLine, 1.6),
    );
  }

  /// Ears on both sides of a face of radius [r].
  void _ears(
    Canvas c,
    Offset center,
    double r, {
    Color? highlight,
    bool? left,
  }) {
    for (final side in [-1, 1]) {
      final at = center + Offset(side * r * 1.0, r * 0.05);
      final isLeftEar = side == 1; // viewer's right = member's left
      final hl = highlight != null && left == isLeftEar;
      c.drawOval(
        Rect.fromCenter(center: at, width: r * 0.42, height: r * 0.62),
        _fill(hl ? highlight : _skin),
      );
      c.drawOval(
        Rect.fromCenter(center: at, width: r * 0.42, height: r * 0.62),
        _stroke(hl ? highlight : _skinLine, 1.4),
      );
    }
  }

  void _earbud(Canvas c, Offset at, Color color, {bool cord = true}) {
    c.drawCircle(at, 4.2, _fill(color));
    c.drawCircle(at, 4.2, _stroke(_ink, 1.2));
    if (cord) {
      final p = Path()
        ..moveTo(at.dx, at.dy + 4)
        ..quadraticBezierTo(at.dx + 2, at.dy + 16, at.dx - 1, at.dy + 28);
      c.drawPath(p, _stroke(_ink, 1.3));
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

  void _finger(Canvas c, Rect r) {
    _rrect(c, r, r.width / 2, _fill(_skin));
    _rrect(c, r, r.width / 2, _stroke(_skinLine, 1.2));
  }

  // ── drawings ───────────────────────────────────────────────────────────

  void _earphones(Canvas c, double h) {
    final center = Offset(50, h / 2 + 3);
    const r = 26.0;
    _ears(c, center, r);
    _face(c, center, r);
    // earbuds: member's right ear is on the viewer's left
    _earbud(c, center + const Offset(-r * 1.0, r * 0.05), _red);
    _earbud(c, center + const Offset(r * 1.0, r * 0.05), _blue);
    _label(
      c,
      'R',
      Offset(center.dx - r * 1.0, center.dy - r * 0.6),
      size: 8,
      color: _red,
    );
    _label(
      c,
      'L',
      Offset(center.dx + r * 1.0, center.dy - r * 0.6),
      size: 8,
      color: _blue,
    );
  }

  void _volume(Canvas c, double h) {
    final cy = h / 2;
    _phone(
      c,
      Rect.fromCenter(center: Offset(38, cy), width: 34, height: h * 0.8),
    );
    // vertical volume bar, full
    _rrect(
      c,
      Rect.fromLTWH(34, cy - 22, 8, 44),
      4,
      _fill(const Color(0xFFE2E8F0)),
    );
    _rrect(c, Rect.fromLTWH(34, cy - 22, 8, 44), 4, _fill(_teal));
    // speaker
    final sp = Path()
      ..moveTo(60, cy - 5)
      ..lineTo(66, cy - 5)
      ..lineTo(74, cy - 12)
      ..lineTo(74, cy + 12)
      ..lineTo(66, cy + 5)
      ..lineTo(60, cy + 5)
      ..close();
    c.drawPath(sp, _fill(_ink));
    _waves(c, Offset(76, cy), 0);
    _label(c, 'MAX', Offset(74, cy + 24), size: 8, color: _teal);
  }

  void _quietRoom(Canvas c, double h) {
    final cy = h / 2 + 6;
    // gauge arc
    final rect = Rect.fromCircle(center: Offset(50, cy + 10), radius: 30);
    c.drawArc(rect, math.pi, math.pi * 0.62, false, _stroke(_green, 7));
    c.drawArc(rect, math.pi * 1.62, math.pi * 0.14, false, _stroke(_amber, 7));
    c.drawArc(rect, math.pi * 1.76, math.pi * 0.24, false, _stroke(_red, 7));
    // needle in the green zone
    final a = math.pi * 1.25;
    c.drawLine(
      Offset(50, cy + 10),
      Offset(50, cy + 10) + Offset.fromDirection(a, 24),
      _stroke(_ink, 2.4),
    );
    c.drawCircle(Offset(50, cy + 10), 3, _fill(_ink));
    _label(c, '≤ 45 dBA', Offset(50, cy + 24), size: 8, color: _green);
    // muted TV top-left
    final tv = Rect.fromLTWH(10, 10, 20, 14);
    _rrect(c, tv, 2, _stroke(_mute, 1.6));
    c.drawLine(const Offset(12, 8), const Offset(30, 26), _stroke(_red, 2));
    // muted speaker top-right
    final sp = Path()
      ..moveTo(74, 12)
      ..lineTo(78, 12)
      ..lineTo(84, 7)
      ..lineTo(84, 23)
      ..lineTo(78, 18)
      ..lineTo(74, 18)
      ..close();
    c.drawPath(sp, _fill(_mute));
    c.drawLine(const Offset(72, 6), const Offset(90, 24), _stroke(_red, 2));
  }

  void _tapWhenBeep(Canvas c, double h) {
    final cy = h / 2;
    final phone = Rect.fromCenter(
      center: Offset(42, cy),
      width: 44,
      height: h * 0.86,
    );
    _phone(c, phone, screen: const Color(0xFF0F172A));
    c.drawCircle(Offset(42, cy + 8), 12, _fill(_teal));
    _label(c, 'TAP', Offset(42, cy + 8), size: 6.5, color: Colors.white);
    _finger(c, Rect.fromLTWH(46, cy + 12, 9, 30));
    // beep waves from an earbud top-right
    _earbud(c, const Offset(80, 22), _red, cord: false);
    _waves(c, const Offset(80, 22), math.pi * 0.5, color: _amber, n: 2);
    _label(c, 'beep', Offset(80, h - 14), size: 7, color: _amber);
  }

  void _earBadge(Canvas c, double h, {required bool left}) {
    final center = Offset(50, h / 2 + 3);
    const r = 26.0;
    _ears(c, center, r, highlight: left ? _blue : _red, left: left);
    _face(c, center, r);
    final earX = center.dx + (left ? r : -r);
    _earbud(
      c,
      Offset(earX, center.dy + r * 0.05),
      left ? _blue : _red,
      cord: false,
    );
    _waves(
      c,
      Offset(earX + (left ? 6 : -6), center.dy),
      left ? 0 : math.pi,
      color: left ? _blue : _red,
      n: 2,
    );
    final badge = Offset(left ? 82 : 18, h * 0.18);
    c.drawCircle(badge, 9, _fill(left ? _blue : _red));
    _label(c, left ? 'L' : 'R', badge, size: 10, color: Colors.white);
  }

  void _keypad(Canvas c, double h) {
    final cy = h / 2;
    final phone = Rect.fromCenter(
      center: Offset(50, cy),
      width: 46,
      height: h * 0.9,
    );
    _phone(c, phone);
    // three slots
    for (var i = 0; i < 3; i++) {
      final x = 36.0 + i * 14;
      _rrect(c, Rect.fromLTWH(x - 5, cy - 24, 10, 12), 2, _stroke(_teal, 1.4));
      _label(c, ['4', '9', '1'][i], Offset(x, cy - 18), size: 7, color: _teal);
    }
    // keypad 3 x 3
    var n = 1;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final x = 36.0 + col * 14, y = cy - 4 + row * 11;
        _rrect(
          c,
          Rect.fromLTWH(x - 5, y - 4, 10, 8),
          2,
          _fill(const Color(0xFFE2E8F0)),
        );
        _label(c, '$n', Offset(x, y), size: 5.5, color: _ink);
        n++;
      }
    }
  }

  void _noiseWaves(Canvas c, double h) {
    final cy = h / 2;
    // rushing noise: wavy lines
    for (var i = 0; i < 5; i++) {
      final y = cy - 20 + i * 10;
      final p = Path()..moveTo(8, y);
      for (var x = 8.0; x <= 92; x += 6) {
        p.lineTo(x + 3, ((x / 6).floor() + i).isEven ? y - 3 : y + 3);
      }
      c.drawPath(p, _stroke(_mute, 1.4));
    }
    // digits in the middle
    _rrect(
      c,
      Rect.fromCenter(center: Offset(50, cy), width: 48, height: 20),
      6,
      _fill(Colors.white.withValues(alpha: 0.9)),
    );
    _label(c, '4 – 9 – 1', Offset(50, cy), size: 10, color: _teal);
    _earbud(c, const Offset(14, 14), _red, cord: false);
    _waves(c, const Offset(14, 14), math.pi * 0.25, color: _amber, n: 2);
  }

  void _phoneOnTable(Canvas c, double h) {
    final ty = h * 0.72;
    c.drawLine(Offset(6, ty), Offset(94, ty), _stroke(_hair, 3));
    _phone(c, Rect.fromLTWH(30, ty - 16, 40, 14), screen: _screen);
    // person head to the right, mouth closed, finger on lips
    final center = Offset(76, ty - 36);
    _face(c, center, 16);
    _finger(c, Rect.fromLTWH(74, center.dy + 2, 5, 16));
    _label(c, 'no talking', Offset(50, h * 0.18), size: 7.5, color: _mute);
  }

  void _unplugged(Canvas c, double h) {
    final cy = h / 2;
    _phone(
      c,
      Rect.fromCenter(center: Offset(34, cy), width: 32, height: h * 0.78),
    );
    // plug falling away from the phone
    final plug = Rect.fromLTWH(58, cy - 4, 14, 8);
    _rrect(c, plug, 3, _fill(_ink));
    c.drawLine(Offset(72, cy), Offset(90, cy + 10), _stroke(_ink, 1.6));
    _earbud(c, Offset(90, cy + 14), _red, cord: false);
    // warning triangle
    final tri = Path()
      ..moveTo(76, 8)
      ..lineTo(92, 32)
      ..lineTo(60, 32)
      ..close();
    c.drawPath(tri, _fill(_amber));
    _label(c, '!', const Offset(76, 24), size: 11, color: Colors.white);
  }

  void _micCheck(Canvas c, double h) {
    final cy = h / 2;
    _rrect(
      c,
      Rect.fromCenter(center: Offset(36, cy - 6), width: 16, height: 30),
      8,
      _fill(_ink),
    );
    c.drawArc(
      Rect.fromCircle(center: Offset(36, cy + 2), radius: 13),
      0,
      math.pi,
      false,
      _stroke(_ink, 2.2),
    );
    c.drawLine(Offset(36, cy + 15), Offset(36, cy + 24), _stroke(_ink, 2.2));
    for (var i = 0; i < 5; i++) {
      final x = 58.0 + i * 8;
      final bh = 6.0 + i * 5;
      _rrect(
        c,
        Rect.fromLTWH(x, cy + 10 - bh, 5, bh),
        2,
        _fill(i < 3 ? _green : _mute),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HearingPainter old) => old.kind != kind;
}
