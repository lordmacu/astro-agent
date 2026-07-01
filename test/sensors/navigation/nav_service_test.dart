import 'package:flutter_test/flutter_test.dart';
import 'package:astro/core/state/mood.dart';
import 'package:astro/sensors/navigation/nav_service.dart';
import 'package:astro/sensors/navigation/nav_reading.dart';

void main() {
  test('maps raw Maps events to NavReadings', () async {
    final raw = Stream<dynamic>.fromIterable([
      {'title': '200 m', 'text': 'Gira a la derecha', 'removed': false},
      {'title': 'Astro', 'text': 'Has llegado', 'removed': false},
      {'title': '200 m', 'text': 'Gira a la derecha', 'removed': true},
    ]);
    final service = NavService(rawEvents: raw);
    final out = await service.readings().toList();

    expect(out[0].turnDirection, TurnDirection.right);
    expect(out[0].distanceM, 200);
    expect(out[1].arrived, true);
    expect(out[2], NavReading.none);
  });

  test('tolerates a non-map event by emitting neutral', () async {
    final service = NavService(rawEvents: Stream<dynamic>.value('garbage'));
    final out = await service.readings().toList();
    expect(out, [NavReading.none]);
  });
}
