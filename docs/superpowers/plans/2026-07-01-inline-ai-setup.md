# Inline AI Setup (API key prompt) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When no LLM key is configured and the driver asks Astro something, Astro says it needs an API key and opens a setup modal (model dropdown + key + provider hint); after saving, it answers the original question.

**Architecture:** Extract the existing Settings model picker into a shared widget, build a bottom-sheet that reuses it plus an API-key field and a localized provider hint, and trigger it from `PetScreen`'s not-configured branch — falling through to the normal brain answer once configured.

**Tech Stack:** Flutter, Riverpod 2, existing `Strings` i18n (`AppLang` + `_pick`), `settingsProvider`.

## Global Constraints

- Code (identifiers, comments, filenames) in **English only**. All user-visible strings go through `Strings` (EN + ES) — never hard-coded literals in widgets.
- Reuse the existing model picker and presets; do not duplicate them.
- Fields in the modal: **model dropdown + LLM API key only** (no web-search key).
- After a successful save: **auto-answer the original command** (the brain provider rebuilds on `llmApiKey` change).
- Cancel/dismiss leaves Astro quiet (current behavior); never crash on a missing key or missing file.
- Git identity: `user.name=lordmacu`, `user.email=10134930+lordmacu@users.noreply.github.com`. **Never** add a `Co-Authored-By` / Claude coauthor line.
- Before a Dart task is done: `dart format .` and `flutter analyze` with no NEW warnings (pre-existing parallel-WIP lints are fine).
- The repo has active parallel WIP; `git add` ONLY the files each task names. Known pre-existing suite failure: `test/widget_test.dart` — ignore only that; add no new failures.

---

## Task 1: Extract the model picker into a shared widget

**Files:**
- Create: `lib/ui/settings/model_picker_tile.dart`
- Modify: `lib/ui/settings/settings_screen.dart`
- Test: `test/ui/settings/settings_screen_test.dart` (must still pass unchanged)

**Interfaces:**
- Produces: `class ModelPickerTile extends StatefulWidget { const ModelPickerTile({required String currentModel, required ValueChanged<String> onChanged, required AppLang lang}); }`, `const List<String> kModelPresets`, `const String kCustomModelSentinel`.

- [ ] **Step 1: Create the shared file (move the code verbatim, renamed public)**

```dart
// lib/ui/settings/model_picker_tile.dart
import 'package:flutter/material.dart';

import '../../core/config/design_tokens.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/l10n/strings.dart';
import 'settings_widgets.dart';

/// OpenAI-compatible model presets offered in the dropdown; the driver can still
/// type any custom model via the "Personalizado…" option.
const List<String> kModelPresets = [
  'MiniMax-M3',
  'gpt-4o',
  'gpt-4o-mini',
  'gpt-4.1',
  'gpt-4.1-mini',
  'o3-mini',
  'deepseek-chat',
  'deepseek-reasoner',
];

/// Dropdown sentinel selected when the stored model is a custom (non-preset)
/// string, or when the user picks "Personalizado…".
const String kCustomModelSentinel = 'custom';

/// A model dropdown (presets + a custom option) that persists the chosen model
/// through [onChanged]. Reused by the settings screen and the inline AI-setup
/// sheet.
class ModelPickerTile extends StatefulWidget {
  const ModelPickerTile({
    super.key,
    required this.currentModel,
    required this.onChanged,
    required this.lang,
  });

  final String currentModel;
  final ValueChanged<String> onChanged;
  final AppLang lang;

  @override
  State<ModelPickerTile> createState() => _ModelPickerTileState();
}

class _ModelPickerTileState extends State<ModelPickerTile> {
  /// True when the user chose "Personalizado…" OR the stored model is non-preset.
  late bool _customMode;

  @override
  void initState() {
    super.initState();
    _customMode = !kModelPresets.contains(widget.currentModel);
  }

  @override
  void didUpdateWidget(ModelPickerTile old) {
    super.didUpdateWidget(old);
    if (kModelPresets.contains(widget.currentModel)) {
      _customMode = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropdownValue = _customMode ? kCustomModelSentinel : widget.currentModel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(
            Strings.modelLabel(widget.lang),
            style: const TextStyle(color: DesignTokens.ink),
          ),
          trailing: DropdownButton<String>(
            value: dropdownValue,
            dropdownColor: const Color(0xFF1a2537),
            style: const TextStyle(color: DesignTokens.ink, fontSize: 14),
            underline: const SizedBox.shrink(),
            items: [
              for (final p in kModelPresets)
                DropdownMenuItem(value: p, child: Text(p)),
              DropdownMenuItem(
                value: kCustomModelSentinel,
                child: Text(Strings.customModel(widget.lang)),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == kCustomModelSentinel) {
                setState(() => _customMode = true);
                return;
              }
              setState(() => _customMode = false);
              widget.onChanged(v);
            },
          ),
        ),
        if (_customMode)
          SettingsTextTile(
            label: Strings.customModelLabel(widget.lang),
            value: widget.currentModel,
            hint: 'MiniMax-M3',
            onSubmitted: widget.onChanged,
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Remove the moved code from settings_screen.dart and import the shared file**

In `lib/ui/settings/settings_screen.dart`:
- Delete the `const _modelPresets = [...]` list and `const _customSentinel = 'custom';` (now in the shared file).
- Delete the entire `class _ModelPickerTile` / `_ModelPickerTileState` (lines defining them).
- Add the import near the other `settings/` imports:
  ```dart
  import 'model_picker_tile.dart';
  ```
- Update the usage site: `_ModelPickerTile(` → `ModelPickerTile(` (keep the same `currentModel:`, `onChanged:`, `lang:` arguments).
- If any remaining references to `_modelPresets` or `_customSentinel` exist in the file, replace them with `kModelPresets` / `kCustomModelSentinel`.

- [ ] **Step 3: Run the settings tests + analyze**

Run: `flutter test test/ui/settings/settings_screen_test.dart`
Expected: PASS (the model dropdown / custom-option tests behave identically).
Run: `flutter analyze lib/ui/settings/settings_screen.dart lib/ui/settings/model_picker_tile.dart`
Expected: no new issues.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/settings/model_picker_tile.dart lib/ui/settings/settings_screen.dart
git commit -m "refactor(settings): extract reusable ModelPickerTile"
```

---

## Task 2: Localized strings for the AI-setup flow

**Files:**
- Modify: `lib/core/l10n/strings.dart`
- Test: `test/core/l10n/ai_setup_strings_test.dart`

**Interfaces:**
- Produces on `Strings`: `aiSetupSpoken(AppLang)`, `aiSetupTitle(AppLang)`, `aiSetupBody(AppLang)`, `aiKeyLabel(AppLang)`, `aiKeyHint(AppLang)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/l10n/ai_setup_strings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/strings.dart';

void main() {
  for (final l in AppLang.values) {
    test('AI-setup strings are non-empty for $l', () {
      expect(Strings.aiSetupSpoken(l), isNotEmpty);
      expect(Strings.aiSetupTitle(l), isNotEmpty);
      expect(Strings.aiSetupBody(l), isNotEmpty);
      expect(Strings.aiKeyLabel(l), isNotEmpty);
      expect(Strings.aiKeyHint(l), isNotEmpty);
    });
  }

  test('the provider hint names MiniMax and OpenAI', () {
    final es = Strings.aiKeyHint(AppLang.es);
    expect(es.toLowerCase(), contains('minimax'));
    expect(es.toLowerCase(), contains('openai'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/l10n/ai_setup_strings_test.dart`
Expected: FAIL — the `aiSetup*` / `aiKey*` methods don't exist yet.

- [ ] **Step 3: Add the strings**

In `lib/core/l10n/strings.dart`, add these methods inside `abstract final class Strings` (next to the other entries, using the existing `_pick` helper):

```dart
  static String aiSetupSpoken(AppLang l) => _pick(
        l,
        en: 'You need to add an API key so I can think. Let me open the setup.',
        es: 'Necesitas agregar una API key para que pueda pensar. Te abro la configuración.',
      );

  static String aiSetupTitle(AppLang l) =>
      _pick(l, en: 'Set up the AI', es: 'Configura la IA');

  static String aiSetupBody(AppLang l) => _pick(
        l,
        en: 'Pick a model and paste an API key to enable Astro\'s brain.',
        es: 'Elige un modelo y pega una API key para activar el cerebro de Astro.',
      );

  static String aiKeyLabel(AppLang l) =>
      _pick(l, en: 'LLM API key', es: 'API key del LLM');

  static String aiKeyHint(AppLang l) => _pick(
        l,
        en: 'You can get a key from MiniMax, OpenAI, or another '
            'OpenAI-compatible provider.',
        es: 'Puedes obtener una key de MiniMax, OpenAI u otro proveedor '
            'compatible con OpenAI.',
      );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/l10n/ai_setup_strings_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n/strings.dart test/core/l10n/ai_setup_strings_test.dart
git commit -m "feat(l10n): strings for the inline AI-setup flow"
```

---

## Task 3: The AI-setup bottom sheet

**Files:**
- Create: `lib/ui/ai_setup_sheet.dart`
- Test: `test/ui/ai_setup_sheet_test.dart`

**Interfaces:**
- Consumes: `ModelPickerTile`, `kModelPresets` (Task 1); `Strings.aiSetup*/aiKey*` (Task 2); `settingsProvider` (`AppSettings.llmModel`, `setLlmModel`, `setLlmApiKey`); `langProvider`.
- Produces: `Future<bool> showAiSetupSheet(BuildContext context)` — resolves `true` once an LLM key has been saved, `false` on cancel/dismiss.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/ai_setup_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/ui/ai_setup_sheet.dart';

void main() {
  testWidgets('saving a key persists it and returns true', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    result = await showAiSetupSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The hint and title render.
    expect(find.textContaining('MiniMax'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'sk-test-123');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(result, true);
    expect(prefs.getString('llmApiKey'), 'sk-test-123');
  });

  testWidgets('dismissing without saving returns false', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    result = await showAiSetupSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Tap the scrim to dismiss.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, false);
    expect(prefs.getString('llmApiKey'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/ai_setup_sheet_test.dart`
Expected: FAIL — `ai_setup_sheet.dart` / `showAiSetupSheet` not found.

- [ ] **Step 3: Implement the sheet**

```dart
// lib/ui/ai_setup_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/design_tokens.dart';
import '../core/config/settings_providers.dart';
import '../core/l10n/lang_provider.dart';
import '../core/l10n/strings.dart';
import 'settings/model_picker_tile.dart';

/// Shows the inline AI-setup modal (model + API key + provider hint). Resolves
/// to true once an LLM key has been saved, false on cancel/dismiss.
Future<bool> showAiSetupSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DesignTokens.bgBottomFallback,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AiSetupSheet(),
  );
  return saved ?? false;
}

class _AiSetupSheet extends ConsumerStatefulWidget {
  const _AiSetupSheet();

  @override
  ConsumerState<_AiSetupSheet> createState() => _AiSetupSheetState();
}

class _AiSetupSheetState extends ConsumerState<_AiSetupSheet> {
  final _keyController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    await ref.read(settingsProvider.notifier).setLlmApiKey(key);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Padding(
      // Lift above the keyboard.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Strings.aiSetupTitle(lang),
            style: const TextStyle(
              color: DesignTokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Strings.aiSetupBody(lang),
            style: const TextStyle(color: DesignTokens.dim),
          ),
          const SizedBox(height: 12),
          ModelPickerTile(
            currentModel: settings.llmModel,
            onChanged: notifier.setLlmModel,
            lang: lang,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _keyController,
            obscureText: _obscure,
            autofocus: true,
            style: const TextStyle(color: DesignTokens.ink),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: Strings.aiKeyLabel(lang),
              labelStyle: const TextStyle(color: DesignTokens.dim),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility : Icons.visibility_off,
                  color: DesignTokens.dim,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Strings.aiKeyHint(lang),
            style: const TextStyle(color: DesignTokens.dim, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _keyController.text.trim().isEmpty ? null : _save,
              child: Text(Strings.save(lang)),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/ai_setup_sheet_test.dart`
Expected: PASS (both tests).

> If `find.widgetWithText(ElevatedButton, 'Guardar')` misses because the device
> language resolves to English in the test, assert on `Strings.save(AppLang.es)`
> is 'Guardar' (it is) — the test's SharedPreferences has no lang set, so
> `langProvider` falls back to the device locale. If the test host is English,
> change the button finder to `find.byType(ElevatedButton).last` and keep the
> persistence assertion. Prefer the language-agnostic finder if unsure.

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze lib/ui/ai_setup_sheet.dart`
Expected: no issues.

```bash
git add lib/ui/ai_setup_sheet.dart test/ui/ai_setup_sheet_test.dart
git commit -m "feat(ai): inline AI-setup bottom sheet (model + key + provider hint)"
```

---

## Task 4: Trigger the sheet from PetScreen and auto-answer

**Files:**
- Modify: `lib/ui/pet_screen.dart`

**Interfaces:**
- Consumes: `showAiSetupSheet` (Task 3); `Strings.aiSetupSpoken` (Task 2); `astroConfiguredProvider`.

- [ ] **Step 1: Add the import**

In `lib/ui/pet_screen.dart`, add near the other `ui` imports:

```dart
import 'ai_setup_sheet.dart';
```

- [ ] **Step 2: Replace the not-configured short-circuit in `_answerStreaming`**

Find (near the top of `_answerStreaming`):

```dart
    if (!ref.read(astroConfiguredProvider)) {
      await _say(_wakeAck, controller);
      return _wakeAck;
    }
```

Replace with:

```dart
    if (!ref.read(astroConfiguredProvider)) {
      // No LLM key yet: tell the driver and open the inline setup. If they
      // configure it, fall through and answer the original command; otherwise
      // stay quiet.
      await _say(Strings.aiSetupSpoken(_lang), controller);
      if (!mounted) return '';
      final configured = await showAiSetupSheet(context);
      if (!configured || !ref.read(astroConfiguredProvider)) return '';
    }
```

(The existing code below this block — `controller.applyPhase(VoicePhase.thinking);`
and the rest of the brain answer path — runs unchanged once configured.)

- [ ] **Step 3: Analyze + full suite**

Run: `flutter analyze lib/ui/pet_screen.dart`
Expected: no new issues.
Run: `flutter test`
Expected: all pass except the known `test/widget_test.dart` failure; no new failures. (The pet_screen voice-loop re-run path is verified on device.)

- [ ] **Step 4: Commit**

```bash
git add lib/ui/pet_screen.dart
git commit -m "feat(ai): prompt inline AI setup when unconfigured, then answer"
```

---

## Final verification

- [ ] `flutter test` — green except the known `widget_test.dart`; no new failures.
- [ ] `flutter analyze` — no new warnings.
- [ ] On-device (fresh state, no key): say "hola Astro" and ask something → Astro says it needs a key and opens the sheet → pick a model, paste a key, Save → Astro answers the original question. Cancel → Astro stays quiet.

## Notes / follow-up
- Reactive only (on first ask); a proactive first-launch nudge is a possible
  follow-up.
- No key validation; an invalid key surfaces via the normal brain-error line on
  the next call.
