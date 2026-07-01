import '../../platform/media_controller.dart';
import 'astro_tool.dart';

/// Plays and controls music through the phone's media stack. One tool with an
/// `action` covers the whole surface (play a query, pause, resume, skip), which
/// keeps the active tool count low. Low-risk, so it runs without confirmation.
class MusicTool extends AstroTool {
  MusicTool(this._media);

  final MediaController _media;

  static const _actions = ['play', 'pause', 'resume', 'next', 'previous'];

  @override
  String get name => 'music';

  @override
  String get description =>
      'Play or control music on the phone. action "play" starts the given query '
      '(song, artist, playlist); "pause"/"resume"/"next"/"previous" control '
      'whatever is already playing. Use when the driver asks for music.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': _actions,
        'description': 'What to do.',
      },
      'query': {
        'type': 'string',
        'description': 'For action "play": what to play, e.g. "jazz relajado".',
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

    final bool ok;
    switch (action) {
      case 'play':
        final query = (args['query'] as String?)?.trim() ?? '';
        if (query.isEmpty) return const ToolResult.error('query is empty');
        ok = await _media.play(query);
        return ok
            ? ToolResult('Playing "$query".')
            : const ToolResult('No music app could handle that.');
      case 'pause':
        ok = await _media.pause();
      case 'resume':
        ok = await _media.resume();
      case 'next':
        ok = await _media.next();
      default: // previous
        ok = await _media.previous();
    }
    return ok
        ? ToolResult('Done: $action.')
        : const ToolResult('Nothing is playing right now.');
  }
}
