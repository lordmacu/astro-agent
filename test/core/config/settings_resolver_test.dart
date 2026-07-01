import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/setting_key.dart';
import 'package:astro/core/config/settings_resolver.dart';
import 'package:astro/core/config/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsStore> store(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    return SettingsStore(await SharedPreferences.getInstance());
  }

  test('user setting wins over env', () async {
    final s = await store({'llmApiKey': 'user-key'});
    expect(
      resolveSecret(store: s, key: SettingKey.llmApiKey, envDefine: 'env-key'),
      'user-key',
    );
  });

  test('falls back to env when user setting is empty', () async {
    final s = await store({});
    expect(
      resolveSecret(store: s, key: SettingKey.llmApiKey, envDefine: 'env-key'),
      'env-key',
    );
  });

  test('falls back to the given fallback when both empty', () async {
    final s = await store({});
    expect(
      resolveSecret(
        store: s,
        key: SettingKey.llmModel,
        envDefine: '',
        fallback: 'MiniMax-M3',
      ),
      'MiniMax-M3',
    );
  });
}
