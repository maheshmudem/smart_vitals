# VitalsMirror — Project Documentation Index & ID Registry

> **Read this first.** This folder is the permanent technical reference for the VitalsMirror Flutter application.
> Every other document uses the IDs defined here (Features `F-xx`, Screens `S-xx`, Gates `G-xx`, Algorithms `ALG-xxx`).
> If you have a doubt about *any* screen, feature, gate or reading — find its ID here, then open the linked document.

---

## 1. Source of truth

| Item | Value |
|---|---|
| Primary reference | `Docs/VitalsMirror - Algorithm Specifications - Test Cards.docx` (Oct 18, 2026 · Dr Hanu Yedluri) — referred to as **"the Spec"** |
| Spec sections | §1 Card template · §2 Capture checks (ALG-CAP) · §3 Pulse pipeline (ALG-PUL) · §4 Vitals & rhythm cards · §5 Formulas (ALG-FRM) · §6 Image screens (ALG-IMG) · §7 Dental (ALG-DEN) · §8 Audio (ALG-AUD) · §9 Movement/touch/vision (ALG-MOV) · §10 Risk engine (ALG-RSK) · §11 Test datasets · §12 Reference links · §13 Lab investigations · §14 Reference pairing windows |
| Documents referenced by the Spec but **NOT provided** | *Master Data, Algorithms & Data Dictionary* · *FRS* (Functional Requirements Spec — e.g. FRS 12.4, REF-03, REF-06) · *Algorithm Accuracy Register* · rule catalogue (BR-VIT-xx, BR-SCR-xx, BR-QUA-xx, BR-DEN) |
| Organisation | Mayura (study data, healthy cohort, ethics-approved internal studies) |

> [!IMPORTANT]
> The Spec is an **algorithm specification**, not a UI/product spec. It does not define login, subscription, navigation, or visual design.
> Everything in these docs is tagged so you always know how firm it is (see §2).

---

## 2. Requirement provenance tags (used in every document)

| Tag | Meaning | Can we build it? |
|---|---|---|
| **[DOC]** | Explicitly stated in the Spec (section reference given, e.g. *Spec §4.6*) | Yes — must match exactly |
| **[DER]** | Derived — not written as a UI requirement, but *required* to execute a documented workflow (e.g. a capture screen for a documented capture) | Yes — UI design is ours, behaviour follows the Spec |
| **[STD]** | Standard production-app infrastructure (splash, sign-in, settings) not mentioned in the Spec | Yes, as a replaceable baseline — **must be confirmed against FRS** |
| **[OPEN]** | Unclear / missing information — listed in `16_Open_Questions_and_Assumptions.md` | UI shell only, behind a flag; never presented as finished |
| **[MOCK]** | Implemented with mock data/model because backend or trained model is unavailable | UI + contract only; clearly marked in code (`// MOCK:`) |

**Medical safety rule:** No threshold, formula, band, or output is invented. Values come from the Spec. Where the Spec says *"to be built"* (e.g. HRV age-band tables), the UI shows *"Reference range not yet available"* — never a guessed range. No result is labelled a diagnosis; all outputs are **screening bands** with a recommended confirmatory test (Spec §13).

---

## 3. Document map

| # | Document | Answers the question… |
|---|---|---|
| 00 | `00_README_Index.md` | Where is everything? What does ID X mean? |
| 01 | `01_Project_Overview.md` | What is VitalsMirror, why does it exist, who is it for? |
| 02 | `02_Application_Requirements.md` | What must the app do (functional & non-functional)? |
| 03 | `03_User_Roles_and_Permissions.md` | Who uses the app and what can each role do? |
| 04 | `04_Feature_Analysis.md` | For each feature: what/why/who/inputs/how/outputs/dependencies |
| 05 | `05_UI_UX_Screen_Documentation.md` | **Every screen** — layout, data, interactions, states, navigation + design system |
| 06 | `06_User_Flows_and_Navigation.md` | How does the user move between screens? Route map |
| 07 | `07_Feature_Lifecycle_and_States.md` | **Every gate and state machine** — prerequisites, transitions, failures, retries |
| 08 | `08_Health_Readings_and_Metrics.md` | Every reading: code, unit, valid range, decimals, normal/borderline/critical bands |
| 09 | `09_AI_ML_Algorithm_Documentation.md` | Every algorithm: inputs, steps, parameters, location, acceptance, fallback, UI display |
| 10 | `10_API_and_Backend_Integration.md` | Backend contracts, master-data sync, partner APIs, device integrations |
| 11 | `11_Data_Models_and_Entities.md` | Entities, fields, enums, master tables |
| 12 | `12_Error_Handling_and_Validation.md` | Every error/validation rule and its user message |
| 13 | `13_Flutter_Architecture.md` | Project structure, layers, state management, routing, design system code |
| 14 | `14_Development_Roadmap.md` | Phases, milestones, order of implementation |
| 15 | `15_Testing_Strategy.md` | Unit/widget/integration tests incl. Spec test vectors |
| 16 | `16_Open_Questions_and_Assumptions.md` | What is unknown and what we assumed |
| — | `../DEVELOPMENT_PROGRESS.md` | Live status of every feature |

---

## 4. Feature registry (F-xx)

| ID | Feature | Tag | Spec source | Main screens |
|---|---|---|---|---|
| F-01 | Authentication & Session | STD | — | S-A04, S-A05 |
| F-02 | Language & Localisation (Telugu / Hindi / English) | DER | §8 AUD-10 (te/hi/en speech) | S-A02, S-I03 |
| F-03 | Consent Management (screening, dental/guardian, training, clinician pathway) | DOC | §6, §7.1, §8 AUD-11, §11.2 | S-B01, S-B02, S-I04 |
| F-04 | Member Profile & Health Context | DOC | §4.6, §4.9, §5, §6.1, §6.4, §8 AUD-05/10 | S-B03, S-B04 |
| F-05 | Family / Dependents (child, newborn) | DER | §6.6, §6.7, §7 (child mode), §5 FRM-12 | S-B05, S-B06 |
| F-06 | Operator (Field Worker) Mode | DER/OPEN | §7.1 "parent vs operator", §6.4 "untrained photographers", schools/anganwadis | S-A06, S-A08 |
| F-07 | Device Capability & Calibration | DOC | §2 CAP-11/15, §4.5 mst_device_model, §4.8 fps | S-B07 |
| F-08 | Runtime Permissions | DER | camera, mic, motion sensors (§9 intro), Bluetooth | S-A07 |
| F-09 | Capture Quality Engine (ALG-CAP-01…15) | DOC | §2 | embedded in all capture screens |
| F-10 | Vitals Scan — Face (rPPG) | DOC | §3, §4 | S-D01…S-D06 |
| F-11 | Vitals Scan — Finger (contact PPG + SpO2) | DOC | §3 PUL-06, §4.5 | S-D04 |
| F-12 | Vital-Sign Results (HR, RR, HRV, Stress, SpO2, BP, Rhythm, Waveform/Vascular age, Diabetes risk) | DOC | §4.1–4.9 | S-D07, S-D08 |
| F-13 | Derived Formulas (ALG-FRM-01…15) | DOC | §5 | S-D07, S-D09 |
| F-14 | BP Personal Cuff Calibration | DOC | §4.6 | S-D10 |
| F-15 | Functional Cardio Tests (orthostatic, HR recovery, paced breathing) | DOC/DER | §5 FRM-14/15, §4.2 | S-D11, S-D12, S-D13 |
| F-16 | Image Screens (anaemia, jaundice, cataract, oral, foot, child eye, newborn jaundice, skin) | DOC | §6.1–6.8 | S-E01…S-E04, S-R01 |
| F-17 | Fundus Partner Integration (DR / glaucoma) | DOC | §6.8 IMG-09 | S-E06 |
| F-18 | Dental Screening | DOC | §7 | S-F01…S-F05 |
| F-19 | Audio Readiness (mic check, noise, clipping, AV sync) | DOC | §2 CAP-11…14, §8 intro | S-G01 |
| F-20 | Respiratory & Voice Audio (cough/TB, obstruction, lung function, voice) | DOC | §8 AUD-01…06 | S-G02…S-G06 |
| F-21 | Sleep Monitoring (sonar RR, apnoea) | DOC | §8 AUD-07/08 | S-G07…S-G09 |
| F-22 | Hearing Screen | DOC | §8 AUD-09 | S-G10, S-G11 |
| F-23 | Cognitive Speech Screen | DOC | §8 AUD-10 | S-G12 |
| F-24 | Mood Screen & Crisis Pathway | DOC | §8 AUD-11 | S-G13, S-G14 |
| F-25 | Heart-Failure Voice Monitoring | DOC | §8 AUD-12 | S-G15 |
| F-26 | Motor & Neuro Tests (tapping, gait, sit-to-stand, tremor, Parkinson's score) | DOC | §9 MOV-01…05, 13 | S-H01…S-H05 |
| F-27 | Stroke FAST Check | DOC | §9 MOV-06…09 | S-H06, S-R02 |
| F-28 | Vision & Reaction Tests (acuity, colour, Amsler, reaction time) | DOC | §9 MOV-10…12 | S-H07…S-H10 |
| F-29 | Risk Engine (bands, urgency, baseline, change, organ risk, confidence, aggregation) | DOC | §10 | all results |
| F-30 | Cases, Flags & Confirmatory Investigations | DOC | §10 RSK-07, §13 | S-R04, S-R05 |
| F-31 | Specialist Review (IMG-10) | DOC (referenced) | §6 intro | state on S-R01/S-R05 |
| F-32 | Reference Tests & Pairing (lab results, sampled negatives) | DOC/OPEN | §13, §14, FRS REF-03/06 | S-R06, S-R07 |
| F-33 | Smart Ring Integration | DOC (referenced) | §4.5, §4.7, §8 AUD-08, §13 temperature | S-I01, S-I02 |
| F-34 | History, Trends & Personal Baselines | DER | §10 RSK-03/04, §7 DEN-07 | S-C03, S-C04, S-C05 |
| F-35 | Notifications & Reminders | DER | foot monthly (§6.5), HF daily (§8 AUD-12), confirmation scan (§4.7) | S-C06 |
| F-36 | Master Data & Algorithm Version Sync | DOC | §1 (mst_* tables, change control) | S-A01, S-I05 |
| F-37 | Settings, Privacy & About | STD | — | S-I03, S-I04, S-I05 |
| F-38 | Algorithm Release Gate (validated / band-only / research / disabled) | DOC | §4 intro, §4.5, §4.6, §8 AUD-11 | all results |

---

## 5. Screen registry (S-xx)

| Group | ID | Screen | Tag |
|---|---|---|---|
| **A. Access** | S-A01 | Splash & Bootstrap | STD |
| | S-A02 | Language Selection | DER |
| | S-A03 | Welcome / Intro | STD |
| | S-A04 | Sign In (mobile number) | STD/OPEN |
| | S-A05 | OTP Verification | STD/OPEN |
| | S-A06 | Mode Selection (Member / Operator) | DER/OPEN |
| | S-A07 | Permissions Primer | DER |
| | S-A08 | Operator — Participant Search & Register | OPEN |
| **B. Consent & Profile** | S-B01 | Consent Center | DOC |
| | S-B02 | Consent Detail & Sign (incl. guardian) | DOC |
| | S-B03 | Profile Setup — Basics | DOC |
| | S-B04 | Health Context | DOC |
| | S-B05 | Family Members | DER |
| | S-B06 | Add / Edit Dependent | DER |
| | S-B07 | Device Readiness Check | DOC |
| **C. Main Shell** | S-C01 | Home Dashboard | DER |
| | S-C02 | Screenings Catalogue | DER |
| | S-C03 | History | DER |
| | S-C04 | Session Detail | DER |
| | S-C05 | Trends & Baselines | DOC/DER |
| | S-C06 | Notifications Inbox | DER |
| | S-C07 | Profile & More | STD |
| **D. Vitals** | S-D01 | Vitals Scan Setup (mode choice) | DOC |
| | S-D02 | Pre-Scan Context Check | DOC |
| | S-D03 | Face Scan Capture | DOC |
| | S-D04 | Finger Scan Capture | DOC |
| | S-D05 | Signal Processing | DOC |
| | S-D06 | Retake Guidance | DOC |
| | S-D07 | Vitals Results Summary | DOC |
| | S-D08 | Marker Detail | DOC |
| | S-D09 | Body & Fitness Metrics | DOC |
| | S-D10 | BP Cuff Calibration | DOC |
| | S-D11 | Orthostatic Test | DOC |
| | S-D12 | HR Recovery Test | DOC |
| | S-D13 | Paced-Breathing Retake | DOC |
| **E. Image** | S-E01 | Image Screen Intro (template) | DOC |
| | S-E02 | Colour Card Setup | DOC |
| | S-E03 | Guided Image Capture (template) | DOC |
| | S-E04 | Capture Review | DER |
| | S-E06 | Fundus Camera Connect & Capture | DOC |
| **F. Dental** | S-F01 | Dental Intro & Consent | DOC |
| | S-F02 | Caries-Risk Questionnaire | DOC |
| | S-F03 | Dental 4-View Capture | DOC |
| | S-F04 | Dental Results & Tooth Chart | DOC |
| | S-F05 | Tooth Detail | DOC |
| **G. Audio** | S-G01 | Audio Readiness Check | DOC |
| | S-G02 | Respiratory Questionnaires | DOC |
| | S-G03 | Cough Task | DOC |
| | S-G04 | Voice Tasks | DOC |
| | S-G05 | Forced Exhale (Lung Function) | DOC |
| | S-G06 | Respiratory & Voice Results | DOC |
| | S-G07 | Sleep Setup | DOC |
| | S-G08 | Sleep Monitoring (night mode) | DOC |
| | S-G09 | Sleep Report | DOC |
| | S-G10 | Hearing Test | DOC |
| | S-G11 | Hearing Results | DOC |
| | S-G12 | Cognitive Speech Tasks | DOC |
| | S-G13 | Mood Check | DOC |
| | S-G14 | Crisis Support | DOC |
| | S-G15 | Heart-Failure Voice Daily Check | DOC |
| **H. Movement & Vision** | S-H01 | Finger Tapping — Video | DOC |
| | S-H02 | Finger Tapping — Touch | DOC |
| | S-H03 | Gait Walk Test | DOC |
| | S-H04 | Sit-to-Stand Test | DOC |
| | S-H05 | Tremor Test | DOC |
| | S-H06 | Stroke Check (FAST) | DOC |
| | S-H07 | Visual Acuity | DOC |
| | S-H08 | Colour Vision | DOC |
| | S-H09 | Amsler Grid | DOC |
| | S-H10 | Reaction Time | DOC |
| **R. Results & Risk** | S-R01 | Screening Result (shared template) | DOC |
| | S-R02 | Emergency Alert | DOC |
| | S-R03 | Urgent Action / Rescan Prompt | DOC |
| | S-R04 | Cases List | DOC |
| | S-R05 | Case Detail & Confirmatory Tests | DOC |
| | S-R06 | Lab / Reference Result Entry | OPEN |
| | S-R07 | Reference Test Invitation | DOC |
| **I. Devices & Settings** | S-I01 | Connected Devices | DOC |
| | S-I02 | Ring Pairing | DOC/OPEN |
| | S-I03 | Settings | STD |
| | S-I04 | Consent & Privacy Management | DOC/STD |
| | S-I05 | About, Algorithm Versions & Disclaimers | DOC |

*(S-E05 intentionally unused — image results use the shared S-R01 template.)*

---

## 6. Gate registry (G-xx)

A **gate** is a condition that must be true before a feature can start, continue, or display a result. Full behaviour in `07_Feature_Lifecycle_and_States.md`.

| ID | Gate | Type | Tag | Spec source |
|---|---|---|---|---|
| G-01 | Authenticated session | Access | STD | — |
| G-02 | Basic profile complete (DOB/age, sex, height, weight) | Data | DOC | §4.6, §5 |
| G-03 | Extended profile (waist, family history, activity, pregnancy) | Data | DOC | §4.9, §10 RSK-05, §6.1 |
| G-04 | Screening consent | Consent | DOC | §6 intro |
| G-05 | Dental consent (guardian for children) | Consent | DOC | §7.1 |
| G-06 | Training-data consent (non-blocking) | Consent | DOC | §11.2 |
| G-07 | Clinician pathway active (mood) | Access | DOC | §8 AUD-11 |
| G-08 | Heart-failure programme enrolment | Access | DOC | §8 AUD-12 |
| G-09 | Age eligibility per screen | Eligibility | DOC | §6, §7, §8, §9 |
| G-10 | Condition/history eligibility (diabetes, tobacco, etc.) | Eligibility | DOC | §6.4, §6.5 |
| G-11 | Camera permission | Permission | DER | — |
| G-12 | Microphone permission | Permission | DER | — |
| G-13 | Motion-sensor permission/availability | Permission | DOC | §9 intro |
| G-14 | Notification permission (non-blocking) | Permission | DER | — |
| G-15 | Bluetooth / nearby-devices permission | Permission | DER | ring, fundus |
| G-16 | Device model supported (mst_device_model) | Device | DOC | §4.5, CAP-11, CAP-15 |
| G-17 | Microphone self-check passed (CAP-11) | Device | DOC | §2, §8 |
| G-18 | Room noise ≤ 45 dBA (CAP-12) | Environment | DOC | §2, §8 |
| G-19 | Earphones connected | Device | DOC | §8 AUD-09 |
| G-20 | Colour card detected (required / preferred per screen) | Capture | DOC | CAP-10, §6 |
| G-21 | Capture quality passed (CAP checks) | Capture | DOC | §2 |
| G-22 | Signal quality passed (PUL-09, beat counts) | Processing | DOC | §3, §4 |
| G-23 | Result confidence ≥ 0.6 (RSK-06) | Display | DOC | §10 |
| G-24 | Algorithm release status allows display | Display | DOC | §4 intro, §4.6 |
| G-25 | Retake limit (max 3) | Flow | DOC | §4.1, §6 intro |
| G-26 | BP calibration validity (≤ 30 days) | Data | DOC | §4.6 |
| G-27 | Confirmation required (rhythm: 2 scans or 1 + ring) | Flow | DOC | §4.7 |
| G-28 | Baseline available (RSK-03; HF 14 days) | Data | DOC | §10, §8 AUD-12 |
| G-29 | Input completeness for formulas | Data | DOC | §5 intro |
| G-30 | Phone charging & placed (sleep) | Environment | DOC | §8 AUD-07 |
| G-31 | Partner fundus device connected | Device | DOC | §6.8 |
| G-32 | Ring connected (optional enhancer) | Device | DOC | §4.5, §4.7, §8 AUD-08 |
| G-33 | Face distance 40 ± 5 cm (vision) | Capture | DOC | CAP-15, MOV-10 |
| G-34 | Schedule / frequency (foot monthly, HF daily) | Flow | DOC | §6.5, §8 AUD-12 |
| G-35 | Subscription / entitlement | Access | OPEN | not in Spec |
| G-36 | Network connectivity (sync / server inference) | System | STD/OPEN | — |
| G-37 | Safety escalation override (emergency / crisis) | Safety | DOC | §8 AUD-11, §10 |

---

## 7. Glossary

| Term | Meaning |
|---|---|
| rPPG | Remote photoplethysmography — pulse from colour changes in face video |
| BVP | Blood-volume pulse waveform |
| ROI | Region of interest (7 facial polygons) |
| IBI | Inter-beat interval (ms) |
| SNR | Signal-to-noise ratio (dB) |
| Band | Screening category (e.g. normal / borderline / critical; low / moderate / high) |
| Marker | A single output value (e.g. `HR`, `RMSSD`, `BP_BAND`) |
| Condition (`COND_*`) | A health condition code from `mst_condition` that markers inform |
| Case | One open follow-up record per condition (merged within 30 days) |
| Urgency | emergency > urgent > routine (ALG-RSK-02) |
| Member | Person being screened |
| Guardian | Adult consenting for a child |
| Operator | Trained field worker capturing for members (schools, anganwadis, clinics) |
| mst_* | Master-data tables changeable only via change control |
| FDI | Tooth numbering system (11–48 permanent, 51–85 primary) |
| Colour card | Physical 24-patch calibration card used for colour correction |
