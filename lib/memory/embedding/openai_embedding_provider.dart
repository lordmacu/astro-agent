import 'dart:convert';

import 'package:http/http.dart' as http;

import 'embedding_provider.dart';

/// OpenAI-compatible embeddings: POST `{base}/embeddings`, body
/// `{model, input: [...]}`, bearer auth. Works for OpenAI and any gateway with
/// the same shape. Ported from the nexo-rs OpenAI `embed` path.
class OpenAiEmbeddingProvider implements EmbeddingProvider {
  OpenAiEmbeddingProvider({
    required this.apiKey,
    this.model = 'text-embedding-3-small',
    this.baseUrl = 'https://api.openai.com/v1',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client _http;

  @override
  String get id => 'openai';

  @override
  Future<List<double>> embedOne(String text) async =>
      (await embed([text])).first;

  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    final resp = await _http.post(
      Uri.parse('$baseUrl/embeddings'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({'model': model, 'input': texts}),
    );

    if (resp.statusCode >= 400) {
      throw Exception(
        'embedding provider error ${resp.statusCode}: ${resp.body}',
      );
    }

    final decoded =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final data = (decoded['data'] as List).cast<Map<String, dynamic>>();
    // The API may return rows out of order; sort by `index` to match inputs.
    data.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    return [
      for (final row in data)
        (row['embedding'] as List).map((v) => (v as num).toDouble()).toList(),
    ];
  }
}
