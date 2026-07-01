import 'package:astro/sensors/motion/motion_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _g = 9.80665;

void main() {
  test(
    'maps device axes to car frame (x→lateral, y→vertical, z→longitudinal)',
    () async {
      // factor 1.0 = no smoothing, value jumps straight to the target.
      final service = MotionService(
        source: Stream.fromIterable([const AccelSample(_g, 0, 0)]),
        smoothing: 1.0,
      );

      final reading = (await service.readings().toList()).single;

      expect(reading.lateralG, closeTo(1.0, 1e-9));
      expect(reading.verticalG, 0);
      expect(reading.longitudinalG, 0);
    },
  );

  test('converts m/s^2 to g and smooths toward steady acceleration', () async {
    final samples = List.generate(
      60,
      (_) => const AccelSample(0, 0, _g),
    ); // 1g forward
    final service = MotionService(
      source: Stream.fromIterable(samples),
      smoothing: 0.2,
    );

    final readings = await service.readings().toList();

    expect(readings.last.longitudinalG, closeTo(1.0, 0.02));
    expect(readings.last.lateralG, closeTo(0.0, 1e-9));
    // Smoothing means it ramps up, not an instant jump.
    expect(readings.first.longitudinalG, lessThan(0.5));
  });

  test('hard braking shows as negative longitudinal g', () async {
    final samples = List.generate(
      60,
      (_) => const AccelSample(0, 0, -0.6 * _g),
    );
    final service = MotionService(
      source: Stream.fromIterable(samples),
      smoothing: 0.3,
    );

    final last = (await service.readings().toList()).last;
    expect(last.longitudinalG, closeTo(-0.6, 0.02));
  });

  test('reads the gyroscope yaw rate (vertical axis = gyro y)', () async {
    final service = MotionService(
      source: Stream.value(const AccelSample(0, 0, 0)),
      gyroSource: Stream.value(const GyroSample(0, 0.8, 0)),
      smoothing: 1.0,
    );

    final last = (await service.readings().toList()).last;
    expect(last.yawRate, closeTo(0.8, 1e-9));
  });

  test('without a gyroscope source, yaw rate stays 0', () async {
    final service = MotionService(
      source: Stream.value(const AccelSample(0, 0, 9.80665)),
      smoothing: 1.0,
    );

    final last = (await service.readings().toList()).last;
    expect(last.yawRate, 0);
  });
}
