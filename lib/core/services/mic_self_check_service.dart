// ALG-CAP-11 microphone self-check (Spec §2, Gate G-17): a 1.5 s
// exponential sine sweep (100 Hz – 8 kHz, assets/audio/sweep.wav) is played
// through the speaker while the microphone records raw PCM; the recording
// is scored by [MicSelfCheck] against this phone's own stored profile when
// one exists. Simulated under FLUTTER_TEST with a Test Controls "simulate
// mic fail".
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../domain/algorithms/breath_engines.dart';

class MicSelfCheckService extends ChangeNotifier {
  MicSelfCheckService({bool? simulated})
    : simulated = simulated ?? Platform.environment.containsKey('FLUTTER_TEST');

  static const int sampleRate = 16000;
  static const String sweepAsset = 'audio/sweep.wav';

  final bool simulated;

  /// Test Controls: pretend the microphone fails the sweep.
  bool simulateFail = false;

  bool running = false;
  double progress = 0;
  MicSelfCheckResult? result;
  bool permissionDenied = false;
  String? lastError;
  int _ticks = 0;

  /// Plays the sweep, records it and scores the recording. [baselineRel]
  /// is this phone's stored profile (null on the first run).
  Future<MicSelfCheckResult> run({List<double>? baselineRel}) async {
    if (running) {
      while (running) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return result!;
    }
    running = true;
    progress = 0;
    result = null;
    permissionDenied = false;
    lastError = null;
    _ticks = 0;
    notifyListeners();
    if (simulated) {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        _ticks++;
        progress = _ticks / 8;
        notifyListeners();
      }
      const rel = [-4.1, -0.6, 0.9, 1.9, 1.9];
      result = simulateFail
          ? MicSelfCheckResult(
              deviationDb: baselineRel == null ? 0 : 11.3,
              processingDetected: false,
              sweepHeard: baselineRel == null ? false : true,
              bandsDb: const [-4.0, -0.2, 1.6, -4.1, -9.0],
              source: 'simulated',
              comparedToProfile: baselineRel != null,
              fixedProfileDeviationDb: 9.4,
            )
          : MicSelfCheckResult(
              deviationDb: baselineRel == null ? 0 : 1.2,
              processingDetected: false,
              sweepHeard: true,
              bandsDb: rel,
              source: 'simulated',
              comparedToProfile: baselineRel != null,
              fixedProfileDeviationDb: 2.1,
            );
      running = false;
      progress = 1;
      notifyListeners();
      return result!;
    }
    AudioRecorder? rec;
    AudioPlayer? player;
    final path =
        '${Directory.systemTemp.path}/vm_sweep_${DateTime.now().millisecondsSinceEpoch}.pcm';
    try {
      rec = AudioRecorder();
      if (!await rec.hasPermission()) {
        permissionDenied = true;
        result = const MicSelfCheckResult(
          deviationDb: 40,
          processingDetected: false,
          sweepHeard: false,
          bandsDb: [0, 0, 0, 0, 0],
          source: 'microphone',
        );
        running = false;
        notifyListeners();
        return result!;
      }
      // Prepare the player first so playback starts promptly once the
      // recorder is running (SoundPool / low-latency mode can stay silent).
      player = AudioPlayer()..setPlayerMode(PlayerMode.mediaPlayer);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
      await player.setSource(AssetSource(sweepAsset));
      await rec.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: sampleRate,
          noiseSuppress: false,
          autoGain: false,
          echoCancel: false,
        ),
        path: path,
      );
      progress = 0.1;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await player.resume();
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        progress = 0.1 + 0.07 * (i + 1);
        notifyListeners();
      }
      await player.stop();
      final p = await rec.stop();
      final file = File(p ?? path);
      final bytes = await file.readAsBytes();
      final samples = _pcm16(bytes);
      try {
        await file.delete();
      } catch (_) {}
      result = MicSelfCheck.evaluate(
        samples,
        sampleRate,
        baselineRel: baselineRel,
      );
    } catch (e) {
      lastError = '$e';
      result = const MicSelfCheckResult(
        deviationDb: 40,
        processingDetected: false,
        sweepHeard: false,
        bandsDb: [0, 0, 0, 0, 0],
        source: 'microphone',
      );
    } finally {
      try {
        await rec?.dispose();
      } catch (_) {}
      try {
        await player?.dispose();
      } catch (_) {}
    }
    running = false;
    progress = 1;
    notifyListeners();
    return result!;
  }

  static List<int> _pcm16(Uint8List bytes) {
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

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
