import 'app_lang.dart';

/// Bilingual UI copy. One method per string; interpolated ones take params.
/// Mirrors `voice/speech_catalog.dart`: this is the single place UI Spanish
/// lives. Grow it as tasks migrate hardcoded strings.
abstract final class Strings {
  static String _pick(AppLang l, {required String en, required String es}) =>
      l == AppLang.es ? es : en;

  static String settingsTitle(AppLang l) =>
      _pick(l, en: 'Settings', es: 'Configuración');
  static String save(AppLang l) => _pick(l, en: 'Save', es: 'Guardar');
  static String cancel(AppLang l) => _pick(l, en: 'Cancel', es: 'Cancelar');
  static String listening(AppLang l) =>
      _pick(l, en: 'Listening…', es: 'Escuchando…');
  static String thinking(AppLang l) =>
      _pick(l, en: 'Thinking…', es: 'Pensando…');
  static String wakeHint(String word, AppLang l) =>
      _pick(l, en: 'Say «$word» or tap 🎙️', es: 'Di «$word» o tócala 🎙️');
  static String confirmCall(String name, AppLang l) =>
      _pick(l, en: 'Call $name?', es: '¿Llamo a $name?');
  static String brightnessSet(int level, AppLang l) =>
      _pick(l, en: 'Brightness at $level%.', es: 'Brillo en $level%.');

  // ── Settings screen ──────────────────────────────────────────────────────
  static String voiceSection(AppLang l) => _pick(l, en: 'Voice', es: 'Voz');
  static String rateLabel(AppLang l) => _pick(l, en: 'Speed', es: 'Velocidad');
  static String pitchLabel(AppLang l) => _pick(l, en: 'Pitch', es: 'Tono');
  static String language(AppLang l) => _pick(l, en: 'Language', es: 'Idioma');
  static String download(AppLang l) =>
      _pick(l, en: 'Download', es: 'Descargar');
  static String neuralVoice(AppLang l) =>
      _pick(l, en: 'Neural voice (offline)', es: 'Voz neuronal (offline)');
  static String useNeuralVoice(AppLang l) =>
      _pick(l, en: 'Use neural voice', es: 'Usar voz neuronal');
  static String neuralVoiceHint(AppLang l) =>
      _pick(l, en: 'Download it first', es: 'Requiere descargarla primero');
  static String downloading(AppLang l) =>
      _pick(l, en: 'Downloading…', es: 'Descargando…');
  static String downloadingPct(int pct, AppLang l) =>
      _pick(l, en: 'Downloading $pct%', es: 'Descargando $pct%');
  static String errorPrefix(String message, AppLang l) =>
      _pick(l, en: 'Error: $message', es: 'Error: $message');
  static String ready(AppLang l) => _pick(l, en: 'Ready', es: 'Lista');
  static String installed(AppLang l) =>
      _pick(l, en: 'Installed', es: 'Instalada');
  static String notDownloaded(AppLang l) =>
      _pick(l, en: 'Not downloaded', es: 'No descargada');
  static String aiSection(AppLang l) => _pick(l, en: 'AI', es: 'IA');

  static String aiSetupSpoken(AppLang l) => _pick(
    l,
    en: 'You need to add an API key so I can think. Let me open the setup.',
    es: 'Necesitas agregar una API key para que pueda pensar. Te abro la configuración.',
  );

  static String aiSetupTitle(AppLang l) =>
      _pick(l, en: 'Set up the AI', es: 'Configura la IA');

  static String aiSetupBody(AppLang l) => _pick(
    l,
    en: 'Pick a model and paste an API key to enable Astro\'s brain.',
    es: 'Elige un modelo y pega una API key para activar el cerebro de Astro.',
  );

  static String aiKeyLabel(AppLang l) =>
      _pick(l, en: 'LLM API key', es: 'API key del LLM');

  static String aiKeyHint(AppLang l) => _pick(
    l,
    en:
        'You can get a key from MiniMax, OpenAI, or another '
        'OpenAI-compatible provider.',
    es:
        'Puedes obtener una key de MiniMax, OpenAI u otro proveedor '
        'compatible con OpenAI.',
  );

  static String llmApiKey(AppLang l) =>
      _pick(l, en: 'LLM API key', es: 'API key del LLM');
  static String searchProviderLabel(AppLang l) =>
      _pick(l, en: 'Search provider', es: 'Proveedor de búsqueda');
  static String searchApiKey(AppLang l) =>
      _pick(l, en: 'Web search API key', es: 'API key de búsqueda web');
  static String getSearchKeyLink(String provider, AppLang l) {
    final name = provider == 'brave' ? 'Brave' : 'Tavily';
    return _pick(
      l,
      en: 'Get a $name API key',
      es: 'Consigue tu API key de $name',
    );
  }

  static String searxngUrl(AppLang l) => _pick(
    l,
    en: 'SearXNG URL (keyless search)',
    es: 'URL de SearXNG (búsqueda sin key)',
  );
  static String wakeSensorsSection(AppLang l) =>
      _pick(l, en: 'Wake word and sensors', es: 'Wake word y sensores');
  static String wakeWordLabel(String word, AppLang l) =>
      _pick(l, en: 'Keyword «$word»', es: 'Palabra clave «$word»');
  static String wakeWordHint(AppLang l) => _pick(
    l,
    en: 'Always listen to answer by voice',
    es: 'Escuchar siempre para responder por voz',
  );
  static String wakePhraseLabel(AppLang l) =>
      _pick(l, en: 'Wake phrase', es: 'Frase para despertar');
  static String sensitivity(AppLang l) =>
      _pick(l, en: 'Sensitivity', es: 'Sensibilidad');
  static String navLabel(AppLang l) =>
      _pick(l, en: 'Navigation (Maps)', es: 'Navegación (Maps)');
  static String navGrantHint(AppLang l) => _pick(
    l,
    en: 'No notification access — tap to grant',
    es: 'Sin acceso a notificaciones — toca para conceder',
  );
  static String navOnHint(AppLang l) => _pick(
    l,
    en: 'React to Google Maps directions',
    es: 'Reaccionar a las indicaciones de Google Maps',
  );
  static String downloadingVoiceModel(AppLang l) => _pick(
    l,
    en: 'Downloading the voice model for a better experience…',
    es: 'Descargando el modelo de voz para una mejor experiencia…',
  );
  static String voiceModelFailed(AppLang l) => _pick(
    l,
    en: "Couldn't download the voice model. Astro still works.",
    es: 'No pude descargar el modelo de voz. Astro igual funciona.',
  );
  static String retry(AppLang l) => _pick(l, en: 'Retry', es: 'Reintentar');
  static String haptics(AppLang l) =>
      _pick(l, en: 'Vibration', es: 'Vibración');
  static String hapticsHint(AppLang l) => _pick(
    l,
    en: 'Vibrate on taps and confirmations',
    es: 'Vibrar al tocar y confirmar',
  );
  static String autoBrightness(AppLang l) =>
      _pick(l, en: 'Automatic brightness', es: 'Brillo automático');
  static String autoBrightnessHint(AppLang l) => _pick(
    l,
    en: 'Adjust brightness to the ambient light',
    es: 'Ajustar el brillo con la luz del ambiente',
  );
  static String permissionsSection(AppLang l) =>
      _pick(l, en: 'Permissions', es: 'Permisos');
  static String micPermission(AppLang l) =>
      _pick(l, en: 'Microphone', es: 'Micrófono');
  static String notificationsPermission(AppLang l) =>
      _pick(l, en: 'Notifications', es: 'Notificaciones');
  static String locationPermission(AppLang l) =>
      _pick(l, en: 'Location', es: 'Ubicación');
  static String aboutSection(AppLang l) =>
      _pick(l, en: 'About', es: 'Acerca de');
  static String customModel(AppLang l) =>
      _pick(l, en: 'Custom…', es: 'Personalizado…');
  static String customModelLabel(AppLang l) =>
      _pick(l, en: 'Custom model', es: 'Modelo personalizado');
  static String notificationsTitle(AppLang l) =>
      _pick(l, en: 'Notifications', es: 'Notificaciones');
  static String summarize(AppLang l) =>
      _pick(l, en: 'Summarize', es: 'Resumir');
  static String noNotifications(AppLang l) =>
      _pick(l, en: 'Nothing new.', es: 'Nada nuevo.');
  static String grantNotifications(AppLang l) => _pick(
    l,
    en: 'Allow notification access',
    es: 'Dar acceso a notificaciones',
  );
  static String notifSummaryError(AppLang l) =>
      _pick(l, en: "I couldn't read that.", es: 'No pude leer eso.');
  static String toolsSection(AppLang l) =>
      _pick(l, en: 'Tools', es: 'Herramientas');
  static String memorySection(AppLang l) =>
      _pick(l, en: 'Memory', es: 'Memoria');
  static String clearMemoryTitle(AppLang l) =>
      _pick(l, en: 'Clear the memory?', es: '¿Borrar la memoria?');
  static String clearMemoryBody(AppLang l) => _pick(
    l,
    en: 'Astro will forget everything it remembers about you.',
    es: 'Astro olvidará todo lo que recuerda de ti.',
  );
  static String delete(AppLang l) => _pick(l, en: 'Delete', es: 'Borrar');
  static String cantOpenLink(AppLang l) =>
      _pick(l, en: "I couldn't open the link.", es: 'No pude abrir el enlace.');
  static String emailSaved(AppLang l) =>
      _pick(l, en: 'Email saved', es: 'Correo guardado');
  static String emailSection(AppLang l) =>
      _pick(l, en: 'Email (SMTP)', es: 'Email (SMTP)');
  static String loading(AppLang l) => _pick(l, en: 'Loading…', es: 'Cargando…');
  static String smtpServer(AppLang l) =>
      _pick(l, en: 'SMTP server', es: 'Servidor SMTP');
  static String port(AppLang l) => _pick(l, en: 'Port', es: 'Puerto');
  static String emailUser(AppLang l) =>
      _pick(l, en: 'User (email)', es: 'Usuario (correo)');
  static String passwordOrAppPassword(AppLang l) =>
      _pick(l, en: 'Password or app password', es: 'Contraseña o app password');
  static String appPasswordHint(AppLang l) => _pick(
    l,
    en: 'Needs two-step verification. Opens in the browser.',
    es: 'Requiere verificación en dos pasos. Se abre en el navegador.',
  );
  static String senderName(AppLang l) => _pick(
    l,
    en: 'Sender name (optional)',
    es: 'Nombre del remitente (opcional)',
  );
  static String imapServer(AppLang l) =>
      _pick(l, en: 'IMAP server (to read)', es: 'Servidor IMAP (para leer)');
  static String imapPort(AppLang l) =>
      _pick(l, en: 'IMAP port', es: 'Puerto IMAP');
  static String modelLabel(AppLang l) => _pick(l, en: 'Model', es: 'Modelo');
  static String createGmailAppPassword(AppLang l) => _pick(
    l,
    en: 'Create a Gmail app password',
    es: 'Crear app password de Gmail',
  );
  static String missingPermission(String label, AppLang l) => _pick(
    l,
    en: 'Missing $label permission — tap to grant',
    es: 'Falta permiso de $label — toca para conceder',
  );
  static String memoryUnavailable(AppLang l) =>
      _pick(l, en: 'Memory unavailable', es: 'Memoria no disponible');
  static String savedMemories(AppLang l) =>
      _pick(l, en: 'Saved memories', es: 'Recuerdos guardados');
  static String aboutSubtitle(
    String version,
    bool neuralInstalled,
    String model,
    AppLang l,
  ) {
    final neural = neuralInstalled
        ? _pick(l, en: 'installed', es: 'instalada')
        : _pick(l, en: 'not installed', es: 'no instalada');
    final voice = _pick(l, en: 'Neural voice', es: 'Voz neuronal');
    final mdl = _pick(l, en: 'Model', es: 'Modelo');
    return 'v$version · $voice: $neural · $mdl: $model';
  }

  // ── HUD / mode switch ────────────────────────────────────────────────────
  static String modeCar(AppLang l) => _pick(l, en: 'CAR', es: 'CARRO');
  static String modeNormal(AppLang l) => _pick(l, en: 'NORMAL', es: 'NORMAL');
  static String speedSource(AppLang l) =>
      _pick(l, en: '🛰️ GPS + accelerometer', es: '🛰️ GPS + acelerómetro');

  // ── Pet screen status + overlays ─────────────────────────────────────────
  static String statusSpeaking(AppLang l) => _pick(l, en: '…', es: '…');
  static String which(AppLang l) => _pick(l, en: 'Which one?', es: '¿A cuál?');
  static String whichCalendar(AppLang l) =>
      _pick(l, en: 'Which calendar?', es: '¿En qué calendario?');
  static String whichEmail(AppLang l) =>
      _pick(l, en: 'Which email?', es: '¿A cuál correo?');
  static String reviewEmail(AppLang l) =>
      _pick(l, en: 'Review the email', es: 'Revisa el correo');
  static String to(AppLang l) => _pick(l, en: 'To', es: 'Para');
  static String subject(AppLang l) => _pick(l, en: 'Subject', es: 'Asunto');
  static String message(AppLang l) => _pick(l, en: 'Message', es: 'Mensaje');
  static String send(AppLang l) => _pick(l, en: 'Send', es: 'Enviar');
  static String view(AppLang l) => _pick(l, en: 'View', es: 'Ver');
  static String close(AppLang l) => _pick(l, en: 'Close', es: 'Cerrar');
  static String noPreview(AppLang l) =>
      _pick(l, en: 'No preview', es: 'Sin vista previa');
  static String yes(AppLang l) => _pick(l, en: 'Yes', es: 'Sí');
  static String no(AppLang l) => _pick(l, en: 'No', es: 'No');

  // ── Astro's spoken/canned lines ──────────────────────────────────────────
  static String wakeAck(AppLang l) => _pick(
    l,
    en: "I'm here! What do you need?",
    es: '¡Aquí estoy! ¿Qué necesitas?',
  );
  static String notHeard(AppLang l) => _pick(
    l,
    en: "Say that again? I didn't catch it.",
    es: '¿Me repites? No te escuché bien.',
  );
  static String oops(AppLang l) => _pick(
    l,
    en: 'Oops, my connection glitched. Try again?',
    es: 'Uy, se me enredó la conexión. ¿Probamos otra vez?',
  );
  static String reviewEmailSpoken(AppLang l) => _pick(
    l,
    en: 'Review the email and tap send.',
    es: 'Revisa el correo y toca enviar.',
  );
  static String confirmMessage(String name, AppLang l) => _pick(
    l,
    en: 'Send the message to $name?',
    es: '¿Le mando el mensaje a $name?',
  );
  static String confirmWrite(String name, AppLang l) =>
      _pick(l, en: 'Write to $name?', es: '¿Le escribo a $name?');
  static String contactNotFound(String name, AppLang l) => _pick(
    l,
    en: "I couldn't find $name in your contacts.",
    es: 'No encontré a $name en tus contactos.',
  );
  static String messageLeft(String name, AppLang l) => _pick(
    l,
    en: "Done, I left the message for $name.",
    es: 'Listo, te dejé el mensaje para $name.',
  );
  static String callingNow(String name, AppLang l) =>
      _pick(l, en: "I'm calling $name now.", es: 'Ya estoy llamando a $name.');
  static String whoToMessage(AppLang l) =>
      _pick(l, en: 'Who should I write to?', es: '¿A quién le escribo?');
  static String whoToCall(AppLang l) =>
      _pick(l, en: 'Who should I call?', es: '¿A quién llamo?');
  static String whichEmailSpoken(AppLang l) =>
      _pick(l, en: 'Which email?', es: '¿A cuál correo?');
  static String whichCalendarSpoken(AppLang l) => _pick(
    l,
    en: 'Which calendar should I save it to?',
    es: '¿En qué calendario lo guardo?',
  );
  static String yesOrNo(AppLang l) =>
      _pick(l, en: 'Yes or no?', es: '¿Sí o no?');
  static String tapYesOrNo(AppLang l) =>
      _pick(l, en: 'Tap yes or no.', es: 'Toca sí o no.');
  static String doIt(AppLang l) => _pick(l, en: 'Go ahead?', es: '¿Lo hago?');

  // ── Tool results (fed to the model, which answers in the active language) ──
  // phone
  static String callFailed(AppLang l) => _pick(
    l,
    en: "I couldn't make the call.",
    es: 'No pude hacer la llamada.',
  );
  static String messageReady(String contact, AppLang l) => _pick(
    l,
    en: 'Message ready for $contact.',
    es: 'Mensaje listo para $contact.',
  );
  static String messageOpenFailed(AppLang l) => _pick(
    l,
    en: "I couldn't open the message.",
    es: 'No pude abrir el mensaje.',
  );
  // device
  static String volumeSet(int level, AppLang l) =>
      _pick(l, en: 'Volume at $level%.', es: 'Volumen en $level%.');
  static String volumeUp(AppLang l) =>
      _pick(l, en: 'Turned the volume up.', es: 'Subí el volumen.');
  static String volumeDown(AppLang l) =>
      _pick(l, en: 'Turned the volume down.', es: 'Bajé el volumen.');
  static String flashlightOn(AppLang l) =>
      _pick(l, en: 'Flashlight on.', es: 'Linterna encendida.');
  static String flashlightOff(AppLang l) =>
      _pick(l, en: 'Flashlight off.', es: 'Linterna apagada.');
  static String cantOpenApps(AppLang l) => _pick(
    l,
    en: "I can't open apps on this device.",
    es: 'No puedo abrir apps en este dispositivo.',
  );
  static String openingApp(String app, AppLang l) =>
      _pick(l, en: 'Opening $app.', es: 'Abriendo $app.');
  static String appNotFound(String app, AppLang l) => _pick(
    l,
    en: 'I couldn\'t find the "$app" app.',
    es: 'No encontré la app "$app".',
  );
  // calendar
  static String eventCreated(String title, AppLang l) => _pick(
    l,
    en: 'Done, I scheduled "$title".',
    es: 'Listo, agendé "$title".',
  );
  static String eventCreateFailed(AppLang l) => _pick(
    l,
    en: "I couldn't create the calendar event.",
    es: 'No pude crear el evento en el calendario.',
  );
  // map
  static String navigatingTo(String dest, AppLang l) =>
      _pick(l, en: 'Navigating to $dest.', es: 'Navegando hacia $dest.');
  static String showingNearby(String query, AppLang l) => _pick(
    l,
    en: 'Showing $query nearby on the map.',
    es: 'Te muestro $query cerca en el mapa.',
  );
  static String cantOpenMap(AppLang l) =>
      _pick(l, en: "I couldn't open the map.", es: 'No pude abrir el mapa.');
  // communication
  static String emailSent(String to, AppLang l) => _pick(
    l,
    en: 'Done, I sent the email to $to.',
    es: 'Listo, envié el correo a $to.',
  );
  static String emailSendFailed(AppLang l) => _pick(
    l,
    en: "I couldn't send the email.",
    es: 'No pude enviar el correo.',
  );
  static String mailDraftOpened(String recipient, AppLang l) => _pick(
    l,
    en: 'I opened your mail app with the draft for $recipient.',
    es: 'Abrí tu app de correo con el borrador para $recipient.',
  );
  static String cantOpenMail(AppLang l) => _pick(
    l,
    en: "I couldn't open your mail app.",
    es: 'No pude abrir tu app de correo.',
  );
  static String mailAppOpened(AppLang l) =>
      _pick(l, en: 'I opened your mail app.', es: 'Abrí tu app de correo.');
  static String noEmailsFound(AppLang l) =>
      _pick(l, en: "I didn't find any emails.", es: 'No encontré correos.');
  static String noRecentNotifications(AppLang l) => _pick(
    l,
    en:
        "I have no recent notifications. If that's odd, grant notification "
        'access in settings.',
    es:
        'No tengo notificaciones recientes. Si es raro, dale acceso a '
        'notificaciones en ajustes.',
  );
  // weather
  static String weatherUnavailable(AppLang l) => _pick(
    l,
    en: "I couldn't check the weather right now.",
    es: 'No pude consultar el clima ahora.',
  );

  // ── Tool catalog (Settings toggles), keyed by AstroTool.name ─────────────
  static String toolLabel(String name, AppLang l) => switch (name) {
    'music' => _pick(l, en: 'Music', es: 'Música'),
    'take_photo' => _pick(l, en: 'Camera', es: 'Cámara'),
    'calendar' => _pick(l, en: 'Calendar', es: 'Calendario'),
    'comunicacion' => _pick(l, en: 'Communication', es: 'Comunicación'),
    'device' => _pick(l, en: 'Device', es: 'Dispositivo'),
    'mapa' => _pick(l, en: 'Maps', es: 'Mapas'),
    'clima' => _pick(l, en: 'Weather', es: 'Clima'),
    'timer' => _pick(l, en: 'Timer', es: 'Temporizador'),
    'phone' => _pick(l, en: 'Calls', es: 'Llamadas'),
    'web_search' => _pick(l, en: 'Web search', es: 'Búsqueda web'),
    'remember_fact' => _pick(l, en: 'Memory', es: 'Memoria'),
    _ => name,
  };

  static String toolSubtitle(String name, AppLang l) => switch (name) {
    'music' => _pick(
      l,
      en: 'Play and control music',
      es: 'Poner y controlar la música',
    ),
    'take_photo' => _pick(
      l,
      en: 'Take photos and save them to the gallery',
      es: 'Tomar fotos y guardarlas en la galería',
    ),
    'calendar' => _pick(
      l,
      en: 'Create events and reminders',
      es: 'Crear eventos y recordatorios',
    ),
    'comunicacion' => _pick(
      l,
      en: 'Email and notifications',
      es: 'Correo y notificaciones',
    ),
    'device' => _pick(
      l,
      en: 'Brightness, volume, flashlight and open apps',
      es: 'Brillo, volumen, linterna y abrir apps',
    ),
    'mapa' => _pick(
      l,
      en: 'Navigate and find nearby places',
      es: 'Navegar y buscar lugares cerca',
    ),
    'clima' => _pick(l, en: "A place's weather", es: 'El tiempo de un lugar'),
    'timer' => _pick(l, en: 'Timers and alarms', es: 'Timers y alarmas'),
    'phone' => _pick(
      l,
      en: 'Call and send messages',
      es: 'Llamar y enviar mensajes',
    ),
    'web_search' => _pick(
      l,
      en: 'Search the internet for info',
      es: 'Buscar información en internet',
    ),
    'remember_fact' => _pick(
      l,
      en: 'Remember durable things across trips',
      es: 'Recordar cosas durables entre viajes',
    ),
    _ => '',
  };

  static String permissionName(String key, AppLang l) => switch (key) {
    'camera' => _pick(l, en: 'camera', es: 'cámara'),
    'calendar' => _pick(l, en: 'calendar', es: 'calendario'),
    'contacts' => _pick(l, en: 'contacts', es: 'contactos'),
    'location' => _pick(l, en: 'location', es: 'ubicación'),
    'phone' => _pick(l, en: 'phone', es: 'teléfono'),
    _ => key,
  };

  // ── Command palette ──────────────────────────────────────────────────────
  static String commandsTitle(AppLang l) =>
      _pick(l, en: 'What can I ask?', es: '¿Qué le puedo preguntar?');

  /// A runnable example utterance for a tool (by AstroTool.name), shown as a
  /// tappable command. Returns '' for names without an example.
  static String commandExample(String tool, AppLang l) => switch (tool) {
    'get_context' => _pick(l, en: 'What time is it?', es: '¿Qué hora es?'),
    'music' => _pick(l, en: 'Play some music', es: 'Pon algo de música'),
    'take_photo' => _pick(l, en: 'Take a photo', es: 'Tómame una foto'),
    'calendar' => _pick(
      l,
      en: 'Add a meeting tomorrow at 3',
      es: 'Agenda una reunión mañana a las 3',
    ),
    'comunicacion' => _pick(
      l,
      en: 'Do I have new email?',
      es: '¿Tengo correos nuevos?',
    ),
    'device' => _pick(l, en: 'Turn up the brightness', es: 'Sube el brillo'),
    'mapa' => _pick(l, en: 'Take me home', es: 'Llévame a casa'),
    'clima' => _pick(
      l,
      en: "What's the weather like?",
      es: '¿Cómo está el clima?',
    ),
    'timer' => _pick(
      l,
      en: 'Set a 5-minute timer',
      es: 'Pon un temporizador de 5 minutos',
    ),
    'phone' => _pick(l, en: 'Call mom', es: 'Llama a mamá'),
    'web_search' => _pick(
      l,
      en: "Search today's news",
      es: 'Busca noticias de hoy',
    ),
    'remember_fact' => _pick(
      l,
      en: 'Remember that I like jazz',
      es: 'Recuerda que me gusta el jazz',
    ),
    _ => '',
  };
}
