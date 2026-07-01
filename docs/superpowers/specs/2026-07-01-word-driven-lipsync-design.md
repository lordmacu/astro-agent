# Word-driven lip-sync — design

**Date:** 2026-07-01
**Status:** Approved (design)
**Area:** `lib/voice`, `lib/ui/astro_character.dart`

## Problem

While Astro speaks, the mouth animation is random noise: a fixed 110 ms
`Timer.periodic` in `pet_screen.dart` calls `tickViseme()`, which draws a random
shape from a weighted bag (`VisemeSequencer` in `viseme.dart`). The five shapes
are drawn as discrete `Path`s in `astro_character.dart` and switch instantly.
Nothing about the animation relates to the words being spoken, and the hard cuts
look robotic.

We want the mouth to follow the **actual words** Astro says, with smoother,
more expressive motion.

## Goals

- Drive mouth shapes from the real words the TTS is speaking, synced per word.
- Expand and smooth the mouth: more shapes, interpolated transitions, jaw
  amplitude.
- Keep the `Viseme` abstraction so a future Rive character or the parked neural
  TTS (`SherpaTts`) can feed the same mouth without a rewrite.
- Degrade gracefully: if the engine reports no word boundaries, the mouth still
  moves (fall back to today's random motion).

## Non-goals

- Audio-amplitude / envelope analysis (needs accessible PCM; the neural TTS is
  parked). Not now.
- A phoneme dictionary or ML grapheme-to-phoneme. Spanish is near-phonetic;
  grapheme rules are enough.
- Rive integration. The current character is a `CustomPainter`; this lands there
  and stays compatible with a later Rive swap.

## Approach

### 1. Parametric mouth (replaces 5 fixed paths)

Each viseme is described by **three scalars** instead of a bespoke `Path`:

- `openness` (0–1): jaw opening.
- `width` (0–1): mouth width — spread (smile) vs narrow.
- `roundness` (0–1): rounded lips (o/u) vs flat.

The painter draws **one** parametric mouth from these numbers. Interpolating
between two visemes becomes a `lerp` of three scalars; jaw amplitude simply
scales `openness`. This is more maintainable than 8 hand-drawn paths and makes
smoothing trivial.

### 2. Expanded viseme set

`Viseme` grows from 5 to ~8 shapes, each defined by its three scalars:

| Viseme        | Triggers (Spanish)        | openness | width | roundness |
|---------------|---------------------------|----------|-------|-----------|
| `rest`        | silence, punctuation      | 0.05     | 0.4   | 0.3       |
| `bilabial`    | m, b, p (lips together)   | 0.0      | 0.4   | 0.2       |
| `labiodental` | f, v (lip to teeth)       | 0.15     | 0.45  | 0.1       |
| `open`        | neutral consonant         | 0.35     | 0.5   | 0.3       |
| `wideA`       | a                         | 0.9      | 0.6   | 0.1       |
| `roundOU`     | o, u                      | 0.5      | 0.25  | 0.95      |
| `spreadEI`    | e, i                      | 0.4      | 0.9   | 0.0       |
| `dental`      | s, z, c(soft), t, d, l, n | 0.25     | 0.6   | 0.15      |

(Exact scalars are tuned during implementation; the table is the starting
point.)

### 3. `viseme_mapper.dart` — new, pure, testable

```dart
List<Viseme> visemesForWord(String word);
List<Viseme> visemesForText(String text); // words + rest at boundaries
```

Grapheme→viseme rules for **Spanish** (the language Astro always answers in per
REGLA #0), handling digraphs `ch`, `ll`, `qu`, `gu`, `rr`. Unknown letters fall
to `open`. Pure functions → table tests (matches the repo's "test the parsers"
convention).

### 4. Per-word sync via flutter_tts

`SystemTts` registers `setProgressHandler((text, start, end, word) => …)`
(flutter_tts 4.2.5, Android reports per-word ranges). On each word event:

1. map the word → its viseme sub-sequence,
2. spread those visemes across the word's **estimated duration**
   (`letters × msPerLetter` at the configured `rate`) — **timing model A**,
3. when the next word event arrives, correct and start the next word.

Because events arrive per word, drift is bounded and resets every word.

The `TextToSpeech` contract gains an optional speech-event callback (word +
char range). `SilentTts` and the parked `SherpaTts` implement it as a no-op /
best-effort, so nothing breaks.

**Fallback:** if no word events arrive for a short window after `speak` starts
(engine/locale without range reporting), fall back to the existing random timer
so the mouth still moves.

### 5. Interpolation

`AstroCharacter` gains an `AnimationController` (or ticker) that `lerp`s the
three scalars from the previous viseme to the current one over ~60–90 ms, plus a
small amplitude jitter so motion doesn't feel mechanical.

## Components and boundaries

- `viseme.dart` — expanded `Viseme` enum + a metrics table (three scalars per
  viseme). No behaviour.
- `viseme_mapper.dart` (new) — text/word → `List<Viseme>`. Pure.
- `viseme_track.dart` (new) — given word events + a clock, expose the currently
  active viseme (timing model A lives here). Testable with a fake clock.
- `voice_interfaces.dart` / `system_tts.dart` — TTS speech-progress events.
- `voice_controller.dart` — wire TTS events → track → mouth state; keep the
  random sequencer as the fallback path.
- `astro_character.dart` — parametric mouth + interpolation.

Data flow:

```
TTS word event ──▶ viseme_mapper ──▶ viseme_track (timing A + clock)
                                          │
                                          ▼
                              VoiceController.state.viseme
                                          │
                                          ▼
                     AstroCharacter (lerp prev→current scalars)
```

## Error handling / degradation

- No word events → random-timer fallback (mouth still moves).
- Empty / whitespace text → `rest`.
- `SilentTts` (no audio) → no events, mouth stays at `rest`.

## Testing

- `viseme_mapper`: table tests over Spanish words, digraphs, punctuation,
  unknown letters.
- `viseme_track`: injected fake clock + scripted word events; assert the active
  viseme at given instants, and that a new word resets timing.
- `voice_controller`: feed synthetic speech events, assert emitted visemes; and
  assert the fallback path engages when no events arrive.
- Painter interpolation: not unit-tested (visual); verified on device.

## Rollout

Pure modules first (`viseme` metrics, `viseme_mapper`, `viseme_track`) with
tests, then the TTS event plumbing, then the painter. Each step keeps the app
compiling; the random fallback means the feature is safe even if word events
misbehave on a given device.
```
