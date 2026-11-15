# 16 — Open Questions, Missing Master Documents, and Explicit Assumptions

> **Rule:** Nothing in this list was silently invented as a clinical requirement. Every item below was identified by comparing the provided *Algorithm Specifications & Test Cards* document against what a full production app needs, and is isolated behind config/mock interfaces (`[OPEN]` / `[MOCK]`).

---

## 1. Referenced Documents Not Yet Provided in `Docs/`

| Missing Reference | Where Referenced in Spec | Impact on App & Current Mitigation |
|---|---|---|
| **Master Data, Algorithms & Data Dictionary** (`mst_algorithm`, `mst_quality_threshold`, `mst_reference_range`, `mst_condition`, `mst_growth_reference`, `mst_confirmatory_test`, `mst_pathway`, `mst_device_model`) | §1, §4.3, §4.5, §4.6, §5 FRM-12, §10, §13, §14 | Seeded in `lib/core/config/master_data_registry.dart` with the exact defaults documented in the Spec; non-documented age/cohort tables display `"Reference range not yet available"`. |
| **Functional Requirements Specification (FRS)** (e.g. `FRS 12.4`, `FRS REF-03`, `FRS REF-06`) | §7.2 `ALG-DEN-06`, §14 | Caries-risk rule `BR-DEN` implements the 6 explicit test vectors from §7.3; pairing grades A–D (`REF-06`) and 5% monthly negative sampling (`REF-03`) are modelled in `S-R06` / `S-R07`. |
| **Algorithm Accuracy Register** | §1 | Represented in `S-I05 About & Algorithm Versions` with per-algorithm release status (`G-24`). |
| **Complete Business Rule Catalogue** (`BR-VIT-01..06`, `BR-SCR-01..04`, `BR-QUA-01`, `BR-DEN`) | §7.2, §10 | `RiskEngine` implements all 16 explicit rule test cases (`T1`–`T16`) and threshold triggers from §4 and §13. |

---

## 2. Specific Clinical & Product Open Questions (`Q-xx`)

| ID | Topic | Question for Clinical Safety Lead / Product Owner | Safe Default Used in Phase 1 UI |
|---|---|---|---|
| `Q-AUTH` | Authentication & Accounts | Does VitalsMirror use mobile OTP, ABHA ID, email, or enterprise SSO for Members and Field Operators? | Mobile + 6-digit OTP UI (`S-A04`, `S-A05`) with replaceable `AuthRepository`. |
| `Q-OPERATOR` | Operator / Camp Workflow | How are school, anganwadi, and clinic sites assigned to Operators, and how is guardian consent captured when parents are not physically present at school camps? | Operator Hub (`S-A08`) requires explicit checkbox `"Guardian present or signed school consent on file"` (`G-05`). |
| `Q-FRM-BP` | BP-Dependent Formulas (`FRM-01..04`) | While `ALG-BP-01` is in `bandOnly` mode (`SBP`/`DBP` numbers internal until ISO 81060-2 validation passes), should `MAP`, `PP`, `Shock Index`, and `RPP` be hidden from the member UI or computed only when a recent cuff calibration (`S-D10`) is entered? | Shown in `Demo/Validated` preview with clear badge; gated by `G-24` (`BP numeric release`) in strict production mode. |
| `Q-SHOCK` | Shock Index Thresholds | Spec §5 gives normal `0.5–0.7` and `T4: 0.79 → None`, `T5: 1.05 → Emergency`, while §13.1 gives trigger `> 0.9 → Emergency`. What is the band label for `0.71–0.90`? | `0.50–0.70` Normal, `0.71–0.90` Borderline (no urgency flag per `T4`), `> 0.90` Critical / Emergency (`BR-VIT-01` per §13.1 & `T5`). |
| `Q-COHORT` | Pending Cohort Reference Tables | When will the Mayura healthy cohort tables for HRV age bands (§4.3), Waveform age bands (§4.8), VO2max age/sex (§5), Cognitive norms (§8 AUD-10), and Movement/Reaction age norms (§9) be finalized? | UI displays the measured value + `"Reference range not yet available"` chip; never guesses cut-offs. |
| `Q-QUEST` | Questionnaire Item Wording | Exact item lists and scoring rules for `Q_TB_SYMPTOMS` (§8 AUD-03), `Q_MMRC` & `Q_EXPOSURE` (§8 AUD-04), and full `Q_CARIES_RISK` (§7.2) in English, Telugu, and Hindi. | Config-driven `QuestionCard` items matching standard mMRC (0–4), WHO TB 4-symptom screen, and §7.3 caries habits. |
| `Q-STROKE` | Stroke Sub-Test Thresholds | Exact numeric cut-offs for `FACE_ASYM_SCORE`, `ARM_DRIFT_L/R`, and `SPEECH_ABN_PROB` (§9 `MOV-06..08`). | Configurable thresholds in `mst_quality_threshold`; any positive sub-sign triggers `STROKE_POSITIVE` → `S-R02 Emergency` (`T10`). |
| `Q-RING` | Smart Ring & Fundus Hardware | Which specific Smart Ring vendor/BLE GATT profile and clip-on Fundus Camera SDK (`Medios AI` adapter) are targeted for initial launch? | Abstracted behind `DeviceIntegrationRepository` on `S-I01`, `S-I02`, and `S-E06`. |
| `Q-HELPLINE` | Emergency & Crisis Numbers | Which regional emergency numbers (`108` / `112`) and mental-health crisis helplines (`S-G14` for `PHQ-9 item 9 > 0`) should be pre-configured? | Displays `108 / 112` Emergency and `Tele-MANAS 14416` crisis helpline as configurable constants. |
