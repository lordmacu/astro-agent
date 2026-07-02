import 'dart:io';

import 'package:astro/voice/vosk_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveVoskModelRoot', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('vosk_root_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('returns base when the model files sit directly in it', () {
      Directory('${tmp.path}/am').createSync();
      Directory('${tmp.path}/conf').createSync();
      expect(resolveVoskModelRoot(tmp.path), tmp.path);
    });

    test('descends into a nested model folder (zip with a top dir)', () {
      final inner = Directory('${tmp.path}/vosk-model-small-es-0.42')
        ..createSync();
      Directory('${inner.path}/am').createSync();
      expect(resolveVoskModelRoot(tmp.path), inner.path);
    });

    test('falls back to base when nothing looks like a model', () {
      expect(resolveVoskModelRoot(tmp.path), tmp.path);
      expect(resolveVoskModelRoot('/no/such/path'), '/no/such/path');
    });
  });
}
