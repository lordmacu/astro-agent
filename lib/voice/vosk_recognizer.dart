import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';

import 'voice_interfaces.dart';

/// Offline, on-device speech recognition with Vosk. Unlike the platform
/// recognizer (which endpoints aggressively and cuts long phrases at the first
/// pause), Vosk runs a single continuous audio stream, so a full command is
/// captured with no restart gap. We end the utterance ourselves once the mic
/// has been quiet for [endSilence].
///
/// If the model can't load (e.g. it isn't bundled yet), every call transparently
/// falls back to [fallback] (the platform `speech_to_text`), so the app keeps
/// working until the ~40 MB Spanish model is dropped into assets.
class VoskSpeechRecognizer implements SpeechRecognizer {
  VoskSpeechRecognizer({
    required this.fallback,
    this.modelAsset = 'assets/models/vosk-model-small-es-0.42.zip',
    this.sampleRate = 16000,
    this.endSilence = const Duration(milliseconds: 1400),
    this.startTimeout = const Duration(seconds: 6),
    this.maxUtterance = const Duration(seconds: 15),
  });

  /// Used when the Vosk model is unavailable.
  final SpeechRecognizer fallback;
  final String modelAsset;
  final int sampleRate;

  /// Quiet time (after speech) that ends the utterance.
  final Duration endSilence;

  /// How long to wait for the driver to START talking before giving up.
  final Duration startTimeout;

  /// Absolute cap on a single capture.
  final Duration maxUtterance;

  final VoskFlutterPlugin _plugin = VoskFlutterPlugin.instance();
  Recognizer? _recognizer;
  bool _initTried = false;
  bool _available = false;

  void Function()? _onListening;

  @override
  set onListening(void Function()? cb) {
    _onListening = cb;
    fallback.onListening = cb; // keep the cue when we fall back
  }

  @override
  Future<bool> warmUp() async {
    if (_initTried) return _available;
    _initTried = true;
    try {
      final modelPath = await ModelLoader().loadFromAssets(modelAsset);
      final model = await _plugin.createModel(modelPath);
      // Load the model + recognizer only. The mic-owning SpeechService is
      // created per-capture (below), so we don't hold the mic while the native
      // Vosk wake word owns it.
      _recognizer = await _plugin.createRecognizer(
        model: model,
        sampleRate: sampleRate,
      );
      _available = true;
      debugPrint('[Astro] 🧠 Vosk offline STT ready (continuous, no network)');
    } catch (e) {
      _available = false; // model missing / init failed → platform STT
      debugPrint(
        '[Astro] Vosk unavailable ($e) → falling back to platform STT',
      );
      await fallback.warmUp();
    }
    return _available;
  }

  @override
  Future<String?> listen({Duration? pauseFor, bool shortReply = false}) async {
    await warmUp();
    final rec = _recognizer;
    if (!_available || rec == null) {
      return fallback.listen(pauseFor: pauseFor, shortReply: shortReply);
    }
    // Fresh mic session per command: create the SpeechService now (the wake mic
    // has been paused, so the mic is free), capture, then release it.
    SpeechService? svc;
    try {
      await rec.reset();
      svc = await _plugin.initSpeechService(rec);
      return await _listen(svc, shortReply: shortReply, pauseFor: pauseFor);
    } catch (e) {
      debugPrint('[Astro] Vosk listen failed ($e) → platform STT');
      return fallback.listen(pauseFor: pauseFor, shortReply: shortReply);
    } finally {
      try {
        await svc?.stop();
      } catch (_) {}
      try {
        await svc?.dispose();
      } catch (_) {}
    }
  }

  Future<String?> _listen(
    SpeechService svc, {
    required bool shortReply,
    Duration? pauseFor,
  }) async {
    final gap =
        pauseFor ??
        (shortReply ? const Duration(milliseconds: 900) : endSilence);

    final sw = Stopwatch()..start();
    final buffer = StringBuffer();
    var lastPartial = '';
    var loggedPartial = '';
    var speaking = false;
    var endReason = 'silence';
    final completer = Completer<String?>();
    Timer? silence;

    void finish(String reason) {
      if (completer.isCompleted) return;
      endReason = reason;
      final done = buffer.toString().trim();
      final text = done.isNotEmpty ? done : lastPartial.trim();
      completer.complete(text.isEmpty ? null : text);
    }

    // Restart the silence countdown. Before any speech, wait [startTimeout];
    // once talking, end after [gap] of quiet.
    void bump({bool speech = false}) {
      if (speech) speaking = true;
      silence?.cancel();
      silence = Timer(
        speaking ? gap : startTimeout,
        () => finish(speaking ? 'silence' : 'no-speech'),
      );
    }

    final guard = Timer(maxUtterance, () => finish('max-length'));

    final partialSub = svc.onPartial().listen((json) {
      final p = _field(json, 'partial');
      if (p.isNotEmpty) {
        // Only log when the hypothesis actually changed (partials repeat a lot).
        if (p != loggedPartial) {
          loggedPartial = p;
          debugPrint('[Astro][vosk] ~ $p');
        }
        lastPartial = p;
        bump(speech: true);
      }
    });
    final resultSub = svc.onResult().listen((json) {
      final r = _field(json, 'text');
      if (r.isNotEmpty) {
        debugPrint('[Astro][vosk] ✓ segment: $r');
        buffer.write(buffer.isEmpty ? r : ' $r');
        lastPartial = '';
        loggedPartial = '';
      }
      bump(speech: true);
    });

    await svc.start();
    HapticFeedback.selectionClick();
    _onListening?.call(); // mic is live — cue the driver
    debugPrint('[Astro][vosk] 🎧 listening (gap=${gap.inMilliseconds}ms)');
    bump(); // start the "waiting to speak" countdown

    final text = await completer.future;
    guard.cancel();
    silence?.cancel();
    await partialSub.cancel();
    await resultSub.cancel();
    // The caller (listen) stops + disposes the service.
    debugPrint(
      '[Astro][vosk] ⏹ end ($endReason, ${sw.elapsedMilliseconds}ms) '
      '→ "${text ?? '(nothing)'}"',
    );
    return text;
  }

  String _field(String json, String key) {
    try {
      final m = jsonDecode(json);
      if (m is Map && m[key] is String) return (m[key] as String).trim();
    } catch (_) {
      // ignore malformed events
    }
    return '';
  }

  @override
  Future<void> stop() async {
    // The per-capture service is torn down inside listen(); nothing persistent
    // to stop here. Delegate to the fallback when Vosk isn't in use.
    if (!_available) await fallback.stop();
  }
}
