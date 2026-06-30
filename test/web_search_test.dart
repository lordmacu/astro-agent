import 'dart:convert';

import 'package:chispa/brain/chispa_brain.dart';
import 'package:chispa/brain/llm/llm_client.dart';
import 'package:chispa/brain/llm/llm_message.dart';
import 'package:chispa/brain/tools/tool_registry.dart';
import 'package:chispa/brain/tools/web_search/providers/brave_provider.dart';
import 'package:chispa/brain/tools/web_search/providers/tavily_provider.dart';
import 'package:chispa/brain/tools/web_search/sanitise.dart';
import 'package:chispa/brain/tools/web_search/web_search_provider.dart';
import 'package:chispa/brain/tools/web_search/web_search_tool.dart';
import 'package:chispa/brain/tools/web_search/web_search_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Returns a fixed hit list, ignoring the query. For tool/brain tests.
class FakeProvider implements WebSearchProvider {
  FakeProvider(this.hits);
  final List<WebSearchHit> hits;
  WebSearchArgs? lastArgs;

  @override
  String get id => 'fake';
  @override
  bool get requiresCredential => false;
  @override
  Future<List<WebSearchHit>> search(WebSearchArgs args) async {
    lastArgs = args;
    return hits;
  }
}

class FakeLlmClient implements LlmClient {
  FakeLlmClient(this._script);
  final List<LlmResponse> _script;
  int _turn = 0;

  @override
  String get providerId => 'fake';
  @override
  Future<LlmResponse> complete(LlmRequest request) async => _script[_turn++];
}

void main() {
  group('sanitiseForPrompt', () {
    test('collapses whitespace and strips control chars', () {
      expect(sanitiseForPrompt('  hello\n\tworld  ', 1024), 'hello world');
    });

    test('caps to the byte budget', () {
      expect(sanitiseForPrompt('abcdef', 3), 'abc');
    });
  });

  test('hostOf extracts the domain', () {
    expect(hostOf('https://example.com/path?q=1'), 'example.com');
    expect(hostOf(''), isNull);
  });

  group('TavilyProvider', () {
    test('posts query + api_key and maps results to hits', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'results': [
              {
                'url': 'https://weather.com/bogota',
                'title': 'Bogota weather',
                'content': 'Sunny, 19C.',
                'published_date': '2026-06-30',
              },
            ],
          }),
          200,
        );
      });

      final provider =
          TavilyProvider(apiKey: 'tvly-key', httpClient: mock);
      final hits = await provider.search(
          const WebSearchArgs(query: 'weather bogota', count: 3));

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(captured.url.toString(), 'https://api.tavily.com/search');
      expect(body['api_key'], 'tvly-key');
      expect(body['query'], 'weather bogota');
      expect(body['max_results'], 3);
      expect(hits.single.url, 'https://weather.com/bogota');
      expect(hits.single.snippet, 'Sunny, 19C.');
      expect(hits.single.siteName, 'weather.com');
    });

    test('a 4xx throws WebSearchException', () async {
      final mock = MockClient((_) async => http.Response('no', 401));
      final provider = TavilyProvider(apiKey: 'bad', httpClient: mock);
      expect(
        () => provider.search(const WebSearchArgs(query: 'x')),
        throwsA(isA<WebSearchException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('BraveProvider', () {
    test('sends the subscription token and parses web.results', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'web': {
              'results': [
                {
                  'url': 'https://brave.example/1',
                  'title': 'Result one',
                  'description': 'A snippet.',
                  'page_age': '2026-06-29',
                },
              ],
            },
          }),
          200,
        );
      });

      final provider = BraveProvider(apiKey: 'brave-key', httpClient: mock);
      final hits = await provider
          .search(const WebSearchArgs(query: 'news', count: 2));

      expect(captured.url.path, '/res/v1/web/search');
      expect(captured.url.queryParameters['q'], 'news');
      expect(captured.url.queryParameters['count'], '2');
      expect(captured.headers['x-subscription-token'], 'brave-key');
      expect(hits.single.title, 'Result one');
      expect(hits.single.publishedAt, '2026-06-29');
    });

    test('missing web key yields no hits', () async {
      final mock = MockClient((_) async => http.Response('{}', 200));
      final provider = BraveProvider(apiKey: 'k', httpClient: mock);
      expect(await provider.search(const WebSearchArgs(query: 'x')), isEmpty);
    });
  });

  group('WebSearchTool', () {
    test('is read-only and declares a query parameter', () {
      final tool = WebSearchTool(FakeProvider(const []));
      expect(tool.name, 'web_search');
      expect(tool.mutates, isFalse);
      expect(tool.inputSchema['required'], ['query']);
    });

    test('empty query is an error result, not a throw', () async {
      final tool = WebSearchTool(FakeProvider(const []));
      final result = await tool.run({'query': '   '});
      expect(result.isError, isTrue);
    });

    test('formats hits into model-friendly text', () async {
      final tool = WebSearchTool(FakeProvider(const [
        WebSearchHit(
          url: 'https://a.com',
          title: 'Alpha',
          snippet: 'first',
          siteName: 'a.com',
        ),
      ]));
      final result = await tool.run({'query': 'alpha'});
      expect(result.isError, isFalse);
      expect(result.content, contains('Alpha'));
      expect(result.content, contains('https://a.com'));
    });
  });

  test('end-to-end: brain calls web_search then answers', () async {
    final provider = FakeProvider(const [
      WebSearchHit(
        url: 'https://weather.com/bogota',
        title: 'Bogota weather',
        snippet: 'Sunny, 19C.',
        siteName: 'weather.com',
      ),
    ]);
    final registry = ToolRegistry()..register(WebSearchTool(provider));

    final brain = ChispaBrain(
      client: FakeLlmClient([
        LlmResponse(
          message: LlmMessage(role: Role.assistant, blocks: const [
            ToolUseBlock(
              id: 'call_1',
              name: 'web_search',
              arguments: {'query': 'weather in Bogota'},
            ),
          ]),
          stopReason: StopReason.toolUse,
        ),
        LlmResponse(
          message: LlmMessage.text(Role.assistant, 'It is sunny in Bogota.'),
          stopReason: StopReason.endTurn,
        ),
      ]),
      registry: registry,
    );

    final answer = await brain.ask('How is the weather?', model: 'm');

    expect(provider.lastArgs?.query, 'weather in Bogota');
    expect(answer, 'It is sunny in Bogota.');
  });
}
