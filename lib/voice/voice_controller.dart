import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state/agent_controller.dart';
import '../core/state/app_state.dart';
import 'viseme.dart';
import 'voice_pipeline.dart';

/// Map a coarse voice phase to the agent phase that drives the mood cascade.
AgentPhase agentPhaseFor(VoicePhase phase) => switch (phase) {
      VoicePhase.thinking => AgentPhase.thinking,
      VoicePhase.speaking => AgentPhase.answering,
      VoicePhase.listening || VoicePhase.idle => AgentPhase.idle,
    };

/// What the UI needs from the voice layer: the current phase and, while
/// speaking, the active mouth shape.
class VoiceUiState {
  const VoiceUiState({this.phase = VoicePhase.idle, this.viseme});

  final VoicePhase phase;
  final Viseme? viseme;
}

/// Bridges the voice pipeline to the reactive state: pushes the agent phase to
/// `AgentController` (which the mood cascade reads) and produces mouth shapes
/// while speaking. Wire it as the pipeline's `onPhase` callback; drive
/// [tickViseme] from a timer in the app while the phase is `speaking`.
class VoiceController extends Notifier<VoiceUiState> {
  late VisemeSequencer _visemes;

  @override
  VoiceUiState build() {
    _visemes = VisemeSequencer();
    return const VoiceUiState();
  }

  /// Apply a phase emitted by the voice pipeline.
  void applyPhase(VoicePhase phase) {
    ref.read(agentControllerProvider.notifier).setPhase(agentPhaseFor(phase));

    if (phase == VoicePhase.speaking) {
      state = VoiceUiState(phase: phase, viseme: _visemes.current);
    } else {
      _visemes.reset();
      state = VoiceUiState(phase: phase);
    }
  }

  /// Advance the mouth to the next shape. No-op unless currently speaking.
  void tickViseme() {
    if (state.phase != VoicePhase.speaking) return;
    state = VoiceUiState(phase: state.phase, viseme: _visemes.next());
  }
}

final voiceControllerProvider =
    NotifierProvider<VoiceController, VoiceUiState>(VoiceController.new);
