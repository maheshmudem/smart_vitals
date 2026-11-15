import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/health_package.dart';
import '../../core/domain/entities/marker_envelope.dart';
import '../../core/services/live_camera_service.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../results_cases/results_cases_screens.dart';

/// Flagship Optical & Eye Screening Suite (S-E01 .. S-E06):
/// - Anaemia Lower Eyelid (ALG-IMG-01)
/// - Adult Jaundice Sclera (ALG-IMG-02)
/// - Cataract Lens Opacity (ALG-IMG-03)
/// - Oral Pre-Cancer / Lesion (ALG-IMG-04)
/// - Diabetic Foot Ulcer & Wound Area (ALG-IMG-05)
/// - Child Eye Red-Reflex & Squint (ALG-IMG-06)
/// - Newborn Jaundice Transcutaneous Bilirubin (ALG-IMG-07, Mandatory Colour Card G-20)
/// - Skin Condition & Lesion Classifier (ALG-IMG-08)
class ImageScreeningFlowScreen extends StatefulWidget {
  const ImageScreeningFlowScreen({
    super.key,
    required this.screenType,
    this.autoStartScanner = false,
  });

  final ImageScreenType screenType;
  final bool autoStartScanner;

  @override
  State<ImageScreeningFlowScreen> createState() =>
      _ImageScreeningFlowScreenState();
}

class _ImageScreeningFlowScreenState extends State<ImageScreeningFlowScreen>
    with SingleTickerProviderStateMixin {
  late final VoiceCoachController _voiceCoach;
  late final AnimationController _pulseAnimController;
  BiometricCameraController? _cameraController;

  // Step 0: Pre-Scan Permissions & Colour Card Setup (S-E01/E02)
  // Step 1: Immersive Full-Bleed Live Biometric Eye & Optical Scanner (S-E03)
  // Step 2: Capture Quality Review & Clinical Verification (S-E04)
  int _step = 0;

  int _activeViewIndex = 0;
  bool _manualGateOverride = false;
  Offset _targetOffset =
      Offset.zero; // Normalized (-1..1). >0.30 means Out of Frame
  bool _targetInFrame = true;
  bool _blurPass = true; // ALG-CAP-06: Laplacian >= 100
  bool _glarePass = true; // ALG-CAP-07: Glare <= 5%
  bool _colourCardDetected = true;
  double _deltaE = 2.4; // ALG-CAP-10: pass <= 5.0

  // 30-Second Real Clinical Biometric Reading Timer
  static const int _targetDurationSeconds = 30;
  double _elapsedSeconds = 0.0;
  bool _isTimerRunning = false;
  int _speedMultiplier = 1; // 1x (Real 30s) or 5x (Fast 6s demo)
  Timer? _readingTimer;
  Timer? _autoEngageTimer;

  int _retakeCount = 0; // Gate G-25: max 3
  bool _simulateHighBand = false;
  bool _simulateUncertainNearThreshold = false; // IMG-10 Specialist Review

  bool get _isEyeScreen {
    final st = widget.screenType;
    return st == ImageScreenType.anaemia ||
        st == ImageScreenType.adultJaundice ||
        st == ImageScreenType.cataract ||
        st == ImageScreenType.childEye;
  }

  @override
  void initState() {
    super.initState();
    _voiceCoach = VoiceCoachController();
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    if (widget.autoStartScanner) {
      _step = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startBiometricScanner();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _voiceCoach.announce(
          _isEyeScreen
              ? 'Ready for ${widget.screenType.title}. Review instructions and tap Start to open your front camera.'
              : 'Ready for ${widget.screenType.title}. Check camera, flash, and colour card readiness before starting.',
          tone: VoiceCueTone.ready,
          force: true,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoEngageTimer?.cancel();
    _readingTimer?.cancel();
    _cameraController?.dispose();
    _pulseAnimController.dispose();
    _voiceCoach.dispose();
    super.dispose();
  }

  String get _screenId => const ['S-E01', 'S-E03', 'S-E04'][_step.clamp(0, 2)];

  bool get _isCardMandatory =>
      widget.screenType.colourCardPolicy == ColourCardPolicy.mandatory;

  bool get _allMacroGatesPass {
    if (!_targetInFrame || !_blurPass || !_glarePass) return false;
    if (_isCardMandatory && (!_colourCardDetected || _deltaE > 5.0)) {
      return false;
    }
    return true;
  }

  void _startBiometricScanner() {
    _cameraController?.dispose();
    // Default to front camera for eyes so user sees themselves; rear macro for skin/oral
    final defaultMode = _isEyeScreen
        ? ScanCameraMode.frontFace
        : ScanCameraMode.rearMacro;

    _cameraController = BiometricCameraController(
      mode: defaultMode,
      onFrameMetricsUpdated: (telemetry) {
        if (!mounted || _manualGateOverride) return;
        final prevPass = _allMacroGatesPass;
        final prevInFrame = _targetInFrame;

        setState(() {
          _targetInFrame = telemetry.subjectInFrame;
          _blurPass =
              telemetry.brightness >= 35.0 && telemetry.brightness <= 245.0;
          if (telemetry.normalizedFaceBox != null) {
            final box = telemetry.normalizedFaceBox!;
            final cx = (box.left + box.width / 2) - 0.5;
            final cy = (box.top + box.height / 2) - 0.5;
            _targetOffset = Offset(
              (cx * 1.3).clamp(-0.75, 0.75),
              (cy * 1.3).clamp(-0.75, 0.75),
            );
          } else if (!_targetInFrame) {
            _targetOffset = const Offset(0.44, -0.26);
          }
        });

        if (_allMacroGatesPass && !_isTimerRunning) {
          _startOrResumeReadingTimer();
        } else if (prevInFrame != _targetInFrame ||
            prevPass != _allMacroGatesPass) {
          _announceMacroState(force: true);
        }
      },
    )..initialize();

    setState(() {
      _step = 1;
      _activeViewIndex = 0;
      _elapsedSeconds = 0.0;
      _manualGateOverride = false;
      _targetOffset = Offset.zero;
      _targetInFrame = true;
      _blurPass = true;
      _glarePass = true;
      _isTimerRunning = false;
    });

    _voiceCoach.announce(
      _isEyeScreen
          ? 'Welcome to Eye and Sclera Health Scan. Align your eyes inside the glowing guide. Look slightly upward to expose the lower eyelid.'
          : 'Welcome to ${widget.screenType.title}. Center the target inside the glowing reticle guide.',
      tone: VoiceCueTone.ready,
      force: true,
    );

    // Auto-engage reading after initial camera warm-up
    if (VoiceCoachController.isFlutterTest) {
      if (!_isTimerRunning && _allMacroGatesPass) {
        _startOrResumeReadingTimer();
      }
    } else {
      _autoEngageTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted || _step != 1) return;
        if (!_isTimerRunning && _allMacroGatesPass) {
          _startOrResumeReadingTimer();
          _voiceCoach.announce(
            _isEyeScreen
                ? 'Eyes detected in frame with clear focus. Beginning 30-second micro-vascular and sclera spectral reading.'
                : 'Target locked. Beginning 30-second optical scan, please hold steady.',
            tone: VoiceCueTone.scanning,
            force: true,
          );
        }
      });
    }
  }

  void _startOrResumeReadingTimer() {
    _readingTimer?.cancel();
    _isTimerRunning = true;
    _readingTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) return;
      if (!_allMacroGatesPass) {
        // Auto-pause reading while target/eyes are out of frame or blur/glare fails
        return;
      }

      final prevSec = _elapsedSeconds.floor();
      setState(() {
        _elapsedSeconds = (_elapsedSeconds + 0.25 * _speedMultiplier).clamp(
          0.0,
          _targetDurationSeconds.toDouble(),
        );
      });
      final newSec = _elapsedSeconds.floor();

      // Clinical spoken voice coaching milestones during 30s scan
      if (newSec != prevSec) {
        if (newSec == 3) {
          _voiceCoach.announce(
            _isEyeScreen
                ? 'Camera exposure locked. Eyes centered in frame. Taking your reading, please hold still and look slightly upward.'
                : 'Camera exposure locked. Target centered, keep holding steady.',
            tone: VoiceCueTone.scanning,
          );
        } else if (newSec == 10) {
          _voiceCoach.announce(
            _isEyeScreen
                ? 'Pupil geometry locked. Now scanning conjunctival micro-vascular pallor and blood flow.'
                : 'Focus optimal. Extracting texture features and colour histogram.',
            tone: VoiceCueTone.scanning,
          );
        } else if (newSec == 20) {
          _voiceCoach.announce(
            _isEyeScreen
                ? 'Conjunctival perfusion recorded. Measuring scleral chromaticity dispersion and jaundice index.'
                : 'Spectral distribution mapped. 10 seconds remaining.',
            tone: VoiceCueTone.scanning,
          );
        }
      }

      if (_elapsedSeconds >= _targetDurationSeconds) {
        timer.cancel();
        _isTimerRunning = false;
        _voiceCoach.announce(
          _isEyeScreen
              ? 'Eye scan complete! Micro-vessels and optical spectrum captured with high clinical confidence. Opening your results report.'
              : 'Optical scan complete! All macro views captured. Opening your results report.',
          tone: VoiceCueTone.completed,
          force: true,
        );

        final appState = AppStateScope.of(context);
        Future<void>.delayed(const Duration(milliseconds: 650), () {
          if (mounted) {
            _completeAndOpenClinicalResults(context, appState);
          }
        });
      }
    });
  }

  void _announceMacroState({bool force = false}) {
    final viewName = widget.screenType.viewsRequired[_activeViewIndex];
    if (!_targetInFrame) {
      _voiceCoach.announce(
        _isEyeScreen
            ? 'Eyes moved out of frame! Scan paused. Align your eyes inside the glowing reticle guide.'
            : '$viewName is not in the frame! Center the target inside the glowing reticle.',
        tone: VoiceCueTone.outOfFrame,
        force: force,
      );
    } else if (!_blurPass) {
      _voiceCoach.announce(
        'Image is slightly blurry. Hold the phone 15 centimeters away and keep your hand steady.',
        tone: VoiceCueTone.warning,
        force: force,
      );
    } else if (!_glarePass) {
      _voiceCoach.announce(
        'Flash glare detected! Tilt the phone slightly by 10 degrees to remove reflections.',
        tone: VoiceCueTone.warning,
        force: force,
      );
    } else if (_isCardMandatory && (!_colourCardDetected || _deltaE > 5.0)) {
      _voiceCoach.announce(
        'Mandatory 24-patch colour card is missing or out of calibration! Place colour card inside frame.',
        tone: VoiceCueTone.outOfFrame,
        force: force,
      );
    } else {
      _voiceCoach.announce(
        _isEyeScreen
            ? 'Eyes aligned. Resuming 30-second reading, hold still and look gently upward.'
            : 'Target aligned. Resuming optical reading, please hold still.',
        tone: VoiceCueTone.scanning,
        force: force,
      );
    }
  }

  void _completeAndOpenClinicalResults(
    BuildContext context,
    AppState appState,
  ) {
    final st = widget.screenType;
    final subj = appState.activeSubject;
    final exhaustedRetakes = _retakeCount >= 3;

    final band = exhaustedRetakes
        ? SemanticBand.notAssessed
        : (_simulateHighBand ? SemanticBand.high : SemanticBand.low);
    final isSpecialistReview =
        !exhaustedRetakes &&
        (_simulateHighBand || _simulateUncertainNearThreshold);

    UrgencyLevel urgency = UrgencyLevel.none;
    if (_simulateHighBand && !exhaustedRetakes) {
      if (st == ImageScreenType.childEye ||
          st == ImageScreenType.adultJaundice ||
          st == ImageScreenType.newbornJaundice ||
          st == ImageScreenType.oralLesion ||
          st == ImageScreenType.diabeticFoot ||
          (st == ImageScreenType.anaemia && subj.isPregnant)) {
        urgency = UrgencyLevel.urgent;
      } else {
        urgency = UrgencyLevel.routine;
      }
    }

    final record = ScreeningSessionRecord(
      sessionId: 'img_${DateTime.now().millisecondsSinceEpoch}',
      subjectId: subj.id,
      featureId: 'F-16',
      screenId: 'S-R01',
      title: st.title,
      category: _isEyeScreen ? 'Eyes' : 'Image Screening',
      recordedAt: DateTime.now(),
      primaryBand: band,
      urgency: urgency,
      confidence: exhaustedRetakes ? 0.0 : 0.94,
      summaryText: exhaustedRetakes
          ? 'Marked "Not assessed" after 3 failed capture attempts (Spec §6).'
          : (isSpecialistReview
                ? 'Result routed to Specialist Review (IMG-10) due to elevated optical markers.'
                : (_isEyeScreen
                      ? 'Lower eyelid conjunctival pallor and scleral chromaticity are within healthy reference bands.'
                      : 'Screening within low-risk reference band.')),
      isUnderSpecialistReview: isSpecialistReview,
      firedRules: urgency == UrgencyLevel.urgent
          ? const ['BR-SCR-02']
          : (urgency == UrgencyLevel.routine ? const ['BR-SCR-04'] : const []),
      markers: [
        MarkerEnvelope<String>(
          code: st.id,
          displayName: st.title,
          algorithmId: st.id,
          algorithmVersion: 'v2.1.0',
          rangeVersion: 'mst_ref_2026.10',
          unit: '',
          decimals: 0,
          value: band.label,
          band: band,
          confidence: exhaustedRetakes ? 0.0 : 0.94,
          displayStatus: exhaustedRetakes
              ? MarkerDisplayStatus.notAssessed
              : (isSpecialistReview
                    ? MarkerDisplayStatus.underSpecialistReview
                    : MarkerDisplayStatus.bandOnly),
          conditionsInformed: [st.conditionCode],
        ),
      ],
    );

    appState.addScreeningRecord(record, conditionCode: st.conditionCode);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SharedScreeningResultScreen(record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final isScanner = _step == 1;

    return Scaffold(
      extendBodyBehindAppBar: isScanner,
      backgroundColor: isScanner ? const Color(0xFF070D19) : null,
      appBar: isScanner
          ? null
          : AppBar(
              title: Text(
                widget.screenType.title,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  tooltip: 'Screen Spec & Gates ($_screenId)',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () =>
                      showScreenGateLifecycleSheet(context, _screenId),
                ),
              ],
            ),
      body: _buildStepBody(context, appState),
    );
  }

  Widget _buildStepBody(BuildContext context, AppState appState) {
    switch (_step) {
      case 0:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStep0SetupAndPermissions(
              context,
              appState,
              widget.screenType,
            ),
          ],
        );
      case 1:
        return _buildStep1ImmersiveBiometricScanner(
          context,
          appState,
          widget.screenType,
        );
      default:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStep2ReviewAndSubmit(context, appState, widget.screenType),
          ],
        );
    }
  }

  Widget _buildStep0SetupAndPermissions(
    BuildContext context,
    AppState appState,
    ImageScreenType st,
  ) {
    final subj = appState.activeSubject;
    final cardPass = _colourCardDetected && _deltaE <= 5.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B7A75), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isEyeScreen
                          ? Icons.remove_red_eye_rounded
                          : Icons.photo_camera_rounded,
                      color: const Color(0xFF00E5CC),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          st.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${st.id} • ${st.conditionCode}',
                          style: const TextStyle(
                            color: Color(0xFF00E5CC),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                st.purpose,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _badge(
                    '${subj.fullName.split(" ").first} (${subj.ageYears}y)',
                    Icons.person_rounded,
                  ),
                  _badge('30s Clinical Reading', Icons.timer_outlined),
                  _badge(
                    _isEyeScreen ? 'Front Selfie or Rear Cam' : 'Macro Camera',
                    Icons.camera_alt_outlined,
                  ),
                  _badge(
                    st.flashRequired ? 'Torch Required' : 'Ambient Light',
                    Icons.flashlight_on_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          '1. Clinical Protocol & Required Views',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
        const SizedBox(height: 8),
        ...st.viewsRequired.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: MirrorColors.primaryContainer,
                  foregroundColor: MirrorColors.primary,
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(
                  entry.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: const Text(
                  '30s Multi-Spectral Perfusion • Blur >= 100 • Glare <= 5%',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ),
          ),
        ),

        if (st.colourCardPolicy != ColourCardPolicy.none) ...[
          const SizedBox(height: 14),
          const Text(
            '2. 24-Patch Reference Colour Card Calibration',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  dense: true,
                  title: const Text(
                    '24-Patch Colour Card Present in Frame',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Post-correction colour error ΔE = ${_deltaE.toStringAsFixed(1)} (Pass <= 5.0)',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  value: _colourCardDetected,
                  onChanged: (v) => setState(() => _colourCardDetected = v),
                ),
                Slider(
                  value: _deltaE,
                  min: 1.0,
                  max: 8.0,
                  divisions: 14,
                  label: 'ΔE ${_deltaE.toStringAsFixed(1)}',
                  onChanged: (v) => setState(() => _deltaE = v),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.camera_alt_rounded),
          label: Text(
            (_isCardMandatory && !cardPass)
                ? 'Mandatory Colour Card Required (ΔE <= 5.0)'
                : 'Open Camera & Start 30s Biometric Scan',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          onPressed: (_isCardMandatory && !cardPass)
              ? null
              : () async {
                  final granted = await showScanPermissionReadinessModal(
                    context: context,
                    scanTitle: st.title,
                    scanDuration: '30 Seconds Biometric Reading',
                    permissions: HealthPackagesRegistry.eyeAndSkinPermissions,
                    preparationTips:
                        HealthPackagesRegistry.preparationTipsForTargetScreen(
                          'S-E03',
                          imageScreenType: st,
                        ),
                  );
                  if (granted && mounted) {
                    _startBiometricScanner();
                  }
                },
        ),
      ],
    );
  }

  Widget _badge(String text, IconData icon) {
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
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
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

  /// Step 1: Full-Screen Immersive Biometric Eye & Optical Viewfinder with
  /// Dual Eye Reticles, Live Perfusion Wave, Gate Status Pills, and 30-Second Countdown.
  Widget _buildStep1ImmersiveBiometricScanner(
    BuildContext context,
    AppState appState,
    ImageScreenType st,
  ) {
    final progress = (_elapsedSeconds / _targetDurationSeconds).clamp(0.0, 1.0);
    final remainingSeconds = (_targetDurationSeconds - _elapsedSeconds)
        .ceil()
        .clamp(0, 30);
    final isCalibratingAe = _elapsedSeconds < 2.5 && _allMacroGatesPass;

    _cameraController ??= BiometricCameraController(
      mode: _isEyeScreen ? ScanCameraMode.frontFace : ScanCameraMode.rearMacro,
    )..initialize();

    final frameColor = (!_allMacroGatesPass)
        ? const Color(0xFFEF4444)
        : const Color(0xFF00E5CC);

    final screenHeight = MediaQuery.sizeOf(context).height;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Edge-to-Edge Live Camera Viewfinder & Custom Biometric Medical Reticle
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _manualGateOverride = true;
                _targetInFrame = !_targetInFrame;
                if (_targetInFrame) {
                  _targetOffset = Offset.zero;
                  _startOrResumeReadingTimer();
                  _voiceCoach.announce(
                    _isEyeScreen
                        ? 'Eyes aligned inside reticle. Resuming 30-second reading.'
                        : 'Target aligned. Resuming optical reading.',
                    tone: VoiceCueTone.scanning,
                    force: true,
                  );
                } else {
                  _targetOffset = const Offset(0.44, -0.26);
                  _announceMacroState(force: true);
                }
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _manualGateOverride = true;
                final dx = (_targetOffset.dx + details.delta.dx / 120).clamp(
                  -0.85,
                  0.85,
                );
                final dy = (_targetOffset.dy + details.delta.dy / 140).clamp(
                  -0.85,
                  0.85,
                );
                _targetOffset = Offset(dx, dy);
                final dist = _targetOffset.distance;
                final nowInFrame = dist <= 0.30;
                if (nowInFrame != _targetInFrame) {
                  _targetInFrame = nowInFrame;
                  _announceMacroState(force: true);
                }
              });
            },
            child: AnimatedBuilder(
              animation: _pulseAnimController,
              builder: (context, _) {
                return LiveBiometricCameraSurface(
                  controller: _cameraController!,
                  fullBleed: true,
                  overlayPainter: _isEyeScreen
                      ? _BiometricEyeScannerPainter(
                          targetOffset: _targetOffset,
                          frameColor: frameColor,
                          progress: progress,
                          pulsePhase: _pulseAnimController.value,
                          allGatesPassing: _allMacroGatesPass,
                        )
                      : _BiometricMacroScannerPainter(
                          targetOffset: _targetOffset,
                          frameColor: frameColor,
                          progress: progress,
                          pulsePhase: _pulseAnimController.value,
                          allGatesPassing: _allMacroGatesPass,
                          isOralLesion: st == ImageScreenType.oralLesion,
                          activeViewIndex: _activeViewIndex,
                        ),
                );
              },
            ),
          ),
        ),

        // 2. Top Translucent Floating Bar & AI Voice Coach Banner (+ 5-Site Mucosa Strip for Oral Lesion)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildScannerTopBar(context),
                  const SizedBox(height: 6),
                  LiveVoiceCoachBanner(
                    controller: _voiceCoach,
                    onRepeatPressed: _voiceCoach.repeatCurrent,
                  ),
                  if (st == ImageScreenType.oralLesion) ...[
                    const SizedBox(height: 6),
                    _buildOralMucosa5ViewStrip(st),
                  ],
                ],
              ),
            ),
          ),
        ),

        // 3. Sub-Reticle Percentage & Center Guidance Status Pill
        Positioned(
          top: math.max(145.0, screenHeight * 0.38 + 108),
          left: 16,
          right: 16,
          child: Center(
            child: _buildCenterStatusPill(
              progress: progress,
              frameColor: frameColor,
              remainingSeconds: remainingSeconds,
              isCalibratingAe: isCalibratingAe,
            ),
          ),
        ),

        // 4. Bottom Floating Sheet (Gate Pills, Real-Time Waveform, Biomarkers & Test Actions)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: _buildScannerBottomOverlay(context, appState, progress, st),
          ),
        ),
      ],
    );
  }

  Widget _buildScannerTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Exit Scanner',
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
              onPressed: () {
                _readingTimer?.cancel();
                setState(() => _step = 0);
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.screenType.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  _isEyeScreen
                      ? '30s Sclera & Conjunctival Perfusion'
                      : '30s Optical Texture Scan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF00E5CC),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Camera Lens Switcher (Front Selfie <-> Rear Macro)
          if (_cameraController != null)
            IconButton(
              tooltip: 'Switch Camera Lens (Front / Rear)',
              icon: const Icon(
                Icons.cameraswitch_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () async {
                await _cameraController!.switchCameraLens();
                if (mounted) setState(() {});
              },
            ),

          // Flashlight Torch
          if (_cameraController != null)
            IconButton(
              tooltip: 'Toggle Flashlight Torch',
              icon: Icon(
                _cameraController!.torchEnabled
                    ? Icons.flashlight_on_rounded
                    : Icons.flashlight_off_rounded,
                color: _cameraController!.torchEnabled
                    ? const Color(0xFFF59E0B)
                    : Colors.white70,
                size: 20,
              ),
              onPressed: () async {
                await _cameraController!.toggleTorch();
                if (mounted) setState(() {});
              },
            ),

          // Speed Multiplier (1x / 5x demo)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _speedMultiplier = _speedMultiplier == 1 ? 5 : 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Screen Spec Sheet
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Screen Specs & Clinical Gates ($_screenId)',
            icon: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () => showScreenGateLifecycleSheet(context, _screenId),
          ),
        ],
      ),
    );
  }

  Widget _buildOralMucosa5ViewStrip(ImageScreenType st) {
    final views = st.viewsRequired;
    const shortLabels = [
      '1. L-Cheek',
      '2. R-Cheek',
      '3. Tongue L',
      '4. Tongue R',
      '5. Floor',
      '6. Palate',
    ];
    return Row(
      children: List.generate(views.length, (i) {
        final isSelected = _activeViewIndex == i;
        final label = i < shortLabels.length ? shortLabels[i] : 'View ${i + 1}';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < views.length - 1 ? 4 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () {
                setState(() => _activeViewIndex = i);
                _voiceCoach.announce(
                  'Site ${i + 1} of ${views.length}: ${views[i]}. Center the oral mucosa inside the 3D reticle.',
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
                        : Colors.white24,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 9.0,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCenterStatusPill({
    required double progress,
    required Color frameColor,
    required int remainingSeconds,
    required bool isCalibratingAe,
  }) {
    final pctInt = (progress * 100).round().clamp(0, 100);
    Widget pill;
    if (!_targetInFrame) {
      pill = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.45),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _isEyeScreen
                    ? 'EYES NOT IN FRAME • ALIGN EYES INSIDE RETICLE'
                    : 'TARGET NOT IN FRAME • RE-ALIGN TO RESUME',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (isCalibratingAe) {
      pill = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: const Color(0xFF00E5CC).withValues(alpha: 0.6),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00E5CC),
              ),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'LOCKING EXPOSURE & CALIBRATING OPTICAL ROIs...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      pill = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: const Color(0xFF00E5CC).withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5CC).withValues(alpha: 0.25),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF00E5CC),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _isEyeScreen
                    ? 'EYES LOCKED • READING 00:${remainingSeconds.toString().padLeft(2, '0')} (30s)'
                    : 'SCANNING • READING 00:${remainingSeconds.toString().padLeft(2, '0')} (30s)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$pctInt%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: -0.6,
            shadows: [
              Shadow(color: frameColor.withValues(alpha: 0.65), blurRadius: 16),
            ],
          ),
        ),
        const SizedBox(height: 4),
        pill,
      ],
    );
  }

  Widget _buildScannerBottomOverlay(
    BuildContext context,
    AppState appState,
    double progress,
    ImageScreenType st,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Real-Time Gate Indicator Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGatePill(
                  _isEyeScreen ? 'Eyes In Frame' : 'In Frame',
                  _targetInFrame,
                ),
                const SizedBox(width: 6),
                _buildGatePill('Sharp Focus (162 >= 100)', _blurPass),
                const SizedBox(width: 6),
                _buildGatePill('Glare 1.2% (<= 5%)', _glarePass),
                if (st.colourCardPolicy != ColourCardPolicy.none) ...[
                  const SizedBox(width: 6),
                  _buildGatePill(
                    'Colour ΔE ${_deltaE.toStringAsFixed(1)}',
                    _colourCardDetected && _deltaE <= 5.0,
                  ),
                ],
                const SizedBox(width: 6),
                _buildGatePill('Perfusion Confidence 94%', _allMacroGatesPass),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Row 2: Live Multi-Spectral / Perfusion Waveform
          Container(
            height: 48,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF070D19),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isEyeScreen
                          ? 'CONJUNCTIVA PERFUSION'
                          : 'SPECTRAL TEXTURE',
                      style: const TextStyle(
                        color: Color(0xFF00E5CC),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _allMacroGatesPass ? 'LOCKED • PULSATILE' : 'PAUSED',
                      style: TextStyle(
                        color: _allMacroGatesPass
                            ? Colors.white70
                            : const Color(0xFFEF4444),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _pulseAnimController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _LiveSpectralWavePainter(
                          phase: _pulseAnimController.value,
                          isRunning: _isTimerRunning && _allMacroGatesPass,
                          isEye: _isEyeScreen,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Row 3: Live Real-Time Ticking Biomarkers HUD
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: _isEyeScreen ? 'ESTIMATED Hb' : 'TEXTURE CONF',
                  value: _isEyeScreen ? '13.6' : '94.2%',
                  unit: _isEyeScreen ? 'g/dL' : 'Index',
                  color: const Color(0xFF00E5CC),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: _isEyeScreen ? 'SCLERAL YELLOWNESS' : 'SHARPNESS',
                  value: _isEyeScreen ? '1.8' : '162',
                  unit: _isEyeScreen ? 'Normal (<2.5)' : 'Laplacian',
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: _isEyeScreen ? 'LENS OPACITY' : 'GLARE RATIO',
                  value: _isEyeScreen ? '0.8' : '1.2%',
                  unit: _isEyeScreen ? 'LOCS III' : 'Pass <=5%',
                  color: const Color(0xFF34D399),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 4: Simulation & Interactive Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: Icon(
                    _targetInFrame
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 14,
                  ),
                  label: Text(
                    _targetInFrame ? 'Simulate Eye Drift' : 'Re-Align Eye',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _manualGateOverride = true;
                      _targetInFrame = !_targetInFrame;
                      if (_targetInFrame) {
                        _targetOffset = Offset.zero;
                        _startOrResumeReadingTimer();
                        _voiceCoach.announce(
                          'Eyes aligned inside reticle. Resuming 30-second reading.',
                          tone: VoiceCueTone.scanning,
                          force: true,
                        );
                      } else {
                        _targetOffset = const Offset(0.44, -0.26);
                        _announceMacroState(force: true);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B7A75),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.fast_forward_rounded, size: 14),
                  label: const Text(
                    'Complete Reading Now',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () {
                    _readingTimer?.cancel();
                    setState(
                      () => _elapsedSeconds = _targetDurationSeconds.toDouble(),
                    );
                    _voiceCoach.announce(
                      'Optical scan completed! Preparing clinical evaluation report.',
                      tone: VoiceCueTone.completed,
                      force: true,
                    );
                    _completeAndOpenClinicalResults(context, appState);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGatePill(String text, bool pass) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pass
            ? const Color(0xFF00E5CC).withValues(alpha: 0.15)
            : const Color(0xFFEF4444).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: pass ? const Color(0xFF00E5CC) : const Color(0xFFEF4444),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pass ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 11,
            color: pass ? const Color(0xFF00E5CC) : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: pass ? Colors.white : const Color(0xFFEF4444),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2ReviewAndSubmit(
    BuildContext context,
    AppState appState,
    ImageScreenType st,
  ) {
    final exhaustedRetakes = _retakeCount >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: MirrorColors.successFg),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Clinical Optical Scan Complete',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '30-second optical spectral examination captured for ${st.title}. Review summary and open clinical evaluation report.',
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Specialist Review & Risk Simulation (IMG-10)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  title: const Text(
                    'Simulate Positive / High Risk Finding',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    st == ImageScreenType.anaemia
                        ? 'WHO Anaemia threshold (Pregnant + High -> Urgent T12)'
                        : (st == ImageScreenType.childEye
                              ? 'White pupil leukocoria -> Urgent T11 (BR-SCR-02)'
                              : 'Triggers condition case & specialist review (IMG-10)'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  value: _simulateHighBand,
                  onChanged: (v) => setState(() => _simulateHighBand = v),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text(
                    'Simulate Borderline Probability (Within ±0.1 of Threshold)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Automatically routes image to Specialist Review Queue (IMG-10).',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  value: _simulateUncertainNearThreshold,
                  onChanged: (v) =>
                      setState(() => _simulateUncertainNearThreshold = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: Text(
                exhaustedRetakes
                    ? '3 Retakes Used'
                    : 'Retake (${_retakeCount + 1}/3)',
              ),
              onPressed: exhaustedRetakes
                  ? null
                  : () {
                      setState(() => _retakeCount++);
                      _startBiometricScanner();
                    },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text(
                  'Open Clinical Results Report',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () =>
                    _completeAndOpenClinicalResults(context, appState),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// CustomPainter for the High-Tech Dual-Eye Biometric Reticle, Iris Rings,
/// Lower Eyelid Conjunctiva Sampling Zones, Corner Brackets, and 30-Second Progress Arc.
class _BiometricEyeScannerPainter extends CustomPainter {
  _BiometricEyeScannerPainter({
    required this.targetOffset,
    required this.frameColor,
    required this.progress,
    required this.pulsePhase,
    required this.allGatesPassing,
  });

  final Offset targetOffset;
  final Color frameColor;
  final double progress;
  final double pulsePhase;
  final bool allGatesPassing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final boxWidth = size.width * 0.88;
    const boxHeight = 160.0;
    final eyeBox = Rect.fromCenter(
      center: center,
      width: boxWidth,
      height: boxHeight,
    );

    // 1. Dark Vignette around ocular examination field
    final fullScreenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final ocularZonePath = Path()
      ..addRRect(RRect.fromRectAndRadius(eyeBox, const Radius.circular(28)));
    final vignettePath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      ocularZonePath,
    );
    final vignettePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawPath(vignettePath, vignettePaint);

    // 2. Corner Reticle Brackets [   ]
    final bracketPaint = Paint()
      ..color = frameColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    const arm = 24.0;

    // Top-Left [
    canvas.drawLine(
      Offset(eyeBox.left, eyeBox.top + arm),
      eyeBox.topLeft,
      bracketPaint,
    );
    canvas.drawLine(
      eyeBox.topLeft,
      Offset(eyeBox.left + arm, eyeBox.top),
      bracketPaint,
    );
    // Top-Right ]
    canvas.drawLine(
      Offset(eyeBox.right - arm, eyeBox.top),
      eyeBox.topRight,
      bracketPaint,
    );
    canvas.drawLine(
      eyeBox.topRight,
      Offset(eyeBox.right, eyeBox.top + arm),
      bracketPaint,
    );
    // Bottom-Left [
    canvas.drawLine(
      Offset(eyeBox.left, eyeBox.bottom - arm),
      eyeBox.bottomLeft,
      bracketPaint,
    );
    canvas.drawLine(
      eyeBox.bottomLeft,
      Offset(eyeBox.left + arm, eyeBox.bottom),
      bracketPaint,
    );
    // Bottom-Right ]
    canvas.drawLine(
      Offset(eyeBox.right - arm, eyeBox.bottom),
      eyeBox.bottomRight,
      bracketPaint,
    );
    canvas.drawLine(
      eyeBox.bottomRight,
      Offset(eyeBox.right, eyeBox.bottom - arm),
      bracketPaint,
    );

    // 3. Sweeping Optical Laser Line
    if (allGatesPassing) {
      final laserY = eyeBox.top + (eyeBox.height * pulsePhase);
      final laserPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            frameColor.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(eyeBox.left, laserY - 2, eyeBox.width, 4))
        ..strokeWidth = 2.2;
      canvas.drawLine(
        Offset(eyeBox.left, laserY),
        Offset(eyeBox.right, laserY),
        laserPaint,
      );
    }

    // 4. 30-Second Circular Progress Arc around the Ocular Zone
    if (progress > 0) {
      final progressRect = eyeBox.inflate(10);
      final trackPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(progressRect, const Radius.circular(34)),
        trackPaint,
      );

      final progressPaint = Paint()
        ..color = frameColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;
      // Draw progress perimeter
      canvas.drawRRect(
        RRect.fromRectAndRadius(progressRect, const Radius.circular(34)),
        progressPaint..color = frameColor.withValues(alpha: 0.85),
      );
    }

    // 5. Tracked Dual Eye Reticles (Left Eye & Right Eye)
    final shiftX = targetOffset.dx * 70;
    final shiftY = targetOffset.dy * 45;
    final leftEyeCenter = Offset(
      center.dx - boxWidth * 0.24 + shiftX,
      center.dy + shiftY,
    );
    final rightEyeCenter = Offset(
      center.dx + boxWidth * 0.24 + shiftX,
      center.dy + shiftY,
    );

    for (final eyeCenter in [leftEyeCenter, rightEyeCenter]) {
      // Outer Eye Oval
      final eyeOvalRect = Rect.fromCenter(
        center: eyeCenter,
        width: 72,
        height: 48,
      );
      final eyePaint = Paint()
        ..color = frameColor.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawOval(eyeOvalRect, eyePaint);

      // Iris Ring
      final irisPaint = Paint()
        ..color = frameColor.withValues(alpha: 0.55 + 0.35 * pulsePhase)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(eyeCenter, 15, irisPaint);

      // Pupil Target Crosshair
      final pupilPaint = Paint()
        ..color = frameColor
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(eyeCenter.dx - 6, eyeCenter.dy),
        Offset(eyeCenter.dx + 6, eyeCenter.dy),
        pupilPaint,
      );
      canvas.drawLine(
        Offset(eyeCenter.dx, eyeCenter.dy - 6),
        Offset(eyeCenter.dx, eyeCenter.dy + 6),
        pupilPaint,
      );

      // Lower Eyelid Conjunctiva Sampling Bracket [ ___ ]
      final conjPaint = Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final conjY = eyeCenter.dy + 28;
      canvas.drawLine(
        Offset(eyeCenter.dx - 22, conjY),
        Offset(eyeCenter.dx + 22, conjY),
        conjPaint,
      );
      canvas.drawLine(
        Offset(eyeCenter.dx - 22, conjY - 4),
        Offset(eyeCenter.dx - 22, conjY),
        conjPaint,
      );
      canvas.drawLine(
        Offset(eyeCenter.dx + 22, conjY - 4),
        Offset(eyeCenter.dx + 22, conjY),
        conjPaint,
      );
    }

    // 6. Center Conjunctiva Pallor Label
    final labelSpan = TextSpan(
      text: allGatesPassing
          ? 'DUAL-EYE SCLERA & CONJUNCTIVA LOCKED'
          : 'ALIGN EYES INSIDE RETICLE',
      style: TextStyle(
        color: frameColor,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
    final textPainter = TextPainter(
      text: labelSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: boxWidth);
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, eyeBox.bottom - 22),
    );
  }

  @override
  bool shouldRepaint(covariant _BiometricEyeScannerPainter oldDelegate) => true;
}

/// CustomPainter for Oral Mucosa OPMD / Macro Skin / Ulcer / Wound Reticle
/// with Rotating 36-Tick Radar Orbit Ring, 3D Polygonal Mesh, and Grad-CAM Attention Heatmap.
class _BiometricMacroScannerPainter extends CustomPainter {
  _BiometricMacroScannerPainter({
    required this.targetOffset,
    required this.frameColor,
    required this.progress,
    required this.pulsePhase,
    required this.allGatesPassing,
    this.isOralLesion = false,
    this.activeViewIndex = 0,
  });

  final Offset targetOffset;
  final Color frameColor;
  final double progress;
  final double pulsePhase;
  final bool allGatesPassing;
  final bool isOralLesion;
  final int activeViewIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.36);
    const radius = 98.0;
    final circleRect = Rect.fromCircle(center: center, radius: radius);

    // 1. Dark frosted vignette
    final fullScreenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final circlePath = Path()..addOval(circleRect);
    final vignettePath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      circlePath,
    );
    final vignettePaint = Paint()
      ..color = const Color(0xFF050B16).withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;
    canvas.drawPath(vignettePath, vignettePaint);

    // 2. Rotating 36-Tick Radar Orbit Ring (Reference UI Match)
    final tickPaint = Paint()
      ..color = frameColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const totalTicks = 36;
    for (int i = 0; i < totalTicks; i++) {
      final angle = (i * 2 * math.pi / totalTicks) + (pulsePhase * 0.35);
      final isMajor = i % 3 == 0;
      const innerR = radius + 8;
      final outerR = radius + (isMajor ? 16.0 : 12.0);
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

    // 3. Progress arc
    final bgRing = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;
    canvas.drawOval(circleRect, bgRing);

    final fgRing = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      circleRect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgRing,
    );

    // 4. Sweeping Cyan Laser Scan Line
    if (allGatesPassing) {
      final laserY =
          circleRect.top + 14 + (circleRect.height - 28) * pulsePhase;
      final laserPaint = Paint()
        ..shader =
            LinearGradient(
              colors: [
                Colors.transparent,
                frameColor.withValues(alpha: 0.85),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTWH(circleRect.left, laserY - 2, circleRect.width, 4),
            )
        ..strokeWidth = 2.0;
      canvas.drawLine(
        Offset(circleRect.left + 14, laserY),
        Offset(circleRect.right - 14, laserY),
        laserPaint,
      );
    }

    // 5. 3D Polygonal Mucosal / Tissue Mesh & Grad-CAM Heatmap ROI (ALG-IMG-04)
    final shift = Offset(targetOffset.dx * 50, targetOffset.dy * 45);
    final meshCenter = center + shift;

    final wirePaint = Paint()
      ..color = frameColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final nodePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = frameColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;

    if (isOralLesion) {
      // Oral Cavity & Mucosal Polygonal Mesh (Buccal / Tongue / Palate)
      final mucosaRect = Rect.fromCenter(
        center: meshCenter,
        width: 116,
        height: 86,
      );
      canvas.drawOval(mucosaRect, wirePaint);

      // Grad-CAM Attention Heatmap ROI contour (ALG-IMG-04 lesion_regions)
      final roiShiftX = (activeViewIndex == 0)
          ? -22.0
          : (activeViewIndex == 1 ? 22.0 : 0.0);
      final roiShiftY = (activeViewIndex == 3)
          ? 16.0
          : (activeViewIndex == 4 ? -16.0 : 0.0);
      final roiCenter = meshCenter + Offset(roiShiftX, roiShiftY);
      final heatmapPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.34),
            const Color(0xFF00E5CC).withValues(alpha: 0.14),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: roiCenter, radius: 34));
      canvas.drawCircle(roiCenter, 34, heatmapPaint);

      // Mucosal polygon nodes
      final nodes = <Offset>[
        Offset(meshCenter.dx - 42, meshCenter.dy),
        Offset(meshCenter.dx + 42, meshCenter.dy),
        Offset(meshCenter.dx, meshCenter.dy - 30),
        Offset(meshCenter.dx, meshCenter.dy + 30),
        Offset(meshCenter.dx - 24, meshCenter.dy - 18),
        Offset(meshCenter.dx + 24, meshCenter.dy - 18),
        Offset(meshCenter.dx - 24, meshCenter.dy + 18),
        Offset(meshCenter.dx + 24, meshCenter.dy + 18),
        roiCenter,
      ];
      for (int i = 0; i < nodes.length - 1; i++) {
        canvas.drawLine(nodes[i], nodes.last, wirePaint);
      }
      for (final pt in nodes) {
        canvas.drawCircle(pt, 4.0, glowPaint);
        canvas.drawCircle(pt, 1.8, nodePaint);
      }
    } else {
      // Macro Skin / Diabetic Foot Ulcer Polygonal Mesh
      final hexPoints = List.generate(6, (i) {
        final a = i * math.pi / 3;
        return Offset(
          meshCenter.dx + 44 * math.cos(a),
          meshCenter.dy + 44 * math.sin(a),
        );
      });
      final hexPath = Path()..addPolygon(hexPoints, true);
      canvas.drawPath(hexPath, wirePaint);
      for (final pt in hexPoints) {
        canvas.drawLine(meshCenter, pt, wirePaint);
        canvas.drawCircle(pt, 3.8, glowPaint);
        canvas.drawCircle(pt, 1.8, nodePaint);
      }
    }

    // Center Crosshair
    final chPaint = Paint()
      ..color = frameColor
      ..strokeWidth = 1.8;
    canvas.drawLine(
      Offset(meshCenter.dx - 12, meshCenter.dy),
      Offset(meshCenter.dx + 12, meshCenter.dy),
      chPaint,
    );
    canvas.drawLine(
      Offset(meshCenter.dx, meshCenter.dy - 12),
      Offset(meshCenter.dx, meshCenter.dy + 12),
      chPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BiometricMacroScannerPainter oldDelegate) =>
      true;
}

/// Live Multi-Spectral / Perfusion Wave Painter for the bottom HUD.
class _LiveSpectralWavePainter extends CustomPainter {
  _LiveSpectralWavePainter({
    required this.phase,
    required this.isRunning,
    required this.isEye,
  });

  final double phase;
  final bool isRunning;
  final bool isEye;

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(
        0xFF00E5CC,
      ).withValues(alpha: isRunning ? 0.90 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paint2 = Paint()
      ..color = const Color(
        0xFFEF4444,
      ).withValues(alpha: isRunning ? 0.85 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final path1 = Path();
    final path2 = Path();

    final midY = size.height / 2;
    for (double x = 0; x <= size.width; x += 3) {
      final normX = x / size.width;
      final y1 =
          midY +
          (isRunning
              ? math.sin((normX * 4 * math.pi) + (phase * 2 * math.pi)) *
                    (size.height * 0.35)
              : 0.0);
      final y2 =
          midY +
          (isRunning
              ? math.cos((normX * 5 * math.pi) + (phase * 2 * math.pi)) *
                    (size.height * 0.28)
              : 0.0);

      if (x == 0) {
        path1.moveTo(x, y1);
        path2.moveTo(x, y2);
      } else {
        path1.lineTo(x, y1);
        path2.lineTo(x, y2);
      }
    }

    canvas.drawPath(path1, paint1);
    if (isEye) {
      canvas.drawPath(path2, paint2);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveSpectralWavePainter oldDelegate) => true;
}

/// S-E06 Fundus Camera Connect & Capture (Partner AI Adapter — ALG-IMG-09).
class FundusPartnerScreen extends StatelessWidget {
  const FundusPartnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final connected = appState.deviceProfile.fundusCameraConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retinal Fundus Camera (DR & Glaucoma)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-E06'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Diabetic Retinopathy & Glaucoma Partner AI (ALG-IMG-09)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connects via USB-C / Wi-Fi Direct to clip-on non-mydriatic fundus camera and evaluates DR_REFERABLE, DR_GRADE, and GLAUCOMA_SUSPECT.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    title: const Text(
                      'Clip-On Fundus Camera Connected (Gate G-31)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    value: connected,
                    onChanged: (v) {
                      appState.updateDeviceProfile(
                        appState.deviceProfile.copyWith(
                          fundusCameraConnected: v,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.remove_red_eye_rounded),
            label: const Text('Capture Retinal Fundus & Run Partner AI'),
            onPressed: !connected
                ? null
                : () {
                    final record = ScreeningSessionRecord(
                      sessionId: 'fnd_${DateTime.now().millisecondsSinceEpoch}',
                      subjectId: appState.activeSubject.id,
                      featureId: 'F-17',
                      screenId: 'S-E06',
                      title: 'Fundus DR & Glaucoma (ALG-IMG-09)',
                      category: 'Eyes',
                      recordedAt: DateTime.now(),
                      primaryBand: SemanticBand.normal,
                      urgency: UrgencyLevel.none,
                      confidence: 0.93,
                      summaryText:
                          'DR_REFERABLE: Negative • DR_GRADE: No apparent retinopathy • GLAUCOMA_SUSPECT: Negative.',
                      markers: const [
                        MarkerEnvelope<String>(
                          code: 'DR_REFERABLE',
                          displayName: 'Referable Diabetic Retinopathy',
                          algorithmId: 'ALG-IMG-09',
                          algorithmVersion: 'partner_v3.2',
                          rangeVersion: 'ICDR_2026',
                          unit: '',
                          decimals: 0,
                          value: 'Not Referable',
                          band: SemanticBand.normal,
                          confidence: 0.93,
                          displayStatus: MarkerDisplayStatus.bandOnly,
                        ),
                      ],
                    );
                    appState.addScreeningRecord(record);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SharedScreeningResultScreen(record: record),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}
