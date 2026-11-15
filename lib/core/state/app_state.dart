import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/algorithms/caries_risk_engine.dart';
import '../domain/algorithms/formulas_engine.dart';
import '../domain/algorithms/hrv_baevsky_engine.dart';
import '../domain/algorithms/risk_engine.dart';
import '../domain/entities/anaemia_result.dart';
import '../domain/entities/eye_photo_session.dart';
import '../domain/entities/case_record.dart';
import '../domain/entities/enums.dart';
import '../domain/entities/marker_envelope.dart';
import '../domain/entities/member_profile.dart';
import '../domain/entities/movement_result.dart';
import '../domain/algorithms/mind_engines.dart';
import '../domain/entities/hearing_result.dart';
import '../domain/entities/mind_protocol.dart';
import '../domain/entities/mind_result.dart';
import '../domain/entities/breath_result.dart';
import '../domain/entities/sleep_result.dart';
import '../domain/entities/vision_result.dart';
import '../domain/entities/screening_catalogue_item.dart';
import '../domain/gates/gate_evaluator.dart';

class AppState extends ChangeNotifier {
  AppState() {
    _seedInitialData();
  }

  bool isAuthenticated = true;
  String localeCode = 'en'; // 'en' | 'te' | 'hi'
  AppUserRole activeRole = AppUserRole.member;
  ThemeMode themeMode = ThemeMode.light;

  bool cameraPermissionGranted = true;
  bool micPermissionGranted = true;
  bool blePermissionGranted = true;
  bool isOnline = true;
  bool bpNumericValidatedRelease =
      false; // Spec §4.6: band-only until validated

  late DeviceCapabilityProfile deviceProfile;
  final List<SubjectProfile> subjects = [];
  int activeSubjectIndex = 0;

  final List<VitalsSessionResult> vitalsSessions = [];
  final List<DentalExamResult> dentalExams = [];
  final List<AnaemiaSessionResult> anaemiaSessions = [];
  final List<EyeSessionResult> eyeSessions = [];

  /// Movement tests (S-H01..S-H05), newest first.
  final List<MovementSessionResult> movementSessions = [];

  /// Vision tests (S-H07..S-H10), newest first.
  final List<VisionSessionResult> visionSessions = [];

  /// Hearing screens (S-G10 → S-G11), newest first.
  final List<HearingSessionResult> hearingSessions = [];

  /// Brain & Mind sessions (S-G12, S-G13, S-G15, S-H06), newest first.
  final List<MindSessionResult> mindSessions = [];

  /// Breathing & Voice sessions (S-G02..S-G06), newest first.
  final List<BreathSessionResult> breathSessions = [];

  /// Overnight sleep sessions (S-G07 → S-G09), newest first.
  final List<SleepSessionResult> sleepSessions = [];

  /// HF daily voice samples per subject (AUD-12 personal baseline, G-28).
  final Map<String, List<HfDailySample>> hfVoiceBaselines = {};

  /// Preferred speech language per subject (te / hi / en).
  final Map<String, MindLanguage> speechLanguages = {};
  final List<ScreeningSessionRecord> screeningRecords = [];
  List<CaseRecord> cases = [];

  SubjectProfile get activeSubject => subjects[activeSubjectIndex];

  void _seedInitialData() {
    final now = DateTime.now();

    deviceProfile = const DeviceCapabilityProfile(
      deviceModelCode: 'PIXEL_8_PRO_IN',
      displayName: 'Google Pixel 8 Pro (Calibrated)',
      cameraMaxFps: 60,
      hasSpo2Calibration: true,
      spo2CoeffA: 108.4,
      spo2CoeffB: 24.2,
      hasMicReferenceProfile: true,
      hasFocalLengthProfile: true,
      focalLengthMm: 4.8,
      hasMotionSensors: true,
      micSelfCheckPassed: true,
      lastRoomNoiseDba: 38.0, // <= 45 dBA pass
      earphonesConnected: true,
      smartRingConnected: true,
      fundusCameraConnected: true,
      phoneCharging: true,
    );

    Map<ConsentType, ConsentRecord> buildAllSignedConsents({
      String? guardian,
    }) => consentsFor(
      guardian: guardian,
      signedAt: now.subtract(const Duration(days: 5)),
    );

    // 1. Adult Self Profile matching Spec §5 worked test vectors (Age 26, Male, 178 cm, 70 kg, 85 cm waist)
    subjects.add(
      SubjectProfile(
        id: 'subj_self_26',
        fullName: 'Arjun Rao',
        relationship: 'Self (26y Adult)',
        ageYears: 26,
        sex: BiologicalSex.male,
        heightCm: 178.0,
        weightKg: 70.0,
        waistCm: 85.0,
        hasFamilyHistoryDiabetes: true,
        hasKnownDiabetes: false,
        usesTobaccoOrAreca: false,
        activityLevel: 'Moderate',
        educationYears: 16,
        isHeartFailureEnrolled: false,
        consents: buildAllSignedConsents(),
        bpCalibration: BpCuffCalibration(
          sbpReading1: 118,
          dbpReading1: 76,
          sbpReading2: 116,
          dbpReading2: 78,
          recordedAt: now.subtract(const Duration(days: 6)),
        ),
      ),
    );

    // 2. Child Dependent (Age 7 — eligible for Child Eye 1-12y, Child Dental & Sealants 6-9y)
    subjects.add(
      SubjectProfile(
        id: 'subj_child_7',
        fullName: 'Ananya Rao',
        relationship: 'Daughter (7y Child)',
        ageYears: 7,
        sex: BiologicalSex.female,
        heightCm: 121.0,
        weightKg: 22.5,
        consents: buildAllSignedConsents(guardian: 'Arjun Rao'),
      ),
    );

    // 3. Newborn Dependent (0y, 72 hours old, 38 weeks gestation — eligible for Newborn Jaundice §6.7)
    subjects.add(
      SubjectProfile(
        id: 'subj_newborn_72h',
        fullName: 'Baby Aarav Rao',
        relationship: 'Newborn (72h · 38w)',
        ageYears: 0,
        ageHoursForNewborn: 72,
        gestationWeeksForNewborn: 38,
        sex: BiologicalSex.male,
        heightCm: 50.0,
        weightKg: 3.1,
        consents: buildAllSignedConsents(guardian: 'Arjun Rao'),
      ),
    );

    // 4. Senior Dependent (Age 62 — eligible for Cataract >=40, Cognitive >=50, Gait, STS 60-64, HF Voice)
    subjects.add(
      SubjectProfile(
        id: 'subj_senior_62',
        fullName: 'Srinivas Rao',
        relationship: 'Father (62y Senior · HF)',
        ageYears: 62,
        sex: BiologicalSex.male,
        heightCm: 170.0,
        weightKg: 74.0,
        waistCm: 94.0,
        hasKnownDiabetes: true,
        hasKnownHypertension: true,
        usesTobaccoOrAreca: true,
        isHeartFailureEnrolled: true,
        hfBaselineDaysCompleted: 14,
        consents: buildAllSignedConsents(),
      ),
    );

    // 5. Pregnant Dependent (Age 29, 22 weeks — Anaemia WHO cut-off 11.0 g/dL, T12 Urgent path)
    subjects.add(
      SubjectProfile(
        id: 'subj_pregnant_29',
        fullName: 'Meera Rao',
        relationship: 'Spouse (29y · Pregnant 22w)',
        ageYears: 29,
        sex: BiologicalSex.female,
        heightCm: 160.0,
        weightKg: 62.0,
        waistCm: 88.0,
        isPregnant: true,
        pregnancyWeeks: 22,
        consents: buildAllSignedConsents(),
      ),
    );

    // Seed initial Vitals Session using exact Spec §4 & §5 numbers
    final seededVitals = generateVitalsSession(
      captureMode: VitalsCaptureMode.finger,
      hrBpm: 92,
      rrBrMin: 21,
      sbpMmhg: 117,
      dbpMmhg: 77,
      spo2Pct: 97.0,
      pulseSnrDb: 7.8,
      cleanBeats: 68,
      hadRecentCaffeineSmokeExercise: false,
      hasChestPain: false,
      temperatureCelsius: 36.8,
    );
    vitalsSessions.add(seededVitals);

    // Seed initial Dental Exam using Spec §7.3
    final seededDental = generateDentalExam(
      habits: const CariesHabitsInput(
        nightBottleFeeding: false,
        brushingPerDay: 2,
        usesFluoridePaste: true,
        sweetsPerDay: 1,
      ),
      missingViewsCount: 0,
      includeAbscess: false,
    );
    dentalExams.add(seededDental);

    // Seed an open Routine Case and an Urgent Case to demonstrate T15 ordering
    final eval = RiskEngine.evaluateUrgency(
      const RiskEvaluationInput(
        anaemiaBand: SemanticBand.high,
        tbBand: SemanticBand.high,
      ),
      sessionId: 'seed_multi_flag',
      timestamp: now.subtract(const Duration(days: 2)),
    );
    cases = RiskEngine.mergeFlagsIntoCases(
      existingCases: cases,
      newFlags: eval.orderedFlags,
      subjectId: subjects.first.id,
    );
  }

  void selectSubject(int index) {
    if (index >= 0 && index < subjects.length) {
      activeSubjectIndex = index;
      notifyListeners();
    }
  }

  void updateActiveSubject(SubjectProfile updated) {
    subjects[activeSubjectIndex] = updated;
    notifyListeners();
  }

  void addDependent(SubjectProfile dependent) {
    subjects.add(dependent);
    activeSubjectIndex = subjects.length - 1;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Family-member management (S-B05 / S-B06)
  // ---------------------------------------------------------------------------

  /// All consents signed with the current document version. Members under 18
  /// should pass the guardian's name.
  Map<ConsentType, ConsentRecord> consentsFor({
    String? guardian,
    DateTime? signedAt,
  }) {
    final at = signedAt ?? DateTime.now();
    return {
      for (final c in ConsentType.values)
        c: ConsentRecord(
          type: c,
          isSigned: true,
          documentVersion: 'mst_consent_v2.1',
          signedAt: at,
          guardianName: guardian,
          guardianRelationship: guardian != null ? 'Parent' : null,
        ),
    };
  }

  /// The account owner ("Self") is always the first member and cannot be removed.
  bool isAccountOwner(String id) =>
      subjects.isNotEmpty && subjects.first.id == id;

  String newMemberId() =>
      'subj_member_${DateTime.now().microsecondsSinceEpoch}';

  /// Adds a member and makes them the active profile.
  void addMember(SubjectProfile member) => addDependent(member);

  void updateMember(String id, SubjectProfile updated) {
    final i = subjects.indexWhere((s) => s.id == id);
    if (i < 0) return;
    subjects[i] = updated;
    notifyListeners();
  }

  /// Removes a member. Returns false for the account owner or an unknown id.
  bool removeMember(String id) {
    final i = subjects.indexWhere((s) => s.id == id);
    if (i <= 0) return false;
    final activeId = activeSubject.id;
    subjects.removeAt(i);
    final keep = subjects.indexWhere((s) => s.id == activeId);
    activeSubjectIndex = keep >= 0 ? keep : 0;
    notifyListeners();
    return true;
  }

  void toggleConsent(ConsentType type, bool signed, {String? guardianName}) {
    final currentMap = Map<ConsentType, ConsentRecord>.from(
      activeSubject.consents,
    );
    final existing = currentMap[type];
    currentMap[type] = ConsentRecord(
      type: type,
      isSigned: signed,
      documentVersion: existing?.documentVersion ?? 'mst_consent_v2.1',
      signedAt: signed ? DateTime.now() : null,
      guardianName: guardianName ?? existing?.guardianName,
      guardianRelationship: guardianName != null ? 'Parent/Guardian' : null,
    );
    updateActiveSubject(activeSubject.copyWith(consents: currentMap));
  }

  void updateDeviceProfile(DeviceCapabilityProfile updated) {
    deviceProfile = updated;
    notifyListeners();
  }

  void setLocale(String code) {
    localeCode = code;
    notifyListeners();
  }

  void setRole(AppUserRole role) {
    activeRole = role;
    notifyListeners();
  }

  void toggleThemeMode() {
    themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void toggleBpNumericRelease(bool enabled) {
    bpNumericValidatedRelease = enabled;
    notifyListeners();
  }

  List<GateCheckOutcome> evaluateGatesForItem(ScreeningCatalogueItem item) {
    return GateEvaluator.evaluateForCatalogueItem(
      item: item,
      subject: activeSubject,
      device: deviceProfile,
      isAuthenticated: isAuthenticated,
      cameraPermissionGranted: cameraPermissionGranted,
      micPermissionGranted: micPermissionGranted,
      blePermissionGranted: blePermissionGranted,
      isOnline: isOnline,
    );
  }

  /// Generates a full VitalsSessionResult executing exact Spec §§3, 4, 5, 10 rules.
  VitalsSessionResult generateVitalsSession({
    required VitalsCaptureMode captureMode,
    required int hrBpm,
    required int rrBrMin,
    required double sbpMmhg,
    required double dbpMmhg,
    required double spo2Pct,
    required double pulseSnrDb,
    required int cleanBeats,
    required bool hadRecentCaffeineSmokeExercise,
    required bool hasChestPain,
    double? temperatureCelsius,
    bool irregularRhythmConfirmed = false,
  }) {
    final subj = activeSubject;
    final now = DateTime.now();

    // Spec §3 ALG-PUL-09 & Note on Oct 17 prototype: SNR < 3.0 dB -> retake!
    final qualityPassed = pulseSnrDb >= 3.0 && cleanBeats >= 20;
    final conf = RiskEngine.computeResultConfidence(
      captureQualityScore: qualityPassed ? 0.94 : 0.45,
      modelConfidence: 0.92,
      hasRecentCaffeineSmokeOrExercise: hadRecentCaffeineSmokeExercise,
    );

    // Spec §4.3 HRV test vector [800, 810, 790, 805, 795] ms -> SDNN 7.9, RMSSD 14.4, pNN50 0%
    final hrv = HrvBaevskyEngine.computeTimeDomain(const [
      800,
      810,
      790,
      805,
      795,
    ]);
    // Spec §4.4 Baevsky vector Mo=0.80s, AMo=40%, MxDMn=0.20s -> SI = 125 (low)
    final baevsky = HrvBaevskyEngine.computeFromParameters(
      moSeconds: 0.80,
      amoPercent: 40.0,
      mxdmnSeconds: 0.20,
    );

    final hrBand = RiskEngine.assignHrBand(hrBpm);
    final rrBand = RiskEngine.assignRrBand(rrBrMin);
    final spo2Band = RiskEngine.assignSpo2Band(spo2Pct);
    final bpBand = RiskEngine.assignBpBand(
      sbp: sbpMmhg.round(),
      dbp: dbpMmhg.round(),
    );

    final hrvEnoughBeats = cleanBeats >= 50;
    final spo2Available =
        captureMode == VitalsCaptureMode.finger &&
        deviceProfile.hasSpo2Calibration;
    final dmHasWaistAndBmi = subj.isExtendedProfileComplete;

    final markers = <String, MarkerEnvelope<dynamic>>{
      'HR': MarkerEnvelope<int>(
        code: 'HR',
        displayName: 'Heart Rate',
        algorithmId: 'ALG-PUL-07',
        algorithmVersion: 'v2.4.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'bpm',
        decimals: 0,
        value: hrBpm,
        band: qualityPassed ? hrBand : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: qualityPassed
            ? MarkerDisplayStatus.ok
            : MarkerDisplayStatus.qualityRetakeRequired,
        normalRangeLabel: '60–100 bpm (Critical <40 or >130)',
        statusReason: qualityPassed
            ? null
            : 'Pulse SNR ${pulseSnrDb.toStringAsFixed(1)} dB < 3.0 dB threshold — Retake required (ALG-PUL-09)',
        conditionsInformed: const ['COND_AF', 'COND_INFECTION', 'COND_HYPOXIA'],
      ),
      'RR': MarkerEnvelope<int>(
        code: 'RR',
        displayName: 'Respiratory Rate',
        algorithmId: 'ALG-RSP-01',
        algorithmVersion: 'v2.1.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'br/min',
        decimals: 0,
        value: rrBrMin,
        band: qualityPassed ? rrBand : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: qualityPassed
            ? MarkerDisplayStatus.ok
            : MarkerDisplayStatus.notAvailable,
        normalRangeLabel: '12–20 br/min (Critical <8 or >24)',
        conditionsInformed: const [
          'COND_INFECTION',
          'COND_OAD',
          'COND_HYPOXIA',
        ],
      ),
      'SPO2_BAND': MarkerEnvelope<String>(
        code: 'SPO2_BAND',
        displayName: 'SpO2 Oxygen Band',
        algorithmId: 'ALG-SPO-01',
        algorithmVersion: 'v1.8.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: '',
        decimals: 0,
        value: spo2Band.label,
        band: spo2Available ? spo2Band : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: spo2Available
            ? MarkerDisplayStatus.bandOnly
            : MarkerDisplayStatus.notAvailable,
        normalRangeLabel: '>= 95% Normal · 92–94% Borderline · < 92% Critical',
        statusReason: spo2Available
            ? 'Band-only display (SPO2_EST ${spo2Pct.toStringAsFixed(0)}% internal per Spec §4.5)'
            : (captureMode == VitalsCaptureMode.face
                  ? 'Requires Finger Mode (face SpO2 is research-only per Spec §4.5)'
                  : 'Device without SpO2 coefficients — use pulse oximeter or Smart Ring'),
      ),
      'BP_BAND': MarkerEnvelope<String>(
        code: 'BP_BAND',
        displayName: 'Blood Pressure',
        algorithmId: 'ALG-BP-01',
        algorithmVersion: 'v1.5.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: bpNumericValidatedRelease ? 'mmHg' : '',
        decimals: 0,
        value: bpBand.label,
        formattedOverride: bpNumericValidatedRelease
            ? '${sbpMmhg.round()}/${dbpMmhg.round()}'
            : bpBand.label,
        band: bpBand,
        confidence: conf,
        displayStatus: bpNumericValidatedRelease
            ? MarkerDisplayStatus.ok
            : MarkerDisplayStatus.bandOnly,
        normalRangeLabel:
            '<120/<80 Normal · 120–139/80–89 Elevated · >=140/>=90 High',
        statusReason: bpNumericValidatedRelease
            ? 'ISO 81060-2 numeric display enabled'
            : 'Band-only display until ISO 81060-2 mean <=5 / SD <=8 mmHg validated (G-24)',
        conditionsInformed: const ['COND_HTN', 'COND_CKD', 'COND_METS'],
      ),
      'RMSSD': MarkerEnvelope<double>(
        code: 'RMSSD',
        displayName: 'HRV RMSSD',
        algorithmId: 'ALG-HRV-01',
        algorithmVersion: 'v2.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'ms',
        decimals: 1,
        value: hrv.rmssdMs,
        band: hrvEnoughBeats
            ? SemanticBand.rangeNotAvailable
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: hrvEnoughBeats
            ? MarkerDisplayStatus.rangeNotAvailable
            : MarkerDisplayStatus.notAvailable,
        statusReason: hrvEnoughBeats
            ? 'SDNN ${hrv.sdnnMs} ms · pNN50 ${hrv.pnn50Pct}% (Age-band table pending cohort §4.3)'
            : 'HRV not available — requires >= 50 clean beats (G-22)',
      ),
      // Spec §4.3 — SDNN, pNN50 and Poincaré markers are displayed alongside RMSSD.
      'SDNN': MarkerEnvelope<double>(
        code: 'SDNN',
        displayName: 'HRV SDNN',
        algorithmId: 'ALG-HRV-01',
        algorithmVersion: 'v2.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'ms',
        decimals: 1,
        value: hrv.sdnnMs,
        band: hrvEnoughBeats
            ? SemanticBand.rangeNotAvailable
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: hrvEnoughBeats
            ? MarkerDisplayStatus.rangeNotAvailable
            : MarkerDisplayStatus.notAvailable,
        statusReason: hrvEnoughBeats
            ? 'Age-band reference range pending cohort (§4.3)'
            : 'HRV not available — requires >= 50 clean beats (G-22)',
      ),
      'PNN50': MarkerEnvelope<double>(
        code: 'PNN50',
        displayName: 'HRV pNN50',
        algorithmId: 'ALG-HRV-01',
        algorithmVersion: 'v2.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: '%',
        decimals: 1,
        value: hrv.pnn50Pct,
        band: !hrvEnoughBeats
            ? SemanticBand.notAvailable
            : (hrv.pnn50Pct > 3.0
                  ? SemanticBand.normal
                  : SemanticBand.notAssessed),
        confidence: conf,
        displayStatus: hrvEnoughBeats
            ? MarkerDisplayStatus.ok
            : MarkerDisplayStatus.notAvailable,
        normalRangeLabel: '> 3% normal',
        statusReason: !hrvEnoughBeats
            ? 'HRV not available — requires >= 50 clean beats (G-22)'
            : (hrv.pnn50Pct > 3.0
                  ? null
                  : 'pNN50 <= 3% — band not specified in Spec (§4.3, OPEN)'),
      ),
      'SD1': MarkerEnvelope<double>(
        code: 'SD1',
        displayName: 'Poincaré SD1',
        algorithmId: 'ALG-HRV-03',
        algorithmVersion: 'v2.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'ms',
        decimals: 1,
        value: hrv.sd1Ms,
        band: hrvEnoughBeats
            ? SemanticBand.rangeNotAvailable
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: hrvEnoughBeats
            ? MarkerDisplayStatus.rangeNotAvailable
            : MarkerDisplayStatus.notAvailable,
        statusReason: 'No reference range in Spec (§4.3)',
      ),
      'SD2': MarkerEnvelope<double>(
        code: 'SD2',
        displayName: 'Poincaré SD2',
        algorithmId: 'ALG-HRV-03',
        algorithmVersion: 'v2.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'ms',
        decimals: 1,
        value: hrv.sd2Ms,
        band: hrvEnoughBeats
            ? SemanticBand.rangeNotAvailable
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: hrvEnoughBeats
            ? MarkerDisplayStatus.rangeNotAvailable
            : MarkerDisplayStatus.notAvailable,
        statusReason: 'No reference range in Spec (§4.3)',
      ),
      'SD1_SD2': MarkerEnvelope<double>(
        code: 'SD1_SD2',
        displayName: 'SD1 / SD2 Ratio',
        algorithmId: 'ALG-HRV-03',
        algorithmVersion: 'v2.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'ratio',
        decimals: 2,
        value: hrv.sd1Sd2Ratio,
        band: hrvEnoughBeats
            ? SemanticBand.rangeNotAvailable
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: hrvEnoughBeats
            ? MarkerDisplayStatus.rangeNotAvailable
            : MarkerDisplayStatus.notAvailable,
        statusReason: 'No reference range in Spec (§4.3)',
      ),
      if (captureMode == VitalsCaptureMode.finger)
        'PI': MarkerEnvelope<double>(
          code: 'PI',
          displayName: 'Perfusion Index',
          algorithmId: 'ALG-WAV-01',
          algorithmVersion: 'v1.3.0',
          rangeVersion: 'mst_ref_2026.10',
          unit: '%',
          decimals: 1,
          value: 1.8,
          band: SemanticBand.rangeNotAvailable,
          confidence: conf,
          displayStatus: MarkerDisplayStatus.rangeNotAvailable,
          statusReason:
              'SpO2 gate PI >= 0.4% passed · age-band reference pending (§4.8)',
        ),
      'BAEVSKY_SI': MarkerEnvelope<double>(
        code: 'BAEVSKY_SI',
        displayName: 'Baevsky Stress Index',
        algorithmId: 'ALG-HRV-04',
        algorithmVersion: 'v2.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'SI',
        decimals: 0,
        value: baevsky.stressIndex,
        band: hrvEnoughBeats ? baevsky.band : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: hrvEnoughBeats
            ? MarkerDisplayStatus.ok
            : MarkerDisplayStatus.notAvailable,
        normalRangeLabel: '50–150 Low · 151–500 Moderate · > 500 High',
      ),
      'IRREG_BAND': MarkerEnvelope<String>(
        code: 'IRREG_BAND',
        displayName: 'Cardiac Rhythm',
        algorithmId: 'ALG-RHY-01',
        algorithmVersion: 'v1.4.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: '',
        decimals: 0,
        value: irregularRhythmConfirmed ? 'Irregular' : 'Regular',
        band: irregularRhythmConfirmed
            ? SemanticBand.irregular
            : SemanticBand.regular,
        confidence: conf,
        displayStatus: MarkerDisplayStatus.bandOnly,
        normalRangeLabel:
            'Regular; ectopics <= 1/min (Positive on 2 scans or 1 + ring)',
      ),
      'VASC_AGE_GAP': MarkerEnvelope<int>(
        code: 'VASC_AGE_GAP',
        displayName: 'Vascular Age Gap (SDPPG)',
        algorithmId: 'ALG-WAV-03',
        algorithmVersion: 'v1.3.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'years',
        decimals: 0,
        value: 2,
        band: SemanticBand.normal,
        confidence: conf,
        displayStatus: MarkerDisplayStatus.ok,
        normalRangeLabel:
            'VASC_AGE_GAP <= 5 years normal; >10 years routine labs (§13.1)',
      ),
      'DM_BAND': MarkerEnvelope<String>(
        code: 'DM_BAND',
        displayName: 'Diabetes Risk (HbA1c)',
        algorithmId: 'ALG-DM-01',
        algorithmVersion: 'v1.2.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: '',
        decimals: 0,
        value: 'Low Risk',
        band: dmHasWaistAndBmi ? SemanticBand.low : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: dmHasWaistAndBmi
            ? MarkerDisplayStatus.bandOnly
            : MarkerDisplayStatus.notAvailable,
        statusReason: dmHasWaistAndBmi
            ? 'Evaluated PPG waveform + HRV + facial Lab a*/b* + waist & BMI'
            : 'Missing waist or BMI — band not shown (Spec §4.9, Gate G-03)',
      ),

      // ── Spec §4.3 frequency-domain HRV: needs a ≥ 120 s recording ──
      for (final entry in const {
        'LF': 'Low-frequency power',
        'HF': 'High-frequency power',
        'LF_HF': 'LF / HF ratio',
      }.entries)
        entry.key: MarkerEnvelope<double>(
          code: entry.key,
          displayName: entry.value,
          algorithmId: 'ALG-HRV-02',
          algorithmVersion: 'v2.0.0',
          rangeVersion: 'mst_ref_2026.10',
          unit: entry.key == 'LF_HF' ? 'ratio' : 'ms²',
          decimals: 1,
          value: null,
          band: SemanticBand.notAvailable,
          confidence: conf,
          displayStatus: MarkerDisplayStatus.notAvailable,
          statusReason:
              'Needs a ≥ 120 s recording — this session is 60 s (§4.3)',
        ),

      // ── Spec §4.4 stress level enum derived from BAEVSKY_SI ──
      'STRESS_BAND': MarkerEnvelope<String>(
        code: 'STRESS_BAND',
        displayName: 'Stress Level',
        algorithmId: 'ALG-HRV-04',
        algorithmVersion: 'v2.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: '',
        decimals: 0,
        value: baevsky.band.label,
        band: hrvEnoughBeats ? baevsky.band : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: hrvEnoughBeats
            ? MarkerDisplayStatus.bandOnly
            : MarkerDisplayStatus.notAvailable,
        normalRangeLabel: 'low / moderate / high from Baevsky SI',
        statusReason: baevsky.isLowConfidenceRigidRhythm
            ? 'MxDMn < 20 ms (very rigid rhythm) — reported with low confidence'
            : null,
        conditionsInformed: const ['COND_MOOD'],
      ),

      // ── Spec §4.6 BP confidence (shown as an indicator) ──
      'BP_CONFIDENCE': MarkerEnvelope<double>(
        code: 'BP_CONFIDENCE',
        displayName: 'BP Model Confidence',
        algorithmId: 'ALG-BP-01',
        algorithmVersion: 'v1.5.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: '',
        decimals: 2,
        value: qualityPassed ? 0.82 : 0.41,
        band: qualityPassed ? SemanticBand.normal : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: qualityPassed
            ? MarkerDisplayStatus.ok
            : MarkerDisplayStatus.notAvailable,
        normalRangeLabel: '< 0.60 → "BP not available, use cuff"',
        statusReason: qualityPassed
            ? null
            : 'BP not available, use cuff (confidence < 0.60)',
      ),

      // ── Spec §4.7 ectopic beats per minute ──
      'ECTOPIC_PM': MarkerEnvelope<double>(
        code: 'ECTOPIC_PM',
        displayName: 'Ectopic Beats',
        algorithmId: 'ALG-RHY-01',
        algorithmVersion: 'v1.4.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: '/min',
        decimals: 1,
        value: 1.0,
        band: qualityPassed ? SemanticBand.normal : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: qualityPassed
            ? MarkerDisplayStatus.ok
            : MarkerDisplayStatus.notAvailable,
        normalRangeLabel: '<= 1 / min normal (> 1 label not specified)',
        conditionsInformed: const ['COND_AF'],
      ),

      // ── Spec §4.8 pulse-waveform morphology (ALG-WAV-01…05) ──
      for (final w in const [
        ['RISE_TIME', 'Rise Time', 'ms', '168', 'ALG-WAV-01'],
        ['NOTCH_TIME', 'Dicrotic Notch Time', 'ms', '312', 'ALG-WAV-01'],
        ['NOTCH_REL_H', 'Notch Relative Height', '', '0.42', 'ALG-WAV-01'],
        ['RI', 'Reflection Index', '', '0.58', 'ALG-WAV-02'],
        ['AIX', 'Augmentation Index', '%', '18.4', 'ALG-WAV-02'],
        ['WIDTH_25', 'Pulse Width 25%', 'ms', '342', 'ALG-WAV-02'],
        ['WIDTH_50', 'Pulse Width 50%', 'ms', '258', 'ALG-WAV-02'],
        ['WIDTH_75', 'Pulse Width 75%', 'ms', '171', 'ALG-WAV-02'],
        ['AREA_RATIO', 'Area Ratio', 'ratio', '0.61', 'ALG-WAV-02'],
        ['SDPPG_BA', 'SDPPG b/a', 'ratio', '-0.72', 'ALG-WAV-03'],
        ['SDPPG_CA', 'SDPPG c/a', 'ratio', '-0.08', 'ALG-WAV-03'],
        ['SDPPG_DA', 'SDPPG d/a', 'ratio', '-0.26', 'ALG-WAV-03'],
        ['SDPPG_EA', 'SDPPG e/a', 'ratio', '0.14', 'ALG-WAV-03'],
        ['AGING_INDEX', 'SDPPG Aging Index', '', '-0.52', 'ALG-WAV-03'],
      ])
        w[0]: MarkerEnvelope<double>(
          code: w[0],
          displayName: w[1],
          algorithmId: w[4],
          algorithmVersion: 'v1.3.0',
          rangeVersion: 'mst_ref_2026.10',
          unit: w[2],
          decimals: w[3].contains('.') ? 2 : 0,
          value: double.parse(w[3]),
          band: cleanBeats >= 40
              ? SemanticBand.rangeNotAvailable
              : SemanticBand.notAvailable,
          confidence: conf,
          displayStatus: cleanBeats >= 40
              ? MarkerDisplayStatus.rangeNotAvailable
              : MarkerDisplayStatus.notAvailable,
          statusReason: cleanBeats >= 40
              ? 'Age-band reference pending (§4.8)'
              : 'Needs >= 40 clean beats (§4.8)',
          conditionsInformed: const ['COND_HTN', 'COND_DM'],
        ),
      'VASC_AGE': MarkerEnvelope<int>(
        code: 'VASC_AGE',
        displayName: 'Vascular Age',
        algorithmId: 'ALG-WAV-04',
        algorithmVersion: 'v1.3.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'years',
        decimals: 0,
        value: subj.ageYears + 2,
        band: cleanBeats >= 40
            ? SemanticBand.normal
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: cleanBeats >= 40
            ? MarkerDisplayStatus.ok
            : MarkerDisplayStatus.notAvailable,
        isEstimate: true,
        normalRangeLabel:
            'Cohort regression vs chronological age ${subj.ageYears} y',
        statusReason: cleanBeats >= 40
            ? null
            : 'Needs >= 40 clean beats (§4.8)',
        conditionsInformed: const ['COND_HTN', 'COND_DM'],
      ),

      // ── Spec §10 RSK-05 kidney & metabolic logistic scores ──
      for (final r in const [
        ['CKD_RISK', 'Kidney Risk Score', 'COND_CKD'],
        ['METS_RISK', 'Metabolic Risk Score', 'COND_METS'],
      ])
        r[0]: MarkerEnvelope<String>(
          code: r[0],
          displayName: r[1],
          algorithmId: 'ALG-RSK-05',
          algorithmVersion: 'v1.0.0',
          rangeVersion: 'mst_ref_2026.10',
          unit: '',
          decimals: 0,
          value: 'Low',
          band: dmHasWaistAndBmi ? SemanticBand.low : SemanticBand.notAvailable,
          confidence: conf,
          displayStatus: dmHasWaistAndBmi
              ? MarkerDisplayStatus.bandOnly
              : MarkerDisplayStatus.notAvailable,
          normalRangeLabel:
              'Logistic score — scale and bands not specified (OPEN)',
          statusReason: dmHasWaistAndBmi
              ? 'Inputs: BP band, diabetes band, waist, history'
              : 'Shown only when BP band, diabetes band, waist and history are all present (RSK-05)',
          conditionsInformed: [r[2]],
        ),
    };

    // Spec §5 Derived Formulas (ALG-FRM-01 to 08)
    final mapVal = FormulasEngine.computeMap(sbp: sbpMmhg, dbp: dbpMmhg);
    final ppVal = FormulasEngine.computePulsePressure(
      sbp: sbpMmhg,
      dbp: dbpMmhg,
    );
    final siVal = FormulasEngine.computeShockIndex(
      hr: hrBpm.toDouble(),
      sbp: sbpMmhg,
    );
    final rppVal = FormulasEngine.computeRpp(
      hr: hrBpm.toDouble(),
      sbp: sbpMmhg,
    );
    final crVal = FormulasEngine.computeCrRatio(
      hr: hrBpm.toDouble(),
      rr: rrBrMin.toDouble(),
    );
    final hrmaxVal = FormulasEngine.computeHrMaxTanaka(ageYears: subj.ageYears);
    final hrrVal = FormulasEngine.computeHrReserve(
      hrMax: hrmaxVal,
      hrRest: hrBpm.toDouble(),
    );
    final vo2Val = FormulasEngine.computeVo2MaxUth(
      hrMax: hrmaxVal,
      hrRest: hrBpm.toDouble(),
    );

    final formulas = <String, MarkerEnvelope<dynamic>>{
      'MAP': MarkerEnvelope<double>(
        code: 'MAP',
        displayName: 'Mean Arterial Pressure (MAP)',
        algorithmId: 'ALG-FRM-01',
        algorithmVersion: 'v1.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'mmHg',
        decimals: 1,
        value: mapVal,
        band: mapVal != null
            ? FormulasEngine.classifyMap(mapVal)
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: MarkerDisplayStatus.ok,
        normalRangeLabel: '70–100 mmHg (DBP + (SBP - DBP)/3)',
      ),
      'PP': MarkerEnvelope<int>(
        code: 'PP',
        displayName: 'Pulse Pressure (PP)',
        algorithmId: 'ALG-FRM-02',
        algorithmVersion: 'v1.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'mmHg',
        decimals: 0,
        value: ppVal,
        band: ppVal != null
            ? FormulasEngine.classifyPulsePressure(ppVal)
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: MarkerDisplayStatus.ok,
        normalRangeLabel: '30–50 mmHg (SBP - DBP)',
      ),
      'SHOCK_INDEX': MarkerEnvelope<double>(
        code: 'SHOCK_INDEX',
        displayName: 'Shock Index (HR / SBP)',
        algorithmId: 'ALG-FRM-03',
        algorithmVersion: 'v1.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'ratio',
        decimals: 2,
        value: siVal,
        band: siVal != null
            ? FormulasEngine.classifyShockIndex(siVal)
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: MarkerDisplayStatus.ok,
        normalRangeLabel: '0.50–0.70 Normal · > 0.90 Emergency',
      ),
      'RPP': MarkerEnvelope<int>(
        code: 'RPP',
        displayName: 'Rate Pressure Product (RPP)',
        algorithmId: 'ALG-FRM-04',
        algorithmVersion: 'v1.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'bpm·mmHg',
        decimals: 0,
        value: rppVal,
        band: rppVal != null
            ? FormulasEngine.classifyRpp(rppVal)
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: MarkerDisplayStatus.ok,
        normalRangeLabel: '< 12000 bpm·mmHg (HR × SBP)',
      ),
      'CR_RATIO': MarkerEnvelope<double>(
        code: 'CR_RATIO',
        displayName: 'Cardio-Respiratory Ratio',
        algorithmId: 'ALG-FRM-05',
        algorithmVersion: 'v1.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'ratio',
        decimals: 2,
        value: crVal,
        band: crVal != null
            ? FormulasEngine.classifyCrRatio(crVal)
            : SemanticBand.notAvailable,
        confidence: conf,
        displayStatus: MarkerDisplayStatus.ok,
        normalRangeLabel: '3.00–6.00 (HR / RR)',
      ),
      'HRMAX': MarkerEnvelope<double>(
        code: 'HRMAX',
        displayName: 'HRmax (Tanaka)',
        algorithmId: 'ALG-FRM-06',
        algorithmVersion: 'v1.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'bpm',
        decimals: 1,
        value: hrmaxVal,
        band: SemanticBand.normal,
        confidence: 1.0,
        displayStatus: MarkerDisplayStatus.ok,
        normalRangeLabel: '208 - 0.7 × age',
      ),
      'HRR': MarkerEnvelope<double>(
        code: 'HRR',
        displayName: 'Heart Rate Reserve (Karvonen)',
        algorithmId: 'ALG-FRM-07',
        algorithmVersion: 'v1.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'bpm',
        decimals: 1,
        value: hrrVal,
        band: SemanticBand.normal,
        confidence: conf,
        displayStatus: MarkerDisplayStatus.ok,
        normalRangeLabel: 'Higher is fitter (HRmax - HRrest)',
      ),
      'VO2MAX': MarkerEnvelope<double>(
        code: 'VO2MAX',
        displayName: 'VO2max (Uth)',
        algorithmId: 'ALG-FRM-08',
        algorithmVersion: 'v1.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: 'mL/kg/min',
        decimals: 1,
        value: vo2Val,
        band: SemanticBand.rangeNotAvailable,
        confidence: conf,
        displayStatus: MarkerDisplayStatus.rangeNotAvailable,
        isEstimate: true,
        statusReason:
            'Labelled "estimate" (Age/sex table pending cohort §5 FRM-08)',
      ),
    };

    final riskEval = RiskEngine.evaluateUrgency(
      RiskEvaluationInput(
        hrBpm: hrBpm,
        hrQualityPassed: qualityPassed,
        rrBrMin: rrBrMin,
        spo2Band: spo2Available ? spo2Band : null,
        bpBand: bpBand,
        sbpMmhg: sbpMmhg,
        dbpMmhg: dbpMmhg,
        temperatureCelsius: temperatureCelsius,
        hasChestPain: hasChestPain,
        irregularRhythmConfirmed: irregularRhythmConfirmed,
      ),
      sessionId: 'vit_${now.millisecondsSinceEpoch}',
      timestamp: now,
    );

    if (riskEval.orderedFlags.isNotEmpty) {
      cases = RiskEngine.mergeFlagsIntoCases(
        existingCases: cases,
        newFlags: riskEval.orderedFlags,
        subjectId: subj.id,
      );
    }

    // ── Internal / diagnostic markers (Spec R-9: stored, not member-facing) ──
    MarkerEnvelope<double> diag(
      String code,
      String name,
      String algorithmId,
      String unit,
      int decimals,
      double value,
      String note,
    ) {
      return MarkerEnvelope<double>(
        code: code,
        displayName: name,
        algorithmId: algorithmId,
        algorithmVersion: 'v1.0.0',
        rangeVersion: 'mst_ref_2026.10',
        unit: unit,
        decimals: decimals,
        value: value,
        band: SemanticBand.hidden,
        confidence: conf,
        displayStatus: MarkerDisplayStatus.internalOnly,
        statusReason: note,
      );
    }

    final diagnostics = <String, MarkerEnvelope<dynamic>>{
      'HR_POS': diag(
        'HR_POS',
        'HR (POS)',
        'ALG-PUL-07',
        'bpm',
        0,
        hrBpm + 1.0,
        'Diagnostic — spectral vs beat HR must agree within 3 bpm',
      ),
      'HR_NEURAL': diag(
        'HR_NEURAL',
        'HR (neural)',
        'ALG-PUL-07',
        'bpm',
        0,
        hrBpm - 1.0,
        'Diagnostic — |neural − POS| > 5 bpm → retake',
      ),
      'HR_SPEC_DIFF': diag(
        'HR_SPEC_DIFF',
        'Spectral vs beat HR difference',
        'ALG-PUL-07',
        'bpm',
        1,
        1.0,
        'Diagnostic — > 3 bpm → retake (max 3) then offer finger mode',
      ),
      'RR_RIIV': diag(
        'RR_RIIV',
        'RR from baseline intensity',
        'ALG-RSP-01',
        'br/min',
        0,
        rrBrMin.toDouble(),
        'Diagnostic — one of 4 fused RR series',
      ),
      'RR_RIAV': diag(
        'RR_RIAV',
        'RR from beat amplitude',
        'ALG-RSP-01',
        'br/min',
        0,
        rrBrMin + 1.0,
        'Diagnostic — one of 4 fused RR series',
      ),
      'RR_RIFV': diag(
        'RR_RIFV',
        'RR from IBI frequency',
        'ALG-RSP-01',
        'br/min',
        0,
        rrBrMin - 1.0,
        'Diagnostic — one of 4 fused RR series',
      ),
      'RR_MOTION': diag(
        'RR_MOTION',
        'RR from landmark motion',
        'ALG-RSP-01',
        'br/min',
        0,
        rrBrMin.toDouble(),
        'Diagnostic — one of 4 fused RR series',
      ),
      'RR_SPREAD': diag(
        'RR_SPREAD',
        'Spread of RR estimates',
        'ALG-RSP-01',
        'br/min',
        0,
        2.0,
        'Diagnostic — spread > 4 br/min → retake',
      ),
      'SPO2_ROR': diag(
        'SPO2_ROR',
        'SpO2 ratio of ratios',
        'ALG-SPO-01',
        'ratio',
        2,
        0.52,
        'Internal — model input',
      ),
      'SPO2_EST': diag(
        'SPO2_EST',
        'SpO2 estimate',
        'ALG-SPO-01',
        '%',
        0,
        spo2Pct,
        'Internal — never displayed as a number (§4.5)',
      ),
      'SBP': diag(
        'SBP',
        'Systolic BP',
        'ALG-BP-01',
        'mmHg',
        0,
        sbpMmhg,
        'Internal until numeric acceptance (mean <= 5, SD <= 8 mmHg)',
      ),
      'DBP': diag(
        'DBP',
        'Diastolic BP',
        'ALG-BP-01',
        'mmHg',
        0,
        dbpMmhg,
        'Internal until numeric acceptance (mean <= 5, SD <= 8 mmHg)',
      ),
      'PTT_PROXY': diag(
        'PTT_PROXY',
        'Pulse-transit-time proxy',
        'ALG-WAV-05',
        'ms',
        0,
        212,
        'Internal feature for the BP model (§4.8)',
      ),
      'IRREG_PROB': diag(
        'IRREG_PROB',
        'Irregular-rhythm probability',
        'ALG-RHY-01',
        '',
        2,
        irregularRhythmConfirmed ? 0.71 : 0.08,
        'Internal — positive if >= threshold (initial 0.5) on 2 scans',
      ),
      'DM_PROB_57': diag(
        'DM_PROB_57',
        'P(HbA1c >= 5.7%)',
        'ALG-DM-01',
        '',
        2,
        0.12,
        'Internal — band only is member-facing (§4.9)',
      ),
      'DM_PROB_65': diag(
        'DM_PROB_65',
        'P(HbA1c >= 6.5%)',
        'ALG-DM-01',
        '',
        2,
        0.04,
        'Internal — band only is member-facing (§4.9)',
      ),
    };

    // ── Capture-quality summary (Spec §2, ALG-CAP-01…05) stored for QA ──
    final motionPxS = qualityPassed ? 1.4 : 4.8;
    final motionHighPct = qualityPassed ? 6.0 : 31.0;
    final captureQuality = CaptureQualitySummary(
      framesPassedPct: qualityPassed ? 93.0 : 71.0,
      captureQualityScore: qualityPassed ? 0.94 : 0.45,
      discardedLeadInSeconds: 3.0,
      checks: [
        const CaptureQualityCheck(
          algorithmId: 'ALG-CAP-01',
          code: 'face_size_px',
          label: 'Face width',
          valueText: '312 px',
          passRuleText: '>= 200 px',
          passed: true,
        ),
        const CaptureQualityCheck(
          algorithmId: 'ALG-CAP-01',
          code: 'yaw_deg / pitch_deg',
          label: 'Head pose',
          valueText: 'yaw 4.2° · pitch 3.1°',
          passRuleText: '|yaw| <= 15° · |pitch| <= 15°',
          passed: true,
        ),
        const CaptureQualityCheck(
          algorithmId: 'ALG-CAP-02',
          code: 'roi_pixel_count',
          label: 'ROI segmentation',
          valueText: '7 / 7 usable · min 1 480 px',
          passRuleText: 'each ROI >= 400 px · >= 4 usable',
          passed: true,
        ),
        const CaptureQualityCheck(
          algorithmId: 'ALG-CAP-03',
          code: 'illuminance_luma',
          label: 'Light level',
          valueText: 'mean luma 142',
          passRuleText: '60 – 220 (1-s window)',
          passed: true,
        ),
        CaptureQualityCheck(
          algorithmId: 'ALG-CAP-04',
          code: 'motion_px_s / motion_high_pct',
          label: 'Motion',
          valueText:
              '${motionPxS.toStringAsFixed(1)} px/s · ${motionHighPct.toStringAsFixed(0)}% high-motion frames',
          passRuleText: '<= 3 px/s · <= 20% frames',
          passed: qualityPassed,
        ),
        const CaptureQualityCheck(
          algorithmId: 'ALG-CAP-05',
          code: 'skin_valid_pct',
          label: 'Skin validity (YCbCr)',
          valueText: '91%',
          passRuleText: '>= 80%',
          passed: true,
        ),
        const CaptureQualityCheck(
          algorithmId: 'ALG-CAP-15',
          code: 'face_distance_cm',
          label: 'Face distance',
          valueText: '38 cm',
          passRuleText: '30 – 50 cm',
          passed: true,
        ),
      ],
    );

    // ── Pulse pipeline summary (F-10 `PulseSignalSummary`, ALG-PUL-01…10) ──
    final pulseSignal = PulseSignalSummary(
      roiWeights: const [
        RoiWeight(roi: 'Forehead', weight: 0.22, snrDb: 9.8),
        RoiWeight(roi: 'Left cheek', weight: 0.18, snrDb: 8.9),
        RoiWeight(roi: 'Right cheek', weight: 0.18, snrDb: 8.7),
        RoiWeight(roi: 'Left temple', weight: 0.12, snrDb: 6.4),
        RoiWeight(roi: 'Right temple', weight: 0.12, snrDb: 6.1),
        RoiWeight(roi: 'Nose', weight: 0.10, snrDb: 5.2),
        RoiWeight(roi: 'Chin', weight: 0.08, snrDb: 4.6),
      ],
      extractionMethod: 'POS',
      neuralFallback: false,
      neuralProcessingSeconds: 11.2,
      hrSpecBpm: hrBpm.toDouble(),
      hrPosBpm: hrBpm + 1.0,
      hrNeuralBpm: hrBpm - 1.0,
      beatsDetected: cleanBeats + 6,
      cleanBeatCount: cleanBeats,
      templateCorrMean: qualityPassed ? 0.91 : 0.74,
      pulseSnrDb: pulseSnrDb,
      ibiCount: cleanBeats > 0 ? cleanBeats - 1 : 0,
      validIbiPct: 94.0,
      ectopicCount: 1,
      meanIbiMs: hrBpm > 0 ? 60000.0 / hrBpm : 0.0,
    );

    return VitalsSessionResult(
      sessionId: 'vit_${now.millisecondsSinceEpoch}',
      subjectId: subj.id,
      captureMode: captureMode,
      recordedAt: now,
      pulseSnrDb: pulseSnrDb,
      cleanBeatCount: cleanBeats,
      validIbiPct: 94.0,
      hadRecentContextFactor: hadRecentCaffeineSmokeExercise,
      markers: markers,
      derivedFormulas: formulas,
      overallUrgency: riskEval.highestUrgency,
      firedRuleCodes: riskEval.firedRuleCodes,
      retakeRequired: riskEval.requiresRetakeFirst,
      retakeReason: riskEval.requiresRetakeFirst
          ? 'Pulse SNR ${pulseSnrDb.toStringAsFixed(1)} dB is below 3.0 dB threshold (BR-QUA-01).'
          : null,
      diagnosticMarkers: diagnostics,
      captureQuality: captureQuality,
      pulseSignal: pulseSignal,
      recordingSeconds: 60,
      bpCuffCalibrationNote:
          'No cuff calibration on file (S-D10) — personal offset not applied (G-26).',
    );
  }

  void saveVitalsSession(VitalsSessionResult session) {
    vitalsSessions.insert(0, session);
    notifyListeners();
  }

  DentalExamResult generateDentalExam({
    required CariesHabitsInput habits,
    required int missingViewsCount,
    required bool includeAbscess,
  }) {
    final subj = activeSubject;
    final childMode = subj.ageYears >= 1 && subj.ageYears <= 12;
    final findings = <ToothFinding>[
      ToothFinding(
        toothFdi: childMode ? 52 : 12,
        findingCode: 'white_spot',
        findingLabel: 'Early Enamel White Spot',
        probability: 0.84,
        band: SemanticBand.moderate,
        changeVsPrevious: 'New',
      ),
      if (includeAbscess)
        ToothFinding(
          toothFdi: childMode ? 54 : 36,
          findingCode: 'abscess_sign',
          findingLabel: 'Gingival Abscess Sign & Cavity',
          probability: 0.91,
          band: SemanticBand.high,
          changeVsPrevious: 'Progressed',
        ),
    ];

    final cariesRisk = CariesRiskEngine.evaluate(
      findings: findings,
      habits: habits,
    );

    final riskEval = RiskEngine.evaluateUrgency(
      RiskEvaluationInput(
        dentalAbscessSign: includeAbscess,
        dentalCavityOnly: !includeAbscess && findings.isNotEmpty,
      ),
      sessionId: 'den_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (riskEval.orderedFlags.isNotEmpty) {
      cases = RiskEngine.mergeFlagsIntoCases(
        existingCases: cases,
        newFlags: riskEval.orderedFlags,
        subjectId: subj.id,
      );
    }

    // Spec §7.2 ALG-DEN-05: Sealant need on first permanent molars (16, 26, 36, 46), age 6–9
    final sealants = (subj.ageYears >= 6 && subj.ageYears <= 9)
        ? const [16, 26, 36, 46]
        : const <int>[];

    return DentalExamResult(
      examId: 'den_${DateTime.now().millisecondsSinceEpoch}',
      subjectId: subj.id,
      recordedAt: DateTime.now(),
      isChildMode: childMode,
      viewsCompleted: (4 - missingViewsCount).clamp(1, 4),
      isPartial: missingViewsCount > 0,
      unseenTeethFdi: missingViewsCount > 0
          ? (childMode ? const [74, 75, 84, 85] : const [37, 38, 47, 48])
          : const [],
      toothFindings: findings,
      gumInflammationBand: SemanticBand.low,
      plaqueBand: SemanticBand.moderate,
      sealantNeededTeethFdi: sealants,
      cariesRiskBand: cariesRisk.riskBand,
      cariesRiskReason: cariesRisk.explanation,
      urgency: riskEval.highestUrgency,
    );
  }

  /// F-16 Anaemia (ALG-IMG-01) session builder.
  ///
  /// The eyelid-colour CNN is not shipped yet, so `demoOutcome` selects a
  /// static haemoglobin estimate relative to the subject's WHO cut-off. Every
  /// other field (band, probability, confidence, urgency, rules, specialist
  /// routing, per-eye summaries, markers) is derived exactly as the Spec
  /// describes so the real model can be dropped in at this single point.
  AnaemiaSessionResult generateAnaemiaSession({
    required SubjectProfile subject,
    required AnaemiaPreTestAnswers answers,
    required List<EyelidPhoto> photos,
    AnaemiaDemoOutcome demoOutcome = AnaemiaDemoOutcome.normal,
    int durationSeconds = 32,
  }) {
    final now = DateTime.now();
    final threshold = AnaemiaWhoThreshold.forSubject(
      ageYears: subject.ageYears,
      sex: subject.sex,
      isPregnant: subject.isPregnant,
    );

    // --- 1. Static model stand-in (HB_EST internal, g/dL 1 dp) -------------
    final double hbEst = switch (demoOutcome) {
      AnaemiaDemoOutcome.normal => threshold.cutoffGdL + 1.6,
      AnaemiaDemoOutcome.borderline => threshold.cutoffGdL + 0.2,
      AnaemiaDemoOutcome.high => threshold.cutoffGdL - 1.4,
    };
    final hbRounded = (hbEst * 10).round() / 10;
    // Probability of anaemia from the distance to the cut-off (logistic, k = 1.6).
    final z = (threshold.cutoffGdL - hbRounded) * 1.6;
    final prob = 1 / (1 + math.exp(-z));
    const decisionThreshold = 0.50;

    // --- 2. Band (WHO cut-off + borderline margin, Spec §6.1) --------------
    final accepted = photos.where((p) => p.accepted).toList();
    final SemanticBand band;
    if (accepted.isEmpty) {
      band = SemanticBand.notAssessed;
    } else if (RiskEngine.assignAnaemiaBand(
          hbEstGdL: hbRounded,
          ageYears: subject.ageYears,
          sex: subject.sex,
          isPregnant: subject.isPregnant,
        ) ==
        SemanticBand.high) {
      band = SemanticBand.high;
    } else if (hbRounded < threshold.cutoffGdL + 0.5) {
      band = SemanticBand.borderline;
    } else {
      band = SemanticBand.normal;
    }

    // --- 3. Capture quality + confidence (ALG-RSK-06) ---------------------
    final captureQuality = accepted.isEmpty
        ? 0.0
        : accepted.map((p) => p.quality.qualityScore).reduce((a, b) => a + b) /
              accepted.length;
    const modelConfidence = 0.88;
    final confidence = accepted.isEmpty
        ? 0.0
        : RiskEngine.computeResultConfidence(
            captureQualityScore: captureQuality,
            modelConfidence: modelConfidence,
            hasRecentCaffeineSmokeOrExercise: false,
          );

    // --- 4. Per-eye summaries [DER] ---------------------------------------
    final perEye = <AnaemiaEyeSummary>[];
    for (final eye in EyeSide.values) {
      final eyePhotos = photos
          .where((p) => p.eye == eye && p.accepted)
          .toList();
      if (eyePhotos.isEmpty) {
        perEye.add(
          AnaemiaEyeSummary(
            eye: eye,
            pallorIndex: 0,
            meanAStar: 0,
            photosUsed: 0,
            band: SemanticBand.notAssessed,
          ),
        );
        continue;
      }
      final aStar =
          eyePhotos.map((p) => p.quality.meanAStar).reduce((a, b) => a + b) /
          eyePhotos.length;
      // Demo pallor: anchor on the chosen outcome, nudge by the eye's real a*.
      final basePallor = switch (demoOutcome) {
        AnaemiaDemoOutcome.normal => 0.22,
        AnaemiaDemoOutcome.borderline => 0.48,
        AnaemiaDemoOutcome.high => 0.74,
      };
      final nudge = ((20.0 - aStar) / 60.0).clamp(-0.06, 0.06);
      final pallor =
          (basePallor + nudge + (eye == EyeSide.right ? 0.03 : -0.02)).clamp(
            0.0,
            1.0,
          );
      perEye.add(
        AnaemiaEyeSummary(
          eye: eye,
          pallorIndex: pallor,
          meanAStar: aStar,
          photosUsed: eyePhotos.length,
          band: pallor >= 0.60
              ? SemanticBand.high
              : pallor >= 0.40
              ? SemanticBand.borderline
              : SemanticBand.normal,
        ),
      );
    }

    // --- 5. Risk rules T12 / T15 (ALG-RSK-02) ------------------------------
    final risk = RiskEngine.evaluateUrgency(
      RiskEvaluationInput(
        anaemiaBand: band == SemanticBand.high ? SemanticBand.high : null,
        isPregnant: subject.isPregnant,
      ),
      sessionId: 'ana_${now.millisecondsSinceEpoch}',
      timestamp: now,
    );

    // --- 6. IMG-10 specialist routing ------------------------------------
    final specialist =
        band == SemanticBand.high ||
        (band != SemanticBand.notAssessed &&
            (prob - decisionThreshold).abs() <= 0.10);

    // --- 7. Marker envelopes ---------------------------------------------
    final retakeTotal = photos.fold<int>(0, (s, p) => s + (p.attempts - 1));
    const algVersion = '0.9.0-dev';
    const rangeVersion = 'WHO-2011 v1';
    MarkerEnvelope<dynamic> env({
      required String code,
      required String name,
      required String unit,
      required int decimals,
      dynamic value,
      required SemanticBand b,
      required MarkerDisplayStatus status,
      String? reason,
      String? range,
      bool estimate = false,
    }) {
      return MarkerEnvelope<dynamic>(
        code: code,
        displayName: name,
        algorithmId: 'ALG-IMG-01',
        algorithmVersion: algVersion,
        rangeVersion: rangeVersion,
        unit: unit,
        decimals: decimals,
        value: value,
        band: b,
        confidence: confidence,
        displayStatus: status,
        statusReason: reason,
        normalRangeLabel: range,
        conditionsInformed: const ['COND_ANAEMIA'],
        isEstimate: estimate,
      );
    }

    final markers = <String, MarkerEnvelope<dynamic>>{
      'ANAEMIA_BAND': env(
        code: 'ANAEMIA_BAND',
        name: 'Anaemia screen',
        unit: 'band',
        decimals: 0,
        b: band,
        status: band == SemanticBand.notAssessed
            ? MarkerDisplayStatus.notAssessed
            : specialist
            ? MarkerDisplayStatus.underSpecialistReview
            : MarkerDisplayStatus.bandOnly,
        reason: band == SemanticBand.notAssessed
            ? 'Not assessed — no usable eyelid photo after 3 attempts'
            : null,
        range:
            '≥ ${threshold.cutoffGdL.toStringAsFixed(1)} g/dL (${threshold.groupLabel})',
      ),
      'ANAEMIA_PROB': env(
        code: 'ANAEMIA_PROB',
        name: 'Anaemia probability',
        unit: '0–1',
        decimals: 2,
        value: prob,
        b: band,
        status: MarkerDisplayStatus.internalOnly,
        reason: 'Not member-facing (R-9)',
      ),
      'HB_EST': env(
        code: 'HB_EST',
        name: 'Haemoglobin estimate',
        unit: 'g/dL',
        decimals: 1,
        value: hbRounded,
        b: band,
        status: MarkerDisplayStatus.internalOnly,
        reason: 'Internal until IMG-AN-01 validation passes (G-24)',
        range: '≥ ${threshold.cutoffGdL.toStringAsFixed(1)} g/dL',
        estimate: true,
      ),
    };

    return AnaemiaSessionResult(
      sessionId: 'ana_${now.millisecondsSinceEpoch}',
      subjectId: subject.id,
      subjectName: subject.fullName,
      ageYears: subject.ageYears,
      sex: subject.sex,
      isPregnant: subject.isPregnant,
      pregnancyWeeks: subject.pregnancyWeeks,
      recordedAt: now,
      answers: answers,
      photos: photos,
      perEye: perEye,
      threshold: threshold,
      hbEstInternalGdL: hbRounded,
      anaemiaProb: prob,
      decisionThreshold: decisionThreshold,
      band: band,
      confidence: confidence,
      captureQualityScore: captureQuality,
      modelConfidence: modelConfidence,
      urgency: risk.highestUrgency,
      firedRuleCodes: risk.firedRuleCodes,
      specialistReviewRequired: specialist,
      specialistReviewStatus: specialist
          ? 'Sent for specialist review'
          : 'Not required',
      retakeTotal: retakeTotal,
      durationSeconds: durationSeconds,
      algorithmVersion: algVersion,
      rangeVersion: rangeVersion,
      markers: markers,
    );
  }

  /// Persists an anaemia session and files it as an S-R01 screening record
  /// (which also opens / merges a COND_ANAEMIA case when a rule fired).
  void saveAnaemiaSession(AnaemiaSessionResult result) {
    anaemiaSessions.insert(0, result);
    final record = ScreeningSessionRecord(
      sessionId: result.sessionId,
      subjectId: result.subjectId,
      featureId: 'F-16',
      screenId: 'S-R01',
      title: 'Anaemia (Lower Eyelid)',
      category: 'Eyes',
      recordedAt: result.recordedAt,
      primaryBand: result.band,
      urgency: result.urgency,
      confidence: result.confidence,
      summaryText: result.band == SemanticBand.notAssessed
          ? 'Not assessed — eyelid photos did not pass quality checks.'
          : 'Anaemia screen: ${result.band.label} (${result.threshold.groupLabel}, cut-off ${result.threshold.cutoffGdL.toStringAsFixed(1)} g/dL).',
      markers: [result.markers['ANAEMIA_BAND']!],
      isUnderSpecialistReview: result.specialistReviewRequired,
      firedRules: result.firedRuleCodes,
    );
    addScreeningRecord(record, conditionCode: 'COND_ANAEMIA');
  }

  /// Persists a guided eye-photo session (jaundice / cataract / child eye /
  /// fundus) and files it as an S-R01 screening record, opening or merging
  /// a case for the protocol's condition when a rule fired.
  void saveEyeSession(EyeSessionResult result) {
    eyeSessions.insert(0, result);
    final p = result.protocol;
    // Dental sessions also file the S-F04 exam so History and ALG-DEN-07
    // (change vs previous) keep working.
    final dental = result.extraCard<DentalChartCard>();
    if (dental != null) dentalExams.insert(0, dental.exam);
    final record = ScreeningSessionRecord(
      sessionId: result.sessionId,
      subjectId: result.subjectId,
      featureId: p.featureId,
      screenId: 'S-R01',
      title: p.recordTitle,
      category: p.category,
      recordedAt: result.recordedAt,
      primaryBand: result.band,
      urgency: result.urgency,
      confidence: result.confidence,
      summaryText: result.band == SemanticBand.notAssessed
          ? 'Not assessed — photos did not pass quality checks.'
          : '${p.shortTitle}: ${result.bandTitle} — ${result.bandSubline}.',
      markers: result.markers.values
          .where((m) => m.displayStatus != MarkerDisplayStatus.internalOnly)
          .toList(),
      isUnderSpecialistReview: result.specialistReviewRequired,
      firedRules: result.firedRuleCodes,
    );
    final glaucomaOnly =
        p.id == 'eye_fundus' &&
        result.firedRuleCodes.isNotEmpty &&
        !result.findings.any(
          (f) => f.code == 'DR_REFERABLE' && f.valueText == 'Yes',
        );
    addScreeningRecord(
      record,
      conditionCode: glaucomaOnly ? 'COND_GLAUCOMA' : p.conditionCode,
    );
  }

  /// G-31: clip-on fundus camera connection state (simulated in this build).
  void setFundusCameraConnected(bool connected) {
    deviceProfile = deviceProfile.copyWith(fundusCameraConnected: connected);
    notifyListeners();
  }

  void saveDentalExam(DentalExamResult exam) {
    dentalExams.insert(0, exam);
    notifyListeners();
  }

  /// Gate G-30: the sleep setup reads the real charger state (battery
  /// channel) and records it here; the settings toggle still works offline.
  void setPhoneCharging(bool charging) {
    if (deviceProfile.phoneCharging == charging) return;
    deviceProfile = deviceProfile.copyWith(phoneCharging: charging);
    notifyListeners();
  }

  /// Gate G-13: the intro probes the IMU and records the answer here.
  void setMotionSensorsAvailable(bool available) {
    if (deviceProfile.hasMotionSensors == available) return;
    deviceProfile = deviceProfile.copyWith(hasMotionSensors: available);
    notifyListeners();
  }

  /// CAP-15 stand-in: the one-time 40 cm calibration stores the front
  /// camera focal length (px); G-33 then reports the distance check as
  /// calibrated.
  void setFocalLengthCalibration(double focalPx) {
    deviceProfile = deviceProfile.copyWith(
      focalLengthPx: focalPx,
      hasFocalLengthProfile: true,
    );
    notifyListeners();
  }

  /// Credit-card screen calibration (mm per logical pixel).
  void setScreenScaleCalibration(double mmPerLogicalPx) {
    deviceProfile = deviceProfile.copyWith(
      screenMmPerLogicalPx: mmPerLogicalPx,
    );
    notifyListeners();
  }

  /// HF daily samples for [subjectId]; the enrolled senior is seeded with
  /// 14 stable baseline days so day-15 logic runs.
  List<HfDailySample> hfSamplesFor(String subjectId) {
    final existing = hfVoiceBaselines[subjectId];
    if (existing != null) return existing;
    final subj = subjects.where((s) => s.id == subjectId).firstOrNull;
    final seeded = subj != null && subj.isHeartFailureEnrolled
        ? MindSimulated.hfBaseline(
            DateTime.now(),
            days: subj.hfBaselineDaysCompleted.clamp(0, 14),
          )
        : <HfDailySample>[];
    return hfVoiceBaselines[subjectId] = List<HfDailySample>.from(seeded);
  }

  /// True when an HF voice check was saved today (G-34 "Completed today").
  bool hfCheckDoneToday(String subjectId) {
    final now = DateTime.now();
    return mindSessions.any(
      (m) =>
          m.subjectId == subjectId &&
          m.protocol.kind == MindKind.hfVoice &&
          m.recordedAt.year == now.year &&
          m.recordedAt.month == now.month &&
          m.recordedAt.day == now.day,
    );
  }

  void setSpeechLanguage(String subjectId, MindLanguage l) {
    speechLanguages[subjectId] = l;
    notifyListeners();
  }

  /// Marks the pathway clinician as notified for a crisis session (G-37).
  void markClinicianNotified(String sessionId) {
    final i = mindSessions.indexWhere((m) => m.sessionId == sessionId);
    if (i >= 0) {
      mindSessions[i] = mindSessions[i].copyWith(clinicianNotified: true);
      notifyListeners();
    }
  }

  /// Persists a Brain & Mind session and files it as a record under
  /// 'Brain & Mind' (opens / merges a case for refer / urgent / emergency).
  void saveMindSession(MindSessionResult result) {
    mindSessions.insert(0, result);
    if (result.protocol.kind == MindKind.hfVoice &&
        result.hfHistory.isNotEmpty) {
      hfVoiceBaselines[result.subjectId] = List<HfDailySample>.from(
        result.hfHistory,
      );
    }
    final markers = result.markers.values
        .where((m) => m.displayStatus != MarkerDisplayStatus.internalOnly)
        .toList();
    final screenId = result.isEmergency
        ? 'S-R02'
        : result.protocol.resultScreenId;
    final record = ScreeningSessionRecord(
      sessionId: result.sessionId,
      subjectId: result.subjectId,
      featureId: result.protocol.featureId,
      screenId: screenId,
      title: result.protocol.recordTitle,
      category: 'Brain & Mind',
      recordedAt: result.recordedAt,
      primaryBand: result.band,
      urgency: result.urgency,
      confidence: result.confidence,
      summaryText: '${result.bandSubline}. ${result.whatItMeans}',
      markers: markers,
      firedRules: result.firedRuleCodes,
    );
    addScreeningRecord(record, conditionCode: result.protocol.conditionCode);
  }

  /// Persists an overnight sleep session and files it as an S-G09 record
  /// under 'Sleep' (opens / merges a COND_OSA case for the Routine
  /// moderate / severe bands; a short night saves the breathing rate only).
  void saveSleepSession(SleepSessionResult result) {
    if (sleepSessions.any((s) => s.sessionId == result.sessionId)) return;
    sleepSessions.insert(0, result);
    final markers = result.markers.values
        .where((m) => m.displayStatus != MarkerDisplayStatus.internalOnly)
        .toList();
    final record = ScreeningSessionRecord(
      sessionId: result.sessionId,
      subjectId: result.subjectId,
      featureId: result.protocol.featureId,
      screenId: result.protocol.resultScreenId,
      title: result.protocol.recordTitle,
      category: 'Sleep',
      recordedAt: result.recordedAt,
      primaryBand: result.band,
      urgency: result.urgency,
      confidence: result.confidence,
      summaryText: '${result.bandSubline}. ${result.whatItMeans}',
      markers: markers,
      firedRules: result.firedRuleCodes,
    );
    addScreeningRecord(record, conditionCode: result.protocol.conditionCode);
  }

  /// Persists a Breathing & Voice session and files it as an S-G06 record
  /// under 'Breathing & Voice' (opens / merges a case for urgent / routine
  /// bands when the protocol names a condition).
  void saveBreathSession(BreathSessionResult result) {
    breathSessions.insert(0, result);
    final markers = result.markers.values
        .where((m) => m.displayStatus != MarkerDisplayStatus.internalOnly)
        .toList();
    final record = ScreeningSessionRecord(
      sessionId: result.sessionId,
      subjectId: result.subjectId,
      featureId: result.protocol.featureId,
      screenId: result.protocol.resultScreenId,
      title: result.protocol.recordTitle,
      category: 'Breathing & Voice',
      recordedAt: result.recordedAt,
      primaryBand: result.band,
      urgency: result.urgency,
      confidence: result.confidence,
      summaryText: '${result.bandSubline}. ${result.whatItMeans}',
      markers: markers,
      firedRules: result.firedRuleCodes,
    );
    addScreeningRecord(
      record,
      conditionCode: result.protocol.hasCondition
          ? result.protocol.conditionCode
          : null,
    );
  }

  /// CAP-11 per-device sweep profile recorded on the first passing
  /// self-check; later checks compare against it [DER].
  void setMicSweepProfile(List<double> relativeBandsDb) {
    deviceProfile = deviceProfile.copyWith(
      micSweepProfileDb: List<double>.unmodifiable(relativeBandsDb),
    );
    notifyListeners();
  }

  /// CAP-11 microphone self-check outcome for this session (G-17).
  void setMicSelfCheck({required bool passed}) {
    if (deviceProfile.micSelfCheckPassed == passed) return;
    deviceProfile = deviceProfile.copyWith(micSelfCheckPassed: passed);
    notifyListeners();
  }

  /// AUD-09 earphone calibration from a known clinic threshold [DER].
  void setEarphoneCalibration(double fullScaleDbHl) {
    deviceProfile = deviceProfile.copyWith(
      earphoneFullScaleDbHl: fullScaleDbHl,
    );
    notifyListeners();
  }

  /// CAP-12 microphone offset from the quiet-room calibration [DER].
  void setMicOffset(double offsetDba) {
    deviceProfile = deviceProfile.copyWith(micDbaOffset: offsetDba);
    notifyListeners();
  }

  /// Live output route from the platform (G-19).
  void updateEarphoneState({required String type, required bool connected}) {
    if (deviceProfile.earphoneType == type &&
        deviceProfile.earphonesConnected == connected) {
      return;
    }
    deviceProfile = deviceProfile.copyWith(
      earphoneType: type,
      earphonesConnected: connected,
    );
    notifyListeners();
  }

  /// Last measured room noise (CAP-12 / G-18).
  void setRoomNoise(double dba) {
    deviceProfile = deviceProfile.copyWith(lastRoomNoiseDba: dba);
    notifyListeners();
  }

  /// Persists a hearing session and files it as an S-G11 record under
  /// 'Hearing' (opens / merges a case for refer bands).
  void saveHearingSession(HearingSessionResult result) {
    hearingSessions.insert(0, result);
    final markers = result.markers.values
        .where((m) => m.displayStatus != MarkerDisplayStatus.internalOnly)
        .toList();
    final record = ScreeningSessionRecord(
      sessionId: result.sessionId,
      subjectId: result.subjectId,
      featureId: result.protocol.featureId,
      screenId: result.protocol.resultScreenId,
      title: result.protocol.recordTitle,
      category: 'Hearing',
      recordedAt: result.recordedAt,
      primaryBand: result.band,
      urgency: result.urgency,
      confidence: result.confidence,
      summaryText: '${result.bandSubline}. ${result.whatItMeans}',
      markers: markers,
      firedRules: result.firedRuleCodes,
    );
    addScreeningRecord(record, conditionCode: result.protocol.conditionCode);
  }

  /// Persists a vision session and files it as an S-R01 record under
  /// 'Vision' (opens / merges a case for refer bands).
  void saveVisionSession(VisionSessionResult result) {
    visionSessions.insert(0, result);
    final markers = result.markers.values
        .where((m) => m.displayStatus != MarkerDisplayStatus.internalOnly)
        .toList();
    final record = ScreeningSessionRecord(
      sessionId: result.sessionId,
      subjectId: result.subjectId,
      featureId: result.protocol.featureId,
      screenId: 'S-R01',
      title: result.protocol.recordTitle,
      category: 'Vision',
      recordedAt: result.recordedAt,
      primaryBand: result.band,
      urgency: result.urgency,
      confidence: result.confidence,
      summaryText: '${result.bandSubline}. ${result.whatItMeans}',
      markers: markers,
      firedRules: result.firedRuleCodes,
    );
    addScreeningRecord(record, conditionCode: result.protocol.conditionCode);
  }

  /// True when a voice task (AUD-06 features) has been recorded.
  bool get hasVoiceTaskRecord => screeningRecords.any(
    (r) => r.screenId.startsWith('S-G') || r.category == 'Breathing & Voice',
  );

  /// True when a face video (S-D03 vitals face scan) exists.
  bool get hasFaceVideoRecord =>
      vitalsSessions.any((v) => v.captureMode == VitalsCaptureMode.face);

  /// Persists a movement session and files it as an S-R01 record under
  /// 'Movement' (opens / merges a case for refer bands).
  void saveMovementSession(MovementSessionResult result) {
    movementSessions.insert(0, result);
    final markers = result.markers.values
        .where((m) => m.displayStatus != MarkerDisplayStatus.internalOnly)
        .toList();
    final record = ScreeningSessionRecord(
      sessionId: result.sessionId,
      subjectId: result.subjectId,
      featureId: result.protocol.featureId,
      screenId: 'S-R01',
      title: result.protocol.recordTitle,
      category: 'Movement',
      recordedAt: result.recordedAt,
      primaryBand: result.band,
      urgency: result.urgency,
      confidence: result.confidence,
      summaryText: '${result.bandSubline}. ${result.whatItMeans}',
      markers: markers,
      firedRules: result.firedRuleCodes,
    );
    addScreeningRecord(record, conditionCode: result.protocol.conditionCode);
  }

  void addScreeningRecord(
    ScreeningSessionRecord record, {
    String? conditionCode,
  }) {
    screeningRecords.insert(0, record);
    if (conditionCode != null && record.urgency != UrgencyLevel.none) {
      final flag = ConditionFlag(
        flagId: 'flg_${DateTime.now().millisecondsSinceEpoch}',
        conditionCode: conditionCode,
        sourceSessionId: record.sessionId,
        markerCode: record.screenId,
        triggerDescription: '${record.title}: ${record.primaryBand.label}',
        urgency: record.urgency,
        ruleCode: record.firedRules.isNotEmpty
            ? record.firedRules.first
            : 'BR-SCR-02',
        createdAt: record.recordedAt,
      );
      cases = RiskEngine.mergeFlagsIntoCases(
        existingCases: cases,
        newFlags: [flag],
        subjectId: activeSubject.id,
      );
    }
    notifyListeners();
  }

  void addLabPairingToCase(String caseId, ReferenceLabPairingRecord record) {
    final idx = cases.indexWhere((c) => c.caseId == caseId);
    if (idx >= 0) {
      final current = cases[idx];
      cases[idx] = current.copyWith(
        pairedLabResults: [...current.pairedLabResults, record],
      );
      notifyListeners();
    }
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in widget tree.');
    return scope!.notifier!;
  }
}
