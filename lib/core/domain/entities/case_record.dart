import 'enums.dart';

class ConfirmatoryInvestigationSpec {
  const ConfirmatoryInvestigationSpec({
    required this.conditionCode,
    required this.markerOrScreenName,
    required this.appTrigger,
    required this.investigations,
    required this.usualDiagnosticCutoffs,
    required this.defaultUrgency,
    required this.pairingReferenceTest,
    required this.maxPairingGapLabel,
    required this.maxPairingHours,
    required this.pairingExclusions,
  });

  final String conditionCode;
  final String markerOrScreenName;
  final String appTrigger;
  final String investigations;
  final String usualDiagnosticCutoffs;
  final UrgencyLevel defaultUrgency;
  final String pairingReferenceTest;
  final String maxPairingGapLabel;
  final int maxPairingHours;
  final String pairingExclusions;
}

class ConditionFlag {
  const ConditionFlag({
    required this.flagId,
    required this.conditionCode,
    required this.sourceSessionId,
    required this.markerCode,
    required this.triggerDescription,
    required this.urgency,
    required this.ruleCode,
    required this.createdAt,
  });

  final String flagId;
  final String conditionCode;
  final String sourceSessionId;
  final String markerCode;
  final String triggerDescription;
  final UrgencyLevel urgency;
  final String ruleCode;
  final DateTime createdAt;
}

class ReferenceLabPairingRecord {
  const ReferenceLabPairingRecord({
    required this.id,
    required this.caseId,
    required this.referenceTestName,
    required this.resultSummary,
    required this.scanTimestamp,
    required this.referenceTimestamp,
    required this.hasExclusionPresent,
    this.exclusionNote,
    required this.maxAllowedHours,
  });

  final String id;
  final String caseId;
  final String referenceTestName;
  final String resultSummary;
  final DateTime scanTimestamp;
  final DateTime referenceTimestamp;
  final bool hasExclusionPresent;
  final String? exclusionNote;
  final int maxAllowedHours;

  int get gapHours =>
      referenceTimestamp.difference(scanTimestamp).inHours.abs();

  /// Spec §14: Pairs outside the window or broken by an exclusion are graded D
  /// and used for monitoring only (FRS REF-06).
  String get pairingGrade {
    if (hasExclusionPresent || gapHours > maxAllowedHours) {
      return 'Grade D (Monitoring only — outside window or exclusion)';
    }
    if (gapHours <= (maxAllowedHours / 4).ceil()) {
      return 'Grade A (Within prime pairing window)';
    }
    return 'Grade B (Valid training/validation pair)';
  }
}

class CaseRecord {
  const CaseRecord({
    required this.caseId,
    required this.subjectId,
    required this.conditionCode,
    required this.conditionTitle,
    required this.openedAt,
    required this.highestUrgency,
    required this.flags,
    required this.confirmatorySpec,
    this.isOpen = true,
    this.specialistReviewStatus = 'Not required',
    this.pairedLabResults = const [],
  });

  final String caseId;
  final String subjectId;
  final String conditionCode;
  final String conditionTitle;
  final DateTime openedAt;
  final UrgencyLevel highestUrgency;
  final List<ConditionFlag> flags;
  final ConfirmatoryInvestigationSpec confirmatorySpec;
  final bool isOpen;
  final String specialistReviewStatus;
  final List<ReferenceLabPairingRecord> pairedLabResults;

  /// Spec §10 ALG-RSK-07: Merge same condition within 30 days into existing open case.
  bool canMergeFlagAt(DateTime flagTime) =>
      isOpen && flagTime.difference(openedAt).inDays.abs() <= 30;

  CaseRecord copyWith({
    UrgencyLevel? highestUrgency,
    List<ConditionFlag>? flags,
    bool? isOpen,
    String? specialistReviewStatus,
    List<ReferenceLabPairingRecord>? pairedLabResults,
  }) {
    return CaseRecord(
      caseId: caseId,
      subjectId: subjectId,
      conditionCode: conditionCode,
      conditionTitle: conditionTitle,
      openedAt: openedAt,
      highestUrgency: highestUrgency ?? this.highestUrgency,
      flags: flags ?? this.flags,
      confirmatorySpec: confirmatorySpec,
      isOpen: isOpen ?? this.isOpen,
      specialistReviewStatus:
          specialistReviewStatus ?? this.specialistReviewStatus,
      pairedLabResults: pairedLabResults ?? this.pairedLabResults,
    );
  }
}

/// Complete Spec §13 Confirmatory Lab Investigations and §14 Pairing Windows Registry.
class ConfirmatoryInvestigationsRegistry {
  static const Map<String, ConfirmatoryInvestigationSpec> byCondition = {
    'COND_HTN': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_HTN',
      markerOrScreenName: 'BP band (SBP/DBP)',
      appTrigger: 'Elevated or High',
      investigations:
          'Clinic cuff BP on 2 visits or 24-h ambulatory BP; then serum creatinine + eGFR, urine ACR, fasting glucose / HbA1c, lipid profile, serum Na & K, urine routine, 12-lead ECG',
      usualDiagnosticCutoffs:
          'Hypertension: clinic >= 140/90 on >= 2 visits, 24-h mean >= 130/80, home >= 135/85',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Validated cuff, mean of 2 readings',
      maxPairingGapLabel: '<= 10 min',
      maxPairingHours: 1,
      pairingExclusions: 'Talking or moving between readings',
    ),
    'COND_HR_ABNORMAL': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_HR_ABNORMAL',
      markerOrScreenName: 'Heart rate',
      appTrigger: 'Resting > 100 or < 50 bpm',
      investigations: '12-lead ECG, TSH, CBC (Hb), serum electrolytes (K, Mg)',
      usualDiagnosticCutoffs:
          'TSH outside lab range (~0.4–4.0 mIU/L); K < 3.5 or > 5.0 mmol/L; Hb below WHO threshold',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: 'ECG, chest belt, contact PPG',
      maxPairingGapLabel: 'Simultaneous or <= 5 min',
      maxPairingHours: 1,
      pairingExclusions: 'Exercise, caffeine or smoking in previous 30 min',
    ),
    'COND_AF': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_AF',
      markerOrScreenName: 'Irregular rhythm',
      appTrigger: 'Irregular on 2 scans (or 1 scan + ring overnight flag)',
      investigations:
          '12-lead ECG; 24–48 h Holter or patch ECG; TSH; electrolytes; echocardiogram if confirmed',
      usualDiagnosticCutoffs: 'AF on ECG (irregular R-R, no P waves)',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: '12-lead ECG or patch/Holter',
      maxPairingGapLabel: 'ECG <= 1 h; Holter starting <= 7 days',
      maxPairingHours: 168,
      pairingExclusions: 'Negative label needs >= 24 h Holter, not single ECG',
    ),
    'COND_HYPOXIA': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_HYPOXIA',
      markerOrScreenName: 'SpO2 band',
      appTrigger: '< 95% (finger)',
      investigations:
          'Medical pulse oximeter; arterial blood gas if < 92%; chest X-ray; CBC',
      usualDiagnosticCutoffs:
          'SpO2 < 94% clinically low; PaO2 < 60 mmHg respiratory failure',
      defaultUrgency: UrgencyLevel.emergency,
      pairingReferenceTest: 'Medical pulse oximeter',
      maxPairingGapLabel: '<= 5 min',
      maxPairingHours: 1,
      pairingExclusions: 'Cold or poorly perfused fingers flagged by oximeter',
    ),
    'COND_INFECTION': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_INFECTION',
      markerOrScreenName: 'Respiratory rate / Temperature',
      appTrigger: 'RR > 20 at rest or Temp >= 38.0 °C',
      investigations:
          'CBC, CRP, chest X-ray, urine routine; seasonal tests (malaria, dengue NS1)',
      usualDiagnosticCutoffs: 'WBC > 11,000/uL; CRP > 10 mg/L',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: 'Chest belt / capnography / medical thermometer',
      maxPairingGapLabel: '<= 15 min',
      maxPairingHours: 1,
      pairingExclusions: 'Antipyretic in previous 4 h',
    ),
    'COND_SHOCK': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_SHOCK',
      markerOrScreenName: 'Shock index',
      appTrigger: 'Shock index > 0.9',
      investigations:
          'Emergency assessment: CBC, serum lactate, electrolytes, creatinine, blood glucose',
      usualDiagnosticCutoffs: 'Lactate > 2 mmol/L',
      defaultUrgency: UrgencyLevel.emergency,
      pairingReferenceTest: 'Simultaneous ECG + validated BP cuff',
      maxPairingGapLabel: '<= 5 min',
      maxPairingHours: 1,
      pairingExclusions: 'Talking or movement during reading',
    ),
    'COND_DM': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_DM',
      markerOrScreenName: 'Diabetes risk',
      appTrigger: 'Prediabetes or Diabetes risk band',
      investigations:
          'HbA1c, fasting plasma glucose, 75-g OGTT if borderline; then lipid profile, creatinine/eGFR, urine ACR',
      usualDiagnosticCutoffs:
          'HbA1c >= 6.5% diabetes, 5.7–6.4% prediabetes; FPG >= 126 / 100–125 mg/dL; OGTT 2-h >= 200 / 140–199 mg/dL',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Lab HbA1c (or FPG <= 7 days)',
      maxPairingGapLabel: '<= 30 days',
      maxPairingHours: 720,
      pairingExclusions:
          'Pregnancy, transfusion in previous 3 months, known Hb variant, new DM treatment',
    ),
    'COND_ANAEMIA': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_ANAEMIA',
      markerOrScreenName: 'Anaemia (Eyelid)',
      appTrigger: 'High band',
      investigations:
          'CBC (Hb, MCV, RDW), peripheral smear, serum ferritin, vitamin B12, folate, reticulocyte count; stool occult blood in adults',
      usualDiagnosticCutoffs:
          'Hb (WHO): men < 13.0, women < 12.0, pregnancy < 11.0, children 5–11 y < 11.5, 6–59 m < 11.0 g/dL; ferritin < 15 ng/mL; B12 < 200 pg/mL',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'CBC haemoglobin',
      maxPairingGapLabel: '<= 7 days',
      maxPairingHours: 168,
      pairingExclusions:
          'Transfusion, iron infusion or acute bleeding between scan and test',
    ),
    'COND_JAUNDICE': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_JAUNDICE',
      markerOrScreenName: 'Jaundice (Adult)',
      appTrigger: 'High band',
      investigations:
          'Serum bilirubin (total and direct), LFTs (ALT, AST, ALP, GGT, albumin), HBsAg, anti-HCV, ultrasound abdomen',
      usualDiagnosticCutoffs:
          'Total bilirubin > 1.2 mg/dL raised; visible jaundice ~2.5–3 mg/dL',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: 'Serum bilirubin',
      maxPairingGapLabel: '<= 2 days',
      maxPairingHours: 48,
      pairingExclusions: 'None',
    ),
    'COND_NEO_JAUNDICE': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_NEO_JAUNDICE',
      markerOrScreenName: 'Newborn jaundice',
      appTrigger: 'High band (above phototherapy-consideration line)',
      investigations:
          'Serum total bilirubin, blood group and Coombs test, G6PD',
      usualDiagnosticCutoffs:
          'Above hour-specific phototherapy line for gestation and age',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: 'Serum or transcutaneous bilirubin',
      maxPairingGapLabel: '<= 6 hours',
      maxPairingHours: 6,
      pairingExclusions: 'Phototherapy between scan and test',
    ),
    'COND_CATARACT': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_CATARACT',
      markerOrScreenName: 'Cataract',
      appTrigger: 'High band',
      investigations: 'Visual acuity, slit-lamp exam',
      usualDiagnosticCutoffs:
          'Lens opacity with visual acuity worse than 6/12 typically considered for surgery',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Slit-lamp exam',
      maxPairingGapLabel: '<= 90 days',
      maxPairingHours: 2160,
      pairingExclusions: 'Eye surgery between scan and exam',
    ),
    'COND_ORAL_CA': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_ORAL_CA',
      markerOrScreenName: 'Oral lesion',
      appTrigger: 'Suspicious / High risk',
      investigations: 'Oral-medicine exam; biopsy and histopathology',
      usualDiagnosticCutoffs:
          'Dysplasia or squamous cell carcinoma on histology',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: 'Oral-medicine exam (<= 14 d) or biopsy (<= 60 d)',
      maxPairingGapLabel: '<= 14 days (exam) / <= 60 days (biopsy)',
      maxPairingHours: 336,
      pairingExclusions: 'Treatment between scan and exam',
    ),
    'COND_DFU': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_DFU',
      markerOrScreenName: 'Diabetic foot',
      appTrigger: 'At risk / Ulcer',
      investigations:
          'Foot exam, 10-g monofilament, ABI / Doppler, wound swab culture if infected, foot X-ray if deep, HbA1c',
      usualDiagnosticCutoffs:
          'Loss of protective sensation; ABI <= 0.90; osteomyelitis on X-ray',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: 'Clinician foot exam',
      maxPairingGapLabel: '<= 3 days',
      maxPairingHours: 72,
      pairingExclusions: 'Wound treatment between',
    ),
    'COND_DR': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_DR',
      markerOrScreenName: 'Diabetic retinopathy (fundus, partner AI)',
      appTrigger: 'Referable (moderate NPDR or worse, or macular oedema)',
      investigations:
          'Dilated fundus examination by an ophthalmologist, OCT macula for oedema; HbA1c, blood pressure, lipid profile, urine ACR',
      usualDiagnosticCutoffs:
          'ICDR moderate NPDR or worse, or diabetic macular oedema on dilated exam or OCT',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Dilated fundus exam or OCT',
      maxPairingGapLabel: '<= 90 days',
      maxPairingHours: 2160,
      pairingExclusions:
          'Laser or intravitreal injection between scan and exam',
    ),
    'COND_GLAUCOMA': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_GLAUCOMA',
      markerOrScreenName: 'Glaucoma suspect (fundus, partner AI)',
      appTrigger: 'Glaucoma suspect (large cup-to-disc ratio or RNFL defect)',
      investigations:
          'Eye pressure (tonometry), OCT RNFL, visual field test, gonioscopy, dilated optic-disc exam [DER: no Spec row]',
      usualDiagnosticCutoffs:
          'Vertical cup-to-disc >= 0.6 or asymmetry >= 0.2; IOP > 21 mmHg; RNFL thinning or visual-field defect',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Ophthalmologist glaucoma work-up',
      maxPairingGapLabel: '<= 90 days',
      maxPairingHours: 2160,
      pairingExclusions: 'Glaucoma surgery or laser between scan and exam',
    ),
    'COND_SKIN': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_SKIN',
      markerOrScreenName: 'Skin condition / suspicious lesion',
      appTrigger: 'Suspicious (urgent) or Needs a look (routine)',
      investigations:
          'Dermatology examination with dermoscopy; excision or punch biopsy with histology if indicated',
      usualDiagnosticCutoffs:
          'Histology (melanoma, basal cell or squamous cell carcinoma vs benign naevus / keratosis / inflammatory dermatosis)',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: 'Dermatology exam (dermoscopy) [DER]',
      maxPairingGapLabel: '<= 30 days',
      maxPairingHours: 720,
      pairingExclusions:
          'Treatment, cryotherapy or removal between scan and exam',
    ),
    'COND_CHILD_EYE': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_CHILD_EYE',
      markerOrScreenName: 'Child eye',
      appTrigger: 'Refer / White pupil',
      investigations:
          'Paediatric eye exam: cover test, cycloplegic refraction, dilated fundus',
      usualDiagnosticCutoffs:
          'Manifest squint; significant refractive error; leukocoria',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: 'Paediatric eye exam',
      maxPairingGapLabel: '<= 30 days',
      maxPairingHours: 720,
      pairingExclusions: 'Glasses or patching started between',
    ),
    'COND_CARIES': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_CARIES',
      markerOrScreenName: 'Dental decay / Abscess',
      appTrigger: 'White spot / Cavity / Abscess sign',
      investigations:
          'Dentist exam (ICDAS), intraoral X-ray (bitewing / IOPA) as needed',
      usualDiagnosticCutoffs: 'ICDAS 1–2 early; 3–6 cavitated',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Dentist exam (ICDAS)',
      maxPairingGapLabel: '<= 14 days',
      maxPairingHours: 336,
      pairingExclusions: 'Dental treatment between scan and exam',
    ),
    'COND_GUM_DISEASE': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_GUM_DISEASE',
      markerOrScreenName: 'Gum inflammation / plaque',
      appTrigger: 'High gum-inflammation band',
      investigations:
          'Dentist periodontal probing (pocket depth, bleeding on probing); HbA1c if diabetic',
      usualDiagnosticCutoffs:
          'Pocket depth >= 4 mm or attachment loss = periodontitis; bleeding on probing = gingivitis',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Periodontal probing [DER]',
      maxPairingGapLabel: '<= 30 days',
      maxPairingHours: 720,
      pairingExclusions:
          'Scaling or periodontal treatment between scan and exam',
    ),
    'COND_TB': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_TB',
      markerOrScreenName: 'TB risk',
      appTrigger: 'High risk or TB symptoms',
      investigations:
          'Sputum NAAT (CBNAAT / TrueNat), chest X-ray, sputum smear; HIV test and blood glucose',
      usualDiagnosticCutoffs: 'NAAT positive = TB',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: 'Sputum NAAT',
      maxPairingGapLabel: '<= 14 days',
      maxPairingHours: 336,
      pairingExclusions: 'TB treatment started before sample',
    ),
    'COND_OAD': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_OAD',
      markerOrScreenName: 'COPD / Asthma / Lung Function',
      appTrigger: 'Obstruction risk or FEV1/FVC < LLN',
      investigations:
          'Spirometry before and after bronchodilator; CBC with eosinophils; chest X-ray',
      usualDiagnosticCutoffs:
          'FEV1/FVC < 0.70 (or < LLN) after bronchodilator = obstruction; reversibility >= 12% and >= 200 mL suggests asthma',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'ATS/ERS Spirometry (post-bronchodilator)',
      maxPairingGapLabel: '<= 14 days',
      maxPairingHours: 336,
      pairingExclusions: 'Exacerbation or new inhaler between',
    ),
    'COND_OSA': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_OSA',
      markerOrScreenName: 'Sleep apnoea',
      appTrigger: 'Moderate–severe band (AHI >= 15)',
      investigations:
          'Home sleep apnoea test or polysomnography; TSH; fasting glucose',
      usualDiagnosticCutoffs: 'AHI >= 5 OSA; >= 15 moderate; >= 30 severe',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Polysomnography or home sleep test',
      maxPairingGapLabel: '<= 60 days',
      maxPairingHours: 1440,
      pairingExclusions: 'Started CPAP or >= 5% weight change between',
    ),
    'COND_PD': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_PD',
      markerOrScreenName: "Parkinson's signs",
      appTrigger:
          'Refer (tap decrement >= 20 %, 4–6 Hz tremor peak, PD band refer)',
      investigations:
          'Neurologist examination (clinical diagnosis); vitamin B12 and TSH to exclude mimics; DaT-SPECT only if uncertain',
      usualDiagnosticCutoffs: 'Clinical criteria (MDS-UPDRS examination)',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Neurologist diagnosis / MDS-UPDRS exam',
      maxPairingGapLabel: '<= 90 days',
      maxPairingHours: 2160,
      pairingExclusions:
          'New dopaminergic medicine started between scan and exam',
    ),
    'COND_FALL': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_FALL',
      markerOrScreenName: 'Mobility / fall risk [DER]',
      appTrigger:
          'Gait speed < 0.8 m/s or sit-to-stand count below the age norm',
      investigations:
          'Falls clinic or physiotherapy gait & balance assessment (Timed Up and Go, Berg Balance); vision, footwear, medication and bone-health review',
      usualDiagnosticCutoffs:
          'TUG > 12 s or Berg < 45 = elevated fall risk; gait speed < 0.8 m/s (World Falls Guidelines)',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Clinician gait & balance assessment',
      maxPairingGapLabel: '<= 90 days',
      maxPairingHours: 2160,
      pairingExclusions:
          'Acute illness, new walking aid or physiotherapy started between tests',
    ),
    'COND_MACULA': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_MACULA',
      markerOrScreenName: 'Macular distortion (Amsler) [DER]',
      appTrigger: 'Wavy, blurred or missing lines marked on the Amsler grid',
      investigations:
          'Dilated fundus examination; OCT of the macula; fluorescein angiography if wet AMD is suspected; HbA1c if diabetic',
      usualDiagnosticCutoffs:
          'Drusen, pigment change, subretinal fluid or macular oedema on OCT',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Dilated fundus exam / OCT',
      maxPairingGapLabel: '<= 30 days',
      maxPairingHours: 720,
      pairingExclusions: 'Laser or injection treatment between test and exam',
    ),
    'COND_COLOUR_VISION': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_COLOUR_VISION',
      markerOrScreenName: 'Colour vision deficiency [DER]',
      appTrigger: 'Three or more red–green screening plates missed',
      investigations:
          'Optometrist colour vision test with printed Ishihara plates; Farnsworth D-15 to grade severity',
      usualDiagnosticCutoffs:
          'Ishihara: 4 or more of the 17 screening plates misread',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Printed Ishihara plates',
      maxPairingGapLabel: '<= 365 days',
      maxPairingHours: 8760,
      pairingExclusions:
          'Tinted lenses or colour-filter glasses worn at either test',
    ),
    'COND_COG': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_COG',
      markerOrScreenName: 'Cognitive / psychomotor slowing',
      appTrigger: 'Refer (cognitive screen) or marked slowing against baseline',
      investigations:
          'Clinician MoCA; B12, folate, TSH, CBC, glucose, electrolytes, calcium; CT or MRI brain',
      usualDiagnosticCutoffs: 'MoCA < 26 suggests impairment; B12 < 200 pg/mL',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Clinician MoCA',
      maxPairingGapLabel: '<= 90 days',
      maxPairingHours: 2160,
      pairingExclusions:
          'Acute illness, delirium or sedating medicines at either test',
    ),
    'COND_HEARING_LOSS': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_HEARING_LOSS',
      markerOrScreenName: 'Hearing loss (AUD-09)',
      appTrigger:
          'Better-ear pure-tone average >= 20 dB HL, or asymmetric thresholds [DER]',
      investigations: 'Pure-tone audiometry, tympanometry, ENT exam',
      usualDiagnosticCutoffs:
          'WHO 2021: hearing loss >= 20 dB HL in the better ear',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'Clinical pure-tone audiometry (sound booth)',
      maxPairingGapLabel: '<= 30 days',
      maxPairingHours: 720,
      pairingExclusions: 'Ear infection or wax removal between test and exam',
    ),
    'COND_MOOD': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_MOOD',
      markerOrScreenName: 'Depression / anxiety (AUD-11)',
      appTrigger:
          'PHQ-9 ≥ 10 or GAD-7 ≥ 10 (routine); PHQ-9 item 9 > 0 (emergency crisis, G-37)',
      investigations:
          'Clinician assessment with PHQ-9 / GAD-7; TSH, CBC, B12, vitamin D',
      usualDiagnosticCutoffs:
          'PHQ-9 ≥ 10 moderate; GAD-7 ≥ 10 moderate; vitamin D < 20 ng/mL deficiency',
      defaultUrgency: UrgencyLevel.routine,
      pairingReferenceTest: 'PHQ-9 / GAD-7 with the pathway clinician',
      maxPairingGapLabel: '<= 7 days',
      maxPairingHours: 168,
      pairingExclusions: 'None',
    ),
    'COND_HF_DECOMP': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_HF_DECOMP',
      markerOrScreenName: 'Heart-failure fluid overload (AUD-12)',
      appTrigger: 'HF_ALERT — daily voice drifted from the 14-day baseline',
      investigations:
          'NT-proBNP or BNP, echocardiogram, creatinine, electrolytes, chest X-ray, weight',
      usualDiagnosticCutoffs:
          'NT-proBNP ≥ 125 pg/mL or BNP ≥ 35 pg/mL (non-acute) supports HF',
      defaultUrgency: UrgencyLevel.urgent,
      pairingReferenceTest: 'NT-proBNP / BNP and clinician assessment',
      maxPairingGapLabel: '<= 3 days',
      maxPairingHours: 72,
      pairingExclusions: 'Diuretic change between test and review',
    ),
    'COND_STROKE': ConfirmatoryInvestigationSpec(
      conditionCode: 'COND_STROKE',
      markerOrScreenName: 'Stroke signs (FAST)',
      appTrigger: 'Positive (Face asymmetry, Arm drift, or Speech)',
      investigations:
          'Emergency: non-contrast CT or MRI brain, blood glucose, PT/INR, platelets, ECG',
      usualDiagnosticCutoffs:
          'Infarct or haemorrhage on imaging; glucose < 70 mg/dL mimic',
      defaultUrgency: UrgencyLevel.emergency,
      pairingReferenceTest: 'Brain imaging and neurologist',
      maxPairingGapLabel: 'Same day',
      maxPairingHours: 24,
      pairingExclusions: 'None',
    ),
  };

  /// Catalogue aliases (the marker catalogue says COND_COGNITIVE; the
  /// registry row is COND_COG).
  static const Map<String, String> aliases = {'COND_COGNITIVE': 'COND_COG'};

  static ConfirmatoryInvestigationSpec forCode(String code) {
    return byCondition[aliases[code] ?? code] ?? byCondition['COND_HTN']!;
  }
}
