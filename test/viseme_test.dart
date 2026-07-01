import 'dart:math';

import 'package:astro/voice/viseme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('never repeats the same viseme twice in a row', () {
    final seq = VisemeSequencer(random: Random(42));
    var previous = seq.current;
    for (var i = 0; i < 500; i++) {
      final next = seq.next();
      expect(next, isNot(previous));
      previous = next;
    }
  });

  test('eventually draws every shape in the bag', () {
    final seq = VisemeSequencer(random: Random(7));
    final seen = <Viseme>{};
    for (var i = 0; i < 500; i++) {
      seen.add(seq.next());
    }
    expect(seen, containsAll(Viseme.values));
  });

  test('intervals stay in the 85-180 ms range', () {
    final seq = VisemeSequencer(random: Random(1));
    for (var i = 0; i < 100; i++) {
      final ms = seq.nextInterval().inMilliseconds;
      expect(ms, inInclusiveRange(85, 180));
    }
  });

  test('reset returns the mouth to a neutral shape', () {
    final seq = VisemeSequencer(random: Random(1))..next();
    seq.reset();
    expect(seq.current, Viseme.openSmall);
  });
}
