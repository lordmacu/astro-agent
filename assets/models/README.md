# Vosk offline STT model

Astro uses [Vosk](https://alphacephei.com/vosk/) for **offline, on-device**
speech recognition (continuous — it doesn't cut long phrases like the platform
recognizer does). The Spanish model is **not committed** (it's ~40 MB); drop it
here and it gets bundled automatically.

## Install the model

1. Download the small Spanish model:
   **https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip**

   ```bash
   cd assets/models
   curl -L -O https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip
   ```

2. Keep it **zipped** and named exactly `vosk-model-small-es-0.42.zip`
   (that's the path `VoskSpeechRecognizer` loads). The `assets/models/` folder
   is already declared in `pubspec.yaml`, so no pubspec edit is needed.

3. Rebuild the app (full build — it's a new asset).

That's it. On first launch Vosk unpacks the model to app storage and uses it for
all command capture, fully offline.

## Notes

- **Without the model**, `VoskSpeechRecognizer` transparently falls back to the
  platform `speech_to_text`, so voice still works — just online and with the
  usual mid-sentence cutting.
- The **small** model (~40 MB) is a good balance for commands. The larger
  `vosk-model-es-0.42` (~1.4 GB) is more accurate but too big to bundle.
- To change which model file is loaded, edit `modelAsset` in
  `lib/voice/vosk_recognizer.dart`.
- APK size grows by roughly the model size (per install, not per ABI).
