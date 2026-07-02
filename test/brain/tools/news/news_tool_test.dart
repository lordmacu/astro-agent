import 'package:astro/brain/tools/news/google_news_provider.dart';
import 'package:astro/brain/tools/news/news_tool.dart';
import 'package:astro/core/l10n/app_lang.dart';
import 'package:astro/core/l10n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is read-only and named noticias', () {
    final tool = NewsTool(fetch: (q, l) async => const []);
    expect(tool.name, 'noticias');
    expect(tool.mutates, isFalse);
  });

  test('formats headlines with their source', () async {
    final tool = NewsTool(
      fetch: (query, lang) async => const [
        NewsHeadline(
          title: 'Petro se reúne con el papa',
          source: 'El Espectador',
          url: 'u1',
        ),
        NewsHeadline(title: 'Sin fuente', source: '', url: 'u2'),
      ],
    );
    final result = await tool.run({});
    expect(result.isError, isFalse);
    expect(
      result.content,
      contains('1. Petro se reúne con el papa — El Espectador'),
    );
    expect(result.content, contains('2. Sin fuente'));
  });

  test('passes the query through to the fetch', () async {
    String? seen;
    final tool = NewsTool(
      fetch: (query, lang) async {
        seen = query;
        return const [NewsHeadline(title: 'x', source: 's', url: 'u')];
      },
    );
    await tool.run({'query': 'colombia'});
    expect(seen, 'colombia');
  });

  test('empty results report the unavailable message', () async {
    final tool = NewsTool(fetch: (q, l) async => const []);
    final result = await tool.run({});
    expect(result.content, Strings.newsUnavailable(AppLang.es));
  });

  test('a fetch error reports the unavailable message, not a crash', () async {
    final tool = NewsTool(fetch: (q, l) async => throw Exception('boom'));
    final result = await tool.run({});
    expect(result.content, Strings.newsUnavailable(AppLang.es));
  });
}
