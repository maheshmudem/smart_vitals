// Output of one overnight sleep session (Doc 11 SleepSessionResult:
// valid_sleep_h, sonar_rr_epochs, apnoea_events, hypopnoea_events, ahi_est,
// osa_band, ring_spo2_connected).
import '../algorithms/risk_engine.dart' show PersonalBaselineResult;
import '../algorithms/sleep_engines.dart';
import 'enums.dart';
import 'marker_envelope.dart';
import 'sleep_protocol.dart';

class SleepQualityFacts {
  const SleepQualityFacts({
    this.audioSource = 'simulated',
    this.sampleRate = 48000,
    this.chirpPlayed = false,
    this.sonarCheckPassed,
    this.sonarCheckDb,
    this.micSelfCheckPassed,
    this.micDeviationDb,
    this.chargingAtStart = true,
    this.unpluggedSeconds = 0,
    this.invalidEpochs = 0,
    this.totalEpochs = 0,
    this.interruptions = 0,
    this.keepAliveUsed = false,
    this.notificationAllowed,
    this.dndOn,
    this.snoreFraction = 0,
    this.stopReason = 'stopped',
    this.simulated = true,
  });

  /// 'stream' | 'simulated' | 'none'.
  final String audioSource;
  final int sampleRate;
  final bool chirpPlayed;

  /// Sonar echo check in Setup: null when not run.
  final bool? sonarCheckPassed;

  /// Echo above floor during the check, dB.
  final double? sonarCheckDb;
  final bool? micSelfCheckPassed;
  final double? micDeviationDb;
  final bool chargingAtStart;
  final int unpluggedSeconds;
  final int invalidEpochs;
  final int totalEpochs;

  /// Microphone stream restarts during the night.
  final int interruptions;

  /// Foreground service kept the recording alive with the screen off.
  final bool keepAliveUsed;
  final bool? notificationAllowed;
  final bool? dndOn;

  /// Fraction of valid seconds with snore-like bursts (support value).
  final double snoreFraction;

  /// 'stopped' | 'short' | 'interrupted' | 'auto'.
  final String stopReason;
  final bool simulated;

  double get invalidFraction =>
      totalEpochs == 0 ? 0 : invalidEpochs / totalEpochs;

  double get captureQualityScore {
    var s = 0.95;
    if (audioSource != 'stream') s -= 0.05;
    if (sonarCheckPassed == false) s -= 0.20;
    if (sonarCheckPassed == null) s -= 0.05;
    if (micSelfCheckPassed == false) s -= 0.05;
    if (invalidFraction > 0.25) s -= 0.15;
    if (invalidFraction > 0.10 && invalidFraction <= 0.25) s -= 0.05;
    if (unpluggedSeconds > 600) s -= 0.05;
    if (interruptions > 0) s -= 0.05 * interruptions.clamp(0, 2);
    return s.clamp(0.4, 1.0);
  }
}

class SleepSessionResult {
  const SleepSessionResult({
    required this.sessionId,
    required this.subjectId,
    required this.subjectName,
    required this.ageYears,
    required this.sex,
    required this.protocol,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.validSleepH,
    required this.recordedH,
    required this.rrEpochs,
    required this.epochValid,
    required this.medianRr,
    required this.apnoeaEvents,
    required this.hypopnoeaEvents,
    required this.ahiEst,
    required this.osaBand,
    required this.events,
    required this.markers,
    required this.band,
    required this.bandTitle,
    required this.bandSubline,
    required this.whatItMeans,
    required this.urgency,
    required this.firedRuleCodes,
    required this.confidence,
    required this.quality,
    required this.partial,
    required this.demoOutcome,
    this.ringConnected = false,
    this.baseline,
    this.rrBaseline,
  });

  final String sessionId;
  final String subjectId;
  final String subjectName;
  final int ageYears;
  final BiologicalSex sex;
  final SleepProtocol protocol;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double validSleepH;
  final double recordedH;

  /// SONAR_RR per 30-s epoch (null = invalid epoch).
  final List<double?> rrEpochs;
  final List<bool> epochValid;
  final double? medianRr;
  final int apnoeaEvents;
  final int hypopnoeaEvents;

  /// null when the night was too short (E-AUD-003).
  final double? ahiEst;
  final OsaBand? osaBand;
  final List<SleepEvent> events;
  final Map<String, MarkerEnvelope<dynamic>> markers;
  final SemanticBand band;
  final String bandTitle;
  final String bandSubline;
  final String whatItMeans;
  final UrgencyLevel urgency;
  final List<String> firedRuleCodes;
  final double confidence;
  final SleepQualityFacts quality;

  /// VALID_SLEEP_H < 4 h: breathing rate only.
  final bool partial;
  final SleepDemoOutcome demoOutcome;
  final bool ringConnected;

  /// Baseline of AHI_EST over the last 180 days.
  final PersonalBaselineResult? baseline;

  /// Baseline of SONAR_RR over the last 180 days.
  final PersonalBaselineResult? rrBaseline;

  DateTime get recordedAt => endedAt;
  int get totalEvents => apnoeaEvents + hypopnoeaEvents;
  bool get isNotAssessed => medianRr == null;

  SleepEvent? get longestEvent {
    SleepEvent? best;
    for (final e in events) {
      if (best == null || e.durationS > best.durationS) best = e;
    }
    return best;
  }
}
