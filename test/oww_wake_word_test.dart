import 'dart:async';

import 'package:chispa/voice/oww_wake_word.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('onWake emits each time the event channel emits', () async {
    final events = StreamController<dynamic>.broadcast();
    final detector = OwwWakeWord(
      control: const MethodChannel('test/wakeword/control'),
      events: events.stream,
    );

    final wakes = <void>[];
    final sub = detector.onWake.listen((_) => wakes.add(null));

    events.add('oye_chispa');
    events.add('chispa');
    await Future<void>.delayed(Duration.zero);

    expect(wakes.length, 2);
    await sub.cancel();
    await events.close();
  });

  test('control methods invoke the native side with the right names', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/wakeword/control');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    final detector = OwwWakeWord(
      control: channel,
      events: const Stream<dynamic>.empty(),
    );
    await detector.start();
    await detector.pause();
    await detector.resume();
    await detector.setThreshold('chispa', 0.7);
    await detector.stop();

    expect(calls.map((c) => c.method).toList(), [
      'start',
      'pause',
      'resume',
      'setThreshold',
      'stop',
    ]);
    expect(calls[3].arguments, {'phrase': 'chispa', 'value': 0.7});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
