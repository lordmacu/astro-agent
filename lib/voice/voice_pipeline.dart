import '../brain/astro_brain.dart';
import 'voice_interfaces.dart';

/// Coarse voice phases the app maps to Astro's mood (thinking / answering) and
/// to the speaking animation.
enum VoicePhase { idle, listening, thinking, speaking }

/// Orchestrates one voice interaction end to end: capture the command, ask the
/// brain, speak the answer. The two-stage Alexa-like flow from pet.md §9 — wake
/// word gates [awaitWakeThenRun]; [runOnce] is the command→brain→voice core.
class VoicePipeline {
  VoicePipeline({
    required this.recognizer,
    required this.tts,
    required this.brain,
    required this.model,
    this.wakeWord,
    this.system,
    this.onPhase,
  });

  final SpeechRecognizer recognizer;
  final TextToSpeech tts;
  final AstroBrain brain;
  final String model;

  /// Optional wake-word gate. When set, [awaitWakeThenRun] waits for it.
  final WakeWordDetector? wakeWord;

  final String? system;
  final void Function(VoicePhase phase)? onPhase;

  /// Listen for one command, answer it, and speak the reply. Returns the
  /// answer, or null when nothing was understood.
  Future<String?> runOnce() async {
    _emit(VoicePhase.listening);
    final utterance = await recognizer.listen();
    if (utterance == null || utterance.trim().isEmpty) {
      _emit(VoicePhase.idle);
      return null;
    }

    _emit(VoicePhase.thinking);
    final answer = await brain.ask(utterance, model: model, system: system);

    _emit(VoicePhase.speaking);
    await tts.speak(answer);

    _emit(VoicePhase.idle);
    return answer;
  }

  /// Wait for the wake word, then run one interaction. Throws [StateError] if
  /// no [wakeWord] was provided.
  Future<String?> awaitWakeThenRun() async {
    final detector = wakeWord;
    if (detector == null) {
      throw StateError('awaitWakeThenRun needs a wakeWord detector');
    }
    await detector.onWake.first;
    return runOnce();
  }

  void _emit(VoicePhase phase) => onPhase?.call(phase);
}
