import 'dart:collection';

/// Detects "the phone is being shaken" from the motion stream — just for fun,
/// so Astro can go dizzy. A sample counts as a jerk when its gravity-free
/// acceleration magnitude passes [thresholdG]; [shaking] is true while at least
/// [count] jerks land within [window]. That both ignores a single bump and
/// makes the state linger ~[window] after you stop, so the mood reads clearly.
///
/// Pure and time-injected (`now` is passed in), so it's deterministically
/// testable with no real clock.
class ShakeDetector {
  ShakeDetector({
    required this.thresholdG,
    required this.window,
    required this.count,
  });

  final double thresholdG;
  final Duration window;
  final int count;

  final Queue<DateTime> _jerks = Queue<DateTime>();
  bool _shaking = false;

  bool get shaking => _shaking;

  /// Feed one acceleration magnitude (gravity-free g) at time [now]. Returns the
  /// updated [shaking] state.
  bool add(double magnitudeG, DateTime now) {
    if (magnitudeG >= thresholdG) _jerks.addLast(now);
    while (_jerks.isNotEmpty && now.difference(_jerks.first) > window) {
      _jerks.removeFirst();
    }
    _shaking = _jerks.length >= count;
    return _shaking;
  }
}
