import 'package:battery_plus/battery_plus.dart';

/// Reads the phone's battery level and whether it's charging, for get_context.
/// Best-effort: returns null on any failure so the tool just omits the line.
class BatteryReader {
  BatteryReader([Battery? battery]) : _battery = battery ?? Battery();

  final Battery _battery;

  /// `(level 0-100, charging)`, or null if it can't be read.
  Future<(int level, bool charging)?> read() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      final charging =
          state == BatteryState.charging || state == BatteryState.full;
      return (level, charging);
    } on Object {
      return null;
    }
  }
}
