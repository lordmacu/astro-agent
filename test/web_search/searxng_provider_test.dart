import 'dart:convert';

import 'package:astro/brain/tools/web_search/providers/searxng_provider.dart';
import 'package:astro/brain/tools/web_search/web_search_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SearxngProvider', () {
    test('is keyless and named searxng', () {
      final p = SearxngProvider(baseUrl: 'https://s.example.com');
      expect(p.id, 'searxng');
      expect(p.requiresCredential, isFalse);
    });

    test('parses JSON results into hits', () async {
      late Uri seen;
      final client = MockClient((req) async {
        seen = req.url;
        return http.Response(
          jsonEncode({
            'results': [
              {
                'url': 'https://a.com/x',
                'title': 'A title',
                'content': 'A snippet',
                'publishedDate': '2026-01-02',
              },
              {'url': 'https://b.com', 'title': 'B', 'content': 'b'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final hits =
          await SearxngProvider(
            baseUrl: 'https://s.example.com/',
            httpClient: client,
          ).search(
            const WebSearchArgs(query: 'astro cars', freshness: Freshness.week),
          );

      // Trailing slash normalized; JSON format + time_range forwarded.
      expect(seen.path, '/search');
      expect(seen.queryParameters['q'], 'astro cars');
      expect(seen.queryParameters['format'], 'json');
      expect(seen.queryParameters['time_range'], 'week');

      expect(hits, hasLength(2));
      expect(hits.first.url, 'https://a.com/x');
      expect(hits.first.title, 'A title');
      expect(hits.first.snippet, 'A snippet');
      expect(hits.first.siteName, 'a.com');
      expect(hits.first.publishedAt, '2026-01-02');
    });

    test('honors the requested count', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'results': List.generate(
              8,
              (i) => {'url': 'https://x.com/$i', 'title': 't$i', 'content': ''},
            ),
          }),
          200,
        );
      });
      final hits = await SearxngProvider(
        baseUrl: 'https://s.example.com',
        httpClient: client,
      ).search(const WebSearchArgs(query: 'q', count: 3));
      expect(hits, hasLength(3));
    });

    test('an empty query throws', () async {
      expect(
        () => SearxngProvider(
          baseUrl: 'https://s.example.com',
        ).search(const WebSearchArgs(query: '   ')),
        throwsA(isA<WebSearchException>()),
      );
    });

    test('an HTTP error throws (so the fallback chain moves on)', () async {
      final client = MockClient((_) async => http.Response('nope', 403));
      expect(
        () => SearxngProvider(
          baseUrl: 'https://s.example.com',
          httpClient: client,
        ).search(const WebSearchArgs(query: 'q')),
        throwsA(isA<WebSearchException>()),
      );
    });
  });
}
