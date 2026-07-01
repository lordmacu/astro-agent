import 'package:astro/core/state/agent_controller.dart';
import 'package:astro/core/state/app_state.dart';
import 'package:astro/core/state/app_state_provider.dart';
import 'package:astro/core/state/mood.dart';
import 'package:astro/voice/voice_controller.dart';
import 'package:astro/voice/voice_pipeline.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        // No real sensors in tests; emit a single resting state.
        appStateProvider.overrideWith((ref) => Stream.value(const AppState())),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('agentPhaseFor', () {
    test('maps voice phases to agent phases', () {
      expect(agentPhaseFor(VoicePhase.thinking), AgentPhase.thinking);
      expect(agentPhaseFor(VoicePhase.speaking), AgentPhase.answering);
      expect(agentPhaseFor(VoicePhase.listening), AgentPhase.idle);
      expect(agentPhaseFor(VoicePhase.idle), AgentPhase.idle);
    });
  });

  group('agent phase overlay on mood', () {
    test('thinking overrides the resting sensor state', () {
      final c = makeContainer();
      expect(c.read(moodStateProvider).mood, Mood.rest);

      c.read(agentControllerProvider.notifier).setPhase(AgentPhase.thinking);

      expect(c.read(moodStateProvider).mood, Mood.thinking);
    });

    test('idle restores the underlying mood', () {
      final c = makeContainer();
      c.read(agentControllerProvider.notifier).setPhase(AgentPhase.answering);
      expect(c.read(moodStateProvider).mood, Mood.answering);

      c.read(agentControllerProvider.notifier).idle();
      expect(c.read(moodStateProvider).mood, Mood.rest);
    });
  });

  group('summon surprise', () {
    test('surprise sets the surprised mood', () {
      final c = makeContainer();
      expect(c.read(moodStateProvider).mood, Mood.rest);

      c.read(voiceControllerProvider.notifier).surprise();
      expect(c.read(moodStateProvider).mood, Mood.surprised);
    });
  });

  group('touch petting drives the caress', () {
    test('petting makes the mood pet, and releasing restores it', () {
      final c = makeContainer();
      expect(c.read(moodStateProvider).mood, Mood.rest);

      c.read(pettingProvider.notifier).state = true;
      expect(c.read(moodStateProvider).mood, Mood.pet);

      c.read(pettingProvider.notifier).state = false;
      expect(c.read(moodStateProvider).mood, Mood.rest);
    });
  });

  group('VoiceController', () {
    test('speaking sets answering mood and exposes a mouth shape', () {
      final c = makeContainer();
      c.read(voiceControllerProvider.notifier).applyPhase(VoicePhase.speaking);

      expect(c.read(voiceControllerProvider).phase, VoicePhase.speaking);
      expect(c.read(voiceControllerProvider).viseme, isNotNull);
      expect(c.read(moodStateProvider).mood, Mood.answering);
    });

    test('tickViseme advances the mouth only while speaking', () {
      final c = makeContainer();
      final controller = c.read(voiceControllerProvider.notifier);

      // Not speaking: tick is a no-op.
      controller.tickViseme();
      expect(c.read(voiceControllerProvider).viseme, isNull);

      controller.applyPhase(VoicePhase.speaking);
      final first = c.read(voiceControllerProvider).viseme;
      controller.tickViseme();
      final second = c.read(voiceControllerProvider).viseme;
      expect(second, isNot(first));
    });

    test('leaving speaking clears the mouth and idles the agent', () {
      final c = makeContainer();
      final controller = c.read(voiceControllerProvider.notifier);

      controller.applyPhase(VoicePhase.speaking);
      controller.applyPhase(VoicePhase.idle);

      expect(c.read(voiceControllerProvider).viseme, isNull);
      expect(c.read(moodStateProvider).mood, Mood.rest);
    });
  });
}
