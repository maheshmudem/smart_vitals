import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/algorithms/vision_engines.dart';
import '../../core/domain/entities/vision_protocol.dart';

/// Flat instructional drawings for the vision tests, in the same style as
/// the movement pictures: one painter, one `switch` per kind, logical
/// 100-unit width scaled uniformly ([wide] = 4:3).
class VisionIllustrationView extends StatelessWidget {
  const VisionIllustrationView({
    super.key,
    required this.kind,
    this.size = 96,
    this.background,
    this.wide = false,
  });

  final VisionIllustration kind;
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
        child: CustomPaint(painter: _VisionPainter(kind)),
      ),
    );
  }
}

class _VisionPainter extends CustomPainter {
  const _VisionPainter(this.kind);

  final VisionIllustration kind;

  static const Color _skin = Color(0xFFF3CDA9);
  static const Color _skinLine = Color(0xFFC98A5B);
  static const Color _ink = Color(0xFF1E293B);
  static const Color _shirt = Color(0xFF0E9F94);
  static const Color _phoneBody = Color(0xFF1F2937);
  static const Color _screen = Color(0xFFFFFFFF);
  static const Color _teal = Color(0xFF0B7A75);

  static const Color _amber = Color(0xFFD97706);
  static const Color _mute = Color(0xFF94A3B8);
  static const Color _hair = Color(0xFF3F2E25);
  static const Color _red = Color(0xFFDC2626);

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
      case VisionIllustration.coverEye:
        _coverEye(canvas, h);
      case VisionIllustration.phoneAt40cm:
        _phoneAtDistance(canvas, h, '40 cm');
      case VisionIllustration.phoneAt30cm:
        _phoneAtDistance(canvas, h, '30 cm');
      case VisionIllustration.tumblingE:
        _tumblingE(canvas, h);
      case VisionIllustration.swipeArrows:
        _swipeArrows(canvas, h);
      case VisionIllustration.glassesOn:
        _glasses(canvas, h, reading: false);
      case VisionIllustration.readingGlasses:
        _glasses(canvas, h, reading: true);
      case VisionIllustration.colourPlate:
        _colourPlate(canvas, h);
      case VisionIllustration.brightnessMax:
        _brightness(canvas, h);
      case VisionIllustration.noFilter:
        _noFilter(canvas, h);
      case VisionIllustration.amslerGrid:
        _amsler(canvas, h, marked: false);
      case VisionIllustration.markWavy:
        _amsler(canvas, h, marked: true);
      case VisionIllustration.tapFlash:
        _tapFlash(canvas, h);
      case VisionIllustration.speaker:
        _speaker(canvas, h);
      case VisionIllustration.waitThenTap:
        _waitThenTap(canvas, h);
      case VisionIllustration.tapeMeasure:
        _tape(canvas, h);
      case VisionIllustration.eyeLeft:
        _eyeBadge(canvas, h, left: true);
      case VisionIllustration.eyeRight:
        _eyeBadge(canvas, h, left: false);
    }
    canvas.restore();
  }

  // ── parts ──────────────────────────────────────────────────────────────

  void _rrect(Canvas c, Rect r, double radius, Paint p) =>
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p);

  void _face(Canvas c, Offset center, double r, {bool coverLeft = false}) {
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
    _eye(c, center + Offset(-r * 0.33, r * 0.05), r * 0.17);
    _eye(c, center + Offset(r * 0.33, r * 0.05), r * 0.17);
    // mouth
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
    if (coverLeft) {
      // palm over the viewer's right (member's left) eye
      final palm = Rect.fromCenter(
        center: center + Offset(r * 0.36, r * 0.1),
        width: r * 0.9,
        height: r * 1.0,
      );
      _rrect(c, palm, r * 0.2, _fill(_skin));
      _rrect(c, palm, r * 0.2, _stroke(_skinLine, 1.4));
      for (var i = 0; i < 4; i++) {
        final x = palm.left + palm.width * (0.15 + i * 0.23);
        _rrect(
          c,
          Rect.fromLTWH(x - r * 0.09, palm.top - r * 0.45, r * 0.18, r * 0.55),
          r * 0.09,
          _fill(_skin),
        );
        _rrect(
          c,
          Rect.fromLTWH(x - r * 0.09, palm.top - r * 0.45, r * 0.18, r * 0.55),
          r * 0.09,
          _stroke(_skinLine, 1.2),
        );
      }
    }
  }

  void _eye(Canvas c, Offset at, double r) {
    c.drawOval(
      Rect.fromCenter(center: at, width: r * 2.2, height: r * 1.3),
      _fill(Colors.white),
    );
    c.drawOval(
      Rect.fromCenter(center: at, width: r * 2.2, height: r * 1.3),
      _stroke(_ink, 1.2),
    );
    c.drawCircle(at, r * 0.55, _fill(const Color(0xFF3B5B8C)));
    c.drawCircle(at, r * 0.25, _fill(_ink));
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

  void _arrow(
    Canvas c,
    Offset a,
    Offset b, {
    Color color = _teal,
    double width = 2.6,
    bool both = false,
    double head = 5,
  }) {
    final p = _stroke(color, width);
    c.drawLine(a, b, p);
    _head(c, b, (b - a).direction, head, p);
    if (both) _head(c, a, (a - b).direction, head, p);
  }

  void _head(Canvas c, Offset tip, double dir, double len, Paint p) {
    c.drawLine(tip, tip + Offset.fromDirection(dir + math.pi * 0.8, len), p);
    c.drawLine(tip, tip + Offset.fromDirection(dir - math.pi * 0.8, len), p);
  }

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

  /// Tumbling E: 5 × 5 grid, stroke = 1/5 of the height, pointing [dir].
  void _drawE(Canvas c, Offset center, double height, EDir dir, Color color) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(switch (dir) {
      EDir.right => 0,
      EDir.down => math.pi / 2,
      EDir.left => math.pi,
      EDir.up => -math.pi / 2,
    });
    final u = height / 5;
    final p = _fill(color);
    c.drawRect(Rect.fromLTWH(-2.5 * u, -2.5 * u, u, 5 * u), p); // spine
    for (final row in [-2.5, -0.5, 1.5]) {
      c.drawRect(Rect.fromLTWH(-2.5 * u, row * u, 5 * u, u), p);
    }
    c.restore();
  }

  // ── drawings ───────────────────────────────────────────────────────────

  void _coverEye(Canvas c, double h) {
    _face(c, Offset(50, h / 2 + 2), 30, coverLeft: true);
  }

  void _phoneAtDistance(Canvas c, double h, String label) {
    final cy = h / 2;
    // side-view head at left, phone at right, dimension line between
    c.drawCircle(Offset(18, cy - 10), 11, _fill(_skin));
    c.drawCircle(Offset(18, cy - 10), 11, _stroke(_skinLine, 1.4));
    final hair = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(18, cy - 10), radius: 11),
        math.pi * 1.1,
        math.pi * 0.8,
      )
      ..close();
    c.drawPath(hair, _fill(_hair));
    _eye(c, Offset(25, cy - 11), 2.2);
    _rrect(c, Rect.fromLTWH(8, cy + 1, 20, 18), 5, _fill(_shirt));
    // arm straight out holding the phone
    _rrect(c, Rect.fromLTWH(24, cy + 2, 46, 6), 3, _fill(_skin));
    _rrect(c, Rect.fromLTWH(24, cy + 2, 46, 6), 3, _stroke(_skinLine, 1.2));
    _phone(c, Rect.fromLTWH(70, cy - 16, 12, 24));
    _arrow(
      c,
      Offset(30, cy - 24),
      Offset(72, cy - 24),
      both: true,
      color: _mute,
      width: 1.8,
    );
    c.drawRect(
      Rect.fromCenter(center: Offset(51, cy - 24), width: 22, height: 9),
      _fill(const Color(0xFFF1F5F9)),
    );
    _label(c, label, Offset(51, cy - 24), size: 7.5);
  }

  void _tumblingE(Canvas c, double h) {
    final cy = h / 2;
    _phone(
      c,
      Rect.fromCenter(center: Offset(50, cy), width: 44, height: h * 0.86),
    );
    _drawE(c, Offset(50, cy), 26, EDir.right, _ink);
  }

  void _swipeArrows(Canvas c, double h) {
    final cy = h / 2;
    _phone(
      c,
      Rect.fromCenter(center: Offset(50, cy), width: 44, height: h * 0.86),
    );
    _drawE(c, Offset(50, cy - 8), 16, EDir.up, _ink);
    // four small arrows around + a swiping finger
    _arrow(
      c,
      Offset(50, cy + 10),
      Offset(50, cy + 2),
      color: _teal,
      width: 2.2,
      head: 3.5,
    );
    _arrow(
      c,
      Offset(38, cy + 16),
      Offset(32, cy + 16),
      color: _mute,
      width: 1.6,
      head: 3,
    );
    _arrow(
      c,
      Offset(62, cy + 16),
      Offset(68, cy + 16),
      color: _mute,
      width: 1.6,
      head: 3,
    );
    _arrow(
      c,
      Offset(50, cy + 20),
      Offset(50, cy + 27),
      color: _mute,
      width: 1.6,
      head: 3,
    );
    _rrect(c, Rect.fromLTWH(56, cy + 22, 8, 22), 4, _fill(_skin));
    _rrect(c, Rect.fromLTWH(56, cy + 22, 8, 22), 4, _stroke(_skinLine, 1.2));
  }

  void _glasses(Canvas c, double h, {required bool reading}) {
    final center = Offset(50, h / 2 + 2);
    _face(c, center, 30);
    final p = _stroke(_ink, 2.2);
    final y = center.dy + 1.5;
    final r = reading ? 7.0 : 9.0;
    c.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - 10, y),
        width: r * 2.2,
        height: r * 1.7,
      ),
      p,
    );
    c.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 10, y),
        width: r * 2.2,
        height: r * 1.7,
      ),
      p,
    );
    c.drawLine(Offset(center.dx - 2, y), Offset(center.dx + 2, y), p);
    c.drawLine(
      Offset(center.dx - 10 - r * 1.1, y),
      Offset(center.dx - 28, y - 3),
      p,
    );
    c.drawLine(
      Offset(center.dx + 10 + r * 1.1, y),
      Offset(center.dx + 28, y - 3),
      p,
    );
    if (reading) {
      // book below
      _rrect(
        c,
        Rect.fromLTWH(30, h - 16, 40, 10),
        2,
        _fill(const Color(0xFFE2E8F0)),
      );
      c.drawLine(Offset(50, h - 16), Offset(50, h - 6), _stroke(_mute, 1.4));
    }
  }

  void _colourPlate(Canvas c, double h) {
    // The same mosaic the test draws (type A, numeral 7).
    final center = Offset(50, h / 2);
    final r = math.min(38.0, h * 0.42);
    c.drawCircle(center, r, _fill(const Color(0xFFF4EFE3)));
    const plate = ColourPlate(
      index: 0,
      digit: 7,
      type: PlateType.a,
      seed: 4207,
    );
    final layout = PlateDotLayout.of(plate, r);
    final paint = Paint();
    for (final d in layout.dots) {
      paint.color = Color(d.argb);
      c.drawCircle(center + Offset(d.x, d.y), d.r, paint);
    }
  }

  void _brightness(Canvas c, double h) {
    final cy = h / 2;
    _phone(
      c,
      Rect.fromCenter(center: Offset(38, cy), width: 34, height: h * 0.8),
    );
    // brightness slider inside
    _rrect(
      c,
      Rect.fromLTWH(26, cy + 14, 24, 4),
      2,
      _fill(const Color(0xFFE2E8F0)),
    );
    _rrect(c, Rect.fromLTWH(26, cy + 14, 24, 4), 2, _fill(_teal));
    c.drawCircle(Offset(50, cy + 16), 3.5, _fill(_teal));
    // sun
    final sun = Offset(74, cy - 12);
    c.drawCircle(sun, 9, _fill(const Color(0xFFFACC15)));
    c.drawCircle(sun, 9, _stroke(_amber, 1.6));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(
        sun + Offset.fromDirection(a, 12),
        sun + Offset.fromDirection(a, 17),
        _stroke(_amber, 2),
      );
    }
    _label(c, '100%', Offset(74, cy + 14), size: 8, color: _teal);
  }

  void _noFilter(Canvas c, double h) {
    final cy = h / 2;
    _phone(
      c,
      Rect.fromCenter(center: Offset(50, cy), width: 40, height: h * 0.82),
      screen: const Color(0xFFFFE4B5),
    );
    // moon (night mode) crossed out
    final moon = Offset(50, cy - 6);
    c.drawCircle(moon, 10, _fill(const Color(0xFF475569)));
    c.drawCircle(moon + const Offset(5, -3), 8, _fill(const Color(0xFFFFE4B5)));
    c.drawLine(Offset(32, cy - 24), Offset(68, cy + 12), _stroke(_red, 3));
    _label(c, 'OFF', Offset(50, cy + 20), size: 8, color: _red);
  }

  void _amsler(Canvas c, double h, {required bool marked}) {
    final side = math.min(72.0, h * 0.84);
    final rect = Rect.fromCenter(
      center: Offset(50, h / 2),
      width: side,
      height: side,
    );
    c.drawRect(rect, _fill(Colors.white));
    c.drawRect(rect, _stroke(_ink, 1.6));
    const n = 10;
    final step = side / n;
    for (var i = 1; i < n; i++) {
      final x = rect.left + i * step;
      final y = rect.top + i * step;
      if (marked && i >= 6 && i <= 8) {
        // wavy segment
        final path = Path()..moveTo(rect.left, y);
        for (var k = 1; k <= 12; k++) {
          final px = rect.left + k * side / 12;
          path.lineTo(
            px,
            y + (k.isEven ? 2.2 : -2.2) * (px > rect.center.dx ? 1 : 0.2),
          );
        }
        c.drawPath(path, _stroke(_ink, 1.0));
      } else {
        c.drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          _stroke(_ink, 1.0),
        );
      }
      c.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        _stroke(_ink, 1.0),
      );
    }
    c.drawCircle(rect.center, 3, _fill(_ink));
    if (marked) {
      c.drawRect(
        Rect.fromLTWH(
          rect.center.dx + step * 0.5,
          rect.top + step * 5.5,
          step * 3.5,
          step * 3,
        ),
        _fill(_red.withValues(alpha: 0.35)),
      );
      // finger
      _rrect(
        c,
        Rect.fromLTWH(rect.right - 16, rect.bottom - 18, 8, 26),
        4,
        _fill(_skin),
      );
      _rrect(
        c,
        Rect.fromLTWH(rect.right - 16, rect.bottom - 18, 8, 26),
        4,
        _stroke(_skinLine, 1.2),
      );
    }
  }

  void _tapFlash(Canvas c, double h) {
    final cy = h / 2;
    final phone = Rect.fromCenter(
      center: Offset(50, cy),
      width: 44,
      height: h * 0.86,
    );
    _phone(c, phone, screen: const Color(0xFF22C55E));
    // flash rays
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + (i - 2.5) * 0.35;
      final from = Offset(50, phone.top - 2) + Offset.fromDirection(a, 4);
      c.drawLine(from, from + Offset.fromDirection(a, 7), _stroke(_amber, 2));
    }
    _rrect(c, Rect.fromLTWH(54, cy + 2, 9, 30), 4.5, _fill(_skin));
    _rrect(c, Rect.fromLTWH(54, cy + 2, 9, 30), 4.5, _stroke(_skinLine, 1.2));
  }

  void _speaker(Canvas c, double h) {
    final cy = h / 2;
    _phone(
      c,
      Rect.fromCenter(center: Offset(36, cy), width: 34, height: h * 0.8),
    );
    final sp = Path()
      ..moveTo(24, cy - 5)
      ..lineTo(30, cy - 5)
      ..lineTo(38, cy - 12)
      ..lineTo(38, cy + 12)
      ..lineTo(30, cy + 5)
      ..lineTo(24, cy + 5)
      ..close();
    c.drawPath(sp, _fill(_ink));
    for (var i = 1; i <= 3; i++) {
      c.drawArc(
        Rect.fromCircle(center: Offset(40, cy), radius: 6.0 * i + 2),
        -0.6,
        1.2,
        false,
        _stroke(_teal, 2.2),
      );
    }
    _rrect(c, Rect.fromLTWH(74, cy - 4, 9, 30), 4.5, _fill(_skin));
    _rrect(c, Rect.fromLTWH(74, cy - 4, 9, 30), 4.5, _stroke(_skinLine, 1.2));
  }

  void _waitThenTap(Canvas c, double h) {
    final cy = h / 2;
    _phone(
      c,
      Rect.fromCenter(center: Offset(28, cy), width: 30, height: h * 0.72),
      screen: const Color(0xFFE2E8F0),
    );
    _label(c, 'Wait', Offset(28, cy), size: 7, color: _mute);
    _arrow(c, Offset(46, cy), Offset(56, cy), color: _teal);
    _phone(
      c,
      Rect.fromCenter(center: Offset(74, cy), width: 30, height: h * 0.72),
      screen: const Color(0xFF22C55E),
    );
    _label(c, 'TAP', Offset(74, cy), size: 7, color: Colors.white);
  }

  void _tape(Canvas c, double h) {
    final cy = h / 2 + 4;
    final body = Rect.fromCenter(center: Offset(26, cy), width: 26, height: 24);
    _rrect(c, body, 7, _fill(const Color(0xFFFACC15)));
    _rrect(c, body, 7, _stroke(_ink, 1.6));
    c.drawCircle(Offset(26, cy), 5, _stroke(_ink, 1.6));
    final tape = Rect.fromLTWH(39, cy - 4, 52, 8);
    c.drawRect(tape, _fill(const Color(0xFFFEF08A)));
    c.drawRect(tape, _stroke(_ink, 1.4));
    for (var x = 43.0; x < 90; x += 5) {
      final tall = ((x - 43) / 5).round() % 2 == 0;
      c.drawLine(
        Offset(x, cy - 4),
        Offset(x, cy - 4 + (tall ? 4 : 2)),
        _stroke(_ink, 1),
      );
    }
    c.drawRect(Rect.fromLTWH(90, cy - 6, 3, 12), _fill(_ink));
  }

  void _eyeBadge(Canvas c, double h, {required bool left}) {
    final center = Offset(50, h / 2 + 2);
    _face(c, center, 30, coverLeft: !left);
    if (left) {
      // cover the member's right eye instead: mirror the palm
      c.save();
      c.translate(100, 0);
      c.scale(-1, 1);
      _face(c, Offset(100 - center.dx, center.dy), 30, coverLeft: true);
      c.restore();
    }
    final badge = Offset(left ? 18 : 82, h * 0.18);
    c.drawCircle(badge, 9, _fill(_teal));
    _label(c, left ? 'L' : 'R', badge, size: 10, color: Colors.white);
  }

  @override
  bool shouldRepaint(covariant _VisionPainter old) => old.kind != kind;
}

/// Local copy of the optotype orientation for the painter (keeps this file
/// free of the engine import).
enum EDir { up, right, down, left }
