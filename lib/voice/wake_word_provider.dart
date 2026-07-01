import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'oww_wake_word.dart';
import 'voice_interfaces.dart';

/// The active wake-word detector, and the single switch for it.
///
/// Uses the native foreground service ([OwwWakeWord] talks to the Kotlin
/// `WakeWordService`). The service currently runs `SttEngine` — Android's
/// SpeechRecognizer in a loop — so it detects "Astro" in Spanish, always-on and
/// in the background, with a persistent notification. (The low-power openWakeWord
/// engine is parked in the same service until its model detects reliably.)
///
/// The pure-Dart `SttWakeWord` remains as a fallback for tests / devices without
/// the service.
///
/// App-scoped (not autoDispose): the detector is long-lived. Teardown stops it.
final wakeWordProvider = Provider<WakeWordDetector>((ref) {
  final detector = OwwWakeWord();
  ref.onDispose(detector.stop);
  return detector;
});
