import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

import 'smtp_store.dart';

/// Sends email over SMTP with the `mailer` package (pure Dart). Best-effort:
/// returns false on incomplete config or any send error, so the tool reports a
/// friendly failure instead of throwing.
class EmailSender {
  const EmailSender();

  Future<bool> send({
    required SmtpConfig config,
    required String to,
    required String subject,
    required String body,
  }) async {
    if (!config.isComplete || to.trim().isEmpty) return false;

    final server = SmtpServer(
      config.host,
      port: config.port,
      username: config.username,
      password: config.password,
      ssl: config.port == 465, // 465 = implicit TLS; 587 = STARTTLS
    );

    final message = mailer.Message()
      ..from = mailer.Address(
        config.username,
        config.fromName.isEmpty ? 'Astro' : config.fromName,
      )
      ..recipients.add(to.trim())
      ..subject = subject
      ..text = body;

    try {
      await mailer.send(message, server);
      return true;
    } on mailer.MailerException {
      return false;
    } on Object {
      return false;
    }
  }
}
