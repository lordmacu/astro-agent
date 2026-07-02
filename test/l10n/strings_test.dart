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

  test('UI labels differ by language', () {
    expect(Strings.modeCar(AppLang.es), 'CARRO');
    expect(Strings.modeCar(AppLang.en), 'CAR');
    expect(Strings.send(AppLang.es), 'Enviar');
    expect(Strings.send(AppLang.en), 'Send');
    expect(Strings.whichCalendar(AppLang.es), '¿En qué calendario?');
    expect(Strings.whichCalendar(AppLang.en), 'Which calendar?');
  });

  test('canned lines and interpolation differ by language', () {
    expect(Strings.wakeAck(AppLang.es), startsWith('¡Aquí estoy!'));
    expect(Strings.wakeAck(AppLang.en), startsWith("I'm here!"));
    expect(Strings.messageLeft('Ana', AppLang.es), contains('para Ana'));
    expect(Strings.messageLeft('Ana', AppLang.en), contains('for Ana'));
  });

  test('tool catalog labels/subtitles/permissions differ by language', () {
    expect(Strings.toolLabel('mapa', AppLang.es), 'Mapas');
    expect(Strings.toolLabel('mapa', AppLang.en), 'Maps');
    expect(Strings.toolSubtitle('music', AppLang.es), contains('música'));
    expect(Strings.toolSubtitle('music', AppLang.en), contains('music'));
    expect(Strings.permissionName('camera', AppLang.es), 'cámara');
    expect(Strings.permissionName('camera', AppLang.en), 'camera');
    // Unknown keys fall back to the key itself.
    expect(Strings.toolLabel('mystery', AppLang.en), 'mystery');
  });

  test('the about subtitle composes version, voice state and model', () {
    final es = Strings.aboutSubtitle('0.1.0', true, 'gpt-4o', AppLang.es);
    expect(es, contains('v0.1.0'));
    expect(es, contains('instalada'));
    expect(es, contains('gpt-4o'));
    final en = Strings.aboutSubtitle('0.1.0', false, 'gpt-4o', AppLang.en);
    expect(en, contains('not installed'));
  });
}
