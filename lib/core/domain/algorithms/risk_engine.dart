import 'dart:math' as math;
import '../entities/enums.dart';
import '../entities/case_record.dart';

class RiskEvaluationInput {
  const RiskEvaluationInput({
    this.hrBpm,
    this.hrQualityPassed = true,
    this.rrBrMin,
    this.spo2Band,
    this.bpBand,
    this.sbpMmhg,
    this.dbpMmhg,
    this.temperatureCelsius,
    this.hasChestPain = false,
    this.irregularRhythmConfirmed = false,
    this.strokePositive = false,
    this.childWhitePupil = false,
    this.anaemiaBand,
    this.isPregnant = false,
    this.dentalAbscessSign = false,
    this.dentalCavityOnly = false,
    this.tbBand,
    this.jaundiceBand,
    this.cataractBand,
    this.childEyeBand,
    this.drReferable = false,
    this.drSightThreatening = false,
    this.glaucomaSuspect = false,
    this.neoJaundiceBand,
    this.dfuClass,
    this.skinBand,
    this.oralClass,
    this.gaitSpeedMs,
    this.stsCount,
    this.stsAgeNormMin,
    this.tremorPeakHz,
    this.tapDecrementPct,
    this.pdBand,
    this.logMarWorse,
    this.amslerAbnormal,
    this.colourPlateMisses,
    this.ptaBetterEarDbHl,
    this.hearingAsymmetry = false,
    this.phq9Total,
    this.phq9Item9,
    this.gad7Total,
    this.hfAlert = false,
    this.fev1FvcBelowLln = false,
    this.oadBand,
    this.ahiEst,
  });

  final int? hrBpm;
  final bool hrQualityPassed;
  final int? rrBrMin;
  final SemanticBand? spo2Band;
  final SemanticBand? bpBand;
  final double? sbpMmhg;
  final double? dbpMmhg;
  final double? temperatureCelsius;
  final bool hasChestPain;
  final bool irregularRhythmConfirmed;
  final bool strokePositive;
  final bool childWhitePupil;
  final SemanticBand? anaemiaBand;
  final bool isPregnant;
  final bool dentalAbscessSign;
  final bool dentalCavityOnly;
  final SemanticBand? tbBand;

  // Image eye screens [DER rule codes T17–T22; Spec assigns only T11].
  final SemanticBand? jaundiceBand; // ALG-IMG-02: high -> Urgent
  final SemanticBand? cataractBand; // ALG-IMG-03: high -> Routine
  final SemanticBand?
  childEyeBand; // ALG-IMG-06: refer -> Routine (white pupil via childWhitePupil)
  final bool drReferable; // ALG-IMG-09: moderate NPDR+ or DME -> Routine
  final bool drSightThreatening; // ALG-IMG-09: PDR or DME -> Urgent
  final bool glaucomaSuspect; // ALG-IMG-09: -> Routine

  // Skin & Body image screens [DER rule codes T23–T27].
  final SemanticBand?
  neoJaundiceBand; // ALG-IMG-07: high -> Urgent, borderline -> Routine recheck
  final SemanticBand?
  dfuClass; // ALG-IMG-05: ulcer -> Urgent, atRisk -> Routine
  final SemanticBand?
  skinBand; // ALG-IMG-08: suspicious -> Urgent, refer -> Routine

  // Dental section [DER rule codes T28–T29].
  final SemanticBand?
  oralClass; // ALG-IMG-04: suspicious / high -> Urgent, refer -> Routine

  // Movement section [DER rule codes T30–T31].
  final double? gaitSpeedMs; // ALG-MOV-03: < 0.8 m/s -> Routine (fall risk)
  final int? stsCount; // ALG-MOV-04
  final int? stsAgeNormMin; // spec norm when known (12 for age 60–64)
  final double? tremorPeakHz; // ALG-MOV-05: set only when above the floor
  final double? tapDecrementPct; // ALG-MOV-01: >= 20 % -> Routine
  final SemanticBand? pdBand; // ALG-MOV-13: refer -> Routine

  // Vision section [DER rule codes T32–T34].
  final double? logMarWorse; // ALG-MOV-10: > 0.5 -> Routine (COND_CATARACT)
  final bool? amslerAbnormal; // ALG-MOV-11: true -> Routine (COND_MACULA)
  final int?
  colourPlateMisses; // ALG-MOV-11: >= 3 -> Routine (COND_COLOUR_VISION)

  // Hearing section [DER rule codes T35–T36].
  final double?
  ptaBetterEarDbHl; // ALG-AUD-09: >= 20 dB HL better ear -> Routine (Spec §13.2)
  final bool
  hearingAsymmetry; // ALG-AUD-09: >= 15 dB at 2+ frequencies -> Routine ENT

  // Brain & Mind [DER rule codes T37–T39; Spec names only G-37 and §13.2].
  final int? phq9Total; // ALG-AUD-11: >= 10 -> Routine (COND_MOOD)
  final int? phq9Item9; // ALG-AUD-11: > 0 -> Emergency crisis (G-37)
  final int? gad7Total; // ALG-AUD-11: >= 10 -> Routine (COND_MOOD)
  final bool hfAlert; // ALG-AUD-12: true -> Urgent (COND_HF_DECOMP)

  // Breathing & Voice [DER rule codes T40–T41; Spec names COND_OAD routine].
  final bool
  fev1FvcBelowLln; // ALG-AUD-05 / FRM-13: FEV1/FVC < RATIO_LLN -> Routine
  final SemanticBand? oadBand; // ALG-AUD-04: moderate / high -> Routine

  // Sleep [DER rule code T42; Spec §8 AUD-08 + §13.2 name COND_OSA routine].
  final double?
  ahiEst; // ALG-AUD-08: AHI_EST >= 15 (moderate / severe) -> Routine
}

class RiskEvaluationResult {
  const RiskEvaluationResult({
    required this.highestUrgency,
    required this.firedRuleCodes,
    required this.requiresRetakeFirst,
    required this.requiresRescanConfirmation,
    required this.orderedFlags,
  });

  final UrgencyLevel highestUrgency;
  final List<String> firedRuleCodes;
  final bool requiresRetakeFirst; // T16: BR-QUA-01
  final bool requiresRescanConfirmation; // T3: BR-VIT-02 Urgent (rescan first)
  final List<ConditionFlag> orderedFlags; // T15: Urgent shown before Routine
}

class PersonalBaselineResult {
  const PersonalBaselineResult({
    required this.hasBaseline,
    this.baselineMedian,
    this.baselineSd,
    this.changePct,
    this.isMeaningfulChange = false,
  });

  final bool hasBaseline;
  final double? baselineMedian;
  final double? baselineSd;
  final double? changePct;
  final bool isMeaningfulChange;
}

/// Deterministic Risk Engine implementing Spec §10 (ALG-RSK-01 to ALG-RSK-07)
/// and passing all 16 minimum Rule Test Cases (T1 to T16).
class RiskEngine {
  /// ALG-RSK-01: Band Assignment (boundaries inclusive on the normal side).
  static SemanticBand assignHrBand(int hrBpm) {
    if (hrBpm < 40 || hrBpm > 130) return SemanticBand.critical;
    if (hrBpm >= 60 && hrBpm <= 100) return SemanticBand.normal;
    if ((hrBpm >= 50 && hrBpm <= 59) || (hrBpm >= 101 && hrBpm <= 110)) {
      return SemanticBand.borderline;
    }
    return SemanticBand.high;
  }

  static SemanticBand assignRrBand(int rrBrMin) {
    if (rrBrMin > 24 || rrBrMin < 8) return SemanticBand.critical;
    if (rrBrMin >= 12 && rrBrMin <= 20) return SemanticBand.normal;
    return SemanticBand.borderline; // 21-24 or 8-11
  }

  static SemanticBand assignSpo2Band(double spo2Pct) {
    if (spo2Pct >= 95.0) return SemanticBand.normal;
    if (spo2Pct >= 92.0) return SemanticBand.borderline;
    return SemanticBand.critical; // < 92%
  }

  static SemanticBand assignBpBand({required int sbp, required int dbp}) {
    if (sbp >= 140 || dbp >= 90) return SemanticBand.high;
    if (sbp >= 120 || dbp >= 80) return SemanticBand.elevated;
    return SemanticBand.normal;
  }

  /// ALG-RSK-01 + Spec §6.1 WHO Anaemia thresholds:
  /// men < 13.0, non-pregnant women < 12.0, pregnant women < 11.0,
  /// children 5–11 y < 11.5, 6–59 months (0–4 y) < 11.0 g/dL.
  static SemanticBand assignAnaemiaBand({
    required double hbEstGdL,
    required int ageYears,
    required BiologicalSex sex,
    required bool isPregnant,
  }) {
    final double cutoff;
    if (ageYears < 5) {
      cutoff = 11.0;
    } else if (ageYears <= 11) {
      cutoff = 11.5;
    } else if (sex == BiologicalSex.female && isPregnant) {
      cutoff = 11.0;
    } else if (sex == BiologicalSex.female) {
      cutoff = 12.0;
    } else {
      cutoff = 13.0;
    }
    return hbEstGdL < cutoff ? SemanticBand.high : SemanticBand.normal;
  }

  /// ALG-RSK-02: Urgency Rules (evaluates all active rules; emergency > urgent > routine).
  /// Matches T1–T16 from Spec §10 exactly.
  static RiskEvaluationResult evaluateUrgency(
    RiskEvaluationInput input, {
    String sessionId = 'sim_session',
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();

    // T16: HR value with quality below threshold -> No flag; "retake" (BR-QUA-01)
    if (!input.hrQualityPassed) {
      return const RiskEvaluationResult(
        highestUrgency: UrgencyLevel.none,
        firedRuleCodes: ['BR-QUA-01'],
        requiresRetakeFirst: true,
        requiresRescanConfirmation: false,
        orderedFlags: [],
      );
    }

    final flags = <ConditionFlag>[];
    final rules = <String>{};
    bool rescanFirst = false;

    void addFlag({
      required String conditionCode,
      required String markerCode,
      required String description,
      required UrgencyLevel urgency,
      required String ruleCode,
    }) {
      rules.add(ruleCode);
      flags.add(
        ConditionFlag(
          flagId: 'flg_${conditionCode}_${flags.length + 1}',
          conditionCode: conditionCode,
          sourceSessionId: sessionId,
          markerCode: markerCode,
          triggerDescription: description,
          urgency: urgency,
          ruleCode: ruleCode,
          createdAt: now,
        ),
      );
    }

    // T1: SpO2 band critical (< 92%) -> Emergency (BR-VIT-01)
    if (input.spo2Band == SemanticBand.critical) {
      addFlag(
        conditionCode: 'COND_HYPOXIA',
        markerCode: 'SPO2_BAND',
        description: 'Critical low oxygen saturation (< 92%)',
        urgency: UrgencyLevel.emergency,
        ruleCode: 'BR-VIT-01',
      );
    }

    // T2: HR > 130 or < 40 -> Emergency (BR-VIT-01)
    if (input.hrBpm != null && (input.hrBpm! > 130 || input.hrBpm! < 40)) {
      addFlag(
        conditionCode: 'COND_HR_ABNORMAL',
        markerCode: 'HR',
        description: 'Critical resting heart rate (${input.hrBpm} bpm)',
        urgency: UrgencyLevel.emergency,
        ruleCode: 'BR-VIT-01',
      );
    }

    // T4 & T5: Shock index = HR / SBP. T4: 92/117 = 0.79 -> None; T5: 100/95 = 1.05 -> Emergency (BR-VIT-01)
    if (input.hrBpm != null && input.sbpMmhg != null && input.sbpMmhg! > 0) {
      final si = input.hrBpm! / input.sbpMmhg!;
      if (si > 0.90) {
        addFlag(
          conditionCode: 'COND_SHOCK',
          markerCode: 'SHOCK_INDEX',
          description: 'Shock index elevated (${si.toStringAsFixed(2)} > 0.90)',
          urgency: UrgencyLevel.emergency,
          ruleCode: 'BR-VIT-01',
        );
      }
    }

    // T3: HR 105 at rest, RR 22 -> Urgent (rescan first) (BR-VIT-02)
    if (input.hrBpm != null &&
        input.hrBpm! > 100 &&
        input.hrBpm! <= 130 &&
        input.rrBrMin != null &&
        input.rrBrMin! > 20 &&
        input.rrBrMin! <= 24) {
      rescanFirst = true;
      addFlag(
        conditionCode: 'COND_INFECTION',
        markerCode: 'HR+RR',
        description:
            'Resting HR ${input.hrBpm} bpm with RR ${input.rrBrMin} br/min (Rescan first)',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-VIT-02',
      );
    }

    // RR > 24 or < 8 -> Emergency (Spec §4.2 & §13.1)
    if (input.rrBrMin != null && (input.rrBrMin! > 24 || input.rrBrMin! < 8)) {
      addFlag(
        conditionCode: 'COND_INFECTION',
        markerCode: 'RR',
        description: 'Critical respiratory rate (${input.rrBrMin} br/min)',
        urgency: UrgencyLevel.emergency,
        ruleCode: 'BR-VIT-01',
      );
    }

    // T6: Irregular rhythm on 2 scans -> Urgent (BR-VIT-03)
    if (input.irregularRhythmConfirmed) {
      addFlag(
        conditionCode: 'COND_AF',
        markerCode: 'IRREG_BAND',
        description: 'Irregular rhythm confirmed across 2 scans',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-VIT-03',
      );
    }

    // T7 & T8: BP band high -> Routine (no symptoms) or Urgent (+ chest pain) (BR-VIT-04)
    if (input.bpBand == SemanticBand.high) {
      addFlag(
        conditionCode: 'COND_HTN',
        markerCode: 'BP_BAND',
        description: input.hasChestPain
            ? 'High BP band with chest pain'
            : 'High BP band without acute symptoms',
        urgency: input.hasChestPain
            ? UrgencyLevel.urgent
            : UrgencyLevel.routine,
        ruleCode: 'BR-VIT-04',
      );
    }

    // T9: Temperature >= 38.0 °C + RR > 20 -> Urgent (BR-VIT-06)
    if (input.temperatureCelsius != null &&
        input.temperatureCelsius! >= 38.0 &&
        input.rrBrMin != null &&
        input.rrBrMin! > 20) {
      addFlag(
        conditionCode: 'COND_INFECTION',
        markerCode: 'TEMP+RR',
        description:
            'Fever (${input.temperatureCelsius!.toStringAsFixed(1)} °C) with raised RR (${input.rrBrMin} br/min)',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-VIT-06',
      );
    }

    // T10: Stroke positive -> Emergency (BR-SCR-01)
    if (input.strokePositive) {
      addFlag(
        conditionCode: 'COND_STROKE',
        markerCode: 'STROKE_POSITIVE',
        description: 'Positive FAST stroke warning sign detected',
        urgency: UrgencyLevel.emergency,
        ruleCode: 'BR-SCR-01',
      );
    }

    // T11: Child white pupil -> Urgent (BR-SCR-02)
    if (input.childWhitePupil) {
      addFlag(
        conditionCode: 'COND_CHILD_EYE',
        markerCode: 'WHITE_PUPIL_PROB',
        description: 'Child white pupil (leukocoria) sign detected',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-SCR-02',
      );
    }

    // T12 & T15: Anaemia high -> Urgent if pregnant (BR-SCR-03), else Routine (BR-SCR-04)
    if (input.anaemiaBand == SemanticBand.high) {
      addFlag(
        conditionCode: 'COND_ANAEMIA',
        markerCode: 'ANAEMIA_BAND',
        description: input.isPregnant
            ? 'High anaemia probability during pregnancy'
            : 'High anaemia probability (adult)',
        urgency: input.isPregnant ? UrgencyLevel.urgent : UrgencyLevel.routine,
        ruleCode: input.isPregnant ? 'BR-SCR-03' : 'BR-SCR-04',
      );
    }

    // T13: Dental abscess sign -> Urgent (BR-SCR-02)
    if (input.dentalAbscessSign) {
      addFlag(
        conditionCode: 'COND_CARIES',
        markerCode: 'DENTAL_ABSCESS',
        description: 'Dental abscess sign detected',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-SCR-02',
      );
    } else if (input.dentalCavityOnly) {
      // T14: Dental cavity only -> Routine (BR-SCR-04)
      addFlag(
        conditionCode: 'COND_CARIES',
        markerCode: 'DENTAL_CAVITY',
        description: 'Dental cavity detected without abscess sign',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T17 [DER]: Adult jaundice high -> Urgent (Spec §13.2: "Urgent"; BR-SCR-02)
    if (input.jaundiceBand == SemanticBand.high) {
      addFlag(
        conditionCode: 'COND_JAUNDICE',
        markerCode: 'JAUNDICE_BAND',
        description:
            'High jaundice probability on sclera photo (bilirubin likely > 2.5 mg/dL)',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-SCR-02',
      );
    }

    // T18 [DER]: Cataract high -> Routine (BR-SCR-04)
    if (input.cataractBand == SemanticBand.high) {
      addFlag(
        conditionCode: 'COND_CATARACT',
        markerCode: 'CATARACT_BAND',
        description: 'Visible lens opacity on front-of-eye photo',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T19 [DER]: Child eye refer (squint / reflex asymmetry) -> Routine (BR-SCR-04)
    if (input.childEyeBand == SemanticBand.refer && !input.childWhitePupil) {
      addFlag(
        conditionCode: 'COND_CHILD_EYE',
        markerCode: 'CHILD_EYE_BAND',
        description: 'Squint or red-reflex asymmetry on child eye photo',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T20 / T21 [DER]: Diabetic retinopathy referable -> Routine; sight-threatening (PDR / DME) -> Urgent
    if (input.drSightThreatening) {
      addFlag(
        conditionCode: 'COND_DR',
        markerCode: 'DR_REFERABLE',
        description:
            'Sight-threatening diabetic retinopathy (PDR or macular oedema) on fundus photo',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-SCR-02',
      );
    } else if (input.drReferable) {
      addFlag(
        conditionCode: 'COND_DR',
        markerCode: 'DR_REFERABLE',
        description:
            'Referable diabetic retinopathy (moderate NPDR or worse) on fundus photo',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T22 [DER]: Glaucoma suspect -> Routine (BR-SCR-04)
    if (input.glaucomaSuspect) {
      addFlag(
        conditionCode: 'COND_GLAUCOMA',
        markerCode: 'GLAUCOMA_SUSPECT',
        description: 'Glaucoma suspect (optic-disc cupping) on fundus photo',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T23 [DER]: Newborn jaundice at/above the phototherapy line -> Urgent; near the line -> Routine recheck
    if (input.neoJaundiceBand == SemanticBand.high) {
      addFlag(
        conditionCode: 'COND_NEO_JAUNDICE',
        markerCode: 'NEO_JAUNDICE_BAND',
        description:
            'Newborn skin colour at or above the hour-specific phototherapy-consideration line',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-SCR-02',
      );
    } else if (input.neoJaundiceBand == SemanticBand.borderline) {
      addFlag(
        conditionCode: 'COND_NEO_JAUNDICE',
        markerCode: 'NEO_JAUNDICE_BAND',
        description:
            'Newborn skin colour within 3 mg/dL of the phototherapy line — recheck in 6–12 h',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T24 / T25 [DER]: Diabetic foot ulcer -> Urgent; at risk -> Routine
    if (input.dfuClass == SemanticBand.ulcer) {
      addFlag(
        conditionCode: 'COND_DFU',
        markerCode: 'DFU_CLASS',
        description: 'Open ulcer detected on a diabetic foot photo',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-SCR-02',
      );
    } else if (input.dfuClass == SemanticBand.atRisk) {
      addFlag(
        conditionCode: 'COND_DFU',
        markerCode: 'DFU_CLASS',
        description:
            'Pre-ulcer signs (callus, cracks, colour change) or raised foot-risk category',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T26 / T27 [DER]: Suspicious skin lesion -> Urgent; needs a look -> Routine
    if (input.skinBand == SemanticBand.suspicious) {
      addFlag(
        conditionCode: 'COND_SKIN',
        markerCode: 'SKIN_BAND',
        description: 'Skin lesion with a suspicious (cancer-like) pattern',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-SCR-02',
      );
    } else if (input.skinBand == SemanticBand.refer) {
      addFlag(
        conditionCode: 'COND_SKIN',
        markerCode: 'SKIN_BAND',
        description: 'Skin lesion that needs a routine dermatology look',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T28 [DER]: Oral lesion suspicious / high_risk -> Urgent oral-medicine
    // biopsy pathway (Spec §6.4: "Suspicious/high -> urgent"; BR-SCR-02).
    if (input.oralClass == SemanticBand.suspicious ||
        input.oralClass == SemanticBand.high) {
      addFlag(
        conditionCode: 'COND_ORAL_CA',
        markerCode: 'ORAL_CLASS',
        description: input.oralClass == SemanticBand.high
            ? 'Oral lesion classed high risk (cancer-like pattern)'
            : 'Oral lesion classed suspicious (possible pre-cancer)',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-SCR-02',
      );
    } else if (input.oralClass == SemanticBand.refer) {
      // T29 [DER]: reported non-healing patch / ulcer (> 3 weeks) with a
      // not-suspicious image -> Routine oral-medicine look (BR-SCR-04).
      addFlag(
        conditionCode: 'COND_ORAL_CA',
        markerCode: 'ORAL_CLASS',
        description:
            'Mouth patch or ulcer reported for over 3 weeks — needs an oral-medicine look',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T32 [DER]: visual acuity in the worse eye beyond 0.5 logMAR (≈ 6/19)
    // — the document lists refractive error / cataract as the conditions
    // informed (Spec §9 MOV-10) -> Routine eye-exam pathway (BR-SCR-04).
    if (input.logMarWorse != null && input.logMarWorse! > 0.5 + 1e-9) {
      addFlag(
        conditionCode: 'COND_CATARACT',
        markerCode: 'LOGMAR',
        description:
            'Visual acuity ${input.logMarWorse!.toStringAsFixed(1)} logMAR in the worse eye at 40 cm (normal ≤ 0.2)',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }
    // T33 [DER]: Amsler distortion marked -> Routine macular pathway
    // (dilated fundus exam / OCT, Spec §9 MOV-11 conditions).
    if (input.amslerAbnormal == true) {
      addFlag(
        conditionCode: 'COND_MACULA',
        markerCode: 'AMSLER_ABNORMAL',
        description: 'Wavy, blurred or missing lines marked on the Amsler grid',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }
    // T34 [DER]: three or more red–green screening plates missed ->
    // Routine optometrist confirmation (Spec §9 MOV-11 conditions).
    if (input.colourPlateMisses != null && input.colourPlateMisses! >= 3) {
      addFlag(
        conditionCode: 'COND_COLOUR_VISION',
        markerCode: 'COLOUR_PLATE_SCORE',
        description:
            '${input.colourPlateMisses} red–green screening plates missed',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T35 [DER]: better-ear four-frequency average at or above the WHO 2021
    // line (Spec §8 AUD-09 normal < 20 dB HL; §13.2 "hearing loss >= 20 dB HL
    // in better ear" -> pure-tone audiometry, tympanometry, ENT; routine).
    if (input.ptaBetterEarDbHl != null && input.ptaBetterEarDbHl! >= 20) {
      addFlag(
        conditionCode: 'COND_HEARING_LOSS',
        markerCode: 'HEARING_BAND',
        description:
            'Better-ear pure-tone average ${input.ptaBetterEarDbHl!.toStringAsFixed(0)} dB HL (WHO 2021 normal < 20)',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }
    // T36 [DER]: asymmetric thresholds (>= 15 dB at two or more
    // frequencies) -> routine ENT review even when the better ear is normal.
    if (input.hearingAsymmetry) {
      addFlag(
        conditionCode: 'COND_HEARING_LOSS',
        markerCode: 'HEAR_ASYMMETRY',
        description:
            'Thresholds differ between ears by 15 dB or more at two or more pitches',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T37 [DER]: PHQ-9 item 9 > 0 -> Emergency crisis pathway (Spec §8
    // AUD-11 safety override G-37, E-AUD-005; §13.2 "Emergency if self-harm
    // risk").
    if ((input.phq9Item9 ?? 0) > 0) {
      addFlag(
        conditionCode: 'COND_MOOD',
        markerCode: 'PHQ9',
        description:
            'PHQ-9 item 9 answered (thoughts of self-harm) — crisis support shown, clinician notified',
        urgency: UrgencyLevel.emergency,
        ruleCode: 'BR-SCR-01',
      );
    }
    // T38 [DER]: PHQ-9 or GAD-7 at or above the moderate line (10) ->
    // Routine clinician follow-up (Spec §8 AUD-11, §13.2).
    if ((input.phq9Total ?? 0) >= 10 || (input.gad7Total ?? 0) >= 10) {
      addFlag(
        conditionCode: 'COND_MOOD',
        markerCode: (input.phq9Total ?? 0) >= 10 ? 'PHQ9' : 'GAD7',
        description:
            'PHQ-9 ${input.phq9Total ?? '—'} / GAD-7 ${input.gad7Total ?? '—'}: moderate or higher (≥ 10)',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }
    // T39 [DER]: heart-failure voice alert -> Urgent fluid-overload pathway
    // (Spec §8 AUD-12, §13.2 NT-proBNP/BNP, weight, electrolytes).
    if (input.hfAlert) {
      addFlag(
        conditionCode: 'COND_HF_DECOMP',
        markerCode: 'HF_ALERT',
        description:
            'Daily voice drifted from the 14-day personal baseline on consecutive days',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-SCR-02',
      );
    }

    // T30 [DER]: fall-risk signals — gait speed below 0.8 m/s (Spec §9
    // MOV-03 older-adult cut-off) or sit-to-stand count below the spec
    // age norm -> Routine falls / physiotherapy pathway (BR-SCR-04).
    if (input.gaitSpeedMs != null && input.gaitSpeedMs! < 0.8) {
      addFlag(
        conditionCode: 'COND_FALL',
        markerCode: 'GAIT_SPEED',
        description:
            'Walking speed ${input.gaitSpeedMs!.toStringAsFixed(2)} m/s is below the 0.8 m/s fall-risk cut-off',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }
    if (input.stsCount != null &&
        input.stsAgeNormMin != null &&
        input.stsCount! < input.stsAgeNormMin!) {
      addFlag(
        conditionCode: 'COND_FALL',
        markerCode: 'STS_COUNT_30S',
        description:
            '${input.stsCount} stands in 30 s is below the age norm of ${input.stsAgeNormMin}',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T31 [DER]: Parkinson's signs — tap amplitude decrement >= 20 % (Spec
    // §9 MOV-01), a tremor peak in the 4–6 Hz Parkinsonian band above the
    // noise floor (MOV-05), or the composite band refer (MOV-13) -> Routine
    // neurologist pathway (BR-SCR-04).
    if (input.tapDecrementPct != null && input.tapDecrementPct! >= 20) {
      addFlag(
        conditionCode: 'COND_PD',
        markerCode: 'TAP_DECREMENT',
        description:
            'Tap size fell ${input.tapDecrementPct!.toStringAsFixed(0)} % over 10 s (20 % or more is a bradykinesia sign)',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }
    if (input.tremorPeakHz != null &&
        input.tremorPeakHz! >= 4.0 &&
        input.tremorPeakHz! <= 6.0) {
      addFlag(
        conditionCode: 'COND_PD',
        markerCode: 'TREMOR_FREQ',
        description:
            'Hand tremor peak at ${input.tremorPeakHz!.toStringAsFixed(1)} Hz above the sensor noise floor (Parkinsonian range 4–6 Hz)',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }
    if (input.pdBand == SemanticBand.refer) {
      addFlag(
        conditionCode: 'COND_PD',
        markerCode: 'PD_BAND',
        description: "Parkinson's composite score banded refer",
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T15: TB high -> Urgent (BR-SCR-02)
    if (input.tbBand == SemanticBand.high) {
      addFlag(
        conditionCode: 'COND_TB',
        markerCode: 'TB_BAND',
        description: 'High TB risk on cough screen',
        urgency: UrgencyLevel.urgent,
        ruleCode: 'BR-SCR-02',
      );
    }

    // T40 [DER]: FEV1/FVC < LLN -> Routine COND_OAD (Spec §8 AUD-05, §13.2)
    if (input.fev1FvcBelowLln) {
      addFlag(
        conditionCode: 'COND_OAD',
        markerCode: 'FEV1_FVC',
        description:
            'FEV1/FVC below the lower limit of normal on the forced-exhale test',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }
    // T41 [DER]: OAD_BAND moderate / high -> Routine COND_OAD (Spec §8 AUD-04)
    if (input.oadBand == SemanticBand.moderate ||
        input.oadBand == SemanticBand.high) {
      addFlag(
        conditionCode: 'COND_OAD',
        markerCode: 'OAD_BAND',
        description:
            'Airway obstruction risk banded ${input.oadBand!.name} on the breathing screen',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-04',
      );
    }

    // T42 [DER]: AHI_EST >= 15 (moderate / severe OSA band) -> Routine
    // COND_OSA (Spec §8 AUD-08, §13.2 home sleep test / polysomnography)
    if (input.ahiEst != null && input.ahiEst! >= 15) {
      addFlag(
        conditionCode: 'COND_OSA',
        markerCode: 'AHI_EST',
        description:
            'Apnoea–hypopnoea index ${input.ahiEst!.toStringAsFixed(1)} events/h (${input.ahiEst! >= 30 ? 'severe' : 'moderate'} band) on the overnight sleep sonar',
        urgency: UrgencyLevel.routine,
        ruleCode: 'BR-SCR-05',
      );
    }

    // Sort flags so highest urgency is ALWAYS first (T15: Urgent shown before Routine)
    flags.sort((a, b) => b.urgency.priority.compareTo(a.urgency.priority));

    UrgencyLevel highest = UrgencyLevel.none;
    for (final f in flags) {
      if (f.urgency > highest) {
        highest = f.urgency;
      }
    }

    return RiskEvaluationResult(
      highestUrgency: highest,
      firedRuleCodes: rules.toList(),
      requiresRetakeFirst: false,
      requiresRescanConfirmation: rescanFirst,
      orderedFlags: flags,
    );
  }

  /// ALG-RSK-03 & ALG-RSK-04: Personal Baseline & Meaningful Change Detection.
  /// - Baseline = median of last 3 valid values within 180 days; SD from last 10.
  /// - Change flag = change > 15% (default) OR > 2 personal SD.
  static PersonalBaselineResult evaluateBaselineAndChange({
    required List<double> historicalValidValuesWithin180Days,
    required double currentValue,
  }) {
    if (historicalValidValuesWithin180Days.length < 3) {
      return const PersonalBaselineResult(hasBaseline: false);
    }

    final last3 = historicalValidValuesWithin180Days.sublist(
      historicalValidValuesWithin180Days.length - 3,
    )..sort();
    final median = last3[1];

    final lastUpTo10 = historicalValidValuesWithin180Days.length <= 10
        ? historicalValidValuesWithin180Days
        : historicalValidValuesWithin180Days.sublist(
            historicalValidValuesWithin180Days.length - 10,
          );
    final mean10 = lastUpTo10.reduce((a, b) => a + b) / lastUpTo10.length;
    double sumSq = 0.0;
    for (final v in lastUpTo10) {
      final d = v - mean10;
      sumSq += d * d;
    }
    final sd = lastUpTo10.length > 1
        ? math.sqrt(sumSq / (lastUpTo10.length - 1))
        : 0.0;

    final absDiff = (currentValue - median).abs();
    final changePct = median != 0
        ? ((currentValue - median) / median) * 100.0
        : 0.0;
    final exceeds15Pct = changePct.abs() > 15.0;
    final exceeds2Sd = sd > 0 && absDiff > 2.0 * sd;

    return PersonalBaselineResult(
      hasBaseline: true,
      baselineMedian: median,
      baselineSd: sd,
      changePct: changePct,
      isMeaningfulChange: exceeds15Pct || exceeds2Sd,
    );
  }

  /// ALG-RSK-06: Result Confidence
  /// Product of capture quality score, model confidence, and context factor
  /// (0.8 if caffeine/smoke/exercise in last 30 min). Hidden when < 0.6.
  static double computeResultConfidence({
    required double captureQualityScore,
    required double modelConfidence,
    required bool hasRecentCaffeineSmokeOrExercise,
  }) {
    final contextFactor = hasRecentCaffeineSmokeOrExercise ? 0.8 : 1.0;
    return (captureQualityScore * modelConfidence * contextFactor).clamp(
      0.0,
      1.0,
    );
  }

  /// ALG-RSK-07: Flag Aggregation
  /// Merge same condition within 30 days into existing open case; never create duplicate open cases.
  static List<CaseRecord> mergeFlagsIntoCases({
    required List<CaseRecord> existingCases,
    required List<ConditionFlag> newFlags,
    required String subjectId,
  }) {
    final updated = List<CaseRecord>.from(existingCases);

    for (final flag in newFlags) {
      final existingIndex = updated.indexWhere(
        (c) =>
            c.subjectId == subjectId &&
            c.conditionCode == flag.conditionCode &&
            c.canMergeFlagAt(flag.createdAt),
      );

      if (existingIndex >= 0) {
        final current = updated[existingIndex];
        final mergedFlags = [...current.flags, flag];
        final highest = flag.urgency > current.highestUrgency
            ? flag.urgency
            : current.highestUrgency;
        updated[existingIndex] = current.copyWith(
          flags: mergedFlags,
          highestUrgency: highest,
        );
      } else {
        final spec = ConfirmatoryInvestigationsRegistry.forCode(
          flag.conditionCode,
        );
        updated.add(
          CaseRecord(
            caseId: 'case_${flag.conditionCode}_${updated.length + 1}',
            subjectId: subjectId,
            conditionCode: flag.conditionCode,
            conditionTitle: spec.markerOrScreenName,
            openedAt: flag.createdAt,
            highestUrgency: flag.urgency,
            flags: [flag],
            confirmatorySpec: spec,
          ),
        );
      }
    }

    // Keep cases sorted with highest urgency first (T15)
    updated.sort(
      (a, b) => b.highestUrgency.priority.compareTo(a.highestUrgency.priority),
    );
    return updated;
  }
}
