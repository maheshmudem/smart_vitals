import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/mirror_motion.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_ui.dart';

/// Building blocks for the Home dashboard (health-dashboard style).

String greetingForNow([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// One compact stat shown on the glass row inside the header.
class HeaderStat {
  const HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;
}

/// Full-bleed gradient header: brand row, greeting, health-score card and
/// a row of glass stat chips.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.firstName,
    required this.fullName,
    required this.score,
    required this.scoreCaption,
    required this.stats,
    required this.alertCount,
    required this.onAlerts,
    required this.onSwitchMember,
  });

  final String firstName;
  final String fullName;

  /// 0–100, or null when there is no scan yet.
  final int? score;
  final String scoreCaption;
  final List<HeaderStat> stats;
  final int alertCount;
  final VoidCallback onAlerts;
  final VoidCallback onSwitchMember;

  static String scoreLabel(int score) => score >= 80
      ? 'Good'
      : score >= 60
      ? 'Fair'
      : 'Needs care';

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, top + 8, 16, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07263A), Color(0xFF0B5F63), Color(0xFF0B7A75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand + actions
            Row(
              children: [
                const BrandMark(size: 24),
                const SizedBox(width: 8),
                const Text(
                  'VitalsMirror',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                _AlertBell(count: alertCount, onTap: onAlerts),
                const SizedBox(width: 6),
                _GlassMemberPill(
                  fullName: fullName,
                  firstName: firstName,
                  onTap: onSwitchMember,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Greeting
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [...previous, ?current],
              ),
              child: Column(
                key: ValueKey(fullName),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${greetingForNow()},',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Health score glass card
            _Glass(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ScoreRing(score: score),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Health score',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          score == null
                              ? 'No scan yet'
                              : scoreLabel(score!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scoreCaption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(child: _GlassStat(stat: stats[i])),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

class _GlassStat extends StatelessWidget {
  const _GlassStat({required this.stat});

  final HeaderStat stat;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          Icon(stat.icon, size: 14, color: MirrorColors.accent),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertBell extends StatelessWidget {
  const _AlertBell({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('home_alerts'),
      tooltip: count == 0 ? 'No open cases' : '$count open cases',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        minimumSize: const Size(34, 34),
        fixedSize: const Size(34, 34),
        padding: EdgeInsets.zero,
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: const Color(0xFFEF4444),
        child: const Icon(Icons.notifications_none_rounded, size: 19),
      ),
    );
  }
}

class _GlassMemberPill extends StatelessWidget {
  const _GlassMemberPill({
    required this.fullName,
    required this.firstName,
    required this.onTap,
  });

  final String fullName;
  final String firstName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('member_switcher_pill'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(3, 3, 6, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberAvatar(name: fullName, radius: 13),
              const Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated white progress ring with the score in the middle.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 54});

  final int? score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final target = (score ?? 0) / 100;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: score == null ? 0 : v,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation(MirrorColors.accent),
              ),
            ),
            Text(
              score == null ? '–' : '${(v * 100).round()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round category shortcut ("Vitals", "Eyes", ...).
class CategoryShortcut extends StatelessWidget {
  const CategoryShortcut({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 58,
      child: Pressable(
        child: InkWell(
          borderRadius: BorderRadius.circular(MirrorRadius.md),
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: t.labelMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One slide of the featured carousel.
class FeaturedScan {
  const FeaturedScan({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.icon,
    required this.colors,
    required this.onStart,
  });

  final String title;
  final String subtitle;
  final String duration;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onStart;
}

/// Swipeable featured-scan carousel with animated page dots.
class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({super.key, required this.items, this.height = 128});

  final List<FeaturedScan> items;
  final double height;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 16 : 6,
                right: i == widget.items.length - 1 ? 16 : 6,
              ),
              child: _FeaturedCard(item: widget.items[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 16 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: i == _page
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item});

  final FeaturedScan item;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: item.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: item.onStart,
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  bottom: -22,
                  child: Icon(
                    item.icon,
                    size: 104,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              item.icon,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                          const Spacer(),
                          MirrorPill(
                            label: item.duration,
                            icon: Icons.schedule_rounded,
                            onDark: true,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
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
                                  size: 15,
                                  color: item.colors.last,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Start',
                                  style: TextStyle(
                                    color: item.colors.last,
                                    fontSize: 12,
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
