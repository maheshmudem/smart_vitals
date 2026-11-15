# 14 — Development Roadmap

> **Purpose:** Sequenced execution plan from requirement analysis and documentation through full Flutter UI implementation, deterministic algorithm integration, and automated test verification.

---

## 1. Phase Breakdown

| Phase | Milestone | Key Deliverables | Status |
|---|---|---|---|
| **Phase 1** | Complete Document Analysis | Full extraction and structured mapping of all 14 Spec sections (`ALG-CAP`, `ALG-PUL`, `§4` Vitals, `ALG-FRM`, `ALG-IMG`, `ALG-DEN`, `ALG-AUD`, `ALG-MOV`, `ALG-RSK`, `§11–14`) | Completed |
| **Phase 2** | Complete Application Documentation | 17 permanent technical reference documents (`00_README_Index.md` … `16_Open_Questions_and_Assumptions.md`) | Completed |
| **Phase 3** | Screen-by-Screen UI/UX Planning | All **82 screens** (`S-A01`…`S-I05`) + 8 image configurations + "Mirror" Design System documented in `05_UI_UX_Screen_Documentation.md` and `06_User_Flows_and_Navigation.md` | Completed |
| **Phase 4** | Feature Gates & Lifecycle Specification | All **37 gates (`G-01`…`G-37`)** and **38 features (`F-01`…`F-38`)** state machines documented in `07_Feature_Lifecycle_and_States.md` | Completed |
| **Phase 5** | Flutter Application Architecture | Feature-first Clean Architecture (`lib/core` + `lib/features`) documented in `13_Flutter_Architecture.md` | Completed |
| **Phase 6** | AI/ML & Deterministic Algorithm Engine | Domain implementations of `ALG-CAP-01..15`, `ALG-HRV-01..04`, `ALG-FRM-01..15`, `ALG-DEN-06`, and `ALG-RSK-01..07` + mock interfaces for trained models | In Progress |
| **Phase 7** | Full Flutter UI Implementation | Theme, Design System components, Gate/Lifecycle Evaluator, and all **82 screens** across Groups A–I & R | In Progress |
| **Phase 8** | Testing & Quality Assurance | Unit tests for all Spec test vectors (HRV, Baevsky, FRM-01..15, Caries Cases 1–6, Risk Cases T1–T16), widget tests, and `flutter analyze` zero-error check | Planned |
| **Phase 9** | Clinical Model & Backend Integration (Post-UI) | Native camera/audio DSP plugins, TFLite `EfficientPhys` (`ALG-PUL-05`), Mayura clinical validation studies (`VIT-*`, `IMG-*`, `DEN-01`, `AUD-*`, `MOV-*`), live REST APIs | Future Phase |

---

## 2. Implementation Sequence (Inside Phase 6–8)

```mermaid
flowchart TD
  M1["1. Core Domain & Master Data<br/>(Enums, MarkerEnvelope, mst_* tables, GateEvaluator G-01..G-37)"] --> M2["2. Deterministic Algorithms<br/>(ALG-CAP, HRV, Baevsky, FRM-01..15, Caries DEN-06, Risk RSK-01..07)"]
  M2 --> M3["3. Mirror Design System<br/>(Theme, BandChip, UrgencyBanner, MetricTile, QualityChecklist, CaptureFrame, ToothChart)"]
  M3 --> M4["4. Access, Consent, Profile & Main Shell<br/>(S-A01..A08, S-B01..B07, S-C01..C07)"]
  M4 --> M5["5. Vitals & Functional Cardio Flows<br/>(S-D01..D13)"]
  M5 --> M6["6. Image (x8), Fundus & Dental Flows<br/>(S-E01..E06, S-F01..F05)"]
  M6 --> M7["7. Audio, Sleep, Hearing, Mind & Movement/Vision Flows<br/>(S-G01..G15, S-H01..H10)"]
  M7 --> M8["8. Results, Emergency/Urgent Alerts, Cases, Lab Pairing & Settings<br/>(S-R01..R07, S-I01..I05)"]
  M8 --> M9["9. Automated Unit & Widget Test Suite + flutter analyze"]
```
