import 'package:shared_preferences/shared_preferences.dart';

import 'setting_key.dart';

/// Typed wrapper over SharedPreferences. Each getter takes the fallback to use
/// when the key is unset, so callers never see a null and defaults live at the
/// call site next to the setting's meaning.
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  String getString(SettingKey key, String fallback) =>
      _prefs.getString(key.name) ?? fallback;

  Future<void> setString(SettingKey key, String value) =>
      _prefs.setString(key.name, value);

  double getDouble(SettingKey key, double fallback) =>
      _prefs.getDouble(key.name) ?? fallback;

  Future<void> setDouble(SettingKey key, double value) =>
      _prefs.setDouble(key.name, value);

  bool getBool(SettingKey key, bool fallback) =>
      _prefs.getBool(key.name) ?? fallback;

  Future<void> setBool(SettingKey key, bool value) =>
      _prefs.setBool(key.name, value);

  Future<void> remove(SettingKey key) => _prefs.remove(key.name);
}
