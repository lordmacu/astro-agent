import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/ui/command_palette.dart';

void main() {
  testWidgets('renders a button per command and reports taps', (tester) async {
    final tapped = <String>[];
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPalette(
            commands: const ['¿Qué hora es?', 'Pon música'],
            onCommand: tapped.add,
            onClose: () => closed++,
            lang: AppLang.es,
          ),
        ),
      ),
    );

    expect(
      find.widgetWithText(ElevatedButton, '¿Qué hora es?'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Pon música'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Pon música'));
    await tester.pump();
    expect(tapped, ['Pon música']);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(closed, 1);
  });

  testWidgets('shows a News button only when onNews is set and reports taps', (
    tester,
  ) async {
    var news = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPalette(
            commands: const ['¿Qué hora es?'],
            onCommand: (_) {},
            onClose: () {},
            lang: AppLang.es,
            onNews: () => news++,
          ),
        ),
      ),
    );

    final newsButton = find.text('Noticias');
    expect(newsButton, findsOneWidget);
    await tester.tap(newsButton);
    await tester.pump();
    expect(news, 1);
  });

  testWidgets('no News button when onNews is omitted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandPalette(
            commands: const ['¿Qué hora es?'],
            onCommand: (_) {},
            onClose: () {},
            lang: AppLang.es,
          ),
        ),
      ),
    );
    expect(find.text('Noticias'), findsNothing);
  });
}
