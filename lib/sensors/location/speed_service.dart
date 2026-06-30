import 'package:geolocator/geolocator.dart';

/// One GPS speed reading: the chip-computed speed plus its reported accuracy.
///
/// Speed comes from the GNSS chip (Doppler on modern chipsets), not from
/// differentiating positions, which is why it is accurate and instantaneous.
/// `accuracyMps` is the 68th-percentile uncertainty (`getSpeedAccuracy` on
/// Android); the fusion filter uses it to weight how much to trust the fix.
class GpsSpeedSample {
  const GpsSpeedSample({required this.speedMps, required this.accuracyMps});

  /// Speed in m/s, never negative.
  final double speedMps;

  /// 68th-percentile speed uncertainty in m/s. 0 means the chip did not report
  /// one; the filter then falls back to a default uncertainty.
  final double accuracyMps;

  double get speedKmh => speedMps * 3.6;
}

/// Vehicle speed from the GPS. The chip reports speed directly; the
/// accelerometer only fills the gaps between fixes (see `SpeedFusion`). The
/// service only produces data — the mood decision stays in `MoodResolver`.
class SpeedService {
  SpeedService({required this.source});

  /// GPS speed samples (speed + accuracy).
  final Stream<GpsSpeedSample> source;

  factory SpeedService.fromGeolocator() =>
      SpeedService(source: _geolocatorSamples());

  /// Raw GPS samples, for the fusion filter.
  Stream<GpsSpeedSample> samples() => source;

  /// Convenience GPS-only speed in km/h (the non-fused path / fallback).
  Stream<double> speedKmh() => source.map((s) => s.speedKmh);
}

/// Ensure location permission, then stream GPS speed samples. If permission is
/// denied or location is off, the stream stays empty and speed stays at 0.
Stream<GpsSpeedSample> _geolocatorSamples() async* {
  if (!await _ensureLocationPermission()) return;

  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    ),
  ).map((position) {
    final speed = position.speed;
    final accuracy = position.speedAccuracy;
    return GpsSpeedSample(
      speedMps: speed.isNaN || speed < 0 ? 0.0 : speed,
      accuracyMps: accuracy.isNaN || accuracy < 0 ? 0.0 : accuracy,
    );
  });
}

Future<bool> _ensureLocationPermission() async {
  if (!await Geolocator.isLocationServiceEnabled()) return false;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  return permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}
