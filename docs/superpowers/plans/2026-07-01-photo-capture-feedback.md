# Photo Capture Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When Astro takes a photo, play a native shutter sound and show a popup with the captured thumbnail plus Ver (full-screen in-app) and Cerrar.

**Architecture:** `CameraCapture.capture()` returns the captured image path; `CameraTool` plays the shutter and publishes the path to `capturedPhotoProvider`; `PetScreen` watches it and renders an overlay (thumbnail + Ver/Cerrar), with Ver pushing a full-screen `PhotoViewerScreen`.

**Tech Stack:** Flutter, Riverpod 2, `camera`/`gal` (existing), Android `MediaActionSound` (native shutter via the existing `astro/media` MethodChannel).

## Global Constraints

- Code (identifiers, comments, docs, filenames) in **English only**. UI strings shown to the driver are Spanish.
- State/DI via **Riverpod 2** only.
- Follow existing patterns: `MediaChannel`/`MediaController` for native audio; the `_confirmOverlay` overlay pattern in `pet_screen.dart` for the popup; tool callbacks injected at construction (as `CameraTool` already does for `capture`).
- The photo is still saved to the gallery (`Gal.putImage`) exactly as today; the returned path is the local file for the in-app thumbnail/viewer.
- Git identity for every commit: `user.name=lordmacu`, `user.email=10134930+lordmacu@users.noreply.github.com`. **Never** add a `Co-Authored-By` / Claude coauthor line.
- Before declaring a Dart task done: `dart format .` and `flutter analyze` with no NEW warnings (there are ~4 pre-existing info lints in unrelated files — those are fine).
- The repo has heavy parallel WIP; `git add` ONLY the files each task names. One known pre-existing suite failure exists (`test/widget_test.dart` 'renders the resting mood on launch') from parallel work — ignore only that one; introduce no others.

---

## Task 1: Capture returns a path; CameraTool plays shutter + publishes it

**Files:**
- Modify: `lib/platform/camera_capture.dart` (return `String?`)
- Modify: `lib/brain/tools/camera_tool.dart` (new signature + optional `playShutter`/`onCaptured`)
- Modify: `lib/core/state/app_state_provider.dart` (add `capturedPhotoProvider`)
- Modify: `lib/brain/astro_brain_provider.dart` (wire the tool)
- Test: `test/camera_tool_test.dart` (update to the new signature + new behavior)

**Interfaces:**
- Produces:
  - `CameraCapture.capture({required bool front}) → Future<String?>` (image path on success, null on failure).
  - `CameraTool({required Future<String?> Function({required bool front}) capture, void Function()? playShutter, void Function(String path)? onCaptured})`.
  - `final capturedPhotoProvider = StateProvider<String?>((_) => null);` in `app_state_provider.dart`.

- [ ] **Step 1: Update the failing test**

Replace `test/camera_tool_test.dart` with:

```dart
import 'package:astro/brain/astro_brain.dart';
import 'package:astro/brain/llm/llm_client.dart';
import 'package:astro/brain/llm/llm_message.dart';
import 'package:astro/brain/tools/camera_tool.dart';
import 'package:astro/brain/tools/tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the requested lens and returns a scripted path (or null on failure).
class FakeCapture {
  FakeCapture({this.result = '/tmp/astro_shot.jpg'});
  final String? result;
  int calls = 0;
  bool? lastFront;

  Future<String?> capture({required bool front}) async {
    calls++;
    lastFront = front;
    return result;
  }
}

class FakeLlmClient implements LlmClient {
  FakeLlmClient(this._script);
  final List<LlmResponse> _script;
  int _turn = 0;

  @override
  String get providerId => 'fake';
  @override
  Future<LlmResponse> complete(LlmRequest request) async => _script[_turn++];
  @override
  Stream<LlmStreamChunk> completeStream(LlmRequest request) =>
      streamViaComplete(complete(request));
}

void main() {
  group('CameraTool', () {
    test('is read-only (no confirmation) and named take_photo', () {
      final tool = CameraTool(capture: FakeCapture().capture);
      expect(tool.name, 'take_photo');
      expect(tool.mutates, isFalse);
    });

    test('camera "front" selects the front lens', () async {
      final cap = FakeCapture();
      final tool = CameraTool(capture: cap.capture);
      final result = await tool.run({'camera': 'front'});
      expect(cap.lastFront, isTrue);
      expect(result.isError, isFalse);
      expect(result.content.toLowerCase(), contains('gallery'));
    });

    test('default (no camera arg) uses the back lens', () async {
      final cap = FakeCapture();
      final tool = CameraTool(capture: cap.capture);
      await tool.run(const {});
      expect(cap.lastFront, isFalse);
    });

    test('on success: plays shutter and publishes the captured path', () async {
      var shutters = 0;
      String? published;
      final tool = CameraTool(
        capture: FakeCapture(result: '/tmp/shot.jpg').capture,
        playShutter: () => shutters++,
        onCaptured: (p) => published = p,
      );
      final result = await tool.run(const {});
      expect(shutters, 1);
      expect(published, '/tmp/shot.jpg');
      expect(result.isError, isFalse);
    });

    test('on failure: no shutter, no publish, reports the error', () async {
      var shutters = 0;
      String? published;
      final tool = CameraTool(
        capture: FakeCapture(result: null).capture,
        playShutter: () => shutters++,
        onCaptured: (p) => published = p,
      );
      final result = await tool.run(const {});
      expect(shutters, 0);
      expect(published, isNull);
      expect(result.content.toLowerCase(), contains('could not'));
    });
  });

  test('end-to-end: brain calls take_photo then answers', () async {
    final cap = FakeCapture();
    final registry = ToolRegistry()..register(CameraTool(capture: cap.capture));

    final brain = AstroBrain(
      client: FakeLlmClient([
        LlmResponse(
          message: LlmMessage(
            role: Role.assistant,
            blocks: const [
              ToolUseBlock(
                id: 'call_1',
                name: 'take_photo',
                arguments: {'camera': 'front'},
              ),
            ],
          ),
          stopReason: StopReason.toolUse,
        ),
        LlmResponse(
          message: LlmMessage.text(Role.assistant, '¡Listo, te tomé la foto!'),
          stopReason: StopReason.endTurn,
        ),
      ]),
      registry: registry,
    );

    final answer = await brain.ask('toma una foto', model: 'm');

    expect(cap.calls, 1);
    expect(cap.lastFront, isTrue);
    expect(answer, '¡Listo, te tomé la foto!');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/camera_tool_test.dart`
Expected: FAIL — `FakeCapture.capture` now returns `String?` but `CameraTool` still expects a `bool`-returning function / has no `playShutter`/`onCaptured`.

- [ ] **Step 3: Update CameraCapture to return the path**

In `lib/platform/camera_capture.dart`, change the signature and the two return points:

```dart
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
```

(Update the class doc-comment's "Returns true on success, false on any failure" line to describe the path/null return.)

- [ ] **Step 4: Update CameraTool to the new signature + feedback callbacks**

Replace the body of `lib/brain/tools/camera_tool.dart`'s class with:

```dart
class CameraTool extends AstroTool {
  CameraTool({
    required Future<String?> Function({required bool front}) capture,
    void Function()? playShutter,
    void Function(String path)? onCaptured,
  })  : _capture = capture,
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
```

(Keep the existing imports at the top of the file.)

- [ ] **Step 5: Add the provider**

In `lib/core/state/app_state_provider.dart`, next to `pettingProvider`, add:

```dart
/// The path of the most recently captured photo, or null when no photo popup is
/// showing. Set by the take_photo tool; the pet screen shows a thumbnail popup
/// while it is non-null, and clears it on Cerrar.
final capturedPhotoProvider = StateProvider<String?>((_) => null);
```

- [ ] **Step 6: Wire the tool in the brain**

In `lib/brain/astro_brain_provider.dart`, replace the CameraTool registration line
`..register(CameraTool(capture: const CameraCapture().capture))` with:

```dart
    ..register(
      CameraTool(
        capture: const CameraCapture().capture,
        playShutter: media.shutter,
        onCaptured: (path) =>
            ref.read(capturedPhotoProvider.notifier).state = path,
      ),
    )
```

(`media` is the `MediaController` already obtained in this provider via `ref.read(mediaControllerProvider)`; `media.shutter` is added in Task 2. `capturedPhotoProvider` is imported from `app_state_provider.dart`, already imported here.)

> NOTE: `media.shutter` does not exist until Task 2. To keep Task 1 compiling and green on its own, TEMPORARILY wire `playShutter: () {}` (no-op) here, and Task 2 switches it to `media.shutter`. The Task 2 step explicitly makes this change.

- [ ] **Step 7: Run tests + analyze**

Run: `flutter test test/camera_tool_test.dart`
Expected: PASS (6 tests).
Run: `flutter analyze lib/platform/camera_capture.dart lib/brain/tools/camera_tool.dart lib/brain/astro_brain_provider.dart lib/core/state/app_state_provider.dart`
Expected: no new issues.

- [ ] **Step 8: Commit**

```bash
git add lib/platform/camera_capture.dart lib/brain/tools/camera_tool.dart lib/core/state/app_state_provider.dart lib/brain/astro_brain_provider.dart test/camera_tool_test.dart
git commit -m "feat(camera): capture returns path; take_photo publishes it + shutter hook"
```

---

## Task 2: Native shutter sound (MediaActionSound)

**Files:**
- Modify: `android/app/src/main/kotlin/com/lordmacu/astro/media/MediaChannel.kt` (add `playShutter`)
- Modify: `lib/platform/media_controller.dart` (add `shutter()`)
- Modify: `lib/brain/astro_brain_provider.dart` (switch the no-op to `media.shutter`)
- Test: `test/media_controller_shutter_test.dart`

**Interfaces:**
- Consumes: the `astro/media` MethodChannel.
- Produces: `MediaController.shutter() → Future<bool>` invoking method `shutter`.

- [ ] **Step 1: Write the failing test**

```dart
// test/media_controller_shutter_test.dart
import 'package:astro/platform/media_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shutter() invokes the "shutter" method and returns its result', () async {
    const channel = MethodChannel('astro/media');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final ok = await MediaController(channel: channel).shutter();
    expect(ok, isTrue);
    expect(calls, contains('shutter'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/media_controller_shutter_test.dart`
Expected: FAIL — `MediaController` has no `shutter` method.

- [ ] **Step 3: Add `shutter()` to MediaController**

In `lib/platform/media_controller.dart`, add after `beep()`:

```dart
  /// Play the system camera shutter sound (matches the stock camera; respects
  /// silent mode). Best-effort.
  Future<bool> shutter() => _invoke('shutter');
```

- [ ] **Step 4: Run the Dart test**

Run: `flutter test test/media_controller_shutter_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the native handler**

In `android/app/src/main/kotlin/com/lordmacu/astro/media/MediaChannel.kt`:

Add the import:

```kotlin
import android.media.MediaActionSound
```

Add a reused sound instance field (next to the `channel` property, inside the class body):

```kotlin
    private val actionSound = MediaActionSound()
```

Add the `shutter` case to the `when (call.method)` block (next to `"beep"`):

```kotlin
                "shutter" -> result.success(shutter())
```

Add the method (next to `beep()`):

```kotlin
    /** Play the system camera shutter sound. Uses MediaActionSound, which honors
     *  the device's shutter-sound policy (silent mode). Best-effort. */
    private fun shutter(): Boolean = runCatching {
        actionSound.play(MediaActionSound.SHUTTER_CLICK)
        true
    }.getOrDefault(false)
```

- [ ] **Step 6: Switch the brain wiring to the real shutter**

In `lib/brain/astro_brain_provider.dart`, change the CameraTool `playShutter:` argument from the Task-1 no-op `() {}` to `media.shutter`.

- [ ] **Step 7: Build + full suite**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL (Kotlin compiles). (If it fails for a reason clearly in the parallel android/ WIP and not this change, report it and proceed.)
Run: `flutter test`
Expected: all pass except the known `test/widget_test.dart` failure.

- [ ] **Step 8: Commit**

```bash
git add android/app/src/main/kotlin/com/lordmacu/astro/media/MediaChannel.kt lib/platform/media_controller.dart lib/brain/astro_brain_provider.dart test/media_controller_shutter_test.dart
git commit -m "feat(camera): native shutter sound via MediaActionSound"
```

---

## Task 3: Photo overlay in PetScreen + full-screen viewer

**Files:**
- Create: `lib/ui/photo_viewer_screen.dart`
- Modify: `lib/ui/pet_screen.dart` (photo overlay in the existing Stack)
- Test: `test/ui/photo_feedback_test.dart`

**Interfaces:**
- Consumes: `capturedPhotoProvider` (Task 1).
- Produces: `class PhotoViewerScreen extends StatelessWidget { const PhotoViewerScreen({required String path}); }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/photo_feedback_test.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astro/ui/photo_viewer_screen.dart';

void main() {
  testWidgets('PhotoViewerScreen shows the image in an InteractiveViewer',
      (tester) async {
    // A path that need not exist on disk; Image.file renders an errorBuilder
    // rather than throwing, so the widget tree is still valid.
    await tester.pumpWidget(const MaterialApp(
      home: PhotoViewerScreen(path: '/tmp/nonexistent_astro.jpg'),
    ));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/photo_feedback_test.dart`
Expected: FAIL — `photo_viewer_screen.dart` not found.

- [ ] **Step 3: Create the viewer**

```dart
// lib/ui/photo_viewer_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen, zoomable view of a captured photo. Stays in-app (dashboard use).
class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'No se pudo cargar la foto',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the viewer test**

Run: `flutter test test/ui/photo_feedback_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the photo overlay to PetScreen**

In `lib/ui/pet_screen.dart`:

Add imports:

```dart
import 'dart:io';
import 'photo_viewer_screen.dart';
```

(`dart:io` for `File`; `dart:async` is already imported. `capturedPhotoProvider` comes from `app_state_provider.dart`, already imported.)

In `build`, read the captured photo near the other `ref.watch` calls:

```dart
    final capturedPhoto = ref.watch(capturedPhotoProvider);
```

Add the overlay to the existing top-level `Stack`'s `children` (after `if (_confirmPrompt != null) _confirmOverlay(accent),`):

```dart
          if (capturedPhoto != null) _photoOverlay(context, ref, capturedPhoto),
```

Add these two methods to `_PetScreenState`:

```dart
  /// Popup shown right after a photo is taken: a thumbnail with Ver / Cerrar.
  Widget _photoOverlay(BuildContext context, WidgetRef ref, String path) {
    void close() => ref.read(capturedPhotoProvider.notifier).state = null;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.bgBottomFallback,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(path),
                    height: 200,
                    width: 268,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 200,
                      child: Center(
                        child: Text('Sin vista previa',
                            style: TextStyle(color: DesignTokens.dim)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        close();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PhotoViewerScreen(path: path),
                          ),
                        );
                      },
                      child: const Text('Ver'),
                    ),
                    TextButton(
                      onPressed: close,
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
```

(If `build`'s signature is `Widget build(BuildContext context)` on a `ConsumerState`, `ref` is a field — call `_photoOverlay(context, ref, capturedPhoto)` with the state's `ref`.)

- [ ] **Step 6: Add a widget test for the overlay**

Append to `test/ui/photo_feedback_test.dart`:

```dart
  testWidgets('photo overlay shows thumbnail + Ver/Cerrar; Cerrar clears',
      (tester) async {
    // Import at top of file (add these): flutter_riverpod, shared_preferences,
    // app_state_provider, settings_providers, stt_provider, voice_interfaces,
    // pet_screen. Provide the same overrides pet_screen_wake_test uses
    // (sharedPreferencesProvider, wakeWordProvider fake, speechRecognizerProvider
    // fake, appStateProvider) plus capturedPhotoProvider overridden to a path.
    // Then: expect find.text('Ver') + find.text('Cerrar'); tap 'Cerrar';
    // expect the container's provider is cleared (overlay gone).
  });
```

Because that widget test needs the same PetScreen provider scaffolding as
`test/pet_screen_wake_test.dart`, copy that test's `FakeWake` + `FakeRecognizer`
+ its `ProviderScope` overrides, add
`capturedPhotoProvider.overrideWith((ref) => StateController<String?>('/tmp/x.jpg'))`
(or set it after pump via `container.read(capturedPhotoProvider.notifier).state`),
pump `PetScreen`, assert `find.text('Ver')` and `find.text('Cerrar')` are found,
tap 'Cerrar', pump, and assert `find.text('Cerrar')` is gone. Write it concretely
following the pet_screen_wake_test pattern (do not leave the comment block above
in the final file — replace it with the real test).

- [ ] **Step 7: Run tests + analyze**

Run: `flutter test test/ui/photo_feedback_test.dart`
Expected: PASS (2 tests).
Run: `flutter analyze lib/ui/photo_viewer_screen.dart lib/ui/pet_screen.dart`
Expected: no new issues.
Run: `flutter test`
Expected: all pass except the known `test/widget_test.dart` failure.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/photo_viewer_screen.dart lib/ui/pet_screen.dart test/ui/photo_feedback_test.dart
git commit -m "feat(camera): photo popup (thumbnail + Ver/Cerrar) + full-screen viewer"
```

---

## Final verification

- [ ] `flutter test` — green except the known parallel-WIP `widget_test.dart` failure; no new failures.
- [ ] `flutter analyze` — no new warnings.
- [ ] `flutter build apk --debug` — compiles.
- [ ] On-device: ask Astro to take a photo → hear the shutter, see the thumbnail popup → Ver opens the full-screen zoomable image → Cerrar dismisses; the photo is in the gallery.

## Notes / follow-up
- The thumbnail/viewer read the camera plugin's temp file path. It persists for the session; if the OS clears temp before the user opens the viewer, `Image.file`'s errorBuilder shows a fallback (no crash).
