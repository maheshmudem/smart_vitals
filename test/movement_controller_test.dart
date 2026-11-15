// MovementRunController timing rules on simulated sensors (fake time).
import 'package:algoritam/core/domain/entities/movement_protocol.dart';
import 'package:algoritam/core/services/motion_sensor_service.dart';
import 'package:algoritam/features/movement/movement_run_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tremor test (ALG-MOV-05) start gating', () {
    test('a still arm: countdown ends and recording starts', () {
      fakeAsync((async) {
        final sensors = MotionSensorService.instance
          ..simulatedProfile = SimulatedMotionProfile.stillHand;
        final c = MovementRunController(
          protocol: MovementProtocols.tremor,
          sensors: sensors,
        );
        c.start();
        async.elapse(const Duration(milliseconds: 4500));
        expect(c.phase, RunPhase.running);
        expect(c.armSteady, isTrue);
        c.dispose();
      });
    });

    test('an arm still moving (passing the phone): recording waits, no '
        'restart, no auto-skip', () {
      fakeAsync((async) {
        final sensors = MotionSensorService.instance
          ..simulatedProfile = SimulatedMotionProfile.grossMovement;
        final c = MovementRunController(
          protocol: MovementProtocols.tremor,
          sensors: sensors,
        );
        c.start();
        async.elapse(const Duration(seconds: 12));
        expect(c.phase, RunPhase.countdown);
        expect(c.waitingForSteady, isTrue);
        expect(c.restartsThisSide, 0);
        expect(c.captures, isEmpty);
        c.dispose();
      });
    });

    test('both hands run to completion with a still arm', () {
      fakeAsync((async) {
        final sensors = MotionSensorService.instance
          ..simulatedProfile = SimulatedMotionProfile.stillHand;
        final c = MovementRunController(
          protocol: MovementProtocols.tremor,
          sensors: sensors,
        );
        c.start();
        async.elapse(const Duration(seconds: 26));
        expect(c.phase, RunPhase.sideSwitch);
        expect(c.captures.length, 1);
        expect(c.captures.single.skipped, isFalse);
        c.start();
        async.elapse(const Duration(seconds: 26));
        expect(c.phase, RunPhase.processing);
        expect(c.captures.length, 2);
        expect(c.captures.every((x) => !x.skipped), isTrue);
        expect(c.captures.every((x) => x.motion.length > 1500), isTrue);
        c.dispose();
      });
    });
  });
}
