# Car mode / Normal mode switch — design

**Date:** 2026-07-01
**Status:** Approved (design)
**Area:** `lib/core/state`, `lib/ui`, `lib/brain`

## Problem

Astro is hardwired as an in-car copilot: the speed circle always shows, the GPS
speed sensor always runs (location permission + battery), the driving moods
always fire, and the LLM system prompt always says Astro rides in a car. When
the phone is on a desk or in hand, none of that fits — "frenada", the speed
ring, and "you're in a car" are wrong.

We want a top-left **text-only switch** to toggle between **car mode** and
**normal mode**, and have the whole stack follow the mode: UI, sensor, mood
logic, and the AI's prompt + context.

## Behaviour

| Aspect            | Car mode                                  | Normal mode                                            |
|-------------------|-------------------------------------------|--------------------------------------------------------|
| Speed ring + readout | Shown                                  | Hidden                                                 |
| GPS speed sensor  | Active (fusion as today)                  | Off — speed is constant 0, no GPS subscription/permission |
| Driving moods     | Full cascade (bump, scared, lean, excited, arrival, worried, alarm) | Silenced — only agent, caress, sleep/still, ambient/rest |
| System prompt     | "copilot in a car…"                       | "companion for its owner…" (no car, no speed)          |
| `get_context` tool| Reports speed                             | Omits the speed line (still gives time + location)     |

**Default: normal**, persisted across restarts. The phone accelerometer /
gyroscope keep running in both modes (no permission cost); in normal mode they
just don't drive the mood (gated in the resolver).

## Approach

### State + persistence

- New `enum AppMode { normal, car }` and `appModeProvider` — a `Notifier` backed
  by `shared_preferences` (same pattern as `CalibrationStore`). Default
  `normal`; the choice is saved on toggle and restored on launch.

### Speed sensor gating

`appStateProvider` watches `appModeProvider`:

- **normal:** speed is `Stream.value(0)` (startWith 0); the GPS subscription and
  the calibrator's GPS feed are skipped entirely — no location permission use,
  no battery draw.
- **car:** GPS + `fuseSpeed` exactly as today.

Toggling the mode rebuilds the sensor stream (rare event, acceptable).

### Mood logic gating

- Add a `carMode` bool to `AppState` (freezed, default `false`).
  `moodStateProvider` sets it from `appModeProvider` alongside the agent phase.
- `mood_resolver` stays pure. In normal mode it skips every driving rule; the
  cascade collapses to:
  1. agent (thinking / answering)
  2. caress (proximity near)
  3. still for a while → sleep
  4. rest (ambient)

  In car mode the cascade is unchanged. Sketch:

  ```dart
  Mood _mood(AppState s) {
    if (s.agentPhase == AgentPhase.thinking) return Mood.thinking;
    if (s.agentPhase == AgentPhase.answering) return Mood.answering;
    if (s.proximityNear) return Mood.pet;
    if (!s.carMode) {
      if (s.stillFor >= t.sleepAfter) return Mood.sleep;
      return Mood.rest;
    }
    // …full driving cascade as today…
  }
  ```

### UI (pet_screen)

- **Text-only switch, top-left** (Positioned inside the SafeArea): two labels
  "CARRO" / "NORMAL", the active one emphasised; tapping toggles
  `appModeProvider`. No icons.
- **car mode:** `Speedometer` shown; character wrapped in `VelocityRing`.
- **normal mode:** no `Speedometer`, no ring — the character renders in a
  same-sized box so the layout doesn't jump.

### AI: prompt + context tool

- `astroSystemPrompt` becomes mode-aware (a function/provider keyed by
  `AppMode`). Car variant keeps today's copilot persona; normal variant is a
  general companion with no car or speed language. `pet_screen` passes the
  current mode's prompt on each turn, so no brain rebuild is needed.
- `ContextTool` takes a `carMode` closure. In normal mode it omits the speed
  line (keeps time + location), so the model never thinks it's driving.

## Components and boundaries

- `lib/core/state/app_mode.dart` (new) — `AppMode` enum + persisted provider.
- `app_state.dart` — add `carMode` field (regenerate freezed).
- `app_state_provider.dart` — gate the GPS stream on mode; set `carMode`.
- `mood_resolver.dart` — gate the driving rules on `carMode`.
- `astro_brain_provider.dart` — mode-aware system prompt; wire `carMode` into
  `ContextTool`.
- `context_tool.dart` — omit speed when not in car mode.
- `pet_screen.dart` (+ optional `ModeSwitch` in `hud.dart`) — the switch and the
  conditional speed UI.

Data flow:

```
appModeProvider ──┬─▶ appStateProvider (GPS on/off, carMode field)
                  │        │
                  │        ▼
                  │   moodStateProvider ──▶ mood_resolver (gates driving moods)
                  ├─▶ pet_screen (switch, speed UI, system prompt)
                  └─▶ ContextTool.carMode (speed line on/off)
```

## Error handling / degradation

- Persistence read/write failures are swallowed → fall back to `normal`
  (matches the app's "one failing piece never breaks the rest" rule).
- Switching to car mode may prompt for location permission (GPS); denial leaves
  speed at 0 via the existing `onErrorReturn(0)` guard — the mode still works,
  just without a live speed.

## Testing

- `mood_resolver` (the core): table tests for **normal** (driving inputs →
  `rest`/`sleep`, never `scared`/`bump`/`lean`/`excited`) and **car** (cascade
  unchanged).
- `context_tool`: speed present in car mode, omitted in normal.
- `app_mode`: persistence round-trip with a mocked store; default is `normal`.
- Optional widget test: toggling shows/hides the `Speedometer`.

## Rollout

State + persistence first, then the resolver gate (with tests), then the sensor
gate, then the prompt/tool, then the UI switch. Each step keeps the app
compiling; default `normal` means the car-only machinery is dormant until the
user opts in.
```
