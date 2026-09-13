<#
================================================================
 Convert-ProjectToMd.ps1  (version portable)
 Convierte todos los archivos de un proyecto a Markdown (.md)
 replicando la estructura de carpetas dentro de una subcarpeta "_md".
 Pensado para optimizar el trabajo con IA (texto ligero = menos tokens).

 - Soporta rutas largas (>260 caracteres) con el prefijo \\?\.
 - Margen de espera para descarga de OneDrive (no fatal).
 - Log robusto en UTF-8, en la subcarpeta "Trabajados" (junto a este script).
 - CSV con punto y coma (;) -> se convierten a tabla Markdown.

 USO (un proyecto):
   powershell -ExecutionPolicy Bypass -File "Convert-ProjectToMd.ps1" -ProjectPath "C:\ruta\al\proyecto"

 USO (varios proyectos desde la lista):
   powershell -ExecutionPolicy Bypass -File "Convert-ProjectToMd.ps1" -ListFile "C:\ruta\a\proyectos.txt"

 Forzar reconversion total:
   ... -Force
================================================================
#>

param(
    [string]$ProjectPath,
    [string]$ListFile,
    [switch]$Force,
    [int]$MaxWaitSeconds = 30,
    [string]$LogDir = (Join-Path $PSScriptRoot "Trabajados")
)

Add-Type -AssemblyName Microsoft.VisualBasic

$MarkItDown = Get-ChildItem "$env:APPDATA\Python\Python*\Scripts\markitdown.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $MarkItDown) { $MarkItDown = "markitdown" }

$Extensions = @('.xlsx','.xls','.docx','.doc','.pptx','.ppt','.pdf','.csv','.html','.htm')

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
$RunStamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$LogFile  = Join-Path $LogDir "conversion_log_$RunStamp.txt"
$header = @(
    "###### REGISTRO DE CONVERSION ######",
    "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Modo Force: $Force | Espera max: $MaxWaitSeconds s | Rutas largas: si | CSV ;: si",
    "------------------------------------"
)
Append-Log -Path $LogFile -Lines $header

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
        Append-Log -Path $Log -Lines @("ERROR: no existe la carpeta $Root"); return
    }
    $MirrorRoot = Join-Path $Root "_md"
    New-Item -ItemType Directory -Force -Path (Get-LongPath $MirrorRoot) | Out-Null
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(""); $lines.Add("===== PROYECTO: $Root =====")
    $converted = 0; $skipped = 0; $failed = 0
    Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
        ($Extensions -contains $_.Extension.ToLower()) -and ($_.FullName -notlike "$MirrorRoot*")
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
                if (Convert-SemicolonCsv -SrcLong $srcLong -DestLong $destLong) { $converted++; $lines.Add("OK    $rel  [csv ;]") }
                else { $failed++; $lines.Add("FALLO $rel (csv ; no convertido)") }
            } else {
                $mdOutput = & $MarkItDown "$srcLong" -o "$destLong" 2>&1
                if (Test-Path -LiteralPath $destLong) { $converted++; $lines.Add("OK    $rel") }
                else {
                    $failed++
                    $reason = ($mdOutput | ForEach-Object { $_.ToString() } | Where-Object { $_.Trim() -ne "" } | Select-Object -Last 1)
                    if (-not $reason) { $reason = "sin salida" }
                    $lines.Add("FALLO $rel ($reason)")
                }
            }
        } catch { $failed++; $lines.Add("FALLO $rel ($($_.Exception.Message))") }
    }
    $summary = "[$Root] Convertidos: $converted | Saltados: $skipped | Fallidos: $failed"
    Write-Host $summary -ForegroundColor Cyan
    $lines.Add($summary)
    Append-Log -Path $Log -Lines $lines.ToArray()
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

Write-Host "Log guardado en: $LogFile" -ForegroundColor Green
