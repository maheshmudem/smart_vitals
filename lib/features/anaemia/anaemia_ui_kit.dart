import 'package:flutter/material.dart';

import '../../core/design_system/mirror_theme.dart';

/// Light-theme building blocks shared by the anaemia intro, stepper and
/// result screens (same visual language as the vitals report, S-D07).
class AnaemiaUi {
  AnaemiaUi._();

  static const Color ink = MirrorColors.inkLight;
  static const Color muted = MirrorColors.inkMutedLight;
  static const Color outline = MirrorColors.outlineLight;
  static const Color surface = MirrorColors.surfaceLight;
  static const Color primary = MirrorColors.primary;
  static const Color accent = Color(0xFFE11D48);
  static const Color conjunctivaPink = Color(0xFFF08A9B);
  static const Color conjunctivaPale = Color(0xFFF9DCE0);

  static const Color segHigh = Color(0xFFFCA5A5);
  static const Color segBorder = Color(0xFFFCD34D);
  static const Color segNormal = Color(0xFF6EE7B7);

  static BoxDecoration card({Color color = surface, Color? border}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(MirrorRadius.lg),
      border: Border.all(color: border ?? outline),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static Widget sectionHeader(String title, String caption) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(color: muted, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  static Widget iconTile(IconData icon, Color color, {double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }

  static Widget kvRow(String key, String value, {double keyWidth = 124}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: keyWidth,
            child: Text(
              key,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget bullet(
    String text, {
    IconData icon = Icons.check_circle_rounded,
    Color color = primary,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: ink, fontSize: 13, height: 1.42),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  static Widget numberedStep(
    int n,
    String title,
    String body, {
    Widget? leading,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading ??
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$n',
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w800,
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
                    color: ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
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

  static Widget tag(String text, {Color color = primary, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card surface backed by a `Material` so ListTiles / Checkbox / Switch
/// tiles inside it paint their ink correctly (same look as [AnaemiaUi.card]).
class MaterialCard extends StatelessWidget {
  const MaterialCard({
    super.key,
    required this.child,
    this.padding,
    this.color = AnaemiaUi.surface,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MirrorRadius.lg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: color,
        clipBehavior: clipBehavior,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MirrorRadius.lg),
          side: const BorderSide(color: AnaemiaUi.outline),
        ),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// Tinted note box (info / warning / success / danger).
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color = MirrorColors.infoFg,
    this.background = MirrorColors.infoBg,
    this.title,
  });

  final String text;
  final String? title;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      title!,
                      style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                Text(
                  text,
                  style: TextStyle(color: color, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reference gauge: `breakpoints` has one more entry than `labels` / `colors`.
class RangeScale {
  const RangeScale({
    required this.breakpoints,
    required this.labels,
    required this.colors,
  });

  final List<double> breakpoints;
  final List<String> labels;
  final List<Color> colors;

  double positionFor(double value) {
    final segments = labels.length;
    if (value <= breakpoints.first) return 0.0;
    if (value >= breakpoints.last) return 1.0;
    for (var i = 0; i < segments; i++) {
      final lo = breakpoints[i];
      final hi = breakpoints[i + 1];
      if (value <= hi) {
        final frac = hi > lo ? (value - lo) / (hi - lo) : 0.0;
        return (i + frac) / segments;
      }
    }
    return 1.0;
  }
}

class RangeGauge extends StatelessWidget {
  const RangeGauge({
    super.key,
    required this.scale,
    required this.value,
    required this.pinColor,
    this.showPin = true,
  });

  final RangeScale scale;
  final double value;
  final Color pinColor;
  final bool showPin;

  @override
  Widget build(BuildContext context) {
    final position = scale.positionFor(value);
    return Column(
      children: [
        SizedBox(
          height: 18,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  for (var i = 0; i < scale.colors.length; i++)
                    Expanded(
                      child: Container(
                        height: 8,
                        margin: EdgeInsets.only(
                          right: i == scale.colors.length - 1 ? 0 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: scale.colors[i],
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(i == 0 ? 99 : 2),
                            right: Radius.circular(
                              i == scale.colors.length - 1 ? 99 : 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (showPin)
                Align(
                  alignment: Alignment(
                    (position.clamp(0.02, 0.98) * 2) - 1.0,
                    0,
                  ),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: pinColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: pinColor.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final lbl in scale.labels)
              Expanded(
                child: Text(
                  lbl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AnaemiaUi.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Horizontal step indicator: dots joined by lines, done = check, current = filled.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AnaemiaUi.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i < current
                          ? AnaemiaUi.primary
                          : i == current
                          ? AnaemiaUi.primary.withValues(alpha: 0.14)
                          : AnaemiaUi.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i <= current
                            ? AnaemiaUi.primary
                            : AnaemiaUi.outline,
                        width: i == current ? 2 : 1.2,
                      ),
                    ),
                    child: i < current
                        ? const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Colors.white,
                          )
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i == current
                                  ? AnaemiaUi.primary
                                  : AnaemiaUi.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: i == current
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: i == current ? AnaemiaUi.ink : AnaemiaUi.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (i != labels.length - 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  width: 14,
                  height: 2,
                  color: i < current ? AnaemiaUi.primary : AnaemiaUi.outline,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Full-width bottom action bar used under every step.
class PrimaryBottomButton extends StatelessWidget {
  const PrimaryBottomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.helper,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? helper;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AnaemiaUi.surface,
        border: Border(top: BorderSide(color: AnaemiaUi.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (helper != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    helper!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AnaemiaUi.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              Row(
                children: [
                  if (secondaryLabel != null) ...[
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        child: Text(
                          secondaryLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: MirrorSpace.md),
                  ],
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: onPressed,
                      icon: Icon(icon, size: 20),
                      label: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
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
}
