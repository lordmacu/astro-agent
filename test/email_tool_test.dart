import 'package:astro/brain/astro_brain.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/tools/email_tool.dart';
import 'package:astro/brain/tools/tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the tool asked to send and returns a scripted result.
class FakeSender {
  FakeSender({this.result = true});
  final bool result;
  int calls = 0;
  String? to;
  String? subject;
  String? body;

  Future<bool> send({
    required String to,
    required String subject,
    required String body,
  }) async {
    calls++;
    this.to = to;
    this.subject = subject;
    this.body = body;
    return result;
  }
}

/// Records the draft the tool asked to open.
class FakeComposer {
  FakeComposer({this.result = true});
  final bool result;
  int calls = 0;
  String? to;
  String? subject;
  String? body;

  Future<bool> compose({
    required String to,
    required String subject,
    required String body,
  }) async {
    calls++;
    this.to = to;
    this.subject = subject;
    this.body = body;
    return result;
  }
}

class FakeLlmClient implements LlmClient {
  FakeLlmClient(this._script);
  final List<LlmResponse> _script;
  int _turn = 0;

  @override
  String get providerId => 'fake';
  @override
  Future<LlmResponse> complete(LlmRequest request) async => _script[_turn++];
  @override
  Stream<LlmStreamChunk> completeStream(LlmRequest request) =>
      streamViaComplete(complete(request));
}

EmailTool _tool(
  FakeSender sender, {
  bool configured = true,
  FakeComposer? composer,
}) => EmailTool(
  isConfigured: () async => configured,
  send: sender.send,
  composeViaIntent: (composer ?? FakeComposer()).compose,
);

void main() {
  group('EmailTool', () {
    test('is mutating (needs confirmation) and named send_email', () {
      expect(_tool(FakeSender()).name, 'send_email');
      expect(_tool(FakeSender()).mutates, isTrue);
    });

    test('with no SMTP: opens a draft via intent instead of sending', () async {
      final sender = FakeSender();
      final composer = FakeComposer();
      final result = await _tool(
        sender,
        configured: false,
        composer: composer,
      ).run({'to': 'a@b.com', 'subject': 'Hi', 'body': 'Hey'});
      expect(sender.calls, 0); // never SMTP-sent
      expect(composer.calls, 1);
      expect(composer.to, 'a@b.com');
      expect(composer.subject, 'Hi');
      expect(composer.body, 'Hey');
      expect(result.isError, isFalse);
      expect(result.content.toLowerCase(), contains('correo'));
    });

    test('requiresConfirmation only when SMTP is configured', () async {
      expect(
        await _tool(
          FakeSender(),
          configured: true,
        ).requiresConfirmation(const {}),
        isTrue,
      );
      expect(
        await _tool(
          FakeSender(),
          configured: false,
        ).requiresConfirmation(const {}),
        isFalse,
      );
    });

    test('passes to/subject/body through on send', () async {
      final sender = FakeSender();
      final result = await _tool(sender).run({
        'to': 'ana@example.com',
        'subject': 'Reunión',
        'body': 'Nos vemos a las 3.',
      });
      expect(sender.to, 'ana@example.com');
      expect(sender.subject, 'Reunión');
      expect(sender.body, 'Nos vemos a las 3.');
      expect(result.isError, isFalse);
      expect(result.content, contains('ana@example.com'));
    });

    test('an empty recipient is an error, not a send', () async {
      final sender = FakeSender();
      final result = await _tool(
        sender,
      ).run({'to': '   ', 'subject': 'x', 'body': 'y'});
      expect(result.isError, isTrue);
      expect(sender.calls, 0);
    });

    test('a send failure reports it', () async {
      final result = await _tool(
        FakeSender(result: false),
      ).run({'to': 'a@b.com', 'subject': 'x', 'body': 'y'});
      expect(result.content.toLowerCase(), contains('no pude'));
    });
  });

  test('end-to-end: brain confirms, then sends the email', () async {
    final sender = FakeSender();
    final registry = ToolRegistry()..register(_tool(sender));
    var confirmed = 0;

    final brain = AstroBrain(
      client: FakeLlmClient([
        LlmResponse(
          message: LlmMessage(
            role: Role.assistant,
            blocks: const [
              ToolUseBlock(
                id: 'call_1',
                name: 'send_email',
                arguments: {
                  'to': 'ana@example.com',
                  'subject': 'Hola',
                  'body': 'Test',
                },
              ),
            ],
          ),
          stopReason: StopReason.toolUse,
        ),
        LlmResponse(
          message: LlmMessage.text(Role.assistant, 'Listo, lo envié.'),
          stopReason: StopReason.endTurn,
        ),
      ]),
      registry: registry,
      confirm: (tool, args) async {
        confirmed++;
        return true;
      },
    );

    final answer = await brain.ask('mándale un correo a Ana', model: 'm');

    expect(confirmed, 1); // mutating tool went through confirmation
    expect(sender.calls, 1);
    expect(sender.to, 'ana@example.com');
    expect(answer, 'Listo, lo envié.');
  });

  test('end-to-end: a denied confirmation does not send', () async {
    final sender = FakeSender();
    final registry = ToolRegistry()..register(_tool(sender));

    final brain = AstroBrain(
      client: FakeLlmClient([
        LlmResponse(
          message: LlmMessage(
            role: Role.assistant,
            blocks: const [
              ToolUseBlock(
                id: 'call_1',
                name: 'send_email',
                arguments: {'to': 'a@b.com', 'subject': 'x', 'body': 'y'},
              ),
            ],
          ),
          stopReason: StopReason.toolUse,
        ),
        LlmResponse(
          message: LlmMessage.text(Role.assistant, 'Bueno, no lo mando.'),
          stopReason: StopReason.endTurn,
        ),
      ]),
      registry: registry,
      confirm: (_, __) async => false,
    );

    await brain.ask('mándale un correo', model: 'm');
    expect(sender.calls, 0); // denied → never sent
  });
}
