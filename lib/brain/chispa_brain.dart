import 'llm/llm_client.dart';
import 'llm/llm_message.dart';
import 'tools/chispa_tool.dart';
import 'tools/tool_registry.dart';

/// Asked to approve a mutating tool before it runs. Return true to allow.
/// Wired to voice confirmation in the app; defaults to allow in tests.
typedef ConfirmTool = Future<bool> Function(
  ChispaTool tool,
  Map<String, dynamic> args,
);

/// Given the user's turn, return extra system context to prepend (e.g. relevant
/// memories), or null for none. Lets Chispa recall without the model having to
/// call a tool.
typedef RecallContext = Future<String?> Function(String userText);

/// The agentic loop: send the conversation to the model, run any tools it asks
/// for (gating mutating ones behind confirmation), feed the results back, and
/// repeat until the model returns a final answer. Ported in spirit from the
/// nexo-rs driver loop, trimmed to what Chispa needs.
///
/// `onThinking(true)` fires while a request is in flight and `onToolUse(name)`
/// fires when a tool runs, so the character can show the thinking / "consulting
/// X" / speaking animations.
class ChispaBrain {
  ChispaBrain({
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

  /// Run one user turn to a final text answer.
  Future<String> ask(
    String userText, {
    required String model,
    String? system,
  }) async {
    final messages = <LlmMessage>[LlmMessage.text(Role.user, userText)];
    final effectiveSystem = await _systemWithRecall(userText, system);

    for (var turn = 0; turn < maxTurns; turn++) {
      onThinking?.call(true);
      final LlmResponse response;
      try {
        response = await client.complete(
          LlmRequest(
            model: model,
            messages: messages,
            system: effectiveSystem,
            tools: registry.specs(),
          ),
        );
      } finally {
        onThinking?.call(false);
      }

      messages.add(response.message);

      final toolUses = response.toolUses;
      if (toolUses.isEmpty) {
        return _finalText(response.message);
      }

      // Run every requested tool and feed the results back as one message.
      final results = <ContentBlock>[];
      for (final call in toolUses) {
        results.add(await _runTool(call));
      }
      messages.add(LlmMessage(role: Role.tool, blocks: results));
    }

    return 'Sorry, I got stuck on that one.';
  }

  /// Prepend recalled memory context to the system prompt, if any.
  Future<String?> _systemWithRecall(String userText, String? system) async {
    final context = await recallContext?.call(userText);
    if (context == null || context.isEmpty) return system;
    return [if (system != null && system.isNotEmpty) system, context]
        .join('\n\n');
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

    // Policy gate: mutating tools require confirmation.
    if (tool.mutates) {
      final allowed = await (confirm?.call(tool, call.arguments) ??
          Future.value(true));
      if (!allowed) {
        return ToolResultBlock(
          toolUseId: call.id,
          content: 'Cancelled by the user.',
        );
      }
    }

    onToolUse?.call(tool.name);
    final result = await tool.run(call.arguments);
    return ToolResultBlock(
      toolUseId: call.id,
      content: result.content,
      isError: result.isError,
    );
  }

  String _finalText(LlmMessage message) {
    final text = message.blocks
        .whereType<TextBlock>()
        .map((b) => b.text)
        .join('\n')
        .trim();
    return text.isEmpty ? '...' : text;
  }
}
