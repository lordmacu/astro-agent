import 'astro_tool.dart';

/// Takes a photo with the phone camera and saves it to the gallery. Low-risk on
/// explicit request, so it runs without confirmation. The capture is injected as
/// a function, keeping the tool decoupled from the camera stack and testable.
class CameraTool extends AstroTool {
  CameraTool({
    required Future<String?> Function({required bool front}) capture,
    void Function()? playShutter,
    void Function(String path)? onCaptured,
  }) : _capture = capture,
       _playShutter = playShutter,
       _onCaptured = onCaptured;

  final Future<String?> Function({required bool front}) _capture;
  final void Function()? _playShutter;
  final void Function(String path)? _onCaptured;

  @override
  String get name => 'take_photo';

  @override
  String get description =>
      'Take a photo with the phone camera and save it to the gallery. Use when '
      'the driver asks to take a picture. camera "front" is the selfie camera '
      '(driver and passengers), "back" is the rear camera (the scene ahead); '
      'default back.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'camera': {
        'type': 'string',
        'enum': ['front', 'back'],
        'description':
            'Which camera to use: "front" (selfie) or "back" (scene).',
      },
    },
  };

  @override
  Future<ToolResult> run(Map<String, dynamic> args) async {
    final front = (args['camera'] as String?)?.trim().toLowerCase() == 'front';
    final path = await _capture(front: front);
    if (path != null) {
      _playShutter?.call();
      _onCaptured?.call(path);
      return const ToolResult('Photo taken and saved to the gallery.');
    }
    return const ToolResult(
      'Could not take the photo (camera unavailable or permission denied).',
    );
  }
}
