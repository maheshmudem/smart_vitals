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
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: MirrorColors.primary,
      primary: MirrorColors.primary,
      secondary: MirrorColors.secondary,
      surface: MirrorColors.surfaceLight,
      error: MirrorColors.dangerFg,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: MirrorColors.backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: MirrorColors.surfaceLight,
        foregroundColor: MirrorColors.inkLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: MirrorColors.inkLight,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: MirrorColors.surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MirrorColors.outlineLight, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MirrorColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(120, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(100, 46),
          side: const BorderSide(color: MirrorColors.outlineLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MirrorColors.surfaceVariantLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MirrorColors.outlineLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MirrorColors.outlineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MirrorColors.primary, width: 1.6),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4FD1C5),
      primary: const Color(0xFF4FD1C5),
      secondary: const Color(0xFFA5B0FF),
      surface: const Color(0xFF161B22),
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      cardTheme: CardThemeData(
        color: const Color(0xFF161B22),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2D3642), width: 1),
        ),
      ),
    );
  }
}
