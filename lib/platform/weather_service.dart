import 'dart:convert';

import 'package:http/http.dart' as http;

/// Current weather for a place, from wttr.in (no key). Returns a one-line
/// summary ready to speak (e.g. "Bogotá: ⛅️ +19°C"), or null on any failure.
class WeatherService {
  const WeatherService({this.httpClient});

  final http.Client? httpClient;

  Future<String?> summary(String place) async {
    final p = Uri.encodeComponent(place.trim());
    // format=3 → "Location: <icon> <temp>"; m = metric; lang=es for conditions.
    final uri = Uri.parse('https://wttr.in/$p?format=3&m&lang=es');
    final client = httpClient ?? http.Client();
    try {
      // wttr.in serves plain text only to curl-like agents (browsers get HTML).
      final resp = await client.get(uri, headers: {'User-Agent': 'curl/8'});
      if (resp.statusCode != 200) return null;
      final line = utf8.decode(resp.bodyBytes).trim();
      // A bad place returns something like "Unknown location; ...".
      if (line.isEmpty || line.toLowerCase().contains('unknown location')) {
        return null;
      }
      return line;
    } on Object {
      return null;
    } finally {
      if (httpClient == null) client.close();
    }
  }
}
