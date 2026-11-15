import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/movement_session_builder.dart';
import '../../core/domain/entities/movement_protocol.dart';
import '../../core/services/hand_tracking_service.dart';
import '../../core/services/live_camera_service.dart';
import '../../core/services/motion_sensor_service.dart';
import '../../core/services/pacing_audio_service.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'movement_illustrations.dart';
import 'movement_result_screen.dart';
import 'movement_run_controller.dart';

/// T-CAP flow for a movement test: Prepare → How-to → Test → Analyse.
class MovementCaptureScreen extends StatefulWidget {
  const MovementCaptureScreen({
    super.key,
    required this.protocol,
    this.startAtHowTo = false,
  });

  final MovementProtocol protocol;
  final bool startAtHowTo;

  @override
  State<MovementCaptureScreen> createState() => _MovementCaptureScreenState();
}

class _MovementCaptureScreenState extends State<MovementCaptureScreen> {
  static const _labels = ['Prepare', 'How-to', 'Test', 'Analyse'];
  static const int _testIdx = 2;
  static const int _analyseIdx = 3;

  MovementProtocol get p => widget.protocol;

  int _step = 0;
  final Set<int> _checked = {};
  MovementSide _firstSide = MovementSide.right;
  bool _showTestControls = false;
  MovementDemoOutcome _demoOutcome = MovementDemoOutcome.normal;
  bool _forceSimulated = false;
  bool _simOutOfFrame = false;
  int _retakes = 0;

  MovementRunController? _run;
  BiometricCameraController? _camera;
  HandTrackingService? _hand;
  VoiceCoachController? _voice;
  int _analysisStage = 0;
  Timer? _analysisTimer;
  DateTime? _testStartedAt;

  @override
  void initState() {
    super.initState();
    if (widget.startAtHowTo) _step = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voice ??= VoiceCoachController(
      languageCode: ttsLocaleFor(AppStateScope.of(context).localeCode),
    );
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _run?.dispose();
    _camera?.dispose();
    _hand?.dispose();
    _voice?.dispose();
    _leaveImmersive();
    super.dispose();
  }

  void _say(
    String text, {
    VoiceCueTone tone = VoiceCueTone.ready,
    bool force = true,
  }) {
    _voice?.announce(text, tone: tone, force: force);
  }

  // ---------------------------------------------------------------------
  // Steps
  // ---------------------------------------------------------------------

  bool get _prepareReady => _checked.length >= p.prepareChecklist.length;

  void _goHowTo() {
    setState(() => _step = 1);
    _say('${p.howTo.first.title}. ${p.howTo.first.body}');
  }

  void _playInstructions() {
    final buf = StringBuffer();
    for (var i = 0; i < p.howTo.length; i++) {
      buf.write('Step ${i + 1}. ${p.howTo[i].title}. ${p.howTo[i].body} ');
    }
    _say(buf.toString());
  }

  Future<void> _enterTest() async {
    _testStartedAt = DateTime.now();
    unawaited(_enterImmersive());
    final sensors = MotionSensorService.instance;
    sensors.forceSimulated = _forceSimulated;
    sensors.simulatedProfile = _profileForOutcome();
    if (p.kind == MovementTestKind.tappingVideo) {
      _hand?.dispose();
      _hand = HandTrackingService.create(
        forceSimulated: _forceSimulated,
        simulatedHz: 4,
        simulatedDecrementPct: switch (_demoOutcome) {
          MovementDemoOutcome.normal => 8,
          MovementDemoOutcome.borderline => 17,
          MovementDemoOutcome.refer => 30,
        },
      );
      await _hand!.start();
      _camera?.dispose();
      _camera = BiometricCameraController(
        mode: ScanCameraMode.frontHand,
        onRawFrame: (img, desc) => _hand?.onCameraFrame(img, desc),
      );
      _camera!.initialize();
    }
    _run?.dispose();
    _run = MovementRunController(
      protocol: p,
      sensors: sensors,
      handTracker: _hand,
      firstSide: _firstSide,
      onSpeak: (t, {warning = false}) =>
          _say(t, tone: warning ? VoiceCueTone.warning : VoiceCueTone.scanning),
      onTick: () => PacingAudio.instance.tick(),
      onGo: () => PacingAudio.instance.go(),
      onStop: () => PacingAudio.instance.stop(),
      onCount: (n) {
        if (p.pacing == MovementPacing.voiceCount) {
          _say('$n', tone: VoiceCueTone.scanning);
        }
        PacingAudio.instance.beep();
      },
    )..addListener(_onRunChanged);
    setState(() => _step = _testIdx);
    _say(p.howTo.first.body, tone: VoiceCueTone.ready);
  }

  SimulatedMotionProfile _profileForOutcome() => switch (p.kind) {
    MovementTestKind.gait =>
      _demoOutcome == MovementDemoOutcome.refer
          ? SimulatedMotionProfile.walkingSlow
          : SimulatedMotionProfile.walking,
    MovementTestKind.sitToStand =>
      _demoOutcome == MovementDemoOutcome.refer
          ? SimulatedMotionProfile.sitToStandLow
          : SimulatedMotionProfile.sitToStand,
    MovementTestKind.tremor => switch (_demoOutcome) {
      MovementDemoOutcome.normal => SimulatedMotionProfile.stillHand,
      MovementDemoOutcome.borderline => SimulatedMotionProfile.tremorEssential,
      MovementDemoOutcome.refer => SimulatedMotionProfile.tremor,
    },
    _ => SimulatedMotionProfile.walking,
  };

  void _onRunChanged() {
    if (!mounted) return;
    final r = _run!;
    if (r.phase == RunPhase.processing) {
      _startAnalysis();
    } else {
      setState(() {});
    }
  }

  /// Portrait lock + keep-awake (Doc 06 "Immersive Capture"). Never awaited
  /// on the UI path: plugin calls can stall on desktop / test hosts.
  Future<void> _enterImmersive() async {
    if (MotionSensorService.isFlutterTest) return;
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } catch (_) {}
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  void _leaveImmersive() {
    if (MotionSensorService.isFlutterTest) return;
    try {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } catch (_) {}
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  Future<void> _confirmLeave() async {
    final r = _run;
    final running =
        r != null &&
        (r.phase == RunPhase.running ||
            r.phase == RunPhase.countdown ||
            r.phase == RunPhase.paused ||
            r.phase == RunPhase.sideSwitch);
    if (!running) {
      Navigator.of(context).maybePop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop the test?'),
        content: const Text('Data recorded so far is discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      _run?.abort();
      Navigator.of(context).pop();
    }
  }

  void _startAnalysis() {
    setState(() {
      _step = _analyseIdx;
      _analysisStage = 0;
    });
    _say('Test complete. Analysing.', tone: VoiceCueTone.completed);
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 420), (t) {
      if (!mounted) return;
      if (_analysisStage < p.analysisStages.length - 1) {
        setState(() => _analysisStage++);
        return;
      }
      t.cancel();
      _finish();
    });
  }

  void _finish() {
    final appState = AppStateScope.of(context);
    final run = _run!;
    final sensors = MotionSensorService.instance;
    final backend = p.kind == MovementTestKind.tappingVideo
        ? (_hand?.backend ?? 'simulated')
        : p.kind == MovementTestKind.tappingTouch
        ? 'touch'
        : sensors.simulated
        ? 'simulated'
        : 'sensors';
    final result = buildMovementSession(
      protocol: p,
      subject: appState.activeSubject,
      captures: run.captures,
      backend: backend,
      demoOutcome: _demoOutcome,
      history: appState.movementSessions,
      hasVoiceTask: appState.hasVoiceTaskRecord,
      hasFaceTask: appState.hasFaceVideoRecord,
      sensorSimulated: p.usesMotion
          ? sensors.simulated
          : _hand?.backend == 'simulated',
      retakes: _retakes,
    );
    _run?.dispose();
    _run = null;
    _camera?.dispose();
    _camera = null;
    _hand?.dispose();
    _hand = null;
    _leaveImmersive();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MovementResultScreen(result: result),
      ),
    );
  }

  void _retake() {
    _retakes++;
    _run?.dispose();
    _run = null;
    _camera?.dispose();
    _camera = null;
    _hand?.dispose();
    _hand = null;
    _enterTest();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final immersive = _step == _testIdx;
    return PopScope(
      canPop: !immersive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: immersive
            ? const Color(0xFF070D19)
            : MirrorColors.backgroundLight,
        appBar: immersive
            ? null
            : AppBar(
                title: Text(p.title),
                actions: [
                  IconButton(
                    tooltip: 'Screen spec & gates (${p.screenId})',
                    icon: const Icon(Icons.info_outline_rounded),
                    onPressed: () =>
                        showScreenGateLifecycleSheet(context, p.screenId),
                  ),
                ],
              ),
        body: immersive
            ? _testBody()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: StepHeader(labels: _labels, current: _step),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: switch (_step) {
                        0 => _prepare(),
                        1 => _howTo(),
                        _ => _analyse(),
                      },
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: immersive
            ? null
            : switch (_step) {
                0 => PrimaryBottomButton(
                  label: 'Continue',
                  helper: _prepareReady ? null : 'Tick each item to continue',
                  onPressed: _prepareReady ? _goHowTo : null,
                ),
                1 => PrimaryBottomButton(
                  label: 'Start test',
                  icon: Icons.play_arrow_rounded,
                  helper: p.twoSided
                      ? '${_firstSide.label} hand first · ${p.secondsPerSide} s each'
                      : p.durationLabel,
                  onPressed: _enterTest,
                ),
                _ => null,
              },
      ),
    );
  }

  // --- Prepare ---------------------------------------------------------------

  Widget _prepare() {
    return ListView(
      key: const ValueKey('prepare'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          'Step 1 · Set up',
          'Tick each item when it is done · ${p.durationLabel}',
        ),
        MaterialCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < p.prepareChecklist.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                CheckboxListTile(
                  key: ValueKey('mov_check_$i'),
                  value: _checked.contains(i),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _checked.add(i);
                    } else {
                      _checked.remove(i);
                    }
                  }),
                  secondary: MovementIllustrationView(
                    kind: p.prepareChecklist[i].illustration,
                    size: 60,
                  ),
                  title: Text(
                    p.prepareChecklist[i].text,
                    style: const TextStyle(
                      color: AnaemiaUi.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (p.setupHint.isNotEmpty) ...[
          const SizedBox(height: 10),
          InfoNote(text: p.setupHint, icon: Icons.lightbulb_outline_rounded),
        ],
        if (p.twoSided) ...[
          const SizedBox(height: 16),
          AnaemiaUi.sectionHeader(
            'Which hand first?',
            'Each hand is tested in turn',
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AnaemiaUi.card(),
            child: SegmentedButton<MovementSide>(
              segments: const [
                ButtonSegment(
                  value: MovementSide.right,
                  label: Text('Right first'),
                  icon: MovementIllustrationView(
                    kind: MovementIllustration.handRight,
                    size: 26,
                    background: Colors.transparent,
                  ),
                ),
                ButtonSegment(
                  value: MovementSide.left,
                  label: Text('Left first'),
                  icon: MovementIllustrationView(
                    kind: MovementIllustration.handLeft,
                    size: 26,
                    background: Colors.transparent,
                  ),
                ),
              ],
              selected: {_firstSide},
              onSelectionChanged: (s) => setState(() => _firstSide = s.first),
            ),
          ),
        ],
        const SizedBox(height: 16),
        AnaemiaUi.sectionHeader('You will need', p.plainSensorLine),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < p.needs.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: AnaemiaUi.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MovementIllustrationView(
                        kind: p.needs[i].illustration,
                        size: 76,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.needs[i].title,
                        style: const TextStyle(
                          color: AnaemiaUi.ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        p.needs[i].sub,
                        style: const TextStyle(
                          color: AnaemiaUi.muted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // --- How-to ----------------------------------------------------------------

  Widget _howTo() {
    return ListView(
      key: const ValueKey('howto'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          'Step 2 · How to do the test',
          '${p.howTo.length} steps · voice guided · ${p.durationLabel}',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _playInstructions,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
            label: const Text('Play instructions aloud'),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < p.howTo.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: AnaemiaUi.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: MovementIllustrationView(
                    kind: p.howTo[i].illustration,
                    size: 200,
                    wide: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AnaemiaUi.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.howTo[i].title,
                            style: const TextStyle(
                              color: AnaemiaUi.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.howTo[i].body,
                            style: const TextStyle(
                              color: AnaemiaUi.ink,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        InfoNote(
          icon: Icons.rule_rounded,
          text: switch (p.kind) {
            MovementTestKind.tappingVideo =>
              'If your hand leaves the outline for more than a second, that hand starts again (up to 3 times). You can skip a hand you cannot use.',
            MovementTestKind.tappingTouch =>
              'Fewer than 5 taps on a hand asks you to try again or skip that hand.',
            MovementTestKind.gait =>
              'If no walking rhythm is found (phone not in the front pocket, or too few steps) the app asks you to try again, up to 3 times.',
            MovementTestKind.sitToStand =>
              'If the sensor signal drops out during the 30 seconds the app asks you to repeat the test.',
            MovementTestKind.tremor =>
              'A big slow arm movement starts the 20 seconds again for that hand (up to 3 times). You can skip a hand.',
          },
        ),
      ],
    );
  }

  // --- Test (immersive) ------------------------------------------------------

  Widget _testBody() {
    final r = _run;
    if (r == null) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        _visual(r),
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  _glassButton(
                    Icons.close_rounded,
                    'Stop and leave',
                    _confirmLeave,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.twoSided && r.currentSide != null
                              ? '${r.currentSide!.label} hand · ${r.sideIndex + 1} of 2'
                              : p.shortTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Step 3 of 4 · ${p.screenId}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _glassButton(
                    Icons.info_outline_rounded,
                    'Screen spec & gates',
                    () => showScreenGateLifecycleSheet(context, p.screenId),
                  ),
                  const SizedBox(width: 6),
                  _glassButton(
                    (_voice?.audioEnabled ?? true)
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    'Voice on / off',
                    () => setState(() => _voice?.toggleAudio()),
                  ),
                  const SizedBox(width: 6),
                  _glassButton(
                    Icons.science_outlined,
                    'Test Controls',
                    () =>
                        setState(() => _showTestControls = !_showTestControls),
                    tint: _showTestControls ? const Color(0xFF00E5CC) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(top: false, child: _dock(r)),
        ),
      ],
    );
  }

  Widget _visual(MovementRunController r) {
    if (r.phase == RunPhase.sideSwitch && r.currentSide != null) {
      return _sideSwitchCard(r.currentSide!);
    }
    switch (p.kind) {
      case MovementTestKind.tappingVideo:
        final cam = _camera;
        if (cam != null) {
          // Same guide for the check and the drawing, from the live viewport.
          r.guideRect = HandGuide.forViewport(
            MediaQuery.sizeOf(context),
            _previewAspect(cam),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            if (cam != null)
              LiveBiometricCameraSurface(
                controller: cam,
                fullBleed: true,
                overlayPainter: HandOverlayPainter(
                  landmarks: r.landmarks,
                  status: r.handStatus,
                  active: r.phase == RunPhase.running,
                  normDistance: r.normDistance,
                  previewAspect: _previewAspect(cam),
                  guide: r.guideRect,
                ),
              ),
            Positioned(
              top: 58,
              left: 0,
              right: 0,
              child: Center(
                child: _bigCounter(r, '${r.liveCount}', 'taps', size: 50),
              ),
            ),
          ],
        );
      case MovementTestKind.tappingTouch:
        return Padding(
          padding: const EdgeInsets.only(top: 90, bottom: 210),
          child: TwoTargetsPad(
            enabled: r.phase == RunPhase.running,
            count: r.liveCount,
            onTap: r.onTouchTarget,
          ),
        );
      case MovementTestKind.gait:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MovementIllustrationView(
                kind: r.phase == RunPhase.countdown
                    ? MovementIllustration.phoneInPocket
                    : MovementIllustration.walk10m,
                size: 150,
                background: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 18),
              _bigCounter(r, '${r.liveCount}', 'steps'),
              const SizedBox(height: 6),
              Text(
                r.phase == RunPhase.running
                    ? (r.walkingDetected ? 'Walking' : 'Listening for steps…')
                    : r.phase == RunPhase.countdown
                    ? 'Pocket the phone'
                    : 'Stopped',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      case MovementTestKind.sitToStand:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MovementIllustrationView(
                kind: MovementIllustration.chairArmless,
                size: 140,
                background: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 18),
              _bigCounter(r, '${r.liveCount}', 'stands'),
            ],
          ),
        );
      case MovementTestKind.tremor:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BubbleLevelView(
                tiltX: r.tiltX,
                tiltY: r.tiltY,
                steady: r.armSteady,
                size: 190,
              ),
              const SizedBox(height: 14),
              Text(
                r.noiseFloorPhase
                    ? 'Measuring noise floor…'
                    : (r.armSteady ? 'Hold still' : 'Hold your arm steady'),
                style: TextStyle(
                  color: r.armSteady ? Colors.white : const Color(0xFFFDE68A),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
    }
  }

  /// Upright preview width ÷ height; the camera reports the sensor size in
  /// landscape, so swap. Falls back to 4:3 until the camera is up.
  double _previewAspect(BiometricCameraController cam) {
    final s = cam.cameraController?.value.previewSize;
    if (s == null || s.width <= 0 || s.height <= 0) return 0.75;
    return s.height / s.width;
  }

  /// Between hands: a full card with the next hand drawn, so the switch is
  /// unmistakable.
  Widget _sideSwitchCard(MovementSide next) {
    final hand = next.label.toLowerCase();
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 90, 28, 230),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MovementIllustrationView(
              kind: next == MovementSide.left
                  ? MovementIllustration.handLeft
                  : MovementIllustration.handRight,
              size: 150,
            ),
            const SizedBox(height: 18),
            Text(
              'Now the $hand hand',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              switch (p.kind) {
                MovementTestKind.tappingVideo =>
                  'Show your $hand hand in the outline, then tap Start.',
                MovementTestKind.tappingTouch =>
                  'Use the index finger of your $hand hand, then tap Start.',
                MovementTestKind.tremor =>
                  'Pass the phone to your $hand hand, arm straight out, then tap Start.',
                _ => 'Tap Start when you are ready.',
              },
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigCounter(
    MovementRunController r,
    String value,
    String unit, {
    double size = 64,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// Minimal T-CAP dock: ring, a short headline with one support line, the
  /// primary button and the skip link. Quality checks surface only as a
  /// single banner line when one fails; the full chip row lives behind the
  /// Test Controls toggle.
  Widget _dock(MovementRunController r) {
    final phase = r.phase;
    final problem = r.problemLine;
    final (headline, support) = _statusLines(r);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (problem != null && phase != RunPhase.sideSwitch)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFFDE68A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    problem,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CountdownRing(
                    progress: phase == RunPhase.countdown ? 0 : r.progress,
                    label: phase == RunPhase.countdown
                        ? (r.waitingForSteady ? '…' : '${r.countdownValue}')
                        : phase == RunPhase.running || phase == RunPhase.paused
                        ? (p.kind == MovementTestKind.gait
                              ? '${r.elapsed.floor()}s'
                              : '${r.remainingSeconds}s')
                        : phase == RunPhase.sideSwitch
                        ? '✓'
                        : '${p.secondsPerSide}s',
                    active: phase == RunPhase.running,
                    paused: phase == RunPhase.paused,
                    size: 64,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          support,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buttons(r),
              if (_showTestControls) ...[
                const SizedBox(height: 10),
                if (r.checks.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [for (final c in r.checks) _checkChip(c)],
                  ),
                  const SizedBox(height: 8),
                ],
                _testControls(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  (String, String) _statusLines(MovementRunController r) {
    final side = r.currentSide?.label.toLowerCase() ?? '';
    switch (r.phase) {
      case RunPhase.idle:
        return (
          p.twoSided ? '${r.currentSide?.label ?? ''} hand' : 'Ready?',
          _idleLine(),
        );
      case RunPhase.countdown:
        if (r.waitingForSteady) {
          return (
            'Hold your arm steady',
            'Arm straight out, palm down. Recording starts by itself once the phone is still.',
          );
        }
        return (
          p.kind == MovementTestKind.gait ? 'Pocket the phone' : 'Get ready',
          p.kind == MovementTestKind.gait
              ? 'Walking starts in ${r.countdownValue}…'
              : 'Starting in ${r.countdownValue}…',
        );
      case RunPhase.running:
        return (
          p.kind == MovementTestKind.gait && !r.walkingDetected
              ? 'Walk now'
              : p.runHeadline,
          r.coaching,
        );
      case RunPhase.paused:
        return ('Paused', 'Tap Resume when you are ready.');
      case RunPhase.sideSwitch:
        return ('Switch hands', 'Now the $side hand.');
      case RunPhase.processing:
      case RunPhase.done:
      case RunPhase.aborted:
        return ('Done', 'Analysing your recording…');
    }
  }

  String _idleLine() => switch (p.kind) {
    MovementTestKind.tappingVideo =>
      'Show your ${_run!.currentSide?.label.toLowerCase() ?? ''} hand in the outline, then tap Start.',
    MovementTestKind.tappingTouch =>
      'Rest your hand on the table, then tap Start.',
    MovementTestKind.gait =>
      'Stand at the start line. Tap Start, then pocket the phone.',
    MovementTestKind.sitToStand =>
      'Sit ready with your arms crossed, then tap Start.',
    MovementTestKind.tremor =>
      'Phone flat in your ${_run!.currentSide?.label.toLowerCase() ?? ''} hand, arm straight out, then tap Start.',
  };

  Widget _buttons(MovementRunController r) {
    final phase = r.phase;
    Widget primary;
    switch (phase) {
      case RunPhase.idle:
        primary = _bigButton('Start', Icons.play_arrow_rounded, r.start);
      case RunPhase.countdown:
        primary = _bigButton('Get ready…', Icons.hourglass_top_rounded, null);
      case RunPhase.running:
        primary = p.kind == MovementTestKind.gait
            ? _bigButton('Stop', Icons.stop_rounded, r.stopEarly)
            : _bigButton('Pause', Icons.pause_rounded, r.pause);
      case RunPhase.paused:
        primary = _bigButton('Resume', Icons.play_arrow_rounded, r.resume);
      case RunPhase.sideSwitch:
        primary = _bigButton(
          'Start ${r.currentSide?.label.toLowerCase() ?? 'other'} hand',
          Icons.play_arrow_rounded,
          r.start,
        );
      case RunPhase.processing:
      case RunPhase.done:
      case RunPhase.aborted:
        primary = _bigButton(
          'Analysing…',
          Icons.hourglass_bottom_rounded,
          null,
        );
    }
    final canSkip =
        p.twoSided &&
        (phase == RunPhase.idle ||
            phase == RunPhase.running ||
            phase == RunPhase.paused ||
            phase == RunPhase.sideSwitch);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        if (canSkip)
          TextButton.icon(
            onPressed: r.skipSide,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              minimumSize: const Size(0, 40),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: const Text('Skip this hand'),
          ),
      ],
    );
  }

  Widget _bigButton(String label, IconData icon, VoidCallback? onTap) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF00E5CC),
        foregroundColor: const Color(0xFF0F172A),
        disabledBackgroundColor: Colors.white24,
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _checkChip(RunCheck c) {
    final Color color = c.pass == null
        ? Colors.white54
        : c.pass!
        ? const Color(0xFF34D399)
        : const Color(0xFFFBBF24);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            c.pass == null
                ? Icons.radio_button_unchecked_rounded
                : c.pass!
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              c.detail != null && c.pass != null && !c.label.contains(c.detail!)
                  ? '${c.label} · ${c.detail}'
                  : c.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testControls() {
    final sensors = MotionSensorService.instance;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        if (p.kind == MovementTestKind.tappingVideo && _run != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _run!.tapDiagnostics,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
        for (final o in MovementDemoOutcome.values)
          _testChip(
            'Outcome: ${p.demoOutcomeLabels[o.name] ?? o.name}',
            _demoOutcome == o,
            () {
              setState(() => _demoOutcome = o);
              sensors.simulatedProfile = _profileForOutcome();
              if (_hand is SimulatedHandTracker ||
                  p.kind == MovementTestKind.tappingVideo) {
                _retake();
              }
            },
          ),
        if (p.kind == MovementTestKind.tappingVideo)
          _testChip('Simulate hand out of frame', _simOutOfFrame, () {
            setState(() => _simOutOfFrame = !_simOutOfFrame);
            final h = _hand;
            if (h is SimulatedHandTracker) {
              h.simulateOutOfFrame = _simOutOfFrame;
            }
          }),
        if (p.kind == MovementTestKind.tremor)
          _testChip(
            'Simulate gross movement',
            sensors.simulatedProfile == SimulatedMotionProfile.grossMovement,
            () {
              sensors.simulatedProfile = SimulatedMotionProfile.grossMovement;
              _retake();
            },
          ),
        if (p.usesMotion)
          _testChip(
            'Simulate sensor dropout',
            sensors.simulatedProfile == SimulatedMotionProfile.dropout,
            () {
              sensors.simulatedProfile = SimulatedMotionProfile.dropout;
              _retake();
            },
          ),
        if (p.usesMotion || p.kind == MovementTestKind.tappingVideo)
          _testChip(
            'Simulated sensors',
            _forceSimulated || sensors.simulated,
            () {
              setState(() => _forceSimulated = !_forceSimulated);
              _retake();
            },
          ),
      ],
    );
  }

  Widget _testChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10.5)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      selectedColor: const Color(0xFF00E5CC).withValues(alpha: 0.25),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: Colors.white10,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
    );
  }

  Widget _glassButton(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    Color? tint,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: tint ?? Colors.white),
          ),
        ),
      ),
    );
  }

  // --- Analyse ---------------------------------------------------------------

  Widget _analyse() {
    final elapsed = _testStartedAt == null
        ? 0
        : DateTime.now().difference(_testStartedAt!).inSeconds;
    return ListView(
      key: const ValueKey('analyse'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          'Step 4 · Analysing',
          '${p.algorithmId} on-device · $elapsed s so far',
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AnaemiaUi.card(),
          child: Column(
            children: [
              for (var i = 0; i < p.analysisStages.length; i++)
                ListTile(
                  dense: true,
                  leading: i < _analysisStage
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: MirrorColors.successFg,
                        )
                      : i == _analysisStage
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(
                          Icons.radio_button_unchecked_rounded,
                          color: AnaemiaUi.muted,
                        ),
                  title: Text(
                    p.analysisStages[i],
                    style: TextStyle(
                      color: i <= _analysisStage
                          ? AnaemiaUi.ink
                          : AnaemiaUi.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// T-CAP countdown ring: progress of the recording, the countdown number
/// before it, paused state in amber.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.progress,
    required this.label,
    this.active = false,
    this.paused = false,
    this.size = 74,
  });

  final double progress;
  final String label;
  final bool active;
  final bool paused;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = paused
        ? const Color(0xFFFBBF24)
        : active
        ? const Color(0xFF34D399)
        : Colors.white70;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Center(
            child: label == '✓'
                ? Icon(Icons.check_rounded, color: color, size: size * 0.42)
                : Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: size * 0.28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Two large circular targets for ALG-MOV-02; flashes on a hit, shows a
/// "same target" warning for repeats.
class TwoTargetsPad extends StatefulWidget {
  const TwoTargetsPad({
    super.key,
    required this.enabled,
    required this.count,
    required this.onTap,
  });

  final bool enabled;
  final int count;
  final void Function(int target) onTap;

  @override
  State<TwoTargetsPad> createState() => _TwoTargetsPadState();
}

class _TwoTargetsPadState extends State<TwoTargetsPad> {
  int? _last;
  int? _flash;
  bool _miss = false;

  void _hit(int t) {
    if (!widget.enabled) return;
    setState(() {
      _miss = _last == t;
      _last = t;
      _flash = t;
    });
    widget.onTap(t);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final r = math.min(c.maxWidth * 0.22, 96.0);
        return Stack(
          children: [
            Positioned(
              left: c.maxWidth * 0.14,
              top: c.maxHeight * 0.52,
              child: _target(0, 'A', r),
            ),
            Positioned(
              right: c.maxWidth * 0.14,
              top: c.maxHeight * 0.18,
              child: _target(1, 'B', r),
            ),
            if (_miss && widget.enabled)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    'Tap the other circle',
                    style: TextStyle(
                      color: const Color(0xFFFDE68A).withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _target(int t, String label, double r) {
    final lit = _flash == t;
    return GestureDetector(
      key: ValueKey('mov_target_$t'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _hit(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lit
              ? const Color(0xFF00E5CC)
              : const Color(
                  0xFF00E5CC,
                ).withValues(alpha: widget.enabled ? 0.22 : 0.10),
          border: Border.all(color: const Color(0xFF00E5CC), width: 3),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: lit ? const Color(0xFF0F172A) : Colors.white,
            fontSize: r * 0.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Bubble level driven by the accelerometer tilt (tremor test).
class BubbleLevelView extends StatelessWidget {
  const BubbleLevelView({
    super.key,
    required this.tiltX,
    required this.tiltY,
    required this.steady,
    this.size = 180,
  });

  final double tiltX;
  final double tiltY;
  final bool steady;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = steady ? const Color(0xFF34D399) : const Color(0xFFFBBF24);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
          ),
          Container(
            width: size * 0.34,
            height: size * 0.34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 120),
            alignment: Alignment(
              tiltX.clamp(-0.9, 0.9),
              (-tiltY).clamp(-0.9, 0.9),
            ),
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hand guide plus the 21 landmark points when tracked.
///
/// Landmarks arrive in normalised display space (upright, mirrored like the
/// selfie preview). The preview is cover-fitted into the surface, so the
/// same cover transform is applied here; the guide rectangle is
/// [HandGuide] mapped through that transform, which keeps the drawing and
/// the "whole hand inside" check identical.
class HandOverlayPainter extends CustomPainter {
  const HandOverlayPainter({
    required this.landmarks,
    required this.status,
    required this.active,
    required this.guide,
    this.previewAspect = 0.75,
    this.normDistance,
  });

  final List<HandPoint>? landmarks;
  final HandStatus status;
  final bool active;

  /// Guide in normalised image space (see [HandGuide.forViewport]).
  final Rect guide;

  /// Upright preview width ÷ height (e.g. 0.75 for a 4:3 sensor).
  final double previewAspect;
  final double? normDistance;

  static const List<List<int>> _bones = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Cover-fit mapping of the normalised image onto the surface.
    final aspect = previewAspect > 0 ? previewAspect : 0.75;
    final scale = math.max(size.width / aspect, size.height);
    final drawnW = aspect * scale;
    final drawnH = scale;
    final ox = (size.width - drawnW) / 2;
    final oy = (size.height - drawnH) / 2;
    Offset map(double x, double y) => Offset(ox + x * drawnW, oy + y * drawnH);

    final ok = status == HandStatus.ok;
    final seen = status != HandStatus.noHand;
    final color = ok
        ? (active ? const Color(0xFF34D399) : Colors.white)
        : const Color(0xFFFBBF24);

    // Dim everything outside the guide so the outline is the obvious target.
    final tl = map(guide.left, guide.top);
    final br = map(guide.right, guide.bottom);
    final win = Rect.fromPoints(tl, br);
    final rr = RRect.fromRectAndRadius(win, const Radius.circular(28));
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rr)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    final guidePaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ok ? 3 : 2.4;
    if (ok) {
      canvas.drawRRect(rr, guidePaint);
    } else {
      final path = Path()..addRRect(rr);
      for (final m in path.computeMetrics()) {
        var d = 0.0;
        while (d < m.length) {
          canvas.drawPath(m.extractPath(d, d + 12), guidePaint);
          d += 20;
        }
      }
    }
    // Corner ticks (Face-ID style) on the guide.
    final tick = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const l = 18.0;
    for (final (cx, cy, sx, sy) in [
      (win.left, win.top, 1.0, 1.0),
      (win.right, win.top, -1.0, 1.0),
      (win.left, win.bottom, 1.0, -1.0),
      (win.right, win.bottom, -1.0, -1.0),
    ]) {
      canvas.drawLine(
        Offset(cx, cy + sy * 28),
        Offset(cx, cy + sy * (28 + l)),
        tick,
      );
      canvas.drawLine(
        Offset(cx + sx * 28, cy),
        Offset(cx + sx * (28 + l), cy),
        tick,
      );
    }

    final lm = landmarks;
    if (lm != null && lm.length >= 21) {
      final bone = Paint()
        ..color = (ok ? const Color(0xFF00E5CC) : const Color(0xFFFBBF24))
            .withValues(alpha: 0.95)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      Offset at(int i) => map(lm[i].x, lm[i].y);
      for (final b in _bones) {
        canvas.drawLine(at(b[0]), at(b[1]), bone);
      }
      for (var i = 0; i < 21; i++) {
        final tip = i == 4 || i == 8;
        canvas.drawCircle(
          at(i),
          tip ? 7 : 4,
          Paint()..color = tip ? const Color(0xFFFDE68A) : Colors.white,
        );
      }
      // Thumb–index gap: the measured signal, drawn thick when open.
      final d = normDistance ?? 0;
      canvas.drawLine(
        at(4),
        at(8),
        Paint()
          ..color = const Color(0xFFFDE68A)
          ..strokeWidth = 2 + (d * 3).clamp(0, 4),
      );
    }

    final label = switch (status) {
      HandStatus.ok => active ? 'Hand found · tapping' : 'Hand found',
      HandStatus.tooFar => 'Move closer',
      HandStatus.tooClose => 'Move back a little',
      HandStatus.partlyOutside => 'Whole hand inside the outline',
      HandStatus.noHand => 'Show your whole hand here',
    };
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFamily: 'Roboto',
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Inside the guide, at the bottom, so the dock never covers it.
    tp.paint(
      canvas,
      Offset(win.center.dx - tp.width / 2, win.bottom - tp.height - 12),
    );
    if (!seen) {
      // A faint hand silhouette hint in the middle of the guide.
      final hint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      final c = win.center;
      final s = win.width * 0.22;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c + Offset(0, s * 0.3),
            width: s,
            height: s * 1.1,
          ),
          Radius.circular(s * 0.22),
        ),
        hint,
      );
      for (var i = 0; i < 4; i++) {
        final x = c.dx - s * 0.36 + i * s * 0.24;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, c.dy - s * 0.55),
              width: s * 0.2,
              height: s * 0.9,
            ),
            Radius.circular(s * 0.1),
          ),
          hint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant HandOverlayPainter old) =>
      old.landmarks != landmarks ||
      old.status != status ||
      old.active != active ||
      old.normDistance != normDistance ||
      old.previewAspect != previewAspect ||
      old.guide != guide;
}
