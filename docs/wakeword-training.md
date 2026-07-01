# Entrenar los modelos de wake word ("Oye Astro" / "Astro")

Guía paso a paso para producir los modelos que el detector openWakeWord de Astro necesita.
**Sin estos archivos, la app corre pero no detecta nada** (el servicio queda en
`Wake-word models unavailable; running idle`). El entrenamiento es gratis, en Google Colab
(Linux), y usa **voz sintética con Piper** — no grabas una sola muestra.

> Tiempo: ~75–90 min por frase, casi todo desatendido. Entrenamos **dos** frases.

---

## Qué necesita la app exactamente

El motor carga 4 archivos `.tflite` desde `android/app/src/main/assets/oww/` con estos
**nombres exactos** (definidos en `WakeConfig.kt`):

| Archivo en `assets/oww/` | Qué es | De dónde sale |
|---|---|---|
| `oye_astro.tflite` | clasificador de "Oye Astro" | lo entrenas (paso 2) |
| `astro.tflite` | clasificador de "Astro" | lo entrenas (paso 3) |
| `melspectrogram.tflite` | extractor de features (compartido, fijo) | viene con openWakeWord |
| `embedding.tflite` | extractor de features (compartido, fijo) | viene con openWakeWord (renómbralo) |

Los dos compartidos son **iguales para cualquier palabra** — se descargan una vez.

---

## Paso 1 — Abrir el notebook en Colab

1. Entra a **https://github.com/dscripka/openWakeWord**.
2. En el README, sección **"Training New Models"**, abre el notebook
   `notebooks/automatic_model_training.ipynb` con el botón **"Open in Colab"**.
3. En Colab: `Entorno de ejecución → Cambiar tipo de entorno → GPU` (acelera; opcional).
4. Corre la primera celda de setup (instala openWakeWord + Piper + descarga los datasets de
   ruido/RIR para aumentar las muestras). Tarda unos minutos.

---

## Paso 2 — Entrenar "Oye Astro"

1. En la celda de configuración del notebook, pon la frase objetivo:
   - `target_word = "oye astro"` (o el campo equivalente `target_phrase` / `model_name`).
2. Usa **voces en español** para Piper (ej. `es_ES-*`, `es_MX-*`). Si el notebook deja elegir
   varias, agrega 2–3 para variar acento/tono.
3. Deja los conteos de positivos/negativos y el aumento (RIR + ruido) por defecto.
4. Corre todas las celdas (`Entorno de ejecución → Ejecutar todo`). Al final entrena un
   clasificador chico sobre el extractor congelado y guarda el modelo.
5. **Exporta a TFLite** si el notebook lo ofrece, y descarga el archivo. Renómbralo
   **`oye_astro.tflite`**.
   - ⚠️ Si el notebook solo exporta **`.onnx`**, descarga ese `oye_astro.onnx` igual — la app
     tiene una ruta ONNX lista para activar (ver "Si te quedan en .onnx" abajo). **Avísame** y
     la conecto.

---

## Paso 3 — Entrenar "Astro"

Repite el paso 2 con `target_word = "astro"`. Descarga y renombra a **`astro.tflite`**.

> "Astro" sola es corta → más falsos positivos. Por eso en `WakeConfig.kt` su umbral arranca
> más alto (0.7 vs 0.5 de "Oye Astro"). Si dispara sola con ruido, lo subimos en el tuning.

---

## Paso 4 — Conseguir los modelos compartidos (melspec + embedding)

Estos NO se entrenan; vienen con el paquete openWakeWord. En una celda del Colab:

```python
import openwakeword, os, glob
base = os.path.dirname(openwakeword.__file__)
print("\n".join(glob.glob(base + "/resources/models/*")))
```
Busca `melspectrogram.tflite` y `embedding_model.tflite`. Descárgalos. Renombra:
- `melspectrogram.tflite` → queda igual: **`melspectrogram.tflite`**
- `embedding_model.tflite` → **`embedding.tflite`**  ← (la app lo espera sin el `_model`)

> Si en tu versión solo aparecen como `.onnx`, bájalos igual y avísame (ruta ONNX).

---

## Paso 5 — Verificar en Colab (antes de bajar a la app)

```python
from openwakeword.model import Model
import numpy as np
oww = Model(wakeword_models=["oye_astro.tflite", "astro.tflite"], inference_framework="tflite")
# Graba un wav diciendo "oye astro" y otro de ruido/música, súbelos a Colab:
print("positivo:", {k: round(max(v),3) for k,v in oww.predict_clip("oye_astro_test.wav").items()})
print("ruido:   ", {k: round(max(v),3) for k,v in oww.predict_clip("ruido.wav").items()})
```
Esperado: la clave correspondiente en el clip positivo **≥ ~0.5**; ambas en ruido **≪ 0.5**.
Anota esos números (sirven para el tuning de umbrales).

---

## Paso 6 — Meter los modelos en la app

Copia los 4 archivos a la carpeta de assets nativos (créala si no existe):

```
android/app/src/main/assets/oww/
├── oye_astro.tflite
├── astro.tflite
├── melspectrogram.tflite
└── embedding.tflite
```

Reinstala en el celu (yo lo corro, o tú):
```bash
flutter run -d <device>        # compila solo el ABI del celu + hot reload
```
Concede el permiso de **micrófono** cuando lo pida. Ahora di **"Oye Astro"** → Astro debe
responder. La notificación dirá que está escuchando.

---

## Si te quedan en `.onnx` (no `.tflite`)

La app es **TFLite por defecto**, pero dejamos la ruta ONNX lista y parqueada (igual que el TTS
neural). Para activarla (lo hago yo cuando me pases los `.onnx`):
1. `android/app/build.gradle.kts`: descomentar la dependencia `onnxruntime-android`.
2. Renombrar `OnnxInferencer.kt.off` → `OnnxInferencer.kt`.
3. En `WakeWordEngine`, seleccionar el inferencer por extensión del asset (`.onnx` → `OnnxInferencer`).
Pon los `.onnx` en `assets/oww/` con los mismos nombres base.

---

## Tuning (después de que detecte)

Si "Astro" dispara sola con música/charla, sube su umbral en `WakeConfig.kt`
(`PhrasePolicy("oww/astro.tflite", threshold = 0.7f → 0.8f, ...)`) y reinstala. "Oye Astro"
debería ser robusta. Anota aquí los valores finales y el ratio TP/FP que observaste.

### Parámetros usados (rellenar al entrenar)
- Notebook + commit:
- `target_word` frase 1 / frase 2:
- Voces Piper:
- Framework export: tflite / onnx
- Scores medidos (positivo / ruido):
- Umbrales finales:
