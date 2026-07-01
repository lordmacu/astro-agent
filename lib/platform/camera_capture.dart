import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

/// Takes a still photo headlessly — no preview widget — for the `take_photo`
/// tool: request permission, bind the chosen lens, capture, save to the gallery,
/// release the camera. Returns the captured file path on success, or null on any
/// failure (no permission, no camera, capture/save error) so the tool can report
/// it plainly.
class CameraCapture {
  const CameraCapture();

  /// Takes a still photo headlessly, saves it to the gallery, and returns the
  /// captured file path (used for the in-app thumbnail/viewer), or null on any
  /// failure (no permission, no camera, capture/save error).
  Future<String?> capture({required bool front}) async {
    if (!await Permission.camera.request().isGranted) return null;

    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException {
      return null;
    }
    if (cameras.isEmpty) return null;

    final wanted = front ? CameraLensDirection.front : CameraLensDirection.back;
    final description = cameras.firstWhere(
      (c) => c.lensDirection == wanted,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      final shot = await controller.takePicture();
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) return null;
      }
      await Gal.putImage(shot.path);
      return shot.path;
    } on Object {
      return null;
    } finally {
      await controller.dispose();
    }
  }
}
