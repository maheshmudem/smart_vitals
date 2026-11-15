// State machine for the Brain & Mind tasks (T-CAP lifecycle: idle → task
// running → between tasks → processing). One controller drives the
// questionnaire, transcript, recording, face-smile and arm-drift tasks of a
// protocol; the screen renders the matching view.
//
// Stroke check rule (MOV-06..09): never fabricate a result on a device —
// a step whose sensor is missing or saw nothing is recorded as not
// assessed; the first positive sign stops the run and goes to S-R02.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/domain/algorithms/mind_engines.dart';
import '../../core/domain/algorithms/mind_session_builder.dart';
import '../../core/domain/algorithms/movement_engines.dart' show MotionSample;
import '../../core/domain/entities/mind_protocol.dart';
import '../../core/services/live_camera_service.dart';
import '../../core/services/motion_sensor_service.dart';
import '../../core/services/speech_capture_service.dart';
import '../../core/services/speech_transcribe_service.dart';

enum MindPhase { idle, running, between, processing, aborted }

/// Face task stage: find the face in the oval, rest, then smile.
enum FaceStage { finding, rest, smile }

class MindRunController extends ChangeNotifier {
  MindRunController({
    required this.protocol,
    required this.language,
    this.transcribe,
    this.capture,
    this.camera,
    this.onSpeak,
    this.onFaceDone,
    this.demoOutcome = MindDemoOutcome.normal,
    this.motionUnavailable = false,
    int seed = 11,
  }) : _rng = math.Random(seed);

  final MindProtocol protocol;
  final MindLanguage language;
  final SpeechTranscribeService? transcribe;
  final SpeechCaptureService? capture;
  final BiometricCameraController? camera;
  final Future<void> Function(String text, {bool warning})? onSpeak;

  /// The face task finished: the screen can release the camera.
  final VoidCallback? onFaceDone;
  final math.Random _rng;
  MindDemoOutcome demoOutcome;

  /// Set by the screen after `MotionSensorService.probe()`: no
  /// accelerometer on this phone → the arm steps are recorded as not
  /// assessed instead of simulated.
  bool motionUnavailable;

  MindPhase phase = MindPhase.idle;
  int taskIndex = 0;
  final List<MindTaskCapture> captures = [];
  String coaching = '';
  DateTime? startedAt;
  bool autoRun = false;
  int _runToken = 0;
  Timer? _timer;

  /// Set when PHQ-9 item 9 is answered > 0; the screen shows S-G14 at once.
  bool crisisRaised = false;
  bool crisisAcknowledged = false;
  bool clinicianNotified = false;

  /// Validation message after a task that produced nothing usable.
  String? retryMessage;

  /// Stroke: the run stopped at the first positive sign (MOV-09).
  bool stoppedEarly = false;
  List<String> earlySigns = const [];

  static const double faceFindTimeoutS = 15;
  static const double faceRestS = 3;
  static const double faceSmileS = 4;
  static const double faceSmileWarmupS = 0.8;
  static const int faceMaxAttempts = 2;
  static const double armSettleS = 2;
  static const double armBaselineS = 1;

  MindTask get currentTask =>
      protocol.tasks[math.min(taskIndex, protocol.tasks.length - 1)];
  bool get isLastTask => taskIndex >= protocol.tasks.length - 1;
  int get taskCount => protocol.tasks.length;
  String get partLabel =>
      '${currentTask.title} · ${taskIndex + 1} of $taskCount';

  bool get _isStroke => protocol.kind == MindKind.stroke;

  // --- questionnaire --------------------------------------------------------
  int questionIndex = 0;
  final Map<String, int> answers = {};
  MindQuestionnaire? get questionnaire => currentTask.questionnaire;
  MindQuestion? get currentQuestion {
    final q = questionnaire;
    if (q == null || questionIndex >= q.questions.length) return null;
    return q.questions[questionIndex];
  }

  /// Global question number across all questionnaire tasks (1-based).
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

  // --- timed tasks ----------------------------------------------------------
  int secondsLeft = 0;
  double elapsedS = 0;
  double level = 0;
  String transcript = '';
  int liveCount = 0;
  String liveCountLabel = '';
  double _lastVoiceAt = 0;

  /// Seconds since the microphone last heard the member (for the
  /// "speak louder" hint).
  double get quietForS => elapsedS - _lastVoiceAt;

  /// Recognised animals / picture details so far (chips on the task view).
  List<String> liveItems = const [];

  /// Helper tally when speech recognition is unavailable.
  int manualTally = 0;

  /// Stroke speech: recognition unavailable or heard nothing → a helper
  /// judges the sentence (clear / slurred / could not speak).
  bool helperMode = false;
  String helperPrompt = '';

  void addManualTally() {
    if (phase != MindPhase.running) return;
    manualTally++;
    liveCount = manualTally;
    liveCountLabel = 'counted';
    notifyListeners();
  }

  // --- face -----------------------------------------------------------------
  FaceStage faceStage = FaceStage.finding;
  final List<FaceGeometry> _restSamples = [];
  final List<FaceGeometry> _smileSamples = [];
  bool faceSeen = false;
  double? liveAsymmetry;
  int faceAttempts = 0;
  double _stageStartS = 0;

  /// Seconds left in the current face stage (for the ring).
  double get faceStageLeftS => switch (faceStage) {
    FaceStage.finding => math.max(0, faceFindTimeoutS - elapsedS),
    FaceStage.rest => math.max(0, faceRestS - (elapsedS - _stageStartS)),
    FaceStage.smile => math.max(0, faceSmileS - (elapsedS - _stageStartS)),
  };
  int get restFrames => _restSamples.length;
  int get smileFrames => _smileSamples.length;

  // --- arm ------------------------------------------------------------------
  StreamSubscription<MotionSample>? _motionSub;
  final List<MotionSample> _motion = [];

  /// Step-clock time (elapsedS) at which each sample arrived; the device
  /// stream may start late and its own timestamps are not comparable to
  /// the step timer, so windows are cut on arrival time.
  final List<double> _arrival = [];
  double liveDropDeg = 0;
  bool motionActive = false;
  bool _motionError = false;

  /// Arm hold: settle (2 s) → hold (10 s, countdown spoken at the end).
  bool get armSettling =>
      currentTask.type == MindTaskType.armDrift &&
      phase == MindPhase.running &&
      elapsedS < armSettleS;
  double get armHoldLeftS =>
      math.max(0, armSettleS + armBaselineS + currentTask.seconds - elapsedS);

  bool get canFinishEarly =>
      phase == MindPhase.running &&
      !helperMode &&
      (currentTask.type == MindTaskType.speechTranscribe ||
          currentTask.type == MindTaskType.speechRecord) &&
      elapsedS >= currentTask.minSeconds;

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  /// Starts (or resumes to) the current task.
  void start() {
    if (phase == MindPhase.running || phase == MindPhase.processing) return;
    startedAt ??= DateTime.now();
    retryMessage = null;
    helperMode = false;
    phase = MindPhase.running;
    final t = currentTask;
    final token = ++_runToken;
    switch (t.type) {
      case MindTaskType.questionnaire:
        questionIndex = 0;
        coaching = questionnaire?.stem ?? '';
        if (taskIndex == 0) unawaited(onSpeak?.call(protocol.voiceStart));
        notifyListeners();
        _autoQuestion(token);
      case MindTaskType.speechTranscribe:
      case MindTaskType.speechRecord:
        _afterInstruction(
          token,
          _speechInstruction(t),
          () => _startSpeech(t, token),
        );
      case MindTaskType.faceSmile:
        _afterInstruction(
          token,
          '${protocol.voiceStart} ${t.whatToDo.isEmpty ? '' : t.whatToDo.first}.',
          () => _startFace(t, token),
        );
      case MindTaskType.armDrift:
        if (_isStroke && motionUnavailable) {
          _finishTask(
            MindTaskCapture(
              taskId: t.id,
              skipped: true,
              skipReason:
                  'Motion sensor unavailable on this phone — step not assessed',
              source: 'none',
            ),
          );
          return;
        }
        _afterInstruction(
          token,
          '${t.arm == 'left' ? 'Left' : 'Right'} arm. Hold the phone flat in your palm, arm straight out at shoulder height, and close your eyes. Hold still.',
          () => _startArm(t, token),
        );
    }
  }

  String _speechInstruction(MindTask t) {
    if (t.sentenceKey != null) {
      return protocol.kind == MindKind.stroke
          ? 'Repeat this sentence: ${MindTexts.sentence(t.sentenceKey!, language)}'
          : protocol.voiceStart;
    }
    return switch (t.id) {
      'fluency' => protocol.voiceStart,
      'picture' =>
        'Now describe everything you see in the picture for one minute.',
      'free_speech' =>
        'Now talk for one minute about your day or anything on your mind.',
      _ => t.instruction,
    };
  }

  void _afterInstruction(int token, String line, void Function() then) {
    coaching = 'Listen to the instruction…';
    notifyListeners();
    unawaited(() async {
      try {
        await (onSpeak?.call(line) ?? Future<void>.value());
      } catch (_) {}
      if (token != _runToken || phase != MindPhase.running) return;
      coaching = 'Get ready…';
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (token != _runToken || phase != MindPhase.running) return;
      then();
    }());
  }

  void abort() {
    _runToken++;
    _timer?.cancel();
    unawaited(_stopServices());
    phase = MindPhase.aborted;
    notifyListeners();
  }

  @override
  void dispose() {
    _runToken++;
    _timer?.cancel();
    unawaited(_stopServices());
    super.dispose();
  }

  Future<void> _stopServices() async {
    transcribe?.removeListener(_onTranscribe);
    capture?.removeListener(_onCapture);
    final sub = _motionSub;
    _motionSub = null;
    motionActive = false;
    unawaited(sub?.cancel());
    await transcribe?.cancel();
    await capture?.cancel();
  }

  void _finishTask(MindTaskCapture c) {
    _timer?.cancel();
    captures.add(c);
    if (c.taskId == 'face') onFaceDone?.call();
    helperMode = false;
    // MOV-09: the first positive sign ends the check at once
    if (_isStroke && !isLastTask) {
      final d = _decisionSoFar();
      if (d.positive) {
        stoppedEarly = true;
        earlySigns = d.signs;
        for (var i = taskIndex + 1; i < protocol.tasks.length; i++) {
          captures.add(
            MindTaskCapture(
              taskId: protocol.tasks[i].id,
              skipped: true,
              skipReason: 'Not needed — a sign was already positive',
              source: 'none',
            ),
          );
        }
        phase = MindPhase.processing;
        coaching = 'A warning sign was found — going to the emergency screen';
        unawaited(
          onSpeak?.call(
            'A warning sign was found. Stop the check and call for help now.',
            warning: true,
          ),
        );
        notifyListeners();
        return;
      }
    }
    if (taskIndex < protocol.tasks.length - 1) {
      taskIndex++;
      questionIndex = 0;
      elapsedS = 0;
      secondsLeft = 0;
      transcript = '';
      liveCount = 0;
      final next = currentTask;
      // questionnaire → questionnaire flows straight on
      if (c.answers.isNotEmpty && next.type == MindTaskType.questionnaire) {
        phase = MindPhase.idle;
        start();
        return;
      }
      phase = MindPhase.between;
      coaching = 'Next: ${next.title}';
      notifyListeners();
      if (_isStroke) {
        unawaited(
          onSpeak?.call('Done. Next: ${next.title}. ${next.instruction}'),
        );
      }
      if (autoRun) {
        _timer = Timer(const Duration(milliseconds: 400), () {
          if (phase == MindPhase.between) start();
        });
      }
      return;
    }
    phase = MindPhase.processing;
    coaching = 'Analysing…';
    unawaited(onSpeak?.call(protocol.voiceDone));
    notifyListeners();
  }

  /// Decision from the captures recorded so far (stroke only).
  StrokeDecisionResult _decisionSoFar() {
    double? face, armL, armR, speech;
    for (final c in captures) {
      if (c.skipped) continue;
      switch (c.taskId) {
        case 'face':
          if (c.faceRestFrames.isNotEmpty && c.faceSmileFrames.isNotEmpty) {
            face = FaceAsymmetry.computeFrames(
              rest: c.faceRestFrames,
              smile: c.faceSmileFrames,
            ).score;
          } else if (c.faceRest != null && c.faceSmile != null) {
            face = FaceAsymmetry.compute(
              rest: c.faceRest!,
              smile: c.faceSmile!,
            ).score;
          }
        case 'arm_right':
        case 'arm_left':
          if (c.armStart != null && c.armEnd != null) {
            final cm = ArmDrift.dropCm(
              ArmDrift.pitchDropDegrees(c.armStart!, c.armEnd!),
            );
            if (c.taskId == 'arm_left') {
              armL = cm;
            } else {
              armR = cm;
            }
          }
        case 'speech':
          if (c.helperJudgement != null) {
            speech =
                SpeechAbnormality.helperProbs[c.helperJudgement!.clamp(0, 2)];
          } else if ((c.transcript ?? '').trim().isNotEmpty) {
            speech = SpeechAbnormality.prob(
              MindTexts.sentence('strokeSentence', language),
              c.transcript!,
              wordsPerSec: SpeechAbnormality.wordsPerSecond(
                c.partials,
                c.durationS ?? 8,
              ),
            );
          }
      }
    }
    return StrokeDecision.evaluate(
      faceScore: face,
      armDriftLCm: armL,
      armDriftRCm: armR,
      speechProb: speech,
    );
  }

  /// Skip the current task (safety: the stroke check never blocks).
  void skipTask() {
    if (phase == MindPhase.processing || phase == MindPhase.aborted) return;
    _runToken++;
    unawaited(_stopServices());
    _finishTask(
      MindTaskCapture(
        taskId: currentTask.id,
        skipped: true,
        skipReason: 'Skipped by the member',
        source: _isStroke ? 'none' : '',
      ),
    );
  }

  /// Repeat the current task after a validation failure.
  void retryTask() {
    if (phase != MindPhase.between && phase != MindPhase.running) return;
    retryMessage = null;
    helperMode = false;
    phase = MindPhase.idle;
    start();
  }

  // ---------------------------------------------------------------------
  // Questionnaire
  // ---------------------------------------------------------------------

  void answerQuestion(int value) {
    if (phase != MindPhase.running) return;
    final q = questionnaire;
    final item = currentQuestion;
    if (q == null || item == null) return;
    answers[item.id] = value;
    if (q.crisisItemId == item.id && value > 0 && !crisisAcknowledged) {
      // Spec §8 AUD-11 / G-37: before anything else.
      crisisRaised = true;
      notifyListeners();
      return;
    }
    _advanceQuestion();
  }

  /// The crisis screen was acknowledged; carry on with the questionnaire.
  void acknowledgeCrisis({required bool notifyClinician}) {
    crisisAcknowledged = true;
    clinicianNotified = notifyClinician;
    crisisRaised = false;
    _advanceQuestion();
  }

  void _advanceQuestion() {
    final q = questionnaire!;
    questionIndex++;
    if (questionIndex >= q.questions.length) {
      final own = {
        for (final item in q.questions) item.id: answers[item.id] ?? 0,
      };
      _finishTask(MindTaskCapture(taskId: currentTask.id, answers: own));
      return;
    }
    notifyListeners();
    _autoQuestion(_runToken);
  }

  void backQuestion() {
    if (phase != MindPhase.running || questionIndex == 0) return;
    questionIndex--;
    notifyListeners();
  }

  void _autoQuestion(int token) {
    if (!autoRun) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 150), () {
      if (token != _runToken || phase != MindPhase.running || crisisRaised) {
        return;
      }
      final item = currentQuestion;
      if (item == null) return;
      final sim = MindSimulated.moodAnswers(demoOutcome);
      answerQuestion(sim[item.id] ?? 0);
    });
  }

  // ---------------------------------------------------------------------
  // Speech tasks
  // ---------------------------------------------------------------------

  Future<void> _startSpeech(MindTask t, int token) async {
    secondsLeft = t.seconds;
    elapsedS = 0;
    transcript = '';
    liveCount = 0;
    liveCountLabel = '';
    liveItems = const [];
    manualTally = 0;
    _lastVoiceAt = 0;
    helperMode = false;
    coaching = t.instruction;
    notifyListeners();
    if (t.type == MindTaskType.speechTranscribe) {
      final svc = transcribe;
      if (_isStroke && (svc == null || !svc.available)) {
        // no recogniser (device, or Test Controls) → a helper judges
        _enterHelperMode(
          'Speech recognition is not available on this phone. Ask the person to repeat the sentence, then choose what you heard.',
        );
        return;
      }
      if (svc != null) {
        svc.removeListener(_onTranscribe);
        svc.addListener(_onTranscribe);
        final plan = t.sentenceKey != null
            ? (
                [TimedWords(1.0, 3), TimedWords(2.2, 7), TimedWords(3.0, 9)],
                MindSimulated.strokeSentence(demoOutcome, language),
              )
            : t.id == 'picture'
            ? MindSimulated.pictureTranscript(demoOutcome, seconds: t.seconds)
            : MindSimulated.fluencyTranscript(
                demoOutcome,
                language,
                seconds: t.seconds,
              );
        final ok = await svc.listen(
          language: language,
          seconds: t.seconds,
          simulatedPlan: plan,
        );
        if (token != _runToken) return;
        if (!ok && _isStroke) {
          // no recogniser on this device → a helper judges the sentence
          _enterHelperMode(
            'Speech recognition is not available on this phone. Ask the person to repeat the sentence, then choose what you heard.',
          );
          return;
        }
      } else if (_isStroke) {
        _enterHelperMode(
          'Speech recognition is not available. Ask the person to repeat the sentence, then choose what you heard.',
        );
        return;
      }
    } else {
      final svc = capture;
      if (svc != null) {
        svc.simulatedOutcome = demoOutcome;
        svc.removeListener(_onCapture);
        svc.addListener(_onCapture);
        await svc.start();
      }
    }
    if (token != _runToken) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (phase != MindPhase.running) return;
      elapsedS += 1;
      secondsLeft = math.max(0, t.seconds - elapsedS.round());
      if (secondsLeft == 0) {
        unawaited(_completeSpeech(t));
      } else {
        notifyListeners();
      }
    });
  }

  void _enterHelperMode(String prompt) {
    _timer?.cancel();
    helperMode = true;
    helperPrompt = prompt;
    coaching = 'What did you hear?';
    phase = MindPhase.running;
    notifyListeners();
    unawaited(onSpeak?.call(prompt));
    if (autoRun) {
      _timer = Timer(const Duration(milliseconds: 400), () {
        if (phase == MindPhase.running && helperMode) {
          judgeSpeech(
            demoOutcome == MindDemoOutcome.refer ||
                    demoOutcome == MindDemoOutcome.crisis
                ? 1
                : 0,
          );
        }
      });
    }
  }

  /// Helper judgement of the stroke sentence: 0 clear · 1 slurred · 2
  /// could not speak.
  void judgeSpeech(int judgement) {
    if (phase != MindPhase.running || !helperMode) return;
    _timer?.cancel();
    final t = currentTask;
    unawaited(transcribe?.cancel());
    transcribe?.removeListener(_onTranscribe);
    _finishTask(
      MindTaskCapture(
        taskId: t.id,
        helperJudgement: judgement.clamp(0, 2),
        durationS: elapsedS,
        source: 'helper',
      ),
    );
  }

  void _onTranscribe() {
    final svc = transcribe!;
    transcript = svc.transcript;
    level = svc.level;
    if (level > 0.3) _lastVoiceAt = elapsedS;
    final tokens = TranscriptAnalysis.tokenize(transcript);
    if (currentTask.id == 'fluency') {
      final f = FluencyScorer.score(tokens, language);
      liveCount = f.count;
      liveItems = f.valid;
      liveCountLabel = 'animals';
    } else if (currentTask.id == 'picture') {
      final u = PictureScorer.infoUnits(tokens);
      liveCount = u.length;
      liveItems = u;
      liveCountLabel = 'details';
    } else {
      liveCount = tokens.length;
      liveCountLabel = 'words';
    }
    notifyListeners();
  }

  void _onCapture() {
    level = capture!.level;
    if (level > 0.3) _lastVoiceAt = elapsedS;
    notifyListeners();
  }

  /// "I'm done" (after the minimum time).
  void finishEarly() {
    if (!canFinishEarly) return;
    unawaited(_completeSpeech(currentTask));
  }

  Future<void> _completeSpeech(MindTask t) async {
    _timer?.cancel();
    final token = ++_runToken;
    coaching = 'Saving…';
    notifyListeners();
    if (t.type == MindTaskType.speechTranscribe) {
      final svc = transcribe;
      final (text, partials) = svc == null
          ? ('', const <TimedWords>[])
          : await svc.stop();
      svc?.removeListener(_onTranscribe);
      if (token != _runToken) return;
      if (TranscriptAnalysis.tokenize(text).isEmpty && manualTally == 0) {
        if (_isStroke) {
          // not hearing words may itself be the sign: let a helper judge
          _enterHelperMode(
            'We did not catch any words. If the person could not speak, choose "Could not speak". You can also try again.',
          );
          return;
        }
        _retry(
          "We did not hear any words. Move the phone closer and try again.",
        );
        return;
      }
      _finishTask(
        MindTaskCapture(
          taskId: t.id,
          transcript: text,
          partials: partials,
          durationS: elapsedS,
          sttUsed: svc?.available ?? false,
          manualCount: manualTally,
          source: _isStroke
              ? ((svc?.simulated ?? true) ? 'simulated' : 'stt')
              : '',
        ),
      );
    } else {
      final svc = capture;
      final f = svc == null
          ? VoiceFeatures.extract(const [], SpeechCaptureService.sampleRate)
          : await svc.stop();
      svc?.removeListener(_onCapture);
      if (token != _runToken) return;
      if (!f.heardSpeech) {
        _retry(
          'We did not hear you. Speak a little louder, closer to the phone.',
        );
        return;
      }
      if (!f.qualityOk && f.clipPct > VoiceFeatures.maxClipPct) {
        _retry(
          'The recording was too loud (clipping). Hold the phone a little further away and try again.',
        );
        return;
      }
      _finishTask(
        MindTaskCapture(taskId: t.id, features: f, durationS: elapsedS),
      );
    }
  }

  void _retry(String message) {
    retryMessage = message;
    phase = MindPhase.between;
    coaching = message;
    notifyListeners();
    unawaited(onSpeak?.call(message, warning: true));
    if (autoRun) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 400), () {
        if (phase == MindPhase.between) retryTask();
      });
    }
  }

  // ---------------------------------------------------------------------
  // Face smile (MOV-06)
  // ---------------------------------------------------------------------

  /// Finding → rest (3 s) → smile (4 s). Samples come only from fresh
  /// landmark frames; on a device a step that saw nothing is repeated, then
  /// recorded as not assessed — never simulated.
  void _startFace(MindTask t, int token) {
    final simulatedFace =
        camera == null || autoRun || camera!.isSimulatedSensor;
    faceStage = simulatedFace ? FaceStage.rest : FaceStage.finding;
    _restSamples.clear();
    _smileSamples.clear();
    liveAsymmetry = null;
    faceSeen = false;
    elapsedS = 0;
    _stageStartS = 0;
    secondsLeft = (faceRestS + faceSmileS).round();
    coaching = simulatedFace
        ? 'Relax your face and look at the camera'
        : 'Look straight at the camera — face in the oval';
    notifyListeners();
    var ticks = 0;
    var smileCued = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (phase != MindPhase.running || token != _runToken) return;
      ticks++;
      elapsedS = ticks / 4;
      final g = camera?.freshFaceGeometry();
      if (g != null) faceSeen = true;
      switch (faceStage) {
        case FaceStage.finding:
          if (g != null) {
            faceStage = FaceStage.rest;
            _stageStartS = elapsedS;
            coaching = 'Good — relax your face and hold still';
          } else if (elapsedS >= faceFindTimeoutS) {
            _timer?.cancel();
            _completeFace(t);
            return;
          }
        case FaceStage.rest:
          if (g != null) _restSamples.add(g);
          if (elapsedS - _stageStartS >= faceRestS) {
            faceStage = FaceStage.smile;
            _stageStartS = elapsedS;
            coaching = 'Now SMILE as wide as you can!';
            if (!smileCued) {
              smileCued = true;
              unawaited(onSpeak?.call('Now smile big.'));
            }
          }
        case FaceStage.smile:
          final inStage = elapsedS - _stageStartS;
          if (g != null && inStage >= faceSmileWarmupS) {
            _smileSamples.add(g);
            if (_restSamples.isNotEmpty) {
              liveAsymmetry = FaceAsymmetry.computeFrames(
                rest: _restSamples,
                smile: _smileSamples,
              ).score;
            }
          }
          if (inStage >= faceSmileS) {
            _timer?.cancel();
            _completeFace(t);
            return;
          }
      }
      secondsLeft = faceStageLeftS.ceil();
      notifyListeners();
    });
  }

  void _completeFace(MindTask t) {
    final simulatedFace =
        camera == null || autoRun || camera!.isSimulatedSensor;
    if (simulatedFace) {
      final droop =
          demoOutcome == MindDemoOutcome.refer ||
          demoOutcome == MindDemoOutcome.crisis;
      _finishTask(
        MindTaskCapture(
          taskId: t.id,
          faceRest: MindSimulated.faceRest(droopLeft: droop),
          faceSmile: MindSimulated.faceSmile(droopLeft: droop),
          faceRestFrames: [MindSimulated.faceRest(droopLeft: droop)],
          faceSmileFrames: [MindSimulated.faceSmile(droopLeft: droop)],
          durationS: elapsedS,
          source: 'simulated',
        ),
      );
      return;
    }
    final rest = List<FaceGeometry>.from(_restSamples);
    final smile = List<FaceGeometry>.from(_smileSamples);
    final r = rest.isEmpty || smile.isEmpty
        ? null
        : FaceAsymmetry.computeFrames(rest: rest, smile: smile);
    final ok = r != null && r.smileDetected && rest.length >= 3;
    if (!ok) {
      faceAttempts++;
      final why = rest.isEmpty && smile.isEmpty
          ? (camera?.permissionDenied ?? false
                ? 'The camera is not allowed (G-11), so the face cannot be checked.'
                : 'The camera did not see your face.')
          : smile.isEmpty || r == null || !r.smileDetected
          ? 'We did not see your smile.'
          : 'We saw your face only for a moment.';
      if (faceAttempts >= faceMaxAttempts ||
          (camera?.permissionDenied ?? false)) {
        _finishTask(
          MindTaskCapture(
            taskId: t.id,
            skipped: true,
            skipReason: '$why Face step not assessed.',
            source: 'none',
          ),
        );
        return;
      }
      _retry(
        '$why Hold the phone at arm\'s length in good light, keep your face in the oval, and smile wide when asked. Or skip this step.',
      );
      return;
    }
    _finishTask(
      MindTaskCapture(
        taskId: t.id,
        faceRest: rest.first,
        faceSmile: smile.first,
        faceRestFrames: rest,
        faceSmileFrames: smile,
        durationS: elapsedS,
        source: 'camera',
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Arm drift (MOV-07 stand-in)
  // ---------------------------------------------------------------------

  Future<void> _startArm(MindTask t, int token) async {
    _motion.clear();
    _arrival.clear();
    _motionError = false;
    liveDropDeg = 0;
    elapsedS = 0;
    secondsLeft = t.seconds;
    coaching = 'Arm straight out… hold still';
    notifyListeners();
    final svc = MotionSensorService.instance;
    if (svc.simulated) {
      final drifts =
          demoOutcome == MindDemoOutcome.refer ||
          demoOutcome == MindDemoOutcome.crisis;
      svc.simulatedProfile = drifts
          ? SimulatedMotionProfile.armHoldDrift
          : SimulatedMotionProfile.armHoldSteady;
    }
    final old = _motionSub;
    _motionSub = null;
    await old?.cancel();
    if (token != _runToken || phase != MindPhase.running) return;
    _motionSub = svc
        .accelerometer(hz: 50)
        .listen(
          (s) {
            if (phase != MindPhase.running || token != _runToken) return;
            _motion.add(s);
            _arrival.add(elapsedS);
            motionActive = true;
          },
          onError: (Object _) {
            _motionError = true;
          },
          cancelOnError: true,
        );
    final total = armSettleS + armBaselineS + t.seconds;
    var ticks = 0;
    var started = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (phase != MindPhase.running || token != _runToken) return;
      ticks++;
      elapsedS = ticks / 4;
      if (_motionError) {
        _timer?.cancel();
        unawaited(_completeArm(t));
        return;
      }
      if (!started && elapsedS >= armSettleS) {
        started = true;
        coaching = 'Eyes closed — hold still for ${t.seconds} seconds';
        unawaited(onSpeak?.call('Hold… now. Eyes closed.'));
      }
      final holdLeft = armHoldLeftS;
      secondsLeft = holdLeft.ceil();
      if (started && _motion.length > 20) {
        final start = _window(armSettleS, armSettleS + armBaselineS);
        final now = _window(elapsedS - 1, elapsedS);
        if (start != null && now != null) {
          liveDropDeg = ArmDrift.pitchDropDegrees(start, now);
        }
      }
      if (ticks % 4 == 0 && secondsLeft > 0 && secondsLeft <= 3) {
        unawaited(onSpeak?.call('$secondsLeft'));
      }
      if (elapsedS >= total) {
        _timer?.cancel();
        unawaited(onSpeak?.call('Done — lower your arm and open your eyes.'));
        unawaited(_completeArm(t));
        return;
      }
      notifyListeners();
    });
  }

  /// Mean gravity vector of the samples that arrived in [from, to] s of
  /// the step clock; null when fewer than 3 did.
  List<double>? _window(double from, double to) {
    if (_motion.isEmpty) return null;
    final vs = [
      for (var i = 0; i < _motion.length; i++)
        if (_arrival[i] >= from && _arrival[i] <= to)
          [_motion[i].x, _motion[i].y, _motion[i].z],
    ];
    if (vs.length < 3) return null;
    return ArmDrift.meanVector(vs);
  }

  /// Mean of the first or last [n] samples (fallback when the stream
  /// started late or stopped early).
  List<double>? _edge({required bool first, int n = 25}) {
    if (_motion.length < 3) return null;
    final k = math.min(n, _motion.length);
    final slice = first
        ? _motion.sublist(0, k)
        : _motion.sublist(_motion.length - k);
    return ArmDrift.meanVector([
      for (final s in slice) [s.x, s.y, s.z],
    ]);
  }

  Future<void> _completeArm(MindTask t) async {
    // Do not await the cancel: some stream controllers never complete it
    // under the test clock, and the samples are already collected.
    unawaited(_motionSub?.cancel() ?? Future<void>.value());
    _motionSub = null;
    motionActive = false;
    final svc = MotionSensorService.instance;
    final total = armSettleS + armBaselineS + t.seconds;
    // Baseline: the second after the settle; end: the last second of the
    // hold. If the stream came up late or ran slow, fall back to the first
    // and last samples so a real hold is never thrown away.
    final start =
        _window(armSettleS, armSettleS + armBaselineS) ??
        _window(armSettleS, armSettleS + armBaselineS + 2) ??
        _edge(first: true);
    final end =
        _window(total - 1.0, total + 0.5) ??
        _window(total - 2.5, total + 0.5) ??
        _edge(first: false);
    if (_motionError || _motion.length < 10 || start == null || end == null) {
      if (_motionError || _motion.isEmpty) {
        _finishTask(
          MindTaskCapture(
            taskId: t.id,
            skipped: true,
            skipReason: 'Motion sensor gave no readings — step not assessed',
            source: 'none',
          ),
        );
        return;
      }
      _retry(
        'The motion sensor gave too few readings. Hold the phone flat and still, and try again.',
      );
      return;
    }
    _finishTask(
      MindTaskCapture(
        taskId: t.id,
        armStart: start,
        armEnd: end,
        durationS: elapsedS,
        source: svc.simulated ? 'simulated' : 'motion',
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Auto run (Test Controls / FLUTTER_TEST)
  // ---------------------------------------------------------------------

  void setAutoRun(bool on) {
    autoRun = on;
    if (on) {
      if (phase == MindPhase.between) {
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 300), () {
          if (phase == MindPhase.between) start();
        });
      } else if (phase == MindPhase.running &&
          currentTask.type == MindTaskType.questionnaire) {
        _autoQuestion(_runToken);
      } else if (phase == MindPhase.running && helperMode) {
        _enterHelperMode(helperPrompt);
      }
    }
    notifyListeners();
  }

  /// Seconds since the test began (for the Analyse header).
  int get runSeconds =>
      startedAt == null ? 0 : DateTime.now().difference(startedAt!).inSeconds;

  int nextInt(int max) => _rng.nextInt(max);
}
