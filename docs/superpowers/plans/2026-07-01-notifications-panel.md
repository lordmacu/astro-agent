# Notifications Panel with AI Summary — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bell icon (with unread badge) next to the settings gear that opens a modal listing captured notifications grouped by app, where tapping a group or an item asks the AI to summarize them (shown as text and spoken by Astro).

**Architecture:** A dedicated `NotificationSummarizer` (mirrors `MemoryExtractor`) makes one tool-less LLM call. A bottom-sheet UI (`showNotificationsSheet`) reads the existing native ring-buffer via `NotificationsReader`, groups by app with pure helpers, and calls the summarizer on demand. `pet_screen` hosts the bell + badge and wires the spoken output to its existing `_say` voice path.

**Tech Stack:** Flutter, Riverpod 2, the project's `LlmClient`/`LlmRequest` abstraction, `flutter_test`.

## Global Constraints

- Code (identifiers, comments) in **English**; user-facing copy is bilingual via `Strings._pick(l, en:, es:)`.
- `dart format .` and `flutter analyze` must be clean before a task is done.
- Free models are keyless; the summarizer must reuse `_llmClientFor(ref, model)` + `astroModelProvider` so it works with the free/paid model already selected.
- No changes to native notification capture; no new persistence beyond one `notificationsSeenAt` marker in `SharedPreferences`.
- Not routed through the agentic brain (no tools, no conversation history).

---

### Task 1: Pure notification helpers + seen marker

**Files:**
- Create: `lib/platform/notifications_grouping.dart`
- Modify: `lib/core/config/setting_key.dart` (add one enum value)
- Test: `test/platform/notifications_grouping_test.dart`

**Interfaces:**
- Consumes: `NotificationSummary` from `lib/platform/notifications_reader.dart` (fields: `String app`, `String? title`, `String? text`, `DateTime? time`).
- Produces:
  - `Map<String, List<NotificationSummary>> groupNotificationsByApp(List<NotificationSummary> items)` — groups sorted by most-recent item first; items within a group newest-first.
  - `int unreadCount(List<NotificationSummary> items, DateTime since)` — count of items strictly newer than `since`.
  - `SettingKey.notificationsSeenAt`.

- [ ] **Step 1: Write the failing test**

Create `test/platform/notifications_grouping_test.dart`:

```dart
import 'package:astro/platform/notifications_grouping.dart';
import 'package:astro/platform/notifications_reader.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationSummary _n(String app, int ms, {String? title, String? text}) =>
    NotificationSummary(
      app: app,
      title: title,
      text: text,
      time: DateTime.fromMillisecondsSinceEpoch(ms),
    );

void main() {
  test('groups by app, newest group and newest item first', () {
    final items = [_n('A', 3000), _n('B', 5000), _n('A', 1000)];
    final groups = groupNotificationsByApp(items);
    expect(groups.keys.toList(), ['B', 'A']); // B is newest (5000)
    expect(
      groups['A']!.map((e) => e.time!.millisecondsSinceEpoch).toList(),
      [3000, 1000], // newest first within the group
    );
  });

  test('unreadCount counts items strictly after "since"', () {
    final items = [_n('A', 1000), _n('A', 3000), _n('B', 5000)];
    final since = DateTime.fromMillisecondsSinceEpoch(2000);
    expect(unreadCount(items, since), 2); // 3000 and 5000
  });

  test('unreadCount ignores items without a timestamp', () {
    final items = [
      const NotificationSummary(app: 'A'), // no time
      _n('B', 5000),
    ];
    expect(unreadCount(items, DateTime.fromMillisecondsSinceEpoch(0)), 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/platform/notifications_grouping_test.dart`
Expected: FAIL — `notifications_grouping.dart` does not exist / functions undefined.

- [ ] **Step 3: Write the implementation**

Create `lib/platform/notifications_grouping.dart`:

```dart
import 'notifications_reader.dart';

/// Milliseconds for sorting; a missing timestamp sorts oldest.
int _ms(NotificationSummary n) => n.time?.millisecondsSinceEpoch ?? 0;

/// Group notifications by their app label. Groups are ordered by their most
/// recent notification first; within each group, items are newest-first.
Map<String, List<NotificationSummary>> groupNotificationsByApp(
  List<NotificationSummary> items,
) {
  final groups = <String, List<NotificationSummary>>{};
  for (final n in items) {
    (groups[n.app] ??= []).add(n);
  }
  for (final list in groups.values) {
    list.sort((a, b) => _ms(b).compareTo(_ms(a)));
  }
  final keys = groups.keys.toList()
    ..sort((a, b) => _ms(groups[b]!.first).compareTo(_ms(groups[a]!.first)));
  return {for (final k in keys) k: groups[k]!};
}

/// How many notifications arrived strictly after [since] (used for the badge).
int unreadCount(List<NotificationSummary> items, DateTime since) =>
    items.where((n) => n.time != null && n.time!.isAfter(since)).length;
```

- [ ] **Step 4: Add the setting key**

In `lib/core/config/setting_key.dart`, add `notificationsSeenAt` as the last enum value (after `hapticsEnabled`):

```dart
  hapticsEnabled,
  notificationsSeenAt,
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/platform/notifications_grouping_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/platform/notifications_grouping.dart lib/core/config/setting_key.dart test/platform/notifications_grouping_test.dart
flutter analyze lib/platform/notifications_grouping.dart lib/core/config/setting_key.dart
git add lib/platform/notifications_grouping.dart lib/core/config/setting_key.dart test/platform/notifications_grouping_test.dart
git commit -m "feat(notifications): grouping + unread helpers and seen-at key"
```

---

### Task 2: NotificationSummarizer + provider

**Files:**
- Create: `lib/brain/notification_summarizer.dart`
- Modify: `lib/brain/astro_brain_provider.dart` (add provider)
- Test: `test/brain/notification_summarizer_test.dart`

**Interfaces:**
- Consumes: `LlmClient`, `LlmRequest`, `LlmResponse`, `LlmMessage`, `Role`, `TextBlock` from `lib/brain/llm/`; `NotificationSummary` from `lib/platform/notifications_reader.dart`; `AppLang` from `lib/core/l10n/app_lang.dart`; private `_llmClientFor(Ref, String)` and `astroModelProvider` in `astro_brain_provider.dart`.
- Produces:
  - `class NotificationSummarizer { NotificationSummarizer({required LlmClient client, required String model}); Future<String> summarize(List<NotificationSummary> items, {required AppLang lang, String? app}); }`
  - `final notificationSummarizerProvider = Provider<NotificationSummarizer>(...)`.

- [ ] **Step 1: Write the failing test**

Create `test/brain/notification_summarizer_test.dart`:

```dart
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
  test('summarize sends a tool-less request with the notification text', () async {
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
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/brain/notification_summarizer_test.dart`
Expected: FAIL — `notification_summarizer.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/brain/notification_summarizer.dart`:

```dart
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
        messages: [LlmMessage.text(Role.user, _prompt(items, lang: lang, app: app))],
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
      b.writeln(app != null
          ? 'Resume estas notificaciones de $app:'
          : 'Resume estas notificaciones:');
    } else {
      b.writeln(app != null
          ? 'Summarize these notifications from $app:'
          : 'Summarize these notifications:');
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
```

- [ ] **Step 4: Add the provider**

In `lib/brain/astro_brain_provider.dart`, add the import near the other `llm/` imports:

```dart
import 'llm/kilo_models.dart';
import 'notification_summarizer.dart';
```

Then add the provider right after `astroModelProvider` (and its `_Fallback` extension):

```dart
/// Summarizer for the notifications panel. Uses the same client/model as the
/// brain (keyless Kilo for free models), but a single tool-less call.
final notificationSummarizerProvider = Provider<NotificationSummarizer>((ref) {
  final model = ref.watch(astroModelProvider);
  return NotificationSummarizer(client: _llmClientFor(ref, model), model: model);
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/brain/notification_summarizer_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/brain/notification_summarizer.dart lib/brain/astro_brain_provider.dart test/brain/notification_summarizer_test.dart
flutter analyze lib/brain/notification_summarizer.dart lib/brain/astro_brain_provider.dart
git add lib/brain/notification_summarizer.dart lib/brain/astro_brain_provider.dart test/brain/notification_summarizer_test.dart
git commit -m "feat(notifications): dedicated AI summarizer + provider"
```

---

### Task 3: Notifications modal sheet

**Files:**
- Create: `lib/ui/notifications_sheet.dart`
- Modify: `lib/core/l10n/strings.dart` (add 5 strings)
- Test: `test/ui/notifications_sheet_test.dart`

**Interfaces:**
- Consumes: `groupNotificationsByApp` (Task 1), `notificationSummarizerProvider` (Task 2), `NotificationsReader`/`NotificationSummary`, `langProvider`, `Strings`, `DesignTokens`, `Permissions`.
- Produces: `Future<void> showNotificationsSheet(BuildContext context, {required void Function(String summary) onSpeak, NotificationsReader reader = const NotificationsReader()})`.

- [ ] **Step 1: Add the strings**

In `lib/core/l10n/strings.dart`, add these methods (anywhere inside the `Strings` class, e.g. after `customModelLabel`):

```dart
  static String notificationsTitle(AppLang l) =>
      _pick(l, en: 'Notifications', es: 'Notificaciones');
  static String summarize(AppLang l) =>
      _pick(l, en: 'Summarize', es: 'Resumir');
  static String noNotifications(AppLang l) =>
      _pick(l, en: 'Nothing new.', es: 'Nada nuevo.');
  static String grantNotifications(AppLang l) => _pick(
    l,
    en: 'Allow notification access',
    es: 'Dar acceso a notificaciones',
  );
  static String notifSummaryError(AppLang l) =>
      _pick(l, en: "I couldn't read that.", es: 'No pude leer eso.');
```

- [ ] **Step 2: Write the failing test**

Create `test/ui/notifications_sheet_test.dart`:

```dart
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
          {'app': 'WhatsApp', 'title': 'Ana', 'text': '¿Vienes?', 'time': 1000},
        ];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('astro/notifications'), null);
  });

  testWidgets('summarizing a group shows text and calls onSpeak', (tester) async {
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/ui/notifications_sheet_test.dart`
Expected: FAIL — `notifications_sheet.dart` does not exist.

- [ ] **Step 4: Write the sheet**

Create `lib/ui/notifications_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../brain/notification_summarizer.dart';
import '../core/config/design_tokens.dart';
import '../core/l10n/app_lang.dart';
import '../core/l10n/lang_provider.dart';
import '../core/l10n/strings.dart';
import '../platform/notifications_grouping.dart';
import '../platform/notifications_reader.dart';
import '../platform/permissions.dart';

/// Show the notifications panel. [onSpeak] receives each AI summary so the
/// caller can voice it. [reader] is injectable for tests.
Future<void> showNotificationsSheet(
  BuildContext context, {
  required void Function(String summary) onSpeak,
  NotificationsReader reader = const NotificationsReader(),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DesignTokens.bgBottomFallback,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _NotificationsSheet(onSpeak: onSpeak, reader: reader),
  );
}

class _NotificationsSheet extends ConsumerStatefulWidget {
  const _NotificationsSheet({required this.onSpeak, required this.reader});
  final void Function(String summary) onSpeak;
  final NotificationsReader reader;
  @override
  ConsumerState<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<_NotificationsSheet> {
  Map<String, List<NotificationSummary>>? _groups; // null = loading
  final _summaries = <String, String>{};
  final _loading = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.reader.recent(40);
    if (!mounted) return;
    setState(() => _groups = groupNotificationsByApp(items));
  }

  Future<void> _summarize(
    String key,
    String app,
    List<NotificationSummary> items,
  ) async {
    final lang = ref.read(langProvider);
    setState(() => _loading.add(key));
    try {
      final summary = await ref
          .read(notificationSummarizerProvider)
          .summarize(items, lang: lang, app: app);
      if (!mounted) return;
      setState(() => _summaries[key] = summary);
      widget.onSpeak(summary);
    } on Object {
      if (!mounted) return;
      setState(() => _summaries[key] = Strings.notifSummaryError(lang));
    } finally {
      if (mounted) setState(() => _loading.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final groups = _groups;
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Strings.notificationsTitle(lang),
            style: const TextStyle(
              color: DesignTokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (groups == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (groups.isEmpty)
            _EmptyState(lang: lang, onGranted: _load)
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in groups.entries)
                    _AppGroup(
                      app: entry.key,
                      items: entry.value,
                      lang: lang,
                      summaries: _summaries,
                      loading: _loading,
                      onSummarizeGroup: () =>
                          _summarize('g:${entry.key}', entry.key, entry.value),
                      onSummarizeItem: (i) => _summarize(
                        'i:${entry.key}#$i',
                        entry.key,
                        [entry.value[i]],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AppGroup extends StatelessWidget {
  const _AppGroup({
    required this.app,
    required this.items,
    required this.lang,
    required this.summaries,
    required this.loading,
    required this.onSummarizeGroup,
    required this.onSummarizeItem,
  });

  final String app;
  final List<NotificationSummary> items;
  final AppLang lang;
  final Map<String, String> summaries;
  final Set<String> loading;
  final VoidCallback onSummarizeGroup;
  final void Function(int index) onSummarizeItem;

  @override
  Widget build(BuildContext context) {
    final groupKey = 'g:$app';
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        collapsedIconColor: DesignTokens.dim,
        iconColor: DesignTokens.accent,
        title: Text(
          '$app (${items.length})',
          style: const TextStyle(color: DesignTokens.ink),
        ),
        trailing: loading.contains(groupKey)
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onSummarizeGroup,
                child: Text(Strings.summarize(lang)),
              ),
        children: [
          if (summaries[groupKey] != null) _SummaryBox(text: summaries[groupKey]!),
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              title: Text(
                items[i].title ?? items[i].app,
                style: const TextStyle(color: DesignTokens.ink, fontSize: 14),
              ),
              subtitle: Text(
                items[i].text ?? '',
                style: const TextStyle(color: DesignTokens.dim, fontSize: 12),
              ),
              trailing: loading.contains('i:$app#$i')
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.auto_awesome,
                      color: DesignTokens.dim,
                      size: 18,
                    ),
              onTap: () => onSummarizeItem(i),
            ),
            if (summaries['i:$app#$i'] != null)
              _SummaryBox(text: summaries['i:$app#$i']!),
          ],
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: DesignTokens.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(color: DesignTokens.ink, fontSize: 13),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lang, required this.onGranted});
  final AppLang lang;
  final Future<void> Function() onGranted;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Text(
          Strings.noNotifications(lang),
          style: const TextStyle(color: DesignTokens.dim),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await const Permissions().requestNotifications();
            await onGranted();
          },
          child: Text(Strings.grantNotifications(lang)),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/ui/notifications_sheet_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/ui/notifications_sheet.dart lib/core/l10n/strings.dart test/ui/notifications_sheet_test.dart
flutter analyze lib/ui/notifications_sheet.dart lib/core/l10n/strings.dart
git add lib/ui/notifications_sheet.dart lib/core/l10n/strings.dart test/ui/notifications_sheet_test.dart
git commit -m "feat(notifications): grouped panel modal with AI summary"
```

---

### Task 4: Bell icon + badge in pet_screen

**Files:**
- Modify: `lib/ui/pet_screen.dart`
- Test: `test/ui/pet_screen_notifications_test.dart`

**Interfaces:**
- Consumes: `showNotificationsSheet` (Task 3), `unreadCount` (Task 1), `NotificationsReader`, `settingsStoreProvider` + `SettingKey.notificationsSeenAt`, `voiceControllerProvider`, and the existing `_say(String, VoiceController)` method.
- Produces: nothing downstream (final task).

- [ ] **Step 1: Add imports**

In `lib/ui/pet_screen.dart`, add near the other imports:

```dart
import '../core/config/setting_key.dart';
import '../core/config/settings_providers.dart';
import '../platform/notifications_reader.dart';
import '../platform/notifications_grouping.dart';
import 'notifications_sheet.dart';
```

(`dart:async` and `voice_controller.dart` are already imported.)

- [ ] **Step 2: Add badge state + lifecycle**

In `_PetScreenState`, add fields near the other state (e.g. next to `String _spokenText = '';`):

```dart
  int _unreadNotifs = 0;
  Timer? _notifBadgeTimer;
```

In `initState()`, after the existing setup, add:

```dart
    _refreshUnread();
    _notifBadgeTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _refreshUnread());
```

In `dispose()`, before `super.dispose()`, add:

```dart
    _notifBadgeTimer?.cancel();
```

- [ ] **Step 3: Add the badge refresh + open methods**

Add these methods to `_PetScreenState`:

```dart
  Future<void> _refreshUnread() async {
    final items = await const NotificationsReader().recent(40);
    if (!mounted) return;
    final seenMs = ref
        .read(settingsStoreProvider)
        .getDouble(SettingKey.notificationsSeenAt, 0);
    final since = DateTime.fromMillisecondsSinceEpoch(seenMs.toInt());
    setState(() => _unreadNotifs = unreadCount(items, since));
  }

  Future<void> _openNotifications() async {
    await ref.read(settingsStoreProvider).setDouble(
      SettingKey.notificationsSeenAt,
      DateTime.now().millisecondsSinceEpoch.toDouble(),
    );
    if (mounted) setState(() => _unreadNotifs = 0);
    final controller = ref.read(voiceControllerProvider.notifier);
    await showNotificationsSheet(
      context,
      onSpeak: (summary) => _say(summary, controller),
    );
    await _refreshUnread();
  }
```

- [ ] **Step 4: Add the bell icon to the top-right Row**

In the top-right `Row` (around line 927, the one holding the `help_outline` and `settings` `IconButton`s), add the bell as the **first** child, before the `help_outline` button:

```dart
                  children: [
                    IconButton(
                      key: const Key('notifications-button'),
                      icon: _unreadNotifs > 0
                          ? Badge(
                              label: Text('$_unreadNotifs'),
                              child: const Icon(Icons.notifications_none),
                            )
                          : const Icon(Icons.notifications_none),
                      color: accent,
                      onPressed: _openNotifications,
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      color: accent,
                      onPressed: () => setState(() => _showCommands = true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      color: accent,
                      onPressed: _openSettings,
                    ),
                  ],
```

- [ ] **Step 5: Write the widget test**

Create `test/ui/pet_screen_notifications_test.dart`:

```dart
import 'dart:async';

import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/state/app_state.dart';
import 'package:astro/core/state/app_state_provider.dart';
import 'package:astro/ui/pet_screen.dart';
import 'package:astro/voice/stt_provider.dart';
import 'package:astro/voice/voice_interfaces.dart';
import 'package:astro/voice/wake_word_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWake implements WakeWordDetector {
  final _wakes = StreamController<void>.broadcast();
  @override
  Stream<void> get onWake => _wakes.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> setKeyword(String keyword) async {}
  @override
  Future<void> setSensitivity(double value) async {}
}

class _FakeRecognizer implements SpeechRecognizer {
  @override
  Future<String?> listen({Duration? pauseFor, bool shortReply = false}) async =>
      null;
  @override
  Future<void> stop() async {}
  @override
  Future<bool> warmUp() async => true;
  @override
  set onListening(void Function()? cb) {}
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('astro/notifications'), (
      call,
    ) async => call.method == 'getRecent' ? const [] : null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('astro/notifications'), null);
  });

  testWidgets('bell opens the notifications sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          wakeWordProvider.overrideWithValue(_FakeWake()),
          speechRecognizerProvider.overrideWithValue(_FakeRecognizer()),
          appStateProvider.overrideWith((ref) => Stream.value(const AppState())),
        ],
        child: const MaterialApp(home: PetScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('notifications-button')));
    await tester.pumpAndSettle();

    // The sheet title appears (empty buffer → "Nada nuevo" also shows).
    expect(find.text('Notifications'), findsOneWidget);
  });
}
```

Note: the default device locale in tests is English, so the title is `Notifications`. If the harness forces Spanish, change the expectation to `Notificaciones`.

- [ ] **Step 6: Run the test**

Run: `flutter test test/ui/pet_screen_notifications_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, full test, commit**

```bash
dart format lib/ui/pet_screen.dart test/ui/pet_screen_notifications_test.dart
flutter analyze lib/ui/pet_screen.dart
flutter test
git add lib/ui/pet_screen.dart test/ui/pet_screen_notifications_test.dart
git commit -m "feat(notifications): bell icon with unread badge in pet screen"
```

---

## Self-review notes

- **Spec coverage:** entry point + badge (Task 4), modal grouped by app (Task 3), group + item summary with text+voice (Task 3 + Task 4 `onSpeak`), dedicated summarizer keyless (Task 2), pure helpers (Task 1), tests each task. All spec sections covered.
- **Types consistent:** `groupNotificationsByApp`/`unreadCount` signatures identical across tasks; `summarize(items, {lang, app})` and `notificationSummarizerProvider` used verbatim in Task 3/4; `showNotificationsSheet(context, {onSpeak, reader})` matches its call in Task 4.
- **Manual verification (device):** grant notification-listener permission, receive a couple of notifications, open the bell, confirm grouping, tap "Resumir" and an item, confirm text appears and Astro speaks; confirm badge counts new ones and clears on open.
