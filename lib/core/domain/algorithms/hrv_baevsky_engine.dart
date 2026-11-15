import 'dart:math' as math;
import '../entities/enums.dart';

class HrvTimeDomainResult {
  const HrvTimeDomainResult({
    required this.sdnnMs,
    required this.rmssdMs,
    required this.pnn50Pct,
    required this.sd1Ms,
    required this.sd2Ms,
    required this.sd1Sd2Ratio,
  });

  final double sdnnMs;
  final double rmssdMs;
  final double pnn50Pct;
  final double sd1Ms;
  final double sd2Ms;
  final double sd1Sd2Ratio;
}

class BaevskyStressResult {
  const BaevskyStressResult({
    required this.stressIndex,
    required this.band,
    required this.isLowConfidenceRigidRhythm,
  });

  final double stressIndex;
  final SemanticBand band;
  final bool isLowConfidenceRigidRhythm;
}

/// Implements Spec §4.3 Heart Rate Variability (ALG-HRV-01/02/03)
/// and Spec §4.4 Baevsky Stress Index (ALG-HRV-04).
class HrvBaevskyEngine {
  /// Computes SDNN, RMSSD, pNN50, SD1, SD2 on valid IBIs (ms).
  /// Spec §4.3 test vector:
  /// IBIs [800, 810, 790, 805, 795] ms -> SDNN 7.9 ms, RMSSD 14.4 ms, pNN50 0.0%
  static HrvTimeDomainResult computeTimeDomain(List<double> validIbisMs) {
    if (validIbisMs.length < 2) {
      return const HrvTimeDomainResult(
        sdnnMs: 0,
        rmssdMs: 0,
        pnn50Pct: 0,
        sd1Ms: 0,
        sd2Ms: 0,
        sd1Sd2Ratio: 0,
      );
    }

    final n = validIbisMs.length;
    final mean = validIbisMs.reduce((a, b) => a + b) / n;

    // SDNN = sample SD (n - 1) of valid IBIs
    double sumSqDev = 0.0;
    for (final ibi in validIbisMs) {
      final diff = ibi - mean;
      sumSqDev += diff * diff;
    }
    final sdnnRaw = math.sqrt(sumSqDev / (n - 1));

    // Successive differences of adjacent valid IBIs
    final diffs = <double>[];
    double sumSqDiff = 0.0;
    int countOver50 = 0;
    for (int i = 0; i < n - 1; i++) {
      final d = validIbisMs[i + 1] - validIbisMs[i];
      diffs.add(d);
      sumSqDiff += d * d;
      if (d.abs() > 50.0) {
        countOver50++;
      }
    }

    final rmssdRaw = math.sqrt(sumSqDiff / diffs.length);
    final pnn50Raw = (countOver50 / diffs.length) * 100.0;

    // SD1 = sqrt(0.5) * SD(delta_IBI); SD2 = sqrt(2 * SDNN^2 - SD1^2)
    final meanDiff = diffs.reduce((a, b) => a + b) / diffs.length;
    double sumSqDiffDev = 0.0;
    for (final d in diffs) {
      final dev = d - meanDiff;
      sumSqDiffDev += dev * dev;
    }
    final sdDelta = diffs.length > 1
        ? math.sqrt(sumSqDiffDev / (diffs.length - 1))
        : 0.0;
    final sd1Raw = math.sqrt(0.5) * sdDelta;
    final twoSdnnSqMinusSd1Sq = math.max(
      0.0,
      2 * sdnnRaw * sdnnRaw - sd1Raw * sd1Raw,
    );
    final sd2Raw = math.sqrt(twoSdnnSqMinusSd1Sq);
    final ratio = sd2Raw > 0 ? sd1Raw / sd2Raw : 0.0;

    return HrvTimeDomainResult(
      sdnnMs: _roundToDecimals(sdnnRaw, 1),
      rmssdMs: _roundToDecimals(rmssdRaw, 1),
      pnn50Pct: _roundToDecimals(pnn50Raw, 1),
      sd1Ms: _roundToDecimals(sd1Raw, 1),
      sd2Ms: _roundToDecimals(sd2Raw, 1),
      sd1Sd2Ratio: _roundToDecimals(ratio, 2),
    );
  }

  /// Spec §4.4 Baevsky Stress Index (ALG-HRV-04):
  /// SI = AMo / (2 * Mo * MxDMn)
  /// Test vector: Mo = 0.80 s, AMo = 40%, MxDMn = 0.20 s -> SI = 125
  /// Normal ranges: 50–150 low; 151–500 moderate; > 500 high.
  static BaevskyStressResult computeFromParameters({
    required double moSeconds,
    required double amoPercent,
    required double mxdmnSeconds,
  }) {
    if (moSeconds <= 0 || mxdmnSeconds <= 0) {
      return const BaevskyStressResult(
        stressIndex: 0,
        band: SemanticBand.notAvailable,
        isLowConfidenceRigidRhythm: true,
      );
    }
    // Spec §4.4 Failure handling: MxDMn < 20 ms (0.02 s) -> report with low confidence
    final isRigid = mxdmnSeconds < 0.020;
    final si = amoPercent / (2.0 * moSeconds * mxdmnSeconds);
    final roundedSi = _roundToDecimals(si, 0);
    return BaevskyStressResult(
      stressIndex: roundedSi,
      band: classifyBaevskyBand(roundedSi),
      isLowConfidenceRigidRhythm: isRigid,
    );
  }

  /// Computes Baevsky SI from a valid IBI series (ms) using 50-ms histogram bins
  /// and 2.5% top/bottom outlier trimming per Spec §4.4.
  static BaevskyStressResult computeFromIbiSeries(List<double> validIbisMs) {
    if (validIbisMs.length < 5) {
      return const BaevskyStressResult(
        stressIndex: 0,
        band: SemanticBand.notAvailable,
        isLowConfidenceRigidRhythm: true,
      );
    }
    final sorted = List<double>.from(validIbisMs)..sort();
    final trimCount = (sorted.length * 0.025).floor();
    final trimmed = sorted.sublist(trimCount, sorted.length - trimCount);
    final mxdmnSeconds = (trimmed.last - trimmed.first) / 1000.0;

    // 50-ms bins from 300 ms to 2000 ms
    int maxBinCount = 0;
    double bestMoMs = trimmed[trimmed.length ~/ 2];
    for (int binStart = 300; binStart < 2000; binStart += 50) {
      final binEnd = binStart + 50;
      final count = trimmed.where((v) => v >= binStart && v < binEnd).length;
      if (count > maxBinCount) {
        maxBinCount = count;
        bestMoMs = binStart + 25.0; // centre of tallest bin
      }
    }
    final moSeconds = bestMoMs / 1000.0;
    final amoPercent = (maxBinCount / trimmed.length) * 100.0;
    return computeFromParameters(
      moSeconds: moSeconds,
      amoPercent: amoPercent,
      mxdmnSeconds: mxdmnSeconds,
    );
  }

  static SemanticBand classifyBaevskyBand(double si) {
    if (si <= 150.0) return SemanticBand.low;
    if (si <= 500.0) return SemanticBand.moderate;
    return SemanticBand.high;
  }

  static double _roundToDecimals(double value, int decimals) {
    final factor = math.pow(10, decimals).toDouble();
    return (value * factor).round() / factor;
  }
}
