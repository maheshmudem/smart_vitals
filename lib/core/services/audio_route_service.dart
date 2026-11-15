// Output-route and volume facts for the hearing screen (G-19 earphones
// connected, Spec §8 AUD-09). Android: MethodChannel 'vitalsmirror/audio'
// (MainActivity.kt) with an EventChannel for connect / disconnect; other
// platforms and tests fall back to a manual confirmation.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioRouteState {
  const AudioRouteState({
    required this.type,
    required this.connected,
    required this.volume,
    required this.maxVolume,
    required this.source,
    this.deviceTypes = const [],
  });

  /// 'wired' | 'bluetooth' | 'usb' | 'none' | 'manual' | 'simulated'.
  final String type;
  final bool connected;
  final int volume;
  final int maxVolume;

  /// 'platform' | 'manual' | 'simulated'.
  final String source;

  /// Raw AudioDeviceInfo output types the platform listed (debug line).
  final List<int> deviceTypes;

  bool get volumeAtMax => maxVolume > 0 && volume >= maxVolume;

  String get plainLabel => switch (type) {
    'wired' => 'Wired earphones detected',
    'bluetooth' => 'Bluetooth earphones detected',
    'usb' => 'USB-C earphones detected',
    'manual' => 'Earphones confirmed by you',
    'simulated' => 'Earphones (simulated)',
    _ => 'No earphones detected',
  };
}

class AudioRouteService extends ChangeNotifier {
  AudioRouteService({bool? simulated})
    : simulated = simulated ?? Platform.environment.containsKey('FLUTTER_TEST');

  static const MethodChannel _channel = MethodChannel('vitalsmirror/audio');
  static const EventChannel _events = EventChannel('vitalsmirror/audio/events');

  final bool simulated;
  StreamSubscription<dynamic>? _sub;
  Timer? _poll;

  /// Last platform error, shown on the Prepare card so a failing channel
  /// is visible instead of silently reading "none".
  String? lastError;

  /// Test Controls: simulate an unplug.
  bool simulatedUnplugged = false;

  /// Manual confirmation when the platform cannot detect the route.
  bool manualConfirmed = false;

  AudioRouteState state = const AudioRouteState(
    type: 'none',
    connected: false,
    volume: 0,
    maxVolume: 0,
    source: 'manual',
  );

  bool get platformSupported => !simulated && Platform.isAndroid;

  Future<void> start() async {
    await refresh();
    if (!platformSupported) return;
    _sub ??= _events.receiveBroadcastStream().listen(
      (_) => refresh(),
      onError: (_) {},
    );
    // Some OEM builds do not fire the device callback reliably; poll too.
    _poll ??= Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  Future<void> refresh() async {
    if (simulated) {
      state = AudioRouteState(
        type: simulatedUnplugged ? 'none' : 'simulated',
        connected: !simulatedUnplugged,
        volume: 15,
        maxVolume: 15,
        source: 'simulated',
      );
      notifyListeners();
      return;
    }
    if (!platformSupported) {
      state = AudioRouteState(
        type: manualConfirmed ? 'manual' : 'none',
        connected: manualConfirmed,
        volume: 0,
        maxVolume: 0,
        source: 'manual',
      );
      notifyListeners();
      return;
    }
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('outputs');
      lastError = null;
      var type = (m?['earphoneType'] as String?) ?? 'none';
      // Not detected but confirmed by the member: allowed, recorded as
      // 'manual' in the result quality.
      if (type == 'none' && manualConfirmed) type = 'manual';
      state = AudioRouteState(
        type: type,
        connected: type != 'none',
        volume: (m?['volume'] as num?)?.toInt() ?? 0,
        maxVolume: (m?['maxVolume'] as num?)?.toInt() ?? 0,
        source: type == 'manual' ? 'manual' : 'platform',
        deviceTypes: [
          for (final t in (m?['deviceTypes'] as List?) ?? const [])
            if (t is num) t.toInt(),
        ],
      );
    } catch (e) {
      lastError = '$e';
      state = AudioRouteState(
        type: manualConfirmed ? 'manual' : 'none',
        connected: manualConfirmed,
        volume: 0,
        maxVolume: 0,
        source: 'manual',
      );
    }
    notifyListeners();
  }

  /// Sets the media volume to a fraction of maximum (sleep sonar plays the
  /// inaudible chirp at 70 %). Returns false when unsupported.
  Future<bool> setVolumeFraction(double fraction) async {
    if (simulated) return true;
    if (!platformSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setVolumeFraction', {
        'fraction': fraction.clamp(0.0, 1.0),
      });
      await refresh();
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sets the media volume to maximum (Android); returns whether it is.
  Future<bool> ensureMaxVolume() async {
    if (simulated) return true;
    if (!platformSupported) return false;
    try {
      await _channel.invokeMethod<void>('setMaxVolume');
      await refresh();
      return state.volumeAtMax;
    } catch (_) {
      return false;
    }
  }

  void setManualConfirmed(bool v) {
    manualConfirmed = v;
    unawaited(refresh());
  }

  void setSimulatedUnplugged(bool v) {
    simulatedUnplugged = v;
    unawaited(refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    super.dispose();
  }
}
