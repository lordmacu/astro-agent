import 'package:chispa/sensors/location/speed_fusion.dart';
import 'package:chispa/sensors/location/speed_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: a GPS event at `t` seconds with the given speed (m/s) and accuracy.
GpsSpeedEvent gps(double speedMps, double accuracyMps, double t) =>
    GpsSpeedEvent(
      GpsSpeedSample(speedMps: speedMps, accuracyMps: accuracyMps),
      _at(t),
    );

/// Helper: an accelerometer event at `t` seconds. `quiet` flags the hint that
/// the phone is mechanically still (no vibration / net acceleration).
AccelEvent accel(double longitudinalMps2, double t, {bool quiet = false}) =>
    AccelEvent(longitudinalMps2, at: _at(t), quiet: quiet);

final DateTime _epoch = DateTime.utc(2026);
DateTime _at(double seconds) =>
    _epoch.add(Duration(milliseconds: (seconds * 1000).round()));

void main() {
  group('SpeedFusion', () {
    test('first GPS fix snaps speed to the measurement', () {
      final f = SpeedFusion();
      f.process(gps(10, 0.5, 0));
      // 10 m/s == 36 km/h, large initial covariance => near-full trust.
      expect(f.speedKmh, closeTo(36, 0.5));
    });

    test('reports km/h as m/s * 3.6', () {
      final f = SpeedFusion();
      f.process(gps(20, 0.5, 0));
      expect(f.speedKmh, closeTo(f.speedMps * 3.6, 1e-9));
    });

    test('dead reckons with the accelerometer between GPS fixes', () {
      final f = SpeedFusion();
      f.process(gps(10, 0.5, 0)); // anchor at 10 m/s
      // +1 m/s^2 for 2 s with no GPS => +2 m/s => 12 m/s == 43.2 km/h.
      for (var i = 1; i <= 20; i++) {
        f.process(accel(1.0, i * 0.1));
      }
      expect(f.speedMps, closeTo(12, 0.4));
    });

    test('a GPS fix corrects accumulated dead-reckoning drift', () {
      final f = SpeedFusion();
      f.process(gps(10, 0.5, 0));
      // Drift up via accel with no GPS.
      for (var i = 1; i <= 20; i++) {
        f.process(accel(2.0, i * 0.1));
      }
      expect(f.speedMps, greaterThan(13)); // drifted high
      // A trustworthy GPS fix says we're actually at 10 again.
      f.process(gps(10, 0.5, 2.1));
      expect(f.speedMps, closeTo(10, 1.5)); // snapped back toward GPS
    });

    test('ZUPT clamps phantom speed to zero when stopped', () {
      final f = SpeedFusion();
      f.process(gps(0.2, 0.5, 0)); // GPS confirms ~stopped, fresh
      f.process(accel(0.0, 0.1, quiet: true)); // phone mechanically still
      expect(f.speedKmh, closeTo(0, 0.3));
    });

    test('ZUPT does NOT clamp during constant-speed cruise', () {
      final f = SpeedFusion();
      f.process(gps(30, 0.5, 0)); // cruising: GPS says 30 m/s, recent
      // Constant velocity => no net acceleration => accel reads quiet, but the
      // car is NOT stopped. ZUPT must not fire.
      f.process(accel(0.0, 0.1, quiet: true));
      expect(f.speedMps, closeTo(30, 1.0));
    });

    test('does not ZUPT when GPS is stale (tunnel): keeps dead reckoning', () {
      final f = SpeedFusion();
      f.process(gps(15, 0.5, 0)); // last GPS a long time ago
      // 10 s later (well past the stale window), accel is quiet but we cannot
      // confirm a stop without GPS, so speed is held, not zeroed.
      f.process(accel(0.0, 10.0, quiet: true));
      expect(f.speedMps, greaterThan(10));
    });

    test('clamps speed to zero under hard sustained braking', () {
      final f = SpeedFusion();
      f.process(gps(5, 0.5, 0));
      for (var i = 1; i <= 20; i++) {
        f.process(accel(-10.0, i * 0.1));
      }
      expect(f.speedMps, greaterThanOrEqualTo(0));
      expect(f.speedMps, closeTo(0, 0.5));
    });

    test('trusts an accurate GPS fix more than an inaccurate one', () {
      final accurate = SpeedFusion()..process(gps(10, 0.5, 0));
      final inaccurate = SpeedFusion()..process(gps(10, 0.5, 0));
      // Both now see a fix claiming 0 m/s, but with different accuracy.
      accurate.process(gps(0, 0.5, 0.1));
      inaccurate.process(gps(0, 20.0, 0.1)); // huge uncertainty
      expect(accurate.speedMps, lessThan(inaccurate.speedMps));
    });

    test('adaptively estimates accelerometer bias while stopped', () {
      final f = SpeedFusion();
      f.process(gps(0, 0.5, 0));
      // Phone is still, but the sensor reads a constant 0.3 m/s^2 offset.
      for (var i = 1; i <= 300; i++) {
        f.process(accel(0.3, i * 0.05, quiet: true));
      }
      expect(f.accelBiasMps2, closeTo(0.3, 0.1));
      // And speed stays pinned at ~0 despite the offset.
      expect(f.speedKmh, closeTo(0, 0.5));
    });

    test(
      'ignores non-positive and oversized time steps without blowing up',
      () {
        final f = SpeedFusion();
        f.process(gps(10, 0.5, 0));
        f.process(accel(1.0, 0)); // same timestamp => dt = 0
        f.process(accel(1.0, -5)); // backwards => clamped
        f.process(accel(1.0, 1000)); // huge gap => clamped to maxDt
        expect(f.speedMps, isNot(isNaN));
        expect(f.speedMps.isFinite, isTrue);
      },
    );
  });

  group('fuseSpeed stream', () {
    test('merges GPS and accel streams into a fused km/h stream', () async {
      final out = await fuseSpeed(
        gps: Stream.fromIterable([
          const GpsSpeedSample(speedMps: 10, accuracyMps: 0.5),
        ]),
        accel: const Stream.empty(),
        clock: _sequenceClock([0.0, 0.1]),
      ).toList();

      expect(out, isNotEmpty);
      expect(out.last, closeTo(36, 1.0));
    });

    test('emits one finite, non-negative km/h value per input event', () async {
      final out = await fuseSpeed(
        gps: Stream.fromIterable([
          const GpsSpeedSample(speedMps: 10, accuracyMps: 0.5),
        ]),
        accel: Stream.fromIterable(
          List.generate(10, (_) => const AccelInput(2.0, quiet: false)),
        ),
        clock: _sequenceClock([for (var i = 0; i <= 10; i++) i * 0.1]),
      ).toList();

      expect(out.length, 11); // one output per merged event
      expect(out.every((v) => v.isFinite && v >= 0), isTrue);
    });
  });
}

/// A deterministic clock that returns the next timestamp in `seconds` on each
/// call, so stream tests do not depend on wall-clock time.
DateTime Function() _sequenceClock(List<double> seconds) {
  var i = 0;
  return () => _at(seconds[i++ % seconds.length]);
}
