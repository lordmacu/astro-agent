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

  MethodChannel get _ch => _channel ?? const MethodChannel('astro/nav/control');

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
final navServiceProvider = Provider<NavService>(
  (_) => NavService.fromChannel(),
);

/// Notification-access permission control.
final navControlProvider = Provider<NavControl>((_) => const NavControl());

/// Whether the notification-listener permission is currently granted.
/// Invalidate this provider after opening settings to re-check the grant.
final navPermissionProvider = FutureProvider<bool>(
  (ref) => ref.read(navControlProvider).hasPermission(),
);
