// Pure-Dart engines for the vision tests (Doc 09 §9 ALG-MOV-10..12,
// ALG-CAP-15). No Flutter imports; unit-tested in test/vision_engines_test.
import 'dart:math' as math;

import '../entities/vision_protocol.dart';

// ---------------------------------------------------------------------------
// ALG-CAP-15 — face distance (document: iris 11.7 mm; stand-in: IPD 63 mm)
// ---------------------------------------------------------------------------

class FaceDistance {
  FaceDistance._();

  /// Document constant (iris) — kept for when iris landmarks are available.
  static const double irisDiameterMm = 11.7;

  /// Stand-in [DER]: mean adult inter-pupillary distance.
  static const double ipdMm = 63.0;

  static const double targetCm = 40.0;
  static const double toleranceCm = 5.0;
  static bool inRange(double cm) =>
      cm >= targetCm - toleranceCm && cm <= targetCm + toleranceCm;

  /// Pinhole model: distance = real size × focal length (px) ÷ size in px.
  static double distanceCm({
    required double featurePx,
    required double focalPx,
    double featureMm = ipdMm,
  }) {
    if (featurePx <= 0 || focalPx <= 0) return 0;
    return featureMm / 10 * focalPx / featurePx;
  }

  /// Focal length from a known distance (one-time calibration).
  static double focalPxFromCalibration({
    required double featurePx,
    required double knownDistanceCm,
    double featureMm = ipdMm,
  }) => featurePx * knownDistanceCm * 10 / featureMm;

  /// Focal length guess from a typical selfie-camera field of view [DER].
  static double focalPxFromFov(double frameWidthPx, {double hfovDeg = 70}) =>
      (frameWidthPx / 2) / math.tan(hfovDeg / 2 * math.pi / 180);
}

// ---------------------------------------------------------------------------
// ALG-MOV-10 — tumbling-E optotype geometry and staircase
// ---------------------------------------------------------------------------

class Optotype {
  Optotype._();

  static const double minLogMar = -0.3;
  static const double maxLogMar = 1.3;
  static const double startLogMar = 1.0;
  static const double stepLogMar = 0.1;
  static const double normalMaxLogMar = 0.2;

  /// Letter height in mm (5 arcmin at logMAR 0.0):
  /// h = 2 · d · tan(5 · 10^logMAR / 120 °)  (Spec §9 MOV-10).
  static double heightMm(double logMar, double distanceCm) {
    final deg = 5 * math.pow(10, logMar) / 120;
    return 2 * distanceCm * 10 * math.tan(deg * math.pi / 180);
  }

  static double heightPx(double logMar, double distanceCm, double dpi) =>
      heightMm(logMar, distanceCm) / 25.4 * dpi;

  /// Stroke (and gap) = height ÷ 5.
  static double strokePx(double logMar, double distanceCm, double dpi) =>
      heightPx(logMar, distanceCm, dpi) / 5;

  /// Snellen 6/x equivalent [DER].
  static String snellen(double logMar) {
    final x = 6 * math.pow(10, logMar);
    final r = x.round();
    return (x - r).abs() < 0.05 ? '6/$r' : '6/${x.toStringAsFixed(1)}';
  }

  static double roundLevel(double v) => (v * 10).round() / 10;
}

enum EDirection { up, right, down, left }

class AcuityTrial {
  const AcuityTrial({
    required this.logMar,
    required this.shown,
    required this.answered,
    required this.correct,
    required this.distanceCm,
    required this.distanceInRange,
  });

  final double logMar;
  final EDirection shown;
  final EDirection? answered;
  final bool correct;
  final double distanceCm;
  final bool distanceInRange;
}

/// Adaptive staircase [DER rule]: start at logMAR 1.0; each level is shown
/// up to 3 times — 2 correct → one step smaller, 2 wrong → one step larger.
/// A reversal is a change of direction; the run ends at the second reversal
/// (or at the floor), and the threshold is the smallest level passed with
/// 2 of 3 correct. Random orientations never repeat 3× in a row.
class TumblingEStaircase {
  TumblingEStaircase({
    double start = Optotype.startLogMar,
    this.floor = Optotype.minLogMar,
    int seed = 11,
  }) : level = Optotype.roundLevel(start),
       _rng = math.Random(seed);

  final double floor;
  final math.Random _rng;
  double level;
  final List<AcuityTrial> trials = [];
  int _correctAtLevel = 0;
  int _wrongAtLevel = 0;
  int? _lastDirection; // -1 smaller, +1 larger
  int _reversals = 0;
  double? _bestPassed;
  bool done = false;
  EDirection? _current;
  final List<EDirection> _recent = [];

  /// Levels passed (2 of 3) so far — smallest is the threshold.
  double? get thresholdLogMar =>
      _bestPassed ?? (done && trials.isNotEmpty ? trials.first.logMar : null);

  int get reversals => _reversals;

  /// Next orientation to show (stable until [answer] is called).
  EDirection next() {
    if (_current != null) return _current!;
    EDirection d;
    do {
      d = EDirection.values[_rng.nextInt(4)];
    } while (_recent.length >= 2 &&
        _recent[_recent.length - 1] == d &&
        _recent[_recent.length - 2] == d);
    _recent.add(d);
    _current = d;
    return d;
  }

  /// Record the member's answer for the current optotype.
  void answer(EDirection? a, {double distanceCm = 40, bool inRange = true}) {
    if (done) return;
    final shown = next();
    final correct = a == shown;
    trials.add(
      AcuityTrial(
        logMar: level,
        shown: shown,
        answered: a,
        correct: correct,
        distanceCm: distanceCm,
        distanceInRange: inRange,
      ),
    );
    _current = null;
    if (correct) {
      _correctAtLevel++;
    } else {
      _wrongAtLevel++;
    }
    if (_correctAtLevel >= 2) {
      _bestPassed = _bestPassed == null ? level : math.min(_bestPassed!, level);
      _move(-1);
    } else if (_wrongAtLevel >= 2) {
      _move(1);
    }
  }

  void _move(int dir) {
    if (_lastDirection != null && _lastDirection != dir) _reversals++;
    _lastDirection = dir;
    _correctAtLevel = 0;
    _wrongAtLevel = 0;
    if (_reversals >= 2) {
      done = true;
      return;
    }
    final nextLevel = Optotype.roundLevel(level + dir * Optotype.stepLogMar);
    if (nextLevel < floor) {
      done = true;
      return;
    }
    if (nextLevel > Optotype.maxLogMar) {
      // Could not read the largest letter twice: record as the ceiling.
      done = true;
      _bestPassed ??= Optotype.maxLogMar;
      return;
    }
    level = nextLevel;
  }

  /// Approximate trials left for the progress line.
  int get estimatedTotal => math.max(trials.length + 4, 14);
}

// ---------------------------------------------------------------------------
// ALG-MOV-11 — colour plates (drawn in-app [DER]) and Amsler grid
// ---------------------------------------------------------------------------

/// A 2-D point in glyph / plate-local space (no dart:ui here).
typedef Pt = ({double x, double y});

/// Rounded numerals 1–9 as stroke centre-lines in a unit box
/// (width [boxWidth] × height 1, y down). A point is inside the numeral when
/// its distance to the nearest centre-line is below [halfWidth]; that gives
/// round caps and joins for free and lets the plate layout size every dot so
/// it never crosses the outline (what makes real pseudoisochromatic plates
/// crisp).
class DigitGlyph {
  DigitGlyph._(this.digit, List<List<Pt>> raw) : strokes = _centre(raw);

  final int digit;
  final List<List<Pt>> strokes;

  static const double boxWidth = 0.62;
  static const double halfWidth = 0.105;

  static final Map<int, DigitGlyph> _cache = {};

  static DigitGlyph of(int digit) =>
      _cache.putIfAbsent(digit, () => DigitGlyph._(digit, _raw(digit)));

  /// Signed distance in box units (negative inside the stroke).
  double signedDistance(double x, double y) {
    var best = double.infinity;
    for (final s in strokes) {
      for (var i = 0; i + 1 < s.length; i++) {
        final d = _segDist(x, y, s[i], s[i + 1]);
        if (d < best) best = d;
      }
    }
    return best - halfWidth;
  }

  /// Signed distance for a plate-local point (−1..1, plate radius = 1) with
  /// the numeral centred and [height] tall (in radii).
  double plateSignedDistance(double lx, double ly, {double height = 1.05}) {
    final bx = lx / height + boxWidth / 2;
    final by = ly / height + 0.5;
    return signedDistance(bx, by) * height;
  }

  /// Share of the unit box covered by the stroke (Monte-Carlo, for tests).
  double areaShare({int n = 4000}) {
    var inside = 0;
    final rng = math.Random(1);
    for (var i = 0; i < n; i++) {
      if (signedDistance(rng.nextDouble() * boxWidth, rng.nextDouble()) < 0) {
        inside++;
      }
    }
    return inside / n;
  }

  static double _segDist(double px, double py, Pt a, Pt b) {
    final vx = b.x - a.x, vy = b.y - a.y;
    final wx = px - a.x, wy = py - a.y;
    final len2 = vx * vx + vy * vy;
    var t = len2 == 0 ? 0.0 : (wx * vx + wy * vy) / len2;
    t = t.clamp(0.0, 1.0);
    final dx = px - (a.x + t * vx), dy = py - (a.y + t * vy);
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Shift the strokes so the glyph's ink box is centred in the unit box.
  static List<List<Pt>> _centre(List<List<Pt>> raw) {
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final s in raw) {
      for (final p in s) {
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
    }
    final dx = boxWidth / 2 - (minX + maxX) / 2;
    final dy = 0.5 - (minY + maxY) / 2;
    return [
      for (final s in raw) [for (final p in s) (x: p.x + dx, y: p.y + dy)],
    ];
  }

  static List<Pt> _arc(
    double cx,
    double cy,
    double r,
    double a0Deg,
    double a1Deg, {
    int n = 24,
  }) {
    final out = <Pt>[];
    for (var i = 0; i <= n; i++) {
      final a = (a0Deg + (a1Deg - a0Deg) * i / n) * math.pi / 180;
      out.add((x: cx + r * math.cos(a), y: cy + r * math.sin(a)));
    }
    return out;
  }

  static List<Pt> _bez(Pt p0, Pt c, Pt p1, {int n = 20}) {
    final out = <Pt>[];
    for (var i = 0; i <= n; i++) {
      final t = i / n, u = 1 - t;
      out.add((
        x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
        y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y,
      ));
    }
    return out;
  }

  // Centre-lines inside a 0.62 × 1.0 box, stroke margin ≈ 0.11 each side.
  static List<List<Pt>> _raw(int d) {
    const top = 0.12, bot = 0.88;
    switch (d) {
      case 1:
        return [
          [(x: 0.14, y: 0.30), (x: 0.34, y: top), (x: 0.34, y: bot)],
        ];
      case 2:
        return [
          [
            ..._arc(0.31, 0.33, 0.20, 190, 395),
            (x: 0.11, y: bot),
            (x: 0.53, y: bot),
          ],
        ];
      case 3:
        return [
          _arc(0.30, 0.31, 0.19, 200, 450),
          _arc(0.30, 0.70, 0.19, 270, 520),
        ];
      case 4:
        return [
          [(x: 0.44, y: top), (x: 0.08, y: 0.64), (x: 0.56, y: 0.64)],
          [(x: 0.44, y: top), (x: 0.44, y: bot)],
        ];
      case 5:
        return [
          [
            (x: 0.52, y: top),
            (x: 0.14, y: top),
            (x: 0.11, y: 0.47),
            ..._arc(0.30, 0.67, 0.22, 250, 530),
          ],
        ];
      case 6:
        return [
          _bez((x: 0.48, y: top), (x: 0.08, y: 0.18), (x: 0.09, y: 0.68)),
          _arc(0.31, 0.68, 0.22, 180, 540),
        ];
      case 7:
        return [
          [(x: 0.10, y: top), (x: 0.54, y: top), (x: 0.24, y: bot)],
        ];
      case 8:
        return [
          _arc(0.31, 0.31, 0.18, 90, 450),
          _arc(0.31, 0.69, 0.21, 270, 630),
        ];
      case 9:
        return [
          _arc(0.31, 0.33, 0.22, 0, 360),
          _bez((x: 0.53, y: 0.33), (x: 0.54, y: 0.84), (x: 0.14, y: bot)),
        ];
      default:
        return [_arc(0.31, 0.5, 0.25, 0, 360)];
    }
  }
}

/// Plate families, like the types of a printed Ishihara set.
enum PlateType {
  /// Orange numeral on yellow-green ground.
  a,

  /// Red-brown numeral on olive-grey ground.
  b,

  /// Salmon-pink numeral on grey-green ground.
  c,

  /// Control: dark slate numeral on light cream (hue AND lightness differ).
  control;

  String get label => switch (this) {
    PlateType.a => 'A orange / green',
    PlateType.b => 'B red-brown / olive',
    PlateType.c => 'C pink / grey-green',
    PlateType.control => 'control',
  };
}

/// sRGB helpers (pure Dart; the UI layer wraps the ints in Color).
class PlateColours {
  PlateColours._();

  static int hsl(double hDeg, double s, double l) {
    final h = ((hDeg % 360) + 360) % 360 / 360;
    double f(double n) {
      final k = (n + h * 12) % 12;
      final a = s * math.min(l, 1 - l);
      return l - a * math.max(-1, math.min(k - 3, math.min(9 - k, 1)));
    }

    int c(double v) => (v * 255).round().clamp(0, 255);
    return 0xFF000000 | (c(f(0)) << 16) | (c(f(8)) << 8) | c(f(4));
  }

  static double _lin(int c) {
    final v = c / 255;
    return v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  /// WCAG relative luminance 0..1.
  static double luminance(int argb) =>
      0.2126 * _lin((argb >> 16) & 0xFF) +
      0.7152 * _lin((argb >> 8) & 0xFF) +
      0.0722 * _lin(argb & 0xFF);

  /// Colour of the given hue / saturation whose luminance equals [targetY]
  /// (lightness is bisected; luminance rises monotonically with it).
  static int matched(double hueDeg, double sat, double targetY) {
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 28; i++) {
      final mid = (lo + hi) / 2;
      if (luminance(hsl(hueDeg, sat, mid)) < targetY) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return hsl(hueDeg, sat, (lo + hi) / 2);
  }

  /// One palette level per target luminance: `[level][hue]`.
  static List<List<int>> levels(
    List<double> hues,
    double sat,
    List<double> targetsY,
  ) => [
    for (final y in targetsY) [for (final h in hues) matched(h, sat, y)],
  ];

  /// Shared lightness levels for the screening plates so brightness carries
  /// no information.
  static const List<double> screeningY = [0.26, 0.38, 0.52];

  static final Map<PlateType, (List<List<int>>, List<List<int>>)> families = {
    PlateType.a: (
      levels(const [12, 20, 28], 0.84, screeningY),
      levels(const [76, 86, 96], 0.55, screeningY),
    ),
    PlateType.b: (
      levels(const [4, 10, 16], 0.58, screeningY),
      levels(const [60, 70, 80], 0.32, screeningY),
    ),
    PlateType.c: (
      levels(const [350, 358, 6], 0.62, screeningY),
      levels(const [100, 115, 130], 0.36, screeningY),
    ),
    PlateType.control: (
      levels(const [218, 224, 230], 0.38, const [0.10, 0.14, 0.19]),
      levels(const [44, 50, 56], 0.55, const [0.70, 0.76, 0.82]),
    ),
  };
}

/// A pseudoisochromatic plate: a numeral drawn with dots of one hue family
/// over dots of a confusion family at the same three lightness levels.
class ColourPlate {
  const ColourPlate({
    required this.index,
    required this.digit,
    required this.type,
    required this.seed,
  });

  final int index;
  final int digit;
  final PlateType type;
  final int seed;

  bool get isControl => type == PlateType.control;

  /// `[level][hue]` ARGB ints.
  List<List<int>> get figureLevels => PlateColours.families[type]!.$1;
  List<List<int>> get groundLevels => PlateColours.families[type]!.$2;
}

class ColourPlateSet {
  ColourPlateSet._(this.plates);

  final List<ColourPlate> plates;

  static const int count = 12;
  static const int controlCount = 2;
  static int get screeningCount => count - controlCount;

  /// 12 plates: #1 and #7 are control plates [DER]. The ten screening plates
  /// cycle types A/B/C and show every digit 1–9 at least once; no digit is
  /// repeated back to back.
  static ColourPlateSet generate({int seed = 7}) {
    final rng = math.Random(seed);
    final pool = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(rng);
    final screening = [...pool];
    var extra = rng.nextInt(9) + 1;
    while (extra == screening.last) {
      extra = rng.nextInt(9) + 1;
    }
    screening.add(extra);
    final digits = <int>[];
    var k = 0;
    for (var i = 0; i < count; i++) {
      if (i == 0 || i == 6) {
        // control digit: distinct from its neighbours
        var d = rng.nextInt(9) + 1;
        final next = k < screening.length ? screening[k] : -1;
        final prev = digits.isEmpty ? -1 : digits.last;
        while (d == next || d == prev) {
          d = rng.nextInt(9) + 1;
        }
        digits.add(d);
      } else {
        digits.add(screening[k++]);
      }
    }
    final types = [PlateType.a, PlateType.b, PlateType.c];
    final plates = <ColourPlate>[];
    var s = 0;
    for (var i = 0; i < count; i++) {
      final control = i == 0 || i == 6;
      plates.add(
        ColourPlate(
          index: i,
          digit: digits[i],
          type: control ? PlateType.control : types[(s++) % types.length],
          seed: seed * 100 + i,
        ),
      );
    }
    return ColourPlateSet._(plates);
  }
}

class ColourPlateAnswer {
  const ColourPlateAnswer({
    required this.plateIndex,
    required this.answered,
    this.responseMs,
  });

  final int plateIndex;

  /// 1–9, or null for "I see nothing".
  final int? answered;

  /// Time from plate shown to answer, when known.
  final double? responseMs;
}

/// One plate after the test: the revealed number against the answer.
class PlateReviewItem {
  const PlateReviewItem({
    required this.plate,
    required this.answered,
    required this.correct,
    this.responseMs,
  });

  final ColourPlate plate;
  final int? answered;
  final bool correct;
  final double? responseMs;

  int get index => plate.index;
  int get digit => plate.digit;
  bool get isControl => plate.isControl;
}

class ColourPlateResult {
  const ColourPlateResult({
    required this.score,
    required this.total,
    required this.controlFailed,
    required this.screeningMisses,
    required this.screeningCorrect,
    required this.screeningTotal,
    required this.controlCorrect,
    required this.controlTotal,
    required this.answered,
    required this.review,
    this.medianResponseMs,
  });

  final int score;
  final int total;

  /// A control plate was misread: screen too dim / filter on / not attended.
  final bool controlFailed;

  /// Red–green screening plates missed.
  final int screeningMisses;
  final int screeningCorrect;
  final int screeningTotal;
  final int controlCorrect;
  final int controlTotal;
  final int answered;
  final List<PlateReviewItem> review;
  final double? medianResponseMs;

  bool get allCorrect => score == total;

  /// [DER] screening line: 3 or more red–green plates missed.
  bool get likelyRedGreen => screeningMisses >= 3;

  List<PlateReviewItem> get missed => review.where((r) => !r.correct).toList();
}

class ColourPlateScorer {
  ColourPlateScorer._();

  static ColourPlateResult score(
    ColourPlateSet set,
    List<ColourPlateAnswer> answers,
  ) {
    var score = 0;
    var misses = 0;
    var controlFailed = false;
    var screeningCorrect = 0, screeningTotal = 0;
    var controlCorrect = 0, controlTotal = 0;
    final byIndex = {for (final a in answers) a.plateIndex: a};
    final review = <PlateReviewItem>[];
    final times = <double>[];
    for (final p in set.plates) {
      final a = byIndex[p.index];
      final ok = a != null && a.answered == p.digit;
      if (a?.responseMs != null) times.add(a!.responseMs!);
      review.add(
        PlateReviewItem(
          plate: p,
          answered: a?.answered,
          correct: ok,
          responseMs: a?.responseMs,
        ),
      );
      if (p.isControl) {
        controlTotal++;
      } else {
        screeningTotal++;
      }
      if (ok) {
        score++;
        if (p.isControl) {
          controlCorrect++;
        } else {
          screeningCorrect++;
        }
      } else if (p.isControl) {
        controlFailed = true;
      } else {
        misses++;
      }
    }
    return ColourPlateResult(
      score: score,
      total: set.plates.length,
      controlFailed: controlFailed,
      screeningMisses: misses,
      screeningCorrect: screeningCorrect,
      screeningTotal: screeningTotal,
      controlCorrect: controlCorrect,
      controlTotal: controlTotal,
      answered: answers.length,
      review: review,
      medianResponseMs: times.isEmpty
          ? null
          : ReactionTimeAnalyzer.median(times),
    );
  }
}

/// One dot of a plate mosaic, in pixels from the plate centre.
class PlateDot {
  const PlateDot(this.x, this.y, this.r, this.argb, this.figure);
  final double x, y, r;
  final int argb;
  final bool figure;
}

/// Edge-aware dot packing for a plate at a given pixel radius. Dots are
/// placed large → small with a spatial hash; a dot near the numeral outline
/// is shrunk so it sits wholly on one side, so the outline stays crisp and
/// only hue separates figure from ground.
class PlateDotLayout {
  PlateDotLayout._(this.radius, this.dots, this.coverage);

  final double radius;
  final List<PlateDot> dots;

  /// Share of the disc covered by dots.
  final double coverage;

  static final Map<String, PlateDotLayout> _cache = {};

  static PlateDotLayout of(ColourPlate plate, double radiusPx) {
    final key = '${plate.seed}@${radiusPx.round()}';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 40) _cache.remove(_cache.keys.first);
    return _cache[key] = build(plate, radiusPx);
  }

  static const List<double> sizeClasses = [0.052, 0.036, 0.022, 0.014];
  static const List<int> attemptBudget = [2600, 5200, 10000, 16000];

  static PlateDotLayout build(ColourPlate plate, double r) {
    final rng = math.Random(plate.seed);
    final glyph = DigitGlyph.of(plate.digit);
    final gap = math.max(0.6, r * 0.004);
    final minRad = r * 0.010;
    final cell = 2 * sizeClasses.first * r + gap;
    final cols = (2 * r / cell).ceil() + 2;
    final grid = <int, List<int>>{};
    final xs = <double>[], ys = <double>[], rs = <double>[];
    final dots = <PlateDot>[];
    int cellKey(double x, double y) =>
        ((y + r) / cell).floor() * cols + ((x + r) / cell).floor();
    var area = 0.0;
    for (var c = 0; c < sizeClasses.length; c++) {
      final base = sizeClasses[c] * r;
      for (var attempt = 0; attempt < attemptBudget[c]; attempt++) {
        var rad = base * (0.82 + rng.nextDouble() * 0.36);
        final a = rng.nextDouble() * 2 * math.pi;
        final d = math.sqrt(rng.nextDouble()) * (r - rad - gap);
        final x = d * math.cos(a), y = d * math.sin(a);
        final sd = glyph.plateSignedDistance(x / r, y / r) * r;
        if (sd.abs() - gap < rad) rad = sd.abs() - gap;
        if (rad < minRad) continue;
        if (d + rad + gap > r) continue;
        var ok = true;
        final cx = ((x + r) / cell).floor(), cy = ((y + r) / cell).floor();
        for (var dy = -1; dy <= 1 && ok; dy++) {
          for (var dx = -1; dx <= 1 && ok; dx++) {
            final list = grid[(cy + dy) * cols + (cx + dx)];
            if (list == null) continue;
            for (final i in list) {
              final ddx = xs[i] - x, ddy = ys[i] - y;
              final lim = rs[i] + rad + gap;
              if (ddx * ddx + ddy * ddy < lim * lim) {
                ok = false;
                break;
              }
            }
          }
        }
        if (!ok) continue;
        final idx = xs.length;
        xs.add(x);
        ys.add(y);
        rs.add(rad);
        (grid[cellKey(x, y)] ??= []).add(idx);
        final figure = sd < 0;
        final family = figure ? plate.figureLevels : plate.groundLevels;
        final level = family[rng.nextInt(family.length)];
        final colour = level[rng.nextInt(level.length)];
        dots.add(PlateDot(x, y, rad, colour, figure));
        area += math.pi * rad * rad;
      }
    }
    return PlateDotLayout._(r, dots, area / (math.pi * r * r));
  }
}

/// Amsler grid marks for one eye: cells of a [cells] × [cells] grid.
class AmslerMarks {
  AmslerMarks({this.cells = 20, Set<int>? marked, this.declaredNormal = false})
    : marked = marked ?? <int>{};

  final int cells;

  /// Cell index = row * cells + col.
  final Set<int> marked;

  /// Member tapped "Looks normal".
  final bool declaredNormal;

  bool get abnormal => marked.isNotEmpty;

  /// Cells within the central 5° (≈ 2.6 cm of a 10 cm grid at 30 cm, i.e.
  /// the inner quarter of the grid) [DER].
  bool get centralInvolved {
    final c = cells / 2;
    final r = cells * 0.13;
    for (final i in marked) {
      final row = i ~/ cells + 0.5;
      final col = i % cells + 0.5;
      if ((row - c).abs() <= r && (col - c).abs() <= r) return true;
    }
    return false;
  }

  /// Which quadrants (as seen by the member) carry marks.
  List<String> get quadrants {
    final out = <String>{};
    final c = cells / 2;
    for (final i in marked) {
      final row = i ~/ cells;
      final col = i % cells;
      final v = row < c ? 'upper' : 'lower';
      final h = col < c ? 'left' : 'right';
      out.add('$v $h');
    }
    return out.toList()..sort();
  }

  double get markedSharePct => marked.length / (cells * cells) * 100;
}

// ---------------------------------------------------------------------------
// ALG-MOV-12 — reaction time
// ---------------------------------------------------------------------------

class ReactionTrial {
  const ReactionTrial({
    required this.block,
    required this.gapS,
    required this.latencyMs,
    required this.falseStart,
  });

  final ReactionBlock block;
  final double gapS;

  /// Milliseconds from stimulus onset to the tap (negative = before onset).
  final double latencyMs;

  /// Tap before the stimulus or under 100 ms (Spec §9: discard, replace).
  final bool falseStart;
}

class ReactionBlockResult {
  const ReactionBlockResult({
    required this.block,
    required this.medianMs,
    required this.validCount,
    required this.discarded,
    required this.latenciesMs,
  });

  final ReactionBlock block;
  final double? medianMs;
  final int validCount;
  final int discarded;
  final List<double> latenciesMs;
}

class ReactionTimeAnalyzer {
  ReactionTimeAnalyzer._();

  static const int trialsPerBlock = 10;
  static const double minValidMs = 100;
  static const double gapMinS = 1.0;
  static const double gapMaxS = 4.0;
  static const int maxFalseStartsBeforeReminder = 3;

  static ReactionBlockResult analyzeBlock(
    List<ReactionTrial> trials,
    ReactionBlock block,
  ) {
    final valid = <double>[];
    var discarded = 0;
    for (final t in trials.where((t) => t.block == block)) {
      if (t.falseStart || t.latencyMs < minValidMs) {
        discarded++;
      } else {
        valid.add(t.latencyMs);
      }
    }
    return ReactionBlockResult(
      block: block,
      medianMs: valid.isEmpty ? null : median(valid),
      validCount: valid.length,
      discarded: discarded,
      latenciesMs: valid,
    );
  }

  static double median(List<double> xs) {
    final s = List<double>.from(xs)..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }

  /// Uniform random gap in [1, 4] s.
  static double randomGapS(math.Random rng) =>
      gapMinS + rng.nextDouble() * (gapMaxS - gapMinS);
}

// ---------------------------------------------------------------------------
// Simulated observers (FLUTTER_TEST / Test Controls)
// ---------------------------------------------------------------------------

class VisionSimulated {
  VisionSimulated._();

  /// Answers correctly whenever the optotype is at or above the observer's
  /// true threshold (plus a 25 % lucky guess below it).
  static EDirection acuityAnswer(
    EDirection shown,
    double levelLogMar,
    double trueLogMar,
    math.Random rng,
  ) {
    if (levelLogMar >= trueLogMar - 1e-9 || rng.nextDouble() < 0.25) {
      return shown;
    }
    final others = EDirection.values.where((d) => d != shown).toList();
    return others[rng.nextInt(others.length)];
  }

  /// Plate answers: normal reads everything; red–green misses the screening
  /// plates (sees nothing) but reads the controls.
  static List<ColourPlateAnswer> plateAnswers(
    ColourPlateSet set, {
    required bool redGreenDeficient,
    int missEvery = 1,
  }) {
    final out = <ColourPlateAnswer>[];
    var k = 0;
    for (final p in set.plates) {
      int? a = p.digit;
      if (redGreenDeficient && !p.isControl && (k++ % missEvery == 0)) {
        a = null;
      }
      out.add(
        ColourPlateAnswer(
          plateIndex: p.index,
          answered: a,
          responseMs: 1400 + (k * 37 % 9) * 180.0,
        ),
      );
    }
    return out;
  }

  static List<ReactionTrial> reactionTrials({
    required ReactionBlock block,
    double meanMs = 250,
    int seed = 3,
    int falseStarts = 0,
  }) {
    final rng = math.Random(seed);
    final out = <ReactionTrial>[];
    for (var i = 0; i < falseStarts; i++) {
      out.add(
        ReactionTrial(block: block, gapS: 2, latencyMs: 40, falseStart: true),
      );
    }
    for (var i = 0; i < ReactionTimeAnalyzer.trialsPerBlock; i++) {
      out.add(
        ReactionTrial(
          block: block,
          gapS: ReactionTimeAnalyzer.randomGapS(rng),
          latencyMs: meanMs + (rng.nextDouble() - 0.5) * 60,
          falseStart: false,
        ),
      );
    }
    return out;
  }
}
