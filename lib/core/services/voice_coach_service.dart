import 'dart:async';
import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'motion_sensor_service.dart';

/// Represents the urgency/state of a live voice coaching cue during any scan.
enum VoiceCueTone {
  ready(Color(0xFF00E5CC), Icons.record_voice_over_rounded, 'AI Voice Coach'),
  scanning(Color(0xFF10B981), Icons.graphic_eq_rounded, 'Scanning Active'),
  warning(Color(0xFFF59E0B), Icons.warning_amber_rounded, 'Adjust Position'),
  outOfFrame(
    Color(0xFFEF4444),
    Icons.center_focus_weak_rounded,
    'Out of Frame',
  ),
  completed(Color(0xFF3B82F6), Icons.check_circle_rounded, 'Scan Complete');

  const VoiceCueTone(this.color, this.icon, this.badgeText);
  final Color color;
  final IconData icon;
  final String badgeText;
}

/// Controller that drives real-time spoken Text-to-Speech (TTS) voice coaching,
/// haptic cues, and live subtitle overlays across all Mirror Wellness scanning screens.
class VoiceCoachController extends ChangeNotifier {
  VoiceCoachController({
    bool initialAudioEnabled = true,
    this.languageCode = 'en-US',
  }) : _audioEnabled = initialAudioEnabled {
    _initTts();
  }

  bool _audioEnabled;
  String languageCode;
  String _currentMessage = 'Initializing scanner and checking sensors...';
  VoiceCueTone _currentTone = VoiceCueTone.ready;
  bool _isSpeaking = false;
  bool _disposed = false;
  Timer? _speakingTimer;
  DateTime? _lastSpokenAt;
  String _lastSpokenMessage = '';

  FlutterTts? _tts;
  bool _ttsInitialized = false;
  Completer<void>? _initCompleter;

  bool get audioEnabled => _audioEnabled;
  String get currentMessage => _currentMessage;
  VoiceCueTone get currentTone => _currentTone;
  bool get isSpeaking => _isSpeaking;
  bool get isTtsInitialized => _ttsInitialized;

  static bool get isFlutterTest => _isFlutterTest;

  static bool get _isFlutterTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<void> _initTts() async {
    if (_isFlutterTest) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    if (!kIsWeb && Platform.isWindows) {
      _ttsInitialized = true;
      _initCompleter!.complete();
      return;
    }

    try {
      _tts = FlutterTts();
      await _tts!.setLanguage(languageCode);
      await _tts!.setSpeechRate(0.50);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);
      // speak() then completes when the utterance has finished, so screens
      // can wait for an instruction before starting a timed task.
      await _tts!.awaitSpeakCompletion(true);
      if (!kIsWeb && Platform.isIOS) {
        await _tts!.setSharedInstance(true);
      }
      _ttsInitialized = true;
      if (!(_initCompleter?.isCompleted ?? true)) {
        _initCompleter!.complete();
      }
    } catch (e) {
      debugPrint('[VoiceCoach] TTS init exception: $e');
      _ttsInitialized = false;
      if (!(_initCompleter?.isCompleted ?? true)) {
        _initCompleter!.complete();
      }
    }
  }

  void toggleAudio() {
    _audioEnabled = !_audioEnabled;
    if (_audioEnabled) {
      HapticFeedback.lightImpact();
      _speakNative('Voice guidance enabled.', forceInterrupt: true);
    } else {
      _stopNativeSpeech();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _stopNativeSpeech() async {
    if (_isFlutterTest) return;
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  Future<void> _speakNative(String text, {bool forceInterrupt = false}) async {
    if (_isFlutterTest || !_audioEnabled) return;
    // Clean visual symbols so TTS reads natural English sentences
    final cleanText = text
        .replaceAll('—', ', ')
        .replaceAll('·', ', ')
        .replaceAll('rPPG', 'optical vitals')
        .replaceAll('SpO2', 'blood oxygen')
        .replaceAll('SpO₂', 'blood oxygen')
        .replaceAll('HRV', 'heart rate variability')
        .replaceAll('PPG', 'pulse sensor');

    debugPrint('[VoiceCoach] Speaking: "$cleanText"');

    // Windows desktop native SAPI execution (fast & reliable without plugin dependency)
    if (!kIsWeb && Platform.isWindows) {
      try {
        final escaped = cleanText.replaceAll("'", "''").replaceAll('"', ' ');
        unawaited(
          Process.run('powershell', [
            '-NoProfile',
            '-WindowStyle',
            'Hidden',
            '-Command',
            "Add-Type -AssemblyName System.Speech; \$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer; \$synth.Rate = 0; \$synth.Speak('$escaped');",
          ]),
        );
        return;
      } catch (e) {
        debugPrint('[VoiceCoach] Windows SAPI error: $e');
      }
    }

    try {
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        await _initCompleter!.future.timeout(
          const Duration(milliseconds: 1000),
          onTimeout: () {},
        );
      } else if (_tts == null) {
        await _initTts();
      }

      if (_tts != null) {
        if (forceInterrupt) {
          await _tts!.stop();
        }
        final res = await _tts!.speak(cleanText);
        if (res == 0) {
          // Retry once if engine was still binding
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await _tts!.speak(cleanText);
        }
      }
    } catch (e) {
      debugPrint('[VoiceCoach] Speak error: $e');
    }
  }

  /// Announces a coaching message both visually and via real spoken TTS + haptics.
  /// Throttles identical messages within [minRepeatInterval] so the user isn't spammed
  /// every frame while adjusting position.
  void announce(
    String message, {
    VoiceCueTone tone = VoiceCueTone.ready,
    bool force = false,
    Duration minRepeatInterval = const Duration(seconds: 4),
  }) {
    if (_disposed) return;
    final now = DateTime.now();
    final isToneChange = _currentTone != tone;
    if (!force &&
        !isToneChange &&
        message == _lastSpokenMessage &&
        _lastSpokenAt != null &&
        now.difference(_lastSpokenAt!) < minRepeatInterval) {
      return;
    }

    final shouldInterrupt =
        force ||
        isToneChange ||
        tone == VoiceCueTone.outOfFrame ||
        tone == VoiceCueTone.completed;

    _currentMessage = message;
    _currentTone = tone;
    _lastSpokenMessage = message;
    _lastSpokenAt = now;
    _isSpeaking = true;
    notifyListeners();

    if (_audioEnabled && !_isFlutterTest) {
      try {
        if (tone == VoiceCueTone.outOfFrame || tone == VoiceCueTone.warning) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.alert);
        } else if (tone == VoiceCueTone.completed) {
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);
        } else {
          HapticFeedback.selectionClick();
        }
        _lastSpeech = _speakNative(message, forceInterrupt: shouldInterrupt);
        unawaited(_lastSpeech);
        final views = WidgetsBinding.instance.platformDispatcher.views;
        if (views.isNotEmpty) {
          SemanticsService.sendAnnouncement(
            views.first,
            message,
            TextDirection.ltr,
          );
        }
      } catch (_) {
        // Safe fallback in headless widget tests
      }
    }

    _speakingTimer?.cancel();
    _speakingTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!_disposed) {
        _isSpeaking = false;
        notifyListeners();
      }
    });
  }

  Future<void>? _lastSpeech;

  /// Rough spoken length of [text] at the coach's rate (fallback when the
  /// engine cannot report completion).
  static Duration estimateSpeech(String text) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return Duration(milliseconds: 500 + words * 340);
  }

  /// [announce], then wait until the sentence has been spoken (engine
  /// completion, capped at about twice the estimated length). Returns at
  /// once when voice is off or under FLUTTER_TEST.
  Future<void> announceAndWait(
    String message, {
    VoiceCueTone tone = VoiceCueTone.ready,
    bool force = true,
  }) async {
    announce(message, tone: tone, force: force);
    if (_disposed || _isFlutterTest || !_audioEnabled) return;
    final est = estimateSpeech(message);
    final speech = _lastSpeech;
    try {
      if (speech != null) {
        await speech.timeout(est * 2 + const Duration(seconds: 2));
      } else {
        await Future<void>.delayed(est);
      }
    } catch (_) {}
  }

  /// Repeats the current instruction aloud when the user taps the banner.
  void repeatCurrent() {
    announce(_currentMessage, tone: _currentTone, force: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _speakingTimer?.cancel();
    _stopNativeSpeech();
    super.dispose();
  }
}

/// Floating glassmorphic AI Voice Coach banner shown at the top of every capture screen.
/// Displays an animated voice equalizer, current spoken instruction, status badge, and mute toggle.
class LiveVoiceCoachBanner extends StatefulWidget {
  const LiveVoiceCoachBanner({
    super.key,
    required this.controller,
    this.onRepeatPressed,
    this.compact = false,
  });

  final VoiceCoachController controller;
  final VoidCallback? onRepeatPressed;

  /// Renders a single-line frosted pill (used on the immersive scanner screens).
  final bool compact;

  @override
  State<LiveVoiceCoachBanner> createState() => _LiveVoiceCoachBannerState();
}

class _LiveVoiceCoachBannerState extends State<LiveVoiceCoachBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final tone = widget.controller.currentTone;
        final speaking =
            widget.controller.isSpeaking && widget.controller.audioEnabled;

        if (widget.compact) return _buildCompact(tone, speaking);

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onRepeatPressed ?? widget.controller.repeatCurrent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: tone.color.withValues(alpha: 0.8),
                width: tone == VoiceCueTone.outOfFrame ? 2.0 : 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: tone.color.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Animated Voice Equalizer / Status Orb
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tone.color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tone.color.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: speaking
                        ? AnimatedBuilder(
                            animation: _animController,
                            builder: (context, _) {
                              final v = _animController.value;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _bar(7 + 9 * v, tone.color),
                                  const SizedBox(width: 2),
                                  _bar(16 - 7 * v, tone.color),
                                  const SizedBox(width: 2),
                                  _bar(9 + 9 * (1 - v), tone.color),
                                  const SizedBox(width: 2),
                                  _bar(13 * v + 5, tone.color),
                                ],
                              );
                            },
                          )
                        : Icon(tone.icon, color: tone.color, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                // Voice Subtitle & Gate Badge (Overflow-proof on 320px+ screens)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tone.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tone.badgeText.toUpperCase(),
                              style: TextStyle(
                                color: tone.color,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Text(
                            widget.controller.audioEnabled
                                ? '🔊 Tap to Repeat Voice'
                                : '🔇 Voice Muted',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"${widget.controller.currentMessage}"',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Mute / Unmute Button
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  tooltip: widget.controller.audioEnabled
                      ? 'Mute Voice Coach'
                      : 'Enable Voice Coach',
                  onPressed: widget.controller.toggleAudio,
                  icon: Icon(
                    widget.controller.audioEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: widget.controller.audioEnabled
                        ? tone.color
                        : Colors.white54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompact(VoiceCueTone tone, bool speaking) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: widget.onRepeatPressed ?? widget.controller.repeatCurrent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tone.color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Center(
                child: speaking
                    ? AnimatedBuilder(
                        animation: _animController,
                        builder: (context, _) {
                          final v = _animController.value;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _bar(5 + 7 * v, tone.color),
                              const SizedBox(width: 2),
                              _bar(12 - 6 * v, tone.color),
                              const SizedBox(width: 2),
                              _bar(6 + 7 * (1 - v), tone.color),
                            ],
                          );
                        },
                      )
                    : Icon(tone.icon, color: tone.color, size: 14),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.controller.currentMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              widget.controller.audioEnabled
                  ? Icons.replay_rounded
                  : Icons.volume_off_rounded,
              size: 13,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double height, Color color) {
    return Container(
      width: 2.5,
      height: height.clamp(4.0, 20.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

/// Describes a hardware permission or sensor requirement needed before starting a scan.
class ScanPermissionItem {
  const ScanPermissionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isMandatory = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isMandatory;
}

/// Interactive Pre-Scan Permission & Sensor Readiness Modal Sheet.
/// Requests real OS runtime permissions (Camera, Microphone) and verifies readiness.
Future<bool> showScanPermissionReadinessModal({
  required BuildContext context,
  required String scanTitle,
  required String scanDuration,
  required List<ScanPermissionItem> permissions,
  required List<String> preparationTips,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _ScanPermissionReadinessSheet(
        scanTitle: scanTitle,
        scanDuration: scanDuration,
        permissions: permissions,
        preparationTips: preparationTips,
      );
    },
  );
  return result ?? false;
}

class _ScanPermissionReadinessSheet extends StatefulWidget {
  const _ScanPermissionReadinessSheet({
    required this.scanTitle,
    required this.scanDuration,
    required this.permissions,
    required this.preparationTips,
  });

  final String scanTitle;
  final String scanDuration;
  final List<ScanPermissionItem> permissions;
  final List<String> preparationTips;

  @override
  State<_ScanPermissionReadinessSheet> createState() =>
      _ScanPermissionReadinessSheetState();
}

class _ScanPermissionReadinessSheetState
    extends State<_ScanPermissionReadinessSheet> {
  late final Map<String, bool> _granted;
  bool _requestingOsPermissions = false;

  @override
  void initState() {
    super.initState();
    _granted = {for (final p in widget.permissions) p.id: true};
  }

  bool get _allMandatoryGranted {
    for (final p in widget.permissions) {
      if (p.isMandatory && !(_granted[p.id] ?? false)) return false;
    }
    return true;
  }

  Future<void> _requestAndStart() async {
    setState(() => _requestingOsPermissions = true);
    try {
      if (!VoiceCoachController._isFlutterTest &&
          !kIsWeb &&
          (Platform.isAndroid || Platform.isIOS)) {
        final needsCam = widget.permissions.any(
          (p) =>
              p.id.contains('cam') ||
              p.id.contains('face') ||
              p.id.contains('rear'),
        );
        final needsMic = widget.permissions.any((p) => p.id.contains('mic'));
        if (needsCam) {
          await Permission.camera.request();
        }
        if (needsMic) {
          await Permission.microphone.request();
        }
        // Gait / sit-to-stand / tremor (G-13): iOS asks for Motion & Fitness;
        // then prove the accelerometer actually delivers events.
        final needsMotion = widget.permissions.any(
          (p) => p.id.contains('motion'),
        );
        if (needsMotion) {
          if (Platform.isIOS) {
            try {
              await Permission.sensors.request();
            } catch (_) {}
          }
          final a = await MotionSensorService.instance.probe(refresh: true);
          if (a == MotionAvailability.unavailable) {
            if (mounted) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Motion sensors unavailable on this device (G-13).',
                  ),
                ),
              );
              Navigator.of(context).pop(false);
            }
            return;
          }
        }
      }
    } catch (_) {
      // Safe fallback on unsupported desktop/test platforms
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111C2D) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B7A75).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF0B7A75),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.scanTitle,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Duration: ${widget.scanDuration} · Hardware & Permission Gate',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'REQUIRED PERMISSIONS & SENSORS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: Color(0xFF0B7A75),
                ),
              ),
              const SizedBox(height: 8),
              ...widget.permissions.map((p) {
                final isOn = _granted[p.id] ?? true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF19263B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOn
                            ? const Color(0xFF10B981).withValues(alpha: 0.45)
                            : const Color(0xFFEF4444).withValues(alpha: 0.45),
                      ),
                    ),
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      secondary: Icon(
                        p.icon,
                        color: isOn
                            ? const Color(0xFF0B7A75)
                            : const Color(0xFFEF4444),
                      ),
                      title: Text(
                        p.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        p.subtitle,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      value: isOn,
                      onChanged: (v) => setState(() => _granted[p.id] = v),
                    ),
                  ),
                );
              }),
              if (widget.preparationTips.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'FOR BEST CLINICAL ACCURACY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: Color(0xFF0B7A75),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B7A75).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: widget.preparationTips
                        .map(
                          (tip) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 15,
                                  color: Color(0xFF0B7A75),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tip,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: _requestingOsPermissions
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        _allMandatoryGranted
                            ? 'Allow & Start Guided Scan'
                            : 'Grant Required Permissions',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed:
                          (_allMandatoryGranted && !_requestingOsPermissions)
                          ? _requestAndStart
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
