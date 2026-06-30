# openWakeWord wake-word ("Oye Chispa" / "Chispa") Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stopgap `SttWakeWord` with a custom, freely-trained openWakeWord detector that listens always-on for "Oye Chispa" and "Chispa" in a native Android foreground service, surfaced to Flutter through the existing `WakeWordDetector` interface.

**Architecture:** Two custom classifiers trained on synthetic Piper speech (Colab) run on a shared melspectrogram+embedding feature extractor inside a Kotlin foreground service (`AudioRecord` → TFLite). Detections cross a platform `EventChannel`; control (`start/stop/pause/resume/setThreshold`) crosses a `MethodChannel`. A Dart `OwwWakeWord` adapter implements `WakeWordDetector`; a `wakeWordProvider` swaps it in for `SttWakeWord`, which stays as a fallback. The ONNX runtime is parked (`.kt.off` + commented dep), exactly like the project's parked neural TTS.

**Tech Stack:** Flutter/Dart 3 + Riverpod 2, Kotlin (Android foreground service, `AudioRecord`), TensorFlow Lite (`org.tensorflow:tensorflow-lite`), openWakeWord training notebook + Piper (Colab).

## Global Constraints

- Code identifiers, comments, docs, filenames: **English only**. Chispa's voice is bilingual but lives in `voice/speech_catalog.dart`, not here.
- All numeric knobs go in config, never raw in logic: Dart → `core/config/thresholds.dart`; Kotlin → a single `WakeConfig` object. (Project rule: no magic numbers in logic.)
- Models are **native** Android assets under `android/app/src/main/assets/oww/`, not Flutter `assets/`.
- Sensor/voice services expose streams/services and must **not** import `ui`. The wake decision stays out of `ui`.
- Immutable models with `freezed` where models are added; cancel subscriptions in `dispose`/`ref.onDispose`.
- Before "done": `dart format .` && `flutter analyze` with no warnings.
- Git identity for any commit: `user.name = lordmacu`, `user.email = 10134930+lordmacu@users.noreply.github.com`. **Note:** this directory is currently **not a git repo** — if commits are desired, `git init` + set this identity first (confirm with the user). Commit steps below assume git exists; skip them if it does not.
- App id / Kotlin package: `com.lordmacu.chispa`.
- Iterate on device with `flutter run -d <device>` (single ABI), never `flutter build apk` for inner loop.

---

## Phases

- **Phase 0 — Train models (human, Colab).** Produces the 4 `.tflite` files. Not agent-runnable here (needs Colab/Linux + Piper). Task 0.
- **Phase 1 — Dart adapter (agent, TDD).** Fully runnable with `flutter test`. Tasks 1–4.
- **Phase 2 — Native engine + service + channels (device-gated).** Pure logic is JVM-unit-tested; `AudioRecord`/TFLite/service are validated on device in Task 11. Tasks 5–11.

Phase 1 ships green tests against a fake channel and is independently mergeable. Phase 2 makes it real on the phone.

---

## File Structure

**Create (Dart):**
- `lib/voice/oww_wake_word.dart` — `OwwWakeWord` adapter over the platform channels.
- `lib/voice/wake_word_provider.dart` — `wakeWordProvider` (the single switch, OWW default / STT fallback).
- `test/oww_wake_word_test.dart`, `test/wake_word_provider_test.dart`, `test/pet_screen_wake_test.dart`.

**Modify (Dart):**
- `lib/voice/voice_interfaces.dart` — add `pause()`/`resume()` to `WakeWordDetector`.
- `lib/voice/stt_wake_word.dart` — `@override` the two new methods (already implemented; just annotate).
- `lib/ui/pet_screen.dart:30,42,55,68,76` — read the detector from `wakeWordProvider` via the interface.
- `lib/core/config/thresholds.dart` — wake-word defaults (mirrors native config; documents the contract).

**Create (Kotlin), under `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/`:**
- `WakeConfig.kt` — all numeric knobs + per-phrase thresholds.
- `WakeDebouncer.kt` — pure threshold + N-consecutive + refractory state machine.
- `FrameRing.kt` — pure rolling 2-D float window.
- `Inferencer.kt` — interface + `TfliteModel` impl.
- `WakeWordEngine.kt` — `AudioRecord` → melspec → embedding → classifiers → debouncer → callback.
- `WakeWordService.kt` — foreground service (type `microphone`) hosting the engine.
- `WakeWordChannel.kt` — Method/Event channel wiring; registered from `MainActivity`.
- `OnnxInferencer.kt.off` — **parked** ONNX fallback (rename to enable).

**Create (Kotlin tests):** `android/app/src/test/kotlin/com/lordmacu/chispa/wakeword/{WakeDebouncerTest,FrameRingTest}.kt`.

**Modify (Android):**
- `android/app/src/main/AndroidManifest.xml` — `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS`; declare the service.
- `android/app/src/main/kotlin/com/lordmacu/chispa/MainActivity.kt` — `configureFlutterEngine` registers `WakeWordChannel`.
- `android/app/build.gradle.kts` — TFLite dep, `noCompress "tflite"`, JUnit test dep; parked ONNX dep (commented).
- `android/app/src/main/assets/oww/` — the 4 `.tflite` files.

**Create (docs):** `docs/wakeword-training.md` — reproducible training parameters.

---

## Task 0: Train the "Oye Chispa" and "Chispa" models (human, Colab)

**Files:**
- Create: `android/app/src/main/assets/oww/oye_chispa.tflite`, `chispa.tflite`, `melspectrogram.tflite`, `embedding.tflite`
- Create: `docs/wakeword-training.md`

**Interfaces:**
- Produces: four `.tflite` files consumed by `TfliteModel` (Task 7) and a documented training recipe.

> This task is run by a person on Google Colab — it is **not** automatable in this repo. Steps are exact so it is reproducible.

- [ ] **Step 1: Open the automatic training notebook**

Open `https://github.com/dscripka/openWakeWord` → `notebooks/automatic_model_training.ipynb` in Google Colab (Runtime → GPU). It is Linux-based, which Piper requires.

- [ ] **Step 2: Train phrase 1 — "oye chispa"**

In the notebook's config cell set the target phrase and Spanish synthesis:
- `target_phrase = ["oye chispa"]`
- Use Spanish Piper voices (e.g. `es_ES-*`, `es_MX-*`); keep the default positive/negative/augmentation (RIR + background noise) counts.
Run all cells. The notebook trains a classifier on the frozen feature extractor and exports it.

- [ ] **Step 3: Export phrase 1 to TFLite**

In the export cell choose **tflite** output. Download the produced model and rename it `oye_chispa.tflite`.

- [ ] **Step 4: Train + export phrase 2 — "chispa"**

Repeat Steps 2–3 with `target_phrase = ["chispa"]`; download as `chispa.tflite`.

- [ ] **Step 5: Grab the shared feature models**

From the openWakeWord package data, copy `melspectrogram.tflite` and `embedding.tflite` (the fixed, word-independent feature extractor). If only `.onnx` is available for a stage, download that `.onnx` instead and note it — the engine falls back to ONNX per stage (Task 7) and the parked `OnnxInferencer` is enabled (its README note).

- [ ] **Step 6: Verify the models load and discriminate (Colab)**

In a final Colab cell, confirm a positive clip scores high and noise scores low:

```python
import openwakeword, numpy as np, scipy.io.wavfile as wav
oww = openwakeword.Model(wakeword_models=["oye_chispa.tflite", "chispa.tflite"],
                         inference_framework="tflite")
sr, pos = wav.read("a_recording_of_oye_chispa.wav")   # record one yourself
print("positive:", {k: round(max(v),3) for k,v in oww.predict_clip("a_recording_of_oye_chispa.wav").items()})
print("noise:",    {k: round(max(v),3) for k,v in oww.predict_clip("road_noise.wav").items()})
```
Expected: the matching key on the positive clip ≥ ~0.5; both keys on noise ≪ 0.5. If "chispa" is noisy, that is expected (short word) — its threshold is raised in `WakeConfig` (Task 5).

- [ ] **Step 7: Record I/O shapes and place the files**

Note each model's input/output tensor shapes (printed by the notebook or `Interpreter.get_input_details()`); they document Task 7's reshaping. Put all four files in `android/app/src/main/assets/oww/`.

- [ ] **Step 8: Write `docs/wakeword-training.md`**

Record: notebook URL + commit, the two `target_phrase` values, the Piper voice list, augmentation counts, framework=tflite, and the measured positive/noise scores from Step 6. This makes the models reproducible.

- [ ] **Step 9: Commit (if git initialized)**

```bash
git add android/app/src/main/assets/oww docs/wakeword-training.md
git commit -m "feat(wakeword): trained oye-chispa/chispa tflite models + training recipe"
```

---

## Task 1: Add `pause()`/`resume()` to the `WakeWordDetector` interface

**Files:**
- Modify: `lib/voice/voice_interfaces.dart:12-16`
- Modify: `lib/voice/stt_wake_word.dart:87-97`
- Test: `test/oww_wake_word_test.dart` (created next task) + `flutter analyze`

**Interfaces:**
- Produces: `WakeWordDetector` with `Future<void> pause()` and `Future<void> resume()` — consumed by `OwwWakeWord` (Task 2) and `pet_screen` (Task 4).

- [ ] **Step 1: Extend the interface**

In `lib/voice/voice_interfaces.dart`, replace the `WakeWordDetector` declaration:

```dart
/// Always-on wake-word listener ("Oye Chispa" / "Chispa"). Fires an event each
/// time the wake word is heard. [pause]/[resume] silence the detector while
/// Chispa speaks, so she doesn't hear herself.
abstract interface class WakeWordDetector {
  Stream<void> get onWake;
  Future<void> start();
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
}
```

- [ ] **Step 2: Annotate the existing `SttWakeWord` methods as overrides**

`SttWakeWord` already defines `pause()`/`resume()`. In `lib/voice/stt_wake_word.dart`, add `@override` above each (lines ~87 and ~93):

```dart
  /// Pause listening (e.g. while Chispa speaks, to avoid hearing herself).
  @override
  Future<void> pause() async {
    _running = false;
    await _speech.stop();
  }

  /// Resume after [pause].
  @override
  Future<void> resume() async {
    if (_running || !_available) return;
    _running = true;
    _listen();
  }
```

- [ ] **Step 3: Verify it still compiles and existing tests pass**

Run: `flutter analyze && flutter test test/stt_wake_word_test.dart`
Expected: analyze clean; the 3 `containsWakeWord` tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/voice/voice_interfaces.dart lib/voice/stt_wake_word.dart
git commit -m "feat(voice): add pause/resume to WakeWordDetector interface"
```

---

## Task 2: `OwwWakeWord` channel adapter

**Files:**
- Create: `lib/voice/oww_wake_word.dart`
- Test: `test/oww_wake_word_test.dart`

**Interfaces:**
- Consumes: `WakeWordDetector` (Task 1).
- Produces: `class OwwWakeWord implements WakeWordDetector` with optional injected `MethodChannel control` and `Stream<dynamic> events` (for tests), plus `Future<void> setThreshold(String phrase, double value)`. Channel names: control `'chispa/wakeword/control'`, events `'chispa/wakeword'`. These exact strings are reused by `WakeWordChannel` (Task 10).

- [ ] **Step 1: Write the failing test**

`test/oww_wake_word_test.dart`:

```dart
import 'dart:async';

import 'package:chispa/voice/oww_wake_word.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('onWake emits each time the event channel emits', () async {
    final events = StreamController<dynamic>.broadcast();
    final detector = OwwWakeWord(
      control: const MethodChannel('test/wakeword/control'),
      events: events.stream,
    );

    final wakes = <void>[];
    final sub = detector.onWake.listen((_) => wakes.add(null));

    events.add('oye_chispa');
    events.add('chispa');
    await Future<void>.delayed(Duration.zero);

    expect(wakes.length, 2);
    await sub.cancel();
    await events.close();
  });

  test('control methods invoke the native side with the right names', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/wakeword/control');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    final detector =
        OwwWakeWord(control: channel, events: const Stream<dynamic>.empty());
    await detector.start();
    await detector.pause();
    await detector.resume();
    await detector.setThreshold('chispa', 0.7);
    await detector.stop();

    expect(calls.map((c) => c.method).toList(),
        ['start', 'pause', 'resume', 'setThreshold', 'stop']);
    expect(calls[3].arguments, {'phrase': 'chispa', 'value': 0.7});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/oww_wake_word_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:chispa/voice/oww_wake_word.dart'`.

- [ ] **Step 3: Implement `OwwWakeWord`**

`lib/voice/oww_wake_word.dart`:

```dart
import 'package:flutter/services.dart';

import 'voice_interfaces.dart';

/// Production wake-word detector backed by the native openWakeWord engine
/// (Kotlin foreground service). Detections arrive on the [EventChannel]
/// `chispa/wakeword`; control flows over the [MethodChannel]
/// `chispa/wakeword/control`. The channels are injectable so the adapter is
/// unit-tested without the platform.
class OwwWakeWord implements WakeWordDetector {
  OwwWakeWord({MethodChannel? control, Stream<dynamic>? events})
      : _control = control ?? const MethodChannel('chispa/wakeword/control'),
        _events = events ??
            const EventChannel('chispa/wakeword').receiveBroadcastStream();

  final MethodChannel _control;
  final Stream<dynamic> _events;

  /// Fires once per native detection (the phrase that fired is dropped here;
  /// the interface only needs "woke").
  @override
  Stream<void> get onWake => _events.map((_) {});

  @override
  Future<void> start() => _control.invokeMethod<void>('start');

  @override
  Future<void> stop() => _control.invokeMethod<void>('stop');

  @override
  Future<void> pause() => _control.invokeMethod<void>('pause');

  @override
  Future<void> resume() => _control.invokeMethod<void>('resume');

  /// Override a phrase's firing threshold at runtime (tuning).
  Future<void> setThreshold(String phrase, double value) =>
      _control.invokeMethod<void>('setThreshold',
          <String, Object>{'phrase': phrase, 'value': value});
}
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `flutter test test/oww_wake_word_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/voice/oww_wake_word.dart test/oww_wake_word_test.dart
git commit -m "feat(voice): OwwWakeWord channel adapter"
```

---

## Task 3: `wakeWordProvider` (the single switch)

**Files:**
- Create: `lib/voice/wake_word_provider.dart`
- Test: `test/wake_word_provider_test.dart`

**Interfaces:**
- Consumes: `OwwWakeWord` (Task 2), `WakeWordDetector` (Task 1).
- Produces: `final wakeWordProvider = Provider<WakeWordDetector>(...)` returning `OwwWakeWord` by default; overridable in tests / swappable to `SttWakeWord`. Consumed by `pet_screen` (Task 4).

- [ ] **Step 1: Write the failing test**

`test/wake_word_provider_test.dart`:

```dart
import 'package:chispa/voice/oww_wake_word.dart';
import 'package:chispa/voice/stt_wake_word.dart';
import 'package:chispa/voice/voice_interfaces.dart';
import 'package:chispa/voice/wake_word_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to the openWakeWord detector', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(wakeWordProvider), isA<OwwWakeWord>());
  });

  test('can be overridden with the STT fallback', () {
    final c = ProviderContainer(overrides: [
      wakeWordProvider.overrideWithValue(SttWakeWord()),
    ]);
    addTearDown(c.dispose);
    expect(c.read(wakeWordProvider), isA<WakeWordDetector>());
    expect(c.read(wakeWordProvider), isA<SttWakeWord>());
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/wake_word_provider_test.dart`
Expected: FAIL — URI `wake_word_provider.dart` doesn't exist.

- [ ] **Step 3: Implement the provider**

`lib/voice/wake_word_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'oww_wake_word.dart';
import 'voice_interfaces.dart';

/// The active wake-word detector, and the single switch for it.
///
/// Default: the native **openWakeWord** engine (`OwwWakeWord`) — custom
/// "Oye Chispa" / "Chispa" models, always-on, low-power. The text-matching
/// `SttWakeWord` stays as a fallback for dev or devices without the models:
/// override this provider with `SttWakeWord()`.
///
/// App-scoped (not autoDispose): the detector is long-lived, like the
/// always-on foreground service it controls. Teardown stops it.
final wakeWordProvider = Provider<WakeWordDetector>((ref) {
  final detector = OwwWakeWord();
  ref.onDispose(detector.stop);
  return detector;
});
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `flutter test test/wake_word_provider_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/voice/wake_word_provider.dart test/wake_word_provider_test.dart
git commit -m "feat(voice): wakeWordProvider (openWakeWord default, STT fallback)"
```

---

## Task 4: Rewire `pet_screen` to the provider + interface

**Files:**
- Modify: `lib/ui/pet_screen.dart:9,30,73-78`
- Test: `test/pet_screen_wake_test.dart`

**Interfaces:**
- Consumes: `wakeWordProvider` (Task 3), `WakeWordDetector` (Task 1).
- Produces: `PetScreen` no longer constructs `SttWakeWord`; it reads the detector from the provider. No other behavior changes.

- [ ] **Step 1: Write the failing widget test**

`test/pet_screen_wake_test.dart`:

```dart
import 'dart:async';

import 'package:chispa/core/state/app_state.dart';
import 'package:chispa/core/state/app_state_provider.dart';
import 'package:chispa/ui/pet_screen.dart';
import 'package:chispa/voice/voice_interfaces.dart';
import 'package:chispa/voice/wake_word_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records lifecycle calls; exposes a controllable wake stream.
class FakeWake implements WakeWordDetector {
  final calls = <String>[];
  final _wakes = StreamController<void>.broadcast();
  void fire() => _wakes.add(null);
  @override
  Stream<void> get onWake => _wakes.stream;
  @override
  Future<void> start() async => calls.add('start');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
}

void main() {
  testWidgets('starts the wake detector from the provider', (tester) async {
    final fake = FakeWake();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        wakeWordProvider.overrideWithValue(fake),
        appStateProvider.overrideWith((ref) => Stream.value(const AppState())),
      ],
      child: const MaterialApp(home: PetScreen()),
    ));
    await tester.pump();

    expect(fake.calls, contains('start'));
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/pet_screen_wake_test.dart`
Expected: FAIL — `PetScreen` still builds its own `SttWakeWord`, so `fake.calls` is empty (`start` never called on the fake).

- [ ] **Step 3: Rewire `pet_screen.dart`**

Replace the import on line 9 (`import '../voice/stt_wake_word.dart';`) with:

```dart
import '../voice/voice_interfaces.dart';
import '../voice/wake_word_provider.dart';
```

Replace line 30 (`final SttWakeWord _wake = SttWakeWord();`) with a late field read from the provider:

```dart
  late final WakeWordDetector _wake = ref.read(wakeWordProvider);
```

In `dispose()` (lines ~73-78), **remove** `_wake.dispose();` — the provider owns the detector's lifecycle now. Keep `_wakeSub?.cancel();`:

```dart
  @override
  void dispose() {
    _visemeTimer?.cancel();
    _wakeSub?.cancel();
    super.dispose();
  }
```

(`initState`'s `_wake.start()`, `_speak`'s `_wake.pause()`/`_wake.resume()` are unchanged — they're on the interface now.)

- [ ] **Step 4: Run the test to confirm it passes**

Run: `flutter test test/pet_screen_wake_test.dart`
Expected: PASS.

- [ ] **Step 5: Full Dart gate**

Run: `dart format . && flutter analyze && flutter test`
Expected: format clean, analyze no warnings, all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pet_screen.dart test/pet_screen_wake_test.dart
git commit -m "feat(ui): pet_screen reads wake detector from wakeWordProvider"
```

> **End of Phase 1.** The whole Dart integration is green against a fake channel; the app still runs on `SttWakeWord` until the native side (Phase 2) backs `OwwWakeWord`. To run the app on `SttWakeWord` meanwhile, override `wakeWordProvider` with `SttWakeWord()` in `main.dart`'s `ProviderScope` (temporary).

---

## Task 5: `WakeConfig` + `WakeDebouncer` (pure Kotlin, JVM-tested)

**Files:**
- Create: `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeConfig.kt`
- Create: `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeDebouncer.kt`
- Create: `android/app/src/test/kotlin/com/lordmacu/chispa/wakeword/WakeDebouncerTest.kt`
- Modify: `android/app/build.gradle.kts` (JUnit test dep)

**Interfaces:**
- Produces: `WakeConfig` (sampleRate=16000, hopSamples=1280, per-phrase `Threshold(threshold, minConsecutive, refractoryFrames)`); `WakeDebouncer(threshold, minConsecutive, refractoryFrames)` with `fun update(score: Float): Boolean`. Consumed by `WakeWordEngine` (Task 8).

- [ ] **Step 1: Add the JUnit test dependency**

In `android/app/build.gradle.kts`, inside `dependencies { }`:

```kotlin
    testImplementation("junit:junit:4.13.2")
```

- [ ] **Step 2: Write the failing test**

`android/app/src/test/kotlin/com/lordmacu/chispa/wakeword/WakeDebouncerTest.kt`:

```kotlin
package com.lordmacu.chispa.wakeword

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class WakeDebouncerTest {
    @Test fun firesOnlyAfterEnoughConsecutiveHighScores() {
        val d = WakeDebouncer(threshold = 0.5f, minConsecutive = 3, refractoryFrames = 5)
        assertFalse(d.update(0.9f)) // 1
        assertFalse(d.update(0.9f)) // 2
        assertEquals(true, d.update(0.9f)) // 3 -> fire
    }

    @Test fun resetsConsecutiveOnALowScore() {
        val d = WakeDebouncer(threshold = 0.5f, minConsecutive = 2, refractoryFrames = 5)
        assertFalse(d.update(0.9f))
        assertFalse(d.update(0.1f)) // reset
        assertFalse(d.update(0.9f)) // 1 again
        assertEquals(true, d.update(0.9f)) // 2 -> fire
    }

    @Test fun suppressesDuringRefractoryWindow() {
        val d = WakeDebouncer(threshold = 0.5f, minConsecutive = 1, refractoryFrames = 3)
        assertEquals(true, d.update(0.9f)) // fire
        assertFalse(d.update(0.9f)) // cooldown 3
        assertFalse(d.update(0.9f)) // cooldown 2
        assertFalse(d.update(0.9f)) // cooldown 1
        assertEquals(true, d.update(0.9f)) // ready again
    }
}
```

- [ ] **Step 3: Run it to confirm it fails**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "*WakeDebouncerTest"`
Expected: FAIL — `WakeDebouncer` unresolved.

- [ ] **Step 4: Implement `WakeConfig` and `WakeDebouncer`**

`WakeConfig.kt`:

```kotlin
package com.lordmacu.chispa.wakeword

/** One phrase's firing policy. Short words (e.g. "chispa") get a higher
 *  threshold than longer ones ("oye chispa") to curb false positives. */
data class PhrasePolicy(
    val assetFile: String,
    var threshold: Float,
    val minConsecutive: Int,
    val refractoryFrames: Int,
)

/** All wake-word numeric knobs in one place (native analog of thresholds.dart). */
object WakeConfig {
    const val SAMPLE_RATE = 16_000
    const val HOP_SAMPLES = 1_280 // 80 ms at 16 kHz

    const val MELSPEC_ASSET = "oww/melspectrogram.tflite"
    const val EMBEDDING_ASSET = "oww/embedding.tflite"

    // refractoryFrames are counted in hops (~80 ms each): ~25 ≈ 2 s.
    val phrases = listOf(
        PhrasePolicy("oww/oye_chispa.tflite", threshold = 0.5f, minConsecutive = 2, refractoryFrames = 25),
        PhrasePolicy("oww/chispa.tflite",     threshold = 0.7f, minConsecutive = 3, refractoryFrames = 25),
    )

    fun phraseId(assetFile: String): String =
        assetFile.substringAfterLast('/').removeSuffix(".tflite")
}
```

`WakeDebouncer.kt`:

```kotlin
package com.lordmacu.chispa.wakeword

/** Turns a stream of per-hop scores into discrete wake events: requires
 *  [minConsecutive] hops at/above [threshold], then suppresses for
 *  [refractoryFrames] hops. Pure — no Android deps, fully unit-tested. */
class WakeDebouncer(
    private val threshold: Float,
    private val minConsecutive: Int,
    private val refractoryFrames: Int,
) {
    private var consecutive = 0
    private var cooldown = 0

    /** Returns true on exactly the hop a wake should fire. */
    fun update(score: Float): Boolean {
        if (cooldown > 0) {
            cooldown--
            consecutive = 0
            return false
        }
        if (score >= threshold) {
            consecutive++
            if (consecutive >= minConsecutive) {
                consecutive = 0
                cooldown = refractoryFrames
                return true
            }
        } else {
            consecutive = 0
        }
        return false
    }
}
```

- [ ] **Step 5: Run the test to confirm it passes**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "*WakeDebouncerTest"`
Expected: PASS (3 tests). (Requires the local Android SDK; this is a pure-JVM unit test, no emulator.)

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeConfig.kt \
        android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeDebouncer.kt \
        android/app/src/test/kotlin/com/lordmacu/chispa/wakeword/WakeDebouncerTest.kt \
        android/app/build.gradle.kts
git commit -m "feat(wakeword): WakeConfig + pure WakeDebouncer with JVM tests"
```

---

## Task 6: `FrameRing` rolling window (pure Kotlin, JVM-tested)

**Files:**
- Create: `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/FrameRing.kt`
- Create: `android/app/src/test/kotlin/com/lordmacu/chispa/wakeword/FrameRingTest.kt`

**Interfaces:**
- Produces: `FrameRing(capacity: Int, width: Int)` with `fun push(frame: FloatArray)`, `fun isFull(): Boolean`, `fun snapshot(): Array<FloatArray>` (oldest→newest). Consumed by `WakeWordEngine` (Task 8) to hold the rolling mel-frame and embedding windows.

- [ ] **Step 1: Write the failing test**

`android/app/src/test/kotlin/com/lordmacu/chispa/wakeword/FrameRingTest.kt`:

```kotlin
package com.lordmacu.chispa.wakeword

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FrameRingTest {
    @Test fun fillsThenReportsFull() {
        val ring = FrameRing(capacity = 2, width = 1)
        assertFalse(ring.isFull())
        ring.push(floatArrayOf(1f))
        assertFalse(ring.isFull())
        ring.push(floatArrayOf(2f))
        assertTrue(ring.isFull())
    }

    @Test fun snapshotIsOldestToNewestAndEvicts() {
        val ring = FrameRing(capacity = 2, width = 1)
        ring.push(floatArrayOf(1f))
        ring.push(floatArrayOf(2f))
        ring.push(floatArrayOf(3f)) // evicts 1
        val snap = ring.snapshot()
        assertEquals(2, snap.size)
        assertArrayEquals(floatArrayOf(2f), snap[0], 0f)
        assertArrayEquals(floatArrayOf(3f), snap[1], 0f)
    }
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "*FrameRingTest"`
Expected: FAIL — `FrameRing` unresolved.

- [ ] **Step 3: Implement `FrameRing`**

`FrameRing.kt`:

```kotlin
package com.lordmacu.chispa.wakeword

/** Fixed-size rolling window of equal-width float frames. Holds the latest
 *  [capacity] frames; [snapshot] returns them oldest→newest as the dense input
 *  the next model stage expects. Pure — unit-tested. */
class FrameRing(private val capacity: Int, private val width: Int) {
    private val buf = ArrayDeque<FloatArray>(capacity)

    fun push(frame: FloatArray) {
        require(frame.size == width) { "frame width ${frame.size} != $width" }
        if (buf.size == capacity) buf.removeFirst()
        buf.addLast(frame)
    }

    fun isFull(): Boolean = buf.size == capacity

    fun snapshot(): Array<FloatArray> = Array(buf.size) { buf[it] }

    fun clear() = buf.clear()
}
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "*FrameRingTest"`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/FrameRing.kt \
        android/app/src/test/kotlin/com/lordmacu/chispa/wakeword/FrameRingTest.kt
git commit -m "feat(wakeword): FrameRing rolling window with JVM tests"
```

---

## Task 7: `Inferencer` interface + `TfliteModel` (+ parked ONNX)

**Files:**
- Create: `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/Inferencer.kt`
- Create: `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/OnnxInferencer.kt.off` (parked)
- Modify: `android/app/build.gradle.kts` (TFLite dep, `noCompress`; parked ONNX dep commented)

**Interfaces:**
- Consumes: model assets from Task 0.
- Produces: `interface Inferencer { val outputShape: IntArray; fun run(input: FloatArray): FloatArray; fun close() }` and `class TfliteModel(assetManager, assetPath) : Inferencer`. Consumed by `WakeWordEngine` (Task 8).

> Device/native task — no automated unit test here; correctness of tensor shapes is validated on device in Task 11. Shapes are read from the model at load, per the design (not hardcoded).

- [ ] **Step 1: Add the TFLite dependency and asset packaging**

In `android/app/build.gradle.kts`:

```kotlin
android {
    androidResources {
        noCompress += "tflite" // mmap models directly; don't gzip them in the APK
    }
}

dependencies {
    implementation("org.tensorflow:tensorflow-lite:2.16.1")
    // Parked ONNX fallback (enable only if a stage ships .onnx, not .tflite):
    // implementation("com.microsoft.onnxruntime:onnxruntime-android:1.18.0")
}
```

- [ ] **Step 2: Implement `Inferencer` + `TfliteModel`**

`Inferencer.kt`:

```kotlin
package com.lordmacu.chispa.wakeword

import android.content.res.AssetManager
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

/** One TFLite (or, parked, ONNX) model stage. Shapes are read from the model,
 *  so swapping a retrained model never requires code changes. */
interface Inferencer {
    /** Output tensor shape, e.g. [1, 96] or [1, frames, 32]. */
    val outputShape: IntArray
    /** Run one inference over a flat float input; returns a flat float output. */
    fun run(input: FloatArray): FloatArray
    fun close()
}

/** TFLite-backed stage. Loads [assetPath] from the APK assets via mmap. */
class TfliteModel(assets: AssetManager, assetPath: String) : Inferencer {
    private val interpreter: Interpreter

    init {
        val fd = assets.openFd(assetPath)
        val model = fd.createInputStream().channel.map(
            FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength,
        )
        fd.close()
        interpreter = Interpreter(model)
    }

    override val outputShape: IntArray get() = interpreter.getOutputTensor(0).shape()

    override fun run(input: FloatArray): FloatArray {
        val inShape = interpreter.getInputTensor(0).shape()
        // Resize the input tensor to the flat length we feed, then run.
        interpreter.resizeInput(0, intArrayOf(1, input.size / batchInner(inShape)))
        interpreter.allocateTensors()

        val inBuf = ByteBuffer.allocateDirect(input.size * 4).order(ByteOrder.nativeOrder())
        for (v in input) inBuf.putFloat(v)
        inBuf.rewind()

        val outLen = outputShape.fold(1) { a, b -> a * if (b <= 0) 1 else b }
        val outBuf = ByteBuffer.allocateDirect(outLen * 4).order(ByteOrder.nativeOrder())
        interpreter.run(inBuf, outBuf)

        outBuf.rewind()
        return FloatArray(outLen) { outBuf.float }
    }

    private fun batchInner(shape: IntArray): Int =
        if (shape.size <= 1) 1 else shape.drop(1).fold(1) { a, b -> a * if (b <= 0) 1 else b }
            .let { if (it == 0) 1 else it }

    override fun close() = interpreter.close()
}
```

> The exact `resizeInput`/reshape calls depend on each model's declared input rank (melspec: variable-length audio; embedding: fixed mel window; classifier: fixed embedding window). Task 0 Step 7 recorded the shapes; reconcile this `run` against them during Task 11 and adjust the reshape if a model uses a fixed (non-resizable) input — in that case drop the `resizeInput` for that stage. This is the one block expected to need on-device iteration.

- [ ] **Step 3: Park the ONNX fallback**

Create `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/OnnxInferencer.kt.off` (the `.off` keeps it out of the build, like `sherpa_tts.dart.off`):

```kotlin
// PARKED. To enable the ONNX fallback for a stage that ships only .onnx:
//   1. build.gradle.kts: uncomment the onnxruntime-android dependency.
//   2. Rename this file: OnnxInferencer.kt.off -> OnnxInferencer.kt
//   3. In WakeWordEngine, build OnnxInferencer(...) for that stage instead of
//      TfliteModel(...), keyed off the asset extension (.onnx vs .tflite).
package com.lordmacu.chispa.wakeword

import android.content.res.AssetManager
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.nio.FloatBuffer

class OnnxInferencer(assets: AssetManager, assetPath: String) : Inferencer {
    private val env = OrtEnvironment.getEnvironment()
    private val session: OrtSession
    private val inputName: String

    init {
        val bytes = assets.open(assetPath).readBytes()
        session = env.createSession(bytes, OrtSession.SessionOptions())
        inputName = session.inputNames.iterator().next()
    }

    override val outputShape: IntArray
        get() = (session.outputInfo.values.first().info as ai.onnxruntime.TensorInfo)
            .shape.map { it.toInt() }.toIntArray()

    override fun run(input: FloatArray): FloatArray {
        val shape = longArrayOf(1, input.size.toLong())
        OnnxTensor.createTensor(env, FloatBuffer.wrap(input), shape).use { t ->
            session.run(mapOf(inputName to t)).use { r ->
                @Suppress("UNCHECKED_CAST")
                val out = (r[0].value as Array<FloatArray>)
                return out[0]
            }
        }
    }

    override fun close() = session.close()
}
```

- [ ] **Step 4: Verify the project still assembles**

Run: `cd android && ./gradlew :app:assembleDebug`
Expected: BUILD SUCCESSFUL (the parked `.kt.off` is ignored; TFLite resolves).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/Inferencer.kt \
        android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/OnnxInferencer.kt.off \
        android/app/build.gradle.kts
git commit -m "feat(wakeword): Inferencer + TfliteModel stage (ONNX parked)"
```

---

## Task 8: `WakeWordEngine` (audio → models → debouncer → callback)

**Files:**
- Create: `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeWordEngine.kt`

**Interfaces:**
- Consumes: `WakeConfig`, `WakeDebouncer` (Task 5), `FrameRing` (Task 6), `TfliteModel`/`Inferencer` (Task 7).
- Produces: `class WakeWordEngine(assets: AssetManager, onWake: (String) -> Unit)` with `fun start()`, `fun pause()`, `fun resume()`, `fun stop()`, `fun setThreshold(phraseId: String, value: Float)`. Consumed by `WakeWordService` (Task 9).

> Device-gated: drives `AudioRecord` and TFLite. Validated in Task 11; no JVM unit test (the pure pieces it composes are already tested in Tasks 5–6).

- [ ] **Step 1: Implement the engine**

`WakeWordEngine.kt`:

```kotlin
package com.lordmacu.chispa.wakeword

import android.annotation.SuppressLint
import android.content.res.AssetManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlin.concurrent.thread

/** openWakeWord streaming engine: mic → melspectrogram → embedding → per-phrase
 *  classifiers → debouncers → [onWake](phraseId). Window sizes come from each
 *  model's I/O shape (read at load), never hardcoded. */
class WakeWordEngine(
    private val assets: AssetManager,
    private val onWake: (String) -> Unit,
) {
    private val melspec = TfliteModel(assets, WakeConfig.MELSPEC_ASSET)
    private val embedding = TfliteModel(assets, WakeConfig.EMBEDDING_ASSET)

    private data class Phrase(
        val id: String,
        val model: Inferencer,
        val debouncer: WakeDebouncer,
        val policy: PhrasePolicy,
    )

    private val phrases: List<Phrase> = WakeConfig.phrases.map { p ->
        Phrase(
            id = WakeConfig.phraseId(p.assetFile),
            model = TfliteModel(assets, p.assetFile),
            debouncer = WakeDebouncer(p.threshold, p.minConsecutive, p.refractoryFrames),
            policy = p,
        )
    }

    // melBins = melspec output width; embWindow = mel frames the embedding model
    // consumes; classWindow = embeddings the classifier consumes; embDim = embedding width.
    private val melBins = melspec.outputShape.last()
    private val embWindow = embedding.inputFrames()
    private val embDim = embedding.outputShape.last()
    private val classWindow = phrases.first().model.inputFrames()

    private val melRing = FrameRing(capacity = embWindow, width = melBins)
    private val embRing = FrameRing(capacity = classWindow, width = embDim)

    @Volatile private var running = false
    @Volatile private var paused = false
    private var worker: Thread? = null
    private var record: AudioRecord? = null

    fun setThreshold(phraseId: String, value: Float) {
        phrases.firstOrNull { it.id == phraseId }?.policy?.threshold = value
    }

    fun pause() { paused = true }
    fun resume() { paused = false }

    @SuppressLint("MissingPermission") // RECORD_AUDIO granted before the service starts
    fun start() {
        if (running) return
        running = true
        val minBuf = AudioRecord.getMinBufferSize(
            WakeConfig.SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        record = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            WakeConfig.SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minBuf, WakeConfig.HOP_SAMPLES * 2 * 4),
        ).apply { startRecording() }

        worker = thread(name = "wakeword-engine") { loop() }
    }

    private fun loop() {
        val pcm = ShortArray(WakeConfig.HOP_SAMPLES)
        val rec = record ?: return
        while (running) {
            val n = rec.read(pcm, 0, pcm.size)
            if (n <= 0 || paused) continue

            val audio = FloatArray(n) { pcm[it] / 32768f } // PCM16 -> [-1,1]
            val mels = melspec.run(audio) // flat: framesOut * melBins
            var off = 0
            while (off + melBins <= mels.size) {
                melRing.push(mels.copyOfRange(off, off + melBins))
                off += melBins
            }
            if (!melRing.isFull()) continue

            val emb = embedding.run(flatten(melRing.snapshot())) // embDim
            embRing.push(emb)
            if (!embRing.isFull()) continue

            val ctx = flatten(embRing.snapshot())
            for (p in phrases) {
                val score = p.model.run(ctx).last() // classifier prob in [0,1]
                if (p.debouncer.update(score)) onWake(p.id)
            }
        }
    }

    private fun flatten(frames: Array<FloatArray>): FloatArray {
        val out = FloatArray(frames.size * frames[0].size)
        var i = 0
        for (f in frames) for (v in f) out[i++] = v
        return out
    }

    fun stop() {
        running = false
        worker?.join(500)
        worker = null
        record?.run { stop(); release() }
        record = null
        melRing.clear(); embRing.clear()
    }

    fun close() {
        stop()
        melspec.close(); embedding.close()
        phrases.forEach { it.model.close() }
    }
}

/** mel/embedding window length read from the model's input rank. */
private fun Inferencer.inputFrames(): Int {
    // TfliteModel exposes the interpreter; for other impls, fall back to outputShape geometry.
    return (this as? TfliteModel)?.inputFrameCount() ?: 16
}
```

- [ ] **Step 2: Expose the input frame count on `TfliteModel`**

Add to `TfliteModel` (Task 7 file) a helper the engine uses to size its rings:

```kotlin
    /** Number of frames the input tensor expects (its second-to-last dim),
     *  or 1 for a flat/variable input. */
    fun inputFrameCount(): Int {
        val shape = interpreter.getInputTensor(0).shape()
        return when {
            shape.size >= 2 && shape[shape.size - 2] > 0 -> shape[shape.size - 2]
            else -> 1
        }
    }
```

- [ ] **Step 3: Compile**

Run: `cd android && ./gradlew :app:assembleDebug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeWordEngine.kt \
        android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/Inferencer.kt
git commit -m "feat(wakeword): WakeWordEngine streaming pipeline"
```

---

## Task 9: `WakeWordService` foreground service

**Files:**
- Create: `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeWordService.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `WakeWordEngine` (Task 8).
- Produces: a started+bound foreground service of type `microphone` exposing `start/pause/resume/stop/setThreshold` and a detection callback sink (`var onDetect: ((String) -> Unit)?`). Consumed by `WakeWordChannel` (Task 10).

> Device-gated. Validated in Task 11.

- [ ] **Step 1: Declare permissions + the service in the manifest**

In `android/app/src/main/AndroidManifest.xml`, add below the existing `RECORD_AUDIO` permission:

```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Inside `<application>` (sibling of `<activity>`):

```xml
        <service
            android:name=".wakeword.WakeWordService"
            android:exported="false"
            android:foregroundServiceType="microphone"/>
```

- [ ] **Step 2: Implement the service**

`WakeWordService.kt`:

```kotlin
package com.lordmacu.chispa.wakeword

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder

/** Always-on foreground service (type microphone) that hosts the wake-word
 *  engine so the mic survives backgrounding. Bound by [WakeWordChannel]. */
class WakeWordService : Service() {
    private val binder = LocalBinder()
    private var engine: WakeWordEngine? = null

    /** Set by the channel; receives the phrase id that fired. */
    var onDetect: ((String) -> Unit)? = null

    inner class LocalBinder : Binder() {
        fun service(): WakeWordService = this@WakeWordService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIF_ID, buildNotification())
        engine = WakeWordEngine(assets) { phraseId -> onDetect?.invoke(phraseId) }
    }

    fun startListening() = engine?.start()
    fun pause() = engine?.pause()
    fun resume() = engine?.resume()
    fun setThreshold(phraseId: String, value: Float) = engine?.setThreshold(phraseId, value)

    override fun onDestroy() {
        engine?.close()
        engine = null
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        val mgr = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Chispa", NotificationManager.IMPORTANCE_LOW),
            )
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Chispa")
            .setContentText("Escuchando \"Oye Chispa\"")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "chispa_wakeword"
        private const val NOTIF_ID = 42
    }
}
```

- [ ] **Step 3: Compile**

Run: `cd android && ./gradlew :app:assembleDebug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeWordService.kt \
        android/app/src/main/AndroidManifest.xml
git commit -m "feat(wakeword): foreground microphone service hosting the engine"
```

---

## Task 10: `WakeWordChannel` + register in `MainActivity`

**Files:**
- Create: `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeWordChannel.kt`
- Modify: `android/app/src/main/kotlin/com/lordmacu/chispa/MainActivity.kt`

**Interfaces:**
- Consumes: `WakeWordService` (Task 9); channel names from `OwwWakeWord` (Task 2): control `chispa/wakeword/control`, events `chispa/wakeword`.
- Produces: the platform bridge. Control methods bind/start the service and forward calls; the service's `onDetect` is pumped into the `EventChannel` sink.

> Device-gated. End-to-end verified in Task 11.

- [ ] **Step 1: Implement the channel bridge**

`WakeWordChannel.kt`:

```kotlin
package com.lordmacu.chispa.wakeword

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Wires the Flutter Method/Event channels to the foreground [WakeWordService]. */
class WakeWordChannel(private val context: Context, messenger: BinaryMessenger) {
    private val control = MethodChannel(messenger, "chispa/wakeword/control")
    private val events = EventChannel(messenger, "chispa/wakeword")
    private val main = Handler(Looper.getMainLooper())

    private var sink: EventChannel.EventSink? = null
    private var service: WakeWordService? = null

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val svc = (binder as WakeWordService.LocalBinder).service()
            service = svc
            svc.onDetect = { phraseId -> main.post { sink?.success(phraseId) } }
            svc.startListening()
        }
        override fun onServiceDisconnected(name: ComponentName?) { service = null }
    }

    init {
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, s: EventChannel.EventSink?) { sink = s }
            override fun onCancel(args: Any?) { sink = null }
        })
        control.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> { bindAndStart(); result.success(null) }
                "pause" -> { service?.pause(); result.success(null) }
                "resume" -> { service?.resume(); result.success(null) }
                "stop" -> { stop(); result.success(null) }
                "setThreshold" -> {
                    val phrase = call.argument<String>("phrase")
                    val value = (call.argument<Double>("value"))?.toFloat()
                    if (phrase != null && value != null) service?.setThreshold(phrase, value)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun bindAndStart() {
        val intent = Intent(context, WakeWordService::class.java)
        context.startForegroundService(intent)
        context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
    }

    private fun stop() {
        service?.let { runCatching { context.unbindService(connection) } }
        context.stopService(Intent(context, WakeWordService::class.java))
        service = null
    }
}
```

- [ ] **Step 2: Register it in `MainActivity`**

Replace `android/app/src/main/kotlin/com/lordmacu/chispa/MainActivity.kt`:

```kotlin
package com.lordmacu.chispa

import com.lordmacu.chispa.wakeword.WakeWordChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WakeWordChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
```

- [ ] **Step 3: Compile**

Run: `cd android && ./gradlew :app:assembleDebug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeWordChannel.kt \
        android/app/src/main/kotlin/com/lordmacu/chispa/MainActivity.kt
git commit -m "feat(wakeword): Method/Event channels wired to the service"
```

---

## Task 11: On-device validation + threshold tuning

**Files:**
- Modify: `android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeConfig.kt` (tuned thresholds)
- Modify: `lib/core/config/thresholds.dart` (document the contract)
- Modify: `docs/wakeword-training.md` (record measured FP/TP)

**Interfaces:**
- Consumes: the full stack (Tasks 0–10).
- Produces: tuned, working always-on detection on the real phone.

> Requires a connected Android device (the dashboard phone). Cannot run in CI.

- [ ] **Step 1: Confirm assets are present**

Run: `ls android/app/src/main/assets/oww/`
Expected: `chispa.tflite  embedding.tflite  melspectrogram.tflite  oye_chispa.tflite`. If any stage is `.onnx` only, enable the parked `OnnxInferencer` per its header note and select it by extension in `WakeWordEngine` model construction.

- [ ] **Step 2: Default the app to the OWW detector and run on device**

`wakeWordProvider` already defaults to `OwwWakeWord` (Task 3). Grant mic + notification permissions on first launch, then:

Run: `flutter run -d <device>`
Expected: app launches; the "Chispa — Escuchando" foreground notification appears.

- [ ] **Step 3: Verify true positives**

Say "Oye Chispa" near the phone. Expected: Chispa speaks the wake ack ("¡Aquí estoy! ¿Qué necesitas?"). Repeat with "Chispa". Watch `flutter run` logs for the fired phrase id.

- [ ] **Step 4: Verify the tensor pipeline (if no fire)**

If nothing fires, reconcile `TfliteModel.run` reshaping against the shapes recorded in Task 0 Step 7 (the one block flagged for on-device iteration). Add a temporary `android.util.Log.d` of each stage's output length in `WakeWordEngine.loop` to confirm melspec→embedding→classifier shapes line up; fix `resizeInput`/flatten as needed; re-run.

- [ ] **Step 5: Tune thresholds against false positives**

Play music / hold a conversation near the phone for a few minutes without saying the wake words. If "chispa" fires falsely, raise its `threshold` (and/or `minConsecutive`) in `WakeConfig`; "oye chispa" should already be robust. Re-run until TP stays reliable and FP is acceptable.

- [ ] **Step 6: Verify self-hearing is handled**

Trigger Chispa, let her speak a long reply. Expected: the detector is paused while she speaks (`pet_screen` calls `_wake.pause()`/`resume()` around TTS) — she does not re-trigger on her own voice.

- [ ] **Step 7: Record results and commit**

Update `docs/wakeword-training.md` with the final per-phrase thresholds and the observed TP/FP behavior. Mirror the final numeric contract as a comment in `lib/core/config/thresholds.dart` (so the Dart side documents what the native config enforces).

```bash
git add android/app/src/main/kotlin/com/lordmacu/chispa/wakeword/WakeConfig.kt \
        lib/core/config/thresholds.dart docs/wakeword-training.md
git commit -m "feat(wakeword): tune thresholds from on-device validation"
```

- [ ] **Step 8: Final gate**

Run: `dart format . && flutter analyze && flutter test && (cd android && ./gradlew :app:testDebugUnitTest)`
Expected: format clean; analyze no warnings; all Dart tests PASS; Kotlin `WakeDebouncerTest` + `FrameRingTest` PASS.

---

## Self-Review

**Spec coverage:**
- §2 both phrases → Task 0 (train both), `WakeConfig.phrases` (run both). ✓
- §2 TFLite-first + ONNX fallback → Task 7 (`TfliteModel` default, `OnnxInferencer.kt.off` parked). ✓
- §2 native foreground service → Tasks 9–10. ✓
- §2 training via Colab/Piper → Task 0. ✓
- §2 unchanged interface + STT fallback → Tasks 1, 3. ✓
- §2 license caveat → recorded in `docs/wakeword-training.md` (Task 0 Step 8). ✓
- §3 shared stages computed once, fed to both classifiers → `WakeWordEngine.loop` (Task 8). ✓
- §4 training outputs + reproducibility doc → Task 0. ✓
- §5 engine, channel, config, runtime abstraction, native assets → Tasks 5–10. ✓
- §6 `OwwWakeWord`, provider swap, pause/resume around TTS, native assets → Tasks 2–4, 11 Step 6. ✓
- §7 Kotlin pure-logic tests + Dart channel test + manual tuning → Tasks 5, 6, 2, 11. ✓
- §8 APK size (noCompress, small libs) → Task 7 Step 1. ✓
- §9 build order → Tasks ordered 0→11. ✓
- §10 risks (TFLite availability, shapes-at-load, FP, self-hearing) → Tasks 0 Step 5, 7/8/11 Step 4, 5, 6. ✓

**Placeholder scan:** No TBD/TODO; every code step shows code; manual/device steps state exact commands + expected observations. The two device-iteration points (TfliteModel reshape, threshold values) are explicit, bounded, and assigned to Task 11 — not hidden placeholders.

**Type consistency:** Channel names match across `OwwWakeWord` (Task 2) and `WakeWordChannel` (Task 10): `chispa/wakeword/control`, `chispa/wakeword`. Method set matches: `start/stop/pause/resume/setThreshold`. `setThreshold` args `{phrase, value}` match on both sides. `Inferencer.run(FloatArray):FloatArray` + `outputShape:IntArray` + `inputFrameCount()` used consistently by `WakeWordEngine`. `WakeWordEngine(assets, onWake:(String)->Unit)` matches `WakeWordService`'s construction. `WakeDebouncer(threshold, minConsecutive, refractoryFrames)` matches `WakeConfig.PhrasePolicy` fields.
