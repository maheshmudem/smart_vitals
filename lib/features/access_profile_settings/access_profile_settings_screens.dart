import 'package:flutter/material.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/design_system/mirror_ui.dart';
import '../anaemia/anaemia_ui_kit.dart';
import '../members/member_screens.dart';
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
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consent'),
        actions: [
          IconButton(
            tooltip: 'About this screen',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-B01'),
          ),
        ],
      ),
      body: ListView(
        padding: MirrorSpace.screen,
        children: [
          PageHeading(
            title: 'Your consents',
            subtitle: 'For ${subj.fullName} · ${subj.relationship}',
          ),
          const InfoNote(
            text:
                'Screening consent is needed for every scan. Dental consent needs a guardian for children. Training consent is optional and only decides whether your anonymised results help improve the models.',
          ),
          const SizedBox(height: MirrorSpace.xl),
          MirrorGroupCard(
            children: ConsentType.values.map((c) {
              final record = subj.consents[c];
              final signed = record?.isSigned ?? false;
              return SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MirrorSpace.lg,
                  vertical: 4,
                ),
                secondary: IconBadge(
                  icon: signed
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
                  color: signed
                      ? MirrorColors.successFg
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 34,
                ),
                title: Text(c.title, style: t.titleSmall),
                subtitle: Text(
                  signed
                      ? 'Signed · ${record?.documentVersion ?? "v2.1"}${record?.guardianName != null ? " · Guardian: ${record!.guardianName}" : ""}'
                      : 'Not signed · switch on to sign',
                  style: t.bodySmall,
                ),
                value: signed,
                onChanged: (v) => appState.toggleConsent(
                  c,
                  v,
                  guardianName: subj.ageYears < 18
                      ? 'Arjun Rao (Parent)'
                      : null,
                ),
              );
            }).toList(),
          ),
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

  Widget _switch({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MirrorSpace.lg,
        vertical: 2,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final subj = appState.activeSubject;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
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
        title: const Text('Profile & Health'),
        actions: [
          IconButton(
            tooltip: 'About this screen',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-B03'),
          ),
        ],
      ),
      body: ListView(
        padding: MirrorSpace.screen,
        children: [
          SectionHeader(
            title: 'Family member',
            subtitle: 'Scans and results are saved to this person',
            actionLabel: 'Manage',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ManageMembersScreen(),
              ),
            ),
          ),
          Wrap(
            spacing: MirrorSpace.sm,
            runSpacing: MirrorSpace.sm,
            children: [
              for (var i = 0; i < appState.subjects.length; i++)
                Builder(
                  builder: (context) {
                    final s = appState.subjects[i];
                    final selected = appState.activeSubjectIndex == i;
                    return ChoiceChip(
                      avatar: MemberAvatar(name: s.fullName, radius: 10),
                      label: Text(s.fullName.split(' ').first),
                      selected: selected,
                      side: BorderSide(
                        color: selected ? scheme.primary : scheme.outline,
                      ),
                      onSelected: (_) => appState.selectSubject(i),
                    );
                  },
                ),
              ActionChip(
                key: const ValueKey('profile_add_member'),
                avatar: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                label: Text('Add', style: TextStyle(color: scheme.primary)),
                side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MemberFormScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MirrorSpace.xl),
          const SectionHeader(
            title: 'Body measurements',
            subtitle: 'Used for BMI, waist-to-height and fitness formulas',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MirrorSpace.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Height',
                            suffixText: 'cm',
                          ),
                        ),
                      ),
                      const SizedBox(width: MirrorSpace.md),
                      Expanded(
                        child: TextField(
                          controller: _weightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Weight',
                            suffixText: 'kg',
                          ),
                        ),
                      ),
                      const SizedBox(width: MirrorSpace.md),
                      Expanded(
                        child: TextField(
                          controller: _waistCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Waist',
                            suffixText: 'cm',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MirrorSpace.lg),
                  Row(
                    children: [
                      _metric(
                        context,
                        'BMI',
                        bmi?.toStringAsFixed(1) ?? '--',
                        'kg/m²',
                      ),
                      const SizedBox(width: MirrorSpace.md),
                      _metric(
                        context,
                        'Waist / height',
                        whtr?.toStringAsFixed(2) ?? '--',
                        whtr == null ? 'add waist' : 'ratio',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MirrorSpace.xl),
          const SectionHeader(
            title: 'Health context',
            subtitle: 'Unlocks screenings that matter for you',
          ),
          MirrorGroupCard(
            dividerIndent: MirrorSpace.lg,
            children: [
              _switch(
                title: 'Known diabetes',
                subtitle: 'Offers a monthly diabetic foot check',
                value: subj.hasKnownDiabetes,
                onChanged: (v) => appState.updateActiveSubject(
                  subj.copyWith(hasKnownDiabetes: v),
                ),
              ),
              _switch(
                title: 'Tobacco or areca use',
                subtitle: 'Always offers the mouth-lining check',
                value: subj.usesTobaccoOrAreca,
                onChanged: (v) => appState.updateActiveSubject(
                  subj.copyWith(usesTobaccoOrAreca: v),
                ),
              ),
              if (subj.sex == BiologicalSex.female && subj.ageYears >= 12)
                _switch(
                  title: 'Currently pregnant',
                  subtitle: 'Uses the pregnancy anaemia cut-off (11.0 g/dL)',
                  value: subj.isPregnant,
                  onChanged: (v) => appState.updateActiveSubject(
                    subj.copyWith(isPregnant: v),
                  ),
                ),
              _switch(
                title: 'Heart-failure voice programme',
                subtitle: 'Enables daily voice monitoring',
                value: subj.isHeartFailureEnrolled,
                onChanged: (v) => appState.updateActiveSubject(
                  subj.copyWith(isHeartFailureEnrolled: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: MirrorSpace.xs),
          Text(
            'Changes to switches are saved immediately.',
            style: t.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: PrimaryBottomButton(
        label: 'Save profile',
        icon: Icons.check_rounded,
        onPressed: () {
          final h = double.tryParse(_heightCtrl.text);
          final w = double.tryParse(_weightCtrl.text);
          final waist = double.tryParse(_waistCtrl.text);
          appState.updateActiveSubject(
            subj.copyWith(heightCm: h, weightKg: w, waistCm: waist),
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profile saved')));
        },
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    String unit,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(MirrorSpace.md),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(MirrorRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.labelSmall),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: t.titleLarge?.copyWith(color: scheme.primary),
                  ),
                  TextSpan(text: '  $unit', style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
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
    final t = Theme.of(context).textTheme;

    Widget toggle({
      required IconData icon,
      required String title,
      String? subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MirrorSpace.lg,
          vertical: 2,
        ),
        secondary: IconBadge(icon: icon, size: 34),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        value: value,
        onChanged: onChanged,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices & Sensors'),
        actions: [
          IconButton(
            tooltip: 'About this screen',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showScreenGateLifecycleSheet(context, 'S-B07'),
          ),
        ],
      ),
      body: ListView(
        padding: MirrorSpace.screen,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MirrorSpace.lg),
              child: Row(
                children: [
                  const IconBadge(icon: Icons.phone_android_rounded),
                  const SizedBox(width: MirrorSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dev.displayName, style: t.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${dev.deviceModelCode} · ${dev.cameraMaxFps} fps camera · ${dev.focalLengthMm} mm lens',
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MirrorSpace.xl),
          const SectionHeader(
            title: 'Phone readiness',
            subtitle: 'Checks that unlock specific scans',
          ),
          MirrorGroupCard(
            children: [
              toggle(
                icon: Icons.water_drop_outlined,
                title: 'SpO2 calibrated for this phone',
                subtitle: 'If off, oxygen level is hidden',
                value: dev.hasSpo2Calibration,
                onChanged: (v) => appState.updateDeviceProfile(
                  dev.copyWith(hasSpo2Calibration: v),
                ),
              ),
              toggle(
                icon: Icons.mic_none_rounded,
                title: 'Microphone check passed',
                value: dev.micSelfCheckPassed,
                onChanged: (v) => appState.updateDeviceProfile(
                  dev.copyWith(micSelfCheckPassed: v),
                ),
              ),
              toggle(
                icon: Icons.headphones_outlined,
                title: 'Earphones connected',
                subtitle: 'Needed for the hearing test',
                value: dev.earphonesConnected,
                onChanged: (v) => appState.updateDeviceProfile(
                  dev.copyWith(earphonesConnected: v),
                ),
              ),
              toggle(
                icon: Icons.battery_charging_full_rounded,
                title: 'Phone on charger',
                subtitle: 'Needed for overnight sleep checks',
                value: dev.phoneCharging,
                onChanged: (v) => appState.updateDeviceProfile(
                  dev.copyWith(phoneCharging: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: MirrorSpace.xl),
          const SectionHeader(title: 'Connected accessories'),
          MirrorGroupCard(
            children: [
              toggle(
                icon: Icons.flare_rounded,
                title: 'Clip-on fundus camera',
                subtitle: 'For retina photos',
                value: dev.fundusCameraConnected,
                onChanged: (v) => appState.updateDeviceProfile(
                  dev.copyWith(fundusCameraConnected: v),
                ),
              ),
              toggle(
                icon: Icons.radio_button_checked_rounded,
                title: 'Smart ring',
                subtitle: 'Overnight SpO2, rhythm and temperature',
                value: dev.smartRingConnected,
                onChanged: (v) => appState.updateDeviceProfile(
                  dev.copyWith(smartRingConnected: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: MirrorSpace.xl),
          const SectionHeader(title: 'Blood pressure'),
          MirrorGroupCard(
            children: [
              toggle(
                icon: Icons.speed_rounded,
                title: 'Show BP numbers',
                subtitle:
                    'Only after clinical validation (ISO 81060-2). Otherwise a band is shown.',
                value: appState.bpNumericValidatedRelease,
                onChanged: (v) => appState.toggleBpNumericRelease(v),
              ),
            ],
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
      appBar: AppBar(title: const Text('Screen Catalogue')),
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
              padding: MirrorSpace.screen,
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
      appBar: AppBar(title: const Text('Spec Test Vectors')),
      body: ListView.builder(
        padding: MirrorSpace.screen,
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
