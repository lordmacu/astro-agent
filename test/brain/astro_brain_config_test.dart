import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/brain/astro_brain_provider.dart';
import 'package:astro/core/config/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  test('model comes from the user setting when set', () async {
    final c = await container({'llmModel': 'MiniMax-Custom'});
    expect(c.read(astroModelProvider), 'MiniMax-Custom');
  });

  test('model defaults to the keyless Kilo free model when unset', () async {
    final c = await container({});
    expect(
      c.read(astroModelProvider),
      'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
    );
  });

  test('configured flag is true once a key is set', () async {
    final c = await container({'llmApiKey': 'k'});
    expect(c.read(astroConfiguredProvider), true);
  });

  test('configured flag is false without a key on a paid model', () async {
    final c = await container({'llmModel': 'MiniMax-M3'}); // paid, no key
    expect(c.read(astroConfiguredProvider), false);
  });

  test('configured flag is true by default (keyless free model)', () async {
    final c = await container({}); // default model is the keyless free one
    expect(c.read(astroConfiguredProvider), true);
  });

  test('configured flag is true for a keyless free model', () async {
    // Kilo free models (id ends in ":free") need no API key.
    final c = await container({'llmModel': 'poolside/laguna-m.1:free'});
    expect(c.read(astroConfiguredProvider), true);
  });
}
