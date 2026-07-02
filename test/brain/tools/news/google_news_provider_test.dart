import 'package:astro/brain/tools/news/google_news_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const _rss = '''
<rss version="2.0"><channel>
<title>Top stories</title>
<item>
  <title>Petro se reúne con el papa - El Espectador</title>
  <link>https://news.google.com/rss/articles/x1</link>
  <source url="https://elespectador.com">El Espectador</source>
</item>
<item>
  <title>Dólar &amp; economía hoy - El Tiempo</title>
  <link>https://news.google.com/rss/articles/x2</link>
  <source url="https://eltiempo.com">El Tiempo</source>
</item>
</channel></rss>
''';

void main() {
  test('parses headlines, splits source out of the title', () {
    final hits = parseGoogleNewsRss(_rss);
    expect(hits.length, 2);
    expect(
      hits.first.title,
      'Petro se reúne con el papa',
    ); // " - source" removed
    expect(hits.first.source, 'El Espectador');
    expect(hits.first.url, 'https://news.google.com/rss/articles/x1');
  });

  test('decodes HTML entities in the title', () {
    final hits = parseGoogleNewsRss(_rss);
    expect(hits[1].title, 'Dólar & economía hoy');
  });

  test('respects the limit', () {
    expect(parseGoogleNewsRss(_rss, limit: 1).length, 1);
  });

  test('empty / no items yields an empty list', () {
    expect(parseGoogleNewsRss('<rss><channel></channel></rss>'), isEmpty);
  });
}
