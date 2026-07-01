# Settings Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a ⚙️ settings area to Astro where all runtime config lives, including on-demand download of the neural voice (so the ~65 MB Piper model is not bundled).

**Architecture:** A `SettingsStore` over `shared_preferences` exposed through Riverpod holds all settings as an immutable `AppSettings` (freezed) with a `SettingsNotifier`. A ⚙️ icon on `PetScreen` pushes `SettingsScreen`, which renders grouped section widgets. Settings that today come from `.env` (LLM key/model, search key) resolve through a new layer `user setting > .env > dart-define > default`; changing them invalidates `astroBrainProvider`. The parked sherpa/Piper voice is unparked as a *downloaded* (not bundled) model via a `NeuralVoiceInstaller`, and `ttsProvider` selects neural vs system based on installed+enabled flags.

**Tech Stack:** Flutter, Riverpod 2, freezed, shared_preferences, flutter_tts (system TTS), sherpa_onnx + audioplayers + archive + path_provider (neural TTS), http (model download), sqflite (memory).

## Global Constraints

- Code (identifiers, comments, docs, filenames) in **English only**. Astro's spoken voice may be Spanish; UI strings shown to the driver follow the existing screens' Spanish copy.
- Immutable models via **freezed** + `copyWith`; never mutate in place.
- State/DI via **Riverpod 2** only. No new state-management or stream library.
- Numeric constants live in `lib/core/config/thresholds.dart` — no magic numbers in logic.
- Basic behavior must keep working with **no settings set**: every setting has a default equal to today's behavior.
- **OBD stays disabled** — do not add OBD settings or re-enable OBD code.
- Git identity for every commit: `user.name=lordmacu`, `user.email=10134930+lordmacu@users.noreply.github.com`. **Never** add a `Co-Authored-By` / Claude coauthor line.
- Before declaring a task done: `dart format .` and `flutter analyze` with no new warnings.
- Run `dart run build_runner build --delete-conflicting-outputs` after editing any freezed file.

---

## Phase 1 — Scaffold, store, one real setting end-to-end

### Task 1: SettingsStore + Riverpod providers

**Files:**
- Create: `lib/core/config/setting_key.dart`
- Create: `lib/core/config/settings_store.dart`
- Create: `lib/core/config/settings_providers.dart`
- Test: `test/core/config/settings_store_test.dart`

**Interfaces:**
- Produces:
  - `enum SettingKey { voiceRate, voicePitch, voiceLanguage, neuralVoiceEnabled, neuralVoiceInstalled, neuralVoicePath, llmModel, llmApiKey, searchApiKey, wakeWordEnabled, wakeWordSensitivity, navListenerEnabled, autoBrightnessEnabled }`
  - `class SettingsStore` with `String getString(SettingKey,String)`, `Future<void> setString(SettingKey,String)`, `double getDouble(SettingKey,double)`, `Future<void> setDouble(SettingKey,double)`, `bool getBool(SettingKey,bool)`, `Future<void> setBool(SettingKey,bool)`, `Future<void> remove(SettingKey)`.
  - `final sharedPreferencesProvider = Provider<SharedPreferences>(...)` (override-in-main).
  - `final settingsStoreProvider = Provider<SettingsStore>(...)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/config/settings_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/setting_key.dart';
import 'package:astro/core/config/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns the fallback when a key is unset', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    expect(store.getDouble(SettingKey.voiceRate, 0.56), 0.56);
    expect(store.getBool(SettingKey.wakeWordEnabled, true), true);
    expect(store.getString(SettingKey.llmModel, 'MiniMax-M3'), 'MiniMax-M3');
  });

  test('persists and reads back a value', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    await store.setDouble(SettingKey.voiceRate, 0.7);
    expect(store.getDouble(SettingKey.voiceRate, 0.56), 0.7);
  });

  test('remove restores the fallback', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    await store.setString(SettingKey.llmApiKey, 'secret');
    await store.remove(SettingKey.llmApiKey);
    expect(store.getString(SettingKey.llmApiKey, ''), '');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/config/settings_store_test.dart`
Expected: FAIL — `SettingsStore` / `SettingKey` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/config/setting_key.dart
/// Every persisted setting, keyed by name in SharedPreferences. Using an enum
/// (instead of raw strings) keeps reads and writes typo-proof.
enum SettingKey {
  voiceRate,
  voicePitch,
  voiceLanguage,
  neuralVoiceEnabled,
  neuralVoiceInstalled,
  neuralVoicePath,
  llmModel,
  llmApiKey,
  searchApiKey,
  wakeWordEnabled,
  wakeWordSensitivity,
  navListenerEnabled,
  autoBrightnessEnabled,
}
```

```dart
// lib/core/config/settings_store.dart
import 'package:shared_preferences/shared_preferences.dart';

import 'setting_key.dart';

/// Typed wrapper over SharedPreferences. Each getter takes the fallback to use
/// when the key is unset, so callers never see a null and defaults live at the
/// call site next to the setting's meaning.
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  String getString(SettingKey key, String fallback) =>
      _prefs.getString(key.name) ?? fallback;

  Future<void> setString(SettingKey key, String value) =>
      _prefs.setString(key.name, value);

  double getDouble(SettingKey key, double fallback) =>
      _prefs.getDouble(key.name) ?? fallback;

  Future<void> setDouble(SettingKey key, double value) =>
      _prefs.setDouble(key.name, value);

  bool getBool(SettingKey key, bool fallback) =>
      _prefs.getBool(key.name) ?? fallback;

  Future<void> setBool(SettingKey key, bool value) =>
      _prefs.setBool(key.name, value);

  Future<void> remove(SettingKey key) => _prefs.remove(key.name);
}
```

```dart
// lib/core/config/settings_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';

/// SharedPreferences, resolved once at startup. Overridden in main.dart with the
/// real instance; the throwing default surfaces a missing override immediately.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('override sharedPreferencesProvider in main'),
);

/// The typed settings store, built on the resolved SharedPreferences.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(sharedPreferencesProvider)),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/config/settings_store_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/setting_key.dart lib/core/config/settings_store.dart lib/core/config/settings_providers.dart test/core/config/settings_store_test.dart
git commit -m "feat(settings): typed SettingsStore over shared_preferences"
```

---

### Task 2: AppSettings model + SettingsNotifier

**Files:**
- Create: `lib/core/config/app_settings.dart`
- Create: `lib/core/config/settings_notifier.dart`
- Modify: `lib/core/config/settings_providers.dart` (add `settingsProvider`)
- Test: `test/core/config/settings_notifier_test.dart`

**Interfaces:**
- Consumes: `SettingsStore`, `SettingKey`, `settingsStoreProvider` (Task 1).
- Produces:
  - `class AppSettings` (freezed) with fields: `double voiceRate`, `double voicePitch`, `String voiceLanguage`, `bool neuralVoiceEnabled`, `bool neuralVoiceInstalled`, `String neuralVoicePath`, `String llmModel`, `String llmApiKey`, `String searchApiKey`, `bool wakeWordEnabled`, `double wakeWordSensitivity`, `bool navListenerEnabled`, `bool autoBrightnessEnabled`; plus `factory AppSettings.fromStore(SettingsStore)`.
  - `class SettingsNotifier extends Notifier<AppSettings>` with typed setters, each persisting then updating state: `setVoiceRate(double)`, `setVoicePitch(double)`, `setVoiceLanguage(String)`, `setNeuralVoiceEnabled(bool)`, `setNeuralVoiceInstalled(bool)`, `setNeuralVoicePath(String)`, `setLlmModel(String)`, `setLlmApiKey(String)`, `setSearchApiKey(String)`, `setWakeWordEnabled(bool)`, `setWakeWordSensitivity(double)`, `setNavListenerEnabled(bool)`, `setAutoBrightnessEnabled(bool)`.
  - `final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(...)`.
- Defaults (must match today's behavior): `voiceRate 0.56`, `voicePitch 1.0`, `voiceLanguage 'es'`, `neuralVoiceEnabled false`, `neuralVoiceInstalled false`, `neuralVoicePath ''`, `llmModel 'MiniMax-M3'`, `llmApiKey ''`, `searchApiKey ''`, `wakeWordEnabled true`, `wakeWordSensitivity 0.5`, `navListenerEnabled true`, `autoBrightnessEnabled true`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/config/settings_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/app_settings.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/config/settings_store.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exposes defaults matching current behavior', () async {
    final c = await _container();
    final s = c.read(settingsProvider);
    expect(s.voiceRate, 0.56);
    expect(s.llmModel, 'MiniMax-M3');
    expect(s.wakeWordEnabled, true);
  });

  test('a setter persists and updates state', () async {
    final c = await _container();
    await c.read(settingsProvider.notifier).setVoiceRate(0.8);
    expect(c.read(settingsProvider).voiceRate, 0.8);
    // Persisted: a fresh store built on the same prefs sees the new value.
    final store = c.read(settingsStoreProvider);
    expect(store, isA<SettingsStore>());
    expect(AppSettings.fromStore(store).voiceRate, 0.8);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/config/settings_notifier_test.dart`
Expected: FAIL — `AppSettings` / `settingsProvider` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/config/app_settings.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'setting_key.dart';
import 'settings_store.dart';

part 'app_settings.freezed.dart';

/// Immutable snapshot of every user setting. Built from the store on startup and
/// replaced (copyWith) on each edit.
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    required double voiceRate,
    required double voicePitch,
    required String voiceLanguage,
    required bool neuralVoiceEnabled,
    required bool neuralVoiceInstalled,
    required String neuralVoicePath,
    required String llmModel,
    required String llmApiKey,
    required String searchApiKey,
    required bool wakeWordEnabled,
    required double wakeWordSensitivity,
    required bool navListenerEnabled,
    required bool autoBrightnessEnabled,
  }) = _AppSettings;

  factory AppSettings.fromStore(SettingsStore s) => AppSettings(
        voiceRate: s.getDouble(SettingKey.voiceRate, 0.56),
        voicePitch: s.getDouble(SettingKey.voicePitch, 1.0),
        voiceLanguage: s.getString(SettingKey.voiceLanguage, 'es'),
        neuralVoiceEnabled: s.getBool(SettingKey.neuralVoiceEnabled, false),
        neuralVoiceInstalled: s.getBool(SettingKey.neuralVoiceInstalled, false),
        neuralVoicePath: s.getString(SettingKey.neuralVoicePath, ''),
        llmModel: s.getString(SettingKey.llmModel, 'MiniMax-M3'),
        llmApiKey: s.getString(SettingKey.llmApiKey, ''),
        searchApiKey: s.getString(SettingKey.searchApiKey, ''),
        wakeWordEnabled: s.getBool(SettingKey.wakeWordEnabled, true),
        wakeWordSensitivity: s.getDouble(SettingKey.wakeWordSensitivity, 0.5),
        navListenerEnabled: s.getBool(SettingKey.navListenerEnabled, true),
        autoBrightnessEnabled: s.getBool(SettingKey.autoBrightnessEnabled, true),
      );
}
```

```dart
// lib/core/config/settings_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'setting_key.dart';
import 'settings_providers.dart';
import 'settings_store.dart';

/// Holds AppSettings in memory and writes each edit through to the store. Every
/// setter persists first, then swaps state so widgets rebuild.
class SettingsNotifier extends Notifier<AppSettings> {
  SettingsStore get _store => ref.read(settingsStoreProvider);

  @override
  AppSettings build() => AppSettings.fromStore(_store);

  Future<void> setVoiceRate(double v) async {
    await _store.setDouble(SettingKey.voiceRate, v);
    state = state.copyWith(voiceRate: v);
  }

  Future<void> setVoicePitch(double v) async {
    await _store.setDouble(SettingKey.voicePitch, v);
    state = state.copyWith(voicePitch: v);
  }

  Future<void> setVoiceLanguage(String v) async {
    await _store.setString(SettingKey.voiceLanguage, v);
    state = state.copyWith(voiceLanguage: v);
  }

  Future<void> setNeuralVoiceEnabled(bool v) async {
    await _store.setBool(SettingKey.neuralVoiceEnabled, v);
    state = state.copyWith(neuralVoiceEnabled: v);
  }

  Future<void> setNeuralVoiceInstalled(bool v) async {
    await _store.setBool(SettingKey.neuralVoiceInstalled, v);
    state = state.copyWith(neuralVoiceInstalled: v);
  }

  Future<void> setNeuralVoicePath(String v) async {
    await _store.setString(SettingKey.neuralVoicePath, v);
    state = state.copyWith(neuralVoicePath: v);
  }

  Future<void> setLlmModel(String v) async {
    await _store.setString(SettingKey.llmModel, v);
    state = state.copyWith(llmModel: v);
  }

  Future<void> setLlmApiKey(String v) async {
    await _store.setString(SettingKey.llmApiKey, v);
    state = state.copyWith(llmApiKey: v);
  }

  Future<void> setSearchApiKey(String v) async {
    await _store.setString(SettingKey.searchApiKey, v);
    state = state.copyWith(searchApiKey: v);
  }

  Future<void> setWakeWordEnabled(bool v) async {
    await _store.setBool(SettingKey.wakeWordEnabled, v);
    state = state.copyWith(wakeWordEnabled: v);
  }

  Future<void> setWakeWordSensitivity(double v) async {
    await _store.setDouble(SettingKey.wakeWordSensitivity, v);
    state = state.copyWith(wakeWordSensitivity: v);
  }

  Future<void> setNavListenerEnabled(bool v) async {
    await _store.setBool(SettingKey.navListenerEnabled, v);
    state = state.copyWith(navListenerEnabled: v);
  }

  Future<void> setAutoBrightnessEnabled(bool v) async {
    await _store.setBool(SettingKey.autoBrightnessEnabled, v);
    state = state.copyWith(autoBrightnessEnabled: v);
  }
}
```

Append to `lib/core/config/settings_providers.dart`:

```dart
import 'app_settings.dart';
import 'settings_notifier.dart';

/// The reactive settings snapshot. Read for values, `.notifier` for setters.
final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
```

- [ ] **Step 4: Generate freezed code, then run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Then: `flutter test test/core/config/settings_notifier_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/app_settings.dart lib/core/config/app_settings.freezed.dart lib/core/config/settings_notifier.dart lib/core/config/settings_providers.dart test/core/config/settings_notifier_test.dart
git commit -m "feat(settings): AppSettings model + reactive SettingsNotifier"
```

---

### Task 3: Wire SharedPreferences into bootstrap

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider` (Task 1).
- Produces: a running app where `settingsProvider` resolves against the real device store.

- [ ] **Step 1: Update main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load .env (API keys) so any launch works without --dart-define. Missing or
  // malformed is fine — the app runs with canned replies until a key is set.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  // Resolve the settings store once so every setting reads synchronously.
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AstroApp(),
    ),
  );
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/main.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(settings): resolve SharedPreferences at bootstrap"
```

---

### Task 4: Reusable settings UI widgets

**Files:**
- Create: `lib/ui/settings/settings_widgets.dart`
- Test: `test/ui/settings/settings_widgets_test.dart`

**Interfaces:**
- Produces:
  - `class SettingsSection extends StatelessWidget` — `SettingsSection({required String title, required List<Widget> children})`, renders a titled card grouping.
  - `class SettingsSliderTile extends StatelessWidget` — `SettingsSliderTile({required String label, required double value, required double min, required double max, required ValueChanged<double> onChanged, String? valueLabel})`.
  - `class SettingsSwitchTile extends StatelessWidget` — `SettingsSwitchTile({required String label, String? subtitle, required bool value, required ValueChanged<bool> onChanged})`.
  - `class SettingsTextTile extends StatelessWidget` — `SettingsTextTile({required String label, required String value, required ValueChanged<String> onSubmitted, bool obscure = false, String? hint})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/settings/settings_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astro/ui/settings/settings_widgets.dart';

void main() {
  testWidgets('SettingsSwitchTile toggles', (tester) async {
    var value = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SettingsSwitchTile(
            label: 'Wake word',
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    ));
    expect(find.text('Wake word'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(value, true);
  });

  testWidgets('SettingsSection shows its title and children', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SettingsSection(title: 'Voice', children: [Text('child')]),
      ),
    ));
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('child'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/settings/settings_widgets_test.dart`
Expected: FAIL — `settings_widgets.dart` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/ui/settings/settings_widgets.dart
import 'package:flutter/material.dart';

import '../../core/config/design_tokens.dart';

/// A titled group of setting tiles, drawn as a soft card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                color: DesignTokens.accent,
                fontFamily: DesignTokens.fontDisplay,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// A labeled slider row.
class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.valueLabel,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: DesignTokens.ink)),
              Text(
                valueLabel ?? value.toStringAsFixed(2),
                style: const TextStyle(
                  color: DesignTokens.dim,
                  fontFamily: DesignTokens.fontMono,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A labeled on/off row with an optional subtitle.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: DesignTokens.ink)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(color: DesignTokens.dim)),
      value: value,
      activeTrackColor: DesignTokens.accent,
      onChanged: onChanged,
    );
  }
}

/// A labeled single-line text field that commits on submit. `obscure` hides the
/// value (API keys) with a reveal toggle.
class SettingsTextTile extends StatefulWidget {
  const SettingsTextTile({
    super.key,
    required this.label,
    required this.value,
    required this.onSubmitted,
    this.obscure = false,
    this.hint,
  });

  final String label;
  final String value;
  final ValueChanged<String> onSubmitted;
  final bool obscure;
  final String? hint;

  @override
  State<SettingsTextTile> createState() => _SettingsTextTileState();
}

class _SettingsTextTileState extends State<SettingsTextTile> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  late bool _hidden = widget.obscure;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _controller,
        obscureText: _hidden,
        style: const TextStyle(color: DesignTokens.ink),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: const TextStyle(color: DesignTokens.dim),
          suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(
                    _hidden ? Icons.visibility : Icons.visibility_off,
                    color: DesignTokens.dim,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/settings/settings_widgets_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings/settings_widgets.dart test/ui/settings/settings_widgets_test.dart
git commit -m "feat(settings): reusable section/slider/switch/text tiles"
```

---

### Task 5: SettingsScreen shell + Voice rate wired to SystemTts

**Files:**
- Create: `lib/ui/settings/settings_screen.dart`
- Modify: `lib/voice/tts_provider.dart` (read voiceRate from settings)
- Modify: `lib/ui/pet_screen.dart` (gear icon + navigation + wake pause/resume)
- Test: `test/ui/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: `settingsProvider` (Task 2), `SettingsSection`/`SettingsSliderTile` (Task 4), `ttsProvider`, `wakeWordProvider`.
- Produces: `class SettingsScreen extends ConsumerWidget`.

- [ ] **Step 1: Make `ttsProvider` read the configured rate**

```dart
// lib/voice/tts_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/settings_providers.dart';
import 'system_tts.dart';
import 'voice_interfaces.dart';

/// The active text-to-speech engine, and the single switch for voice.
///
/// Currently the **simple system TTS** (`flutter_tts`), tuned by the user's
/// voice-rate setting. The offline **neural** voice (sherpa-onnx + Piper) is
/// added later (Phase 4) as a downloaded model and selected here when installed
/// and enabled.
final ttsProvider = Provider<TextToSpeech>((ref) {
  final rate = ref.watch(settingsProvider.select((s) => s.voiceRate));
  return SystemTts(rate: rate);
});
```

- [ ] **Step 2: Write the failing widget test**

```dart
// test/ui/settings/settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/ui/settings/settings_screen.dart';

void main() {
  testWidgets('shows the Voice section and updates rate', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    expect(find.text('Configuración'), findsOneWidget);
    expect(find.text('Voz'), findsOneWidget);
    // Drag the first slider (voice rate) and confirm it persists.
    await tester.drag(find.byType(Slider).first, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(prefs.getDouble('voiceRate'), isNotNull);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/ui/settings/settings_screen_test.dart`
Expected: FAIL — `settings_screen.dart` not found.

- [ ] **Step 4: Implement the screen (voice rate only for now)**

```dart
// lib/ui/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/design_tokens.dart';
import '../../core/config/settings_providers.dart';
import 'settings_widgets.dart';

/// The single place where all runtime configuration lives. Grows section by
/// section (voice, AI, wake word, memory, permissions, about) across the plan.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          SettingsSection(
            title: 'Voz',
            children: [
              SettingsSliderTile(
                label: 'Velocidad',
                value: settings.voiceRate,
                min: 0.3,
                max: 1.0,
                onChanged: notifier.setVoiceRate,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/ui/settings/settings_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Add the gear icon + navigation to PetScreen**

In `lib/ui/pet_screen.dart`, add the import:

```dart
import 'settings/settings_screen.dart';
```

Add this method to `_PetScreenState` (opens settings, pausing the wake mic while
the driver edits, resuming on return):

```dart
  Future<void> _openSettings() async {
    await _wake.pause();
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );
    } finally {
      await _wake.resume();
    }
  }
```

Wrap the current `Scaffold`'s `body` (the `Container`) in a `Stack` with a
top-right gear button. Replace the `return Scaffold(body: Container(...))` outer
structure with:

```dart
    return Scaffold(
      body: Stack(
        children: [
          Container(
            // ...existing decoration + SafeArea + Center child unchanged...
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.settings),
              color: accent,
              onPressed: _openSettings,
            ),
          ),
        ],
      ),
    );
```

(`accent` is already computed above in `build`.)

- [ ] **Step 7: Verify analyze + full test suite**

Run: `flutter analyze && flutter test`
Expected: No new issues; all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/settings/settings_screen.dart lib/voice/tts_provider.dart lib/ui/pet_screen.dart test/ui/settings/settings_screen_test.dart
git commit -m "feat(settings): settings screen shell + gear nav + voice rate"
```

---

## Phase 2 — AI section (keys/model with .env override)

### Task 6: Settings-aware secret resolver

**Files:**
- Create: `lib/core/config/settings_resolver.dart`
- Test: `test/core/config/settings_resolver_test.dart`

**Interfaces:**
- Consumes: `SettingsStore`, `SettingKey` (Task 1).
- Produces: `String resolveSecret({required SettingsStore store, required SettingKey key, required String envDefine, String fallback = ''})` — returns the user setting when non-empty, else `envDefine` (the caller passes the existing `_secret(...)` result), else `fallback`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/config/settings_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/setting_key.dart';
import 'package:astro/core/config/settings_resolver.dart';
import 'package:astro/core/config/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsStore> store(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    return SettingsStore(await SharedPreferences.getInstance());
  }

  test('user setting wins over env', () async {
    final s = await store({'llmApiKey': 'user-key'});
    expect(
      resolveSecret(store: s, key: SettingKey.llmApiKey, envDefine: 'env-key'),
      'user-key',
    );
  });

  test('falls back to env when user setting is empty', () async {
    final s = await store({});
    expect(
      resolveSecret(store: s, key: SettingKey.llmApiKey, envDefine: 'env-key'),
      'env-key',
    );
  });

  test('falls back to the given fallback when both empty', () async {
    final s = await store({});
    expect(
      resolveSecret(
          store: s,
          key: SettingKey.llmModel,
          envDefine: '',
          fallback: 'MiniMax-M3'),
      'MiniMax-M3',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/config/settings_resolver_test.dart`
Expected: FAIL — `settings_resolver.dart` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/config/settings_resolver.dart
import 'setting_key.dart';
import 'settings_store.dart';

/// Resolve a secret/config value with precedence:
///   user setting (store) > env/dart-define (envDefine) > fallback.
/// Callers pass their existing `.env`/dart-define result as [envDefine]; this
/// only adds the user-override layer on top, so nothing about `.env` changes.
String resolveSecret({
  required SettingsStore store,
  required SettingKey key,
  required String envDefine,
  String fallback = '',
}) {
  final user = store.getString(key, '').trim();
  if (user.isNotEmpty) return user;
  if (envDefine.trim().isNotEmpty) return envDefine.trim();
  return fallback;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/config/settings_resolver_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/settings_resolver.dart test/core/config/settings_resolver_test.dart
git commit -m "feat(settings): secret resolver with user>env>fallback precedence"
```

---

### Task 7: Brain providers read through the resolver + invalidate on change

**Files:**
- Modify: `lib/brain/astro_brain_provider.dart`
- Test: `test/brain/astro_brain_config_test.dart`

**Interfaces:**
- Consumes: `resolveSecret` (Task 6), `settingsProvider`/`settingsStoreProvider` (Tasks 1–2).
- Produces: `astroConfiguredProvider`, `astroModelProvider`, and the MiniMax key/search-key resolution now honor user settings; the brain rebuilds when `llmApiKey`/`llmModel`/`searchApiKey` change.

- [ ] **Step 1: Write the failing test**

```dart
// test/brain/astro_brain_config_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/brain/astro_brain_provider.dart';
import 'package:astro/core/config/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
  }

  test('model comes from the user setting when set', () async {
    final c = await container({'llmModel': 'MiniMax-Custom'});
    expect(c.read(astroModelProvider), 'MiniMax-Custom');
  });

  test('model defaults to MiniMax-M3 when unset', () async {
    final c = await container({});
    expect(c.read(astroModelProvider), 'MiniMax-M3');
  });

  test('configured flag is true once a key is set', () async {
    final c = await container({'llmApiKey': 'k'});
    expect(c.read(astroConfiguredProvider), true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/brain/astro_brain_config_test.dart`
Expected: FAIL — providers still ignore settings (model test fails / configured false).

- [ ] **Step 3: Refactor the brain providers to read through the resolver**

In `lib/brain/astro_brain_provider.dart`:

Add imports:

```dart
import '../core/config/setting_key.dart';
import '../core/config/settings_providers.dart';
import '../core/config/settings_resolver.dart';
```

Replace the top-level getters `_miniMaxApiKey`, `_tavilyApiKey`, and the
`astroConfiguredProvider` / `astroModelProvider` / `_buildSearchProvider`
call-sites so they resolve against a passed-in `Ref`. Concretely, change the
`_secret`-based getters into `Ref`-taking helpers:

```dart
/// MiniMax API key: user setting > .env (LLM_API_KEY) > dart-define.
String _miniMaxKey(Ref ref) => resolveSecret(
      store: ref.read(settingsStoreProvider),
      key: SettingKey.llmApiKey,
      envDefine: _secret(
        'LLM_API_KEY',
        const String.fromEnvironment(
          'LLM_API_KEY',
          defaultValue: String.fromEnvironment('MINIMAX_API_KEY'),
        ),
      ),
    );

/// Web-search key: user setting > .env (TAVILY_API_KEY) > dart-define.
String _searchKey(Ref ref) => resolveSecret(
      store: ref.read(settingsStoreProvider),
      key: SettingKey.searchApiKey,
      envDefine: _secret('TAVILY_API_KEY',
          const String.fromEnvironment('TAVILY_API_KEY')),
    );
```

Update `_buildSearchProvider` to take `Ref`:

```dart
WebSearchProvider? _buildSearchProvider(Ref ref, String llmProviderId) {
  if (llmProviderId == 'minimax') {
    final key = _miniMaxKey(ref);
    return FallbackSearchProvider([
      if (key.isNotEmpty) MiniMaxSearchProvider(apiKey: key),
      DuckDuckGoProvider(),
    ]);
  }
  final tavily = _searchKey(ref);
  if (tavily.isNotEmpty) return TavilyProvider(apiKey: tavily);
  return null;
}
```

Update `astroConfiguredProvider` and `astroModelProvider` to watch settings so
they recompute on change:

```dart
final astroConfiguredProvider = Provider<bool>((ref) {
  ref.watch(settingsProvider.select((s) => s.llmApiKey));
  return _miniMaxKey(ref).isNotEmpty;
});

final astroModelProvider = Provider<String>((ref) {
  final user = ref.watch(settingsProvider.select((s) => s.llmModel)).trim();
  if (user.isNotEmpty) return user;
  return _secret('ASTRO_MODEL', const String.fromEnvironment('ASTRO_MODEL'))
      .ifEmpty('MiniMax-M3');
});
```

In `astroBrainProvider`, watch the relevant settings (so the brain rebuilds when
they change) and use the `Ref` helpers:

```dart
final astroBrainProvider = FutureProvider<AstroBrain>((ref) async {
  // Rebuild the brain whenever the key or model changes.
  ref.watch(settingsProvider.select((s) => s.llmApiKey));
  ref.watch(settingsProvider.select((s) => s.searchApiKey));
  final client = OpenAiCompatClient.miniMax(apiKey: _miniMaxKey(ref));
  // ...rest unchanged, except:
  final searchProvider = _buildSearchProvider(ref, client.providerId);
  // ...
});
```

Delete the now-unused standalone getters `_miniMaxApiKey` and `_tavilyApiKey`
(replaced by the `Ref` helpers). Keep `_secret` and the `ifEmpty` extension.

- [ ] **Step 4: Run test + analyze**

Run: `flutter test test/brain/astro_brain_config_test.dart && flutter analyze lib/brain/astro_brain_provider.dart`
Expected: PASS (3 tests); no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/brain/astro_brain_provider.dart test/brain/astro_brain_config_test.dart
git commit -m "feat(settings): brain honors user LLM key/model/search key over .env"
```

---

### Task 8: AI section UI

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart` (add AI section)
- Test: `test/ui/settings/settings_screen_test.dart` (extend)

**Interfaces:**
- Consumes: `settingsProvider`, `SettingsTextTile` (Task 4).
- Produces: an "IA" section with model + LLM key + search key fields.

- [ ] **Step 1: Add a test for the AI section**

Append to `test/ui/settings/settings_screen_test.dart`:

```dart
  testWidgets('AI section persists the model on submit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    final modelField = find.widgetWithText(TextField, 'Modelo');
    expect(modelField, findsOneWidget);
    await tester.enterText(modelField, 'MiniMax-M3-Turbo');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(prefs.getString('llmModel'), 'MiniMax-M3-Turbo');
  });
```

(Add `import 'package:flutter/services.dart';` at the top of the test file for
`TextInputAction`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/settings/settings_screen_test.dart`
Expected: FAIL — no field labeled "Modelo" yet.

- [ ] **Step 3: Add the AI section to the screen**

Insert this `SettingsSection` into the `ListView` children in
`settings_screen.dart`, after the Voz section:

```dart
          SettingsSection(
            title: 'IA',
            children: [
              SettingsTextTile(
                label: 'Modelo',
                value: settings.llmModel,
                hint: 'MiniMax-M3',
                onSubmitted: notifier.setLlmModel,
              ),
              SettingsTextTile(
                label: 'API key del LLM',
                value: settings.llmApiKey,
                obscure: true,
                onSubmitted: notifier.setLlmApiKey,
              ),
              SettingsTextTile(
                label: 'API key de búsqueda web',
                value: settings.searchApiKey,
                obscure: true,
                onSubmitted: notifier.setSearchApiKey,
              ),
            ],
          ),
```

(`SettingsTextTile` needs importing — it's already in `settings_widgets.dart`,
which the screen imports.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/settings/settings_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings/settings_screen.dart test/ui/settings/settings_screen_test.dart
git commit -m "feat(settings): AI section (model + LLM/search keys)"
```

---

## Phase 3 — Toggles: wake word, sensors, memory, permissions, about

### Task 9: Wake word + sensor toggles section

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart`
- Modify: `lib/ui/pet_screen.dart` (respect `wakeWordEnabled`)
- Test: `test/ui/settings/settings_screen_test.dart` (extend)

**Interfaces:**
- Consumes: `settingsProvider`, `SettingsSwitchTile`, `SettingsSliderTile`.
- Produces: a "Wake word y sensores" section; `PetScreen` starts the wake word only when `wakeWordEnabled`.

- [ ] **Step 1: Add a test for the wake-word toggle**

Append to `test/ui/settings/settings_screen_test.dart`:

```dart
  testWidgets('wake word toggle persists', (tester) async {
    SharedPreferences.setMockInitialValues({'wakeWordEnabled': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    final tile = find.widgetWithText(SwitchListTile, 'Palabra clave «Astro»');
    expect(tile, findsOneWidget);
    await tester.tap(tile);
    await tester.pump();
    expect(prefs.getBool('wakeWordEnabled'), false);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/settings/settings_screen_test.dart`
Expected: FAIL — no such tile.

- [ ] **Step 3: Add the section to the screen**

Insert after the IA section:

```dart
          SettingsSection(
            title: 'Wake word y sensores',
            children: [
              SettingsSwitchTile(
                label: 'Palabra clave «Astro»',
                subtitle: 'Escuchar siempre para responder por voz',
                value: settings.wakeWordEnabled,
                onChanged: notifier.setWakeWordEnabled,
              ),
              SettingsSliderTile(
                label: 'Sensibilidad',
                value: settings.wakeWordSensitivity,
                min: 0.0,
                max: 1.0,
                onChanged: notifier.setWakeWordSensitivity,
              ),
              SettingsSwitchTile(
                label: 'Navegación (Maps)',
                subtitle: 'Reaccionar a las indicaciones de Google Maps',
                value: settings.navListenerEnabled,
                onChanged: notifier.setNavListenerEnabled,
              ),
              SettingsSwitchTile(
                label: 'Brillo automático',
                subtitle: 'Ajustar el brillo con la luz del ambiente',
                value: settings.autoBrightnessEnabled,
                onChanged: notifier.setAutoBrightnessEnabled,
              ),
            ],
          ),
```

- [ ] **Step 4: Respect `wakeWordEnabled` in PetScreen**

In `lib/ui/pet_screen.dart` `initState`, replace the unconditional
`_wake.start();` with:

```dart
    if (ref.read(settingsProvider).wakeWordEnabled) {
      _wake.start();
    }
```

Add `import '../core/config/settings_providers.dart';` to `pet_screen.dart`.

- [ ] **Step 5: Run test + analyze**

Run: `flutter test test/ui/settings/settings_screen_test.dart && flutter analyze`
Expected: PASS; no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/settings/settings_screen.dart lib/ui/pet_screen.dart test/ui/settings/settings_screen_test.dart
git commit -m "feat(settings): wake word + sensor toggles; gate wake start on setting"
```

> Note: wiring `wakeWordSensitivity`, `navListenerEnabled`, and
> `autoBrightnessEnabled` into their services is deferred — the settings persist
> and are read by their owners in follow-up work. This task only guarantees the
> wake-word on/off gate is live, which is the user-visible behavior.

---

### Task 10: Memory section (count + clear)

**Files:**
- Modify: `lib/memory/long_term_memory.dart` (add `clearAll`)
- Modify: `lib/ui/settings/settings_screen.dart`
- Test: `test/memory/long_term_memory_clear_test.dart`

**Interfaces:**
- Consumes: `memoryProvider` (from `astro_brain_provider.dart`), `LongTermMemory.count()`.
- Produces: `Future<int> LongTermMemory.clearAll()` (returns rows removed); a "Memoria" section showing the count with a clear button + confirm dialog.

- [ ] **Step 1: Write the failing test**

```dart
// test/memory/long_term_memory_clear_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:astro/memory/long_term_memory.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('clearAll empties the store', () async {
    final mem = await LongTermMemory.open(
      factory: databaseFactory,
      path: inMemoryDatabasePath,
    );
    await mem.remember('the driver likes jazz');
    expect(await mem.count(), 1);
    final removed = await mem.clearAll();
    expect(removed, 1);
    expect(await mem.count(), 0);
    await mem.close();
  });
}
```

(If `sqflite_common_ffi` is not yet a dev dependency, add it:
`flutter pub add --dev sqflite_common_ffi`, then `flutter pub get`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/memory/long_term_memory_clear_test.dart`
Expected: FAIL — `clearAll` not defined.

- [ ] **Step 3: Add `clearAll` to LongTermMemory**

Add this method to `class LongTermMemory` (near `forget`), deleting from all
three tables the schema uses:

```dart
  /// Remove every memory for this agent. Returns how many rows were deleted.
  Future<int> clearAll() async {
    final removed = await _db.delete(
      'memories',
      where: 'agent_id = ?',
      whereArgs: [agentId],
    );
    await _db.delete('memories_fts');
    await _db.delete('memory_vectors');
    return removed;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/memory/long_term_memory_clear_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the Memoria section to the screen**

Add these imports to `settings_screen.dart`:

```dart
import '../../brain/astro_brain_provider.dart';
```

Add a small stateless helper widget at the bottom of `settings_screen.dart`:

```dart
/// Memory section: shows the stored-memory count and offers a destructive
/// "clear" with confirmation. Reads the shared memory instance from the brain
/// provider; degrades to a disabled row if memory failed to open.
class _MemorySection extends ConsumerWidget {
  const _MemorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoryAsync = ref.watch(memoryProvider);
    return SettingsSection(
      title: 'Memoria',
      children: [
        memoryAsync.when(
          loading: () => const ListTile(
            title: Text('Memoria', style: TextStyle(color: DesignTokens.ink)),
            trailing: SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => const ListTile(
            title: Text('Memoria no disponible',
                style: TextStyle(color: DesignTokens.dim)),
          ),
          data: (memory) {
            if (memory == null) {
              return const ListTile(
                title: Text('Memoria no disponible',
                    style: TextStyle(color: DesignTokens.dim)),
              );
            }
            return FutureBuilder<int>(
              future: memory.count(),
              builder: (context, snap) {
                final n = snap.data ?? 0;
                return ListTile(
                  title: const Text('Recuerdos guardados',
                      style: TextStyle(color: DesignTokens.ink)),
                  subtitle: Text('$n',
                      style: const TextStyle(color: DesignTokens.dim)),
                  trailing: TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('¿Borrar la memoria?'),
                          content: const Text(
                              'Astro olvidará todo lo que recuerda de ti.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Borrar'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await memory.clearAll();
                        // Rebuild the FutureBuilder by nudging the provider.
                        ref.invalidate(memoryProvider);
                      }
                    },
                    child: const Text('Borrar'),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
```

Add `const _MemorySection(),` to the `ListView` children (after the wake/sensors
section).

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test && flutter analyze`
Expected: All pass; no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/memory/long_term_memory.dart lib/ui/settings/settings_screen.dart test/memory/long_term_memory_clear_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(settings): memory section with count + clear-all"
```

---

### Task 11: Permissions + About sections

**Files:**
- Create: `lib/platform/permissions.dart`
- Modify: `lib/ui/settings/settings_screen.dart`
- Test: `test/platform/permissions_test.dart`

**Interfaces:**
- Produces:
  - `class Permissions` with `Future<bool> requestMicrophone()`, `Future<bool> requestNotifications()`, `Future<bool> requestLocation()` — thin wrappers over the platform permission plugin already used by the app, returning grant status. If no permission plugin exists yet, use `permission_handler` (`flutter pub add permission_handler`).
  - An "Acerca de" section showing app name/version and a diagnostics line.

- [ ] **Step 1: Confirm the permission mechanism**

Run: `grep -rn "permission" pubspec.yaml lib/ | head`
- If `permission_handler` is present, use it.
- Otherwise add it: `flutter pub add permission_handler && flutter pub get`, and
  ensure the Android manifest already declares `RECORD_AUDIO`,
  `POST_NOTIFICATIONS`, and location permissions (per CLAUDE.md they are
  required; add any missing).

- [ ] **Step 2: Write the failing test (pure surface test)**

```dart
// test/platform/permissions_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:astro/platform/permissions.dart';

void main() {
  test('Permissions exposes the three request methods', () {
    const p = Permissions();
    expect(p.requestMicrophone, isA<Function>());
    expect(p.requestNotifications, isA<Function>());
    expect(p.requestLocation, isA<Function>());
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/platform/permissions_test.dart`
Expected: FAIL — `permissions.dart` not found.

- [ ] **Step 4: Implement `Permissions`**

```dart
// lib/platform/permissions.dart
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper over permission_handler for the three permissions the settings
/// screen can (re)request. Each returns whether the permission ended up granted.
class Permissions {
  const Permissions();

  Future<bool> requestMicrophone() async =>
      (await Permission.microphone.request()).isGranted;

  Future<bool> requestNotifications() async =>
      (await Permission.notification.request()).isGranted;

  Future<bool> requestLocation() async =>
      (await Permission.locationWhenInUse.request()).isGranted;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/platform/permissions_test.dart`
Expected: PASS.

- [ ] **Step 6: Add Permissions + About sections to the screen**

Add imports to `settings_screen.dart`:

```dart
import '../../platform/permissions.dart';
```

Add before the closing `SizedBox`:

```dart
          SettingsSection(
            title: 'Permisos',
            children: [
              ListTile(
                title: const Text('Micrófono',
                    style: TextStyle(color: DesignTokens.ink)),
                trailing: const Icon(Icons.mic, color: DesignTokens.dim),
                onTap: () => const Permissions().requestMicrophone(),
              ),
              ListTile(
                title: const Text('Notificaciones',
                    style: TextStyle(color: DesignTokens.ink)),
                trailing:
                    const Icon(Icons.notifications, color: DesignTokens.dim),
                onTap: () => const Permissions().requestNotifications(),
              ),
              ListTile(
                title: const Text('Ubicación',
                    style: TextStyle(color: DesignTokens.ink)),
                trailing:
                    const Icon(Icons.location_on, color: DesignTokens.dim),
                onTap: () => const Permissions().requestLocation(),
              ),
            ],
          ),
          SettingsSection(
            title: 'Acerca de',
            children: [
              ListTile(
                title: const Text('Astro',
                    style: TextStyle(color: DesignTokens.ink)),
                subtitle: Text(
                  'Voz neuronal: '
                  '${settings.neuralVoiceInstalled ? "instalada" : "no instalada"}'
                  ' · Modelo: ${settings.llmModel}',
                  style: const TextStyle(color: DesignTokens.dim),
                ),
              ),
            ],
          ),
```

- [ ] **Step 7: Run tests + analyze**

Run: `flutter test && flutter analyze`
Expected: All pass; no issues.

- [ ] **Step 8: Commit**

```bash
git add lib/platform/permissions.dart lib/ui/settings/settings_screen.dart test/platform/permissions_test.dart pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "feat(settings): permissions request buttons + about section"
```

---

## Phase 4 — Neural voice download

### Task 12: Re-enable neural deps + refactor SherpaTts to a pre-installed model path

**Files:**
- Modify: `pubspec.yaml` (uncomment `sherpa_onnx`, `audioplayers`, `archive`, `path_provider`; add `http` is already present)
- Rename: `lib/voice/sherpa_tts.dart.off` → `lib/voice/sherpa_tts.dart`
- Modify: `lib/voice/sherpa_tts.dart` (load from a given model directory instead of extracting a bundled asset)

**Interfaces:**
- Produces: `class SherpaTts implements TextToSpeech` with `SherpaTts({required String modelDir, double speed = 1.0})` and `Future<void> warmUp()`. Loads the `.onnx` + `tokens.txt` + `espeak-ng-data` from `modelDir` (already unzipped by the installer). No `rootBundle`, no asset.

- [ ] **Step 1: Re-enable dependencies**

In `pubspec.yaml`, under `dependencies:`, ensure these are present (uncomment the
parked ones; keep the bundled `assets/tts/*.zip` asset **commented out** — the
model is downloaded, not bundled):

```yaml
  sherpa_onnx: ^1.10.0   # match the version parked in the commented block
  audioplayers: ^6.0.0
  archive: ^3.6.0
  path_provider: ^2.1.4
```

Run: `flutter pub get`

- [ ] **Step 2: Rename and refactor SherpaTts**

Rename the file:

```bash
git mv lib/voice/sherpa_tts.dart.off lib/voice/sherpa_tts.dart
```

Replace its constructor + model-loading so it takes an already-extracted
directory (drop `_ensureModelExtracted`, `rootBundle`, and the `modelName`
asset logic):

```dart
// lib/voice/sherpa_tts.dart — constructor + init changes
  SherpaTts({required this.modelDir, this.speed = 1.0});

  /// Directory holding the unzipped Piper model (.onnx, tokens.txt,
  /// espeak-ng-data). Populated by NeuralVoiceInstaller before this is created.
  final String modelDir;
  final double speed;

  // ...unchanged fields (_tts, _player, _counter, _initFuture)...

  Future<void> warmUp() => _ensureInit();

  Future<void> _ensureInit() => _initFuture ??= _init();

  Future<void> _init() async {
    sherpa.initBindings();
    final dir = Directory(modelDir);
    final onnx = dir
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.onnx'),
            orElse: () => throw StateError('no .onnx in $modelDir'));
    final config = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: onnx.path,
          tokens: '$modelDir/tokens.txt',
          dataDir: '$modelDir/espeak-ng-data',
        ),
        numThreads: 4,
        debug: false,
      ),
    );
    _tts = sherpa.OfflineTts(config);
  }
```

Remove the now-unused imports (`rootBundle`, `Isolate` if unused, the
`_ensureModelExtracted`/`_extractZip` methods). Keep `speak`, `stop`, `dispose`,
`_encodeWav` unchanged.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/voice/sherpa_tts.dart`
Expected: No issues (unresolved sherpa imports now resolve since deps are on).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/voice/sherpa_tts.dart
git commit -m "feat(voice): unpark SherpaTts, load from a downloaded model dir"
```

---

### Task 13: NeuralVoiceInstaller (download + unzip + state)

**Files:**
- Create: `lib/voice/neural_voice_installer.dart`
- Modify: `lib/core/config/thresholds.dart` (add default model URL + name)
- Test: `test/voice/neural_voice_installer_test.dart`

**Interfaces:**
- Consumes: `http` (already a dependency), `archive`, `path_provider`, `SettingsNotifier` (Task 2), `SettingKey`.
- Produces:
  - `sealed class VoiceInstallState` with `NotInstalled`, `Installing(double progress)`, `Installed(String path)`, `InstallError(String message)`.
  - `class NeuralVoiceInstaller` with `Stream<VoiceInstallState> get state`, `Future<void> install()`, and a static `Future<Directory> targetDir()` helper. Constructor: `NeuralVoiceInstaller({required http.Client client, required String modelUrl, required String modelName, required Future<Directory> Function() supportDir, required Future<void> Function(String path) onInstalled})`. `install()` downloads the zip with progress, unzips into `supportDir()/tts/<modelName>/`, writes a `.ready` marker, calls `onInstalled(dir)`, and emits `Installed(dir)`.

- [ ] **Step 1: Add config constants**

In `lib/core/config/thresholds.dart`, add near the top of the file (outside the
`Thresholds` class, as top-level consts):

```dart
/// Default download source for the neural Piper voice model zip. Overridable via
/// `.env` (TTS_MODEL_URL). The zip must contain the .onnx, tokens.txt, and
/// espeak-ng-data at its root.
const String kDefaultNeuralVoiceUrl =
    'https://github.com/lordmacu/aipet/releases/download/tts-v1/vits-piper-es_ES-davefx-medium.zip';

/// Folder name the model unzips into under app support dir.
const String kNeuralVoiceModelName = 'vits-piper-es_ES-davefx-medium';
```

- [ ] **Step 2: Write the failing test**

```dart
// test/voice/neural_voice_installer_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:astro/voice/neural_voice_installer.dart';

Uint8List _tinyZip() {
  final archive = Archive()
    ..addFile(ArchiveFile('model.onnx', 3, [1, 2, 3]))
    ..addFile(ArchiveFile('tokens.txt', 2, [97, 98]));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('install downloads, unzips, and emits Installed', () async {
    final tmp = await Directory.systemTemp.createTemp('nvi_test');
    final zip = _tinyZip();
    final client = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        Stream.value(zip),
        200,
        contentLength: zip.length,
      );
    });

    String? installedPath;
    final installer = NeuralVoiceInstaller(
      client: client,
      modelUrl: 'https://example.test/model.zip',
      modelName: 'testmodel',
      supportDir: () async => tmp,
      onInstalled: (p) async => installedPath = p,
    );

    final states = <VoiceInstallState>[];
    final sub = installer.state.listen(states.add);
    await installer.install();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();

    expect(states.last, isA<Installed>());
    expect(installedPath, isNotNull);
    expect(File('${tmp.path}/tts/testmodel/model.onnx').existsSync(), true);
    expect(File('${tmp.path}/tts/testmodel/.ready').existsSync(), true);
    await tmp.delete(recursive: true);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/voice/neural_voice_installer_test.dart`
Expected: FAIL — `neural_voice_installer.dart` not found.

- [ ] **Step 4: Implement the installer**

```dart
// lib/voice/neural_voice_installer.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

/// Where a neural-voice install currently stands.
sealed class VoiceInstallState {
  const VoiceInstallState();
}

class NotInstalled extends VoiceInstallState {
  const NotInstalled();
}

class Installing extends VoiceInstallState {
  const Installing(this.progress);
  /// 0.0–1.0, or -1 when the total size is unknown.
  final double progress;
}

class Installed extends VoiceInstallState {
  const Installed(this.path);
  final String path;
}

class InstallError extends VoiceInstallState {
  const InstallError(this.message);
  final String message;
}

/// Downloads the neural voice model zip on demand and unzips it into app
/// storage, reporting progress. The model is never bundled in the APK.
class NeuralVoiceInstaller {
  NeuralVoiceInstaller({
    required http.Client client,
    required String modelUrl,
    required String modelName,
    required Future<Directory> Function() supportDir,
    required Future<void> Function(String path) onInstalled,
  })  : _client = client,
        _modelUrl = modelUrl,
        _modelName = modelName,
        _supportDir = supportDir,
        _onInstalled = onInstalled;

  final http.Client _client;
  final String _modelUrl;
  final String _modelName;
  final Future<Directory> Function() _supportDir;
  final Future<void> Function(String path) _onInstalled;

  final _controller = StreamController<VoiceInstallState>.broadcast();
  Stream<VoiceInstallState> get state => _controller.stream;

  Future<void> install() async {
    try {
      _controller.add(const Installing(0));
      final support = await _supportDir();
      final modelDir = Directory('${support.path}/tts/$_modelName');
      final marker = File('${modelDir.path}/.ready');
      if (marker.existsSync()) {
        _controller.add(Installed(modelDir.path));
        await _onInstalled(modelDir.path);
        return;
      }

      // Clean any partial previous attempt.
      if (modelDir.existsSync()) modelDir.deleteSync(recursive: true);
      modelDir.createSync(recursive: true);

      final bytes = await _download();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        final outPath = '${modelDir.path}/${entry.name}';
        if (entry.isFile) {
          File(outPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(entry.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
      marker.writeAsStringSync('ok');
      _controller.add(Installed(modelDir.path));
      await _onInstalled(modelDir.path);
    } catch (e) {
      _controller.add(InstallError('$e'));
    }
  }

  Future<Uint8List> _download() async {
    final request = http.Request('GET', Uri.parse(_modelUrl));
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException('download failed: ${response.statusCode}');
    }
    final total = response.contentLength ?? -1;
    final chunks = <int>[];
    var received = 0;
    await for (final chunk in response.stream) {
      chunks.addAll(chunk);
      received += chunk.length;
      _controller.add(Installing(total > 0 ? received / total : -1));
    }
    return Uint8List.fromList(chunks);
  }

  Future<void> dispose() => _controller.close();
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/voice/neural_voice_installer_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/voice/neural_voice_installer.dart lib/core/config/thresholds.dart test/voice/neural_voice_installer_test.dart
git commit -m "feat(voice): NeuralVoiceInstaller downloads + unzips model on demand"
```

---

### Task 14: Engine selection + Voice section download UI

**Files:**
- Modify: `lib/voice/tts_provider.dart` (select neural when installed+enabled)
- Create: `lib/voice/neural_voice_provider.dart` (installer provider + state)
- Modify: `lib/ui/settings/settings_screen.dart` (download/enable UI in Voz section)
- Test: `test/voice/tts_provider_selection_test.dart`

**Interfaces:**
- Consumes: `settingsProvider`, `NeuralVoiceInstaller`, `SherpaTts`, `SystemTts`, `kDefaultNeuralVoiceUrl`, `kNeuralVoiceModelName`.
- Produces:
  - `final neuralVoiceInstallerProvider = Provider<NeuralVoiceInstaller>(...)`.
  - `final voiceInstallStateProvider = StreamProvider<VoiceInstallState>(...)`.
  - `ttsProvider` returns `SherpaTts(modelDir: path)` when `neuralVoiceInstalled && neuralVoiceEnabled && neuralVoicePath` is non-empty; else `SystemTts(rate: ...)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/voice/tts_provider_selection_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/voice/system_tts.dart';
import 'package:astro/voice/tts_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses SystemTts when neural is not installed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    expect(c.read(ttsProvider), isA<SystemTts>());
  });

  test('uses SystemTts when installed but disabled', () async {
    SharedPreferences.setMockInitialValues({
      'neuralVoiceInstalled': true,
      'neuralVoiceEnabled': false,
      'neuralVoicePath': '/tmp/model',
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    expect(c.read(ttsProvider), isA<SystemTts>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/voice/tts_provider_selection_test.dart`
Expected: PASS for test 1 (already SystemTts) but the file may not compile if
`neural_voice_provider` referenced. Since this test only touches `ttsProvider`,
it should FAIL only once we change selection logic incorrectly — run to confirm
current behavior first, then proceed to Step 3. (If both already pass, that's
fine; Step 3 keeps them green while adding neural selection.)

- [ ] **Step 3: Implement the installer provider**

```dart
// lib/voice/neural_voice_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/config/settings_providers.dart';
import '../core/config/thresholds.dart';
import 'neural_voice_installer.dart';

/// Model download URL: `.env` (TTS_MODEL_URL) overrides the built-in default.
String _modelUrl() {
  try {
    final v = dotenv.env['TTS_MODEL_URL'];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  } catch (_) {}
  return kDefaultNeuralVoiceUrl;
}

/// The installer, wired to app storage and to the settings that record a
/// finished install (installed flag + model path).
final neuralVoiceInstallerProvider = Provider<NeuralVoiceInstaller>((ref) {
  final settings = ref.read(settingsProvider.notifier);
  final installer = NeuralVoiceInstaller(
    client: http.Client(),
    modelUrl: _modelUrl(),
    modelName: kNeuralVoiceModelName,
    supportDir: getApplicationSupportDirectory,
    onInstalled: (path) async {
      await settings.setNeuralVoicePath(path);
      await settings.setNeuralVoiceInstalled(true);
    },
  );
  ref.onDispose(installer.dispose);
  return installer;
});

/// Live install progress for the Voz section to render.
final voiceInstallStateProvider = StreamProvider<VoiceInstallState>((ref) {
  return ref.watch(neuralVoiceInstallerProvider).state;
});
```

- [ ] **Step 4: Update `ttsProvider` to select the engine**

```dart
// lib/voice/tts_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/settings_providers.dart';
import 'sherpa_tts.dart';
import 'system_tts.dart';
import 'voice_interfaces.dart';

/// The active text-to-speech engine. Neural (SherpaTts, offline Piper) when the
/// model is downloaded AND enabled; otherwise the lightweight system TTS. Any
/// missing piece falls back to system so voice never breaks.
final ttsProvider = Provider<TextToSpeech>((ref) {
  final s = ref.watch(settingsProvider);
  if (s.neuralVoiceInstalled &&
      s.neuralVoiceEnabled &&
      s.neuralVoicePath.isNotEmpty) {
    return SherpaTts(modelDir: s.neuralVoicePath, speed: s.voicePitch);
  }
  return SystemTts(rate: s.voiceRate);
});
```

- [ ] **Step 5: Run the selection test**

Run: `flutter test test/voice/tts_provider_selection_test.dart`
Expected: PASS (both tests: not installed → System; installed+disabled → System).

- [ ] **Step 6: Add the download UI to the Voz section**

In `settings_screen.dart`, add imports:

```dart
import '../../voice/neural_voice_installer.dart';
import '../../voice/neural_voice_provider.dart';
```

Add these children to the existing "Voz" `SettingsSection`, after the rate
slider:

```dart
              // Neural voice: download on demand, then enable.
              Consumer(
                builder: (context, ref, _) {
                  final installState = ref.watch(voiceInstallStateProvider);
                  final installed = settings.neuralVoiceInstalled;
                  final subtitle = installState.maybeWhen(
                    data: (s) => switch (s) {
                      Installing(:final progress) => progress < 0
                          ? 'Descargando…'
                          : 'Descargando ${(progress * 100).round()}%',
                      InstallError(:final message) => 'Error: $message',
                      Installed() => 'Lista',
                      NotInstalled() =>
                        installed ? 'Instalada' : 'No descargada',
                    },
                    orElse: () => installed ? 'Instalada' : 'No descargada',
                  );
                  return ListTile(
                    title: const Text('Voz neuronal (offline)',
                        style: TextStyle(color: DesignTokens.ink)),
                    subtitle: Text(subtitle,
                        style: const TextStyle(color: DesignTokens.dim)),
                    trailing: installed
                        ? null
                        : TextButton(
                            onPressed: () =>
                                ref.read(neuralVoiceInstallerProvider).install(),
                            child: const Text('Descargar'),
                          ),
                  );
                },
              ),
              SettingsSwitchTile(
                label: 'Usar voz neuronal',
                subtitle: 'Requiere descargarla primero',
                value: settings.neuralVoiceEnabled,
                onChanged: settings.neuralVoiceInstalled
                    ? notifier.setNeuralVoiceEnabled
                    : (_) {},
              ),
```

- [ ] **Step 7: Run full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: All pass; no issues.

- [ ] **Step 8: Commit**

```bash
git add lib/voice/tts_provider.dart lib/voice/neural_voice_provider.dart lib/ui/settings/settings_screen.dart test/voice/tts_provider_selection_test.dart
git commit -m "feat(voice): neural voice download UI + engine selection"
```

---

### Task 15: Warm up neural voice on PetScreen when active

**Files:**
- Modify: `lib/ui/pet_screen.dart`

**Interfaces:**
- Consumes: `ttsProvider`, `SherpaTts.warmUp()`.

- [ ] **Step 1: Warm up in initState when the active engine is neural**

In `_PetScreenState.initState`, after the existing recognizer warm-up, add:

```dart
    final tts = ref.read(ttsProvider);
    if (tts is SherpaTts) {
      unawaited(tts.warmUp());
    }
```

Add the import to `pet_screen.dart`:

```dart
import '../voice/sherpa_tts.dart';
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/ui/pet_screen.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/pet_screen.dart
git commit -m "feat(voice): warm up neural TTS on screen open when active"
```

---

## Final verification

- [ ] Run the full suite: `flutter test` — all green.
- [ ] `flutter analyze` — no warnings.
- [ ] `dart format .` — no diffs (or commit formatting).
- [ ] Manual smoke on device (see `run-chispa` skill / `flutter run -d <device>`):
  gear opens settings; change voice rate and hear the difference; paste an LLM
  key and confirm Astro answers; download neural voice, enable it, confirm the
  voice changes; toggle wake word off and confirm Astro stops listening.

## Notes / deferred (documented, not silently dropped)

- `wakeWordSensitivity`, `navListenerEnabled`, and `autoBrightnessEnabled` are
  persisted and shown, but wiring each into its owning service (Porcupine
  sensitivity, nav listener lifecycle, brightness controller) is follow-up work
  beyond this plan. The wake-word on/off gate IS wired (Task 9).
- API keys are stored in plaintext SharedPreferences (matches current `.env`
  posture). A `flutter_secure_storage` migration is out of scope.
- The neural model URL points at a GitHub Release of this repo
  (`kDefaultNeuralVoiceUrl`); the release asset must be published for downloads
  to work. Override with `TTS_MODEL_URL` in `.env` for testing.
