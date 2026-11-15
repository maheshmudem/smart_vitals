// Device facts for the overnight sleep check (Doc 07 G-30: phone charging;
// Doc 05 S-G07: Do-not-disturb; Doc 02 FR-232 [DER]: keep recording with
// the screen off). Backed by the `vitalsmirror/sleep` MethodChannel in
// MainActivity.kt; simulated under FLUTTER_TEST and on platforms without
// the channel.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class BatteryStatus {
  const BatteryStatus({
    required this.charging,
    required this.levelPct,
    required this.source,
  });
  final bool charging;
  final int levelPct;

  /// 'device' | 'simulated' | 'unknown'.
  final String source;
}

class SleepDeviceService {
  SleepDeviceService({bool? simulated})
    : simulated = simulated ?? isFlutterTest;

  static const MethodChannel _channel = MethodChannel('vitalsmirror/sleep');

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  final bool simulated;

  /// Test Controls: pretend the charger is out.
  bool simulatedCharging = true;
  bool simulatedDnd = false;
  bool keepAliveRunning = false;
  String? lastError;

  bool get _hasChannel =>
      !simulated && !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<BatteryStatus> battery() async {
    if (simulated) {
      return BatteryStatus(
        charging: simulatedCharging,
        levelPct: 82,
        source: 'simulated',
      );
    }
    if (!_hasChannel) {
      return const BatteryStatus(
        charging: true,
        levelPct: 100,
        source: 'unknown',
      );
    }
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('battery');
      return BatteryStatus(
        charging: m?['charging'] == true,
        levelPct: (m?['level'] as num?)?.round() ?? -1,
        source: 'device',
      );
    } catch (e) {
      lastError = '$e';
      return const BatteryStatus(
        charging: true,
        levelPct: -1,
        source: 'unknown',
      );
    }
  }

  /// True when Do-not-disturb (any interruption filter other than "all")
  /// is on. Null when unknown.
  Future<bool?> dndActive() async {
    if (simulated) return simulatedDnd;
    if (!_hasChannel) return null;
    try {
      return await _channel.invokeMethod<bool>('dnd');
    } catch (e) {
      lastError = '$e';
      return null;
    }
  }

  /// Android 13+: notification permission for the keep-alive notification.
  /// Null when not applicable.
  Future<bool?> requestNotificationPermission() async {
    if (simulated) return true;
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final st = await Permission.notification.request();
      return st.isGranted || st.isLimited;
    } catch (e) {
      lastError = '$e';
      return null;
    }
  }

  /// Starts the microphone foreground service so the recorder keeps
  /// running with the screen off (FR-232 [DER]).
  Future<bool> startKeepAlive({
    String title = 'Sleep monitoring running',
    String text = 'Phone on the bedside table · tap to return',
  }) async {
    if (simulated) {
      keepAliveRunning = true;
      return true;
    }
    if (!_hasChannel || !Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('keepAliveStart', {
        'title': title,
        'text': text,
      });
      keepAliveRunning = ok ?? false;
      return keepAliveRunning;
    } catch (e) {
      lastError = '$e';
      keepAliveRunning = false;
      return false;
    }
  }

  Future<void> stopKeepAlive() async {
    if (!keepAliveRunning) return;
    keepAliveRunning = false;
    if (simulated || !_hasChannel || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('keepAliveStop');
    } catch (e) {
      lastError = '$e';
    }
  }
}
