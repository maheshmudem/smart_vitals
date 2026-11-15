import '../domain/algorithms/photo_quality_analyzer.dart' show PhotoTarget;

/// What the live camera must *see* before a photo flow counts the subject as
/// "in frame" — the photo-flow equivalent of the face scan's face tracking.
///
/// Detection runs on-device with Google ML Kit's base image labeler (430
/// labels). The base model has no "tooth" or "eye" label, so each target
/// uses the closest labels it does have — verified against the published
/// label map: Mouth, Smile, Foot, Toe, Skin, Eyelash, Hand, Nail, Baby
/// [DER]. A pixel proxy (torch-lit share, luminance) still guards position.
class SubjectTrackSpec {
  const SubjectTrackSpec({
    required this.subjectName,
    required this.labels,
    this.minConfidence = 0.45,
    this.useFaceDetector = false,
    this.notSeenHint = '',
    this.minCoverage = 0.0,
  });

  /// Share of the live frame's centre region the subject must cover
  /// (torch-lit pixels for mouth targets, skin-tone pixels otherwise) before
  /// the frame counts as framed. 0 disables the pixel gate.
  final double minCoverage;

  /// Plain word used in warnings: "Teeth not in frame".
  final String subjectName;

  /// ML Kit base-model labels that mean the subject is visible.
  final Set<String> labels;
  final double minConfidence;

  /// Subject is a whole face at 0.5–1 m (child eye): use the face detector
  /// instead of the labeler.
  final bool useFaceDetector;

  /// One line telling the person how to bring the subject into frame.
  final String notSeenHint;

  static SubjectTrackSpec? forTarget(PhotoTarget t) => switch (t) {
    PhotoTarget.teethArch => const SubjectTrackSpec(
      subjectName: 'Teeth',
      labels: {'Mouth', 'Smile'},
      minCoverage: 0.15,
      notSeenHint:
          'Show your teeth to the camera — pull the lips back, 10–15 cm away, torch on.',
    ),
    PhotoTarget.oralMucosa => const SubjectTrackSpec(
      subjectName: 'Mouth',
      labels: {'Mouth', 'Smile'},
      minCoverage: 0.15,
      notSeenHint:
          'Open wide and point the torch into the mouth — fill the guide with the lining.',
    ),
    PhotoTarget.footSole => const SubjectTrackSpec(
      subjectName: 'Foot',
      labels: {'Foot', 'Toe'},
      minCoverage: 0.30,
      notSeenHint:
          'Bare foot inside the frame, toes at the top — move the phone back until the whole sole shows.',
    ),
    PhotoTarget.skinPatch => const SubjectTrackSpec(
      subjectName: 'Skin',
      labels: {'Skin', 'Baby', 'Hand', 'Nail'},
      minCoverage: 0.30,
      notSeenHint:
          'Bare skin must fill the guide — move clothing away and keep the card beside it.',
    ),
    PhotoTarget.lesion => const SubjectTrackSpec(
      subjectName: 'Skin',
      labels: {'Skin', 'Hand', 'Nail'},
      minCoverage: 0.12,
      notSeenHint: 'Centre the spot on bare skin, 10–15 cm away.',
    ),
    PhotoTarget.lowerEyelid ||
    PhotoTarget.sclera ||
    PhotoTarget.pupilLens => const SubjectTrackSpec(
      subjectName: 'Eye',
      labels: {'Eyelash', 'Skin'},
      minConfidence: 0.40,
      minCoverage: 0.20,
      notSeenHint: 'Bring the eye inside the guide, about 10 cm away.',
    ),
    PhotoTarget.bothPupils => const SubjectTrackSpec(
      subjectName: 'Face',
      labels: {},
      useFaceDetector: true,
      notSeenHint:
          'Both eyes in the frame — hold the phone at the child\'s eye level, 0.5–1 m away.',
    ),
    // Clip-on fundus camera: the eyepiece sits on the eye; nothing to track.
    PhotoTarget.fundus => null,
  };

  /// Union of the specs for every view of a protocol (null when no view is
  /// trackable). The name and hint come from the first trackable view.
  static SubjectTrackSpec? forTargets(Iterable<PhotoTarget> targets) {
    SubjectTrackSpec? first;
    final labels = <String>{};
    var face = false;
    var minConf = 1.0;
    var minCov = 1.0;
    for (final t in targets) {
      final s = forTarget(t);
      if (s == null) continue;
      first ??= s;
      labels.addAll(s.labels);
      face = face || s.useFaceDetector;
      if (s.minConfidence < minConf) minConf = s.minConfidence;
      if (s.minCoverage < minCov) minCov = s.minCoverage;
    }
    if (first == null) return null;
    return SubjectTrackSpec(
      subjectName: first.subjectName,
      labels: labels,
      minConfidence: minConf,
      useFaceDetector: face,
      notSeenHint: first.notSeenHint,
      minCoverage: minCov,
    );
  }

  bool matches(Iterable<(String, double)> found) =>
      found.any((f) => labels.contains(f.$1) && f.$2 >= minConfidence);

  /// Highest-confidence matching label, if any.
  (String, double)? best(Iterable<(String, double)> found) {
    (String, double)? b;
    for (final f in found) {
      if (!labels.contains(f.$1)) continue;
      if (b == null || f.$2 > b.$2) b = f;
    }
    return b;
  }
}
