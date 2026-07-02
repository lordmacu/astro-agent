import 'package:freezed_annotation/freezed_annotation.dart';

import 'speech_line.dart';

part 'mood.freezed.dart';

/// The single resolved mood for Astro, produced by `MoodResolver` from the
/// combined `AppState`. Exactly one mood is active at a time; the navigation
/// posture is layered on top via `MoodState` and never competes in the cascade.
enum Mood {
  rest,
  excited,
  scared,
  worried,
  alarm,
  sleep,
  arrival,
  lean,
  bump,
  pet,
  dizzy,
  surprised,
  thinking,
  answering,
}

/// Direction of an upcoming maneuver, used by the navigation posture layer.
enum TurnDirection { none, left, right }

/// The output of the resolver: one mood plus the navigation posture overlay
/// (gaze/tilt toward the turn) and the line Astro should say. All speech is
/// English; Spanish, if ever wanted, goes through localization.
@freezed
class MoodState with _$MoodState {
  const factory MoodState({
    required Mood mood,

    /// Where Astro looks: toward the side of the upcoming turn.
    @Default(TurnDirection.none) TurnDirection gaze,

    /// Body lean in the range -1..1 (negative left, positive right).
    @Default(0.0) double tilt,

    /// True when the next maneuver is close enough to heighten attention.
    @Default(false) bool turnImminent,

    /// Semantic line to say (rendered to EN/ES by `SpeechCatalog`), or null to
    /// stay quiet.
    SpeechLine? line,
  }) = _MoodState;
}
