import 'package:astro/brain/tools/weather_tool.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFetch {
  FakeFetch(this.result);
  final String? result;
  String? lastPlace;
  Future<String?> call(String place) async {
    lastPlace = place;
    return result;
  }
}

void main() {
  group('WeatherTool', () {
    test('is read-only and named clima', () {
      final tool = WeatherTool(fetch: FakeFetch('x').call);
      expect(tool.name, 'clima');
      expect(tool.mutates, isFalse);
    });

    test('passes the place and returns the summary', () async {
      final fetch = FakeFetch('Bogotá: ⛅️ +19°C');
      final tool = WeatherTool(fetch: fetch.call);
      final result = await tool.run({'place': 'Bogotá'});
      expect(fetch.lastPlace, 'Bogotá');
      expect(result.content, contains('+19°C'));
    });

    test('empty place is passed through (current location)', () async {
      final fetch = FakeFetch('Aquí: ☀️ +25°C');
      await WeatherTool(fetch: fetch.call).run(const {});
      expect(fetch.lastPlace, '');
    });

    test('a failed lookup reports it', () async {
      final tool = WeatherTool(fetch: FakeFetch(null).call);
      final result = await tool.run({'place': 'Nowhere'});
      expect(result.content.toLowerCase(), contains('no pude'));
    });
  });
}
