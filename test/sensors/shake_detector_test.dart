import 'package:astro/sensors/motion/shake_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ShakeDetector make() => ShakeDetector(
    thresholdG: 1.2,
    window: const Duration(milliseconds: 1000),
    count: 5,
  );

  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('one big jerk is not a shake', () {
    final d = make();
    expect(d.add(3.0, at(0)), isFalse);
    expect(d.shaking, isFalse);
  });

  test('enough jerks within the window is a shake', () {
    final d = make();
    for (var i = 0; i < 4; i++) {
      expect(d.add(2.0, at(i * 100)), isFalse); // 4 jerks → not yet
    }
    expect(d.add(2.0, at(400)), isTrue); // 5th within 1s → shake
  });

  test('sub-threshold samples never count', () {
    final d = make();
    for (var i = 0; i < 10; i++) {
      d.add(1.1, at(i * 50)); // below 1.2g
    }
    expect(d.shaking, isFalse);
  });

  test('old jerks age out of the window', () {
    final d = make();
    for (var i = 0; i < 5; i++) {
      d.add(2.0, at(i * 100)); // 5 jerks over 0–400ms → shaking
    }
    expect(d.shaking, isTrue);
    // Long quiet gap; a lone new jerk leaves only 1 in the window.
    expect(d.add(2.0, at(2000)), isFalse);
  });
}
