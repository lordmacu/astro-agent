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

  test('model defaults to MiniMax-M3 when unset', () async {
    final c = await container({});
    expect(c.read(astroModelProvider), 'MiniMax-M3');
  });

  test('configured flag is true once a key is set', () async {
    final c = await container({'llmApiKey': 'k'});
    expect(c.read(astroConfiguredProvider), true);
  });
}
