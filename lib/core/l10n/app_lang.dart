import 'package:shared_preferences/shared_preferences.dart';

/// The languages the app supports. Add one by adding a value here and a column
/// in `Strings` / `SpeechCatalog`.
enum AppLang { en, es }

/// The persisted user choice. `auto` follows the device locale.
enum LangPref { auto, es, en }

/// Map a locale language code to an [AppLang]; English is the fallback.
AppLang appLangFromLocale(String languageCode) =>
    languageCode.toLowerCase() == 'es' ? AppLang.es : AppLang.en;

/// Persists [LangPref] in SharedPreferences. Missing/corrupt → auto.
class LangStore {
  const LangStore();

  static const _key = 'lang_pref';

  Future<LangPref> load() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'es' => LangPref.es,
      'en' => LangPref.en,
      _ => LangPref.auto,
    };
  }

  Future<void> save(LangPref pref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pref.name);
  }
}
