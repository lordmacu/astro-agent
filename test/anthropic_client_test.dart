import 'dart:convert';

import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/llm/providers/anthropic_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

LlmRequest _request({String model = 'claude-sonnet-4-6'}) => LlmRequest(
  model: model,
  system: 'be brief',
  messages: [LlmMessage.text(Role.user, 'weather in Bogota?')],
  tools: const [
    ToolSpec(
      name: 'get_weather',
      description: 'Look up the weather.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'city': {'type': 'string'},
        },
      },
    ),
  ],
);

void main() {
  group('buildMessagesUrl', () {
    test('appends the full path to a bare base', () {
      expect(
        buildMessagesUrl('https://api.anthropic.com'),
        'https://api.anthropic.com/v1/messages',
      );
    });
    test('does not double up an existing /v1', () {
      expect(
        buildMessagesUrl('https://proxy.local/v1'),
        'https://proxy.local/v1/messages',
      );
    });
    test('leaves a full path untouched', () {
      expect(
        buildMessagesUrl('https://proxy.local/v1/messages/'),
        'https://proxy.local/v1/messages',
      );
    });
  });

  group('buildAnthropicBody', () {
    test('system is top-level, tools use input_schema', () {
      final body = buildAnthropicBody(_request());

      expect(body['model'], 'claude-sonnet-4-6');
      expect(body['system'], 'be brief');
      expect(body['max_tokens'], isA<int>());
      expect(body['messages'][0]['role'], 'user');
      expect(body['messages'][0]['content'][0], {
        'type': 'text',
        'text': 'weather in Bogota?',
      });
      expect(body['tools'][0]['name'], 'get_weather');
      expect(body['tools'][0]['input_schema']['type'], 'object');
    });

    test('omits temperature for Opus 4.8 but keeps it for Sonnet', () {
      expect(
        buildAnthropicBody(
          _request(model: 'claude-opus-4-8'),
        ).containsKey('temperature'),
        isFalse,
      );
      expect(
        buildAnthropicBody(
          _request(model: 'claude-sonnet-4-6'),
        ).containsKey('temperature'),
        isTrue,
      );
    });

    test('assistant tool use becomes a tool_use block', () {
      final req = LlmRequest(
        model: 'claude-sonnet-4-6',
        messages: [
          LlmMessage(
            role: Role.assistant,
            blocks: const [
              ToolUseBlock(
                id: 'tu_1',
                name: 'get_weather',
                arguments: {'city': 'Bogota'},
              ),
            ],
          ),
        ],
      );

      final block = buildAnthropicBody(req)['messages'][0]['content'][0];
      expect(block['type'], 'tool_use');
      expect(block['id'], 'tu_1');
      expect(block['name'], 'get_weather');
      expect(block['input'], {'city': 'Bogota'});
    });

    test('tool results ride inside a user tool_result block', () {
      final req = LlmRequest(
        model: 'claude-sonnet-4-6',
        messages: [
          LlmMessage(
            role: Role.tool,
            blocks: const [
              ToolResultBlock(toolUseId: 'tu_1', content: '22C, clear'),
            ],
          ),
        ],
      );

      final msg = buildAnthropicBody(req)['messages'][0];
      expect(msg['role'], 'user');
      expect(msg['content'][0]['type'], 'tool_result');
      expect(msg['content'][0]['tool_use_id'], 'tu_1');
      expect(msg['content'][0]['content'], '22C, clear');
    });
  });

  group('parseAnthropicResponse', () {
    test('text content ends the turn', () {
      final resp = parseAnthropicResponse({
        'content': [
          {'type': 'text', 'text': 'Sunny.'},
        ],
        'stop_reason': 'end_turn',
      });

      expect(resp.stopReason, StopReason.endTurn);
      expect(resp.message.blocks.whereType<TextBlock>().single.text, 'Sunny.');
    });

    test('tool_use content yields a tool use', () {
      final resp = parseAnthropicResponse({
        'content': [
          {
            'type': 'tool_use',
            'id': 'tu_1',
            'name': 'get_weather',
            'input': {'city': 'Bogota'},
          },
        ],
        'stop_reason': 'tool_use',
      });

      expect(resp.stopReason, StopReason.toolUse);
      final call = resp.toolUses.single;
      expect(call.id, 'tu_1');
      expect(call.arguments, {'city': 'Bogota'});
    });
  });

  group('complete (round-trip)', () {
    test('posts to /v1/messages with the api-key headers', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Sunny.'},
            ],
            'stop_reason': 'end_turn',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AnthropicClient(apiKey: 'secret', httpClient: mock);
      final resp = await client.complete(_request());

      expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(captured.headers['x-api-key'], 'secret');
      expect(captured.headers['anthropic-version'], isNotNull);
      expect(resp.message.blocks.whereType<TextBlock>().single.text, 'Sunny.');
    });

    test('a 4xx response throws LlmException', () async {
      final mock = MockClient((req) async => http.Response('nope', 400));
      final client = AnthropicClient(apiKey: 'bad', httpClient: mock);

      expect(
        () => client.complete(_request()),
        throwsA(
          isA<LlmException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });
  });
}
