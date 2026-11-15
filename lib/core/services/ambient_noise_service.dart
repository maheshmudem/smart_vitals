// ALG-CAP-12 room-noise check and in-test monitor (Spec §2, G-18):
// microphone amplitude in dBFS from the `record` package, converted to dBA
// with a per-device offset [DER default 95 dBA at 0 dBFS]. Simulated under
// FLUTTER_TEST (36 dBA) with a Test Controls override.
import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../domain/algorithms/hearing_engines.dart';

class NoiseReading {
  const NoiseReading({required this.dba, required this.source, this.window});

  final double dba;

  /// 'microphone' | 'simulated' | 'manual'.
  final String source;
  final NoiseWindow? window;

  bool get passes => NoiseLevel.passes(dba);
}

class AmbientNoiseService extends ChangeNotifier {
  AmbientNoiseService({double? micOffsetDba, bool? simulated})
    : micOffsetDba = micOffsetDba ?? NoiseLevel.defaultMicOffsetDba,
      simulated = simulated ?? Platform.environment.containsKey('FLUTTER_TEST');

  /// dBFS → dBA offset; replaced by [calibrateQuietRoom] on this phone.
  double micOffsetDba;

  /// Last raw recorder level (dBFS), for the diagnostics line.
  double? lastDbfs;

  /// Quiet-room reference used by the one-tap calibration [DER].
  static const double quietRoomDba = 35.0;
  final bool simulated;

  /// Test Controls: override the simulated room level.
  double simulatedDba = 36;

  AudioRecorder? _rec;
  Timer? _timer;
  // Tick-counted clock (200 ms per tick) so the 3 s window also advances
  // under the widget-test fake clock.
  int _ticks = 0;
  bool _running = false;
  bool _permissionDenied = false;

  double? currentDba;
  double? sessionMaxDba;
  double? sessionMeanDba;
  int _meanCount = 0;

  bool get running => _running;
  bool get permissionDenied => _permissionDenied;
  String get source => simulated ? 'simulated' : 'microphone';

  /// Starts sampling every 200 ms. Safe to call twice.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _ticks = 0;
    sessionMaxDba = null;
    sessionMeanDba = null;
    _meanCount = 0;
    if (!simulated) {
      try {
        _rec = AudioRecorder();
        if (!await _rec!.hasPermission()) {
          _permissionDenied = true;
          _running = false;
          notifyListeners();
          return;
        }
        final dir = Directory.systemTemp;
        await _rec!.start(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            numChannels: 1,
            sampleRate: 44100,
            noiseSuppress: false,
            autoGain: false,
            echoCancel: false,
          ),
          path: '${dir.path}/vm_noise_probe.pcm',
        );
      } catch (_) {
        _rec = null;
      }
    }
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  Future<void> _tick() async {
    _ticks++;
    double dba;
    if (simulated || _rec == null) {
      dba = simulatedDba;
    } else {
      try {
        final a = await _rec!.getAmplitude();
        final dbfs = a.current.isFinite ? a.current.clamp(-120.0, 0.0) : -90.0;
        lastDbfs = dbfs;
        dba = NoiseLevel.dbaFromDbfs(dbfs, offset: micOffsetDba);
      } catch (_) {
        dba = simulatedDba;
      }
    }
    currentDba = dba;
    sessionMaxDba = sessionMaxDba == null || dba > sessionMaxDba!
        ? dba
        : sessionMaxDba;
    _meanCount++;
    sessionMeanDba = sessionMeanDba == null
        ? dba
        : sessionMeanDba! + (dba - sessionMeanDba!) / _meanCount;
    notifyListeners();
  }

  /// One-tap calibration: the member confirms the room is quiet, so the
  /// current reading is defined as [quietRoomDba]. Returns the new offset
  /// (null when no microphone reading exists yet).
  double? calibrateQuietRoom() {
    final d = lastDbfs;
    if (d == null) return null;
    micOffsetDba = (quietRoomDba - d).clamp(40.0, 130.0);
    currentDba = quietRoomDba;
    sessionMeanDba = null;
    sessionMaxDba = null;
    _meanCount = 0;
    notifyListeners();
    return micOffsetDba;
  }

  /// Seconds since [start] (tick-counted).
  double get elapsedS => _ticks * 0.2;

  /// 3 s silence window (Spec §2 CAP-12): samples until the window is full,
  /// then reports the mean. [onProgress] gets 0..1.
  Future<NoiseReading> checkRoom({void Function(double)? onProgress}) async {
    await start();
    final w = NoiseWindow();
    final t0 = elapsedS;
    while (elapsedS - t0 < NoiseLevel.windowS + 0.05) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (currentDba != null) w.add(elapsedS, currentDba!);
      onProgress?.call(((elapsedS - t0) / NoiseLevel.windowS).clamp(0, 1));
      if (!_running) break;
    }
    final mean = w.meanDba ?? currentDba ?? simulatedDba;
    return NoiseReading(dba: mean, source: source, window: w);
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
    try {
      await _rec?.stop();
      await _rec?.dispose();
    } catch (_) {}
    _rec = null;
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
