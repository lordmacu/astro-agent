import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/setting_key.dart';
import 'package:astro/core/config/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns the fallback when a key is unset', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    expect(store.getDouble(SettingKey.voiceRate, 0.56), 0.56);
    expect(store.getBool(SettingKey.wakeWordEnabled, true), true);
    expect(store.getString(SettingKey.llmModel, 'MiniMax-M3'), 'MiniMax-M3');
  });

  test('persists and reads back a value', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    await store.setDouble(SettingKey.voiceRate, 0.7);
    expect(store.getDouble(SettingKey.voiceRate, 0.56), 0.7);
  });

  test('remove restores the fallback', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    await store.setString(SettingKey.llmApiKey, 'secret');
    await store.remove(SettingKey.llmApiKey);
    expect(store.getString(SettingKey.llmApiKey, ''), '');
  });
}
