/// First-order low-pass filter for noisy sensor values. Each `add` moves the
/// running value a fraction (`factor`) toward the target: a low factor smooths
/// hard (slow to react), a high factor reacts fast (less smoothing).
///
/// ```
/// value += (target - value) * factor;
/// ```
class LowPass {
  LowPass({this.factor = 0.2, double initial = 0}) : _value = initial;

  /// Smoothing strength in (0, 1]. Lower = smoother, higher = more reactive.
  final double factor;

  double _value;

  double get value => _value;

  /// Feed a new raw sample; returns the smoothed value.
  double add(double target) {
    _value += (target - _value) * factor;
    return _value;
  }

  void reset([double value = 0]) => _value = value;
}
