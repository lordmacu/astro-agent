import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sanitise.dart';
import '../web_search_provider.dart';
import '../web_search_types.dart';

/// SearXNG provider — GET `{baseUrl}/search?q=...&format=json`. SearXNG is an
/// open-source metasearch engine you self-host; from the app's side it needs no
/// API key, so it's a reliable keyless backend (unlike the DuckDuckGo HTML
/// scraper, which is best-effort). Point [baseUrl] at your instance.
///
/// The instance must allow the JSON output format — add `json` under
/// `search.formats` in its `settings.yml` (the default config often lists only
/// `html`). Otherwise it returns HTTP 403 and this provider throws, letting the
/// fallback chain move on to DuckDuckGo.
class SearxngProvider implements WebSearchProvider {
  SearxngProvider({required String baseUrl, http.Client? httpClient})
    : _base = _normalize(baseUrl),
      _http = httpClient ?? http.Client();

  final String _base;
  final http.Client _http;

  /// Trim trailing slashes so `$base/search` is well-formed for any input.
  static String _normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  @override
  String get id => 'searxng';

  @override
  bool get requiresCredential => false;

  @override
  Future<List<WebSearchHit>> search(WebSearchArgs args) async {
    if (args.query.trim().isEmpty) {
      throw const WebSearchException('query is empty', provider: 'searxng');
    }
    if (_base.isEmpty) {
      throw const WebSearchException('no base url', provider: 'searxng');
    }

    final params = <String, String>{
      'q': args.query,
      'format': 'json',
      'categories': 'general',
      if (args.freshness != null) 'time_range': args.freshness!.name,
      if (args.language != null) 'language': args.language!.trim(),
    };
    final uri = Uri.parse('$_base/search').replace(queryParameters: params);

    final http.Response resp;
    try {
      resp = await _http.get(
        uri,
        headers: const {'accept': 'application/json'},
      );
    } on Object catch (e) {
      throw WebSearchException('transport error: $e', provider: 'searxng');
    }

    if (resp.statusCode >= 400) {
      throw WebSearchException(
        'http error',
        provider: 'searxng',
        statusCode: resp.statusCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    } on Object catch (e) {
      throw WebSearchException('bad json: $e', provider: 'searxng');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const WebSearchException('unexpected body', provider: 'searxng');
    }
    final results = decoded['results'] as List? ?? const [];

    final limit = args.effectiveCount(5);
    final hits = <WebSearchHit>[];
    for (final raw in results) {
      if (hits.length >= limit) break;
      if (raw is! Map<String, dynamic>) continue;
      final url = raw['url'] as String? ?? '';
      final title = raw['title'] as String? ?? '';
      if (url.isEmpty && title.isEmpty) continue;
      hits.add(
        WebSearchHit(
          url: sanitiseForPrompt(url, 2 * 1024),
          title: sanitiseForPrompt(title, 512),
          snippet: sanitiseForPrompt(raw['content'] as String? ?? '', 4 * 1024),
          siteName: hostOf(url),
          publishedAt: raw['publishedDate'] as String?,
        ),
      );
    }
    return hits;
  }
}
