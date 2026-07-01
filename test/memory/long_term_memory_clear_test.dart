import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:astro/memory/long_term_memory.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('clearAll empties the store', () async {
    final mem = await LongTermMemory.open(
      factory: databaseFactory,
      path: inMemoryDatabasePath,
    );
    await mem.remember('the driver likes jazz');
    expect(await mem.count(), 1);
    final removed = await mem.clearAll();
    expect(removed, 1);
    expect(await mem.count(), 0);
    await mem.close();
  });

  test(
    'clearAll does not throw when FTS is unavailable (forceNoFts)',
    () async {
      final mem = await LongTermMemory.open(
        factory: databaseFactory,
        path: inMemoryDatabasePath,
        forceNoFts: true,
      );
      expect(mem.hasFullTextSearch, isFalse);
      await mem.remember('test memory without fts');
      expect(await mem.count(), 1);
      // Must not throw even though memories_fts table does not exist.
      final removed = await mem.clearAll();
      expect(removed, 1);
      expect(await mem.count(), 0);
      await mem.close();
    },
  );
}
