import '../../core/state/mood.dart' show TurnDirection;

/// One parsed navigation snapshot from the Maps notification. Neutral
/// ([none]) when there is no active guidance.
class NavReading {
  const NavReading({
    this.turnDirection = TurnDirection.none,
    this.distanceM,
    this.arrived = false,
  });

  final TurnDirection turnDirection;

  /// Distance to the next maneuver in metres, or null when unknown/unsupported.
  final double? distanceM;

  final bool arrived;

  static const NavReading none = NavReading();

  @override
  bool operator ==(Object other) =>
      other is NavReading &&
      other.turnDirection == turnDirection &&
      other.distanceM == distanceM &&
      other.arrived == arrived;

  @override
  int get hashCode => Object.hash(turnDirection, distanceM, arrived);

  @override
  String toString() =>
      'NavReading(dir: $turnDirection, distM: $distanceM, arrived: $arrived)';
}
