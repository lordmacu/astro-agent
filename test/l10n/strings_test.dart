import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns the right language and interpolates', () {
    expect(Strings.save(AppLang.es), 'Guardar');
    expect(Strings.save(AppLang.en), 'Save');
    expect(Strings.confirmCall('Ana', AppLang.es), '¿Llamo a Ana?');
    expect(Strings.confirmCall('Ana', AppLang.en), 'Call Ana?');
  });
}
