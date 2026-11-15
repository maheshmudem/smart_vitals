import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'anaemia_ui_kit.dart';

/// Vector instruction drawings for the lower-eyelid photo flow. Drawn in
/// code (no asset files) so they ship with the app and can later be replaced
/// by illustrated PNGs through an `assets:` section.
enum EyelidIllustration {
  pullLidDown,
  lookUp,
  phoneDistanceFlash,
  colourCardBesideEye,
  holdStill,
  goodExample,
  glareExample,
  blurryExample,
}

class EyelidIllustrationView extends StatelessWidget {
  const EyelidIllustrationView({
    super.key,
    required this.kind,
    this.size = 96,
    this.background = const Color(0xFFF1F5F9),
  });

  final EyelidIllustration kind;
  final double size;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Container(
        width: size,
        height: size,
        color: background,
        child: CustomPaint(painter: _EyelidIllustrationPainter(kind)),
      ),
    );
  }
}

class _EyelidIllustrationPainter extends CustomPainter {
  const _EyelidIllustrationPainter(this.kind);

  final EyelidIllustration kind;

  static const Color _skin = Color(0xFFF3CDA9);
  static const Color _skinLine = Color(0xFFC98A5B);
  static const Color _ink = Color(0xFF1E293B);
  static const Color _iris = Color(0xFF3F6E8C);
  static const Color _pink = AnaemiaUi.conjunctivaPink;
  static const Color _pinkDark = Color(0xFFD95A6E);

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case EyelidIllustration.pullLidDown:
        _paintPulledEye(canvas, size, pulled: true, finger: true);
        _arrow(
          canvas,
          Offset(size.width * 0.82, size.height * 0.40),
          Offset(size.width * 0.82, size.height * 0.66),
          AnaemiaUi.primary,
        );
      case EyelidIllustration.lookUp:
        _paintPulledEye(canvas, size, pulled: true, finger: true, irisUp: true);
        _arrow(
          canvas,
          Offset(size.width * 0.82, size.height * 0.52),
          Offset(size.width * 0.82, size.height * 0.24),
          AnaemiaUi.primary,
        );
      case EyelidIllustration.phoneDistanceFlash:
        _paintPhoneDistance(canvas, size);
      case EyelidIllustration.colourCardBesideEye:
        _paintEyeWithCard(canvas, size);
      case EyelidIllustration.holdStill:
        _paintHoldStill(canvas, size);
      case EyelidIllustration.goodExample:
        _paintPulledEye(canvas, size, pulled: true, finger: true);
        _badge(canvas, size, Icons.check_rounded, const Color(0xFF15803D));
      case EyelidIllustration.glareExample:
        _paintPulledEye(canvas, size, pulled: true, finger: true);
        final glare = Paint()..color = Colors.white;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * 0.50, size.height * 0.60),
            width: size.width * 0.26,
            height: size.height * 0.10,
          ),
          glare,
        );
        _badge(
          canvas,
          size,
          Icons.priority_high_rounded,
          const Color(0xFFB45309),
        );
      case EyelidIllustration.blurryExample:
        canvas.saveLayer(Offset.zero & size, Paint());
        _paintPulledEye(
          canvas,
          size,
          pulled: true,
          finger: true,
          blur: size.width * 0.03,
        );
        canvas.restore();
        _badge(
          canvas,
          size,
          Icons.priority_high_rounded,
          const Color(0xFFB45309),
        );
    }
  }

  // --- helpers -----------------------------------------------------------

  void _paintPulledEye(
    Canvas canvas,
    Size size, {
    required bool pulled,
    required bool finger,
    bool irisUp = false,
    double blur = 0,
  }) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.46;
    final cy = h * 0.42;
    final eyeW = w * 0.56;
    final eyeH = h * 0.26;

    final maskPaint = blur > 0
        ? (Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, blur))
        : null;
    if (maskPaint != null) {
      canvas.saveLayer(Offset.zero & size, maskPaint);
    }

    // Sclera (upper lid arc + a flatter lower arc)
    final sclera = Path()
      ..moveTo(cx - eyeW / 2, cy)
      ..quadraticBezierTo(cx, cy - eyeH * 1.15, cx + eyeW / 2, cy)
      ..quadraticBezierTo(cx, cy + eyeH * 0.55, cx - eyeW / 2, cy)
      ..close();
    canvas.drawPath(sclera, Paint()..color = Colors.white);

    // Iris + pupil (clipped to sclera)
    canvas.save();
    canvas.clipPath(sclera);
    final irisCenter = Offset(cx, irisUp ? cy - eyeH * 0.42 : cy - eyeH * 0.12);
    canvas.drawCircle(irisCenter, eyeH * 0.52, Paint()..color = _iris);
    canvas.drawCircle(irisCenter, eyeH * 0.24, Paint()..color = _ink);
    canvas.drawCircle(
      irisCenter + Offset(-eyeH * 0.14, -eyeH * 0.16),
      eyeH * 0.08,
      Paint()..color = Colors.white,
    );
    canvas.restore();

    // Upper lid line
    final lidStroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, w * 0.022)
      ..strokeCap = StrokeCap.round;
    final upper = Path()
      ..moveTo(cx - eyeW / 2, cy)
      ..quadraticBezierTo(cx, cy - eyeH * 1.15, cx + eyeW / 2, cy);
    canvas.drawPath(upper, lidStroke);

    if (pulled) {
      // Pulled-down lower lid: pink conjunctiva band between the natural
      // lower arc and the pulled arc.
      final conj = Path()
        ..moveTo(cx - eyeW / 2, cy)
        ..quadraticBezierTo(cx, cy + eyeH * 0.55, cx + eyeW / 2, cy)
        ..quadraticBezierTo(cx, cy + eyeH * 1.45, cx - eyeW / 2, cy)
        ..close();
      canvas.drawPath(conj, Paint()..color = _pink);
      // Micro-vessels
      final vessel = Paint()
        ..color = _pinkDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.01);
      for (var i = -2; i <= 2; i++) {
        final x = cx + i * eyeW * 0.14;
        canvas.drawLine(
          Offset(x, cy + eyeH * 0.42),
          Offset(x + eyeW * 0.03, cy + eyeH * 0.95),
          vessel,
        );
      }
      final lower = Path()
        ..moveTo(cx - eyeW / 2, cy)
        ..quadraticBezierTo(cx, cy + eyeH * 1.45, cx + eyeW / 2, cy);
      canvas.drawPath(lower, lidStroke);
    } else {
      final lower = Path()
        ..moveTo(cx - eyeW / 2, cy)
        ..quadraticBezierTo(cx, cy + eyeH * 0.55, cx + eyeW / 2, cy);
      canvas.drawPath(lower, lidStroke);
    }

    if (finger) {
      // Finger tip coming from below, pressing the lower lid down.
      final fingerRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cx - eyeW * 0.16,
          cy + eyeH * 1.05,
          eyeW * 0.30,
          h * 0.60,
        ),
        Radius.circular(eyeW * 0.15),
      );
      canvas.drawRRect(fingerRect, Paint()..color = _skin);
      canvas.drawRRect(
        fingerRect,
        Paint()
          ..color = _skinLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, w * 0.016),
      );
      // Nail
      canvas.drawOval(
        Rect.fromLTWH(
          cx - eyeW * 0.09,
          cy + eyeH * 1.18,
          eyeW * 0.16,
          h * 0.10,
        ),
        Paint()..color = const Color(0xFFFBE4D6),
      );
    }

    if (maskPaint != null) canvas.restore();
  }

  void _paintPhoneDistance(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Head profile (left)
    final headCenter = Offset(w * 0.24, h * 0.50);
    canvas.drawCircle(headCenter, w * 0.17, Paint()..color = _skin);
    canvas.drawCircle(
      headCenter,
      w * 0.17,
      Paint()
        ..color = _skinLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, w * 0.016),
    );
    // Nose bump + eye
    final nose = Path()
      ..moveTo(headCenter.dx + w * 0.15, headCenter.dy - h * 0.02)
      ..lineTo(headCenter.dx + w * 0.21, headCenter.dy + h * 0.04)
      ..lineTo(headCenter.dx + w * 0.15, headCenter.dy + h * 0.07);
    canvas.drawPath(nose, Paint()..color = _skin);
    canvas.drawPath(
      nose,
      Paint()
        ..color = _skinLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.014),
    );
    canvas.drawCircle(
      Offset(headCenter.dx + w * 0.09, headCenter.dy - h * 0.05),
      w * 0.022,
      Paint()..color = _ink,
    );
    // Phone (right)
    final phone = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.70, h * 0.22, w * 0.16, h * 0.56),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(phone, Paint()..color = _ink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.72, h * 0.26, w * 0.12, h * 0.48),
        Radius.circular(w * 0.02),
      ),
      Paint()..color = const Color(0xFF334155),
    );
    // Flash burst
    final flash = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, w * 0.02)
      ..strokeCap = StrokeCap.round;
    final fc = Offset(w * 0.69, h * 0.30);
    for (var i = 0; i < 5; i++) {
      final a = math.pi * (0.75 + i * 0.125);
      canvas.drawLine(
        fc + Offset(math.cos(a), math.sin(a)) * w * 0.05,
        fc + Offset(math.cos(a), math.sin(a)) * w * 0.11,
        flash,
      );
    }
    // Dashed distance line + label
    final dash = Paint()
      ..color = AnaemiaUi.primary
      ..strokeWidth = math.max(1.2, w * 0.016);
    final y = h * 0.86;
    var x = w * 0.42;
    while (x < w * 0.68) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + w * 0.04, w * 0.68), y),
        dash,
      );
      x += w * 0.07;
    }
    _text(
      canvas,
      '15–20 cm',
      Offset(w * 0.55, h * 0.72),
      w * 0.11,
      AnaemiaUi.primary,
    );
  }

  void _paintEyeWithCard(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(-w * 0.16, 0);
    _paintPulledEye(canvas, Size(w * 0.92, h), pulled: true, finger: false);
    canvas.restore();
    // 24-patch card (6×4) with white border
    final cardRect = Rect.fromLTWH(w * 0.58, h * 0.24, w * 0.36, h * 0.30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cardRect.inflate(w * 0.02),
        Radius.circular(w * 0.02),
      ),
      Paint()..color = Colors.white,
    );
    const colours = [
      Color(0xFF735244),
      Color(0xFFC29682),
      Color(0xFF627A9D),
      Color(0xFF576C43),
      Color(0xFF8580B1),
      Color(0xFF67BDAA),
      Color(0xFFD67E2C),
      Color(0xFF505BA6),
      Color(0xFFC15A63),
      Color(0xFF5E3C6C),
      Color(0xFF9DBC40),
      Color(0xFFE0A32E),
      Color(0xFF383D96),
      Color(0xFF469449),
      Color(0xFFAF363C),
      Color(0xFFE7C71F),
      Color(0xFFBB5695),
      Color(0xFF0885A1),
      Color(0xFFF3F3F2),
      Color(0xFFC8C8C8),
      Color(0xFFA0A0A0),
      Color(0xFF7A7A79),
      Color(0xFF555555),
      Color(0xFF343434),
    ];
    final pw = cardRect.width / 6;
    final ph = cardRect.height / 4;
    for (var i = 0; i < 24; i++) {
      final r = Rect.fromLTWH(
        cardRect.left + (i % 6) * pw,
        cardRect.top + (i ~/ 6) * ph,
        pw,
        ph,
      ).deflate(w * 0.004);
      canvas.drawRect(r, Paint()..color = colours[i]);
    }
    _text(canvas, '24-patch card', Offset(w * 0.76, h * 0.64), w * 0.085, _ink);
  }

  void _paintHoldStill(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(0, -h * 0.04);
    _paintPulledEye(canvas, size, pulled: true, finger: false);
    canvas.restore();
    // Corner brackets
    final br = Paint()
      ..color = AnaemiaUi.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, w * 0.024)
      ..strokeCap = StrokeCap.round;
    final frame = Rect.fromLTWH(w * 0.10, h * 0.12, w * 0.74, h * 0.56);
    final l = w * 0.10;
    void corner(Offset c, int sx, int sy) {
      canvas.drawLine(c, c + Offset(l * sx, 0), br);
      canvas.drawLine(c, c + Offset(0, l * sy), br);
    }

    corner(frame.topLeft, 1, 1);
    corner(frame.topRight, -1, 1);
    corner(frame.bottomLeft, 1, -1);
    corner(frame.bottomRight, -1, -1);
    // Timer ring
    final ringCenter = Offset(w * 0.50, h * 0.84);
    canvas.drawCircle(
      ringCenter,
      w * 0.075,
      Paint()
        ..color = AnaemiaUi.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, w * 0.024),
    );
    canvas.drawArc(
      Rect.fromCircle(center: ringCenter, radius: w * 0.075),
      -math.pi / 2,
      math.pi * 1.4,
      false,
      br,
    );
    _text(
      canvas,
      '2 s',
      Offset(w * 0.66, h * 0.84),
      w * 0.10,
      AnaemiaUi.primary,
    );
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, p);
    final dir = (to - from);
    final len = dir.distance;
    if (len == 0) return;
    final u = dir / len;
    final n = Offset(-u.dy, u.dx);
    canvas.drawLine(to, to - u * 6 + n * 5, p);
    canvas.drawLine(to, to - u * 6 - n * 5, p);
  }

  void _badge(Canvas canvas, Size size, IconData icon, Color color) {
    final c = Offset(size.width * 0.84, size.height * 0.18);
    canvas.drawCircle(c, size.width * 0.11, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size.width * 0.15,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  void _text(
    Canvas canvas,
    String s,
    Offset center,
    double fontSize,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _EyelidIllustrationPainter old) =>
      old.kind != kind;
}

/// Live camera overlay for S-E03: dark scrim with a clear 4:3 window, an
/// almond eye outline with the lower-lid band highlighted, corner brackets
/// whose colour follows the live quality state, and a 2 s hold ring.
class EyelidGuidePainter extends CustomPainter {
  const EyelidGuidePainter({
    required this.strokeColor,
    required this.holdProgress,
    required this.pulse,
    required this.captured,
  });

  final Color strokeColor;

  /// 0..1 — fraction of the 2 s continuous-pass window (ALG-CAP auto-capture).
  final double holdProgress;

  /// 0..1 looping phase for the gentle breathing of the guide.
  final double pulse;
  final bool captured;

  static Rect windowFor(Size size) {
    final w = size.width * 0.86;
    final h = w * 3 / 4;
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final window = windowFor(size);
    final rr = RRect.fromRectAndRadius(window, const Radius.circular(22));

    // Scrim outside the window
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rr)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Window edge
    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Corner brackets
    final br = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const l = 26.0;
    void corner(Offset c, int sx, int sy) {
      canvas.drawLine(c + Offset(0, 10.0 * sy), c + Offset(0, l * sy), br);
      canvas.drawLine(c + Offset(10.0 * sx, 0), c + Offset(l * sx, 0), br);
    }

    corner(window.topLeft, 1, 1);
    corner(window.topRight, -1, 1);
    corner(window.bottomLeft, 1, -1);
    corner(window.bottomRight, -1, -1);

    // Eye guide (dashed almond) — breathing ±2 %
    final breathe = 1.0 + 0.02 * math.sin(pulse * 2 * math.pi);
    final eyeW = window.width * 0.66 * breathe;
    final eyeH = window.height * 0.34 * breathe;
    final cx = window.center.dx;
    final cy = window.center.dy - window.height * 0.06;
    final upper = Path()
      ..moveTo(cx - eyeW / 2, cy)
      ..quadraticBezierTo(cx, cy - eyeH * 1.05, cx + eyeW / 2, cy);
    final lowerNatural = Path()
      ..moveTo(cx - eyeW / 2, cy)
      ..quadraticBezierTo(cx, cy + eyeH * 0.45, cx + eyeW / 2, cy);
    final lowerPulled = Path()
      ..moveTo(cx - eyeW / 2, cy)
      ..quadraticBezierTo(cx, cy + eyeH * 1.30, cx + eyeW / 2, cy);

    final guide = Paint()
      ..color = strokeColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    _drawDashed(canvas, upper, guide, 10, 7);
    _drawDashed(canvas, lowerNatural, guide..strokeWidth = 1.2, 6, 6);

    // Lower-lid target band (where the pink conjunctiva should sit)
    final band = Path()
      ..addPath(lowerNatural, Offset.zero)
      ..addPath(
        Path()
          ..moveTo(cx + eyeW / 2, cy)
          ..quadraticBezierTo(cx, cy + eyeH * 1.30, cx - eyeW / 2, cy),
        Offset.zero,
      );
    canvas.drawPath(
      band,
      Paint()
        ..color = AnaemiaUi.conjunctivaPink.withValues(
          alpha: captured ? 0.18 : 0.26,
        ),
    );
    _drawDashed(canvas, lowerPulled, guide..strokeWidth = 2.2, 10, 7);

    // Hold ring along the window border (progress)
    if (holdProgress > 0) {
      final ring = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      final ringPath = Path()..addRRect(rr);
      final metrics = ringPath.computeMetrics().first;
      final extract = metrics.extractPath(
        0,
        metrics.length * holdProgress.clamp(0.0, 1.0),
      );
      canvas.drawPath(extract, ring);
    }

    if (captured) {
      canvas.drawRRect(
        rr,
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
    }
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint,
    double dash,
    double gap,
  ) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant EyelidGuidePainter old) =>
      old.strokeColor != strokeColor ||
      old.holdProgress != holdProgress ||
      old.pulse != pulse ||
      old.captured != captured;
}
