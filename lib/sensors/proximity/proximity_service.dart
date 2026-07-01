import 'package:flutter/services.dart';

/// Near/far proximity, used for the caress reaction. The service only produces
/// data — the mood decision stays in `MoodResolver`.
///
/// Reads the native `astro/proximity` EventChannel instead of the
/// `proximity_sensor` plugin. The plugin classifies near as `distance == 0`,
/// which never fires on devices whose only public TYPE_PROXIMITY sensor is a
/// "Palm" gesture sensor (some Samsungs) — so it always reported "far". The
/// native channel uses Android's real test, `value < maximumRange`.
class ProximityService {
  ProximityService({required this.source});

  /// True when something is near.
  final Stream<bool> source;

  factory ProximityService.fromChannel([EventChannel? channel]) {
    final ch = channel ?? const EventChannel('astro/proximity');
    return ProximityService(
      source: ch.receiveBroadcastStream().map((event) => event == true),
    );
  }

  Stream<bool> near() => source;
}
