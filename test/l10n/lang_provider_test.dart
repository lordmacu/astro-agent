import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer make(AppLang device) => ProviderContainer(
    overrides: [deviceLangProvider.overrideWithValue(device)],
  );

  test('auto follows the device language', () {
    final c = make(AppLang.es);
    addTearDown(c.dispose);
    expect(c.read(langProvider), AppLang.es);
  });

  test('an explicit preference overrides the device', () {
    final c = make(AppLang.es);
    addTearDown(c.dispose);
    c.read(langPrefProvider.notifier).set(LangPref.en);
    expect(c.read(langProvider), AppLang.en);
  });

  test('switching back to auto restores the device language', () {
    final c = make(AppLang.en);
    addTearDown(c.dispose);
    c.read(langPrefProvider.notifier).set(LangPref.es);
    expect(c.read(langProvider), AppLang.es);
    c.read(langPrefProvider.notifier).set(LangPref.auto);
    expect(c.read(langProvider), AppLang.en);
  });
}
