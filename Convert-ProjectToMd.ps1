<#
================================================================
 Convert-ProjectToMd.ps1  (con OCR integrado)
 Convierte los archivos de un proyecto a Markdown (.md) en una
 subcarpeta espejo "_md", replicando la estructura de carpetas.

 NOVEDAD — OCR de rescate (opcional, con -OCR):
   - PDF escaneado: si tras convertir el .md queda vacio o casi,
     se pasa un OCR y su texto rellena el .md.
   - Imagenes (.jpg/.png/.tiff/.bmp): se reconocen con OCR.
   El OCR usa el motor Python "ocr-a-md.py" (Tesseract, spa+eng),
   que debe estar en la MISMA carpeta que este script.

 Caracteristicas base:
   - Espejo _md incremental (solo reconvierte lo que cambia).
   - Rutas largas (>260) con prefijo \\?\.
   - OneDrive: fuerza descarga y espera (no fatal).
   - CSV con ; -> tabla Markdown.
   - Registro UNICO acumulado en Markdown: Trabajados\registro-conversiones.md
     (cada ejecucion se anexa; solo resumen + fallos + rescatados por OCR).

 USO:
   # Como siempre (sin OCR):
   powershell -ExecutionPolicy Bypass -File "Convert-ProjectToMd.ps1" -ListFile "proyectos.txt"
   # Con rescate OCR:
   powershell -ExecutionPolicy Bypass -File "Convert-ProjectToMd.ps1" -ListFile "proyectos.txt" -OCR
================================================================
#>

param(
    [string]$ProjectPath,
    [string]$ListFile,
    [switch]$Force,
    [int]$MaxWaitSeconds = 30,
    [string]$LogDir = (Join-Path $PSScriptRoot "Trabajados"),
    # --- OCR ---
    [switch]$OCR,                       # activa el rescate OCR
    [int]$OcrMinChars = 15,             # si el .md de un PDF tiene menos de N caracteres utiles, se OCR-ea
    [string]$OcrLang = "spa+eng",       # idiomas de Tesseract
    [int]$OcrDpi = 300                  # resolucion de rasterizado del PDF
)

Add-Type -AssemblyName Microsoft.VisualBasic

$MarkItDown = Get-ChildItem "$env:APPDATA\Python\Python*\Scripts\markitdown.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $MarkItDown) { $MarkItDown = "markitdown" }

# Motor OCR (Python) y python.exe
$OcrScript = Join-Path $PSScriptRoot "ocr-a-md.py"
$PythonExe = "python"
$TessData  = Join-Path $PSScriptRoot "tessdata"   # opcional: carpeta propia con eng/spa

$Extensions      = @('.xlsx','.xls','.docx','.doc','.pptx','.ppt','.pdf','.csv','.html','.htm')
$ImageExtensions = @('.jpg','.jpeg','.png','.tiff','.tif','.bmp')

function Get-LongPath([string]$p) {
    if ([string]::IsNullOrEmpty($p)) { return $p }
    if ($p.StartsWith("\\?\")) { return $p }
    if ($p.StartsWith("\\"))   { return "\\?\UNC\" + $p.Substring(2) }
    return "\\?\" + $p
}

function Append-Log {
    param([string]$Path, [string[]]$Lines)
    for ($i = 0; $i -lt 6; $i++) {
        try { Add-Content -LiteralPath $Path -Value $Lines -Encoding UTF8; return }
        catch { Start-Sleep -Milliseconds 500 }
    }
}

function Get-MdCharCount {
    # Cuenta caracteres NO en blanco de un .md (para detectar PDF vacio)
    param([string]$LongPath)
    try {
        $t = [System.IO.File]::ReadAllText($LongPath)
        return ($t -replace '\s', '').Length
    } catch { return 0 }
}

function Invoke-Ocr {
    # Ejecuta el motor OCR de Python; escribe el .md directamente en UTF-8. Devuelve $true si OK.
    param([string]$SrcLong, [string]$DestLong)
    if (-not (Test-Path -LiteralPath $OcrScript)) { return $false }
    $ocrArgs = @($OcrScript, "$SrcLong", "--lang", $OcrLang, "--dpi", "$OcrDpi", "--out", "$DestLong")
    if (Test-Path -LiteralPath $TessData) { $ocrArgs += @("--tessdata", "$TessData") }
    try {
        & $PythonExe @ocrArgs 2>$null
        return (Test-Path -LiteralPath $DestLong)
    } catch { return $false }
}

function Read-TextSmart {
    # Detecta BOM UTF-8; si no hay, intenta UTF-8 estricto y si falla
    # (bytes invalidos) asume Windows-1252 (ANSI), habitual en CSV
    # exportados por Excel en Windows en espanol/europeo.
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    try {
        $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
        return $utf8Strict.GetString($bytes)
    } catch {
        return [System.Text.Encoding]::GetEncoding(1252).GetString($bytes)
    }
}

function Convert-SemicolonCsv {
    param([string]$SrcLong, [string]$DestLong)
    try {
        $text = Read-TextSmart -Path $SrcLong
        $reader = New-Object System.IO.StringReader($text)
        $parser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($reader)
        $parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
        $parser.SetDelimiters(';')
        $parser.HasFieldsEnclosedInQuotes = $true
        $rows = New-Object System.Collections.Generic.List[object]
        while (-not $parser.EndOfData) { $rows.Add($parser.ReadFields()) }
        $parser.Close()
        if ($rows.Count -eq 0) { return $false }
        $colCount = $rows[0].Count
        $sb = New-Object System.Text.StringBuilder
        $hdr = ($rows[0] | ForEach-Object { ($_ -replace '\|','\|').Trim() }) -join ' | '
        [void]$sb.AppendLine('| ' + $hdr + ' |')
        [void]$sb.AppendLine('| ' + ((1..$colCount | ForEach-Object { '---' }) -join ' | ') + ' |')
        for ($i = 1; $i -lt $rows.Count; $i++) {
            $r = $rows[$i]
            $cells = for ($c = 0; $c -lt $colCount; $c++) {
                if ($c -lt $r.Count) { ($r[$c] -replace '\|','\|') } else { '' }
            }
            [void]$sb.AppendLine('| ' + ($cells -join ' | ') + ' |')
        }
        [System.IO.File]::WriteAllText($DestLong, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
        return (Test-Path -LiteralPath $DestLong)
    } catch { return $false }
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
# Un UNICO registro en Markdown que se va acumulando en cada ejecucion
$LogFile = Join-Path $LogDir "registro-conversiones.md"
if (-not (Test-Path -LiteralPath $LogFile)) {
    Append-Log -Path $LogFile -Lines @("# Registro de conversiones a Markdown", "")
}
# Cabecera de esta ejecucion (se anexa al final del mismo .md)
Append-Log -Path $LogFile -Lines @(
    "",
    "## $(Get-Date -Format 'yyyy-MM-dd HH:mm') — Force: $Force · OCR: $OCR · Espera: ${MaxWaitSeconds}s",
    ""
)

function Wait-Hydrated {
    param([string]$LongPath, [int]$MaxSeconds)
    $RECALL_ON_DATA_ACCESS = 0x400000; $RECALL_ON_OPEN = 0x40000; $OFFLINE = 0x1000
    $elapsed = 0
    while ($true) {
        try { $attrs = [int]([System.IO.File]::GetAttributes($LongPath)) } catch { return }
        if (-not (($attrs -band $RECALL_ON_DATA_ACCESS) -or ($attrs -band $RECALL_ON_OPEN) -or ($attrs -band $OFFLINE))) { return }
        if ($elapsed -ge $MaxSeconds) { return }
        Start-Sleep -Seconds 2; $elapsed += 2
    }
}

function Convert-OneProject {
    param([string]$Root, [switch]$ForceAll, [string]$Log, [int]$MaxWait)
    if (-not (Test-Path -LiteralPath $Root)) {
        Write-Host "ERROR: no existe la carpeta $Root" -ForegroundColor Red
        Append-Log -Path $Log -Lines @("### $Root", "_No existe la carpeta._", ""); return
    }
    $MirrorRoot = Join-Path $Root "_md"
    New-Item -ItemType Directory -Force -Path (Get-LongPath $MirrorRoot) | Out-Null
    $failLines = New-Object System.Collections.Generic.List[string]   # solo fallos
    $ocrLines  = New-Object System.Collections.Generic.List[string]   # solo rescatados por OCR
    $converted = 0; $skipped = 0; $failed = 0; $ocrCount = 0

    # Extensiones a procesar: documentos siempre; imagenes solo si -OCR
    $exts = $Extensions
    if ($OCR) { $exts = $Extensions + $ImageExtensions }

    Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
        ($exts -contains $_.Extension.ToLower()) -and ($_.FullName -notlike "$MirrorRoot*")
    } | ForEach-Object {
        $src = $_.FullName; $ext = $_.Extension.ToLower()
        $rel = $src.Substring($Root.Length).TrimStart('\')
        $relMd = [System.IO.Path]::ChangeExtension($rel, ".md")
        $dest = Join-Path $MirrorRoot $relMd
        $destDir = Split-Path $dest -Parent
        $srcLong = Get-LongPath $src; $destLong = Get-LongPath $dest
        New-Item -ItemType Directory -Force -Path (Get-LongPath $destDir) | Out-Null
        if ((-not $ForceAll) -and (Test-Path -LiteralPath $destLong) -and
            ((Get-Item -LiteralPath $destLong).LastWriteTime -ge $_.LastWriteTime)) { $skipped++; return }
        attrib +P "$src" 2>$null | Out-Null
        Wait-Hydrated -LongPath $srcLong -MaxSeconds $MaxWait

        # --- Imagen: OCR directo (solo si -OCR, que es cuando llega aqui) ---
        if ($ImageExtensions -contains $ext) {
            if (Invoke-Ocr -SrcLong $srcLong -DestLong $destLong) { $converted++; $ocrCount++; $ocrLines.Add("$rel [imagen]") }
            else { $failed++; $failLines.Add("$rel (OCR imagen)") }
            return
        }

        # --- CSV con ; ---
        $isCsvSemicolon = $false
        if ($ext -eq '.csv') {
            try {
                $fl = [System.IO.File]::ReadLines($srcLong) | Select-Object -First 1
                if ($fl) {
                    $semi = ([regex]::Matches($fl, ';')).Count; $comma = ([regex]::Matches($fl, ',')).Count
                    if ($semi -gt $comma) { $isCsvSemicolon = $true }
                }
            } catch {}
        }

        try {
            if ($isCsvSemicolon) {
                if (Convert-SemicolonCsv -SrcLong $srcLong -DestLong $destLong) { $converted++ }
                else { $failed++; $failLines.Add("$rel (csv ; no convertido)") }
            } else {
                $mdOutput = & $MarkItDown "$srcLong" -o "$destLong" 2>&1
                if (Test-Path -LiteralPath $destLong) {
                    # --- Rescate OCR para PDF vacio/escaneado ---
                    if ($OCR -and $ext -eq '.pdf' -and (Get-MdCharCount $destLong) -lt $OcrMinChars) {
                        if (Invoke-Ocr -SrcLong $srcLong -DestLong $destLong) { $converted++; $ocrCount++; $ocrLines.Add("$rel [pdf escaneado]") }
                        else { $failed++; $failLines.Add("$rel (OCR pdf)") }
                    } else {
                        $converted++
                    }
                }
                else {
                    $failed++
                    # stderr llega como ErrorRecord: se usa Exception.Message porque en Windows
                    # PowerShell 5.1 ToString() de una linea vacia devuelve el nombre del tipo.
                    $reason = ($mdOutput | ForEach-Object {
                        if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { [string]$_ }
                    } | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -Last 1)
                    if (-not $reason) { $reason = "sin salida" }
                    $failLines.Add("$rel ($reason)")
                }
            }
        } catch { $failed++; $failLines.Add("$rel ($($_.Exception.Message))") }
    }
    Write-Host "[$Root] Convertidos: $converted | Saltados: $skipped | Fallidos: $failed | OCR: $ocrCount" -ForegroundColor Cyan
    # --- Bloque Markdown de este proyecto para el registro acumulado ---
    $block = New-Object System.Collections.Generic.List[string]
    $block.Add("### $Root")
    $block.Add("Convertidos: $converted · Saltados: $skipped · Fallidos: $failed · OCR: $ocrCount")
    if ($ocrLines.Count -gt 0) {
        $block.Add(""); $block.Add("Rellenados por OCR:")
        foreach ($o in $ocrLines) { $block.Add("- $o") }
    }
    if ($failLines.Count -gt 0) {
        $block.Add(""); $block.Add("Fallidos:")
        foreach ($f in $failLines) { $block.Add("- $f") }
    }
    $block.Add("")
    Append-Log -Path $Log -Lines $block.ToArray()
}

if ($ListFile) {
    if (-not (Test-Path -LiteralPath $ListFile)) { Write-Host "ERROR: no existe la lista $ListFile" -ForegroundColor Red; exit 1 }
    Get-Content -LiteralPath $ListFile | Where-Object { $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") } | ForEach-Object {
        Convert-OneProject -Root $_.Trim().Trim('"') -ForceAll:$Force -Log $LogFile -MaxWait $MaxWaitSeconds
    }
}
elseif ($ProjectPath) {
    Convert-OneProject -Root $ProjectPath.Trim('"') -ForceAll:$Force -Log $LogFile -MaxWait $MaxWaitSeconds
}
else { Write-Host "Indica -ProjectPath o -ListFile" -ForegroundColor Yellow }

Write-Host "Registro actualizado en: $LogFile" -ForegroundColor Green
