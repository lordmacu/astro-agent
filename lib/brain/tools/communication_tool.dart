import '../../core/l10n/app_lang.dart';
import '../../core/l10n/strings.dart';
import '../../platform/email_reader.dart';
import '../../platform/notifications_reader.dart';
import 'astro_tool.dart';

/// One tool for the phone's inbound/outbound messages, grouping what were three
/// tools (send email, read email, read notifications) to keep the active tool
/// count low. The action picks the path; every effect is injected, so the tool
/// stays decoupled and testable. Only the send path can be outward-facing, so
/// only it asks for confirmation (and only when SMTP is configured).
class CommunicationTool extends AstroTool {
  CommunicationTool({
    // --- send email ---
    required Future<bool> Function() emailConfigured,
    required Future<bool> Function({
      required String to,
      required String subject,
      required String body,
    })
    sendEmail,
    required Future<bool> Function({
      required String to,
      required String subject,
      required String body,
    })
    composeEmail,
    Future<String?> Function(String query)? resolveEmail,
    // --- read email ---
    required Future<bool> Function() emailCanRead,
    required Future<List<EmailSummary>> Function({required int count})
    readEmail,
    required Future<bool> Function() openMailApp,
    // --- read notifications ---
    required Future<List<NotificationSummary>> Function({required int count})
    readNotifications,
    AppLang Function() lang = _defaultLang,
  }) : _emailConfigured = emailConfigured,
       _sendEmail = sendEmail,
       _composeEmail = composeEmail,
       _resolveEmail = resolveEmail,
       _emailCanRead = emailCanRead,
       _readEmail = readEmail,
       _openMailApp = openMailApp,
       _readNotifications = readNotifications,
       _lang = lang;

  static AppLang _defaultLang() => AppLang.es;

  final AppLang Function() _lang;
  final Future<bool> Function() _emailConfigured;
  final Future<bool> Function({
    required String to,
    required String subject,
    required String body,
  })
  _sendEmail;
  final Future<bool> Function({
    required String to,
    required String subject,
    required String body,
  })
  _composeEmail;
  final Future<String?> Function(String query)? _resolveEmail;
  final Future<bool> Function() _emailCanRead;
  final Future<List<EmailSummary>> Function({required int count}) _readEmail;
  final Future<bool> Function() _openMailApp;
  final Future<List<NotificationSummary>> Function({required int count})
  _readNotifications;

  static const _actions = [
    'enviar_correo',
    'leer_correo',
    'leer_notificaciones',
  ];

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  String get name => 'comunicacion';

  @override
  String get description =>
      'Phone messages. action "enviar_correo" sends an email (to may be an '
      'address OR a contact name to resolve; needs subject and body). '
      '"leer_correo" lists recent inbox emails. "leer_notificaciones" reads the '
      'phone notifications. count = how many for the read actions (default 5).';

  @override
  bool get mutates => true; // the send path is outward-facing

  /// Only the send path (and only when SMTP will really send) needs confirming.
  @override
  Future<bool> requiresConfirmation(Map<String, dynamic> args) async {
    final action = (args['action'] as String?)?.trim().toLowerCase();
    return action == 'enviar_correo' && await _emailConfigured();
  }

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'action': {'type': 'string', 'enum': _actions},
      'to': {
        'type': 'string',
        'description': 'enviar_correo: recipient address or contact name.',
      },
      'subject': {'type': 'string', 'description': 'enviar_correo: subject.'},
      'body': {'type': 'string', 'description': 'enviar_correo: message body.'},
      'count': {
        'type': 'integer',
        'description': 'How many to read (default 5) for the read actions.',
      },
    },
    'required': ['action'],
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final action = (args['action'] as String?)?.trim().toLowerCase() ?? '';
    switch (action) {
      case 'enviar_correo':
        return _sendEmailAction(args);
      case 'leer_correo':
        return _readEmailAction(args);
      case 'leer_notificaciones':
        return _readNotificationsAction(args);
      default:
        return ToolResult.error('unknown action: "$action"');
    }
  }

  Future<ToolResult> _sendEmailAction(Map<String, dynamic> args) async {
    final to = (args['to'] as String?)?.trim() ?? '';
    if (to.isEmpty) return const ToolResult.error('to is empty');
    final subject = (args['subject'] as String?)?.trim() ?? '';
    final body = (args['body'] as String?)?.trim() ?? '';

    if (await _emailConfigured()) {
      final ok = await _sendEmail(to: to, subject: subject, body: body);
      return ok
          ? ToolResult(Strings.emailSent(to, _lang()))
          : ToolResult(Strings.emailSendFailed(_lang()));
    }

    // No SMTP: resolve a spoken contact name to its saved address, then open a
    // pre-filled draft in the phone's mail app (a dictated address is trusted).
    var recipient = to;
    if (_resolveEmail != null && !_emailPattern.hasMatch(to)) {
      final resolved = await _resolveEmail(to);
      if (resolved != null && resolved.trim().isNotEmpty) {
        recipient = resolved.trim();
      }
    }
    final opened = await _composeEmail(
      to: recipient,
      subject: subject,
      body: body,
    );
    return opened
        ? ToolResult(Strings.mailDraftOpened(recipient, _lang()))
        : ToolResult(Strings.cantOpenMail(_lang()));
  }

  Future<ToolResult> _readEmailAction(Map<String, dynamic> args) async {
    if (!await _emailCanRead()) {
      final opened = await _openMailApp();
      return opened
          ? ToolResult(Strings.mailAppOpened(_lang()))
          : ToolResult(Strings.cantOpenMail(_lang()));
    }
    final count = (args['count'] as num?)?.toInt() ?? 5;
    final emails = await _readEmail(count: count);
    if (emails.isEmpty) return ToolResult(Strings.noEmailsFound(_lang()));

    final buffer = StringBuffer();
    for (var i = 0; i < emails.length; i++) {
      final e = emails[i];
      final when = e.date == null ? '' : ' (${_fmtDate(e.date!)})';
      buffer.writeln('${i + 1}. ${e.from} — ${e.subject}$when');
    }
    return ToolResult(buffer.toString().trimRight());
  }

  Future<ToolResult> _readNotificationsAction(Map<String, dynamic> args) async {
    final count = (args['count'] as num?)?.toInt() ?? 5;
    final items = await _readNotifications(count: count);
    if (items.isEmpty) {
      return ToolResult(Strings.noRecentNotifications(_lang()));
    }
    final buffer = StringBuffer();
    for (var i = 0; i < items.length; i++) {
      final n = items[i];
      final body = [
        n.title,
        n.text,
      ].where((s) => s != null && s.isNotEmpty).join(': ');
      buffer.writeln('${i + 1}. ${n.app}${body.isEmpty ? '' : ' — $body'}');
    }
    return ToolResult(buffer.toString().trimRight());
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}
