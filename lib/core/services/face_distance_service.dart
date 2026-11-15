// Face distance for the acuity test (ALG-CAP-15 / Gate G-33, Spec §9
// MOV-10: 40 ± 5 cm live).
//
// The document uses MediaPipe Iris (11.7 mm iris) and a per-device focal
// length. Neither exists here, so this is a stand-in [DER]: the ML Kit eye
// landmarks give the inter-pupillary distance in pixels; with a focal
// length the pinhole model gives the distance. The focal length comes from a
// one-time 40 cm calibration ('measured'), else from a typical selfie field
// of view ('estimated'). When no face is tracked the test falls back to the
// document's manual "hold at 40 cm" prompt ('manual').
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/algorithms/vision_engines.dart';
import 'live_camera_service.dart';

enum DistanceMode { measured, estimated, manual }

class DistanceReading {
  const DistanceReading({
    required this.cm,
    required this.mode,
    required this.reliable,
  });

  final double? cm;
  final DistanceMode mode;

  /// Face tracked and the eye spacing stable over the last half second.
  final bool reliable;

  bool get inRange => cm != null && reliable && FaceDistance.inRange(cm!);
  bool get tooClose =>
      cm != null &&
      reliable &&
      cm! < FaceDistance.targetCm - FaceDistance.toleranceCm;
  bool get tooFar =>
      cm != null &&
      reliable &&
      cm! > FaceDistance.targetCm + FaceDistance.toleranceCm;
}

class FaceDistanceService extends ChangeNotifier {
  FaceDistanceService({this.camera, this.calibratedFocalPx, bool? simulated})
    : simulated = simulated ?? isFlutterTest {
    if (this.simulated) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _simTick(),
      );
    } else {
      camera?.addListener(_onCamera);
    }
  }

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  final BiometricCameraController? camera;
  final double? calibratedFocalPx;
  final bool simulated;

  /// Test Controls: simulated distance in cm (null = 40 ± jitter).
  double? simulatedCm;

  DistanceReading reading = const DistanceReading(
    cm: null,
    mode: DistanceMode.manual,
    reliable: false,
  );

  /// Last raw eye gap (px) for the calibration sheet.
  double? lastEyeGapPx;
  double? lastImageWidthPx;

  Timer? _timer;
  double? _ema;
  final List<double> _recent = [];
  int _simTicks = 0;

  void _simTick() {
    _simTicks++;
    final cm = simulatedCm ?? (40 + math.sin(_simTicks / 3) * 1.5);
    lastEyeGapPx = 90;
    lastImageWidthPx = 480;
    _push(cm, DistanceMode.measured);
  }

  void _onCamera() {
    final c = camera;
    if (c == null) return;
    final gap = c.eyeGapPx;
    final w = c.eyeGapImageWidthPx;
    if (gap == null || w == null || gap <= 0) {
      _recent.clear();
      if (reading.reliable || reading.cm != null) {
        reading = DistanceReading(
          cm: null,
          mode: calibratedFocalPx != null
              ? DistanceMode.measured
              : DistanceMode.estimated,
          reliable: false,
        );
        notifyListeners();
      }
      return;
    }
    lastEyeGapPx = gap;
    lastImageWidthPx = w;
    final focal = calibratedFocalPx ?? FaceDistance.focalPxFromFov(w);
    final cm = FaceDistance.distanceCm(featurePx: gap, focalPx: focal);
    _push(
      cm,
      calibratedFocalPx != null
          ? DistanceMode.measured
          : DistanceMode.estimated,
    );
  }

  void _push(double cm, DistanceMode mode) {
    _ema = _ema == null ? cm : _ema! * 0.6 + cm * 0.4;
    _recent.add(cm);
    if (_recent.length > 4) _recent.removeAt(0);
    var reliable = _recent.length >= 2;
    if (reliable) {
      final mn = _recent.reduce(math.min);
      final mx = _recent.reduce(math.max);
      reliable = (mx - mn) / math.max(1e-6, _ema!) <= 0.16;
    }
    reading = DistanceReading(cm: _ema, mode: mode, reliable: reliable);
    notifyListeners();
  }

  /// Focal length implied by the current eye gap at a known distance.
  double? calibrationFocalPx({double knownDistanceCm = 40}) {
    final gap = lastEyeGapPx;
    if (gap == null || gap <= 0) return null;
    return FaceDistance.focalPxFromCalibration(
      featurePx: gap,
      knownDistanceCm: knownDistanceCm,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    camera?.removeListener(_onCamera);
    super.dispose();
  }
}
