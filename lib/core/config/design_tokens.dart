import 'package:flutter/material.dart';

import '../state/mood.dart';

/// Visual tokens ported from the HTML prototype. The production character is a
/// Rive state machine; these values drive the placeholder UI and theme until
/// then.
abstract final class DesignTokens {
  // Base palette.
  static const Color ink = Color(0xFFE8EDF5);
  static const Color dim = Color(0xFF5F6A7D);
  static const Color accent = Color(0xFF43D6CF);

  /// Scaffold fallback background before the ambient gradient takes over.
  static const Color bgBottomFallback = Color(0xFF101B2C);

  // Typography (add the font assets before relying on these).
  static const String fontDisplay = 'Fredoka';
  static const String fontMono = 'Space Mono';

  /// Body color override per motion mood. Moods absent here use the ambient
  /// light color instead.
  static const Map<Mood, Color> moodColor = {
    Mood.excited: Color(0xFFF2A93B),
    Mood.scared: Color(0xFF7FB6FF),
    Mood.bump: Color(0xFFB48BFF),
    Mood.worried: Color(0xFFF2873B),
    Mood.alarm: Color(0xFFFF4D57),
    Mood.sleep: Color(0xFF9FB0C7),
    Mood.arrival: Color(0xFF5FD97A),
    Mood.surprised: Color(0xFFFFD166),
  };
}

/// An ambient palette: the background gradient and body color shift with the
/// time of day, derived from the clock (not the light sensor — indoors the lux
/// reading rarely matches the real hour).
class AmbientPalette {
  const AmbientPalette({
    required this.body,
    required this.accent,
    required this.bgTop,
    required this.bgBottom,
    required this.eyeOpenness,
    required this.label,
    required this.icon,
  });

  final Color body;
  final Color accent;
  final Color bgTop;
  final Color bgBottom;
  final double eyeOpenness;

  /// Spanish label and emoji shown in the ambient chip.
  final String label;
  final String icon;

  static const day = AmbientPalette(
    body: Color(0xFF43D6CF),
    accent: Color(0xFF43D6CF),
    bgTop: Color(0xFF26384F),
    bgBottom: Color(0xFF101B2C),
    eyeOpenness: 1.0,
    label: 'día',
    icon: '☀️',
  );

  static const dusk = AmbientPalette(
    body: Color(0xFFF2A93B),
    accent: Color(0xFFF2A93B),
    bgTop: Color(0xFF3A2433),
    bgBottom: Color(0xFF160D18),
    eyeOpenness: 0.92,
    label: 'atardecer',
    icon: '🌆',
  );

  static const night = AmbientPalette(
    body: Color(0xFF6F79C4),
    accent: Color(0xFF8B95E6),
    bgTop: Color(0xFF0B0F18),
    bgBottom: Color(0xFF04060A),
    eyeOpenness: 0.5,
    label: 'noche',
    icon: '🌙',
  );

  static const dawn = AmbientPalette(
    body: Color(0xFF9FB0E0),
    accent: Color(0xFFF5A0B5),
    bgTop: Color(0xFF2C2742),
    bgBottom: Color(0xFF16131F),
    eyeOpenness: 0.82,
    label: 'amanecer',
    icon: '🌅',
  );

  /// Pick a palette from the hour of day (0–23):
  ///   night 20:00–04:59 · dawn 05:00–07:59 · day 08:00–17:59 · dusk 18:00–19:59
  static AmbientPalette fromHour(int hour) {
    if (hour < 5 || hour >= 20) return night;
    if (hour < 8) return dawn;
    if (hour < 18) return day;
    return dusk;
  }
}
