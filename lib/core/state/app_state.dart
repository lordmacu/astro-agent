import 'package:freezed_annotation/freezed_annotation.dart';

import 'mood.dart';

part 'app_state.freezed.dart';

/// What the agentic brain is doing right now. Highest priority in the cascade.
/// `surprised` is the brief startle when Astro is summoned (wake word or tap),
/// before it starts listening.
enum AgentPhase { idle, surprised, thinking, answering }

/// The single immutable snapshot that every data source feeds into. Sensor
/// services produce streams; `appStateProvider` combines them into this object.
/// Optional sources (OBD, navigation) are nullable so the basics work without
/// any extra hardware. Mood is never decided here — only in `MoodResolver`.
@freezed
class AppState with _$AppState {
  const factory AppState({
    // --- Agentic brain (priority 1) ---
    @Default(AgentPhase.idle) AgentPhase agentPhase,
    String? activeToolName,

    // --- Mode: true only in car mode. Gates the speed sensor and every
    // driving reaction; false (normal mode) collapses the cascade to the
    // universal moods (agent, caress, sleep, rest). ---
    @Default(false) bool carMode,

    // --- Proximity / caress (priority 2) ---
    @Default(false) bool proximityNear,

    // --- OBD (optional; null when no adapter is connected) ---
    bool? dtcPresent,
    double? coolantTempC,
    double? rpm,

    // --- Phone motion sensors (always available, already low-pass filtered) ---
    /// Longitudinal g: positive accelerating, negative braking.
    @Default(0.0) double longitudinalG,

    /// Vertical g spike, used to detect bumps.
    @Default(0.0) double verticalG,

    /// Lateral g, used to detect curves.
    @Default(0.0) double lateralG,

    /// Turn rate about the vertical axis (rad/s) from the gyroscope. Drives the
    /// continuous lean into curves.
    @Default(0.0) double yawRate,

    // --- Speed (GPS, fused with the accelerometer between fixes) ---
    @Default(0.0) double speedKmh,

    // --- Navigation (optional) ---
    @Default(false) bool arrived,
    @Default(TurnDirection.none) TurnDirection turnDirection,
    double? turnDistanceM,

    // --- Stillness ---
    @Default(Duration.zero) Duration stillFor,

    // --- Ambient light ---
    @Default(12000.0) double lux,
  }) = _AppState;
}
