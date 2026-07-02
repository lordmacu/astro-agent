import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../brain/astro_brain_provider.dart';
import '../brain/tools/astro_tool.dart';
import '../core/config/design_tokens.dart';
import '../core/config/settings_providers.dart';
import '../core/l10n/app_lang.dart';
import '../core/l10n/lang_provider.dart';
import '../core/l10n/strings.dart';
import '../core/state/app_mode.dart';
import '../core/state/app_state.dart';
import '../core/state/app_state_provider.dart';
import '../platform/calendar_writer.dart';
import '../platform/contact_match.dart';
import '../platform/haptics.dart';
import '../platform/system_actions.dart';
import '../voice/neural_voice_installer.dart'
    show InstallError, Installing, VoiceInstallState;
import '../voice/stt_model_provider.dart';
import '../voice/stt_provider.dart';
import '../voice/voice_interfaces.dart';
import '../voice/wake_word_provider.dart';
// import '../voice/sherpa_tts.dart'; // PARKED — neural TTS disabled to slim the APK
import '../voice/tts_provider.dart';
import '../voice/voice_controller.dart';
import '../voice/voice_pipeline.dart';
import 'ai_setup_sheet.dart';
import 'astro_character.dart';
import 'command_palette.dart';
import 'hud.dart';
import 'photo_viewer_screen.dart';
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
  /// The language Astro speaks/writes right now (device locale or user override).
  AppLang get _lang => ref.read(langProvider);

  /// Haptic feedback for taps and confirmations (no-op when disabled).
  Haptics get _haptics => ref.read(hapticsProvider);

  String get _notHeard => Strings.notHeard(_lang);
  String get _oops => Strings.oops(_lang);

  late final WakeWordDetector _wake = ref.read(wakeWordProvider);
  StreamSubscription<void>? _wakeSub;
  Timer? _visemeTimer;

  /// Repeating "thinking" haptic pulse (a heartbeat) and its beat counter.
  /// Runs only while the voice phase is `thinking`.
  Timer? _thinkHapticTimer;
  int _thinkHapticStep = 0;

  /// The gap before each beat, cycling short→long so the pulse feels like a
  /// "da-dum" heartbeat rather than an even tick.
  static const _thinkHapticGaps = [
    Duration(milliseconds: 160),
    Duration(milliseconds: 620),
  ];
  bool _busy = false;
  bool _cancelRequested = false; // tap-to-cancel while listening
  String _spokenText = '';
  bool _showCommands = false;

  /// When a mutating tool asks for confirmation: the question to show, and the
  /// pending answer (resolved by voice or by a tap on the SÍ/NO buttons).
  String? _confirmPrompt;
  Completer<bool>? _confirmCompleter;

  /// When a spoken name matches several contacts: the choices to show, and the
  /// pending pick (resolved by tapping a contact).
  List<ContactCandidate>? _pickContacts;
  Completer<ContactCandidate?>? _pickCompleter;

  /// The first time Astro creates a calendar event: the calendars to choose
  /// from, and the pending pick (resolved by tapping one). Remembered after.
  List<CalendarOption>? _calendarOptions;
  Completer<CalendarOption?>? _calendarCompleter;

  /// Before sending an email: the draft args to review/edit in a popup, and the
  /// pending send/cancel. Editing writes the corrected values back into args.
  Map<String, dynamic>? _emailArgs;
  Completer<bool>? _emailCompleter;

  /// When a spoken recipient matches several contact emails: the choices to show
  /// and the pending pick (resolved by tapping one). Used to prefill the "to".
  List<EmailCandidate>? _emailPickOptions;
  Completer<EmailCandidate?>? _emailPickCompleter;

  /// For calls/messages: the fixed line Astro should say with the REAL contact
  /// name, spoken by the app instead of the model's paraphrase (which mangles
  /// the name). Set during confirmation, consumed by [_answerStreaming].
  String? _overrideAnswer;

  @override
  void initState() {
    super.initState();
    // Let the brain ask us to confirm mutating tools (e.g. calls) by voice.
    ref.read(toolConfirmerProvider).confirmer = _confirmTool;
    // Let the brain ask the user to pick a calendar the first time.
    ref.read(calendarChooserProvider).choose = _pickCalendar;
    // Warm up speech recognition so the first listen doesn't miss the first
    // word, and beep the moment the mic is live so the driver knows to speak.
    final recognizer = ref.read(speechRecognizerProvider);
    unawaited(recognizer.warmUp());
    recognizer.onListening = () => ref.read(mediaControllerProvider).beep();
    // Neural TTS is parked; the system TTS needs no warm-up.
    // final tts = ref.read(ttsProvider);
    // if (tts is SherpaTts) unawaited(tts.warmUp());
    _wakeSub = _wake.onWake.listen((_) {
      if (!_busy) _converse();
    });
    final settings = ref.read(settingsProvider);
    // Tell the native engine which phrase to listen for (default "hola astro",
    // user-configurable in Settings) and how sensitive to be, before it starts.
    unawaited(_wake.setKeyword(settings.wakeWord));
    unawaited(_wake.setSensitivity(settings.wakeWordSensitivity));
    if (settings.wakeWordEnabled) {
      _wake.start();
    }
    // Download the offline STT model on start if it's missing OR its files are
    // gone (a stale saved path — otherwise Vosk would fail forever with no
    // re-download). Meanwhile the platform recognizer handles commands; Vosk
    // takes over automatically once the model lands.
    final sttPath = settings.sttModelPath;
    final sttReady = sttPath.isNotEmpty && File('$sttPath/.ready').existsSync();
    if (!sttReady) {
      if (sttPath.isNotEmpty) {
        unawaited(ref.read(settingsProvider.notifier).setSttModelPath(''));
      }
      unawaited(ref.read(sttModelInstallerProvider).install());
    }
  }

  /// Confirmation gate for a mutating tool. Phone gets a contact-aware flow;
  /// everything else gets a plain yes/no.
  Future<bool> _confirmTool(AstroTool tool, Map<String, dynamic> args) async {
    if (tool.name == 'phone') return _confirmPhone(args);
    // Only the send-email action of `comunicacion` reaches here (it's the only
    // one that requests confirmation).
    if (tool.name == 'comunicacion') return _confirmEmail(args);
    return _confirmYesNo(_confirmQuestion(tool, args));
  }

  /// Show the email draft (what Astro understood) in an editable popup. The user
  /// fixes the recipient / subject / body and taps Enviar; the corrected values
  /// are written back into [args] so the tool sends exactly what's on screen.
  Future<bool> _confirmEmail(Map<String, dynamic> args) async {
    final controller = ref.read(voiceControllerProvider.notifier);

    // The recognizer often mangles a spoken address. If what we heard resembles
    // a saved contact, prefill the form with that contact's real email so the
    // driver doesn't have to fix it by hand.
    final heard = (args['to'] as String?)?.trim() ?? '';
    if (heard.isNotEmpty) {
      final matches = await const SystemActions().matchingContactEmails(heard);
      if (matches.length == 1) {
        args['to'] = matches.first.email;
      } else if (matches.length > 1) {
        final chosen = await _pickEmail(matches);
        if (chosen != null) args['to'] = chosen.email;
      }
    }

    final completer = Completer<bool>();
    _emailCompleter = completer;
    if (mounted) setState(() => _emailArgs = args);
    await _say(Strings.reviewEmailSpoken(_lang), controller);

    final ok = await completer.future;
    _emailCompleter = null;
    if (mounted) setState(() => _emailArgs = null);
    controller.applyPhase(VoicePhase.thinking);
    return ok;
  }

  /// Phone confirmation with fuzzy contact resolution:
  ///  - 0 matches → say it wasn't found, deny.
  ///  - 1 match  → confirm the REAL contact name (yes/no).
  ///  - 2+ match → show a picker; tapping a contact confirms it.
  /// On confirm/pick, the resolved number is written back into [args] so the
  /// tool dials the right person, not the misheard name.
  Future<bool> _confirmPhone(Map<String, dynamic> args) async {
    final controller = ref.read(voiceControllerProvider.notifier);
    final spoken = (args['contact'] as String?)?.trim() ?? '';
    final isMessage =
        (args['action'] as String?)?.trim().toLowerCase() == 'message';

    // Already a raw number → confirm as spoken, no lookup.
    if (RegExp(r'^[+0-9][0-9\s\-()]{4,}$').hasMatch(spoken)) {
      final ok = await _confirmYesNo(
        isMessage
            ? Strings.confirmMessage(spoken, _lang)
            : Strings.confirmCall(spoken, _lang),
      );
      if (ok) _setPhoneOverride(spoken, isMessage);
      return ok;
    }

    final matches = await const SystemActions().matchingContacts(spoken);
    if (matches.isEmpty) {
      await _say(Strings.contactNotFound(spoken, _lang), controller);
      return false;
    }
    if (matches.length == 1) {
      _applyContact(args, matches.first);
      final ok = await _confirmYesNo(
        isMessage
            ? Strings.confirmWrite(matches.first.name, _lang)
            : Strings.confirmCall(matches.first.name, _lang),
      );
      if (ok) _setPhoneOverride(matches.first.name, isMessage);
      return ok;
    }

    // Several close matches → let the driver tap the right one.
    final chosen = await _pickContact(matches, isMessage);
    if (chosen == null) return false;
    _applyContact(args, chosen);
    _setPhoneOverride(chosen.name, isMessage);
    return true;
  }

  /// The exact line the app will speak after the call/message goes out, using
  /// the real contact name (bypasses the model's name-mangling paraphrase).
  void _setPhoneOverride(String name, bool isMessage) {
    _overrideAnswer = isMessage
        ? Strings.messageLeft(name, _lang)
        : Strings.callingNow(name, _lang);
  }

  /// Write the resolved contact back into the tool args: the exact number to
  /// dial, plus the real contact name so Astro reports the right person.
  void _applyContact(Map<String, dynamic> args, ContactCandidate c) {
    args['number'] = c.number;
    args['contact'] = c.name;
  }

  /// Show SÍ/NO buttons AND listen for a spoken yes/no — whichever comes first
  /// wins. The buttons make it reliable even when the mic misses a short "sí"
  /// right after Astro speaks. Times out to "no" if the driver does nothing.
  Future<bool> _confirmYesNo(String question) async {
    final controller = ref.read(voiceControllerProvider.notifier);
    final completer = Completer<bool>();
    _confirmCompleter = completer;
    if (mounted) setState(() => _confirmPrompt = question);

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

  /// Show a contact picker; tapping a contact resolves the pick. Returns null on
  /// timeout / dismissal.
  Future<ContactCandidate?> _pickContact(
    List<ContactCandidate> contacts,
    bool isMessage,
  ) async {
    final controller = ref.read(voiceControllerProvider.notifier);
    final completer = Completer<ContactCandidate?>();
    _pickCompleter = completer;
    if (mounted) setState(() => _pickContacts = contacts);

    final timeout = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    await _say(
      isMessage ? Strings.whoToMessage(_lang) : Strings.whoToCall(_lang),
      controller,
    );

    final chosen = await completer.future;
    timeout.cancel();
    _pickCompleter = null;
    if (mounted) setState(() => _pickContacts = null);
    controller.applyPhase(VoicePhase.thinking);
    return chosen;
  }

  /// Show the email-recipient picker (several contacts/addresses matched what
  /// was heard) and resolve on tap. Returns null on cancel / timeout, leaving
  /// the recipient as the model gave it.
  Future<EmailCandidate?> _pickEmail(List<EmailCandidate> options) async {
    final controller = ref.read(voiceControllerProvider.notifier);
    final completer = Completer<EmailCandidate?>();
    _emailPickCompleter = completer;
    if (mounted) setState(() => _emailPickOptions = options);

    final timeout = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    await _say(Strings.whichEmailSpoken(_lang), controller);

    final chosen = await completer.future;
    timeout.cancel();
    _emailPickCompleter = null;
    if (mounted) setState(() => _emailPickOptions = null);
    controller.applyPhase(VoicePhase.thinking);
    return chosen;
  }

  /// Show the calendar picker (first event only) and resolve on tap. Speaks a
  /// short prompt. Returns null on cancel / timeout (→ primary calendar).
  Future<CalendarOption?> _pickCalendar(List<CalendarOption> options) async {
    final controller = ref.read(voiceControllerProvider.notifier);
    final completer = Completer<CalendarOption?>();
    _calendarCompleter = completer;
    if (mounted) setState(() => _calendarOptions = options);

    final timeout = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    await _say(Strings.whichCalendarSpoken(_lang), controller);

    final chosen = await completer.future;
    timeout.cancel();
    _calendarCompleter = null;
    if (mounted) setState(() => _calendarOptions = null);
    controller.applyPhase(VoicePhase.thinking);
    return chosen;
  }

  /// Speak the question and listen for a spoken yes/no (short-reply mode), up to
  /// two tries. Bails out the moment a button tap resolves [completer].
  Future<void> _voiceConfirm(
    String question,
    VoiceController controller,
    Completer<bool> completer,
  ) async {
    for (var attempt = 0; attempt < 2 && !completer.isCompleted; attempt++) {
      await _say(attempt == 0 ? question : Strings.yesOrNo(_lang), controller);
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
    if (!completer.isCompleted) {
      await _say(Strings.tapYesOrNo(_lang), controller);
    }
  }

  /// Question for a generic mutating tool (phone has its own contact-aware flow).
  String _confirmQuestion(AstroTool tool, Map<String, dynamic> args) =>
      Strings.doIt(_lang);

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
      // English
      'yes',
      'yeah',
      'yep',
      'yup',
      'sure',
      'do it',
      'go ahead',
      'okay',
      'sounds good',
      'affirmative',
      'call',
      'send',
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
    _cancelRequested = false;
    // A firm buzz the moment Astro is summoned (by tap or wake word).
    _haptics.listenStart();
    final controller = ref.read(voiceControllerProvider.notifier);
    await _wake.pause(); // free the mic + don't let Astro hear herself

    // Startle reaction on being summoned, a beat before it starts listening.
    controller.surprise();
    await Future<void>.delayed(const Duration(milliseconds: 650));

    // Collected across the turns of this one conversation, then handed to the
    // background memory extractor once it ends.
    final exchanges = <String>[];

    try {
      for (var turn = 0; turn < 6; turn++) {
        controller.applyPhase(VoicePhase.listening);
        if (mounted) setState(() => _spokenText = '');

        // Let the mic free up so the first word isn't clipped. Follow-up turns
        // come right after Astro speaks, so give the audio longer to settle.
        await Future<void>.delayed(
          Duration(milliseconds: turn == 0 ? 300 : 650),
        );
        if (_cancelRequested) break; // tapped to cancel before listening
        final capSw = Stopwatch()..start();
        final command = await ref.read(speechRecognizerProvider).listen();
        if (_cancelRequested) break; // tapped to cancel — end quietly
        debugPrint(
          '[Astro] 🎙️ heard (${capSw.elapsedMilliseconds}ms): '
          '${command ?? '(nothing)'}',
        );
        if (command == null || command.isEmpty) {
          if (turn == 0) await _say(_notHeard, controller);
          break; // silence ends the conversation
        }

        final answer = await _answerStreaming(command, controller);
        exchanges.add('Conductor: $command');
        if (answer.trim().isNotEmpty) exchanges.add('Astro: $answer');
        if (!_invitesReply(answer)) break; // Astro didn't ask anything back
      }
    } finally {
      controller.applyPhase(VoicePhase.idle);
      if (mounted) setState(() => _spokenText = '');
      _busy = false;
      await _wake.resume();
      // Learn from the conversation in the background (never blocks the mic).
      unawaited(_extractMemories(exchanges));
    }
  }

  /// Run a fixed text command (from the command palette) through the same brain
  /// path as a spoken one: pause the wake mic, answer + speak, then resume.
  Future<void> _runCommand(String command) async {
    if (_busy) return;
    _busy = true;
    final controller = ref.read(voiceControllerProvider.notifier);
    await _wake.pause();
    try {
      await _answerStreaming(command, controller);
    } finally {
      controller.applyPhase(VoicePhase.idle);
      if (mounted) setState(() => _spokenText = '');
      _busy = false;
      await _wake.resume();
    }
  }

  /// After a conversation, harvest durable facts in the background so Astro
  /// learns over time (preferences, names, routes) without the driver saying
  /// "remember this". Skips trivial turns (a handful of words) to avoid needless
  /// LLM calls; the extractor itself also saves nothing when there's nothing
  /// worth keeping, and dedupes against recent memories.
  Future<void> _extractMemories(List<String> exchanges) async {
    if (exchanges.isEmpty) return;
    final driverWords = exchanges
        .where((e) => e.startsWith('Conductor: '))
        .map((e) => e.substring('Conductor: '.length))
        .join(' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (driverWords < 4) return; // one-word commands / yes-no → nothing durable

    try {
      final extractor = await ref.read(memoryExtractorProvider.future);
      if (extractor == null) return;
      final recent = await extractor.memory.recent(limit: 20);
      final existing = recent.map((m) => m.content).join('\n');
      final stored = await extractor.extractAndStore(
        exchanges.join('\n'),
        existing: existing,
      );
      if (stored.isNotEmpty) {
        debugPrint('[Astro] 🧠 learned ${stored.length} memory(ies)');
        // Refresh the Settings counter live (harmless if that screen is closed).
        if (mounted) ref.invalidate(memoryCountProvider);
      }
    } catch (e) {
      debugPrint('[Astro] memory extraction failed: $e');
    }
  }

  /// Tap while a conversation is in progress cancels the current listen: only
  /// while actually listening (not mid-answer). Stopping the recognizer unblocks
  /// the pending `listen()`, and the flag makes the loop end quietly.
  void _cancelListening() {
    if (ref.read(voiceControllerProvider).phase != VoicePhase.listening) return;
    _cancelRequested = true;
    ref.read(speechRecognizerProvider).stop();
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
      // No LLM key yet: tell the driver and open the inline setup. If they
      // configure it, fall through and answer the original command; otherwise
      // stay quiet.
      await _say(Strings.aiSetupSpoken(_lang), controller);
      if (!mounted) return '';
      final configured = await showAiSetupSheet(context);
      if (!configured || !ref.read(astroConfiguredProvider)) return '';
    }
    controller.applyPhase(VoicePhase.thinking);
    _overrideAnswer = null; // reset; a phone confirm may set it mid-turn

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
        system: astroSystemPromptFor(
          ref.read(appModeProvider),
          ref.read(langProvider),
        ),
        onSentence: (sentence) {
          // Suppress the model's own words when we'll speak a fixed line (e.g.
          // a call, where the model tends to mangle the contact name).
          if (_overrideAnswer != null) return;
          // Queue each sentence so they play in order, one after another.
          ttsChain = ttsChain.then((_) async {
            ensureSpeaking();
            if (mounted) setState(() => _spokenText = sentence);
            await ref.read(ttsProvider).speak(sentence);
          });
        },
      );
      await ttsChain; // let all queued speech finish

      // A call/message went out → say the app's line with the real name.
      final override = _overrideAnswer;
      if (override != null) {
        _overrideAnswer = null;
        _visemeTimer?.cancel();
        await _say(override, controller);
        return override;
      }
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

  /// Slim top banner for the offline STT model. While [state] is `Installing`
  /// it shows download progress; on `InstallError` it shows a short message and
  /// a Retry button. On success the banner isn't built, so it disappears the
  /// moment the download completes. Non-blocking throughout: Astro stays usable
  /// with the platform recognizer and switches to Vosk on its own once ready.
  Widget _sttBanner(AppLang lang, Color accent, VoiceInstallState state) {
    final failed = state is InstallError;
    final progress = state is Installing ? state.progress : -1.0;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 44, left: 16, right: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  failed
                      ? Strings.voiceModelFailed(lang)
                      : Strings.downloadingVoiceModel(lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DesignTokens.ink, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (failed)
                  TextButton(
                    onPressed: () {
                      _haptics.select();
                      unawaited(ref.read(sttModelInstallerProvider).install());
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Text(Strings.retry(lang)),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress >= 0 ? progress.clamp(0.0, 1.0) : null,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Start/stop the thinking heartbeat as the voice phase enters/leaves
  /// `thinking`. Called from a phase listener in [build].
  void _syncThinkingHaptics(VoicePhase phase) {
    if (phase == VoicePhase.thinking) {
      _startThinkingHaptics();
    } else {
      _stopThinkingHaptics();
    }
  }

  void _startThinkingHaptics() {
    if (_thinkHapticTimer != null) return; // already pulsing
    if (!ref.read(settingsProvider).hapticsEnabled) return;
    _thinkHapticStep = 0;
    _thinkHapticBeat();
  }

  void _thinkHapticBeat() {
    _haptics.thinking(_thinkHapticStep);
    final gap = _thinkHapticGaps[_thinkHapticStep % _thinkHapticGaps.length];
    _thinkHapticStep++;
    _thinkHapticTimer = Timer(gap, _thinkHapticBeat);
  }

  void _stopThinkingHaptics() {
    _thinkHapticTimer?.cancel();
    _thinkHapticTimer = null;
  }

  @override
  void dispose() {
    _visemeTimer?.cancel();
    _thinkHapticTimer?.cancel();
    _wakeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = ref.watch(moodStateProvider);
    final voice = ref.watch(voiceControllerProvider);
    // Pulse a heartbeat while thinking; stop it the moment the phase changes.
    ref.listen(voiceControllerProvider.select((v) => v.phase), (_, next) {
      _syncThinkingHaptics(next);
    });
    final appState =
        ref.watch(appStateProvider).valueOrNull ?? const AppState();
    final capturedPhoto = ref.watch(capturedPhotoProvider);
    final lang = ref.watch(langProvider);
    // While the offline STT model downloads, show a thin banner at the top.
    final sttInstall = ref.watch(sttModelInstallStateProvider);

    final ambient = AmbientPalette.fromHour(DateTime.now().hour);
    final moodColor = DesignTokens.moodColor[mood.mood];
    final bodyColor = moodColor ?? ambient.body;
    final accent = moodColor ?? ambient.accent;
    final carMode = ref.watch(appModeProvider).isCar;
    final character = AstroCharacter(
      mood: mood,
      color: bodyColor,
      viseme: voice.viseme,
      size: 260,
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
                        // Speed readout + ring only in car mode.
                        if (carMode) ...[
                          Speedometer(
                            speedKmh: appState.speedKmh.round(),
                            color: moodColor ?? DesignTokens.ink,
                            lang: lang,
                          ),
                          const SizedBox(height: 16),
                        ],
                        GestureDetector(
                          // Tap starts a conversation (like the wake word); tap
                          // again while it's listening to cancel.
                          onTap: () {
                            if (_busy) {
                              _haptics.cancel();
                              _cancelListening();
                            } else {
                              _converse();
                            }
                          },
                          // Press-and-hold to pet Astro (the caress reaction),
                          // since this phone has no usable proximity sensor.
                          onLongPressStart: (_) {
                            _haptics.pet();
                            ref.read(pettingProvider.notifier).state = true;
                          },
                          onLongPressEnd: (_) =>
                              ref.read(pettingProvider.notifier).state = false,
                          onLongPressCancel: () =>
                              ref.read(pettingProvider.notifier).state = false,
                          child: carMode
                              ? VelocityRing(
                                  speedKmh: appState.speedKmh,
                                  color: accent,
                                  size: 330,
                                  child: character,
                                )
                              // Same 330 box (no ring) so the layout doesn't jump.
                              : SizedBox(
                                  width: 330,
                                  height: 330,
                                  child: Center(child: character),
                                ),
                        ),
                        const SizedBox(height: 16),
                        // Min height keeps the layout from jumping when empty;
                        // the text wraps, and a max height + scroll keeps a long
                        // reply fully readable without pushing the pet off-screen.
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 26,
                            maxHeight: 150,
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _spokenText,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: const TextStyle(
                                color: DesignTokens.ink,
                                fontSize: 17,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          switch (voice.phase) {
                            VoicePhase.listening => Strings.listening(lang),
                            VoicePhase.thinking => Strings.thinking(lang),
                            VoicePhase.speaking => Strings.statusSpeaking(lang),
                            VoicePhase.idle => Strings.wakeHint(
                              ref.read(settingsProvider).wakeWord,
                              lang,
                            ),
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
                  lang: lang,
                  onSelect: (car) {
                    _haptics.select();
                    ref
                        .read(appModeProvider.notifier)
                        .set(car ? AppMode.car : AppMode.normal);
                  },
                ),
              ),
            ),
          ),
          // Top-right icons: command palette ("?") and settings (gear).
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      color: accent,
                      onPressed: () => setState(() => _showCommands = true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      color: accent,
                      onPressed: _openSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (sttInstall is Installing || sttInstall is InstallError)
            _sttBanner(lang, accent, sttInstall),
          if (_showCommands) _commandsOverlay(),
          if (_confirmPrompt != null) _confirmOverlay(accent),
          if (_pickContacts != null) _pickOverlay(accent),
          if (_calendarOptions != null) _calendarOverlay(accent),
          if (_emailPickOptions != null) _emailPickOverlay(accent),
          if (_emailArgs != null)
            _EmailConfirm(
              args: _emailArgs!,
              accent: accent,
              lang: lang,
              onSend: () {
                _haptics.confirm();
                _emailCompleter?.complete(true);
              },
              onCancel: () {
                _haptics.cancel();
                _emailCompleter?.complete(false);
              },
            ),
          if (capturedPhoto != null) _photoOverlay(context, capturedPhoto),
        ],
      ),
    );
  }

  /// Full-screen scrim with the command palette; tapping a command closes it and
  /// runs the command through the brain.
  Widget _commandsOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: CommandPalette(
            commands: astroCommands(_lang),
            lang: _lang,
            onClose: () => setState(() => _showCommands = false),
            onCommand: (command) {
              setState(() => _showCommands = false);
              _runCommand(command);
            },
          ),
        ),
      ),
    );
  }

  /// Full-screen contact picker: a button per matching contact; tapping one
  /// resolves the pick (and calls / messages that person).
  Widget _pickOverlay(Color accent) {
    final contacts = _pickContacts ?? const [];
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Strings.which(_lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DesignTokens.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                // Scrolls when there are many matches, so it never overflows.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in contacts) ...[
                          _contactButton(c, accent),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _contactButton(null, DesignTokens.dim), // Cancel (always shown)
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendarOverlay(Color accent) {
    final options = _calendarOptions ?? const [];
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Strings.whichCalendar(_lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DesignTokens.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                // Scrolls when there are many calendars, so it never overflows.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final o in options) ...[
                          _calendarButton(o, accent),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _calendarButton(
                  null,
                  DesignTokens.dim,
                ), // Cancel (always shown)
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A calendar row in the picker. [option] null renders a Cancel button.
  Widget _calendarButton(CalendarOption? option, Color color) {
    final label = option == null
        ? Strings.cancel(_lang)
        : (option.account.isEmpty
              ? option.name
              : '${option.name}\n${option.account}');
    return GestureDetector(
      onTap: () {
        _haptics.select();
        if (_calendarCompleter?.isCompleted == false) {
          _calendarCompleter!.complete(option);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        constraints: const BoxConstraints(minHeight: 60),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// A contact row in the picker. [contact] null renders a Cancel button.
  Widget _contactButton(ContactCandidate? contact, Color color) {
    return GestureDetector(
      onTap: () {
        _haptics.select();
        if (_pickCompleter?.isCompleted == false) {
          _pickCompleter!.complete(contact);
        }
      },
      child: Container(
        width: double.infinity,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          contact?.name ?? Strings.cancel(_lang),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Full-screen email-recipient picker: a button per matching contact (name +
  /// address); tapping one prefills the "to". Scrolls so it never overflows.
  Widget _emailPickOverlay(Color accent) {
    final options = _emailPickOptions ?? const [];
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Strings.whichEmail(_lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DesignTokens.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final o in options) ...[
                          _emailButton(o, accent),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _emailButton(null, DesignTokens.dim), // Cancel (always shown)
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// An email row in the picker: name over address. [option] null → Cancel.
  Widget _emailButton(EmailCandidate? option, Color color) {
    final label = option == null
        ? Strings.cancel(_lang)
        : '${option.name}\n${option.email}';
    return GestureDetector(
      onTap: () {
        _haptics.select();
        if (_emailPickCompleter?.isCompleted == false) {
          _emailPickCompleter!.complete(option);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        constraints: const BoxConstraints(minHeight: 60),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                    Expanded(
                      child: _confirmButton(Strings.yes(_lang), true, accent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _confirmButton(
                        Strings.no(_lang),
                        false,
                        DesignTokens.dim,
                      ),
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
        _haptics.confirm();
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

  /// Popup shown right after a photo is taken: a thumbnail with Ver / Cerrar.
  Widget _photoOverlay(BuildContext context, String path) {
    void close() {
      _haptics.select();
      ref.read(capturedPhotoProvider.notifier).state = null;
    }

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.bgBottomFallback,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(path),
                    height: 200,
                    width: 268,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          Strings.noPreview(_lang),
                          style: const TextStyle(color: DesignTokens.dim),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        close();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PhotoViewerScreen(path: path),
                          ),
                        );
                      },
                      child: Text(Strings.view(_lang)),
                    ),
                    TextButton(
                      onPressed: close,
                      child: Text(Strings.close(_lang)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Editable review of the email Astro understood, before sending. Its own
/// controllers keep the edits; on Enviar it writes the corrected values back
/// into [args] (the same map the tool reads) and calls [onSend].
class _EmailConfirm extends StatefulWidget {
  const _EmailConfirm({
    required this.args,
    required this.accent,
    required this.lang,
    required this.onSend,
    required this.onCancel,
  });

  final Map<String, dynamic> args;
  final Color accent;
  final AppLang lang;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  State<_EmailConfirm> createState() => _EmailConfirmState();
}

class _EmailConfirmState extends State<_EmailConfirm> {
  late final _to = TextEditingController(
    text: (widget.args['to'] as String?) ?? '',
  );
  late final _subject = TextEditingController(
    text: (widget.args['subject'] as String?) ?? '',
  );
  late final _body = TextEditingController(
    text: (widget.args['body'] as String?) ?? '',
  );

  @override
  void dispose() {
    _to.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _send() {
    // Write the corrected values back so the tool sends what's on screen.
    widget.args['to'] = _to.text.trim();
    widget.args['subject'] = _subject.text.trim();
    widget.args['body'] = _body.text.trim();
    widget.onSend();
  }

  Widget _field(String label, TextEditingController c, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          style: const TextStyle(color: DesignTokens.ink),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: DesignTokens.dim),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.82),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Strings.reviewEmail(widget.lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DesignTokens.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _field(Strings.to(widget.lang), _to),
                        _field(Strings.subject(widget.lang), _subject),
                        _field(
                          Strings.message(widget.lang),
                          _body,
                          maxLines: 5,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        child: Text(Strings.cancel(widget.lang)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _send,
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.accent,
                        ),
                        child: Text(Strings.send(widget.lang)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
