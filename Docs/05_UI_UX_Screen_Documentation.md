# 05 — UI/UX Screen Documentation

> **How to use this document:** find the screen ID (registry in `00_README_Index.md §5`), jump to its card.
> Each card follows the same 13-point template. Gates (`G-xx`) are fully defined in `07_Feature_Lifecycle_and_States.md`.
> Readings/bands are defined in `08_Health_Readings_and_Metrics.md`; algorithms in `09_AI_ML_Algorithm_Documentation.md`.

---

# Part 1 — Design System ("Mirror" design language)

## 1.1 Design principles

| Principle | What it means in practice |
|---|---|
| **Calm clinical confidence** | Generous white space, soft surfaces, one primary action per screen, no visual noise during capture |
| **Guidance over instruction** | Live, plain-language coaching during capture ("Hold still") rather than long text before it |
| **Honest results** | Bands + confidence + "what to do next". Never a bare number without context; never "diagnosis" language |
| **Safety is loud, everything else is quiet** | Only emergency/urgent states use saturated red/amber full-width banners |
| **Accessible by default** | WCAG 2.2 AA contrast, ≥ 48 dp touch targets, dynamic type to 200%, screen-reader labels, colour never the only signal (icons + text on every band) |
| **Consistent templates** | Every capture uses the *Capture template*; every result uses the *Result template*; every gate uses the *Gate blocker* |

## 1.2 Colour tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `primary` | `#0B7A75` (deep teal) | `#4FD1C5` | Primary actions, active nav, focus |
| `primaryContainer` | `#D7F2EF` | `#0E3B39` | Tonal buttons, selected chips |
| `secondary` | `#4C5BD4` (indigo) | `#A5B0FF` | Charts, secondary accents |
| `background` | `#F5F7FA` | `#0D1117` | Scaffold |
| `surface` | `#FFFFFF` | `#161B22` | Cards, sheets |
| `surfaceVariant` | `#EEF2F6` | `#1F2630` | Inputs, inactive tiles |
| `ink` / `onSurface` | `#0F172A` | `#E6EDF3` | Primary text |
| `inkMuted` | `#5B6B7F` | `#9AA7B4` | Secondary text |
| `outline` | `#DCE3EA` | `#2D3642` | Dividers, borders |
| **Semantic** | | | |
| `success` (normal / low risk / regular) | `#15803D` on `#DCFCE7` | `#4ADE80` on `#0F2E1C` | Normal band |
| `warning` (borderline / elevated / moderate / mild / prediabetes risk) | `#B45309` on `#FEF3C7` | `#FBBF24` on `#3A2A0A` | Borderline band, routine follow-up |
| `danger` (critical / high / severe / irregular / diabetes risk) | `#B91C1C` on `#FEE2E2` | `#F87171` on `#3B1111` | Critical band, urgent |
| `emergency` | `#FFFFFF` on `#B91C1C` (solid) | same | Emergency banner & S-R02 only |
| `info` | `#1D4ED8` on `#DBEAFE` | `#93C5FD` on `#0F1F3D` | Tips, "in validation" |
| `neutral` (not assessed / not available / hidden) | `#475569` on `#E2E8F0` | `#94A3B8` on `#1E293B` | Missing results |

Band → token mapping is defined once in code (`BandStyle`) and referenced everywhere (see doc 08 "Band colour semantics").

## 1.3 Typography (font: **Plus Jakarta Sans**, fallback system sans; numerals tabular)

| Style | Size / line / weight | Use |
|---|---|---|
| `displayLarge` | 44 / 52 / 700 | Hero metric value (e.g. HR "72") |
| `headlineMedium` | 28 / 36 / 700 | Screen titles on large headers |
| `titleLarge` | 22 / 28 / 600 | App bar titles, section headers |
| `titleMedium` | 17 / 24 / 600 | Card titles |
| `bodyLarge` | 16 / 24 / 400 | Body text |
| `bodyMedium` | 14 / 20 / 400 | Secondary text |
| `labelLarge` | 15 / 20 / 600 | Buttons |
| `labelSmall` | 12 / 16 / 600, +0.4 tracking | Chips, captions, units |

## 1.4 Spacing, shape, elevation, motion

| Token | Values |
|---|---|
| Spacing (4-pt grid) | `xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32 · huge 48` |
| Screen padding | 20 horizontal (phones), 32 (≥ 600 dp), content max-width 720 |
| Radius | `sm 8` (chips) · `md 12` (inputs, buttons) · `lg 16` (cards) · `xl 24` (sheets, hero cards) · `full` (pills) |
| Elevation | Flat surfaces with 1 px `outline` border; floating elements use soft shadow `0 8 24 rgba(15,23,42,.06)` |
| Motion | 200 ms standard ease-out; 300 ms page transitions; capture rings animate continuously; reduce-motion honoured |
| Icons | Material Symbols Rounded, 24 dp; filled when selected |

## 1.5 Component library (all in `lib/core/design_system/`)

| Component | Purpose | Variants / notes |
|---|---|---|
| `VmButton` | All buttons | primary · tonal · outline · text · danger; `loading` state; full-width default on mobile |
| `VmCard` | Surface container | default · tappable · hero (gradient) · outlined |
| `VmAppBar` | Top bar | large-title collapsing · compact · transparent (capture) |
| `VmSectionHeader` | Section title + optional action | — |
| `VmListTile` | Navigation row | leading icon tile, title, subtitle, trailing chevron / chip |
| `BandChip` | Shows a band | colour + icon + text from `BandStyle`; never colour-only |
| `UrgencyBanner` | Emergency / urgent / routine banner | emergency is solid red full width, with call action |
| `MetricTile` | Marker value tile | value, unit, band chip, confidence, status (hidden / not available / in validation) |
| `ConfidenceMeter` | Result confidence 0–1 | segmented bar + label (Low < 0.6 hidden by G-23) |
| `QualityChecklist` | Live capture checks | rows: pending → passing → failing with coaching text |
| `CaptureFrame` | Camera overlay | face oval, finger circle, body-part outline, tooth arch, card target |
| `CountdownRing` | Recording progress | seconds remaining, pauses when quality fails |
| `StepIndicator` | Multi-step flows | dots / "Step 2 of 4" |
| `GateBlocker` | Explains why something is unavailable | icon, title, reason, primary fix action, secondary "learn more" |
| `StateView` | Loading / empty / error / success | consistent illustrations + retry |
| `DisclaimerNote` | "Screening, not diagnosis" | compact & full variants |
| `VmTextField`, `VmDropdown`, `VmSegmented`, `VmDatePicker`, `VmUnitField` | Inputs | inline validation, helper text, unit suffix |
| `QuestionCard` | Questionnaires | single/multi choice, scale, numeric |
| `WaveformView` | Pulse / breath waveform | CustomPainter, live or static |
| `TrendSparkline` | Mini trend | baseline band shading (RSK-03) |
| `ToothChart` | FDI chart | primary / mixed / permanent dentition |
| `VmBottomSheet`, `VmDialog`, `VmSnackbar` | Overlays | — |

## 1.6 Global UI rules

1. **One primary action** per screen, pinned to the bottom safe area on flows.
2. **Every result** = value or band + `BandChip` + `ConfidenceMeter` + "What this means" + "Next step" + `DisclaimerNote`.
3. **Hidden ≠ removed:** a result hidden by a gate still shows a `MetricTile` in *status* form ("HRV not available — needs 50 clean beats") so the user understands why.
4. **Capture screens** are immersive (dark, transparent app bar, no bottom nav), keep the screen awake, and lock orientation to portrait.
5. **Empty states** always offer the next useful action (e.g. "Start your first vitals scan").
6. **Errors** are human, specific and actionable (message table in doc 12); never raw exception text.
7. **Units** shown next to values in `labelSmall`, never inside the number.
8. **Mock banner:** in dev builds, any screen using `[MOCK]` data shows a small "Demo data" chip in the app bar.

---

# Part 2 — Shared Templates

## T-CAP — Capture template (used by S-D03, S-D04, S-E03, S-F03, S-G03…05, S-G10, S-G12, S-H01…H10)

```
┌──────────────────────────────┐
│ ✕  Title         Step 2/4  ⓘ │  transparent app bar
│                              │
│      [ camera / visual ]     │  CaptureFrame overlay (oval / circle / outline)
│                              │
│  ● Face found ✓              │  QualityChecklist (live, ALG-CAP)
│  ● Light ✓   ● Hold still ⟳  │
│                              │
│   "Hold still"               │  Coaching line (largest failing check)
│      ( 42 s )                │  CountdownRing — pauses on fail
│ [   Start / Pause / Stop   ] │
└──────────────────────────────┘
```

**Lifecycle (template):** `idle → preparing (camera/mic init) → aligning (checks running, not recording) → recording (all checks pass) ⇄ paused (a check fails; coaching shown; timer paused or restarted per check rule) → captured → (upload/process)`; exit on ✕ asks for confirmation and discards the capture.

## T-RES — Result template (S-D07, S-R01, S-F04, S-G06, S-G09, S-G11 …)

```
┌──────────────────────────────┐
│ ←  Result title          ⋮   │
│ [UrgencyBanner if any]       │
│ ╭ Hero card ───────────────╮ │
│ │ Band chip  · confidence  │ │
│ │ Big value / band name    │ │
│ │ "What this means" (1–2 l)│ │
│ ╰──────────────────────────╯ │
│ Markers grid (MetricTile…)   │
│ Next steps (confirmatory     │
│   tests from §13)            │
│ Quality & versions (expand)  │
│ DisclaimerNote               │
│ [ Done ]  [ Share / Save ]   │
└──────────────────────────────┘
```

## T-GATE — Gate blocker

Shown full-screen or as a bottom sheet whenever a gate (`G-xx`) blocks entry. Contents: icon, gate-specific title, plain reason, **primary fix action** (e.g. "Allow camera", "Complete profile", "Sign consent", "Move to a quieter room"), secondary "Not now". Permission-denied-forever state switches the action to "Open settings".

---

# Part 3 — Screen Cards

Template for every card: **1** Purpose · **2** Role/access · **3** Entry & path · **4** Layout & hierarchy · **5** Information shown · **6** Data required · **7** Interactions · **8** States · **9** Validation & permissions · **10** Gates · **11** Navigation destinations · **12** Dependencies · **13** Lifecycle & state management.

---

## A. Access & Onboarding

### S-A01 Splash & Bootstrap — [STD]
1. **Purpose:** Brand moment while restoring session, loading cached master data (F-36), device profile (F-07).
2. **Role:** Everyone, unauthenticated.
3. **Entry:** App launch / cold start.
4. **Layout:** Centered logo mark (mirror + pulse line), product name, subtle progress dot animation; version label bottom.
5. **Shows:** Logo, app version.
6. **Data:** Secure storage (token), local DB (cached masters + versions), device model id.
7. **Interactions:** None.
8. **States:** loading → (success: route) / error (corrupt cache → clear and continue; no network is **not** an error).
9. **Validation:** Token expiry check.
10. **Gates:** G-01 decides route; G-36 non-blocking.
11. **Navigation:** first run → S-A02; signed-out → S-A03; signed-in but profile incomplete → S-B03; consent missing → S-B01; else → S-C01.
12. **Dependencies:** F-01, F-36, F-07.
13. **Lifecycle:** `AppBootstrapController` (async init, max 2.5 s visible; never blocks on network).

### S-A02 Language Selection — [DER]
1. **Purpose:** Choose UI language (English / తెలుగు / हिन्दी) — also the speech-recognition language for AUD-10.
2. **Role:** All. 3. **Entry:** First run; Settings → Language.
4. **Layout:** Title "Choose your language", three large selectable cards with native script + English name, primary "Continue".
5. **Shows:** Languages. 6. **Data:** Local preference.
7. **Interactions:** Select → Continue. 8. **States:** ready / selected.
9. **Validation:** One selection required.
10. **Gates:** none. 11. **Navigation:** → S-A03 (first run) or back (from settings).
12. **Dependencies:** F-02. 13. **Lifecycle:** `LocaleController` (persisted).

### S-A03 Welcome / Intro — [STD]
1. **Purpose:** Explain value and the safety position ("screening, not diagnosis") in 3 swipeable panels.
2. **Role:** Unauthenticated. 3. **Entry:** After S-A02 or on sign-out.
4. **Layout:** Illustration carousel (Scan vitals with your face · Screen eyes, teeth, voice & movement · Know what to do next), page dots, primary "Get started", text "I already have an account".
5–6. Static content. 7. Swipe / skip. 8. ready.
9. — 10. — 11. → S-A04. 12. F-01. 13. Stateless.

### S-A04 Sign In — [STD/OPEN]
1. **Purpose:** Identify the user (mobile-number OTP assumed — see Q-AUTH in doc 16).
2. **Role:** Unauthenticated.
3. **Entry:** S-A03.
4. **Layout:** Title, country code + phone `VmTextField`, terms/privacy text links, primary "Send code".
5. **Shows:** Input, legal links.
6. **Data:** `POST /auth/otp/request` [MOCK].
7. **Interactions:** Enter number, submit.
8. **States:** ready → loading → success (→ S-A05) / error (invalid number, rate-limited, network).
9. **Validation:** 10-digit Indian mobile (configurable), required consent to terms.
10. **Gates:** G-36 (network required).
11. **Navigation:** → S-A05. 12. F-01. 13. `SignInController` (form state).

### S-A05 OTP Verification — [STD/OPEN]
1. **Purpose:** Verify the code and create a session.
4. **Layout:** "Enter the 6-digit code sent to +91 …", 6-box OTP input (autofill), resend timer (30 s), primary "Verify".
6. **Data:** `POST /auth/otp/verify` → tokens stored in secure storage.
8. **States:** ready → verifying → success / error (wrong code, expired code, too many attempts → locked 15 min [OPEN]).
9. **Validation:** 6 digits.
10. **Gates:** G-36. 11. **Navigation:** new user → S-A06; returning → S-A01 routing logic.
13. `OtpController` (timer, attempts).

### S-A06 Mode Selection — [DER/OPEN]
1. **Purpose:** Choose *"For me & my family"* (Member/Guardian) or *"I screen others"* (Operator — requires operator authorisation).
4. **Layout:** Two large cards with icon, title, 1-line description; primary "Continue".
6. **Data:** user.roles from backend; operator option disabled with explanation if not authorised.
8. **States:** ready / operator-not-authorised (GateBlocker inline).
11. **Navigation:** Member → S-A07 → S-B01; Operator → S-A07 → S-A08.
12. F-06. 13. `SessionController.mode`.

### S-A07 Permissions Primer — [DER]
1. **Purpose:** Explain *why* camera, microphone, motion sensors, notifications and Bluetooth are needed **before** OS prompts (OS prompts are requested just-in-time, not here — this screen only explains and optionally pre-grants camera+mic).
4. **Layout:** List of permission rows (icon, name, reason, status chip: Not asked / Allowed / Denied), primary "Allow camera & microphone", text "Later".
6. **Data:** permission_handler status.
8. **States:** per-permission: notRequested / granted / denied / permanentlyDenied / restricted.
9. **Permissions:** G-11, G-12 (optional here), G-13, G-14, G-15 informational.
11. **Navigation:** → S-B01 (member) or S-A08 (operator).
13. `PermissionController` (re-checks on app resume).

### S-A08 Operator — Participant Search & Register — [OPEN]
1. **Purpose:** Operator finds or registers the participant being screened, then runs screenings on their behalf.
4. **Layout:** Site selector (school / anganwadi / clinic), search field (name / ID / phone), recent participants list, FAB "Register participant" (opens S-B03 in operator context), queued-uploads indicator.
6. **Data:** site list, participant search API [MOCK], offline queue count.
8. **States:** loading / empty ("No participants yet") / results / offline (search local cache only) / error.
9. **Validation:** Participant must have consent (G-04, G-05 for children) captured by operator with guardian present.
11. **Navigation:** participant → S-C02 (catalogue scoped to participant); register → S-B03 → S-B02.
12. F-06, F-03, F-04. 13. `OperatorSessionController` (active participant, site).

---

## B. Consent & Profile

### S-B01 Consent Center — [DOC]
1. **Purpose:** One place to see and sign every consent the Spec requires: **Screening** (required for all image screens — Spec §6 intro; adopted for all screenings [DER]), **Dental** (guardian for children — §7.1), **Training-data use** (optional; only training-consented records build models — §11.2), **Clinician pathway** (mood — §8 AUD-11, enabled by clinician), **HF programme** (§8 AUD-12, enrolment).
2. **Role:** Member, Guardian (per dependent), Operator (with participant).
3. **Entry:** After onboarding; Profile → Consents; any GateBlocker for G-04/G-05/G-06.
4. **Layout:** Header "Your consents" + person switcher (self / dependents); list of `VmListTile` per consent with status chip (Required · Signed · Optional · Not offered · Withdrawn) and date; primary "Continue" (enabled when required consents signed).
5. **Shows:** consent name, purpose line, status, version, signed date.
6. **Data:** `GET /members/{id}/consents`, consent document versions (master).
7. **Interactions:** Tap → S-B02. Continue.
8. **States:** loading / ready / error (retry) / offline (shows cached; signing queued).
9. **Validation:** Screening consent required to proceed to screening; others optional.
10. **Gates:** G-04, G-05, G-06, G-07 (display only), G-08 (display only).
11. **Navigation:** → S-B02; Continue → S-B03 (first run) or back.
12. F-03. 13. `ConsentController` (per member, versioned; re-consent if document version changes).

### S-B02 Consent Detail & Sign — [DOC]
1. **Purpose:** Read and sign a specific consent; capture guardian identity for children.
4. **Layout:** Title, version & date, scrollable plain-language sections (what we collect, why, who sees it, how long, withdrawal), key points summary card, checkbox(es) "I have read and agree", guardian block (name, relationship) when subject < 18 y, primary "Sign consent", text "Decline".
6. **Data:** consent document (by type, language, version). `POST /consents`.
7. **Interactions:** Must scroll to end to enable checkbox [DER]; sign; decline.
8. **States:** loading / ready / signing / signed (success toast, back) / error.
9. **Validation:** checkbox ticked; guardian fields required when minor; operator mode requires "Guardian present" confirmation.
10. **Gates:** produces G-04/G-05/G-06 = true.
11. **Navigation:** back to S-B01 or to the originally blocked feature (return-to route).
12. F-03. 13. `ConsentSignController`.

### S-B03 Profile Setup — Basics — [DOC]
1. **Purpose:** Collect inputs required by algorithms: **date of birth (age), sex, height, weight** — required by BP (§4.6 preconditions), FRM-06…11, AUD-05, IMG-01 thresholds.
2. **Role:** Member, Guardian (for dependent), Operator (for participant).
3. **Entry:** First run after consent; G-02 GateBlocker; Profile edit.
4. **Layout:** StepIndicator (1/2), fields: Full name, Date of birth (`VmDatePicker`), Sex (segmented: Male / Female — Spec formulas need binary sex; see Q-SEX), Height (`VmUnitField` cm / ft-in), Weight (kg / lb); live BMI preview card (FRM-09) with band chip; primary "Continue".
5. **Shows:** inputs, live BMI.
6. **Data:** local draft; `PUT /members/{id}/profile`.
7. **Interactions:** edit, unit toggle, continue.
8. **States:** ready / validating / saving / saved / error.
9. **Validation:** DOB not in future; age 0–120; height 30–250 cm, weight 1–300 kg (plausibility [DER]); BMI preview only when result within FRM-09 valid range 10–70, else "Please check height and weight".
10. **Gates:** produces G-02.
11. **Navigation:** → S-B04.
12. F-04, F-13. 13. `ProfileFormController` (draft persisted).

### S-B04 Health Context — [DOC]
1. **Purpose:** Extended inputs for risk models and eligibility: waist (DM-01, RSK-05, FRM-10), family history of diabetes (DM-01), activity level (DM-01), pregnancy & gestation (IMG-01 thresholds, RSK-01 ranges), known diabetes (IMG-05 eligibility), tobacco/areca use (IMG-04), education level (AUD-10), known conditions/history (RSK-05).
4. **Layout:** StepIndicator (2/2), grouped cards: *Body* (waist cm, live WHtR FRM-10), *Family & history* (toggles), *Lifestyle* (activity segmented, tobacco/areca), *Women's health* (pregnant? + weeks — only if sex = female and age 10–55 [DER]), *Education* (dropdown); "Skip for now" text button; primary "Save".
5. **Shows:** each field with "Used for: Diabetes risk, Kidney risk…" helper text so users understand why.
6. **Data:** `PUT /members/{id}/health-context`.
8. **States:** ready / saving / saved / error.
9. **Validation:** waist 30–200 cm [DER]; gestation 1–42 weeks.
10. **Gates:** produces G-03, G-10 inputs.
11. **Navigation:** → S-B07 (first run) or back.
12. F-04, F-12, F-16, F-29. 13. `HealthContextController`.

### S-B05 Family Members — [DER]
1. **Purpose:** Manage dependents (children 1–12 for child-eye & child dental; newborns 0–28 d for newborn jaundice; other adults [OPEN]).
4. **Layout:** List of member cards (avatar initials, name, age, relationship, consent status), "Add member" button.
8. **States:** loading / empty ("Add a child to use child eye and child dental screens") / list / error.
11. **Navigation:** tap → member profile (S-B03 in edit mode for that member); add → S-B06.
12. F-05. 13. `FamilyController`.

### S-B06 Add / Edit Dependent — [DER]
1. **Purpose:** Create a dependent; for newborns capture **age in hours and gestation** (IMG-07 inputs).
4. **Layout:** Name, relationship, DOB (+ time of birth if < 28 days), sex, gestation weeks (newborn), height/weight (optional for child — needed for FRM-12 growth z-scores), primary "Save & sign consent".
9. **Validation:** DOB ≤ today; newborn time of birth required if age < 28 d.
11. **Navigation:** → S-B02 (guardian consent) → S-B05.
12. F-05, F-03.

### S-B07 Device Readiness Check — [DOC]
1. **Purpose:** Determine what this phone can do: model lookup in `mst_device_model` (SpO2 coefficients, focal length for CAP-15, mic profile for CAP-11, camera fps), and run optional quick checks.
4. **Layout:** Phone illustration + model name; capability checklist rows: Camera 30 fps / 60 fps · SpO2 calibration available · Microphone profile available · Motion sensors · Distance estimation (focal length) — each ✓ / ✕ / "Not calibrated" with which screens are affected; primary "Continue".
6. **Data:** device_info, `GET /device-models/{model}` (cached), camera capability probe.
8. **States:** checking / ready / partially supported (info banner) / unsupported model (warning — SpO2 band hidden, audio tasks may be blocked) / offline (use cached or "unknown").
10. **Gates:** produces G-16 per capability.
11. **Navigation:** → S-C01.
12. F-07. 13. `DeviceCapabilityController` (cached; refreshed on master sync).

---

## C. Main Shell (bottom navigation: Home · Screenings · History · More)

### S-C01 Home Dashboard — [DER]
1. **Purpose:** Daily entry point: start a vitals scan, see urgent items, latest results and what is due.
2. **Role:** Member/Guardian (self or selected dependent).
3. **Entry:** Bottom nav "Home"; after onboarding.
4. **Layout (top→bottom):**
   - Header: greeting + member switcher avatar (self / dependents), notifications bell with badge.
   - **UrgencyBanner** (only if open emergency/urgent case) → S-R05.
   - **Hero card "Vitals scan"**: last scan time, 3 mini MetricTiles (HR, RR, Stress band), primary "Start scan" → S-D01.
   - **Due for you** horizontal cards (scheduled/recommended: e.g. monthly foot check if diabetic (G-34), HF daily voice check (G-08), rhythm confirmation scan (G-27), reference test invitation (S-R07)).
   - **Open cases** summary (count by urgency) → S-R04.
   - **Explore screenings** grid of 6 category tiles → S-C02.
   - **Profile completion** nudge if G-03 incomplete.
6. **Data:** latest session summary, open cases, reminders, profile completeness.
8. **States:** loading (skeletons) / first-use empty (hero "Take your first scan" + education) / ready / partial error (each section independently retryable) / offline (cached, "Last updated …").
10. **Gates:** G-01, G-04 (start buttons show GateBlocker if missing).
11. **Navigation:** S-D01, S-C02, S-R04, S-R05, S-C06, S-C05, S-B04.
12. F-10, F-29, F-30, F-34, F-35. 13. `HomeController` (aggregates repositories; refresh on resume & pull-to-refresh).

### S-C02 Screenings Catalogue — [DER]
1. **Purpose:** Browse every screening, see eligibility and availability at a glance.
4. **Layout:** Search, category chips (Vitals · Eyes · Skin & Body · Dental · Breathing & Voice · Sleep · Hearing · Brain & Mind · Movement · Vision), list of `ScreeningCard` (icon, name, duration, inputs needed e.g. "Camera + colour card", **availability chip**: Available · Recommended · Needs consent · Needs profile · Not for this age · Device not supported · In validation · Coming soon).
6. **Data:** static catalogue config + gate evaluation per member (eligibility engine).
7. **Interactions:** tap available → screening intro; tap blocked → GateBlocker sheet explaining the gate and fix.
8. **States:** ready / filtered-empty / error.
10. **Gates:** evaluates G-02…G-19, G-24, G-35 per item.
11. **Navigation:** S-D01, S-E01 (×8 configs), S-E06, S-F01, S-G01→…, S-G07, S-G10, S-G12, S-G13, S-G15, S-H01…S-H10.
12. All screening features. 13. `CatalogueController` (derives `ScreeningAvailability` per item).

**Catalogue item list (source of truth for the catalogue config):**

| Item | Feature | Category | Eligibility gate (Spec) |
|---|---|---|---|
| Vitals scan (face) | F-10 | Vitals | G-04, G-11 |
| Vitals scan (finger, incl. SpO2 band) | F-11 | Vitals | G-04, G-11, SpO2 needs G-16 |
| BP cuff calibration | F-14 | Vitals | G-02 |
| Orthostatic test | F-15 | Vitals | G-04, G-11 |
| HR recovery test | F-15 | Vitals | G-04, G-11 |
| Anaemia (eyelid) | F-16 | Eyes | G-04; pregnancy affects band |
| Jaundice (eyes) | F-16 | Eyes | G-04 |
| Cataract | F-16 | Eyes | age ≥ 40 or on request (§6.3) |
| Child eye | F-16 | Eyes | age 1–12 (§6.6) |
| Newborn jaundice | F-16 | Skin & Body | age 0–28 d, colour card mandatory (§6.7) |
| Oral check | F-16 | Dental | always offered to tobacco users (§6.4) |
| Diabetic foot | F-16 | Skin & Body | diabetes or high DM risk; monthly (§6.5) |
| Skin check | F-16 | Skin & Body | G-04 (acceptance set after pilot) |
| Fundus (partner camera) | F-17 | Eyes | G-31 |
| Dental check | F-18 | Dental | G-05; child mode 1–12 |
| Cough & TB risk | F-20 | Breathing | G-12, G-17, G-18 |
| Breathing & voice (COPD/asthma) | F-20 | Breathing | G-12, G-17, G-18 |
| Lung function | F-20 | Breathing | G-02 + audio gates |
| Voice quality | F-20 | Breathing | audio gates |
| Sleep check | F-21 | Sleep | G-12, G-30 |
| Hearing check | F-22 | Hearing | G-19, G-18 |
| Memory & speech | F-23 | Brain & Mind | age ≥ 50 (§8 AUD-10) |
| Mood check | F-24 | Brain & Mind | G-07 clinician pathway |
| Heart-failure voice | F-25 | Brain & Mind | G-08 enrolment, daily |
| Finger tapping (video / touch) | F-26 | Movement | G-11 / touch |
| Walk test | F-26 | Movement | G-13 |
| Sit-to-stand | F-26 | Movement | G-13 |
| Tremor | F-26 | Movement | G-13 |
| Parkinson's signs | F-26 | Movement | requires tapping + voice + face (§9 MOV-13) |
| Stroke check (FAST) | F-27 | Brain & Mind | none — always available (safety) |
| Visual acuity | F-28 | Vision | G-33 |
| Colour vision | F-28 | Vision | — |
| Amsler grid | F-28 | Vision | — |
| Reaction time | F-28 | Vision | G-12 for sound stimuli |

### S-C03 History — [DER]
1. **Purpose:** Chronological list of all sessions/results for the selected member.
4. **Layout:** Segmented filter (All · Vitals · Screenings · Tests), month-grouped list; each row: icon, title, date-time, summary band chip(s), status (Processing · Ready · Needs retake · Under specialist review · Not assessed).
8. **States:** loading / empty ("No scans yet" + Start scan) / list / error / paginating.
11. **Navigation:** row → S-C04; trend icon → S-C05.
12. F-34. 13. `HistoryController` (paginated).

### S-C04 Session Detail — [DER]
1. **Purpose:** Re-open any past session in its result template (read-only) with versions used.
4. **Layout:** T-RES for that session type + "Algorithm & range versions" expandable + "Compare with previous" link (dental DEN-07, baseline change RSK-04).
8. **States:** loading / ready / processing (server job pending: progress + "We'll notify you") / failed (retake CTA).
11. **Navigation:** S-D08, S-F05, S-R05.
12. F-34, F-29.

### S-C05 Trends & Baselines — [DOC/DER]
1. **Purpose:** Show each marker over time with **personal baseline** (median of last 3 valid within 180 days, SD from last 10 — RSK-03) and **change flags** (> 15% or > 2 SD — RSK-04).
4. **Layout:** Marker selector chips (HR, RR, RMSSD, SDNN, Stress SI, BP band, Vascular age gap, BMI, Weight…), range tabs (1M · 3M · 6M · 1Y), line chart with baseline band shading and reference band shading, change-flag markers; stats row (latest, baseline, change %).
8. **States:** loading / insufficient data ("Need 3 valid readings to build your baseline" — G-28) / ready / error.
12. F-34, ALG-RSK-03/04. 13. `TrendController(marker, range)`.

### S-C06 Notifications Inbox — [DER]
1. **Purpose:** Reminders and result-ready notices (processing done, specialist review complete, confirmation scan due, monthly foot check, HF daily check, reference-test invitation).
4. **Layout:** list grouped Today / Earlier; unread dot; swipe to dismiss; tap deep-links.
8. **States:** loading / empty / list / error.
10. **Gates:** G-14 (if denied, inline card "Turn on notifications to get reminders").
12. F-35.

### S-C07 Profile & More — [STD]
1. **Purpose:** Hub for profile, family, consents, devices, settings, help, about, sign out.
4. **Layout:** Profile header card (name, age, completion ring), sections: *My health* (Profile S-B03, Health context S-B04, Family S-B05, Cases S-R04, Lab results S-R06), *Devices* (S-I01, Device check S-B07, BP calibration S-D10), *Privacy* (S-B01/S-I04), *App* (S-I03, S-I05, Help), Sign out (confirm dialog).
12. F-37.

---

## D. Vitals (F-10 … F-15)

### S-D01 Vitals Scan Setup — [DOC]
1. **Purpose:** Choose capture mode and explain what will be measured.
4. **Layout:** Two mode cards — **Face scan** (60 s, front camera; HR, RR, HRV, stress, rhythm, BP band*, waveform*, diabetes risk*) and **Finger scan** (30–60 s, rear camera + torch; adds **SpO2 band**, better waveform/PI) — each lists outputs with availability chips (e.g. SpO2 "Not calibrated for this phone" when G-16 fails); tips accordion (sit, rest 5 min, no caffeine/smoke/exercise 30 min); BP calibration status chip (G-26); primary "Continue".
6. **Data:** device capability, release status of each marker (G-24), calibration validity.
10. **Gates:** G-04, G-11, G-16 (SpO2), G-24, G-26.
11. **Navigation:** → S-D02.
12. F-10, F-11. 13. `VitalsSetupController`.

### S-D02 Pre-Scan Context Check — [DOC]
1. **Purpose:** Record context that changes confidence: caffeine / smoking / exercise in last 30 min → context factor 0.8 (RSK-06); symptoms (chest pain, fever) used by urgency rules (T8, T9).
4. **Layout:** 3 yes/no chips (Caffeine · Smoked · Exercised — "in the last 30 minutes"), symptoms multi-select (Chest pain · Breathlessness · Fever · Dizziness · None), optional temperature entry (°C; thermometer/ring) [DER from T9], primary "Start scan".
9. **Validation:** temperature 30.0–45.0 °C if entered [DER].
11. **Navigation:** → S-D03 or S-D04. **Safety:** selecting chest pain + breathlessness shows advisory card "If severe, call emergency services" [DER — see Q-SAFETY].
12. F-29.

### S-D03 Face Scan Capture — [DOC] (T-CAP)
1. **Purpose:** Record 60 s of face video meeting CAP-01…05 for ≥ 80 % of frames (first 3 s discarded) — Spec §3.
4. **Layout:** T-CAP with front camera preview, **face oval** guide, QualityChecklist rows: Face position (CAP-01) · Light (CAP-03) · Stillness (CAP-04) · Skin visible (CAP-05) · Face regions (CAP-02); live mini-waveform (optional, after 10 s); CountdownRing 60 s.
5. **Shows:** coaching messages exactly from Spec: "Move closer / face the camera", "Move to brighter place" / "Avoid direct light", "Hold still" (restarts), "Remove mask / hair from forehead".
6. **Data:** camera stream ≥ 30 fps (60 preferred §4.8), on-device landmarker [MOCK in UI phase].
7. **Interactions:** Start (enabled only when all checks pass for ~1 s), Cancel.
8. **States:** permissionRequired / initializing / aligning / recording / paused-quality / restarting (motion fail) / captured / cameraError.
9. **Permissions:** camera (G-11).
10. **Gates:** G-11, G-21 (live).
11. **Navigation:** captured → S-D05; cancel → S-D01.
12. F-09, F-10. 13. `FaceScanController` (wakelock, portrait lock, disposes camera on pause).

### S-D04 Finger Scan Capture — [DOC] (T-CAP)
1. **Purpose:** 30–60 s rear camera + torch finger PPG (PUL-06); enables SpO2 band (SPO-01).
4. **Layout:** illustration of finger covering lens & torch, large **finger circle** showing live red intensity, QualityChecklist: Lens covered · Pressure (saturation) · Pulse detected · Stillness; CountdownRing.
5. **Coaching (Spec):** "press lighter" (mean red > 250), "cover lens fully" (no pulse).
8. **States:** as S-D03 + torchUnavailable (→ unsupported message).
11. **Navigation:** → S-D05.

### S-D05 Signal Processing — [DOC]
1. **Purpose:** Show progress while pipeline runs (PUL-01…10, then §4 cards). PUL-05 neural ≤ 15 s; if > 20 s → POS-only + flag.
4. **Layout:** Animated pulse ring, step list with ticks: Checking signal quality → Extracting pulse → Detecting beats → Calculating vitals → Assessing risk; cancel text button.
8. **States:** processing (per step) / success → S-D07 / retakeRequired → S-D06 / failed (technical) → error with retry / timeout (fallback info chip "Used standard pulse method").
12. F-10, F-12, F-29. 13. `ProcessingController` (stream of `PipelineStep`).

### S-D06 Retake Guidance — [DOC]
1. **Purpose:** Explain *why* a retake is needed and how to fix it; enforce **max 3** retakes (G-25) then offer finger mode (HR §4.1) or paced breathing (RR §4.2).
4. **Layout:** Illustration, title "Let's try that again", reason card(s) mapped from failure codes (pulse SNR < 3 dB · HR methods disagree · too few beats · neural vs POS > 5 bpm · motion), tips list, attempt counter "Attempt 2 of 3", primary "Retake", secondary "Try finger scan instead" (after 3rd fail primary becomes this), text "Cancel".
12. F-10, F-11, G-25.

### S-D07 Vitals Results Summary — [DOC] (T-RES)
1. **Purpose:** Present all vital markers with bands, confidence and next steps.
4. **Layout:**
   - UrgencyBanner (RSK-02) if any rule fired; emergency → auto-push S-R02 first.
   - Hero: Heart rate value (0 dp) + band; confidence.
   - **Core vitals grid** (MetricTile): Heart rate · Respiratory rate · SpO2 band (finger) · BP band · Rhythm (regular / irregular — "needs confirmation" when 1 scan G-27).
   - **Heart health**: HRV (RMSSD, SDNN, pNN50 — "reference range not yet available" for age bands), Stress (Baevsky band), Vascular age gap, Pulse waveform (PI, AIx…) → S-D08.
   - **Risk**: Diabetes risk band (or "Complete waist & BMI to see this" G-03).
   - **Derived** (FRM): MAP, PP, Shock index, RPP, CR ratio — only when inputs present & displayed (G-29); SBP/DBP numbers are **internal** until validated → derived values that need SBP/DBP are internal too [see Q-FRM-BP].
   - Fitness link → S-D09.
   - Quality & versions (signal SNR, clean beats, algorithm_version, range_version).
   - DisclaimerNote; primary "Done", secondary "Save PDF / Share" [OPEN].
6. **Data:** `VitalsResult` (envelope per marker).
8. **States:** ready / partial (some markers hidden with reason) / allHidden (→ retake) / lowConfidence (< 0.6 hidden by G-23).
10. **Gates:** G-22, G-23, G-24, G-27, G-29.
11. **Navigation:** S-D08, S-D09, S-R02, S-R03, S-R05, S-D10.
12. F-12, F-13, F-29, F-30.

### S-D08 Marker Detail — [DOC]
1. **Purpose:** Deep dive into one marker: definition, value/band, reference band chart, trend, contributing quality, conditions informed, confirmatory tests (§13).
4. **Layout:** Title, hero value + band, **range bar** with normal/borderline/critical segments (only if Spec defines them), "What it is", "What affects it", trend sparkline with baseline (RSK-03), "If this is out of range" → investigations table from §13, versions.
8. **States:** ready / rangeNotAvailable (HRV/waveform age bands) / hidden-with-reason.
12. F-12, F-34.

### S-D09 Body & Fitness Metrics — [DOC]
1. **Purpose:** Profile-derived formulas: BMI (FRM-09, Asian cut-off 18.5–22.9), WHtR (FRM-10, < 0.5), Body fat % estimate (FRM-11, adults only, "estimate"), HRmax (FRM-06), HRR (FRM-07), VO2max estimate (FRM-08, "estimate"; age/sex table not provided → no band).
4. **Layout:** cards per metric with value (correct decimals), band chip where Spec defines a normal range, "estimate" tag, formula disclosure ("How we calculate this").
8. **States:** ready / missing-input card per metric ("Add waist to see WHtR" → S-B04).
10. **Gates:** G-02, G-03, G-29.

### S-D10 BP Cuff Calibration — [DOC]
1. **Purpose:** Enter a personal cuff reading taken with a validated cuff to calibrate BP offset; valid **30 days** (§4.6).
4. **Layout:** status card (Calibrated on dd-mm, expires in N days / Expired / Never), instructions (sit 5 min, mean of 2 readings ≤ 10 min apart per §14), SBP & DBP fields ×2 readings, "Then take a vitals scan within 10 minutes" [DER from §14], primary "Save & scan now".
9. **Validation:** SBP 60–260, DBP 30–160 (valid ranges §4.6), SBP > DBP.
8. **States:** never / valid / expiring (≤ 5 days, [DER]) / expired.
10. **Gates:** produces G-26.

### S-D11 Orthostatic Test — [DOC]
1. **Purpose:** HR rise lying → standing (FRM-14): max standing HR (0–3 min) − mean lying HR (last 30 s); flag ≥ 30 bpm (§13).
4. **Layout:** 3-phase guided flow: *Lie down* (finger/face continuous HR [OPEN: capture mode for lying]) countdown → *Stand up now* (voice cue) → *Stand still 3 min* with live HR; result card.
8. **States:** instructions / lying / transition / standing / processing / result / aborted (dizziness button "I feel dizzy" stops test and shows safety advice).
12. F-15, ALG-FRM-14.

### S-D12 HR Recovery Test — [DOC]
1. **Purpose:** HR at end of exercise − HR 60 s later (FRM-15), normal ≥ 12.
4. **Layout:** exercise instruction [OPEN: protocol not in Spec], "Finished exercising" button → immediate scan → 60 s recovery scan → result.
12. F-15, ALG-FRM-15.

### S-D13 Paced-Breathing Retake — [DOC]
1. **Purpose:** When RR not available (< 2 valid series), offer a paced-breathing retake (§4.2).
4. **Layout:** expanding/contracting circle pacer with inhale/exhale cue during face capture (T-CAP); rate [OPEN — Spec tests paced 8/12/20/28 br/min but does not state the app pacing rate].
12. F-10, ALG-RSP-01.

---

## E. Image Screens (F-16, F-17) — one template, eight configurations

### S-E01 Image Screen Intro (template) — [DOC]
1. **Purpose:** Explain the screen, what photos are needed, eligibility, and get ready.
4. **Layout:** hero illustration, title, "What this checks", "You'll need" (flash, colour card [required/preferred/none], helper person?), "How to take the photo" (3 illustrated steps), eligibility note, primary "Start".
10. **Gates:** G-04, G-09, G-10, G-11, G-24; G-20 if card required.
11. **Navigation:** → S-E02 (if card required/preferred) → S-E03.

### S-E02 Colour Card Setup — [DOC]
1. **Purpose:** Explain & detect the 24-patch colour card (CAP-10); mandatory for newborn jaundice, preferred for anaemia, required for jaundice & diabetic foot size.
4. **Layout:** card illustration, "Place the card next to the area", live detection badge (card found, ΔE ≤ 5), "I don't have a card" (allowed only when optional — newborn shows GateBlocker "Card required").
8. **States:** detecting / found / notFound / correctionFailed (ΔE > 5).

### S-E03 Guided Image Capture (template, T-CAP for photos) — [DOC]
1. **Purpose:** Capture each required view with real-time checks: blur (CAP-06 ≥ 100), glare/dark (CAP-07), image-quality classifier (CAP-08 ≥ 0.7), body-part coverage (CAP-09 ≥ 80 %), colour card (CAP-10); auto-capture after **2 s continuous framing** passing all checks (§2 intro).
4. **Layout:** camera with part-specific outline, view list chips at top ("Left eye 1/2 ✓"), QualityChecklist, coaching (Spec messages: "Autofocus tap + retake", "Tilt phone / more light", "Show the whole [part]"), shutter (manual fallback), flash toggle (forced on where Spec requires).
8. **States:** aligning / holding (2 s ring) / captured (thumbnail) / failed check / allViewsDone.
11. **Navigation:** → S-E04.

### S-E04 Capture Review — [DER]
1. **Purpose:** Review thumbnails, retake any view, then submit; tracks **retakes max 3 per view** then "not assessed" (§6 intro).
4. **Layout:** grid of view thumbnails with ✓ / retake button, submit primary.
8. **States:** reviewing / uploading (progress) / submitted → processing → S-R01 / offlineQueued.

**Image screen configurations (S-E01/02/03 parameters):**

| Screen | ALG | Views | Flash | Colour card | Eligibility | Outputs shown | Notes |
|---|---|---|---|---|---|---|---|
| Anaemia | IMG-01 | 2 per eye, lower lid pulled down | On | Preferred | all; band uses age/sex/pregnancy | ANAEMIA_BAND, ANAEMIA_PROB (HB_EST internal) | Pregnant + high → urgent (T12) |
| Jaundice (adult) | IMG-02 | eyes looking up | On | Required | adults [DER] | JAUNDICE_BAND | — |
| Cataract | IMG-03 | front of each eye | On | — | age ≥ 40 or on request | CATARACT_BAND (per eye L/R) | — |
| Oral | IMG-04 | both cheeks, tongue sides, floor of mouth, palate | [OPEN] | — | tobacco users always offered | ORAL_CLASS + heat-map regions | Suspicious/high → urgent |
| Diabetic foot | IMG-05 | both soles, heels, between toes | [OPEN] | For size | diabetes / high DM risk; monthly | DFU_CLASS, WOUND_AREA cm² | Ulcer → urgent |
| Child eye | IMG-06 | flash photo, dim room, 0.5–1 m | On | — | age 1–12 | CHILD_EYE_BAND | White pupil → urgent (T11) |
| Newborn jaundice | IMG-07 | forehead / chest skin | [OPEN] | **Mandatory** | 0–28 d; age in hours + gestation | NEO_JAUNDICE_BAND | Never "normal" without card |
| Skin | IMG-08 | close-up with distance guide | [OPEN] | — | all | SKIN_CLASS, SKIN_BAND | acceptance set after pilot → likely "In validation" |

### S-E06 Fundus Camera Connect & Capture — [DOC]
1. **Purpose:** Pair partner clip-on fundus camera, capture, send to partner AI via adapter (IMG-09) → DR_REFERABLE, DR_GRADE, GLAUCOMA_SUSPECT.
4. **Layout:** connection steps (attach clip, Bluetooth/USB [OPEN]), status chip, capture per eye, upload & partner processing status.
8. **States:** notConnected / connecting / connected / capturing / uploading / partnerProcessing / result / partnerError.
10. **Gates:** G-31, G-15.

---

## F. Dental (F-18)

### S-F01 Dental Intro & Consent — [DOC]
1. **Purpose:** Explain the 4-view exam, select adult vs **child mode (1–12)** — child mode changes capture guidance and tooth chart, not the models (§7).
4. **Layout:** member chip (self / child), mode auto-set from age (editable label only), "You'll take 4 photos" visual (front closed, front open, upper biting surfaces, lower biting surfaces), tips (good light, helper holds phone for child), dental-consent status, primary "Start".
10. **Gates:** G-05 (guardian for children), G-11.
11. **Navigation:** → S-F02 (if questionnaire not answered in last [OPEN] days) → S-F03.

### S-F02 Caries-Risk Questionnaire (Q_CARIES_RISK) — [DOC]
1. **Purpose:** Habits input for caries-risk rule ALG-DEN-06 (BR-DEN, FRS 12.4): night bottle feeding, brushing frequency, fluoride paste, sweets per day.
4. **Layout:** QuestionCards one per screen with progress: Brushing (none / once / twice+ daily), Fluoride toothpaste (yes/no/don't know), Sweets or sugary drinks per day (0–5+ stepper), Night bottle/breast feeding (child < 6 [DER]), primary "Next".
9. **Validation:** all required.
12. ALG-DEN-06. *Full BR-DEN rule text is in the FRS (not provided) — only the 6 test vectors are known (doc 09).*

### S-F03 Dental 4-View Capture — [DOC]
1. **Purpose:** Capture 4 views, each validated by view classifier (DEN-01) + blur/glare/coverage checks.
4. **Layout:** T-CAP with **arch outline** per view, view stepper (1/4…4/4), coaching ("Open wider", "Tilt up to show upper teeth" [DER]), flash toggle.
8. **States:** per view: aligning / captured / wrongView ("This looks like the front view — please show the upper biting surfaces") / skipped (→ exam partial).
11. **Navigation:** → upload → processing → S-F04.

### S-F04 Dental Results & Tooth Chart — [DOC] (T-RES)
1. **Purpose:** Show per-tooth findings on an FDI chart, gum & plaque bands, sealant need (age 6–9), caries risk level, change vs last exam.
4. **Layout:** urgency banner (abscess → urgent T13), summary card (caries risk level chip, # teeth with findings), **ToothChart** (primary 51–85 < 6 y; mixed 6–12 y; permanent 11–48) with colour-coded teeth (white spot · enamel break · cavity · broken/black · abscess sign), legend, Gum inflammation band, Plaque band, Sealant needed teeth (16/26/36/46), "Changed since last exam" list (new / progressed — DEN-07), **Partial exam** banner listing teeth not seen, next steps (§13 dentist exam ICDAS; X-ray as needed).
8. **States:** ready / partial / processing / failed.
11. **Navigation:** tooth → S-F05; S-R05.

### S-F05 Tooth Detail — [DOC]
Shows FDI number + name, photo crop with bbox, findings with probability band, view source, history for that tooth.

---

## G. Audio, Sleep, Hearing, Mind (F-19 … F-25)

### S-G01 Audio Readiness Check — [DOC]
1. **Purpose:** Gate all audio tasks: **mic self-check** (CAP-11 speaker sweep 100 Hz–8 kHz, deviation ≤ 6 dB, OS processing not detected), **room noise** (CAP-12 ≤ 45 dBA, 3 s silence), then per-task clipping/SNR (CAP-13 clip ≤ 1 %, SNR ≥ 15 dB) and AV sync (CAP-14) when video+audio.
4. **Layout:** 2-step checklist with live level meter: "Testing your microphone…" (plays sweep) → "Stay quiet for 3 seconds" (dBA gauge with 45 threshold line); results ✓/✕; fix tips ("Remove phone case covering the mic", "Turn off noise suppression", "Move to a quieter room").
8. **States:** permissionRequired / testingMic / micFailed (blocks audio tasks) / measuringNoise / tooNoisy (retry) / passed.
10. **Gates:** G-12, G-16 (mic profile), produces G-17, G-18.
11. **Navigation:** passed → next audio task; failed → retry / back.
13. `AudioReadinessController` (result valid for this session only [DER]).

### S-G02 Respiratory Questionnaires — [DOC]
Q_TB_SYMPTOMS (TB symptoms, for AUD-03), Q_MMRC (breathlessness scale, AUD-04), Q_EXPOSURE (smoke/dust exposure, AUD-04). Question wording comes from FRS / master data **[OPEN]** — UI uses QuestionCard with config-driven items.

### S-G03 Cough Task — [DOC]
1. **Purpose:** Record voluntary coughs; need **≥ 3 valid coughs** (AUD-01: prob ≥ 0.5, 150–800 ms) for TB risk (AUD-03) and obstruction (AUD-04).
4. **Layout:** phone-position illustration (arm's length [DER]), "Cough when the circle turns green", live valid-cough counter (0/3 → 3/3 ✓), level meter with clipping warning ("Move phone further / quieter room").
8. **States:** ready / recording / cough detected (+1) / clipping / lowSNR / done / insufficient (retry).

### S-G04 Voice Tasks — [DOC]
Sequential tasks (AUD-04, AUD-06): sustained **"aaa" ≥ 3 s** (MPT = longest), **"sss"**, **"zzz"** (s/z ratio), fixed **sentence**, breath sounds, exhale. Layout: task card with big instruction, timer bar, re-record per task, task progress 1/6.

### S-G05 Forced Exhale — Lung Function — [DOC]
1. **Purpose:** 3 forced exhales at arm's length (~30 cm); best of 3; repeatability within 10 % (AUD-05).
4. **Layout:** demo animation, distance guide, "Take a deep breath… BLOW hard and fast!" cue, attempt cards 1–3 with ✓ and repeatability status; if not repeatable → "One more try" (max [OPEN]).
10. **Gates:** G-02 (height, age, sex for % predicted FRM-13), audio gates.

### S-G06 Respiratory & Voice Results — [DOC] (T-RES)
Markers: TB_BAND (+ "always test with sputum NAAT if high" §13), OAD_BAND, ASTHMA_VS_COPD_PROB (display policy [OPEN]), FEV1_L, FVC_L, FEV1_FVC, PEF_LS, % predicted, RATIO_LLN, voice F0, jitter, shimmer, HNR, CPPS, MPT, s/z with Spec normal ranges.

### S-G07 Sleep Setup — [DOC]
1. **Purpose:** Prepare overnight sonar monitoring (AUD-07) + apnoea estimate (AUD-08, ≥ 4 h).
4. **Layout:** checklist: phone on bedside table · **charging** · 0.3–1 m from chest · volume [OPEN: inaudible chirps 18–20 kHz need speaker] · Do-not-disturb; ring connected (optional, adds SpO2 dips); primary "Start sleep monitoring".
10. **Gates:** G-12, G-30, G-32 (optional).

### S-G08 Sleep Monitoring (night mode) — [DOC]
Dark, minimal, OLED-friendly: clock, "Monitoring" pulse dot, elapsed time, tap-to-reveal "Stop" (long-press to stop to avoid accidental taps). States: running / paused (charger disconnected → warning) / interrupted / stopped (< 4 h → "Not enough sleep recorded for apnoea estimate", RR still shown) / completed.

### S-G09 Sleep Report — [DOC] (T-RES)
VALID_SLEEP_H, SONAR_RR (12–20 normal), breathing-rate chart per 30-s epoch, APNOEA_EVENTS, HYPOPNOEA_EVENTS, AHI_EST, OSA_BAND (< 5 normal · 5–14 mild · 15–29 moderate · ≥ 30 severe), next steps (§13 home sleep test / PSG for moderate–severe).

### S-G10 Hearing Test — [DOC]
1. **Purpose:** Pure-tone 0.5/1/2/4 kHz each ear (adaptive up 5 dB / down 10 dB) **or** digits-in-noise staircase (AUD-09).
4. **Layout:** earphone check (G-19) → noise check (G-18) → ear selector visual (L/R) → "Tap when you hear a beep" big button / digits keypad for DIN; progress per frequency.
8. **States:** earphonesMissing / tooNoisy / testing / earphoneDisconnected (pause) / done.

### S-G11 Hearing Results — [DOC]
Audiogram-style chart per ear (HEAR_L/R_xxx dB HL), DIN_SRT_DB, HEARING_BAND (all < 20 dB HL normal, WHO 2021), next steps.

### S-G12 Cognitive Speech Tasks — [DOC]
Age ≥ 50 (G-09). Inputs: education level (S-B04). Tasks: **animal naming 60 s**, **picture description** (picture asset [OPEN]). Speech recognition te/hi/en. Result: FLUENCY_COUNT, PAUSE_RATE, SPEECH_RATE, LEXICAL_DIV, COG_BAND (norms not provided → band only when model released).

### S-G13 Mood Check — [DOC]
**Clinician pathway only** (G-07). PHQ-9 (0–27) + GAD-7 (0–21) questionnaires + 60 s free speech. **Any PHQ-9 item 9 answer > 0 immediately triggers S-G14** (G-37) before anything else.

### S-G14 Crisis Support — [DOC]
Full-screen, calm design: "You're not alone", immediate helpline call buttons (numbers configured by region [OPEN]), "Talk to someone you trust", notify clinician (pathway), cannot be dismissed accidentally (explicit "I'm safe right now" + clinician notified flag).

### S-G15 Heart-Failure Voice Daily Check — [DOC]
Enrolled HF patients only (G-08). Daily 30-s fixed sentence. **Baseline building for first 14 days** (G-28) with progress "Day 6 of 14". Then HF_VOICE_DEV + HF_ALERT; alert → urgent case (NT-proBNP/BNP etc. §13). Reminder daily (G-34).

---

## H. Movement, Stroke & Vision (F-26 … F-28)

| Screen | ALG | Inputs / setup (Spec) | Layout highlights | Outputs | Gates |
|---|---|---|---|---|---|
| **S-H01** Finger tapping — video | MOV-01 | Hand in frame, 10 s per hand, "big and fast", voice + metronome pacing | Camera with hand outline, hand selector L→R, countdown, MediaPipe hand overlay | TAP_COUNT, TAP_FREQ, TAP_DECREMENT (< 20 %), TAP_CV | G-11, G-21 (CAP-09) |
| **S-H02** Finger tapping — touch | MOV-02 | Two on-screen targets, 10 s per hand | Two large circular targets, live counter, hand selector | TOUCH_TAP_COUNT, INTER_TAP_CV | — |
| **S-H03** Gait walk test | MOV-03 | Phone in front trouser pocket, 10-m walk, accelerometer 50 Hz | Setup steps (measure 10 m, pocket phone), audio cues "Start walking" / auto-stop or "Stop" voice, result | STEPS, CADENCE, STEP_CV, GAIT_SPEED (≥ 0.8 m/s older adults) | G-13 |
| **S-H04** Sit-to-stand | MOV-04 | Chair without arms, 30 s | Chair illustration, 30-s countdown with voice, live count | STS_COUNT_30S (age/sex norms, e.g. ≥ 12 at 60–64) | G-13 |
| **S-H05** Tremor | MOV-05 | Phone held still at arm's length, 20 s per hand, gyroscope 100 Hz | Hold-still visual (bubble level), per-hand countdown | TREMOR_FREQ (3–12 Hz peak), TREMOR_AMP | G-13 |
| **S-H06** Stroke check (FAST) | MOV-06…09 | Face at rest & smiling; both arms raised palms up eyes closed 10 s; repeat fixed sentence; **onset time** | 3 quick steps + "When did symptoms start?" time picker; **"Call emergency now" button visible at all times** | FACE_ASYM_SCORE/SIDE, ARM_DRIFT_L/R, SPEECH_ABN_PROB → STROKE_POSITIVE → **S-R02 emergency** | none — never blocked (safety); G-11, G-12 used if available, else manual checklist [DER] |
| **S-H07** Visual acuity | MOV-10 | Face distance 40 ± 5 cm (CAP-15), cover one eye, tumbling-E staircase sized by screen DPI | Distance badge (live cm), "Cover your left eye", E with 4 swipe directions, per-eye progress | LOGMAR_L/R (≤ 0.2 normal) | G-33, G-16 (focal length) |
| **S-H08** Colour vision | MOV-11 | Max brightness; plates | Plate image + answer options, progress | COLOUR_PLATE_SCORE (all correct normal) | — (plate assets [OPEN]) |
| **S-H09** Amsler grid | MOV-11 | Grid at 30 cm, per eye | Grid with central dot; member draws/marks distorted areas | AMSLER_ABNORMAL | — |
| **S-H10** Reaction time | MOV-12 | 10 visual + 10 sound stimuli, random 1–4 s gaps; discard < 100 ms | Full-screen tap area; "Wait…" → flash / beep; false-start warning | RT_VISUAL_MS, RT_AUDIO_MS (median) | G-12 (sound) |

**Parkinson's score (MOV-13)** has no separate capture screen: it combines tapping (S-H01), voice (S-G04) and face expressivity (face video from S-D03 / S-H06) and appears on S-R01 when all inputs exist (PD_BAND).

All movement screens share lifecycle: `instructions → setup check → countdown (3-2-1) → running (paced by voice + metronome) → per-side switch → processing → result (S-R01)`; abort at any time.

---

## R. Results, Urgency & Cases (F-29 … F-32)

### S-R01 Screening Result (shared template) — [DOC] (T-RES)
1. **Purpose:** Uniform result page for image, audio, movement and vision screens.
4. **Layout:** T-RES; hero shows band (e.g. "Anaemia: Low risk"), per-side results where relevant (eyes L/R, hands L/R), heat-map overlay for oral/skin, **"Under specialist review"** state for high/uncertain results (probability within ±0.1 of threshold → IMG-10), next steps from §13, "Not assessed" state after 3 failed retakes.
8. **States:** processing / ready / underReview (pending specialist) / reviewed (specialist outcome shown) / notAssessed / inValidation (model not released — G-24) / error.
10. **Gates:** G-23, G-24.

### S-R02 Emergency Alert — [DOC]
1. **Purpose:** Interrupt for emergency urgency (RSK-02): SpO2 critical < 92 % (T1), HR > 130 / < 40 (T2), shock index > 0.9 (T5 — see Q-SHOCK), stroke positive (T10), shock-index etc.
4. **Layout:** full-screen solid emergency red, large icon, plain title ("Your results need emergency attention"), reason list, **"Call emergency (108/112)"** primary (number configurable [OPEN]), "Call my contact" [OPEN], "Rescan to double-check" (only where Spec says rescan — e.g. T3 is urgent "rescan first", not emergency), "I understand" (logs acknowledgement).
8. **States:** shown / acknowledged / called.
10. **Gates:** G-37 — overrides all navigation; cannot be skipped without acknowledgement.

### S-R03 Urgent Action / Rescan Prompt — [DOC]
For urgent outcomes (T3 rescan first, T6, T8, T9, T11–T13, T15 urgent first): amber banner, reason, "Rescan now" (when rule says rescan first), "See what to do" → S-R05.

### S-R04 Cases List — [DOC]
One case per condition, merged within 30 days (RSK-07). Layout: filter (Open · Closed), cards sorted **urgency first** (T15: urgent shown first) then date: condition name, urgency chip, opened date, # flags, next confirmatory step, status (Open · Awaiting test · Test uploaded · Closed). States: loading / empty ("No open cases — great!") / list / error.

### S-R05 Case Detail & Confirmatory Tests — [DOC]
Header (condition, urgency, opened), timeline of flags (each linked to its session), **Confirmatory investigations** table from §13 (tests + usual cut-offs, with "Your lab's ranges and your doctor's judgement take precedence"), specialist review status, actions: "Upload lab result" (S-R06), "Find a lab/clinic" [OPEN], "Mark as seen by doctor" [OPEN], share summary [OPEN].

### S-R06 Lab / Reference Result Entry — [OPEN]
Enter or photograph a lab report (Hb, HbA1c, bilirubin, ECG outcome…). Pairing window shown per §14 (e.g. "HbA1c is usable if taken within 30 days of your scan"); exclusion questions (e.g. "Pregnancy, transfusion in last 3 months?" for HbA1c). Grade D pairs = monitoring only. Validation: value units and plausible ranges per test [OPEN].

### S-R07 Reference Test Invitation — [DOC]
Sampled negatives (FRS REF-03): ≥ 5 % of screen-negative members per screen offered a reference test monthly. Layout: explanation ("Help us check accuracy"), test, where/how, accept / decline, deadline = pairing window.

---

## I. Devices & Settings (F-33, F-36, F-37)

### S-I01 Connected Devices — [DOC]
Smart ring (SpO2, temperature, overnight rhythm flag; used by SPO-01 context, RHY-01 confirmation, AUD-08 SpO2 dips, BR-VIT-06 temperature), fundus camera (IMG-09). Each with status, last sync, battery [OPEN], "Pair" / "Remove". States: none / connected / disconnected / syncing / error.

### S-I02 Ring Pairing — [DOC/OPEN]
Bluetooth permission (G-15) → scanning list → pairing → success. Vendor SDK unknown [OPEN].

### S-I03 Settings — [STD]
Language (S-A02), units (metric / imperial), theme (system / light / dark), text size preview, notifications toggles per type, data sync (Wi-Fi only uploads), developer section (dev builds: mock toggles, environment).

### S-I04 Consent & Privacy Management — [DOC/STD]
View/withdraw consents (S-B01), download my data [OPEN], delete account [OPEN], training-data opt-out (G-06).

### S-I05 About, Algorithm Versions & Disclaimers — [DOC]
App version, master-data version & last sync, table of algorithms with version and release status (validated / band-only / in validation / disabled), medical disclaimer, licences (incl. HeAR licence note AUD-02), contact.

---

# Part 4 — Screen count summary

| Group | Screens |
|---|---|
| A Access | 8 |
| B Consent & Profile | 7 |
| C Main shell | 7 |
| D Vitals | 13 |
| E Image (template × 8 configs) | 5 |
| F Dental | 5 |
| G Audio / sleep / hearing / mind | 15 |
| H Movement & vision | 10 |
| R Results & cases | 7 |
| I Devices & settings | 5 |
| **Total unique screens** | **82** (+ 8 image configurations) |
