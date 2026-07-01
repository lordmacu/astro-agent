import 'package:astro/brain/astro_brain.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/tools/memory_tools.dart';
import 'package:astro/brain/tools/tool_registry.dart';
import 'package:astro/memory/long_term_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

LlmResponse _toolTurn(String name, Map<String, dynamic> args) => LlmResponse(
  message: LlmMessage(
    role: Role.assistant,
    blocks: [ToolUseBlock(id: 'c1', name: name, arguments: args)],
  ),
  stopReason: StopReason.toolUse,
);

LlmResponse _finalTurn(String text) => LlmResponse(
  message: LlmMessage.text(Role.assistant, text),
  stopReason: StopReason.endTurn,
);

void main() {
  late LongTermMemory memory;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    memory = await LongTermMemory.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() async => memory.close());

  group('RememberTool', () {
    test('stores the fact with its tags', () async {
      final result = await RememberTool(memory).run({
        'content': 'The driver likes vallenato',
        'tags': ['preference'],
      });

      expect(result.isError, isFalse);
      expect(await memory.count(), 1);
      final recalled = await memory.recall('vallenato');
      expect(recalled.single.tags, ['preference']);
    });

    test('empty content is an error', () async {
      final result = await RememberTool(memory).run({'content': '  '});
      expect(result.isError, isTrue);
      expect(await memory.count(), 0);
    });
  });

  group('RecallTool', () {
    test('returns saved memories matching the query', () async {
      await memory.remember('parking spot is on level 3');
      final result = await RecallTool(memory).run({'query': 'parking'});

      expect(result.isError, isFalse);
      expect(result.content, contains('level 3'));
    });

    test('reports when nothing matches', () async {
      final result = await RecallTool(memory).run({'query': 'spaceship'});
      expect(result.content, contains('Nothing remembered'));
    });
  });

  test('end-to-end: brain recalls a saved memory through the tool', () async {
    await memory.remember('the driver prefers the scenic route home');
    final registry = ToolRegistry()..register(RecallTool(memory));

    final brain = AstroBrain(
      client: FakeLlmClient([
        _toolTurn('recall_memory', {'query': 'route home'}),
        _finalTurn('You like the scenic route home.'),
      ]),
      registry: registry,
    );

    final answer = await brain.ask('Which way home?', model: 'm');
    expect(answer, 'You like the scenic route home.');
  });
}
