import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which calendar the user picked for Astro's events, so the picker
/// only shows once. Stored as a single int id; missing means "not chosen yet".
class CalendarPrefs {
  const CalendarPrefs();

  static const String _key = 'calendar_id';

  Future<int?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key);
  }

  Future<void> save(int calendarId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, calendarId);
  }
}
