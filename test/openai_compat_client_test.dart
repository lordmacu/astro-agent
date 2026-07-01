import 'dart:convert';

import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/llm/providers/openai_compat_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

LlmRequest _request() => LlmRequest(
  model: 'deepseek-chat',
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
        'required': ['city'],
      },
    ),
  ],
);

void main() {
  group('buildOpenAiBody', () {
    test('emits system, user, and tool declarations', () {
      final body = buildOpenAiBody(_request());

      expect(body['model'], 'deepseek-chat');
      expect(body['messages'][0], {'role': 'system', 'content': 'be brief'});
      expect(body['messages'][1]['role'], 'user');
      expect(body['messages'][1]['content'], 'weather in Bogota?');
      expect(body['tools'][0]['type'], 'function');
      expect(body['tools'][0]['function']['name'], 'get_weather');
      expect(body['tool_choice'], 'auto');
    });

    test('assistant tool use becomes a tool_calls array', () {
      final req = LlmRequest(
        model: 'm',
        messages: [
          LlmMessage(
            role: Role.assistant,
            blocks: const [
              ToolUseBlock(
                id: 'call_1',
                name: 'get_weather',
                arguments: {'city': 'Bogota'},
              ),
            ],
          ),
        ],
      );

      final assistant = (buildOpenAiBody(req)['messages'] as List).firstWhere(
        (m) => m['role'] == 'assistant',
      );

      expect(assistant['content'], isNull);
      expect(assistant['tool_calls'][0]['id'], 'call_1');
      expect(assistant['tool_calls'][0]['type'], 'function');
      expect(assistant['tool_calls'][0]['function']['name'], 'get_weather');
      expect(jsonDecode(assistant['tool_calls'][0]['function']['arguments']), {
        'city': 'Bogota',
      });
    });

    test('each tool result expands to its own role:tool message', () {
      final req = LlmRequest(
        model: 'm',
        messages: [
          LlmMessage(
            role: Role.tool,
            blocks: const [
              ToolResultBlock(toolUseId: 'call_1', content: '22C, clear'),
              ToolResultBlock(toolUseId: 'call_2', content: 'no rain'),
            ],
          ),
        ],
      );

      final toolMsgs = (buildOpenAiBody(req)['messages'] as List)
          .where((m) => m['role'] == 'tool')
          .toList();

      expect(toolMsgs, hasLength(2));
      expect(toolMsgs[0]['tool_call_id'], 'call_1');
      expect(toolMsgs[0]['content'], '22C, clear');
      expect(toolMsgs[1]['tool_call_id'], 'call_2');
    });
  });

  group('parseOpenAiResponse', () {
    test('plain text reply ends the turn', () {
      final resp = parseOpenAiResponse({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'Sunny.'},
            'finish_reason': 'stop',
          },
        ],
      });

      expect(resp.stopReason, StopReason.endTurn);
      expect(resp.message.blocks.whereType<TextBlock>().single.text, 'Sunny.');
      expect(resp.toolUses, isEmpty);
    });

    test('tool_calls reply yields tool uses with decoded arguments', () {
      final resp = parseOpenAiResponse({
        'choices': [
          {
            'message': {
              'role': 'assistant',
              'content': null,
              'tool_calls': [
                {
                  'id': 'call_1',
                  'type': 'function',
                  'function': {
                    'name': 'get_weather',
                    'arguments': '{"city":"Bogota"}',
                  },
                },
              ],
            },
            'finish_reason': 'tool_calls',
          },
        ],
      });

      expect(resp.stopReason, StopReason.toolUse);
      final call = resp.toolUses.single;
      expect(call.id, 'call_1');
      expect(call.name, 'get_weather');
      expect(call.arguments, {'city': 'Bogota'});
    });

    test('an empty choices list throws', () {
      expect(
        () => parseOpenAiResponse({'choices': []}),
        throwsA(isA<LlmException>()),
      );
    });
  });

  group('complete (round-trip)', () {
    test('posts to /chat/completions and parses the reply', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'Sunny.'},
                'finish_reason': 'stop',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OpenAiCompatClient.deepSeek(
        apiKey: 'secret',
        httpClient: mock,
      );
      final resp = await client.complete(_request());

      expect(
        captured.url.toString(),
        'https://api.deepseek.com/v1/chat/completions',
      );
      expect(captured.headers['authorization'], 'Bearer secret');
      expect(resp.message.blocks.whereType<TextBlock>().single.text, 'Sunny.');
    });

    test(
      'miniMax factory targets the MiniMax base URL with Bearer auth',
      () async {
        late http.Request captured;
        final mock = MockClient((req) async {
          captured = req;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'Listo.'},
                  'finish_reason': 'stop',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = OpenAiCompatClient.miniMax(
          apiKey: 'mm-key',
          httpClient: mock,
        );
        expect(client.providerId, 'minimax');
        await client.complete(_request());

        expect(
          captured.url.toString(),
          'https://api.minimax.io/v1/chat/completions',
        );
        expect(captured.headers['authorization'], 'Bearer mm-key');
        // Latency tuning: thinking off + priority tier.
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['thinking'], {'type': 'disabled'});
        expect(body['service_tier'], 'priority');
      },
    );

    test('a 4xx response throws LlmException', () async {
      final mock = MockClient((req) async => http.Response('nope', 401));
      final client = OpenAiCompatClient.deepSeek(
        apiKey: 'bad',
        httpClient: mock,
      );

      expect(
        () => client.complete(_request()),
        throwsA(
          isA<LlmException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  group('completeStream', () {
    test('parses SSE text deltas and assembles the final response', () async {
      final sse = [
        'data: {"choices":[{"delta":{"content":"Hola"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":" mundo"}}]}\n\n',
        'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\n',
        'data: [DONE]\n\n',
      ].join();
      final mock = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
      });
      final client = OpenAiCompatClient.miniMax(apiKey: 'k', httpClient: mock);

      final chunks = await client.completeStream(_request()).toList();

      final deltas = chunks
          .whereType<LlmTextDelta>()
          .map((c) => c.text)
          .toList();
      expect(deltas, ['Hola', ' mundo']);

      final done = chunks.whereType<LlmDone>().single;
      final text = done.response.message.blocks
          .whereType<TextBlock>()
          .single
          .text;
      expect(text, 'Hola mundo');
      expect(done.response.stopReason, StopReason.endTurn);
    });

    test('assembles streamed tool-call deltas into a ToolUseBlock', () async {
      final sse = [
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1",'
            '"function":{"name":"get_time","arguments":"{}"}}]}}]}\n\n',
        'data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}\n\n',
        'data: [DONE]\n\n',
      ].join();
      final mock = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
      });
      final client = OpenAiCompatClient.miniMax(apiKey: 'k', httpClient: mock);

      final chunks = await client.completeStream(_request()).toList();
      final done = chunks.whereType<LlmDone>().single;
      final call = done.response.toolUses.single;

      expect(call.name, 'get_time');
      expect(call.id, 'call_1');
      expect(done.response.stopReason, StopReason.toolUse);
    });
  });
}
