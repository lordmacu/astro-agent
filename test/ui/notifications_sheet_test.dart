import 'package:astro/brain/astro_brain_provider.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/notification_summarizer.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:astro/ui/notifications_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedClient implements LlmClient {
  @override
  String get providerId => 'fake';
  @override
  Future<LlmResponse> complete(LlmRequest request) async => LlmResponse(
    message: LlmMessage.text(Role.assistant, 'Ana te escribió.'),
    stopReason: StopReason.endTurn,
  );
  @override
  Stream<LlmStreamChunk> completeStream(LlmRequest request) =>
      streamViaComplete(complete(request));
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('astro/notifications'), (
          call,
        ) async {
          if (call.method == 'getRecent') {
            return [
              {
                'app': 'WhatsApp',
                'title': 'Ana',
                'text': '¿Vienes?',
                'time': 1000,
              },
            ];
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('astro/notifications'),
          null,
        );
  });

  testWidgets('summarizing a group shows text and calls onSpeak', (
    tester,
  ) async {
    final spoken = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceLangProvider.overrideWithValue(AppLang.es),
          notificationSummarizerProvider.overrideWithValue(
            NotificationSummarizer(client: _FixedClient(), model: 'm'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showNotificationsSheet(context, onSpeak: spoken.add),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The app group is shown.
    expect(find.textContaining('WhatsApp'), findsWidgets);

    // Tap "Resumir" (group header button).
    await tester.tap(find.text('Resumir').first);
    await tester.pumpAndSettle();

    expect(find.text('Ana te escribió.'), findsOneWidget); // shown in modal
    expect(spoken, ['Ana te escribió.']); // spoken via callback
  });
}
