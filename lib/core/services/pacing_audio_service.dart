// Pacing sounds for the movement tests (Spec §9: "paced by voice +
// metronome"): countdown ticks, the "go" and "stop" cues, and a count beep.
// Tiny generated WAV assets (tool/gen_pacing_wavs.dart) plus haptics; silent
// under FLUTTER_TEST or when audio playback fails on a platform.
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class PacingAudio {
  PacingAudio._();

  static final PacingAudio instance = PacingAudio._();

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  AudioPlayer? _a;
  AudioPlayer? _b;
  bool _useA = true;

  Future<void> _play(String asset, {bool haptic = true}) async {
    if (haptic) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
    if (isFlutterTest) return;
    try {
      _a ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      _b ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      final p = _useA ? _a! : _b!;
      _useA = !_useA;
      await p.stop();
      await p.play(AssetSource('audio/$asset'));
    } catch (_) {
      // No audio on this platform — haptics and voice still pace the test.
    }
  }

  /// Countdown tick (3 · 2 · 1).
  Future<void> tick() => _play('tick.wav');

  /// Counted repetition / halfway cue.
  Future<void> beep() => _play('beep.wav', haptic: false);

  /// Start of the recording.
  Future<void> go() => _play('go.wav');

  /// End of the recording.
  Future<void> stop() => _play('beep.wav');

  void dispose() {
    _a?.dispose();
    _b?.dispose();
    _a = null;
    _b = null;
  }
}
