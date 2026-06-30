import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../sensors/light/light_service.dart';
import '../../sensors/location/speed_fusion.dart';
import '../../sensors/location/speed_service.dart';
import '../../sensors/motion/motion_service.dart';
import '../../sensors/proximity/proximity_service.dart';
import '../../voice/speech_catalog.dart';
import '../config/thresholds.dart';
import '../util/calibration.dart';
import '../util/calibration_store.dart';
import 'agent_controller.dart';
import 'app_state.dart';
import 'mood.dart';
import 'mood_resolver.dart';

/// Tuning constants for the cascade.
final thresholdsProvider = Provider<Thresholds>((_) => const Thresholds());

/// The pure resolver.
final moodResolverProvider = Provider<MoodResolver>(
  (ref) => MoodResolver(ref.watch(thresholdsProvider)),
);

/// Phone sensor services. Each is overridable in tests with a fake source.
final motionServiceProvider = Provider<MotionService>(
  (ref) => MotionService.fromSensorsPlus(),
);
final lightServiceProvider = Provider<LightService>(
  (ref) => LightService.fromPlugin(),
);
final proximityServiceProvider = Provider<ProximityService>(
  (ref) => ProximityService.fromPlugin(),
);
final speedServiceProvider = Provider<SpeedService>(
  (ref) => SpeedService.fromGeolocator(),
);

/// Persistence for the learned forward-axis calibration.
final calibrationStoreProvider = Provider<CalibrationStore>(
  (_) => CalibrationStore(),
);

/// The forward-axis calibrator, restored from disk on start and persisted
/// periodically so the learned axis survives restarts. A single instance is
/// shared by the speed fusion. I/O errors (e.g. no platform binding in tests)
/// are swallowed — the calibrator just falls back to relearning.
final forwardCalibratorProvider = Provider<ForwardCalibrator>((ref) {
  final store = ref.watch(calibrationStoreProvider);
  final calibrator = ForwardCalibrator();

  store
      .load()
      .then((acc) {
        if (acc != null) calibrator.loadAccumulator(acc);
      })
      .catchError((_) {});

  void persist() => store.save(calibrator.accumulator).catchError((_) {});
  final timer = Timer.periodic(const Duration(seconds: 60), (_) => persist());
  ref.onDispose(() {
    timer.cancel();
    persist();
  });

  return calibrator;
});

/// Pure assembly of the latest sensor values into one `AppState`. OBD and
/// navigation fields stay null/default — the app works fully without them.
AppState buildSensorState({
  required MotionReading motion,
  required double lux,
  required bool proximityNear,
  required double speedKmh,
}) => AppState(
  longitudinalG: motion.longitudinalG,
  verticalG: motion.verticalG,
  lateralG: motion.lateralG,
  yawRate: motion.yawRate,
  lux: lux,
  proximityNear: proximityNear,
  speedKmh: speedKmh,
);

const MotionReading _restMotion = MotionReading(
  longitudinalG: 0,
  verticalG: 0,
  lateralG: 0,
);

/// Standard gravity, to turn car-frame g back into m/s^2 for the fusion filter.
const double _gravity = 9.80665;

/// The combined application state: every sensor stream merged into one object
/// (add-data-source skill). Each source is seeded with a default (`startWith`)
/// so the UI has a value immediately, and guarded with `onErrorReturn` so one
/// missing/failing sensor never takes down the rest.
final appStateProvider = StreamProvider<AppState>((ref) {
  final t = ref.watch(thresholdsProvider);

  // Motion is shared: it feeds both the g-force fields and the speed fusion's
  // dead-reckoning input, off a single sensor subscription.
  final motion = ref
      .watch(motionServiceProvider)
      .readings()
      .onErrorReturn(_restMotion)
      .startWith(_restMotion)
      .shareReplay(maxSize: 1);
  final lux = ref
      .watch(lightServiceProvider)
      .lux()
      .onErrorReturn(12000)
      .startWith(12000);
  final near = ref
      .watch(proximityServiceProvider)
      .near()
      .onErrorReturn(false)
      .startWith(false);

  // Speed = GPS Doppler anchored, accelerometer fills the gaps (see
  // SpeedFusion). A ForwardCalibrator learns which device axis is "forward" so
  // dead reckoning works regardless of how the phone is mounted; each GPS fix
  // both feeds that learning and corrects the filter.
  final calibrator = ref.watch(forwardCalibratorProvider);
  final gps = ref
      .watch(speedServiceProvider)
      .samples()
      .onErrorReturn(const GpsSpeedSample(speedMps: 0, accuracyMps: 0))
      .doOnData((s) => calibrator.addGpsSpeed(s.speedMps, DateTime.now()));
  final accel = motion.map(
    (m) => AccelInput(
      calibrator.longitudinal([
        m.lateralG * _gravity,
        m.verticalG * _gravity,
        m.longitudinalG * _gravity,
      ]),
      quiet:
          m.longitudinalG.abs() < t.quietG &&
          m.lateralG.abs() < t.quietG &&
          m.verticalG.abs() < t.quietG,
    ),
  );
  final speed = fuseSpeed(gps: gps, accel: accel).onErrorReturn(0).startWith(0);

  return Rx.combineLatest4(
    motion,
    lux,
    near,
    speed,
    (MotionReading m, double l, bool n, double s) =>
        buildSensorState(motion: m, lux: l, proximityNear: n, speedKmh: s),
  );
});

/// The single resolved mood the UI and character render. Combines the sensor
/// `AppState` with the live agent phase (from voice / brain) before resolving.
final moodStateProvider = Provider<MoodState>((ref) {
  final resolver = ref.watch(moodResolverProvider);
  final base = ref.watch(appStateProvider).valueOrNull ?? const AppState();
  final agent = ref.watch(agentControllerProvider);
  final state = base.copyWith(
    agentPhase: agent.phase,
    activeToolName: agent.activeToolName,
  );
  return resolver.resolve(state);
});

/// The language Chispa speaks. Defaults to Spanish (the driver's language);
/// switch to English here or from settings later.
final speechLangProvider = StateProvider<SpeechLang>((_) => SpeechLang.es);

/// The current spoken line rendered to text, or null when Chispa is quiet.
final speechTextProvider = Provider<String?>((ref) {
  final line = ref.watch(moodStateProvider).line;
  if (line == null) return null;
  return SpeechCatalog.text(line, ref.watch(speechLangProvider));
});
