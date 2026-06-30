import 'dart:math';

/// Mouth shapes Chispa cycles through while speaking. Ported from the HTML
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
  Duration nextInterval() =>
      Duration(milliseconds: 85 + _random.nextInt(96));

  /// Return the mouth to rest (e.g. when speech ends).
  void reset() => current = Viseme.openSmall;
}
