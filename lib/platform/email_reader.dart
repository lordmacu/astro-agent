import 'package:enough_mail/enough_mail.dart';

import 'smtp_store.dart';

/// One inbox message, trimmed to what Astro reads aloud.
class EmailSummary {
  const EmailSummary({required this.from, required this.subject, this.date});

  final String from;
  final String subject;
  final DateTime? date;
}

/// Reads the latest inbox messages over IMAP with `enough_mail` (pure Dart) for
/// the read_email tool. Best-effort: returns an empty list on incomplete config
/// or any error, so the tool reports a friendly message instead of throwing.
class EmailReader {
  const EmailReader();

  Future<List<EmailSummary>> fetchRecent(
    SmtpConfig config, {
    int count = 5,
  }) async {
    if (!config.canRead) return const [];

    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(
        config.imapHost,
        config.imapPort,
        isSecure: true,
      );
      await client.login(config.username, config.password);
      await client.selectInbox();
      final result = await client.fetchRecentMessages(
        messageCount: count.clamp(1, 20),
        criteria: 'BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)]',
      );

      final out = [
        for (final m in result.messages)
          EmailSummary(
            from: _fromOf(m),
            subject: m.decodeSubject() ?? '(sin asunto)',
            date: m.decodeDate(),
          ),
      ];
      // Newest first.
      out.sort(
        (a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)),
      );
      return out;
    } on Object {
      return const [];
    } finally {
      try {
        await client.logout();
      } on Object {
        // already disconnected — ignore
      }
    }
  }

  String _fromOf(MimeMessage m) {
    final from = m.from;
    if (from != null && from.isNotEmpty) {
      final a = from.first;
      final name = a.personalName;
      return (name != null && name.isNotEmpty) ? name : a.email;
    }
    return m.fromEmail ?? '?';
  }
}
