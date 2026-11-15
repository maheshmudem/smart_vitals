// Raw sensor-frame landmark → upright preview-space mapping (ALG-MOV-01
// overlay alignment). The expected values follow the hand_landmarker plugin
// example, which rotates the canvas by sensorOrientation and flips the
// selfie lens.
import 'package:algoritam/core/services/hand_tracking_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HandTrackingService.toDisplaySpace', () {
    test('front camera at 270°: raw top-left lands bottom-left, mirrored', () {
      // raw (0,0) → upright (0,1) → mirrored (1,1)? No: rotate 270 CW maps
      // top-left to bottom-left (0,1); the selfie mirror then puts it at
      // bottom-right (1,1).
      final p = HandTrackingService.toDisplaySpace(
        0,
        0,
        0,
        rotation: 270,
        mirror: true,
      );
      expect(p.x, closeTo(1, 1e-9));
      expect(p.y, closeTo(1, 1e-9));
      // General form (1 − y, 1 − x).
      final q = HandTrackingService.toDisplaySpace(
        0.2,
        0.7,
        0,
        rotation: 270,
        mirror: true,
      );
      expect(q.x, closeTo(0.3, 1e-9));
      expect(q.y, closeTo(0.8, 1e-9));
    });

    test('back camera at 90°: raw top-left lands top-right, no mirror', () {
      final p = HandTrackingService.toDisplaySpace(
        0,
        0,
        0,
        rotation: 90,
        mirror: false,
      );
      expect(p.x, closeTo(1, 1e-9));
      expect(p.y, closeTo(0, 1e-9));
      final q = HandTrackingService.toDisplaySpace(
        0.2,
        0.7,
        0,
        rotation: 90,
        mirror: false,
      );
      expect(q.x, closeTo(0.3, 1e-9));
      expect(q.y, closeTo(0.2, 1e-9));
    });

    test('0° and 180° keep or flip both axes', () {
      final a = HandTrackingService.toDisplaySpace(
        0.2,
        0.7,
        0,
        rotation: 0,
        mirror: false,
      );
      expect(a.x, closeTo(0.2, 1e-9));
      expect(a.y, closeTo(0.7, 1e-9));
      final b = HandTrackingService.toDisplaySpace(
        0.2,
        0.7,
        0,
        rotation: 180,
        mirror: false,
      );
      expect(b.x, closeTo(0.8, 1e-9));
      expect(b.y, closeTo(0.3, 1e-9));
    });

    test('a hand spanning the raw frame keeps its shape after mapping', () {
      // Wrist at raw (0.5, 0.8), middle MCP at raw (0.5, 0.5) on a 4:3
      // sensor: upright this is a vertical 0.3 (of width) span → in
      // height units after the 270° rotation it is 0.3 × aspect.
      final w = HandTrackingService.toDisplaySpace(
        0.5,
        0.8,
        0,
        rotation: 270,
        mirror: true,
      );
      final m = HandTrackingService.toDisplaySpace(
        0.5,
        0.5,
        0,
        rotation: 270,
        mirror: true,
      );
      // Same y (both x_raw = 0.5), different x: a horizontal span upright.
      expect(w.y, closeTo(m.y, 1e-9));
      expect((w.x - m.x).abs(), closeTo(0.3, 1e-9));
    });
  });

  group('HandGuide', () {
    test(
      'guide stays inside the visible strip of a cover-fitted 4:3 image',
      () {
        final v = HandGuide.visibleRect(const Size(390, 844), 0.75);
        expect(v.left, greaterThan(0.15));
        expect(v.right, lessThan(0.85));
        expect(v.top, closeTo(0, 1e-9));
        expect(v.bottom, closeTo(1, 1e-9));
        final g = HandGuide.forViewport(const Size(390, 844), 0.75);
        expect(g.left, greaterThan(v.left));
        expect(g.right, lessThan(v.right));
        expect(g.top, greaterThan(0.1));
        expect(g.bottom, lessThan(0.8));
      },
    );

    test('status: whole hand inside → ok, half outside → partlyOutside', () {
      final g = HandGuide.forViewport(const Size(390, 844), 0.75);
      List<HandPoint> hand(double cx, double cy) => List.generate(
        21,
        (i) => HandPoint(cx + (i % 5) * 0.02, cy + (i ~/ 5) * 0.03, 0),
      );
      final inside = HandFrame(
        t: 0,
        handInFrame: true,
        landmarks: hand(g.center.dx - 0.04, g.center.dy - 0.06),
        handSize: 0.2,
      );
      expect(HandGuide.statusFor(inside, g), HandStatus.ok);
      final out = HandFrame(
        t: 0,
        handInFrame: true,
        landmarks: hand(g.right - 0.04, g.center.dy),
        handSize: 0.2,
      );
      expect(HandGuide.statusFor(out, g), HandStatus.partlyOutside);
      final far = HandFrame(
        t: 0,
        handInFrame: true,
        landmarks: hand(g.center.dx - 0.04, g.center.dy - 0.06),
        handSize: 0.05,
      );
      expect(HandGuide.statusFor(far, g), HandStatus.tooFar);
    });
  });
}
