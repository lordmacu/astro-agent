# Command Palette (help "?") Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A "?" button at the top of the pet screen opens a popup of example-command buttons; tapping one sends that command to the AI so Astro answers.

**Architecture:** A pure `astroCommands(lang)` helper builds the localized list from `kToolCatalog`; a `CommandPalette` widget renders it as buttons; `PetScreen` shows it as an in-Stack overlay (like its other overlays) and runs a tapped command through the existing brain path via a new `_runCommand`.

**Tech Stack:** Flutter, Riverpod 2, existing `Strings` i18n (`AppLang` + `_pick`), `kToolCatalog`.

## Global Constraints

- Code (identifiers, comments, filenames) in **English only**. All user-visible strings go through `Strings` (EN + ES) — no hard-coded literals.
- Command list is **data-driven from `kToolCatalog`**; unknown tool names yield an empty example and are skipped (robust to catalog churn).
- Tapping a command runs it through `_answerStreaming` (reusing the AI-setup gate + the per-call voice confirmation for mutating tools).
- Match existing pet_screen overlay style (`_confirmOverlay` / `_pickOverlay`): a `Positioned.fill` dark scrim + centered card.
- Git identity: `user.name=lordmacu`, `user.email=10134930+lordmacu@users.noreply.github.com`. **Never** add a `Co-Authored-By` / Claude coauthor line.
- Before a Dart task is done: `dart format .` and `flutter analyze` with no NEW warnings.
- The repo has active parallel WIP; `git add` ONLY the files each task names.

---

## Task 1: Command strings + `astroCommands` helper + `CommandPalette` widget

**Files:**
- Modify: `lib/core/l10n/strings.dart`
- Create: `lib/ui/command_palette.dart`
- Test: `test/ui/command_palette_test.dart`
- Test: `test/core/l10n/command_strings_test.dart`

**Interfaces:**
- Produces:
  - `Strings.commandsTitle(AppLang)`, `Strings.commandExample(String toolName, AppLang)` (unknown → '').
  - `List<String> astroCommands(AppLang lang)` — ordered localized command strings (get_context first, then each `kToolCatalog` tool), empties skipped.
  - `class CommandPalette extends StatelessWidget { const CommandPalette({required List<String> commands, required void Function(String) onCommand, required VoidCallback onClose, required AppLang lang}); }`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/l10n/command_strings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:astro/core/config/tool_catalog.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/strings.dart';
import 'package:astro/ui/command_palette.dart';

void main() {
  for (final l in AppLang.values) {
    test('commandsTitle non-empty for $l', () {
      expect(Strings.commandsTitle(l), isNotEmpty);
    });

    test('every catalog tool + get_context has a command example for $l', () {
      expect(Strings.commandExample('get_context', l), isNotEmpty);
      for (final info in kToolCatalog) {
        expect(
          Strings.commandExample(info.name, l),
          isNotEmpty,
          reason: 'missing command example for ${info.name} ($l)',
        );
      }
    });

    test('astroCommands is non-empty with no blank entries for $l', () {
      final cmds = astroCommands(l);
      expect(cmds, isNotEmpty);
      expect(cmds.any((c) => c.trim().isEmpty), isFalse);
      // get_context example leads the list.
      expect(cmds.first, Strings.commandExample('get_context', l));
    });
  }

  test('an unknown tool name yields an empty example', () {
    expect(Strings.commandExample('nope_not_a_tool', AppLang.es), isEmpty);
  });
}
```

```dart
// test/ui/command_palette_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/ui/command_palette.dart';

void main() {
  testWidgets('renders a button per command and reports taps', (tester) async {
    final tapped = <String>[];
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPalette(
            commands: const ['¿Qué hora es?', 'Pon música'],
            onCommand: tapped.add,
            onClose: () => closed++,
            lang: AppLang.es,
          ),
        ),
      ),
    );

    expect(find.widgetWithText(ElevatedButton, '¿Qué hora es?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Pon música'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Pon música'));
    await tester.pump();
    expect(tapped, ['Pon música']);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(closed, 1);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/l10n/command_strings_test.dart test/ui/command_palette_test.dart`
Expected: FAIL — `commandsTitle`/`commandExample`/`astroCommands`/`CommandPalette` don't exist.

- [ ] **Step 3: Add the strings**

In `lib/core/l10n/strings.dart`, add inside `abstract final class Strings` (using `_pick`):

```dart
  static String commandsTitle(AppLang l) =>
      _pick(l, en: 'What can I ask?', es: '¿Qué le puedo preguntar?');

  /// A runnable example utterance for a tool (by AstroTool.name), shown as a
  /// tappable command. Returns '' for names without an example.
  static String commandExample(String tool, AppLang l) => switch (tool) {
        'get_context' => _pick(l, en: 'What time is it?', es: '¿Qué hora es?'),
        'music' => _pick(l, en: 'Play some music', es: 'Pon algo de música'),
        'take_photo' => _pick(l, en: 'Take a photo', es: 'Tómame una foto'),
        'calendar' => _pick(
            l,
            en: 'Add a meeting tomorrow at 3',
            es: 'Agenda una reunión mañana a las 3',
          ),
        'comunicacion' =>
          _pick(l, en: 'Do I have new email?', es: '¿Tengo correos nuevos?'),
        'device' => _pick(
            l,
            en: 'Turn up the brightness',
            es: 'Sube el brillo',
          ),
        'mapa' => _pick(l, en: 'Take me home', es: 'Llévame a casa'),
        'clima' =>
          _pick(l, en: "What's the weather like?", es: '¿Cómo está el clima?'),
        'timer' => _pick(
            l,
            en: 'Set a 5-minute timer',
            es: 'Pon un temporizador de 5 minutos',
          ),
        'phone' => _pick(l, en: 'Call mom', es: 'Llama a mamá'),
        'web_search' =>
          _pick(l, en: "Search today's news", es: 'Busca noticias de hoy'),
        'remember_fact' => _pick(
            l,
            en: 'Remember that I like jazz',
            es: 'Recuerda que me gusta el jazz',
          ),
        _ => '',
      };
```

> NOTE: the switch keys MUST match the current `kToolCatalog` names
> (`music, take_photo, calendar, comunicacion, device, mapa, clima, timer,
> phone, web_search, remember_fact`) plus `get_context`. If the catalog has
> been renamed since, add/adjust the matching cases so the strings test passes.

- [ ] **Step 4: Create the helper + widget**

```dart
// lib/ui/command_palette.dart
import 'package:flutter/material.dart';

import '../core/config/design_tokens.dart';
import '../core/config/tool_catalog.dart';
import '../core/l10n/app_lang.dart';
import '../core/l10n/strings.dart';

/// The ordered list of localized example commands shown in the palette:
/// get_context first, then one per toggleable tool in [kToolCatalog]. Tools
/// without a defined example are skipped.
List<String> astroCommands(AppLang lang) {
  final out = <String>[];
  void add(String toolName) {
    final c = Strings.commandExample(toolName, lang);
    if (c.isNotEmpty) out.add(c);
  }

  add('get_context');
  for (final info in kToolCatalog) {
    add(info.name);
  }
  return out;
}

/// A popup card listing [commands] as tappable buttons. [onCommand] fires with
/// the command text; [onClose] dismisses. Presentation only — the caller wires
/// tapping to the brain.
class CommandPalette extends StatelessWidget {
  const CommandPalette({
    super.key,
    required this.commands,
    required this.onCommand,
    required this.onClose,
    required this.lang,
  });

  final List<String> commands;
  final void Function(String command) onCommand;
  final VoidCallback onClose;
  final AppLang lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360, maxHeight: 520),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.bgBottomFallback,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Strings.commandsTitle(lang),
                  style: const TextStyle(
                    color: DesignTokens.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: DesignTokens.dim),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final cmd in commands)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ElevatedButton(
                        onPressed: () => onCommand(cmd),
                        child: Text(cmd),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/l10n/command_strings_test.dart test/ui/command_palette_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze lib/ui/command_palette.dart lib/core/l10n/strings.dart` → no new issues.

```bash
git add lib/core/l10n/strings.dart lib/ui/command_palette.dart test/ui/command_palette_test.dart test/core/l10n/command_strings_test.dart
git commit -m "feat(ui): command palette content + widget (localized example commands)"
```

---

## Task 2: "?" button, overlay, and run-command in PetScreen

**Files:**
- Modify: `lib/ui/pet_screen.dart`

**Interfaces:**
- Consumes: `astroCommands`, `CommandPalette` (Task 1); `_answerStreaming`, `_wake`, `voiceControllerProvider`, `_busy`, `_lang` (existing in pet_screen).

- [ ] **Step 1: Add the import + state flag**

In `lib/ui/pet_screen.dart`:
- Add `import 'command_palette.dart';` near the other `ui` imports.
- Add a state field next to `_busy` / `_confirmPrompt`:
  ```dart
  bool _showCommands = false;
  ```

- [ ] **Step 2: Add `_runCommand`**

Add this method to `_PetScreenState` (mirrors `_converse` for a single fixed
command; reuses `_answerStreaming`, which includes the AI-setup gate):

```dart
  /// Run a fixed text command (from the command palette) through the same brain
  /// path as a spoken one: pause the wake mic, answer + speak, then resume.
  Future<void> _runCommand(String command) async {
    if (_busy) return;
    _busy = true;
    final controller = ref.read(voiceControllerProvider.notifier);
    await _wake.pause();
    try {
      await _answerStreaming(command, controller);
    } finally {
      controller.applyPhase(VoicePhase.idle);
      if (mounted) setState(() => _spokenText = '');
      _busy = false;
      await _wake.resume();
    }
  }
```

(If `_spokenText` isn't a field in the current file, drop that one line — check
the file; `_converse` uses it, so it exists.)

- [ ] **Step 3: Add the "?" button next to the gear**

In the top-right `Positioned` (currently a `SafeArea` > `Padding` > `IconButton`
settings), replace the single `IconButton` with a `Row` of two:

```dart
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      color: accent,
                      onPressed: () => setState(() => _showCommands = true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      color: accent,
                      onPressed: _openSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),
```

- [ ] **Step 4: Add the overlay to the Stack**

Next to the other overlay entries (`if (_confirmPrompt != null) _confirmOverlay(accent),` etc.), add:

```dart
          if (_showCommands) _commandsOverlay(),
```

And add the overlay method to `_PetScreenState`:

```dart
  /// Full-screen scrim with the command palette; tapping a command closes it and
  /// runs the command through the brain.
  Widget _commandsOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: CommandPalette(
            commands: astroCommands(_lang),
            lang: _lang,
            onClose: () => setState(() => _showCommands = false),
            onCommand: (command) {
              setState(() => _showCommands = false);
              _runCommand(command);
            },
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 5: Analyze + full suite**

Run: `flutter analyze lib/ui/pet_screen.dart`
Expected: no new issues.
Run: `flutter test`
Expected: all pass (no new failures; the command-palette unit/widget tests from Task 1 pass). If a pre-existing unrelated failure appears from parallel WIP, note it and proceed.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pet_screen.dart
git commit -m "feat(ui): help '?' opens command palette that runs commands"
```

---

## Final verification

- [ ] `flutter test` — green (no new failures).
- [ ] `flutter analyze` — no new warnings.
- [ ] On-device: tap "?" → the palette lists command buttons → tap one → the
  palette closes and Astro runs that command and answers out loud. With no key +
  a paid model, the AI-setup sheet appears first; with the free model it answers
  directly. A mutating command (call/email) still asks for voice confirmation.

## Notes / follow-up
- Command examples live in `Strings.commandExample`; keep them in sync when tool
  names change in `kToolCatalog`.
