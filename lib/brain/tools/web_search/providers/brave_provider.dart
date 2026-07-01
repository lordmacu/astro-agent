import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sanitise.dart';
import '../web_search_provider.dart';
import '../web_search_types.dart';

/// Brave Search provider. GET `https://api.search.brave.com/res/v1/web/search`,
/// auth via the `X-Subscription-Token` header. Independent index, ~2000 free
/// queries/month. Ported from nexo-rs `providers::brave`.
class BraveProvider implements WebSearchProvider {
  BraveProvider({
    required this.apiKey,
    this.endpoint = 'https://api.search.brave.com/res/v1/web/search',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String endpoint;
  final http.Client _http;

  @override
  String get id => 'brave';

  @override
  bool get requiresCredential => true;

  @override
  Future<List<WebSearchHit>> search(WebSearchArgs args) async {
    if (args.query.trim().isEmpty) {
      throw const WebSearchException('query is empty', provider: 'brave');
    }

    final params = <String, String>{
      'q': args.query,
      'count': args.effectiveCount(5).toString(),
      if (args.freshness != null) 'freshness': _freshnessParam(args.freshness!),
      if (args.country != null) 'country': args.country!.trim().toUpperCase(),
      if (args.language != null)
        'search_lang': args.language!.trim().toLowerCase(),
    };
    final uri = Uri.parse(endpoint).replace(queryParameters: params);

    final http.Response resp;
    try {
      resp = await _http.get(
        uri,
        headers: {'x-subscription-token': apiKey, 'accept': 'application/json'},
      );
    } on Object catch (e) {
      throw WebSearchException('transport error: $e', provider: 'brave');
    }

    if (resp.statusCode >= 400) {
      throw WebSearchException(
        'http error',
        provider: 'brave',
        statusCode: resp.statusCode,
      );
    }

    final decoded =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final web = decoded['web'] as Map<String, dynamic>?;
    final results = web?['results'] as List? ?? const [];

    return [
      for (final raw in results)
        if (raw is Map<String, dynamic>)
          WebSearchHit(
            url: sanitiseForPrompt(raw['url'] as String? ?? '', 2 * 1024),
            title: sanitiseForPrompt(raw['title'] as String? ?? '', 512),
            snippet: sanitiseForPrompt(
              raw['description'] as String? ?? '',
              4 * 1024,
            ),
            siteName: hostOf(raw['url'] as String? ?? ''),
            publishedAt: raw['page_age'] as String?,
          ),
    ];
  }
}

String _freshnessParam(Freshness f) => switch (f) {
  Freshness.day => 'pd',
  Freshness.week => 'pw',
  Freshness.month => 'pm',
  Freshness.year => 'py',
};
