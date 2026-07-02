import 'package:astro/brain/astro_brain.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/tools/astro_tool.dart';
import 'package:astro/brain/tools/tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake client that replays a scripted list of responses, one per turn.
class FakeLlmClient implements LlmClient {
  FakeLlmClient(this._script);

  final List<LlmResponse> _script;
  int _turn = 0;
  final List<LlmRequest> requests = [];

  /// Text of every message, snapshotted at call time (before the loop mutates
  /// the shared messages list with the response).
  final List<List<String>> requestTexts = [];

  @override
  String get providerId => 'fake';

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    requests.add(request);
    requestTexts.add([
      for (final m in request.messages)
        for (final b in m.blocks.whereType<TextBlock>()) b.text,
    ]);
    return _script[_turn++];
  }

  @override
  Stream<LlmStreamChunk> completeStream(LlmRequest request) =>
      streamViaComplete(complete(request));
}

/// A read-only tool that records whether it ran.
class EchoTool extends AstroTool {
  bool ran = false;

  @override
  String get name => 'echo';
  @override
  String get description => 'Echo back the text.';
  @override
  Map<String, dynamic> get inputSchema => {'type': 'object'};

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    ran = true;
    return ToolResult('echo: ${args['text']}');
  }
}

/// A mutating tool, gated behind confirmation.
class WipeTool extends AstroTool {
  bool ran = false;

  @override
  String get name => 'wipe';
  @override
  String get description => 'Clear the fault codes.';
  @override
  Map<String, dynamic> get inputSchema => {'type': 'object'};
  @override
  bool get mutates => true;

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    ran = true;
    return const ToolResult('done');
  }
}

LlmResponse _toolTurn(String id, String name, Map<String, dynamic> args) =>
    LlmResponse(
      message: LlmMessage(
        role: Role.assistant,
        blocks: [ToolUseBlock(id: id, name: name, arguments: args)],
      ),
      stopReason: StopReason.toolUse,
    );

LlmResponse _finalTurn(String text) => LlmResponse(
  message: LlmMessage.text(Role.assistant, text),
  stopReason: StopReason.endTurn,
);

/// Mutating tool whose confirmation requirement is configurable, to test the
/// brain's requiresConfirmation gate.
class _ConfirmSpyTool extends AstroTool {
  _ConfirmSpyTool({required this.needs});
  final bool needs;
  @override
  String get name => 'spy';
  @override
  String get description => 'spy';
  @override
  Map<String, dynamic> get inputSchema => const {'type': 'object'};
  @override
  bool get mutates => true;
  @override
  Future<bool> requiresConfirmation(Map<String, dynamic> args) async => needs;
  @override
  Future<ToolResult> run(Map<String, dynamic> args) async =>
      const ToolResult('done');
}

/// Fake client that fails (throws [LlmException]) for the given models and
/// otherwise returns a final answer naming the model that served it. Records
/// every model id it is called with, in order.
class _FailoverClient implements LlmClient {
  _FailoverClient({required this.failing, this.status = 500});
  final Set<String> failing;
  final int status;
  final List<String> calls = [];

  @override
  String get providerId => 'fake';

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    calls.add(request.model);
    if (failing.contains(request.model)) {
      throw LlmException('down', statusCode: status);
    }
    return _finalTurn('served by ${request.model}');
  }

  // Streams natively (throws inside the generator, like the real clients) so a
  // failed model raises before any delta.
  @override
  Stream<LlmStreamChunk> completeStream(LlmRequest request) async* {
    calls.add(request.model);
    if (failing.contains(request.model)) {
      throw LlmException('down', statusCode: status);
    }
    yield LlmTextDelta('served by ${request.model}');
    yield LlmDone(_finalTurn('served by ${request.model}'));
  }
}

void main() {
  const freeList = ['free-a', 'free-b', 'free-c'];

  test('returns the final text when no tools are requested', () async {
    final brain = AstroBrain(
      client: FakeLlmClient([_finalTurn('Sunny today.')]),
      registry: ToolRegistry(),
    );
    final answer = await brain.ask('How is the weather?', model: 'm');
    expect(answer, 'Sunny today.');
  });

  group('free-model failover', () {
    test('switches to the next free model and persists it', () async {
      final client = _FailoverClient(failing: {'free-a'});
      final switched = <String>[];
      final brain = AstroBrain(
        client: client,
        registry: ToolRegistry(),
        freeFallbacks: () => freeList,
        onModelSwitched: switched.add,
      );

      final answer = await brain.ask('hi', model: 'free-a');

      expect(client.calls, ['free-a', 'free-b']); // tried A, fell over to B
      expect(answer, 'served by free-b');
      expect(switched, ['free-b']); // winner persisted
    });

    test('streaming also fails over and persists', () async {
      final client = _FailoverClient(failing: {'free-a'});
      final switched = <String>[];
      final brain = AstroBrain(
        client: client,
        registry: ToolRegistry(),
        freeFallbacks: () => freeList,
        onModelSwitched: switched.add,
      );

      final sentences = <String>[];
      final answer = await brain.askStream(
        'hi',
        model: 'free-a',
        onSentence: sentences.add,
      );

      expect(answer, 'served by free-b');
      expect(switched, ['free-b']);
    });

    test('paid models never fail over (single attempt, no persist)', () async {
      final client = _FailoverClient(failing: {'MiniMax-M3'});
      final switched = <String>[];
      final brain = AstroBrain(
        client: client,
        registry: ToolRegistry(),
        freeFallbacks: () => freeList, // MiniMax-M3 is not in the free list
        onModelSwitched: switched.add,
      );

      await expectLater(
        brain.ask('hi', model: 'MiniMax-M3'),
        throwsA(isA<LlmException>()),
      );
      expect(client.calls, ['MiniMax-M3']); // no failover attempted
      expect(switched, isEmpty);
    });

    test('a rate-limited free model (429) does not cycle the others', () async {
      final client = _FailoverClient(failing: freeList.toSet(), status: 429);
      final brain = AstroBrain(
        client: client,
        registry: ToolRegistry(),
        freeFallbacks: () => freeList,
      );

      await expectLater(
        brain.ask('hi', model: 'free-a'),
        throwsA(isA<LlmException>()),
      );
      expect(client.calls, ['free-a']); // 429 → don't hammer the rest
    });
  });

  test('runs a read-only tool then returns the final answer', () async {
    final tool = EchoTool();
    final registry = ToolRegistry()..register(tool);
    final used = <String>[];
    final brain = AstroBrain(
      client: FakeLlmClient([
        _toolTurn('1', 'echo', {'text': 'hi'}),
        _finalTurn('I echoed it.'),
      ]),
      registry: registry,
      onToolUse: used.add,
    );

    final answer = await brain.ask('Echo hi', model: 'm');

    expect(tool.ran, isTrue);
    expect(used, ['echo']);
    expect(answer, 'I echoed it.');
  });

  test('a denied mutating tool does not run', () async {
    final tool = WipeTool();
    final registry = ToolRegistry()..register(tool);
    final brain = AstroBrain(
      client: FakeLlmClient([
        _toolTurn('1', 'wipe', {}),
        _finalTurn('Left them as is.'),
      ]),
      registry: registry,
      confirm: (_, __) async => false,
    );

    final answer = await brain.ask('Clear the codes', model: 'm');

    expect(tool.ran, isFalse);
    expect(answer, 'Left them as is.');
  });

  test('an approved mutating tool runs', () async {
    final tool = WipeTool();
    final registry = ToolRegistry()..register(tool);
    final brain = AstroBrain(
      client: FakeLlmClient([
        _toolTurn('1', 'wipe', {}),
        _finalTurn('Cleared.'),
      ]),
      registry: registry,
      confirm: (_, __) async => true,
    );

    await brain.ask('Clear the codes', model: 'm');

    expect(tool.ran, isTrue);
  });

  test('a non-Spanish answer triggers one rewrite request', () async {
    final client = FakeLlmClient([
      _finalTurn('现在是下午三点。'), // Chinese slip
      _finalTurn('Son las tres de la tarde.'), // corrected
    ]);
    final brain = AstroBrain(client: client, registry: ToolRegistry());

    final answer = await brain.ask('¿Qué hora es?', model: 'm');

    expect(answer, 'Son las tres de la tarde.');
    // A second request was made, carrying a Spanish rewrite instruction.
    expect(client.requests.length, 2);
    final allText = client.requests.last.messages
        .expand((m) => m.blocks.whereType<TextBlock>())
        .map((b) => b.text)
        .join(' ');
    expect(allText, contains('español'));
  });

  test('strips leaked <think> reasoning from the answer', () async {
    final client = FakeLlmClient([
      _finalTurn(
        '<think>El usuario pregunta la hora. Voy a responder en '
        'español.</think>Son las tres de la tarde.',
      ),
    ]);
    final brain = AstroBrain(client: client, registry: ToolRegistry());

    final answer = await brain.ask('¿Qué hora es?', model: 'm');

    expect(answer, 'Son las tres de la tarde.');
    expect(answer, isNot(contains('<think>')));
    expect(answer, isNot(contains('Voy a responder')));
  });

  test('a Spanish answer is returned without an extra request', () async {
    final client = FakeLlmClient([_finalTurn('Son las tres.')]);
    final brain = AstroBrain(client: client, registry: ToolRegistry());

    final answer = await brain.ask('¿Qué hora es?', model: 'm');

    expect(answer, 'Son las tres.');
    expect(client.requests.length, 1);
  });

  group('askStream', () {
    test('emits one sentence at a time and returns the full text', () async {
      final client = FakeLlmClient([_finalTurn('Son las tres. Vamos bien.')]);
      final brain = AstroBrain(client: client, registry: ToolRegistry());
      final sentences = <String>[];

      final answer = await brain.askStream(
        '¿hora?',
        model: 'm',
        onSentence: sentences.add,
      );

      expect(sentences, ['Son las tres.', 'Vamos bien.']);
      expect(answer, 'Son las tres. Vamos bien.');
    });

    test('runs a tool, then streams the final answer', () async {
      final tool = EchoTool();
      final registry = ToolRegistry()..register(tool);
      final client = FakeLlmClient([
        _toolTurn('1', 'echo', {'text': 'hi'}),
        _finalTurn('Listo.'),
      ]);
      final brain = AstroBrain(client: client, registry: registry);
      final sentences = <String>[];

      final answer = await brain.askStream(
        'echo',
        model: 'm',
        onSentence: sentences.add,
      );

      expect(tool.ran, isTrue);
      expect(sentences, ['Listo.']);
      expect(answer, 'Listo.');
    });

    test('filters a leaked <think> block from the spoken sentences', () async {
      final client = FakeLlmClient([
        _finalTurn('<think>razono aquí</think>Hola.'),
      ]);
      final brain = AstroBrain(client: client, registry: ToolRegistry());
      final sentences = <String>[];

      await brain.askStream('hola', model: 'm', onSentence: sentences.add);

      expect(sentences, ['Hola.']);
    });

    test('carries prior turns as memory into the next request', () async {
      final client = FakeLlmClient([
        _finalTurn('Estamos en Usaquén.'),
        _finalTurn('Es la Calle 100.'),
      ]);
      final brain = AstroBrain(client: client, registry: ToolRegistry());

      await brain.askStream('¿dónde estamos?', model: 'm', onSentence: (_) {});
      await brain.askStream('dame la exacta', model: 'm', onSentence: (_) {});

      // The 2nd request replays the 1st exchange before the new question.
      expect(client.requestTexts.last, [
        '¿dónde estamos?',
        'Estamos en Usaquén.',
        'dame la exacta',
      ]);
    });

    test('resetConversation clears the memory', () async {
      final client = FakeLlmClient([_finalTurn('Uno.'), _finalTurn('Dos.')]);
      final brain = AstroBrain(client: client, registry: ToolRegistry());

      await brain.askStream('a', model: 'm', onSentence: (_) {});
      brain.resetConversation();
      await brain.askStream('b', model: 'm', onSentence: (_) {});

      // Only the new question, no history.
      expect(client.requestTexts.last, ['b']);
    });
  });

  group('conditional confirmation', () {
    test(
      'a mutating tool whose requiresConfirmation is false is NOT confirmed',
      () async {
        var confirms = 0;
        final registry = ToolRegistry()
          ..register(_ConfirmSpyTool(needs: false));
        final brain = AstroBrain(
          client: FakeLlmClient([
            LlmResponse(
              message: LlmMessage(
                role: Role.assistant,
                blocks: const [
                  ToolUseBlock(id: 'c1', name: 'spy', arguments: {}),
                ],
              ),
              stopReason: StopReason.toolUse,
            ),
            LlmResponse(
              message: LlmMessage.text(Role.assistant, 'ok'),
              stopReason: StopReason.endTurn,
            ),
          ]),
          registry: registry,
          confirm: (_, __) async {
            confirms++;
            return true;
          },
        );
        await brain.ask('x', model: 'm');
        expect(confirms, 0);
      },
    );

    test(
      'a mutating tool whose requiresConfirmation is true IS confirmed',
      () async {
        var confirms = 0;
        final registry = ToolRegistry()..register(_ConfirmSpyTool(needs: true));
        final brain = AstroBrain(
          client: FakeLlmClient([
            LlmResponse(
              message: LlmMessage(
                role: Role.assistant,
                blocks: const [
                  ToolUseBlock(id: 'c1', name: 'spy', arguments: {}),
                ],
              ),
              stopReason: StopReason.toolUse,
            ),
            LlmResponse(
              message: LlmMessage.text(Role.assistant, 'ok'),
              stopReason: StopReason.endTurn,
            ),
          ]),
          registry: registry,
          confirm: (_, __) async {
            confirms++;
            return true;
          },
        );
        await brain.ask('x', model: 'm');
        expect(confirms, 1);
      },
    );
  });
}
