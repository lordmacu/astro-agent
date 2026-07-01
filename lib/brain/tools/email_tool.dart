import 'astro_tool.dart';

/// Sends an email. When SMTP is configured it sends directly (mutating:
/// confirmed by voice before running). When SMTP is not configured it opens a
/// pre-filled draft in the phone's mail app via a mailto intent (no
/// confirmation needed because nothing is sent automatically).
class EmailTool extends AstroTool {
  EmailTool({
    required Future<bool> Function() isConfigured,
    required Future<bool> Function({
      required String to,
      required String subject,
      required String body,
    })
    send,
    required Future<bool> Function({
      required String to,
      required String subject,
      required String body,
    })
    composeViaIntent,
  }) : _isConfigured = isConfigured,
       _send = send,
       _composeViaIntent = composeViaIntent;

  final Future<bool> Function() _isConfigured;
  final Future<bool> Function({
    required String to,
    required String subject,
    required String body,
  })
  _send;
  final Future<bool> Function({
    required String to,
    required String subject,
    required String body,
  })
  _composeViaIntent;

  @override
  String get name => 'send_email';

  @override
  String get description =>
      'Send an email. Needs to (recipient address), subject and body. If SMTP is '
      'configured it sends directly; otherwise it opens a pre-filled draft in the '
      'phone mail app. Use when the driver asks to email someone.';

  @override
  bool get mutates => true; // outward-facing → confirmed before sending when SMTP

  @override
  Future<bool> requiresConfirmation(Map<String, dynamic> args) =>
      _isConfigured();

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'to': {'type': 'string', 'description': 'Recipient email address.'},
      'subject': {'type': 'string', 'description': 'Subject line.'},
      'body': {'type': 'string', 'description': 'Message body.'},
    },
    'required': ['to', 'subject', 'body'],
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final to = (args['to'] as String?)?.trim() ?? '';
    if (to.isEmpty) return const ToolResult.error('to is empty');
    final subject = (args['subject'] as String?)?.trim() ?? '';
    final body = (args['body'] as String?)?.trim() ?? '';

    if (await _isConfigured()) {
      final ok = await _send(to: to, subject: subject, body: body);
      return ok
          ? ToolResult('Listo, envié el correo a $to.')
          : const ToolResult('No pude enviar el correo.');
    }

    // No SMTP: open a pre-filled draft in the phone's mail app.
    final opened = await _composeViaIntent(
      to: to,
      subject: subject,
      body: body,
    );
    return opened
        ? ToolResult('Abrí tu app de correo con el borrador para $to.')
        : const ToolResult('No pude abrir tu app de correo.');
  }
}
