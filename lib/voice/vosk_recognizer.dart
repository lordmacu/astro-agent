import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';

import 'voice_interfaces.dart';

/// Locate the Vosk model root under [base]: the folder that directly contains
/// the model's `am/` (or `conf/`) subdir. The downloaded zip may nest the files
/// under a top-level folder (e.g. `vosk-model-small-es-0.42/`), so check [base]
/// first, then its immediate subdirectories.
String resolveVoskModelRoot(String base) {
  bool looksLikeModel(String p) =>
      Directory('$p/am').existsSync() || Directory('$p/conf').existsSync();
  if (looksLikeModel(base)) return base;
  final dir = Directory(base);
  if (dir.existsSync()) {
    for (final e in dir.listSync()) {
      if (e is Directory && looksLikeModel(e.path)) return e.path;
    }
  }
  return base;
}

/// Offline, on-device speech recognition with Vosk. Unlike the platform
/// recognizer (which endpoints aggressively and cuts long phrases at the first
/// pause), Vosk runs a single continuous audio stream, so a full command is
/// captured with no restart gap. We end the utterance ourselves once the mic
/// has been quiet for [endSilence].
///
/// The ~37 MB Spanish model is downloaded on demand (see stt_model_provider),
/// so until it finishes every call transparently falls back to [fallback] (the
/// platform `speech_to_text`). [modelDir] returns the unzipped model directory
/// once ready, or null/empty meanwhile; `warmUp` retries on each call so Astro
/// switches to Vosk automatically the moment the download lands.
class VoskSpeechRecognizer implements SpeechRecognizer {
  VoskSpeechRecognizer({
    required this.fallback,
    required this.modelDir,
    this.sampleRate = 16000,
    this.endSilence = const Duration(milliseconds: 1400),
    this.startTimeout = const Duration(seconds: 6),
    this.maxUtterance = const Duration(seconds: 15),
  });

  /// Used until the Vosk model is downloaded (or if it fails to load).
  final SpeechRecognizer fallback;

  /// The unzipped model directory, or null/empty until the download completes.
  final String? Function() modelDir;
  final int sampleRate;

  /// Quiet time (after speech) that ends the utterance.
  final Duration endSilence;

  /// How long to wait for the driver to START talking before giving up.
  final Duration startTimeout;

  /// Absolute cap on a single capture.
  final Duration maxUtterance;

  final VoskFlutterPlugin _plugin = VoskFlutterPlugin.instance();
  Recognizer? _recognizer;
  bool _available = false;

  void Function()? _onListening;

  @override
  set onListening(void Function()? cb) {
    _onListening = cb;
    fallback.onListening = cb; // keep the cue when we fall back
  }

  @override
  Future<bool> warmUp() async {
    if (_available) return true;
    final dir = modelDir()?.trim() ?? '';
    if (dir.isEmpty) {
      // Model not downloaded yet → keep using the platform recognizer.
      await fallback.warmUp();
      return false;
    }
    try {
      final model = await _plugin.createModel(resolveVoskModelRoot(dir));
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
      _available = false; // load failed → keep the platform STT for now
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
