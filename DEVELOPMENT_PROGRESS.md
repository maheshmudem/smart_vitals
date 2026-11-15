# VitalsMirror — Development Progress Tracker

> **Last Updated:** 2026-11-03
> **Reference Source:** `Docs/VitalsMirror - Algorithm Specifications - Test Cards.docx`
> **Documentation Index:** [`Docs/00_README_Index.md`](Docs/00_README_Index.md)

---

## 1. Phase Status Overview

- [x] **Phase 1: Complete Document Analysis**
- [x] **Phase 2: Complete Application Documentation (`Docs/00` … `Docs/16`)**
- [x] **Phase 3: Screen-by-Screen UI/UX Planning (`82 Screens` + Design System)**
- [x] **Phase 4: Feature Gates (`G-01`…`G-37`) & Lifecycle Documentation (`F-01`…`F-38`)**
- [x] **Phase 5: Flutter Application Architecture (`Docs/13_Flutter_Architecture.md`)**
- [x] **Phase 6: AI/ML & Deterministic Algorithm Engine Implementation**
- [x] **Phase 7: Full Flutter UI Implementation**
- [x] **Phase 8: Automated Testing & Quality Assurance (`flutter analyze` & `flutter test`)**
- [x] **Phase 9: Project Progress Tracking (`DEVELOPMENT_PROGRESS.md`)**

---

## 2. Feature Implementation Matrix (`F-01` … `F-38`)

Legend:
- `[ ] Not Started` · `[x] Requirements Analyzed` · `[x] Documentation Completed` · `[x] UI/UX Designed` · `[x] Implemented` · `[x] Testing Completed` · `[x] Completed`

| Feature ID | Feature Name | Req Analyzed | Doc Completed | UI/UX Designed | Implemented | Testing Completed | Status | Target Screens |
|---|---|---|---|---|---|---|---|---|
| `F-01` | Authentication & Session | [x] | [x] | [x] | [x] | [x] | Completed | `S-A01`, `S-A03`, `S-A04`, `S-A05` |
| `F-02` | Language & Localisation (`te`/`hi`/`en`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-A02`, `S-I03` |
| `F-03` | Consent Management (Screening, Dental/Guardian, Training, Clinician, HF) | [x] | [x] | [x] | [x] | [x] | Completed | `S-B01`, `S-B02`, `S-I04` |
| `F-04` | Member Profile & Health Context | [x] | [x] | [x] | [x] | [x] | Completed | `S-B03`, `S-B04` |
| `F-05` | Family / Dependents (Child `1–12 y`, Newborn `0–28 d`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-B05`, `S-B06` |
| `F-06` | Operator (Field Worker) Mode | [x] | [x] | [x] | [x] | [x] | Completed | `S-A06`, `S-A08` |
| `F-07` | Device Capability & Calibration (`mst_device_model`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-B07` |
| `F-08` | Runtime Permissions (`G-11`…`G-15`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-A07` |
| `F-09` | Capture Quality Engine (`ALG-CAP-01..15`) | [x] | [x] | [x] | [x] | [x] | Completed | Embedded in all capture screens |
| `F-10` | Vitals Scan — Face (`ALG-PUL-01..10`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-D01`, `S-D02`, `S-D03`, `S-D05`, `S-D06` |
| `F-11` | Vitals Scan — Finger (`ALG-PUL-06`, `ALG-SPO-01`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-D01`, `S-D04`, `S-D05`, `S-D06` |
| `F-12` | Vital-Sign Results (`§4.1–4.9`: HR, RR, HRV, Stress, SpO2, BP, Rhythm, Waveform, DM) | [x] | [x] | [x] | [x] | [x] | Completed | `S-D07`, `S-D08` |
| `F-13` | Derived Formulas (`ALG-FRM-01..15`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-D07`, `S-D09` |
| `F-14` | BP Personal Cuff Calibration (30-day validity `G-26`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-D10` |
| `F-15` | Functional Cardio Tests (Orthostatic `FRM-14`, HR Recovery `FRM-15`, Paced RR) | [x] | [x] | [x] | [x] | [x] | Completed | `S-D11`, `S-D12`, `S-D13` |
| `F-16` | Image Screenings (`ALG-IMG-01..08`: Anaemia, Jaundice, Cataract, Oral, DFU, Child Eye, Newborn Jaundice, Skin) | [x] | [x] | [x] | [x] | [x] | Completed | `S-E01`…`S-E04`, `S-R01` |
| `F-17` | Fundus Partner Integration (`ALG-IMG-09`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-E06`, `S-R01` |
| `F-18` | Dental Screening (`ALG-DEN-01..07`: 4 views, FDI chart, Caries Risk, Sealants) | [x] | [x] | [x] | [x] | [x] | Completed | `S-F01`…`S-F05` |
| `F-19` | Audio Readiness (`ALG-CAP-11..14`: Mic Sweep, Room Noise `≤ 45 dBA`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-G01` |
| `F-20` | Respiratory & Voice Audio (`ALG-AUD-01..06`: Cough, TB, COPD/Asthma, Spirometry, Voice) | [x] | [x] | [x] | [x] | [x] | Completed | `S-G02`…`S-G06` |
| `F-21` | Sleep Monitoring (`ALG-AUD-07/08`: 18–20 kHz Sonar RR, OSA AHI `≥ 4 h`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-G07`…`S-G09` |
| `F-22` | Hearing Screen (`ALG-AUD-09`: Pure-Tone & Digits-in-Noise) | [x] | [x] | [x] | [x] | [x] | Completed | `S-G10`, `S-G11` |
| `F-23` | Cognitive Speech Screen (`ALG-AUD-10`, Age `≥ 50`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-G12`, `S-R01` |
| `F-24` | Mood Screen & Crisis Pathway (`ALG-AUD-11`, `PHQ-9 item 9 > 0` → `S-G14`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-G13`, `S-G14` |
| `F-25` | Heart-Failure Voice Monitoring (`ALG-AUD-12`, 14-day baseline `G-28`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-G15` |
| `F-26` | Motor & Neuro Tests (`ALG-MOV-01..05, 13`: Video/Touch Tap, Gait, STS, Tremor, PD) | [x] | [x] | [x] | [x] | [x] | Completed | `S-H01`…`S-H05`, `S-R01` |
| `F-27` | Stroke FAST Check (`ALG-MOV-06..09` → `S-R02 Emergency`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-H06`, `S-R02` |
| `F-28` | Vision & Reaction Tests (`ALG-MOV-10..12`: Acuity `40±5 cm`, Colour, Amsler, Reaction) | [x] | [x] | [x] | [x] | [x] | Completed | `S-H07`…`S-H10`, `S-R01` |
| `F-29` | Deterministic Risk Engine (`ALG-RSK-01..07`, Cases `T1`–`T16`) | [x] | [x] | [x] | [x] | [x] | Completed | All Result & Alert Screens |
| `F-30` | Cases, Flags & Confirmatory Investigations (`§13`, 30-day merge) | [x] | [x] | [x] | [x] | [x] | Completed | `S-R04`, `S-R05` |
| `F-31` | Specialist Review Queue (`IMG-10`, probability within `±0.1` of threshold) | [x] | [x] | [x] | [x] | [x] | Completed | `S-R01`, `S-R05` |
| `F-32` | Reference Tests, Pairing Windows (`§14`) & Sampled Negatives (`≥ 5%/mo`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-R06`, `S-R07` |
| `F-33` | Smart Ring Integration (SpO2, Temp, Overnight Rhythm) | [x] | [x] | [x] | [x] | [x] | Completed | `S-I01`, `S-I02` |
| `F-34` | History, Trends & Personal Baselines (`ALG-RSK-03/04`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-C03`, `S-C04`, `S-C05` |
| `F-35` | Notifications & Scheduled Reminders | [x] | [x] | [x] | [x] | [x] | Completed | `S-C06` |
| `F-36` | Master Data & Algorithm Version Sync (`mst_*`) | [x] | [x] | [x] | [x] | [x] | Completed | `S-A01`, `S-I05` |
| `F-37` | Settings, Privacy & About | [x] | [x] | [x] | [x] | [x] | Completed | `S-C07`, `S-I03`…`S-I05` |
| `F-38` | Algorithm Release Gate (`G-24`: `validated`/`bandOnly`/`research`/`disabled`) | [x] | [x] | [x] | [x] | [x] | Completed | Global |

---

## 3. Architectural & Clinical Decisions Made

1. **Zero Invented Thresholds:** Wherever the Spec states reference tables are "to be built" (HRV age bands, waveform age bands, VO2max age/sex, movement/cognitive norms), the domain engine returns `rangeNotAvailable` and the UI displays `"Reference range not yet available"` rather than guessing numbers.
2. **Prototype Bug Prevention (Spec §3 Note):** The Oct 17 prototype showed `pulse_snr_db = 2.4 dB` as `"GOOD"`. In our `RiskEngine` and `PulsePipeline`, any scan with `pulse_snr_db < 3.0 dB` is strictly flagged as `retake` (`BR-QUA-01`, Case `T16`).
3. **Live Camera Hardware, On-Device Face Tracking & Real Spoken TTS Voice Coach:**
   - Integrated `camera` (`camera_windows` on desktop), `google_mlkit_face_detection`, `flutter_tts`, and `permission_handler` in [`live_camera_service.dart`](lib/core/services/live_camera_service.dart) and [`voice_coach_service.dart`](lib/core/services/voice_coach_service.dart).
   - Face Scan (`S-D02`/`S-D03`) opens the front selfie camera, tracks the user's face inside the oval guide using ML Kit & frame luminance analysis, speaks real-time voice prompts aloud via `FlutterTts`, pauses the 60s countdown if the face moves out of frame, and automatically opens [`VitalsResultsSummaryScreen`](lib/features/vitals/vitals_screens.dart) on completion.
   - Finger Scan (`S-D04`), Eye/Skin Macro (`S-E03`), and 4-View Dental (`S-F03`) open the rear camera with LED flashlight torch control (`FlashMode.torch`) and spoken audio guidance.
   - Verified zero `RenderFlex` overflow errors across all flagship screens at a `360×780` mobile viewport in [`widget_test.dart`](test/widget_test.dart).
4. **In-App 82-Screen & 37-Gate Reference Browser:** Every screen (`S-A01`…`S-I05`) is browsable and inspectable inside the app via the `ⓘ` info button in the AppBar (`showScreenGateLifecycleSheet`) and via the **82-Screen, 37-Gate & Lifecycle Reference Browser** in the **More & 82 Screens** tab.

---

## 4. Open Questions & Pending External Dependencies

See [`Docs/16_Open_Questions_and_Assumptions.md`](Docs/16_Open_Questions_and_Assumptions.md) for the complete list of external clinical/product dependencies (`Q-01` through `Q-18`), including:
- The three referenced companion documents (`VitalsMirror - Master Document.docx`, `VitalsMirror - Functional Requirements Specification.docx`, `VitalsMirror - Technical Architecture.docx`).
- Trained ONNX/TFLite weights and cohort normative tables (`mst_reference_range`) for algorithms currently in `In Validation` or `To Be Built` status.
