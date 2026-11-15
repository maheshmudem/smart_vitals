// Motion sensors for the movement tests (Spec §9: accelerometer 50 Hz for
// gait / sit-to-stand, gyroscope 100 Hz for tremor; Gate G-13).
//
// Wraps sensors_plus. On desktop, web or when the plugin is missing the
// service reports "unavailable" so G-13 blocks the test; under FLUTTER_TEST
// (and when Test Controls ask for it) it streams deterministic synthetic
// signals from [MovementSynthetic] on a timer so flows can run end to end.
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../domain/algorithms/movement_engines.dart';

enum MotionAvailability { available, unavailable, simulated }

/// What the simulated streams should look like.
enum SimulatedMotionProfile {
  /// 8 s of normal walking (1.8 Hz) then standing still → ≈ 1.2 m/s.
  walking,

  /// 14 s of slow walking (1.4 Hz) then standing still → ≈ 0.7 m/s.
  walkingSlow,
  standingStill,

  /// 12 stands in 30 s.
  sitToStand,

  /// 8 stands in 30 s (below the 60–64 norm).
  sitToStandLow,

  /// 5 Hz, 30 deg/s (Parkinsonian range).
  tremor,

  /// 8 Hz, 12 deg/s (essential / physiological range).
  tremorEssential,
  stillHand,
  grossMovement,
  dropout,

  /// Phone held flat in the outstretched hand for 10 s, steady.
  armHoldSteady,

  /// Same, but the arm sinks about 25° over the hold (MOV-07 positive).
  armHoldDrift,
}

class MotionStreamStats {
  MotionStreamStats();

  int samples = 0;
  int dropped = 0;
  double? firstT;
  double? lastT;
  double _medianGap = 0;
  final List<double> _gaps = [];

  void add(double t) {
    if (lastT != null) {
      final g = t - lastT!;
      _gaps.add(g);
      if (_gaps.length > 50) _gaps.removeAt(0);
      _medianGap = Dsp.median(_gaps);
      if (_medianGap > 0 && g > 2.5 * _medianGap) {
        dropped += (g / _medianGap).round() - 1;
      }
    }
    firstT ??= t;
    lastT = t;
    samples++;
  }

  double get achievedHz => _medianGap > 0 ? 1 / _medianGap : 0;
  double get seconds => firstT == null || lastT == null ? 0 : lastT! - firstT!;
}

class MotionSensorService {
  MotionSensorService._();

  static final MotionSensorService instance = MotionSensorService._();

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Test Controls: force simulated streams on a device / desktop.
  bool forceSimulated = false;
  SimulatedMotionProfile simulatedProfile = SimulatedMotionProfile.walking;

  /// Test Controls / tests: behave as a phone without an accelerometer.
  bool simulateUnavailable = false;

  /// Test hook: delay before the simulated stream delivers its first sample
  /// (a real sensor often comes up 1–3 s after listen()).
  Duration simulatedStartDelay = Duration.zero;

  MotionAvailability? _probed;

  bool get _platformHasSensors =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get simulated => isFlutterTest || forceSimulated || !_platformHasSensors;

  /// Checks that the accelerometer delivers events (300 ms window).
  Future<MotionAvailability> probe({bool refresh = false}) async {
    if (simulateUnavailable) return MotionAvailability.unavailable;
    if (simulated) return MotionAvailability.simulated;
    if (_probed != null && !refresh) return _probed!;
    try {
      final completer = Completer<bool>();
      late StreamSubscription<AccelerometerEvent> sub;
      sub =
          accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 20),
          ).listen(
            (_) {
              if (!completer.isCompleted) completer.complete(true);
            },
            onError: (_) {
              if (!completer.isCompleted) completer.complete(false);
            },
          );
      final ok = await completer.future.timeout(
        const Duration(milliseconds: 600),
        onTimeout: () => false,
      );
      await sub.cancel();
      _probed = ok
          ? MotionAvailability.available
          : MotionAvailability.unavailable;
    } on MissingPluginException {
      _probed = MotionAvailability.unavailable;
    } catch (_) {
      _probed = MotionAvailability.unavailable;
    }
    return _probed!;
  }

  /// Accelerometer in m/s² (gravity included), [hz] requested.
  Stream<MotionSample> accelerometer({double hz = 50}) {
    if (simulateUnavailable) {
      return Stream<MotionSample>.error(
        StateError('accelerometer unavailable'),
      );
    }
    if (simulated) return _simulatedAccel(hz);
    final t0 = DateTime.now();
    return accelerometerEventStream(
      samplingPeriod: Duration(microseconds: (1e6 / hz).round()),
    ).map(
      (e) => MotionSample(
        e.timestamp.difference(t0).inMicroseconds / 1e6,
        e.x,
        e.y,
        e.z,
      ),
    );
  }

  /// Gyroscope in deg/s, [hz] requested.
  Stream<MotionSample> gyroscope({double hz = 100}) {
    if (simulated) return _simulatedGyro(hz);
    final t0 = DateTime.now();
    const r2d = 180 / math.pi;
    return gyroscopeEventStream(
      samplingPeriod: Duration(microseconds: (1e6 / hz).round()),
    ).map(
      (e) => MotionSample(
        e.timestamp.difference(t0).inMicroseconds / 1e6,
        e.x * r2d,
        e.y * r2d,
        e.z * r2d,
      ),
    );
  }

  // --- simulation -----------------------------------------------------------

  Stream<MotionSample> _simulatedAccel(double hz) {
    final profile = simulatedProfile;
    final data = switch (profile) {
      SimulatedMotionProfile.sitToStand => MovementSynthetic.sitToStand(
        seconds: 40,
        fs: hz,
      ),
      SimulatedMotionProfile.sitToStandLow => MovementSynthetic.sitToStand(
        cycles: 8,
        seconds: 30,
        fs: hz,
      ),
      SimulatedMotionProfile.standingStill || SimulatedMotionProfile.dropout =>
        MovementSynthetic.standingStill(seconds: 70, fs: hz),
      SimulatedMotionProfile.armHoldSteady => _armHold(hz, dropDeg: 1.5),
      SimulatedMotionProfile.armHoldDrift => _armHold(hz, dropDeg: 25),
      SimulatedMotionProfile.walkingSlow => _leadInThenStill(
        MovementSynthetic.walking(stepHz: 1.4, seconds: 14, fs: hz),
        hz,
      ),
      _ => _leadInThenStill(MovementSynthetic.walking(seconds: 8, fs: hz), hz),
    };
    return _play(
      data,
      hz,
      dropAfter: profile == SimulatedMotionProfile.dropout,
    );
  }

  /// Gravity on a phone lying in the palm, arm out: starts almost flat and
  /// tilts forward by [dropDeg] over 10 s (then holds), with hand tremor.
  static List<MotionSample> _armHold(double hz, {required double dropDeg}) {
    final rng = math.Random(4);
    final out = <MotionSample>[];
    final n = (14 * hz).round();
    for (var i = 0; i < n; i++) {
      final t = i / hz;
      final frac = (t / 10).clamp(0.0, 1.0);
      final a = (8 + dropDeg * frac) * math.pi / 180;
      final jitter = (rng.nextDouble() - 0.5) * 0.25;
      out.add(
        MotionSample(
          t,
          0.3 + jitter,
          9.81 * math.sin(a) + jitter,
          9.81 * math.cos(a) + jitter,
        ),
      );
    }
    return out;
  }

  /// 5 s standing (the "pocket the phone" countdown), the walk, then 60 s
  /// standing still so the gait auto-stop fires.
  static List<MotionSample> _leadInThenStill(
    List<MotionSample> walk,
    double hz,
  ) {
    final lead = MovementSynthetic.standingStill(seconds: 5, fs: hz, seed: 9);
    final t1 = lead.last.t;
    final out = <MotionSample>[...lead];
    for (final s in walk.skip(1)) {
      out.add(MotionSample(t1 + s.t, s.x, s.y, s.z));
    }
    final t2 = out.last.t;
    final still = MovementSynthetic.standingStill(seconds: 60, fs: hz);
    for (final s in still.skip(1)) {
      out.add(MotionSample(t2 + s.t, s.x, s.y, s.z));
    }
    return out;
  }

  Stream<MotionSample> _simulatedGyro(double hz) {
    final profile = simulatedProfile;
    final data = switch (profile) {
      SimulatedMotionProfile.tremor => MovementSynthetic.tremor(
        seconds: 25,
        fs: hz,
      ),
      SimulatedMotionProfile.tremorEssential => MovementSynthetic.tremor(
        hz: 8,
        ampDegS: 12,
        seconds: 25,
        fs: hz,
      ),
      SimulatedMotionProfile.grossMovement => MovementSynthetic.grossMovement(
        seconds: 25,
        fs: hz,
      ),
      _ => MovementSynthetic.stillHand(seconds: 25, fs: hz),
    };
    return _play(
      data,
      hz,
      dropAfter: profile == SimulatedMotionProfile.dropout,
    );
  }

  /// Emits [data] in real time at [hz] (batched 10 samples per timer tick so
  /// widget tests stay cheap).
  Stream<MotionSample> _play(
    List<MotionSample> data,
    double hz, {
    bool dropAfter = false,
  }) {
    late StreamController<MotionSample> ctrl;
    Timer? timer;
    var i = 0;
    final batch = math.max(1, (hz / 10).round());
    void run() {
      timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (dropAfter && i > hz * 3) return; // sensor dropout after 3 s
        for (var k = 0; k < batch && i < data.length; k++, i++) {
          ctrl.add(data[i]);
        }
        if (i >= data.length) {
          timer?.cancel();
        }
      });
    }

    ctrl = StreamController<MotionSample>(
      onListen: () {
        final delay = simulatedStartDelay;
        if (delay > Duration.zero) {
          // one-shot: the sensor "comes up late" for this listen only
          simulatedStartDelay = Duration.zero;
          timer = Timer(delay, run);
          return;
        }
        run();
      },
      onCancel: () => timer?.cancel(),
    );
    return ctrl.stream;
  }
}
