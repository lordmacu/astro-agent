import 'package:flutter_tts/flutter_tts.dart';

import 'voice_interfaces.dart';

/// Simple TTS using the device's built-in engine via `flutter_tts`. Lightweight
/// (no model, no native onnxruntime), so builds stay fast. This is the stopgap
/// voice; the offline neural Piper voice (`SherpaTts`) replaces it later for
/// quality and full offline behaviour. `speak` completes when playback ends, so
/// the speaking animation lines up.
class SystemTts implements TextToSpeech {
  SystemTts({this.language = 'es-ES', this.rate = 0.5});

  final String language;
  final double rate;

  final FlutterTts _tts = FlutterTts();
  Future<void>? _ready;

  Future<void> _ensureReady() => _ready ??= () async {
        await _tts.awaitSpeakCompletion(true);
        await _tts.setLanguage(language);
        await _tts.setSpeechRate(rate);
      }();

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureReady();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}
