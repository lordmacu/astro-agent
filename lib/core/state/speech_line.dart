/// A language-agnostic line Astro can say. The `MoodResolver` emits these; the
/// voice/UI layer renders them into actual text (English or Spanish) via
/// `SpeechCatalog`. Keeping the resolver on semantic lines, not strings, keeps
/// it pure and lets the voice be bilingual without touching the state machine.
enum SpeechLine {
  letsGo,
  holdOn,
  bump,
  curve,
  engineWarm,
  faultCode,
  arrived,
  dizzy,
}
