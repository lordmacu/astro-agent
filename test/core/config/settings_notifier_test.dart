import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/app_settings.dart';
import 'package:astro/core/config/llm_models.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/config/settings_store.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exposes defaults matching current behavior', () async {
    final c = await _container();
    final s = c.read(settingsProvider);
    expect(s.voiceRate, 0.56);
    expect(s.llmModel, kDefaultModel);
    expect(s.wakeWordEnabled, true);
    expect(s.hapticsEnabled, true);
  });

  test('a setter persists and updates state', () async {
    final c = await _container();
    await c.read(settingsProvider.notifier).setVoiceRate(0.8);
    expect(c.read(settingsProvider).voiceRate, 0.8);
    // Persisted: a fresh store built on the same prefs sees the new value.
    final store = c.read(settingsStoreProvider);
    expect(store, isA<SettingsStore>());
    expect(AppSettings.fromStore(store).voiceRate, 0.8);
  });
}
