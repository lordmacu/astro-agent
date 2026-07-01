import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'setting_key.dart';
import 'settings_providers.dart';
import 'settings_store.dart';

/// Holds AppSettings in memory and writes each edit through to the store. Every
/// setter persists first, then swaps state so widgets rebuild.
class SettingsNotifier extends Notifier<AppSettings> {
  SettingsStore get _store => ref.read(settingsStoreProvider);

  @override
  AppSettings build() => AppSettings.fromStore(_store);

  Future<void> setVoiceRate(double v) async {
    await _store.setDouble(SettingKey.voiceRate, v);
    state = state.copyWith(voiceRate: v);
  }

  Future<void> setVoicePitch(double v) async {
    await _store.setDouble(SettingKey.voicePitch, v);
    state = state.copyWith(voicePitch: v);
  }

  Future<void> setVoiceLanguage(String v) async {
    await _store.setString(SettingKey.voiceLanguage, v);
    state = state.copyWith(voiceLanguage: v);
  }

  Future<void> setNeuralVoiceEnabled(bool v) async {
    await _store.setBool(SettingKey.neuralVoiceEnabled, v);
    state = state.copyWith(neuralVoiceEnabled: v);
  }

  Future<void> setNeuralVoiceInstalled(bool v) async {
    await _store.setBool(SettingKey.neuralVoiceInstalled, v);
    state = state.copyWith(neuralVoiceInstalled: v);
  }

  Future<void> setNeuralVoicePath(String v) async {
    await _store.setString(SettingKey.neuralVoicePath, v);
    state = state.copyWith(neuralVoicePath: v);
  }

  Future<void> setLlmModel(String v) async {
    await _store.setString(SettingKey.llmModel, v);
    state = state.copyWith(llmModel: v);
  }

  Future<void> setLlmApiKey(String v) async {
    await _store.setString(SettingKey.llmApiKey, v);
    state = state.copyWith(llmApiKey: v);
  }

  Future<void> setSearchApiKey(String v) async {
    await _store.setString(SettingKey.searchApiKey, v);
    state = state.copyWith(searchApiKey: v);
  }

  Future<void> setWakeWordEnabled(bool v) async {
    await _store.setBool(SettingKey.wakeWordEnabled, v);
    state = state.copyWith(wakeWordEnabled: v);
  }

  Future<void> setWakeWordSensitivity(double v) async {
    await _store.setDouble(SettingKey.wakeWordSensitivity, v);
    state = state.copyWith(wakeWordSensitivity: v);
  }

  Future<void> setNavListenerEnabled(bool v) async {
    await _store.setBool(SettingKey.navListenerEnabled, v);
    state = state.copyWith(navListenerEnabled: v);
  }

  Future<void> setAutoBrightnessEnabled(bool v) async {
    await _store.setBool(SettingKey.autoBrightnessEnabled, v);
    state = state.copyWith(autoBrightnessEnabled: v);
  }
}
