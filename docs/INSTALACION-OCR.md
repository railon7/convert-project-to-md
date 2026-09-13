# 🔎 OCR para el conversor a Markdown — instalación y uso

Amplía el conversor para **recuperar el texto de PDFs escaneados y de imágenes**. Cuando un PDF sale vacío (es un escaneo) o el archivo es una imagen, se le pasa un OCR y su texto rellena el `.md`.

Todo es **local**: nada sale del equipo. Motor: **Tesseract** (spa+eng) + Python (PyMuPDF + pytesseract).

---

## 1. Instalación (una sola vez)

### 1.1 Tesseract (el motor OCR)
```powershell
winget install --id UB-Mannheim.TesseractOCR -e
```

### 1.2 Datos de idioma (español + inglés) en una carpeta propia
Crea una subcarpeta `tessdata` **junto al script** y descarga los idiomas (no necesita permisos de administrador):
```powershell
$dir = "C:\Users\TU_USUARIO\...\Convertir carpetas a.md\tessdata"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Invoke-WebRequest "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/spa.traineddata" -OutFile "$dir\spa.traineddata"
Invoke-WebRequest "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/eng.traineddata" -OutFile "$dir\eng.traineddata"
```
> El script detecta esta carpeta `tessdata` automáticamente y la usa.

### 1.3 Paquetes de Python
```powershell
pip install pymupdf pytesseract pillow
```

### 1.4 Comprobar
```powershell
python "C:\Users\TU_USUARIO\...\Convertir carpetas a.md\ocr-a-md.py" --help
```
Si muestra la ayuda, está listo.

---

## 2. Uso

El comportamiento **sin `-OCR` es idéntico al de siempre**. El OCR solo actúa si añades el interruptor `-OCR`:

```powershell
powershell -ExecutionPolicy Bypass -File "...\Convert-ProjectToMd.ps1" -ListFile "...\proyectos.txt" -OCR
```

Qué hace con `-OCR`:
- **PDF escaneado**: si tras convertir el `.md` queda vacío o casi (menos de `OcrMinChars`, por defecto 15 caracteres), lo rellena con OCR.
- **Imágenes** (`.jpg`, `.png`, `.tiff`, `.bmp`): las reconoce y crea su `.md`.

Parámetros ajustables:
- `-OcrMinChars 15` — umbral para considerar un PDF "vacío".
- `-OcrLang "spa+eng"` — idiomas.
- `-OcrDpi 300` — resolución de lectura del PDF (más alto = mejor calidad, más lento).

En el registro, los archivos recuperados aparecen bajo "Rellenados por OCR", y el resumen de cada proyecto incluye un contador `OCR: N`.

> **Nota sobre el registro:** ahora hay un único archivo `Trabajados\registro-conversiones.md` que **acumula** todas las ejecuciones (en vez de un `.txt` por pasada). Cada ejecución añade su fecha, un resumen por proyecto y solo lo relevante (fallos y archivos rescatados por OCR). Ábrelo en cualquier visor de Markdown o en el propio VS Code para consultarlo.

---

## 3. Recomendación sobre la tarea automática

El OCR es **más lento** (procesa cada página como imagen). Por eso conviene **no** ponerlo en la tarea programada de cada 10 días. Mejor:
- Deja la tarea automática **sin `-OCR`** (rápida, como ahora).
- Lanza una pasada **manual con `-OCR`** de vez en cuando, o solo sobre la carpeta que tenga escaneos:
  ```powershell
  powershell -ExecutionPolicy Bypass -File "...\Convert-ProjectToMd.ps1" -ProjectPath "C:\ruta\carpeta_con_escaneos" -OCR
  ```

---

## 4. Avisos honestos (calidad del OCR)

- Texto **impreso y nítido** sale muy bien. Escaneos torcidos, con manchas o de baja resolución salen peor.
- El **manuscrito** no se reconoce de forma fiable.
- Las **tablas** se recuperan como texto alineado, no como tabla Markdown perfecta.
- Siempre puede haber pequeños errores de lectura (una letra por otra, un número mal). Para datos críticos, contrasta con el original.

---

## 5. Solución de problemas

| Síntoma | Causa | Solución |
|---|---|---|
| `tesseract is not installed or not in PATH` | No encuentra el motor | Reinstala Tesseract (1.1); el script lo busca en `C:\Program Files\Tesseract-OCR` |
| Texto vacío o basura en español | Falta el idioma `spa` | Repite el paso 1.2 (descarga `spa.traineddata`) |
| `falta un paquete Python` | Faltan pip packages | `pip install pymupdf pytesseract pillow` |
| Muy lento | PDFs escaneados grandes | Baja `-OcrDpi 200`, o procesa solo la carpeta afectada |
| Un PDF con texto no se OCR-ea | Ya tenía texto (no hacía falta) | Correcto: el OCR solo actúa en los vacíos |
