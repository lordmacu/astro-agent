import 'package:astro/platform/media_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'shutter() invokes the "shutter" method and returns its result',
    () async {
      const channel = MethodChannel('astro/media');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final ok = await MediaController(channel: channel).shutter();
      expect(ok, isTrue);
      expect(calls, contains('shutter'));
    },
  );
}
