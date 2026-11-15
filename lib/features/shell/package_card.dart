import 'package:flutter/material.dart';

import '../../core/design_system/mirror_motion.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_ui.dart';
import '../../core/domain/entities/health_package.dart';

/// Gradient rounded-square icon used as the visual identity of a package.
class PackageIconTile extends StatelessWidget {
  const PackageIconTile({super.key, required this.package, this.size = 44});

  final HealthScanPackage package;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: package.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: package.gradientColors.first.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(package.icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// Small "icon + text" meta item, e.g. ⏱ 90 sec.
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: muted),
        ),
      ],
    );
  }
}

/// Compact card for the Home "Health packages" carousel.
class PackageMiniCard extends StatelessWidget {
  const PackageMiniCard({
    super.key,
    required this.package,
    required this.onOpen,
    this.width = 232,
  });

  final HealthScanPackage package;
  final VoidCallback onOpen;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = package;
    return SizedBox(
      width: width,
      child: Pressable(
        child: Card(
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PackageIconTile(package: p, size: 38),
                      const Spacer(),
                      MirrorPill(
                        label: p.totalDurationLabel,
                        icon: Icons.schedule_rounded,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Meta(
                        icon: Icons.layers_outlined,
                        text: '${p.includedCatalogueIds.length} scans',
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large "Most popular" showcase card at the top of the Packs tab.
class PackageHeroCard extends StatelessWidget {
  const PackageHeroCard({
    super.key,
    required this.package,
    required this.onOpen,
    this.badge = 'MOST POPULAR',
  });

  final HealthScanPackage package;
  final VoidCallback onOpen;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final p = package;
    final accentText = p.gradientColors.last;
    return Pressable(
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: p.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: onOpen,
            child: Stack(
              children: [
                // Decorative rings + big icon
                Positioned(
                  right: -40,
                  top: -40,
                  child: _Ring(size: 170, opacity: 0.08),
                ),
                Positioned(
                  right: 30,
                  bottom: -60,
                  child: _Ring(size: 130, opacity: 0.06),
                ),
                Positioned(
                  right: 16,
                  top: 48,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(p.icon, color: Colors.white, size: 30),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: BorderRadius.circular(
                                MirrorRadius.pill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Color(0xFF422006),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  badge,
                                  style: const TextStyle(
                                    color: Color(0xFF422006),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          MirrorPill(
                            label: p.totalDurationLabel,
                            icon: Icons.schedule_rounded,
                            onDark: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.only(right: 76),
                        child: Text(
                          p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(right: 76),
                        child: Text(
                          p.recommendedFor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _HeroStat(
                            value: '${p.includedCatalogueIds.length}',
                            label: 'scans',
                          ),
                          _HeroDivider(),
                          _HeroStat(
                            value: '${p.biomarkersCovered.length}',
                            label: 'markers',
                          ),
                          _HeroDivider(),
                          _HeroStat(
                            value: '${p.permissionsNeeded.length}',
                            label: 'checks',
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                MirrorRadius.pill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                  color: accentText,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Start pack',
                                  style: TextStyle(
                                    color: accentText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity),
          width: 18,
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white24,
    );
  }
}

/// Rich list card: colour banner, overlapping icon badge, details and a
/// row of the scans included in the pack.
class PackageShowcaseCard extends StatelessWidget {
  const PackageShowcaseCard({
    super.key,
    required this.package,
    required this.scanIcons,
    required this.onOpen,
  });

  final HealthScanPackage package;

  /// One icon per included scan, in order.
  final List<IconData> scanIcons;
  final VoidCallback onOpen;

  static const double _banner = 60;
  static const double _badge = 48;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final p = package;
    final tint = p.gradientColors.first;
    final shown = scanIcons.take(5).toList();
    final more = scanIcons.length - shown.length;

    return Pressable(
      child: Card(
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner with overlapping badge
              SizedBox(
                height: _banner + _badge / 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: _banner,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: p.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -16,
                            top: -22,
                            child: _Ring(size: 96, opacity: 0.10),
                          ),
                          Positioned(
                            right: 70,
                            bottom: -34,
                            child: _Ring(size: 70, opacity: 0.07),
                          ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: MirrorPill(
                              label: p.totalDurationLabel,
                              icon: Icons.schedule_rounded,
                              onDark: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: _banner - _badge / 2,
                      child: Container(
                        width: _badge,
                        height: _badge,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: p.gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(p.icon, color: Colors.white, size: 21),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.tagline.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Overlapping scan-icon avatars
                        SizedBox(
                          height: 30,
                          width: shown.isEmpty
                              ? 0
                              : 30 + (shown.length - 1) * 22.0,
                          child: Stack(
                            children: [
                              for (var i = 0; i < shown.length; i++)
                                Positioned(
                                  left: i * 22.0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Color.alphaBlend(
                                        tint.withValues(alpha: 0.12),
                                        scheme.surface,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: scheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      shown[i],
                                      size: 14,
                                      color:
                                          scheme.brightness == Brightness.dark
                                          ? Colors.white70
                                          : tint,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (more > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '+$more',
                            style: t.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${p.includedCatalogueIds.length} scans · ${p.biomarkersCovered.length} markers',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: scheme.onPrimary,
                          ),
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
    );
  }
}

/// Expanded cover for the pack detail screen (sits behind the SliverAppBar).
class PackageCover extends StatelessWidget {
  const PackageCover({super.key, required this.package});

  final HealthScanPackage package;

  @override
  Widget build(BuildContext context) {
    final p = package;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: p.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -50,
            top: -30,
            child: _Ring(size: 200, opacity: 0.08),
          ),
          const Positioned(
            left: -40,
            bottom: -70,
            child: _Ring(size: 150, opacity: 0.06),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, top, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(p.icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.tagline.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  p.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'For ${p.recommendedFor.toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      _HeroStat(value: p.totalDurationLabel, label: 'total'),
                      _HeroDivider(),
                      _HeroStat(
                        value: '${p.includedCatalogueIds.length}',
                        label: 'scans',
                      ),
                      _HeroDivider(),
                      _HeroStat(
                        value: '${p.biomarkersCovered.length}',
                        label: 'markers',
                      ),
                      _HeroDivider(),
                      _HeroStat(
                        value: '${p.permissionsNeeded.length}',
                        label: 'checks',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
