import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/notification_summarizer.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/platform/notifications_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the request and returns a fixed answer.
class _CapturingClient implements LlmClient {
  LlmRequest? last;
  @override
  String get providerId => 'fake';
  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    last = request;
    return LlmResponse(
      message: LlmMessage.text(Role.assistant, 'Ana te preguntó si vienes.'),
      stopReason: StopReason.endTurn,
    );
  }

  @override
  Stream<LlmStreamChunk> completeStream(LlmRequest request) =>
      streamViaComplete(complete(request));
}

void main() {
  test(
    'summarize sends a tool-less request with the notification text',
    () async {
      final client = _CapturingClient();
      final summarizer = NotificationSummarizer(client: client, model: 'm');

      final answer = await summarizer.summarize(
        const [
          NotificationSummary(app: 'WhatsApp', title: 'Ana', text: '¿Vienes?'),
        ],
        lang: AppLang.es,
        app: 'WhatsApp',
      );

      expect(answer, 'Ana te preguntó si vienes.');
      expect(client.last!.tools, isEmpty); // never calls tools
      expect(client.last!.model, 'm');
      final userText = client.last!.messages
          .expand((mm) => mm.blocks)
          .whereType<TextBlock>()
          .map((b) => b.text)
          .join('\n');
      expect(userText, contains('WhatsApp'));
      expect(userText, contains('¿Vienes?'));
      expect(client.last!.system, isNotNull);
    },
  );
}
