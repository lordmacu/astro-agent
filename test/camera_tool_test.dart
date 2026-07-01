import 'package:astro/brain/astro_brain.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/tools/camera_tool.dart';
import 'package:astro/brain/tools/tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the requested lens and returns a scripted path (or null on failure).
class FakeCapture {
  FakeCapture({this.result = '/tmp/astro_shot.jpg'});
  final String? result;
  int calls = 0;
  bool? lastFront;

  Future<String?> capture({required bool front}) async {
    calls++;
    lastFront = front;
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
  group('CameraTool', () {
    test('is read-only (no confirmation) and named take_photo', () {
      final tool = CameraTool(capture: FakeCapture().capture);
      expect(tool.name, 'take_photo');
      expect(tool.mutates, isFalse);
    });

    test('camera "front" selects the front lens', () async {
      final cap = FakeCapture();
      final tool = CameraTool(capture: cap.capture);
      final result = await tool.run({'camera': 'front'});
      expect(cap.lastFront, isTrue);
      expect(result.isError, isFalse);
      expect(result.content.toLowerCase(), contains('gallery'));
    });

    test('default (no camera arg) uses the back lens', () async {
      final cap = FakeCapture();
      final tool = CameraTool(capture: cap.capture);
      await tool.run(const {});
      expect(cap.lastFront, isFalse);
    });

    test('on success: plays shutter and publishes the captured path', () async {
      var shutters = 0;
      String? published;
      final tool = CameraTool(
        capture: FakeCapture(result: '/tmp/shot.jpg').capture,
        playShutter: () => shutters++,
        onCaptured: (p) => published = p,
      );
      final result = await tool.run(const {});
      expect(shutters, 1);
      expect(published, '/tmp/shot.jpg');
      expect(result.isError, isFalse);
    });

    test('on failure: no shutter, no publish, reports the error', () async {
      var shutters = 0;
      String? published;
      final tool = CameraTool(
        capture: FakeCapture(result: null).capture,
        playShutter: () => shutters++,
        onCaptured: (p) => published = p,
      );
      final result = await tool.run(const {});
      expect(shutters, 0);
      expect(published, isNull);
      expect(result.content.toLowerCase(), contains('could not'));
    });
  });

  test('end-to-end: brain calls take_photo then answers', () async {
    final cap = FakeCapture();
    final registry = ToolRegistry()..register(CameraTool(capture: cap.capture));

    final brain = AstroBrain(
      client: FakeLlmClient([
        LlmResponse(
          message: LlmMessage(
            role: Role.assistant,
            blocks: const [
              ToolUseBlock(
                id: 'call_1',
                name: 'take_photo',
                arguments: {'camera': 'front'},
              ),
            ],
          ),
          stopReason: StopReason.toolUse,
        ),
        LlmResponse(
          message: LlmMessage.text(Role.assistant, '¡Listo, te tomé la foto!'),
          stopReason: StopReason.endTurn,
        ),
      ]),
      registry: registry,
    );

    final answer = await brain.ask('toma una foto', model: 'm');

    expect(cap.calls, 1);
    expect(cap.lastFront, isTrue);
    expect(answer, '¡Listo, te tomé la foto!');
  });
}
