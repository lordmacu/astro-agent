import '../web_search_provider.dart';
import '../web_search_types.dart';

/// Runs an ordered list of providers and returns the first non-empty result.
/// A provider that throws or finds nothing is skipped and the next is tried.
/// The chain only fails when *every* provider throws — if at least one
/// succeeded but found nothing, an empty list is returned so the tool reports
/// "No results" instead of an error. Lets us wire "MiniMax native → DuckDuckGo"
/// as a single `WebSearchProvider`.
class FallbackSearchProvider implements WebSearchProvider {
  FallbackSearchProvider(this.providers)
    : assert(providers.isNotEmpty, 'need at least one provider');

  final List<WebSearchProvider> providers;

  @override
  String get id => 'fallback(${providers.map((p) => p.id).join('>')})';

  /// Only credential-bound if every leg needs a key; a keyless leg (DuckDuckGo)
  /// makes the whole chain usable without credentials.
  @override
  bool get requiresCredential => providers.every((p) => p.requiresCredential);

  @override
  Future<List<WebSearchHit>> search(WebSearchArgs args) async {
    WebSearchException? lastError;
    var anySucceeded = false;
    for (final provider in providers) {
      try {
        final hits = await provider.search(args);
        anySucceeded = true;
        if (hits.isNotEmpty) return hits;
      } on WebSearchException catch (e) {
        lastError = e;
      }
    }
    if (!anySucceeded && lastError != null) throw lastError;
    return const [];
  }
}
