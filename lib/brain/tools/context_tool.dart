import 'astro_tool.dart';

/// A single read-only snapshot of the here-and-now: local time, car speed, and
/// approximate location. Groups what used to be three tools (time, speed,
/// location) into one call, keeping the active tool count low — the model gets
/// full situational awareness in one round-trip. All inputs are injected so the
/// tool stays decoupled from the sensor stack and testable.
class ContextTool extends AstroTool {
  ContextTool({
    required double? Function() speedKmh,
    Future<String?> Function()? locationName,
    DateTime Function()? now,
    bool Function()? carMode,
    Future<(int level, bool charging)?> Function()? battery,
  }) : _speedKmh = speedKmh,
       _locationName = locationName,
       _now = now ?? DateTime.now,
       _carMode = carMode ?? (() => true),
       _battery = battery;

  final double? Function() _speedKmh;
  final Future<String?> Function()? _locationName;
  final DateTime Function() _now;

  /// Whether Astro is in a car right now. In normal mode the speed line is
  /// dropped, so the model never assumes it's driving.
  final bool Function() _carMode;

  /// Phone battery `(level%, charging)`, or null when unavailable.
  final Future<(int level, bool charging)?> Function()? _battery;

  @override
  String get name => 'get_context';

  @override
  String get description =>
      'Get a snapshot of the current situation: local time and date, the car\'s '
      'speed in km/h, the approximate location, and the phone battery. Use for '
      '"what time is it", "how fast are we going", "where are we", "how much '
      'battery", or to ground any answer in the here and now.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final n = _now();
    String two(int v) => v.toString().padLeft(2, '0');
    final lines = <String>[
      'Local time: ${two(n.hour)}:${two(n.minute)} on '
          '${n.year}-${two(n.month)}-${two(n.day)} (weekday ${n.weekday}).',
    ];

    if (_carMode()) {
      final speed = _speedKmh();
      lines.add(
        speed == null
            ? 'Speed: unknown (no GPS fix yet).'
            : 'Speed: ${speed.round()} km/h.',
      );
    }

    final place = await _locationName?.call();
    if (place != null && place.isNotEmpty) {
      lines.add('Location: near $place.');
    }

    final bat = await _battery?.call();
    if (bat != null) {
      lines.add('Battery: ${bat.$1}%${bat.$2 ? ' (charging)' : ''}.');
    }

    return ToolResult(lines.join('\n'));
  }
}
