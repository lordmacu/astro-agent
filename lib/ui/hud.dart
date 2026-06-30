import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config/design_tokens.dart';
import '../core/state/mood.dart';

/// Spanish status label shown in the event row, derived from the mood.
String eventLabel(Mood mood) => switch (mood) {
      Mood.excited => 'acelerando',
      Mood.scared => 'frenada',
      Mood.bump => 'bache',
      Mood.lean => 'curva',
      Mood.worried => 'motor caliente',
      Mood.alarm => 'alerta',
      Mood.arrival => 'llegamos',
      Mood.pet => 'caricia',
      Mood.thinking => 'pensando',
      Mood.answering => 'hablando',
      Mood.sleep => 'durmiendo',
      Mood.rest => 'en reposo',
    };

/// Top pill: ambient icon, label, and lux value.
class AmbientChip extends StatelessWidget {
  const AmbientChip({super.key, required this.ambient, required this.lux});

  final AmbientPalette ambient;
  final double lux;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10151F).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ambient.icon, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 10),
          Text(
            ambient.label.toUpperCase(),
            style: const TextStyle(
              color: DesignTokens.ink,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_grouped(lux.round())} lux',
            style: const TextStyle(
              color: DesignTokens.dim,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  static String _grouped(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Big speed readout with unit and source.
class Speedometer extends StatelessWidget {
  const Speedometer({super.key, required this.speedKmh, required this.color});

  final int speedKmh;
  final Color color;

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
                color: DesignTokens.dim, fontSize: 13, letterSpacing: 1),
          ),
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            '🛰️ GPS + acelerómetro',
            style: TextStyle(color: Color(0xFF3A4456), fontSize: 10),
          ),
        ),
      ],
    );
  }
}

/// Bottom row: current motion event (with colored dot) and proximity state.
class EventRow extends StatelessWidget {
  const EventRow({
    super.key,
    required this.event,
    required this.eventColor,
    required this.near,
  });

  final String event;
  final Color eventColor;
  final bool near;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _dot(eventColor),
            const SizedBox(width: 8),
            Text(event.toUpperCase(), style: _labelStyle),
          ],
        ),
        Row(
          children: [
            _dot(near ? const Color(0xFF5FD97A) : const Color(0xFF2C3A4F)),
            const SizedBox(width: 9),
            Text(
              (near ? 'cerca' : 'lejos').toUpperCase(),
              style: _labelStyle.copyWith(
                color: DesignTokens.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const _labelStyle = TextStyle(
    color: DesignTokens.dim,
    fontSize: 11,
    letterSpacing: 2,
  );

  Widget _dot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 6)],
        ),
      );
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
