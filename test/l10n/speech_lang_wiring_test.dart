import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:astro/core/state/app_state_provider.dart';
import 'package:astro/voice/speech_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('speechLangProvider follows the app language', () {
    final en = ProviderContainer(
      overrides: [deviceLangProvider.overrideWithValue(AppLang.en)],
    );
    addTearDown(en.dispose);
    expect(en.read(speechLangProvider), SpeechLang.en);

    final es = ProviderContainer(
      overrides: [deviceLangProvider.overrideWithValue(AppLang.es)],
    );
    addTearDown(es.dispose);
    expect(es.read(speechLangProvider), SpeechLang.es);
  });
}
