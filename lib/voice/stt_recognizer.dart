import 'dart:async';

import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'voice_interfaces.dart';

/// Captures one spoken command with the `speech_to_text` plugin. Used AFTER the
/// wake word fires: the native wake service is paused (freeing the mic), this
/// grabs an utterance, then the wake service resumes. Spanish by default.
///
/// Android's recognizer "endpoints" on the first natural pause, so a command
/// said with a beat in the middle ("llama... a esposita") gets cut after the
/// first words. To fight that, a command capture listens in rounds and keeps
/// going while what it heard still looks unfinished (ends in a preposition, or
/// is a lone command verb), concatenating each round. A phrase that already
/// looks complete ends immediately, so there's no dead wait for normal commands.
class SttSpeechRecognizer implements SpeechRecognizer {
  SttSpeechRecognizer({
    this.localeId = 'es_ES',
    this.listenFor = const Duration(seconds: 8),
    this.pauseFor = const Duration(seconds: 2),
    this.maxRounds = 3,
  });

  final String localeId;

  /// Hard cap on a single recognition round.
  final Duration listenFor;

  /// Default silence that ends a round; a `listen` call may override it.
  final Duration pauseFor;

  /// Cap on how many rounds a command capture stitches together.
  final int maxRounds;

  /// Fired once, when the mic goes live, so the UI can play a "speak now" cue.
  @override
  void Function()? onListening;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  // Per-round hooks so the global status/error callbacks (set once at init) can
  // end the current round fast instead of waiting for the long guard.
  void Function(String status)? _onStatus;
  void Function()? _onError;
  bool _shouldCue = false; // cue only on the first round of a capture

  /// Initialise ahead of time so the first real capture doesn't pay init cost.
  @override
  Future<bool> warmUp() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (_) => _onError?.call(),
      onStatus: (status) {
        if (status == 'listening' && _shouldCue) {
          _shouldCue = false;
          HapticFeedback.selectionClick();
          onListening?.call();
        }
        _onStatus?.call(status);
      },
    );
    return _initialized;
  }

  @override
  Future<String?> listen({Duration? pauseFor, bool shortReply = false}) async {
    if (!await warmUp()) return null;
    _shouldCue = true;

    if (shortReply) {
      final r = await _round(pauseFor: pauseFor, shortReply: true);
      return (r == null || r.isEmpty) ? null : r;
    }

    // Command: stitch rounds while the phrase still looks unfinished.
    final buffer = StringBuffer();
    for (var round = 0; round < maxRounds; round++) {
      final chunk = await _round(pauseFor: pauseFor, shortReply: false);
      if (chunk == null || chunk.isEmpty) break; // silence → done
      buffer.write(buffer.isEmpty ? chunk : ' $chunk');
      if (!_looksIncomplete(buffer.toString())) break; // complete → done
    }
    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// One recognition session. Completes as soon as the platform finalizes, the
  /// session stops, or it errors (e.g. no speech) — so an empty continuation
  /// round resolves quickly instead of hanging on the long guard.
  Future<String?> _round({Duration? pauseFor, required bool shortReply}) async {
    if (_speech.isListening) {
      await _speech.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    final endSilence = pauseFor ?? this.pauseFor;
    final completer = Completer<String?>();
    var best = '';
    void finish() {
      if (!completer.isCompleted) completer.complete(best);
    }

    _onStatus = (s) {
      if (s == 'done' || s == 'notListening') finish();
    };
    _onError = finish;

    await _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) best = result.recognizedWords;
        if (result.finalResult) finish();
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: endSilence,
        partialResults: true,
        // "confirmation" is tuned for short yes/no answers.
        listenMode: shortReply
            ? stt.ListenMode.confirmation
            : stt.ListenMode.dictation,
        cancelOnError: true,
      ),
    );

    final guard = Timer(listenFor + const Duration(seconds: 1), () async {
      await _speech.stop();
      finish();
    });

    final text = await completer.future;
    guard.cancel();
    _onStatus = null;
    _onError = null;
    return text?.trim();
  }

  /// A phrase looks unfinished when it trails off on a connector word (a, en,
  /// de, para, que...) or is a lone command verb — the exact shapes Android's
  /// endpointing leaves behind ("llama a", "busca en", "llamar").
  bool _looksIncomplete(String text) {
    final words = text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return false;
    final last = words.last.replaceAll(RegExp(r'[^0-9a-záéíóúñü]'), '');
    if (_connectors.contains(last)) return true;
    if (words.length == 1 && _leadVerbs.contains(last)) return true;
    return false;
  }

  static const _connectors = {
    'a',
    'ante',
    'bajo',
    'con',
    'contra',
    'de',
    'del',
    'desde',
    'en',
    'entre',
    'hacia',
    'hasta',
    'para',
    'por',
    'según',
    'sin',
    'sobre',
    'tras',
    'y',
    'e',
    'o',
    'u',
    'que',
    'el',
    'la',
    'los',
    'las',
    'un',
    'una',
    'unos',
    'unas',
    'al',
    'mi',
    'tu',
    'su',
    'lo',
    'le',
    'me',
    'te',
    'se',
    'nos',
  };

  static const _leadVerbs = {
    'llama',
    'llamar',
    'busca',
    'buscar',
    'pon',
    'poner',
    'ponme',
    'manda',
    'mandar',
    'dile',
    'escribe',
    'escribir',
    'navega',
    'navegar',
    'lleva',
    'llévame',
    'abre',
    'sube',
    'baja',
    'recuerda',
    'recuérdame',
    'reproduce',
  };

  @override
  Future<void> stop() => _speech.stop();
}
