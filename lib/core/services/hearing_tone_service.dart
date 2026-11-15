// Pure-tone and masking-noise playback for the hearing screen (Spec §8
// AUD-09). Tones are tiny generated WAV assets (tool/gen_pacing_wavs.dart):
// one file per frequency and ear, stereo with the other channel silent, so
// no balance API is needed. Level comes from the player gain
// (ToneLevel.gainFor); earphone calibration is the member's [DER] value.
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';

import '../domain/algorithms/hearing_engines.dart';
import '../domain/entities/hearing_protocol.dart';

class HearingToneService {
  HearingToneService({double? fullScaleDbHl})
    : fullScaleDbHl = fullScaleDbHl ?? ToneLevel.defaultFullScaleDbHl;

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Hearing level of a full-scale tone at max volume [DER].
  double fullScaleDbHl;

  AudioPlayer? _tone;
  AudioPlayer? _noise;
  bool _noisePlaying = false;

  /// Lowest level this device can present (player gain floor ≈ −80 dB).
  double get floorDbHl => (fullScaleDbHl - 80).clamp(0, 80).toDouble();

  static String toneAsset(HearingEar ear, int hz) =>
      'audio/tone_${hz}_${ear == HearingEar.left ? 'l' : 'r'}.wav';

  /// Plays a 1 s tone; returns when playback has been requested (the
  /// onset is "now" for latency purposes).
  Future<DateTime> playTone(HearingEar ear, int hz, double dbHl) async {
    final onset = DateTime.now();
    if (isFlutterTest) return onset;
    try {
      _tone ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      final p = _tone!;
      await p.stop();
      await p.setVolume(ToneLevel.gainFor(dbHl, fullScaleDbHl: fullScaleDbHl));
      await p.play(AssetSource(toneAsset(ear, hz)));
    } catch (_) {
      // No audio on this platform — the controller still runs.
    }
    return onset;
  }

  Future<void> stopTone() async {
    if (isFlutterTest) return;
    try {
      await _tone?.stop();
    } catch (_) {}
  }

  /// Starts the speech-shaped masking noise loop at [gain] (Mode B).
  Future<void> playNoise(double gain) async {
    if (isFlutterTest) return;
    try {
      _noise ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _noise!.setVolume(gain.clamp(0.0, 1.0));
      if (!_noisePlaying) {
        await _noise!.play(AssetSource('audio/din_noise.wav'));
        _noisePlaying = true;
      }
    } catch (_) {}
  }

  Future<void> stopNoise() async {
    _noisePlaying = false;
    if (isFlutterTest) return;
    try {
      await _noise?.stop();
    } catch (_) {}
  }

  void dispose() {
    _tone?.dispose();
    _noise?.dispose();
    _tone = null;
    _noise = null;
  }
}
