// Spoken digit triplets for the digits-in-noise mode (Spec §8 AUD-09 Mode
// B). Uses the phone's own voice at a gain derived from the staircase SNR
// [DER: speech level relative to the noise file is app-defined].
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';

class DigitSpeechService {
  DigitSpeechService({this.languageCode = 'en-US'});

  final String languageCode;

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  FlutterTts? _tts;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready || isFlutterTest) return;
    try {
      _tts = FlutterTts();
      await _tts!.setLanguage(languageCode);
      await _tts!.setSpeechRate(0.42);
      await _tts!.setPitch(1.0);
      await _tts!.awaitSpeakCompletion(true);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Speaks "4 … 9 … 1" at [gain] (0..1) and completes when finished.
  /// Returns the approximate duration spoken.
  Future<Duration> speakTriplet(List<int> digits, double gain) async {
    if (isFlutterTest) return const Duration(milliseconds: 300);
    await _init();
    if (!_ready) return const Duration(seconds: 2);
    final sw = Stopwatch()..start();
    try {
      await _tts!.setVolume(gain.clamp(0.05, 1.0));
      await _tts!.speak(digits.map((d) => '$d').join(', '));
    } catch (_) {}
    sw.stop();
    return sw.elapsed < const Duration(milliseconds: 500)
        ? const Duration(seconds: 2)
        : sw.elapsed;
  }

  Future<void> stop() async {
    if (isFlutterTest) return;
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  void dispose() {
    unawaited(stop());
    _tts = null;
    _ready = false;
  }
}
