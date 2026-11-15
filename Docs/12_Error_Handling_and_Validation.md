# 12 — Error Handling, Signal Fallbacks & Validation Rules

> **Document ID:** `12_Error_Handling_and_Validation.md`
> **Primary Provenance:** `[DOC]` (all capture, signal, marker, and risk failure rules from Spec §§2–14) / `[DER]` (error code taxonomy, input validators, Dart sealed failure hierarchy)
> **Cross-References:** `00_README_Index.md` · `07_Feature_Lifecycle_and_States.md` · `08_Health_Readings_and_Metrics.md` · `09_AI_ML_Algorithm_Documentation.md` · `11_Data_Models_and_Entities.md`

---

## 1. Medical Safety Principles for Error & Failure Handling `[DOC]`

1. **Zero Fabricated Outputs:** When a capture check fails, a signal is noisy, or an input is missing, VitalsMirror **never** guesses, extrapolates, or displays a low-trust number. It either prompts a guided retake (up to `max_retakes = 3`, `G-25`), offers an alternative modality (e.g., finger PPG or paced breathing), or hides the specific marker while preserving valid sibling markers.
2. **Prototype Bug Prevention (`Spec §3 Note`):** The Oct 17 prototype reported `confidence 0.99 "GOOD"` on a scan with `pulse_snr_db = 2.4 dB`. Under `ALG-PUL-09` and rule `BR-QUA-01` (`T16`), any scan with `pulse_snr_db < 3.0 dB` **must** be rejected with `"retake"` and **must never** trigger clinical risk flags.
3. **Partial Degradation over Total Failure:** When a dicrotic notch is not found (`ALG-WAV`), only notch-dependent markers are hidden; when 1 of 4 dental views fails (`ALG-DEN-01`), the exam is marked `"partial"` and explicitly lists unseen FDI teeth rather than discarding the entire exam.

---

## 2. Real-Time Capture Failure & Coaching Catalogue (`ALG-CAP` & `ALG-PUL-06`) `[DOC]`

Per Spec §2, all capture checks run on the phone in real time. A video capture is accepted only when every applicable check passes for the full recording (`>= 80%` of frames for `ALG-PUL`, first 3 s discarded), and a photo capture requires **2 seconds of continuous valid framing** before shutter release.

| Error Code | Spec ID | Check Name | Trigger Condition (Default Threshold) | Exact User / Coaching Message (`[DOC]`) | Timer & Capture Behaviour |
|---|---|---|---|---|---|
| `E-CAP-001` | `ALG-CAP-01` | Face found & posed | `face_size_px < 200` OR `\|yaw_deg\| > 15°` OR `\|pitch_deg\| > 15°` | **"Move closer / face the camera"** | Pause 2-s photo lock; during video, mark frame invalid & show live pose guide; fail if `< 80%` valid frames |
| `E-CAP-002` | `ALG-CAP-02` | ROI segmentation | Individual ROI `< 400 px` (after 3-px erosion from eyes/brows/lips); `< 4` usable ROIs remain | **"Move closer / face the camera"** *(drops ROI < 400 px; fails capture if < 4 ROIs)* | Drop affected ROI dynamically; abort & restart capture if usable ROIs `< 4` |
| `E-CAP-003L` | `ALG-CAP-03` | Light level (low) | 1-s mean `illuminance_luma < 60` (maps to `< 50 lux`) | **"Move to brighter place"** | Pause countdown / block shutter until luma enters `60–220` |
| `E-CAP-003H` | `ALG-CAP-03` | Light level (high) | 1-s mean `illuminance_luma > 220` | **"Avoid direct light"** | Pause countdown / block shutter until glare/direct light resolved |
| `E-CAP-004` | `ALG-CAP-04` | Motion | `motion_px_s > 3` px/s OR `motion_high_pct > 20%` of frames | **"Hold still"** | **Reset video timer and restart recording** (`"Hold still" and restart`) |
| `E-CAP-005` | `ALG-CAP-05` | Skin validity | `skin_valid_pct < 80%` in YCbCr (`Cb 77–127`, `Cr 133–173`) | **"Remove mask / hair from forehead"** | Block capture start / pause framing lock until skin ROI unobstructed |
| `E-CAP-006` | `ALG-CAP-06` | Blur | Variance of Laplacian `blur_score < 100` (device-calibrated) | **"Autofocus tap + retake"** | Trigger camera autofocus tap on target ROI and prompt immediate retake (`max 3`) |
| `E-CAP-007` | `ALG-CAP-07` | Glare / exposure | `glare_pct > 5%` (`luma >= 250`) OR `dark_pct > 10%` (`luma <= 15`) | **"Tilt phone / more light"** | Block photo acceptance; guide user to tilt phone angle or add ambient light |
| `E-CAP-008` | `ALG-CAP-08` | Image-quality classifier | MobileNetV3-small `iq_score < 0.7` | **Retake with `iq_reason`** *(e.g. out of focus, motion blur, poor framing)* | Increment `retake_count`; guide retake on `S-E03`/`S-E04` (if `retake_count == 3` → mark `"not assessed"`) |
| `E-CAP-009` | `ALG-CAP-09` | Body-part detection | Segmentation / MediaPipe mask coverage `< 80%` of expected region | **"Show the whole [part]"** *(e.g., lower eyelid, sole, mouth, hand)* | Hold shutter until body-part mask coverage `>= 80%` for 2 continuous seconds |
| `E-CAP-010` | `ALG-CAP-10` | Colour card | `card_found == false` OR post-correction `colour_error_de (ΔE) > 5` | **Card optional unless screen requires (newborn `ALG-IMG-07` mandatory)** | On newborn jaundice (`ALG-IMG-07`): block `"normal"` output & require card in frame with `ΔE <= 5`; on other image screens: log warning & proceed uncalibrated if card absent |
| `E-CAP-011` | `ALG-CAP-11` | Microphone self-check | 100 Hz–8 kHz sweep `mic_response_dev_db > 6 dB` OR `audio_processing_detected == true` | **Show fix (uncover mic / disable OS noise suppression); block audio tasks** | Hard gate (`G-17`) on `S-G01`: block all §8 audio screenings until check passes |
| `E-CAP-012` | `ALG-CAP-12` | Room noise | 3-s silence A-weighted `noise_dba > 45 dBA` | **Block audio tasks ("Move to a quieter room ≤ 45 dBA")** | Hard gate (`G-18`) on `S-G01`: prevent starting cough, voice, spirometry, or hearing tasks |
| `E-CAP-013` | `ALG-CAP-13` | Clipping & audio SNR | `clip_pct > 1%` (`>= 0.99` FS) OR `audio_snr_db < 15 dB` | **"Move phone further / quieter room"** | Reject recorded audio task clip; prompt immediate re-record |
| `E-CAP-014` | `ALG-CAP-14` | Audio–video sync | 1 kHz beep + white flash `sync_found == false` | **"Re-record"** | Discard desynchronised video/audio clip and restart task |
| `E-CAP-015` | `ALG-CAP-15` | Face distance | Iris-based `face_distance_cm` outside `40 ± 5 cm` (`< 35` or `> 45` cm) | **"Move closer / further"** | Pause visual acuity (`ALG-MOV-10`) tumbling-E presentation until distance returns to `35–45 cm` (`G-33`) |
| `E-PUL-006P` | `ALG-PUL-06` | Finger PPG over-pressure | Rear-camera + torch `mean_red > 250` (channel saturation) | **"press lighter"** | Show live pressure gauge on `S-D04`; pause beat accumulation until red channel unsaturates |
| `E-PUL-006C` | `ALG-PUL-06` | Finger PPG lens uncovered | No pulsatile AC modulation detected in centre 50% ROI | **"cover lens fully"** | Pause timer on `S-D04`; coach user to cover both rear camera lens and flash/torch completely |

---

## 3. Signal Processing, Algorithm & Risk Failure Matrix (Spec §§3–10) `[DOC]`

| Error Code | Spec Section & ID | Failure / Precondition Breach | Exact System & UI Behaviour (`[DOC]`) | Fallback / Next Action Offered |
|---|---|---|---|---|
| `E-PUL-001` | §3 `ALG-PUL-01` | ROI colour traces: `< 4` ROIs have 10-s pulse `SNR >= 0 dB` | Fail capture (`usable_rois_count < 4`) | Route to Retake Guidance (`S-D06`, `G-25`) |
| `E-PUL-005` | §3 `ALG-PUL-05` | Neural pulse (`EfficientPhys` INT8 TFLite) fails or inference time `> 20 s` | **Use POS (`bvp_pos`) only and set audit flag `pos_used_fallback_only = true`** | Continue pipeline transparently without failing user scan |
| `E-PUL-007A` | §3 `ALG-PUL-07` | `\|hr_neural_bpm - hr_pos_bpm\| > 5 bpm` | Reject HR estimate → **"retake"** | Prompt retake (`max 3`); on 3rd failure offer **Finger Mode** (`S-D04`) |
| `E-PUL-007B` | §4.1 `ALG-PUL-07` | `\|hr_spec_bpm - hr_beat_bpm\| > 3 bpm` (spectral vs `60000 / median IBI`) | Disagreement → **"retake" (max 3) → offer finger mode** | Route to `S-D06`; after 3 face retakes, switch CTA to Finger Scan (`S-D04`) |
| `E-PUL-008` | §3 `ALG-PUL-08` | Total detected beats `< 20` (`beat_peaks_ms.length < 20`) | **All pulse readings hidden** (`is_hidden = true`) | Prompt retake or Finger Mode |
| `E-PUL-009A` | §3 `ALG-PUL-09`, §10 `T16` | Spectral `pulse_snr_db < 3.0 dB` | **Mark scan `"retake"`; fire `BR-QUA-01`; suppress all vital flags (`No flag; "retake"`)** | Route to `S-D06` retake flow |
| `E-PUL-009B` | §3 `ALG-PUL-09`, §4.3 | `clean_beat_count < 50` (beats with template Pearson $r \ge 0.8$) | **Show `"HRV not available"`** (`SDNN`, `RMSSD`, `PNN50`, `SD1`, `SD2`, `BAEVSKY_SI` hidden); keep `HR` and `RR` if valid | Suggest longer/stiller 60-s or 120-s scan if user wants HRV |
| `E-PUL-010` | §3 `ALG-PUL-10` | Valid IBIs `< 50%` of total beats (after `300–2000 ms` & `> 20%` step rejection) | **HRV hidden** (`is_hidden = true`, `hidden_reason = "valid_ibi_below_50pct"`) | Keep spectral `HR` if `SNR >= 3 dB`; hide HRV & stress |
| `E-VIT-001` | §4.2 `ALG-RSP-01` | `< 32 s` clean recording, OR `< 2` respiratory series have peak power `>= 20%`, OR remaining series `RR_SPREAD > 4 br/min` | **Show `"RR not available"`** | **Offer Paced-Breathing Retake (`S-D13`)** |
| `E-VIT-002` | §4.3 `ALG-HRV-03` | Recording duration `< 120 s` (`< 2 min`) | Time-domain HRV (`SDNN`, `RMSSD`, `pNN50`) shown if `>= 50` clean beats; **Frequency-domain (`LF`, `HF`, `LF_HF`) hidden** | Offer 2-minute extended scan mode for frequency-domain HRV |
| `E-VIT-003` | §4.3 `ALG-HRV-01` | Age-band reference table in `mst_reference_range` has `cohort_status == "pending_cohort"` | Display numeric `SDNN` / `RMSSD` value with label **"Reference range not yet available"** (pNN50 `> 3%` normal still shown) | Never invent or guess an HRV normal range (Medical Safety Rule) |
| `E-VIT-004` | §4.4 `ALG-HRV-04` | Baevsky `MxDMn < 20 ms` (`< 0.02 s`, very rigid rhythm) | **Report `BAEVSKY_SI` with low confidence warning** | Flag low confidence in `MarkerResult` |
| `E-VIT-005` | §4.5 `ALG-SPO-01` | Face mode used, OR finger `PI < 0.4%`, OR phone model has no calibrated `(A, B)` coefficients in `mst_device_model` | **SpO2 band not shown** (generic `A=110, B=25` is research-only, never displayed to user) | **Recommend medical pulse oximeter or Smart Ring (`S-I02`)** |
| `E-VIT-006` | §4.6 `ALG-BP-01` | `BP_CONFIDENCE < 0.6`, OR `< 40` clean beats, OR face `SNR < 6 dB`, OR missing age/sex/height/weight | **Show `"BP not available, use cuff"`** | Prompt user to measure with validated arm cuff (`S-D10`) |
| `E-VIT-007` | §4.7 `ALG-RHY-01` | Recording `< 30 s` OR `< 70%` valid beats | **Show `"rhythm not assessed"`** | If 1st scan was `irregular`, schedule confirmation scan (`G-27`: needs 2 scans or 1 scan + ring) |
| `E-VIT-008` | §4.8 `ALG-WAV-01`..`05` | Dicrotic notch (2nd-derivative zero crossing after systolic peak) not found | **Notch-based markers hidden** (`NOTCH_TIME`, `NOTCH_REL_H`, `RI`, `AIX`, `AREA_RATIO`); **all other waveform & SDPPG markers (`a–e`, `AGING_INDEX`, `VASC_AGE`) kept** | Prefer 60 fps finger PPG for high-fidelity notch detection |
| `E-VIT-009` | §4.9 `ALG-DM-01` | Missing `waist_cm` OR missing `bmi` (height/weight) in `HealthProfile` | **Diabetes risk band not shown** (`is_hidden = true`, `hidden_reason = "missing_waist_or_bmi"`) | Deep-link to `S-B04` Health Context to enter waist circumference |
| `E-VIT-010` | §5 `ALG-FRM-01`..`15` | Any formula input is missing, `is_hidden == true`, or below its quality threshold (`G-29`) | **Formula never runs** (output omitted/hidden; zero divide or partial calc impossible) | Show which prerequisite input (e.g., `SBP` or `waist_cm`) is needed |
| `E-IMG-001` | §6 Intro `ALG-IMG-01`..`08` | Unusable image after **3 guided retakes** (`retake_count >= 3`, `G-25`) | **Mark screen `"not assessed"`** | Save session as `"not assessed"`; advise clinic visit if symptomatic |
| `E-IMG-002` | §6 Intro `IMG-10` | Model probability within `±0.10` of threshold OR `band == "high"` / `"suspicious"` / `"ulcer"` | **Route to Specialist Review (`IMG-10`)**; display badge `"Pending specialist review"` on `S-R01`/`S-R05` | Notify member when specialist adjudication completes |
| `E-IMG-003` | §6.7 `ALG-IMG-07` | Newborn jaundice scan taken without physical 24-patch colour card (`card_found == false` or `ΔE > 5`) | **Never shows `"normal"` without colour card** | Require colour card setup (`S-E02`) or refer directly for serum/TcB bilirubin |
| `E-DEN-001` | §7.1 `ALG-DEN-01`..`03` | 1 to 3 of the 4 dental views (`front_closed`, `front_open`, `upper_occlusal`, `lower_occlusal`) missing or failed quality after retakes | **Mark dental exam `"partial"` (`is_partial = true`); report explicitly lists which FDI teeth were not seen** | Allow user to retake only the missing view(s) |
| `E-AUD-001` | §8 `ALG-AUD-01`, `AUD-03` | `COUGH_COUNT_VALID < 3` (fewer than 3 valid cough events with `prob >= 0.5` and duration `150–800 ms`) | Cannot run `ALG-AUD-03` TB classifier | Prompt user on `S-G03` to record additional voluntary coughs |
| `E-AUD-002` | §8 `ALG-AUD-05` | Forced exhale repeatability check: top 2 of 3 efforts differ by `> 10%` | Flag low repeatability; prompt 4th coaching trial | Coach arm's-length (`~30 cm`) maximal deep breath + forceful blow |
| `E-AUD-003` | §8 `ALG-AUD-08` | Overnight sleep recording `< 4.0` valid hours (`VALID_SLEEP_H < 4`) | **OSA / AHI band not computed** (`"Insufficient sleep duration (< 4 h)"`) | Advise keeping phone plugged in on bedside table `0.3–1 m` from chest overnight (`G-30`) |
| `E-AUD-004` | §8 `ALG-AUD-09` | Earphones unplugged during hearing test (`G-19`) | Pause adaptive staircase immediately | Prompt user to reconnect earphones before resuming |
| `E-AUD-005` | §8 `ALG-AUD-11` | `PHQ-9 item 9 > 0` (thoughts of self-harm) OR voice model AUC gain `< 0.03` | **If `PHQ-9 item 9 > 0`: immediately trigger Crisis Support screen (`S-G14`, `G-37`)**. If voice model unvalidated: use questionnaire score only | Show 24/7 crisis helplines and notify clinician pathway lead |
| `E-AUD-006` | §8 `ALG-AUD-12` | Enrolled HF patient has `< 14 days` of daily baseline recordings (`G-28`) | Show `"Building personal baseline (Day X of 14)"`; suppress `HF_ALERT` until 14-day baseline established | Send daily morning reminder (`F-35`) |
| `E-MOV-001` | §9 `ALG-MOV-12` | Reaction time tap `< 100 ms` after stimulus onset | **Discard trial as anticipatory false-start** (`discard < 100 ms`) | Re-queue stimulus with new random `1–4 s` gap |
| `E-RSK-001` | §10 `ALG-RSK-05` | Missing `BP_BAND`, `DM_BAND`, `waist_cm`, or medical history | **Hide `ckd_risk` and `mets_risk` organ scores** | Show checklist of missing inputs required to unlock organ risk |
| `E-RSK-002` | §10 `ALG-RSK-06` | Composite `result_confidence < 0.6` (`capture_quality * model_conf * context_factor < 0.6`, where `context_factor = 0.8` if caffeine/smoke/exercise in last 30m) | **Result hidden (`is_hidden = true`)** (`G-23`) | Advise resting 30 minutes after exercise/caffeine/smoking and rescanning |

---

## 4. Input Field & Form Validation Rules `[DOC]` `[DER]`

### 4.1 Profile & Anthropometrics (`S-B03`, `S-B04`, `S-B06`)
| Field | Validation Rule | Error Message |
|---|---|---|
| `date_of_birth` | Not in future; age `0 days` to `120 years`. If age `< 28 days`, require `birth_timestamp_utc` (hour precision) for `ALG-IMG-07`. | *"Please enter a valid date of birth (include birth time for newborns under 28 days)."* |
| `height_cm` | Numeric, `30.0 <= height_cm <= 250.0` (1 decimal). Cross-check with age (`< 100 cm` warning for adults). | *"Height must be between 30 cm and 250 cm."* |
| `weight_kg` | Numeric, `1.0 <= weight_kg <= 300.0` (1 decimal). Computed `bmi` must fall in valid range `10.0–70.0 kg/m²` (`ALG-FRM-09`). | *"Weight must be between 1 kg and 300 kg (resulting BMI 10–70 kg/m²)."* |
| `waist_cm` | Optional for basic profile (`G-02`), required for `G-03` (`ALG-DM-01`, `ALG-FRM-10`, `ALG-RSK-05`). Valid `30.0 <= waist_cm <= 200.0` and `0.300 <= waist_cm / height_cm <= 1.000` (`ALG-FRM-10`). | *"Waist circumference must be between 30 cm and 200 cm (WHtR 0.3–1.0)."* |
| `gestation_weeks` | Required when `is_pregnant == true` or for newborn jaundice (`ALG-IMG-07`). Integer `4–42` weeks (`22–42` weeks at birth for newborns). | *"Please enter gestation between 4 and 42 weeks."* |
| `education_years` | Required before Cognitive Speech (`ALG-AUD-10`, age $\ge 50$). Integer `0–30`. | *"Please enter years of formal education (0–30) for accurate speech scoring."* |

### 4.2 BP Personal Cuff Calibration (`S-D10`, `F-14`, `ALG-BP-01`, §14)
- **Two-Reading Requirement:** Per Spec §14 (`Validated cuff, mean of 2 readings, <= 10 min`), the calibration form requires **2 consecutive cuff readings** (`SBP_1/DBP_1`, `SBP_2/DBP_2`).
- **Bounds:** `60 <= SBP <= 260 mmHg`, `30 <= DBP <= 160 mmHg`, and `PP = SBP - DBP >= 10 mmHg` and `<= 120 mmHg` (`ALG-FRM-02`).
- **Consistency Check:** If `|SBP_1 - SBP_2| > 15 mmHg` or `|DBP_1 - DBP_2| > 10 mmHg`, prompt a 3rd reading.
- **Pairing Window:** Must be entered within **10 minutes** of a clean Vitals scan (`G-26`, §14) with confirmation that the user did not talk or move between readings. Expires automatically after **30 days** (`ALG-BP-01`).

### 4.3 Confirmatory Lab / Reference Result Entry (`S-R06`, `F-32`, Spec §13 & §14)
- Validates `collected_at` timestamp (cannot be in the future).
- Enforces physiological bounds per test code (e.g., `HbA1c`: `3.0–20.0%`; `Hb`: `2.0–25.0 g/dL`; `Total Bilirubin`: `0.1–40.0 mg/dL`; `SpO2`: `50–100%`).
- Requires explicit boolean answers to the marker-specific **§14 Exclusions Checklist** (e.g., for `HbA1c`: pregnancy, transfusion in last 3 months, haemoglobin variant, new DM therapy between scan and test). If any exclusion is `true` or `|collected_at - scan_at| > max_gap`, the record is saved with `PairingGrade.gradeD` (`monitoring_only`).

---

## 5. Sealed `AppFailure` Hierarchy & Error Code Registry `[DER]`

```dart
sealed class AppFailure {
  final String code;
  final String userMessageKey;
  final String? technicalDetail;
  final bool isRetryable;

  const AppFailure({
    required this.code,
    required this.userMessageKey,
    this.technicalDetail,
    this.isRetryable = true,
  });
}

/// Real-time capture check failure (ALG-CAP-01..15, ALG-PUL-06)
final class CaptureQualityFailure extends AppFailure {
  final String checkId; // e.g. 'ALG-CAP-03'
  final double measuredValue;
  final bool resetsRecordingTimer;

  const CaptureQualityFailure({
    required super.code,
    required this.checkId,
    required this.measuredValue,
    required super.userMessageKey,
    this.resetsRecordingTimer = false,
  });
}

/// Signal / beat / agreement failure in pulse or vital algorithms (Sec 3-5)
final class SignalQualityFailure extends AppFailure {
  final int currentRetakeCount;
  final int maxRetakes; // default 3 (G-25)
  final String? alternativeModalityRoute; // e.g. '/vitals/finger' or '/vitals/paced-breathing'

  const SignalQualityFailure({
    required super.code,
    required super.userMessageKey,
    required this.currentRetakeCount,
    this.maxRetakes = 3,
    this.alternativeModalityRoute,
  });

  bool get canRetakeSameMode => currentRetakeCount < maxRetakes;
}

/// Marker-level suppression (confidence < 0.6, missing notch, uncalibrated device)
final class MarkerSuppressedFailure extends AppFailure {
  final String markerCode;
  final String suppressionReason;

  const MarkerSuppressedFailure({
    required super.code,
    required this.markerCode,
    required this.suppressionReason,
    required super.userMessageKey,
  }) : super(isRetryable: false);
}

/// Prerequisite gate failure (G-01..G-37: consent, profile, permissions, device)
final class GateBlockedFailure extends AppFailure {
  final String gateId; // e.g. 'G-05', 'G-17', 'G-18'
  final String resolutionRoute;

  const GateBlockedFailure({
    required super.code,
    required this.gateId,
    required this.resolutionRoute,
    required super.userMessageKey,
  });
}

/// Network / Offline / Partner hardware failure (G-31, G-32, G-36)
final class IntegrationFailure extends AppFailure {
  final bool queuedInOfflineOutbox;

  const IntegrationFailure({
    required super.code,
    required super.userMessageKey,
    this.queuedInOfflineOutbox = false,
    super.technicalDetail,
  });
}
```

### 5.1 Prefix Namespace Registry
- `E-CAP-001`…`015`: Real-time capture checks (`ALG-CAP-01`…`15`)
- `E-PUL-001`…`010`: Pulse extraction, finger PPG pressure/coverage, SNR, IBI cleaning (`ALG-PUL-01`…`10`)
- `E-VIT-001`…`010`: Vital-sign card preconditions, agreement, device coefficients, and §5 formulas
- `E-IMG-001`…`003`: Image screening 3-retake exhaustion, `IMG-10` review escalation, newborn colour card mandate
- `E-DEN-001`…`002`: Dental partial view handling and guardian consent blocks
- `E-AUD-001`…`006`: Cough count, spirometry repeatability, sleep `< 4 h`, earphone disconnect, crisis override, HF 14-day baseline
- `E-MOV-001`…`003`: Reaction time anticipatory tap discard (`< 100 ms`), sensor unavailability (`G-13`), vision distance (`G-33`)
- `E-RSK-001`…`002`: Organ score input completeness (`ALG-RSK-05`), confidence suppression (`< 0.6`, `ALG-RSK-06`)
- `E-PERM-001`…`005`: Runtime OS permissions (`G-11` Camera, `G-12` Mic, `G-13` Motion Sensors, `G-14` Notifications, `G-15` BLE)
- `E-NET-001`…`004`: Offline queue deferred sync, master-data checksum mismatch, partner adapter timeout

---

## 6. PHI-Safe Logging & Telemetry Redaction Rules `[STD]` `[DER]`

1. **Never Log Raw Biometrics or PII:** Application logs, crash reports (Sentry/Crashlytics), and analytics events **must never** contain member names, phone numbers, dates of birth, raw face/eye/oral/dental photos, raw audio recordings, or exact GPS coordinates.
2. **Permitted Diagnostic Telemetry:** Logs may include `session_id` (UUID), `check_id` (`ALG-CAP-*`), aggregate quality scores (`pulse_snr_db`, `illuminance_luma`, `noise_dba`, `blur_score`), `device_model_code`, `master_bundle_version`, inference latency in milliseconds, and `AppFailure.code`.
3. **Training Data Isolation (`G-06`, Spec §11.2):** Raw media and signal traces are flagged `eligible_for_model_training = true` on the backend **only** when an active, unrevoked `CONSENT_TRAINING_DATA` record exists for `subject_id`. If `CONSENT_TRAINING_DATA` is revoked (`S-I04`), all training-tagged copies are purged from the ML feature store while preserving the member's clinical screening history unless account deletion is requested.
