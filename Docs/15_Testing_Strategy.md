# 15 — Testing Strategy

> **Purpose:** Defines the verification strategy covering deterministic Spec test vectors, gate and lifecycle transitions, UI widget rendering, and clinical study acceptance criteria.

---

## 1. Testing Pyramid

1. **Deterministic Algorithm Unit Tests (`test/algorithms_test.dart`):**
   - **100% pass requirement** on every worked test vector in the Spec before any UI code is accepted.
2. **Gate & Lifecycle Unit Tests (`test/gates_and_risk_test.dart`):**
   - Verifies `G-01`…`G-37` blocking/passing logic, retake counter limits (`G-25`), confidence hiding (`< 0.6`, `G-23`), release status hiding (`G-24`), and 30-day case merging (`ALG-RSK-07`).
3. **Widget & Navigation Tests (`test/widget_test.dart`):**
   - Verifies app launch, shell navigation, Screenings Catalogue (`S-C02`), Vitals Scan workflow (`S-D01`→`S-D07`), Dental FDI Chart (`S-F04`), Emergency Alert override (`S-R02`), and Screen Inventory inspector.

---

## 2. Mandatory Unit Test Vectors from the Spec

### 2.1 HRV & Baevsky Stress Vectors (Spec §4.3, §4.4)
| Algorithm | Input Vector | Expected Output | Tolerance |
|---|---|---|---|
| `ALG-HRV-01` | IBIs `[800, 810, 790, 805, 795]` ms | `SDNN = 7.9 ms`, `RMSSD = 14.4 ms`, `pNN50 = 0.0%` | `±0.1 ms` |
| `ALG-HRV-04` | `Mo = 0.80 s`, `AMo = 40%`, `MxDMn = 0.20 s` | `BAEVSKY_SI = 125` (`low` band `50–150`) | Exact |

### 2.2 Formula Cards (`ALG-FRM-01` … `ALG-FRM-15`, Spec §5)
| ID | Formula | Test Input | Expected Output | Decimals |
|---|---|---|---|---|
| `ALG-FRM-01` | `MAP = DBP + (SBP - DBP) / 3` | `SBP 117, DBP 77` | `90.3 mmHg` | 1 |
| `ALG-FRM-02` | `PP = SBP - DBP` | `SBP 117, DBP 77` | `40 mmHg` | 0 |
| `ALG-FRM-03` | `Shock index = HR / SBP` | `HR 92, SBP 117` | `0.79` | 2 |
| `ALG-FRM-04` | `RPP = HR * SBP` | `HR 92, SBP 117` | `10764 bpm·mmHg` | 0 |
| `ALG-FRM-05` | `CR ratio = HR / RR` | `HR 92, RR 21` | `4.38` | 2 |
| `ALG-FRM-06` | `HRmax = 208 - 0.7 * age` | `age 26` | `189.8 bpm` | 1 |
| `ALG-FRM-07` | `HRR = HRmax - HRrest` | `HRmax 189.8, HR 92` | `97.8 bpm` | 1 |
| `ALG-FRM-08` | `VO2max = 15.3 * HRmax / HRrest` | `HRmax 189.8, HR 92` | `31.6 mL/kg/min` | 1 |
| `ALG-FRM-09` | `BMI = weight / height^2` | `70 kg, 1.78 m` | `22.09 kg/m²` | 2 |
| `ALG-FRM-10` | `WHtR = waist / height` | `85 cm, 178 cm` | `0.478` | 3 |
| `ALG-FRM-11` | `Body fat = 1.2*BMI + 0.23*age - 10.8*sex - 5.4` | `BMI 22.09, age 26, male (1)` | `16.29 %` | 2 |
| `ALG-FRM-12` | `WHO z = ((X/M)^L - 1) / (L * S)` | `X=18, L=-0.5, M=16, S=0.08`; `X=M` | `1.43`; `0.00` | 2 |
| `ALG-FRM-14` | `Orthostatic rise = max standing HR - mean lying HR` | `Lying 70, Standing max 104` | `34 bpm` (flag `≥ 30`) | 0 |
| `ALG-FRM-15` | `HR recovery = HR end - HR 60s later` | `120 -> 105` | `15 bpm` (normal `≥ 12`) | 0 |

### 2.3 Dental Caries-Risk Rule Vectors (`ALG-DEN-06`, Spec §7.3)
| Case | Findings | Habits | Expected Risk |
|---|---|---|---|
| Case 1 | One cavity on 54 | None | `High` |
| Case 2 | White spots on 51 and 61 | None | `High` |
| Case 3 | One white spot on 52 | Night bottle feeding | `High` |
| Case 4 | One white spot on 52 | Brushing twice daily, fluoride paste, sweets 1/day | `Moderate` |
| Case 5 | No lesions | Sweets 4/day, brushing once daily | `Moderate` |
| Case 6 | No lesions | Sweets 2/day | `Low` |

### 2.4 Risk Engine Rule Test Cases (`ALG-RSK-02`, Spec §10)
| Case | Inputs | Expected Urgency | Rules Fired |
|---|---|---|---|
| `T1` | SpO2 band critical (`< 92%`) | `Emergency` | `BR-VIT-01` |
| `T2` | HR `135`, others normal | `Emergency` | `BR-VIT-01` |
| `T3` | HR `105` at rest, RR `22` | `Urgent` (rescan first) | `BR-VIT-02` |
| `T4` | SBP `117`, HR `92` → shock index `0.79` | `None` | — |
| `T5` | SBP `95`, HR `100` → shock index `1.05` | `Emergency` | `BR-VIT-01` |
| `T6` | Irregular rhythm on 2 scans | `Urgent` | `BR-VIT-03` |
| `T7` | BP band high, no symptoms | `Routine` | `BR-VIT-04` |
| `T8` | BP band high + chest pain | `Urgent` | `BR-VIT-04` |
| `T9` | Temperature `38.4 °C` + RR `22` | `Urgent` | `BR-VIT-06` |
| `T10` | Stroke positive | `Emergency` | `BR-SCR-01` |
| `T11` | Child white pupil | `Urgent` | `BR-SCR-02` |
| `T12` | Anaemia high, pregnant | `Urgent` | `BR-SCR-03` |
| `T13` | Dental abscess sign | `Urgent` | `BR-SCR-02` |
| `T14` | Dental cavity only | `Routine` | `BR-SCR-04` |
| `T15` | Two flags: anaemia high (routine) + TB high (urgent) | `Urgent` shown first | `BR-SCR-02`, `BR-SCR-04` |
| `T16` | HR value with quality below threshold (`SNR < 3 dB`) | `No flag`; `"retake"` | `BR-QUA-01` |
