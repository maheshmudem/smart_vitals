# 02 — Application Requirements (Functional & Non-Functional)

> **Scope.** What the VitalsMirror Flutter app must do. Requirements are numbered `FR-xxx` (functional) and `NFR-xxx` (non-functional), grouped by feature `F-xx` from [00_README_Index.md](00_README_Index.md).
> Every requirement carries a provenance tag (**[DOC] / [DER] / [STD] / [OPEN] / [MOCK]**) and a Spec reference ("the Spec" = *VitalsMirror — Algorithm Specifications & Test Cards*, Oct 18 2026).
> Unknowns are marked **[OPEN]** — see `16_Open_Questions_and_Assumptions.md` (temporary IDs `OQ-REQ-nn` are listed at the end of this document).

> [!IMPORTANT]
> **Medical-safety rule (applies to every FR).** The app must never invent a threshold, formula, band or output. All numeric limits below are copied from the Spec and must be loaded from master tables (`mst_algorithm`, `mst_quality_threshold`, `mst_reference_range`, `mst_device_model`, …) rather than hard-coded, because the Spec states they are *"starting points … changeable only through change control"* (Spec §1). Every output is a **screening band**, never a diagnosis, and always comes with a recommended confirmatory test (Spec §13).

---

## 1. Conventions

| Item | Rule |
|---|---|
| "shall" | Mandatory |
| "should" | Recommended; deviation needs justification |
| Master-driven value | Written as `value (mst_x)` — default from the Spec, live value from master data |
| Hidden | Marker computed (possibly) but **not shown** to the user; status `hidden` in the result envelope (see 10/11) |
| Not available | Pre-condition failed, nothing computed; status `notAvailable` |
| Not assessed | Capture failed after max retakes; status `notAssessed` |

---

## 2. Functional requirements

### F-01 Authentication & Session — [STD]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-001 | The app shall let a user sign in with a mobile number and a one-time password (OTP). | STD/OPEN | — (FRS not provided) |
| FR-002 | The app shall keep an authenticated session (access + refresh token) in secure storage and refresh it silently. | STD | — |
| FR-003 | The app shall sign the user out and wipe cached PHI on explicit sign-out. | STD | — |
| FR-004 | Gate **G-01** (authenticated session) shall be required before any profile, consent, capture or result screen. | STD | — |
| FR-005 | Authentication method for Operators (shared device, organisation login, PIN) is undefined. | OPEN | OQ-REQ-01 |

### F-02 Language & Localisation — [DER]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-010 | The app shall support Telugu, Hindi and English for all UI text, voice prompts and instructions. | DER | §8 AUD-10 (speech recognition te/hi/en) |
| FR-011 | Language shall be selectable on first launch (S-A02) and changeable in Settings (S-I03). | DER | — |
| FR-012 | Speech-based tasks (AUD-10 cognitive, MOV-08 stroke speech, AUD-12 HF sentence) shall use the selected language for prompts and recognition. | DOC/DER | §8 AUD-10, §9 MOV-08 |
| FR-013 | Movement tests shall be paced by voice + metronome in the selected language. | DOC | §9 intro |
| FR-014 | Languages beyond te/hi/en and per-language validation of speech models are undefined. | OPEN | OQ-REQ-02 |

### F-03 Consent Management — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-020 | Screening consent (**G-04**) shall be captured before any image screen, and before any capture generally. | DOC | §6 intro ("screening consent") |
| FR-021 | Dental consent (**G-05**) shall be captured before dental capture; for children it shall be given by a guardian. | DOC | §7.1 Preconditions |
| FR-022 | Training-data consent (**G-06**) shall be captured separately and be **non-blocking**; only training-consented records may be used for model building. | DOC | §11.2 footer |
| FR-023 | Mood screening shall only be available inside an active clinician pathway (**G-07**). | DOC | §8 AUD-11 |
| FR-024 | Heart-failure voice monitoring shall only be available to enrolled HF patients (**G-08**). | DOC | §8 AUD-12 |
| FR-025 | Every consent record shall store type, version, subject, signer (self/guardian/operator-witnessed), timestamp, language and withdrawal state. | DER | — |
| FR-026 | Users shall be able to view and withdraw consents (S-I04); withdrawal shall immediately close the gated features. | DER | — |
| FR-027 | Consent text/legal wording and versions come from the FRS / legal team. | OPEN | OQ-REQ-03 |

### F-04 Member Profile & Health Context — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-030 | Basic profile (**G-02**): date of birth (age), sex, height (cm), weight (kg) shall be required before vitals results that use them. | DOC | §4.6 Preconditions; §5 |
| FR-031 | Extended profile (**G-03**): waist (cm), family history (diabetes), physical activity, pregnancy status (+ gestation) shall be collected. | DOC | §4.9 Inputs; §6.1; §10 RSK-05 |
| FR-032 | Tobacco / areca history shall be collected (drives oral-lesion offer). | DOC | §6.4 |
| FR-033 | Diabetes status shall be collected (drives diabetic-foot offer). | DOC | §6.5 |
| FR-034 | Education level shall be collected for the cognitive speech screen. | DOC | §8 AUD-10 |
| FR-035 | Context in the last 30 min (caffeine, smoking, exercise) shall be asked before each vitals scan; if any is "yes", the confidence context factor 0.8 is applied. | DOC | §10 RSK-06 |
| FR-036 | Profile field validation ranges shall be consistent with formula valid ranges (see 12_Error_Handling). | DER | §5 |
| FR-037 | Symptom capture (e.g. chest pain for T8) is required by risk rules but the symptom list is not defined. | OPEN | §10 T8; OQ-REQ-04 |

### F-05 Family / Dependents — [DER]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-040 | A guardian shall be able to add dependents (child 1–12, newborn 0–28 days, other). | DER | §6.6, §6.7, §7 |
| FR-041 | For newborns the app shall capture date **and time** of birth (age in hours) and gestation. | DOC | §6.7 Inputs |
| FR-042 | Child growth z-scores (HAZ/WAZ/BMIZ) shall be computed with FRM-12 from `mst_growth_reference`. | DOC | §5 FRM-12 |
| FR-043 | Dental child mode (1–12) shall change capture guidance and tooth chart only, not the models. | DOC | §7 intro |
| FR-044 | Age of majority / handover of a dependent to own account is undefined. | OPEN | OQ-REQ-05 |

### F-06 Operator (Field Worker) Mode — [DER/OPEN]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-050 | The app should support an operator capturing for many participants (schools, anganwadis, clinics). | DER | §7.1 test steps ("photographer parent vs operator"), §6.4 ("untrained photographers") |
| FR-051 | Every capture shall record the photographer type (self / parent / operator) for subgroup analysis. | DER | §7.1, §6.4, §11.2 |
| FR-052 | Operator participant search/registration, organisation/site model, and offline batch sync are undefined. | OPEN | OQ-REQ-06 |

### F-07 Device Capability & Calibration — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-060 | On first run and after OS update the app shall look up the phone in `mst_device_model` (**G-16**). | DOC | §4.5, CAP-11, CAP-15 |
| FR-061 | The device profile shall provide: SpO2 coefficients A, B; mic response profile; per-device noise offset; camera focal length; blur calibration. | DOC | §4.5, CAP-11, CAP-12, CAP-15, CAP-06 |
| FR-062 | If the device has no SpO2 coefficients, the SpO2 band shall not be shown and the user shall be advised to use an oximeter or ring. | DOC | §4.5 Failure handling |
| FR-063 | The app shall verify camera supports ≥ 30 fps (60 fps preferred) for pulse capture. | DOC | §4.8 Preconditions |
| FR-064 | Behaviour for devices absent from `mst_device_model` (block vs generic profile) is undefined. | OPEN | OQ-REQ-07 |

### F-08 Runtime Permissions — [DER]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-070 | Camera (**G-11**), microphone (**G-12**), motion sensors (**G-13**), notifications (**G-14**, non-blocking) and Bluetooth/nearby devices (**G-15**) shall be requested just-in-time with a primer (S-A07). | DER | §9 intro (sensor access) |
| FR-071 | A denied permission shall disable only the dependent tasks, with a path to system settings. | DER | — |

### F-09 Capture Quality Engine (ALG-CAP-01…15) — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-080 | All capture checks shall run **on the phone in real time**. | DOC | §2 intro |
| FR-081 | A capture shall be accepted only when every applicable check passes for the full recording (or 2 s of continuous framing for photos). | DOC | §2 intro |
| FR-082 | CAP-01 face: width ≥ 200 px, \|yaw\| ≤ 15°, \|pitch\| ≤ 15°; else "Move closer / face the camera". | DOC | §2 CAP-01 |
| FR-083 | CAP-02 ROI: 7 polygons, eroded 3 px from eyes/brows/lips; ROI < 400 px dropped; fail if < 4 ROIs. | DOC | §2 CAP-02 |
| FR-084 | CAP-03 light: mean luma (1-s window) 60–220; else "Move to brighter place" / "Avoid direct light". | DOC | §2 CAP-03 |
| FR-085 | CAP-04 motion: motion_px_s ≤ 3 and high-motion frames ≤ 20 %; else "Hold still" and restart. | DOC | §2 CAP-04 |
| FR-086 | CAP-05 skin validity: YCbCr Cb 77–127, Cr 133–173, ≥ 80 %; else "Remove mask / hair from forehead". | DOC | §2 CAP-05 |
| FR-087 | CAP-06 blur: variance of Laplacian ≥ 100 (calibrated per device); else autofocus tap + retake. | DOC | §2 CAP-06 |
| FR-088 | CAP-07 glare/exposure: glare (≥ 250 luma) ≤ 5 %, dark (≤ 15 luma) ≤ 10 %; else "Tilt phone / more light". | DOC | §2 CAP-07 |
| FR-089 | CAP-08 image-quality classifier (MobileNetV3-small 224×224): iq_score ≥ 0.7; else retake with reason. | DOC/MOCK | §2 CAP-08 |
| FR-090 | CAP-09 body part: coverage ≥ 80 % of expected region; else "Show the whole [part]". | DOC | §2 CAP-09 |
| FR-091 | CAP-10 colour card: card found and ΔE after correction ≤ 5; optional unless screen requires (newborn). | DOC | §2 CAP-10 |
| FR-092 | CAP-11 mic self-check: 1.5 s sweep 100 Hz–8 kHz; deviation ≤ 6 dB and no audio processing detected; else show fix and block audio tasks. | DOC | §2 CAP-11 |
| FR-093 | CAP-12 room noise: 3 s silence, A-weighted with per-device offset, ≤ 45 dBA; else block audio tasks. | DOC | §2 CAP-12 |
| FR-094 | CAP-13 clipping/SNR: clip ≤ 1 %, SNR ≥ 15 dB; else "Move phone further / quieter room". | DOC | §2 CAP-13 |
| FR-095 | CAP-14 AV sync: 1 kHz 100 ms beep + 100 ms white flash; sync_found = true; else re-record. | DOC | §2 CAP-14 |
| FR-096 | CAP-15 face distance from iris (11.7 mm) and focal length; vision tests require 40 ± 5 cm; else "Move closer / further". | DOC | §2 CAP-15 |
| FR-097 | Each check's raw output marker (e.g. `face_size_px`, `illuminance_luma`, `noise_dba`) shall be stored with the capture for audit. | DOC | §2 Output marker column |

### F-10 Vitals Scan — Face (rPPG) — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-100 | Face scan shall record 60 s of front-camera video at ≥ 30 fps (60 preferred). | DOC | §3 intro, §4.8 |
| FR-101 | Pulse pipeline preconditions: CAP-01…05 passed for ≥ 80 % of frames; first 3 s discarded. | DOC | §3 intro |
| FR-102 | PUL-01: per-ROI RGB means; ROI weight = normalised pulse SNR (10-s window); ROI SNR < 0 dB weight 0; < 4 usable ROIs → fail capture. | DOC | §3 PUL-01 |
| FR-103 | PUL-02: smoothness-priors detrend λ = 300; Butterworth band-pass order 4, 0.7–3.0 Hz, zero-phase. | DOC | §3 PUL-02 |
| FR-104 | PUL-03 POS (1.6 s window, overlap-add); PUL-04 CHROM used only when POS SNR < CHROM SNR. | DOC | §3 PUL-03/04 |
| FR-105 | PUL-05 neural pulse (EfficientPhys, 72×72, INT8 TFLite on phone); if the model fails or exceeds 20 s → POS only and flag. | DOC/MOCK | §3 PUL-05 |
| FR-106 | PUL-07 spectral HR (Welch 10-s Hann, 50 % overlap, nfft 4096, peak 0.75–3.0 Hz, parabolic interpolation, harmonic check); \|neural − POS\| > 5 bpm → retake. | DOC | §3 PUL-07 |
| FR-107 | PUL-08 beat detection (1 kHz spline, min distance 333 ms, prominence ≥ 0.3 × local range); < 20 beats → pulse readings hidden. | DOC | §3 PUL-08 |
| FR-108 | PUL-09 signal quality: pulse SNR < 3 dB → "retake"; HRV needs ≥ 50 clean beats (template r ≥ 0.8). | DOC | §3 PUL-09 |
| FR-109 | PUL-10 IBI cleaning: valid IBI 300–2000 ms; reject if > 20 % from previous valid; valid IBIs < 50 % → HRV hidden. | DOC | §3 PUL-10 |
| FR-110 | The app shall never show "GOOD" quality when pulse SNR < 3 dB (prototype defect, Spec §3 note). | DOC | §3 note |
| FR-111 | Retake loop: max 3 attempts (**G-25**), then offer finger mode. | DOC | §4.1 Failure handling |

### F-11 Vitals Scan — Finger (contact PPG + SpO2) — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-120 | Finger scan shall record 30–60 s of rear-camera video with torch on. | DOC | §3 intro, PUL-06 |
| FR-121 | PUL-06: ROI = centre 50 %, mean red, inverted, same filter as PUL-02. | DOC | §3 PUL-06 |
| FR-122 | Mean red > 250 → "press lighter"; no pulse → "cover lens fully". | DOC | §3 PUL-06 |
| FR-123 | SpO2 requires finger mode, PI ≥ 0.4 %, ≥ 20 clean beats; uses R, G, B channels. | DOC | §4.5 |
| FR-124 | Finger mode is preferred for waveform markers. | DOC | §4.8 Inputs |

### F-12 Vital-Sign Results — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-130 | **HR**: preconditions SNR ≥ 3 dB, ≥ 20 clean beats; beat HR = 60000 / median IBI; report mean(neural spectral, beat HR) if within 3 bpm else retake; valid 30–220, 0 decimals; bands normal 60–100, borderline 50–59 / 101–110, critical < 40 or > 130. | DOC | §4.1 |
| FR-131 | **RR**: ≥ 32 s clean; RIIV/RIAV/RIFV/motion at 4 Hz, 0.1–0.5 Hz; discard series < 20 % band power; spread ≤ 4 br/min → median; min 2 series; valid 4–60, 0 decimals; bands 12–20 normal, 21–24 borderline, critical > 24 or < 8; < 2 series → "RR not available" + offer paced-breathing retake. | DOC | §4.2 |
| FR-132 | **HRV**: ≥ 50 clean beats (time domain), ≥ 120 s (frequency domain); SDNN, RMSSD, SD1, SD2 (ms, 1 dp), pNN50 (%, 1 dp), SD1_SD2, LF, HF, LF_HF; age-band ranges *to be built* → show "Reference range not yet available"; pNN50 > 3 % normal; too few beats → "HRV not available". | DOC | §4.3 |
| FR-133 | **Stress (Baevsky)**: 50-ms bins, trim 2.5 % tails before MxDMn; SI 10–2000; bands 50–150 low, 151–500 moderate, > 500 high; MxDMn < 20 ms → low confidence. | DOC | §4.4 |
| FR-134 | **SpO2**: show **band only** (SPO2_EST is internal): ≥ 95 normal, 92–94 borderline, < 92 critical; generic A = 110, B = 25 is research only and never displayed. | DOC | §4.5 |
| FR-135 | **BP**: ≥ 40 clean beats; finger mode or face SNR ≥ 6 dB; age, sex, height, weight present; SBP/DBP internal; display BP_BAND (normal < 120/< 80, elevated 120–139/80–89, high ≥ 140/≥ 90) **band-only until validated**; confidence < 0.6 → "BP not available, use cuff". | DOC | §4.6 |
| FR-136 | **Rhythm**: ≥ 30 s with ≥ 70 % valid beats; IRREG_BAND regular/irregular; positive only if ≥ threshold on 2 scans or 1 scan + ring overnight flag (**G-27**); insufficient beats → "rhythm not assessed". | DOC | §4.7 |
| FR-137 | **Waveform/vascular age**: ≥ 40 clean beats, ≥ 30 fps; notch not found → notch markers hidden, others kept; VASC_AGE_GAP ≤ 5 y normal; other age-band tables *to be built*. | DOC | §4.8 |
| FR-138 | **Diabetes risk**: vitals passed quality + profile complete; DM_BAND low / prediabetes risk / diabetes risk; missing waist or BMI → band not shown; always recommend HbA1c when not low; high → trigger eye, foot, dental follow-ups. | DOC | §4.9 |
| FR-139 | Trained-model outputs (SpO2, BP, rhythm, diabetes) shall be displayed only when their release status permits (**G-24**, F-38). | DOC | §4 intro |
| FR-140 | Each marker shall be shown with unit, configured decimals, band, confidence and version info (Marker detail S-D08). | DOC/DER | §1 Output markers |

### F-13 Derived Formulas (ALG-FRM-01…15) — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-150 | A formula shall **never run** if any input is missing, hidden or below its quality threshold (**G-29**). | DOC | §5 intro |
| FR-151 | Each formula shall reproduce its Spec test vector exactly (to the stated decimals). | DOC | §5 table |
| FR-152 | FRM-01 MAP (1 dp, 40–180), FRM-02 PP (0 dp, 10–120), FRM-03 shock index (2 dp, 0.2–3), FRM-04 RPP (0 dp, 3000–40000), FRM-05 CR ratio (2 dp, 1–20). Since SBP/DBP are internal while BP is band-only, BP-derived formulas shall follow BP release status. | DOC/OPEN | §5; OQ-REQ-08 |
| FR-153 | FRM-06 HRmax (Tanaka), FRM-07 HRR (Karvonen), FRM-08 VO2max (Uth, labelled "estimate"). | DOC | §5 |
| FR-154 | FRM-09 BMI (2 dp, 10–70), FRM-10 WHtR (3 dp, 0.3–1.0), FRM-11 body fat (Deurenberg, 2 dp, 3–60, labelled "estimate", adults only). | DOC | §5 |
| FR-155 | FRM-12 WHO z (2 dp, −6–6) from `mst_growth_reference`; FRM-13 GLI-2012 predicted/LLN. | DOC | §5 |
| FR-156 | FRM-14 orthostatic rise (0 dp, flag ≥ 30); FRM-15 HR recovery (0 dp, normal ≥ 12). | DOC | §5 |

### F-14 BP Personal Cuff Calibration — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-160 | The user may enter a cuff reading paired with a scan; an offset is applied to subsequent BP estimates for 30 days (**G-26**). | DOC | §4.6 Steps 3, Default parameters |
| FR-161 | After 30 days the offset expires and the user is prompted to recalibrate. | DOC/DER | §4.6 |
| FR-162 | Number of cuff readings and pairing window for calibration (§14 suggests mean of 2 readings, ≤ 10 min) to be confirmed. | OPEN | §14 BP row; OQ-REQ-09 |

### F-15 Functional Cardio Tests — [DOC/DER]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-170 | Orthostatic test: lying HR (last 30 s mean) then standing HR max over 0–3 min → FRM-14. | DOC | §5 FRM-14 |
| FR-171 | HR recovery test: HR at end of exercise and 60 s later → FRM-15. | DOC | §5 FRM-15 |
| FR-172 | Paced-breathing retake offered when RR not available. | DOC | §4.2 |
| FR-173 | Exercise protocol, pacing rate and capture method (continuous scan vs repeated scans) are undefined. | OPEN | OQ-REQ-10 |

### F-16 Image Screens — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-180 | Shared preconditions: screening consent, CAP-06/07/08/09 passed, colour card where required. | DOC | §6 intro |
| FR-181 | Unusable image → guided retake (max 3) → mark "not assessed". | DOC | §6 intro |
| FR-182 | High or uncertain result (probability within ± 0.1 of threshold) → specialist review (IMG-10, F-31). | DOC | §6 intro |
| FR-183 | Anaemia: 2 photos per eye, lid pulled down, flash on, card preferred; uses age, sex, pregnancy; HB_EST internal; ANAEMIA_BAND by WHO thresholds. | DOC | §6.1 |
| FR-184 | Adult jaundice: eye photos looking up, flash on, colour card. | DOC | §6.2 |
| FR-185 | Cataract: front-of-eye photo each eye with flash; offered to age ≥ 40 or on request. | DOC | §6.3 |
| FR-186 | Oral lesion: views incl. both cheeks, tongue sides, floor of mouth, palate; tobacco users always offered; classes not suspicious / suspicious / high risk with heat-map. | DOC | §6.4 |
| FR-187 | Diabetic foot: both soles, heels, between toes, card for size; offered to members with diabetes or high diabetes risk; monthly (**G-34**). | DOC | §6.5 |
| FR-188 | Child eye: flash photo, dim room, child looking at phone light at 0.5–1 m, age 1–12; white pupil always urgent. | DOC | §6.6 |
| FR-189 | Newborn jaundice: forehead/chest skin with **mandatory** card; age in hours; gestation; never show "normal" without card. | DOC | §6.7 |
| FR-190 | Skin: close-up with distance guide; thresholds "set after pilot". | DOC/OPEN | §6.8 IMG-08; OQ-REQ-11 |

### F-17 Fundus Partner Integration — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-195 | Clip-on fundus camera → partner AI → adapter → DR_REFERABLE, DR_GRADE, GLAUCOMA_SUSPECT. | DOC | §6.8 IMG-09 |
| FR-196 | Partner device model, connection (BLE/Wi-Fi/USB) and API are undefined. | OPEN | OQ-REQ-12 |

### F-18 Dental Screening — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-200 | Dental exam requires dental consent (guardian for children) and 4 views: front closed, front open, upper biting surfaces, lower biting surfaces, each passing blur/glare/coverage. | DOC | §7.1 |
| FR-201 | Teeth numbered in FDI: primary 51–85 under 6 y; mixed 6–12 y; permanent 11–48. | DOC | §7.1 Step 3 |
| FR-202 | Per-tooth findings: white spot, enamel break, cavity, broken/black, abscess sign; duplicates merged keeping highest severity; detection confidence ≥ 0.5; max 1 finding per class per tooth surface. | DOC | §7.1 |
| FR-203 | Missing view → exam "partial" and report states which teeth were not seen. | DOC | §7.1 Failure |
| FR-204 | Gum inflammation & plaque bands per sextant (DEN-04); sealant need on FDI 16/26/36/46 for ages 6–9 (DEN-05). | DOC | §7.2 |
| FR-205 | Caries risk via rule BR-DEN (FRS 12.4) on findings + Q_CARIES_RISK; must pass all 6 Spec vectors. | DOC/OPEN | §7.2, §7.3; OQ-REQ-13 |
| FR-206 | Change vs previous exam matched by FDI (new / progressed). | DOC | §7.2 DEN-07 |
| FR-207 | Child mode (1–12) changes capture guidance and chart only. | DOC | §7 intro |

### F-19 Audio Readiness — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-210 | Every audio task shall be preceded by CAP-11 (mic), CAP-12 (≤ 45 dBA) and monitored by CAP-13 (clip ≤ 1 %, SNR ≥ 15 dB). | DOC | §8 intro |
| FR-211 | Audio shall be recorded at 44.1–48 kHz, mono, with OS audio processing (AGC, noise suppression, echo cancellation) off; down-sampled to 16 kHz for models unless stated. | DOC | §8 intro |
| FR-212 | Video+audio tasks shall run CAP-14 AV sync. | DOC | §2 CAP-14 |

### F-20 Respiratory & Voice Audio — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-220 | Cough task: detect valid coughs (prob ≥ 0.5, 150–800 ms); ≥ 3 valid required. | DOC | §8 AUD-01 |
| FR-221 | TB risk from ≥ 3 valid coughs + Q_TB_SYMPTOMS (on-device/server classifier or partner API). | DOC | §8 AUD-03 |
| FR-222 | Obstruction: coughs, "aaa", "sss/zzz", sentence, breath sounds, exhale + Q_MMRC, Q_EXPOSURE. | DOC | §8 AUD-04 |
| FR-223 | Lung function: 3 forced exhales at arm's length (~30 cm); best of 3; repeatability within 10 %; uses height, age, sex. | DOC | §8 AUD-05 |
| FR-224 | Voice features: "aaa" ≥ 3 s, "sss", "zzz", sentence; middle 3 s analysed. | DOC | §8 AUD-06 |
| FR-225 | Questionnaire item content (Q_TB_SYMPTOMS, Q_MMRC, Q_EXPOSURE) is not in the Spec. | OPEN | OQ-REQ-14 |

### F-21 Sleep Monitoring — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-230 | Sleep sonar requires phone on bedside table, charging, 0.3–1 m from chest (**G-30**); 18–20 kHz chirps; RR per 30-s epoch. | DOC | §8 AUD-07 |
| FR-231 | Apnoea estimate requires ≥ 4 h valid sleep; ring SpO2 used if available. | DOC | §8 AUD-08 |
| FR-232 | The app shall keep recording with the screen off (foreground service / background audio). | DER | — |

### F-22 Hearing — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-240 | Requires earphones detected (**G-19**) and quiet room; pure tone 0.5/1/2/4 kHz each ear (up 5 dB / down 10 dB) or digits-in-noise SRT. | DOC | §8 AUD-09 |
| FR-241 | Earphone output calibration (dB HL mapping per earphone) is undefined. | OPEN | OQ-REQ-15 |

### F-23 Cognitive Speech — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-250 | Offered to age ≥ 50; animal naming 60 s + picture description; uses education level. | DOC | §8 AUD-10 |

### F-24 Mood & Crisis — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-260 | Mood check only within clinician pathway; free speech 60 s + PHQ-9 + GAD-7. | DOC | §8 AUD-11 |
| FR-261 | PHQ-9 item 9 > 0 shall immediately open the crisis screen (S-G14) (**G-37**). | DOC | §8 AUD-11 |
| FR-262 | Voice score used only if it adds ≥ 0.03 AUC over questionnaire (release gate). | DOC | §8 AUD-11 |
| FR-263 | Crisis helpline numbers / clinician escalation route are undefined. | OPEN | OQ-REQ-16 |

### F-25 Heart-Failure Voice — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-270 | Enrolled HF patients record a daily 30-s fixed sentence; first 14 days build the baseline (**G-28**); then HF_VOICE_DEV and HF_ALERT. | DOC | §8 AUD-12 |

### F-26 Motor & Neuro — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-280 | Finger tapping video: hand in frame, 10 s per hand, "big and fast". | DOC | §9 MOV-01 |
| FR-281 | Finger tapping touch: two targets, 10 s per hand. | DOC | §9 MOV-02 |
| FR-282 | Gait: phone in front trouser pocket, 10-m walk, accelerometer 50 Hz. | DOC | §9 MOV-03 |
| FR-283 | Sit-to-stand: armless chair, 30 s. | DOC | §9 MOV-04 |
| FR-284 | Tremor: phone at arm's length, 20 s per hand, gyroscope 100 Hz, peak 3–12 Hz. | DOC | §9 MOV-05 |
| FR-285 | Parkinson's score from tapping, voice, face expressivity. | DOC | §9 MOV-13 |
| FR-286 | All movement tests timed and paced by app voice + metronome. | DOC | §9 intro |

### F-27 Stroke FAST — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-290 | Face asymmetry (rest + smile), arm drift (10 s, eyes closed), speech repeat; onset time captured. | DOC | §9 MOV-06…09 |
| FR-291 | Any sign above threshold → STROKE_POSITIVE → Emergency (T10, BR-SCR-01) → S-R02. | DOC | §9 MOV-09; §10 T10 |

### F-28 Vision & Reaction — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-300 | Visual acuity: face distance 40 ± 5 cm (**G-33**), one eye covered, tumbling-E staircase, size from DPI and distance. | DOC | §9 MOV-10 |
| FR-301 | Colour vision & Amsler: max brightness, plates, Amsler at 30 cm. | DOC | §9 MOV-11 |
| FR-302 | Reaction time: 10 visual + 10 sound stimuli, random 1–4 s gaps, discard < 100 ms, median. | DOC | §9 MOV-12 |

### F-29 Risk Engine — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-310 | RSK-01: band lookup by parameter, age, sex, pregnancy; boundaries inclusive on the normal side; output range_version. | DOC | §10 RSK-01 |
| FR-311 | RSK-02: evaluate all active rules; highest urgency wins (emergency > urgent > routine). | DOC | §10 RSK-02 |
| FR-312 | RSK-03 baseline: median of last 3 valid values within 180 days; SD from last 10. | DOC | §10 RSK-03 |
| FR-313 | RSK-04 change: > 15 % or > 2 personal SD. | DOC | §10 RSK-04 |
| FR-314 | RSK-05 CKD/MetS risk shown only when BP band, diabetes band, waist and history present. | DOC | §10 RSK-05 |
| FR-315 | RSK-06 confidence = capture quality × model confidence × context factor; hidden when < 0.6 (**G-23**). | DOC | §10 RSK-06 |
| FR-316 | RSK-07 one flag/case per condition; merge within 30 days. | DOC | §10 RSK-07 |
| FR-317 | Rule test cases T1–T16 shall all pass before any master change goes live. | DOC | §10 |
| FR-318 | Full BR-VIT/BR-SCR/BR-QUA rule catalogue is not provided. | OPEN | OQ-REQ-17 |

### F-30 Cases, Flags & Confirmatory Investigations — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-320 | Each flag shall show investigations, usual cut-offs and urgency from `mst_confirmatory_test` / `mst_pathway` (Spec §13). | DOC | §13 |
| FR-321 | Urgent flags shown before routine (T15). | DOC | §10 T15 |
| FR-322 | The §13 text "reporting lab's own reference ranges and the treating clinician's judgement take precedence" shall be shown. | DOC | §13 intro |

### F-31 Specialist Review — [DOC referenced]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-330 | Results routed to IMG-10 shall show "Under specialist review" until reviewed. | DOC/DER | §6 intro |
| FR-331 | Reviewer portal, SLA and outcome codes undefined. | OPEN | OQ-REQ-18 |

### F-32 Reference Tests & Pairing — [DOC/OPEN]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-340 | Reference results shall be paired to scans only within §14 max gaps; outside window or exclusion → grade D (monitoring only). | DOC | §14, FRS REF-06 |
| FR-341 | ≥ 5 % of screen-negative members per screen per month are offered the reference test (S-R07). | DOC | §14 footer, FRS REF-03 |
| FR-342 | Exclusion questions per §14 shall be asked at reference entry. | DER | §14 |
| FR-343 | Grades A–C definitions and who enters lab results (member, operator, lab feed) undefined. | OPEN | OQ-REQ-19 |

### F-33 Smart Ring — [DOC referenced]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-350 | Optional ring (**G-32**) supplies SpO2 (AUD-08 hypopnoea, SpO2 alternative), temperature (T9), overnight rhythm flag (G-27 confirmation). | DOC | §4.5, §4.7, §8 AUD-08, §13 |
| FR-351 | Ring vendor/SDK undefined. | OPEN | OQ-REQ-20 |

### F-34 History, Trends & Baselines — [DER]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-360 | History of sessions with per-marker trend and personal baseline (RSK-03) and change flags (RSK-04). | DER | §10 |
| FR-361 | Dental history comparison by FDI (DEN-07). | DOC | §7.2 |

### F-35 Notifications & Reminders — [DER]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-370 | Reminders: monthly foot screen, daily HF voice, rhythm confirmation scan, BP recalibration (30 d), reference test invitation, specialist review completed. | DER | §6.5, §8 AUD-12, §4.7, §4.6, §14 |

### F-36 Master Data & Algorithm Version Sync — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-380 | Sync `mst_*` tables at bootstrap and periodically; store version; every result records algorithm_version and range_version. | DOC | §1, §10 RSK-01 |
| FR-381 | The app shall refuse to compute with a master set that failed rule tests (server-side gate). | DOC | §10 intro |

### F-37 Settings, Privacy & About — [STD]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-390 | Settings: language, notifications, connected devices, consents, data export/delete [OPEN], about with algorithm versions and disclaimer. | STD | — |

### F-38 Algorithm Release Gate — [DOC]

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| FR-400 | Each algorithm has release status: `validated`, `bandOnly`, `research`, `disabled` (from `mst_algorithm`). | DOC/DER | §4 intro, §4.5, §4.6 |
| FR-401 | `research` outputs are never displayed (e.g. generic SpO2 coefficients, face SpO2). `bandOnly` shows bands but not numbers (BP until mean ≤ 5 / SD ≤ 8 mmHg). | DOC | §4.5, §4.6 |
| FR-402 | Models that fail "must beat" criteria fall back (DM → profile-only score; mood voice → questionnaire only). | DOC | §4.9, §8 AUD-11 |

---

## 3. Non-functional requirements

### 3.1 Performance & real-time

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| NFR-001 | All ALG-CAP checks run on-device in real time; guidance overlay refresh ≥ 10 Hz [DER]; face landmarker every frame. | DOC/DER | §2 intro, CAP-01 |
| NFR-002 | PUL-05 neural pulse latency ≤ 15 s for a 60-s clip on target phones; hard fallback to POS at 20 s with flag. | DOC | §3 PUL-05 |
| NFR-003 | Camera capture ≥ 30 fps, 60 fps preferred; frame drops shall be recorded and count towards quality. | DOC/DER | §4.8 |
| NFR-004 | Total time from end of face scan to vitals summary should be ≤ 20 s [DER, derived from NFR-002]. | DER | — |
| NFR-005 | Processing shall run off the UI isolate (Dart isolates / native) — no UI jank during capture. | DER | — |

### 3.2 Determinism, versioning, change control

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| NFR-010 | The risk engine is deterministic: same readings + masters + versions → same flags. | DOC | §10 intro |
| NFR-011 | Every result stores `algorithm_version` and `range_version`. | DOC | §1, §10 RSK-01 |
| NFR-012 | Master tables are read-only in the app; changes only via change control and only after T1–T16 pass. | DOC | §1, §10 |
| NFR-013 | Formula implementations reproduce Spec vectors exactly (unit tests in 15_Testing). | DOC | §5 |
| NFR-014 | Master data cached locally with version; app must work with last good version offline. | DER | — |

### 3.3 Medical safety

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| NFR-020 | Wording: "screening", "risk band", "estimate" — never "diagnosis". | DOC | §13 |
| NFR-021 | Every non-normal band shows a confirmatory test recommendation from `mst_confirmatory_test`. | DOC | §13, §4.9 |
| NFR-022 | Hidden/low-confidence results never displayed as values; no guessed reference ranges. | DOC | §10 RSK-06, §4.3 |
| NFR-023 | Emergency/crisis overrides (G-37) cannot be dismissed without acknowledgement. | DOC/DER | §8 AUD-11, §10 |

### 3.4 Privacy, consent & security

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| NFR-030 | Tokens and keys in platform secure storage (Keychain / Android Keystore). | STD | — |
| NFR-031 | Local DB encrypted at rest; raw media deleted after successful upload unless training consent [DER/OPEN]. | DER/OPEN | §11.2; OQ-REQ-21 |
| NFR-032 | All network traffic TLS 1.2+ with certificate pinning [STD]. | STD | — |
| NFR-033 | No PHI in logs or crash reports. | STD | — |
| NFR-034 | Only training-consented records used for model building. | DOC | §11.2 |
| NFR-035 | Data residency, retention period, DPDP Act compliance undefined. | OPEN | OQ-REQ-22 |

### 3.5 Accessibility & localisation

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| NFR-040 | WCAG 2.1 AA contrast; touch targets ≥ 48 dp; screen-reader labels. | STD | — |
| NFR-041 | Support system text scaling up to 200 % without loss of function. | STD | — |
| NFR-042 | te/hi/en text, voice prompts and number formatting; layout tolerant of longer Telugu/Hindi strings. | DER | §8 AUD-10 |
| NFR-043 | Band never conveyed by colour alone (label + icon). | STD | — |

### 3.6 Offline & sync

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| NFR-050 | Capture and on-device checks work offline; uploads queue and sync later with idempotency keys. | DER/OPEN | OQ-REQ-23 |
| NFR-051 | Server-inference results arrive asynchronously; the UI shows "processing" state. | DER | — |

### 3.7 Fairness

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| NFR-060 | No skin-tone bias: equal pass rates Fitzpatrick IV–VI vs I–III (CAP-05); HR MAE ≤ 3 bpm in every skin-tone and phone subgroup. | DOC | §2 CAP-05, §4.1 |
| NFR-061 | Capture metadata stores phone model, skin type, age, sex for subgroup analysis. | DOC | §11.2 |

### 3.8 Device support

| ID | Requirement | Tag | Ref |
|---|---|---|---|
| NFR-070 | Supported devices = those in `mst_device_model`; per-device calibration for blur, mic, noise, focal length, SpO2. | DOC | §2, §4.5 |
| NFR-071 | Audio 44.1–48 kHz mono, processing off; capability verified via CAP-11. | DOC | §8 intro |
| NFR-072 | Minimum OS versions (Android/iOS) undefined. | OPEN | OQ-REQ-24 |

---

## 4. Open questions raised in this document

| Temp ID | Question |
|---|---|
| OQ-REQ-01 | Operator authentication (org login, PIN, shared device)? |
| OQ-REQ-02 | Languages beyond te/hi/en; speech-model validation per language? |
| OQ-REQ-03 | Consent texts, versions, legal approval? |
| OQ-REQ-04 | Symptom list for urgency rules (chest pain, fever, dizziness…)? |
| OQ-REQ-05 | Dependent age-of-majority handover? |
| OQ-REQ-06 | Operator org/site model, participant registration, batch sync? |
| OQ-REQ-07 | Device not in `mst_device_model`: block or generic profile? |
| OQ-REQ-08 | Show MAP/PP/shock index/RPP when BP is band-only? |
| OQ-REQ-09 | BP cuff calibration protocol (readings, window)? |
| OQ-REQ-10 | Orthostatic/HR-recovery/paced-breathing protocols? |
| OQ-REQ-11 | Skin classifier classes/thresholds after pilot? |
| OQ-REQ-12 | Fundus partner device/API? |
| OQ-REQ-13 | BR-DEN rule logic (FRS 12.4) and Q_CARIES_RISK items? |
| OQ-REQ-14 | Q_TB_SYMPTOMS, Q_MMRC, Q_EXPOSURE item content? |
| OQ-REQ-15 | Earphone calibration for dB HL? |
| OQ-REQ-16 | Crisis helplines and escalation route? |
| OQ-REQ-17 | Full BR-VIT/BR-SCR/BR-QUA rule catalogue? |
| OQ-REQ-18 | Specialist review portal, SLA, outcomes? |
| OQ-REQ-19 | Pairing grades A–C; who enters lab results? |
| OQ-REQ-20 | Smart-ring vendor/SDK? |
| OQ-REQ-21 | Raw media retention / deletion policy? |
| OQ-REQ-22 | Data residency, retention, DPDP compliance? |
| OQ-REQ-23 | Offline scope (which inferences on-device vs server)? |
| OQ-REQ-24 | Minimum OS versions and device tiers? |
