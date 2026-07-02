# Offline STT model (Vosk, Spanish)

Astro uses [Vosk](https://alphacephei.com/vosk/) for **offline, on-device**
speech recognition (continuous — it doesn't cut long phrases like the platform
recognizer does).

The Spanish model (`vosk-model-small-es-0.42`, ~37 MB) is **no longer bundled**
in the APK. It is **downloaded on demand** the first time the app starts, from a
GitHub Release asset, so the APK stays small.

- Default URL: `https://github.com/lordmacu/astro-agent/releases/download/stt-v1/vosk-model-small-es-0.42.zip`
- Override with `STT_MODEL_URL` in `.env`.

Until the download finishes, Astro falls back to the platform `speech_to_text`
recognizer, then switches to Vosk automatically once the model lands. A small
progress line at the top of the pet screen shows the download.

See `lib/voice/stt_model_provider.dart` and `lib/voice/vosk_recognizer.dart`.
