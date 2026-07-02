import 'package:astro/brain/tools/news/google_news_provider.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/lang_provider.dart';
import 'package:astro/ui/news_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists headlines and opens one in the browser on tap', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceLangProvider.overrideWithValue(AppLang.es)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showNewsSheet(
                  context,
                  headlines: const [
                    NewsHeadline(
                      title: 'Titular A',
                      source: 'El Tiempo',
                      url: 'https://example.com/a',
                    ),
                  ],
                  launch: (uri) async {
                    opened.add(uri);
                    return true;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Headline + source are shown.
    expect(find.text('Titular A'), findsOneWidget);
    expect(find.text('El Tiempo'), findsOneWidget);

    // Tapping the headline launches its URL in the (injected) browser.
    await tester.tap(find.text('Titular A'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'https://example.com/a');
  });
}
