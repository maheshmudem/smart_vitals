// On-device speech recognition for the transcript tasks (Spec §8 AUD-10
// animal naming / picture description, §9 MOV-08 sentence repeat) through
// `speech_to_text` (te_IN / hi_IN / en_IN). Partial results are timestamped
// so pauses and rate can be measured. Simulated under FLUTTER_TEST and when
// the recogniser is unavailable (Test Controls).
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../domain/algorithms/mind_engines.dart';
import '../domain/entities/mind_protocol.dart';

class SpeechTranscribeService extends ChangeNotifier {
  SpeechTranscribeService({bool? simulated})
    : simulated = simulated ?? Platform.environment.containsKey('FLUTTER_TEST');

  final bool simulated;

  /// Test Controls: pretend the recogniser is missing.
  bool simulateUnavailable = false;
  MindDemoOutcome simulatedOutcome = MindDemoOutcome.normal;

  stt.SpeechToText? _stt;
  bool _available = false;
  bool _initialised = false;
  String? lastError;

  bool _listening = false;
  String transcript = '';
  final List<TimedWords> partials = [];
  double level = 0;
  final Stopwatch _clock = Stopwatch();
  Timer? _sim;
  int _ticks = 0;
  List<TimedWords> _simPlan = const [];
  String _simText = '';

  bool get available => simulated ? !simulateUnavailable : _available;
  bool get listening => _listening;

  /// Locale ids the recogniser reported (device); empty when unknown.
  List<String> supportedLocales = const [];

  /// Set when the requested language is not installed and the device
  /// default locale is used instead (the member is warned).
  bool localeFallback = false;

  bool supportsLocale(MindLanguage l) =>
      simulated ||
      supportedLocales.isEmpty ||
      supportedLocales.any(
        (id) =>
            id.toLowerCase().replaceAll('-', '_') ==
            l.localeId.toLowerCase().replaceAll('-', '_'),
      ) ||
      supportedLocales.any(
        (id) =>
            id.toLowerCase().startsWith('${l.name}_') ||
            id.toLowerCase().startsWith('${l.name}-'),
      );
  double get elapsedS =>
      simulated ? _ticks * 0.25 : _clock.elapsedMilliseconds / 1000;
  int get wordCount => TranscriptAnalysis.tokenize(transcript).length;

  Future<bool> initialize() async {
    if (simulated) {
      _initialised = true;
      return available;
    }
    if (_initialised) return _available;
    _initialised = true;
    try {
      _stt = stt.SpeechToText();
      _available = await _stt!.initialize(
        onError: (e) {
          lastError = e.errorMsg;
          notifyListeners();
        },
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') _maybeRestart();
        },
      );
      if (_available) {
        try {
          final locales = await _stt!.locales();
          supportedLocales = [for (final l in locales) l.localeId];
        } catch (_) {}
      }
    } catch (e) {
      lastError = '$e';
      _available = false;
    }
    return _available;
  }

  /// Starts recognition for up to [seconds]. [simulatedPlan] feeds the
  /// transcript under simulation.
  Future<bool> listen({
    required MindLanguage language,
    required int seconds,
    (List<TimedWords>, String)? simulatedPlan,
  }) async {
    if (_listening) return true;
    transcript = '';
    partials.clear();
    _ticks = 0;
    level = 0;
    _listening = true;
    _clock
      ..reset()
      ..start();
    if (!simulated && !_available) {
      // No recogniser on this device: never pretend. The caller offers the
      // helper judgement / manual tally instead.
      _listening = false;
      _clock.stop();
      notifyListeners();
      return false;
    }
    if (simulated) {
      final plan =
          simulatedPlan ??
          MindSimulated.fluencyTranscript(simulatedOutcome, language);
      _simPlan = plan.$1;
      _simText = plan.$2;
      final words = _simText.split(' ');
      _sim = Timer.periodic(const Duration(milliseconds: 250), (_) {
        _ticks++;
        final t = elapsedS;
        var count = 0;
        for (final p in _simPlan) {
          if (p.tSeconds <= t) count = p.wordCount;
        }
        final shown = words.take(count).join(' ');
        if (shown != transcript) {
          transcript = shown;
          partials.add(TimedWords(t, count));
        }
        level = count > 0 && _simPlan.any((p) => (p.tSeconds - t).abs() < 0.6)
            ? 0.8
            : 0.15;
        notifyListeners();
      });
      notifyListeners();
      return true;
    }
    _committed = '';
    _language = language;
    _wantSeconds = seconds;
    localeFallback = !supportsLocale(language);
    final ok = await _engineListen();
    if (!_listening) {
      // cancelled while the engine was starting
      try {
        await _stt?.cancel();
      } catch (_) {}
      return false;
    }
    notifyListeners();
    return ok;
  }

  // Android stops recognising after a pause or a hard limit, long before a
  // 60 s task ends: the engine is restarted while the task is running and
  // earlier text is kept in [_committed].
  String _committed = '';
  MindLanguage _language = MindLanguage.en;
  int _wantSeconds = 60;
  bool _restarting = false;

  Future<bool> _engineListen() async {
    final remaining = (_wantSeconds - elapsedS).clamp(3, 65).round();
    try {
      await _stt!.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: localeFallback ? null : _language.localeId,
          listenFor: Duration(seconds: remaining + 2),
          pauseFor: const Duration(seconds: 6),
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
        ),
        onResult: (r) {
          final text = _committed.isEmpty
              ? r.recognizedWords
              : '$_committed ${r.recognizedWords}'.trim();
          if (text != transcript) {
            transcript = text;
            partials.add(TimedWords(elapsedS, wordCount));
            notifyListeners();
          }
          if (r.finalResult) {
            _committed = transcript;
            _maybeRestart();
          }
        },
        onSoundLevelChange: (v) {
          // speech_to_text reports dB-ish levels around -2..10 on Android
          level = ((v + 2) / 12).clamp(0.0, 1.0);
          notifyListeners();
        },
      );
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  /// Restart the engine while the task still has time left.
  void _maybeRestart() {
    if (!_listening || _restarting || simulated || !_available) return;
    if (_wantSeconds - elapsedS < 2) return;
    _restarting = true;
    Future<void>.delayed(const Duration(milliseconds: 350), () async {
      _restarting = false;
      if (!_listening) return;
      if (_stt?.isListening ?? false) return;
      _committed = transcript;
      await _engineListen();
    });
  }

  /// Stops and returns the final transcript and the timed partials.
  Future<(String, List<TimedWords>)> stop() async {
    _sim?.cancel();
    _sim = null;
    _clock.stop();
    if (!simulated && _available) {
      try {
        await _stt?.stop();
      } catch (_) {}
      // give the engine a moment to flush the final result
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } else if (simulated &&
        _listening &&
        partials.isEmpty &&
        _simText.isNotEmpty) {
      transcript = _simText;
      partials.add(TimedWords(elapsedS, wordCount));
    }
    _listening = false;
    notifyListeners();
    return (transcript, List<TimedWords>.unmodifiable(partials));
  }

  Future<void> cancel() async {
    _sim?.cancel();
    _sim = null;
    _clock.stop();
    _listening = false;
    try {
      await _stt?.cancel();
    } catch (_) {}
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
