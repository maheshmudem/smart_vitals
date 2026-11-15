import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart' show ResolutionPreset;
import 'package:flutter/material.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/caries_risk_engine.dart';
import '../../core/domain/algorithms/eye_session_builder.dart';
import '../../core/domain/algorithms/photo_quality_analyzer.dart';
import '../../core/domain/entities/anaemia_result.dart' show EyeSide;
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/eye_photo_protocol.dart';
import '../../core/domain/entities/eye_photo_session.dart';
import '../../core/services/live_camera_service.dart';
import '../../core/services/subject_track_spec.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';
import 'eye_illustrations.dart';
import 'eye_result_screen.dart';
import 'photo_review_panel.dart';

/// Maps the app language code ('en' | 'te' | 'hi') to a TTS locale.
String ttsLocaleFor(String localeCode) => switch (localeCode) {
  'te' => 'te-IN',
  'hi' => 'hi-IN',
  _ => 'en-US',
};

/// Generic guided eye-photo flow driven by an [EyeProtocol]:
///   [Connect]  — fundus only: attach + pair the clip-on camera (G-31),
///                partner data-sharing consent
///   Prepare    — pre-test questions, equipment / card (G-20), checklist,
///                before-you-start
///   How-to     — illustrated photo instructions + good / bad examples
///   Photos     — N photos with on-device quality checks (G-21), up to 3
///                attempts per view (G-25)
///   Analyse    — staged processing, then S-R01 result
class EyeStepperScreen extends StatefulWidget {
  const EyeStepperScreen({
    super.key,
    required this.protocol,
    this.startAtHowTo = false,
    this.onRequest = false,
  });

  final EyeProtocol protocol;
  final bool startAtHowTo;

  /// Cataract under 40 taken "on request" (G-09 advisory).
  final bool onRequest;

  @override
  State<EyeStepperScreen> createState() => _EyeStepperScreenState();
}

class _EyeStepperScreenState extends State<EyeStepperScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxAttempts = 3; // G-25

  EyeProtocol get p => widget.protocol;
  bool get _hasConnect => p.requiresFundusCamera;
  List<String> get _stepLabels => [
    if (_hasConnect) 'Connect',
    'Prepare',
    'How-to',
    'Photos',
    'Analyse',
  ];
  int get _prepareIdx => _hasConnect ? 1 : 0;
  int get _howToIdx => _prepareIdx + 1;
  int get _photosIdx => _prepareIdx + 2;
  int get _analyseIdx => _prepareIdx + 3;
  String get _stepTitlePrefix => 'Step ${_step + 1}';

  int _step = 0;

  // Connect (fundus)
  bool _connecting = false;
  bool _connected = false;
  bool _partnerConsent = false;
  Timer? _connectTimer;

  // Prepare
  final Set<String> _ticked = {};
  final _otherCtrl = TextEditingController();
  bool _cardReady = false;
  late final List<bool> _checklist = List.filled(p.checklist.length, false);
  String? _photographerRole;
  String? _bodyLocation;
  String? _duration;
  String? _skinType;
  final Set<String> _abcde = {};
  // Oral: tobacco / areca status. Dental: S-F02 caries-risk questionnaire.
  String? _tobacco;
  int? _brushing;
  String? _fluoride;
  int _sweets = 1;
  bool _nightFeeding = false;
  String? _lastVisit;
  bool _guardian = false;
  bool _prefilled = false;

  // Voice coach (spoken step summaries, view coaching, verdicts)
  VoiceCoachController? _voice;
  int _lastAnnouncedStep = -1;
  int _lastAnnouncedView = -1;
  String _lastCoaching = '';

  // Photos
  BiometricCameraController? _camera;
  late final AnimationController _pulse;
  final List<EyePhoto> _photos = [];
  int _attempts = 0;
  Uint8List? _pendingBytes;
  PhotoQualityReport? _pendingReport;
  bool _analysingPhoto = false;
  double _holdProgress = 0;
  Timer? _holdTimer;
  double _brightness = 142;
  double _variance = 450;
  bool _subjectInFrame = false;
  double _subjectCoverage = 0;
  bool _detectorActive = false;
  bool _subjectSeen = false;
  String? _subjectLabel;
  double _subjectConfidence = 0;
  bool _liveStream = false;
  bool _showTestControls = false;
  bool _simulateBadPhoto = false;
  EyeDemoOutcome _demoOutcome = EyeDemoOutcome.normal;
  DateTime? _photosStartedAt;

  // Analyse
  int _stageDone = 0;
  Timer? _stageTimer;

  int get _viewIndex => _photos.length;
  EyeView get _currentView => p.views[_viewIndex.clamp(0, p.views.length - 1)];
  bool get _hasCard => p.cardOffered && _cardReady;
  Set<EyeSide> get _operatedEyes => {
    if (_ticked.contains('surgery_left')) EyeSide.left,
    if (_ticked.contains('surgery_right')) EyeSide.right,
  };

  @override
  void initState() {
    super.initState();
    _step = widget.startAtHowTo ? _howToIdx : 0;
    if (widget.startAtHowTo && _hasConnect) {
      _connected = true;
      _partnerConsent = true;
    }
    if (widget.startAtHowTo && _ticked.isEmpty) _ticked.add('none');
    if (widget.startAtHowTo && p.cardOffered) _cardReady = true;
    if (widget.startAtHowTo && p.guardianRequired) {
      _photographerRole = 'Parent / guardian';
    }
    if (widget.startAtHowTo) {
      _tobacco ??= 'Never';
      _brushing ??= 2;
      _fluoride ??= 'yes';
      _lastVisit ??= 'Under 6 months';
    }
    _guardian = p.guardianRequired;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = AppStateScope.of(context);
    if (_hasConnect && !_connected) {
      _connected = appState.deviceProfile.fundusCameraConnected;
    }
    _voice ??= VoiceCoachController(
      languageCode: ttsLocaleFor(appState.localeCode),
    );
    _guardian = p.guardianRequiredFor(appState.activeSubject);
    if (!_prefilled) {
      _prefilled = true;
      // Tobacco status is prefilled from the profile only when it says
      // "no"; users must pick which product when the profile says "yes".
      if (_needsTobacco && !appState.activeSubject.usesTobaccoOrAreca) {
        _tobacco ??= 'Never';
      }
      if (_guardian && widget.startAtHowTo) {
        _photographerRole ??= 'Parent / guardian';
      }
    }
  }

  @override
  void dispose() {
    _connectTimer?.cancel();
    _holdTimer?.cancel();
    _stageTimer?.cancel();
    _camera?.dispose();
    _pulse.dispose();
    _otherCtrl.dispose();
    _voice?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Voice
  // ---------------------------------------------------------------------

  void _say(
    String text, {
    VoiceCueTone tone = VoiceCueTone.ready,
    bool force = false,
  }) {
    _voice?.announce(text, tone: tone, force: force);
  }

  /// Spoken summary for the current step, once per step entry.
  void _announceStepIfNeeded() {
    if (_lastAnnouncedStep == _step) return;
    _lastAnnouncedStep = _step;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_hasConnect && _step == 0) {
        _say(
          'Connect the clip-on fundus camera and agree to share de-identified images with the partner. Then tap continue.',
          force: true,
        );
      } else if (_step == _prepareIdx) {
        _say(p.voicePrepare, force: true);
      } else if (_step == _howToIdx) {
        _say(p.voiceHowTo, force: true);
      } else if (_step == _analyseIdx) {
        _say(p.voiceAnalysing, tone: VoiceCueTone.completed, force: true);
      }
    });
  }

  void _announceViewIfNeeded() {
    if (_viewIndex >= p.views.length || _lastAnnouncedView == _viewIndex) {
      return;
    }
    _lastAnnouncedView = _viewIndex;
    final v = p.views[_viewIndex];
    _say(
      'Photo ${_viewIndex + 1} of ${p.photoCount}. ${v.coaching}',
      tone: VoiceCueTone.scanning,
      force: true,
    );
  }

  void _announceVerdict(PhotoQualityReport report) {
    if (report.overallPassed) {
      _say(
        'Good photo. Keep and continue, or retake.',
        tone: VoiceCueTone.completed,
        force: true,
      );
    } else {
      final reason = report.failureReasons.isEmpty
          ? 'please retake'
          : report.failureReasons.first;
      _say('Needs retake. $reason', tone: VoiceCueTone.warning, force: true);
    }
  }

  void _playInstructions() {
    final buf = StringBuffer();
    for (var i = 0; i < p.howTo.length; i++) {
      buf.write('Step ${i + 1}. ${p.howTo[i].title}. ${p.howTo[i].body} ');
    }
    final tip = p.helperTip;
    if (tip != null) buf.write('Tip. ${tip.$2}');
    _say(buf.toString(), force: true);
  }

  Widget _muteButton({bool glass = false}) {
    final v = _voice;
    if (v == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: v,
      builder: (context, _) {
        final icon = v.audioEnabled
            ? Icons.volume_up_rounded
            : Icons.volume_off_rounded;
        final tip = v.audioEnabled ? 'Mute voice guide' : 'Unmute voice guide';
        if (glass) {
          return _glassButton(
            icon,
            tip,
            v.toggleAudio,
            tint: v.audioEnabled ? const Color(0xFF34D399) : null,
          );
        }
        return IconButton(
          tooltip: tip,
          icon: Icon(icon),
          onPressed: v.toggleAudio,
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------

  String get _screenId {
    final ids = p.stepScreenIds;
    return ids[_step.clamp(0, ids.length - 1)];
  }

  Future<void> _goBack() async {
    if (_step == _analyseIdx) return;
    if (_step == _photosIdx) {
      final leave = await _confirmLeavePhotos();
      if (leave && mounted) {
        _disposeCamera();
        setState(() {
          _photos.clear();
          _pendingBytes = null;
          _pendingReport = null;
          _attempts = 0;
          _step = _howToIdx;
        });
      }
      return;
    }
    if (_step > 0) {
      setState(() => _step--);
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmLeavePhotos() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop taking photos?'),
        content: const Text(
          'Photos taken so far will be discarded and you can start again later.',
        ),
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
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isPhotos = _step == _photosIdx;
    _announceStepIfNeeded();
    if (isPhotos) _announceViewIfNeeded();
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: isPhotos
            ? const Color(0xFF07111E)
            : MirrorColors.backgroundLight,
        appBar: isPhotos
            ? null
            : AppBar(
                leading: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _step == _analyseIdx ? null : _goBack,
                ),
                title: Text(p.title),
                actions: [
                  _muteButton(),
                  IconButton(
                    tooltip: 'Screen spec & gates',
                    icon: const Icon(Icons.info_outline_rounded),
                    onPressed: () =>
                        showScreenGateLifecycleSheet(context, _screenId),
                  ),
                ],
              ),
        body: isPhotos
            ? _buildPhotosStep(context)
            : Column(
                children: [
                  StepHeader(labels: _stepLabels, current: _step),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _hasConnect && _step == 0
                            ? _buildConnectStep(context)
                            : _step == _prepareIdx
                            ? _buildPrepareStep(context)
                            : _step == _howToIdx
                            ? _buildHowToStep(context)
                            : _buildAnalysingStep(context),
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: isPhotos ? null : _bottomBar(context),
      ),
    );
  }

  bool get _needsLocation => p.extraInputs.contains(EyeExtraInput.bodyLocation);
  bool get _needsDuration => p.extraInputs.contains(EyeExtraInput.duration);
  bool get _needsTobacco => p.extraInputs.contains(EyeExtraInput.tobaccoStatus);
  bool get _needsHabits => p.extraInputs.contains(EyeExtraInput.dentalHabits);
  bool get _habitsComplete =>
      _brushing != null && _fluoride != null && _lastVisit != null;

  bool get _prepareReady {
    if (_ticked.isEmpty) return false;
    if (p.cardRequired && !_cardReady) return false;
    if (_guardian && _photographerRole == null) return false;
    if (_hasConnect && !(_connected && _partnerConsent)) return false;
    if (_needsLocation && _bodyLocation == null) return false;
    if (_needsDuration && _duration == null) return false;
    if (_needsTobacco && _tobacco == null) return false;
    if (_needsHabits && !_habitsComplete) return false;
    return true;
  }

  String? get _prepareHelper {
    if (_needsTobacco && _tobacco == null) {
      return 'Choose your tobacco / areca status to continue (G-10)';
    }
    if (_needsLocation && _bodyLocation == null) {
      return 'Choose where the spot is to continue';
    }
    if (_needsDuration && _duration == null) {
      return p.id == 'dental_oral'
          ? 'Say whether you have noticed anything, and for how long'
          : 'Say how long you have had it to continue';
    }
    if (_needsHabits && !_habitsComplete) {
      return 'Answer brushing, fluoride and last dentist visit to continue (S-F02)';
    }
    if (_ticked.isEmpty) return 'Answer the questions to continue';
    if (p.cardRequired && !_cardReady) {
      return 'Confirm the colour card is ready — required for this screen (G-20)';
    }
    if (_guardian && _photographerRole == null) {
      return 'Choose who is taking the photo';
    }
    return null;
  }

  /// 'flash will fire' / 'flash on 2 of 4 shots' / 'camera lights the retina'.
  String get _flashSummary {
    final flashViews = p.views.where((v) => v.flash ?? p.flash).length;
    if (p.partnerModel) return 'camera lights the retina';
    if (p.torchPreview) return 'torch on, flash fires';
    if (flashViews == 0) return 'flash off';
    if (flashViews == p.views.length) return 'flash will fire';
    return 'flash on $flashViews of ${p.views.length} shots';
  }

  Widget? _bottomBar(BuildContext context) {
    if (_hasConnect && _step == 0) {
      final ready = _connected && _partnerConsent;
      return PrimaryBottomButton(
        label: 'Camera connected — continue',
        icon: Icons.check_rounded,
        helper: ready
            ? null
            : !_connected
            ? 'Connect the clip-on camera to continue (G-31)'
            : 'Agree to share de-identified images with the partner AI',
        onPressed: ready ? () => setState(() => _step = _prepareIdx) : null,
      );
    }
    if (_step == _prepareIdx) {
      return PrimaryBottomButton(
        label: 'Start the test',
        helper: _prepareHelper,
        onPressed: _prepareReady
            ? () => setState(() => _step = _howToIdx)
            : null,
      );
    }
    if (_step == _howToIdx) {
      return PrimaryBottomButton(
        label: 'Start photos',
        icon: Icons.photo_camera_rounded,
        helper:
            '${p.photoCount} photos · $_flashSummary${p.dimRoom ? ' · dim room' : ''}',
        onPressed: _enterPhotosStep,
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Connect (fundus)
  // ---------------------------------------------------------------------

  void _connectCamera() {
    setState(() => _connecting = true);
    _connectTimer?.cancel();
    _connectTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      AppStateScope.of(context).setFundusCameraConnected(true);
      setState(() {
        _connecting = false;
        _connected = true;
      });
    });
  }

  Widget _buildConnectStep(BuildContext context) {
    final statusColor = _connected
        ? MirrorColors.successFg
        : _connecting
        ? MirrorColors.warningFg
        : MirrorColors.dangerFg;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          '$_stepTitlePrefix · Connect the fundus camera',
          'Clip-on camera over the rear lens, paired to the phone (G-15 / G-31)',
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AnaemiaUi.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const EyeIllustrationView(
                    kind: EyeIllustration.fundusClipOn,
                    size: 78,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Clip-on fundus camera',
                          style: TextStyle(
                            color: AnaemiaUi.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnaemiaUi.tag(
                          _connected
                              ? 'Connected · G-31 passed'
                              : _connecting
                              ? 'Connecting…'
                              : 'Not connected',
                          color: statusColor,
                          icon: _connected
                              ? Icons.check_circle_rounded
                              : _connecting
                              ? Icons.sync_rounded
                              : Icons.bluetooth_disabled_rounded,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Partner AI licence: active',
                          style: TextStyle(
                            color: AnaemiaUi.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnaemiaUi.numberedStep(
                1,
                'Attach',
                'Clip the camera squarely over the rear lens until it clicks. Remove any phone case that lifts it.',
              ),
              AnaemiaUi.numberedStep(
                2,
                'Power on and pair',
                'Hold the power button 2 s. The app pairs over Bluetooth (or USB-C) and shows "Connected".',
              ),
              AnaemiaUi.numberedStep(
                3,
                'Check the eyepiece',
                'Wipe the eyepiece with a lens cloth. The green fixation light should be visible inside.',
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _connected
                    ? OutlinedButton.icon(
                        onPressed: () => setState(() => _connected = false),
                        icon: const Icon(Icons.link_off_rounded, size: 18),
                        label: const Text('Disconnect'),
                      )
                    : FilledButton.icon(
                        onPressed: _connecting ? null : _connectCamera,
                        icon: _connecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.bluetooth_searching_rounded),
                        label: Text(
                          _connecting ? 'Pairing…' : 'Connect camera',
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MaterialCard(
          padding: EdgeInsets.zero,
          child: CheckboxListTile(
            value: _partnerConsent,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.fromLTRB(8, 2, 14, 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onChanged: (v) => setState(() => _partnerConsent = v ?? false),
            title: const Text(
              'Share de-identified retina images with the partner AI',
              style: TextStyle(
                color: AnaemiaUi.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Only the retina images, age and sex are sent — no name or contact details. Required for grading (G-04 partner share). Without it the partner path is disabled.',
              style: TextStyle(
                color: AnaemiaUi.muted,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const InfoNote(
          icon: Icons.science_outlined,
          text:
              'Design build: the connection is simulated and the phone\'s rear camera stands in for the clip-on optics, so the full flow can be walked through. Grades are static demo values until the partner SDK is wired.',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Prepare
  // ---------------------------------------------------------------------

  Widget _buildPrepareStep(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          '$_stepTitlePrefix · Prepare',
          'A few quick questions, then get set up for the photos',
        ),
        if (widget.onRequest) ...[
          const InfoNote(
            icon: Icons.front_hand_rounded,
            color: MirrorColors.warningFg,
            background: MirrorColors.warningBg,
            title: 'Taken on request (G-09)',
            text:
                'This screen is normally offered from age 40. It will run as requested and the result is marked "on request".',
          ),
          const SizedBox(height: 12),
        ],
        if (_needsLocation || _needsDuration || _needsTobacco) ...[
          _spotDetailsCard(),
          const SizedBox(height: 12),
        ],
        if (_needsHabits) ...[_dentalHabitsCard(), const SizedBox(height: 12)],
        if (p.extraInputs.contains(EyeExtraInput.abcde)) ...[
          _abcdeCard(),
          const SizedBox(height: 12),
        ],
        _questionsCard(),
        const SizedBox(height: 12),
        if (p.extraInputs.contains(EyeExtraInput.skinType)) ...[
          _skinTypeCard(),
          const SizedBox(height: 12),
        ],
        if (_guardian) ...[_photographerCard(), const SizedBox(height: 12)],
        _equipmentCard(),
        const SizedBox(height: 12),
        _beforeYouStartCard(),
      ],
    );
  }

  Widget _cardHeader(IconData icon, Color color, String title, String sub) {
    return Row(
      children: [
        AnaemiaUi.iconTile(icon, color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AnaemiaUi.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipChoice(
    List<String> options,
    String? selected,
    ValueChanged<String> onPick,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: selected == o,
            onSelected: (_) => setState(() => onPick(o)),
          ),
      ],
    );
  }

  Widget _subQuestion(String text) => Text(
    text,
    style: const TextStyle(
      color: AnaemiaUi.ink,
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
    ),
  );

  /// Skin lesion: where the spot is + how long. Oral: tobacco status + what
  /// was noticed and for how long.
  Widget _spotDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            _needsTobacco ? Icons.smoke_free_rounded : Icons.place_outlined,
            AnaemiaUi.accent,
            p.detailsTitle,
            p.detailsCaption,
          ),
          if (_needsTobacco) ...[
            const SizedBox(height: 12),
            _subQuestion('Tobacco or areca (supari, gutka, paan, khaini)?'),
            const SizedBox(height: 6),
            _chipChoice(
              const ['Never', 'Former', 'Smoking', 'Chewing', 'Both'],
              _tobacco,
              (v) => _tobacco = v,
            ),
            const SizedBox(height: 6),
            Text(
              _tobacco == null
                  ? 'Your profile says you use tobacco or areca — choose which (G-10).'
                  : _tobacco == 'Never' || _tobacco == 'Former'
                  ? 'Recorded as tobacco_areca_status · this screen is still open to you on request.'
                  : 'Current use: this screen is recommended every 6 months (G-10). Quitline 1800-11-2356.',
              style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11),
            ),
          ],
          if (_needsLocation) ...[
            const SizedBox(height: 12),
            const Text(
              'Where on the body?',
              style: TextStyle(
                color: AnaemiaUi.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            _chipChoice(
              p.bodyLocations,
              _bodyLocation,
              (v) => _bodyLocation = v,
            ),
          ],
          if (_needsDuration) ...[
            const SizedBox(height: 12),
            _subQuestion(p.durationPrompt),
            const SizedBox(height: 6),
            _chipChoice(p.durationOptions, _duration, (v) => _duration = v),
            if (_duration == 'Over 3 weeks') ...[
              const SizedBox(height: 8),
              const InfoNote(
                icon: Icons.priority_high_rounded,
                color: MirrorColors.dangerFg,
                background: MirrorColors.dangerBg,
                text:
                    'A patch, sore or lump that has lasted over 3 weeks needs an in-person look whatever the photos show — the result will say "Needs a look" at minimum.',
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Dental: S-F02 caries-risk questionnaire (Q_CARIES_RISK) with a live
  /// habits-only preview of the BR-DEN rule.
  Widget _dentalHabitsCard() {
    final appState = AppStateScope.of(context);
    final age = appState.activeSubject.ageYears;
    final preview = CariesRiskEngine.evaluate(
      findings: const [],
      habits: CariesHabitsInput(
        nightBottleFeeding: _nightFeeding,
        brushingPerDay: _brushing ?? 2,
        usesFluoridePaste: _fluoride == 'yes',
        sweetsPerDay: _sweets,
      ),
    );
    final previewColor = switch (preview.riskBand) {
      SemanticBand.low => MirrorColors.successFg,
      SemanticBand.moderate => MirrorColors.warningFg,
      _ => MirrorColors.dangerFg,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            Icons.cleaning_services_rounded,
            AnaemiaUi.accent,
            'Brushing, fluoride and sugar',
            'Caries-risk questionnaire (S-F02) · the BR-DEN rule combines these with the photos',
          ),
          const SizedBox(height: 12),
          _subQuestion('How often are the teeth brushed?'),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Not daily')),
                ButtonSegment(value: 1, label: Text('Once a day')),
                ButtonSegment(value: 2, label: Text('Twice +')),
              ],
              selected: {?_brushing},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _brushing = s.isEmpty ? null : s.first),
            ),
          ),
          const SizedBox(height: 12),
          _subQuestion(
            'Fluoride toothpaste? (check the tube: "fluoride" or "1000 ppm")',
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'yes', label: Text('Yes')),
                ButtonSegment(value: 'no', label: Text('No')),
                ButtonSegment(value: 'unknown', label: Text("Don't know")),
              ],
              selected: {?_fluoride},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _fluoride = s.isEmpty ? null : s.first),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _subQuestion('Sweets or sugary drinks per day')),
              IconButton.outlined(
                tooltip: 'Fewer',
                visualDensity: VisualDensity.compact,
                onPressed: _sweets > 0 ? () => setState(() => _sweets--) : null,
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  _sweets >= 5 ? '5+' : '$_sweets',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'More',
                visualDensity: VisualDensity.compact,
                onPressed: _sweets < 5 ? () => setState(() => _sweets++) : null,
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
          const Text(
            'Count every sweet, biscuit, chocolate, juice or fizzy drink between meals.',
            style: TextStyle(color: AnaemiaUi.muted, fontSize: 11),
          ),
          if (age < 6) ...[
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _nightFeeding,
              onChanged: (v) => setState(() => _nightFeeding = v),
              title: const Text(
                'Bottle or breast feeding at night, in bed',
                style: TextStyle(
                  color: AnaemiaUi.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'Milk pooling on the teeth overnight is the main cause of early-childhood caries (under 6).',
                style: TextStyle(color: AnaemiaUi.muted, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _subQuestion('Last dentist visit'),
          const SizedBox(height: 6),
          _chipChoice(
            const ['Under 6 months', '6–12 months', 'Over a year', 'Never'],
            _lastVisit,
            (v) => _lastVisit = v,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: previewColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: previewColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.rule_rounded, size: 18, color: previewColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Habits alone: ${preview.riskBand.label.replaceAll(' Risk', '')} caries risk (ALG-DEN-06). Tooth findings from the photos are added after the scan.',
                    style: TextStyle(
                      color: previewColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Skin lesion: ABCDE checklist.
  Widget _abcdeCard() {
    return MaterialCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            Icons.rule_rounded,
            const Color(0xFF7C3AED),
            'ABCDE check',
            'Tick any sign you can see — two or more always earn a look',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const EyeIllustrationView(
                kind: EyeIllustration.abcdeChart,
                size: 72,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in p.abcdeItems)
                      _checkTile(
                        item.$2,
                        _abcde.contains(item.$1),
                        (v) => setState(
                          () =>
                              v ? _abcde.add(item.$1) : _abcde.remove(item.$1),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Skin lesion: Fitzpatrick skin type (fairness audit, not used for the band).
  Widget _skinTypeCard() {
    const types = ['I', 'II', 'III', 'IV', 'V', 'VI'];
    const colours = [
      Color(0xFFF8E3D3),
      Color(0xFFF2CDB3),
      Color(0xFFE2B48E),
      Color(0xFFC08A5C),
      Color(0xFF8D5A3B),
      Color(0xFF4A3024),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            Icons.palette_outlined,
            const Color(0xFF059669),
            'Your skin type (optional)',
            'Fitzpatrick I–VI · used only to check the model works equally for all skin tones',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < types.length; i++) ...[
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _skinType = types[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: colours[i],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _skinType == types[i]
                              ? AnaemiaUi.primary
                              : AnaemiaUi.outline,
                          width: _skinType == types[i] ? 2.2 : 1,
                        ),
                      ),
                      child: Text(
                        types[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: i >= 4 ? Colors.white : AnaemiaUi.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                if (i != types.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionsCard() {
    final reliability = p.questions
        .where((q) => _ticked.contains(q.id) && q.affectsReliability)
        .toList();
    final escalating = p.questions
        .where((q) => _ticked.contains(q.id) && q.escalates)
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(
                Icons.medical_services_outlined,
                const Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before the photos',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Does any of this apply? Select all that apply.',
                      style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final q in p.questions) _questionRow(q),
          if (reliability.isNotEmpty) ...[
            const SizedBox(height: 4),
            InfoNote(
              icon: Icons.warning_amber_rounded,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              title: 'You can still take the test',
              text: reliability.map((q) => q.note).join(' '),
            ),
          ],
          if (escalating.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoNote(
              icon: Icons.priority_high_rounded,
              color: MirrorColors.dangerFg,
              background: MirrorColors.dangerBg,
              title: 'Worth telling your doctor',
              text: escalating.map((q) => q.note).join(' '),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _otherCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13.5, color: AnaemiaUi.ink),
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Anything else? (optional)',
              hintText:
                  'e.g. recent illness, medicines, what you have noticed…',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionRow(EyeQuestion q) {
    final selected = _ticked.contains(q.id);
    final isNone = q.id == 'none';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          if (isNone) {
            _ticked
              ..clear()
              ..add('none');
          } else {
            _ticked.remove('none');
            selected ? _ticked.remove(q.id) : _ticked.add(q.id);
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AnaemiaUi.primary.withValues(alpha: 0.07)
                : AnaemiaUi.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AnaemiaUi.primary : AnaemiaUi.outline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 22,
                color: selected ? AnaemiaUi.primary : AnaemiaUi.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  q.label,
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (q.affectsReliability || q.escalates)
                Tooltip(
                  message: q.affectsReliability
                      ? 'May affect how reliable the result is'
                      : 'Strengthens the advice if the result is positive',
                  child: Icon(
                    q.affectsReliability
                        ? Icons.info_outline_rounded
                        : Icons.priority_high_rounded,
                    size: 17,
                    color: AnaemiaUi.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photographerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AnaemiaUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(
                Icons.family_restroom_rounded,
                AnaemiaUi.accent,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Who is taking the photo?',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Recorded as photographer role (Spec). A parent, guardian or operator holds the phone.',
                      style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Parent / guardian',
                  label: Text('Parent / guardian'),
                  icon: Icon(Icons.escalator_warning_rounded),
                ),
                ButtonSegment(
                  value: 'Operator',
                  label: Text('Operator'),
                  icon: Icon(Icons.badge_rounded),
                ),
              ],
              selected: {?_photographerRole},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) => setState(
                () => _photographerRole = s.isEmpty ? null : s.first,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _equipmentCard() {
    return MaterialCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnaemiaUi.iconTile(
                Icons.handyman_outlined,
                const Color(0xFF059669),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.equipmentTitle,
                      style: const TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      p.equipmentCaption,
                      style: const TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p.cardOffered && p.cardRequired) ...[
            _optionCard(
              selected: _cardReady,
              onTap: () => setState(() => _cardReady = !_cardReady),
              illustration: _cardIllustration,
              title: _cardReady
                  ? '24-patch colour card is ready'
                  : 'Tap when the 24-patch colour card is ready',
              body:
                  'Place it ${p.cardPlacementCopy}, inside the frame in every photo. The app corrects colours and scale with it (ΔE ≤ 5).',
              tag: p.card == ColourCardPolicy.mandatory
                  ? 'Mandatory'
                  : 'Required',
            ),
            const SizedBox(height: 8),
            InfoNote(
              icon: Icons.block_rounded,
              color: MirrorColors.dangerFg,
              background: MirrorColors.dangerBg,
              text:
                  p.cardRequiredNote ??
                  'This screen needs the card to correct colour or size. Without it the result would be "Not assessed" (G-20).',
            ),
            const SizedBox(height: 10),
          ] else if (p.cardOffered) ...[
            _optionCard(
              selected: _cardReady,
              onTap: () => setState(() => _cardReady = true),
              illustration: _cardIllustration,
              title: '24-patch colour card is ready',
              body:
                  'Place it ${p.cardPlacementCopy}, inside the frame in every photo. The app corrects colours and scale with it (ΔE ≤ 5).',
              tag: 'Preferred',
            ),
            const SizedBox(height: 8),
            _optionCard(
              selected: !_cardReady,
              onTap: () => setState(() => _cardReady = false),
              illustration: p.isBodyScreen
                  ? EyeIllustration.coinScale
                  : EyeIllustration.phoneDistanceFlash,
              title: p.isBodyScreen
                  ? 'No card — coin or no scale'
                  : 'No card — use flash white balance',
              body: p.isBodyScreen
                  ? 'Allowed for this screen. A coin gives a rough size; without any scale the size is not measured and confidence is slightly lower.'
                  : 'Allowed for this screen. Colour is normalised from the flash; the result confidence is slightly lower.',
              tag: 'Uncalibrated',
              tagColor: MirrorColors.warningFg,
            ),
            const SizedBox(height: 10),
          ],
          for (var i = 0; i < p.checklist.length; i++)
            _checkTile(
              p.checklist[i],
              _checklist[i],
              (v) => setState(() => _checklist[i] = v),
            ),
        ],
      ),
    );
  }

  Widget _optionCard({
    required bool selected,
    required VoidCallback onTap,
    required EyeIllustration illustration,
    required String title,
    required String body,
    required String tag,
    Color tagColor = MirrorColors.successFg,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? AnaemiaUi.primary.withValues(alpha: 0.07)
              : AnaemiaUi.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AnaemiaUi.primary : AnaemiaUi.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EyeIllustrationView(kind: illustration, size: 64),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AnaemiaUi.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      AnaemiaUi.tag(tag, color: tagColor),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AnaemiaUi.muted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AnaemiaUi.primary : AnaemiaUi.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkTile(String title, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        title,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _beforeYouStartCard() {
    return MaterialCard(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: AnaemiaUi.iconTile(
            Icons.checklist_rounded,
            AnaemiaUi.primary,
            size: 36,
          ),
          title: const Text(
            'Before you start',
            style: TextStyle(
              color: AnaemiaUi.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${p.beforeYouStart.length} things that make the photos work first time',
            style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            Row(
              children: [
                for (var i = 0; i < p.beforeIllustrations.length; i++) ...[
                  Expanded(
                    child: _IllustratedHint(
                      p.beforeIllustrations[i],
                      _hintCaption(p.beforeIllustrations[i]),
                    ),
                  ),
                  if (i != p.beforeIllustrations.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 10),
            for (final b in p.beforeYouStart) AnaemiaUi.bullet(b),
          ],
        ),
      ),
    );
  }

  EyeIllustration get _cardIllustration => switch (p.id) {
    'body_newborn' => EyeIllustration.cardOnChest,
    'body_foot' => EyeIllustration.footSoleWithCard,
    'body_skin' => EyeIllustration.cardOnChest,
    _ => EyeIllustration.cardBesideEye,
  };

  String _hintCaption(EyeIllustration k) => switch (k) {
    EyeIllustration.lookUp => 'Look up',
    EyeIllustration.lookTowardNose => 'Look toward nose',
    EyeIllustration.cardBesideEye => 'Card beside eye',
    EyeIllustration.phoneDistanceFlash => 'Flash on, ${p.distanceLabel}',
    EyeIllustration.dimRoom => 'Dim the room',
    EyeIllustration.glassesOff => 'Glasses off',
    EyeIllustration.pupilCentred => 'Pupil in the ring',
    EyeIllustration.childDistance => '0.5–1 m, eye level',
    EyeIllustration.childLookAtLight => 'Look at the light',
    EyeIllustration.fundusClipOn => 'Clip-on camera',
    EyeIllustration.fundusFixation => 'Fixation light',
    EyeIllustration.holdStill => 'Hold still 2 s',
    EyeIllustration.babyOnBack => 'Baby calm, on back',
    EyeIllustration.cardOnChest => 'Card on the skin',
    EyeIllustration.daylightWindow => 'Daylight, no lamps',
    EyeIllustration.wipeCream => 'Wipe the skin',
    EyeIllustration.helperHoldsFoot => 'Helper, ${p.distanceLabel}',
    EyeIllustration.footSoleWithCard => 'Card beside sole',
    EyeIllustration.toesSpread => 'Spread the toes',
    EyeIllustration.lesionCentred => 'Spot in the ring',
    EyeIllustration.lesionContextArm => 'Arm\'s-length shot',
    EyeIllustration.coinScale => 'Coin or card',
    EyeIllustration.dentureOut => 'Rinse, dentures out',
    EyeIllustration.torchMouthDistance => 'Torch on, ${p.distanceLabel}',
    EyeIllustration.cheekRetract => 'Pull the cheek out',
    EyeIllustration.mouthOpenWide => 'Open wide',
    EyeIllustration.tongueToSide => 'Tongue to the side',
    EyeIllustration.tongueUpFloor => 'Tongue up',
    EyeIllustration.headBackPalate => 'Head back, say aah',
    EyeIllustration.wipeTeeth => 'Dry the teeth',
    EyeIllustration.frontBite => 'Bite, lips back',
    EyeIllustration.frontOpen => 'Open, tongue down',
    EyeIllustration.upperArch => 'Upper, head back',
    EyeIllustration.lowerArch => 'Lower, tongue up',
    EyeIllustration.helperChildMouth => 'Knee-to-knee',
    _ => '',
  };

  // ---------------------------------------------------------------------
  // How-to
  // ---------------------------------------------------------------------

  Widget _buildHowToStep(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          '$_stepTitlePrefix · How to take the photos',
          '${p.photoCount} photo${p.photoCount == 1 ? '' : 's'} · $_flashSummary · ${p.distanceLabel.toLowerCase()} · about ${p.durationLabel.replaceAll('~', '')}',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _playInstructions,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: const Text('Play instructions aloud'),
            ),
          ),
        ),
        for (var i = 0; i < p.howTo.length; i++) _howToTile(i + 1, p.howTo[i]),
        if (p.helperTip != null) ...[
          InfoNote(
            title: p.helperTip!.$1,
            text: p.helperTip!.$2,
            icon: Icons.people_alt_outlined,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AnaemiaUi.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What a good photo looks like',
                style: TextStyle(
                  color: AnaemiaUi.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < p.examples.length; i++) ...[
                    Expanded(
                      child: _IllustratedHint(
                        p.examples[i].illustration,
                        p.examples[i].caption,
                      ),
                    ),
                    if (i != p.examples.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              InfoNote(
                icon: Icons.replay_rounded,
                text:
                    'After each photo the app scores sharpness, glare, darkness and ${_currentViewTargetLabel.toLowerCase()}. If a check fails you will see why and can retake — up to 3 attempts per photo (G-25).',
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _currentViewTargetLabel => p.views.first.target.coverageLabel;

  Widget _howToTile(int n, EyeHowToStep s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EyeIllustrationView(kind: s.illustration, size: 78),
          const SizedBox(width: 12),
          Expanded(child: AnaemiaUi.numberedStep(n, s.title, s.body)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Photos
  // ---------------------------------------------------------------------

  void _enterPhotosStep() {
    FocusScope.of(context).unfocus();
    _photosStartedAt = DateTime.now();
    _photos.clear();
    _attempts = 0;
    _pendingBytes = null;
    _pendingReport = null;
    _holdProgress = 0;
    _camera?.dispose();
    _camera = BiometricCameraController(
      mode: p.torchPreview
          ? ScanCameraMode.rearTorchMouth
          : ScanCameraMode.rearEyelid,
      resolutionPreset: ResolutionPreset.high,
      subjectTrack: SubjectTrackSpec.forTargets(p.views.map((v) => v.target)),
      onFrameMetricsUpdated: (t) {
        if (!mounted) return;
        setState(() {
          _brightness = t.brightness;
          _variance = t.frameVariance;
          _subjectInFrame = t.subjectInFrame;
          _subjectCoverage = t.subjectCoverage;
          _detectorActive = t.detectorActive;
          _subjectSeen = t.subjectSeen;
          _subjectLabel = t.subjectLabel;
          _subjectConfidence = t.subjectConfidence;
          _liveStream = _camera?.liveFaceTrackingActive ?? false;
        });
        // Spoken live coaching when the advice changes (throttled by the coach).
        if (_liveStream && _pendingReport == null && !_analysingPhoto) {
          final line = _coachingLine();
          if (line != _lastCoaching) {
            _lastCoaching = line;
            _say(
              line,
              tone: !_liveFramingOk
                  ? VoiceCueTone.outOfFrame
                  : _livePass
                  ? VoiceCueTone.scanning
                  : VoiceCueTone.warning,
            );
          }
        }
        if (_liveStream && _holdTimer == null) {
          _holdTimer = Timer.periodic(
            const Duration(milliseconds: 100),
            (_) => _tickHold(),
          );
        }
      },
    );
    _camera!.initialize();
    setState(() => _step = _photosIdx);
  }

  void _disposeCamera() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _camera?.dispose();
    _camera = null;
  }

  // Dim-room protocols expect a darker preview (the flash / camera LEDs
  // light the shot); bright-room protocols need 60–220 luma (ALG-CAP-03).
  bool get _liveLightOk => p.dimRoom
      ? _brightness <= 140
      : (_brightness >= 60 && _brightness <= 220);
  bool get _liveSharpOk => _variance >= 120;
  bool get _liveFramingOk => _subjectInFrame;
  bool get _livePass =>
      _liveStream && _liveLightOk && _liveSharpOk && _liveFramingOk;

  void _tickHold() {
    if (!mounted || _step != _photosIdx) return;
    if (_pendingReport != null || _analysingPhoto) return;
    final next = _livePass ? (_holdProgress + 0.05) : (_holdProgress - 0.10);
    final clamped = next.clamp(0.0, 1.0);
    if (clamped != _holdProgress) setState(() => _holdProgress = clamped);
    if (_holdProgress >= 1.0) {
      _holdProgress = 0;
      _onShutter();
    }
  }

  Future<void> _onShutter() async {
    if (_analysingPhoto ||
        _pendingReport != null ||
        _viewIndex >= p.views.length) {
      return;
    }
    setState(() => _analysingPhoto = true);
    final view = _currentView;
    Uint8List? bytes;
    PhotoQualityReport report;
    try {
      final cam = _camera;
      if (p.guardianRequired &&
          !p.newbornOnly &&
          !p.torchPreview &&
          cam != null &&
          cam.isCameraReady) {
        // Attention light: brief torch blink so the child looks at the phone.
        await cam.toggleTorch();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await cam.toggleTorch();
      }
      bytes = await cam?.captureStill(flash: view.flash ?? p.flash);
      if (bytes != null) {
        report = await analyzeEncodedPhoto(
          bytes,
          roi: view.roi,
          target: view.target,
        );
      } else {
        report = PhotoQualityReport.simulated(
          good: !_simulateBadPhoto,
          seed: _viewIndex * 10 + _attempts,
          target: view.target,
        );
      }
    } catch (_) {
      bytes = null;
      report = PhotoQualityReport.simulated(
        good: false,
        seed: _attempts,
        target: view.target,
      );
    }
    if (_hasCard) {
      report = report.withColourCard(report.overallPassed ? 2.4 : 3.8);
    }
    if (!mounted) return;
    setState(() {
      _attempts++;
      _pendingBytes = bytes;
      _pendingReport = report;
      _analysingPhoto = false;
      _holdProgress = 0;
    });
    _announceVerdict(report);
  }

  void _acceptPending() {
    final rep = _pendingReport;
    if (rep == null || !rep.overallPassed) return;
    _photos.add(
      EyePhoto(
        view: _currentView,
        quality: rep,
        attempts: _attempts,
        accepted: true,
        bytes: _pendingBytes,
      ),
    );
    _afterViewResolved();
  }

  void _retakePending() {
    setState(() {
      _pendingBytes = null;
      _pendingReport = null;
    });
  }

  void _markNotAssessed() {
    final rep =
        _pendingReport ??
        PhotoQualityReport.simulated(good: false, target: _currentView.target);
    _photos.add(
      EyePhoto(
        view: _currentView,
        quality: rep,
        attempts: _attempts,
        accepted: false,
        bytes: _pendingBytes,
      ),
    );
    _afterViewResolved();
  }

  void _afterViewResolved() {
    setState(() {
      _pendingBytes = null;
      _pendingReport = null;
      _attempts = 0;
    });
    if (_photos.length >= p.views.length) {
      _startAnalysis();
    }
  }

  Widget _buildPhotosStep(BuildContext context) {
    final cam = _camera;
    if (cam == null) return const SizedBox.shrink();
    final allDone = _viewIndex >= p.views.length;
    final view = _currentView;
    final strokeColor = _pendingReport != null
        ? Colors.white
        : _livePass
        ? const Color(0xFF34D399)
        : _liveStream
        ? const Color(0xFFFBBF24)
        : Colors.white.withValues(alpha: 0.9);

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => LiveBiometricCameraSurface(
            controller: cam,
            fullBleed: true,
            overlayPainter: EyeGuidePainter(
              target: view.target,
              strokeColor: strokeColor,
              holdProgress: _holdProgress,
              pulse: _pulse.value,
              captured: _pendingReport != null,
              showCardSlot: _hasCard,
              variant: view.zoneCode ?? view.id,
            ),
          ),
        ),
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
                    'Cancel photos',
                    _cancelPhotos,
                  ),
                  const SizedBox(width: 8),
                  if (!allDone) ...[
                    // Position picture for this photo (same drawing as the
                    // how-to step) so the pose is clear at a glance.
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00E5CC)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: EyeIllustrationView(
                        kind: view.illustration,
                        size: 44,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allDone
                              ? 'All ${p.photoCount} photos taken'
                              : 'Photo ${_viewIndex + 1} of ${p.photoCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          allDone ? 'Analysing…' : view.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _glassButton(
                    (view.flash ?? p.flash)
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    (view.flash ?? p.flash)
                        ? 'Flash fires on this photo'
                        : p.partnerModel
                        ? 'Phone flash off — the clip-on camera lights the retina'
                        : 'Flash off for this photo — use daylight',
                    null,
                    tint: (view.flash ?? p.flash)
                        ? const Color(0xFFFBBF24)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  _muteButton(glass: true),
                  const SizedBox(width: 6),
                  if (p.torchPreview)
                    _glassButton(
                      cam.torchEnabled
                          ? Icons.flashlight_on_rounded
                          : Icons.flashlight_off_rounded,
                      cam.torchEnabled
                          ? 'Torch on — lights the mouth while you frame'
                          : 'Torch off — tap to light the mouth',
                      () async {
                        await cam.toggleTorch();
                        if (mounted) setState(() {});
                      },
                      tint: cam.torchEnabled ? const Color(0xFFFDE68A) : null,
                    )
                  else
                    _glassButton(
                      Icons.cameraswitch_rounded,
                      'Switch camera',
                      () => cam.switchCameraLens(),
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
        if (_liveStream && _pendingReport == null && !allDone)
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 0),
                child: _trackingBanner(),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(top: false, child: _photosBottomDock(context)),
        ),
        if (_analysingPhoto)
          Container(
            color: Colors.black.withValues(alpha: 0.45),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Color(0xFF00E5CC),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Checking the photo…',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_pendingReport != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: PhotoReviewPanel(
              report: _pendingReport!,
              bytes: _pendingBytes,
              viewLabel: view.label,
              attempt: _attempts,
              maxAttempts: _maxAttempts,
              hasCard: _hasCard,
              onKeep: _acceptPending,
              onRetake: _retakePending,
              onNotAssessed: _markNotAssessed,
              onCancel: _cancelPhotos,
              notAssessedLabel: p.partnerModel
                  ? 'Mark not gradable & continue'
                  : 'Mark not assessed & continue',
              notAssessedHint: p.notAssessedHint,
              placeholder: EyeIllustrationView(
                kind: _pendingReport!.overallPassed
                    ? p.examples.first.illustration
                    : EyeIllustration.blurryExample,
                size: 92,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _cancelPhotos() async {
    final leave = await _confirmLeavePhotos();
    if (!leave || !mounted) return;
    _disposeCamera();
    Navigator.of(context).pop();
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

  Widget _photosBottomDock(BuildContext context) {
    final coaching = _coachingLine();
    final viewFlash = _viewIndex < p.views.length
        ? (p.views[_viewIndex].flash ?? p.flash)
        : p.flash;
    final (fourthLabel, fourthPass, fourthIcon, fourthOff) = p.cardOffered
        ? ('Card', _hasCard ? true : null, Icons.grid_on_rounded, 'No card')
        : _hasConnect
        ? ('Camera', _connected ? true : false, Icons.camera_rounded, 'Camera')
        : viewFlash
        ? ('Flash', true, Icons.flash_on_rounded, 'Flash')
        : ('Daylight', true, Icons.light_rounded, 'Daylight');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            coaching,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _liveChip(
                  p.dimRoom ? 'Dim room' : 'Light',
                  _liveStream ? _liveLightOk : null,
                  p.dimRoom
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _liveChip(
                  'Sharp',
                  _liveStream ? _liveSharpOk : null,
                  Icons.center_focus_strong_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _liveChip(
                  _liveStream && _trackSpec != null
                      ? '${_trackSpec!.subjectName} ${(_subjectCoverage * 100).round()} %'
                      : 'Framing',
                  _liveStream ? _liveFramingOk : null,
                  Icons.crop_free_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _liveChip(
                  fourthLabel,
                  fourthPass,
                  fourthIcon,
                  offLabel: fourthOff,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < p.views.length; i++) ...[
                      _slotThumb(i),
                      if (i != p.views.length - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Take photo',
                child: GestureDetector(
                  onTap: (_pendingReport != null || _analysingPhoto)
                      ? null
                      : _onShutter,
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_pendingReport != null || _analysingPhoto)
                            ? Colors.white38
                            : Colors.white,
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        color: Color(0xFF0F172A),
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(width: 38),
            ],
          ),
          if (_showTestControls) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _testChip(
                  'Simulate good photo',
                  !_simulateBadPhoto,
                  () => setState(() => _simulateBadPhoto = false),
                ),
                _testChip(
                  'Simulate bad photo',
                  _simulateBadPhoto,
                  () => setState(() => _simulateBadPhoto = true),
                ),
                for (final o in EyeDemoOutcome.values)
                  _testChip(
                    'Outcome: ${p.demoOutcomeLabels[o.name] ?? o.name}',
                    _demoOutcome == o,
                    () => setState(() => _demoOutcome = o),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  SubjectTrackSpec? get _trackSpec =>
      SubjectTrackSpec.forTarget(_currentView.target);

  /// Face-scan style status pill: "Teeth not in frame" (amber) while the
  /// detector cannot see the subject, "Teeth detected · hold still" (green)
  /// once it can.
  Widget _trackingBanner() {
    final spec = _trackSpec;
    final name = spec?.subjectName ?? 'Subject';
    final ok = _liveFramingOk;
    final String text;
    if (!ok) {
      text = _detectorActive && !_subjectSeen
          ? '$name not in frame — ${spec?.notSeenHint ?? _currentView.coaching}'
          : '$name not in frame — ${_coachingLine()}';
    } else {
      final conf = _subjectLabel != null && _subjectConfidence > 0
          ? ' · ${_subjectLabel!} ${(_subjectConfidence * 100).round()} %'
          : '';
      text = !_liveLightOk
          ? '$name detected$conf — ${_coachingLine()}'
          : !_liveSharpOk
          ? '$name detected$conf — hold still'
          : '$name detected$conf — hold still, capturing';
    }
    final bg = ok ? const Color(0xFF065F46) : const Color(0xFF92400E);
    final fg = ok ? const Color(0xFF6EE7B7) : const Color(0xFFFDE68A);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _coachingLine() {
    if (_analysingPhoto) return 'Checking the photo…';
    if (!_liveStream) return _currentView.coaching;
    if (!_liveFramingOk) {
      final spec = _trackSpec;
      if (_detectorActive && !_subjectSeen && spec != null) {
        return '${spec.subjectName} not seen yet. ${spec.notSeenHint}';
      }
      return switch (_currentView.target) {
        PhotoTarget.sclera =>
          'Move the eye inside the guide — show the white of the eye.',
        PhotoTarget.pupilLens => 'Centre the pupil in the ring.',
        PhotoTarget.bothPupils => 'Both eyes inside the frame — face straight.',
        PhotoTarget.fundus => 'Rest the eyepiece on the eye and keep it still.',
        PhotoTarget.lowerEyelid => 'Move the eye inside the guide.',
        PhotoTarget.skinPatch =>
          'Bare skin in the guide, card beside it — move clothing away.',
        PhotoTarget.footSole =>
          'Whole sole in the frame, toes at the top — move the phone back.',
        PhotoTarget.lesion => 'Centre the spot in the ring, 10–15 cm away.',
        PhotoTarget.oralMucosa =>
          'Open wider and pull the cheek out — fill the guide with the lining.',
        PhotoTarget.teethArch =>
          'Pull the lips back — show the whole row of teeth inside the guide.',
      };
    }
    if (!_liveLightOk) {
      if (p.dimRoom) return 'Too bright — dim the room so the pupils open.';
      return _brightness < 60
          ? 'Too dark — move closer to a window.'
          : 'Too bright — tilt the phone slightly or move out of direct light.';
    }
    if (!_liveSharpOk) return 'Hold still — tap the ${p.partNoun} to focus.';
    return _holdProgress > 0
        ? 'Hold still… capturing'
        : 'Looks good — hold still for 2 s or tap the shutter.';
  }

  Widget _liveChip(
    String label,
    bool? pass,
    IconData icon, {
    String? offLabel,
  }) {
    final Color color = pass == null
        ? Colors.white.withValues(alpha: 0.55)
        : pass
        ? const Color(0xFF34D399)
        : const Color(0xFFFBBF24);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            pass == null
                ? icon
                : (pass
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded),
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              pass == null && offLabel != null ? offLabel : label,
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

  Widget _slotThumb(int i) {
    final done = i < _photos.length;
    final current = i == _viewIndex;
    final photo = done ? _photos[i] : null;
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: done ? 0.16 : 0.06),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: current
                  ? const Color(0xFF00E5CC)
                  : Colors.white.withValues(alpha: 0.18),
              width: current ? 1.6 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photo?.bytes != null)
                Image.memory(photo!.bytes!, fit: BoxFit.cover),
              Center(
                child: Text(
                  p.views[i].chipLabel ?? p.views[i].shortLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: photo?.bytes != null ? 0.0 : 0.9,
                    ),
                    fontSize: p.views[i].chipLabel != null ? 9.5 : 11,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (done)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Icon(
                    photo!.accepted
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 13,
                    color: photo.accepted
                        ? const Color(0xFF34D399)
                        : const Color(0xFFF87171),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _testChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10.5)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      selectedColor: const Color(0xFF00E5CC).withValues(alpha: 0.25),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      labelStyle: const TextStyle(color: Colors.white),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
    );
  }

  // ---------------------------------------------------------------------
  // Analyse
  // ---------------------------------------------------------------------

  void _startAnalysis() {
    _disposeCamera();
    _stageDone = 0;
    setState(() => _step = _analyseIdx);
    _stageTimer?.cancel();
    _stageTimer = Timer.periodic(const Duration(milliseconds: 420), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _stageDone++);
      if (_stageDone >= p.analysisStages.length) {
        t.cancel();
        _finishAndOpenResult();
      }
    });
  }

  void _finishAndOpenResult() {
    final appState = AppStateScope.of(context);
    final answers = EyeAnswers(
      questionIds: Set.unmodifiable(_ticked),
      otherNote: _otherCtrl.text.trim().isEmpty ? null : _otherCtrl.text.trim(),
      hasColourCard: _hasCard,
      colourErrorDe: _hasCard ? 2.4 : null,
      photographerRole: _photographerRole,
      partnerConsent: _partnerConsent,
      consentGiven: appState.activeSubject.hasConsent(p.consentType),
      operatedEyes: _operatedEyes,
      onRequest: widget.onRequest,
      bodyLocation: _bodyLocation,
      durationBucket: _duration,
      skinType: _skinType,
      abcdeFlags: Set.unmodifiable(_abcde),
      newbornAgeHours: appState.activeSubject.ageHoursForNewborn,
      gestationWeeks: appState.activeSubject.gestationWeeksForNewborn,
      birthWeightKg: appState.activeSubject.weightKg,
      tobaccoStatus: _needsTobacco ? _tobacco : null,
      brushingPerDay: _needsHabits ? _brushing : null,
      fluoridePaste: _needsHabits ? _fluoride : null,
      sweetsPerDay: _needsHabits ? _sweets : null,
      nightFeeding: _needsHabits && _nightFeeding,
      lastDentalVisit: _needsHabits ? _lastVisit : null,
    );
    final started = _photosStartedAt ?? DateTime.now();
    final subjectId = appState.activeSubject.id;
    final result = buildEyeSession(
      protocol: p,
      subject: appState.activeSubject,
      answers: answers,
      photos: List.unmodifiable(_photos),
      demoOutcome: _demoOutcome,
      durationSeconds: DateTime.now()
          .difference(started)
          .inSeconds
          .clamp(1, 900),
      previousDental: p.id == 'dental_caries'
          ? appState.dentalExams
                .where((e) => e.subjectId == subjectId)
                .firstOrNull
          : null,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => EyeResultScreen(result: result)),
    );
  }

  Widget _buildAnalysingStep(BuildContext context) {
    final stages = p.analysisStages;
    final progress = (_stageDone / stages.length).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          '$_stepTitlePrefix · Analysing your photos',
          '${_photos.where((x) => x.accepted).length} of ${p.photoCount} photos accepted · ${p.partnerModel ? 'partner grading takes a moment' : 'this takes a few seconds'}',
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AnaemiaUi.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AnaemiaUi.outline,
                  color: AnaemiaUi.primary,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < stages.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: i < _stageDone
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: MirrorColors.successFg,
                                size: 22,
                              )
                            : i == _stageDone
                            ? const Padding(
                                padding: EdgeInsets.all(2),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Icon(
                                Icons.radio_button_off_rounded,
                                color: AnaemiaUi.outline,
                                size: 22,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          stages[i],
                          style: TextStyle(
                            color: i <= _stageDone
                                ? AnaemiaUi.ink
                                : AnaemiaUi.muted,
                            fontSize: 13,
                            fontWeight: i == _stageDone
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
        const SizedBox(height: 12),
        InfoNote(
          icon: Icons.lock_outline_rounded,
          text: p.partnerModel
              ? 'Only de-identified retina images are sent to the partner. Referable or glaucoma-suspect results are also sent for specialist review (IMG-10).'
              : 'Photos are analysed for screening only. High, Refer, Ulcer, Suspicious or borderline results are also sent for specialist review (IMG-10) before a case is confirmed.',
        ),
      ],
    );
  }
}

class _IllustratedHint extends StatelessWidget {
  const _IllustratedHint(this.kind, this.caption);

  final EyeIllustration kind;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) =>
              EyeIllustrationView(kind: kind, size: c.maxWidth),
        ),
        const SizedBox(height: 5),
        Text(
          caption,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AnaemiaUi.ink,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
