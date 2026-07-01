import 'dart:async';

/// Turn a single-subscription [source] into a broadcast stream that stays
/// subscribed for the app's lifetime. Sensor plugins hand back single-listener
/// streams; wrapping them lets the combined `appStateProvider` re-listen freely
/// (e.g. when it rebuilds on a mode/settings change) without hitting
/// "Stream has already been listened to". The source subscription is never torn
/// down — fine for app-lifetime sensor sources.
Stream<T> shareForever<T>(Stream<T> source) {
  final controller = StreamController<T>.broadcast();
  source.listen(
    controller.add,
    onError: controller.addError,
    onDone: controller.close,
  );
  return controller.stream;
}
