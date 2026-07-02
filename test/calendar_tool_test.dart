import 'package:astro/brain/astro_brain.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/tools/calendar_tool.dart';
import 'package:astro/brain/tools/tool_registry.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the tool asked to create, and returns a scripted result.
class FakeCreator {
  FakeCreator({this.result = true});
  final bool result;
  int calls = 0;
  String? title;
  DateTime? start;
  Duration? duration;
  Duration? reminder;

  Future<bool> create({
    required String title,
    required DateTime start,
    required Duration duration,
    required Duration reminder,
  }) async {
    calls++;
    this.title = title;
    this.start = start;
    this.duration = duration;
    this.reminder = reminder;
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

void main() {
  group('CalendarTool', () {
    test('is read-only (no confirmation) and named calendar', () {
      final tool = CalendarTool(createEvent: FakeCreator().create);
      expect(tool.name, 'calendar');
      expect(tool.mutates, isFalse);
    });

    test('parses title + ISO start and passes them through', () async {
      final creator = FakeCreator();
      final tool = CalendarTool(createEvent: creator.create);
      final result = await tool.run({
        'title': 'Cita con el dentista',
        'start': '2026-07-02T18:30',
        'duration_minutes': 45,
        'reminder_minutes': 30,
      });

      expect(creator.title, 'Cita con el dentista');
      expect(creator.start, DateTime(2026, 7, 2, 18, 30));
      expect(creator.duration, const Duration(minutes: 45));
      expect(creator.reminder, const Duration(minutes: 30));
      expect(result.isError, isFalse);
    });

    test('defaults duration 60 and reminder 10 when omitted', () async {
      final creator = FakeCreator();
      final tool = CalendarTool(createEvent: creator.create);
      await tool.run({'title': 'X', 'start': '2026-07-02T09:00'});
      expect(creator.duration, const Duration(minutes: 60));
      expect(creator.reminder, const Duration(minutes: 10));
    });

    test('a bad start datetime is an error, not a throw', () async {
      final creator = FakeCreator();
      final tool = CalendarTool(createEvent: creator.create);
      final result = await tool.run({'title': 'X', 'start': 'mañana'});
      expect(result.isError, isTrue);
      expect(creator.calls, 0);
    });

    test('a create failure reports it', () async {
      final tool = CalendarTool(createEvent: FakeCreator(result: false).create);
      final result = await tool.run({
        'title': 'X',
        'start': '2026-07-02T09:00',
      });
      expect(result.content.toLowerCase(), contains('no pude'));
    });

    test('the result language follows the injected AppLang', () async {
      final tool = CalendarTool(
        createEvent: FakeCreator().create,
        lang: () => AppLang.en,
      );
      final result = await tool.run({
        'title': 'Dentist',
        'start': '2026-07-02T18:30',
      });
      expect(result.content, 'Done, I scheduled "Dentist".');
    });
  });

  test('end-to-end: brain calls calendar then answers', () async {
    final creator = FakeCreator();
    final registry = ToolRegistry()
      ..register(CalendarTool(createEvent: creator.create));

    final brain = AstroBrain(
      client: FakeLlmClient([
        LlmResponse(
          message: LlmMessage(
            role: Role.assistant,
            blocks: const [
              ToolUseBlock(
                id: 'call_1',
                name: 'calendar',
                arguments: {'title': 'Reunión', 'start': '2026-07-02T15:00'},
              ),
            ],
          ),
          stopReason: StopReason.toolUse,
        ),
        LlmResponse(
          message: LlmMessage.text(Role.assistant, 'Listo, quedó agendado.'),
          stopReason: StopReason.endTurn,
        ),
      ]),
      registry: registry,
    );

    final answer = await brain.ask('agéndame una reunión', model: 'm');

    expect(creator.calls, 1);
    expect(creator.title, 'Reunión');
    expect(creator.start, DateTime(2026, 7, 2, 15, 0));
    expect(answer, 'Listo, quedó agendado.');
  });
}
