import '../entities/anaemia_result.dart';
import '../entities/breath_protocol.dart';
import '../entities/breath_result.dart';
import '../entities/enums.dart';
import '../entities/eye_photo_session.dart';
import '../entities/hearing_protocol.dart';
import '../entities/hearing_result.dart';
import '../entities/mind_protocol.dart';
import '../entities/mind_result.dart';
import '../entities/marker_catalogue.dart';
import '../entities/marker_envelope.dart';
import '../entities/movement_result.dart';
import '../entities/sleep_result.dart';
import '../entities/vision_protocol.dart';
import '../entities/vision_result.dart';

/// One spec output marker paired with what the session actually produced.
class MarkerReading {
  const MarkerReading({
    required this.spec,
    required this.status,
    this.envelope,
    this.value,
    this.band = SemanticBand.notAvailable,
    this.reason,
    this.sideLabel,
    this.bpNumericReleased = false,
  });

  final MarkerSpec spec;
  final MarkerEnvelope<dynamic>? envelope;

  /// Raw spec value: num, String (band / class code), bool or List.
  final Object? value;
  final SemanticBand band;
  final MarkerDisplayStatus status;

  /// Why the value is missing / hidden (spec failure rule).
  final String? reason;

  /// 'Left' / 'Right' when one spec marker maps to per-side session keys.
  final String? sideLabel;
  final bool bpNumericReleased;

  String get code => sideLabel == null
      ? spec.code
      : '${spec.code}_${sideLabel == 'Left' ? 'L' : 'R'}';

  String get label =>
      sideLabel == null ? spec.label : '${spec.label} · $sideLabel';

  bool get isMissing => value == null && envelope == null;

  /// Spec display rule, with SBP/DBP released once numeric validation passes.
  bool get memberFacing => switch (spec.display) {
    MarkerDisplay.shown || MarkerDisplay.bandOnly => true,
    MarkerDisplay.internalUntilValidated => bpNumericReleased,
    MarkerDisplay.internal || MarkerDisplay.diagnostic => false,
  };

  bool get hasValue =>
      value != null &&
      status != MarkerDisplayStatus.notAvailable &&
      status != MarkerDisplayStatus.notAssessed &&
      status != MarkerDisplayStatus.qualityRetakeRequired &&
      status != MarkerDisplayStatus.lowConfidenceHidden &&
      status != MarkerDisplayStatus.inValidation;

  double? get numericValue => value is num ? (value as num).toDouble() : null;

  /// Probability within ±0.10 of τ → IMG-10 specialist review.
  bool get inUncertainZone {
    final v = numericValue;
    final t = spec.threshold;
    return v != null && t != null && (v - t).abs() <= 0.10;
  }

  /// Value formatted to the spec decimals and unit.
  String get formatted {
    if (!hasValue) {
      return reason ??
          switch (status) {
            MarkerDisplayStatus.notAssessed => 'Not assessed',
            MarkerDisplayStatus.qualityRetakeRequired => 'Retake required',
            MarkerDisplayStatus.lowConfidenceHidden =>
              'Hidden (confidence < 0.60)',
            MarkerDisplayStatus.inValidation => 'In validation (G-24)',
            _ => 'Not available',
          };
    }
    final v = value;
    switch (spec.kind) {
      case MarkerKind.number:
        if (v is num) {
          final s = v.toDouble().toStringAsFixed(spec.decimals);
          return spec.unit.isEmpty ? s : '$s ${spec.unit}';
        }
        return v.toString();
      case MarkerKind.band:
      case MarkerKind.classCode:
        return v.toString();
      case MarkerKind.flag:
        if (v is bool) return v ? 'Yes' : 'No';
        return v.toString();
      case MarkerKind.list:
        if (v is List) return v.isEmpty ? 'None' : v.join(', ');
        return v.toString();
      case MarkerKind.text:
        return v.toString();
    }
  }

  /// 'τ 0.50 · within ±0.10 → specialist review (IMG-10)' for probabilities.
  String? get thresholdNote {
    final t = spec.threshold;
    if (t == null || !hasValue) return null;
    final base = 'τ ${t.toStringAsFixed(2)}';
    return inUncertainZone
        ? '$base · within ±0.10 → specialist review (IMG-10)'
        : base;
  }
}

class ReadingGroup {
  const ReadingGroup({required this.card, required this.readings});

  final AlgorithmCard card;
  final List<MarkerReading> readings;

  List<MarkerReading> get memberReadings =>
      readings.where((r) => r.memberFacing).toList();
  List<MarkerReading> get internalReadings =>
      readings.where((r) => !r.memberFacing).toList();
}

/// Builds spec-ordered [ReadingGroup]s from session envelopes.
class MarkerReadings {
  MarkerReadings._();

  static const String appCardId = 'APP-DER';

  /// Pair every spec output of [cards] with the matching envelope(s).
  static List<ReadingGroup> fromEnvelopes(
    Iterable<MarkerEnvelope<dynamic>> envelopes,
    List<AlgorithmCard> cards, {
    bool bpNumericReleased = false,
    bool dropEmptyCards = false,
    Map<String, String> missingReasons = const {},
  }) {
    final envs = envelopes.toList();
    final groups = <ReadingGroup>[];
    for (final card in cards) {
      final readings = <MarkerReading>[];
      var any = false;
      for (final spec in card.outputs) {
        final matches = envs.where((e) => spec.matches(e.code)).toList();
        if (matches.isEmpty) {
          readings.add(
            MarkerReading(
              spec: spec,
              status: MarkerDisplayStatus.notAvailable,
              reason:
                  missingReasons[spec.code] ??
                  spec.missingReason ??
                  'Not produced in this session',
              bpNumericReleased: bpNumericReleased,
            ),
          );
          continue;
        }
        any = true;
        for (final e in matches) {
          readings.add(
            _fromEnvelope(
              spec,
              e,
              bpNumericReleased: bpNumericReleased,
              sideLabel: matches.length > 1 || e.code != spec.code
                  ? _sideOf(e.code)
                  : null,
            ),
          );
        }
      }
      if (any || !dropEmptyCards) {
        groups.add(ReadingGroup(card: card, readings: readings));
      }
    }
    return groups;
  }

  static String? _sideOf(String code) {
    if (code.endsWith('_L')) return 'Left';
    if (code.endsWith('_R')) return 'Right';
    return null;
  }

  static MarkerReading _fromEnvelope(
    MarkerSpec spec,
    MarkerEnvelope<dynamic> e, {
    required bool bpNumericReleased,
    String? sideLabel,
  }) {
    var status = e.displayStatus;
    // The spec display rule wins over the producer's R-9 flag.
    if (status == MarkerDisplayStatus.internalOnly && spec.memberFacing) {
      status = MarkerDisplayStatus.ok;
    }
    if (e.confidence < 0.60 &&
        status != MarkerDisplayStatus.notAvailable &&
        status != MarkerDisplayStatus.notAssessed &&
        status != MarkerDisplayStatus.qualityRetakeRequired &&
        status != MarkerDisplayStatus.internalOnly) {
      status = MarkerDisplayStatus.lowConfidenceHidden;
    }
    return MarkerReading(
      spec: spec,
      envelope: e,
      value: _valueFor(spec, e),
      band: e.band,
      status: status,
      reason: e.statusReason,
      sideLabel: sideLabel,
      bpNumericReleased: bpNumericReleased,
    );
  }

  static Object? _valueFor(MarkerSpec spec, MarkerEnvelope<dynamic> e) {
    final v = e.value;
    switch (spec.kind) {
      case MarkerKind.number:
        if (v is num) return v;
        // A producer-declared qualitative reading (e.g. tremor "No peak"
        // above the noise floor, Spec §9 normal) is shown as given.
        if (v is String && v.isNotEmpty) return v;
        return null;
      case MarkerKind.band:
        if (v is String && spec.allowedValues.contains(v)) return v;
        final fromBand = bandCode(e.band);
        if (spec.allowedValues.contains(fromBand)) return fromBand;
        if (v is String) {
          final norm = v.toLowerCase().replaceAll(' ', '_');
          if (spec.allowedValues.contains(norm)) return norm;
        }
        if (e.band == SemanticBand.notAvailable ||
            e.band == SemanticBand.notAssessed ||
            e.band == SemanticBand.hidden) {
          return null;
        }
        return fromBand;
      case MarkerKind.classCode:
        if (v is String) return v;
        return e.formattedOverride;
      case MarkerKind.flag:
        if (v is bool) return v;
        if (v is String) {
          final s = v.toLowerCase();
          if (s == 'yes' || s == 'true') return true;
          if (s == 'no' || s == 'false') return false;
        }
        return v;
      case MarkerKind.list:
        if (v is List) return v;
        if (v is String) {
          return v.split(', ').where((s) => s.isNotEmpty).toList();
        }
        return v == null ? null : [v];
      case MarkerKind.text:
        return v ?? e.formattedOverride;
    }
  }

  /// `SemanticBand.prediabetesRisk` → `prediabetes_risk`.
  static String bandCode(SemanticBand b) {
    final buf = StringBuffer();
    for (final ch in b.name.codeUnits) {
      final c = String.fromCharCode(ch);
      if (c.toUpperCase() == c && c.toLowerCase() != c) {
        buf.write('_${c.toLowerCase()}');
      } else {
        buf.write(c);
      }
    }
    return buf.toString();
  }

  // ---------------------------------------------------------------------
  // Adapters
  // ---------------------------------------------------------------------

  static MarkerEnvelope<dynamic> synth(
    String code, {
    required Object? value,
    required String algorithmId,
    SemanticBand band = SemanticBand.normal,
    MarkerDisplayStatus status = MarkerDisplayStatus.ok,
    String? reason,
    double confidence = 1.0,
    String version = 'v1.0.0',
  }) {
    final spec = MarkerCatalogue.byCode(code);
    return MarkerEnvelope<dynamic>(
      code: code,
      displayName: spec?.label ?? code,
      algorithmId: algorithmId,
      algorithmVersion: version,
      rangeVersion: 'mst_ref_2026.10',
      unit: spec?.unit ?? '',
      decimals: spec?.decimals ?? 0,
      value: value,
      band: band,
      confidence: confidence,
      displayStatus: status,
      statusReason: reason,
      conditionsInformed: spec?.conditions ?? const [],
    );
  }

  /// S-D07: every vitals card in report order, plus the PUL-09 quality row.
  static List<ReadingGroup> fromVitals(
    VitalsSessionResult s, {
    required bool bpNumericReleased,
  }) {
    final envs = <MarkerEnvelope<dynamic>>[
      ...s.markers.values,
      ...s.derivedFormulas.values,
      ...s.diagnosticMarkers.values,
      synth(
        'pulse_snr_db',
        value: s.pulseSnrDb,
        algorithmId: 'ALG-PUL-09',
        band: s.pulseSnrDb >= 3 ? SemanticBand.normal : SemanticBand.critical,
      ),
      synth(
        'clean_beat_count',
        value: s.cleanBeatCount,
        algorithmId: 'ALG-PUL-09',
        band: s.cleanBeatCount >= 20
            ? SemanticBand.normal
            : SemanticBand.critical,
      ),
      if (s.pulseSignal != null)
        synth(
          'template_corr_mean',
          value: s.pulseSignal!.templateCorrMean,
          algorithmId: 'ALG-PUL-09',
        ),
    ];
    final face = s.captureMode == VitalsCaptureMode.face;
    return fromEnvelopes(
      envs,
      MarkerCatalogue.vitalsCards,
      bpNumericReleased: bpNumericReleased,
      missingReasons: {
        if (face) 'PI': 'Finger mode only (§4.8)',
        if (face) 'SPO2_ROR': 'Finger mode only (§4.5)',
        if (face) 'SPO2_EST': 'Finger mode only (§4.5)',
        if (s.cleanBeatCount < 40)
          'NOTCH_TIME': 'Needs ≥ 40 clean beats (§4.8)',
        if (s.cleanBeatCount < 40)
          'NOTCH_REL_H': 'Needs ≥ 40 clean beats (§4.8)',
        if (s.cleanBeatCount < 40) 'RI': 'Needs ≥ 40 clean beats (§4.8)',
        if (s.cleanBeatCount < 40)
          'AREA_RATIO': 'Needs ≥ 40 clean beats (§4.8)',
      },
    );
  }

  static MarkerEnvelope<dynamic> _reviewEnvelope(
    String status,
    bool required,
  ) => synth(
    MarkerCatalogue.reviewStatusCode,
    value: status,
    algorithmId: 'IMG-10',
    band: required ? SemanticBand.hidden : SemanticBand.normal,
  );

  /// Photo-engine result: the protocol's card, IMG-10, then any app-derived
  /// extra findings under an "Additional checks" card.
  static List<ReadingGroup> fromEye(EyeSessionResult r) {
    final card = MarkerCatalogue.card(r.protocol.algorithmId);
    final envs = <MarkerEnvelope<dynamic>>[
      ...r.markers.values,
      _reviewEnvelope(r.specialistReviewStatus, r.specialistReviewRequired),
    ];
    final cards = [?card, MarkerCatalogue.card('IMG-10')!];
    final groups = fromEnvelopes(envs, cards);
    final covered = <String>{};
    for (final g in groups) {
      for (final rd in g.readings) {
        if (rd.envelope != null) covered.add(rd.envelope!.code);
      }
    }
    final extras = r.memberFindings
        .where((f) => !covered.contains(f.code))
        .toList();
    if (extras.isNotEmpty) {
      final specs = [
        for (final f in extras)
          MarkerSpec(
            code: f.code,
            label: f.label,
            algorithmId: r.protocol.algorithmId,
            specRef: '[DER]',
            display: MarkerDisplay.shown,
            kind: MarkerKind.text,
            howComputed: 'App-derived supporting check, not a spec marker.',
          ),
      ];
      final appCard = AlgorithmCard(
        id: appCardId,
        title: 'Additional checks',
        specRef: '[DER]',
        classification: 'App-derived supporting values',
        purpose:
            'Supporting values the app derives next to the spec outputs (not spec markers).',
        outputs: specs,
      );
      groups.add(
        ReadingGroup(
          card: appCard,
          readings: [
            for (final f in extras)
              MarkerReading(
                spec: specs.firstWhere((s) => s.code == f.code),
                status:
                    r.markers[f.code]?.displayStatus ?? MarkerDisplayStatus.ok,
                envelope: r.markers[f.code],
                value: f.valueText,
                band: f.band,
              ),
          ],
        ),
      );
    }
    return groups;
  }

  static List<ReadingGroup> fromAnaemia(AnaemiaSessionResult r) {
    return fromEnvelopes(
      [
        ...r.markers.values,
        _reviewEnvelope(r.specialistReviewStatus, r.specialistReviewRequired),
      ],
      [MarkerCatalogue.card('ALG-IMG-01')!, MarkerCatalogue.card('IMG-10')!],
    );
  }

  static const Map<String, int> _findingRank = {
    'white_spot': 1,
    'enamel_break': 2,
    'cavity': 3,
    'broken_black': 4,
    'abscess_sign': 5,
  };

  /// ALG-DEN-01..07 outputs synthesised from a stored [DentalExamResult].
  static List<ReadingGroup> fromDental(DentalExamResult e) {
    ToothFinding? worst;
    for (final f in e.toothFindings) {
      if (worst == null ||
          (_findingRank[f.findingCode] ?? 0) >
              (_findingRank[worst.findingCode] ?? 0)) {
        worst = f;
      }
    }
    final changes = e.toothFindings
        .map((f) => f.changeVsPrevious)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    const den = 'ALG-DEN-01..07';
    final envs = <MarkerEnvelope<dynamic>>[
      synth(
        'dental_exam.views_completed',
        value: e.viewsCompleted,
        algorithmId: 'ALG-DEN-01',
        band: e.isPartial ? SemanticBand.borderline : SemanticBand.normal,
      ),
      synth(
        'dental_exam.partial',
        value: e.isPartial,
        algorithmId: 'ALG-DEN-01',
        band: e.isPartial ? SemanticBand.borderline : SemanticBand.normal,
      ),
      synth(
        'tooth_fdi',
        value: e.toothFindings.map((f) => f.toothFdi).toList(),
        algorithmId: 'ALG-DEN-02',
        band: e.toothFindings.isEmpty ? SemanticBand.normal : e.cariesRiskBand,
      ),
      if (worst != null) ...[
        synth(
          'finding_code',
          value: worst.findingCode,
          algorithmId: 'ALG-DEN-03',
          band: worst.band,
        ),
        synth(
          'finding_prob',
          value: worst.probability,
          algorithmId: 'ALG-DEN-03',
          band: worst.band,
        ),
      ] else
        synth(
          'finding_code',
          value: 'none',
          algorithmId: 'ALG-DEN-03',
          band: SemanticBand.normal,
        ),
      synth(
        'GUM_INFLAM_BAND',
        value: bandCode(e.gumInflammationBand),
        algorithmId: 'ALG-DEN-04',
        band: e.gumInflammationBand,
        status: e.gumInflammationBand == SemanticBand.notAssessed
            ? MarkerDisplayStatus.notAssessed
            : MarkerDisplayStatus.bandOnly,
      ),
      synth(
        'PLAQUE_BAND',
        value: bandCode(e.plaqueBand),
        algorithmId: 'ALG-DEN-04',
        band: e.plaqueBand,
        status: e.plaqueBand == SemanticBand.notAssessed
            ? MarkerDisplayStatus.notAssessed
            : MarkerDisplayStatus.bandOnly,
      ),
      synth(
        'sealant_needed_teeth',
        value: e.sealantNeededTeethFdi,
        algorithmId: 'ALG-DEN-05',
        band: e.sealantNeededTeethFdi.isEmpty
            ? SemanticBand.normal
            : SemanticBand.borderline,
      ),
      synth(
        'caries_risk_level',
        value: bandCode(e.cariesRiskBand),
        algorithmId: 'ALG-DEN-06',
        band: e.cariesRiskBand,
        status: MarkerDisplayStatus.bandOnly,
        reason: e.cariesRiskReason,
      ),
      if (changes.isNotEmpty)
        synth(
          'change_vs_previous',
          value: changes.join(' · '),
          algorithmId: 'ALG-DEN-07',
          band: changes.any((c) => c.toLowerCase().startsWith('progress'))
              ? SemanticBand.high
              : changes.any((c) => c.toLowerCase().startsWith('new'))
              ? SemanticBand.borderline
              : SemanticBand.normal,
        ),
    ];
    return fromEnvelopes(envs, [MarkerCatalogue.card(den)!]);
  }

  /// History (S-R01 generic): cards inferred from the record's markers.
  static List<ReadingGroup> fromRecord(ScreeningSessionRecord rec) {
    final ids = <String>[];
    for (final m in rec.markers) {
      final c =
          MarkerCatalogue.cardOf(m.code) ?? MarkerCatalogue.card(m.algorithmId);
      if (c != null && !ids.contains(c.id)) ids.add(c.id);
    }
    return fromEnvelopes(
      rec.markers,
      MarkerCatalogue.cardsFor(ids),
      dropEmptyCards: true,
    );
  }

  /// Movement test (S-H01..S-H05): the protocol's card plus ALG-MOV-13.
  static List<ReadingGroup> fromMovement(MovementSessionResult r) {
    final cards = MarkerCatalogue.cardsFor([
      r.protocol.algorithmId,
      'ALG-MOV-13',
    ]);
    final pdMissing = r.pd.complete
        ? 'Not produced in this session'
        : 'Waiting for: ${r.pd.missing.join(' · ')}';
    return fromEnvelopes(
      r.markers.values,
      cards,
      missingReasons: {
        'PD_PROB': pdMissing,
        'PD_BAND': pdMissing,
        if (!r.protocol.twoSided) ...{'TAP_COUNT': 'Not part of this test'},
      },
    );
  }

  /// Vision test (S-H07..S-H10): the protocol's card (plus CAP-15 for
  /// acuity); the markers of the other MOV-11 half are explained, not blank.
  static List<ReadingGroup> fromVision(VisionSessionResult r) {
    final p = r.protocol;
    final cards = MarkerCatalogue.cardsFor([
      p.algorithmId,
      ...p.extraAlgorithmIds,
    ]);
    final missing = <String, String>{
      if (p.kind == VisionTestKind.colour)
        'AMSLER_ABNORMAL': 'Amsler grid is a separate test (S-H09)',
      if (p.kind == VisionTestKind.amsler)
        'COLOUR_PLATE_SCORE': 'Colour plates are a separate test (S-H08)',
      if (p.kind == VisionTestKind.acuity && r.quality.distanceMode == 'manual')
        'face_distance_cm':
            'Not measured — manual 40 cm prompt (G-16 fallback)',
    };
    return fromEnvelopes(
      r.markers.values,
      cards,
      missingReasons: missing,
      dropEmptyCards: true,
    );
  }

  /// Hearing screen (S-G10 → S-G11): the AUD-09 card; the other mode's
  /// marker is explained, not blank.
  static List<ReadingGroup> fromHearing(HearingSessionResult r) {
    final cards = MarkerCatalogue.cardsFor([r.protocol.algorithmId]);
    final din = r.protocol.mode == HearingMode.digitsInNoise;
    final missing = <String, String>{
      if (!din) 'DIN_SRT_DB': 'Digits-in-noise is the other mode (Mode B)',
      if (din)
        for (final ear in const ['R', 'L'])
          for (final hz in const [500, 1000, 2000, 4000])
            'HEAR_${ear}_$hz':
                'Pure-tone thresholds are the other mode (Mode A)',
    };
    return fromEnvelopes(
      r.markers.values,
      cards,
      missingReasons: missing,
      dropEmptyCards: true,
    );
  }

  /// Brain & Mind (S-G12, S-G13, S-G15, S-H06): the protocol's cards.
  static List<ReadingGroup> fromMind(MindSessionResult r) {
    final p = r.protocol;
    final cards = MarkerCatalogue.cardsFor(
      p.kind == MindKind.stroke ? ['ALG-MOV-06..09'] : p.algorithmIds,
    );
    final missing = <String, String>{
      if (p.kind == MindKind.cognitive)
        'COG_BAND': 'Band only when the classifier is released (G-24)',
      if (p.kind == MindKind.mood)
        'MOOD_VOICE_SCORE':
            'Recorded, not used until voice adds ≥ 0.03 AUC (G-24)',
      if (p.kind == MindKind.hfVoice && r.hfBuilding) ...{
        'HF_VOICE_DEV':
            'Building personal voice baseline (Day ${r.hfBaselineDay ?? '—'} of 14)',
        'HF_ALERT': 'No alerts until the 14-day baseline is complete (G-28)',
      },
    };
    return fromEnvelopes(
      r.markers.values,
      cards,
      missingReasons: missing,
      dropEmptyCards: true,
    );
  }

  /// Breathing & Voice (S-G02..S-G06): the protocol's cards; the FRM-13
  /// card is trimmed to its spirometry outputs.
  static List<ReadingGroup> fromBreath(BreathSessionResult r) {
    final p = r.protocol;
    final cards = <AlgorithmCard>[];
    for (final id in p.algorithmIds) {
      final c = MarkerCatalogue.card(id);
      if (c == null) continue;
      if (id == 'ALG-FRM-13') {
        cards.add(
          AlgorithmCard(
            id: c.id,
            title: 'Predicted lung values (GLI-2012)',
            specRef: c.specRef,
            classification: c.classification,
            purpose: 'FEV1 and FVC % predicted and the FEV1/FVC lower limit.',
            failureRule: c.failureRule,
            uiScreens: c.uiScreens,
            outputs: [
              for (final o in c.outputs)
                if (const {
                  'fev1_pred_pct',
                  'fvc_pred_pct',
                  'ratio_lln',
                }.contains(o.code))
                  o,
            ],
          ),
        );
      } else {
        cards.add(c);
      }
    }
    final missing = <String, String>{
      if (p.kind == BreathKind.coughTb)
        'TB_PROB': 'Number not member-facing until study AUD-TB-01 (G-24)',
      if (p.kind == BreathKind.airway) ...{
        'OAD_PROB': 'Number shown after study AUD-OAD-01 (G-24)',
        'ASTHMA_VS_COPD_PROB': 'Display policy open in the document',
      },
    };
    return fromEnvelopes(
      r.markers.values,
      cards,
      missingReasons: missing,
      dropEmptyCards: true,
    );
  }

  /// Overnight sleep (S-G09): the AUD-07 and AUD-08 cards; a night under
  /// 4 h carries the E-AUD-003 reason on the apnoea outputs.
  static List<ReadingGroup> fromSleep(SleepSessionResult r) {
    final cards = MarkerCatalogue.cardsFor(r.protocol.algorithmIds);
    final missing = <String, String>{
      if (r.partial) ...{
        'AHI_EST':
            'Insufficient valid sleep time (< 4 h) — please repeat overnight session',
        'OSA_BAND':
            'Insufficient valid sleep time (< 4 h) — please repeat overnight session',
        'APNOEA_EVENTS': 'Not counted — valid sleep under 4 h',
        'HYPOPNOEA_EVENTS': 'Not counted — valid sleep under 4 h',
      },
      if (r.isNotAssessed)
        'SONAR_RR': 'No epoch with a clear chest echo (G-30 placement)',
    };
    return fromEnvelopes(
      r.markers.values,
      cards,
      missingReasons: missing,
      dropEmptyCards: false,
    );
  }

  /// Demo suites (audio / movement): plain values keyed by spec code.
  static List<ReadingGroup> fromValues(
    Map<String, Object?> values,
    List<String> cardIds, {
    Map<String, SemanticBand> bands = const {},
    String missingReason = 'Not measured in this demo',
  }) {
    final envs = <MarkerEnvelope<dynamic>>[
      for (final entry in values.entries)
        if (entry.value != null)
          synth(
            entry.key,
            value: entry.value,
            algorithmId:
                MarkerCatalogue.byCode(entry.key)?.algorithmId ?? 'APP',
            band: bands[entry.key] ?? SemanticBand.normal,
            status: MarkerCatalogue.byCode(entry.key)?.kind == MarkerKind.band
                ? MarkerDisplayStatus.bandOnly
                : MarkerDisplayStatus.ok,
          ),
    ];
    final cards = MarkerCatalogue.cardsFor(cardIds);
    final reasons = <String, String>{
      for (final c in cards)
        for (final o in c.outputs)
          if (o.missingReason == null) o.code: missingReason,
    };
    return fromEnvelopes(envs, cards, missingReasons: reasons);
  }
}
