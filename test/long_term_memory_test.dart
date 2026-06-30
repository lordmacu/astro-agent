import 'package:chispa/memory/long_term_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LongTermMemory mem;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    mem = await LongTermMemory.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async => mem.close());

  group('remember and recall', () {
    test('recalls a memory by keyword and keeps its tags', () async {
      await mem.remember('The driver prefers cumbia music',
          tags: ['preference'], type: 'preference');

      final hits = await mem.recall('music');

      expect(hits, hasLength(1));
      expect(hits.first.content, contains('cumbia'));
      expect(hits.first.tags, ['preference']);
      expect(hits.first.type, 'preference');
    });

    test('no match yields an empty list', () async {
      await mem.remember('The driver prefers cumbia');
      expect(await mem.recall('motorcycle'), isEmpty);
    });

    test('ranks the better match first', () async {
      await mem.remember('coffee notes about the trip');
      await mem.remember('the road to the coffee farm was full of coffee');

      final hits = await mem.recall('coffee', limit: 2);

      expect(hits, hasLength(2));
      expect(hits.first.content, contains('coffee farm'));
    });

    test('a tag term is OR-ed into the content match', () async {
      await mem.remember('the warning lights are on', tags: ['warning']);
      // The query word misses, but the tag term matches the content.
      final hits = await mem.recall('zzznomatch', tags: ['warning']);
      expect(hits, hasLength(1));
    });
  });

  group('recent, count, forget', () {
    test('recent returns the newest first', () async {
      await mem.remember('first');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await mem.remember('second');

      final recent = await mem.recent(limit: 2);

      expect(recent.first.content, 'second');
      expect(recent.last.content, 'first');
    });

    test('count reflects stored rows', () async {
      expect(await mem.count(), 0);
      await mem.remember('a');
      await mem.remember('b');
      expect(await mem.count(), 2);
    });

    test('forget removes a memory from store and search', () async {
      final entry = await mem.remember('forget me');
      expect(await mem.forget(entry.id), isTrue);
      expect(await mem.count(), 0);
      expect(await mem.recall('forget'), isEmpty);
    });
  });

  group('FTS escaping', () {
    test('a query with FTS operators does not throw', () async {
      await mem.remember('safety and caution always');
      // Unquoted, "AND ( OR *" would be an FTS5 syntax error; quoting makes
      // the whole thing a literal phrase, so the call just completes.
      await expectLater(mem.recall('AND (always) OR *'), completes);
    });

    test('buildFtsMatch quotes and OR-joins terms', () {
      expect(buildFtsMatch('coffee', ['trip']), '"coffee" OR "trip"');
      expect(buildFtsMatch('', []), '""');
      expect(ftsQuote('say "hi"'), '"say ""hi"""');
    });
  });
}
