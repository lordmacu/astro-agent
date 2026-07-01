import 'package:astro/brain/astro_brain.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/tools/read_email_tool.dart';
import 'package:astro/brain/tools/tool_registry.dart';
import 'package:astro/platform/email_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records whether the tool asked to open the mail app.
class FakeMailOpener {
  FakeMailOpener({this.result = true});
  final bool result;
  int calls = 0;
  Future<bool> open() async {
    calls++;
    return result;
  }
}

/// Returns a scripted inbox and records the requested count.
class FakeFetcher {
  FakeFetcher(this.emails);
  final List<EmailSummary> emails;
  int calls = 0;
  int? lastCount;

  Future<List<EmailSummary>> fetch({required int count}) async {
    calls++;
    lastCount = count;
    return emails;
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

ReadEmailTool _tool(
  FakeFetcher fetcher, {
  bool configured = true,
  FakeMailOpener? opener,
}) => ReadEmailTool(
  canRead: () async => configured,
  fetch: fetcher.fetch,
  openMailApp: (opener ?? FakeMailOpener()).open,
);

void main() {
  group('ReadEmailTool', () {
    test('is read-only (no confirmation) and named read_email', () {
      final tool = _tool(FakeFetcher(const []));
      expect(tool.name, 'read_email');
      expect(tool.mutates, isFalse);
    });

    test('with no IMAP: opens the mail app instead of reading', () async {
      final opener = FakeMailOpener();
      final fetcher = FakeFetcher(const []);
      final tool = _tool(fetcher, configured: false, opener: opener);
      final result = await tool.run(const {});
      expect(opener.calls, 1);
      expect(fetcher.calls, 0);
      expect(result.content.toLowerCase(), contains('correo'));
    });

    test('empty inbox says so', () async {
      final result = await _tool(FakeFetcher(const [])).run(const {});
      expect(result.content.toLowerCase(), contains('no encontré'));
    });

    test('formats sender and subject, and passes the count', () async {
      final fetcher = FakeFetcher([
        EmailSummary(
          from: 'Ana',
          subject: 'Reunión',
          date: DateTime(2026, 7, 1, 9, 5),
        ),
        const EmailSummary(from: 'Banco', subject: 'Tu recibo'),
      ]);
      final result = await _tool(fetcher).run({'count': 3});

      expect(fetcher.lastCount, 3);
      expect(result.isError, isFalse);
      expect(result.content, contains('Ana — Reunión'));
      expect(result.content, contains('2026-07-01 09:05'));
      expect(result.content, contains('Banco — Tu recibo'));
    });

    test('defaults to 5 when no count given', () async {
      final fetcher = FakeFetcher(const [
        EmailSummary(from: 'x', subject: 'y'),
      ]);
      await _tool(fetcher).run(const {});
      expect(fetcher.lastCount, 5);
    });
  });

  test('end-to-end: brain reads email then answers', () async {
    final fetcher = FakeFetcher(const [
      EmailSummary(from: 'Ana', subject: 'Hola'),
    ]);
    final registry = ToolRegistry()..register(_tool(fetcher));

    final brain = AstroBrain(
      client: FakeLlmClient([
        LlmResponse(
          message: LlmMessage(
            role: Role.assistant,
            blocks: const [
              ToolUseBlock(
                id: 'call_1',
                name: 'read_email',
                arguments: {'count': 2},
              ),
            ],
          ),
          stopReason: StopReason.toolUse,
        ),
        LlmResponse(
          message: LlmMessage.text(Role.assistant, 'Tienes un correo de Ana.'),
          stopReason: StopReason.endTurn,
        ),
      ]),
      registry: registry,
    );

    final answer = await brain.ask('¿tengo correos?', model: 'm');

    expect(fetcher.calls, 1);
    expect(fetcher.lastCount, 2);
    expect(answer, 'Tienes un correo de Ana.');
  });
}
