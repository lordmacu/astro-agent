import 'package:flutter/services.dart';

import 'voice_interfaces.dart';

/// Production wake-word detector backed by the native openWakeWord engine
/// (Kotlin foreground service). Detections arrive on the [EventChannel]
/// `astro/wakeword`; control flows over the [MethodChannel]
/// `astro/wakeword/control`. The channels are injectable so the adapter is
/// unit-tested without the platform.
class OwwWakeWord implements WakeWordDetector {
  OwwWakeWord({MethodChannel? control, Stream<dynamic>? events})
    : _control = control ?? const MethodChannel('astro/wakeword/control'),
      _events =
          events ??
          const EventChannel('astro/wakeword').receiveBroadcastStream();

  final MethodChannel _control;
  final Stream<dynamic> _events;

  late final Stream<void> _onWake = _events.map((_) {});

  /// Fires once per native detection (the phrase that fired is dropped here;
  /// the interface only needs "woke").
  @override
  Stream<void> get onWake => _onWake;

  @override
  Future<void> start() => _control.invokeMethod<void>('start');

  @override
  Future<void> stop() => _control.invokeMethod<void>('stop');

  @override
  Future<void> pause() => _control.invokeMethod<void>('pause');

  @override
  Future<void> resume() => _control.invokeMethod<void>('resume');

  /// Override a phrase's firing threshold at runtime (tuning).
  Future<void> setThreshold(String phrase, double value) =>
      _control.invokeMethod<void>('setThreshold', <String, dynamic>{
        'phrase': phrase,
        'value': value,
      });

  /// Set the wake phrase the native engine listens for (from Settings).
  @override
  Future<void> setKeyword(String keyword) => _control.invokeMethod<void>(
    'setKeyword',
    <String, dynamic>{'keyword': keyword},
  );

  /// Set the native detection sensitivity in [0,1] (from the Settings slider).
  @override
  Future<void> setSensitivity(double value) => _control.invokeMethod<void>(
    'setSensitivity',
    <String, dynamic>{'value': value},
  );
}
