import 'package:flutter/material.dart';
import '../../services/voice_coach_service.dart';
import 'enums.dart';

/// Represents a curated multi-scan Health Check Package (Bundled Screening Flow)
/// vs. Separate Individual Screenings.
class HealthScanPackage {
  const HealthScanPackage({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tagline,
    required this.totalDurationLabel,
    required this.badgeLabel,
    required this.gradientColors,
    required this.icon,
    required this.includedCatalogueIds,
    required this.biomarkersCovered,
    required this.permissionsNeeded,
    this.recommendedFor = 'All Adults (18+)',
  });

  final String id;
  final String title;
  final String subtitle;
  final String tagline;
  final String totalDurationLabel;
  final String badgeLabel;
  final List<Color> gradientColors;
  final IconData icon;
  final List<String> includedCatalogueIds;
  final List<String> biomarkersCovered;
  final List<ScanPermissionItem> permissionsNeeded;
  final String recommendedFor;
}

/// Registry of all 8 Curated Health Check Packages + Permission Requirements per Scan Type.
class HealthPackagesRegistry {
  static const List<ScanPermissionItem> facePermissions = [
    ScanPermissionItem(
      id: 'perm_cam_front',
      title: 'Front Camera Access (≥ 30 fps, AE/AWB Lock)',
      subtitle:
          'Tracks 468 facial landmarks & 7 capillary ROI zones for rPPG pulse extraction.',
      icon: Icons.camera_front_rounded,
    ),
    ScanPermissionItem(
      id: 'perm_voice_coach',
      title: 'Real-Time AI Voice Coach & Audio Alerts',
      subtitle:
          'Speaks aloud if your face leaves the frame, lighting drops, or when 1-minute reading finishes.',
      icon: Icons.record_voice_over_rounded,
    ),
    ScanPermissionItem(
      id: 'perm_light_imu',
      title: 'Ambient Light & Motion Stability Gate',
      subtitle:
          'Verifies brightness (80–220) and head stillness (< 3 px/frame).',
      icon: Icons.wb_sunny_outlined,
    ),
  ];

  static const List<ScanPermissionItem> fingerPermissions = [
    ScanPermissionItem(
      id: 'perm_cam_rear',
      title: 'Rear Optical Camera Access (≥ 30 fps)',
      subtitle:
          'Captures red/green capillary pulsatile absorption from your index fingertip.',
      icon: Icons.camera_rear_rounded,
    ),
    ScanPermissionItem(
      id: 'perm_torch',
      title: 'LED Flashlight / Torch Control',
      subtitle:
          'Illuminates fingertip capillary bed for calibrated SpO2 Band & Perfusion Index (PI% >= 0.3%).',
      icon: Icons.flashlight_on_rounded,
    ),
    ScanPermissionItem(
      id: 'perm_voice_coach',
      title: 'AI Voice & Haptic Pressure Coach',
      subtitle:
          'Alerts you if your finger slips off the lens or presses too hard.',
      icon: Icons.vibration_rounded,
    ),
  ];

  static const List<ScanPermissionItem> eyeAndSkinPermissions = [
    ScanPermissionItem(
      id: 'perm_cam_macro',
      title: 'High-Resolution Rear Camera (≥ 1080p Macro)',
      subtitle:
          'Captures lower eyelid conjunctiva, sclera, cornea, oral mucosa, or skin lesion.',
      icon: Icons.center_focus_strong_rounded,
    ),
    ScanPermissionItem(
      id: 'perm_flash_card',
      title: 'Flash Illumination & 24-Patch Colour Card Check',
      subtitle:
          'Calibrates lighting colour accuracy (delta-E <= 5.0) and checks glare (<= 5%).',
      icon: Icons.palette_outlined,
    ),
    ScanPermissionItem(
      id: 'perm_voice_coach',
      title: '2-Second Auto-Shutter Voice Coach',
      subtitle:
          'Counts down 2.0 seconds of steady framing and confirms capture.',
      icon: Icons.record_voice_over_rounded,
    ),
  ];

  static const List<ScanPermissionItem> dentalPermissions = [
    ScanPermissionItem(
      id: 'perm_cam_dental',
      title: 'Rear Camera + Torch Illumination',
      subtitle:
          'Captures 4 guided mouth photos (front teeth closed, front teeth open, upper and lower biting surfaces) with the torch on.',
      icon: Icons.sentiment_satisfied_alt_rounded,
    ),
    ScanPermissionItem(
      id: 'perm_dental_consent',
      title: 'Dental / Guardian Screening Consent (G-05)',
      subtitle: 'Required before photographing adult or child dentition.',
      icon: Icons.verified_user_outlined,
    ),
  ];

  static const List<ScanPermissionItem> audioPermissions = [
    ScanPermissionItem(
      id: 'perm_mic_raw',
      title: 'Microphone Access (16–48 kHz Uncompressed PCM)',
      subtitle:
          'Records cough bursts, sustained vowels ("aaa"/"sss"/"zzz"), forced exhale, or overnight breathing.',
      icon: Icons.mic_rounded,
    ),
    ScanPermissionItem(
      id: 'perm_noise_gate',
      title: 'Ambient Room Noise Gate (≤ 45 dBA)',
      subtitle:
          'Verifies quiet room environment before recording respiratory or voice acoustics.',
      icon: Icons.volume_down_rounded,
    ),
    ScanPermissionItem(
      id: 'perm_speaker',
      title: 'Speaker Output (Voice Coach / Sonar / Audiometry)',
      subtitle:
          'Plays voice coaching prompts, 18–20 kHz sleep sonar, or calibrated hearing tones.',
      icon: Icons.speaker_phone_rounded,
    ),
  ];

  /// Gait, sit-to-stand and tremor (S-H03..S-H05): motion sensors only.
  static const List<ScanPermissionItem> motionSensorPermissions = [
    ScanPermissionItem(
      id: 'perm_motion',
      title: 'Motion sensors (accelerometer 50 Hz, gyroscope 100 Hz)',
      subtitle:
          'Counts steps and stands and measures hand tremor (3–12 Hz). iOS asks for Motion & Fitness; Android needs no permission below 200 Hz (G-13).',
      icon: Icons.sensors_rounded,
    ),
  ];

  /// Finger tapping — video (S-H01): front camera for hand tracking.
  static const List<ScanPermissionItem> handCameraPermissions = [
    ScanPermissionItem(
      id: 'perm_cam_front_hand',
      title: 'Front camera (hand tracking)',
      subtitle:
          'Tracks 21 hand landmarks at ≥ 30 fps to measure thumb–index tapping. Video stays on the device (G-11).',
      icon: Icons.back_hand_rounded,
    ),
  ];

  /// Finger tapping — touch (S-H02): touch screen only.
  static const List<ScanPermissionItem> touchPermissions = [
    ScanPermissionItem(
      id: 'perm_touch',
      title: 'Touch screen',
      subtitle:
          'Millisecond timestamps of taps on two on-screen targets. No OS permission needed.',
      icon: Icons.touch_app_rounded,
    ),
  ];

  /// Hearing screen (S-G10): earphones, media volume and a microphone
  /// room-noise check (Spec §8 AUD-09, G-18 / G-19).
  static const List<ScanPermissionItem> hearingPermissions = [
    ScanPermissionItem(
      id: 'hearing_earphones',
      title: 'Earphones and media volume (G-19)',
      subtitle:
          'Plays soft pure tones through wired or Bluetooth earphones; the app sets the volume to maximum on Android.',
      icon: Icons.headphones_rounded,
    ),
    ScanPermissionItem(
      id: 'perm_mic_noise',
      title: 'Microphone — room-noise check (G-18)',
      subtitle:
          'A 3-second A-weighted level check before and during the test (ALG-CAP-12, limit 45 dBA). Nothing is stored.',
      icon: Icons.mic_rounded,
    ),
  ];

  /// Brain & Mind speech checks (S-G12 cognitive, S-G13 mood, S-G15 HF).
  static const List<ScanPermissionItem> mindSpeechPermissions = [
    ScanPermissionItem(
      id: 'perm_mic_speech',
      title: 'Microphone — speech tasks (G-12)',
      subtitle:
          'Records 30–60 s speech tasks; cognitive tasks also use on-device speech recognition (te / hi / en). Room noise is checked first (G-18).',
      icon: Icons.mic_rounded,
    ),
  ];

  /// Stroke act-now check (S-H06): front camera, motion sensor, microphone.
  static const List<ScanPermissionItem> strokePermissions = [
    ScanPermissionItem(
      id: 'stroke_camera',
      title: 'Front camera — smile symmetry (MOV-06)',
      subtitle: 'Face landmarks at rest and at peak smile. Nothing is stored.',
      icon: Icons.face_retouching_natural_rounded,
    ),
    ScanPermissionItem(
      id: 'stroke_motion',
      title: 'Motion sensor — arm drift (MOV-07)',
      subtitle: 'Phone tilt during the 10 s arm hold, each arm.',
      icon: Icons.back_hand_rounded,
    ),
    ScanPermissionItem(
      id: 'stroke_mic',
      title: 'Microphone — sentence repeat (MOV-08)',
      subtitle:
          'Speech recognition of one fixed sentence. Never blocks: skip any step.',
      icon: Icons.mic_rounded,
    ),
  ];

  /// Visual acuity (S-H07): front camera for the 40 cm distance check.
  static const List<ScanPermissionItem> visionCameraPermissions = [
    ScanPermissionItem(
      id: 'vision_camera',
      title: 'Front camera — distance check',
      subtitle:
          'Keeps you at 40 ± 5 cm for the letter sizes (ALG-CAP-15, G-33). Nothing is recorded.',
      icon: Icons.social_distance_rounded,
    ),
  ];

  /// Colour plates and Amsler grid (S-H08, S-H09): screen only.
  static const List<ScanPermissionItem> visionScreenPermissions = [
    ScanPermissionItem(
      id: 'vision_screen',
      title: 'Screen at full brightness',
      subtitle:
          'The app sets brightness to 100 % for the plates and grid, then puts it back.',
      icon: Icons.brightness_high_rounded,
    ),
  ];

  /// Reaction time (S-H10): touch + speaker.
  static const List<ScanPermissionItem> reactionPermissions = [
    ScanPermissionItem(
      id: 'reaction_sound',
      title: 'Speaker — sound signals',
      subtitle: 'Ten beeps are played for the sound block; media volume up.',
      icon: Icons.volume_up_rounded,
    ),
  ];

  static const List<ScanPermissionItem> movementVisionPermissions = [
    ScanPermissionItem(
      id: 'perm_imu',
      title: '6-Axis Motion Sensors (Accelerometer & Gyroscope)',
      subtitle:
          'Measures gait cadence, sit-to-stand power, postural/rest tremor (3–12 Hz), and arm drift.',
      icon: Icons.sensors_rounded,
    ),
    ScanPermissionItem(
      id: 'perm_touch_cam',
      title: 'High-Speed Touch Digitizer & Front Camera Distance Lock',
      subtitle:
          'Tracks millisecond finger tapping, reaction time, and 40 cm viewing distance for vision charts.',
      icon: Icons.touch_app_rounded,
    ),
  ];

  static List<ScanPermissionItem> permissionsForTargetScreen(
    String targetScreenId, {
    ImageScreenType? imageScreenType,
  }) {
    if (imageScreenType != null || targetScreenId.startsWith('S-E')) {
      return eyeAndSkinPermissions;
    }
    if (targetScreenId == 'S-D04') return fingerPermissions;
    if (targetScreenId.startsWith('S-D')) return facePermissions;
    if (targetScreenId.startsWith('S-F')) return dentalPermissions;
    if (targetScreenId == 'S-G10' || targetScreenId == 'S-G11') {
      return hearingPermissions;
    }
    if (targetScreenId == 'S-G12' ||
        targetScreenId == 'S-G13' ||
        targetScreenId == 'S-G15') {
      return mindSpeechPermissions;
    }
    if (targetScreenId == 'S-H06') return strokePermissions;
    if (targetScreenId.startsWith('S-G')) return audioPermissions;
    if (targetScreenId == 'S-H01') return handCameraPermissions;
    if (targetScreenId == 'S-H02') return touchPermissions;
    if (targetScreenId == 'S-H03' ||
        targetScreenId == 'S-H04' ||
        targetScreenId == 'S-H05') {
      return motionSensorPermissions;
    }
    if (targetScreenId == 'S-H07') return visionCameraPermissions;
    if (targetScreenId == 'S-H08' || targetScreenId == 'S-H09') {
      return visionScreenPermissions;
    }
    if (targetScreenId == 'S-H10') return reactionPermissions;
    if (targetScreenId.startsWith('S-H')) return movementVisionPermissions;
    return facePermissions;
  }

  static List<String> preparationTipsForTargetScreen(
    String targetScreenId, {
    ImageScreenType? imageScreenType,
  }) {
    if (targetScreenId == 'S-D04') {
      return const [
        'Cover both the rear camera lens and LED flash gently with your index fingertip.',
        'Do not press too hard—excess pressure blocks capillary blood flow.',
        'Keep your hand resting flat on a table for 30 seconds.',
      ];
    }
    if (targetScreenId.startsWith('S-D')) {
      return const [
        'Sit comfortably upright and face an even light source (avoid strong backlight).',
        'Keep your face centered inside the oval frame—voice coach will alert you if you drift out.',
        'Breathe normally and remain still for the full 60-second reading.',
      ];
    }
    if (imageScreenType == ImageScreenType.newbornJaundice) {
      return const [
        'Lay the baby on its back in daylight; switch off yellow lamps and any phototherapy light.',
        'Place the 24-patch colour card flat on the skin beside the forehead, then the chest — it is mandatory.',
        'Hold the phone 20–25 cm away, parallel to the skin; the app takes one shot without and one with flash per area.',
      ];
    }
    if (imageScreenType == ImageScreenType.diabeticFoot) {
      return const [
        'Socks off, feet washed and dried, no cream. A helper or a floor mirror makes the sole photos easy.',
        'Lay the colour card flat beside the sole for scale; whole sole from toes to heel in the frame, 20–30 cm away.',
        'Spread the toes for the between-toes photo. Left foot first, then right.',
      ];
    }
    if (imageScreenType == ImageScreenType.skinLesion) {
      return const [
        'Daylight, flash off. Wipe make-up or cream off the spot and clear any hair across it.',
        'Spot centred in the ring 10–15 cm away with a card or coin beside it; then an angled close-up.',
        'Finish with a wider photo from arm\x27s length showing where the spot is on the body.',
      ];
    }
    if (imageScreenType != null || targetScreenId.startsWith('S-E')) {
      return const [
        'Hold the camera 10–15 cm from the target area until the focus ring turns green.',
        'Place the 24-patch reference colour card in frame when prompted.',
        'Hold steady for 2.0 seconds for automatic glare-free shutter capture.',
      ];
    }
    if (targetScreenId.startsWith('S-F')) {
      return const [
        'Brush or rinse, then dry the teeth with a tissue; pull the lips back with clean fingers.',
        'Four photos with the torch on: front teeth closed, front teeth open, upper biting surfaces (head back), lower biting surfaces (tongue up).',
      ];
    }
    switch (targetScreenId) {
      case 'S-G12':
        return const [
          'Quiet room, phone 20–30 cm from your mouth, your usual language selected.',
          'Name as many different animals as you can for 60 s, then describe the park picture for 60 s.',
          'Values are shown without a band until the age / education norms are released.',
        ];
      case 'S-G13':
        return const [
          'Somewhere private. Answer about the last two weeks: 9 PHQ-9 and 7 GAD-7 questions.',
          'Then talk freely for 60 s. A support button is on every screen.',
          'A "thoughts of self-harm" answer opens Crisis Support immediately and tells your clinician.',
        ];
      case 'S-G15':
        return const [
          'Same quiet place and time each morning; sit upright.',
          'Read the sentence aloud for 30 s. Days 1–14 build your baseline; alerts start from day 15.',
        ];
      case 'S-H06':
        return const [
          'If the person cannot smile, lift an arm or speak — call 108 / 112 first.',
          'Face: relax then smile at the camera. Arms: phone in each hand, arm out, eyes closed, 10 s. Speech: repeat the sentence.',
          'Any one sign goes straight to the emergency screen; note when symptoms started.',
        ];
    }
    if (targetScreenId == 'S-G10' || targetScreenId == 'S-G11') {
      return const [
        'Earphones in both ears (red or "R" side in the right ear), volume at maximum, no other app playing sound.',
        'Quiet room: TV, fan and music off. The app checks the room for 3 seconds before starting (limit 45 dBA).',
        'Tap the big button every time you hear a beep, even a faint one. Right ear first, then left.',
      ];
    }
    if (targetScreenId.startsWith('S-G')) {
      return const [
        'Ensure background room noise is below 45 dBA (turn off fans or TV).',
        'Hold the phone 20–30 cm from your mouth during cough, voice, or forced exhale tasks.',
      ];
    }
    switch (targetScreenId) {
      case 'S-H01':
        return const [
          'Prop the phone upright at chest height with the front camera facing you, in bright even light.',
          'Hold one hand 30–50 cm from the camera, palm facing the phone, whole hand inside the outline.',
          'Tap index finger and thumb together as big and as fast as you can for 10 s per hand.',
        ];
      case 'S-H02':
        return const [
          'Lay the phone flat on a table and rest your forearm beside it.',
          'Tap the two circles alternately with one index finger for 10 s per hand; only alternating taps count.',
          'Wait for "Go" — taps before the countdown ends are ignored.',
        ];
      case 'S-H03':
        return const [
          'Measure and mark a straight 10-metre path (a tape, or 13 adult paces).',
          'After tapping Start you have 5 s to put the phone in your front trouser pocket, screen towards your leg.',
          'Walk at your normal pace in your usual shoes; stand still at the end and the app stops by itself.',
        ];
      case 'S-H04':
        return const [
          'Use a chair without arms, back against a wall, seat about knee height (43 cm).',
          'Sit in the middle, feet flat, arms crossed at the wrists on your chest, phone in the front pocket.',
          'On "Go" stand fully and sit back down as many times as you can in 30 s; stop if you need your arms.',
        ];
      case 'S-H05':
        return const [
          'Sit with your back supported and hold the phone flat in one hand.',
          'Stretch the arm straight out in front at shoulder height, palm down, and keep the bubble centred.',
          'Hold as still as you can for 20 s; large slow movements restart the recording. Then the other hand.',
        ];
      case 'S-H07':
        return const [
          'Wear your usual distance glasses. Cover the left eye with your palm; the right eye is tested first.',
          'Hold the phone at arm\'s length (40 cm). The badge turns green at the right distance; letters pause if you drift.',
          'Swipe or tap the way the E points; tap "Not sure" if you cannot tell. Then swap eyes.',
        ];
      case 'S-H08':
        return const [
          'Turn off night mode and colour filters; the app sets brightness to 100 %.',
          'Both eyes open. Find the number hidden in each plate and tap it (12 plates).',
          'Tap "I see nothing" rather than guessing.',
        ];
      case 'S-H09':
        return const [
          'Wear reading glasses if you use them. Hold the phone about 30 cm away.',
          'Cover one eye, stare at the centre dot and judge the lines without looking away.',
          'Drag over any area that looks wavy, blurred or missing, or tap "Looks normal". Then the other eye.',
        ];
      case 'S-H10':
        return const [
          'Media volume up, phone on a table or held firmly, one finger ready above the screen.',
          'Wait for the flash (10 times), then for the beep (10 times), and tap as fast as you can.',
          'A tap before the signal is a false start and is repeated.',
        ];
    }
    return const [
      'Follow the live voice coach prompts and on-screen alignment guides.',
    ];
  }

  static const List<HealthScanPackage> packages = [
    HealthScanPackage(
      id: 'pkg_complete_vitals',
      title: '60s Complete Vitals & Cardio Pack',
      subtitle:
          'Face rPPG (60s) + Finger SpO2 (30s) + 15 Cardio & Fitness Formulas',
      tagline: 'MOST POPULAR DAILY CHECK',
      totalDurationLabel: '90 sec',
      badgeLabel: '18 Biomarkers',
      gradientColors: [Color(0xFF0B7A75), Color(0xFF0A3641)],
      icon: Icons.monitor_heart_rounded,
      includedCatalogueIds: ['cat_vitals_face', 'cat_vitals_finger'],
      biomarkersCovered: [
        'Heart Rate (BPM)',
        'Respiratory Rate (br/min)',
        'SpO2 Oxygen Band (%)',
        'Blood Pressure Band',
        'HRV (SDNN, RMSSD, pNN50)',
        'Baevsky Stress Index',
        'Pulse Rhythm & AF Screen',
        'Vascular Age & Stiffness',
        'Diabetes PPG Risk',
        'MAP, PP, Shock Index, RPP, VO2max',
      ],
      permissionsNeeded: [...facePermissions, ...fingerPermissions],
      recommendedFor: 'Daily Wellness, Hypertension & Fitness Tracking',
    ),
    HealthScanPackage(
      id: 'pkg_annual_master',
      title: '360° Full-Body Clinical Triage Pack',
      subtitle:
          'Face Vitals + Anaemia Eyelid + Adult Jaundice + Dental 4-View + Cough/Lung + Vision',
      tagline: 'COMPLETE MULTI-SYSTEM SCREEN',
      totalDurationLabel: '4 min',
      badgeLabel: '35+ Biomarkers',
      gradientColors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
      icon: Icons.health_and_safety_rounded,
      includedCatalogueIds: [
        'cat_vitals_face',
        'cat_img_anaemia',
        'cat_img_jaundice',
        'cat_dental_full',
        'cat_aud_tb',
        'cat_vis_acuity',
      ],
      biomarkersCovered: [
        'Full Face Vitals & HRV',
        'Haemoglobin Anaemia Band',
        'Scleral Bilirubin Jaundice',
        '32-Tooth FDI Caries Chart',
        'Cough TB & COPD/Asthma Screen',
        'Distance & Near Visual Acuity',
      ],
      permissionsNeeded: [
        ...facePermissions,
        ...eyeAndSkinPermissions,
        ...audioPermissions,
      ],
      recommendedFor: 'Comprehensive Preventive Health Check',
    ),
    HealthScanPackage(
      id: 'pkg_metabolic_diabetes',
      title: 'Heart, BP & Diabetes Care Pack',
      subtitle:
          'Face Vitals & DM Risk + Orthostatic Stand + Diabetic Foot Ulcer + Retinal Fundus',
      tagline: 'CARDIO-METABOLIC CARE',
      totalDurationLabel: '3 min',
      badgeLabel: '14 Biomarkers',
      gradientColors: [Color(0xFF047857), Color(0xFF064E3B)],
      icon: Icons.bloodtype_rounded,
      includedCatalogueIds: [
        'cat_vitals_face',
        'cat_vitals_ortho',
        'cat_img_dfu',
        'cat_img_fundus',
      ],
      biomarkersCovered: [
        'BP Band & Arterial Stiffness',
        'PPG Diabetes Risk Band',
        'Asian BMI, WHtR & Body Fat %',
        'Orthostatic Autonomic HR Rise',
        'Diabetic Foot Ulcer & Wound Area',
        'Referable Diabetic Retinopathy',
      ],
      permissionsNeeded: [...facePermissions, ...eyeAndSkinPermissions],
      recommendedFor: 'Adults with Diabetes, Pre-Diabetes, or High BP',
    ),
    HealthScanPackage(
      id: 'pkg_maternal_anaemia',
      title: 'Maternal & Women’s Wellness Pack',
      subtitle: 'Lower Eyelid Anaemia Hb + Face BP/HR/Stress Scan + Mood Check',
      tagline: 'MATERNAL & IRON SCREEN',
      totalDurationLabel: '2.5 min',
      badgeLabel: '12 Biomarkers',
      gradientColors: [Color(0xFF9D174D), Color(0xFF500724)],
      icon: Icons.pregnant_woman_rounded,
      includedCatalogueIds: ['cat_img_anaemia', 'cat_vitals_face', 'cat_mood'],
      biomarkersCovered: [
        'WHO Pregnancy-Adjusted Haemoglobin Band (<11.0 g/dL)',
        'Blood Pressure & Resting HR',
        'Baevsky Autonomic Stress',
        'PHQ-9 & GAD-7 Emotional Wellbeing',
      ],
      permissionsNeeded: [...eyeAndSkinPermissions, ...facePermissions],
      recommendedFor:
          'Women & Expectant Mothers (Urgent Anaemia Escalation T12)',
    ),
    HealthScanPackage(
      id: 'pkg_child_growth_dental',
      title: 'Child Growth, Eye & Dental Pack (1–12 yrs)',
      subtitle:
          'Child Eye Red-Reflex/Squint + 20-Tooth Child Dental + Pure-Tone Hearing',
      tagline: 'PAEDIATRIC MILESTONES',
      totalDurationLabel: '3 min',
      badgeLabel: 'Paediatric',
      gradientColors: [Color(0xFF6D28D9), Color(0xFF3B0764)],
      icon: Icons.child_care_rounded,
      includedCatalogueIds: [
        'cat_img_child_eye',
        'cat_dental_full',
        'cat_hearing',
      ],
      biomarkersCovered: [
        'WHO Growth Z-Scores (HAZ, WAZ, BMIZ)',
        'White Pupil (Leukocoria) & Strabismus Degrees',
        '20-Primary-Tooth Caries & Pit-Fissure Sealant Map',
        '4-Frequency Pure-Tone Paediatric Hearing',
      ],
      permissionsNeeded: [
        ...eyeAndSkinPermissions,
        ...dentalPermissions,
        ...audioPermissions,
      ],
      recommendedFor: 'Children Ages 1 to 12 Years (Guardian Consent G-05)',
    ),
    HealthScanPackage(
      id: 'pkg_newborn_jaundice',
      title: 'Newborn Jaundice & Vitals Pack (0–28 Days)',
      subtitle:
          'Mandatory Colour-Card Transcutaneous Bilirubin + Neonatal Breathing & HR',
      tagline: 'NEONATAL SAFETY (0–28 DAYS)',
      totalDurationLabel: '90 sec',
      badgeLabel: 'Neonatal',
      gradientColors: [Color(0xFFB45309), Color(0xFF451A03)],
      icon: Icons.crib_rounded,
      includedCatalogueIds: ['cat_img_newborn_jaundice', 'cat_vitals_face'],
      biomarkersCovered: [
        'Forehead & Chest Skin Bilirubin Estimate (mg/dL)',
        'Bhutani Hour-Specific Phototherapy Action Band',
        '24-Patch Colour Card Delta-E Verification (<= 5)',
      ],
      permissionsNeeded: eyeAndSkinPermissions,
      recommendedFor: 'Newborns 0–28 Days Old (Mandatory Colour Card G-20)',
    ),
    HealthScanPackage(
      id: 'pkg_respiratory_sleep',
      title: 'Respiratory, Cough TB & Sleep Apnea Pack',
      subtitle:
          'Cough TB/COPD Screen + Forced Exhale Spirometry + Voice Acoustic + Sleep Sonar',
      tagline: 'LUNG & AIRWAY LAB',
      totalDurationLabel: '3 min + Sleep',
      badgeLabel: '10 Biomarkers',
      gradientColors: [Color(0xFF0369A1), Color(0xFF082F49)],
      icon: Icons.air_rounded,
      includedCatalogueIds: [
        'cat_aud_tb',
        'cat_aud_spirometry',
        'cat_aud_voice',
        'cat_sleep_sonar',
      ],
      biomarkersCovered: [
        'Wet/Dry Cough & WHO TB Triage Probability',
        'COPD / Asthma Pattern & mMRC Grade',
        'Forced Exhale FEV1, FVC, FEV1/FVC & PEF (% Predicted)',
        'Voice Jitter, Shimmer, HNR &Hoarseness',
        'Overnight Sonar Breathing Rate & OSA AHI Band',
      ],
      permissionsNeeded: audioPermissions,
      recommendedFor: 'Chronic Cough, Breathlessness, Snoring, or Smokers',
    ),
    HealthScanPackage(
      id: 'pkg_senior_neuro_vision',
      title: 'Senior Neuro, Stroke FAST & Vision Pack (50+)',
      subtitle:
          'Stroke FAST + Finger Tap & Tremor + Cognitive Speech + Amsler Macular + Cataract',
      tagline: 'HEALTHY AGEING & NEURO',
      totalDurationLabel: '8 min',
      badgeLabel: '18 Biomarkers',
      gradientColors: [Color(0xFF4338CA), Color(0xFF1E1B4B)],
      icon: Icons.psychology_rounded,
      includedCatalogueIds: [
        'cat_stroke_fast',
        'cat_mov_tap_video',
        'cat_mov_gait',
        'cat_mov_sts',
        'cat_mov_tremor',
        'cat_cognitive',
        'cat_img_cataract',
        'cat_vis_amsler',
      ],
      biomarkersCovered: [
        'Stroke FAST (Facial Droop, Arm Drift, Speech Slur)',
        'Bradykinesia Tap Decrement & 3–12 Hz Postural Tremor',
        '10-m Gait Speed, Cadence & 30-s Sit-to-Stand Count',
        'Bilingual Cognitive Recall & Fluency',
        'Cataract Opacity & Macular Amsler Distortion',
      ],
      permissionsNeeded: [
        ...movementVisionPermissions,
        ...audioPermissions,
        ...eyeAndSkinPermissions,
      ],
      recommendedFor: 'Adults 50+ & Neurological / Vision Monitoring',
    ),
  ];
}
