# openWakeWord wake-word detection for Chispa — Design

**Date:** 2026-06-30
**Status:** Approved design, pending implementation plan
**Topic:** Replace the stopgap `SttWakeWord` with a custom, freely-trained openWakeWord
detector ("Oye Chispa" + "Chispa") running in a native Android foreground service.

---

## 1. Goal & scope

Detect the wake word for Chispa with a **custom model we train ourselves for free**
(no Picovoice account, no recorded samples), running **always-on and low-power** on the
dashboard phone.

This replaces the current stopgap [`SttWakeWord`](../../../lib/voice/stt_wake_word.dart),
which matches the literal text "chispa" in a continuous `speech_to_text` transcript. That
stopgap keeps the mic + system recognizer busy, can't do a true custom word, and depends on
the device's speech engine.

**Hard boundary:** everything stays behind the existing
[`WakeWordDetector`](../../../lib/voice/voice_interfaces.dart) interface
(`onWake` stream + `start()`/`stop()`). No other layer of the app changes. `SttWakeWord`
remains as a selectable fallback, the same way `SystemTts`/`SilentTts` coexist today.

**Non-goals:** changing STT (`speech_to_text` stays), changing TTS, OBD, or any mood logic.

---

## 2. Decisions (locked)

| Decision | Choice | Why |
|---|---|---|
| Wake phrases | **Both** `"Oye Chispa"` and `"Chispa"` | Longer phrase is robust; bare "Chispa" is natural but short. openWakeWord runs many models per core cheaply, so we run both and fire on either. |
| Runtime | **TFLite-first**, fall back to `onnxruntime-android` (mobile build) per stage if a `.tflite` is missing | Smallest native lib for mobile; the mobile onnxruntime is a few MB, *not* the ~72 MB desktop build sherpa bundles. |
| Where it runs | **Native Kotlin** inside the always-on foreground service | Dart can't reliably hold the mic in the background on Android. |
| Training | openWakeWord `automatic_model_training.ipynb` on Colab, 100% **Piper** synthetic data | Free, no recorded samples; Piper is already the project's TTS engine of record. |
| Interface | Unchanged `WakeWordDetector` | Drop-in swap; `SttWakeWord` kept as fallback provider. |

### License note (honest caveat)
- openWakeWord framework: **Apache 2.0**. Feature extractor (melspectrogram + Google speech
  embedding): **Apache 2.0** → safe to ship.
- openWakeWord's *pretrained* word models: CC BY-NC-SA (non-commercial). **We don't use those** —
  we train "Chispa"/"Oye Chispa" ourselves, so their license follows the augmentation datasets
  (RIR/noise) the Colab pulls. Irrelevant for a personal car-pet project; revisit if ever
  commercialized.

---

## 3. Architecture overview

```
                          ┌─────────────────────── Android foreground service (Kotlin) ───────────────────────┐
 mic ── AudioRecord ──►   │  PCM16 16kHz ring buffer                                                           │
 (16kHz mono)            │      │ 80ms hops (1280 samples)                                                    │
                          │      ▼                                                                             │
                          │  melspectrogram.tflite ──► rolling mel-frame buffer                               │
                          │                                  │                                                 │
                          │                                  ▼                                                 │
                          │  embedding.tflite ──────► rolling embedding buffer (~1.5s context)                │
                          │                                  │                                                 │
                          │                ┌─────────────────┼─────────────────┐                              │
                          │                ▼                 ▼                 (shared stages computed once)   │
                          │   oye_chispa.tflite      chispa.tflite                                             │
                          │        score 0..1            score 0..1                                            │
                          │        │ threshold+debounce  │ threshold+debounce                                  │
                          │        └────────── any fires ─┘                                                    │
                          │                  │ EventChannel "chispa/wakeword"                                  │
                          └──────────────────┼───────────────────────────────────────────────────────────────┘
                                             ▼
 Flutter:  OwwWakeWord (implements WakeWordDetector) ──► onWake stream ──► VoiceController (unchanged)
           start/stop/pause/resume/setThreshold via MethodChannel "chispa/wakeword/control"
```

The melspectrogram and embedding stages are computed **once per hop** and the resulting
embedding window is fed to **both** classifiers — that's openWakeWord's multi-model design and
why running two words costs almost nothing.

---

## 4. Component 1 — Model training (offline, Colab)

**Tool:** openWakeWord `notebooks/automatic_model_training.ipynb` (Linux-only; Colab is fine).

**Process per phrase** (`"oye chispa"`, `"chispa"`):
1. Generate positive clips with **Piper** Spanish voices, varying pitch/speed/voice.
2. Pull negative speech + background noise + room-impulse-response (RIR) datasets the notebook
   uses, to augment positives into realistic conditions.
3. Train a small classifier on top of the **frozen** melspectrogram + embedding feature
   extractor.
4. Export the classifier to `.tflite` (and `.onnx` as the fallback artifact).

**Outputs committed/bundled** (per §6 layout):
- `oye_chispa.tflite`, `chispa.tflite` — the two classifiers (each small, hundreds of KB).
- `melspectrogram.tflite`, `embedding.tflite` — shared feature extractor (from the
  openWakeWord repo; identical for every word).

**Tuning artifacts:** keep a small set of recorded positive clips ("Oye Chispa", "Chispa" in
the car, with road noise) and negatives (music, conversation, silence) to measure
detection-rate vs false-positive-rate and pick per-model thresholds. These live under
`test/voice/fixtures/wakeword/` for the Kotlin test (§7) and manual tuning.

> The training notebook is run by a human; this repo stores the **resulting models** and the
> exact notebook parameters used (phrases, voice list, augmentation counts) in a short
> `docs/wakeword-training.md` so the model is reproducible.

---

## 5. Component 2 — Native inference engine (Kotlin)

Lives in the **foreground service of type `microphone`** that CLAUDE.md already plans for
always-on listening. New Kotlin classes under `android/app/src/main/kotlin/.../wakeword/`:

### `WakeWordEngine`
- Owns `AudioRecord` (16kHz, mono, PCM16) and a background thread for the inference loop.
- Maintains: a PCM ring buffer; a rolling mel-frame buffer; a rolling embedding buffer.
- Loads three+ TFLite `Interpreter`s: shared `melspectrogram` + `embedding`, plus one
  classifier per phrase. **Model I/O shapes are read at load time** — buffer window sizes
  (mel-frame count, embedding context length) are derived from the models, never hardcoded.
- Loop per 80ms hop: append 1280 samples → melspec → append mel frames → when enough mels,
  embedding → append embedding → run each classifier over the embedding window → smooth →
  per-model threshold + N-consecutive + refractory debounce (~2s) → on cross, emit a wake
  event tagged with which phrase fired.
- Runtime abstraction: an `Inferencer` interface with a `TfliteInferencer` (primary) and an
  `OnnxInferencer` (fallback). The engine picks per stage based on which model file is present,
  so a stage that lacks `.tflite` transparently uses `.onnx` via onnxruntime-android.

### `WakeWordChannel` (platform bridge)
- **EventChannel** `chispa/wakeword`: emits on each detection (payload: phrase + score).
- **MethodChannel** `chispa/wakeword/control`: `start`, `stop`, `pause`, `resume`,
  `setThreshold(phrase, value)`.
- `pause`/`resume` stop/restart the `AudioRecord` capture so Chispa doesn't hear herself while
  speaking (TTS), mirroring `SttWakeWord.pause/resume`.

### Config
All numeric knobs (per-phrase threshold, min-consecutive frames, refractory ms, hop size) live
in one Kotlin config object — the native analog of `core/config/thresholds.dart`. Defaults:
`chispa` threshold higher than `oye_chispa` (shorter word → more false positives).

### Dependencies
- `org.tensorflow:tensorflow-lite` (primary).
- `com.microsoft.onnxruntime:onnxruntime-android` (mobile build) only if a stage needs ONNX.
- Restrict ABIs for dev runs to the phone's ABI (`flutter run`) per CLAUDE.md's fast-iterate note.

---

## 6. Component 3 — Flutter side

### `OwwWakeWord implements WakeWordDetector`
`lib/voice/oww_wake_word.dart`
- `start()`/`stop()` → MethodChannel.
- `onWake` ← EventChannel stream mapped to `Stream<void>` (phrase/score logged but the
  interface only needs "woke").
- `pause()`/`resume()` → MethodChannel (same surface `SttWakeWord` exposes; `VoiceController`
  already calls these around TTS).

### Provider swap
`wakeWordProvider` returns `OwwWakeWord()` by default; `SttWakeWord()` remains selectable as a
fallback for dev/devices without the models — exactly the `SystemTts`/`SilentTts` pattern in
[`tts_provider.dart`](../../../lib/voice/tts_provider.dart). No call site outside the provider
changes.

### Assets
Models in `android/app/src/main/assets/oww/` (native assets so the service loads them without a
Dart round-trip), **not** Flutter `assets/`. Documented in CLAUDE.md's voice section.

---

## 7. Testing

Mirrors the project rule "test parsing with fixed data; mock hardware":

- **Kotlin (the important one):** unit-test the engine's buffer/threshold loop by feeding a
  fixed PCM array decoded from a WAV fixture — a "Oye Chispa" clip must fire; silence/noise/
  music must not. This is the analog of OBD PID parsing tests. The `AudioRecord` source is
  abstracted so the loop is fed from a byte array in tests.
- **Dart:** `OwwWakeWord` mapping logic with fake Method/Event channels (`onWake` emits when the
  EventChannel emits; control calls invoke the right method). No device needed.
- **Validation/tuning (manual):** run the fixture set of positives/negatives to set per-phrase
  thresholds and the refractory window; record the chosen values in the Kotlin config with a
  comment citing the measured FP rate.

---

## 8. APK size

3–4 `.tflite` files (a few MB total) + the TFLite native lib (a few MB per ABI). Trivial next to
the parked neural-TTS problem (~297 MB). If the ONNX fallback is needed for a stage, the
**mobile** onnxruntime is still only a few MB — not the desktop build. Size is not a blocker.

---

## 9. Build order (de-risking phases)

1. **Train** → produce `oye_chispa.tflite`, `chispa.tflite` (+ confirm the shared
   `melspectrogram.tflite` / `embedding.tflite` exist; else grab `.onnx`). Verify detection in
   Colab/python before any app code.
2. **`WakeWordEngine` in Kotlin** + the WAV-fixture unit test. Validate the trained model fires
   on real "Oye Chispa" clips and rejects negatives. (No Flutter wiring yet.)
3. **Foreground service hosts the engine** + `WakeWordChannel` (Event/Method channels), models
   in native assets.
4. **`OwwWakeWord` + `wakeWordProvider`** swap; `SttWakeWord` demoted to fallback.
5. **pause/resume around TTS** in `VoiceController`; threshold/refractory tuning from the
   fixture set.

Each phase is independently verifiable; the interface is stable from phase 4 on, so the rest of
the app is untouched throughout.

---

## 10. Open risks

- **TFLite availability per stage** — melspec is documented as an ONNX implementation; phase 1
  confirms whether all three stages ship `.tflite`. The `Inferencer` abstraction makes a
  per-stage ONNX fallback cheap, so this is a known-handled risk, not a blocker.
- **Exact streaming geometry** — mel-frame-per-hop and embedding-context counts are read from
  model I/O at load, not assumed, so a mismatch surfaces at load time rather than as silent
  garbage.
- **"Chispa" false positives** — mitigated by running the longer "Oye Chispa" as the primary
  trigger and giving bare "Chispa" a higher threshold; both tunable from config.
- **Self-hearing** — pause on TTS start, resume on TTS end (existing pattern), plus audio-focus
  ducking already in scope.
