// Overnight sonar capture (Doc 09 §8 ALG-AUD-07): plays the inaudible
// 18–20 kHz chirp loop through the speaker and streams the microphone at
// native 48 kHz into [SonarFrameAnalyzer]. Only 20 Hz features leave this
// class — no PCM is kept (an 8 h night cannot be buffered).
//
// FLUTTER_TEST / desktop: simulated features from [SleepSimulated], one
// epoch per 100 ms tick so a whole night passes in seconds.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../domain/algorithms/sleep_engines.dart';

class SonarCheckResult {
  const SonarCheckResult({
    required this.passed,
    required this.echoDb,
    required this.floorDb,
    required this.source,
    this.note = '',
  });

  final bool passed;

  /// Mean 18–20 kHz level with the chirp playing (dBFS).
  final double echoDb;

  /// Same with the chirp off.
  final double floorDb;
  final String source;
  final String note;

  double get aboveFloorDb => echoDb - floorDb;

  static const double minAboveFloorDb = 15;
}

class SleepSonarService extends ChangeNotifier {
  SleepSonarService({bool? simulated})
    : simulated = simulated ?? isFlutterTestStatic;

  static const int sampleRate = 48000;
  static const String chirpAsset = 'audio/sonar_chirp.wav';
  static const double chirpVolume = 0.7;
  static const int maxRestarts = 3;

  static bool get isFlutterTestStatic =>
      Platform.environment.containsKey('FLUTTER_TEST');

  final bool simulated;

  /// Simulated night profile ('normal' | 'mild' | 'moderate' | 'severe' |
  /// 'shortNight') and Test Controls flags.
  String simulatedOutcome = 'normal';
  bool simulateEchoLost = false;
  bool simulateSonarFail = false;
  bool simulateInterruption = false;

  /// 'stream' | 'simulated' | 'none'.
  String source = 'none';
  bool running = false;
  bool interrupted = false;
  int restarts = 0;
  bool chirpPlayed = false;
  bool permissionDenied = false;
  String? lastError;

  /// Echo floor (chirp off) from the last sonar check, dBFS.
  double floorDb = -80;

  final SonarFrameAnalyzer _analyzer = SonarFrameAnalyzer();
  final List<SonarFeature> _features = [];
  int _published = 0;
  AudioRecorder? _rec;
  StreamSubscription<Uint8List>? _sub;
  AudioPlayer? _player;
  Timer? _simTimer;
  int _simEpoch = 0;
  bool _checking = false;

  /// Seconds of audio processed so far.
  double get elapsedS => _features.isEmpty ? 0 : _features.last.t;

  double? get lastEchoDb => _features.isEmpty ? null : _features.last.sonarDb;

  /// Meter 0..1 from the last echo level.
  double get level =>
      lastEchoDb == null ? 0 : ((lastEchoDb! + 70) / 50).clamp(0.0, 1.0);

  /// Features published since the previous call.
  List<SonarFeature> takeNewFeatures() {
    final fresh = _features.sublist(_published);
    _published = _features.length;
    if (_published > 4000) {
      // keep memory flat: drop what has been consumed
      _features.removeRange(0, _published);
      _published = 0;
    }
    return fresh;
  }

  // ---------------------------------------------------------------------
  // Sonar echo check (Setup)
  // ---------------------------------------------------------------------

  /// Measures the 18–20 kHz band with the chirp off, then on. A speaker /
  /// microphone pair that carries ultrasound shows ≥ 15 dB more with the
  /// chirp playing [DER].
  Future<SonarCheckResult> sonarCheck({
    void Function(double progress)? onProgress,
  }) async {
    if (_checking) {
      return const SonarCheckResult(
        passed: false,
        echoDb: -120,
        floorDb: -120,
        source: 'none',
        note: 'Check already running',
      );
    }
    _checking = true;
    notifyListeners();
    try {
      if (simulated) {
        for (var i = 1; i <= 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          onProgress?.call(i / 10);
        }
        floorDb = -82;
        return simulateSonarFail
            ? const SonarCheckResult(
                passed: false,
                echoDb: -78,
                floorDb: -82,
                source: 'simulated',
                note: 'Speaker / microphone pair carries little 18–20 kHz',
              )
            : const SonarCheckResult(
                passed: true,
                echoDb: -41,
                floorDb: -82,
                source: 'simulated',
              );
      }
      final rec = AudioRecorder();
      AudioPlayer? player;
      try {
        if (!await rec.hasPermission()) {
          permissionDenied = true;
          return const SonarCheckResult(
            passed: false,
            echoDb: -120,
            floorDb: -120,
            source: 'none',
            note: 'Microphone permission needed (G-12)',
          );
        }
        final analyzer = SonarFrameAnalyzer();
        final quiet = <double>[];
        final loud = <double>[];
        var phase = 0; // 0 quiet · 1 loud
        final stream = await rec.startStream(_config);
        final sub = stream.listen((bytes) {
          for (final f in analyzer.push(_pcm16(bytes))) {
            (phase == 0 ? quiet : loud).add(f.sonarDb);
          }
        });
        for (var i = 1; i <= 4; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          onProgress?.call(i / 10);
        }
        player = await _startChirp();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        phase = 1;
        for (var i = 5; i <= 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          onProgress?.call(i / 10);
        }
        await sub.cancel();
        await rec.stop();
        final q = quiet.isEmpty ? -120.0 : _median(quiet);
        final l = loud.isEmpty ? -120.0 : _median(loud);
        floorDb = q;
        final ok = l - q >= SonarCheckResult.minAboveFloorDb;
        return SonarCheckResult(
          passed: ok,
          echoDb: l,
          floorDb: q,
          source: 'stream',
          note: ok
              ? ''
              : 'The 18–20 kHz chirp came back only ${(l - q).toStringAsFixed(0)} dB above the floor (needs ≥ 15). Raise the media volume, uncover the speaker and microphone, or this phone may filter ultrasound.',
        );
      } catch (e) {
        lastError = '$e';
        return SonarCheckResult(
          passed: false,
          echoDb: -120,
          floorDb: -120,
          source: 'none',
          note: 'Could not run the check: $e',
        );
      } finally {
        try {
          await player?.stop();
          await player?.dispose();
        } catch (_) {}
        try {
          await rec.dispose();
        } catch (_) {}
      }
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Night
  // ---------------------------------------------------------------------

  Future<bool> start() async {
    if (running) return true;
    _features.clear();
    _published = 0;
    _analyzer.reset();
    interrupted = false;
    restarts = 0;
    permissionDenied = false;
    lastError = null;
    if (simulated) {
      source = 'simulated';
      chirpPlayed = true;
      _simEpoch = 0;
      _simTimer?.cancel();
      _simTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _simTick(),
      );
      running = true;
      notifyListeners();
      return true;
    }
    final ok = await _openStream();
    if (!ok) {
      notifyListeners();
      return false;
    }
    try {
      _player = await _startChirp();
      chirpPlayed = true;
    } catch (e) {
      lastError = 'chirp: $e';
      chirpPlayed = false;
    }
    running = true;
    notifyListeners();
    return true;
  }

  Future<bool> _openStream() async {
    try {
      _rec = AudioRecorder();
      if (!await _rec!.hasPermission()) {
        permissionDenied = true;
        _rec = null;
        source = 'none';
        return false;
      }
      final stream = await _rec!.startStream(_config);
      _sub = stream.listen(
        (bytes) {
          final fresh = _analyzer.push(_pcm16(bytes));
          if (fresh.isNotEmpty) {
            _features.addAll(fresh);
            notifyListeners();
          }
        },
        onError: (Object e) => _onStreamLost('$e'),
        onDone: () {
          if (running) _onStreamLost('stream closed');
        },
        cancelOnError: true,
      );
      source = 'stream';
      return true;
    } catch (e) {
      lastError = '$e';
      try {
        await _rec?.dispose();
      } catch (_) {}
      _rec = null;
      source = 'none';
      return false;
    }
  }

  Future<void> _onStreamLost(String why) async {
    if (!running) return;
    interrupted = true;
    lastError = why;
    notifyListeners();
    try {
      await _sub?.cancel();
    } catch (_) {}
    try {
      await _rec?.dispose();
    } catch (_) {}
    _rec = null;
    if (restarts >= maxRestarts) {
      source = 'none';
      notifyListeners();
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!running) return;
    restarts++;
    final ok = await _openStream();
    interrupted = !ok;
    notifyListeners();
  }

  /// Test Controls: drop the stream once (simulated restart).
  void simulateDropout() {
    if (!running) return;
    restarts++;
    interrupted = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 600), () {
      if (!running) return;
      interrupted = false;
      notifyListeners();
    });
  }

  void _simTick() {
    if (!running) return;
    if (simulateInterruption) {
      simulateInterruption = false;
      simulateDropout();
    }
    final total = SleepSimulated.epochCount(simulatedOutcome);
    if (_simEpoch >= total + 4) return; // night over: hold
    _features.addAll(
      SleepSimulated.epochFeatures(
        simulatedOutcome,
        _simEpoch,
        echoLost: simulateEchoLost,
      ),
    );
    _simEpoch++;
    notifyListeners();
  }

  Future<void> stop() async {
    running = false;
    _simTimer?.cancel();
    _simTimer = null;
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      await _rec?.stop();
      await _rec?.dispose();
    } catch (_) {}
    _rec = null;
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------

  static const RecordConfig _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    numChannels: 1,
    sampleRate: sampleRate,
    noiseSuppress: false,
    autoGain: false,
    echoCancel: false,
  );

  Future<AudioPlayer> _startChirp() async {
    final p = AudioPlayer()..setPlayerMode(PlayerMode.mediaPlayer);
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setVolume(chirpVolume);
    await p.play(AssetSource(chirpAsset));
    return p;
  }

  static List<int> _pcm16(Uint8List bytes) {
    final n = bytes.length ~/ 2;
    final bd = ByteData.sublistView(bytes, 0, n * 2);
    return [for (var i = 0; i < n; i++) bd.getInt16(i * 2, Endian.little)];
  }

  static double _median(List<double> v) {
    final s = List<double>.from(v)..sort();
    return s[s.length ~/ 2];
  }

  bool get checking => _checking;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
