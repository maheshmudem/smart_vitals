// Physical screen scale for the vision tests (Spec §9 MOV-10 "device screen
// DPI", MOV-11 "10 × 10 cm Amsler grid").
//
// Sources, best first:
//  • card calibrated — the member matched an on-screen box to a bank card
//    (85.60 mm wide); exact for this screen.
//  • device dpi — Android DisplayMetrics.xdpi via a tiny platform channel.
//  • estimated — devicePixelRatio × 160 (Android density bucket), which can
//    be 10–20 % off; the result records the source.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenMetrics {
  const ScreenMetrics({required this.mmPerLogicalPx, required this.source});

  /// Millimetres per Flutter logical pixel.
  final double mmPerLogicalPx;

  /// 'card calibrated' | 'device dpi' | 'estimated'.
  final String source;

  double get dpi => 25.4 / mmPerLogicalPx * 1.0;

  double mmToLogicalPx(double mm) => mm / mmPerLogicalPx;
  double logicalPxToMm(double px) => px * mmPerLogicalPx;
}

class ScreenMetricsService {
  ScreenMetricsService._();

  static final ScreenMetricsService instance = ScreenMetricsService._();

  static const MethodChannel _channel = MethodChannel('vitalsmirror/display');

  /// ISO/IEC 7810 ID-1 card width.
  static const double cardWidthMm = 85.60;

  double? _deviceXdpi;
  bool _probed = false;

  static bool get isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// Resolve the scale. [devicePixelRatio] from MediaQuery; [calibratedMmPerPx]
  /// from the device profile when the member calibrated with a card.
  Future<ScreenMetrics> resolve({
    required double devicePixelRatio,
    double? calibratedMmPerPx,
  }) async {
    if (calibratedMmPerPx != null && calibratedMmPerPx > 0) {
      return ScreenMetrics(
        mmPerLogicalPx: calibratedMmPerPx,
        source: 'card calibrated',
      );
    }
    if (!_probed && !isFlutterTest && !kIsWeb && Platform.isAndroid) {
      _probed = true;
      try {
        final m = await _channel.invokeMapMethod<String, dynamic>('metrics');
        final x = (m?['xdpi'] as num?)?.toDouble();
        if (x != null && x > 50 && x < 1200) _deviceXdpi = x;
      } catch (_) {
        _deviceXdpi = null;
      }
    }
    final xdpi = _deviceXdpi;
    if (xdpi != null) {
      // physical px per inch → logical px per inch
      final logicalPerInch = xdpi / devicePixelRatio;
      return ScreenMetrics(
        mmPerLogicalPx: 25.4 / logicalPerInch,
        source: 'device dpi',
      );
    }
    final logicalPerInch = 160.0; // Android density bucket definition
    return ScreenMetrics(
      mmPerLogicalPx: 25.4 / logicalPerInch,
      source: 'estimated',
    );
  }
}
