import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/breath_engines.dart';
import '../../core/domain/algorithms/breath_session_builder.dart';
import '../../core/domain/algorithms/hearing_engines.dart' show NoiseLevel;
import '../../core/domain/entities/breath_protocol.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/services/ambient_noise_service.dart';
import '../../core/services/breath_audio_service.dart';
import '../../core/services/mic_self_check_service.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'breath_illustrations.dart';
import 'breath_result_screen.dart';
import 'breath_run_controller.dart';
import 'breath_task_views.dart';

/// T-CAP flow for a Breathing & Voice check: Prepare (checklist + the
/// S-G01 audio readiness checks: microphone sweep G-17, room noise G-18,
/// body profile G-02) → How-to → Tasks → Analyse.
class BreathCaptureScreen extends StatefulWidget {
  const BreathCaptureScreen({
    super.key,
    required this.protocol,
    this.startAtHowTo = false,
    this.micResult,
    this.roomDba,
  });

  final BreathProtocol protocol;
  final bool startAtHowTo;

  /// Readiness outcome carried into a retake.
  final MicSelfCheckResult? micResult;
  final double? roomDba;

  @override
  State<BreathCaptureScreen> createState() => _BreathCaptureScreenState();
}

class _BreathCaptureScreenState extends State<BreathCaptureScreen> {
  static const _labels = ['Prepare', 'How-to', 'Test', 'Analyse'];
  static const int _testIdx = 2;
  static const int _analyseIdx = 3;

  BreathProtocol get p => widget.protocol;

  int _step = 0;
  final Set<int> _checked = {};
  bool _showTestControls = false;
  BreathDemoOutcome _demoOutcome = BreathDemoOutcome.normal;
  final int _retakes = 0;
  final TextEditingController _height = TextEditingController();

  BreathRunController? _run;
  AmbientNoiseService? _noise;
  MicSelfCheckService? _mic;
  BreathAudioService? _audio;
  VoiceCoachController? _voice;

  NoiseReading? _roomReading;
  double _noiseProgress = 0;
  bool _noiseChecking = false;
  MicSelfCheckResult? _micResult;
  bool _micManual = false;

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
    if (_noise == null) {
      _noise = AmbientNoiseService(
        micOffsetDba: appState.deviceProfile.micDbaOffset,
      )..addListener(_onServiceTick);
      _mic = MicSelfCheckService()..addListener(_onServiceTick);
      _audio = BreathAudioService();
      final h = appState.activeSubject.heightCm;
      _height.text = h == null ? '' : h.toStringAsFixed(0);
      if (widget.startAtHowTo) {
        // retake: keep this session's readiness outcome
        _micResult = widget.micResult?.copyWith(source: 'session');
        _micManual = widget.micResult?.manual ?? false;
        _roomReading = NoiseReading(
          dba: widget.roomDba ?? appState.deviceProfile.lastRoomNoiseDba,
          source: 'session',
        );
      }
    }
  }

  void _onServiceTick() {
    if (!mounted) return;
    if (_noiseChecking || (_mic?.running ?? false)) setState(() {});
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _run?.dispose();
    _noise?.removeListener(_onServiceTick);
    _noise?.dispose();
    _mic?.removeListener(_onServiceTick);
    _mic?.dispose();
    _audio?.dispose();
    _voice?.dispose();
    _height.dispose();
    _leaveImmersive();
    super.dispose();
  }

  void _say(String text, {VoiceCueTone tone = VoiceCueTone.ready}) {
    _voice?.announce(text, tone: tone, force: true);
  }

  Future<void> _sayAndWait(
    String text, {
    VoiceCueTone tone = VoiceCueTone.ready,
  }) => _voice?.announceAndWait(text, tone: tone) ?? Future<void>.value();

  // ---------------------------------------------------------------------
  // Prepare validation
  // ---------------------------------------------------------------------

  bool get _needsRoomCheck => p.requiredGates.contains(GateId.g18);
  bool get _needsMicCheck => p.requiredGates.contains(GateId.g17);
  bool get _roomOk => !_needsRoomCheck || (_roomReading?.passes ?? false);
  bool get _micOk => !_needsMicCheck || (_micResult?.passed ?? false);
  double? get _heightCm {
    final v = double.tryParse(_height.text.trim());
    if (v == null || v < 50 || v > 250) return null;
    return v;
  }

  bool get _prepareReady =>
      _checked.length >= p.prepareChecklist.length &&
      _micOk &&
      _roomOk &&
      (!p.needsBodyProfile || _heightCm != null);

  String? get _prepareHelper {
    if (_checked.length < p.prepareChecklist.length) {
      return 'Tick each item to continue';
    }
    if (_needsMicCheck && _micResult == null) {
      return 'Run the microphone check (G-17)';
    }
    if (!_micOk) {
      return 'Microphone check failed — fix and run it again, or confirm manually';
    }
    if (_needsRoomCheck && _roomReading == null) {
      return 'Run the 3-second room check (G-18)';
    }
    if (!_roomOk) {
      return 'Room too noisy — move somewhere quieter and check again';
    }
    if (p.needsBodyProfile && _heightCm == null) {
      return 'Enter height in cm (50–250) for the predicted values (G-02)';
    }
    return null;
  }

  Future<void> _checkMic() async {
    final m = _mic;
    if (m == null || m.running) return;
    final appState = AppStateScope.of(context);
    setState(() {
      _micResult = null;
      _micManual = false;
    });
    _say('Testing your microphone. Stay quiet.', tone: VoiceCueTone.scanning);
    final r = await m.run(
      baselineRel: appState.deviceProfile.micSweepProfileDb,
    );
    if (!mounted) return;
    if (r.profileRecorded) appState.setMicSweepProfile(r.bandsDb);
    appState.setMicSelfCheck(passed: r.passed);
    setState(() => _micResult = r);
    _say(
      r.passed ? 'Microphone ready.' : r.fixTip,
      tone: r.passed ? VoiceCueTone.completed : VoiceCueTone.warning,
    );
  }

  /// Fallback like the hearing earphone confirmation: the member vouches
  /// for the test sound and an uncovered mic; recorded as 'manual'.
  void _setMicManual(bool on) {
    final appState = AppStateScope.of(context);
    setState(() {
      _micManual = on;
      if (on) {
        _micResult = MicSelfCheckResult.manualConfirmation;
      } else if (_micResult?.manual ?? false) {
        _micResult = null;
      }
    });
    appState.setMicSelfCheck(passed: _micResult?.passed ?? false);
  }

  Future<void> _checkRoom() async {
    final n = _noise;
    if (n == null || _noiseChecking) return;
    setState(() {
      _noiseChecking = true;
      _noiseProgress = 0;
      _roomReading = null;
    });
    _say('Stay quiet for three seconds.', tone: VoiceCueTone.scanning);
    final r = await n.checkRoom(
      onProgress: (v) {
        if (mounted) setState(() => _noiseProgress = v);
      },
    );
    await n.stop();
    if (!mounted) return;
    AppStateScope.of(context).setRoomNoise(r.dba);
    setState(() {
      _noiseChecking = false;
      _roomReading = r;
    });
    _say(
      r.passes
          ? 'Room is quiet enough.'
          : 'Too noisy at ${r.dba.toStringAsFixed(0)} decibels. Move to a quieter room and check again.',
      tone: r.passes ? VoiceCueTone.completed : VoiceCueTone.warning,
    );
  }

  /// CAP-12 per-device offset [DER]: the member confirms this room is
  /// quiet, the current microphone level is defined as 35 dBA.
  Future<void> _calibrateRoom() async {
    final n = _noise;
    if (n == null) return;
    setState(() => _noiseChecking = true);
    await n.start();
    for (var i = 0; i < 8 && n.lastDbfs == null && !n.simulated; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final offset = n.simulated ? n.micOffsetDba : n.calibrateQuietRoom();
    await n.stop();
    if (!mounted) return;
    if (offset != null) {
      AppStateScope.of(context).setMicOffset(offset);
      AppStateScope.of(context).setRoomNoise(AmbientNoiseService.quietRoomDba);
    }
    setState(() {
      _noiseChecking = false;
      _roomReading = offset == null
          ? null
          : NoiseReading(
              dba: AmbientNoiseService.quietRoomDba,
              source: n.source,
            );
    });
    _say(
      offset == null
          ? 'No microphone reading yet. Try again.'
          : 'Calibrated. This room counts as thirty-five decibels.',
      tone: VoiceCueTone.completed,
    );
  }

  void _goHowTo() {
    final appState = AppStateScope.of(context);
    if (p.needsBodyProfile && _heightCm != null) {
      final subj = appState.activeSubject;
      if (subj.heightCm != _heightCm) {
        appState.updateActiveSubject(subj.copyWith(heightCm: _heightCm));
      }
    }
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

  // ---------------------------------------------------------------------
  // Test
  // ---------------------------------------------------------------------

  Future<void> _enterTest() async {
    final appState = AppStateScope.of(context);
    final subj = appState.activeSubject;
    _testStartedAt = DateTime.now();
    unawaited(_enterImmersive());
    _run?.dispose();
    _run = BreathRunController(
      protocol: p,
      prediction: SpirometryReference.predict(
        sex: subj.sex,
        heightCm: subj.heightCm ?? _heightCm ?? 165,
        ageYears: subj.ageYears,
      ),
      audio: _audio,
      demoOutcome: _demoOutcome,
      adult: subj.isAdult,
      micOffsetDba:
          appState.deviceProfile.micDbaOffset ?? NoiseLevel.defaultMicOffsetDba,
      onSpeak: (t, {warning = false}) => _sayAndWait(
        t,
        tone: warning ? VoiceCueTone.warning : VoiceCueTone.scanning,
      ),
    )..addListener(_onRunChanged);
    if (!mounted) return;
    setState(() => _step = _testIdx);
    _say(p.howTo.first.body, tone: VoiceCueTone.ready);
  }

  void _onRunChanged() {
    if (!mounted) return;
    if (_run!.phase == BreathPhase.processing) {
      _startAnalysis();
    } else {
      setState(() {});
    }
  }

  Future<void> _enterImmersive() async {
    if (BreathAudioService.isFlutterTestStatic) return;
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
    if (BreathAudioService.isFlutterTestStatic) return;
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
        (r.phase == BreathPhase.running || r.phase == BreathPhase.between);
    if (!running) {
      Navigator.of(context).maybePop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop the check?'),
        content: const Text('Recordings made so far are discarded.'),
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
    _say('Done. Analysing.', tone: VoiceCueTone.completed);
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
    final result = buildBreathSession(
      protocol: p,
      subject: appState.activeSubject,
      captures: run.captures,
      demoOutcome: _demoOutcome,
      history: appState.breathSessions,
      audioSource: (_audio?.simulated ?? true) ? 'simulated' : 'microphone',
      ambientDba: _roomReading?.dba,
      micCheck: _micResult,
      retakes: _retakes,
      simulated: run.autoRun || (_audio?.simulated ?? false),
      durationSeconds: _testStartedAt == null
          ? 0
          : DateTime.now().difference(_testStartedAt!).inSeconds,
    );
    _run?.dispose();
    _run = null;
    _leaveImmersive();
    final mic = _micResult;
    final room = _roomReading?.dba;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            BreathResultScreen(result: result, micResult: mic, roomDba: room),
      ),
    );
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
                  helper: _prepareHelper,
                  onPressed: _prepareReady ? _goHowTo : null,
                ),
                1 => PrimaryBottomButton(
                  label: 'Start',
                  icon: Icons.play_arrow_rounded,
                  helper:
                      '${p.tasks.length} step${p.tasks.length == 1 ? '' : 's'} · ${p.durationLabel}',
                  onPressed: _enterTest,
                ),
                _ => null,
              },
      ),
    );
  }

  // --- Prepare ---------------------------------------------------------------

  Widget _prepare() {
    final appState = AppStateScope.of(context);
    final subj = appState.activeSubject;
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
                  key: ValueKey('breath_check_$i'),
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
                  secondary: BreathIllustrationView(
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
        AnaemiaUi.sectionHeader(
          'Audio readiness · S-G01',
          'Microphone check (G-17) and room noise (G-18) before any audio task',
        ),
        if (_needsMicCheck) ...[
          _micCheckCard(appState.deviceProfile.micSweepProfileDb != null),
          const SizedBox(height: 10),
        ],
        if (_needsRoomCheck) ...[_roomCheckCard(), const SizedBox(height: 10)],
        if (p.needsBodyProfile) ...[
          AnaemiaUi.sectionHeader(
            'Body profile · G-02',
            'Height, age and sex give the predicted values (FRM-13)',
          ),
          _bodyProfileCard(subj.fullName, subj.ageYears, subj.sex.label),
        ],
      ],
    );
  }

  Widget _micCheckCard(bool hasProfile) {
    final m = _mic;
    final r = _micResult;
    final running = m?.running ?? false;
    final color = r == null
        ? AnaemiaUi.muted
        : r.passed
        ? (r.manual ? MirrorColors.warningFg : MirrorColors.successFg)
        : MirrorColors.warningFg;
    final String status;
    if (running) {
      status = 'Testing your microphone… stay quiet';
    } else if (r == null) {
      status = hasProfile
          ? 'Not run yet · compares with this phone\'s profile'
          : 'Not run yet · the first pass records this phone\'s profile';
    } else if (r.manual) {
      status = 'Confirmed by you (manual) — recorded as advisory';
    } else if (!r.passed) {
      status = !r.sweepHeard
          ? 'Failed: test sound not heard'
          : 'Failed: differs from this phone\'s profile by ${r.deviationDb.toStringAsFixed(1)} dB (limit 6)';
    } else if (r.comparedToProfile) {
      status =
          'Passed: matches this phone\'s profile within ${r.deviationDb.toStringAsFixed(1)} dB (limit 6)';
    } else if (r.source == 'session') {
      status = 'Passed earlier in this session';
    } else {
      status = 'Passed: test sound heard · profile recorded for this phone';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BreathIllustrationView(
                kind: BreathIllustration.micSweep,
                size: 56,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Microphone check · G-17',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      status,
                      key: const ValueKey('breath_mic_label'),
                      style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (running) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: m?.progress, minHeight: 6),
          ],
          if (r != null && !r.passed) ...[
            const SizedBox(height: 8),
            InfoNote(
              icon: Icons.build_outlined,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              text: r.fixTip,
            ),
          ],
          if (r != null && r.passed && r.processingDetected) ...[
            const SizedBox(height: 8),
            InfoNote(
              icon: Icons.info_outline_rounded,
              text:
                  'The level dropped during the test sound — phone audio processing may be active. If you can, turn off noise suppression / sound enhancements (advisory).',
            ),
          ],
          if (m?.permissionDenied ?? false) ...[
            const SizedBox(height: 6),
            const Text(
              'Microphone permission needed (G-12)',
              style: TextStyle(color: MirrorColors.warningFg, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            hasProfile
                ? 'The phone plays a 1.5 s sweep (100 Hz – 8 kHz) and records it. The response must match this phone\'s own profile within 6 dB (ALG-CAP-11): a covered or blocked microphone fails.'
                : 'The phone plays a 1.5 s sweep (100 Hz – 8 kHz) and records it. The first pass records this phone\'s response as its profile; later checks must match it within 6 dB (ALG-CAP-11).',
            style: const TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                key: const ValueKey('breath_mic_check'),
                onPressed: running ? null : _checkMic,
                child: Text(
                  r == null || r.manual
                      ? 'Check the microphone'
                      : 'Check again',
                ),
              ),
              if (m?.simulated ?? false)
                ChoiceChip(
                  key: const ValueKey('breath_mic_sim_fail'),
                  label: const Text(
                    'Simulate mic fail',
                    style: TextStyle(fontSize: 10.5),
                  ),
                  selected: m!.simulateFail,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) =>
                      setState(() => m.simulateFail = !m.simulateFail),
                ),
            ],
          ),
          if (r == null || !r.passed || r.manual) ...[
            const SizedBox(height: 4),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                key: const ValueKey('breath_mic_manual'),
                value: _micManual,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: running ? null : (v) => _setMicManual(v ?? false),
                title: const Text(
                  'I can hear the test sound and nothing covers the microphone — continue (recorded as a manual check)',
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _roomCheckCard() {
    final r = _roomReading;
    final live = _noise?.currentDba;
    final shown = _noiseChecking ? live : r?.dba;
    final color = r == null
        ? AnaemiaUi.muted
        : r.passes
        ? MirrorColors.successFg
        : MirrorColors.warningFg;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(Icons.mic_rounded, color, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Room noise · G-18',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _noiseChecking
                          ? 'Stay quiet… ${shown?.toStringAsFixed(0) ?? '—'} dBA'
                          : r == null
                          ? 'Not checked yet · limit 45 dBA'
                          : r.passes
                          ? 'Quiet enough: ${r.dba.toStringAsFixed(0)} dBA (limit 45)'
                          : 'Too noisy: ${r.dba.toStringAsFixed(0)} dBA — move to a quieter room',
                      key: const ValueKey('breath_room_label'),
                      style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RangeGauge(
            scale: const RangeScale(
              breakpoints: [20, 45, 60, 80],
              labels: ['≤ 45 quiet', '46–60 noisy', '> 60 loud'],
              colors: [
                AnaemiaUi.segNormal,
                AnaemiaUi.segBorder,
                AnaemiaUi.segHigh,
              ],
            ),
            value: (shown ?? 20).clamp(20, 80),
            pinColor: color,
          ),
          if (_noiseChecking) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _noiseProgress, minHeight: 6),
          ],
          const SizedBox(height: 6),
          Text(
            'Microphone: ${_noise?.lastDbfs == null ? 'no reading yet' : '${_noise!.lastDbfs!.toStringAsFixed(0)} dBFS'} · offset ${(_noise?.micOffsetDba ?? 0).toStringAsFixed(0)} dB (per-phone, CAP-12). If a silent room reads above 45, tap Calibrate.',
            style: const TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                key: const ValueKey('breath_noise_check'),
                onPressed: _noiseChecking ? null : _checkRoom,
                child: Text(
                  r == null ? 'Check the room (3 s)' : 'Check again (3 s)',
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('breath_noise_calibrate'),
                onPressed: _noiseChecking ? null : _calibrateRoom,
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Reads too high? Calibrate here'),
              ),
              if (_noise?.permissionDenied ?? false)
                const SizedBox(
                  width: 220,
                  child: Text(
                    'Microphone permission needed (G-12)',
                    style: TextStyle(
                      color: MirrorColors.warningFg,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bodyProfileCard(String name, int age, String sex) => Container(
    padding: const EdgeInsets.all(12),
    decoration: AnaemiaUi.card(),
    child: Row(
      children: [
        const BreathIllustrationView(
          kind: BreathIllustration.bodyProfile,
          size: 56,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name · $age y · $sex',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AnaemiaUi.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _heightCm == null
                    ? 'Height in cm is needed for % predicted (G-02)'
                    : age < SpirometryReference.minAge ||
                          age > SpirometryReference.maxAge
                    ? 'Reference equations cover 18–70 y; values shown with a warning'
                    : 'Predicted FEV1 / FVC / ratio from height, age and sex',
                style: const TextStyle(
                  color: AnaemiaUi.muted,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: TextField(
            key: const ValueKey('breath_height'),
            controller: _height,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              suffixText: 'cm',
              suffixStyle: TextStyle(fontSize: 11, color: AnaemiaUi.muted),
              hintText: '165',
            ),
          ),
        ),
      ],
    ),
  );

  // --- How-to ----------------------------------------------------------------

  Widget _howTo() {
    return ListView(
      key: const ValueKey('howto'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          'Step 2 · How to do the check',
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
                  child: BreathIllustrationView(
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
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AnaemiaUi.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The steps, in order',
                style: TextStyle(
                  color: AnaemiaUi.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < p.tasks.length; i++)
                AnaemiaUi.bullet(
                  '${i + 1}. ${p.tasks[i].title} — ${p.tasks[i].brief?.stopsWhen ?? p.tasks[i].instruction}',
                  icon: Icons.arrow_right_alt_rounded,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AnaemiaUi.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What you get from this check',
                style: TextStyle(
                  color: AnaemiaUi.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              for (final line in p.whatYouGet)
                AnaemiaUi.bullet(
                  line,
                  icon: Icons.check_circle_outline_rounded,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (p.kind == BreathKind.voice) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AnaemiaUi.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The sentence',
                  style: TextStyle(
                    color: AnaemiaUi.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  BreathTexts.voiceSentence,
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        InfoNote(icon: Icons.rule_rounded, text: p.retryNote),
      ],
    );
  }

  // --- Test (immersive) ------------------------------------------------------

  Widget _testBody() {
    final r = _run;
    if (r == null) return const SizedBox.shrink();
    const fg = Colors.white;
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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

  Widget _visual(BreathRunController r) {
    if (r.phase == BreathPhase.idle) return _idleCard(r);
    if (r.phase == BreathPhase.between) return _betweenCard(r);
    switch (r.currentTask.type) {
      case BreathTaskType.questionnaire:
        return BreathQuestionView(run: r);
      case BreathTaskType.cough:
        return CoughTaskView(run: r);
      case BreathTaskType.phonation:
        return PhonationTaskView(run: r);
      case BreathTaskType.breathSounds:
        return BreathSoundsTaskView(run: r);
      case BreathTaskType.forcedExhale:
        return ExhaleTaskView(run: r);
    }
  }

  Widget _idleCard(BreathRunController r) => BreathTaskBriefCard(
    task: r.currentTask,
    title: r.currentTask.title,
    subtitle: 'Step 1 of ${r.taskCount} · tap Start when ready',
  );

  Widget _betweenCard(BreathRunController r) {
    final t = r.currentTask;
    if (r.retryMessage != null) {
      return BreathTaskBriefCard(
        task: t,
        title: 'Let\'s try that again',
        subtitle: r.retryMessage,
        extra: FilledButton.icon(
          key: const ValueKey('breath_retry'),
          onPressed: r.retryTask,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Try again'),
        ),
      );
    }
    if (t.type == BreathTaskType.forcedExhale && r.efforts.isNotEmpty) {
      return BreathTaskBriefCard(
        task: t,
        title: 'Blow ${r.efforts.length} done',
        subtitle: r.coaching,
        extra: ExhaleEffortsStrip(run: r),
      );
    }
    return BreathTaskBriefCard(
      task: t,
      title: 'Next: ${t.title}',
      subtitle:
          'Step ${r.taskIndex + 1} of ${r.taskCount} · tap Start when ready',
    );
  }

  Widget _dock(BreathRunController r) {
    final (headline, support) = _statusLines(r);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
              AnaemiaUi.iconTile(_icon(r), const Color(0xFF0B7A75), size: 44),
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
                        color: Colors.white.withValues(alpha: 0.75),
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

  IconData _icon(BreathRunController r) => switch (r.currentTask.type) {
    BreathTaskType.questionnaire => Icons.checklist_rounded,
    BreathTaskType.cough => Icons.sick_outlined,
    BreathTaskType.phonation => Icons.graphic_eq_rounded,
    BreathTaskType.breathSounds => Icons.air_rounded,
    BreathTaskType.forcedExhale => Icons.speed_rounded,
  };

  (String, String) _statusLines(BreathRunController r) {
    switch (r.phase) {
      case BreathPhase.idle:
        return ('Ready?', 'Tap Start when you are set.');
      case BreathPhase.running:
        return (
          r.currentTask.title,
          r.coaching.isEmpty ? r.currentTask.instruction : r.coaching,
        );
      case BreathPhase.between:
        return (
          r.retryMessage != null
              ? 'Try again'
              : r.currentTask.type == BreathTaskType.forcedExhale &&
                    r.efforts.isNotEmpty
              ? (r.resting
                    ? 'Rest ${r.restLeftS.toStringAsFixed(0)} s, then blow ${r.effortNumber}'
                    : 'Ready for blow ${r.effortNumber}')
              : 'Next step',
          r.coaching,
        );
      case BreathPhase.processing:
      case BreathPhase.aborted:
        return ('Done', 'Analysing your recordings…');
    }
  }

  Widget _buttons(BreathRunController r) {
    Widget primary;
    switch (r.phase) {
      case BreathPhase.idle:
        primary = _bigButton('Start', Icons.play_arrow_rounded, r.start);
      case BreathPhase.between:
        primary = r.retryMessage != null
            ? _bigButton('Try again', Icons.replay_rounded, r.retryTask)
            : r.currentTask.type == BreathTaskType.forcedExhale &&
                  r.efforts.isNotEmpty
            ? _bigButton(
                r.resting
                    ? 'Skip rest — blow ${r.effortNumber} now'
                    : 'Blow ${r.effortNumber} — ready',
                Icons.play_arrow_rounded,
                r.start,
              )
            : _bigButton(
                'Start ${r.currentTask.title.toLowerCase()}',
                Icons.play_arrow_rounded,
                r.start,
              );
      case BreathPhase.running:
        primary = _bigButton(
          switch (r.currentTask.type) {
            BreathTaskType.questionnaire => 'Answer above',
            BreathTaskType.forcedExhale =>
              r.countdown > 0 ? 'Breathe in…' : 'Blowing…',
            _ => 'Listening…',
          },
          Icons.hourglass_top_rounded,
          null,
        );
      case BreathPhase.processing:
      case BreathPhase.aborted:
        primary = _bigButton(
          'Analysing…',
          Icons.hourglass_bottom_rounded,
          null,
        );
    }
    final canSkip =
        p.tasks.length > 1 &&
        r.currentTask.type != BreathTaskType.questionnaire &&
        (r.phase == BreathPhase.idle ||
            r.phase == BreathPhase.running ||
            r.phase == BreathPhase.between);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        if (canSkip)
          TextButton.icon(
            key: const ValueKey('breath_skip'),
            onPressed: r.skipTask,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              minimumSize: const Size(0, 40),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: const Text('Skip this step'),
          ),
      ],
    );
  }

  Widget _bigButton(String label, IconData icon, VoidCallback? onTap) =>
      FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0B7A75),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white24,
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );

  Widget _testControls(BreathRunController r) => Wrap(
    spacing: 6,
    runSpacing: 6,
    alignment: WrapAlignment.center,
    children: [
      for (final o in BreathDemoOutcome.values)
        _testChip(
          'Outcome: ${o.name[0].toUpperCase()}${o.name.substring(1)}',
          _demoOutcome == o,
          () => setState(() {
            _demoOutcome = o;
            r.demoOutcome = o;
          }),
        ),
      _testChip(
        'Auto-run (simulated)',
        r.autoRun,
        () => r.setAutoRun(!r.autoRun),
      ),
      if (p.tasks.any((t) => t.type == BreathTaskType.cough))
        _testChip(
          'Simulate few coughs',
          r.simulateFewCoughs,
          () => setState(() => r.simulateFewCoughs = !r.simulateFewCoughs),
        ),
      if (p.tasks.any((t) => t.efforts > 1))
        _testChip(
          'Simulate unrepeatable blows',
          r.simulateUnrepeatable,
          () =>
              setState(() => r.simulateUnrepeatable = !r.simulateUnrepeatable),
        ),
      _testChip(
        'Simulate clipping',
        r.simulateClipping,
        () => setState(() => r.simulateClipping = !r.simulateClipping),
      ),
      Text(
        'mic ${_audio?.source ?? '—'} · room ${_roomReading?.dba.toStringAsFixed(0) ?? '—'} dBA · sweep ${_micResult == null
            ? '—'
            : _micResult!.manual
            ? 'manual'
            : '${_micResult!.deviationDb.toStringAsFixed(1)} dB'}',
        style: const TextStyle(color: Colors.white70, fontSize: 10.5),
      ),
    ],
  );

  Widget _testChip(String label, bool selected, VoidCallback onTap) =>
      ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 10.5)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        selectedColor: const Color(0xFF0B7A75).withValues(alpha: 0.25),
      );

  Widget _glassButton(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    Color? tint,
  }) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white.withValues(alpha: 0.10),
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
          '${p.algorithmLabel} on-device · $elapsed s so far',
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
