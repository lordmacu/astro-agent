import '../../memory/long_term_memory.dart';
import 'chispa_tool.dart';

/// Lets the brain save a durable fact to long-term memory. The store is
/// injected, keeping the tool decoupled from SQLite. Low-risk write, so it
/// runs without confirmation.
class RememberTool extends ChispaTool {
  RememberTool(this.memory);

  final LongTermMemory memory;

  @override
  String get name => 'remember_fact';

  @override
  String get description =>
      'Save a fact worth keeping across trips: driver preferences, recurring '
      'routes, car quirks, names. Use when the driver shares something durable.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'content': {
            'type': 'string',
            'description': 'The fact to remember, in one sentence.',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Optional labels, e.g. ["preference"].',
          },
          'type': {
            'type': 'string',
            'description': 'Optional category, e.g. "preference", "route".',
          },
        },
        'required': ['content'],
      };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final content = (args['content'] as String?)?.trim() ?? '';
    if (content.isEmpty) return const ToolResult.error('content is empty');

    final tags = (args['tags'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    await memory.remember(content, tags: tags, type: args['type'] as String?);
    return const ToolResult('Saved.');
  }
}

/// Lets the brain look up things Chispa saved earlier. Read-only.
class RecallTool extends ChispaTool {
  RecallTool(this.memory);

  final LongTermMemory memory;

  @override
  String get name => 'recall_memory';

  @override
  String get description =>
      'Look up what Chispa saved before about the driver, the car, or past '
      'trips. Use before answering anything that may depend on past context.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'What to look up.',
          },
          'limit': {
            'type': 'integer',
            'description': 'How many memories to return (default 5).',
          },
        },
        'required': ['query'],
      };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return const ToolResult.error('query is empty');

    final limit = (args['limit'] as num?)?.toInt() ?? 5;
    final hits = await memory.recall(query, limit: limit);
    if (hits.isEmpty) {
      return const ToolResult('Nothing remembered about that.');
    }

    final buffer = StringBuffer();
    for (var i = 0; i < hits.length; i++) {
      buffer.writeln('${i + 1}. ${hits[i].content}');
    }
    return ToolResult(buffer.toString().trimRight());
  }
}
