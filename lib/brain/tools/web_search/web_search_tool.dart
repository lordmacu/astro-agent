import '../chispa_tool.dart';
import 'web_search_provider.dart';
import 'web_search_types.dart';

/// Lets the brain look up fresh, external facts. Read-only, so it runs without
/// confirmation. The provider (Tavily, Brave, ...) is injected, keeping the
/// tool decoupled from any one search API.
class WebSearchTool extends ChispaTool {
  WebSearchTool(this.provider, {this.defaultCount = 5});

  final WebSearchProvider provider;
  final int defaultCount;

  @override
  String get name => 'web_search';

  @override
  String get description =>
      'Search the web for current, factual information Chispa does not already '
      'know: weather, news, places, opening hours, prices. Use only when the '
      'answer needs fresh facts from the internet.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'What to search for.',
          },
          'count': {
            'type': 'integer',
            'description': 'How many results to return (1-10).',
          },
          'freshness': {
            'type': 'string',
            'enum': ['day', 'week', 'month', 'year'],
            'description': 'Restrict to recent results.',
          },
        },
        'required': ['query'],
      };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final searchArgs = WebSearchArgs.fromJson(args);
    if (searchArgs.query.isEmpty) {
      return const ToolResult.error('query is empty');
    }

    final List<WebSearchHit> hits;
    try {
      hits = await provider.search(searchArgs);
    } on WebSearchException catch (e) {
      return ToolResult.error('search failed: ${e.message}');
    }

    if (hits.isEmpty) {
      return const ToolResult('No results found.');
    }
    return ToolResult(_format(hits, searchArgs.effectiveCount(defaultCount)));
  }

  /// Render hits as compact, model-friendly text.
  String _format(List<WebSearchHit> hits, int limit) {
    final buffer = StringBuffer();
    final shown = hits.take(limit).toList();
    for (var i = 0; i < shown.length; i++) {
      final h = shown[i];
      final site = h.siteName == null ? '' : ' — ${h.siteName}';
      buffer.writeln('${i + 1}. ${h.title}$site');
      buffer.writeln(h.url);
      if (h.snippet.isNotEmpty) buffer.writeln(h.snippet);
      if (i != shown.length - 1) buffer.writeln();
    }
    return buffer.toString().trimRight();
  }
}
