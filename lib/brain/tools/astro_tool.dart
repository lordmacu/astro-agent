import '../llm/llm_message.dart';

/// The result of running a tool, fed back to the model.
class ToolResult {
  const ToolResult(this.content, {this.isError = false});

  const ToolResult.error(String message) : content = message, isError = true;

  final String content;
  final bool isError;
}

/// Contract for a single capability the brain can call. Add a tool by
/// subclassing this and registering it in a `ToolRegistry`. Keep tool
/// descriptions short and clearly distinct, and keep no more than 3-5 active.
abstract class AstroTool {
  /// Stable identifier the model uses to call this tool.
  String get name;

  /// One clear sentence telling the model when to use it.
  String get description;

  /// JSON Schema of the tool input.
  Map<String, dynamic> get inputSchema;

  /// True for tools that change something (clear DTC, brightness, music).
  /// The brain gates these behind a confirmation before running.
  bool get mutates => false;

  /// Whether THIS call needs confirmation before running. Defaults to [mutates]
  /// so existing tools are unchanged; async + per-call so a tool can decide
  /// dynamically (e.g. only when a real outward send will happen).
  Future<bool> requiresConfirmation(Map<String, dynamic> args) async => mutates;

  /// Execute the tool with validated arguments.
  Future<ToolResult> run(Map<String, dynamic> args);

  /// The declaration handed to the model.
  ToolSpec get spec =>
      ToolSpec(name: name, description: description, inputSchema: inputSchema);
}
