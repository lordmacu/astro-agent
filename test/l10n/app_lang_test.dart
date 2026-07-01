import 'package:astro/core/l10n/app_lang.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('appLangFromLocale maps es to es, everything else to en', () {
    expect(appLangFromLocale('es'), AppLang.es);
    expect(appLangFromLocale('en'), AppLang.en);
    expect(appLangFromLocale('fr'), AppLang.en); // fallback
    expect(appLangFromLocale(''), AppLang.en);
  });

  group('LangStore', () {
    test('defaults to auto when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await const LangStore().load(), LangPref.auto);
    });

    test('save then load round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      const store = LangStore();
      await store.save(LangPref.en);
      expect(await store.load(), LangPref.en);
    });

    test('an unrecognised stored value loads as auto', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lang_pref', 'bogus');
      expect(await const LangStore().load(), LangPref.auto);
    });
  });
}
