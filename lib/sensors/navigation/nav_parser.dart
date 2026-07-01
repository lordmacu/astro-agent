import '../../core/state/mood.dart' show TurnDirection;
import 'nav_reading.dart';

/// Turns a raw Google Maps notification (title + text) into a [NavReading].
/// Pure and bilingual (Spanish + English); best-effort and easy to extend by
/// adding patterns. Anything unrecognized maps to [NavReading.none].
abstract final class NavParser {
  static final _arrival = RegExp(
    r'has llegado|llegaste|you have arrived|you.?ve arrived|arriving now',
    caseSensitive: false,
  );
  // \b around the whole words so Spanish "derecho" (straight) is not a right turn.
  static final _left = RegExp(r'\b(izquierda|left)\b', caseSensitive: false);
  static final _right = RegExp(r'\b(derecha|right)\b', caseSensitive: false);
  // Metric distance only: number (optional decimal, comma or dot) + m/km.
  static final _distance = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(km|m)\b',
    caseSensitive: false,
  );

  static NavReading parse({String? title, String? text, bool removed = false}) {
    if (removed) return NavReading.none;
    final blob = '${title ?? ''} ${text ?? ''}'.trim();
    if (blob.isEmpty) return NavReading.none;

    if (_arrival.hasMatch(blob)) {
      return const NavReading(arrived: true);
    }

    final direction = _right.hasMatch(blob)
        ? TurnDirection.right
        : _left.hasMatch(blob)
        ? TurnDirection.left
        : TurnDirection.none;

    final distance = _parseDistance(blob);

    if (direction == TurnDirection.none && distance == null) {
      return NavReading.none;
    }
    return NavReading(turnDirection: direction, distanceM: distance);
  }

  static double? _parseDistance(String blob) {
    final m = _distance.firstMatch(blob);
    if (m == null) return null;
    final value = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (value == null) return null;
    final unit = m.group(2)!.toLowerCase();
    return unit == 'km' ? value * 1000 : value;
  }
}
