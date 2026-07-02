# Tap-to-cancel ("escape") — design

**Date:** 2026-07-02
**Status:** approved

## Goal

Tapping the pet while Astro is active — listening, thinking, or speaking — is a
full stop: Astro goes quiet immediately and the current conversation ends,
returning to rest. No spoken confirmation (the point is silence), just the
cancel haptic. Tapping while idle still starts a conversation, as today.

Today's tap only cancels during the `listening` phase: `_cancelListening()`
returns early unless `phase == VoicePhase.listening`, so a tap mid-thinking or
mid-speech does nothing and Astro keeps talking. This fixes that.

## Decision (from brainstorming)

**Cooperative cancellation**, not a true HTTP abort. On tap Astro stops talking
instantly (TTS `stop()`), suppresses any further speech, breaks out of the
brain's turn loop, and discards the pending answer. The in-flight HTTP request
for the current turn finishes on its own in the background, silently. This keeps
the brain and its HTTP client decoupled (a predicate, not a cancel token) and is
low-risk. Hard-aborting the socket to save the current turn's tokens was
considered and rejected as out of scope.

## Mechanism

Generalize the existing `_cancelRequested` flag (honored only in `listening`)
into a single `_aborted` abort signal honored across all phases.

On tap while busy (any phase):
1. `_haptics.cancel()` — the existing buzz.
2. `_aborted = true`.
3. `ref.read(ttsProvider).stop()` — cut current speech immediately.
4. `ref.read(speechRecognizerProvider).stop()` — unblock a pending `listen()`.

The running loops observe `_aborted` and unwind to idle on their own.

### Where the flag is honored

- **`_converse`** — reset `_aborted = false` at the start (as `_cancelRequested`
  is today). Check `_aborted` at the top of each turn and after each `await`
  (the listen, the answer) → `break`. The existing `finally` already sets phase
  → idle, resumes the wake mic, and clears the spoken text.
- **`_runCommand`** (command-palette path) — reset `_aborted = false` at the
  start and honor it the same way, so a palette-triggered answer can also be
  tapped to stop.
- **`_answerStreaming`**:
  - In the `onSentence` callback: if `_aborted`, return without queuing/speaking
    the sentence (suppress the remaining speech).
  - Pass `isCancelled: () => _aborted` to `brain.askStream`.
  - After the brain call / `await ttsChain`, if `_aborted` return `''` (discard
    the answer so nothing is added to the exchange or spoken).
- **`AstroBrain.askStream`** — add an optional `bool Function()? isCancelled`
  parameter, checked in two places:
  - At the top of each turn → `break` the turn loop (stops further LLM calls and
    tool runs).
  - Inside `emit(...)` → return early so `onSentence` is no longer called.

  The current `_streamWithFailover` await still completes in the background, but
  produces no spoken output and triggers no further turns.

`_cancelListening()` is replaced by a general `_abort()` that runs the four
steps above regardless of phase.

## Error handling & edge cases

- Tap while idle → unchanged (`_converse()` starts a conversation).
- Confirmation / pick overlays (phone, email, calendar) render a full-screen
  overlay above the pet, so a tap "on the pet" doesn't reach the gesture
  detector during them; those keep their own dismiss. Out of scope here.
- Double-tap / rapid taps after abort: `_aborted` stays true until the next
  `_converse`/`_runCommand` resets it; extra taps are harmless no-ops once idle.

## Testing

- **`AstroBrain.askStream` cancellation** (unit, fake LLM client): with
  `isCancelled` flipping to true after the first emitted sentence/turn, the loop
  stops emitting further sentences and returns early. This is the testable core.
- The pet_screen tap → abort wiring (TTS stop, STT stop, loop unwind) is verified
  on device, consistent with how `_converse` and the other overlays are treated
  (the voice loop is not unit-tested).

## Files touched

- `lib/ui/pet_screen.dart` — tap handler, `_converse`, `_runCommand`,
  `_answerStreaming`; replace `_cancelListening`/`_cancelRequested` with the
  general `_aborted` + `_abort()`.
- `lib/brain/astro_brain.dart` — `askStream` gains the `isCancelled` predicate.

## Non-goals

- No true socket/HTTP abort (cooperative only).
- No spoken "ok/stopped" confirmation.
- No change to idle-tap (still starts a conversation) or long-press (petting).
