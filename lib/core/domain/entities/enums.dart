// Core domain enumerations for VitalsMirror.
// Maps directly to Docs/00_README_Index.md, Docs/07_Feature_Lifecycle_and_States.md,
// and Docs/08_Health_Readings_and_Metrics.md.

enum FeatureLifecycleState {
  notStarted('Not Started', 'Feature or session has not been started yet.'),
  initializing(
    'Initializing',
    'Hardware, sensors, or master configurations are initializing.',
  ),
  permissionRequired(
    'Permission Required',
    'Requires OS runtime permission or clinical consent.',
  ),
  permissionGranted(
    'Permission Granted',
    'Required permissions and consents are verified.',
  ),
  permissionDenied(
    'Permission Denied',
    'Permission or consent was declined by the user.',
  ),
  ready('Ready', 'All prerequisites, permissions, and quality checks pass.'),
  loading('Loading', 'Loading profile, history, or master reference tables.'),
  processing(
    'Processing',
    'Running signal pipeline, DSP, ML inference, or risk engine.',
  ),
  success(
    'Success',
    'Capture and calculation passed quality and confidence gates.',
  ),
  failed(
    'Failed',
    'Capture quality or signal SNR failed after allowed attempts.',
  ),
  retry(
    'Retry',
    'Guided retake in progress within the 3-attempt limit (G-25).',
  ),
  completed(
    'Completed',
    'Session persisted and Risk Engine cases updated (ALG-RSK-07).',
  ),
  disabled(
    'Disabled',
    'Blocked by age/condition eligibility, device calibration, or release gate.',
  ),
  expired(
    'Expired',
    'Time-bounded calibration (30d BP) or pairing window has expired.',
  );

  const FeatureLifecycleState(this.label, this.description);
  final String label;
  final String description;
}

enum GateId {
  g01('G-01', 'Authenticated Session', 'Access'),
  g02('G-02', 'Basic Profile Complete (DOB, Sex, Height, Weight)', 'Data'),
  g03(
    'G-03',
    'Extended Profile (Waist, Family History, Activity, Pregnancy)',
    'Data',
  ),
  g04('G-04', 'Screening Consent Signed', 'Consent'),
  g05('G-05', 'Dental Consent Signed (Guardian for Children)', 'Consent'),
  g06('G-06', 'Training-Data Consent (Optional Non-Blocking)', 'Consent'),
  g07('G-07', 'Clinician Pathway Active (Mood Screen)', 'Access'),
  g08('G-08', 'Heart-Failure Programme Enrolment', 'Access'),
  g09('G-09', 'Age Eligibility per Screen', 'Eligibility'),
  g10(
    'G-10',
    'Condition / History Eligibility (Diabetes, Tobacco)',
    'Eligibility',
  ),
  g11('G-11', 'Camera Permission', 'Permission'),
  g12('G-12', 'Microphone Permission', 'Permission'),
  g13(
    'G-13',
    'Motion Sensors Available (50 Hz Accel / 100 Hz Gyro)',
    'Permission',
  ),
  g14('G-14', 'Notification Permission (Non-Blocking)', 'Permission'),
  g15('G-15', 'Bluetooth / Nearby Devices Permission', 'Permission'),
  g16('G-16', 'Device Model Supported in mst_device_model', 'Device'),
  g17('G-17', 'Microphone Self-Check Passed (ALG-CAP-11 <= 6 dB)', 'Device'),
  g18('G-18', 'Room Noise <= 45 dBA (ALG-CAP-12)', 'Environment'),
  g19('G-19', 'Earphones Connected (Hearing Test)', 'Device'),
  g20('G-20', '24-Patch Colour Card Detected (ALG-CAP-10 dE <= 5)', 'Capture'),
  g21('G-21', 'Real-Time Capture Quality Passed (ALG-CAP)', 'Capture'),
  g22(
    'G-22',
    'Signal Quality & Clean Beat Count Passed (ALG-PUL-09)',
    'Processing',
  ),
  g23('G-23', 'Result Confidence >= 0.60 (ALG-RSK-06)', 'Display'),
  g24('G-24', 'Algorithm Release Status Allows Display', 'Display'),
  g25('G-25', 'Retake Limit (Max 3 Attempts)', 'Flow'),
  g26('G-26', 'BP Personal Cuff Calibration Valid (<= 30 Days)', 'Data'),
  g27('G-27', 'Irregular Rhythm Confirmation (2 Scans or 1 + Ring)', 'Flow'),
  g28('G-28', 'Personal Baseline Available (3 Scans / 14 Days HF)', 'Data'),
  g29('G-29', 'Formula Input Completeness (ALG-FRM)', 'Data'),
  g30(
    'G-30',
    'Sleep Setup: Charging & Bedside 0.3-1 m (>= 4h for OSA)',
    'Environment',
  ),
  g31('G-31', 'Partner Clip-On Fundus Camera Connected', 'Device'),
  g32('G-32', 'Smart Ring Connected (Optional Enhancer)', 'Device'),
  g33('G-33', 'Face Distance 40 +/- 5 cm (ALG-CAP-15 Vision)', 'Capture'),
  g34(
    'G-34',
    'Screening Schedule / Frequency (Monthly Foot / Daily HF)',
    'Flow',
  ),
  g35('G-35', 'Programme Entitlement', 'Access'),
  g36('G-36', 'Network Connectivity (Sync / Cloud Inference)', 'System'),
  g37('G-37', 'Safety Escalation Override (Emergency / Crisis)', 'Safety');

  const GateId(this.code, this.title, this.category);
  final String code;
  final String title;
  final String category;
}

enum UrgencyLevel {
  none('None', 0),
  routine('Routine', 1),
  urgent('Urgent', 2),
  emergency('Emergency', 3);

  const UrgencyLevel(this.label, this.priority);
  final String label;
  final int priority;

  bool operator >(UrgencyLevel other) => priority > other.priority;
}

enum SemanticBand {
  normal('Normal'),
  low('Low Risk'),
  regular('Regular'),
  borderline('Borderline'),
  elevated('Elevated'),
  moderate('Moderate'),
  mild('Mild'),
  prediabetesRisk('Prediabetes Risk'),
  atRisk('At Risk'),
  suspicious('Suspicious'),
  critical('Critical'),
  high('High'),
  diabetesRisk('Diabetes Risk'),
  irregular('Irregular'),
  ulcer('Ulcer'),
  severe('Severe'),
  refer('Refer'),
  emergency('Emergency / Positive'),
  notAssessed('Not Assessed'),
  notAvailable('Not Available'),
  hidden('Hidden'),
  inValidation('In Validation'),
  rangeNotAvailable('Range Pending Cohort'),
  needsConfirmation('Needs Confirmation (1/2)');

  const SemanticBand(this.label);
  final String label;
}

enum AlgorithmReleaseStatus {
  validated('Validated'),
  bandOnly('Band-Only Display'),
  research('Research Only (Internal)'),
  disabled('Disabled');

  const AlgorithmReleaseStatus(this.label);
  final String label;
}

enum MarkerDisplayStatus {
  ok,
  bandOnly,
  rangeNotAvailable,
  needsConfirmation,
  underSpecialistReview,
  lowConfidenceHidden,
  qualityRetakeRequired,
  notAvailable,
  notAssessed,
  inValidation,
  internalOnly,
}

enum VitalsCaptureMode {
  face('Face Scan (rPPG · 60 s)'),
  finger('Finger Scan (Rear Camera + Torch · 30–60 s)');

  const VitalsCaptureMode(this.label);
  final String label;
}

enum BiologicalSex {
  male('Male', 1),
  female('Female', 0);

  const BiologicalSex(this.label, this.deurenbergCode);
  final String label;
  final int deurenbergCode; // Spec §5 ALG-FRM-11: male = 1, female = 0
}

enum AppUserRole {
  member('Member / Self'),
  guardian('Guardian (Parent)'),
  operator('Field Operator (School / Anganwadi / Clinic)');

  const AppUserRole(this.label);
  final String label;
}

enum ConsentType {
  screening('G-04', 'Health Screening Consent', true),
  dentalGuardian('G-05', 'Dental & Guardian Screening Consent', true),
  trainingData('G-06', 'Anonymised Model Training Consent', false),
  clinicianMoodPathway('G-07', 'Clinician Mood Pathway Authorization', false),
  heartFailureProgramme(
    'G-08',
    'Heart-Failure Voice Monitoring Enrolment',
    false,
  );

  const ConsentType(this.gateCode, this.title, this.isCoreScreening);
  final String gateCode;
  final String title;
  final bool isCoreScreening;
}

enum ImageScreenType {
  anaemia(
    id: 'ALG-IMG-01',
    title: 'Anaemia (Lower Eyelid)',
    conditionCode: 'COND_ANAEMIA',
    viewsRequired: [
      'Left Lower Eyelid (Flash On)',
      'Right Lower Eyelid (Flash On)',
    ],
    flashRequired: true,
    colourCardPolicy: ColourCardPolicy.preferred,
    purpose: 'Estimate haemoglobin band from palpebral conjunctiva colour.',
  ),
  adultJaundice(
    id: 'ALG-IMG-02',
    title: 'Jaundice (Adult Sclera)',
    conditionCode: 'COND_JAUNDICE',
    viewsRequired: ['Left Eye Looking Up', 'Right Eye Looking Up'],
    flashRequired: true,
    colourCardPolicy: ColourCardPolicy.required,
    purpose: 'Flag raised bilirubin (>2.5 mg/dL) from yellow sclera.',
  ),
  cataract(
    id: 'ALG-IMG-03',
    title: 'Cataract (Lens Opacity)',
    conditionCode: 'COND_CATARACT',
    viewsRequired: ['Left Eye Front (Flash)', 'Right Eye Front (Flash)'],
    flashRequired: true,
    colourCardPolicy: ColourCardPolicy.none,
    purpose:
        'Detect visible lens opacity (offered to age >= 40 or on request).',
  ),
  oralLesion(
    id: 'ALG-IMG-04',
    title: 'Oral Lesion Screen',
    conditionCode: 'COND_ORAL_CA',
    viewsRequired: [
      'Left Cheek Lining',
      'Right Cheek Lining',
      'Tongue Left Border',
      'Tongue Right Border',
      'Floor of Mouth',
      'Palate',
    ],
    flashRequired: true,
    colourCardPolicy: ColourCardPolicy.none,
    purpose:
        'Triage oral pre-cancer and cancer (always offered to tobacco/areca users).',
  ),
  diabeticFoot(
    id: 'ALG-IMG-05',
    title: 'Diabetic Foot Check',
    conditionCode: 'COND_DFU',
    viewsRequired: ['Left Sole & Heel', 'Right Sole & Heel', 'Between Toes'],
    flashRequired: false,
    colourCardPolicy: ColourCardPolicy.required,
    purpose:
        'Detect ulcers, callus, and pre-ulcer signs; measure wound area (cm2).',
  ),
  childEye(
    id: 'ALG-IMG-06',
    title: 'Child Eye Screen (Ages 1–12)',
    conditionCode: 'COND_CHILD_EYE',
    viewsRequired: ['Both Eyes Flash Photo in Dim Room (0.5–1 m)'],
    flashRequired: true,
    colourCardPolicy: ColourCardPolicy.none,
    purpose:
        'Red-reflex asymmetry, Hirschberg squint degrees, and urgent white pupil.',
  ),
  newbornJaundice(
    id: 'ALG-IMG-07',
    title: 'Newborn Jaundice (0–28 Days)',
    conditionCode: 'COND_NEO_JAUNDICE',
    viewsRequired: [
      'Forehead Skin with Colour Card',
      'Chest Skin with Colour Card',
    ],
    flashRequired: false,
    colourCardPolicy: ColourCardPolicy.mandatory,
    purpose: 'Estimate neonatal bilirubin vs hour-specific phototherapy chart.',
  ),
  skinLesion(
    id: 'ALG-IMG-08',
    title: 'Skin Condition & Lesion Check',
    conditionCode: 'COND_SKIN',
    viewsRequired: ['Close-Up Lesion with Distance Guide'],
    flashRequired: false,
    colourCardPolicy: ColourCardPolicy.preferred,
    purpose: 'Classify common skin conditions and flag suspicious lesions.',
  ),
  fundusDrGlaucoma(
    id: 'ALG-IMG-09',
    title: 'Diabetic Retinopathy & Glaucoma (Fundus)',
    conditionCode: 'COND_DR',
    viewsRequired: [
      'Left Eye Macula-Centred',
      'Left Eye Disc-Centred',
      'Right Eye Macula-Centred',
      'Right Eye Disc-Centred',
    ],
    flashRequired: false,
    colourCardPolicy: ColourCardPolicy.none,
    purpose:
        'Partner-AI grading of retina photos for diabetic retinopathy (ICDR) and glaucoma suspicion.',
  );

  const ImageScreenType({
    required this.id,
    required this.title,
    required this.conditionCode,
    required this.viewsRequired,
    required this.flashRequired,
    required this.colourCardPolicy,
    required this.purpose,
  });

  final String id;
  final String title;
  final String conditionCode;
  final List<String> viewsRequired;
  final bool flashRequired;
  final ColourCardPolicy colourCardPolicy;
  final String purpose;
}

enum ColourCardPolicy {
  none('Not Required'),
  preferred('Preferred (Improves Colour Accuracy)'),
  required('Required for Calibration / Size'),
  mandatory('Mandatory (Never Shows Normal Without Card)');

  const ColourCardPolicy(this.label);
  final String label;
}
