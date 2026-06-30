import 'dart:async';

import 'package:chispa/core/state/app_state.dart';
import 'package:chispa/core/state/app_state_provider.dart';
import 'package:chispa/ui/pet_screen.dart';
import 'package:chispa/voice/voice_interfaces.dart';
import 'package:chispa/voice/wake_word_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

void main() {
  testWidgets('starts the wake detector from the provider', (tester) async {
    final fake = FakeWake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wakeWordProvider.overrideWithValue(fake),
          appStateProvider.overrideWith(
            (ref) => Stream.value(const AppState()),
          ),
        ],
        child: const MaterialApp(home: PetScreen()),
      ),
    );
    await tester.pump();

    expect(fake.calls, contains('start'));
  });
}
