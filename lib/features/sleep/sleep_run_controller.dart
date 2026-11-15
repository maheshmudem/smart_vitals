// State machine for the overnight sleep sonar night (Doc 07 F-21:
// ready → processing (overnight) → success / partial; Doc 05 S-G08 states:
// running / paused (charger disconnected) / interrupted / stopped).
//
// Consumes 20 Hz features from [SleepSonarService], cuts them into 30-s
// epochs through [BreathWaveExtractor] and scores events incrementally
// with [ApnoeaScorer]. Time comes from the feature timestamps, so a
// simulated "fast night" runs under the test clock.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/domain/algorithms/sleep_engines.dart';
import '../../core/domain/entities/sleep_protocol.dart';
import '../../core/services/sleep_device_service.dart';
import '../../core/services/sleep_sonar_service.dart';

enum SleepPhase { idle, running, paused, interrupted, stopped, processing }

class SleepRunController extends ChangeNotifier {
  SleepRunController({
    required this.protocol,
    required this.sonar,
    required this.device,
    this.onSpeak,
    this.demoOutcome = SleepDemoOutcome.normal,
    double floorDb = -80,
  }) : _extractor = BreathWaveExtractor(floorDb: floorDb);

  final SleepProtocol protocol;
  final SleepSonarService sonar;
  final SleepDeviceService device;
  final Future<void> Function(String text, {bool warning})? onSpeak;
  SleepDemoOutcome demoOutcome;

  static const int chargerPollSeconds = 5;
  static const int unpluggedWarnAfterS = 60;
  static const int unpluggedRepeatS = 300;

  SleepPhase phase = SleepPhase.idle;
  DateTime? startedAt;
  DateTime? endedAt;
  String coaching = '';

  final List<SonarEpoch> epochs = [];
  List<SleepEvent> events = const [];
  final List<SonarFeature> _pending = [];
  int _epochIndex = 0;
  final BreathWaveExtractor _extractor;
  final ApnoeaScorer _scorer = const ApnoeaScorer();

  Timer? _tick;
  Timer? _charger;
  bool charging = true;
  bool chargingAtStart = true;
  int batteryPct = -1;
  int unpluggedS = 0;
  int _lastUnpluggedWarnS = -unpluggedRepeatS;
  int interruptions = 0;
  bool _wasInterrupted = false;
  String stopReason = 'stopped';

  /// Seconds of audio processed (from feature timestamps).
  double elapsedS = 0;
  double? liveRr;
  bool echoOk = true;
  int _echoLostStreak = 0;
  bool _echoHintSaid = false;

  int get validEpochs => epochs.where((e) => e.valid).length;
  double get validSleepH => validEpochs * SonarEpoch.seconds / 3600;
  double get recordedH => elapsedS / 3600;
  bool get enoughForAhi => validSleepH >= SleepProtocol.minValidSleepH;
  int get apnoeas =>
      events.where((e) => e.type == SleepEventType.apnoea).length;
  int get hypopnoeas =>
      events.where((e) => e.type == SleepEventType.hypopnoea).length;
  bool get isNight =>
      phase == SleepPhase.running ||
      phase == SleepPhase.paused ||
      phase == SleepPhase.interrupted;

  /// Median SONAR_RR so far over valid epochs.
  double? get medianRr {
    final v = epochs.where((e) => e.valid).map((e) => e.rr!).toList()..sort();
    return v.isEmpty ? null : v[v.length ~/ 2];
  }

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  Future<bool> start() async {
    if (phase != SleepPhase.idle && phase != SleepPhase.stopped) return true;
    startedAt = DateTime.now();
    epochs.clear();
    events = const [];
    _pending.clear();
    _epochIndex = 0;
    elapsedS = 0;
    unpluggedS = 0;
    interruptions = 0;
    liveRr = null;
    echoOk = true;
    sonar.simulatedOutcome = demoOutcome.name;
    final b = await device.battery();
    charging = b.charging;
    chargingAtStart = b.charging;
    batteryPct = b.levelPct;
    final ok = await sonar.start();
    if (!ok) {
      phase = SleepPhase.stopped;
      stopReason = 'no_audio';
      coaching = sonar.permissionDenied
          ? 'Microphone permission needed (G-12)'
          : 'Could not open the microphone';
      notifyListeners();
      return false;
    }
    phase = SleepPhase.running;
    coaching = 'Monitoring';
    sonar.addListener(_onSonar);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _charger?.cancel();
    _charger = Timer.periodic(
      const Duration(seconds: chargerPollSeconds),
      (_) => _pollCharger(),
    );
    notifyListeners();
    unawaited(onSpeak?.call(protocol.voiceStart));
    return true;
  }

  void _onSonar() {
    if (!isNight) return;
    final fresh = sonar.takeNewFeatures();
    if (fresh.isNotEmpty) {
      _pending.addAll(fresh);
      elapsedS = fresh.last.t;
      _cutEpochs();
    }
    // interruption bookkeeping
    if (sonar.interrupted && !_wasInterrupted) {
      _wasInterrupted = true;
      interruptions++;
      if (phase == SleepPhase.running) phase = SleepPhase.interrupted;
      coaching = 'Microphone interrupted — restarting';
      notifyListeners();
    } else if (!sonar.interrupted && _wasInterrupted) {
      _wasInterrupted = false;
      if (phase == SleepPhase.interrupted) {
        phase = charging ? SleepPhase.running : SleepPhase.paused;
      }
      coaching = 'Monitoring';
      notifyListeners();
    }
  }

  void _cutEpochs() {
    final per = (SonarEpoch.seconds * SleepSimulated.featureHz).round();
    var changed = false;
    while (_pending.length >= per) {
      final chunk = _pending.sublist(0, per);
      _pending.removeRange(0, per);
      final e = _extractor.epoch(_epochIndex++, chunk);
      epochs.add(e);
      changed = true;
      if (e.valid) {
        liveRr = e.rr;
        _echoLostStreak = 0;
        echoOk = true;
      } else {
        _echoLostStreak++;
        if (_echoLostStreak >= 2) {
          echoOk = false;
          if (!_echoHintSaid) {
            _echoHintSaid = true;
            unawaited(onSpeak?.call(protocol.echoLostHint, warning: true));
          }
        }
      }
    }
    if (changed) {
      _rescoreTail();
      notifyListeners();
    }
  }

  /// Incremental scoring: events depend only on the preceding 60 s
  /// baseline and the 15 s after they end, so only the last 12 epochs are
  /// rescored (every 4th epoch); events older than that window are final.
  static const int _tailEpochs = 12;
  static const int _contextEpochs = 2;

  void _rescoreTail() {
    if (epochs.length % 4 != 0) return;
    final from = math.max(0, epochs.length - _tailEpochs);
    final scoreFrom = math.max(0, from - _contextEpochs);
    final boundaryS = epochs[from].startS;
    final fresh = _scorer
        .score(epochs.sublist(scoreFrom))
        .where((e) => e.startS >= boundaryS);
    // events that started before the boundary had their full context in
    // an earlier pass and are final; the tail is replaced
    final kept = events.where((e) => e.startS < boundaryS);
    events = [...kept, ...fresh];
  }

  void _onTick() {
    if (!isNight) return;
    if (!charging) {
      unpluggedS += 1;
      if (unpluggedS >= unpluggedWarnAfterS &&
          unpluggedS - _lastUnpluggedWarnS >= unpluggedRepeatS) {
        _lastUnpluggedWarnS = unpluggedS;
        unawaited(onSpeak?.call(protocol.unpluggedWarning, warning: true));
      }
    }
    if (sonar.simulated && sonar.running) {
      // the simulated night ends by itself: stop when its epochs are done
      final total = SleepSimulated.epochCount(demoOutcome.name);
      if (_epochIndex >= total && autoStop) {
        unawaited(stop(reason: 'auto'));
        return;
      }
    }
    notifyListeners();
  }

  /// Simulated nights stop themselves once their epochs are consumed
  /// (Test Controls "Fast night"); a real night waits for the member.
  bool autoStop = true;

  Future<void> _pollCharger() async {
    if (!isNight) return;
    final b = await device.battery();
    if (!isNight) return;
    batteryPct = b.levelPct;
    if (b.charging == charging) return;
    charging = b.charging;
    if (!charging) {
      if (phase == SleepPhase.running) phase = SleepPhase.paused;
      coaching = 'Charger disconnected';
      unawaited(onSpeak?.call(protocol.unpluggedWarning, warning: true));
    } else {
      if (phase == SleepPhase.paused) phase = SleepPhase.running;
      coaching = 'Monitoring';
      unawaited(onSpeak?.call('Charger connected. Good night.'));
    }
    notifyListeners();
  }

  /// Test Controls: force the charger state (simulated device).
  Future<void> setSimulatedCharging(bool on) async {
    device.simulatedCharging = on;
    await _pollCharger();
  }

  /// Member long-pressed Stop (or the simulated night finished).
  Future<void> stop({String reason = 'stopped'}) async {
    if (!isNight) return;
    _tick?.cancel();
    _charger?.cancel();
    sonar.removeListener(_onSonar);
    // flush what is left of the sonar stream
    final fresh = sonar.takeNewFeatures();
    if (fresh.isNotEmpty) {
      _pending.addAll(fresh);
      elapsedS = fresh.last.t;
    }
    _cutEpochs();
    await sonar.stop();
    endedAt = DateTime.now();
    stopReason = reason == 'stopped' && !enoughForAhi ? 'short' : reason;
    events = _scorer.score(epochs); // one full pass at the end
    phase = SleepPhase.processing;
    coaching = 'Analysing the night';
    notifyListeners();
    unawaited(onSpeak?.call(protocol.voiceDone));
  }

  Future<void> abort() async {
    _tick?.cancel();
    _charger?.cancel();
    sonar.removeListener(_onSonar);
    await sonar.stop();
    phase = SleepPhase.stopped;
    stopReason = 'aborted';
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _charger?.cancel();
    sonar.removeListener(_onSonar);
    super.dispose();
  }

  /// Wall-clock seconds since start (clock on the night screen).
  int get wallSeconds =>
      startedAt == null ? 0 : DateTime.now().difference(startedAt!).inSeconds;

  /// Progress towards the 4 h minimum (ring on the night screen).
  double get validProgress =>
      (validSleepH / SleepProtocol.minValidSleepH).clamp(0.0, 1.0);

  /// Last 120 epochs' breathing rates for the live strip.
  List<double?> get recentRr => [
    for (final e in epochs.skip(math.max(0, epochs.length - 120)))
      e.valid ? e.rr : null,
  ];
}
