import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart side of the native `astro/media` channel. Plays music by search query
/// (MediaStore intent) and controls the active media session with media-button
/// events. Provider-agnostic: works with whatever music app the driver uses.
class MediaController {
  MediaController({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('astro/media');

  final MethodChannel _channel;

  Future<bool> play(String query) => _invoke('play', {'query': query});
  Future<bool> pause() => _invoke('pause');
  Future<bool> resume() => _invoke('resume');
  Future<bool> next() => _invoke('next');
  Future<bool> previous() => _invoke('previous');

  /// Set the media volume, [value01] in 0..1.
  Future<bool> setVolume(double value01) =>
      _invoke('setVolume', {'level': value01});

  /// Nudge the media volume up (+1) or down (-1) by one step.
  Future<bool> nudgeVolume(int direction) =>
      _invoke('nudgeVolume', {'direction': direction});

  /// Play a short "listening" earcon so the driver knows when to speak.
  Future<bool> beep() => _invoke('beep');

  /// Play the system camera shutter sound (matches the stock camera; respects
  /// silent mode). Best-effort.
  Future<bool> shutter() => _invoke('shutter');

  /// Turn the flashlight on/off via CameraManager (reliable off across cameras).
  Future<bool> setTorch(bool on) async {
    final ok = await _invoke('torch', {'on': on});
    debugPrint('[Astro] 🔦 setTorch($on) → $ok');
    return ok;
  }

  Future<bool> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      final ok = await _channel.invokeMethod<bool>(method, args);
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
