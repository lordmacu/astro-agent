// LLM model ids and the routing rule shared by the brain and the settings UI.
// Lives in `core/config` so both layers depend on it without `brain` importing
// `ui` (or vice-versa).

/// A representative Kilo free model (reasoning), routed through the keyless
/// anonymous gateway. Any id ending in `:free` is treated as a keyless Kilo
/// model.
const String kKiloFreeModel = 'poolside/laguna-m.1:free';

/// The default model when the user hasn't chosen one — a free, keyless Kilo
/// model, so Astro works from first launch with no API key. Picked from a
/// latency benchmark of the free tool-capable models: NVIDIA Nemotron 3 Nano
/// was the fastest AND most consistent (~2.2 s, reliable tool calls), while
/// the previous default (Poolside Laguna M.1) occasionally stalled for minutes.
const String kDefaultModel =
    'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free';

/// True for a keyless Kilo free model — any id ending in `:free`. These route
/// through Kilo's anonymous gateway (no API key), and the settings UI hides the
/// key fields for them.
bool isFreeModel(String model) => model.trim().endsWith(':free');
