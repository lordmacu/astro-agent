import 'package:chispa/voice/oww_wake_word.dart';
import 'package:chispa/voice/stt_wake_word.dart';
import 'package:chispa/voice/voice_interfaces.dart';
import 'package:chispa/voice/wake_word_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the platform channel to avoid MissingPluginException in teardown.
  setUpAll(() {
    const channel = MethodChannel('chispa/wakeword/control');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return null;
        });
  });

  test('defaults to the openWakeWord detector', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(wakeWordProvider), isA<OwwWakeWord>());
  });

  test('can be overridden with the STT fallback', () {
    final c = ProviderContainer(
      overrides: [wakeWordProvider.overrideWithValue(SttWakeWord())],
    );
    addTearDown(c.dispose);
    expect(c.read(wakeWordProvider), isA<WakeWordDetector>());
    expect(c.read(wakeWordProvider), isA<SttWakeWord>());
  });
}
