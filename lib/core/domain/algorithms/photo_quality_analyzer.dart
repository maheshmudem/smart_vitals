import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'capture_quality_engine.dart';

/// Which body part a still photo is supposed to show. Drives the CAP-09
/// coverage proxy, the coaching copy and the live guide overlay.
enum PhotoTarget {
  lowerEyelid('Lid visible'),
  sclera('White of eye'),
  pupilLens('Pupil found'),
  bothPupils('Both pupils'),
  fundus('Retina area'),
  skinPatch('Skin area'),
  footSole('Foot in frame'),
  lesion('Spot centred'),
  oralMucosa('Mouth lining in frame'),
  teethArch('Teeth in frame');

  const PhotoTarget(this.coverageLabel);

  /// Short label for the coverage row in review panels and result tables.
  final String coverageLabel;
}

/// On-device still-photo quality report for image screens (Spec §2, G-21).
///
/// Real pixel metrics:
/// - `blurScore`   — variance of a 3×3 Laplacian on luma (ALG-CAP-06, pass ≥ 100)
/// - `glarePct`    — % of pixels with luma ≥ 250 (ALG-CAP-07, pass ≤ 5 %)
/// - `darkPct`     — % of pixels with luma ≤ 15 (ALG-CAP-07, pass ≤ 10 %)
/// - `meanLuma`    — mean luma 0–255
///
/// Proxy metrics (no trained model on device yet — labelled as proxies in the
/// operator expander, see Spec ALG-CAP-08 / CAP-09):
/// - `lidCoveragePct` — share of ROI pixels that match the [target] colour
///   rule (pink lining, white sclera, dark pupil, …) → stands in for the
///   CAP-09 part-coverage mask. The field keeps its original name so the
///   anaemia flow is unchanged; read it through [coveragePct].
/// - `iqScore`        — 0–1 blend of the four real checks → stands in for the
///   CAP-08 MobileNetV3 image-quality classifier (pass ≥ 0.70).
///
/// Colour features kept for the eye models:
/// - `redGreenRatio`, `meanAStar` (approximate CIELab a* of the ROI, ALG-IMG-01)
/// - `meanBStar` (approximate CIELab b* of the ROI — sclera yellowness, ALG-IMG-02)
class PhotoQualityReport {
  const PhotoQualityReport({
    required this.blurScore,
    required this.glarePct,
    required this.darkPct,
    required this.meanLuma,
    required this.lidCoveragePct,
    required this.iqScore,
    required this.redGreenRatio,
    required this.meanAStar,
    this.meanBStar = 0,
    this.colourErrorDe,
    this.isSimulated = false,
    this.target = PhotoTarget.lowerEyelid,
  });

  /// Deterministic synthetic report used in widget tests and on devices
  /// without a camera (FLUTTER_TEST / desktop without webcam).
  factory PhotoQualityReport.simulated({
    required bool good,
    int seed = 0,
    PhotoTarget target = PhotoTarget.lowerEyelid,
  }) {
    final r = math.Random(seed);
    if (good) {
      return PhotoQualityReport(
        blurScore: 180 + r.nextDouble() * 160,
        glarePct: 0.4 + r.nextDouble() * 2.0,
        darkPct: 1.0 + r.nextDouble() * 3.5,
        meanLuma: 128 + r.nextDouble() * 30,
        lidCoveragePct: 86 + r.nextDouble() * 10,
        iqScore: 0.84 + r.nextDouble() * 0.12,
        redGreenRatio: 1.28 + r.nextDouble() * 0.12,
        meanAStar: 18 + r.nextDouble() * 6,
        meanBStar: 6 + r.nextDouble() * 4,
        isSimulated: true,
        target: target,
      );
    }
    // A blurry, glare-hit frame: fails CAP-06 and CAP-07.
    return PhotoQualityReport(
      blurScore: 32 + r.nextDouble() * 40,
      glarePct: 7.5 + r.nextDouble() * 6,
      darkPct: 2.0 + r.nextDouble() * 3,
      meanLuma: 150 + r.nextDouble() * 40,
      lidCoveragePct: 58 + r.nextDouble() * 15,
      iqScore: 0.38 + r.nextDouble() * 0.2,
      redGreenRatio: 1.12 + r.nextDouble() * 0.1,
      meanAStar: 11 + r.nextDouble() * 4,
      meanBStar: 4 + r.nextDouble() * 3,
      isSimulated: true,
      target: target,
    );
  }

  final double blurScore;
  final double glarePct;
  final double darkPct;
  final double meanLuma;
  final double lidCoveragePct;
  final double iqScore;
  final double redGreenRatio;
  final double meanAStar;
  final double meanBStar;

  /// ΔE after 3×3 colour correction when a 24-patch card was used (ALG-CAP-10).
  final double? colourErrorDe;
  final bool isSimulated;
  final PhotoTarget target;

  /// Target-agnostic alias for the CAP-09 coverage proxy.
  double get coveragePct => lidCoveragePct;
  String get coverageLabel => target.coverageLabel;

  bool get blurPassed => CaptureQualityEngine.checkBlurScore(blurScore);
  bool get glarePassed => glarePct <= 5.0;
  bool get darkPassed => darkPct <= 10.0;
  bool get glareAndDarkPassed => CaptureQualityEngine.checkGlareAndDark(
    glarePct: glarePct,
    darkPct: darkPct,
  );
  bool get iqPassed =>
      CaptureQualityEngine.checkImageQualityClassifier(iqScore);
  bool get coveragePassed =>
      CaptureQualityEngine.checkBodyPartCoverage(lidCoveragePct);
  bool get cardPassed =>
      colourErrorDe == null ||
      CaptureQualityEngine.checkColourCard(
        cardFound: true,
        deltaEAfterCorrection: colourErrorDe!,
      );

  bool get overallPassed =>
      blurPassed &&
      glareAndDarkPassed &&
      iqPassed &&
      coveragePassed &&
      cardPassed;

  /// Spec coaching copy for each failing check (ALG-CAP-06…10), worded for
  /// the photo [target].
  List<String> get failureReasons {
    final reasons = <String>[];
    if (!blurPassed) {
      reasons.add(switch (target) {
        PhotoTarget.fundus =>
          'Image is blurry — hold the camera steady against the eyepiece and retake.',
        PhotoTarget.bothPupils =>
          'Photo is blurry — wait until the child is still, then retake.',
        PhotoTarget.skinPatch =>
          'Photo is blurry — wait until the baby is still, tap the skin to focus and retake.',
        PhotoTarget.footSole =>
          'Photo is blurry — rest the foot, tap the sole to focus and retake.',
        PhotoTarget.lesion =>
          'Photo is blurry — tap the spot to focus, keep 10–15 cm away and retake.',
        PhotoTarget.oralMucosa =>
          'Photo is blurry — hold the phone still 10–15 cm from the mouth, tap the lining to focus and retake.',
        PhotoTarget.teethArch =>
          'Photo is blurry — keep the phone still, tap a tooth to focus and retake.',
        _ => 'Photo is blurry — tap the eye to autofocus and retake.',
      });
    }
    if (!glarePassed) {
      reasons.add(switch (target) {
        PhotoTarget.pupilLens =>
          'Flash glare covers the lens — tilt the phone slightly so the reflection moves off the pupil.',
        PhotoTarget.fundus =>
          'Bright reflection on the retina image — re-seat the eyepiece and retake.',
        PhotoTarget.skinPatch || PhotoTarget.lesion =>
          'Glare on the skin or card — move away from direct light and tilt the phone slightly.',
        PhotoTarget.footSole =>
          'Glare on the sole or card — tilt the phone and avoid a lamp shining straight at the foot.',
        PhotoTarget.oralMucosa =>
          'Flash glare on wet lining — dab the area dry with gauze, tilt the phone a little and retake.',
        PhotoTarget.teethArch =>
          'Flash glare on the teeth — dry them with a tissue, tilt the phone a little and retake.',
        _ => 'Too much glare on the eye — tilt the phone slightly.',
      });
    }
    if (!darkPassed) {
      reasons.add(switch (target) {
        PhotoTarget.fundus =>
          'Retina image too dark — the pupil may be small; wait a few minutes in the dark room and retake.',
        PhotoTarget.bothPupils || PhotoTarget.pupilLens =>
          'Photo is too dark — make sure the flash fired and the lens is not covered.',
        PhotoTarget.footSole =>
          'Photo is too dark or shadowed — move to brighter light so the whole sole is lit evenly.',
        PhotoTarget.skinPatch || PhotoTarget.lesion =>
          'Photo is too dark — move closer to a window; your own shadow must not fall on the skin.',
        PhotoTarget.oralMucosa || PhotoTarget.teethArch =>
          'Photo is too dark — keep the torch on, open wider and move the phone a little closer.',
        _ => 'Photo is too dark — find more light or move closer.',
      });
    }
    if (!coveragePassed) {
      reasons.add(switch (target) {
        PhotoTarget.lowerEyelid =>
          'Show the whole lower eyelid — pull the lid down a little more.',
        PhotoTarget.sclera =>
          'Show more of the white of the eye — look further in the asked direction and keep the lids open.',
        PhotoTarget.pupilLens =>
          'Centre the pupil in the ring — move a little closer and dim the room so the pupil is larger.',
        PhotoTarget.bothPupils =>
          'Both eyes must be in the frame — hold the phone at the child\'s eye level, 0.5–1 m away.',
        PhotoTarget.fundus =>
          'Retina not visible — ask the person to look at the green light and hold the eyepiece steady.',
        PhotoTarget.skinPatch =>
          'Keep bare skin and the card together in the frame — move the clothing away and fill the guide with skin.',
        PhotoTarget.footSole =>
          'Show the whole sole from toes to heel — move the phone back a little and keep the card beside the foot.',
        PhotoTarget.lesion =>
          'Centre the spot in the ring, 10–15 cm away, with normal skin around it and no shadow.',
        PhotoTarget.oralMucosa =>
          'Open wider and pull the cheek out — the mouth lining must fill the guide with no lips or teeth in the way.',
        PhotoTarget.teethArch =>
          'Show all the teeth from one side to the other — pull the lips back and keep the whole row inside the guide.',
      });
    }
    if (!iqPassed && blurPassed && glareAndDarkPassed && coveragePassed) {
      reasons.add('Image quality is low — hold still and retake.');
    }
    if (!cardPassed) {
      reasons.add(
        'Colour card not read clearly — lay it flat, fully inside the frame and free of glare.',
      );
    }
    return reasons;
  }

  /// Aggregate 0–1 capture-quality score fed into ALG-RSK-06 result confidence.
  double get qualityScore {
    final blurPart = (blurScore / 300.0).clamp(0.0, 1.0);
    final glarePart = (1.0 - glarePct / 20.0).clamp(0.0, 1.0);
    final darkPart = (1.0 - darkPct / 40.0).clamp(0.0, 1.0);
    final covPart = (lidCoveragePct / 100.0).clamp(0.0, 1.0);
    final cardPart = colourErrorDe == null
        ? 0.92
        : (1.0 - (colourErrorDe! / 10.0)).clamp(0.0, 1.0);
    return (0.30 * blurPart +
            0.20 * glarePart +
            0.15 * darkPart +
            0.25 * covPart +
            0.10 * cardPart)
        .clamp(0.0, 1.0);
  }

  PhotoQualityReport withColourCard(double deltaE) => PhotoQualityReport(
    blurScore: blurScore,
    glarePct: glarePct,
    darkPct: darkPct,
    meanLuma: meanLuma,
    lidCoveragePct: lidCoveragePct,
    iqScore: iqScore,
    redGreenRatio: redGreenRatio,
    meanAStar: meanAStar,
    meanBStar: meanBStar,
    colourErrorDe: deltaE,
    isSimulated: isSimulated,
    target: target,
  );
}

/// Default fractional ROI per target (0..1 of width / height).
ui.Rect defaultRoiFor(PhotoTarget target) => switch (target) {
  PhotoTarget.lowerEyelid => const ui.Rect.fromLTWH(0.20, 0.30, 0.60, 0.40),
  PhotoTarget.sclera => const ui.Rect.fromLTWH(0.18, 0.32, 0.64, 0.36),
  PhotoTarget.pupilLens => const ui.Rect.fromLTWH(0.34, 0.34, 0.32, 0.32),
  PhotoTarget.bothPupils => const ui.Rect.fromLTWH(0.10, 0.30, 0.80, 0.40),
  PhotoTarget.fundus => const ui.Rect.fromLTWH(0.20, 0.20, 0.60, 0.60),
  PhotoTarget.skinPatch => const ui.Rect.fromLTWH(0.12, 0.30, 0.46, 0.40),
  PhotoTarget.footSole => const ui.Rect.fromLTWH(0.18, 0.12, 0.54, 0.76),
  PhotoTarget.lesion => const ui.Rect.fromLTWH(0.36, 0.36, 0.28, 0.28),
  PhotoTarget.oralMucosa => const ui.Rect.fromLTWH(0.20, 0.26, 0.60, 0.44),
  PhotoTarget.teethArch => const ui.Rect.fromLTWH(0.12, 0.28, 0.76, 0.40),
};

/// Pure-Dart analysis of an RGBA buffer (4 bytes / pixel, row-major).
///
/// `roi` is a fractional rectangle (0..1 of width/height) used for the
/// coverage and colour features; the blur / glare / dark checks run on the
/// whole frame. Keep the input ≤ ~320 px wide for speed (see
/// [analyzeEncodedPhoto], which downsamples when decoding).
PhotoQualityReport analyzeRgba(
  Uint8List rgba,
  int width,
  int height, {
  ui.Rect? roi,
  PhotoTarget target = PhotoTarget.lowerEyelid,
}) {
  final region = roi ?? defaultRoiFor(target);
  if (width < 3 || height < 3 || rgba.length < width * height * 4) {
    return PhotoQualityReport(
      blurScore: 0,
      glarePct: 100,
      darkPct: 100,
      meanLuma: 0,
      lidCoveragePct: 0,
      iqScore: 0,
      redGreenRatio: 1,
      meanAStar: 0,
      target: target,
    );
  }

  // 1. Luma plane + glare / dark counts.
  final luma = Float32List(width * height);
  int glare = 0;
  int dark = 0;
  double lumaSum = 0;
  double rgSum = 0;
  for (int i = 0, p = 0; i < width * height; i++, p += 4) {
    final r = rgba[p];
    final g = rgba[p + 1];
    final b = rgba[p + 2];
    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    luma[i] = y;
    lumaSum += y;
    rgSum += r - g;
    if (y >= 250) glare++;
    if (y <= 15) dark++;
  }
  final total = width * height;
  final meanLuma = lumaSum / total;
  final meanRedGreen = rgSum / total;

  // 2. Variance of Laplacian (ALG-CAP-06).
  double lapSum = 0;
  double lapSqSum = 0;
  int lapCount = 0;
  for (int yPos = 1; yPos < height - 1; yPos++) {
    final row = yPos * width;
    for (int x = 1; x < width - 1; x++) {
      final i = row + x;
      final lap =
          4 * luma[i] -
          luma[i - 1] -
          luma[i + 1] -
          luma[i - width] -
          luma[i + width];
      lapSum += lap;
      lapSqSum += lap * lap;
      lapCount++;
    }
  }
  final lapMean = lapCount > 0 ? lapSum / lapCount : 0.0;
  final blurScore = lapCount > 0
      ? math.max(0.0, lapSqSum / lapCount - lapMean * lapMean)
      : 0.0;

  // 3. ROI colour features (coverage proxy per target, R/G ratio, a*, b*).
  final x0 = (region.left * width).floor().clamp(0, width - 1);
  final y0 = (region.top * height).floor().clamp(0, height - 1);
  final x1 = (region.right * width).ceil().clamp(x0 + 1, width);
  final y1 = (region.bottom * height).ceil().clamp(y0 + 1, height);
  int roiCount = 0;
  int matchCount = 0;
  double rSum = 0;
  double gSum = 0;
  double aStarSum = 0;
  double bStarSum = 0;
  int labCount = 0;
  for (int yPos = y0; yPos < y1; yPos++) {
    for (int x = x0; x < x1; x++) {
      final p = (yPos * width + x) * 4;
      final r = rgba[p];
      final g = rgba[p + 1];
      final b = rgba[p + 2];
      final y = luma[yPos * width + x];
      roiCount++;
      rSum += r;
      gSum += g;
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final matched = switch (target) {
        // Conjunctiva pink: red-dominant.
        PhotoTarget.lowerEyelid => r > g + 12 && r > b + 12,
        // Sclera: bright and low-saturation (white → pale yellow).
        PhotoTarget.sclera => y >= 140 && (maxC - minC) <= 70,
        // Pupil / lens: dark disc, or a red/white reflex from the flash.
        PhotoTarget.pupilLens => y <= 70 || (r > 110 && r > g * 1.5),
        // Two pupils with a Brückner reflex: dark or reddish-bright.
        PhotoTarget.bothPupils =>
          y <= 70 || (r > 110 && r > g * 1.4) || (y >= 235),
        // Fundus: anything that is not the black mask around the retina.
        PhotoTarget.fundus => y > 25,
        // Bare skin (any tone): warm, moderately saturated, not clipped.
        PhotoTarget.skinPatch || PhotoTarget.footSole =>
          r > g &&
              g >= b - 4 &&
              (r - b) >= 15 &&
              y >= 50 &&
              y <= 245 &&
              (maxC - minC) >= 12 &&
              (maxC - minC) <= 150,
        // Lesion: darker or redder than the overall frame (pigmented / inflamed spot).
        PhotoTarget.lesion =>
          y < meanLuma - 25 || ((r - g) > meanRedGreen + 30),
        // Mouth lining: wet pink / red tissue — red-dominant, moderately
        // saturated, lit by the torch (not the dark cavity, not a tooth).
        PhotoTarget.oralMucosa =>
          r > g + 18 &&
              r > b + 10 &&
              y >= 45 &&
              y <= 240 &&
              (maxC - minC) >= 25,
        // Teeth with gum: bright low-saturation enamel (white -> ivory) or
        // the pink gum margin around it.
        // Torch light makes enamel ivory / warm, so allow moderate
        // saturation; the pink gum margin counts too.
        PhotoTarget.teethArch =>
          (y >= 130 && (maxC - minC) <= 90) ||
              (r > g + 18 && r > b + 10 && y >= 60 && (maxC - minC) >= 25),
      };
      if (matched) matchCount++;
      if (((yPos - y0) & 3) == 0 && ((x - x0) & 3) == 0) {
        final lab = _approxLab(r, g, b);
        aStarSum += lab.$1;
        bStarSum += lab.$2;
        labCount++;
      }
    }
  }
  final rawCoveragePct = roiCount > 0 ? matchCount * 100.0 / roiCount : 0.0;
  // Mouth targets never fill the whole guide: the open mouth, lips and the
  // dark cavity sit inside it. Calibrate the proxy so a well-framed arch
  // (≈ 55 % enamel + gum pixels) or lining (≈ 65 %) reads as full coverage
  // [DER] — the CAP-09 ≥ 80 % rule then applies to the calibrated value.
  // A sole never fills its tall guide corner to corner (toes, arch, the
  // card beside it), so ≈ 60 % skin pixels is a full sole [DER].
  final coveragePct = switch (target) {
    PhotoTarget.teethArch => (rawCoveragePct / 0.55).clamp(0.0, 100.0),
    PhotoTarget.oralMucosa => (rawCoveragePct / 0.65).clamp(0.0, 100.0),
    PhotoTarget.footSole => (rawCoveragePct / 0.60).clamp(0.0, 100.0),
    _ => rawCoveragePct,
  };
  final redGreenRatio = gSum > 0 ? rSum / gSum : 1.0;
  final meanAStar = labCount > 0 ? aStarSum / labCount : 0.0;
  final meanBStar = labCount > 0 ? bStarSum / labCount : 0.0;

  final glarePct = glare * 100.0 / total;
  final darkPct = dark * 100.0 / total;

  // 4. IQ proxy: geometric-ish blend of the real checks.
  final iqScore =
      (0.35 * (blurScore / 250.0).clamp(0.0, 1.0) +
              0.25 * (1.0 - glarePct / 15.0).clamp(0.0, 1.0) +
              0.15 * (1.0 - darkPct / 30.0).clamp(0.0, 1.0) +
              0.25 * (coveragePct / 100.0).clamp(0.0, 1.0))
          .clamp(0.0, 1.0);

  return PhotoQualityReport(
    blurScore: blurScore,
    glarePct: glarePct,
    darkPct: darkPct,
    meanLuma: meanLuma,
    lidCoveragePct: coveragePct,
    iqScore: iqScore,
    redGreenRatio: redGreenRatio,
    meanAStar: meanAStar,
    meanBStar: meanBStar,
    target: target,
  );
}

double _srgbToLinear(int c) {
  final v = c / 255.0;
  return v <= 0.04045
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _labF(double t) =>
    t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : (7.787 * t) + (16 / 116);

/// Approximate CIELab (a*, b*) (D65) for one sRGB pixel.
(double, double) _approxLab(int r, int g, int b) {
  final rl = _srgbToLinear(r);
  final gl = _srgbToLinear(g);
  final bl = _srgbToLinear(b);
  final x = (rl * 0.4124 + gl * 0.3576 + bl * 0.1805) / 0.95047;
  final y = rl * 0.2126 + gl * 0.7152 + bl * 0.0722;
  final z = (rl * 0.0193 + gl * 0.1192 + bl * 0.9505) / 1.08883;
  final fx = _labF(x);
  final fy = _labF(y);
  final fz = _labF(z);
  return (500 * (fx - fy), 200 * (fy - fz));
}

/// Decodes an encoded still (JPEG/PNG from `CameraController.takePicture`),
/// downsamples to ≤ 320 px wide and runs [analyzeRgba].
Future<PhotoQualityReport> analyzeEncodedPhoto(
  Uint8List encoded, {
  ui.Rect? roi,
  PhotoTarget target = PhotoTarget.lowerEyelid,
}) async {
  final codec = await ui.instantiateImageCodec(encoded, targetWidth: 320);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      return PhotoQualityReport.simulated(good: false, target: target);
    }
    return analyzeRgba(
      data.buffer.asUint8List(),
      image.width,
      image.height,
      roi: roi,
      target: target,
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}
