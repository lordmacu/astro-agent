import 'package:astro/app.dart';
import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/state/app_mode.dart';
import 'package:astro/core/state/app_state.dart';
import 'package:astro/core/state/app_state_provider.dart';
import 'package:astro/ui/astro_character.dart';
import 'package:astro/voice/stt_provider.dart';
import 'package:astro/voice/voice_interfaces.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Car mode so the dashboard HUD (speedometer, km/h) renders. The resting mood
/// still resolves from the emitted AppState below.
class _CarModeNotifier extends AppModeNotifier {
  @override
  AppMode build() => AppMode.car;
}

/// No-op recognizer so PetScreen.initState doesn't build the real platform
/// recognizer (Vosk), which throws UnsupportedError in the test VM.
class _FakeRecognizer implements SpeechRecognizer {
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
  testWidgets('renders the resting mood on launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appModeProvider.overrideWith(_CarModeNotifier.new),
          speechRecognizerProvider.overrideWithValue(_FakeRecognizer()),
          // No real sensors in tests; emit a single resting state.
          appStateProvider.overrideWith(
            (ref) => Stream.value(const AppState()),
          ),
        ],
        child: const AstroApp(),
      ),
    );
    await tester.pump();

    // HUD renders with the speedometer unit, and the resting mood shows Astro.
    expect(find.text('km/h'), findsOneWidget);
    expect(find.byType(AstroCharacter), findsOneWidget);
  });
}
