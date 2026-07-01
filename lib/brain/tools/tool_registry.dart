import 'dart:developer' as developer;

import '../llm/llm_message.dart';
import 'astro_tool.dart';

/// Central registry of the tools available to the brain. Adding a tool is just
/// `register(MyTool())`. The model's tool-selection accuracy drops sharply past
/// a handful of tools, so this warns when more than five are active — group
/// them or split into topic agents instead.
class ToolRegistry {
  ToolRegistry({this.softLimit = 5});

  final int softLimit;
  final Map<String, AstroTool> _tools = {};

  void register(AstroTool tool) {
    _tools[tool.name] = tool;
    if (_tools.length > softLimit) {
      developer.log(
        'Active tools (${_tools.length}) exceed the soft limit of $softLimit; '
        'tool-selection accuracy degrades. Group or split into agents.',
        name: 'ToolRegistry',
      );
    }
  }

  AstroTool? byName(String name) => _tools[name];

  /// Remove a tool by name (e.g. one the driver disabled in Settings). No-op if
  /// it was never registered.
  void unregister(String name) => _tools.remove(name);

  /// The names of the currently registered tools.
  Iterable<String> get names => _tools.keys;

  /// The tool declarations handed to the model on every request.
  List<ToolSpec> specs() => [for (final t in _tools.values) t.spec];

  int get length => _tools.length;
}
