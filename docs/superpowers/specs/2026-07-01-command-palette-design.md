# Command palette (help "?") — design

**Date:** 2026-07-01
**Status:** approved for planning

## Goal

Add a "?" button at the top of the pet screen that opens a popup listing example
commands as tappable buttons. Tapping a button **sends that command to the AI**
(same path as a spoken command) so Astro answers. It shows what the driver can
ask, and doubles as one-tap shortcuts. All text is localized (EN/ES).

## Decisions (from brainstorming)
- The popup is an **in-Stack overlay of buttons**, styled like the existing
  overlays (`_confirmOverlay` / `_pickOverlay`), with a scrollable button list.
- Tapping a command button **runs it through the brain** (reusing
  `_answerStreaming`, including the AI-setup gate when unconfigured).
- Command list is **data-driven from `kToolCatalog`** (auto-updates as tools
  change), each with a localized example utterance.
- Mutating commands (call, email) still hit the existing per-call **voice
  confirmation**, so a demo tap never sends anything without asking.

## Architecture

`PetScreen` already renders a `Stack` with a top-left `ModeSwitch`, a top-right
settings gear, and overlays (`_confirmOverlay`, `_pickOverlay`, `_photoOverlay`)
gated by state flags. This feature adds a "?" button and a commands overlay in
the same pattern, plus a helper to run a text command through the existing brain
path.

```
tap "?"  → setState(_showCommands = true)  → _commandsOverlay renders buttons
tap a command button → setState(_showCommands = false) → _runCommand(text)
   → (same as a spoken turn) pause wake mic → _answerStreaming(text) → Astro speaks
   → (if unconfigured, _answerStreaming already opens the AI-setup sheet)
   → finally: idle phase + resume wake mic
```

## Components

1. **Command source (data-driven, testable).** A pure helper
   `List<AstroCommand> astroCommands(AppLang lang)` (new file
   `lib/ui/command_palette.dart`, or in strings/tool-catalog land) where
   `AstroCommand` is `{String label}` — the localized utterance to show AND send
   (label == command text). It is built from `kToolCatalog`: for each `ToolInfo`
   whose example is defined, include `Strings.commandExample(info.name, lang)`;
   prepend a `get_context` example (time/speed) since that tool is core and not
   in the catalog. `Strings.commandExample` returns an empty string for names it
   doesn't know; empty entries are skipped, so catalog churn never crashes the
   list.

2. **`Strings` additions** (`lib/core/l10n/strings.dart`), EN + ES:
   - `commandsTitle(AppLang)` — the popup title ("¿Qué le puedo preguntar?" /
     "What can I ask?").
   - `commandsClose(AppLang)` — the close button (reuse `Strings.cancel` if it
     reads well, else a dedicated "Cerrar"/"Close"). Prefer reusing an existing
     one; only add if none fits.
   - `commandExample(String toolName, AppLang)` — one runnable example utterance
     per tool name (music, take_photo, calendar, device, mapa, clima, timer,
     phone/comunicacion, web_search, memory, …) plus `get_context`. Unknown name
     → `''`.

3. **`_runCommand(String command)`** in `_PetScreenState` — mirrors `_converse`
   for a single fixed command instead of a listened one:
   ```
   if (_busy) return;
   _busy = true;
   final controller = ref.read(voiceControllerProvider.notifier);
   await _wake.pause();
   try { await _answerStreaming(command, controller); }
   finally { controller.applyPhase(VoicePhase.idle); _busy = false; await _wake.resume(); }
   ```
   Reuses the existing brain+speak path (and the AI-setup gate inside
   `_answerStreaming`).

4. **"?" button + overlay in `PetScreen`.**
   - Add `bool _showCommands = false;` state.
   - In the top-right `Positioned`, wrap the gear in a `Row` with a new
     `IconButton(Icons.help_outline)` (tinted `accent`) that sets
     `_showCommands = true`.
   - Add `if (_showCommands) _commandsOverlay(context)` to the Stack children
     (alongside the other overlays).
   - `_commandsOverlay`: a `Positioned.fill` dark scrim + centered rounded card
     (max width ~360) containing the title and a **scrollable** column of
     `ElevatedButton`s (one per `astroCommands(lang)` entry) plus a Close button.
     Each command button `onPressed`: `setState(() => _showCommands = false);`
     then `_runCommand(cmd.label);`. Close just clears `_showCommands`.

## Error handling & degradation
- Empty/unknown command example → skipped from the list (no crash).
- If busy (`_busy`), `_runCommand` no-ops (won't overlap a live turn).
- Unconfigured AI → `_answerStreaming` opens the AI-setup sheet (existing);
  free model → answers directly.
- Mutating commands are gated by the existing voice confirmation.

## Testing
- **`astroCommands` / `Strings.commandExample`**: unit test — for every
  `kToolCatalog` name (+ `get_context`), `commandExample` is non-empty in EN and
  ES; `astroCommands(lang)` returns a non-empty list with no empty labels.
- **`commandsTitle`**: non-empty EN/ES.
- The overlay rendering + `_runCommand` wiring in `PetScreen` is verified on
  device (the voice-loop turn is not unit-tested), consistent with how the other
  overlays/`_converse` are treated. If the button list is extracted into a small
  widget taking `(commands, onTap)`, a light widget test can assert it renders a
  button per command and calls `onTap` with the command text.

## Non-goals
- No fuzzy search / filtering of commands (it's a short curated list).
- No per-tool deep configuration from this popup (that's Settings).
- Commands are the same in car and normal mode (no mode-specific list).
