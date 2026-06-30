import 'package:proximity_sensor/proximity_sensor.dart';

/// Near/far proximity, used for the caress reaction. The plugin emits an int
/// that is > 0 when something is close. The service only produces data — the
/// mood decision stays in `MoodResolver`.
class ProximityService {
  ProximityService({required this.source});

  /// True when something is near.
  final Stream<bool> source;

  factory ProximityService.fromPlugin() => ProximityService(
        source: ProximitySensor.events.map((event) => event > 0),
      );

  Stream<bool> near() => source;
}
