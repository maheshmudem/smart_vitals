// State machine for the hearing screen (T-CAP lifecycle: idle → running ⇄
// paused (earphones / noise) → switch ear → processing). Spec §8 AUD-09:
// pure-tone staircase per ear, or digits-in-noise; E-AUD-004 pause on
// earphone disconnect; CAP-12 pause when the room exceeds 45 dBA.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/domain/algorithms/hearing_engines.dart';
import '../../core/domain/algorithms/hearing_session_builder.dart';
import '../../core/domain/entities/hearing_protocol.dart';
import '../../core/services/ambient_noise_service.dart';
import '../../core/services/audio_route_service.dart';
import '../../core/services/digit_speech_service.dart';
import '../../core/services/hearing_tone_service.dart';

enum HearingPhase {
  idle,
  running,
  pausedEarphones,
  pausedNoise,
  switchPart,
  processing,
  done,
  aborted,
}

/// Pure-tone trial state.
enum ToneState { idle, gap, playing, feedback }

class HearingRunController extends ChangeNotifier {
  HearingRunController({
    required this.protocol,
    this.tones,
    this.speech,
    this.route,
    this.noise,
    this.onSpeak,
    this.demoOutcome = HearingDemoOutcome.normal,
    int seed = 11,
  }) : _rng = math.Random(seed) {
    route?.addListener(_onRoute);
    noise?.addListener(_onNoise);
    if (protocol.perEar) currentEar = HearingEar.right;
  }

  final HearingProtocol protocol;
  final HearingToneService? tones;
  final DigitSpeechService? speech;
  final AudioRouteService? route;
  final AmbientNoiseService? noise;

  /// Speaks a line; the returned future completes when the voice has
  /// finished so timed trials never start under the instruction.
  final Future<void> Function(String text, {bool warning})? onSpeak;
  int _runToken = 0;
  final math.Random _rng;
  HearingDemoOutcome demoOutcome;

  HearingPhase phase = HearingPhase.idle;
  HearingEar? currentEar;
  final List<HearingPartCapture> captures = [];
  String coaching = '';
  DateTime? startedAt;
  int pauses = 0;
  HearingPhase? _resumeTo;

  // --- pure tone ----------------------------------------------------------
  int freqIndex = 0;
  HughsonWestlake? staircase;
  final Map<int, double> thresholds = {};
  final Set<int> noResponse = {};
  final List<TonePresentation> earPresentations = [];
  ToneState tone = ToneState.idle;
  bool? lastHeard;
  DateTime? _onsetAt;
  bool _windowOpen = false;
  Timer? _timer;

  static const double toneSeconds = 1.0;
  static const double responseWindowS = 1.5;

  int get currentHz => hearingTestOrderHz[math.min(freqIndex, 3)];
  String get currentHzLabel =>
      currentHz >= 1000 ? '${currentHz ~/ 1000} kHz' : '$currentHz Hz';

  /// True while a tap counts as "heard".
  bool get canTap =>
      phase == HearingPhase.running &&
      protocol.mode == HearingMode.pureTone &&
      _windowOpen;

  // --- digits in noise ----------------------------------------------------
  DigitsInNoise? din;
  final List<int> typed = [];
  bool dinAwaitingAnswer = false;
  bool dinSpeaking = false;
  int get dinRound => (din?.trials.length ?? 0) + 1;

  // --- auto listener (Test Controls / FLUTTER_TEST) -----------------------
  bool autoRun = false;

  int get partIndex => captures.length;
  int get partCount => protocol.perEar ? 2 : 1;
  String get partLabel => switch (protocol.mode) {
    HearingMode.pureTone =>
      '${currentEar?.label ?? ''} ear · $currentHzLabel · ${math.min(freqIndex + 1, 4)} of 4',
    HearingMode.digitsInNoise =>
      'Round ${math.min(dinRound, DigitsInNoise.totalTriplets)} of ${DigitsInNoise.totalTriplets}',
  };

  bool get paused =>
      phase == HearingPhase.pausedEarphones ||
      phase == HearingPhase.pausedNoise;

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  void start() {
    if (phase == HearingPhase.running) return;
    startedAt ??= DateTime.now();
    phase = HearingPhase.running;
    switch (protocol.mode) {
      case HearingMode.pureTone:
        freqIndex = 0;
        thresholds.clear();
        noResponse.clear();
        earPresentations.clear();
        _newStaircase();
        _afterInstruction(
          partIndex == 0 ? protocol.voiceStart : protocol.voiceSwitch,
          _scheduleTrial,
        );
      case HearingMode.digitsInNoise:
        din = DigitsInNoise(seed: _rng.nextInt(1 << 20));
        typed.clear();
        _afterInstruction(protocol.voiceStart, () => unawaited(_dinRound()));
    }
    notifyListeners();
  }

  /// Speak [line], wait for the voice to finish, show "Get ready…" for a
  /// moment, then run [then] — unless the run was paused or stopped.
  void _afterInstruction(String line, void Function() then) {
    final token = ++_runToken;
    coaching = 'Listen to the instruction…';
    notifyListeners();
    unawaited(() async {
      try {
        await (onSpeak?.call(line) ?? Future<void>.value());
      } catch (_) {}
      if (token != _runToken || phase != HearingPhase.running) return;
      coaching = 'Get ready…';
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (token != _runToken || phase != HearingPhase.running) return;
      coaching = 'Listen…';
      then();
    }());
  }

  void abort() {
    _runToken++;
    _timer?.cancel();
    unawaited(tones?.stopTone());
    unawaited(tones?.stopNoise());
    unawaited(speech?.stop());
    phase = HearingPhase.aborted;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    route?.removeListener(_onRoute);
    noise?.removeListener(_onNoise);
    unawaited(tones?.stopNoise());
    super.dispose();
  }

  void _finishPart(HearingPartCapture capture) {
    _timer?.cancel();
    _windowOpen = false;
    tone = ToneState.idle;
    captures.add(capture);
    if (captures.length < partCount) {
      currentEar = currentEar!.other;
      phase = HearingPhase.switchPart;
      coaching = 'Now the ${currentEar!.label.toLowerCase()} ear';
      notifyListeners();
      return;
    }
    phase = HearingPhase.processing;
    coaching = 'Analysing…';
    unawaited(tones?.stopNoise());
    onSpeak?.call(protocol.voiceDone);
    notifyListeners();
  }

  /// Skip the current ear (pure tone) or the whole block.
  void skipPart() {
    if (phase == HearingPhase.processing || phase == HearingPhase.done) return;
    _finishPart(
      HearingPartCapture(
        ear: protocol.perEar ? currentEar : null,
        skipped: true,
        skipReason: 'Skipped by the member',
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Gates during the test (G-19 earphones, G-18 noise)
  // ---------------------------------------------------------------------

  void _onRoute() {
    final r = route;
    if (r == null) return;
    if (phase == HearingPhase.running && !r.state.connected) {
      _pause(HearingPhase.pausedEarphones);
      coaching = 'Earphones disconnected — plug them in to continue';
      onSpeak?.call(
        'Earphones disconnected. Plug them in to continue.',
        warning: true,
      );
      notifyListeners();
    } else if (phase == HearingPhase.pausedEarphones && r.state.connected) {
      _resume();
    }
  }

  // Tick-counted (the noise service samples every 200 ms) so the 1 s
  // hysteresis also works under the widget-test fake clock.
  int _noisyTicks = 0;
  int _quietTicks = 0;
  static const int _hysteresisTicks = 5;

  void _onNoise() {
    final n = noise;
    if (n == null || n.currentDba == null) return;
    final loud = !NoiseLevel.passes(n.currentDba!);
    if (phase == HearingPhase.running) {
      if (loud) {
        _noisyTicks++;
        if (_noisyTicks >= _hysteresisTicks) {
          _pause(HearingPhase.pausedNoise);
          coaching =
              'Too noisy (${n.currentDba!.toStringAsFixed(0)} dBA) — wait for quiet';
          onSpeak?.call(
            'The room is too noisy. Wait for quiet.',
            warning: true,
          );
          _quietTicks = 0;
          notifyListeners();
        }
      } else {
        _noisyTicks = 0;
      }
    } else if (phase == HearingPhase.pausedNoise) {
      if (!loud) {
        _quietTicks++;
        if (_quietTicks >= _hysteresisTicks) {
          _noisyTicks = 0;
          _resume();
        }
      } else {
        _quietTicks = 0;
        coaching =
            'Too noisy (${n.currentDba!.toStringAsFixed(0)} dBA) — wait for quiet';
        notifyListeners();
      }
    }
  }

  void _pause(HearingPhase to) {
    if (phase != HearingPhase.running) return;
    pauses++;
    _runToken++;
    _timer?.cancel();
    _windowOpen = false;
    tone = ToneState.idle;
    dinAwaitingAnswer = false;
    unawaited(tones?.stopTone());
    unawaited(tones?.stopNoise());
    unawaited(speech?.stop());
    _resumeTo = phase;
    phase = to;
  }

  void _resume() {
    if (!paused) return;
    phase = _resumeTo ?? HearingPhase.running;
    _resumeTo = null;
    coaching = 'Carrying on…';
    notifyListeners();
    switch (protocol.mode) {
      case HearingMode.pureTone:
        _scheduleTrial();
      case HearingMode.digitsInNoise:
        typed.clear();
        unawaited(_dinRound());
    }
  }

  /// Member taps "Continue" on a pause card (route confirmed manually).
  void resumeManually() {
    if (phase == HearingPhase.pausedEarphones) {
      route?.setManualConfirmed(true);
      _resume();
    } else if (phase == HearingPhase.pausedNoise) {
      _noisyTicks = 0;
      _resume();
    }
  }

  // ---------------------------------------------------------------------
  // Pure tone
  // ---------------------------------------------------------------------

  void _newStaircase() {
    staircase = HughsonWestlake(
      ear: currentEar!,
      hz: currentHz,
      seed: _rng.nextInt(1 << 20),
    );
  }

  void _scheduleTrial() {
    if (phase != HearingPhase.running) return;
    _timer?.cancel();
    tone = ToneState.gap;
    _windowOpen = false;
    lastHeard = null;
    final gapMs = autoRun
        ? 250
        : 1000 + _rng.nextInt(1500); // U(1, 2.5) s [DER]
    notifyListeners();
    _timer = Timer(Duration(milliseconds: gapMs), _present);
  }

  Future<void> _present() async {
    if (phase != HearingPhase.running || staircase == null) return;
    final s = staircase!;
    final isCatch = s.nextIsCatch();
    tone = ToneState.playing;
    _windowOpen = true;
    if (isCatch) {
      _onsetAt = DateTime.now();
    } else {
      _onsetAt =
          await tones?.playTone(currentEar!, currentHz, s.level) ??
          DateTime.now();
    }
    coaching = 'Listen…';
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: ((toneSeconds + responseWindowS) * 1000).round()),
      () => _respond(false),
    );
    if (autoRun) _autoAnswer(isCatch);
  }

  /// The big button.
  void onTap() {
    if (!canTap) return;
    final ms = _onsetAt == null
        ? null
        : DateTime.now().difference(_onsetAt!).inMilliseconds.toDouble();
    _respond(true, latencyMs: ms);
  }

  void _respond(bool heard, {double? latencyMs}) {
    if (phase != HearingPhase.running || staircase == null) return;
    _timer?.cancel();
    _windowOpen = false;
    unawaited(tones?.stopTone());
    final s = staircase!;
    s.answer(heard, latencyMs: latencyMs);
    lastHeard = heard;
    tone = ToneState.feedback;
    coaching = heard ? 'Heard ✓' : 'Not heard';
    notifyListeners();
    if (s.done) {
      thresholds[currentHz] = s.threshold!;
      if (s.noResponse) noResponse.add(currentHz);
      earPresentations.addAll(s.presentations);
      freqIndex++;
      if (freqIndex >= hearingTestOrderHz.length) {
        final ear = currentEar!;
        _timer = Timer(const Duration(milliseconds: 500), () {
          _finishPart(
            HearingPartCapture(
              ear: ear,
              thresholds: Map.unmodifiable(thresholds),
              noResponse: Set.unmodifiable(noResponse),
              presentations: List.unmodifiable(earPresentations),
            ),
          );
        });
        return;
      }
      _newStaircase();
      coaching = 'Next pitch: $currentHzLabel';
      notifyListeners();
    }
    _timer = Timer(const Duration(milliseconds: 450), _scheduleTrial);
  }

  // ---------------------------------------------------------------------
  // Digits in noise
  // ---------------------------------------------------------------------

  Future<void> _dinRound() async {
    final d = din;
    if (d == null || phase != HearingPhase.running) return;
    if (d.done) {
      unawaited(tones?.stopNoise());
      _finishPart(
        HearingPartCapture(
          dinTrials: List.unmodifiable(d.trials),
          srtDb: d.srtDb,
        ),
      );
      return;
    }
    final digits = d.next();
    dinAwaitingAnswer = false;
    dinSpeaking = true;
    coaching = 'Listen…';
    notifyListeners();
    await tones?.playNoise(DigitsInNoise.noiseGain());
    await Future<void>.delayed(Duration(milliseconds: autoRun ? 100 : 700));
    if (phase != HearingPhase.running) return;
    await speech?.speakTriplet(digits, DigitsInNoise.speechGain(d.snrDb));
    if (phase != HearingPhase.running) return;
    dinSpeaking = false;
    dinAwaitingAnswer = true;
    coaching = 'Type the three numbers';
    notifyListeners();
    if (autoRun) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 200), () {
        if (!dinAwaitingAnswer) return;
        final correct = HearingSimulated.dinCorrect(
          d.snrDb,
          HearingSimulated.dinSrt(demoOutcome),
          _rng,
        );
        typed
          ..clear()
          ..addAll(correct ? digits : digits.map((x) => (x + 1) % 10).toList());
        submitDin();
      });
    }
  }

  void typeDigit(int d) {
    if (!dinAwaitingAnswer || typed.length >= 3) return;
    typed.add(d);
    notifyListeners();
  }

  void backspace() {
    if (!dinAwaitingAnswer || typed.isEmpty) return;
    typed.removeLast();
    notifyListeners();
  }

  void submitDin() {
    final d = din;
    if (d == null || !dinAwaitingAnswer || typed.length < 3) return;
    dinAwaitingAnswer = false;
    d.answer(List<int>.from(typed));
    typed.clear();
    coaching = d.trials.last.correct ? 'Correct ✓' : 'Not quite';
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: autoRun ? 100 : 600),
      () => unawaited(_dinRound()),
    );
  }

  // ---------------------------------------------------------------------
  // Auto listener (Test Controls / FLUTTER_TEST)
  // ---------------------------------------------------------------------

  void setAutoRun(bool on) {
    autoRun = on;
    notifyListeners();
  }

  void _autoAnswer(bool isCatch) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 120), () {
      if (!_windowOpen || staircase == null) return;
      final t = HearingSimulated.thresholds(
        demoOutcome,
      )[currentEar!]![currentHz]!;
      final heard = HearingSimulated.hears(
        staircase!.level,
        t,
        _rng,
        isCatch: isCatch,
      );
      if (heard) {
        onTap();
      } else {
        _respond(false);
      }
    });
  }
}
