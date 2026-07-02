import 'dart:async';

import 'package:astro/core/config/settings_providers.dart';
import 'package:astro/core/state/app_state.dart';
import 'package:astro/core/state/app_state_provider.dart';
import 'package:astro/ui/pet_screen.dart';
import 'package:astro/voice/stt_provider.dart';
import 'package:astro/voice/voice_interfaces.dart';
import 'package:astro/voice/wake_word_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWake implements WakeWordDetector {
  final _wakes = StreamController<void>.broadcast();
  @override
  Stream<void> get onWake => _wakes.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> setKeyword(String keyword) async {}
  @override
  Future<void> setSensitivity(double value) async {}
}

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
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('astro/notifications'),
          (call) async => call.method == 'getRecent' ? const [] : null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('astro/notifications'),
          null,
        );
  });

  testWidgets('bell opens the notifications sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          wakeWordProvider.overrideWithValue(_FakeWake()),
          speechRecognizerProvider.overrideWithValue(_FakeRecognizer()),
          appStateProvider.overrideWith(
            (ref) => Stream.value(const AppState()),
          ),
        ],
        child: const MaterialApp(home: PetScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('notifications-button')));
    // PetScreen keeps background timers alive (heartbeat, badge refresh),
    // so pumpAndSettle never quiesces; pump the modal's open animation and
    // its async load explicitly instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // The sheet title appears (empty buffer → "Nada nuevo" also shows).
    expect(find.text('Notifications'), findsOneWidget);
  });
}
