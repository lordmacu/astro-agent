import 'app_lang.dart';

/// Bilingual UI copy. One method per string; interpolated ones take params.
/// Mirrors `voice/speech_catalog.dart`: this is the single place UI Spanish
/// lives. Grow it as tasks migrate hardcoded strings.
abstract final class Strings {
  static String _pick(AppLang l, {required String en, required String es}) =>
      l == AppLang.es ? es : en;

  static String settingsTitle(AppLang l) =>
      _pick(l, en: 'Settings', es: 'Configuración');
  static String save(AppLang l) => _pick(l, en: 'Save', es: 'Guardar');
  static String cancel(AppLang l) => _pick(l, en: 'Cancel', es: 'Cancelar');
  static String listening(AppLang l) =>
      _pick(l, en: 'Listening…', es: 'Escuchando…');
  static String thinking(AppLang l) =>
      _pick(l, en: 'Thinking…', es: 'Pensando…');
  static String wakeHint(String word, AppLang l) =>
      _pick(l, en: 'Say «$word» or tap 🎙️', es: 'Di «$word» o tócala 🎙️');
  static String confirmCall(String name, AppLang l) =>
      _pick(l, en: 'Call $name?', es: '¿Llamo a $name?');
  static String brightnessSet(int level, AppLang l) =>
      _pick(l, en: 'Brightness at $level%.', es: 'Brillo en $level%.');
}
