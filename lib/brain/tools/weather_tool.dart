import 'astro_tool.dart';

/// Tells the current weather for a place (temperature + conditions). Read-only.
/// The lookup is injected, keeping the tool decoupled and testable; an empty
/// place lets the wiring fall back to the current location.
class WeatherTool extends AstroTool {
  WeatherTool({required Future<String?> Function(String place) fetch})
    : _fetch = fetch;

  final Future<String?> Function(String place) _fetch;

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
        ? const ToolResult('No pude consultar el clima ahora.')
        : ToolResult(summary);
  }
}
