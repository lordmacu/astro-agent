import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/settings_providers.dart';

/// The strength/style of a single haptic tick.
enum HapticTone { light, medium, heavy, selection }

/// Thin wrapper over the platform haptic engine. Kept behind a class (instead of
/// calling `HapticFeedback` statically) so it can be gated by a setting and
/// faked in tests. Every method is best-effort: it never throws if the device
/// has no vibrator, and does nothing when haptics are disabled.
class Haptics {
  Haptics({
    required bool Function() enabled,
    Future<void> Function(HapticTone tone)? fire,
  }) : _enabled = enabled,
       _fire = fire ?? _platformFire;

  final bool Function() _enabled;
  final Future<void> Function(HapticTone tone) _fire;

  static Future<void> _platformFire(HapticTone tone) => switch (tone) {
    HapticTone.light => HapticFeedback.lightImpact(),
    HapticTone.medium => HapticFeedback.mediumImpact(),
    HapticTone.heavy => HapticFeedback.heavyImpact(),
    HapticTone.selection => HapticFeedback.selectionClick(),
  };

  Future<void> _tick(HapticTone tone) async {
    if (!_enabled()) return;
    try {
      await _fire(tone);
    } catch (_) {
      // No vibrator / platform rejected it — haptics are always best-effort.
    }
  }

  /// Tap (or wake word) to start talking — a firm, noticeable buzz.
  Future<void> listenStart() => _tick(HapticTone.medium);

  /// Tap again to cancel/stop listening — a light, dismissive tick.
  Future<void> cancel() => _tick(HapticTone.light);

  /// Press-and-hold caress on Astro — a soft selection tick.
  Future<void> pet() => _tick(HapticTone.selection);

  /// Confirm/deny a mutating action (Sí/No, send email) — a firm buzz.
  Future<void> confirm() => _tick(HapticTone.medium);

  /// A discrete choice: picker row, mode switch, toggle — a crisp tick.
  Future<void> select() => _tick(HapticTone.selection);

  /// One beat of the "thinking" pulse, driven by a repeating timer while Astro
  /// is working. Alternates a soft tick and a crisper one by [step] so the loop
  /// feels like a live heartbeat ("da-dum") instead of a monotonous buzz.
  Future<void> thinking(int step) =>
      _tick(step.isEven ? HapticTone.light : HapticTone.selection);
}

/// The shared haptics service, gated by the `hapticsEnabled` setting.
final hapticsProvider = Provider<Haptics>(
  (ref) => Haptics(enabled: () => ref.read(settingsProvider).hapticsEnabled),
);
