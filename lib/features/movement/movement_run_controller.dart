// Phase machine for one movement test run (Doc 05 §H lifecycle:
// countdown → running ⇄ paused → per-side switch → processing).
//
// Widget-free so it can be unit-tested; the capture screen listens and
// renders. Sensors / hand tracking are injected as streams.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../../core/domain/algorithms/movement_engines.dart';
import '../../core/domain/algorithms/movement_session_builder.dart';
import '../../core/domain/entities/movement_protocol.dart';
import '../../core/services/hand_tracking_service.dart';
import '../../core/services/motion_sensor_service.dart';

enum RunPhase {
  idle,
  countdown,
  running,
  paused,
  sideSwitch,
  processing,
  done,
  aborted,
}

/// Live quality checks shown as chips under the visual.
class RunCheck {
  const RunCheck(this.label, this.pass, {this.detail});

  final String label;
  final bool? pass;
  final String? detail;
}

class MovementRunController extends ChangeNotifier {
  MovementRunController({
    required this.protocol,
    required this.sensors,
    this.handTracker,
    this.firstSide = MovementSide.right,
    this.maxRestarts = 3,
    this.onSpeak,
    this.onTick,
    this.onGo,
    this.onStop,
    this.onCount,
  }) {
    if (twoSided) currentSide = firstSide;
    // Hand guidance starts as soon as the camera is up (before Start), so
    // the hand can be placed in the outline first.
    final tracker = handTracker;
    if (protocol.kind == MovementTestKind.tappingVideo && tracker != null) {
      _handSub = tracker.frames.listen(_onHandFrame);
    }
  }

  final MovementProtocol protocol;
  final MotionSensorService sensors;
  final HandTrackingService? handTracker;
  final MovementSide firstSide;
  final int maxRestarts;

  /// Voice line callback (text, isWarning).
  final void Function(String text, {bool warning})? onSpeak;
  final VoidCallback? onTick;
  final VoidCallback? onGo;
  final VoidCallback? onStop;
  final void Function(int count)? onCount;

  RunPhase phase = RunPhase.idle;
  int countdownValue = 0;
  double elapsed = 0;
  MovementSide? currentSide;
  int sideIndex = 0;
  int restartsThisSide = 0;
  String coaching = '';
  String? lastWarning;

  /// Live numbers for the visual.
  int liveCount = 0;
  bool handInFrame = false;
  HandStatus handStatus = HandStatus.noHand;

  /// Where the whole hand must be (normalised image space); the capture
  /// screen sets it from the live viewport so check and drawing agree.
  Rect guideRect = HandGuide.fallbackRect;
  bool? lightOk;
  double _lastSeenAt = -1;
  double handVisibleFrames = 0;
  double totalFrames = 0;
  List<HandPoint>? landmarks;
  double? normDistance;
  bool walkingDetected = false;
  bool noiseFloorPhase = false;
  double tiltX = 0;
  double tiltY = 0;
  bool armSteady = true;
  double accelHz = 0;
  double gyroHz = 0;
  bool sensorDropout = false;

  final List<MovementSideCapture> captures = [];

  // per-side buffers
  final List<TapSample> _taps = [];
  final List<TouchTap> _touch = [];
  final List<MotionSample> _accel = [];
  final List<MotionSample> _gyro = [];
  double _lastStepT = -1;
  int _stepCount = 0;
  double _lastStsCheckT = 0;
  double _outOfFrameSince = -1;
  double _lastGrossCheckT = 0;
  bool _midSpoken = false;

  Timer? _ticker;
  Timer? _countdownTimer;
  StreamSubscription<MotionSample>? _accelSub;
  StreamSubscription<MotionSample>? _gyroSub;
  StreamSubscription<HandFrame>? _handSub;
  // Timing is driven by the 100 ms ticker (not a wall clock) so the run
  // behaves the same under fake-async widget tests; sample timestamps come
  // from the sensor / tracker streams themselves.
  double? _motionT0;
  double? _gyroT0;
  double? _handT0;
  int _wallStartMs = 0;
  MotionStreamStats _accelStats = MotionStreamStats();
  MotionStreamStats _gyroStats = MotionStreamStats();
  DateTime? _lastAccelAt;

  bool get twoSided => protocol.twoSided;
  int get secondsTarget => protocol.secondsPerSide;
  double get progress => (elapsed / secondsTarget).clamp(0.0, 1.0);
  int get remainingSeconds => math.max(0, secondsTarget - elapsed.floor());
  bool get isLastSide => !twoSided || sideIndex >= 1;
  MovementSide get _otherSide =>
      firstSide == MovementSide.right ? MovementSide.left : MovementSide.right;

  List<RunCheck> get checks => switch (protocol.kind) {
    MovementTestKind.tappingVideo => [
      RunCheck('Hand in frame', handInFrame),
      RunCheck(
        'Distance',
        handStatus == HandStatus.ok
            ? true
            : handStatus == HandStatus.noHand
            ? null
            : false,
        detail: switch (handStatus) {
          HandStatus.tooFar => 'too far',
          HandStatus.tooClose => 'too close',
          HandStatus.partlyOutside => 'partly outside',
          _ => null,
        },
      ),
      RunCheck('Light', lightOk),
      RunCheck(
        'Tracking',
        handTracker == null ? null : handTracker!.backend != 'proxy',
        detail: handTracker?.backend,
      ),
    ],
    MovementTestKind.tappingTouch => const [],
    MovementTestKind.gait => [
      RunCheck(
        'Sensor 50 Hz',
        _streaming ? accelHz >= 25 : null,
        detail: '${accelHz.toStringAsFixed(0)} Hz',
      ),
      RunCheck('Walking', _streaming ? walkingDetected : null),
      RunCheck('Signal', _streaming ? !sensorDropout : null),
    ],
    MovementTestKind.sitToStand => [
      RunCheck(
        'Sensor 50 Hz',
        _streaming ? accelHz >= 25 : null,
        detail: '${accelHz.toStringAsFixed(0)} Hz',
      ),
      RunCheck('Signal', _streaming ? !sensorDropout : null),
    ],
    MovementTestKind.tremor => [
      RunCheck(
        'Sensor 100 Hz',
        _streaming ? gyroHz >= 50 : null,
        detail: '${gyroHz.toStringAsFixed(0)} Hz',
      ),
      RunCheck('Arm steady', _streaming ? armSteady : null),
      RunCheck('Noise floor', _streaming ? !noiseFloorPhase : null),
    ],
  };

  /// The first failing live check, as a one-line fix in plain words (T-CAP
  /// coaching line), or null when everything passes.
  String? get problemLine {
    if (protocol.kind == MovementTestKind.tappingVideo) {
      // Hand guidance runs from the moment the camera is up, so the hand is
      // placed before Start is pressed.
      if (phase == RunPhase.sideSwitch ||
          phase == RunPhase.processing ||
          phase == RunPhase.done) {
        return null;
      }
      switch (handStatus) {
        case HandStatus.noHand:
          return handInFrame
              ? null
              : 'Show your whole hand, palm to the phone, inside the outline';
        case HandStatus.partlyOutside:
          return 'Keep the whole hand inside the outline';
        case HandStatus.tooFar:
          return 'Move your hand closer to the phone';
        case HandStatus.tooClose:
          return 'Move your hand a little further away';
        case HandStatus.ok:
          if (lightOk == false) return 'More light on your hand';
          return null;
      }
    }
    if (!_streaming) return null;
    switch (protocol.kind) {
      case MovementTestKind.tappingVideo:
        return null;
      case MovementTestKind.tappingTouch:
        return null;
      case MovementTestKind.gait:
        if (sensorDropout) {
          return 'Sensor signal lost — keep the phone in the pocket';
        }
        if (phase == RunPhase.running && elapsed > 4 && !walkingDetected) {
          return 'No steps heard yet — phone in the front pocket, then walk';
        }
        return null;
      case MovementTestKind.sitToStand:
        if (sensorDropout) {
          return 'Sensor signal lost — keep the phone in the pocket';
        }
        return null;
      case MovementTestKind.tremor:
        if (!armSteady) return 'Hold your arm steady';
        return null;
    }
  }

  bool get _streaming =>
      phase == RunPhase.running ||
      phase == RunPhase.paused ||
      phase == RunPhase.countdown;

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  /// Start the first (or next) side: countdown then recording.
  Future<void> start() async {
    if (phase == RunPhase.running || phase == RunPhase.countdown) return;
    currentSide = twoSided ? (sideIndex == 0 ? firstSide : _otherSide) : null;
    _resetSideBuffers();
    await _openSensors();
    _runCountdown();
  }

  /// Tremor: recording only starts once the arm has been steady — passing
  /// the phone to the other hand and raising the arm must never eat into
  /// the 20 s or trigger a restart (T-CAP "aligning" before "recording").
  bool get waitingForSteady =>
      phase == RunPhase.countdown &&
      countdownValue <= 0 &&
      protocol.kind == MovementTestKind.tremor;

  void _runCountdown() {
    phase = RunPhase.countdown;
    countdownValue = protocol.countdownSeconds;
    _steadyChecks = 0;
    coaching = protocol.kind == MovementTestKind.gait
        ? 'Pocket the phone. Walking starts in $countdownValue…'
        : 'Get ready… $countdownValue';
    onTick?.call();
    notifyListeners();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 1000), (t) {
      if (countdownValue > 0) countdownValue--;
      if (countdownValue <= 0) {
        if (protocol.kind == MovementTestKind.tremor &&
            sensorsLive &&
            _steadyChecks < 1) {
          // Hold until the last two steadiness checks passed.
          coaching = 'Hold your arm steady — starting as soon as it is still';
          if (!_holdSpoken) {
            _holdSpoken = true;
            onSpeak?.call('Hold your arm steady. Starting when it is still.');
          }
          notifyListeners();
          return;
        }
        t.cancel();
        _holdSpoken = false;
        _beginRecording();
      } else {
        coaching = protocol.kind == MovementTestKind.gait
            ? 'Pocket the phone. Walking starts in $countdownValue…'
            : 'Get ready… $countdownValue';
        onTick?.call();
        notifyListeners();
      }
    });
  }

  bool _holdSpoken = false;

  /// Consecutive steady 0.25 s windows (tremor), from the live gyro.
  int _steadyChecks = 0;
  int _unsteadyChecks = 0;

  /// Any gyro samples seen since the sensors were opened (false on a
  /// device that never delivers, so the countdown is not held forever).
  bool get sensorsLive => _gyroStats.samples > 0;

  void _beginRecording() {
    phase = RunPhase.running;
    elapsed = 0;
    _midSpoken = false;
    _motionT0 = null;
    _gyroT0 = null;
    _handT0 = null;
    _wallStartMs = DateTime.now().millisecondsSinceEpoch;
    noiseFloorPhase = protocol.kind == MovementTestKind.tremor;
    coaching = protocol.voiceGo;
    onGo?.call();
    onSpeak?.call(protocol.voiceGo);
    notifyListeners();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    if (phase != RunPhase.running) return;
    final before = elapsed.floor();
    elapsed += 0.1;
    // Spec §9 intro: tests are paced by voice + metronome. A soft tick on
    // every whole second while recording.
    if (protocol.pacing == MovementPacing.metronome &&
        elapsed.floor() > before) {
      onTick?.call();
    }
    if (noiseFloorPhase && elapsed >= 2) noiseFloorPhase = false;
    if (!_midSpoken &&
        elapsed >= secondsTarget / 2 &&
        protocol.kind != MovementTestKind.gait) {
      _midSpoken = true;
      onSpeak?.call(protocol.voiceMid);
    }
    // Hand-out-of-frame rule (MOV-01): > 1 s → restart this hand.
    if (protocol.kind == MovementTestKind.tappingVideo &&
        !handInFrame &&
        _outOfFrameSince >= 0 &&
        elapsed - _outOfFrameSince > 1.0) {
      _restartSide('Hand left the frame — restarting this hand');
      return;
    }
    // Gait auto-stop: ≥ 8 steps and 2.5 s without a step, or max seconds.
    if (protocol.kind == MovementTestKind.gait) {
      final maxS = protocol.maxSeconds ?? 60;
      if ((_stepCount >= 8 && _lastStepT >= 0 && elapsed - _lastStepT > 2.5) ||
          elapsed >= maxS) {
        _finishSide();
        return;
      }
      coaching = _stepCount == 0
          ? 'Listening for steps…'
          : 'Walking · $_stepCount steps';
      notifyListeners();
      return;
    }
    if (elapsed >= secondsTarget) {
      _finishSide();
      return;
    }
    coaching = _liveCoaching();
    notifyListeners();
  }

  String _liveCoaching() => switch (protocol.kind) {
    MovementTestKind.tappingVideo =>
      !handInFrame
          ? 'Show the whole hand in the outline'
          : 'Open wide, close fast · $liveCount taps',
    MovementTestKind.tappingTouch => 'Tap the two circles in turn · $liveCount',
    MovementTestKind.sitToStand => 'Stand up fully, sit back down · $liveCount',
    MovementTestKind.tremor =>
      noiseFloorPhase
          ? 'Measuring noise floor… hold still'
          : armSteady
          ? 'Hold still… ${remainingSeconds}s'
          : 'Hold your arm steady',
    MovementTestKind.gait => 'Walking',
  };

  void pause() {
    if (phase != RunPhase.running) return;
    phase = RunPhase.paused;
    coaching = 'Paused';
    notifyListeners();
  }

  void resume() {
    if (phase != RunPhase.paused) return;
    phase = RunPhase.running;
    notifyListeners();
  }

  /// Manual stop (gait "Stop" button) finishes the side early.
  void stopEarly() {
    if (phase == RunPhase.running || phase == RunPhase.paused) _finishSide();
  }

  void _restartSide(String reason) {
    restartsThisSide++;
    lastWarning = reason;
    onSpeak?.call(reason, warning: true);
    if (restartsThisSide > maxRestarts) {
      // G-25: give up on this side.
      _ticker?.cancel();
      captures.add(
        MovementSideCapture(
          side: currentSide,
          skipped: true,
          restarts: restartsThisSide,
          skipReason: protocol.kind == MovementTestKind.tremor
              ? 'Not assessed — the arm kept moving ($maxRestarts restarts)'
              : protocol.kind == MovementTestKind.tappingVideo
              ? 'Not assessed — the hand kept leaving the frame ($maxRestarts restarts)'
              : 'Not assessed after $maxRestarts restarts',
        ),
      );
      _afterSide();
      return;
    }
    _ticker?.cancel();
    _resetSideBuffers(keepRestarts: true);
    _runCountdown();
  }

  void _finishSide() {
    _ticker?.cancel();
    if (protocol.kind == MovementTestKind.tappingVideo && _liveTaps.flush()) {
      liveCount = _liveTaps.count;
    }
    onStop?.call();
    onSpeak?.call(protocol.voiceStop);
    captures.add(
      MovementSideCapture(
        side: currentSide,
        restarts: restartsThisSide,
        tapSamples: List<TapSample>.from(_taps),
        touchTaps: List<TouchTap>.from(_touch),
        motion: List<MotionSample>.from(
          protocol.kind == MovementTestKind.tremor ? _gyro : _accel,
        ),
        handVisiblePct: totalFrames > 0
            ? handVisibleFrames / totalFrames * 100
            : null,
        fps: _taps.length > 1 && (_taps.last.t - _taps.first.t) > 0
            ? (_taps.length - 1) / (_taps.last.t - _taps.first.t)
            : null,
      ),
    );
    _afterSide();
  }

  void _afterSide() {
    _closeSensors();
    if (twoSided && sideIndex == 0) {
      sideIndex = 1;
      currentSide = _otherSide;
      phase = RunPhase.sideSwitch;
      coaching =
          'Switch hands — now the ${_otherSide.label.toLowerCase()} hand';
      onSpeak?.call(
        'Switch hands. Now the ${_otherSide.label.toLowerCase()} hand.',
      );
      notifyListeners();
      return;
    }
    phase = RunPhase.processing;
    coaching = 'Analysing…';
    notifyListeners();
  }

  /// "Skip this hand" from the side-switch card or during the first side.
  void skipSide() {
    if (phase == RunPhase.done || phase == RunPhase.processing) return;
    _ticker?.cancel();
    _countdownTimer?.cancel();
    captures.add(
      MovementSideCapture(
        side: twoSided ? (sideIndex == 0 ? firstSide : _otherSide) : null,
        skipped: true,
        restarts: restartsThisSide,
      ),
    );
    if (phase == RunPhase.sideSwitch) {
      phase = RunPhase.processing;
      coaching = 'Analysing…';
      _closeSensors();
      notifyListeners();
      return;
    }
    _afterSide();
  }

  void abort() {
    _ticker?.cancel();
    _countdownTimer?.cancel();
    _closeSensors();
    phase = RunPhase.aborted;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _countdownTimer?.cancel();
    _closeSensors();
    _handSub?.cancel();
    _handSub = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Inputs
  // ---------------------------------------------------------------------

  /// Touch target tapped (0 = A, 1 = B). Counted only while running.
  void onTouchTarget(int target) {
    if (phase != RunPhase.running) return;
    final t = DateTime.now().millisecondsSinceEpoch - _wallStartMs;
    final counted = _touch.isEmpty || _touch.last.target != target;
    _touch.add(TouchTap(t, target));
    if (counted) {
      liveCount++;
      notifyListeners();
    }
  }

  void _onHandFrame(HandFrame f) {
    totalFrames++;
    final status = HandGuide.statusFor(f, guideRect);
    handStatus = status;
    lightOk = f.lightOk;
    // Keep the last skeleton through a single missed detection so the
    // overlay does not blink; it clears once the grace below expires.
    if (f.landmarks != null || f.t - _lastSeenAt > 0.25) {
      landmarks = f.landmarks;
    }
    normDistance = f.normDistance;
    // CAP-09 "hand in frame": detected and (nearly) whole inside the guide.
    // Too far / too close still counts as in frame — it is coached, not
    // restarted.
    final inFrame =
        status == HandStatus.ok ||
        status == HandStatus.tooFar ||
        status == HandStatus.tooClose;
    if (inFrame) {
      _lastSeenAt = f.t;
      handInFrame = true;
      handVisibleFrames++;
      _outOfFrameSince = -1;
    } else {
      // Short grace so a single missed detection does not flicker the UI;
      // the > 1 s restart rule still runs off [_outOfFrameSince].
      if (handInFrame && f.t - _lastSeenAt > 0.25) handInFrame = false;
      if (_outOfFrameSince < 0) _outOfFrameSince = elapsed;
    }
    // Record every frame in which a hand is seen — a big tap can carry the
    // fingertips past the guide for a moment, and those are exactly the
    // samples that must not be lost. The guide drives coaching only.
    if (phase == RunPhase.running && f.handInFrame && f.normDistance != null) {
      _handT0 ??= f.t;
      final t = f.t - _handT0!;
      _taps.add(TapSample(t, f.normDistance!));
      if (_liveTaps.add(_taps.length - 1, t, f.normDistance!)) {
        liveCount = _liveTaps.count;
        onCount?.call(liveCount);
      }
    }
    if (phase != RunPhase.processing && phase != RunPhase.done) {
      notifyListeners();
    }
  }

  /// Live tap counter — the same reversal detector the final analysis
  /// uses, fed frame by frame. Reset per side.
  TapReversalCounter _liveTaps = TapReversalCounter();

  /// Operator diagnostics for the Test Controls panel: recorded sample
  /// rate, current tap threshold and last tap amplitude.
  String get tapDiagnostics {
    if (_taps.length < 2) return 'tracking: waiting for samples';
    final span = _taps.last.t - _taps.first.t;
    final fps = span > 0 ? (_taps.length - 1) / span : 0.0;
    return '${fps.toStringAsFixed(0)} samples/s · gap ${(_taps.last.t - _taps[_taps.length - 2].t) * 1000 ~/ 1} ms · '
        'thr ${_liveTaps.threshold.toStringAsFixed(2)} · last tap ${_liveTaps.lastAmplitude.toStringAsFixed(2)} · '
        'dist ${(normDistance ?? 0).toStringAsFixed(2)}';
  }

  void _onAccel(MotionSample s) {
    final now = DateTime.now();
    if (_lastAccelAt != null &&
        now.difference(_lastAccelAt!).inMilliseconds > 500) {
      sensorDropout = true;
    }
    _lastAccelAt = now;
    _accelStats.add(s.t);
    accelHz = _accelStats.achievedHz;
    if (protocol.kind == MovementTestKind.tremor) {
      // tilt for the bubble level (gravity components)
      final g = s.magnitude == 0 ? 9.81 : s.magnitude;
      tiltX = (s.x / g).clamp(-1.0, 1.0);
      tiltY = (s.y / g).clamp(-1.0, 1.0);
      return;
    }
    if (phase != RunPhase.running) return;
    _motionT0 ??= s.t;
    _accel.add(MotionSample(s.t - _motionT0!, s.x, s.y, s.z));
    _liveMotionUpdate();
  }

  /// Rough live step / stand counting on the recent window (the final
  /// numbers come from the analyzers).
  void _liveMotionUpdate() {
    final t = _accel.last.t;
    if (protocol.kind == MovementTestKind.gait) {
      if (_accel.length < 25) return;
      final recent = _accel.sublist(_accel.length - 25);
      final mags = recent.map((e) => e.magnitude).toList();
      final m = Dsp.mean(mags);
      final last = mags[mags.length - 2];
      final isPeak =
          last > mags[mags.length - 3] && last >= mags.last && last - m > 1.0;
      if (isPeak && t - _lastStepT > 0.3) {
        _lastStepT = t;
        _stepCount++;
        liveCount = _stepCount;
        walkingDetected = _stepCount >= 3;
        notifyListeners();
      }
    } else if (protocol.kind == MovementTestKind.sitToStand) {
      if (t - _lastStsCheckT < 0.25 || _accel.length < 60) return;
      _lastStsCheckT = t;
      final m = StsCycleCounter.analyze(_accel);
      if (m.count != liveCount) {
        liveCount = m.count;
        onCount?.call(liveCount);
        notifyListeners();
      }
    }
  }

  // Rolling 1 s of |ω| for the steadiness check, kept in every phase so the
  // countdown can wait for a still arm and the overlay bubble is live.
  final List<MotionSample> _recentGyro = [];
  int _sinceSteadyCheck = 0;

  void _onGyro(MotionSample s) {
    _gyroStats.add(s.t);
    gyroHz = _gyroStats.achievedHz;
    if (protocol.kind == MovementTestKind.tremor) {
      _recentGyro.add(s);
      if (_recentGyro.length > 100) _recentGyro.removeAt(0);
      if (++_sinceSteadyCheck >= 25 && _recentGyro.length >= 50) {
        _sinceSteadyCheck = 0;
        _updateSteadiness();
      }
    }
    if (phase != RunPhase.running) return;
    _gyroT0 ??= s.t;
    final t = s.t - _gyroT0!;
    _gyro.add(MotionSample(t, s.x, s.y, s.z));
  }

  /// Spec §9 MOV-05: voluntary gross arm movement (< 2 Hz, high amplitude)
  /// → "Hold arm steady" and restart. Evaluated on the slow (< 2 Hz)
  /// component of |ω| over the last second; a restart needs the movement to
  /// persist for two consecutive checks, so one jolt only warns.
  void _updateSteadiness() {
    // Per-axis low-pass (< 2 Hz, DC kept) then vector RMS: a tremor at
    // 4–12 Hz is removed, a slow swing or a sustained turn of the arm is
    // not. (The rectified |ω| would double a tremor's frequency and hide a
    // steady rotation behind its own mean.)
    final g = _recentGyro;
    double axisRms(double Function(MotionSample) pick) =>
        Dsp.rms(Dsp.lowPass(g.map(pick).toList(), 100, 2.0));
    final rx = axisRms((m) => m.x);
    final ry = axisRms((m) => m.y);
    final rz = axisRms((m) => m.z);
    final slowRms = math.sqrt(rx * rx + ry * ry + rz * rz);
    final steadyNow = slowRms <= 40;
    if (steadyNow) {
      _steadyChecks++;
      _unsteadyChecks = 0;
    } else {
      _steadyChecks = 0;
      _unsteadyChecks++;
    }
    final wasSteady = armSteady;
    // Steady needs two calm windows; unsteady shows after one so the
    // coaching line reacts at once.
    armSteady = steadyNow ? _steadyChecks >= 2 || wasSteady : false;
    if (phase == RunPhase.running &&
        !noiseFloorPhase &&
        _unsteadyChecks >= 2 &&
        elapsed - _lastGrossCheckT >= 1.0) {
      _lastGrossCheckT = elapsed;
      _restartSide(
        'Big arm movement — hold still. Restarting this hand '
        '(${restartsThisSide + 1} of $maxRestarts)',
      );
      return;
    }
    if (wasSteady != armSteady && phase != RunPhase.processing) {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Sensor plumbing
  // ---------------------------------------------------------------------

  Future<void> _openSensors() async {
    _closeSensors();
    _recentGyro.clear();
    _sinceSteadyCheck = 0;
    _steadyChecks = 0;
    _unsteadyChecks = 0;
    _accelStats = MotionStreamStats();
    _gyroStats = MotionStreamStats();
    _lastAccelAt = null;
    if (protocol.sensors.contains(MovementSensor.accelerometer)) {
      _accelSub = sensors
          .accelerometer(hz: 50)
          .listen(_onAccel, onError: (_) {});
    }
    if (protocol.sensors.contains(MovementSensor.gyroscope)) {
      _gyroSub = sensors.gyroscope(hz: 100).listen(_onGyro, onError: (_) {});
    }
    final tracker = handTracker;
    if (protocol.kind == MovementTestKind.tappingVideo && tracker != null) {
      _handSub ??= tracker.frames.listen(_onHandFrame);
    }
  }

  void _closeSensors() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
  }

  void _resetSideBuffers({bool keepRestarts = false}) {
    _taps.clear();
    _liveTaps = TapReversalCounter();
    _touch.clear();
    _accel.clear();
    _gyro.clear();
    _lastStepT = -1;
    _stepCount = 0;
    _lastStsCheckT = 0;
    _outOfFrameSince = -1;
    _lastGrossCheckT = -10;
    liveCount = 0;
    walkingDetected = false;
    sensorDropout = false;
    armSteady = true;
    elapsed = 0;
    if (!keepRestarts) restartsThisSide = 0;
  }
}
