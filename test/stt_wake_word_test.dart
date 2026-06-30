import 'package:chispa/voice/stt_wake_word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('containsWakeWord', () {
    test('matches the keyword anywhere in the transcript', () {
      expect(containsWakeWord('oye chispa ayúdame', 'chispa'), isTrue);
      expect(containsWakeWord('CHISPA', 'chispa'), isTrue);
    });

    test('is diacritic-insensitive', () {
      expect(containsWakeWord('chíspa', 'chispa'), isTrue);
    });

    test('does not match unrelated speech', () {
      expect(containsWakeWord('vamos a rodar', 'chispa'), isFalse);
    });
  });
}
