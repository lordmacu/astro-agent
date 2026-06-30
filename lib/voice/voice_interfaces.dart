/// Provider-agnostic voice contracts. Device plugins implement these; the rest
/// of the app and the tests only talk to the interfaces. Planned concrete
/// implementations (added later, with native setup and models):
///   - WakeWordDetector  → Porcupine (porcupine_flutter), local & low-power.
///   - SpeechRecognizer  → speech_to_text.
///   - TextToSpeech      → sherpa-onnx with an offline Piper Spanish voice
///                         (neural, on-device, no network — see pet.md §10).
library;

/// Always-on wake-word listener ("Hey Chispa"). Fires an event each time the
/// wake word is heard.
abstract interface class WakeWordDetector {
  Stream<void> get onWake;
  Future<void> start();
  Future<void> stop();
}

/// Captures one spoken command and returns the recognized text.
abstract interface class SpeechRecognizer {
  /// Listen for a single utterance. Returns the text, or null if nothing was
  /// understood.
  Future<String?> listen();
  Future<void> stop();
}

/// Speaks text aloud. The future completes when playback finishes, so callers
/// can run the speaking animation for exactly that span. Implemented offline by
/// a neural TTS (sherpa-onnx / Piper).
abstract interface class TextToSpeech {
  Future<void> speak(String text);
  Future<void> stop();
}
