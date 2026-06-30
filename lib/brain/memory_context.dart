import '../memory/long_term_memory.dart';

/// Builds the memory-context block injected into the brain's system prompt each
/// turn. Uses semantic recall when an embedder is available, otherwise
/// full-text recall. Wire it as `ChispaBrain(recallContext: MemoryContext(mem).call)`.
class MemoryContext {
  MemoryContext(this.memory, {this.limit = 5});

  final LongTermMemory memory;
  final int limit;

  Future<String?> call(String userText) async {
    if (userText.trim().isEmpty) return null;

    final hits = memory.hasEmbedder
        ? await memory.recallSemantic(userText, limit: limit)
        : await memory.recall(userText, limit: limit);
    if (hits.isEmpty) return null;

    final buffer = StringBuffer('What Chispa remembers that may be relevant:');
    for (final hit in hits) {
      buffer.write('\n- ${hit.content}');
    }
    return buffer.toString();
  }
}
