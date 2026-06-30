# Chispa — AI Pet para el carro

Documento técnico del proyecto. Mascota virtual con IA que vive en un celular montado en el tablero, reacciona a cómo manejas y te acompaña por voz.

---

## 1. Visión general

Chispa es un personaje en pantalla que corre en un celular Android sin uso, montado en el tablero. Reacciona en tiempo real a los datos del carro y del propio teléfono, conversa por voz, y consulta información o controla herramientas cuando hace falta.

**Principios de diseño**

- Una sola máquina de estados recibe varias fuentes de datos y produce un solo estado de ánimo y una sola animación.
- Cada fuente entra por su propio `Stream` y se combina en un objeto de estado.
- Lo básico funciona sin OBD y sin root, apenas montas el celular y das permisos.
- El OBD y la navegación suman entradas, no son requisitos.

**Patrón mental repetido en todo el proyecto**

```
sensor  ->  umbral  ->  estado  ->  animación + frase
```

---

## 2. Decisión de diseño: sin root

El proyecto funciona sin root, para que sea instalable por cualquiera y no ate el código a un celular modificado. Casi todo funciona igual sin root: sensores, OBD por Bluetooth, GPS, luz, proximidad, navegación por Notification Listener, voz con Porcupine, TTS y tools.

Lo que cambia sin root, resuelto con permisos que el usuario concede una vez:

| Función | Sin root |
|---|---|
| Abrir app a pantalla completa al cargar | Requiere permiso de superposición `SYSTEM_ALERT_WINDOW` |
| Brillo de la propia ventana | Libre, con `screenBrightness` |
| Brillo del sistema | Requiere `WRITE_SETTINGS` |
| Servicio de micrófono siempre activo | Foreground service + quitar optimización de batería |
| Audio crudo del micrófono | No, se usa el audio ya procesado por el sistema |

Nada de esto bloquea el proyecto. Solo pide cuidado en la primera configuración.

---

## 3. Hardware

| Componente | Detalle |
|---|---|
| Celular | Android sin uso, sin necesidad de root |
| Adaptador OBD | Vgate iCar Pro 2S, BLE (Bluetooth Low Energy) |
| Soporte | Montaje en tablero, apuntando al conductor |
| Micrófono | El del celular, o uno externo para captar mejor de lejos |
| Carro | Lectura de sensores en cualquier modelo con OBD-II |

---

## 4. Arquitectura de software

### 4.1 Fuentes de datos

| Fuente | Vía | Requiere |
|---|---|---|
| OBD-II | ELM327 por BLE | Adaptador |
| Navegación | NotificationListenerService de Google Maps | Permiso de notificaciones |
| Movimiento | Acelerómetro + giroscopio | Nada |
| Velocidad | GPS | Permiso de ubicación |
| Luz ambiente | Sensor de luz | Nada |
| Proximidad | Sensor de proximidad | Nada |
| Voz | Micrófono | Permiso de micrófono |

### 4.2 Máquina de estados

Todas las fuentes alimentan un objeto de estado. Una cascada de prioridades resuelve los conflictos y devuelve un solo ánimo. La navegación se aplica como capa de postura encima del ánimo.

**Jerarquía de ánimo (de mayor a menor prioridad)**

```
1. agente: pensando / respondiendo   (consulta a la IA o tool)
2. caricia (proximidad)
3. falla activa (DTC)        -> alarma
4. frenada fuerte            -> susto
5. llegada al destino        -> celebración
6. temperatura alta del motor-> preocupación
7. aceleración / RPM altas   -> emoción
8. carro quieto un rato      -> sueño
9. reposo                    -> tranquilo (refleja la luz ambiente)
```

**Capa de navegación (encima del ánimo)**

- Mirada y leve inclinación hacia el lado del giro.
- Atención aumentada cuando el giro está cerca.
- Resaltado de la banda de maniobra.

### 4.3 Paquetes Flutter

| Función | Paquete |
|---|---|
| OBD por BLE | `flutter_blue_plus` |
| Notificaciones de Maps | `flutter_notification_listener` |
| Acelerómetro y giroscopio | `sensors_plus` |
| Velocidad por GPS | `geolocator` |
| Luz ambiente | `light` |
| Proximidad | `proximity_sensor` |
| Palabra de activación | `porcupine_flutter` |
| Reconocimiento de voz | `speech_to_text` |
| Voz (TTS) | `flutter_tts` o `sherpa_onnx` |
| Animación del personaje | `rive` |
| Llamadas a la IA | `http` (API de la nube u Ollama local) |

---

## 5. El personaje y las animaciones

### 5.1 Motor de animación

Para producción se usa **Rive**. Defines un State Machine con un input numérico de "mood" y Rive interpola las animaciones solo. Es la forma correcta para un pet expresivo, mejor que dibujar a mano.

### 5.2 Estados de ánimo

| Ánimo | Disparador | Señales visuales |
|---|---|---|
| Tranquilo / reposo | Sin eventos | Color de la luz ambiente, respiración lenta |
| Emoción | Acelerar, RPM altas | Ámbar, ojos abiertos, boca abierta, rebote |
| Susto | Frenada fuerte a velocidad alta | Azul, ojos muy abiertos, temblor, gota de sudor |
| Preocupación | Motor sobre 112 °C | Naranja, ceño, respiración rápida |
| Alarma | Código de falla | Rojo, signo de exclamación |
| Sueño | Carro quieto varios segundos | Gris, ojos caídos, "z" |
| Atención (nav) | Giro cercano | Mirada e inclinación hacia el giro |
| Llegada | Llegada al destino | Verde, estrella, celebración |
| Inclinación (curva) | Fuerza lateral | Tilt hacia el lado |
| Brinco (bache) | Pico vertical | Saltito, sorpresa |
| Caricia | Proximidad cercana | Ojos cerrados, sonrojo, corazones |
| Pensando | Consulta a la IA o tool | Globo de pensamiento, puntitos, mirada arriba |
| Hablando | TTS activo | Boca alternando formas (visemas) |

### 5.3 Animación de pensar

Se activa al lanzar la petición a la IA y se apaga al recibir la respuesta. Globo de pensamiento con tres puntos que laten, cabeza ladeada y mirada hacia arriba. En tool use, además se muestra qué herramienta está consultando.

### 5.4 Animación de hablar (visemas)

La boca no solo abre y cierra. Alterna entre cinco formas que imitan los sonidos del habla.

| Visema | Sonido | Forma |
|---|---|---|
| Cerrada | m, b, p | Línea fina |
| Abierta pequeña | neutra | Óvalo pequeño |
| Abierta amplia | a | Boca grande |
| Redonda | o, u | Círculo |
| Ancha | e, i | Óvalo ancho y bajo |

Las formas salen en orden variado y a ritmo irregular para verse natural. En la app se enciende con el callback de inicio del TTS y se apaga con el de fin. Una mejora futura es lip-sync real, eligiendo el visema según el fonema o el audio.

---

## 6. OBD-II

### 6.1 Tres niveles de acceso

**Leer.** El 90 % del uso. Universal y seguro.

**Acción estándar.** El Modo 04 borra los códigos de falla y apaga el testigo de check engine. Funciona en cualquier carro con un ELM327 normal.

**Control de actuadores (bidireccional).** Va por UDS con comandos propios del fabricante, con "security access" seed/key. Descartado por riesgo y complejidad. En carros 2026 aparece SecOC, que firma cada mensaje CAN, así que el replay simple ya no sirve. Abrir vidrios vive en el bus de confort detrás de un gateway que filtra el puerto OBD.

### 6.2 PIDs de lectura útiles

| Dato | Modo/PID | Uso para Chispa |
|---|---|---|
| RPM | 01 0C | Emoción al acelerar |
| Velocidad | 01 0D | Ritmo, detección de frenadas |
| Temperatura refrigerante | 01 05 | Salud del motor, preocupación |
| Carga del motor | 01 04 | Esfuerzo en subidas |
| Posición del acelerador | 01 11 | Intención de acelerar |
| Flujo de aire (MAF) | 01 10 | Modo eco |
| Voltaje de batería | 01 42 | Aviso de arranque débil |
| Códigos de falla (DTC) | 03 | Alarma |
| Datos congelados | 02 | Contexto del error |
| Borrar DTC | 04 | "Chispa, apaga la alerta" |

### 6.3 Combinaciones de sensores

Lo interesante es combinar, no leer sueltos.

- Acelerador a fondo, velocidad que no sube y RPM altas: posible problema, cara de duda.
- Temperatura subiendo y carga alta en una loma: "vamos con cuidado".
- Velocidad cae rápido con RPM al ralentí: susto de frenada.
- Viaje largo y suave: felicitación por buen manejo.

---

## 7. Detección de navegación (Google Maps)

### 7.1 Notification Listener (recomendado, sin root)

Maps publica una notificación persistente mientras navega.

- Filtra por el paquete `com.google.android.apps.maps`.
- Revisa el flag `FLAG_ONGOING_EVENT`.
- `EXTRA_TITLE`: maniobra y calle.
- `EXTRA_TEXT`: distancia y tiempo restante.
- `EXTRA_SUB_TEXT`: ETA o nombre de ruta.

El servicio nativo va en Kotlin y se conecta por MethodChannel o EventChannel. El paquete `flutter_notification_listener` hace casi todo. El tipo de flecha se deduce por palabras clave del título o por el ícono de la notificación.

### 7.2 HUD de navegación

- Banda superior con flecha de maniobra, distancia y calle.
- Barra de proximidad a la maniobra.
- Chispa mira hacia el lado del giro y se pone atenta al acercarse.

---

## 8. Sensores del celular

### 8.1 Movimiento

`sensors_plus` entrega los eventos con x, y, z.

- `userAccelerometerEvents`: longitudinal (acelerar y frenar) y vertical (baches).
- `gyroscopeEvents`: rotación, para curvas.

Mapeo a reacciones: frenada por desaceleración, curva por giroscopio, bache por pico vertical, arranque por el sensor de carga.

### 8.2 Filtro de ruido

El sensor crudo tiembla. Se suaviza con un filtro paso-bajo.

```dart
valor += (objetivo - valor) * factor; // factor bajo suaviza, alto reacciona rápido
```

### 8.3 Calibración

El celular va montado en cualquier ángulo. Hay que calibrar el vector de gravedad y saber cuál eje es "adelante". Se resuelve con una calibración corta al arrancar.

### 8.4 Velocidad sin OBD

La fuente real es el **GPS**. `geolocator` entrega el campo `speed` en metros por segundo, ya calculado por el chip.

El acelerómetro solo rellena los huecos entre lecturas del GPS, que llega una o dos veces por segundo. Entre dato y dato se integra la aceleración para suavizar, y al llegar el siguiente GPS se corrige. Eso es fusión de sensores. El acelerómetro solo no sirve porque la integración acumula error y la velocidad miente en un minuto.

### 8.5 Luz y proximidad

- `light`: lux del ambiente, con umbrales para día, atardecer, noche y amanecer. Conviene suavizar el cambio para que no parpadee bajo un puente.
- `proximity_sensor`: evento binario cerca/lejos. Cerca dispara la caricia, lejos la termina.

---

## 9. Voz tipo Alexa

### 9.1 Flujo en dos etapas

```
1. Palabra de activación (wake word)   -> motor liviano, siempre activo, local
2. Captura del comando                  -> reconocimiento de voz completo
3. Cerebro                              -> IA con tools y contexto del viaje
4. Voz                                  -> TTS habla, Chispa anima la boca
```

### 9.2 Componentes

- Wake word: **Porcupine** de Picovoice, local y de bajo consumo. Alternativas: openWakeWord, Vosk.
- Comando: `speech_to_text`.
- Respuesta hablada: `flutter_tts` o un TTS neuronal.

### 9.3 Calidad del micrófono a distancia

El micrófono del celular es MEMS, hecho para captar la voz de cerca. El volumen cae rápido con la distancia, y al duplicar la distancia llega con la cuarta parte de potencia. El problema real en el carro es la relación señal a ruido, por motor, llantas, viento y música. La supresión de ruido del sistema a veces borra la voz lejana.

Mejoras para el carro:

- Monta el celular cerca y apuntando al conductor.
- Considera un micrófono externo, Bluetooth o de visera, o el del carro por manos libres.
- Suma un botón físico o un toque como respaldo de la palabra de activación.
- Aplica cancelación de eco, para que la voz de Chispa no dispare el reconocimiento.

### 9.4 Servicio en primer plano (Android)

- Foreground service con tipo `microphone`.
- Permiso `RECORD_AUDIO`.
- En Android 14, permiso `FOREGROUND_SERVICE_MICROPHONE`.
- Notificación persistente, aceptable en un carro.
- Sin root, pide al usuario quitar la optimización de batería para tu app.

### 9.5 Foco de audio

Cuando Chispa habla, baja el volumen de la música y lo sube al terminar.

---

## 10. TTS neuronal

| Opción | Tipo | Notas |
|---|---|---|
| edge-tts | Nube, no oficial | Endpoint de Edge sobre Azure, WebSocket + SSML, gratis, puede romperse |
| Azure Speech | Nube, oficial | La versión legal de edge-tts |
| Google Cloud Neural2 | Nube, oficial | Voces neuronales de calidad |
| OpenAI / ElevenLabs | Nube, oficial | Muy expresivas, pago por carácter |
| sherpa-onnx + Piper/VITS | En el dispositivo | Offline, neuronal, español, recomendado |
| flutter_tts (voces de Google) | Sistema | Lo más simple, menos control |

**Recomendación.** En el carro la conexión falla, así que la opción principal es **sherpa-onnx con una voz Piper en español**, todo offline. El paquete `sherpa_onnx` corre en Android e iOS. Una voz Piper pesa unos 30 MB y el runtime unos 25 MB, alrededor de 55 MB una sola vez. Responde en menos de un segundo y no envía el texto a terceros.

El estado "hablando" se enciende con el callback de inicio del TTS y se apaga con el de fin. Ahí corre la alternancia de visemas.

---

## 11. Disparadores de encendido y apagado

### 11.1 Despertar al cargar

Cuando enciendes el carro, el cargador da corriente. Android emite un broadcast `ACTION_POWER_CONNECTED` al conectar y `ACTION_POWER_DISCONNECTED` al desconectar. Un `BroadcastReceiver` los escucha y lanza o duerme a Chispa.

Matiz sin root: desde Android 10 el sistema bloquea lanzar una actividad a pantalla completa desde segundo plano. Caminos:

- Solo arrancar trabajo en segundo plano (micrófono, lógica): se puede directo.
- Mostrar la interfaz encima: requiere el permiso de superposición `SYSTEM_ALERT_WINDOW`, que el usuario concede una vez.

Detalles prácticos:

- El receiver de carga no se declara solo en el manifiesto en Android moderno. Va registrado desde un foreground service ligero siempre activo.
- Distingue "cargando por USB" de "cargando", para no abrir Chispa en la casa.
- Combina señales: cargando por USB más movimiento más hora, para decidir cuándo despierta y cuándo duerme.

---

## 12. Brillo y ahorro de batería

### 12.1 Control de brillo

- Brillo de la propia ventana: `screenBrightness`, sin permisos. Alcanza porque tu app está en primer plano.
- Brillo del sistema: requiere `WRITE_SETTINGS`, concedido una vez.

### 12.2 Disparadores y eficiencia

- **Movimiento (mejor para ahorrar).** El acelerómetro gasta poquísimo. Quieto baja brillo, en movimiento sube.
- **Luz ambiente (mejor ahorro natural).** Baja brillo de noche, lo sube de día.
- **Sonido (con cuidado).** Tener el micrófono siempre abierto gasta más de lo que ahorra. Solo vale si ya corres la palabra de activación y reutilizas ese audio.

**Recomendación.** Brillo por luz ambiente siempre. Atenúa cuando el carro lleva rato quieto, por acelerómetro. Suma el sonido solo si el micrófono ya está encendido.

---

## 13. Tool use (arquitectura agéntica)

### 13.1 Idea

La IA recibe una lista de herramientas, decide cuáles usar, tú las ejecutas localmente y le devuelves el resultado. El bucle repite hasta la respuesta final.

```
usuario -> modelo -> ¿pide tool? -> ejecutas -> resultado -> modelo -> ... -> respuesta final
```

Se conecta con las animaciones. Mientras corre el bucle, Chispa está en "pensando". Al llamar una tool dice "consultando...". La respuesta final dispara los visemas.

### 13.2 Componentes (ver `chispa_tools.dart`)

- `ChispaTool`: contrato de una herramienta, con nombre, descripción, esquema y método `run`.
- `ToolRegistry`: registro central. Agregar una tool nueva es crear una subclase y registrarla.
- `ChispaBrain`: corre el bucle agéntico contra la API, con callbacks `onThinking` y `onToolUse` para enganchar las animaciones.

### 13.3 Herramientas del carro

`get_speed`, `get_engine_status`, `clear_dtc` (Modo 04), `get_next_turn`, `set_brightness`. Cada una envuelve la fuente real y se le inyecta la función que lee el dato, para quedar desacoplada.

### 13.4 Búsqueda en internet (ver `chispa_tools_search_music.dart`)

Bing cerró su API de búsqueda en agosto de 2025. Hoy las opciones para agentes son Brave, Tavily y Exa.

- **Tavily**: devuelve una respuesta limpia lista para la IA en una sola llamada. Capa gratis de unas 1000 búsquedas al mes. Recomendada para empezar.
- **Brave**: índice propio e independiente, 2000 consultas gratis al mes.

### 13.5 Música

La Web API de Spotify busca y controla reproducción, pero exige Premium y trae restricciones recientes para apps de terceros. La ruta limpia en el carro es no atarse a Spotify:

- `poner_musica`: usa un intent de Android de "reproducir desde búsqueda" (`MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH`). Funciona con cualquier app instalada, sin llave ni Premium.
- `control_musica`: pausar, reanudar, saltar, por los controles de sesión de media del sistema.

### 13.6 Límite de número de tools

La precisión con que el modelo elige la herramienta baja al tener más. Con tres a cinco acierta casi siempre, con diez a quince empiezan los errores, con veinte se confunde seguido. Mantén pocas tools con descripciones bien distintas. Si crecen, agrúpalas o divide en agentes por tema.

### 13.7 Seguridad

Marca las herramientas que cambian algo (borrar códigos, brillo) y pide confirmación por voz antes de ejecutarlas. Las de solo lectura corren sin confirmar.

---

## 14. El cerebro: modelos

### 14.1 En la nube

- **Claude** por API, con tool use.
- **DeepSeek** por API, económico, con tool calling formato estilo OpenAI.
- **OpenAI** por API, con key.

Nota sobre ChatGPT. La suscripción Plus y la API son productos separados con cobros separados. Plus no da acceso a la API. Los trucos que usan la sesión de Plus violan los términos, se rompen seguido y arriesgan la cuenta. Para un carro, no sirven. La única vía estable es la API con key.

### 14.2 Local con tools

Comparativa de soporte de herramientas:

- **Gemma 4** entiende tools de forma nativa, con tokens dedicados. Variantes edge E2B y E4B pensadas para correr en el celular. El E4B trae entrada de audio.
- **Gemma 3** entiende tools, pero con esquema "pythonic" menos limpio. El 4b tiene un sesgo a llamar herramientas hasta en preguntas de charla, molesto para un pet. Si lo usas, ve por una variante afinada y un system prompt estricto.
- **Qwen3 4B**: recomendado. Ligero, charla bien y llama tools de forma confiable. La familia Qwen es el estándar para agentes locales.

Hay un corte de capacidad alrededor de 7 a 9 mil millones de parámetros en modelos de propósito general. Los muy pequeños caen en llamadas de varias herramientas seguidas, pero para Chispa la mayoría son de una sola llamada.

### 14.3 Peso aproximado (cuantización 4 bits)

| Modelo | En disco | En memoria al correr |
|---|---|---|
| Gemma 4 E2B | 1.5 a 2 GB | 2 a 3 GB |
| Gemma 4 E4B | 2.5 a 3 GB | 3 a 4 GB |
| Qwen3 4B | ~2.5 GB | 3 a 4 GB |
| xLAM-2 3B | ~2 GB | 2.5 a 3.5 GB |

A 8 bits el peso casi se duplica. Sin cuantizar, en 16 bits, un 4B ronda los 8 GB. Puedes cuantizar el caché de contexto a 4 u 8 bits para bajar memoria, útil en el celular. La cuantización a 4 bits casi no afecta la calidad de las tools.

### 14.4 Estrategia recomendada

Modelo local como Qwen3 4B o Gemma 4 E2B para lo cotidiano y las tools de rutina, sin gastar nube ni datos. Una key de DeepSeek u OpenAI solo para consultas que de verdad lo pidan. Así casi no pagas y no dependes de trucos frágiles.

---

## 15. Resumen del modelo de datos

```
Entradas (Streams)                         Procesamiento                 Salida
-----------------                          -------------                 ------
OBD: rpm, vel, temp, DTC          \
Nav: maniobra, distancia, calle    \
Accel: longitudinal, vertical       \      objeto de estado    ->  cascada  ->  un ánimo
Gyro: lateral                        >--->  (combinación)            de        +  postura nav
GPS: velocidad                      /       + filtros            prioridad     +  frase
Luz: lux                           /        + calibración                      +  voz (TTS)
Proximidad: cerca/lejos           /
Micrófono: wake word, comando    /
IA + tools: consultas y acciones /
```

Cada entrada es un `Stream`. Todo se combina en un objeto de estado. La cascada decide una sola animación. El TTS y la boca se sincronizan con los callbacks del sintetizador. La IA con tools entra como un agente que consulta datos y ejecuta acciones.

---

## 16. Próximos pasos sugeridos

1. Esqueleto Flutter con la máquina de estados y los `Stream` de sensores.
2. Personaje en Rive con State Machine e input de mood.
3. Lectura OBD por BLE con `flutter_blue_plus`.
4. Notification Listener de Maps en Kotlin con puente a Flutter.
5. Wake word con Porcupine, comando con `speech_to_text`.
6. TTS offline con sherpa-onnx y voz Piper en español.
7. Tool use con `ChispaTool`, `ToolRegistry` y `ChispaBrain`.
8. Cerebro local con Qwen3 4B o Gemma 4 E2B por Ollama, con respaldo en la nube.
9. Control de brillo por luz y movimiento, despertar al cargar por USB.

---

## Archivos del proyecto

- `chispa-documento-tecnico.md`: este documento.
- `chispa_tools.dart`: arquitectura de tool use, registro y bucle agéntico, con tools del carro.
- `chispa_tools_search_music.dart`: herramientas de búsqueda web y de música.
- `ai-pet-sensores-todo.html`: demo visual con sensores, velocímetro, anillo, y animaciones de pensar y hablar.