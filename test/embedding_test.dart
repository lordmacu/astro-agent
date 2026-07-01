import 'dart:convert';

import 'package:astro/memory/embedding/embedding_provider.dart';
import 'package:astro/memory/embedding/openai_embedding_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('cosineSimilarity', () {
    test('identical vectors score 1', () {
      expect(cosineSimilarity([1, 2, 3], [1, 2, 3]), closeTo(1.0, 1e-9));
    });
    test('orthogonal vectors score 0', () {
      expect(cosineSimilarity([1, 0], [0, 1]), 0);
    });
    test('mismatched or empty vectors score 0', () {
      expect(cosineSimilarity([1, 0], [1]), 0);
      expect(cosineSimilarity([], []), 0);
    });
  });

  group('OpenAiEmbeddingProvider', () {
    test('posts model + input and returns vectors in input order', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'data': [
              // Intentionally out of order; the provider sorts by index.
              {
                'index': 1,
                'embedding': [0.0, 1.0],
              },
              {
                'index': 0,
                'embedding': [1.0, 0.0],
              },
            ],
          }),
          200,
        );
      });

      final provider = OpenAiEmbeddingProvider(apiKey: 'k', httpClient: mock);
      final vectors = await provider.embed(['first', 'second']);

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(captured.url.toString(), 'https://api.openai.com/v1/embeddings');
      expect(captured.headers['authorization'], 'Bearer k');
      expect(body['input'], ['first', 'second']);
      expect(vectors, [
        [1.0, 0.0],
        [0.0, 1.0],
      ]);
    });

    test('a 4xx throws', () async {
      final mock = MockClient((_) async => http.Response('no', 401));
      final provider = OpenAiEmbeddingProvider(apiKey: 'bad', httpClient: mock);
      expect(() => provider.embed(['x']), throwsException);
    });
  });
}
