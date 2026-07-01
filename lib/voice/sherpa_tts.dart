import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'voice_interfaces.dart';

/// Offline neural TTS via sherpa-onnx + a Piper voice. The model lives in
/// [modelDir] (an already-extracted directory containing the `.onnx` weights,
/// `tokens.txt`, and `espeak-ng-data/`). Populated by NeuralVoiceInstaller
/// before this object is created — nothing is bundled in the APK.
///
/// Synthesizes to PCM, writes a WAV, and plays it, completing `speak` when
/// playback ends so the speaking animation lines up.
class SherpaTts implements TextToSpeech {
  SherpaTts({required this.modelDir, this.speed = 1.0});

  /// Directory holding the unzipped Piper model (.onnx, tokens.txt,
  /// espeak-ng-data). Populated by NeuralVoiceInstaller before this is created.
  final String modelDir;
  final double speed;

  sherpa.OfflineTts? _tts;
  final AudioPlayer _player = AudioPlayer();
  int _counter = 0;
  Future<void>? _initFuture;

  /// Load the engine ahead of time (load weights) so the first `speak` only
  /// pays synthesis cost. Call once when the screen appears.
  Future<void> warmUp() => _ensureInit();

  Future<void> _ensureInit() => _initFuture ??= _init();

  Future<void> _init() async {
    sherpa.initBindings();
    final dir = Directory(modelDir);
    final onnx = dir.listSync().whereType<File>().firstWhere(
      (f) => f.path.endsWith('.onnx'),
      orElse: () => throw StateError('no .onnx in $modelDir'),
    );

    final loadSw = Stopwatch()..start();
    final config = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: onnx.path,
          tokens: '$modelDir/tokens.txt',
          dataDir: '$modelDir/espeak-ng-data',
        ),
        // The S24 has 8 cores; more threads = faster synthesis.
        numThreads: 4,
        debug: false,
      ),
    );
    _tts = sherpa.OfflineTts(config);
    debugPrint('SherpaTts: model loaded in ${loadSw.elapsedMilliseconds}ms');
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();

    final sw = Stopwatch()..start();
    final audio = _tts!.generate(text: text, sid: 0, speed: speed);
    final audioSec = audio.samples.length / audio.sampleRate;
    debugPrint(
      'SherpaTts: synthesized ${audioSec.toStringAsFixed(2)}s of audio '
      'in ${sw.elapsedMilliseconds}ms (RTF '
      '${(sw.elapsedMilliseconds / 1000 / audioSec).toStringAsFixed(2)})',
    );
    if (audio.samples.isEmpty) return;

    final tmp = await getTemporaryDirectory();
    final path = '${tmp.path}/astro_${_counter++}.wav';
    await File(path).writeAsBytes(_encodeWav(audio.samples, audio.sampleRate));

    await _player.stop();
    final done = _player.onPlayerComplete.first;
    await _player.play(DeviceFileSource(path));
    await done;
  }

  @override
  Future<void> stop() => _player.stop();

  void dispose() {
    _player.dispose();
    _tts?.free();
    _tts = null;
  }

  /// Encode mono Float32 samples in [-1, 1] as a 16-bit PCM WAV.
  Uint8List _encodeWav(Float32List samples, int sampleRate) {
    final dataBytes = samples.length * 2;
    final out = BytesBuilder();

    void writeStr(String s) => out.add(s.codeUnits);
    void writeU32(int v) => out.add(
      (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
    );
    void writeU16(int v) => out.add(
      (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
    );

    writeStr('RIFF');
    writeU32(36 + dataBytes);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16); // PCM chunk size
    writeU16(1); // PCM format
    writeU16(1); // mono
    writeU32(sampleRate);
    writeU32(sampleRate * 2); // byte rate
    writeU16(2); // block align
    writeU16(16); // bits per sample
    writeStr('data');
    writeU32(dataBytes);

    final pcm = ByteData(dataBytes);
    for (var i = 0; i < samples.length; i++) {
      final s = (samples[i] * 32767).round().clamp(-32768, 32767);
      pcm.setInt16(i * 2, s, Endian.little);
    }
    out.add(pcm.buffer.asUint8List());

    return out.toBytes();
  }
}
