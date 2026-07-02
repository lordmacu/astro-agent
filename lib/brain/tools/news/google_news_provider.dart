import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/l10n/app_lang.dart';

/// One news headline from Google News RSS.
class NewsHeadline {
  const NewsHeadline({
    required this.title,
    required this.source,
    required this.url,
  });

  final String title;
  final String source;
  final String url;
}

/// Thrown when the news feed can't be fetched.
class NewsException implements Exception {
  const NewsException(this.message);
  final String message;
  @override
  String toString() => 'NewsException: $message';
}

/// Real today's headlines from **Google News RSS** — keyless. Unlike a generic
/// web search (which returns newspaper homepages for "today's news"), this
/// returns actual stories with their source, so the brain can summarize the
/// relevant ones instead of pointing the driver to news sites.
///
/// Empty query → the region's top headlines; a query → news about that topic.
class GoogleNewsProvider {
  GoogleNewsProvider({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

  Future<List<NewsHeadline>> headlines({
    String? query,
    required AppLang lang,
    int? limit, // null = all the feed returns
  }) async {
    final (hl, gl, ceid) = _locale(lang);
    final q = (query ?? '').trim();
    final base = q.isEmpty
        ? Uri.parse('https://news.google.com/rss')
        : Uri.parse('https://news.google.com/rss/search');
    final uri = base.replace(
      queryParameters: {
        if (q.isNotEmpty) 'q': q,
        'hl': hl,
        'gl': gl,
        'ceid': ceid,
      },
    );

    final http.Response resp;
    try {
      resp = await _http.get(uri, headers: const {'user-agent': _userAgent});
    } on Object catch (e) {
      throw NewsException('transport error: $e');
    }
    if (resp.statusCode >= 400) {
      throw NewsException('http error ${resp.statusCode}');
    }
    return parseGoogleNewsRss(
      utf8.decode(resp.bodyBytes, allowMalformed: true),
      limit: limit,
    );
  }

  /// Google News localization: (hl, gl, ceid).
  (String, String, String) _locale(AppLang lang) => switch (lang) {
    AppLang.es => ('es-419', 'CO', 'CO:es'),
    AppLang.en => ('en-US', 'US', 'US:en'),
  };
}

/// Shared Google News client (one HTTP client) for the news tool and the news
/// panel, so both hit the same source.
final googleNewsProvider = Provider<GoogleNewsProvider>(
  (_) => GoogleNewsProvider(),
);

/// The headlines from the most recent `noticias` tool run, published so the UI
/// can pop the clickable news panel with the same list the brain just spoke
/// about. Null until a news query runs; reset to null after the panel opens.
final latestNewsProvider = StateProvider<List<NewsHeadline>?>((_) => null);

/// Parse a Google News RSS document into headlines. Pure, so it can be
/// unit-tested without a network call. Google News titles end with
/// " - <source>"; the source is dropped from the title (it is returned
/// separately) to give the model clean text.
List<NewsHeadline> parseGoogleNewsRss(String xml, {int? limit}) {
  final items = RegExp(r'<item>(.*?)</item>', dotAll: true).allMatches(xml);
  final out = <NewsHeadline>[];
  for (final m in items) {
    if (limit != null && out.length >= limit) break;
    final block = m.group(1) ?? '';
    final title = _tag(block, 'title');
    if (title.isEmpty) continue;
    final source = _tag(block, 'source');
    final url = _tag(block, 'link');
    var clean = title;
    if (source.isNotEmpty && clean.endsWith(' - $source')) {
      clean = clean.substring(0, clean.length - source.length - 3).trimRight();
    }
    out.add(NewsHeadline(title: clean, source: source, url: url));
  }
  return out;
}

/// Inner text of the first `<tag ...>...</tag>` in [block], decoded to plain
/// text (CDATA, tags and the common entities stripped).
String _tag(String block, String tag) {
  final m = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true).firstMatch(block);
  return m == null ? '' : _decode(m.group(1) ?? '');
}

String _decode(String raw) {
  var t = raw.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '');
  t = t.replaceAll(RegExp(r'<[^>]+>'), ' ');
  const entities = {
    '&amp;': '&',
    '&quot;': '"',
    '&#39;': "'",
    '&#x27;': "'",
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&nbsp;': ' ',
  };
  entities.forEach((from, to) => t = t.replaceAll(from, to));
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}
