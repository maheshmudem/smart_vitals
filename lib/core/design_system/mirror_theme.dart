import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../domain/entities/enums.dart';

class MirrorColors {
  static const Color primary = Color(0xFF0B7A75);
  static const Color primaryContainer = Color(0xFFD7F2EF);
  static const Color secondary = Color(0xFF4C5BD4);
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFEEF2F6);
  static const Color inkLight = Color(0xFF0F172A);
  static const Color inkMutedLight = Color(0xFF5B6B7F);
  static const Color outlineLight = Color(0xFFDCE3EA);

  // Semantic tokens from Docs/05_UI_UX_Screen_Documentation.md & Docs/08
  static const Color successFg = Color(0xFF15803D);
  static const Color successBg = Color(0xFFDCFCE7);

  static const Color warningFg = Color(0xFFB45309);
  static const Color warningBg = Color(0xFFFEF3C7);

  static const Color dangerFg = Color(0xFFB91C1C);
  static const Color dangerBg = Color(0xFFFEE2E2);

  static const Color emergencySolid = Color(0xFFB91C1C);

  static const Color infoFg = Color(0xFF1D4ED8);
  static const Color infoBg = Color(0xFFDBEAFE);

  static const Color neutralFg = Color(0xFF475569);
  static const Color neutralBg = Color(0xFFE2E8F0);

  /// Bright teal accent used on hero cards.
  static const Color accent = Color(0xFF00E5CC);

  /// Deep navy to brand teal hero gradient.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF092032), Color(0xFF0B7A75)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Brand logo-mark gradient.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF0B7A75), Color(0xFF00E5CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark theme surfaces.
  static const Color backgroundDark = Color(0xFF0D1117);
  static const Color surfaceDark = Color(0xFF161B22);
  static const Color surfaceVariantDark = Color(0xFF1F2630);
  static const Color outlineDark = Color(0xFF2D3642);
}

/// 4-pt spacing scale. Screen gutter and card padding = [lg].
class MirrorSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Standard scroll-view padding for every non-scanning screen.
  static const EdgeInsets screen = EdgeInsets.fromLTRB(16, 8, 16, 24);
}

class MirrorRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 24;
  static const double pill = 999;
}

class BandVisualStyle {
  const BandVisualStyle({
    required this.foreground,
    required this.background,
    required this.icon,
    required this.label,
  });

  final Color foreground;
  final Color background;
  final IconData icon;
  final String label;

  static BandVisualStyle forBand(SemanticBand band) {
    switch (band) {
      case SemanticBand.normal:
      case SemanticBand.low:
      case SemanticBand.regular:
        return BandVisualStyle(
          foreground: MirrorColors.successFg,
          background: MirrorColors.successBg,
          icon: Icons.check_circle_rounded,
          label: band.label,
        );
      case SemanticBand.borderline:
      case SemanticBand.elevated:
      case SemanticBand.moderate:
      case SemanticBand.mild:
      case SemanticBand.prediabetesRisk:
      case SemanticBand.atRisk:
      case SemanticBand.suspicious:
        return BandVisualStyle(
          foreground: MirrorColors.warningFg,
          background: MirrorColors.warningBg,
          icon: Icons.warning_amber_rounded,
          label: band.label,
        );
      case SemanticBand.critical:
      case SemanticBand.high:
      case SemanticBand.diabetesRisk:
      case SemanticBand.irregular:
      case SemanticBand.ulcer:
      case SemanticBand.severe:
      case SemanticBand.refer:
        return BandVisualStyle(
          foreground: MirrorColors.dangerFg,
          background: MirrorColors.dangerBg,
          icon: Icons.error_outline_rounded,
          label: band.label,
        );
      case SemanticBand.emergency:
        return BandVisualStyle(
          foreground: Colors.white,
          background: MirrorColors.emergencySolid,
          icon: Icons.emergency_rounded,
          label: band.label,
        );
      case SemanticBand.inValidation:
      case SemanticBand.rangeNotAvailable:
      case SemanticBand.needsConfirmation:
        return BandVisualStyle(
          foreground: MirrorColors.infoFg,
          background: MirrorColors.infoBg,
          icon: Icons.info_outline_rounded,
          label: band.label,
        );
      case SemanticBand.notAssessed:
      case SemanticBand.notAvailable:
      case SemanticBand.hidden:
        return BandVisualStyle(
          foreground: MirrorColors.neutralFg,
          background: MirrorColors.neutralBg,
          icon: Icons.remove_circle_outline_rounded,
          label: band.label,
        );
    }
  }
}

class MirrorTheme {
  static const String fontFamily = 'Roboto';

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: MirrorColors.primary,
          primary: MirrorColors.primary,
          secondary: MirrorColors.secondary,
          surface: MirrorColors.surfaceLight,
          error: MirrorColors.dangerFg,
          brightness: Brightness.light,
        ).copyWith(
          onSurface: MirrorColors.inkLight,
          onSurfaceVariant: MirrorColors.inkMutedLight,
          outline: MirrorColors.outlineLight,
          outlineVariant: MirrorColors.outlineLight,
          surfaceContainerHighest: MirrorColors.surfaceVariantLight,
          surfaceContainerHigh: const Color(0xFFF1F4F8),
          surfaceContainer: const Color(0xFFF5F7FA),
          surfaceContainerLow: const Color(0xFFF8FAFC),
          primaryContainer: MirrorColors.primaryContainer,
          onPrimaryContainer: const Color(0xFF064E4A),
        );
    return _build(
      scheme,
      background: MirrorColors.backgroundLight,
      surface: MirrorColors.surfaceLight,
      surfaceVariant: MirrorColors.surfaceVariantLight,
      outline: MirrorColors.outlineLight,
    );
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF4FD1C5),
          primary: const Color(0xFF4FD1C5),
          secondary: const Color(0xFFA5B0FF),
          surface: MirrorColors.surfaceDark,
          brightness: Brightness.dark,
        ).copyWith(
          onSurface: const Color(0xFFE6EDF3),
          onSurfaceVariant: const Color(0xFF9BA7B4),
          outline: MirrorColors.outlineDark,
          outlineVariant: MirrorColors.outlineDark,
          surfaceContainerHighest: MirrorColors.surfaceVariantDark,
          surfaceContainerHigh: const Color(0xFF1B222B),
          surfaceContainer: const Color(0xFF161B22),
          surfaceContainerLow: const Color(0xFF12171D),
        );
    return _build(
      scheme,
      background: MirrorColors.backgroundDark,
      surface: MirrorColors.surfaceDark,
      surfaceVariant: MirrorColors.surfaceVariantDark,
      outline: MirrorColors.outlineDark,
    );
  }

  static TextTheme _textTheme(ColorScheme s) {
    final ink = s.onSurface;
    final muted = s.onSurfaceVariant;
    return TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.2,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 14, height: 1.45, color: ink),
      bodyMedium: TextStyle(fontSize: 13.5, height: 1.45, color: ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: ink,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: muted,
      ),
    );
  }

  static ThemeData _build(
    ColorScheme scheme, {
    required Color background,
    required Color surface,
    required Color surfaceVariant,
    required Color outline,
  }) {
    final text = _textTheme(scheme);
    final rMd = BorderRadius.circular(MirrorRadius.md);
    const btnText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MirrorRadius.md),
          side: BorderSide(color: outline),
        ),
        textStyle: text.bodyMedium!.copyWith(fontFamily: fontFamily),
        labelTextStyle: WidgetStatePropertyAll(
          text.bodyMedium!.copyWith(fontFamily: fontFamily),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(3),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.18),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MirrorRadius.md),
              side: BorderSide(color: outline),
            ),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyMedium!.copyWith(fontFamily: fontFamily),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: rMd,
            borderSide: BorderSide(color: outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: rMd,
            borderSide: BorderSide(color: outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: rMd,
            borderSide: BorderSide(color: scheme.primary, width: 1.6),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: 56,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: MirrorSpace.lg,
        shape: Border(bottom: BorderSide(color: outline, width: 1)),
        titleTextStyle: text.titleLarge!.copyWith(fontFamily: fontFamily),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MirrorRadius.lg),
          side: BorderSide(color: outline, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: MirrorSpace.lg),
        minVerticalPadding: 8,
        horizontalTitleGap: MirrorSpace.md,
        iconColor: scheme.primary,
        titleTextStyle: text.titleSmall!.copyWith(fontFamily: fontFamily),
        subtitleTextStyle: text.bodySmall!.copyWith(fontFamily: fontFamily),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: scheme.primary.withValues(alpha: 0.16),
        side: BorderSide(color: outline),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium!.copyWith(fontFamily: fontFamily),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: rMd),
          textStyle: btnText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: rMd),
          textStyle: btnText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: rMd),
          textStyle: btnText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: rMd),
          textStyle: btnText.copyWith(fontSize: 13.5),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: rMd),
          side: BorderSide(color: outline),
          textStyle: btnText.copyWith(fontSize: 13),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: rMd),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MirrorRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MirrorRadius.xl),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: MirrorSpace.lg),
        iconColor: scheme.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: rMd,
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: rMd,
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: rMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
    );
  }
}
