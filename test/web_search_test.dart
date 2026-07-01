import 'dart:convert';

import 'package:astro/brain/astro_brain.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/tools/tool_registry.dart';
import 'package:astro/brain/tools/web_search/providers/brave_provider.dart';
import 'package:astro/brain/tools/web_search/providers/duckduckgo_provider.dart';
import 'package:astro/brain/tools/web_search/providers/fallback_provider.dart';
import 'package:astro/brain/tools/web_search/providers/minimax_provider.dart';
import 'package:astro/brain/tools/web_search/providers/tavily_provider.dart';
import 'package:astro/brain/tools/web_search/sanitise.dart';
import 'package:astro/brain/tools/web_search/web_search_provider.dart';
import 'package:astro/brain/tools/web_search/web_search_tool.dart';
import 'package:astro/brain/tools/web_search/web_search_types.dart';
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

/// A provider that returns a fixed list or throws, and counts its calls. For
/// exercising the fallback chain.
class ScriptedProvider implements WebSearchProvider {
  ScriptedProvider(this.id, {this.hits = const [], this.error});
  @override
  final String id;
  final List<WebSearchHit> hits;
  final WebSearchException? error;
  int calls = 0;

  @override
  bool get requiresCredential => error == null && hits.isEmpty ? false : true;
  @override
  Future<List<WebSearchHit>> search(WebSearchArgs args) async {
    calls++;
    if (error != null) throw error!;
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
  @override
  Stream<LlmStreamChunk> completeStream(LlmRequest request) =>
      streamViaComplete(complete(request));
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

      final provider = TavilyProvider(apiKey: 'tvly-key', httpClient: mock);
      final hits = await provider.search(
        const WebSearchArgs(query: 'weather bogota', count: 3),
      );

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
        throwsA(
          isA<WebSearchException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
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
      final hits = await provider.search(
        const WebSearchArgs(query: 'news', count: 2),
      );

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

  group('MiniMaxSearchProvider', () {
    test('posts {q} with a Bearer key and maps organic to hits', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'organic': [
              {
                'title': 'Bogota weather',
                'snippet': 'Sunny, 19C.',
                'link': 'https://weather.com/bogota',
                'date': '2026-06-30',
              },
            ],
          }),
          200,
        );
      });

      final provider = MiniMaxSearchProvider(
        apiKey: 'mm-key',
        httpClient: mock,
      );
      final hits = await provider.search(
        const WebSearchArgs(query: 'weather bogota'),
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(
        captured.url.toString(),
        'https://api.minimax.io/v1/coding_plan/search',
      );
      expect(captured.headers['authorization'], 'Bearer mm-key');
      expect(body, {'q': 'weather bogota'});
      expect(hits.single.url, 'https://weather.com/bogota');
      expect(hits.single.title, 'Bogota weather');
      expect(hits.single.snippet, 'Sunny, 19C.');
      expect(hits.single.siteName, 'weather.com');
      expect(hits.single.publishedAt, '2026-06-30');
    });

    test('a 4xx throws WebSearchException with the status', () async {
      final mock = MockClient((_) async => http.Response('nope', 429));
      final provider = MiniMaxSearchProvider(apiKey: 'k', httpClient: mock);
      expect(
        () => provider.search(const WebSearchArgs(query: 'x')),
        throwsA(
          isA<WebSearchException>().having(
            (e) => e.statusCode,
            'statusCode',
            429,
          ),
        ),
      );
    });

    test('a body without organic yields no hits', () async {
      final mock = MockClient((_) async => http.Response('{}', 200));
      final provider = MiniMaxSearchProvider(apiKey: 'k', httpClient: mock);
      expect(await provider.search(const WebSearchArgs(query: 'x')), isEmpty);
    });
  });

  group('DuckDuckGoProvider', () {
    const html = '''
      <div class="result">
        <a rel="nofollow" class="result__a"
           href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fpage&rut=z">
           Example <b>Title</b></a>
        <a class="result__snippet"
           href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fpage">
           A <b>snippet</b> here.</a>
      </div>''';

    test('scrapes results, decodes uddg links and strips tags', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(html, 200);
      });
      final provider = DuckDuckGoProvider(httpClient: mock);
      final hits = await provider.search(const WebSearchArgs(query: 'example'));

      expect(captured.url.host, 'html.duckduckgo.com');
      expect(captured.url.queryParameters['q'], 'example');
      expect(captured.headers['user-agent'], contains('Mozilla/5.0'));
      expect(hits.single.url, 'https://example.com/page');
      expect(hits.single.title, 'Example Title');
      expect(hits.single.snippet, 'A snippet here.');
      expect(hits.single.siteName, 'example.com');
    });

    test('passes a freshness window as df', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response('', 200);
      });
      await DuckDuckGoProvider(
        httpClient: mock,
      ).search(const WebSearchArgs(query: 'x', freshness: Freshness.week));
      expect(captured.url.queryParameters['df'], 'w');
    });

    test('an empty page yields no hits (no throw)', () async {
      final mock = MockClient((_) async => http.Response('<html></html>', 200));
      final provider = DuckDuckGoProvider(httpClient: mock);
      expect(await provider.search(const WebSearchArgs(query: 'x')), isEmpty);
    });
  });

  group('FallbackSearchProvider', () {
    final oneHit = [
      const WebSearchHit(url: 'https://a.com', title: 'A', snippet: 's'),
    ];

    test('returns the first non-empty result and skips the rest', () async {
      final first = ScriptedProvider('first', hits: oneHit);
      final second = ScriptedProvider('second', hits: oneHit);
      final chain = FallbackSearchProvider([first, second]);

      final hits = await chain.search(const WebSearchArgs(query: 'x'));
      expect(hits, oneHit);
      expect(first.calls, 1);
      expect(second.calls, 0);
    });

    test('falls through when the first throws', () async {
      final first = ScriptedProvider(
        'first',
        error: const WebSearchException('down', provider: 'first'),
      );
      final second = ScriptedProvider('second', hits: oneHit);
      final chain = FallbackSearchProvider([first, second]);

      expect(await chain.search(const WebSearchArgs(query: 'x')), oneHit);
      expect(first.calls, 1);
      expect(second.calls, 1);
    });

    test('falls through when the first returns empty', () async {
      final first = ScriptedProvider('first');
      final second = ScriptedProvider('second', hits: oneHit);
      final chain = FallbackSearchProvider([first, second]);

      expect(await chain.search(const WebSearchArgs(query: 'x')), oneHit);
      expect(second.calls, 1);
    });

    test(
      'empty (not error) when a leg succeeded but all found nothing',
      () async {
        final first = ScriptedProvider(
          'first',
          error: const WebSearchException('down', provider: 'first'),
        );
        final second = ScriptedProvider('second'); // succeeds, empty
        final chain = FallbackSearchProvider([first, second]);

        expect(await chain.search(const WebSearchArgs(query: 'x')), isEmpty);
      },
    );

    test('rethrows the last error when every leg throws', () async {
      final first = ScriptedProvider(
        'first',
        error: const WebSearchException('a', provider: 'first'),
      );
      final second = ScriptedProvider(
        'second',
        error: const WebSearchException('b', provider: 'second'),
      );
      final chain = FallbackSearchProvider([first, second]);

      expect(
        () => chain.search(const WebSearchArgs(query: 'x')),
        throwsA(
          isA<WebSearchException>().having(
            (e) => e.provider,
            'provider',
            'second',
          ),
        ),
      );
    });

    test('is keyless when any leg is keyless', () {
      final chain = FallbackSearchProvider([
        MiniMaxSearchProvider(apiKey: 'k'),
        DuckDuckGoProvider(),
      ]);
      expect(chain.requiresCredential, isFalse);
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
      final tool = WebSearchTool(
        FakeProvider(const [
          WebSearchHit(
            url: 'https://a.com',
            title: 'Alpha',
            snippet: 'first',
            siteName: 'a.com',
          ),
        ]),
      );
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

    final brain = AstroBrain(
      client: FakeLlmClient([
        LlmResponse(
          message: LlmMessage(
            role: Role.assistant,
            blocks: const [
              ToolUseBlock(
                id: 'call_1',
                name: 'web_search',
                arguments: {'query': 'weather in Bogota'},
              ),
            ],
          ),
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
