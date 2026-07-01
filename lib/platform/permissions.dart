import 'package:permission_handler/permission_handler.dart';

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
}
