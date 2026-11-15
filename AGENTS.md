# AGENTS.md — VitalsMirror (`algoritam`) Agent Guide

> Read this file first before modifying code in `d:\algoritam`.
> For the complete file-by-file symbol catalog, algorithm details, and data flows, see [PROJECT_KNOWLEDGE.md](file:///d:/algoritam/PROJECT_KNOWLEDGE.md).
> For the clinical spec registry (`F-xx`, `S-xx`, `G-xx`, `ALG-xxx`), see [Docs/00_README_Index.md](file:///d:/algoritam/Docs/00_README_Index.md) and [DEVELOPMENT_PROGRESS.md](file:///d:/algoritam/DEVELOPMENT_PROGRESS.md).

---

## 1. Project Snapshot & Tech Stack

- **Package:** `algoritam` (VitalsMirror — Clinical & Wellness Screening)
- **Toolchain:** Flutter `3.44.9` (stable), Dart `^3.12.2`, `flutter_lints: ^6.0.0`
- **State Management:** Pure Flutter `AppState` (`ChangeNotifier`) + `AppStateScope` (`InheritedNotifier`) in `lib/core/state/app_state.dart` — **no** Riverpod/Bloc/Provider packages.
- **Navigation:** Imperative `Navigator.of(context).push(MaterialPageRoute(...))` from `MainShellScreen` (`lib/features/shell/main_shell_screen.dart`). Note: `Docs/13_Flutter_Architecture.md` mentions `lib/app.dart` and `lib/core/router/`, which do not exist in the actual codebase; `lib/main.dart` mounts `MainShellScreen` directly.
- **Persistence:** In-memory only (seeded in `AppState._seedInitialData()` with 5 family profiles, initial vitals/dental sessions, and sample cases). No DB/API client is wired yet.

---

## 2. Non-Negotiable Clinical & Safety Rules

1. **Screening, Never Diagnosis:** Present outputs only as screening bands (`SemanticBand`) with confirmatory tests from `ConfirmatoryInvestigationsRegistry` (`lib/core/domain/entities/case_record.dart`) and `DisclaimerFooter`.
2. **Never Invent Clinical Thresholds:** If cohort norms are not defined in the Spec, emit `SemanticBand.rangeNotAvailable` / `MarkerDisplayStatus.rangeNotAvailable` (`"Reference range not yet available"`).
3. **Pulse Quality Guard (`ALG-PUL-09` / `BR-QUA-01` / Case `T16`):** Any pulse scan with `pulse_snr_db < 3.0` or `clean_beat_count < 20` **must** require retake (`retakeRequired = true`, `MarkerDisplayStatus.qualityRetakeRequired`) and emit zero clinical flags.
4. **Confidence Gate (`G-23` / `ALG-RSK-06`):** `confidence = captureQualityScore * modelConfidence * (context ? 0.8 : 1.0)`. Markers with `confidence < 0.60` must be hidden (`MarkerDisplayStatus.lowConfidenceHidden`).
5. **Release Status Gate (`G-24`):**
   - `SBP` / `DBP` remain `internalUntilValidated` until `appState.bpNumericValidatedRelease == true`.
   - Internal markers (`HB_EST`, `ANAEMIA_PROB`, `TB_PROB`, `OAD_PROB`, `MOOD_VOICE_SCORE`, `IRREG_PROB`, `HR_POS`, `RR_RIIV`) stay `MarkerDisplay.internal` / `MarkerDisplayStatus.internalOnly` (rendered only in `InternalMarkersExpander`).
6. **Specialist Review (`IMG-10`):** Image probabilities within `±0.10` of threshold `τ` (or `high` band) set `specialistReviewRequired = true` (`MarkerDisplayStatus.underSpecialistReview`).
7. **Safety Escalation Override (`G-37`):** Emergency states (`PHQ-9 item 9 > 0` -> `CrisisSupportScreen` `S-G14`; Stroke FAST / `SpO2 < 92%` / `HR < 40` or `> 130` / `RR < 8` or `> 24` / `Shock Index > 0.90` -> `EmergencyAlertScreen` `S-R02`) must save immediately and pre-empt normal result screens.
8. **30-Day Case Merging (`ALG-RSK-07`):** Always route flagged sessions through `AppState.addScreeningRecord(..., conditionCode: ...)` -> `RiskEngine.mergeFlagsIntoCases(...)` so same-subject, same-condition flags within 30 days merge into one `CaseRecord` sorted `Emergency > Urgent > Routine`.

---

## 3. Architecture & Directory Map (`136` files in `lib/`, `18` in `test/`)

- `lib/main.dart` — App entry (`VitalsMirrorApp`, `AppStateScope`, `MainShellScreen`).
- `lib/core/design_system/` — `mirror_theme.dart` (`MirrorColors`, `MirrorSpace`, `MirrorRadius`, `BandVisualStyle`, `MirrorTheme`), `mirror_ui.dart`, `mirror_widgets.dart` (`BandChip`, `UrgencyBanner`, `ConfidenceMeter`, `MetricTile`, `GateBlockerCard`, `DisclaimerFooter`, `showScreenGateLifecycleSheet`), `mirror_motion.dart`, `algorithm_outputs_section.dart` (`AlgorithmOutputsSection`).
- `lib/core/domain/entities/` — `enums.dart`, `member_profile.dart`, `marker_envelope.dart`, `marker_catalogue.dart` (44 `AlgorithmCard`s), `screening_catalogue_item.dart` (34 `cat_*` items, 83 `ScreenSpec`s), `health_package.dart` (8 `pkg_*` bundles), `case_record.dart` (31 `COND_*` specs), and module `*_protocol.dart` / `*_result.dart` files.
- `lib/core/domain/algorithms/` — Pure Dart DSP/math/ML engines (`*_engines.dart`, `formulas_engine.dart`, `hrv_baevsky_engine.dart`, `caries_risk_engine.dart`, `capture_quality_engine.dart`, `photo_quality_analyzer.dart`, `neonatal_bilirubin_chart.dart`, `fft.dart`), 7 `build*Session` builders (`*_session_builder.dart`), `risk_engine.dart`, and `marker_readings.dart`.
- `lib/core/domain/gates/` — `gate_evaluator.dart` (`G-01`..`G-37`).
- `lib/core/services/` — 20 hardware/OS services (`live_camera_service.dart`, `voice_coach_service.dart`, `hand_tracking_service.dart`, `motion_sensor_service.dart`, `breath_audio_service.dart`, `ambient_noise_service.dart`, `mic_self_check_service.dart`, `sleep_sonar_service.dart`, `hearing_tone_service.dart`, etc.) with safe desktop/test fallbacks.
- `lib/core/state/app_state.dart` — Central `AppState` & `AppStateScope`.
- `lib/features/` — Active feature modules: `shell/`, `vitals/`, `anaemia/`, `eye_screens/`, `breath/`, `hearing/`, `mind/`, `movement/`, `sleep/`, `vision/`, `members/`, `results_cases/`, `access_profile_settings/`; plus legacy/fallback files in `image_screening/`, `dental/`, `audio_screening/`, `movement_vision/`.

---

## 4. Naming Conventions Cheatsheet

- **Registry IDs:** `F-01..38` (features), `S-A01..S-I05` & `S-R01..07` (screens), `G-01..37` (gates), `ALG-*` & `IMG-10` (algorithm cards), `COND_*` (conditions), `BR-*` & `T1..T42` (risk rules), `cat_*` (catalogue items), `pkg_*` (health packages).
- **Module File Pattern:**
  - Entities: `<module>_protocol.dart`, `<module>_result.dart`
  - Domain: `<module>_engines.dart`, `<module>_session_builder.dart` (exports `build<Module>Session(...)`)
  - UI: `<module>_intro_screen.dart`, `<module>_capture_screen.dart`, `<module>_run_controller.dart` (`<Module>RunController extends ChangeNotifier`), `<module>_result_screen.dart`, `<module>_illustrations.dart`, `<module>_task_views.dart`
  - Tests: `test/<module>_engines_test.dart`, `test/<module>_flow_test.dart`
- **Marker Codes:** `UPPER_SNAKE_CASE` for spec clinical markers (`HR`, `BAEVSKY_SI`, `FEV1`, `AHI_EST`, `PHQ9`), `lower_snake_case` for formula/quality fields (`map_mmhg`, `pulse_snr_db`, `face_distance_cm`). Append `_L` / `_R` for side-specific envelopes so `MarkerReadings._sideOf` pairs them automatically.

---

## 5. Adding or Modifying a Module (Standard Pattern)

1. Keep all math/DSP/clinical rules pure in `lib/core/domain/algorithms/` (never inside widgets).
2. Register cards/markers in `MarkerCatalogue` (`marker_catalogue.dart`) and expose them via `MarkerReadings.from<Module>(result)` (`marker_readings.dart`) so every result screen renders `AlgorithmOutputsSection`.
3. Persist via `AppState.save<Module>Session(result)` (`app_state.dart`) -> `addScreeningRecord(...)` (handles `ScreeningSessionRecord` + 30-day `CaseRecord` merge).
4. Wire catalogue dispatch in `MainShellScreen._openCatalogueItem` (and `PackageDetailAndRunnerScreen` if included in a package).
5. Use `MirrorTheme` / `MirrorColors` / `MirrorSpace` / `MirrorWidgets` — avoid hardcoded theme colors in feature screens.

---

## 6. Verification Commands

```powershell
# Static analysis (must report 0 issues)
flutter analyze --no-pub

# Run unit & widget test suite
flutter test

# Regenerate assets/audio/*.wav if pacing or hearing tones change
dart run tool/gen_pacing_wavs.dart
```
