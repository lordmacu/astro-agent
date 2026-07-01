import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/state/app_mode.dart';
import 'package:astro/core/state/app_state_provider.dart';
import 'package:astro/sensors/light/light_service.dart';
import 'package:astro/sensors/location/speed_service.dart';
import 'package:astro/sensors/motion/motion_service.dart';
import 'package:astro/sensors/proximity/proximity_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts the app in car mode, where the speed sensor runs and driving moods
/// fire. The default AppModeNotifier starts in normal mode (speed gated to 0).
class _CarModeNotifier extends AppModeNotifier {
  @override
  AppMode build() => AppMode.car;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LightService', () {
    test('smooths lux toward the latest reading', () async {
      final service = LightService(
        source: Stream.fromIterable(List.filled(60, 100.0)),
        smoothing: 0.2,
      );
      final values = await service.lux().toList();
      expect(values.last, closeTo(100, 1));
      // Smoothed: ramps down from the 12000 initial, not an instant jump.
      expect(values.first, greaterThan(values.last));
    });
  });

  group('ProximityService', () {
    test('passes near/far through', () async {
      final service = ProximityService(
        source: Stream.fromIterable([false, true, false]),
      );
      expect(await service.near().toList(), [false, true, false]);
    });
  });

  group('SpeedService', () {
    test('exposes GPS samples and converts speed to km/h', () async {
      final service = SpeedService(
        source: Stream.fromIterable(const [
          GpsSpeedSample(speedMps: 0, accuracyMps: 1),
          GpsSpeedSample(speedMps: 10, accuracyMps: 1),
        ]),
      );
      expect(await service.speedKmh().toList(), [0.0, 36.0]);
    });
  });

  group('buildSensorState', () {
    test('assembles all sensor values, leaving OBD/nav at defaults', () {
      final state = buildSensorState(
        motion: const MotionReading(
          longitudinalG: 0.6,
          verticalG: 0.1,
          lateralG: -0.2,
        ),
        lux: 50,
        proximityNear: true,
        speedKmh: 42,
      );

      expect(state.longitudinalG, 0.6);
      expect(state.lux, 50);
      expect(state.proximityNear, true);
      expect(state.speedKmh, 42);
      // Optional sources stay null/default — the app works without them.
      expect(state.dtcPresent, isNull);
      expect(state.rpm, isNull);
    });
  });

  group('appStateProvider combiner', () {
    test('merges all four sensor streams into the latest AppState', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appModeProvider.overrideWith(_CarModeNotifier.new),
          motionServiceProvider.overrideWithValue(
            MotionService(
              source: Stream.value(const AccelSample(0, 0, 9.80665)),
              smoothing: 1.0,
            ),
          ),
          lightServiceProvider.overrideWithValue(
            LightService(source: Stream.value(3.0), smoothing: 1.0),
          ),
          proximityServiceProvider.overrideWithValue(
            ProximityService(source: Stream.value(true)),
          ),
          speedServiceProvider.overrideWithValue(
            SpeedService(
              source: Stream.value(
                const GpsSpeedSample(speedMps: 13.89, accuracyMps: 0.5),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Drain emissions so the latest AppState carries every sensor's value
      // (the first is the startWith defaults).
      final sub = container.listen(
        appStateProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(appStateProvider).requireValue;
      expect(state.longitudinalG, closeTo(1.0, 1e-9));
      expect(state.lux, 3.0);
      expect(state.proximityNear, true);
      // Speed flows through the GPS+IMU fusion, so it is a positive, finite
      // estimate near the GPS fix rather than a verbatim pass-through.
      expect(state.speedKmh, greaterThan(0));
      expect(state.speedKmh.isFinite, isTrue);
    });
  });
}
