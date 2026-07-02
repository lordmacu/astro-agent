import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// The permissions helper, injectable so widget tests can override it with a
/// no-op (the real one calls native plugins that aren't available in tests).
final permissionsProvider = Provider<Permissions>((_) => const Permissions());

/// Thin wrapper over permission_handler for the three permissions the settings
/// screen can (re)request. Each returns whether the permission ended up granted.
class Permissions {
  const Permissions();

  Future<bool> requestMicrophone() async =>
      (await Permission.microphone.request()).isGranted;

  Future<bool> requestNotifications() async =>
      (await Permission.notification.request()).isGranted;

  Future<bool> requestLocation() async =>
      (await Permission.locationWhenInUse.request()).isGranted;

  /// Ask for the core runtime permissions once at app start, in one flow:
  /// microphone (wake word + STT), location (speed, weather, nearby, context),
  /// and notifications. Already-granted or permanently-denied ones show no
  /// dialog, so this is safe to call on every launch.
  Future<void> requestStartup() async {
    try {
      await [
        Permission.microphone,
        Permission.locationWhenInUse,
        Permission.notification,
      ].request();
    } catch (_) {
      // No platform binding (tests) or plugin error — permissions are
      // best-effort; features that need one re-request it on use.
    }
  }
}
