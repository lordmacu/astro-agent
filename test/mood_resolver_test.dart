import 'package:astro/core/config/thresholds.dart';
import 'package:astro/core/state/app_state.dart';
import 'package:astro/core/state/mood.dart';
import 'package:astro/core/state/mood_resolver.dart';
import 'package:astro/core/state/speech_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = MoodResolver(Thresholds());
  Mood moodOf(AppState s) => resolver.resolve(s).mood;

  // Driving reactions only fire in car mode; this stamps carMode on the inputs
  // so the "single rule" and "priority" tests read the car cascade.
  Mood carMoodOf(AppState s) =>
      resolver.resolve(s.copyWith(carMode: true)).mood;

  group('cascade, single rule (car mode)', () {
    test('idle and still-but-not-long is rest', () {
      expect(carMoodOf(const AppState()), Mood.rest);
    });

    test('thinking agent wins', () {
      expect(
        carMoodOf(const AppState(agentPhase: AgentPhase.thinking)),
        Mood.thinking,
      );
    });

    test('answering agent', () {
      expect(
        carMoodOf(const AppState(agentPhase: AgentPhase.answering)),
        Mood.answering,
      );
    });

    test('proximity is a caress', () {
      expect(carMoodOf(const AppState(proximityNear: true)), Mood.pet);
    });

    test('fault code is alarm', () {
      expect(carMoodOf(const AppState(dtcPresent: true)), Mood.alarm);
    });

    test('vertical spike is a bump', () {
      expect(carMoodOf(const AppState(verticalG: 0.9)), Mood.bump);
    });

    test('hard braking while moving is scared', () {
      expect(
        carMoodOf(const AppState(longitudinalG: -0.6, speedKmh: 50)),
        Mood.scared,
      );
    });

    test('hard braking while stopped is not scared', () {
      expect(
        carMoodOf(const AppState(longitudinalG: -0.6, speedKmh: 5)),
        isNot(Mood.scared),
      );
    });

    test('arrival', () {
      expect(carMoodOf(const AppState(arrived: true)), Mood.arrival);
    });

    test('high coolant temperature is worried', () {
      expect(carMoodOf(const AppState(coolantTempC: 120)), Mood.worried);
    });

    test('eager acceleration is excited', () {
      expect(carMoodOf(const AppState(longitudinalG: 0.6)), Mood.excited);
    });

    test('high rpm is excited', () {
      expect(carMoodOf(const AppState(rpm: 4000)), Mood.excited);
    });

    test('lateral g is a lean', () {
      expect(carMoodOf(const AppState(lateralG: 0.6, speedKmh: 30)), Mood.lean);
    });

    test('still for a while is sleep', () {
      expect(
        carMoodOf(const AppState(stillFor: Duration(seconds: 10))),
        Mood.sleep,
      );
    });
  });

  group('normal mode gates driving reactions', () {
    test('a bump does not fire in normal mode', () {
      expect(moodOf(const AppState(verticalG: 0.9)), Mood.rest);
    });

    test('hard braking does not scare in normal mode', () {
      expect(
        moodOf(const AppState(longitudinalG: -0.6, speedKmh: 50)),
        Mood.rest,
      );
    });

    test('acceleration does not excite in normal mode', () {
      expect(moodOf(const AppState(longitudinalG: 0.6)), Mood.rest);
    });

    test('a curve does not lean the mood in normal mode', () {
      expect(moodOf(const AppState(yawRate: 0.8)), Mood.rest);
    });

    test('a fault code does not alarm in normal mode', () {
      expect(moodOf(const AppState(dtcPresent: true)), Mood.rest);
    });

    test('caress still works in normal mode', () {
      expect(moodOf(const AppState(proximityNear: true)), Mood.pet);
    });

    test('the brain still drives the mood in normal mode', () {
      expect(
        moodOf(const AppState(agentPhase: AgentPhase.thinking)),
        Mood.thinking,
      );
    });

    test('stillness still sleeps in normal mode', () {
      expect(
        moodOf(const AppState(stillFor: Duration(seconds: 10))),
        Mood.sleep,
      );
    });

    test('a curve still leans the body posture in normal mode', () {
      // The mood is gated, but the continuous gyroscope lean is universal.
      const t = Thresholds();
      final state = resolver.resolve(const AppState(yawRate: 0.5));
      expect(state.mood, Mood.rest);
      expect(state.tilt, closeTo((0.5 * t.tiltPerYaw).clamp(-1.0, 1.0), 1e-9));
    });
  });

  group('surprise (summon reaction) tops the cascade', () {
    test('surprised agent phase wins', () {
      expect(
        moodOf(const AppState(agentPhase: AgentPhase.surprised)),
        Mood.surprised,
      );
    });

    test('surprise beats a caress', () {
      expect(
        moodOf(
          const AppState(agentPhase: AgentPhase.surprised, proximityNear: true),
        ),
        Mood.surprised,
      );
    });

    test('surprise fires in normal mode too (it is above the car gate)', () {
      // Default AppState is normal mode (carMode false); surprise still wins.
      expect(
        moodOf(const AppState(agentPhase: AgentPhase.surprised)),
        Mood.surprised,
      );
    });
  });

  group('priority ties (the bug-prone part, car mode)', () {
    test('agent beats a caress', () {
      expect(
        carMoodOf(
          const AppState(agentPhase: AgentPhase.thinking, proximityNear: true),
        ),
        Mood.thinking,
      );
    });

    test('caress beats a fault code', () {
      expect(
        carMoodOf(const AppState(proximityNear: true, dtcPresent: true)),
        Mood.pet,
      );
    });

    test('fault code beats a bump', () {
      expect(
        carMoodOf(const AppState(dtcPresent: true, verticalG: 0.9)),
        Mood.alarm,
      );
    });

    test('bump beats hard braking', () {
      expect(
        carMoodOf(
          const AppState(verticalG: 0.9, longitudinalG: -0.6, speedKmh: 50),
        ),
        Mood.bump,
      );
    });

    test('hard braking beats high temperature', () {
      expect(
        carMoodOf(
          const AppState(longitudinalG: -0.6, speedKmh: 50, coolantTempC: 120),
        ),
        Mood.scared,
      );
    });

    test('acceleration beats a lean', () {
      expect(
        carMoodOf(const AppState(longitudinalG: 0.6, lateralG: 0.6)),
        Mood.excited,
      );
    });

    test('a lean beats sleep', () {
      expect(
        carMoodOf(
          const AppState(lateralG: 0.6, stillFor: Duration(seconds: 10)),
        ),
        Mood.lean,
      );
    });
  });

  group('gyroscope curves (car mode)', () {
    test('a clear turn rate triggers the lean mood', () {
      expect(carMoodOf(const AppState(yawRate: 0.8)), Mood.lean);
    });

    test('yaw rate produces a continuous lean, even at rest', () {
      const t = Thresholds();
      final state = resolver.resolve(const AppState(yawRate: 0.5));
      expect(state.tilt, closeTo((0.5 * t.tiltPerYaw).clamp(-1.0, 1.0), 1e-9));
    });

    test('opposite turn directions lean opposite ways', () {
      final left = resolver.resolve(const AppState(yawRate: -0.4)).tilt;
      final right = resolver.resolve(const AppState(yawRate: 0.4)).tilt;
      expect(left, lessThan(0));
      expect(right, greaterThan(0));
    });

    test('no turn means no lean', () {
      expect(resolver.resolve(const AppState()).tilt, 0);
    });
  });

  group('navigation posture is layered, not a mood', () {
    test('turn direction sets gaze without changing the mood', () {
      final state = resolver.resolve(
        const AppState(turnDirection: TurnDirection.left),
      );
      expect(state.mood, Mood.rest);
      expect(state.gaze, TurnDirection.left);
    });

    test('a close turn is imminent', () {
      final state = resolver.resolve(
        const AppState(turnDirection: TurnDirection.right, turnDistanceM: 40),
      );
      expect(state.turnImminent, isTrue);
    });

    test('a far turn is not imminent', () {
      final state = resolver.resolve(
        const AppState(turnDirection: TurnDirection.right, turnDistanceM: 300),
      );
      expect(state.turnImminent, isFalse);
    });
  });

  group('shake makes Astro dizzy (just for fun)', () {
    test('shaking is dizzy in normal mode', () {
      expect(moodOf(const AppState(shaking: true)), Mood.dizzy);
    });

    test('shaking is dizzy in car mode too', () {
      expect(carMoodOf(const AppState(shaking: true)), Mood.dizzy);
    });

    test('the brain still tops a shake (no cutting off a reply)', () {
      expect(
        moodOf(const AppState(shaking: true, agentPhase: AgentPhase.answering)),
        Mood.answering,
      );
    });

    test('a shake beats a caress and driving reactions', () {
      expect(
        carMoodOf(const AppState(shaking: true, proximityNear: true)),
        Mood.dizzy,
      );
      expect(
        carMoodOf(const AppState(shaking: true, verticalG: 0.9)),
        Mood.dizzy,
      );
    });

    test('the dizzy mood says the dizzy line', () {
      final state = resolver.resolve(const AppState(shaking: true));
      expect(state.line, SpeechLine.dizzy);
    });
  });
}
