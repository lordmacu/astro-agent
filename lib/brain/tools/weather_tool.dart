import '../../core/l10n/app_lang.dart';
import '../../core/l10n/strings.dart';
import 'astro_tool.dart';

/// Tells the current weather for a place (temperature + conditions). Read-only.
/// The lookup is injected, keeping the tool decoupled and testable; an empty
/// place lets the wiring fall back to the current location.
class WeatherTool extends AstroTool {
  WeatherTool({
    required Future<String?> Function(String place) fetch,
    AppLang Function() lang = _defaultLang,
  }) : _fetch = fetch,
       _lang = lang;

  static AppLang _defaultLang() => AppLang.es;

  final Future<String?> Function(String place) _fetch;
  final AppLang Function() _lang;

  @override
  String get name => 'clima';

  @override
  String get description =>
      'Get the current weather (temperature and conditions) for a place. Leave '
      'place empty for the current location. Use for "what\'s the weather", '
      '"is it going to rain", "how hot is it in X".';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'place': {
        'type': 'string',
        'description': 'City or place; empty = current location.',
      },
    },
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final place = (args['place'] as String?)?.trim() ?? '';
    final summary = await _fetch(place);
    return summary == null
        ? ToolResult(Strings.weatherUnavailable(_lang()))
        : ToolResult(summary);
  }
}
