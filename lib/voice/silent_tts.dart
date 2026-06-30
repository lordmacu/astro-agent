import 'package:flutter/foundation.dart' show debugPrint;

import 'voice_interfaces.dart';

/// No-op TTS used while voice is disabled for fast dev builds. It logs the text
/// instead of playing audio; the speech bubble still shows it (text, no voice).
/// Swap it for `SherpaTts` to get the real offline neural voice back.
class SilentTts implements TextToSpeech {
  @override
  Future<void> speak(String text) async {
    debugPrint('SilentTts (voice disabled): "$text"');
  }

  @override
  Future<void> stop() async {}
}
