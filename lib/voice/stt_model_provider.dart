import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/config/settings_providers.dart';
import '../core/config/thresholds.dart';
import 'neural_voice_installer.dart';

/// STT model download URL: `.env` (STT_MODEL_URL) overrides the built-in
/// default (a GitHub Release asset).
String _sttModelUrl() {
  try {
    final v = dotenv.env['STT_MODEL_URL'];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  } catch (_) {}
  return kDefaultSttModelUrl;
}

/// Installer for the offline Vosk STT model. Reuses the generic zip installer
/// under the `stt/` subdir and records the unzipped path in settings; the Vosk
/// recognizer reads that path and switches over automatically.
final sttModelInstallerProvider = Provider<NeuralVoiceInstaller>((ref) {
  final settings = ref.read(settingsProvider.notifier);
  final installer = NeuralVoiceInstaller(
    client: http.Client(),
    modelUrl: _sttModelUrl(),
    modelName: kSttModelName,
    subdir: 'stt',
    supportDir: getApplicationSupportDirectory,
    onInstalled: (path) async => settings.setSttModelPath(path),
  );
  ref.onDispose(installer.dispose);
  return installer;
});

/// Live download progress for the STT model, for the pet screen banner.
final sttModelInstallStateProvider = StreamProvider<VoiceInstallState>((ref) {
  return ref.watch(sttModelInstallerProvider).state;
});
