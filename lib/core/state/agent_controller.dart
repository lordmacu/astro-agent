import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';

/// What the agentic brain / voice layer is doing right now. Held separately
/// from the sensor streams and overlaid onto `AppState` so the resolver stays
/// pure and the brain/voice can drive the top of the mood cascade reactively.
class AgentStatus {
  const AgentStatus({this.phase = AgentPhase.idle, this.activeToolName});

  final AgentPhase phase;
  final String? activeToolName;
}

class AgentController extends Notifier<AgentStatus> {
  @override
  AgentStatus build() => const AgentStatus();

  void setPhase(AgentPhase phase) =>
      state = AgentStatus(phase: phase, activeToolName: state.activeToolName);

  void setTool(String? toolName) =>
      state = AgentStatus(phase: state.phase, activeToolName: toolName);

  void idle() => state = const AgentStatus();
}

final agentControllerProvider = NotifierProvider<AgentController, AgentStatus>(
  AgentController.new,
);
