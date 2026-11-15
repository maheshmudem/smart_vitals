# 08 — Health Readings & Metrics (Marker Dictionary)

> **Purpose.** Every output marker produced by the VitalsMirror algorithms: code, unit, decimals, valid range, whether it is shown to the member or kept internal, normal / borderline / critical bands **exactly as written in the Spec**, the producing algorithm (`ALG-*`), the conditions it informs (`COND_*`), and the UI display rule.
>
> **Source:** *VitalsMirror — Algorithm Specifications & Test Cards* (Oct 18, 2026), called **"the Spec"**. Section references are given as *Spec §x.y*. IDs (F-xx, S-xx, G-xx) are from [00_README_Index.md](00_README_Index.md). Algorithm internals are in [09_AI_ML_Algorithm_Documentation.md](09_AI_ML_Algorithm_Documentation.md).

> [!IMPORTANT]
> **Medical safety rule.** No threshold, band, unit or formula in this document is invented. Where the Spec is silent the cell says **"Not specified in Spec — see 16_Open_Questions"** and carries **[OPEN]**. Where the Spec says a reference table is *"to be built"*, the UI shows **"Reference range not yet available"** (see §12). All outputs are **screening bands, not diagnoses**; each flag is paired with the confirmatory investigations in §14 (Spec §13).

---

## 1. How to read this document

### 1.1 Column conventions

| Column | Meaning |
|---|---|
| **Code** | Parameter / field code exactly as in the Spec (case preserved; upper-case = marker stored in results, lower-case = pipeline/field value) |
| **Unit** | Unit as in the Spec. "—" = Spec gives none |
| **Dec.** | Display decimals. "n/s" = not specified in Spec [OPEN] |
| **Valid range** | Physiological/technical range from the Spec. Values outside → rejected as invalid (status `notAvailable`/`retake`, never shown) [DER] |
| **Visibility** | `Displayed` (value + band), `Band only`, `Internal` (stored, used by other algorithms / risk engine, never shown to member), `Guidance` (drives live capture prompts, not a health result), `Diagnostic` (shown only in debug/operator QA views) |
| **Source** | Producing algorithm ID and Spec section |
| **Tag** | Provenance tag (see index §2) |

### 1.2 Global display rules (apply to every marker)

| # | Rule | Source | Tag |
|---|---|---|---|
| R-1 | Bands are looked up from `mst_reference_range` by parameter, age, sex, pregnancy; **boundaries are inclusive on the normal side** (e.g. HR 100 = normal, HR 60 = normal) | ALG-RSK-01, Spec §10 | [DOC] |
| R-2 | One `result_confidence` per result = capture quality score × model confidence × context factor (0.8 if caffeine/smoke/exercise in last 30 min). **Result hidden when < 0.6** (gate G-23) | ALG-RSK-06, Spec §10 | [DOC] |
| R-3 | A formula **never runs** if any input is missing, hidden or below its quality threshold (gate G-29) | Spec §5 intro | [DOC] |
| R-4 | SpO2, BP, rhythm and diabetes risk are trained models that **must pass their studies before display** (gate G-24) | Spec §4 intro | [DOC] |
| R-5 | All default values live in `mst_algorithm` / `mst_quality_threshold` / `mst_reference_range` and change only by change control; every stored result carries `range_version` and algorithm version | Spec §1, ALG-RSK-01 | [DOC] |
| R-6 | Adult defaults are given in the Spec; **children and pregnancy ranges live in `mst_reference_range` (not provided)** — see §16 | Spec §1 card template | [DOC] |
| R-7 | A reading with quality below threshold produces **no flag** and a "retake" (risk-engine case T16, rule BR-QUA-01) | Spec §10 | [DOC] |
| R-8 | Image screens: unusable image → guided retake (max 3) → mark **"not assessed"**. Every high or uncertain result (probability within ±0.1 of threshold) goes to specialist review (IMG-10) | Spec §6 intro | [DOC] |
| R-9 | Raw model probabilities (`*_PROB`) — Spec does not say whether they are shown to members. Recommended: **not displayed to members**; band + confidence only | Not specified in Spec — see 16_Open_Questions | [OPEN] |
| R-10 | Results are rounded to the stated decimals **only for display/storage of the final value**; whether chained formulas use rounded or unrounded intermediates, and the rounding mode (half-up vs half-even), is not stated. Test vectors in §5 reproduce with round-half-up on the final value | Not specified in Spec — see 16_Open_Questions | [OPEN] |

### 1.3 Result status vocabulary (used in UI copy)

| Status | When | UI message pattern | Token |
|---|---|---|---|
| `ok` | Value valid, quality passed, confidence ≥ 0.6, release gate allows | Value + band | band token (§13) |
| `retake` | Quality check failed (e.g. pulse SNR < 3 dB, HR disagreement) and retakes remain (max 3, G-25) | "Please retake — [reason]" | neutral |
| `notAvailable` | Insufficient data after processing ("HRV not available", "RR not available", "BP not available, use cuff") | Spec wording verbatim | neutral |
| `notAssessed` | Retakes exhausted (image), or insufficient beats for rhythm ("rhythm not assessed") | "Not assessed" | neutral |
| `hidden` | Confidence < 0.6 (R-2), or input to a formula hidden (R-3) | Not shown; parent result explains | neutral |
| `lowConfidence` | Spec explicitly says "report with low confidence" (e.g. Baevsky MxDMn < 20 ms) | Value + "Low confidence" | muted |
| `inValidation` | Release gate G-24 not yet passed for this algorithm | "In validation — not displayed" | neutral |

---

## 2. Capture-quality markers (ALG-CAP, Spec §2)

All checks run **on the phone in real time**; a capture is accepted only when every check passes for the full recording (or 2 s of continuous framing for photos) [DOC]. These are **Guidance** markers — they drive live prompts on capture screens and the retake screen (S-D03, S-D04, S-D06, S-E03, S-F03, S-G01, S-H01, S-H06, S-H07, S-B07). They are stored with the session for QA and for the RSK-06 capture-quality score [DER].

| Code | Unit | Valid range | Pass rule (default) | On fail (UI prompt — verbatim) | Source | Tag |
|---|---|---|---|---|---|---|
| `face_size_px` | px | 0–2000 | Face width ≥ 200 px | "Move closer / face the camera" | ALG-CAP-01 | [DOC] |
| `yaw_deg` | ° | −90–90 | \|yaw\| ≤ 15° | "Move closer / face the camera" | ALG-CAP-01 | [DOC] |
| `pitch_deg` | ° | −90–90 | \|pitch\| ≤ 15° | "Move closer / face the camera" | ALG-CAP-01 | [DOC] |
| `roi_pixel_count` (per ROI, 7 ROIs) | px | n/s | Each ROI ≥ 400 px | Drop that ROI; **fail capture if < 4 ROIs** | ALG-CAP-02 | [DOC] |
| `illuminance_luma` | luma | 0–255 | 60–220 (mean luma, 1-s window) | "Move to brighter place" / "Avoid direct light" | ALG-CAP-03 | [DOC] |
| `motion_px_s` | px/s | 0–500 | ≤ 3 | "Hold still" and restart | ALG-CAP-04 | [DOC] |
| `motion_high_pct` | % | 0–100 | High-motion frames ≤ 20% | "Hold still" and restart | ALG-CAP-04 | [DOC] |
| `skin_valid_pct` | % | 0–100 | ≥ 80% (YCbCr Cb 77–127, Cr 133–173) | "Remove mask / hair from forehead" | ALG-CAP-05 | [DOC] |
| `blur_score` | variance of Laplacian | 0–5000 | ≥ 100 (calibrated per device) | Autofocus tap + retake | ALG-CAP-06 | [DOC] |
| `glare_pct` | % | 0–100 | ≤ 5% (saturated = ≥ 250 luma) | "Tilt phone / more light" | ALG-CAP-07 | [DOC] |
| `dark_pct` | % | 0–100 | ≤ 10% (dark = ≤ 15 luma) | "Tilt phone / more light" | ALG-CAP-07 | [DOC] |
| `iq_score` | — | 0–1 | ≥ 0.7 | Retake with reason | ALG-CAP-08 | [DOC] |
| `iq_reason` | enum | n/s (reason list not specified) [OPEN] | — | Shown as retake reason | ALG-CAP-08 | [DOC]/[OPEN] |
| `part_found` | bool | — | true | "Show the whole [part]" | ALG-CAP-09 | [DOC] |
| mask coverage % | % | 0–100 | ≥ 80% of expected region | "Show the whole [part]" | ALG-CAP-09 | [DOC] |
| `card_found` | bool | — | true where required | Card optional unless screen requires (newborn) | ALG-CAP-10 | [DOC] |
| `colour_error_de` | ΔE | 0–50 | ≤ 5 after correction | Card optional unless screen requires (newborn) | ALG-CAP-10 | [DOC] |
| `mic_response_dev_db` | dB | 0–40 | ≤ 6 dB | Show fix; **block audio tasks** | ALG-CAP-11 | [DOC] |
| `audio_processing_detected` | bool | — | false | Show fix; **block audio tasks** | ALG-CAP-11 | [DOC] |
| `noise_dba` | dBA | 20–100 | ≤ 45 dBA | **Block audio tasks** | ALG-CAP-12 | [DOC] |
| `clip_pct` | % | 0–100 | ≤ 1% (full scale = ≥ 0.99) | "Move phone further / quieter room" | ALG-CAP-13 | [DOC] |
| `audio_snr_db` | dB | −10–60 | ≥ 15 dB | "Move phone further / quieter room" | ALG-CAP-13 | [DOC] |
| `av_offset_ms` | ms | −500–500 | — (diagnostic) | Re-record | ALG-CAP-14 | [DOC] |
| `sync_found` | bool | — | true | Re-record | ALG-CAP-14 | [DOC] |
| `face_distance_cm` | cm | 15–100 | Vision test: 40 ± 5 cm | "Move closer / further" | ALG-CAP-15 | [DOC] |

---

## 3. Pulse-pipeline markers (ALG-PUL, Spec §3)

Preconditions for all steps: CAP-01 to CAP-05 passed for ≥ 80% of frames; first 3 s discarded [DOC]. All are **Internal** (intermediate signals) except where noted.

| Code | Unit | Valid range | Rule / threshold | Visibility | Source | Tag |
|---|---|---|---|---|---|---|
| `rgb_trace[roi]` | 0–255 | 0–255 | Per-frame spatial mean R, G, B per ROI | Internal | ALG-PUL-01 | [DOC] |
| `roi_weight` | — | 0–1, sum = 1 | ROI with SNR < 0 dB → weight 0; < 4 usable ROIs → fail capture | Internal | ALG-PUL-01 | [DOC] |
| `bvp_filtered` | — | — | Detrended (λ = 300) + band-pass 0.7–3.0 Hz | Internal | ALG-PUL-02 | [DOC] |
| `bvp_pos` | — | — | POS pulse wave | Internal | ALG-PUL-03 | [DOC] |
| `bvp_chrom` | — | — | Used only when POS SNR < CHROM SNR | Internal | ALG-PUL-04 | [DOC] |
| `bvp_neural` | — | — | EfficientPhys; fail or > 20 s → POS only + flag | Internal | ALG-PUL-05 | [DOC] |
| `bvp_finger` | — | — | Saturation (mean red > 250) → "press lighter"; no pulse → "cover lens fully" | Internal (prompts = Guidance) | ALG-PUL-06 | [DOC] |
| `hr_spec_bpm` | bpm | 40–180 | Welch peak in 0.75–3.0 Hz | Internal | ALG-PUL-07 | [DOC] |
| `hr_pos_bpm` | bpm | n/s | — | Internal | ALG-PUL-07 | [DOC] |
| `hr_neural_bpm` | bpm | n/s | \|neural − POS\| > 5 bpm → retake | Internal | ALG-PUL-07 | [DOC] |
| `beat_peaks_ms[]` | ms | — | Min distance 333 ms; prominence ≥ 0.3 × local range | Internal (may drive waveform plot [DER]) | ALG-PUL-08 | [DOC] |
| `beat_feet_ms[]` | ms | — | Intersecting tangents | Internal | ALG-PUL-08 | [DOC] |
| — (beat count) | count | — | **< 20 beats → pulse readings hidden** | — | ALG-PUL-08 | [DOC] |
| `pulse_snr_db` | dB | −20–30 | **< 3 dB → "retake"** | Diagnostic / quality indicator | ALG-PUL-09 | [DOC] |
| `template_corr_mean` | — | 0–1 | Beat kept if Pearson r ≥ 0.8 vs median template | Internal | ALG-PUL-09 | [DOC] |
| `clean_beat_count` | count | n/s | HRV needs ≥ 50 clean beats | Internal | ALG-PUL-09 | [DOC] |
| `ibi_ms[]` | ms | 300–2000 valid | Reject if differs > 20% from previous valid IBI | Internal | ALG-PUL-10 | [DOC] |
| `ibi_valid_flag[]` | bool[] | — | — | Internal | ALG-PUL-10 | [DOC] |
| `ectopic_count` | count | n/s | — | Internal (feeds RHY-01) | ALG-PUL-10 | [DOC] |
| — (valid IBI %) | % | — | **Valid IBIs < 50% → HRV hidden** | — | ALG-PUL-10 | [DOC] |

> [!WARNING]
> **Prototype defect (Spec §3 note).** The 17 Oct prototype report showed pulse SNR **2.4 dB** with confidence 0.99 labelled **"GOOD"**. Under ALG-PUL-09 that scan must be marked **"retake"** (SNR < 3 dB). The production app must never show a quality label of "good" when `pulse_snr_db` < 3 dB. This is a mandatory regression test (see 09 §9).

> [!NOTE]
> **Measurable-range limitation [DER].** The band-pass (0.7–3.0 Hz, PUL-02) and spectral search (0.75–3.0 Hz, PUL-07) bound camera HR to ≈ 45–180 bpm, although `HR` valid range is 30–220. HR below ≈ 45 or above 180 bpm cannot be confirmed by spectral/beat agreement and will end in "retake". The HR critical band "< 40" is therefore not reachable from camera capture. — see 16_Open_Questions [OPEN].

---

## 4. Vital-sign and rhythm markers (Spec §4.1–4.9)

> Spec §4 intro: *"HR, RR and HRV are signal processing on the section-3 outputs, while SpO2, BP, rhythm and diabetes risk are trained models that must pass their studies before display."* [DOC]
> Results screens: **S-D07** Vitals Results Summary, **S-D08** Marker Detail, trends on **S-C05**.

### 4.1 Heart rate — ALG-PUL-07 final HR (Spec §4.1)

| Code | Display name | Unit | Dec. | Valid range | Visibility | Tag |
|---|---|---|---|---|---|---|
| `HR` | Heart rate | bpm | 0 | 30–220 | **Displayed** (value + band) | [DOC] |
| `HR_POS` | HR (POS) | bpm | n/s | n/s | Diagnostic — Spec does not state visibility; recommended not member-facing | [DOC] code / [OPEN] visibility |
| `HR_NEURAL` | HR (neural) | bpm | n/s | n/s | Diagnostic (as above) | [DOC]/[OPEN] |
| `HR_SPEC_DIFF` | Spectral vs beat HR difference | bpm | n/s | n/s | Diagnostic (as above) | [DOC]/[OPEN] |

**Bands (adult defaults)** [DOC]

| Band | Range |
|---|---|
| Normal | 60–100 bpm |
| Borderline | 50–59 **or** 101–110 bpm |
| Critical | < 40 **or** > 130 bpm |
| *Unclassified gap* | 40–49 and 111–130 bpm — **Not specified in Spec — see 16_Open_Questions** [OPEN] |

| Item | Value | Tag |
|---|---|---|
| Preconditions | Pulse SNR ≥ 3 dB; ≥ 20 clean beats | [DOC] |
| Conditions informed | COND_AF (context), COND_INFECTION, COND_HYPOXIA (context), shock index, all derived formulas | [DOC] |
| Failure / display rule | Spectral vs beat HR disagree > 3 bpm, or \|neural − POS\| > 5 bpm → **retake (max 3) → offer finger mode** (S-D06 → S-D04) | [DOC] |
| Risk-engine use | HR 135 others normal → **Emergency** (T2, BR-VIT-01); HR 105 at rest + RR 22 → **Urgent (rescan first)** (T3, BR-VIT-02) | [DOC] |
| Confirmatory trigger (§13.1) | Resting > 100 or < 50 bpm → Urgent; Emergency if > 130 or < 40 | [DOC] |

### 4.2 Respiratory rate — ALG-RSP-01 (Spec §4.2)

| Code | Display name | Unit | Dec. | Valid range | Visibility | Tag |
|---|---|---|---|---|---|---|
| `RR` | Respiratory rate | br/min | 0 | 4–60 | **Displayed** | [DOC] |
| `RR_RIIV` | RR from baseline (intensity) | br/min | n/s | n/s | Diagnostic [OPEN visibility] | [DOC] |
| `RR_RIAV` | RR from beat amplitude | br/min | n/s | n/s | Diagnostic | [DOC] |
| `RR_RIFV` | RR from IBI (frequency) | br/min | n/s | n/s | Diagnostic | [DOC] |
| `RR_MOTION` | RR from landmark motion | br/min | n/s | n/s | Diagnostic | [DOC] |
| `RR_SPREAD` | Spread of estimates | br/min | n/s | n/s | Diagnostic (> 4 → retake) | [DOC] |

**Bands** [DOC]

| Band | Range |
|---|---|
| Normal | 12–20 br/min |
| Borderline | 21–24 br/min |
| Critical | > 24 **or** < 8 br/min |
| *Unclassified gap* | 8–11 br/min — **Not specified in Spec — see 16_Open_Questions** [OPEN] |

| Item | Value | Tag |
|---|---|---|
| Preconditions | ≥ 32 s clean recording | [DOC] |
| Conditions informed | COND_INFECTION, COND_OAD (context), COND_HYPOXIA, CR_RATIO | [DOC] |
| Display rule | < 2 valid series → **"RR not available"**; offer paced-breathing retake (S-D13). Spread > 4 br/min → retake | [DOC] |
| Measurable range note | Analysis band 0.1–0.5 Hz = 6–30 br/min, although valid range is 4–60 [DER]; values outside 6–30 cannot be estimated — see 16_Open_Questions [OPEN] | [DER] |
| Risk engine | T3 (HR 105 + RR 22 → Urgent), T9 (Temp 38.4 °C + RR 22 → Urgent, BR-VIT-06) | [DOC] |
| Confirmatory trigger (§13.1) | > 20 at rest (with fever or low SpO2) → Urgent; Emergency if > 24 | [DOC] |

### 4.3 Heart-rate variability — ALG-HRV-01/02/03 (Spec §4.3)

| Code | Display name | Unit | Dec. | Valid range | Visibility | Tag |
|---|---|---|---|---|---|---|
| `SDNN` | SDNN | ms | 1 | n/s | Displayed (value; band **"Reference range not yet available"**) | [DOC] |
| `RMSSD` | RMSSD | ms | 1 | n/s | Displayed (as above) | [DOC] |
| `PNN50` | pNN50 | % | 1 | n/s | Displayed with band (> 3% normal) | [DOC] |
| `SD1` | Poincaré SD1 | ms | 1 | n/s | Displayed (no range) | [DOC] |
| `SD2` | Poincaré SD2 | ms | 1 | n/s | Displayed (no range) | [DOC] |
| `SD1_SD2` | SD1/SD2 ratio | ratio | n/s | n/s | Displayed (no range) [OPEN dec.] | [DOC] |
| `LF` | Low-frequency power | ms² | n/s | n/s | Displayed only if recording ≥ 120 s | [DOC] |
| `HF` | High-frequency power | ms² | n/s | n/s | Displayed only if recording ≥ 120 s | [DOC] |
| `LF_HF` | LF/HF ratio | ratio | n/s | n/s | Displayed only if recording ≥ 120 s | [DOC] |

**Bands** [DOC]

| Marker | Normal | Other bands |
|---|---|---|
| PNN50 | > 3% | Not specified — no "low" label; values ≤ 3% → band **not specified** [OPEN] |
| SDNN, RMSSD, SD1, SD2, SD1_SD2, LF, HF, LF_HF | **Age-band tables in `mst_reference_range` (to be built from Mayura healthy cohort)** | UI: **"Reference range not yet available"** |

| Item | Value | Tag |
|---|---|---|
| Preconditions | ≥ 50 clean beats (time domain); ≥ 2 min recording (frequency domain, ≥ 120 s) | [DOC] |
| Conditions informed | Stress band, COND_DM (autonomic features), COND_AF features, recovery trends | [DOC] |
| Display rule | Too few beats → **"HRV not available"**; valid IBIs < 50% → HRV hidden (PUL-10) | [DOC] |
| Confirmatory trigger (§13.1) | RMSSD/SDNN below age band, especially with diabetes → Routine. **Cannot fire until age bands exist** [DER] | [DOC]/[DER] |

### 4.4 Stress index — ALG-HRV-04 Baevsky (Spec §4.4)

| Code | Display name | Unit | Dec. | Valid range | Visibility | Tag |
|---|---|---|---|---|---|---|
| `BAEVSKY_SI` | Stress index | units | n/s [OPEN] | 10–2000 | Displayed | [DOC] |
| `STRESS_BAND` | Stress level | enum low / moderate / high | — | — | **Displayed** | [DOC] |

**Bands** [DOC]

| Band | BAEVSKY_SI |
|---|---|
| Low | 50–150 |
| Moderate | 151–500 |
| High | > 500 |
| *Unclassified gap* | 10–49 (and non-integers between 150 and 151 if SI is not rounded) — **Not specified in Spec — see 16_Open_Questions** [OPEN] |

| Item | Value | Tag |
|---|---|---|
| Preconditions | ≥ 50 clean beats | [DOC] |
| Conditions informed | Stress band; COND_MOOD (context only) | [DOC] |
| Display rule | MxDMn < 20 ms (very rigid rhythm) → report with **low confidence** (status `lowConfidence`) | [DOC] |
| Confirmatory trigger (§13.1) | High on repeated scans → Routine; no lab test required (TSH if persistent tachycardia; PHQ-9/GAD-7 if mood symptoms). "Repeated" count not specified [OPEN] | [DOC]/[OPEN] |

### 4.5 SpO2 band — ALG-SPO-01 (Spec §4.5)

| Code | Display name | Unit | Dec. | Valid range | Visibility | Tag |
|---|---|---|---|---|---|---|
| `SPO2_ROR` | Ratio of ratios | ratio | n/s | n/s | **Internal** | [DOC] |
| `SPO2_EST` | SpO2 estimate | % | n/s | n/s | **Internal** (Spec: "%, internal") — never displayed as a number | [DOC] |
| `SPO2_BAND` | Oxygen level | enum normal / borderline / critical | — | — | **Band only**, finger mode only, only when device model has fitted coefficients and G-24 passed | [DOC] |

**Bands** [DOC]

| Band | SPO2_EST |
|---|---|
| Normal | ≥ 95% |
| Borderline | 92–94% |
| Critical | < 92% |
| *Gap* | Non-integer values between 94 and 95 — rounding before banding not specified [OPEN] |

| Item | Value | Tag |
|---|---|---|
| Preconditions | Finger mode; PI ≥ 0.4%; ≥ 20 clean beats. Face mode = research only | [DOC] |
| Conditions informed | COND_HYPOXIA, COND_OAD, COND_OSA (with ring), COND_INFECTION | [DOC] |
| Display rule | Device without coefficients in `mst_device_model` → **band not shown**; recommend oximeter or ring. Generic fallback A = 110, B = 25 is **research only, not displayed** | [DOC] |
| Acceptance gate | Band agreement ≥ 90%; **no "normal" shown when reference < 92%** in validation set (VIT-SPO2-01) | [DOC] |
| Risk engine | SpO2 band critical (< 92%) → **Emergency** (T1, BR-VIT-01) | [DOC] |
| Confirmatory trigger (§13.1) | < 95% (finger) → Emergency if < 92% | [DOC] |

### 4.6 Blood pressure — ALG-BP-01 (Spec §4.6)

| Code | Display name | Unit | Dec. | Valid range | Visibility | Tag |
|---|---|---|---|---|---|---|
| `SBP` | Systolic BP | mmHg | n/s | 60–260 | **Internal** until numeric acceptance met (mean error ≤ 5 and SD ≤ 8 mmHg) | [DOC] |
| `DBP` | Diastolic BP | mmHg | n/s | 30–160 | **Internal** (as above) | [DOC] |
| `BP_BAND` | Blood pressure band | enum normal / elevated / high | — | — | **Band only** ("band-only display until validated"); requires band agreement ≥ 85% (VIT-BP-02) | [DOC] |
| `BP_CONFIDENCE` | BP confidence | — | n/s | 0–1 | Shown as confidence indicator [DER] | [DOC] |

**Bands** [DOC]

| Band | SBP / DBP |
|---|---|
| Normal | < 120 / < 80 |
| Elevated | 120–139 / 80–89 |
| High | ≥ 140 / ≥ 90 |
| *Combination rule* | How SBP and DBP combine when they fall in different bands (e.g. 118/85) is **not specified in Spec** — conventional "higher category wins" is assumed pending confirmation — see 16_Open_Questions [OPEN] |

| Item | Value | Tag |
|---|---|---|
| Preconditions | ≥ 40 clean beats; finger mode **or** face SNR ≥ 6 dB; age, sex, height, weight present (G-02) | [DOC] |
| Personal calibration | If cuff calibration within **30 days** exists, apply offset (S-D10, G-26) | [DOC] |
| Conditions informed | COND_HTN, COND_CKD, COND_METS, shock index, MAP, PP, RPP | [DOC] |
| Display rule | `BP_CONFIDENCE` < 0.6 → **"BP not available, use cuff"** | [DOC] |
| Risk engine | BP band high, no symptoms → Routine (T7, BR-VIT-04); BP band high + chest pain → Urgent (T8) | [DOC] |
| Confirmatory trigger (§13.1) | Elevated or High → Routine; **Urgent if ≥ 180/110 or symptoms**. Evaluating ≥ 180/110 needs internal SBP/DBP — whether internal numbers may drive this rule is not specified [OPEN] | [DOC]/[OPEN] |

### 4.7 Irregular rhythm — ALG-RHY-01 (Spec §4.7)

| Code | Display name | Unit | Dec. | Valid range | Visibility | Tag |
|---|---|---|---|---|---|---|
| `IRREG_PROB` | Irregular-rhythm probability | — | n/s | 0–1 | Internal / not member-facing (R-9) [OPEN] | [DOC] |
| `IRREG_BAND` | Rhythm | enum regular / irregular | — | — | **Band only**, after G-24; "irregular" only after confirmation (G-27) | [DOC] |
| `ECTOPIC_PM` | Ectopic beats per minute | /min | n/s | n/s | Displayed with band [DER] | [DOC] |

**Bands** [DOC]

| Marker | Normal | Abnormal |
|---|---|---|
| IRREG_BAND | Regular | Irregular — positive if probability ≥ threshold (initial 0.5, final chosen for ≥ 90% sensitivity) on **2 scans**, or 1 scan + ring overnight flag |
| ECTOPIC_PM | ≤ 1/min | > 1/min — band label not specified [OPEN] |

| Item | Value | Tag |
|---|---|---|
| Preconditions | IBI series ≥ 30 s with ≥ 70% valid beats | [DOC] |
| Conditions informed | COND_AF | [DOC] |
| Display rule | Insufficient clean beats → **"rhythm not assessed"**. Single positive scan → prompt confirmation scan (S-R03) [DER from G-27] | [DOC]/[DER] |
| Risk engine | Irregular rhythm on 2 scans → **Urgent** (T6, BR-VIT-03) | [DOC] |
| Confirmatory trigger (§13.1) | Irregular on 2 scans → Urgent | [DOC] |

### 4.8 Pulse waveform & vascular age — ALG-WAV-01 to 05 (Spec §4.8)

| Code | Display name | Unit | Dec. | Valid range | Visibility | Tag |
|---|---|---|---|---|---|---|
| `PI` | Perfusion index | % | n/s | n/s | Displayed (finger only); also gate for SpO2 (PI ≥ 0.4%) | [DOC] |
| `RISE_TIME` | Rise time | ms | n/s | n/s | Displayed (no range) | [DOC] |
| `NOTCH_TIME` | Dicrotic notch time | ms | n/s | n/s | Hidden if notch not found | [DOC] |
| `NOTCH_REL_H` | Notch relative height | — | n/s | 0–1 | Hidden if notch not found | [DOC] |
| `RI` | Reflection index | — | n/s | 0–1.5 | Displayed (no range) | [DOC] |
| `AIX` | Augmentation index | % | n/s | n/s | Displayed (no range) | [DOC] |
| `WIDTH_25`, `WIDTH_50`, `WIDTH_75` | Pulse width at 25/50/75% | ms | n/s | n/s | Displayed (no range) | [DOC] |
| `AREA_RATIO` | Area ratio | ratio | n/s | n/s | Displayed (no range) | [DOC] |
| `SDPPG_BA`, `SDPPG_CA`, `SDPPG_DA`, `SDPPG_EA` | 2nd-derivative ratios b/a, c/a, d/a, e/a | ratio | n/s | n/s | Displayed (no range) | [DOC] |
| `AGING_INDEX` | SDPPG aging index (b − c − d − e)/a | — | n/s | n/s | Displayed (no range) | [DOC] |
| `VASC_AGE` | Vascular age | years | n/s | n/s | Displayed only when regression from healthy reference group exists [DER] | [DOC] |
| `VASC_AGE_GAP` | Vascular-age gap | years | n/s | n/s | Displayed with band | [DOC] |
| `PTT_PROXY` | Pulse-transit-time proxy | ms | n/s | n/s | **Internal** feature for BP [DER] (visibility not specified) | [DOC]/[OPEN] |

> Which of these markers are member-facing vs research/internal is **not specified in Spec** — see 16_Open_Questions [OPEN]. Recommended [DER]: show `VASC_AGE`, `VASC_AGE_GAP`, `PI` on S-D08; others in an "advanced" expander.

**Bands** [DOC]

| Marker | Normal | Other |
|---|---|---|
| VASC_AGE_GAP | ≤ 5 years | Confirmatory trigger at **> 10 years above age** (§13.1, Routine). Band for 5–10 years not specified [OPEN] |
| All other waveform markers | **Age-band tables (to be built)** | UI: "Reference range not yet available" |

| Item | Value | Tag |
|---|---|---|
| Preconditions | ≥ 40 clean beats; capture ≥ 30 fps (60 fps preferred); finger preferred | [DOC] |
| Conditions informed | COND_HTN, COND_DM, cardiovascular risk | [DOC] |
| Display rule | Notch not found → notch-based markers hidden; others kept | [DOC] |

### 4.9 Diabetes risk — ALG-DM-01 (Spec §4.9)

| Code | Display name | Unit | Dec. | Valid range | Visibility | Tag |
|---|---|---|---|---|---|---|
| `DM_PROB_57` | Probability HbA1c ≥ 5.7% | — | n/s | 0–1 | Internal / not member-facing (R-9) [OPEN] | [DOC] |
| `DM_PROB_65` | Probability HbA1c ≥ 6.5% | — | n/s | 0–1 | Internal / not member-facing [OPEN] | [DOC] |
| `DM_BAND` | Diabetes risk | enum low / prediabetes risk / diabetes risk | — | — | **Band only**, after G-24 | [DOC] |

**Bands** [DOC]

| Band | Rule |
|---|---|
| Low risk (normal) | Below both thresholds |
| Prediabetes risk | ≥ threshold of the HbA1c ≥ 5.7% classifier |
| Diabetes risk | ≥ threshold of the HbA1c ≥ 6.5% classifier |
| Thresholds | Chosen for ≥ 80% sensitivity on validation set — **values not yet available** (VIT-DM-01) |

| Item | Value | Tag |
|---|---|---|
| Preconditions | Vitals session passed quality; profile complete (G-02, G-03) | [DOC] |
| Conditions informed | COND_DM; **triggers eye, foot and dental follow-ups when high** | [DOC] |
| Display rule | **Missing waist or BMI → band not shown**. Always recommend HbA1c test when not low | [DOC] |
| Release fallback | Must beat profile-only model (age, BMI, waist, family history) by ≥ 0.03 AUC, otherwise the **profile-only score** is used | [DOC] |
| Confirmatory trigger (§13.1) | Prediabetes or diabetes risk → Routine | [DOC] |

---

## 5. Derived-formula markers (ALG-FRM, Spec §5)

Each formula must reproduce its test vector **exactly** (to the stated decimals). A formula never runs if any input is missing, hidden or below its quality threshold [DOC]. Screens: **S-D07 / S-D09** (body & fitness), **S-D11** (orthostatic), **S-D12** (HR recovery), **S-G06** (lung function % predicted), growth z-scores on dependent profile/S-D09 [DER].

| ID | Code | Formula | Inputs | Unit | Dec. | Valid range | Normal (Spec) | Test vector → expected | Visibility | Tag |
|---|---|---|---|---|---|---|---|---|---|---|
| ALG-FRM-01 | `map_mmhg` | MAP = DBP + (SBP − DBP) / 3 | SBP, DBP (mmHg) | mmHg | 1 | 40–180 | 70–100 | 117 / 77 → **90.3** | Depends on SBP/DBP (internal) → see note A [OPEN] | [DOC] |
| ALG-FRM-02 | `pp_mmhg` | PP = SBP − DBP | SBP, DBP | mmHg | 0 | 10–120 | 30–50 | 117 / 77 → **40** | Note A [OPEN] | [DOC] |
| ALG-FRM-03 | `shock_index` | Shock index = HR / SBP | HR, SBP | ratio | 2 | 0.2–3 | 0.5–0.7 | 92 / 117 → **0.79** | Note A [OPEN]; always used by risk engine (T4, T5) | [DOC] |
| ALG-FRM-04 | `rpp` | RPP = HR × SBP | HR, SBP | bpm·mmHg | 0 | 3000–40000 | < 12000 | 92 × 117 → **10764** | Note A [OPEN] | [DOC] |
| ALG-FRM-05 | `cr_ratio` | CR ratio = HR / RR | HR, RR | ratio | 2 | 1–20 | 3–6 | 92 / 21 → **4.38** | Displayed | [DOC] |
| ALG-FRM-06 | `hrmax_bpm` | HRmax (Tanaka) = 208 − 0.7 × age | Age (years) | bpm | 1 | 120–210 | — (none) | 26 → **189.8** | Displayed (no band) | [DOC] |
| ALG-FRM-07 | `hrr_bpm` | HRR (Karvonen) = HRmax − HRrest | HRmax, HR | bpm | 1 | 20–180 | "Higher is fitter" (no band) | 189.8 − 92 → **97.8** | Displayed (no band) | [DOC] |
| ALG-FRM-08 | `vo2max_est` | VO2max (Uth) = 15.3 × HRmax / HRrest | HRmax, HR | mL/kg/min | 1 | 10–80 | **Age/sex table** (not provided — to be built) | 15.3 × 189.8 / 92 → **31.6** | Displayed, labelled **"estimate"**; band "Reference range not yet available" | [DOC] |
| ALG-FRM-09 | `bmi` | BMI = weight / height² | kg, m | kg/m² | 2 | 10–70 | 18.5–22.9 (Asian) | 70 kg, 1.78 m → **22.09** | Displayed | [DOC] |
| ALG-FRM-10 | `whtr` | WHtR = waist / height | cm, cm | ratio | 3 | 0.3–1.0 | < 0.5 | 85 / 178 → **0.478** | Displayed | [DOC] |
| ALG-FRM-11 | `body_fat_pct` | Body fat (Deurenberg) = 1.2·BMI + 0.23·age − 10.8·sex − 5.4 (male = 1) | BMI, age, sex | % | 2 | 3–60 | Men 10–20; women 20–30 | BMI 22.09, 26 y, male → **16.29** | Displayed, labelled **"estimate"**; **adults only** | [DOC] |
| ALG-FRM-12 | `haz`, `waz`, `bmiz` | WHO z = ((X / M)^L − 1) / (L × S) | Measurement, L, M, S from `mst_growth_reference` | z | 2 | −6–6 | −2 to +2 | X = 18, L = −0.5, M = 16, S = 0.08 → **1.43**; X = M → **0.00** | Displayed (children) | [DOC] |
| ALG-FRM-13 | `fev1_pred_pct`, `fvc_pred_pct`, `ratio_lln` | GLI-2012 predicted and LLN | Sex, age, height, FEV1, FVC | % | 0 | n/s | ≥ LLN | 5 cases from official GLI calculator (values not in Spec) | Displayed on S-G06 | [DOC] |
| ALG-FRM-14 | `ortho_hr_rise_bpm` | Orthostatic rise = max standing HR (0–3 min) − mean lying HR (last 30 s) | HR series | bpm | 0 | −20–80 | < 30 | Lying 70, standing max 104 → **34 (flag)** | Displayed | [DOC] |
| ALG-FRM-15 | `hr_recovery_1m_bpm` | HR recovery = HR at end of exercise − HR 60 s later | HR series | bpm | 0 | −10–80 | ≥ 12 | 120 → 105 → **15 (normal)** | Displayed | [DOC] |

**Out-of-normal labels for formulas.** The Spec gives only a *normal* range per formula; it does **not** name a borderline/critical band. The app shows `normal` vs **"outside normal range"** (warning token) unless a §13 trigger or risk rule applies [DER]:

| Marker | Spec-defined escalations beyond "normal" | Tag |
|---|---|---|
| `shock_index` | > 0.9 → confirmatory "Emergency assessment" (§13.1); T4: 0.79 → **no flag**; T5: 1.05 → **Emergency** (BR-VIT-01). Values 0.71–0.90 → outside normal, no flag | [DOC] |
| `bmi` / `whtr` | BMI ≥ 23 or WHtR ≥ 0.5 → metabolic work-up, Routine (§13.1). BMI < 18.5 label not specified [OPEN] | [DOC]/[OPEN] |
| `ortho_hr_rise_bpm` | HR rise ≥ 30 (or BP fall with dizziness) → Routine (§13.1) | [DOC] |
| `haz`/`waz`/`bmiz` | z < −2 → growth faltering, Routine (§13.2). z > +2 label not specified [OPEN] | [DOC]/[OPEN] |
| `ratio_lln` | FEV1/FVC < LLN → Routine (§13.2) | [DOC] |
| `hr_recovery_1m_bpm` | < 12 → outside normal; no §13 row [OPEN] | [DOC]/[OPEN] |
| `map_mmhg`, `pp_mmhg`, `rpp`, `cr_ratio`, `body_fat_pct` | None beyond normal range | [DOC] |

> [!WARNING]
> **Note A — formulas on internal BP numbers [OPEN].** SBP/DBP are *internal* until BP numeric acceptance (mean ≤ 5, SD ≤ 8 mmHg). Spec §5 forbids running a formula on a *hidden* input, yet the risk-engine cases T4/T5 compute shock index from SBP. Recommended interpretation [DER]: *internal ≠ hidden* — FRM-01…04 are computed for the risk engine when SBP/DBP pass quality, but `map_mmhg`, `pp_mmhg`, `shock_index`, `rpp` are **not displayed** until BP numbers are released. Must be confirmed — see 16_Open_Questions.

---

## 6. Image-screen markers (ALG-IMG, Spec §6)

Shared rules [DOC]: screening consent (G-04), CAP-06/07/08/09 passed, colour card where required (G-20); unusable image → guided retake (max 3) → **"not assessed"**; high or uncertain (probability within ±0.1 of threshold) → specialist review IMG-10 (F-31). All IMG classifiers are trained models → **G-24 applies** (status `inValidation` until study passes). Screens: S-E01…S-E04, result on **S-R01**; fundus S-E06.

| Screen | Code | Display name | Unit | Dec. | Range | Visibility | Band values / thresholds (Spec) | Conditions | Source | Tag |
|---|---|---|---|---|---|---|---|---|---|---|
| Anaemia | `HB_EST` | Haemoglobin estimate | g/dL | 1 | n/s | **Internal** | Band by age/sex/pregnancy — WHO anaemia: men < 13.0; non-pregnant women < 12.0; pregnant women < 11.0; children 5–11 y < 11.5; 6–59 months < 11.0 g/dL | COND_ANAEMIA | ALG-IMG-01 §6.1 | [DOC] |
| | `ANAEMIA_PROB` | Anaemia probability | — | n/s | 0–1 | Not member-facing (R-9) [OPEN] | — | | | [DOC] |
| | `ANAEMIA_BAND` | Anaemia screen | enum | — | — | **Band only** | Band labels not enumerated; §13 uses "High band" [OPEN] | | | [DOC]/[OPEN] |
| Jaundice (adult) | `SCLERA_BSTAR` | Sclera yellowness (b*) | CIELab b* | n/s | n/s | Internal [DER] | — | COND_JAUNDICE | ALG-IMG-02 §6.2 | [DOC] |
| | `JAUNDICE_PROB` | Jaundice probability | — | n/s | 0–1 [DER] | Not member-facing [OPEN] | Positive reference: serum total bilirubin > 2.5 mg/dL | | | [DOC] |
| | `JAUNDICE_BAND` | Jaundice screen | enum | — | — | Band only | Labels not enumerated; §13 "High band" [OPEN] | | | [DOC]/[OPEN] |
| Cataract | `CATARACT_PROB_L`, `CATARACT_PROB_R` | Cataract probability per eye | — | n/s | 0–1 [DER] | Not member-facing [OPEN] | — | COND_CATARACT | ALG-IMG-03 §6.3 | [DOC] |
| | `CATARACT_BAND` | Cataract screen | enum | — | — | Band only | Labels not enumerated; §13 "High band". Offered to age ≥ 40 or on request (G-09) | | | [DOC]/[OPEN] |
| Oral lesion | `ORAL_CLASS` | Oral screen | enum **not suspicious / suspicious / high risk** | — | — | Band (class) | Tobacco users always offered | COND_ORAL_CA | ALG-IMG-04 §6.4 | [DOC] |
| | `ORAL_PROB_SUSP`, `ORAL_PROB_HIGH` | Class probabilities | — | n/s | 0–1 | Not member-facing [OPEN] | — | | | [DOC] |
| | lesion regions | Heat-map regions | — | — | — | Displayed as overlay [DER] | — | | | [DOC] |
| Diabetic foot | `DFU_CLASS` | Foot screen | enum **normal / at risk / ulcer** | — | — | Band (class) | Offered to members with diabetes or high diabetes risk; monthly (G-10, G-34) | COND_DFU | ALG-IMG-05 §6.5 | [DOC] |
| | `DFU_PROB` | Probability | — | n/s | 0–1 | Not member-facing [OPEN] | — | | | [DOC] |
| | `WOUND_AREA` | Wound area | cm² | n/s | n/s | Displayed when ulcer detected and colour card present [DER] | — | | | [DOC] |
| Child eye (1–12 y) | `REFLEX_ASYM` | Red-reflex asymmetry | n/s | n/s | n/s | Internal [DER] | — | COND_CHILD_EYE | ALG-IMG-06 §6.6 | [DOC] |
| | `HIRSCHBERG_DEG` | Estimated deviation | ° | n/s | n/s | Internal [DER] | Hirschberg ≈ 12–15° per mm of reflex offset (calibrate on study data) | | | [DOC] |
| | `WHITE_PUPIL_PROB` | White-pupil probability | — | n/s | 0–1 | Not member-facing [OPEN] | **White pupil always urgent** | | | [DOC] |
| | `CHILD_EYE_BAND` | Child eye screen | enum | — | — | Band only | Labels not enumerated; §13 uses "Refer / white pupil" [OPEN] | | | [DOC]/[OPEN] |
| Newborn jaundice (0–28 d) | `NEO_BILI_EST` | Bilirubin estimate | mg/dL | n/s | n/s | Numeric display **not specified** — recommended internal until IMG-NJ-01 passes [OPEN] | Compared with age-in-hours treatment chart (chart not provided) | COND_NEO_JAUNDICE | ALG-IMG-07 §6.7 | [DOC]/[OPEN] |
| | `NEO_JAUNDICE_BAND` | Newborn jaundice screen | enum | — | — | Band only | **Never shows "normal" without colour card** (card mandatory, G-20); **high band = above phototherapy-consideration line**; other labels not enumerated [OPEN] | | | [DOC] |
| Skin | `SKIN_CLASS`, `SKIN_PROB`, `SKIN_BAND` | Skin screen | enum / 0–1 / enum | — | — | Band only | Classes/thresholds not specified; acceptance "set after pilot" [OPEN] | COND_* not specified [OPEN] | ALG-IMG-08 §6.8 | [DOC]/[OPEN] |
| Fundus (partner) | `DR_REFERABLE` | Referable DR | bool | — | — | Displayed (partner result) | Referable = ICDR moderate NPDR or worse, or macular oedema (§13.2) | COND_* not named [OPEN] | ALG-IMG-09 §6.8 | [DOC] |
| | `DR_GRADE` | DR grade | enum (ICDR [DER]) | — | — | Displayed | — | | | [DOC] |
| | `GLAUCOMA_SUSPECT` | Glaucoma suspect | bool | — | — | Displayed | No §13 row for glaucoma [OPEN] | | | [DOC]/[OPEN] |

---

## 7. Dental markers (ALG-DEN, Spec §7)

Preconditions: dental consent (guardian for children, G-05); views pass blur/glare/coverage checks. Child mode (ages 1–12) changes capture guidance and tooth chart, not the models [DOC]. Screens: S-F01…S-F05.

| Code | Display name | Unit / values | Visibility | Rule (Spec) | Source | Tag |
|---|---|---|---|---|---|---|
| `tooth_fdi` | Tooth number | FDI: primary **51–85** (< 6 y); mixed (6–12 y); permanent **11–48** | Displayed on tooth chart (S-F04) | Numbered by view-specific left-to-right order and arch | ALG-DEN-02 [DER mapping] | [DOC] |
| `finding_code` | Finding | **white spot, enamel break, cavity, broken/black, abscess sign** | Displayed (S-F05) | Max 1 finding per class per tooth surface; duplicates across views merged keeping highest severity | ALG-DEN-03 | [DOC] |
| `finding_prob` | Finding probability | 0–1 | Not member-facing (R-9) [OPEN] | Thresholds set for target sensitivity (values not provided) | ALG-DEN-03 | [DOC] |
| `bbox` | Bounding box | px | Overlay [DER] | Detection confidence ≥ 0.5 | ALG-DEN-02 | [DOC] |
| `dental_exam.views_completed` | Views completed | 0–4 [DER] | Displayed | 4 views: front closed, front open, upper biting, lower biting | ALG-DEN-01 | [DOC] |
| `partial` | Partial exam | bool | Displayed | Missing view → exam "partial"; report says which teeth were not seen | ALG-DEN-01 | [DOC] |
| `GUM_INFLAM_BAND` | Gum inflammation | band (labels n/s; §13 "High band") | Band only | Per sextant | ALG-DEN-04 | [DOC]/[OPEN] |
| `PLAQUE_BAND` | Plaque | band (labels n/s) | Band only | Per sextant | ALG-DEN-04 | [DOC]/[OPEN] |
| `sealant_needed_teeth[]` | Sealant needed | FDI 16, 26, 36, 46 | Displayed (age 6–9) | Deep pit/fissure on first permanent molars | ALG-DEN-05 | [DOC] |
| `caries_risk_level` | Caries risk | **Low / Moderate / High** (from test vectors) | Displayed | Rule BR-DEN (FRS 12.4) — **rule text not provided**; 6 test cases in 09 §8.4 | ALG-DEN-06 | [DOC]/[OPEN] |
| `change_vs_previous` | Change since last exam | **new / progressed** (others n/s, e.g. "unchanged/resolved" [OPEN]) | Displayed (S-F04, S-C05) | Match by FDI; new finding = new; severity increase = progressed | ALG-DEN-07 | [DOC] |

Conditions informed: **COND_CARIES** (DEN-01…03). Risk engine: dental abscess sign → **Urgent** (T13, BR-SCR-02); dental cavity only → **Routine** (T14, BR-SCR-04). Severity order of finding codes (for "keep highest severity") is not specified [OPEN].

---

## 8. Audio markers (ALG-AUD, Spec §8)

All audio algorithms require CAP-11, CAP-12 (≤ 45 dBA) and CAP-13 (clip ≤ 1%, SNR ≥ 15 dB); recorded 44.1–48 kHz mono, phone processing off, down-sampled to 16 kHz for models [DOC]. Gates G-12, G-17, G-18.

| Code | Display name | Unit | Dec. | Valid range | Normal (Spec) | Visibility | Source / screen | Tag |
|---|---|---|---|---|---|---|---|---|
| `COUGH_COUNT_VALID` | Valid coughs | count | 0 | 0–10 | ≥ 3 valid | Guidance (task progress) | AUD-01 / S-G03 | [DOC] |
| `cough_events[]` | Cough events | — | — | prob ≥ 0.5, duration 150–800 ms | — | Internal | AUD-01 | [DOC] |
| `audio_embedding[]` | Health-audio embedding | vector | — | — | — | Internal | AUD-02 | [DOC] |
| `TB_PROB` | TB probability | — | n/s | 0–1 | — | Not member-facing [OPEN] | AUD-03 | [DOC] |
| `TB_BAND` | TB risk | enum (labels n/s; §13 "High risk") | — | — | **Low** | Band only (G-24) | AUD-03 / S-G06 | [DOC]/[OPEN] |
| `OAD_PROB` | Obstruction probability | — | n/s | n/s | — | Not member-facing | AUD-04 | [DOC] |
| `OAD_BAND` | Airway obstruction risk | enum (labels n/s) | — | — | **Low** | Band only (G-24) | AUD-04 / S-G06 | [DOC]/[OPEN] |
| `ASTHMA_VS_COPD_PROB` | Asthma vs COPD | — | n/s | n/s | — | Not specified [OPEN] | AUD-04 | [DOC] |
| `FEV1_L` | FEV1 | L | n/s | 0.3–7 | — | Displayed after G-24 | AUD-05 / S-G05, S-G06 | [DOC] |
| `FVC_L` | FVC | L | n/s | 0.3–8 | — | Displayed after G-24 | AUD-05 | [DOC] |
| `FEV1_FVC` | FEV1/FVC | ratio | n/s | 0.2–1 | Ratio ≥ LLN | Displayed after G-24 | AUD-05 | [DOC] |
| `PEF_LS` | Peak flow | L/s | n/s | 0.5–15 | — | Displayed after G-24 | AUD-05 | [DOC] |
| % predicted | % predicted | % | 0 | — | — | Displayed (via FRM-13) | AUD-05 + FRM-13 | [DOC] |
| `RATIO_LLN` | Ratio vs LLN | — | — | — | ≥ LLN | Displayed | AUD-05 + FRM-13 | [DOC] |
| `F0_HZ` | Fundamental frequency | Hz | n/s | 75–500 analysis range | — (no norm) | Displayed [DER] | AUD-06 / S-G06 | [DOC] |
| `JITTER_PCT` | Jitter (local) | % | n/s | n/s | < 1.04% | Displayed | AUD-06 | [DOC] |
| `SHIMMER_PCT` | Shimmer (local) | % | n/s | n/s | < 3.81% | Displayed | AUD-06 | [DOC] |
| `HNR_DB` | Harmonics-to-noise | dB | n/s | n/s | > 20 dB | Displayed | AUD-06 | [DOC] |
| `CPPS_DB` | CPPS | dB | n/s | n/s | n/s [OPEN] | Displayed (no range) | AUD-06 | [DOC] |
| `MPT_S` | Max phonation time | s | n/s | n/s | ≥ 15 s (adult); child norm not given | Displayed | AUD-06 | [DOC] |
| `SZ_RATIO` | s/z ratio | ratio | n/s | n/s | < 1.4 | Displayed | AUD-06 | [DOC] |
| `SONAR_RR` | Sleep breathing rate | br/min | n/s | n/s | 12–20 br/min | Displayed (S-G09) | AUD-07 | [DOC] |
| `sonar_breath_wave` | Breathing waveform | — | — | — | — | Internal / chart [DER] | AUD-07 | [DOC] |
| `APNOEA_EVENTS` | Apnoea events | count | 0 | n/s | — | Displayed | AUD-08 / S-G09 | [DOC] |
| `HYPOPNOEA_EVENTS` | Hypopnoea events | count | 0 | n/s | — | Displayed | AUD-08 | [DOC] |
| `AHI_EST` | AHI estimate | events/h | n/s | n/s | < 5 | Displayed after G-24 | AUD-08 | [DOC] |
| `OSA_BAND` | Sleep apnoea band | enum | — | — | AHI **< 5 normal; 5–14 mild; 15–29 moderate; ≥ 30 severe** | Band | AUD-08 | [DOC] |
| `VALID_SLEEP_H` | Valid sleep hours | h | n/s | ≥ 4 h required | — | Displayed | AUD-08 | [DOC] |
| `HEAR_L_xxx`, `HEAR_R_xxx` (xxx = 500, 1000, 2000, 4000 Hz [DER]) | Hearing threshold | dB HL | 0 [DER: 5-dB steps] | n/s | All thresholds **< 20 dB HL** (WHO 2021 grading) | Displayed | AUD-09 / S-G11 | [DOC] |
| `DIN_SRT_DB` | Digits-in-noise SRT | dB | n/s | n/s | Below normative cut-off (**cut-off not provided**) | Displayed; band "Reference range not yet available" | AUD-09 | [DOC]/[OPEN] |
| `HEARING_BAND` | Hearing band | enum (WHO 2021 grades not listed in Spec) | — | — | Normal = all < 20 dB HL | Band | AUD-09 | [DOC]/[OPEN] |
| `FLUENCY_COUNT` | Animal-naming count | count | 0 | n/s | Age/education norms (to be built) | Displayed | AUD-10 / S-G12 | [DOC] |
| `PAUSE_RATE` | Pause rate (> 2 s) | n/s | n/s | n/s | Norms to be built | Displayed | AUD-10 | [DOC] |
| `SPEECH_RATE` | Speech rate | n/s | n/s | n/s | Norms to be built | Displayed | AUD-10 | [DOC] |
| `LEXICAL_DIV` | Lexical diversity | n/s | n/s | n/s | Norms to be built | Displayed | AUD-10 | [DOC] |
| `COG_BAND` | Cognitive screen | enum (labels n/s; §13 "Refer") | — | — | Age/education norms | Band (G-24) | AUD-10 | [DOC]/[OPEN] |
| `MOOD_VOICE_SCORE` | Voice mood score | n/s | n/s | n/s | — | **Not used** unless voice adds ≥ 0.03 AUC over questionnaire; clinician pathway only (G-07) | AUD-11 / S-G13 | [DOC] |
| `PHQ9` | PHQ-9 | score | 0 | 0–27 | < 5 | Displayed (clinician pathway) | AUD-11 | [DOC] |
| `GAD7` | GAD-7 | score | 0 | 0–21 | < 5 | Displayed (clinician pathway) | AUD-11 | [DOC] |
| `HF_VOICE_DEV` | HF voice deviation | score | n/s | n/s | — | Displayed to enrolled HF patients [DER] | AUD-12 / S-G15 | [DOC] |
| `HF_ALERT` | HF alert | bool | — | — | **No alert** | Displayed | AUD-12 | [DOC] |

Audio safety & band rules [DOC]:

| Rule | Detail |
|---|---|
| PHQ-9 item 9 > 0 | **Triggers crisis screen** (S-G14, G-37) regardless of other results |
| PHQ-9 / GAD-7 severity | Spec gives only normal < 5 and §13 "≥ 10 moderate"; intermediate labels (5–9) **not specified** [OPEN] |
| OSA confirmatory | Moderate–severe band → Routine (§13.2) |
| TB | High risk or TB symptoms → Urgent (§13.2). Risk engine T15: TB high (urgent) shown before anaemia high (routine) |
| HF baseline | First 14 days = personal baseline (G-28); no alert before baseline complete [DER] |
| Conditions informed | Not listed per AUD card in Spec (only implied by name). COND_* codes for AUD-03…12 **not specified** [OPEN] |

---

## 9. Movement, touch & vision markers (ALG-MOV, Spec §9)

| Code | Display name | Unit | Dec. | Valid range | Normal (Spec) | Visibility | Source / screen | Tag |
|---|---|---|---|---|---|---|---|---|
| `TAP_COUNT` | Taps (video) | count | 0 | 0–80 | Age norms (to be built) | Displayed | MOV-01 / S-H01 | [DOC] |
| `TAP_FREQ` | Tap frequency | Hz | n/s | n/s | Age norms (to be built) | Displayed | MOV-01 | [DOC] |
| `TAP_DECREMENT` | Amplitude decrement | % | n/s | n/s | **< 20%** | Displayed | MOV-01 | [DOC] |
| `TAP_CV` | Tap variability | % | n/s | n/s | Age norms (to be built) | Displayed | MOV-01 | [DOC] |
| `TOUCH_TAP_COUNT` | Taps (touch) | count | 0 | n/s | Age norms (to be built) | Displayed | MOV-02 / S-H02 | [DOC] |
| `INTER_TAP_CV` | Inter-tap variability | % [DER] | n/s | n/s | Age norms (to be built) | Displayed | MOV-02 | [DOC] |
| `STEPS` | Steps | count | 0 | n/s | — | Displayed | MOV-03 / S-H03 | [DOC] |
| `CADENCE` | Cadence | steps/min | n/s | n/s | — | Displayed | MOV-03 | [DOC] |
| `STEP_CV` | Step variability | % | n/s | n/s | — | Displayed | MOV-03 | [DOC] |
| `GAIT_SPEED` | Gait speed | m/s | n/s | n/s | **≥ 0.8 m/s (older adults)**; other ages not given | Displayed | MOV-03 | [DOC] |
| `STS_COUNT_30S` | Sit-to-stand (30 s) | count | 0 | n/s | Age/sex norms (e.g. **≥ 12 for age 60–64**); full table not provided | Displayed | MOV-04 / S-H04 | [DOC] |
| `TREMOR_FREQ` | Tremor frequency | Hz | n/s | 3–12 analysis band | No peak above noise floor | Displayed | MOV-05 / S-H05 | [DOC] |
| `TREMOR_AMP` | Tremor amplitude | deg/s | n/s | n/s | No peak above noise floor (noise-floor value n/s) | Displayed | MOV-05 | [DOC] |
| `FACE_ASYM_SCORE` | Face asymmetry | — | n/s | 0–1 | Below threshold (**threshold n/s**) | Internal → drives STROKE | MOV-06 / S-H06 | [DOC]/[OPEN] |
| `FACE_ASYM_SIDE` | Weaker side | L/R [DER] | — | — | — | Displayed if positive [DER] | MOV-06 | [DOC] |
| `ARM_DRIFT_L`, `ARM_DRIFT_R` | Arm drift | cm or % of arm length (unit choice n/s) | n/s | n/s | Drift < threshold (**threshold n/s**) | Internal → STROKE | MOV-07 | [DOC]/[OPEN] |
| `SPEECH_ABN_PROB` | Speech abnormality | — | n/s | 0–1 [DER] | Below threshold (**n/s**) | Internal → STROKE | MOV-08 | [DOC]/[OPEN] |
| `STROKE_POSITIVE` | Stroke warning | bool | — | — | **Negative** | Displayed → S-R02 Emergency if positive | MOV-09 | [DOC] |
| `signs[]` | Positive signs | list (face / arm / speech) | — | — | — | Displayed | MOV-09 | [DOC] |
| `LOGMAR_L`, `LOGMAR_R` | Visual acuity | logMAR | n/s (1 [DER]) | −0.3–1.3 | **≤ 0.2** | Displayed | MOV-10 / S-H07 | [DOC] |
| `COLOUR_PLATE_SCORE` | Colour plates | score | 0 | n/s | **All plates correct** | Displayed | MOV-11 / S-H08 | [DOC] |
| `AMSLER_ABNORMAL` | Amsler grid | bool | — | — | **No distortion** | Displayed | MOV-11 / S-H09 | [DOC] |
| `RT_VISUAL_MS` | Visual reaction time | ms | 0 [DER] | n/s | Age norms (to be built) | Displayed | MOV-12 / S-H10 | [DOC] |
| `RT_AUDIO_MS` | Auditory reaction time | ms | 0 [DER] | n/s | Age norms (to be built) | Displayed | MOV-12 | [DOC] |
| `PD_PROB` | Parkinson's probability | — | n/s | 0–1 | — | Not member-facing [OPEN] | MOV-13 | [DOC] |
| `PD_BAND` | Parkinson's signs | enum (labels n/s; §13 "Refer") | — | — | **Low** | Band (G-24) | MOV-13 / S-R01 | [DOC]/[OPEN] |

Risk engine: **Stroke positive → Emergency** (T10, BR-SCR-01). Conditions informed (COND_*) are not listed on MOV cards [OPEN].

---

## 10. Risk-engine outputs (ALG-RSK, Spec §10)

| Code | Meaning | Values | Visibility | Source | Tag |
|---|---|---|---|---|---|
| `band` | Band for a value | per `mst_reference_range` | Displayed (with every result) | RSK-01 | [DOC] |
| `range_version` | Version of reference range used | string | S-I05 / Marker detail footer [DER] | RSK-01 | [DOC] |
| `urgency` | Highest-priority urgency | **emergency > urgent > routine** | Displayed (S-R02 / S-R03 / S-R05) | RSK-02 | [DOC] |
| `rule_codes[]` | Rules fired | e.g. BR-VIT-01 | Diagnostic / audit | RSK-02 | [DOC] |
| `baseline_value` | Personal baseline | median of last 3 valid values within 180 days | Displayed on S-C05 | RSK-03 | [DOC] |
| `baseline_sd` | Personal SD | SD from last 10 values | Internal | RSK-03 | [DOC] |
| `change_flag` | Meaningful change | bool — change > 15% (default) **or** > 2 personal SD | Displayed (trend badge) | RSK-04 | [DOC] |
| `change_pct` | Change % | % | Displayed | RSK-04 | [DOC] |
| `ckd_risk` | Kidney risk score | logistic score (scale/bands n/s) | Shown **only when BP band, diabetes band, waist and history present** | RSK-05 | [DOC]/[OPEN] |
| `mets_risk` | Metabolic risk score | logistic score (scale/bands n/s) | Same as above | RSK-05 | [DOC]/[OPEN] |
| `result_confidence` | Result confidence | 0–1 | Displayed as confidence; **hidden when < 0.6** | RSK-06 | [DOC] |
| `flag_id`, `case_id` | Flag and case | IDs; same condition within 30 days merges into open case | S-R04 / S-R05 | RSK-07 | [DOC] |

---

## 11. Markers without an algorithm card

| Marker | Source | Spec rule | Tag |
|---|---|---|---|
| Temperature (°C) | Smart ring or thermometer (F-33) | §13.1 trigger ≥ 38.0 °C → Urgent if with RR > 20 or SpO2 < 95%; T9: 38.4 °C + RR 22 → **Urgent** (BR-VIT-06). Unit/decimals/valid range/normal band not carded [OPEN] | [DOC]/[OPEN] |
| Fatty-liver / metabolic risk | §13.1 row "Fatty-liver / metabolic risk — High". Whether this equals `mets_risk` (RSK-05) is not stated [OPEN] | [DOC]/[OPEN] |
| Questionnaire scores (Q_TB_SYMPTOMS, Q_MMRC, Q_EXPOSURE, Q_CARIES_RISK) | Inputs to AUD-03/04, DEN-06. Item content and scoring not provided [OPEN] | [DOC]/[OPEN] |

---

## 12. Markers with Reference Ranges "To Be Built" (Never Invented)

Where the Spec states that normal ranges come from future cohorts or unprovided master tables, the Flutter UI **must never invent numeric cut-offs**. Until `mst_reference_range` or `mst_growth_reference` provides approved tables, the UI displays the numeric value (if allowed by G-24) with status badge `"Reference range not yet available"`.

| Marker(s) | Spec Note | UI Fallback Behaviour |
|---|---|---|
| `SDNN`, `RMSSD`, `SD1`, `SD2`, `SD1_SD2`, `LF`, `HF`, `LF_HF` | "Age-band tables in `mst_reference_range` (to be built from Mayura healthy cohort); `pNN50 > 3%` normal" (§4.3) | Display `pNN50` with `> 3%` normal rule; display other HRV metrics with `"Age-band reference range pending cohort"` |
| `PI`, `RISE_TIME`, `NOTCH_TIME`, `NOTCH_REL_H`, `RI`, `AIX`, `WIDTH_25/50/75`, `AREA_RATIO`, `SDPPG_*`, `AGING_INDEX`, `PTT_PROXY` | "Age-band tables (to be built); `VASC_AGE_GAP ≤ 5 years` normal" (§4.8) | Display `VASC_AGE_GAP ≤ 5 years` normal band; other waveform markers show value + `"Age-band reference pending"` |
| `vo2max_est` | "Age/sex table" (§5 FRM-08) | Show value labelled `"estimate"` + `"Age/sex reference table pending"` |
| `haz`, `waz`, `bmiz` | `L, M, S` from `mst_growth_reference` (§5 FRM-12) | Normal range `−2 to +2` is documented; requires `mst_growth_reference` LMS table for calculation (test vector `X=18, L=-0.5, M=16, S=0.08 → 1.43` works directly) |
| `fev1_pred_pct`, `fvc_pred_pct`, `ratio_lln` | GLI-2012 equations (§5 FRM-13) | Requires GLI-2012 lookup coefficients |
| `FLUENCY_COUNT`, `PAUSE_RATE`, `SPEECH_RATE`, `LEXICAL_DIV` | "Age/education norms" (§8 AUD-10) | Show values + `"Age/education norms pending"` |
| `TAP_COUNT`, `TAP_FREQ`, `TAP_CV`, `TOUCH_TAP_COUNT`, `INTER_TAP_CV` | "Age norms; decrement < 20%" (§9 MOV-01/02) | Show `TAP_DECREMENT < 20%` normal band; others `"Age norms pending"` |
| `STS_COUNT_30S` | "Age/sex norms (e.g. ≥ 12 for age 60–64)" (§9 MOV-04) | Apply `≥ 12` for age 60–64; other age bands `"Age/sex norm pending"` |
| `RT_VISUAL_MS`, `RT_AUDIO_MS` | "Age norms" (§9 MOV-12) | Show median ms + `"Age norms pending"` |
| Child & pregnancy ranges (general) | "Adult defaults (children and pregnancy in `mst_reference_range`)" (§1) | Except Anaemia WHO thresholds (§6.1, which are explicitly given for men, non-pregnant women, pregnant women, children 5–11 y, 6–59 m), non-adult ranges require `mst_reference_range` |

---

## 13. Band Colour Semantics & Urgency Mapping

Every band and urgency level maps deterministically to a `BandStyle` semantic token in the design system (`lib/core/design_system/`), pairing colour + icon + text label so colour is never the sole indicator.

| Semantic Token | Band Values Mapped | Urgency Level | Icon | Light Fore / Back |
|---|---|---|---|---|
| `success` | `normal`, `low` (risk/stress/DM/TB/OAD/PD/caries), `regular` (rhythm), `not suspicious` (oral), `no alert` (HF), `negative` (stroke), `all plates correct`, `no distortion` | None | `check_circle_rounded` | `#15803D` / `#DCFCE7` |
| `warning` | `borderline`, `elevated` (BP), `moderate` (stress/caries/OSA), `mild` (OSA), `prediabetes risk`, `at risk` (DFU), `suspicious` (oral), `early/white spot` | `routine` | `warning_amber_rounded` | `#B45309` / `#FEF3C7` |
| `danger` | `critical`, `high` (BP/stress/anaemia/jaundice/cataract/oral/caries/TB/OAD/mood/CKD/MetS), `diabetes risk`, `irregular` (rhythm), `ulcer` (DFU), `severe` (OSA), `refer` / `referable`, `abscess sign`, `alert` (HF) | `urgent` | `error_outline_rounded` | `#B91C1C` / `#FEE2E2` |
| `emergency` | `STROKE_POSITIVE`, SpO2 `< 92%`, HR `< 40` or `> 130`, RR `> 24` or `< 8`, Shock Index `> 0.9`, PHQ-9 item 9 `> 0` (crisis) | `emergency` | `emergency_rounded` | `#FFFFFF` / `#B91C1C` (solid) |
| `neutral` | `notAssessed`, `notAvailable`, `hidden`, `partial` | None | `remove_circle_outline` | `#475569` / `#E2E8F0` |
| `info` | `inValidation` (G-24), `lowConfidence` (`< 0.6` G-23), `needsConfirmation` (1st irregular rhythm scan G-27), `baselineBuilding` (HF `< 14 d` G-28) | None | `info_outline_rounded` | `#1D4ED8` / `#DBEAFE` |

---

## 14. Confirmatory Lab Investigations by Marker (Spec §13)

> **Clinical safety rule [DOC]:** Every screening flag must be confirmed or ruled out by standard investigations. Cut-offs below are commonly used adult guideline values from Spec §13 — the reporting lab's own reference ranges and the treating clinician's judgement take precedence.

### 14.1 Vitals & Pulse Markers (Spec §13.1)

| Marker / Screen | App Screening Trigger | Confirmatory Investigations | Usual Diagnostic Cut-offs | Urgency |
|---|---|---|---|---|
| BP band (SBP/DBP) | Elevated or High | Clinic cuff BP on 2 visits or 24-h ambulatory BP; then serum creatinine + eGFR, urine ACR, fasting glucose / HbA1c, lipid profile, serum Na & K, urine routine, 12-lead ECG | Hypertension: clinic ≥ 140/90 on ≥ 2 visits, 24-h mean ≥ 130/80, home ≥ 135/85 | Routine; **Urgent** if ≥ 180/110 or symptoms |
| Heart rate | Resting > 100 or < 50 bpm | 12-lead ECG, TSH, CBC (Hb), serum electrolytes (K, Mg) | TSH outside lab range (~0.4–4.0 mIU/L); K < 3.5 or > 5.0 mmol/L; Hb below WHO threshold | **Urgent**; **Emergency** if > 130 or < 40 |
| Irregular rhythm | Irregular on 2 scans | 12-lead ECG; 24–48 h Holter or patch ECG; TSH; electrolytes; echocardiogram if confirmed | AF on ECG (irregular R-R, no P waves) | **Urgent** |
| SpO2 band | < 95% (finger) | Medical pulse oximeter; arterial blood gas if < 92%; chest X-ray; CBC | SpO2 < 94% clinically low; PaO2 < 60 mmHg respiratory failure | **Emergency** if < 92% |
| Respiratory rate | > 20 at rest (with fever or low SpO2) | CBC, CRP, chest X-ray; seasonal tests (malaria, dengue NS1) as clinically indicated | WBC > 11,000/µL; CRP > 10 mg/L | **Urgent**; **Emergency** if > 24 |
| Temperature (ring/thermometer) | ≥ 38.0 °C | CBC, CRP, urine routine, seasonal tests, blood culture if indicated | As above | **Urgent** if with RR > 20 or SpO2 < 95% |
| Shock index | > 0.9 | Emergency assessment: CBC, serum lactate, electrolytes, creatinine, blood glucose | Lactate > 2 mmol/L | **Emergency** |
| HRV (low for age) | RMSSD/SDNN below age band, esp. with diabetes | HbA1c; clinical autonomic tests (deep-breathing E:I ratio, lying-to-standing 30:15 ratio, orthostatic BP) | Abnormal autonomic tests per clinic reference | Routine |
| Stress index | High on repeated scans | No lab test required; TSH if persistent tachycardia; PHQ-9 / GAD-7 if mood symptoms | TSH as above | Routine |
| Waveform / vascular age gap | > 10 years above age | Lipid profile, HbA1c, hs-CRP, carotid-femoral PWV, ankle-brachial index (ABI) | LDL ≥ 160 mg/dL (risk-dependent); hs-CRP > 3 mg/L; ABI ≤ 0.90 | Routine |
| Diabetes risk | Prediabetes or diabetes risk | HbA1c, fasting plasma glucose, 75-g OGTT if borderline; then lipid profile, creatinine/eGFR, urine ACR | HbA1c ≥ 6.5% diabetes, 5.7–6.4% prediabetes; FPG ≥ 126 / 100–125 mg/dL; OGTT 2-h ≥ 200 / 140–199 mg/dL | Routine |
| BMI / waist-to-height | BMI ≥ 23 or WHtR ≥ 0.5 | Fasting lipids, fasting glucose / HbA1c, ALT, AST, TSH; liver ultrasound if ALT raised | Metabolic syndrome: TG ≥ 150 mg/dL; HDL < 40 (men) / < 50 (women); FPG ≥ 100 | Routine |
| Orthostatic test | HR rise ≥ 30 or BP fall with dizziness | Orthostatic BP by clinician, ECG, CBC, electrolytes, blood glucose | BP fall ≥ 20/10 mmHg within 3 min = orthostatic hypotension | Routine |
| Kidney risk score | High | Serum creatinine with eGFR, urine ACR, urine routine | eGFR < 60 mL/min/1.73 m² or ACR ≥ 30 mg/g for ≥ 3 months = CKD | Routine |
| Fatty-liver / metabolic risk | High | ALT, AST, GGT, lipid profile, fasting glucose, liver ultrasound; FIB-4 from labs | ALT above lab upper limit; FIB-4 > 2.67 high fibrosis risk | Routine |

### 14.2 Image, Dental, Audio & Movement Screens (Spec §13.2)

| Marker / Screen | App Screening Trigger | Confirmatory Investigations | Usual Diagnostic Cut-offs | Urgency |
|---|---|---|---|---|
| Anaemia | High band | CBC (Hb, MCV, RDW), peripheral smear, serum ferritin, vitamin B12, folate, reticulocyte count; stool occult blood in adults | Hb (WHO): men < 13.0, women < 12.0, pregnancy < 11.0, children 5–11 y < 11.5, 6–59 m < 11.0 g/dL; ferritin < 15 ng/mL (< 30 often used); B12 < 200 pg/mL | Routine; **Urgent** in pregnancy or Hb < 7 g/dL |
| Jaundice (adult) | High band | Serum bilirubin (total & direct), LFTs (ALT, AST, ALP, GGT, albumin), HBsAg, anti-HCV, abdominal ultrasound | Total bilirubin > 1.2 mg/dL raised; visible jaundice ~2.5–3 mg/dL | **Urgent** |
| Newborn jaundice | High band | Serum total bilirubin, blood group & Coombs test, G6PD | Above hour-specific phototherapy line for gestation and age | **Urgent** |
| Cataract | High band | Visual acuity, slit-lamp exam | Lens opacity with VA worse than 6/12 typically considered for surgery | Routine |
| Diabetic retinopathy | Referable | Dilated fundus exam, OCT for macular oedema; HbA1c, BP, lipids, urine ACR | ICDR moderate NPDR or worse, or macular oedema = referable | Routine; **Urgent** if sight-threatening |
| Oral lesion | Suspicious / high risk | Oral-medicine exam; biopsy and histopathology | Dysplasia or squamous cell carcinoma on histology | **Urgent** |
| Dental decay | White spot / cavity | Dentist exam (ICDAS), intraoral X-ray (bitewing / IOPA) as needed | ICDAS 1–2 early; 3–6 cavitated | Preventive / Routine; **Urgent** if swelling |
| Gum disease | High band | Periodontal probing; HbA1c in people with diabetes | Pocket depth ≥ 4 mm or attachment loss | Routine |
| Diabetic foot | At risk / ulcer | Foot exam, 10-g monofilament, ABI / Doppler, wound swab culture if infected, foot X-ray if deep, HbA1c | Loss of protective sensation; ABI ≤ 0.90; osteomyelitis on X-ray | **Urgent** if ulcer |
| Child eye | Refer / white pupil | Paediatric eye exam: cover test, cycloplegic refraction, dilated fundus | Manifest squint; significant refractive error; leukocoria | **Urgent** (white pupil); Routine |
| TB | High risk or TB symptoms | Sputum NAAT (CBNAAT / TrueNat), chest X-ray, sputum smear; HIV test and blood glucose for TB patients | NAAT positive = TB | **Urgent** |
| COPD / asthma | Obstruction risk | Spirometry before & after bronchodilator; CBC with eosinophils; chest X-ray | FEV1/FVC < 0.70 (or < LLN) post-bronchodilator = obstruction; reversibility ≥ 12% and ≥ 200 mL suggests asthma; eosinophils ≥ 300/µL support asthma | Routine |
| Lung function | FEV1/FVC < LLN | As above | As above | Routine |
| Sleep apnoea | Moderate–severe band | Home sleep apnoea test or polysomnography; TSH; fasting glucose | AHI ≥ 5 OSA; ≥ 15 moderate; ≥ 30 severe | Routine |
| Hearing loss | Refer | Pure-tone audiometry, tympanometry, ENT exam | WHO 2021: hearing loss ≥ 20 dB HL in better ear | Routine |
| Stroke signs | Positive | Emergency: non-contrast CT or MRI brain, blood glucose, PT/INR, platelets, ECG | Infarct or haemorrhage on imaging; glucose < 70 mg/dL mimic | **Emergency** |
| Parkinson's signs | Refer | Neurologist examination (clinical diagnosis); B12, TSH to exclude mimics; DaT-SPECT only if uncertain | Clinical criteria | Routine |
| Cognitive decline | Refer | Clinician MoCA; B12, folate, TSH, CBC, glucose, electrolytes, calcium; CT or MRI brain | MoCA < 26 suggests impairment; B12 < 200 pg/mL | Routine |
| Depression / anxiety | High | Clinician assessment, PHQ-9 / GAD-7; TSH, CBC, B12, vitamin D | PHQ-9 ≥ 10 moderate; GAD-7 ≥ 10 moderate; vitamin D < 20 ng/mL deficiency | Routine; **Emergency** if self-harm risk |
| Heart-failure fluid | Alert | NT-proBNP or BNP, echocardiogram, creatinine, electrolytes, chest X-ray, weight | NT-proBNP ≥ 125 pg/mL or BNP ≥ 35 pg/mL (non-acute) supports HF | **Urgent** |
| Growth faltering (child) | z-score < −2 | Paediatric review; CBC, stool exam, thyroid tests as indicated | Height or weight-for-age z < −2 (stunting / underweight) | Routine |
| Skin lesion | Suspicious | Dermatology exam; biopsy if indicated | Histology | **Urgent** if suspected malignancy |

---

## 15. Reference Pairing Windows by Marker (Spec §14)

Pairs outside the maximum gap or broken by an exclusion are graded **D** and used for monitoring only (FRS REF-06). At least 5% of screen-negative members per screen are offered the reference test each month (sampled negatives, FRS REF-03).

| Marker / Screen | Reference Test | Max Gap (Either Direction) | Exclusions (Pair Graded D — Not Used for Training) |
|---|---|---|---|
| Heart rate, respiratory rate, HRV | ECG, chest belt, contact PPG | Simultaneous (study) or ≤ 5 min (device) | Exercise, caffeine or smoking in previous 30 min, unless recorded as context |
| SpO2 band | Medical pulse oximeter | ≤ 5 min | Cold or poorly perfused fingers flagged by oximeter |
| Blood pressure | Validated cuff, mean of 2 readings | ≤ 10 min | Talking or moving between readings |
| Temperature | Medical thermometer | ≤ 15 min | Antipyretic in previous 4 h |
| Irregular rhythm | 12-lead ECG or patch/Holter | ECG ≤ 1 h; Holter starting ≤ 7 days | Negative label needs ≥ 24 h Holter, not single ECG |
| Diabetes risk | HbA1c (lab) | ≤ 30 days | Pregnancy, transfusion in previous 3 months, known Hb variant, new diabetes treatment between scan and test |
| Diabetes risk (fasting) | Fasting plasma glucose | ≤ 7 days | Not fasting ≥ 8 h; acute illness |
| Vascular age / stiffness | Lipid profile, PWV, ABI | ≤ 30 days | New lipid or BP medicine between scan and test |
| Anaemia | CBC haemoglobin | ≤ 7 days | Transfusion, iron infusion or acute bleeding between scan and test |
| Jaundice (adult) | Serum bilirubin | ≤ 2 days | — |
| Newborn jaundice | Serum or transcutaneous bilirubin | ≤ 6 hours | Phototherapy between scan and test |
| Kidney risk | Creatinine/eGFR, urine ACR | ≤ 30 days | Acute illness or dehydration at test |
| Fatty liver / metabolic | ALT, AST, ultrasound | ≤ 30 days | — |
| Dental decay, gum disease | Dentist exam (ICDAS) | ≤ 14 days | Dental treatment between scan and exam |
| Oral lesion | Oral-medicine exam; biopsy | Exam ≤ 14 days; biopsy ≤ 60 days (biopsy overrides exam) | Treatment between scan and exam |
| Cataract | Slit-lamp exam | ≤ 90 days | Eye surgery between scan and exam |
| Diabetic retinopathy | Dilated fundus exam / OCT | ≤ 90 days | Laser or injection treatment between |
| Child eye | Paediatric eye exam | ≤ 30 days | Glasses or patching started between |
| Diabetic foot | Clinician foot exam | ≤ 3 days | Wound treatment between |
| TB | Sputum NAAT | ≤ 14 days | TB treatment started before sample |
| COPD / asthma, lung function | Spirometry (post-bronchodilator for obstruction) | ≤ 14 days | Exacerbation or new inhaler between |
| Sleep apnoea | Polysomnography or home sleep test | ≤ 60 days | Started CPAP or ≥ 5% weight change between |
| Hearing | Pure-tone audiometry | ≤ 30 days | Ear infection or wax removal between |
| Cognition | Clinician MoCA | ≤ 30 days | Acute illness, delirium, sedating medicine change |
| Mood | PHQ-9 / GAD-7 with clinician | ≤ 7 days | — |
| Heart-failure fluid | NT-proBNP / BNP, clinician assessment | ≤ 3 days | Diuretic change between |
| Stroke signs | Brain imaging and neurologist | Same day | — |
| Parkinson's signs | Neurologist diagnosis | ≤ 90 days | — |
