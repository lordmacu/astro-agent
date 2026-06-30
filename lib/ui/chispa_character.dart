import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/state/mood.dart';
import '../voice/viseme.dart';

/// Chispa, drawn and animated in Flutter from the HTML prototype. Driven by the
/// resolved `MoodState` (+ the current viseme while speaking). This is the
/// stand-in until a Rive character with a real state machine replaces it; the
/// shapes, colors, and motions mirror the prototype.
class ChispaCharacter extends StatefulWidget {
  const ChispaCharacter({
    super.key,
    required this.mood,
    required this.color,
    this.viseme,
    this.size = 200,
  });

  final MoodState mood;

  /// Body color (mood override, or ambient color, computed by the caller).
  final Color color;

  /// Active mouth shape while speaking.
  final Viseme? viseme;

  final double size;

  @override
  State<ChispaCharacter> createState() => _ChispaCharacterState();
}

class _ChispaCharacterState extends State<ChispaCharacter>
    with TickerProviderStateMixin {
  late final AnimationController _motion;
  late final AnimationController _blink;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scheduleBlink();
  }

  void _scheduleBlink() {
    final ms = 2600 + math.Random().nextInt(2200);
    _blinkTimer = Timer(Duration(milliseconds: ms), () async {
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _motion.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_motion, _blink]),
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _ChispaPainter(
          mood: widget.mood,
          color: widget.color,
          viseme: widget.viseme,
          t: _motion.value,
          blink: _blink.value,
        ),
      ),
    );
  }
}

class _ChispaPainter extends CustomPainter {
  _ChispaPainter({
    required this.mood,
    required this.color,
    required this.viseme,
    required this.t,
    required this.blink,
  });

  final MoodState mood;
  final Color color;
  final Viseme? viseme;
  final double t; // 0..1 looping
  final double blink; // 0 open .. 1 closed

  static const _ink = Color(0xFF10141D);
  static const _blush = Color(0xFFFF7A9C);
  static const _sweat = Color(0xFF7FD0FF);

  double get _tau => math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    // Work in the prototype's 200x200 space.
    canvas.scale(size.width / 200, size.height / 200);

    final m = mood.mood;

    // --- whole-body motion (translate / scale / rotate around the body) ---
    canvas.save();
    canvas.translate(100, 120);

    // Postural lean (always applied, like the prototype's #tilt layer): Chispa
    // leans into the curve, driven continuously by the gyroscope (mood.tilt).
    var rot = (mood.tilt * 9) * math.pi / 180;
    var sx = 1.0;
    var sy = 1.0;
    var dy = 0.0;
    var dx = 0.0;

    switch (m) {
      case Mood.excited:
        dy = -7 * math.sin(_tau * t * 4).abs();
        sx = 1.03;
        sy = 0.97;
      case Mood.scared:
        dx = 1.6 * math.sin(_tau * t * 16);
        sx = 1.06;
        sy = 0.92;
      case Mood.bump:
        dy = -10 * math.sin(_tau * t * 6).abs();
      case Mood.pet:
        rot += (3 * math.sin(_tau * t)) * math.pi / 180;
      default:
        // rest / thinking / worried / alarm / sleep / arrival / answering / lean
        final b = 0.022 * math.sin(_tau * t);
        sx = 1 + b;
        sy = 1 - b;
    }

    canvas.translate(dx, dy);
    canvas.rotate(rot);
    canvas.scale(sx, sy);
    canvas.translate(-100, -120);

    _drawSpark(canvas, m);
    _drawBody(canvas);
    _drawEyes(canvas, m);
    _drawMouth(canvas, m);
    _drawExtras(canvas, m);

    canvas.restore();
  }

  void _drawBody(Canvas canvas) {
    final body = Path()
      ..moveTo(100, 36)
      ..cubicTo(148, 36, 168, 74, 168, 116)
      ..cubicTo(168, 158, 140, 178, 100, 178)
      ..cubicTo(60, 178, 32, 158, 32, 116)
      ..cubicTo(32, 74, 52, 36, 100, 36)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
  }

  void _drawSpark(Canvas canvas, Mood m) {
    final lit = m == Mood.thinking;
    canvas.drawLine(
      const Offset(100, 36),
      const Offset(100, 16),
      Paint()
        ..color = _ink.withValues(alpha: 0.3)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(100, 13),
      5,
      Paint()..color = const Color(0xFFF2F7C7).withValues(alpha: lit ? 1 : 0.5),
    );
  }

  void _drawEyes(Canvas canvas, Mood m) {
    if (m == Mood.pet) {
      // Happy closed eyes.
      final p = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(66, 106)
          ..quadraticBezierTo(76, 98, 86, 106),
        p,
      );
      canvas.drawPath(
        Path()
          ..moveTo(114, 106)
          ..quadraticBezierTo(124, 98, 134, 106),
        p,
      );
      return;
    }

    final base = switch (m) {
      Mood.excited => 1.2,
      Mood.scared => 1.35,
      Mood.bump => 1.4,
      Mood.lean => 1.15,
      Mood.sleep => 0.5,
      _ => 1.0,
    };
    final openY = base * (1 - 0.92 * blink);

    final gaze = switch (mood.gaze) {
      TurnDirection.left => -4.0,
      TurnDirection.right => 4.0,
      TurnDirection.none => 0.0,
    };
    final pupilUp = m == Mood.thinking ? -3.0 : 0.0;
    final pupilX = m == Mood.thinking ? 2.0 : gaze;

    _eye(canvas, const Offset(76, 104), const Offset(80, 100), openY, pupilX,
        pupilUp);
    _eye(canvas, const Offset(124, 104), const Offset(128, 100), openY, pupilX,
        pupilUp);
  }

  void _eye(Canvas canvas, Offset eye, Offset pupil, double openY, double px,
      double py) {
    canvas.save();
    canvas.translate(eye.dx, eye.dy);
    canvas.scale(1, openY.clamp(0.05, 1.5));
    canvas.translate(-eye.dx, -eye.dy);
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 30, height: 36),
      Paint()..color = _ink,
    );
    canvas.restore();
    if (openY > 0.3) {
      canvas.drawCircle(
        pupil.translate(px, py),
        5,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawMouth(Canvas canvas, Mood m) {
    // Speaking: cycle viseme shapes.
    if (m == Mood.answering && viseme != null) {
      _visemeMouth(canvas, viseme!);
      return;
    }

    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = _ink;

    switch (m) {
      case Mood.scared:
      case Mood.bump:
        canvas.drawCircle(const Offset(100, 154), 10, fill);
      case Mood.excited:
        final p = Path()
          ..moveTo(80, 134)
          ..quadraticBezierTo(100, 168, 120, 134)
          ..close();
        canvas.drawPath(p, fill);
      case Mood.pet:
        canvas.drawPath(
          Path()
            ..moveTo(80, 136)
            ..quadraticBezierTo(100, 158, 120, 136),
          stroke,
        );
      case Mood.worried:
        canvas.drawPath(
          Path()
            ..moveTo(84, 148)
            ..quadraticBezierTo(100, 138, 116, 148),
          stroke,
        );
      case Mood.sleep:
        canvas.drawPath(
          Path()
            ..moveTo(86, 142)
            ..quadraticBezierTo(100, 148, 114, 142),
          stroke,
        );
      default:
        canvas.drawPath(
          Path()
            ..moveTo(82, 138)
            ..quadraticBezierTo(100, 154, 118, 138),
          stroke,
        );
    }
  }

  void _visemeMouth(Canvas canvas, Viseme v) {
    final fill = Paint()..color = _ink;
    switch (v) {
      case Viseme.closed:
        canvas.drawPath(
          Path()
            ..moveTo(88, 142)
            ..quadraticBezierTo(100, 146, 112, 142),
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
      case Viseme.openSmall:
        canvas.drawPath(
          Path()
            ..moveTo(90, 139)
            ..quadraticBezierTo(100, 151, 110, 139)
            ..close(),
          fill,
        );
      case Viseme.openWide:
        canvas.drawPath(
          Path()
            ..moveTo(82, 133)
            ..quadraticBezierTo(100, 168, 118, 133)
            ..close(),
          fill,
        );
      case Viseme.round:
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(100, 148), width: 14, height: 16),
          fill,
        );
      case Viseme.broad:
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(100, 144), width: 34, height: 12),
          fill,
        );
    }
  }

  void _drawExtras(Canvas canvas, Mood m) {
    if (m == Mood.pet) {
      final blush = Paint()..color = _blush.withValues(alpha: 0.55);
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(58, 130), width: 26, height: 16),
          blush);
      canvas.drawOval(
          Rect.fromCenter(
              center: const Offset(142, 130), width: 26, height: 16),
          blush);
      final hy = 80 - 30 * t;
      _glyph(canvas, '♥', Offset(44, hy), 20, _blush.withValues(alpha: 1 - t));
    }

    if (m == Mood.scared) {
      canvas.drawCircle(const Offset(152, 100), 7, Paint()..color = _sweat);
    }
    if (m == Mood.sleep) {
      _glyph(canvas, 'z', const Offset(146, 70), 22, const Color(0xFF9FB0C7));
    }
    if (m == Mood.bump || m == Mood.alarm) {
      _glyph(canvas, '!', const Offset(116, 74), 32, const Color(0xFFB48BFF));
    }
    if (m == Mood.thinking) {
      _drawThinkBubble(canvas);
    }
  }

  void _drawThinkBubble(Canvas canvas) {
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(150, 52), 3.5, white);
    canvas.drawCircle(const Offset(159, 42), 5, white);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(176, 26), width: 46, height: 30),
        white);
    for (var i = 0; i < 3; i++) {
      final pulse = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(_tau * (t - i * 0.12)));
      canvas.drawCircle(
        Offset(166 + i * 10.0, 26),
        3,
        Paint()..color = const Color(0xFF5F6A7D).withValues(alpha: pulse),
      );
    }
  }

  void _glyph(Canvas canvas, String text, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_ChispaPainter old) =>
      old.t != t ||
      old.blink != blink ||
      old.mood.mood != mood.mood ||
      old.color != color ||
      old.viseme != viseme;
}
