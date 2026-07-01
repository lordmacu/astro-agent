/// One stored memory. Ported from the nexo-rs `MemoryEntry`, trimmed to what
/// Astro needs (no concept_tags / embeddings yet).
class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.agentId,
    required this.content,
    required this.createdAt,
    this.tags = const [],
    this.type,
  });

  final String id;
  final String agentId;
  final String content;
  final DateTime createdAt;
  final List<String> tags;

  /// Optional category, e.g. "trip", "preference", "fact".
  final String? type;
}
