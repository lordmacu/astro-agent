# Settings screen — design

**Date:** 2026-07-01
**Status:** approved for planning

## Goal

Add a configuration area to the app: a ⚙️ icon in the top-right of `PetScreen`
that opens a `SettingsScreen` where all runtime configuration lives. The headline
capability is **downloading the neural voice on demand** (so the ~65 MB Piper
model no longer has to be bundled and inflate the APK), plus runtime control of
the AI engine/keys, voice, wake word, sensors, memory, permissions, and an about
section.

This is intentionally a *broad* spec (the full map) implemented in *vertical
slices*. Each slice is independently shippable.

## Guiding principles (from CLAUDE.md)

- Code in English (identifiers, comments, docs). Astro's voice stays bilingual
  and lives only in `voice/speech_catalog.dart`.
- Immutable models; Riverpod for state/DI; no new state library.
- Numeric thresholds live in `core/config/thresholds.dart`.
- Basic behavior must keep working without optional hardware/keys. Settings only
  *add* control; sensible defaults keep the current behavior when nothing is set.
- OBD stays disabled (per project memory); no OBD toggles in this work.

## A. Navigation & screen

- Add a ⚙️ `IconButton` to `PetScreen`, positioned top-right via a `Stack` +
  `Positioned` inside the existing `SafeArea` so it does not disturb the centered
  column layout. Tinted with the current ambient/mood accent.
- Tapping pushes `SettingsScreen` with `Navigator.push` (a
  `MaterialPageRoute`). The app stays single-route + one modal screen; no router
  package is introduced.
- Guard: opening settings must not fight the voice pipeline. Opening the screen
  calls `wake.pause()` on entry and `wake.resume()` on pop (Astro shouldn't be
  listening for the wake word while the driver edits settings). This reuses the
  existing `WakeWordDetector.pause/resume`.
- `SettingsScreen` is a `ConsumerWidget` rendering a scrollable list of grouped
  sections. Visual style follows `design_tokens.dart` (Fredoka labels, dark
  surface, accent `#43d6cf`). Each section is its own small widget under
  `lib/ui/settings/` so files stay focused.

## B. Settings store (the core)

New `lib/core/config/settings_store.dart`:

- Thin wrapper over `shared_preferences` (already a dependency). Exposes typed
  getters/setters keyed by an enum of setting keys (avoids stringly-typed bugs).
- Exposed through Riverpod. Pattern:
  - `sharedPreferencesProvider` — a `FutureProvider<SharedPreferences>` resolved
    once at startup (or overridden in `main.dart` after `getInstance`).
  - `settingsStoreProvider` — `Provider<SettingsStore>` built from it.
  - One small `StateNotifier`/`Notifier` per mutable setting group so UI edits
    persist and notify dependents reactively.

### Precedence for values that today come from `.env`

API key, model, and search key currently resolve via `_secret()` in
`astro_brain_provider.dart` (`.env` → dart-define → default). The store adds a
**user-override layer on top**:

```
user setting (SharedPreferences)  >  .env  >  dart-define  >  hardcoded default
```

Implementation: introduce a single resolver used by the brain providers, e.g.
`settingsResolvedValue(key, envName, define, fallback)` that first checks the
store, then falls back to the existing `_secret()` chain. The current `_secret()`
logic is preserved as the lower layers. `astroConfiguredProvider`,
`astroModelProvider`, and the search-provider builder read through this resolver
so pasting a key in the UI takes effect without touching `.env`.

Because the brain is a `FutureProvider` built from these values, changing a key
or model **invalidates `astroBrainProvider`** (`ref.invalidate`) so the next turn
uses the new config. No app restart required.

### Persistence & security note

- API keys are stored in `SharedPreferences` (plaintext on-device). This matches
  the current `.env`-on-device posture and is acceptable for a personal
  dashboard app. Not using flutter_secure_storage to avoid a new dependency;
  documented as a known trade-off. Key fields render obscured with a reveal
  toggle.

## C. Sections (what each contains)

1. **Voice**
   - Neural voice: state chip (not downloaded / downloading N% / ready / error),
     download button, and an enable toggle (only effective once downloaded).
   - Language: EN / ES (drives `speech_catalog` selection; default ES to match
     today's behavior).
   - Rate and pitch sliders (applied to whichever TTS engine is active).
2. **AI**
   - Provider/model field (default `MiniMax-M3`).
   - LLM API key (obscured + reveal).
   - Web-search API key (Tavily/Brave) — optional.
3. **Wake word & sensors**
   - Wake word on/off + sensitivity.
   - Toggles: navigation (Maps) listener, automatic brightness by ambient light.
   - (No OBD — stays disabled.)
4. **Memory**
   - Show long-term memory item count; "clear memory" with a confirm dialog
     (calls into `LongTermMemory`).
5. **Permissions**
   - Buttons to (re)request mic / notifications / location, showing current
     grant status.
6. **About**
   - App version (`package_info` or a const), neural-model status, a short
     diagnostics blob (which keys/engines are active) for troubleshooting.

## D. Neural voice download ("download the language") — the heavy slice

Unparks the sherpa/Piper path described in CLAUDE.md, but **downloaded, not
bundled**.

- **Dependencies:** re-enable `sherpa_onnx`, `audioplayers`, `archive`,
  `path_provider` in `pubspec.yaml`. Do **not** re-enable the bundled
  `assets/tts/...zip` asset — the model comes over the network instead.
- **Rename** `lib/voice/sherpa_tts.dart.off` → `sherpa_tts.dart`.
- **Model source:** a hosted zip (default: a GitHub Release asset of this repo),
  URL held in a const in `thresholds.dart`/config and overridable via `.env`
  (`TTS_MODEL_URL`). The zip contains the Piper `.onnx` + tokens, same layout the
  parked `sherpa_tts` expects.
- **Downloader:** new `lib/voice/neural_voice_installer.dart`:
  - Downloads to app documents dir (`path_provider`), streaming with progress.
  - Verifies size/basic integrity, unzips (`archive`), marks a
    "installed" flag + stored path in `SettingsStore`.
  - Exposes a state stream: `NotDownloaded | Downloading(progress) | Ready | Error`.
  - Idempotent + resumable-enough: a partial/failed download is cleaned up and
    retried; an already-installed model short-circuits.
- **Engine selection:** `ttsProvider` becomes a `Provider` that returns
  `SherpaTts(modelPath)` **iff** neural is installed *and* enabled in settings,
  else `SystemTts()`. `warmUp()` is called when neural becomes active. The viseme
  pipeline already compiles with either engine (per CLAUDE.md), so no UI change.
- **Fallback:** any neural init failure logs and falls back to `SystemTts` so
  voice never breaks.

## E. Build order (vertical slices)

1. **Scaffold + store + one real setting end-to-end.**
   ⚙️ icon → `SettingsScreen`, `SettingsStore` + providers, wake pause/resume on
   open/close, and the voice **rate** slider wired through to the active TTS.
   Proves the whole pattern (persist → provider → service applies it).
2. **AI section.** Model + LLM key + search key with the user-override resolver
   on top of `.env`; `astroBrainProvider` invalidation on change.
3. **Toggles slice.** Wake word on/off + sensitivity, nav listener, auto
   brightness, memory count/clear, permission request buttons, about. (Fast,
   reuse the store.)
4. **Neural voice download.** The heavy, higher-risk slice, done last: deps,
   rename, installer, download UI, engine selection.

## F. Testing

- `SettingsStore`: get/set/defaults/precedence with
  `SharedPreferences.setMockInitialValues`.
- Resolver precedence: user > .env > define > default (unit test the resolver in
  isolation, mocking the store and dotenv absence).
- Providers that reconfigure services: verify a settings change invalidates
  `astroBrainProvider` and that `ttsProvider` returns neural vs system per the
  installed/enabled flags (mock the installer state).
- `NeuralVoiceInstaller`: state transitions with a fake HTTP client returning a
  small zip; error path cleans up partial files. Mock the filesystem paths.
- Keep `mood_resolver` and existing tests untouched/green.

## Non-goals (YAGNI)

- No OBD settings (OBD stays disabled).
- No cloud sync of settings; device-local only.
- No `flutter_secure_storage` migration (documented trade-off above).
- No multi-profile / per-user settings.
- No in-app model *browser* — a single configurable model field is enough.
