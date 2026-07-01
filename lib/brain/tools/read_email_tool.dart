import '../../platform/email_reader.dart';
import 'astro_tool.dart';

/// Reads the latest inbox messages (sender, subject, date). Read-only, so it
/// runs without confirmation. The fetch and the "is it configured" check are
/// injected, keeping the tool decoupled from the IMAP stack and testable.
class ReadEmailTool extends AstroTool {
  ReadEmailTool({
    required Future<bool> Function() canRead,
    required Future<List<EmailSummary>> Function({required int count}) fetch,
    required Future<bool> Function() openMailApp,
  }) : _canRead = canRead,
       _fetch = fetch,
       _openMailApp = openMailApp;

  final Future<bool> Function() _canRead;
  final Future<List<EmailSummary>> Function({required int count}) _fetch;
  final Future<bool> Function() _openMailApp;

  @override
  String get name => 'read_email';

  @override
  String get description =>
      'Check the latest emails in the inbox: sender, subject and date. If IMAP is '
      'configured it lists them; otherwise it opens the phone mail app. Use for '
      '"do I have new email", "read my last emails". count = how many to fetch '
      '(default 5).';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'count': {
        'type': 'integer',
        'description': 'How many recent emails to fetch (default 5).',
      },
    },
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    if (!await _canRead()) {
      final opened = await _openMailApp();
      return opened
          ? const ToolResult('Abrí tu app de correo.')
          : const ToolResult('No pude abrir tu app de correo.');
    }

    final count = (args['count'] as num?)?.toInt() ?? 5;
    final emails = await _fetch(count: count);
    if (emails.isEmpty) return const ToolResult('No encontré correos.');

    final buffer = StringBuffer();
    for (var i = 0; i < emails.length; i++) {
      final e = emails[i];
      final when = e.date == null ? '' : ' (${_fmtDate(e.date!)})';
      buffer.writeln('${i + 1}. ${e.from} — ${e.subject}$when');
    }
    return ToolResult(buffer.toString().trimRight());
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
