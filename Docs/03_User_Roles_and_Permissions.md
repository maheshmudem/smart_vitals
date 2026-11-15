# 03 — User Roles & Permissions

> Who uses VitalsMirror, what each role may do, which consents are required, and which device permissions the app asks for.
> IDs (F-xx, S-xx, G-xx) from [00_README_Index.md](00_README_Index.md). Tags: **[DOC] [DER] [STD] [OPEN] [MOCK]**. Open items → `16_Open_Questions_and_Assumptions.md` (temp IDs `OQ-ROLE-nn`).

> [!NOTE]
> The Spec is an algorithm specification and contains **no role model**. Roles below are *implied* by Spec text (quoted in the "Evidence" column). The Flutter mobile app primarily serves **Member, Guardian and Operator**. Clinician, Specialist reviewer, Clinical safety lead and Data/ML team are **back-office** roles (assumed web portal, out of scope for the mobile app unless confirmed — [OPEN] OQ-ROLE-01).

---

## 1. Roles

| Role | Description | Evidence in Spec | App surface | Tag |
|---|---|---|---|---|
| **Member** | Adult (≥ 18 [OPEN]) screening themselves | "member marks distortions" (§9 MOV-11); "screen-negative members" (§14) | Mobile app | DER |
| **Guardian** | Adult who consents and captures for a child (1–12) or newborn (0–28 d); the "parent" photographer | "Dental consent (guardian for children)" (§7.1); "photographer parent vs operator" (§7.1) | Mobile app (acting on dependent) | DOC |
| **Operator** | Trained field worker capturing for many participants in schools, anganwadis and clinics | "photographer parent vs operator", "schools, anganwadis and clinic" (§7.1); "untrained photographers" subgroup (§6.4) | Mobile app, Operator mode (F-06) | DER/OPEN |
| **Clinician** | Runs the clinician pathway for mood; applies clinical judgement to flags; may enrol HF patients | "clinician pathway only" (§8 AUD-11); "treating clinician's judgement take precedence" (§13); "enrolled HF patients" (§8 AUD-12) | Back office [OPEN] | DOC/OPEN |
| **Specialist reviewer** | Reviews high/uncertain image results (IMG-10) | "Every high or uncertain result … goes to specialist review (IMG-10)" (§6 intro) | Back office [OPEN] | DOC/OPEN |
| **Clinical safety lead** | Approves `mst_confirmatory_test`, `mst_pathway`, pairing tables | "clinical safety lead should confirm each row" (§13), "approves this table" (§14) | Back office | DOC |
| **Data/ML team** | Trains/validates models on training-consented data; manages release status | "keeps only training-consented records for model building" (§11.2) | Back office | DOC |
| **System** | Automated jobs: risk engine, sampled-negative invitations, reminders | §10, §14 footer | Server | DER |

### 1.1 Subject types handled under a Guardian

| Subject | Age | Managed by | Specific rules | Ref |
|---|---|---|---|---|
| Newborn | 0–28 days | Guardian or Operator (with guardian consent) | Age in **hours** + gestation required; colour card mandatory; never "normal" without card | §6.7 |
| Child | 1–12 years ("child mode") | Guardian or Operator (with guardian consent) | Dental child mode changes guidance and tooth chart only (§7); child eye screen 1–12 (§6.6); FRM-11 body fat adults only; FRM-12 z-scores | §6.6, §7, §5 |
| Adolescent | 13–17 | Guardian [OPEN] | Not defined by the Spec — OQ-ROLE-02 | — |

---

## 2. Permission matrix (feature × role)

Legend: **A** = allowed · **C** = conditional (condition in note) · **D** = denied · **—** = not applicable / back office.
"Guardian" columns mean *acting for a dependent*; a Guardian acting for themselves is a Member.

| Feature | Member | Guardian (for dependent) | Operator | Clinician | Specialist | Notes |
|---|---|---|---|---|---|---|
| F-01 Auth | A | A | C¹ | — | — | ¹ Operator auth model [OPEN] OQ-REQ-01 |
| F-02 Language | A | A | A | — | — | |
| F-03 Consent | A (self) | A (for dependent) | C² | C (clinician pathway activation) | — | ² Operator records/witnesses consent; signer is participant or guardian |
| F-04 Profile | A | A | A (for participant) | R³ | — | ³ read-only in portal [OPEN] |
| F-05 Dependents | A | A | C (registers participants, not "family") | — | — | |
| F-06 Operator mode | D | D | A | — | — | |
| F-07 Device check | A | A | A | — | — | |
| F-09/F-10/F-11 Vitals scans | A | C⁴ | A | — | — | ⁴ Adult vitals reference ranges; child/pregnancy ranges in `mst_reference_range` — availability [OPEN] OQ-ROLE-03 |
| F-12/F-13 Results/formulas | A | A | C⁵ | R | — | ⁵ Operator sees results on site; whether operator may see full results vs "refer/no refer" [OPEN] OQ-ROLE-04 |
| F-14 BP calibration | A | D | C (with cuff on site) | — | — | |
| F-15 Functional cardio | A | D | C | — | — | Exercise safety for children not defined |
| F-16 Image screens | A | C⁶ | A | — | R (IMG-10) | ⁶ Child eye (1–12), newborn jaundice (0–28 d) only under guardian; cataract offered ≥ 40 or on request |
| F-17 Fundus partner | C (device) | C | A | — | R | Requires G-31 |
| F-18 Dental | A | A (guardian consent G-05) | A (with guardian consent for child) | — | — | Child mode 1–12 |
| F-19/F-20 Respiratory audio | A | C [OPEN] | A | — | — | Paediatric validity of audio models not stated |
| F-21 Sleep | A | C [OPEN] | D (home task) | — | — | |
| F-22 Hearing | A | C [OPEN] | A | — | — | |
| F-23 Cognitive | C (age ≥ 50) | D | C (age ≥ 50) | — | — | §8 AUD-10 |
| F-24 Mood | C (G-07) | D | D | A (activates pathway) | — | §8 AUD-11 "clinician pathway only" |
| F-25 HF voice | C (G-08) | D | D | A (enrols) | — | §8 AUD-12 |
| F-26 Motor/neuro | A | D [OPEN] | A | — | — | |
| F-27 Stroke FAST | A | A (on behalf) | A | — | — | Emergency — never blocked by entitlement (G-37) |
| F-28 Vision/reaction | A | C [OPEN] | A | — | — | |
| F-29 Risk engine | (system) | (system) | (system) | R | R | Deterministic, no user override |
| F-30 Cases | A (own) | A (dependent) | C⁵ | A | R | |
| F-31 Specialist review | R (status) | R | R | R | A | |
| F-32 Reference results | C⁷ | C⁷ | C⁷ | A | — | ⁷ who may enter lab results [OPEN] OQ-REQ-19 |
| F-33 Ring | A | D | D | — | — | |
| F-34 History | A | A | C (site-scoped) | R | — | |
| F-35 Notifications | A | A | C | — | — | |
| F-36 Master sync | (system) | (system) | (system) | — | — | |
| F-37 Settings | A | A | A | — | — | |
| F-38 Release gate | (system) | (system) | (system) | — | — | |

(R = read only.)

---

## 3. Consent types

| Consent | Gate | Who signs | Blocking? | Scope | Withdrawal effect | Ref | Tag |
|---|---|---|---|---|---|---|---|
| **Screening consent** | G-04 | Member; guardian for dependent | Blocks all captures | Capture, process, store screening data, generate flags | Captures disabled; existing data handling per retention policy [OPEN] | §6 intro | DOC |
| **Dental consent** | G-05 | Member; **guardian for children** | Blocks dental capture | Mouth photos, tooth chart | Dental disabled | §7.1 | DOC |
| **Training-data consent** | G-06 | Member; guardian for dependent | Non-blocking | Use of records/media for model building | Records excluded from future training sets | §11.2 | DOC |
| **Clinician pathway (mood)** | G-07 | Member + clinician activation | Blocks mood screen | Voice + PHQ-9/GAD-7 shared with clinician | Mood screen hidden | §8 AUD-11 | DOC |
| **HF programme enrolment** | G-08 | Member + clinician enrolment | Blocks HF voice | Daily voice, baseline, alerts to clinic | HF voice hidden; reminders stopped | §8 AUD-12 | DOC |
| Reference-test participation | — | Member/guardian | Non-blocking | Sampled-negative invitation, lab result pairing | No invitations | §14, FRS REF-03 | DER/OPEN |
| Partner data sharing (fundus, TB API, HeAR) | — | Member | Blocks partner feature | Media sent to third party | Partner path disabled | §6.8, §8 AUD-02/03 | DER/OPEN |

> [!IMPORTANT]
> Consent text, version numbers and whether consent can be given verbally to an Operator are **[OPEN]** (OQ-REQ-03, OQ-ROLE-05).

---

## 4. Data-access rules

| Rule | Description | Tag |
|---|---|---|
| DA-01 | A Member sees only their own records and those of dependents they are guardian for. | DER |
| DA-02 | A Guardian's access to a dependent ends when guardianship is removed or the dependent reaches majority [OPEN OQ-REQ-05]. | DER/OPEN |
| DA-03 | An Operator sees participants registered at their site/organisation only, and only for the duration needed [OPEN OQ-ROLE-06]. | DER/OPEN |
| DA-04 | Raw media (video/audio/photos) stays on device until upload; after server inference, retention depends on training consent. | DER/OPEN |
| DA-05 | Training pipelines receive only records with active G-06 consent (§11.2). | DOC |
| DA-06 | Specialist reviewers see only the images and minimal context (age, sex, relevant history) needed for IMG-10. | DER |
| DA-07 | Mood data visible only to the member and the pathway clinician. | DER |
| DA-08 | Partner integrations receive pseudonymised payloads (no name/phone). | DER |
| DA-09 | Master data is public-read for authenticated apps, write only through change control (§1). | DOC |
| DA-10 | Every access to another person's record (guardian/operator/clinician) is audit-logged. | STD |

---

## 5. Child mode & newborn handling

| Aspect | Child (1–12) | Newborn (0–28 d) |
|---|---|---|
| Account | Dependent of Guardian; no own login | Dependent of Guardian |
| Consent | Guardian signs screening + dental (+ training) | Guardian signs screening (+ training) |
| Required profile | DOB, sex, height, weight (for z-scores, FRM-12) | DOB **with time** (age in hours), sex, gestation (weeks) |
| Screens offered | Child eye (§6.6), dental child mode (§7), anaemia (6–59 m / 5–11 y thresholds §6.1), growth z (§5) | Newborn jaundice (§6.7) |
| Not offered | Body fat FRM-11 (adults only); cognitive (≥ 50); mood; HF | Everything else [DER] |
| Capture | By guardian ("parent") or operator; photographer type recorded | By guardian or operator; colour card mandatory |
| Special rules | Primary FDI 51–85 < 6 y; mixed 6–12 y; sealant check 6–9 y | Never show "normal" without card; high = above phototherapy line |

---

## 6. Runtime device permissions

| Permission | Gate | Requested when (just-in-time) | Used by | If denied | If permanently denied | Tag |
|---|---|---|---|---|---|---|
| **Camera** | G-11 | First tap on any camera task (vitals, image, dental, tapping video, stroke, vision distance) | F-09/10/11/16/18/26/27/28 | Explain why; camera tasks disabled; non-camera tasks remain | Show "Open Settings" CTA | DER |
| **Microphone** | G-12 | First audio task or CAP-11 mic check | F-19…F-25, MOV-08, MOV-12 audio stimuli, CAP-14 | Audio tasks disabled | "Open Settings" | DER |
| **Motion sensors** (iOS Motion & Fitness; Android `ACTIVITY_RECOGNITION` / high-rate sensors on Android 12+ `HIGH_SAMPLING_RATE_SENSORS`) | G-13 | First gait / sit-to-stand / tremor test | MOV-03/04/05 | Motion tests disabled | "Open Settings" | DOC (§9 intro)/DER |
| **Notifications** | G-14 (non-blocking) | After first completed screening or on enrolling in foot/HF/rhythm reminders | F-35 | In-app inbox only | In-app inbox only | DER |
| **Bluetooth / Nearby devices** | G-15 | When pairing ring (S-I02) or fundus camera (S-E06) | F-17, F-33 | Ring/fundus unavailable; core app unaffected | "Open Settings" | DER |
| **Location** (Android < 12 for BLE scan only) | G-15 | Only if OS requires for BLE scanning | F-33 | As Bluetooth | As Bluetooth | DER |
| **Foreground service / keep-awake** (sleep) | G-30 | Sleep setup | F-21 | Sleep monitoring unavailable | — | DER |
| **Speech recognition** (iOS `SFSpeechRecognizer`) | — | First speech task if on-device OS recogniser used [OPEN] | F-23, MOV-08 | Speech tasks disabled | "Open Settings" | DER/OPEN |
| **Storage / Photos** | — | Not required (app-private storage) | — | — | — | DER |

---

## 7. Open questions (this document)

| Temp ID | Question |
|---|---|
| OQ-ROLE-01 | Are Clinician / Specialist / Safety-lead functions web-portal only, or any in the mobile app? |
| OQ-ROLE-02 | How are adolescents (13–17) handled — own account, guardian-managed, which screens? |
| OQ-ROLE-03 | Are child/pregnancy vitals reference ranges available in `mst_reference_range` at launch? |
| OQ-ROLE-04 | What results may an Operator see/share on site (full bands vs refer/no-refer)? |
| OQ-ROLE-05 | Can consent be given verbally/witnessed via an Operator; e-signature requirements? |
| OQ-ROLE-06 | Operator data-access scope and retention on a shared device? |
| OQ-ROLE-07 | Adult age threshold for "Member" (18?) and minimum age per screen not stated by Spec. |
