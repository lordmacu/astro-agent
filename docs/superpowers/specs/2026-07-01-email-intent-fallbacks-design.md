# Email intent fallbacks (no SMTP) — design

**Date:** 2026-07-01
**Status:** approved for planning

## Goal

When SMTP/IMAP is not configured, the email tools should still help the driver
instead of dead-ending:
- **send_email** with no SMTP → open a pre-filled draft in the default mail app
  (`mailto:` intent) instead of returning "not configured".
- **read_email** with no IMAP → open the default mail app instead of returning
  "not configured".

## Decision (from brainstorming)
- The **draft fallback is NOT voice-confirmed** (it only opens a draft the user
  sends manually). Voice confirmation stays **only** for the real SMTP auto-send.

## Architecture

Confirmation today is a brain-level gate on the static `AstroTool.mutates` bool,
decided before `run()`. "Confirm only when SMTP is configured" is an async,
per-call condition the brain can't see. Resolve it with a minimal,
backward-compatible addition:

- `AstroTool` gains `Future<bool> requiresConfirmation(Map<String, dynamic> args)
  async => mutates;` (default preserves current behavior for every tool).
- `AstroBrain._runTool` changes its gate from `if (tool.mutates)` to
  `if (await tool.requiresConfirmation(call.arguments))`.
- `EmailTool` overrides `requiresConfirmation` → `await _isConfigured()` (confirm
  only for SMTP auto-send; the draft fallback runs unconfirmed). `mutates` stays
  `true` (semantic marker; other mutating tools are unaffected).

## Components

1. **`SystemActions`** (`lib/platform/system_actions.dart`) — add two methods,
   reusing its existing intent helpers:
   - `Future<bool> composeEmail({required String to, required String subject,
     required String body})` → builds a `mailto:` `Uri` (path = `to`, query =
     `subject`/`body`, URL-encoded) and launches it via the existing
     `_tryLaunch(Uri)` (url_launcher, external app). Opens the default mail
     composer pre-filled.
   - `Future<bool> openEmailApp()` → launches an `AndroidIntent(action:
     'android.intent.action.MAIN', category: 'android.intent.category.APP_EMAIL')`
     via the existing `_fireIntent`-style helper. Opens the default mail app.
   Both are best-effort, returning `false` on failure (no throw), like the other
   `SystemActions` methods.

2. **`EmailTool`** (`lib/brain/tools/email_tool.dart`, `send_email`) — add an
   injected `Future<bool> Function({required String to, required String subject,
   required String body}) composeViaIntent`. `run()`: parse `to`/`subject`/`body`
   first; if `await _isConfigured()` → SMTP `send` (as today); else →
   `composeViaIntent(...)` → on success `ToolResult('Abrí tu app de correo con el
   borrador para $to.')`, on failure `ToolResult('No pude abrir tu app de
   correo.')`. Override `requiresConfirmation` → `_isConfigured()`. Update the
   tool `description` so the model knows it works with or without SMTP (SMTP
   sends directly; otherwise it opens a draft).

3. **`ReadEmailTool`** (`lib/brain/tools/read_email_tool.dart`, `read_email`) —
   add an injected `Future<bool> Function() openMailApp`. `run()`: if `await
   _canRead()` → IMAP fetch (as today); else → `openMailApp()` → on success
   `ToolResult('Abrí tu app de correo.')`, on failure `ToolResult('No pude abrir
   tu app de correo.')`. Read-only, still no confirmation.

4. **Wiring** (`lib/brain/astro_brain_provider.dart`) — `EmailTool(...,
   composeViaIntent: actions.composeEmail)` and `ReadEmailTool(...,
   openMailApp: actions.openEmailApp)`. `actions` (a `SystemActions`) is already
   constructed in this provider.

## Error handling & degradation
- Intent/launch failure (no mail app installed) → the friendly "No pude abrir tu
  app de correo." text; never throws.
- The SMTP send and IMAP read paths are unchanged.
- Existing behavior for every other tool is preserved (`requiresConfirmation`
  defaults to `mutates`).

## Testing
- **`EmailTool`** (`test/email_tool_test.dart`, update): SMTP configured →
  `send` path + `requiresConfirmation` true; not configured → `composeViaIntent`
  called with to/subject/body + result mentions the draft + `requiresConfirmation`
  false; compose failure → "No pude abrir".
- **`ReadEmailTool`** (`test/read_email_tool_test.dart`, update): IMAP available →
  fetch path; not available → `openMailApp` called + "Abrí tu app de correo".
- **`AstroBrain`** (`test/astro_brain_test.dart`, add one): a `mutates`-true tool
  whose `requiresConfirmation` returns false runs WITHOUT invoking the confirm
  callback; and one returning true still confirms.
- **`SystemActions.composeEmail`/`openEmailApp`** — platform intent glue, verified
  by `flutter build apk --debug` + on-device; not unit-tested.

## Build order (vertical slices)
1. `AstroTool.requiresConfirmation` + brain gate change (+ brain test).
2. `SystemActions.composeEmail` + `openEmailApp` (build-verified).
3. `EmailTool` fallback + `requiresConfirmation` override (+ test).
4. `ReadEmailTool` fallback (+ test).
5. Wiring in `astro_brain_provider`.

## Non-goals
- No new SMTP/IMAP config or auto-detection; this only adds the no-config
  fallbacks.
- No cross-platform (iOS) intent handling; Android only, matching the app.
- The draft is composed in the user's mail app; Astro does not auto-send it.
