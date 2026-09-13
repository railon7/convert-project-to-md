# SOP — Conversión automática de carpetas de proyecto a Markdown (.md)

> **Área:** Sistemas / Automatizaciones Claude
> **Herramienta principal:** MarkItDown (Microsoft) + PowerShell + Programador de tareas de Windows
> **Autor del proceso:** Tazuke
> **Objetivo:** Mantener, dentro de cada carpeta de proyecto, una versión en texto ligero (`.md`) de todos los documentos pesados (Excel, Word, PDF…), para que los proyectos de Cowork hagan búsquedas y lecturas más rápidas y baratas.

---

## 1. ¿Para qué sirve esto y por qué?

Cuando se trabaja un proyecto en Cowork con una carpeta llena de archivos pesados (Excel con muchas hojas, PDF, presentaciones…), cada lectura o búsqueda obliga a cargar documentos grandes, lo que consume más recursos y ralentiza el trabajo.

La solución es generar, **junto a los originales**, una copia en **Markdown** de cada archivo. El Markdown es texto plano y ligero, así que Claude puede leerlo y buscar en él de forma mucho más eficiente. Los originales se conservan intactos; los `.md` son solo una capa de lectura rápida.

Todo el proceso está automatizado con un script que:

1. Recorre cada carpeta de proyecto indicada.
2. Crea dentro una subcarpeta llamada **`_md`** que **replica la estructura de subcarpetas** del proyecto.
3. Convierte cada documento a `.md` y lo deja en su sitio espejo dentro de `_md`.
4. Es **incremental**: en cada pasada solo reconvierte lo que ha cambiado desde la última vez.
5. Guarda un **registro (log)** de cada ejecución, con la fecha, en una carpeta central de control.

---

## 2. Estructura de archivos del sistema

Todo vive en esta carpeta raíz:

```
C:\Users\railo\OneDrive\Aplicaciones\Automatizaciones Claude\Convertir carpetas a.md\
│
├── Convert-ProjectToMd.ps1      <- El script que hace el trabajo
├── proyectos.txt                <- Lista de carpetas de proyecto a procesar
│
├── Sops\                        <- Documentación (este SOP y la plantilla de proyecto)
│   ├── SOP - Conversion de carpetas a Markdown.md
│   └── instruccionesproyecto.md
│
└── Trabajados\                  <- Logs de cada ejecucion (se crea solo)
    ├── conversion_log_2026-06-12_1500.txt
    ├── conversion_log_2026-06-22_1500.txt
    └── ...
```

Y dentro de **cada proyecto**, el script crea su propia carpeta espejo:

```
...\Implantaciones Tazuke\Arg Bottling\
├── (archivos y subcarpetas originales)
└── _md\                         <- Espejo en Markdown (lo genera el script)
    └── (misma estructura, con .md)
```

---

## 3. Requisitos previos (una sola vez)

Estos pasos ya se hicieron al montar el sistema. Se documentan por si hay que reinstalar en otro equipo.

1. **Node.js** instalado (para otras automatizaciones; no imprescindible para este proceso).
2. **Python 3.10 o superior**. Comprobar en CMD: `python --version`.
3. **MarkItDown** con soporte completo:
   ```
   pip install "markitdown[all]"
   ```
4. Comprobar que responde: `markitdown --help`.

> Si `markitdown` no se reconoce como comando, no pasa nada: el script lo localiza solo en `%APPDATA%\Python\Python3XX\Scripts\markitdown.exe`.

---

## 4. Uso manual (bajo orden, cuando quieras)

Abre **PowerShell** y ejecuta uno de estos comandos.

### a) Procesar TODOS los proyectos de la lista
```
powershell -ExecutionPolicy Bypass -File "C:\Users\railo\OneDrive\Aplicaciones\Automatizaciones Claude\Convertir carpetas a.md\Convert-ProjectToMd.ps1" -ListFile "C:\Users\railo\OneDrive\Aplicaciones\Automatizaciones Claude\Convertir carpetas a.md\proyectos.txt"
```

### b) Procesar UN solo proyecto
```
powershell -ExecutionPolicy Bypass -File "C:\Users\railo\OneDrive\Aplicaciones\Automatizaciones Claude\Convertir carpetas a.md\Convert-ProjectToMd.ps1" -ProjectPath "C:\Users\railo\OneDrive - Nanopyme SL\Implantaciones Tazuke\Arg Bottling"
```

### c) Forzar reconversión total (ignorar el incremental)
Añade `-Force` al final de cualquiera de los anteriores. Útil si sospechas que algún `.md` quedó mal.

> **`-ExecutionPolicy Bypass`** permite ejecutar el script sin cambiar la política de seguridad del equipo. Es seguro y solo aplica a esa ejecución.

Al terminar, en pantalla verás un resumen tipo `Convertidos: X | Saltados: Y | Fallidos: Z` por cada proyecto, y la ruta del log generado.

---

## 5. Automatización: ejecución cada 10 días

Para que el sistema se actualice solo cada 10 días a las **15:00**, hay una tarea en el Programador de tareas de Windows. Se crea una sola vez con este comando en **CMD ejecutado como administrador**:

```
schtasks /Create /TN "Tazuke - Conversion MD proyectos" /TR "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"C:\Users\railo\OneDrive\Aplicaciones\Automatizaciones Claude\Convertir carpetas a.md\Convert-ProjectToMd.ps1\" -ListFile \"C:\Users\railo\OneDrive\Aplicaciones\Automatizaciones Claude\Convertir carpetas a.md\proyectos.txt\"" /SC DAILY /MO 10 /ST 15:00 /F
```

- `/SC DAILY /MO 10` = cada 10 días.
- `/ST 15:00` = a las 15:00.
- `/WindowStyle Hidden` = se ejecuta en segundo plano, sin abrir ventana.

**Gestión de la tarea:**
- Ver que existe: `schtasks /Query /TN "Tazuke - Conversion MD proyectos"`
- Ejecutarla ahora mismo a mano: `schtasks /Run /TN "Tazuke - Conversion MD proyectos"`
- Borrarla: `schtasks /Delete /TN "Tazuke - Conversion MD proyectos" /F`

### 5.1 ¿Qué pasa si el PC está apagado a las 15:00?

Por defecto, **si el equipo está apagado a la hora programada, esa ejecución se pierde**: Windows no la lanza y se espera al siguiente ciclo de 10 días. No se acumula ni se ejecuta sola al encender.

Para evitarlo existe la opción **"Ejecutar la tarea lo antes posible tras un inicio programado omitido"**: con ella, si el PC estaba apagado, Windows detecta la ejecución saltada y la lanza poco después de encenderlo. Esta opción **no se puede activar con `schtasks`**, hay que ponerla desde la interfaz gráfica. Por eso se recomienda crear la tarea así:

1. `Win` → abrir **"Programador de tareas"**.
2. A la derecha, **"Crear tarea..."** (no "básica").
3. **General:** nombre `Tazuke - Conversion MD proyectos`; marcar **"Ejecutar tanto si el usuario inició sesión como si no"** y **"Ejecutar con los privilegios más altos"**.
4. **Desencadenadores → Nuevo:** Diariamente, hora **15:00**, "Repetir cada" **10 días**.
5. **Acciones → Nuevo:**
   - Programa o script: `powershell`
   - Argumentos:
     ```
     -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Users\railo\OneDrive\Aplicaciones\Automatizaciones Claude\Convertir carpetas a.md\Convert-ProjectToMd.ps1" -ListFile "C:\Users\railo\OneDrive\Aplicaciones\Automatizaciones Claude\Convertir carpetas a.md\proyectos.txt"
     ```
6. **Condiciones:** desmarcar **"Iniciar la tarea solo si el equipo está conectado a la corriente"** (útil en portátil).
7. **Configuración:** marcar **"Ejecutar la tarea lo antes posible tras un inicio programado omitido"**. Opcional: "Si la tarea falla, reiniciar cada...".
8. Aceptar (pedirá la contraseña de Windows).

**Matices:** la ejecución de recuperación no es instantánea (Windows suele esperar hasta ~10 minutos tras el arranque) y, si el PC pasa varios ciclos apagado, solo recupera la última omitida, no todas. Para mantener los `.md` razonablemente al día es suficiente; y siempre queda el lanzamiento manual (sección 4) para forzarlo un día concreto.

---

## 6. Añadir o quitar proyectos

Editar el archivo `proyectos.txt`:
- **Añadir** un proyecto: escribir su ruta completa en una línea nueva (sin comillas).
- **Desactivar** temporalmente un proyecto: poner `#` al principio de su línea.
- No hace falta tocar el script ni la tarea programada: leen la lista en cada ejecución.

---

## 7. Control y registros (carpeta Trabajados)

Cada ejecución genera un archivo en `Trabajados\` con la fecha y hora en el nombre:
`conversion_log_AAAA-MM-DD_HHmm.txt`.

Dentro se ve, por proyecto: cada archivo convertido (`OK`), saltado (sin cambios) o fallido (`FALLO`), más un resumen final. Sirve para auditar qué se procesó y detectar archivos problemáticos.

---

## 8. Reglas y avisos importantes

- **OneDrive:** el script fuerza la descarga local de cada archivo antes de convertirlo. Aun así, el **primer** procesado de un proyecto grande puede tardar, porque baja de la nube lo que esté en modo "solo online". Las siguientes pasadas van rápidas.
- **No se borra nada:** el script solo crea/actualiza `.md` dentro de `_md`. Nunca toca ni elimina los originales.
- **Libros Excel con varias hojas:** se vuelcan todas seguidas en el mismo `.md`.
- **Fórmulas:** aparecen como su valor calculado, no como la fórmula.
- **Estilos:** el Markdown captura el contenido (texto y tablas), no el formato visual.
- **La carpeta `_md` se autoexcluye:** el script nunca intenta convertir su propia salida.

---

## 9. Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| Un archivo sale como `FALLO (sin salida)` en el log | Origen "solo en la nube" que no se descargó | Forzar descarga manual de la carpeta ("Mantener siempre en este dispositivo") y relanzar |
| Un archivo sale como `FALLO (...)` con un mensaje de MarkItDown entre paréntesis | El paréntesis indica la causa real: `Workbook is encrypted` (Excel con contraseña), `The formats ['.ppt'] are not supported` (PowerPoint 97-2003), `Unexpected EOF` o `No /Root object` (PDF dañado) | Quitar la contraseña o guardar como `.pptx` / PDF válido y relanzar; si no tiene arreglo, ignorar ese archivo |
| `'markitdown' no se reconoce` al usarlo suelto | La carpeta de scripts no está en el PATH | No afecta al script (lo localiza solo); para uso manual usar `python -m markitdown` |
| La tarea programada no se ejecuta | Equipo apagado a las 15:00 / permisos | Windows la lanza al siguiente arranque; comprobar con `schtasks /Query` |
| Aviso de `ffmpeg or avconv` | Falta ffmpeg (solo para audio) | Ignorar: no afecta a Office ni PDF |

---

## 10. Relación con los proyectos de Cowork

Para que un proyecto de Cowork aproveche estos `.md`, sus **instrucciones** deben indicar que lea preferentemente la carpeta `_md`. Esa indicación está recogida en la plantilla `instruccionesproyecto.md` (misma carpeta `Sops`), pensada para usarse al **crear proyectos nuevos**.

---

*Última actualización: junio 2026*
