import 'package:astro/brain/tools/device_tool.dart';
import 'package:astro/brain/tools/music_tool.dart';
import 'package:astro/brain/tools/phone_tool.dart';
import 'package:astro/brain/tools/timer_tool.dart';
import 'package:astro/platform/media_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the media-channel calls the tool makes, without any native side.
class _FakeMediaController extends MediaController {
  _FakeMediaController()
    : super(channel: const MethodChannel('astro/media/test'));

  final calls = <String>[];

  @override
  Future<bool> play(String query) async {
    calls.add('play:$query');
    return true;
  }

  @override
  Future<bool> pause() async {
    calls.add('pause');
    return true;
  }

  @override
  Future<bool> resume() async {
    calls.add('resume');
    return true;
  }

  @override
  Future<bool> next() async {
    calls.add('next');
    return true;
  }

  @override
  Future<bool> previous() async {
    calls.add('previous');
    return true;
  }
}

void main() {
  group('MusicTool', () {
    test('play forwards the query', () async {
      final media = _FakeMediaController();
      final result = await MusicTool(
        media,
      ).run({'action': 'play', 'query': 'jazz'});
      expect(media.calls, ['play:jazz']);
      expect(result.content, contains('jazz'));
    });

    test('control actions map through and reject unknowns', () async {
      final media = _FakeMediaController();
      final tool = MusicTool(media);
      for (final a in ['pause', 'resume', 'next', 'previous']) {
        await tool.run({'action': a});
      }
      expect(media.calls, ['pause', 'resume', 'next', 'previous']);
      expect((await tool.run({'action': 'boom'})).isError, isTrue);
    });
  });

  group('DeviceTool', () {
    test('set_brightness / set_volume apply the clamped 0..1 value', () async {
      double? bright, vol;
      final tool = DeviceTool(
        setBrightness: (v) async => bright = v,
        setVolume: (v) async => vol = v,
        nudgeVolume: (_) async {},
        setTorch: (_) async {},
      );

      await tool.run({'action': 'set_brightness', 'level': 40});
      await tool.run({'action': 'set_volume', 'level': 250});

      expect(bright, closeTo(0.4, 1e-9));
      expect(vol, 1.0); // clamped
    });

    test('volume_up / down nudge, flashlight toggles', () async {
      final nudges = <int>[];
      bool? torch;
      final tool = DeviceTool(
        setBrightness: (_) async {},
        setVolume: (_) async {},
        nudgeVolume: (d) async => nudges.add(d),
        setTorch: (on) async => torch = on,
      );

      await tool.run({'action': 'volume_up'});
      await tool.run({'action': 'volume_down'});
      await tool.run({'action': 'flashlight_on'});
      expect(nudges, [1, -1]);
      expect(torch, isTrue);

      await tool.run({'action': 'flashlight_off'});
      expect(torch, isFalse);
    });

    test('is read-only (no confirmation)', () {
      final tool = DeviceTool(
        setBrightness: (_) async {},
        setVolume: (_) async {},
        nudgeVolume: (_) async {},
        setTorch: (_) async {},
      );
      expect(tool.mutates, isFalse);
    });

    test('open_app launches by name and reports the outcome', () async {
      String? opened;
      final tool = DeviceTool(
        setBrightness: (_) async {},
        setVolume: (_) async {},
        nudgeVolume: (_) async {},
        setTorch: (_) async {},
        openApp: (name) async {
          opened = name;
          return name.toLowerCase() == 'spotify';
        },
      );

      final ok = await tool.run({'action': 'open_app', 'app': 'Spotify'});
      expect(opened, 'Spotify');
      expect(ok.content, contains('Abriendo Spotify'));

      final miss = await tool.run({'action': 'open_app', 'app': 'Nope'});
      expect(miss.content.toLowerCase(), contains('no encontré'));
    });

    test('open_app without an app name is an error', () async {
      final tool = DeviceTool(
        setBrightness: (_) async {},
        setVolume: (_) async {},
        nudgeVolume: (_) async {},
        setTorch: (_) async {},
        openApp: (_) async => true,
      );
      final result = await tool.run({'action': 'open_app'});
      expect(result.isError, isTrue);
    });
  });

  group('TimerTool', () {
    test('timer needs positive seconds', () async {
      final tool = TimerTool(
        setTimer: (_, __) async => true,
        setAlarm: (_, __, ___) async => true,
      );
      expect(
        (await tool.run({'action': 'timer', 'seconds': 0})).isError,
        isTrue,
      );
    });

    test('timer forwards seconds and label', () async {
      int? secs;
      String? label;
      final tool = TimerTool(
        setTimer: (s, l) async {
          secs = s;
          label = l;
          return true;
        },
        setAlarm: (_, __, ___) async => true,
      );
      final result = await tool.run({
        'action': 'timer',
        'seconds': 600,
        'label': 'té',
      });
      expect(secs, 600);
      expect(label, 'té');
      expect(result.content, contains('10 min'));
    });

    test('alarm validates the time', () async {
      final tool = TimerTool(
        setTimer: (_, __) async => true,
        setAlarm: (_, __, ___) async => true,
      );
      expect((await tool.run({'action': 'alarm', 'hour': 30})).isError, isTrue);
      final ok = await tool.run({'action': 'alarm', 'hour': 6, 'minute': 30});
      expect(ok.content, contains('06:30'));
    });
  });

  group('PhoneTool', () {
    PhoneTool build({
      String? resolved = '+573001112233',
      List<String>? calls,
      List<String>? messages,
    }) => PhoneTool(
      resolveContact: (_) async => resolved,
      call: (n) async {
        calls?.add(n);
        return true;
      },
      message: (n, t, w) async {
        messages?.add('$n|$t|${w ? 'wa' : 'sms'}');
        return true;
      },
    );

    test('is mutating (needs confirmation)', () {
      expect(build().mutates, isTrue);
    });

    test('a raw number passes through without lookup', () async {
      final calls = <String>[];
      final tool = build(resolved: null, calls: calls); // resolve returns null
      await tool.run({'action': 'call', 'contact': '+57 300 111 2233'});
      expect(calls, ['+573001112233']);
    });

    test('resolves a saved name before calling', () async {
      final calls = <String>[];
      final tool = build(resolved: '+573009998877', calls: calls);
      await tool.run({'action': 'call', 'contact': 'mamá'});
      expect(calls, ['+573009998877']);
    });

    test('unknown contact reports back', () async {
      final tool = build(resolved: null);
      final result = await tool.run({'action': 'call', 'contact': 'zzz'});
      expect(result.content.toLowerCase(), contains('no encontré'));
    });

    test(
      'an injected number dials directly and reports the real name',
      () async {
        final calls = <String>[];
        // resolve would fail (null), but the injected number skips lookup.
        final tool = build(resolved: null, calls: calls);
        final result = await tool.run({
          'action': 'call',
          'contact': 'Mi Esposa',
          'number': '+573001112233',
        });
        expect(calls, ['+573001112233']);
        expect(result.content, contains('Mi Esposa'));
      },
    );

    test('message defaults to WhatsApp and needs text', () async {
      final messages = <String>[];
      final tool = build(messages: messages);
      expect(
        (await tool.run({'action': 'message', 'contact': 'mamá'})).isError,
        isTrue,
      );
      await tool.run({'action': 'message', 'contact': 'mamá', 'text': 'voy'});
      expect(messages.single, endsWith('|voy|wa'));
    });
  });
}
