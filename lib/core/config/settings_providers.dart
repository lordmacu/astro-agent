import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'settings_notifier.dart';
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

/// The reactive settings snapshot. Read for values, `.notifier` for setters.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
