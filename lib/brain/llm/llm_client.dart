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
