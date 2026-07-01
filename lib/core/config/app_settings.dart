import 'package:freezed_annotation/freezed_annotation.dart';

import 'setting_key.dart';
import 'settings_store.dart';

part 'app_settings.freezed.dart';

/// Immutable snapshot of every user setting. Built from the store on startup and
/// replaced (copyWith) on each edit.
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    required double voiceRate,
    required double voicePitch,
    required String voiceLanguage,
    required bool neuralVoiceEnabled,
    required bool neuralVoiceInstalled,
    required String neuralVoicePath,
    required String llmModel,
    required String llmApiKey,
    required String searchApiKey,
    required bool wakeWordEnabled,
    required String wakeWord,
    required double wakeWordSensitivity,
    required bool navListenerEnabled,
    required bool autoBrightnessEnabled,
  }) = _AppSettings;

  factory AppSettings.fromStore(SettingsStore s) => AppSettings(
    voiceRate: s.getDouble(SettingKey.voiceRate, 0.56),
    voicePitch: s.getDouble(SettingKey.voicePitch, 1.0),
    voiceLanguage: s.getString(SettingKey.voiceLanguage, 'es'),
    neuralVoiceEnabled: s.getBool(SettingKey.neuralVoiceEnabled, false),
    neuralVoiceInstalled: s.getBool(SettingKey.neuralVoiceInstalled, false),
    neuralVoicePath: s.getString(SettingKey.neuralVoicePath, ''),
    llmModel: s.getString(SettingKey.llmModel, 'MiniMax-M3'),
    llmApiKey: s.getString(SettingKey.llmApiKey, ''),
    searchApiKey: s.getString(SettingKey.searchApiKey, ''),
    wakeWordEnabled: s.getBool(SettingKey.wakeWordEnabled, true),
    wakeWord: s.getString(SettingKey.wakeWord, 'hola astro'),
    wakeWordSensitivity: s.getDouble(SettingKey.wakeWordSensitivity, 0.5),
    navListenerEnabled: s.getBool(SettingKey.navListenerEnabled, true),
    autoBrightnessEnabled: s.getBool(SettingKey.autoBrightnessEnabled, true),
  );
}
