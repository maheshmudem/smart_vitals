import '../entities/anaemia_result.dart' show EyeSide;
import '../entities/enums.dart';
import '../entities/eye_photo_protocol.dart';
import '../entities/eye_photo_session.dart';
import '../entities/marker_catalogue.dart';
import '../entities/marker_envelope.dart';
import '../entities/member_profile.dart';
import 'caries_risk_engine.dart';
import 'neonatal_bilirubin_chart.dart';
import 'risk_engine.dart';

/// Builds an [EyeSessionResult] for one of the four eye protocols.
///
/// Photo quality is real; the model outputs are **static demo values**
/// chosen by [demoOutcome] (no trained ALG-IMG-02/03/06 model and no partner
/// SDK are shipped yet). Everything that depends on the Spec — bands, risk
/// rules, IMG-10 routing, marker visibility — runs on those values exactly
/// as it would on real ones, so the result screen is faithful.
EyeSessionResult buildEyeSession({
  required EyeProtocol protocol,
  required SubjectProfile subject,
  required EyeAnswers answers,
  required List<EyePhoto> photos,
  EyeDemoOutcome demoOutcome = EyeDemoOutcome.normal,
  int durationSeconds = 40,
  DentalExamResult? previousDental,
}) {
  final now = DateTime.now();
  final sessionId = '${protocol.id}_${now.millisecondsSinceEpoch}';
  final accepted = photos.where((p) => p.accepted).toList();

  bool eyeAssessed(EyeSide eye) {
    if (answers.operatedEyes.contains(eye)) return false;
    if (protocol.bothEyesInOneFrame) return accepted.isNotEmpty;
    return accepted.any((p) => p.view.eye == eye);
  }

  // --- Capture quality + confidence (ALG-RSK-06) ---------------------------
  final captureQuality = accepted.isEmpty
      ? 0.0
      : accepted.map((p) => p.quality.qualityScore).reduce((a, b) => a + b) /
            accepted.length;
  final confidence = accepted.isEmpty
      ? 0.0
      : RiskEngine.computeResultConfidence(
          captureQualityScore: captureQuality,
          modelConfidence: protocol.modelConfidence,
          hasRecentCaffeineSmokeOrExercise: false,
        );
  final retakeTotal = photos.fold<int>(0, (s, p) => s + (p.attempts - 1));

  final _Outcome o = switch (protocol.id) {
    'eye_jaundice' => _jaundice(
      protocol,
      answers,
      accepted,
      demoOutcome,
      eyeAssessed,
    ),
    'eye_cataract' => _cataract(protocol, answers, demoOutcome, eyeAssessed),
    'eye_child' => _childEye(protocol, answers, demoOutcome, eyeAssessed),
    'body_newborn' => _newborn(
      protocol,
      answers,
      accepted,
      demoOutcome,
      subject,
    ),
    'body_foot' => _foot(protocol, answers, accepted, demoOutcome, eyeAssessed),
    'body_skin' => _skin(protocol, answers, accepted, demoOutcome),
    'dental_oral' => _oral(protocol, answers, accepted, demoOutcome),
    'dental_caries' => _dental(
      protocol,
      answers,
      accepted,
      demoOutcome,
      subject,
      previousDental,
      sessionId,
      now,
    ),
    _ => _fundus(protocol, answers, demoOutcome, eyeAssessed),
  };

  // --- Risk rules (ALG-RSK-02) ---------------------------------------------
  final risk = RiskEngine.evaluateUrgency(
    o.riskInput,
    sessionId: sessionId,
    timestamp: now,
  );

  // --- Marker envelopes -----------------------------------------------------
  MarkerEnvelope<dynamic> env(EyeFinding f, MarkerDisplayStatus status) {
    final spec = MarkerCatalogue.byCode(f.code);
    return MarkerEnvelope<dynamic>(
      code: f.code,
      displayName: f.label,
      algorithmId: spec?.algorithmId ?? protocol.algorithmId,
      algorithmVersion: protocol.algorithmVersion,
      rangeVersion: protocol.rangeVersion,
      unit: spec?.unit ?? (f.gaugeValue == null ? 'band' : 'index'),
      decimals: spec?.decimals ?? 2,
      value: f.specValue ?? f.gaugeValue,
      formattedOverride: f.valueText,
      band: f.band,
      confidence: confidence,
      displayStatus: status,
      statusReason: status == MarkerDisplayStatus.internalOnly
          ? 'Not member-facing (R-9)'
          : status == MarkerDisplayStatus.notAssessed
          ? 'Not assessed — no usable photo after 3 attempts'
          : null,
      conditionsInformed: protocol.allConditionCodes,
      isEstimate: !f.memberFacing,
    );
  }

  final markers = <String, MarkerEnvelope<dynamic>>{};
  for (final f in o.findings) {
    final MarkerDisplayStatus status;
    final spec = MarkerCatalogue.byCode(f.code);
    // The spec's display rule decides member-facing; the builder's R-9 flag
    // only applies to markers the catalogue does not know.
    final memberFacing = spec?.memberFacing ?? f.memberFacing;
    if (!memberFacing) {
      status = MarkerDisplayStatus.internalOnly;
    } else if (o.band == SemanticBand.notAssessed) {
      status = MarkerDisplayStatus.notAssessed;
    } else if (protocol.partnerModel) {
      status = MarkerDisplayStatus.ok;
    } else if (o.specialist) {
      status = MarkerDisplayStatus.underSpecialistReview;
    } else {
      status = MarkerDisplayStatus.bandOnly;
    }
    markers[f.code] = env(f, status);
  }

  return EyeSessionResult(
    protocol: protocol,
    sessionId: sessionId,
    subjectId: subject.id,
    subjectName: subject.fullName,
    ageYears: subject.ageYears,
    sex: subject.sex,
    recordedAt: now,
    answers: answers,
    photos: photos,
    findings: o.findings,
    perEyeBand: o.perEyeBand,
    perEyeGauge: o.perEyeGauge,
    perEyeNote: o.perEyeNote,
    band: o.band,
    bandTitle: o.bandTitle,
    bandSubline: o.bandSubline,
    whatItMeans: o.whatItMeans,
    urgency: risk.highestUrgency,
    firedRuleCodes: risk.firedRuleCodes,
    specialistReviewRequired: o.specialist,
    specialistReviewStatus: o.specialist
        ? 'Sent for specialist review'
        : 'Not required',
    confidence: confidence,
    captureQualityScore: captureQuality,
    modelConfidence: protocol.modelConfidence,
    probability: o.probability,
    decisionThreshold: 0.50,
    markers: markers,
    retakeTotal: retakeTotal,
    durationSeconds: durationSeconds,
    demoOutcome: demoOutcome,
    perZone: o.perZone,
    extraCards: o.extraCards,
    highlightBandOverride: o.highlightBand,
    ageLabelOverride: subject.isNewborn
        ? '${answers.newbornAgeHours ?? subject.ageHoursForNewborn ?? 0} h · ${answers.gestationWeeks ?? subject.gestationWeeksForNewborn ?? 0} w'
        : null,
  );
}

class _Outcome {
  const _Outcome({
    required this.findings,
    required this.perEyeBand,
    required this.perEyeGauge,
    required this.perEyeNote,
    required this.band,
    required this.bandTitle,
    required this.bandSubline,
    required this.whatItMeans,
    required this.riskInput,
    required this.specialist,
    this.probability,
    this.perZone = const {},
    this.extraCards = const [],
    this.highlightBand,
  });

  final List<EyeFinding> findings;
  final Map<EyeSide, SemanticBand> perEyeBand;
  final Map<EyeSide, double?> perEyeGauge;
  final Map<EyeSide, String> perEyeNote;
  final SemanticBand band;
  final String bandTitle;
  final String bandSubline;
  final String whatItMeans;
  final RiskEvaluationInput riskInput;
  final bool specialist;
  final double? probability;
  final Map<String, EyeZoneResult> perZone;
  final List<EyeExtraCard> extraCards;
  final SemanticBand? highlightBand;
}

SemanticBand _bandFromIndex(double v) => v >= 0.60
    ? SemanticBand.high
    : v >= 0.40
    ? SemanticBand.borderline
    : SemanticBand.normal;

SemanticBand _worse(Iterable<SemanticBand> bands) {
  const order = [
    SemanticBand.notAssessed,
    SemanticBand.normal,
    SemanticBand.low,
    SemanticBand.mild,
    SemanticBand.borderline,
    SemanticBand.moderate,
    SemanticBand.atRisk,
    SemanticBand.high,
    SemanticBand.refer,
    SemanticBand.ulcer,
    SemanticBand.suspicious,
  ];
  var best = SemanticBand.notAssessed;
  for (final b in bands) {
    if (order.indexOf(b) > order.indexOf(best)) best = b;
  }
  return best;
}

String _r2(double v) => v.toStringAsFixed(2);

// ---------------------------------------------------------------------------
// 1. Adult jaundice — ALG-IMG-02
// ---------------------------------------------------------------------------
_Outcome _jaundice(
  EyeProtocol p,
  EyeAnswers a,
  List<EyePhoto> accepted,
  EyeDemoOutcome outcome,
  bool Function(EyeSide) assessed,
) {
  final base = switch (outcome) {
    EyeDemoOutcome.normal => 0.14,
    EyeDemoOutcome.borderline => 0.47,
    EyeDemoOutcome.high => 0.82,
    EyeDemoOutcome.urgent => 0.91,
  };
  final perEyeBand = <EyeSide, SemanticBand>{};
  final perEyeGauge = <EyeSide, double?>{};
  final perEyeNote = <EyeSide, String>{};
  final findings = <EyeFinding>[];
  for (final eye in EyeSide.values) {
    if (!assessed(eye)) {
      perEyeBand[eye] = SemanticBand.notAssessed;
      perEyeGauge[eye] = null;
      perEyeNote[eye] = 'Not assessed — photos failed the quality checks';
      continue;
    }
    final idx = (base + (eye == EyeSide.left ? -0.03 : 0.02)).clamp(0.0, 1.0);
    final photosOf = accepted.where((x) => x.view.eye == eye).toList();
    final bStar =
        6.0 + idx * 22.0; // demo CIELab b*; real value from the photos later
    perEyeBand[eye] = _bandFromIndex(idx);
    perEyeGauge[eye] = idx;
    perEyeNote[eye] =
        '${photosOf.length} photo${photosOf.length == 1 ? '' : 's'} · yellowness ${_r2(idx)}';
    findings.add(
      EyeFinding(
        code: 'SCLERA_${eye == EyeSide.left ? 'L' : 'R'}',
        label: '${eye.label} white of the eye',
        valueText: idx >= 0.60
            ? 'Clearly yellow'
            : idx >= 0.40
            ? 'Slight yellow tint'
            : 'White',
        band: perEyeBand[eye]!,
        gaugeValue: idx,
        eye: eye,
      ),
    );
    findings.add(
      EyeFinding(
        code: 'SCLERA_BSTAR_${eye == EyeSide.left ? 'L' : 'R'}',
        label: '${eye.label} sclera b*',
        valueText: '${bStar.toStringAsFixed(1)} (CIELab b*)',
        band: perEyeBand[eye]!,
        gaugeValue: bStar,
        eye: eye,
      ),
    );
  }
  final anyAssessed = perEyeBand.values.any(
    (b) => b != SemanticBand.notAssessed,
  );
  final band = anyAssessed
      ? _worse(perEyeBand.values)
      : SemanticBand.notAssessed;
  final prob = anyAssessed ? base : null;
  final specialist =
      anyAssessed && (band == SemanticBand.high || (base - 0.50).abs() <= 0.10);
  final symptoms = a.anyEscalating(p);

  findings.insert(
    0,
    EyeFinding(
      code: 'JAUNDICE_BAND',
      label: 'Jaundice screen',
      valueText: band == SemanticBand.notAssessed ? 'Not assessed' : band.label,
      band: band,
      specValue: band == SemanticBand.high ? 'high' : 'normal',
    ),
  );
  findings.add(
    EyeFinding(
      code: 'JAUNDICE_PROB',
      label: 'Jaundice probability',
      valueText: prob == null ? '—' : '${_r2(prob)} (τ 0.50)',
      band: band,
      gaugeValue: prob,
    ),
  );

  final (title, sub, means) = switch (band) {
    SemanticBand.high => (
      'High band',
      'Sclera colour suggests bilirubin above 2.5 mg/dL',
      'The white of the eye looks yellow in ${_eyesText(perEyeBand, SemanticBand.high)}. '
          'This is the colour seen when bilirubin is above about 2.5 mg/dL and needs a serum bilirubin and liver test within 2 days.'
          '${symptoms ? ' You also reported symptoms (dark urine, pale stools, itching, belly pain or known liver disease) — treat this as urgent.' : ''}',
    ),
    SemanticBand.borderline => (
      'Borderline',
      'Slight tint close to the visible-jaundice threshold',
      'A slight yellow tint is close to the threshold. A serum bilirubin test will tell for sure; if you cannot test now, repeat the screen in white daylight in a few days.',
    ),
    SemanticBand.notAssessed => (
      'Not assessed',
      'No usable photos — not a health result',
      'No photo passed the quality and colour-card checks after 3 attempts, so no band was produced. Retake in white light with the card flat beside the eye.',
    ),
    _ => (
      'Normal band',
      'Sclera colour within the normal range',
      'The white of the eye is not yellow in either eye. No jaundice signal was found in this screen.',
    ),
  };

  return _Outcome(
    findings: findings,
    perEyeBand: perEyeBand,
    perEyeGauge: perEyeGauge,
    perEyeNote: perEyeNote,
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    riskInput: RiskEvaluationInput(
      jaundiceBand: band == SemanticBand.high ? SemanticBand.high : null,
    ),
    specialist: specialist,
    probability: prob,
  );
}

// ---------------------------------------------------------------------------
// 2. Cataract — ALG-IMG-03
// ---------------------------------------------------------------------------
_Outcome _cataract(
  EyeProtocol p,
  EyeAnswers a,
  EyeDemoOutcome outcome,
  bool Function(EyeSide) assessed,
) {
  final (pl, pr) = switch (outcome) {
    EyeDemoOutcome.normal => (0.08, 0.11),
    EyeDemoOutcome.borderline => (0.12, 0.46),
    EyeDemoOutcome.high => (0.14, 0.82),
    EyeDemoOutcome.urgent => (0.86, 0.79),
  };
  final perEyeBand = <EyeSide, SemanticBand>{};
  final perEyeGauge = <EyeSide, double?>{};
  final perEyeNote = <EyeSide, String>{};
  final findings = <EyeFinding>[];
  double? nearest;
  for (final eye in EyeSide.values) {
    final operated = a.operatedEyes.contains(eye);
    if (!assessed(eye)) {
      perEyeBand[eye] = SemanticBand.notAssessed;
      perEyeGauge[eye] = null;
      perEyeNote[eye] = operated
          ? 'Operated — artificial lens, not screened'
          : 'Not assessed — photo failed the quality checks';
      continue;
    }
    final prob = eye == EyeSide.left ? pl : pr;
    nearest = nearest == null || (prob - 0.5).abs() < (nearest - 0.5).abs()
        ? prob
        : nearest;
    perEyeBand[eye] = _bandFromIndex(prob);
    perEyeGauge[eye] = prob;
    perEyeNote[eye] = '1 photo · haze index ${_r2(prob)}';
    findings.add(
      EyeFinding(
        code: 'CATARACT_PROB_${eye == EyeSide.left ? 'L' : 'R'}',
        label: '${eye.label} cataract probability',
        valueText: '${_r2(prob)} (τ 0.50)',
        band: perEyeBand[eye]!,
        gaugeValue: prob,
        eye: eye,
      ),
    );
  }
  final anyAssessed = perEyeBand.values.any(
    (b) => b != SemanticBand.notAssessed,
  );
  final band = anyAssessed
      ? _worse(perEyeBand.values)
      : SemanticBand.notAssessed;
  final specialist =
      anyAssessed &&
      (band == SemanticBand.high ||
          (nearest != null && (nearest - 0.50).abs() <= 0.10));

  findings.insert(
    0,
    EyeFinding(
      code: 'CATARACT_BAND',
      label: 'Cataract screen',
      valueText: band == SemanticBand.notAssessed ? 'Not assessed' : band.label,
      band: band,
      specValue: band == SemanticBand.high ? 'high' : 'normal',
    ),
  );
  for (final eye in EyeSide.values) {
    findings.add(
      EyeFinding(
        code: 'CATARACT_BAND_${eye == EyeSide.left ? 'L' : 'R'}',
        label: '${eye.label} lens',
        valueText: perEyeBand[eye] == SemanticBand.notAssessed
            ? perEyeNote[eye]!
            : perEyeBand[eye]!.label,
        band: perEyeBand[eye]!,
        gaugeValue: perEyeGauge[eye],
        eye: eye,
      ),
    );
  }

  final (title, sub, means) = switch (band) {
    SemanticBand.high => (
      'High band',
      'Lens looks cloudy in ${_eyesText(perEyeBand, SemanticBand.high)}',
      'The lens behind the pupil looks cloudy in ${_eyesText(perEyeBand, SemanticBand.high)}. '
          'This is the pattern of a cataract. Book a visual acuity and slit-lamp exam within 90 days; surgery is only considered when vision is affected.'
          '${a.anyEscalating(p) ? ' Diabetes, steroid use or the symptoms you reported make a true cataract more likely.' : ''}',
    ),
    SemanticBand.borderline => (
      'Borderline',
      'Some haze close to the threshold',
      'Some haze was seen in ${_eyesText(perEyeBand, SemanticBand.borderline)}, close to the threshold. A routine slit-lamp exam will tell for sure.',
    ),
    SemanticBand.notAssessed => (
      'Not assessed',
      'No usable pupil photo — not a health result',
      'No photo showed the pupil clearly after 3 attempts (or both eyes have been operated), so no band was produced. Retake in a darker room.',
    ),
    _ => (
      'Normal band',
      'Lens looks clear in the screened eye(s)',
      'The lens looks clear in ${_eyesText(perEyeBand, SemanticBand.normal)}. No cataract signal was found in this screen.',
    ),
  };

  return _Outcome(
    findings: findings,
    perEyeBand: perEyeBand,
    perEyeGauge: perEyeGauge,
    perEyeNote: perEyeNote,
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    riskInput: RiskEvaluationInput(
      cataractBand: band == SemanticBand.high ? SemanticBand.high : null,
    ),
    specialist: specialist,
    probability: nearest,
  );
}

// ---------------------------------------------------------------------------
// 3. Child eye — ALG-IMG-06
// ---------------------------------------------------------------------------
_Outcome _childEye(
  EyeProtocol p,
  EyeAnswers a,
  EyeDemoOutcome outcome,
  bool Function(EyeSide) assessed,
) {
  final (asym, deg, white) = switch (outcome) {
    EyeDemoOutcome.normal => (0.08, 0.4, 0.03),
    EyeDemoOutcome.borderline => (0.30, 3.5, 0.06),
    EyeDemoOutcome.high => (0.46, 9.0, 0.08),
    EyeDemoOutcome.urgent => (0.22, 1.0, 0.93),
  };
  final whitePupil = white >= 0.50;
  final reflexBand = asym >= 0.40
      ? SemanticBand.refer
      : asym >= 0.25
      ? SemanticBand.borderline
      : SemanticBand.normal;
  final cornealBand = deg >= 7
      ? SemanticBand.refer
      : deg >= 3
      ? SemanticBand.borderline
      : SemanticBand.normal;
  final anyAssessed = assessed(EyeSide.left) || assessed(EyeSide.right);
  const affected = EyeSide.left; // demo: findings sit in the left eye

  final perEyeBand = <EyeSide, SemanticBand>{};
  final perEyeGauge = <EyeSide, double?>{};
  final perEyeNote = <EyeSide, String>{};
  for (final eye in EyeSide.values) {
    if (!anyAssessed) {
      perEyeBand[eye] = SemanticBand.notAssessed;
      perEyeGauge[eye] = null;
      perEyeNote[eye] = 'Not assessed — pupils not found';
      continue;
    }
    final isAffected = eye == affected;
    final gauge = isAffected ? (whitePupil ? 1.0 : asym) : 0.06;
    final SemanticBand b;
    if (isAffected && whitePupil) {
      b = SemanticBand.refer;
    } else if (isAffected && outcome == EyeDemoOutcome.high) {
      b = SemanticBand.refer;
    } else if (isAffected && outcome == EyeDemoOutcome.borderline) {
      b = SemanticBand.borderline;
    } else {
      b = SemanticBand.normal;
    }
    perEyeBand[eye] = b;
    perEyeGauge[eye] = gauge;
    perEyeNote[eye] = isAffected && whitePupil
        ? 'White pupil glow seen'
        : isAffected && outcome == EyeDemoOutcome.high
        ? 'Flash dot shifted · dimmer red reflex'
        : isAffected && outcome == EyeDemoOutcome.borderline
        ? 'Slightly dimmer red reflex'
        : 'Even red reflex · flash dot centred';
  }
  final band = !anyAssessed
      ? SemanticBand.notAssessed
      : whitePupil
      ? SemanticBand.refer
      : _worse(perEyeBand.values);
  final specialist =
      anyAssessed &&
      (band == SemanticBand.refer || (asym - 0.40).abs() <= 0.10);

  final findings = <EyeFinding>[
    EyeFinding(
      code: 'CHILD_EYE_BAND',
      label: 'Child eye screen',
      valueText: !anyAssessed
          ? 'Not assessed'
          : whitePupil
          ? 'White pupil — urgent'
          : band.label,
      band: band,
      specValue: whitePupil
          ? 'white_pupil_urgent'
          : band == SemanticBand.refer
          ? 'refer'
          : 'normal',
    ),
    EyeFinding(
      code: 'RED_REFLEX',
      label: 'Red reflex (both pupils)',
      valueText: !anyAssessed
          ? '—'
          : asym >= 0.40
          ? 'Uneven — ${affected.label.toLowerCase()} dimmer'
          : asym >= 0.25
          ? 'Slightly uneven'
          : 'Even in both eyes',
      band: anyAssessed ? reflexBand : band,
      gaugeValue: asym,
    ),
    EyeFinding(
      code: 'CORNEAL_REFLEX',
      label: 'Flash dot position (Hirschberg)',
      valueText: !anyAssessed
          ? '—'
          : deg >= 7
          ? 'Shifted in the ${affected.label.toLowerCase()} — possible squint'
          : deg >= 3
          ? 'Slightly off-centre'
          : 'Centred in both eyes',
      band: anyAssessed ? cornealBand : band,
    ),
    EyeFinding(
      code: 'WHITE_PUPIL',
      label: 'White pupil (leukocoria)',
      valueText: !anyAssessed
          ? '—'
          : whitePupil
          ? 'Seen in the ${affected.label.toLowerCase()} — urgent'
          : 'Not seen',
      band: whitePupil ? SemanticBand.refer : SemanticBand.normal,
    ),
    EyeFinding(
      code: 'REFLEX_ASYM',
      label: 'Reflex asymmetry',
      valueText: '${_r2(asym)} (0–1)',
      band: anyAssessed ? reflexBand : band,
      gaugeValue: asym,
    ),
    EyeFinding(
      code: 'HIRSCHBERG_DEG',
      label: 'Corneal reflex offset',
      valueText: '${deg.toStringAsFixed(1)}° (12–15°/mm)',
      band: anyAssessed ? cornealBand : band,
      gaugeValue: deg,
    ),
    EyeFinding(
      code: 'WHITE_PUPIL_PROB',
      label: 'White-pupil probability',
      valueText: '${_r2(white)} (τ 0.50)',
      band: whitePupil ? SemanticBand.refer : SemanticBand.normal,
      gaugeValue: white,
    ),
  ];

  final (title, sub, means) = !anyAssessed
      ? (
          'Not assessed',
          'Pupils not found — not a health result',
          'No photo showed both pupils clearly after 3 attempts. The room may have been too bright or the child was not looking at the light. Retake in a darker room.',
        )
      : whitePupil
      ? (
          'White pupil — urgent',
          'A white glow was seen in the ${affected.label.toLowerCase()} pupil',
          'Instead of the normal red glow, the ${affected.label.toLowerCase()} pupil reflected white. This can be a sign of a cataract, retinal disease or a tumour and always needs a children\'s eye doctor within days (rule T11).'
              '${a.anyEscalating(p) ? ' A parent has also noticed signs or there is a family history — mention this when booking.' : ''}',
        )
      : band == SemanticBand.refer
      ? (
          'Refer',
          'Flash dot shifted and red reflex uneven in the ${affected.label.toLowerCase()}',
          'The small flash reflection sits off-centre in the ${affected.label.toLowerCase()} and its red glow is dimmer. This pattern suggests a squint or unequal focus, which is treatable when found early. Book a paediatric eye exam within 30 days.',
        )
      : band == SemanticBand.borderline
      ? (
          'Borderline',
          'Small reflex difference close to the threshold',
          'The red glow differs slightly between the eyes, close to the threshold. A specialist will review the photos; a routine children\'s eye exam is sensible.',
        )
      : (
          'Normal',
          'Even red reflex, flash dots centred',
          'Both pupils glow evenly and the flash dots are centred in both eyes. No squint or white-pupil signal was found in this screen.',
        );

  return _Outcome(
    findings: findings,
    perEyeBand: perEyeBand,
    perEyeGauge: perEyeGauge,
    perEyeNote: perEyeNote,
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    riskInput: RiskEvaluationInput(
      childWhitePupil: anyAssessed && whitePupil,
      childEyeBand: anyAssessed && band == SemanticBand.refer && !whitePupil
          ? SemanticBand.refer
          : null,
    ),
    specialist: specialist,
    probability: anyAssessed ? (whitePupil ? white : asym) : null,
    highlightBand: anyAssessed && whitePupil ? SemanticBand.emergency : null,
  );
}

// ---------------------------------------------------------------------------
// 4. Fundus (DR & glaucoma, partner AI) — ALG-IMG-09
// ---------------------------------------------------------------------------
const _icdr = ['No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'PDR'];

_Outcome _fundus(
  EyeProtocol p,
  EyeAnswers a,
  EyeDemoOutcome outcome,
  bool Function(EyeSide) assessed,
) {
  // (grade L, grade R, DME R, CDR L, CDR R)
  final (gl, gr, dme, cdrL, cdrR) = switch (outcome) {
    EyeDemoOutcome.normal => (0, 0, false, 0.35, 0.38),
    EyeDemoOutcome.borderline => (1, 1, false, 0.40, 0.42),
    EyeDemoOutcome.high => (1, 2, false, 0.68, 0.45),
    EyeDemoOutcome.urgent => (3, 4, true, 0.41, 0.44),
  };
  final perEyeBand = <EyeSide, SemanticBand>{};
  final perEyeGauge = <EyeSide, double?>{};
  final perEyeNote = <EyeSide, String>{};
  final findings = <EyeFinding>[];
  var referable = false;
  var sight = false;
  var glaucoma = false;
  for (final eye in EyeSide.values) {
    if (!assessed(eye)) {
      perEyeBand[eye] = SemanticBand.notAssessed;
      perEyeGauge[eye] = null;
      perEyeNote[eye] = 'Not gradable — image too dark or blurred';
      continue;
    }
    final grade = eye == EyeSide.left ? gl : gr;
    final eyeDme = eye == EyeSide.right && dme;
    final cdr = eye == EyeSide.left ? cdrL : cdrR;
    final suspect = cdr >= 0.60;
    final eyeReferable = grade >= 2 || eyeDme;
    referable |= eyeReferable;
    sight |= grade >= 4 || eyeDme;
    glaucoma |= suspect;
    perEyeBand[eye] = eyeReferable || suspect
        ? SemanticBand.refer
        : grade == 1
        ? SemanticBand.mild
        : SemanticBand.normal;
    perEyeGauge[eye] = grade + (eyeDme ? 0.5 : 0);
    perEyeNote[eye] =
        '${_icdr[grade]} · ${eyeDme ? 'DME present' : 'no DME'} · cup/disc ${cdr.toStringAsFixed(2)}${suspect ? ' (suspect)' : ''}';
    final side = eye == EyeSide.left ? 'L' : 'R';
    findings.add(
      EyeFinding(
        code: 'DR_GRADE_$side',
        label: '${eye.label} retinopathy grade',
        valueText: '${_icdr[grade]}${eyeDme ? ' + DME' : ''}',
        band: perEyeBand[eye]!,
        gaugeValue: grade.toDouble(),
        eye: eye,
        specValue: eyeDme ? 'macular oedema' : _icdr[grade],
      ),
    );
    findings.add(
      EyeFinding(
        code: 'CDR_$side',
        label: '${eye.label} cup-to-disc ratio',
        valueText:
            '${cdr.toStringAsFixed(2)}${suspect ? ' — glaucoma suspect' : ' — within normal'}',
        band: suspect ? SemanticBand.refer : SemanticBand.normal,
        gaugeValue: cdr,
        eye: eye,
      ),
    );
  }
  final anyAssessed = perEyeBand.values.any(
    (b) => b != SemanticBand.notAssessed,
  );
  final band = !anyAssessed
      ? SemanticBand.notAssessed
      : (referable || glaucoma)
      ? SemanticBand.refer
      : (gl == 1 || gr == 1)
      ? SemanticBand.mild
      : SemanticBand.normal;

  findings.insert(
    0,
    EyeFinding(
      code: 'DR_REFERABLE',
      label: 'Referable diabetic retinopathy',
      valueText: !anyAssessed
          ? 'Not gradable'
          : referable
          ? 'Yes'
          : 'No',
      band: band,
      specValue: anyAssessed ? referable : null,
    ),
  );
  findings.add(
    EyeFinding(
      code: 'DME',
      label: 'Macular oedema',
      valueText: !anyAssessed
          ? '—'
          : dme
          ? 'Present (right eye)'
          : 'Not seen',
      band: dme ? SemanticBand.refer : SemanticBand.normal,
    ),
  );
  findings.add(
    EyeFinding(
      code: 'GLAUCOMA_SUSPECT',
      label: 'Glaucoma suspect',
      valueText: !anyAssessed
          ? '—'
          : glaucoma
          ? 'Yes (left eye cup/disc 0.68)'
          : 'No',
      band: glaucoma ? SemanticBand.refer : SemanticBand.normal,
      specValue: anyAssessed ? glaucoma : null,
    ),
  );

  final gradesLine =
      'Left: ${assessed(EyeSide.left) ? _icdr[gl] : 'not gradable'} · Right: ${assessed(EyeSide.right) ? _icdr[gr] + (dme ? ' + DME' : '') : 'not gradable'}';
  final (title, sub, means) = !anyAssessed
      ? (
          'Not gradable',
          'Images too dark or blurred — not a health result',
          'None of the retina images could be graded after 3 attempts, usually because the pupils were small or the lens is cloudy. Wait longer in a dark room and retake, or book a dilated eye exam.',
        )
      : sight
      ? (
          'Sight-threatening DR',
          gradesLine,
          'The partner AI found advanced retinopathy (${dme ? 'macular oedema' : 'new vessels'}) that can threaten sight. See an eye doctor within days for a dilated exam and treatment planning.',
        )
      : referable
      ? (
          'Referable DR',
          gradesLine,
          'The partner AI graded moderate retinopathy in ${_eyesText(perEyeBand, SemanticBand.refer)}. This is the level where an eye doctor should examine the retina within 90 days.'
              '${glaucoma ? ' The left optic disc also shows a large cup, so a glaucoma check is added.' : ''}',
        )
      : glaucoma
      ? (
          'Glaucoma suspect',
          gradesLine,
          'No referable retinopathy, but the optic-disc cup is large in the left eye. A routine glaucoma work-up (eye pressure, OCT, visual field) is recommended.',
        )
      : (gl == 1 || gr == 1)
      ? (
          'Mild NPDR',
          gradesLine,
          'Early, non-referable retinopathy changes were found. No treatment is needed now; repeat the screen in 12 months and keep sugar, blood pressure and lipids controlled.',
        )
      : (
          'No referable DR',
          gradesLine,
          'No retinopathy and no glaucoma sign in either eye. Screen again in 12 months.',
        );

  return _Outcome(
    findings: findings,
    perEyeBand: perEyeBand,
    perEyeGauge: perEyeGauge,
    perEyeNote: perEyeNote,
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    riskInput: RiskEvaluationInput(
      drReferable: anyAssessed && referable,
      drSightThreatening: anyAssessed && sight,
      glaucomaSuspect: anyAssessed && glaucoma,
    ),
    specialist: anyAssessed && (referable || glaucoma),
  );
}

String _eyesText(Map<EyeSide, SemanticBand> perEye, SemanticBand band) {
  final eyes = [
    for (final e in EyeSide.values)
      if (perEye[e] == band) e,
  ];
  if (eyes.length == 2) return 'both eyes';
  if (eyes.length == 1) return 'the ${eyes.first.label.toLowerCase()}';
  return 'the screened eye';
}

// ---------------------------------------------------------------------------
// 5. Newborn jaundice — ALG-IMG-07 (card mandatory, hour-specific chart)
// ---------------------------------------------------------------------------
_Outcome _newborn(
  EyeProtocol p,
  EyeAnswers a,
  List<EyePhoto> accepted,
  EyeDemoOutcome outcome,
  SubjectProfile subject,
) {
  final ageHours = a.newbornAgeHours ?? subject.ageHoursForNewborn ?? 72;
  final gestation = a.gestationWeeks ?? subject.gestationWeeksForNewborn ?? 38;
  const riskIds = {
    'sibling_phototherapy',
    'bruising',
    'blood_group',
    'ancestry_g6pd',
  };
  final hasRisk = a.questionIds.any(riskIds.contains);
  final threshold = NeonatalBilirubinChart.phototherapyThreshold(
    gestationWeeks: gestation,
    ageHours: ageHours,
    hasRiskFactors: hasRisk,
  );
  final chartApplies = threshold != null;
  final cardOk = a.hasColourCard;
  final anyPhoto = accepted.isNotEmpty;
  final assessable = chartApplies && cardOk && anyPhoto;

  // Demo estimate anchored on the baby's own line (mg/dL, 1 dp internal).
  final double estimate;
  if (threshold != null) {
    final delta = switch (outcome) {
      EyeDemoOutcome.normal => -5.5,
      EyeDemoOutcome.borderline => -1.6,
      EyeDemoOutcome.high => 1.2,
      EyeDemoOutcome.urgent => 4.0,
    };
    estimate = ((threshold + delta).clamp(1.0, 30.0) * 10).round() / 10;
  } else {
    estimate = 0;
  }
  final band = !assessable
      ? SemanticBand.notAssessed
      : NeonatalBilirubinChart.band(
          estimateMgDl: estimate,
          thresholdMgDl: threshold,
        );
  final yellowIdx = (estimate / 25.0).clamp(0.0, 1.0);

  final perZone = <String, EyeZoneResult>{};
  for (final zone in p.zoneLabelsInOrder) {
    final photosOf = accepted.where((x) => x.view.zoneLabel == zone).toList();
    if (!assessable || photosOf.isEmpty) {
      perZone[zone] = EyeZoneResult(
        band: SemanticBand.notAssessed,
        gauge: null,
        note: !cardOk
            ? 'Not assessed — colour card not read'
            : !chartApplies
            ? 'Not assessed — chart does not apply'
            : 'Not assessed — photos failed the quality checks',
      );
      continue;
    }
    // Cephalocaudal progression: chest slightly less yellow than forehead.
    final idx = (zone == 'Chest' ? yellowIdx - 0.05 : yellowIdx).clamp(
      0.0,
      1.0,
    );
    perZone[zone] = EyeZoneResult(
      band: band,
      gauge: idx,
      note:
          '${photosOf.length} photo${photosOf.length == 1 ? '' : 's'} (no flash + flash) · yellowness ${_r2(idx)}',
    );
  }

  final bucket = NeonatalBilirubinChart.bucketLabel(gestation);
  final thrText = threshold == null ? '—' : threshold.toStringAsFixed(1);
  final statusLine = !chartApplies
      ? (gestation < 35
            ? 'Chart not validated under 35 weeks — ask the clinic for a TcB or serum bilirubin.'
            : 'Baby is older than 28 days — the newborn chart no longer applies.')
      : !cardOk
      ? 'Colour card not read — the screen never shows Normal without it (E-IMG-003).'
      : switch (band) {
          SemanticBand.high =>
            'Skin colour at or above the line ($thrText mg/dL at $ageHours h).',
          SemanticBand.borderline =>
            'Skin colour within 3 mg/dL below the line ($thrText mg/dL at $ageHours h).',
          _ =>
            'Skin colour well below the line ($thrText mg/dL at $ageHours h).',
        };
  final position = threshold == null
      ? 0.0
      : (0.75 * estimate / threshold).clamp(0.0, 1.0);

  final findings = <EyeFinding>[
    EyeFinding(
      code: 'NEO_JAUNDICE_BAND',
      label: 'Newborn jaundice screen',
      valueText: !assessable
          ? 'Not assessed'
          : band == SemanticBand.high
          ? 'High — above the line'
          : band == SemanticBand.borderline
          ? 'Borderline — near the line'
          : 'Normal — below the line',
      band: band,
    ),
    EyeFinding(
      code: 'NEO_LINE',
      label: 'Treatment line for this baby',
      valueText: chartApplies
          ? '$thrText mg/dL at $ageHours h ($bucket${hasRisk ? ', with risk factors' : ''})'
          : 'Not available ($bucket)',
      band: chartApplies ? SemanticBand.normal : SemanticBand.notAssessed,
    ),
    EyeFinding(
      code: 'NEO_RISK_FACTORS',
      label: 'Neurotoxicity risk factors',
      valueText: hasRisk
          ? '${a.questionIds.where(riskIds.contains).length} reported — lower line used'
          : 'None reported',
      band: hasRisk ? SemanticBand.borderline : SemanticBand.normal,
    ),
    for (final e in perZone.entries)
      EyeFinding(
        code: 'NEO_ZONE_${e.key.toUpperCase()}',
        label: '${e.key} skin',
        valueText: e.value.gauge == null
            ? e.value.note
            : e.value.gauge! >= 0.60
            ? 'Clearly yellow'
            : e.value.gauge! >= 0.40
            ? 'Light yellow tint'
            : 'Pink',
        band: e.value.band,
        gaugeValue: e.value.gauge,
      ),
    EyeFinding(
      code: 'NEO_BILI_EST',
      label: 'Bilirubin estimate',
      valueText: assessable ? '${estimate.toStringAsFixed(1)} mg/dL' : '—',
      band: band,
      memberFacing: false,
      gaugeValue: assessable ? estimate : null,
    ),
    EyeFinding(
      code: 'NEO_B_STAR',
      label: 'Skin yellowness (CIELab b*)',
      valueText: assessable ? (6 + yellowIdx * 22).toStringAsFixed(1) : '—',
      band: band,
      memberFacing: false,
      gaugeValue: yellowIdx,
    ),
  ];

  final (title, sub, means) = !assessable
      ? (
          'Not assessed',
          !cardOk
              ? 'Colour card missing — not a health result'
              : !chartApplies
              ? 'Chart does not apply to this baby'
              : 'No usable photos — not a health result',
          !cardOk
              ? 'The 24-patch card was not read in the photos, so the lighting could not be corrected. The screen never shows Normal without the card (E-IMG-003). Ask the clinic for a transcutaneous or serum bilirubin.'
              : !chartApplies
              ? '$statusLine The clinic can measure bilirubin directly.'
              : 'No photo passed the quality checks after 3 attempts, so no band was produced. Retake in daylight with the card flat on the skin.',
        )
      : switch (band) {
          SemanticBand.high => (
            'Above the line — urgent',
            'Estimate at or above $thrText mg/dL for $ageHours h, $bucket',
            'The corrected skin colour matches a bilirubin level at or above the phototherapy-consideration line for a baby of $ageHours hours born at $gestation weeks${hasRisk ? ' with risk factors' : ''}. '
                'Take the baby for a serum bilirubin within 6 hours — the newborn unit decides on phototherapy.'
                '${a.questionIds.contains('unwell') ? ' You also reported that the baby is sleepy or feeding poorly — go today.' : ''}',
          ),
          SemanticBand.borderline => (
            'Near the line',
            'Within 3 mg/dL below $thrText mg/dL at $ageHours h',
            'The skin colour is close to the treatment line for this baby\'s age. The line rises with age in hours, so a repeat in 6–12 hours or a transcutaneous (TcB) check at the clinic today will show whether it is pulling ahead or falling behind.',
          ),
          _ => (
            'Below the line',
            'Well below $thrText mg/dL at $ageHours h, $bucket',
            'The corrected skin colour is well below the phototherapy line for a baby of $ageHours hours born at $gestation weeks. No treatment signal was found. Repeat once a day until day 5 and feed often.',
          ),
        };

  return _Outcome(
    findings: findings,
    perEyeBand: const {},
    perEyeGauge: const {},
    perEyeNote: const {},
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    riskInput: RiskEvaluationInput(
      neoJaundiceBand:
          assessable &&
              (band == SemanticBand.high || band == SemanticBand.borderline)
          ? band
          : null,
    ),
    specialist:
        assessable &&
        (band == SemanticBand.high || band == SemanticBand.borderline),
    probability: assessable ? (estimate / threshold).clamp(0.0, 1.5) : null,
    perZone: perZone,
    extraCards: [
      NeonatalChartCard(
        gestationWeeks: gestation,
        ageHours: ageHours,
        hasRiskFactors: hasRisk,
        bucketLabel: bucket,
        rows: NeonatalBilirubinChart.tableFor(
          gestationWeeks: gestation,
          hasRiskFactors: hasRisk,
        ),
        thresholdAtAge: threshold,
        positionFraction: position,
        chartApplies: chartApplies,
        statusLine: statusLine,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 6. Diabetic foot — ALG-IMG-05 (per foot, wound area, IWGDF category)
// ---------------------------------------------------------------------------
_Outcome _foot(
  EyeProtocol p,
  EyeAnswers a,
  List<EyePhoto> accepted,
  EyeDemoOutcome outcome,
  bool Function(EyeSide) assessed,
) {
  // (left index, right index, left findings, right findings, wound cm², site)
  final (li, ri, lf, rf, wound, site) = switch (outcome) {
    EyeDemoOutcome.normal => (0.10, 0.12, <String>[], <String>[], null, null),
    EyeDemoOutcome.borderline => (
      0.46,
      0.14,
      ['Callus under the big toe', 'Dry cracks on the heel'],
      <String>[],
      null,
      null,
    ),
    EyeDemoOutcome.high => (
      0.22,
      0.78,
      ['Mild callus on the ball of the foot'],
      ['Open ulcer on the heel', 'Callus ring around the wound'],
      1.8,
      'right heel',
    ),
    EyeDemoOutcome.urgent => (
      0.42,
      0.92,
      ['Callus under the big toe', 'Dry cracks on the heel'],
      [
        'Open ulcer under the ball of the foot',
        'Redness and swelling around it',
        'Maceration between the toes',
      ],
      4.6,
      'right forefoot',
    ),
  };
  SemanticBand footBand(double v) => v >= 0.65
      ? SemanticBand.ulcer
      : v >= 0.35
      ? SemanticBand.atRisk
      : SemanticBand.normal;

  // IWGDF 2023 risk category from the answers [DER].
  final prevUlcer = a.questionIds.contains('previous_ulcer');
  final lops = a.questionIds.contains('numbness');
  final pad = a.questionIds.contains('circulation');
  final category = prevUlcer
      ? 3
      : (lops && pad)
      ? 2
      : (lops || pad)
      ? 1
      : 0;
  final categoryLabel = switch (category) {
    3 => 'Category 3 — previous ulcer or amputation',
    2 => 'Category 2 — loss of feeling and poor circulation',
    1 =>
      lops
          ? 'Category 1 — loss of protective sensation'
          : 'Category 1 — poor circulation',
    _ => 'Category 0 — no loss of feeling, good circulation',
  };
  final recheck = switch (category) {
    3 => 'Foot check every 1–3 months',
    2 => 'Foot check every 3–6 months',
    1 => 'Foot check every 6–12 months',
    _ => 'Foot check yearly',
  };

  final perEyeBand = <EyeSide, SemanticBand>{};
  final perEyeGauge = <EyeSide, double?>{};
  final perEyeNote = <EyeSide, String>{};
  final perFoot = <EyeSide, List<String>>{};
  final findings = <EyeFinding>[];
  for (final side in EyeSide.values) {
    final idx = side == EyeSide.left ? li : ri;
    final list = side == EyeSide.left ? lf : rf;
    final label = p.sideLabel(side);
    if (!assessed(side)) {
      perEyeBand[side] = SemanticBand.notAssessed;
      perEyeGauge[side] = null;
      perEyeNote[side] = 'Not assessed — sole not seen clearly';
      perFoot[side] = const [];
      continue;
    }
    var b = footBand(idx);
    if (b == SemanticBand.normal && category >= 2) b = SemanticBand.atRisk;
    perEyeBand[side] = b;
    perEyeGauge[side] = idx;
    perFoot[side] = list;
    final photosOf = accepted.where((x) => x.view.eye == side).length;
    perEyeNote[side] = list.isEmpty
        ? '$photosOf photos · no callus, cracks or wound seen'
        : '$photosOf photos · ${list.join(' · ')}';
    findings.add(
      EyeFinding(
        code: 'DFU_${side == EyeSide.left ? 'L' : 'R'}',
        label: label,
        valueText: list.isEmpty ? 'Healthy skin' : list.join('; '),
        band: b,
        gaugeValue: idx,
        eye: side,
      ),
    );
  }
  final anyAssessed = perEyeBand.values.any(
    (b) => b != SemanticBand.notAssessed,
  );
  final band = anyAssessed
      ? _worse(perEyeBand.values)
      : SemanticBand.notAssessed;
  final hasUlcer = band == SemanticBand.ulcer;
  final woundSide = hasUlcer ? EyeSide.right : null;
  final worst = li > ri ? li : ri;

  findings.insert(
    0,
    EyeFinding(
      code: 'DFU_CLASS',
      label: 'Diabetic foot screen',
      valueText: !anyAssessed
          ? 'Not assessed'
          : band == SemanticBand.ulcer
          ? 'Ulcer'
          : band == SemanticBand.atRisk
          ? 'At risk'
          : 'Healthy',
      band: band,
      specValue: !anyAssessed
          ? null
          : band == SemanticBand.ulcer
          ? 'ulcer'
          : band == SemanticBand.atRisk
          ? 'at_risk'
          : 'normal',
    ),
  );
  if (hasUlcer && wound != null) {
    findings.add(
      EyeFinding(
        code: 'WOUND_AREA',
        label: 'Wound area',
        valueText: a.hasColourCard
            ? '${wound.toStringAsFixed(1)} cm² ($site)'
            : 'Card not read — size not measured',
        band: SemanticBand.ulcer,
        gaugeValue: a.hasColourCard ? wound : null,
        eye: woundSide,
      ),
    );
  }
  findings.add(
    EyeFinding(
      code: 'IWGDF_CATEGORY',
      label: 'Foot-risk category (from your answers)',
      valueText: '$categoryLabel · $recheck',
      band: category >= 2
          ? SemanticBand.atRisk
          : category == 1
          ? SemanticBand.borderline
          : SemanticBand.normal,
    ),
  );
  findings.add(
    EyeFinding(
      code: 'DFU_PROB',
      label: 'Detector probability (worse foot)',
      valueText: '${_r2(worst)} (τ 0.65 ulcer / 0.35 at risk)',
      band: band,
      gaugeValue: worst,
    ),
  );

  final urgentSigns = outcome == EyeDemoOutcome.urgent;
  final anyFinding = lf.isNotEmpty || rf.isNotEmpty;
  final (title, sub, means) = !anyAssessed
      ? (
          'Not assessed',
          'Soles not seen clearly — not a health result',
          'No photo showed the whole sole clearly after 3 attempts. Retake with a helper in bright light, card flat beside the foot.',
        )
      : hasUlcer
      ? (
          'Ulcer — urgent',
          'Open wound on the $site${a.hasColourCard && wound != null ? ' · ${wound.toStringAsFixed(1)} cm²' : ''}',
          'An open wound was found on the ${p.sideLabel(EyeSide.right).toLowerCase()}${urgentSigns ? ' with redness and swelling around it, which can mean infection' : ''}. '
              'Diabetic foot wounds heal slowly and can deepen quickly. Keep weight off it, do not treat it yourself, and go to the foot clinic within 3 days — same day if it is red, hot, smelly or you have a fever.',
        )
      : band == SemanticBand.atRisk
      ? (
          'At risk',
          anyFinding ? 'Callus or cracks seen · $categoryLabel' : categoryLabel,
          '${anyFinding ? 'Hard skin or cracks were seen — these are pressure points where ulcers start. ' : ''}'
              'Your answers place you in foot-risk $categoryLabel. A routine foot-clinic or podiatry review, well-fitting shoes and daily self-checks keep this from becoming a wound.',
        )
      : (
          'Healthy',
          'No ulcer, callus or colour change seen',
          'The skin of both soles, heels and toe spaces looks healthy and your answers do not raise the risk category. Keep the monthly photo check and look at your feet every day.',
        );

  return _Outcome(
    findings: findings,
    perEyeBand: perEyeBand,
    perEyeGauge: perEyeGauge,
    perEyeNote: perEyeNote,
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    riskInput: RiskEvaluationInput(
      dfuClass: anyAssessed && band != SemanticBand.normal ? band : null,
    ),
    specialist: anyAssessed && (hasUlcer || (worst - 0.65).abs() <= 0.10),
    probability: anyAssessed ? worst : null,
    extraCards: [
      FootRiskCard(
        category: category,
        categoryLabel: categoryLabel,
        recheck: recheck,
        perFootFindings: perFoot,
        woundAreaCm2: hasUlcer && a.hasColourCard ? wound : null,
        woundSide: woundSide,
        woundSite: hasUlcer ? site : null,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 7. Skin lesion — ALG-IMG-08 (band + possible matches + ABCDE)
// ---------------------------------------------------------------------------
_Outcome _skin(
  EyeProtocol p,
  EyeAnswers a,
  List<EyePhoto> accepted,
  EyeDemoOutcome outcome,
) {
  final anyPhoto = accepted.isNotEmpty;
  final (suspicion, matches) = switch (outcome) {
    EyeDemoOutcome.normal => (
      0.12,
      [
        (
          'Eczema (atopic dermatitis)',
          'Dry, itchy, red patch; moisturiser and a mild steroid cream usually settle it',
        ),
        (
          'Contact dermatitis',
          'Reaction to something touching the skin (metal, cosmetic, plant)',
        ),
        ('Psoriasis', 'Well-defined pink plaque with silvery scale'),
      ],
    ),
    EyeDemoOutcome.borderline => (
      0.18,
      [
        (
          'Tinea (ringworm)',
          'Ring-shaped scaly patch with a clearer centre; antifungal cream',
        ),
        (
          'Pityriasis rosea',
          'Oval pink patches that clear on their own in weeks',
        ),
        ('Nummular eczema', 'Coin-shaped itchy patch'),
      ],
    ),
    EyeDemoOutcome.high => (
      0.52,
      [
        (
          'Seborrhoeic keratosis',
          'Waxy, stuck-on brown growth; harmless but can mimic other spots',
        ),
        (
          'Basal cell carcinoma pattern',
          'Pearly bump or non-healing sore — needs a look, grows slowly',
        ),
        ('Dermatofibroma', 'Firm small bump that dimples when pinched'),
      ],
    ),
    EyeDemoOutcome.urgent => (
      0.86,
      [
        (
          'Melanoma pattern',
          'Asymmetric, multi-coloured, changing mole — dermatologist within 2 weeks',
        ),
        (
          'Atypical (dysplastic) naevus',
          'Irregular mole that needs dermoscopy',
        ),
        (
          'Seborrhoeic keratosis',
          'Harmless growth that can look dark and irregular',
        ),
      ],
    ),
  };
  final abcdeCount = a.abcdeFlags.length;
  var band = !anyPhoto
      ? SemanticBand.notAssessed
      : suspicion >= 0.65
      ? SemanticBand.suspicious
      : suspicion >= 0.35
      ? SemanticBand.refer
      : SemanticBand.normal;
  // ABCDE escalation [DER]: two or more signs always earn a look.
  final escalatedByAbcde =
      anyPhoto && band == SemanticBand.normal && abcdeCount >= 2;
  if (escalatedByAbcde) band = SemanticBand.refer;
  final lesionMm = !a.hasColourCard
      ? null
      : switch (outcome) {
          EyeDemoOutcome.normal => 4.5,
          EyeDemoOutcome.borderline => 6.0,
          EyeDemoOutcome.high => 8.2,
          EyeDemoOutcome.urgent => 9.4,
        };

  final perZone = <String, EyeZoneResult>{};
  for (final zone in p.zoneLabelsInOrder) {
    final photosOf = accepted.where((x) => x.view.zoneLabel == zone).toList();
    if (!anyPhoto || photosOf.isEmpty) {
      perZone[zone] = const EyeZoneResult(
        band: SemanticBand.notAssessed,
        gauge: null,
        note: 'Not assessed — photo failed the quality checks',
      );
      continue;
    }
    perZone[zone] = EyeZoneResult(
      band: band,
      gauge: suspicion,
      note: zone == 'Context'
          ? 'Location recorded${a.bodyLocation != null ? ' · ${a.bodyLocation!.toLowerCase()}' : ''}'
          : zone == 'Angled'
          ? 'Texture and height checked'
          : 'Pattern, edge and colour scored · suspicion ${_r2(suspicion)}',
    );
  }

  final findings = <EyeFinding>[
    EyeFinding(
      code: 'SKIN_BAND',
      label: 'Skin check',
      valueText: !anyPhoto
          ? 'Not assessed'
          : band == SemanticBand.suspicious
          ? 'Suspicious — urgent'
          : band == SemanticBand.refer
          ? 'Needs a look'
          : 'Benign pattern',
      band: band,
      specValue: !anyPhoto
          ? null
          : band == SemanticBand.suspicious
          ? 'suspicious_urgent'
          : band == SemanticBand.refer
          ? 'routine_refer'
          : 'benign_common',
    ),
    EyeFinding(
      code: 'SKIN_MATCHES',
      label: 'Possible matches (not a diagnosis)',
      valueText: anyPhoto ? matches.map((m) => m.$1).join(' · ') : '—',
      band: band,
    ),
    EyeFinding(
      code: 'ABCDE',
      label: 'ABCDE signs you ticked',
      valueText: abcdeCount == 0
          ? 'None'
          : '$abcdeCount of 5 (${a.abcdeFlags.map((k) => k[0].toUpperCase()).join(', ')})${escalatedByAbcde ? ' — raised to Needs a look' : ''}',
      band: abcdeCount >= 2
          ? SemanticBand.refer
          : abcdeCount == 1
          ? SemanticBand.borderline
          : SemanticBand.normal,
    ),
    EyeFinding(
      code: 'LESION_SIZE',
      label: 'Spot size',
      valueText: lesionMm == null
          ? 'No scale beside the spot — not measured'
          : '${lesionMm.toStringAsFixed(1)} mm across${lesionMm > 6 ? ' (wider than 6 mm)' : ''}',
      band: lesionMm != null && lesionMm > 6
          ? SemanticBand.borderline
          : SemanticBand.normal,
      gaugeValue: lesionMm,
    ),
    EyeFinding(
      code: 'SKIN_PROB',
      label: 'Suspicious-pattern probability',
      valueText: '${_r2(suspicion)} (τ 0.65 suspicious / 0.35 refer)',
      band: band,
      gaugeValue: suspicion,
    ),
    EyeFinding(
      code: 'SKIN_CLASS',
      label: 'Top class',
      valueText: matches.first.$1,
      band: band,
      specValue: matches.first.$1,
    ),
  ];

  final where = a.bodyLocation != null
      ? ' on the ${a.bodyLocation!.toLowerCase()}'
      : '';
  final (title, sub, means) = !anyPhoto
      ? (
          'Not assessed',
          'Spot not clear enough — not a health result',
          'No photo showed the spot clearly after 3 attempts (blur, shadow or hair). Retake in daylight with the spot centred in the ring.',
        )
      : band == SemanticBand.suspicious
      ? (
          'Suspicious — urgent',
          'Pattern seen in skin cancer · closest match: ${matches.first.$1}',
          'The spot$where shows a pattern the model has learned from skin-cancer images (asymmetry, uneven edge, several colours). '
              'Most such spots still prove benign after a proper look, but it needs a dermatologist with dermoscopy within 2 weeks.'
              '${a.anyEscalating(p) ? ' Your history (symptoms, sun exposure, family history or immune status) strengthens this advice.' : ''}',
        )
      : band == SemanticBand.refer
      ? (
          'Needs a look',
          escalatedByAbcde
              ? 'ABCDE signs ticked · closest match: ${matches.first.$1}'
              : 'Closest match: ${matches.first.$1}',
          escalatedByAbcde
              ? 'The photo pattern looks benign, but you ticked $abcdeCount ABCDE signs, so a routine GP or dermatology review within 4 weeks is the safe step.'
              : 'The spot$where is probably benign but has features worth a routine review within 4 weeks — for example a growing, scaly or pearly patch. The closest matches are listed below.',
        )
      : (
          'Benign pattern',
          'Closest match: ${matches.first.$1}',
          'The spot$where matches common, harmless skin conditions. Read the matches below for self-care; see a doctor if it changes, bleeds or does not settle in 4 weeks.',
        );

  return _Outcome(
    findings: findings,
    perEyeBand: const {},
    perEyeGauge: const {},
    perEyeNote: const {},
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    riskInput: RiskEvaluationInput(
      skinBand: anyPhoto && band != SemanticBand.normal ? band : null,
    ),
    specialist:
        anyPhoto &&
        (band == SemanticBand.suspicious || (suspicion - 0.65).abs() <= 0.10),
    probability: anyPhoto ? suspicion : null,
    perZone: perZone,
    extraCards: [
      SkinMatchesCard(
        matches: matches,
        abcdeFlags: a.abcdeFlags,
        abcdeItems: p.abcdeItems,
        lesionMm: lesionMm,
        bodyLocation: a.bodyLocation,
        duration: a.durationBucket,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 8. Oral pre-cancer & lesion — ALG-IMG-04 (class per site, max over views)
// ---------------------------------------------------------------------------
_Outcome _oral(
  EyeProtocol p,
  EyeAnswers a,
  List<EyePhoto> accepted,
  EyeDemoOutcome outcome,
) {
  // Demo classifier output per site: (p_suspicious, p_high, class, note, box).
  // Real values come from the ALG-IMG-04 model once it ships.
  const baseline = <String, double>{
    'Left cheek': 0.08,
    'Right cheek': 0.06,
    'Tongue · left edge': 0.11,
    'Tongue · right edge': 0.09,
    'Floor of mouth': 0.12,
    'Palate': 0.05,
  };
  final siteDemo =
      <
        String,
        (double, double, String, String, (double, double, double, double)?)
      >{};
  for (final e in baseline.entries) {
    siteDemo[e.key] = (
      e.value,
      e.value * 0.3,
      'not_suspicious',
      'Even pink lining · no patch, ulcer or lump',
      null,
    );
  }
  switch (outcome) {
    case EyeDemoOutcome.normal:
      break;
    case EyeDemoOutcome.borderline:
      siteDemo['Left cheek'] = (
        0.44,
        0.09,
        'not_suspicious',
        'Faint pale area near the bite line · near the threshold — specialist double-checks',
        (0.34, 0.38, 0.30, 0.22),
      );
    case EyeDemoOutcome.high:
      siteDemo['Left cheek'] = (
        0.74,
        0.18,
        'suspicious',
        'White patch that does not wipe off (leukoplakia pattern) · region marked',
        (0.30, 0.34, 0.36, 0.28),
      );
    case EyeDemoOutcome.urgent:
      siteDemo['Tongue · left edge'] = (
        0.62,
        0.81,
        'high_risk',
        'Red-white mixed patch with a non-healing ulcer (erythroleukoplakia pattern) · region marked',
        (0.28, 0.30, 0.40, 0.34),
      );
      siteDemo['Left cheek'] = (
        0.68,
        0.22,
        'suspicious',
        'White patch along the bite line (leukoplakia pattern) · region marked',
        (0.32, 0.36, 0.34, 0.26),
      );
  }

  SemanticBand bandFor(String cls) => switch (cls) {
    'high_risk' => SemanticBand.high,
    'suspicious' => SemanticBand.suspicious,
    _ => SemanticBand.normal,
  };
  String labelFor(SemanticBand b) => switch (b) {
    SemanticBand.high => 'High risk',
    SemanticBand.suspicious => 'Suspicious',
    SemanticBand.refer => 'Needs a look',
    SemanticBand.notAssessed => 'Not assessed',
    _ => 'Not suspicious',
  };
  int rank(SemanticBand b) => switch (b) {
    SemanticBand.high => 3,
    SemanticBand.suspicious => 2,
    SemanticBand.refer => 1,
    SemanticBand.normal => 0,
    _ => -1,
  };

  final sites = <OralSiteResult>[];
  final perZone = <String, EyeZoneResult>{};
  var worstBand = SemanticBand.notAssessed;
  String? worstSite;
  var pSuspMax = 0.0;
  var pHighMax = 0.0;
  var assessedCount = 0;
  for (final zone in p.zoneLabelsInOrder) {
    final seen = accepted.any((x) => x.view.zoneLabel == zone);
    final d = siteDemo[zone]!;
    if (!seen) {
      sites.add(
        OralSiteResult(
          zone: zone,
          band: SemanticBand.notAssessed,
          classLabel: 'Not assessed',
          note: 'Not assessed — photo failed the quality checks',
        ),
      );
      perZone[zone] = const EyeZoneResult(
        band: SemanticBand.notAssessed,
        gauge: null,
        note: 'Not assessed — photo failed the quality checks',
      );
      continue;
    }
    assessedCount++;
    final b = bandFor(d.$3);
    final score = d.$2 > d.$1 ? 0.75 + d.$2 * 0.25 : d.$1;
    pSuspMax = pSuspMax < d.$1 ? d.$1 : pSuspMax;
    pHighMax = pHighMax < d.$2 ? d.$2 : pHighMax;
    if (rank(b) > rank(worstBand) || worstBand == SemanticBand.notAssessed) {
      if (rank(b) > rank(worstBand)) {
        worstBand = b;
        worstSite = b == SemanticBand.normal ? null : zone;
      }
    }
    sites.add(
      OralSiteResult(
        zone: zone,
        band: b,
        classLabel: labelFor(b),
        note: d.$4,
        lesionBox: d.$5,
      ),
    );
    perZone[zone] = EyeZoneResult(
      band: b,
      gauge: score.clamp(0.0, 1.0),
      note: '${d.$4.split(' · ').first} · suspicion ${_r2(d.$1)}',
    );
  }
  final anyPhoto = assessedCount > 0;
  if (!anyPhoto) worstBand = SemanticBand.notAssessed;

  // Red flags from the answers [DER].
  final redFlags = <String>[];
  final nonHealing = a.durationBucket == 'Over 3 weeks';
  if (nonHealing) {
    redFlags.add('Patch, sore or lump present for over 3 weeks (non-healing)');
  } else if (a.durationBucket == '2–3 weeks') {
    redFlags.add(
      'Patch or sore for 2–3 weeks — see a dentist if not healed by 3 weeks',
    );
  }
  if (a.questionIds.contains('trismus')) {
    redFlags.add('Reduced mouth opening — possible submucous fibrosis (OSMF)');
  }
  if (a.questionIds.contains('burning')) {
    redFlags.add('Burning with spicy food — early OSMF sign');
  }
  if (a.questionIds.contains('numb_loose')) {
    redFlags.add('Numbness, loose teeth or an ill-fitting denture');
  }
  if (a.questionIds.contains('weight_voice')) {
    redFlags.add('Weight loss, voice change or a neck lump');
  }
  if (a.usesTobacco) {
    redFlags.add(
      'Current ${a.tobaccoStatus == 'Both'
          ? 'smoking and chewing'
          : a.tobaccoStatus == 'Chewing'
          ? 'gutka / paan / areca chewing'
          : 'smoking'} — the main cause of mouth cancer',
    );
    if (a.questionIds.contains('alcohol')) {
      redFlags.add('Alcohol together with tobacco multiplies the risk');
    }
  }

  // Escalation [DER]: a reported non-healing lesion or OSMF sign always earns a look.
  var band = worstBand;
  final escalated =
      anyPhoto &&
      band == SemanticBand.normal &&
      (nonHealing || a.questionIds.contains('trismus'));
  if (escalated) band = SemanticBand.refer;

  final nearThreshold = anyPhoto && (pSuspMax - 0.5).abs() <= 0.10;
  final specialist =
      anyPhoto &&
      (band == SemanticBand.suspicious ||
          band == SemanticBand.high ||
          nearThreshold);

  final notSuspiciousCount = sites
      .where((s) => s.band == SemanticBand.normal)
      .length;
  final boxed = [
    for (final s in sites)
      if (s.hasLesionBox) s.zone,
  ];
  final findings = <EyeFinding>[
    EyeFinding(
      code: 'ORAL_CLASS',
      label: 'Mouth check (worst site)',
      valueText: !anyPhoto
          ? 'Not assessed'
          : band == SemanticBand.high
          ? 'High risk — urgent'
          : band == SemanticBand.suspicious
          ? 'Suspicious — urgent'
          : band == SemanticBand.refer
          ? 'Needs a look (reported lesion)'
          : nearThreshold
          ? 'Not suspicious — under specialist review'
          : 'Not suspicious',
      band: band,
      gaugeValue: anyPhoto
          ? (pHighMax > pSuspMax ? 0.75 + pHighMax * 0.25 : pSuspMax)
          : null,
      specValue: !anyPhoto
          ? null
          : band == SemanticBand.high
          ? 'high_risk'
          : band == SemanticBand.suspicious
          ? 'suspicious'
          : 'not_suspicious',
    ),
    EyeFinding(
      code: 'ORAL_WORST_SITE',
      label: 'Site that decides the result',
      valueText: !anyPhoto
          ? '—'
          : worstSite ??
                (nearThreshold
                    ? 'Left cheek (near threshold)'
                    : 'None — all sites clear'),
      band: worstBand == SemanticBand.notAssessed
          ? SemanticBand.notAssessed
          : worstBand,
    ),
    EyeFinding(
      code: 'ORAL_SITES',
      label: 'Sites not suspicious',
      valueText:
          '$notSuspiciousCount of ${p.photoCount}'
          '${assessedCount < p.photoCount ? ' · ${p.photoCount - assessedCount} not assessed' : ''}',
      band: assessedCount == 0
          ? SemanticBand.notAssessed
          : notSuspiciousCount == assessedCount
          ? SemanticBand.normal
          : SemanticBand.borderline,
    ),
    EyeFinding(
      code: 'ORAL_RED_FLAGS',
      label: 'Red flags from your answers',
      valueText: redFlags.isEmpty
          ? 'None'
          : '${redFlags.length} — ${redFlags.first}',
      band: redFlags.isEmpty
          ? SemanticBand.normal
          : (nonHealing || a.questionIds.contains('trismus'))
          ? SemanticBand.refer
          : SemanticBand.borderline,
    ),
    EyeFinding(
      code: 'lesion_regions',
      label: 'Lesion regions (heat-map boxes)',
      valueText: !anyPhoto
          ? '—'
          : boxed.isEmpty
          ? 'None'
          : boxed.join(' · '),
      band: !anyPhoto
          ? SemanticBand.notAssessed
          : boxed.isEmpty
          ? SemanticBand.normal
          : worstBand,
      specValue: anyPhoto ? boxed : null,
    ),
    EyeFinding(
      code: 'TOBACCO_STATUS',
      label: 'Tobacco / areca status',
      valueText: a.tobaccoStatus ?? 'Not recorded',
      band: a.usesTobacco ? SemanticBand.atRisk : SemanticBand.normal,
    ),
    EyeFinding(
      code: 'ORAL_PROB_SUSP',
      label: 'P(suspicious), max over sites',
      valueText: '${_r2(pSuspMax)} (τ 0.50)',
      band: band,
      gaugeValue: pSuspMax,
    ),
    EyeFinding(
      code: 'ORAL_PROB_HIGH',
      label: 'P(high risk), max over sites',
      valueText: '${_r2(pHighMax)} (τ 0.50)',
      band: band,
      gaugeValue: pHighMax,
    ),
  ];

  final tobaccoLine = a.usesTobacco
      ? ' Because you use tobacco or areca, stopping now is the most important step — the national quitline is 1800-11-2356.'
      : '';
  final (title, sub, means) = !anyPhoto
      ? (
          'Not assessed',
          'Mouth lining not clear enough — not a health result',
          'No photo showed the lining clearly after 3 attempts (blur, dark or lips in the way). Retake with a helper, the torch on and the mouth wide open.',
        )
      : band == SemanticBand.high
      ? (
          'High risk — urgent',
          'Red-white patch and non-healing ulcer · ${worstSite!.toLowerCase()}',
          'The ${worstSite.toLowerCase()} shows a red-white mixed patch with an ulcer — the pattern the model has learned from oral-cancer images. '
              'This needs the oral-medicine biopsy pathway within 1 week; a specialist reviewer also checks the photos (IMG-10).$tobaccoLine',
        )
      : band == SemanticBand.suspicious
      ? (
          'Suspicious — urgent',
          'White patch (leukoplakia pattern) · ${worstSite!.toLowerCase()}',
          'The ${worstSite.toLowerCase()} shows a white patch that does not look like normal lining — an oral potentially malignant disorder (OPMD) pattern. '
              'Most such patches are not cancer, but an oral-medicine specialist should examine it within 2 weeks and decide on a biopsy.$tobaccoLine',
        )
      : band == SemanticBand.refer
      ? (
          'Needs a look',
          nonHealing
              ? 'Photos not suspicious · patch or sore reported for over 3 weeks'
              : 'Photos not suspicious · reduced mouth opening reported',
          'The six photos show no pre-cancer pattern, but ${nonHealing ? 'a patch, sore or lump that has lasted over 3 weeks' : 'reduced mouth opening'} must be examined in person — a routine dentist or oral-medicine check within 4 weeks.$tobaccoLine',
        )
      : nearThreshold
      ? (
          'Not suspicious — under specialist review',
          'Left cheek scored close to the threshold',
          'No site crossed the suspicious threshold, but the left cheek scored close to it, so the photos go to an oral-medicine reviewer who confirms within a few days (IMG-10). No action is needed unless the reviewer says so.$tobaccoLine',
        )
      : (
          'Not suspicious',
          'All ${assessedCount == p.photoCount ? 'six' : '$assessedCount'} sites look like healthy lining',
          'No white, red or mixed patch, ulcer or lump pattern was seen in any site.${a.usesTobacco ? ' Keep checking every 6 months while you use tobacco or areca.' : ' Check your mouth in a mirror monthly and repeat yearly.'}$tobaccoLine',
        );

  return _Outcome(
    findings: findings,
    perEyeBand: const {},
    perEyeGauge: const {},
    perEyeNote: const {},
    band: band,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    riskInput: RiskEvaluationInput(
      oralClass:
          anyPhoto &&
              (band == SemanticBand.suspicious ||
                  band == SemanticBand.high ||
                  band == SemanticBand.refer)
          ? band
          : null,
    ),
    specialist: specialist,
    probability: anyPhoto ? (pHighMax > pSuspMax ? pHighMax : pSuspMax) : null,
    perZone: perZone,
    extraCards: [
      OralSitesCard(
        sites: sites,
        redFlags: redFlags,
        worstSite: worstSite,
        tobaccoStatus: a.tobaccoStatus,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 9. Dental 4-view & caries — ALG-DEN-01..07 (FDI chart, gums, sealants,
//    BR-DEN caries-risk rule, change vs previous exam)
// ---------------------------------------------------------------------------
int _findingRank(String code) => switch (code) {
  'white_spot' => 1,
  'enamel_break' => 2,
  'cavity' => 3,
  'broken_black' => 4,
  'abscess_sign' => 5,
  _ => 0,
};

String dentalFindingLabel(String code) => switch (code) {
  'white_spot' => 'White spot (ICDAS 1–2)',
  'enamel_break' => 'Enamel break (ICDAS 3)',
  'cavity' => 'Cavity (ICDAS 4–6)',
  'broken_black' => 'Broken / black tooth',
  'abscess_sign' => 'Abscess sign',
  _ => code,
};

SemanticBand dentalFindingBand(String code) => switch (code) {
  'white_spot' => SemanticBand.borderline,
  'enamel_break' => SemanticBand.moderate,
  'cavity' => SemanticBand.high,
  'broken_black' => SemanticBand.severe,
  'abscess_sign' => SemanticBand.critical,
  _ => SemanticBand.normal,
};

/// Plain tooth name from the FDI number (quadrant + position).
String fdiToothName(int fdi) {
  final q = fdi ~/ 10;
  final n = fdi % 10;
  final primary = q >= 5;
  final side = (q == 1 || q == 4 || q == 5 || q == 8) ? 'right' : 'left';
  final jaw = (q == 1 || q == 2 || q == 5 || q == 6) ? 'upper' : 'lower';
  final type = primary
      ? switch (n) {
          1 => 'central incisor',
          2 => 'lateral incisor',
          3 => 'canine',
          4 => 'first molar',
          _ => 'second molar',
        }
      : switch (n) {
          1 => 'central incisor',
          2 => 'lateral incisor',
          3 => 'canine',
          4 => 'first premolar',
          5 => 'second premolar',
          6 => 'first molar',
          7 => 'second molar',
          _ => 'wisdom tooth',
        };
  return '${primary ? 'Baby ' : ''}$jaw $side $type';
}

_Outcome _dental(
  EyeProtocol p,
  EyeAnswers a,
  List<EyePhoto> accepted,
  EyeDemoOutcome outcome,
  SubjectProfile subject,
  DentalExamResult? previous,
  String sessionId,
  DateTime now,
) {
  final age = subject.ageYears;
  final child = age >= 1 && age <= 12 || (age == 0 && !subject.isNewborn);
  final primary = age <= 5;
  final mixed = age >= 6 && age <= 12;
  bool has(String code) => accepted.any((x) => x.view.zoneCode == code);
  final frontSeen = has('D1') || has('D2');
  final viewsCompleted = ['D1', 'D2', 'D3', 'D4'].where(has).length;
  final anyPhoto = viewsCompleted > 0;

  // --- Demo per-tooth findings (source view, FDI adult / child) -------------
  // (code, fdi, probability, sourceView)
  final demo = <(String, int, double, String)>[];
  switch (outcome) {
    case EyeDemoOutcome.normal:
      break;
    case EyeDemoOutcome.borderline:
      demo.add(('white_spot', child ? 52 : 12, 0.71, 'D1'));
    case EyeDemoOutcome.high:
      demo.add(('cavity', child ? 54 : 36, 0.88, child ? 'D3' : 'D4'));
      demo.add(('white_spot', child ? 51 : 11, 0.66, 'D1'));
      demo.add(('white_spot', child ? 61 : 21, 0.62, 'D1'));
    case EyeDemoOutcome.urgent:
      demo.add(('abscess_sign', child ? 85 : 46, 0.83, 'D4'));
      demo.add(('cavity', child ? 54 : 36, 0.88, child ? 'D3' : 'D4'));
      demo.add(('white_spot', child ? 51 : 11, 0.64, 'D1'));
  }
  final sourceOf = <int, String>{};
  final probOf = <int, double>{};
  final previousByFdi = {
    for (final f in previous?.toothFindings ?? const <ToothFinding>[])
      f.toothFdi: f,
  };
  final findingsList = <ToothFinding>[];
  for (final d in demo) {
    if (!has(d.$4)) continue; // the view that shows this tooth was not taken
    final prev = previousByFdi[d.$2];
    final change = prev == null
        ? (previous == null ? 'Baseline' : 'New')
        : _findingRank(prev.findingCode) < _findingRank(d.$1)
        ? 'Progressed'
        : 'Unchanged';
    sourceOf[d.$2] = d.$4;
    probOf[d.$2] = d.$3;
    findingsList.add(
      ToothFinding(
        toothFdi: d.$2,
        findingCode: d.$1,
        findingLabel: dentalFindingLabel(d.$1),
        probability: d.$3,
        band: dentalFindingBand(d.$1),
        changeVsPrevious: change,
      ),
    );
  }
  findingsList.sort(
    (x, y) =>
        _findingRank(y.findingCode).compareTo(_findingRank(x.findingCode)),
  );

  // --- Unseen teeth per missing view (E-DEN-001 partial exam) --------------
  final unseen = <int>[];
  if (!has('D3')) {
    unseen.addAll(
      child
          ? [55, 54, 64, 65, if (mixed) 16, if (mixed) 26]
          : [18, 17, 16, 15, 14, 24, 25, 26, 27, 28],
    );
  }
  if (!has('D4')) {
    unseen.addAll(
      child
          ? [85, 84, 74, 75, if (mixed) 36, if (mixed) 46]
          : [48, 47, 46, 45, 44, 34, 35, 36, 37, 38],
    );
  }
  if (!frontSeen) {
    unseen.addAll(
      child
          ? [53, 52, 51, 61, 62, 63, 83, 82, 81, 71, 72, 73]
          : [13, 12, 11, 21, 22, 23, 43, 42, 41, 31, 32, 33],
    );
  }
  unseen.sort();

  // --- Gums & plaque (ALG-DEN-04, front views) ------------------------------
  final (gum, plaque) = !frontSeen
      ? (SemanticBand.notAssessed, SemanticBand.notAssessed)
      : switch (outcome) {
          EyeDemoOutcome.normal => (SemanticBand.low, SemanticBand.low),
          EyeDemoOutcome.borderline => (
            SemanticBand.low,
            SemanticBand.moderate,
          ),
          EyeDemoOutcome.high => (SemanticBand.moderate, SemanticBand.moderate),
          EyeDemoOutcome.urgent => (SemanticBand.high, SemanticBand.high),
        };

  // --- Sealant need (ALG-DEN-05: 16/26/36/46, ages 6–9) ---------------------
  final sealants = <int>[
    if (age >= 6 && age <= 9) ...[
      if (has('D3')) ...[16, 26],
      if (has('D4')) ...[36, 46],
    ],
  ].where((t) => !findingsList.any((f) => f.toothFdi == t)).toList();

  // --- Caries-risk rule (ALG-DEN-06 / BR-DEN) -------------------------------
  final habits = CariesHabitsInput(
    nightBottleFeeding: a.nightFeeding,
    brushingPerDay: a.brushingPerDay ?? 2,
    // "Don't know" is scored as no fluoride (conservative) [DER].
    usesFluoridePaste: a.fluoridePaste == 'yes',
    sweetsPerDay: a.sweetsPerDay ?? 1,
  );
  final risk = CariesRiskEngine.evaluate(
    findings: findingsList,
    habits: habits,
  );
  final habitsComplete = a.brushingPerDay != null && a.fluoridePaste != null;

  // --- Urgency for the exam object (T13 / T14) ------------------------------
  final abscess = findingsList.any((f) => f.findingCode == 'abscess_sign');
  final cavitated = findingsList.any(
    (f) =>
        f.findingCode == 'cavity' ||
        f.findingCode == 'enamel_break' ||
        f.findingCode == 'broken_black',
  );
  final examUrgency = abscess
      ? UrgencyLevel.urgent
      : cavitated
      ? UrgencyLevel.routine
      : UrgencyLevel.none;

  // --- Change vs previous (ALG-DEN-07) --------------------------------------
  final changes = <(int, String)>[];
  if (previous != null) {
    for (final f in findingsList) {
      if (f.changeVsPrevious != 'Unchanged') {
        changes.add((f.toothFdi, f.changeVsPrevious));
      }
    }
    for (final pf in previous.toothFindings) {
      final stillThere = findingsList.any((f) => f.toothFdi == pf.toothFdi);
      if (!stillThere) {
        changes.add((
          pf.toothFdi,
          unseen.contains(pf.toothFdi)
              ? 'Not comparable (not seen)'
              : 'Resolved / restored',
        ));
      }
    }
  }

  final exam = DentalExamResult(
    examId: sessionId,
    subjectId: subject.id,
    recordedAt: now,
    isChildMode: child,
    viewsCompleted: viewsCompleted,
    isPartial: anyPhoto && viewsCompleted < 4,
    unseenTeethFdi: unseen,
    toothFindings: findingsList,
    gumInflammationBand: gum,
    plaqueBand: plaque,
    sealantNeededTeethFdi: sealants,
    cariesRiskBand: anyPhoto ? risk.riskBand : SemanticBand.notAssessed,
    cariesRiskReason: risk.explanation,
    urgency: examUrgency,
  );

  // --- Per-view rows ---------------------------------------------------------
  String teethIn(String code) {
    final list = findingsList
        .where((f) => sourceOf[f.toothFdi] == code)
        .toList();
    if (list.isEmpty) return '';
    return list
        .map(
          (f) =>
              '${f.toothFdi} ${f.findingLabel.split(' (').first.toLowerCase()}',
        )
        .join(' · ');
  }

  final perZone = <String, EyeZoneResult>{};
  for (final v in p.views) {
    final zone = v.zoneLabel!;
    if (!has(v.zoneCode!)) {
      perZone[zone] = const EyeZoneResult(
        band: SemanticBand.notAssessed,
        gauge: null,
        note:
            'Not seen — view skipped or failed the quality checks (partial exam)',
      );
      continue;
    }
    final inView = findingsList
        .where((f) => sourceOf[f.toothFdi] == v.zoneCode)
        .toList();
    final worst = inView.isEmpty
        ? 0
        : inView
              .map((f) => _findingRank(f.findingCode))
              .reduce((x, y) => x > y ? x : y);
    final gauge = worst == 0
        ? 0.08
        : worst == 1
        ? 0.45
        : worst == 2
        ? 0.60
        : 0.90;
    final band = worst == 0
        ? SemanticBand.normal
        : worst <= 2
        ? SemanticBand.moderate
        : SemanticBand.high;
    final gumNote = v.zoneCode == 'D1'
        ? ' · gums ${gum.label.toLowerCase()} · plaque ${plaque.label.toLowerCase()}'
        : '';
    perZone[zone] = EyeZoneResult(
      band: band,
      gauge: gauge,
      note: inView.isEmpty
          ? 'All teeth sound in this view$gumNote'
          : '${teethIn(v.zoneCode!)}$gumNote',
    );
  }

  // --- Findings table --------------------------------------------------------
  final worstFinding = findingsList.isEmpty ? null : findingsList.first;
  final findingsText = findingsList.isEmpty
      ? (anyPhoto ? 'None — all seen teeth sound' : 'Not assessed')
      : findingsList
            .map(
              (f) =>
                  '${f.toothFdi} ${f.findingLabel.split(' (').first.toLowerCase()}',
            )
            .join(' · ');
  final changeText = !anyPhoto
      ? '—'
      : previous == null
      ? 'First dental baseline recorded'
      : changes.isEmpty
      ? 'No change since ${_d(previous.recordedAt)}'
      : changes.map((c) => '${c.$1} ${c.$2.toLowerCase()}').join(' · ');
  final findings = <EyeFinding>[
    EyeFinding(
      code: 'CARIES_RISK',
      label: 'Caries risk (ALG-DEN-06)',
      valueText: !anyPhoto
          ? 'Not assessed'
          : '${risk.riskBand.label.replaceAll(' Risk', '')} risk'
                '${habitsComplete ? '' : ' (habits incomplete — findings only)'}',
      band: exam.cariesRiskBand,
      specValue: !anyPhoto
          ? null
          : exam.cariesRiskBand == SemanticBand.high
          ? 'high'
          : exam.cariesRiskBand == SemanticBand.moderate
          ? 'moderate'
          : 'low',
    ),
    EyeFinding(
      code: 'DENTAL_TEETH',
      label: 'Teeth with findings (ALG-DEN-03)',
      valueText: findingsText,
      band:
          worstFinding?.band ??
          (anyPhoto ? SemanticBand.normal : SemanticBand.notAssessed),
      specValue: exam.toothFindings.map((f) => f.toothFdi).toList(),
    ),
    EyeFinding(
      code: 'dental_exam.partial',
      label: 'Partial exam (ALG-DEN-01)',
      valueText: !anyPhoto
          ? '—'
          : exam.isPartial
          ? 'Yes — ${unseen.length} teeth not seen'
          : 'No — all 4 views',
      band: !anyPhoto
          ? SemanticBand.notAssessed
          : exam.isPartial
          ? SemanticBand.borderline
          : SemanticBand.normal,
      specValue: anyPhoto ? exam.isPartial : null,
    ),
    EyeFinding(
      code: 'finding_code',
      label: 'Worst tooth finding (ALG-DEN-03)',
      valueText: !anyPhoto
          ? '—'
          : worstFinding == null
          ? 'None'
          : '${worstFinding.findingLabel} on ${worstFinding.toothFdi}',
      band:
          worstFinding?.band ??
          (anyPhoto ? SemanticBand.normal : SemanticBand.notAssessed),
      specValue: !anyPhoto ? null : (worstFinding?.findingCode ?? 'none'),
    ),
    if (worstFinding != null)
      EyeFinding(
        code: 'finding_prob',
        label: 'Finding probability, worst tooth (ALG-DEN-03)',
        valueText: '${_r2(worstFinding.probability)} (τ 0.50)',
        band: worstFinding.band,
        gaugeValue: worstFinding.probability,
      ),
    EyeFinding(
      code: 'GUM_INFLAM_BAND',
      label: 'Gum inflammation (ALG-DEN-04)',
      valueText: gum == SemanticBand.notAssessed
          ? 'Not assessed — no front view'
          : gum.label,
      band: gum,
      specValue: gum == SemanticBand.notAssessed ? null : gum.name,
    ),
    EyeFinding(
      code: 'PLAQUE_BAND',
      label: 'Plaque (ALG-DEN-04)',
      valueText: plaque == SemanticBand.notAssessed
          ? 'Not assessed — no front view'
          : plaque.label,
      band: plaque,
      specValue: plaque == SemanticBand.notAssessed ? null : plaque.name,
    ),
    EyeFinding(
      code: 'SEALANT_NEED',
      label: 'Sealant candidates (ALG-DEN-05, ages 6–9)',
      valueText: age < 6 || age > 9
          ? 'Not applicable at age $age'
          : sealants.isEmpty
          ? 'None'
          : 'Teeth ${sealants.join(', ')} — deep grooves, ask about fissure sealants',
      band: sealants.isEmpty ? SemanticBand.normal : SemanticBand.borderline,
      specValue: age < 6 || age > 9 ? null : sealants,
    ),
    EyeFinding(
      code: 'DENTAL_CHANGE',
      label: 'Change since last exam (ALG-DEN-07)',
      valueText: changeText,
      band: changes.any((c) => c.$2 == 'Progressed' || c.$2 == 'New')
          ? SemanticBand.borderline
          : SemanticBand.normal,
      specValue: !anyPhoto || previous == null ? null : changeText,
    ),
    EyeFinding(
      code: 'VIEWS_DONE',
      label: 'Views completed (ALG-DEN-01)',
      valueText:
          '$viewsCompleted of 4'
          '${exam.isPartial ? ' — partial exam, ${unseen.length} teeth not seen' : ''}',
      band: !anyPhoto
          ? SemanticBand.notAssessed
          : exam.isPartial
          ? SemanticBand.borderline
          : SemanticBand.normal,
      gaugeValue: anyPhoto ? viewsCompleted.toDouble() : null,
    ),
    EyeFinding(
      code: 'DEN_PROB',
      label: 'Per-tooth finding probabilities',
      valueText: probOf.isEmpty
          ? '—'
          : probOf.entries.map((e) => '${e.key}: ${_r2(e.value)}').join(' · '),
      band: worstFinding?.band ?? SemanticBand.normal,
      memberFacing: false,
    ),
  ];

  // --- Headline -------------------------------------------------------------
  final partialNote = exam.isPartial
      ? ' This was a partial exam ($viewsCompleted of 4 views) — ${unseen.length} teeth were not seen and are marked "?" on the chart.'
      : '';
  final riskWord = risk.riskBand.label.replaceAll(' Risk', '').toLowerCase();
  String teethList(Iterable<ToothFinding> fs) =>
      fs.map((f) => '${f.toothFdi}').join(', ');
  final whites = findingsList.where((f) => f.findingCode == 'white_spot');
  final cavities = findingsList.where((f) => f.findingCode == 'cavity');
  final extras = [
    if (cavities.isNotEmpty) 'a cavity on ${teethList(cavities)}',
    if (whites.isNotEmpty) 'early white spots on ${teethList(whites)}',
  ].join(' and ');
  final extrasSentence = extras.isEmpty
      ? 'The caries risk is $riskWord.'
      : '${extras[0].toUpperCase()}${extras.substring(1)} raise the caries risk to $riskWord.';
  final (title, sub, means) = !anyPhoto
      ? (
          'Not assessed',
          'No view showed the teeth clearly — not a health result',
          'None of the four views passed the quality checks after 3 attempts. Retake with dry teeth, lips pulled back and the torch on.',
        )
      : abscess
      ? (
          'Abscess sign — urgent',
          'Tooth ${teethList(findingsList.where((f) => f.findingCode == 'abscess_sign'))} · caries risk $riskWord',
          'A swelling or gum boil (abscess sign) was seen next to tooth ${teethList(findingsList.where((f) => f.findingCode == 'abscess_sign'))} — an infected tooth that needs a dentist within 3 days, the same day if there is fever or facial swelling. '
              '$extrasSentence$partialNote',
        )
      : risk.riskBand == SemanticBand.high
      ? (
          'High caries risk',
          cavities.isNotEmpty
              ? 'Cavity on ${teethList(cavities)}${whites.isNotEmpty ? ' · white spots ${teethList(whites)}' : ''}'
              : whites.length >= 2
              ? 'White spots on ${teethList(whites)}'
              : 'White spot on ${teethList(whites)} + night feeding',
          '${cavities.isNotEmpty ? 'A cavity (ICDAS 4–6) was seen on tooth ${teethList(cavities)} — it needs a filling, so see a dentist within 4 weeks (T14). ' : ''}'
              '${whites.isNotEmpty ? 'White spots on ${teethList(whites)} are early decay that fluoride can still reverse. ' : ''}'
              'By the BR-DEN rule this is high caries risk: brush twice a day with fluoride toothpaste, cut sweets to mealtimes, and ask the dentist about fluoride varnish.$partialNote',
        )
      : risk.riskBand == SemanticBand.moderate
      ? (
          'Moderate caries risk',
          whites.isNotEmpty
              ? 'One early white spot (tooth ${teethList(whites)})'
              : 'No decay seen · sugar, brushing or fluoride gaps',
          '${whites.isNotEmpty ? 'A chalky white spot on tooth ${teethList(whites)} is the first, reversible stage of decay. ' : 'No decay was seen, but your habits (sweets ${a.sweetsPerDay ?? '?'} a day, brushing ${a.brushingPerDay ?? '?'} a day${a.fluoridePaste == 'yes' ? '' : ', fluoride paste not confirmed'}) put the teeth at moderate risk. '}'
              'Brush twice a day with fluoride toothpaste, spit but do not rinse, keep sweets to twice a day, and see a dentist within 3 months for fluoride varnish.$partialNote',
        )
      : (
          'Low caries risk',
          'No decay seen · gums ${gum == SemanticBand.notAssessed ? 'not assessed' : gum.label.toLowerCase()}',
          'All ${child ? 'baby ' : ''}teeth seen look sound and your habits protect them. Keep brushing twice a day with fluoride toothpaste and repeat the photos in 6 months so the app can compare each tooth.$partialNote',
        );

  final habitsSummary =
      'Brushing ${a.brushingPerDay == null
          ? '?'
          : a.brushingPerDay == 0
          ? 'none'
          : a.brushingPerDay == 1
          ? 'once'
          : 'twice+'} a day · fluoride paste ${a.fluoridePaste ?? '?'} · sweets ${a.sweetsPerDay ?? '?'}/day'
      '${age < 6 ? ' · night feeding ${a.nightFeeding ? 'yes' : 'no'}' : ''}'
      '${a.lastDentalVisit != null ? ' · last dentist visit ${a.lastDentalVisit!.toLowerCase()}' : ''}';

  return _Outcome(
    findings: findings,
    perEyeBand: const {},
    perEyeGauge: const {},
    perEyeNote: const {},
    band: exam.cariesRiskBand,
    bandTitle: title,
    bandSubline: sub,
    whatItMeans: means,
    riskInput: RiskEvaluationInput(
      dentalAbscessSign: abscess,
      dentalCavityOnly: !abscess && cavitated,
    ),
    specialist: false,
    probability: worstFinding?.probability,
    perZone: perZone,
    highlightBand: abscess ? SemanticBand.high : null,
    extraCards: [
      DentalChartCard(
        exam: exam,
        dentitionLabel: primary
            ? 'Primary teeth (FDI 51–85)'
            : mixed
            ? 'Mixed dentition (51–85 + first molars 16/26/36/46)'
            : 'Permanent teeth (FDI 11–48)',
        cariesReason: risk.explanation,
        changes: changes,
        previousExamAt: previous?.recordedAt,
        habitsSummary: habitsSummary,
        mixedDentition: mixed,
      ),
    ],
  );
}

String _d(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
