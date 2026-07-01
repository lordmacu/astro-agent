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
  static String llmApiKey(AppLang l) =>
      _pick(l, en: 'LLM API key', es: 'API key del LLM');
  static String searchApiKey(AppLang l) =>
      _pick(l, en: 'Web search API key', es: 'API key de búsqueda web');
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
}
