import 'package:astro/voice/stt_wake_word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('containsWakeWord', () {
    test('matches the keyword anywhere in the transcript', () {
      expect(containsWakeWord('oye astro ayúdame', 'astro'), isTrue);
      expect(containsWakeWord('ASTRO', 'astro'), isTrue);
    });

    test('is diacritic-insensitive', () {
      expect(containsWakeWord('ástro', 'astro'), isTrue);
    });

    test('does not match unrelated speech', () {
      expect(containsWakeWord('vamos a rodar', 'astro'), isFalse);
    });
  });
}
