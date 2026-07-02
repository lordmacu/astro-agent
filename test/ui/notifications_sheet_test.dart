import 'package:astro/brain/astro_brain_provider.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/notification_summarizer.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:astro/platform/notifications_reader.dart';
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

  testWidgets('reloads on app resume so newly-granted notifications appear', (
    tester,
  ) async {
    // Empty on first read (no access yet), then a notification after the user
    // grants access in system settings and returns to the app.
    final reader = _SequenceReader([
      const [],
      const [
        NotificationSummary(app: 'WhatsApp', title: 'Ana', text: '¿Vienes?'),
      ],
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceLangProvider.overrideWithValue(AppLang.es)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showNotificationsSheet(
                  context,
                  onSpeak: (_) {},
                  reader: reader,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // No notifications shown before access is granted.
    expect(find.textContaining('WhatsApp'), findsNothing);

    // The user granted access in system settings and returned to the app.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // The panel re-read and now shows the notification (no stale grant text).
    expect(find.textContaining('WhatsApp'), findsWidgets);
  });

  testWidgets('hides notifications already seen before `since`', (
    tester,
  ) async {
    final reader = _SequenceReader([
      [
        NotificationSummary(
          app: 'OldApp',
          title: 'old',
          text: 'seen before',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
        NotificationSummary(
          app: 'NewApp',
          title: 'new',
          text: 'arrived after',
          time: DateTime.fromMillisecondsSinceEpoch(5000),
        ),
      ],
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceLangProvider.overrideWithValue(AppLang.es)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showNotificationsSheet(
                  context,
                  onSpeak: (_) {},
                  reader: reader,
                  since: DateTime.fromMillisecondsSinceEpoch(3000),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Only the notification newer than `since` is shown.
    expect(find.textContaining('NewApp'), findsWidgets);
    expect(find.textContaining('OldApp'), findsNothing);
  });
}

/// Returns each canned response in order; sticks on the last once exhausted.
class _SequenceReader implements NotificationsReader {
  _SequenceReader(this._responses);
  final List<List<NotificationSummary>> _responses;
  int _call = 0;

  @override
  Future<List<NotificationSummary>> recent({int count = 5}) async {
    final i = _call < _responses.length ? _call : _responses.length - 1;
    _call++;
    return _responses[i];
  }
}
