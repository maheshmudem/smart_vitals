import '../entities/enums.dart';
import '../entities/marker_envelope.dart';

class CariesHabitsInput {
  const CariesHabitsInput({
    this.nightBottleFeeding = false,
    this.brushingPerDay = 2,
    this.usesFluoridePaste = true,
    this.sweetsPerDay = 1,
  });

  final bool nightBottleFeeding;
  final int brushingPerDay;
  final bool usesFluoridePaste;
  final int sweetsPerDay;
}

class CariesRiskOutput {
  const CariesRiskOutput({required this.riskBand, required this.explanation});

  final SemanticBand riskBand;
  final String explanation;
}

/// Implements Spec §7.2 & §7.3 Caries-risk rule (ALG-DEN-06 / BR-DEN).
/// Reproduces all 6 test vectors in Spec §7.3 with 100% pass:
/// - Case 1: One cavity on 54 + None -> High
/// - Case 2: White spots on 51 and 61 + None -> High
/// - Case 3: One white spot on 52 + Night bottle feeding -> High (white spot + night feeding)
/// - Case 4: One white spot on 52 + Brushing 2/day, fluoride, sweets 1/day -> Moderate
/// - Case 5: No lesions + Sweets 4/day, brushing 1/day -> Moderate
/// - Case 6: No lesions + Sweets 2/day -> Low
class CariesRiskEngine {
  static CariesRiskOutput evaluate({
    required List<ToothFinding> findings,
    required CariesHabitsInput habits,
  }) {
    final cavityOrWorseCount = findings
        .where(
          (f) =>
              f.findingCode == 'cavity' ||
              f.findingCode == 'enamel_break' ||
              f.findingCode == 'broken_black' ||
              f.findingCode == 'abscess_sign',
        )
        .length;
    final whiteSpotCount = findings
        .where((f) => f.findingCode == 'white_spot')
        .length;

    // Case 1: Any cavitated lesion -> High
    if (cavityOrWorseCount >= 1) {
      return const CariesRiskOutput(
        riskBand: SemanticBand.high,
        explanation:
            'High caries risk (cavitated lesion detected — BR-DEN Case 1).',
      );
    }

    // Case 2: >= 2 white spots -> High
    if (whiteSpotCount >= 2) {
      return const CariesRiskOutput(
        riskBand: SemanticBand.high,
        explanation:
            'High caries risk (multiple white-spot lesions — BR-DEN Case 2).',
      );
    }

    // Case 3: 1 white spot + night bottle feeding -> High
    if (whiteSpotCount == 1 && habits.nightBottleFeeding) {
      return const CariesRiskOutput(
        riskBand: SemanticBand.high,
        explanation:
            'High caries risk (white spot + night bottle feeding — BR-DEN Case 3).',
      );
    }

    // Case 4: 1 white spot without night bottle feeding -> Moderate
    if (whiteSpotCount == 1) {
      return const CariesRiskOutput(
        riskBand: SemanticBand.moderate,
        explanation:
            'Moderate caries risk (single white-spot lesion with protective habits — BR-DEN Case 4).',
      );
    }

    // Case 5: No lesions, but high sugar (>=3/day) or brushing <=1/day or night bottle -> Moderate
    if (habits.sweetsPerDay >= 3 ||
        habits.brushingPerDay <= 1 ||
        habits.nightBottleFeeding ||
        !habits.usesFluoridePaste) {
      return const CariesRiskOutput(
        riskBand: SemanticBand.moderate,
        explanation:
            'Moderate caries risk (dietary/hygiene risk factors without active lesions — BR-DEN Case 5).',
      );
    }

    // Case 6: No lesions + sweets <= 2/day + brushing >= 2/day -> Low
    return const CariesRiskOutput(
      riskBand: SemanticBand.low,
      explanation:
          'Low caries risk (no lesions and low dietary sugar — BR-DEN Case 6).',
    );
  }
}
