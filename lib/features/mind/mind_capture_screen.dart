import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/mind_engines.dart';
import '../../core/domain/algorithms/mind_session_builder.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/mind_protocol.dart';
import '../../core/services/ambient_noise_service.dart';
import '../../core/services/emergency_contacts.dart';
import '../../core/services/live_camera_service.dart';
import '../../core/services/motion_sensor_service.dart';
import '../../core/services/speech_capture_service.dart';
import '../../core/services/speech_transcribe_service.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../eye_screens/eye_stepper_screen.dart' show ttsLocaleFor;
import '../results_cases/results_cases_screens.dart' show EmergencyAlertScreen;
import 'crisis_support_screen.dart';
import 'mind_illustrations.dart';
import 'mind_result_screen.dart';
import 'mind_run_controller.dart';
import 'mind_task_views.dart';

/// T-CAP flow for a Brain & Mind check: Prepare (checklist + live checks +
/// language / education / onset) → How-to → Tasks → Analyse.
class MindCaptureScreen extends StatefulWidget {
  const MindCaptureScreen({
    super.key,
    required this.protocol,
    this.language = MindLanguage.en,
    this.startAtHowTo = false,
    this.onsetLabel,
  });

  final MindProtocol protocol;
  final MindLanguage language;
  final bool startAtHowTo;

  /// Onset choice carried into a retake (stroke).
  final String? onsetLabel;

  @override
  State<MindCaptureScreen> createState() => _MindCaptureScreenState();
}

/// Onset choices for the stroke check (MOV-09 `symptom_onset_time`).
class _Onset {
  const _Onset(this.label, this.minutesAgo, {this.lastKnownWell});
  final String label;
  final int? minutesAgo; // null = unknown exact time

  /// For "woke up with it": the time the person was last seen well.
  final String? lastKnownWell;
  static const List<_Onset> all = [
    _Onset('Just now', 0),
    _Onset('About 1 h ago', 60),
    _Onset('About 3 h ago', 180),
    _Onset('More than 4.5 h ago', 300),
    _Onset(
      'Woke up with it',
      null,
      lastKnownWell: 'last known well at bedtime',
    ),
    _Onset('Unknown', null),
  ];

  /// Text stored with the result (MOV-09 symptom_onset_time).
  String get recordLabel =>
      lastKnownWell == null ? label : '$label ($lastKnownWell)';
}

class _MindCaptureScreenState extends State<MindCaptureScreen> {
  static const _labels = ['Prepare', 'How-to', 'Test', 'Analyse'];
  static const int _testIdx = 2;
  static const int _analyseIdx = 3;

  MindProtocol get p => widget.protocol;

  int _step = 0;
  final Set<int> _checked = {};
  bool _showTestControls = false;
  MindDemoOutcome _demoOutcome = MindDemoOutcome.normal;
  final int _retakes = 0;
  late MindLanguage _language = widget.language;
  final TextEditingController _education = TextEditingController();
  _Onset? _onset;
  DateTime? _onsetSelectedAt;
  bool _motionUnavailable = false;

  MindRunController? _run;
  AmbientNoiseService? _noise;
  SpeechTranscribeService? _transcribe;
  SpeechCaptureService? _capture;
  BiometricCameraController? _camera;
  VoiceCoachController? _voice;

  NoiseReading? _roomReading;
  double _noiseProgress = 0;
  bool _noiseChecking = false;
  bool _crisisShowing = false;
  bool _clinicianNotified = false;

  int _analysisStage = 0;
  Timer? _analysisTimer;
  DateTime? _testStartedAt;

  @override
  void initState() {
    super.initState();
    if (widget.startAtHowTo) _step = 1;
    final carried = widget.onsetLabel;
    if (carried != null) {
      for (final o in _Onset.all) {
        if (o.label == carried || o.recordLabel == carried) {
          _onset = o;
          _onsetSelectedAt = DateTime.now();
        }
      }
    }
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
      )..addListener(_onNoiseTick);
      _transcribe = SpeechTranscribeService();
      unawaited(
        _transcribe!.initialize().then((_) {
          if (mounted) setState(() {});
        }),
      );
      _capture = SpeechCaptureService();
      _education.text = '${appState.activeSubject.educationYears}';
    }
  }

  void _onNoiseTick() {
    if (!mounted) return;
    if (_noiseChecking) setState(() {});
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    // test toggles on the motion singleton must not outlive this screen
    MotionSensorService.instance.simulateUnavailable = false;
    _run?.dispose();
    _noise?.removeListener(_onNoiseTick);
    _noise?.dispose();
    _transcribe?.dispose();
    _capture?.dispose();
    _camera?.dispose();
    _voice?.dispose();
    _education.dispose();
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
  bool get _roomOk => !_needsRoomCheck || (_roomReading?.passes ?? false);
  int? get _educationYears {
    final v = int.tryParse(_education.text.trim());
    if (v == null || v < 0 || v > 30) return null;
    return v;
  }

  bool get _prepareReady =>
      _checked.length >= p.prepareChecklist.length &&
      _roomOk &&
      (!p.needsEducationYears || _educationYears != null) &&
      (!p.needsOnsetTime || _onset != null);

  String? get _prepareHelper {
    if (_checked.length < p.prepareChecklist.length) {
      return 'Tick each item to continue';
    }
    if (p.needsEducationYears && _educationYears == null) {
      return 'Enter years of schooling (0–30)';
    }
    if (p.needsOnsetTime && _onset == null) {
      return 'Choose when the symptoms started';
    }
    if (_needsRoomCheck && _roomReading == null) {
      return 'Run the 3-second room check (G-18)';
    }
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
          ? 'Room is quiet enough.'
          : 'Too noisy at ${r.dba.toStringAsFixed(0)} decibels. Move to a quieter room and check again.',
      tone: r.passes ? VoiceCueTone.completed : VoiceCueTone.warning,
    );
  }

  void _goHowTo() {
    final appState = AppStateScope.of(context);
    if (p.needsEducationYears && _educationYears != null) {
      appState.updateActiveSubject(
        appState.activeSubject.copyWith(educationYears: _educationYears),
      );
    }
    appState.setSpeechLanguage(appState.activeSubject.id, _language);
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
    _testStartedAt = DateTime.now();
    unawaited(_enterImmersive());
    if (p.usesCamera) {
      _camera?.dispose();
      _camera = BiometricCameraController(mode: ScanCameraMode.frontFace);
      _camera!.initialize();
    }
    if (p.usesMotion) {
      // a Movement Test Controls toggle must not leak into this check
      final motion = MotionSensorService.instance;
      motion.forceSimulated = false;
      final avail = await motion.probe();
      _motionUnavailable = avail == MotionAvailability.unavailable;
    }
    if (p.tasks.any((t) => t.type == MindTaskType.speechTranscribe)) {
      await _transcribe?.initialize();
    }
    if (!mounted) return;
    _run?.dispose();
    _run = MindRunController(
      protocol: p,
      language: _language,
      transcribe: _transcribe,
      capture: _capture,
      camera: _camera,
      demoOutcome: _demoOutcome,
      motionUnavailable: _motionUnavailable,
      onFaceDone: () {
        // release the camera so ML Kit does not compete with the recogniser
        final cam = _camera;
        _camera = null;
        cam?.dispose();
      },
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
    final r = _run!;
    if (r.crisisRaised && !_crisisShowing) {
      _showCrisis();
      return;
    }
    if (r.phase == MindPhase.processing) {
      _startAnalysis();
    } else {
      setState(() {});
    }
  }

  Future<void> _showCrisis() async {
    _crisisShowing = true;
    setState(() {});
    _say(
      'You are not alone. Help is available right now; please look at the screen.',
      tone: VoiceCueTone.warning,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CrisisSupportScreen(
          subjectName: AppStateScope.of(
            context,
          ).activeSubject.fullName.split(' ').first,
          onAcknowledged: (notify) {
            _clinicianNotified = notify;
            Navigator.of(context).pop();
          },
        ),
      ),
    );
    _crisisShowing = false;
    if (!mounted) return;
    _run?.acknowledgeCrisis(notifyClinician: _clinicianNotified);
  }

  Future<void> _enterImmersive() async {
    if (SpeechCaptureService.isFlutterTestStatic) return;
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
    if (SpeechCaptureService.isFlutterTestStatic) return;
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
        (r.phase == MindPhase.running || r.phase == MindPhase.between);
    if (!running) {
      Navigator.of(context).maybePop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop the check?'),
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
    final subj = appState.activeSubject;
    DateTime? onsetAt;
    if (_onset?.minutesAgo != null) {
      onsetAt = (_onsetSelectedAt ?? DateTime.now()).subtract(
        Duration(minutes: _onset!.minutesAgo!),
      );
    }
    var result = buildMindSession(
      protocol: p,
      subject: subj,
      captures: run.captures,
      demoOutcome: _demoOutcome,
      history: appState.mindSessions,
      language: _language,
      sttAvailable: _transcribe?.available ?? false,
      audioSource: (_capture?.simulated ?? true) ? 'simulated' : 'microphone',
      ambientDba: _roomReading?.dba,
      micSelfCheck: appState.deviceProfile.micSelfCheckPassed,
      cameraUsed: _camera?.isCameraReady ?? false,
      motionUsed:
          run.motionActive || run.captures.any((c) => c.armStart != null),
      hfBaseline: p.kind == MindKind.hfVoice
          ? appState.hfSamplesFor(subj.id)
          : const [],
      onsetAt: onsetAt,
      onsetLabel: _onset?.recordLabel,
      retakes: _retakes,
      simulated: run.autoRun || (_transcribe?.simulated ?? false),
      durationSeconds: _testStartedAt == null
          ? 0
          : DateTime.now().difference(_testStartedAt!).inSeconds,
    );
    if (_clinicianNotified) result = result.copyWith(clinicianNotified: true);
    _run?.dispose();
    _run = null;
    _camera?.dispose();
    _camera = null;
    _leaveImmersive();
    final nav = Navigator.of(context);
    if (p.kind == MindKind.stroke && result.isEmergency) {
      // Spec §9 MOV-09: positive → S-R02 Emergency immediately (BR-SCR-01).
      // Saved at once so the record and the COND_STROKE case exist even if
      // the member leaves to call for help.
      appState.saveMindSession(result);
      final signs = result.positiveSigns
          .map(
            (s) => switch (s) {
              'face' => 'uneven smile',
              'arm' => 'arm drift',
              _ => 'unclear speech',
            },
          )
          .join(', ');
      final skipped = result.parts.where((x) => !x.assessed).length;
      nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EmergencyAlertScreen(
            title: 'Stroke warning sign — act now (BR-SCR-01)',
            reasons: [
              'Sign${result.positiveSigns.length == 1 ? '' : 's'}: $signs',
              if (_onset != null) 'Symptoms started: ${_onset!.recordLabel}',
              if (skipped > 0)
                'The check stopped at the first sign; $skipped step${skipped == 1 ? '' : 's'} not needed',
              'Say "possible stroke" — stroke unit, CT brain (T10). Do not give food or drink.',
            ],
            nextRouteBuilder: () => MindResultScreen(result: result),
          ),
        ),
      );
      return;
    }
    nav.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => MindResultScreen(result: result)),
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
                bottom: p.safetyCritical ? _emergencyBar() : null,
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

  PreferredSizeWidget _emergencyBar() => PreferredSize(
    preferredSize: const Size.fromHeight(44),
    child: Container(
      color: const Color(0xFFDC2626),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Suspect a stroke? Call first, check second.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('mind_call_emergency'),
            onPressed: () => EmergencyContacts.dial('108'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFDC2626),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text(
              'Call 108',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    ),
  );

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
                  key: ValueKey('mind_check_$i'),
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
                  secondary: MindIllustrationView(
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
        AnaemiaUi.sectionHeader('Details for this check', p.plainSensorLine),
        if (p.languages.length > 1) ...[
          _languageCard(),
          const SizedBox(height: 10),
        ],
        if (p.needsEducationYears) ...[
          _educationCard(subj.fullName),
          const SizedBox(height: 10),
        ],
        if (p.needsOnsetTime) ...[_onsetCard(), const SizedBox(height: 10)],
        if (p.kind == MindKind.hfVoice) ...[
          _hfStatusCard(appState),
          const SizedBox(height: 10),
        ],
        if (p.kind == MindKind.mood) ...[
          _pathwayCard(subj.hasConsent(ConsentType.clinicianMoodPathway)),
          const SizedBox(height: 10),
        ],
        if (_needsRoomCheck) _roomCheckCard(),
        if (p.requiredGates.contains(GateId.g17)) ...[
          const SizedBox(height: 10),
          _micSelfCheckCard(appState.deviceProfile.micSelfCheckPassed),
        ],
      ],
    );
  }

  Widget _languageCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: AnaemiaUi.card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Language for speaking',
          style: TextStyle(
            color: AnaemiaUi.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<MindLanguage>(
          segments: [
            for (final l in p.languages)
              ButtonSegment(
                value: l,
                label: Text(
                  l.nativeLabel,
                  key: ValueKey('mind_lang_${l.name}'),
                ),
              ),
          ],
          selected: {_language},
          onSelectionChanged: (s) => setState(() => _language = s.first),
        ),
        const SizedBox(height: 6),
        Text(
          p.kind == MindKind.cognitive
              ? 'Speech recognition runs in this language (Spec §8: te / hi / en). ${_transcribe?.available == true ? 'Recognition ready on this phone.' : 'Recognition not available on this phone — a helper can count aloud and the acoustic values are still recorded.'}'
              : 'The sentence is shown in this language.',
          style: const TextStyle(
            color: AnaemiaUi.muted,
            fontSize: 11.5,
            height: 1.3,
          ),
        ),
      ],
    ),
  );

  Widget _educationCard(String name) => Container(
    padding: const EdgeInsets.all(12),
    decoration: AnaemiaUi.card(),
    child: Row(
      children: [
        const MindIllustrationView(kind: MindIllustration.graduation, size: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Years of formal education',
                style: TextStyle(
                  color: AnaemiaUi.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'For $name · needed for the age / education norms (S-B04, 0–30)',
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
          width: 64,
          child: TextField(
            key: const ValueKey('mind_education'),
            controller: _education,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: '12',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _onsetCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: AnaemiaUi.card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            MindIllustrationView(kind: MindIllustration.clock, size: 44),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'When did the symptoms start?',
                style: TextStyle(
                  color: AnaemiaUi.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < _Onset.all.length; i++)
              ChoiceChip(
                key: ValueKey('mind_onset_$i'),
                label: Text(_Onset.all[i].label),
                selected: _onset == _Onset.all[i],
                onSelected: (_) => setState(() {
                  _onset = _Onset.all[i];
                  _onsetSelectedAt = DateTime.now();
                }),
              ),
          ],
        ),
        if (_onset?.lastKnownWell != null) ...[
          const SizedBox(height: 4),
          Text(
            'Recorded as "${_onset!.recordLabel}" — the stroke team counts from the last time the person was seen well.',
            style: const TextStyle(
              color: MirrorColors.warningFg,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 6),
        const Text(
          'The stroke team needs this time: clot-busting treatment is given within 4.5 hours of the first symptom.',
          style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5, height: 1.3),
        ),
      ],
    ),
  );

  Widget _hfStatusCard(AppState appState) {
    final subj = appState.activeSubject;
    final samples = appState.hfSamplesFor(subj.id);
    final baselineDays = samples.where((s) => s.deviation == null).length;
    final building = baselineDays < HfBaseline.baselineDays;
    final doneToday = appState.hfCheckDoneToday(subj.id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Row(
        children: [
          const MindIllustrationView(
            kind: MindIllustration.calendar14,
            size: 56,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  building
                      ? 'Day ${baselineDays + 1} of ${HfBaseline.baselineDays} — building baseline'
                      : 'Baseline complete · day-to-day comparison active',
                  key: const ValueKey('mind_hf_status'),
                  style: const TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  doneToday
                      ? 'Completed today — recording again replaces today\'s sample (G-34).'
                      : 'Not yet done today (G-34 daily). ${subj.isHeartFailureEnrolled ? 'Enrolled in the HF programme (G-08).' : 'Not enrolled (G-08).'}',
                  style: const TextStyle(
                    color: AnaemiaUi.muted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pathwayCard(bool consent) => Container(
    padding: const EdgeInsets.all(12),
    decoration: AnaemiaUi.card(),
    child: Row(
      children: [
        const MindIllustrationView(kind: MindIllustration.clinician, size: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                consent
                    ? 'Clinician pathway active (G-07)'
                    : 'Clinician pathway not active (G-07)',
                style: TextStyle(
                  color: consent
                      ? MirrorColors.successFg
                      : MirrorColors.warningFg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Your PHQ-9 / GAD-7 answers and the voice sample are shared with your pathway clinician only.',
                style: TextStyle(
                  color: AnaemiaUi.muted,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _micSelfCheckCard(bool passed) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: AnaemiaUi.card(),
    child: Row(
      children: [
        Icon(
          passed ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          color: passed ? MirrorColors.successFg : MirrorColors.infoFg,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            passed
                ? 'Microphone self-check passed (G-17, ALG-CAP-11)'
                : 'Microphone self-check not run — open Audio Readiness (S-G01) for the 1.5 s sweep (G-17). Advisory here.',
            style: const TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );

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
                      key: const ValueKey('mind_room_label'),
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
                key: const ValueKey('mind_noise_check'),
                onPressed: _noiseChecking ? null : _checkRoom,
                child: Text(
                  r == null ? 'Check the room (3 s)' : 'Check again (3 s)',
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('mind_noise_calibrate'),
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
                  child: p.howTo[i].illustration == MindIllustration.parkScene
                      ? const ParkSceneView(width: 240)
                      : MindIllustrationView(
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
        if (p.whatYouGet.isNotEmpty) ...[
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
        ],
        for (final t in p.tasks)
          if (t.sentenceKey != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AnaemiaUi.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The sentence (${_language.label})',
                    style: const TextStyle(
                      color: AnaemiaUi.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    MindTexts.sentence(t.sentenceKey!, _language),
                    style: const TextStyle(
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
        InfoNote(
          icon: Icons.rule_rounded,
          text: switch (p.kind) {
            MindKind.cognitive =>
              'If the phone hears nothing, the task repeats. You can tap "I\'m done" after 20 seconds. Values are stored without a band until the norms are released.',
            MindKind.mood =>
              'If you answer question 9 with anything other than "Not at all", the app pauses and shows support contacts before continuing (G-37).',
            MindKind.hfVoice =>
              'If the recording is too quiet or too loud it repeats. No alert is raised during the first 14 days.',
            MindKind.stroke =>
              'Skip any step you cannot do. One positive sign is enough: the app goes straight to the emergency screen.',
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
                  if (p.safetyCritical)
                    _glassButton(
                      Icons.call_rounded,
                      'Call emergency (108)',
                      () => EmergencyContacts.dial('108'),
                      tint: const Color(0xFFF87171),
                    ),
                  if (p.kind == MindKind.mood)
                    _glassButton(
                      Icons.favorite_rounded,
                      'Support (helplines)',
                      () => _showCrisisHelplines(),
                      tint: const Color(0xFFFCA5A5),
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

  Future<void> _showCrisisHelplines() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Talk to someone now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AnaemiaUi.ink,
              ),
            ),
            const SizedBox(height: 10),
            for (final c in EmergencyContacts.crisis)
              ListTile(
                leading: const Icon(
                  Icons.call_rounded,
                  color: AnaemiaUi.primary,
                ),
                title: Text(c.label),
                subtitle: Text(c.sub),
                onTap: () => EmergencyContacts.dial(c.number),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _visual(MindRunController r) {
    if (r.phase == MindPhase.idle) return _idleCard(r);
    if (r.phase == MindPhase.between) return _betweenCard(r);
    switch (r.currentTask.type) {
      case MindTaskType.questionnaire:
        return QuestionnaireView(run: r);
      case MindTaskType.speechTranscribe:
      case MindTaskType.speechRecord:
        return SpeechTaskView(
          run: r,
          sttAvailable: _transcribe?.available ?? false,
        );
      case MindTaskType.faceSmile:
        return SmileTaskView(run: r, camera: _camera);
      case MindTaskType.armDrift:
        return ArmDriftTaskView(run: r);
    }
  }

  Widget _centred(
    MindIllustration kind,
    String title,
    String body, {
    Widget? extra,
  }) => Center(
    child: SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 90, 28, 230),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          kind == MindIllustration.parkScene
              ? const ParkSceneView(width: 200)
              : MindIllustrationView(kind: kind, size: 150),
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

  Widget _sentencePreview(MindTask t) => t.sentenceKey == null
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            MindTexts.sentence(t.sentenceKey!, _language),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
          ),
        );

  /// Steps + sentence preview (+ live camera for the face task) under the
  /// idle / between card.
  Widget _taskExtra(MindTask t, {Widget? leading}) {
    final cam = _camera;
    final showCamera =
        t.type == MindTaskType.faceSmile && cam != null && cam.isCameraReady;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leading != null) ...[leading, const SizedBox(height: 12)],
        if (showCamera) ...[
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: LiveBiometricCameraSurface(
                controller: cam,
                overlayPainter: FaceOvalPainter(
                  ok: cam.freshFaceGeometry() != null,
                  smile: false,
                ),
                fullBleed: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (t.whatToDo.isNotEmpty) TaskStepsList(steps: t.whatToDo),
        if (t.sentenceKey != null) ...[
          const SizedBox(height: 10),
          _sentencePreview(t),
        ],
      ],
    );
  }

  Widget _idleCard(MindRunController r) {
    final t = r.currentTask;
    return _centred(
      t.illustration ?? MindIllustration.speakToPhone,
      t.title,
      p.kind == MindKind.stroke
          ? 'Step 1 of ${r.taskCount} · tap Start when ready'
          : '${t.instruction} Tap Start when ready.',
      extra: _taskExtra(t),
    );
  }

  Widget _betweenCard(MindRunController r) {
    final t = r.currentTask;
    if (r.retryMessage != null) {
      return _centred(
        t.type == MindTaskType.faceSmile
            ? MindIllustration.smileCamera
            : MindIllustration.micLevel,
        'Let\'s try that again',
        r.retryMessage!,
        extra: _taskExtra(
          t,
          leading: FilledButton.icon(
            key: const ValueKey('mind_retry'),
            onPressed: r.retryTask,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Try again'),
          ),
        ),
      );
    }
    return _centred(
      t.illustration ?? MindIllustration.speakToPhone,
      'Next: ${t.title}',
      p.kind == MindKind.stroke
          ? 'Step ${r.taskIndex + 1} of ${r.taskCount} · tap Start when ready'
          : '${t.instruction} Tap Start when ready.',
      extra: _taskExtra(t),
    );
  }

  Widget _dock(MindRunController r) {
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

  IconData _icon(MindRunController r) => switch (r.currentTask.type) {
    MindTaskType.questionnaire => Icons.checklist_rounded,
    MindTaskType.speechTranscribe => Icons.record_voice_over_rounded,
    MindTaskType.speechRecord => Icons.mic_rounded,
    MindTaskType.faceSmile => Icons.face_retouching_natural_rounded,
    MindTaskType.armDrift => Icons.back_hand_rounded,
  };

  (String, String) _statusLines(MindRunController r) {
    switch (r.phase) {
      case MindPhase.idle:
        return ('Ready?', 'Tap Start when you are set.');
      case MindPhase.running:
        return (
          r.currentTask.title,
          r.coaching.isEmpty ? r.currentTask.instruction : r.coaching,
        );
      case MindPhase.between:
        return (r.retryMessage != null ? 'Try again' : 'Next step', r.coaching);
      case MindPhase.processing:
      case MindPhase.aborted:
        return ('Done', 'Analysing your answers…');
    }
  }

  Widget _buttons(MindRunController r) {
    Widget primary;
    switch (r.phase) {
      case MindPhase.idle:
        primary = _bigButton('Start', Icons.play_arrow_rounded, r.start);
      case MindPhase.between:
        primary = r.retryMessage != null
            ? _bigButton('Try again', Icons.replay_rounded, r.retryTask)
            : _bigButton(
                'Start ${r.currentTask.title.toLowerCase()}',
                Icons.play_arrow_rounded,
                r.start,
              );
      case MindPhase.running:
        primary = _bigButton(
          switch (r.currentTask.type) {
            MindTaskType.questionnaire => 'Answer above',
            MindTaskType.faceSmile => 'Look at the camera…',
            MindTaskType.armDrift => 'Hold still…',
            _ => 'Listening…',
          },
          Icons.hourglass_top_rounded,
          null,
        );
      case MindPhase.processing:
      case MindPhase.aborted:
        primary = _bigButton(
          'Analysing…',
          Icons.hourglass_bottom_rounded,
          null,
        );
    }
    final canSkip =
        p.tasks.length > 1 &&
        r.currentTask.type != MindTaskType.questionnaire &&
        (r.phase == MindPhase.idle ||
            r.phase == MindPhase.running ||
            r.phase == MindPhase.between);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        if (canSkip)
          TextButton.icon(
            key: const ValueKey('mind_skip'),
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

  Widget _testControls(MindRunController r) => Wrap(
    spacing: 6,
    runSpacing: 6,
    alignment: WrapAlignment.center,
    children: [
      for (final o in MindDemoOutcome.values)
        if (o != MindDemoOutcome.crisis || p.kind == MindKind.mood)
          _testChip(
            'Outcome: ${o.name[0].toUpperCase()}${o.name.substring(1)}',
            _demoOutcome == o,
            () {
              setState(() {
                _demoOutcome = o;
                r.demoOutcome = o;
                _transcribe?.simulatedOutcome = o;
                _capture?.simulatedOutcome = o;
              });
            },
          ),
      _testChip(
        'Auto-run (simulated)',
        r.autoRun,
        () => r.setAutoRun(!r.autoRun),
      ),
      if (_transcribe != null &&
          p.tasks.any((t) => t.type == MindTaskType.speechTranscribe))
        _testChip(
          'Simulate no speech recognition',
          _transcribe!.simulateUnavailable,
          () {
            setState(
              () => _transcribe!.simulateUnavailable =
                  !_transcribe!.simulateUnavailable,
            );
          },
        ),
      if (p.usesMotion)
        _testChip(
          'Simulate no motion sensor',
          MotionSensorService.instance.simulateUnavailable,
          () {
            final m = MotionSensorService.instance;
            setState(() {
              m.simulateUnavailable = !m.simulateUnavailable;
              _motionUnavailable = m.simulateUnavailable;
              r.motionUnavailable = m.simulateUnavailable;
            });
          },
        ),
      Text(
        'lang ${_language.name} · stt ${_transcribe?.available == true ? 'on' : 'off'} · mic ${_capture?.source ?? '—'}',
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
