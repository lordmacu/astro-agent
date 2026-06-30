import 'package:chispa/core/util/calibration.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _epoch = DateTime.utc(2026);
DateTime _at(double seconds) =>
    _epoch.add(Duration(milliseconds: (seconds * 1000).round()));

/// Drive one straight-line acceleration window: feed `samples` accel vectors of
/// `accel` (device-frame m/s^2), bracketed by two GPS speeds `from`->`to` over
/// `dt` seconds, so the calibrator can correlate them.
void _window(
  ForwardCalibrator c, {
  required List<double> accel,
  required double from,
  required double to,
  required double t0,
  required double dt,
  int samples = 10,
}) {
  c.addGpsSpeed(from, _at(t0));
  for (var i = 0; i < samples; i++) {
    c.longitudinal(accel);
  }
  c.addGpsSpeed(to, _at(t0 + dt));
}

void main() {
  group('ForwardCalibrator', () {
    test('defaults to the device z-axis before it has learned anything', () {
      final c = ForwardCalibrator();
      expect(c.calibrated, isFalse);
      // z is the assumed travel axis: a pure-z accel projects fully.
      expect(c.longitudinal([0, 0, 1.5]), closeTo(1.5, 1e-9));
      // x (sideways) does not count as forward yet.
      expect(c.longitudinal([2, 0, 0]), closeTo(0, 1e-9));
    });

    test('learns the forward axis from GPS-correlated acceleration', () {
      final c = ForwardCalibrator();
      // Phone mounted so travel is along device X (e.g. landscape): real
      // acceleration shows up on X while the car speeds up.
      _window(c, accel: [2.5, 0, 0], from: 0, to: 2.5, t0: 0, dt: 1);
      _window(c, accel: [2.5, 0, 0], from: 2.5, to: 5.0, t0: 2, dt: 1);

      expect(c.calibrated, isTrue);
      expect(c.forward[0], closeTo(1.0, 0.05));
      expect(c.forward[1], closeTo(0.0, 0.05));
      expect(c.forward[2], closeTo(0.0, 0.05));
      // Now a forward (X) acceleration projects to its full magnitude.
      expect(c.longitudinal([3, 0, 0]), closeTo(3.0, 0.1));
    });

    test('braking reinforces the same forward axis as accelerating', () {
      final c = ForwardCalibrator();
      _window(c, accel: [3, 0, 0], from: 0, to: 3, t0: 0, dt: 1); // speed up
      _window(c, accel: [-3, 0, 0], from: 3, to: 0, t0: 2, dt: 1); // brake

      expect(c.calibrated, isTrue);
      expect(c.forward[0], closeTo(1.0, 0.05));
    });

    test('does not calibrate from constant-speed windows', () {
      final c = ForwardCalibrator();
      // Vibration/noise on X but the car holds a steady speed: nothing to learn.
      _window(c, accel: [2, 0, 0], from: 12, to: 12, t0: 0, dt: 1);
      _window(c, accel: [2, 0, 0], from: 12, to: 12, t0: 2, dt: 1);

      expect(c.calibrated, isFalse);
      expect(c.forward[2], closeTo(1.0, 1e-9)); // still the default z-axis
    });

    test('keeps the forward axis a unit vector', () {
      final c = ForwardCalibrator();
      _window(c, accel: [0, 2.0, 0], from: 0, to: 2, t0: 0, dt: 1);
      _window(c, accel: [0, 2.0, 0], from: 2, to: 4, t0: 2, dt: 1);

      final f = c.forward;
      final norm = (f[0] * f[0] + f[1] * f[1] + f[2] * f[2]); // squared length
      expect(norm, closeTo(1.0, 1e-6));
    });

    test('restores a learned axis from a saved accumulator', () {
      final c = ForwardCalibrator();
      // Strong evidence along device X, above the confidence threshold.
      c.loadAccumulator([10, 0, 0]);
      expect(c.calibrated, isTrue);
      expect(c.forward[0], closeTo(1.0, 1e-9));
      expect(c.longitudinal([2, 0, 0]), closeTo(2.0, 1e-9));
    });

    test('round-trips its accumulator so calibration survives a restart', () {
      final c = ForwardCalibrator();
      _window(c, accel: [2.5, 0, 0], from: 0, to: 2.5, t0: 0, dt: 1);
      _window(c, accel: [2.5, 0, 0], from: 2.5, to: 5, t0: 2, dt: 1);

      final restored = ForwardCalibrator()..loadAccumulator(c.accumulator);
      expect(restored.forward[0], closeTo(c.forward[0], 1e-9));
      expect(restored.forward[1], closeTo(c.forward[1], 1e-9));
      expect(restored.forward[2], closeTo(c.forward[2], 1e-9));
      expect(restored.calibrated, c.calibrated);
    });
  });
}
