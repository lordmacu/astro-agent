import 'setting_key.dart';
import 'settings_store.dart';

/// Resolve a secret/config value with precedence:
///   user setting (store) > env/dart-define (envDefine) > fallback.
/// Callers pass their existing `.env`/dart-define result as [envDefine]; this
/// only adds the user-override layer on top, so nothing about `.env` changes.
String resolveSecret({
  required SettingsStore store,
  required SettingKey key,
  required String envDefine,
  String fallback = '',
}) {
  final user = store.getString(key, '').trim();
  if (user.isNotEmpty) return user;
  if (envDefine.trim().isNotEmpty) return envDefine.trim();
  return fallback;
}
