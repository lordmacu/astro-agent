import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/settings_providers.dart';
import 'sherpa_tts.dart';
import 'system_tts.dart';
import 'voice_interfaces.dart';

/// The active text-to-speech engine. Neural (SherpaTts, offline Piper) when the
/// model is downloaded AND enabled; otherwise the lightweight system TTS. Any
/// missing piece falls back to system so voice never breaks.
final ttsProvider = Provider<TextToSpeech>((ref) {
  final s = ref.watch(settingsProvider);
  if (s.neuralVoiceInstalled &&
      s.neuralVoiceEnabled &&
      s.neuralVoicePath.isNotEmpty) {
    return SherpaTts(modelDir: s.neuralVoicePath, speed: s.voicePitch);
  }
  return SystemTts(rate: s.voiceRate);
});
