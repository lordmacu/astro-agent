// test/voice/neural_voice_installer_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:astro/voice/neural_voice_installer.dart';

Uint8List _tinyZip() {
  final archive = Archive()
    ..addFile(ArchiveFile('model.onnx', 3, [1, 2, 3]))
    ..addFile(ArchiveFile('tokens.txt', 2, [97, 98]));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('install downloads, unzips, and emits Installed', () async {
    final tmp = await Directory.systemTemp.createTemp('nvi_test');
    final zip = _tinyZip();
    final client = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        Stream.value(zip),
        200,
        contentLength: zip.length,
      );
    });

    String? installedPath;
    final installer = NeuralVoiceInstaller(
      client: client,
      modelUrl: 'https://example.test/model.zip',
      modelName: 'testmodel',
      supportDir: () async => tmp,
      onInstalled: (p) async => installedPath = p,
    );

    final states = <VoiceInstallState>[];
    final sub = installer.state.listen(states.add);
    await installer.install();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();

    expect(states.last, isA<Installed>());
    expect(installedPath, isNotNull);
    expect(File('${tmp.path}/tts/testmodel/model.onnx').existsSync(), true);
    expect(File('${tmp.path}/tts/testmodel/.ready').existsSync(), true);
    await tmp.delete(recursive: true);
  });
}
