import '../core/l10n/app_lang.dart';
import '../platform/notifications_reader.dart';
import 'llm/llm_client.dart';
import 'llm/llm_message.dart';

const String _systemEs =
    'Eres Astro. En 1 o 2 frases cortas, en español de Colombia, cuenta qué '
    'pasó en estas notificaciones. Habla natural, como para leer en voz alta. '
    'Nada de listas ni markdown. No inventes lo que no esté.';

const String _systemEn =
    'You are Astro. In 1 or 2 short sentences, in natural English, say what '
    'happened in these notifications. Speak naturally, to be read aloud. No '
    'lists, no markdown. Do not make up anything that is not there.';

/// One tool-less LLM pass that summarizes a set of notifications for the panel.
/// Mirrors [MemoryExtractor]: a dedicated summarizer, not the agentic brain, so
/// it never calls tools or touches conversation history.
class NotificationSummarizer {
  NotificationSummarizer({required this.client, required this.model});

  final LlmClient client;
  final String model;

  /// Summarize [items]. Pass [app] for a per-app group summary (used in the
  /// prompt), or omit it for an ad-hoc set. Returns the spoken-style text.
  Future<String> summarize(
    List<NotificationSummary> items, {
    required AppLang lang,
    String? app,
  }) async {
    final response = await client.complete(
      LlmRequest(
        model: model,
        system: lang == AppLang.es ? _systemEs : _systemEn,
        messages: [
          LlmMessage.text(Role.user, _prompt(items, lang: lang, app: app)),
        ],
        maxTokens: 400,
        temperature: 0.3,
      ),
    );
    return response.message.blocks
        .whereType<TextBlock>()
        .map((b) => b.text)
        .join('\n')
        .trim();
  }

  String _prompt(
    List<NotificationSummary> items, {
    required AppLang lang,
    String? app,
  }) {
    final b = StringBuffer();
    if (lang == AppLang.es) {
      b.writeln(
        app != null
            ? 'Resume estas notificaciones de $app:'
            : 'Resume estas notificaciones:',
      );
    } else {
      b.writeln(
        app != null
            ? 'Summarize these notifications from $app:'
            : 'Summarize these notifications:',
      );
    }
    for (final n in items) {
      final parts = [
        (n.title ?? '').trim(),
        (n.text ?? '').trim(),
      ].where((s) => s.isNotEmpty).join(': ');
      b.writeln('- [${n.app}] $parts');
    }
    return b.toString().trim();
  }
}
