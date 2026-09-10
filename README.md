![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?logo=powershell&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

# Convert-ProjectToMd

Conversor automático de carpetas de proyecto a **Markdown** para Windows.

Convierte todos los documentos de una carpeta (Excel, Word, PowerPoint, PDF, CSV, HTML) a archivos `.md` ligeros, replicando la estructura de subcarpetas en un espejo `_md`. Pensado para **trabajar con asistentes de IA gastando menos tokens**: la IA lee y busca sobre texto plano en lugar de sobre documentos pesados.

---

## ¿Por qué?

Cuando se trabaja un proyecto con IA sobre una carpeta llena de archivos pesados, cada lectura consume muchos recursos (tokens) y va lenta. Manteniendo una copia en Markdown de cada documento, las búsquedas y lecturas son mucho más rápidas y económicas. Los originales se conservan intactos; los `.md` son solo una capa de lectura.

## Características

- Espejo `_md` que replica la estructura de carpetas del proyecto.
- **Incremental**: solo reconvierte lo que ha cambiado desde la última pasada.
- **Soporte de rutas largas** (> 260 caracteres) mediante el prefijo `\\?\`.
- **OneDrive**: fuerza la descarga local y espera (no fatal) a que el archivo esté disponible.
- **CSV con punto y coma** (formato europeo): se convierten a tabla Markdown correctamente.
- **Log robusto** en UTF-8 por ejecución, con fecha y hora en el nombre.
- Procesa **un proyecto** o **varios** desde una lista (`proyectos.txt`).

## Requisitos

1. **Windows** 10/11.
2. **Python** 3.10 o superior (marcar *Add python.exe to PATH* al instalar).
3. **MarkItDown**:
   ```
   pip install "markitdown[all]"
   ```
4. **Rutas largas activadas** (una sola vez, en PowerShell como administrador, y reiniciar):
   ```
   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
   ```

## Uso

Convertir **un** proyecto:
```
powershell -ExecutionPolicy Bypass -File ".\Convert-ProjectToMd.ps1" -ProjectPath "C:\ruta\al\proyecto"
```

Convertir **varios** proyectos desde una lista:
```
powershell -ExecutionPolicy Bypass -File ".\Convert-ProjectToMd.ps1" -ListFile ".\proyectos.txt"
```

Forzar reconversión total (ignorar el incremental):
```
powershell -ExecutionPolicy Bypass -File ".\Convert-ProjectToMd.ps1" -ListFile ".\proyectos.txt" -Force
```

### La lista de proyectos

Copia `proyectos.example.txt` como `proyectos.txt` y escribe **una ruta por línea**. Las líneas que empiezan por `#` se ignoran. (El archivo `proyectos.txt` real está excluido del repositorio para no exponer rutas privadas.)

## Automatización (cada 10 días)

Mediante el Programador de tareas de Windows (recomendado, permite recuperación si el PC estaba apagado):

- Acción → `powershell`, con argumentos:
  ```
  -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ruta\Convert-ProjectToMd.ps1" -ListFile "C:\ruta\proyectos.txt"
  ```
- Desencadenador: diariamente, repetir cada **10 días**.
- En *Configuración*, marcar **"Ejecutar la tarea lo antes posible tras un inicio programado omitido"**.

## Usar los `.md` con la IA

En las instrucciones del proyecto de IA, indicar:

> Para buscar información y leer documentos, usa **primero** los archivos de la carpeta `_md` (versión en texto de los originales). Acude al archivo original solo si necesitas un dato o una fórmula exacta que el Markdown no conserve.

## Notas

- Los libros Excel con varias hojas se vuelcan todas seguidas en el mismo `.md`.
- Las fórmulas se convierten en su **valor calculado**, no se conserva la fórmula.
- El Markdown captura el contenido (texto y tablas), no el formato visual.
- La carpeta `_md` se autoexcluye: el script nunca convierte su propia salida.

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| Acaba pero no se crea el `.md` | Archivo "solo en la nube" (OneDrive) | Clic derecho en la carpeta → "Mantener siempre en este dispositivo" y relanzar |
| `'markitdown' no se reconoce` | No quedó en el PATH | El script lo localiza solo; para uso manual usar `python -m markitdown` |
| Error de ruta demasiado larga | Falta activar rutas largas | Aplicar el ajuste del registro (admin) y reiniciar |
| Aviso de `ffmpeg` | Solo afecta a audio | Ignorar |

## Licencia

MIT. Ver `LICENSE`.

---

# Convert-ProjectToMd

Automatic project folder converter to **Markdown** for Windows.

Converts all documents in a folder (Excel, Word, PowerPoint, PDF, CSV, HTML) to lightweight `.md` files, replicating the subfolder structure in a `_md` mirror. Designed to **work with AI assistants consuming fewer tokens**: the AI reads and searches plain text instead of heavy documents.

---

## Why?

When working on a project with AI over a folder full of heavy files, each read consumes many resources (tokens) and runs slowly. By maintaining a Markdown copy of each document, searches and reads become much faster and more economical. The originals remain intact; the `.md` files are just a read layer.

## Features

- `_md` mirror that replicates the project folder structure.
- **Incremental**: only reconverts what has changed since the last run.
- **Long path support** (> 260 characters) via the `\\?\` prefix.
- **OneDrive**: forces local download and waits (non-fatal) for file availability.
- **Semicolon-separated CSV** (European format): correctly converted to Markdown tables.
- **Robust UTF-8 logging** per execution, with date and time in the filename.
- Processes **one project** or **multiple** from a list (`proyectos.txt`).

## Requirements

1. **Windows** 10/11.
2. **Python** 3.10 or higher (check *Add python.exe to PATH* during installation).
3. **MarkItDown**:
   ```
   pip install "markitdown[all]"
   ```
4. **Long paths enabled** (once only, in PowerShell as administrator, then restart):
   ```
   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
   ```

## Usage

Convert **one** project:
```
powershell -ExecutionPolicy Bypass -File ".\Convert-ProjectToMd.ps1" -ProjectPath "C:\path\to\project"
```

Convert **multiple** projects from a list:
```
powershell -ExecutionPolicy Bypass -File ".\Convert-ProjectToMd.ps1" -ListFile ".\proyectos.txt"
```

Force full reconversion (ignore incremental):
```
powershell -ExecutionPolicy Bypass -File ".\Convert-ProjectToMd.ps1" -ListFile ".\proyectos.txt" -Force
```

### The projects list

Copy `proyectos.example.txt` as `proyectos.txt` and write **one path per line**. Lines starting with `#` are ignored. (The actual `proyectos.txt` file is excluded from the repository to avoid exposing private paths.)

## Automation (every 10 days)

Via Windows Task Scheduler (recommended, allows recovery if the PC was off):

- Action → `powershell`, with arguments:
  ```
  -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\path\Convert-ProjectToMd.ps1" -ListFile "C:\path\proyectos.txt"
  ```
- Trigger: daily, repeat every **10 days**.
- In *Settings*, check **"Run the task as soon as possible after a scheduled start is missed"**.

## Using `.md` files with AI

In the AI project instructions, indicate:

> To search for information and read documents, **first** use the files in the `_md` folder (text version of the originals). Only refer to the original file if you need an exact value or formula that Markdown does not preserve.

## Notes

- Excel workbooks with multiple sheets are all dumped consecutively in the same `.md`.
- Formulas are converted to their **calculated value**, not the formula itself.
- Markdown captures content (text and tables), not visual formatting.
- The `_md` folder auto-excludes itself: the script never converts its own output.

## Troubleshooting

| Symptom | Likely cause | Solution |
|---|---|---|
| Completes but `.md` not created | File "cloud only" (OneDrive) | Right-click folder → "Always keep on this device" and re-run |
| `'markitdown' not recognized` | Not in PATH | The script finds it automatically; for manual use run `python -m markitdown` |
| Long path error | Long paths not enabled | Apply registry adjustment (admin) and restart |
| `ffmpeg` warning | Only affects audio | Ignore |

## License

MIT. See `LICENSE`.
