// test/voice/tts_provider_selection_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/voice/system_tts.dart';
import 'package:astro/voice/tts_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses SystemTts when neural is not installed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    expect(c.read(ttsProvider), isA<SystemTts>());
  });

  test('uses SystemTts when installed but disabled', () async {
    SharedPreferences.setMockInitialValues({
      'neuralVoiceInstalled': true,
      'neuralVoiceEnabled': false,
      'neuralVoicePath': '/tmp/model',
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    expect(c.read(ttsProvider), isA<SystemTts>());
  });
}
