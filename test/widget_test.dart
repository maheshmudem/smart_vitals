import 'dart:typed_data';

import 'package:algoritam/core/domain/algorithms/photo_quality_analyzer.dart';
import 'package:algoritam/core/domain/entities/anaemia_result.dart';
import 'package:algoritam/core/domain/algorithms/eye_session_builder.dart';
import 'package:algoritam/core/domain/algorithms/neonatal_bilirubin_chart.dart';
import 'package:algoritam/core/domain/entities/case_record.dart';
import 'package:algoritam/core/domain/entities/eye_photo_protocol.dart';
import 'package:algoritam/core/domain/entities/eye_photo_session.dart';
import 'package:algoritam/core/domain/entities/member_profile.dart';
import 'package:algoritam/features/eye_screens/eye_intro_screen.dart';
import 'package:algoritam/features/eye_screens/eye_result_screen.dart';
import 'package:algoritam/features/eye_screens/eye_stepper_screen.dart';
import 'package:algoritam/features/anaemia/anaemia_intro_screen.dart';
import 'package:algoritam/features/anaemia/anaemia_result_screen.dart';
import 'package:algoritam/features/anaemia/anaemia_stepper_screen.dart';
import 'package:algoritam/core/domain/algorithms/caries_risk_engine.dart';
import 'package:algoritam/core/domain/algorithms/formulas_engine.dart';
import 'package:algoritam/core/domain/algorithms/hrv_baevsky_engine.dart';
import 'package:algoritam/core/domain/algorithms/risk_engine.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/health_package.dart';
import 'package:algoritam/core/domain/algorithms/marker_readings.dart';
import 'package:algoritam/core/domain/entities/marker_catalogue.dart';
import 'package:algoritam/core/domain/entities/marker_envelope.dart';
import 'package:algoritam/features/results_cases/results_cases_screens.dart';
import 'package:algoritam/core/domain/entities/screening_catalogue_item.dart';
import 'package:algoritam/core/services/live_camera_service.dart';
import 'package:algoritam/core/services/subject_track_spec.dart';
import 'package:algoritam/core/services/voice_coach_service.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:algoritam/features/audio_screening/audio_screens.dart';
import 'package:algoritam/features/dental/dental_screens.dart';
import 'package:algoritam/features/image_screening/image_screens.dart';
import 'package:algoritam/core/domain/entities/movement_protocol.dart';
import 'package:algoritam/features/movement/movement_intro_screen.dart';
import 'package:algoritam/features/movement_vision/movement_vision_screens.dart';
import 'package:algoritam/features/shell/main_shell_screen.dart';
import 'package:algoritam/features/vitals/vitals_screens.dart';
import 'package:algoritam/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Spec §4.3 & §4.4 — HRV & Baevsky Stress Worked Test Vectors', () {
    test(
      'ALG-HRV-01: [800, 810, 790, 805, 795] ms -> SDNN 7.9, RMSSD 14.4, pNN50 0.0%',
      () {
        final res = HrvBaevskyEngine.computeTimeDomain([
          800,
          810,
          790,
          805,
          795,
        ]);
        expect(res.sdnnMs, closeTo(7.9, 0.05));
        expect(res.rmssdMs, closeTo(14.4, 0.05));
        expect(res.pnn50Pct, closeTo(0.0, 0.01));
      },
    );

    test(
      'ALG-HRV-04: Mo = 0.80 s, AMo = 40%, MxDMn = 0.20 s -> SI = 125 (low)',
      () {
        final res = HrvBaevskyEngine.computeFromParameters(
          moSeconds: 0.80,
          amoPercent: 40.0,
          mxdmnSeconds: 0.20,
        );
        expect(res.stressIndex, closeTo(125.0, 0.01));
        expect(res.band, SemanticBand.low);
      },
    );
  });

  group('Spec §5 — Deterministic Formula Calculations (ALG-FRM-01..15)', () {
    test(
      'ALG-FRM-01..05 Cardiovascular Load Formulas match exact Spec test vectors',
      () {
        final map = FormulasEngine.computeMap(sbp: 117, dbp: 77)!;
        expect(map, closeTo(90.3, 0.05));
        expect(FormulasEngine.classifyMap(map), SemanticBand.normal);

        final pp = FormulasEngine.computePulsePressure(sbp: 117, dbp: 77)!;
        expect(pp, 40);
        expect(FormulasEngine.classifyPulsePressure(pp), SemanticBand.normal);

        final si = FormulasEngine.computeShockIndex(hr: 92, sbp: 117)!;
        expect(si, closeTo(0.79, 0.01));
        expect(FormulasEngine.classifyShockIndex(si), SemanticBand.borderline);

        final rpp = FormulasEngine.computeRpp(hr: 92, sbp: 117)!;
        expect(rpp, 10764);
        expect(FormulasEngine.classifyRpp(rpp), SemanticBand.normal);

        final cr = FormulasEngine.computeCrRatio(hr: 92, rr: 21)!;
        expect(cr, closeTo(4.38, 0.01));
        expect(FormulasEngine.classifyCrRatio(cr), SemanticBand.normal);
      },
    );

    test('ALG-FRM-06..08 Fitness Formulas match exact Spec test vectors', () {
      final hrmax = FormulasEngine.computeHrMaxTanaka(ageYears: 26)!;
      expect(hrmax, closeTo(189.8, 0.05));

      final hrr = FormulasEngine.computeHrReserve(hrMax: hrmax, hrRest: 92)!;
      expect(hrr, closeTo(97.8, 0.05));

      final vo2 = FormulasEngine.computeVo2MaxUth(hrMax: hrmax, hrRest: 92)!;
      expect(vo2, closeTo(31.6, 0.05));
    });

    test(
      'ALG-FRM-09..12 Body & Child Growth Formulas match exact Spec test vectors',
      () {
        final bmi = FormulasEngine.computeBmi(weightKg: 70, heightCm: 178)!;
        expect(bmi, closeTo(22.09, 0.01));
        expect(FormulasEngine.classifyAsianBmi(bmi), SemanticBand.normal);

        final whtr = FormulasEngine.computeWhtr(waistCm: 85, heightCm: 178)!;
        expect(whtr, closeTo(0.478, 0.001));
        expect(FormulasEngine.classifyWhtr(whtr), SemanticBand.normal);

        final bf = FormulasEngine.computeBodyFatDeurenberg(
          bmi: 22.09,
          ageYears: 26,
          sex: BiologicalSex.male,
        )!;
        expect(bf, closeTo(16.29, 0.02));
        expect(
          FormulasEngine.classifyBodyFat(bf, BiologicalSex.male),
          SemanticBand.normal,
        );

        final zPos = FormulasEngine.computeWhoZScore(
          x: 18.0,
          l: -0.5,
          m: 16.0,
          s: 0.08,
        )!;
        expect(zPos, closeTo(1.43, 0.02));
        expect(FormulasEngine.classifyWhoZScore(zPos), SemanticBand.normal);

        final zZero = FormulasEngine.computeWhoZScore(
          x: 16.0,
          l: 0.0,
          m: 16.0,
          s: 0.08,
        )!;
        expect(zZero, closeTo(0.0, 0.001));
      },
    );

    test(
      'ALG-FRM-14 & 15 Orthostatic HR Rise and 1-Min HR Recovery match exact Spec vectors',
      () {
        final ortho = FormulasEngine.computeOrthostaticRise(
          meanLyingHr: 70,
          maxStandingHr: 104,
        )!;
        expect(ortho, 34);
        expect(
          FormulasEngine.classifyOrthostaticRise(ortho),
          SemanticBand.high,
        );

        final rec = FormulasEngine.computeHrRecovery1Min(
          hrEndExercise: 120,
          hrAfter60Sec: 105,
        )!;
        expect(rec, 15);
        expect(FormulasEngine.classifyHrRecovery1Min(rec), SemanticBand.normal);
      },
    );
  });

  group('Spec §7.2 — Dental Caries-Risk Rule Table (ALG-DEN-06 Cases 1–6)', () {
    test('All 6 Dental Caries-Risk Test Cases pass', () {
      // Case 1: 1 cavity on tooth 54 -> High
      final c1 = CariesRiskEngine.evaluate(
        findings: const [
          ToothFinding(
            toothFdi: 54,
            findingCode: 'cavity',
            findingLabel: 'Cavity',
            probability: 0.9,
            band: SemanticBand.high,
          ),
        ],
        habits: const CariesHabitsInput(),
      );
      expect(c1.riskBand, SemanticBand.high);

      // Case 2: White spots on 51 and 61 -> High
      final c2 = CariesRiskEngine.evaluate(
        findings: const [
          ToothFinding(
            toothFdi: 51,
            findingCode: 'white_spot',
            findingLabel: 'White Spot',
            probability: 0.85,
            band: SemanticBand.moderate,
          ),
          ToothFinding(
            toothFdi: 61,
            findingCode: 'white_spot',
            findingLabel: 'White Spot',
            probability: 0.82,
            band: SemanticBand.moderate,
          ),
        ],
        habits: const CariesHabitsInput(),
      );
      expect(c2.riskBand, SemanticBand.high);

      // Case 3: One white spot on 52 + Night bottle feeding -> High
      final c3 = CariesRiskEngine.evaluate(
        findings: const [
          ToothFinding(
            toothFdi: 52,
            findingCode: 'white_spot',
            findingLabel: 'White Spot',
            probability: 0.85,
            band: SemanticBand.moderate,
          ),
        ],
        habits: const CariesHabitsInput(nightBottleFeeding: true),
      );
      expect(c3.riskBand, SemanticBand.high);

      // Case 4: One white spot on 52 + Brushing 2/day, fluoride, sweets 1/day -> Moderate
      final c4 = CariesRiskEngine.evaluate(
        findings: const [
          ToothFinding(
            toothFdi: 52,
            findingCode: 'white_spot',
            findingLabel: 'White Spot',
            probability: 0.85,
            band: SemanticBand.moderate,
          ),
        ],
        habits: const CariesHabitsInput(
          brushingPerDay: 2,
          usesFluoridePaste: true,
          sweetsPerDay: 1,
        ),
      );
      expect(c4.riskBand, SemanticBand.moderate);

      // Case 5: No lesions + Sweets 4/day, brushing 1/day -> Moderate
      final c5 = CariesRiskEngine.evaluate(
        findings: const [],
        habits: const CariesHabitsInput(sweetsPerDay: 4, brushingPerDay: 1),
      );
      expect(c5.riskBand, SemanticBand.moderate);

      // Case 6: No lesions + Sweets 2/day, brushing 2/day with fluoride -> Low
      final c6 = CariesRiskEngine.evaluate(
        findings: const [],
        habits: const CariesHabitsInput(
          sweetsPerDay: 2,
          brushingPerDay: 2,
          usesFluoridePaste: true,
        ),
      );
      expect(c6.riskBand, SemanticBand.low);
    });
  });

  group('Spec §10 — Deterministic Risk Engine (ALG-RSK-01..07 Cases T1–T16)', () {
    test(
      'All 16 Risk Engine Rule Test Cases (T1–T16) pass including T15 priority & T16 SNR retake',
      () {
        // T1: SpO2 88% (critical) -> Emergency (BR-VIT-01)
        final t1 = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(spo2Band: SemanticBand.critical),
        );
        expect(t1.highestUrgency, UrgencyLevel.emergency);
        expect(t1.firedRuleCodes, contains('BR-VIT-01'));

        // T2: HR 145 bpm (> 130) at rest -> Emergency (BR-VIT-01)
        final t2 = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(hrBpm: 145, hrQualityPassed: true),
        );
        expect(t2.highestUrgency, UrgencyLevel.emergency);
        expect(t2.firedRuleCodes, contains('BR-VIT-01'));

        // T3: HR 105 bpm at rest + RR 22 br/min -> Urgent + rescan first (BR-VIT-02)
        final t3 = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(
            hrBpm: 105,
            rrBrMin: 22,
            hrQualityPassed: true,
          ),
        );
        expect(t3.highestUrgency, UrgencyLevel.urgent);
        expect(t3.requiresRescanConfirmation, isTrue);
        expect(t3.firedRuleCodes, contains('BR-VIT-02'));

        // T4: HR 92 / SBP 117 (Shock Index 0.79) -> None
        final t4 = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(hrBpm: 92, sbpMmhg: 117),
        );
        expect(t4.highestUrgency, UrgencyLevel.none);

        // T5: HR 100 / SBP 95 (Shock Index 1.05 > 0.90) -> Emergency (BR-VIT-01)
        final t5 = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(hrBpm: 100, sbpMmhg: 95),
        );
        expect(t5.highestUrgency, UrgencyLevel.emergency);
        expect(t5.firedRuleCodes, contains('BR-VIT-01'));

        // T6..T9: AF confirmed (Urgent), BP high no chest pain (Routine), BP high + chest pain (Urgent), Fever + RR>20 (Urgent)
        expect(
          RiskEngine.evaluateUrgency(
            const RiskEvaluationInput(irregularRhythmConfirmed: true),
          ).highestUrgency,
          UrgencyLevel.urgent,
        );
        expect(
          RiskEngine.evaluateUrgency(
            const RiskEvaluationInput(
              bpBand: SemanticBand.high,
              hasChestPain: false,
            ),
          ).highestUrgency,
          UrgencyLevel.routine,
        );
        expect(
          RiskEngine.evaluateUrgency(
            const RiskEvaluationInput(
              bpBand: SemanticBand.high,
              hasChestPain: true,
            ),
          ).highestUrgency,
          UrgencyLevel.urgent,
        );
        expect(
          RiskEngine.evaluateUrgency(
            const RiskEvaluationInput(temperatureCelsius: 38.4, rrBrMin: 22),
          ).highestUrgency,
          UrgencyLevel.urgent,
        );

        // T10: Stroke FAST positive -> Emergency (BR-SCR-01)
        final t10 = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(strokePositive: true),
        );
        expect(t10.highestUrgency, UrgencyLevel.emergency);
        expect(t10.firedRuleCodes, contains('BR-SCR-01'));

        // T15: Both Anaemia high (non-pregnant -> Routine) and TB high (Urgent) -> Urgent first
        final t15 = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(
            anaemiaBand: SemanticBand.high,
            isPregnant: false,
            tbBand: SemanticBand.high,
          ),
        );
        expect(t15.highestUrgency, UrgencyLevel.urgent);
        expect(t15.orderedFlags.first.urgency, UrgencyLevel.urgent);
        expect(t15.orderedFlags.last.urgency, UrgencyLevel.routine);

        // T16: HR 92 bpm with SNR 2.4 dB (quality fail) -> Retake first, no HR flag (BR-QUA-01)
        final t16 = RiskEngine.evaluateUrgency(
          const RiskEvaluationInput(hrBpm: 92, hrQualityPassed: false),
        );
        expect(t16.requiresRetakeFirst, isTrue);
        expect(t16.firedRuleCodes, contains('BR-QUA-01'));
        expect(t16.orderedFlags, isEmpty);
      },
    );

    test(
      'ALG-RSK-03 & 04 Personal Baseline Median (last 3) and Meaningful Change flag',
      () {
        final check = RiskEngine.evaluateBaselineAndChange(
          currentValue: 92,
          historicalValidValuesWithin180Days: [
            74,
            76,
            75,
            73,
            75,
            76,
            74,
            75,
            76,
            75,
          ],
        );
        expect(check.hasBaseline, isTrue);
        expect(check.baselineMedian, closeTo(75.0, 0.01));
        expect(check.isMeaningfulChange, isTrue);
      },
    );
  });

  group(
    '82-Screen Registry, Health Packages, Voice Coach & VitalsMirrorApp Widget Tests',
    () {
      test(
        'Master Screen Registry contains all 82 ScreenSpecs (S-A01..S-I05) and 8 Health Packages',
        () {
          expect(VitalsMirrorCatalogRegistry.allScreens.length, 82);
          expect(HealthPackagesRegistry.packages.length, 8);
          expect(
            VitalsMirrorCatalogRegistry.findScreen('S-A01')?.title,
            isNotEmpty,
          );
          expect(
            VitalsMirrorCatalogRegistry.findScreen('S-D05')?.screenId,
            'S-D05',
          );
          expect(
            VitalsMirrorCatalogRegistry.findScreen('S-F04')?.screenId,
            'S-F04',
          );
          expect(
            VitalsMirrorCatalogRegistry.findScreen('S-R02')?.screenId,
            'S-R02',
          );
          expect(
            VitalsMirrorCatalogRegistry.findScreen('S-I05')?.screenId,
            'S-I05',
          );
        },
      );

      test(
        'VoiceCoachController announces out-of-frame and completion states accurately',
        () {
          final coach = VoiceCoachController();
          coach.announce(
            'Your face is not in the frame!',
            tone: VoiceCueTone.outOfFrame,
            force: true,
          );
          expect(coach.currentTone, VoiceCueTone.outOfFrame);
          expect(coach.currentMessage, contains('not in the frame'));
          coach.dispose();
        },
      );

      testWidgets(
        'VitalsMirrorApp renders Home Dashboard, Health Packs, Separate Screenings & 82 Screens',
        (WidgetTester tester) async {
          final appState = AppState();
          await tester.pumpWidget(VitalsMirrorApp(appState: appState));
          await tester.pumpAndSettle();

          expect(find.text('VitalsMirror'), findsOneWidget);
          expect(find.text('Home'), findsOneWidget);
          expect(find.text('Packs'), findsOneWidget);
          expect(find.text('Scans'), findsOneWidget);

          // Switch to Health Packs tab
          await tester.tap(find.text('Packs'));
          await tester.pumpAndSettle();
          expect(find.text('Health Packs'), findsOneWidget);

          // Switch to Separate Individual Screenings tab (S-C02)
          await tester.tap(find.text('Scans'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Vitals Scan (Face rPPG)'), findsWidgets);

          // Switch to More tab (S-C07); developer tools live in a
          // collapsed section at the bottom.
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.dragUntilVisible(
            find.text('Developer tools'),
            find.byType(ListView).first,
            const Offset(0, -200),
          );
          expect(find.text('Developer tools'), findsOneWidget);
          await tester.ensureVisible(find.text('Developer tools'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Developer tools'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Screen catalogue'));
          await tester.pumpAndSettle();
          expect(find.text('Screen catalogue'), findsOneWidget);
        },
      );

      testWidgets(
        'Mobile 360x780 viewport renders all flagship screens and live scanners with ZERO overflow errors',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final appState = AppState();

          Future<void> pumpScreen(Widget child) async {
            await tester.pumpWidget(
              AppStateScope(
                notifier: appState,
                child: MaterialApp(home: child),
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(tester.takeException(), isNull);
          }

          // 1. All 5 MainShellScreen tabs at 360x780
          await pumpScreen(const MainShellScreen());
          await tester.tap(find.text('Packs'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Scans'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('History'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('More'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          // 2. Live Face rPPG Scanner & Finger PPG Scanner at 360x780
          await pumpScreen(
            const VitalsFlowScreen(
              initialMode: VitalsCaptureMode.face,
              autoStartScanner: true,
            ),
          );
          await pumpScreen(
            const VitalsFlowScreen(
              initialMode: VitalsCaptureMode.finger,
              autoStartScanner: true,
            ),
          );
          await pumpScreen(
            VitalsResultsSummaryScreen(session: appState.vitalsSessions.first),
          );

          // 3. Image Macro Scanner, Dental Scanner, Audio Suite, Movement/Vision Suite & Package Runner at 360x780
          await pumpScreen(
            const ImageScreeningFlowScreen(screenType: ImageScreenType.anaemia),
          );
          await pumpScreen(
            const ImageScreeningFlowScreen(
              screenType: ImageScreenType.oralLesion,
              autoStartScanner: true,
            ),
          );
          await pumpScreen(const DentalFlowScreen());
          await pumpScreen(const DentalFlowScreen(autoStartScanner: true));
          await pumpScreen(
            DentalResultsScreen(exam: appState.dentalExams.first),
          );
          await pumpScreen(const AudioSuiteScreen(initialScreenId: 'S-G13'));
          await pumpScreen(
            const MovementVisionSuiteScreen(initialScreenId: 'S-H06'),
          );
          await pumpScreen(
            PackageDetailAndRunnerScreen(
              package: HealthPackagesRegistry.packages.first,
            ),
          );
        },
      );

      testWidgets(
        'Live Face Scanner pauses when Face Out of Frame and speaks audible warning',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final appState = AppState();
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: VitalsFlowScreen(
                  initialMode: VitalsCaptureMode.face,
                  autoStartScanner: true,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));

          // Verify full-screen scanner elements exist
          expect(find.text('Face Vitals'), findsOneWidget);
          expect(find.textContaining("rPPG"), findsWidgets);
          expect(find.byIcon(Icons.cameraswitch_rounded), findsOneWidget);

          // Pan across camera surface to move face out of the oval frame
          await tester.drag(
            find.byType(LiveBiometricCameraSurface),
            const Offset(120, 100),
          );
          await tester.pump(const Duration(milliseconds: 200));

          // Guidance should switch to the out-of-frame instruction
          expect(find.textContaining('inside the circle'), findsWidgets);

          // Pan back to center face inside the oval frame
          await tester.drag(
            find.byType(LiveBiometricCameraSurface),
            const Offset(-120, -100),
          );
          await tester.pump(const Duration(milliseconds: 200));

          // Guidance should switch to the lock-on / detected state
          expect(find.textContaining('Face detected'), findsWidgets);
        },
      );

      testWidgets(
        'Live Finger PPG Scanner engages sensor, responds to touch, and runs reading',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final appState = AppState();
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: VitalsFlowScreen(
                  initialMode: VitalsCaptureMode.finger,
                  autoStartScanner: true,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));

          // Verify Finger PPG scanner elements exist
          expect(find.text('Finger SpO2'), findsOneWidget);
          expect(find.textContaining("PPG"), findsWidgets);
          expect(find.byType(LiveBiometricCameraSurface), findsOneWidget);

          // Tap on sensor viewfinder to toggle finger coverage
          await tester.tap(find.byType(LiveBiometricCameraSurface));
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Live Eye Scanner renders dual-eye reticle, tracks alignment, and speaks guidance',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final appState = AppState();
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: ImageScreeningFlowScreen(
                  screenType: ImageScreenType.anaemia,
                  autoStartScanner: true,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));

          // Verify Eye Scanner elements exist
          expect(find.text('Anaemia (Lower Eyelid)'), findsOneWidget);
          expect(
            find.text('30s Sclera & Conjunctival Perfusion'),
            findsOneWidget,
          );
          expect(find.byType(LiveBiometricCameraSurface), findsOneWidget);
          expect(find.text('Eyes In Frame'), findsOneWidget);

          // Simulate eye drift out of frame
          await tester.tap(find.text('Simulate Eye Drift'));
          await tester.pump(const Duration(milliseconds: 200));

          // Status pill should update to out of frame
          expect(find.textContaining('EYES NOT IN FRAME'), findsWidgets);

          // Re-align eye inside reticle
          await tester.tap(find.text('Re-Align Eye'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Face Scan Quality Failure routes to S-D06 Retake Screen, and Complete opens Results with Retake action',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final appState = AppState();
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: VitalsFlowScreen(
                  initialMode: VitalsCaptureMode.face,
                  autoStartScanner: true,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));

          // 1. Simulate Quality Failure -> Should route to S-D06 Quality Retake Screen
          // Test controls live behind the "tune" toggle in the bottom dock.
          await tester.tap(find.byTooltip('Test Controls'));
          await tester.pump(const Duration(milliseconds: 250));

          final failChip = find.textContaining('Simulate Quality Failure');
          expect(failChip, findsOneWidget);
          await tester.ensureVisible(failChip);
          await tester.tap(failChip);
          await tester.pump(const Duration(milliseconds: 300));

          // Verify S-D06 Retake Screen UI elements
          expect(find.text('Quality Retake Required'), findsOneWidget);
          expect(find.textContaining('Measured SNR: 2.4 dB'), findsOneWidget);
          expect(find.text('Root-Cause Diagnostic Flags'), findsOneWidget);
          expect(find.text('Step-by-Step Remediation Guide'), findsOneWidget);
          expect(find.textContaining('Start Guided Retake'), findsOneWidget);

          // 2. Tap Retake Button -> Should re-enter scanner
          final retakeBtn = find.textContaining('Start Guided Retake');
          await tester.ensureVisible(retakeBtn);
          await tester.tap(retakeBtn);
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Face Vitals'), findsOneWidget);

          // 3. Complete reading -> Should open Vitals Results Summary Screen
          if (find.text('Finish Scan & View Results').evaluate().isEmpty) {
            await tester.tap(find.byTooltip('Test Controls'));
            await tester.pump(const Duration(milliseconds: 250));
          }
          final finishBtn = find.text('Finish Scan & View Results');
          await tester.ensureVisible(finishBtn);
          await tester.tap(finishBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));

          // Verify Results Screen elements: Hero vitality dial, range scales, Retake Scan button
          expect(find.textContaining('Vitals & Cardio Report'), findsOneWidget);
          expect(
            find.textContaining('Face Contactless rPPG Scan'),
            findsOneWidget,
          );
          expect(find.text('Resting Heart Rate'), findsOneWidget);
          expect(find.text('Algorithm Outputs'), findsOneWidget);
          expect(find.text('ALG-BP-01'), findsOneWidget);
          expect(find.text('Blood-pressure band'), findsOneWidget);
          expect(find.text('ALG-FRM-01..15'), findsOneWidget);

          // 4. Tap Retake Scan on Results Screen -> Takes user back into scanner
          final retakeFromResultsBtn = find.text('Retake Scan');
          await tester.ensureVisible(retakeFromResultsBtn);
          expect(retakeFromResultsBtn, findsOneWidget);
          expect(find.text('Save to Profile'), findsOneWidget);
          await tester.tap(retakeFromResultsBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Face Vitals'), findsOneWidget);
        },
      );
    },
  );

  group(
    'F-16 Anaemia (ALG-IMG-01) — photo quality analyzer, session builder & guided flow',
    () {
      Uint8List rgbaFill(int w, int h, int Function(int x, int y) pixel) {
        final out = Uint8List(w * h * 4);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final v = pixel(x, y);
            final i = (y * w + x) * 4;
            out[i] = (v >> 16) & 0xFF;
            out[i + 1] = (v >> 8) & 0xFF;
            out[i + 2] = v & 0xFF;
            out[i + 3] = 0xFF;
          }
        }
        return out;
      }

      test(
        'analyzeRgba: flat grey frame fails blur (CAP-06), passes glare/dark (CAP-07)',
        () {
          final rep = analyzeRgba(rgbaFill(64, 64, (x, y) => 0x808080), 64, 64);
          expect(rep.blurScore, lessThan(1.0));
          expect(rep.blurPassed, isFalse);
          expect(rep.glarePct, 0.0);
          expect(rep.darkPct, 0.0);
          expect(rep.overallPassed, isFalse);
          expect(rep.failureReasons.first, contains('blurry'));
        },
      );

      test(
        'analyzeRgba: high-contrast checkerboard passes blur, pink ROI passes coverage',
        () {
          final rep = analyzeRgba(
            rgbaFill(64, 64, (x, y) => ((x + y).isEven ? 0xDC7882 : 0xB4505A)),
            64,
            64,
          );
          expect(rep.blurScore, greaterThan(100.0));
          expect(rep.blurPassed, isTrue);
          expect(rep.lidCoveragePct, greaterThanOrEqualTo(80.0));
          expect(rep.coveragePassed, isTrue);
          expect(rep.redGreenRatio, greaterThan(1.0));
          expect(rep.glarePassed, isTrue);
          expect(rep.darkPassed, isTrue);
          expect(rep.overallPassed, isTrue);
        },
      );

      test('analyzeRgba: 10% saturated rows fail glare (> 5%)', () {
        final rep = analyzeRgba(
          rgbaFill(
            64,
            64,
            (x, y) => y < 7 ? 0xFFFFFF : ((x + y).isEven ? 0xDC7882 : 0xB4505A),
          ),
          64,
          64,
        );
        expect(rep.glarePct, greaterThan(5.0));
        expect(rep.glarePassed, isFalse);
        expect(rep.failureReasons.join(' '), contains('glare'));
      });

      test(
        'PhotoQualityReport.simulated(good) passes, simulated(bad) fails with reasons',
        () {
          expect(
            PhotoQualityReport.simulated(good: true).overallPassed,
            isTrue,
          );
          final bad = PhotoQualityReport.simulated(good: false);
          expect(bad.overallPassed, isFalse);
          expect(bad.failureReasons, isNotEmpty);
        },
      );

      List<EyelidPhoto> simulatedPhotos({bool allGood = true}) => [
        for (final eye in EyeSide.values)
          for (final i in [1, 2])
            EyelidPhoto(
              eye: eye,
              index: i,
              quality: PhotoQualityReport.simulated(good: allGood, seed: i),
              attempts: 1,
              accepted: allGood,
            ),
      ];

      test(
        'generateAnaemiaSession: pregnant + high -> Urgent (T12 BR-SCR-03), specialist review, cut-off 11.0',
        () {
          final appState = AppState();
          final meera = appState.subjects.firstWhere(
            (s) => s.id == 'subj_pregnant_29',
          );
          final r = appState.generateAnaemiaSession(
            subject: meera,
            answers: const AnaemiaPreTestAnswers(
              treatments: {RecentTreatment.none},
              consentGiven: true,
            ),
            photos: simulatedPhotos(),
            demoOutcome: AnaemiaDemoOutcome.high,
          );
          expect(r.threshold.cutoffGdL, 11.0);
          expect(r.band, SemanticBand.high);
          expect(r.urgency, UrgencyLevel.urgent);
          expect(r.firedRuleCodes, contains('BR-SCR-03'));
          expect(r.specialistReviewRequired, isTrue);
          expect(r.hbEstInternalGdL, lessThan(11.0));
          expect(
            r.markers['HB_EST']!.displayStatus,
            MarkerDisplayStatus.internalOnly,
          );
          expect(
            r.markers['ANAEMIA_BAND']!.displayText,
            contains('Specialist review'),
          );
          expect(r.confidence, greaterThanOrEqualTo(0.6));
        },
      );

      test(
        'generateAnaemiaSession: man + normal -> Normal band, no urgency; no photos -> Not assessed',
        () {
          final appState = AppState();
          final arjun = appState.subjects.first;
          final normal = appState.generateAnaemiaSession(
            subject: arjun,
            answers: const AnaemiaPreTestAnswers(
              treatments: {RecentTreatment.none},
            ),
            photos: simulatedPhotos(),
          );
          expect(normal.threshold.cutoffGdL, 13.0);
          expect(normal.band, SemanticBand.normal);
          expect(normal.urgency, UrgencyLevel.none);
          expect(normal.specialistReviewRequired, isFalse);

          final none = appState.generateAnaemiaSession(
            subject: arjun,
            answers: const AnaemiaPreTestAnswers(),
            photos: simulatedPhotos(allGood: false),
          );
          expect(none.band, SemanticBand.notAssessed);
          expect(none.isNotAssessed, isTrue);
          expect(none.confidence, 0.0);

          appState.saveAnaemiaSession(normal);
          expect(appState.anaemiaSessions.first.sessionId, normal.sessionId);
          expect(
            appState.screeningRecords.first.title,
            'Anaemia (Lower Eyelid)',
          );
        },
      );

      testWidgets(
        'S-E01 intro shows subject, WHO table, ALG-IMG-01 card and lets the user change the person',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final appState = AppState();
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(home: AnaemiaIntroScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          expect(find.text('Anaemia screening'), findsOneWidget);
          expect(find.text('Arjun Rao'), findsOneWidget);
          expect(find.textContaining('Man: cut-off 13.0 g/dL'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Pregnant women'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('Pregnant women'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Eyelid colour CNN'),
            240,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('Eyelid colour CNN'), findsOneWidget);
          expect(find.textContaining('ALG-IMG-01'), findsWidgets);
          expect(find.text('Ready'), findsOneWidget);
          await tester.drag(find.byType(ListView).first, const Offset(0, 2400));
          await tester.pump(const Duration(milliseconds: 300));

          await tester.tap(find.text('Change'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Who is being screened?'), findsOneWidget);
          await tester.ensureVisible(
            find.byKey(const ValueKey('subject_option_subj_pregnant_29')),
          );
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(
            find.byKey(const ValueKey('subject_option_subj_pregnant_29')),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));
          expect(appState.activeSubject.id, 'subj_pregnant_29');
          expect(find.text('Meera Rao'), findsOneWidget);
          expect(
            find.textContaining('Pregnant woman: cut-off 11.0 g/dL'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'Guided anaemia test: prepare -> how-to -> 4 simulated photos -> analysis -> S-R01 result -> save',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final appState = AppState();
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(home: AnaemiaStepperScreen()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));

          // Step 1 — prepare: must answer the treatment question first
          expect(find.text('Step 1 · Prepare'), findsOneWidget);
          expect(find.text('Your details'), findsNothing);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Start the test'),
                )
                .onPressed,
            isNull,
          );
          await tester.ensureVisible(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('Start the test'));
          await tester.pump(const Duration(milliseconds: 400));

          // Step 2 — how-to
          expect(find.text('Step 2 · How to take the photos'), findsOneWidget);
          expect(find.text('Pull the lower eyelid down'), findsOneWidget);
          await tester.tap(find.text('Start photos'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);

          // Step 3 — photos (no hardware in tests → simulated good photos)
          for (var i = 1; i <= 4; i++) {
            expect(find.text('Photo $i of 4'), findsOneWidget);
            await tester.tap(find.byIcon(Icons.photo_camera_rounded));
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('Good photo'), findsOneWidget);
            await tester.tap(find.text('Keep & continue'));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
          }

          // Step 4 — analysing, then result
          expect(find.text('Step 4 · Analysing your photos'), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Anaemia result'), findsOneWidget);
          expect(find.text('Normal band'), findsOneWidget);
          expect(find.text('Left eye'), findsOneWidget);
          expect(find.text('Right eye'), findsOneWidget);
          expect(find.text('How this result is made'), findsOneWidget);
          expect(find.text('Next steps'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.ensureVisible(find.text('Save to profile'));
          await tester.tap(find.text('Save to profile'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Saved'), findsOneWidget);
          expect(appState.anaemiaSessions.length, 1);
          expect(appState.screeningRecords.first.screenId, 'S-R01');
          await tester.pump(
            const Duration(seconds: 5),
          ); // let the snackbar expire
        },
      );

      testWidgets(
        'Photo review: bad photo shows reasons, blocks Keep, allows 3 attempts then Not assessed (G-25)',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final appState = AppState();
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: AnaemiaStepperScreen(initialStep: 1),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Start photos'));
          await tester.pump(const Duration(milliseconds: 400));

          await tester.tap(find.byTooltip('Test Controls'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('Simulate bad photo'));
          await tester.pump(const Duration(milliseconds: 200));

          for (var attempt = 1; attempt <= 3; attempt++) {
            await tester.tap(find.byIcon(Icons.photo_camera_rounded));
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('Needs retake'), findsOneWidget);
            expect(find.textContaining('blurry'), findsWidgets);
            if (attempt < 3) {
              expect(
                tester
                    .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'Keep & continue'),
                    )
                    .onPressed,
                isNull,
              );
              await tester.tap(find.text('Retake ${attempt + 1} of 3'));
              await tester.pump(const Duration(milliseconds: 200));
            }
          }
          expect(find.text('Mark not assessed & continue'), findsOneWidget);
          await tester.tap(find.text('Mark not assessed & continue'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Photo 2 of 4'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Anaemia screens render at 360x780 with ZERO overflow errors',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final appState = AppState();
          Future<void> pumpScreen(Widget child) async {
            await tester.pumpWidget(
              AppStateScope(
                notifier: appState,
                child: MaterialApp(home: child),
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(tester.takeException(), isNull);
          }

          await pumpScreen(const AnaemiaIntroScreen());
          await pumpScreen(const AnaemiaStepperScreen(key: ValueKey('step0')));
          await pumpScreen(
            const AnaemiaStepperScreen(key: ValueKey('step1'), initialStep: 1),
          );
          await tester.tap(find.text('Start photos'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await tester.tap(find.byIcon(Icons.photo_camera_rounded));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Good photo'), findsOneWidget);
          expect(tester.takeException(), isNull);

          final meera = appState.subjects.firstWhere(
            (s) => s.id == 'subj_pregnant_29',
          );
          final result = appState.generateAnaemiaSession(
            subject: meera,
            answers: const AnaemiaPreTestAnswers(
              treatments: {
                RecentTreatment.transfusion3m,
                RecentTreatment.eyeInfectionToday,
              },
              otherNote: 'Felt dizzy this week',
              consentGiven: true,
            ),
            photos: simulatedPhotos(),
            demoOutcome: AnaemiaDemoOutcome.high,
          );
          await pumpScreen(AnaemiaResultScreen(result: result));
          expect(find.text('High band'), findsOneWidget);
          expect(
            find.textContaining('Possible anaemia in pregnancy'),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Quality & versions'));
          await tester.tap(find.text('Quality & versions'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  group(
    'Eye screens (ALG-IMG-02/03/06/09) — protocols, session builder & guided flows',
    () {
      List<EyePhoto> eyePhotos(EyeProtocol p, {bool allGood = true}) => [
        for (var i = 0; i < p.views.length; i++)
          EyePhoto(
            view: p.views[i],
            quality: PhotoQualityReport.simulated(
              good: allGood,
              seed: i,
              target: p.views[i].target,
            ),
            attempts: 1,
            accepted: allGood,
          ),
      ];

      test(
        'EyeProtocols: four protocols with Spec view counts, card policy and age rules',
        () {
          expect(EyeProtocols.all.length, 4);
          expect(EyeProtocols.jaundice.views.length, 4);
          expect(EyeProtocols.jaundice.cardRequired, isTrue);
          expect(EyeProtocols.cataract.views.length, 2);
          expect(EyeProtocols.cataract.minAgeYears, 40);
          expect(EyeProtocols.cataract.allowOnRequest, isTrue);
          expect(EyeProtocols.cataract.ageBlockReason(26), isNotNull);
          expect(EyeProtocols.cataract.ageBlockReason(62), isNull);
          expect(EyeProtocols.childEye.views.length, 2);
          expect(EyeProtocols.childEye.bothEyesInOneFrame, isTrue);
          expect(EyeProtocols.childEye.ageBlockReason(7), isNull);
          expect(EyeProtocols.childEye.ageBlockReason(26), isNotNull);
          expect(EyeProtocols.fundus.views.length, 4);
          expect(EyeProtocols.fundus.requiresFundusCamera, isTrue);
          expect(EyeProtocols.fundus.partnerModel, isTrue);
          expect(EyeProtocols.fundus.introScreenId, 'S-E06');
          expect(
            EyeProtocols.forScreenType(ImageScreenType.adultJaundice),
            EyeProtocols.jaundice,
          );
          expect(
            EyeProtocols.forScreenType(ImageScreenType.fundusDrGlaucoma),
            EyeProtocols.fundus,
          );
          expect(
            EyeProtocols.forScreenType(ImageScreenType.oralLesion),
            EyeProtocols.oralLesion,
          );
        },
      );

      test(
        'buildEyeSession: jaundice high -> Urgent BR-SCR-02 + specialist review; normal -> no rules',
        () {
          final appState = AppState();
          final high = buildEyeSession(
            protocol: EyeProtocols.jaundice,
            subject: appState.activeSubject,
            answers: const EyeAnswers(
              questionIds: {'symptoms'},
              hasColourCard: true,
              colourErrorDe: 2.4,
              consentGiven: true,
            ),
            photos: eyePhotos(EyeProtocols.jaundice),
            demoOutcome: EyeDemoOutcome.high,
          );
          expect(high.band, SemanticBand.high);
          expect(high.urgency, UrgencyLevel.urgent);
          expect(high.firedRuleCodes, contains('BR-SCR-02'));
          expect(high.specialistReviewRequired, isTrue);
          expect(
            high.markers['JAUNDICE_BAND']!.displayStatus,
            MarkerDisplayStatus.underSpecialistReview,
          );
          expect(
            high.markers['JAUNDICE_PROB']!.displayStatus,
            MarkerDisplayStatus.underSpecialistReview,
          );
          expect(high.whatItMeans, contains('urgent'));

          final normal = buildEyeSession(
            protocol: EyeProtocols.jaundice,
            subject: appState.activeSubject,
            answers: const EyeAnswers(
              questionIds: {'none'},
              hasColourCard: true,
              consentGiven: true,
            ),
            photos: eyePhotos(EyeProtocols.jaundice),
          );
          expect(normal.band, SemanticBand.normal);
          expect(normal.urgency, UrgencyLevel.none);
          expect(normal.firedRuleCodes, isEmpty);

          final none = buildEyeSession(
            protocol: EyeProtocols.jaundice,
            subject: appState.activeSubject,
            answers: const EyeAnswers(questionIds: {'none'}),
            photos: eyePhotos(EyeProtocols.jaundice, allGood: false),
            demoOutcome: EyeDemoOutcome.high,
          );
          expect(none.band, SemanticBand.notAssessed);
          expect(none.urgency, UrgencyLevel.none);
        },
      );

      test(
        'buildEyeSession: cataract operated eye -> that eye not assessed; combined = worse screened eye (Routine)',
        () {
          final appState = AppState();
          final senior = appState.subjects.firstWhere(
            (s) => s.id == 'subj_senior_62',
          );
          final r = buildEyeSession(
            protocol: EyeProtocols.cataract,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'surgery_left'},
              operatedEyes: {EyeSide.left},
              consentGiven: true,
            ),
            photos: eyePhotos(EyeProtocols.cataract),
            demoOutcome: EyeDemoOutcome.high,
          );
          expect(r.perEyeBand[EyeSide.left], SemanticBand.notAssessed);
          expect(r.perEyeNote[EyeSide.left], contains('Operated'));
          expect(r.perEyeBand[EyeSide.right], SemanticBand.high);
          expect(r.band, SemanticBand.high);
          expect(r.urgency, UrgencyLevel.routine);
          expect(r.firedRuleCodes, contains('BR-SCR-04'));
        },
      );

      test(
        'buildEyeSession: child white pupil -> Urgent T11 BR-SCR-02; squint -> Refer Routine',
        () {
          final appState = AppState();
          final child = appState.subjects.firstWhere(
            (s) => s.id == 'subj_child_7',
          );
          final white = buildEyeSession(
            protocol: EyeProtocols.childEye,
            subject: child,
            answers: const EyeAnswers(
              questionIds: {'none'},
              photographerRole: 'Parent / guardian',
              consentGiven: true,
            ),
            photos: eyePhotos(EyeProtocols.childEye),
            demoOutcome: EyeDemoOutcome.urgent,
          );
          expect(white.band, SemanticBand.refer);
          expect(white.urgency, UrgencyLevel.urgent);
          expect(white.firedRuleCodes, contains('BR-SCR-02'));
          expect(white.bandTitle, contains('White pupil'));
          expect(white.perEyeBand[EyeSide.left], SemanticBand.refer);
          expect(white.perEyeBand[EyeSide.right], SemanticBand.normal);

          final squint = buildEyeSession(
            protocol: EyeProtocols.childEye,
            subject: child,
            answers: const EyeAnswers(
              questionIds: {'none'},
              photographerRole: 'Operator',
            ),
            photos: eyePhotos(EyeProtocols.childEye),
            demoOutcome: EyeDemoOutcome.high,
          );
          expect(squint.band, SemanticBand.refer);
          expect(squint.urgency, UrgencyLevel.routine);
          expect(squint.firedRuleCodes, ['BR-SCR-04']);
        },
      );

      test(
        'buildEyeSession: fundus PDR+DME -> Urgent; moderate NPDR -> referable Routine + glaucoma; none -> no rules',
        () {
          final appState = AppState();
          final senior = appState.subjects.firstWhere(
            (s) => s.id == 'subj_senior_62',
          );
          EyeSessionResult run(EyeDemoOutcome o) => buildEyeSession(
            protocol: EyeProtocols.fundus,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'diabetes_known'},
              partnerConsent: true,
              consentGiven: true,
            ),
            photos: eyePhotos(EyeProtocols.fundus),
            demoOutcome: o,
          );
          final urgent = run(EyeDemoOutcome.urgent);
          expect(urgent.band, SemanticBand.refer);
          expect(urgent.urgency, UrgencyLevel.urgent);
          expect(urgent.firedRuleCodes, contains('BR-SCR-02'));
          expect(
            urgent.findings.firstWhere((f) => f.code == 'DR_GRADE_R').valueText,
            'PDR + DME',
          );
          expect(
            urgent.markers['DR_REFERABLE']!.displayStatus,
            MarkerDisplayStatus.ok,
          );

          final high = run(EyeDemoOutcome.high);
          expect(high.band, SemanticBand.refer);
          expect(high.urgency, UrgencyLevel.routine);
          expect(
            high.findings.firstWhere((f) => f.code == 'GLAUCOMA_SUSPECT').band,
            SemanticBand.refer,
          );
          expect(high.specialistReviewRequired, isTrue);

          final normal = run(EyeDemoOutcome.normal);
          expect(normal.band, SemanticBand.normal);
          expect(normal.firedRuleCodes, isEmpty);
          expect(normal.bandTitle, 'No referable DR');
        },
      );

      test(
        'analyzeRgba targets: white ROI passes sclera coverage, pink fails; dark disc passes pupil',
        () {
          const w = 64, h = 48;
          Uint8List fill(int r, int g, int b) {
            final buf = Uint8List(w * h * 4);
            for (var i = 0; i < w * h; i++) {
              buf[i * 4] = r;
              buf[i * 4 + 1] = g;
              buf[i * 4 + 2] = b;
              buf[i * 4 + 3] = 255;
            }
            return buf;
          }

          final white = analyzeRgba(
            fill(240, 236, 230),
            w,
            h,
            target: PhotoTarget.sclera,
          );
          expect(white.coveragePassed, isTrue);
          expect(white.coverageLabel, 'White of eye');
          final pink = analyzeRgba(
            fill(230, 120, 140),
            w,
            h,
            target: PhotoTarget.sclera,
          );
          expect(pink.coveragePassed, isFalse);
          expect(
            pink.failureReasons.any((s) => s.contains('white of the eye')),
            isTrue,
          );
          final pupil = analyzeRgba(
            fill(20, 20, 24),
            w,
            h,
            target: PhotoTarget.pupilLens,
          );
          expect(pupil.coveragePassed, isTrue);
          expect(pupil.coverageLabel, 'Pupil found');
          // Anaemia default stays unchanged.
          final lid = analyzeRgba(fill(230, 120, 140), w, h);
          expect(lid.target, PhotoTarget.lowerEyelid);
          expect(lid.coveragePassed, isTrue);
        },
      );

      testWidgets(
        'Jaundice prepare step: Start the test blocked until a question is answered AND the colour card is ready (G-20)',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appState = AppState();
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: EyeStepperScreen(protocol: EyeProtocols.jaundice),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Step 1 · Prepare'), findsOneWidget);
          FilledButton start() => tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start the test'),
          );
          expect(start().onPressed, isNull);
          await tester.ensureVisible(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(start().onPressed, isNull);
          expect(
            find.textContaining('Confirm the colour card is ready'),
            findsOneWidget,
          );
          await tester.ensureVisible(
            find.text('Tap when the 24-patch colour card is ready'),
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(
            find.text('Tap when the 24-patch colour card is ready'),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(start().onPressed, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Guided cataract test: prepare -> how-to -> 2 simulated photos -> analysis -> result -> save',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appState = AppState();
          appState.selectSubject(
            appState.subjects.indexWhere((s) => s.id == 'subj_senior_62'),
          );
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: EyeStepperScreen(protocol: EyeProtocols.cataract),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.ensureVisible(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('Start the test'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Step 2 · How to take the photos'), findsOneWidget);
          expect(find.text('Dim the room first'), findsOneWidget);
          await tester.tap(find.text('Start photos'));
          await tester.pump(const Duration(milliseconds: 400));
          for (var i = 1; i <= 2; i++) {
            expect(find.text('Photo $i of 2'), findsOneWidget);
            await tester.tap(find.byIcon(Icons.photo_camera_rounded));
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('Good photo'), findsOneWidget);
            expect(find.text('Pupil found'), findsOneWidget);
            await tester.tap(find.text('Keep & continue'));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
          }
          expect(find.text('Step 4 · Analysing your photos'), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Cataract result'), findsOneWidget);
          expect(find.text('Normal band'), findsOneWidget);
          expect(find.text('Left eye'), findsOneWidget);
          expect(find.text('Right eye'), findsOneWidget);
          expect(find.text('Algorithm outputs'), findsOneWidget);
          expect(find.text('ALG-IMG-03'), findsOneWidget);
          expect(find.text('CATARACT_PROB_R'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Save to profile'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Saved'), findsOneWidget);
          expect(appState.eyeSessions.length, 1);
          expect(
            appState.screeningRecords.first.title,
            'Cataract (Lens Opacity)',
          );
          await tester.pump(const Duration(seconds: 5));
        },
      );

      testWidgets(
        'Child eye: guardian role required; Test Controls white pupil -> urgent result (T11)',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appState = AppState();
          appState.selectSubject(
            appState.subjects.indexWhere((s) => s.id == 'subj_child_7'),
          );
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: EyeStepperScreen(protocol: EyeProtocols.childEye),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.ensureVisible(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Start the test'),
                )
                .onPressed,
            isNull,
          );
          await tester.ensureVisible(find.text('Parent / guardian'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('Parent / guardian'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('Start the test'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('Start photos'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.byTooltip('Test Controls'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('Outcome: White pupil'));
          await tester.pump(const Duration(milliseconds: 200));
          for (var i = 1; i <= 2; i++) {
            await tester.tap(find.byIcon(Icons.photo_camera_rounded));
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('Both pupils'), findsOneWidget);
            await tester.tap(find.text('Keep & continue'));
            await tester.pump(const Duration(milliseconds: 300));
          }
          await tester.pump(const Duration(seconds: 3));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Child eye result'), findsOneWidget);
          expect(find.text('White pupil — urgent'), findsWidgets);
          expect(
            find.textContaining("children's eye doctor within days"),
            findsWidgets,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Fundus: connect step (G-31) + partner consent -> 4 retina photos -> partner grades on result',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appState = AppState();
          appState.selectSubject(
            appState.subjects.indexWhere((s) => s.id == 'subj_senior_62'),
          );
          appState.setFundusCameraConnected(false);
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: EyeStepperScreen(protocol: EyeProtocols.fundus),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.text('Step 1 · Connect the fundus camera'),
            findsOneWidget,
          );
          expect(find.text('Not connected'), findsOneWidget);
          FilledButton cont() => tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Camera connected — continue'),
          );
          expect(cont().onPressed, isNull);
          await tester.ensureVisible(find.text('Connect camera'));
          await tester.pump();
          await tester.tap(find.text('Connect camera'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('Pairing…'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 1300));
          expect(find.text('Connected · G-31 passed'), findsOneWidget);
          expect(appState.deviceProfile.fundusCameraConnected, isTrue);
          expect(cont().onPressed, isNull);
          await tester.scrollUntilVisible(
            find.text('Share de-identified retina images with the partner AI'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(
            find.text('Share de-identified retina images with the partner AI'),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(cont().onPressed, isNotNull);
          await tester.tap(find.text('Camera connected — continue'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Step 2 · Prepare'), findsOneWidget);
          await tester.ensureVisible(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('Start the test'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('Start photos'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.byTooltip('Test Controls'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(
            find.text('Outcome: Moderate NPDR + glaucoma suspect'),
          );
          await tester.pump(const Duration(milliseconds: 200));
          for (var i = 1; i <= 4; i++) {
            expect(find.text('Photo $i of 4'), findsOneWidget);
            await tester.tap(find.byIcon(Icons.photo_camera_rounded));
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('Retina area'), findsOneWidget);
            await tester.tap(find.text('Keep & continue'));
            await tester.pump(const Duration(milliseconds: 300));
          }
          await tester.pump(const Duration(seconds: 3));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Retina result'), findsOneWidget);
          expect(find.text('Referable DR'), findsWidgets);
          expect(find.textContaining('Moderate NPDR'), findsWidgets);
          expect(find.textContaining('glaucoma suspect'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Eye screens render at 360x780 with ZERO overflow errors (4 intros, steppers, review, 4 results)',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appState = AppState();
          Future<void> pumpScreen(Widget child) async {
            await tester.pumpWidget(
              AppStateScope(
                notifier: appState,
                child: MaterialApp(home: child),
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(tester.takeException(), isNull);
          }

          for (final p in EyeProtocols.all) {
            await pumpScreen(
              EyeIntroScreen(key: ValueKey('intro_${p.id}'), protocol: p),
            );
            await pumpScreen(
              EyeStepperScreen(key: ValueKey('prep_${p.id}'), protocol: p),
            );
            await pumpScreen(
              EyeStepperScreen(
                key: ValueKey('howto_${p.id}'),
                protocol: p,
                startAtHowTo: true,
              ),
            );
          }
          await tester.tap(find.text('Start photos'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await tester.tap(find.byIcon(Icons.photo_camera_rounded));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Good photo'), findsOneWidget);
          expect(tester.takeException(), isNull);

          final senior = appState.subjects.firstWhere(
            (s) => s.id == 'subj_senior_62',
          );
          final child = appState.subjects.firstWhere(
            (s) => s.id == 'subj_child_7',
          );
          final cases =
              <(EyeProtocol, EyeDemoOutcome, EyeAnswers, SubjectProfile)>[
                (
                  EyeProtocols.jaundice,
                  EyeDemoOutcome.high,
                  const EyeAnswers(
                    questionIds: {'symptoms', 'red_eye'},
                    hasColourCard: true,
                    colourErrorDe: 2.4,
                    consentGiven: true,
                  ),
                  appState.activeSubject,
                ),
                (
                  EyeProtocols.cataract,
                  EyeDemoOutcome.high,
                  const EyeAnswers(
                    questionIds: {'surgery_left', 'symptoms'},
                    operatedEyes: {EyeSide.left},
                    consentGiven: true,
                  ),
                  senior,
                ),
                (
                  EyeProtocols.childEye,
                  EyeDemoOutcome.urgent,
                  const EyeAnswers(
                    questionIds: {'parent_noticed'},
                    photographerRole: 'Parent / guardian',
                    consentGiven: true,
                  ),
                  child,
                ),
                (
                  EyeProtocols.fundus,
                  EyeDemoOutcome.urgent,
                  const EyeAnswers(
                    questionIds: {'diabetes_known', 'laser_injection'},
                    partnerConsent: true,
                    consentGiven: true,
                  ),
                  senior,
                ),
              ];
          for (final c in cases) {
            final result = buildEyeSession(
              protocol: c.$1,
              subject: c.$4,
              answers: c.$3,
              photos: eyePhotos(c.$1),
              demoOutcome: c.$2,
            );
            await pumpScreen(
              EyeResultScreen(key: ValueKey('res_${c.$1.id}'), result: result),
            );
            await tester.ensureVisible(find.text('Quality & versions'));
            await tester.tap(find.text('Quality & versions'));
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
          }
        },
      );

      testWidgets(
        '4-View Dental Scanner (ALG-DEN-01..07) & Oral Lesion Screen (ALG-IMG-04) render 3D meshes, quality retake, and results',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final appState = AppState();
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: DentalFlowScreen(autoStartScanner: true),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));
          expect(tester.takeException(), isNull);

          // 1. Verify 4-Arch Stepper Strip & Live 3D Mesh Viewfinder
          expect(find.text('4-View Guided Dental Screening'), findsOneWidget);
          expect(find.text('1. Front Bite'), findsOneWidget);
          expect(find.text('3. Upper Arch'), findsOneWidget);
          expect(find.byType(LiveBiometricCameraSurface), findsOneWidget);

          // Switch to View 3 (Upper Occlusal Horseshoe Arch)
          await tester.tap(find.text('3. Upper Arch'));
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.textContaining('Upper Occlusal Arch'), findsWidgets);

          // 2. Test Out-of-Frame warning
          await tester.tap(find.textContaining('Test Out of Frame'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(
            find.textContaining('DENTAL ARCH OUT OF FRAME'),
            findsOneWidget,
          );
          await tester.tap(find.textContaining('Center Arch'));
          await tester.pump(const Duration(milliseconds: 200));

          // 3. Test Quality Failure -> Intraoral Quality Retake Screen -> Start Guided Retake
          await tester.tap(find.byTooltip('Test Controls'));
          await tester.pump(const Duration(milliseconds: 250));
          await tester.tap(find.text('Simulate Quality Failure'));
          await tester.pump(const Duration(milliseconds: 300));

          expect(
            find.text('Intraoral Quality Retake Required'),
            findsOneWidget,
          );
          final startGuidedRetakeBtn = find.textContaining(
            'Start Guided Retake',
          );
          expect(startGuidedRetakeBtn, findsOneWidget);
          await tester.ensureVisible(startGuidedRetakeBtn);
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(startGuidedRetakeBtn);
          await tester.pump(const Duration(milliseconds: 300));

          // 4. Complete 4-View Dental Exam -> DentalResultsScreen with Hero Score, Range Scales, FDI Odontogram & Retake Scan
          await tester.tap(
            find.textContaining('Generate FDI Chart & Caries Report'),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.text('Dental Report'), findsOneWidget);
          expect(
            find.text('Caries risk'),
            findsOneWidget,
          );
          expect(
            find.text('Gum health'),
            findsOneWidget,
          );
          expect(
            find.text('Sealant advice'),
            findsOneWidget,
          );
          expect(find.text('Retake Scan'), findsOneWidget);
          expect(find.text('Save to Profile'), findsOneWidget);

          // 5. Verify Oral Pre-Cancer & Lesion Screen (ALG-IMG-04) 5-Site Mucosa Scanner & Grad-CAM Result
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                key: ValueKey('oral_app'),
                home: ImageScreeningFlowScreen(
                  screenType: ImageScreenType.oralLesion,
                  autoStartScanner: true,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.text('1. L-Cheek'), findsOneWidget);
          expect(find.text('3. Tongue L'), findsOneWidget);
          expect(find.text('6. Palate'), findsOneWidget);

          await tester.tap(find.text('Complete Reading Now'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(
            find.text('Mouth lining classifier'),
            findsOneWidget,
          );
          expect(find.text('Retake Scan'), findsOneWidget);
        },
      );
    },
  );

  group('Skin & Body (ALG-IMG-05/07/08) — chart, protocols, builder, flows & voice', () {
    List<EyePhoto> bodyPhotos(EyeProtocol p, {bool allGood = true}) => [
      for (var i = 0; i < p.views.length; i++)
        EyePhoto(
          view: p.views[i],
          quality: PhotoQualityReport.simulated(
            good: allGood,
            seed: i,
            target: p.views[i].target,
          ),
          attempts: 1,
          accepted: allGood,
        ),
    ];

    test(
      'NeonatalBilirubinChart: AAP 2022 stand-in thresholds, bands and limits',
      () {
        final t38 = NeonatalBilirubinChart.phototherapyThreshold(
          gestationWeeks: 38,
          ageHours: 72,
          hasRiskFactors: false,
        );
        expect(t38, closeTo(18.8, 0.01));
        final t36 = NeonatalBilirubinChart.phototherapyThreshold(
          gestationWeeks: 36,
          ageHours: 48,
          hasRiskFactors: false,
        )!;
        final t36r = NeonatalBilirubinChart.phototherapyThreshold(
          gestationWeeks: 36,
          ageHours: 48,
          hasRiskFactors: true,
        )!;
        expect(t36r, lessThan(t36));
        final mid = NeonatalBilirubinChart.phototherapyThreshold(
          gestationWeeks: 40,
          ageHours: 30,
          hasRiskFactors: false,
        )!;
        expect(mid, greaterThan(13.3));
        expect(mid, lessThan(15.4));
        expect(
          NeonatalBilirubinChart.phototherapyThreshold(
            gestationWeeks: 34,
            ageHours: 48,
            hasRiskFactors: false,
          ),
          isNull,
        );
        expect(
          NeonatalBilirubinChart.phototherapyThreshold(
            gestationWeeks: 39,
            ageHours: 700,
            hasRiskFactors: false,
          ),
          isNull,
        );
        expect(
          NeonatalBilirubinChart.band(estimateMgDl: 19.0, thresholdMgDl: 18.8),
          SemanticBand.high,
        );
        expect(
          NeonatalBilirubinChart.band(estimateMgDl: 16.5, thresholdMgDl: 18.8),
          SemanticBand.borderline,
        );
        expect(
          NeonatalBilirubinChart.band(estimateMgDl: 12.0, thresholdMgDl: 18.8),
          SemanticBand.normal,
        );
        expect(
          NeonatalBilirubinChart.tableFor(
            gestationWeeks: 38,
            hasRiskFactors: false,
          ).length,
          5,
        );
      },
    );

    test(
      'Skin & Body protocols: 3 protocols, view counts, card policies, eligibility',
      () {
        expect(EyeProtocols.skinBody.length, 3);
        expect(EyeProtocols.all.length, 4);
        expect(EyeProtocols.everything.length, 9);
        expect(EyeProtocols.newbornJaundice.views.length, 4);
        expect(EyeProtocols.newbornJaundice.card, ColourCardPolicy.mandatory);
        expect(
          EyeProtocols.newbornJaundice.views
              .where((v) => v.flash == true)
              .length,
          2,
        );
        expect(EyeProtocols.diabeticFoot.views.length, 4);
        expect(EyeProtocols.diabeticFoot.card, ColourCardPolicy.required);
        expect(EyeProtocols.diabeticFoot.sideLabel(EyeSide.left), 'Left foot');
        expect(EyeProtocols.skinLesion.views.length, 3);
        expect(EyeProtocols.skinLesion.card, ColourCardPolicy.preferred);
        expect(EyeProtocols.skinLesion.eligibilityLabel(), 'All ages');
        expect(
          EyeProtocols.forScreenType(ImageScreenType.newbornJaundice),
          EyeProtocols.newbornJaundice,
        );
        expect(
          EyeProtocols.forScreenType(ImageScreenType.diabeticFoot),
          EyeProtocols.diabeticFoot,
        );
        expect(
          EyeProtocols.forScreenType(ImageScreenType.skinLesion),
          EyeProtocols.skinLesion,
        );
        final appState = AppState();
        final baby = appState.subjects.firstWhere(
          (s) => s.id == 'subj_newborn_72h',
        );
        expect(EyeProtocols.newbornJaundice.ageBlockReasonFor(baby), isNull);
        expect(
          EyeProtocols.newbornJaundice.ageBlockReasonFor(
            appState.activeSubject,
          ),
          isNotNull,
        );
        expect(EyeProtocols.jaundice.ageBlockReasonFor(baby), isNull);
        expect(EyeProtocols.cataract.ageBlockReasonFor(baby), isNotNull);
      },
    );

    test(
      'buildEyeSession newborn: above the line -> Urgent BR-SCR-02; no card -> never Normal; < 35 w -> not assessed',
      () {
        final appState = AppState();
        final baby = appState.subjects.firstWhere(
          (s) => s.id == 'subj_newborn_72h',
        );
        final high = buildEyeSession(
          protocol: EyeProtocols.newbornJaundice,
          subject: baby,
          answers: const EyeAnswers(
            questionIds: {'none'},
            hasColourCard: true,
            colourErrorDe: 2.4,
            photographerRole: 'Parent / guardian',
            consentGiven: true,
          ),
          photos: bodyPhotos(EyeProtocols.newbornJaundice),
          demoOutcome: EyeDemoOutcome.high,
        );
        expect(high.band, SemanticBand.high);
        expect(high.urgency, UrgencyLevel.urgent);
        expect(high.firedRuleCodes, contains('BR-SCR-02'));
        expect(
          high.markers['NEO_BILI_EST']!.displayStatus,
          MarkerDisplayStatus.internalOnly,
        );
        expect(
          high.markers['NEO_JAUNDICE_BAND']!.displayStatus,
          MarkerDisplayStatus.underSpecialistReview,
        );
        expect(
          high.extraCard<NeonatalChartCard>()!.thresholdAtAge,
          closeTo(18.8, 0.01),
        );
        expect(high.ageLabel, '72 h · 38 w');
        expect(high.perZone.keys, containsAll(['Forehead', 'Chest']));

        final noCard = buildEyeSession(
          protocol: EyeProtocols.newbornJaundice,
          subject: baby,
          answers: const EyeAnswers(
            questionIds: {'none'},
            hasColourCard: false,
          ),
          photos: bodyPhotos(EyeProtocols.newbornJaundice),
        );
        expect(noCard.band, SemanticBand.notAssessed);
        expect(noCard.urgency, UrgencyLevel.none);
        expect(noCard.whatItMeans, contains('E-IMG-003'));

        final preterm = buildEyeSession(
          protocol: EyeProtocols.newbornJaundice,
          subject: baby,
          answers: const EyeAnswers(
            questionIds: {'none'},
            hasColourCard: true,
            gestationWeeks: 34,
            newbornAgeHours: 72,
          ),
          photos: bodyPhotos(EyeProtocols.newbornJaundice),
          demoOutcome: EyeDemoOutcome.high,
        );
        expect(preterm.band, SemanticBand.notAssessed);
        expect(preterm.extraCard<NeonatalChartCard>()!.chartApplies, isFalse);

        final border = buildEyeSession(
          protocol: EyeProtocols.newbornJaundice,
          subject: baby,
          answers: const EyeAnswers(
            questionIds: {'bruising'},
            hasColourCard: true,
          ),
          photos: bodyPhotos(EyeProtocols.newbornJaundice),
          demoOutcome: EyeDemoOutcome.borderline,
        );
        expect(border.band, SemanticBand.borderline);
        expect(border.urgency, UrgencyLevel.routine);
        expect(border.extraCard<NeonatalChartCard>()!.hasRiskFactors, isTrue);
      },
    );

    test(
      'buildEyeSession foot: ulcer -> Urgent + wound area + right foot; at risk -> Routine; IWGDF category from answers',
      () {
        final appState = AppState();
        final senior = appState.subjects.firstWhere(
          (s) => s.id == 'subj_senior_62',
        );
        final ulcer = buildEyeSession(
          protocol: EyeProtocols.diabeticFoot,
          subject: senior,
          answers: const EyeAnswers(
            questionIds: {'numbness', 'circulation'},
            hasColourCard: true,
            colourErrorDe: 2.4,
            consentGiven: true,
          ),
          photos: bodyPhotos(EyeProtocols.diabeticFoot),
          demoOutcome: EyeDemoOutcome.high,
        );
        expect(ulcer.band, SemanticBand.ulcer);
        expect(ulcer.urgency, UrgencyLevel.urgent);
        expect(ulcer.firedRuleCodes, contains('BR-SCR-02'));
        expect(ulcer.perEyeBand[EyeSide.right], SemanticBand.ulcer);
        expect(
          ulcer.findings.firstWhere((f) => f.code == 'WOUND_AREA').valueText,
          contains('1.8 cm²'),
        );
        final card = ulcer.extraCard<FootRiskCard>()!;
        expect(card.category, 2);
        expect(card.woundAreaCm2, 1.8);

        final risk = buildEyeSession(
          protocol: EyeProtocols.diabeticFoot,
          subject: senior,
          answers: const EyeAnswers(questionIds: {'none'}, hasColourCard: true),
          photos: bodyPhotos(EyeProtocols.diabeticFoot),
          demoOutcome: EyeDemoOutcome.borderline,
        );
        expect(risk.band, SemanticBand.atRisk);
        expect(risk.urgency, UrgencyLevel.routine);
        expect(risk.firedRuleCodes, ['BR-SCR-04']);
        expect(risk.perEyeBand[EyeSide.left], SemanticBand.atRisk);
        expect(risk.perEyeBand[EyeSide.right], SemanticBand.normal);

        final healthy = buildEyeSession(
          protocol: EyeProtocols.diabeticFoot,
          subject: senior,
          answers: const EyeAnswers(questionIds: {'none'}, hasColourCard: true),
          photos: bodyPhotos(EyeProtocols.diabeticFoot),
        );
        expect(healthy.band, SemanticBand.normal);
        expect(healthy.firedRuleCodes, isEmpty);
      },
    );

    test(
      'buildEyeSession skin: suspicious -> Urgent + COND_SKIN registry row; benign -> 3 matches, no rules; ABCDE escalation',
      () {
        final appState = AppState();
        final sus = buildEyeSession(
          protocol: EyeProtocols.skinLesion,
          subject: appState.activeSubject,
          answers: const EyeAnswers(
            questionIds: {'itch_bleed'},
            hasColourCard: true,
            colourErrorDe: 2.4,
            bodyLocation: 'Arm or hand',
            durationBucket: 'Over 6 months',
            abcdeFlags: {'asymmetry', 'colour'},
            consentGiven: true,
          ),
          photos: bodyPhotos(EyeProtocols.skinLesion),
          demoOutcome: EyeDemoOutcome.urgent,
        );
        expect(sus.band, SemanticBand.suspicious);
        expect(sus.urgency, UrgencyLevel.urgent);
        expect(sus.firedRuleCodes, contains('BR-SCR-02'));
        expect(
          sus.extraCard<SkinMatchesCard>()!.matches.first.$1,
          'Melanoma pattern',
        );
        expect(sus.extraCard<SkinMatchesCard>()!.lesionMm, 9.4);
        final spec = ConfirmatoryInvestigationsRegistry.forCode('COND_SKIN');
        expect(spec.conditionCode, 'COND_SKIN');
        expect(spec.markerOrScreenName, contains('Skin'));

        final benign = buildEyeSession(
          protocol: EyeProtocols.skinLesion,
          subject: appState.activeSubject,
          answers: const EyeAnswers(
            questionIds: {'none'},
            bodyLocation: 'Leg or foot',
            durationBucket: 'Years',
          ),
          photos: bodyPhotos(EyeProtocols.skinLesion),
        );
        expect(benign.band, SemanticBand.normal);
        expect(benign.firedRuleCodes, isEmpty);
        expect(benign.extraCard<SkinMatchesCard>()!.matches.length, 3);
        expect(
          benign.findings.firstWhere((f) => f.code == 'LESION_SIZE').valueText,
          contains('not measured'),
        );

        final abcde = buildEyeSession(
          protocol: EyeProtocols.skinLesion,
          subject: appState.activeSubject,
          answers: const EyeAnswers(
            questionIds: {'none'},
            abcdeFlags: {'border', 'evolving'},
          ),
          photos: bodyPhotos(EyeProtocols.skinLesion),
        );
        expect(abcde.band, SemanticBand.refer);
        expect(abcde.urgency, UrgencyLevel.routine);
      },
    );

    test(
      'analyzeRgba body targets: skin tone passes skinPatch, grey fails; dark centre passes lesion',
      () {
        const w = 64, h = 48;
        Uint8List fill(int r, int g, int b, {bool darkCentre = false}) {
          final buf = Uint8List(w * h * 4);
          for (var y = 0; y < h; y++) {
            for (var x = 0; x < w; x++) {
              final i = (y * w + x) * 4;
              final inCentre =
                  darkCentre &&
                  x >= w * 0.36 &&
                  x < w * 0.64 &&
                  y >= h * 0.36 &&
                  y < h * 0.64;
              buf[i] = inCentre ? 40 : r;
              buf[i + 1] = inCentre ? 25 : g;
              buf[i + 2] = inCentre ? 20 : b;
              buf[i + 3] = 255;
            }
          }
          return buf;
        }

        final skin = analyzeRgba(
          fill(205, 160, 130),
          w,
          h,
          target: PhotoTarget.skinPatch,
        );
        expect(skin.coveragePassed, isTrue);
        expect(skin.coverageLabel, 'Skin area');
        final grey = analyzeRgba(
          fill(128, 128, 128),
          w,
          h,
          target: PhotoTarget.skinPatch,
        );
        expect(grey.coveragePassed, isFalse);
        expect(grey.failureReasons.any((s) => s.contains('bare skin')), isTrue);
        final foot = analyzeRgba(
          fill(190, 140, 110),
          w,
          h,
          target: PhotoTarget.footSole,
        );
        expect(foot.coveragePassed, isTrue);
        final lesion = analyzeRgba(
          fill(205, 160, 130, darkCentre: true),
          w,
          h,
          target: PhotoTarget.lesion,
        );
        expect(lesion.coveragePassed, isTrue);
        expect(lesion.coverageLabel, 'Spot centred');
        final noLesion = analyzeRgba(
          fill(205, 160, 130),
          w,
          h,
          target: PhotoTarget.lesion,
        );
        expect(noLesion.coveragePassed, isFalse);
      },
    );

    testWidgets(
      'Newborn intro shows baby details + mandatory card; prepare blocks Start until card, question and photographer',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final appState = AppState();
        appState.selectSubject(
          appState.subjects.indexWhere((s) => s.id == 'subj_newborn_72h'),
        );
        await tester.pumpWidget(
          AppStateScope(
            notifier: appState,
            child: const MaterialApp(
              home: EyeIntroScreen(protocol: EyeProtocols.newbornJaundice),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Baby details'), findsOneWidget);
        expect(find.text('Newborns 0–28 days'), findsOneWidget);
        expect(
          find.textContaining(
            'Phototherapy line (no risk factors): 18.8 mg/dL',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          AppStateScope(
            notifier: appState,
            child: const MaterialApp(
              home: EyeStepperScreen(protocol: EyeProtocols.newbornJaundice),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        FilledButton start() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Start the test'),
        );
        expect(start().onPressed, isNull);
        await tester.ensureVisible(find.text('None of these'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('None of these'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(start().onPressed, isNull);
        await tester.scrollUntilVisible(
          find.text('Parent / guardian'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Parent / guardian'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(start().onPressed, isNull);
        await tester.scrollUntilVisible(
          find.text('Tap when the 24-patch colour card is ready'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(
          find.text('Tap when the 24-patch colour card is ready'),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Mandatory'), findsOneWidget);
        expect(start().onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Guided diabetic foot test: prepare -> how-to (play aloud) -> 4 photos -> result -> save under Skin & Body',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final appState = AppState();
        appState.selectSubject(
          appState.subjects.indexWhere((s) => s.id == 'subj_senior_62'),
        );
        await tester.pumpWidget(
          AppStateScope(
            notifier: appState,
            child: const MaterialApp(
              home: EyeStepperScreen(protocol: EyeProtocols.diabeticFoot),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byTooltip('Mute voice guide'), findsOneWidget);
        await tester.tap(find.byTooltip('Mute voice guide'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byTooltip('Unmute voice guide'), findsOneWidget);
        await tester.ensureVisible(find.text('None of these'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('None of these'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.scrollUntilVisible(
          find.text('Tap when the 24-patch colour card is ready'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(
          find.text('Tap when the 24-patch colour card is ready'),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Start the test'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Step 2 · How to take the photos'), findsOneWidget);
        await tester.tap(find.text('Play instructions aloud'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Start photos'));
        await tester.pump(const Duration(milliseconds: 400));
        for (var i = 1; i <= 4; i++) {
          expect(find.text('Photo $i of 4'), findsOneWidget);
          await tester.tap(find.byIcon(Icons.photo_camera_rounded));
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('Good photo'), findsOneWidget);
          expect(find.text('Foot in frame'), findsOneWidget);
          await tester.tap(find.text('Keep & continue'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Step 4 · Analysing your photos'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Diabetic foot result'), findsOneWidget);
        expect(find.text('Healthy'), findsWidgets);
        expect(find.text('Left foot'), findsWidgets);
        expect(find.text('Foot-risk category'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Save to profile'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Saved'), findsOneWidget);
        expect(appState.eyeSessions.length, 1);
        expect(appState.screeningRecords.first.category, 'Skin & Body');
        expect(
          appState.screeningRecords.first.title,
          'Diabetic Foot Ulcer & Callus Screen',
        );
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'Skin check: location, duration and ABCDE collected; Test Controls suspicious -> urgent result',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final appState = AppState();
        await tester.pumpWidget(
          AppStateScope(
            notifier: appState,
            child: const MaterialApp(
              home: EyeStepperScreen(protocol: EyeProtocols.skinLesion),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        FilledButton start() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Start the test'),
        );
        expect(find.text('Where on the body?'), findsOneWidget);
        await tester.tap(find.text('Arm or hand'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Over 6 months'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(start().onPressed, isNull);
        await tester.scrollUntilVisible(
          find.textContaining('A — one half'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.textContaining('A — one half'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.scrollUntilVisible(
          find.text('None of these'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('None of these'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(start().onPressed, isNotNull);
        await tester.tap(find.text('Start the test'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Start photos'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byTooltip('Test Controls'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Outcome: Suspicious (melanoma-pattern)'));
        await tester.pump(const Duration(milliseconds: 200));
        for (var i = 1; i <= 3; i++) {
          expect(find.text('Photo $i of 3'), findsOneWidget);
          await tester.tap(find.byIcon(Icons.photo_camera_rounded));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('Keep & continue'));
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Skin check result'), findsOneWidget);
        expect(find.text('Suspicious — urgent'), findsWidgets);
        expect(
          find.textContaining('dermatologist within 2 weeks'),
          findsWidgets,
        );
        expect(find.text('Possible matches'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Skin & Body screens render at 360x780 with ZERO overflow errors',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final appState = AppState();
        Future<void> pumpScreen(Widget child) async {
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: MaterialApp(home: child),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));
          expect(tester.takeException(), isNull);
        }

        final baby = appState.subjects.firstWhere(
          (s) => s.id == 'subj_newborn_72h',
        );
        final senior = appState.subjects.firstWhere(
          (s) => s.id == 'subj_senior_62',
        );
        appState.selectSubject(appState.subjects.indexOf(baby));
        await pumpScreen(
          const EyeIntroScreen(
            key: ValueKey('intro_nb'),
            protocol: EyeProtocols.newbornJaundice,
          ),
        );
        await pumpScreen(
          const EyeStepperScreen(
            key: ValueKey('prep_nb'),
            protocol: EyeProtocols.newbornJaundice,
          ),
        );
        await pumpScreen(
          const EyeStepperScreen(
            key: ValueKey('howto_nb'),
            protocol: EyeProtocols.newbornJaundice,
            startAtHowTo: true,
          ),
        );
        appState.selectSubject(appState.subjects.indexOf(senior));
        for (final p in [EyeProtocols.diabeticFoot, EyeProtocols.skinLesion]) {
          await pumpScreen(
            EyeIntroScreen(key: ValueKey('intro_${p.id}'), protocol: p),
          );
          await pumpScreen(
            EyeStepperScreen(key: ValueKey('prep_${p.id}'), protocol: p),
          );
          await pumpScreen(
            EyeStepperScreen(
              key: ValueKey('howto_${p.id}'),
              protocol: p,
              startAtHowTo: true,
            ),
          );
        }
        await tester.tap(find.text('Start photos'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.photo_camera_rounded));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Good photo'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final cases =
            <(EyeProtocol, EyeDemoOutcome, EyeAnswers, SubjectProfile)>[
              (
                EyeProtocols.newbornJaundice,
                EyeDemoOutcome.urgent,
                const EyeAnswers(
                  questionIds: {'bruising', 'unwell'},
                  hasColourCard: true,
                  colourErrorDe: 2.4,
                  photographerRole: 'Parent / guardian',
                  consentGiven: true,
                ),
                baby,
              ),
              (
                EyeProtocols.newbornJaundice,
                EyeDemoOutcome.high,
                const EyeAnswers(questionIds: {'none'}, hasColourCard: false),
                baby,
              ),
              (
                EyeProtocols.diabeticFoot,
                EyeDemoOutcome.urgent,
                const EyeAnswers(
                  questionIds: {
                    'numbness',
                    'previous_ulcer',
                    'recent_treatment',
                  },
                  hasColourCard: true,
                  colourErrorDe: 2.4,
                  consentGiven: true,
                ),
                senior,
              ),
              (
                EyeProtocols.skinLesion,
                EyeDemoOutcome.urgent,
                const EyeAnswers(
                  questionIds: {'itch_bleed', 'cancer_history'},
                  hasColourCard: true,
                  colourErrorDe: 2.4,
                  bodyLocation: 'Chest or back',
                  durationBucket: '1–6 months',
                  skinType: 'IV',
                  abcdeFlags: {'asymmetry', 'border', 'evolving'},
                  consentGiven: true,
                ),
                senior,
              ),
            ];
        for (var i = 0; i < cases.length; i++) {
          final c = cases[i];
          final result = buildEyeSession(
            protocol: c.$1,
            subject: c.$4,
            answers: c.$3,
            photos: bodyPhotos(c.$1),
            demoOutcome: c.$2,
          );
          await pumpScreen(
            EyeResultScreen(key: ValueKey('res_$i'), result: result),
          );
          await tester.ensureVisible(find.text('Quality & versions'));
          await tester.tap(find.text('Quality & versions'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        }
      },
    );
  });

  group(
    'Dental section (ALG-IMG-04 · ALG-DEN-01..07) — protocols, builders, flows & chart',
    () {
      List<EyePhoto> mouthPhotos(
        EyeProtocol p, {
        Set<String> skipCodes = const {},
      }) => [
        for (var i = 0; i < p.views.length; i++)
          EyePhoto(
            view: p.views[i],
            quality: PhotoQualityReport.simulated(
              good: !skipCodes.contains(p.views[i].zoneCode),
              seed: i,
              target: p.views[i].target,
            ),
            attempts: skipCodes.contains(p.views[i].zoneCode) ? 3 : 1,
            accepted: !skipCodes.contains(p.views[i].zoneCode),
          ),
      ];

      test(
        'Dental protocols: oral 6 sites + dental 4 views, torch preview, G-05 consent, child guardian rule',
        () {
          expect(EyeProtocols.dental.length, 2);
          expect(EyeProtocols.everything.length, 9);
          final oral = EyeProtocols.oralLesion;
          expect(oral.views.length, 6);
          expect(oral.torchPreview, isTrue);
          expect(oral.flash, isTrue);
          expect(oral.card, ColourCardPolicy.none);
          expect(oral.zoneLabelsInOrder.first, 'Left cheek');
          expect(oral.zoneLabelsInOrder.last, 'Palate');
          expect(oral.consentType, ConsentType.screening);
          expect(
            EyeProtocols.forScreenType(ImageScreenType.oralLesion),
            EyeProtocols.oralLesion,
          );
          expect(ImageScreenType.oralLesion.viewsRequired.length, 6);
          final dental = EyeProtocols.dentalCaries;
          expect(dental.views.length, 4);
          expect(dental.views.map((v) => v.zoneCode), ['D1', 'D2', 'D3', 'D4']);
          expect(dental.consentType, ConsentType.dentalGuardian);
          expect(dental.introScreenId, 'S-F01');
          expect(dental.screenType, isNull);
          expect(dental.extraInputs, contains(EyeExtraInput.dentalHabits));
          final appState = AppState();
          final child = appState.subjects.firstWhere(
            (s) => s.id == 'subj_child_7',
          );
          final senior = appState.subjects.firstWhere(
            (s) => s.id == 'subj_senior_62',
          );
          expect(dental.guardianRequiredFor(child), isTrue);
          expect(dental.guardianRequiredFor(senior), isFalse);
          expect(oral.guardianRequiredFor(child), isFalse);
          expect(dental.ageBlockReasonFor(child), isNull);
          expect(dental.ageBlockReasonFor(senior), isNull);
          // Catalogue + packs point at the real ids
          expect(
            VitalsMirrorCatalogRegistry.catalogueItems.any(
              (i) => i.id == 'cat_dental_full',
            ),
            isTrue,
          );
          expect(
            HealthPackagesRegistry.packages
                .expand((pk) => pk.includedCatalogueIds)
                .any((id) => id == 'cat_dental_exam'),
            isFalse,
          );
          expect(
            HealthPackagesRegistry.packages
                .expand((pk) => pk.includedCatalogueIds)
                .where((id) => id == 'cat_dental_full')
                .length,
            greaterThanOrEqualTo(2),
          );
        },
      );

      test(
        'buildEyeSession oral: high risk -> Urgent BR-SCR-02 + internal probs + worst site; normal -> no rules; > 3 weeks -> Needs a look (T29)',
        () {
          final appState = AppState();
          final senior = appState.subjects.firstWhere(
            (s) => s.id == 'subj_senior_62',
          );
          final high = buildEyeSession(
            protocol: EyeProtocols.oralLesion,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'alcohol', 'burning'},
              tobaccoStatus: 'Chewing',
              durationBucket: 'Over 3 weeks',
              consentGiven: true,
            ),
            photos: mouthPhotos(EyeProtocols.oralLesion),
            demoOutcome: EyeDemoOutcome.urgent,
          );
          expect(high.band, SemanticBand.high);
          expect(high.urgency, UrgencyLevel.urgent);
          expect(high.firedRuleCodes, contains('BR-SCR-02'));
          expect(high.specialistReviewRequired, isTrue);
          expect(
            high.markers['ORAL_PROB_HIGH']!.displayStatus,
            MarkerDisplayStatus.underSpecialistReview,
          );
          expect(
            high.markers['ORAL_CLASS']!.displayStatus,
            MarkerDisplayStatus.underSpecialistReview,
          );
          final card = high.extraCard<OralSitesCard>()!;
          expect(card.worstSite, 'Tongue · left edge');
          expect(card.sites.length, 6);
          expect(card.sites.where((s) => s.hasLesionBox).length, 2);
          expect(card.redFlags, isNotEmpty);
          expect(high.perZone['Palate']!.band, SemanticBand.normal);

          final suspicious = buildEyeSession(
            protocol: EyeProtocols.oralLesion,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'none'},
              tobaccoStatus: 'Never',
            ),
            photos: mouthPhotos(EyeProtocols.oralLesion),
            demoOutcome: EyeDemoOutcome.high,
          );
          expect(suspicious.band, SemanticBand.suspicious);
          expect(suspicious.urgency, UrgencyLevel.urgent);
          expect(
            suspicious.extraCard<OralSitesCard>()!.worstSite,
            'Left cheek',
          );

          final normal = buildEyeSession(
            protocol: EyeProtocols.oralLesion,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'none'},
              tobaccoStatus: 'Never',
              durationBucket: 'Nothing noticed',
            ),
            photos: mouthPhotos(EyeProtocols.oralLesion),
          );
          expect(normal.band, SemanticBand.normal);
          expect(normal.firedRuleCodes, isEmpty);
          expect(normal.specialistReviewRequired, isFalse);

          final near = buildEyeSession(
            protocol: EyeProtocols.oralLesion,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'none'},
              tobaccoStatus: 'Former',
            ),
            photos: mouthPhotos(EyeProtocols.oralLesion),
            demoOutcome: EyeDemoOutcome.borderline,
          );
          expect(near.band, SemanticBand.normal);
          expect(near.specialistReviewRequired, isTrue);
          expect(near.firedRuleCodes, isEmpty);

          final reported = buildEyeSession(
            protocol: EyeProtocols.oralLesion,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'none'},
              tobaccoStatus: 'Smoking',
              durationBucket: 'Over 3 weeks',
            ),
            photos: mouthPhotos(EyeProtocols.oralLesion),
          );
          expect(reported.band, SemanticBand.refer);
          expect(reported.urgency, UrgencyLevel.routine);
          expect(reported.firedRuleCodes, ['BR-SCR-04']);

          final none = buildEyeSession(
            protocol: EyeProtocols.oralLesion,
            subject: senior,
            answers: const EyeAnswers(questionIds: {'none'}),
            photos: mouthPhotos(
              EyeProtocols.oralLesion,
              skipCodes: {'M1', 'M2', 'M3', 'M4', 'M5', 'M6'},
            ),
            demoOutcome: EyeDemoOutcome.urgent,
          );
          expect(none.band, SemanticBand.notAssessed);
          expect(none.urgency, UrgencyLevel.none);
          final spec = ConfirmatoryInvestigationsRegistry.forCode(
            'COND_ORAL_CA',
          );
          expect(spec.investigations, contains('biopsy'));
        },
      );

      test(
        'buildEyeSession dental: abscess -> Urgent T13; cavity -> Routine T14 + High; vector 4 -> Moderate; child FDI + sealants; change vs previous; partial exam',
        () {
          final appState = AppState();
          final senior = appState.subjects.firstWhere(
            (s) => s.id == 'subj_senior_62',
          );
          final child = appState.subjects.firstWhere(
            (s) => s.id == 'subj_child_7',
          );
          const goodHabits = EyeAnswers(
            questionIds: {'none'},
            brushingPerDay: 2,
            fluoridePaste: 'yes',
            sweetsPerDay: 1,
            lastDentalVisit: 'Under 6 months',
            consentGiven: true,
          );
          final abscess = buildEyeSession(
            protocol: EyeProtocols.dentalCaries,
            subject: senior,
            answers: goodHabits,
            photos: mouthPhotos(EyeProtocols.dentalCaries),
            demoOutcome: EyeDemoOutcome.urgent,
          );
          expect(abscess.urgency, UrgencyLevel.urgent);
          expect(abscess.firedRuleCodes, contains('BR-SCR-02'));
          expect(abscess.band, SemanticBand.high);
          expect(abscess.bandTitle, 'Abscess sign — urgent');
          final exam = abscess.extraCard<DentalChartCard>()!.exam;
          expect(exam.urgency, UrgencyLevel.urgent);
          expect(exam.isChildMode, isFalse);
          expect(exam.toothFindings.first.findingCode, 'abscess_sign');
          expect(exam.toothFindings.first.toothFdi, 46);
          expect(exam.gumInflammationBand, SemanticBand.high);
          expect(exam.isPartial, isFalse);
          expect(
            abscess.markers['DEN_PROB']!.displayStatus,
            MarkerDisplayStatus.internalOnly,
          );

          final cavity = buildEyeSession(
            protocol: EyeProtocols.dentalCaries,
            subject: senior,
            answers: goodHabits,
            photos: mouthPhotos(EyeProtocols.dentalCaries),
            demoOutcome: EyeDemoOutcome.high,
          );
          expect(cavity.urgency, UrgencyLevel.routine);
          expect(cavity.firedRuleCodes, ['BR-SCR-04']);
          expect(cavity.band, SemanticBand.high);
          expect(
            cavity.extraCard<DentalChartCard>()!.exam.cariesRiskBand,
            SemanticBand.high,
          );

          // BR-DEN vector 4: one white spot + brushing 2, fluoride, sweets 1 -> Moderate
          final moderate = buildEyeSession(
            protocol: EyeProtocols.dentalCaries,
            subject: senior,
            answers: goodHabits,
            photos: mouthPhotos(EyeProtocols.dentalCaries),
            demoOutcome: EyeDemoOutcome.borderline,
          );
          expect(moderate.band, SemanticBand.moderate);
          expect(moderate.urgency, UrgencyLevel.none);
          expect(moderate.firedRuleCodes, isEmpty);
          expect(
            moderate
                .extraCard<DentalChartCard>()!
                .exam
                .toothFindings
                .single
                .toothFdi,
            12,
          );

          // vector 6: no lesions + sweets 2 -> Low
          final low = buildEyeSession(
            protocol: EyeProtocols.dentalCaries,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'none'},
              brushingPerDay: 2,
              fluoridePaste: 'yes',
              sweetsPerDay: 2,
              lastDentalVisit: 'Over a year',
            ),
            photos: mouthPhotos(EyeProtocols.dentalCaries),
          );
          expect(low.band, SemanticBand.low);
          expect(low.extraCard<DentalChartCard>()!.previousExamAt, isNull);
          expect(
            low.findings.firstWhere((f) => f.code == 'DENTAL_CHANGE').valueText,
            contains('First dental baseline'),
          );

          // Child 7: primary FDI codes, mixed chart, sealant candidates 16/26/36/46
          final kid = buildEyeSession(
            protocol: EyeProtocols.dentalCaries,
            subject: child,
            answers: const EyeAnswers(
              questionIds: {'none'},
              brushingPerDay: 1,
              fluoridePaste: 'unknown',
              sweetsPerDay: 3,
              nightFeeding: false,
              lastDentalVisit: 'Never',
              photographerRole: 'Parent / guardian',
              consentGiven: true,
            ),
            photos: mouthPhotos(EyeProtocols.dentalCaries),
            demoOutcome: EyeDemoOutcome.high,
          );
          final kidCard = kid.extraCard<DentalChartCard>()!;
          expect(kidCard.exam.isChildMode, isTrue);
          expect(kidCard.mixedDentition, isTrue);
          expect(
            kidCard.exam.toothFindings.map((f) => f.toothFdi),
            containsAll([54, 51, 61]),
          );
          expect(kidCard.exam.sealantNeededTeethFdi, [16, 26, 36, 46]);
          expect(fdiToothName(54), 'Baby upper right first molar');
          expect(fdiToothName(36), 'lower left first molar');

          // Change vs previous: previous white spot on 12 -> now cavity 36 (new), 11/21 new, 12 resolved
          final previous = moderate.extraCard<DentalChartCard>()!.exam;
          final followUp = buildEyeSession(
            protocol: EyeProtocols.dentalCaries,
            subject: senior,
            answers: goodHabits,
            photos: mouthPhotos(EyeProtocols.dentalCaries),
            demoOutcome: EyeDemoOutcome.high,
            previousDental: previous,
          );
          final changes = followUp.extraCard<DentalChartCard>()!.changes;
          expect(changes, contains((36, 'New')));
          expect(changes, contains((12, 'Resolved / restored')));

          // Partial exam: upper view skipped -> unseen upper molars, cavity 36 still seen (lower)
          final partial = buildEyeSession(
            protocol: EyeProtocols.dentalCaries,
            subject: senior,
            answers: goodHabits,
            photos: mouthPhotos(EyeProtocols.dentalCaries, skipCodes: {'D3'}),
            demoOutcome: EyeDemoOutcome.high,
          );
          final pExam = partial.extraCard<DentalChartCard>()!.exam;
          expect(pExam.isPartial, isTrue);
          expect(pExam.viewsCompleted, 3);
          expect(pExam.unseenTeethFdi, containsAll([16, 26, 18]));
          expect(pExam.toothFindings.any((f) => f.toothFdi == 36), isTrue);
          expect(
            partial.perZone['Upper teeth']!.band,
            SemanticBand.notAssessed,
          );
          expect(
            ConfirmatoryInvestigationsRegistry.forCode(
              'COND_GUM_DISEASE',
            ).investigations,
            contains('probing'),
          );
        },
      );

      test(
        'analyzeRgba mouth targets: pink wet tissue passes oralMucosa; white + pink passes teethArch; grey fails both',
        () {
          const w = 64, h = 48;
          Uint8List fill(int r, int g, int b, {bool whiteBand = false}) {
            final buf = Uint8List(w * h * 4);
            for (var y = 0; y < h; y++) {
              for (var x = 0; x < w; x++) {
                final i = (y * w + x) * 4;
                final white = whiteBand && y > h * 0.3 && y < h * 0.6;
                final noise = (x * 7 + y * 13) % 9;
                buf[i] = (white ? 245 : r) - noise;
                buf[i + 1] = (white ? 240 : g) - noise;
                buf[i + 2] = (white ? 230 : b) - noise;
                buf[i + 3] = 255;
              }
            }
            return buf;
          }

          final mucosa = analyzeRgba(
            fill(215, 120, 130),
            w,
            h,
            target: PhotoTarget.oralMucosa,
          );
          expect(mucosa.coveragePassed, isTrue);
          expect(mucosa.coverageLabel, 'Mouth lining in frame');
          final grey = analyzeRgba(
            fill(150, 150, 150),
            w,
            h,
            target: PhotoTarget.oralMucosa,
          );
          expect(grey.coveragePassed, isFalse);
          final teeth = analyzeRgba(
            fill(215, 120, 130, whiteBand: true),
            w,
            h,
            target: PhotoTarget.teethArch,
          );
          expect(teeth.coveragePassed, isTrue);
          expect(teeth.coverageLabel, 'Teeth in frame');
          final greyTeeth = analyzeRgba(
            fill(120, 120, 120),
            w,
            h,
            target: PhotoTarget.teethArch,
          );
          expect(greyTeeth.coveragePassed, isFalse);
          expect(
            greyTeeth.failureReasons.any(
              (r) =>
                  r.contains('Pull the lips back') ||
                  r.contains('Show all the teeth'),
            ),
            isTrue,
          );
        },
      );

      testWidgets(
        'Guided dental check (adult): habits card gates Start -> how-to -> 4 photos (torch) -> result with FDI chart -> save files a dental exam',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appState = AppState();
          appState.selectSubject(
            appState.subjects.indexWhere((s) => s.id == 'subj_senior_62'),
          );
          final examsBefore = appState.dentalExams.length;
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: EyeStepperScreen(protocol: EyeProtocols.dentalCaries),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          FilledButton start() => tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start the test'),
          );
          expect(find.text('Brushing, fluoride and sugar'), findsOneWidget);
          expect(start().onPressed, isNull);
          await tester.tap(find.text('Twice +'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('Yes'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.scrollUntilVisible(
            find.text('Under 6 months'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Under 6 months'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(
            find.textContaining('Habits alone: Low caries risk'),
            findsOneWidget,
          );
          expect(start().onPressed, isNull);
          await tester.scrollUntilVisible(
            find.text('None of these'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(start().onPressed, isNotNull);
          await tester.tap(find.text('Start the test'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Step 2 · How to take the photos'), findsOneWidget);
          expect(find.textContaining('torch on, flash fires'), findsWidgets);
          await tester.tap(find.text('Start photos'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.byTooltip('Test Controls'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(
            find.text('Outcome: Cavity + white spots (high, routine)'),
          );
          await tester.pump(const Duration(milliseconds: 200));
          for (var i = 1; i <= 4; i++) {
            expect(find.text('Photo $i of 4'), findsOneWidget);
            await tester.tap(find.byIcon(Icons.photo_camera_rounded));
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('Good photo'), findsOneWidget);
            expect(find.text('Teeth in frame'), findsOneWidget);
            await tester.tap(find.text('Keep & continue'));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
          }
          await tester.pump(const Duration(seconds: 3));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Dental check result'), findsOneWidget);
          expect(find.text('High caries risk'), findsWidgets);
          expect(find.textContaining('dentist within 4 weeks'), findsWidgets);
          expect(find.text('Tooth chart (FDI)'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('36'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('36'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.textContaining('Tooth 36 · lower left first molar'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('Save to profile'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Save to profile'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(appState.eyeSessions.length, 1);
          expect(appState.dentalExams.length, examsBefore + 1);
          expect(appState.screeningRecords.first.category, 'Dental');
          expect(
            appState.screeningRecords.first.title,
            '4-View Dental & Caries Screening',
          );
          await tester.pump(const Duration(seconds: 5));
        },
      );

      testWidgets(
        'Mouth check (tobacco user): status must be chosen, 6 torch photos, Test Controls high risk -> urgent oral-medicine banner',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appState = AppState();
          appState.selectSubject(
            appState.subjects.indexWhere((s) => s.id == 'subj_senior_62'),
          );
          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: EyeIntroScreen(protocol: EyeProtocols.oralLesion),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Recommended for you (G-10)'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            AppStateScope(
              notifier: appState,
              child: const MaterialApp(
                home: EyeStepperScreen(protocol: EyeProtocols.oralLesion),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          FilledButton start() => tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Start the test'),
          );
          expect(
            find.textContaining('Your profile says you use tobacco'),
            findsOneWidget,
          );
          await tester.tap(find.text('Chewing'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(find.text('Nothing noticed'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(start().onPressed, isNull);
          await tester.scrollUntilVisible(
            find.text('None of these'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('None of these'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(start().onPressed, isNotNull);
          await tester.tap(find.text('Start the test'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('Start photos'));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.byTooltip('Test Controls'));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.tap(
            find.text('Outcome: High risk (red-white patch + ulcer)'),
          );
          await tester.pump(const Duration(milliseconds: 200));
          for (var i = 1; i <= 6; i++) {
            expect(find.text('Photo $i of 6'), findsOneWidget);
            await tester.tap(find.byIcon(Icons.photo_camera_rounded));
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('Mouth lining in frame'), findsOneWidget);
            await tester.tap(find.text('Keep & continue'));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
          }
          await tester.pump(const Duration(seconds: 3));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Mouth check result'), findsOneWidget);
          expect(find.text('High risk — urgent'), findsWidgets);
          expect(find.textContaining('oral-medicine'), findsWidgets);
          expect(find.text('Site by site'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Dental screens render at 360x780 with ZERO overflow errors (adult + child, four result variants)',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appState = AppState();
          Future<void> pumpScreen(Widget child) async {
            await tester.pumpWidget(
              AppStateScope(
                notifier: appState,
                child: MaterialApp(home: child),
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(tester.takeException(), isNull);
          }

          final senior = appState.subjects.firstWhere(
            (s) => s.id == 'subj_senior_62',
          );
          final child = appState.subjects.firstWhere(
            (s) => s.id == 'subj_child_7',
          );
          for (final subj in [senior, child]) {
            appState.selectSubject(appState.subjects.indexOf(subj));
            for (final p in EyeProtocols.dental) {
              await pumpScreen(
                EyeIntroScreen(
                  key: ValueKey('intro_${p.id}_${subj.id}'),
                  protocol: p,
                ),
              );
              await pumpScreen(
                EyeStepperScreen(
                  key: ValueKey('prep_${p.id}_${subj.id}'),
                  protocol: p,
                ),
              );
              await pumpScreen(
                EyeStepperScreen(
                  key: ValueKey('howto_${p.id}_${subj.id}'),
                  protocol: p,
                  startAtHowTo: true,
                ),
              );
            }
          }
          await tester.tap(find.text('Start photos'));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          expect(
            find.byTooltip('Torch off — tap to light the mouth'),
            findsOneWidget,
          );
          await tester.tap(find.byIcon(Icons.photo_camera_rounded));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Good photo'), findsOneWidget);
          expect(tester.takeException(), isNull);

          const habits = EyeAnswers(
            questionIds: {'bleeding_gums', 'braces_dentures'},
            brushingPerDay: 1,
            fluoridePaste: 'no',
            sweetsPerDay: 4,
            nightFeeding: true,
            lastDentalVisit: 'Never',
            photographerRole: 'Parent / guardian',
            consentGiven: true,
          );
          final cases =
              <(EyeProtocol, EyeDemoOutcome, EyeAnswers, SubjectProfile)>[
                (
                  EyeProtocols.oralLesion,
                  EyeDemoOutcome.urgent,
                  const EyeAnswers(
                    questionIds: {'alcohol', 'trismus', 'prior_lesion'},
                    tobaccoStatus: 'Both',
                    durationBucket: 'Over 3 weeks',
                    consentGiven: true,
                  ),
                  senior,
                ),
                (
                  EyeProtocols.oralLesion,
                  EyeDemoOutcome.normal,
                  const EyeAnswers(
                    questionIds: {'none'},
                    tobaccoStatus: 'Never',
                    durationBucket: 'Nothing noticed',
                  ),
                  senior,
                ),
                (
                  EyeProtocols.dentalCaries,
                  EyeDemoOutcome.urgent,
                  habits,
                  child,
                ),
                (
                  EyeProtocols.dentalCaries,
                  EyeDemoOutcome.normal,
                  const EyeAnswers(
                    questionIds: {'none'},
                    brushingPerDay: 2,
                    fluoridePaste: 'yes',
                    sweetsPerDay: 1,
                    lastDentalVisit: 'Under 6 months',
                  ),
                  senior,
                ),
              ];
          for (var i = 0; i < cases.length; i++) {
            final c = cases[i];
            final result = buildEyeSession(
              protocol: c.$1,
              subject: c.$4,
              answers: c.$3,
              photos: mouthPhotos(c.$1, skipCodes: i == 2 ? {'D3'} : const {}),
              demoOutcome: c.$2,
              previousDental: i == 2 ? appState.dentalExams.firstOrNull : null,
            );
            await pumpScreen(
              EyeResultScreen(key: ValueKey('res_dental_$i'), result: result),
            );
            if (c.$1.id == 'dental_caries') {
              await tester.scrollUntilVisible(
                find.text('Tooth chart (FDI)'),
                300,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pump(const Duration(milliseconds: 200));
              final fdi = i == 2 ? '85' : '11';
              await tester.tap(find.text(fdi));
              await tester.pump(const Duration(milliseconds: 300));
              expect(find.textContaining('Seen in:'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
            await tester.ensureVisible(find.text('Quality & versions'));
            await tester.tap(find.text('Quality & versions'));
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
          }
        },
      );
    },
  );

  group(
    'Marker catalogue & algorithm outputs (Doc 09 Output Markers on every result screen)',
    () {
      List<EyePhoto> photosFor(EyeProtocol p, {Set<String> skip = const {}}) =>
          [
            for (var i = 0; i < p.views.length; i++)
              EyePhoto(
                view: p.views[i],
                quality: PhotoQualityReport.simulated(
                  good: !skip.contains(p.views[i].zoneCode),
                  seed: i,
                  target: p.views[i].target,
                ),
                attempts: skip.contains(p.views[i].zoneCode) ? 3 : 1,
                accepted: !skip.contains(p.views[i].zoneCode),
              ),
          ];

      MarkerReading reading(List<ReadingGroup> groups, String code) {
        for (final g in groups) {
          for (final r in g.readings) {
            if (r.code == code || r.spec.code == code) return r;
          }
        }
        throw StateError('no reading $code');
      }

      test(
        'catalogue: every spec card present, specs verbatim, aliases, no duplicates',
        () {
          for (final id in [
            'ALG-PUL-07',
            'ALG-RSP-01',
            'ALG-HRV-01..03',
            'ALG-HRV-04',
            'ALG-SPO-01',
            'ALG-BP-01',
            'ALG-RHY-01',
            'ALG-WAV-01..05',
            'ALG-DM-01',
            'ALG-RSK-05',
            'ALG-FRM-01..15',
            'ALG-IMG-01',
            'ALG-IMG-02',
            'ALG-IMG-03',
            'ALG-IMG-04',
            'ALG-IMG-05',
            'ALG-IMG-06',
            'ALG-IMG-07',
            'ALG-IMG-08',
            'ALG-IMG-09',
            'IMG-10',
            'ALG-DEN-01..07',
            'ALG-AUD-01',
            'ALG-AUD-03',
            'ALG-AUD-05',
            'ALG-AUD-08',
            'ALG-AUD-11',
            'ALG-MOV-01',
            'ALG-MOV-06..09',
            'ALG-MOV-10',
            'ALG-MOV-13',
          ]) {
            expect(MarkerCatalogue.card(id), isNotNull, reason: id);
          }
          // Member cards reachable through a member id too.
          expect(MarkerCatalogue.card('ALG-HRV-02')!.id, 'ALG-HRV-01..03');
          expect(MarkerCatalogue.card('ALG-DEN-04')!.id, 'ALG-DEN-01..07');

          final hr = MarkerCatalogue.byCode('HR')!;
          expect(hr.unit, 'bpm');
          expect(hr.decimals, 0);
          expect(hr.validMin, 30);
          expect(hr.validMax, 220);
          expect(hr.display, MarkerDisplay.shown);
          expect(hr.thresholds, isNotNull);
          expect(
            MarkerCatalogue.byCode('HB_EST')!.display,
            MarkerDisplay.internal,
          );
          expect(
            MarkerCatalogue.byCode('SPO2_EST')!.display,
            MarkerDisplay.internal,
          );
          expect(
            MarkerCatalogue.byCode('SBP')!.display,
            MarkerDisplay.internalUntilValidated,
          );
          expect(
            MarkerCatalogue.byCode('HR_POS')!.display,
            MarkerDisplay.diagnostic,
          );
          final cp = MarkerCatalogue.byCode('CATARACT_PROB_L')!;
          expect(cp.decimals, 2);
          expect(cp.memberFacing, isTrue);
          expect(cp.threshold, 0.50);
          expect(MarkerCatalogue.byCode('caries_risk_level')!.allowedValues, [
            'low',
            'moderate',
            'high',
          ]);
          expect(
            MarkerCatalogue.byCode('CHILD_EYE_BAND')!.allowedValues,
            contains('white_pupil_urgent'),
          );
          expect(MarkerCatalogue.byCode('MAP')!.code, 'map_mmhg');
          expect(MarkerCatalogue.byCode('SHOCK_INDEX')!.code, 'shock_index');
          expect(MarkerCatalogue.byCode('VO2MAX')!.code, 'vo2max_est');
          expect(
            MarkerCatalogue.byCode('CARIES_RISK')!.code,
            'caries_risk_level',
          );

          final codes = <String>[];
          for (final c in MarkerCatalogue.cards) {
            for (final o in c.outputs) {
              codes.add(o.code);
            }
          }
          expect(
            codes.toSet().length,
            codes.length,
            reason: 'duplicate marker codes',
          );
          expect(codes.length, greaterThan(120));
          expect(
            MarkerCatalogue.vitalsCards.length,
            MarkerCatalogue.vitalsCardIds.length,
          );
        },
      );

      test(
        'resolver: face vitals session -> every vitals card, spec reasons for missing values',
        () {
          final appState = AppState();
          final s = appState.generateVitalsSession(
            captureMode: VitalsCaptureMode.face,
            hrBpm: 76,
            rrBrMin: 16,
            sbpMmhg: 117,
            dbpMmhg: 77,
            spo2Pct: 98,
            pulseSnrDb: 8.6,
            cleanBeats: 68,
            hadRecentCaffeineSmokeExercise: false,
            hasChestPain: false,
          );
          final groups = MarkerReadings.fromVitals(s, bpNumericReleased: false);
          expect(
            groups.map((g) => g.card.id),
            containsAll(MarkerCatalogue.vitalsCardIds),
          );
          final hr = reading(groups, 'HR');
          expect(hr.hasValue, isTrue);
          expect(hr.formatted, '76 bpm');
          expect(hr.memberFacing, isTrue);
          expect(reading(groups, 'SDNN').formatted, '7.9 ms');
          expect(reading(groups, 'RMSSD').formatted, '14.4 ms');
          expect(reading(groups, 'BAEVSKY_SI').formatted, '125 SI');
          final spo2 = reading(groups, 'SPO2_BAND');
          expect(spo2.hasValue, isFalse);
          expect(spo2.formatted, contains('Finger'));
          final lf = reading(groups, 'LF');
          expect(lf.hasValue, isFalse);
          expect(lf.formatted, contains('120 s'));
          expect(reading(groups, 'PI').formatted, contains('Finger mode only'));
          final map = reading(groups, 'map_mmhg');
          expect(map.formatted, '90.3 mmHg');
          expect(reading(groups, 'shock_index').formatted, '0.65 ratio');
          final sbp = reading(groups, 'SBP');
          expect(sbp.memberFacing, isFalse);
          expect(sbp.hasValue, isTrue);
          expect(reading(groups, 'HR_POS').memberFacing, isFalse);
          expect(reading(groups, 'pulse_snr_db').formatted, '8.6 dB');
          final released = MarkerReadings.fromVitals(
            s,
            bpNumericReleased: true,
          );
          expect(reading(released, 'SBP').memberFacing, isTrue);
          final dm57 = reading(groups, 'DM_PROB_57');
          expect(
            dm57.memberFacing,
            isTrue,
            reason: 'spec lists DM_PROB_57 as an output',
          );
          expect(dm57.thresholdNote, startsWith('τ 0.50'));

          final finger = appState.generateVitalsSession(
            captureMode: VitalsCaptureMode.finger,
            hrBpm: 76,
            rrBrMin: 16,
            sbpMmhg: 117,
            dbpMmhg: 77,
            spo2Pct: 98,
            pulseSnrDb: 8.6,
            cleanBeats: 68,
            hadRecentCaffeineSmokeExercise: false,
            hasChestPain: false,
          );
          final fg = MarkerReadings.fromVitals(
            finger,
            bpNumericReleased: false,
          );
          expect(reading(fg, 'SPO2_BAND').formatted, 'normal');
          expect(reading(fg, 'PI').formatted, '1.8 %');
        },
      );

      test(
        'resolver: photo-engine, anaemia and dental sessions expose spec outputs with values',
        () {
          final appState = AppState();
          final senior = appState.subjects.firstWhere(
            (s) => s.id == 'subj_senior_62',
          );
          final child = appState.subjects.firstWhere(
            (s) => s.id == 'subj_child_7',
          );

          final cataract = buildEyeSession(
            protocol: EyeProtocols.cataract,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'none'},
              consentGiven: true,
            ),
            photos: photosFor(EyeProtocols.cataract),
            demoOutcome: EyeDemoOutcome.high,
          );
          final cg = MarkerReadings.fromEye(cataract);
          expect(cg.first.card.id, 'ALG-IMG-03');
          final pr = reading(cg, 'CATARACT_PROB_R');
          expect(pr.formatted, '0.82');
          expect(pr.memberFacing, isTrue);
          expect(pr.thresholdNote, 'τ 0.50');
          expect(reading(cg, 'CATARACT_BAND').formatted, 'high');
          expect(
            reading(cg, MarkerCatalogue.reviewStatusCode).formatted,
            contains('specialist'),
          );
          expect(cg.any((g) => g.card.id == MarkerReadings.appCardId), isTrue);

          final childEye = buildEyeSession(
            protocol: EyeProtocols.childEye,
            subject: child,
            answers: const EyeAnswers(
              questionIds: {'none'},
              photographerRole: 'Parent / guardian',
              consentGiven: true,
            ),
            photos: photosFor(EyeProtocols.childEye),
            demoOutcome: EyeDemoOutcome.urgent,
          );
          final ce = MarkerReadings.fromEye(childEye);
          expect(reading(ce, 'WHITE_PUPIL_PROB').formatted, '0.93');
          expect(reading(ce, 'WHITE_PUPIL_PROB').memberFacing, isTrue);
          expect(reading(ce, 'HIRSCHBERG_DEG').formatted, '1.0 deg');
          expect(reading(ce, 'CHILD_EYE_BAND').formatted, 'white_pupil_urgent');

          final jaundice = buildEyeSession(
            protocol: EyeProtocols.jaundice,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'symptoms'},
              hasColourCard: true,
              colourErrorDe: 2.4,
              consentGiven: true,
            ),
            photos: photosFor(EyeProtocols.jaundice),
            demoOutcome: EyeDemoOutcome.high,
          );
          final jg = MarkerReadings.fromEye(jaundice);
          final bl = reading(jg, 'SCLERA_BSTAR_L');
          expect(bl.sideLabel, 'Left');
          expect(bl.formatted, endsWith(' b*'));
          expect(reading(jg, 'JAUNDICE_BAND').formatted, 'high');

          final anaemia = appState.generateAnaemiaSession(
            subject: appState.subjects.firstWhere(
              (s) => s.id == 'subj_pregnant_29',
            ),
            answers: const AnaemiaPreTestAnswers(
              treatments: {RecentTreatment.none},
              consentGiven: true,
            ),
            photos: [
              for (final eye in EyeSide.values)
                for (final i in [1, 2])
                  EyelidPhoto(
                    eye: eye,
                    index: i,
                    quality: PhotoQualityReport.simulated(good: true, seed: i),
                    attempts: 1,
                    accepted: true,
                  ),
            ],
            demoOutcome: AnaemiaDemoOutcome.high,
          );
          final ag = MarkerReadings.fromAnaemia(anaemia);
          expect(reading(ag, 'ANAEMIA_PROB').memberFacing, isTrue);
          expect(reading(ag, 'ANAEMIA_PROB').hasValue, isTrue);
          expect(reading(ag, 'HB_EST').memberFacing, isFalse);
          expect(reading(ag, 'HB_EST').formatted, endsWith(' g/dL'));
          expect(reading(ag, 'ANAEMIA_BAND').formatted, 'high');

          final dental = buildEyeSession(
            protocol: EyeProtocols.dentalCaries,
            subject: child,
            answers: const EyeAnswers(
              questionIds: {'swelling'},
              brushingPerDay: 1,
              fluoridePaste: 'no',
              sweetsPerDay: 4,
              nightFeeding: false,
              lastDentalVisit: 'Never',
              photographerRole: 'Parent / guardian',
              consentGiven: true,
            ),
            photos: photosFor(EyeProtocols.dentalCaries),
            demoOutcome: EyeDemoOutcome.urgent,
          );
          final dg = MarkerReadings.fromEye(dental);
          expect(reading(dg, 'finding_code').formatted, 'abscess_sign');
          expect(reading(dg, 'finding_prob').hasValue, isTrue);
          expect(reading(dg, 'dental_exam.partial').formatted, 'No');
          expect(reading(dg, 'dental_exam.views_completed').formatted, '4');
          expect(reading(dg, 'caries_risk_level').formatted, 'high');
          expect(reading(dg, 'GUM_INFLAM_BAND').formatted, 'high');
          final exam = dental.extraCard<DentalChartCard>()!.exam;
          final hg = MarkerReadings.fromDental(exam);
          expect(hg.single.card.id, 'ALG-DEN-01..07');
          expect(reading(hg, 'finding_code').formatted, 'abscess_sign');
          expect(reading(hg, 'tooth_fdi').formatted, contains('85'));

          final record = ScreeningSessionRecord(
            sessionId: cataract.sessionId,
            subjectId: cataract.subjectId,
            featureId: 'F-17',
            screenId: 'S-R01',
            title: 'Cataract',
            category: 'Eyes',
            recordedAt: cataract.recordedAt,
            primaryBand: cataract.band,
            urgency: cataract.urgency,
            confidence: cataract.confidence,
            summaryText: cataract.whatItMeans,
            markers: cataract.markers.values.toList(),
          );
          final rg = MarkerReadings.fromRecord(record);
          expect(rg.map((g) => g.card.id), contains('ALG-IMG-03'));
          expect(rg.any((g) => g.card.id == 'ALG-IMG-02'), isFalse);

          final demo = MarkerReadings.fromValues(
            {'PHQ9': 12, 'GAD7': 3},
            const ['ALG-AUD-11'],
          );
          expect(reading(demo, 'PHQ9').formatted, '12');
          expect(reading(demo, 'MOOD_VOICE_SCORE').formatted, contains('G-24'));
        },
      );

      testWidgets(
        'widgets: outputs section on eye, vitals, anaemia, dental, history and suites; row tap opens S-D08 sheet; zero overflow at 360x780',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appState = AppState();
          Future<void> pumpScreen(Widget child) async {
            await tester.pumpWidget(
              AppStateScope(
                notifier: appState,
                child: MaterialApp(key: UniqueKey(), home: child),
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(tester.takeException(), isNull);
          }

          final senior = appState.subjects.firstWhere(
            (s) => s.id == 'subj_senior_62',
          );
          appState.selectSubject(appState.subjects.indexOf(senior));

          // Eye result: section + tap -> detail sheet
          final cataract = buildEyeSession(
            protocol: EyeProtocols.cataract,
            subject: senior,
            answers: const EyeAnswers(
              questionIds: {'none'},
              consentGiven: true,
            ),
            photos: photosFor(EyeProtocols.cataract),
            demoOutcome: EyeDemoOutcome.high,
          );
          await pumpScreen(
            EyeResultScreen(key: const ValueKey('cat'), result: cataract),
          );
          expect(find.text('Algorithm outputs'), findsOneWidget);
          expect(find.text('ALG-IMG-03'), findsOneWidget);
          expect(find.text('CATARACT_PROB_R'), findsOneWidget);
          expect(find.text('What was found'), findsNothing);
          await tester.ensureVisible(find.text('CATARACT_PROB_R'));
          await tester.tap(find.text('CATARACT_PROB_R'));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('What it is'), findsOneWidget);
          expect(find.text('This reading'), findsOneWidget);
          expect(find.textContaining('Spec §6.3'), findsWidgets);
          expect(tester.takeException(), isNull);

          // Vitals report: grouped cards + S-D08 via scale card and waveform screen
          final s = appState.generateVitalsSession(
            captureMode: VitalsCaptureMode.face,
            hrBpm: 76,
            rrBrMin: 16,
            sbpMmhg: 117,
            dbpMmhg: 77,
            spo2Pct: 98,
            pulseSnrDb: 8.6,
            cleanBeats: 68,
            hadRecentCaffeineSmokeExercise: false,
            hasChestPain: false,
          );
          await pumpScreen(VitalsResultsSummaryScreen(session: s));
          for (final id in [
            'ALG-PUL-07',
            'ALG-RSP-01',
            'ALG-HRV-01..03',
            'ALG-WAV-01..05',
            'ALG-FRM-01..15',
          ]) {
            expect(find.text(id), findsOneWidget, reason: id);
          }
          expect(find.text('Internal & diagnostic markers'), findsOneWidget);
          await tester.ensureVisible(find.text('Resting Heart Rate'));
          await tester.pump();
          await tester.tap(find.text('Resting Heart Rate'));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('This reading'), findsOneWidget);
          expect(find.text('ALG-PUL-07 v2.4.0'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await pumpScreen(WaveformAndVascularDetailScreen(session: s));
          expect(find.text('VASC_AGE_GAP'), findsNWidgets(2));
          expect(
            find.text('Recorded pulse waveform (ALG-PUL-03/05)'),
            findsOneWidget,
          );

          // Anaemia result
          final anaemia = appState.generateAnaemiaSession(
            subject: appState.subjects.firstWhere(
              (x) => x.id == 'subj_pregnant_29',
            ),
            answers: const AnaemiaPreTestAnswers(
              treatments: {RecentTreatment.none},
              consentGiven: true,
            ),
            photos: [
              for (final eye in EyeSide.values)
                for (final i in [1, 2])
                  EyelidPhoto(
                    eye: eye,
                    index: i,
                    quality: PhotoQualityReport.simulated(good: true, seed: i),
                    attempts: 1,
                    accepted: true,
                  ),
            ],
            demoOutcome: AnaemiaDemoOutcome.high,
          );
          await pumpScreen(AnaemiaResultScreen(result: anaemia));
          expect(find.text('ALG-IMG-01'), findsOneWidget);
          expect(find.text('ANAEMIA_PROB'), findsOneWidget);

          // Dental history + generic record + suites
          await pumpScreen(
            DentalResultsScreen(exam: appState.dentalExams.first),
          );
          expect(find.text('ALG-DEN-01..07'), findsOneWidget);
          final record = ScreeningSessionRecord(
            sessionId: cataract.sessionId,
            subjectId: cataract.subjectId,
            featureId: 'F-17',
            screenId: 'S-R01',
            title: 'Cataract',
            category: 'Eyes',
            recordedAt: cataract.recordedAt,
            primaryBand: cataract.band,
            urgency: cataract.urgency,
            confidence: cataract.confidence,
            summaryText: cataract.whatItMeans,
            markers: cataract.markers.values.toList(),
          );
          await pumpScreen(SharedScreeningResultScreen(record: record));
          expect(find.text('ALG-IMG-03'), findsOneWidget);
          await pumpScreen(const MovementVisionSuiteScreen());
          expect(find.text('ALG-MOV-06..09'), findsOneWidget);
          await pumpScreen(
            const MovementIntroScreen(protocol: MovementProtocols.tappingVideo),
          );
          expect(find.textContaining('ALG-MOV-01'), findsWidgets);
          await pumpScreen(const AudioSuiteScreen());
          await tester.ensureVisible(find.text('Resp Questions'));
          await tester.pump();
          await tester.tap(find.text('Resp Questions'));
          await tester.pump(const Duration(milliseconds: 350));
          await tester.scrollUntilVisible(
            find.text('ALG-AUD-03'),
            300,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text('ALG-AUD-03'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  group('Subject tracking for photo flows (ML Kit labels per target)', () {
    test(
      'every photo target except the clip-on fundus has a tracking spec with ML Kit labels',
      () {
        for (final t in PhotoTarget.values) {
          final s = SubjectTrackSpec.forTarget(t);
          if (t == PhotoTarget.fundus) {
            expect(s, isNull);
            continue;
          }
          expect(s, isNotNull, reason: t.name);
          expect(s!.subjectName, isNotEmpty);
          expect(s.notSeenHint, isNotEmpty);
          expect(
            s.useFaceDetector || s.labels.isNotEmpty,
            isTrue,
            reason: t.name,
          );
        }
        expect(
          SubjectTrackSpec.forTarget(PhotoTarget.teethArch)!.labels,
          containsAll(['Mouth', 'Smile']),
        );
        expect(
          SubjectTrackSpec.forTarget(PhotoTarget.footSole)!.labels,
          containsAll(['Foot', 'Toe']),
        );
        expect(
          SubjectTrackSpec.forTarget(PhotoTarget.skinPatch)!.labels,
          contains('Baby'),
        );
        expect(
          SubjectTrackSpec.forTarget(PhotoTarget.bothPupils)!.useFaceDetector,
          isTrue,
        );
        expect(
          SubjectTrackSpec.forTarget(PhotoTarget.teethArch)!.subjectName,
          'Teeth',
        );
      },
    );

    test(
      'matches: teeth spec accepts Mouth / Smile above confidence, rejects Foot or weak labels',
      () {
        final teeth = SubjectTrackSpec.forTarget(PhotoTarget.teethArch)!;
        expect(teeth.matches([('Smile', 0.82), ('Skin', 0.4)]), isTrue);
        expect(teeth.matches([('Mouth', 0.46)]), isTrue);
        expect(teeth.matches([('Mouth', 0.20)]), isFalse);
        expect(teeth.matches([('Foot', 0.95), ('Toe', 0.9)]), isFalse);
        expect(teeth.matches(const []), isFalse);
        expect(teeth.best([('Smile', 0.6), ('Mouth', 0.9), ('Foot', 0.99)]), (
          'Mouth',
          0.9,
        ));
        final foot = SubjectTrackSpec.forTarget(PhotoTarget.footSole)!;
        expect(foot.matches([('Foot', 0.7)]), isTrue);
        expect(foot.matches([('Mouth', 0.9)]), isFalse);
      },
    );

    test(
      'forTargets: dental protocol tracks teeth; foot protocol tracks feet; fundus has nothing to track',
      () {
        final dental = SubjectTrackSpec.forTargets(
          EyeProtocols.dentalCaries.views.map((v) => v.target),
        )!;
        expect(dental.subjectName, 'Teeth');
        expect(dental.labels, {'Mouth', 'Smile'});
        final foot = SubjectTrackSpec.forTargets(
          EyeProtocols.diabeticFoot.views.map((v) => v.target),
        )!;
        expect(foot.subjectName, 'Foot');
        final skin = SubjectTrackSpec.forTargets(
          EyeProtocols.skinLesion.views.map((v) => v.target),
        )!;
        expect(skin.subjectName, 'Skin');
        expect(
          SubjectTrackSpec.forTargets(
            EyeProtocols.fundus.views.map((v) => v.target),
          ),
          isNull,
        );
        final child = SubjectTrackSpec.forTargets(
          EyeProtocols.childEye.views.map((v) => v.target),
        )!;
        expect(child.useFaceDetector, isTrue);
      },
    );

    test('telemetry carries detector fields with safe defaults', () {
      const t = BiometricFrameTelemetry(
        subjectInFrame: false,
        brightness: 120,
        headTiltDeg: 0,
        normalizedFaceBox: null,
        torchActive: true,
      );
      expect(t.detectorActive, isFalse);
      expect(t.subjectSeen, isFalse);
      expect(t.subjectLabel, isNull);
      expect(t.subjectCoverage, 0.0);
    });
  });
}
