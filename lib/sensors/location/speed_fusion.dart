import 'package:rxdart/rxdart.dart';

import 'speed_service.dart';

/// GPS+IMU speed fusion (Kalman), the robust core of the speedometer.
///
/// Speed is anchored to the GPS Doppler reading; the accelerometer only fills
/// the gaps between fixes. This mirrors how Uber/Waze/Google Maps work and the
/// project rule in CLAUDE.md: never integrate the accelerometer as the speed by
/// itself (it drifts), only dead-reckon between GPS fixes and let the next fix
/// correct it.
///
/// State `x = [v, b]`: speed `v` (m/s) and an adaptively-estimated longitudinal
/// accelerometer bias `b` (m/s^2). Modelling the bias lets dead reckoning stay
/// accurate per device/condition instead of drifting on a fixed MEMS offset.
///
/// - Predict (per accel sample): `v += (a - b) * dt`, covariance grows.
/// - Update (per GPS fix): blend toward the fix, weighted by its accuracy
///   (`R = accuracy^2`) — a low-accuracy fix barely moves the estimate, which
///   is what suppresses GPS jumps.
/// - ZUPT (zero-velocity update): when the phone is mechanically still AND a
///   recent GPS fix agreed we were ~stopped, pin speed to 0 to kill phantom
///   speed at red lights. Gated by GPS so it never fires while cruising at a
///   constant speed (no net acceleration) or while dead-reckoning a tunnel.
class SpeedFusion {
  SpeedFusion([this.config = const SpeedFusionConfig()])
    : _v = 0,
      _b = 0,
      _p00 = config.initialSpeedVar,
      _p01 = 0,
      _p10 = 0,
      _p11 = config.initialBiasVar;

  final SpeedFusionConfig config;

  double _v; // speed, m/s
  double _b; // accelerometer bias, m/s^2
  // 2x2 covariance, kept symmetric.
  double _p00, _p01, _p10, _p11;

  double _lastAccel = 0; // last commanded longitudinal acceleration, m/s^2
  DateTime? _lastEventT;
  DateTime? _lastGpsT;
  double _lastGpsSpeed = double.infinity;

  /// Fused speed in m/s, never negative.
  double get speedMps => _v < 0 ? 0 : _v;

  /// Fused speed in km/h.
  double get speedKmh => speedMps * 3.6;

  /// Current estimate of the longitudinal accelerometer bias (m/s^2).
  double get accelBiasMps2 => _b;

  /// Feed one event (GPS fix or accel sample); returns the new speed in km/h.
  double process(SpeedEvent event) {
    final dt = _stepSeconds(event.at);
    _lastEventT = event.at;

    if (event is GpsSpeedEvent) {
      _predict(dt, _lastAccel);
      _updateSpeed(event.sample.speedMps, _gpsVariance(event.sample));
      _lastGpsT = event.at;
      _lastGpsSpeed = event.sample.speedMps;
    } else if (event is AccelEvent) {
      _lastAccel = event.longitudinalMps2;
      _predict(dt, event.longitudinalMps2);
      if (_shouldZupt(event)) {
        _updateSpeed(0, config.zuptVariance);
      }
    }

    if (_v < 0) _v = 0;
    return speedKmh;
  }

  /// Clamp the time step to a sane window: ignore non-positive steps (events out
  /// of order / same timestamp) and cap long gaps so one stale event cannot
  /// inject a huge prediction.
  double _stepSeconds(DateTime now) {
    final last = _lastEventT;
    if (last == null) return 0;
    final s = now.difference(last).inMicroseconds / 1e6;
    if (s <= 0) return 0;
    return s > config.maxStepSeconds ? config.maxStepSeconds : s;
  }

  void _predict(double dt, double accel) {
    if (dt <= 0) return;
    // x = F x + B u, with F = [[1,-dt],[0,1]], B = [dt,0], u = accel.
    _v = _v + (accel - _b) * dt;
    // P = F P F^T + Q.
    final n00 = _p00 - dt * _p10 - dt * _p01 + dt * dt * _p11;
    final n01 = _p01 - dt * _p11;
    final n10 = _p10 - dt * _p11;
    final n11 = _p11;
    final qv = config.accelNoise * dt * config.accelNoise * dt;
    final qb = config.biasWalk * config.biasWalk * dt;
    _p00 = n00 + qv;
    _p01 = n01;
    _p10 = n10;
    _p11 = n11 + qb;
  }

  void _updateSpeed(double z, double r) {
    // H = [1,0] measures v.
    final y = z - _v;
    final s = _p00 + r;
    final k0 = _p00 / s;
    final k1 = _p10 / s;
    _v = _v + k0 * y;
    _b = _b + k1 * y;
    // P = (I - K H) P.
    final n00 = (1 - k0) * _p00;
    final n01 = (1 - k0) * _p01;
    final n10 = _p10 - k1 * _p00;
    final n11 = _p11 - k1 * _p01;
    _p00 = n00;
    _p11 = n11;
    // Symmetrize to absorb numerical drift.
    final off = 0.5 * (n01 + n10);
    _p01 = off;
    _p10 = off;
  }

  bool _shouldZupt(AccelEvent e) {
    if (!e.quiet) return false;
    final lastGpsT = _lastGpsT;
    if (lastGpsT == null) return false; // no GPS yet: cannot confirm a stop
    if (e.at.difference(lastGpsT) >= config.gpsStale) return false; // tunnel
    return _lastGpsSpeed < config.zuptSpeedMps;
  }

  double _gpsVariance(GpsSpeedSample s) {
    var acc = s.accuracyMps;
    if (acc <= 0) acc = config.defaultAccuracyMps;
    if (acc < config.accuracyFloorMps) acc = config.accuracyFloorMps;
    return acc * acc;
  }
}

/// Tuning for [SpeedFusion]. Defaults are sized for a dashboard-mounted phone;
/// kept here (not in the mood `Thresholds`) because these are filter noise
/// parameters, not mood-cascade thresholds.
class SpeedFusionConfig {
  const SpeedFusionConfig({
    this.accelNoise = 0.3,
    this.biasWalk = 0.01,
    this.accuracyFloorMps = 0.3,
    this.defaultAccuracyMps = 1.0,
    this.maxStepSeconds = 1.0,
    this.zuptSpeedMps = 1.0,
    this.zuptVariance = 0.0025, // (0.05 m/s)^2: a hard pin to zero
    this.gpsStale = const Duration(seconds: 3),
    this.initialSpeedVar = 100.0,
    this.initialBiasVar = 1.0,
  });

  /// Accelerometer noise std (m/s^2): velocity process noise per step.
  final double accelNoise;

  /// Bias random-walk std (m/s^2): how fast the bias estimate may wander.
  final double biasWalk;

  /// Floor on reported GPS speed accuracy so an over-optimistic fix cannot make
  /// the filter blindly trust it.
  final double accuracyFloorMps;

  /// Fallback accuracy when the chip reports none (0).
  final double defaultAccuracyMps;

  /// Cap on a single prediction step.
  final double maxStepSeconds;

  /// Below this last-known GPS speed a quiet phone counts as stopped (ZUPT).
  final double zuptSpeedMps;

  /// Measurement variance for the ZUPT pseudo-fix (very small = hard pin).
  final double zuptVariance;

  /// After this long with no GPS we are dead-reckoning (e.g. a tunnel) and must
  /// not ZUPT, since we cannot confirm a stop.
  final Duration gpsStale;

  /// Initial speed/bias variances (large = trust the first GPS fix).
  final double initialSpeedVar;
  final double initialBiasVar;
}

/// One input to the fusion filter, time-stamped so the filter is pure and
/// deterministic (no wall-clock reads inside).
sealed class SpeedEvent {
  const SpeedEvent(this.at);
  final DateTime at;
}

/// A GPS fix.
class GpsSpeedEvent extends SpeedEvent {
  const GpsSpeedEvent(this.sample, DateTime at) : super(at);
  final GpsSpeedSample sample;
}

/// A longitudinal accelerometer sample (m/s^2, gravity removed). `quiet` flags
/// that the phone is mechanically still (low vibration / no net acceleration).
class AccelEvent extends SpeedEvent {
  const AccelEvent(
    this.longitudinalMps2, {
    required DateTime at,
    this.quiet = false,
  }) : super(at);
  final double longitudinalMps2;
  final bool quiet;
}

/// Live accelerometer input for [fuseSpeed]: the longitudinal acceleration plus
/// the stillness hint. Carries no timestamp — [fuseSpeed] stamps it from the
/// clock as events arrive.
class AccelInput {
  const AccelInput(this.longitudinalMps2, {this.quiet = false});
  final double longitudinalMps2;
  final bool quiet;
}

/// Merge a GPS-sample stream and an accelerometer stream into one fused speed
/// stream (km/h). Each incoming event is time-stamped from `clock` (real wall
/// clock in production, a deterministic sequence in tests) and run through one
/// shared [SpeedFusion]. Emits one value per input event.
Stream<double> fuseSpeed({
  required Stream<GpsSpeedSample> gps,
  required Stream<AccelInput> accel,
  DateTime Function()? clock,
  SpeedFusion? filter,
  SpeedFusionConfig config = const SpeedFusionConfig(),
}) {
  final now = clock ?? DateTime.now;
  final f = filter ?? SpeedFusion(config);
  return Rx.merge<SpeedEvent>([
    gps.map((s) => GpsSpeedEvent(s, now())),
    accel.map((a) => AccelEvent(a.longitudinalMps2, at: now(), quiet: a.quiet)),
  ]).map(f.process);
}
