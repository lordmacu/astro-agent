import 'package:astro/platform/haptics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Haptics', () {
    test('fires the tone for each semantic action when enabled', () async {
      final fired = <HapticTone>[];
      final h = Haptics(enabled: () => true, fire: (t) async => fired.add(t));

      await h.listenStart();
      await h.cancel();
      await h.pet();
      await h.confirm();
      await h.select();

      expect(fired, [
        HapticTone.medium, // listenStart
        HapticTone.light, // cancel
        HapticTone.selection, // pet
        HapticTone.medium, // confirm
        HapticTone.selection, // select
      ]);
    });

    test('thinking alternates tone by step for a heartbeat feel', () async {
      final fired = <HapticTone>[];
      final h = Haptics(enabled: () => true, fire: (t) async => fired.add(t));

      for (var step = 0; step < 4; step++) {
        await h.thinking(step);
      }

      expect(fired, [
        HapticTone.light, // 0 (even)
        HapticTone.selection, // 1 (odd)
        HapticTone.light, // 2
        HapticTone.selection, // 3
      ]);
    });

    test('does nothing when disabled', () async {
      final fired = <HapticTone>[];
      final h = Haptics(enabled: () => false, fire: (t) async => fired.add(t));

      await h.listenStart();
      await h.confirm();

      expect(fired, isEmpty);
    });

    test('swallows platform errors (no vibrator)', () async {
      final h = Haptics(
        enabled: () => true,
        fire: (_) async => throw Exception('no vibrator'),
      );
      // Must not throw.
      await h.listenStart();
    });

    test('re-reads enabled on each call (live toggle)', () async {
      var on = false;
      final fired = <HapticTone>[];
      final h = Haptics(enabled: () => on, fire: (t) async => fired.add(t));

      await h.select();
      expect(fired, isEmpty);
      on = true;
      await h.select();
      expect(fired, [HapticTone.selection]);
    });
  });
}
