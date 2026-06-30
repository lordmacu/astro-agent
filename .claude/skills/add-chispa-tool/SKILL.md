---
name: add-chispa-tool
description: Use when adding a capability the IA can call in Chispa's agentic brain — a new ChispaTool (get_speed, clear_dtc, set_brightness, poner_musica, web search, etc.). Triggers — "agregar una tool", "que la IA pueda X", "nueva herramienta del carro", "tool use", "ChispaBrain".
---

# Agregar una tool al cerebro agéntico

## Principio

La IA recibe la lista de tools, decide cuáles usar, tú las ejecutas local y devuelves el resultado.
El bucle de `ChispaBrain` repite hasta la respuesta final.

```
usuario -> modelo -> ¿pide tool? -> run() local -> resultado -> modelo -> ... -> respuesta
```

Cada tool va **desacoplada de la fuente**: se le inyecta la función que lee/ejecuta el dato, no
importa el servicio directo. Así se testea con un fake.

## Pasos

1. **Subclase de `ChispaTool`** en `lib/brain/tools/`. Define `name`, `description` (clara y bien
   distinta de las demás), `schema` (JSON de parámetros) y `run(args)`.
2. **Inyecta la dependencia** por constructor (ej. `Future<int> Function() readSpeed`), no el servicio.
3. **¿Cambia algo?** (borrar DTC Modo 04, brillo, poner música). Márcala `requiresConfirmation = true`:
   `ChispaBrain` pide **confirmación por voz** antes de ejecutar. Las de solo lectura corren directo.
4. **Registra** en `ToolRegistry`. **Límite: 3–5 tools activas.** La precisión del modelo cae con más
   (10–15 empieza a errar, 20 se confunde). Si crecen, agrupa o divide por agente temático.
5. **Anima**: el `run` se refleja en `onToolUse` → Chispa muestra "consultando X". El bucle entero es
   `thinking`; la respuesta final dispara los visemas (`answering`).
6. **Test** (TDD): corre el bucle con un cliente HTTP/IA falso que devuelve un `tool_call` predecible
   y verifica que `run` se invoca, que una tool mutadora espera confirmación, y el resultado vuelve al modelo.

## Tools del carro (referencia)

| Tool | Tipo | Fuente envuelta |
|---|---|---|
| `get_speed` | lectura | GPS / OBD |
| `get_engine_status` | lectura | OBD (temp, RPM, carga) |
| `clear_dtc` | **mutadora** (Modo 04) | OBD — confirma por voz |
| `get_next_turn` | lectura | NavService (Maps) |
| `set_brightness` | **mutadora** | ventana/sistema — confirma |
| `poner_musica` | acción | intent `MEDIA_PLAY_FROM_SEARCH` (sin Spotify/Premium) |
| `control_musica` | acción | sesiones de media del sistema |
| `buscar_web` | lectura | Tavily (empezar) o Brave |

## Errores comunes

- Descripciones parecidas entre tools. → El modelo elige mal; hazlas bien distintas.
- Pasar de 5 tools activas "por si acaso". → Baja la precisión; agrupa o divide en agentes.
- Tool mutadora sin confirmación. → Riesgo (borra códigos, cambia brillo sin avisar).
- Importar el servicio dentro de la tool. → Acopla y no se puede testear; inyecta la función.
- Olvidar enganchar `onToolUse`/`onThinking`. → La animación no refleja lo que hace.
