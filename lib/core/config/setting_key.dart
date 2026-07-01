/// Every persisted setting, keyed by name in SharedPreferences. Using an enum
/// (instead of raw strings) keeps reads and writes typo-proof.
enum SettingKey {
  voiceRate,
  voicePitch,
  voiceLanguage,
  neuralVoiceEnabled,
  neuralVoiceInstalled,
  neuralVoicePath,
  llmModel,
  llmApiKey,
  searchApiKey,
  wakeWordEnabled,
  wakeWordSensitivity,
  navListenerEnabled,
  autoBrightnessEnabled,
}
