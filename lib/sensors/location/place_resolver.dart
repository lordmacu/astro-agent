import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Resolves the car's current position into a short human place name
/// ("Chapinero, Bogotá") by reverse-geocoding the GPS fix. The `get_context`
/// tool injects [name]; tests can stub it.
///
/// Speed matters — this runs inside a voiced answer. Two guards keep it from
/// blocking: a short-lived cache (the neighbourhood doesn't change in a minute)
/// and a hard time budget, after which it gives up and returns the last known
/// place (or null) rather than stalling the reply.
class PlaceResolver {
  PlaceResolver();

  static const _cacheTtl = Duration(seconds: 90);
  static const _budget = Duration(milliseconds: 1500);

  String? _cached;
  DateTime? _cachedAt;

  Future<String?> name() async {
    final at = _cachedAt;
    if (_cached != null &&
        at != null &&
        DateTime.now().difference(at) < _cacheTtl) {
      return _cached; // fresh enough — instant
    }
    try {
      final place = await _resolve().timeout(_budget);
      if (place != null && place.isNotEmpty) {
        _cached = place;
        _cachedAt = DateTime.now();
      }
      return place ?? _cached;
    } catch (_) {
      return _cached; // timed out or failed — fall back to the last place
    }
  }

  Future<String?> _resolve() async {
    // Prefer the cached fix (instant); only wait briefly for a fresh one.
    final pos =
        await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 2),
          ),
        );
    final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (marks.isEmpty) return null;
    return _format(marks.first);
  }

  /// Prefer "neighbourhood, city"; fall back to whatever fields are present.
  String? _format(Placemark m) {
    final parts = <String>[
      if ((m.subLocality ?? '').isNotEmpty) m.subLocality!,
      if ((m.locality ?? '').isNotEmpty) m.locality!,
    ];
    if (parts.isEmpty) {
      final alt = m.administrativeArea ?? m.country ?? '';
      return alt.isEmpty ? null : alt;
    }
    return parts.join(', ');
  }
}
