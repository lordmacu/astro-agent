/// Provider-agnostic chat types. Ported in spirit from the nexo-rs `llm` crate:
/// one neutral message shape that per-provider adapters (Anthropic, DeepSeek,
/// OpenAI-compatible, local Ollama) translate to and from their own JSON. No
/// provider details leak into this file.
library;

enum Role { system, user, assistant, tool }

/// Why the model stopped generating.
enum StopReason { endTurn, toolUse, maxTokens, stop }

/// A single piece of message content. A message can mix text and tool blocks.
sealed class ContentBlock {
  const ContentBlock();
}

/// Plain text content.
class TextBlock extends ContentBlock {
  const TextBlock(this.text);
  final String text;
}

/// The model asking to run a tool.
class ToolUseBlock extends ContentBlock {
  const ToolUseBlock({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
}

/// The result of a tool, fed back to the model.
class ToolResultBlock extends ContentBlock {
  const ToolResultBlock({
    required this.toolUseId,
    required this.content,
    this.isError = false,
  });

  final String toolUseId;
  final String content;
  final bool isError;
}

/// One turn in the conversation.
class LlmMessage {
  const LlmMessage({required this.role, required this.blocks});

  LlmMessage.text(this.role, String text) : blocks = [TextBlock(text)];

  final Role role;
  final List<ContentBlock> blocks;
}

/// Declares a tool to the model: name, description, JSON Schema of its input.
class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
}

/// A request to the model, independent of provider.
class LlmRequest {
  const LlmRequest({
    required this.model,
    required this.messages,
    this.system,
    this.tools = const [],
    this.maxTokens = 1024,
    this.temperature = 0.7,
  });

  final String model;
  final List<LlmMessage> messages;
  final String? system;
  final List<ToolSpec> tools;
  final int maxTokens;
  final double temperature;

  LlmRequest copyWith({List<LlmMessage>? messages}) => LlmRequest(
    model: model,
    messages: messages ?? this.messages,
    system: system,
    tools: tools,
    maxTokens: maxTokens,
    temperature: temperature,
  );
}

/// The model's reply.
class LlmResponse {
  const LlmResponse({required this.message, required this.stopReason});

  final LlmMessage message;
  final StopReason stopReason;

  /// The tool calls the model is requesting this turn, if any.
  List<ToolUseBlock> get toolUses =>
      message.blocks.whereType<ToolUseBlock>().toList();
}
