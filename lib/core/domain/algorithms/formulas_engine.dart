import 'dart:math' as math;
import '../entities/enums.dart';

/// Implements Spec §5 Formula Cards (ALG-FRM-01 to ALG-FRM-15).
/// Rule (Spec §5 intro):
/// "Each formula must reproduce its test vector exactly (to the stated decimals)
/// in unit tests... A formula never runs if any input is missing, hidden or
/// below its quality threshold."
class FormulasEngine {
  static double _round(double value, int decimals) {
    final factor = math.pow(10, decimals).toDouble();
    return (value * factor).round() / factor;
  }

  /// ALG-FRM-01: MAP = DBP + (SBP - DBP) / 3
  /// Output: map_mmhg (mmHg, 1 decimal, valid 40–180), normal 70–100.
  /// Vector: 117 / 77 -> 90.3
  static double? computeMap({double? sbp, double? dbp}) {
    if (sbp == null || dbp == null) return null;
    final raw = dbp + (sbp - dbp) / 3.0;
    final rounded = _round(raw, 1);
    if (rounded < 40.0 || rounded > 180.0) return null;
    return rounded;
  }

  static SemanticBand classifyMap(double mapMmhg) {
    if (mapMmhg >= 70.0 && mapMmhg <= 100.0) return SemanticBand.normal;
    return SemanticBand.borderline;
  }

  /// ALG-FRM-02: PP = SBP - DBP
  /// Output: pp_mmhg (mmHg, 0 decimals, valid 10–120), normal 30–50.
  /// Vector: 117 / 77 -> 40
  static int? computePulsePressure({double? sbp, double? dbp}) {
    if (sbp == null || dbp == null) return null;
    final pp = (sbp - dbp).round();
    if (pp < 10 || pp > 120) return null;
    return pp;
  }

  static SemanticBand classifyPulsePressure(int ppMmhg) {
    if (ppMmhg >= 30 && ppMmhg <= 50) return SemanticBand.normal;
    return SemanticBand.borderline;
  }

  /// ALG-FRM-03: Shock index = HR / SBP
  /// Output: shock_index (ratio, 2 decimals, valid 0.2–3.0), normal 0.5–0.7.
  /// Vector: 92 / 117 -> 0.79
  static double? computeShockIndex({double? hr, double? sbp}) {
    if (hr == null || sbp == null || sbp <= 0) return null;
    final si = _round(hr / sbp, 2);
    if (si < 0.20 || si > 3.00) return null;
    return si;
  }

  static SemanticBand classifyShockIndex(double si) {
    if (si > 0.90) {
      return SemanticBand.critical; // Spec §13.1 & T5: > 0.9 Emergency
    }
    if (si >= 0.50 && si <= 0.70) return SemanticBand.normal;
    return SemanticBand.borderline; // T4: 0.79 -> None (no urgency flag)
  }

  /// ALG-FRM-04: RPP = HR * SBP
  /// Output: rpp (bpm·mmHg, 0 decimals, valid 3000–40000), normal < 12000.
  /// Vector: 92 * 117 -> 10764
  static int? computeRpp({double? hr, double? sbp}) {
    if (hr == null || sbp == null) return null;
    final rpp = (hr * sbp).round();
    if (rpp < 3000 || rpp > 40000) return null;
    return rpp;
  }

  static SemanticBand classifyRpp(int rpp) {
    return rpp < 12000 ? SemanticBand.normal : SemanticBand.borderline;
  }

  /// ALG-FRM-05: CR ratio = HR / RR
  /// Output: cr_ratio (ratio, 2 decimals, valid 1–20), normal 3–6.
  /// Vector: 92 / 21 -> 4.38
  static double? computeCrRatio({double? hr, double? rr}) {
    if (hr == null || rr == null || rr <= 0) return null;
    final cr = _round(hr / rr, 2);
    if (cr < 1.0 || cr > 20.0) return null;
    return cr;
  }

  static SemanticBand classifyCrRatio(double cr) {
    if (cr >= 3.0 && cr <= 6.0) return SemanticBand.normal;
    return SemanticBand.borderline;
  }

  /// ALG-FRM-06: HRmax (Tanaka) = 208 - 0.7 * age
  /// Output: hrmax_bpm (bpm, 1 decimal, valid 120–210).
  /// Vector: 26 -> 189.8
  static double? computeHrMaxTanaka({int? ageYears}) {
    if (ageYears == null || ageYears <= 0) return null;
    final hrmax = _round(208.0 - 0.7 * ageYears, 1);
    if (hrmax < 120.0 || hrmax > 210.0) return null;
    return hrmax;
  }

  /// ALG-FRM-07: HRR (Karvonen) = HRmax - HRrest
  /// Output: hrr_bpm (bpm, 1 decimal, valid 20–180).
  /// Vector: 189.8 - 92 -> 97.8
  static double? computeHrReserve({double? hrMax, double? hrRest}) {
    if (hrMax == null || hrRest == null) return null;
    final hrr = _round(hrMax - hrRest, 1);
    if (hrr < 20.0 || hrr > 180.0) return null;
    return hrr;
  }

  /// ALG-FRM-08: VO2max (Uth) = 15.3 * HRmax / HRrest
  /// Output: vo2max_est (mL/kg/min, 1 decimal, valid 10–80), labelled "estimate".
  /// Vector: 15.3 * 189.8 / 92 -> 31.6
  static double? computeVo2MaxUth({double? hrMax, double? hrRest}) {
    if (hrMax == null || hrRest == null || hrRest <= 0) return null;
    final vo2 = _round(15.3 * hrMax / hrRest, 1);
    if (vo2 < 10.0 || vo2 > 80.0) return null;
    return vo2;
  }

  /// ALG-FRM-09: BMI = weight / height^2
  /// Output: bmi (kg/m2, 2 decimals, valid 10–70), normal 18.5–22.9 (Asian).
  /// Vector: 70 kg, 1.78 m -> 22.09
  static double? computeBmi({double? weightKg, double? heightCm}) {
    if (weightKg == null || heightCm == null || heightCm <= 0) return null;
    final heightM = heightCm / 100.0;
    final bmi = _round(weightKg / (heightM * heightM), 2);
    if (bmi < 10.0 || bmi > 70.0) return null;
    return bmi;
  }

  static SemanticBand classifyAsianBmi(double bmi) {
    if (bmi >= 18.5 && bmi <= 22.9) return SemanticBand.normal;
    if (bmi >= 23.0) return SemanticBand.high; // Spec §13.1 trigger: BMI >= 23
    return SemanticBand.borderline;
  }

  /// ALG-FRM-10: WHtR = waist / height
  /// Output: whtr (ratio, 3 decimals, valid 0.3–1.0), normal < 0.5.
  /// Vector: 85 / 178 -> 0.478
  static double? computeWhtr({double? waistCm, double? heightCm}) {
    if (waistCm == null || heightCm == null || heightCm <= 0) return null;
    final whtr = _round(waistCm / heightCm, 3);
    if (whtr < 0.300 || whtr > 1.000) return null;
    return whtr;
  }

  static SemanticBand classifyWhtr(double whtr) {
    return whtr < 0.500 ? SemanticBand.normal : SemanticBand.high;
  }

  /// ALG-FRM-11: Body fat (Deurenberg) = 1.2 * BMI + 0.23 * age - 10.8 * sex - 5.4 (male = 1)
  /// Output: body_fat_pct (%, 2 decimals, valid 3–60), adults only, labelled "estimate".
  /// Normal: Men 10–20; women 20–30.
  /// Vector: BMI 22.09, 26 y, male (1) -> 16.29
  static double? computeBodyFatDeurenberg({
    double? bmi,
    int? ageYears,
    BiologicalSex? sex,
  }) {
    if (bmi == null || ageYears == null || sex == null) return null;
    if (ageYears < 18) return null; // Spec §5: adults only
    final bf = _round(
      1.2 * bmi + 0.23 * ageYears - 10.8 * sex.deurenbergCode - 5.4,
      2,
    );
    if (bf < 3.0 || bf > 60.0) return null;
    return bf;
  }

  static SemanticBand classifyBodyFat(double bodyFatPct, BiologicalSex sex) {
    if (sex == BiologicalSex.male) {
      return (bodyFatPct >= 10.0 && bodyFatPct <= 20.0)
          ? SemanticBand.normal
          : SemanticBand.borderline;
    } else {
      return (bodyFatPct >= 20.0 && bodyFatPct <= 30.0)
          ? SemanticBand.normal
          : SemanticBand.borderline;
    }
  }

  /// ALG-FRM-12: WHO z = ((X / M)^L - 1) / (L * S)
  /// Output: haz, waz, bmiz (z, 2 decimals, valid -6 to 6), normal -2 to +2.
  /// Vector: X = 18, L = -0.5, M = 16, S = 0.08 -> 1.43; X = M -> 0.00
  static double? computeWhoZScore({
    required double x,
    required double l,
    required double m,
    required double s,
  }) {
    if (x <= 0 || m <= 0 || s <= 0) return null;
    final double zRaw;
    if (l.abs() < 1e-9) {
      zRaw = math.log(x / m) / s;
    } else {
      zRaw = (math.pow(x / m, l) - 1.0) / (l * s);
    }
    final z = _round(zRaw.toDouble(), 2);
    if (z < -6.0 || z > 6.0) return null;
    return z;
  }

  static SemanticBand classifyWhoZScore(double z) {
    if (z >= -2.0 && z <= 2.0) return SemanticBand.normal;
    if (z < -2.0) {
      return SemanticBand.high; // Spec §13.2: z-score < -2 Growth faltering
    }
    return SemanticBand.borderline;
  }

  /// ALG-FRM-14: Orthostatic rise = max standing HR (0–3 min) - mean lying HR (last 30 s)
  /// Output: ortho_hr_rise_bpm (bpm, 0 decimals, valid -20 to 80), normal < 30.
  /// Vector: Lying 70, standing max 104 -> 34 (flag)
  static int? computeOrthostaticRise({
    double? meanLyingHr,
    double? maxStandingHr,
  }) {
    if (meanLyingHr == null || maxStandingHr == null) return null;
    final rise = (maxStandingHr - meanLyingHr).round();
    if (rise < -20 || rise > 80) return null;
    return rise;
  }

  static SemanticBand classifyOrthostaticRise(int riseBpm) {
    return riseBpm < 30 ? SemanticBand.normal : SemanticBand.high;
  }

  /// ALG-FRM-15: HR recovery = HR at end of exercise - HR 60 s later
  /// Output: hr_recovery_1m_bpm (bpm, 0 decimals, valid -10 to 80), normal >= 12.
  /// Vector: 120 -> 105 -> 15 (normal)
  static int? computeHrRecovery1Min({
    double? hrEndExercise,
    double? hrAfter60Sec,
  }) {
    if (hrEndExercise == null || hrAfter60Sec == null) return null;
    final rec = (hrEndExercise - hrAfter60Sec).round();
    if (rec < -10 || rec > 80) return null;
    return rec;
  }

  static SemanticBand classifyHrRecovery1Min(int recoveryBpm) {
    return recoveryBpm >= 12 ? SemanticBand.normal : SemanticBand.borderline;
  }
}
