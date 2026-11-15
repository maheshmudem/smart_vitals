import 'dart:math' as math;
import 'scan_art.dart';
import 'package_card.dart';
import 'home_widgets.dart';
import '../../core/domain/entities/marker_envelope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import '../../core/design_system/mirror_motion.dart';
import '../members/member_screens.dart';
import '../operator/operator_home_screen.dart';
import '../trends/trends_screen.dart';
import '../members/member_switcher_sheet.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_widgets.dart';
import '../../core/design_system/mirror_ui.dart';
import '../../core/domain/algorithms/risk_engine.dart';
import '../../core/domain/algorithms/formulas_engine.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/health_package.dart';
import '../../core/domain/entities/screening_catalogue_item.dart';
import '../../core/domain/gates/gate_evaluator.dart';
import '../../core/services/voice_coach_service.dart';
import '../../core/state/app_state.dart';
import '../access_profile_settings/access_profile_settings_screens.dart';
import '../anaemia/anaemia_ui_kit.dart';
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

/// Flagship 5-tab application shell:
/// - Tab 0: Home (S-C01) — hero scan card, quick scans, packages, latest vitals
/// - Tab 1: Packs — curated multi-scan packages with a guided runner
/// - Tab 2: Scans (S-C02) — all individual screenings with sensor badges
/// - Tab 3: History (S-C03/C05) — personal baseline and past sessions
/// - Tab 4: More (S-C07) — profile, consent, devices, appearance, developer
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _tabIndex = 0;
  final Set<int> _visitedTabs = {0};
  String _selectedCatalogueCategory = 'All';
  String _packFilter = 'All';
  String _scanQuery = '';
  bool _scanBrowseAll = false;
  String _scanAvail = 'All';
  String _historyKind = 'All';
  final TextEditingController _scanSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _scanSearchCtrl.dispose();
    super.dispose();
  }

  static const List<String> _tabScreenIds = [
    'S-C01',
    'S-C02',
    'S-C02',
    'S-C03',
    'S-C07',
  ];

  @override
  Widget build(BuildContext context) {
    _visitedTabs.add(_tabIndex);
    final appState = AppStateScope.of(context);
    final currentScreenId = _tabScreenIds[_tabIndex];

    final scaffold = Scaffold(
      appBar: _tabIndex != 1
          ? null
          : AppBar(
              title: const Row(
                children: [
                  BrandMark(size: 28),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'VitalsMirror',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                _buildSubjectSwitcher(context, appState),
                IconButton(
                  tooltip: 'About this screen',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () =>
                      showScreenGateLifecycleSheet(context, currentScreenId),
                ),
                const SizedBox(width: 4),
              ],
            ),
      body: FadeIndexedStack(
        index: _tabIndex,
        children: [
          _buildHomeTab(context, appState),
          _visitedTabs.contains(1)
              ? _buildHealthPackagesTab(context, appState)
              : const SizedBox.shrink(),
          _visitedTabs.contains(2)
              ? _buildIndividualScreeningsTab(context, appState)
              : const SizedBox.shrink(),
          _visitedTabs.contains(3)
              ? _buildHistoryAndTrendsTab(context, appState)
              : const SizedBox.shrink(),
          _visitedTabs.contains(4)
              ? _buildMoreAndArchitectureTab(context, appState)
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _tabIndex,
          animationDuration: const Duration(milliseconds: 350),
          onDestinationSelected: (i) {
            if (i == _tabIndex) return;
            HapticFeedback.selectionClick();
            setState(() => _tabIndex = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Packs',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Scans',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_rounded),
              selectedIcon: Icon(Icons.menu_open_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
    return scaffold;
  }

  /// Compact "avatar + first name" pill; opens the account-switcher sheet.
  Widget _buildSubjectSwitcher(BuildContext context, AppState appState) {
    final scheme = Theme.of(context).colorScheme;
    final subj = appState.activeSubject;
    final first = subj.fullName.split(' ').first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: StadiumBorder(side: BorderSide(color: scheme.outline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('member_switcher_pill'),
          onTap: () => showMemberSwitcher(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(3, 3, 6, 3),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Row(
                key: ValueKey(subj.id),
                mainAxisSize: MainAxisSize.min,
                children: [
                  MemberAvatar(name: subj.fullName, radius: 12),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 76),
                    child: Text(
                      first,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tab 0: Home dashboard (S-C01) — health-dashboard layout.
  Widget _buildHomeTab(BuildContext context, AppState appState) {
    final subj = appState.activeSubject;
    final latestVitals = appState.vitalsSessions.firstOrNull;
    final first = subj.fullName.split(' ').first;
    final score = _healthScore(latestVitals);

    String? markerText(String code) {
      final m = latestVitals?.markers[code];
      if (m == null) return null;
      return m.shouldShowNumericValue ? m.displayText : m.band.label;
    }

    final stats = <HeaderStat>[
      if (markerText('HR') != null)
        HeaderStat(
          icon: Icons.favorite_rounded,
          value: '${markerText('HR')} bpm',
          label: 'Heart rate',
        ),
      if (markerText('RR') != null)
        HeaderStat(
          icon: Icons.air_rounded,
          value: '${markerText('RR')}/min',
          label: 'Breathing',
        ),
      if (latestVitals?.markers['BAEVSKY_SI'] != null)
        HeaderStat(
          icon: Icons.bolt_rounded,
          value: latestVitals!.markers['BAEVSKY_SI']!.band.label,
          label: 'Stress',
        ),
    ];

    final scoreCaption = latestVitals == null
        ? 'Take a 1-minute face scan to see your score'
        : 'From your ${latestVitals.captureMode == VitalsCaptureMode.face ? "face" : "finger"} scan · ${_ago(latestVitals.recordedAt)}';

    const gutter = EdgeInsets.symmetric(horizontal: MirrorSpace.lg);
    const gap = SizedBox(height: MirrorSpace.xl);

    return ListView(
      scrollCacheExtent: const ScrollCacheExtent.pixels(600),
      padding: const EdgeInsets.only(bottom: MirrorSpace.xxl),
      children: [
        FadeSlideIn(
          offset: 0,
          child: HomeHeader(
            firstName: first,
            fullName: subj.fullName,
            score: score,
            scoreCaption: scoreCaption,
            stats: stats,
            alertCount: appState.cases.length,
            onAlerts: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CasesListScreen()),
            ),
            onSwitchMember: () => showMemberSwitcher(context),
          ),
        ),
        const SizedBox(height: 14),

        // Search
        FadeSlideIn(
          index: 1,
          child: Padding(
            padding: gutter,
            child: _buildSearch(context, appState),
          ),
        ),
        gap,

        // Categories
        FadeSlideIn(
          index: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: gutter,
                child: SectionHeader(
                  title: 'Browse by category',
                  actionLabel: 'All scans',
                  onAction: () => setState(() {
                    _selectedCatalogueCategory = 'All';
                    _tabIndex = 2;
                  }),
                ),
              ),
              SizedBox(
                height: 68,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  itemCount: _homeCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (context, i) {
                    final c = _homeCategories[i];
                    return CategoryShortcut(
                      label: c.label,
                      icon: _iconForCategory(c.category),
                      color: c.color,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedCatalogueCategory = c.category;
                          _tabIndex = 2;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        gap,

        // Featured scans carousel
        FadeSlideIn(
          index: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: gutter,
                child: SectionHeader(title: 'Featured scans'),
              ),
              FeaturedCarousel(items: _featuredScans(context, appState)),
            ],
          ),
        ),
        gap,

        // Curated packages
        FadeSlideIn(
          index: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: gutter,
                child: SectionHeader(
                  title: 'Health packages',
                  actionLabel: 'See all',
                  onAction: () => setState(() => _tabIndex = 1),
                ),
              ),
              SizedBox(
                height: 136,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: gutter,
                  itemCount: HealthPackagesRegistry.packages.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: MirrorSpace.md),
                  itemBuilder: (context, index) {
                    final pkg = HealthPackagesRegistry.packages[index];
                    return _buildHorizontalPackageCard(context, appState, pkg);
                  },
                ),
              ),
            ],
          ),
        ),

        // Latest vitals snapshot
        if (latestVitals != null) ...[
          gap,
          FadeSlideIn(
            index: 5,
            child: Padding(
              padding: gutter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'Latest vitals',
                    actionLabel: 'Full report',
                    onAction: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              VitalsResultsSummaryScreen(session: latestVitals),
                        ),
                      );
                    },
                  ),
                  () {
                    final raw = [
                      for (final code in const [
                        'HR',
                        'RR',
                        'BAEVSKY_SI',
                        'MAP',
                      ])
                        if (latestVitals.markers[code] != null)
                          MetricTile(marker: latestVitals.markers[code]!),
                    ];
                    // Keep full rows only, so the grid never has a gap.
                    final tiles = raw.length > 1 && raw.length.isOdd
                        ? raw.sublist(0, raw.length - 1)
                        : raw;
                    return Column(
                      children: [
                        for (var i = 0; i < tiles.length; i += 2) ...[
                          if (i > 0) const SizedBox(height: 10),
                          SizedBox(
                            height: 104,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: RepaintBoundary(child: tiles[i]),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: i + 1 < tiles.length
                                      ? RepaintBoundary(child: tiles[i + 1])
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  }(),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static const _homeCategories =
      <({String category, String label, Color color})>[
        (category: 'Vitals', label: 'Vitals', color: Color(0xFFDC2626)),
        (category: 'Eyes', label: 'Eyes', color: Color(0xFF0B7A75)),
        (category: 'Dental', label: 'Dental', color: Color(0xFF0284C7)),
        (category: 'Skin & Body', label: 'Skin', color: Color(0xFF9F1239)),
        (
          category: 'Breathing & Voice',
          label: 'Breath',
          color: Color(0xFF2563EB),
        ),
        (category: 'Brain & Mind', label: 'Mind', color: Color(0xFF7C3AED)),
        (category: 'Sleep', label: 'Sleep', color: Color(0xFF4C5BD4)),
        (category: 'Hearing', label: 'Hearing', color: Color(0xFFD97706)),
        (category: 'Vision', label: 'Vision', color: Color(0xFF059669)),
        (category: 'Movement', label: 'Movement', color: Color(0xFFDB2777)),
      ];

  /// Simple 0–100 wellness score from the latest vitals bands.
  int? _healthScore(VitalsSessionResult? v) {
    if (v == null) return null;
    final scores = <int>[];
    for (final m in v.markers.values) {
      final style = BandVisualStyle.forBand(m.band);
      if (style.foreground == MirrorColors.successFg) {
        scores.add(100);
      } else if (style.foreground == MirrorColors.warningFg) {
        scores.add(65);
      } else if (style.foreground == MirrorColors.dangerFg ||
          m.band == SemanticBand.emergency) {
        scores.add(35);
      }
    }
    if (scores.isEmpty) return null;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'yesterday';
    return '${d.inDays} days ago';
  }

  Widget _buildSearch(BuildContext context, AppState appState) {
    final scheme = Theme.of(context).colorScheme;
    final items = VitalsMirrorCatalogRegistry.catalogueItems;
    return SearchAnchor(
      viewHintText: 'Search screenings',
      builder: (context, controller) => SearchBar(
        key: const ValueKey('home_search'),
        controller: controller,
        hintText: 'Search ${items.length} screenings…',
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surface),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14),
        ),
        hintStyle: WidgetStatePropertyAll(
          Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        leading: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
        trailing: [
          Icon(Icons.tune_rounded, size: 20, color: scheme.onSurfaceVariant),
        ],
        onTap: controller.openView,
        onChanged: (_) => controller.openView(),
      ),
      suggestionsBuilder: (context, controller) {
        final q = controller.text.trim().toLowerCase();
        final matches = items
            .where(
              (i) =>
                  q.isEmpty ||
                  i.title.toLowerCase().contains(q) ||
                  i.subtitle.toLowerCase().contains(q) ||
                  i.category.toLowerCase().contains(q),
            )
            .take(30);
        return [
          for (final i in matches)
            ListTile(
              leading: IconBadge(icon: _iconForCategory(i.category), size: 36),
              title: Text(i.title),
              subtitle: Text('${i.category} · ${i.durationLabel}'),
              onTap: () {
                controller.closeView(null);
                _openCatalogueItem(context, appState, i, outcomes: null);
              },
            ),
        ];
      },
    );
  }

  List<FeaturedScan> _featuredScans(BuildContext context, AppState appState) {
    void openCatalogue(String id) {
      final item = VitalsMirrorCatalogRegistry.catalogueItems
          .where((c) => c.id == id)
          .firstOrNull;
      if (item != null) {
        _openCatalogueItem(context, appState, item, outcomes: null);
      }
    }

    return [
      FeaturedScan(
        title: 'Face vitals scan',
        subtitle: 'Heart rate, breathing & stress',
        duration: '60 s',
        icon: Icons.face_retouching_natural_rounded,
        colors: const [Color(0xFF0B7A75), Color(0xFF07263A)],
        onStart: () => _launchWithPermissionModal(
          context,
          scanTitle: '1-Minute Face rPPG Vitals Scan',
          scanDuration: '60 Seconds',
          permissions: HealthPackagesRegistry.facePermissions,
          preparationTips:
              HealthPackagesRegistry.preparationTipsForTargetScreen('S-D02'),
          builder: (_) => const VitalsFlowScreen(
            initialMode: VitalsCaptureMode.face,
            autoStartScanner: true,
          ),
        ),
      ),
      FeaturedScan(
        title: 'Finger SpO2',
        subtitle: 'Oxygen level with the torch',
        duration: '30 s',
        icon: Icons.fingerprint_rounded,
        colors: const [Color(0xFFE11D48), Color(0xFF7F1D1D)],
        onStart: () => _launchWithPermissionModal(
          context,
          scanTitle: 'Finger PPG & SpO2 Scan',
          scanDuration: '30–60 Seconds',
          permissions: HealthPackagesRegistry.fingerPermissions,
          preparationTips:
              HealthPackagesRegistry.preparationTipsForTargetScreen('S-D04'),
          builder: (_) => const VitalsFlowScreen(
            initialMode: VitalsCaptureMode.finger,
            autoStartScanner: true,
          ),
        ),
      ),
      FeaturedScan(
        title: 'Anaemia eye check',
        subtitle: '4 photos of the lower eyelid',
        duration: '2 min',
        icon: Icons.remove_red_eye_rounded,
        colors: const [Color(0xFF7C3AED), Color(0xFF312E81)],
        onStart: () => openCatalogue('cat_img_anaemia'),
      ),
      FeaturedScan(
        title: 'Cough & TB screen',
        subtitle: 'Record 3 coughs with the mic',
        duration: '1 min',
        icon: Icons.air_rounded,
        colors: const [Color(0xFF2563EB), Color(0xFF1E3A8A)],
        onStart: () => openCatalogue('cat_aud_tb'),
      ),
    ];
  }

  Widget _buildHorizontalPackageCard(
    BuildContext context,
    AppState appState,
    HealthScanPackage pkg,
  ) {
    return PackageMiniCard(
      package: pkg,
      onOpen: () => _openPackage(context, pkg),
    );
  }

  void _openPackage(BuildContext context, HealthScanPackage pkg) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PackageDetailAndRunnerScreen(package: pkg),
      ),
    );
  }

  /// Audience filters for the Packs tab (package id → groups).
  static const Map<String, List<String>> _packAudience = {
    'pkg_complete_vitals': ['Adults'],
    'pkg_annual_master': ['Adults', 'Seniors'],
    'pkg_metabolic_diabetes': ['Adults', 'Seniors'],
    'pkg_maternal_anaemia': ['Women'],
    'pkg_child_growth_dental': ['Kids'],
    'pkg_newborn_jaundice': ['Kids'],
    'pkg_respiratory_sleep': ['Adults', 'Seniors'],
    'pkg_senior_neuro_vision': ['Seniors'],
  };
  static const _packFilters = ['All', 'Adults', 'Women', 'Kids', 'Seniors'];

  List<IconData> _scanIconsFor(HealthScanPackage pkg) => [
    for (final id in pkg.includedCatalogueIds)
      _iconForCategory(
        VitalsMirrorCatalogRegistry.catalogueItems
                .where((c) => c.id == id)
                .firstOrNull
                ?.category ??
            '',
      ),
  ];

  /// Tab 1: Health check packages — showcase layout.
  Widget _buildHealthPackagesTab(BuildContext context, AppState appState) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final all = HealthPackagesRegistry.packages;
    final showAll = _packFilter == 'All';
    final featured = all.first;
    final list = showAll
        ? all.skip(1).toList()
        : all
              .where(
                (p) => (_packAudience[p.id] ?? const []).contains(_packFilter),
              )
              .toList();

    return ListView(
      scrollCacheExtent: const ScrollCacheExtent.pixels(600),
      padding: MirrorSpace.screen,
      children: [
        PageHeading(
          title: 'Health Packs',
          subtitle: '${all.length} guided bundles · several scans in one flow',
        ),
        // Audience filter
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _packFilters.length,
            separatorBuilder: (_, _) => const SizedBox(width: MirrorSpace.sm),
            itemBuilder: (context, i) {
              final f = _packFilters[i];
              final selected = f == _packFilter;
              return ChoiceChip(
                label: Text(f),
                selected: selected,
                visualDensity: VisualDensity.compact,
                labelStyle: t.labelMedium?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
                selectedColor: scheme.primary,
                side: BorderSide(
                  color: selected ? scheme.primary : scheme.outline,
                ),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _packFilter = f);
                },
              );
            },
          ),
        ),
        const SizedBox(height: MirrorSpace.lg),
        if (showAll) ...[
          PackageHeroCard(
            package: featured,
            onOpen: () => _openPackage(context, featured),
          ),
          const SizedBox(height: MirrorSpace.xl),
        ],
        SectionHeader(
          title: showAll ? 'All packs' : '$_packFilter packs',
          subtitle: '${list.length} ${list.length == 1 ? "pack" : "packs"}',
        ),
        if (list.isEmpty)
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No packs here yet',
          )
        else
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == list.length - 1 ? 0 : MirrorSpace.md,
              ),
              child: PackageShowcaseCard(
                package: list[i],
                scanIcons: _scanIconsFor(list[i]),
                onOpen: () => _openPackage(context, list[i]),
              ),
            ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: S-C02 Screenings — dark immersive layout with neon illustrations.
  // ---------------------------------------------------------------------------

  /// Set at the start of each Scans build from the active theme.
  bool _scanDark = false;

  Color get _ink => _scanDark ? Colors.white : MirrorColors.inkLight;
  Color get _inkMuted =>
      _scanDark ? const Color(0x99FFFFFF) : MirrorColors.inkMutedLight;
  Color get _inkFaint =>
      _scanDark ? const Color(0x80FFFFFF) : const Color(0xFF94A3B8);
  Color get _glassFill =>
      _scanDark ? const Color(0x0FFFFFFF) : const Color(0xE6FFFFFF);
  Color get _glassLine =>
      _scanDark ? const Color(0x1AFFFFFF) : MirrorColors.outlineLight;
  Color get _searchFill => _scanDark ? const Color(0x14FFFFFF) : Colors.white;
  Color get _track =>
      _scanDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0);
  Color get _accent => _scanDark ? MirrorColors.accent : MirrorColors.primary;
  Color get _onNeon => _scanDark ? const Color(0xFF06121F) : Colors.white;
  Color get _amber =>
      _scanDark ? const Color(0xFFFBBF24) : MirrorColors.warningFg;
  List<Color> get _scanBg => _scanDark
      ? const [Color(0xFF050914), Color(0xFF0A1226), Color(0xFF071A24)]
      : const [Color(0xFFF4F7FB), Color(0xFFF1F5F9), Color(0xFFEEF6F5)];

  /// Brighter category colour that reads as "neon" on the dark background.
  Color _neon(String category) => (_scanDark
      ? Color.lerp(_categoryColor(category), Colors.white, 0.3)!
      : _categoryColor(category));

  BoxDecoration _glass({double radius = 20, Color? tint}) => BoxDecoration(
    color: tint == null
        ? _glassFill
        : Color.alphaBlend(tint.withValues(alpha: 0.10), _glassFill),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: tint == null ? _glassLine : tint.withValues(alpha: 0.28),
    ),
  );

  Widget _buildIndividualScreeningsTab(
    BuildContext context,
    AppState appState,
  ) {
    _scanDark = Theme.of(context).brightness == Brightness.dark;
    final all = VitalsMirrorCatalogRegistry.catalogueItems;
    final q = _scanQuery.trim().toLowerCase();
    bool matches(ScreeningCatalogueItem i) =>
        q.isEmpty ||
        i.title.toLowerCase().contains(q) ||
        i.subtitle.toLowerCase().contains(q) ||
        i.category.toLowerCase().contains(q) ||
        i.hardwareNeeded.toLowerCase().contains(q);
    final outcomesById = <String, List<GateCheckOutcome>>{
      for (final i in all) i.id: appState.evaluateGatesForItem(i),
    };
    bool eligible(ScreeningCatalogueItem i) => (outcomesById[i.id] ?? const [])
        .every((o) => o.passed || o.isAdvisoryOnly);

    final browsing =
        q.isNotEmpty ||
        _selectedCatalogueCategory != 'All' ||
        _scanBrowseAll ||
        _scanAvail != 'All';
    bool availOk(ScreeningCatalogueItem i) => switch (_scanAvail) {
      'Ready' => eligible(i),
      'Locked' => !eligible(i),
      _ => true,
    };
    final available = all.where(eligible).length;
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _scanDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _scanBg,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Soft colour glows
            Positioned(
              left: -90,
              top: -60,
              child: _Glow(color: Color(0xFF14B8A6), size: 280),
            ),
            Positioned(
              right: -110,
              top: 120,
              child: _Glow(color: Color(0xFF7C3AED), size: 260),
            ),
            ListView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(600),
              padding: EdgeInsets.fromLTRB(16, top + 14, 16, 28),
              children: [
                _immersiveHeader(context, appState, all.length, available),
                SizedBox(height: 12),
                _availabilityFilter(all.length, available),
                SizedBox(height: 20),
                if (browsing)
                  ..._scanResultsItems(
                    context,
                    appState,
                    all
                        .where(
                          (i) =>
                              (_selectedCatalogueCategory == 'All' ||
                                  i.category == _selectedCatalogueCategory) &&
                              matches(i) &&
                              availOk(i),
                        )
                        .toList(),
                    q,
                    eligible,
                    outcomesById,
                  )
                else
                  ..._scanOverviewItems(context, appState, all, eligible),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _immersiveHeader(
    BuildContext context,
    AppState appState,
    int total,
    int available,
  ) {
    final subj = appState.activeSubject;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Screenings',
                style: TextStyle(
                  color: _ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            Material(
              color: _glassFill,
              shape: StadiumBorder(side: BorderSide(color: _glassLine)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => showMemberSwitcher(context),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(3, 3, 6, 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MemberAvatar(name: subj.fullName, radius: 13),
                      Icon(Icons.expand_more_rounded, size: 16, color: _ink),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Text(
          '$available of $total checks ready for ${subj.fullName.split(' ').first}',
          style: TextStyle(color: _inkMuted, fontSize: 13),
        ),
        SizedBox(height: 14),
        TextField(
          key: ValueKey('scans_search'),
          controller: _scanSearchCtrl,
          onChanged: (v) => setState(() => _scanQuery = v),
          textInputAction: TextInputAction.search,
          style: TextStyle(color: _ink, fontSize: 14),
          cursorColor: _accent,
          decoration: InputDecoration(
            hintText: 'Search scans, body parts or sensors',
            hintStyle: TextStyle(color: _inkFaint, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: _inkMuted),
            suffixIcon: _scanQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: _inkMuted,
                    ),
                    onPressed: () {
                      _scanSearchCtrl.clear();
                      setState(() => _scanQuery = '');
                    },
                  ),
            filled: true,
            fillColor: _searchFill,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _glassLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _glassLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _accent, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _darkSectionTitle(
    String title, {
    String? action,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (action != null)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(MirrorRadius.pill),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action,
                      style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: _accent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Overview: quick-start carousel + illustrated body-area tiles.
  List<Widget> _scanOverviewItems(
    BuildContext context,
    AppState appState,
    List<ScreeningCatalogueItem> all,
    bool Function(ScreeningCatalogueItem) eligible,
  ) {
    final quick = <ScreeningCatalogueItem>[];
    for (final cat in [
      'Vitals',
      'Eyes',
      'Dental',
      'Breathing & Voice',
      'Brain & Mind',
      'Vision',
    ]) {
      final pick = all
          .where((i) => i.category == cat && eligible(i))
          .firstOrNull;
      if (pick != null) quick.add(pick);
    }
    final recent = _recentSection(context, appState);

    Widget buildAreaTile(int idx) {
      final c = _homeCategories[idx];
      final items = all.where((s) => s.category == c.category).toList();
      return RepaintBoundary(
        child: _areaTile(
          c.category,
          c.label,
          items.length,
          items.where(eligible).length,
        ),
      );
    }

    return [
      ?recent,
      if (quick.isNotEmpty) ...[
        _darkSectionTitle('Quick start'),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: quick.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => RepaintBoundary(
              child: _quickStartCard(context, appState, quick[i]),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
      _darkSectionTitle(
        'Body areas',
        action: 'All ${all.length}',
        onTap: () => setState(() => _scanBrowseAll = true),
      ),
      for (var i = 0; i < _homeCategories.length; i += 2)
        Padding(
          padding: EdgeInsets.only(
            bottom: i + 2 < _homeCategories.length ? 12 : 0,
          ),
          child: SizedBox(
            height: 118,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: buildAreaTile(i)),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < _homeCategories.length
                      ? buildAreaTile(i + 1)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _quickStartCard(
    BuildContext context,
    AppState appState,
    ScreeningCatalogueItem item,
  ) {
    final neon = _neon(item.category);
    void open() => _openCatalogueItem(context, appState, item, outcomes: null);
    return SizedBox(
      width: 152,
      child: Pressable(
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: _glass(tint: neon),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showScanPreview(context, appState, item),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScanArt(category: item.category, color: neon, size: 56),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.durationLabel,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _inkMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _inkMuted, fontSize: 11.5),
                          ),
                        ),
                        _neonPlay(neon, open, tooltip: 'Start ${item.title}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _neonPlay(Color neon, VoidCallback onTap, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? 'Start',
      child: InkWell(
        onTap: onTap,
        customBorder: CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: neon,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: neon.withValues(alpha: 0.55), blurRadius: 14),
            ],
          ),
          child: Icon(Icons.play_arrow_rounded, size: 20, color: _onNeon),
        ),
      ),
    );
  }

  Widget _areaTile(String category, String label, int count, int ready) {
    final neon = _neon(category);
    return Pressable(
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: _glass(),
          child: InkWell(
            key: ValueKey('area_$category'),
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCatalogueCategory = category);
            },
            child: Stack(
              children: [
                Positioned(
                  right: 8,
                  top: 10,
                  child: ScanArt(
                    category: category,
                    color: neon,
                    size: 56,
                    glow: false,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Spacer(),
                      Text(
                        label,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        ready == count
                            ? '$count ${count == 1 ? "scan" : "scans"}'
                            : '$ready of $count ready',
                        style: TextStyle(color: _inkMuted, fontSize: 11.5),
                      ),
                      SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: count == 0 ? 0 : ready / count,
                          minHeight: 3,
                          backgroundColor: _track,
                          valueColor: AlwaysStoppedAnimation(neon),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Drill-in: illustrated banner, chips and a lazily culled glass list.
  List<Widget> _scanResultsItems(
    BuildContext context,
    AppState appState,
    List<ScreeningCatalogueItem> items,
    String q,
    bool Function(ScreeningCatalogueItem) eligible,
    Map<String, List<GateCheckOutcome>> outcomesById,
  ) {
    final single = _selectedCatalogueCategory != 'All' && q.isEmpty;
    final neon = single ? _neon(_selectedCatalogueCategory) : _accent;
    final title = q.isNotEmpty
        ? 'Results'
        : _selectedCatalogueCategory != 'All'
        ? _selectedCatalogueCategory
        : _scanAvail == 'Ready'
        ? 'Ready to start'
        : _scanAvail == 'Locked'
        ? 'Locked for now'
        : 'All screenings';
    final ready = items.where(eligible).length;

    void back() {
      _scanSearchCtrl.clear();
      setState(() {
        _scanQuery = '';
        _selectedCatalogueCategory = 'All';
        _scanBrowseAll = false;
        _scanAvail = 'All';
      });
    }

    return [
      RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 16),
          decoration: _glass(tint: neon),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      key: const ValueKey('scans_back'),
                      onPressed: back,
                      style: TextButton.styleFrom(
                        foregroundColor: _ink,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Body areas'),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6, top: 2),
                      child: Text(
                        '${items.length} ${items.length == 1 ? "scan" : "scans"} · $ready ready',
                        style: TextStyle(color: _inkMuted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (single)
                ScanArt(
                  category: _selectedCatalogueCategory,
                  color: neon,
                  size: 84,
                )
              else
                Icon(
                  q.isNotEmpty ? Icons.search_rounded : Icons.apps_rounded,
                  size: 56,
                  color: neon,
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: VitalsMirrorCatalogRegistry.categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = VitalsMirrorCatalogRegistry.categories[i];
            final selected = cat == _selectedCatalogueCategory;
            return InkWell(
              borderRadius: BorderRadius.circular(MirrorRadius.pill),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCatalogueCategory = cat;
                  if (cat == 'All') _scanBrowseAll = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _accent : _glassFill,
                  borderRadius: BorderRadius.circular(MirrorRadius.pill),
                  border: Border.all(color: selected ? _accent : _glassLine),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: selected ? _onNeon : _ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      if (items.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: _glass(),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 40, color: _inkMuted),
              const SizedBox(height: 10),
              Text(
                'No screenings found',
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                q.isEmpty
                    ? 'Try another body area.'
                    : 'Nothing matches "$_scanQuery".',
                textAlign: TextAlign.center,
                style: TextStyle(color: _inkMuted, fontSize: 12.5),
              ),
            ],
          ),
        )
      else
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
            child: RepaintBoundary(
              child: Container(
                decoration: _glass(radius: 18),
                child: Material(
                  type: MaterialType.transparency,
                  child: _scanListRow(
                    context,
                    appState,
                    items[i],
                    showCategory: !single,
                    outcomes: outcomesById[items[i].id],
                  ),
                ),
              ),
            ),
          ),
    ];
  }

  /// Glass list row with a mini illustration and neon play button.
  Widget _scanListRow(
    BuildContext context,
    AppState appState,
    ScreeningCatalogueItem item, {
    bool showCategory = false,
    List<GateCheckOutcome>? outcomes,
  }) {
    final resolvedOutcomes = outcomes ?? appState.evaluateGatesForItem(item);
    final ok = resolvedOutcomes.every((o) => o.passed || o.isAdvisoryOnly);
    final blocker = resolvedOutcomes
        .where((o) => !o.passed && !o.isAdvisoryOnly)
        .firstOrNull;
    final neon = _neon(item.category);
    final sensor = item.hardwareNeeded.split('(').first.trim();
    final meta = ok
        ? '${showCategory ? "${item.category} · " : ""}${item.durationLabel} · $sensor'
        : (blocker?.reason ?? 'Not available');
    void open() =>
        _openCatalogueItem(context, appState, item, outcomes: resolvedOutcomes);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showScanPreview(context, appState, item),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: (ok ? neon : _amber).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ok
                  ? ScanArt(category: item.category, color: neon, glow: false)
                  : Icon(Icons.lock_outline_rounded, color: _amber, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ok ? _inkMuted : _amber,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            ok
                ? _neonPlay(neon, open, tooltip: 'Start ${item.title}')
                : Icon(Icons.chevron_right_rounded, color: _inkMuted),
          ],
        ),
      ),
    );
  }

  /// Segmented All · Ready · Locked filter under the search field.
  Widget _availabilityFilter(int total, int available) {
    final options = [
      ('All', total),
      ('Ready', available),
      ('Locked', total - available),
    ];
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _glassFill,
        borderRadius: BorderRadius.circular(MirrorRadius.pill),
        border: Border.all(color: _glassLine),
      ),
      child: Row(
        children: [
          for (final (label, n) in options)
            Expanded(
              child: GestureDetector(
                key: ValueKey('scans_filter_$label'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _scanAvail = label);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _scanAvail == label ? _accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(MirrorRadius.pill),
                    boxShadow: _scanAvail == label
                        ? [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '$label  $n',
                    style: TextStyle(
                      color: _scanAvail == label ? _onNeon : _inkMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "Recently done" strip built from saved vitals, dental and screening
  /// results, newest first.
  /// Every saved result (vitals, dental, screenings), newest first.
  List<_HistoryEntry> _historyEntries(BuildContext context, AppState appState) {
    return <_HistoryEntry>[
      for (final v in appState.vitalsSessions)
        (
          kind: 'Vitals',
          title: v.captureMode == VitalsCaptureMode.face
              ? 'Face vitals'
              : 'Finger SpO2',
          category: 'Vitals',
          band: v.markers['HR']?.band ?? SemanticBand.notAssessed,
          at: v.recordedAt,
          onView: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VitalsResultsSummaryScreen(session: v),
            ),
          ),
          redoId: v.captureMode == VitalsCaptureMode.face
              ? 'cat_vitals_face'
              : 'cat_vitals_finger',
        ),
      for (final d in appState.dentalExams)
        (
          kind: 'Dental',
          title: 'Dental check',
          category: 'Dental',
          band: d.cariesRiskBand,
          at: d.recordedAt,
          onView: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DentalResultsScreen(exam: d),
            ),
          ),
          redoId: 'cat_dental_full',
        ),
      for (final r in appState.screeningRecords)
        (
          kind: 'Screenings',
          title: r.title,
          category: VitalsMirrorCatalogRegistry.categories.contains(r.category)
              ? r.category
              : 'Vitals',
          band: r.primaryBand,
          at: r.recordedAt,
          onView: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SharedScreeningResultScreen(record: r),
            ),
          ),
          redoId: null,
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
  }

  Widget? _recentSection(BuildContext context, AppState appState) {
    final entries = _historyEntries(context, appState);
    if (entries.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _darkSectionTitle('Recently done'),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: entries.take(8).length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final e = entries[i];
              final neon = _neon(e.category);
              final style = BandVisualStyle.forBand(e.band);
              final redo = e.redoId == null
                  ? null
                  : VitalsMirrorCatalogRegistry.catalogueItems
                        .where((c) => c.id == e.redoId)
                        .firstOrNull;
              return FadeSlideIn(
                index: i,
                child: SizedBox(
                  width: 236,
                  child: Pressable(
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        decoration: _glass(radius: 18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: e.onView,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: neon.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ScanArt(
                                    category: e.category,
                                    color: neon,
                                    glow: false,
                                    animate: false,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _ink,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            style.icon,
                                            size: 13,
                                            color: _scanDark
                                                ? Color.lerp(
                                                    style.foreground,
                                                    Colors.white,
                                                    0.35,
                                                  )
                                                : style.foreground,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              style.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _scanDark
                                                    ? Color.lerp(
                                                        style.foreground,
                                                        Colors.white,
                                                        0.35,
                                                      )
                                                    : style.foreground,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _ago(e.at),
                                        style: TextStyle(
                                          color: _inkMuted,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (redo != null)
                                  IconButton(
                                    tooltip: 'Redo ${e.title}',
                                    onPressed: () => _openCatalogueItem(
                                      context,
                                      appState,
                                      redo,
                                      outcomes: null,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: neon.withValues(
                                        alpha: 0.14,
                                      ),
                                      foregroundColor: neon,
                                      minimumSize: const Size(34, 34),
                                      fixedSize: const Size(34, 34),
                                      padding: EdgeInsets.zero,
                                    ),
                                    icon: const Icon(
                                      Icons.replay_rounded,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Bottom-sheet preview of a scan: big illustration, what it measures,
  /// sensors and tips, with a Start (or locked) action.
  Future<void> _showScanPreview(
    BuildContext context,
    AppState appState,
    ScreeningCatalogueItem item,
  ) {
    final outcomes = appState.evaluateGatesForItem(item);
    final ok = outcomes.every((o) => o.passed || o.isAdvisoryOnly);
    final blocker = outcomes
        .where((o) => !o.passed && !o.isAdvisoryOnly)
        .firstOrNull;
    final perms = HealthPackagesRegistry.permissionsForTargetScreen(
      item.targetScreenId,
      imageScreenType: item.imageScreenType,
    );
    final tips = HealthPackagesRegistry.preparationTipsForTargetScreen(
      item.targetScreenId,
      imageScreenType: item.imageScreenType,
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final t = Theme.of(sheetContext).textTheme;
        final scheme = Theme.of(sheetContext).colorScheme;
        final dark = scheme.brightness == Brightness.dark;
        final neon = dark
            ? Color.lerp(_categoryColor(item.category), Colors.white, 0.3)!
            : _categoryColor(item.category);

        Widget infoChip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(MirrorRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: neon),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelMedium,
                ),
              ),
            ],
          ),
        );

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    Center(
                      child: Container(
                        width: 132,
                        height: 132,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              neon.withValues(alpha: 0.22),
                              neon.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                        child: ScanArt(category: item.category, color: neon),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        item.category.toUpperCase(),
                        style: t.labelSmall?.copyWith(
                          color: neon,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: t.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        infoChip(Icons.schedule_rounded, item.durationLabel),
                        infoChip(
                          Icons.sensors_rounded,
                          item.hardwareNeeded.split('(').first.trim(),
                        ),
                      ],
                    ),
                    if (!ok) ...[
                      const SizedBox(height: 16),
                      InfoNote(
                        title: 'Not available right now',
                        text: blocker?.reason ?? 'This scan is locked.',
                        icon: Icons.lock_outline_rounded,
                        color: MirrorColors.warningFg,
                        background: MirrorColors.warningBg,
                      ),
                    ],
                    if (perms.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('What it uses', style: t.titleSmall),
                      const SizedBox(height: 8),
                      for (final p in perms.take(4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: neon.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(p.icon, size: 17, color: neon),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.title.split('(').first.trim(),
                                  style: t.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (tips.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Before you start', style: t.titleSmall),
                      const SizedBox(height: 8),
                      for (final tip in tips.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: neon,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(tip, style: t.bodySmall)),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: FilledButton.icon(
                    key: const ValueKey('scan_preview_start'),
                    onPressed: ok
                        ? () {
                            Navigator.of(sheetContext).pop();
                            _openCatalogueItem(
                              context,
                              appState,
                              item,
                              outcomes: outcomes,
                            );
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: neon,
                      foregroundColor: dark
                          ? const Color(0xFF06121F)
                          : Colors.white,
                    ),
                    icon: Icon(
                      ok
                          ? Icons.play_arrow_rounded
                          : Icons.lock_outline_rounded,
                    ),
                    label: Text(ok ? 'Start scan' : 'Locked'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _categoryColor(String category) =>
      _homeCategories
          .where((c) => c.category == category)
          .map((c) => c.color)
          .firstOrNull ??
      MirrorColors.primary;

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

  /// Tab 3: S-C03 session history & S-C05 personal baseline (ALG-RSK-03/04)
  /// — same theme-aware glass style as Scans.
  Widget _buildHistoryAndTrendsTab(BuildContext context, AppState appState) {
    _scanDark = Theme.of(context).brightness == Brightness.dark;
    const history = <double>[74, 76, 75, 73, 75, 76, 74, 75, 76, 75];
    const latest = 92.0;
    final baseline = RiskEngine.evaluateBaselineAndChange(
      historicalValidValuesWithin180Days: history,
      currentValue: latest,
    );
    final all = _historyEntries(context, appState);
    final kinds = [
      'All',
      ...{for (final e in all) e.kind},
    ];
    final filtered = _historyKind == 'All'
        ? all
        : all.where((e) => e.kind == _historyKind).toList();
    final now = DateTime.now();
    final thisWeek = all.where((e) => now.difference(e.at).inDays < 7).length;
    final areas = {for (final e in all) e.category}.length;
    final top = MediaQuery.paddingOf(context).top;
    final subj = appState.activeSubject;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _scanDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _scanBg,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -90,
              top: -70,
              child: _Glow(color: Color(0xFF14B8A6), size: 280),
            ),
            const Positioned(
              left: -120,
              top: 260,
              child: _Glow(color: Color(0xFF4C5BD4), size: 260),
            ),
            ListView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(600),
              padding: EdgeInsets.fromLTRB(16, top + 14, 16, 28),
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'History',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    Material(
                      color: _glassFill,
                      shape: StadiumBorder(side: BorderSide(color: _glassLine)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => showMemberSwitcher(context),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(3, 3, 6, 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MemberAvatar(name: subj.fullName, radius: 13),
                              Icon(
                                Icons.expand_more_rounded,
                                size: 16,
                                color: _ink,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Your trends and saved results',
                  style: TextStyle(color: _inkMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),

                // Plain-language insight
                FadeSlideIn(
                  child: _insightCard(
                    context,
                    appState,
                    latest: latest,
                    baseline: baseline,
                  ),
                ),
                const SizedBox(height: 12),

                // Trend card
                FadeSlideIn(
                  index: 1,
                  child: _trendCard(
                    context,
                    history: history,
                    latest: latest,
                    baseline: baseline,
                  ),
                ),
                const SizedBox(height: 12),

                // Summary strip
                FadeSlideIn(
                  index: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: _glass(radius: 18),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          _historyStat(
                            '${all.length}',
                            'Saved results',
                            Icons.folder_open_rounded,
                          ),
                          VerticalDivider(width: 1, color: _glassLine),
                          _historyStat(
                            '$thisWeek',
                            'This week',
                            Icons.calendar_today_rounded,
                          ),
                          VerticalDivider(width: 1, color: _glassLine),
                          _historyStat(
                            '$areas',
                            'Body areas',
                            Icons.category_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // Timeline
                _darkSectionTitle('Timeline'),
                if (kinds.length > 2) ...[
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kinds.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final k = kinds[i];
                        final selected = k == _historyKind;
                        return InkWell(
                          key: ValueKey('history_kind_$k'),
                          borderRadius: BorderRadius.circular(
                            MirrorRadius.pill,
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _historyKind = k);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? _accent : _glassFill,
                              borderRadius: BorderRadius.circular(
                                MirrorRadius.pill,
                              ),
                              border: Border.all(
                                color: selected ? _accent : _glassLine,
                              ),
                            ),
                            child: Text(
                              k,
                              style: TextStyle(
                                color: selected ? _onNeon : _ink,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    decoration: _glass(),
                    child: Column(
                      children: [
                        Icon(Icons.history_rounded, size: 40, color: _inkMuted),
                        const SizedBox(height: 10),
                        Text(
                          'No results yet',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scans you save will appear here.',
                          style: TextStyle(color: _inkMuted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  )
                else
                  ..._timeline(context, appState, filtered),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyStat(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: _accent),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _inkMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? "AM" : "PM"}';
  }

  /// Day-grouped timeline with a coloured rail.
  List<Widget> _timeline(
    BuildContext context,
    AppState appState,
    List<_HistoryEntry> entries,
  ) {
    final out = <Widget>[];
    String? lastDay;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final day = _dayLabel(e.at);
      if (day != lastDay) {
        out.add(
          Padding(
            padding: EdgeInsets.only(top: lastDay == null ? 0 : 8, bottom: 8),
            child: Text(
              day.toUpperCase(),
              style: TextStyle(
                color: _inkMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ),
        );
        lastDay = day;
      }
      final isLastOfDay =
          i == entries.length - 1 || _dayLabel(entries[i + 1].at) != day;
      final isFirstOfDay = i == 0 || _dayLabel(entries[i - 1].at) != day;
      out.add(
        FadeSlideIn(
          index: i + 2,
          child: _timelineTile(
            context,
            appState,
            e,
            isLastOfDay,
            isFirst: isFirstOfDay,
          ),
        ),
      );
    }
    return out;
  }

  Widget _timelineTile(
    BuildContext context,
    AppState appState,
    _HistoryEntry e,
    bool isLast, {
    bool isFirst = false,
  }) {
    final neon = _neon(e.category);
    final style = BandVisualStyle.forBand(e.band);
    final bandColor = _scanDark
        ? Color.lerp(style.foreground, Colors.white, 0.35)!
        : style.foreground;
    final redo = e.redoId == null
        ? null
        : VitalsMirrorCatalogRegistry.catalogueItems
              .where((c) => c.id == e.redoId)
              .firstOrNull;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(left: 30, bottom: isLast ? 0 : 10),
          child: Pressable(
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: _glass(radius: 18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: e.onView,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: neon.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ScanArt(
                            category: e.category,
                            color: neon,
                            glow: false,
                            animate: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bandColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(
                                        MirrorRadius.pill,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          style.icon,
                                          size: 12,
                                          color: bandColor,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          style.label,
                                          style: TextStyle(
                                            color: bandColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${e.category} · ${_clock(e.at)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _inkMuted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _bandMeaning(e.band),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _ink.withValues(alpha: 0.8),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (redo != null)
                          IconButton(
                            tooltip: 'Redo ${e.title}',
                            onPressed: () => _openCatalogueItem(
                              context,
                              appState,
                              redo,
                              outcomes: null,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: neon.withValues(alpha: 0.14),
                              foregroundColor: neon,
                              minimumSize: const Size(32, 32),
                              fixedSize: const Size(32, 32),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.replay_rounded, size: 17),
                          )
                        else
                          Icon(Icons.chevron_right_rounded, color: _inkMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Rail: dot centred on the card, line joining the day's results.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 20,
          child: Column(
            children: [
              Expanded(
                child: isFirst
                    ? const SizedBox()
                    : Container(width: 2, color: _glassLine),
              ),
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: bandColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _scanDark ? const Color(0xFF0A1226) : Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: bandColor.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLast
                    ? const SizedBox()
                    : Container(width: 2, color: _glassLine),
              ),
              Container(width: 2, height: isLast ? 0 : 10, color: _glassLine),
            ],
          ),
        ),
      ],
    );
  }

  /// Plain-language "what this means" card above the trend chart.
  Widget _insightCard(
    BuildContext context,
    AppState appState, {
    required double latest,
    required PersonalBaselineResult baseline,
  }) {
    final base = baseline.baselineMedian ?? latest;
    final change = baseline.changePct ?? 0;
    final flagged = baseline.isMeaningfulChange;
    final higher = latest >= base;
    final color = flagged
        ? _amber
        : (_scanDark ? MirrorColors.accent : MirrorColors.successFg);
    final title = !flagged
        ? 'Your heart rate is normal for you'
        : higher
        ? 'Your heart rate is higher than usual'
        : 'Your heart rate is lower than usual';
    final body = !flagged
        ? 'Your latest reading of ${latest.toStringAsFixed(0)} bpm is close to your usual ${base.toStringAsFixed(0)} bpm. Keep checking now and then to track changes.'
        : '${latest.toStringAsFixed(0)} bpm is about ${change.abs().toStringAsFixed(0)}% ${higher ? "above" : "below"} your usual ${base.toStringAsFixed(0)} bpm. '
              '${higher ? "Activity, coffee, stress or feeling unwell can raise it." : "Deep rest or some medicines can lower it."} '
              'Sit quietly for 5 minutes, then check again.';
    final face = VitalsMirrorCatalogRegistry.catalogueItems
        .where((c) => c.id == 'cat_vitals_face')
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _glass(tint: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  flagged
                      ? Icons.lightbulb_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHAT THIS MEANS',
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        color: _inkMuted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (face != null)
                  FilledButton.icon(
                    key: const ValueKey('history_check_again'),
                    onPressed: () => _openCatalogueItem(
                      context,
                      appState,
                      face,
                      outcomes: null,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: _scanDark
                          ? const Color(0xFF06121F)
                          : Colors.white,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.favorite_rounded, size: 16),
                    label: const Text('Check again'),
                  ),
                TextButton(
                  onPressed: () =>
                      showScreenGateLifecycleSheet(context, 'S-C05'),
                  style: TextButton.styleFrom(
                    foregroundColor: _ink,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Learn more'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Short plain-language meaning for a result band.
  String _bandMeaning(SemanticBand band) {
    final s = BandVisualStyle.forBand(band);
    if (s.foreground == MirrorColors.successFg) return 'Looks normal';
    if (s.foreground == MirrorColors.warningFg) {
      return 'Worth keeping an eye on';
    }
    if (s.foreground == MirrorColors.dangerFg ||
        band == SemanticBand.emergency) {
      return 'Needs attention · open to see next steps';
    }
    return 'Needs another check to be sure';
  }

  Widget _trendCard(
    BuildContext context, {
    required List<double> history,
    required double latest,
    required PersonalBaselineResult baseline,
  }) {
    final base = baseline.baselineMedian ?? history.last;
    final sd = baseline.baselineSd ?? 0;
    final change = baseline.changePct ?? 0;
    final flagged = baseline.isMeaningfulChange;
    final heart = _neon('Vitals');
    final status = flagged
        ? _amber
        : (_scanDark ? MirrorColors.accent : MirrorColors.successFg);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _glass(tint: heart),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: ScanArt(category: 'Vitals', color: heart, glow: false),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resting heart rate',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Last ${history.length + 1} readings · 180 days',
                      style: TextStyle(color: _inkMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'How the baseline works',
                onPressed: () => showScreenGateLifecycleSheet(context, 'S-C05'),
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: _inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latest.toStringAsFixed(0),
                style: TextStyle(
                  color: _ink,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  'bpm',
                  style: TextStyle(color: _inkMuted, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: status.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(MirrorRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          change >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 15,
                          color: status,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${change >= 0 ? "+" : ""}${change.toStringAsFixed(1)}% vs baseline',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: status,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: _TrendChartPainter(
                  values: [...history, latest],
                  baseline: base,
                  band: 2 * sd,
                  line: heart,
                  latestColor: status,
                  grid: _glassLine,
                  label: _inkMuted,
                  progress: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '180 days ago',
                style: TextStyle(color: _inkMuted, fontSize: 11),
              ),
              const Spacer(),
              Text(
                'Today',
                style: TextStyle(
                  color: _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 14,
                height: 8,
                decoration: BoxDecoration(
                  color: heart.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Normal for you: ${(base - math.max(2 * sd, 1.5)).toStringAsFixed(0)}–${(base + math.max(2 * sd, 1.5)).toStringAsFixed(0)} bpm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _inkMuted, fontSize: 11.5),
                ),
              ),
              Text(
                flagged ? 'Meaningful change' : 'Within your range',
                style: TextStyle(
                  color: status,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Tab 4: S-C07 profile, settings, appearance & developer tools — same
  /// theme-aware glass style as Scans and History.
  Widget _buildMoreAndArchitectureTab(BuildContext context, AppState appState) {
    _scanDark = Theme.of(context).brightness == Brightness.dark;
    final subj = appState.activeSubject;
    final dev = appState.deviceProfile;
    final top = MediaQuery.paddingOf(context).top;

    final consentsSigned = subj.consents.values.where((c) => c.isSigned).length;
    final consentsTotal = ConsentType.values.length;
    final deviceChecks = [
      dev.hasSpo2Calibration,
      dev.micSelfCheckPassed,
      dev.earphonesConnected,
      dev.phoneCharging,
      dev.fundusCameraConnected,
      dev.smartRingConnected,
    ];
    final devicesReady = deviceChecks.where((b) => b).length;
    final openCases = appState.cases.length;

    void push(Widget screen) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _scanDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _scanBg,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              left: -80,
              top: -60,
              child: _Glow(color: Color(0xFF4C5BD4), size: 300),
            ),
            const Positioned(
              right: -100,
              top: 160,
              child: _Glow(color: Color(0xFF14B8A6), size: 260),
            ),
            ListView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(600),
              padding: EdgeInsets.fromLTRB(16, top + 14, 16, 28),
              children: [
                Text(
                  'More',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your profile, family and settings',
                  style: TextStyle(color: _inkMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),

                FadeSlideIn(child: _profileHero(context, appState, push)),
                const SizedBox(height: 12),

                // Status tiles
                FadeSlideIn(
                  index: 1,
                  child: Row(
                    children: [
                      _statusTile(
                        key: const ValueKey('more_status_consent'),
                        icon: Icons.verified_user_rounded,
                        value: '$consentsSigned/$consentsTotal',
                        label: 'Consents',
                        ok: consentsSigned == consentsTotal,
                        onTap: () => push(const ConsentCenterScreen()),
                      ),
                      const SizedBox(width: 10),
                      _statusTile(
                        key: const ValueKey('more_status_devices'),
                        icon: Icons.sensors_rounded,
                        value: '$devicesReady/${deviceChecks.length}',
                        label: 'Devices ready',
                        ok: devicesReady == deviceChecks.length,
                        onTap: () =>
                            push(const DeviceReadinessAndHardwareScreen()),
                      ),
                      const SizedBox(width: 10),
                      _statusTile(
                        key: const ValueKey('more_status_cases'),
                        icon: Icons.folder_copy_rounded,
                        value: '$openCases',
                        label: 'Open cases',
                        ok: openCases == 0,
                        onTap: () => push(const CasesListScreen()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),

                // Account & privacy
                _darkSectionTitle('Account & privacy'),
                FadeSlideIn(
                  index: 2,
                  child: _settingsGroup([
                    _settingsRow(
                      icon: Icons.family_restroom_rounded,
                      color: const Color(0xFF4C5BD4),
                      title: 'Family members',
                      subtitle:
                          '${appState.subjects.length} profiles · add, edit or remove',
                      onTap: () => push(const ManageMembersScreen()),
                    ),
                    _settingsRow(
                      icon: Icons.monitor_weight_outlined,
                      color: const Color(0xFF0B7A75),
                      title: 'Profile & health',
                      subtitle: 'Height, weight and health conditions',
                      onTap: () => push(const ProfileAndHealthContextScreen()),
                    ),
                    _settingsRow(
                      icon: Icons.verified_user_outlined,
                      color: const Color(0xFF059669),
                      title: 'Consent',
                      subtitle: 'Screening, guardian and training consent',
                      badge: consentsSigned == consentsTotal
                          ? ('All signed', MirrorColors.successFg)
                          : (
                              '${consentsTotal - consentsSigned} to sign',
                              MirrorColors.warningFg,
                            ),
                      onTap: () => push(const ConsentCenterScreen()),
                    ),
                    _settingsRow(
                      icon: Icons.folder_copy_outlined,
                      color: const Color(0xFFDC2626),
                      title: 'Condition cases',
                      subtitle: 'Flagged results and lab follow-ups',
                      badge: openCases == 0
                          ? null
                          : ('$openCases open', MirrorColors.dangerFg),
                      onTap: () => push(const CasesListScreen()),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // Devices
                _darkSectionTitle('Devices'),
                FadeSlideIn(
                  index: 3,
                  child: _settingsGroup([
                    _settingsRow(
                      icon: Icons.devices_other_rounded,
                      color: const Color(0xFF0284C7),
                      title: 'Devices & sensors',
                      subtitle: dev.displayName,
                      badge: (
                        '$devicesReady of ${deviceChecks.length} ready',
                        devicesReady == deviceChecks.length
                            ? MirrorColors.successFg
                            : MirrorColors.warningFg,
                      ),
                      onTap: () =>
                          push(const DeviceReadinessAndHardwareScreen()),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // Operator
                _darkSectionTitle('Tools & insights'),
                FadeSlideIn(
                  index: 4,
                  child: _settingsGroup([
                    _settingsRow(
                      icon: Icons.badge_outlined,
                      color: const Color(0xFF7C3AED),
                      title: 'Operator mode',
                      subtitle: 'Register walk-ins and add reference readings',
                      onTap: () => push(const OperatorHomeScreen()),
                    ),
                    _settingsRow(
                      key: const ValueKey('more_trends'),
                      icon: Icons.insights_rounded,
                      color: const Color(0xFF0B7A75),
                      title: 'Trends',
                      subtitle: 'Track your scan results over time',
                      onTap: () => push(
                        TrendsScreen(
                          onNewScan: () {
                            Navigator.of(context).pop();
                            setState(() => _tabIndex = 2);
                          },
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // Appearance
                _darkSectionTitle('Appearance'),
                FadeSlideIn(index: 4, child: _themeSelector(appState)),
                const SizedBox(height: 24),

                // Developer tools
                FadeSlideIn(
                  index: 5,
                  child: Container(
                    decoration: _glass(),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        tilePadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                        iconColor: _inkMuted,
                        collapsedIconColor: _inkMuted,
                        leading: _settingsIcon(
                          Icons.developer_board_rounded,
                          const Color(0xFF64748B),
                        ),
                        title: Text(
                          'Developer tools',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Screen catalogue and spec test vectors',
                          style: TextStyle(color: _inkMuted, fontSize: 12),
                        ),
                        children: [
                          Divider(height: 1, color: _glassLine),
                          _settingsRow(
                            icon: Icons.account_tree_outlined,
                            color: const Color(0xFF7C3AED),
                            title: 'Screen catalogue',
                            subtitle: 'Every screen, its gates and lifecycle',
                            onTap: () =>
                                push(const ScreenArchitectureBrowserScreen()),
                          ),
                          Divider(indent: 66, height: 1, color: _glassLine),
                          _settingsRow(
                            icon: Icons.verified_rounded,
                            color: MirrorColors.successFg,
                            title: 'Spec test vectors',
                            subtitle:
                                'HRV, formulas, caries and risk-engine cases',
                            onTap: () =>
                                push(const SpecVectorsVerifierScreen()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Footer
                Column(
                  children: [
                    const BrandMark(size: 30),
                    const SizedBox(height: 8),
                    Text(
                      'VitalsMirror',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Screening only · not a medical diagnosis',
                      style: TextStyle(color: _inkMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact profile card: avatar with edit badge, key details, family row.
  Widget _profileHero(
    BuildContext context,
    AppState appState,
    void Function(Widget) push,
  ) {
    final subj = appState.activeSubject;
    final bmi = FormulasEngine.computeBmi(
      weightKg: subj.weightKg,
      heightCm: subj.heightCm,
    );
    final others = [
      for (var i = 0; i < appState.subjects.length; i++)
        if (i != appState.activeSubjectIndex) appState.subjects[i],
    ];
    final ring = _scanDark ? const Color(0xFF0A1226) : Colors.white;

    Widget fact(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(color: _inkMuted, fontSize: 11)),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: _glass(tint: _accent),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with gradient ring and edit badge
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: MirrorColors.brandGradient,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ring,
                        ),
                        child: MemberAvatar(name: subj.fullName, radius: 24),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: _accent,
                        shape: CircleBorder(
                          side: BorderSide(color: ring, width: 2),
                        ),
                        child: InkWell(
                          key: const ValueKey('more_edit_profile'),
                          customBorder: const CircleBorder(),
                          onTap: () => push(MemberFormScreen(member: subj)),
                          child: Tooltip(
                            message: 'Edit profile',
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: Icon(
                                Icons.edit_rounded,
                                size: 13,
                                color: _onNeon,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subj.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      memberSubtitle(subj),
                      style: TextStyle(color: _inkMuted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _heroPill(
                          subj.sex == BiologicalSex.female
                              ? Icons.female_rounded
                              : Icons.male_rounded,
                          subj.sex.label,
                        ),
                        if (appState.isAccountOwner(subj.id))
                          _heroPill(Icons.star_rounded, 'Account owner'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _scanDark
                  ? const Color(0x0DFFFFFF)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  fact(
                    subj.heightCm == null
                        ? '–'
                        : '${subj.heightCm!.toStringAsFixed(0)} cm',
                    'Height',
                  ),
                  VerticalDivider(width: 1, color: _glassLine),
                  fact(
                    subj.weightKg == null
                        ? '–'
                        : '${subj.weightKg!.toStringAsFixed(1)} kg',
                    'Weight',
                  ),
                  VerticalDivider(width: 1, color: _glassLine),
                  fact(bmi == null ? '–' : bmi.toStringAsFixed(1), 'BMI'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Family row (tap to switch)
          InkWell(
            key: const ValueKey('more_profile_card'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => showMemberSwitcher(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  if (others.isNotEmpty) ...[
                    SizedBox(
                      height: 26,
                      width: 26 + (others.take(4).length - 1) * 17.0,
                      child: Stack(
                        children: [
                          for (var i = 0; i < others.take(4).length; i++)
                            Positioned(
                              left: i * 17.0,
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ring,
                                ),
                                child: MemberAvatar(
                                  name: others[i].fullName,
                                  radius: 11.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      others.isEmpty
                          ? 'Add a family member'
                          : 'Switch to ${others.length} family ${others.length == 1 ? "member" : "members"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: _accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(MirrorRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _accent),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: _accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusTile({
    Key? key,
    required IconData icon,
    required String value,
    required String label,
    required bool ok,
    required VoidCallback onTap,
  }) {
    final color = ok
        ? (_scanDark ? MirrorColors.accent : MirrorColors.successFg)
        : _amber;
    return Expanded(
      child: Pressable(
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: _glass(radius: 18),
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: color),
                        const Spacer(),
                        Icon(
                          ok
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          size: 14,
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _inkMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsIcon(IconData icon, Color color) {
    final c = _scanDark ? Color.lerp(color, Colors.white, 0.3)! : color;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: c),
    );
  }

  Widget _settingsGroup(List<Widget> rows) {
    return Container(
      decoration: _glass(),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(indent: 66, height: 1, color: _glassLine),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _settingsRow({
    Key? key,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    (String, Color)? badge,
    Widget? trailing,
  }) {
    final badgeColor = badge == null
        ? null
        : (_scanDark ? Color.lerp(badge.$2, Colors.white, 0.35)! : badge.$2);
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
        child: Row(
          children: [
            _settingsIcon(icon, color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _inkMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor!.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(MirrorRadius.pill),
                ),
                child: Text(
                  badge.$1,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            trailing ?? Icon(Icons.chevron_right_rounded, color: _inkMuted),
          ],
        ),
      ),
    );
  }

  /// Light / Dark segmented choice with live mini previews.
  Widget _themeSelector(AppState appState) {
    final isDark = appState.themeMode == ThemeMode.dark;
    Widget option(String label, bool dark) {
      final selected = isDark == dark;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('theme_${label.toLowerCase()}'),
          onTap: () {
            if (!selected) {
              HapticFeedback.selectionClick();
              appState.toggleThemeMode();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _glassFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _accent : _glassLine,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                // Mini phone preview
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF0D1117)
                        : const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: dark
                          ? const Color(0xFF2D3642)
                          : const Color(0xFFDCE3EA),
                    ),
                  ),
                  padding: const EdgeInsets.all(7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dark
                              ? Colors.white70
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Expanded(
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: dark
                                      ? const Color(0xFF161B22)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: dark
                                        ? const Color(0xFF2D3642)
                                        : const Color(0xFFDCE3EA),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 16,
                      color: selected ? _accent : _inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

    return Row(
      children: [
        option('Light', false),
        const SizedBox(width: 10),
        option('Dark', true),
      ],
    );
  }
}

/// Guided multi-scan package detail & step-by-step runner.
/// Lets the user inspect all scans, biomarkers, and required permissions in a
/// health check package and launch each step with voice-coach support.
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
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final pkg = widget.package;
    final steps = pkg.includedCatalogueIds
        .map(
          (id) => VitalsMirrorCatalogRegistry.catalogueItems
              .where((c) => c.id == id)
              .firstOrNull,
        )
        .whereType<ScreeningCatalogueItem>()
        .toList();
    final nextIndex = steps.indexWhere(
      (s) => !_completedStepIds.contains(s.id),
    );
    final nextStep = nextIndex >= 0 ? steps[nextIndex] : steps.firstOrNull;
    final doneCount = _completedStepIds.length.clamp(0, steps.length);
    final progress = steps.isEmpty ? 0.0 : doneCount / steps.length;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 256,
            backgroundColor: pkg.gradientColors.last,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: const Border(),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: LayoutBuilder(
              builder: (context, c) {
                final collapsed = c.maxHeight <= kToolbarHeight + topInset + 24;
                return FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 56,
                    bottom: 16,
                    end: 16,
                  ),
                  title: AnimatedOpacity(
                    opacity: collapsed ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      pkg.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  background: PackageCover(package: pkg),
                );
              },
            ),
          ),
          SliverPadding(
            padding: MirrorSpace.screen.copyWith(top: MirrorSpace.lg),
            sliver: SliverList.list(
              children: [
                // Progress
                FadeSlideIn(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 4,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: t.labelMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doneCount == steps.length && steps.isNotEmpty
                                      ? 'All steps done'
                                      : 'Your progress',
                                  style: t.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$doneCount of ${steps.length} scans completed · ${pkg.totalDurationLabel} total',
                                  style: t.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MirrorSpace.xl),

                // Steps timeline
                const SectionHeader(
                  title: 'Guided steps',
                  subtitle: 'Do them in order · the coach guides each one',
                ),
                for (var i = 0; i < steps.length; i++)
                  FadeSlideIn(
                    index: i + 1,
                    child: _stepTile(
                      context,
                      steps[i],
                      i,
                      isLast: i == steps.length - 1,
                      isNext: i == nextIndex,
                    ),
                  ),
                const SizedBox(height: MirrorSpace.xl),

                // What you'll need
                if (pkg.permissionsNeeded.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'What you\'ll need',
                    subtitle: 'Checked automatically before each scan',
                  ),
                  MirrorGroupCard(
                    children: [
                      for (final perm in pkg.permissionsNeeded)
                        ListTile(
                          leading: IconBadge(icon: perm.icon, size: 34),
                          title: Text(
                            perm.title.split('(').first.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            perm.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: perm.isMandatory
                              ? null
                              : const MirrorPill(label: 'Optional'),
                        ),
                    ],
                  ),
                  const SizedBox(height: MirrorSpace.xl),
                ],

                // What it covers
                SectionHeader(
                  title: 'What it covers',
                  subtitle:
                      '${pkg.biomarkersCovered.length} biomarkers and clinical outputs',
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final colW = (c.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            for (final b in pkg.biomarkersCovered)
                              SizedBox(
                                width: colW,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        size: 15,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        b.split(' (').first,
                                        style: t.bodySmall?.copyWith(
                                          color: scheme.onSurface,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: PrimaryBottomButton(
        label: nextStep == null
            ? 'No steps'
            : nextIndex >= 0
            ? 'Start step ${nextIndex + 1}: ${nextStep.title}'
            : 'All steps done · Restart',
        icon: Icons.play_arrow_rounded,
        onPressed: nextStep == null
            ? null
            : () => _launchPackageStep(context, nextStep),
      ),
    );
  }

  Widget _stepTile(
    BuildContext context,
    ScreeningCatalogueItem step,
    int index, {
    required bool isLast,
    required bool isNext,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final done = _completedStepIds.contains(step.id);
    final dotColor = done
        ? MirrorColors.successFg
        : isNext
        ? scheme.primary
        : scheme.outline;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 42,
            bottom: isLast ? 0 : MirrorSpace.md,
          ),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MirrorRadius.lg),
              side: BorderSide(
                color: isNext ? scheme.primary : scheme.outline,
                width: isNext ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isNext)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  'UP NEXT',
                                  style: t.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            Text(step.title, style: t.titleSmall),
                            const SizedBox(height: 4),
                            Text(
                              step.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      done
                          ? OutlinedButton(
                              onPressed: () =>
                                  _launchPackageStep(context, step),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                textStyle: t.labelLarge,
                              ),
                              child: const Text('Redo'),
                            )
                          : FilledButton.tonal(
                              onPressed: () =>
                                  _launchPackageStep(context, step),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                textStyle: t.labelLarge,
                              ),
                              child: const Text('Start'),
                            ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      MirrorPill(
                        label: step.durationLabel,
                        icon: Icons.schedule_rounded,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: MirrorPill(
                          label: step.hardwareNeeded,
                          icon: Icons.sensors_rounded,
                          filled: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Timeline rail
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 32,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: done || isNext ? dotColor : scheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
                alignment: Alignment.center,
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isNext
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: done
                          ? MirrorColors.successFg.withValues(alpha: 0.5)
                          : scheme.outline,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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

/// Large, soft radial colour glow used behind the immersive Scans screen.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// One saved result shown in "Recently done" and the History timeline.
typedef _HistoryEntry = ({
  String kind,
  String title,
  String category,
  SemanticBand band,
  DateTime at,
  VoidCallback onView,
  String? redoId,
});

/// Smooth line chart of personal readings over a baseline band.
class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({
    required this.values,
    required this.baseline,
    required this.band,
    required this.line,
    required this.latestColor,
    required this.grid,
    required this.label,
    required this.progress,
  });

  final List<double> values;
  final double baseline;

  /// Half-height of the "normal for you" band (e.g. 2 × SD).
  final double band;
  final Color line;
  final Color latestColor;
  final Color grid;
  final Color label;

  /// 0..1 draw-in animation.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const padTop = 10.0;
    const padBottom = 6.0;
    const padRight = 10.0;
    final w = size.width - padRight;
    final h = size.height - padTop - padBottom;
    final minV = [...values, baseline - band].reduce(math.min) - 4;
    final maxV = [...values, baseline + band].reduce(math.max) + 4;
    double y(double v) => padTop + h * (1 - (v - minV) / (maxV - minV));
    double x(int i) => w * i / (values.length - 1);

    // Normal-range band + baseline.
    final bandHalf = math.max(band, 1.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, y(baseline + bandHalf), w, y(baseline - bandHalf)),
        const Radius.circular(6),
      ),
      Paint()..color = line.withValues(alpha: 0.12),
    );
    final dash = Paint()
      ..color = line.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    for (var dx = 0.0; dx < w; dx += 8) {
      canvas.drawLine(
        Offset(dx, y(baseline)),
        Offset(math.min(dx + 4, w), y(baseline)),
        dash,
      );
    }

    // Smooth path through the points.
    final pts = [
      for (var i = 0; i < values.length; i++) Offset(x(i), y(values[i])),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    // Gradient fill under the line.
    final fill = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.28), line.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    // Glow + line.
    canvas.drawPath(
      path,
      Paint()
        ..color = line.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    // Earlier points.
    for (final p in pts.take(pts.length - 1)) {
      canvas.drawCircle(p, 2.4, Paint()..color = line);
    }
    canvas.restore();

    // Latest point pops in at the end.
    if (progress > 0.95) {
      final last = pts.last;
      canvas.drawCircle(
        last,
        10,
        Paint()..color = latestColor.withValues(alpha: 0.25),
      );
      canvas.drawCircle(last, 5.5, Paint()..color = latestColor);
      canvas.drawCircle(last, 2.2, Paint()..color = Colors.white);

      // Value bubble to the left of the latest point.
      final tp = TextPainter(
        text: TextSpan(
          text: values.last.toStringAsFixed(0),
          style: const TextStyle(
            fontFamily: MirrorTheme.fontFamily,
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bubble = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(last.dx - tp.width / 2 - 18, last.dy),
          width: tp.width + 12,
          height: tp.height + 6,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(bubble, Paint()..color = latestColor);
      tp.paint(canvas, Offset(bubble.left + 6, bubble.top + 3));
    }
  }

  @override
  bool shouldRepaint(_TrendChartPainter old) =>
      old.progress != progress ||
      old.values != values ||
      old.line != line ||
      old.latestColor != latestColor;
}
