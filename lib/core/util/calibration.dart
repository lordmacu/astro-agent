import 'dart:math' as math;

/// Learns which way the phone's accelerometer points "forward" (along travel),
/// so the speed fusion's dead reckoning works no matter how the phone is
/// mounted — tilted, landscape, on a vent clip. This is the world-frame
/// projection the research calls for (Mad Location Manager's rotation step),
/// done without a magnetometer: the forward axis is *learned* from data.
///
/// Idea: when the GPS shows the car genuinely speeding up or braking in a
/// straight line, the device-frame acceleration vector at that moment points
/// along travel. Accumulate `accel * (dv/dt)` over many such windows; the sum
/// points "forward" (braking and accelerating reinforce the same axis because
/// both `accel` and `dv/dt` flip sign together). Normalize it and project each
/// raw sample onto it to get the longitudinal acceleration.
///
/// Until enough evidence is gathered it falls back to the device z-axis — the
/// project's documented dashboard-portrait assumption — so behavior is
/// unchanged on day one and only improves as it calibrates.
class ForwardCalibrator {
  ForwardCalibrator([this.config = const ForwardCalibratorConfig()]);

  final ForwardCalibratorConfig config;

  // Learned forward unit vector (device frame). Default: z-axis.
  double _fx = 0, _fy = 0, _fz = 1;

  // Correlation accumulator C += avgAccel * dvdt, per axis.
  double _cx = 0, _cy = 0, _cz = 0;

  // Running mean of device accel over the current GPS window.
  double _sx = 0, _sy = 0, _sz = 0;
  int _count = 0;

  double? _prevGpsSpeed;
  DateTime? _prevGpsT;

  /// The learned forward unit vector in the device frame, `[x, y, z]`.
  List<double> get forward => [_fx, _fy, _fz];

  /// The raw correlation accumulator `[Cx, Cy, Cz]`. Persist this to keep the
  /// learned axis across app restarts (and keep refining it).
  List<double> get accumulator => [_cx, _cy, _cz];

  /// Restore a previously-saved [accumulator] and recompute the forward axis.
  void loadAccumulator(List<double> c) {
    _cx = c[0];
    _cy = c[1];
    _cz = c[2];
    _refreshForward();
  }

  /// How much consistent evidence has been accumulated (magnitude of C).
  double get confidence => _length(_cx, _cy, _cz);

  /// Whether enough evidence has been gathered to trust the learned axis.
  bool get calibrated => confidence >= config.confidenceThreshold;

  /// Project a device-frame acceleration `[x, y, z]` (m/s^2) onto the forward
  /// axis, returning the longitudinal acceleration (m/s^2). Also feeds the
  /// sample into the current calibration window.
  double longitudinal(List<double> deviceAccelMps2) {
    final x = deviceAccelMps2[0];
    final y = deviceAccelMps2[1];
    final z = deviceAccelMps2[2];
    _sx += x;
    _sy += y;
    _sz += z;
    _count++;
    return x * _fx + y * _fy + z * _fz;
  }

  /// Close the current window with a GPS speed reading and learn from it: if the
  /// car's speed changed enough in a straight line, fold the averaged device
  /// acceleration into the forward-axis estimate.
  void addGpsSpeed(double speedMps, DateTime at) {
    final prevSpeed = _prevGpsSpeed;
    final prevT = _prevGpsT;
    if (prevSpeed != null && prevT != null && _count > 0) {
      final dt = at.difference(prevT).inMicroseconds / 1e6;
      if (dt > 0) {
        final dvdt = (speedMps - prevSpeed) / dt;
        if (dvdt.abs() >= config.minAbsDvdt) {
          final ax = _sx / _count;
          final ay = _sy / _count;
          final az = _sz / _count;
          _cx += ax * dvdt;
          _cy += ay * dvdt;
          _cz += az * dvdt;
          _refreshForward();
        }
      }
    }
    _prevGpsSpeed = speedMps;
    _prevGpsT = at;
    _sx = _sy = _sz = 0;
    _count = 0;
  }

  void _refreshForward() {
    final len = _length(_cx, _cy, _cz);
    if (len < config.confidenceThreshold) return; // not trustworthy yet
    _fx = _cx / len;
    _fy = _cy / len;
    _fz = _cz / len;
  }

  static double _length(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z);
}

/// Tuning for [ForwardCalibrator].
class ForwardCalibratorConfig {
  const ForwardCalibratorConfig({
    this.minAbsDvdt = 0.3,
    this.confidenceThreshold = 5.0,
  });

  /// Only learn from windows whose GPS-measured longitudinal acceleration
  /// magnitude (m/s^2) exceeds this — ignores constant-speed noise and turns.
  final double minAbsDvdt;

  /// Magnitude the correlation accumulator must reach before the learned axis
  /// is trusted (and replaces the default z-axis).
  final double confidenceThreshold;
}
