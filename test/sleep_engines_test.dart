// Overnight sleep sonar engines (Doc 09 §8 ALG-AUD-07 / ALG-AUD-08):
// analyzer + extractor on synthetic 48 kHz audio, apnoea / hypopnoea
// scoring rules, AHI bands, the 4 h rule, T42 and the session builder.
import 'package:algoritam/core/domain/algorithms/risk_engine.dart';
import 'package:algoritam/core/domain/algorithms/sleep_engines.dart';
import 'package:algoritam/core/domain/algorithms/sleep_session_builder.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:algoritam/core/domain/entities/sleep_protocol.dart';
import 'package:algoritam/core/domain/entities/sleep_result.dart';
import 'package:algoritam/core/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

SonarEpoch epochOf(
  int index, {
  required List<double> amp,
  List<double>? audible,
  bool valid = true,
  double rr = 15,
}) => SonarEpoch(
  index: index,
  startS: index * 30.0,
  valid: valid,
  rr: valid ? rr : null,
  echoDb: -30,
  peakRatio: 5,
  amplitude: 1,
  ampPerSecond: amp,
  audiblePerSecond: audible ?? List<double>.filled(30, -60),
  wave: const [],
);

List<SonarEpoch> flatNight(int epochs) => [
  for (var i = 0; i < epochs; i++)
    epochOf(i, amp: List<double>.filled(30, 1.0)),
];

/// Runs a simulated feature night through the real extractor.
List<SonarEpoch> simulatedNight(String outcome, {int? epochs}) {
  const ex = BreathWaveExtractor(floorDb: -80);
  final n = epochs ?? SleepSimulated.epochCount(outcome);
  return [
    for (var i = 0; i < n; i++)
      ex.epoch(i, SleepSimulated.epochFeatures(outcome, i)),
  ];
}

void main() {
  group('ALG-AUD-07 sonar: analyzer + breathing wave', () {
    test(
      '48 kHz chirp echo modulated at 15 br/min → valid epochs, RR ≈ 15',
      () {
        final pcm = SleepSimulated.pcm(seconds: 61, rr: 15);
        final an = SonarFrameAnalyzer();
        final feats = an.push(pcm);
        expect(feats.length, greaterThanOrEqualTo(1200));
        // 20 features per second
        expect(feats[20].t - feats[0].t, closeTo(1.0, 0.02));
        const ex = BreathWaveExtractor(floorDb: -80);
        final e0 = ex.epoch(0, feats.sublist(0, 600));
        final e1 = ex.epoch(1, feats.sublist(600, 1200));
        expect(e0.valid, isTrue, reason: e0.invalidReason);
        expect(e1.valid, isTrue, reason: e1.invalidReason);
        expect(e0.rr, closeTo(15, 1.5));
        expect(e1.rr, closeTo(15, 1.5));
        expect(e0.echoDb, greaterThan(-40));
        expect(e0.ampPerSecond.length, 30);
        expect(e0.wave.length, 60);
      },
    );

    test('no echo → epoch invalid and excluded (VALID_SLEEP_H rule)', () {
      final pcm = SleepSimulated.pcm(seconds: 31, rr: 15, echo: false);
      final feats = SonarFrameAnalyzer().push(pcm);
      const ex = BreathWaveExtractor(floorDb: -80);
      final e = ex.epoch(0, feats.sublist(0, 600));
      expect(e.valid, isFalse);
      expect(e.rr, isNull);
      expect(e.invalidReason, 'No chest echo');
      final d = SleepDecision.compute([e], const []);
      expect(d.validSleepH, 0);
      expect(d.medianRr, isNull);
    });

    test('a 15 s breathing stop in the audio is scored as one apnoea', () {
      final pcm = SleepSimulated.pcm(
        seconds: 151,
        rr: 15,
        apnoeas: const [(65, 15)],
      );
      final feats = SonarFrameAnalyzer().push(pcm);
      const ex = BreathWaveExtractor(floorDb: -80);
      final epochs = [
        for (var i = 0; i < 5; i++)
          ex.epoch(i, feats.sublist(i * 600, (i + 1) * 600)),
      ];
      expect(epochs.where((e) => e.valid).length, greaterThanOrEqualTo(4));
      final ev = const ApnoeaScorer().score(epochs);
      final apnoeas = ev.where((e) => e.type == SleepEventType.apnoea).toList();
      expect(
        apnoeas.length,
        1,
        reason: ev.map((e) => '${e.type} ${e.startS}').join(', '),
      );
      expect(apnoeas.first.startS, closeTo(65, 6));
      expect(apnoeas.first.durationS, inInclusiveRange(10, 22));
      expect(apnoeas.first.dropPct, greaterThanOrEqualTo(90));
    });

    test('dominant rate picks the breathing fundamental', () {
      const ex = BreathWaveExtractor();
      final wave = [
        for (var i = 0; i < 600; i++)
          0.01 * _sin(2 * 3.14159265 * 0.25 * i / 20),
      ];
      final (rr, ratio) = ex.dominantRate(wave, 20);
      expect(rr, closeTo(15, 1.5));
      expect(ratio, greaterThan(2.5));
    });
  });

  group('ALG-AUD-08 apnoea scorer (document rules)', () {
    test('drop ≥ 90 % for ≥ 10 s → apnoea; shorter than 10 s → nothing', () {
      final night = flatNight(3);
      final amp = List<double>.filled(30, 1.0);
      for (var s = 5; s < 20; s++) {
        amp[s] = 0.05;
      }
      night.add(epochOf(3, amp: amp));
      final ev = const ApnoeaScorer().score(night);
      expect(ev.length, 1);
      expect(ev.first.type, SleepEventType.apnoea);
      expect(ev.first.durationS, 15);
      expect(ev.first.startS, 95);
      expect(ev.first.dropPct, closeTo(95, 0.5));
      final short = flatNight(3);
      final amp2 = List<double>.filled(30, 1.0);
      for (var s = 5; s < 13; s++) {
        amp2[s] = 0.02; // 8 s only
      }
      short.add(epochOf(3, amp: amp2));
      expect(const ApnoeaScorer().score(short), isEmpty);
    });

    test(
      'drop ≥ 30 % for ≥ 10 s counts only with a snore / gasp at the end',
      () {
        final amp = List<double>.filled(30, 1.0);
        for (var s = 4; s < 16; s++) {
          amp[s] = 0.5;
        }
        // no termination sound → discarded
        final quiet = flatNight(3)..add(epochOf(3, amp: amp));
        expect(const ApnoeaScorer().score(quiet), isEmpty);
        // gasp 2 s after the end → hypopnoea
        final audible = List<double>.filled(30, -60);
        audible[17] = -38;
        audible[18] = -40;
        final loud = flatNight(3)..add(epochOf(3, amp: amp, audible: audible));
        final ev = const ApnoeaScorer().score(loud);
        expect(ev.length, 1);
        expect(ev.first.type, SleepEventType.hypopnoea);
        expect(ev.first.terminatedBy, 'gasp');
        expect(ev.first.dropPct, closeTo(50, 0.5));
        // ring SpO2 dip ≥ 3 % also terminates (G-32)
        final ring = flatNight(3)..add(epochOf(3, amp: amp));
        final evRing = const ApnoeaScorer().score(
          ring,
          ringDips: const [SpO2Dip(104, 10, 4)],
        );
        expect(evRing.length, 1);
        expect(evRing.first.terminatedBy, 'spo2');
        expect(
          const ApnoeaScorer().score(
            ring,
            ringDips: const [SpO2Dip(104, 10, 2)],
          ),
          isEmpty,
        );
      },
    );

    test('events inside invalid epochs and without a baseline are ignored', () {
      final amp = List<double>.filled(30, 0.05);
      // first epoch: no preceding baseline
      expect(const ApnoeaScorer().score([epochOf(0, amp: amp)]), isEmpty);
      final night = flatNight(2)..add(epochOf(2, amp: amp, valid: false));
      expect(const ApnoeaScorer().score(night), isEmpty);
    });

    test('AHI bands and the 4 h rule (E-AUD-003)', () {
      expect(OsaBands.band(4.9), OsaBand.normal);
      expect(OsaBands.band(5), OsaBand.mild);
      expect(OsaBands.band(14.9), OsaBand.mild);
      expect(OsaBands.band(15), OsaBand.moderate);
      expect(OsaBands.band(29.9), OsaBand.moderate);
      expect(OsaBands.band(30), OsaBand.severe);
      final events = [
        for (var i = 0; i < 20; i++)
          SleepEvent(
            type: i.isEven ? SleepEventType.apnoea : SleepEventType.hypopnoea,
            startS: i * 600.0,
            durationS: 14,
            dropPct: 95,
          ),
      ];
      final full = SleepDecision.compute(flatNight(480), events);
      expect(full.validSleepH, closeTo(4.0, 1e-9));
      expect(full.ahi, closeTo(5.0, 1e-9));
      expect(full.band, OsaBand.mild);
      expect(full.partial, isFalse);
      expect(full.apnoeaEvents, 10);
      expect(full.hypopnoeaEvents, 10);
      final short = SleepDecision.compute(flatNight(479), events);
      expect(short.partial, isTrue);
      expect(short.ahi, isNull);
      expect(short.band, isNull);
      expect(short.medianRr, 15);
    });

    test('T42 [DER]: AHI ≥ 15 → Routine COND_OSA (BR-SCR-05)', () {
      final none = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(ahiEst: 14.9),
      );
      expect(none.highestUrgency, UrgencyLevel.none);
      final mod = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(ahiEst: 15),
      );
      expect(mod.highestUrgency, UrgencyLevel.routine);
      expect(mod.firedRuleCodes, contains('BR-SCR-05'));
      expect(mod.orderedFlags.first.conditionCode, 'COND_OSA');
      final sev = RiskEngine.evaluateUrgency(
        const RiskEvaluationInput(ahiEst: 38),
      );
      expect(sev.highestUrgency, UrgencyLevel.routine);
      expect(sev.orderedFlags.first.triggerDescription, contains('severe'));
    });
  });

  group('Simulated nights through the real pipeline', () {
    test('each demo outcome lands in its band', () {
      for (final (outcome, band) in [
        ('normal', OsaBand.normal),
        ('mild', OsaBand.mild),
        ('moderate', OsaBand.moderate),
        ('severe', OsaBand.severe),
      ]) {
        final epochs = simulatedNight(outcome);
        final ev = const ApnoeaScorer().score(epochs);
        final d = SleepDecision.compute(epochs, ev);
        expect(d.partial, isFalse, reason: outcome);
        expect(d.validSleepH, greaterThan(5), reason: outcome);
        expect(d.medianRr, inInclusiveRange(12, 20), reason: outcome);
        expect(
          d.band,
          band,
          reason:
              '$outcome → AHI ${d.ahi?.toStringAsFixed(1)} '
              '(${d.apnoeaEvents} A + ${d.hypopnoeaEvents} H in ${d.validSleepH.toStringAsFixed(1)} h)',
        );
      }
    });

    test('short night → breathing rate only, apnoea outputs not assessed', () {
      final epochs = simulatedNight('shortNight');
      final ev = const ApnoeaScorer().score(epochs);
      final app = AppState();
      final r = buildSleepSession(
        protocol: SleepProtocols.sonar,
        subject: app.activeSubject,
        epochs: epochs,
        events: ev,
        startedAt: DateTime(2026, 11, 9, 23),
        endedAt: DateTime(2026, 11, 10, 1, 30),
        quality: const SleepQualityFacts(sonarCheckPassed: true),
      );
      expect(r.partial, isTrue);
      expect(r.ahiEst, isNull);
      expect(r.osaBand, isNull);
      expect(r.band, SemanticBand.notAssessed);
      expect(r.urgency, UrgencyLevel.none);
      expect(r.markers['SONAR_RR']!.value, isNotNull);
      expect(r.markers['AHI_EST']!.value, isNull);
      expect(r.markers['AHI_EST']!.statusReason, contains('< 4 h'));
      expect(r.markers['VALID_SLEEP_H']!.value, closeTo(2.4, 0.3));
      expect(r.bandTitle, 'Breathing rate only');
    });

    test('severe night → red band, Routine urgency, COND_OSA rule', () {
      final epochs = simulatedNight('severe');
      final ev = const ApnoeaScorer().score(epochs);
      final app = AppState();
      final r = buildSleepSession(
        protocol: SleepProtocols.sonar,
        subject: app.activeSubject,
        epochs: epochs,
        events: ev,
        startedAt: DateTime(2026, 11, 9, 23),
        endedAt: DateTime(2026, 11, 10, 5),
        quality: const SleepQualityFacts(sonarCheckPassed: true),
      );
      expect(r.osaBand, OsaBand.severe);
      expect(r.band, SemanticBand.critical);
      expect(r.urgency, UrgencyLevel.routine);
      expect(r.firedRuleCodes, contains('BR-SCR-05'));
      expect(r.markers['OSA_BAND']!.value, 'severe');
      expect(r.markers['AHI_EST']!.value, greaterThanOrEqualTo(30));
      // weak sonar check lowers confidence
      final weak = buildSleepSession(
        protocol: SleepProtocols.sonar,
        subject: app.activeSubject,
        epochs: epochs,
        events: ev,
        startedAt: DateTime(2026, 11, 9, 23),
        endedAt: DateTime(2026, 11, 10, 5),
        quality: const SleepQualityFacts(sonarCheckPassed: false),
      );
      expect(weak.confidence, lessThan(r.confidence));
    });
  });
}

double _sin(double x) {
  // tiny Taylor-free sine via dart:math would need an import; keep it plain
  return _sinImpl(x);
}

double _sinImpl(double x) {
  const twoPi = 6.283185307179586;
  x = x % twoPi;
  if (x > 3.141592653589793) x -= twoPi;
  // Bhaskara-quality approximation is enough for a 0.25 Hz test wave
  var term = x, sum = x;
  for (var k = 1; k < 10; k++) {
    term *= -x * x / ((2 * k) * (2 * k + 1));
    sum += term;
  }
  return sum;
}
