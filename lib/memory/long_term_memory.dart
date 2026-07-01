import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'embedding/embedding_provider.dart';
import 'memory_entry.dart';

/// Default agent id. Astro is a single pet, so one bucket is enough; the
/// column stays for parity with the nexo-rs schema and future multi-agent use.
const String kDefaultAgentId = 'astro';

/// SQLite-backed long-term memory. Ported from the nexo-rs `LongTermMemory`,
/// trimmed to the core store: write memories and recall them by full-text
/// search (FTS5). Vector/embedding recall and the dreaming sweep come later.
class LongTermMemory {
  LongTermMemory._(this._db, this.agentId, this._embedder, this._ftsAvailable);

  final Database _db;
  final String agentId;

  /// Optional embeddings backend. When set, memories are also stored as
  /// vectors and `recallSemantic` works.
  final EmbeddingProvider? _embedder;

  /// Whether the device's SQLite has the FTS5 module. Some Android builds ship
  /// SQLite without it (`no such module: fts5`); there, recall falls back to a
  /// plain LIKE search so memory still works.
  final bool _ftsAvailable;

  static const _uuid = Uuid();

  bool get hasEmbedder => _embedder != null;
  bool get hasFullTextSearch => _ftsAvailable;

  /// Open (and migrate) the database. Pass a [factory] — the device's
  /// `databaseFactory` in the app, or `databaseFactoryFfi` in tests. Use
  /// [inMemoryDatabasePath] for an ephemeral database. Pass an [embedder] to
  /// enable semantic recall.
  static Future<LongTermMemory> open({
    required DatabaseFactory factory,
    String path = 'astro_memory.db',
    String agentId = kDefaultAgentId,
    EmbeddingProvider? embedder,
    bool forceNoFts = false, // test hook: simulate SQLite without FTS5
  }) async {
    final db = await factory.openDatabase(path);
    final fts = await _createSchema(db, allowFts: !forceNoFts);
    return LongTermMemory._(db, agentId, embedder, fts);
  }

  /// Create the schema. Returns whether the FTS5 virtual table was created —
  /// false on devices whose SQLite lacks the module (or when [allowFts] is off).
  static Future<bool> _createSchema(Database db, {bool allowFts = true}) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memories (
        id          TEXT PRIMARY KEY,
        agent_id    TEXT NOT NULL,
        content     TEXT NOT NULL,
        tags        TEXT NOT NULL DEFAULT '[]',
        memory_type TEXT,
        created_at  INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_memories_agent
        ON memories(agent_id, created_at DESC)
    ''');
    // Vectors live in a plain table; similarity is computed in Dart since the
    // sqlite-vec extension is not available under sqflite.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memory_vectors (
        memory_id TEXT PRIMARY KEY,
        agent_id  TEXT NOT NULL,
        embedding TEXT NOT NULL
      )
    ''');
    if (!allowFts) return false;
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
          content,
          id UNINDEXED,
          agent_id UNINDEXED
        )
      ''');
      return true;
    } catch (_) {
      // Device SQLite without FTS5 — recall uses a LIKE fallback instead.
      return false;
    }
  }

  /// Store a memory and return it.
  Future<MemoryEntry> remember(
    String content, {
    List<String> tags = const [],
    String? type,
  }) async {
    final entry = MemoryEntry(
      id: _uuid.v4(),
      agentId: agentId,
      content: content,
      tags: tags,
      type: type,
      createdAt: DateTime.now(),
    );

    await _db.insert('memories', {
      'id': entry.id,
      'agent_id': entry.agentId,
      'content': entry.content,
      'tags': jsonEncode(entry.tags),
      'memory_type': entry.type,
      'created_at': entry.createdAt.millisecondsSinceEpoch,
    });
    if (_ftsAvailable) {
      await _db.insert('memories_fts', {
        'content': entry.content,
        'id': entry.id,
        'agent_id': entry.agentId,
      });
    }

    if (_embedder != null) {
      final vector = await _embedder.embedOne(entry.content);
      await _db.insert('memory_vectors', {
        'memory_id': entry.id,
        'agent_id': entry.agentId,
        'embedding': jsonEncode(vector),
      });
    }

    return entry;
  }

  /// Recall memories matching [query] (and optional [tags]), best match first.
  /// Uses FTS5 when available, else a LIKE fallback on the same tokens.
  Future<List<MemoryEntry>> recall(
    String query, {
    List<String> tags = const [],
    int limit = 5,
  }) async {
    if (!_ftsAvailable) return _recallLike(query, tags: tags, limit: limit);
    final rows = await _db.rawQuery(
      '''
      SELECT m.id, m.agent_id, m.content, m.tags, m.memory_type, m.created_at
      FROM memories_fts f
      JOIN memories m ON m.id = f.id
      WHERE f.content MATCH ? AND f.agent_id = ?
      ORDER BY rank
      LIMIT ?
      ''',
      [buildFtsMatch(query, tags), agentId, limit],
    );
    return rows.map(_rowToEntry).toList();
  }

  /// FTS5-free recall: match memories whose content contains any query token
  /// (case-insensitive), newest first. Coarser than FTS ranking, but keeps
  /// memory usable on devices without the module.
  Future<List<MemoryEntry>> _recallLike(
    String query, {
    List<String> tags = const [],
    int limit = 5,
  }) async {
    final tokens = <String>{
      ..._tokenize(query),
      for (final t in tags) t.toLowerCase().trim(),
    }..removeWhere((t) => t.isEmpty);
    if (tokens.isEmpty) return recent(limit: limit);

    final likes = List.filled(
      tokens.length,
      'LOWER(content) LIKE ?',
    ).join(' OR ');
    final rows = await _db.rawQuery(
      '''
      SELECT id, agent_id, content, tags, memory_type, created_at
      FROM memories
      WHERE agent_id = ? AND ($likes)
      ORDER BY created_at DESC
      LIMIT ?
      ''',
      [agentId, for (final t in tokens) '%$t%', limit],
    );
    return rows.map(_rowToEntry).toList();
  }

  /// Recall memories by semantic similarity to [query]. Requires an embedder.
  /// Embeds the query, scores every stored vector by cosine similarity in
  /// Dart, and returns the top [limit]. Results below [minScore] are dropped.
  Future<List<MemoryEntry>> recallSemantic(
    String query, {
    int limit = 5,
    double minScore = 0.0,
  }) async {
    final embedder = _embedder;
    if (embedder == null) {
      throw StateError('recallSemantic needs an embedder; none was provided');
    }

    final queryVector = await embedder.embedOne(query);

    final rows = await _db.rawQuery(
      '''
      SELECT m.id, m.agent_id, m.content, m.tags, m.memory_type, m.created_at,
             v.embedding
      FROM memory_vectors v
      JOIN memories m ON m.id = v.memory_id
      WHERE v.agent_id = ?
      ''',
      [agentId],
    );

    final scored = <({MemoryEntry entry, double score})>[];
    for (final row in rows) {
      final vector = (jsonDecode(row['embedding'] as String) as List)
          .map((v) => (v as num).toDouble())
          .toList();
      final score = cosineSimilarity(queryVector, vector);
      if (score >= minScore) {
        scored.add((entry: _rowToEntry(row), score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return [for (final s in scored.take(limit)) s.entry];
  }

  /// The most recent memories, ignoring relevance. Useful as trip context.
  Future<List<MemoryEntry>> recent({int limit = 5}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT id, agent_id, content, tags, memory_type, created_at
      FROM memories
      WHERE agent_id = ?
      ORDER BY created_at DESC
      LIMIT ?
      ''',
      [agentId, limit],
    );
    return rows.map(_rowToEntry).toList();
  }

  Future<int> count() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM memories WHERE agent_id = ?',
      [agentId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Remove every memory for this agent. Returns how many rows were deleted.
  Future<int> clearAll() async {
    final removed = await _db.delete(
      'memories',
      where: 'agent_id = ?',
      whereArgs: [agentId],
    );
    await _db.delete('memories_fts');
    await _db.delete('memory_vectors');
    return removed;
  }

  /// Delete a memory by id. Returns true if a row was removed.
  Future<bool> forget(String id) async {
    final removed = await _db.delete(
      'memories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (_ftsAvailable) {
      await _db.delete('memories_fts', where: 'id = ?', whereArgs: [id]);
    }
    await _db.delete('memory_vectors', where: 'memory_id = ?', whereArgs: [id]);
    return removed > 0;
  }

  Future<void> close() => _db.close();

  MemoryEntry _rowToEntry(Map<String, Object?> row) {
    final tagsJson = row['tags'] as String? ?? '[]';
    return MemoryEntry(
      id: row['id'] as String,
      agentId: row['agent_id'] as String,
      content: row['content'] as String,
      tags: (jsonDecode(tagsJson) as List).cast<String>(),
      type: row['memory_type'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }
}

/// Build an FTS5 MATCH expression from a query plus any extra tag terms,
/// OR-joined. The query is split into keyword tokens (stopwords and very short
/// words dropped) so natural-language questions still match — unlike nexo-rs,
/// which quotes the whole query as one phrase.
String buildFtsMatch(String query, List<String> extraTags) {
  final parts = <String>[];
  for (final token in _tokenize(query)) {
    final q = ftsQuote(token);
    if (q.isNotEmpty && !parts.contains(q)) parts.add(q);
  }
  for (final tag in extraTags) {
    final t = ftsQuote(tag);
    if (t.isNotEmpty && !parts.contains(t)) parts.add(t);
  }
  // FTS5 MATCH cannot be empty; a quoted-empty sentinel matches nothing.
  if (parts.isEmpty) return '""';
  return parts.join(' OR ');
}

Iterable<String> _tokenize(String query) sync* {
  for (final raw in query.toLowerCase().split(RegExp('[^a-z0-9]+'))) {
    if (raw.length < 2 || _stopwords.contains(raw)) continue;
    yield raw;
  }
}

/// Common English function words dropped from recall queries so they don't
/// match every memory.
const Set<String> _stopwords = {
  'the',
  'a',
  'an',
  'and',
  'or',
  'of',
  'to',
  'in',
  'on',
  'at',
  'for',
  'is',
  'are',
  'was',
  'were',
  'be',
  'am',
  'do',
  'does',
  'did',
  'how',
  'what',
  'which',
  'where',
  'when',
  'why',
  'who',
  'it',
  'its',
  'this',
  'that',
  'these',
  'those',
  'i',
  'you',
  'he',
  'she',
  'we',
  'they',
  'me',
  'my',
  'your',
  'our',
  'their',
  'with',
  'as',
  'by',
  'from',
  'about',
};

/// Escape a term as an FTS5 phrase: double internal quotes, then wrap in
/// quotes so operators (AND, *, parens) in user input are treated as literals.
String ftsQuote(String term) {
  final trimmed = term.trim();
  if (trimmed.isEmpty) return '';
  final escaped = trimmed.replaceAll('"', '""');
  return '"$escaped"';
}
