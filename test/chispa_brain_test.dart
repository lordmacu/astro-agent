import 'package:chispa/brain/chispa_brain.dart';
import 'package:chispa/brain/llm/llm_client.dart';
import 'package:chispa/brain/llm/llm_message.dart';
import 'package:chispa/brain/tools/chispa_tool.dart';
import 'package:chispa/brain/tools/tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake client that replays a scripted list of responses, one per turn.
class FakeLlmClient implements LlmClient {
  FakeLlmClient(this._script);

  final List<LlmResponse> _script;
  int _turn = 0;
  final List<LlmRequest> requests = [];

  @override
  String get providerId => 'fake';

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    requests.add(request);
    return _script[_turn++];
  }
}

/// A read-only tool that records whether it ran.
class EchoTool extends ChispaTool {
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
class WipeTool extends ChispaTool {
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

void main() {
  test('returns the final text when no tools are requested', () async {
    final brain = ChispaBrain(
      client: FakeLlmClient([_finalTurn('Sunny today.')]),
      registry: ToolRegistry(),
    );
    final answer = await brain.ask('How is the weather?', model: 'm');
    expect(answer, 'Sunny today.');
  });

  test('runs a read-only tool then returns the final answer', () async {
    final tool = EchoTool();
    final registry = ToolRegistry()..register(tool);
    final used = <String>[];
    final brain = ChispaBrain(
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
    final brain = ChispaBrain(
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
    final brain = ChispaBrain(
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
}
