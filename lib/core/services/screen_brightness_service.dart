// Screen brightness for the vision tests (Spec §9 MOV-11: brightness 100 %,
// "auto-boost brightness before starting"). Uses screen_brightness; silent
// no-op under FLUTTER_TEST or where the platform has no control (desktop).
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';

class ScreenBrightnessService {
  ScreenBrightnessService._();

  static final ScreenBrightnessService instance = ScreenBrightnessService._();

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  bool _boosted = false;
  bool _dimmed = false;

  /// 'boosted' when the app set 100 %, 'manual' when it could not.
  String mode = 'manual';

  /// Current application brightness 0..1 when readable.
  double? lastLevel;

  Future<void> boostToMax() async {
    if (isFlutterTest || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      mode = 'manual';
      return;
    }
    try {
      final sb = ScreenBrightness.instance;
      lastLevel = await sb.application;
      await sb.setApplicationScreenBrightness(1.0);
      _boosted = true;
      mode = 'boosted';
    } catch (_) {
      mode = 'manual';
    }
  }

  /// Night mode (Spec S-G08 OLED-friendly): lowest application brightness.
  Future<void> dimForNight() async {
    if (isFlutterTest || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    try {
      final sb = ScreenBrightness.instance;
      lastLevel ??= await sb.application;
      await sb.setApplicationScreenBrightness(0.02);
      _dimmed = true;
    } catch (_) {}
  }

  Future<void> restore() async {
    if (!_boosted && !_dimmed) return;
    _boosted = false;
    _dimmed = false;
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }
}
