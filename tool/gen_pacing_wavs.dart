// Generates the three tiny pacing sounds used by the Movement tests
// (assets/audio/tick.wav, beep.wav, go.wav). Run once:
//   dart run tool/gen_pacing_wavs.dart
// 16-bit mono PCM at 22 050 Hz, sine bursts with a short fade so they do
// not click. No external assets or licences involved.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  final out = Directory('assets/audio')..createSync(recursive: true);
  _write('${out.path}/tick.wav', _tone([(1760, 0.045)]));
  _write('${out.path}/beep.wav', _tone([(880, 0.14)]));
  _write('${out.path}/go.wav', _tone([(660, 0.10), (990, 0.18)]));
  // Hearing screen (Spec §8 AUD-09): 1 s pure tones per ear at 44.1 kHz,
  // stereo with the other channel silent, −3 dBFS, 20 ms raised-cosine
  // ramps; plus a 4 s speech-shaped (pink-filtered) masking noise loop.
  for (final hz in [500, 1000, 2000, 4000]) {
    for (final side in ['l', 'r']) {
      _writeStereo(
        '${out.path}/tone_${hz}_$side.wav',
        _pureTone(hz.toDouble(), 1.0),
        left: side == 'l',
      );
    }
  }
  _writeStereo('${out.path}/din_noise.wav', _pinkNoise(4.0), both: true);
  // Audio readiness (Spec §2 CAP-11): 1.5 s exponential sine sweep
  // 100 Hz → 8 kHz played through the speaker while the mic records.
  _write('${out.path}/sweep.wav', _sweep(), rate: _hiRate);
  // Sleep sonar (Spec §8 AUD-07): 1 s loop of 20 ms linear 18 → 20 kHz
  // chirps at 48 kHz, −6 dBFS, 2 ms raised-cosine ramps (inaudible).
  _write('${out.path}/sonar_chirp.wav', _sonarChirp(), rate: _sonarRate);
  stdout.writeln(
    'wrote tick.wav, beep.wav, go.wav, 8 hearing tones, din_noise.wav and sweep.wav to ${out.path}',
  );
}

const int _sonarRate = 48000;

/// 50 chirps of 20 ms, each a linear sweep 18 → 20 kHz, −6 dBFS, with 2 ms
/// raised-cosine ramps so the loop point and chirp edges do not click.
List<int> _sonarChirp() {
  const f0 = 18000.0, f1 = 20000.0, chirpS = 0.020;
  final nChirp = (chirpS * _sonarRate).round();
  final ramp = (0.002 * _sonarRate).round();
  final out = <int>[];
  for (var c = 0; c < 50; c++) {
    for (var i = 0; i < nChirp; i++) {
      final t = i / _sonarRate;
      final phase = 2 * math.pi * (f0 * t + (f1 - f0) / (2 * chirpS) * t * t);
      var env = 1.0;
      if (i < ramp) env = 0.5 - 0.5 * math.cos(math.pi * i / ramp);
      if (nChirp - i < ramp) {
        env = 0.5 - 0.5 * math.cos(math.pi * (nChirp - i) / ramp);
      }
      out.add((math.sin(phase) * 0.5 * env * 32767).round());
    }
  }
  return out;
}

/// Exponential sine sweep 100 Hz → 8 kHz over 1.5 s, −3 dBFS, 20 ms ramps.
List<int> _sweep() {
  const f0 = 100.0, f1 = 8000.0, secs = 1.5;
  final n = (secs * _hiRate).round();
  final k = math.log(f1 / f0);
  final ramp = (0.020 * _hiRate).round();
  final out = <int>[];
  for (var i = 0; i < n; i++) {
    final t = i / _hiRate;
    final phase = 2 * math.pi * f0 * secs / k * (math.exp(k * t / secs) - 1);
    var env = 1.0;
    if (i < ramp) env = i / ramp;
    if (n - i < ramp) env = (n - i) / ramp;
    out.add((math.sin(phase) * 0.708 * env * 32767).round());
  }
  return out;
}

const int _rate = 22050;

/// Concatenated sine segments: (frequency Hz, seconds).
List<int> _tone(List<(double, double)> segments) {
  final samples = <int>[];
  for (final (freq, secs) in segments) {
    final n = (secs * _rate).round();
    final fade = (0.006 * _rate).round();
    for (var i = 0; i < n; i++) {
      var env = 1.0;
      if (i < fade) env = i / fade;
      if (n - i < fade) env = (n - i) / fade;
      final v = math.sin(2 * math.pi * freq * i / _rate) * 0.6 * env;
      samples.add((v * 32767).round());
    }
  }
  return samples;
}

void _write(String path, List<int> samples, {int rate = _rate}) {
  final dataBytes = samples.length * 2;
  final b = BytesBuilder();
  void str(String s) => b.add(s.codeUnits);
  void u32(int v) =>
      b.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) =>
      b.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));
  str('RIFF');
  u32(36 + dataBytes);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  str('data');
  u32(dataBytes);
  final pcm = Uint8List(dataBytes);
  final bd = pcm.buffer.asByteData();
  for (var i = 0; i < samples.length; i++) {
    bd.setInt16(i * 2, samples[i], Endian.little);
  }
  b.add(pcm);
  File(path).writeAsBytesSync(b.toBytes());
}

const int _hiRate = 44100;

/// Full-scale-ish (−3 dBFS) sine with 20 ms raised-cosine ramps.
List<int> _pureTone(double hz, double secs) {
  final n = (secs * _hiRate).round();
  final ramp = (0.020 * _hiRate).round();
  final out = <int>[];
  for (var i = 0; i < n; i++) {
    var env = 1.0;
    if (i < ramp) env = 0.5 - 0.5 * math.cos(math.pi * i / ramp);
    if (n - i < ramp) env = 0.5 - 0.5 * math.cos(math.pi * (n - i) / ramp);
    final v = math.sin(2 * math.pi * hz * i / _hiRate) * 0.708 * env;
    out.add((v * 32767).round());
  }
  return out;
}

/// Pink-ish noise (Paul Kellet filter) normalised to −6 dBFS peak, with
/// short ramps so the loop point does not click.
List<int> _pinkNoise(double secs) {
  final n = (secs * _hiRate).round();
  final rng = math.Random(7);
  double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
  final raw = List<double>.filled(n, 0);
  var peak = 0.0;
  for (var i = 0; i < n; i++) {
    final white = rng.nextDouble() * 2 - 1;
    b0 = 0.99886 * b0 + white * 0.0555179;
    b1 = 0.99332 * b1 + white * 0.0750759;
    b2 = 0.96900 * b2 + white * 0.1538520;
    b3 = 0.86650 * b3 + white * 0.3104856;
    b4 = 0.55000 * b4 + white * 0.5329522;
    b5 = -0.7616 * b5 - white * 0.0168980;
    final pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
    b6 = white * 0.115926;
    raw[i] = pink;
    if (pink.abs() > peak) peak = pink.abs();
  }
  final ramp = (0.010 * _hiRate).round();
  final out = <int>[];
  for (var i = 0; i < n; i++) {
    var env = 1.0;
    if (i < ramp) env = i / ramp;
    if (n - i < ramp) env = (n - i) / ramp;
    out.add((raw[i] / peak * 0.5 * env * 32767).round());
  }
  return out;
}

/// 16-bit stereo WAV at 44.1 kHz; [left] puts the signal in the left
/// channel only, [both] in both, else right only.
void _writeStereo(
  String path,
  List<int> samples, {
  bool left = false,
  bool both = false,
}) {
  final frames = samples.length;
  final dataBytes = frames * 4;
  final b = BytesBuilder();
  void str(String s) => b.add(s.codeUnits);
  void u32(int v) =>
      b.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) =>
      b.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));
  str('RIFF');
  u32(36 + dataBytes);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1); // PCM
  u16(2); // stereo
  u32(_hiRate);
  u32(_hiRate * 4);
  u16(4);
  u16(16);
  str('data');
  u32(dataBytes);
  final pcm = Uint8List(dataBytes);
  final bd = pcm.buffer.asByteData();
  for (var i = 0; i < frames; i++) {
    final l = both || left ? samples[i] : 0;
    final r = both || !left ? samples[i] : 0;
    bd.setInt16(i * 4, l, Endian.little);
    bd.setInt16(i * 4 + 2, r, Endian.little);
  }
  b.add(pcm);
  File(path).writeAsBytesSync(b.toBytes());
}
