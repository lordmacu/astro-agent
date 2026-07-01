import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi;

import '../core/config/setting_key.dart';
import '../core/config/settings_providers.dart';
import '../core/config/settings_resolver.dart';
import '../core/config/tool_catalog.dart';
import '../core/config/tool_prefs.dart';
import '../core/state/app_mode.dart';
import '../core/state/app_state_provider.dart';
import '../memory/long_term_memory.dart';
import '../memory/memory_extractor.dart';
import '../platform/media_controller.dart';
import '../sensors/location/place_resolver.dart';
import '../platform/system_actions.dart';
import 'astro_brain.dart';
import 'llm/providers/openai_compat_client.dart';
import 'memory_context.dart';
import '../platform/app_launcher.dart';
import '../platform/battery_reader.dart';
import '../platform/calendar_prefs.dart';
import '../platform/calendar_writer.dart';
import '../platform/camera_capture.dart';
import '../platform/email_reader.dart';
import '../platform/email_sender.dart';
import '../platform/sent_emails_store.dart';
import '../platform/smtp_store.dart';
import '../platform/weather_service.dart';
import 'tools/calendar_tool.dart';
import 'tools/camera_tool.dart';
import 'tools/communication_tool.dart';
import '../platform/notifications_reader.dart';
import 'tools/context_tool.dart';
import 'tools/device_tool.dart';
import 'tools/memory_tools.dart';
import 'tools/music_tool.dart';
import 'tools/map_tool.dart';
import 'tools/phone_tool.dart';
import 'tools/weather_tool.dart';
import 'tools/timer_tool.dart';
import 'tools/tool_registry.dart';
import 'tools/web_search/providers/duckduckgo_provider.dart';
import 'tools/web_search/providers/fallback_provider.dart';
import 'tools/web_search/providers/minimax_provider.dart';
import 'tools/web_search/providers/tavily_provider.dart';
import 'tools/web_search/web_search_provider.dart';
import 'tools/web_search/web_search_tool.dart';

/// Resolve a secret: prefer the runtime `.env` (so any `flutter run` works),
/// then fall back to a `--dart-define` build arg. Returns '' when unset.
String _secret(String envName, String define) {
  try {
    final v = dotenv.env[envName];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  } catch (_) {
    // dotenv not initialised (e.g. in tests) — fall through to the define.
  }
  return define;
}

/// MiniMax API key: user setting > .env (LLM_API_KEY) > dart-define.
String _miniMaxKey(Ref ref) => resolveSecret(
  store: ref.read(settingsStoreProvider),
  key: SettingKey.llmApiKey,
  envDefine: _secret(
    'LLM_API_KEY',
    const String.fromEnvironment(
      'LLM_API_KEY',
      defaultValue: String.fromEnvironment('MINIMAX_API_KEY'),
    ),
  ),
);

/// Web-search key: user setting > .env (TAVILY_API_KEY) > dart-define.
String _searchKey(Ref ref) => resolveSecret(
  store: ref.read(settingsStoreProvider),
  key: SettingKey.searchApiKey,
  envDefine: _secret(
    'TAVILY_API_KEY',
    const String.fromEnvironment('TAVILY_API_KEY'),
  ),
);

/// Pick the web-search backend for the active LLM provider. MiniMax gets its
/// native search (`/v1/coding_plan/search`) with DuckDuckGo as a keyless,
/// always-available fallback; every other provider uses Tavily when its key is
/// configured, else no web search at all. Gating on the provider id keeps the
/// MiniMax-only search key from ever being used under a different LLM.
WebSearchProvider? _buildSearchProvider(Ref ref, String llmProviderId) {
  if (llmProviderId == 'minimax') {
    final key = _miniMaxKey(ref);
    return FallbackSearchProvider([
      if (key.isNotEmpty) MiniMaxSearchProvider(apiKey: key),
      DuckDuckGoProvider(),
    ]);
  }
  final tavily = _searchKey(ref);
  if (tavily.isNotEmpty) return TavilyProvider(apiKey: tavily);
  return null;
}

/// Whether the brain has credentials. The UI uses this to fall back to canned
/// lines instead of hitting the API with no key.
final astroConfiguredProvider = Provider<bool>((ref) {
  ref.watch(settingsProvider.select((s) => s.llmApiKey));
  return _miniMaxKey(ref).isNotEmpty;
});

/// The model Astro talks through. Default MiniMax-M3 (only model with
/// documented tool calling; thinking is disabled at the client for speed).
/// Override with `ASTRO_MODEL=` in `.env` to experiment (e.g. a highspeed
/// variant) — but M2.x tool support is undocumented and their thinking can't
/// be turned off, so they may be slower and may not call tools.
final astroModelProvider = Provider<String>((ref) {
  final user = ref.watch(settingsProvider.select((s) => s.llmModel)).trim();
  if (user.isNotEmpty) return user;
  return _secret(
    'ASTRO_MODEL',
    const String.fromEnvironment('ASTRO_MODEL'),
  ).ifEmpty('MiniMax-M3');
});

extension _Fallback on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// Astro's persona and answer style, tuned to the active mode. The language
/// rule (#0) and the speaking style are shared; car mode frames Astro as a
/// copilot aware of speed and driving safety, normal mode as a general
/// companion with neither. The rest follows the humanize-text guidelines (short
/// active sentences, everyday words, no clichés, no hedging), for a voiced pet.
String astroSystemPromptFor(AppMode mode) {
  final persona = mode.isCar
      ? 'Eres Astro, la mascota copiloto de un carro. Vas en el asiento del '
            'copiloto y hablas como un buen amigo: cálido, con humor, cercano. '
            'Tus respuestas se leen en voz alta, así que habla natural.'
      : 'Eres Astro, la mascota que acompaña a su dueño. Estás con él, en casa '
            'o en su mano, y hablas como un buen amigo: cálido, con humor, '
            'cercano. Tus respuestas se leen en voz alta, así que habla natural.';

  final contextTool = mode.isCar
      ? 'get_context (hora, velocidad, ubicación, batería)'
      : 'get_context (hora, ubicación, batería)';

  final closing = mode.isCar
      ? ' Nunca inventes datos del carro. Cuida la seguridad: no distraigas de '
            'más mientras se conduce.'
      : '';

  return '''
REGLA #0, IRROMPIBLE — IDIOMA: responde SIEMPRE en español de Colombia, con
tildes correctas. Nunca uses chino, inglés, portugués ni ningún otro idioma,
pase lo que pase y en cualquier idioma que te hablen. Si algo saldría en otro
idioma, reescríbelo en español antes de responder. Una respuesta con otro
idioma no sirve.

$persona

Cómo hablas:
- Frases cortas, de 10 a 20 palabras, una idea por frase. Voz activa.
- Palabras cotidianas y concretas. Datos exactos cuando los tengas.
- Sé breve: 1 o 2 frases. Nada de listas ni markdown.
- Sin punto y coma, sin guiones largos, sin jerga ni clichés.
- No te disculpes, no dudes, no digas que eres una IA. Di las cosas directo.

Comandos cortados: el reconocedor de voz a veces corta la frase y te llega
incompleta (una o dos palabras sueltas, o algo a medias como "busca en" o
"llama a"). Cuando eso pase, NO adivines ni inventes: pide que te lo repitan
completo con una pregunta corta y concreta que termine en "?" (así se reabre el
micrófono). Ej: "Se cortó, ¿qué querías buscar?".

Herramientas: $contextTool; music (poner o controlar música); take_photo (tomar
una foto y guardarla en la galería); calendar (crear un evento o recordatorio en
el calendario); comunicacion (mandar correo, leer correos, o leer las
notificaciones del teléfono); clima (el tiempo de un lugar); mapa (navegar a un
destino o buscar sitios cerca); device
(brillo, volumen, linterna, abrir apps); timer (temporizador o alarma); phone
(llamar o mandar mensaje); web_search (datos
frescos de internet); remember_fact (guardar algo del usuario).$closing''';
}

/// Holds the command-time voice confirmation for mutating tools. The UI sets
/// [confirmer] once mounted; until then, mutating tools are denied. A mutable
/// holder (not a StateProvider) so the UI can install it from initState without
/// modifying provider state mid-build.
class ToolConfirmerHolder {
  ConfirmTool? confirmer;
}

final toolConfirmerProvider = Provider<ToolConfirmerHolder>(
  (_) => ToolConfirmerHolder(),
);

/// Holds the UI callback that lets the user pick a calendar (shown once, then
/// remembered). The UI installs it once mounted; until then, and if the user
/// dismisses it, event creation falls back to the primary calendar.
class CalendarChooserHolder {
  Future<CalendarOption?> Function(List<CalendarOption>)? choose;
}

final calendarChooserProvider = Provider<CalendarChooserHolder>(
  (_) => CalendarChooserHolder(),
);

/// Resolve which calendar to write to, showing the picker only the first time.
/// Uses the saved choice when it still exists; otherwise auto-picks a lone
/// calendar, or asks the UI to choose and remembers it. Returns null id (0) to
/// let the native side fall back to the primary calendar.
Future<int> _resolveCalendarId(Ref ref, CalendarWriter writer) async {
  const prefs = CalendarPrefs();
  final options = await writer.listCalendars();
  if (options.isEmpty) return 0; // none/denied → native primary fallback

  final storedId = await prefs.load();
  if (storedId != null && options.any((c) => c.id == storedId)) {
    return storedId;
  }
  if (options.length == 1) {
    await prefs.save(options.first.id);
    return options.first.id;
  }
  final choose = ref.read(calendarChooserProvider).choose;
  final picked = choose == null ? null : await choose(options);
  if (picked == null) return 0; // UI not ready / dismissed → primary fallback
  await prefs.save(picked.id);
  return picked.id;
}

/// Native media controller (play / pause / skip) shared by the music tool.
final mediaControllerProvider = Provider<MediaController>(
  (_) => MediaController(),
);

/// Long-term memory, opened once. Uses the ffi factory backed by the bundled
/// libsqlite3 (which has FTS5); `getDatabasesPath()` still gives a valid
/// per-app location. Null if it fails to open (the brain works without recall).
final memoryProvider = FutureProvider<LongTermMemory?>((ref) async {
  try {
    final dir = await getDatabasesPath();
    return await LongTermMemory.open(
      factory: databaseFactoryFfi,
      path: '$dir/astro_memory.db',
    );
  } catch (_) {
    return null;
  }
});

/// How many memories are stored, for the Settings counter. Reactive: invalidate
/// it after saving or clearing memories and the counter updates itself. 0 when
/// memory is unavailable.
final memoryCountProvider = FutureProvider<int>((ref) async {
  final memory = await ref.watch(memoryProvider.future);
  return memory == null ? 0 : memory.count();
});

/// Background memory extractor: after a conversation, an LLM pass pulls durable
/// facts from the transcript and stores them, so Astro learns without the driver
/// saying "remember this". Null when memory is unavailable or the LLM isn't
/// configured (no key) — then there is nothing to run.
final memoryExtractorProvider = FutureProvider<MemoryExtractor?>((ref) async {
  if (!ref.watch(astroConfiguredProvider)) return null;
  final memory = await ref.watch(memoryProvider.future);
  if (memory == null) return null;
  return MemoryExtractor(
    client: OpenAiCompatClient.miniMax(apiKey: _miniMaxKey(ref)),
    memory: memory,
    model: ref.read(astroModelProvider),
  );
});

/// The fully wired brain: MiniMax client + the active tool set + memory recall.
/// A FutureProvider because opening memory is async.
final astroBrainProvider = FutureProvider<AstroBrain>((ref) async {
  // Rebuild the brain whenever the key or model changes.
  ref.watch(settingsProvider.select((s) => s.llmApiKey));
  ref.watch(settingsProvider.select((s) => s.searchApiKey));
  // Rebuild when the driver enables/disables a tool from Settings.
  final disabledTools = ref.watch(toolPrefsProvider);
  final client = OpenAiCompatClient.miniMax(apiKey: _miniMaxKey(ref));
  final media = ref.read(mediaControllerProvider);
  const actions = SystemActions();
  final calendarWriter = CalendarWriter();
  final batteryReader = BatteryReader();
  final placeResolver = PlaceResolver(); // one instance, so its cache persists

  // Above the soft limit of 5 on purpose: MiniMax-M3 has strong tool use and a
  // 1M-token context, so it handles this set well. If selection ever degrades,
  // split into a router / topic agents.
  final registry = ToolRegistry(softLimit: 12)
    // Situational snapshot: time + speed + location + battery.
    ..register(
      ContextTool(
        speedKmh: () => ref.read(appStateProvider).valueOrNull?.speedKmh,
        locationName: placeResolver.name,
        carMode: () => ref.read(appModeProvider).isCar,
        battery: batteryReader.read,
      ),
    )
    // Music: play / pause / resume / next / previous.
    ..register(MusicTool(media))
    // Camera: take a photo, saved to the gallery.
    ..register(
      CameraTool(
        capture: const CameraCapture().capture,
        playShutter: media.shutter,
        onCaptured: (path) =>
            ref.read(capturedPhotoProvider.notifier).state = path,
      ),
    )
    // Calendar: create an event / reminder. The calendar is picked once (UI
    // popup) then remembered; creation itself is silent.
    ..register(
      CalendarTool(
        createEvent:
            ({
              required title,
              required start,
              required duration,
              required reminder,
            }) async {
              final calendarId = await _resolveCalendarId(ref, calendarWriter);
              return calendarWriter.createEvent(
                calendarId: calendarId,
                title: title,
                start: start,
                duration: duration,
                reminder: reminder,
              );
            },
      ),
    )
    // Communication: send email (confirmed when SMTP sends), read email, read
    // notifications — one tool with an action to keep the tool count low.
    ..register(
      CommunicationTool(
        emailConfigured: () async =>
            (await const SmtpStore().load()).isComplete,
        sendEmail: ({required to, required subject, required body}) async {
          final ok = await const EmailSender().send(
            config: await const SmtpStore().load(),
            to: to,
            subject: subject,
            body: body,
          );
          // Remember the recipient so Astro can reuse it later.
          if (ok) await const SentEmailsStore().add(to);
          return ok;
        },
        composeEmail: ({required to, required subject, required body}) =>
            actions.composeEmail(to: to, subject: subject, body: body),
        // No-SMTP path: turn a spoken contact name into its saved address.
        resolveEmail: (query) async {
          final matches = await actions.matchingContactEmails(query, max: 1);
          return matches.isEmpty ? null : matches.first.email;
        },
        emailCanRead: () async => (await const SmtpStore().load()).canRead,
        readEmail: ({required count}) async => const EmailReader().fetchRecent(
          await const SmtpStore().load(),
          count: count,
        ),
        openMailApp: actions.openEmailApp,
        readNotifications: ({required count}) =>
            const NotificationsReader().recent(count: count),
      ),
    )
    // Phone hardware: brightness + volume + flashlight + open apps.
    ..register(
      DeviceTool(
        setBrightness: (v) =>
            ScreenBrightness().setApplicationScreenBrightness(v),
        setVolume: media.setVolume,
        nudgeVolume: media.nudgeVolume,
        setTorch: media.setTorch, // native CameraManager (reliable off)
        openApp: const AppLauncher().open,
      ),
    )
    // Maps: navigate to a place or find places nearby.
    ..register(MapTool(navigate: actions.navigate, nearby: actions.nearby))
    // Current weather (empty place → current location).
    ..register(
      WeatherTool(
        fetch: (place) async {
          final p = place.trim().isEmpty
              ? (await placeResolver.name() ?? '')
              : place;
          return const WeatherService().summary(p);
        },
      ),
    )
    // Countdown timer / alarm.
    ..register(
      TimerTool(setTimer: actions.setTimer, setAlarm: actions.setAlarm),
    )
    // Calls and messages (mutating → confirmed).
    ..register(
      PhoneTool(
        resolveContact: actions.resolveContact,
        call: actions.call,
        message: actions.message,
      ),
    );

  // Web search: on MiniMax (Astro's provider) use MiniMax's native search with
  // DuckDuckGo as a keyless fallback; any other LLM provider uses Tavily.
  final searchProvider = _buildSearchProvider(ref, client.providerId);
  if (searchProvider != null) {
    registry.register(WebSearchTool(searchProvider));
  }

  // Long-term memory: write tool + automatic recall (no separate read tool, to
  // stay within the tool budget — recall is injected each turn).
  final memory = await ref.watch(memoryProvider.future);
  final memRecall = memory != null ? MemoryContext(memory).call : null;
  if (memory != null) registry.register(RememberTool(memory));

  // Drop the tools the driver turned off in Settings (done last so it applies
  // to the conditionally-registered tools too). Core tools are never removed,
  // even if a stale preference names one.
  for (final name in disabledTools) {
    if (kCoreTools.contains(name)) continue;
    registry.unregister(name);
  }

  // Recall each turn = long-term memory + the addresses Astro has emailed, so it
  // can reuse a recipient the user references.
  Future<String?> recall(String userText) async {
    final parts = <String>[];
    if (memRecall != null) {
      final m = await memRecall(userText);
      if (m != null && m.isNotEmpty) parts.add(m);
    }
    final recipients = await const SentEmailsStore().all();
    if (recipients.isNotEmpty) {
      parts.add('Correos a los que ya escribiste: ${recipients.join(', ')}.');
    }
    return parts.isEmpty ? null : parts.join('\n');
  }

  return AstroBrain(
    client: client,
    registry: registry,
    recallContext: recall,
    confirm: (tool, args) async {
      final confirmer = ref.read(toolConfirmerProvider).confirmer;
      return confirmer == null ? false : confirmer(tool, args);
    },
  );
});
