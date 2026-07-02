import '../../core/l10n/app_lang.dart';
import '../../core/l10n/strings.dart';
import 'astro_tool.dart';

/// Maps in one tool: navigate to a place, or find places nearby. Grouping
/// navigation and nearby-search keeps the active tool count low. Both effects
/// are injected (Google Maps intents), so the tool stays decoupled and testable.
class MapTool extends AstroTool {
  MapTool({
    required Future<bool> Function(String destination) navigate,
    required Future<bool> Function(String query) nearby,
    AppLang Function() lang = _defaultLang,
  }) : _navigate = navigate,
       _nearby = nearby,
       _lang = lang;

  static AppLang _defaultLang() => AppLang.es;

  final Future<bool> Function(String destination) _navigate;
  final Future<bool> Function(String query) _nearby;
  final AppLang Function() _lang;

  static const _actions = ['navigate', 'nearby'];

  @override
  String get name => 'mapa';

  @override
  String get description =>
      'Maps. action "navigate" starts turn-by-turn to destination ("take me to '
      'X", "navigate home"). action "nearby" searches query near the current '
      'location (gas stations, ATMs, cafés, pharmacies). Opens the maps app.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'action': {'type': 'string', 'enum': _actions},
      'destination': {
        'type': 'string',
        'description': 'For navigate: where to go (address, place, "casa").',
      },
      'query': {
        'type': 'string',
        'description': 'For nearby: what to look for, e.g. "gasolinera".',
      },
    },
    'required': ['action'],
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final action = (args['action'] as String?)?.trim().toLowerCase() ?? '';
    switch (action) {
      case 'navigate':
        final dest = (args['destination'] as String?)?.trim() ?? '';
        if (dest.isEmpty) return const ToolResult.error('destination is empty');
        return await _navigate(dest)
            ? ToolResult(Strings.navigatingTo(dest, _lang()))
            : ToolResult(Strings.cantOpenMap(_lang()));
      case 'nearby':
        final query = (args['query'] as String?)?.trim() ?? '';
        if (query.isEmpty) return const ToolResult.error('query is empty');
        return await _nearby(query)
            ? ToolResult(Strings.showingNearby(query, _lang()))
            : ToolResult(Strings.cantOpenMap(_lang()));
      default:
        return ToolResult.error('unknown action: "$action"');
    }
  }
}
