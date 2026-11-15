import 'package:flutter/material.dart';
import '../../core/design_system/algorithm_outputs_section.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/marker_readings.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/marker_envelope.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';

/// Flagship Acoustic, Respiratory, Sleep, Hearing, Cognitive, Mood & HF Suite (S-G01 .. S-G15):
/// Includes live AI Voice Coach, animated 24-bar Audio Spectrum Analyzer,
/// Room Noise Gate (<= 45 dBA), and immediate Crisis Support (S-G14) override on PHQ-9 Item 9 > 0.
class AudioSuiteScreen extends StatefulWidget {
  const AudioSuiteScreen({super.key, this.initialScreenId = 'S-G01'});

  final String initialScreenId;

  @override
  State<AudioSuiteScreen> createState() => _AudioSuiteScreenState();
}

class _AudioSuiteScreenState extends State<AudioSuiteScreen>
    with SingleTickerProviderStateMixin {
  late String _activeScreenId;
  late final VoiceCoachController _voiceCoach;
  late final AnimationController _spectrumAnim;

  // S-G01 Audio Readiness (CAP-11/12)
  double _roomNoiseDba = 36.0; // Pass <= 45 dBA (<= 40 dBA for Hearing)
  final double _micSweepDevDb = 2.2; // Pass <= 6 dB

  // S-G02..G06 Respiratory & Cough/Voice/Spirometry
  int _validCoughsCount = 3; // CAP-13: >= 3 coughs
  double _sustainedVowelSec = 4.2; // CAP-14: >= 3.0 s
  bool _simulateTbHigh = false;
  final int _forcedBlowsRepeatable = 3;

  // S-G12 Cognitive Speech (AUD-10)
  String _selectedSpeechLang = 'en';

  // S-G13..G14 Mood PHQ-9 / GAD-7 + Crisis Override
  int _phq9Total = 6;
  int _gad7Total = 5;
  int _phq9Item9Score = 0; // Gate G-37: ANY > 0 immediately opens S-G14 Crisis!

  // S-G15 Heart-Failure Voice (AUD-12)
  int _hfEnrolledDays = 16; // Gate G-28: >= 14 days

  @override
  void initState() {
    super.initState();
    _activeScreenId = widget.initialScreenId;
    _voiceCoach = VoiceCoachController();
    _spectrumAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceForActiveScreen();
    });
  }

  @override
  void dispose() {
    _spectrumAnim.dispose();
    _voiceCoach.dispose();
    super.dispose();
  }

  void _announceForActiveScreen() {
    if (_roomNoiseDba > 45.0) {
      _voiceCoach.announce(
        'Background room noise is ${_roomNoiseDba.toStringAsFixed(0)} dBA, which is above the 45 dBA limit. Please move to a quieter room.',
        tone: VoiceCueTone.outOfFrame,
        force: true,
      );
      return;
    }
    switch (_activeScreenId) {
      case 'S-G01':
        _voiceCoach.announce(
          'Microphone sweep verified and room noise is quiet (${_roomNoiseDba.toStringAsFixed(0)} dBA). Select any acoustic test below.',
          tone: VoiceCueTone.ready,
          force: true,
        );
      case 'S-G03':
        _voiceCoach.announce(
          'Hold the phone 25 cm from your mouth and record 3 natural coughs for TB and airway triage.',
          tone: VoiceCueTone.scanning,
          force: true,
        );
      case 'S-G04':
        _voiceCoach.announce(
          'Take a deep breath and say "aaa" steadily for at least 3 seconds.',
          tone: VoiceCueTone.scanning,
          force: true,
        );
      case 'S-G05':
        _voiceCoach.announce(
          'Inhale deeply and blow out as hard and fast as you can at 30 cm from the microphone.',
          tone: VoiceCueTone.scanning,
          force: true,
        );
      default:
        _voiceCoach.announce(
          'Acoustic & neurological voice lab ready. Follow the prompts on screen.',
          tone: VoiceCueTone.ready,
          force: true,
        );
    }
  }

  static const Map<String, String> _screenTabs = {
    'S-G01': 'Mic & Noise Check',
    'S-G02': 'Resp Questions',
    'S-G03': 'Cough (TB/COPD)',
    'S-G04': 'Voice ("aaa")',
    'S-G05': 'Lung Exhale',
    'S-G06': 'Resp Results',
    'S-G12': 'Cognitive (50+)',
    'S-G13': 'Mood (PHQ-9)',
    'S-G14': 'Crisis Support',
    'S-G15': 'HF Voice (14d)',
  };

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTabs[_activeScreenId] ?? 'Acoustic & Voice Lab'),
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
          // Horizontal Sub-Modality Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _screenTabs.entries.map((e) {
                final selected = e.key == _activeScreenId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _activeScreenId = e.key);
                      _announceForActiveScreen();
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
                _buildLiveAudioSpectrumCard(),
                const SizedBox(height: 14),
                _buildActiveAudioBody(context, appState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Animated 24-Bar Acoustic Spectrum & Ambient Room Noise Meter
  Widget _buildLiveAudioSpectrumCard() {
    final noisePass = _roomNoiseDba <= 45.0;
    final barColor = noisePass
        ? const Color(0xFF00E5CC)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1526),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: barColor.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded, color: barColor, size: 17),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '16–48 kHz PCM SPECTRUM',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Noise: ${_roomNoiseDba.toStringAsFixed(0)} dBA (${noisePass ? "PASS" : "LOUD!"})',
                  style: TextStyle(
                    color: barColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: AnimatedBuilder(
              animation: _spectrumAnim,
              builder: (context, _) {
                final v = _spectrumAnim.value;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(24, (i) {
                    final wave =
                        ((i % 5) + 1) * 5.0 +
                        (i.isEven ? v * 18.0 : (1 - v) * 16.0);
                    return Container(
                      width: 6,
                      height: wave.clamp(6.0, 44.0),
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Spec output markers (Doc 09 §8) for the active suite, fed from the demo
  /// state; anything the demo does not measure is listed as not available.
  List<ReadingGroup> _outputsForActiveScreen() {
    switch (_activeScreenId) {
      case 'S-G02':
      case 'S-G03':
      case 'S-G04':
      case 'S-G05':
      case 'S-G06':
        return MarkerReadings.fromValues(
          {
            'COUGH_COUNT_VALID': _validCoughsCount,
            'TB_PROB': _simulateTbHigh ? 0.82 : 0.11,
            'TB_BAND': _simulateTbHigh ? 'high' : 'low',
            'MPT_S': _sustainedVowelSec,
          },
          const [
            'ALG-AUD-01',
            'ALG-AUD-03',
            'ALG-AUD-04',
            'ALG-AUD-05',
            'ALG-AUD-06',
          ],
          bands: {
            'COUGH_COUNT_VALID': _validCoughsCount >= 3
                ? SemanticBand.normal
                : SemanticBand.notAssessed,
            'TB_PROB': _simulateTbHigh ? SemanticBand.high : SemanticBand.low,
            'TB_BAND': _simulateTbHigh ? SemanticBand.high : SemanticBand.low,
            'MPT_S': _sustainedVowelSec >= 3.0
                ? SemanticBand.normal
                : SemanticBand.borderline,
          },
        );
      case 'S-G12':
        return MarkerReadings.fromValues(
          const {},
          const ['ALG-AUD-10'],
          missingReason:
              'Demo composite only — ASR fluency model not shipped (G-24)',
        );
      case 'S-G13':
        return MarkerReadings.fromValues(
          {'PHQ9': _phq9Total, 'GAD7': _gad7Total},
          const ['ALG-AUD-11'],
          bands: {
            'PHQ9': _phq9Total >= 10
                ? SemanticBand.high
                : _phq9Total >= 5
                ? SemanticBand.borderline
                : SemanticBand.normal,
            'GAD7': _gad7Total >= 10
                ? SemanticBand.high
                : _gad7Total >= 5
                ? SemanticBand.borderline
                : SemanticBand.normal,
          },
          missingReason: 'Conditional on release gate G-24',
        );
      case 'S-G15':
        final ready = _hfEnrolledDays >= 14;
        return MarkerReadings.fromValues(
          {if (ready) 'HF_ALERT': false},
          const ['ALG-AUD-12'],
          missingReason: ready
              ? 'Not measured in this demo'
              : 'Building personal voice baseline (Day $_hfEnrolledDays of 14)',
        );
      default:
        return const [];
    }
  }

  Widget _buildActiveAudioBody(BuildContext context, AppState appState) {
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
              'Spec §8 output markers for this suite · values from the demo controls',
        ),
      ],
    );
  }

  Widget _suiteBody(BuildContext context, AppState appState) {
    switch (_activeScreenId) {
      case 'S-G01':
        return _buildG01AudioReadiness();
      case 'S-G02':
      case 'S-G03':
      case 'S-G04':
      case 'S-G05':
      case 'S-G06':
        return _buildG02ToG06RespiratorySuite(context, appState);
      case 'S-G12':
        return _buildG12CognitiveSpeech(context, appState);
      case 'S-G13':
        return _buildG13MoodScreen(context, appState);
      case 'S-G14':
        return _buildG14CrisisSupport(context);
      case 'S-G15':
        return _buildG15HeartFailureVoice(context, appState);
      default:
        return _buildG01AudioReadiness();
    }
  }

  Widget _buildG01AudioReadiness() {
    final noisePass = _roomNoiseDba <= 45.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Microphone Calibration & Ambient Room Noise Gate',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Mic 200–8000 Hz Sweep Deviation: ±${_micSweepDevDb.toStringAsFixed(1)} dB (Pass <= 6.0 dB)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Ambient Room Noise: ${_roomNoiseDba.toStringAsFixed(1)} dBA (Pass <= 45 dBA · Hearing <= 40 dBA)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Slider(
              value: _roomNoiseDba,
              min: 25.0,
              max: 65.0,
              onChanged: (v) {
                setState(() => _roomNoiseDba = v);
                _announceForActiveScreen();
              },
            ),
            BandChip(
              band: noisePass ? SemanticBand.normal : SemanticBand.notAssessed,
              customLabel: noisePass
                  ? 'Room Quiet Enough for All Acoustic Screens'
                  : 'Too Noisy (> 45 dBA) — Voice Coach Paused Recording',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildG02ToG06RespiratorySuite(
    BuildContext context,
    AppState appState,
  ) {
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
                  'Cough (TB/COPD), Voice ("aaa") & Forced Exhale Spirometry',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  'Valid Coughs Detected: $_validCoughsCount (Minimum >= 3)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _validCoughsCount.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (v) =>
                      setState(() => _validCoughsCount = v.round()),
                ),
                Text(
                  'Sustained Vowel "aaa": ${_sustainedVowelSec.toStringAsFixed(1)} s (Minimum >= 3.0 s)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _sustainedVowelSec,
                  min: 1.5,
                  max: 6.0,
                  onChanged: (v) => setState(() => _sustainedVowelSec = v),
                ),
                Text(
                  'Forced Exhale Blows at 30 cm (10% repeatability): $_forcedBlowsRepeatable / 3',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                SwitchListTile(
                  title: const Text(
                    'Simulate High TB Risk on Cough Triage -> Urgent (Rule BR-SCR-02 / T15)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  value: _simulateTbHigh,
                  onChanged: (v) => setState(() => _simulateTbHigh = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Respiratory & Voice Screening Report',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const BandChip(
                      band: SemanticBand.normal,
                      customLabel: 'Cough Type: Dry (89%)',
                    ),
                    BandChip(
                      band: _simulateTbHigh
                          ? SemanticBand.high
                          : SemanticBand.low,
                      customLabel: _simulateTbHigh
                          ? 'TB Triage: High (Urgent)'
                          : 'TB Triage: Low Risk',
                    ),
                    const BandChip(
                      band: SemanticBand.normal,
                      customLabel: 'FEV1/FVC (Est): 0.81 (94% GLI-2012)',
                    ),
                    const BandChip(
                      band: SemanticBand.normal,
                      customLabel: 'Voice Jitter 0.42% · HNR 22.8 dB',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Save Respiratory & Voice Session'),
                  onPressed: () {
                    final rec = ScreeningSessionRecord(
                      sessionId: 'aud_${DateTime.now().millisecondsSinceEpoch}',
                      subjectId: appState.activeSubject.id,
                      featureId: 'F-20',
                      screenId: 'S-G06',
                      title: 'Respiratory, Cough TB & Spirometry',
                      category: 'Breathing & Voice',
                      recordedAt: DateTime.now(),
                      primaryBand: _simulateTbHigh
                          ? SemanticBand.high
                          : SemanticBand.low,
                      urgency: _simulateTbHigh
                          ? UrgencyLevel.urgent
                          : UrgencyLevel.none,
                      confidence: 0.89,
                      summaryText: _simulateTbHigh
                          ? 'High TB triage risk on cough acoustics — Urgent GeneXpert & Chest X-ray recommended.'
                          : 'Cough, voice acoustics, and forced exhale lung function within normal bands.',
                      markers: const [],
                      firedRules: _simulateTbHigh
                          ? const ['BR-SCR-02']
                          : const [],
                    );
                    appState.addScreeningRecord(
                      rec,
                      conditionCode: _simulateTbHigh ? 'COND_TB' : null,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Saved Respiratory Session to History & Cases.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildG12CognitiveSpeech(BuildContext context, AppState appState) {
    final subj = appState.activeSubject;
    final ageEligible = subj.ageYears >= 50;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cognitive Speech Screen (ALG-AUD-10 · Age >= 50)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (!ageEligible)
              const Text(
                'Active subject is under 50 years old. Switch to "Ramesh (62y Senior)" in the top AppBar to unlock Age >= 50 eligibility.',
                style: TextStyle(
                  color: MirrorColors.warningFg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'te', label: Text('Telugu (te)')),
                ButtonSegment(value: 'hi', label: Text('Hindi (hi)')),
              ],
              selected: {_selectedSpeechLang},
              onSelectionChanged: (s) =>
                  setState(() => _selectedSpeechLang = s.first),
            ),
            const SizedBox(height: 12),
            const BandChip(
              band: SemanticBand.rangeNotAvailable,
              customLabel:
                  'Cognitive Composite: 84/100 (Reference range not yet available)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildG13MoodScreen(BuildContext context, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emotional Wellbeing (PHQ-9 & GAD-7) + Safety Override (ALG-AUD-11)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text('PHQ-9 Total Score: $_phq9Total / 27'),
            Slider(
              value: _phq9Total.toDouble(),
              min: 0,
              max: 27,
              divisions: 27,
              onChanged: (v) => setState(() => _phq9Total = v.round()),
            ),
            Text('GAD-7 Total Score: $_gad7Total / 21'),
            Slider(
              value: _gad7Total.toDouble(),
              min: 0,
              max: 21,
              divisions: 21,
              onChanged: (v) => setState(() => _gad7Total = v.round()),
            ),
            const Divider(),
            const Text(
              'PHQ-9 Item 9 (Thoughts of self-harm): Any non-zero response immediately triggers S-G14 Crisis Support (Gate G-37):',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: MirrorColors.dangerFg,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in const [
                  (0, '0 (Not at all)'),
                  (1, '1 (Several days)'),
                  (2, '2 (> Half days)'),
                  (3, '3 (Nearly every day)'),
                ])
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: _phq9Item9Score == item.$1,
                    onSelected: (_) {
                      setState(() {
                        _phq9Item9Score = item.$1;
                        if (item.$1 > 0) {
                          _activeScreenId = 'S-G14';
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildG14CrisisSupport(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MirrorColors.dangerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MirrorColors.dangerFg, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: MirrorColors.dangerFg,
                size: 30,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Immediate Crisis & Helpline Support (S-G14)',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: MirrorColors.dangerFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'You are not alone. Free, confidential 24/7 crisis support is available right now:\n'
            '• Tele-MANAS (India National Mental Health Helpline): 14416 or 1800-891-4416\n'
            '• Emergency Medical Services: 108 / 112',
            style: TextStyle(fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: MirrorColors.dangerFg,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call Tele-MANAS (14416)'),
                onPressed: () {},
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _phq9Item9Score = 0;
                    _activeScreenId = 'S-G13';
                  });
                },
                child: const Text('Return to Assessment'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildG15HeartFailureVoice(BuildContext context, AppState appState) {
    final hasBaseline = _hfEnrolledDays >= 14;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Heart-Failure Daily Voice Wetness Monitor (ALG-AUD-12)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Personal Voice Baseline Days Completed: $_hfEnrolledDays / 14 days (Gate G-28)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Slider(
              value: _hfEnrolledDays.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              onChanged: (v) => setState(() => _hfEnrolledDays = v.round()),
            ),
            BandChip(
              band: hasBaseline
                  ? SemanticBand.normal
                  : SemanticBand.notAssessed,
              customLabel: hasBaseline
                  ? 'Wetness Shift vs 14-Day Personal Baseline: +0.3 SD (Stable)'
                  : 'Calibrating Personal Baseline (${14 - _hfEnrolledDays} days remaining)',
            ),
          ],
        ),
      ),
    );
  }
}
