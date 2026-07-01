import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config/design_tokens.dart';
import '../core/l10n/app_lang.dart';
import '../core/l10n/strings.dart';

/// Text-only mode toggle for the top-left corner: CAR / NORMAL, the active
/// label bright and bold, the other dim. Tapping a label selects that mode.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({
    super.key,
    required this.carMode,
    required this.onSelect,
    required this.lang,
  });

  final bool carMode;
  final AppLang lang;

  /// Called with `true` for car mode, `false` for normal.
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _label(Strings.modeCar(lang), carMode, () => onSelect(true)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '·',
            style: TextStyle(color: DesignTokens.dim, fontSize: 12),
          ),
        ),
        _label(Strings.modeNormal(lang), !carMode, () => onSelect(false)),
      ],
    );
  }

  Widget _label(String text, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          text,
          style: TextStyle(
            color: active ? DesignTokens.ink : DesignTokens.dim,
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
}

/// Big speed readout with unit and source.
class Speedometer extends StatelessWidget {
  const Speedometer({
    super.key,
    required this.speedKmh,
    required this.color,
    required this.lang,
  });

  final int speedKmh;
  final Color color;
  final AppLang lang;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$speedKmh',
          style: TextStyle(
            color: color,
            fontSize: 46,
            height: 1,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'km/h',
            style: TextStyle(
              color: DesignTokens.dim,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            Strings.speedSource(lang),
            style: const TextStyle(color: Color(0xFF3A4456), fontSize: 10),
          ),
        ),
      ],
    );
  }
}

/// A ~270° progress ring (gap at the bottom) that fills with speed, wrapped
/// around [child]. Mirrors the prototype's velocity ring.
class VelocityRing extends StatelessWidget {
  const VelocityRing({
    super.key,
    required this.speedKmh,
    required this.color,
    required this.child,
    this.size = 260,
    this.maxKmh = 100,
  });

  final double speedKmh;
  final Color color;
  final Widget child;
  final double size;
  final double maxKmh;

  @override
  Widget build(BuildContext context) {
    final fraction = (speedKmh / maxKmh).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(fraction: fraction, color: color),
          ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  // Start bottom-left, sweep 270° clockwise, leaving the gap at the bottom.
  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 6,
    );

    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    if (fraction > 0) {
      canvas.drawArc(
        rect,
        _start,
        _sweep * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
