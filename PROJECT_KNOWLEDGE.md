# VitalsMirror (`algoritam`) — Complete Project Knowledge Base

> **Audience:** AI coding agents, tools, and engineers onboarding onto or modifying **VitalsMirror** (`package:algoritam`).
> **Purpose:** Single authoritative code-grounded map of the entire Flutter project — clinical safety rules, ID registries, strict naming conventions, actual directory layout, every domain entity/algorithm/service/screen, end-to-end data & navigation flows, and step-by-step extension playbooks.
> **Companion files:**
> - [AGENTS.md](file:///d:/algoritam/AGENTS.md) — Concise AI agent entry-point & guardrails.
> - [Docs/00_README_Index.md](file:///d:/algoritam/Docs/00_README_Index.md) — Clinical specification index & ID registry (`F-xx`, `S-xx`, `G-xx`, `ALG-xxx`).
> - [DEVELOPMENT_PROGRESS.md](file:///d:/algoritam/DEVELOPMENT_PROGRESS.md) — Feature implementation tracker (`F-01`..`F-38`).

---

## 1. Project Identity & Clinical Safety Rules

| Property | Value (Verified from Codebase) |
|---|---|
| **App Name** | VitalsMirror — Clinical & Wellness Screening |
| **Package Name** | `algoritam` (`version: 1.0.0+1`, `publish_to: 'none'`) |
| **Toolchain** | Flutter `3.44.9` (stable), Dart SDK `^3.12.2`, `flutter_lints: ^6.0.0` |
| **Primary Spec** | `Docs/VitalsMirror — Algorithm Specifications - Test Cards.docx` (Oct 18, 2026 · Dr Hanu Yedluri, Mayura) + 17 markdown docs in `Docs/00..16` |
| **Architecture Style** | Feature-first Clean Architecture: `AppState` (`ChangeNotifier`) + `AppStateScope` (`InheritedNotifier`) — zero third-party state-management bloat |
| **Codebase Scale** | `136` Dart files under `lib/`, `18` test files under `test/`, `14` generated WAV assets under `assets/audio/` |

### 1.1 Requirement Provenance Tags
Every feature, screen, and threshold in `Docs/` and code comments uses these provenance tags:
- **`[DOC]`** — Explicitly stated in the clinical Spec (must match formulas, cut-offs, and test vectors verbatim).
- **`[DER]`** — Derived by engineering to execute a documented workflow (e.g., guided intro/capture screens, secondary rule codes `T17`..`T42`).
- **`[STD]`** — Standard production app infrastructure (splash, sign-in, settings, appearance) not covered by the algorithm spec.
- **`[OPEN]`** — External dependency or unconfirmed FRS detail (`Docs/16_Open_Questions_and_Assumptions.md`).
- **`[MOCK]` / Simulated** — Local stand-in (e.g., CNN eyelid/eye/oral/skin classifiers, clip-on fundus camera toggle, or synthetic sensor/signal waveforms on desktop/test).

### 1.2 Non-Negotiable Clinical & Engineering Rules
1. **Screening, Never Diagnosis:** Outputs are screening bands (`SemanticBand`), never confirmed medical diagnoses. Every result screen renders `DisclaimerFooter` and links flagged conditions (`COND_*`) to `ConfirmatoryInvestigationsRegistry` (`Docs` §13).
2. **Zero Invented Thresholds:** Where the Spec states cohort reference tables are "to be built" (e.g. HRV age bands, waveform age bands, VO2max age/sex, movement/cognitive norms without a Spec cut-off), domain builders emit `SemanticBand.rangeNotAvailable` / `MarkerDisplayStatus.rangeNotAvailable` (`"Reference range not yet available"`). Never invent clinical cut-offs.
3. **Oct 17 Prototype Bug Guard (`ALG-PUL-09` / Case `T16` / `BR-QUA-01`):** Any pulse scan with `pulse_snr_db < 3.0` or `clean_beat_count < 20` is strictly flagged `retakeRequired = true` (`MarkerDisplayStatus.qualityRetakeRequired`), hides clinical values, and emits **zero** urgency flags.
4. **Confidence Gate (`G-23` / `ALG-RSK-06`):**
   `confidence = (captureQualityScore * modelConfidence * (hadRecentCaffeineSmokeExercise ? 0.8 : 1.0)).clamp(0.0, 1.0)`
   Any marker with `confidence < 0.60` is automatically hidden (`MarkerDisplayStatus.lowConfidenceHidden` in `MarkerEnvelope` and `MarkerReadings._fromEnvelope`).
5. **Algorithm Release Gate (`G-24` / `AlgorithmReleaseStatus`):**
   - `SBP` and `DBP` use `MarkerDisplay.internalUntilValidated`: only `BP_BAND` is member-facing unless `appState.bpNumericValidatedRelease == true` (ISO 81060-2 validation toggle in `More` tab).
   - Internal/research markers (`HB_EST`, `ANAEMIA_PROB`, `TB_PROB`, `OAD_PROB`, `ASTHMA_VS_COPD_PROB`, `MOOD_VOICE_SCORE`, `COG_BAND`, `IRREG_PROB`, `HR_POS`, `RR_RIIV`) use `MarkerDisplay.internal` / `MarkerDisplay.diagnostic` / `MarkerDisplayStatus.internalOnly` and render only inside the collapsible `InternalMarkersExpander`, never as headline member values.
6. **Specialist Review Routing (`IMG-10`):** Image screens route to specialist review (`specialistReviewRequired = true`, `MarkerDisplayStatus.underSpecialistReview`) when `band == SemanticBand.high` (or `refer`/`suspicious`/`ulcer`) or when the predicted probability is within `±0.10` of the decision threshold `τ` (`MarkerReading.inUncertainZone`).
7. **Safety Escalation Override (`G-37`):** Emergency findings (`UrgencyLevel.emergency`) pre-empt standard result navigation:
   - `PHQ-9 item 9 > 0` (`T37`, `BR-SCR-01`) -> `MindCaptureScreen` saves session immediately and opens `CrisisSupportScreen` (`S-G14`).
   - Positive Stroke FAST (`T10`, `BR-SCR-01`), critical `SpO2 < 92%` (`T1`), critical `HR < 40` or `> 130` (`T2`), critical `RR < 8` or `> 24`, or `Shock Index > 0.90` (`T5`) -> opens `EmergencyAlertScreen` (`S-R02`) immediately.
8. **30-Day Case Deduplication (`ALG-RSK-07`):** `RiskEngine.mergeFlagsIntoCases` merges flags sharing the same `subjectId` and `conditionCode` (`COND_*`) within 30 days (`CaseRecord.canMergeFlagAt`) into a single open `CaseRecord`, sorted with highest urgency first (`T15`: `Emergency > Urgent > Routine`).
9. **Persistence Scope (Important Reality):** All state in `AppState` (subjects, consents, device calibration, all session lists, `screeningRecords`, `cases`) is currently **in-memory** seeded at startup by `_seedInitialData()` — there is no local database or REST API client wired yet.

---

## 2. ID Registries & Naming Conventions

### 2.1 Domain & Spec ID Systems

| Prefix | Meaning | Where Defined | Examples |
|---|---|---|---|
| `F-01`..`F-38` | Application Features (38) | `Docs/00_README_Index.md`, `DEVELOPMENT_PROGRESS.md` | `F-10` (Face rPPG), `F-16` (Image Screens), `F-20` (Respiratory Audio) |
| `S-A01`..`S-I05` | UI Screens (`83` `ScreenSpec` entries in registry; `82` named IDs, `S-E05` unused) | `VitalsMirrorCatalogRegistry.allScreens` (`screening_catalogue_item.dart`) | `S-C01` (Home), `S-D03` (Face Capture), `S-G14` (Crisis), `S-R01` (Shared Result) |
| `G-01`..`G-37` | Feature Gates (37) | `GateId` (`enums.dart`), `GateEvaluator` (`gate_evaluator.dart`) | `G-04` (Screening Consent), `G-18` (Room Noise ≤ 45 dBA), `G-24` (Release Gate) |
| `ALG-*` | Algorithm Cards | `MarkerCatalogue` (`marker_catalogue.dart`), `CaptureQualityEngine` | `ALG-CAP-01..15`, `ALG-PUL-01..10`, `ALG-FRM-01..15`, `ALG-IMG-01..09`, `IMG-10`, `ALG-DEN-01..07`, `ALG-AUD-01..12`, `ALG-MOV-01..13`, `ALG-RSK-01..07` |
| `COND_*` | Confirmatory Clinical Conditions (31 + 1 alias) | `ConfirmatoryInvestigationsRegistry.byCondition` (`case_record.dart`) | `COND_HTN`, `COND_AF`, `COND_ANAEMIA`, `COND_TB`, `COND_OAD`, `COND_OSA`, `COND_PD`, `COND_STROKE`, `COND_MOOD`, `COND_HF_DECOMP` |
| `BR-*` / `T1`..`T42` | Business Rules & Urgency Rule Test Cases | `RiskEngine.evaluateUrgency` (`risk_engine.dart`) | `BR-QUA-01` (`T16`), `BR-VIT-01..06` (`T1`..`T9`), `BR-SCR-01..05` (`T10`..`T42`) |
| `cat_*` | 34 Screening Catalogue Items | `VitalsMirrorCatalogRegistry.catalogueItems` | `cat_vitals_face`, `cat_img_anaemia`, `cat_dental_full`, `cat_sleep_sonar` |
| `pkg_*` | 8 Curated Multi-Scan Packages | `HealthPackagesRegistry.packages` (`health_package.dart`) | `pkg_complete_vitals`, `pkg_annual_master`, `pkg_respiratory_sleep` |
| Session/Entity IDs | Runtime instance IDs | `AppState` & builders | `subj_*`, `den_*`, `ana_*`, `breath_*`, `mind_*`, `sleep_*`, `hear_*`, `vis_*`, `mov_*`, `flg_*`, `case_*` |

### 2.2 File, Class, and Symbol Naming Conventions
Every modern screening module follows a strict, uniform structure across `domain/` and `features/`:

- **File Naming (`snake_case.dart`):**
  - Protocols & Results: `lib/core/domain/entities/<module>_protocol.dart`, `<module>_result.dart`
  - Pure Signal/ML Engines: `lib/core/domain/algorithms/<module>_engines.dart`
  - Session Assemblers: `lib/core/domain/algorithms/<module>_session_builder.dart`
  - Services: `lib/core/services/<capability>_service.dart`
  - Feature UI (6-file template):
    - `lib/features/<module>/<module>_intro_screen.dart`
    - `lib/features/<module>/<module>_capture_screen.dart` (or `*_stepper_screen.dart`)
    - `lib/features/<module>/<module>_run_controller.dart`
    - `lib/features/<module>/<module>_result_screen.dart`
    - `lib/features/<module>/<module>_illustrations.dart`
    - `lib/features/<module>/<module>_task_views.dart` (or per-test `*_test_view.dart`)
  - Tests: `test/<module>_engines_test.dart` (unit/math) and `test/<module>_flow_test.dart` (widget/state integration).

- **Class & Function Naming (`PascalCase` / `camelCase`):**
  - Protocols: `<Module>Protocol` + `<Module>Protocols` (static `all`, `forScreenId(String)`, `forCatalogueId(String)`).
  - Demo / Synthetic data: `<Module>DemoOutcome` enum + `<Module>Simulated` (or `<Module>Synthetic`) class.
  - Session Builder: top-level pure function `build<Module>Session(...) -> <Module>SessionResult`.
  - Result Models: `<Module>SessionResult`, `<Module>PartResult` (or `<Module>SideResult`), `<Module>QualityFacts`.
  - Controllers: `<Module>RunController extends ChangeNotifier` with `<Module>Phase` (or `RunPhase`) enum (`idle`, `running`, `between`, `processing`, `aborted`, etc.).
  - UI Classes: `*Screen` (full `Scaffold` page), `*View` (embedded task body), `*Sheet` / `show*Sheet` (modal bottom sheet), `*Card`, `*Tile`, `*Banner`, `*Painter extends CustomPainter`.

- **Marker Code Naming (`MarkerCatalogue` & `MarkerEnvelope`):**
  - **`UPPER_SNAKE_CASE`**: Primary clinical markers & bands (`HR`, `RR`, `SDNN`, `RMSSD`, `BAEVSKY_SI`, `BP_BAND`, `SPO2_BAND`, `ANAEMIA_BAND`, `FEV1`, `FVC`, `FEV1_FVC`, `PTA_L`, `PTA_R`, `LOGMAR_L`, `LOGMAR_R`, `GAIT_SPEED`, `STS_COUNT_30S`, `TREMOR_FREQ`, `PHQ9`, `GAD7`, `AHI_EST`, `OSA_BAND`).
  - **`lower_snake_case`**: Derived formula values, quality checks, and sub-metrics (`map_mmhg`, `pp_mmhg`, `shock_index`, `bmi`, `whtr`, `body_fat_pct`, `vo2max_est`, `pulse_snr_db`, `clean_beat_count`, `face_distance_cm`, `dental_exam.views_completed`, `tooth_fdi`).
  - **Per-side pairing:** Envelopes emitted with `_L` or `_R` suffixes (e.g., `CATARACT_PROB_L`, `HEAR_R_1000`) are automatically matched and labelled `Left` / `Right` against base `MarkerSpec` codes by `MarkerReadings._sideOf` (`marker_readings.dart`).

---

## 3. Actual Architecture & Directory Layout

> [!NOTE]
> `Docs/13_Flutter_Architecture.md` describes an early aspirational layout (`lib/app.dart`, `lib/core/config/`, `lib/core/router/`, `lib/features/access/`). **Do not look for those folders** — the actual implemented codebase is structured as below.

```text
lib/
├── main.dart                                # Entry point: AppState + AppStateScope + MainShellScreen
├── core/
│   ├── design_system/ (5 files)             # MirrorTheme, MirrorColors, MirrorUI, MirrorWidgets, Motion, AlgorithmOutputsSection
│   ├── domain/
│   │   ├── entities/ (22 files)             # Enums, Member/Device, MarkerCatalogue, Catalogue (83 ScreenSpecs, 34 items), CaseRecord, Module Protocols & Results
│   │   ├── algorithms/ (22 files)           # Pure Dart DSP/math/rule engines, 7 session builders, RiskEngine, MarkerReadings
│   │   └── gates/ (1 file)                  # GateEvaluator (G-01..G-37)
│   ├── services/ (20 files)                 # Hardware/OS wrappers (camera, ML Kit, hand_landmarker, audio, TTS, STT, IMU, brightness) + fallbacks
│   └── state/ (1 file)                      # AppState (ChangeNotifier) & AppStateScope (InheritedNotifier)
└── features/ (17 folders, 65 files)
    ├── shell/ (4)                           # MainShellScreen (5 tabs), PackageDetailAndRunnerScreen, home_widgets, package_card, scan_art
    ├── access_profile_settings/ (1)         # ConsentCenterScreen, ProfileAndHealthContextScreen, DeviceReadinessAndHardwareScreen, ScreenArchitectureBrowserScreen, SpecVectorsVerifierScreen
    ├── members/ (2)                         # ManageMembersScreen, MemberFormScreen, showMemberSwitcher
    ├── results_cases/ (1)                   # SharedScreeningResultScreen (S-R01), EmergencyAlertScreen (S-R02), CasesListScreen (S-R04), CaseDetailScreen (S-R05)
    ├── vitals/ (1)                          # VitalsFlowScreen (S-D01..06), VitalsResultsSummaryScreen (S-D07), WaveformAndVascularDetailScreen (S-D08), FormulaLabScreen (S-D09), BpCuffCalibrationScreen (S-D10), FunctionalCardioTestsScreen (S-D11..13)
    ├── anaemia/ (5)                         # Dedicated lower-eyelid anaemia flow (S-E01..04 -> S-R01)
    ├── eye_screens/ (5)                     # Unified photo stepper flow for 8 protocols (jaundice, cataract, child eye, fundus, newborn, DFU, skin, oral, dental)
    ├── breath/ (6)                          # Cough/TB, Airway/OAD, Forced Exhale Spirometry, Voice Quality (S-G02..S-G06)
    ├── hearing/ (8)                         # Pure-tone Hughson–Westlake & Digits-in-Noise (S-G10 -> S-G11)
    ├── mind/ (7)                            # Cognitive Speech (S-G12), Mood + CrisisSupportScreen (S-G13/14), HF Voice (S-G15), Stroke FAST (S-H06)
    ├── movement/ (5)                        # Video/Touch Finger Tap, Gait, Sit-to-Stand, Tremor (S-H01..S-H05)
    ├── sleep/ (6)                           # Overnight 18–20 kHz Sonar & OSA Screen (S-G07 -> S-G08 -> S-G09)
    ├── vision/ (9)                          # Tumbling-E Acuity, Colour Plates, Amsler Grid, Reaction Time (S-H07..S-H10)
    ├── image_screening/ (1)                 # Legacy/fallback ImageScreeningFlowScreen + FundusPartnerScreen
    ├── dental/ (1)                          # Legacy/fallback DentalFlowScreen + DentalResultsScreen
    ├── audio_screening/ (1)                 # Legacy/fallback AudioSuiteScreen (still fallback for unhandled S-G* IDs)
    └── movement_vision/ (1)                 # Legacy/fallback MovementVisionSuiteScreen (fallback for unhandled S-H* IDs)
```

---

## 4. Layer-by-Layer & File-by-File Technical Reference

### 4.1 Entry & Central State (`lib/main.dart`, `lib/core/state/app_state.dart`)
- **`lib/main.dart` (38 L):** `main()` instantiates `AppState()` and runs `VitalsMirrorApp`, which wraps `MaterialApp` (`MirrorTheme.light()`, `MirrorTheme.dark()`, `themeMode: appState.themeMode`, `home: const MainShellScreen()`) inside `AppStateScope`.
- **`lib/core/state/app_state.dart` (2115 L):** `AppState extends ChangeNotifier` + `AppStateScope extends InheritedNotifier<AppState>` (`AppStateScope.of(context)`).
  - **Session/Env Fields:** `isAuthenticated` (`true`), `localeCode` (`'en' | 'te' | 'hi'`), `activeRole` (`AppUserRole.member`), `themeMode` (`ThemeMode.light`), `cameraPermissionGranted`, `micPermissionGranted`, `blePermissionGranted`, `isOnline`, `bpNumericValidatedRelease` (`false`), `deviceProfile` (`PIXEL_8_PRO_IN`, 60 fps, SpO2 A=108.4/B=24.2, room noise 38 dBA).
  - **Seeded Family Profiles (`subjects`, 5 members):**
    1. `subj_self_26` — Arjun Rao (`26y`, Male, `178 cm`, `70 kg`, `85 cm` waist — exact Spec §5 test-vector profile; family DM history; valid BP cuff calibration).
    2. `subj_child_7` — Ananya Rao (`7y`, Female — Child Eye 1–12y, Child Dental & Sealants 6–9y).
    3. `subj_newborn_72h` — Baby Aarav Rao (`0y`, `72h`, `38w` gestation — Newborn Jaundice §6.7).
    4. `subj_senior_62` — Srinivas Rao (`62y`, Male — Cataract ≥40, Cognitive ≥50, known DM/HTN/tobacco, HF enrolled with `14` baseline days).
    5. `subj_pregnant_29` — Meera Rao (`29y`, Female, `22w` pregnant — WHO anaemia cut-off `11.0 g/dL`, `T12` Urgent path).
  - **Stored Session Collections (newest first):** `vitalsSessions`, `dentalExams`, `anaemiaSessions`, `eyeSessions`, `movementSessions`, `visionSessions`, `hearingSessions`, `mindSessions`, `breathSessions`, `sleepSessions`, `hfVoiceBaselines` (`Map<String, List<HfDailySample>>`), `speechLanguages` (`Map<String, MindLanguage>`), `screeningRecords` (`List<ScreeningSessionRecord>`), `cases` (`List<CaseRecord>`).
  - **Key Public Methods:**
    - *Members & Consents:* `selectSubject`, `updateActiveSubject`, `addDependent`, `addMember`, `updateMember`, `removeMember` (protects index 0 account owner), `isAccountOwner`, `newMemberId`, `consentsFor`, `toggleConsent`.
    - *Device & Calibrations:* `updateDeviceProfile`, `setFundusCameraConnected`, `setPhoneCharging`, `setMotionSensorsAvailable`, `setFocalLengthCalibration`, `setScreenScaleCalibration`, `setMicSweepProfile`, `setMicSelfCheck`, `setEarphoneCalibration`, `setMicOffset`, `updateEarphoneState`, `setRoomNoise`.
    - *Settings & Gates:* `setLocale`, `setRole`, `toggleThemeMode`, `toggleBpNumericRelease`, `evaluateGatesForItem`.
    - *Generators (Spec-accurate synthetic/build helpers):* `generateVitalsSession(...)` (builds `HR`, `RR`, `SDNN`, `RMSSD`, `PNN50`, `BAEVSKY_SI`, `SPO2_BAND`, `BP_BAND`, `SBP`, `DBP`, `IRREG_BAND`, `VASC_AGE_GAP`, `DM_RISK`, `ALG-FRM-01..11`, runs `RiskEngine.evaluateUrgency`), `generateDentalExam(...)` (runs `CariesRiskEngine` + `RiskEngine`), `generateAnaemiaSession(...)` (WHO thresholds + `RiskEngine` + `IMG-10` specialist routing).
    - *Persistence & Case Merging:* `saveVitalsSession`, `saveDentalExam`, `saveAnaemiaSession`, `saveEyeSession` (special-cases `COND_GLAUCOMA` vs `COND_DR` for `eye_fundus` and appends `DentalChartCard.exam` to `dentalExams`), `saveMindSession` (updates `hfVoiceBaselines`, routes `isEmergency` to `S-R02`), `saveSleepSession` (deduplicates `sessionId`), `saveBreathSession`, `saveHearingSession`, `saveVisionSession`, `saveMovementSession`, `addScreeningRecord` (inserts `ScreeningSessionRecord` + creates `ConditionFlag` + calls `RiskEngine.mergeFlagsIntoCases`), `addLabPairingToCase`.
    - *Mind/HF Helpers:* `hfSamplesFor`, `hfCheckDoneToday`, `setSpeechLanguage`, `markClinicianNotified`, `hasVoiceTaskRecord`, `hasFaceVideoRecord`.

### 4.2 Design System (`lib/core/design_system/`)

| File (Lines) | Purpose | Key Public Symbols |
|---|---|---|
| `mirror_theme.dart` (526) | Tokens, semantic band colours & Light/Dark Material 3 themes | `MirrorColors`, `MirrorSpace` (4-pt scale, `screen` padding), `MirrorRadius`, `BandVisualStyle.forBand(SemanticBand)`, `MirrorTheme.light()`, `MirrorTheme.dark()` |
| `mirror_ui.dart` (437) | Shared layout & card primitives | `SectionHeader`, `PageHeading`, `MirrorPill`, `IconBadge`, `MirrorGroupCard`, `MirrorNavTile`, `EmptyState`, `BrandMark`, `MirrorDropdownField<T>`, `MemberAvatar` |
| `mirror_widgets.dart` (953) | Clinical UI components & gate/lifecycle inspector | `BandChip`, `UrgencyBanner`, `ConfidenceMeter`, `MetricTile`, `GateBlockerCard`, `WaveformPainterView`, `FdiToothChartWidget`, `DisclaimerFooter`, `showScreenGateLifecycleSheet(context, screenId)` |
| `mirror_motion.dart` (144) | Accessible motion primitives (honours `disableAnimationsOf`) | `FadeSlideIn`, `Pressable`, `FadeIndexedStack` |
| `algorithm_outputs_section.dart` (826) | Universal spec-ordered marker output renderer & inspector | `AlgorithmOutputsSection`, `AlgorithmOutputCard`, `MarkerReadingRow`, `InternalMarkersExpander`, `showMarkerDetailSheet`, `MarkerDetailScreen`, `MarkerDetailView`, `displayRuleText` |

### 4.3 Domain Entities & Gates (`lib/core/domain/entities/`, `lib/core/domain/gates/`)

- **`enums.dart` (371 L):**
  - `FeatureLifecycleState` (14): `notStarted`, `initializing`, `permissionRequired`, `permissionGranted`, `permissionDenied`, `ready`, `loading`, `processing`, `success`, `failed`, `retry`, `completed`, `disabled`, `expired`.
  - `GateId` (37): `g01`..`g37` (`code`, `title`, `category`).
  - `UrgencyLevel` (4): `none` (0), `routine` (1), `urgent` (2), `emergency` (3) with `operator >`.
  - `SemanticBand` (24): `normal`, `low`, `regular`, `borderline`, `elevated`, `moderate`, `mild`, `prediabetesRisk`, `atRisk`, `suspicious`, `critical`, `high`, `diabetesRisk`, `irregular`, `ulcer`, `severe`, `refer`, `emergency`, `notAssessed`, `notAvailable`, `hidden`, `inValidation`, `rangeNotAvailable`, `needsConfirmation`.
  - `AlgorithmReleaseStatus`: `validated`, `bandOnly`, `research`, `disabled`.
  - `MarkerDisplayStatus`: `ok`, `bandOnly`, `rangeNotAvailable`, `needsConfirmation`, `underSpecialistReview`, `lowConfidenceHidden`, `qualityRetakeRequired`, `notAvailable`, `notAssessed`, `inValidation`, `internalOnly`.
  - `VitalsCaptureMode`: `face`, `finger`.
  - `BiologicalSex`: `male` (deurenbergCode `1`), `female` (deurenbergCode `0`).
  - `AppUserRole`: `member`, `guardian`, `operator`.
  - `ConsentType`: `screening` (`G-04`), `dentalGuardian` (`G-05`), `trainingData` (`G-06`), `clinicianMoodPathway` (`G-07`), `heartFailureProgramme` (`G-08`).
  - `ImageScreenType` (9): `anaemia`, `adultJaundice`, `cataract`, `oralLesion`, `diabeticFoot`, `childEye`, `newbornJaundice`, `skinLesion`, `fundusDrGlaucoma`.
  - `ColourCardPolicy`: `none`, `preferred`, `required`, `mandatory`.
- **`member_profile.dart` (296 L):** `ConsentRecord`, `BpCuffCalibration` (30-day validity), `DeviceCapabilityProfile` (SpO2 coeffs, `isRoomQuietEnough` `<= 45.0` dBA, focal length, earphone/mic calibration), `SubjectProfile` (`isNewborn`, `isChild`, `isAdult`, `isBasicProfileComplete`, `isExtendedProfileComplete`, `hasConsent`).
- **`marker_envelope.dart` (313 L):** `MarkerEnvelope<T>` (with `shouldShowNumericValue`, `displayText` enforcing `confidence < 0.60` & `G-24`), `ToothFinding`, `DentalExamResult`, `CaptureQualityCheck`, `CaptureQualitySummary`, `RoiWeight`, `PulseSignalSummary`, `VitalsSessionResult`, `ScreeningSessionRecord`.
- **`marker_catalogue.dart` (2975 L):** `MarkerDisplay` (`shown`, `bandOnly`, `internalUntilValidated`, `internal`, `diagnostic`), `MarkerKind`, `MarkerThresholds`, `MarkerSpec`, `AlgorithmCard`, and `MarkerCatalogue` containing all 44 `AlgorithmCard` definitions (`ALG-CAP-01..15` through `ALG-MOV-13`, plus `IMG-10`).
- **`screening_catalogue_item.dart` (2073 L):** `ScreenSpec`, `ScreeningCatalogueItem`, and `VitalsMirrorCatalogRegistry` (`categories` [11], `catalogueItems` [34], `allScreens` [83 `ScreenSpec`s]).
- **`health_package.dart` (688 L):** `HealthScanPackage`, `HealthPackagesRegistry` (`packages` [8], `permissionsForTargetScreen`, `preparationTipsForTargetScreen`).
- **`case_record.dart` (592 L):** `ConfirmatoryInvestigationSpec`, `ConditionFlag`, `ReferenceLabPairingRecord` (`pairingGrade`: Grade A / B / D), `CaseRecord` (`canMergeFlagAt` within 30 days), `ConfirmatoryInvestigationsRegistry` (31 `COND_*` entries + `COND_COGNITIVE` -> `COND_COG` alias).
- **`gate_evaluator.dart` (441 L):** `GateCheckOutcome`, `GateEvaluator.evaluateSingleGate(...)`, `GateEvaluator.evaluateForCatalogueItem(...)` implementing all 37 gates (`G-01`..`G-37`). Blocking vs advisory gates are distinguished via `GateCheckOutcome.isAdvisoryOnly` (e.g., `G-06` training consent, `G-10` history priority, `G-14` notifications, `G-26` cuff calibration, `G-27` rhythm confirmation, `G-28` HF baseline building, `G-32` Smart Ring, `G-34` cadence, `G-36` online status, plus `G-09` cataract on-request).
- **Module Protocol & Result Entities:**
  - `anaemia_result.dart` (283 L): `EyeSide`, `RecentTreatment`, `AnaemiaPreTestAnswers`, `EyelidPhoto`, `AnaemiaEyeSummary`, `AnaemiaWhoThreshold`, `AnaemiaDemoOutcome`, `AnaemiaSessionResult`.
  - `eye_photo_protocol.dart` (3617 L): `EyeGaze`, `EyeExtraInput`, `EyeIllustration`, `EyeView`, `EyeQuestion`, `EyeHowToStep`, `EyeExample`, `EyeNeedTile`, `EyeBandInfo`, `EyeScale`, `EyeGaugeSpec`, `EyeProtocol`, `EyeProtocols` (`jaundice`, `cataract`, `childEye`, `fundus`, `newbornJaundice`, `diabeticFoot`, `skinLesion`, `oralLesion`, `dentalCaries`, `everything`, `forScreenType`, `forId`).
  - `eye_photo_session.dart` (440 L): `EyeDemoOutcome`, `EyePhoto`, `EyeAnswers`, `EyeFinding`, `EyeZoneResult`, sealed `EyeExtraCard` (`NeonatalChartCard`, `FootRiskCard`, `SkinMatchesCard`, `OralSitesCard`, `DentalChartCard`), `EyeSessionResult`.
  - `breath_protocol.dart` (1295 L) & `breath_result.dart` (206 L): `BreathKind` (`coughTb`, `airway`, `lungFunction`, `voice`), `BreathTaskType`, `PhonationKind` (`aaa`, `sss`, `zzz`, `sentence`), `BreathProtocol`, `BreathProtocols` (`coughTb`, `airway`, `lungFunction`, `voice`), `BreathPartResult`, `BreathQualityFacts`, `BreathSessionResult`.
  - `mind_protocol.dart` (1525 L) & `mind_result.dart` (219 L): `MindKind` (`cognitive`, `mood`, `hfVoice`, `stroke`), `MindLanguage` (`en`, `hi`, `te`), `MindTaskType`, `MindProtocol`, `MindProtocols` (`cognitive`, `mood`, `hfVoice`, `stroke`), `MindPartResult`, `MindQualityFacts`, `MindSessionResult`.
  - `sleep_protocol.dart` (369 L) & `sleep_result.dart` (173 L): `SleepProtocols.sonar`, `SleepQualityFacts`, `SleepSessionResult`.
  - `hearing_protocol.dart` (432 L) & `hearing_result.dart` (178 L): `HearingMode` (`pureTone`, `digitsInNoise`), `HearingEar`, `HearingProtocols` (`pureTone`, `digitsInNoise`), `HearingPartResult`, `HearingQualityFacts`, `HearingSessionResult`.
  - `vision_protocol.dart` (663 L) & `vision_result.dart` (160 L): `VisionTestKind` (`acuity`, `colour`, `amsler`, `reaction`), `VisionEye`, `ReactionBlock`, `VisionProtocols` (`acuity`, `colour`, `amsler`, `reaction`), `VisionPartResult`, `VisionQualityFacts`, `VisionSessionResult`.
  - `movement_protocol.dart` (805 L) & `movement_result.dart` (176 L): `MovementTestKind` (`tappingVideo`, `tappingTouch`, `gait`, `sitToStand`, `tremor`), `MovementSide`, `MovementSensor`, `MovementPacing`, `MovementProtocols`, `MovementSideResult`, `MovementQualityFacts`, `PdCompositeStatus`, `MovementSessionResult`.

### 4.4 Domain Algorithms & Session Builders (`lib/core/domain/algorithms/`)

| File (Lines) | ALG IDs | Key Classes / Functions & Rules |
|---|---|---|
| `capture_quality_engine.dart` (226) | `ALG-CAP-01..15`, `ALG-PUL-06` | `CaptureQualityEngine.specs` + check methods (`checkFacePose`, `checkLightLuma` 60–220, `checkMotion` ≤3 px/s, `checkSkinValidityPct` ≥80%, `checkBlurScore` ≥100, `checkGlareAndDark` ≤5%/≤10%, `checkImageQualityClassifier` ≥0.70, `checkColourCard` ΔE≤5, `checkMicSweep` ≤6 dB, `checkRoomNoise` ≤45 dBA, `checkAudioClipAndSnr` ≤1%/≥15 dB, `checkVisionFaceDistance` 35–45 cm) |
| `hrv_baevsky_engine.dart` (179) | `ALG-HRV-01..04` | `HrvBaevskyEngine.computeTimeDomain` (SDNN, RMSSD, pNN50, SD1/SD2), `computeFromParameters` (`SI = AMo / (2 * Mo * MxDMn)`, flags rigid rhythm if `MxDMn < 0.020 s`), `computeFromIbiSeries` (50-ms bins, 2.5% trim) |
| `formulas_engine.dart` (247) | `ALG-FRM-01..15` | `FormulasEngine`: `computeMap`, `computePulsePressure`, `computeShockIndex` (>0.90 critical), `computeRpp`, `computeCrRatio`, `computeHrMaxTanaka`, `computeHrReserve`, `computeVo2MaxUth`, `computeBmi` (Asian BMI ≥23 high), `computeWhtr` (<0.5 normal), `computeBodyFatDeurenberg` (adults ≥18y), `computeWhoZScore`, `computeOrthostaticRise` (<30 normal), `computeHrRecovery1Min` (≥12 normal) |
| `caries_risk_engine.dart` (106) | `ALG-DEN-06` (`BR-DEN`) | `CariesRiskEngine.evaluate(findings, habits)` implementing exact Cases 1–6 |
| `neonatal_bilirubin_chart.dart` (121) | `ALG-IMG-07` | `NeonatalBilirubinChart.phototherapyThreshold` (stand-in AAP 2022 12-h sampled table for 35–40+ weeks, 0–672h) & `band` (borderline within 3.0 mg/dL) |
| `photo_quality_analyzer.dart` (521) | `ALG-CAP-06..10` | `analyzeRgba`, `analyzeEncodedPhoto`: computes blur (Laplacian variance), glare/dark %, CIE `L*a*b*`, 24-patch colour card heuristics per `PhotoTarget` |
| `eye_session_builder.dart` (2518) | `ALG-IMG-02..09`, `ALG-DEN-01..07` | `buildEyeSession(...) -> EyeSessionResult` covering adult/newborn jaundice, cataract, child eye, fundus DR/glaucoma, diabetic foot, skin, oral lesion, and 4-view dental + caries risk |
| `fft.dart` (58) | Shared DSP | `Fft` (radix-2 Cooley-Tukey FFT & magnitude spectrum) |
| `breath_engines.dart` (2151) & `breath_session_builder.dart` (1040) | `ALG-AUD-01..06`, `ALG-FRM-13`, `ALG-CAP-11` | `CoughDetector`, `LiveBurstCounter`, `WheezeDetector`, `ExhaleAnalyzer`, `SpirometryReference` (GLI-2012), `AudioSpirometry`, `VoiceQuality` (F0, jitter, shimmer, HNR, CPPS, MPT, s/z), `TbModel`, `OadModel`, `MicSelfCheck`, `LiveFrameDetector`, `BreathSimulated`, `buildBreathSession(...)` |
| `mind_engines.dart` (1146) & `mind_session_builder.dart` (1036) | `ALG-AUD-10..12`, `ALG-MOV-06..09` | `VoiceFeatures`, `TranscriptAnalysis`, `FluencyScorer` (`en`/`hi`/`te`), `PictureScorer`, `Phq9Gad7`, `MoodVoiceModel`, `HfBaseline` (14d personal baseline + 2d drift alert), `FaceAsymmetry`, `ArmDrift`, `SpeechAbnormality`, `StrokeDecision`, `MindSimulated`, `buildMindSession(...)` |
| `sleep_engines.dart` (775) & `sleep_session_builder.dart` (233) | `ALG-AUD-07`, `ALG-AUD-08` | `SonarFrameAnalyzer` (18–20 kHz), `BreathWaveExtractor`, `ApnoeaScorer` (+ `SpO2Dip`), `SnoreDetector`, `SleepDecision` (OSA bands, requires ≥ 4 h valid sleep for AHI), `SleepSimulated`, `buildSleepSession(...)` |
| `hearing_engines.dart` (412) & `hearing_session_builder.dart` (432) | `ALG-AUD-09`, `ALG-CAP-12` | `HughsonWestlake` (500/1000/2000/4000 Hz staircase), `DigitsInNoise` (adaptive SNR triplets -> `DIN_SRT_DB`), `HearingGrading` (WHO <20 dB HL, asymmetry ≥15 dB at ≥2 freqs), `NoiseWindow`, `HearingSimulated`, `buildHearingSession(...)` |
| `vision_engines.dart` (984) & `vision_session_builder.dart` (550) | `ALG-MOV-10..12`, `ALG-CAP-15` | `FaceDistance` (iris 11.7 mm pinhole -> 40±5 cm), `TumblingEStaircase` (logMAR), `ColourPlateSet`/`ColourPlateScorer`, `AmslerMarks`, `ReactionTimeAnalyzer` (discards <100 ms), `VisionSimulated`, `buildVisionSession(...)` |
| `movement_engines.dart` (1047) & `movement_session_builder.dart` (665) | `ALG-MOV-01..05`, `ALG-MOV-13` | `Dsp`, `TapReversalCounter`, `TapSeriesAnalyzer` (decrement ≥20%), `TouchTapAnalyzer`, `GaitAnalyzer` (<0.8 m/s fall risk), `StsCycleCounter` (30s norm ≥12 for 60–64y), `TremorAnalyzer` (4–6 Hz PSD via `Fft`), `MovementSynthetic`, `buildMovementSession(...)` |
| `risk_engine.dart` (919) | `ALG-RSK-01..07` | `RiskEngine`: `assignHrBand`, `assignRrBand`, `assignSpo2Band`, `assignBpBand`, `assignAnaemiaBand`, `evaluateUrgency` (all rules `T1`..`T42`), `evaluateBaselineAndChange` (median of last 3 within 180d, >15% or >2 SD), `computeResultConfidence`, `mergeFlagsIntoCases` (30-day window) |
| `marker_readings.dart` (771) | UI Adapter | `MarkerReading`, `ReadingGroup`, `MarkerReadings`: `fromEnvelopes`, `fromVitals`, `fromEye`, `fromAnaemia`, `fromDental`, `fromRecord`, `fromMovement`, `fromVision`, `fromHearing`, `fromMind`, `fromBreath`, `fromSleep`, `fromValues` |

### 4.5 Hardware & Platform Services (`lib/core/services/`)
All 20 services wrap native plugins safely and degrade gracefully (to simulated streams, manual fallbacks, or headless no-ops) on Windows desktop or `flutter test` environments:

| Service File (Lines) | Plugin(s) Wrapped | Key Public API & Purpose |
|---|---|---|
| `live_camera_service.dart` (1189) | `camera`, `google_mlkit_face_detection`, `google_mlkit_image_labeling`, `permission_handler` | `ScanCameraMode` (`faceVitals`, `fingerPpg`, `eyeMacro`, `dentalArch`, `footMacro`, `skinMacro`, `faceSmile`, `faceDistance`), `BiometricCameraController` (`initialize`, `switchCameraLens`, `toggleTorch`, `captureStill`, `onRawFrame`, `onFrameMetricsUpdated`), `BiometricFrameTelemetry`, `LiveBiometricCameraSurface` |
| `voice_coach_service.dart` (923) | `flutter_tts`, `permission_handler` | `VoiceCoachController` (`announce`, `speak`, `stop`), `LiveVoiceCoachBanner`, `ScanPermissionItem`, `showScanPermissionReadinessModal(...)` |
| `hand_tracking_service.dart` (601) | `camera`, `hand_landmarker` | `HandTrackingService` (`LandmarkHandTracker`, `ProxyHandTracker`, `SimulatedHandTracker`), `toDisplaySpace`, `HandFrame`, `HandGuide`, `HandStatus` (`ALG-MOV-01`) |
| `motion_sensor_service.dart` (317) | `sensors_plus` | `MotionSensorService`, `MotionAvailability` (`available`, `unavailable`, `simulated`), `SimulatedMotionProfile`, `MotionStreamStats` (50 Hz accel / 100 Hz gyro for `G-13`, `ALG-MOV-03..05`, `ALG-MOV-07`) |
| `breath_audio_service.dart` (284) | `record` | `BreathAudioService`: 16 kHz mono PCM stream/buffer capture for cough, phonation, breath sounds, forced exhale (`ALG-AUD-01..06`) |
| `ambient_noise_service.dart` (172) | `record` | `AmbientNoiseService`, `NoiseReading`: 3 s room-noise dBA check (`ALG-CAP-12` / `G-18`) |
| `mic_self_check_service.dart` (191) | `audioplayers`, `record` | `MicSelfCheckService`: plays `assets/audio/sweep.wav` & compares loopback octave profile (`ALG-CAP-11` / `G-17`) |
| `sleep_sonar_service.dart` (426) | `audioplayers`, `record` | `SleepSonarService`, `SonarCheckResult`: plays `sonar_chirp.wav` 18–20 kHz & analyzes chest echo (`ALG-AUD-07`) |
| `sleep_device_service.dart` (139) | `MethodChannel` / `permission_handler` | `SleepDeviceService`, `BatteryStatus`: checks charger state (`G-30`) & notification permission |
| `hearing_tone_service.dart` (84) | `audioplayers` | `HearingToneService`: plays left/right pure-tone WAVs (`tone_*_l/r.wav`) and `din_noise.wav` (`ALG-AUD-09`) |
| `audio_route_service.dart` (186) | Platform `MethodChannel` | `AudioRouteService`, `AudioRouteState`: detects wired/bluetooth/USB earphones (`G-19`) |
| `digit_speech_service.dart` (63) | `flutter_tts` | `DigitSpeechService`: speaks 3-digit triplets for DIN hearing screen |
| `pacing_audio_service.dart` (59) | `audioplayers` | `PacingAudio`: plays `tick.wav`, `beep.wav`, `go.wav` for movement & reaction tests |
| `speech_capture_service.dart` (205) | `record` | `SpeechCaptureService`: 16 kHz PCM voice capture for Mind tasks (`ALG-AUD-10..12`, `ALG-MOV-08`) |
| `speech_transcribe_service.dart` (274) | `speech_to_text` | `SpeechTranscribeService`: on-device STT for `en` / `hi` / `te` cognitive & stroke speech tasks |
| `face_distance_service.dart` (153) | — (consumes camera iris/face width) | `FaceDistanceService`, `DistanceMode` (`measured`, `estimated`, `manual`), `DistanceReading` (`ALG-CAP-15` 40±5 cm) |
| `screen_brightness_service.dart` (63) | `screen_brightness` | `ScreenBrightnessService`: forces 100% brightness during Colour Vision (`S-H08`) and restores on exit |
| `screen_metrics_service.dart` (83) | `MediaQuery` / platform | `ScreenMetricsService`, `ScreenMetrics`: physical mm-per-logical-px sizing for Tumbling-E optotypes (`S-H07`) |
| `subject_track_spec.dart` (135) | — | `SubjectTrackSpec`: maps `PhotoTarget` to expected ML Kit image labels (e.g. Mouth/Smile for dental, Foot/Toe for DFU) |
| `emergency_contacts.dart` (53) | `url_launcher` | `EmergencyContacts`, `EmergencyContact`: India emergency (`112`, Tele-MANAS `14416`, Kiran) `tel:` launchers for `S-R02` / `S-G14` |

### 4.6 Platform Permissions & Audio Assets
- **Android (`android/app/src/main/AndroidManifest.xml` & `build.gradle.kts`):** `compileSdk = 37`, `minSdk = flutter.minSdkVersion`; permissions: `INTERNET`, `CAMERA`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `FLASHLIGHT`, `VIBRATE`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS`, `WAKE_LOCK`.
- **iOS (`ios/Runner/Info.plist`):** `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSMotionUsageDescription`.
- **Audio Assets (`assets/audio/`):** 14 WAV files (`tick.wav`, `beep.wav`, `go.wav`, `sweep.wav`, `sonar_chirp.wav`, `din_noise.wav`, `tone_{500,1000,2000,4000}_{l,r}.wav`) generated deterministically by `dart run tool/gen_pacing_wavs.dart`.

### 4.7 Feature UI Modules (`lib/features/`)

1. **`shell/` (`main_shell_screen.dart` 4863 L, `home_widgets.dart`, `package_card.dart`, `scan_art.dart`):**
   - `MainShellScreen` hosts a 5-destination `NavigationBar` inside `FadeIndexedStack`:
     - **Tab 0 — Home (`S-C01`):** `HomeHeader` (greeting, wellness score `ScoreRing`, latest HR/RR/Stress stats, alert bell -> `CasesListScreen`, `showMemberSwitcher`), search bar, horizontal category shortcuts (`_homeCategories`), `FeaturedCarousel`, top open `CaseRecord` alert banner, horizontal `HealthPackagesRegistry` cards, latest vitals `MetricTile` 2-col grid.
     - **Tab 1 — Packs (`S-C02`):** Filterable showcase of the 8 `HealthScanPackage` bundles -> opens `PackageDetailAndRunnerScreen` (multi-step guided runner).
     - **Tab 2 — Scans (`S-C02`):** Search + category filter + availability filter over all 34 `ScreeningCatalogueItem`s with gate status badges.
     - **Tab 3 — History (`S-C03` / `S-C05`):** Trend chart (`_TrendChartPainter`) with `ALG-RSK-03/04` personal baseline evaluation + filterable timeline of `screeningRecords` -> `SharedScreeningResultScreen` (`S-R01`), `VitalsResultsSummaryScreen`, `DentalResultsScreen`.
     - **Tab 4 — More (`S-C07`):** Links to `ConsentCenterScreen`, `DeviceReadinessAndHardwareScreen`, `CasesListScreen`, `ManageMembersScreen`, `ProfileAndHealthContextScreen`, `ScreenArchitectureBrowserScreen` (83-screen/37-gate inspector), `SpecVectorsVerifierScreen` (live test-vector verifier), theme toggle, and `bpNumericValidatedRelease` (`G-24`) toggle.
2. **Modern 6-File Guided Modules (Controller + SessionBuilder Pattern):**
   - `breath/` (`S-G02`..`S-G06`): `BreathIntroScreen` -> `BreathCaptureScreen` (`BreathRunController`) -> `BreathResultScreen`
   - `hearing/` (`S-G10` -> `S-G11`): `HearingIntroScreen` -> `HearingCaptureScreen` (`HearingRunController`, `PureToneTestView`, `DinTestView`) -> `HearingResultScreen` (`AudiogramPainter`)
   - `mind/` (`S-G12`, `S-G13`, `S-G14`, `S-G15`, `S-H06`): `MindIntroScreen` -> `MindCaptureScreen` (`MindRunController`, `MindTaskViews`) -> `MindResultScreen` or `CrisisSupportScreen` (`S-G14`) / `EmergencyAlertScreen` (`S-R02`)
   - `movement/` (`S-H01`..`S-H05`): `MovementIntroScreen` -> `MovementCaptureScreen` (`MovementRunController`, `TwoTargetsPad`, `BubbleLevelView`, `HandOverlayPainter`) -> `MovementResultScreen`
   - `sleep/` (`S-G07` -> `S-G08` -> `S-G09`): `SleepIntroScreen` -> `SleepCaptureScreen` (`SleepRunController`, `SleepReadyView`, `SleepNightClockView`) -> `SleepResultScreen` (`SleepRrChartPainter`)
   - `vision/` (`S-H07`..`S-H10`): `VisionIntroScreen` -> `VisionCaptureScreen` (`VisionRunController`, `AcuityTestView`, `ColourPlateView`, `AmslerGridView`, `ReactionTestView`) -> `VisionResultScreen`
3. **Guided Photo Stepper Modules:**
   - `anaemia/` (`S-E01`..`S-E04`): `AnaemiaIntroScreen` -> `AnaemiaStepperScreen` -> `AnaemiaResultScreen` (`appState.generateAnaemiaSession` & `saveAnaemiaSession`).
   - `eye_screens/` (`S-E01`..`S-E04`, `S-E06`, `S-F01`..`S-F05`): `EyeIntroScreen` -> `EyeStepperScreen` (`buildEyeSession`) -> `EyeResultScreen` (`saveEyeSession`). Handles **9 protocols** (`jaundice`, `cataract`, `childEye`, `fundus`, `newbornJaundice`, `diabeticFoot`, `skinLesion`, `oralLesion`, `dentalCaries`).
4. **Vitals Suite (`vitals/vitals_screens.dart` 5890 L):**
   - `VitalsFlowScreen` (`S-D01`..`S-D06`), `VitalsResultsSummaryScreen` (`S-D07`), `WaveformAndVascularDetailScreen` (`S-D08`), `FormulaLabScreen` (`S-D09`), `BpCuffCalibrationScreen` (`S-D10`), `FunctionalCardioTestsScreen` (`S-D11`..`S-D13`). Note: live camera tracks face/finger via `BiometricCameraController` while physiological HR/RR/BP/SpO2 waveform metrics currently combine simulated/demo parameters (`_simulatedHr`, `_simulatedSnrDb`, etc.) with exact `HrvBaevskyEngine`, `FormulasEngine`, and `RiskEngine` computation.
5. **Supporting Suites & Legacy Fallbacks:**
   - `members/` (`ManageMembersScreen`, `MemberFormScreen`, `showMemberSwitcher`)
   - `results_cases/` (`SharedScreeningResultScreen` `S-R01`, `EmergencyAlertScreen` `S-R02`, `CasesListScreen` `S-R04`, `CaseDetailScreen` `S-R05`)
   - `access_profile_settings/` (`ConsentCenterScreen` `S-B01/02`, `ProfileAndHealthContextScreen` `S-B03/04`, `DeviceReadinessAndHardwareScreen` `S-B07`, `ScreenArchitectureBrowserScreen`, `SpecVectorsVerifierScreen`)
   - Legacy/fallback studios kept in `lib/`: `image_screening/image_screens.dart`, `dental/dental_screens.dart`, `audio_screening/audio_screens.dart` (fallback for any unhandled `S-G*`), `movement_vision/movement_vision_screens.dart` (fallback for any unhandled `S-H*`).

---

## 5. End-to-End Application Flows

### 5.1 Flow 1 — Catalogue Launch & Gate Enforcement (`MainShellScreen._openCatalogueItem`)
1. User taps a `ScreeningCatalogueItem` (or `PackageDetailAndRunnerScreen` step).
2. `appState.evaluateGatesForItem(item)` invokes `GateEvaluator.evaluateForCatalogueItem`.
3. If any outcome has `!o.passed && !o.isAdvisoryOnly`, a bottom sheet renders `GateBlockerCard` with a fix action (`ConsentCenterScreen`, etc.) and **aborts launch**.
4. Otherwise, `showScanPermissionReadinessModal(...)` presents `HealthPackagesRegistry.permissionsForTargetScreen` and preparation tips.
5. Once confirmed, `Navigator.of(context).push(MaterialPageRoute(...))` dispatches by item:
   - `ImageScreenType.anaemia` -> `AnaemiaIntroScreen`
   - Any other `ImageScreenType` or `S-E06` -> `EyeIntroScreen(protocol: EyeProtocols.forScreenType(...) ?? EyeProtocols.fundus)`
   - `S-F01` -> `EyeIntroScreen(protocol: EyeProtocols.dentalCaries)`
   - `S-D01` / `S-D04` -> `VitalsFlowScreen(initialMode: face / finger, autoStartScanner: true)`
   - `S-D09` -> `FormulaLabScreen`; `S-D11..13` -> `FunctionalCardioTestsScreen`
   - `BreathProtocols` match -> `BreathIntroScreen`
   - `MindProtocols` match -> `MindIntroScreen`
   - `HearingProtocols` match -> `HearingIntroScreen`
   - `SleepProtocols` match -> `SleepIntroScreen`
   - `MovementProtocols` match -> `MovementIntroScreen`
   - `VisionProtocols` match -> `VisionIntroScreen`
   - Any other `S-G*` -> `AudioSuiteScreen`; any other `S-H*` -> `MovementVisionSuiteScreen`

### 5.2 Flow 2 — Guided Capture -> Algorithm -> Case -> Result
```text
*IntroScreen (protocol, demo outcome, live hardware readiness checks)
   │  Navigator.push
   ▼
*CaptureScreen / *StepperScreen
   ├── drives *RunController (ChangeNotifier) + hardware services
   ├── enforces live ALG-CAP checks & G-25 (max 3 retakes)
   │
   ▼  calls pure domain function
build<Module>Session(...)   [or generateVitalsSession / generateAnaemiaSession]
   ├── runs pure DSP / ML engines (breath_engines, mind_engines, etc.)
   ├── wraps every output in MarkerEnvelope<T> (G-23 conf, G-24 release status)
   ├── runs RiskEngine.evaluateUrgency (ALG-RSK-02 -> UrgencyLevel + ConditionFlags)
   └── returns immutable <Module>SessionResult
   │
   ├──► IF Emergency (G-37: PHQ-9 item 9 > 0 or Stroke FAST or SpO2<92/HR/Shock):
   │       mind_capture_screen / vitals_screens saves immediately ->
   │       CrisisSupportScreen (S-G14) or EmergencyAlertScreen (S-R02)
   │
   └──► ELSE Navigator.pushReplacement -> *ResultScreen(result: result)
           ├── initState calls AppStateScope.of(context).save<Module>Session(result)
           │      ├── inserts into <module>Sessions
           │      ├── builds ScreeningSessionRecord -> addScreeningRecord()
           │      ├── merges ConditionFlags into AppState.cases (30-day window)
           │      └── notifyListeners()
           └── renders UrgencyBanner + BandChip + ConfidenceMeter +
               AlgorithmOutputsSection(groups: MarkerReadings.from*(result)) +
               DisclaimerFooter
```

---

## 6. Verification & Playbook for Changes

### 6.1 Commands
- **Static analysis:** `flutter analyze --no-pub` (currently passes with **0 issues**).
- **Full test suite:** `flutter test` (`18` test files covering unit engines, Spec §4/§5/§7/§10 test vectors, guided flows with `fake_async`, member management, hand landmark coordinate mapping, and `360×780` overflow checks; `ui_preview_test.dart` is gated behind `--dart-define=UI_PREVIEW=true`).
- **Regenerate audio assets:** `dart run tool/gen_pacing_wavs.dart`.

### 6.2 Checklist When Adding or Updating a Screening Module
1. Register any new `GateId` / `SemanticBand` / `ScreenSpec` / `ScreeningCatalogueItem` in `enums.dart`, `gate_evaluator.dart`, and `screening_catalogue_item.dart`.
2. Add `AlgorithmCard` & `MarkerSpec` definitions in `MarkerCatalogue` (`marker_catalogue.dart`), and confirmatory investigations in `ConfirmatoryInvestigationsRegistry` (`case_record.dart`) if a new `COND_*` is introduced.
3. Define `<module>_protocol.dart` and `<module>_result.dart` in `lib/core/domain/entities/`.
4. Implement pure Dart algorithms in `lib/core/domain/algorithms/<module>_engines.dart` and pure assembler `build<Module>Session(...)` in `<module>_session_builder.dart` (enforcing `G-23`, `G-24`, `ALG-RSK-02`, and `rangeNotAvailable` for missing norms).
5. Add `MarkerReadings.from<Module>(result)` adapter in `marker_readings.dart` so `AlgorithmOutputsSection` renders all spec markers & `InternalMarkersExpander`.
6. Add `List<<Module>SessionResult>` and `save<Module>Session(...)` to `AppState` (`app_state.dart`), wiring `addScreeningRecord(...)`.
7. Build the 6-file UI under `lib/features/<module>/` using `MirrorTheme` / `MirrorSpace` / `MirrorWidgets` and wire routing in `MainShellScreen._openCatalogueItem` (`main_shell_screen.dart`).
8. Add `<module>_engines_test.dart` and `<module>_flow_test.dart` in `test/`, then run `flutter analyze --no-pub` and `flutter test`.
