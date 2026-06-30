---
name: add-data-source
description: Use when adding a new sensor or input to Chispa — an OBD PID, phone sensor (accel, gyro, light, proximity), GPS speed, or a Maps nav signal. Anything that produces a Stream that feeds the combined AppState. Triggers — "agregar sensor", "leer un nuevo PID", "nueva fuente de datos", "wire X into AppState".
---

# Agregar una fuente de datos a Chispa

## Principio

Toda fuente sigue el mismo pipeline. No lo rompas:

```
servicio (Stream)  ->  filtro/parse  ->  campo en AppState  ->  (si afecta ánimo) cascada
```

Un servicio **solo produce datos**. La decisión de ánimo vive **únicamente** en
`core/state/mood_resolver.dart`. La UI nunca escucha el servicio directo, solo `AppState`.

**Regla dura:** si la fuente es opcional (OBD, navegación), Chispa debe seguir funcionando sin ella.
Nunca hagas que una feature básica dependa de hardware opcional. El campo entra como nullable.

## Pasos

1. **Servicio** en `lib/sensors/<fuente>/<fuente>_service.dart`. Expone un `Stream<XReading>` de un
   modelo tipado (freezed). Encapsula el paquete (`flutter_blue_plus`, `sensors_plus`, `geolocator`,
   `light`, `proximity_sensor`, listener de Maps). No expongas tipos del paquete hacia arriba.
2. **Filtra/parsea el valor crudo** antes de emitirlo. Sensores ruidosos pasan por `core/util/low_pass.dart`.
   Velocidad = GPS (`geolocator.speed`); el accel solo rellena huecos (fusión), nunca integración sola.
3. **Umbrales** → agrégalos a `core/config/thresholds.dart`. Nunca un número mágico en la lógica.
4. **Campo en `AppState`** (`core/state/app_state.dart`, freezed). Nullable si la fuente es opcional.
   Regenera: `dart run build_runner build --delete-conflicting-outputs`.
5. **Combina** la fuente en `core/state/app_state_provider.dart` (`CombineLatestStream` de rxdart).
   Provee el servicio con Riverpod y cancela la suscripción en `ref.onDispose`.
6. **¿Afecta el ánimo?** Solo entonces toca `mood_resolver.dart`, respetando la prioridad de la cascada
   (ver CLAUDE.md). Si solo es telemetría (mostrar en HUD), no toques el resolver.
7. **Tests** (TDD): un test de parsing del servicio con datos fijos (mockea el hardware con un
   `StreamController`), y si tocaste el resolver, un test de tabla del nuevo caso.

## Referencia rápida

| Fuente | Paquete | Filtro | ¿Afecta ánimo? |
|---|---|---|---|
| RPM / vel / temp / DTC | `flutter_blue_plus` (ELM327) | — | sí (excited/worried/alarm) |
| Accel + gyro | `sensors_plus` | low-pass | sí (scared/excited/lean/bump) |
| Velocidad GPS | `geolocator` | fusión con accel | indirecto |
| Luz (lux) | `light` | low-pass (evita parpadeo) | rest refleja la luz |
| Proximidad | `proximity_sensor` | — | sí (pet) |
| Navegación | `flutter_notification_listener` | — | capa de postura, no mood |

## Errores comunes

- Meter la decisión de ánimo en el servicio. → Va solo en `mood_resolver`.
- Emitir el valor crudo sin filtrar. → Tiembla y la animación parpadea.
- Hacer obligatorio el OBD/nav. → Campo nullable; lo básico funciona sin él.
- Olvidar `build_runner` tras tocar `AppState` freezed. → No compila / campos viejos.
- No cancelar la suscripción. → Fuga al cambiar de pantalla.
