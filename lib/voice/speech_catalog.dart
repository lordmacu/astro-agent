import '../core/state/speech_line.dart';

/// The languages Chispa speaks.
enum SpeechLang { en, es }

/// Bilingual text for every `SpeechLine`. This is the one place where Spanish
/// lives — as voice content, not code. Add a language by adding a column here;
/// the resolver and state machine never change. Lines are short and casual,
/// matching the in-car pet tone.
abstract final class SpeechCatalog {
  static const Map<SpeechLine, Map<SpeechLang, String>> _text = {
    SpeechLine.letsGo: {
      SpeechLang.en: "Let's go!",
      SpeechLang.es: '¡Eso, vamos!',
    },
    SpeechLine.holdOn: {
      SpeechLang.en: 'Whoa, hold on!',
      SpeechLang.es: '¡Frenada, sujétate!',
    },
    SpeechLine.bump: {
      SpeechLang.en: 'Oof, a bump!',
      SpeechLang.es: '¡Uy, un bache!',
    },
    SpeechLine.curve: {
      SpeechLang.en: 'Curve!',
      SpeechLang.es: '¡Curvaaa!',
    },
    SpeechLine.engineWarm: {
      SpeechLang.en: 'Easy, the engine is warm.',
      SpeechLang.es: 'Con calma, el motor está caliente.',
    },
    SpeechLine.faultCode: {
      SpeechLang.en: 'Heads up, a fault code.',
      SpeechLang.es: 'Ojo, hay un código de falla.',
    },
    SpeechLine.arrived: {
      SpeechLang.en: 'We made it!',
      SpeechLang.es: '¡Llegamos!',
    },
  };

  /// The text for a line in the given language, falling back to English.
  static String text(SpeechLine line, SpeechLang lang) {
    final byLang = _text[line]!;
    return byLang[lang] ?? byLang[SpeechLang.en]!;
  }
}
