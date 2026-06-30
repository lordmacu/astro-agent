---
name: run-chispa
description: Use when launching or running the Chispa app on an Android device, or to verify a change works in the real app (not just tests). Triggers — "corre la app", "run on device", "pruébalo en el celular", "ver si funciona en el carro", "instala el APK", "hot reload".
---

# Correr Chispa en un dispositivo

## Principio

Chispa es Android-only, sin root, y depende de permisos y de un foreground service. Mucho del
comportamiento (wake word, sensores, brillo, despertar al cargar) **no se ve en un emulador** — usa un
celular físico conectado por USB para verificación real.

## Pasos

1. **Dispositivo**: `flutter devices`. Debe aparecer el Android físico (depuración USB activa).
   Si falta: `flutter doctor`.
2. **Generar código** si tocaste freezed/riverpod/json:
   `dart run build_runner build --delete-conflicting-outputs`.
3. **Correr**: `flutter run` (debug, hot reload). Para probar rendimiento real o el servicio en
   segundo plano: `flutter run --release` o `flutter build apk --release` e instala el APK.
4. **Permisos en el primer arranque** (concédelos en el celu, una vez): micrófono, ubicación,
   notificaciones (listener de Maps), y los opcionales superposición (`SYSTEM_ALERT_WINDOW`) y
   `WRITE_SETTINGS`. Quita la optimización de batería para la app o el foreground service muere.
5. **Hot reload** (`r`) para UI/lógica Dart. **Hot restart** (`R`) tras cambios de estado o providers.
   Cambios en código Kotlin/manifest/permisos → para y re-corre (`flutter run` de nuevo).
6. **Verifica el cambio de verdad**, no asumas: mira la animación/HUD, dispara el sensor real (mueve el
   celular, tapa el proximidad, baja la luz), o di la wake word. Si reportas que algo "funciona",
   que sea porque lo viste.

## Qué requiere celular físico (no emulador)

| Función | Por qué |
|---|---|
| OBD BLE | Bluetooth + adaptador ELM327 real |
| Wake word / STT / TTS | micrófono y audio del sistema |
| Acelerómetro / giroscopio / luz / proximidad | sensores reales |
| GPS speed | señal real en movimiento |
| Listener de Maps | notificación real navegando |
| Despertar al cargar | broadcast de `ACTION_POWER_CONNECTED` |

## Errores comunes

- Probar en emulador y concluir que "no funciona". → Casi nada de hardware existe ahí; usa físico.
- Olvidar `build_runner` tras tocar freezed/riverpod. → Errores de código generado.
- Hot reload tras cambiar providers/estado. → Usa hot restart (`R`); el estado viejo persiste.
- Cambiar permisos/Kotlin y solo hacer reload. → Re-corre la app completa.
- No quitar la optimización de batería. → El foreground service del micrófono se mata solo.
