# EN/ES Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app's UI, confirmations, mood voice, and Astro's spoken answers follow the device language (English or Spanish), with a manual Auto/ES/EN override.

**Architecture:** One context-independent language source (`AppLang`, resolved from a persisted preference then the device locale) exposed via a Riverpod `langProvider`. A bilingual `Strings` catalog (same pattern as the existing `voice/speech_catalog.dart`) serves text everywhere — widgets read it through `ref`, non-widget code (prompt, tools) gets `AppLang` passed in. `flutter_localizations` handles native widgets.

**Tech Stack:** Flutter (stable), Riverpod 2, `shared_preferences`, `flutter_localizations`.

## Global Constraints

- Code (identifiers, comments, file names) in **English only**; user-facing copy is EN + ES.
- Supported languages: **English and Spanish only**. `AppLang { en, es }`.
- Default preference is **Auto** → device locale: `languageCode == 'es'` → `es`, everything else → `en` (English is the fallback).
- Persistence uses `shared_preferences` (same as `AppModeStore`/`CalendarPrefs`). A read/write failure degrades to `auto` (never throws).
- Missing catalog entry falls back to English (like `SpeechCatalog.text`).
- Commit identity: `user.name = lordmacu`, `user.email = 10134930+lordmacu@users.noreply.github.com`. No co-author footer.
- Before "done": `dart format .` and `flutter analyze` with no new warnings.

---

### Task 1: `AppLang`, `LangPref`, and `LangStore`

**Files:**
- Create: `lib/core/l10n/app_lang.dart`
- Test: `test/l10n/app_lang_test.dart`

**Interfaces:**
- Produces: `enum AppLang { en, es }`; `enum LangPref { auto, es, en }`;
  `AppLang appLangFromLocale(String languageCode)`;
  `class LangStore { Future<LangPref> load(); Future<void> save(LangPref pref); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/l10n/app_lang_test.dart
import 'package:astro/core/l10n/app_lang.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('appLangFromLocale maps es to es, everything else to en', () {
    expect(appLangFromLocale('es'), AppLang.es);
    expect(appLangFromLocale('en'), AppLang.en);
    expect(appLangFromLocale('fr'), AppLang.en); // fallback
    expect(appLangFromLocale(''), AppLang.en);
  });

  group('LangStore', () {
    test('defaults to auto when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await const LangStore().load(), LangPref.auto);
    });

    test('save then load round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      const store = LangStore();
      await store.save(LangPref.en);
      expect(await store.load(), LangPref.en);
    });

    test('an unrecognised stored value loads as auto', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lang_pref', 'bogus');
      expect(await const LangStore().load(), LangPref.auto);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/l10n/app_lang_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:astro/core/l10n/app_lang.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/l10n/app_lang.dart
import 'package:shared_preferences/shared_preferences.dart';

/// The languages the app supports. Add one by adding a value here and a column
/// in `Strings` / `SpeechCatalog`.
enum AppLang { en, es }

/// The persisted user choice. `auto` follows the device locale.
enum LangPref { auto, es, en }

/// Map a locale language code to an [AppLang]; English is the fallback.
AppLang appLangFromLocale(String languageCode) =>
    languageCode.toLowerCase() == 'es' ? AppLang.es : AppLang.en;

/// Persists [LangPref] in SharedPreferences. Missing/corrupt → auto.
class LangStore {
  const LangStore();

  static const _key = 'lang_pref';

  Future<LangPref> load() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'es' => LangPref.es,
      'en' => LangPref.en,
      _ => LangPref.auto,
    };
  }

  Future<void> save(LangPref pref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pref.name);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/l10n/app_lang_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n/app_lang.dart test/l10n/app_lang_test.dart
git commit -m "feat(l10n): AppLang + LangPref + persisted LangStore"
```

---

### Task 2: `langProvider` (preference + device locale, reactive)

**Files:**
- Create: `lib/core/l10n/lang_provider.dart`
- Test: `test/l10n/lang_provider_test.dart`

**Interfaces:**
- Consumes: `AppLang`, `LangPref`, `appLangFromLocale`, `LangStore` (Task 1).
- Produces:
  - `class LangController extends Notifier<AppLang>` with `void setPref(LangPref)` and `void deviceLocaleChanged(String languageCode)`.
  - `final langPrefProvider = NotifierProvider<...>` — no; expose `langProvider` (the resolved `AppLang`) and `langPrefProvider` (the current `LangPref` for the settings UI).
  - `final deviceLangProvider = Provider<AppLang>` — the raw device language (overridable in tests).

**Design note:** The resolved language is `pref == auto ? deviceLang : pref`. `deviceLangProvider` reads `PlatformDispatcher.instance.locale.languageCode` by default and is overridden in tests. The app installs a locale-change listener (Task 3) that calls `ref.read(deviceLangProvider.notifier)`-equivalent; here `deviceLangProvider` is a plain `Provider` recomputed by invalidation.

- [ ] **Step 1: Write the failing test**

```dart
// test/l10n/lang_provider_test.dart
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer make(AppLang device) => ProviderContainer(
    overrides: [deviceLangProvider.overrideWithValue(device)],
  );

  test('auto follows the device language', () {
    final c = make(AppLang.es);
    addTearDown(c.dispose);
    expect(c.read(langProvider), AppLang.es);
  });

  test('an explicit preference overrides the device', () {
    final c = make(AppLang.es);
    addTearDown(c.dispose);
    c.read(langPrefProvider.notifier).set(LangPref.en);
    expect(c.read(langProvider), AppLang.en);
  });

  test('switching back to auto restores the device language', () {
    final c = make(AppLang.en);
    addTearDown(c.dispose);
    c.read(langPrefProvider.notifier).set(LangPref.es);
    expect(c.read(langProvider), AppLang.es);
    c.read(langPrefProvider.notifier).set(LangPref.auto);
    expect(c.read(langProvider), AppLang.en);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/l10n/lang_provider_test.dart`
Expected: FAIL — `lang_provider.dart` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/l10n/lang_provider.dart
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lang.dart';

/// The device's language, from the platform locale. Overridable in tests.
/// Recompute on a live locale change by `ref.invalidate(deviceLangProvider)`.
final deviceLangProvider = Provider<AppLang>(
  (_) => appLangFromLocale(PlatformDispatcher.instance.locale.languageCode),
);

/// The user's language preference (Auto/ES/EN), restored from disk, saved on
/// change. Starts at [LangPref.auto].
class LangPrefController extends Notifier<LangPref> {
  @override
  LangPref build() {
    const LangStore().load().then((p) {
      if (p != LangPref.auto) state = p;
    }).catchError((_) {});
    return LangPref.auto;
  }

  void set(LangPref pref) {
    state = pref;
    const LangStore().save(pref).catchError((_) {});
  }
}

final langPrefProvider = NotifierProvider<LangPrefController, LangPref>(
  LangPrefController.new,
);

/// The resolved app language: the preference, or the device language when Auto.
final langProvider = Provider<AppLang>((ref) {
  final pref = ref.watch(langPrefProvider);
  return switch (pref) {
    LangPref.es => AppLang.es,
    LangPref.en => AppLang.en,
    LangPref.auto => ref.watch(deviceLangProvider),
  };
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/l10n/lang_provider_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n/lang_provider.dart test/l10n/lang_provider_test.dart
git commit -m "feat(l10n): langProvider resolves pref over device locale"
```

---

### Task 3: `flutter_localizations` + reactive `MaterialApp.locale`

**Files:**
- Modify: `pubspec.yaml` (add `flutter_localizations` sdk dep)
- Modify: `lib/app.dart` (whole file)
- Test: manual (widget-level; covered indirectly by later widget tests)

**Interfaces:**
- Consumes: `langProvider`, `deviceLangProvider`, `AppLang` (Tasks 1-2).

- [ ] **Step 1: Add the SDK dependency**

In `pubspec.yaml`, under `dependencies:`, add:

```yaml
  flutter_localizations:
    sdk: flutter
```

Run: `flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: Make `AstroApp` a ConsumerWidget driving locale**

Replace `lib/app.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/design_tokens.dart';
import 'core/l10n/app_lang.dart';
import 'core/l10n/lang_provider.dart';
import 'ui/pet_screen.dart';

/// Root widget. Single screen: Astro on the dashboard. Its locale follows
/// [langProvider]; a `WidgetsBindingObserver` refreshes the device language when
/// the system locale changes so `Auto` stays live.
class AstroApp extends ConsumerStatefulWidget {
  const AstroApp({super.key});

  @override
  ConsumerState<AstroApp> createState() => _AstroAppState();
}

class _AstroAppState extends ConsumerState<AstroApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // System language changed → re-resolve the device language.
    ref.invalidate(deviceLangProvider);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    return MaterialApp(
      title: 'Astro',
      debugShowCheckedModeBanner: false,
      locale: Locale(lang == AppLang.es ? 'es' : 'en'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: DesignTokens.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: DesignTokens.bgBottomFallback,
      ),
      home: const PetScreen(),
    );
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/app.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/app.dart
git commit -m "feat(l10n): flutter_localizations + locale from langProvider"
```

---

### Task 4: `Strings` catalog scaffold

**Files:**
- Create: `lib/core/l10n/strings.dart`
- Test: `test/l10n/strings_test.dart`

**Interfaces:**
- Consumes: `AppLang` (Task 1).
- Produces: `abstract final class Strings` with static methods, e.g.
  `static String settingsTitle(AppLang l)`, `static String save(AppLang l)`,
  `static String cancel(AppLang l)`, `static String listening(AppLang l)`,
  `static String wakeHint(String word, AppLang l)`,
  `static String confirmCall(String name, AppLang l)`,
  `static String brightnessSet(int level, AppLang l)`. Add methods as later
  tasks need them.

- [ ] **Step 1: Write the failing test**

```dart
// test/l10n/strings_test.dart
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns the right language and interpolates', () {
    expect(Strings.save(AppLang.es), 'Guardar');
    expect(Strings.save(AppLang.en), 'Save');
    expect(Strings.confirmCall('Ana', AppLang.es), '¿Llamo a Ana?');
    expect(Strings.confirmCall('Ana', AppLang.en), 'Call Ana?');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/l10n/strings_test.dart`
Expected: FAIL — `strings.dart` doesn't exist.

- [ ] **Step 3: Write the scaffold**

```dart
// lib/core/l10n/strings.dart
import 'app_lang.dart';

/// Bilingual UI copy. One method per string; interpolated ones take params.
/// Mirrors `voice/speech_catalog.dart`: this is the single place UI Spanish
/// lives. Grow it as tasks migrate hardcoded strings.
abstract final class Strings {
  static String _pick(AppLang l, {required String en, required String es}) =>
      l == AppLang.es ? es : en;

  static String settingsTitle(AppLang l) =>
      _pick(l, en: 'Settings', es: 'Configuración');
  static String save(AppLang l) => _pick(l, en: 'Save', es: 'Guardar');
  static String cancel(AppLang l) => _pick(l, en: 'Cancel', es: 'Cancelar');
  static String listening(AppLang l) =>
      _pick(l, en: 'Listening…', es: 'Escuchando…');
  static String thinking(AppLang l) =>
      _pick(l, en: 'Thinking…', es: 'Pensando…');
  static String wakeHint(String word, AppLang l) =>
      _pick(l, en: 'Say «$word» or tap 🎙️', es: 'Di «$word» o tócala 🎙️');
  static String confirmCall(String name, AppLang l) =>
      _pick(l, en: 'Call $name?', es: '¿Llamo a $name?');
  static String brightnessSet(int level, AppLang l) =>
      _pick(l, en: 'Brightness at $level%.', es: 'Brillo en $level%.');
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/l10n/strings_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n/strings.dart test/l10n/strings_test.dart
git commit -m "feat(l10n): Strings catalog scaffold"
```

---

### Task 5: Wire mood voice to `langProvider`

**Files:**
- Modify: `lib/core/state/app_state_provider.dart:229` (the `speechLangProvider` line and its consumer at `:235`)
- Test: `test/l10n/speech_lang_wiring_test.dart`

**Interfaces:**
- Consumes: `langProvider`, `AppLang` (Task 2). `SpeechLang { en, es }` already exists in `voice/speech_catalog.dart`.

- [ ] **Step 1: Write the failing test**

```dart
// test/l10n/speech_lang_wiring_test.dart
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:astro/core/state/app_state_provider.dart';
import 'package:astro/voice/speech_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('speechLangProvider follows the app language', () {
    final c = ProviderContainer(
      overrides: [deviceLangProvider.overrideWithValue(AppLang.en)],
    );
    addTearDown(c.dispose);
    expect(c.read(speechLangProvider), SpeechLang.en);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/l10n/speech_lang_wiring_test.dart`
Expected: FAIL — `speechLangProvider` is a `StateProvider<SpeechLang>` fixed to `es`, so it returns `SpeechLang.es`.

- [ ] **Step 3: Derive speechLangProvider from langProvider**

In `lib/core/state/app_state_provider.dart`, replace line 229:

```dart
// before:
final speechLangProvider = StateProvider<SpeechLang>((_) => SpeechLang.es);
// after:
final speechLangProvider = Provider<SpeechLang>(
  (ref) => ref.watch(langProvider) == AppLang.es ? SpeechLang.es : SpeechLang.en,
);
```

Add imports at the top of the file:

```dart
import '../l10n/app_lang.dart';
import '../l10n/lang_provider.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/l10n/speech_lang_wiring_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/state/app_state_provider.dart test/l10n/speech_lang_wiring_test.dart
git commit -m "feat(l10n): mood voice follows the app language"
```

---

### Task 6: Language row in Settings (Auto/ES/EN)

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart` (add a section/row; make it a `Consumer` reading `langProvider`/`langPrefProvider`)
- Test: `test/ui/settings_language_test.dart` (widget test)

**Interfaces:**
- Consumes: `langProvider`, `langPrefProvider`, `LangPref`, `AppLang`, `Strings`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/ui/settings_language_test.dart
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setting the language pref to en resolves to en', () {
    final c = ProviderContainer(
      overrides: [deviceLangProvider.overrideWithValue(AppLang.es)],
    );
    addTearDown(c.dispose);
    c.read(langPrefProvider.notifier).set(LangPref.en);
    expect(c.read(langProvider), AppLang.en);
  });
}
```

(The provider logic is the testable core; the row itself is verified on device.)

- [ ] **Step 2: Run test to verify it passes**

Run: `flutter test test/ui/settings_language_test.dart`
Expected: PASS (reuses Task 2 logic).

- [ ] **Step 3: Add the Language section to settings_screen**

In `lib/ui/settings/settings_screen.dart`, add a section near the top of the
`ListView` (after the app-bar `Scaffold` body opens). Use the existing
`SettingsSection` widget. Read the pref with a `Consumer`:

```dart
Consumer(
  builder: (context, ref, _) {
    final pref = ref.watch(langPrefProvider);
    final lang = ref.watch(langProvider);
    String label(LangPref p) => switch (p) {
      LangPref.auto => lang == AppLang.es ? 'Automático' : 'Automatic',
      LangPref.es => 'Español',
      LangPref.en => 'English',
    };
    return SettingsSection(
      title: lang == AppLang.es ? 'Idioma' : 'Language',
      children: [
        for (final p in LangPref.values)
          RadioListTile<LangPref>(
            title: Text(
              label(p),
              style: const TextStyle(color: DesignTokens.ink),
            ),
            value: p,
            groupValue: pref,
            activeColor: DesignTokens.accent,
            onChanged: (v) {
              if (v != null) ref.read(langPrefProvider.notifier).set(v);
            },
          ),
      ],
    );
  },
),
const SizedBox(height: 24),
```

Add imports to `settings_screen.dart`:

```dart
import '../../core/l10n/app_lang.dart';
import '../../core/l10n/lang_provider.dart';
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/ui/settings/settings_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/ui/settings/settings_screen.dart test/ui/settings_language_test.dart
git commit -m "feat(l10n): language selector (Auto/ES/EN) in settings"
```

---

### Task 7: Migrate UI strings to `Strings`

**Files (migrate every hardcoded Spanish string to a `Strings.xxx(lang)` call, adding the method to `lib/core/l10n/strings.dart` as you go):**
- Modify: `lib/ui/settings/settings_screen.dart` — section titles, tile labels, buttons ("Guardar", "Descargar", "Borrar", "¿Borrar la memoria?", the AI/Voz/Wake word/Email/About section titles, hints).
- Modify: `lib/ui/hud.dart` — `ModeSwitch` labels ("CARRO"/"NORMAL"), any remaining labels.
- Modify: `lib/ui/pet_screen.dart` — status text (`Escuchando…`/`Pensando…`/`…`/`Di «Astro»…`), the `ModeSwitch`/mode strings, overlay titles (`Revisa el correo`, `¿A cuál?`, `¿En qué calendario?`, `Enviar`/`Cancelar`), the `Correo guardado` SnackBar.

**Pattern (apply per string):**

1. Read the widget's `AppLang`: in a `ConsumerWidget`/`ConsumerState` add
   `final lang = ref.watch(langProvider);` in `build`. In a plain
   `StatelessWidget` that already receives data, pass `AppLang lang` into its
   constructor from the parent that has `ref`.
2. Replace `'Guardar'` with `Strings.save(lang)`. If the method doesn't exist,
   add it to `Strings` with both `en`/`es` values, following Task 4's style.
3. For each new `Strings` method add a one-line assertion to
   `test/l10n/strings_test.dart` (both languages).

**Interfaces:**
- Consumes: `langProvider`, `Strings`, `AppLang`.

- [ ] **Step 1: Add all needed `Strings` methods + tests**

For each Spanish string in the three files, add a `Strings` method (EN/ES) and a
line in `test/l10n/strings_test.dart`. Example additions:

```dart
// in Strings
static String modeCar(AppLang l) => _pick(l, en: 'CAR', es: 'CARRO');
static String modeNormal(AppLang l) => _pick(l, en: 'NORMAL', es: 'NORMAL');
static String reviewEmail(AppLang l) =>
    _pick(l, en: 'Review the email', es: 'Revisa el correo');
static String send(AppLang l) => _pick(l, en: 'Send', es: 'Enviar');
static String whichCalendar(AppLang l) =>
    _pick(l, en: 'Which calendar?', es: '¿En qué calendario?');
static String emailSaved(AppLang l) =>
    _pick(l, en: 'Email saved', es: 'Correo guardado');
static String download(AppLang l) => _pick(l, en: 'Download', es: 'Descargar');
static String delete(AppLang l) => _pick(l, en: 'Delete', es: 'Borrar');
// … one per remaining string.
```

- [ ] **Step 2: Run the strings test**

Run: `flutter test test/l10n/strings_test.dart`
Expected: PASS.

- [ ] **Step 3: Replace the strings in the 3 UI files**

Apply the pattern above to `settings_screen.dart`, `hud.dart`, `pet_screen.dart`.
`ModeSwitch` (a `StatelessWidget`) gets an `AppLang lang` field passed from
`pet_screen` (which has `ref`).

- [ ] **Step 4: Verify + widget smoke test**

Run: `flutter analyze lib/ui` — Expected: `No issues found!`
Run: `flutter test test/astro_character_test.dart test/pet_screen_wake_test.dart` — Expected: PASS (no regressions).

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n/strings.dart test/l10n/strings_test.dart lib/ui/
git commit -m "feat(l10n): localize UI strings (settings, hud, pet screen)"
```

---

### Task 8: Localize confirmations + canned lines

**Files:**
- Modify: `lib/ui/pet_screen.dart` — the canned constants (`_wakeAck`, `_notHeard`, `_oops`, greeting) become `Strings` calls; `_confirmQuestion`, `_confirmPhone`, the yes/no button text, and `_pickContact`/`_pickCalendar` prompts localize.
- Modify: `lib/core/l10n/strings.dart` — add the methods.
- Test: `test/l10n/strings_test.dart` — assertions for the new methods.

**Interfaces:**
- Consumes: `langProvider`, `Strings`, `AppLang`.

- [ ] **Step 1: Add `Strings` methods + tests**

```dart
// in Strings
static String wakeAck(AppLang l) =>
    _pick(l, en: "I'm here! What do you need?", es: '¡Aquí estoy! ¿Qué necesitas?');
static String notHeard(AppLang l) =>
    _pick(l, en: "Say again? I didn't catch that.", es: '¿Me repites? No te escuché bien.');
static String oops(AppLang l) => _pick(l,
    en: 'Oops, my connection glitched. Try again?',
    es: 'Uy, se me enredó la conexión. ¿Probamos otra vez?');
static String confirmMessage(String name, AppLang l) =>
    _pick(l, en: 'Send the message to $name?', es: '¿Le mando el mensaje a $name?');
static String yes(AppLang l) => _pick(l, en: 'YES', es: 'SÍ');
static String no(AppLang l) => _pick(l, en: 'NO', es: 'NO');
static String whoToCall(AppLang l) =>
    _pick(l, en: 'Who should I call?', es: '¿A quién llamo?');
// … remaining prompts.
```

Add matching assertions to `test/l10n/strings_test.dart`.

- [ ] **Step 2: Run the strings test**

Run: `flutter test test/l10n/strings_test.dart`
Expected: PASS.

- [ ] **Step 3: Replace canned constants + confirmation copy**

In `pet_screen.dart`, remove the `static const _wakeAck`/`_notHeard`/`_oops`/
greeting fields; call `Strings.wakeAck(ref.read(langProvider))` etc. at use
sites. Localize `_confirmQuestion` (uses `lang`), the yes/no button labels, and
the picker prompts spoken via `_say`.

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/ui/pet_screen.dart` — Expected: `No issues found!`
Run: `flutter test test/pet_screen_wake_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n/strings.dart test/l10n/strings_test.dart lib/ui/pet_screen.dart
git commit -m "feat(l10n): localize confirmations and canned lines"
```

---

### Task 9: Dynamic REGLA #0 — `astroSystemPromptFor(mode, lang)`

**Files:**
- Modify: `lib/brain/astro_brain_provider.dart` — `astroSystemPromptFor` gains an `AppLang lang` param and returns an EN or ES prompt.
- Modify: `lib/ui/pet_screen.dart` — pass `ref.read(langProvider)` where `astroSystemPromptFor(mode)` is called.
- Test: `test/l10n/system_prompt_test.dart`

**Interfaces:**
- Consumes: `AppLang`, `AppMode`.
- Produces: `String astroSystemPromptFor(AppMode mode, AppLang lang)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/l10n/system_prompt_test.dart
import 'package:astro/brain/astro_brain_provider.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/state/app_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the prompt forces the active language', () {
    final es = astroSystemPromptFor(AppMode.normal, AppLang.es);
    final en = astroSystemPromptFor(AppMode.normal, AppLang.en);
    expect(es.toLowerCase(), contains('español'));
    expect(en.toLowerCase(), contains('english'));
    // Tools still listed in both.
    expect(es, contains('comunicacion'));
    expect(en, contains('comunicacion'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/l10n/system_prompt_test.dart`
Expected: FAIL — `astroSystemPromptFor` takes one argument.

- [ ] **Step 3: Add the `lang` param and an English prompt**

In `astro_brain_provider.dart`, change the signature to
`String astroSystemPromptFor(AppMode mode, AppLang lang)`. Branch on `lang`:
keep the current Spanish body for `AppLang.es`; add an English translation for
`AppLang.en` whose language rule reads roughly "RULE #0, UNBREAKABLE — LANGUAGE:
ALWAYS answer in English…", with the persona/style/tool list translated. Import
`../core/l10n/app_lang.dart`.

- [ ] **Step 4: Pass the language from the UI**

In `pet_screen.dart`, change `system: astroSystemPromptFor(ref.read(appModeProvider))`
to `system: astroSystemPromptFor(ref.read(appModeProvider), ref.read(langProvider))`.

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/l10n/system_prompt_test.dart` — Expected: PASS.
Run: `flutter analyze lib/brain/astro_brain_provider.dart lib/ui/pet_screen.dart` — Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/brain/astro_brain_provider.dart lib/ui/pet_screen.dart test/l10n/system_prompt_test.dart
git commit -m "feat(l10n): Astro speaks the device language (dynamic prompt)"
```

---

### Task 10: Localize tool result strings

**Files (each tool that returns Spanish prose gains an injected `AppLang Function() lang` and localizes its `ToolResult` text; register the getter in `astro_brain_provider.dart` as `() => ref.read(langProvider)`):**
- Modify: `lib/brain/tools/map_tool.dart`, `device_tool.dart`, `calendar_tool.dart`, `phone_tool.dart`, `communication_tool.dart`, `weather_tool.dart`, `context_tool.dart`
- Modify: `lib/brain/astro_brain_provider.dart` — pass the lang getter into each.
- Modify/extend: `lib/core/l10n/strings.dart` — add tool-result methods.
- Test: extend each tool's existing test with an EN vs ES assertion.

**Interfaces:**
- Consumes: `AppLang`, `Strings`, `langProvider`.

**Pattern (apply per tool):**
1. Add a constructor param `AppLang Function() lang` (default `() => AppLang.es`
   so existing tests that omit it stay green until updated).
2. Replace each Spanish `ToolResult('…')` with `ToolResult(Strings.xxx(lang()))`,
   adding the method to `Strings`.
3. In `astro_brain_provider.dart`, pass `lang: () => ref.read(langProvider)`.
4. Add one EN/ES assertion to the tool's test.

- [ ] **Step 1: Add tool-result methods to `Strings` + tests**

Example for `map_tool`:

```dart
// in Strings
static String navigatingTo(String dest, AppLang l) =>
    _pick(l, en: 'Navigating to $dest.', es: 'Navegando hacia $dest.');
static String showingNearby(String q, AppLang l) =>
    _pick(l, en: 'Showing $q nearby on the map.', es: 'Te muestro $q cerca en el mapa.');
static String cantOpenMap(AppLang l) =>
    _pick(l, en: "I couldn't open the map.", es: 'No pude abrir el mapa.');
// … one per tool result string.
```

- [ ] **Step 2: Migrate one tool (map_tool) as the reference**

Add `AppLang Function() lang` to `MapTool`, localize its results, update
`test/map_tool_test.dart` to pass `lang: () => AppLang.en` in one case and assert
the English text. Run `flutter test test/map_tool_test.dart` — Expected: PASS.

- [ ] **Step 3: Repeat for the remaining tools**

`device_tool`, `calendar_tool`, `phone_tool`, `communication_tool`,
`weather_tool`, `context_tool` — same pattern, each with its test updated.

- [ ] **Step 4: Wire the lang getter in the provider**

In `astro_brain_provider.dart`, add `lang: () => ref.read(langProvider)` to each
tool registration.

- [ ] **Step 5: Full verify**

Run: `flutter analyze lib` — Expected: no new errors/warnings.
Run: `flutter test` — Expected: all pass.
Run: `dart format .`

- [ ] **Step 6: Commit**

```bash
git add lib/ test/
git commit -m "feat(l10n): localize tool result strings"
```

---

## Notes for the executor

- Do the tasks in order; each compiles and is testable on its own.
- The repo has heavy in-flight edits to `astro_brain_provider.dart` and the tools.
  Run this plan on a dedicated branch created from a stable tree, and re-read each
  target file immediately before editing (it may have changed).
- `speechLangProvider` becomes a `Provider` (was `StateProvider`); no code writes
  to it anymore — the language flows from `langPrefProvider`. Grep for
  `speechLangProvider.notifier` and remove any writers.
