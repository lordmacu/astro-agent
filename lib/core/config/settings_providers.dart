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
