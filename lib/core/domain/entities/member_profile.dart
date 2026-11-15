import 'enums.dart';

class ConsentRecord {
  const ConsentRecord({
    required this.type,
    required this.isSigned,
    required this.documentVersion,
    this.signedAt,
    this.guardianName,
    this.guardianRelationship,
  });

  final ConsentType type;
  final bool isSigned;
  final String documentVersion;
  final DateTime? signedAt;
  final String? guardianName;
  final String? guardianRelationship;

  ConsentRecord copyWith({
    bool? isSigned,
    String? documentVersion,
    DateTime? signedAt,
    String? guardianName,
    String? guardianRelationship,
  }) {
    return ConsentRecord(
      type: type,
      isSigned: isSigned ?? this.isSigned,
      documentVersion: documentVersion ?? this.documentVersion,
      signedAt: signedAt ?? this.signedAt,
      guardianName: guardianName ?? this.guardianName,
      guardianRelationship: guardianRelationship ?? this.guardianRelationship,
    );
  }
}

class BpCuffCalibration {
  const BpCuffCalibration({
    required this.sbpReading1,
    required this.dbpReading1,
    required this.sbpReading2,
    required this.dbpReading2,
    required this.recordedAt,
  });

  final int sbpReading1;
  final int dbpReading1;
  final int sbpReading2;
  final int dbpReading2;
  final DateTime recordedAt;

  double get meanSbp => (sbpReading1 + sbpReading2) / 2.0;
  double get meanDbp => (dbpReading1 + dbpReading2) / 2.0;

  /// Spec §4.6: Calibration offset expiry = 30 days (G-26).
  bool isValidAt(DateTime now) => now.difference(recordedAt).inDays <= 30;

  int daysRemainingAt(DateTime now) {
    final elapsed = now.difference(recordedAt).inDays;
    return (30 - elapsed).clamp(0, 30);
  }
}

class DeviceCapabilityProfile {
  const DeviceCapabilityProfile({
    required this.deviceModelCode,
    required this.displayName,
    required this.cameraMaxFps,
    required this.hasSpo2Calibration,
    required this.spo2CoeffA,
    required this.spo2CoeffB,
    required this.hasMicReferenceProfile,
    required this.hasFocalLengthProfile,
    required this.focalLengthMm,
    required this.hasMotionSensors,
    required this.micSelfCheckPassed,
    required this.lastRoomNoiseDba,
    required this.earphonesConnected,
    required this.smartRingConnected,
    required this.fundusCameraConnected,
    required this.phoneCharging,
    this.focalLengthPx,
    this.screenMmPerLogicalPx,
    this.earphoneFullScaleDbHl,
    this.micDbaOffset,
    this.micSweepProfileDb,
    this.earphoneType = 'unknown',
  });

  final String deviceModelCode;
  final String displayName;
  final int cameraMaxFps;
  final bool hasSpo2Calibration;
  final double spo2CoeffA;
  final double spo2CoeffB;
  final bool hasMicReferenceProfile;
  final bool hasFocalLengthProfile;
  final double focalLengthMm;
  final bool hasMotionSensors;
  final bool micSelfCheckPassed;
  final double lastRoomNoiseDba;
  final bool earphonesConnected;
  final bool smartRingConnected;
  final bool fundusCameraConnected;
  final bool phoneCharging;

  /// Front-camera focal length in pixels from the one-time 40 cm
  /// calibration (CAP-15 stand-in [DER]); null = not calibrated.
  final double? focalLengthPx;

  /// Physical screen scale from the credit-card calibration; null = use the
  /// device DPI.
  final double? screenMmPerLogicalPx;

  /// Hearing level of a full-scale tone at maximum volume through the
  /// member's earphones (AUD-09 calibration, OQ-REQ-15 [DER]); null =
  /// assumed 90 dB HL.
  final double? earphoneFullScaleDbHl;

  /// Microphone dBFS → dBA offset (CAP-12 per-device table); null = 95.
  final double? micDbaOffset;

  /// Relative octave-band response of this phone's own speaker→mic sweep
  /// (CAP-11), recorded on the first passing self-check [DER]; null = not
  /// yet profiled.
  final List<double>? micSweepProfileDb;

  /// Last detected output route: wired | bluetooth | usb | none | unknown.
  final String earphoneType;

  bool get isRoomQuietEnough => lastRoomNoiseDba <= 45.0; // ALG-CAP-12

  DeviceCapabilityProfile copyWith({
    bool? hasSpo2Calibration,
    bool? micSelfCheckPassed,
    double? lastRoomNoiseDba,
    bool? earphonesConnected,
    bool? smartRingConnected,
    bool? fundusCameraConnected,
    bool? phoneCharging,
    bool? hasMotionSensors,
    bool? hasFocalLengthProfile,
    double? focalLengthPx,
    double? screenMmPerLogicalPx,
    double? earphoneFullScaleDbHl,
    double? micDbaOffset,
    List<double>? micSweepProfileDb,
    String? earphoneType,
  }) {
    return DeviceCapabilityProfile(
      deviceModelCode: deviceModelCode,
      displayName: displayName,
      cameraMaxFps: cameraMaxFps,
      hasSpo2Calibration: hasSpo2Calibration ?? this.hasSpo2Calibration,
      spo2CoeffA: spo2CoeffA,
      spo2CoeffB: spo2CoeffB,
      hasMicReferenceProfile: hasMicReferenceProfile,
      hasFocalLengthProfile:
          hasFocalLengthProfile ?? this.hasFocalLengthProfile,
      focalLengthMm: focalLengthMm,
      hasMotionSensors: hasMotionSensors ?? this.hasMotionSensors,
      micSelfCheckPassed: micSelfCheckPassed ?? this.micSelfCheckPassed,
      lastRoomNoiseDba: lastRoomNoiseDba ?? this.lastRoomNoiseDba,
      earphonesConnected: earphonesConnected ?? this.earphonesConnected,
      smartRingConnected: smartRingConnected ?? this.smartRingConnected,
      fundusCameraConnected:
          fundusCameraConnected ?? this.fundusCameraConnected,
      phoneCharging: phoneCharging ?? this.phoneCharging,
      focalLengthPx: focalLengthPx ?? this.focalLengthPx,
      screenMmPerLogicalPx: screenMmPerLogicalPx ?? this.screenMmPerLogicalPx,
      earphoneFullScaleDbHl:
          earphoneFullScaleDbHl ?? this.earphoneFullScaleDbHl,
      micDbaOffset: micDbaOffset ?? this.micDbaOffset,
      micSweepProfileDb: micSweepProfileDb ?? this.micSweepProfileDb,
      earphoneType: earphoneType ?? this.earphoneType,
    );
  }
}

class SubjectProfile {
  const SubjectProfile({
    required this.id,
    required this.fullName,
    required this.relationship,
    required this.ageYears,
    this.ageHoursForNewborn,
    this.gestationWeeksForNewborn,
    required this.sex,
    this.heightCm,
    this.weightKg,
    this.waistCm,
    this.isPregnant = false,
    this.pregnancyWeeks,
    this.hasFamilyHistoryDiabetes = false,
    this.hasKnownDiabetes = false,
    this.hasKnownHypertension = false,
    this.usesTobaccoOrAreca = false,
    this.activityLevel = 'Moderate',
    this.educationYears = 12,
    this.isHeartFailureEnrolled = false,
    this.hfBaselineDaysCompleted = 0,
    required this.consents,
    this.bpCalibration,
  });

  final String id;
  final String fullName;
  final String relationship; // 'Self', 'Child (7y)', 'Newborn (3d)', etc.
  final int ageYears;
  final int? ageHoursForNewborn; // Spec §6.7: 0-28 days in hours
  final int? gestationWeeksForNewborn;
  final BiologicalSex sex;
  final double? heightCm;
  final double? weightKg;
  final double? waistCm;
  final bool isPregnant;
  final int? pregnancyWeeks;
  final bool hasFamilyHistoryDiabetes;
  final bool hasKnownDiabetes;
  final bool hasKnownHypertension;
  final bool usesTobaccoOrAreca;
  final String activityLevel;
  final int educationYears;
  final bool isHeartFailureEnrolled;
  final int hfBaselineDaysCompleted;
  final Map<ConsentType, ConsentRecord> consents;
  final BpCuffCalibration? bpCalibration;

  bool get isNewborn => ageHoursForNewborn != null && ageYears == 0;
  bool get isChild => ageYears >= 1 && ageYears <= 12;
  bool get isAdult => ageYears >= 18;

  /// Gate G-02: Basic Profile Complete (DOB/age, sex, height, weight).
  bool get isBasicProfileComplete =>
      heightCm != null && heightCm! >= 30 && weightKg != null && weightKg! >= 1;

  /// Gate G-03: Extended Profile Complete (waist, family history, activity).
  bool get isExtendedProfileComplete =>
      isBasicProfileComplete && waistCm != null && waistCm! >= 30;

  bool hasConsent(ConsentType type) => consents[type]?.isSigned ?? false;

  SubjectProfile copyWith({
    String? fullName,
    String? relationship,
    int? ageYears,
    int? ageHoursForNewborn,
    int? gestationWeeksForNewborn,
    BiologicalSex? sex,
    double? heightCm,
    double? weightKg,
    double? waistCm,
    bool? isPregnant,
    int? pregnancyWeeks,
    bool? hasFamilyHistoryDiabetes,
    bool? hasKnownDiabetes,
    bool? hasKnownHypertension,
    bool? usesTobaccoOrAreca,
    String? activityLevel,
    int? educationYears,
    bool? isHeartFailureEnrolled,
    int? hfBaselineDaysCompleted,
    Map<ConsentType, ConsentRecord>? consents,
    BpCuffCalibration? bpCalibration,
  }) {
    return SubjectProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      relationship: relationship ?? this.relationship,
      ageYears: ageYears ?? this.ageYears,
      ageHoursForNewborn: ageHoursForNewborn ?? this.ageHoursForNewborn,
      gestationWeeksForNewborn:
          gestationWeeksForNewborn ?? this.gestationWeeksForNewborn,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      waistCm: waistCm ?? this.waistCm,
      isPregnant: isPregnant ?? this.isPregnant,
      pregnancyWeeks: pregnancyWeeks ?? this.pregnancyWeeks,
      hasFamilyHistoryDiabetes:
          hasFamilyHistoryDiabetes ?? this.hasFamilyHistoryDiabetes,
      hasKnownDiabetes: hasKnownDiabetes ?? this.hasKnownDiabetes,
      hasKnownHypertension: hasKnownHypertension ?? this.hasKnownHypertension,
      usesTobaccoOrAreca: usesTobaccoOrAreca ?? this.usesTobaccoOrAreca,
      activityLevel: activityLevel ?? this.activityLevel,
      educationYears: educationYears ?? this.educationYears,
      isHeartFailureEnrolled:
          isHeartFailureEnrolled ?? this.isHeartFailureEnrolled,
      hfBaselineDaysCompleted:
          hfBaselineDaysCompleted ?? this.hfBaselineDaysCompleted,
      consents: consents ?? this.consents,
      bpCalibration: bpCalibration ?? this.bpCalibration,
    );
  }
}
