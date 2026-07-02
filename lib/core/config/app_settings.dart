import 'package:freezed_annotation/freezed_annotation.dart';

import 'llm_models.dart';
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
    required String sttModelPath,
    required String llmModel,
    required String llmApiKey,
    required String searchProvider,
    required String searchApiKey,
    required String searxngUrl,
    required bool wakeWordEnabled,
    required String wakeWord,
    required double wakeWordSensitivity,
    required bool navListenerEnabled,
    required bool autoBrightnessEnabled,
    required bool hapticsEnabled,
  }) = _AppSettings;

  factory AppSettings.fromStore(SettingsStore s) => AppSettings(
    voiceRate: s.getDouble(SettingKey.voiceRate, 0.56),
    voicePitch: s.getDouble(SettingKey.voicePitch, 1.0),
    voiceLanguage: s.getString(SettingKey.voiceLanguage, 'es'),
    neuralVoiceEnabled: s.getBool(SettingKey.neuralVoiceEnabled, false),
    neuralVoiceInstalled: s.getBool(SettingKey.neuralVoiceInstalled, false),
    neuralVoicePath: s.getString(SettingKey.neuralVoicePath, ''),
    sttModelPath: s.getString(SettingKey.sttModelPath, ''),
    llmModel: s.getString(SettingKey.llmModel, kDefaultModel),
    llmApiKey: s.getString(SettingKey.llmApiKey, ''),
    searchProvider: s.getString(SettingKey.searchProvider, 'tavily'),
    searchApiKey: s.getString(SettingKey.searchApiKey, ''),
    searxngUrl: s.getString(SettingKey.searxngUrl, ''),
    wakeWordEnabled: s.getBool(SettingKey.wakeWordEnabled, true),
    wakeWord: s.getString(SettingKey.wakeWord, 'hola astro'),
    wakeWordSensitivity: s.getDouble(SettingKey.wakeWordSensitivity, 0.5),
    navListenerEnabled: s.getBool(SettingKey.navListenerEnabled, true),
    autoBrightnessEnabled: s.getBool(SettingKey.autoBrightnessEnabled, true),
    hapticsEnabled: s.getBool(SettingKey.hapticsEnabled, true),
  );
}
