import 'dart:io';

import 'package:archive/archive.dart';
import 'package:astro/voice/neural_voice_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A tiny valid zip containing `am/final.mdl`, so the unzip has something real.
List<int> _sampleZip() {
  final archive = Archive()
    ..addFile(ArchiveFile('vosk/am/final.mdl', 3, [1, 2, 3]));
  return ZipEncoder().encode(archive)!;
}

void main() {
  late Directory support;
  setUp(() => support = Directory.systemTemp.createTempSync('inst_'));
  tearDown(() => support.deleteSync(recursive: true));

  NeuralVoiceInstaller make(
    http.Client client, {
    List<String> fallbackUrls = const [],
    Duration timeout = const Duration(seconds: 30),
    void Function(String)? onInstalled,
  }) => NeuralVoiceInstaller(
    client: client,
    modelUrl: 'https://primary.example/model.zip',
    fallbackUrls: fallbackUrls,
    modelName: 'm',
    subdir: 'stt',
    timeout: timeout,
    supportDir: () async => support,
    onInstalled: (p) async => onInstalled?.call(p),
  );

  test('downloads, unzips to disk, and reports Installed', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(_sampleZip(), 200),
    );
    String? installedPath;
    final inst = make(client, onInstalled: (p) => installedPath = p);

    final states = <VoiceInstallState>[];
    final sub = inst.state.listen(states.add);
    await inst.install();
    await sub.cancel();

    expect(states.last, isA<Installed>());
    expect(installedPath, isNotNull);
    expect(File('${support.path}/stt/m/.ready').existsSync(), isTrue);
    expect(
      File('${support.path}/stt/m/vosk/am/final.mdl').existsSync(),
      isTrue,
    );
  });

  test('falls back to the next URL when the first fails', () async {
    final client = MockClient((req) async {
      if (req.url.host == 'primary.example') return http.Response('no', 404);
      return http.Response.bytes(_sampleZip(), 200);
    });
    final inst = make(client, fallbackUrls: ['https://mirror.example/m.zip']);

    final states = <VoiceInstallState>[];
    final sub = inst.state.listen(states.add);
    await inst.install();
    await sub.cancel();

    expect(states.last, isA<Installed>());
  });

  test('a hung download times out and reports an error', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      return http.Response.bytes(_sampleZip(), 200);
    });
    final inst = make(client, timeout: const Duration(milliseconds: 80));

    final states = <VoiceInstallState>[];
    final sub = inst.state.listen(states.add);
    await inst.install();
    await Future<void>.delayed(Duration.zero); // flush broadcast microtasks
    await sub.cancel();

    expect(states.last, isA<InstallError>());
  });
}
