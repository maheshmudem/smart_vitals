// Implements Spec §2 Capture and Quality Checks (ALG-CAP-01 to ALG-CAP-15)
// and Spec §3 Finger PPG quality checks (ALG-PUL-06).

class CaptureCheckSpec {
  const CaptureCheckSpec({
    required this.id,
    required this.name,
    required this.outputMarker,
    required this.passRuleText,
    required this.onFailCoaching,
    required this.resetsTimerOnFail,
  });

  final String id;
  final String name;
  final String outputMarker;
  final String passRuleText;
  final String onFailCoaching;
  final bool resetsTimerOnFail;
}

class CaptureCheckEvaluation {
  const CaptureCheckEvaluation({
    required this.spec,
    required this.passed,
    required this.measuredValueLabel,
  });

  final CaptureCheckSpec spec;
  final bool passed;
  final String measuredValueLabel;
}

class CaptureQualityEngine {
  static const Map<String, CaptureCheckSpec> specs = {
    'ALG-CAP-01': CaptureCheckSpec(
      id: 'ALG-CAP-01',
      name: 'Face found and posed',
      outputMarker: 'face_size_px, yaw_deg, pitch_deg',
      passRuleText: 'Face width >= 200 px; |yaw| <= 15°; |pitch| <= 15°',
      onFailCoaching: 'Move closer / face the camera',
      resetsTimerOnFail: false,
    ),
    'ALG-CAP-02': CaptureCheckSpec(
      id: 'ALG-CAP-02',
      name: 'ROI segmentation (7 polygons)',
      outputMarker: 'roi_pixel_count per ROI',
      passRuleText: 'Each ROI >= 400 px; >= 4 usable ROIs',
      onFailCoaching: 'Keep full face visible in the oval',
      resetsTimerOnFail: false,
    ),
    'ALG-CAP-03': CaptureCheckSpec(
      id: 'ALG-CAP-03',
      name: 'Light level',
      outputMarker: 'illuminance_luma (0–255)',
      passRuleText: 'Mean luma 60–220',
      onFailCoaching: 'Move to brighter place / Avoid direct light',
      resetsTimerOnFail: false,
    ),
    'ALG-CAP-04': CaptureCheckSpec(
      id: 'ALG-CAP-04',
      name: 'Motion',
      outputMarker: 'motion_px_s, motion_high_pct',
      passRuleText: 'motion_px_s <= 3; high-motion frames <= 20%',
      onFailCoaching: 'Hold still',
      resetsTimerOnFail: true, // Spec §2: "Hold still" and restart
    ),
    'ALG-CAP-05': CaptureCheckSpec(
      id: 'ALG-CAP-05',
      name: 'Skin validity (YCbCr)',
      outputMarker: 'skin_valid_pct (0–100)',
      passRuleText: 'skin_valid_pct >= 80% (Cb 77–127, Cr 133–173)',
      onFailCoaching: 'Remove mask / hair from forehead',
      resetsTimerOnFail: false,
    ),
    'ALG-CAP-06': CaptureCheckSpec(
      id: 'ALG-CAP-06',
      name: 'Blur (Laplacian variance)',
      outputMarker: 'blur_score (0–5000)',
      passRuleText: 'blur_score >= 100',
      onFailCoaching: 'Autofocus tap + retake',
      resetsTimerOnFail: true,
    ),
    'ALG-CAP-07': CaptureCheckSpec(
      id: 'ALG-CAP-07',
      name: 'Glare / exposure',
      outputMarker: 'glare_pct, dark_pct (0–100)',
      passRuleText: 'glare <= 5%; dark <= 10%',
      onFailCoaching: 'Tilt phone / more light',
      resetsTimerOnFail: true,
    ),
    'ALG-CAP-08': CaptureCheckSpec(
      id: 'ALG-CAP-08',
      name: 'Image-quality classifier',
      outputMarker: 'iq_score (0–1)',
      passRuleText: 'iq_score >= 0.70 (MobileNetV3-small)',
      onFailCoaching: 'Retake with clearer framing',
      resetsTimerOnFail: true,
    ),
    'ALG-CAP-09': CaptureCheckSpec(
      id: 'ALG-CAP-09',
      name: 'Body-part detection',
      outputMarker: 'part_found, mask coverage %',
      passRuleText: 'Coverage >= 80% of expected region',
      onFailCoaching: 'Show the whole target area',
      resetsTimerOnFail: true,
    ),
    'ALG-CAP-10': CaptureCheckSpec(
      id: 'ALG-CAP-10',
      name: '24-patch colour card',
      outputMarker: 'card_found, colour_error_de',
      passRuleText: 'Card found and delta-E <= 5 after 3x3 correction',
      onFailCoaching: 'Place 24-patch colour card in frame',
      resetsTimerOnFail: true,
    ),
    'ALG-CAP-11': CaptureCheckSpec(
      id: 'ALG-CAP-11',
      name: 'Microphone self-check',
      outputMarker: 'mic_response_dev_db, audio_processing_detected',
      passRuleText: 'Deviation <= 6 dB; OS processing not detected',
      onFailCoaching: 'Uncover microphone and disable OS noise suppression',
      resetsTimerOnFail: true,
    ),
    'ALG-CAP-12': CaptureCheckSpec(
      id: 'ALG-CAP-12',
      name: 'Room noise (3 s silence)',
      outputMarker: 'noise_dba (20–100)',
      passRuleText: 'noise_dba <= 45 dBA',
      onFailCoaching: 'Move to a quieter room (<= 45 dBA)',
      resetsTimerOnFail: true,
    ),
    'ALG-CAP-13': CaptureCheckSpec(
      id: 'ALG-CAP-13',
      name: 'Clipping and audio SNR',
      outputMarker: 'clip_pct, audio_snr_db',
      passRuleText: 'clip <= 1%; SNR >= 15 dB',
      onFailCoaching: 'Move phone further / quieter room',
      resetsTimerOnFail: true,
    ),
    'ALG-CAP-14': CaptureCheckSpec(
      id: 'ALG-CAP-14',
      name: 'Audio–video sync',
      outputMarker: 'av_offset_ms, sync_found',
      passRuleText: 'sync_found = true (offset within +/-20 ms)',
      onFailCoaching: 'Re-record audio-video sync',
      resetsTimerOnFail: true,
    ),
    'ALG-CAP-15': CaptureCheckSpec(
      id: 'ALG-CAP-15',
      name: 'Face distance (Iris 11.7 mm)',
      outputMarker: 'face_distance_cm (15–100)',
      passRuleText: 'Vision test: 40 +/- 5 cm (35–45 cm)',
      onFailCoaching: 'Move closer / further (hold at 40 cm)',
      resetsTimerOnFail: false,
    ),
    'ALG-PUL-06': CaptureCheckSpec(
      id: 'ALG-PUL-06',
      name: 'Finger PPG contact & pressure',
      outputMarker: 'bvp_finger (mean red)',
      passRuleText: 'Centre 50% red < 250 (unsaturated) with pulse wave',
      onFailCoaching: 'press lighter / cover lens fully',
      resetsTimerOnFail: false,
    ),
  };

  static bool checkFacePose({
    required double faceWidthPx,
    required double yawDeg,
    required double pitchDeg,
  }) {
    return faceWidthPx >= 200.0 &&
        yawDeg.abs() <= 15.0 &&
        pitchDeg.abs() <= 15.0;
  }

  static bool checkLightLuma(double meanLuma) =>
      meanLuma >= 60.0 && meanLuma <= 220.0;

  static bool checkMotion({
    required double motionPxPerSec,
    required double highMotionFramesPct,
  }) {
    return motionPxPerSec <= 3.0 && highMotionFramesPct <= 20.0;
  }

  static bool checkSkinValidityPct(double skinValidPct) => skinValidPct >= 80.0;

  static bool checkBlurScore(double blurScore) => blurScore >= 100.0;

  static bool checkGlareAndDark({
    required double glarePct,
    required double darkPct,
  }) {
    return glarePct <= 5.0 && darkPct <= 10.0;
  }

  static bool checkImageQualityClassifier(double iqScore) => iqScore >= 0.70;

  static bool checkBodyPartCoverage(double coveragePct) => coveragePct >= 80.0;

  static bool checkColourCard({
    required bool cardFound,
    required double deltaEAfterCorrection,
  }) {
    return cardFound && deltaEAfterCorrection <= 5.0;
  }

  static bool checkMicSweep({
    required double deviationDb,
    required bool audioProcessingDetected,
  }) {
    return deviationDb <= 6.0 && !audioProcessingDetected;
  }

  static bool checkRoomNoise(double noiseDba) => noiseDba <= 45.0;

  static bool checkAudioClipAndSnr({
    required double clipPct,
    required double snrDb,
  }) {
    return clipPct <= 1.0 && snrDb >= 15.0;
  }

  static bool checkVisionFaceDistance(double distanceCm) =>
      distanceCm >= 35.0 && distanceCm <= 45.0;
}
