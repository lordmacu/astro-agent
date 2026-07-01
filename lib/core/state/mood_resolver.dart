import '../config/thresholds.dart';
import 'app_state.dart';
import 'mood.dart';
import 'speech_line.dart';

/// Pure function: `AppState` -> a single `MoodState`.
///
/// This is the heart of Astro's behaviour and the single place a mood is
/// decided. The mood is chosen by a strict priority cascade; the navigation
/// posture (gaze/tilt toward the next turn) is layered on top and never
/// competes with the mood.
class MoodResolver {
  const MoodResolver(this.t);

  final Thresholds t;

  MoodState resolve(AppState s) {
    final mood = _mood(s);
    return MoodState(
      mood: mood,
      gaze: s.turnDirection,
      tilt: _tilt(s),
      turnImminent: _turnImminent(s),
      line: _line(mood),
    );
  }

  /// The priority cascade, highest to lowest. The first matching rule wins.
  Mood _mood(AppState s) {
    // 1. Agentic brain (surprise on being summoned tops everything).
    if (s.agentPhase == AgentPhase.surprised) return Mood.surprised;
    if (s.agentPhase == AgentPhase.thinking) return Mood.thinking;
    if (s.agentPhase == AgentPhase.answering) return Mood.answering;

    // 2. Caress.
    if (s.proximityNear) return Mood.pet;

    // Normal mode: skip every driving reaction below. Astro is a desk / handheld
    // companion, so it only sleeps, rests, and reacts to caress and the brain.
    if (!s.carMode) {
      if (s.stillFor >= t.sleepAfter) return Mood.sleep;
      return Mood.rest;
    }

    // 3. Active fault code.
    if (s.dtcPresent == true) return Mood.alarm;

    // 4. Bump (brief vertical spike, high salience).
    if (s.verticalG.abs() > t.bumpG) return Mood.bump;

    // 5. Hard braking while moving.
    if (s.longitudinalG < t.brakeG && s.speedKmh > t.brakeSpeedKmh) {
      return Mood.scared;
    }

    // 6. Arrival at destination.
    if (s.arrived) return Mood.arrival;

    // 7. High engine temperature.
    if (s.coolantTempC != null && s.coolantTempC! > t.coolantHighC) {
      return Mood.worried;
    }

    // 8. Eager acceleration / high revs.
    if (s.longitudinalG > t.accelG || (s.rpm != null && s.rpm! > t.rpmHigh)) {
      return Mood.excited;
    }

    // 9. Curve (lateral g and/or a clear turn rate from the gyroscope).
    if (s.lateralG.abs() > t.leanG || s.yawRate.abs() > t.turnRateLean) {
      return Mood.lean;
    }

    // 10. Still for a while.
    if (s.stillFor >= t.sleepAfter) return Mood.sleep;

    // 11. Resting.
    return Mood.rest;
  }

  /// Continuous postural lean, driven by the gyroscope turn rate (the body
  /// leans into the curve every frame, not only when `lean` wins the cascade).
  double _tilt(AppState s) =>
      (s.yawRate * t.tiltPerYaw).clamp(-1.0, 1.0).toDouble();

  bool _turnImminent(AppState s) {
    final d = s.turnDistanceM;
    return d != null && d <= t.turnImminentM;
  }

  /// Maps a mood to the line Astro says, or null to stay quiet. The actual
  /// EN/ES text comes from `SpeechCatalog`.
  SpeechLine? _line(Mood mood) {
    switch (mood) {
      case Mood.excited:
        return SpeechLine.letsGo;
      case Mood.scared:
        return SpeechLine.holdOn;
      case Mood.bump:
        return SpeechLine.bump;
      case Mood.lean:
        return SpeechLine.curve;
      case Mood.worried:
        return SpeechLine.engineWarm;
      case Mood.alarm:
        return SpeechLine.faultCode;
      case Mood.arrival:
        return SpeechLine.arrived;
      case Mood.sleep:
      case Mood.surprised:
      case Mood.thinking:
      case Mood.answering:
      case Mood.pet:
      case Mood.rest:
        return null;
    }
  }
}
