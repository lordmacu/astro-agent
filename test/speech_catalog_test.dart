import 'package:chispa/core/config/thresholds.dart';
import 'package:chispa/core/state/app_state.dart';
import 'package:chispa/core/state/mood_resolver.dart';
import 'package:chispa/core/state/speech_line.dart';
import 'package:chispa/voice/speech_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every line has English and Spanish text', () {
    for (final line in SpeechLine.values) {
      final en = SpeechCatalog.text(line, SpeechLang.en);
      final es = SpeechCatalog.text(line, SpeechLang.es);
      expect(en, isNotEmpty, reason: 'missing EN for $line');
      expect(es, isNotEmpty, reason: 'missing ES for $line');
      expect(en, isNot(es), reason: '$line is identical in both languages');
    }
  });

  test('the resolver emits a bilingual line for an excited mood', () {
    const resolver = MoodResolver(Thresholds());
    final line = resolver.resolve(const AppState(longitudinalG: 0.6)).line;

    expect(line, SpeechLine.letsGo);
    expect(SpeechCatalog.text(line!, SpeechLang.en), "Let's go!");
    expect(SpeechCatalog.text(line, SpeechLang.es), '¡Eso, vamos!');
  });
}
