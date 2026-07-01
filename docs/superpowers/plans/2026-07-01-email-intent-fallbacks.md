# Email Intent Fallbacks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When SMTP/IMAP is not configured, `send_email` opens a pre-filled draft in the default mail app and `read_email` opens the default mail app, instead of dead-ending.

**Architecture:** Add an async, per-call `AstroTool.requiresConfirmation` (default = `mutates`) and switch the brain's confirm gate to it, so `EmailTool` confirms only for real SMTP sends. `SystemActions` gains a `mailto:` composer and an "open mail app" intent; the two email tools call them as fallbacks when unconfigured.

**Tech Stack:** Flutter, Riverpod 2, `url_launcher` (mailto), `android_intent_plus` (open mail app) — both already dependencies used by `SystemActions`.

## Global Constraints

- Code (identifiers, comments, docs, filenames) in **English only**. UI/spoken strings are Spanish, matching the existing tools.
- Follow existing patterns: `SystemActions` intent helpers (`_tryLaunch(Uri)` for url_launcher, `_fireIntent(action, args)` / `AndroidIntent` for intents); tools inject their platform functions at construction.
- Backward compatible: `AstroTool.requiresConfirmation` defaults to `mutates`, so every other tool's confirmation behavior is unchanged.
- Android only (the app is Android-only); no iOS intent handling.
- Git identity for every commit: `user.name=lordmacu`, `user.email=10134930+lordmacu@users.noreply.github.com`. **Never** add a `Co-Authored-By` / Claude coauthor line.
- Before declaring a Dart task done: `dart format .` and `flutter analyze` with no NEW warnings (there are pre-existing info lints in unrelated parallel-WIP files — leave them).
- The repo has active parallel WIP; `git add` ONLY the files each task names. `test/widget_test.dart` ('renders the resting mood on launch') is a known pre-existing failure from parallel work — ignore only that; introduce no others.
- **These email files are actively edited by the repo owner** — the plan matches their current shape (verified). If a file differs materially at execution time, STOP and ask.

---

## Task 1: Conditional confirmation (AstroTool.requiresConfirmation + brain gate)

**Files:**
- Modify: `lib/brain/tools/astro_tool.dart`
- Modify: `lib/brain/astro_brain.dart` (the `_runTool` gate)
- Test: `test/astro_brain_test.dart` (add two tests)

**Interfaces:**
- Produces: `Future<bool> AstroTool.requiresConfirmation(Map<String, dynamic> args)` (default `async => mutates`). Brain gate uses it.

- [ ] **Step 1: Write the failing tests**

Append to `test/astro_brain_test.dart` (inside `void main() {}`; if the file already imports `astro_tool.dart`/`tool_registry.dart`/`llm_*`, reuse those imports — otherwise add them):

```dart
  group('conditional confirmation', () {
    test('a mutating tool whose requiresConfirmation is false is NOT confirmed',
        () async {
      var confirms = 0;
      final registry = ToolRegistry()..register(_ConfirmSpyTool(needs: false));
      final brain = AstroBrain(
        client: FakeLlmClient([
          LlmResponse(
            message: LlmMessage(
              role: Role.assistant,
              blocks: const [
                ToolUseBlock(id: 'c1', name: 'spy', arguments: {}),
              ],
            ),
            stopReason: StopReason.toolUse,
          ),
          LlmResponse(
            message: LlmMessage.text(Role.assistant, 'ok'),
            stopReason: StopReason.endTurn,
          ),
        ]),
        registry: registry,
        confirm: (_, __) async {
          confirms++;
          return true;
        },
      );
      await brain.ask('x', model: 'm');
      expect(confirms, 0);
    });

    test('a mutating tool whose requiresConfirmation is true IS confirmed',
        () async {
      var confirms = 0;
      final registry = ToolRegistry()..register(_ConfirmSpyTool(needs: true));
      final brain = AstroBrain(
        client: FakeLlmClient([
          LlmResponse(
            message: LlmMessage(
              role: Role.assistant,
              blocks: const [
                ToolUseBlock(id: 'c1', name: 'spy', arguments: {}),
              ],
            ),
            stopReason: StopReason.toolUse,
          ),
          LlmResponse(
            message: LlmMessage.text(Role.assistant, 'ok'),
            stopReason: StopReason.endTurn,
          ),
        ]),
        registry: registry,
        confirm: (_, __) async {
          confirms++;
          return true;
        },
      );
      await brain.ask('x', model: 'm');
      expect(confirms, 1);
    });
  });
```

And add this fake tool at the top level of the test file (after the imports, alongside the existing fakes):

```dart
/// Mutating tool whose confirmation requirement is configurable, to test the
/// brain's requiresConfirmation gate.
class _ConfirmSpyTool extends AstroTool {
  _ConfirmSpyTool({required this.needs});
  final bool needs;
  @override
  String get name => 'spy';
  @override
  String get description => 'spy';
  @override
  Map<String, dynamic> get inputSchema => const {'type': 'object'};
  @override
  bool get mutates => true;
  @override
  Future<bool> requiresConfirmation(Map<String, dynamic> args) async => needs;
  @override
  Future<ToolResult> run(Map<String, dynamic> args) async =>
      const ToolResult('done');
}
```

(Ensure the test imports `package:astro/brain/tools/astro_tool.dart`. The `FakeLlmClient` fake already exists in this file — reuse it.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/astro_brain_test.dart`
Expected: FAIL — `requiresConfirmation` isn't defined on `AstroTool`, and (before the gate change) the "not confirmed" test fails because the brain still confirms on `mutates`.

- [ ] **Step 3: Add `requiresConfirmation` to AstroTool**

In `lib/brain/tools/astro_tool.dart`, after the `mutates` getter, add:

```dart
  /// Whether THIS call needs confirmation before running. Defaults to [mutates]
  /// so existing tools are unchanged; async + per-call so a tool can decide
  /// dynamically (e.g. only when a real outward send will happen).
  Future<bool> requiresConfirmation(Map<String, dynamic> args) async => mutates;
```

- [ ] **Step 4: Switch the brain gate**

In `lib/brain/astro_brain.dart` `_runTool`, replace:

```dart
    // Policy gate: mutating tools require confirmation.
    if (tool.mutates) {
```

with:

```dart
    // Policy gate: tools that ask for confirmation for this call.
    if (await tool.requiresConfirmation(call.arguments)) {
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/astro_brain_test.dart`
Expected: PASS (both new tests + the existing ones).

- [ ] **Step 6: Commit**

```bash
git add lib/brain/tools/astro_tool.dart lib/brain/astro_brain.dart test/astro_brain_test.dart
git commit -m "feat(brain): per-call requiresConfirmation gate (defaults to mutates)"
```

---

## Task 2: SystemActions — composeEmail + openEmailApp

**Files:**
- Modify: `lib/platform/system_actions.dart`

**Interfaces:**
- Produces:
  - `Future<bool> SystemActions.composeEmail({required String to, required String subject, required String body})`.
  - `Future<bool> SystemActions.openEmailApp()`.

> Platform intent glue — no unit test (like the other `SystemActions` methods); verified by `flutter analyze` + `flutter build apk --debug`.

- [ ] **Step 1: Add the two methods**

In `lib/platform/system_actions.dart`, add these public methods to the `SystemActions` class (near `message`, reusing the existing `_tryLaunch` and `_fireIntent` helpers):

```dart
  /// Open the default mail app's composer, pre-filled, via a `mailto:` URI.
  /// Best-effort: the user reviews and sends manually.
  Future<bool> composeEmail({
    required String to,
    required String subject,
    required String body,
  }) {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query: _mailtoQuery(subject: subject, body: body),
    );
    return _tryLaunch(uri);
  }

  /// Open the phone's default email app (no compose), via ACTION_MAIN +
  /// CATEGORY_APP_EMAIL. Best-effort.
  Future<bool> openEmailApp() => _fireIntent(
        'android.intent.action.MAIN',
        const {},
      );
```

Add the small query builder near the other private helpers (e.g. next to `_digits`):

```dart
  /// Build a `mailto:` query string with URL-encoded subject and body, omitting
  /// empty parts.
  String _mailtoQuery({required String subject, required String body}) {
    final parts = <String>[
      if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
      if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
    ];
    return parts.join('&');
  }
```

> Note on `openEmailApp`: `_fireIntent` currently takes `(action, arguments, {data})` and does not set a category. `AndroidIntent` needs `category` for `CATEGORY_APP_EMAIL`. Extend `_fireIntent` with an optional `String? category` param (defaulting to null, passed through to `AndroidIntent(category: category)`) so existing callers are unchanged, and call `_fireIntent('android.intent.action.MAIN', const {}, category: 'android.intent.category.APP_EMAIL')`. Apply that here:

```dart
  Future<bool> openEmailApp() => _fireIntent(
        'android.intent.action.MAIN',
        const {},
        category: 'android.intent.category.APP_EMAIL',
      );
```

And update `_fireIntent`:

```dart
  Future<bool> _fireIntent(
    String action,
    Map<String, dynamic> arguments, {
    String? data,
    String? category,
  }) async {
    try {
      await AndroidIntent(
        action: action,
        arguments: arguments,
        data: data,
        category: category,
      ).launch();
      debugPrint('[intent] $action OK  args=$arguments');
      return true;
    } catch (e) {
      debugPrint('[intent] $action FAILED: $e  args=$arguments');
      return false;
    }
  }
```

- [ ] **Step 2: Analyze + build**

Run: `flutter analyze lib/platform/system_actions.dart`
Expected: no new issues.
Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL. (If it fails for a reason clearly in unrelated parallel android/ WIP, capture it and report; if it's your change, fix it.)

- [ ] **Step 3: Commit**

```bash
git add lib/platform/system_actions.dart
git commit -m "feat(email): SystemActions.composeEmail (mailto) + openEmailApp intent"
```

---

## Task 3: EmailTool fallback to a mailto draft

**Files:**
- Modify: `lib/brain/tools/email_tool.dart`
- Modify: `lib/brain/astro_brain_provider.dart` (EmailTool registration)
- Test: `test/email_tool_test.dart` (update)

**Interfaces:**
- Consumes: `AstroTool.requiresConfirmation` (Task 1), `SystemActions.composeEmail` (Task 2).
- Produces: `EmailTool` gains a required `composeViaIntent` callback and a `requiresConfirmation` override.

- [ ] **Step 1: Update the test**

In `test/email_tool_test.dart`:

Add a fake composer near `FakeSender`:

```dart
/// Records the draft the tool asked to open.
class FakeComposer {
  FakeComposer({this.result = true});
  final bool result;
  int calls = 0;
  String? to;
  String? subject;
  String? body;

  Future<bool> compose({
    required String to,
    required String subject,
    required String body,
  }) async {
    calls++;
    this.to = to;
    this.subject = subject;
    this.body = body;
    return result;
  }
}
```

Change the `_tool` helper to take an optional composer:

```dart
EmailTool _tool(
  FakeSender sender, {
  bool configured = true,
  FakeComposer? composer,
}) => EmailTool(
  isConfigured: () async => configured,
  send: sender.send,
  composeViaIntent: (composer ?? FakeComposer()).compose,
);
```

Replace the "reports when SMTP is not configured, without sending" test with:

```dart
    test('with no SMTP: opens a draft via intent instead of sending', () async {
      final sender = FakeSender();
      final composer = FakeComposer();
      final result = await _tool(sender, configured: false, composer: composer)
          .run({'to': 'a@b.com', 'subject': 'Hi', 'body': 'Hey'});
      expect(sender.calls, 0); // never SMTP-sent
      expect(composer.calls, 1);
      expect(composer.to, 'a@b.com');
      expect(composer.subject, 'Hi');
      expect(composer.body, 'Hey');
      expect(result.isError, isFalse);
      expect(result.content.toLowerCase(), contains('correo'));
    });

    test('requiresConfirmation only when SMTP is configured', () async {
      expect(
        await _tool(FakeSender(), configured: true)
            .requiresConfirmation(const {}),
        isTrue,
      );
      expect(
        await _tool(FakeSender(), configured: false)
            .requiresConfirmation(const {}),
        isFalse,
      );
    });
```

Keep the other tests. The end-to-end "brain confirms then sends" test still uses `configured: true` (default) so `requiresConfirmation` is true and `confirmed == 1` holds.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/email_tool_test.dart`
Expected: FAIL — `EmailTool` has no `composeViaIntent` param / `requiresConfirmation` override.

- [ ] **Step 3: Update EmailTool**

In `lib/brain/tools/email_tool.dart`, update the constructor and `run`:

```dart
  EmailTool({
    required Future<bool> Function() isConfigured,
    required Future<bool> Function({
      required String to,
      required String subject,
      required String body,
    })
    send,
    required Future<bool> Function({
      required String to,
      required String subject,
      required String body,
    })
    composeViaIntent,
  })  : _isConfigured = isConfigured,
        _send = send,
        _composeViaIntent = composeViaIntent;

  final Future<bool> Function() _isConfigured;
  final Future<bool> Function({
    required String to,
    required String subject,
    required String body,
  })
  _send;
  final Future<bool> Function({
    required String to,
    required String subject,
    required String body,
  })
  _composeViaIntent;
```

Update the description so the model knows it always works:

```dart
  @override
  String get description =>
      'Send an email. Needs to (recipient address), subject and body. If SMTP is '
      'configured it sends directly; otherwise it opens a pre-filled draft in the '
      'phone mail app. Use when the driver asks to email someone.';
```

Add the confirmation override (after `mutates`):

```dart
  @override
  Future<bool> requiresConfirmation(Map<String, dynamic> args) =>
      _isConfigured();
```

Replace `run`:

```dart
  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final to = (args['to'] as String?)?.trim() ?? '';
    if (to.isEmpty) return const ToolResult.error('to is empty');
    final subject = (args['subject'] as String?)?.trim() ?? '';
    final body = (args['body'] as String?)?.trim() ?? '';

    if (await _isConfigured()) {
      final ok = await _send(to: to, subject: subject, body: body);
      return ok
          ? ToolResult('Listo, envié el correo a $to.')
          : const ToolResult('No pude enviar el correo.');
    }

    // No SMTP: open a pre-filled draft in the phone's mail app.
    final opened =
        await _composeViaIntent(to: to, subject: subject, body: body);
    return opened
        ? ToolResult('Abrí tu app de correo con el borrador para $to.')
        : const ToolResult('No pude abrir tu app de correo.');
  }
```

- [ ] **Step 4: Wire it in the brain**

In `lib/brain/astro_brain_provider.dart`, in the `EmailTool(...)` registration, add the `composeViaIntent` argument (the provider already has `const actions = SystemActions();` or an `actions` instance used by other tools — reuse it; if it's `const SystemActions()` inline, use `const SystemActions().composeEmail`):

```dart
      EmailTool(
        isConfigured: () async => (await const SmtpStore().load()).isComplete,
        send: ({required to, required subject, required body}) async {
          final ok = await const EmailSender().send(
            config: await const SmtpStore().load(),
            to: to,
            subject: subject,
            body: body,
          );
          if (ok) await const SentEmailsStore().add(to);
          return ok;
        },
        composeViaIntent: ({required to, required subject, required body}) =>
            actions.composeEmail(to: to, subject: subject, body: body),
      ),
```

(Use the `actions` instance already present in this provider — the same one passed to `NavigateTool`/`PhoneTool`/`TimerTool`. If it is written as `const SystemActions()` at those call sites, use `const SystemActions().composeEmail(...)` here too.)

- [ ] **Step 5: Run test + analyze**

Run: `flutter test test/email_tool_test.dart`
Expected: PASS.
Run: `flutter analyze lib/brain/tools/email_tool.dart lib/brain/astro_brain_provider.dart`
Expected: no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/brain/tools/email_tool.dart lib/brain/astro_brain_provider.dart test/email_tool_test.dart
git commit -m "feat(email): send_email opens a mailto draft when SMTP is unset"
```

---

## Task 4: ReadEmailTool fallback to opening the mail app

**Files:**
- Modify: `lib/brain/tools/read_email_tool.dart`
- Modify: `lib/brain/astro_brain_provider.dart` (ReadEmailTool registration)
- Test: `test/read_email_tool_test.dart` (update)

**Interfaces:**
- Consumes: `SystemActions.openEmailApp` (Task 2).
- Produces: `ReadEmailTool` gains a required `openMailApp` callback.

- [ ] **Step 1: Update the test**

In `test/read_email_tool_test.dart`, add a fake and thread it through the tool
construction (mirror the existing helper/fakes in that file). Add:

```dart
/// Records whether the tool asked to open the mail app.
class FakeMailOpener {
  FakeMailOpener({this.result = true});
  final bool result;
  int calls = 0;
  Future<bool> open() async {
    calls++;
    return result;
  }
}
```

Update the tool-construction helper in that file to pass `openMailApp: opener.open`
(add an optional `FakeMailOpener? opener` param defaulting to a fresh one), then
add:

```dart
    test('with no IMAP: opens the mail app instead of reading', () async {
      final opener = FakeMailOpener();
      // Build a ReadEmailTool with canRead=false and the fake opener via the
      // file's construction helper; then:
      final result = await tool.run(const {});
      expect(opener.calls, 1);
      expect(result.content.toLowerCase(), contains('correo'));
    });
```

(Replace the existing "not configured for reading" assertion — which expects the
old "pon el IMAP" text — with the above. Follow the file's existing helper shape
for constructing the tool with `canRead: false` and the fake opener.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/read_email_tool_test.dart`
Expected: FAIL — `ReadEmailTool` has no `openMailApp` param.

- [ ] **Step 3: Update ReadEmailTool**

In `lib/brain/tools/read_email_tool.dart`, add the callback and use it:

```dart
  ReadEmailTool({
    required Future<bool> Function() canRead,
    required Future<List<EmailSummary>> Function({required int count}) fetch,
    required Future<bool> Function() openMailApp,
  })  : _canRead = canRead,
        _fetch = fetch,
        _openMailApp = openMailApp;

  final Future<bool> Function() _canRead;
  final Future<List<EmailSummary>> Function({required int count}) _fetch;
  final Future<bool> Function() _openMailApp;
```

Update the description:

```dart
  @override
  String get description =>
      'Check the latest emails in the inbox: sender, subject and date. If IMAP is '
      'configured it lists them; otherwise it opens the phone mail app. Use for '
      '"do I have new email", "read my last emails". count = how many to fetch '
      '(default 5).';
```

Replace the not-configured branch in `run`:

```dart
    if (!await _canRead()) {
      final opened = await _openMailApp();
      return opened
          ? const ToolResult('Abrí tu app de correo.')
          : const ToolResult('No pude abrir tu app de correo.');
    }
```

(Keep the rest of `run` — the fetch + formatting — unchanged.)

- [ ] **Step 4: Wire it in the brain**

In `lib/brain/astro_brain_provider.dart`, in the `ReadEmailTool(...)` registration,
add:

```dart
        openMailApp: actions.openEmailApp,
```

(again reusing the `actions` instance / `const SystemActions()` as the other
registrations in this file do).

- [ ] **Step 5: Run test + analyze + full suite**

Run: `flutter test test/read_email_tool_test.dart`
Expected: PASS.
Run: `flutter analyze`
Expected: no new issues (beyond pre-existing parallel-WIP lints).
Run: `flutter test`
Expected: all pass except the known `test/widget_test.dart` failure; no new failures.

- [ ] **Step 6: Commit**

```bash
git add lib/brain/tools/read_email_tool.dart lib/brain/astro_brain_provider.dart test/read_email_tool_test.dart
git commit -m "feat(email): read_email opens the mail app when IMAP is unset"
```

---

## Final verification

- [ ] `flutter test` — green except the known parallel-WIP `widget_test.dart` failure; no new failures.
- [ ] `flutter analyze` — no new warnings.
- [ ] `flutter build apk --debug` — compiles.
- [ ] On-device: with no SMTP set, ask Astro to email someone → the mail app opens a pre-filled draft (no voice confirm); ask to read email → the mail app opens. With SMTP set, sending still confirms by voice and sends directly.

## Notes / follow-up
- `openEmailApp` uses `CATEGORY_APP_EMAIL`; if a device has no default mail app, the intent fails and the tool returns the friendly "No pude abrir tu app de correo."
- The draft path deliberately does not auto-send (per the brainstorm decision); the user sends from their mail app.
