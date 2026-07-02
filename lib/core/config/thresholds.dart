/// Default download source for the neural Piper voice model zip. Overridable via
/// `.env` (TTS_MODEL_URL). The zip must contain the .onnx, tokens.txt, and
/// espeak-ng-data at its root.
const String kDefaultNeuralVoiceUrl =
    'https://github.com/lordmacu/aipet/releases/download/tts-v1/vits-piper-es_ES-davefx-medium.zip';

/// Folder name the model unzips into under app support dir.
const String kNeuralVoiceModelName = 'vits-piper-es_ES-davefx-medium';

/// Download source for the offline Vosk STT model (Spanish). Downloaded
/// on-demand at app start so the ~37MB model isn't bundled in the APK.
/// Overridable via `.env` (STT_MODEL_URL).
const String kDefaultSttModelUrl =
    'https://github.com/lordmacu/astro-agent/releases/download/stt-v1/vosk-model-small-es-0.42.zip';

/// Folder name the STT model unzips into (under the app support dir).
const String kSttModelName = 'vosk-model-small-es-0.42';

/// Fallback download sources, tried in order after [kDefaultSttModelUrl] if it
/// fails: the official Vosk site, then a Hugging Face mirror.
const String kSttModelOfficialUrl =
    'https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip';
const String kSttModelHuggingFaceUrl =
    'https://huggingface.co/localstack/vosk-models/resolve/main/vosk-model-small-es-0.42.zip';

/// All numeric thresholds used by the mood cascade live here, in one place.
/// Never hard-code a magic number in `MoodResolver` — read it from this object.
class Thresholds {
  const Thresholds();

  /// Longitudinal g below this counts as hard braking.
  final double brakeG = -0.45;

  /// Below this speed a hard deceleration is not treated as a scare.
  final double brakeSpeedKmh = 20.0;

  /// Longitudinal g above this counts as eager acceleration.
  final double accelG = 0.40;

  /// Vertical g magnitude above this counts as a bump.
  final double bumpG = 0.60;

  /// Lateral g magnitude above this counts as a curve.
  final double leanG = 0.40;

  /// Gyroscope turn rate (rad/s) above which a curve registers as the `lean`
  /// mood. Gentler than [leanG] so ordinary turns are caught.
  final double turnRateLean = 0.5;

  /// Tilt per rad/s of yaw: maps the gyroscope turn rate to the body lean
  /// (-1..1, clamped). The character multiplies the result by ~9°.
  final double tiltPerYaw = 1.8;

  /// Below this g magnitude on every axis the phone is mechanically still; the
  /// speed fusion uses it (with a recent GPS stop) to zero out phantom speed.
  final double quietG = 0.06;

  /// RPM above this counts as high revs.
  final double rpmHigh = 3500.0;

  /// Coolant temperature above this raises worry.
  final double coolantHighC = 112.0;

  /// How long the car must be still before Astro falls asleep.
  final Duration sleepAfter = const Duration(seconds: 8);

  /// Distance to the next maneuver below which attention is heightened.
  final double turnImminentM = 80.0;
}
