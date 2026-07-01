import 'package:astro/core/config/design_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmbientPalette.fromHour', () {
    test('maps the clock to the four phases', () {
      // night 20:00–04:59
      expect(AmbientPalette.fromHour(0), AmbientPalette.night);
      expect(AmbientPalette.fromHour(4), AmbientPalette.night);
      expect(AmbientPalette.fromHour(20), AmbientPalette.night);
      expect(AmbientPalette.fromHour(23), AmbientPalette.night);
      // dawn 05:00–07:59
      expect(AmbientPalette.fromHour(5), AmbientPalette.dawn);
      expect(AmbientPalette.fromHour(7), AmbientPalette.dawn);
      // day 08:00–17:59
      expect(AmbientPalette.fromHour(8), AmbientPalette.day);
      expect(AmbientPalette.fromHour(12), AmbientPalette.day);
      expect(AmbientPalette.fromHour(17), AmbientPalette.day);
      // dusk 18:00–19:59
      expect(AmbientPalette.fromHour(18), AmbientPalette.dusk);
      expect(AmbientPalette.fromHour(19), AmbientPalette.dusk);
    });
  });
}
