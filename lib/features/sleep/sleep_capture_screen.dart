import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/breath_engines.dart'
    show MicSelfCheckResult;
import '../../core/domain/algorithms/sleep_engines.dart';
import '../../core/domain/algorithms/sleep_session_builder.dart';
import '../../core/domain/entities/sleep_protocol.dart';
import '../../core/domain/entities/sleep_result.dart';
import '../../core/services/audio_route_service.dart';
import '../../core/services/mic_self_check_service.dart';
import '../../core/services/screen_brightness_service.dart';
import '../../core/services/sleep_device_service.dart';
import '../../core/services/sleep_sonar_service.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'sleep_illustrations.dart';
import 'sleep_night_views.dart';
import 'sleep_result_screen.dart';
import 'sleep_run_controller.dart';

/// Overnight flow: S-G07 Set up (checklist + live checks: microphone
/// CAP-11, sonar echo, charger G-30, Do-not-disturb, volume, notification)
/// → How-to → S-G08 Night (dark clock, long-press Stop) → Report
/// (analysis stages → S-G09).
class SleepCaptureScreen extends StatefulWidget {
  const SleepCaptureScreen({
    super.key,
    this.protocol = SleepProtocols.sonar,
    this.startAtHowTo = false,
  });

  final SleepProtocol protocol;
  final bool startAtHowTo;

  @override
  State<SleepCaptureScreen> createState() => _SleepCaptureScreenState();
}

class _SleepCaptureScreenState extends State<SleepCaptureScreen> {
  static const _labels = ['Set up', 'How-to', 'Night', 'Report'];
  static const int _nightIdx = 2;
  static const int _analyseIdx = 3;

  SleepProtocol get p => widget.protocol;

  int _step = 0;
  final Set<int> _checked = {};
  bool _showTestControls = false;
  bool _showLive = false;
  bool _controlsRevealed = true;
  SleepDemoOutcome _demoOutcome = SleepDemoOutcome.normal;

  VoiceCoachController? _voice;
  MicSelfCheckService? _mic;
  SleepSonarService? _sonar;
  SleepDeviceService? _device;
  AudioRouteService? _route;
  SleepRunController? _run;

  MicSelfCheckResult? _micResult;
  bool _micManual = false;
  SonarCheckResult? _sonarResult;
  bool _sonarChecking = false;
  double _sonarProgress = 0;
  bool _sonarWarningAccepted = false;
  BatteryStatus? _battery;
  Timer? _batteryTimer;
  bool? _dnd;
  bool? _notificationAllowed;
  bool _volumeSet = false;
  bool _keepAlive = false;

  int _analysisStage = 0;
  Timer? _analysisTimer;
  Timer? _stopHold;
  double _stopProgress = 0;
  bool _stopping = false;

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
    if (_sonar == null) {
      _mic = MicSelfCheckService()..addListener(_onServiceTick);
      _sonar = SleepSonarService();
      _device = SleepDeviceService();
      _route = AudioRouteService();
      _pollBattery();
      _batteryTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pollBattery(),
      );
      unawaited(_readDnd());
      if (widget.startAtHowTo) {
        // retake: the readiness checks of this session stand
        _micResult = MicSelfCheckResult.manualConfirmation;
        _micManual = true;
        _sonarResult = const SonarCheckResult(
          passed: true,
          echoDb: -45,
          floorDb: -80,
          source: 'session',
        );
        _volumeSet = true;
        for (var i = 0; i < p.prepareChecklist.length; i++) {
          _checked.add(i);
        }
      }
    }
  }

  void _onServiceTick() {
    if (!mounted) return;
    if (_mic?.running ?? false) setState(() {});
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _batteryTimer?.cancel();
    _stopHold?.cancel();
    _run?.dispose();
    _mic?.removeListener(_onServiceTick);
    _mic?.dispose();
    _sonar?.dispose();
    _voice?.dispose();
    unawaited(_device?.stopKeepAlive());
    _leaveNightMode();
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
  // Set up: live checks
  // ---------------------------------------------------------------------

  Future<void> _pollBattery() async {
    final d = _device;
    if (d == null) return;
    final b = await d.battery();
    if (!mounted) return;
    final changed = _battery?.charging != b.charging;
    setState(() => _battery = b);
    if (changed || _battery == null) {
      AppStateScope.of(context).setPhoneCharging(b.charging);
    }
  }

  Future<void> _readDnd() async {
    final v = await _device?.dndActive();
    if (mounted) setState(() => _dnd = v);
  }

  bool get _charging => _battery?.charging ?? false;
  bool get _micOk => _micResult?.passed ?? false;
  bool get _sonarOk =>
      _sonarResult != null && (_sonarResult!.passed || _sonarWarningAccepted);

  bool get _prepareReady =>
      _checked.length >= p.prepareChecklist.length &&
      _micOk &&
      _sonarOk &&
      _charging;

  String? get _prepareHelper {
    if (_checked.length < p.prepareChecklist.length) {
      return 'Tick each item to continue';
    }
    if (_micResult == null) return 'Run the microphone check (CAP-11 / G-17)';
    if (!_micOk) {
      return 'Microphone check failed — fix and run it again, or confirm manually';
    }
    if (_sonarResult == null) return 'Run the 10-second sonar echo check';
    if (!_sonarOk) {
      return 'Sonar echo weak — raise the volume and check again, or accept the warning';
    }
    if (!_charging) return 'Plug the charger in to start the night (G-30)';
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

  Future<void> _checkSonar() async {
    final s = _sonar;
    if (s == null || _sonarChecking) return;
    setState(() {
      _sonarChecking = true;
      _sonarProgress = 0;
      _sonarResult = null;
      _sonarWarningAccepted = false;
    });
    if (!_volumeSet) await _setVolume();
    _say(
      'Checking the sonar echo. Keep the phone on the table for ten seconds.',
      tone: VoiceCueTone.scanning,
    );
    final r = await s.sonarCheck(
      onProgress: (v) {
        if (mounted) setState(() => _sonarProgress = v);
      },
    );
    if (!mounted) return;
    setState(() {
      _sonarChecking = false;
      _sonarResult = r;
    });
    _say(
      r.passed
          ? 'Sonar echo is strong. Ready for the night.'
          : 'The sonar echo is weak on this phone. You can still start; the breathing rate may be less reliable.',
      tone: r.passed ? VoiceCueTone.completed : VoiceCueTone.warning,
    );
  }

  Future<void> _setVolume() async {
    final ok = await _route?.setVolumeFraction(0.7) ?? false;
    if (!mounted) return;
    setState(() => _volumeSet = ok || (_route?.simulated ?? false));
  }

  Future<void> _requestNotification() async {
    final v = await _device?.requestNotificationPermission();
    if (mounted) setState(() => _notificationAllowed = v);
  }

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

  // ---------------------------------------------------------------------
  // Night
  // ---------------------------------------------------------------------

  Future<void> _enterNight() async {
    final d = _device!;
    _notificationAllowed ??= await d.requestNotificationPermission();
    _keepAlive = await d.startKeepAlive();
    unawaited(_enterNightMode());
    _run?.dispose();
    _run = SleepRunController(
      protocol: p,
      sonar: _sonar!,
      device: d,
      demoOutcome: _demoOutcome,
      floorDb: _sonar!.floorDb,
      onSpeak: (t, {warning = false}) => _sayAndWait(
        t,
        tone: warning ? VoiceCueTone.warning : VoiceCueTone.scanning,
      ),
    )..addListener(_onRunChanged);
    if (!mounted) return;
    setState(() {
      _step = _nightIdx;
      _controlsRevealed = true;
    });
    _say(
      '${p.whatToDo.join('. ')}. Tap Start when the phone is in place.',
      tone: VoiceCueTone.ready,
    );
  }

  Future<void> _startNight() async {
    final r = _run;
    if (r == null) return;
    r.demoOutcome = _demoOutcome;
    final ok = await r.start();
    if (!mounted) return;
    setState(() => _controlsRevealed = false);
    if (!ok) {
      _say(r.coaching, tone: VoiceCueTone.warning);
    }
  }

  void _onRunChanged() {
    if (!mounted) return;
    if (_run!.phase == SleepPhase.processing) {
      _startAnalysis();
    } else {
      setState(() {});
    }
  }

  Future<void> _enterNightMode() async {
    if (SleepSonarService.isFlutterTestStatic) return;
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } catch (_) {}
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    unawaited(ScreenBrightnessService.instance.dimForNight());
  }

  void _leaveNightMode() {
    if (SleepSonarService.isFlutterTestStatic) return;
    try {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } catch (_) {}
    try {
      WakelockPlus.disable();
    } catch (_) {}
    unawaited(ScreenBrightnessService.instance.restore());
  }

  Future<void> _confirmLeave() async {
    final r = _run;
    if (r == null || !r.isNight) {
      Navigator.of(context).maybePop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave without a report?'),
        content: const Text(
          'The night so far is discarded. To keep it, go back and hold Stop instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep monitoring'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      await r.abort();
      await _device?.stopKeepAlive();
      if (mounted) Navigator.of(context).pop();
    }
  }

  // long-press Stop (Doc 05 S-G08: avoid accidental taps)
  void _stopHoldStart() {
    _stopHold?.cancel();
    var ticks = 0;
    setState(() => _stopProgress = 0.02);
    _stopHold = Timer.periodic(const Duration(milliseconds: 100), (t) {
      ticks++;
      if (!mounted) return;
      setState(() => _stopProgress = (ticks / 15).clamp(0.0, 1.0));
      if (ticks >= 15) {
        t.cancel();
        _stopHold = null;
        setState(() => _stopProgress = 0);
        unawaited(_requestStop());
      }
    });
  }

  void _stopHoldCancel() {
    _stopHold?.cancel();
    _stopHold = null;
    if (mounted && _stopProgress > 0) setState(() => _stopProgress = 0);
  }

  Future<void> _requestStop() async {
    final r = _run;
    if (r == null || !r.isNight || _stopping) return;
    _stopping = true;
    try {
      if (!r.enoughForAhi) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Stop now?'),
            content: Text(
              'Not enough sleep recorded for apnoea estimate — ${r.validSleepH.toStringAsFixed(1)} h valid so far (4 h needed). Breathing rate will still be shown.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep monitoring'),
              ),
              FilledButton(
                key: const ValueKey('sleep_stop_confirm'),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Stop'),
              ),
            ],
          ),
        );
        if (go != true || !mounted) return;
      }
      await r.stop();
    } finally {
      _stopping = false;
    }
  }

  void _startAnalysis() {
    if (_step == _analyseIdx) return;
    unawaited(_device?.stopKeepAlive());
    _leaveNightMode();
    setState(() {
      _step = _analyseIdx;
      _analysisStage = 0;
    });
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
    final s = _sonar!;
    final quality = SleepQualityFacts(
      audioSource: s.source,
      sampleRate: SleepSonarService.sampleRate,
      chirpPlayed: s.chirpPlayed,
      sonarCheckPassed: _sonarResult?.passed,
      sonarCheckDb: _sonarResult?.aboveFloorDb,
      micSelfCheckPassed: _micResult?.passed,
      micDeviationDb: _micResult?.manual ?? true
          ? null
          : _micResult?.deviationDb,
      chargingAtStart: run.chargingAtStart,
      unpluggedSeconds: run.unpluggedS,
      invalidEpochs: run.epochs.length - run.validEpochs,
      totalEpochs: run.epochs.length,
      interruptions: run.interruptions,
      keepAliveUsed: _keepAlive,
      notificationAllowed: _notificationAllowed,
      dndOn: _dnd,
      snoreFraction: const SnoreDetector().nightFraction(run.epochs),
      stopReason: run.stopReason,
      simulated: s.simulated,
    );
    final result = buildSleepSession(
      protocol: p,
      subject: appState.activeSubject,
      epochs: run.epochs,
      events: run.events,
      startedAt: run.startedAt ?? DateTime.now(),
      endedAt: run.endedAt ?? DateTime.now(),
      quality: quality,
      demoOutcome: _demoOutcome,
      history: appState.sleepSessions,
    );
    _run?.dispose();
    _run = null;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SleepResultScreen(result: result),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final night = _step == _nightIdx;
    return PopScope(
      canPop: !night,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: night ? Colors.black : MirrorColors.backgroundLight,
        appBar: night
            ? null
            : AppBar(
                title: Text(p.title),
                actions: [
                  IconButton(
                    tooltip: 'Screen spec & gates (${p.setupScreenId})',
                    icon: const Icon(Icons.info_outline_rounded),
                    onPressed: () =>
                        showScreenGateLifecycleSheet(context, p.setupScreenId),
                  ),
                ],
              ),
        body: night
            ? _nightBody()
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
        bottomNavigationBar: night
            ? null
            : switch (_step) {
                0 => PrimaryBottomButton(
                  label: 'Continue',
                  helper: _prepareHelper,
                  onPressed: _prepareReady ? _goHowTo : null,
                ),
                1 => PrimaryBottomButton(
                  label: 'Start sleep monitoring',
                  icon: Icons.bedtime_rounded,
                  helper: '${p.howTo.length} steps · ${p.durationLabel}',
                  onPressed: _enterNight,
                ),
                _ => null,
              },
      ),
    );
  }

  // --- Set up ----------------------------------------------------------------

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
                  key: ValueKey('sleep_check_$i'),
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
                  secondary: SleepIllustrationView(
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
        const SizedBox(height: 10),
        InfoNote(text: p.setupHint, icon: Icons.lightbulb_outline_rounded),
        const SizedBox(height: 16),
        AnaemiaUi.sectionHeader(
          'Live checks · ${p.setupScreenId}',
          'Microphone (CAP-11), sonar echo, charger (G-30), quiet night',
        ),
        _micCheckCard(),
        const SizedBox(height: 10),
        _sonarCheckCard(),
        const SizedBox(height: 10),
        _chargerCard(),
        const SizedBox(height: 10),
        _quietNightCard(),
      ],
    );
  }

  Widget _micCheckCard() {
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
      status = 'Not run yet · 1.5 s sweep through the speaker';
    } else if (r.manual) {
      status = 'Confirmed by you (manual) — recorded as advisory';
    } else if (!r.passed) {
      status = !r.sweepHeard
          ? 'Failed: test sound not heard'
          : 'Failed: differs from this phone\'s profile by ${r.deviationDb.toStringAsFixed(1)} dB (limit 6)';
    } else {
      status = 'Passed: microphone and speaker respond normally';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SleepIllustrationView(
                kind: SleepIllustration.micSweep,
                size: 56,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Microphone check · CAP-11 / G-17',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      status,
                      key: const ValueKey('sleep_mic_label'),
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
          if (m?.permissionDenied ?? false) ...[
            const SizedBox(height: 6),
            const Text(
              'Microphone permission needed (G-12)',
              style: TextStyle(color: MirrorColors.warningFg, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                key: const ValueKey('sleep_mic_check'),
                onPressed: running ? null : _checkMic,
                child: Text(
                  r == null || r.manual
                      ? 'Check the microphone'
                      : 'Check again',
                ),
              ),
              if (m?.simulated ?? false)
                ChoiceChip(
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
                key: const ValueKey('sleep_mic_manual'),
                value: _micManual,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: running ? null : (v) => _setMicManual(v ?? false),
                title: const Text(
                  'I can hear the test sound and nothing covers the microphone — continue (manual check)',
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

  Widget _sonarCheckCard() {
    final r = _sonarResult;
    final s = _sonar;
    final color = r == null
        ? AnaemiaUi.muted
        : r.passed
        ? MirrorColors.successFg
        : MirrorColors.warningFg;
    final String status;
    if (_sonarChecking) {
      status = _sonarProgress < 0.4
          ? 'Listening to the room…'
          : 'Playing the inaudible chirp… ${(_sonarProgress * 100).round()} %';
    } else if (r == null) {
      status = 'Not run yet · 10 s, phone on the table';
    } else if (r.passed) {
      status =
          'Echo strong: ${r.aboveFloorDb.toStringAsFixed(0)} dB above the floor (needs ≥ 15)';
    } else {
      status =
          'Weak echo: ${r.aboveFloorDb.toStringAsFixed(0)} dB above the floor (needs ≥ 15)';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SleepIllustrationView(
                kind: SleepIllustration.sonarWaves,
                size: 56,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sonar echo check · AUD-07',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      status,
                      key: const ValueKey('sleep_sonar_label'),
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
          if (_sonarChecking) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _sonarProgress, minHeight: 6),
          ],
          if (r != null && !r.passed) ...[
            const SizedBox(height: 8),
            InfoNote(
              icon: Icons.warning_amber_rounded,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              text: r.note.isEmpty
                  ? 'This phone\'s speaker / microphone pair carries little 18–20 kHz. You can still start; the breathing rate may be invalid and the result shows lower confidence.'
                  : r.note,
            ),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                key: const ValueKey('sleep_sonar_accept'),
                value: _sonarWarningAccepted,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) =>
                    setState(() => _sonarWarningAccepted = v ?? false),
                title: const Text(
                  'I understand — start anyway with the warning recorded',
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'The phone listens for 2 s, then plays the 18–20 kHz chirp for 5 s and measures how much comes back. Media volume is set to 70 % first; keep the speaker and microphone uncovered.',
            style: TextStyle(
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
                key: const ValueKey('sleep_sonar_check'),
                onPressed: _sonarChecking ? null : _checkSonar,
                child: Text(r == null ? 'Check the sonar echo' : 'Check again'),
              ),
              if (s?.simulated ?? false)
                ChoiceChip(
                  key: const ValueKey('sleep_sonar_sim_fail'),
                  label: const Text(
                    'Simulate weak echo',
                    style: TextStyle(fontSize: 10.5),
                  ),
                  selected: s!.simulateSonarFail,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(
                    () => s.simulateSonarFail = !s.simulateSonarFail,
                  ),
                ),
              AnaemiaUi.tag(
                _volumeSet ? 'Volume set to 70 %' : 'Volume not set yet',
                color: _volumeSet ? MirrorColors.successFg : AnaemiaUi.muted,
                icon: Icons.volume_up_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chargerCard() {
    final b = _battery;
    final d = _device;
    final ok = b?.charging ?? false;
    final color = b == null
        ? AnaemiaUi.muted
        : ok
        ? MirrorColors.successFg
        : MirrorColors.dangerFg;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SleepIllustrationView(
                kind: SleepIllustration.charger,
                size: 56,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Charger · G-30',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      b == null
                          ? 'Reading the battery…'
                          : ok
                          ? 'Charging${b.levelPct >= 0 ? ' · ${b.levelPct} %' : ''} — checked every 5 s all night'
                          : 'Not charging${b.levelPct >= 0 ? ' · ${b.levelPct} %' : ''} — plug the charger in to start',
                      key: const ValueKey('sleep_charger_label'),
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
          const SizedBox(height: 6),
          const Text(
            'The night needs 4 hours or more; the sonar and the screen use power, so the phone must stay plugged in. If the charger comes out during the night the screen warns you and the minutes are noted on the report.',
            style: TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
          if (d?.simulated ?? false) ...[
            const SizedBox(height: 8),
            ChoiceChip(
              key: const ValueKey('sleep_sim_unplugged'),
              label: const Text(
                'Simulate unplugged',
                style: TextStyle(fontSize: 10.5),
              ),
              selected: !(d!.simulatedCharging),
              visualDensity: VisualDensity.compact,
              onSelected: (_) {
                d.simulatedCharging = !d.simulatedCharging;
                _pollBattery();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _quietNightCard() {
    final dnd = _dnd;
    final notif = _notificationAllowed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SleepIllustrationView(
                kind: SleepIllustration.doNotDisturb,
                size: 56,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quiet night · screen off allowed',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      dnd == null
                          ? 'Do-not-disturb: not readable on this device — switch it on yourself'
                          : dnd
                          ? 'Do-not-disturb is on'
                          : 'Do-not-disturb is off — turn it on so calls do not interrupt the night',
                      key: const ValueKey('sleep_dnd_label'),
                      style: TextStyle(
                        color: dnd == true
                            ? MirrorColors.successFg
                            : MirrorColors.warningFg,
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _readDnd,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Re-check'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('sleep_notification'),
                onPressed: notif == true ? null : _requestNotification,
                icon: const Icon(Icons.notifications_active_outlined, size: 16),
                label: Text(
                  notif == true
                      ? 'Notification allowed'
                      : notif == false
                      ? 'Allow the notification'
                      : 'Allow the night notification',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            notif == false
                ? 'Without the notification the phone cannot keep recording with the screen off; keep the night screen on instead (it dims to its lowest).'
                : 'A small "Sleep monitoring running" notification keeps the recording alive when you press the power button (FR-232). Optional — the dimmed night screen works too.',
            style: const TextStyle(
              color: AnaemiaUi.muted,
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // --- How-to ----------------------------------------------------------------

  Widget _howTo() {
    return ListView(
      key: const ValueKey('howto'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          'Step 2 · How the night works',
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
                  child: SleepIllustrationView(
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
        InfoNote(
          icon: Icons.rule_rounded,
          text:
              'Under 4 hours of clear echo the report shows the breathing rate only and asks you to repeat the night (E-AUD-003). Moderate or severe results open a COND_OSA case with a Routine referral.',
        ),
      ],
    );
  }

  // --- Night (immersive) ------------------------------------------------------

  Widget _nightBody() {
    final r = _run;
    if (r == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (r.isNight) setState(() => _controlsRevealed = !_controlsRevealed);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (r.phase == SleepPhase.idle || r.phase == SleepPhase.stopped)
            SleepReadyView(protocol: p, run: r)
          else
            SleepNightClockView(
              run: r,
              showLive: _showLive,
              keepAlive: _keepAlive,
            ),
          AnimatedOpacity(
            opacity: _controlsRevealed ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_controlsRevealed,
              child: Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: Row(
                      children: [
                        _glassButton(
                          Icons.close_rounded,
                          'Leave',
                          _confirmLeave,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                r.isNight
                                    ? 'Sleep monitoring'
                                    : 'Ready for the night',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Step 3 of 4 · ${p.nightScreenId}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _glassButton(
                          _showLive
                              ? Icons.monitor_heart_rounded
                              : Icons.monitor_heart_outlined,
                          'Live breathing',
                          () => setState(() => _showLive = !_showLive),
                          tint: _showLive ? const Color(0xFF0B7A75) : null,
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
                          () => setState(
                            () => _showTestControls = !_showTestControls,
                          ),
                          tint: _showTestControls
                              ? const Color(0xFF0B7A75)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _controlsRevealed || !r.isNight
                    ? _dock(r)
                    : Padding(
                        key: const ValueKey('sleep_tap_hint'),
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          'Tap the screen for controls',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dock(SleepRunController r) {
    final (headline, support) = _statusLines(r);
    return Container(
      key: const ValueKey('sleep_dock'),
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
              AnaemiaUi.iconTile(_icon(r), const Color(0xFF0B7A75), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      headline,
                      key: const ValueKey('sleep_dock_headline'),
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
          if (r.isNight)
            SleepStopButton(
              progress: _stopProgress,
              onHoldStart: _stopHoldStart,
              onHoldCancel: _stopHoldCancel,
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('sleep_start'),
                onPressed: _startNight,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B7A75),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.bedtime_rounded, size: 20),
                label: const Text(
                  'Start sleep monitoring',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          if (_showTestControls) ...[
            const SizedBox(height: 10),
            _testControls(r),
          ],
        ],
      ),
    );
  }

  IconData _icon(SleepRunController r) => switch (r.phase) {
    SleepPhase.idle || SleepPhase.stopped => Icons.bedtime_rounded,
    SleepPhase.running => Icons.graphic_eq_rounded,
    SleepPhase.paused => Icons.power_off_rounded,
    SleepPhase.interrupted => Icons.mic_off_rounded,
    SleepPhase.processing => Icons.hourglass_top_rounded,
  };

  (String, String) _statusLines(SleepRunController r) {
    final valid = r.validSleepH.toStringAsFixed(1);
    return switch (r.phase) {
      SleepPhase.idle => (
        'Ready for the night',
        'Phone in place? Tap Start, then sleep as usual.',
      ),
      SleepPhase.stopped => ('Not started', r.coaching),
      SleepPhase.running => (
        'Monitoring',
        '$valid h valid of 4 h needed · hold Stop for 2 s to end',
      ),
      SleepPhase.paused => (
        'Charger disconnected',
        'Plug it back in — ${r.unpluggedS ~/ 60} min unplugged · $valid h valid',
      ),
      SleepPhase.interrupted => (
        'Microphone interrupted',
        'Restarting the recording… $valid h valid so far',
      ),
      SleepPhase.processing => ('Analysing', 'Scoring the night…'),
    };
  }

  Widget _testControls(SleepRunController r) {
    final s = _sonar!;
    final d = _device!;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final o in SleepDemoOutcome.values)
          _testChip(
            'Outcome: ${switch (o) {
              SleepDemoOutcome.normal => 'Normal',
              SleepDemoOutcome.mild => 'Mild',
              SleepDemoOutcome.moderate => 'Moderate',
              SleepDemoOutcome.severe => 'Severe',
              SleepDemoOutcome.shortNight => 'Short night',
            }}',
            _demoOutcome == o,
            () => setState(() {
              _demoOutcome = o;
              r.demoOutcome = o;
              s.simulatedOutcome = o.name;
            }),
          ),
        if (d.simulated)
          _testChip(
            'Simulate unplugged',
            !d.simulatedCharging,
            () => unawaited(r.setSimulatedCharging(!d.simulatedCharging)),
          ),
        if (s.simulated) ...[
          _testChip(
            'Simulate echo lost',
            s.simulateEchoLost,
            () => setState(() => s.simulateEchoLost = !s.simulateEchoLost),
          ),
          _testChip(
            'Simulate mic dropout',
            false,
            () => setState(() => s.simulateInterruption = true),
          ),
          _testChip(
            'Fast night auto-stop',
            r.autoStop,
            () => setState(() => r.autoStop = !r.autoStop),
          ),
        ],
        Text(
          'audio ${s.source} · echo ${s.lastEchoDb?.toStringAsFixed(0) ?? '—'} dBFS · floor ${s.floorDb.toStringAsFixed(0)} · epochs ${r.epochs.length} (${r.validEpochs} valid) · events ${r.events.length} · keep-alive ${_keepAlive ? 'on' : 'off'}',
          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
        ),
      ],
    );
  }

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

  // --- Report (analysis) --------------------------------------------------------

  Widget _analyse() {
    final r = _run;
    return ListView(
      key: const ValueKey('analyse'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          'Step 4 · Analysing the night',
          '${p.algorithmLabel} on-device · ${r == null ? '' : '${r.epochs.length} epochs · ${r.validSleepH.toStringAsFixed(1)} h valid'}',
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AnaemiaUi.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < p.analysisStages.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: i < _analysisStage
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: MirrorColors.successFg,
                                size: 22,
                              )
                            : i == _analysisStage
                            ? const CircularProgressIndicator(strokeWidth: 2.5)
                            : const Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: AnaemiaUi.muted,
                                size: 22,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.analysisStages[i],
                          style: TextStyle(
                            color: i <= _analysisStage
                                ? AnaemiaUi.ink
                                : AnaemiaUi.muted,
                            fontSize: 13.5,
                            fontWeight: i == _analysisStage
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
