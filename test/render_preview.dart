import 'dart:io';
import 'dart:ui' as ui;

import 'package:chispa/core/config/design_tokens.dart';
import 'package:chispa/core/state/mood.dart';
import 'package:chispa/ui/chispa_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Not a real test — a tiny harness to render Chispa to PNGs for visual review.
/// Run: flutter test test/render_preview.dart
void main() {
  const out =
      '/private/tmp/claude-501/-Users-cristian-aipet/e2befe2d-80d5-4ae6-8a2d-98c7b98ab1fe/scratchpad';

  final moods = {
    'rest': Mood.rest,
    'excited': Mood.excited,
    'scared': Mood.scared,
    'pet': Mood.pet,
    'thinking': Mood.thinking,
    'sleep': Mood.sleep,
  };

  // A leaning frame (gyroscope curve) to preview the postural tilt.
  testWidgets('render lean', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFF101B2C),
          child: Center(
            child: ChispaCharacter(
              mood: const MoodState(mood: Mood.lean, tilt: 0.85),
              color: DesignTokens.accent,
              size: 260,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 125));
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/chispa_lean.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  moods.forEach((name, mood) {
    testWidgets('render $name', (tester) async {
      final key = GlobalKey();
      final color = DesignTokens.moodColor[mood] ?? DesignTokens.accent;

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF101B2C),
            child: Center(
              child: ChispaCharacter(
                mood: MoodState(mood: mood),
                color: color,
                size: 260,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 125));

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/chispa_$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  });
}
