import 'package:astro/brain/tools/communication_tool.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/platform/email_reader.dart';
import 'package:astro/platform/notifications_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configurable fakes for every injected effect, recording what was called.
class Fakes {
  bool configured = true;
  bool canRead = true;
  bool sendResult = true;
  bool composeResult = true;
  bool openMailResult = true;
  List<EmailSummary> emails = const [];
  List<NotificationSummary> notifs = const [];

  String? sentTo;
  String? composedTo;
  int sends = 0;
  int composes = 0;
  int openMailCalls = 0;

  Future<bool> send({
    required String to,
    required String subject,
    required String body,
  }) async {
    sends++;
    sentTo = to;
    return sendResult;
  }

  Future<bool> compose({
    required String to,
    required String subject,
    required String body,
  }) async {
    composes++;
    composedTo = to;
    return composeResult;
  }

  Future<String?> resolve(String q) async => 'ana@example.com';
  Future<bool> openMail() async {
    openMailCalls++;
    return openMailResult;
  }

  Future<List<EmailSummary>> readEmail({required int count}) async => emails;
  Future<List<NotificationSummary>> readNotifs({required int count}) async =>
      notifs;
}

CommunicationTool _tool(Fakes f, {AppLang Function()? lang}) =>
    CommunicationTool(
      emailConfigured: () async => f.configured,
      sendEmail: f.send,
      composeEmail: f.compose,
      resolveEmail: f.resolve,
      emailCanRead: () async => f.canRead,
      readEmail: f.readEmail,
      openMailApp: f.openMail,
      readNotifications: f.readNotifs,
      lang: lang ?? () => AppLang.es,
    );

void main() {
  group('CommunicationTool', () {
    test('is named comunicacion and mutates', () {
      final tool = _tool(Fakes());
      expect(tool.name, 'comunicacion');
      expect(tool.mutates, isTrue);
    });

    test('only enviar_correo with SMTP needs confirmation', () async {
      final tool = _tool(Fakes()..configured = true);
      expect(
        await tool.requiresConfirmation({'action': 'enviar_correo'}),
        isTrue,
      );
      expect(
        await tool.requiresConfirmation({'action': 'leer_correo'}),
        isFalse,
      );
      final noSmtp = _tool(Fakes()..configured = false);
      expect(
        await noSmtp.requiresConfirmation({'action': 'enviar_correo'}),
        isFalse,
      );
    });

    test('enviar_correo sends when SMTP is configured', () async {
      final f = Fakes()..configured = true;
      final result = await _tool(f).run({
        'action': 'enviar_correo',
        'to': 'ana@example.com',
        'subject': 'Hi',
        'body': 'Hey',
      });
      expect(f.sends, 1);
      expect(f.sentTo, 'ana@example.com');
      expect(result.content, contains('ana@example.com'));
    });

    test('the result language follows the injected AppLang', () async {
      final f = Fakes()..configured = true;
      final result = await _tool(f, lang: () => AppLang.en).run({
        'action': 'enviar_correo',
        'to': 'ana@example.com',
        'subject': 'Hi',
        'body': 'Hey',
      });
      expect(result.content, 'Done, I sent the email to ana@example.com.');
    });

    test(
      'enviar_correo without SMTP resolves a name and opens a draft',
      () async {
        final f = Fakes()..configured = false;
        final result = await _tool(f).run({
          'action': 'enviar_correo',
          'to': 'Ana',
          'subject': 'Hi',
          'body': 'Hey',
        });
        expect(f.sends, 0);
        expect(f.composes, 1);
        expect(f.composedTo, 'ana@example.com'); // resolved from the name
        expect(result.content.toLowerCase(), contains('borrador'));
      },
    );

    test('leer_correo lists emails when IMAP can read', () async {
      final f = Fakes()
        ..canRead = true
        ..emails = const [EmailSummary(from: 'Ana', subject: 'Hola')];
      final result = await _tool(f).run({'action': 'leer_correo'});
      expect(result.content, contains('Ana — Hola'));
    });

    test('leer_correo opens the mail app when IMAP is off', () async {
      final f = Fakes()..canRead = false;
      final result = await _tool(f).run({'action': 'leer_correo'});
      expect(f.openMailCalls, 1);
      expect(result.content.toLowerCase(), contains('correo'));
    });

    test('leer_notificaciones formats app/title/text', () async {
      final f = Fakes()
        ..notifs = const [
          NotificationSummary(app: 'WhatsApp', title: 'Ana', text: '¿Vienes?'),
        ];
      final result = await _tool(f).run({'action': 'leer_notificaciones'});
      expect(result.content, contains('WhatsApp — Ana: ¿Vienes?'));
    });

    test('an unknown action is an error', () async {
      final result = await _tool(Fakes()).run({'action': 'nope'});
      expect(result.isError, isTrue);
    });
  });
}
