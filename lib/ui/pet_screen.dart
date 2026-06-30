import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/design_tokens.dart';
import '../core/state/app_state.dart';
import '../core/state/app_state_provider.dart';
import '../voice/stt_wake_word.dart';
import '../voice/tts_provider.dart';
import '../voice/voice_controller.dart';
import '../voice/voice_pipeline.dart';
import 'chispa_character.dart';
import 'hud.dart';

/// The full pet screen: ambient chip, speedometer, the velocity ring around the
/// animated Chispa, the speech line, and the event + proximity row. Chispa
/// reacts to the wake word "Chispa" (and to a tap) by speaking.
class PetScreen extends ConsumerStatefulWidget {
  const PetScreen({super.key});

  @override
  ConsumerState<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends ConsumerState<PetScreen> {
  static const _greeting = '¡Hola! Soy Chispa, tu copiloto. ¿Listo para rodar?';
  static const _wakeAck = '¡Aquí estoy! ¿Qué necesitas?';

  final SttWakeWord _wake = SttWakeWord();
  StreamSubscription<void>? _wakeSub;
  Timer? _visemeTimer;
  bool _speaking = false;
  String _spokenText = '';

  @override
  void initState() {
    super.initState();
    _wakeSub = _wake.onWake.listen((_) {
      if (!_speaking) _speak(_wakeAck);
    });
    _wake.start();
  }

  Future<void> _speak(String text) async {
    if (_speaking) return;
    setState(() {
      _speaking = true;
      _spokenText = text;
    });

    final controller = ref.read(voiceControllerProvider.notifier);
    final tts = ref.read(ttsProvider);

    await _wake.pause(); // don't let Chispa hear herself
    controller.applyPhase(VoicePhase.speaking);
    _visemeTimer = Timer.periodic(
      const Duration(milliseconds: 110),
      (_) => controller.tickViseme(),
    );

    try {
      await tts.speak(text);
    } finally {
      _visemeTimer?.cancel();
      controller.applyPhase(VoicePhase.idle);
      if (mounted) setState(() => _speaking = false);
      await _wake.resume();
    }
  }

  @override
  void dispose() {
    _visemeTimer?.cancel();
    _wakeSub?.cancel();
    _wake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = ref.watch(moodStateProvider);
    final voice = ref.watch(voiceControllerProvider);
    final appState = ref.watch(appStateProvider).valueOrNull ?? const AppState();

    final ambient = AmbientPalette.fromLux(appState.lux);
    final moodColor = DesignTokens.moodColor[mood.mood];
    final bodyColor = moodColor ?? ambient.body;
    final accent = moodColor ?? ambient.accent;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1),
            radius: 1.1,
            colors: [ambient.bgTop, ambient.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AmbientChip(ambient: ambient, lux: appState.lux),
                    const SizedBox(height: 16),
                    Speedometer(
                      speedKmh: appState.speedKmh.round(),
                      color: moodColor ?? DesignTokens.ink,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _speak(_greeting),
                      child: VelocityRing(
                        speedKmh: appState.speedKmh,
                        color: accent,
                        size: 260,
                        child: ChispaCharacter(
                          mood: mood,
                          color: bodyColor,
                          viseme: voice.viseme,
                          size: 200,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 26,
                      child: Text(
                        _speaking ? _spokenText : '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: DesignTokens.ink, fontSize: 17),
                      ),
                    ),
                    const SizedBox(height: 16),
                    EventRow(
                      event: eventLabel(mood.mood),
                      eventColor: accent,
                      near: appState.proximityNear,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _speaking ? '…' : 'Di «Chispa» o tócala 🎙️',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: DesignTokens.dim, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
