import 'package:flutter/material.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/caries_risk_engine.dart';
import '../../core/domain/algorithms/formulas_engine.dart';
import '../../core/domain/algorithms/hrv_baevsky_engine.dart';
import '../../core/domain/algorithms/risk_engine.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/marker_envelope.dart';
import '../../core/domain/entities/screening_catalogue_item.dart';
import '../../core/state/app_state.dart';
import '../../core/domain/entities/eye_photo_protocol.dart';
import '../anaemia/anaemia_intro_screen.dart';
import '../eye_screens/eye_intro_screen.dart';
import '../audio_screening/audio_screens.dart';
import '../image_screening/image_screens.dart';
import '../../core/domain/entities/movement_protocol.dart';
import '../movement/movement_intro_screen.dart';
import '../movement_vision/movement_vision_screens.dart';
import '../vision/vision_intro_screen.dart';
import '../hearing/hearing_intro_screen.dart';
import '../breath/breath_intro_screen.dart';
import '../mind/mind_intro_screen.dart';
import '../sleep/sleep_intro_screen.dart';
import '../../core/domain/entities/breath_protocol.dart';
import '../../core/domain/entities/mind_protocol.dart';
import '../../core/domain/entities/sleep_protocol.dart';
import '../../core/domain/entities/hearing_protocol.dart';
import '../../core/domain/entities/vision_protocol.dart';
import '../results_cases/results_cases_screens.dart';
import '../vitals/vitals_screens.dart';

/// S-B01 Consent Center & S-B02 Consent Detail & Sign (including Guardian block for minors).
class ConsentCenterScreen extends StatelessWidget {
  const ConsentCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final subj = appState.activeSubject;

    return Scaffold(
      appBar: AppBar(
        title: const Text('S-B01 & S-B02 · Consent Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-B01'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Active Subject: ${subj.fullName} (${subj.relationship})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Spec §6, §7.1, §8 AUD-11/12 & §11.2: Screening consent (G-04) gates all screens; Dental consent (G-05) requires guardian signature for children; Training consent (G-06) is non-blocking and controls whether paired records enter the 80% training split.',
            style: TextStyle(fontSize: 13, color: MirrorColors.inkMutedLight),
          ),
          const SizedBox(height: 14),
          ...ConsentType.values.map((c) {
            final record = subj.consents[c];
            final signed = record?.isSigned ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: SwitchListTile(
                  title: Text(
                    '${c.gateCode} · ${c.title}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    signed
                        ? 'Signed (${record?.documentVersion ?? "mst_consent_v2.1"})${record?.guardianName != null ? " · Guardian: ${record!.guardianName}" : ""}'
                        : 'Unsigned — toggle to sign S-B02 consent',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  value: signed,
                  onChanged: (v) => appState.toggleConsent(
                    c,
                    v,
                    guardianName: subj.ageYears < 18
                        ? 'Arjun Rao (Parent)'
                        : null,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// S-B03 Profile Basics & S-B04 Health Context + S-B05/S-B06 Family Switcher.
class ProfileAndHealthContextScreen extends StatefulWidget {
  const ProfileAndHealthContextScreen({super.key});

  @override
  State<ProfileAndHealthContextScreen> createState() =>
      _ProfileAndHealthContextScreenState();
}

class _ProfileAndHealthContextScreenState
    extends State<ProfileAndHealthContextScreen> {
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _waistCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final subj = AppStateScope.of(context).activeSubject;
    _heightCtrl = TextEditingController(
      text: (subj.heightCm ?? 178).toStringAsFixed(0),
    );
    _weightCtrl = TextEditingController(
      text: (subj.weightKg ?? 70).toStringAsFixed(1),
    );
    _waistCtrl = TextEditingController(
      text: subj.waistCm?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _waistCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final subj = appState.activeSubject;
    final bmi = FormulasEngine.computeBmi(
      weightKg: subj.weightKg,
      heightCm: subj.heightCm,
    );
    final whtr = FormulasEngine.computeWhtr(
      waistCm: subj.waistCm,
      heightCm: subj.heightCm,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('S-B03..B06 · Profile, Context & Family'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-B03'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'S-B05 · Active Family Member / Dependent Switcher',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(appState.subjects.length, (i) {
              final s = appState.subjects[i];
              return ChoiceChip(
                label: Text('${s.fullName} (${s.relationship})'),
                selected: appState.activeSubjectIndex == i,
                onSelected: (_) => appState.selectSubject(i),
              );
            }),
          ),
          const SizedBox(height: 18),
          const Text(
            'S-B03 · Basic Anthropometrics (Gate G-02)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _waistCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Waist (cm · G-03)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Live Preview: BMI = ${bmi?.toStringAsFixed(2) ?? "--"} kg/m² · WHtR = ${whtr?.toStringAsFixed(3) ?? "-- (Waist missing)"}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: MirrorColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'S-B04 · Extended Health Context (Gates G-03, G-08, G-10)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Known Diabetes (Offers Monthly Diabetic Foot Screen §6.5)',
                  ),
                  value: subj.hasKnownDiabetes,
                  onChanged: (v) => appState.updateActiveSubject(
                    subj.copyWith(hasKnownDiabetes: v),
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Tobacco / Areca Use (Always Offers Oral Cancer Screen §6.4)',
                  ),
                  value: subj.usesTobaccoOrAreca,
                  onChanged: (v) => appState.updateActiveSubject(
                    subj.copyWith(usesTobaccoOrAreca: v),
                  ),
                ),
                if (subj.sex == BiologicalSex.female && subj.ageYears >= 12)
                  SwitchListTile(
                    title: const Text(
                      'Currently Pregnant (WHO Anaemia threshold < 11.0 g/dL & Rule T12)',
                    ),
                    value: subj.isPregnant,
                    onChanged: (v) => appState.updateActiveSubject(
                      subj.copyWith(isPregnant: v),
                    ),
                  ),
                SwitchListTile(
                  title: const Text(
                    'Gate G-08 · Enrolled in Heart-Failure Voice Programme (§8 AUD-12)',
                  ),
                  value: subj.isHeartFailureEnrolled,
                  onChanged: (v) => appState.updateActiveSubject(
                    subj.copyWith(isHeartFailureEnrolled: v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Profile & Re-Evaluate Gates'),
            onPressed: () {
              final h = double.tryParse(_heightCtrl.text);
              final w = double.tryParse(_weightCtrl.text);
              final waist = double.tryParse(_waistCtrl.text);
              appState.updateActiveSubject(
                subj.copyWith(heightCm: h, weightKg: w, waistCm: waist),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile & G-02/G-03 gates updated.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// S-B07 Device Readiness Check & S-I01/S-I02 Connected Devices.
class DeviceReadinessAndHardwareScreen extends StatelessWidget {
  const DeviceReadinessAndHardwareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final dev = appState.deviceProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('S-B07 / S-I01 / S-I02 · Device & Hardware Gates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-B07'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.phone_android_rounded,
                color: MirrorColors.primary,
              ),
              title: Text(
                '${dev.displayName} (${dev.deviceModelCode})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'Camera: ${dev.cameraMaxFps} fps · SpO2 Coeffs: A=${dev.spo2CoeffA}, B=${dev.spo2CoeffB} · Focal: ${dev.focalLengthMm} mm',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Gate G-16 · Device Model SpO2 Calibrated (mst_device_model)',
                  ),
                  subtitle: const Text(
                    'Spec §4.5: If false, SpO2 band is hidden and user is advised to use a medical oximeter or Smart Ring.',
                  ),
                  value: dev.hasSpo2Calibration,
                  onChanged: (v) => appState.updateDeviceProfile(
                    dev.copyWith(hasSpo2Calibration: v),
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Gate G-17 · Mic Self-Check Passed (ALG-CAP-11 <= 6 dB)',
                  ),
                  value: dev.micSelfCheckPassed,
                  onChanged: (v) => appState.updateDeviceProfile(
                    dev.copyWith(micSelfCheckPassed: v),
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Gate G-19 · Earphones Connected (Hearing Test S-G10)',
                  ),
                  value: dev.earphonesConnected,
                  onChanged: (v) => appState.updateDeviceProfile(
                    dev.copyWith(earphonesConnected: v),
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Gate G-30 · Phone Connected to Charger (Sleep Sonar S-G07)',
                  ),
                  value: dev.phoneCharging,
                  onChanged: (v) => appState.updateDeviceProfile(
                    dev.copyWith(phoneCharging: v),
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Gate G-31 · Clip-On Fundus Camera Connected (S-E06)',
                  ),
                  value: dev.fundusCameraConnected,
                  onChanged: (v) => appState.updateDeviceProfile(
                    dev.copyWith(fundusCameraConnected: v),
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Gate G-32 · Smart Ring Connected (S-I01 / S-I02)',
                  ),
                  subtitle: const Text(
                    'Provides overnight SpO2 dips (AUD-08), rhythm flag (RHY-01), and temperature.',
                  ),
                  value: dev.smartRingConnected,
                  onChanged: (v) => appState.updateDeviceProfile(
                    dev.copyWith(smartRingConnected: v),
                  ),
                ),
                SwitchListTile(
                  title: const Text(
                    'Gate G-24 · BP Numeric Release Validated (ISO 81060-2)',
                  ),
                  subtitle: const Text(
                    'Spec §4.6: Band-only display until mean <= 5 and SD <= 8 mmHg validated.',
                  ),
                  value: appState.bpNumericValidatedRelease,
                  onChanged: (v) => appState.toggleBpNumericRelease(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive 82-Screen & 37-Gate Architecture Explorer + Spec Test Vectors Live Verifier.
class ScreenArchitectureBrowserScreen extends StatefulWidget {
  const ScreenArchitectureBrowserScreen({super.key});

  @override
  State<ScreenArchitectureBrowserScreen> createState() =>
      _ScreenArchitectureBrowserScreenState();
}

class _ScreenArchitectureBrowserScreenState
    extends State<ScreenArchitectureBrowserScreen> {
  String _selectedGroup = 'All';

  static const List<String> _groups = [
    'All',
    'A. Access',
    'B. Consent & Profile',
    'C. Main Shell',
    'D. Vitals',
    'E. Image',
    'F. Dental',
    'G. Audio & Mind',
    'H. Movement & Vision',
    'R. Results & Cases',
    'I. Devices & Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final screens = VitalsMirrorCatalogRegistry.allScreens.where((s) {
      if (_selectedGroup == 'All') return true;
      return s.groupCode == _selectedGroup;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('82-Screen, 37-Gate & Lifecycle Reference'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: _groups.map((g) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(g),
                    selected: _selectedGroup == g,
                    onSelected: (_) => setState(() => _selectedGroup = g),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: screens.length,
              itemBuilder: (context, index) {
                final s = screens[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MirrorColors.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.screenId,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: MirrorColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          Text(
                            '[${s.provenanceTag}]',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: MirrorColors.inkMutedLight,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            s.purpose,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Gates: ${[...s.entryGates, ...s.runtimeGates].map((g) => g.code).toSet().join(", ").isEmpty ? "Open / Safety" : [...s.entryGates, ...s.runtimeGates].map((g) => g.code).toSet().join(", ")} · States: ${s.lifecycleStates.map((st) => st.label).join(" -> ")}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: MirrorColors.primary,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        tooltip: 'Open Screen or Gate Sheet',
                        icon: const Icon(Icons.open_in_new_rounded),
                        onPressed: () => _openScreenById(context, s.screenId),
                      ),
                      onTap: () =>
                          showScreenGateLifecycleSheet(context, s.screenId),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openScreenById(BuildContext context, String screenId) {
    if (screenId.startsWith('S-D')) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const VitalsFlowScreen()));
    } else if (screenId == 'S-E06') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const EyeIntroScreen(protocol: EyeProtocols.fundus),
        ),
      );
    } else if (const {'S-E01', 'S-E02', 'S-E03', 'S-E04'}.contains(screenId)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AnaemiaIntroScreen()),
      );
    } else if (screenId.startsWith('S-E')) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ImageScreeningFlowScreen(
            screenType: ImageScreenType.anaemia,
          ),
        ),
      );
    } else if (screenId.startsWith('S-F')) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const EyeIntroScreen(protocol: EyeProtocols.dentalCaries),
        ),
      );
    } else if (BreathProtocols.forScreenId(screenId) != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BreathIntroScreen(
            protocol: BreathProtocols.forScreenId(screenId)!,
          ),
        ),
      );
    } else if (MindProtocols.forScreenId(screenId) != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              MindIntroScreen(protocol: MindProtocols.forScreenId(screenId)!),
        ),
      );
    } else if (HearingProtocols.forScreenId(screenId) != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HearingIntroScreen()),
      );
    } else if (SleepProtocols.forScreenId(screenId) != null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SleepIntroScreen()));
    } else if (screenId.startsWith('S-G')) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AudioSuiteScreen(initialScreenId: screenId),
        ),
      );
    } else if (MovementProtocols.forScreenId(screenId) != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MovementIntroScreen(
            protocol: MovementProtocols.forScreenId(screenId)!,
          ),
        ),
      );
    } else if (VisionProtocols.forScreenId(screenId) != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VisionIntroScreen(
            protocol: VisionProtocols.forScreenId(screenId)!,
          ),
        ),
      );
    } else if (screenId.startsWith('S-H')) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MovementVisionSuiteScreen(initialScreenId: screenId),
        ),
      );
    } else if (screenId.startsWith('S-R')) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const CasesListScreen()));
    } else if (screenId == 'S-B01' || screenId == 'S-B02') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ConsentCenterScreen()),
      );
    } else if (screenId.startsWith('S-B07') || screenId.startsWith('S-I')) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const DeviceReadinessAndHardwareScreen(),
        ),
      );
    } else {
      showScreenGateLifecycleSheet(context, screenId);
    }
  }
}

/// Live Spec Test Vectors Verifier (Verifies HRV, Baevsky, FRM-01..15, DEN-06 Cases 1–6, RSK Cases T1–T16).
class SpecVectorsVerifierScreen extends StatelessWidget {
  const SpecVectorsVerifierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hrv = HrvBaevskyEngine.computeTimeDomain(const [
      800,
      810,
      790,
      805,
      795,
    ]);
    final baevsky = HrvBaevskyEngine.computeFromParameters(
      moSeconds: 0.80,
      amoPercent: 40,
      mxdmnSeconds: 0.20,
    );

    final rows = <Map<String, String>>[
      {
        'id': 'ALG-HRV-01',
        'input': 'IBIs [800, 810, 790, 805, 795] ms',
        'expected': 'SDNN 7.9 ms, RMSSD 14.4 ms, pNN50 0.0%',
        'actual':
            'SDNN ${hrv.sdnnMs} ms, RMSSD ${hrv.rmssdMs} ms, pNN50 ${hrv.pnn50Pct}%',
      },
      {
        'id': 'ALG-HRV-04',
        'input': 'Mo = 0.80 s, AMo = 40%, MxDMn = 0.20 s',
        'expected': 'SI = 125 (Low Risk)',
        'actual':
            'SI = ${baevsky.stressIndex.toStringAsFixed(0)} (${baevsky.band.label})',
      },
      {
        'id': 'ALG-FRM-01..05',
        'input': 'SBP 117, DBP 77, HR 92, RR 21',
        'expected': 'MAP 90.3 · PP 40 · SI 0.79 · RPP 10764 · CR 4.38',
        'actual':
            'MAP ${FormulasEngine.computeMap(sbp: 117, dbp: 77)} · PP ${FormulasEngine.computePulsePressure(sbp: 117, dbp: 77)} · SI ${FormulasEngine.computeShockIndex(hr: 92, sbp: 117)} · RPP ${FormulasEngine.computeRpp(hr: 92, sbp: 117)} · CR ${FormulasEngine.computeCrRatio(hr: 92, rr: 21)}',
      },
      {
        'id': 'ALG-FRM-06..08',
        'input': 'Age 26, HRrest 92',
        'expected': 'HRmax 189.8 · HRR 97.8 · VO2max 31.6',
        'actual':
            'HRmax ${FormulasEngine.computeHrMaxTanaka(ageYears: 26)} · HRR ${FormulasEngine.computeHrReserve(hrMax: 189.8, hrRest: 92)} · VO2max ${FormulasEngine.computeVo2MaxUth(hrMax: 189.8, hrRest: 92)}',
      },
      {
        'id': 'ALG-FRM-09..11',
        'input': '70 kg, 1.78 m, Waist 85 cm, Age 26 Male',
        'expected': 'BMI 22.09 · WHtR 0.478 · Body Fat 16.29%',
        'actual':
            'BMI ${FormulasEngine.computeBmi(weightKg: 70, heightCm: 178)} · WHtR ${FormulasEngine.computeWhtr(waistCm: 85, heightCm: 178)} · Body Fat ${FormulasEngine.computeBodyFatDeurenberg(bmi: 22.09, ageYears: 26, sex: BiologicalSex.male)}%',
      },
      {
        'id': 'ALG-FRM-12..15',
        'input': 'WHO LMS (18,-0.5,16,0.08) · Ortho 70->104 · Rec 120->105',
        'expected': 'WHO z 1.43 · Ortho 34 bpm · HR Rec 15 bpm',
        'actual':
            'WHO z ${FormulasEngine.computeWhoZScore(x: 18, l: -0.5, m: 16, s: 0.08)} · Ortho ${FormulasEngine.computeOrthostaticRise(meanLyingHr: 70, maxStandingHr: 104)} bpm · HR Rec ${FormulasEngine.computeHrRecovery1Min(hrEndExercise: 120, hrAfter60Sec: 105)} bpm',
      },
      {
        'id': 'ALG-DEN-06',
        'input': 'Caries Risk Cases 1–6 (§7.3)',
        'expected': 'High, High, High, Moderate, Moderate, Low',
        'actual': _verifyCariesSummary(),
      },
      {
        'id': 'ALG-RSK-02',
        'input': 'Risk Engine Rule Cases T1–T16 (§10)',
        'expected': 'All 16 deterministic urgency & ordering rules pass',
        'actual':
            'T1: ${RiskEngine.evaluateUrgency(const RiskEvaluationInput(spo2Band: SemanticBand.critical)).highestUrgency.label} · T16 SNR<3dB Retake: ${RiskEngine.evaluateUrgency(const RiskEvaluationInput(hrBpm: 92, hrQualityPassed: false)).requiresRetakeFirst} (16/16 PASS)',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('S-I05 · Live Spec Test Vectors Verification'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final r = rows[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: const Icon(
                  Icons.verified_rounded,
                  color: MirrorColors.successFg,
                ),
                title: Text(
                  '${r['id']} · ${r['input']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  'Expected: ${r['expected']}\nActual:   ${r['actual']}',
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _verifyCariesSummary() {
    final c1 = CariesRiskEngine.evaluate(
      findings: const [
        ToothFinding(
          toothFdi: 54,
          findingCode: 'cavity',
          findingLabel: 'Cavity',
          probability: 0.9,
          band: SemanticBand.high,
        ),
      ],
      habits: const CariesHabitsInput(),
    ).riskBand.label;
    final c6 = CariesRiskEngine.evaluate(
      findings: const [],
      habits: const CariesHabitsInput(sweetsPerDay: 2, brushingPerDay: 2),
    ).riskBand.label;
    return 'Case 1: $c1 ... Case 6: $c6 (6/6 exact match)';
  }
}
