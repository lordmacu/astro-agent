import 'package:astro/brain/astro_brain.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/memory_context.dart';
import 'package:astro/brain/tools/tool_registry.dart';
import 'package:astro/memory/long_term_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Captures the request so the test can inspect the system prompt.
class CapturingLlmClient implements LlmClient {
  CapturingLlmClient(this.reply);
  final String reply;
  LlmRequest? lastRequest;

  @override
  String get providerId => 'fake';

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    lastRequest = request;
    return LlmResponse(
      message: LlmMessage.text(Role.assistant, reply),
      stopReason: StopReason.endTurn,
    );
  }

  @override
  Stream<LlmStreamChunk> completeStream(LlmRequest request) =>
      streamViaComplete(complete(request));
}

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

  test('relevant memory is injected into the system prompt', () async {
    await memory.remember('the driver prefers the scenic route home');
    final client = CapturingLlmClient('Taking the scenic route.');

    final brain = AstroBrain(
      client: client,
      registry: ToolRegistry(),
      recallContext: MemoryContext(memory).call,
    );

    await brain.ask('which way home?', model: 'm', system: 'You are Astro.');

    final system = client.lastRequest!.system!;
    expect(system, contains('You are Astro.'));
    expect(system, contains('scenic route home'));
  });

  test('no relevant memory leaves the system prompt unchanged', () async {
    await memory.remember('the driver likes vallenato');
    final client = CapturingLlmClient('Sure.');

    final brain = AstroBrain(
      client: client,
      registry: ToolRegistry(),
      recallContext: MemoryContext(memory).call,
    );

    await brain.ask('how far is the moon?', model: 'm', system: 'Base.');

    expect(client.lastRequest!.system, 'Base.');
  });

  test('without a recall hook the system prompt is passed through', () async {
    final client = CapturingLlmClient('ok');
    final brain = AstroBrain(client: client, registry: ToolRegistry());

    await brain.ask('hi', model: 'm', system: 'Base.');

    expect(client.lastRequest!.system, 'Base.');
  });
}
