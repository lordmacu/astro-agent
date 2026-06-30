import 'dart:async';

import 'package:chispa/brain/chispa_brain.dart';
import 'package:chispa/brain/llm/llm_client.dart';
import 'package:chispa/brain/llm/llm_message.dart';
import 'package:chispa/brain/tools/tool_registry.dart';
import 'package:chispa/voice/voice_interfaces.dart';
import 'package:chispa/voice/voice_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRecognizer implements SpeechRecognizer {
  FakeRecognizer(this.utterance);
  final String? utterance;
  @override
  Future<String?> listen() async => utterance;
  @override
  Future<void> stop() async {}
}

class FakeTts implements TextToSpeech {
  final List<String> spoken = [];
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

class FakeWakeWord implements WakeWordDetector {
  final _controller = StreamController<void>.broadcast();
  @override
  Stream<void> get onWake => _controller.stream;
  void trigger() => _controller.add(null);
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
}

class FixedLlmClient implements LlmClient {
  FixedLlmClient(this.reply);
  final String reply;
  @override
  String get providerId => 'fake';
  @override
  Future<LlmResponse> complete(LlmRequest request) async => LlmResponse(
    message: LlmMessage.text(Role.assistant, reply),
    stopReason: StopReason.endTurn,
  );
}

ChispaBrain _brain(String reply) =>
    ChispaBrain(client: FixedLlmClient(reply), registry: ToolRegistry());

void main() {
  test('runOnce: listen, ask the brain, speak, with phases in order', () async {
    final tts = FakeTts();
    final phases = <VoicePhase>[];
    final pipeline = VoicePipeline(
      recognizer: FakeRecognizer('how is the weather'),
      tts: tts,
      brain: _brain('It is sunny.'),
      model: 'm',
      onPhase: phases.add,
    );

    final answer = await pipeline.runOnce();

    expect(answer, 'It is sunny.');
    expect(tts.spoken, ['It is sunny.']);
    expect(phases, [
      VoicePhase.listening,
      VoicePhase.thinking,
      VoicePhase.speaking,
      VoicePhase.idle,
    ]);
  });

  test('runOnce: nothing heard returns null and never speaks', () async {
    final tts = FakeTts();
    final phases = <VoicePhase>[];
    final pipeline = VoicePipeline(
      recognizer: FakeRecognizer(null),
      tts: tts,
      brain: _brain('unused'),
      model: 'm',
      onPhase: phases.add,
    );

    expect(await pipeline.runOnce(), isNull);
    expect(tts.spoken, isEmpty);
    expect(phases, [VoicePhase.listening, VoicePhase.idle]);
  });

  test('awaitWakeThenRun runs after the wake word fires', () async {
    final wake = FakeWakeWord();
    final tts = FakeTts();
    final pipeline = VoicePipeline(
      recognizer: FakeRecognizer('hi'),
      tts: tts,
      brain: _brain('Hello!'),
      model: 'm',
      wakeWord: wake,
    );

    final run = pipeline.awaitWakeThenRun();
    wake.trigger();

    expect(await run, 'Hello!');
    expect(tts.spoken, ['Hello!']);
  });

  test('awaitWakeThenRun without a detector throws', () {
    final pipeline = VoicePipeline(
      recognizer: FakeRecognizer('hi'),
      tts: FakeTts(),
      brain: _brain('x'),
      model: 'm',
    );
    expect(pipeline.awaitWakeThenRun(), throwsA(isA<StateError>()));
  });
}
