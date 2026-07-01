import 'package:flutter/services.dart';

/// Opens an installed app by (fuzzy) name via the native `astro/apps` channel,
/// for the device tool's `open_app` action. Returns false if nothing matched.
class AppLauncher {
  const AppLauncher([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('astro/apps');

  final MethodChannel _channel;

  Future<bool> open(String name) async {
    if (name.trim().isEmpty) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openApp', {'name': name});
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }
}
