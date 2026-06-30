# Chispa — AI Pet para el carro (Flutter)

App Flutter (Android, **sin root**) de una mascota virtual con IA que vive en un celular montado
en el tablero. Lee sensores del carro y del teléfono, reacciona con animaciones y voz, y consulta
o ejecuta acciones por un cerebro agéntico (tool use).

Documento técnico de referencia: [pet.md](pet.md). Prototipo visual: [ai-pet-sensores-todo.html](ai-pet-sensores-todo.html).
**Este `CLAUDE.md` manda sobre el `.md` si hay conflicto.**

---

## Principio rector

Todo en el proyecto sigue el mismo patrón. No lo rompas:

```
sensor  ->  filtro/umbral  ->  estado  ->  ánimo (cascada)  ->  animación + frase + voz
```

- Cada fuente de datos entra por **su propio `Stream`** y nunca toca la UI directamente.
- Todos los streams se **combinan en un único `AppState`** inmutable.
- Una **cascada de prioridades** resuelve `AppState` → un solo `Mood`. La navegación es una capa de postura encima.
- **Lo básico funciona sin OBD y sin root.** OBD y navegación *suman* entradas, no son requisitos.
  Nunca hagas que una feature básica dependa de hardware opcional.

---

## Stack y decisiones fijas

> **Idioma del código: SOLO inglés.** Identificadores, comentarios, docs y nombres de archivo,
> todo en inglés. **Excepción: la voz de Chispa es bilingüe (inglés + español).** Pero nunca como
> strings sueltos en la lógica: el `MoodResolver` emite una **línea semántica** (`SpeechLine`,
> sin idioma) y `voice/speech_catalog.dart` guarda el texto EN + ES. Agregar un idioma = otra
> entrada en el catálogo, sin tocar el resolver.

| Capa | Elección | Notas |
|---|---|---|
| Estado / DI | **Riverpod 2** (`flutter_riverpod`) | Providers reactivos, testeables; codegen opcional |
| Combinar streams | **`rxdart`** (`CombineLatestStream`) | De N streams a un `AppState` |
| Modelos inmutables | **`freezed`** + `json_serializable` | `AppState`, `MoodState`, mensajes de IA |
| Personaje | **`rive`** | State Machine con input numérico `mood` + inputs de postura |
| OBD BLE | `flutter_blue_plus` | ELM327, PIDs Modo 01/03/04 |
| Navegación | `flutter_notification_listener` + servicio Kotlin | Notificación de Google Maps |
| Movimiento | `sensors_plus` | `userAccelerometerEvents`, `gyroscopeEvents` |
| Velocidad | `geolocator` | Campo `speed` (m/s) del GPS, fuente real |
| Luz / proximidad | `light`, `proximity_sensor` | |
| Wake word | `porcupine_flutter` | Local, bajo consumo |
| STT | `speech_to_text` | Captura del comando |
| TTS | **`flutter_tts`** (sistema, activo) → `sherpa_onnx` (Piper offline) después | ver nota abajo |
| IA | `http` a API en la nube (Claude / DeepSeek / OpenAI) | Bucle agéntico propio |

Versiones: Dart 3 con sound null-safety. Flutter canal `stable`. No introduzcas otra librería de
estado (BLoC, GetX, Provider plano) ni otra de combinación de streams sin justificarlo.

---

## Voz: TTS simple activo, neural parqueado

Ahora mismo Chispa habla con el **TTS del sistema** (`flutter_tts`, español, probado en device):
ligero, sin modelo, builds rápidos. El **TTS neuronal offline** (sherpa-onnx + Piper) está listo
pero **parqueado** porque sus libs (`onnxruntime` ~72 MB ×3 ABIs) + el modelo (65 MB) inflaban el
APK a ~297 MB. Estado:

- `lib/voice/tts_provider.dart` → `ttsProvider` devuelve **`SystemTts`** (`flutter_tts`).
  `SilentTts` queda como fallback mudo.
- Neural: deps `sherpa_onnx`/`audioplayers`/`archive`/`path_provider` y el asset `assets/tts/...zip`
  **comentados** en `pubspec.yaml`; `lib/voice/sherpa_tts.dart` aparcado como **`sherpa_tts.dart.off`**.
- Visemas, pipeline, controlador e interfaces **siguen compilando** con cualquiera de los dos.

**Cambiar al neural (3 pasos, también en el doc-comment de `tts_provider.dart`):**
1. `pubspec.yaml`: descomentar las 4 deps + el asset; `flutter pub get`.
2. Renombrar `lib/voice/sherpa_tts.dart.off` → `sherpa_tts.dart`.
3. En `tts_provider.dart`: devolver `SherpaTts()` y llamar `warmUp()` en `PetScreen.initState`.

**Iterar rápido:** usa `flutter run -d <device>` (compila solo el ABI del celu + hot reload), no
`flutter build apk` (APK gordo con las 3 ABIs).

## Arquitectura de carpetas

```
lib/
  main.dart                 # bootstrap, ProviderScope
  app.dart                  # MaterialApp, tema, ruta única (la pantalla del pet)
  core/
    state/
      app_state.dart        # AppState (freezed): todas las señales combinadas
      mood.dart             # enum Mood + MoodState (ánimo + postura nav)
      mood_resolver.dart    # la cascada de prioridades (AppState -> MoodState)
      app_state_provider.dart # CombineLatestStream de todas las fuentes
    config/
      thresholds.dart       # TODOS los umbrales numéricos viven aquí (un solo lugar)
      design_tokens.dart    # colores, fuentes, duraciones (ver sección Diseño)
    util/
      low_pass.dart         # filtro paso-bajo para sensores ruidosos
      calibration.dart      # vector de gravedad y eje "adelante"
  sensors/
    obd/                    # ObdService (BLE), pid parsing, modelo ObdReading
    motion/                 # MotionService (accel + gyro, ya filtrado)
    location/               # SpeedService (GPS + fusión con accel)
    light/                  # LightService (lux -> fase día/atardecer/noche/amanecer)
    proximity/              # ProximityService (cerca/lejos)
    navigation/             # NavService: puente al NotificationListener de Maps
  voice/
    wake_word/              # Porcupine
    stt/                    # speech_to_text
    tts/                    # sherpa-onnx + visemas
    audio_focus.dart        # ducking de la música al hablar
  brain/
    chispa_brain.dart       # bucle agéntico (onThinking, onToolUse)
    tools/
      chispa_tool.dart      # contrato: nombre, descripción, schema, run()
      tool_registry.dart    # registro central
      car_tools.dart        # get_speed, get_engine_status, clear_dtc, get_next_turn, set_brightness
      search_music_tools.dart # búsqueda web (Tavily/Brave) + poner/control música (intents)
  character/
    rive_controller.dart    # mapea MoodState -> inputs de la State Machine de Rive
  ui/
    pet_screen.dart         # pantalla principal
    widgets/                # speedometer, ambient_chip, g_meter, nav_hud, speech_bubble, prox_dot
  platform/
    android/                # MethodChannel/EventChannel: notif listener, brillo, foreground service
android/                    # manifest, permisos, servicio Kotlin, BroadcastReceiver de carga
```

**Reglas de dependencia:** `ui` y `character` dependen de `core/state`. `sensors`, `voice`, `brain`
exponen streams/servicios y **no importan `ui`**. `core` no importa nada de las capas de arriba.
Un servicio de sensor solo produce datos; la decisión de ánimo vive **solo** en `mood_resolver.dart`.

---

## La cascada de ánimo (no la dupliques en otro lado)

`mood_resolver.dart` traduce `AppState` a un único `Mood`, de mayor a menor prioridad:

```
1. agente: thinking / answering   (consulta IA o tool en curso)
2. caricia (proximidad cerca)
3. falla activa (DTC presente)    -> alarm
4. frenada fuerte a vel. alta     -> scared
5. llegada al destino             -> arrival
6. temperatura motor > umbral     -> worried
7. aceleración / RPM altas        -> excited
8. carro quieto un rato           -> sleep
9. reposo                         -> rest (refleja la luz ambiente)
```

La **capa de navegación** se aplica *encima* del `Mood` resuelto, no compite con él: mirada e
inclinación hacia el lado del giro, atención aumentada cuando el giro está cerca. Se modela como
campos aparte en `MoodState` (`gazeDir`, `tiltDir`, `turnImminent`), que el `RiveController` envía
como inputs de postura independientes del input `mood`.

Estados de `Mood`: `rest, excited, scared, worried, alarm, sleep, arrival, lean, bump, pet,
thinking, answering`. Cada uno tiene color, ojos, boca y extras definidos en diseño.

---

## Convenciones de código

- **Umbrales y constantes mágicas → `core/config/thresholds.dart`.** Nunca un número crudo en la
  lógica de ánimo (ej. `tempMotor > 112`). El resolver lee de ahí.
- **Sensores crudos siempre se filtran** antes de entrar al estado. Usa `low_pass.dart`:
  `valor += (objetivo - valor) * factor;` (factor bajo = suave, alto = reactivo). La luz se suaviza
  para que no parpadee bajo un puente.
- **Velocidad = GPS** (`geolocator.speed`). El acelerómetro solo rellena huecos entre lecturas GPS
  (fusión); nunca uses integración de acelerómetro sola como velocidad: acumula error.
- **Modelos inmutables con `freezed`.** Nada de mutar `AppState` en sitio; siempre `copyWith`.
- **Código en inglés**: identificadores, comentarios, docs. La voz de Chispa es bilingüe EN+ES, pero
  vive en `voice/speech_catalog.dart` indexada por `SpeechLine`; el resolver nunca lleva texto crudo.
- **Async:** `Stream`/`Future` idiomáticos, cancela suscripciones en `dispose`/`ref.onDispose`.
- Antes de dar algo por terminado: `dart format .` && `flutter analyze` sin warnings.

---

## Diseño (tokens del prototipo)

Fuente de verdad visual: [ai-pet-sensores-todo.html](ai-pet-sensores-todo.html). Llévalo a
`core/config/design_tokens.dart`.

**Tipografía**
- `Fredoka` (w400/500/600): etiquetas de UI, burbuja de diálogo, botones.
- `Space Mono` (w400/700): números (velocímetro), lecturas, mono.

**Color base**
- Tinta `#e8edf5`, tenue `#5f6a7d`, acento `#43d6cf`.
- Fondo: radial-gradient que cambia con la luz ambiente.

**Paletas por luz ambiente** (cuerpo del pet + acento + apertura de ojos + fondo):

| Fase | Cuerpo | Acento | bg1 / bg2 | Ojo |
|---|---|---|---|---|
| día | `#43d6cf` | `#43d6cf` | `#26384f` / `#101b2c` | 1.0 |
| atardecer | `#f2a93b` | `#f2a93b` | `#3a2433` / `#160d18` | 0.92 |
| noche | `#6f79c4` | `#8b95e6` | `#0b0f18` / `#04060a` | 0.5 |
| amanecer | `#9fb0e0` | `#f5a0b5` | `#2c2742` / `#16131f` | 0.82 |

**Colores por ánimo de movimiento** (override del cuerpo): excited `#f2a93b`, scared `#7fb6ff`
(número/arco en alerta `#ff4d57`), bump `#b48bff`.

**Animación de pensar:** globo con 3 puntos que laten, cabeza ladeada, mirada arriba. Se enciende al
lanzar la petición a la IA, se apaga al recibir respuesta. En tool use muestra qué herramienta consulta.

**Animación de hablar (visemas):** la boca alterna 5 formas (cerrada m/b/p, abierta pequeña, abierta
amplia 'a', redonda o/u, ancha e/i) en orden variado y ritmo irregular. Se enciende con el callback
de inicio del TTS y se apaga con el de fin.

En producción el personaje es **Rive** con State Machine (input `mood` + inputs de postura); el SVG/CSS
del HTML es solo referencia de la sensación, no se porta tal cual.

---

## Cerebro agéntico (tool use)

```
usuario -> modelo -> ¿pide tool? -> ejecutas local -> resultado -> modelo -> ... -> respuesta final
```

- `ChispaTool`: contrato (nombre, descripción, schema JSON, `run`). `ToolRegistry`: registro central
  (agregar tool = subclase + registrar). `ChispaBrain`: corre el bucle con callbacks `onThinking` y
  `onToolUse` para enganchar las animaciones (pensando / "consultando X" / hablando).
- **Máximo 3–5 tools activas** con descripciones bien distintas; la precisión cae con más. Si crecen,
  agrupa o divide por agente.
- **Tools que cambian algo** (`clear_dtc` Modo 04, `set_brightness`) se marcan y **piden confirmación
  por voz** antes de ejecutar. Las de solo lectura corren sin confirmar.
- Cerebro **en la nube** (Claude / DeepSeek / OpenAI por API). No usamos Ollama ni modelos locales.
  **Nunca** trucos sobre sesiones web/Plus; solo API con key.
- Música sin atarse a Spotify: `poner_musica` por intent `MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH`;
  `control_musica` por sesiones de media del sistema. Búsqueda web: Tavily (empezar) o Brave.

---

## Android, permisos y ciclo de vida (sin root)

- Permisos: `RECORD_AUDIO`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MICROPHONE` (A14),
  ubicación, notificaciones (listener de Maps). Opcionales una vez: `SYSTEM_ALERT_WINDOW`
  (mostrar UI a pantalla completa al cargar), `WRITE_SETTINGS` (brillo del sistema).
- **Foreground service** tipo `microphone` siempre activo para wake word; pide quitar optimización de batería.
- **Despertar al cargar:** `BroadcastReceiver` de `ACTION_POWER_CONNECTED`/`DISCONNECTED` registrado
  desde el foreground service (no en el manifest). Distingue carga USB de carga normal; combina
  señales (USB + movimiento + hora) para no abrir Chispa en casa.
- **Brillo:** ventana propia con `screenBrightness` (sin permiso); sistema con `WRITE_SETTINGS`.
  Regla: brillo por luz ambiente siempre; atenúa con carro quieto (acelerómetro).
- **Foco de audio:** al hablar Chispa baja la música y la restaura al terminar.

---

## Comandos

```bash
flutter pub get
flutter run                              # dispositivo Android conectado
flutter analyze                          # sin warnings antes de terminar
dart format .
flutter test                             # unit + widget
dart run build_runner build --delete-conflicting-outputs   # freezed / riverpod / json
flutter build apk --release
```

---

## Pruebas

- **Prioridad: `mood_resolver`.** Es pura (`AppState` → `MoodState`); cúbrela con tests de tabla
  para cada nivel de la cascada y los empates de prioridad. Es el corazón del comportamiento.
- Servicios de sensores: testea el parsing (PIDs OBD, deltas de movimiento) con datos fijos; mockea
  el hardware. Los streams se prueban con `StreamController` falsos.
- `ChispaBrain`: testea el bucle con un cliente HTTP falso que devuelve tool_calls predecibles.
- Usa TDD para lógica nueva no trivial (resolver, parsers, fusión de velocidad).

---

## Orden de construcción sugerido

1. Esqueleto Flutter: `AppState`, `Mood`, `mood_resolver`, `CombineLatestStream` de streams *fake*.
2. `pet_screen` + widgets básicos leyendo `MoodState` (sin Rive aún, placeholder).
3. Sensores reales del teléfono: movimiento, GPS, luz, proximidad.
4. Personaje en Rive con input `mood` + postura.
5. OBD BLE (`flutter_blue_plus`), PIDs de lectura.
6. Navegación: listener de Maps en Kotlin + puente.
7. Voz: Porcupine → `speech_to_text` → TTS sherpa-onnx con visemas.
8. Cerebro: `ChispaTool` / `ToolRegistry` / `ChispaBrain`, en la nube (Claude / DeepSeek / OpenAI).
9. Brillo por luz/movimiento y despertar al cargar por USB.
