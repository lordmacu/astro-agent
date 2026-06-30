import 'package:chispa/memory/embedding/embedding_provider.dart';
import 'package:chispa/memory/long_term_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Deterministic embedder: a term-frequency vector over hashed word buckets, so
/// texts that share words land near each other. No network, fully repeatable.
class HashingEmbeddingProvider implements EmbeddingProvider {
  HashingEmbeddingProvider({this.dim = 64});
  final int dim;

  @override
  String get id => 'hashing';

  @override
  Future<List<double>> embedOne(String text) async =>
      (await embed([text])).first;

  @override
  Future<List<List<double>>> embed(List<String> texts) async =>
      [for (final t in texts) _vectorize(t)];

  List<double> _vectorize(String text) {
    final vector = List<double>.filled(dim, 0);
    for (final word in text.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (word.isEmpty) continue;
      vector[word.hashCode.abs() % dim] += 1;
    }
    return vector;
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  Future<LongTermMemory> openWithEmbedder() => LongTermMemory.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
        embedder: HashingEmbeddingProvider(),
      );

  test('recallSemantic ranks the topically closest memory first', () async {
    final mem = await openWithEmbedder();
    addTearDown(mem.close);

    await mem.remember('I love drinking coffee in the morning');
    await mem.remember('the engine oil needs a change soon');
    await mem.remember('the best coffee shop is downtown');

    final coffee = await mem.recallSemantic('where to get coffee', limit: 1);
    expect(coffee.single.content, contains('coffee'));

    final oil = await mem.recallSemantic('motor oil maintenance', limit: 1);
    expect(oil.single.content, contains('oil'));
  });

  test('semantic results respect the limit', () async {
    final mem = await openWithEmbedder();
    addTearDown(mem.close);

    await mem.remember('coffee one');
    await mem.remember('coffee two');
    await mem.remember('coffee three');

    expect(await mem.recallSemantic('coffee', limit: 2), hasLength(2));
  });

  test('forget removes the vector too', () async {
    final mem = await openWithEmbedder();
    addTearDown(mem.close);

    final entry = await mem.remember('coffee with sugar');
    await mem.forget(entry.id);

    expect(await mem.recallSemantic('coffee'), isEmpty);
  });

  test('recallSemantic without an embedder throws', () async {
    final mem = await LongTermMemory.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(mem.close);

    expect(mem.hasEmbedder, isFalse);
    expect(() => mem.recallSemantic('coffee'), throwsA(isA<StateError>()));
  });
}
