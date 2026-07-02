import 'package:flutter_test/flutter_test.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/strings.dart';

void main() {
  for (final l in AppLang.values) {
    test('AI-setup strings are non-empty for $l', () {
      expect(Strings.aiSetupSpoken(l), isNotEmpty);
      expect(Strings.aiSetupTitle(l), isNotEmpty);
      expect(Strings.aiSetupBody(l), isNotEmpty);
      expect(Strings.aiKeyLabel(l), isNotEmpty);
      expect(Strings.aiKeyHint(l), isNotEmpty);
    });
  }

  test('the provider hint names MiniMax and OpenAI', () {
    final es = Strings.aiKeyHint(AppLang.es);
    expect(es.toLowerCase(), contains('minimax'));
    expect(es.toLowerCase(), contains('openai'));
  });
}
