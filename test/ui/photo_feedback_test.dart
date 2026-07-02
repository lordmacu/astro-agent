import 'dart:async';

import 'package:astro/core/state/app_state.dart';
import 'package:astro/core/state/app_state_provider.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:astro/platform/permissions.dart';
import 'package:astro/ui/pet_screen.dart';
import 'package:astro/ui/photo_viewer_screen.dart';
import 'package:astro/voice/stt_provider.dart';
import 'package:astro/voice/voice_interfaces.dart';
import 'package:astro/voice/wake_word_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records lifecycle calls; exposes a controllable wake stream.
class FakeWake implements WakeWordDetector {
  final calls = <String>[];
  final _wakes = StreamController<void>.broadcast();
  void fire() => _wakes.add(null);
  @override
  Stream<void> get onWake => _wakes.stream;
  @override
  Future<void> start() async => calls.add('start');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> setKeyword(String keyword) async =>
      calls.add('keyword:$keyword');
  @override
  Future<void> setSensitivity(double value) async => calls.add('sens:$value');
}

/// No-op permissions so initState doesn't hit the real permission_handler
/// plugin (which would leave a pending timer in the test VM).
class NoPermissions extends Permissions {
  const NoPermissions();
  @override
  Future<void> requestStartup() async {}
}

/// No-op recognizer so PetScreen.initState doesn't build the real platform
/// recognizer (Vosk), which throws UnsupportedError in the test VM.
class FakeRecognizer implements SpeechRecognizer {
  @override
  Future<String?> listen({Duration? pauseFor, bool shortReply = false}) async =>
      null;
  @override
  Future<void> stop() async {}
  @override
  Future<bool> warmUp() async => true;
  @override
  set onListening(void Function()? cb) {}
}

void main() {
  testWidgets('PhotoViewerScreen shows the image in an InteractiveViewer', (
    tester,
  ) async {
    // A path that need not exist on disk; Image.file renders an errorBuilder
    // rather than throwing, so the widget tree is still valid.
    await tester.pumpWidget(
      const MaterialApp(
        home: PhotoViewerScreen(path: '/tmp/nonexistent_astro.jpg'),
      ),
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('photo overlay shows thumbnail + Ver/Cerrar; Cerrar clears', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fake = FakeWake();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLangProvider.overrideWithValue(AppLang.es),
          wakeWordProvider.overrideWithValue(fake),
          speechRecognizerProvider.overrideWithValue(FakeRecognizer()),
          permissionsProvider.overrideWithValue(const NoPermissions()),
          appStateProvider.overrideWith(
            (ref) => Stream.value(const AppState()),
          ),
          capturedPhotoProvider.overrideWith((ref) => '/tmp/fake_photo.jpg'),
        ],
        child: const MaterialApp(home: PetScreen()),
      ),
    );
    await tester.pump();

    // The overlay should be visible with Ver and Cerrar buttons.
    expect(find.text('Ver'), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);

    // Tap Cerrar — it sets capturedPhotoProvider to null, hiding the overlay.
    await tester.tap(find.text('Cerrar'));
    await tester.pump();

    expect(find.text('Cerrar'), findsNothing);
  });
}
