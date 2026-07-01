# Google Maps navigation listener — design

**Date:** 2026-07-01
**Status:** approved for planning

## Goal

Give Astro a real navigation input by reading Google Maps' turn-by-turn
notification and feeding the next-turn direction, distance, and arrival into
`AppState`. The `AppState`/`MoodResolver` side is already built (`arrived`,
`turnDirection`, `turnDistanceM` → `arrival` mood, `turnImminent`, `gaze`,
`tilt`); this feature only adds the missing **source**, plus its permission UX,
gated by the existing `navListenerEnabled` setting.

## Decisions (from brainstorming)
- **Parse in Dart.** Native side is a thin forwarder of raw notification text;
  a pure Dart `NavParser` extracts the fields (unit-testable, tunable without a
  native rebuild).
- **Languages: Spanish + English** notification heuristics (es-Colombia primary).
- **Permission: open Settings + status.** Notification access is a special
  permission granted only in system settings; enabling the toggle deep-links to
  the Notification-access screen when not yet granted, and the toggle shows the
  granted state.

## Architecture

```
Google Maps notification
 → NavListenerService (Kotlin, NotificationListenerService, filters
   com.google.android.apps.maps)
 → EventChannel "astro/nav" forwards RAW {title, text, removed}
 → NavParser (Dart, pure) → NavReading {turnDirection, distanceM, arrived}
 → NavService (Dart) → Stream<NavReading>
 → appStateProvider combiner → AppState.copyWith(arrived, turnDirection,
   turnDistanceM)   [only when navListenerEnabled; else a neutral reading]
 → MoodResolver (already consumes these)
```

## Components

1. **`NavListenerService` (Kotlin, `com.lordmacu.astro.nav`)** — extends
   `NotificationListenerService`. `onNotificationPosted`/`onNotificationRemoved`
   filter `sbn.packageName == "com.google.android.apps.maps"`, extract
   `extras.getString(EXTRA_TITLE)` + `EXTRA_TEXT` (and sub-text), and push a
   small map `{title, text, removed}` to a process-static broadcaster the channel
   subscribes to. Registered in `AndroidManifest.xml` with permission
   `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE` and an intent-filter
   for `android.service.notification.NotificationListenerService`.

2. **`NavChannel` (Kotlin)** — registered from `MainActivity` alongside the
   existing channels. `EventChannel "astro/nav"` streams the raw notification
   maps; `MethodChannel "astro/nav/control"` exposes `hasPermission()` (checks
   the enabled notification listeners via `Settings.Secure` /
   `NotificationManagerCompat.getEnabledListenerPackages`) and `openSettings()`
   (`Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`).

3. **`NavReading` (Dart)** — immutable value: `TurnDirection turnDirection`,
   `double? distanceM`, `bool arrived`. A `NavReading.none` neutral constant.

4. **`NavParser` (Dart, pure)** — `NavReading parse({String? title, String?
   text, bool removed})`. Heuristics (es + en), order: if `removed` or an
   arrival phrase → arrived / none; else distance via regex
   `(\d+(?:[.,]\d+)?)\s*(m|km)` (km ×1000, comma decimal) and direction via
   keyword sets (`izquierda|left` → left, `derecha|right` → right, else none).
   Unrecognized → `NavReading.none`. This is the primary tested unit.

5. **`NavService` (Dart, `lib/sensors/navigation/nav_service.dart`)** — wraps the
   `astro/nav` EventChannel, maps each raw event through `NavParser`, exposes
   `Stream<NavReading> readings()`. Constructor takes the event stream (so tests
   inject a fake). A `navServiceProvider`.

6. **Combiner integration (`app_state_provider.dart`)** — add nav as an
   additional combined source. Use `startWith(NavReading.none)` so it never
   blocks the combine. When `navListenerEnabled` is false, substitute a constant
   `Stream.value(NavReading.none)` (nav fields stay default). Merge into
   `AppState` via `arrived`, `turnDirection`, `turnDistanceM`.

7. **Settings wiring** — the existing 'Navegación (Maps)' `SettingsSwitchTile`
   calls `setNavListenerEnabled`. On enabling, call `NavChannel.hasPermission()`;
   if false, `NavChannel.openSettings()`. The subtitle reflects granted/!granted.

## Error handling & degradation
- No notification access → the native service never runs; NavService emits
  nothing beyond the neutral start; toggle shows "sin acceso". App behaves
  exactly as today.
- Parser returns `NavReading.none` on anything it doesn't recognize; an arrival
  or a removed Maps notification resets nav to neutral.
- One failing piece never breaks the rest (project rule): a channel error is
  caught and treated as neutral nav.

## Testing
- **`NavParser`** (core): table tests over real Maps strings — es ("A 200 m gira
  a la derecha", "Has llegado", "1,2 km"), en ("In 200 m, turn left", "You have
  arrived", "0.5 mi"→unsupported-unit → distance null but direction still
  parsed), and unrecognized → `NavReading.none`.
- **`NavService`**: inject a fake raw-event stream → assert `NavReading` mapping
  and that removed/arrival reset to neutral.
- **Combiner**: `navListenerEnabled=false` → nav fields default; `=true` with a
  fake nav stream → `AppState.arrived/turnDirection/turnDistanceM` reflect it.
- Native `NavListenerService`/`NavChannel` are thin and not unit-tested (no JVM
  test harness here); they are verified on-device.

## Build order (vertical slices)
1. `NavParser` (pure Dart, TDD) — the fragile heuristics, fully tested.
2. `NavReading` + `NavService` over the EventChannel (fake stream in tests).
3. Combiner integration + `navListenerEnabled` gating.
4. Kotlin `NavListenerService` + `NavChannel` + manifest registration.
5. Settings toggle → permission check / open-settings + status.

## Non-goals
- No parsing of arbitrary nav apps (Waze, etc.) — Google Maps only.
- No distance-unit support beyond metric (m/km); imperial (mi/ft) → distance
  null (direction/arrival still parsed). Extensible later.
- No change to `AppState`/`MoodResolver` (already built for nav).
- Parser is best-effort; on-device tuning of patterns is expected follow-up.
