// Plain microphone recording for the acoustic tasks (mood free speech,
// HF sentence; Spec §8 AUD-11 / AUD-12): PCM16 mono 16 kHz via `record`,
// then the samples are analysed by VoiceFeatures. The live meter uses the
// recorder amplitude. Simulated under FLUTTER_TEST.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../domain/algorithms/mind_engines.dart';
import '../domain/entities/mind_protocol.dart';

class SpeechCaptureService extends ChangeNotifier {
  SpeechCaptureService({bool? simulated})
    : simulated = simulated ?? Platform.environment.containsKey('FLUTTER_TEST');

  static const int sampleRate = 16000;

  static bool get isFlutterTestStatic =>
      Platform.environment.containsKey('FLUTTER_TEST');

  final bool simulated;

  /// Test Controls: which synthetic voice to produce.
  MindDemoOutcome simulatedOutcome = MindDemoOutcome.normal;

  /// Under simulation: builds the synthetic take returned by [stopRaw]
  /// (the Breathing & Voice tasks set this per task); null → the Mind
  /// speech generator.
  List<int> Function(int seconds)? simulatedSamples;

  /// Under simulation: live level 0..1 at [elapsedS] (cough bursts, a held
  /// note, a blow); null → a speaking rhythm.
  double Function(double tSeconds)? simulatedLevel;

  AudioRecorder? _rec;
  Timer? _meter;
  String? _path;
  bool _recording = false;
  bool _permissionDenied = false;
  final Stopwatch _clock = Stopwatch();
  int _ticks = 0;

  /// Live level 0..1 for the meter bars.
  double level = 0;
  bool get recording => _recording;
  bool get permissionDenied => _permissionDenied;
  double get elapsedS =>
      simulated ? _ticks * 0.1 : _clock.elapsedMilliseconds / 1000;
  String get source => simulated ? 'simulated' : 'microphone';

  Future<bool> start() async {
    if (_recording) return true;
    _ticks = 0;
    level = 0;
    if (!simulated) {
      try {
        _rec = AudioRecorder();
        if (!await _rec!.hasPermission()) {
          _permissionDenied = true;
          notifyListeners();
          return false;
        }
        _path =
            '${Directory.systemTemp.path}/vm_speech_${DateTime.now().millisecondsSinceEpoch}.pcm';
        await _rec!.start(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            numChannels: 1,
            sampleRate: sampleRate,
            noiseSuppress: false,
            autoGain: false,
            echoCancel: false,
          ),
          path: _path!,
        );
      } catch (_) {
        _rec = null;
        _permissionDenied = false;
      }
    }
    _recording = true;
    _clock
      ..reset()
      ..start();
    _meter = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    notifyListeners();
    return true;
  }

  Future<void> _tick() async {
    _ticks++;
    if (simulated || _rec == null) {
      final pattern = simulatedLevel;
      level = pattern != null
          ? pattern(elapsedS).clamp(0.0, 1.0)
          // a speaking rhythm for the bars
          : (0.35 + 0.35 * (((_ticks % 7) - 3).abs() / 3)).clamp(0, 1);
    } else {
      try {
        final a = await _rec!.getAmplitude();
        final db = a.current.isFinite ? a.current : -60.0;
        level = ((db + 50) / 50).clamp(0.0, 1.0);
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Stops and returns the acoustic features of the take.
  Future<VoiceFeatures> stop() async => (await stopRaw()).$2;

  /// Stops and returns the PCM16 samples of the take with their features
  /// (the breathing engines run on the samples).
  Future<(List<int>, VoiceFeatures)> stopRaw() async {
    _meter?.cancel();
    _meter = null;
    _clock.stop();
    final seconds = elapsedS.clamp(1, 120).round();
    _recording = false;
    if (simulated || _rec == null) {
      notifyListeners();
      final custom = simulatedSamples;
      if (custom != null) {
        final samples = custom(seconds);
        return (samples, VoiceFeatures.extract(samples, sampleRate));
      }
      final pauses = switch (simulatedOutcome) {
        MindDemoOutcome.normal => 0,
        MindDemoOutcome.borderline => 2,
        _ => 4,
      };
      final f0 = switch (simulatedOutcome) {
        MindDemoOutcome.normal => 150.0,
        MindDemoOutcome.borderline => 146.0,
        _ => 138.0,
      };
      final samples = MindSimulated.pcm(
        seconds: seconds,
        f0: f0,
        longPauses: pauses,
      );
      return (samples, VoiceFeatures.extract(samples, sampleRate));
    }
    try {
      final p = await _rec!.stop();
      await _rec!.dispose();
      _rec = null;
      final file = File(p ?? _path!);
      final bytes = await file.readAsBytes();
      final samples = _pcm16(bytes);
      try {
        await file.delete();
      } catch (_) {}
      notifyListeners();
      return (samples, VoiceFeatures.extract(samples, sampleRate));
    } catch (_) {
      notifyListeners();
      return (const <int>[], VoiceFeatures.extract(const [], sampleRate));
    }
  }

  static List<int> _pcm16(Uint8List bytes) {
    // Skip a WAV header when the platform wrote one.
    var offset = 0;
    if (bytes.length > 44 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      offset = 44;
    }
    final n = (bytes.length - offset) ~/ 2;
    final bd = ByteData.sublistView(bytes, offset, offset + n * 2);
    return [for (var i = 0; i < n; i++) bd.getInt16(i * 2, Endian.little)];
  }

  Future<void> cancel() async {
    _meter?.cancel();
    _meter = null;
    _clock.stop();
    _recording = false;
    try {
      await _rec?.stop();
      await _rec?.dispose();
    } catch (_) {}
    _rec = null;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(cancel());
    super.dispose();
  }
}
