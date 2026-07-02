# Inline AI setup (API key prompt) — design

**Date:** 2026-07-01
**Status:** approved for planning

## Goal

When no LLM is configured and the driver asks Astro something, Astro should not
dead-end. It should say it needs an API key and open a small setup modal — the
same model picker + API key field as Settings — so the user can configure the AI
right there. After saving, Astro answers the original question.

This is the first-run path: on a fresh install the pet, sensors, and voice all
work; only the reasoning brain needs a key, and this is how the user provides it
without hunting through Settings.

## Decisions (from brainstorming)
- **After saving:** auto-answer the original question (re-run the command once
  the brain is configured).
- **Fields:** model dropdown + LLM API key only (minimum to make the agent work).
- **Hint:** the modal shows a localized note that a key can be obtained from
  **MiniMax, OpenAI, or another** OpenAI-compatible provider.
- **All new text is localized** through the existing `Strings` (EN/ES).

## Architecture

Today `PetScreen._answerStreaming` short-circuits when
`!ref.read(astroConfiguredProvider)` and speaks a canned line. That branch
becomes the trigger for the setup flow.

```
user asks (no key)
 → Astro speaks Strings.aiSetupSpoken(lang)  ("necesitas agregar una API key…")
 → showAiSetupSheet(context, ref)  → modal: model dropdown + API key + hint
 → Save: settings.setLlmModel(...) + setLlmApiKey(...)  (brain rebuilds; astroConfigured → true)
 → sheet returns true → _answerStreaming re-runs the same command through the brain
 → (cancel → returns false → Astro stays quiet, unchanged from today)
```

## Components

1. **Extract the model picker (refactor, DRY).** `_ModelPickerTile`,
   `_modelPresets`, and `_customSentinel` currently live privately in
   `lib/ui/settings/settings_screen.dart`. Move them to a shared
   `lib/ui/settings/model_picker_tile.dart` as public `ModelPickerTile` +
   `kModelPresets`. `settings_screen.dart` imports and uses them (behavior
   unchanged). This lets the modal reuse the exact same picker.

2. **`lib/ui/ai_setup_sheet.dart`** — `Future<bool> showAiSetupSheet(BuildContext
   context, WidgetRef ref)` presenting a `showModalBottomSheet` (scroll-safe,
   `isScrollControlled: true`) with, all localized via `Strings`:
   - a title + one-line explanation,
   - the `ModelPickerTile` (bound to `settings.llmModel` / `setLlmModel`),
   - an obscured API-key field (reusing `SettingsTextTile`) bound to
     `setLlmApiKey`,
   - a **hint** line: "You can get a key from MiniMax, OpenAI, or another
     provider." (`Strings.aiKeyHint`),
   - a **Save** button, enabled only when the key field is non-empty; on tap it
     persists the model + key and closes returning `true`.
   Returns `true` iff the LLM key ends up non-empty (configured), else `false`.

3. **`Strings` additions** (`lib/core/l10n/strings.dart`), each with EN + ES:
   - `aiSetupSpoken` — the spoken line ("Necesitas agregar una API key para que
     pueda pensar. Te abro la configuración." / EN equivalent).
   - `aiSetupTitle` — modal title ("Configura la IA").
   - `aiSetupBody` — one-line explanation.
   - `aiKeyLabel` — "API key del LLM" / "LLM API key".
   - `aiKeyHint` — the providers hint.
   (Reuse existing `Strings.save(l)` for the button; `Strings.settingsModel`/
   model label if present, else add `aiModelLabel`.)

4. **`PetScreen._answerStreaming` change.** Replace the current not-configured
   short-circuit:
   - speak `Strings.aiSetupSpoken(_lang)`,
   - `final ok = await showAiSetupSheet(context, ref);`
   - if `!ok` → return (quiet, as today),
   - if `ok` → fall through and answer `command` through the brain normally
     (the brain provider has rebuilt with the new key).
   The wake mic is already paused for the turn, so the sheet does not interfere.

## Error handling & degradation
- Cancel / dismiss → no key saved, Astro stays quiet (current behavior). No
  crash, no partial state.
- Empty key → Save disabled, so the sheet can only return `true` when actually
  configured.
- If the user types an invalid key, the *next* brain call fails and hits the
  normal brain-error canned line — out of scope to validate keys here.
- Everything else (pet, sensors, voice) already works without a key and is
  untouched.

## Testing
- **`showAiSetupSheet`** widget test: pump it with a `sharedPreferencesProvider`
  override; the dropdown + key field + hint render; entering a key and tapping
  Save persists `llmModel` + `llmApiKey` and the sheet returns `true`;
  `astroConfiguredProvider` flips to `true`.
- **Extraction**: existing `settings_screen_test.dart` (model dropdown, custom
  option) still passes against the moved `ModelPickerTile` — no behavior change.
- **`Strings`**: the new keys return non-empty EN and ES (a small table test, or
  covered by the existing "every string localized" style test if present).
- The `_answerStreaming` re-run path is exercised manually on device; a full unit
  test of the voice loop is out of scope.

## Non-goals
- No key validation / test-call before saving.
- No provider-specific base-URL switching in the modal (still the app's default
  MiniMax endpoint unless the model implies otherwise — same as Settings today).
- No first-launch proactive nudge (the flow is reactive, on first ask). Can be a
  follow-up.
- No web-search key in this modal (LLM key only).
