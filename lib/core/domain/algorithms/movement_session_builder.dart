// Turns raw movement-test captures into a [MovementSessionResult]
// (Doc 09 §9 ALG-MOV-01..05 + MOV-13, §10 RSK-02/03/04/06).
import '../entities/enums.dart';
import '../entities/marker_envelope.dart';
import '../entities/member_profile.dart';
import '../entities/movement_protocol.dart';
import '../entities/movement_result.dart';
import 'marker_readings.dart';
import 'movement_engines.dart';
import 'risk_engine.dart';

/// Raw capture for one side (or the whole body for gait / STS).
class MovementSideCapture {
  const MovementSideCapture({
    required this.side,
    this.skipped = false,
    this.restarts = 0,
    this.tapSamples = const [],
    this.touchTaps = const [],
    this.motion = const [],
    this.handVisiblePct,
    this.fps,
    this.skipReason,
  });

  final MovementSide? side;
  final bool skipped;

  /// Why a side was skipped (auto-skip after restarts, or the user).
  final String? skipReason;
  final int restarts;
  final List<TapSample> tapSamples;
  final List<TouchTap> touchTaps;

  /// Accelerometer (m/s²) or gyroscope (deg/s) samples.
  final List<MotionSample> motion;
  final double? handVisiblePct;
  final double? fps;
}

/// Previous saved sessions of the same protocol, newest first (for RSK-03).
typedef MovementHistory = List<MovementSessionResult>;

MovementSessionResult buildMovementSession({
  required MovementProtocol protocol,
  required SubjectProfile subject,
  required List<MovementSideCapture> captures,
  required String backend,
  required MovementDemoOutcome demoOutcome,
  MovementHistory history = const [],
  bool hasVoiceTask = false,
  bool hasFaceTask = false,
  bool sensorSimulated = true,
  int retakes = 0,
  String? sessionId,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final id = sessionId ?? 'mov_${at.millisecondsSinceEpoch}';

  final sides = <MovementSideResult>[];
  final env = <String, MarkerEnvelope<dynamic>>{};
  double? accelHz, gyroHz, fps, handPct;
  var dropped = 0;
  var restarts = 0;
  double? noiseFloor, peakRatio;
  final overall = <String, double>{};

  for (final c in captures) {
    restarts += c.restarts;
    if (c.skipped) {
      sides.add(
        MovementSideResult(
          side: c.side,
          assessed: false,
          skipped: true,
          note: c.skipReason ?? 'Skipped by you — not assessed',
        ),
      );
      continue;
    }
    switch (protocol.kind) {
      case MovementTestKind.tappingVideo:
        final m = TapSeriesAnalyzer.analyze(c.tapSamples);
        fps = c.fps ?? m.fps;
        handPct = c.handVisiblePct;
        if (m.count == 0) {
          sides.add(
            MovementSideResult(
              side: c.side,
              assessed: false,
              restarts: c.restarts,
              note: 'No taps detected — hand not tracked',
            ),
          );
          continue;
        }
        final band = m.decrementPct >= 20
            ? SemanticBand.refer
            : m.decrementPct >= 15
            ? SemanticBand.borderline
            : SemanticBand.normal;
        sides.add(
          MovementSideResult(
            side: c.side,
            assessed: true,
            restarts: c.restarts,
            band: band,
            values: {
              'TAP_COUNT': m.count.toDouble(),
              'TAP_FREQ': m.freqHz,
              'TAP_DECREMENT': m.decrementPct,
              'TAP_CV': m.cvPct,
            },
            note:
                '${m.count} taps · ${m.freqHz.toStringAsFixed(1)} Hz · decrement ${m.decrementPct.toStringAsFixed(0)} %',
          ),
        );
      case MovementTestKind.tappingTouch:
        final m = TouchTapAnalyzer.analyze(c.touchTaps);
        if (m.tooFew) {
          sides.add(
            MovementSideResult(
              side: c.side,
              assessed: false,
              restarts: c.restarts,
              note: 'Fewer than 5 alternating taps',
            ),
          );
          continue;
        }
        sides.add(
          MovementSideResult(
            side: c.side,
            assessed: true,
            restarts: c.restarts,
            band: SemanticBand.rangeNotAvailable,
            values: {
              'TOUCH_TAP_COUNT': m.alternatingCount.toDouble(),
              'INTER_TAP_CV': m.interTapCvPct,
            },
            note:
                '${m.alternatingCount} alternating taps · rhythm CV ${m.interTapCvPct.toStringAsFixed(0)} %${m.misses > 0 ? ' · ${m.misses} same-target taps ignored' : ''}',
          ),
        );
      case MovementTestKind.gait:
        final m = GaitAnalyzer.analyze(c.motion);
        accelHz = m.achievedHz;
        dropped += m.droppedSamples;
        if (!m.valid) {
          sides.add(
            MovementSideResult(
              side: null,
              assessed: false,
              restarts: c.restarts,
              note: 'No walking rhythm detected',
            ),
          );
          continue;
        }
        overall.addAll({
          'STEPS': m.steps.toDouble(),
          'CADENCE': m.cadenceSpm,
          'STEP_CV': m.stepCvPct,
          'GAIT_SPEED': m.speedMs,
        });
        sides.add(
          MovementSideResult(
            side: null,
            assessed: true,
            restarts: c.restarts,
            band: m.speedMs >= 0.8 ? SemanticBand.normal : SemanticBand.refer,
            values: Map<String, double>.from(overall),
            note:
                '${m.steps} steps in ${m.walkDurationS.toStringAsFixed(1)} s · ${m.cadenceSpm.toStringAsFixed(0)} steps/min',
          ),
        );
      case MovementTestKind.sitToStand:
        final m = StsCycleCounter.analyze(c.motion);
        accelHz = m.achievedHz;
        dropped += m.droppedSamples;
        if (m.dropout) {
          sides.add(
            MovementSideResult(
              side: null,
              assessed: false,
              restarts: c.restarts,
              note: 'Sensor dropout — repeat the test',
            ),
          );
          continue;
        }
        overall['STS_COUNT_30S'] = m.count.toDouble();
        final norm = stsAgeNorm(subject.ageYears);
        sides.add(
          MovementSideResult(
            side: null,
            assessed: true,
            restarts: c.restarts,
            band: norm == null
                ? SemanticBand.rangeNotAvailable
                : m.count >= norm
                ? SemanticBand.normal
                : SemanticBand.refer,
            values: {'STS_COUNT_30S': m.count.toDouble()},
            note: '${m.count} full stands in 30 s',
          ),
        );
      case MovementTestKind.tremor:
        final m = TremorAnalyzer.analyze(c.motion);
        gyroHz = m.achievedHz;
        dropped += m.droppedSamples;
        noiseFloor = m.floorPsd;
        peakRatio = m.peakRatio;
        if (m.achievedHz == 0 && c.motion.length < 300) {
          sides.add(
            MovementSideResult(
              side: c.side,
              assessed: false,
              restarts: c.restarts,
              note: 'Too little data',
            ),
          );
          continue;
        }
        final f = m.freqHz;
        // Spec §9 MOV-05: normal = no spectral peak above the sensor noise
        // floor. Any significant peak is a finding (COND_PD / essential
        // tremor); the range note says which band of the document it sits in.
        final band = !m.peakAboveFloor
            ? SemanticBand.normal
            : SemanticBand.refer;
        sides.add(
          MovementSideResult(
            side: c.side,
            assessed: true,
            restarts: c.restarts,
            band: band,
            values: {'TREMOR_FREQ': ?f, 'TREMOR_AMP': ?m.ampDegS},
            note: !m.peakAboveFloor
                ? 'No peak above the noise floor'
                : '${f!.toStringAsFixed(1)} Hz · ${m.ampDegS!.toStringAsFixed(1)} deg/s · ${tremorRangeLabel(f)}',
          ),
        );
    }
  }

  // --- Demo outcome stand-in when nothing real came in -------------------
  // Captures always exist; the demo outcome only nudges simulated runs.

  // --- Overall band, hero ----------------------------------------------------
  final assessed = sides.where((s) => s.assessed).toList();
  final anyAssessed = assessed.isNotEmpty;
  SemanticBand band = anyAssessed
      ? _worse(assessed.map((s) => s.band))
      : SemanticBand.notAssessed;

  String heroCode;
  double? heroValue;
  String heroLabel;
  String? ageNormLabel;
  switch (protocol.kind) {
    case MovementTestKind.tappingVideo:
      heroCode = 'TAP_DECREMENT';
      heroValue = _maxOf(assessed, 'TAP_DECREMENT');
      heroLabel = heroValue == null
          ? 'Not assessed'
          : '${heroValue.toStringAsFixed(0)} % decrement';
    case MovementTestKind.tappingTouch:
      heroCode = 'TOUCH_TAP_COUNT';
      heroValue = _minOf(assessed, 'TOUCH_TAP_COUNT');
      heroLabel = heroValue == null
          ? 'Not assessed'
          : '${heroValue.toStringAsFixed(0)} taps (slower hand)';
    case MovementTestKind.gait:
      heroCode = 'GAIT_SPEED';
      heroValue = overall['GAIT_SPEED'];
      heroLabel = heroValue == null
          ? 'Not assessed'
          : '${heroValue.toStringAsFixed(2)} m/s';
    case MovementTestKind.sitToStand:
      heroCode = 'STS_COUNT_30S';
      heroValue = overall['STS_COUNT_30S'];
      heroLabel = heroValue == null
          ? 'Not assessed'
          : '${heroValue.toStringAsFixed(0)} stands';
      final norm = stsAgeNorm(subject.ageYears);
      ageNormLabel = norm == null
          ? 'Age / sex norm pending (Q-COHORT)'
          : 'Age ${subject.ageYears}: norm ≥ $norm (Spec §9)';
    case MovementTestKind.tremor:
      heroCode = 'TREMOR_FREQ';
      heroValue = _maxOf(assessed, 'TREMOR_FREQ');
      final worst = assessed.isEmpty
          ? null
          : assessed.reduce((a, b) => _rank(a.band) >= _rank(b.band) ? a : b);
      heroLabel = worst == null
          ? 'Not assessed'
          : worst.values.containsKey('TREMOR_FREQ')
          ? '${worst.values['TREMOR_FREQ']!.toStringAsFixed(1)} Hz · ${worst.values['TREMOR_AMP']!.toStringAsFixed(1)} deg/s'
          : 'No tremor peak';
  }

  // --- Marker envelopes (spec codes, per-side suffix) ------------------------
  for (final s in sides) {
    final suffix = s.side == null ? '' : '_${s.side!.suffix}';
    if (s.assessed &&
        protocol.kind == MovementTestKind.tremor &&
        !s.values.containsKey('TREMOR_FREQ')) {
      // Normal tremor result: the spec outputs exist but carry no peak.
      for (final code in ['TREMOR_FREQ', 'TREMOR_AMP']) {
        env['$code$suffix'] = MarkerReadings.synth(
          '$code$suffix',
          value: 'No peak',
          algorithmId: protocol.algorithmId,
          band: SemanticBand.normal,
          status: MarkerDisplayStatus.ok,
          reason: 'No peak above the sensor noise floor (normal)',
          version: protocol.algorithmVersion,
          confidence: 0.9,
        );
      }
    }
    for (final e in s.values.entries) {
      final code = '${e.key}$suffix';
      final numericNorm = _hasSpecNorm(e.key, subject.ageYears);
      env[code] = MarkerReadings.synth(
        code,
        value: e.value,
        algorithmId: protocol.algorithmId,
        band: numericNorm ? s.band : SemanticBand.rangeNotAvailable,
        status: numericNorm
            ? MarkerDisplayStatus.ok
            : MarkerDisplayStatus.rangeNotAvailable,
        reason: numericNorm ? null : 'Age norms pending (Q-COHORT)',
        version: protocol.algorithmVersion,
        confidence: 0.9,
      );
    }
    if (!s.assessed && s.side != null) {
      // Keep a visible "not assessed" row for the skipped hand.
      final code = '${_primaryCode(protocol.kind)}_${s.side!.suffix}';
      env[code] = MarkerReadings.synth(
        code,
        value: null,
        algorithmId: protocol.algorithmId,
        band: SemanticBand.notAssessed,
        status: MarkerDisplayStatus.notAssessed,
        reason: s.note,
        version: protocol.algorithmVersion,
      );
    }
  }

  // --- PD composite (MOV-13) ------------------------------------------------
  final hasTapping =
      protocol.kind == MovementTestKind.tappingVideo ||
      protocol.kind == MovementTestKind.tappingTouch ||
      history.any(
        (h) =>
            (h.protocol.kind == MovementTestKind.tappingVideo ||
                h.protocol.kind == MovementTestKind.tappingTouch) &&
            at.difference(h.recordedAt).inDays <= 90,
      );
  SemanticBand? pdBand;
  double? pdProb;
  if (hasTapping && hasVoiceTask && hasFaceTask) {
    final dec = _maxOf(assessed, 'TAP_DECREMENT') ?? 0;
    final tremorPd = assessed.any((s) {
      final f = s.values['TREMOR_FREQ'];
      return f != null && f >= 4 && f <= 6;
    });
    pdBand = dec >= 20 || tremorPd ? SemanticBand.refer : SemanticBand.low;
    pdProb = (0.12 + dec / 100 * 0.6 + (tremorPd ? 0.25 : 0)).clamp(0.0, 0.95);
    env['PD_BAND'] = MarkerReadings.synth(
      'PD_BAND',
      value: pdBand == SemanticBand.refer ? 'refer' : 'low',
      algorithmId: 'ALG-MOV-13',
      band: pdBand,
      status: MarkerDisplayStatus.bandOnly,
      reason: 'Stand-in rule until MOV-PD-01 classifier ships [DER]',
    );
    env['PD_PROB'] = MarkerReadings.synth(
      'PD_PROB',
      value: pdProb,
      algorithmId: 'ALG-MOV-13',
      band: pdBand,
      status: MarkerDisplayStatus.internalOnly,
      reason: 'Not member-facing [OPEN]',
    );
  }
  final pd = PdCompositeStatus(
    hasTapping: hasTapping,
    hasVoice: hasVoiceTask,
    hasFace: hasFaceTask,
    band: pdBand,
    prob: pdProb,
  );

  // --- Risk rules (RSK-02, T30/T31 [DER]) ----------------------------------
  double? tremorPeak;
  for (final s in assessed) {
    final f = s.values['TREMOR_FREQ'];
    if (f != null && (tremorPeak == null || f < tremorPeak)) tremorPeak = f;
  }
  final norm = stsAgeNorm(subject.ageYears);
  final risk = RiskEngine.evaluateUrgency(
    RiskEvaluationInput(
      gaitSpeedMs: overall['GAIT_SPEED'],
      stsCount: overall['STS_COUNT_30S']?.round(),
      stsAgeNormMin: norm,
      tremorPeakHz: tremorPeak,
      tapDecrementPct: _maxOf(assessed, 'TAP_DECREMENT'),
      pdBand: pdBand,
    ),
    sessionId: id,
    timestamp: at,
  );
  if (risk.highestUrgency != UrgencyLevel.none && band == SemanticBand.normal) {
    band = SemanticBand.refer;
  }

  // --- Quality, confidence, baseline ----------------------------------------
  final quality = MovementQualityFacts(
    achievedAccelHz: accelHz,
    achievedGyroHz: gyroHz,
    droppedSamples: dropped,
    framesPerSecond: fps,
    handVisiblePct: handPct,
    backend: backend,
    restarts: restarts,
    retakes: retakes,
    sensorSimulated: sensorSimulated,
    noiseFloorPsd: noiseFloor,
    peakRatio: peakRatio,
  );
  final confidence = RiskEngine.computeResultConfidence(
    captureQualityScore: quality.captureQualityScore,
    modelConfidence: backend == 'proxy' ? 0.70 : 0.90,
    hasRecentCaffeineSmokeOrExercise: false,
  );
  PersonalBaselineResult? baseline;
  if (heroValue != null) {
    final hist = history
        .where(
          (h) =>
              h.protocol.id == protocol.id &&
              h.heroValue != null &&
              at.difference(h.recordedAt).inDays <= 180,
        )
        .map((h) => h.heroValue!)
        .toList()
        .reversed
        .toList();
    baseline = RiskEngine.evaluateBaselineAndChange(
      historicalValidValuesWithin180Days: hist,
      currentValue: heroValue,
    );
  }

  // --- Headline copy ---------------------------------------------------------
  final (title, sub, means) = _copy(protocol, band, sides, heroLabel, subject);

  final seconds = captures.fold<double>(0, (acc, c) {
    if (c.motion.isNotEmpty) return acc + (c.motion.last.t - c.motion.first.t);
    if (c.tapSamples.isNotEmpty) {
      return acc + (c.tapSamples.last.t - c.tapSamples.first.t);
    }
    return acc + protocol.secondsPerSide;
  });

  return MovementSessionResult(
    sessionId: id,
    subjectId: subject.id,
    subjectName: subject.fullName,
    ageYears: subject.ageYears,
    sex: subject.sex,
    protocol: protocol,
    recordedAt: at,
    durationSeconds: seconds.round(),
    perSide: sides,
    overall: overall,
    markers: env,
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    urgency: risk.highestUrgency,
    firedRuleCodes: risk.firedRuleCodes,
    confidence: confidence,
    quality: quality,
    baseline: baseline,
    pd: pd,
    demoOutcome: demoOutcome,
    heroCode: heroCode,
    heroValue: heroValue,
    heroLabel: heroLabel,
    ageNormLabel: ageNormLabel,
  );
}

/// Spec §9 MOV-04: the only stated norm is ≥ 12 for age 60–64; other bands
/// are "pending" (Q-COHORT), so no band is assigned for them.
int? stsAgeNorm(int ageYears) => ageYears >= 60 && ageYears <= 64 ? 12 : null;

/// Spec §9 MOV-05 bands inside the 3–12 Hz analysis window: Parkinsonian
/// rest / re-emergent 4–6 Hz, essential postural 5–10 Hz (they overlap at
/// 5–6 Hz).
String tremorRangeLabel(double hz) {
  final pd = hz >= 4 && hz <= 6;
  final et = hz >= 5 && hz <= 10;
  if (pd && et) return 'Parkinsonian / essential overlap (5–6 Hz)';
  if (pd) return 'Parkinsonian range (4–6 Hz)';
  if (et) return 'essential tremor range (5–10 Hz)';
  return 'outside the typical bands';
}

bool _hasSpecNorm(String code, int age) => switch (code) {
  'TAP_DECREMENT' || 'GAIT_SPEED' || 'TREMOR_FREQ' || 'TREMOR_AMP' => true,
  'STS_COUNT_30S' => stsAgeNorm(age) != null,
  _ => false,
};

String _primaryCode(MovementTestKind k) => switch (k) {
  MovementTestKind.tappingVideo => 'TAP_COUNT',
  MovementTestKind.tappingTouch => 'TOUCH_TAP_COUNT',
  MovementTestKind.gait => 'GAIT_SPEED',
  MovementTestKind.sitToStand => 'STS_COUNT_30S',
  MovementTestKind.tremor => 'TREMOR_FREQ',
};

double? _maxOf(List<MovementSideResult> sides, String code) {
  double? v;
  for (final s in sides) {
    final x = s.values[code];
    if (x != null && (v == null || x > v)) v = x;
  }
  return v;
}

double? _minOf(List<MovementSideResult> sides, String code) {
  double? v;
  for (final s in sides) {
    final x = s.values[code];
    if (x != null && (v == null || x < v)) v = x;
  }
  return v;
}

int _rank(SemanticBand b) => switch (b) {
  SemanticBand.refer || SemanticBand.high => 3,
  SemanticBand.borderline => 2,
  SemanticBand.normal || SemanticBand.low => 1,
  _ => 0,
};

SemanticBand _worse(Iterable<SemanticBand> bands) {
  SemanticBand best = SemanticBand.rangeNotAvailable;
  var bestRank = -1;
  for (final b in bands) {
    final r = _rank(b);
    if (r > bestRank) {
      bestRank = r;
      best = b;
    }
  }
  return best;
}

(String, String, String) _copy(
  MovementProtocol p,
  SemanticBand band,
  List<MovementSideResult> sides,
  String hero,
  SubjectProfile subject,
) {
  if (band == SemanticBand.notAssessed) {
    return (
      'Not assessed',
      'The test did not produce a usable recording',
      'No valid recording was captured, so no result was produced. Check the setup steps and try again.',
    );
  }
  final partial = p.twoSided && sides.any((s) => !s.assessed)
      ? ' One hand was not assessed, so the result rests on the other hand.'
      : '';
  switch (p.kind) {
    case MovementTestKind.tappingVideo:
      final dec = _maxOf(sides, 'TAP_DECREMENT');
      final decText = dec == null ? '' : '${dec.toStringAsFixed(0)} %';
      return switch (band) {
        SemanticBand.refer => (
          'Refer',
          'Your taps shrank by $decText',
          'Your taps became clearly smaller over the 10 seconds (20 % or more). That pattern, called decrement, is one of the signs a neurologist looks for in Parkinson\'s. It is a screening signal, not a diagnosis.$partial',
        ),
        _ => (
          'Normal',
          'Your taps stayed the same size',
          'Your tap size held up across the 10 seconds (decrement $decText, under the 20 % line). Tap count, speed and rhythm are recorded for your personal baseline until age norms are available.$partial',
        ),
      };
    case MovementTestKind.tappingTouch:
      return (
        'Recorded',
        '$hero recorded for your baseline',
        'Alternating-tap speed and rhythm are recorded for your personal baseline. Age norms are not yet available, so no band is assigned; a drop against your own earlier tests is what matters.$partial',
      );
    case MovementTestKind.gait:
      return switch (band) {
        SemanticBand.refer => (
          'Refer',
          'You walked at $hero — below the 0.8 m/s line',
          'A usual walking speed under 0.8 m/s is linked with a higher risk of falls in older adults. A physiotherapist or falls clinic can check gait, balance, vision, footwear and medicines.',
        ),
        _ => (
          'Normal',
          'You walked at $hero — above the 0.8 m/s line',
          'Your walking speed is at or above the 0.8 m/s screening line for older adults. Steps, cadence and step regularity are recorded for your baseline.',
        ),
      };
    case MovementTestKind.sitToStand:
      final norm = stsAgeNorm(subject.ageYears);
      return switch (band) {
        SemanticBand.refer => (
          'Below age norm',
          '$hero — below the norm of $norm for age ${subject.ageYears}',
          'Fewer stands than the norm for your age points to weaker legs and a higher fall risk. Leg-strengthening exercise helps; a physiotherapist can advise.',
        ),
        SemanticBand.rangeNotAvailable => (
          'Recorded',
          '$hero — the norm for age ${subject.ageYears} is still pending',
          'The document gives a norm only for ages 60–64, so your count is recorded without a band. The CDC reference table below is shown for context only.',
        ),
        _ => (
          'Normal',
          '$hero — at or above the norm of $norm for age ${subject.ageYears}',
          'You reached the norm for your age. Leg strength looks adequate for daily tasks.',
        ),
      };
    case MovementTestKind.tremor:
      final worst = sides
          .where((s) => s.assessed)
          .fold<MovementSideResult?>(
            null,
            (a, b) => a == null || _rank(b.band) > _rank(a.band) ? b : a,
          );
      final f = worst?.values['TREMOR_FREQ'];
      final hand = worst?.side == null
          ? ''
          : ' in the ${worst!.side!.label.toLowerCase()} hand';
      return switch (band) {
        SemanticBand.refer => (
          'Refer',
          'A steady ${f?.toStringAsFixed(1) ?? ''} Hz shake$hand',
          'A shaking rhythm rose above the phone\'s sensor noise while your arm was held out (${f == null ? 'peak found' : tremorRangeLabel(f)}). Frequency alone cannot tell Parkinson\'s from essential tremor; a neurologist can examine you. It is a screening signal, not a diagnosis.$partial',
        ),
        _ => (
          'Normal',
          'No tremor peak found',
          'No shaking rhythm rose above the phone\'s own sensor noise while your arm was held out.$partial',
        ),
      };
  }
}
