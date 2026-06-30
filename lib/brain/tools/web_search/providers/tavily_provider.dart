import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sanitise.dart';
import '../web_search_provider.dart';
import '../web_search_types.dart';

/// Tavily provider — POST `https://api.tavily.com/search`, JSON body. Returns
/// LLM-ready hits in one call. Recommended starting provider (free tier ~1000
/// searches/month). Ported from nexo-rs `providers::tavily`.
class TavilyProvider implements WebSearchProvider {
  TavilyProvider({
    required this.apiKey,
    this.endpoint = 'https://api.tavily.com/search',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String endpoint;
  final http.Client _http;

  @override
  String get id => 'tavily';

  @override
  bool get requiresCredential => true;

  @override
  Future<List<WebSearchHit>> search(WebSearchArgs args) async {
    if (args.query.trim().isEmpty) {
      throw const WebSearchException('query is empty', provider: 'tavily');
    }

    final payload = <String, dynamic>{
      'api_key': apiKey,
      'query': args.query,
      'max_results': args.effectiveCount(5),
      if (args.freshness != null) 'time_range': args.freshness!.name,
    };

    final http.Response resp;
    try {
      resp = await _http.post(
        Uri.parse(endpoint),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode(payload),
      );
    } on Object catch (e) {
      throw WebSearchException('transport error: $e', provider: 'tavily');
    }

    if (resp.statusCode >= 400) {
      throw WebSearchException('http error',
          provider: 'tavily', statusCode: resp.statusCode);
    }

    final decoded =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final results = decoded['results'] as List? ?? const [];

    return [
      for (final raw in results)
        if (raw is Map<String, dynamic>)
          WebSearchHit(
            url: sanitiseForPrompt(raw['url'] as String? ?? '', 2 * 1024),
            title: sanitiseForPrompt(raw['title'] as String? ?? '', 512),
            snippet:
                sanitiseForPrompt(raw['content'] as String? ?? '', 4 * 1024),
            siteName: hostOf(raw['url'] as String? ?? ''),
            publishedAt: raw['published_date'] as String?,
          ),
    ];
  }
}
