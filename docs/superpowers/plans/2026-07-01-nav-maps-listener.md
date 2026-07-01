# Google Maps Navigation Listener Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Feed Google Maps turn-by-turn notifications into `AppState` (arrived / turnDirection / turnDistanceM) so Astro reacts to navigation, gated by the existing `navListenerEnabled` setting.

**Architecture:** A thin Kotlin `NotificationListenerService` forwards raw Maps notification text over an EventChannel; a pure Dart `NavParser` turns it into a `NavReading`; a `NavService` streams readings; the `appStateProvider` combiner merges them into the already-built nav fields. `AppState`/`MoodResolver` are unchanged (already consume `arrived`/`turnDirection`/`turnDistanceM`).

**Tech Stack:** Flutter, Riverpod 2, rxdart (`Rx.combineLatest5`), Flutter platform channels (EventChannel + MethodChannel), Kotlin `NotificationListenerService`.

## Global Constraints

- Code (identifiers, comments, docs, filenames) in **English only**. UI strings shown to the driver are Spanish, matching existing screens.
- State/DI via **Riverpod 2** only; stream combination via **rxdart**. No new state/stream library.
- Reuse the existing `TurnDirection` enum from `lib/core/state/mood.dart` (`none`, `left`, `right`). Do NOT define a new direction enum.
- Do NOT modify `AppState`, `MoodState`, or `MoodResolver` — they already have and consume `arrived` (bool), `turnDirection` (TurnDirection), `turnDistanceM` (double?).
- Basic behavior must keep working with **nav disabled or permission not granted**: nav fields stay at defaults; the app behaves exactly as today.
- Numeric thresholds live in `lib/core/config/thresholds.dart` (nav already uses `turnImminentM = 80.0`). No magic numbers in resolver logic.
- Android package is `com.lordmacu.astro`. Follow the existing channel pattern (`ProximityChannel`/`MediaChannel`/`WakeWordChannel` registered from `MainActivity.configureFlutterEngine`).
- Google Maps package id: `com.google.android.apps.maps`.
- Git identity for every commit: `user.name=lordmacu`, `user.email=10134930+lordmacu@users.noreply.github.com`. **Never** add a `Co-Authored-By` / Claude coauthor line.
- Before declaring a Dart task done: `dart format .` and `flutter analyze` with no NEW warnings (there are ~4 pre-existing info lints in unrelated files — those are fine).
- The repo has heavy uncommitted parallel WIP; `git add` ONLY the files each task names. One known pre-existing suite failure exists (`test/widget_test.dart` 'renders the resting mood on launch') from parallel work — ignore only that one; introduce no others.

---

## Task 1: NavReading + NavParser (pure Dart)

**Files:**
- Create: `lib/sensors/navigation/nav_reading.dart`
- Create: `lib/sensors/navigation/nav_parser.dart`
- Test: `test/sensors/navigation/nav_parser_test.dart`

**Interfaces:**
- Consumes: `TurnDirection` from `lib/core/state/mood.dart`.
- Produces:
  - `class NavReading { const NavReading({TurnDirection turnDirection = TurnDirection.none, double? distanceM, bool arrived = false}); final TurnDirection turnDirection; final double? distanceM; final bool arrived; static const NavReading none; }` with value equality + hashCode.
  - `abstract final class NavParser { static NavReading parse({String? title, String? text, bool removed = false}); }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/sensors/navigation/nav_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:astro/core/state/mood.dart';
import 'package:astro/sensors/navigation/nav_reading.dart';
import 'package:astro/sensors/navigation/nav_parser.dart';

void main() {
  group('NavParser', () {
    test('Spanish: distance + right turn', () {
      final r = NavParser.parse(title: '200 m', text: 'Gira a la derecha hacia Cra 7');
      expect(r.turnDirection, TurnDirection.right);
      expect(r.distanceM, 200);
      expect(r.arrived, false);
    });

    test('Spanish: km with comma decimal + left', () {
      final r = NavParser.parse(title: '1,2 km', text: 'Gira a la izquierda');
      expect(r.turnDirection, TurnDirection.left);
      expect(r.distanceM, 1200);
    });

    test('English: distance + left turn', () {
      final r = NavParser.parse(title: '150 m', text: 'Turn left onto Main St');
      expect(r.turnDirection, TurnDirection.left);
      expect(r.distanceM, 150);
    });

    test('Spanish arrival', () {
      final r = NavParser.parse(title: 'Astro', text: 'Has llegado a tu destino');
      expect(r.arrived, true);
      expect(r.turnDirection, TurnDirection.none);
    });

    test('English arrival', () {
      final r = NavParser.parse(text: 'You have arrived');
      expect(r.arrived, true);
    });

    test('"derecho" (straight, es) is NOT a right turn', () {
      final r = NavParser.parse(title: '300 m', text: 'Sigue derecho');
      expect(r.turnDirection, TurnDirection.none);
      expect(r.distanceM, 300);
    });

    test('removed notification → neutral', () {
      final r = NavParser.parse(title: '200 m', text: 'Gira a la derecha', removed: true);
      expect(r, NavReading.none);
    });

    test('unrecognized → neutral', () {
      final r = NavParser.parse(title: 'Spotify', text: 'Now playing');
      expect(r, NavReading.none);
    });

    test('imperial distance is ignored (direction still parsed)', () {
      final r = NavParser.parse(title: '0.5 mi', text: 'Turn right');
      expect(r.turnDirection, TurnDirection.right);
      expect(r.distanceM, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sensors/navigation/nav_parser_test.dart`
Expected: FAIL — `nav_reading.dart` / `nav_parser.dart` not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/sensors/navigation/nav_reading.dart
import '../../core/state/mood.dart' show TurnDirection;

/// One parsed navigation snapshot from the Maps notification. Neutral
/// ([none]) when there is no active guidance.
class NavReading {
  const NavReading({
    this.turnDirection = TurnDirection.none,
    this.distanceM,
    this.arrived = false,
  });

  final TurnDirection turnDirection;

  /// Distance to the next maneuver in metres, or null when unknown/unsupported.
  final double? distanceM;

  final bool arrived;

  static const NavReading none = NavReading();

  @override
  bool operator ==(Object other) =>
      other is NavReading &&
      other.turnDirection == turnDirection &&
      other.distanceM == distanceM &&
      other.arrived == arrived;

  @override
  int get hashCode => Object.hash(turnDirection, distanceM, arrived);

  @override
  String toString() =>
      'NavReading(dir: $turnDirection, distM: $distanceM, arrived: $arrived)';
}
```

```dart
// lib/sensors/navigation/nav_parser.dart
import '../../core/state/mood.dart' show TurnDirection;
import 'nav_reading.dart';

/// Turns a raw Google Maps notification (title + text) into a [NavReading].
/// Pure and bilingual (Spanish + English); best-effort and easy to extend by
/// adding patterns. Anything unrecognized maps to [NavReading.none].
abstract final class NavParser {
  static final _arrival = RegExp(
    r'has llegado|llegaste|you have arrived|you.?ve arrived|arriving now',
    caseSensitive: false,
  );
  // \b around the whole words so Spanish "derecho" (straight) is not a right turn.
  static final _left = RegExp(r'\b(izquierda|left)\b', caseSensitive: false);
  static final _right = RegExp(r'\b(derecha|right)\b', caseSensitive: false);
  // Metric distance only: number (optional decimal, comma or dot) + m/km.
  static final _distance = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(km|m)\b',
    caseSensitive: false,
  );

  static NavReading parse({String? title, String? text, bool removed = false}) {
    if (removed) return NavReading.none;
    final blob = '${title ?? ''} ${text ?? ''}'.trim();
    if (blob.isEmpty) return NavReading.none;

    if (_arrival.hasMatch(blob)) {
      return const NavReading(arrived: true);
    }

    final direction = _right.hasMatch(blob)
        ? TurnDirection.right
        : _left.hasMatch(blob)
            ? TurnDirection.left
            : TurnDirection.none;

    final distance = _parseDistance(blob);

    if (direction == TurnDirection.none && distance == null) {
      return NavReading.none;
    }
    return NavReading(turnDirection: direction, distanceM: distance);
  }

  static double? _parseDistance(String blob) {
    final m = _distance.firstMatch(blob);
    if (m == null) return null;
    final value = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (value == null) return null;
    final unit = m.group(2)!.toLowerCase();
    return unit == 'km' ? value * 1000 : value;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/sensors/navigation/nav_parser_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/sensors/navigation/nav_reading.dart lib/sensors/navigation/nav_parser.dart test/sensors/navigation/nav_parser_test.dart
git commit -m "feat(nav): NavReading + bilingual NavParser for Maps notifications"
```

---

## Task 2: NavService + NavControl (channels) + providers

**Files:**
- Create: `lib/sensors/navigation/nav_service.dart`
- Test: `test/sensors/navigation/nav_service_test.dart`

**Interfaces:**
- Consumes: `NavParser`, `NavReading` (Task 1).
- Produces:
  - `class NavService { NavService({required Stream<dynamic> rawEvents}); factory NavService.fromChannel([EventChannel? channel]); Stream<NavReading> readings(); }` — maps each raw event (a `Map` with keys `title`,`text`,`removed`) through `NavParser`.
  - `class NavControl { const NavControl([MethodChannel? channel]); Future<bool> hasPermission(); Future<void> openSettings(); }` over MethodChannel `astro/nav/control`.
  - `final navServiceProvider = Provider<NavService>((_) => NavService.fromChannel());`
  - `final navControlProvider = Provider<NavControl>((_) => const NavControl());`
- Channels: EventChannel `astro/nav` (raw events), MethodChannel `astro/nav/control` (`hasPermission` → bool, `openSettings` → void).

- [ ] **Step 1: Write the failing test**

```dart
// test/sensors/navigation/nav_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:astro/core/state/mood.dart';
import 'package:astro/sensors/navigation/nav_service.dart';
import 'package:astro/sensors/navigation/nav_reading.dart';

void main() {
  test('maps raw Maps events to NavReadings', () async {
    final raw = Stream<dynamic>.fromIterable([
      {'title': '200 m', 'text': 'Gira a la derecha', 'removed': false},
      {'title': 'Astro', 'text': 'Has llegado', 'removed': false},
      {'title': '200 m', 'text': 'Gira a la derecha', 'removed': true},
    ]);
    final service = NavService(rawEvents: raw);
    final out = await service.readings().toList();

    expect(out[0].turnDirection, TurnDirection.right);
    expect(out[0].distanceM, 200);
    expect(out[1].arrived, true);
    expect(out[2], NavReading.none);
  });

  test('tolerates a non-map event by emitting neutral', () async {
    final service = NavService(rawEvents: Stream<dynamic>.value('garbage'));
    final out = await service.readings().toList();
    expect(out, [NavReading.none]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sensors/navigation/nav_service_test.dart`
Expected: FAIL — `nav_service.dart` not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/sensors/navigation/nav_service.dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nav_parser.dart';
import 'nav_reading.dart';

/// Streams [NavReading]s parsed from the native `astro/nav` EventChannel, which
/// forwards raw Google Maps notification text. Only produces data; the mood
/// decision stays in `MoodResolver`.
class NavService {
  NavService({required Stream<dynamic> rawEvents}) : _raw = rawEvents;

  final Stream<dynamic> _raw;

  factory NavService.fromChannel([EventChannel? channel]) {
    final ch = channel ?? const EventChannel('astro/nav');
    return NavService(rawEvents: ch.receiveBroadcastStream());
  }

  Stream<NavReading> readings() => _raw.map(_toReading);

  static NavReading _toReading(dynamic event) {
    if (event is! Map) return NavReading.none;
    return NavParser.parse(
      title: event['title'] as String?,
      text: event['text'] as String?,
      removed: event['removed'] == true,
    );
  }
}

/// Notification-access permission control over MethodChannel `astro/nav/control`.
/// The access is a special permission granted only in system settings, so
/// [openSettings] deep-links there; [hasPermission] reports the current grant.
class NavControl {
  const NavControl([MethodChannel? channel]) : _channel = channel;

  final MethodChannel? _channel;

  MethodChannel get _ch =>
      _channel ?? const MethodChannel('astro/nav/control');

  Future<bool> hasPermission() async {
    try {
      return await _ch.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await _ch.invokeMethod<void>('openSettings');
    } catch (_) {}
  }
}

/// The nav source (native Maps notification listener).
final navServiceProvider = Provider<NavService>((_) => NavService.fromChannel());

/// Notification-access permission control.
final navControlProvider = Provider<NavControl>((_) => const NavControl());
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/sensors/navigation/nav_service_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/sensors/navigation/nav_service.dart test/sensors/navigation/nav_service_test.dart
git commit -m "feat(nav): NavService + NavControl over astro/nav channels"
```

---

## Task 3: Combiner integration + navListenerEnabled gating

**Files:**
- Modify: `lib/core/state/app_state_provider.dart`
- Test: `test/sensors/navigation/nav_combiner_test.dart`

**Interfaces:**
- Consumes: `navServiceProvider`, `NavReading` (Task 2), `settingsProvider` (`AppSettings.navListenerEnabled`).
- Produces: `buildSensorState` gains `NavReading nav = NavReading.none`; `appStateProvider` becomes `Rx.combineLatest5` with a nav stream that is neutral when `navListenerEnabled` is false.

- [ ] **Step 1: Write the failing test**

```dart
// test/sensors/navigation/nav_combiner_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/state/app_mode.dart';
import 'package:astro/core/state/app_state_provider.dart';
import 'package:astro/core/state/mood.dart';
import 'package:astro/sensors/navigation/nav_reading.dart';
import 'package:astro/sensors/navigation/nav_service.dart';

class _FakeNav extends NavService {
  _FakeNav(this._readings) : super(rawEvents: const Stream.empty());
  final List<NavReading> _readings;
  @override
  Stream<NavReading> readings() => Stream.fromIterable(_readings);
}

class _CarMode extends AppModeNotifier {
  @override
  AppMode build() => AppMode.car;
}

Future<ProviderContainer> _container({
  required bool navEnabled,
  required List<NavReading> nav,
}) async {
  SharedPreferences.setMockInitialValues({'navListenerEnabled': navEnabled});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appModeProvider.overrideWith(_CarMode.new),
    navServiceProvider.overrideWithValue(_FakeNav(nav)),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nav enabled: reading flows into AppState', () async {
    final c = await _container(
      navEnabled: true,
      nav: [const NavReading(turnDirection: TurnDirection.right, distanceM: 50)],
    );
    final sub = c.listen(appStateProvider, (_, __) {}, fireImmediately: true);
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final state = c.read(appStateProvider).requireValue;
    expect(state.turnDirection, TurnDirection.right);
    expect(state.turnDistanceM, 50);
  });

  test('nav disabled: fields stay default even if the service emits', () async {
    final c = await _container(
      navEnabled: false,
      nav: [const NavReading(turnDirection: TurnDirection.left, distanceM: 10)],
    );
    final sub = c.listen(appStateProvider, (_, __) {}, fireImmediately: true);
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final state = c.read(appStateProvider).requireValue;
    expect(state.turnDirection, TurnDirection.none);
    expect(state.turnDistanceM, isNull);
    expect(state.arrived, false);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sensors/navigation/nav_combiner_test.dart`
Expected: FAIL — `buildSensorState` has no `nav` param / nav not wired.

- [ ] **Step 3: Wire nav into the combiner**

In `lib/core/state/app_state_provider.dart`:

Add imports (with the other imports):

```dart
import '../../sensors/navigation/nav_reading.dart';
import '../config/settings_providers.dart';
```

Extend `buildSensorState` to accept and apply a `NavReading` (replace the existing function):

```dart
AppState buildSensorState({
  required MotionReading motion,
  required double lux,
  required bool proximityNear,
  required double speedKmh,
  bool carMode = false,
  NavReading nav = NavReading.none,
}) => AppState(
  carMode: carMode,
  longitudinalG: motion.longitudinalG,
  verticalG: motion.verticalG,
  lateralG: motion.lateralG,
  yawRate: motion.yawRate,
  lux: lux,
  proximityNear: proximityNear,
  speedKmh: speedKmh,
  arrived: nav.arrived,
  turnDirection: nav.turnDirection,
  turnDistanceM: nav.distanceM,
);
```

Inside `appStateProvider`, after the `speed` block and before the `return`, build the nav stream:

```dart
  // Navigation: parsed Google Maps notifications, only when the user enabled it.
  // Disabled (or no notification access) → a constant neutral reading, so the
  // nav fields stay at their defaults and the app behaves exactly as today.
  final navEnabled = ref.watch(
    settingsProvider.select((s) => s.navListenerEnabled),
  );
  final Stream<NavReading> nav = navEnabled
      ? ref
          .watch(navServiceProvider)
          .readings()
          .onErrorReturn(NavReading.none)
          .startWith(NavReading.none)
      : Stream<NavReading>.value(NavReading.none);
```

Replace the `Rx.combineLatest4(...)` return with `Rx.combineLatest5(...)`:

```dart
  return Rx.combineLatest5(
    motion,
    lux,
    near,
    speed,
    nav,
    (MotionReading m, double l, bool n, double s, NavReading nv) =>
        buildSensorState(
      motion: m,
      lux: l,
      proximityNear: n,
      speedKmh: s,
      carMode: carMode,
      nav: nv,
    ),
  );
```

- [ ] **Step 4: Run the nav combiner test AND the existing sensors test**

Run: `flutter test test/sensors/navigation/nav_combiner_test.dart test/sensors_test.dart`
Expected: PASS (both — the existing combiner test still passes because nav defaults to neutral and `buildSensorState`'s nav param is optional).

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze lib/core/state/app_state_provider.dart` → no new issues.

```bash
git add lib/core/state/app_state_provider.dart test/sensors/navigation/nav_combiner_test.dart
git commit -m "feat(nav): merge NavReading into AppState combiner, gated by setting"
```

---

## Task 4: Kotlin NavListenerService + NavChannel + manifest (on-device)

**Files:**
- Create: `android/app/src/main/kotlin/com/lordmacu/astro/nav/NavListenerService.kt`
- Create: `android/app/src/main/kotlin/com/lordmacu/astro/nav/NavChannel.kt`
- Modify: `android/app/src/main/kotlin/com/lordmacu/astro/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: nothing from Dart at compile time; produces the runtime channels `astro/nav` (EventChannel, emits `mapOf("title","text","removed")`) and `astro/nav/control` (MethodChannel: `hasPermission` → Bool, `openSettings` → Unit) that Task 2's `NavService`/`NavControl` consume.

> No JVM unit-test harness exists in this repo; this task is verified by build + on-device. Follow the exact patterns of `ProximityChannel`/`MainActivity`.

- [ ] **Step 1: Create the listener service**

```kotlin
// android/app/src/main/kotlin/com/lordmacu/astro/nav/NavListenerService.kt
package com.lordmacu.astro.nav

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/** Forwards Google Maps turn-by-turn notification text to the app. Parsing lives
 *  in Dart (NavParser); this only extracts title/text and marks removals. A
 *  process-static sink lets [NavChannel] receive events without binding to the
 *  service instance (Android owns its lifecycle). */
class NavListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != MAPS_PKG) return
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        Log.d(TAG, "maps posted: title='$title' text='$text'")
        sink?.invoke(mapOf("title" to title, "text" to text, "removed" to false))
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (sbn.packageName != MAPS_PKG) return
        sink?.invoke(mapOf("title" to null, "text" to null, "removed" to true))
    }

    companion object {
        private const val TAG = "AstroNav"
        private const val MAPS_PKG = "com.google.android.apps.maps"

        /** Set by NavChannel while a Dart listener is active. */
        @Volatile
        var sink: ((Map<String, Any?>) -> Unit)? = null
    }
}
```

- [ ] **Step 2: Create the channel**

```kotlin
// android/app/src/main/kotlin/com/lordmacu/astro/nav/NavChannel.kt
package com.lordmacu.astro.nav

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Bridges [NavListenerService] to Dart: an EventChannel of raw notification
 *  maps and a MethodChannel for the notification-access permission. */
class NavChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val main = Handler(Looper.getMainLooper())

    @Suppress("unused")
    private val events = EventChannel(messenger, EVENTS).also {
        it.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                NavListenerService.sink = { event ->
                    // EventSink must be used on the main thread.
                    main.post { sink?.success(event) }
                }
            }

            override fun onCancel(arguments: Any?) {
                NavListenerService.sink = null
            }
        })
    }

    @Suppress("unused")
    private val control = MethodChannel(messenger, CONTROL).also {
        it.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasAccess())
                "openSettings" -> {
                    context.startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAccess(): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(":").any { it.contains(context.packageName) }
    }

    companion object {
        private const val EVENTS = "astro/nav"
        private const val CONTROL = "astro/nav/control"
    }
}
```

- [ ] **Step 3: Register the channel in MainActivity**

In `android/app/src/main/kotlin/com/lordmacu/astro/MainActivity.kt`:
- Add import: `import com.lordmacu.astro.nav.NavChannel`
- Add field: `private lateinit var navChannel: NavChannel`
- In `configureFlutterEngine`, after the existing channel constructions, add:

```kotlin
        navChannel = NavChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
```

- [ ] **Step 4: Register the service + Maps visibility in the manifest**

In `android/app/src/main/AndroidManifest.xml`, inside the `<application>` element (next to the existing `<service>`), add:

```xml
        <service
            android:name=".nav.NavListenerService"
            android:label="Astro navigation"
            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
            android:exported="false">
            <intent-filter>
                <action android:name="android.service.notification.NotificationListenerService"/>
            </intent-filter>
        </service>
```

Inside the existing `<queries>` element, add Google Maps so the app can see it on Android 11+:

```xml
        <package android:name="com.google.android.apps.maps"/>
```

- [ ] **Step 5: Build to verify it compiles**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL (no Kotlin/manifest errors). (Full nav behavior is verified on-device: grant notification access, start Maps navigation, confirm Astro leans/announces the turn.)

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/lordmacu/astro/nav/NavListenerService.kt android/app/src/main/kotlin/com/lordmacu/astro/nav/NavChannel.kt android/app/src/main/kotlin/com/lordmacu/astro/MainActivity.kt android/app/src/main/AndroidManifest.xml
git commit -m "feat(nav): Kotlin Maps notification listener + astro/nav channels"
```

---

## Task 5: Settings toggle → permission check / open + status

**Files:**
- Modify: `lib/ui/settings/settings_screen.dart`
- Test: `test/ui/settings/nav_permission_test.dart`

**Interfaces:**
- Consumes: `settingsProvider` (`navListenerEnabled` + `setNavListenerEnabled`), `navControlProvider` (`NavControl.hasPermission`/`openSettings`) from Task 2.
- Produces: the existing 'Navegación (Maps)' switch, when turned ON, checks notification access and deep-links to settings when missing.

> The existing wake/sensors section already has a `SettingsSwitchTile` labelled 'Navegación (Maps)' bound to `settings.navListenerEnabled` / `notifier.setNavListenerEnabled`. This task changes its `onChanged` to also drive the permission flow. Read the current section before editing.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/settings/nav_permission_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/sensors/navigation/nav_service.dart';
import 'package:astro/ui/settings/settings_screen.dart';

class _FakeNavControl implements NavControl {
  _FakeNavControl(this._granted);
  final bool _granted;
  int openCalls = 0;
  @override
  Future<bool> hasPermission() async => _granted;
  @override
  Future<void> openSettings() async => openCalls++;
}

void main() {
  testWidgets('enabling nav without access opens settings', (tester) async {
    SharedPreferences.setMockInitialValues({'navListenerEnabled': false});
    final prefs = await SharedPreferences.getInstance();
    final fake = _FakeNavControl(false);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        navControlProvider.overrideWithValue(fake),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    // Scroll the switch into view, then toggle it on.
    final tile = find.widgetWithText(SwitchListTile, 'Navegación (Maps)');
    await tester.scrollUntilVisible(tile, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(prefs.getBool('navListenerEnabled'), true);
    expect(fake.openCalls, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/settings/nav_permission_test.dart`
Expected: FAIL — the switch's `onChanged` doesn't call `navControl` yet (openCalls stays 0).

- [ ] **Step 3: Wire the permission flow into the nav switch**

In `lib/ui/settings/settings_screen.dart`, add the import:

```dart
import '../../sensors/navigation/nav_service.dart';
```

Find the 'Navegación (Maps)' `SettingsSwitchTile` and replace its `onChanged: notifier.setNavListenerEnabled` with a handler that also drives the permission (the screen is a `ConsumerWidget`, so `ref` is in scope):

```dart
              SettingsSwitchTile(
                label: 'Navegación (Maps)',
                subtitle: 'Reaccionar a las indicaciones de Google Maps',
                value: settings.navListenerEnabled,
                onChanged: (on) async {
                  await notifier.setNavListenerEnabled(on);
                  if (!on) return;
                  final control = ref.read(navControlProvider);
                  if (!await control.hasPermission()) {
                    await control.openSettings();
                  }
                },
              ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/settings/nav_permission_test.dart`
Expected: PASS.

- [ ] **Step 5: Full suite + analyze + commit**

Run: `flutter test` → all pass except the known pre-existing `test/widget_test.dart` failure.
Run: `flutter analyze` → no new issues.

```bash
git add lib/ui/settings/settings_screen.dart test/ui/settings/nav_permission_test.dart
git commit -m "feat(nav): nav toggle checks notification access and opens settings"
```

---

## Final verification

- [ ] `flutter test` — green except the known parallel-WIP `widget_test.dart` failure; no new failures.
- [ ] `flutter analyze` — no new warnings.
- [ ] `flutter build apk --debug` — compiles (Kotlin + manifest).
- [ ] On-device: Settings → enable 'Navegación (Maps)' → grant notification access → start Google Maps navigation → Astro leans toward the turn (`gaze`/`tilt`), shows `turnImminent` under ~80 m, and reacts with the `arrival` mood on arrival.

## Notes / follow-up
- The parser is best-effort; expect to add patterns after observing real Maps notification strings on the device (Maps changes wording and localizes). Patterns live in `NavParser` regexes.
- Imperial units (mi/ft) yield a null distance (direction/arrival still parse). Add metric-only note holds until a user needs imperial.
