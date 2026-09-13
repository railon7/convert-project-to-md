#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ocr-a-md.py  ·  Motor OCR para el conversor a Markdown
------------------------------------------------------
Recibe la ruta de un PDF escaneado o de una imagen y devuelve por
pantalla (stdout) el texto reconocido en formato Markdown.

- PDF: rasteriza cada pagina EN MEMORIA con PyMuPDF (no necesita Ghostscript
  ni Poppler) y la pasa por Tesseract.
- Imagen (.jpg/.png/.tiff/.bmp): OCR directo.

Todo el proceso es LOCAL; nada sale del equipo.

Uso:
    python ocr-a-md.py "ruta\\al\\archivo.pdf" [--lang spa+eng] [--dpi 300]

Requisitos: Tesseract instalado + paquetes pip: pymupdf, pytesseract, pillow.
"""

import sys
import os
import argparse
import io

def find_tesseract():
    """Localiza tesseract.exe en Windows si no esta en el PATH."""
    import shutil
    if shutil.which("tesseract"):
        return None  # ya esta en el PATH
    candidatos = [
        r"C:\Program Files\Tesseract-OCR\tesseract.exe",
        r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
        os.path.expandvars(r"%LOCALAPPDATA%\Programs\Tesseract-OCR\tesseract.exe"),
    ]
    for c in candidatos:
        if os.path.isfile(c):
            return c
    return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("archivo")
    ap.add_argument("--lang", default="spa+eng")
    ap.add_argument("--dpi", type=int, default=300)
    ap.add_argument("--tessdata", default="")  # carpeta tessdata propia (opcional)
    ap.add_argument("--out", default="")        # si se indica, escribe el .md directamente (UTF-8)
    args = ap.parse_args()

    ruta = args.archivo
    if not os.path.isfile(ruta):
        sys.stderr.write(f"ERROR: no existe el archivo: {ruta}\n")
        sys.exit(2)

    try:
        import pytesseract
        from PIL import Image
    except ImportError as e:
        sys.stderr.write(f"ERROR: falta un paquete Python ({e}). "
                         f"Instala: pip install pymupdf pytesseract pillow\n")
        sys.exit(3)

    tpath = find_tesseract()
    if tpath:
        pytesseract.pytesseract.tesseract_cmd = tpath

    # Configuracion pensada para texto impreso, numeros y tablas (pseudo):
    #  --oem 3  motor LSTM
    #  --psm 6  bloque uniforme de texto (respeta mejor columnas)
    #  preserve_interword_spaces=1  conserva la separacion (util para tablas)
    cfg = "--oem 3 --psm 6 -c preserve_interword_spaces=1"
    if args.tessdata:
        cfg = f'--tessdata-dir "{args.tessdata}" ' + cfg

    ext = os.path.splitext(ruta)[1].lower()
    salida = []
    nombre = os.path.basename(ruta)
    salida.append(f"<!-- Texto recuperado por OCR ({args.lang}) de: {nombre} -->\n")

    try:
        if ext == ".pdf":
            import fitz  # PyMuPDF
            doc = fitz.open(ruta)
            zoom = args.dpi / 72.0
            mat = fitz.Matrix(zoom, zoom)
            for i, page in enumerate(doc, start=1):
                pix = page.get_pixmap(matrix=mat)
                img = Image.open(io.BytesIO(pix.tobytes("png")))
                texto = pytesseract.image_to_string(img, lang=args.lang, config=cfg)
                texto = texto.strip()
                if len(doc) > 1:
                    salida.append(f"\n## Pagina {i}\n")
                salida.append(texto if texto else "_(sin texto reconocible en esta pagina)_")
            doc.close()
        else:
            img = Image.open(ruta)
            texto = pytesseract.image_to_string(img, lang=args.lang, config=cfg).strip()
            salida.append(texto if texto else "_(sin texto reconocible)_")
    except Exception as e:
        sys.stderr.write(f"ERROR durante el OCR: {e}\n")
        sys.exit(1)

    texto_final = "\n".join(salida) + "\n"
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(texto_final)
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stdout.write(texto_final)

if __name__ == "__main__":
    main()
