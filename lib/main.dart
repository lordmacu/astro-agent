import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'core/config/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use the bundled SQLite (sqlite3_flutter_libs) via ffi, so FTS5 is available
  // for memory even on devices whose system SQLite lacks it.
  sqfliteFfiInit();
  // Best-effort local-dev .env read. `.env` is NOT a bundled asset (that would
  // ship the key inside the APK/AAB), so on-device this finds nothing and we
  // fall back to --dart-define / in-app Settings. Missing or malformed is fine.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  // Resolve the settings store once so every setting reads synchronously.
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AstroApp(),
    ),
  );
}
