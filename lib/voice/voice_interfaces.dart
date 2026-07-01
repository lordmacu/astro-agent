/// Provider-agnostic voice contracts. Device plugins implement these; the rest
/// of the app and the tests only talk to the interfaces. Planned concrete
/// implementations (added later, with native setup and models):
///   - WakeWordDetector  → Porcupine (porcupine_flutter), local & low-power.
///   - SpeechRecognizer  → speech_to_text.
///   - TextToSpeech      → sherpa-onnx with an offline Piper Spanish voice
///                         (neural, on-device, no network — see pet.md §10).
library;

/// Always-on wake-word listener ("Oye Astro" / "Astro"). Fires an event each
/// time the wake word is heard. [pause]/[resume] silence the detector while
/// Astro speaks, so she doesn't hear herself.
abstract interface class WakeWordDetector {
  Stream<void> get onWake;
  Future<void> start();
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();

  /// Change the phrase to listen for (from Settings). Default is "hola astro";
  /// the user can set any word or phrase.
  Future<void> setKeyword(String keyword);

  /// Set detection sensitivity in [0,1] (from the Settings slider). Higher fires
  /// more easily; lower is stricter (fewer false wakes).
  Future<void> setSensitivity(double value);
}

/// Captures one spoken command and returns the recognized text.
abstract interface class SpeechRecognizer {
  /// Listen for a single utterance. Returns the text, or null if nothing was
  /// understood. [pauseFor] overrides how long a silence ends the utterance —
  /// use a generous value for a full command, a short one for a yes/no. Set
  /// [shortReply] for a brief yes/no answer (tuned recognition mode).
  Future<String?> listen({Duration? pauseFor, bool shortReply = false});
  Future<void> stop();

  /// Initialise ahead of time so the first capture is fast. Returns whether the
  /// recognizer is ready.
  Future<bool> warmUp();

  /// Called once when the mic goes live, so the UI can play a "speak now" cue.
  set onListening(void Function()? cb);
}

/// Speaks text aloud. The future completes when playback finishes, so callers
/// can run the speaking animation for exactly that span. Implemented offline by
/// a neural TTS (sherpa-onnx / Piper).
abstract interface class TextToSpeech {
  Future<void> speak(String text);
  Future<void> stop();
}
