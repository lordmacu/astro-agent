import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'system_tts.dart';
import 'voice_interfaces.dart';

/// The active text-to-speech engine, and the single switch for voice.
///
/// Currently the **simple system TTS** (`flutter_tts`): lightweight, gives audio
/// now, keeps builds fast. The offline **neural** voice (sherpa-onnx + Piper)
/// is the planned upgrade for quality and full offline behaviour.
///
/// To switch to the NEURAL voice later:
///   1. pubspec.yaml: uncomment `sherpa_onnx`, `audioplayers`, `archive`,
///      `path_provider`, and the `assets/tts/...zip` asset; run `flutter pub get`.
///   2. Rename `lib/voice/sherpa_tts.dart.off` → `sherpa_tts.dart`.
///   3. Here: return `SherpaTts()` and call `warmUp()` from PetScreen.initState.
final ttsProvider = Provider<TextToSpeech>((ref) => SystemTts());
