// Hand tracking for the video finger-tapping test (ALG-MOV-01).
//
// Backends, best first:
//  • landmarks — MediaPipe Hand Landmarker (hand_landmarker plugin, Android):
//    21 normalised landmarks; thumb tip 4, index tip 8, wrist 0, middle MCP 9.
//    GPU delegate first, CPU if the GPU delegate fails to initialise.
//  • proxy [DER] — when no landmark model is available (iOS, desktop) or the
//    landmarker never answers: the centre-region luma pattern says a hand is
//    in frame, and its oscillation is used as the tap series.
//  • simulated — FLUTTER_TEST / Test Controls: a synthetic tapping series.
//
// All landmarks are delivered in *display* space: upright (MediaPipe applies
// the sensor rotation) and mirrored for the selfie camera, so x,y map
// straight onto the mirrored front-camera preview.
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as hl;

import '../domain/algorithms/movement_engines.dart';

class HandPoint {
  const HandPoint(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// Where the whole hand has to be. The camera image is cover-fitted into
/// the screen, so only a central strip of it is visible; the guide is
/// defined inside that *visible* strip (in normalised image coordinates)
/// and the overlay draws it through the same cover transform. What the user
/// sees is therefore exactly what the check tests.
class HandGuide {
  HandGuide._();

  /// Hand size = wrist (0) → middle-finger MCP (9) distance in height units.
  /// Outside this window the hand is too far for stable landmarks, or so
  /// close it will leave the frame while tapping.
  static const double minHandSize = 0.09;
  static const double maxHandSize = 0.46;

  /// Share of the 21 landmarks that must lie inside the guide.
  static const double minInsideShare = 0.90;

  /// Visible part of the normalised image for a surface of [surface] pixels
  /// showing a preview of [aspect] (upright width ÷ height) with cover fit.
  static Rect visibleRect(Size surface, double aspect) {
    final a = aspect > 0 ? aspect : 0.75;
    if (surface.width <= 0 || surface.height <= 0) {
      return const Rect.fromLTRB(0, 0, 1, 1);
    }
    final scale = math.max(surface.width / a, surface.height);
    final drawnW = a * scale;
    final drawnH = scale;
    final ox = (surface.width - drawnW) / 2;
    final oy = (surface.height - drawnH) / 2;
    return Rect.fromLTRB(
      (-ox / drawnW).clamp(0.0, 1.0),
      (-oy / drawnH).clamp(0.0, 1.0),
      ((surface.width - ox) / drawnW).clamp(0.0, 1.0),
      ((surface.height - oy) / drawnH).clamp(0.0, 1.0),
    );
  }

  /// The guide rectangle (normalised image coordinates): the visible strip
  /// inset by a side margin, below the live counter and above the dock.
  static Rect forViewport(Size surface, double aspect) {
    final v = visibleRect(surface, aspect);
    return Rect.fromLTRB(
      v.left + v.width * 0.08,
      v.top + v.height * 0.17,
      v.right - v.width * 0.08,
      v.top + v.height * 0.72,
    );
  }

  /// Default guide for a tall phone (used before layout is known).
  static final Rect fallbackRect = forViewport(const Size(390, 844), 0.75);

  /// Position check for a landmark frame against [guide].
  static HandStatus statusFor(HandFrame f, Rect guide) {
    if (!f.handInFrame) return HandStatus.noHand;
    final s = f.handSize;
    final pts = f.landmarks;
    if (s == null || pts == null || pts.isEmpty) {
      return HandStatus.ok; // proxy backend: presence only
    }
    var inside = 0;
    for (final p in pts) {
      if (p.x >= guide.left &&
          p.x <= guide.right &&
          p.y >= guide.top &&
          p.y <= guide.bottom) {
        inside++;
      }
    }
    if (inside / pts.length < minInsideShare) return HandStatus.partlyOutside;
    if (s < minHandSize) return HandStatus.tooFar;
    if (s > maxHandSize) return HandStatus.tooClose;
    return HandStatus.ok;
  }
}

/// What the tracker sees, in plain terms for the coaching line.
enum HandStatus { noHand, tooFar, tooClose, partlyOutside, ok }

/// One analysed camera frame.
class HandFrame {
  const HandFrame({
    required this.t,
    required this.handInFrame,
    this.landmarks,
    this.normDistance,
    this.handSize,
    this.lightOk,
  });

  /// Seconds since the tracker started.
  final double t;

  /// A hand is detected (landmarks or proxy signal). Position checks are
  /// done by [HandGuide.statusFor] against the on-screen guide.
  final bool handInFrame;

  /// 21 normalised display-space points when landmarks are available.
  final List<HandPoint>? landmarks;

  /// Thumb-tip–index-tip distance ÷ wrist–middle-MCP distance (spec), or the
  /// proxy oscillation value.
  final double? normDistance;

  /// Wrist–middle-MCP distance in height units (landmarks only).
  final double? handSize;

  /// Enough light on the frame (null when not measured).
  final bool? lightOk;
}

abstract class HandTrackingService {
  String get backend;
  Stream<HandFrame> get frames;

  /// Feed a camera frame (YUV420 on Android). No-op for simulated.
  void onCameraFrame(CameraImage image, CameraDescription description) {}

  Future<void> start();
  Future<void> dispose();

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Picks the best available backend.
  static HandTrackingService create({
    bool forceSimulated = false,
    double simulatedHz = 4,
    double simulatedDecrementPct = 8,
  }) {
    if (isFlutterTest || forceSimulated) {
      return SimulatedHandTracker(
        hz: simulatedHz,
        decrementPct: simulatedDecrementPct,
      );
    }
    if (!kIsWeb && Platform.isAndroid) return LandmarkHandTracker();
    return ProxyHandTracker();
  }

  /// Spec: thumb tip (4) to index tip (8), normalised by wrist (0) to middle
  /// MCP (9) so camera distance does not matter. [aspect] = width / height
  /// of the upright image, so x and y are measured in the same units.
  static double normalisedThumbIndexDistance(
    List<HandPoint> p, {
    double aspect = 0.75,
  }) {
    final size = _dist(p[0], p[9], aspect);
    if (size <= 1e-6) return 0;
    return _dist(p[4], p[8], aspect) / size;
  }

  static double _dist(HandPoint a, HandPoint b, double aspect) {
    final dx = (a.x - b.x) * aspect;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Mean luma of the Y plane on a coarse grid (0..255).
  static double meanLuma(CameraImage image) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final w = image.width;
    final h = image.height;
    if (bytes.isEmpty || w == 0 || h == 0) return 0;
    final stride = plane.bytesPerRow > 0 ? plane.bytesPerRow : w;
    final pix = plane.bytesPerPixel ?? 1;
    var sum = 0.0;
    var n = 0;
    for (var y = 0; y < h; y += math.max(1, h ~/ 20)) {
      for (var x = 0; x < w; x += math.max(1, w ~/ 20)) {
        final idx = y * stride + x * pix;
        if (idx >= bytes.length) continue;
        sum += bytes[idx];
        n++;
      }
    }
    return n == 0 ? 0 : sum / n;
  }

  /// Whether the preview is mirrored relative to the upright image: the
  /// camera plugin shows the selfie lens as a mirror.
  static bool previewMirrored(CameraDescription d) =>
      d.lensDirection == CameraLensDirection.front;

  /// Raw sensor-frame landmark (normalised to the landscape sensor image) →
  /// upright, preview-space point. [rotation] is the clockwise rotation the
  /// preview applies to the sensor image (`sensorOrientation`); [mirror]
  /// flips x afterwards for the selfie lens.
  ///
  /// Checked against the plugin example: for the usual front camera at 270°
  /// a raw (x, y) lands at (1 − y, 1 − x).
  static HandPoint toDisplaySpace(
    double x,
    double y,
    double z, {
    required int rotation,
    required bool mirror,
  }) {
    double ux, uy;
    switch (rotation % 360) {
      case 90:
        ux = 1 - y;
        uy = x;
      case 180:
        ux = 1 - x;
        uy = 1 - y;
      case 270:
        ux = y;
        uy = 1 - x;
      default:
        ux = x;
        uy = y;
    }
    return HandPoint(mirror ? 1 - ux : ux, uy, z);
  }
}

/// MediaPipe Hand Landmarker via the hand_landmarker plugin (Android).
class LandmarkHandTracker extends HandTrackingService {
  hl.HandLandmarkerPlugin? _plugin;
  StreamSubscription<List<hl.Hand>>? _sub;
  StreamSubscription<HandFrame>? _proxySub;
  ProxyHandTracker? _proxy;
  final _ctrl = StreamController<HandFrame>.broadcast();
  final Stopwatch _clock = Stopwatch();
  DateTime _lastFed = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _firstFedAt;
  DateTime? _lastResultAt;
  int _minGapMs = 30;
  int _fed = 0;
  bool _failed = false;
  bool _mirror = true;
  int _rotation = 270;
  double _aspect = 0.75;
  bool? _lightOk;
  String _delegate = 'gpu';

  @override
  String get backend => _failed ? 'proxy' : 'landmarks';

  /// 'gpu' or 'cpu' once initialised (operator view).
  String get delegate => _delegate;

  @override
  Stream<HandFrame> get frames => _ctrl.stream;

  @override
  Future<void> start() async {
    _clock.start();
    final created =
        _tryCreate(hl.HandLandmarkerDelegate.gpu) ||
        _tryCreate(hl.HandLandmarkerDelegate.cpu);
    if (!created) _switchToProxy();
  }

  bool _tryCreate(hl.HandLandmarkerDelegate delegate) {
    try {
      _plugin = hl.HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.5,
        delegate: delegate,
      );
      _delegate = delegate == hl.HandLandmarkerDelegate.gpu ? 'gpu' : 'cpu';
      _sub = _plugin!.landmarkStream.listen(_onHands, onError: (_) {});
      return true;
    } catch (_) {
      try {
        _plugin?.dispose();
      } catch (_) {}
      _plugin = null;
      return false;
    }
  }

  /// The landmarker is unusable: carry on with the luma proxy so the test
  /// still runs, flagged as 'proxy' on the result.
  void _switchToProxy() {
    if (_failed) return;
    _failed = true;
    _sub?.cancel();
    _sub = null;
    try {
      _plugin?.dispose();
    } catch (_) {}
    _plugin = null;
    final p = ProxyHandTracker();
    _proxy = p;
    p.start();
    _proxySub = p.frames.listen((f) {
      if (!_ctrl.isClosed) _ctrl.add(f);
    });
  }

  void _onHands(List<hl.Hand> hands) {
    _lastResultAt = DateTime.now();
    final t = _clock.elapsedMicroseconds / 1e6;
    if (hands.isEmpty || hands.first.landmarks.length < 21) {
      _ctrl.add(HandFrame(t: t, handInFrame: false, lightOk: _lightOk));
      return;
    }
    final lm = hands.first.landmarks;
    // MediaPipe reports landmarks in the *raw sensor frame* (normalised to
    // the landscape sensor width/height) even when a rotation is passed —
    // the plugin's own example rotates the canvas by sensorOrientation and
    // flips for the selfie lens. Do the same per point here so every
    // consumer gets upright, preview-space coordinates.
    final raw = [
      for (final l in lm)
        HandTrackingService.toDisplaySpace(
          l.x,
          l.y,
          l.z,
          rotation: _rotation,
          mirror: _mirror,
        ),
    ];
    final pts = _smooth(raw, t);
    _ctrl.add(
      HandFrame(
        t: t,
        handInFrame: true,
        landmarks: pts,
        // Measurement from the raw (unsmoothed) points: smoothing is for
        // the eye, not the tap amplitude.
        normDistance: HandTrackingService.normalisedThumbIndexDistance(
          raw,
          aspect: _aspect,
        ),
        handSize: HandTrackingService._dist(raw[0], raw[9], _aspect),
        lightOk: _lightOk,
      ),
    );
  }

  List<HandPoint>? _prev;
  double _prevT = -1;

  /// Speed-adaptive smoothing (one-euro style): still joints are filtered
  /// hard so the skeleton does not shiver, fast joints follow at once so a
  /// tap is never lagged. Resets after a gap so a re-found hand snaps in.
  List<HandPoint> _smooth(List<HandPoint> cur, double t) {
    final prev = _prev;
    if (prev == null || prev.length != cur.length || t - _prevT > 0.2) {
      _prev = cur;
      _prevT = t;
      return cur;
    }
    final out = List<HandPoint>.generate(cur.length, (i) {
      final a = prev[i];
      final b = cur[i];
      final dx = (b.x - a.x) * _aspect;
      final dy = b.y - a.y;
      final speed = math.sqrt(dx * dx + dy * dy); // height units per frame
      // 0.004 ≈ landmark jitter at rest, 0.03 ≈ a brisk tap per frame.
      final k = ((speed - 0.004) / 0.026).clamp(0.0, 1.0);
      final alpha = 0.30 + 0.70 * k;
      return HandPoint(
        a.x + (b.x - a.x) * alpha,
        a.y + (b.y - a.y) * alpha,
        a.z + (b.z - a.z) * alpha,
      );
    });
    _prev = out;
    _prevT = t;
    return out;
  }

  @override
  void onCameraFrame(CameraImage image, CameraDescription description) {
    if (_failed) {
      _proxy?.onCameraFrame(image, description);
      return;
    }
    final p = _plugin;
    if (p == null) return;
    final now = DateTime.now();
    if (now.difference(_lastFed).inMilliseconds < _minGapMs) return;
    _lastFed = now;
    _firstFedAt ??= now;
    if (image.planes.length < 3) return; // needs YUV420 (three planes)
    _mirror = HandTrackingService.previewMirrored(description);
    _rotation = description.sensorOrientation;
    final rotated =
        description.sensorOrientation == 90 ||
        description.sensorOrientation == 270;
    final upW = rotated ? image.height : image.width;
    final upH = rotated ? image.width : image.height;
    if (upH > 0) _aspect = upW / upH;
    if (_fed++ % 8 == 0) {
      _lightOk = HandTrackingService.meanLuma(image) >= 55;
    }
    // Watchdog: frames go in, nothing ever comes back → proxy.
    final last = _lastResultAt;
    if ((last == null && now.difference(_firstFedAt!).inSeconds >= 4) ||
        (last != null && now.difference(last).inSeconds >= 4)) {
      _switchToProxy();
      _proxy?.onCameraFrame(image, description);
      return;
    }
    // The YUV→RGB conversion runs on the calling thread before MediaPipe's
    // own worker takes over, so pace the feed to what the device sustains
    // (aim ≥ 30 fps, never more than ~60 % of the frame budget).
    final sw = Stopwatch()..start();
    try {
      p.processFrame(image, description.sensorOrientation);
    } catch (_) {
      _switchToProxy();
      return;
    }
    sw.stop();
    _minGapMs = (sw.elapsedMilliseconds * 1.0).round().clamp(16, 100);
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _proxySub?.cancel();
    await _proxy?.dispose();
    try {
      _plugin?.dispose();
    } catch (_) {}
    await _ctrl.close();
  }

  /// Kept for callers that used the old static helper.
  static double normalisedThumbIndexDistance(List<HandPoint> p) =>
      HandTrackingService.normalisedThumbIndexDistance(p);
}

/// [DER] stand-in when no landmark model is available: hand presence from the
/// centre-region brightness pattern and taps from its oscillation. Reported
/// as backend 'proxy' and results carry "landmark model pending".
class ProxyHandTracker extends HandTrackingService {
  final _ctrl = StreamController<HandFrame>.broadcast();
  final Stopwatch _clock = Stopwatch();
  DateTime _lastFed = DateTime.fromMillisecondsSinceEpoch(0);
  double _ema = 0;
  bool _emaInit = false;

  @override
  String get backend => 'proxy';

  @override
  Stream<HandFrame> get frames => _ctrl.stream;

  @override
  Future<void> start() async => _clock.start();

  @override
  void onCameraFrame(CameraImage image, CameraDescription description) {
    final now = DateTime.now();
    if (now.difference(_lastFed).inMilliseconds < 33) return;
    _lastFed = now;
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final w = image.width;
    final h = image.height;
    if (bytes.isEmpty || w == 0 || h == 0) return;
    final stride = plane.bytesPerRow > 0 ? plane.bytesPerRow : w;
    final pix = plane.bytesPerPixel ?? 1;
    // Centre region: mean luma and share of mid-bright (skin-like) pixels.
    var sum = 0.0, n = 0, lit = 0;
    for (var y = (h * 0.2).floor(); y < h * 0.8; y += math.max(1, h ~/ 24)) {
      for (var x = (w * 0.2).floor(); x < w * 0.8; x += math.max(1, w ~/ 24)) {
        final idx = y * stride + x * pix;
        if (idx >= bytes.length) continue;
        final v = bytes[idx];
        sum += v;
        n++;
        if (v >= 90 && v <= 230) lit++;
      }
    }
    if (n == 0) return;
    final mean = sum / n;
    final litFrac = lit / n;
    if (!_emaInit) {
      _ema = mean;
      _emaInit = true;
    }
    _ema = 0.9 * _ema + 0.1 * mean;
    final t = _clock.elapsedMicroseconds / 1e6;
    final inFrame = litFrac >= 0.25 && litFrac <= 0.95;
    // Oscillation around the slow mean, scaled to roughly 0..1.
    final osc = ((mean - _ema) / 40.0 + 0.5).clamp(0.0, 1.0);
    _ctrl.add(
      HandFrame(
        t: t,
        handInFrame: inFrame,
        normDistance: inFrame ? osc : null,
        lightOk: mean >= 55,
      ),
    );
  }

  @override
  Future<void> dispose() async => _ctrl.close();
}

/// Deterministic tapping series for tests and Test Controls.
class SimulatedHandTracker extends HandTrackingService {
  SimulatedHandTracker({this.hz = 4, this.decrementPct = 8, this.fps = 30});

  final double hz;
  final double decrementPct;
  final double fps;

  /// Test Controls: pretend the hand left the frame.
  bool simulateOutOfFrame = false;

  final _ctrl = StreamController<HandFrame>.broadcast();
  Timer? _timer;
  late final List<TapSample> _series = MovementSynthetic.tapping(
    fps: fps,
    hz: hz,
    decrementPct: decrementPct,
    seconds: 60,
  );

  @override
  String get backend => 'simulated';

  @override
  Stream<HandFrame> get frames => _ctrl.stream;

  @override
  Future<void> start() async {
    var tick = 0;
    _timer = Timer.periodic(Duration(milliseconds: (1000 / fps).round()), (_) {
      final i = (tick++).clamp(0, _series.length - 1);
      final t = i / fps;
      if (simulateOutOfFrame) {
        _ctrl.add(HandFrame(t: t, handInFrame: false, lightOk: true));
        return;
      }
      final d = _series[i].normDistance;
      // Synthetic landmarks: a palm outline inside the guide that opens with
      // the tap (thumb tip 4 and index tip 8 move apart).
      final pts = List<HandPoint>.generate(21, (k) {
        final ang = k / 21 * 2 * math.pi;
        return HandPoint(
          0.5 + 0.14 * math.cos(ang),
          0.46 + 0.16 * math.sin(ang),
          0,
        );
      });
      final spread = 0.05 + 0.12 * d;
      pts[4] = HandPoint(0.5 - spread, 0.32, 0);
      pts[8] = HandPoint(0.5 + spread, 0.30, 0);
      _ctrl.add(
        HandFrame(
          t: t,
          handInFrame: true,
          landmarks: pts,
          normDistance: d,
          handSize: 0.2,
          lightOk: true,
        ),
      );
    });
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _ctrl.close();
  }
}
