import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stt_recognizer.dart';
import 'voice_interfaces.dart';
import 'vosk_recognizer.dart';

/// The command recognizer used after the wake word fires. Captures one Spanish
/// utterance and returns the text. App-scoped and long-lived.
///
/// Prefers offline Vosk (continuous, no mid-sentence cutting); if its model
/// isn't bundled yet, Vosk transparently falls back to the platform
/// `speech_to_text`, so voice keeps working either way.
final speechRecognizerProvider = Provider<SpeechRecognizer>(
  (ref) => VoskSpeechRecognizer(fallback: SttSpeechRecognizer()),
);
