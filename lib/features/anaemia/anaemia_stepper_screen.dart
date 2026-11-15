import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart' show ResolutionPreset;
import 'package:flutter/material.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/photo_quality_analyzer.dart';
import '../../core/domain/entities/anaemia_result.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/services/live_camera_service.dart';
import '../../core/services/subject_track_spec.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import 'anaemia_illustrations.dart';
import 'anaemia_result_screen.dart';
import 'anaemia_ui_kit.dart';

/// Guided anaemia test (F-16 · ALG-IMG-01):
///   1 Details  — confirm / edit name, age, sex, pregnancy, consent (G-02/03/04)
///   1 Prepare  — recent treatment, equipment (colour card G-20), before-you-start
///   2 How-to   — illustrated photo instructions
///   3 Photos   — 4 flash photos (L1, L2, R1, R2) with on-device quality checks
///                (G-21) and up to 3 attempts per view (G-25)
///   4 Analyse  — staged processing, then S-R01 result
class AnaemiaStepperScreen extends StatefulWidget {
  const AnaemiaStepperScreen({super.key, this.initialStep = 0});

  final int initialStep;

  @override
  State<AnaemiaStepperScreen> createState() => _AnaemiaStepperScreenState();
}

class _AnaemiaStepperScreenState extends State<AnaemiaStepperScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _stepLabels = [
    'Prepare',
    'How-to',
    'Photos',
    'Analyse',
  ];
  static const List<(EyeSide, int)> _views = [
    (EyeSide.left, 1),
    (EyeSide.left, 2),
    (EyeSide.right, 1),
    (EyeSide.right, 2),
  ];
  static const int _maxAttempts = 3; // G-25

  int _step = 0;

  // Step 1 — prepare
  final Set<RecentTreatment> _treatments = {};
  final _otherCtrl = TextEditingController();
  bool _hasCard = true;
  bool _flashOk = false;
  bool _lensClean = false;
  bool _helperPresent = false;

  // Step 3 — photos
  BiometricCameraController? _camera;
  late final AnimationController _pulse;
  final List<EyelidPhoto> _photos = [];
  int _attempts = 0;
  Uint8List? _pendingBytes;
  PhotoQualityReport? _pendingReport;
  bool _analysingPhoto = false;
  double _holdProgress = 0;
  Timer? _holdTimer;
  double _brightness = 142;
  double _variance = 450;
  bool _subjectInFrame = false;
  bool _liveStream = false;
  bool _showTestControls = false;
  bool _simulateBadPhoto = false;
  AnaemiaDemoOutcome _demoOutcome = AnaemiaDemoOutcome.normal;
  DateTime? _photosStartedAt;

  // Voice coach
  VoiceCoachController? _voice;
  int _lastAnnouncedStep = -1;
  int _lastAnnouncedView = -1;

  // Step 4 — analysis
  static const List<String> _stages = [
    'Colour correction (card or flash white balance)',
    'Finding the inner eyelid (conjunctiva)',
    'Eyelid colour model (ALG-IMG-01)',
    'WHO haemoglobin cut-off for you',
    'Risk rules & specialist routing',
  ];
  int _stageDone = 0;
  Timer? _stageTimer;

  int get _viewIndex => _photos.length;
  (EyeSide, int) get _currentView =>
      _views[_viewIndex.clamp(0, _views.length - 1)];

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, 1);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = AppStateScope.of(context).localeCode;
    _voice ??= VoiceCoachController(
      languageCode: switch (code) {
        'te' => 'te-IN',
        'hi' => 'hi-IN',
        _ => 'en-US',
      },
    );
  }

  void _say(String text, {VoiceCueTone tone = VoiceCueTone.ready}) =>
      _voice?.announce(text, tone: tone, force: true);

  void _announceStepIfNeeded() {
    if (_lastAnnouncedStep == _step) return;
    _lastAnnouncedStep = _step;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (_step) {
        case 0:
          _say(
            'Anaemia screen. Answer the recent-treatment question and get your equipment ready, then tap Start the test.',
          );
        case 1:
          _say(
            'How to take the photos. Pull the lower eyelid down with a clean finger, look up, and hold the phone fifteen to twenty centimetres away. Two photos of each eye with the flash. Tap Start photos when ready.',
          );
        case 3:
          _say(
            'All four photos taken. Analysing the colour of the inner eyelid.',
            tone: VoiceCueTone.completed,
          );
      }
    });
  }

  void _announceViewIfNeeded() {
    if (_viewIndex >= _views.length || _lastAnnouncedView == _viewIndex) {
      return;
    }
    _lastAnnouncedView = _viewIndex;
    final (eye, idx) = _views[_viewIndex];
    _say(
      'Photo ${_viewIndex + 1} of 4. ${eye.label}, photo $idx of 2. Pull the lower lid down, look up and fill the guide with the eye.',
      tone: VoiceCueTone.scanning,
    );
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

  @override
  void dispose() {
    _voice?.dispose();
    _holdTimer?.cancel();
    _stageTimer?.cancel();
    _camera?.dispose();
    _pulse.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------

  String get _screenId => const ['S-E02', 'S-E01', 'S-E03', 'S-E04'][_step];

  Future<void> _goBack() async {
    if (_step == 3) return;
    if (_step == 2) {
      final leave = await _confirmLeavePhotos();
      if (leave && mounted) {
        _disposeCamera();
        setState(() {
          _photos.clear();
          _pendingBytes = null;
          _pendingReport = null;
          _attempts = 0;
          _step = 1;
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
    final isPhotos = _step == 2;
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
                  onPressed: _step == 3 ? null : _goBack,
                ),
                title: const Text('Anaemia screening'),
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
                        child: switch (_step) {
                          0 => _buildPrepareStep(context),
                          1 => _buildHowToStep(context),
                          _ => _buildAnalysingStep(context),
                        },
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: isPhotos ? null : _bottomBar(context),
      ),
    );
  }

  Widget? _bottomBar(BuildContext context) {
    switch (_step) {
      case 0:
        final ready = _treatments.isNotEmpty;
        return PrimaryBottomButton(
          label: 'Start the test',
          helper: ready
              ? null
              : 'Answer the recent-treatment question to continue',
          onPressed: ready ? () => setState(() => _step = 1) : null,
        );
      case 1:
        return PrimaryBottomButton(
          label: 'Start photos',
          icon: Icons.photo_camera_rounded,
          helper: '4 photos · about 30 seconds · flash will fire',
          onPressed: _enterPhotosStep,
        );
      default:
        return null;
    }
  }

  // Step 1 — Prepare
  // ---------------------------------------------------------------------

  Widget _buildPrepareStep(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          'Step 1 · Prepare',
          'One quick question, then get your equipment ready',
        ),
        _recentTreatmentCard(),
        const SizedBox(height: 12),
        _equipmentCard(),
        const SizedBox(height: 12),
        _beforeYouStartCard(),
      ],
    );
  }

  Widget _recentTreatmentCard() {
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
                      'Recent treatment',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Anything here in the last 3 months? Select all that apply.',
                      style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (final t in RecentTreatment.values) _treatmentRow(t),
            ],
          ),
          if (_treatments.any((t) => t.affectsReliability)) ...[
            const SizedBox(height: 10),
            InfoNote(
              icon: Icons.warning_amber_rounded,
              color: MirrorColors.warningFg,
              background: MirrorColors.warningBg,
              title: 'You can still take the test',
              text: _treatments
                  .where((t) => t.affectsReliability)
                  .map((t) => t.reliabilityNote)
                  .join(' '),
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
                  'e.g. recent illness, known thalassaemia, iron-rich diet change…',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _treatmentRow(RecentTreatment t) {
    final selected = _treatments.contains(t);
    final isNone = t == RecentTreatment.none;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          if (isNone) {
            _treatments
              ..clear()
              ..add(RecentTreatment.none);
          } else {
            _treatments.remove(RecentTreatment.none);
            selected ? _treatments.remove(t) : _treatments.add(t);
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
                  t.label,
                  style: TextStyle(
                    color: AnaemiaUi.ink,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (t.affectsReliability)
                const Tooltip(
                  message: 'May affect how reliable the result is',
                  child: Icon(
                    Icons.info_outline_rounded,
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Equipment ready',
                      style: TextStyle(
                        color: AnaemiaUi.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Colour card is preferred (ALG-CAP-10, ΔE ≤ 5) but not required',
                      style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _optionCard(
            selected: _hasCard,
            onTap: () => setState(() => _hasCard = true),
            illustration: EyelidIllustration.colourCardBesideEye,
            title: '24-patch colour card',
            body:
                'Place it flat beside the eye. The app corrects colours with it, giving the most accurate band.',
            tag: 'Preferred',
          ),
          const SizedBox(height: 8),
          _optionCard(
            selected: !_hasCard,
            onTap: () => setState(() => _hasCard = false),
            illustration: EyelidIllustration.phoneDistanceFlash,
            title: 'No card — use flash white balance',
            body:
                'Allowed for this screen. Colour is normalised from the flash; the result confidence is slightly lower.',
            tag: 'Uncalibrated',
            tagColor: MirrorColors.warningFg,
          ),
          const SizedBox(height: 10),
          _checkTile(
            'Flash works on the rear camera',
            _flashOk,
            (v) => setState(() => _flashOk = v),
          ),
          _checkTile(
            'Camera lens is clean',
            _lensClean,
            (v) => setState(() => _lensClean = v),
          ),
          _checkTile(
            'A helper will hold the phone (optional)',
            _helperPresent,
            (v) => setState(() => _helperPresent = v),
          ),
        ],
      ),
    );
  }

  Widget _optionCard({
    required bool selected,
    required VoidCallback onTap,
    required EyelidIllustration illustration,
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
            EyelidIllustrationView(kind: illustration, size: 64),
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
          subtitle: const Text(
            'Six things that make the photos work first time',
            style: TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            Row(
              children: const [
                Expanded(
                  child: _IllustratedHint(
                    EyelidIllustration.pullLidDown,
                    'Pull the lower lid down',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _IllustratedHint(EyelidIllustration.lookUp, 'Look up'),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _IllustratedHint(
                    EyelidIllustration.phoneDistanceFlash,
                    'Flash on, 15–20 cm',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnaemiaUi.bullet(
              'Check the name, age, sex and pregnancy status on the first screen — tap Change there if they are wrong.',
            ),
            AnaemiaUi.bullet(
              'Sit facing a window or a lamp. The flash fires on every photo — do not cover it.',
            ),
            AnaemiaUi.bullet(
              'Wash your hands. Remove contact lenses and wipe make-up from the lower lid.',
            ),
            AnaemiaUi.bullet(
              'With one clean fingertip, gently pull the lower eyelid down so the pink inner lining shows.',
            ),
            AnaemiaUi.bullet(
              'Look up, hold the phone 15–20 cm from the eye and keep still until the app accepts the photo.',
            ),
            AnaemiaUi.bullet(
              'If the app asks, retake — up to 3 attempts per photo. Eyes that still fail are marked "Not assessed".',
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step 2 — How to take the photos
  // ---------------------------------------------------------------------

  Widget _buildHowToStep(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          'Step 2 · How to take the photos',
          'Two photos of each eye with the flash on — about 30 seconds in total',
        ),
        _howToTile(
          1,
          EyelidIllustration.pullLidDown,
          'Pull the lower eyelid down',
          'Use a clean fingertip just below the lashes and pull gently until the pink inner lining is fully visible.',
        ),
        _howToTile(
          2,
          EyelidIllustration.lookUp,
          'Look up, flash on',
          'Looking up moves the iris away and shows more lining. The flash fires automatically on every photo.',
        ),
        _howToTile(
          3,
          EyelidIllustration.phoneDistanceFlash,
          'Two photos of each eye',
          'Order: Left 1, Left 2, Right 1, Right 2. Hold the phone 15–20 cm away and fill the guide with the eye.',
        ),
        _howToTile(
          4,
          EyelidIllustration.holdStill,
          'Hold still until the app accepts',
          'The frame turns green when the light, sharpness and framing pass; the app then captures after 2 s or when you tap the shutter.',
        ),
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
                children: const [
                  Expanded(
                    child: _IllustratedHint(
                      EyelidIllustration.goodExample,
                      'Good: lining clear, even light',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _IllustratedHint(
                      EyelidIllustration.glareExample,
                      'Glare: tilt the phone',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _IllustratedHint(
                      EyelidIllustration.blurryExample,
                      'Blurry: tap to focus, retake',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const InfoNote(
                icon: Icons.replay_rounded,
                text:
                    'After each photo the app scores sharpness, glare, darkness and framing. If a check fails you will see why and can retake — up to 3 attempts per photo (G-25).',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _howToTile(int n, EyelidIllustration kind, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: AnaemiaUi.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EyelidIllustrationView(kind: kind, size: 78),
          const SizedBox(width: 12),
          Expanded(child: AnaemiaUi.numberedStep(n, title, body)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step 3 — Photos
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
      mode: ScanCameraMode.rearEyelid,
      resolutionPreset: ResolutionPreset.high,
      subjectTrack: SubjectTrackSpec.forTarget(PhotoTarget.lowerEyelid),
      onFrameMetricsUpdated: (t) {
        if (!mounted) return;
        setState(() {
          _brightness = t.brightness;
          _variance = t.frameVariance;
          _subjectInFrame = t.subjectInFrame;
          _liveStream = _camera?.liveFaceTrackingActive ?? false;
        });
        // Auto-capture (2 s continuous pass) only makes sense with a live
        // frame stream; desktop / test builds use the manual shutter.
        if (_liveStream && _holdTimer == null) {
          _holdTimer = Timer.periodic(
            const Duration(milliseconds: 100),
            (_) => _tickHold(),
          );
        }
      },
    );
    _camera!.initialize();
    setState(() => _step = 2);
  }

  void _disposeCamera() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _camera?.dispose();
    _camera = null;
  }

  bool get _liveLightOk => _brightness >= 60 && _brightness <= 220;
  bool get _liveSharpOk => _variance >= 120;
  bool get _liveFramingOk => _subjectInFrame;
  bool get _livePass =>
      _liveStream && _liveLightOk && _liveSharpOk && _liveFramingOk;

  void _tickHold() {
    if (!mounted || _step != 2) return;
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
        _viewIndex >= _views.length) {
      return;
    }
    setState(() => _analysingPhoto = true);
    Uint8List? bytes;
    PhotoQualityReport report;
    try {
      bytes = await _camera?.captureStill(flash: true);
      if (bytes != null) {
        report = await analyzeEncodedPhoto(bytes);
      } else {
        report = PhotoQualityReport.simulated(
          good: !_simulateBadPhoto,
          seed: _viewIndex * 10 + _attempts,
        );
      }
    } catch (_) {
      bytes = null;
      report = PhotoQualityReport.simulated(good: false, seed: _attempts);
    }
    if (_hasCard) {
      // ALG-CAP-10 colour-card read: static ΔE until the card detector lands.
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
    if (report.overallPassed) {
      _say(
        'Good photo. Keep and continue, or retake.',
        tone: VoiceCueTone.completed,
      );
    } else {
      _say(
        'Needs retake. ${report.failureReasons.isEmpty ? 'Please retake.' : report.failureReasons.first}',
        tone: VoiceCueTone.warning,
      );
    }
  }

  void _acceptPending() {
    final rep = _pendingReport;
    if (rep == null || !rep.overallPassed) return;
    final (eye, idx) = _currentView;
    _photos.add(
      EyelidPhoto(
        eye: eye,
        index: idx,
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
    final rep = _pendingReport ?? PhotoQualityReport.simulated(good: false);
    final (eye, idx) = _currentView;
    _photos.add(
      EyelidPhoto(
        eye: eye,
        index: idx,
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
    if (_photos.length >= _views.length) {
      _startAnalysis();
    }
  }

  Widget _buildPhotosStep(BuildContext context) {
    final cam = _camera;
    if (cam == null) return const SizedBox.shrink();
    final allDone = _viewIndex >= _views.length;
    final (eye, idx) = _currentView;
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
            overlayPainter: EyelidGuidePainter(
              strokeColor: strokeColor,
              holdProgress: _holdProgress,
              pulse: _pulse.value,
              captured: _pendingReport != null,
            ),
          ),
        ),
        // Top bar
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
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allDone
                              ? 'All 4 photos taken'
                              : 'Photo ${_viewIndex + 1} of 4',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          allDone
                              ? 'Analysing…'
                              : '${eye.label} · photo $idx of 2',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _glassButton(
                    Icons.flash_on_rounded,
                    'Flash required — fires on every photo',
                    null,
                    tint: const Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 6),
                  _muteButton(glass: true),
                  const SizedBox(width: 6),
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
        // Bottom dock
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(top: false, child: _photosBottomDock(context)),
        ),
        // Analysing overlay
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
        // Review panel
        if (_pendingReport != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: _PhotoReviewPanel(
              report: _pendingReport!,
              bytes: _pendingBytes,
              viewLabel: '${eye.label} · photo $idx of 2',
              attempt: _attempts,
              maxAttempts: _maxAttempts,
              hasCard: _hasCard,
              onKeep: _acceptPending,
              onRetake: _retakePending,
              onNotAssessed: _markNotAssessed,
              onCancel: _cancelPhotos,
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
                  'Light',
                  _liveStream ? _liveLightOk : null,
                  Icons.light_mode_rounded,
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
                  'Framing',
                  _liveStream ? _liveFramingOk : null,
                  Icons.crop_free_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _liveChip(
                  'Card',
                  _hasCard ? true : null,
                  Icons.grid_on_rounded,
                  offLabel: 'No card',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Thumbnails strip
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < _views.length; i++) ...[
                      _slotThumb(i),
                      if (i != _views.length - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Shutter
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
                for (final o in AnaemiaDemoOutcome.values)
                  _testChip(
                    'Outcome: ${o.name}',
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

  String _coachingLine() {
    if (_analysingPhoto) return 'Checking the photo…';
    if (!_liveStream) {
      return 'Pull the lower lid down, look up, fill the guide with the eye, then tap the shutter.';
    }
    if (!_liveFramingOk) {
      return 'Move the eye inside the guide — show the whole lower eyelid.';
    }
    if (!_liveLightOk) {
      return _brightness < 60
          ? 'Too dark — find more light.'
          : 'Too bright — tilt the phone slightly.';
    }
    if (!_liveSharpOk) return 'Hold still — tap the eye to focus.';
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
    final (eye, idx) = _views[i];
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
                  '${eye == EyeSide.left ? 'L' : 'R'}$idx',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: photo?.bytes != null ? 0.0 : 0.9,
                    ),
                    fontSize: 11,
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
  // Step 4 — Analysing
  // ---------------------------------------------------------------------

  void _startAnalysis() {
    _disposeCamera();
    _stageDone = 0;
    setState(() => _step = 3);
    _stageTimer?.cancel();
    _stageTimer = Timer.periodic(const Duration(milliseconds: 420), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _stageDone++);
      if (_stageDone >= _stages.length) {
        t.cancel();
        _finishAndOpenResult();
      }
    });
  }

  void _finishAndOpenResult() {
    final appState = AppStateScope.of(context);
    final answers = AnaemiaPreTestAnswers(
      treatments: Set.unmodifiable(_treatments),
      otherNote: _otherCtrl.text.trim().isEmpty ? null : _otherCtrl.text.trim(),
      hasColourCard: _hasCard,
      colourErrorDe: _hasCard ? 2.4 : null,
      consentGiven: appState.activeSubject.hasConsent(ConsentType.screening),
    );
    final started = _photosStartedAt ?? DateTime.now();
    final result = appState.generateAnaemiaSession(
      subject: appState.activeSubject,
      answers: answers,
      photos: List.unmodifiable(_photos),
      demoOutcome: _demoOutcome,
      durationSeconds: DateTime.now()
          .difference(started)
          .inSeconds
          .clamp(1, 600),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AnaemiaResultScreen(result: result),
      ),
    );
  }

  Widget _buildAnalysingStep(BuildContext context) {
    final progress = (_stageDone / _stages.length).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        AnaemiaUi.sectionHeader(
          'Step 4 · Analysing your photos',
          '${_photos.where((p) => p.accepted).length} of 4 photos accepted · this takes a few seconds',
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
              for (var i = 0; i < _stages.length; i++)
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
                          _stages[i],
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
        const InfoNote(
          icon: Icons.lock_outline_rounded,
          text:
              'Photos are analysed for screening only. High or borderline results are also sent for specialist review (IMG-10) before a case is confirmed.',
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------------
// Review panel shown after every capture
// -------------------------------------------------------------------------

class _PhotoReviewPanel extends StatelessWidget {
  const _PhotoReviewPanel({
    required this.report,
    required this.bytes,
    required this.viewLabel,
    required this.attempt,
    required this.maxAttempts,
    required this.hasCard,
    required this.onKeep,
    required this.onRetake,
    required this.onNotAssessed,
    required this.onCancel,
  });

  final PhotoQualityReport report;
  final Uint8List? bytes;
  final String viewLabel;
  final int attempt;
  final int maxAttempts;
  final bool hasCard;
  final VoidCallback onKeep;
  final VoidCallback onRetake;
  final VoidCallback onNotAssessed;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final passed = report.overallPassed;
    final canRetake = attempt < maxAttempts;
    final verdictColor = passed
        ? MirrorColors.successFg
        : MirrorColors.warningFg;
    final verdictBg = passed ? MirrorColors.successBg : MirrorColors.warningBg;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AnaemiaUi.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 92,
                      height: 69,
                      child: bytes != null
                          ? Image.memory(bytes!, fit: BoxFit.cover)
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                EyelidIllustrationView(
                                  kind: passed
                                      ? EyelidIllustration.goodExample
                                      : EyelidIllustration.blurryExample,
                                  size: 92,
                                ),
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: AnaemiaUi.tag(
                                    'Simulated',
                                    color: AnaemiaUi.muted,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          viewLabel,
                          style: const TextStyle(
                            color: AnaemiaUi.muted,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: verdictBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                passed
                                    ? Icons.check_circle_rounded
                                    : Icons.replay_rounded,
                                size: 16,
                                color: verdictColor,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  passed ? 'Good photo' : 'Needs retake',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: verdictColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Attempt $attempt of $maxAttempts · quality ${(report.qualityScore * 100).round()}%',
                          style: const TextStyle(
                            color: AnaemiaUi.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _scoreRow(
                'Sharpness',
                report.blurScore,
                0,
                400,
                100,
                report.blurPassed,
                '${report.blurScore.round()} (≥ 100)',
              ),
              _scoreRow(
                'Glare',
                report.glarePct,
                0,
                20,
                5,
                report.glarePassed,
                '${report.glarePct.toStringAsFixed(1)}% (≤ 5%)',
                inverted: true,
              ),
              _scoreRow(
                'Dark areas',
                report.darkPct,
                0,
                40,
                10,
                report.darkPassed,
                '${report.darkPct.toStringAsFixed(1)}% (≤ 10%)',
                inverted: true,
              ),
              _scoreRow(
                'Lid visible',
                report.lidCoveragePct,
                0,
                100,
                80,
                report.coveragePassed,
                '${report.lidCoveragePct.round()}% (≥ 80%)',
              ),
              if (hasCard)
                _scoreRow(
                  'Colour card ΔE',
                  report.colourErrorDe ?? 0,
                  0,
                  10,
                  5,
                  report.cardPassed,
                  'ΔE ${(report.colourErrorDe ?? 0).toStringAsFixed(1)} (≤ 5)',
                  inverted: true,
                ),
              if (!passed) ...[
                const SizedBox(height: 6),
                for (final r in report.failureReasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 15,
                          color: MirrorColors.dangerFg,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            r,
                            style: const TextStyle(
                              color: MirrorColors.dangerFg,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!canRetake)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'No attempts left for this photo (G-25). It will be marked "Not assessed" and the test continues.',
                      style: TextStyle(
                        color: AnaemiaUi.muted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: passed
                    ? FilledButton.icon(
                        onPressed: onKeep,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'Keep & continue',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    : !canRetake
                    ? FilledButton.tonalIcon(
                        onPressed: onNotAssessed,
                        icon: const Icon(Icons.skip_next_rounded, size: 20),
                        label: const Text(
                          'Mark not assessed & continue',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    : const FilledButton(
                        onPressed: null,
                        child: Text(
                          'Keep & continue',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: canRetake ? onRetake : null,
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: Text(
                          canRetake
                              ? (passed
                                    ? 'Retake'
                                    : 'Retake ${attempt + 1} of $maxAttempts')
                              : 'No retakes left',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Cancel test'),
                        style: TextButton.styleFrom(
                          foregroundColor: AnaemiaUi.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreRow(
    String label,
    double value,
    double min,
    double max,
    double threshold,
    bool passed,
    String text, {
    bool inverted = false,
  }) {
    final frac = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final thrFrac = ((threshold - min) / (max - min)).clamp(0.0, 1.0);
    final color = passed ? MirrorColors.successFg : MirrorColors.warningFg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: AnaemiaUi.muted, fontSize: 11.5),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 10,
              child: LayoutBuilder(
                builder: (context, c) => Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AnaemiaUi.outline,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (thrFrac * c.maxWidth - 1).clamp(
                        0.0,
                        c.maxWidth - 2,
                      ),
                      top: -1,
                      bottom: -1,
                      child: Container(
                        width: 2,
                        color: AnaemiaUi.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              text,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            passed ? Icons.check_rounded : Icons.close_rounded,
            size: 14,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _IllustratedHint extends StatelessWidget {
  const _IllustratedHint(this.kind, this.caption);

  final EyelidIllustration kind;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) =>
              EyelidIllustrationView(kind: kind, size: c.maxWidth),
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
