import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/algorithms/mind_engines.dart' show FaceGeometry;
import 'subject_track_spec.dart';

/// Camera operating modes across Mirror Wellness biometric modules.
enum ScanCameraMode {
  /// Front-facing selfie camera for contactless Facial rPPG (`S-D02`/`S-D03`) & Vision (`S-H07`).
  frontFace,

  /// Rear camera + continuous LED flashlight torch for Finger Contact PPG (`S-D04`).
  rearTorchFinger,

  /// Rear macro camera (with optional LED torch) for Eye/Skin/Nail (`S-E03`) & 4-View Dental (`S-F03`).
  rearMacro,

  /// Rear camera for lower-eyelid still photos (Anaemia `ALG-IMG-01`): flash
  /// stays off during preview and fires on `captureStill(flash: true)`.
  rearEyelid,

  /// Front camera streaming YUV420 frames at full rate to a hand-landmark
  /// tracker (finger-tapping video `ALG-MOV-01`, S-H01). No face detector.
  frontHand,

  /// Rear camera with the LED torch on during framing (mouth photos: oral
  /// lesion `ALG-IMG-04` and dental `ALG-DEN-01`): the torch lights the dark
  /// cavity while the person frames, the flash fires on `captureStill` and the
  /// torch is restored afterwards.
  rearTorchMouth,
}

/// Manages real device camera hardware (`CameraController`), LED flashlight torch,
/// and live on-device face/finger/luminance detection (`google_mlkit_face_detection` + pixel stream).
class BiometricCameraController extends ChangeNotifier {
  BiometricCameraController({
    required this.mode,
    this.onFrameMetricsUpdated,
    this.resolutionPreset = ResolutionPreset.medium,
    this.subjectTrack,
    this.onRawFrame,
  });

  final ScanCameraMode mode;

  /// `frontHand` only: every camera frame, before any throttling, so a
  /// landmark tracker can run at the camera's rate.
  final void Function(CameraImage image, CameraDescription camera)? onRawFrame;

  /// Photo flows: what must be visible (teeth, foot, skin, eye …) before the
  /// frame counts as "subject in frame". Detected on-device with the ML Kit
  /// image labeler (or the face detector for whole-face targets).
  final SubjectTrackSpec? subjectTrack;
  ImageLabeler? _imageLabeler;
  DateTime _lastLabelAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _detectorActive = false;
  bool _subjectSeen = false;
  String? _subjectLabel;
  double _subjectConfidence = 0.0;
  final void Function(BiometricFrameTelemetry telemetry)? onFrameMetricsUpdated;

  /// Preview / still resolution. Still-photo screens use `high`.
  final ResolutionPreset resolutionPreset;
  bool _isCapturingStill = false;
  double _frameVariance = 450.0;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;
  FaceDetector? _faceDetector;

  bool _isInitializing = true;
  bool _hasHardwareCamera = false;
  bool _permissionDenied = false;
  bool _torchEnabled = false;
  bool _isProcessingFrame = false;
  bool _disposed = false;
  String? _statusNote;
  DateTime _lastFrameProcessed = DateTime.fromMillisecondsSinceEpoch(0);

  // Live telemetry computed from real camera frames (or interactive override)
  bool _frameStreamActive = false;
  bool _subjectInFrame = false;
  double _subjectCoverage = 0.0;
  Rect? _normalizedFaceBox;
  double _brightness = 142.0;
  double _headTiltDeg = 0.0;
  // CAP-15 stand-in: distance between the two eye landmarks in image px and
  // the upright image width (null when no face / no landmarks).
  double? _eyeGapPx;
  double? _eyeGapImageWidthPx;
  // MOV-06 stand-in: smile probability and the eye / mouth-corner landmark
  // geometry of the largest face (normalised to the upright image).
  double? _smileProb;
  FaceGeometry? _faceGeometry;
  DateTime? _faceGeometryAt;
  double _redDominanceRatio = 1.85;
  int _facesCount = 0;

  CameraController? get cameraController => _cameraController;
  bool get isInitializing => _isInitializing;
  bool get isCameraReady =>
      _hasHardwareCamera &&
      _cameraController != null &&
      _cameraController!.value.isInitialized;
  bool get permissionDenied => _permissionDenied;

  /// True under FLUTTER_TEST: no device camera, deterministic readiness.
  bool get isSimulatedSensor => _isFlutterTest;
  bool get torchEnabled => _torchEnabled;
  String? get statusNote => _statusNote;

  bool get subjectInFrame => _subjectInFrame;

  /// Mouth mode: share of the centre region lit by the torch (0–1).
  double get subjectCoverage => _subjectCoverage;

  /// True once the on-device detector (labeler / face detector) is running.
  bool get detectorActive => _detectorActive;
  bool get subjectSeen => _subjectSeen;
  String? get subjectLabel => _subjectLabel;
  double get subjectConfidence => _subjectConfidence;

  /// True when real per-frame analysis (ML Kit / pixel stream) is running, as
  /// opposed to the desktop/web warm-up fallback that reports a synthetic box.
  bool get liveFaceTrackingActive => _frameStreamActive;
  Rect? get normalizedFaceBox => _normalizedFaceBox;
  double get brightness => _brightness;
  double get headTiltDeg => _headTiltDeg;

  /// Inter-pupillary distance of the largest face in image pixels, with the
  /// width of the upright analysed image (face distance, ALG-CAP-15 stand-in).
  double? get eyeGapPx => _eyeGapPx;
  double? get eyeGapImageWidthPx => _eyeGapImageWidthPx;

  /// ML Kit smiling probability of the largest face (null = unknown).
  double? get smileProb => _smileProb;

  /// Eye and mouth-corner landmarks for the face-asymmetry check (MOV-06).
  FaceGeometry? get faceGeometry => _faceGeometry;

  /// When [faceGeometry] was last refreshed from a frame with a face.
  DateTime? get faceGeometryAt => _faceGeometryAt;

  /// A face geometry no older than [maxAge] (null when the face is lost).
  FaceGeometry? freshFaceGeometry({
    Duration maxAge = const Duration(milliseconds: 600),
  }) {
    final at = _faceGeometryAt;
    if (_faceGeometry == null || at == null) return null;
    if (DateTime.now().difference(at) > maxAge) return null;
    return _faceGeometry;
  }

  double get redDominanceRatio => _redDominanceRatio;
  int get facesCount => _facesCount;

  /// Spatial luma variance of the last analysed frame (live sharpness hint).
  double get frameVariance => _frameVariance;
  bool get isCapturingStill => _isCapturingStill;

  static bool get _isFlutterTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    if (_disposed) return;
    _isInitializing = true;
    _permissionDenied = false;
    _statusNote = 'Opening device camera...';
    notifyListeners();

    if (_isFlutterTest) {
      // In widget tests, provide immediate deterministic readiness without platform channels
      _isInitializing = false;
      _hasHardwareCamera = false;
      _statusNote = 'Simulated test sensor active';
      notifyListeners();
      return;
    }

    try {
      // 1. Request runtime camera permission on Android / iOS
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          _permissionDenied = true;
          _isInitializing = false;
          _statusNote =
              'Camera permission is required to scan your face/finger.';
          if (!_disposed) notifyListeners();
          return;
        }
      }

      // 2. Initialize ML Kit Face Detector on Android / iOS for frontFace mode
      if (!kIsWeb &&
          (Platform.isAndroid || Platform.isIOS) &&
          mode == ScanCameraMode.frontFace) {
        _faceDetector ??= FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: true,
            enableLandmarks: true,
            enableTracking: true,
            performanceMode: FaceDetectorMode.fast,
            minFaceSize: 0.18,
          ),
        );
      }
      // 2b. Photo flows: subject tracking (teeth / mouth / foot / skin / eye)
      // with the on-device image labeler, or the face detector for a whole
      // face at 0.5–1 m (child eye).
      final track = subjectTrack;
      if (!kIsWeb &&
          (Platform.isAndroid || Platform.isIOS) &&
          mode != ScanCameraMode.frontFace &&
          mode != ScanCameraMode.rearTorchFinger &&
          track != null) {
        if (track.useFaceDetector) {
          _faceDetector ??= FaceDetector(
            options: FaceDetectorOptions(
              performanceMode: FaceDetectorMode.fast,
              minFaceSize: 0.12,
            ),
          );
        } else {
          _imageLabeler ??= ImageLabeler(
            options: ImageLabelerOptions(confidenceThreshold: 0.30),
          );
        }
      }

      // 3. Discover available hardware cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _hasHardwareCamera = false;
        _isInitializing = false;
        _statusNote =
            'No physical camera found — interactive sensor mode active';
        if (!_disposed) notifyListeners();
        return;
      }

      // 4. Pick front camera for Face Scan, rear camera for Finger/Macro/Dental
      final desiredDirection =
          mode == ScanCameraMode.frontFace || mode == ScanCameraMode.frontHand
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final matchIdx = _cameras.indexWhere(
        (c) => c.lensDirection == desiredDirection,
      );
      _selectedCameraIndex = matchIdx >= 0 ? matchIdx : 0;

      await _startCameraAtIndex(_selectedCameraIndex);
    } catch (e) {
      _hasHardwareCamera = false;
      _isInitializing = false;
      _statusNote = 'Live sensor simulation active';
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _startCameraAtIndex(int index) async {
    if (_disposed || _cameras.isEmpty) return;
    final cam = _cameras[index];

    final prev = _cameraController;
    _cameraController = null;
    try {
      await prev?.dispose();
    } catch (_) {}

    CameraController? controller;
    bool initSuccess = false;

    // 1. Android-optimized NV21 image format for ML Kit
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final candidate = CameraController(
          cam,
          resolutionPreset,
          enableAudio: false,
          // Hand Landmarker needs the three YUV420 planes; ML Kit prefers NV21.
          imageFormatGroup: mode == ScanCameraMode.frontHand
              ? ImageFormatGroup.yuv420
              : ImageFormatGroup.nv21,
        );
        await candidate.initialize();
        controller = candidate;
        initSuccess = true;
      } catch (e) {
        debugPrint(
          '[BiometricCamera] NV21 init note, trying platform default: $e',
        );
      }
    }

    // 2. Platform default format negotiation (Windows camera_windows, iOS, Android fallback)
    if (!initSuccess) {
      try {
        final candidate = CameraController(
          cam,
          resolutionPreset,
          enableAudio: false,
        );
        await candidate.initialize();
        controller = candidate;
        initSuccess = true;
      } catch (e) {
        debugPrint('[BiometricCamera] Default camera format init failed: $e');
      }
    }

    if (!initSuccess || controller == null) {
      _hasHardwareCamera = false;
      _isInitializing = false;
      _statusNote =
          'Hardware camera unavailable — interactive optical simulation active';
      if (!_disposed) notifyListeners();
      return;
    }

    if (_disposed) {
      await controller.dispose();
      return;
    }

    _cameraController = controller;
    _hasHardwareCamera = true;
    _isInitializing = false;

    // Continuous auto-focus / auto-exposure so the face stays sharp and evenly lit.
    try {
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {}
    try {
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {}
    _statusNote = mode == ScanCameraMode.frontFace
        ? 'Front camera active — tracking your face'
        : mode == ScanCameraMode.rearTorchFinger
        ? 'Rear camera & optical PPG sensor active'
        : mode == ScanCameraMode.rearEyelid
        ? 'Rear camera ready — flash fires on each photo'
        : mode == ScanCameraMode.rearTorchMouth
        ? 'Rear camera + torch lighting the mouth — flash fires on each photo'
        : mode == ScanCameraMode.frontHand
        ? 'Front camera active — tracking your hand'
        : 'Rear macro camera active';

    // Enable LED Flashlight Torch automatically for Finger PPG Contact mode
    // and for mouth photos (the torch lights the oral cavity while framing).
    if (mode == ScanCameraMode.rearTorchFinger ||
        mode == ScanCameraMode.rearTorchMouth) {
      try {
        await controller.setFlashMode(FlashMode.torch);
        _torchEnabled = true;
      } catch (_) {
        _torchEnabled = false;
      }
    } else {
      try {
        await controller.setFlashMode(FlashMode.off);
        _torchEnabled = false;
      } catch (_) {}
    }

    // Start real-time camera frame analysis on Android/iOS
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await controller.startImageStream(_onCameraFrame);
        _frameStreamActive = true;
      } catch (e) {
        debugPrint('[BiometricCamera] Frame stream note: $e');
      }
    } else {
      // Desktop / Web without frame stream: automatically recognize subject after camera warms up
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (!_disposed && _hasHardwareCamera && !_subjectInFrame) {
          _subjectInFrame = true;
          _facesCount = 1;
          _normalizedFaceBox = const Rect.fromLTWH(0.24, 0.16, 0.52, 0.66);
          onFrameMetricsUpdated?.call(
            BiometricFrameTelemetry(
              subjectInFrame: _subjectInFrame,
              brightness: _brightness,
              headTiltDeg: _headTiltDeg,
              normalizedFaceBox: _normalizedFaceBox,
              torchActive: _torchEnabled,
            ),
          );
          notifyListeners();
        }
      });
    }

    if (!_disposed) notifyListeners();
  }

  /// Switches between Front and Rear cameras on demand.
  Future<void> switchCameraLens() async {
    if (_cameras.length < 2 || _isInitializing) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _startCameraAtIndex(_selectedCameraIndex);
  }

  /// Toggles the rear camera LED flashlight torch.
  Future<void> toggleTorch() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      _torchEnabled = !_torchEnabled;
      notifyListeners();
      return;
    }
    try {
      final next = !_torchEnabled;
      await ctrl.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      _torchEnabled = next;
      notifyListeners();
    } catch (_) {
      _torchEnabled = !_torchEnabled;
      notifyListeners();
    }
  }

  /// Takes one still photo (JPEG bytes) with the hardware flash when asked.
  /// Pauses the analysis stream for the capture and restores it afterwards.
  /// Returns `null` in widget tests, without hardware, or on capture failure
  /// so callers can fall back to a simulated frame.
  Future<Uint8List?> captureStill({bool flash = true}) async {
    final ctrl = _cameraController;
    if (_isFlutterTest ||
        _disposed ||
        ctrl == null ||
        !ctrl.value.isInitialized ||
        _isCapturingStill) {
      return null;
    }
    _isCapturingStill = true;
    notifyListeners();
    final wasStreaming = ctrl.value.isStreamingImages;
    try {
      if (wasStreaming) {
        try {
          await ctrl.stopImageStream();
        } catch (_) {}
      }
      try {
        await ctrl.setFlashMode(flash ? FlashMode.always : FlashMode.off);
      } catch (_) {}
      final file = await ctrl.takePicture();
      final bytes = await file.readAsBytes();
      return bytes;
    } catch (e) {
      debugPrint('[BiometricCamera] Still capture failed: $e');
      return null;
    } finally {
      try {
        await ctrl.setFlashMode(
          _torchEnabled ? FlashMode.torch : FlashMode.off,
        );
      } catch (_) {}
      if (wasStreaming && !_disposed) {
        try {
          await ctrl.startImageStream(_onCameraFrame);
          _frameStreamActive = true;
        } catch (_) {}
      }
      _isCapturingStill = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (mode == ScanCameraMode.frontHand && !_disposed) {
      final c = _cameraController;
      if (c != null) onRawFrame?.call(image, c.description);
    }
    if (_disposed || _isProcessingFrame) return;
    final now = DateTime.now();
    // Process ~3.5 frames/sec so UI & 60 FPS animations stay silky smooth
    if (now.difference(_lastFrameProcessed).inMilliseconds < 280) return;
    _isProcessingFrame = true;
    _lastFrameProcessed = now;

    try {
      // 1. Compute real frame luminance and center-vs-outer contrast from Plane 0 (Y or BGRA)
      final frameStats = _analyzeRawFramePixels(image);
      _brightness = frameStats.meanLuminance;
      _redDominanceRatio = frameStats.redDominance;
      _frameVariance = frameStats.centerVariance;

      if (mode == ScanCameraMode.frontFace) {
        // 2. Try ML Kit Face Detector first on Android/iOS
        bool mlKitSucceeded = false;
        if (_faceDetector != null && _cameraController != null) {
          final inputImage = _buildInputImage(
            image,
            _cameraController!.description,
          );
          if (inputImage != null) {
            try {
              final faces = await _faceDetector!.processImage(inputImage);
              mlKitSucceeded = true;
              _facesCount = faces.length;
              if (faces.isEmpty) {
                _subjectInFrame = false;
                _normalizedFaceBox = null;
                _eyeGapPx = null;
                _faceGeometry = null;
                _smileProb = null;
              } else {
                // Pick largest face
                faces.sort(
                  (a, b) => (b.boundingBox.width * b.boundingBox.height)
                      .compareTo(a.boundingBox.width * a.boundingBox.height),
                );
                final face = faces.first;
                // ML Kit reports boxes in the upright (rotation-applied) frame on
                // Android but in the native frame on iOS, so pick the matching
                // image dimensions before normalising (same rule as the official
                // google_mlkit coordinate translator).
                final description = _cameraController!.description;
                final rotation = _inputRotationFor(description);
                final rotated =
                    rotation == InputImageRotation.rotation90deg ||
                    rotation == InputImageRotation.rotation270deg;
                final swapAxes = rotated && !Platform.isIOS;
                final imgW = (swapAxes ? image.height : image.width).toDouble();
                final imgH = (swapAxes ? image.width : image.height).toDouble();
                final isFront =
                    description.lensDirection == CameraLensDirection.front;
                // The preview is mirrored for the selfie camera; mirror x to match.
                final mirrored =
                    rotation == InputImageRotation.rotation270deg ||
                    (!rotated && isFront);
                final box = face.boundingBox;
                final normW = (box.width / imgW).clamp(0.10, 0.95);
                final normH = (box.height / imgH).clamp(0.10, 0.95);
                final rawL = mirrored
                    ? (1.0 - box.right / imgW)
                    : (box.left / imgW);
                final normL = rawL.clamp(0.0, 1.0 - normW);
                final normT = (box.top / imgH).clamp(0.0, 1.0 - normH);

                _normalizedFaceBox = Rect.fromLTWH(normL, normT, normW, normH);
                final yaw = (face.headEulerAngleY ?? 0.0).abs();
                final pitch = (face.headEulerAngleX ?? 0.0).abs();
                _headTiltDeg = math.max(yaw, pitch);
                final le = face.landmarks[FaceLandmarkType.leftEye]?.position;
                final re = face.landmarks[FaceLandmarkType.rightEye]?.position;
                if (le != null && re != null) {
                  final dx = (le.x - re.x).toDouble();
                  final dy = (le.y - re.y).toDouble();
                  _eyeGapPx = math.sqrt(dx * dx + dy * dy);
                  _eyeGapImageWidthPx = imgW;
                } else {
                  _eyeGapPx = null;
                }
                _smileProb = face.smilingProbability;
                final ml = face.landmarks[FaceLandmarkType.leftMouth]?.position;
                final mr =
                    face.landmarks[FaceLandmarkType.rightMouth]?.position;
                if (le != null && re != null && ml != null && mr != null) {
                  // ML Kit "left" is the member's left (image right when
                  // mirrored); keep member-side naming.
                  _faceGeometry = FaceGeometry(
                    leftEye: (x: le.x / imgW, y: le.y / imgH),
                    rightEye: (x: re.x / imgW, y: re.y / imgH),
                    mouthLeft: (x: ml.x / imgW, y: ml.y / imgH),
                    mouthRight: (x: mr.x / imgW, y: mr.y / imgH),
                    smileProb: face.smilingProbability ?? 0,
                  );
                  _faceGeometryAt = now;
                } else {
                  _faceGeometry = null;
                }

                // Check if face center is reasonably inside the oval frame
                final cx = normL + normW / 2;
                final cy = normT + normH / 2;
                final centered =
                    cx >= 0.22 &&
                    cx <= 0.78 &&
                    cy >= 0.18 &&
                    cy <= 0.82 &&
                    normW >= 0.20;
                _subjectInFrame = centered;
              }
            } catch (_) {
              mlKitSucceeded = false;
              _faceGeometry = null;
              _smileProb = null;
            }
          }
        }

        // Fallback pixel-based presence check if ML Kit InputImage wasn't supported on this OEM format
        if (!mlKitSucceeded) {
          final hasCentralSubject =
              frameStats.meanLuminance > 35 &&
              frameStats.centerVariance > 120.0;
          _subjectInFrame = hasCentralSubject;
          _facesCount = hasCentralSubject ? 1 : 0;
          _normalizedFaceBox = hasCentralSubject
              ? const Rect.fromLTWH(0.23, 0.15, 0.54, 0.68)
              : null;
        }
      } else if (mode == ScanCameraMode.rearTorchFinger) {
        // For Finger Contact PPG: when finger covers the lens + torch, spatial variance drops
        // and brightness is warm/moderate (not pitch black 0 and not blown-out room scene with high edges)
        final isFingerCoveringLens =
            frameStats.meanLuminance >= 22 &&
            frameStats.meanLuminance <= 245 &&
            frameStats.centerVariance < 1800;
        _subjectInFrame = isFingerCoveringLens;
      } else {
        // Photo flows (mouth / teeth / eye / skin / foot).
        // a) Pixel proxy for position and light.
        final bool pixelOk;
        final minCov = subjectTrack?.minCoverage ?? 0.0;
        if (mode == ScanCameraMode.rearTorchMouth) {
          // The torch-lit teeth or tissue must fill a fair share of the
          // centre of the frame, with real edges — a plain lit wall (flat)
          // or the dark room (no lit pixels) do not count as "in frame".
          _subjectCoverage = frameStats.centerLitFraction;
          pixelOk =
              frameStats.meanLuminance >= 35 &&
              frameStats.centerLitFraction >= math.max(0.15, minCov) &&
              frameStats.centerLitFraction <= 0.97 &&
              frameStats.centerVariance >= 120.0;
        } else {
          // Skin-tone share of the centre region (YCbCr skin rule on the
          // camera's colour planes): the foot / skin / eye must fill the
          // guide. When the frame carries no colour planes the share is
          // unknown and only the light check applies.
          _subjectCoverage = frameStats.centerSkinFraction;
          pixelOk =
              frameStats.meanLuminance >= 35 &&
              (!frameStats.skinKnown ||
                  minCov <= 0 ||
                  frameStats.centerSkinFraction >= minCov);
        }
        // b) On-device detector: is the subject actually visible?
        await _trackSubject(image);
        _subjectInFrame = pixelOk && (!_detectorActive || _subjectSeen);
      }

      if (!_disposed) {
        onFrameMetricsUpdated?.call(
          BiometricFrameTelemetry(
            subjectInFrame: _subjectInFrame,
            brightness: _brightness,
            headTiltDeg: _headTiltDeg,
            normalizedFaceBox: _normalizedFaceBox,
            torchActive: _torchEnabled,
            frameVariance: _frameVariance,
            subjectCoverage: _subjectCoverage,
            detectorActive: _detectorActive,
            subjectSeen: _subjectSeen,
            subjectLabel: _subjectLabel,
            subjectConfidence: _subjectConfidence,
          ),
        );
        notifyListeners();
      }
    } catch (_) {
      // Ignore transient frame errors
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Runs the labeler (or the face detector) about twice a second and keeps
  /// the last answer between runs. Leaves [_detectorActive] false when ML
  /// Kit is unavailable so the pixel proxy alone decides (desktop / tests).
  Future<void> _trackSubject(CameraImage image) async {
    final track = subjectTrack;
    final controller = _cameraController;
    if (track == null || controller == null) return;
    final now = DateTime.now();
    if (now.difference(_lastLabelAt).inMilliseconds < 500) return;
    _lastLabelAt = now;
    final input = _buildInputImage(image, controller.description);
    if (input == null) return;
    try {
      if (track.useFaceDetector) {
        final detector = _faceDetector;
        if (detector == null) return;
        final faces = await detector.processImage(input);
        _detectorActive = true;
        _facesCount = faces.length;
        _subjectSeen = faces.isNotEmpty;
        _subjectLabel = faces.isNotEmpty ? 'Face' : null;
        _subjectConfidence = faces.isNotEmpty ? 1.0 : 0.0;
        return;
      }
      final labeler = _imageLabeler;
      if (labeler == null) return;
      final labels = await labeler.processImage(input);
      _detectorActive = true;
      final found = [for (final l in labels) (l.label, l.confidence)];
      final best = track.best(found);
      _subjectSeen = track.matches(found);
      _subjectLabel = best?.$1;
      _subjectConfidence = best?.$2 ?? 0.0;
    } catch (_) {
      // Detector unavailable on this OEM format: fall back to the proxy.
    }
  }

  _RawFrameStats _analyzeRawFramePixels(CameraImage image) {
    if (image.planes.isEmpty) {
      return const _RawFrameStats(
        meanLuminance: 140,
        centerVariance: 450,
        redDominance: 1.8,
      );
    }
    final plane = image.planes.first;
    final bytes = plane.bytes;
    if (bytes.isEmpty) {
      return const _RawFrameStats(
        meanLuminance: 140,
        centerVariance: 450,
        redDominance: 1.8,
      );
    }

    // Sample up to ~400 pixels across the frame for fast O(1) luminance & variance
    final step = math.max(1, bytes.length ~/ 400);
    double sum = 0;
    double sumSq = 0;
    int count = 0;
    for (int i = 0; i < bytes.length; i += step) {
      final v = bytes[i].toDouble();
      sum += v;
      sumSq += v * v;
      count++;
    }
    final mean = count > 0 ? (sum / count).clamp(5.0, 250.0) : 140.0;
    final variance = count > 0
        ? math.max(0.0, (sumSq / count) - (mean * mean))
        : 400.0;

    // Centre region (x 15–85 %, y 25–75 %): share of pixels lit by the torch
    // (Y ≥ 120 — enamel, gum or wet lining). Plane 0 is luma on Android
    // (YUV) and blue on iOS (BGRA); both track brightness well enough for
    // a presence proxy.
    double litFraction = 0.0;
    final w = image.width;
    final h = image.height;
    final rowStride = plane.bytesPerRow > 0 ? plane.bytesPerRow : w;
    final pixStride = plane.bytesPerPixel ?? 1;
    if (w > 0 && h > 0) {
      final x0 = (w * 0.15).floor();
      final x1 = (w * 0.85).floor();
      final y0 = (h * 0.25).floor();
      final y1 = (h * 0.75).floor();
      final sx = math.max(1, (x1 - x0) ~/ 24);
      final sy = math.max(1, (y1 - y0) ~/ 16);
      int lit = 0;
      int n = 0;
      for (var y = y0; y < y1; y += sy) {
        for (var x = x0; x < x1; x += sx) {
          final idx = y * rowStride + x * pixStride;
          if (idx < 0 || idx >= bytes.length) continue;
          n++;
          if (bytes[idx] >= 120) lit++;
        }
      }
      if (n > 0) litFraction = lit / n;
    }
    // Skin-tone share of the centre region (x 18–82 %, y 12–88 %) using the
    // classic YCbCr rule (Cb 77–127, Cr 133–173, Y 40–235). Reads the
    // chroma from NV21 (single plane: Y then interleaved V/U), three-plane
    // YUV420 or iOS BGRA; otherwise the share is unknown.
    double skinFraction = 0.0;
    var skinKnown = false;
    if (w > 0 && h > 0) {
      final planes = image.planes;
      final isBgra = planes.length == 1 && (plane.bytesPerPixel ?? 1) == 4;
      final isYuv3 = planes.length >= 3;
      final isNv21 =
          planes.length == 1 &&
          !isBgra &&
          bytes.length >= rowStride * h + (h ~/ 2) * rowStride;
      if (isBgra || isYuv3 || isNv21) {
        final x0 = (w * 0.18).floor();
        final x1 = (w * 0.82).floor();
        final y0 = (h * 0.12).floor();
        final y1 = (h * 0.88).floor();
        final sx = math.max(2, ((x1 - x0) ~/ 24) & ~1);
        final sy = math.max(2, ((y1 - y0) ~/ 20) & ~1);
        int skin = 0;
        int n = 0;
        for (var y = y0; y < y1; y += sy) {
          for (var x = x0; x < x1; x += sx) {
            int yy, cb, cr;
            if (isBgra) {
              final idx = y * rowStride + x * 4;
              if (idx + 2 >= bytes.length) continue;
              final b = bytes[idx];
              final g = bytes[idx + 1];
              final r = bytes[idx + 2];
              yy = (0.299 * r + 0.587 * g + 0.114 * b).round();
              cb = (128 - 0.1687 * r - 0.3313 * g + 0.5 * b).round();
              cr = (128 + 0.5 * r - 0.4187 * g - 0.0813 * b).round();
            } else if (isYuv3) {
              final yIdx = y * rowStride + x;
              final u = planes[1];
              final v = planes[2];
              final uvIdx =
                  (y ~/ 2) * u.bytesPerRow + (x ~/ 2) * (u.bytesPerPixel ?? 1);
              if (yIdx >= bytes.length ||
                  uvIdx >= u.bytes.length ||
                  uvIdx >= v.bytes.length) {
                continue;
              }
              yy = bytes[yIdx];
              cb = u.bytes[uvIdx];
              cr = v.bytes[uvIdx];
            } else {
              final yIdx = y * rowStride + x;
              final base = rowStride * h + (y ~/ 2) * rowStride + (x ~/ 2) * 2;
              if (yIdx >= bytes.length || base + 1 >= bytes.length) continue;
              yy = bytes[yIdx];
              cr = bytes[base];
              cb = bytes[base + 1];
            }
            n++;
            if (yy >= 40 &&
                yy <= 235 &&
                cb >= 77 &&
                cb <= 127 &&
                cr >= 133 &&
                cr <= 173) {
              skin++;
            }
          }
        }
        if (n > 0) {
          skinFraction = skin / n;
          skinKnown = true;
        }
      }
    }
    return _RawFrameStats(
      meanLuminance: mean,
      centerVariance: variance,
      redDominance: variance < 1800 ? 2.1 : 1.1,
      centerLitFraction: litFraction,
      centerSkinFraction: skinFraction,
      skinKnown: skinKnown,
    );
  }

  InputImageRotation _inputRotationFor(CameraDescription camera) {
    return InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;
  }

  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    try {
      final rotation = _inputRotationFor(camera);
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null || image.planes.isEmpty) return null;

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final ctrl = _cameraController;
    _cameraController = null;
    try {
      if (ctrl != null &&
          ctrl.value.isInitialized &&
          ctrl.value.isStreamingImages) {
        // stop the stream before disposing; both may throw late
        ctrl
            .stopImageStream()
            .catchError((_) {})
            .whenComplete(() => ctrl.dispose().catchError((_) {}));
      } else {
        ctrl?.dispose().catchError((_) {});
      }
    } catch (_) {}
    try {
      _faceDetector?.close();
    } catch (_) {}
    try {
      _imageLabeler?.close();
    } catch (_) {}
    super.dispose();
  }
}

class BiometricFrameTelemetry {
  const BiometricFrameTelemetry({
    required this.subjectInFrame,
    required this.brightness,
    required this.headTiltDeg,
    required this.normalizedFaceBox,
    required this.torchActive,
    this.frameVariance = 450.0,
    this.subjectCoverage = 0.0,
    this.detectorActive = false,
    this.subjectSeen = false,
    this.subjectLabel,
    this.subjectConfidence = 0.0,
  });

  final bool subjectInFrame;
  final double brightness;
  final double headTiltDeg;
  final Rect? normalizedFaceBox;
  final bool torchActive;

  /// Spatial luma variance — low values mean a flat / defocused frame.
  final double frameVariance;

  /// Mouth mode: share of the centre region lit by the torch (0–1).
  final double subjectCoverage;

  /// Photo flows: on-device subject detection (labeler / face detector).
  final bool detectorActive;
  final bool subjectSeen;
  final String? subjectLabel;
  final double subjectConfidence;
}

class _RawFrameStats {
  const _RawFrameStats({
    required this.meanLuminance,
    required this.centerVariance,
    required this.redDominance,
    this.centerLitFraction = 0.0,
    this.centerSkinFraction = 0.0,
    this.skinKnown = false,
  });

  final double meanLuminance;
  final double centerVariance;
  final double redDominance;
  final double centerLitFraction;
  final double centerSkinFraction;
  final bool skinKnown;
}

/// Renders the live device `CameraPreview` (when hardware camera is available)
/// with a responsive aspect-ratio cover fit, plus an interactive fallback background
/// if running in headless tests or without a physical webcam.
class LiveBiometricCameraSurface extends StatelessWidget {
  const LiveBiometricCameraSurface({
    super.key,
    required this.controller,
    required this.overlayPainter,
    this.topLeftHud,
    this.topRightHud,
    this.centerBanner,
    this.bottomHud,
    this.height = 310,
    this.fullBleed = false,
  });

  final BiometricCameraController controller;
  final CustomPainter overlayPainter;
  final Widget? topLeftHud;
  final Widget? topRightHud;
  final Widget? centerBanner;
  final Widget? bottomHud;
  final double? height;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final camCtrl = controller.cameraController;
        final isReady = controller.isCameraReady && camCtrl != null;

        final surface = Container(
          height: fullBleed ? null : height,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF07111E), Color(0xFF0F243C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Real Hardware Camera Feed (Aspect-Ratio Cover Fit, Overflow-Proof)
              if (isReady)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final previewSize = camCtrl.value.previewSize;
                    // In portrait mode, camera previewSize is reported as landscape (width > height)
                    final double previewW = previewSize != null
                        ? previewSize.height
                        : constraints.maxWidth;
                    final double previewH = previewSize != null
                        ? previewSize.width
                        : constraints.maxHeight;
                    return FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: previewW > 0 ? previewW : 360,
                        height: previewH > 0 ? previewH : 480,
                        child: CameraPreview(camCtrl),
                      ),
                    );
                  },
                ),

              // 2. Darkened Vignette so HUD text & biometric overlays are always crisp
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: isReady ? 0.35 : 0.15),
                      Colors.transparent,
                      Colors.black.withValues(alpha: isReady ? 0.55 : 0.25),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // 3. Biometric CustomPainter Overlay (Face Oval, ROI Brackets, Laser Sweep, etc.)
              Positioned.fill(child: CustomPaint(painter: overlayPainter)),

              // 4. Camera Initialization / Permission Retry Indicator
              if (controller.isInitializing)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00E5CC),
                          ),
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Opening Live Camera...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (controller.permissionDenied)
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam_off_rounded,
                          color: Color(0xFFEF4444),
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Camera Permission Needed',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Please allow camera access so we can view your face/finger in real time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: controller.initialize,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Grant & Retry Camera'),
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. Top-Left & Top-Right HUD Badges (Wrapped to never overflow)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (topLeftHud != null) Flexible(child: topLeftHud!),
                    const SizedBox(width: 6),
                    if (topRightHud != null) Flexible(child: topRightHud!),
                  ],
                ),
              ),

              // 6. Center Warning Banner (e.g., Out of Frame Alert)
              if (centerBanner != null) Center(child: centerBanner!),

              // 7. Bottom HUD Bar
              if (bottomHud != null)
                Positioned(bottom: 10, left: 10, right: 10, child: bottomHud!),
            ],
          ),
        );

        if (fullBleed) return surface;
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: surface,
        );
      },
    );
  }
}
