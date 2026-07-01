# Photo capture feedback — design

**Date:** 2026-07-01
**Status:** approved for planning

## Goal

When Astro takes a photo (the `take_photo` tool), give the driver immediate
feedback: play a camera shutter sound and show a popup with the captured
thumbnail plus **Ver** (view full-screen in-app) and **Cerrar** (dismiss).
Today `take_photo` is headless (silent capture to gallery, text-only result).

## Decisions (from brainstorming)
- **Shutter sound: native** `MediaActionSound.SHUTTER_CLICK` (matches the system
  camera, respects silent mode) via the existing `MediaChannel`.
- **Ver: full-screen in-app viewer** (`Image.file`), so the driver never leaves
  Astro (dashboard use).
- **Popup lifecycle: stays until closed** (explicit Ver / Cerrar).

## Architecture

```
take_photo (voice) → CameraTool.run
 → CameraCapture.capture() returns the saved image PATH (String?, null = failure)
 → on success: MediaController.shutter() (native SHUTTER_CLICK)
              + capturedPhotoProvider.state = path
 → PetScreen watches capturedPhotoProvider → overlay: thumbnail + [Ver] + [Cerrar]
 → Ver → PhotoViewerScreen (full-screen Image.file + InteractiveViewer)
 → Cerrar → capturedPhotoProvider.state = null
```

## Components

1. **`CameraCapture.capture()` returns `String?`** — change the return type from
   `bool` to the captured image path (the camera plugin's `XFile.path`, which
   persists as a temp file for the session and is what the in-app viewer reads),
   or `null` on any failure. The existing permission → capture → `Gal.putImage`
   (save to gallery) → dispose flow is preserved; the returned path is the local
   file used for the thumbnail/viewer. Ripple: the injected capture signature in
   `CameraTool` becomes `Future<String?> Function({required bool front})`, and
   its registration in `astro_brain_provider.dart` is updated.

2. **Native shutter sound** — add a `playShutter` method to the existing
   `MediaChannel` (Kotlin) that plays `MediaActionSound().play(MediaActionSound.SHUTTER_CLICK)`
   (a single reused `MediaActionSound` instance). Dart side: add
   `MediaController.shutter()` invoking the channel method. It respects the
   ringer/silent mode exactly like the system camera.

3. **`capturedPhotoProvider`** — `final capturedPhotoProvider =
   StateProvider<String?>((_) => null);` in the app-state providers. `CameraTool`
   is constructed with two injected callbacks (same injection style it already
   uses for `capture`): `void Function() playShutter` and `void Function(String
   path) onCaptured`. `CameraTool.run`: `final path = await capture(front:...)`;
   if `path != null` → `playShutter()` + `onCaptured(path)` and return the
   success `ToolResult`; else return the failure `ToolResult` (unchanged text).
   `astro_brain_provider` wires `playShutter: media.shutter` and `onCaptured:
   (p) => ref.read(capturedPhotoProvider.notifier).state = p`.

4. **UI overlay + viewer (`PetScreen`)** — when `capturedPhotoProvider != null`,
   render a photo overlay inside the existing `Stack` (mirroring the existing
   `_confirmOverlay` pattern): a card showing `Image.file(File(path))` as a
   thumbnail, a **Ver** button that pushes `PhotoViewerScreen` (a full-screen
   `Image.file` wrapped in `InteractiveViewer` for pinch-zoom, with a close
   affordance), and a **Cerrar** button that sets `capturedPhotoProvider` to
   null. New file `lib/ui/photo_viewer_screen.dart` for the viewer.

## Error handling & degradation
- Capture failure (`null`) → no shutter, no overlay; the tool returns its usual
  failure text. Nothing else changes.
- If the file no longer exists when the overlay/viewer renders (temp cleanup),
  `Image.file` shows its error builder and the overlay offers Cerrar; the app
  never crashes.
- The shutter method swallows native errors (one failing piece never breaks the
  rest); a missing sound never blocks the capture or the popup.

## Testing
- **`CameraTool`** (update the existing tool test to the new signature): fake
  capture returning a path → asserts `playShutter` invoked once, `onCaptured`
  invoked with that path, and a success `ToolResult`; fake returning `null` →
  neither callback fires and a failure `ToolResult`.
- **Photo overlay** widget test: pump `PetScreen` (or the overlay widget) with
  `capturedPhotoProvider` overridden to a path → thumbnail + Ver + Cerrar shown;
  tapping Cerrar clears the provider.
- **`PhotoViewerScreen`** widget test: pump with a path → renders an
  `Image.file` inside an `InteractiveViewer`.
- **`CameraCapture`** (native camera) and **`MediaChannel.playShutter`** (Kotlin)
  are verified on-device / by build; no unit test.

## Build order (vertical slices)
1. `CameraCapture` → `String?` + `CameraTool` signature/wiring + `capturedPhotoProvider` (TDD the tool).
2. Native shutter: `MediaChannel.playShutter` (Kotlin) + `MediaController.shutter()` (Dart).
3. `PetScreen` photo overlay + `PhotoViewerScreen` full-screen viewer.

## Non-goals
- No burst/multi-photo, no in-app editing, no share sheet.
- No auto-dismiss timer (popup stays until closed).
- No change to when/why `take_photo` fires (still voice-driven, no confirmation).
- The photo is still saved to the gallery as today; the in-app path is only for
  the thumbnail/viewer.
