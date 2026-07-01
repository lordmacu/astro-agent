import 'dart:io';
import 'dart:ui' as ui;

import 'package:astro/core/config/design_tokens.dart';
import 'package:astro/core/state/mood.dart';
import 'package:astro/ui/astro_character.dart';
import 'package:astro/voice/viseme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Not a real test — a harness to render Astro to PNGs for visual review.
/// Run: flutter test test/render_preview.dart
/// Note: fonts don't load in the test env, so text glyphs (♥, z, !) and labels
/// render as boxes; the character shapes themselves are accurate.
void main() {
  const out =
      '/private/tmp/claude-501/-Users-cristian-aipet/e2befe2d-80d5-4ae6-8a2d-98c7b98ab1fe/scratchpad';

  Widget cell(String name, MoodState state, {Viseme? viseme}) {
    final color = DesignTokens.moodColor[state.mood] ?? DesignTokens.accent;
    return SizedBox(
      width: 150,
      height: 168,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AstroCharacter(mood: state, color: color, viseme: viseme, size: 130),
          const SizedBox(height: 2),
          Text(
            name,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  testWidgets('render mood grid', (tester) async {
    tester.view.physicalSize = const Size(960, 900);
    tester.view.devicePixelRatio = 1;

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF101B2C),
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final mood in Mood.values)
                  cell(mood.name, MoodState(mood: mood)),
                cell(
                  'speaking',
                  const MoodState(mood: Mood.answering),
                  viseme: Viseme.openWide,
                ),
                cell(
                  'turn→',
                  const MoodState(
                    mood: Mood.rest,
                    gaze: TurnDirection.right,
                    turnImminent: true,
                  ),
                ),
                cell('lean', const MoodState(mood: Mood.lean, tilt: 0.85)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/astro_grid.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    addTearDown(tester.view.resetPhysicalSize);
  });
}
