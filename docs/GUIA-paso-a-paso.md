# 🧭 Guía paso a paso · Convertir carpetas a Markdown

> Manual completo **desde cero** para Windows, pensado también para quien no es técnico.
> Convierte tus documentos (Excel, Word, PDF) en texto ligero para que la IA los lea **gastando muchos menos tokens**.

---

## 💡 ¿Por qué hacer esto?

Cuando le das a una IA (ChatGPT, Claude…) archivos pesados (Excels enormes, PDF, presentaciones), cada lectura **consume muchos tokens** y va lenta. Si antes los conviertes a **Markdown** (texto plano y ligero), la IA lee y busca mucho más rápido y barato. Esta guía te deja todo montado para que se haga **solo, cada 10 días**.

---

## 📑 Índice

1. [Resumen](#-resumen-qué-vas-a-hacer)
2. [Paso 1 · Instalar Python](#-paso-1--instalar-python)
3. [Paso 2 · Instalar MarkItDown](#-paso-2--instalar-markitdown)
4. [Paso 3 · Activar rutas largas](#-paso-3--activar-rutas-largas-en-windows)
5. [Paso 4 · Colocar el script](#-paso-4--colocar-el-script-y-la-lista)
6. [Paso 5 · Configurar la lista](#-paso-5--configurar-la-lista-proyectostxt)
7. [Paso 6 · Primera prueba](#-paso-6--primera-prueba-una-sola-carpeta)
8. [Paso 7 · Convertir todo](#-paso-7--convertir-todas-las-carpetas)
9. [Paso 8 · Revisar el resultado](#-paso-8--revisar-el-resultado)
10. [Paso 9 · Automatizar cada 10 días](#-paso-9--automatizar-cada-10-días)
11. [Trabajar con la IA gastando pocos tokens](#-trabajar-con-la-ia-gastando-pocos-tokens)
12. [Si algo falla: prompts listos](#-si-algo-falla-prompts-listos-para-la-ia)
13. [Solución de problemas](#-solución-de-problemas-rápida)

> 📌 Sustituye `TU_USUARIO` por tu nombre de usuario de Windows en todas las rutas.

---

## ✅ Resumen: qué vas a hacer

1. Instalar **Python** (el motor del conversor).
2. Instalar **MarkItDown** (la herramienta que convierte).
3. Activar **rutas largas** en Windows (un ajuste único).
4. Colocar el **script** y la lista de carpetas.
5. Hacer una **prueba** y convertir **todo**.
6. **Automatizar** cada 10 días.

> Necesitarás dos archivos: `Convert-ProjectToMd.ps1` (el conversor) y `proyectos.txt` (la lista de carpetas).

---

## 🐍 Paso 1 · Instalar Python

1. Entra en [python.org](https://www.python.org) y descarga **"Download Python"** (versión 3.10 o superior).
2. Abre el instalador. **⚠️ MUY IMPORTANTE:** marca la casilla **"Add python.exe to PATH"** (abajo del todo) antes de continuar.
3. Pulsa **"Install Now"** y espera.
4. Comprueba en **CMD** (tecla Windows → `cmd` → Enter):

```bash
python --version
```

Si devuelve un número (ej. `Python 3.13.0`), perfecto. Si dice que no se reconoce, reinstala marcando la casilla de PATH.

---

## 📦 Paso 2 · Instalar MarkItDown

En la misma ventana de CMD:

```bash
pip install "markitdown[all]"
```

Cuando acabe, comprueba:

```bash
markitdown --help
```

Si aparece la ayuda, está listo.

> ℹ️ Si `markitdown` dice que no se reconoce, no pasa nada: el script lo encuentra solo.
> ℹ️ El aviso amarillo sobre `ffmpeg` solo afecta a audio. Para Excel, Word y PDF, ignóralo.

---

## 📏 Paso 3 · Activar rutas largas en Windows

Windows tiene un límite antiguo de 260 caracteres. Si tienes carpetas con nombres largos, algunos archivos fallarían. Esto lo soluciona (una sola vez):

1. Tecla Windows → escribe **"PowerShell"**.
2. **Clic derecho** → **"Ejecutar como administrador"**. Acepta el aviso.
3. Pega y pulsa Enter:

```powershell
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

4. **Reinicia el ordenador** para que tenga efecto.

> ⚠️ Este comando da error si la ventana **no** es de administrador.

---

## 📁 Paso 4 · Colocar el script y la lista

1. Crea una carpeta para la automatización, por ejemplo:
   `C:\Users\TU_USUARIO\Documentos\Conversor MD`
2. Copia dentro `Convert-ProjectToMd.ps1` y `proyectos.txt` (y también `ocr-a-md.py` si vas a usar el OCR opcional; ver `INSTALACION-OCR.md`).
3. No crees nada más: el script creará solo la subcarpeta `Trabajados` (registros) y, dentro de cada proyecto, una subcarpeta `_md` con los archivos convertidos.

---

## 📝 Paso 5 · Configurar la lista (proyectos.txt)

Abre `proyectos.txt` con el Bloc de notas y pon **una ruta por línea**:

```text
C:\Users\TU_USUARIO\OneDrive\Proyectos\Cliente A
C:\Users\TU_USUARIO\OneDrive\Proyectos\Cliente B
```

- No hace falta poner comillas.
- Para desactivar una sin borrarla, pon `#` al principio de su línea.
- Guárdalo asegurándote de que se llama `proyectos.txt` (y no `proyectos.txt.txt`).

---

## 🧪 Paso 6 · Primera prueba (una sola carpeta)

Abre **PowerShell** (normal) y pega en una sola línea, cambiando las rutas:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\TU_USUARIO\Documentos\Conversor MD\Convert-ProjectToMd.ps1" -ProjectPath "C:\Users\TU_USUARIO\OneDrive\Proyectos\Cliente A"
```

Verás un resumen: `Convertidos: X | Saltados: Y | Fallidos: Z`. Comprueba que apareció la subcarpeta `_md`.

> ☁️ **Si usas OneDrive:** antes, clic derecho en la carpeta → **"Mantener siempre en este dispositivo"** y espera a los iconos verdes. Los archivos "solo en la nube" pueden fallar.

---

## 🚀 Paso 7 · Convertir todas las carpetas

Cuando la prueba vaya bien:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\TU_USUARIO\Documentos\Conversor MD\Convert-ProjectToMd.ps1" -ListFile "C:\Users\TU_USUARIO\Documentos\Conversor MD\proyectos.txt"
```

La primera vez tarda; las siguientes son rápidas (solo procesa lo que cambió).

> 🔁 ¿Rehacer todo desde cero? Añade `-Force` al final.

---

## 🔍 Paso 8 · Revisar el resultado

Todas las ejecuciones se acumulan en `Trabajados\registro-conversiones.md` (la última queda al final). Para ver sus últimas líneas:

```powershell
Get-Content "C:\Users\TU_USUARIO\Documentos\Conversor MD\Trabajados\registro-conversiones.md" -Tail 40
```

Si bajo el proyecto no aparece la lista «Fallidos», no hubo fallos. Algún fallo suelto es normal; la causa sale entre paréntesis (archivo con contraseña, formato antiguo, PDF dañado).

---

## ⏰ Paso 9 · Automatizar cada 10 días

Con el **Programador de tareas** de Windows:

1. Tecla Windows → **"Programador de tareas"**.
2. A la derecha, **"Crear tarea..."** (no la básica).
3. **General:** nombre `Conversor MD`. Marca *"Ejecutar tanto si el usuario inició sesión como si no"* y *"Ejecutar con los privilegios más altos"*.
4. **Desencadenadores → Nuevo:** Diariamente, hora **15:00**, "Repetir cada" **10 días**.
5. **Acciones → Nuevo:** programa `powershell`; argumentos (una línea):

```powershell
-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Users\TU_USUARIO\Documentos\Conversor MD\Convert-ProjectToMd.ps1" -ListFile "C:\Users\TU_USUARIO\Documentos\Conversor MD\proyectos.txt"
```

6. **Condiciones:** desmarca *"Iniciar solo si está conectado a la corriente"*.
7. **Configuración:** marca **"Ejecutar la tarea lo antes posible tras un inicio programado omitido"**.
8. Acepta (pedirá tu contraseña de Windows).
9. **Probar:** clic derecho en la tarea → **Ejecutar**. Si añade una entrada nueva al final del registro, está perfecta.

> 🔌 **¿PC apagado a las 15:00?** Con el ajuste del punto 7, se lanza sola al encender. No se pierde.

---

## 🤖 Trabajar con la IA gastando pocos tokens

Cuando trabajes un proyecto con la IA, **dile que use la carpeta `_md`** en lugar de los originales pesados. Pega esto en tus instrucciones:

> *"Para buscar información y leer documentos de este proyecto, usa **primero** los archivos de la carpeta `_md` (versión en texto de los originales). Acude al archivo original solo si necesitas un dato o una fórmula exacta que el texto no conserve."*

---

## 🆘 Si algo falla: prompts listos para la IA

Copia el error y pégaselo a la IA con uno de estos prompts:

**1) No me funciona un comando**
> "Estoy en Windows con PowerShell. He ejecutado: *[comando]* y da este error: *[error completo]*. ¿Qué significa y cómo lo soluciono paso a paso?"

**2) Instalar Python o MarkItDown**
> "Tengo Windows y quiero instalar Python (con Add to PATH) y luego `pip install markitdown[all]`. Dame los pasos exactos y cómo comprobar que está bien."

**3) Un archivo sale como FALLO**
> "En el registro, este archivo aparece en Fallidos: *[línea]*. ¿Qué significa la causa que va entre paréntesis y qué hago?"

**4) Crear la tarea programada**
> "Guíame para crear una tarea en el Programador de tareas que ejecute este comando cada 10 días a las 15:00, y que corra aunque el PC haya estado apagado: *[comando]*."

---

## 🧯 Solución de problemas rápida

| Síntoma | Causa probable | Solución |
|---|---|---|
| Acaba pero no se crea el `.md` | Archivo "solo en la nube" (OneDrive) | Clic derecho → "Mantener siempre en este dispositivo" y relanzar |
| `'markitdown' no se reconoce` | No quedó en el PATH | No afecta al script; manual: `python -m markitdown` |
| Error de "ruta demasiado larga" | Falta activar rutas largas | Repite el Paso 3 (admin) y reinicia |
| Aviso de `ffmpeg` | Solo afecta a audio | Ignorar |
| La tarea no se ejecutó | PC apagado a esa hora | Se lanza al encender (si marcaste el ajuste) |
| PowerShell bloquea un `.ps1` | Política de ejecución | Usa siempre `-ExecutionPolicy Bypass` |

---

*¿Dudas? Abre un issue en el repositorio o sigue los prompts de arriba.*
