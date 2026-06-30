import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'oww_wake_word.dart';
import 'voice_interfaces.dart';

/// The active wake-word detector, and the single switch for it.
///
/// Default: the native **openWakeWord** engine (`OwwWakeWord`) — custom
/// "Oye Chispa" / "Chispa" models, always-on, low-power. The text-matching
/// `SttWakeWord` stays as a fallback for dev or devices without the models:
/// override this provider with `SttWakeWord()`.
///
/// App-scoped (not autoDispose): the detector is long-lived, like the
/// always-on foreground service it controls. Teardown stops it.
final wakeWordProvider = Provider<WakeWordDetector>((ref) {
  final detector = OwwWakeWord();
  ref.onDispose(detector.stop);
  return detector;
});
