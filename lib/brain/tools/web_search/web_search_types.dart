/// Input/output types for web search. Ported from the nexo-rs `web-search`
/// crate. The shape stays stable across providers; each provider translates
/// these into its own API.
library;

/// Time-window filter understood by providers that expose one.
enum Freshness { day, week, month, year }

/// Arguments the model passes when calling `web_search`. The common case is
/// just `{"query": "..."}`.
class WebSearchArgs {
  const WebSearchArgs({
    required this.query,
    this.count,
    this.freshness,
    this.country,
    this.language,
  });

  final String query;
  final int? count;
  final Freshness? freshness;
  final String? country;
  final String? language;

  /// The request count, clamped to [1, 10]. Out-of-range values are pulled
  /// into range rather than erroring — the model occasionally emits count: 25.
  int effectiveCount(int fallback) => (count ?? fallback).clamp(1, 10);

  factory WebSearchArgs.fromJson(Map<String, dynamic> json) => WebSearchArgs(
    query: (json['query'] as String?)?.trim() ?? '',
    count: (json['count'] as num?)?.toInt(),
    freshness: parseFreshness(json['freshness']),
    country: json['country'] as String?,
    language: json['language'] as String?,
  );
}

/// A single search result.
class WebSearchHit {
  const WebSearchHit({
    required this.url,
    required this.title,
    required this.snippet,
    this.siteName,
    this.publishedAt,
  });

  final String url;
  final String title;
  final String snippet;
  final String? siteName;
  final String? publishedAt;
}

/// Raised when a provider call fails.
class WebSearchException implements Exception {
  const WebSearchException(this.message, {this.provider, this.statusCode});

  final String message;
  final String? provider;
  final int? statusCode;

  @override
  String toString() =>
      'WebSearchException'
      '${provider == null ? '' : '($provider)'}: $message'
      '${statusCode == null ? '' : ' [http $statusCode]'}';
}

/// Parse a freshness value from model JSON, ignoring anything unrecognised.
Freshness? parseFreshness(Object? value) {
  if (value is! String) return null;
  return switch (value.toLowerCase()) {
    'day' => Freshness.day,
    'week' => Freshness.week,
    'month' => Freshness.month,
    'year' => Freshness.year,
    _ => null,
  };
}
