import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lang.dart';

/// The device's language, from the platform locale. Overridable in tests.
/// Recompute on a live locale change with `ref.invalidate(deviceLangProvider)`.
final deviceLangProvider = Provider<AppLang>(
  (_) => appLangFromLocale(PlatformDispatcher.instance.locale.languageCode),
);

/// The user's language preference (Auto/ES/EN), restored from disk and saved on
/// change. Starts at [LangPref.auto].
class LangPrefController extends Notifier<LangPref> {
  @override
  LangPref build() {
    const LangStore()
        .load()
        .then((p) {
          if (p != LangPref.auto) state = p;
        })
        .catchError((_) {});
    return LangPref.auto;
  }

  void set(LangPref pref) {
    state = pref;
    const LangStore().save(pref).catchError((_) {});
  }
}

final langPrefProvider = NotifierProvider<LangPrefController, LangPref>(
  LangPrefController.new,
);

/// The resolved app language: the preference, or the device language when Auto.
final langProvider = Provider<AppLang>((ref) {
  return switch (ref.watch(langPrefProvider)) {
    LangPref.es => AppLang.es,
    LangPref.en => AppLang.en,
    LangPref.auto => ref.watch(deviceLangProvider),
  };
});
