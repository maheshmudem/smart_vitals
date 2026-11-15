// Turns raw vision-test captures into a [VisionSessionResult]
// (Doc 09 §9 ALG-MOV-10..12 + CAP-15, §10 RSK-02/03/04/06).
import '../entities/enums.dart';
import '../entities/marker_envelope.dart';
import '../entities/member_profile.dart';
import '../entities/vision_protocol.dart';
import '../entities/vision_result.dart';
import 'marker_readings.dart';
import 'risk_engine.dart';
import 'vision_engines.dart';

/// Raw capture for one eye (acuity / Amsler), one block (reaction) or the
/// whole plate set (colour).
class VisionPartCapture {
  const VisionPartCapture({
    this.eye,
    this.block,
    this.skipped = false,
    this.skipReason,
    this.acuityTrials = const [],
    this.thresholdLogMar,
    this.plateSet,
    this.plateAnswers = const [],
    this.amsler,
    this.reactionTrials = const [],
  });

  final VisionEye? eye;
  final ReactionBlock? block;
  final bool skipped;
  final String? skipReason;
  final List<AcuityTrial> acuityTrials;
  final double? thresholdLogMar;
  final ColourPlateSet? plateSet;
  final List<ColourPlateAnswer> plateAnswers;
  final AmslerMarks? amsler;
  final List<ReactionTrial> reactionTrials;
}

typedef VisionHistory = List<VisionSessionResult>;

VisionSessionResult buildVisionSession({
  required VisionProtocol protocol,
  required SubjectProfile subject,
  required List<VisionPartCapture> captures,
  required VisionDemoOutcome demoOutcome,
  VisionHistory history = const [],
  String distanceMode = 'manual',
  double? meanDistanceCm,
  String dpiSource = 'estimated',
  double? dpi,
  String brightnessMode = 'manual',
  int retakes = 0,
  bool simulated = true,
  int durationSeconds = 0,
  String? sessionId,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final id = sessionId ?? 'vis_${at.millisecondsSinceEpoch}';
  final parts = <VisionPartResult>[];
  final env = <String, MarkerEnvelope<dynamic>>{};
  final overall = <String, double>{};
  var trialsTotal = 0;
  var falseStarts = 0;
  var controlFailed = false;
  double? plateMedianMs;
  double? inRangePct;
  double? meanDist = meanDistanceCm;

  for (final c in captures) {
    if (c.skipped) {
      parts.add(
        VisionPartResult(
          label: c.eye?.label ?? c.block?.label ?? 'Test',
          assessed: false,
          skipped: true,
          eye: c.eye,
          block: c.block,
          note: c.skipReason ?? 'Skipped by you — not assessed',
        ),
      );
      continue;
    }
    switch (protocol.kind) {
      case VisionTestKind.acuity:
        final t = c.thresholdLogMar;
        trialsTotal += c.acuityTrials.length;
        if (c.acuityTrials.isNotEmpty) {
          final inRange = c.acuityTrials.where((x) => x.distanceInRange).length;
          final pct = inRange / c.acuityTrials.length * 100;
          inRangePct = inRangePct == null ? pct : (inRangePct + pct) / 2;
          final md =
              c.acuityTrials.map((x) => x.distanceCm).reduce((a, b) => a + b) /
              c.acuityTrials.length;
          meanDist = meanDist == null ? md : (meanDist + md) / 2;
        }
        if (t == null) {
          parts.add(
            VisionPartResult(
              label: '${c.eye!.label} eye',
              eye: c.eye,
              assessed: false,
              note: 'No threshold reached',
              trials: c.acuityTrials,
            ),
          );
          continue;
        }
        final band = t <= Optotype.normalMaxLogMar + 1e-9
            ? SemanticBand.normal
            : t <= 0.5 + 1e-9
            ? SemanticBand.borderline
            : SemanticBand.refer;
        parts.add(
          VisionPartResult(
            label: '${c.eye!.label} eye',
            eye: c.eye,
            assessed: true,
            band: band,
            values: {'LOGMAR': t},
            note:
                '${t.toStringAsFixed(1)} logMAR · ≈ ${Optotype.snellen(t)} · ${c.acuityTrials.length} letters',
            trials: c.acuityTrials,
          ),
        );
      case VisionTestKind.colour:
        final set = c.plateSet ?? ColourPlateSet.generate();
        final r = ColourPlateScorer.score(set, c.plateAnswers);
        trialsTotal += r.answered;
        controlFailed = r.controlFailed;
        plateMedianMs = r.medianResponseMs;
        overall['COLOUR_PLATE_SCORE'] = r.score.toDouble();
        final plateValues = {
          'COLOUR_PLATE_SCORE': r.score.toDouble(),
          'SCREENING_CORRECT': r.screeningCorrect.toDouble(),
          'SCREENING_TOTAL': r.screeningTotal.toDouble(),
          'SCREENING_MISSES': r.screeningMisses.toDouble(),
          'CONTROL_CORRECT': r.controlCorrect.toDouble(),
          'CONTROL_TOTAL': r.controlTotal.toDouble(),
          if (r.medianResponseMs != null)
            'MEDIAN_RESPONSE_MS': r.medianResponseMs!,
        };
        if (r.controlFailed) {
          parts.add(
            VisionPartResult(
              label: 'Colour plates',
              assessed: false,
              values: plateValues,
              note:
                  'Control plate misread (${r.controlCorrect} of ${r.controlTotal} read) — screen too dim, a colour filter on, or not attended. Retake.',
              plateReview: r.review,
            ),
          );
          continue;
        }
        final band = r.allCorrect
            ? SemanticBand.normal
            : r.likelyRedGreen
            ? SemanticBand.refer
            : SemanticBand.borderline;
        parts.add(
          VisionPartResult(
            label: 'Colour plates',
            assessed: true,
            band: band,
            values: plateValues,
            note:
                '${r.score} of ${r.total} correct · screening ${r.screeningCorrect} of ${r.screeningTotal} · control ${r.controlCorrect} of ${r.controlTotal}',
            plateReview: r.review,
          ),
        );
      case VisionTestKind.amsler:
        final m = c.amsler ?? AmslerMarks();
        final abnormal = m.abnormal;
        parts.add(
          VisionPartResult(
            label: '${c.eye!.label} eye',
            eye: c.eye,
            assessed: true,
            band: abnormal ? SemanticBand.refer : SemanticBand.normal,
            flags: {'AMSLER_ABNORMAL': abnormal},
            values: {'AMSLER_MARKED_PCT': m.markedSharePct},
            note: abnormal
                ? 'Distortion marked: ${m.quadrants.join(', ')}${m.centralInvolved ? ' · includes the centre' : ''}'
                : m.declaredNormal
                ? 'Looks normal — nothing marked'
                : 'Nothing marked',
            amsler: m,
          ),
        );
      case VisionTestKind.reaction:
        final r = ReactionTimeAnalyzer.analyzeBlock(c.reactionTrials, c.block!);
        trialsTotal += c.reactionTrials.length;
        falseStarts += r.discarded;
        final code = c.block == ReactionBlock.visual
            ? 'RT_VISUAL_MS'
            : 'RT_AUDIO_MS';
        if (r.medianMs == null) {
          parts.add(
            VisionPartResult(
              label: '${c.block!.label} block',
              block: c.block,
              assessed: false,
              note: 'No valid trials',
            ),
          );
          continue;
        }
        overall[code] = r.medianMs!;
        parts.add(
          VisionPartResult(
            label: '${c.block!.label} block',
            block: c.block,
            assessed: true,
            band: SemanticBand.rangeNotAvailable,
            values: {code: r.medianMs!},
            note:
                'median ${r.medianMs!.toStringAsFixed(0)} ms · ${r.validCount} valid${r.discarded > 0 ? ' · ${r.discarded} false start${r.discarded == 1 ? '' : 's'} replaced' : ''}',
          ),
        );
    }
  }

  // --- Overall band and hero ------------------------------------------------
  final assessed = parts.where((p) => p.assessed).toList();
  var band = assessed.isEmpty
      ? SemanticBand.notAssessed
      : _worse(assessed.map((p) => p.band));

  String heroCode;
  double? heroValue;
  String heroLabel;
  switch (protocol.kind) {
    case VisionTestKind.acuity:
      final worst = _maxOf(assessed, 'LOGMAR');
      heroCode = 'LOGMAR';
      heroValue = worst;
      heroLabel = worst == null
          ? 'Not assessed'
          : '${worst.toStringAsFixed(1)} logMAR (worse eye)';
    case VisionTestKind.colour:
      heroCode = 'COLOUR_PLATE_SCORE';
      heroValue = overall['COLOUR_PLATE_SCORE'];
      heroLabel = heroValue == null
          ? 'Not assessed'
          : '${heroValue.toStringAsFixed(0)} of ${ColourPlateSet.count} plates';
    case VisionTestKind.amsler:
      heroCode = 'AMSLER_ABNORMAL';
      final any = assessed.any((p) => p.flags['AMSLER_ABNORMAL'] == true);
      heroValue = assessed.isEmpty ? null : (any ? 1 : 0);
      heroLabel = assessed.isEmpty
          ? 'Not assessed'
          : any
          ? 'Distortion marked'
          : 'No distortion';
    case VisionTestKind.reaction:
      heroCode = 'RT_VISUAL_MS';
      heroValue = overall['RT_VISUAL_MS'];
      final a = overall['RT_AUDIO_MS'];
      heroLabel = heroValue == null && a == null
          ? 'Not assessed'
          : 'visual ${heroValue?.toStringAsFixed(0) ?? '—'} ms · sound ${a?.toStringAsFixed(0) ?? '—'} ms';
  }

  // --- Marker envelopes -----------------------------------------------------
  for (final p in parts) {
    final suffix = p.eye == null ? '' : '_${p.eye!.suffix}';
    if (!p.assessed) {
      final code = switch (protocol.kind) {
        VisionTestKind.acuity => 'LOGMAR$suffix',
        VisionTestKind.colour => 'COLOUR_PLATE_SCORE',
        VisionTestKind.amsler => 'AMSLER_ABNORMAL$suffix',
        VisionTestKind.reaction =>
          p.block == ReactionBlock.visual ? 'RT_VISUAL_MS' : 'RT_AUDIO_MS',
      };
      env[code] = MarkerReadings.synth(
        code,
        value: null,
        algorithmId: protocol.algorithmId,
        band: p.skipped ? SemanticBand.notAssessed : SemanticBand.notAssessed,
        status: p.skipped
            ? MarkerDisplayStatus.notAssessed
            : MarkerDisplayStatus.qualityRetakeRequired,
        reason: p.note,
        version: protocol.algorithmVersion,
      );
      continue;
    }
    for (final e in p.values.entries) {
      if (e.key == 'SCREENING_MISSES' || e.key == 'AMSLER_MARKED_PCT') continue;
      final code = '${e.key}$suffix';
      final hasNorm = protocol.kind != VisionTestKind.reaction;
      env[code] = MarkerReadings.synth(
        code,
        value: e.value,
        algorithmId: protocol.algorithmId,
        band: hasNorm ? p.band : SemanticBand.rangeNotAvailable,
        status: hasNorm
            ? MarkerDisplayStatus.ok
            : MarkerDisplayStatus.rangeNotAvailable,
        reason: hasNorm ? null : 'Age norms pending (Q-COHORT)',
        version: protocol.algorithmVersion,
        confidence: 0.9,
      );
    }
    for (final f in p.flags.entries) {
      final code = '${f.key}$suffix';
      env[code] = MarkerReadings.synth(
        code,
        value: f.value,
        algorithmId: protocol.algorithmId,
        band: p.band,
        version: protocol.algorithmVersion,
        confidence: 0.9,
      );
    }
  }
  if (protocol.kind == VisionTestKind.acuity && meanDist != null) {
    env['face_distance_cm'] = MarkerReadings.synth(
      'face_distance_cm',
      value: meanDist,
      algorithmId: 'ALG-CAP-15',
      band: FaceDistance.inRange(meanDist)
          ? SemanticBand.normal
          : SemanticBand.borderline,
      reason: distanceMode == 'manual'
          ? 'Not measured — manual 40 cm prompt (G-16 fallback)'
          : distanceMode == 'estimated'
          ? 'Camera estimate from eye spacing, uncalibrated focal length [DER]'
          : null,
      status: distanceMode == 'manual'
          ? MarkerDisplayStatus.notAvailable
          : MarkerDisplayStatus.ok,
      version: 'v0.9.0',
    );
  }

  // --- Risk rules (T32–T34 [DER]) -------------------------------------------
  final misses = assessed
      .map((p) => p.values['SCREENING_MISSES'] ?? 0)
      .fold<double>(0, (a, b) => a + b)
      .round();
  final risk = RiskEngine.evaluateUrgency(
    RiskEvaluationInput(
      logMarWorse: protocol.kind == VisionTestKind.acuity ? heroValue : null,
      amslerAbnormal: protocol.kind == VisionTestKind.amsler
          ? assessed.any((p) => p.flags['AMSLER_ABNORMAL'] == true)
          : null,
      colourPlateMisses: protocol.kind == VisionTestKind.colour ? misses : null,
    ),
    sessionId: id,
    timestamp: at,
  );
  if (risk.highestUrgency != UrgencyLevel.none && band == SemanticBand.normal) {
    band = SemanticBand.refer;
  }

  // --- Quality, confidence, baseline ----------------------------------------
  final quality = VisionQualityFacts(
    distanceMode: protocol.kind == VisionTestKind.acuity ? distanceMode : 'n/a',
    meanDistanceCm: protocol.kind == VisionTestKind.acuity ? meanDist : null,
    distanceInRangePct: inRangePct,
    dpiSource: dpiSource,
    dpi: dpi,
    brightnessMode: brightnessMode,
    trials: trialsTotal,
    falseStarts: falseStarts,
    controlPlateFailed: controlFailed,
    medianResponseMs: plateMedianMs,
    retakes: retakes,
    simulated: simulated,
  );
  final confidence = RiskEngine.computeResultConfidence(
    captureQualityScore: quality.captureQualityScore,
    modelConfidence: 0.90,
    hasRecentCaffeineSmokeOrExercise: false,
  );
  PersonalBaselineResult? baseline;
  if (heroValue != null && protocol.kind != VisionTestKind.amsler) {
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

  final (title, sub, means) = _copy(protocol, band, parts, overall, heroValue);

  return VisionSessionResult(
    sessionId: id,
    subjectId: subject.id,
    subjectName: subject.fullName,
    ageYears: subject.ageYears,
    sex: subject.sex,
    protocol: protocol,
    recordedAt: at,
    durationSeconds: durationSeconds,
    parts: parts,
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
    demoOutcome: demoOutcome,
    heroCode: heroCode,
    heroValue: heroValue,
    heroLabel: heroLabel,
  );
}

double? _maxOf(List<VisionPartResult> parts, String code) {
  double? v;
  for (final p in parts) {
    final x = p.values[code];
    if (x != null && (v == null || x > v)) v = x;
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
  VisionProtocol p,
  SemanticBand band,
  List<VisionPartResult> parts,
  Map<String, double> overall,
  double? hero,
) {
  if (band == SemanticBand.notAssessed) {
    return (
      'Not assessed',
      'The test did not produce a usable result',
      p.kind == VisionTestKind.colour
          ? 'One of the two easy control plates was misread, which means the screen or the lighting was not right. Turn colour filters off, set brightness to full and try again.'
          : 'No valid result was captured. Check the setup steps and try again.',
    );
  }
  final partial = parts.length > 1 && parts.any((x) => !x.assessed)
      ? ' One side was not assessed, so the result rests on the other.'
      : '';
  String eyeWord(VisionEye e) => e.label.toLowerCase();
  switch (p.kind) {
    case VisionTestKind.acuity:
      final r = parts.where((x) => x.eye == VisionEye.right && x.assessed);
      final l = parts.where((x) => x.eye == VisionEye.left && x.assessed);
      final rv = r.isEmpty ? null : r.first.values['LOGMAR'];
      final lv = l.isEmpty ? null : l.first.values['LOGMAR'];
      String fmt(double? v) => v == null ? '—' : v.toStringAsFixed(1);
      final worseEye = (rv ?? -1) >= (lv ?? -1)
          ? VisionEye.right
          : VisionEye.left;
      final both = 'Right ${fmt(rv)} · left ${fmt(lv)} logMAR';
      return switch (band) {
        SemanticBand.refer => (
          'Refer',
          '${worseEye.label} eye ${fmt(hero)} logMAR — well below the 0.2 line',
          '$both. Your ${eyeWord(worseEye)} eye could only read large letters at 40 cm (about ${Optotype.snellen(hero ?? 1)}). Glasses, cataract or another eye condition can cause this; an optometrist or eye clinic can examine you.$partial',
        ),
        SemanticBand.borderline => (
          'Borderline',
          '${worseEye.label} eye ${fmt(hero)} logMAR — just below the 0.2 line',
          '$both. Reading at 40 cm was a little below the normal line in the ${eyeWord(worseEye)} eye. Repeat when rested, with your usual glasses; if it stays, an optometrist check is sensible.$partial',
        ),
        _ => (
          'Normal',
          'Both eyes read the small letters',
          '$both. Both eyes are at or better than the 0.2 logMAR line (about 6/9.5) at 40 cm.$partial',
        ),
      };
    case VisionTestKind.colour:
      final score = overall['COLOUR_PLATE_SCORE']?.toStringAsFixed(0) ?? '—';
      return switch (band) {
        SemanticBand.refer => (
          'Refer',
          '$score of 12 plates read — red–green plates missed',
          'Several plates whose colours look alike to people with red–green colour deficiency were not read. This is common (about 1 in 12 men) and usually lifelong; an optometrist can confirm it with printed plates.',
        ),
        SemanticBand.borderline => (
          'Repeat',
          '$score of 12 plates read',
          'One or two plates were missed. That can happen with glare, a dim screen or a quick glance. Repeat in good light before drawing a conclusion.',
        ),
        _ => (
          'Normal',
          'All 12 plates read correctly',
          'Every plate was read, including the red–green screening plates. No sign of a colour deficiency on this screen.',
        ),
      };
    case VisionTestKind.amsler:
      final marked = parts
          .where((x) => x.assessed && x.flags['AMSLER_ABNORMAL'] == true)
          .map((x) => eyeWord(x.eye!))
          .toList();
      return switch (band) {
        SemanticBand.refer => (
          'Refer',
          'Distortion marked in the ${marked.join(' and ')} eye',
          'You marked lines as wavy, blurred or missing while looking at the dot. New distortion can be a sign of a change at the macula (the centre of the retina), which an eye clinic can check with a dilated exam or an OCT scan. Sooner is better.$partial',
        ),
        _ => (
          'Normal',
          'No distortion marked',
          'All lines looked straight and complete in both eyes while you stared at the dot.$partial',
        ),
      };
    case VisionTestKind.reaction:
      final v = overall['RT_VISUAL_MS']?.toStringAsFixed(0) ?? '—';
      final a = overall['RT_AUDIO_MS']?.toStringAsFixed(0) ?? '—';
      return (
        'Recorded',
        'Flash $v ms · beep $a ms',
        'Your typical delay was $v ms to the flash and $a ms to the beep. Age norms are not yet available, so no band is assigned; the numbers are kept for your personal baseline.$partial',
      );
  }
}
