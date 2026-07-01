import 'package:astro/brain/tools/context_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContextTool', () {
    test('reports time, date, and rounded speed', () async {
      final tool = ContextTool(
        now: () => DateTime(2026, 7, 1, 9, 5),
        speedKmh: () => 62.4,
      );
      final result = await tool.run(const {});

      expect(result.isError, isFalse);
      expect(result.content, contains('09:05'));
      expect(result.content, contains('2026-07-01'));
      expect(result.content, contains('weekday 3')); // Wednesday
      expect(result.content, contains('62 km/h'));
    });

    test('says speed is unknown without a GPS fix', () async {
      final tool = ContextTool(
        now: () => DateTime(2026, 1, 1),
        speedKmh: () => null,
      );
      final result = await tool.run(const {});

      expect(result.content.toLowerCase(), contains('unknown'));
    });

    test('includes the resolved location when available', () async {
      final tool = ContextTool(
        now: () => DateTime(2026, 1, 1),
        speedKmh: () => 0,
        locationName: () async => 'Chapinero, Bogotá',
      );
      final result = await tool.run(const {});

      expect(result.content, contains('Chapinero, Bogotá'));
    });

    test('omits the location line when it cannot be resolved', () async {
      final tool = ContextTool(
        now: () => DateTime(2026, 1, 1),
        speedKmh: () => 0,
        locationName: () async => null,
      );
      final result = await tool.run(const {});

      expect(result.content.toLowerCase(), isNot(contains('location')));
    });

    test('omits the speed line in normal mode', () async {
      final tool = ContextTool(
        now: () => DateTime(2026, 1, 1),
        speedKmh: () => 62.4,
        carMode: () => false,
      );
      final result = await tool.run(const {});

      expect(result.content.toLowerCase(), isNot(contains('speed')));
      expect(result.content, contains('2026-01-01')); // still gives time
    });

    test('includes the speed line in car mode', () async {
      final tool = ContextTool(
        now: () => DateTime(2026, 1, 1),
        speedKmh: () => 62.4,
        carMode: () => true,
      );
      final result = await tool.run(const {});

      expect(result.content, contains('62 km/h'));
    });

    test('includes battery when provided, noting charging', () async {
      final tool = ContextTool(
        now: () => DateTime(2026, 1, 1),
        speedKmh: () => 0,
        battery: () async => (82, true),
      );
      final result = await tool.run(const {});

      expect(result.content, contains('Battery: 82% (charging)'));
    });

    test('omits the battery line when unavailable', () async {
      final tool = ContextTool(
        now: () => DateTime(2026, 1, 1),
        speedKmh: () => 0,
        battery: () async => null,
      );
      final result = await tool.run(const {});

      expect(result.content.toLowerCase(), isNot(contains('battery')));
    });

    test('is read-only and named get_context', () {
      final tool = ContextTool(speedKmh: () => 0);
      expect(tool.name, 'get_context');
      expect(tool.mutates, isFalse);
    });
  });
}
