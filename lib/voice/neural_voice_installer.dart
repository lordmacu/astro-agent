// lib/voice/neural_voice_installer.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
    Duration timeout = const Duration(seconds: 120),
  }) : _client = client,
       _modelUrl = modelUrl,
       _modelName = modelName,
       _supportDir = supportDir,
       _onInstalled = onInstalled,
       _subdir = subdir,
       _fallbackUrls = fallbackUrls,
       _timeout = timeout;

  final http.Client _client;
  final String _modelUrl;
  final String _modelName;
  final Future<Directory> Function() _supportDir;
  final Future<void> Function(String path) _onInstalled;
  final String _subdir;

  /// Extra sources tried in order if [_modelUrl] fails.
  final List<String> _fallbackUrls;

  /// Per-source cap; a hung connection becomes an error (→ next source / retry)
  /// instead of a banner that spins forever.
  final Duration _timeout;

  final _controller = StreamController<VoiceInstallState>.broadcast();
  Stream<VoiceInstallState> get state => _controller.stream;

  VoiceInstallState _current = const NotInstalled();

  /// The latest state, retained so a late subscriber (e.g. a widget that builds
  /// after `install()` already started) can seed from it — a broadcast stream
  /// alone drops events emitted before subscription.
  VoiceInstallState get current => _current;

  /// Prefix so device logs make clear which model (stt / tts) is downloading.
  String get _tag => '[Astro][model:$_subdir]';

  void _emit(VoiceInstallState s) {
    _current = s;
    _controller.add(s);
  }

  Future<void> install() async {
    final sw = Stopwatch()..start();
    try {
      _emit(const Installing(0));
      final support = await _supportDir();
      final modelDir = Directory('${support.path}/$_subdir/$_modelName');
      final marker = File('${modelDir.path}/.ready');
      debugPrint('$_tag install() → target=${modelDir.path}');
      if (marker.existsSync()) {
        debugPrint('$_tag already installed (.ready present), skipping download');
        _emit(Installed(modelDir.path));
        await _onInstalled(modelDir.path);
        return;
      }

      // Clean any partial previous attempt.
      if (modelDir.existsSync()) {
        debugPrint('$_tag clearing partial previous attempt');
        modelDir.deleteSync(recursive: true);
      }
      modelDir.createSync(recursive: true);

      final bytes = await _download();
      debugPrint('$_tag downloaded ${bytes.length} bytes, unzipping…');
      final archive = ZipDecoder().decodeBytes(bytes);
      var files = 0;
      for (final entry in archive) {
        final outPath = '${modelDir.path}/${entry.name}';
        if (entry.isFile) {
          File(outPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(entry.content as List<int>);
          files++;
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
      marker.writeAsStringSync('ok');
      debugPrint(
        '$_tag ✓ installed ($files files, ${sw.elapsedMilliseconds}ms) '
        '→ ${modelDir.path}',
      );
      _emit(Installed(modelDir.path));
      await _onInstalled(modelDir.path);
    } catch (e, st) {
      debugPrint('$_tag ✗ install failed after ${sw.elapsedMilliseconds}ms: $e');
      debugPrint('$_tag stack: $st');
      _emit(InstallError('$e'));
    }
  }

  /// Try the primary URL then each fallback in order; the first that downloads
  /// wins. Only when all fail do we surface the last error.
  Future<Uint8List> _download() async {
    final urls = [_modelUrl, ..._fallbackUrls];
    Object lastError = const HttpException('no download sources');
    for (var i = 0; i < urls.length; i++) {
      final url = urls[i];
      try {
        debugPrint('$_tag source ${i + 1}/${urls.length}: GET $url');
        return await _downloadOne(url).timeout(_timeout);
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('$_tag source ${i + 1} TIMED OUT after '
            '${_timeout.inSeconds}s: $url');
        _emit(const Installing(-1)); // reset the bar for the next try
      } catch (e) {
        lastError = e;
        debugPrint('$_tag source ${i + 1} failed: $url → $e');
        _emit(const Installing(-1)); // reset the bar for the next try
      }
    }
    debugPrint('$_tag all ${urls.length} sources failed; last error: $lastError');
    throw lastError;
  }

  Future<Uint8List> _downloadOne(String url) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);
    final total = response.contentLength ?? -1;
    debugPrint('$_tag HTTP ${response.statusCode} '
        '(size=${total >= 0 ? '$total bytes' : 'unknown'}) ← $url');
    if (response.statusCode != 200) {
      throw HttpException('download failed: HTTP ${response.statusCode}');
    }
    // BytesBuilder (not a growable List<int>) keeps memory near the file size
    // instead of ~8x, which matters for a ~37MB model on low-end phones.
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream) {
      builder.add(chunk);
      received += chunk.length;
      _emit(Installing(total > 0 ? received / total : -1));
    }
    debugPrint('$_tag received $received bytes from $url');
    if (received == 0) {
      throw const HttpException('download failed: empty response body');
    }
    return builder.takeBytes();
  }

  Future<void> dispose() => _controller.close();
}
