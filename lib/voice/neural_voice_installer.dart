// lib/voice/neural_voice_installer.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

/// Where a neural-voice install currently stands.
sealed class VoiceInstallState {
  const VoiceInstallState();
}

class NotInstalled extends VoiceInstallState {
  const NotInstalled();
}

class Installing extends VoiceInstallState {
  const Installing(this.progress);

  /// 0.0–1.0, or -1 when the total size is unknown.
  final double progress;
}

class Installed extends VoiceInstallState {
  const Installed(this.path);
  final String path;
}

class InstallError extends VoiceInstallState {
  const InstallError(this.message);
  final String message;
}

/// Downloads a model zip on demand and unzips it into app storage, reporting
/// progress. The model is never bundled in the APK. Generic: used for the
/// neural voice ([subdir] 'tts') and the offline STT model ([subdir] 'stt').
class NeuralVoiceInstaller {
  NeuralVoiceInstaller({
    required http.Client client,
    required String modelUrl,
    required String modelName,
    required Future<Directory> Function() supportDir,
    required Future<void> Function(String path) onInstalled,
    String subdir = 'tts',
    List<String> fallbackUrls = const [],
  }) : _client = client,
       _modelUrl = modelUrl,
       _modelName = modelName,
       _supportDir = supportDir,
       _onInstalled = onInstalled,
       _subdir = subdir,
       _fallbackUrls = fallbackUrls;

  final http.Client _client;
  final String _modelUrl;
  final String _modelName;
  final Future<Directory> Function() _supportDir;
  final Future<void> Function(String path) _onInstalled;
  final String _subdir;

  /// Extra sources tried in order if [_modelUrl] fails.
  final List<String> _fallbackUrls;

  final _controller = StreamController<VoiceInstallState>.broadcast();
  Stream<VoiceInstallState> get state => _controller.stream;

  Future<void> install() async {
    try {
      _controller.add(const Installing(0));
      final support = await _supportDir();
      final modelDir = Directory('${support.path}/$_subdir/$_modelName');
      final marker = File('${modelDir.path}/.ready');
      if (marker.existsSync()) {
        _controller.add(Installed(modelDir.path));
        await _onInstalled(modelDir.path);
        return;
      }

      // Clean any partial previous attempt.
      if (modelDir.existsSync()) modelDir.deleteSync(recursive: true);
      modelDir.createSync(recursive: true);

      final bytes = await _download();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        final outPath = '${modelDir.path}/${entry.name}';
        if (entry.isFile) {
          File(outPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(entry.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
      marker.writeAsStringSync('ok');
      _controller.add(Installed(modelDir.path));
      await _onInstalled(modelDir.path);
    } catch (e) {
      _controller.add(InstallError('$e'));
    }
  }

  /// Try the primary URL then each fallback in order; the first that downloads
  /// wins. Only when all fail do we surface the last error.
  Future<Uint8List> _download() async {
    final urls = [_modelUrl, ..._fallbackUrls];
    Object lastError = const HttpException('no download sources');
    for (final url in urls) {
      try {
        return await _downloadOne(url);
      } catch (e) {
        lastError = e;
        _controller.add(const Installing(-1)); // reset the bar for the next try
      }
    }
    throw lastError;
  }

  Future<Uint8List> _downloadOne(String url) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException('download failed: ${response.statusCode}');
    }
    final total = response.contentLength ?? -1;
    final chunks = <int>[];
    var received = 0;
    await for (final chunk in response.stream) {
      chunks.addAll(chunk);
      received += chunk.length;
      _controller.add(Installing(total > 0 ? received / total : -1));
    }
    return Uint8List.fromList(chunks);
  }

  Future<void> dispose() => _controller.close();
}
