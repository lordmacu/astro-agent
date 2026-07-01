import 'package:flutter/foundation.dart';

import 'astro_tool.dart';

/// Sets a countdown timer or an alarm through the system clock app. Both
/// effects are injected (Android AlarmClock intents) so the tool is decoupled
/// and testable. Low-risk (the clock app shows the pending timer), no confirm.
class TimerTool extends AstroTool {
  TimerTool({
    required Future<bool> Function(int seconds, String? label) setTimer,
    required Future<bool> Function(int hour, int minute, String? label)
    setAlarm,
  }) : _setTimer = setTimer,
       _setAlarm = setAlarm;

  final Future<bool> Function(int seconds, String? label) _setTimer;
  final Future<bool> Function(int hour, int minute, String? label) _setAlarm;

  @override
  String get name => 'timer';

  @override
  String get description =>
      'Set a countdown timer or an alarm. action "timer" needs seconds; '
      'action "alarm" needs hour and minute (24h). Use for "set a timer for '
      '10 minutes" or "wake me at 6:30".';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['timer', 'alarm'],
      },
      'seconds': {
        'type': 'integer',
        'description': 'For "timer": total seconds to count down.',
      },
      'hour': {'type': 'integer', 'description': 'For "alarm": hour, 0-23.'},
      'minute': {
        'type': 'integer',
        'description': 'For "alarm": minute, 0-59.',
      },
      'label': {'type': 'string', 'description': 'Optional label.'},
    },
    'required': ['action'],
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    debugPrint('[timer] run args=$args');
    final action = (args['action'] as String?)?.trim().toLowerCase() ?? '';
    final label = (args['label'] as String?)?.trim();

    switch (action) {
      case 'timer':
        final seconds = (args['seconds'] as num?)?.toInt() ?? 0;
        if (seconds <= 0) return const ToolResult.error('seconds must be > 0');
        final ok = await _setTimer(seconds, label);
        debugPrint('[timer] setTimer(${seconds}s, "$label") -> $ok');
        return ok
            ? ToolResult('Listo, temporizador de ${_pretty(seconds)}.')
            : const ToolResult('No pude poner el temporizador.');
      case 'alarm':
        final hour = (args['hour'] as num?)?.toInt();
        final minute = (args['minute'] as num?)?.toInt() ?? 0;
        if (hour == null ||
            hour < 0 ||
            hour > 23 ||
            minute < 0 ||
            minute > 59) {
          return const ToolResult.error('need a valid hour (0-23) and minute');
        }
        final ok = await _setAlarm(hour, minute, label);
        debugPrint('[timer] setAlarm($hour:$minute, "$label") -> $ok');
        return ok
            ? ToolResult(
                'Alarma puesta para las '
                '${hour.toString().padLeft(2, '0')}:'
                '${minute.toString().padLeft(2, '0')}.',
              )
            : const ToolResult('No pude poner la alarma.');
      default:
        return ToolResult.error('unknown action: "$action"');
    }
  }

  String _pretty(int seconds) {
    final m = seconds ~/ 60, s = seconds % 60;
    if (m == 0) return '$s s';
    if (s == 0) return '$m min';
    return '$m min $s s';
  }
}
