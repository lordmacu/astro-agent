import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_providers.dart';

/// Which tools the driver turned OFF, persisted in SharedPreferences. Stored as
/// the DISABLED set (not enabled) so any new or renamed tool defaults to on.
///
/// Reactive: toggling rebuilds both the Settings switches and the brain (which
/// watches this to drop disabled tools from the registry).
class ToolPrefs extends Notifier<Set<String>> {
  static const _key = 'disabled_tools';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getStringList(_key)?.toSet() ?? <String>{};
  }

  /// Whether [name] is currently enabled (i.e. not in the disabled set).
  bool isEnabled(String name) => !state.contains(name);

  /// Turn a tool on/off and persist it.
  Future<void> setEnabled(String name, bool enabled) async {
    final next = {...state};
    if (enabled) {
      next.remove(name);
    } else {
      next.add(name);
    }
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, next.toList());
    state = next;
  }
}

/// The disabled-tool set. Read for the set, `.notifier` to toggle.
final toolPrefsProvider = NotifierProvider<ToolPrefs, Set<String>>(
  ToolPrefs.new,
);
