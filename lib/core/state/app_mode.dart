import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where Astro is running. `car` mounts on a dashboard: the speed ring shows,
/// the GPS speed sensor runs, the driving moods fire, and the brain knows it's
/// in a car. `normal` is a desk / handheld companion: none of that. The basics
/// (voice, caress, ambient, sleep) work the same in both.
enum AppMode { normal, car }

extension AppModeX on AppMode {
  bool get isCar => this == AppMode.car;
}

/// Persists the chosen [AppMode] across restarts. Stored as a single string
/// under one key; a missing or unrecognised value loads as null (fall back to
/// the default).
class AppModeStore {
  const AppModeStore();

  static const String _key = 'app_mode';

  Future<AppMode?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'car' => AppMode.car,
      'normal' => AppMode.normal,
      _ => null,
    };
  }

  Future<void> save(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final appModeStoreProvider = Provider<AppModeStore>(
  (_) => const AppModeStore(),
);

/// The live app mode. Starts at [AppMode.normal] and restores the saved choice
/// asynchronously on launch; every change is persisted. Persistence errors are
/// swallowed (e.g. no platform binding in tests) — the mode still works in
/// memory, matching the app's "one failing piece never breaks the rest" rule.
class AppModeNotifier extends Notifier<AppMode> {
  @override
  AppMode build() {
    final store = ref.watch(appModeStoreProvider);
    store
        .load()
        .then((restored) {
          if (restored != null) state = restored;
        })
        .catchError((_) {});
    return AppMode.normal;
  }

  void set(AppMode mode) {
    state = mode;
    ref.read(appModeStoreProvider).save(mode).catchError((_) {});
  }

  void toggle() => set(state.isCar ? AppMode.normal : AppMode.car);
}

final appModeProvider = NotifierProvider<AppModeNotifier, AppMode>(
  AppModeNotifier.new,
);
