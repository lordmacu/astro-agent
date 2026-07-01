import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/state/app_mode.dart';
import 'package:astro/core/state/app_state_provider.dart';
import 'package:astro/core/state/mood.dart';
import 'package:astro/sensors/light/light_service.dart';
import 'package:astro/sensors/location/speed_service.dart';
import 'package:astro/sensors/motion/motion_service.dart';
import 'package:astro/sensors/navigation/nav_reading.dart';
import 'package:astro/sensors/navigation/nav_service.dart';
import 'package:astro/sensors/proximity/proximity_service.dart';

class _FakeNav extends NavService {
  _FakeNav(this._readings) : super(rawEvents: const Stream.empty());
  final List<NavReading> _readings;
  @override
  Stream<NavReading> readings() => Stream.fromIterable(_readings);
}

class _CarMode extends AppModeNotifier {
  @override
  AppMode build() => AppMode.car;
}

Future<ProviderContainer> _container({
  required bool navEnabled,
  required List<NavReading> nav,
}) async {
  SharedPreferences.setMockInitialValues({'navListenerEnabled': navEnabled});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appModeProvider.overrideWith(_CarMode.new),
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
        ProximityService(source: Stream.value(false)),
      ),
      speedServiceProvider.overrideWithValue(
        SpeedService(
          source: Stream.value(
            const GpsSpeedSample(speedMps: 0, accuracyMps: 0),
          ),
        ),
      ),
      navServiceProvider.overrideWithValue(_FakeNav(nav)),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nav enabled: reading flows into AppState', () async {
    final c = await _container(
      navEnabled: true,
      nav: [
        const NavReading(turnDirection: TurnDirection.right, distanceM: 50),
      ],
    );
    final sub = c.listen(appStateProvider, (_, __) {}, fireImmediately: true);
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final state = c.read(appStateProvider).requireValue;
    expect(state.turnDirection, TurnDirection.right);
    expect(state.turnDistanceM, 50);
  });

  test('nav disabled: fields stay default even if the service emits', () async {
    final c = await _container(
      navEnabled: false,
      nav: [const NavReading(turnDirection: TurnDirection.left, distanceM: 10)],
    );
    final sub = c.listen(appStateProvider, (_, __) {}, fireImmediately: true);
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final state = c.read(appStateProvider).requireValue;
    expect(state.turnDirection, TurnDirection.none);
    expect(state.turnDistanceM, isNull);
    expect(state.arrived, false);
  });
}
