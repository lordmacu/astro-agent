import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'llm/llm_client.dart';
import 'llm/llm_message.dart';
import 'tools/astro_tool.dart';
import 'tools/tool_registry.dart';

/// Asked to approve a mutating tool before it runs. Return true to allow.
/// Wired to voice confirmation in the app; defaults to allow in tests.
typedef ConfirmTool =
    Future<bool> Function(AstroTool tool, Map<String, dynamic> args);

/// Given the user's turn, return extra system context to prepend (e.g. relevant
/// memories), or null for none. Lets Astro recall without the model having to
/// call a tool.
typedef RecallContext = Future<String?> Function(String userText);

/// The agentic loop: send the conversation to the model, run any tools it asks
/// for (gating mutating ones behind confirmation), feed the results back, and
/// repeat until the model returns a final answer. Ported in spirit from the
/// nexo-rs driver loop, trimmed to what Astro needs.
///
/// `onThinking(true)` fires while a request is in flight and `onToolUse(name)`
/// fires when a tool runs, so the character can show the thinking / "consulting
/// X" / speaking animations.
class AstroBrain {
  AstroBrain({
    required this.client,
    required this.registry,
    this.onThinking,
    this.onToolUse,
    this.confirm,
    this.recallContext,
    this.maxTurns = 6,
  });

  final LlmClient client;
  final ToolRegistry registry;
  final void Function(bool thinking)? onThinking;
  final void Function(String toolName)? onToolUse;
  final ConfirmTool? confirm;

  /// Optional memory recall, injected into the system prompt for this turn.
  final RecallContext? recallContext;

  /// Hard cap on tool round-trips, a backstop against runaway loops.
  final int maxTurns;

  /// Rolling conversation memory (user + final-answer turns) so follow-ups like
  /// "sí, dámela exacta" have context. Only [askStream] uses it. Bounded and
  /// cleared after a long idle gap so stale context doesn't bleed in.
  final List<LlmMessage> _history = [];
  DateTime? _lastTurnAt;
  static const _historyMax = 6; // ~3 exchanges (trimmed for lower prefill cost)
  static const _idleReset = Duration(minutes: 3);

  /// Output-token cap per model call. Astro speaks 1–2 short sentences, so a
  /// tight cap keeps generation fast and prevents rambling. Tool-call turns need
  /// far fewer tokens than this.
  static const _maxAnswerTokens = 192;

  /// Forget the running conversation (e.g. to start fresh).
  void resetConversation() {
    _history.clear();
    _lastTurnAt = null;
  }

  /// Run one user turn to a final text answer.
  Future<String> ask(
    String userText, {
    required String model,
    String? system,
  }) async {
    final sw = Stopwatch()..start();
    _log('▶ user: $userText  [model=$model]');
    final messages = <LlmMessage>[LlmMessage.text(Role.user, userText)];
    final effectiveSystem = await _systemWithRecall(userText, system);
    var languageRetried = false;

    for (var turn = 0; turn < maxTurns; turn++) {
      onThinking?.call(true);
      final callSw = Stopwatch()..start();
      final LlmResponse response;
      try {
        response = await client.complete(
          LlmRequest(
            model: model,
            messages: messages,
            system: effectiveSystem,
            tools: registry.specs(),
            // Voice replies are short; cap output so the model can't ramble
            // and the scheduler has a tight budget.
            maxTokens: _maxAnswerTokens,
          ),
        );
      } finally {
        onThinking?.call(false);
      }
      _log('  · model call ${turn + 1}: ${callSw.elapsedMilliseconds}ms');

      messages.add(response.message);

      final toolUses = response.toolUses;
      if (toolUses.isEmpty) {
        final text = _finalText(response.message);

        // Language safety net: if the model slipped into another script (e.g.
        // Chinese), ask it once to rewrite the answer in Spanish.
        if (_hasForeignScript(text) && !languageRetried) {
          languageRetried = true;
          _log('⚠ non-Spanish output detected, requesting rewrite: $text');
          messages.add(
            LlmMessage.text(
              Role.user,
              'Reescribe tu última respuesta completa en español de Colombia. '
              'No dejes ninguna palabra en chino, inglés ni otro idioma.',
            ),
          );
          continue;
        }

        _log('◀ answer (${sw.elapsedMilliseconds}ms, turn ${turn + 1}): $text');
        return text;
      }

      // Run every requested tool and feed the results back as one message.
      final results = <ContentBlock>[];
      for (final call in toolUses) {
        results.add(await _runTool(call));
      }
      messages.add(LlmMessage(role: Role.tool, blocks: results));
    }

    _log('◀ gave up after $maxTurns turns (${sw.elapsedMilliseconds}ms)');
    return 'Uy, me enredé con eso. ¿Lo intentamos otra vez?';
  }

  /// Like [ask], but streams: [onSentence] fires with each complete sentence of
  /// the answer as it is generated, so the caller can start speaking before the
  /// whole reply is ready. Runs the same agentic loop; reasoning and any
  /// foreign-script slips are filtered before a sentence is emitted. Returns the
  /// full spoken text.
  Future<String> askStream(
    String userText, {
    required String model,
    String? system,
    required void Function(String sentence) onSentence,
  }) async {
    final sw = Stopwatch()..start();
    _log('▶ (stream) user: $userText  [model=$model]');
    _maybeResetHistory();
    final userMessage = LlmMessage.text(Role.user, userText);
    final messages = <LlmMessage>[..._history, userMessage];
    final effectiveSystem = await _systemWithRecall(userText, system);
    final spoken = StringBuffer();

    void emit(String sentence) {
      final clean = _stripReasoning(sentence).trim();
      if (clean.isEmpty || _hasForeignScript(clean)) return;
      spoken.write(spoken.isEmpty ? clean : ' $clean');
      onSentence(clean);
    }

    for (var turn = 0; turn < maxTurns; turn++) {
      onThinking?.call(true);
      final callSw = Stopwatch()..start();
      final splitter = _SentenceSplitter(emit);
      LlmResponse? done;
      try {
        await for (final chunk in client.completeStream(
          LlmRequest(
            model: model,
            messages: messages,
            system: effectiveSystem,
            tools: registry.specs(),
            maxTokens: _maxAnswerTokens,
          ),
        )) {
          switch (chunk) {
            case LlmTextDelta(:final text):
              splitter.add(text);
            case LlmDone(:final response):
              done = response;
          }
        }
      } finally {
        onThinking?.call(false);
      }
      splitter.flush();
      _log('  · model call ${turn + 1}: ${callSw.elapsedMilliseconds}ms');

      final response = done;
      if (response == null) break;
      messages.add(response.message);

      final toolUses = response.toolUses;
      if (toolUses.isEmpty) {
        final text = spoken.toString().trim();
        _remember(userMessage, text);
        _log('◀ (stream) answer (${sw.elapsedMilliseconds}ms): $text');
        return text;
      }

      final results = <ContentBlock>[];
      for (final call in toolUses) {
        results.add(await _runTool(call));
      }
      messages.add(LlmMessage(role: Role.tool, blocks: results));
    }

    final text = spoken.toString().trim();
    _log('◀ (stream) done (${sw.elapsedMilliseconds}ms)');
    return text.isEmpty
        ? 'Uy, me enredé con eso. ¿Lo intentamos otra vez?'
        : text;
  }

  /// Drop the conversation memory if it's been idle too long.
  void _maybeResetHistory() {
    final last = _lastTurnAt;
    if (last != null && DateTime.now().difference(last) > _idleReset) {
      _history.clear();
    }
  }

  /// Append this exchange to the rolling memory, bounded to the last few turns.
  void _remember(LlmMessage userMessage, String answer) {
    if (answer.isEmpty) return;
    _history
      ..add(userMessage)
      ..add(LlmMessage.text(Role.assistant, answer));
    while (_history.length > _historyMax) {
      _history.removeAt(0);
    }
    _lastTurnAt = DateTime.now();
  }

  /// Log a line to the console (visible in `flutter run` / logcat), so the user
  /// can see what Astro heard, which tools it called, and what it answered, and
  /// tune the prompt and tools from that.
  void _log(String message) => debugPrint('[Astro] $message');

  /// True when [text] contains CJK (Han) or Hangul/Hiragana/Katakana — a sign
  /// the model answered in the wrong language.
  bool _hasForeignScript(String text) =>
      RegExp(r'[぀-ヿ㐀-䶿一-鿿가-힯]').hasMatch(text);

  /// Prepend recalled memory context to the system prompt, if any.
  Future<String?> _systemWithRecall(String userText, String? system) async {
    final context = await recallContext?.call(userText);
    if (context == null || context.isEmpty) return system;
    return [
      if (system != null && system.isNotEmpty) system,
      context,
    ].join('\n\n');
  }

  Future<ToolResultBlock> _runTool(ToolUseBlock call) async {
    final tool = registry.byName(call.name);
    if (tool == null) {
      return ToolResultBlock(
        toolUseId: call.id,
        content: 'Unknown tool: ${call.name}',
        isError: true,
      );
    }

    // Policy gate: tools that ask for confirmation for this call.
    if (await tool.requiresConfirmation(call.arguments)) {
      final allowed =
          await (confirm?.call(tool, call.arguments) ?? Future.value(true));
      if (!allowed) {
        return ToolResultBlock(
          toolUseId: call.id,
          content: 'Cancelled by the user.',
        );
      }
    }

    onToolUse?.call(tool.name);
    _log('🔧 ${tool.name}(${_encodeArgs(call.arguments)})');
    final toolSw = Stopwatch()..start();
    final result = await tool.run(call.arguments);
    _log(
      '   ↳ (${toolSw.elapsedMilliseconds}ms) '
      '${result.isError ? 'ERROR ' : ''}${result.content}',
    );
    return ToolResultBlock(
      toolUseId: call.id,
      content: result.content,
      isError: result.isError,
    );
  }

  String _encodeArgs(Map<String, dynamic> args) {
    try {
      return jsonEncode(args);
    } catch (_) {
      return args.toString();
    }
  }

  String _finalText(LlmMessage message) {
    final raw = message.blocks
        .whereType<TextBlock>()
        .map((b) => b.text)
        .join('\n');
    final text = _stripReasoning(raw).trim();
    return text.isEmpty ? '...' : text;
  }

  /// Strip any chain-of-thought the model leaked into the content. MiniMax M3
  /// wraps reasoning in `<think>...</think>`; we disable thinking at the API
  /// level too, but this guarantees it never reaches the voice even if a stray
  /// tag slips through.
  String _stripReasoning(String text) {
    var out = text.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    // A dangling close tag means everything before it was reasoning.
    final close = out.lastIndexOf('</think>');
    if (close != -1) out = out.substring(close + '</think>'.length);
    // Drop any remaining stray open/close tags.
    return out.replaceAll(RegExp(r'</?think>'), '');
  }
}

/// Buffers streamed text deltas and emits one complete sentence at a time, so
/// the voice can start on the first sentence while the rest still generates.
class _SentenceSplitter {
  _SentenceSplitter(this._onSentence);

  final void Function(String sentence) _onSentence;
  final StringBuffer _buf = StringBuffer();

  static final _boundary = RegExp(r'[.!?…\n]');

  void add(String delta) {
    _buf.write(delta);
    while (true) {
      final s = _buf.toString();
      final match = _boundary.firstMatch(s);
      if (match == null) break;
      final sentence = s.substring(0, match.end).trim();
      _buf
        ..clear()
        ..write(s.substring(match.end));
      if (sentence.isNotEmpty) _onSentence(sentence);
    }
  }

  /// Emit whatever is left (a final sentence with no trailing punctuation).
  void flush() {
    final rest = _buf.toString().trim();
    _buf.clear();
    if (rest.isNotEmpty) _onSentence(rest);
  }
}
