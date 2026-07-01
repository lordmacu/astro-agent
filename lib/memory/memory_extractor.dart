import 'dart:convert';

import '../brain/llm/llm_client.dart';
import '../brain/llm/llm_message.dart';
import 'long_term_memory.dart';
import 'memory_entry.dart';

/// System instruction for the extraction pass. Ported in spirit from the
/// nexo-rs memory-extraction prompt, retargeted from MEMORY.md files to
/// Astro's SQLite rows and the in-car domain.
const String kMemoryExtractionSystemPrompt = '''
You are Astro's memory extractor. From the conversation, pull out durable facts
worth remembering across future drives: the driver's preferences, names,
recurring routes or places, car quirks, and anything the driver explicitly asks
you to remember.

Do NOT save: transient trip state (current speed, today's weather, one-off
chit-chat), facts already obvious, or sensitive data you were not asked to keep.

Return ONLY a JSON array, nothing else. Each item:
{"content": "<one short sentence>", "type": "<preference|route|car|person|fact>",
 "tags": ["<optional labels>"]}
Return [] when there is nothing worth saving.''';

/// One memory the model proposed to save.
class ExtractedMemory {
  const ExtractedMemory({
    required this.content,
    this.type,
    this.tags = const [],
  });

  final String content;
  final String? type;
  final List<String> tags;
}

/// LLM-driven memory extraction: read a conversation, decide what is worth
/// keeping, and write it to long-term memory. Lets Astro learn over time
/// without the driver saying "remember this".
class MemoryExtractor {
  MemoryExtractor({
    required this.client,
    required this.memory,
    required this.model,
  });

  final LlmClient client;
  final LongTermMemory memory;
  final String model;

  /// Extract durable memories from [transcript] and store them. Returns the
  /// stored entries (empty when the model found nothing or the reply was
  /// unparseable). Pass [existing] (e.g. recent memory contents) to discourage
  /// duplicates.
  Future<List<MemoryEntry>> extractAndStore(
    String transcript, {
    String? existing,
  }) async {
    final response = await client.complete(
      LlmRequest(
        model: model,
        system: kMemoryExtractionSystemPrompt,
        messages: [
          LlmMessage.text(Role.user, _userPrompt(transcript, existing)),
        ],
        maxTokens: 1024,
        temperature: 0,
      ),
    );

    final text = response.message.blocks
        .whereType<TextBlock>()
        .map((b) => b.text)
        .join('\n');

    final List<ExtractedMemory> extracted;
    try {
      extracted = parseExtraction(text);
    } on FormatException {
      return const [];
    }

    final stored = <MemoryEntry>[];
    for (final m in extracted) {
      stored.add(await memory.remember(m.content, tags: m.tags, type: m.type));
    }
    return stored;
  }

  String _userPrompt(String transcript, String? existing) {
    final existingBlock = (existing == null || existing.isEmpty)
        ? ''
        : '\n\nAlready remembered (do not duplicate):\n$existing';
    return 'Conversation:\n$transcript$existingBlock';
  }
}

/// Parse the model's extraction reply into memories, tolerating a ```json
/// fence. Throws [FormatException] when the payload is not a JSON array.
List<ExtractedMemory> parseExtraction(String text) {
  var body = text.trim();
  if (body.startsWith('```')) {
    body = body.replaceFirst(RegExp(r'^```(json)?'), '').trim();
    if (body.endsWith('```')) {
      body = body.substring(0, body.length - 3).trim();
    }
  }

  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw const FormatException('expected a JSON array of memories');
  }

  return [
    for (final item in decoded)
      if (item is Map<String, dynamic>)
        ExtractedMemory(
          content: (item['content'] as String?)?.trim() ?? '',
          type: item['type'] as String?,
          tags:
              (item['tags'] as List?)?.whereType<String>().toList() ?? const [],
        ),
  ].where((m) => m.content.isNotEmpty).toList();
}
