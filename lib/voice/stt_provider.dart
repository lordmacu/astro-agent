import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/settings_providers.dart';
import 'stt_recognizer.dart';
import 'voice_interfaces.dart';
import 'vosk_recognizer.dart';

/// The command recognizer used after the wake word fires. Captures one Spanish
/// utterance and returns the text. App-scoped and long-lived.
///
/// Prefers offline Vosk (continuous, no mid-sentence cutting). The model is
/// downloaded on demand at app start (see stt_model_provider); until it lands,
/// Vosk transparently falls back to the platform `speech_to_text`, then switches
/// over automatically. The model path is read live from settings.
final speechRecognizerProvider = Provider<SpeechRecognizer>(
  (ref) => VoskSpeechRecognizer(
    fallback: SttSpeechRecognizer(),
    modelDir: () => ref.read(settingsProvider).sttModelPath,
  ),
);
