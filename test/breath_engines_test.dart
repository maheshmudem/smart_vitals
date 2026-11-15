import 'dart:math' as math;

import 'package:algoritam/core/domain/algorithms/breath_engines.dart';
import 'package:algoritam/core/domain/entities/breath_protocol.dart';
import 'package:algoritam/core/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sr = 16000;

  group('Breathing & Voice engines (ALG-AUD-01/03/04/05/06, CAP-11)', () {
    test('cough detector counts bursts and rejects hum and click', () {
      final four = CoughDetector.detect(
        BreathSimulated.coughs(n: 4, seconds: 13),
        sr,
      );
      expect(four.count, 4);
      for (final e in four.events) {
        expect(e.durationMs, inInclusiveRange(150, 800));
        expect(e.prob, greaterThanOrEqualTo(0.5));
        expect(e.riseDb, greaterThan(12));
      }
      expect(four.enough, isTrue);
      final two = CoughDetector.detect(BreathSimulated.coughs(n: 2), sr);
      expect(two.count, 2);
      expect(two.enough, isFalse);
      expect(CoughDetector.detect(BreathSimulated.hum(), sr).count, 0);
      expect(CoughDetector.detect(BreathSimulated.click(), sr).count, 0);
      expect(CoughDetector.detect(BreathSimulated.silence(), sr).count, 0);
      // wet coughs carry more low-frequency energy in the tail
      final wet = CoughDetector.detect(
        BreathSimulated.coughs(n: 3, wetness: 0.9),
        sr,
      );
      final dry = CoughDetector.detect(
        BreathSimulated.coughs(n: 3, wetness: 0.0),
        sr,
      );
      expect(wet.meanWetness, greaterThan(dry.meanWetness));
    });

    test('live burst counter follows the level meter', () {
      final c = LiveBurstCounter();
      for (var i = 0; i < 150; i++) {
        final t = i / 10;
        final burst =
            (t >= 2.5 && t < 2.8) ||
            (t >= 5 && t < 5.3) ||
            (t >= 7.5 && t < 7.8);
        c.add(t, burst ? 0.9 : 0.12);
      }
      expect(c.count, 3);
      // a long hum is not a burst
      final h = LiveBurstCounter();
      for (var i = 0; i < 60; i++) {
        h.add(i / 10, i >= 10 && i < 40 ? 0.8 : 0.1);
      }
      expect(h.count, 0);
    });

    test('wheeze detector finds a ≥ 100 ms tone and not noise', () {
      final w = WheezeDetector.detect(
        BreathSimulated.breathSounds(wheeze: true),
        sr,
      );
      expect(w.segments, greaterThan(0));
      expect(w.wheezeShare, greaterThan(0.15));
      expect(w.dominantHz, closeTo(420, 40));
      final n = WheezeDetector.detect(
        BreathSimulated.breathSounds(wheeze: false),
        sr,
      );
      expect(n.wheezeShare, lessThan(0.05));
    });

    test('exhale analyser: duration, first-second share, repeatability', () {
      final normal = ExhaleAnalyzer.analyze(BreathSimulated.exhale(), sr);
      expect(normal.durationS, closeTo(5.0, 0.4));
      expect(normal.longEnough, isTrue);
      expect(normal.fev1Fraction, greaterThan(0.68));
      expect(normal.peakAtS, lessThan(0.5));
      expect(normal.curve.length, greaterThan(20));
      final obstructed = ExhaleAnalyzer.analyze(
        BreathSimulated.exhale(obstructed: true),
        sr,
      );
      expect(obstructed.durationS, closeTo(7.0, 0.5));
      expect(obstructed.fev1Fraction, lessThan(0.58));
      final short = ExhaleAnalyzer.analyze(
        BreathSimulated.exhale(seconds: 1.8),
        sr,
      );
      expect(short.longEnough, isFalse);
      expect(
        ExhaleAnalyzer.analyze(BreathSimulated.silence(), sr).heard,
        isFalse,
      );

      final pred = SpirometryReference.predict(
        sex: BiologicalSex.male,
        heightCm: 170,
        ageYears: 62,
      );
      final est = AudioSpirometry.estimate([
        normal,
        ExhaleAnalyzer.analyze(BreathSimulated.exhale(seed: 23), sr),
        ExhaleAnalyzer.analyze(BreathSimulated.exhale(seed: 29), sr),
      ], pred);
      expect(est.validCount, 3);
      expect(est.repeatable, isTrue);
      expect(est.repeatabilityDiffPct, lessThan(10));
      expect(est.fvcPredPct!, closeTo(100, 12));
      expect(est.belowLln, isFalse);
      final obs = AudioSpirometry.estimate([obstructed, obstructed], pred);
      expect(obs.ratio!, lessThan(pred.ratioLln));
      expect(obs.belowLln, isTrue);
      final mixed = AudioSpirometry.estimate([normal, obstructed], pred);
      expect(mixed.repeatable, isFalse);
      expect(AudioSpirometry.estimate([short], pred).best, isNull);
    });

    test('ECSC-1993 predicted values and LLN (FRM-13 stand-in)', () {
      final m = SpirometryReference.predict(
        sex: BiologicalSex.male,
        heightCm: 170,
        ageYears: 62,
      );
      expect(m.fev1, closeTo(3.02, 0.03));
      expect(m.fvc, closeTo(3.84, 0.03));
      expect(m.ratioLln, closeTo(0.64, 0.01));
      expect(m.pef, closeTo(7.9, 0.1));
      expect(m.ageInRange, isTrue);
      final f = SpirometryReference.predict(
        sex: BiologicalSex.female,
        heightCm: 160,
        ageYears: 29,
      );
      expect(f.fev1, closeTo(3.0, 0.03));
      expect(f.fvc, closeTo(3.44, 0.03));
      expect(f.ratio, closeTo(0.836, 0.005));
      expect(
        SpirometryReference.predict(
          sex: BiologicalSex.male,
          heightCm: 150,
          ageYears: 12,
        ).ageInRange,
        isFalse,
      );
    });

    test('voice quality: MPT, middle 3 s, norms, s/z, CPPS', () {
      final p = BreathSimulated.voiceParams(BreathDemoOutcome.normal);
      final v = VoiceQuality.analyze(
        aaa: BreathSimulated.phonation(
          seconds: p.mpt,
          f0: p.f0,
          jitterPct: p.jitter,
          shimmerPct: p.shimmer,
          noise: p.noise,
        ),
        sss: BreathSimulated.fricative(seconds: 12),
        zzz: BreathSimulated.fricative(seconds: 11, voiced: true),
        sr: sr,
      );
      expect(v.mptS, closeTo(18, 0.6));
      expect(v.f0Hz, closeTo(140, 6));
      expect(v.jitterPct, lessThan(VoiceQuality.jitterMaxPct));
      expect(v.shimmerPct, lessThan(VoiceQuality.shimmerMaxPct));
      expect(v.hnrDb, greaterThan(VoiceQuality.hnrMinDb));
      expect(v.szRatio!, closeTo(12 / 11, 0.1));
      expect(v.bandOf('SZ_RATIO'), SemanticBand.normal);
      expect(v.bandOf('MPT_S'), SemanticBand.normal);
      expect(v.outsideNormCount, 0);
      expect(v.cppsDb, greaterThan(5));
      final r = BreathSimulated.voiceParams(BreathDemoOutcome.refer);
      final hoarse = VoiceQuality.analyze(
        aaa: BreathSimulated.phonation(
          seconds: r.mpt,
          f0: r.f0,
          jitterPct: r.jitter,
          shimmerPct: r.shimmer,
          noise: r.noise,
        ),
        sss: BreathSimulated.fricative(seconds: 9),
        zzz: BreathSimulated.fricative(seconds: 5, voiced: true),
        sr: sr,
      );
      expect(hoarse.mptS, closeTo(7, 0.6));
      expect(hoarse.jitterPct, greaterThan(VoiceQuality.jitterMaxPct));
      expect(hoarse.hnrDb, lessThan(v.hnrDb));
      expect(hoarse.cppsDb, lessThan(v.cppsDb));
      expect(hoarse.szRatio!, greaterThan(VoiceQuality.szMaxRatio));
      expect(hoarse.outsideNormCount, greaterThanOrEqualTo(3));
      // too short to analyse
      final short = VoiceQuality.analyze(
        aaa: BreathSimulated.phonation(seconds: 1.5),
        sr: sr,
      );
      expect(short.phonationOk, isFalse);
    });

    test('TB symptom rule and heuristic band', () {
      expect(
        TbSymptoms.classic(BreathSimulated.tbAnswers(BreathDemoOutcome.normal)),
        isFalse,
      );
      expect(
        TbSymptoms.classic(
          BreathSimulated.tbAnswers(BreathDemoOutcome.borderline),
        ),
        isFalse,
      );
      expect(
        TbSymptoms.classic(BreathSimulated.tbAnswers(BreathDemoOutcome.refer)),
        isTrue,
      );
      expect(TbSymptoms.classic({'tb_blood': 1}), isTrue);
      expect(TbSymptoms.classic({'tb_fever': 1, 'tb_weight': 1}), isTrue);
      final coughs = CoughDetector.detect(BreathSimulated.coughs(n: 3), sr);
      final pNormal = TbModel.prob(
        coughs: coughs,
        symptoms: BreathSimulated.tbAnswers(BreathDemoOutcome.normal),
      );
      expect(pNormal, lessThan(TbModel.tau));
      expect(TbModel.band(pNormal, classicSymptoms: false), SemanticBand.low);
      expect(TbModel.band(0.2, classicSymptoms: true), SemanticBand.high);
      final pRefer = TbModel.prob(
        coughs: coughs,
        symptoms: BreathSimulated.tbAnswers(BreathDemoOutcome.refer),
      );
      expect(pRefer, greaterThan(pNormal));
    });

    test('OAD score bands and asthma-vs-COPD lean', () {
      final low = OadModel.score(
        wheezeShare: 0,
        ratio: 0.8,
        ratioLln: 0.64,
        mmrc: 0,
        exposureAnswers: BreathSimulated.exposureAnswers(
          BreathDemoOutcome.normal,
        ),
      );
      expect(low.band, SemanticBand.low);
      final high = OadModel.score(
        wheezeShare: 0.3,
        ratio: 0.5,
        ratioLln: 0.64,
        mmrc: 3,
        exposureAnswers: BreathSimulated.exposureAnswers(
          BreathDemoOutcome.refer,
        ),
        ageYears: 62,
      );
      expect(high.band, SemanticBand.high);
      expect(high.asthmaVsCopd, lessThan(0.5));
      final asthma = OadModel.score(
        wheezeShare: 0.3,
        ratio: 0.6,
        ratioLln: 0.64,
        mmrc: 1,
        exposureAnswers: BreathSimulated.exposureAnswers(
          BreathDemoOutcome.normal,
        ),
        ageYears: 25,
      );
      expect(asthma.asthmaVsCopd, greaterThan(0.5));
      expect(asthma.band, isNot(SemanticBand.low));
      expect(ExposureScore.of({'exp_smoke': 2, 'exp_years': 3}), 1.0);
    });

    test('mic self-check: flat sweep passes, notched fails, silence fails', () {
      final sweep = MicSelfCheck.sweep(sr);
      List<int> pcm(List<double> xs, {double gain = 0.5}) => [
        for (final x in xs) (x * gain * 32767).round().clamp(-32768, 32767),
      ];
      final lead = List<double>.filled(sr ~/ 2, 0);
      final flat = MicSelfCheck.evaluate(pcm([...lead, ...sweep, ...lead]), sr);
      expect(flat.sweepHeard, isTrue);
      expect(flat.deviationDb, lessThanOrEqualTo(MicSelfCheck.maxDeviationDb));
      expect(flat.processingDetected, isFalse);
      expect(flat.passed, isTrue);
      // a covered mic: everything above 1 kHz is 20 dB down
      final notched = List<double>.from(sweep);
      final n = notched.length;
      for (var i = 0; i < n; i++) {
        final t = i / sr;
        final hz = 100 * math.exp(math.log(80) * t / MicSelfCheck.sweepS);
        if (hz > 1000) notched[i] *= 0.1;
      }
      // without a stored profile a notched phone still passes and records
      // its own profile; against the flat profile it fails
      final unprofiled = MicSelfCheck.evaluate(
        pcm([...lead, ...notched, ...lead]),
        sr,
      );
      expect(unprofiled.passed, isTrue);
      expect(unprofiled.profileRecorded, isTrue);
      final fail = MicSelfCheck.evaluate(
        pcm([...lead, ...notched, ...lead]),
        sr,
        baselineRel: flat.bandsDb,
      );
      expect(fail.deviationDb, greaterThan(MicSelfCheck.maxDeviationDb));
      expect(fail.passed, isFalse);
      final silent = MicSelfCheck.evaluate(BreathSimulated.silence(), sr);
      expect(silent.sweepHeard, isFalse);
      expect(silent.passed, isFalse);
    });

    test(
      'live frame detector: coughs, phonation, exhale on streamed frames',
      () {
        List<double> frames(List<int> s) {
          final out = <double>[];
          for (var off = 0; off + 160 <= s.length; off += 160) {
            var acc = 0.0;
            for (var i = 0; i < 160; i++) {
              final v = s[off + i].toDouble();
              acc += v * v;
            }
            out.add(
              20 *
                  math.log(math.max(math.sqrt(acc / 160), 1e-3) / 32768) /
                  math.ln10,
            );
          }
          return out;
        }

        // coughs: three accepted, nothing rejected, quiet after the last one
        final c = LiveFrameDetector(LiveMode.cough);
        final coughFrames = frames(BreathSimulated.coughs(n: 3));
        for (var i = 0; i < coughFrames.length; i += 10) {
          c.addFrames(
            coughFrames.sublist(i, math.min(i + 10, coughFrames.length)),
          );
        }
        expect(c.accepted, 3);
        expect(c.rejected, 0);
        expect(c.quietForS, greaterThan(1.5));
        expect(c.lastAcceptedAtS, closeTo(7.3, 0.3));
        // a 2 s hum is one long burst → rejected as too long
        final h = LiveFrameDetector(LiveMode.cough);
        h.addFrames(
          frames([
            ...BreathSimulated.silence(seconds: 1),
            ...BreathSimulated.hum(),
            ...BreathSimulated.silence(seconds: 1),
          ]),
        );
        expect(h.accepted, 0);
        expect(h.rejected, 1);
        expect(h.lastRejectReason, 'too long');
        // a soft "sss" counts as voiced for its whole length
        final v = LiveFrameDetector(LiveMode.phonation);
        v.addFrames(frames(BreathSimulated.fricative(seconds: 6)));
        expect(v.voicedS, closeTo(6, 0.5));
        expect(v.longestRunS, closeTo(6, 0.5));
        expect(v.silentForS, closeTo(0.5, 0.3));
        // exhale: blow starts after the lead, ends after the tail
        final e = LiveFrameDetector(LiveMode.exhale);
        final blowFrames = frames(BreathSimulated.exhale());
        var endedAt = -1.0;
        for (var i = 0; i < blowFrames.length; i++) {
          e.addFrames([blowFrames[i]]);
          if (e.blowEnded && endedAt < 0) endedAt = e.elapsedS;
        }
        expect(e.blowing, isTrue);
        expect(e.blowStartS, closeTo(0.6, 0.2));
        expect(e.blowEnded, isTrue);
        expect(endedAt, closeTo(6.4, 0.4));
        expect(e.levelNorm, lessThan(0.2));
        // amplitude fallback at 100 ms frames still counts coughs
        final a = LiveFrameDetector(LiveMode.cough, frameMs: 100);
        final f10 = frames(BreathSimulated.coughs(n: 3));
        a.addFrames([
          for (var i = 0; i + 10 <= f10.length; i += 10)
            f10.sublist(i, i + 10).reduce(math.max),
        ]);
        expect(a.accepted, 3);
      },
    );

    test('mic self-check against this phone\'s profile', () {
      final sweep = MicSelfCheck.sweep(sr);
      List<int> pcm(List<double> xs, {double gain = 0.5}) => [
        for (final x in xs) (x * gain * 32767).round().clamp(-32768, 32767),
      ];
      final lead = List<double>.filled(sr ~/ 2, 0);
      // a phone whose speaker is 15 dB weak below 500 Hz: first run records
      // the profile and passes without a deviation
      final uneven = List<double>.from(sweep);
      for (var i = 0; i < uneven.length; i++) {
        final t = i / sr;
        final hz = 100 * math.exp(math.log(80) * t / MicSelfCheck.sweepS);
        if (hz < 500) uneven[i] *= 0.18;
      }
      final first = MicSelfCheck.evaluate(
        pcm([...lead, ...uneven, ...lead]),
        sr,
      );
      expect(first.passed, isTrue);
      expect(first.profileRecorded, isTrue);
      expect(first.comparedToProfile, isFalse);
      expect(first.fixedProfileDeviationDb, greaterThan(4));
      // same phone again → compared, tiny deviation
      final again = MicSelfCheck.evaluate(
        pcm([...lead, ...uneven, ...lead], gain: 0.4),
        sr,
        baselineRel: first.bandsDb,
      );
      expect(again.comparedToProfile, isTrue);
      expect(again.deviationDb, lessThan(1.5));
      expect(again.passed, isTrue);
      // finger over the mic: everything above 2 kHz 20 dB down → fails
      final covered = List<double>.from(uneven);
      for (var i = 0; i < covered.length; i++) {
        final t = i / sr;
        final hz = 100 * math.exp(math.log(80) * t / MicSelfCheck.sweepS);
        if (hz > 2000) covered[i] *= 0.1;
      }
      final fail = MicSelfCheck.evaluate(
        pcm([...lead, ...covered, ...lead]),
        sr,
        baselineRel: first.bandsDb,
      );
      expect(fail.deviationDb, greaterThan(MicSelfCheck.maxDeviationDb));
      expect(fail.passed, isFalse);
      expect(fail.fixTip, contains('profile'));
      expect(MicSelfCheckResult.manualConfirmation.passed, isTrue);
      expect(MicSelfCheckResult.manualConfirmation.profileRecorded, isFalse);
    });

    test('protocol lookups', () {
      expect(BreathProtocols.forScreenId('S-G01'), BreathProtocols.coughTb);
      expect(BreathProtocols.forScreenId('S-G02'), BreathProtocols.airway);
      expect(BreathProtocols.forScreenId('S-G04'), BreathProtocols.voice);
      expect(
        BreathProtocols.forScreenId('S-G05'),
        BreathProtocols.lungFunction,
      );
      expect(BreathProtocols.forScreenId('S-G10'), isNull);
      expect(
        BreathProtocols.forCatalogueId('cat_aud_spirometry'),
        BreathProtocols.lungFunction,
      );
      for (final p in BreathProtocols.all) {
        expect(p.tasks, isNotEmpty);
        expect(p.whatYouGet, isNotEmpty);
        expect(p.howWorkedOut, isNotEmpty);
        expect(p.howTo.length, greaterThanOrEqualTo(3));
      }
      expect(BreathProtocols.voice.hasCondition, isFalse);
      expect(BreathProtocols.lungFunction.needsBodyProfile, isTrue);
    });
  });
}
