import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../brain/astro_brain_provider.dart';
import '../brain/tools/astro_tool.dart';
import '../core/config/design_tokens.dart';
import '../core/state/app_mode.dart';
import '../core/state/app_state.dart';
import '../core/state/app_state_provider.dart';
import '../voice/stt_provider.dart';
import '../voice/stt_recognizer.dart';
import '../voice/voice_interfaces.dart';
import '../voice/wake_word_provider.dart';
import '../voice/tts_provider.dart';
import '../voice/voice_controller.dart';
import '../voice/voice_pipeline.dart';
import 'astro_character.dart';
import 'hud.dart';
import 'settings/settings_screen.dart';

/// The full pet screen: ambient chip, speedometer, the velocity ring around the
/// animated Astro, the speech line, and the event + proximity row. Astro
/// reacts to the wake word "Astro" (and to a tap) by speaking.
class PetScreen extends ConsumerStatefulWidget {
  const PetScreen({super.key});

  @override
  ConsumerState<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends ConsumerState<PetScreen> {
  static const _greeting = '¡Hola! Soy Astro, tu copiloto. ¿Listo para rodar?';
  static const _wakeAck = '¡Aquí estoy! ¿Qué necesitas?';
  static const _notHeard = '¿Me repites? No te escuché bien.';
  static const _oops = 'Uy, se me enredó la conexión. ¿Probamos otra vez?';

  late final WakeWordDetector _wake = ref.read(wakeWordProvider);
  StreamSubscription<void>? _wakeSub;
  Timer? _visemeTimer;
  bool _busy = false;
  String _spokenText = '';

  /// When a mutating tool asks for confirmation: the question to show, and the
  /// pending answer (resolved by voice or by a tap on the SÍ/NO buttons).
  String? _confirmPrompt;
  Completer<bool>? _confirmCompleter;

  @override
  void initState() {
    super.initState();
    // Let the brain ask us to confirm mutating tools (e.g. calls) by voice.
    ref.read(toolConfirmerProvider).confirmer = _confirmTool;
    // Warm up speech recognition so the first listen doesn't miss the first
    // word, and beep the moment the mic is live so the driver knows to speak.
    final recognizer = ref.read(speechRecognizerProvider);
    if (recognizer is SttSpeechRecognizer) {
      unawaited(recognizer.warmUp());
      recognizer.onListening = () => ref.read(mediaControllerProvider).beep();
    }
    _wakeSub = _wake.onWake.listen((_) {
      if (!_busy) _converse();
    });
    _wake.start();
  }

  /// Confirmation for a mutating tool. Shows SÍ/NO buttons AND listens for a
  /// spoken yes/no — whichever comes first wins. The buttons make it reliable
  /// even when the mic misses a short "sí" right after Astro speaks. Times out
  /// to "no" if the driver does nothing.
  Future<bool> _confirmTool(AstroTool tool, Map<String, dynamic> args) async {
    final controller = ref.read(voiceControllerProvider.notifier);
    final question = _confirmQuestion(tool, args);
    final completer = Completer<bool>();
    _confirmCompleter = completer;
    if (mounted) setState(() => _confirmPrompt = question);

    // Safety net: never hang waiting for an answer.
    final timeout = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    unawaited(_voiceConfirm(question, controller, completer));

    final result = await completer.future;
    timeout.cancel();
    _confirmCompleter = null;
    if (mounted) setState(() => _confirmPrompt = null);
    controller.applyPhase(VoicePhase.thinking);
    return result;
  }

  /// Speak the question and listen for a spoken yes/no (short-reply mode), up to
  /// two tries. Bails out the moment a button tap resolves [completer].
  Future<void> _voiceConfirm(
    String question,
    VoiceController controller,
    Completer<bool> completer,
  ) async {
    for (var attempt = 0; attempt < 2 && !completer.isCompleted; attempt++) {
      await _say(attempt == 0 ? question : '¿Sí o no?', controller);
      if (completer.isCompleted) return; // tapped while speaking

      controller.applyPhase(VoicePhase.listening);
      // Let the audio settle after the TTS so the mic isn't clipped.
      await Future<void>.delayed(const Duration(milliseconds: 650));
      // Generous silence window: after the beep you need a beat to react and
      // say "sí" — a short window would close before you speak.
      final reply = await ref
          .read(speechRecognizerProvider)
          .listen(pauseFor: const Duration(seconds: 2), shortReply: true);
      debugPrint('[Astro] ✅ confirm reply: ${reply ?? '(nothing)'}');
      if (completer.isCompleted) return;
      if (reply != null && reply.trim().isNotEmpty) {
        if (!completer.isCompleted) completer.complete(_isAffirmative(reply));
        return;
      }
    }
    if (!completer.isCompleted) await _say('Toca sí o no.', controller);
  }

  String _confirmQuestion(AstroTool tool, Map<String, dynamic> args) {
    if (tool.name == 'phone') {
      final contact = (args['contact'] as String?)?.trim() ?? 'ese contacto';
      final action = (args['action'] as String?)?.trim().toLowerCase();
      return action == 'message'
          ? '¿Le mando el mensaje a $contact?'
          : '¿Llamo a $contact?';
    }
    return '¿Lo hago?';
  }

  bool _isAffirmative(String reply) {
    final r = reply.toLowerCase();
    const yes = [
      'si',
      'sí',
      'dale',
      'hazlo',
      'hágale',
      'hagale',
      'claro',
      'ok',
      'okey',
      'listo',
      'bueno',
      'adelante',
      'de una',
      'obvio',
      'correcto',
      'afirmativo',
      'afirmo',
      'hágalo',
      'hagalo',
      'llama',
      'llamar',
    ];
    return yes.any(r.contains);
  }

  /// A back-and-forth after the wake word: pause the wake mic, then loop —
  /// capture a command, answer it (with memory of the exchange), and if Astro
  /// asked something back, keep the mic open for the reply. Ends on silence or
  /// when Astro didn't ask anything.
  Future<void> _converse() async {
    if (_busy) return;
    _busy = true;
    final controller = ref.read(voiceControllerProvider.notifier);
    await _wake.pause(); // free the mic + don't let Astro hear herself

    try {
      for (var turn = 0; turn < 6; turn++) {
        controller.applyPhase(VoicePhase.listening);
        if (mounted) setState(() => _spokenText = '');

        // Let the mic free up so the first word isn't clipped. Follow-up turns
        // come right after Astro speaks, so give the audio longer to settle.
        await Future<void>.delayed(
          Duration(milliseconds: turn == 0 ? 300 : 650),
        );
        final capSw = Stopwatch()..start();
        final command = await ref.read(speechRecognizerProvider).listen();
        debugPrint(
          '[Astro] 🎙️ heard (${capSw.elapsedMilliseconds}ms): '
          '${command ?? '(nothing)'}',
        );
        if (command == null || command.isEmpty) {
          if (turn == 0) await _say(_notHeard, controller);
          break; // silence ends the conversation
        }

        final answer = await _answerStreaming(command, controller);
        if (!_invitesReply(answer)) break; // Astro didn't ask anything back
      }
    } finally {
      controller.applyPhase(VoicePhase.idle);
      if (mounted) setState(() => _spokenText = '');
      _busy = false;
      await _wake.resume();
    }
  }

  /// True when Astro's answer ends with a question, i.e. it expects a reply.
  bool _invitesReply(String answer) {
    final a = answer.trimRight();
    return a.endsWith('?');
  }

  /// Stream the answer: speak each sentence as soon as it is generated, instead
  /// of waiting for the whole reply. Falls back to a canned line when there's no
  /// API key or the request fails.
  Future<String> _answerStreaming(
    String command,
    VoiceController controller,
  ) async {
    if (!ref.read(astroConfiguredProvider)) {
      await _say(_wakeAck, controller);
      return _wakeAck;
    }
    controller.applyPhase(VoicePhase.thinking);

    var started = false;
    Future<void> ttsChain = Future.value();

    void ensureSpeaking() {
      if (started) return;
      started = true;
      controller.applyPhase(VoicePhase.speaking);
      _visemeTimer = Timer.periodic(
        const Duration(milliseconds: 110),
        (_) => controller.tickViseme(),
      );
    }

    try {
      final brain = await ref.read(astroBrainProvider.future);
      final answer = await brain.askStream(
        command,
        model: ref.read(astroModelProvider),
        system: astroSystemPromptFor(ref.read(appModeProvider)),
        onSentence: (sentence) {
          // Queue each sentence so they play in order, one after another.
          ttsChain = ttsChain.then((_) async {
            ensureSpeaking();
            if (mounted) setState(() => _spokenText = sentence);
            await ref.read(ttsProvider).speak(sentence);
          });
        },
      );
      await ttsChain; // let all queued speech finish
      return answer;
    } catch (e) {
      await ttsChain;
      debugPrint('[Astro] brain error: $e');
      if (!started) await _say(_oops, controller);
      return '';
    } finally {
      _visemeTimer?.cancel();
    }
  }

  /// Speak [text] with the mouth animation. Assumes the wake mic is already
  /// paused (the caller manages pause/resume around the whole turn).
  Future<void> _say(String text, VoiceController controller) async {
    if (mounted) setState(() => _spokenText = text);
    controller.applyPhase(VoicePhase.speaking);
    _visemeTimer = Timer.periodic(
      const Duration(milliseconds: 110),
      (_) => controller.tickViseme(),
    );
    final ttsSw = Stopwatch()..start();
    try {
      await ref.read(ttsProvider).speak(text);
    } finally {
      _visemeTimer?.cancel();
      debugPrint('[Astro] 🔊 spoke in ${ttsSw.elapsedMilliseconds}ms');
    }
  }

  /// Open the settings screen, pausing the wake detector while the user edits
  /// and resuming it when they return.
  Future<void> _openSettings() async {
    final nav = Navigator.of(context);
    await _wake.pause();
    try {
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );
    } finally {
      await _wake.resume();
    }
  }

  /// One-shot line with no listening (the tap greeting). Manages the wake mic.
  Future<void> _speakStandalone(String text) async {
    if (_busy) return;
    _busy = true;
    final controller = ref.read(voiceControllerProvider.notifier);
    await _wake.pause();
    try {
      await _say(text, controller);
    } finally {
      controller.applyPhase(VoicePhase.idle);
      if (mounted) setState(() => _spokenText = '');
      _busy = false;
      await _wake.resume();
    }
  }

  @override
  void dispose() {
    _visemeTimer?.cancel();
    _wakeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = ref.watch(moodStateProvider);
    final voice = ref.watch(voiceControllerProvider);
    final appState =
        ref.watch(appStateProvider).valueOrNull ?? const AppState();

    final ambient = AmbientPalette.fromLux(appState.lux);
    final moodColor = DesignTokens.moodColor[mood.mood];
    final bodyColor = moodColor ?? ambient.body;
    final accent = moodColor ?? ambient.accent;
    final carMode = ref.watch(appModeProvider).isCar;
    final character = AstroCharacter(
      mood: mood,
      color: bodyColor,
      viseme: voice.viseme,
      size: 200,
    );

    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                        // Speed readout + ring only in car mode.
                        if (carMode) ...[
                          Speedometer(
                            speedKmh: appState.speedKmh.round(),
                            color: moodColor ?? DesignTokens.ink,
                          ),
                          const SizedBox(height: 16),
                        ],
                        GestureDetector(
                          onTap: () => _speakStandalone(_greeting),
                          child: carMode
                              ? VelocityRing(
                                  speedKmh: appState.speedKmh,
                                  color: accent,
                                  size: 260,
                                  child: character,
                                )
                              // Same 260 box (no ring) so the layout doesn't jump.
                              : SizedBox(
                                  width: 260,
                                  height: 260,
                                  child: Center(child: character),
                                ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 26,
                          child: Text(
                            _spokenText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: DesignTokens.ink,
                              fontSize: 17,
                            ),
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
                          switch (voice.phase) {
                            VoicePhase.listening => 'Escuchando…',
                            VoicePhase.thinking => 'Pensando…',
                            VoicePhase.speaking => '…',
                            VoicePhase.idle => 'Di «Astro» o tócala 🎙️',
                          },
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: DesignTokens.dim,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Top-left text switch: car mode vs normal mode.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: ModeSwitch(
                  carMode: carMode,
                  onSelect: (car) => ref
                      .read(appModeProvider.notifier)
                      .set(car ? AppMode.car : AppMode.normal),
                ),
              ),
            ),
          ),
          // Top-right gear icon: opens the settings screen.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: IconButton(
                  icon: const Icon(Icons.settings),
                  color: accent,
                  onPressed: _openSettings,
                ),
              ),
            ),
          ),
          if (_confirmPrompt != null) _confirmOverlay(accent),
        ],
      ),
    );
  }

  /// Full-screen confirmation: the question plus big SÍ / NO buttons that
  /// resolve the pending confirmation immediately.
  Widget _confirmOverlay(Color accent) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.66),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _confirmPrompt ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DesignTokens.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _confirmButton('Sí', true, accent)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _confirmButton('No', false, DesignTokens.dim),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _confirmButton(String label, bool value, Color color) {
    return GestureDetector(
      onTap: () {
        if (_confirmCompleter?.isCompleted == false) {
          _confirmCompleter!.complete(value);
        }
      },
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
