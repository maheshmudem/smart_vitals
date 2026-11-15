import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/vision_session_builder.dart';
import '../../core/domain/entities/vision_protocol.dart';
import '../../core/services/face_distance_service.dart';
import '../../core/services/live_camera_service.dart';
import '../../core/services/pacing_audio_service.dart';
import '../../core/services/screen_brightness_service.dart';
import '../../core/services/screen_metrics_service.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'acuity_test_view.dart';
import 'amsler_grid_view.dart';
import 'colour_plate_view.dart';
import 'reaction_test_view.dart';
import 'vision_illustrations.dart';
import 'vision_result_screen.dart';
import 'vision_run_controller.dart';

/// T-CAP flow for a vision test: Prepare → How-to → Test → Analyse.
class VisionCaptureScreen extends StatefulWidget {
  const VisionCaptureScreen({
    super.key,
    required this.protocol,
    this.startAtHowTo = false,
  });

  final VisionProtocol protocol;
  final bool startAtHowTo;

  @override
  State<VisionCaptureScreen> createState() => _VisionCaptureScreenState();
}

class _VisionCaptureScreenState extends State<VisionCaptureScreen> {
  static const _labels = ['Prepare', 'How-to', 'Test', 'Analyse'];
  static const int _testIdx = 2;
  static const int _analyseIdx = 3;

  VisionProtocol get p => widget.protocol;

  int _step = 0;
  final Set<int> _checked = {};
  bool _showTestControls = false;
  VisionDemoOutcome _demoOutcome = VisionDemoOutcome.normal;
  int _retakes = 0;

  VisionRunController? _run;
  BiometricCameraController? _camera;
  FaceDistanceService? _distance;
  VoiceCoachController? _voice;
  ScreenMetrics _metrics = const ScreenMetrics(
    mmPerLogicalPx: 25.4 / 160,
    source: 'estimated',
  );
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
    final appState = AppStateScope.of(context);
    _voice ??= VoiceCoachController(
      languageCode: ttsLocaleFor(appState.localeCode),
    );
    unawaited(_resolveMetrics(appState));
  }

  Future<void> _resolveMetrics(AppState appState) async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final m = await ScreenMetricsService.instance.resolve(
      devicePixelRatio: dpr,
      calibratedMmPerPx: appState.deviceProfile.screenMmPerLogicalPx,
    );
    if (!mounted) return;
    setState(() => _metrics = m);
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _run?.dispose();
    _distance?.dispose();
    _camera?.dispose();
    _voice?.dispose();
    _leaveImmersive();
    super.dispose();
  }

  void _say(String text, {VoiceCueTone tone = VoiceCueTone.ready}) {
    _voice?.announce(text, tone: tone, force: true);
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
    final appState = AppStateScope.of(context);
    if (p.needsMaxBrightness) {
      unawaited(ScreenBrightnessService.instance.boostToMax());
    }
    if (p.kind == VisionTestKind.acuity) {
      _camera?.dispose();
      _camera = BiometricCameraController(mode: ScanCameraMode.frontFace);
      _camera!.initialize();
      _distance?.dispose();
      _distance = FaceDistanceService(
        camera: _camera,
        calibratedFocalPx: appState.deviceProfile.focalLengthPx,
      );
    }
    _run?.dispose();
    _run = VisionRunController(
      protocol: p,
      distance: _distance,
      demoOutcome: _demoOutcome,
      onSpeak: (t, {warning = false}) =>
          _voice?.announceAndWait(
            t,
            tone: warning ? VoiceCueTone.warning : VoiceCueTone.scanning,
          ) ??
          Future<void>.value(),
      onBeep: () => PacingAudio.instance.beep(),
    )..addListener(_onRunChanged);
    setState(() => _step = _testIdx);
    _say(p.howTo.first.body, tone: VoiceCueTone.ready);
  }

  void _onRunChanged() {
    if (!mounted) return;
    if (_run!.phase == VisionPhase.processing) {
      _startAnalysis();
    } else {
      setState(() {});
    }
  }

  Future<void> _enterImmersive() async {
    if (ScreenBrightnessService.isFlutterTest) return;
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
    unawaited(ScreenBrightnessService.instance.restore());
    if (ScreenBrightnessService.isFlutterTest) return;
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
        (r.phase == VisionPhase.running ||
            r.phase == VisionPhase.pausedDistance ||
            r.phase == VisionPhase.switchPart);
    if (!running) {
      Navigator.of(context).maybePop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop the test?'),
        content: const Text('Answers recorded so far are discarded.'),
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
    if (_step == _analyseIdx) return;
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
    final d = _distance?.reading;
    final result = buildVisionSession(
      protocol: p,
      subject: appState.activeSubject,
      captures: run.captures,
      demoOutcome: _demoOutcome,
      history: appState.visionSessions,
      distanceMode: d == null
          ? 'manual'
          : switch (d.mode) {
              DistanceMode.measured => 'measured',
              DistanceMode.estimated => 'estimated',
              DistanceMode.manual => 'manual',
            },
      dpiSource: _metrics.source,
      dpi: _metrics.dpi,
      brightnessMode: p.needsMaxBrightness
          ? ScreenBrightnessService.instance.mode
          : 'n/a',
      retakes: _retakes,
      simulated: run.autoRun || (_distance?.simulated ?? false),
      durationSeconds: _testStartedAt == null
          ? 0
          : DateTime.now().difference(_testStartedAt!).inSeconds,
    );
    _run?.dispose();
    _run = null;
    _distance?.dispose();
    _distance = null;
    _camera?.dispose();
    _camera = null;
    _leaveImmersive();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => VisionResultScreen(result: result),
      ),
    );
  }

  void _retake() {
    _retakes++;
    _run?.dispose();
    _run = null;
    _distance?.dispose();
    _distance = null;
    _camera?.dispose();
    _camera = null;
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
            ? (_dark ? const Color(0xFF070D19) : Colors.white)
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
                  helper: p.perEye
                      ? 'Right eye first · ${p.durationLabel}'
                      : p.durationLabel,
                  onPressed: _enterTest,
                ),
                _ => null,
              },
      ),
    );
  }

  bool get _dark => p.kind == VisionTestKind.reaction;

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
                  key: ValueKey('vis_check_$i'),
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
                  secondary: VisionIllustrationView(
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
                      VisionIllustrationView(
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
                  child: VisionIllustrationView(
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
            VisionTestKind.acuity =>
              'If you drift outside 35–45 cm the letters pause until you are back at 40 cm (G-33). You can skip an eye you cannot use.',
            VisionTestKind.colour =>
              'Two of the plates are easy on purpose. If one of those is missed, the screen or lighting was wrong and the test asks for a retake.',
            VisionTestKind.amsler =>
              'Only mark what looks wavy, bent, dark or missing while you keep staring at the dot. You can skip an eye you cannot use.',
            VisionTestKind.reaction =>
              'A tap before the signal, or within 0.1 s of it, is a false start: it is not counted and the signal is repeated.',
          },
        ),
      ],
    );
  }

  // --- Test (immersive) ------------------------------------------------------

  Widget _testBody() {
    final r = _run;
    if (r == null) return const SizedBox.shrink();
    final fg = _dark ? Colors.white : const Color(0xFF0F172A);
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
                          r.partLabel,
                          style: TextStyle(
                            color: fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Step 3 of 4 · ${p.screenId}',
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.7),
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
                    tint: _showTestControls ? const Color(0xFF0B7A75) : null,
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

  Widget _visual(VisionRunController r) {
    if (r.phase == VisionPhase.switchPart) return _switchCard(r);
    if (r.phase == VisionPhase.idle) return _idleCard(r);
    switch (p.kind) {
      case VisionTestKind.acuity:
        return AcuityTestView(
          run: r,
          metrics: _metrics,
          onCalibrate: _showCalibration,
        );
      case VisionTestKind.colour:
        return ColourPlateView(run: r);
      case VisionTestKind.amsler:
        return AmslerGridView(run: r, metrics: _metrics);
      case VisionTestKind.reaction:
        return ReactionTestView(run: r);
    }
  }

  Widget _idleCard(VisionRunController r) {
    final kind = switch (p.kind) {
      VisionTestKind.acuity => VisionIllustration.eyeRight,
      VisionTestKind.amsler => VisionIllustration.eyeRight,
      VisionTestKind.colour => VisionIllustration.colourPlate,
      VisionTestKind.reaction => VisionIllustration.waitThenTap,
    };
    final fg = _dark ? Colors.white : const Color(0xFF0F172A);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 90, 28, 230),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VisionIllustrationView(kind: kind, size: 150),
            const SizedBox(height: 18),
            Text(
              switch (p.kind) {
                VisionTestKind.acuity => 'Cover your left eye',
                VisionTestKind.amsler => 'Cover your left eye',
                VisionTestKind.colour => 'Both eyes open',
                VisionTestKind.reaction => 'Finger ready',
              },
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              switch (p.kind) {
                VisionTestKind.acuity =>
                  'Right eye first. Hold the phone at arm\'s length, then tap Start.',
                VisionTestKind.amsler =>
                  'Right eye first. Phone at about 30 cm, then tap Start.',
                VisionTestKind.colour =>
                  'Screen at full brightness. Tap Start when ready.',
                VisionTestKind.reaction =>
                  'Tap Start, then wait for the flash.',
              },
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg.withValues(alpha: 0.75),
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (p.kind == VisionTestKind.acuity) ...[
              const SizedBox(height: 12),
              Text(
                r.distanceLine,
                style: const TextStyle(
                  color: Color(0xFF0B7A75),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _switchCard(VisionRunController r) {
    final fg = _dark ? Colors.white : const Color(0xFF0F172A);
    final eye = r.currentEye;
    final title = eye != null
        ? 'Now the ${eye.label.toLowerCase()} eye'
        : 'Now the sound block';
    final body = eye != null
        ? 'Cover your ${eye.coveredLabel} eye with your palm, then tap Start.'
        : 'Tap as soon as you hear the beep. Ten beeps.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 90, 28, 230),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VisionIllustrationView(
              kind: eye == VisionEye.left
                  ? VisionIllustration.eyeLeft
                  : eye == VisionEye.right
                  ? VisionIllustration.eyeRight
                  : VisionIllustration.speaker,
              size: 150,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg.withValues(alpha: 0.75),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dock(VisionRunController r) {
    final (headline, support) = _statusLines(r);
    final dockBg = _dark
        ? const Color(0xFF0F172A).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.96);
    final fg = _dark ? Colors.white : const Color(0xFF0F172A);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: dockBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: fg.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(
                _stepIcon(r),
                const Color(0xFF0B7A75),
                size: 44,
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
                      style: TextStyle(
                        color: fg,
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
                        color: fg.withValues(alpha: 0.75),
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
            _testControls(r),
          ],
        ],
      ),
    );
  }

  IconData _stepIcon(VisionRunController r) => switch (p.kind) {
    VisionTestKind.acuity => Icons.remove_red_eye_rounded,
    VisionTestKind.colour => Icons.palette_rounded,
    VisionTestKind.amsler => Icons.grid_on_rounded,
    VisionTestKind.reaction =>
      r.currentBlock == ReactionBlock.audio
          ? Icons.volume_up_rounded
          : Icons.bolt_rounded,
  };

  (String, String) _statusLines(VisionRunController r) {
    switch (r.phase) {
      case VisionPhase.idle:
        return ('Ready?', 'Tap Start when you are set.');
      case VisionPhase.running:
        return (
          p.runHeadline,
          r.coaching.isEmpty ? p.durationLabel : r.coaching,
        );
      case VisionPhase.pausedDistance:
        return ('Hold phone at 40 cm', r.coaching);
      case VisionPhase.switchPart:
        return ('Switch', r.coaching);
      case VisionPhase.processing:
      case VisionPhase.done:
      case VisionPhase.aborted:
        return ('Done', 'Analysing your answers…');
    }
  }

  Widget _buttons(VisionRunController r) {
    final phase = r.phase;
    Widget primary;
    switch (phase) {
      case VisionPhase.idle:
        primary = _bigButton('Start', Icons.play_arrow_rounded, r.start);
      case VisionPhase.switchPart:
        primary = _bigButton(
          r.currentEye != null
              ? 'Start ${r.currentEye!.label.toLowerCase()} eye'
              : 'Start sound block',
          Icons.play_arrow_rounded,
          r.start,
        );
      case VisionPhase.running:
      case VisionPhase.pausedDistance:
        primary = _bigButton(
          p.kind == VisionTestKind.acuity
              ? 'Keep answering…'
              : p.kind == VisionTestKind.reaction
              ? 'Keep going…'
              : 'Answer on the screen above',
          Icons.hourglass_top_rounded,
          null,
        );
      case VisionPhase.processing:
      case VisionPhase.done:
      case VisionPhase.aborted:
        primary = _bigButton(
          'Analysing…',
          Icons.hourglass_bottom_rounded,
          null,
        );
    }
    final canSkip =
        (p.perEye || p.kind == VisionTestKind.reaction) &&
        (phase == VisionPhase.idle ||
            phase == VisionPhase.running ||
            phase == VisionPhase.pausedDistance ||
            phase == VisionPhase.switchPart);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        if (canSkip)
          TextButton.icon(
            onPressed: r.skipPart,
            style: TextButton.styleFrom(
              foregroundColor: _dark ? Colors.white70 : const Color(0xFF475569),
              minimumSize: const Size(0, 40),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: Text(p.perEye ? 'Skip this eye' : 'Skip this block'),
          ),
      ],
    );
  }

  Widget _bigButton(String label, IconData icon, VoidCallback? onTap) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0B7A75),
        foregroundColor: Colors.white,
        disabledBackgroundColor: _dark
            ? Colors.white24
            : const Color(0xFFE2E8F0),
        disabledForegroundColor: _dark
            ? Colors.white70
            : const Color(0xFF64748B),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _testControls(VisionRunController r) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final o in VisionDemoOutcome.values)
          _testChip(
            'Outcome: ${o.name[0].toUpperCase()}${o.name.substring(1)}',
            _demoOutcome == o,
            () {
              setState(() {
                _demoOutcome = o;
                r.demoOutcome = o;
              });
            },
          ),
        _testChip(
          'Auto-answer (simulated)',
          r.autoRun,
          () => r.setAutoRun(!r.autoRun),
        ),
        if (p.kind == VisionTestKind.acuity && _distance != null) ...[
          _testChip('Simulate too close', _distance!.simulatedCm == 28, () {
            _distance!.simulatedCm = _distance!.simulatedCm == 28 ? null : 28;
          }),
          _testChip('Simulate too far', _distance!.simulatedCm == 55, () {
            _distance!.simulatedCm = _distance!.simulatedCm == 55 ? null : 55;
          }),
        ],
        Text(
          'scale: ${_metrics.source} · ${_metrics.dpi.toStringAsFixed(0)} dpi',
          style: TextStyle(
            color: _dark ? Colors.white70 : const Color(0xFF64748B),
            fontSize: 10.5,
          ),
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
      selectedColor: const Color(0xFF0B7A75).withValues(alpha: 0.25),
    );
  }

  Widget _glassButton(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    Color? tint,
  }) {
    final fg = _dark ? Colors.white : const Color(0xFF0F172A);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: fg.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: tint ?? fg),
          ),
        ),
      ),
    );
  }

  /// One-time 40 cm calibration for the camera distance (CAP-15 stand-in):
  /// the member holds the phone at a measured 40 cm and taps Calibrate.
  Future<void> _showCalibration() async {
    final appState = AppStateScope.of(context);
    final d = _distance;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Calibrate the distance check',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AnaemiaUi.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Measure 40 cm from your eyes to the screen with a tape (or a ruler), hold the phone there with your face in view, then tap Calibrate. This stores the camera\'s focal length for this phone so the live distance is exact (Spec §2 CAP-15, G-33).',
                style: TextStyle(
                  color: AnaemiaUi.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const VisionIllustrationView(
                    kind: VisionIllustration.tapeMeasure,
                    size: 64,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      d == null
                          ? 'Camera not running.'
                          : (d.lastEyeGapPx == null
                                ? 'Face not found yet — look at the camera.'
                                : 'Face found. Eye spacing ${d.lastEyeGapPx!.toStringAsFixed(0)} px.'),
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: d?.calibrationFocalPx() == null
                    ? null
                    : () {
                        final f = d!.calibrationFocalPx()!;
                        appState.setFocalLengthCalibration(f);
                        Navigator.pop(ctx);
                        _retake();
                      },
                icon: const Icon(Icons.straighten_rounded),
                label: const Text('Calibrate at 40 cm'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Without calibration the distance is estimated from a typical selfie camera and the result says so; the document\'s fallback is to hold the phone at a measured 40 cm.',
                style: TextStyle(
                  color: AnaemiaUi.muted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
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
