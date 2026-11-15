import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/algorithms/photo_quality_analyzer.dart'
    show PhotoTarget;
import '../../core/domain/entities/eye_photo_protocol.dart';
import '../anaemia/anaemia_ui_kit.dart';

/// Vector instruction drawings for the sclera / lens / child-eye / fundus
/// flows. Drawn in code (no asset files) so they ship with the app and can
/// later be swapped for illustrated PNGs through an `assets:` section.
class EyeIllustrationView extends StatelessWidget {
  const EyeIllustrationView({
    super.key,
    required this.kind,
    this.size = 96,
    this.background,
  });

  final EyeIllustration kind;
  final double size;
  final Color? background;

  static bool _isDark(EyeIllustration k) => const {
    EyeIllustration.dimRoom,
    EyeIllustration.redReflexNormal,
    EyeIllustration.redReflexAsymmetric,
    EyeIllustration.whitePupilExample,
    EyeIllustration.childLookAtLight,
    EyeIllustration.fundusMaculaExample,
    EyeIllustration.fundusDiscExample,
    EyeIllustration.fundusFixation,
    EyeIllustration.daylightWindow,
  }.contains(k);

  @override
  Widget build(BuildContext context) {
    final bg =
        background ??
        (_isDark(kind) ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Container(
        width: size,
        height: size,
        color: bg,
        child: CustomPaint(painter: _EyeIllustrationPainter(kind)),
      ),
    );
  }
}

class _EyeIllustrationPainter extends CustomPainter {
  const _EyeIllustrationPainter(this.kind);

  final EyeIllustration kind;

  static const Color _skin = Color(0xFFF3CDA9);
  static const Color _skinLine = Color(0xFFC98A5B);
  static const Color _ink = Color(0xFF1E293B);
  static const Color _iris = Color(0xFF3F6E8C);
  static const Color _green = Color(0xFF15803D);
  static const Color _amber = Color(0xFFB45309);
  static const Color _red = Color(0xFFB91C1C);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case EyeIllustration.lookUp:
        _eye(
          canvas,
          Rect.fromLTWH(w * 0.12, h * 0.26, w * 0.60, h * 0.40),
          irisDy: -0.45,
        );
        _arrow(
          canvas,
          Offset(w * 0.84, h * 0.62),
          Offset(w * 0.84, h * 0.26),
          AnaemiaUi.primary,
        );
      case EyeIllustration.lookTowardNose:
        _eye(
          canvas,
          Rect.fromLTWH(w * 0.08, h * 0.26, w * 0.60, h * 0.40),
          irisDx: 0.42,
        );
        // nose silhouette on the right
        final nose = Path()
          ..moveTo(w * 0.80, h * 0.22)
          ..quadraticBezierTo(w * 0.92, h * 0.50, w * 0.78, h * 0.68);
        canvas.drawPath(
          nose,
          Paint()
            ..color = _skinLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.4, w * 0.02)
            ..strokeCap = StrokeCap.round,
        );
        _arrow(
          canvas,
          Offset(w * 0.38, h * 0.82),
          Offset(w * 0.66, h * 0.82),
          AnaemiaUi.primary,
        );
      case EyeIllustration.cardBesideEye:
        _eye(canvas, Rect.fromLTWH(w * 0.04, h * 0.28, w * 0.52, h * 0.36));
        _card(canvas, Rect.fromLTWH(w * 0.62, h * 0.26, w * 0.32, h * 0.26));
        _text(canvas, '24-patch', Offset(w * 0.78, h * 0.62), w * 0.09, _ink);
      case EyeIllustration.scleraGoodExample:
        _eye(
          canvas,
          Rect.fromLTWH(w * 0.06, h * 0.30, w * 0.56, h * 0.36),
          irisDy: -0.4,
        );
        _card(canvas, Rect.fromLTWH(w * 0.68, h * 0.36, w * 0.24, h * 0.20));
        _badge(canvas, size, Icons.check_rounded, _green);
      case EyeIllustration.scleraYellowExample:
        _eye(
          canvas,
          Rect.fromLTWH(w * 0.12, h * 0.30, w * 0.62, h * 0.38),
          irisDy: -0.4,
          sclera: const Color(0xFFF3DC7A),
        );
        _badge(canvas, size, Icons.priority_high_rounded, _amber);
      case EyeIllustration.pupilCentred:
        _eye(
          canvas,
          Rect.fromLTWH(w * 0.06, h * 0.22, w * 0.88, h * 0.56),
          irisScale: 1.25,
          flashDot: true,
        );
        _dashedCircle(
          canvas,
          Offset(w * 0.50, h * 0.50),
          w * 0.19,
          AnaemiaUi.primary,
          w * 0.022,
        );
      case EyeIllustration.dimRoom:
        _dimRoom(canvas, size);
      case EyeIllustration.clearLensExample:
        _eye(
          canvas,
          Rect.fromLTWH(w * 0.06, h * 0.24, w * 0.88, h * 0.56),
          irisScale: 1.25,
          flashDot: true,
        );
        _badge(canvas, size, Icons.check_rounded, _green);
      case EyeIllustration.cloudyLensExample:
        _eye(
          canvas,
          Rect.fromLTWH(w * 0.06, h * 0.24, w * 0.88, h * 0.56),
          irisScale: 1.25,
          flashDot: true,
          pupil: const Color(0xFFB8C2CF),
        );
        _badge(canvas, size, Icons.priority_high_rounded, _amber);
      case EyeIllustration.childDistance:
        _childDistance(canvas, size);
      case EyeIllustration.childLookAtLight:
        _face(
          canvas,
          Offset(w * 0.50, h * 0.62),
          w * 0.26,
          pupilL: _red,
          pupilR: _red,
          dots: true,
        );
        _phoneTop(canvas, size);
      case EyeIllustration.redReflexNormal:
        _face(
          canvas,
          Offset(w * 0.50, h * 0.52),
          w * 0.34,
          pupilL: _red,
          pupilR: _red,
          dots: true,
        );
        _badge(canvas, size, Icons.check_rounded, _green);
      case EyeIllustration.redReflexAsymmetric:
        _face(
          canvas,
          Offset(w * 0.50, h * 0.52),
          w * 0.34,
          pupilL: const Color(0xFF5B1A1A),
          pupilR: _red,
          dots: true,
          dotOffsetL: 0.45,
        );
        _badge(canvas, size, Icons.priority_high_rounded, _amber);
      case EyeIllustration.whitePupilExample:
        _face(
          canvas,
          Offset(w * 0.50, h * 0.52),
          w * 0.34,
          pupilL: const Color(0xFFF8FAFC),
          pupilR: _red,
          dots: true,
        );
        _badge(canvas, size, Icons.priority_high_rounded, _red);
      case EyeIllustration.fundusClipOn:
        _clipOn(canvas, size);
      case EyeIllustration.fundusFixation:
        _fundusFixation(canvas, size);
      case EyeIllustration.fundusMaculaExample:
        _fundus(
          canvas,
          Offset(w * 0.50, h * 0.50),
          w * 0.40,
          discCentred: false,
        );
        _badge(canvas, size, Icons.check_rounded, _green);
      case EyeIllustration.fundusDiscExample:
        _fundus(
          canvas,
          Offset(w * 0.50, h * 0.50),
          w * 0.40,
          discCentred: true,
        );
        _badge(canvas, size, Icons.check_rounded, _green);
      case EyeIllustration.phoneDistanceFlash:
        _phoneDistance(canvas, size);
      case EyeIllustration.holdStill:
        _holdStill(canvas, size);
      case EyeIllustration.glassesOff:
        _glassesOff(canvas, size);
      case EyeIllustration.glareExample:
        _eye(canvas, Rect.fromLTWH(w * 0.10, h * 0.28, w * 0.66, h * 0.40));
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.46, h * 0.44),
            width: w * 0.22,
            height: h * 0.09,
          ),
          Paint()..color = Colors.white,
        );
        _badge(canvas, size, Icons.priority_high_rounded, _amber);
      case EyeIllustration.blurryExample:
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.03),
        );
        _eye(canvas, Rect.fromLTWH(w * 0.10, h * 0.28, w * 0.66, h * 0.40));
        canvas.restore();
        _badge(canvas, size, Icons.priority_high_rounded, _amber);
      default:
        _BodyIllustrationPainter.paintKind(canvas, size, kind);
    }
  }

  // --- primitives ---------------------------------------------------------

  /// Almond eye inside [r]. `irisDx`/`irisDy` are fractions of the eye size.
  void _eye(
    Canvas canvas,
    Rect r, {
    double irisDx = 0,
    double irisDy = 0,
    double irisScale = 1,
    Color sclera = Colors.white,
    Color pupil = _ink,
    bool flashDot = false,
  }) {
    final cx = r.center.dx;
    final cy = r.center.dy;
    final eyeW = r.width;
    final eyeH = r.height;
    final shape = Path()
      ..moveTo(cx - eyeW / 2, cy)
      ..quadraticBezierTo(cx, cy - eyeH * 1.1, cx + eyeW / 2, cy)
      ..quadraticBezierTo(cx, cy + eyeH * 1.1, cx - eyeW / 2, cy)
      ..close();
    canvas.drawPath(shape, Paint()..color = sclera);
    canvas.save();
    canvas.clipPath(shape);
    final ic = Offset(cx + irisDx * eyeW * 0.5, cy + irisDy * eyeH * 0.9);
    final irisR = eyeH * 0.55 * irisScale;
    canvas.drawCircle(ic, irisR, Paint()..color = _iris);
    canvas.drawCircle(ic, irisR * 0.48, Paint()..color = pupil);
    if (flashDot) {
      canvas.drawCircle(
        ic + Offset(-irisR * 0.22, -irisR * 0.26),
        irisR * 0.13,
        Paint()..color = Colors.white,
      );
    } else {
      canvas.drawCircle(
        ic + Offset(-irisR * 0.25, -irisR * 0.3),
        irisR * 0.12,
        Paint()..color = Colors.white,
      );
    }
    canvas.restore();
    canvas.drawPath(
      shape,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, eyeW * 0.03)
        ..strokeJoin = StrokeJoin.round,
    );
    // lashes hint
    final lash = Paint()
      ..color = _ink
      ..strokeWidth = math.max(1.0, eyeW * 0.02)
      ..strokeCap = StrokeCap.round;
    for (var i = -1; i <= 1; i++) {
      final x = cx + i * eyeW * 0.22;
      canvas.drawLine(
        Offset(x, cy - eyeH * 0.95),
        Offset(x + eyeW * 0.02, cy - eyeH * 1.15),
        lash,
      );
    }
  }

  void _face(
    Canvas canvas,
    Offset c,
    double r, {
    required Color pupilL,
    required Color pupilR,
    bool dots = false,
    double dotOffsetL = 0,
  }) {
    canvas.drawCircle(c, r, Paint()..color = _skin);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _skinLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, r * 0.05),
    );
    // hair cap
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      math.pi * 1.05,
      math.pi * 0.9,
      false,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.22,
    );
    // smile
    canvas.drawArc(
      Rect.fromCircle(center: c + Offset(0, r * 0.25), radius: r * 0.35),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      Paint()
        ..color = _skinLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, r * 0.05)
        ..strokeCap = StrokeCap.round,
    );
    void eye(Offset ec, Color pupil, double dotOffset) {
      final ew = r * 0.52;
      final eh = r * 0.17;
      final shape = Path()
        ..moveTo(ec.dx - ew / 2, ec.dy)
        ..quadraticBezierTo(ec.dx, ec.dy - eh * 1.3, ec.dx + ew / 2, ec.dy)
        ..quadraticBezierTo(ec.dx, ec.dy + eh * 1.3, ec.dx - ew / 2, ec.dy)
        ..close();
      canvas.drawPath(shape, Paint()..color = Colors.white);
      canvas.save();
      canvas.clipPath(shape);
      canvas.drawCircle(ec, eh * 0.95, Paint()..color = _iris);
      canvas.drawCircle(ec, eh * 0.55, Paint()..color = pupil);
      if (dots) {
        canvas.drawCircle(
          ec + Offset(eh * 0.55 * dotOffset, -eh * 0.1),
          eh * 0.18,
          Paint()..color = Colors.white,
        );
      }
      canvas.restore();
      canvas.drawPath(
        shape,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, r * 0.04),
      );
    }

    eye(c + Offset(-r * 0.38, -r * 0.12), pupilL, dotOffsetL);
    eye(c + Offset(r * 0.38, -r * 0.12), pupilR, 0);
  }

  void _phone(Canvas canvas, Rect r, {bool flash = false, bool lens = true}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.22)),
      Paint()..color = _ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r.deflate(r.width * 0.12),
        Radius.circular(r.width * 0.12),
      ),
      Paint()..color = const Color(0xFF334155),
    );
    if (lens) {
      canvas.drawCircle(
        Offset(r.left + r.width * 0.3, r.top + r.height * 0.12),
        r.width * 0.09,
        Paint()..color = const Color(0xFF0EA5E9),
      );
    }
    if (flash) {
      final fc = Offset(r.left - r.width * 0.05, r.top + r.height * 0.12);
      final p = Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = math.max(1.4, r.width * 0.12)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final a = math.pi * (0.75 + i * 0.125);
        canvas.drawLine(
          fc + Offset(math.cos(a), math.sin(a)) * r.width * 0.3,
          fc + Offset(math.cos(a), math.sin(a)) * r.width * 0.7,
          p,
        );
      }
    }
  }

  void _card(Canvas canvas, Rect cardRect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cardRect.inflate(cardRect.width * 0.06),
        Radius.circular(cardRect.width * 0.06),
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
      ).deflate(pw * 0.08);
      canvas.drawRect(r, Paint()..color = colours[i]);
    }
  }

  void _dimRoom(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // moon
    canvas.drawCircle(
      Offset(w * 0.22, h * 0.22),
      w * 0.10,
      Paint()..color = const Color(0xFFFDE68A),
    );
    canvas.drawCircle(
      Offset(w * 0.26, h * 0.19),
      w * 0.085,
      Paint()..color = const Color(0xFF1E293B),
    );
    // lamp switched off (bulb with cross)
    final bulb = Offset(w * 0.74, h * 0.24);
    canvas.drawCircle(bulb, w * 0.10, Paint()..color = const Color(0xFF475569));
    canvas.drawRect(
      Rect.fromCenter(
        center: bulb + Offset(0, w * 0.13),
        width: w * 0.08,
        height: w * 0.07,
      ),
      Paint()..color = const Color(0xFF475569),
    );
    final x = Paint()
      ..color = const Color(0xFFF87171)
      ..strokeWidth = math.max(1.6, w * 0.03)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      bulb + Offset(-w * 0.07, -w * 0.07),
      bulb + Offset(w * 0.07, w * 0.07),
      x,
    );
    canvas.drawLine(
      bulb + Offset(w * 0.07, -w * 0.07),
      bulb + Offset(-w * 0.07, w * 0.07),
      x,
    );
    // eye with large pupil
    _eye(
      canvas,
      Rect.fromLTWH(w * 0.16, h * 0.54, w * 0.68, h * 0.30),
      irisScale: 1.15,
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.69),
      h * 0.12,
      Paint()..color = _ink,
    );
    _text(
      canvas,
      'lights off',
      Offset(w * 0.50, h * 0.93),
      w * 0.09,
      const Color(0xFFCBD5E1),
    );
  }

  void _childDistance(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // parent (left): head + phone in hand
    canvas.drawCircle(
      Offset(w * 0.18, h * 0.34),
      w * 0.13,
      Paint()..color = _skin,
    );
    canvas.drawCircle(
      Offset(w * 0.18, h * 0.34),
      w * 0.13,
      Paint()
        ..color = _skinLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, w * 0.016),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.50, w * 0.20, h * 0.34),
        Radius.circular(w * 0.06),
      ),
      Paint()..color = const Color(0xFF64748B),
    );
    _phone(
      canvas,
      Rect.fromLTWH(w * 0.30, h * 0.40, w * 0.09, h * 0.20),
      flash: true,
    );
    // child (right), smaller, face front
    _face(
      canvas,
      Offset(w * 0.78, h * 0.50),
      w * 0.15,
      pupilL: _ink,
      pupilR: _ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.68, h * 0.66, w * 0.20, h * 0.22),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = const Color(0xFF0EA5E9),
    );
    // distance line
    final dash = Paint()
      ..color = AnaemiaUi.primary
      ..strokeWidth = math.max(1.2, w * 0.016);
    var x = w * 0.42;
    while (x < w * 0.62) {
      canvas.drawLine(
        Offset(x, h * 0.92),
        Offset(math.min(x + w * 0.04, w * 0.62), h * 0.92),
        dash,
      );
      x += w * 0.07;
    }
    _text(
      canvas,
      '0.5–1 m',
      Offset(w * 0.52, h * 0.80),
      w * 0.10,
      AnaemiaUi.primary,
    );
  }

  void _phoneTop(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = Rect.fromLTWH(w * 0.42, h * 0.04, w * 0.16, h * 0.24);
    canvas.save();
    canvas.translate(r.center.dx, r.center.dy);
    canvas.rotate(math.pi);
    canvas.translate(-r.center.dx, -r.center.dy);
    _phone(canvas, r);
    canvas.restore();
    // light burst below the phone
    final p = Paint()
      ..color = const Color(0xFFFDE68A)
      ..strokeWidth = math.max(1.2, w * 0.02)
      ..strokeCap = StrokeCap.round;
    final fc = Offset(w * 0.50, h * 0.30);
    for (var i = 0; i < 5; i++) {
      final a = math.pi * (0.15 + i * 0.175);
      canvas.drawLine(
        fc + Offset(math.cos(a), math.sin(a)) * w * 0.03,
        fc + Offset(math.cos(a), math.sin(a)) * w * 0.09,
        p,
      );
    }
  }

  void _clipOn(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _phone(
      canvas,
      Rect.fromLTWH(w * 0.36, h * 0.30, w * 0.28, h * 0.60),
      lens: true,
    );
    // clip-on cylinder over the lens
    final cyl = Rect.fromLTWH(w * 0.30, h * 0.10, w * 0.26, h * 0.26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cyl, Radius.circular(w * 0.05)),
      Paint()..color = const Color(0xFF475569),
    );
    canvas.drawCircle(
      Offset(cyl.center.dx, cyl.top + h * 0.02),
      w * 0.10,
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(
      Offset(cyl.center.dx, cyl.top + h * 0.02),
      w * 0.055,
      Paint()..color = const Color(0xFF22C55E),
    );
    // bluetooth / link symbol
    final p = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..strokeWidth = math.max(1.4, w * 0.024)
      ..strokeCap = StrokeCap.round;
    final bx = w * 0.80;
    final by = h * 0.28;
    canvas.drawLine(Offset(bx, by - h * 0.12), Offset(bx, by + h * 0.12), p);
    canvas.drawLine(
      Offset(bx, by - h * 0.12),
      Offset(bx + w * 0.07, by - h * 0.05),
      p,
    );
    canvas.drawLine(
      Offset(bx + w * 0.07, by - h * 0.05),
      Offset(bx - w * 0.07, by + h * 0.06),
      p,
    );
    canvas.drawLine(
      Offset(bx, by + h * 0.12),
      Offset(bx + w * 0.07, by + h * 0.05),
      p,
    );
    canvas.drawLine(
      Offset(bx + w * 0.07, by + h * 0.05),
      Offset(bx - w * 0.07, by - h * 0.06),
      p,
    );
    _text(canvas, 'clip-on', Offset(w * 0.50, h * 0.95), w * 0.09, _ink);
  }

  void _fundusFixation(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // eyepiece circle with green fixation dot and a side dot
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.44),
      w * 0.30,
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.44),
      w * 0.30,
      Paint()
        ..color = const Color(0xFF64748B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, w * 0.03),
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.44),
      w * 0.045,
      Paint()..color = const Color(0xFF22C55E),
    );
    canvas.drawCircle(
      Offset(w * 0.68, h * 0.44),
      w * 0.03,
      Paint()..color = const Color(0xFF22C55E).withValues(alpha: 0.5),
    );
    _text(
      canvas,
      'centre',
      Offset(w * 0.50, h * 0.60),
      w * 0.08,
      const Color(0xFFCBD5E1),
    );
    _text(
      canvas,
      'side',
      Offset(w * 0.72, h * 0.34),
      w * 0.07,
      const Color(0xFFCBD5E1),
    );
    // eye below looking in
    _eye(
      canvas,
      Rect.fromLTWH(w * 0.22, h * 0.80, w * 0.56, h * 0.16),
      irisDy: -0.5,
    );
  }

  void _fundus(Canvas canvas, Offset c, double r, {required bool discCentred}) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFD9772B));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFF2A65A), const Color(0xFFB8521E)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final disc = discCentred ? c : c + Offset(r * 0.55, -r * 0.05);
    final macula = discCentred ? c + Offset(-r * 0.60, r * 0.05) : c;
    // vessels from the disc
    final v = Paint()
      ..color = const Color(0xFF7F1D1D)
      ..strokeWidth = math.max(1.2, r * 0.06)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final a in [0.6, 1.1, 2.0, 2.6, -0.6, -1.1, -2.0, -2.6]) {
      final p = Path()
        ..moveTo(disc.dx, disc.dy)
        ..quadraticBezierTo(
          disc.dx + math.cos(a) * r * 0.5,
          disc.dy + math.sin(a) * r * 0.9,
          disc.dx + math.cos(a) * r * 1.0,
          disc.dy + math.sin(a) * r * 1.1,
        );
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
      canvas.drawPath(p, v);
      canvas.restore();
    }
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(disc, r * 0.18, Paint()..color = const Color(0xFFFCE7B3));
    canvas.drawCircle(disc, r * 0.09, Paint()..color = const Color(0xFFFEF3C7));
    canvas.drawCircle(
      macula,
      r * 0.14,
      Paint()..color = const Color(0xFF9A3412).withValues(alpha: 0.6),
    );
    canvas.drawCircle(
      macula,
      r * 0.05,
      Paint()..color = const Color(0xFF7C2D12),
    );
    canvas.restore();
  }

  void _phoneDistance(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
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
    _phone(
      canvas,
      Rect.fromLTWH(w * 0.70, h * 0.22, w * 0.16, h * 0.56),
      flash: true,
    );
    final dash = Paint()
      ..color = AnaemiaUi.primary
      ..strokeWidth = math.max(1.2, w * 0.016);
    var x = w * 0.44;
    while (x < w * 0.66) {
      canvas.drawLine(
        Offset(x, h * 0.86),
        Offset(math.min(x + w * 0.04, w * 0.66), h * 0.86),
        dash,
      );
      x += w * 0.07;
    }
    _text(
      canvas,
      'flash on',
      Offset(w * 0.55, h * 0.72),
      w * 0.10,
      AnaemiaUi.primary,
    );
  }

  void _holdStill(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _eye(canvas, Rect.fromLTWH(w * 0.18, h * 0.24, w * 0.58, h * 0.32));
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

  void _glassesOff(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, w * 0.03)
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.36, w * 0.30, h * 0.24),
        Radius.circular(w * 0.08),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.58, h * 0.36, w * 0.30, h * 0.24),
        Radius.circular(w * 0.08),
      ),
      p,
    );
    canvas.drawLine(Offset(w * 0.42, h * 0.44), Offset(w * 0.58, h * 0.44), p);
    canvas.drawLine(Offset(w * 0.12, h * 0.42), Offset(w * 0.02, h * 0.36), p);
    canvas.drawLine(Offset(w * 0.88, h * 0.42), Offset(w * 0.98, h * 0.36), p);
    final x = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = math.max(2.0, w * 0.04)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.22, h * 0.20), Offset(w * 0.78, h * 0.78), x);
    _text(canvas, 'glasses off', Offset(w * 0.50, h * 0.90), w * 0.09, _ink);
  }

  void _dashedCircle(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    double stroke,
  ) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    const n = 18;
    for (var i = 0; i < n; i++) {
      final a0 = i * 2 * math.pi / n;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a0,
        math.pi / n,
        false,
        p,
      );
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, p);
    final dir = to - from;
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
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _EyeIllustrationPainter old) => old.kind != kind;
}

/// Drawings for the Skin & Body screens (newborn skin + card, feet, skin
/// lesion). Same flat style as the eye drawings.
class _BodyIllustrationPainter {
  _BodyIllustrationPainter._();

  static const Color _skin = Color(0xFFF3CDA9);
  static const Color _skinDark = Color(0xFFD9A77A);
  static const Color _skinLine = Color(0xFFC98A5B);
  static const Color _ink = Color(0xFF1E293B);
  static const Color _green = Color(0xFF15803D);
  static const Color _amber = Color(0xFFB45309);
  static const Color _red = Color(0xFFB91C1C);
  static const Color _primary = AnaemiaUi.primary;

  static void paintKind(Canvas canvas, Size size, EyeIllustration kind) {
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case EyeIllustration.cardOnChest:
        _babyTorso(canvas, size);
        _card(canvas, Rect.fromLTWH(w * 0.56, h * 0.44, w * 0.30, h * 0.22));
        _dashedRect(
          canvas,
          Rect.fromLTWH(w * 0.22, h * 0.44, w * 0.26, h * 0.22),
          _primary,
          w * 0.018,
        );
        _text(
          canvas,
          'skin · card',
          Offset(w * 0.50, h * 0.78),
          w * 0.085,
          _ink,
        );
      case EyeIllustration.babyOnBack:
        _babyTorso(canvas, size);
        _text(
          canvas,
          'calm, on back',
          Offset(w * 0.50, h * 0.86),
          w * 0.085,
          _ink,
        );
      case EyeIllustration.daylightWindow:
        // window with sun, lamp crossed out
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.10, h * 0.14, w * 0.48, h * 0.50),
            Radius.circular(w * 0.03),
          ),
          Paint()..color = const Color(0xFFBAE6FD),
        );
        final frame = Paint()
          ..color = Colors.white
          ..strokeWidth = math.max(1.5, w * 0.025);
        canvas.drawLine(
          Offset(w * 0.34, h * 0.14),
          Offset(w * 0.34, h * 0.64),
          frame,
        );
        canvas.drawLine(
          Offset(w * 0.10, h * 0.39),
          Offset(w * 0.58, h * 0.39),
          frame,
        );
        canvas.drawCircle(
          Offset(w * 0.24, h * 0.27),
          w * 0.07,
          Paint()..color = const Color(0xFFFDE68A),
        );
        final bulb = Offset(w * 0.78, h * 0.30);
        canvas.drawCircle(
          bulb,
          w * 0.09,
          Paint()..color = const Color(0xFF475569),
        );
        final x = Paint()
          ..color = const Color(0xFFF87171)
          ..strokeWidth = math.max(1.6, w * 0.03)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          bulb + Offset(-w * 0.07, -w * 0.07),
          bulb + Offset(w * 0.07, w * 0.07),
          x,
        );
        canvas.drawLine(
          bulb + Offset(w * 0.07, -w * 0.07),
          bulb + Offset(-w * 0.07, w * 0.07),
          x,
        );
        _text(
          canvas,
          'daylight, no lamps',
          Offset(w * 0.50, h * 0.84),
          w * 0.08,
          const Color(0xFFCBD5E1),
        );
      case EyeIllustration.noFlashLamp:
        canvas.drawCircle(
          Offset(w * 0.5, h * 0.42),
          w * 0.18,
          Paint()..color = const Color(0xFF475569),
        );
        final x = Paint()
          ..color = const Color(0xFFF87171)
          ..strokeWidth = math.max(1.6, w * 0.03)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(w * 0.36, h * 0.28),
          Offset(w * 0.64, h * 0.56),
          x,
        );
        _text(canvas, 'flash off', Offset(w * 0.5, h * 0.80), w * 0.09, _ink);
      case EyeIllustration.wipeCream:
        _babyTorso(canvas, size);
        // cloth
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.52, h * 0.40, w * 0.30, h * 0.20),
            Radius.circular(w * 0.04),
          ),
          Paint()..color = const Color(0xFFE0F2FE),
        );
        _arrow(
          canvas,
          Offset(w * 0.80, h * 0.50),
          Offset(w * 0.60, h * 0.50),
          _primary,
        );
        _text(
          canvas,
          'wipe clean',
          Offset(w * 0.50, h * 0.86),
          w * 0.085,
          _ink,
        );
      case EyeIllustration.footSoleWithCard:
        _footSole(
          canvas,
          Rect.fromLTWH(w * 0.14, h * 0.08, w * 0.42, h * 0.80),
        );
        _card(canvas, Rect.fromLTWH(w * 0.64, h * 0.52, w * 0.26, h * 0.20));
        _text(canvas, 'card', Offset(w * 0.77, h * 0.82), w * 0.085, _ink);
      case EyeIllustration.toesSpread:
        _footSole(
          canvas,
          Rect.fromLTWH(w * 0.18, h * 0.16, w * 0.52, h * 0.82),
          toesOnly: true,
        );
        _arrow(
          canvas,
          Offset(w * 0.80, h * 0.30),
          Offset(w * 0.92, h * 0.22),
          _primary,
        );
        _arrow(
          canvas,
          Offset(w * 0.14, h * 0.30),
          Offset(w * 0.04, h * 0.22),
          _primary,
        );
        _text(
          canvas,
          'spread toes',
          Offset(w * 0.50, h * 0.90),
          w * 0.085,
          _ink,
        );
      case EyeIllustration.helperHoldsFoot:
        // leg from the right resting, phone on the left held by a helper hand
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.56, h * 0.10, w * 0.26, h * 0.48),
            Radius.circular(w * 0.08),
          ),
          Paint()..color = _skin,
        );
        _footSole(
          canvas,
          Rect.fromLTWH(w * 0.50, h * 0.42, w * 0.38, h * 0.50),
          rotate: true,
        );
        _phone(canvas, Rect.fromLTWH(w * 0.14, h * 0.30, w * 0.16, h * 0.34));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.06, h * 0.52, w * 0.22, h * 0.30),
            Radius.circular(w * 0.06),
          ),
          Paint()..color = _skinDark,
        );
        _text(
          canvas,
          '20–30 cm',
          Offset(w * 0.40, h * 0.88),
          w * 0.085,
          _primary,
        );
      case EyeIllustration.footGoodExample:
        _footSole(
          canvas,
          Rect.fromLTWH(w * 0.20, h * 0.10, w * 0.42, h * 0.78),
        );
        _card(canvas, Rect.fromLTWH(w * 0.68, h * 0.58, w * 0.22, h * 0.16));
        _badge(canvas, size, Icons.check_rounded, _green);
      case EyeIllustration.footCallusExample:
        _footSole(
          canvas,
          Rect.fromLTWH(w * 0.24, h * 0.10, w * 0.44, h * 0.80),
        );
        canvas.drawOval(
          Rect.fromLTWH(w * 0.33, h * 0.26, w * 0.14, h * 0.09),
          Paint()..color = const Color(0xFFE7D3A3),
        );
        canvas.drawOval(
          Rect.fromLTWH(w * 0.36, h * 0.72, w * 0.18, h * 0.10),
          Paint()..color = const Color(0xFFE7D3A3),
        );
        final crack = Paint()
          ..color = _skinLine
          ..strokeWidth = math.max(1, w * 0.012);
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            Offset(w * (0.38 + i * 0.05), h * 0.74),
            Offset(w * (0.40 + i * 0.05), h * 0.80),
            crack,
          );
        }
        _badge(canvas, size, Icons.priority_high_rounded, _amber);
      case EyeIllustration.footUlcerExample:
        _footSole(
          canvas,
          Rect.fromLTWH(w * 0.24, h * 0.10, w * 0.44, h * 0.80),
        );
        canvas.drawOval(
          Rect.fromLTWH(w * 0.36, h * 0.66, w * 0.16, h * 0.13),
          Paint()..color = const Color(0xFFF2B5B5),
        );
        canvas.drawOval(
          Rect.fromLTWH(w * 0.39, h * 0.69, w * 0.10, h * 0.08),
          Paint()..color = _red,
        );
        _badge(canvas, size, Icons.priority_high_rounded, _red);
      case EyeIllustration.lesionCentred:
        _skinField(canvas, size);
        _lesion(canvas, Offset(w * 0.50, h * 0.46), w * 0.09, regular: true);
        _dashedCircle(
          canvas,
          Offset(w * 0.50, h * 0.46),
          w * 0.20,
          _primary,
          w * 0.02,
        );
        _text(
          canvas,
          '10–15 cm',
          Offset(w * 0.50, h * 0.86),
          w * 0.085,
          _primary,
        );
      case EyeIllustration.lesionAngled:
        _skinField(canvas, size);
        canvas.save();
        canvas.translate(w * 0.50, h * 0.46);
        canvas.scale(1.0, 0.62);
        _lesion(canvas, Offset.zero, w * 0.10, regular: true);
        canvas.restore();
        _phone(
          canvas,
          Rect.fromLTWH(w * 0.70, h * 0.08, w * 0.12, h * 0.26),
          tilt: -0.5,
        );
        _text(canvas, '~30°', Offset(w * 0.50, h * 0.86), w * 0.085, _primary);
      case EyeIllustration.lesionContextArm:
        // forearm with a spot, phone at distance
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.06, h * 0.36, w * 0.54, h * 0.24),
            Radius.circular(w * 0.10),
          ),
          Paint()..color = _skin,
        );
        _lesion(canvas, Offset(w * 0.36, h * 0.48), w * 0.035, regular: true);
        _phone(canvas, Rect.fromLTWH(w * 0.74, h * 0.26, w * 0.14, h * 0.40));
        _text(
          canvas,
          'arm\'s length',
          Offset(w * 0.50, h * 0.84),
          w * 0.085,
          _primary,
        );
      case EyeIllustration.lesionGoodExample:
        _skinField(canvas, size);
        _lesion(canvas, Offset(w * 0.44, h * 0.50), w * 0.10, regular: true);
        canvas.drawCircle(
          Offset(w * 0.76, h * 0.56),
          w * 0.08,
          Paint()..color = const Color(0xFFD4A017),
        );
        canvas.drawCircle(
          Offset(w * 0.76, h * 0.56),
          w * 0.06,
          Paint()..color = const Color(0xFFE9C55A),
        );
        _badge(canvas, size, Icons.check_rounded, _green);
      case EyeIllustration.lesionHairShadowExample:
        _skinField(canvas, size);
        _lesion(canvas, Offset(w * 0.50, h * 0.50), w * 0.10, regular: true);
        canvas.drawRect(
          Rect.fromLTWH(0, h * 0.50, w, h * 0.5),
          Paint()..color = Colors.black.withValues(alpha: 0.25),
        );
        final hair = Paint()
          ..color = _ink
          ..strokeWidth = math.max(1, w * 0.012)
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(
            Offset(w * (0.30 + i * 0.10), h * 0.30),
            Offset(w * (0.38 + i * 0.10), h * 0.66),
            hair,
          );
        }
        _badge(canvas, size, Icons.priority_high_rounded, _amber);
      case EyeIllustration.abcdeChart:
        _skinField(canvas, size);
        _lesion(canvas, Offset(w * 0.30, h * 0.36), w * 0.09, regular: true);
        _lesion(canvas, Offset(w * 0.68, h * 0.36), w * 0.10, regular: false);
        _text(canvas, 'regular', Offset(w * 0.30, h * 0.60), w * 0.08, _ink);
        _text(canvas, 'ABCDE', Offset(w * 0.68, h * 0.60), w * 0.08, _red);
      case EyeIllustration.coinScale:
        _skinField(canvas, size);
        _lesion(canvas, Offset(w * 0.36, h * 0.48), w * 0.08, regular: true);
        canvas.drawCircle(
          Offset(w * 0.68, h * 0.50),
          w * 0.12,
          Paint()..color = const Color(0xFFD4A017),
        );
        canvas.drawCircle(
          Offset(w * 0.68, h * 0.50),
          w * 0.09,
          Paint()..color = const Color(0xFFE9C55A),
        );
        _text(
          canvas,
          'coin or card',
          Offset(w * 0.50, h * 0.84),
          w * 0.085,
          _ink,
        );
      default:
        _MouthIllustrationPainter.paintKind(canvas, size, kind);
    }
  }

  // --- primitives ----------------------------------------------------------

  static void _babyTorso(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // head (top-left) + torso
    canvas.drawCircle(
      Offset(w * 0.30, h * 0.24),
      w * 0.14,
      Paint()..color = _skin,
    );
    canvas.drawCircle(
      Offset(w * 0.30, h * 0.24),
      w * 0.14,
      Paint()
        ..color = _skinLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, w * 0.016),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.40, w * 0.40, h * 0.36),
        Radius.circular(w * 0.08),
      ),
      Paint()..color = _skin,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.40, w * 0.40, h * 0.36),
        Radius.circular(w * 0.08),
      ),
      Paint()
        ..color = _skinLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, w * 0.016),
    );
    // nappy
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.70, w * 0.40, h * 0.12),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = Colors.white,
    );
    // closed eye + smile
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.27, h * 0.23), radius: w * 0.035),
      0,
      math.pi,
      false,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.014),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.32, h * 0.30), radius: w * 0.03),
      0.2,
      math.pi * 0.7,
      false,
      Paint()
        ..color = _skinLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.014),
    );
  }

  static void _footSole(
    Canvas canvas,
    Rect r, {
    bool toesOnly = false,
    bool rotate = false,
  }) {
    canvas.save();
    if (rotate) {
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(-math.pi / 2);
      canvas.translate(-r.center.dx, -r.center.dy);
    }
    final w = r.width;
    final h = r.height;
    final sole = Path()
      ..moveTo(r.left + w * 0.30, r.top + h * 0.20)
      ..quadraticBezierTo(
        r.left + w * 0.05,
        r.top + h * 0.45,
        r.left + w * 0.22,
        r.top + h * 0.70,
      )
      ..quadraticBezierTo(
        r.left + w * 0.30,
        r.top + h * 1.02,
        r.left + w * 0.62,
        r.top + h * 0.98,
      )
      ..quadraticBezierTo(
        r.left + w * 0.95,
        r.top + h * 0.80,
        r.left + w * 0.86,
        r.top + h * 0.40,
      )
      ..quadraticBezierTo(
        r.left + w * 0.80,
        r.top + h * 0.18,
        r.left + w * 0.58,
        r.top + h * 0.16,
      )
      ..close();
    final fill = Paint()..color = _skin;
    final line = Paint()
      ..color = _skinLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.03);
    if (!toesOnly) {
      canvas.drawPath(sole, fill);
      canvas.drawPath(sole, line);
    }
    // toes
    final toeR = [0.14, 0.11, 0.10, 0.09, 0.085];
    final toeX = [0.26, 0.42, 0.56, 0.68, 0.80];
    final toeY = [0.13, 0.07, 0.08, 0.11, 0.16];
    for (var i = 0; i < 5; i++) {
      final c = Offset(r.left + w * toeX[i], r.top + h * toeY[i]);
      canvas.drawCircle(c, w * toeR[i], fill);
      canvas.drawCircle(c, w * toeR[i], line);
    }
    canvas.restore();
  }

  static void _skinField(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _skin);
    final pore = Paint()..color = _skinDark.withValues(alpha: 0.35);
    for (var i = 0; i < 12; i++) {
      final x = size.width * ((i * 37) % 100) / 100;
      final y = size.height * ((i * 61) % 100) / 100;
      canvas.drawCircle(Offset(x, y), size.width * 0.008, pore);
    }
  }

  static void _lesion(
    Canvas canvas,
    Offset c,
    double r, {
    required bool regular,
  }) {
    if (regular) {
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF6B3F2A));
      canvas.drawCircle(
        c + Offset(-r * 0.3, -r * 0.3),
        r * 0.35,
        Paint()..color = const Color(0xFF7D4B33),
      );
      return;
    }
    final p = Path()
      ..moveTo(c.dx - r, c.dy)
      ..quadraticBezierTo(
        c.dx - r * 0.8,
        c.dy - r * 1.2,
        c.dx + r * 0.1,
        c.dy - r * 0.8,
      )
      ..quadraticBezierTo(
        c.dx + r * 1.2,
        c.dy - r * 0.9,
        c.dx + r * 0.9,
        c.dy + r * 0.2,
      )
      ..quadraticBezierTo(
        c.dx + r * 1.1,
        c.dy + r * 1.1,
        c.dx + r * 0.2,
        c.dy + r * 0.8,
      )
      ..quadraticBezierTo(c.dx - r * 0.5, c.dy + r * 1.2, c.dx - r, c.dy)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFF3B1F14));
    canvas.drawCircle(
      c + Offset(r * 0.3, r * 0.1),
      r * 0.4,
      Paint()..color = const Color(0xFF8B2E2E),
    );
    canvas.drawCircle(
      c + Offset(-r * 0.35, -r * 0.25),
      r * 0.3,
      Paint()..color = const Color(0xFF7D5A3C),
    );
  }

  static void _phone(Canvas canvas, Rect r, {double tilt = 0}) {
    canvas.save();
    if (tilt != 0) {
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(tilt);
      canvas.translate(-r.center.dx, -r.center.dy);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.22)),
      Paint()..color = _ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r.deflate(r.width * 0.12),
        Radius.circular(r.width * 0.12),
      ),
      Paint()..color = const Color(0xFF334155),
    );
    canvas.drawCircle(
      Offset(r.left + r.width * 0.3, r.top + r.height * 0.12),
      r.width * 0.09,
      Paint()..color = const Color(0xFF0EA5E9),
    );
    canvas.restore();
  }

  static void _card(Canvas canvas, Rect cardRect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cardRect.inflate(cardRect.width * 0.06),
        Radius.circular(cardRect.width * 0.06),
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
      final rr = Rect.fromLTWH(
        cardRect.left + (i % 6) * pw,
        cardRect.top + (i ~/ 6) * ph,
        pw,
        ph,
      ).deflate(pw * 0.08);
      canvas.drawRect(rr, Paint()..color = colours[i]);
    }
  }

  static void _dashedRect(Canvas canvas, Rect r, Color color, double stroke) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.1)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), p);
        d += 10;
      }
    }
  }

  static void _dashedCircle(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    double stroke,
  ) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    const n = 18;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        i * 2 * math.pi / n,
        math.pi / n,
        false,
        p,
      );
    }
  }

  static void _arrow(Canvas canvas, Offset from, Offset to, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, p);
    final dir = to - from;
    final len = dir.distance;
    if (len == 0) return;
    final u = dir / len;
    final n = Offset(-u.dy, u.dx);
    canvas.drawLine(to, to - u * 6 + n * 5, p);
    canvas.drawLine(to, to - u * 6 - n * 5, p);
  }

  static void _badge(Canvas canvas, Size size, IconData icon, Color color) {
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

  static void _text(
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
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}

/// Live camera overlay for S-E03 / S-E06: dark scrim with a clear window
/// whose shape depends on the [target], a dashed guide, corner brackets whose
/// colour follows the live quality state, and a 2 s hold ring.
class EyeGuidePainter extends CustomPainter {
  const EyeGuidePainter({
    required this.target,
    required this.strokeColor,
    required this.holdProgress,
    required this.pulse,
    required this.captured,
    this.showCardSlot = false,
    this.variant,
  });

  final PhotoTarget target;
  final Color strokeColor;
  final double holdProgress;
  final double pulse;
  final bool captured;
  final bool showCardSlot;

  /// View code that refines the guide for one target (dental 'D1'…'D4',
  /// oral 'M1'…'M6').
  final String? variant;

  /// Foot views L2 / R2: the between-toes close-up.
  static bool _isToesView(String? variant) =>
      variant == 'L2' || variant == 'R2';

  static bool _isArchView(String? variant) =>
      variant == 'D3' || variant == 'D4';

  static Rect windowFor(Size size, PhotoTarget target, {String? variant}) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    switch (target) {
      case PhotoTarget.oralMucosa:
        final w = size.width * 0.86;
        return Rect.fromCenter(
          center: Offset(cx, cy),
          width: w,
          height: w * 3 / 4,
        );
      case PhotoTarget.teethArch:
        if (_isArchView(variant)) {
          final w = size.width * 0.80;
          return Rect.fromCenter(
            center: Offset(cx, size.height * 0.43),
            width: w,
            height: w * 1.05,
          );
        }
        final w = size.width * 0.92;
        return Rect.fromCenter(
          center: Offset(cx, cy),
          width: w,
          height: w * 0.58,
        );
      case PhotoTarget.pupilLens:
        final w = size.width * 0.70;
        return Rect.fromCenter(center: Offset(cx, cy), width: w, height: w);
      case PhotoTarget.bothPupils:
        final w = size.width * 0.92;
        return Rect.fromCenter(
          center: Offset(cx, cy),
          width: w,
          height: w * 2 / 3,
        );
      case PhotoTarget.fundus:
        final w = size.width * 0.78;
        return Rect.fromCenter(center: Offset(cx, cy), width: w, height: w);
      case PhotoTarget.lesion:
        final w = size.width * 0.68;
        return Rect.fromCenter(center: Offset(cx, cy), width: w, height: w);
      case PhotoTarget.footSole:
        if (_isToesView(variant)) {
          final w = size.width * 0.88;
          return Rect.fromCenter(
            center: Offset(cx, cy),
            width: w,
            height: w * 0.72,
          );
        }
        final w = size.width * 0.76;
        return Rect.fromCenter(
          center: Offset(cx, size.height * 0.44),
          width: w,
          height: w * 1.38,
        );
      case PhotoTarget.sclera:
      case PhotoTarget.lowerEyelid:
      case PhotoTarget.skinPatch:
        final w = size.width * 0.86;
        return Rect.fromCenter(
          center: Offset(cx, cy),
          width: w,
          height: w * 3 / 4,
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final window = windowFor(size, target, variant: variant);
    final isCircle = target == PhotoTarget.fundus;
    final shape = Path();
    if (isCircle) {
      shape.addOval(window);
    } else {
      shape.addRRect(
        RRect.fromRectAndRadius(window, const Radius.circular(22)),
      );
    }

    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addPath(shape, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: isCircle ? 0.72 : 0.55),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final guide = Paint()
      ..color = strokeColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final breathe = 1.0 + 0.02 * math.sin(pulse * 2 * math.pi);
    final cx = window.center.dx;
    final cy = window.center.dy;

    if (!isCircle) {
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
    }

    switch (target) {
      case PhotoTarget.sclera:
      case PhotoTarget.lowerEyelid:
        final eyeW = window.width * (showCardSlot ? 0.56 : 0.66) * breathe;
        final eyeH = window.height * 0.34 * breathe;
        final ex = showCardSlot ? cx - window.width * 0.12 : cx;
        final almond = Path()
          ..moveTo(ex - eyeW / 2, cy)
          ..quadraticBezierTo(ex, cy - eyeH * 1.05, ex + eyeW / 2, cy)
          ..quadraticBezierTo(ex, cy + eyeH * 1.05, ex - eyeW / 2, cy);
        _drawDashed(canvas, almond, guide, 10, 7);
        // sclera target band (below the iris)
        canvas.drawPath(
          Path()
            ..moveTo(ex - eyeW / 2, cy)
            ..quadraticBezierTo(ex, cy + eyeH * 1.05, ex + eyeW / 2, cy)
            ..quadraticBezierTo(ex, cy + eyeH * 0.25, ex - eyeW / 2, cy),
          Paint()
            ..color = Colors.white.withValues(alpha: captured ? 0.12 : 0.22),
        );
        _drawDashed(
          canvas,
          Path()..addOval(
            Rect.fromCircle(
              center: Offset(ex, cy - eyeH * 0.35),
              radius: eyeH * 0.45,
            ),
          ),
          guide..strokeWidth = 1.2,
          5,
          5,
        );
        if (showCardSlot) {
          final slot = Rect.fromCenter(
            center: Offset(window.right - window.width * 0.15, cy),
            width: window.width * 0.22,
            height: window.height * 0.30,
          );
          _drawDashed(
            canvas,
            Path()..addRRect(
              RRect.fromRectAndRadius(slot, const Radius.circular(6)),
            ),
            guide..strokeWidth = 1.6,
            6,
            5,
          );
          _label(canvas, 'card', slot.center, strokeColor);
        }
      case PhotoTarget.pupilLens:
        final r = window.width * 0.21 * breathe;
        _drawDashed(
          canvas,
          Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
          guide..strokeWidth = 2.4,
          10,
          7,
        );
        _drawDashed(
          canvas,
          Path()
            ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r * 2.1)),
          guide..strokeWidth = 1.2,
          6,
          6,
        );
        canvas.drawCircle(
          Offset(cx, cy),
          r,
          Paint()
            ..color = Colors.white.withValues(alpha: captured ? 0.08 : 0.14),
        );
        _label(canvas, 'pupil', Offset(cx, cy + r + 14), strokeColor);
      case PhotoTarget.bothPupils:
        final faceW = window.width * 0.62 * breathe;
        final faceH = window.height * 0.96 * breathe;
        _drawDashed(
          canvas,
          Path()..addOval(
            Rect.fromCenter(
              center: Offset(cx, cy + window.height * 0.06),
              width: faceW,
              height: faceH,
            ),
          ),
          guide..strokeWidth = 1.2,
          6,
          6,
        );
        final r = window.width * 0.07;
        for (final dx in [-1, 1]) {
          final c = Offset(
            cx + dx * window.width * 0.14,
            cy - window.height * 0.06,
          );
          _drawDashed(
            canvas,
            Path()..addOval(Rect.fromCircle(center: c, radius: r)),
            guide..strokeWidth = 2.2,
            8,
            6,
          );
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = Colors.white.withValues(alpha: captured ? 0.08 : 0.14),
          );
        }
        _label(
          canvas,
          'both eyes',
          Offset(cx, window.bottom - 16),
          strokeColor,
        );
      case PhotoTarget.fundus:
        final r = window.width * 0.42 * breathe;
        _drawDashed(
          canvas,
          Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
          guide..strokeWidth = 2.2,
          10,
          7,
        );
        canvas.drawCircle(
          Offset(cx, cy),
          5,
          Paint()..color = const Color(0xFF22C55E),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          10,
          Paint()..color = const Color(0xFF22C55E).withValues(alpha: 0.35),
        );
        _label(canvas, 'fixation light', Offset(cx, cy + 22), strokeColor);
      case PhotoTarget.skinPatch:
        // bare-skin patch on the left, card slot on the right
        final patch = Rect.fromCenter(
          center: Offset(cx - window.width * 0.16, cy),
          width: window.width * 0.46 * breathe,
          height: window.height * 0.52 * breathe,
        );
        _drawDashed(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(patch, const Radius.circular(18)),
          ),
          guide..strokeWidth = 2.2,
          10,
          7,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(patch, const Radius.circular(18)),
          Paint()
            ..color = Colors.white.withValues(alpha: captured ? 0.08 : 0.14),
        );
        _label(
          canvas,
          'bare skin',
          Offset(patch.center.dx, patch.bottom + 14),
          strokeColor,
        );
        final slot = Rect.fromCenter(
          center: Offset(window.right - window.width * 0.19, cy),
          width: window.width * 0.28,
          height: window.height * 0.32,
        );
        _drawDashed(
          canvas,
          Path()
            ..addRRect(RRect.fromRectAndRadius(slot, const Radius.circular(6))),
          guide..strokeWidth = 1.6,
          6,
          5,
        );
        _label(canvas, 'card', slot.center, strokeColor);
      case PhotoTarget.footSole:
        if (_isToesView(variant)) {
          // Between-toes close-up: five spread toes across the guide with a
          // gap of skin between each, big toe on the left.
          final gap = window.width / 6.4;
          for (var i = 0; i < 5; i++) {
            final r = gap * (i == 0 ? 0.52 : 0.44 - i * 0.03) * breathe;
            final tx = window.left + gap * (1.05 + i * 1.08);
            final ty = cy + (i == 0 ? gap * 0.30 : -gap * 0.06 * i);
            final toe = Path()
              ..addRRect(
                RRect.fromRectAndRadius(
                  Rect.fromCenter(
                    center: Offset(tx, ty),
                    width: r * 1.7,
                    height: r * 2.8,
                  ),
                  Radius.circular(r),
                ),
              );
            _drawDashed(canvas, toe, guide..strokeWidth = 2.0, 8, 6);
            canvas.drawPath(
              toe,
              Paint()
                ..color = Colors.white.withValues(
                  alpha: captured ? 0.08 : 0.12,
                ),
            );
          }
          _label(
            canvas,
            'spread the toes · skin between them',
            Offset(cx, window.bottom - 14),
            strokeColor,
          );
        } else {
          // Whole sole filling the guide: toes at the top, ball of the foot
          // wider than the heel, heel at the bottom; card slot on the right.
          final fw = window.width * (showCardSlot ? 0.56 : 0.64) * breathe;
          final fh = window.height * 0.84 * breathe;
          final fx = cx - (showCardSlot ? window.width * 0.10 : 0);
          final top = cy - fh * 0.44;
          final bottom = cy + fh * 0.50;
          final sole = Path()
            ..moveTo(fx - fw * 0.44, top + fh * 0.20)
            ..quadraticBezierTo(
              fx - fw * 0.54,
              top + fh * 0.48,
              fx - fw * 0.34,
              top + fh * 0.74,
            )
            ..quadraticBezierTo(fx - fw * 0.30, bottom, fx, bottom)
            ..quadraticBezierTo(
              fx + fw * 0.30,
              bottom,
              fx + fw * 0.30,
              top + fh * 0.74,
            )
            ..quadraticBezierTo(
              fx + fw * 0.48,
              top + fh * 0.42,
              fx + fw * 0.42,
              top + fh * 0.16,
            )
            ..quadraticBezierTo(
              fx,
              top + fh * 0.02,
              fx - fw * 0.44,
              top + fh * 0.20,
            )
            ..close();
          _drawDashed(canvas, sole, guide..strokeWidth = 2.2, 10, 7);
          canvas.drawPath(
            sole,
            Paint()
              ..color = Colors.white.withValues(alpha: captured ? 0.08 : 0.12),
          );
          for (var i = 0; i < 5; i++) {
            final r = fw * (0.115 - i * 0.013);
            final tx = fx - fw * 0.31 + i * fw * 0.17;
            final ty = top + fh * 0.05 + i * fh * 0.015;
            _drawDashed(
              canvas,
              Path()
                ..addOval(Rect.fromCircle(center: Offset(tx, ty), radius: r)),
              guide..strokeWidth = 1.4,
              5,
              4,
            );
          }
          _label(
            canvas,
            'whole sole · toes at the top · heel at the bottom',
            Offset(fx, window.bottom - 14),
            strokeColor,
          );
          if (showCardSlot) {
            final slot = Rect.fromCenter(
              center: Offset(
                window.right - window.width * 0.16,
                cy + window.height * 0.20,
              ),
              width: window.width * 0.24,
              height: window.height * 0.14,
            );
            _drawDashed(
              canvas,
              Path()..addRRect(
                RRect.fromRectAndRadius(slot, const Radius.circular(6)),
              ),
              guide..strokeWidth = 1.6,
              6,
              5,
            );
            _label(canvas, 'card', slot.center, strokeColor);
          }
        }
      case PhotoTarget.lesion:
        final r = window.width * 0.17 * breathe;
        _drawDashed(
          canvas,
          Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
          guide..strokeWidth = 2.4,
          10,
          7,
        );
        _drawDashed(
          canvas,
          Path()
            ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r * 2.2)),
          guide..strokeWidth = 1.2,
          6,
          6,
        );
        canvas.drawCircle(
          Offset(cx, cy),
          r,
          Paint()
            ..color = Colors.white.withValues(alpha: captured ? 0.06 : 0.10),
        );
        // mm ticks along the bottom of the window (scale hint)
        final tick = Paint()
          ..color = strokeColor.withValues(alpha: 0.7)
          ..strokeWidth = 1.2;
        final y0 = window.bottom - 22;
        for (var i = 0; i <= 10; i++) {
          final x = window.left + window.width * 0.25 + i * window.width * 0.05;
          canvas.drawLine(
            Offset(x, y0),
            Offset(x, y0 - (i % 5 == 0 ? 10 : 5)),
            tick,
          );
        }
        _label(
          canvas,
          'spot in the ring · card or coin beside it',
          Offset(cx, window.bottom - 8),
          strokeColor,
        );
      case PhotoTarget.oralMucosa:
        // the lining should fill an inner rounded area; lips / teeth stay out
        final lining = Rect.fromCenter(
          center: Offset(cx, cy),
          width: window.width * 0.78 * breathe,
          height: window.height * 0.72 * breathe,
        );
        _drawDashed(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(lining, const Radius.circular(40)),
          ),
          guide..strokeWidth = 2.2,
          10,
          7,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(lining, const Radius.circular(40)),
          Paint()
            ..color = Colors.white.withValues(alpha: captured ? 0.06 : 0.10),
        );
        final site = switch (variant) {
          'M1' || 'M2' => 'cheek lining fills the frame · pull the cheek out',
          'M3' || 'M4' => 'tongue edge in the frame · hold the tip with gauze',
          'M5' => 'under the tongue · tip touching the roof',
          'M6' => 'roof of the mouth · head back, say "aah"',
          _ => 'mouth lining fills the frame',
        };
        _label(canvas, site, Offset(cx, window.bottom - 10), strokeColor);
      case PhotoTarget.teethArch:
        if (_isArchView(variant)) {
          // U-shaped arch guide: upper opens downward, lower opens upward
          final upper = variant == 'D3';
          final rx = window.width * 0.36 * breathe;
          final ry = window.height * 0.40 * breathe;
          final top = upper
              ? window.top + window.height * 0.12
              : window.bottom - window.height * 0.12;
          final dir = upper ? 1.0 : -1.0;
          final u = Path()
            ..moveTo(cx - rx, top + dir * ry)
            ..quadraticBezierTo(cx - rx, top, cx, top)
            ..quadraticBezierTo(cx + rx, top, cx + rx, top + dir * ry);
          _drawDashed(canvas, u, guide..strokeWidth = 2.4, 10, 7);
          canvas.drawPath(
            u,
            Paint()
              ..color = Colors.white.withValues(alpha: captured ? 0.06 : 0.12)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 26,
          );
          _label(
            canvas,
            upper
                ? 'whole upper arch · molar to molar · head back'
                : 'whole lower arch · tongue up',
            Offset(cx, upper ? window.bottom - 12 : window.top + 14),
            strokeColor,
          );
        } else {
          // lips-back band with a bite line (closed) or an open gap
          final band = Rect.fromCenter(
            center: Offset(cx, cy),
            width: window.width * 0.86 * breathe,
            height: window.height * 0.62 * breathe,
          );
          _drawDashed(
            canvas,
            Path()..addRRect(
              RRect.fromRectAndRadius(band, const Radius.circular(30)),
            ),
            guide..strokeWidth = 2.2,
            10,
            7,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(band, const Radius.circular(30)),
            Paint()
              ..color = Colors.white.withValues(alpha: captured ? 0.06 : 0.10),
          );
          if (variant == 'D1') {
            _drawDashed(
              canvas,
              Path()
                ..moveTo(band.left + 16, band.center.dy)
                ..lineTo(band.right - 16, band.center.dy),
              guide..strokeWidth = 1.4,
              6,
              6,
            );
          } else {
            _drawDashed(
              canvas,
              Path()..addRRect(
                RRect.fromRectAndRadius(
                  Rect.fromCenter(
                    center: band.center,
                    width: band.width * 0.7,
                    height: band.height * 0.30,
                  ),
                  const Radius.circular(14),
                ),
              ),
              guide..strokeWidth = 1.4,
              6,
              6,
            );
          }
          _label(
            canvas,
            variant == 'D1'
                ? 'bite together · all front teeth · lips pulled back'
                : 'open two fingers · tongue down · lips pulled back',
            Offset(cx, window.bottom - 10),
            strokeColor,
          );
        }
    }

    if (holdProgress > 0) {
      final ring = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      final metrics = shape.computeMetrics().first;
      canvas.drawPath(
        metrics.extractPath(0, metrics.length * holdProgress.clamp(0.0, 1.0)),
        ring,
      );
    }
    if (captured) {
      canvas.drawPath(
        shape,
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
    }
  }

  void _label(Canvas canvas, String s, Offset c, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.9),
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
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
  bool shouldRepaint(covariant EyeGuidePainter old) =>
      old.strokeColor != strokeColor ||
      old.holdProgress != holdProgress ||
      old.pulse != pulse ||
      old.captured != captured ||
      old.target != target ||
      old.showCardSlot != showCardSlot ||
      old.variant != variant;
}

/// Mouth drawings for the Dental section (oral lesion + 4-view dental):
/// open mouth, cheek pulled out, tongue positions, arches, torch distance,
/// examples and a mini FDI chart. Shares the phone / text / badge primitives
/// of [_BodyIllustrationPainter].
class _MouthIllustrationPainter {
  _MouthIllustrationPainter._();

  static const Color _lip = Color(0xFFD9797E);
  static const Color _lipDark = Color(0xFFB85C62);
  static const Color _cavity = Color(0xFF4A1F24);
  static const Color _mucosa = Color(0xFFF2A3AC);
  static const Color _mucosaDark = Color(0xFFD9858F);
  static const Color _tongue = Color(0xFFE88A93);
  static const Color _toothWhite = Color(0xFFFDFBF4);
  static const Color _toothLine = Color(0xFFC9C2B2);
  static const Color _gum = Color(0xFFEF9AA2);
  static const Color _skin = _BodyIllustrationPainter._skin;
  static const Color _skinLine = _BodyIllustrationPainter._skinLine;
  static const Color _ink = _BodyIllustrationPainter._ink;
  static const Color _green = _BodyIllustrationPainter._green;
  static const Color _amber = _BodyIllustrationPainter._amber;
  static const Color _red = _BodyIllustrationPainter._red;
  static const Color _primary = _BodyIllustrationPainter._primary;

  static void paintKind(Canvas canvas, Size size, EyeIllustration kind) {
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case EyeIllustration.mouthOpenWide:
        _openMouth(
          canvas,
          Rect.fromLTWH(w * 0.10, h * 0.16, w * 0.62, h * 0.56),
        );
        _torchPhone(
          canvas,
          Rect.fromLTWH(w * 0.80, h * 0.22, w * 0.12, h * 0.42),
          toLeft: true,
        );
        _BodyIllustrationPainter._text(
          canvas,
          'open wide · torch',
          Offset(w * 0.50, h * 0.88),
          w * 0.085,
          _ink,
        );
      case EyeIllustration.cheekRetract:
        _openMouth(
          canvas,
          Rect.fromLTWH(w * 0.22, h * 0.16, w * 0.62, h * 0.56),
          cheekLining: true,
        );
        _finger(canvas, Rect.fromLTWH(w * 0.04, h * 0.30, w * 0.26, h * 0.16));
        _BodyIllustrationPainter._arrow(
          canvas,
          Offset(w * 0.30, h * 0.60),
          Offset(w * 0.10, h * 0.60),
          _primary,
        );
        _BodyIllustrationPainter._text(
          canvas,
          'pull cheek out',
          Offset(w * 0.50, h * 0.88),
          w * 0.085,
          _ink,
        );
      case EyeIllustration.tongueToSide:
        _openMouth(
          canvas,
          Rect.fromLTWH(w * 0.14, h * 0.12, w * 0.62, h * 0.52),
        );
        // tongue out, pushed to the right; gauze holds the tip
        final t = Rect.fromLTWH(w * 0.34, h * 0.40, w * 0.30, h * 0.36);
        _tongueShape(canvas, t, edge: true);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.58, h * 0.62, w * 0.18, h * 0.14),
            Radius.circular(w * 0.02),
          ),
          Paint()..color = Colors.white,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.58, h * 0.62, w * 0.18, h * 0.14),
            Radius.circular(w * 0.02),
          ),
          Paint()
            ..color = _toothLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        _BodyIllustrationPainter._arrow(
          canvas,
          Offset(w * 0.40, h * 0.84),
          Offset(w * 0.66, h * 0.84),
          _primary,
        );
        _BodyIllustrationPainter._text(
          canvas,
          'tongue to the side',
          Offset(w * 0.50, h * 0.94),
          w * 0.08,
          _ink,
        );
      case EyeIllustration.tongueUpFloor:
        _openMouth(
          canvas,
          Rect.fromLTWH(w * 0.14, h * 0.12, w * 0.68, h * 0.60),
          tongueUp: true,
        );
        _BodyIllustrationPainter._text(
          canvas,
          'tongue up · floor',
          Offset(w * 0.50, h * 0.88),
          w * 0.085,
          _ink,
        );
      case EyeIllustration.headBackPalate:
        _openMouth(
          canvas,
          Rect.fromLTWH(w * 0.14, h * 0.12, w * 0.68, h * 0.60),
          palate: true,
        );
        _BodyIllustrationPainter._text(
          canvas,
          'head back · say aah',
          Offset(w * 0.50, h * 0.88),
          w * 0.08,
          _ink,
        );
      case EyeIllustration.torchMouthDistance:
        _openMouth(
          canvas,
          Rect.fromLTWH(w * 0.04, h * 0.22, w * 0.46, h * 0.44),
        );
        _torchPhone(
          canvas,
          Rect.fromLTWH(w * 0.80, h * 0.24, w * 0.12, h * 0.42),
          toLeft: true,
        );
        final dash = Paint()
          ..color = _primary
          ..strokeWidth = math.max(1, w * 0.012);
        for (var x = w * 0.52; x < w * 0.78; x += w * 0.05) {
          canvas.drawLine(
            Offset(x, h * 0.46),
            Offset(x + w * 0.025, h * 0.46),
            dash,
          );
        }
        _BodyIllustrationPainter._text(
          canvas,
          '10–15 cm · torch on',
          Offset(w * 0.50, h * 0.86),
          w * 0.08,
          _ink,
        );
      case EyeIllustration.dentureOut:
        // denture arch out of the mouth, water glass, "rinse"
        _arch(
          canvas,
          Rect.fromLTWH(w * 0.12, h * 0.14, w * 0.50, h * 0.42),
          upper: true,
          tongue: false,
        );
        _BodyIllustrationPainter._arrow(
          canvas,
          Offset(w * 0.40, h * 0.62),
          Offset(w * 0.40, h * 0.78),
          _primary,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.70, h * 0.30, w * 0.18, h * 0.30),
            Radius.circular(w * 0.02),
          ),
          Paint()..color = const Color(0xFFBAE6FD),
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.70, h * 0.40, w * 0.18, h * 0.20),
          Paint()..color = const Color(0xFF7DD3FC),
        );
        _BodyIllustrationPainter._text(
          canvas,
          'rinse · dentures out',
          Offset(w * 0.50, h * 0.90),
          w * 0.08,
          _ink,
        );
      case EyeIllustration.oralGoodExample:
        _mucosaField(canvas, size);
        _BodyIllustrationPainter._badge(
          canvas,
          size,
          Icons.check_rounded,
          _green,
        );
      case EyeIllustration.oralPatchExample:
        _mucosaField(canvas, size);
        _patch(canvas, Offset(w * 0.36, h * 0.48), w * 0.16, white: true);
        _patch(canvas, Offset(w * 0.68, h * 0.62), w * 0.11, white: false);
        _BodyIllustrationPainter._badge(
          canvas,
          size,
          Icons.priority_high_rounded,
          _amber,
        );
      case EyeIllustration.frontBite:
        _frontTeeth(
          canvas,
          Rect.fromLTWH(w * 0.08, h * 0.18, w * 0.84, h * 0.52),
          open: false,
        );
        _BodyIllustrationPainter._text(
          canvas,
          'bite together · lips back',
          Offset(w * 0.50, h * 0.88),
          w * 0.075,
          _ink,
        );
      case EyeIllustration.frontOpen:
        _frontTeeth(
          canvas,
          Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.84, h * 0.64),
          open: true,
        );
        _BodyIllustrationPainter._text(
          canvas,
          'open · tongue down',
          Offset(w * 0.50, h * 0.90),
          w * 0.08,
          _ink,
        );
      case EyeIllustration.upperArch:
        _arch(
          canvas,
          Rect.fromLTWH(w * 0.14, h * 0.12, w * 0.72, h * 0.62),
          upper: true,
          tongue: false,
        );
        _BodyIllustrationPainter._text(
          canvas,
          'upper · head back',
          Offset(w * 0.50, h * 0.88),
          w * 0.08,
          _ink,
        );
      case EyeIllustration.lowerArch:
        _arch(
          canvas,
          Rect.fromLTWH(w * 0.14, h * 0.18, w * 0.72, h * 0.62),
          upper: false,
          tongue: true,
        );
        _BodyIllustrationPainter._text(
          canvas,
          'lower · tongue up',
          Offset(w * 0.50, h * 0.90),
          w * 0.08,
          _ink,
        );
      case EyeIllustration.wipeTeeth:
        _teethRow(
          canvas,
          Rect.fromLTWH(w * 0.10, h * 0.24, w * 0.60, h * 0.28),
          count: 6,
          upper: true,
        );
        // tissue
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.56, h * 0.40, w * 0.30, h * 0.26),
            Radius.circular(w * 0.03),
          ),
          Paint()..color = Colors.white,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.56, h * 0.40, w * 0.30, h * 0.26),
            Radius.circular(w * 0.03),
          ),
          Paint()
            ..color = _toothLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        _BodyIllustrationPainter._arrow(
          canvas,
          Offset(w * 0.70, h * 0.74),
          Offset(w * 0.40, h * 0.74),
          _primary,
        );
        _BodyIllustrationPainter._text(
          canvas,
          'dry the teeth',
          Offset(w * 0.50, h * 0.90),
          w * 0.085,
          _ink,
        );
      case EyeIllustration.helperChildMouth:
        // child head (lying back) with open mouth, guardian hand + phone above
        canvas.drawCircle(
          Offset(w * 0.36, h * 0.58),
          w * 0.24,
          Paint()..color = _skin,
        );
        canvas.drawCircle(
          Offset(w * 0.36, h * 0.58),
          w * 0.24,
          Paint()
            ..color = _skinLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, w * 0.016),
        );
        _openMouth(
          canvas,
          Rect.fromLTWH(w * 0.24, h * 0.56, w * 0.24, h * 0.18),
          simple: true,
        );
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w * 0.28, h * 0.48), radius: w * 0.03),
          0,
          math.pi,
          false,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, w * 0.014),
        );
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w * 0.44, h * 0.48), radius: w * 0.03),
          0,
          math.pi,
          false,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, w * 0.014),
        );
        _BodyIllustrationPainter._phone(
          canvas,
          Rect.fromLTWH(w * 0.62, h * 0.10, w * 0.16, h * 0.34),
          tilt: -0.5,
        );
        _finger(canvas, Rect.fromLTWH(w * 0.70, h * 0.40, w * 0.22, h * 0.14));
        _BodyIllustrationPainter._text(
          canvas,
          'knee-to-knee',
          Offset(w * 0.50, h * 0.92),
          w * 0.08,
          _ink,
        );
      case EyeIllustration.dentalGoodExample:
        _frontTeeth(
          canvas,
          Rect.fromLTWH(w * 0.02, h * 0.14, w * 0.96, h * 0.66),
          open: false,
        );
        _BodyIllustrationPainter._badge(
          canvas,
          size,
          Icons.check_rounded,
          _green,
        );
      case EyeIllustration.dentalBlurryExample:
        final r = Rect.fromLTWH(w * 0.02, h * 0.14, w * 0.96, h * 0.66);
        for (final dx in [-0.03, 0.0, 0.03]) {
          canvas.save();
          canvas.translate(w * dx, 0);
          _frontTeeth(canvas, r, open: false);
          canvas.restore();
        }
        canvas.drawRect(
          r,
          Paint()..color = Colors.white.withValues(alpha: 0.45),
        );
        canvas.drawCircle(
          Offset(w * 0.68, h * 0.34),
          w * 0.09,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        _BodyIllustrationPainter._badge(
          canvas,
          size,
          Icons.priority_high_rounded,
          _amber,
        );
      case EyeIllustration.dentalTongueExample:
        _arch(
          canvas,
          Rect.fromLTWH(w * 0.12, h * 0.16, w * 0.72, h * 0.62),
          upper: false,
          tongue: true,
          tongueOver: true,
        );
        _BodyIllustrationPainter._badge(
          canvas,
          size,
          Icons.priority_high_rounded,
          _amber,
        );
      case EyeIllustration.toothChartExample:
        final cell = w * 0.085;
        for (var row = 0; row < 2; row++) {
          for (var i = 0; i < 8; i++) {
            final r = Rect.fromLTWH(
              w * 0.12 + i * (cell + w * 0.012),
              h * (row == 0 ? 0.22 : 0.50),
              cell,
              cell * 1.1,
            );
            final flagged = row == 1 && i == 5;
            canvas.drawRRect(
              RRect.fromRectAndRadius(r, Radius.circular(cell * 0.2)),
              Paint()
                ..color = flagged
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFD1FAE5),
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(r, Radius.circular(cell * 0.2)),
              Paint()
                ..color = flagged ? _red : _green
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1,
            );
          }
        }
        _BodyIllustrationPainter._text(
          canvas,
          'FDI chart',
          Offset(w * 0.50, h * 0.86),
          w * 0.085,
          _ink,
        );
      default:
        break;
    }
  }

  // --- primitives ----------------------------------------------------------

  /// Open mouth inside [r]: lips, dark cavity, upper + lower teeth rows and a
  /// resting tongue. Options expose the cheek lining, lift the tongue (floor)
  /// or show the palate dome (head back).
  static void _openMouth(
    Canvas canvas,
    Rect r, {
    bool cheekLining = false,
    bool tongueUp = false,
    bool palate = false,
    bool simple = false,
  }) {
    final lips = RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.5));
    canvas.drawRRect(lips, Paint()..color = _lip);
    final inner = r.deflate(r.height * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(inner.height * 0.45)),
      Paint()..color = _cavity,
    );
    if (simple) return;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(inner.height * 0.45)),
    );
    if (palate) {
      // dome of the palate with a uvula hanging at the centre
      canvas.drawOval(
        Rect.fromLTWH(
          inner.left + inner.width * 0.10,
          inner.top - inner.height * 0.20,
          inner.width * 0.80,
          inner.height * 0.70,
        ),
        Paint()..color = _mucosa,
      );
      canvas.drawOval(
        Rect.fromLTWH(
          inner.left + inner.width * 0.16,
          inner.top - inner.height * 0.12,
          inner.width * 0.68,
          inner.height * 0.50,
        ),
        Paint()..color = _mucosaDark,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(inner.center.dx, inner.top + inner.height * 0.52),
          width: inner.width * 0.08,
          height: inner.height * 0.18,
        ),
        Paint()..color = _mucosaDark,
      );
      _teethRow(
        canvas,
        Rect.fromLTWH(inner.left, inner.top, inner.width, inner.height * 0.22),
        count: 8,
        upper: true,
        archy: true,
      );
    } else {
      _teethRow(
        canvas,
        Rect.fromLTWH(inner.left, inner.top, inner.width, inner.height * 0.26),
        count: 8,
        upper: true,
      );
      if (tongueUp) {
        // floor of the mouth exposed, tongue tip touching the palate
        canvas.drawOval(
          Rect.fromLTWH(
            inner.left + inner.width * 0.14,
            inner.top + inner.height * 0.52,
            inner.width * 0.72,
            inner.height * 0.50,
          ),
          Paint()..color = _mucosa,
        );
        _tongueShape(
          canvas,
          Rect.fromLTWH(
            inner.left + inner.width * 0.28,
            inner.top + inner.height * 0.02,
            inner.width * 0.44,
            inner.height * 0.52,
          ),
          edge: false,
        );
      } else {
        _tongueShape(
          canvas,
          Rect.fromLTWH(
            inner.left + inner.width * 0.22,
            inner.top + inner.height * 0.42,
            inner.width * 0.56,
            inner.height * 0.60,
          ),
          edge: false,
        );
      }
      _teethRow(
        canvas,
        Rect.fromLTWH(
          inner.left,
          inner.bottom - inner.height * 0.24,
          inner.width,
          inner.height * 0.24,
        ),
        count: 8,
        upper: false,
      );
    }
    if (cheekLining) {
      // the left cheek pulled out: pink lining fills the left third
      canvas.drawRect(
        Rect.fromLTWH(inner.left, inner.top, inner.width * 0.34, inner.height),
        Paint()..color = _mucosa,
      );
      canvas.drawRect(
        Rect.fromLTWH(inner.left, inner.top, inner.width * 0.34, inner.height),
        Paint()
          ..color = _mucosaDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      lips,
      Paint()
        ..color = _lipDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r.height * 0.03),
    );
  }

  static void _teethRow(
    Canvas canvas,
    Rect r, {
    required int count,
    required bool upper,
    bool archy = false,
  }) {
    final gap = r.width * 0.012;
    final tw = (r.width - gap * (count - 1)) / count;
    for (var i = 0; i < count; i++) {
      // front teeth a little taller than the side ones
      final centreness = 1 - ((i + 0.5) / count - 0.5).abs() * 2;
      final th = r.height * (0.72 + 0.28 * centreness);
      final x = r.left + i * (tw + gap);
      final y = upper ? r.top : r.bottom - th;
      final arch = archy ? (1 - centreness) * r.height * 0.25 : 0.0;
      final tooth = Rect.fromLTWH(x, y + (upper ? arch : -arch), tw, th);
      final rr = RRect.fromRectAndCorners(
        tooth,
        topLeft: Radius.circular(upper ? tw * 0.1 : tw * 0.35),
        topRight: Radius.circular(upper ? tw * 0.1 : tw * 0.35),
        bottomLeft: Radius.circular(upper ? tw * 0.35 : tw * 0.1),
        bottomRight: Radius.circular(upper ? tw * 0.35 : tw * 0.1),
      );
      canvas.drawRRect(rr, Paint()..color = _toothWhite);
      canvas.drawRRect(
        rr,
        Paint()
          ..color = _toothLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
    // gum strip
    canvas.drawRect(
      upper
          ? Rect.fromLTWH(
              r.left,
              r.top - r.height * 0.12,
              r.width,
              r.height * 0.14,
            )
          : Rect.fromLTWH(
              r.left,
              r.bottom - r.height * 0.02,
              r.width,
              r.height * 0.14,
            ),
      Paint()..color = _gum,
    );
  }

  /// Front teeth as seen with the lips pulled back (closed bite or open).
  static void _frontTeeth(Canvas canvas, Rect r, {required bool open}) {
    // retracted lips frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.3)),
      Paint()..color = _lip,
    );
    final inner = r.deflate(r.height * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(inner.height * 0.28)),
      Paint()..color = open ? _cavity : _gum,
    );
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(inner.height * 0.28)),
    );
    if (open) {
      _teethRow(
        canvas,
        Rect.fromLTWH(
          inner.left,
          inner.top + inner.height * 0.10,
          inner.width,
          inner.height * 0.30,
        ),
        count: 10,
        upper: true,
      );
      _tongueShape(
        canvas,
        Rect.fromLTWH(
          inner.left + inner.width * 0.25,
          inner.top + inner.height * 0.52,
          inner.width * 0.50,
          inner.height * 0.5,
        ),
        edge: false,
      );
      _teethRow(
        canvas,
        Rect.fromLTWH(
          inner.left,
          inner.bottom - inner.height * 0.38,
          inner.width,
          inner.height * 0.28,
        ),
        count: 10,
        upper: false,
      );
    } else {
      _teethRow(
        canvas,
        Rect.fromLTWH(
          inner.left,
          inner.top + inner.height * 0.12,
          inner.width,
          inner.height * 0.40,
        ),
        count: 10,
        upper: true,
      );
      _teethRow(
        canvas,
        Rect.fromLTWH(
          inner.left,
          inner.bottom - inner.height * 0.50,
          inner.width,
          inner.height * 0.38,
        ),
        count: 10,
        upper: false,
      );
      // bite line
      canvas.drawLine(
        Offset(inner.left, inner.center.dy + inner.height * 0.02),
        Offset(inner.right, inner.center.dy + inner.height * 0.02),
        Paint()
          ..color = _toothLine
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  /// U-shaped dental arch seen from the biting surface. Upper arch opens
  /// downwards (palate inside), lower arch opens upwards (tongue inside).
  static void _arch(
    Canvas canvas,
    Rect r, {
    required bool upper,
    required bool tongue,
    bool tongueOver = false,
  }) {
    final cx = r.center.dx;
    final rx = r.width / 2;
    final ry = r.height * 0.92;
    final top = upper ? r.top : r.bottom;
    final dir = upper ? 1.0 : -1.0;
    // gum U
    final gumPath = Path()
      ..moveTo(cx - rx, top + dir * ry)
      ..quadraticBezierTo(cx - rx, top, cx, top)
      ..quadraticBezierTo(cx + rx, top, cx + rx, top + dir * ry);
    canvas.drawPath(
      gumPath,
      Paint()
        ..color = _gum
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width * 0.26
        ..strokeCap = StrokeCap.round,
    );
    // inside: palate (upper) or tongue (lower)
    final insideRect = Rect.fromLTWH(
      cx - rx * 0.62,
      upper ? top + ry * 0.12 : top - ry * 0.95,
      rx * 1.24,
      ry * 0.85,
    );
    canvas.drawOval(
      insideRect,
      Paint()..color = upper ? _mucosa : (tongue ? _tongue : _cavity),
    );
    if (!upper && tongue) {
      canvas.drawLine(
        Offset(cx, insideRect.top + insideRect.height * 0.15),
        Offset(cx, insideRect.bottom - insideRect.height * 0.1),
        Paint()
          ..color = _mucosaDark
          ..strokeWidth = 1,
      );
    }
    // teeth along the U
    const n = 12;
    for (var i = 0; i < n; i++) {
      final t = (i + 0.5) / n;
      // parametric point on the quadratic U (approximate by angle)
      final ang = math.pi * t;
      final px = cx - rx * math.cos(ang);
      final py = top + dir * ry * math.sin(ang) * 0.95;
      final size = r.width * (0.075 + 0.02 * math.sin(ang));
      final tooth = Rect.fromCenter(
        center: Offset(px, py),
        width: size,
        height: size * 1.1,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(tooth, Radius.circular(size * 0.3)),
        Paint()..color = _toothWhite,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(tooth, Radius.circular(size * 0.3)),
        Paint()
          ..color = _toothLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      // fissure on molars
      if (t < 0.3 || t > 0.7) {
        canvas.drawLine(
          Offset(px - size * 0.25, py),
          Offset(px + size * 0.25, py),
          Paint()
            ..color = _toothLine
            ..strokeWidth = 0.8,
        );
      }
    }
    if (tongueOver) {
      // tongue flopping over the lower teeth — the "bad" example
      _tongueShape(
        canvas,
        Rect.fromLTWH(
          cx - rx * 0.75,
          r.top + r.height * 0.22,
          rx * 1.5,
          r.height * 0.78,
        ),
        edge: false,
      );
    }
  }

  static void _tongueShape(Canvas canvas, Rect r, {required bool edge}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.45)),
      Paint()..color = _tongue,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.45)),
      Paint()
        ..color = _mucosaDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (edge) {
      // highlighted lateral border
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            r.left,
            r.top + r.height * 0.1,
            r.width * 0.22,
            r.height * 0.8,
          ),
          Radius.circular(r.width * 0.2),
        ),
        Paint()..color = _primary.withValues(alpha: 0.35),
      );
    } else {
      canvas.drawLine(
        Offset(r.center.dx, r.top + r.height * 0.15),
        Offset(r.center.dx, r.bottom - r.height * 0.15),
        Paint()
          ..color = _mucosaDark
          ..strokeWidth = 1,
      );
    }
  }

  static void _finger(Canvas canvas, Rect r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.5)),
      Paint()..color = _skin,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.5)),
      Paint()
        ..color = _skinLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // nail
    canvas.drawOval(
      Rect.fromLTWH(
        r.right - r.height * 0.9,
        r.top + r.height * 0.2,
        r.height * 0.7,
        r.height * 0.6,
      ),
      Paint()..color = const Color(0xFFFBE3D2),
    );
  }

  static void _torchPhone(Canvas canvas, Rect r, {required bool toLeft}) {
    _BodyIllustrationPainter._phone(canvas, r);
    // light cone from the lens towards the mouth
    final lens = Offset(toLeft ? r.left : r.right, r.top + r.height * 0.14);
    final cone = Path()
      ..moveTo(lens.dx, lens.dy)
      ..lineTo(
        lens.dx + (toLeft ? -r.width * 3.2 : r.width * 3.2),
        lens.dy - r.height * 0.25,
      )
      ..lineTo(
        lens.dx + (toLeft ? -r.width * 3.2 : r.width * 3.2),
        lens.dy + r.height * 0.55,
      )
      ..close();
    canvas.drawPath(
      cone,
      Paint()..color = const Color(0xFFFDE68A).withValues(alpha: 0.45),
    );
  }

  static void _mucosaField(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _mucosa);
    final vein = Paint()
      ..color = _mucosaDark.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.15 + i * 0.14);
      canvas.drawLine(
        Offset(size.width * 0.1, y),
        Offset(size.width * 0.9, y + size.height * 0.04),
        vein,
      );
    }
    // wet highlight
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.55,
        size.height * 0.18,
        size.width * 0.22,
        size.height * 0.12,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  static void _patch(Canvas canvas, Offset c, double r, {required bool white}) {
    final p = Path()
      ..moveTo(c.dx - r, c.dy)
      ..quadraticBezierTo(
        c.dx - r * 0.8,
        c.dy - r * 1.1,
        c.dx + r * 0.1,
        c.dy - r * 0.8,
      )
      ..quadraticBezierTo(
        c.dx + r * 1.2,
        c.dy - r * 0.8,
        c.dx + r * 0.9,
        c.dy + r * 0.2,
      )
      ..quadraticBezierTo(
        c.dx + r * 1.0,
        c.dy + r * 1.0,
        c.dx + r * 0.1,
        c.dy + r * 0.8,
      )
      ..quadraticBezierTo(c.dx - r * 0.6, c.dy + r * 1.1, c.dx - r, c.dy)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..color = white ? const Color(0xFFF8F4EC) : const Color(0xFFB3262E),
    );
    canvas.drawPath(
      p,
      Paint()
        ..color = white ? const Color(0xFFD8CFC0) : const Color(0xFF7F1D1D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}
