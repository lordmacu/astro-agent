import 'package:shared_preferences/shared_preferences.dart';

/// Persists the [ForwardCalibrator]'s learned state (its correlation
/// accumulator) so the forward-axis calibration survives app restarts instead
/// of relearning every drive. Stored as three stringified doubles under one
/// key; a corrupt or missing value loads as null (fall back to relearning).
class CalibrationStore {
  CalibrationStore();

  static const String _key = 'forward_axis_accumulator';

  /// Load the saved accumulator `[Cx, Cy, Cz]`, or null if none/corrupt.
  Future<List<double>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null || raw.length != 3) return null;
    final parsed = [for (final s in raw) double.tryParse(s)];
    if (parsed.any((v) => v == null)) return null;
    return parsed.cast<double>();
  }

  /// Save the accumulator `[Cx, Cy, Cz]`.
  Future<void> save(List<double> accumulator) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [
      for (final v in accumulator) v.toString(),
    ]);
  }
}
