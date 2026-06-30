import 'dart:convert';

/// Flatten untrusted provider text into something safe to drop into a model
/// prompt: control chars removed, newlines/tabs collapsed to single spaces,
/// runs of whitespace squeezed, and the whole thing capped to `maxBytes` of
/// UTF-8. Ported from the nexo-rs `web_search::sanitise`.
String sanitiseForPrompt(String input, int maxBytes) {
  final out = StringBuffer();
  var bytes = 0;
  var lastWasSpace = true; // suppress leading whitespace

  for (final rune in input.runes) {
    final String mapped;
    if (rune == 0x0d || rune == 0x0a || rune == 0x09) {
      mapped = ' ';
    } else if (_isControl(rune)) {
      continue;
    } else {
      mapped = String.fromCharCode(rune);
    }

    if (mapped == ' ') {
      if (lastWasSpace) continue;
      lastWasSpace = true;
    } else {
      lastWasSpace = false;
    }

    final width = utf8.encode(mapped).length;
    if (bytes + width > maxBytes) break;
    out.write(mapped);
    bytes += width;
  }

  return out.toString().trimRight();
}

/// Extract the host from a URL for display, or null if there isn't one.
String? hostOf(String url) {
  final after = url.contains('://') ? url.split('://')[1] : url;
  final host = after.split('/').first;
  return host.isEmpty ? null : host;
}

bool _isControl(int rune) =>
    rune < 0x20 || (rune >= 0x7f && rune < 0xa0);
