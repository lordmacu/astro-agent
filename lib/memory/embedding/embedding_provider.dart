import 'dart:math' as math;

/// Turns text into dense vectors for semantic memory. Provider-agnostic, like
/// `LlmClient`: a cloud embeddings API implements this once. Ported in spirit
/// from the nexo-rs `EmbeddingProvider`.
abstract interface class EmbeddingProvider {
  /// Short id for logs ("openai").
  String get id;

  /// Embed a batch of texts, returning one vector per input, in order.
  Future<List<List<double>>> embed(List<String> texts);

  /// Convenience: embed a single text.
  Future<List<double>> embedOne(String text) async => (await embed([text]))
      .first;
}

/// Cosine similarity in [-1, 1]; 0 when either vector is empty, zero, or the
/// lengths differ. The vector search runs in Dart (no `sqlite-vec` extension),
/// which is plenty for a pet's memory size.
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 0;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denom = math.sqrt(normA) * math.sqrt(normB);
  return denom == 0 ? 0 : dot / denom;
}
