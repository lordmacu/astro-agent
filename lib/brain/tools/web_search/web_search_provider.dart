import 'web_search_types.dart';

/// A web-search backend. Each provider (Tavily, Brave, ...) implements this;
/// the `WebSearchTool` only ever talks to this interface. Ported from the
/// nexo-rs `web_search::provider` trait.
abstract interface class WebSearchProvider {
  /// Low-cardinality id for logs ("tavily", "brave").
  String get id;

  /// True when the provider needs an API key to work.
  bool get requiresCredential;

  /// Run a search and return the hits, or throw `WebSearchException`.
  Future<List<WebSearchHit>> search(WebSearchArgs args);
}
