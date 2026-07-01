import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'voice_interfaces.dart';

/// True when [keyword] appears in [transcript] (case/diacritic-insensitive).
/// Pure, so the matching logic is unit-tested without the plugin.
bool containsWakeWord(String transcript, String keyword) {
  String norm(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  return norm(transcript).contains(norm(keyword));
}

/// Stopgap wake-word detector built on `speech_to_text`: it listens
/// continuously and fires [onWake] when it hears the keyword. Works for the
/// real word "Astro" with no Picovoice key or trained model. The trade-off is
/// power (the mic stays open) and that the recognizer auto-stops on silence, so
/// we restart it. Porcupine is the low-power production replacement — same
/// `WakeWordDetector` interface.
class SttWakeWord implements WakeWordDetector {
  SttWakeWord({this.keyword = 'hola astro', this.localeId = 'es_ES'});

  /// Phrase to match; mutable so Settings can change it at runtime.
  String keyword;
  final String localeId;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final StreamController<void> _wakes = StreamController<void>.broadcast();
  bool _running = false;
  bool _available = false;

  @override
  Stream<void> get onWake => _wakes.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    try {
      _available = await _speech.initialize(
        onStatus: _onStatus,
        onError: (e) => debugPrint('SttWakeWord error: ${e.errorMsg}'),
      );
    } catch (e) {
      // No speech recognition on this device / platform (or test env).
      debugPrint('SttWakeWord init failed: $e');
      return;
    }
    if (!_available) {
      debugPrint('SttWakeWord: speech recognition unavailable');
      return;
    }
    _running = true;
    _listen();
  }

  void _listen() {
    if (!_running) return;
    try {
      _speech.listen(
        onResult: (result) {
          if (containsWakeWord(result.recognizedWords, keyword)) {
            _wakes.add(null);
          }
        },
        // Long session + long silence tolerance so a quiet gap doesn't stop it;
        // when the recognizer does stop, _onStatus restarts it.
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(minutes: 5),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          localeId: localeId,
        ),
      );
    } catch (e) {
      // A session may still be closing; retry shortly.
      debugPrint('SttWakeWord listen failed: $e');
      if (_running) {
        Future<void>.delayed(const Duration(milliseconds: 500), _listen);
      }
    }
  }

  void _onStatus(String status) {
    // The recognizer stops on silence/timeout; keep it alive while running.
    if (_running && (status == 'done' || status == 'notListening')) {
      Future<void>.delayed(const Duration(milliseconds: 300), _listen);
    }
  }

  /// Pause listening (e.g. while Astro speaks, to avoid hearing herself).
  @override
  Future<void> pause() async {
    _running = false;
    await _speech.stop();
  }

  /// Resume after [pause].
  @override
  Future<void> resume() async {
    if (_running || !_available) return;
    _running = true;
    _listen();
  }

  @override
  Future<void> setKeyword(String keyword) async {
    final k = keyword.trim();
    if (k.isNotEmpty) this.keyword = k;
  }

  /// No-op: matching by substring has no confidence gate to tune.
  @override
  Future<void> setSensitivity(double value) async {}

  @override
  Future<void> stop() async {
    _running = false;
    await _speech.stop();
  }

  void dispose() {
    _running = false;
    _speech.cancel();
    _wakes.close();
  }
}
