import 'package:rxdart/rxdart.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/util/low_pass.dart';

/// Standard gravity, to convert m/s^2 into g.
const double _g = 9.80665;

/// A raw, gravity-removed accelerometer sample in m/s^2 (device frame). Neutral
/// type so the service does not leak `sensors_plus` to its consumers and can be
/// driven by a fake stream in tests.
class AccelSample {
  const AccelSample(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

/// A raw gyroscope sample in rad/s (device frame).
class GyroSample {
  const GyroSample(this.x, this.y, this.z);
  static const zero = GyroSample(0, 0, 0);
  final double x;
  final double y;
  final double z;
}

/// One smoothed motion reading, mapped to the car frame.
class MotionReading {
  const MotionReading({
    required this.longitudinalG,
    required this.verticalG,
    required this.lateralG,
    this.yawRate = 0,
  });

  /// Along travel: positive accelerating, negative braking.
  final double longitudinalG;

  /// Vertical spikes (bumps).
  final double verticalG;

  /// Sideways g (curves, centripetal).
  final double lateralG;

  /// Turn rate about the vertical axis in rad/s (curves), from the gyroscope.
  /// Sign indicates turn direction; magnitude how sharp the turn is.
  final double yawRate;
}

/// Turns raw accelerometer + gyroscope samples into smoothed car-frame motion
/// that feeds `AppState`. The service only produces data — the mood decision
/// stays in `MoodResolver`.
///
/// Axis mapping assumes the phone stands in portrait on the dashboard, screen
/// facing the driver: accel x = sideways, y = vertical, z = travel; the vertical
/// (yaw) axis is gyro y. A proper calibration of the gravity/forward axes is a
/// TODO (pet.md 8.3); until then this is the documented default.
class MotionService {
  MotionService({
    required this.source,
    this.gyroSource,
    this.smoothing = 0.2,
  });

  /// Gravity-removed accelerometer samples (e.g. `userAccelerometerEvents`).
  final Stream<AccelSample> source;

  /// Gyroscope samples (rad/s). Optional — without it, yawRate stays 0.
  final Stream<GyroSample>? gyroSource;

  /// Low-pass strength; low smooths the jittery raw signal.
  final double smoothing;

  /// Phone sensors via sensors_plus (accelerometer + gyroscope).
  factory MotionService.fromSensorsPlus({double smoothing = 0.2}) {
    return MotionService(
      source: userAccelerometerEventStream()
          .map((e) => AccelSample(e.x, e.y, e.z)),
      gyroSource:
          gyroscopeEventStream().map((e) => GyroSample(e.x, e.y, e.z)),
      smoothing: smoothing,
    );
  }

  Stream<MotionReading> readings() {
    final lateral = LowPass(factor: smoothing);
    final vertical = LowPass(factor: smoothing);
    final longitudinal = LowPass(factor: smoothing);
    final yaw = LowPass(factor: smoothing);

    // Seed the gyro with zero so the combined stream emits as soon as the
    // accelerometer does, even when no gyroscope is present (e.g. in tests).
    final gyro = (gyroSource ?? const Stream<GyroSample>.empty())
        .startWith(GyroSample.zero);

    return Rx.combineLatest2<AccelSample, GyroSample, MotionReading>(
      source,
      gyro,
      (a, g) => MotionReading(
        lateralG: lateral.add(a.x) / _g,
        verticalG: vertical.add(a.y) / _g,
        longitudinalG: longitudinal.add(a.z) / _g,
        yawRate: yaw.add(g.y),
      ),
    );
  }
}
