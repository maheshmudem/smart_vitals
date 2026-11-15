// Minimal radix-2 FFT for the voice-feature extractor (pure Dart).
import 'dart:math' as math;

class Fft {
  Fft._();

  /// Power spectrum (bins 0..n/2) of a real frame; [frame] length must be a
  /// power of two. A Hann window is applied.
  static List<double> powerSpectrum(List<double> frame) {
    final n = frame.length;
    assert(n > 0 && (n & (n - 1)) == 0, 'frame length must be a power of two');
    final re = List<double>.filled(n, 0);
    final im = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final w = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
      re[i] = frame[i] * w;
    }
    // bit reversal
    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      while (j & bit != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j |= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wr = math.cos(ang), wi = math.sin(ang);
      for (var i = 0; i < n; i += len) {
        var cr = 1.0, ci = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final a = i + k, b = i + k + len ~/ 2;
          final xr = re[b] * cr - im[b] * ci;
          final xi = re[b] * ci + im[b] * cr;
          re[b] = re[a] - xr;
          im[b] = im[a] - xi;
          re[a] += xr;
          im[a] += xi;
          final ncr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = ncr;
        }
      }
    }
    final half = n ~/ 2;
    return [for (var i = 0; i <= half; i++) re[i] * re[i] + im[i] * im[i]];
  }
}
