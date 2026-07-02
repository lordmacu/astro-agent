import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/state/mood.dart';
import '../voice/viseme.dart';

/// Astro, drawn and animated entirely in Flutter (no external asset). Driven by
/// the resolved `MoodState` (+ the current viseme while speaking). Each mood has
/// its own body motion, brows, eyes, mouth, and extras; mood and ambient color
/// changes glide with a little squash-and-stretch pop so nothing snaps.
class AstroCharacter extends StatefulWidget {
  const AstroCharacter({
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
  State<AstroCharacter> createState() => _AstroCharacterState();
}

class _AstroCharacterState extends State<AstroCharacter>
    with TickerProviderStateMixin {
  late final AnimationController _motion; // idle loop (breathing, bobs)
  late final AnimationController _blink;
  late final AnimationController _change; // mood / color transition pop + glide
  late final AnimationController _mouth; // viseme-to-viseme tween
  Timer? _blinkTimer;

  // The viseme being tweened from / to, so the mouth glides instead of snapping.
  Viseme? _prevViseme;
  Viseme? _curViseme;

  Color _fromColor = const Color(0xFF43D6CF);
  late Color _toColor;

  @override
  void initState() {
    super.initState();
    _toColor = widget.color;
    _fromColor = widget.color;
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _change = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1,
    );
    // Shorter than the ~110 ms between viseme changes, so each shape settles
    // before the next arrives.
    _mouth = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      value: 1,
    );
    _curViseme = widget.viseme;
    _scheduleBlink();
  }

  @override
  void didUpdateWidget(AstroCharacter old) {
    super.didUpdateWidget(old);
    final colorChanged = old.color != widget.color;
    final moodChanged = old.mood.mood != widget.mood.mood;
    if (colorChanged || moodChanged) {
      _fromColor = _currentColor(); // start the glide from what's on screen
      _toColor = widget.color;
      _change.forward(from: 0);
    }
    if (old.viseme != widget.viseme) {
      _prevViseme = _curViseme; // glide from the shape currently on screen
      _curViseme = widget.viseme;
      _mouth.forward(from: 0);
    }
  }

  Color _currentColor() => Color.lerp(
    _fromColor,
    _toColor,
    Curves.easeOut.transform(_change.value),
  )!;

  /// The mouth geometry to paint this frame: the previous viseme lerped toward
  /// the current one. Null when Astro isn't speaking (the painter then draws the
  /// mood-based mouth). A first viseme opens from a resting closed shape.
  VisemeMetrics? _mouthMetrics() {
    final cur = _curViseme;
    if (cur == null) return null;
    final from = (_prevViseme ?? Viseme.closed).metrics;
    final e = Curves.easeOut.transform(_mouth.value);
    return VisemeMetrics.lerp(from, cur.metrics, e);
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
    _change.dispose();
    _mouth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_motion, _blink, _change, _mouth]),
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _AstroPainter(
          mood: widget.mood,
          color: _currentColor(),
          mouth: _mouthMetrics(),
          t: _motion.value,
          blink: _blink.value,
          change: _change.value,
        ),
      ),
    );
  }
}

class _AstroPainter extends CustomPainter {
  _AstroPainter({
    required this.mood,
    required this.color,
    required this.mouth,
    required this.t,
    required this.blink,
    required this.change,
  });

  final MoodState mood;
  final Color color;

  /// Interpolated mouth geometry while speaking; null draws the mood mouth.
  final VisemeMetrics? mouth;
  final double t; // 0..1 looping
  final double blink; // 0 open .. 1 closed
  final double change; // 0..1 mood/color transition progress

  static const _ink = Color(0xFF10141D);
  static const _blush = Color(0xFFFF7A9C);
  static const _sweat = Color(0xFF7FD0FF);
  static const _alert = Color(0xFFFF4D57);
  static const _bulb = Color(0xFFF2F7C7);
  static const _surprise = Color(0xFFF2A93B);

  double get _tau => math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    // Work in the prototype's 200x200 space.
    canvas.scale(size.width / 200, size.height / 200);

    final m = mood.mood;

    _drawShadow(canvas, m);

    // --- whole-body motion (translate / scale / rotate around the body) ---
    canvas.save();
    canvas.translate(100, 120);

    // Postural lean (always applied): Astro leans into the curve, driven
    // continuously by the gyroscope (mood.tilt).
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
      case Mood.alarm:
        dx = 2.2 * math.sin(_tau * t * 18); // urgent shake
        sx = 1.02;
      case Mood.bump:
        dy = -10 * math.sin(_tau * t * 6).abs();
      case Mood.surprised:
        // A quick startle: pop up and stretch tall.
        dy = -11 * math.sin(_tau * t * 6).abs();
        sx = 0.94;
        sy = 1.08;
      case Mood.arrival:
        dy = -9 * math.sin(_tau * t * 2).abs(); // happy hops
      case Mood.dizzy:
        // Shaken silly: fast wobble side to side + a woozy rock and jitter.
        dx = 4.5 * math.sin(_tau * t * 14);
        dy = 2.5 * math.sin(_tau * t * 11);
        rot += (14 * math.sin(_tau * t * 7)) * math.pi / 180;
        sx = 1.05;
        sy = 0.95;
      case Mood.pet:
        rot += (3 * math.sin(_tau * t)) * math.pi / 180;
      case Mood.sleep:
        final b = 0.03 * math.sin(_tau * t * 0.5); // slow, deep breaths
        sx = 1 - b;
        sy = 1 + b;
        dy = 2 * math.sin(_tau * t * 0.5);
      default:
        // rest / thinking / worried / answering / lean
        final b = 0.022 * math.sin(_tau * t);
        sx = 1 + b;
        sy = 1 - b;
    }

    // Squash-and-stretch pop on a mood/color change (peaks mid-transition).
    final pop = math.sin(math.pi * change);
    sx += 0.09 * pop;
    sy -= 0.07 * pop;

    canvas.translate(dx, dy);
    canvas.rotate(rot);
    canvas.scale(sx, sy);
    canvas.translate(-100, -120);

    _drawAttention(canvas, m); // directional cue when a turn is imminent
    _drawAlarmRing(canvas, m);
    _drawAntenna(canvas, m);
    _drawBody(canvas);
    _drawBrows(canvas, m);
    _drawEyes(canvas, m);
    _drawMouth(canvas, m);
    _drawExtras(canvas, m);

    canvas.restore();
  }

  // --- body -----------------------------------------------------------------

  Path _bodyPath() => Path()
    ..moveTo(100, 36)
    ..cubicTo(148, 36, 168, 74, 168, 116)
    ..cubicTo(168, 158, 140, 178, 100, 178)
    ..cubicTo(60, 178, 32, 158, 32, 116)
    ..cubicTo(32, 74, 52, 36, 100, 36)
    ..close();

  void _drawShadow(Canvas canvas, Mood m) {
    // Grounding shadow that shrinks when Astro lifts off (hops / bounces).
    final lift = switch (m) {
      Mood.excited || Mood.bump || Mood.arrival || Mood.surprised => 0.78,
      _ => 1.0,
    };
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(100, 186),
        width: 96 * lift,
        height: 16 * lift,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _drawBody(Canvas canvas) {
    final path = _bodyPath();

    // Base with a soft vertical gradient for a little depth.
    final rect = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.14)!,
            color,
            Color.lerp(color, Colors.black, 0.10)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    // Glossy highlight, top-left.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(78, 74), width: 66, height: 48),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.restore();
  }

  // --- antenna ---------------------------------------------------------------

  void _drawAntenna(Canvas canvas, Mood m) {
    final excited = m == Mood.excited || m == Mood.arrival;
    final lit = m == Mood.thinking || excited || m == Mood.alarm;
    // A gentle bob, more energetic when excited.
    final bob = (excited ? 2.6 : 1.2) * math.sin(_tau * t * (excited ? 3 : 1));
    final tipX = 100 + bob;
    final tipY = 13.0;
    final bulb = m == Mood.alarm ? _alert : _bulb;

    canvas.drawLine(
      const Offset(100, 36),
      Offset(tipX, tipY + 3),
      Paint()
        ..color = _ink.withValues(alpha: 0.3)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (lit) {
      final glow = 0.5 + 0.5 * math.sin(_tau * t * (m == Mood.alarm ? 4 : 1.5));
      canvas.drawCircle(
        Offset(tipX, tipY),
        9,
        Paint()
          ..color = bulb.withValues(alpha: 0.35 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawCircle(
      Offset(tipX, tipY),
      5,
      Paint()..color = bulb.withValues(alpha: lit ? 1 : 0.5),
    );
  }

  // --- brows -----------------------------------------------------------------

  void _drawBrows(Canvas canvas, Mood m) {
    // No brows for closed/special eyes (sleep, pet) or the spiral dizzy eyes.
    if (m == Mood.sleep || m == Mood.pet || m == Mood.dizzy) return;

    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const y = 86.0;

    if (m == Mood.thinking) {
      // Quizzical: left flat, right cocked up.
      _brow(canvas, 64, 88, y, y, paint);
      _brow(canvas, 136, 112, y - 1, y - 8, paint);
      return;
    }

    // (outer, inner) vertical offsets from the base brow line.
    final (double o, double i) = switch (m) {
      Mood.worried => (2.0, -4.0), // inner raised — concern
      Mood.alarm => (-3.0, 5.0), // inner lowered — alert/angry
      Mood.scared || Mood.bump => (-6.0, -6.0), // raised high — surprise
      Mood.surprised => (-8.0, -8.0), // raised highest — startle
      Mood.excited || Mood.arrival => (-4.0, -4.0), // raised — delight
      _ => (1.0, 1.0), // subtle neutral brows
    };
    _brow(canvas, 64, 88, y + o, y + i, paint); // left: outer→inner
    _brow(canvas, 136, 112, y + o, y + i, paint); // right (mirrored)
  }

  void _brow(Canvas c, double xo, double xi, double yo, double yi, Paint p) =>
      c.drawLine(Offset(xo, yo), Offset(xi, yi), p);

  // --- eyes ------------------------------------------------------------------

  void _drawEyes(Canvas canvas, Mood m) {
    if (m == Mood.dizzy) {
      // Spinning spiral eyes — the classic "seeing stars" dizzy look.
      _dizzyEye(canvas, const Offset(76, 104));
      _dizzyEye(canvas, const Offset(124, 104));
      return;
    }
    if (m == Mood.pet) {
      // Happy closed eyes (upward arcs).
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

    var base = switch (m) {
      Mood.excited => 1.2,
      Mood.scared => 1.35,
      Mood.bump => 1.4,
      Mood.surprised => 1.55, // eyes flung wide open
      Mood.alarm => 1.3,
      Mood.arrival => 1.15,
      Mood.lean => 1.15,
      Mood.sleep => 0.5,
      _ => 1.0,
    };
    if (mood.turnImminent) base += 0.15; // heightened attention near a turn
    final openY = base * (1 - 0.92 * blink);

    final gazeDir = switch (mood.gaze) {
      TurnDirection.left => -4.0,
      TurnDirection.right => 4.0,
      TurnDirection.none => 0.0,
    };
    // Idle look-around when resting and not steering anywhere.
    final drift = (m == Mood.rest && mood.gaze == TurnDirection.none)
        ? 2.4 * math.sin(_tau * t * 0.5)
        : 0.0;
    final pupilUp = m == Mood.thinking ? -3.0 : 0.0;
    final pupilX = m == Mood.thinking ? 2.0 : gazeDir + drift;

    final starry = m == Mood.excited || m == Mood.arrival;
    _eye(
      canvas,
      const Offset(76, 104),
      const Offset(80, 100),
      openY,
      pupilX,
      pupilUp,
      starry,
    );
    _eye(
      canvas,
      const Offset(124, 104),
      const Offset(128, 100),
      openY,
      pupilX,
      pupilUp,
      starry,
    );
  }

  /// A rotating spiral eye for the dizzy mood.
  void _dizzyEye(Canvas canvas, Offset c) {
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final spin = _tau * t * 1.6; // whole swirl rotates
    const turns = 2.4, maxR = 8.0, steps = 44;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final a = f * turns * _tau + spin;
      final r = f * maxR;
      final x = c.dx + r * math.cos(a);
      final y = c.dy + r * math.sin(a);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  void _eye(
    Canvas canvas,
    Offset eye,
    Offset pupil,
    double openY,
    double px,
    double py,
    bool starry,
  ) {
    canvas.save();
    canvas.translate(eye.dx, eye.dy);
    canvas.scale(1, openY.clamp(0.05, 1.6));
    canvas.translate(-eye.dx, -eye.dy);
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 30, height: 36),
      Paint()..color = _ink,
    );
    canvas.restore();
    if (openY <= 0.3) return;

    final at = pupil.translate(px, py);
    if (starry) {
      _sparkle(canvas, at, 6, Colors.white);
    } else {
      canvas.drawCircle(at, 5, Paint()..color = Colors.white);
      // tiny secondary glint
      canvas.drawCircle(
        at.translate(-2.4, -2.4),
        1.5,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      path.moveTo(c.dx, c.dy);
      path.lineTo(c.dx + r * math.cos(a - 0.35), c.dy + r * math.sin(a - 0.35));
      path.lineTo(c.dx + (r + 3) * math.cos(a), c.dy + (r + 3) * math.sin(a));
      path.lineTo(c.dx + r * math.cos(a + 0.35), c.dy + r * math.sin(a + 0.35));
      path.close();
    }
    canvas.drawPath(path, paint);
    canvas.drawCircle(c, 2.2, paint);
  }

  // --- mouth -----------------------------------------------------------------

  void _drawMouth(Canvas canvas, Mood m) {
    // Speaking: draw the interpolated parametric mouth whenever it's active.
    if (mouth != null) {
      _parametricMouth(canvas, mouth!);
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
      case Mood.alarm:
        canvas.drawCircle(const Offset(100, 154), 10, fill);
      case Mood.surprised:
        // A big round gasp.
        canvas.drawCircle(const Offset(100, 152), 14, fill);
      case Mood.dizzy:
        // A wide, woozy open mouth that jiggles with the shake.
        final wob = 3.0 * math.sin(_tau * t * 9);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(100, 150 + wob),
            width: 26,
            height: 22 - wob,
          ),
          fill,
        );
      case Mood.excited:
      case Mood.arrival:
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

  /// Draw the mouth from three scalars (jaw open, width, rounding). One shape
  /// for every viseme means transitions are a plain lerp of the scalars, so the
  /// mouth glides between shapes instead of snapping.
  void _parametricMouth(Canvas canvas, VisemeMetrics mm) {
    const cx = 100.0, cy = 147.0;
    // Rounding pulls the corners in, so o/u read narrow and round.
    final halfW = (8 + 12 * mm.width) * (1 - 0.45 * mm.roundness);
    // A small floor keeps closed lips visible as a thin line.
    final openH = 3 + 30 * mm.openness;
    final upperLift = 2 + 4 * mm.roundness;

    final path = Path()
      ..moveTo(cx - halfW, cy)
      ..quadraticBezierTo(cx, cy - upperLift, cx + halfW, cy) // upper lip
      ..quadraticBezierTo(cx, cy + openH, cx - halfW, cy) // lower lip / jaw
      ..close();
    canvas.drawPath(path, Paint()..color = _ink);
  }

  // --- per-mood extras -------------------------------------------------------

  void _drawExtras(Canvas canvas, Mood m) {
    if (m == Mood.pet) {
      final blush = Paint()..color = _blush.withValues(alpha: 0.55);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(58, 130), width: 26, height: 16),
        blush,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(142, 130), width: 26, height: 16),
        blush,
      );
      // Hearts float up and fade.
      for (var i = 0; i < 2; i++) {
        final tt = (t + i * 0.5) % 1;
        _glyph(
          canvas,
          '♥',
          Offset(44.0 + i * 108, 84 - 34 * tt),
          18,
          _blush.withValues(alpha: (1 - tt).clamp(0, 1)),
        );
      }
    }

    if (m == Mood.scared) {
      canvas.drawCircle(const Offset(152, 100), 7, Paint()..color = _sweat);
    }
    if (m == Mood.worried) {
      final tt = t % 1;
      canvas.drawCircle(
        Offset(150, 96 + 8 * tt),
        6,
        Paint()..color = _sweat.withValues(alpha: (1 - tt).clamp(0, 1)),
      );
    }
    if (m == Mood.sleep) {
      // A rising trail of Z's.
      for (var i = 0; i < 3; i++) {
        final tt = (t + i * 0.33) % 1;
        _glyph(
          canvas,
          'z',
          Offset(140 + 14 * tt, 78 - 40 * tt),
          14.0 + 8 * i,
          const Color(0xFF9FB0C7).withValues(alpha: (1 - tt).clamp(0, 1)),
        );
      }
    }
    if (m == Mood.bump) {
      _glyph(canvas, '!', const Offset(116, 74), 32, const Color(0xFFB48BFF));
    }
    if (m == Mood.surprised) {
      // A "!" that pops in with the startle.
      final pop = (0.6 + 0.4 * math.sin(_tau * t * 6)).clamp(0.0, 1.0);
      _glyph(canvas, '!', const Offset(118, 72), 30 + 8 * pop, _surprise);
    }
    if (m == Mood.arrival) {
      _drawArrivalSparkles(canvas);
    }
    if (m == Mood.thinking) {
      _drawThinkBubble(canvas);
    }
  }

  void _drawAlarmRing(Canvas canvas, Mood m) {
    if (m != Mood.alarm) return;
    final pulse = 0.5 + 0.5 * math.sin(_tau * t * 3);
    canvas.drawPath(
      _bodyPath(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 + 3 * pulse
        ..color = _alert.withValues(alpha: 0.35 + 0.4 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawArrivalSparkles(Canvas canvas) {
    for (var i = 0; i < 6; i++) {
      final a = (i / 6) * _tau + t * _tau * 0.3;
      final rr = 78 + 10 * math.sin(_tau * t + i);
      final at = Offset(100 + rr * math.cos(a), 108 + rr * 0.7 * math.sin(a));
      final tw = (0.5 + 0.5 * math.sin(_tau * (t * 2 + i / 6))).clamp(0.0, 1.0);
      _sparkle(
        canvas,
        at,
        3.5 * tw,
        const Color(0xFFF2A93B).withValues(alpha: tw),
      );
    }
  }

  /// A soft directional cue toward the upcoming turn when it's close.
  void _drawAttention(Canvas canvas, Mood m) {
    if (!mood.turnImminent || mood.gaze == TurnDirection.none) return;
    final right = mood.gaze == TurnDirection.right;
    final x = right ? 176.0 : 24.0;
    final pulse = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(_tau * t * 2));
    final dir = right ? 1 : -1;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < 2; i++) {
      final ox = x + dir * i * 9.0;
      canvas.drawPath(
        Path()
          ..moveTo(ox - dir * 6, 100)
          ..lineTo(ox + dir * 6, 112)
          ..lineTo(ox - dir * 6, 124),
        paint,
      );
    }
  }

  void _drawThinkBubble(Canvas canvas) {
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(150, 52), 3.5, white);
    canvas.drawCircle(const Offset(159, 42), 5, white);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(176, 26), width: 46, height: 30),
      white,
    );
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
  bool shouldRepaint(_AstroPainter old) =>
      old.t != t ||
      old.blink != blink ||
      old.change != change ||
      old.mood.mood != mood.mood ||
      old.mood.gaze != mood.gaze ||
      old.mood.tilt != mood.tilt ||
      old.mood.turnImminent != mood.turnImminent ||
      old.color != color ||
      old.mouth != mouth;
}
