import 'package:flutter/material.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/domain/algorithms/risk_engine.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/health_package.dart';
import '../../core/domain/entities/screening_catalogue_item.dart';
import '../../core/domain/gates/gate_evaluator.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../access_profile_settings/access_profile_settings_screens.dart';
import '../anaemia/anaemia_intro_screen.dart';
import '../../core/domain/entities/eye_photo_protocol.dart';
import '../eye_screens/eye_intro_screen.dart';
import '../audio_screening/audio_screens.dart';
import '../dental/dental_screens.dart';
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

/// Flagship 5-Tab Application Shell:
/// - Tab 0: Home (S-C01) — Biometric Mirror Hero, Quick Individual Scans Strip, Featured Health Packages, Latest Vitals & Alerts
/// - Tab 1: Health Packs — All 8 Curated Bundled Multi-Scan Packages with Guided Step-by-Step Runner
/// - Tab 2: Screenings (S-C02) — All 34 Separate Individual Screenings with Permission Badges & Pre-Scan Readiness Check
/// - Tab 3: History & Trends (S-C03/C05) — Personal Baselines & Past Sessions
/// - Tab 4: More & 82 Screens (S-C07) — Profiles, Permissions, Hardware, Consents & 82-Screen Spec Browser
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _tabIndex = 0;
  String _selectedCatalogueCategory = 'All';

  static const List<String> _tabScreenIds = [
    'S-C01',
    'S-C02',
    'S-C02',
    'S-C03',
    'S-C07',
  ];

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final subj = appState.activeSubject;
    final currentScreenId = _tabScreenIds[_tabIndex];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B7A75), Color(0xFF00E5CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.monitor_heart_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'VitalsMirror',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        actions: [
          // Active Subject Switcher Pill (Self / Child 7y / Newborn 72h / Senior 62y)
          PopupMenuButton<int>(
            tooltip:
                'Switch Active Family Member (Updates Age & Eligibility Gates)',
            onSelected: (index) => appState.selectSubject(index),
            itemBuilder: (ctx) => List.generate(appState.subjects.length, (i) {
              final s = appState.subjects[i];
              return PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Icon(
                      i == appState.activeSubjectIndex
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 18,
                      color: MirrorColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.fullName} · ${s.relationship}',
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              );
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.person_outline_rounded, size: 15),
                label: Text(
                  subj.fullName.split(' ').first,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip:
                'Inspect Screen Purpose, Gates & Lifecycle ($currentScreenId)',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () =>
                showScreenGateLifecycleSheet(context, currentScreenId),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildHomeTab(context, appState),
          _buildHealthPackagesTab(context, appState),
          _buildIndividualScreeningsTab(context, appState),
          _buildHistoryAndTrendsTab(context, appState),
          _buildMoreAndArchitectureTab(context, appState),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home (S-C01)',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Health Packs',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Screenings (S-C02)',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline_rounded),
            label: 'History & Trends',
          ),
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            selectedIcon: Icon(Icons.layers_rounded),
            label: 'More & 82 Screens',
          ),
        ],
      ),
    );
  }

  /// Tab 0: Flagship Home Dashboard (S-C01)
  Widget _buildHomeTab(BuildContext context, AppState appState) {
    final subj = appState.activeSubject;
    final latestVitals = appState.vitalsSessions.firstOrNull;
    final topCase = appState.cases.firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // 1. Flagship Hero: Contactless & Optical Biometric Mirror
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF092032), Color(0xFF0B7A75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B7A75).withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5CC).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF00E5CC).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.record_voice_over_rounded,
                          size: 13,
                          color: Color(0xFF00E5CC),
                        ),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'VOICE-COACHED AI HEALTH MIRROR',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF00E5CC),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${subj.fullName.split(" ").first} · ${subj.isNewborn ? "${subj.ageHoursForNewborn}h" : "${subj.ageYears}y"}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Contactless & Finger Vitals Scan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Live camera face tracking with real spoken voice guidance. Automatically verifies lighting, pauses if your face leaves the frame, and completes a 1-minute reading.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5CC),
                        foregroundColor: const Color(0xFF052925),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(
                        Icons.face_retouching_natural_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Face Scan (60s)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      onPressed: () => _launchWithPermissionModal(
                        context,
                        scanTitle: '1-Minute Face rPPG Vitals Scan',
                        scanDuration: '60 Seconds',
                        permissions: HealthPackagesRegistry.facePermissions,
                        preparationTips:
                            HealthPackagesRegistry.preparationTipsForTargetScreen(
                              'S-D02',
                            ),
                        builder: (_) => const VitalsFlowScreen(
                          initialMode: VitalsCaptureMode.face,
                          autoStartScanner: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded, size: 18),
                      label: const Text(
                        'Finger SpO2',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      onPressed: () => _launchWithPermissionModal(
                        context,
                        scanTitle: 'Finger PPG & SpO2 Scan',
                        scanDuration: '30–60 Seconds',
                        permissions: HealthPackagesRegistry.fingerPermissions,
                        preparationTips:
                            HealthPackagesRegistry.preparationTipsForTargetScreen(
                              'S-D04',
                            ),
                        builder: (_) => const VitalsFlowScreen(
                          initialMode: VitalsCaptureMode.finger,
                          autoStartScanner: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Separate Individual Scans Quick-Launch Grid
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Separate Individual Scans',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    'Tap any single reading to open camera & voice coach',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: MirrorColors.inkMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _tabIndex = 2),
              icon: const Icon(Icons.apps_rounded, size: 15),
              label: const Text('All 34'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildQuickSeparateScansGrid(context, appState),
        const SizedBox(height: 20),

        // 3. Curated Health Check Packages (Bundled Scans)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Curated Health Check Packages',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    'Guided multi-scan bundles for complete body checks',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: MirrorColors.inkMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _tabIndex = 1),
              icon: const Icon(Icons.inventory_2_outlined, size: 15),
              label: const Text('All 8 Packs'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: HealthPackagesRegistry.packages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final pkg = HealthPackagesRegistry.packages[index];
              return _buildHorizontalPackageCard(context, appState, pkg);
            },
          ),
        ),
        const SizedBox(height: 20),

        // 4. Active Clinical Cases & Confirmatory Lab Follow-Ups
        if (topCase != null) ...[
          UrgencyBanner(
            urgency: topCase.highestUrgency,
            title: 'Open Case: ${topCase.conditionTitle}',
            subtitle:
                'Confirmatory tests: ${topCase.confirmatorySpec.investigations}',
            primaryActionLabel: 'Open Case',
            onPrimaryAction: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CasesListScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
        ],

        // 5. Latest Vitals Snapshot (Fixed-Extent Grid — Zero Overflows on 360px+)
        if (latestVitals != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Latest Vitals Snapshot',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          VitalsResultsSummaryScreen(session: latestVitals),
                    ),
                  );
                },
                child: const Text('Full Report ->'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 118,
            ),
            children: [
              if (latestVitals.markers['HR'] != null)
                MetricTile(marker: latestVitals.markers['HR']!),
              if (latestVitals.markers['RR'] != null)
                MetricTile(marker: latestVitals.markers['RR']!),
              if (latestVitals.markers['BAEVSKY_SI'] != null)
                MetricTile(marker: latestVitals.markers['BAEVSKY_SI']!),
              if (latestVitals.markers['MAP'] != null)
                MetricTile(marker: latestVitals.markers['MAP']!),
            ],
          ),
        ],
      ],
    );
  }

  /// Quick 8-Tile Grid of Separate Individual Scans on the Home Dashboard (Fixed 106px height — Zero Overflow)
  Widget _buildQuickSeparateScansGrid(BuildContext context, AppState appState) {
    final quickItems =
        <
          ({
            String title,
            String sub,
            IconData icon,
            Color color,
            String catalogId,
          })
        >[
          (
            title: 'Face Vitals',
            sub: '60s · Front Cam',
            icon: Icons.face_retouching_natural_rounded,
            color: const Color(0xFF0B7A75),
            catalogId: 'cat_vitals_face',
          ),
          (
            title: 'Finger SpO2',
            sub: '30s · Rear+Torch',
            icon: Icons.fingerprint_rounded,
            color: const Color(0xFFDC2626),
            catalogId: 'cat_vitals_finger',
          ),
          (
            title: 'Anaemia Eye',
            sub: '4 photos · Lower eyelid',
            icon: Icons.remove_red_eye_rounded,
            color: const Color(0xFFE11D48),
            catalogId: 'cat_img_anaemia',
          ),
          (
            title: 'Jaundice Eye',
            sub: '4 photos · Sclera + card',
            icon: Icons.wb_incandescent_rounded,
            color: const Color(0xFFD97706),
            catalogId: 'cat_img_jaundice',
          ),
          (
            title: 'Cataract Eye',
            sub: '2 photos · Pupil close-up',
            icon: Icons.blur_circular_rounded,
            color: const Color(0xFF475569),
            catalogId: 'cat_img_cataract',
          ),
          (
            title: 'Child Eye',
            sub: '2 photos · Red reflex',
            icon: Icons.child_care_rounded,
            color: const Color(0xFFDB2777),
            catalogId: 'cat_img_child_eye',
          ),
          (
            title: 'Retina (Fundus)',
            sub: '4 photos · Clip-on camera',
            icon: Icons.flare_rounded,
            color: const Color(0xFFB45309),
            catalogId: 'cat_img_fundus',
          ),
          (
            title: 'Newborn Jaundice',
            sub: '4 photos · Skin + card',
            icon: Icons.child_friendly_rounded,
            color: const Color(0xFFCA8A04),
            catalogId: 'cat_img_newborn_jaundice',
          ),
          (
            title: 'Diabetic Foot',
            sub: '4 photos · Soles + toes',
            icon: Icons.healing_rounded,
            color: const Color(0xFF9F1239),
            catalogId: 'cat_img_dfu',
          ),
          (
            title: 'Skin Check',
            sub: '3 photos · Spot close-up',
            icon: Icons.texture_rounded,
            color: const Color(0xFF7C3AED),
            catalogId: 'cat_img_skin',
          ),
          (
            title: 'Dental Check',
            sub: '4 teeth photos · FDI chart',
            icon: Icons.sentiment_satisfied_alt_rounded,
            color: const Color(0xFF0284C7),
            catalogId: 'cat_dental_full',
          ),
          (
            title: 'Mouth Lining',
            sub: '6 photos · Not teeth',
            icon: Icons.medical_services_rounded,
            color: const Color(0xFF0D9488),
            catalogId: 'cat_img_oral',
          ),
          (
            title: 'Cough & TB',
            sub: '3 Coughs · Mic',
            icon: Icons.air_rounded,
            color: const Color(0xFF2563EB),
            catalogId: 'cat_aud_tb',
          ),
          (
            title: 'Stroke FAST',
            sub: 'Face·Arm·Speech',
            icon: Icons.emergency_rounded,
            color: const Color(0xFF7C3AED),
            catalogId: 'cat_stroke_fast',
          ),
          (
            title: 'Vision 40cm',
            sub: 'Acuity · Amsler',
            icon: Icons.visibility_rounded,
            color: const Color(0xFF059669),
            catalogId: 'cat_vis_acuity',
          ),
        ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: quickItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 102,
      ),
      itemBuilder: (context, i) {
        final q = quickItems[i];
        final catItem = VitalsMirrorCatalogRegistry.catalogueItems
            .where((c) => c.id == q.catalogId)
            .firstOrNull;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (catItem != null) {
              _openCatalogueItem(context, appState, catItem, outcomes: null);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: q.color.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: q.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(q.icon, color: q.color, size: 20),
                ),
                const SizedBox(height: 5),
                Text(
                  q.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  q.sub,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: MirrorColors.inkMutedLight,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontalPackageCard(
    BuildContext context,
    AppState appState,
    HealthScanPackage pkg,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PackageDetailAndRunnerScreen(package: pkg),
          ),
        );
      },
      child: Container(
        width: 268,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: pkg.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      pkg.badgeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '⏱ ${pkg.totalDurationLabel}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pkg.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pkg.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.28,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF00E5CC),
                  size: 17,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Start ${pkg.includedCatalogueIds.length}-Step Guided Pack ->',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF00E5CC),
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 1: Dedicated Health Check Packages Tab (8 Curated Multi-Scan Bundles)
  Widget _buildHealthPackagesTab(BuildContext context, AppState appState) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Curated Health Check Packages',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Run bundled multi-sensor screenings in one guided flow, or switch to Separate Screenings.',
                    style: TextStyle(
                      fontSize: 12,
                      color: MirrorColors.inkMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.grid_view_rounded, size: 15),
              label: const Text('Separate', style: TextStyle(fontSize: 12)),
              onPressed: () => setState(() => _tabIndex = 2),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...HealthPackagesRegistry.packages.map(
          (pkg) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PackageDetailAndRunnerScreen(package: pkg),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: pkg.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              pkg.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pkg.tagline,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF00E5CC),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pkg.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              pkg.totalDurationLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pkg.subtitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: pkg.biomarkersCovered
                                .take(5)
                                .map(
                                  (b) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MirrorColors.primaryContainer
                                          .withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      b,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: MirrorColors.primary,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${pkg.includedCatalogueIds.length} Guided Scans · ${pkg.permissionsNeeded.length} Sensor Checks',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: MirrorColors.inkMutedLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 17,
                                ),
                                label: const Text('Open Pack'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          PackageDetailAndRunnerScreen(
                                            package: pkg,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Tab 2: S-C02 All 34 Separate Individual Screenings with Permission Badges & Category Filter
  Widget _buildIndividualScreeningsTab(
    BuildContext context,
    AppState appState,
  ) {
    final subj = appState.activeSubject;
    final items = VitalsMirrorCatalogRegistry.catalogueItems.where((item) {
      if (_selectedCatalogueCategory == 'All') return true;
      return item.category == _selectedCatalogueCategory;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '34 Separate Individual Screenings',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                      ),
                    ),
                    Text(
                      'Each scan verifies camera, flash, mic, or motion permissions.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: MirrorColors.inkMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.inventory_2_outlined, size: 15),
                label: const Text('Packs'),
                onPressed: () => setState(() => _tabIndex = 1),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: VitalsMirrorCatalogRegistry.categories.map((cat) {
              final selected = cat == _selectedCatalogueCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCatalogueCategory = cat),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final outcomes = appState.evaluateGatesForItem(item);
              final allPassed = outcomes.every(
                (o) => o.passed || o.isAdvisoryOnly,
              );
              final firstBlocker = outcomes
                  .where((o) => !o.passed && !o.isAdvisoryOnly)
                  .firstOrNull;
              final perms = HealthPackagesRegistry.permissionsForTargetScreen(
                item.targetScreenId,
                imageScreenType: item.imageScreenType,
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: allPassed
                                  ? MirrorColors.primaryContainer
                                  : MirrorColors.warningBg,
                              foregroundColor: allPassed
                                  ? MirrorColors.primary
                                  : MirrorColors.warningFg,
                              child: Icon(
                                allPassed
                                    ? _iconForCategory(item.category)
                                    : Icons.lock_outline_rounded,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: MirrorColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                        child: Text(
                                          item.durationLabel,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: MirrorColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _permBadge(
                              Icons.sensors_rounded,
                              item.hardwareNeeded,
                            ),
                            ...perms
                                .take(2)
                                .map(
                                  (p) => _permBadge(
                                    p.icon,
                                    p.title.split('(').first.trim(),
                                  ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                allPassed
                                    ? '✓ Eligible for ${subj.fullName.split(" ").first}'
                                    : 'Gate: ${firstBlocker?.reason ?? "Blocked"}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: allPassed
                                      ? MirrorColors.successFg
                                      : MirrorColors.warningFg,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 17,
                              ),
                              label: const Text('Start Scan'),
                              onPressed: () => _openCatalogueItem(
                                context,
                                appState,
                                item,
                                outcomes: outcomes,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Vitals':
        return Icons.monitor_heart_rounded;
      case 'Eyes':
        return Icons.remove_red_eye_rounded;
      case 'Skin & Body':
        return Icons.healing_rounded;
      case 'Dental':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'Breathing & Voice':
        return Icons.air_rounded;
      case 'Sleep':
        return Icons.bedtime_rounded;
      case 'Hearing':
        return Icons.hearing_rounded;
      case 'Brain & Mind':
        return Icons.psychology_rounded;
      case 'Movement':
        return Icons.directions_walk_rounded;
      case 'Vision':
        return Icons.visibility_rounded;
      default:
        return Icons.biotech_rounded;
    }
  }

  Widget _permBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: MirrorColors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWithPermissionModal(
    BuildContext context, {
    required String scanTitle,
    required String scanDuration,
    required List<ScanPermissionItem> permissions,
    required List<String> preparationTips,
    required WidgetBuilder builder,
  }) async {
    final granted = await showScanPermissionReadinessModal(
      context: context,
      scanTitle: scanTitle,
      scanDuration: scanDuration,
      permissions: permissions,
      preparationTips: preparationTips,
    );
    if (granted && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
    }
  }

  Future<void> _openCatalogueItem(
    BuildContext context,
    AppState appState,
    ScreeningCatalogueItem item, {
    required List<GateCheckOutcome>? outcomes,
  }) async {
    final evalList = outcomes ?? appState.evaluateGatesForItem(item);
    final firstBlocker = evalList
        .where((o) => !o.passed && !o.isAdvisoryOnly)
        .firstOrNull;

    if (firstBlocker != null) {
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feature Gate Blocked · ${item.title}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                ),
              ),
              const SizedBox(height: 12),
              GateBlockerCard(
                outcome: firstBlocker,
                onFixPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ConsentCenterScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Show Pre-Scan Permission & Sensor Readiness Modal first
    final permissions = HealthPackagesRegistry.permissionsForTargetScreen(
      item.targetScreenId,
      imageScreenType: item.imageScreenType,
    );
    final tips = HealthPackagesRegistry.preparationTipsForTargetScreen(
      item.targetScreenId,
      imageScreenType: item.imageScreenType,
    );

    final granted = await showScanPermissionReadinessModal(
      context: context,
      scanTitle: item.title,
      scanDuration: item.durationLabel,
      permissions: permissions,
      preparationTips: tips,
    );
    if (!granted || !context.mounted) return;

    if (item.imageScreenType == ImageScreenType.anaemia) {
      // Dedicated guided flow: S-E01 intro -> details -> prepare -> how-to
      // -> 4 flash photos (S-E03) -> S-R01.
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AnaemiaIntroScreen()),
      );
      return;
    }

    final eyeProtocol =
        EyeProtocols.forScreenType(item.imageScreenType) ??
        (item.targetScreenId == 'S-E06' ? EyeProtocols.fundus : null);
    if (eyeProtocol != null) {
      // Guided eye-photo flows: jaundice, cataract, child eye, fundus.
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EyeIntroScreen(protocol: eyeProtocol),
        ),
      );
      return;
    }

    if (item.imageScreenType != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageScreeningFlowScreen(
            screenType: item.imageScreenType!,
            autoStartScanner: true,
          ),
        ),
      );
      return;
    }

    switch (item.targetScreenId) {
      case 'S-D01':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const VitalsFlowScreen(
              initialMode: VitalsCaptureMode.face,
              autoStartScanner: true,
            ),
          ),
        );
      case 'S-D04':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const VitalsFlowScreen(
              initialMode: VitalsCaptureMode.finger,
              autoStartScanner: true,
            ),
          ),
        );
      case 'S-D09':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FormulaLabScreen()),
        );
      case 'S-D11':
      case 'S-D12':
      case 'S-D13':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const FunctionalCardioTestsScreen(),
          ),
        );
      case 'S-E06':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const EyeIntroScreen(protocol: EyeProtocols.fundus),
          ),
        );
      case 'S-F01':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const EyeIntroScreen(protocol: EyeProtocols.dentalCaries),
          ),
        );
      default:
        final breath =
            BreathProtocols.forCatalogueId(item.id) ??
            BreathProtocols.forScreenId(item.targetScreenId);
        if (breath != null) {
          // S-G02..S-G05: Breathing & Voice guided checks (readiness S-G01
          // runs inside the Prepare step).
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BreathIntroScreen(protocol: breath),
            ),
          );
        } else if (MindProtocols.forScreenId(item.targetScreenId) != null) {
          // S-G12 / S-G13 / S-G15 / S-H06: Brain & Mind guided checks.
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MindIntroScreen(
                protocol: MindProtocols.forScreenId(item.targetScreenId)!,
              ),
            ),
          );
        } else if (HearingProtocols.forScreenId(item.targetScreenId) != null) {
          // S-G10 / S-G11: guided hearing screen (intro → capture → result).
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const HearingIntroScreen()),
          );
        } else if (SleepProtocols.forCatalogueId(item.id) != null ||
            SleepProtocols.forScreenId(item.targetScreenId) != null) {
          // S-G07 → S-G08 → S-G09: overnight sleep sonar & apnoea screen.
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SleepIntroScreen()),
          );
        } else if (item.targetScreenId.startsWith('S-G')) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AudioSuiteScreen(initialScreenId: item.targetScreenId),
            ),
          );
        } else if (MovementProtocols.forScreenId(item.targetScreenId) != null) {
          // S-H01..S-H05: guided movement tests (intro → capture → result).
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MovementIntroScreen(
                protocol: MovementProtocols.forScreenId(item.targetScreenId)!,
              ),
            ),
          );
        } else if (VisionProtocols.forScreenId(item.targetScreenId) != null) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VisionIntroScreen(
                protocol: VisionProtocols.forScreenId(item.targetScreenId)!,
              ),
            ),
          );
        } else if (item.targetScreenId.startsWith('S-H')) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MovementVisionSuiteScreen(
                initialScreenId: item.targetScreenId,
              ),
            ),
          );
        } else {
          showScreenGateLifecycleSheet(context, item.targetScreenId);
        }
    }
  }

  /// Tab 3: S-C03 Session History & S-C05 Personal Baseline Trends (ALG-RSK-03/04)
  Widget _buildHistoryAndTrendsTab(BuildContext context, AppState appState) {
    final baselineCheck = RiskEngine.evaluateBaselineAndChange(
      historicalValidValuesWithin180Days: const [
        74,
        76,
        75,
        73,
        75,
        76,
        74,
        75,
        76,
        75,
      ],
      currentValue: 92,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      color: MirrorColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Personal Baseline & Change Detection (ALG-RSK-03/04)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      onPressed: () =>
                          showScreenGateLifecycleSheet(context, 'S-C05'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Personal baseline = median of last 3 valid values within 180 days (${baselineCheck.baselineMedian?.toStringAsFixed(1)} bpm); SD from last 10 (${baselineCheck.baselineSd?.toStringAsFixed(1)}). Meaningful change flagged when > 15% or > 2 personal SD.',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 10),
                BandChip(
                  band: baselineCheck.isMeaningfulChange
                      ? SemanticBand.moderate
                      : SemanticBand.normal,
                  customLabel:
                      'Latest 92 bpm vs Baseline ${baselineCheck.baselineMedian?.toStringAsFixed(0)} bpm (+${baselineCheck.changePct?.toStringAsFixed(1)}%)',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Recorded Screening Sessions',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
        const SizedBox(height: 10),
        ...appState.vitalsSessions.map(
          (v) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: const Icon(
                  Icons.favorite_rounded,
                  color: MirrorColors.primary,
                ),
                title: Text(
                  'Vitals Scan (${v.captureMode.label})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  'HR ${v.markers['HR']?.displayText} bpm · RR ${v.markers['RR']?.displayText} br/m · SNR ${v.pulseSnrDb.toStringAsFixed(1)} dB',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VitalsResultsSummaryScreen(session: v),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        ...appState.dentalExams.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: const Icon(
                  Icons.sentiment_satisfied_alt_rounded,
                  color: MirrorColors.primary,
                ),
                title: Text(
                  'Dental 4-View Exam (${d.isChildMode ? "Child" : "Adult"} · ${d.viewsCompleted}/4 views)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  'Caries Risk: ${d.cariesRiskBand.label}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DentalResultsScreen(exam: d),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        ...appState.screeningRecords.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: const Icon(
                  Icons.fact_check_outlined,
                  color: MirrorColors.primary,
                ),
                title: Text(
                  r.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  r.summaryText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: BandChip(band: r.primaryBand, compact: true),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SharedScreeningResultScreen(record: r),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Tab 4: S-C07 Profile, Settings, Permissions & 82-Screen Architecture Browser
  Widget _buildMoreAndArchitectureTab(BuildContext context, AppState appState) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: MirrorColors.primaryContainer.withValues(alpha: 0.45),
          child: ListTile(
            leading: const Icon(
              Icons.developer_board_rounded,
              color: MirrorColors.primary,
            ),
            title: const Text(
              '82-Screen, 37-Gate & Lifecycle Reference Browser',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: const Text(
              'Inspect or launch every single screen (S-A01..S-I05), its gates (G-01..G-37), and its lifecycle state machine.',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScreenArchitectureBrowserScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.verified_rounded,
              color: MirrorColors.successFg,
            ),
            title: const Text(
              'S-I05 · Live Spec Test Vectors Verification',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: const Text(
              'Verify HRV, Baevsky SI, all 15 Formulas (ALG-FRM-01..15), Caries Cases 1–6, and Risk Engine Cases T1–T16.',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SpecVectorsVerifierScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text(
                  'Profile, Health Context & Family Dependents',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileAndHealthContextScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text(
                  'Consent Center (Screening, Dental/Guardian, Training)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ConsentCenterScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: Text(
                  'Condition Cases (${appState.cases.length}) & Confirmatory Lab Pairing',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CasesListScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.devices_other_rounded),
                title: const Text(
                  'Device Readiness, Smart Ring & Fundus Camera',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DeviceReadinessAndHardwareScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text(
                  'Dark Theme Mode',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                value: appState.themeMode == ThemeMode.dark,
                onChanged: (_) => appState.toggleThemeMode(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Guided Multi-Scan Package Detail & Step-by-Step Runner Screen.
/// Lets the user inspect all scans, biomarkers, and required permissions in a Health Check Package
/// and launch each step sequentially with AI Voice Coach support.
class PackageDetailAndRunnerScreen extends StatefulWidget {
  const PackageDetailAndRunnerScreen({super.key, required this.package});

  final HealthScanPackage package;

  @override
  State<PackageDetailAndRunnerScreen> createState() =>
      _PackageDetailAndRunnerScreenState();
}

class _PackageDetailAndRunnerScreenState
    extends State<PackageDetailAndRunnerScreen> {
  final Set<String> _completedStepIds = {};

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;
    final steps = pkg.includedCatalogueIds
        .map(
          (id) => VitalsMirrorCatalogRegistry.catalogueItems
              .where((c) => c.id == id)
              .firstOrNull,
        )
        .whereType<ScreeningCatalogueItem>()
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(pkg.title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Package Hero Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: pkg.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      pkg.tagline,
                      style: const TextStyle(
                        color: Color(0xFF00E5CC),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Total: ${pkg.totalDurationLabel}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pkg.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pkg.subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Recommended For: ${pkg.recommendedFor}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Step-by-Step Guided Scans in this Package
          Text(
            '1. Guided Scans in This Package (${_completedStepIds.length}/${steps.length} Done)',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final done = _completedStepIds.contains(step.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: done
                        ? MirrorColors.successBg
                        : MirrorColors.primaryContainer,
                    foregroundColor: done
                        ? MirrorColors.successFg
                        : MirrorColors.primary,
                    child: Icon(
                      done ? Icons.check_rounded : Icons.looks_one_rounded,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    'Step ${idx + 1}: ${step.title}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    '${step.durationLabel} · ${step.hardwareNeeded}\n${step.subtitle}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  isThreeLine: true,
                  trailing: FilledButton.tonal(
                    onPressed: () => _launchPackageStep(context, step),
                    child: Text(done ? 'Rescan' : 'Start'),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 12),
          const Text(
            '2. Biomarkers & Clinical Outputs Covered',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pkg.biomarkersCovered
                .map(
                  (b) => Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 15,
                      color: MirrorColors.primary,
                    ),
                    label: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.play_circle_fill_rounded),
            label: Text(
              'Start Step 1: ${steps.firstOrNull?.title ?? "Scan"}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            onPressed: steps.isEmpty
                ? null
                : () => _launchPackageStep(context, steps.first),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPackageStep(
    BuildContext context,
    ScreeningCatalogueItem step,
  ) async {
    final perms = HealthPackagesRegistry.permissionsForTargetScreen(
      step.targetScreenId,
      imageScreenType: step.imageScreenType,
    );
    final tips = HealthPackagesRegistry.preparationTipsForTargetScreen(
      step.targetScreenId,
      imageScreenType: step.imageScreenType,
    );

    final granted = await showScanPermissionReadinessModal(
      context: context,
      scanTitle: step.title,
      scanDuration: step.durationLabel,
      permissions: perms,
      preparationTips: tips,
    );
    if (!granted || !context.mounted) return;

    setState(() => _completedStepIds.add(step.id));

    if (step.imageScreenType == ImageScreenType.anaemia) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AnaemiaIntroScreen()),
      );
      return;
    }

    final eyeProtocol =
        EyeProtocols.forScreenType(step.imageScreenType) ??
        (step.targetScreenId == 'S-E06' ? EyeProtocols.fundus : null);
    if (eyeProtocol != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EyeIntroScreen(protocol: eyeProtocol),
        ),
      );
      return;
    }

    if (step.imageScreenType != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageScreeningFlowScreen(
            screenType: step.imageScreenType!,
            autoStartScanner: true,
          ),
        ),
      );
      return;
    }

    if (step.targetScreenId == 'S-D04') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const VitalsFlowScreen(
            initialMode: VitalsCaptureMode.finger,
            autoStartScanner: true,
          ),
        ),
      );
    } else if (step.targetScreenId.startsWith('S-D')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const VitalsFlowScreen(
            initialMode: VitalsCaptureMode.face,
            autoStartScanner: true,
          ),
        ),
      );
    } else if (step.targetScreenId.startsWith('S-F')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const EyeIntroScreen(protocol: EyeProtocols.dentalCaries),
        ),
      );
    } else if (BreathProtocols.forScreenId(step.targetScreenId) != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BreathIntroScreen(
            protocol: BreathProtocols.forScreenId(step.targetScreenId)!,
          ),
        ),
      );
    } else if (MindProtocols.forScreenId(step.targetScreenId) != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MindIntroScreen(
            protocol: MindProtocols.forScreenId(step.targetScreenId)!,
          ),
        ),
      );
    } else if (HearingProtocols.forScreenId(step.targetScreenId) != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HearingIntroScreen()),
      );
    } else if (SleepProtocols.forScreenId(step.targetScreenId) != null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SleepIntroScreen()));
    } else if (step.targetScreenId.startsWith('S-G')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AudioSuiteScreen(initialScreenId: step.targetScreenId),
        ),
      );
    } else if (MovementProtocols.forScreenId(step.targetScreenId) != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MovementIntroScreen(
            protocol: MovementProtocols.forScreenId(step.targetScreenId)!,
          ),
        ),
      );
    } else if (VisionProtocols.forScreenId(step.targetScreenId) != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VisionIntroScreen(
            protocol: VisionProtocols.forScreenId(step.targetScreenId)!,
          ),
        ),
      );
    } else if (step.targetScreenId.startsWith('S-H')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              MovementVisionSuiteScreen(initialScreenId: step.targetScreenId),
        ),
      );
    }
  }
}
