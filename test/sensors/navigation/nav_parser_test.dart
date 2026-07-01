import 'package:flutter_test/flutter_test.dart';
import 'package:astro/core/state/mood.dart';
import 'package:astro/sensors/navigation/nav_reading.dart';
import 'package:astro/sensors/navigation/nav_parser.dart';

void main() {
  group('NavParser', () {
    test('Spanish: distance + right turn', () {
      final r = NavParser.parse(
        title: '200 m',
        text: 'Gira a la derecha hacia Cra 7',
      );
      expect(r.turnDirection, TurnDirection.right);
      expect(r.distanceM, 200);
      expect(r.arrived, false);
    });

    test('Spanish: km with comma decimal + left', () {
      final r = NavParser.parse(title: '1,2 km', text: 'Gira a la izquierda');
      expect(r.turnDirection, TurnDirection.left);
      expect(r.distanceM, 1200);
    });

    test('English: distance + left turn', () {
      final r = NavParser.parse(title: '150 m', text: 'Turn left onto Main St');
      expect(r.turnDirection, TurnDirection.left);
      expect(r.distanceM, 150);
    });

    test('Spanish arrival', () {
      final r = NavParser.parse(
        title: 'Astro',
        text: 'Has llegado a tu destino',
      );
      expect(r.arrived, true);
      expect(r.turnDirection, TurnDirection.none);
    });

    test('English arrival', () {
      final r = NavParser.parse(text: 'You have arrived');
      expect(r.arrived, true);
    });

    test('"derecho" (straight, es) is NOT a right turn', () {
      final r = NavParser.parse(title: '300 m', text: 'Sigue derecho');
      expect(r.turnDirection, TurnDirection.none);
      expect(r.distanceM, 300);
    });

    test('removed notification → neutral', () {
      final r = NavParser.parse(
        title: '200 m',
        text: 'Gira a la derecha',
        removed: true,
      );
      expect(r, NavReading.none);
    });

    test('unrecognized → neutral', () {
      final r = NavParser.parse(title: 'Spotify', text: 'Now playing');
      expect(r, NavReading.none);
    });

    test('imperial distance is ignored (direction still parsed)', () {
      final r = NavParser.parse(title: '0.5 mi', text: 'Turn right');
      expect(r.turnDirection, TurnDirection.right);
      expect(r.distanceM, isNull);
    });

    test('speed unit "km/h" is NOT parsed as a distance', () {
      final r = NavParser.parse(text: '80 km/h');
      expect(
        r,
        NavReading.none,
        reason: '"km/h" is a speed, not a nav distance',
      );
    });
  });
}
