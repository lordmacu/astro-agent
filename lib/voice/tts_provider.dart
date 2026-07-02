import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/settings_providers.dart';
// import 'sherpa_tts.dart'; // PARKED — sherpa_onnx commented out in pubspec.
import 'system_tts.dart';
import 'voice_interfaces.dart';

/// The active text-to-speech engine — the lightweight system TTS.
///
/// The neural engine (SherpaTts, offline Piper) is PARKED to keep the APK small
/// (its onnxruntime libs add ~70MB per ABI). To restore it: un-park
/// `sherpa_tts.dart.off`, re-add the deps in pubspec, and uncomment the neural
/// branch below.
final ttsProvider = Provider<TextToSpeech>((ref) {
  final s = ref.watch(settingsProvider);
  // if (s.neuralVoiceInstalled &&
  //     s.neuralVoiceEnabled &&
  //     s.neuralVoicePath.isNotEmpty) {
  //   // Neural: speed is separate from pitch; use default speed (1.0).
  //   return SherpaTts(modelDir: s.neuralVoicePath);
  // }
  return SystemTts(
    rate: s.voiceRate,
    pitch: s.voicePitch,
    language: s.voiceLanguage == 'en' ? 'en-US' : 'es-ES',
  );
});
