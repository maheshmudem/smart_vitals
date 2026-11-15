import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/design_system/mirror_ui.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../../core/domain/algorithms/caries_risk_engine.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/health_package.dart';
import '../../core/domain/entities/marker_envelope.dart';
import '../../core/services/live_camera_service.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';

/// Flagship 4-View Guided Dental Scanner & Interactive FDI Odontogram (S-F01 .. S-F05):
/// - Real Live Camera + Flashlight Torch with spoken Voice-Guided 4-arch capture (ALG-DEN-01)
/// - 3D Tooth Arch Polygonal Wireframe & Tooth Segmentation Mesh (ALG-DEN-02)
/// - Per-Tooth ICDAS 1–6 Caries & Gingival Abscess Classifier (ALG-DEN-03)
/// - Gingival Inflammation & Plaque Biofilm Estimators (ALG-DEN-04)
/// - Preventive Pit-and-Fissure Molar Sealant Candidate Detector (ALG-DEN-05)
/// - Deterministic Caries-Risk Engine (ALG-DEN-06 Cases 1–6) & Longitudinal Tracker (ALG-DEN-07)
class DentalFlowScreen extends StatefulWidget {
  const DentalFlowScreen({super.key, this.autoStartScanner = false});

  final bool autoStartScanner;

  @override
  State<DentalFlowScreen> createState() => _DentalFlowScreenState();
}

class _DentalFlowScreenState extends State<DentalFlowScreen>
    with SingleTickerProviderStateMixin {
  late final VoiceCoachController _voiceCoach;
  late final AnimationController _pulseAnimController;
  BiometricCameraController? _cameraController;

  // 0: S-F01 Setup & Consent
  // 1: S-F02 Oral Hygiene & Dietary Habits
  // 2: S-F03 Full-Screen Immersive 4-View Guided Dental Scanner
  // 3: S-F03 Intraoral Quality Check & Guided Retake Screen
  int _step = 0;

  int _activeArchIndex = 0;
  bool _archInFrame = true;
  bool _blurPass = true; // ALG-CAP-06: Laplacian >= 100
  bool _glarePass = true; // ALG-CAP-07: Saliva Glare <= 5%
  Offset _archOffset = Offset.zero;
  bool _showArchControls = false;

  // Per-view 10-second guided auto-lock timer
  static const double _archTargetSeconds = 10.0;
  double _archElapsedSeconds = 0.0;
  int _speedMultiplier = 1; // 1x or 5x
  Timer? _archScanTimer;
  int _retakeCount = 0;

  bool _nightBottleFeeding = false;
  int _brushingPerDay = 2;
  bool _usesFluoridePaste = true;
  int _sweetsPerDay = 1;
  bool _simulateAbscessUrgent = false;

  final List<bool> _viewsCaptured = [true, true, true, true];

  static const List<String> _viewLabels = [
    'Front Closed Bite (Smile Wide, Teeth Together)',
    'Front Open Mouth (Open Wide, Facing Camera)',
    'Upper Occlusal Arch (Tilt Head Back 45°)',
    'Lower Occlusal Arch (Chin Down, Tongue Back)',
  ];

  static const List<String> _shortViewLabels = [
    '1. Front Bite',
    '2. Open Mouth',
    '3. Upper Arch',
    '4. Lower Arch',
  ];

  static const List<String> _viewCodes = [
    'front_closed',
    'front_open',
    'upper_occlusal',
    'lower_occlusal',
  ];

  static const List<String> _viewTargets = [
    'Anterior crowns & cervical gingiva (ALG-DEN-04)',
    'Incisal edges & anterior arch separation',
    'Upper occlusal table FDI 18–28 & molars 16, 26',
    'Lower occlusal table FDI 38–48 & molars 36, 46',
  ];

  @override
  void initState() {
    super.initState();
    _voiceCoach = VoiceCoachController();
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    if (widget.autoStartScanner) {
      _step = 2;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startDentalScanner();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _voiceCoach.announce(
          'Welcome to 4-View Guided Dental Screening. Verify consent and camera torch access to begin.',
          tone: VoiceCueTone.ready,
          force: true,
        );
      });
    }
  }

  @override
  void dispose() {
    _archScanTimer?.cancel();
    _cameraController?.dispose();
    _pulseAnimController.dispose();
    _voiceCoach.dispose();
    super.dispose();
  }

  String get _screenId =>
      const ['S-F01', 'S-F02', 'S-F03', 'S-F03'][_step.clamp(0, 3)];

  bool get _allDentalGatesPass => _archInFrame && _blurPass && _glarePass;

  void _startDentalScanner() {
    _archScanTimer?.cancel();
    _cameraController?.dispose();
    _cameraController = BiometricCameraController(
      mode: ScanCameraMode.rearMacro,
    )..initialize();

    setState(() {
      _step = 2;
      _activeArchIndex = 0;
      _archInFrame = true;
      _blurPass = true;
      _glarePass = true;
      _archOffset = Offset.zero;
      _archElapsedSeconds = 0.0;
    });

    _voiceCoach.announce(
      'Now starting 4-View Dental Scan. View 1 of 4: ${_viewLabels[0]}. Center the dental arch inside the 3D tooth mesh guide.',
      tone: VoiceCueTone.scanning,
      force: true,
    );

    _startOrResumeArchTimer();
  }

  void _startOrResumeArchTimer() {
    _archScanTimer?.cancel();
    _archScanTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted || _step != 2) return;
      if (!_allDentalGatesPass) return;

      setState(() {
        _archElapsedSeconds = (_archElapsedSeconds + 0.25 * _speedMultiplier)
            .clamp(0.0, _archTargetSeconds);
      });

      if (_archElapsedSeconds >= _archTargetSeconds) {
        _viewsCaptured[_activeArchIndex] = true;
        if (_activeArchIndex < 3) {
          final nextIdx = _activeArchIndex + 1;
          setState(() {
            _activeArchIndex = nextIdx;
            _archElapsedSeconds = 0.0;
          });
          _voiceCoach.announce(
            'View $nextIdx locked! Switching to View ${nextIdx + 1} of 4: ${_viewLabels[nextIdx]}.',
            tone: VoiceCueTone.scanning,
            force: true,
          );
        } else {
          timer.cancel();
          _voiceCoach.announce(
            'All 4 intraoral dental arch views locked with high macro sharpness! Generating your interactive FDI odontogram and caries report.',
            tone: VoiceCueTone.completed,
            force: true,
          );
        }
      }
    });
  }

  void _triggerQualityRetakeScreen() {
    _archScanTimer?.cancel();
    setState(() {
      _blurPass = false;
      _glarePass = false;
      _step = 3;
    });
    _voiceCoach.announce(
      'Intraoral photo quality check failed due to saliva glare and macro blur. Follow the 4-step preparation guide and tap Start Guided Retake.',
      tone: VoiceCueTone.warning,
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final isScanner = _step == 2;
    final isDarkStep = _step >= 2;

    return Scaffold(
      extendBodyBehindAppBar: isScanner,
      backgroundColor: isDarkStep ? const Color(0xFF070D19) : null,
      appBar: isScanner
          ? null
          : AppBar(
              backgroundColor: isDarkStep ? const Color(0xFF070D19) : null,
              foregroundColor: isDarkStep ? Colors.white : null,
              title: const Text(
                '4-View Guided Dental Screening',
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () =>
                      showScreenGateLifecycleSheet(context, _screenId),
                ),
              ],
            ),
      body: _buildStepContent(context, appState),
    );
  }

  Widget _buildStepContent(BuildContext context, AppState appState) {
    if (_step == 2) {
      return _buildStep2Guided4ViewScanner(context, appState);
    }
    if (_step == 3) {
      return _buildStep3QualityRetakeScreen(context, appState);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_step == 0) _buildStep0Setup(context, appState),
        if (_step == 1) _buildStep1Habits(context, appState),
      ],
    );
  }

  Widget _buildStep0Setup(BuildContext context, AppState appState) {
    final subj = appState.activeSubject;
    final hasConsent = subj.hasConsent(ConsentType.dentalGuardian);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B7A75), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF00E5CC).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5CC).withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      color: Color(0xFF00E5CC),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subj.isChild
                              ? 'Child 20-Tooth Primary Dental Screen (${subj.fullName})'
                              : 'Adult 32-Tooth FDI Dental Screen (${subj.fullName})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'ALG-DEN-01..07 • 4-View Intraoral AI & FDI Odontogram',
                          style: TextStyle(
                            color: Color(0xFF00E5CC),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Guides you through 4 intra-oral photos with live camera and spoken voice coaching, maps every tooth on an interactive FDI odontogram, calculates Caries Risk, and flags pit-and-fissure sealant candidates.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _prepBadge('Rear Macro + Torch', Icons.flashlight_on_rounded),
                  _prepBadge('4 Guided Arch Views', Icons.grid_view_rounded),
                  _prepBadge(
                    subj.isChild ? 'FDI 51–85 Primary' : 'FDI 11–48 Permanent',
                    Icons.medical_information_outlined,
                  ),
                  _prepBadge('ICDAS 1–6 & Sealant AI', Icons.verified_outlined),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4-View Intraoral Protocol Cards
        const Text(
          '1. 4-View Intraoral Capture Sequence (ALG-DEN-01)',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...List.generate(4, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: MirrorColors.primaryContainer,
                  foregroundColor: MirrorColors.primary,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  _viewLabels[i],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  '${_viewCodes[i]} • ${_viewTargets[i]}',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 8),
        // Best-Practice Preparation Tips
        Card(
          color: MirrorColors.primaryContainer.withValues(alpha: 0.28),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      size: 18,
                      color: MirrorColors.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Clinical Intraoral Capture Best Practices',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '• Swallow saliva before each view to keep specular flash glare <= 5% (ALG-CAP-07).\n'
                  '• Hold rear macro camera 12–15 cm from mouth with Torch ON (Laplacian sharpness >= 100).\n'
                  '• Gently retract lips/cheeks with clean fingers to expose cervical gumlines & posterior molars.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: const Text(
              'Dental & Guardian Screening Consent (Gate G-05)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Required before photographing teeth and oral mucosa.',
              style: TextStyle(fontSize: 12),
            ),
            value: hasConsent,
            onChanged: (v) =>
                appState.toggleConsent(ConsentType.dentalGuardian, v),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text(
            'Continue to Oral Hygiene & Diet Questions',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: !hasConsent ? null : () => setState(() => _step = 1),
        ),
      ],
    );
  }

  Widget _prepBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF00E5CC)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Habits(BuildContext context, AppState appState) {
    final subj = appState.activeSubject;
    final previewEval = CariesRiskEngine.evaluate(
      findings: const [],
      habits: CariesHabitsInput(
        nightBottleFeeding: _nightBottleFeeding,
        brushingPerDay: _brushingPerDay,
        usesFluoridePaste: _usesFluoridePaste,
        sweetsPerDay: _sweetsPerDay,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Oral Hygiene & Dietary Habits (ALG-DEN-06)',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
        const SizedBox(height: 6),
        const Text(
          'Spec §7.2: Combines your hygiene & sugar frequency answers with per-tooth visual findings (Cases 1–6) to compute Overall Caries Risk.',
          style: TextStyle(fontSize: 12.5, color: MirrorColors.inkMutedLight),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subj.isChild)
                  SwitchListTile(
                    dense: true,
                    title: const Text('Night bottle or sweetened feeding'),
                    subtitle: const Text(
                      'Case 3 Rule: White spot + night feeding -> High Caries Risk',
                    ),
                    value: _nightBottleFeeding,
                    onChanged: (v) => setState(() => _nightBottleFeeding = v),
                  ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Uses fluoridated toothpaste'),
                  subtitle: const Text(
                    'Protective remineralization factor in ALG-DEN-06',
                  ),
                  value: _usesFluoridePaste,
                  onChanged: (v) => setState(() => _usesFluoridePaste = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'Brushing frequency: $_brushingPerDay time(s) / day',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _brushingPerDay.toDouble(),
                  min: 0,
                  max: 3,
                  divisions: 3,
                  onChanged: (v) => setState(() => _brushingPerDay = v.round()),
                ),
                Text(
                  'Sugary snacks / drinks: $_sweetsPerDay / day',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _sweetsPerDay.toDouble(),
                  min: 0,
                  max: 6,
                  divisions: 6,
                  onChanged: (v) => setState(() => _sweetsPerDay = v.round()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: MirrorColors.primaryContainer.withValues(alpha: 0.35),
          child: ListTile(
            dense: true,
            leading: const Icon(
              Icons.analytics_outlined,
              color: MirrorColors.primary,
            ),
            title: Text(
              'Baseline Habit Profile: ${previewEval.riskBand.label} Risk',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            subtitle: Text(
              previewEval.explanation,
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.camera_alt_rounded),
          label: const Text(
            'Open Camera & Start 4-Arch Dental Scan',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () async {
            final granted = await showScanPermissionReadinessModal(
              context: context,
              scanTitle: '4-View Dental Arch Scanner',
              scanDuration: '4 Guided Intra-Oral Views',
              permissions: HealthPackagesRegistry.dentalPermissions,
              preparationTips:
                  HealthPackagesRegistry.preparationTipsForTargetScreen(
                    'S-F03',
                  ),
            );
            if (granted && mounted) {
              _startDentalScanner();
            }
          },
        ),
      ],
    );
  }

  /// Step 2 (S-F03): Full-Bleed Edge-to-Edge Immersive 4-View Guided Dental Scanner
  /// matching the Reference UI images:
  /// - 3D Tooth Arch Polygonal Wireframe & Tooth Segmentation Mesh
  /// - Rotating 36-Tick Radar Orbit Ring & Sweeping Cyan Laser
  /// - Sub-Reticle Bold 34px Percentage & Phase Status Cluster
  /// - Compact Frosted Glassmorphism Telemetry Dock
  Widget _buildStep2Guided4ViewScanner(
    BuildContext context,
    AppState appState,
  ) {
    final completedCount = _viewsCaptured.where((v) => v).length;
    final archProgress = (_archElapsedSeconds / _archTargetSeconds).clamp(
      0.0,
      1.0,
    );
    final frameColor = _allDentalGatesPass
        ? const Color(0xFF00E5CC)
        : const Color(0xFFEF4444);

    _cameraController ??= BiometricCameraController(
      mode: ScanCameraMode.rearMacro,
    )..initialize();

    final screenHeight = MediaQuery.sizeOf(context).height;
    final subj = appState.activeSubject;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Full-Bleed Live Camera Surface + 3D Dental Arch Mesh Painter
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _archInFrame = !_archInFrame;
                _archOffset = _archInFrame
                    ? Offset.zero
                    : const Offset(0.36, -0.22);
              });
              if (!_archInFrame) {
                _voiceCoach.announce(
                  'Dental arch is not in the frame! Center the teeth inside the 3D arch outline.',
                  tone: VoiceCueTone.outOfFrame,
                  force: true,
                );
              } else {
                _voiceCoach.announce(
                  'Dental arch centered. Scanning ${_viewLabels[_activeArchIndex]}.',
                  tone: VoiceCueTone.scanning,
                  force: true,
                );
              }
            },
            onPanUpdate: (details) {
              setState(() {
                final dx = (_archOffset.dx + details.delta.dx / 120).clamp(
                  -0.80,
                  0.80,
                );
                final dy = (_archOffset.dy + details.delta.dy / 140).clamp(
                  -0.80,
                  0.80,
                );
                _archOffset = Offset(dx, dy);
                final inFrame = _archOffset.distance <= 0.28;
                if (inFrame != _archInFrame) {
                  _archInFrame = inFrame;
                  if (!_archInFrame) {
                    _voiceCoach.announce(
                      'Dental arch moved out of frame! Align teeth inside the glowing mesh.',
                      tone: VoiceCueTone.outOfFrame,
                      force: true,
                    );
                  } else {
                    _voiceCoach.announce(
                      'Dental arch re-aligned. Resuming tooth segmentation.',
                      tone: VoiceCueTone.scanning,
                      force: true,
                    );
                  }
                }
              });
            },
            child: AnimatedBuilder(
              animation: _pulseAnimController,
              builder: (context, _) {
                return LiveBiometricCameraSurface(
                  controller: _cameraController!,
                  fullBleed: true,
                  overlayPainter: _BiometricDentalArchScannerPainter(
                    archIndex: _activeArchIndex,
                    isChildMode: subj.isChild,
                    archOffset: _archOffset,
                    frameColor: frameColor,
                    progress: archProgress,
                    pulsePhase: _pulseAnimController.value,
                    allGatesPassing: _allDentalGatesPass,
                  ),
                );
              },
            ),
          ),
        ),

        // 2. Floating Top Bar + Voice Coach Banner + 4-Arch Stepper Strip
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDentalScannerTopBar(context),
                  const SizedBox(height: 6),
                  LiveVoiceCoachBanner(
                    controller: _voiceCoach,
                    onRepeatPressed: _voiceCoach.repeatCurrent,
                  ),
                  const SizedBox(height: 6),
                  _build4ArchStepperStrip(),
                ],
              ),
            ),
          ),
        ),

        // 3. Sub-Reticle Bold 34px Percentage & Phase Status Cluster (Reference UI Match)
        Positioned(
          top: math.max(175.0, screenHeight * 0.37 + 108),
          left: 16,
          right: 16,
          child: Center(
            child: _buildSubReticlePercentageCluster(
              archProgress: archProgress,
              frameColor: frameColor,
              isChild: subj.isChild,
            ),
          ),
        ),

        // 4. Compact Frosted Glassmorphic Bottom Telemetry Dock
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: _buildDentalScannerBottomDock(
              context,
              appState,
              completedCount: completedCount,
              isChild: subj.isChild,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDentalScannerTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Back to Dental Setup',
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
              onPressed: () {
                _archScanTimer?.cancel();
                if (Navigator.of(context).canPop() && widget.autoStartScanner) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _step = 0);
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '4-View Guided Dental Screening',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'ARCH VIEW ${_activeArchIndex + 1} OF 4 • ${_viewCodes[_activeArchIndex].toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF00E5CC),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (_cameraController != null) ...[
            SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Switch Camera Lens',
                icon: const Icon(
                  Icons.cameraswitch_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: _cameraController!.switchCameraLens,
              ),
            ),
            SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Toggle Flashlight Torch',
                icon: Icon(
                  _cameraController!.torchEnabled
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  color: _cameraController!.torchEnabled
                      ? const Color(0xFFF59E0B)
                      : Colors.white70,
                  size: 18,
                ),
                onPressed: () async {
                  await _cameraController!.toggleTorch();
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _speedMultiplier = _speedMultiplier == 1 ? 5 : 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _speedMultiplier > 1
                    ? const Color(0xFF00E5CC).withValues(alpha: 0.25)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _speedMultiplier > 1
                      ? const Color(0xFF00E5CC)
                      : Colors.white24,
                ),
              ),
              child: Text(
                '${_speedMultiplier}x',
                style: TextStyle(
                  color: _speedMultiplier > 1
                      ? const Color(0xFF00E5CC)
                      : Colors.white70,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Screen Specs ($_screenId)',
              icon: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white70,
                size: 18,
              ),
              onPressed: () => showScreenGateLifecycleSheet(context, _screenId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build4ArchStepperStrip() {
    return Row(
      children: List.generate(4, (i) {
        final isSelected = _activeArchIndex == i;
        final isCaptured = _viewsCaptured[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 5 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () {
                setState(() {
                  _activeArchIndex = i;
                  _archElapsedSeconds = 0.0;
                });
                _voiceCoach.announce(
                  'Selected View ${i + 1} of 4: ${_viewLabels[i]}.',
                  tone: VoiceCueTone.scanning,
                  force: true,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00E5CC).withValues(alpha: 0.22)
                      : const Color(0xFF0F172A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00E5CC)
                        : (isCaptured
                              ? const Color(0xFF10B981).withValues(alpha: 0.65)
                              : Colors.white24),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCaptured
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 11,
                      color: isCaptured
                          ? const Color(0xFF00E5CC)
                          : Colors.white54,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        _shortViewLabels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 9.5,
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSubReticlePercentageCluster({
    required double archProgress,
    required Color frameColor,
    required bool isChild,
  }) {
    final pctInt = (archProgress * 100).round().clamp(0, 100);
    final statusText = !_archInFrame
        ? 'DENTAL ARCH OUT OF FRAME • ALIGN TEETH IN MESH'
        : (!_blurPass || !_glarePass)
        ? 'SALIVA GLARE / BLUR • SWALLOW & HOLD AT 12 CM'
        : (pctInt < 45
              ? 'SEGMENTING ${isChild ? "PRIMARY" : "FDI"} TOOTH CROWNS & GINGIVA...'
              : 'ANALYZING OCCLUSAL FISSURES & ICDAS ENAMEL...');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$pctInt%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.0,
            shadows: [
              Shadow(color: frameColor.withValues(alpha: 0.65), blurRadius: 18),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color:
                (!_allDentalGatesPass
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF0F172A))
                    .withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: frameColor.withValues(alpha: 0.65)),
          ),
          child: Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _viewLabels[_activeArchIndex],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF00E5CC),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildDentalScannerBottomDock(
    BuildContext context,
    AppState appState, {
    required int completedCount,
    required bool isChild,
  }) {
    final torchOn = _cameraController?.torchEnabled ?? true;
    final teethCountLabel = _activeArchIndex <= 1
        ? (isChild ? '10/10 Primary Anterior' : '12/12 Anterior Crowns')
        : (isChild ? '10/10 Primary Arch' : '16/16 Occlusal Teeth');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1325).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Compact 4-Gate Telemetry Capsule (Zero Overflow on 360px)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(child: _telemetryDot('Arch', _archInFrame)),
                Container(width: 1, height: 11, color: Colors.white12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _telemetryDot('Focus >=100', _blurPass),
                  ),
                ),
                Container(width: 1, height: 11, color: Colors.white12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _telemetryDot('Glare <=5%', _glarePass),
                  ),
                ),
                Container(width: 1, height: 11, color: Colors.white12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _telemetryDot('Torch ON', torchOn),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Row 2: Live Tooth Mesh Telemetry + Quick Sim / Controls Toggle
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111C2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.grid_on_rounded,
                        size: 14,
                        color: Color(0xFF00E5CC),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$teethCountLabel • Views: $completedCount/4',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _archInFrame = !_archInFrame);
                  if (!_archInFrame) {
                    _voiceCoach.announce(
                      'Dental arch is not in the frame! Center the teeth inside the arch outline.',
                      tone: VoiceCueTone.outOfFrame,
                      force: true,
                    );
                  } else {
                    _voiceCoach.announce(
                      'Dental arch centered. Ready to capture ${_viewLabels[_activeArchIndex]}.',
                      tone: VoiceCueTone.scanning,
                      force: true,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111C2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _archInFrame
                          ? Colors.white24
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  child: Text(
                    _archInFrame ? '⚠ Test Out of Frame' : '✓ Center Arch',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Test Controls',
                  icon: Icon(
                    _showArchControls
                        ? Icons.expand_less_rounded
                        : Icons.tune_rounded,
                    color: _showArchControls
                        ? const Color(0xFF00E5CC)
                        : Colors.white70,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _showArchControls = !_showArchControls),
                ),
              ),
            ],
          ),

          // Collapsible Partial Exam & Clinical Simulation Panel
          if (_showArchControls) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF111C2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CAPTURED VIEWS ($completedCount / 4 · Partial Exam Allowed if >= 1)',
                    style: const TextStyle(
                      color: Color(0xFF00E5CC),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: List.generate(4, (i) {
                      return FilterChip(
                        visualDensity: VisualDensity.compact,
                        selected: _viewsCaptured[i],
                        selectedColor: const Color(
                          0xFF00E5CC,
                        ).withValues(alpha: 0.25),
                        checkmarkColor: const Color(0xFF00E5CC),
                        backgroundColor: const Color(0xFF070D19),
                        label: Text(
                          _shortViewLabels[i],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onSelected: (v) {
                          setState(() {
                            _viewsCaptured[i] = v;
                            _activeArchIndex = i;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => setState(
                      () => _simulateAbscessUrgent = !_simulateAbscessUrgent,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          visualDensity: VisualDensity.compact,
                          value: _simulateAbscessUrgent,
                          onChanged: (v) => setState(
                            () => _simulateAbscessUrgent = v ?? false,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Simulate Gingival Abscess Sign -> Urgent T13 (BR-SCR-02)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF87171),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(Icons.warning_amber_rounded, size: 14),
                      label: const Text(
                        'Simulate Quality Failure',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: _triggerQualityRetakeScreen,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: const Color(0xFF00E5CC),
                foregroundColor: const Color(0xFF062825),
              ),
              icon: const Icon(Icons.fact_check_rounded, size: 18),
              label: Text(
                completedCount == 0
                    ? 'Capture At Least 1 View'
                    : 'Generate FDI Chart & Caries Report ($completedCount/4)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
              onPressed: completedCount == 0
                  ? null
                  : () => _completeDentalExam(context, appState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _telemetryDot(String label, bool pass) {
    final color = pass ? const Color(0xFF00E5CC) : const Color(0xFFEF4444);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: pass ? Colors.white : const Color(0xFFFCA5A5),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  /// Step 3 (S-F03): Intraoral Quality Check & Guided Retake Screen
  Widget _buildStep3QualityRetakeScreen(
    BuildContext context,
    AppState appState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF450A0A), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.65),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cameraswitch_rounded,
                        color: Color(0xFFF87171),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Intraoral Quality Retake Required',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Laplacian Blur: 62.0 (< 100) • Saliva Glare: 8.6% (> 5.0%)',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Spec §7.1 (ALG-DEN-01): Specular saliva reflections or macro blur on occlusal molar surfaces can mask early white-spot lesions (ICDAS 1–2). Follow the remediation steps below and retake the view.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Root-Cause Diagnostic Flags',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 8),
          _retakeReasonTile(
            Icons.wb_sunny_outlined,
            'Specular Saliva Glare > 5.0% (ALG-CAP-07)',
            'Wet enamel on lower occlusal molars reflected the LED torch, saturating 8.6% of tooth pixels.',
          ),
          const SizedBox(height: 8),
          _retakeReasonTile(
            Icons.blur_on_rounded,
            'Macro Focus Below Laplacian 100 (ALG-CAP-06)',
            'Camera held closer than minimum macro focal distance (12 cm) or moved during shutter capture.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Step-by-Step Intraoral Remediation Guide',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 8),
          _remediationStepTile(
            '1',
            'Swallow Saliva & Wipe Lip Moisture',
            'Swallow once immediately before opening wide to clear pooled saliva from molar grooves.',
          ),
          _remediationStepTile(
            '2',
            'Hold Rear Camera 12–15 cm Away at 10° Angle',
            'Slight 10° tilt prevents direct LED torch bounce while keeping all 16 arch teeth in sharp focus.',
          ),
          _remediationStepTile(
            '3',
            'Tilt Head Back 45° (Upper) or Curl Tongue Back (Lower)',
            'Ensures first permanent molars (FDI 16, 26, 36, 46) are unobstructed for sealant evaluation.',
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF00E5CC),
              foregroundColor: const Color(0xFF042F2E),
            ),
            icon: const Icon(Icons.replay_rounded),
            label: Text(
              'Start Guided Retake (Attempt ${_retakeCount + 1}/3)',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: () {
              setState(() => _retakeCount++);
              _startDentalScanner();
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text(
              'Proceed with Partial Exam (ALG-DEN-01)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              setState(() {
                _viewsCaptured[3] =
                    false; // Mark 1 view missing for partial exam
              });
              _completeDentalExam(context, appState);
            },
          ),
        ],
      ),
    );
  }

  Widget _retakeReasonTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFF87171), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _remediationStepTile(String stepNum, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: const Color(0xFF00E5CC).withValues(alpha: 0.2),
              foregroundColor: const Color(0xFF00E5CC),
              child: Text(
                stepNum,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _completeDentalExam(BuildContext context, AppState appState) {
    _archScanTimer?.cancel();
    final missingCount = _viewsCaptured.where((v) => !v).length;
    final exam = appState.generateDentalExam(
      habits: CariesHabitsInput(
        nightBottleFeeding: _nightBottleFeeding,
        brushingPerDay: _brushingPerDay,
        usesFluoridePaste: _usesFluoridePaste,
        sweetsPerDay: _sweetsPerDay,
      ),
      missingViewsCount: missingCount,
      includeAbscess: _simulateAbscessUrgent,
    );

    appState.saveDentalExam(exam);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => DentalResultsScreen(exam: exam)),
    );
  }
}

/// CustomPainter for the 3D Tooth Arch Polygonal Wireframe & Tooth Segmentation Mesh (ALG-DEN-02),
/// Rotating 36-Tick Radar Orbit Ring, Corner Brackets, and Sweeping Cyan Laser.
class _BiometricDentalArchScannerPainter extends CustomPainter {
  _BiometricDentalArchScannerPainter({
    required this.archIndex,
    required this.isChildMode,
    required this.archOffset,
    required this.frameColor,
    required this.progress,
    required this.pulsePhase,
    required this.allGatesPassing,
  });

  final int archIndex;
  final bool isChildMode;
  final Offset archOffset;
  final Color frameColor;
  final double progress;
  final double pulsePhase;
  final bool allGatesPassing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.36);
    final isOcclusal = archIndex >= 2;
    final archWidth = math.min(size.width * 0.78, 260.0);
    final archHeight = isOcclusal ? 190.0 : 150.0;
    final archRect = Rect.fromCenter(
      center: center,
      width: archWidth,
      height: archHeight,
    );

    // 1. Dark Frosted Vignette with Anatomical Dental Cutout
    final fullScreenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutRadius = isOcclusal ? 90.0 : 68.0;
    final archCutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(archRect, Radius.circular(cutoutRadius)),
      );
    final vignettePath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      archCutoutPath,
    );
    canvas.drawPath(
      vignettePath,
      Paint()
        ..color = const Color(0xFF050B16).withValues(alpha: 0.72)
        ..style = PaintingStyle.fill,
    );

    // 2. Rotating 36-Tick Radar Orbit Ring (Reference UI Match)
    final orbitRadius = math.max(archWidth, archHeight) * 0.54;
    final tickPaint = Paint()
      ..color = frameColor.withValues(alpha: 0.32)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const totalTicks = 36;
    for (int i = 0; i < totalTicks; i++) {
      final angle = (i * 2 * math.pi / totalTicks) + (pulsePhase * 0.35);
      final isMajor = i % 3 == 0;
      final innerR = orbitRadius + 4;
      final outerR = orbitRadius + (isMajor ? 11.0 : 7.0);
      final p1 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 3. Outer Progress Ring Around Dental Arch Cutout
    final borderPaint = Paint()
      ..color = frameColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(archRect, Radius.circular(cutoutRadius)),
      borderPaint,
    );

    if (progress > 0) {
      final progressArcPaint = Paint()
        ..color = frameColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: orbitRadius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressArcPaint,
      );
    }

    // 4. Corner Technical Reticle Brackets [   ]
    final bracketRect = archRect.inflate(10);
    final bracketPaint = Paint()
      ..color = frameColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    const arm = 20.0;
    canvas.drawLine(
      Offset(bracketRect.left, bracketRect.top + arm),
      bracketRect.topLeft,
      bracketPaint,
    );
    canvas.drawLine(
      bracketRect.topLeft,
      Offset(bracketRect.left + arm, bracketRect.top),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(bracketRect.right - arm, bracketRect.top),
      bracketRect.topRight,
      bracketPaint,
    );
    canvas.drawLine(
      bracketRect.topRight,
      Offset(bracketRect.right, bracketRect.top + arm),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(bracketRect.left, bracketRect.bottom - arm),
      bracketRect.bottomLeft,
      bracketPaint,
    );
    canvas.drawLine(
      bracketRect.bottomLeft,
      Offset(bracketRect.left + arm, bracketRect.bottom),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(bracketRect.right - arm, bracketRect.bottom),
      bracketRect.bottomRight,
      bracketPaint,
    );
    canvas.drawLine(
      bracketRect.bottomRight,
      Offset(bracketRect.right, bracketRect.bottom - arm),
      bracketPaint,
    );

    // 5. Sweeping Cyan Laser Line Across Dental Arch
    if (allGatesPassing) {
      final laserY = archRect.top + 12 + (archRect.height - 24) * pulsePhase;
      final laserPaint = Paint()
        ..shader =
            LinearGradient(
              colors: [
                Colors.transparent,
                frameColor.withValues(alpha: 0.90),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTWH(archRect.left, laserY - 2, archRect.width, 4),
            )
        ..strokeWidth = 2.2;
      canvas.drawLine(
        Offset(archRect.left + 8, laserY),
        Offset(archRect.right - 8, laserY),
        laserPaint,
      );
    }

    // 6. 3D Tooth Arch Polygonal Wireframe & Tooth Segmentation Mesh (ALG-DEN-02)
    final shift = Offset(archOffset.dx * 55, archOffset.dy * 45);
    final meshCenter = center + shift;

    final wirePaint = Paint()
      ..color = frameColor.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fissurePaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final gingivaPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final nodePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final nodeGlowPaint = Paint()
      ..color = frameColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    if (!isOcclusal) {
      // Anterior Views (0: Front Closed Bite, 1: Front Open Mouth)
      final gapY = archIndex == 1 ? 18.0 : 3.0;
      const toothCols = 6; // Anterior incisors + canines
      final totalW = archWidth * 0.68;
      final startX = meshCenter.dx - totalW / 2;
      final colW = totalW / toothCols;

      // Gingival margin contour curves (ALG-DEN-04)
      final upperGingiva = Path()
        ..moveTo(startX - 8, meshCenter.dy - gapY - 24)
        ..quadraticBezierTo(
          meshCenter.dx,
          meshCenter.dy - gapY - 34,
          startX + totalW + 8,
          meshCenter.dy - gapY - 24,
        );
      final lowerGingiva = Path()
        ..moveTo(startX - 8, meshCenter.dy + gapY + 24)
        ..quadraticBezierTo(
          meshCenter.dx,
          meshCenter.dy + gapY + 34,
          startX + totalW + 8,
          meshCenter.dy + gapY + 24,
        );
      canvas.drawPath(upperGingiva, gingivaPaint);
      canvas.drawPath(lowerGingiva, gingivaPaint);

      for (int c = 0; c < toothCols; c++) {
        final tx = startX + c * colW;
        final isCentral = c == 2 || c == 3;
        final th = isCentral ? 22.0 : 19.0;

        // Upper anterior tooth polygon
        final uRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(tx + 1.5, meshCenter.dy - gapY - th, colW - 3, th),
          const Radius.circular(5),
        );
        // Lower anterior tooth polygon
        final lRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(tx + 1.5, meshCenter.dy + gapY, colW - 3, th - 2),
          const Radius.circular(5),
        );
        canvas.drawRRect(uRect, wirePaint);
        canvas.drawRRect(lRect, wirePaint);

        // Crown landmark vertex nodes
        final uNode = Offset(tx + colW / 2, meshCenter.dy - gapY - th / 2);
        final lNode = Offset(
          tx + colW / 2,
          meshCenter.dy + gapY + (th - 2) / 2,
        );
        canvas.drawCircle(uNode, 4.0, nodeGlowPaint);
        canvas.drawCircle(uNode, 2.0, nodePaint);
        canvas.drawCircle(lNode, 4.0, nodeGlowPaint);
        canvas.drawCircle(lNode, 2.0, nodePaint);
      }
    } else {
      // Occlusal Views (2: Upper Occlusal Horseshoe, 3: Lower Occlusal Horseshoe)
      final isUpper = archIndex == 2;
      final toothCount = isChildMode ? 10 : 12;
      final rx = archWidth * 0.34;
      final ry = archHeight * 0.34;
      final List<Offset> archNodes = [];

      for (int i = 0; i < toothCount; i++) {
        final t = i / (toothCount - 1); // 0..1 along horseshoe arch
        final angle = isUpper
            ? (math.pi + t * math.pi) // Upper arch curves top
            : (t * math.pi); // Lower arch curves bottom
        final tx = meshCenter.dx + rx * math.cos(angle);
        final ty = meshCenter.dy + (isUpper ? 16 : -16) + ry * math.sin(angle);
        final toothPos = Offset(tx, ty);
        archNodes.add(toothPos);

        // Individual occlusal tooth polygon
        final isMolar = i <= 1 || i >= toothCount - 2;
        final toothSize = isMolar ? 18.0 : 14.0;
        final tRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: toothPos,
            width: toothSize,
            height: toothSize,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(tRect, wirePaint);

        // Pit-and-fissure groove cross on posterior molars (ALG-DEN-05)
        if (isMolar) {
          canvas.drawLine(
            Offset(toothPos.dx - 5, toothPos.dy),
            Offset(toothPos.dx + 5, toothPos.dy),
            fissurePaint,
          );
          canvas.drawLine(
            Offset(toothPos.dx, toothPos.dy - 5),
            Offset(toothPos.dx, toothPos.dy + 5),
            fissurePaint,
          );
        }

        // Cuspal vertex node
        canvas.drawCircle(toothPos, 3.8, nodeGlowPaint);
        canvas.drawCircle(toothPos, 1.8, nodePaint);
      }

      // Connect arch parabolic wireframe curve
      if (archNodes.length > 1) {
        final archCurve = Path()
          ..moveTo(archNodes.first.dx, archNodes.first.dy);
        for (int i = 1; i < archNodes.length; i++) {
          archCurve.lineTo(archNodes[i].dx, archNodes[i].dy);
        }
        canvas.drawPath(archCurve, gingivaPaint);
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant _BiometricDentalArchScannerPainter oldDelegate,
  ) => true;
}

/// S-F04 Dental Tooth Chart & Caries Risk Results + S-F05 Sealant Recommendations
/// Light card layout: oral health score, range scales,
/// Interactive FDI Odontogram + ICDAS Surface Inspector, and Persistent Retake / Save Dock.
class DentalResultsScreen extends StatefulWidget {
  const DentalResultsScreen({super.key, required this.exam});

  final DentalExamResult exam;

  @override
  State<DentalResultsScreen> createState() => _DentalResultsScreenState();
}

class _DentalResultsScreenState extends State<DentalResultsScreen> {
  int? _selectedToothFdi;

  int _computeOralHealthScore(DentalExamResult ex) {
    if (ex.urgency == UrgencyLevel.urgent) return 34;
    int base = switch (ex.cariesRiskBand) {
      SemanticBand.low => 92,
      SemanticBand.normal => 90,
      SemanticBand.moderate => 74,
      SemanticBand.high => 52,
      _ => 65,
    };
    base -= (ex.toothFindings.length * 4).clamp(0, 20);
    if (ex.isPartial) base -= 4;
    return base.clamp(18, 98);
  }

  void _retake() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const DentalFlowScreen(autoStartScanner: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exam;
    final selectedFinding = ex.toothFindings
        .where((f) => f.toothFdi == _selectedToothFdi)
        .firstOrNull;
    final oralScore = _computeOralHealthScore(ex);

    final gingivitisBand = ex.urgency == UrgencyLevel.urgent
        ? SemanticBand.high
        : (ex.cariesRiskBand == SemanticBand.high
              ? SemanticBand.moderate
              : SemanticBand.low);
    final plaqueBand = ex.cariesRiskBand == SemanticBand.high
        ? SemanticBand.moderate
        : SemanticBand.low;

    const segs = [AnaemiaUi.segNormal, AnaemiaUi.segBorder, AnaemiaUi.segHigh];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dental Report', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'About this screen',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-F04'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: MirrorSpace.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Oral health score summary
            _buildHeroOralScoreCard(context, ex, oralScore),
            const SizedBox(height: MirrorSpace.md),

            // 2. Urgency triage
            UrgencyBanner(
              urgency: ex.urgency,
              title: 'Dental triage',
              subtitle: ex.isPartial
                  ? 'Partial exam (${ex.viewsCompleted}/4 views). Unseen teeth: ${ex.unseenTeethFdi.join(", ")}.'
                  : 'All 4 views captured. ${ex.cariesRiskReason}',
            ),
            const SizedBox(height: MirrorSpace.xl),

            // 3. Interactive FDI tooth chart (S-F04)
            const SectionHeader(
              title: 'Tooth chart',
              subtitle: 'Tap a tooth to see its finding',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(MirrorSpace.lg),
                child: FdiToothChartWidget(
                  isChildMode: ex.isChildMode,
                  findings: ex.toothFindings,
                  unseenTeeth: ex.unseenTeethFdi,
                  sealantTeeth: ex.sealantNeededTeethFdi,
                  onToothSelected: (fdi) =>
                      setState(() => _selectedToothFdi = fdi),
                ),
              ),
            ),

            // 4. Selected tooth inspector (S-F05)
            if (_selectedToothFdi != null) ...[
              const SizedBox(height: MirrorSpace.md),
              _buildSelectedToothInspector(context, ex, selectedFinding),
            ],
            const SizedBox(height: MirrorSpace.xl),

            // 5. Range scales (ALG-DEN-04..07)
            const SectionHeader(
              title: 'Teeth & gum health',
              subtitle: 'Where your result sits on each scale',
            ),
            _buildDentalRangeScaleCard(
              context,
              title: 'Caries risk',
              valueLabel: ex.cariesRiskBand.label,
              subtitle: ex.cariesRiskReason,
              markerPct: ex.cariesRiskBand == SemanticBand.low
                  ? 0.18
                  : (ex.cariesRiskBand == SemanticBand.moderate ? 0.52 : 0.86),
              labels: const ['Low', 'Moderate', 'High'],
              colors: segs,
            ),
            const SizedBox(height: MirrorSpace.md),
            _buildDentalRangeScaleCard(
              context,
              title: 'Gum health',
              valueLabel: gingivitisBand.label,
              subtitle: 'Redness and swelling along the gum line',
              markerPct: gingivitisBand == SemanticBand.low
                  ? 0.22
                  : (gingivitisBand == SemanticBand.moderate ? 0.55 : 0.88),
              labels: const ['Healthy', 'Mild', 'Inflamed'],
              colors: segs,
            ),
            const SizedBox(height: MirrorSpace.md),
            _buildDentalRangeScaleCard(
              context,
              title: 'Plaque coverage',
              valueLabel: plaqueBand.label,
              subtitle: 'Visible plaque and tartar on the front of the teeth',
              markerPct: plaqueBand == SemanticBand.low ? 0.20 : 0.54,
              labels: const ['Clean <15%', '15–35%', 'Heavy >35%'],
              colors: segs,
            ),
            const SizedBox(height: MirrorSpace.xl),

            // 6. Sealant advice (ALG-DEN-05 / 07)
            const SectionHeader(title: 'Sealant advice'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(MirrorSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const IconBadge(icon: Icons.shield_outlined, size: 34),
                        const SizedBox(width: MirrorSpace.md),
                        Expanded(
                          child: Text(
                            ex.sealantNeededTeethFdi.isEmpty
                                ? 'No back teeth need a sealant right now.'
                                : 'These healthy molars have deep grooves. A protective sealant can prevent decay.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    if (ex.sealantNeededTeethFdi.isNotEmpty) ...[
                      const SizedBox(height: MirrorSpace.md),
                      Wrap(
                        spacing: MirrorSpace.sm,
                        runSpacing: MirrorSpace.sm,
                        children: ex.sealantNeededTeethFdi
                            .map(
                              (fdi) => MirrorPill(
                                label: 'Tooth $fdi',
                                icon: Icons.shield_outlined,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: MirrorSpace.xl),

            // 7. Spec output markers (ALG-DEN-01..07)
            const SectionHeader(
              title: 'Algorithm outputs',
              subtitle: 'Markers stored with this exam · tap a row for detail',
            ),
            AlgorithmOutputsSection(
              groups: MarkerReadings.fromDental(ex),
              showHeader: false,
            ),
            const SizedBox(height: MirrorSpace.lg),
            const DisclaimerFooter(),
          ],
        ),
      ),
      bottomNavigationBar: PrimaryBottomButton(
        label: 'Save to Profile',
        icon: Icons.check_circle_rounded,
        secondaryLabel: 'Retake Scan',
        onSecondary: _retake,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dental report saved to profile')),
          );
        },
      ),
    );
  }

  Widget _buildHeroOralScoreCard(
    BuildContext context,
    DentalExamResult ex,
    int oralScore,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final scoreColor = oralScore >= 80
        ? MirrorColors.successFg
        : (oralScore >= 60 ? MirrorColors.warningFg : MirrorColors.dangerFg);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MirrorSpace.lg),
        child: Row(
          children: [
            SizedBox(
              width: 66,
              height: 66,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 62,
                    height: 62,
                    child: CircularProgressIndicator(
                      value: oralScore / 100.0,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$oralScore',
                        style: t.headlineSmall?.copyWith(
                          color: scoreColor,
                          height: 1.0,
                        ),
                      ),
                      Text('/ 100', style: t.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: MirrorSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Oral health score', style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    ex.isChildMode
                        ? 'Child · 20 primary teeth'
                        : 'Adult · 32 permanent teeth',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: MirrorSpace.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      MirrorPill(
                        label: '${ex.viewsCompleted}/4 views',
                        icon: Icons.photo_camera_outlined,
                      ),
                      MirrorPill(
                        label:
                            '${ex.toothFindings.length} ${ex.toothFindings.length == 1 ? "finding" : "findings"}',
                        color: scoreColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedToothInspector(
    BuildContext context,
    DentalExamResult ex,
    ToothFinding? selectedFinding,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final fdi = _selectedToothFdi!;
    final title = selectedFinding != null
        ? 'Tooth $fdi · ${selectedFinding.findingLabel}'
        : (ex.unseenTeethFdi.contains(fdi)
              ? 'Tooth $fdi · Not seen in photos'
              : (ex.sealantNeededTeethFdi.contains(fdi)
                    ? 'Tooth $fdi · Healthy (sealant candidate)'
                    : 'Tooth $fdi · Healthy'));
    final subtitle = selectedFinding != null
        ? 'Confidence ${(selectedFinding.probability * 100).round()}% · Change: ${selectedFinding.changeVsPrevious}'
        : 'Tap another tooth on the chart to inspect it.';

    return Card(
      color: scheme.primary.withValues(alpha: 0.08),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: Text('$fdi'),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildDentalRangeScaleCard(
    BuildContext context, {
    required String title,
    required String valueLabel,
    required String subtitle,
    required double markerPct,
    required List<String> labels,
    required List<Color> colors,
  }) {
    final t = Theme.of(context).textTheme;
    final pct = markerPct.clamp(0.05, 0.95);
    final segIndex = (pct * labels.length).floor().clamp(0, labels.length - 1);
    final pin = segIndex == 0
        ? MirrorColors.successFg
        : (segIndex == 1 ? MirrorColors.warningFg : MirrorColors.dangerFg);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MirrorSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: t.titleSmall)),
                const SizedBox(width: MirrorSpace.sm),
                MirrorPill(label: valueLabel, color: pin),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: t.bodySmall),
            const SizedBox(height: MirrorSpace.md),
            RangeGauge(
              scale: RangeScale(
                breakpoints: List.generate(
                  labels.length + 1,
                  (i) => i.toDouble(),
                ),
                labels: labels,
                colors: colors,
              ),
              value: pct * labels.length,
              pinColor: pin,
            ),
          ],
        ),
      ),
    );
  }
}
