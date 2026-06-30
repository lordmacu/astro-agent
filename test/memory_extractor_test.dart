import 'package:chispa/brain/llm/llm_client.dart';
import 'package:chispa/brain/llm/llm_message.dart';
import 'package:chispa/memory/long_term_memory.dart';
import 'package:chispa/memory/memory_extractor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FixedLlmClient implements LlmClient {
  FixedLlmClient(this.reply);
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
}

void main() {
  group('parseExtraction', () {
    test('parses a plain JSON array', () {
      final out = parseExtraction(
          '[{"content":"likes cumbia","type":"preference","tags":["music"]}]');
      expect(out.single.content, 'likes cumbia');
      expect(out.single.type, 'preference');
      expect(out.single.tags, ['music']);
    });

    test('tolerates a ```json fence', () {
      final out = parseExtraction('```json\n[{"content":"parks on level 3"}]\n```');
      expect(out.single.content, 'parks on level 3');
    });

    test('drops items with empty content', () {
      final out = parseExtraction('[{"content":"  "},{"content":"keep me"}]');
      expect(out, hasLength(1));
      expect(out.single.content, 'keep me');
    });

    test('an empty array yields nothing', () {
      expect(parseExtraction('[]'), isEmpty);
    });

    test('non-array payload throws FormatException', () {
      expect(() => parseExtraction('not json'),
          throwsA(isA<FormatException>()));
    });
  });

  group('extractAndStore', () {
    late LongTermMemory memory;

    setUpAll(sqfliteFfiInit);
    setUp(() async {
      memory = await LongTermMemory.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
    });
    tearDown(() async => memory.close());

    test('stores extracted memories and makes them recallable', () async {
      final client = FixedLlmClient(
          '[{"content":"the driver prefers the scenic route home",'
          '"type":"route","tags":["home"]}]');
      final extractor =
          MemoryExtractor(client: client, memory: memory, model: 'm');

      final stored = await extractor.extractAndStore('driver: I always take the scenic way home');

      expect(stored, hasLength(1));
      expect(client.lastRequest!.system, kMemoryExtractionSystemPrompt);
      expect(await memory.count(), 1);
      final recalled = await memory.recall('scenic route');
      expect(recalled.single.type, 'route');
    });

    test('stores nothing when the model returns an empty array', () async {
      final client = FixedLlmClient('[]');
      final extractor =
          MemoryExtractor(client: client, memory: memory, model: 'm');

      final stored = await extractor.extractAndStore('driver: nice weather huh');

      expect(stored, isEmpty);
      expect(await memory.count(), 0);
    });

    test('an unparseable reply stores nothing instead of throwing', () async {
      final client = FixedLlmClient('sorry, I cannot help with that');
      final extractor =
          MemoryExtractor(client: client, memory: memory, model: 'm');

      expect(await extractor.extractAndStore('hello'), isEmpty);
      expect(await memory.count(), 0);
    });
  });
}
