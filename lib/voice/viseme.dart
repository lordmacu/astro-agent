import 'dart:math';

/// Mouth shapes Astro cycles through while speaking. Ported from the HTML
/// prototype's five-shape set; the production character maps each to a Rive
/// input. Real per-phoneme lip-sync is a future upgrade — for now the shapes
/// alternate freely between the TTS start and end callbacks.
enum Viseme {
  /// m, b, p — a thin closed line.
  closed,

  /// neutral — a small oval.
  openSmall,

  /// a — a wide open mouth.
  openWide,

  /// o, u — a round mouth.
  round,

  /// e, i — a wide, low oval.
  broad,
}

/// A mouth shape as three interpolatable scalars. Keeping the geometry as plain
/// numbers (instead of a baked `Path`) lets the painter tween smoothly between
/// visemes rather than hard-switching, so speech doesn't look jumpy.
class VisemeMetrics {
  const VisemeMetrics({
    required this.openness,
    required this.width,
    required this.roundness,
  });

  /// Jaw opening: 0 lips shut .. 1 wide open.
  final double openness;

  /// Mouth width: 0 narrow .. 1 spread wide.
  final double width;

  /// Lip rounding: 0 flat .. 1 rounded (o/u).
  final double roundness;

  /// Linear blend between two shapes, for the tween mid-transition.
  static VisemeMetrics lerp(VisemeMetrics a, VisemeMetrics b, double t) =>
      VisemeMetrics(
        openness: a.openness + (b.openness - a.openness) * t,
        width: a.width + (b.width - a.width) * t,
        roundness: a.roundness + (b.roundness - a.roundness) * t,
      );

  @override
  bool operator ==(Object other) =>
      other is VisemeMetrics &&
      other.openness == openness &&
      other.width == width &&
      other.roundness == roundness;

  @override
  int get hashCode => Object.hash(openness, width, roundness);
}

/// The mouth geometry for each viseme. Starting values tuned to match the
/// prototype's five shapes; the parametric mouth in `AstroCharacter` renders and
/// interpolates them.
extension VisemeGeometry on Viseme {
  VisemeMetrics get metrics => switch (this) {
    Viseme.closed => const VisemeMetrics(
      openness: 0.0,
      width: 0.5,
      roundness: 0.2,
    ),
    Viseme.openSmall => const VisemeMetrics(
      openness: 0.32,
      width: 0.45,
      roundness: 0.4,
    ),
    Viseme.openWide => const VisemeMetrics(
      openness: 0.9,
      width: 0.6,
      roundness: 0.15,
    ),
    Viseme.round => const VisemeMetrics(
      openness: 0.55,
      width: 0.3,
      roundness: 0.95,
    ),
    Viseme.broad => const VisemeMetrics(
      openness: 0.35,
      width: 0.95,
      roundness: 0.0,
    ),
  };
}

/// Emits a natural-looking, irregular sequence of visemes while speaking.
/// Mirrors the prototype: draw from a weighted bag, never repeat the same shape
/// twice in a row, with slightly varying intervals. Inject a [Random] for
/// deterministic tests.
class VisemeSequencer {
  VisemeSequencer({Random? random, this.current = Viseme.openSmall})
    : _random = random ?? Random();

  final Random _random;
  Viseme current;

  /// Weighted bag (open shapes appear more often, closed least), matching the
  /// prototype's VPOOL distribution.
  static const List<Viseme> _pool = [
    Viseme.openSmall,
    Viseme.openWide,
    Viseme.round,
    Viseme.broad,
    Viseme.openWide,
    Viseme.openSmall,
    Viseme.broad,
    Viseme.round,
    Viseme.openWide,
    Viseme.closed,
  ];

  /// The next viseme, never equal to the current one.
  Viseme next() {
    Viseme candidate;
    do {
      candidate = _pool[_random.nextInt(_pool.length)];
    } while (candidate == current);
    current = candidate;
    return candidate;
  }

  /// Time until the next shape change: 85–180 ms, irregular on purpose.
  Duration nextInterval() => Duration(milliseconds: 85 + _random.nextInt(96));

  /// Return the mouth to rest (e.g. when speech ends).
  void reset() => current = Viseme.openSmall;
}
