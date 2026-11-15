import 'package:flutter/material.dart';
import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/risk_engine.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../results_cases/results_cases_screens.dart';

/// Flagship Movement, Touch, Stroke FAST & Vision Interactive Studio (S-H01 .. S-H10):
/// Includes live AI Voice Coach, interactive Finger Tap Arena, 3D IMU Gait/Tremor gauge,
/// Stroke FAST emergency triage (T10 -> S-R02), and Vision Acuity at 40 ± 5 cm.
class MovementVisionSuiteScreen extends StatefulWidget {
  const MovementVisionSuiteScreen({super.key, this.initialScreenId = 'S-H06'});

  final String initialScreenId;

  @override
  State<MovementVisionSuiteScreen> createState() =>
      _MovementVisionSuiteScreenState();
}

class _MovementVisionSuiteScreenState extends State<MovementVisionSuiteScreen> {
  late String _activeScreenId;
  late final VoiceCoachController _voiceCoach;

  // S-H01 & S-H02 Finger Tapping
  int _leftTapCount = 24;
  int _rightTapCount = 26;

  // S-H03 Gait (CAP-15: >= 5 step cycles)
  int _stepCyclesDetected = 8;

  // S-H04 5x Sit-to-Stand
  double _fiveStsSeconds = 11.4;

  // S-H05 Tremor
  final double _restTremorHz = 4.8;
  final double _posturalTremorRms = 0.08;

  // S-H06 Stroke FAST Check (MOV-06..09)
  bool _faceDroopDetected = false;
  bool _armDriftDetected = false;
  bool _speechSlurredDetected = false;

  // S-H07..H10 Vision & Reaction
  double _viewingDistanceCm = 40.0; // Pass: 40 ± 5 cm
  final double _leftLogMar = 0.0;
  final double _rightLogMar = 0.1;
  final int _ishiharaCorrect = 12;
  bool _amslerDistortionMarked = false;
  final int _visualRtMedianMs = 248;
  final int _audioRtMedianMs = 215;

  // S-H01..S-H05 (movement) and S-H07..S-H10 (vision) now run as guided
  // tests in lib/features/movement and lib/features/vision; this suite
  // keeps the stroke FAST check.
  static const Map<String, String> _tabs = {'S-H06': 'Stroke FAST Check'};

  @override
  void initState() {
    super.initState();
    _activeScreenId = widget.initialScreenId;
    _voiceCoach = VoiceCoachController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentTask();
    });
  }

  @override
  void dispose() {
    _voiceCoach.dispose();
    super.dispose();
  }

  void _announceCurrentTask() {
    if (_activeScreenId == 'S-H07' &&
        (_viewingDistanceCm < 35.0 || _viewingDistanceCm > 45.0)) {
      _voiceCoach.announce(
        'Phone distance is ${_viewingDistanceCm.round()} cm! Move phone to 40 centimeters (35 to 45 cm) to unlock Vision Acuity.',
        tone: VoiceCueTone.outOfFrame,
        force: true,
      );
      return;
    }
    switch (_activeScreenId) {
      case 'S-H06':
        _voiceCoach.announce(
          'Stroke FAST Emergency Check: Smile for facial symmetry, hold both arms out for 10 seconds, and repeat the test sentence.',
          tone: VoiceCueTone.ready,
          force: true,
        );
      case 'S-H07':
        _voiceCoach.announce(
          'Viewing distance locked at ${_viewingDistanceCm.round()} cm. Cover one eye and swipe in the direction of the Tumbling-E.',
          tone: VoiceCueTone.scanning,
          force: true,
        );
      default:
        _voiceCoach.announce(
          'Motor, neurological, and vision testing studio active. Follow the guided prompts.',
          tone: VoiceCueTone.ready,
          force: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_activeScreenId] ?? 'Movement & Vision Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () =>
                showScreenGateLifecycleSheet(context, _activeScreenId),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _tabs.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _activeScreenId == e.key,
                    onSelected: (_) {
                      setState(() => _activeScreenId = e.key);
                      _announceCurrentTask();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                LiveVoiceCoachBanner(controller: _voiceCoach),
                const SizedBox(height: 14),
                _buildActiveMovementVisionBody(context, appState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Spec output markers (Doc 09 §9) for the active suite, fed from the demo
  /// state; anything the demo does not measure is listed as not available.
  List<ReadingGroup> _outputsForActiveScreen() {
    switch (_activeScreenId) {
      case 'S-H01':
      case 'S-H02':
      case 'S-H03':
      case 'S-H04':
      case 'S-H05':
        return MarkerReadings.fromValues(
          {
            'TAP_COUNT_L': _leftTapCount,
            'TAP_COUNT_R': _rightTapCount,
            'STEPS': _stepCyclesDetected,
            'TREMOR_FREQ': _restTremorHz,
            'TREMOR_AMP': _posturalTremorRms,
            'PD_BAND': 'low',
          },
          const [
            'ALG-MOV-01',
            'ALG-MOV-02',
            'ALG-MOV-03',
            'ALG-MOV-04',
            'ALG-MOV-05',
            'ALG-MOV-13',
          ],
          bands: {
            'TREMOR_FREQ': _restTremorHz >= 3 && _restTremorHz <= 12
                ? SemanticBand.borderline
                : SemanticBand.normal,
            'PD_BAND': SemanticBand.low,
          },
        );
      case 'S-H06':
        final positive =
            _faceDroopDetected || _armDriftDetected || _speechSlurredDetected;
        return MarkerReadings.fromValues(
          {
            'FACE_ASYM_SIDE': _faceDroopDetected ? 'left' : 'none',
            'STROKE_POSITIVE': positive,
          },
          const ['ALG-MOV-06..09'],
          bands: {
            'FACE_ASYM_SIDE': _faceDroopDetected
                ? SemanticBand.emergency
                : SemanticBand.normal,
            'STROKE_POSITIVE': positive
                ? SemanticBand.emergency
                : SemanticBand.normal,
          },
          missingReason: 'Sign recorded as a switch in this demo — no score',
        );
      case 'S-H07':
      case 'S-H08':
      case 'S-H09':
      case 'S-H10':
        return MarkerReadings.fromValues(
          {
            'LOGMAR_L': _leftLogMar,
            'LOGMAR_R': _rightLogMar,
            'COLOUR_PLATE_SCORE': _ishiharaCorrect,
            'AMSLER_ABNORMAL': _amslerDistortionMarked,
            'RT_VISUAL_MS': _visualRtMedianMs,
            'RT_AUDIO_MS': _audioRtMedianMs,
          },
          const ['ALG-MOV-10', 'ALG-MOV-11', 'ALG-MOV-12'],
          bands: {
            'LOGMAR_L': _leftLogMar <= 0.2
                ? SemanticBand.normal
                : SemanticBand.refer,
            'LOGMAR_R': _rightLogMar <= 0.2
                ? SemanticBand.normal
                : SemanticBand.refer,
            'COLOUR_PLATE_SCORE': _ishiharaCorrect >= 12
                ? SemanticBand.normal
                : SemanticBand.refer,
            'AMSLER_ABNORMAL': _amslerDistortionMarked
                ? SemanticBand.refer
                : SemanticBand.normal,
          },
        );
      default:
        return const [];
    }
  }

  Widget _buildActiveMovementVisionBody(
    BuildContext context,
    AppState appState,
  ) {
    final body = _suiteBody(context, appState);
    final groups = _outputsForActiveScreen();
    if (groups.isEmpty) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        const SizedBox(height: 16),
        AlgorithmOutputsSection(
          groups: groups,
          caption:
              'Spec §9 output markers for this suite · values from the demo controls',
        ),
      ],
    );
  }

  Widget _suiteBody(BuildContext context, AppState appState) {
    switch (_activeScreenId) {
      case 'S-H01':
      case 'S-H02':
      case 'S-H03':
      case 'S-H04':
      case 'S-H05':
        return _buildMotorAndPdSuite(context, appState);
      case 'S-H06':
        return _buildStrokeFastCheck(context, appState);
      case 'S-H07':
      case 'S-H08':
      case 'S-H09':
      case 'S-H10':
        return _buildVisionAndReactionSuite(context, appState);
      default:
        return _buildMotorAndPdSuite(context, appState);
    }
  }

  Widget _buildMotorAndPdSuite(BuildContext context, AppState appState) {
    final gaitValid = _stepCyclesDetected >= 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Interactive Finger Tapping Arena (10s per Hand · ALG-MOV-01/02)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.touch_app_rounded),
                        label: Text('Left Tap ($_leftTapCount)'),
                        onPressed: () => setState(() => _leftTapCount++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.touch_app_rounded),
                        label: Text('Right Tap ($_rightTapCount)'),
                        onPressed: () => setState(() => _rightTapCount++),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  '10-Second Gait Step Cycles: $_stepCyclesDetected (Pass >= 5 cycles)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _stepCyclesDetected.toDouble(),
                  min: 2,
                  max: 14,
                  divisions: 12,
                  onChanged: (v) =>
                      setState(() => _stepCyclesDetected = v.round()),
                ),
                Text(
                  '5x Sit-to-Stand Time: ${_fiveStsSeconds.toStringAsFixed(1)} s',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _fiveStsSeconds,
                  min: 6.0,
                  max: 25.0,
                  onChanged: (v) => setState(() => _fiveStsSeconds = v),
                ),
                Text(
                  'Rest Tremor Peak (4–6 Hz): ${_restTremorHz.toStringAsFixed(1)} Hz · RMS ${_posturalTremorRms.toStringAsFixed(2)} m/s²',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    BandChip(
                      band: gaitValid
                          ? SemanticBand.rangeNotAvailable
                          : SemanticBand.notAssessed,
                      customLabel: gaitValid
                          ? 'Gait Cadence: 112 steps/min'
                          : 'Gait Retake Needed (< 5 step cycles)',
                    ),
                    const BandChip(
                      band: SemanticBand.low,
                      customLabel: 'Parkinson Composite (ALG-MOV-13): Low Risk',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// S-H06 Stroke FAST Check (Spec §9.6 & §10 Case T10: BR-SCR-01 -> Emergency S-R02)
  Widget _buildStrokeFastCheck(BuildContext context, AppState appState) {
    final strokePositive =
        _faceDroopDetected || _armDriftDetected || _speechSlurredDetected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stroke FAST Emergency Check (ALG-MOV-06..09)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 6),
            const Text(
              'Any single positive sign (Face droop, Arm drift, or Speech slur) sets STROKE_POSITIVE = True and immediately triggers Emergency Alert (S-R02).',
              style: TextStyle(fontSize: 13),
            ),
            const Divider(height: 22),
            SwitchListTile(
              title: const Text(
                'F — Facial Droop on Smile (Mouth-Corner Asymmetry)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              value: _faceDroopDetected,
              onChanged: (v) => setState(() => _faceDroopDetected = v),
            ),
            SwitchListTile(
              title: const Text(
                'A — Arm Drift During 10-s Hold (IMU Tilt / Drop)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              value: _armDriftDetected,
              onChanged: (v) => setState(() => _armDriftDetected = v),
            ),
            SwitchListTile(
              title: const Text(
                'S — Slurred Speech on Sentence Repetition',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              value: _speechSlurredDetected,
              onChanged: (v) => setState(() => _speechSlurredDetected = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: strokePositive
                      ? MirrorColors.dangerFg
                      : MirrorColors.primary,
                ),
                icon: Icon(
                  strokePositive
                      ? Icons.emergency_rounded
                      : Icons.check_circle_outline_rounded,
                ),
                label: Text(
                  strokePositive
                      ? 'STROKE_POSITIVE -> Trigger Emergency (S-R02)'
                      : 'Complete FAST Check (Negative)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: () {
                  final eval = RiskEngine.evaluateUrgency(
                    RiskEvaluationInput(strokePositive: strokePositive),
                  );
                  if (strokePositive) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EmergencyAlertScreen(
                          title:
                              'Stroke FAST Warning Sign Detected (BR-SCR-01)',
                          reasons: [
                            if (_faceDroopDetected) 'Facial Droop on Smile',
                            if (_armDriftDetected) 'Arm Drift on 10s Hold',
                            if (_speechSlurredDetected)
                              'Slurred Speech Repetition',
                            ...eval.firedRuleCodes,
                          ],
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('FAST Check Negative — No acute signs.'),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisionAndReactionSuite(BuildContext context, AppState appState) {
    final distancePass =
        _viewingDistanceCm >= 35.0 && _viewingDistanceCm <= 45.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visual Acuity (40 ± 5 cm), Ishihara, Amsler Grid & Reaction Time',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Front Camera Face Distance Lock: ${_viewingDistanceCm.toStringAsFixed(0)} cm (Required: 35–45 cm)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: distancePass
                    ? MirrorColors.successFg
                    : MirrorColors.dangerFg,
              ),
            ),
            Slider(
              value: _viewingDistanceCm,
              min: 20,
              max: 60,
              onChanged: (v) {
                setState(() => _viewingDistanceCm = v);
                _announceCurrentTask();
              },
            ),
            const Divider(),
            Text(
              'Left Eye logMAR: ${_leftLogMar.toStringAsFixed(1)} · Right Eye logMAR: ${_rightLogMar.toStringAsFixed(1)}',
            ),
            Text('Ishihara Colour Plates: $_ishiharaCorrect / 12 correct'),
            SwitchListTile(
              title: const Text(
                'Amsler Grid Wavy / Missing Lines Marked (Metamorphopsia)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              value: _amslerDistortionMarked,
              onChanged: (v) => setState(() => _amslerDistortionMarked = v),
            ),
            Text(
              'Visual RT Median: $_visualRtMedianMs ms · Auditory RT Median: $_audioRtMedianMs ms (Discards < 100 ms)',
            ),
          ],
        ),
      ),
    );
  }
}
