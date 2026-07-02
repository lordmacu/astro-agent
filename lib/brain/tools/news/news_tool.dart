import '../../../core/l10n/app_lang.dart';
import '../../../core/l10n/strings.dart';
import '../astro_tool.dart';
import 'google_news_provider.dart';

/// Gives today's actual news headlines (real stories with sources), so the
/// brain can summarize the relevant ones instead of telling the driver where to
/// look. Read-only. The fetch is injected, keeping the tool decoupled and
/// testable.
class NewsTool extends AstroTool {
  NewsTool({
    required Future<List<NewsHeadline>> Function(String? query, AppLang lang)
    fetch,
    AppLang Function() lang = _defaultLang,
    this.summaryLimit = 4,
  }) : _fetch = fetch,
       _lang = lang;

  static AppLang _defaultLang() => AppLang.es;

  final Future<List<NewsHeadline>> Function(String? query, AppLang lang) _fetch;
  final AppLang Function() _lang;

  /// How many headlines to put in the MODEL payload (the on-screen panel still
  /// shows every fetched headline). Keeps the summary short so Astro starts
  /// speaking sooner.
  final int summaryLimit;

  @override
  String get name => 'noticias';

  @override
  String get description =>
      "Get today's real news headlines (actual stories with their source), not "
      'just where to find news. Use for "what\'s the news", "noticias de hoy", '
      'or news about a topic. Put a topic in query, or leave it empty for the '
      'top headlines.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': 'Topic to get news about; empty = top headlines.',
      },
    },
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim();
    final List<NewsHeadline> items;
    try {
      items = await _fetch(query, _lang());
    } on Object {
      return ToolResult(Strings.newsUnavailable(_lang()));
    }
    if (items.isEmpty) return ToolResult(Strings.newsUnavailable(_lang()));

    // Keep the model payload lean so the context doesn't balloon: title plus
    // its source (so the model can attribute a story), with long headlines
    // trimmed. The on-screen panel shows the links. Enough to summarize aloud.
    final forModel = items.take(summaryLimit).toList();
    final buffer = StringBuffer();
    for (var i = 0; i < forModel.length; i++) {
      final title = forModel[i].title.trim();
      final short = title.length > 90 ? '${title.substring(0, 89)}…' : title;
      final source = forModel[i].source.trim();
      buffer.writeln(
        source.isEmpty ? '${i + 1}. $short' : '${i + 1}. $short — $source',
      );
    }
    return ToolResult(buffer.toString().trimRight());
  }
}
