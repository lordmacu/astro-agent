// lib/voice/neural_voice_provider.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/config/settings_providers.dart';
import '../core/config/thresholds.dart';
import 'neural_voice_installer.dart';

/// Model download URL: `.env` (TTS_MODEL_URL) overrides the built-in default.
String _modelUrl() {
  try {
    final v = dotenv.env['TTS_MODEL_URL'];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  } catch (_) {}
  return kDefaultNeuralVoiceUrl;
}

/// The installer, wired to app storage and to the settings that record a
/// finished install (installed flag + model path).
final neuralVoiceInstallerProvider = Provider<NeuralVoiceInstaller>((ref) {
  final settings = ref.read(settingsProvider.notifier);
  final installer = NeuralVoiceInstaller(
    client: http.Client(),
    modelUrl: _modelUrl(),
    modelName: kNeuralVoiceModelName,
    supportDir: getApplicationSupportDirectory,
    onInstalled: (path) async {
      await settings.setNeuralVoicePath(path);
      await settings.setNeuralVoiceInstalled(true);
    },
  );
  ref.onDispose(installer.dispose);
  return installer;
});

/// Live install progress for the Voz section to render.
final voiceInstallStateProvider = StreamProvider<VoiceInstallState>((ref) {
  return ref.watch(neuralVoiceInstallerProvider).state;
});
