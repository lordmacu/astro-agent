// LLM model ids and the routing rule shared by the brain and the settings UI.
// Lives in `core/config` so both layers depend on it without `brain` importing
// `ui` (or vice-versa).

/// Kilo Gateway free model (reasoning), routed through the keyless anonymous
/// gateway. Any id ending in `:free` is treated as a keyless Kilo model.
const String kKiloFreeModel = 'poolside/laguna-m.1:free';

/// The default model when the user hasn't chosen one. The free, keyless Kilo
/// model, so Astro is functional from first launch with no API key.
const String kDefaultModel = kKiloFreeModel;

/// True for a keyless Kilo free model — any id ending in `:free`. These route
/// through Kilo's anonymous gateway (no API key), and the settings UI hides the
/// key fields for them.
bool isFreeModel(String model) => model.trim().endsWith(':free');
