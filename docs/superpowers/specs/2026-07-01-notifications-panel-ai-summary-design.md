# Notifications panel with AI summary — design

**Date:** 2026-07-01
**Status:** Approved (design), pending implementation plan

## Goal

Give Astro a notifications panel: a bell icon in the top bar (next to the
settings gear) that opens a modal listing captured phone notifications grouped
by app. The user can ask the AI to summarize a whole app group, or a single
notification. The summary is shown as text in the modal and spoken aloud by
Astro.

## Context (existing system)

Notifications are already captured by a single Android `NotificationListenerService`
(`NavListenerService.kt`) that routes Google Maps notifications to a live nav
EventChannel and buffers all other notifications in a **native ring buffer (40
max, memory-only, no persistence)**. Dart reads them via
`NotificationsReader().recent({int count})` → `List<NotificationSummary>` with
fields `app`, `title`, `text`, `time` (DateTime). Today they are only pulled
on-demand by the agentic brain via the `comunicacion` tool
(`leer_notificaciones`). There is no UI list and no proactive use.

This feature adds a UI surface and a dedicated summarizer; it does **not** change
capture or add persistence.

## Decisions (from brainstorming)

- **Trigger granularity:** both — a group-level "Resumir" button AND tappable
  individual items.
- **Output:** text in the modal **and** spoken by Astro (reuse the voice path).
- **Container:** modal bottom sheet (matches `showAiSetupSheet`).
- **Badge:** unread count — notifications newer than a persisted "seen at"
  marker.
- **AI mechanism:** dedicated `NotificationSummarizer` (approach A), a single
  tool-less LLM call, mirroring `MemoryExtractor`. No agentic loop.

## Components

### 1. Entry point — bell icon + unread badge
- Add an `IconButton(Icons.notifications_none)` to the top-right `Row` in
  `pet_screen.dart` (~line 921), to the **left** of the settings gear, same
  `accent` color.
- **Unread badge:** overlay a small count when > 0. Count = notifications whose
  `time` is after the persisted `notificationsSeenAt` (epoch ms).
- **Refresh:** the buffer is pull-only (no Dart-side new-notification stream), so
  the count is recomputed on a periodic `Timer` (~20s) and on app resume
  (`AppLifecycleState.resumed`).
- **Reset:** opening the sheet sets `notificationsSeenAt = now` (persisted) and
  the badge drops to 0.

### 2. Modal — `lib/ui/notifications_sheet.dart`
- `showNotificationsSheet(BuildContext, {required void Function(String) onSpeak})`,
  patterned on `showAiSetupSheet`.
- On open: `NotificationsReader().recent(40)`, then group by `app`.
- Each app → a collapsible section (`ExpansionTile`) showing app name, item
  count, and a **"Resumir"** button in the header.
- Inside: each notification as a tappable `ListTile` (title — text — relative
  time).
- **Empty states:** no listener permission → message + button to grant (reuse
  `Permissions().requestNotifications()` / open listener settings); empty buffer
  → "Nada nuevo" / "Nothing new".

### 3. Interaction & output
- Tap **"Resumir"** (group) → summarize all of that app's notifications.
- Tap an **item** → summarize/explain that single one.
- While running: spinner scoped to that group/item.
- On success: summary shown in a highlighted box within the group/item, and
  `onSpeak(summary)` is invoked → `pet_screen` speaks it via `_say(...)` (voice +
  visemes + speech bubble).
- On failure (`LlmException`): error text in the box; the modal stays usable.

### 4. AI — `lib/brain/notification_summarizer.dart`
- Class `NotificationSummarizer(client: LlmClient, model: String)`, mirroring
  `MemoryExtractor`.
- `Future<String> summarize(List<NotificationSummary> items, {required AppLang lang, String? app})`
  — builds one `LlmRequest` (system = bilingual summary persona respecting RULE
  #0 language, short spoken style; user = the rendered notifications; **no
  tools**) and calls `client.complete` once. Returns the text.
- `notificationSummarizerProvider` builds it with `_llmClientFor(ref, model)` +
  the resolved `astroModelProvider` model, so it works keyless with free models.

### 5. Pure, testable helpers
- `groupNotificationsByApp(List<NotificationSummary>) → Map<String, List<NotificationSummary>>`
  (groups sorted by most-recent notification first; items within a group newest
  first).
- `unreadCount(List<NotificationSummary> items, DateTime since) → int`.
Both pure — no UI, no network.

## Files

**New:**
- `lib/brain/notification_summarizer.dart` — summarizer + provider.
- `lib/ui/notifications_sheet.dart` — modal + grouping/unread helpers (or a small
  co-located helpers file if cleaner).

**Touched:**
- `lib/ui/pet_screen.dart` — bell icon, badge, poll/resume refresh, `onSpeak`
  wiring to `_say`.
- `lib/brain/astro_brain_provider.dart` — `notificationSummarizerProvider`.
- `lib/core/config/setting_key.dart` — add `notificationsSeenAt`.

## Testing

- `NotificationSummarizer` with a fake `LlmClient`: asserts the request carries
  the notification text, sends **no tools**, and returns the model's text.
- `groupNotificationsByApp` and `unreadCount`: table tests (grouping, ordering,
  boundary of the `since` timestamp).
- Widget test for the sheet with overridden summarizer + reader: tapping
  "Resumir" shows the summary text.

## Non-goals / constraints

- No changes to native capture; no historical persistence (buffer stays 40,
  memory-only). "What arrived today?" across restarts is out of scope (would
  require SQLite).
- Not routed through the agentic brain (no tool calls, no conversation history
  pollution).
- Free-model failover (built for the brain) is **not** reused here; a failed
  summary shows an error. Adding failover to the summarizer is a possible later
  extension.
