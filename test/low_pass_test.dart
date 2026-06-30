import 'package:chispa/core/util/low_pass.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moves toward the target by the factor each step', () {
    final f = LowPass(factor: 0.5);
    expect(f.add(10), 5);
    expect(f.add(10), 7.5);
    expect(f.add(10), 8.75);
  });

  test('a low factor smooths slower than a high factor', () {
    final slow = LowPass(factor: 0.1);
    final fast = LowPass(factor: 0.9);
    expect(slow.add(10), lessThan(fast.add(10)));
  });

  test('converges to the target over many samples', () {
    final f = LowPass(factor: 0.3);
    for (var i = 0; i < 100; i++) {
      f.add(5);
    }
    expect(f.value, closeTo(5, 1e-6));
  });

  test('reset returns to a value', () {
    final f = LowPass(factor: 0.5)..add(10);
    f.reset();
    expect(f.value, 0);
  });
}
