import 'package:astro/core/state/mood.dart';
import 'package:astro/ui/astro_character.dart';
import 'package:astro/voice/viseme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('renders every mood without throwing', (tester) async {
    for (final mood in Mood.values) {
      await tester.pumpWidget(
        host(
          AstroCharacter(
            mood: MoodState(mood: mood),
            color: const Color(0xFF43D6CF),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(AstroCharacter), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders speaking (viseme) and navigation posture', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AstroCharacter(
          mood: const MoodState(
            mood: Mood.answering,
            gaze: TurnDirection.right,
            tilt: 0.6,
            turnImminent: true,
          ),
          color: const Color(0xFFF2A93B),
          viseme: Viseme.openWide,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('animates a mood change without throwing', (tester) async {
    await tester.pumpWidget(
      host(
        AstroCharacter(
          mood: const MoodState(mood: Mood.rest),
          color: Colors.teal,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Change mood + color: triggers the transition pop/glide.
    await tester.pumpWidget(
      host(
        AstroCharacter(
          mood: const MoodState(mood: Mood.alarm),
          color: Colors.red,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
