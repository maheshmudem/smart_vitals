import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/hearing_engines.dart';
import '../../core/domain/algorithms/hearing_session_builder.dart';
import '../../core/domain/entities/hearing_protocol.dart';
import '../../core/services/ambient_noise_service.dart';
import '../../core/services/audio_route_service.dart';
import '../../core/services/digit_speech_service.dart';
import '../../core/services/hearing_tone_service.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import 'din_test_view.dart';
import 'hearing_illustrations.dart';
import 'hearing_result_screen.dart';
import 'hearing_run_controller.dart';
import 'pure_tone_test_view.dart';

/// T-CAP flow for the hearing screen: Prepare (checklist + live earphone
/// and room-noise checks, G-19 / G-18) → How-to → Test → Analyse.
class HearingCaptureScreen extends StatefulWidget {
  const HearingCaptureScreen({
    super.key,
    required this.protocol,
    this.startAtHowTo = false,
  });

  final HearingProtocol protocol;
  final bool startAtHowTo;

  @override
  State<HearingCaptureScreen> createState() => _HearingCaptureScreenState();
}

class _HearingCaptureScreenState extends State<HearingCaptureScreen> {
  static const _labels = ['Prepare', 'How-to', 'Test', 'Analyse'];
  static const int _testIdx = 2;
  static const int _analyseIdx = 3;

  HearingProtocol get p => widget.protocol;

  int _step = 0;
  final Set<int> _checked = {};
  bool _showTestControls = false;
  HearingDemoOutcome _demoOutcome = HearingDemoOutcome.normal;
  final int _retakes = 0;

  HearingRunController? _run;
  AudioRouteService? _route;
  AmbientNoiseService? _noise;
  HearingToneService? _tones;
  DigitSpeechService? _speech;
  VoiceCoachController? _voice;

  // prepare-step live checks
  NoiseReading? _roomReading;
  double _noiseProgress = 0;
  bool _noiseChecking = false;
  bool _volumeAtMax = false;

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
    if (_route == null) {
      _route = AudioRouteService()..addListener(_onRoute);
      unawaited(_route!.start());
      _noise = AmbientNoiseService(
        micOffsetDba: appState.deviceProfile.micDbaOffset,
      )..addListener(_onNoiseTick);
      _tones = HearingToneService(
        fullScaleDbHl: appState.deviceProfile.earphoneFullScaleDbHl,
      );
      _speech = DigitSpeechService(
        languageCode: ttsLocaleFor(appState.localeCode),
      );
    }
  }

  void _onRoute() {
    if (!mounted) return;
    final s = _route!.state;
    // The route can notify during the first build; push the shared-state
    // update to after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppStateScope.of(
        context,
      ).updateEarphoneState(type: s.type, connected: s.connected);
      setState(() {});
    });
  }

  void _onNoiseTick() {
    if (!mounted) return;
    if (_step == _testIdx || _noiseChecking) setState(() {});
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _run?.dispose();
    _route?.removeListener(_onRoute);
    _route?.dispose();
    _noise?.removeListener(_onNoiseTick);
    _noise?.dispose();
    _tones?.dispose();
    _speech?.dispose();
    _voice?.dispose();
    _leaveImmersive();
    super.dispose();
  }

  void _say(String text, {VoiceCueTone tone = VoiceCueTone.ready}) {
    _voice?.announce(text, tone: tone, force: true);
  }

  /// Speak and complete when the sentence has been spoken.
  Future<void> _sayAndWait(
    String text, {
    VoiceCueTone tone = VoiceCueTone.ready,
  }) => _voice?.announceAndWait(text, tone: tone) ?? Future<void>.value();

  // ---------------------------------------------------------------------
  // Steps
  // ---------------------------------------------------------------------

  bool get _earphonesOk => _route?.state.connected ?? false;
  bool get _roomOk => _roomReading?.passes ?? false;
  bool get _prepareReady =>
      _checked.length >= p.prepareChecklist.length && _earphonesOk && _roomOk;

  String? get _prepareHelper {
    if (_checked.length < p.prepareChecklist.length) {
      return 'Tick each item to continue';
    }
    if (!_earphonesOk) return 'Earphones must be connected (G-19)';
    if (_roomReading == null) return 'Run the 3-second room check (G-18)';
    if (!_roomOk) {
      return 'Room too noisy — move somewhere quieter and check again';
    }
    return null;
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
          ? 'Room is quiet enough. ${r.dba.toStringAsFixed(0)} decibels.'
          : 'Too noisy at ${r.dba.toStringAsFixed(0)} decibels. Move to a quieter room and check again.',
      tone: r.passes ? VoiceCueTone.completed : VoiceCueTone.warning,
    );
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

  Future<void> _testBeep() async {
    final t = _tones;
    if (t == null) return;
    await t.playTone(HearingEar.right, 1000, 60);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    await t.playTone(HearingEar.left, 1000, 60);
  }

  Future<void> _enterTest() async {
    _testStartedAt = DateTime.now();
    unawaited(_enterImmersive());
    if (p.mode == HearingMode.pureTone) {
      _volumeAtMax = await _route?.ensureMaxVolume() ?? false;
    }
    unawaited(_noise?.start());
    _run?.dispose();
    _run = HearingRunController(
      protocol: p,
      tones: _tones,
      speech: _speech,
      route: _route,
      noise: _noise,
      demoOutcome: _demoOutcome,
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
    if (_run!.phase == HearingPhase.processing) {
      _startAnalysis();
    } else {
      setState(() {});
    }
  }

  Future<void> _enterImmersive() async {
    if (HearingToneService.isFlutterTest) return;
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
    if (HearingToneService.isFlutterTest) return;
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
        (r.phase == HearingPhase.running ||
            r.paused ||
            r.phase == HearingPhase.switchPart);
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
    unawaited(_noise?.stop());
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
    final route = _route?.state;
    final dev = appState.deviceProfile;
    final result = buildHearingSession(
      protocol: p,
      subject: appState.activeSubject,
      captures: run.captures,
      demoOutcome: _demoOutcome,
      history: appState.hearingSessions,
      earphoneType: route?.type ?? 'none',
      earphonesVerified: route?.connected ?? false,
      volumeAtMax: _volumeAtMax || (route?.volumeAtMax ?? false),
      fullScaleDbHl:
          dev.earphoneFullScaleDbHl ?? ToneLevel.defaultFullScaleDbHl,
      calibrationSource: dev.earphoneFullScaleDbHl == null
          ? 'assumed'
          : 'entered',
      ambientMeanDba: _noise?.sessionMeanDba ?? _roomReading?.dba,
      ambientMaxDba: _noise?.sessionMaxDba ?? _roomReading?.dba,
      ambientSource: _noise?.source ?? 'manual',
      pauses: run.pauses,
      retakes: _retakes,
      simulated: run.autoRun || (_route?.simulated ?? false),
      durationSeconds: _testStartedAt == null
          ? 0
          : DateTime.now().difference(_testStartedAt!).inSeconds,
    );
    _run?.dispose();
    _run = null;
    _leaveImmersive();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HearingResultScreen(result: result),
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
                  label: 'Start test',
                  icon: Icons.play_arrow_rounded,
                  helper: p.perEar
                      ? 'Right ear first · ${p.durationLabel}'
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
                  key: ValueKey('hear_check_$i'),
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
                  secondary: HearingIllustrationView(
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
          'Live checks',
          'Both must pass before the test starts (Spec §8 gates)',
        ),
        _earphoneCheckCard(),
        const SizedBox(height: 10),
        _roomCheckCard(),
      ],
    );
  }

  Widget _earphoneCheckCard() {
    final s = _route?.state;
    final ok = s?.connected ?? false;
    final color = ok ? MirrorColors.successFg : MirrorColors.warningFg;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(Icons.headphones_rounded, color, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Earphones · G-19',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      s?.plainLabel ?? 'Checking…',
                      key: const ValueKey('hear_route_label'),
                      style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Check again',
                onPressed: () => _route?.refresh(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_route != null && !_route!.simulated) ...[
            const SizedBox(height: 4),
            Text(
              _route!.lastError != null
                  ? 'Detection error: ${_route!.lastError}'
                  : _route!.platformSupported
                  ? 'Phone reports: ${s == null || s.deviceTypes.isEmpty ? 'no output devices' : 'types ${s.deviceTypes.join(", ")}'}${s != null && s.maxVolume > 0 ? ' · volume ${s.volume}/${s.maxVolume}' : ''} · rechecked every 2 s'
                  : 'Automatic detection is Android-only on this build.',
              style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11),
            ),
          ],
          if (_route != null && !_route!.simulated && !ok) ...[
            const Divider(height: 16),
            CheckboxListTile(
              key: const ValueKey('hear_manual_earphones'),
              value: _route?.manualConfirmed ?? false,
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => _route?.setManualConfirmed(v ?? false),
              title: const Text(
                'Not detected automatically — I confirm the earphones are in both ears and the volume is at maximum (recorded as a manual check)',
                style: TextStyle(color: AnaemiaUi.ink, fontSize: 12.5),
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
                      key: const ValueKey('hear_room_label'),
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
            'Microphone: ${_noise?.lastDbfs == null ? 'no reading yet' : '${_noise!.lastDbfs!.toStringAsFixed(0)} dBFS'} Â· offset ${(_noise?.micOffsetDba ?? 0).toStringAsFixed(0)} dB (per-phone, CAP-12). If a silent room reads above 45, tap Calibrate.',
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
                key: const ValueKey('hear_noise_check'),
                onPressed: _noiseChecking ? null : _checkRoom,
                child: Text(
                  r == null ? 'Check the room (3 s)' : 'Check again (3 s)',
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('hear_noise_calibrate'),
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

  /// CAP-12 per-device offset [DER]: the member confirms this room is
  /// quiet, the current microphone level is defined as 35 dBA and the
  /// offset is stored for this phone.
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
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: _playInstructions,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: const Text('Play instructions aloud'),
            ),
            if (p.mode == HearingMode.pureTone)
              OutlinedButton.icon(
                key: const ValueKey('hear_test_beep'),
                onPressed: _testBeep,
                icon: const Icon(Icons.hearing_rounded, size: 18),
                label: const Text('Play a test beep (right, then left)'),
              ),
          ],
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
                  child: HearingIllustrationView(
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
          text: switch (p.mode) {
            HearingMode.pureTone =>
              'If an earphone disconnects or the room goes above 45 dBA the beeps pause (E-AUD-004, G-18). You can skip an ear you cannot use.',
            HearingMode.digitsInNoise =>
              'Every round needs three digits — guess if unsure. The first three rounds are practice and are not scored.',
          },
        ),
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

  Widget _visual(HearingRunController r) {
    if (r.phase == HearingPhase.switchPart) return _switchCard(r);
    if (r.phase == HearingPhase.idle) return _idleCard(r);
    if (r.paused) return _pauseCard(r);
    switch (p.mode) {
      case HearingMode.pureTone:
        return PureToneTestView(run: r, ambientDba: _noise?.currentDba);
      case HearingMode.digitsInNoise:
        return DinTestView(run: r);
    }
  }

  Widget _centred(
    HearingIllustration kind,
    String title,
    String body, {
    Widget? extra,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 90, 28, 230),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HearingIllustrationView(kind: kind, size: 150),
            const SizedBox(height: 18),
            Text(
              title,
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
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (extra != null) ...[const SizedBox(height: 12), extra],
          ],
        ),
      ),
    );
  }

  Widget _idleCard(HearingRunController r) => switch (p.mode) {
    HearingMode.pureTone => _centred(
      HearingIllustration.earRight,
      'Right ear first',
      'Both earphones in. Tap Start, then tap the big button every time you hear a beep.',
    ),
    HearingMode.digitsInNoise => _centred(
      HearingIllustration.noiseWaves,
      'Listen for three numbers',
      'Both earphones in. Tap Start; the noise begins, then a voice says three numbers.',
    ),
  };

  Widget _switchCard(HearingRunController r) => _centred(
    r.currentEar == HearingEar.left
        ? HearingIllustration.earLeft
        : HearingIllustration.earRight,
    'Now the ${r.currentEar!.label.toLowerCase()} ear',
    'Keep both earphones in. Tap Start, then tap every time you hear a beep.',
  );

  Widget _pauseCard(HearingRunController r) {
    final earphones = r.phase == HearingPhase.pausedEarphones;
    return _centred(
      earphones
          ? HearingIllustration.earphoneUnplugged
          : HearingIllustration.quietRoom,
      earphones ? 'Earphones disconnected' : 'Too noisy',
      earphones
          ? 'Plug in or reconnect your earphones. The test carries on by itself (E-AUD-004).'
          : '${_noise?.currentDba?.toStringAsFixed(0) ?? '—'} dBA — the limit is 45. Wait for quiet; the test carries on by itself (G-18).',
      extra: OutlinedButton.icon(
        key: const ValueKey('hear_resume'),
        onPressed: r.resumeManually,
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(
          earphones ? 'Earphones are in — continue' : 'Continue anyway',
        ),
      ),
    );
  }

  Widget _dock(HearingRunController r) {
    final (headline, support) = _statusLines(r);
    final dockBg = const Color(0xFF0F172A).withValues(alpha: 0.92);
    const fg = Colors.white;
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
                p.mode == HearingMode.pureTone
                    ? Icons.hearing_rounded
                    : Icons.dialpad_rounded,
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
                      style: const TextStyle(
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

  (String, String) _statusLines(HearingRunController r) {
    switch (r.phase) {
      case HearingPhase.idle:
        return ('Ready?', 'Tap Start when you are set.');
      case HearingPhase.running:
        return (
          p.runHeadline,
          r.coaching.isEmpty ? p.durationLabel : r.coaching,
        );
      case HearingPhase.pausedEarphones:
        return ('Paused — earphones', r.coaching);
      case HearingPhase.pausedNoise:
        return ('Paused — too noisy', r.coaching);
      case HearingPhase.switchPart:
        return ('Switch ear', r.coaching);
      case HearingPhase.processing:
      case HearingPhase.done:
      case HearingPhase.aborted:
        return ('Done', 'Analysing your answers…');
    }
  }

  Widget _buttons(HearingRunController r) {
    final phase = r.phase;
    Widget primary;
    switch (phase) {
      case HearingPhase.idle:
        primary = _bigButton('Start', Icons.play_arrow_rounded, r.start);
      case HearingPhase.switchPart:
        primary = _bigButton(
          'Start ${r.currentEar!.label.toLowerCase()} ear',
          Icons.play_arrow_rounded,
          r.start,
        );
      case HearingPhase.running:
      case HearingPhase.pausedEarphones:
      case HearingPhase.pausedNoise:
        primary = _bigButton(
          p.mode == HearingMode.pureTone ? 'Listening…' : 'Keypad above',
          Icons.hourglass_top_rounded,
          null,
        );
      case HearingPhase.processing:
      case HearingPhase.done:
      case HearingPhase.aborted:
        primary = _bigButton(
          'Analysing…',
          Icons.hourglass_bottom_rounded,
          null,
        );
    }
    final canSkip =
        p.perEar &&
        (phase == HearingPhase.idle ||
            phase == HearingPhase.running ||
            r.paused ||
            phase == HearingPhase.switchPart);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        if (canSkip)
          TextButton.icon(
            onPressed: r.skipPart,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              minimumSize: const Size(0, 40),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: const Text('Skip this ear'),
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
        disabledBackgroundColor: Colors.white24,
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _testControls(HearingRunController r) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final o in HearingDemoOutcome.values)
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
          'Auto-listen (simulated)',
          r.autoRun,
          () => r.setAutoRun(!r.autoRun),
        ),
        if (_route?.simulated ?? false)
          _testChip('Simulate unplug', _route!.simulatedUnplugged, () {
            _route!.setSimulatedUnplugged(!_route!.simulatedUnplugged);
          }),
        if (_noise?.simulated ?? false)
          _testChip('Simulate noisy room', _noise!.simulatedDba > 45, () {
            setState(() {
              _noise!.simulatedDba = _noise!.simulatedDba > 45 ? 36 : 62;
            });
          }),
        Text(
          'level: full scale ${(_tones?.fullScaleDbHl ?? 90).toStringAsFixed(0)} dB HL · route ${_route?.state.type ?? '—'} · mic ${_noise?.source ?? '—'}',
          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
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
    const fg = Colors.white;
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
