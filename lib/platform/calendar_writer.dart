import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// A calendar the user can write events to (shown in the picker).
class CalendarOption {
  const CalendarOption({
    required this.id,
    required this.name,
    required this.account,
  });

  final int id;
  final String name;
  final String account;
}

/// Talks to the native `astro/calendar` channel (Calendar provider): lists the
/// writable calendars and creates events silently. Asks for calendar access
/// first (request-and-continue); returns empty / false on denial or failure.
class CalendarWriter {
  CalendarWriter([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('astro/calendar');

  final MethodChannel _channel;

  /// The writable calendars, or empty on denial/failure.
  Future<List<CalendarOption>> listCalendars() async {
    if (!await Permission.calendarFullAccess.request().isGranted) {
      return const [];
    }
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listCalendars');
      return [
        for (final e in raw ?? const [])
          if (e is Map)
            CalendarOption(
              id: (e['id'] as num).toInt(),
              name: (e['name'] as String?) ?? 'Calendar',
              account: (e['account'] as String?) ?? '',
            ),
      ];
    } on PlatformException {
      return const [];
    }
  }

  Future<bool> createEvent({
    required int calendarId,
    required String title,
    required DateTime start,
    required Duration duration,
    required Duration reminder,
  }) async {
    if (!await Permission.calendarFullAccess.request().isGranted) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('createEvent', {
        'calendarId': calendarId,
        'title': title,
        'startMillis': start.millisecondsSinceEpoch,
        'durationMinutes': duration.inMinutes,
        'reminderMinutes': reminder.inMinutes,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }
}
