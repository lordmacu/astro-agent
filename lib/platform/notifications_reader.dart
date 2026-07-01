import 'package:flutter/services.dart';

/// One recent notification, trimmed to what Astro reads aloud.
class NotificationSummary {
  const NotificationSummary({
    required this.app,
    this.title,
    this.text,
    this.time,
  });

  final String app;
  final String? title;
  final String? text;
  final DateTime? time;
}

/// Reads the phone's recent notifications, buffered by the native listener
/// (`astro/notifications`), for the read_notifications tool. Empty when there's
/// no notification access or nothing arrived since the listener connected.
class NotificationsReader {
  const NotificationsReader([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('astro/notifications');

  final MethodChannel _channel;

  Future<List<NotificationSummary>> recent({int count = 5}) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getRecent', {
        'count': count,
      });
      return [
        for (final e in raw ?? const [])
          if (e is Map)
            NotificationSummary(
              app: (e['app'] as String?) ?? '?',
              title: e['title'] as String?,
              text: e['text'] as String?,
              time: e['time'] == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      (e['time'] as num).toInt(),
                    ),
            ),
      ];
    } on PlatformException {
      return const [];
    }
  }
}
