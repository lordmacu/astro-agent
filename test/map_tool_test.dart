import 'package:astro/brain/tools/map_tool.dart';
import 'package:flutter_test/flutter_test.dart';

class Fake {
  String? navDest;
  String? nearQuery;
  bool navResult = true;
  bool nearResult = true;

  Future<bool> navigate(String d) async {
    navDest = d;
    return navResult;
  }

  Future<bool> nearby(String q) async {
    nearQuery = q;
    return nearResult;
  }
}

MapTool _tool(Fake f) => MapTool(navigate: f.navigate, nearby: f.nearby);

void main() {
  group('MapTool', () {
    test('is read-only and named mapa', () {
      final tool = _tool(Fake());
      expect(tool.name, 'mapa');
      expect(tool.mutates, isFalse);
    });

    test('navigate passes the destination', () async {
      final f = Fake();
      final result = await _tool(
        f,
      ).run({'action': 'navigate', 'destination': 'la casa'});
      expect(f.navDest, 'la casa');
      expect(result.content, contains('la casa'));
    });

    test('nearby passes the query', () async {
      final f = Fake();
      final result = await _tool(
        f,
      ).run({'action': 'nearby', 'query': 'gasolinera'});
      expect(f.nearQuery, 'gasolinera');
      expect(result.content, contains('gasolinera'));
    });

    test('navigate without a destination is an error', () async {
      final result = await _tool(Fake()).run({'action': 'navigate'});
      expect(result.isError, isTrue);
    });

    test('nearby without a query is an error', () async {
      final result = await _tool(Fake()).run({'action': 'nearby'});
      expect(result.isError, isTrue);
    });

    test('an unknown action is an error', () async {
      final result = await _tool(Fake()).run({'action': 'teleport'});
      expect(result.isError, isTrue);
    });

    test('a launch failure reports it', () async {
      final f = Fake()..navResult = false;
      final result = await _tool(
        f,
      ).run({'action': 'navigate', 'destination': 'x'});
      expect(result.content.toLowerCase(), contains('no pude'));
    });
  });
}
