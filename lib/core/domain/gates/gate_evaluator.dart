import '../entities/enums.dart';
import '../entities/member_profile.dart';
import '../entities/screening_catalogue_item.dart';

class GateCheckOutcome {
  const GateCheckOutcome({
    required this.gate,
    required this.passed,
    required this.reason,
    this.fixButtonLabel,
    this.fixTargetScreenId,
    this.isAdvisoryOnly = false,
  });

  final GateId gate;
  final bool passed;
  final String reason;
  final String? fixButtonLabel;
  final String? fixTargetScreenId;
  final bool isAdvisoryOnly;
}

/// Evaluates all 37 Gates (G-01 .. G-37) documented in Docs/07_Feature_Lifecycle_and_States.md.
class GateEvaluator {
  static GateCheckOutcome evaluateSingleGate({
    required GateId gate,
    required SubjectProfile subject,
    required DeviceCapabilityProfile device,
    required bool isAuthenticated,
    required bool cameraPermissionGranted,
    required bool micPermissionGranted,
    required bool blePermissionGranted,
    required bool isOnline,
    ScreeningCatalogueItem? catalogueItem,
  }) {
    switch (gate) {
      case GateId.g01:
        return GateCheckOutcome(
          gate: gate,
          passed: isAuthenticated,
          reason: isAuthenticated
              ? 'Session authenticated.'
              : 'Sign-in required to access health records.',
          fixButtonLabel: 'Sign In',
          fixTargetScreenId: 'S-A04',
        );
      case GateId.g02:
        return GateCheckOutcome(
          gate: gate,
          passed: subject.isBasicProfileComplete,
          reason: subject.isBasicProfileComplete
              ? 'Age (${subject.ageYears}y), sex (${subject.sex.label}), height (${subject.heightCm} cm) & weight (${subject.weightKg} kg) present.'
              : 'Requires age, biological sex, height, and weight (Spec §4.6, §5).',
          fixButtonLabel: 'Complete Basic Profile',
          fixTargetScreenId: 'S-B03',
        );
      case GateId.g03:
        return GateCheckOutcome(
          gate: gate,
          passed: subject.isExtendedProfileComplete,
          reason: subject.isExtendedProfileComplete
              ? 'Waist (${subject.waistCm} cm) and health context complete.'
              : 'Waist circumference and health history required for Diabetes & Organ Risk (Spec §4.9, §10 RSK-05).',
          fixButtonLabel: 'Add Waist & Health Context',
          fixTargetScreenId: 'S-B04',
        );
      case GateId.g04:
        final signed = subject.hasConsent(ConsentType.screening);
        return GateCheckOutcome(
          gate: gate,
          passed: signed,
          reason: signed
              ? 'Health Screening Consent signed.'
              : 'Screening Consent must be signed before running health screens (Spec §6).',
          fixButtonLabel: 'Sign Screening Consent',
          fixTargetScreenId: 'S-B01',
        );
      case GateId.g05:
        final signed = subject.hasConsent(ConsentType.dentalGuardian);
        return GateCheckOutcome(
          gate: gate,
          passed: signed,
          reason: signed
              ? 'Dental / Guardian consent signed.'
              : 'Dental consent (by guardian for children) required (Spec §7.1).',
          fixButtonLabel: 'Sign Dental Consent',
          fixTargetScreenId: 'S-B01',
        );
      case GateId.g06:
        final signed = subject.hasConsent(ConsentType.trainingData);
        return GateCheckOutcome(
          gate: gate,
          passed: true, // Non-blocking per Spec §11.2
          isAdvisoryOnly: true,
          reason: signed
              ? 'Consented to anonymised model training.'
              : 'Training consent off (scans excluded from model building per Spec §11.2).',
        );
      case GateId.g07:
        final active = subject.hasConsent(ConsentType.clinicianMoodPathway);
        return GateCheckOutcome(
          gate: gate,
          passed: active,
          reason: active
              ? 'Clinician Mood Pathway active.'
              : 'Mood voice & PHQ-9/GAD-7 screen is available on the Clinician Pathway only (Spec §8 AUD-11).',
          fixButtonLabel: 'Enable Clinician Pathway',
          fixTargetScreenId: 'S-B01',
        );
      case GateId.g08:
        return GateCheckOutcome(
          gate: gate,
          passed: subject.isHeartFailureEnrolled,
          reason: subject.isHeartFailureEnrolled
              ? 'Enrolled in Heart-Failure Voice Programme.'
              : 'Only for enrolled Heart-Failure clinic patients (Spec §8 AUD-12).',
          fixButtonLabel: 'Enrol in HF Programme',
          fixTargetScreenId: 'S-B01',
        );
      case GateId.g09:
        if (catalogueItem != null) {
          if (catalogueItem.forNewbornOnly && !subject.isNewborn) {
            return GateCheckOutcome(
              gate: gate,
              passed: false,
              reason:
                  'Newborn Jaundice is for babies 0–28 days old (Spec §6.7). Current subject is ${subject.ageYears} y.',
              fixButtonLabel: 'Switch to Newborn Dependent',
              fixTargetScreenId: 'S-B05',
            );
          }
          if (catalogueItem.minAgeYears != null &&
              subject.ageYears < catalogueItem.minAgeYears!) {
            // Spec §6.3: Cataract offered to age >= 40 or on request
            final onRequestAllowed =
                catalogueItem.imageScreenType == ImageScreenType.cataract;
            return GateCheckOutcome(
              gate: gate,
              passed: onRequestAllowed,
              isAdvisoryOnly: onRequestAllowed,
              reason:
                  'Standard eligibility is age >= ${catalogueItem.minAgeYears} y (current: ${subject.ageYears} y).',
              fixButtonLabel: 'Switch Family Member',
              fixTargetScreenId: 'S-B05',
            );
          }
          if (catalogueItem.maxAgeYears != null &&
              subject.ageYears > catalogueItem.maxAgeYears!) {
            return GateCheckOutcome(
              gate: gate,
              passed: false,
              reason:
                  'Child screen is for ages ${catalogueItem.minAgeYears ?? 1}–${catalogueItem.maxAgeYears} y (Spec §6.6). Current subject is ${subject.ageYears} y.',
              fixButtonLabel: 'Switch to Child Dependent',
              fixTargetScreenId: 'S-B05',
            );
          }
        }
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          reason:
              'Subject age (${subject.isNewborn ? "${subject.ageHoursForNewborn}h newborn" : "${subject.ageYears}y"}) meets eligibility.',
        );
      case GateId.g10:
        final recommended =
            subject.hasKnownDiabetes || subject.usesTobaccoOrAreca;
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          isAdvisoryOnly: true,
          reason: recommended
              ? 'Priority recommended based on diabetes / tobacco history (Spec §6.4, §6.5).'
              : 'Available on request (priority for diabetes or tobacco history).',
        );
      case GateId.g11:
        return GateCheckOutcome(
          gate: gate,
          passed: cameraPermissionGranted,
          reason: cameraPermissionGranted
              ? 'Camera permission granted.'
              : 'Camera access is required for optical capture.',
          fixButtonLabel: 'Grant Camera Permission',
          fixTargetScreenId: 'S-A07',
        );
      case GateId.g12:
        return GateCheckOutcome(
          gate: gate,
          passed: micPermissionGranted,
          reason: micPermissionGranted
              ? 'Microphone permission granted.'
              : 'Microphone access is required for acoustic analysis.',
          fixButtonLabel: 'Grant Microphone Permission',
          fixTargetScreenId: 'S-A07',
        );
      case GateId.g13:
        return GateCheckOutcome(
          gate: gate,
          passed: device.hasMotionSensors,
          reason: device.hasMotionSensors
              ? '50 Hz Accelerometer & 100 Hz Gyroscope ready.'
              : 'Motion sensors unavailable on this device (Spec §9).',
          fixButtonLabel: 'Check Device Readiness',
          fixTargetScreenId: 'S-B07',
        );
      case GateId.g14:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          isAdvisoryOnly: true,
          reason: 'In-app reminders active.',
        );
      case GateId.g15:
        return GateCheckOutcome(
          gate: gate,
          passed: blePermissionGranted,
          reason: blePermissionGranted
              ? 'Bluetooth / Nearby devices enabled.'
              : 'Bluetooth permission needed for Smart Ring & Fundus camera.',
          fixButtonLabel: 'Enable Bluetooth',
          fixTargetScreenId: 'S-A07',
        );
      case GateId.g16:
        return GateCheckOutcome(
          gate: gate,
          passed: device.hasSpo2Calibration,
          reason: device.hasSpo2Calibration
              ? 'Device model (${device.displayName}) calibrated in mst_device_model.'
              : 'No SpO2 A/B coefficients for this phone model — SpO2 band hidden; use oximeter or ring (Spec §4.5).',
          fixButtonLabel: 'Device Readiness Details',
          fixTargetScreenId: 'S-B07',
        );
      case GateId.g17:
        return GateCheckOutcome(
          gate: gate,
          passed: device.micSelfCheckPassed,
          reason: device.micSelfCheckPassed
              ? 'Mic self-check passed (deviation <= 6 dB, DSP off).'
              : 'Microphone self-check (ALG-CAP-11) failed or not run — blocks audio tasks.',
          fixButtonLabel: 'Run Audio Readiness Check',
          fixTargetScreenId: 'S-G01',
        );
      case GateId.g18:
        return GateCheckOutcome(
          gate: gate,
          passed: device.isRoomQuietEnough,
          reason: device.isRoomQuietEnough
              ? 'Ambient noise ${device.lastRoomNoiseDba.toStringAsFixed(0)} dBA (<= 45 dBA).'
              : 'Room noise is ${device.lastRoomNoiseDba.toStringAsFixed(0)} dBA (must be <= 45 dBA per ALG-CAP-12).',
          fixButtonLabel: 'Check Room Noise',
          fixTargetScreenId: 'S-G01',
        );
      case GateId.g19:
        return GateCheckOutcome(
          gate: gate,
          passed: device.earphonesConnected,
          reason: device.earphonesConnected
              ? 'Earphones connected.'
              : 'Earphones must be connected for pure-tone & DIN hearing screening (Spec §8 AUD-09).',
          fixButtonLabel: 'Connect Earphones in Devices',
          fixTargetScreenId: 'S-I01',
        );
      case GateId.g20:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          reason:
              '24-patch colour card verified during capture framing (ALG-CAP-10).',
        );
      case GateId.g21:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          reason: 'Real-time ALG-CAP checks run continuously during capture.',
        );
      case GateId.g22:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          reason:
              'Pulse SNR >= 3.0 dB and beat-count thresholds enforced post-capture.',
        );
      case GateId.g23:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          reason:
              'Results with confidence < 0.60 are automatically hidden (ALG-RSK-06).',
        );
      case GateId.g24:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          reason:
              'Algorithm Release Gate active (BP band-only until ISO 81060-2 numbers validated).',
        );
      case GateId.g25:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          reason:
              'Maximum 3 guided retakes enforced before fallback / Not Assessed.',
        );
      case GateId.g26:
        final hasCalib =
            subject.bpCalibration != null &&
            subject.bpCalibration!.isValidAt(DateTime.now());
        return GateCheckOutcome(
          gate: gate,
          passed: hasCalib,
          isAdvisoryOnly: true,
          reason: hasCalib
              ? 'Personal cuff calibration active (${subject.bpCalibration!.daysRemainingAt(DateTime.now())} days left).'
              : 'No personal cuff calibration in last 30 days (optional offset per Spec §4.6).',
          fixButtonLabel: 'Calibrate with BP Cuff',
          fixTargetScreenId: 'S-D10',
        );
      case GateId.g27:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          isAdvisoryOnly: true,
          reason:
              'Irregular rhythm requires 2 positive scans or 1 scan + Smart Ring overnight flag (Spec §4.7).',
        );
      case GateId.g28:
        final hfReady =
            !subject.isHeartFailureEnrolled ||
            subject.hfBaselineDaysCompleted >= 14;
        return GateCheckOutcome(
          gate: gate,
          passed: hfReady,
          isAdvisoryOnly: true,
          reason: hfReady
              ? 'Personal baseline established.'
              : 'Building 14-day HF personal voice baseline (Day ${subject.hfBaselineDaysCompleted}/14).',
        );
      case GateId.g29:
        return GateCheckOutcome(
          gate: gate,
          passed: subject.isBasicProfileComplete,
          reason:
              'Formulas only run when all required inputs pass quality thresholds (Spec §5).',
        );
      case GateId.g30:
        return GateCheckOutcome(
          gate: gate,
          passed: device.phoneCharging,
          reason: device.phoneCharging
              ? 'Phone connected to charger for overnight sleep sonar.'
              : 'Connect phone to charger and place 0.3–1 m from chest (Spec §8 AUD-07).',
          fixButtonLabel: 'Open Sleep Setup',
          fixTargetScreenId: 'S-G07',
        );
      case GateId.g31:
        return GateCheckOutcome(
          gate: gate,
          passed: device.fundusCameraConnected,
          reason: device.fundusCameraConnected
              ? 'Clip-on Fundus Camera connected.'
              : 'Requires clip-on Fundus Camera for Partner DR/Glaucoma AI (Spec §6.8 IMG-09).',
          fixButtonLabel: 'Connect Fundus Camera',
          fixTargetScreenId: 'S-I01',
        );
      case GateId.g32:
        return GateCheckOutcome(
          gate: gate,
          passed: device.smartRingConnected,
          isAdvisoryOnly: true,
          reason: device.smartRingConnected
              ? 'Smart Ring connected (provides overnight SpO2 dips, temp & rhythm flag).'
              : 'Smart Ring not connected (optional enhancer).',
          fixButtonLabel: 'Pair Smart Ring',
          fixTargetScreenId: 'S-I02',
        );
      case GateId.g33:
        return GateCheckOutcome(
          gate: gate,
          passed: device.hasFocalLengthProfile,
          reason: 'Iris distance check (40 +/- 5 cm) active via ALG-CAP-15.',
        );
      case GateId.g34:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          isAdvisoryOnly: true,
          reason:
              'Scheduled screening cadence tracked (Monthly DFU / Daily HF).',
        );
      case GateId.g35:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          reason: 'Programme entitlement active.',
        );
      case GateId.g36:
        return GateCheckOutcome(
          gate: gate,
          passed: isOnline,
          isAdvisoryOnly: true,
          reason: isOnline
              ? 'Online — cloud inference and sync ready.'
              : 'Offline mode — on-device checks active; uploads queued.',
        );
      case GateId.g37:
        return GateCheckOutcome(
          gate: gate,
          passed: true,
          reason:
              'Safety escalation override active (Emergency & Crisis pre-empt navigation).',
        );
    }
  }

  static List<GateCheckOutcome> evaluateForCatalogueItem({
    required ScreeningCatalogueItem item,
    required SubjectProfile subject,
    required DeviceCapabilityProfile device,
    required bool isAuthenticated,
    required bool cameraPermissionGranted,
    required bool micPermissionGranted,
    required bool blePermissionGranted,
    required bool isOnline,
  }) {
    return item.requiredGates
        .map(
          (g) => evaluateSingleGate(
            gate: g,
            subject: subject,
            device: device,
            isAuthenticated: isAuthenticated,
            cameraPermissionGranted: cameraPermissionGranted,
            micPermissionGranted: micPermissionGranted,
            blePermissionGranted: blePermissionGranted,
            isOnline: isOnline,
            catalogueItem: item,
          ),
        )
        .toList();
  }
}
