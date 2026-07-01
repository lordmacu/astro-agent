import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sanitise.dart';
import '../web_search_provider.dart';
import '../web_search_types.dart';

/// MiniMax native web search — POST `https://api.minimax.io/v1/coding_plan/search`
/// with `{"q": query}` and a Bearer key, returning the `organic[]` results as
/// LLM-ready hits. Only meaningful when the brain's LLM is MiniMax, since the
/// search credential is the same MiniMax API key. Ported from the SlimePet
/// `AnthropicBackend.webSearch` native path; pair it with a keyless fallback
/// (see `FallbackSearchProvider` + `DuckDuckGoProvider`) so an outage or an
/// empty result still yields something.
class MiniMaxSearchProvider implements WebSearchProvider {
  MiniMaxSearchProvider({
    required this.apiKey,
    this.endpoint = 'https://api.minimax.io/v1/coding_plan/search',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String endpoint;
  final http.Client _http;

  @override
  String get id => 'minimax';

  @override
  bool get requiresCredential => true;

  @override
  Future<List<WebSearchHit>> search(WebSearchArgs args) async {
    if (args.query.trim().isEmpty) {
      throw const WebSearchException('query is empty', provider: 'minimax');
    }

    final http.Response resp;
    try {
      resp = await _http.post(
        Uri.parse(endpoint),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({'q': args.query}),
      );
    } on Object catch (e) {
      throw WebSearchException('transport error: $e', provider: 'minimax');
    }

    if (resp.statusCode >= 400) {
      throw WebSearchException(
        'http error',
        provider: 'minimax',
        statusCode: resp.statusCode,
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } on Object catch (e) {
      throw WebSearchException('invalid JSON: $e', provider: 'minimax');
    }

    final results = decoded['organic'] as List? ?? const [];
    return [
      for (final raw in results)
        if (raw is Map<String, dynamic>)
          WebSearchHit(
            url: sanitiseForPrompt(raw['link'] as String? ?? '', 2 * 1024),
            title: sanitiseForPrompt(raw['title'] as String? ?? '', 512),
            snippet: sanitiseForPrompt(
              raw['snippet'] as String? ?? '',
              4 * 1024,
            ),
            siteName: hostOf(raw['link'] as String? ?? ''),
            publishedAt: raw['date'] as String?,
          ),
    ];
  }
}
