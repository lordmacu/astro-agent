import 'astro_tool.dart';

/// Creates an event / reminder in the phone calendar. Low-risk on explicit
/// request, so it runs without confirmation. The creation is injected as a
/// function, keeping the tool decoupled from the calendar stack and testable.
class CalendarTool extends AstroTool {
  CalendarTool({
    required Future<bool> Function({
      required String title,
      required DateTime start,
      required Duration duration,
      required Duration reminder,
    })
    createEvent,
  }) : _createEvent = createEvent;

  final Future<bool> Function({
    required String title,
    required DateTime start,
    required Duration duration,
    required Duration reminder,
  })
  _createEvent;

  @override
  String get name => 'calendar';

  @override
  String get description =>
      'Create an event or reminder in the phone calendar. Needs title and start '
      '(ISO-8601 local datetime, e.g. 2026-07-02T18:30). Resolve relative times '
      '("mañana a las 6") from get_context first. Optional duration_minutes '
      '(default 60) and reminder_minutes before it (default 10, 0 = none).';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'description': 'Event title.'},
      'start': {
        'type': 'string',
        'description': 'ISO-8601 local start, e.g. 2026-07-02T18:30.',
      },
      'duration_minutes': {
        'type': 'integer',
        'description': 'Length in minutes (default 60).',
      },
      'reminder_minutes': {
        'type': 'integer',
        'description': 'Minutes before to remind (default 10, 0 = none).',
      },
    },
    'required': ['title', 'start'],
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final title = (args['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return const ToolResult.error('title is empty');

    final start = DateTime.tryParse((args['start'] as String?)?.trim() ?? '');
    if (start == null) {
      return const ToolResult.error('invalid start (need ISO-8601 datetime)');
    }

    final duration = Duration(
      minutes: (args['duration_minutes'] as num?)?.toInt() ?? 60,
    );
    final reminder = Duration(
      minutes: (args['reminder_minutes'] as num?)?.toInt() ?? 10,
    );

    final ok = await _createEvent(
      title: title,
      start: start,
      duration: duration,
      reminder: reminder,
    );
    return ok
        ? ToolResult('Listo, agendé "$title".')
        : const ToolResult('No pude crear el evento en el calendario.');
  }
}
