<p align="center">
  <img src="assets/icon/astro_icon.png" alt="Astro" width="160" />
</p>

<h1 align="center">Astro</h1>

<p align="center">
  <b>An AI pet that lives on your car dashboard.</b><br/>
  A Flutter (Android, no root) virtual companion that reads the car and phone,
  reacts with animations and voice, and can act on your behalf through an
  agentic, tool-using brain.
</p>

---

## What is Astro?

Astro is a little character mounted on a phone on your dashboard. It senses what
is happening — how fast you are going, how hard you brake, the ambient light, a
turn coming up on the map — and reacts with a mood, an animation, and a spoken
line. Say **"hola Astro"** (or tap it) and it becomes a hands-free voice
assistant: it understands you, decides what to do, calls the right tools, and
answers out loud.

Everything essential works **without a car adapter and without root**. OBD and
navigation only *add* signals; they are never requirements.

The guiding pattern of the whole app:

```
sensor  ->  filter/threshold  ->  state  ->  mood (priority cascade)  ->  animation + line + voice
```

## Highlights

- 🗣️ **Hands-free voice loop** — offline wake word → speech-to-text → agentic
  brain → text-to-speech, with a back-and-forth conversation and voice
  confirmation for anything that acts on the outside world.
- 🧠 **Agentic brain (tool use)** — a cloud LLM runs a proper tool-calling loop:
  it can read the situation, call tools, feed results back, and keep going until
  it has a final spoken answer.
- 🎭 **Mood engine** — a single priority cascade turns all the combined signals
  into one mood (excited, scared, worried, arrival, sleep, rest, …), with a
  navigation "posture" layer (lean and gaze toward the next turn).
- 🚗 **Car mode vs normal mode** — on the dashboard it shows speed, runs the GPS
  fusion, and reacts to driving; as a desk companion it stays calm.
- 🔊 **Two voices** — a lightweight built-in system voice by default, plus an
  optional **downloadable neural (Piper) voice** for offline, higher-quality
  speech — fetched on demand so it never bloats the install.
- ⚙️ **In-app settings** — pick the AI model, paste API keys, tune the voice,
  manage memory and permissions — all from a screen behind the ⚙️ icon.
- 🔒 **Local-first & no root** — long-term memory lives in on-device SQLite; the
  app runs as a foreground service for the always-on wake word.

## What the agent can do (tools)

Astro's brain calls small, well-scoped tools. The active set includes:

| Capability | What it does |
|---|---|
| **Context** | Time, current speed, and resolved location for grounded answers. |
| **Music** | Play by search and control playback (play/pause/next/previous) on whatever media app is active — no lock-in to one service. |
| **Device** | Screen brightness, media volume, and the flashlight. |
| **Navigation** | Launch Google Maps to a destination. A notification listener also reads Maps' turn-by-turn guidance so Astro leans into the next turn and celebrates arrival. |
| **Timers & alarms** | Set a countdown timer or an alarm. |
| **Phone** | Place a call or send a message (WhatsApp / SMS), resolving the contact by name. |
| **Communication (email)** | Send email over SMTP when configured, or open a pre-filled draft in the phone's mail app otherwise; read the inbox over IMAP, or open the mail app when it isn't set up. |
| **Calendar** | Create events / reminders. |
| **Web search** | Pull fresh facts from the internet when needed. |
| **Weather & places** | Look up conditions and nearby places. |
| **Camera** | Take a photo (front/back), with a real shutter sound and a thumbnail popup (view full-screen or dismiss). |
| **Memory** | Remember facts about the driver and recall them automatically on later turns. |

> Read-only tools run immediately; tools that act on the outside world (send a
> message, send email over SMTP, …) ask for a quick **voice confirmation**
> first.

## How it works

1. **Sensors** each produce their own `Stream` (motion, GPS speed, light,
   proximity, and — in car mode — navigation).
2. Streams are combined (rxdart `CombineLatest`) into one immutable `AppState`.
3. A pure **`MoodResolver`** turns `AppState` into a single `Mood` via a
   priority cascade; the navigation posture (gaze / lean / "turn imminent") is
   layered on top.
4. The character renders the mood; the voice catalog speaks the matching line
   (bilingual EN/ES).
5. On the wake word, the **agentic loop** takes over: the LLM sees the
   conversation + relevant memories, calls tools, and streams its answer sentence
   by sentence so Astro starts talking before the whole reply is ready.

## Voice

- **Wake word** — offline, always-on (runs in a foreground service).
- **Speech-to-text** — captures the command.
- **Text-to-speech** — the built-in system voice by default; an optional
  **neural Piper voice** can be downloaded from Settings for offline, natural
  speech. Mouth visemes animate while Astro talks.

## Settings

Behind the ⚙️ icon (top-right):

- **AI** — model picker (OpenAI-compatible presets, default MiniMax) and API
  keys (LLM + web search), overriding `.env` at runtime.
- **Voice** — rate, pitch, language (EN/ES), and download/enable the neural
  voice.
- **Wake word & sensors** — toggle the wake word and sensitivity, the Maps
  navigation listener, and automatic brightness.
- **Memory** — see how much Astro remembers and clear it.
- **Permissions** — request microphone, notifications, and location.
- **About** — version and diagnostics.

## Tech stack

| Layer | Choice |
|---|---|
| State / DI | Riverpod 2 |
| Stream combination | rxdart |
| Immutable models | freezed + json_serializable |
| Character | Rive state machine (planned) with a placeholder renderer today |
| Sensors | `sensors_plus`, `geolocator` (GPS + IMU speed fusion), `light`, native proximity |
| Navigation | Google Maps notification listener (native `NotificationListenerService`) |
| Voice | offline wake word + STT; `flutter_tts` (system) and sherpa-onnx / Piper (neural, optional) |
| Brain | HTTP to a cloud LLM (MiniMax / OpenAI-compatible), custom tool-use loop |
| Memory | SQLite (`sqflite`) with full-text (and semantic) recall |
| Platform | Android, no root; foreground service, method/event channels |

> **Language rule:** all code is in English. Astro's *voice* is bilingual
> (EN + ES) and lives in a speech catalog, never as loose strings in logic.

## Getting started

```bash
flutter pub get

# Provide API keys (a cloud LLM key enables the agent; without one Astro falls
# back to canned lines). Keys can also be set in-app from Settings.
echo 'LLM_API_KEY=your_key_here' > .env   # optional: TAVILY_API_KEY, ASTRO_MODEL, TTS_MODEL_URL

flutter run                 # on a connected Android device (fast: one ABI + hot reload)

flutter analyze             # no warnings before you finish
flutter test                # unit + widget tests
dart run build_runner build --delete-conflicting-outputs   # freezed / json
```

Optional:

```bash
dart run flutter_launcher_icons   # regenerate the launcher icon from assets/icon/astro_icon.png
flutter build apk --release
```

## Project layout

```
lib/
  core/state/     AppState, Mood, MoodResolver (the cascade), combined provider
  core/config/    thresholds, design tokens, settings store
  sensors/        motion, location (speed fusion), light, proximity, navigation
  voice/          wake word, STT, TTS (system + neural), visemes
  brain/          agentic loop + tools (context, music, device, navigate, phone,
                  communication, calendar, camera, web search, memory, …)
  ui/             pet screen, HUD, settings, photo viewer
  platform/       Android channels: media, proximity, camera, system actions
android/          manifest, permissions, Kotlin services (wake word, nav listener)
```

## Status

Astro is under active development. The sensor pipeline, mood cascade, voice loop,
agentic brain, in-app settings, downloadable neural voice, Maps navigation
listener, and the tool set above are in place. OBD (car diagnostics over BLE) is
planned and intentionally optional — the basics never depend on it.
