import 'package:chispa/core/config/thresholds.dart';
import 'package:chispa/core/state/app_state.dart';
import 'package:chispa/core/state/mood.dart';
import 'package:chispa/core/state/mood_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = MoodResolver(Thresholds());
  Mood moodOf(AppState s) => resolver.resolve(s).mood;

  group('cascade, single rule', () {
    test('idle and still-but-not-long is rest', () {
      expect(moodOf(const AppState()), Mood.rest);
    });

    test('thinking agent wins', () {
      expect(moodOf(const AppState(agentPhase: AgentPhase.thinking)),
          Mood.thinking);
    });

    test('answering agent', () {
      expect(moodOf(const AppState(agentPhase: AgentPhase.answering)),
          Mood.answering);
    });

    test('proximity is a caress', () {
      expect(moodOf(const AppState(proximityNear: true)), Mood.pet);
    });

    test('fault code is alarm', () {
      expect(moodOf(const AppState(dtcPresent: true)), Mood.alarm);
    });

    test('vertical spike is a bump', () {
      expect(moodOf(const AppState(verticalG: 0.9)), Mood.bump);
    });

    test('hard braking while moving is scared', () {
      expect(moodOf(const AppState(longitudinalG: -0.6, speedKmh: 50)),
          Mood.scared);
    });

    test('hard braking while stopped is not scared', () {
      expect(moodOf(const AppState(longitudinalG: -0.6, speedKmh: 5)),
          isNot(Mood.scared));
    });

    test('arrival', () {
      expect(moodOf(const AppState(arrived: true)), Mood.arrival);
    });

    test('high coolant temperature is worried', () {
      expect(moodOf(const AppState(coolantTempC: 120)), Mood.worried);
    });

    test('eager acceleration is excited', () {
      expect(moodOf(const AppState(longitudinalG: 0.6)), Mood.excited);
    });

    test('high rpm is excited', () {
      expect(moodOf(const AppState(rpm: 4000)), Mood.excited);
    });

    test('lateral g is a lean', () {
      expect(moodOf(const AppState(lateralG: 0.6, speedKmh: 30)), Mood.lean);
    });

    test('still for a while is sleep', () {
      expect(moodOf(const AppState(stillFor: Duration(seconds: 10))),
          Mood.sleep);
    });
  });

  group('priority ties (the bug-prone part)', () {
    test('agent beats a caress', () {
      expect(
        moodOf(const AppState(
            agentPhase: AgentPhase.thinking, proximityNear: true)),
        Mood.thinking,
      );
    });

    test('caress beats a fault code', () {
      expect(
        moodOf(const AppState(proximityNear: true, dtcPresent: true)),
        Mood.pet,
      );
    });

    test('fault code beats a bump', () {
      expect(
        moodOf(const AppState(dtcPresent: true, verticalG: 0.9)),
        Mood.alarm,
      );
    });

    test('bump beats hard braking', () {
      expect(
        moodOf(const AppState(
            verticalG: 0.9, longitudinalG: -0.6, speedKmh: 50)),
        Mood.bump,
      );
    });

    test('hard braking beats high temperature', () {
      expect(
        moodOf(const AppState(
            longitudinalG: -0.6, speedKmh: 50, coolantTempC: 120)),
        Mood.scared,
      );
    });

    test('acceleration beats a lean', () {
      expect(
        moodOf(const AppState(longitudinalG: 0.6, lateralG: 0.6)),
        Mood.excited,
      );
    });

    test('a lean beats sleep', () {
      expect(
        moodOf(const AppState(
            lateralG: 0.6, stillFor: Duration(seconds: 10))),
        Mood.lean,
      );
    });
  });

  group('gyroscope curves', () {
    test('a clear turn rate triggers the lean mood', () {
      expect(moodOf(const AppState(yawRate: 0.8)), Mood.lean);
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
      final state = resolver
          .resolve(const AppState(turnDirection: TurnDirection.left));
      expect(state.mood, Mood.rest);
      expect(state.gaze, TurnDirection.left);
    });

    test('a close turn is imminent', () {
      final state = resolver.resolve(
          const AppState(turnDirection: TurnDirection.right, turnDistanceM: 40));
      expect(state.turnImminent, isTrue);
    });

    test('a far turn is not imminent', () {
      final state = resolver.resolve(
          const AppState(turnDirection: TurnDirection.right, turnDistanceM: 300));
      expect(state.turnImminent, isFalse);
    });
  });
}
