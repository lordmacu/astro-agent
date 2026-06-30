---
name: add-mood
description: Use when adding or changing a Chispa mood / animation state — a new emotional reaction, its place in the priority cascade, its look (color, eyes, mouth, extras), and its Rive input. Triggers — "agregar un ánimo", "nueva animación", "que reaccione con X", "Mood enum", "mood_resolver", "estado de ánimo".
---

# Agregar o cambiar un ánimo de Chispa

## Principio

Un solo `Mood` se resuelve por **cascada de prioridad** en `core/state/mood_resolver.dart` a partir
del `AppState`. La navegación es una **capa de postura aparte** (mirada/inclinación), no un mood que
compita en la cascada. Toda la apariencia sale de `core/config/design_tokens.dart`; el personaje real
es **Rive** (input numérico `mood` + inputs de postura).

## La cascada (mayor a menor prioridad)

```
1 agente thinking/answering · 2 caricia (pet) · 3 DTC (alarm) · 4 frenada fuerte (scared)
5 llegada (arrival) · 6 temp alta (worried) · 7 RPM/accel altas (excited)
8 quieto un rato (sleep) · 9 reposo (rest, refleja la luz)
```

Moods existentes: `rest, excited, scared, worried, alarm, sleep, arrival, lean, bump, pet,
thinking, answering`.

## Pasos

1. **Enum** `Mood` en `core/state/mood.dart`: agrega el valor.
2. **Cascada**: ubícalo en `mood_resolver.dart` en su nivel de prioridad correcto (un `if` antes/después
   según gane a quién). Lee el umbral de `thresholds.dart`, nunca un número crudo.
3. **Diseño** en `design_tokens.dart`: color de cuerpo (override del color por luz ambiente), apertura
   de ojos, forma de boca, extras (sweat, zzz, "!", corazones, globo de pensar).
4. **Rive**: mapea el `Mood` al input `mood` de la State Machine en `character/rive_controller.dart`.
   Postura (giro de nav) son inputs aparte: `gazeDir`, `tiltDir`, `turnImminent`.
5. **Frase**: agrega la línea de voz/subtítulo en español para ese ánimo.
6. **Test** (TDD, obligatorio aquí): el resolver es función pura `AppState -> MoodState`. Agrega un caso
   de tabla para el nuevo mood **y** verifica los empates de prioridad (que gane a quien debe perder).

## Apariencia por ánimo (del prototipo)

| Mood | Cuerpo | Señales |
|---|---|---|
| rest | color de la luz ambiente | respiración lenta |
| excited | `#f2a93b` | ojos abiertos, boca abierta, rebote |
| scared | `#7fb6ff` (arco `#ff4d57`) | ojos muy abiertos, temblor, gota |
| worried | naranja | ceño, respiración rápida |
| alarm | rojo | "!" |
| sleep | gris | ojos caídos, "z" |
| arrival | verde | estrella, celebración |
| lean | — | tilt hacia el lado |
| bump | `#b48bff` | saltito, sorpresa |
| pet | — | ojos cerrados, sonrojo, corazones |
| thinking | — | globo + 3 puntos, mirada arriba |
| answering | — | visemas (boca alterna 5 formas) |

## Errores comunes

- Meter el mood en el lugar equivocado de la cascada. → Lo tapa otro de mayor prioridad y nunca se ve.
- Tratar la navegación como un mood. → Es postura encima; va en campos aparte de `MoodState`.
- Hardcodear el umbral en el resolver. → Va en `thresholds.dart`.
- No testear los empates. → El bug típico: dos condiciones ciertas y gana la incorrecta.
