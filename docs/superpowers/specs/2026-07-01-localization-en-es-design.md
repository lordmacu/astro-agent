# App localization (EN/ES) by device language — design

**Date:** 2026-07-01
**Status:** Approved (design)
**Area:** `lib/core/l10n` (new), `lib/ui`, `lib/voice`, `lib/brain`, `lib/main.dart`

## Problem

Every user-facing string is hardcoded Spanish, and the LLM system prompt (REGLA
#0) forces Astro to always answer in Spanish. The app should present — and Astro
should speak — English or Spanish based on the device language, with a manual
override.

Astro's mood voice already is bilingual (`voice/speech_catalog.dart`: each
`SpeechLine` → EN/ES, chosen by `speechLangProvider`). Nothing else is.

## Goals

- UI, on-screen confirmations, canned lines, and mood voice follow the device
  language (Spanish for `es*` locales, English otherwise).
- Astro **speaks** the device language: REGLA #0 becomes dynamic.
- A manual override in Settings: **Auto / Español / English** (default `Auto`).
- Reactive: changing the phone language updates the app without a restart.

## Non-goals

- Languages beyond EN/ES. The design leaves room (add a column) but ships two.
- Per-string translation memory / `.arb` tooling.

## Approach

The blocker: user-facing strings live not only in widgets but in **plain Dart
classes with no `BuildContext`** — tool result strings, the system prompt, the
speech catalog. Flutter's official `AppLocalizations.of(context)` can't reach
those. So the mechanism must be **context-independent**.

Chosen: a lightweight bilingual catalog + a locale provider (extends the existing
`speech_catalog` pattern). One language source drives UI, prompt, tools, and
voice. (Rejected: gen-l10n/ARB — context-bound, would need a second parallel
system; `intl` — heavier codegen, same context problem.)

### 1. Language source + provider

- `enum AppLang { en, es }` in `lib/core/l10n/app_lang.dart`.
- `enum LangPref { auto, es, en }` — the persisted user choice (SharedPreferences,
  same pattern as `AppModeStore`/`CalendarPrefs`). Default `auto`.
- `langProvider` (Riverpod) resolves, in order:
  1. If pref is `es`/`en` → that.
  2. If `auto` → device locale via `PlatformDispatcher.instance.locale`:
     `languageCode == 'es'` → `AppLang.es`, else `AppLang.en` (English fallback).
- **Reactive:** the provider watches the platform locale (a
  `WidgetsBindingObserver` / `PlatformDispatcher.onLocaleChanged` bridged to a
  provider) so a live language change re-resolves.
- `speechLangProvider` becomes derived from `langProvider` (single source). The
  existing `SpeechLang { en, es }` maps 1:1 to `AppLang` (or `AppLang` replaces
  it; a small alias keeps `speech_catalog` untouched).

### 2. Strings catalog

- `lib/core/l10n/strings.dart` — a `Strings` class like `SpeechCatalog`: static
  methods returning EN/ES text for a given `AppLang`, including interpolated ones
  (`Strings.brightnessSet(int level, AppLang lang)`, `Strings.confirmCall(name)`,
  `Strings.listening`, …). Grouped by area with clear names.
- UI reads it via `ref.watch(langProvider)`; non-UI code gets `AppLang` passed in.

### 3. Direct-to-user text (must localize)

Everything shown or spoken **without going through the LLM**:
- UI: `settings_screen`, `hud`, `pet_screen` status/labels/buttons.
- Confirmations (`¿Envío el correo a X?`, SÍ/NO, contact/calendar pickers) and
  canned lines (`_wakeAck`, `_notHeard`, `_oops`, greeting).
- Mood lines: already bilingual — just wire `speechLangProvider` to `langProvider`.

### 4. Prompt / Astro's voice (dynamic REGLA #0)

- `astroSystemPromptFor(AppMode mode, AppLang lang)`: REGLA #0 → "respond ALWAYS
  in {English/Spanish}"; persona, style, and the tool list are translated per
  language. `pet_screen` passes the current lang each turn.

### 5. Tool result strings

Tool results (`Listo, envié el correo a $to`) are fed to the LLM, which
re-phrases the final answer in the active language — so the model already
translates them. For robustness (no mixed-language logs, better model context)
the tools take an injected `AppLang` (or a `Strings`-backed formatter) and return
localized text. This is the largest surface: every tool that returns prose.

### 6. Native widgets

Add `flutter_localizations` and set `MaterialApp.locale` +
`localizationsDelegates` + `supportedLocales` so built-in dialogs / date & time
pickers render in the active language. `locale` is driven by `langProvider`.

## Components and boundaries

- `lib/core/l10n/app_lang.dart` — `AppLang`, `LangPref`, `LangStore` (persist).
- `lib/core/l10n/lang_provider.dart` — `langProvider` (pref + device + reactive).
- `lib/core/l10n/strings.dart` — the bilingual `Strings` catalog.
- `voice/speech_catalog.dart` — `speechLangProvider` derives from `langProvider`.
- `brain/astro_brain_provider.dart` — `astroSystemPromptFor(mode, lang)`.
- `brain/tools/*` — accept `AppLang` (or a formatter) for their result strings.
- `ui/*` — read `langProvider`, use `Strings`.
- `ui/settings/settings_screen.dart` — a Language row (Auto/ES/EN).
- `main.dart` / `app.dart` — `flutter_localizations`, `MaterialApp.locale`.

Data flow:

```
device locale ─┐
LangPref (pref)─┴─▶ langProvider ─┬─▶ Strings (UI, confirmations, canned)
                                  ├─▶ speechLangProvider ─▶ speech_catalog
                                  ├─▶ astroSystemPromptFor(mode, lang)
                                  ├─▶ tools (result strings)
                                  └─▶ MaterialApp.locale (native widgets)
```

## Error handling / degradation

- Unknown/unsupported locale → English fallback.
- Persistence failure → `auto` (device). Matches the app's "one failing piece
  never breaks the rest" rule.
- A missing catalog entry falls back to English (like `SpeechCatalog.text`).

## Testing

- `langProvider`: pref overrides device; `auto` maps `es`→es, others→en;
  persistence round-trip (mocked store).
- `Strings`: a representative sample returns the right EN/ES text; interpolation
  works; missing key → English fallback.
- `astroSystemPromptFor`: the EN variant says "respond in English", the ES
  variant "en español"; tool list present in both.
- Tool result localization: a couple of tools return EN vs ES per injected lang.

## Rollout (execute on a stable tree, in a branch)

This touches nearly every string plus a full prompt translation and per-tool
result localization — large, and it collides with in-flight edits to the brain
provider and tools. Build it **on a branch once those settle**, in this order,
each step compiling and tested:

1. `app_lang` + `LangStore` + `langProvider` (+ tests). Wire `speechLangProvider`.
2. `flutter_localizations` + `MaterialApp.locale` + the Settings Language row.
3. `Strings` catalog; migrate UI (`settings`, `hud`, `pet_screen`) + confirmations
   + canned lines.
4. `astroSystemPromptFor(mode, lang)` — dynamic REGLA #0 + translated prompt.
5. Tool result strings — inject `AppLang`, localize per tool.
```
