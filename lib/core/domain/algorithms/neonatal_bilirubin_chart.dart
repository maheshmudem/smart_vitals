import '../entities/enums.dart';

/// Hour-specific phototherapy-consideration line for newborns (ALG-IMG-07).
///
/// The Spec says "compare with age-in-hours treatment chart (NICE/AAP)" but
/// ships no values (`mst_reference_range` is a missing master document).
/// This is a **stand-in** [DER] sampled from the AAP 2022 phototherapy
/// thresholds (Kemper et al., Pediatrics 2022, supplemental tables) every
/// 12 h for gestation groups 35–37 / 38 / 39 / ≥ 40 weeks, with and without
/// neurotoxicity risk factors, and linearly interpolated between samples.
/// Replace with the master table before any clinical use.
class NeonatalBilirubinChart {
  NeonatalBilirubinChart._();

  static const List<int> sampleHours = [
    12,
    24,
    36,
    48,
    60,
    72,
    84,
    96,
    108,
    120,
  ];

  /// mg/dL at [sampleHours]; key = gestation bucket (35, 38, 39, 40).
  static const Map<int, List<double>> _noRisk = {
    35: [7.0, 9.4, 11.4, 13.4, 15.0, 16.2, 17.1, 17.9, 18.5, 18.9],
    38: [9.4, 12.3, 14.4, 16.0, 17.5, 18.8, 19.9, 20.7, 21.2, 21.5],
    39: [9.9, 12.8, 14.9, 16.6, 18.1, 19.5, 20.6, 21.5, 21.9, 22.2],
    40: [10.3, 13.3, 15.4, 17.0, 18.5, 19.8, 20.9, 21.8, 22.2, 22.5],
  };

  /// With ≥ 1 neurotoxicity risk factor (haemolysis, G6PD, sepsis, low
  /// albumin, instability): lines sit roughly 2 mg/dL lower.
  static const Map<int, List<double>> _withRisk = {
    35: [5.6, 7.6, 9.3, 11.0, 12.4, 13.5, 14.3, 15.0, 15.5, 15.9],
    38: [7.6, 10.1, 12.0, 13.6, 14.9, 16.1, 17.1, 17.8, 18.3, 18.6],
    39: [8.0, 10.6, 12.5, 14.1, 15.5, 16.8, 17.8, 18.6, 19.0, 19.3],
    40: [8.4, 11.0, 12.9, 14.5, 15.9, 17.2, 18.2, 19.0, 19.4, 19.7],
  };

  static int? _bucket(int gestationWeeks) {
    if (gestationWeeks < 35) return null;
    if (gestationWeeks < 38) return 35;
    if (gestationWeeks == 38) return 38;
    if (gestationWeeks == 39) return 39;
    return 40;
  }

  static String bucketLabel(int gestationWeeks) {
    final b = _bucket(gestationWeeks);
    return switch (b) {
      null => 'under 35 weeks',
      35 => '35–37 weeks',
      38 => '38 weeks',
      39 => '39 weeks',
      _ => '40 weeks or more',
    };
  }

  /// Phototherapy-consideration threshold in mg/dL, or null when the chart
  /// does not apply (< 35 weeks, > 28 days).
  static double? phototherapyThreshold({
    required int gestationWeeks,
    required int ageHours,
    required bool hasRiskFactors,
  }) {
    final b = _bucket(gestationWeeks);
    if (b == null) return null;
    if (ageHours < 0 || ageHours > 672) return null;
    final table = (hasRiskFactors ? _withRisk : _noRisk)[b]!;
    if (ageHours <= sampleHours.first) {
      // Before 12 h the line is not defined; use the 12 h value (conservative).
      return table.first;
    }
    if (ageHours >= sampleHours.last) return table.last;
    for (var i = 0; i < sampleHours.length - 1; i++) {
      final h0 = sampleHours[i];
      final h1 = sampleHours[i + 1];
      if (ageHours >= h0 && ageHours <= h1) {
        final t = (ageHours - h0) / (h1 - h0);
        return table[i] + (table[i + 1] - table[i]) * t;
      }
    }
    return table.last;
  }

  /// Band against the line [DER]: High at/above, Borderline within
  /// [borderlineMarginMgDl] below, otherwise Normal.
  static SemanticBand band({
    required double estimateMgDl,
    required double thresholdMgDl,
    double borderlineMarginMgDl = 3.0,
  }) {
    if (estimateMgDl >= thresholdMgDl) return SemanticBand.high;
    if (estimateMgDl >= thresholdMgDl - borderlineMarginMgDl) {
      return SemanticBand.borderline;
    }
    return SemanticBand.normal;
  }

  /// Rows (hours, mg/dL) for the result-card table at 24 h steps.
  static List<(int, double)> tableFor({
    required int gestationWeeks,
    required bool hasRiskFactors,
  }) {
    final out = <(int, double)>[];
    for (final h in const [24, 48, 72, 96, 120]) {
      final v = phototherapyThreshold(
        gestationWeeks: gestationWeeks,
        ageHours: h,
        hasRiskFactors: hasRiskFactors,
      );
      if (v != null) out.add((h, v));
    }
    return out;
  }
}
