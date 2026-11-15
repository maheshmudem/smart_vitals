import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/entities/movement_protocol.dart';

/// Flat instructional drawings for the movement tests.
///
/// One painter, one `switch` per kind, built from shared parts (person, hand,
/// phone, chair, arrows) so every picture reads the same way whether it is a
/// 56 px checklist icon or a 150 px how-to hero. All drawing happens in a
/// logical 100-unit-wide space scaled uniformly to the widget, so nothing is
/// stretched; [wide] gives a 4:3 canvas (logical height 75).
class MovementIllustrationView extends StatelessWidget {
  const MovementIllustrationView({
    super.key,
    required this.kind,
    this.size = 96,
    this.background,
    this.wide = false,
  });

  final MovementIllustration kind;

  /// Width in pixels (height is [size] for square, 0.75 × [size] when [wide]).
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
        child: CustomPaint(painter: _MovementPainter(kind)),
      ),
    );
  }
}

class _MovementPainter extends CustomPainter {
  const _MovementPainter(this.kind);

  final MovementIllustration kind;

  // Palette
  static const Color _skin = Color(0xFFF3CDA9);
  static const Color _skinLine = Color(0xFFC98A5B);
  static const Color _ink = Color(0xFF1E293B);
  static const Color _shirt = Color(0xFF0E9F94);
  static const Color _trousers = Color(0xFF334155);
  static const Color _phoneBody = Color(0xFF1F2937);
  static const Color _screen = Color(0xFFE0F2FE);
  static const Color _teal = Color(0xFF0B7A75);
  static const Color _green = Color(0xFF15803D);
  static const Color _amber = Color(0xFFD97706);
  static const Color _wood = Color(0xFFB08968);
  static const Color _woodDark = Color(0xFF8C6A4E);
  static const Color _mute = Color(0xFF94A3B8);
  static const Color _hair = Color(0xFF3F2E25);

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
    final h = size.height / s; // logical height (100 square, 75 wide)
    switch (kind) {
      case MovementIllustration.handInFrame:
        _drawHandInFrame(canvas, h);
      case MovementIllustration.handTapping:
        _drawHandTapping(canvas, h);
      case MovementIllustration.tapOpenClose:
        _drawTapOpenClose(canvas, h);
      case MovementIllustration.twoTargets:
        _drawTwoTargets(canvas, h);
      case MovementIllustration.tableFlat:
        _drawTableFlat(canvas, h);
      case MovementIllustration.phoneInPocket:
        _drawPhoneInPocket(canvas, h);
      case MovementIllustration.walk10m:
        _drawWalk10m(canvas, h);
      case MovementIllustration.measureTape:
        _drawMeasureTape(canvas, h);
      case MovementIllustration.chairArmless:
        _drawChairArmless(canvas, h);
      case MovementIllustration.sitReady:
        _drawSitReady(canvas, h);
      case MovementIllustration.standUp:
        _drawStandUp(canvas, h);
      case MovementIllustration.armOutstretched:
        _drawArmOutstretched(canvas, h);
      case MovementIllustration.bubbleLevel:
        _drawBubbleLevel(canvas, h);
      case MovementIllustration.holdStill:
        _drawHoldStill(canvas, h);
      case MovementIllustration.countdown:
        _drawCountdown(canvas, h);
      case MovementIllustration.switchHands:
        _drawSwitchHands(canvas, h);
      case MovementIllustration.handLeft:
        _drawSingleHand(canvas, h, left: true);
      case MovementIllustration.handRight:
        _drawSingleHand(canvas, h, left: false);
      case MovementIllustration.restartHand:
        _drawRestartHand(canvas, h);
      case MovementIllustration.lightEven:
        _drawLightEven(canvas, h);
      case MovementIllustration.phoneStand:
        _drawPhoneStand(canvas, h);
    }
    canvas.restore();
  }

  // ───────────────────────── shared parts ─────────────────────────────────

  void _rrect(Canvas c, Rect r, double radius, Paint p) =>
      c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p);

  /// Capsule from [base] of [length] along [angle] (0 = straight up,
  /// positive = clockwise).
  void _capsule(
    Canvas c,
    Offset base,
    double angle,
    double length,
    double width, {
    Color fill = _skin,
    Color? outline = _skinLine,
    double outlineWidth = 1.4,
  }) {
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(angle);
    final r = Rect.fromLTWH(-width / 2, -length, width, length + width / 2);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(width / 2));
    c.drawRRect(rr, _fill(fill));
    if (outline != null) c.drawRRect(rr, _stroke(outline, outlineWidth));
    c.restore();
  }

  void _head(Canvas c, Offset center, double r, {bool side = false}) {
    c.drawCircle(center, r, _fill(_skin));
    c.drawCircle(center, r, _stroke(_skinLine, 1.4));
    // hair cap
    final hair = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: r),
        math.pi * 1.05,
        math.pi * 0.9,
      )
      ..close();
    c.drawPath(hair, _fill(_hair));
    if (side) {
      // ear
      c.drawCircle(
        center + Offset(-r * 0.05, r * 0.15),
        r * 0.18,
        _fill(_skin),
      );
    } else {
      // eyes
      c.drawCircle(center + Offset(-r * 0.3, r * 0.1), r * 0.1, _fill(_ink));
      c.drawCircle(center + Offset(r * 0.3, r * 0.1), r * 0.1, _fill(_ink));
    }
  }

  /// Open hand seen palm-on. [center] is the palm centre, [s] the palm
  /// width. [openness] 1 = thumb wide, 0 = thumb touching index tip.
  /// [left] mirrors the thumb to the right side.
  void _hand(
    Canvas c,
    Offset center,
    double s, {
    double openness = 1.0,
    bool left = false,
  }) {
    c.save();
    c.translate(center.dx, center.dy);
    if (left) c.scale(-1, 1);
    final palm = Rect.fromCenter(
      center: Offset.zero,
      width: s,
      height: s * 1.1,
    );
    final fingerW = s * 0.24;
    // four fingers from the palm top
    final xs = [-0.36, -0.12, 0.12, 0.36];
    final lens = [0.8, 0.95, 0.9, 0.72];
    final angs = [-0.16, -0.05, 0.05, 0.16];
    for (var i = 0; i < 4; i++) {
      var ang = angs[i];
      var len = lens[i] * s;
      if (i == 0) {
        // index finger leans toward the thumb as the pinch closes
        ang = -0.16 - (1 - openness) * 0.55;
        len = lens[i] * s * (0.75 + 0.25 * openness);
      }
      _capsule(c, Offset(xs[i] * s, -palm.height * 0.42), ang, len, fingerW);
    }
    // palm
    _rrect(c, palm, s * 0.22, _fill(_skin));
    _rrect(c, palm, s * 0.22, _stroke(_skinLine, 1.4));
    // thumb
    final thumbAng = -(0.55 + openness * 0.75);
    _capsule(
      c,
      Offset(-s * 0.42, palm.height * 0.05),
      thumbAng,
      s * 0.8,
      fingerW * 1.05,
    );
    c.restore();
  }

  /// Thumb-tip and index-tip positions for [_hand] with the same arguments.
  (Offset, Offset) _handTips(
    Offset center,
    double s, {
    double openness = 1.0,
    bool left = false,
  }) {
    final palmH = s * 1.1;
    final idxAng = -0.16 - (1 - openness) * 0.55;
    final idxLen = 0.8 * s * (0.75 + 0.25 * openness);
    final idxBase = Offset(-0.36 * s, -palmH * 0.42);
    final idxTip =
        idxBase + Offset(math.sin(idxAng) * idxLen, -math.cos(idxAng) * idxLen);
    final thAng = -(0.55 + openness * 0.75);
    final thLen = 0.8 * s;
    final thBase = Offset(-s * 0.42, palmH * 0.05);
    final thTip =
        thBase + Offset(math.sin(thAng) * thLen, -math.cos(thAng) * thLen);
    Offset place(Offset p) => center + Offset(left ? -p.dx : p.dx, p.dy);
    return (place(thTip), place(idxTip));
  }

  /// Upright phone. [landscape] lies it on its side.
  void _phone(
    Canvas c,
    Rect r, {
    bool landscape = false,
    bool cameraDot = true,
    Color screen = _screen,
  }) {
    final radius = math.min(r.width, r.height) * 0.18;
    _rrect(c, r, radius, _fill(_phoneBody));
    final inset = math.min(r.width, r.height) * 0.09;
    final sc = r.deflate(inset);
    _rrect(c, sc, radius * 0.6, _fill(screen));
    if (cameraDot) {
      final dot = landscape
          ? Offset(sc.left + inset * 0.9, sc.center.dy)
          : Offset(sc.center.dx, sc.top + inset * 0.9);
      c.drawCircle(dot, inset * 0.45, _fill(_phoneBody));
    }
  }

  void _arrow(
    Canvas c,
    Offset a,
    Offset b, {
    Color color = _teal,
    double width = 2.6,
    bool bothEnds = false,
    double head = 5,
  }) {
    final p = _stroke(color, width);
    c.drawLine(a, b, p);
    _arrowHead(c, b, (b - a).direction, head, p);
    if (bothEnds) _arrowHead(c, a, (a - b).direction, head, p);
  }

  void _arrowHead(Canvas c, Offset tip, double dir, double len, Paint p) {
    final l = tip + Offset.fromDirection(dir + math.pi * 0.8, len);
    final r = tip + Offset.fromDirection(dir - math.pi * 0.8, len);
    c.drawLine(tip, l, p);
    c.drawLine(tip, r, p);
  }

  void _arcArrow(
    Canvas c,
    Offset center,
    double radius,
    double start,
    double sweep, {
    Color color = _teal,
    double width = 2.6,
    bool bothEnds = false,
  }) {
    final p = _stroke(color, width);
    c.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      p,
    );
    final end = center + Offset.fromDirection(start + sweep, radius);
    final tangentEnd = start + sweep + (sweep > 0 ? math.pi / 2 : -math.pi / 2);
    _arrowHead(c, end, tangentEnd, 5, p);
    if (bothEnds) {
      final st = center + Offset.fromDirection(start, radius);
      final tangentStart = start + (sweep > 0 ? -math.pi / 2 : math.pi / 2);
      _arrowHead(c, st, tangentStart, 5, p);
    }
  }

  void _floor(Canvas c, double y, {double x0 = 6, double x1 = 94}) {
    c.drawLine(Offset(x0, y), Offset(x1, y), _stroke(_mute, 2));
  }

  void _dashedRRect(Canvas c, Rect r, double radius, Paint p) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, d + 4), p);
        d += 7;
      }
    }
  }

  void _dashedLine(Canvas c, Offset a, Offset b, Paint p) {
    final len = (b - a).distance;
    final dir = (b - a) / len;
    var d = 0.0;
    while (d < len) {
      final e = math.min(d + 4, len);
      c.drawLine(a + dir * d, a + dir * e, p);
      d += 7;
    }
  }

  void _check(Canvas c, Offset center, double r) {
    c.drawCircle(center, r, _fill(_green));
    final p = _stroke(Colors.white, r * 0.32);
    c.drawLine(
      center + Offset(-r * 0.45, 0),
      center + Offset(-r * 0.1, r * 0.35),
      p,
    );
    c.drawLine(
      center + Offset(-r * 0.1, r * 0.35),
      center + Offset(r * 0.5, -r * 0.35),
      p,
    );
  }

  void _label(
    Canvas c,
    String text,
    Offset center, {
    double size = 9,
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
          fontFamily: "Roboto",
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Side-view chair (facing left). [x] is the front edge of the seat,
  /// [y] the seat height, [wall] draws a wall line behind.
  void _chairSide(Canvas c, double x, double y, {bool wall = true}) {
    final depth = 26.0;
    final back = x + depth;
    if (wall) {
      c.drawLine(
        Offset(back + 6, y - 34),
        Offset(back + 6, y + 30),
        _stroke(_mute, 2),
      );
    }
    // seat
    _rrect(c, Rect.fromLTWH(x, y - 3, depth, 6), 2, _fill(_wood));
    // backrest
    _rrect(c, Rect.fromLTWH(back - 5, y - 32, 5, 32), 2, _fill(_woodDark));
    // legs
    c.drawLine(
      Offset(x + 3, y + 3),
      Offset(x + 3, y + 26),
      _stroke(_woodDark, 3),
    );
    c.drawLine(
      Offset(back - 3, y + 3),
      Offset(back - 3, y + 26),
      _stroke(_woodDark, 3),
    );
  }

  /// Side-view person standing (facing left), feet at [feetY], centred at [x].
  /// [stride] 0..1 spreads the legs; [armSwing] swings the arms.
  void _personSide(
    Canvas c,
    double x,
    double feetY, {
    double stride = 0,
    double scale = 1,
    bool phonePocket = false,
  }) {
    final hipY = feetY - 28 * scale;
    final shoulderY = hipY - 22 * scale;
    final headR = 7.5 * scale;
    // legs
    _capsule(
      c,
      Offset(x, hipY),
      math.pi + 0.45 * stride,
      28 * scale,
      9 * scale,
      fill: _trousers,
      outline: null,
    );
    _capsule(
      c,
      Offset(x, hipY),
      math.pi - 0.45 * stride,
      28 * scale,
      9 * scale,
      fill: _trousers,
      outline: null,
    );
    // torso
    _rrect(
      c,
      Rect.fromCenter(
        center: Offset(x, (hipY + shoulderY) / 2),
        width: 14 * scale,
        height: 26 * scale,
      ),
      5 * scale,
      _fill(_shirt),
    );
    // arms
    _capsule(
      c,
      Offset(x, shoulderY + 2 * scale),
      math.pi - 0.5 * stride,
      20 * scale,
      6 * scale,
    );
    _capsule(
      c,
      Offset(x, shoulderY + 2 * scale),
      math.pi + 0.5 * stride,
      20 * scale,
      6 * scale,
    );
    // head
    _head(c, Offset(x, shoulderY - headR - 3 * scale), headR, side: true);
    if (phonePocket) {
      final pr = Rect.fromLTWH(
        x - 7 * scale,
        hipY + 3 * scale,
        6 * scale,
        11 * scale,
      );
      _dashedRRect(c, pr, 1.5, _stroke(Colors.white, 1.4));
    }
  }

  // ───────────────────────── drawings ─────────────────────────────────────

  void _drawHandInFrame(Canvas c, double h) {
    final cy = h / 2;
    // phone upright
    final phone = Rect.fromCenter(
      center: Offset(50, cy),
      width: 46,
      height: h * 0.86,
    );
    _phone(c, phone);
    final sc = phone.deflate(4.5);
    // dashed outline on the screen
    final guide = Rect.fromCenter(
      center: Offset(sc.center.dx, sc.center.dy + 2),
      width: sc.width * 0.72,
      height: sc.height * 0.66,
    );
    _dashedRRect(c, guide, 6, _stroke(_teal, 1.6));
    // hand inside
    _hand(
      c,
      Offset(guide.center.dx, guide.center.dy + 3),
      guide.width * 0.44,
      openness: 0.75,
    );
    // found tick
    _check(c, Offset(phone.right - 2, phone.top + 4), 7);
  }

  void _drawHandTapping(Canvas c, double h) {
    final cy = h / 2 + 9;
    final s = h * 0.29;
    final center = Offset(56, cy);
    _hand(c, center, s, openness: 1.0);
    final (th, ix) = _handTips(center, s, openness: 1.0);
    // double arrow between thumb tip and index tip, bowed outward
    final mid = (th + ix) / 2;
    final normal = Offset((ix - th).dy, -(ix - th).dx);
    final nl = normal.distance == 0 ? Offset.zero : normal / normal.distance;
    final ctrl = mid + nl * 10;
    final path = Path()
      ..moveTo(th.dx, th.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, ix.dx, ix.dy);
    final p = _stroke(_amber, 2.6);
    c.drawPath(path, p);
    _arrowHead(c, ix, (ix - ctrl).direction, 5, p);
    _arrowHead(c, th, (th - ctrl).direction, 5, p);
    // motion ticks near the index tip
    for (var i = -1; i <= 1; i++) {
      final a = (ix - ctrl).direction + i * 0.5;
      c.drawLine(
        ix + Offset.fromDirection(a, 7),
        ix + Offset.fromDirection(a, 12),
        _stroke(_amber, 2),
      );
    }
  }

  void _drawTapOpenClose(Canvas c, double h) {
    final cy = h / 2 + 4;
    const s = 20.0;
    _hand(c, Offset(27, cy), s, openness: 1.0);
    _hand(c, Offset(75, cy), s, openness: 0.0);
    _arrow(c, Offset(44, cy - 2), Offset(58, cy - 2), bothEnds: true);
  }

  void _drawTwoTargets(Canvas c, double h) {
    final cy = h / 2;
    // phone lying flat (portrait, seen from above)
    final phone = Rect.fromCenter(
      center: Offset(44, cy),
      width: 48,
      height: h * 0.88,
    );
    _phone(c, phone, cameraDot: false, screen: const Color(0xFF0F172A));
    final sc = phone.deflate(4.5);
    final a = Offset(sc.left + sc.width * 0.36, sc.bottom - sc.height * 0.26);
    final b = Offset(sc.right - sc.width * 0.34, sc.top + sc.height * 0.26);
    final r = sc.width * 0.27;
    for (final (pt, label) in [(a, 'A'), (b, 'B')]) {
      c.drawCircle(
        pt,
        r,
        _fill(const Color(0xFF00E5CC).withValues(alpha: 0.25)),
      );
      c.drawCircle(pt, r, _stroke(const Color(0xFF00E5CC), 2));
      _label(c, label, pt, size: r * 1.0, color: Colors.white);
    }
    // dotted path A → B
    _dashedLine(
      c,
      a + Offset(r * 0.6, -r * 0.6),
      b + Offset(-r * 0.6, r * 0.6),
      _stroke(Colors.white, 1.6),
    );
    // pointing finger coming from the right
    _capsule(c, Offset(a.dx + 3, a.dy + 24), -0.35, 24, 8);
    _rrect(
      c,
      Rect.fromCenter(
        center: Offset(a.dx + 14, a.dy + 30),
        width: 18,
        height: 16,
      ),
      5,
      _fill(_skin),
    );
    _rrect(
      c,
      Rect.fromCenter(
        center: Offset(a.dx + 14, a.dy + 30),
        width: 18,
        height: 16,
      ),
      5,
      _stroke(_skinLine, 1.4),
    );
  }

  void _drawTableFlat(Canvas c, double h) {
    final cy = h / 2;
    // table top (perspective trapezoid)
    final top = Path()
      ..moveTo(16, cy + 10)
      ..lineTo(84, cy + 10)
      ..lineTo(92, cy + 28)
      ..lineTo(8, cy + 28)
      ..close();
    c.drawPath(top, _fill(_wood));
    c.drawLine(Offset(12, cy + 28), Offset(12, cy + 40), _stroke(_woodDark, 3));
    c.drawLine(Offset(88, cy + 28), Offset(88, cy + 40), _stroke(_woodDark, 3));
    // phone lying flat on it
    final phone = Rect.fromCenter(
      center: Offset(50, cy + 17),
      width: 40,
      height: 18,
    );
    _phone(c, phone, landscape: true);
    // hand above, finger pointing down to the screen
    _capsule(c, Offset(62, cy - 14), math.pi * 0.98, 18, 7);
    _rrect(
      c,
      Rect.fromCenter(center: Offset(66, cy - 22), width: 20, height: 16),
      5,
      _fill(_skin),
    );
    _rrect(
      c,
      Rect.fromCenter(center: Offset(66, cy - 22), width: 20, height: 16),
      5,
      _stroke(_skinLine, 1.4),
    );
  }

  void _drawPhoneInPocket(Canvas c, double h) {
    // front-view standing person with the phone outlined in the pocket
    final feetY = h * 0.92;
    const x = 44.0;
    final hipY = feetY - 36;
    final shoulderY = hipY - 26;
    // legs
    _rrect(c, Rect.fromLTWH(x - 13, hipY - 2, 11, 36), 4, _fill(_trousers));
    _rrect(c, Rect.fromLTWH(x + 2, hipY - 2, 11, 36), 4, _fill(_trousers));
    // torso
    _rrect(
      c,
      Rect.fromCenter(
        center: Offset(x, (hipY + shoulderY) / 2),
        width: 28,
        height: 30,
      ),
      6,
      _fill(_shirt),
    );
    // arms
    _capsule(c, Offset(x - 15, shoulderY + 3), math.pi - 0.12, 26, 7);
    _capsule(c, Offset(x + 15, shoulderY + 3), math.pi + 0.12, 26, 7);
    _head(c, Offset(x, shoulderY - 11), 9);
    // pocket with phone
    final pocket = Rect.fromLTWH(x + 3, hipY + 1, 9, 15);
    _rrect(c, pocket, 2, _fill(const Color(0xFF475569)));
    _dashedRRect(c, pocket.deflate(1), 1.5, _stroke(Colors.white, 1.3));
    // callout arrow from a small phone on the right
    final phone = Rect.fromLTWH(74, hipY - 10, 14, 26);
    _phone(c, phone);
    _arrow(
      c,
      Offset(73, hipY + 8),
      Offset(pocket.right + 3, hipY + 8),
      color: _amber,
    );
  }

  void _drawWalk10m(Canvas c, double h) {
    final floorY = h * 0.84;
    _floor(c, floorY);
    // start / end marks
    for (final x in [12.0, 88.0]) {
      c.drawLine(
        Offset(x, floorY - 8),
        Offset(x, floorY + 2),
        _stroke(_amber, 3),
      );
    }
    // dimension line
    final dimY = floorY + 8;
    if (dimY < h - 2) {
      _arrow(
        c,
        Offset(16, dimY),
        Offset(84, dimY),
        bothEnds: true,
        color: _mute,
        width: 1.8,
      );
      _label(c, '10 m', Offset(50, dimY), size: 7, color: _ink);
      c.drawRect(
        Rect.fromCenter(center: Offset(50, dimY), width: 18, height: 8),
        _fill(const Color(0xFFF1F5F9)),
      );
      _label(c, '10 m', Offset(50, dimY), size: 7, color: _ink);
    }
    _personSide(c, 52, floorY, stride: 1, scale: 0.9, phonePocket: true);
    _arrow(c, Offset(66, floorY - 34), Offset(80, floorY - 34), color: _teal);
  }

  void _drawMeasureTape(Canvas c, double h) {
    final cy = h / 2 + 6;
    // tape body
    final body = Rect.fromCenter(center: Offset(26, cy), width: 26, height: 24);
    _rrect(c, body, 7, _fill(const Color(0xFFFACC15)));
    _rrect(c, body, 7, _stroke(_ink, 1.6));
    c.drawCircle(Offset(26, cy), 5, _stroke(_ink, 1.6));
    // extended tape
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
    // end hook
    c.drawRect(Rect.fromLTWH(90, cy - 6, 3, 12), _fill(_ink));
    // floor marks
    final floorY = cy + 18;
    _floor(c, floorY);
    for (final x in [14.0, 86.0]) {
      c.drawLine(
        Offset(x, floorY - 7),
        Offset(x, floorY + 1),
        _stroke(_amber, 3),
      );
    }
  }

  void _drawChairArmless(Canvas c, double h) {
    final floorY = h * 0.86;
    _floor(c, floorY, x0: 10, x1: 90);
    _chairSide(c, 32, floorY - 26);
    // seat-height dimension
    final x = 22.0;
    _arrow(
      c,
      Offset(x, floorY),
      Offset(x, floorY - 26),
      bothEnds: true,
      color: _mute,
      width: 1.6,
      head: 3.5,
    );
    _check(c, Offset(78, h * 0.22), 8);
  }

  void _drawSitReady(Canvas c, double h) {
    // front view, seated, arms crossed on the chest, feet flat
    final floorY = h * 0.9;
    const x = 50.0;
    final seatY = floorY - 26;
    final shoulderY = seatY - 26;
    // chair back + seat (front view)
    _rrect(c, Rect.fromLTWH(x - 18, seatY - 32, 36, 36), 4, _fill(_woodDark));
    _rrect(c, Rect.fromLTWH(x - 20, seatY - 3, 40, 7), 3, _fill(_wood));
    // legs down to the floor, shins vertical
    _rrect(c, Rect.fromLTWH(x - 14, seatY - 2, 11, 28), 4, _fill(_trousers));
    _rrect(c, Rect.fromLTWH(x + 3, seatY - 2, 11, 28), 4, _fill(_trousers));
    // feet
    _rrect(c, Rect.fromLTWH(x - 16, floorY - 4, 14, 4), 2, _fill(_ink));
    _rrect(c, Rect.fromLTWH(x + 2, floorY - 4, 14, 4), 2, _fill(_ink));
    // torso
    _rrect(
      c,
      Rect.fromCenter(
        center: Offset(x, (seatY + shoulderY) / 2),
        width: 28,
        height: 30,
      ),
      6,
      _fill(_shirt),
    );
    // forearms crossed over the chest (each runs from a hip-side elbow up
    // to the opposite shoulder)
    _capsule(c, Offset(x - 17, shoulderY + 21), 0.95, 26, 7);
    _capsule(c, Offset(x + 17, shoulderY + 21), -0.95, 26, 7);
    _head(c, Offset(x, shoulderY - 11), 9);
    _floor(c, floorY, x0: 14, x1: 86);
  }

  void _drawStandUp(Canvas c, double h) {
    // seated figure on the left, standing figure on the right, up arrow
    final floorY = h * 0.86;
    _floor(c, floorY, x0: 6, x1: 94);
    final seatY = floorY - 24;
    _chairSide(c, 20, seatY, wall: false);
    // seated side view (small)
    const sx = 20.0;
    final hipY = seatY - 2;
    final shoulderY = hipY - 20;
    _capsule(
      c,
      Offset(sx, hipY),
      -math.pi / 2,
      15,
      8,
      fill: _trousers,
      outline: null,
    );
    _capsule(
      c,
      Offset(sx - 15, hipY),
      math.pi,
      22,
      8,
      fill: _trousers,
      outline: null,
    );
    _rrect(
      c,
      Rect.fromCenter(
        center: Offset(sx, (hipY + shoulderY) / 2),
        width: 12,
        height: 22,
      ),
      4,
      _fill(_shirt),
    );
    _capsule(c, Offset(sx - 2, shoulderY + 8), -1.9, 11, 5);
    _head(c, Offset(sx, shoulderY - 8), 6.5, side: true);
    // arrow up-right
    _arrow(
      c,
      Offset(44, hipY + 2),
      Offset(58, hipY - 14),
      color: _green,
      width: 3,
      head: 5,
    );
    // standing figure
    _personSide(c, 74, floorY, scale: 0.95);
  }

  void _drawArmOutstretched(Canvas c, double h) {
    final floorY = h * 0.9;
    _floor(c, floorY, x0: 8, x1: 92);
    final seatY = floorY - 26;
    _chairSide(c, 56, seatY, wall: true);
    const x = 56.0;
    final hipY = seatY - 2;
    final shoulderY = hipY - 24;
    // thigh forward, shin down
    _capsule(
      c,
      Offset(x, hipY),
      -math.pi / 2,
      18,
      9,
      fill: _trousers,
      outline: null,
    );
    _capsule(
      c,
      Offset(x - 18, hipY),
      math.pi,
      24,
      9,
      fill: _trousers,
      outline: null,
    );
    // torso upright
    _rrect(
      c,
      Rect.fromCenter(
        center: Offset(x, (hipY + shoulderY) / 2),
        width: 14,
        height: 26,
      ),
      5,
      _fill(_shirt),
    );
    // arm straight out to the left, palm down
    _capsule(c, Offset(x - 2, shoulderY + 3), -math.pi / 2, 34, 7);
    // phone lying flat on the hand
    final phone = Rect.fromLTWH(x - 46, shoulderY - 2, 16, 5);
    _phone(c, phone, landscape: true, cameraDot: false);
    // shoulder-height dashed line
    _dashedLine(
      c,
      Offset(8, shoulderY + 3),
      Offset(x - 48, shoulderY + 3),
      _stroke(_mute, 1.4),
    );
    _head(c, Offset(x, shoulderY - 10), 8, side: true);
  }

  void _drawBubbleLevel(Canvas c, double h) {
    final center = Offset(50, h / 2);
    c.drawCircle(center, 34, _fill(Colors.white));
    c.drawCircle(center, 34, _stroke(_mute, 2));
    c.drawCircle(center, 14, _stroke(_green, 2.4));
    c.drawCircle(center, 9, _fill(_green));
    // cross hairs
    c.drawLine(
      center + const Offset(-34, 0),
      center + const Offset(-20, 0),
      _stroke(_mute, 1.4),
    );
    c.drawLine(
      center + const Offset(20, 0),
      center + const Offset(34, 0),
      _stroke(_mute, 1.4),
    );
    c.drawLine(
      center + const Offset(0, -34),
      center + const Offset(0, -20),
      _stroke(_mute, 1.4),
    );
    c.drawLine(
      center + const Offset(0, 20),
      center + const Offset(0, 34),
      _stroke(_mute, 1.4),
    );
  }

  void _drawHoldStill(Canvas c, double h) {
    final cy = h / 2 + 2;
    // open palm-up hand holding a flat phone (seen from above)
    _hand(c, Offset(50, cy + 6), 30, openness: 0.9);
    final phone = Rect.fromCenter(
      center: Offset(50, cy - 2),
      width: 30,
      height: 44,
    );
    _phone(c, phone);
    // stillness rings
    c.drawCircle(
      Offset(50, cy - 2),
      30,
      _stroke(_green.withValues(alpha: 0.5), 1.6),
    );
    c.drawCircle(
      Offset(50, cy - 2),
      38,
      _stroke(_green.withValues(alpha: 0.25), 1.6),
    );
    _check(c, Offset(78, h * 0.22), 8);
  }

  void _drawCountdown(Canvas c, double h) {
    final center = Offset(50, h / 2);
    c.drawCircle(center, 32, _stroke(_mute, 3));
    c.drawArc(
      Rect.fromCircle(center: center, radius: 32),
      -math.pi / 2,
      math.pi * 1.4,
      false,
      _stroke(_teal, 4),
    );
    _label(c, '3·2·1', center, size: 13, color: _teal);
    // ticks
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      c.drawLine(
        center + Offset.fromDirection(a, 36),
        center + Offset.fromDirection(a, 40),
        _stroke(_mute, 1.6),
      );
    }
  }

  void _drawSwitchHands(Canvas c, double h) {
    final cy = h / 2 + 6;
    _hand(c, Offset(27, cy), 22, openness: 0.9);
    _hand(c, Offset(73, cy), 22, openness: 0.9, left: true);
    _arcArrow(
      c,
      Offset(50, cy + 6),
      26,
      math.pi * 1.2,
      math.pi * 0.6,
      width: 2.8,
    );
  }

  void _drawSingleHand(Canvas c, double h, {required bool left}) {
    final cy = h / 2 + 4;
    _hand(c, Offset(50, cy), 32, openness: 0.9, left: left);
    final badge = Offset(left ? 20 : 80, h * 0.2);
    c.drawCircle(badge, 9, _fill(_teal));
    _label(c, left ? 'L' : 'R', badge, size: 10, color: Colors.white);
  }

  void _drawRestartHand(Canvas c, double h) {
    final cy = h / 2 + 4;
    _hand(c, Offset(44, cy), 28, openness: 0.9);
    _arcArrow(
      c,
      Offset(78, h * 0.3),
      11,
      -math.pi * 0.3,
      math.pi * 1.5,
      color: _amber,
      width: 2.8,
    );
  }

  void _drawLightEven(Canvas c, double h) {
    // light source top-left with rays, hand lit below
    final src = Offset(24, h * 0.22);
    c.drawCircle(src, 9, _fill(const Color(0xFFFACC15)));
    c.drawCircle(src, 9, _stroke(_amber, 1.6));
    for (var i = 0; i < 5; i++) {
      final a = -0.2 + i * 0.35;
      c.drawLine(
        src + Offset.fromDirection(a, 13),
        src + Offset.fromDirection(a, 22),
        _stroke(_amber, 2),
      );
    }
    _hand(c, Offset(62, h * 0.62), 26, openness: 0.85);
    // crossed-out window behind
    final win = Rect.fromLTWH(74, h * 0.1, 18, 18);
    c.drawRect(win, _stroke(_mute, 1.6));
    c.drawLine(
      win.center + const Offset(-9, 0),
      win.center + const Offset(9, 0),
      _stroke(_mute, 1.2),
    );
    c.drawLine(
      win.center + const Offset(0, -9),
      win.center + const Offset(0, 9),
      _stroke(_mute, 1.2),
    );
    c.drawLine(
      win.topLeft,
      win.bottomRight,
      _stroke(const Color(0xFFDC2626), 2.2),
    );
  }

  void _drawPhoneStand(Canvas c, double h) {
    final floorY = h * 0.84;
    _floor(c, floorY, x0: 14, x1: 86);
    // wedge stand
    final stand = Path()
      ..moveTo(40, floorY)
      ..lineTo(64, floorY)
      ..lineTo(58, floorY - 16)
      ..lineTo(44, floorY - 14)
      ..close();
    c.drawPath(stand, _fill(_mute));
    // phone leaning on it
    c.save();
    c.translate(50, floorY - 20);
    c.rotate(-0.12);
    _phone(c, const Rect.fromLTWH(-11, -26, 22, 44));
    c.restore();
    // eye-level dashed line and an eye glyph
    final eyeY = floorY - 40;
    _dashedLine(c, Offset(16, eyeY), Offset(36, eyeY), _stroke(_teal, 1.6));
    c.drawOval(
      Rect.fromCenter(center: Offset(22, eyeY - 8), width: 14, height: 8),
      _stroke(_ink, 1.6),
    );
    c.drawCircle(Offset(22, eyeY - 8), 2.4, _fill(_ink));
  }

  @override
  bool shouldRepaint(covariant _MovementPainter old) => old.kind != kind;
}
