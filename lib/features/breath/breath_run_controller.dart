// State machine for the Breathing & Voice tasks (T-CAP lifecycle: idle →
// task running → between tasks → processing). One controller drives the
// questionnaire, cough, phonation, breath-sound and forced-exhale tasks of
// a protocol on the streamed microphone frames; the screen renders the
// matching view.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/domain/algorithms/breath_engines.dart';
import '../../core/domain/algorithms/breath_session_builder.dart';
import '../../core/domain/algorithms/hearing_engines.dart' show NoiseLevel;
import '../../core/domain/algorithms/mind_engines.dart' show VoiceFeatures;
import '../../core/domain/entities/breath_protocol.dart';
import '../../core/services/breath_audio_service.dart';

enum BreathPhase { idle, running, between, processing, aborted }

class BreathRunController extends ChangeNotifier {
  BreathRunController({
    required this.protocol,
    required this.prediction,
    this.audio,
    this.onSpeak,
    this.demoOutcome = BreathDemoOutcome.normal,
    this.adult = true,
    this.micOffsetDba = NoiseLevel.defaultMicOffsetDba,
  });

  final BreathProtocol protocol;

  /// Predicted spirometry values for the live effort table.
  final SpirometryPrediction prediction;
  final BreathAudioService? audio;
  final Future<void> Function(String text, {bool warning})? onSpeak;
  final bool adult;

  /// dBFS → dBA offset for the in-test room-noise monitor (CAP-12).
  final double micOffsetDba;
  BreathDemoOutcome demoOutcome;

  /// Test Controls: the first cough attempt hears only two coughs.
  bool simulateFewCoughs = false;

  /// Test Controls: blows 1–3 disagree so a 4th is needed.
  bool simulateUnrepeatable = false;

  /// Test Controls: the next recording clips (CAP-13 path).
  bool simulateClipping = false;

  static const int sampleRate = BreathAudioService.sampleRate;
  static const double restBetweenBlowsS = 20;

  BreathPhase phase = BreathPhase.idle;
  int taskIndex = 0;
  final List<BreathTaskCapture> captures = [];
  String coaching = '';
  DateTime? startedAt;
  bool autoRun = false;
  int _runToken = 0;
  Timer? _timer;
  Timer? _restTimer;

  /// Validation message after a task that produced nothing usable.
  String? retryMessage;

  /// Attempt number of the current task (E-AUD-001: up to 3).
  int attempt = 1;

  /// Clipped takes of the current task so far (CAP-13 re-record, max 2).
  int clippedAttempts = 0;

  BreathTask get currentTask =>
      protocol.tasks[math.min(taskIndex, protocol.tasks.length - 1)];
  bool get isLastTask => taskIndex >= protocol.tasks.length - 1;
  int get taskCount => protocol.tasks.length;
  String get partLabel =>
      '${currentTask.title} · ${taskIndex + 1} of $taskCount';

  // --- questionnaire --------------------------------------------------------
  int questionIndex = 0;
  final Map<String, int> answers = {};
  BreathQuestionnaire? get questionnaire => currentTask.questionnaire;
  BreathQuestion? get currentQuestion {
    final q = questionnaire;
    if (q == null || questionIndex >= q.questions.length) return null;
    return q.questions[questionIndex];
  }

  int get questionNumber {
    var n = 0;
    for (var i = 0; i < taskIndex; i++) {
      n += protocol.tasks[i].questionnaire?.questions.length ?? 0;
    }
    return n + questionIndex + 1;
  }

  int get questionTotal => protocol.tasks.fold(
    0,
    (s, t) => s + (t.questionnaire?.questions.length ?? 0),
  );

  // --- live audio -----------------------------------------------------------
  LiveFrameDetector? _live;
  double elapsedS = 0;
  int secondsLeft = 0;
  double level = 0;
  bool clipping = false;

  /// Live room level during a task (dBA from the capture's own frames).
  double? liveDba;
  bool roomTooNoisy = false;
  int _noisyTicks = 0;
  int _quietTicks = 0;

  // cough
  int liveCoughs = 0;
  int rejectedBursts = 0;
  String? lastRejectReason;
  bool circleGreen = false;

  /// True after the last accepted cough until the pulse has been shown.
  int pulseSerial = 0;

  // phonation
  double voicedS = 0;
  bool hearingVoice = false;

  // breath sounds (4 s cycle: 2 s in, 2 s out)
  double get pacerPhase => (elapsedS % 4) / 4;
  bool get inhaling => pacerPhase < 0.5;
  int get breathNumber => math.min(4, (elapsedS ~/ 4) + 1);

  // forced exhale
  final List<ExhaleEffort> efforts = [];
  SpirometryEstimate? _estimate;
  int countdown = 0;
  bool blowing = false;
  bool awaitingBlow = false;
  double blowS = 0;
  double flowLevel = 0;
  double peakLevel = 0;
  String effortCoach = '';
  double restLeftS = 0;

  /// Live estimate over the efforts so far.
  SpirometryEstimate? get liveEstimate => _estimate;
  int get validEfforts => efforts.where((e) => e.longEnough).length;
  int get effortNumber => efforts.length + 1;
  bool get resting => restLeftS > 0;

  bool get canFinishEarly {
    if (phase != BreathPhase.running) return false;
    final t = currentTask;
    return switch (t.type) {
      BreathTaskType.cough => liveCoughs >= CoughDetector.minValidCoughs,
      BreathTaskType.phonation => voicedS >= t.minSeconds,
      BreathTaskType.breathSounds => elapsedS >= 8,
      BreathTaskType.forcedExhale => blowing && blowS >= 3,
      BreathTaskType.questionnaire => false,
    };
  }

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  /// Starts (or resumes to) the current task.
  void start() {
    if (phase == BreathPhase.running || phase == BreathPhase.processing) {
      return;
    }
    _restTimer?.cancel();
    restLeftS = 0;
    startedAt ??= DateTime.now();
    retryMessage = null;
    phase = BreathPhase.running;
    final t = currentTask;
    final token = ++_runToken;
    final spoken = t.brief == null
        ? t.voiceLine
        : '${t.voiceLine} ${t.brief!.spoken}';
    switch (t.type) {
      case BreathTaskType.questionnaire:
        questionIndex = 0;
        coaching = questionnaire?.stem ?? '';
        if (taskIndex == 0) unawaited(onSpeak?.call(protocol.voiceStart));
        notifyListeners();
        _autoQuestion(token);
      case BreathTaskType.cough:
        _afterInstruction(token, spoken, () => _startCough(t, token));
      case BreathTaskType.phonation:
        _afterInstruction(token, spoken, () => _startPhonation(t, token));
      case BreathTaskType.breathSounds:
        _afterInstruction(token, spoken, () => _startBreath(t, token));
      case BreathTaskType.forcedExhale:
        if (efforts.isEmpty && attempt == 1 && clippedAttempts == 0) {
          _afterInstruction(
            token,
            spoken,
            () => _startExhaleCountdown(t, token),
          );
        } else {
          _startExhaleCountdown(t, token);
        }
    }
  }

  void _afterInstruction(int token, String line, void Function() then) {
    coaching = 'Listen to the instruction…';
    notifyListeners();
    unawaited(() async {
      try {
        await (onSpeak?.call(line) ?? Future<void>.value());
      } catch (_) {}
      if (token != _runToken || phase != BreathPhase.running) return;
      coaching = 'Get ready…';
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (token != _runToken || phase != BreathPhase.running) return;
      then();
    }());
  }

  void abort() {
    _runToken++;
    _timer?.cancel();
    _restTimer?.cancel();
    unawaited(_stopServices());
    phase = BreathPhase.aborted;
    notifyListeners();
  }

  @override
  void dispose() {
    _runToken++;
    _timer?.cancel();
    _restTimer?.cancel();
    unawaited(_stopServices());
    super.dispose();
  }

  Future<void> _stopServices() async {
    audio?.removeListener(_onAudio);
    await audio?.cancel();
  }

  void _resetLive() {
    _live = null;
    elapsedS = 0;
    secondsLeft = currentTask.seconds;
    level = 0;
    clipping = false;
    liveDba = null;
    roomTooNoisy = false;
    _noisyTicks = 0;
    _quietTicks = 0;
    liveCoughs = 0;
    rejectedBursts = 0;
    lastRejectReason = null;
    circleGreen = false;
    voicedS = 0;
    hearingVoice = false;
    countdown = 0;
    blowing = false;
    awaitingBlow = false;
    blowS = 0;
    flowLevel = 0;
    peakLevel = 0;
  }

  void _finishTask(BreathTaskCapture c) {
    _timer?.cancel();
    captures.add(c);
    attempt = 1;
    clippedAttempts = 0;
    efforts.clear();
    _estimate = null;
    effortCoach = '';
    if (taskIndex < protocol.tasks.length - 1) {
      taskIndex++;
      questionIndex = 0;
      _resetLive();
      final next = currentTask;
      // questionnaire → questionnaire flows straight on
      if (c.answers.isNotEmpty && next.type == BreathTaskType.questionnaire) {
        phase = BreathPhase.idle;
        start();
        return;
      }
      phase = BreathPhase.between;
      coaching = 'Next: ${next.title}';
      notifyListeners();
      if (autoRun) {
        _timer = Timer(const Duration(milliseconds: 400), () {
          if (phase == BreathPhase.between) start();
        });
      }
      return;
    }
    phase = BreathPhase.processing;
    coaching = 'Analysing…';
    unawaited(onSpeak?.call(protocol.voiceDone));
    notifyListeners();
  }

  /// Skip the current task.
  void skipTask() {
    if (phase == BreathPhase.processing || phase == BreathPhase.aborted) {
      return;
    }
    _runToken++;
    _timer?.cancel();
    _restTimer?.cancel();
    restLeftS = 0;
    unawaited(_stopServices());
    _finishTask(
      BreathTaskCapture(
        taskId: currentTask.id,
        skipped: true,
        skipReason: 'Skipped by the member',
        attempts: attempt,
      ),
    );
  }

  /// Repeat the current task after a validation failure.
  void retryTask() {
    if (phase != BreathPhase.between && phase != BreathPhase.running) return;
    retryMessage = null;
    phase = BreathPhase.idle;
    start();
  }

  void _retry(String message, {bool countAttempt = true}) {
    if (countAttempt) attempt++;
    retryMessage = message;
    phase = BreathPhase.between;
    coaching = 'Try again';
    notifyListeners();
    unawaited(onSpeak?.call(message, warning: true));
    if (autoRun) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 400), () {
        if (phase == BreathPhase.between) retryTask();
      });
    }
  }

  // ---------------------------------------------------------------------
  // Questionnaire
  // ---------------------------------------------------------------------

  void answerQuestion(int value) {
    if (phase != BreathPhase.running) return;
    final q = questionnaire;
    final item = currentQuestion;
    if (q == null || item == null) return;
    answers[item.id] = value;
    questionIndex++;
    if (questionIndex >= q.questions.length) {
      final own = {for (final x in q.questions) x.id: answers[x.id] ?? 0};
      _finishTask(BreathTaskCapture(taskId: currentTask.id, answers: own));
      return;
    }
    notifyListeners();
    _autoQuestion(_runToken);
  }

  void backQuestion() {
    if (phase != BreathPhase.running || questionIndex == 0) return;
    questionIndex--;
    notifyListeners();
  }

  void _autoQuestion(int token) {
    if (!autoRun) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 150), () {
      if (token != _runToken || phase != BreathPhase.running) return;
      final item = currentQuestion;
      final q = questionnaire;
      if (item == null || q == null) return;
      final sim = BreathSimulated.answersFor(q.id, demoOutcome);
      answerQuestion(sim[item.id] ?? 0);
    });
  }

  // ---------------------------------------------------------------------
  // Shared audio plumbing
  // ---------------------------------------------------------------------

  /// Starts the microphone for the current task; [take] builds the
  /// synthetic recording under simulation.
  Future<bool> _beginCapture(
    int token,
    LiveMode mode, {
    required List<int> Function() take,
  }) async {
    final svc = audio;
    if (svc == null) return false;
    final clip = simulateClipping;
    svc.simulatedTake = () {
      final s = take();
      if (!clip) return s;
      return [for (final v in s) (v * 9).clamp(-32768, 32767)];
    };
    svc.removeListener(_onAudio);
    svc.addListener(_onAudio);
    final ok = await svc.start();
    if (token != _runToken) return false;
    if (!ok) {
      _retry(
        svc.permissionDenied
            ? 'Microphone permission is needed (G-12). Allow the microphone and try again.'
            : 'The microphone could not be started. Close other apps using the microphone and try again.',
        countAttempt: false,
      );
      return false;
    }
    _live = LiveFrameDetector(mode, frameMs: svc.frameMs);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (phase != BreathPhase.running || token != _runToken) return;
      elapsedS += 0.1;
      secondsLeft = math.max(0, (currentTask.seconds - elapsedS).ceil());
      _tick(token);
    });
    return true;
  }

  void _onAudio() {
    final svc = audio;
    final live = _live;
    if (svc == null || live == null || phase != BreathPhase.running) return;
    final fresh = svc.takeNewFrames();
    if (fresh.isEmpty) return;
    final before = live.accepted;
    live.addFrames(fresh);
    level = live.levelNorm;
    clipping = svc.clipping;
    final db = svc.lastDbfs;
    if (db != null) {
      liveDba = NoiseLevel.dbaFromDbfs(db, offset: micOffsetDba);
      // room monitor: only quiet frames count (the member's own sound is
      // not room noise); 1 s hysteresis each way
      final quietFrame = !live.hearingVoice && !live.blowing;
      if (quietFrame && liveDba! > NoiseLevel.maxDba) {
        _noisyTicks++;
        _quietTicks = 0;
        if (_noisyTicks >= 10) roomTooNoisy = true;
      } else if (quietFrame) {
        _quietTicks++;
        _noisyTicks = 0;
        if (_quietTicks >= 10) roomTooNoisy = false;
      }
    }
    switch (currentTask.type) {
      case BreathTaskType.cough:
        liveCoughs = live.accepted;
        rejectedBursts = live.rejected;
        lastRejectReason = live.lastRejectReason;
        if (live.accepted > before) pulseSerial++;
      case BreathTaskType.phonation:
        hearingVoice = live.hearingVoice;
        voicedS = live.voicedS;
      case BreathTaskType.forcedExhale:
        flowLevel = live.levelNorm;
        if (flowLevel > peakLevel) peakLevel = flowLevel;
        if (!awaitingBlow) {
          blowing = live.blowing;
          blowS = live.blowS;
        }
      default:
        break;
    }
    notifyListeners();
  }

  Future<(List<int>, VoiceFeatures)> _endCapture() async {
    _timer?.cancel();
    final svc = audio;
    if (svc == null) {
      return (const <int>[], VoiceFeatures.extract(const [], sampleRate));
    }
    svc.removeListener(_onAudio);
    return svc.stopRaw();
  }

  void _tick(int token) {
    final t = currentTask;
    final live = _live;
    switch (t.type) {
      case BreathTaskType.cough:
        if (!circleGreen && elapsedS >= 0.5) {
          circleGreen = true;
          coaching = 'Cough now — three times';
        }
        final done =
            liveCoughs >= CoughDetector.minValidCoughs &&
            (live?.quietForS ?? 0) >= 1.5;
        if (done || elapsedS >= t.seconds) {
          unawaited(_completeCough(t));
          return;
        }
      case BreathTaskType.phonation:
        final silentAfterVoice =
            voicedS >= 1.0 && (live?.silentForS ?? 0) >= 1.0;
        if (silentAfterVoice || elapsedS >= t.seconds) {
          unawaited(_completePhonation(t));
          return;
        }
      case BreathTaskType.breathSounds:
        if (elapsedS >= t.seconds) {
          unawaited(_completeBreath(t));
          return;
        }
      case BreathTaskType.forcedExhale:
        if ((live?.blowEnded ?? false) || elapsedS >= t.seconds) {
          unawaited(_completeEffort(t));
          return;
        }
      case BreathTaskType.questionnaire:
        break;
    }
    notifyListeners();
  }

  /// CAP-13 clipping gate: re-record with distance coaching, at most twice.
  bool _clipGate(VoiceFeatures f, String what) {
    if (f.clipPct <= VoiceFeatures.maxClipPct) return false;
    if (clippedAttempts >= 2) return false; // accept with a quality warning
    clippedAttempts++;
    _retry(
      'Move phone further / quieter room: the recording of the $what was too loud for the microphone (clipping ${f.clipPct.toStringAsFixed(1)} %). Hold the phone at arm\'s length with the microphone turned slightly away from your mouth, then try again.',
      countAttempt: false,
    );
    return true;
  }

  // ---------------------------------------------------------------------
  // Cough (AUD-01)
  // ---------------------------------------------------------------------

  Future<void> _startCough(BreathTask t, int token) async {
    _resetLive();
    coaching = 'Get ready…';
    notifyListeners();
    final n = simulateFewCoughs && attempt == 1 ? 2 : 3;
    final wet = switch (demoOutcome) {
      BreathDemoOutcome.normal => 0.15,
      BreathDemoOutcome.borderline => 0.35,
      BreathDemoOutcome.refer => 0.7,
    };
    final ok = await _beginCapture(
      token,
      LiveMode.cough,
      take: () => BreathSimulated.coughs(n: n, wetness: wet),
    );
    if (!ok) return;
    coaching = 'Wait for green…';
    notifyListeners();
  }

  Future<void> _completeCough(BreathTask t) async {
    final token = ++_runToken;
    coaching = liveCoughs >= CoughDetector.minValidCoughs
        ? 'Heard $liveCoughs — checking they are coughs…'
        : 'Checking the recording…';
    notifyListeners();
    final (samples, f) = await _endCapture();
    if (token != _runToken) return;
    if (_clipGate(f, 'coughs')) return;
    final d = CoughDetector.detect(samples, sampleRate);
    if (!d.enough && attempt < t.attempts) {
      _retry(
        d.count == 0
            ? 'No clear cough was heard. Cough a little harder, three times — attempt ${attempt + 1} of ${t.attempts}.'
            : 'Only ${d.count} clear cough${d.count == 1 ? '' : 's'} heard; three are needed. Cough again with a short pause between coughs, and do not speak — attempt ${attempt + 1} of ${t.attempts}.',
      );
      return;
    }
    _finishTask(
      BreathTaskCapture(
        taskId: t.id,
        features: f,
        coughs: d,
        durationS: elapsedS,
        attempts: attempt,
        clipAccepted: f.clipPct > VoiceFeatures.maxClipPct,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Phonation (AUD-06)
  // ---------------------------------------------------------------------

  Future<void> _startPhonation(BreathTask t, int token) async {
    _resetLive();
    coaching = 'Get ready…';
    notifyListeners();
    final p = BreathSimulated.voiceParams(demoOutcome);
    final kind = t.phonation ?? PhonationKind.aaa;
    final holdS = switch (kind) {
      PhonationKind.aaa => math.min(p.mpt, t.seconds - 1.0),
      PhonationKind.sss => demoOutcome == BreathDemoOutcome.refer ? 9.0 : 12.0,
      PhonationKind.zzz => demoOutcome == BreathDemoOutcome.refer ? 5.0 : 11.0,
      PhonationKind.sentence => 3.0,
    };
    final ok = await _beginCapture(
      token,
      LiveMode.phonation,
      take: () => switch (kind) {
        PhonationKind.aaa => BreathSimulated.phonation(
          seconds: holdS,
          f0: p.f0,
          jitterPct: p.jitter,
          shimmerPct: p.shimmer,
          noise: p.noise,
          leadS: 0.8,
          tailS: 2.0,
        ),
        PhonationKind.sss => BreathSimulated.fricative(seconds: holdS),
        PhonationKind.zzz => BreathSimulated.fricative(
          seconds: holdS,
          voiced: true,
        ),
        PhonationKind.sentence => BreathSimulated.phonation(
          seconds: holdS,
          f0: p.f0 - 10,
          jitterPct: p.jitter,
          shimmerPct: p.shimmer,
          noise: p.noise,
          leadS: 0.8,
          tailS: 2.0,
        ),
      },
    );
    if (!ok) return;
    coaching = switch (kind) {
      PhonationKind.aaa => 'Deep breath… "aaa" as long as you can',
      PhonationKind.sss => 'Deep breath… "sss" as long as you can',
      PhonationKind.zzz => 'Deep breath… "zzz" as long as you can',
      PhonationKind.sentence => 'Read the sentence',
    };
    notifyListeners();
  }

  Future<void> _completePhonation(BreathTask t) async {
    final token = ++_runToken;
    coaching = 'Checking…';
    notifyListeners();
    final (samples, f) = await _endCapture();
    if (token != _runToken) return;
    final kind = t.phonation ?? PhonationKind.aaa;
    if (_clipGate(f, 'sound')) return;
    if (kind == PhonationKind.aaa) {
      final span = VoiceQuality.longestSpan(samples, sampleRate);
      final held = span?.durationS ?? 0;
      if (held < VoiceQuality.minPhonationS && attempt < t.attempts) {
        _retry(
          held <= 0
              ? 'We did not hear the "aaa". Take a deep breath and hold it for at least ${VoiceQuality.holdForS.toStringAsFixed(0)} seconds.'
              : '"aaa" lasted ${held.toStringAsFixed(1)} s — please hold it for at least ${VoiceQuality.holdForS.toStringAsFixed(0)} seconds.',
        );
        return;
      }
    } else if (kind != PhonationKind.sentence) {
      final held = VoiceQuality.phonatedS(samples, sampleRate);
      if (held < 1.0 && attempt < t.attempts) {
        _retry(
          'We did not hear the "${BreathTexts.phonationLabel(kind)}". Take a deep breath and hold it as long as you can — a soft sound is enough.',
        );
        return;
      }
    } else if (!f.heardSpeech && attempt < t.attempts) {
      _retry('We did not hear the sentence. Read it a little louder.');
      return;
    }
    _finishTask(
      BreathTaskCapture(
        taskId: t.id,
        features: f,
        samples: samples,
        durationS: voicedS,
        attempts: attempt,
        clipAccepted: f.clipPct > VoiceFeatures.maxClipPct,
      ),
    );
  }

  /// "I'm done" (after the minimum).
  void finishEarly() {
    if (!canFinishEarly) return;
    final t = currentTask;
    switch (t.type) {
      case BreathTaskType.cough:
        unawaited(_completeCough(t));
      case BreathTaskType.phonation:
        unawaited(_completePhonation(t));
      case BreathTaskType.breathSounds:
        unawaited(_completeBreath(t));
      case BreathTaskType.forcedExhale:
        unawaited(_completeEffort(t));
      case BreathTaskType.questionnaire:
        break;
    }
  }

  // ---------------------------------------------------------------------
  // Breath sounds (AUD-04 wheeze)
  // ---------------------------------------------------------------------

  Future<void> _startBreath(BreathTask t, int token) async {
    _resetLive();
    coaching = 'Get ready…';
    notifyListeners();
    final wheeze = demoOutcome != BreathDemoOutcome.normal;
    final ok = await _beginCapture(
      token,
      LiveMode.breath,
      take: () => BreathSimulated.breathSounds(
        seconds: t.seconds.toDouble(),
        wheeze: wheeze,
      ),
    );
    if (!ok) return;
    coaching = 'Breathe in… and out, with the ring';
    notifyListeners();
  }

  Future<void> _completeBreath(BreathTask t) async {
    final token = ++_runToken;
    coaching = 'Listening for wheeze…';
    notifyListeners();
    final (samples, f) = await _endCapture();
    if (token != _runToken) return;
    if (_clipGate(f, 'breathing')) return;
    final w = WheezeDetector.detect(samples, sampleRate);
    if (!w.heard && attempt < t.attempts) {
      _retry(
        'The breathing was too quiet to analyse. Breathe deeply through your mouth, a little closer to the phone.',
      );
      return;
    }
    _finishTask(
      BreathTaskCapture(
        taskId: t.id,
        features: f,
        wheeze: w,
        durationS: elapsedS,
        attempts: attempt,
        clipAccepted: f.clipPct > VoiceFeatures.maxClipPct,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Forced exhale (AUD-05)
  // ---------------------------------------------------------------------

  void _startExhaleCountdown(BreathTask t, int token) {
    _resetLive();
    awaitingBlow = true;
    countdown = 3;
    coaching = 'Deepest breath in…';
    notifyListeners();
    unawaited(() async {
      for (var n = 3; n >= 1; n--) {
        if (token != _runToken || phase != BreathPhase.running) return;
        countdown = n;
        notifyListeners();
        unawaited(onSpeak?.call('$n'));
        await Future<void>.delayed(const Duration(milliseconds: 650));
      }
      if (token != _runToken || phase != BreathPhase.running) return;
      countdown = 0;
      await _startBlow(t, token);
    }());
  }

  Future<void> _startBlow(BreathTask t, int token) async {
    final shapeIndex = efforts.length;
    final shapes = simulateUnrepeatable
        ? const ['normal', 'borderline', 'obstructed', 'normal', 'normal']
        : List<String>.filled(5, switch (demoOutcome) {
            BreathDemoOutcome.normal => 'normal',
            BreathDemoOutcome.borderline => 'borderline',
            BreathDemoOutcome.refer => 'obstructed',
          });
    final shape = shapes[math.min(shapeIndex, shapes.length - 1)];
    unawaited(onSpeak?.call('Blow!'));
    final ok = await _beginCapture(
      token,
      LiveMode.exhale,
      take: () => BreathSimulated.exhale(
        obstructed: shape == 'obstructed',
        borderline: shape == 'borderline',
        seed: 19 + shapeIndex * 7,
      ),
    );
    if (!ok) return;
    awaitingBlow = false;
    coaching = 'BLOW! Hard and fast… keep going';
    notifyListeners();
  }

  Future<void> _completeEffort(BreathTask t) async {
    final token = ++_runToken;
    coaching = 'Measuring the blow…';
    notifyListeners();
    final (samples, f) = await _endCapture();
    if (token != _runToken) return;
    if (_clipGate(f, 'blow')) {
      effortCoach =
          'Too loud for the microphone — arm\'s length, mic turned slightly away';
      return;
    }
    final e = ExhaleAnalyzer.analyze(samples, sampleRate);
    if (!e.heard) {
      if (efforts.length < t.maxEfforts - 1) {
        effortCoach = 'We did not hear the blow — closer to the phone';
        _retry(
          'We did not hear the blow. Hold the phone at arm\'s length with the microphone towards you and blow again.',
          countAttempt: false,
        );
      } else {
        _finishTask(
          BreathTaskCapture(
            taskId: t.id,
            efforts: List.of(efforts),
            attempts: attempt,
          ),
        );
      }
      return;
    }
    efforts.add(e);
    _estimate = AudioSpirometry.estimate(efforts, prediction);
    final est = _estimate!;
    final clipAccepted = f.clipPct > VoiceFeatures.maxClipPct;
    final enough = validEfforts >= t.efforts;
    final needMore =
        t.efforts > 1 &&
        enough &&
        !est.repeatable &&
        efforts.length < t.maxEfforts;
    if (!e.longEnough && efforts.length < t.maxEfforts) {
      effortCoach =
          'Blow ${efforts.length} lasted ${e.durationS.toStringAsFixed(1)} s — take a deeper breath and keep pushing for at least 3 s';
      _betweenEfforts(
        'Blow ${efforts.length} was only ${e.durationS.toStringAsFixed(1)} s. Take a deeper breath and keep pushing until empty — at least 3 seconds.',
      );
      return;
    }
    if ((enough && !needMore) || efforts.length >= t.maxEfforts) {
      _finishTask(
        BreathTaskCapture(
          taskId: t.id,
          features: f,
          efforts: List.of(efforts),
          durationS: e.durationS,
          attempts: efforts.length,
          clipAccepted: clipAccepted,
        ),
      );
      return;
    }
    if (needMore) {
      final diff = est.repeatabilityDiffPct ?? 0;
      effortCoach =
          'Best two blows differ by ${diff.toStringAsFixed(0)} % (limit 10 %) — one more try';
      _betweenEfforts(
        'Good. The best two blows differ by ${diff.toStringAsFixed(0)} % (limit 10 %), so one more blow is needed — blow ${efforts.length + 1} of ${t.maxEfforts}. Rest for 20 seconds first.',
      );
      return;
    }
    effortCoach = 'Blow ${efforts.length} recorded ✓';
    _betweenEfforts(
      'Blow ${efforts.length} recorded. Rest for 20 seconds, then blow ${efforts.length + 1} of ${t.efforts}.',
    );
  }

  /// Rest between blows with a visible countdown; "Start" skips the rest.
  void _betweenEfforts(String line) {
    phase = BreathPhase.between;
    retryMessage = null;
    coaching = line;
    restLeftS = restBetweenBlowsS;
    notifyListeners();
    unawaited(onSpeak?.call(line));
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (phase != BreathPhase.between) {
        timer.cancel();
        return;
      }
      restLeftS = math.max(0, restLeftS - 1);
      if (restLeftS == 0) {
        timer.cancel();
        unawaited(onSpeak?.call('Ready for the next blow when you are.'));
      }
      notifyListeners();
    });
    if (autoRun) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 500), () {
        if (phase == BreathPhase.between) start();
      });
    }
  }

  // ---------------------------------------------------------------------
  // Auto run (Test Controls / FLUTTER_TEST)
  // ---------------------------------------------------------------------

  void setAutoRun(bool on) {
    autoRun = on;
    if (on) {
      if (phase == BreathPhase.between) {
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 300), () {
          if (phase != BreathPhase.between) return;
          if (retryMessage != null) {
            retryTask();
          } else {
            start();
          }
        });
      } else if (phase == BreathPhase.running &&
          currentTask.type == BreathTaskType.questionnaire) {
        _autoQuestion(_runToken);
      }
    }
    notifyListeners();
  }

  /// Seconds since the test began (for the Analyse header).
  int get runSeconds =>
      startedAt == null ? 0 : DateTime.now().difference(startedAt!).inSeconds;
}
