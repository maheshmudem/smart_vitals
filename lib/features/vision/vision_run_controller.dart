// State machine for the four vision tests (T-CAP lifecycle: idle → running
// ⇄ paused (distance) → switch (other eye / other block) → processing).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/domain/algorithms/vision_engines.dart';
import '../../core/domain/algorithms/vision_session_builder.dart';
import '../../core/domain/entities/vision_protocol.dart';
import '../../core/services/face_distance_service.dart';

enum VisionPhase {
  idle,
  running,
  pausedDistance,
  switchPart,
  processing,
  done,
  aborted,
}

/// Reaction-time trial state.
enum StimulusState { idle, waiting, shown, feedback }

class VisionRunController extends ChangeNotifier {
  VisionRunController({
    required this.protocol,
    this.distance,
    this.onSpeak,
    this.onBeep,
    this.demoOutcome = VisionDemoOutcome.normal,
    int seed = 11,
  }) : _rng = math.Random(seed) {
    distance?.addListener(_onDistance);
    if (protocol.kind == VisionTestKind.colour) {
      plateSet = ColourPlateSet.generate(seed: seed);
    }
    if (protocol.perEye) currentEye = VisionEye.right;
    if (protocol.kind == VisionTestKind.reaction) {
      currentBlock = ReactionBlock.visual;
    }
  }

  final VisionProtocol protocol;
  final FaceDistanceService? distance;

  /// Speaks a line; completes when the voice has finished (timed blocks
  /// wait for it).
  final Future<void> Function(String text, {bool warning})? onSpeak;
  int _runToken = 0;
  final VoidCallback? onBeep;
  final math.Random _rng;
  VisionDemoOutcome demoOutcome;

  VisionPhase phase = VisionPhase.idle;
  VisionEye? currentEye;
  ReactionBlock? currentBlock;
  final List<VisionPartCapture> captures = [];
  String coaching = '';
  DateTime? startedAt;

  // --- acuity -------------------------------------------------------------
  TumblingEStaircase? staircase;
  DistanceReading distanceReading = const DistanceReading(
    cm: null,
    mode: DistanceMode.manual,
    reliable: false,
  );
  DateTime? _outOfRangeSince;
  bool get distancePaused => phase == VisionPhase.pausedDistance;
  EDirection? get currentDirection =>
      phase == VisionPhase.running || phase == VisionPhase.pausedDistance
      ? staircase?.next()
      : null;
  String get distanceLine {
    final d = distanceReading;
    if (d.mode == DistanceMode.manual || d.cm == null) return 'Hold at 40 cm';
    if (!d.reliable) return 'Finding your face…';
    final cm = d.cm!.round();
    if (d.tooClose) return '$cm cm — move further away';
    if (d.tooFar) return '$cm cm — move closer';
    return '$cm cm';
  }

  // --- colour -------------------------------------------------------------
  late final ColourPlateSet plateSet;
  int plateIndex = 0;
  final List<ColourPlateAnswer> plateAnswers = [];
  ColourPlate? get currentPlate =>
      protocol.kind == VisionTestKind.colour &&
          plateIndex < plateSet.plates.length
      ? plateSet.plates[plateIndex]
      : null;

  // --- amsler -------------------------------------------------------------
  AmslerMarks marks = AmslerMarks();

  // --- reaction -----------------------------------------------------------
  StimulusState stimulus = StimulusState.idle;
  final List<ReactionTrial> _trials = [];
  int validInBlock = 0;
  int falseStartsInBlock = 0;
  int falseStartsTotal = 0;
  double? lastLatencyMs;
  Timer? _stimTimer;
  DateTime? _onsetAt;
  double _pendingGap = 0;
  List<ReactionTrial> get trials => List.unmodifiable(_trials);

  // --- auto observer (Test Controls / FLUTTER_TEST) ------------------------
  bool autoRun = false;
  Timer? _autoTimer;

  int get partIndex => captures.length;
  int get partCount => protocol.perEye
      ? 2
      : protocol.kind == VisionTestKind.reaction
      ? 2
      : 1;
  String get partLabel => switch (protocol.kind) {
    VisionTestKind.acuity || VisionTestKind.amsler =>
      '${currentEye?.label ?? ''} eye · ${partIndex + 1} of 2',
    VisionTestKind.reaction =>
      '${currentBlock?.label ?? ''} · ${partIndex + 1} of 2',
    VisionTestKind.colour =>
      'Plate ${math.min(plateIndex + 1, plateSet.plates.length)} of ${plateSet.plates.length}',
  };

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  void start() {
    if (phase == VisionPhase.running) return;
    startedAt ??= DateTime.now();
    phase = VisionPhase.running;
    switch (protocol.kind) {
      case VisionTestKind.acuity:
        staircase = TumblingEStaircase(seed: _rng.nextInt(1 << 20));
        coaching = 'Swipe the way the E points';
        onSpeak?.call(
          partIndex == 0 ? protocol.voiceStart : protocol.voiceSwitch,
        );
      case VisionTestKind.colour:
        coaching = 'Tap the number you see';
        _armPlate();
        onSpeak?.call(protocol.voiceStart);
      case VisionTestKind.amsler:
        marks = AmslerMarks();
        coaching = 'Look only at the dot';
        onSpeak?.call(
          partIndex == 0 ? protocol.voiceStart : protocol.voiceSwitch,
        );
      case VisionTestKind.reaction:
        validInBlock = 0;
        falseStartsInBlock = 0;
        final token = ++_runToken;
        coaching = 'Listen to the instruction…';
        unawaited(() async {
          try {
            await (onSpeak?.call(
                  partIndex == 0 ? protocol.voiceStart : protocol.voiceSwitch,
                ) ??
                Future<void>.value());
          } catch (_) {}
          if (token != _runToken || phase != VisionPhase.running) return;
          _scheduleStimulus();
        }());
    }
    notifyListeners();
    _startAuto();
  }

  void abort() {
    _runToken++;
    _stimTimer?.cancel();
    _autoTimer?.cancel();
    _plateHintTimer?.cancel();
    phase = VisionPhase.aborted;
    notifyListeners();
  }

  @override
  void dispose() {
    _stimTimer?.cancel();
    _autoTimer?.cancel();
    _plateHintTimer?.cancel();
    distance?.removeListener(_onDistance);
    super.dispose();
  }

  void _finishPart(VisionPartCapture capture) {
    _stimTimer?.cancel();
    _autoTimer?.cancel();
    captures.add(capture);
    if (captures.length < partCount) {
      if (protocol.perEye) currentEye = currentEye!.other;
      if (protocol.kind == VisionTestKind.reaction) {
        currentBlock = ReactionBlock.audio;
      }
      phase = VisionPhase.switchPart;
      coaching = protocol.perEye
          ? 'Now cover your ${currentEye!.coveredLabel} eye'
          : 'Now the sound block';
      stimulus = StimulusState.idle;
      notifyListeners();
      return;
    }
    phase = VisionPhase.processing;
    coaching = 'Analysing…';
    onSpeak?.call(protocol.voiceDone);
    notifyListeners();
  }

  /// Skip the current eye / block.
  void skipPart() {
    if (phase == VisionPhase.processing || phase == VisionPhase.done) return;
    _finishPart(
      VisionPartCapture(
        eye: protocol.perEye ? currentEye : null,
        block: protocol.kind == VisionTestKind.reaction ? currentBlock : null,
        skipped: true,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Acuity
  // ---------------------------------------------------------------------

  void _onDistance() {
    final d = distance;
    if (d == null) return;
    if (phase == VisionPhase.processing ||
        phase == VisionPhase.done ||
        phase == VisionPhase.aborted) {
      return;
    }
    distanceReading = d.reading;
    if (protocol.kind != VisionTestKind.acuity) return;
    final measured =
        distanceReading.mode != DistanceMode.manual && distanceReading.reliable;
    final out = measured && !distanceReading.inRange;
    final now = DateTime.now();
    if (out) {
      _outOfRangeSince ??= now;
      // E-CAP-015 / G-33: outside 35–45 cm for > 0.5 s → pause the optotype.
      if (phase == VisionPhase.running &&
          now.difference(_outOfRangeSince!).inMilliseconds > 500) {
        phase = VisionPhase.pausedDistance;
        coaching = distanceReading.tooClose
            ? 'Move further away'
            : 'Move closer';
        onSpeak?.call(
          'Hold the phone at 40 centimetres. ${distanceReading.tooClose ? 'Move further away.' : 'Move closer.'}',
          warning: true,
        );
      }
    } else {
      _outOfRangeSince = null;
      if (phase == VisionPhase.pausedDistance) {
        phase = VisionPhase.running;
        coaching = 'Swipe the way the E points';
      }
    }
    notifyListeners();
  }

  /// Member's answer for the current E (null = "Not sure").
  void answerAcuity(EDirection? dir) {
    if (phase != VisionPhase.running || staircase == null) return;
    final d = distanceReading;
    staircase!.answer(
      dir,
      distanceCm: d.cm ?? FaceDistance.targetCm,
      inRange: d.mode == DistanceMode.manual ? true : d.inRange,
    );
    if (staircase!.done) {
      _finishPart(
        VisionPartCapture(
          eye: currentEye,
          acuityTrials: List.unmodifiable(staircase!.trials),
          thresholdLogMar: staircase!.thresholdLogMar,
        ),
      );
      return;
    }
    coaching =
        'Level ${staircase!.level.toStringAsFixed(1)} · '
        '${staircase!.trials.length} of ~${staircase!.estimatedTotal}';
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Colour plates
  // ---------------------------------------------------------------------

  /// Wall-clock moment the current plate appeared (response time).
  DateTime? _plateShownAt;
  Timer? _plateHintTimer;

  /// True after 8 s on one plate: the view nudges "I see nothing".
  bool plateHintDue = false;

  void _armPlate() {
    _plateShownAt = DateTime.now();
    plateHintDue = false;
    _plateHintTimer?.cancel();
    _plateHintTimer = Timer(const Duration(seconds: 8), () {
      if (phase != VisionPhase.running) return;
      plateHintDue = true;
      notifyListeners();
    });
  }

  void answerPlate(int? digit) {
    if (phase != VisionPhase.running) return;
    final p = currentPlate;
    if (p == null) return;
    final shownAt = _plateShownAt;
    plateAnswers.add(
      ColourPlateAnswer(
        plateIndex: p.index,
        answered: digit,
        responseMs: shownAt == null
            ? null
            : DateTime.now().difference(shownAt).inMilliseconds.toDouble(),
      ),
    );
    plateIndex++;
    _plateHintTimer?.cancel();
    plateHintDue = false;
    if (plateIndex >= plateSet.plates.length) {
      _finishPart(
        VisionPartCapture(
          plateSet: plateSet,
          plateAnswers: List.unmodifiable(plateAnswers),
        ),
      );
      return;
    }
    _armPlate();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Amsler
  // ---------------------------------------------------------------------

  void markCell(int cell, {bool on = true}) {
    if (phase != VisionPhase.running) return;
    if (on) {
      marks.marked.add(cell);
    } else {
      marks.marked.remove(cell);
    }
    notifyListeners();
  }

  void clearMarks() {
    marks.marked.clear();
    notifyListeners();
  }

  void amslerDone({bool declaredNormal = false}) {
    if (phase != VisionPhase.running) return;
    final m = AmslerMarks(
      marked: declaredNormal ? <int>{} : Set<int>.from(marks.marked),
      declaredNormal: declaredNormal,
    );
    _finishPart(VisionPartCapture(eye: currentEye, amsler: m));
  }

  // ---------------------------------------------------------------------
  // Reaction time
  // ---------------------------------------------------------------------

  void _scheduleStimulus() {
    _stimTimer?.cancel();
    stimulus = StimulusState.waiting;
    coaching = 'Wait…';
    _pendingGap = ReactionTimeAnalyzer.randomGapS(_rng);
    _onsetAt = null;
    notifyListeners();
    _stimTimer = Timer(
      Duration(milliseconds: (_pendingGap * 1000).round()),
      () {
        if (phase != VisionPhase.running) return;
        stimulus = StimulusState.shown;
        if (currentBlock == ReactionBlock.audio) {
          _onsetAt = DateTime.now();
          onBeep?.call();
          coaching = 'Tap!';
        } else {
          coaching = 'Tap!';
        }
        notifyListeners();
        // Missed stimulus: no tap within 2 s → count as a slow trial of 2000 ms
        // and move on (keeps the test finite).
        _stimTimer = Timer(const Duration(seconds: 2), () {
          if (stimulus == StimulusState.shown) {
            _recordTrial(2000, falseStart: false);
          }
        });
      },
    );
  }

  /// The visual stimulus has been painted (post-frame).
  void markOnset() {
    if (stimulus == StimulusState.shown && _onsetAt == null) {
      _onsetAt = DateTime.now();
    }
  }

  void onReactionTap() {
    if (phase != VisionPhase.running) return;
    switch (stimulus) {
      case StimulusState.waiting:
        // Anticipation: tap before the stimulus (Spec §9: discard, replace).
        _recordTrial(-1, falseStart: true);
      case StimulusState.shown:
        final onset = _onsetAt ?? DateTime.now();
        final ms = DateTime.now().difference(onset).inMicroseconds / 1000;
        _recordTrial(ms, falseStart: ms < ReactionTimeAnalyzer.minValidMs);
      case StimulusState.idle:
      case StimulusState.feedback:
        return;
    }
  }

  void _recordTrial(double ms, {required bool falseStart}) {
    _stimTimer?.cancel();
    _trials.add(
      ReactionTrial(
        block: currentBlock!,
        gapS: _pendingGap,
        latencyMs: ms,
        falseStart: falseStart,
      ),
    );
    if (falseStart) {
      falseStartsInBlock++;
      falseStartsTotal++;
      lastLatencyMs = null;
      coaching =
          falseStartsInBlock > ReactionTimeAnalyzer.maxFalseStartsBeforeReminder
          ? 'Too early again — wait for the signal, then tap'
          : 'Too early — wait for the signal';
      if (falseStartsInBlock ==
          ReactionTimeAnalyzer.maxFalseStartsBeforeReminder + 1) {
        onSpeak?.call('Wait for the signal before you tap.', warning: true);
      }
    } else {
      validInBlock++;
      lastLatencyMs = ms;
      coaching = '${ms.round()} ms';
    }
    stimulus = StimulusState.feedback;
    notifyListeners();
    if (validInBlock >= ReactionTimeAnalyzer.trialsPerBlock) {
      final block = currentBlock!;
      _stimTimer = Timer(const Duration(milliseconds: 700), () {
        _finishPart(
          VisionPartCapture(
            block: block,
            reactionTrials: List.unmodifiable(
              _trials.where((t) => t.block == block).toList(),
            ),
          ),
        );
      });
      return;
    }
    _stimTimer = Timer(const Duration(milliseconds: 700), _scheduleStimulus);
  }

  // ---------------------------------------------------------------------
  // Auto observer (Test Controls / FLUTTER_TEST)
  // ---------------------------------------------------------------------

  double get _trueLogMar => switch (demoOutcome) {
    VisionDemoOutcome.normal => 0.0,
    VisionDemoOutcome.borderline => 0.3,
    VisionDemoOutcome.refer => 0.7,
  };

  void setAutoRun(bool on) {
    autoRun = on;
    if (on) {
      _startAuto();
    } else {
      _autoTimer?.cancel();
    }
    notifyListeners();
  }

  void _startAuto() {
    if (!autoRun) return;
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (phase != VisionPhase.running) return;
      switch (protocol.kind) {
        case VisionTestKind.acuity:
          final shown = staircase?.next();
          if (shown == null) return;
          answerAcuity(
            VisionSimulated.acuityAnswer(
              shown,
              staircase!.level,
              _trueLogMar,
              _rng,
            ),
          );
        case VisionTestKind.colour:
          final p = currentPlate;
          if (p == null) return;
          final deficient = demoOutcome == VisionDemoOutcome.refer;
          final borderline = demoOutcome == VisionDemoOutcome.borderline;
          int? a = p.digit;
          if (!p.isControl && deficient) a = null;
          if (!p.isControl && borderline && p.index == 3) a = null;
          answerPlate(a);
        case VisionTestKind.amsler:
          if (demoOutcome == VisionDemoOutcome.refer &&
              currentEye == VisionEye.left) {
            for (final c in [190, 191, 210, 211, 230]) {
              marks.marked.add(c);
            }
            amslerDone();
          } else {
            amslerDone(declaredNormal: true);
          }
        case VisionTestKind.reaction:
          if (stimulus == StimulusState.shown) {
            // Simulated observer: a fixed 240 ms latency regardless of when
            // the frame that painted the flash ran.
            _onsetAt = DateTime.now().subtract(
              const Duration(milliseconds: 240),
            );
            onReactionTap();
          }
      }
    });
  }
}
