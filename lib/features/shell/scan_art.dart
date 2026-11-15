import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Neon line-art illustrations for each screening category, drawn in code so
/// they stay crisp at any size and need no image assets.
///
/// When [animate] is true the art loops subtly: the heart beats while its
/// pulse line draws, the eye blinks, lungs breathe, sound waves ripple,
/// stars twinkle and the runner bobs. Animation is skipped when the platform
/// asks for reduced motion and inside widget tests (so `pumpAndSettle` can
/// settle).
///
/// Artwork is authored on a 100×100 grid and scaled to the widget size.
class ScanArt extends StatefulWidget {
  const ScanArt({
    super.key,
    required this.category,
    required this.color,
    this.size = 64,
    this.glow = true,
    this.animate = true,
  });

  final String category;
  final Color color;
  final double size;
  final bool glow;
  final bool animate;

  /// True while running under `flutter test`.
  static final bool _inTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  State<ScanArt> createState() => _ScanArtState();
}

class _ScanArtState extends State<ScanArt> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  bool _shouldAnimate(BuildContext context) =>
      widget.animate &&
      !ScanArt._inTest &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ScanArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_shouldAnimate(context)) {
      _c ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..repeat();
    } else {
      _c?.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    Widget paint(double t) => CustomPaint(
      painter: _ArtPainter(
        category: widget.category,
        color: widget.color,
        glow: widget.glow,
        t: t,
      ),
    );
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: c == null
            ? paint(0.25)
            : AnimatedBuilder(
                animation: c,
                builder: (context, _) => paint(c.value),
              ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter({
    required this.category,
    required this.color,
    required this.glow,
    required this.t,
  });

  final String category;
  final Color color;
  final bool glow;

  /// Loop phase 0..1.
  final double t;

  late double _s;
  late Canvas _c;

  static const _tau = math.pi * 2;

  Offset _p(double x, double y) => Offset(x * _s, y * _s);

  /// 0..1 wave with an optional phase offset (in loop fractions).
  double _wave([double phase = 0, double speed = 1]) =>
      (math.sin((t * speed - phase) * _tau) + 1) / 2;

  Paint _line([double alpha = 1]) => Paint()
    ..color = color.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2 * _s
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _thin([double alpha = 0.75]) => Paint()
    ..color = color.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2 * _s
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get _fill => Paint()
    ..shader = RadialGradient(
      colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.04)],
    ).createShader(Rect.fromLTWH(0, 0, 100 * _s, 100 * _s));

  Paint _dot([double alpha = 1]) =>
      Paint()..color = color.withValues(alpha: alpha);

  /// Draws [path] with a soft neon glow underneath.
  void _neon(
    Path path, {
    bool fill = false,
    bool thin = false,
    double alpha = 1,
  }) {
    if (fill) _c.drawPath(path, _fill);
    if (glow && alpha > 0.05) {
      _c.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.45 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (thin ? 5 : 7) * _s
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * _s),
      );
    }
    _c.drawPath(path, thin ? _thin(0.75 * alpha) : _line(alpha));
  }

  void _circle(double x, double y, double r, {bool fill = false}) {
    _neon(
      Path()..addOval(Rect.fromCircle(center: _p(x, y), radius: r * _s)),
      fill: fill,
    );
  }

  /// Runs [draw] scaled around ([cx], [cy]) on the 100-grid.
  void _scaled(double cx, double cy, double sx, double sy, VoidCallback draw) {
    _c.save();
    _c.translate(cx * _s, cy * _s);
    _c.scale(sx, sy);
    _c.translate(-cx * _s, -cy * _s);
    draw();
    _c.restore();
  }

  void _moved(double dx, double dy, VoidCallback draw) {
    _c.save();
    _c.translate(dx * _s, dy * _s);
    draw();
    _c.restore();
  }

  Path _poly(List<List<double>> pts) {
    final p = Path()
      ..moveTo(_p(pts[0][0], pts[0][1]).dx, _p(pts[0][0], pts[0][1]).dy);
    for (final q in pts.skip(1)) {
      p.lineTo(_p(q[0], q[1]).dx, _p(q[0], q[1]).dy);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    _s = size.shortestSide / 100;
    switch (category) {
      case 'Vitals':
        _heart();
      case 'Eyes':
        _eye();
      case 'Dental':
        _tooth();
      case 'Skin & Body':
        _skin();
      case 'Breathing & Voice':
        _lungs();
      case 'Brain & Mind':
        _brain();
      case 'Sleep':
        _moon();
      case 'Hearing':
        _ear();
      case 'Vision':
        _glasses();
      case 'Movement':
        _runner();
      default:
        _circle(50, 50, 30, fill: true);
    }
  }

  void _heart() {
    // Two quick beats per loop.
    final beat = math.pow(math.max(0, math.sin(t * 2 * _tau)), 6).toDouble();
    _scaled(50, 52, 1 + 0.07 * beat, 1 + 0.07 * beat, () {
      final h = Path()
        ..moveTo(_p(50, 84).dx, _p(50, 84).dy)
        ..cubicTo(
          _p(18, 62).dx,
          _p(18, 62).dy,
          _p(10, 40).dx,
          _p(10, 40).dy,
          _p(22, 26).dx,
          _p(22, 26).dy,
        )
        ..cubicTo(
          _p(32, 15).dx,
          _p(32, 15).dy,
          _p(46, 20).dx,
          _p(46, 20).dy,
          _p(50, 30).dx,
          _p(50, 30).dy,
        )
        ..cubicTo(
          _p(54, 20).dx,
          _p(54, 20).dy,
          _p(68, 15).dx,
          _p(68, 15).dy,
          _p(78, 26).dx,
          _p(78, 26).dy,
        )
        ..cubicTo(
          _p(90, 40).dx,
          _p(90, 40).dy,
          _p(82, 62).dx,
          _p(82, 62).dy,
          _p(50, 84).dx,
          _p(50, 84).dy,
        )
        ..close();
      _neon(h, fill: true);
    });
    // ECG: faint full trace + bright part drawing in.
    final ecg = _poly([
      [4, 52],
      [32, 52],
      [39, 40],
      [47, 66],
      [55, 30],
      [62, 52],
      [96, 52],
    ]);
    _c.drawPath(ecg, _thin(0.2));
    final metric = ecg.computeMetrics().first;
    final head = (t % 1) * metric.length;
    final tail = math.max(0.0, head - metric.length * 0.45);
    _neon(metric.extractPath(tail, head), thin: true);
  }

  void _eye() {
    // Blink near the end of each loop.
    final b = t > 0.86 && t < 0.96
        ? math.sin((t - 0.86) / 0.10 * math.pi)
        : 0.0;
    final open = 1 - 0.92 * b;
    _scaled(50, 50, 1, open, () {
      final e = Path()
        ..moveTo(_p(8, 50).dx, _p(8, 50).dy)
        ..quadraticBezierTo(
          _p(50, 10).dx,
          _p(50, 10).dy,
          _p(92, 50).dx,
          _p(92, 50).dy,
        )
        ..quadraticBezierTo(
          _p(50, 90).dx,
          _p(50, 90).dy,
          _p(8, 50).dx,
          _p(8, 50).dy,
        )
        ..close();
      _neon(e, fill: true);
      // Iris drifts slightly left and right.
      final dx = (math.sin(t * _tau) * 4);
      _circle(50 + dx, 50, 16);
      _c.drawCircle(_p(50 + dx, 50), 7 * _s, _dot());
      _c.drawCircle(
        _p(55 + dx, 45),
        3 * _s,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    });
    final rays = 0.35 + 0.65 * _wave();
    for (final dx in [-1, 1]) {
      _neon(
        _poly([
          [50 + dx * 30, 22],
          [50 + dx * 36, 14],
        ]),
        thin: true,
        alpha: rays,
      );
    }
    _neon(
      _poly([
        [50, 18],
        [50, 8],
      ]),
      thin: true,
      alpha: rays,
    );
  }

  void _sparkle(double x, double y, double r, {double alpha = 1}) {
    final k = 0.6 + 0.4 * alpha;
    _neon(
      Path()
        ..moveTo(_p(x, y - r * k).dx, _p(x, y - r * k).dy)
        ..lineTo(_p(x, y + r * k).dx, _p(x, y + r * k).dy)
        ..moveTo(_p(x - r * k, y).dx, _p(x - r * k, y).dy)
        ..lineTo(_p(x + r * k, y).dx, _p(x + r * k, y).dy),
      thin: true,
      alpha: alpha,
    );
  }

  void _tooth() {
    final t0 = Path()
      ..moveTo(_p(30, 18).dx, _p(30, 18).dy)
      ..cubicTo(
        _p(40, 12).dx,
        _p(40, 12).dy,
        _p(46, 20).dx,
        _p(46, 20).dy,
        _p(50, 20).dx,
        _p(50, 20).dy,
      )
      ..cubicTo(
        _p(54, 20).dx,
        _p(54, 20).dy,
        _p(60, 12).dx,
        _p(60, 12).dy,
        _p(70, 18).dx,
        _p(70, 18).dy,
      )
      ..cubicTo(
        _p(84, 26).dx,
        _p(84, 26).dy,
        _p(78, 50).dx,
        _p(78, 50).dy,
        _p(70, 60).dx,
        _p(70, 60).dy,
      )
      ..cubicTo(
        _p(66, 70).dx,
        _p(66, 70).dy,
        _p(66, 86).dx,
        _p(66, 86).dy,
        _p(60, 88).dx,
        _p(60, 88).dy,
      )
      ..cubicTo(
        _p(54, 90).dx,
        _p(54, 90).dy,
        _p(54, 66).dx,
        _p(54, 66).dy,
        _p(50, 66).dx,
        _p(50, 66).dy,
      )
      ..cubicTo(
        _p(46, 66).dx,
        _p(46, 66).dy,
        _p(46, 90).dx,
        _p(46, 90).dy,
        _p(40, 88).dx,
        _p(40, 88).dy,
      )
      ..cubicTo(
        _p(34, 86).dx,
        _p(34, 86).dy,
        _p(34, 70).dx,
        _p(34, 70).dy,
        _p(30, 60).dx,
        _p(30, 60).dy,
      )
      ..cubicTo(
        _p(22, 50).dx,
        _p(22, 50).dy,
        _p(16, 26).dx,
        _p(16, 26).dy,
        _p(30, 18).dx,
        _p(30, 18).dy,
      )
      ..close();
    _neon(t0, fill: true);
    // Shine sweeps across the crown.
    final sx = 30 + 10 * _wave();
    _neon(
      Path()
        ..moveTo(_p(sx, 32).dx, _p(sx, 32).dy)
        ..quadraticBezierTo(
          _p(sx + 4, 25).dx,
          _p(sx + 4, 25).dy,
          _p(sx + 10, 27).dx,
          _p(sx + 10, 27).dy,
        ),
      thin: true,
    );
    _sparkle(82, 16, 6, alpha: _wave(0, 2));
    _sparkle(90, 34, 3.5, alpha: _wave(0.25, 2));
  }

  void _skin() {
    for (var i = 0; i < 3; i++) {
      final y = 30.0 + i * 16;
      final shift = 4 * math.sin((t + i * 0.2) * _tau);
      final w = Path()..moveTo(_p(6, y).dx, _p(6, y).dy);
      for (var x = 6.0; x <= 70; x += 16) {
        w.quadraticBezierTo(
          _p(x + 8, y - 6 + shift * 0.4).dx,
          _p(x + 8, y - 6 + shift * 0.4).dy,
          _p(x + 16, y).dx,
          _p(x + 16, y).dy,
        );
      }
      _neon(w, thin: i != 0);
    }
    // Magnifier scans left and right.
    final mx = 8 * math.sin(t * _tau);
    _moved(mx, 0, () {
      _circle(66, 62, 16, fill: true);
      _neon(
        _poly([
          [78, 74],
          [92, 88],
        ]),
      );
      _c.drawCircle(_p(62, 58), 3.5 * _s, _dot());
    });
  }

  void _lungs() {
    final breathe = 1 + 0.06 * math.sin(t * _tau);
    _neon(
      Path()
        ..moveTo(_p(50, 10).dx, _p(50, 10).dy)
        ..lineTo(_p(50, 40).dx, _p(50, 40).dy)
        ..moveTo(_p(50, 40).dx, _p(50, 40).dy)
        ..quadraticBezierTo(
          _p(46, 46).dx,
          _p(46, 46).dy,
          _p(40, 48).dx,
          _p(40, 48).dy,
        )
        ..moveTo(_p(50, 40).dx, _p(50, 40).dy)
        ..quadraticBezierTo(
          _p(54, 46).dx,
          _p(54, 46).dy,
          _p(60, 48).dx,
          _p(60, 48).dy,
        ),
      thin: true,
    );
    for (final side in [-1.0, 1.0]) {
      double x(double v) => 50 + side * v;
      _scaled(x(24), 56, breathe, breathe, () {
        final l = Path()
          ..moveTo(_p(x(8), 30).dx, _p(x(8), 30).dy)
          ..cubicTo(
            _p(x(30), 18).dx,
            _p(x(30), 18).dy,
            _p(x(44), 50).dx,
            _p(x(44), 50).dy,
            _p(x(40), 80).dx,
            _p(x(40), 80).dy,
          )
          ..cubicTo(
            _p(x(36), 92).dx,
            _p(x(36), 92).dy,
            _p(x(12), 90).dx,
            _p(x(12), 90).dy,
            _p(x(8), 78).dx,
            _p(x(8), 78).dy,
          )
          ..close();
        _neon(l, fill: true);
      });
    }
  }

  void _brain() {
    for (final side in [-1.0, 1.0]) {
      double x(double v) => 50 + side * v;
      final b = Path()
        ..moveTo(_p(x(2), 20).dx, _p(x(2), 20).dy)
        ..cubicTo(
          _p(x(20), 6).dx,
          _p(x(20), 6).dy,
          _p(x(40), 14).dx,
          _p(x(40), 14).dy,
          _p(x(40), 30).dx,
          _p(x(40), 30).dy,
        )
        ..cubicTo(
          _p(x(50), 40).dx,
          _p(x(50), 40).dy,
          _p(x(46), 62).dx,
          _p(x(46), 62).dy,
          _p(x(34), 66).dx,
          _p(x(34), 66).dy,
        )
        ..cubicTo(
          _p(x(30), 80).dx,
          _p(x(30), 80).dy,
          _p(x(12), 82).dx,
          _p(x(12), 82).dy,
          _p(x(2), 74).dx,
          _p(x(2), 74).dy,
        )
        ..close();
      _neon(b, fill: true);
      // Folds light up in turn, like neurons firing.
      _neon(
        Path()
          ..moveTo(_p(x(12), 30).dx, _p(x(12), 30).dy)
          ..quadraticBezierTo(
            _p(x(26), 32).dx,
            _p(x(26), 32).dy,
            _p(x(24), 44).dx,
            _p(x(24), 44).dy,
          ),
        thin: true,
        alpha: 0.3 + 0.7 * _wave(side > 0 ? 0 : 0.5),
      );
      _neon(
        Path()
          ..moveTo(_p(x(10), 54).dx, _p(x(10), 54).dy)
          ..quadraticBezierTo(
            _p(x(24), 52).dx,
            _p(x(24), 52).dy,
            _p(x(30), 60).dx,
            _p(x(30), 60).dy,
          ),
        thin: true,
        alpha: 0.3 + 0.7 * _wave(side > 0 ? 0.25 : 0.75),
      );
    }
    _c.drawCircle(_p(50, 92), 3 * _s, _dot(0.4 + 0.6 * _wave(0, 2)));
  }

  void _moon() {
    final bob = 2 * math.sin(t * _tau);
    _moved(0, bob, () {
      final m = Path()
        ..addOval(Rect.fromCircle(center: _p(46, 54), radius: 32 * _s));
      final cut = Path()
        ..addOval(Rect.fromCircle(center: _p(64, 42), radius: 28 * _s));
      _neon(Path.combine(PathOperation.difference, m, cut), fill: true);
    });
    _sparkle(74, 18, 6, alpha: _wave(0));
    _sparkle(88, 40, 4, alpha: _wave(0.33));
    _c.drawCircle(_p(84, 66), 2.5 * _s, _dot(_wave(0.66)));
  }

  void _ear() {
    final e = Path()
      ..moveTo(_p(30, 70).dx, _p(30, 70).dy)
      ..cubicTo(
        _p(18, 50).dx,
        _p(18, 50).dy,
        _p(20, 18).dx,
        _p(20, 18).dy,
        _p(44, 14).dx,
        _p(44, 14).dy,
      )
      ..cubicTo(
        _p(64, 12).dx,
        _p(64, 12).dy,
        _p(70, 32).dx,
        _p(70, 32).dy,
        _p(62, 46).dx,
        _p(62, 46).dy,
      )
      ..cubicTo(
        _p(54, 58).dx,
        _p(54, 58).dy,
        _p(50, 62).dx,
        _p(50, 62).dy,
        _p(50, 74).dx,
        _p(50, 74).dy,
      )
      ..cubicTo(
        _p(50, 86).dx,
        _p(50, 86).dy,
        _p(36, 90).dx,
        _p(36, 90).dy,
        _p(30, 82).dx,
        _p(30, 82).dy,
      );
    _neon(e);
    _neon(
      Path()
        ..moveTo(_p(36, 40).dx, _p(36, 40).dy)
        ..quadraticBezierTo(
          _p(38, 26).dx,
          _p(38, 26).dy,
          _p(50, 28).dx,
          _p(50, 28).dy,
        )
        ..quadraticBezierTo(
          _p(56, 34).dx,
          _p(56, 34).dy,
          _p(46, 44).dx,
          _p(46, 44).dy,
        ),
      thin: true,
    );
    // Sound waves ripple outward.
    for (var i = 0; i < 3; i++) {
      final r = 10.0 + i * 9;
      _neon(
        Path()..addArc(
          Rect.fromCircle(center: _p(70, 50), radius: r * _s),
          -math.pi / 4,
          math.pi / 2,
        ),
        thin: true,
        alpha: 0.15 + 0.85 * _wave(i * 0.18),
      );
    }
  }

  void _glasses() {
    _circle(30, 54, 18, fill: true);
    _circle(70, 54, 18, fill: true);
    _neon(
      Path()
        ..moveTo(_p(48, 52).dx, _p(48, 52).dy)
        ..quadraticBezierTo(
          _p(50, 46).dx,
          _p(50, 46).dy,
          _p(52, 52).dx,
          _p(52, 52).dy,
        )
        ..moveTo(_p(12, 50).dx, _p(12, 50).dy)
        ..lineTo(_p(4, 38).dx, _p(4, 38).dy)
        ..moveTo(_p(88, 50).dx, _p(88, 50).dy)
        ..lineTo(_p(96, 38).dx, _p(96, 38).dy),
      thin: true,
    );
    // Glint slides across both lenses.
    final g = -6 + 12 * _wave();
    for (final cx in [30.0, 70.0]) {
      _neon(
        _poly([
          [cx - 8 + g, 48],
          [cx - 2 + g, 42],
        ]),
        thin: true,
      );
    }
    _sparkle(50, 18, 6, alpha: _wave(0, 2));
  }

  void _runner() {
    final bob = -2.5 * (math.sin(t * 2 * _tau)).abs();
    _moved(0, bob, () {
      _circle(58, 16, 8, fill: true);
      _neon(
        Path()
          ..moveTo(_p(54, 28).dx, _p(54, 28).dy)
          ..lineTo(_p(46, 54).dx, _p(46, 54).dy)
          ..moveTo(_p(52, 34).dx, _p(52, 34).dy)
          ..lineTo(_p(34, 40).dx, _p(34, 40).dy)
          ..lineTo(_p(26, 52).dx, _p(26, 52).dy)
          ..moveTo(_p(52, 34).dx, _p(52, 34).dy)
          ..lineTo(_p(66, 46).dx, _p(66, 46).dy)
          ..lineTo(_p(80, 42).dx, _p(80, 42).dy)
          ..moveTo(_p(46, 54).dx, _p(46, 54).dy)
          ..lineTo(_p(62, 68).dx, _p(62, 68).dy)
          ..lineTo(_p(58, 88).dx, _p(58, 88).dy)
          ..moveTo(_p(46, 54).dx, _p(46, 54).dy)
          ..lineTo(_p(34, 72).dx, _p(34, 72).dy)
          ..lineTo(_p(16, 76).dx, _p(16, 76).dy),
      );
    });
    // Speed lines stream backwards.
    for (var i = 0; i < 3; i++) {
      final y = 30.0 + i * 12;
      final shift = ((t * 2 + i * 0.3) % 1) * 8;
      _neon(
        _poly([
          [4 + i * 2 - shift + 6, y],
          [16 + i * 2 - shift + 6, y],
        ]),
        thin: true,
        alpha: 1 - shift / 10,
      );
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.t != t ||
      old.category != category ||
      old.color != color ||
      old.glow != glow;
}
