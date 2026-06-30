import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_client.dart';
import '../llm_message.dart';

/// Default Anthropic Messages API version header.
const String _defaultApiVersion = '2023-06-01';

/// Anthropic Messages API client. Ported from the nexo-rs `llm::anthropic`
/// adapter, trimmed to chat with tool use (no prompt caching, streaming, or
/// subscription/Claude-Code spoofing). Auth is plain `x-api-key`.
class AnthropicClient implements LlmClient {
  AnthropicClient({
    required this.apiKey,
    this.baseUrl = 'https://api.anthropic.com',
    this.apiVersion = _defaultApiVersion,
    this.extraHeaders = const {},
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final String apiVersion;
  final Map<String, String> extraHeaders;

  @override
  final String providerId = 'anthropic';

  final http.Client _http;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final uri = Uri.parse(buildMessagesUrl(baseUrl));
    final headers = <String, String>{
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': apiVersion,
      ...extraHeaders,
    };

    final http.Response resp;
    try {
      resp = await _http.post(
        uri,
        headers: headers,
        body: jsonEncode(buildAnthropicBody(request)),
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
    return parseAnthropicResponse(decoded);
  }
}

/// Build the `/v1/messages` URL from an operator-supplied base, tolerating a
/// base that already carries `/v1` or the full path so we never land at
/// `/v1/v1/messages`.
String buildMessagesUrl(String baseUrl) {
  final trimmed =
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  if (trimmed.endsWith('/v1/messages')) return trimmed;
  if (trimmed.endsWith('/v1')) return '$trimmed/messages';
  return '$trimmed/v1/messages';
}

/// Build the Anthropic request body from a neutral `LlmRequest`. Pure function
/// so it can be unit-tested without a network call.
Map<String, dynamic> buildAnthropicBody(LlmRequest req) {
  final messages = <Map<String, dynamic>>[];

  for (final msg in req.messages) {
    switch (msg.role) {
      case Role.system:
        // Folded into the top-level `system` below; skip here.
        break;
      case Role.user:
        messages.add({'role': 'user', 'content': _userBlocks(msg)});
      case Role.assistant:
        messages.add({'role': 'assistant', 'content': _assistantBlocks(msg)});
      case Role.tool:
        // Tool results ride inside a user message as tool_result blocks.
        messages.add({
          'role': 'user',
          'content': [
            for (final b in msg.blocks.whereType<ToolResultBlock>())
              {
                'type': 'tool_result',
                'tool_use_id': b.toolUseId,
                'content': b.content,
                if (b.isError) 'is_error': true,
              },
          ],
        });
    }
  }

  final body = <String, dynamic>{
    'model': req.model,
    'max_tokens': req.maxTokens,
    'messages': messages,
    // temperature was deprecated starting with Opus 4.7; sending it 400s.
    if (_supportsTemperature(req.model)) 'temperature': req.temperature,
  };

  // System: fold the request system prompt and any role:system messages.
  final systemParts = <String>[
    if (req.system != null) req.system!,
    for (final m in req.messages)
      if (m.role == Role.system) _joinText(m.blocks),
  ]..removeWhere((s) => s.isEmpty);
  if (systemParts.isNotEmpty) {
    body['system'] = systemParts.join('\n\n');
  }

  if (req.tools.isNotEmpty) {
    body['tools'] = [
      for (final t in req.tools)
        {
          'name': t.name,
          'description': t.description,
          'input_schema': _ensureObjectSchema(t.inputSchema),
        },
    ];
    // tool_choice "auto" is Anthropic's default, so it is left implicit.
  }

  return body;
}

/// Parse an Anthropic Messages response into a neutral `LlmResponse`.
LlmResponse parseAnthropicResponse(Map<String, dynamic> json) {
  final content = json['content'] as List? ?? const [];

  final blocks = <ContentBlock>[];
  for (final raw in content) {
    final block = raw as Map<String, dynamic>;
    switch (block['type']) {
      case 'text':
        final text = block['text'] as String? ?? '';
        if (text.isNotEmpty) blocks.add(TextBlock(text));
      case 'tool_use':
        blocks.add(ToolUseBlock(
          id: block['id'] as String,
          name: block['name'] as String,
          arguments: (block['input'] as Map?)?.cast<String, dynamic>() ?? {},
        ));
      default:
        break;
    }
  }

  final stopReason = switch (json['stop_reason']) {
    'end_turn' || 'stop_sequence' => StopReason.endTurn,
    'tool_use' => StopReason.toolUse,
    'max_tokens' => StopReason.maxTokens,
    _ => StopReason.endTurn,
  };

  return LlmResponse(
    message: LlmMessage(role: Role.assistant, blocks: blocks),
    stopReason: stopReason,
  );
}

List<Map<String, dynamic>> _userBlocks(LlmMessage msg) {
  final text = _joinText(msg.blocks);
  if (text.isEmpty) {
    // Anthropic requires at least one content block.
    return [
      {'type': 'text', 'text': '(no content)'},
    ];
  }
  return [
    {'type': 'text', 'text': text},
  ];
}

List<Map<String, dynamic>> _assistantBlocks(LlmMessage msg) {
  final blocks = <Map<String, dynamic>>[];
  final text = _joinText(msg.blocks);
  if (text.isNotEmpty) {
    blocks.add({'type': 'text', 'text': text});
  }
  for (final t in msg.blocks.whereType<ToolUseBlock>()) {
    blocks.add({
      'type': 'tool_use',
      'id': t.id,
      'name': t.name,
      'input': t.arguments,
    });
  }
  if (blocks.isEmpty) {
    blocks.add({'type': 'text', 'text': ''});
  }
  return blocks;
}

String _joinText(List<ContentBlock> blocks) =>
    blocks.whereType<TextBlock>().map((b) => b.text).join('\n');

bool _supportsTemperature(String model) =>
    !(model.startsWith('claude-opus-4-7') ||
        model.startsWith('claude-opus-4-8'));

Map<String, dynamic> _ensureObjectSchema(Map<String, dynamic> schema) {
  if (schema.isEmpty) return {'type': 'object'};
  if (!schema.containsKey('type')) {
    return {'type': 'object', ...schema};
  }
  return schema;
}
