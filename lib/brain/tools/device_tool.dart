import '../../core/l10n/app_lang.dart';
import '../../core/l10n/strings.dart';
import 'astro_tool.dart';

/// Controls low-stakes phone hardware: screen brightness, media volume, and the
/// flashlight. Groups what would be several tools into one to stay near the
/// tool budget. Every action is instantly reversible, so it runs without
/// confirmation (unlike a destructive tool such as clearing fault codes). All
/// effects are injected, so the tool is decoupled from the plugins and testable.
class DeviceTool extends AstroTool {
  DeviceTool({
    required Future<void> Function(double value01) setBrightness,
    required Future<void> Function(double value01) setVolume,
    required Future<void> Function(int direction) nudgeVolume,
    required Future<void> Function(bool on) setTorch,
    Future<bool> Function(String appName)? openApp,
    AppLang Function() lang = _defaultLang,
  }) : _setBrightness = setBrightness,
       _setVolume = setVolume,
       _nudgeVolume = nudgeVolume,
       _setTorch = setTorch,
       _openApp = openApp,
       _lang = lang;

  static AppLang _defaultLang() => AppLang.es;

  final Future<void> Function(double value01) _setBrightness;
  final Future<void> Function(double value01) _setVolume;
  final Future<void> Function(int direction) _nudgeVolume;
  final Future<void> Function(bool on) _setTorch;
  final AppLang Function() _lang;

  /// Launch an installed app by name; null when unavailable (e.g. in tests).
  final Future<bool> Function(String appName)? _openApp;

  static const _actions = [
    'set_brightness',
    'set_volume',
    'volume_up',
    'volume_down',
    'flashlight_on',
    'flashlight_off',
    'open_app',
  ];

  @override
  String get name => 'device';

  @override
  String get description =>
      'Control the phone: screen brightness, media volume, the flashlight, and '
      'opening apps. actions: set_brightness/set_volume (need level 0-100), '
      'volume_up, volume_down, flashlight_on, flashlight_off, open_app (needs '
      'app, the app name to launch, e.g. "Spotify").';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'action': {'type': 'string', 'enum': _actions},
      'level': {
        'type': 'integer',
        'description': 'Percentage 0-100 for set_brightness / set_volume.',
      },
      'app': {
        'type': 'string',
        'description': 'App name to launch for open_app, e.g. "WhatsApp".',
      },
    },
    'required': ['action'],
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final action = (args['action'] as String?)?.trim().toLowerCase() ?? '';
    if (!_actions.contains(action)) {
      return ToolResult.error('unknown action: "$action"');
    }

    try {
      switch (action) {
        case 'set_brightness':
          final level = _level(args);
          if (level == null) return const ToolResult.error('need level 0-100');
          await _setBrightness(level / 100);
          return ToolResult(Strings.brightnessSet(level, _lang()));
        case 'set_volume':
          final level = _level(args);
          if (level == null) return const ToolResult.error('need level 0-100');
          await _setVolume(level / 100);
          return ToolResult(Strings.volumeSet(level, _lang()));
        case 'volume_up':
          await _nudgeVolume(1);
          return ToolResult(Strings.volumeUp(_lang()));
        case 'volume_down':
          await _nudgeVolume(-1);
          return ToolResult(Strings.volumeDown(_lang()));
        case 'flashlight_on':
          await _setTorch(true);
          return ToolResult(Strings.flashlightOn(_lang()));
        case 'flashlight_off':
          await _setTorch(false);
          return ToolResult(Strings.flashlightOff(_lang()));
        default: // open_app
          final app = (args['app'] as String?)?.trim() ?? '';
          if (app.isEmpty) return const ToolResult.error('need an app name');
          if (_openApp == null) {
            return ToolResult(Strings.cantOpenApps(_lang()));
          }
          final opened = await _openApp(app);
          return opened
              ? ToolResult(Strings.openingApp(app, _lang()))
              : ToolResult(Strings.appNotFound(app, _lang()));
      }
    } catch (_) {
      return const ToolResult.error('the device rejected that');
    }
  }

  int? _level(Map<String, dynamic> args) {
    final raw = (args['level'] as num?)?.toInt();
    return raw?.clamp(0, 100);
  }
}
