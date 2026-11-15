// Microphone capture for the Breathing & Voice tasks (Spec §8 AUD-01..06,
// CAP-13): raw PCM16 mono 16 kHz streamed from `record` with every phone
// audio processing turned off. The samples are kept for the offline engines
// and, every 100 ms, the new 10 ms RMS frames (dBFS) are published so the
// live recogniser sees the same audio the engines will. Falls back to the
// amplitude meter when streaming is unavailable; refuses to pretend on a
// device without a recorder. Simulated under FLUTTER_TEST by streaming a
// synthetic take in 100 ms chunks.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../domain/algorithms/breath_engines.dart';
import '../domain/algorithms/mind_engines.dart' show VoiceFeatures;

class BreathAudioService extends ChangeNotifier {
  BreathAudioService({bool? simulated})
    : simulated = simulated ?? Platform.environment.containsKey('FLUTTER_TEST');

  static const int sampleRate = 16000;
  static const int frameSamples = 160; // 10 ms
  static bool get isFlutterTestStatic =>
      Platform.environment.containsKey('FLUTTER_TEST');

  final bool simulated;

  /// Under simulation: the whole synthetic take, generated when the
  /// recording starts and streamed in 100 ms chunks.
  List<int> Function()? simulatedTake;

  AudioRecorder? _rec;
  StreamSubscription<Uint8List>? _sub;
  Timer? _ticker;
  String? _path;
  final List<int> _samples = [];
  final List<int> _pending = [];
  final List<int> _carry = [];
  final List<double> _frames = [];
  int _published = 0;
  int _ticks = 0;
  List<int>? _simTake;
  int _simPos = 0;
  bool _recording = false;
  bool _permissionDenied = false;
  int _clippedSamples = 0;

  /// 'stream' | 'amplitude' | 'simulated' | 'none'.
  String source = 'none';

  /// Milliseconds per published frame (10 for PCM, 100 for the amplitude
  /// fallback).
  double get frameMs => source == 'amplitude' ? 100 : 10;

  bool get recording => _recording;
  bool get permissionDenied => _permissionDenied;

  /// Tick-counted seconds since start (advances under the test clock).
  double get elapsedS => _ticks * 0.1;

  /// Last frame in dBFS (null before the first frame).
  double? get lastDbfs => _frames.isEmpty ? null : _frames.last;

  /// Meter level 0..1 for the bars.
  double get level =>
      lastDbfs == null ? 0 : ((lastDbfs! + 55) / 52).clamp(0.0, 1.0);

  /// True when the last 100 ms contained full-scale samples.
  bool clipping = false;
  double get clipPct =>
      _samples.isEmpty ? 0 : _clippedSamples * 100 / _samples.length;

  /// All frames so far (dBFS).
  List<double> get frames => List.unmodifiable(_frames);

  /// Frames published since the previous call.
  List<double> takeNewFrames() {
    final fresh = _frames.sublist(_published);
    _published = _frames.length;
    return fresh;
  }

  Future<bool> start() async {
    if (_recording) return true;
    _samples.clear();
    _pending.clear();
    _carry.clear();
    _frames.clear();
    _published = 0;
    _ticks = 0;
    _clippedSamples = 0;
    clipping = false;
    _permissionDenied = false;
    if (simulated) {
      _simTake = simulatedTake?.call() ?? BreathSimulated.silence(seconds: 3);
      _simPos = 0;
      source = 'simulated';
    } else {
      try {
        _rec = AudioRecorder();
        if (!await _rec!.hasPermission()) {
          _permissionDenied = true;
          _rec = null;
          notifyListeners();
          return false;
        }
        const config = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: sampleRate,
          noiseSuppress: false,
          autoGain: false,
          echoCancel: false,
        );
        try {
          final stream = await _rec!.startStream(config);
          _sub = stream.listen((bytes) => _pending.addAll(_pcm16(bytes)));
          source = 'stream';
        } catch (_) {
          _path =
              '${Directory.systemTemp.path}/vm_breath_${DateTime.now().millisecondsSinceEpoch}.pcm';
          await _rec!.start(config, path: _path!);
          source = 'amplitude';
        }
      } catch (_) {
        try {
          await _rec?.dispose();
        } catch (_) {}
        _rec = null;
        source = 'none';
        notifyListeners();
        return false;
      }
    }
    _recording = true;
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    notifyListeners();
    return true;
  }

  Future<void> _tick() async {
    if (!_recording) return;
    _ticks++;
    switch (source) {
      case 'simulated':
        final take = _simTake!;
        final end = math.min(take.length, _simPos + sampleRate ~/ 10);
        final chunk = _simPos < take.length
            ? take.sublist(_simPos, end)
            : List<int>.filled(sampleRate ~/ 10, 0);
        _simPos = end;
        _ingest(chunk);
      case 'stream':
        if (_pending.isNotEmpty) {
          final chunk = List<int>.from(_pending);
          _pending.clear();
          _ingest(chunk);
        }
      case 'amplitude':
        try {
          final a = await _rec!.getAmplitude();
          final db = a.current.isFinite ? a.current.clamp(-96.0, 0.0) : -96.0;
          _frames.add(db);
          clipping = db > -1.0;
        } catch (_) {}
      default:
        break;
    }
    notifyListeners();
  }

  void _ingest(List<int> chunk) {
    var clipped = 0;
    for (final v in chunk) {
      if (v.abs() >= 32700) clipped++;
    }
    _clippedSamples += clipped;
    clipping = clipped > 0;
    _samples.addAll(chunk);
    _carry.addAll(chunk);
    var off = 0;
    while (off + frameSamples <= _carry.length) {
      var acc = 0.0;
      for (var i = 0; i < frameSamples; i++) {
        final v = _carry[off + i].toDouble();
        acc += v * v;
      }
      final rms = math.sqrt(acc / frameSamples);
      _frames.add(20 * math.log(math.max(rms, 1e-3) / 32768) / math.ln10);
      off += frameSamples;
    }
    _carry.removeRange(0, off);
  }

  /// Stops and returns the PCM16 samples of the take with their features.
  Future<(List<int>, VoiceFeatures)> stopRaw() async {
    _ticker?.cancel();
    _ticker = null;
    _recording = false;
    List<int> samples;
    switch (source) {
      case 'simulated':
        samples = _simTake == null
            ? const []
            : _simTake!.sublist(0, math.min(_simPos, _simTake!.length));
      case 'stream':
        await _sub?.cancel();
        _sub = null;
        try {
          await _rec?.stop();
        } catch (_) {}
        if (_pending.isNotEmpty) {
          _ingest(List<int>.from(_pending));
          _pending.clear();
        }
        samples = List<int>.from(_samples);
      case 'amplitude':
        samples = const [];
        try {
          final p = await _rec?.stop();
          final file = File(p ?? _path!);
          final bytes = await file.readAsBytes();
          samples = _pcm16(bytes, skipWavHeader: true);
          try {
            await file.delete();
          } catch (_) {}
        } catch (_) {}
      default:
        samples = const [];
    }
    try {
      await _rec?.dispose();
    } catch (_) {}
    _rec = null;
    notifyListeners();
    return (samples, VoiceFeatures.extract(samples, sampleRate));
  }

  static List<int> _pcm16(Uint8List bytes, {bool skipWavHeader = false}) {
    var offset = 0;
    if (skipWavHeader &&
        bytes.length > 44 &&
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
    _ticker?.cancel();
    _ticker = null;
    _recording = false;
    await _sub?.cancel();
    _sub = null;
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
