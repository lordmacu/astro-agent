import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_client.dart';
import '../llm_message.dart';

/// OpenAI-compatible chat client. One adapter covers OpenAI itself, DeepSeek,
/// local Ollama, and any gateway that speaks the `/chat/completions` shape.
/// Ported from the nexo-rs `llm::openai_compat` adapter, trimmed to chat with
/// tool use (no streaming, embeddings, vision, or cost tracking yet).
class OpenAiCompatClient implements LlmClient {
  OpenAiCompatClient({
    required this.baseUrl,
    this.apiKey,
    this.providerId = 'openai-compat',
    this.extraHeaders = const {},
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// DeepSeek cloud. Models: "deepseek-chat", "deepseek-reasoner".
  factory OpenAiCompatClient.deepSeek({
    required String apiKey,
    http.Client? httpClient,
  }) =>
      OpenAiCompatClient(
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: apiKey,
        providerId: 'deepseek',
        httpClient: httpClient,
      );

  /// OpenAI cloud.
  factory OpenAiCompatClient.openAi({
    required String apiKey,
    http.Client? httpClient,
  }) =>
      OpenAiCompatClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: apiKey,
        providerId: 'openai',
        httpClient: httpClient,
      );

  /// Base URL up to and including `/v1` (no trailing `/chat/completions`).
  final String baseUrl;
  final String? apiKey;
  @override
  final String providerId;
  final Map<String, String> extraHeaders;

  final http.Client _http;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final headers = <String, String>{
      'content-type': 'application/json',
      if (apiKey != null) 'authorization': 'Bearer $apiKey',
      ...extraHeaders,
    };

    final http.Response resp;
    try {
      resp = await _http.post(
        uri,
        headers: headers,
        body: jsonEncode(buildOpenAiBody(request)),
      );
    } on Object catch (e) {
      throw LlmException('request to $providerId failed: $e');
    }

    if (resp.statusCode >= 400) {
      throw LlmException(
        'provider $providerId returned an error: ${resp.body}',
        statusCode: resp.statusCode,
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } on Object catch (e) {
      throw LlmException('could not parse $providerId response: $e');
    }
    return parseOpenAiResponse(decoded);
  }
}

/// Build the OpenAI-compatible request body from a neutral `LlmRequest`.
/// Pure function so it can be unit-tested without a network call.
Map<String, dynamic> buildOpenAiBody(LlmRequest req) {
  final messages = <Map<String, dynamic>>[];

  if (req.system != null) {
    messages.add({'role': 'system', 'content': req.system});
  }

  for (final msg in req.messages) {
    switch (msg.role) {
      case Role.tool:
        // OpenAI expects one message per tool result, correlated by id.
        for (final block in msg.blocks.whereType<ToolResultBlock>()) {
          messages.add({
            'role': 'tool',
            'tool_call_id': block.toolUseId,
            'content': block.content,
          });
        }
      case Role.assistant:
        final toolUses = msg.blocks.whereType<ToolUseBlock>().toList();
        final text = _joinText(msg.blocks);
        if (toolUses.isNotEmpty) {
          messages.add({
            'role': 'assistant',
            'content': text.isEmpty ? null : text,
            'tool_calls': [
              for (final t in toolUses)
                {
                  'id': t.id,
                  'type': 'function',
                  'function': {
                    'name': t.name,
                    'arguments': jsonEncode(t.arguments),
                  },
                },
            ],
          });
        } else {
          messages.add({'role': 'assistant', 'content': text});
        }
      case Role.user:
        messages.add({'role': 'user', 'content': _joinText(msg.blocks)});
      case Role.system:
        messages.add({'role': 'system', 'content': _joinText(msg.blocks)});
    }
  }

  final body = <String, dynamic>{
    'model': req.model,
    'messages': messages,
    'max_tokens': req.maxTokens,
    'temperature': req.temperature,
  };

  if (req.tools.isNotEmpty) {
    body['tools'] = [
      for (final t in req.tools)
        {
          'type': 'function',
          'function': {
            'name': t.name,
            'description': t.description,
            'parameters': _ensureObjectSchema(t.inputSchema),
          },
        },
    ];
    body['tool_choice'] = 'auto';
  }

  return body;
}

/// Parse an OpenAI-compatible chat response into a neutral `LlmResponse`.
LlmResponse parseOpenAiResponse(Map<String, dynamic> json) {
  final choices = json['choices'] as List? ?? const [];
  if (choices.isEmpty) {
    throw const LlmException('response contained no choices');
  }

  final choice = choices.first as Map<String, dynamic>;
  final message = choice['message'] as Map<String, dynamic>? ?? const {};

  final blocks = <ContentBlock>[];
  final content = message['content'];
  if (content is String && content.isNotEmpty) {
    blocks.add(TextBlock(content));
  }
  for (final raw in message['tool_calls'] as List? ?? const []) {
    final call = raw as Map<String, dynamic>;
    final fn = call['function'] as Map<String, dynamic>;
    blocks.add(ToolUseBlock(
      id: call['id'] as String,
      name: fn['name'] as String,
      arguments: _decodeArguments(fn['arguments']),
    ));
  }

  final stopReason = switch (choice['finish_reason']) {
    'stop' => StopReason.endTurn,
    'tool_calls' => StopReason.toolUse,
    'length' => StopReason.maxTokens,
    _ => StopReason.endTurn,
  };

  return LlmResponse(
    message: LlmMessage(role: Role.assistant, blocks: blocks),
    stopReason: stopReason,
  );
}

String _joinText(List<ContentBlock> blocks) =>
    blocks.whereType<TextBlock>().map((b) => b.text).join('\n');

/// JSON Schema must be an object with a `type`; some tools omit it.
Map<String, dynamic> _ensureObjectSchema(Map<String, dynamic> schema) {
  if (schema.isEmpty) return {'type': 'object'};
  if (!schema.containsKey('type')) {
    return {'type': 'object', ...schema};
  }
  return schema;
}

/// Tool-call arguments come back as a JSON string (OpenAI) or, on some
/// gateways, an already-decoded object. Accept both.
Map<String, dynamic> _decodeArguments(Object? arguments) {
  if (arguments is Map<String, dynamic>) return arguments;
  if (arguments is String) {
    if (arguments.isEmpty) return {};
    final decoded = jsonDecode(arguments);
    if (decoded is Map<String, dynamic>) return decoded;
  }
  return {};
}
