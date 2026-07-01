import 'llm_message.dart';

/// Provider-agnostic LLM client. Each backend (Anthropic, DeepSeek,
/// OpenAI-compatible, local Ollama) implements this once; the rest of the brain
/// only ever talks to this interface. Ported from the nexo-rs `llm::client`
/// abstraction.
abstract interface class LlmClient {
  /// A short identifier for logs and quota tracking (e.g. "anthropic").
  String get providerId;

  /// Run one completion turn. Adapters translate `LlmRequest` to provider JSON
  /// and the provider reply back into an `LlmResponse`.
  Future<LlmResponse> complete(LlmRequest request);

  /// Stream one completion turn: emit [LlmTextDelta]s as text arrives and a
  /// final [LlmDone] carrying the assembled response (text + tool calls).
  /// Adapters that don't stream natively delegate to [streamViaComplete].
  Stream<LlmStreamChunk> completeStream(LlmRequest request);
}

/// A piece of a streamed completion.
sealed class LlmStreamChunk {
  const LlmStreamChunk();
}

/// Incremental assistant text, as it is generated.
class LlmTextDelta extends LlmStreamChunk {
  const LlmTextDelta(this.text);
  final String text;
}

/// The turn finished; carries the fully assembled response so the agentic loop
/// can inspect tool calls and stop reason.
class LlmDone extends LlmStreamChunk {
  const LlmDone(this.response);
  final LlmResponse response;
}

/// Fallback streaming for clients that don't stream natively: run the normal
/// completion, emit its text as one delta, then the done event.
Stream<LlmStreamChunk> streamViaComplete(
  Future<LlmResponse> completion,
) async* {
  final response = await completion;
  final text = response.message.blocks
      .whereType<TextBlock>()
      .map((b) => b.text)
      .join('\n');
  if (text.isNotEmpty) yield LlmTextDelta(text);
  yield LlmDone(response);
}

/// Raised when a provider call fails (HTTP error, malformed body, etc.).
class LlmException implements Exception {
  const LlmException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'LlmException: $message'
      : 'LlmException($statusCode): $message';
}
