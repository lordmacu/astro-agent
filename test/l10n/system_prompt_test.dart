import 'package:astro/brain/astro_brain_provider.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/state/app_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the prompt forces the active language', () {
    final es = astroSystemPromptFor(AppMode.normal, AppLang.es);
    final en = astroSystemPromptFor(AppMode.normal, AppLang.en);
    expect(es.toLowerCase(), contains('español'));
    expect(en.toLowerCase(), contains('english'));
    // Tool names stay identical in both.
    expect(es, contains('comunicacion'));
    expect(en, contains('comunicacion'));
  });

  test('car mode adds the driving-safety closing', () {
    final car = astroSystemPromptFor(AppMode.car, AppLang.en);
    final normal = astroSystemPromptFor(AppMode.normal, AppLang.en);
    expect(car.toLowerCase(), contains('driving'));
    expect(normal.toLowerCase(), isNot(contains('driving')));
  });
}
