import 'package:flutter/material.dart';

import 'mirror_theme.dart';

/// Shared, theme-aware building blocks for every non-scanning screen.
/// All sizes come from [MirrorSpace] / [MirrorRadius] and the app TextTheme,
/// so light and dark mode stay consistent.

/// Section title + optional caption + optional trailing text action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: 10),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: t.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Large page heading used at the top of a tab body.
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MirrorSpace.md + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: t.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: MirrorSpace.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Small rounded label (duration, badge, sensor, biomarker...).
class MirrorPill extends StatelessWidget {
  const MirrorPill({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.onDark = false,
    this.filled = true,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  /// Translucent white pill for use on gradient / dark hero cards.
  final bool onDark;

  /// When false, uses a neutral surface-variant background with a coloured icon.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    final Color fg;
    final Color bg;
    if (onDark) {
      fg = Colors.white;
      bg = Colors.white.withValues(alpha: 0.18);
    } else if (filled) {
      fg = c;
      bg = c.withValues(alpha: 0.12);
    } else {
      fg = scheme.onSurfaceVariant;
      bg = scheme.surfaceContainerHighest;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MirrorRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: filled || onDark ? fg : c),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft tinted square holding an icon.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 36,
    this.circle = false,
  });

  final IconData icon;
  final Color? color;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: c, size: size * 0.5),
    );
  }
}

/// A card holding a vertical group of rows (usually ListTiles) separated by
/// inset dividers — the classic settings-list look.
class MirrorGroupCard extends StatelessWidget {
  const MirrorGroupCard({
    super.key,
    required this.children,
    this.dividerIndent = 62,
  });

  final List<Widget> children;

  /// Left inset of the dividers; use 16 for rows without a leading icon.
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(Divider(indent: dividerIndent, height: 1));
      }
    }
    return Card(child: Column(children: items));
  }
}

/// Uniform navigation row: icon badge, title, subtitle, chevron / trailing.
class MirrorNavTile extends StatelessWidget {
  const MirrorNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MirrorSpace.lg,
        vertical: 0,
      ),
      leading: IconBadge(icon: icon, color: color, size: 34),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      onTap: onTap,
    );
  }
}

/// Friendly placeholder for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MirrorSpace.xxl,
          vertical: MirrorSpace.xxxl,
        ),
        child: Column(
          children: [
            IconBadge(icon: icon, size: 48, circle: true),
            const SizedBox(height: MirrorSpace.md),
            Text(title, style: t.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: MirrorSpace.xs),
              Text(message!, style: t.bodySmall, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// Brand logo mark (gradient rounded square with heart-monitor glyph).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: MirrorColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.monitor_heart_rounded,
        color: Colors.white,
        size: size * 0.58,
      ),
    );
  }
}

/// Full-width Material 3 dropdown styled like the app's text fields.
class MirrorDropdownField<T> extends StatelessWidget {
  const MirrorDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
    this.itemIcon,
    this.errorText,
  });

  final String label;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final IconData Function(T)? itemIcon;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => DropdownMenu<T>(
        width: constraints.maxWidth,
        initialSelection: value,
        label: Text(label),
        errorText: errorText,
        leadingIcon: icon == null ? null : Icon(icon, size: 20),
        trailingIcon: const Icon(Icons.expand_more_rounded),
        selectedTrailingIcon: const Icon(Icons.expand_less_rounded),
        menuHeight: 320,
        requestFocusOnTap: false,
        onSelected: onChanged,
        dropdownMenuEntries: [
          for (final (v, text) in items)
            DropdownMenuEntry<T>(
              value: v,
              label: text,
              leadingIcon: itemIcon == null
                  ? null
                  : Icon(itemIcon!(v), size: 18),
            ),
        ],
      ),
    );
  }
}

/// Circular initial avatar with a stable colour per name.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.name, this.radius = 18});

  final String name;
  final double radius;

  static const _palette = [
    Color(0xFF0B7A75),
    Color(0xFF4C5BD4),
    Color(0xFFDB2777),
    Color(0xFFD97706),
    Color(0xFF0284C7),
    Color(0xFF7C3AED),
    Color(0xFF059669),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((p) => p[0].toUpperCase()).join();
    final color =
        _palette[trimmed.codeUnits.fold<int>(0, (a, b) => a + b) %
            _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundColor: Colors.white,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
