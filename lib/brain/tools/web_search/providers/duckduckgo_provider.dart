import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sanitise.dart';
import '../web_search_provider.dart';
import '../web_search_types.dart';

/// DuckDuckGo HTML-endpoint scraper — GET `https://html.duckduckgo.com/html/?q=`.
/// Needs no API key, so it works as a universal, always-available fallback when
/// a keyed provider is missing, down, or returns nothing. Parses the lite HTML
/// result blocks and decodes DuckDuckGo's `/l/?uddg=` redirect links. Ported
/// from the SlimePet `WebTools.search` scraper.
class DuckDuckGoProvider implements WebSearchProvider {
  DuckDuckGoProvider({
    this.endpoint = 'https://html.duckduckgo.com/html/',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String endpoint;
  final http.Client _http;

  /// A desktop-browser UA — the HTML endpoint serves an empty page to obvious
  /// bots.
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15';

  static final _titleRe = RegExp(
    r'class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
    dotAll: true,
    caseSensitive: false,
  );
  static final _snippetRe = RegExp(
    r'class="result__snippet"[^>]*>(.*?)</a>',
    dotAll: true,
    caseSensitive: false,
  );
  static final _tagRe = RegExp(r'<[^>]+>');

  @override
  String get id => 'duckduckgo';

  @override
  bool get requiresCredential => false;

  @override
  Future<List<WebSearchHit>> search(WebSearchArgs args) async {
    if (args.query.trim().isEmpty) {
      throw const WebSearchException('query is empty', provider: 'duckduckgo');
    }

    final params = <String, String>{
      'q': args.query,
      if (args.freshness != null) 'df': _freshnessParam(args.freshness!),
      if (args.country != null) 'kl': args.country!.trim().toLowerCase(),
    };
    final uri = Uri.parse(endpoint).replace(queryParameters: params);

    final http.Response resp;
    try {
      resp = await _http.get(uri, headers: const {'user-agent': _userAgent});
    } on Object catch (e) {
      throw WebSearchException('transport error: $e', provider: 'duckduckgo');
    }

    if (resp.statusCode >= 400) {
      throw WebSearchException(
        'http error',
        provider: 'duckduckgo',
        statusCode: resp.statusCode,
      );
    }

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    final titles = _titleRe.allMatches(html).toList();
    final snippets = _snippetRe.allMatches(html).toList();

    final limit = args.effectiveCount(5);
    final hits = <WebSearchHit>[];
    for (var i = 0; i < titles.length && hits.length < limit; i++) {
      final url = _decodeDdgLink(titles[i].group(1) ?? '');
      final title = _stripHtml(titles[i].group(2) ?? '');
      final snippet = i < snippets.length
          ? _stripHtml(snippets[i].group(1) ?? '')
          : '';
      if (url.isEmpty && title.isEmpty) continue;
      hits.add(
        WebSearchHit(
          url: sanitiseForPrompt(url, 2 * 1024),
          title: sanitiseForPrompt(title, 512),
          snippet: sanitiseForPrompt(snippet, 4 * 1024),
          siteName: hostOf(url),
        ),
      );
    }
    return hits;
  }

  /// DuckDuckGo wraps outbound links as `//duckduckgo.com/l/?uddg=<encoded>&...`.
  /// Pull out and percent-decode the real target; otherwise normalise a
  /// protocol-relative URL.
  String _decodeDdgLink(String href) {
    final marker = href.indexOf('uddg=');
    if (marker != -1) {
      final after = href.substring(marker + 'uddg='.length);
      final enc = after.split('&').first;
      try {
        return Uri.decodeComponent(enc);
      } on Object {
        return href;
      }
    }
    return href.startsWith('//') ? 'https:$href' : href;
  }

  /// Strip HTML tags (DDG bolds query terms with `<b>`) and decode the handful
  /// of entities the endpoint emits. `sanitiseForPrompt` collapses the
  /// remaining whitespace afterwards.
  String _stripHtml(String input) {
    var text = input.replaceAll(_tagRe, ' ');
    const entities = {
      '&amp;': '&',
      '&quot;': '"',
      '&#x27;': "'",
      '&#39;': "'",
      '&lt;': '<',
      '&gt;': '>',
      '&nbsp;': ' ',
    };
    entities.forEach((from, to) => text = text.replaceAll(from, to));
    return text;
  }

  String _freshnessParam(Freshness f) => switch (f) {
    Freshness.day => 'd',
    Freshness.week => 'w',
    Freshness.month => 'm',
    Freshness.year => 'y',
  };
}
