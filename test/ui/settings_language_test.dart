import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setting the language pref to en resolves to en', () {
    final c = ProviderContainer(
      overrides: [deviceLangProvider.overrideWithValue(AppLang.es)],
    );
    addTearDown(c.dispose);
    c.read(langPrefProvider.notifier).set(LangPref.en);
    expect(c.read(langProvider), AppLang.en);
  });
}
