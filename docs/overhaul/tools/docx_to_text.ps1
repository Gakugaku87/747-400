# Dump a Word (.docx) reference in _ref/ to text the way extract_pdfs.sh
# does a PDF: _ref/text/<Id>/pNNNN.txt (one file a page), _ref/text/<Id>.txt
# (all pages with "==== [<Id> p.N] ====" markers) and _ref/text/<Id>.pages.tsv
# (page, non-blank characters, first and last non-blank lines). A .docx has
# no fixed pages: a page ends at Word's last rendered page break or at a
# manual page break (estimate of the printed pages). Paragraphs and table
# cells end a line. Nothing needs installing (Windows PowerShell 5.1).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File docx_to_text.ps1 -Id <ID> -File <name>.docx
#   (first used for the 2026-11-19 CMCS document, removed on 2026-11-20 as
#   not the 747's: no .docx reference is left)
param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$File
)
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$ref = Join-Path $root '_ref'
$out = Join-Path $ref 'text'
$path = Join-Path $ref $File
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($path)
try {
    $entry = $zip.GetEntry('word/document.xml')
    $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
    $xml = $reader.ReadToEnd()
    $reader.Close()
} finally { $zip.Dispose() }

$ff = [char]12
$t = $xml
$t = $t -replace '<w:lastRenderedPageBreak/>', $ff
$t = $t -replace '<w:br [^>]*w:type="page"[^>]*/>', $ff
$t = $t -replace '<w:tab/>', "`t"
$t = $t -replace '<w:br/>', "`n"
$t = $t -replace '</w:p>', "`n"
$t = $t -replace '</w:tc>', ' | '
$t = $t -replace '<[^>]+>', ''
$t = $t.Replace('&lt;', '<').Replace('&gt;', '>').Replace('&quot;', '"').Replace('&apos;', "'").Replace('&amp;', '&')
$pages = $t.Split($ff)

$dir = Join-Path $out $Id
if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$whole = New-Object System.Text.StringBuilder
$stats = New-Object System.Text.StringBuilder
[void]$stats.Append("page`tchars`tfirst_line`tlast_line`n")
$n = 0
foreach ($p in $pages) {
    $body = ($p -replace "`r", '')
    if ($n -gt 0 -and $body.Trim() -eq '') { continue }
    $n++
    [System.IO.File]::WriteAllText((Join-Path $dir ('p{0:D4}.txt' -f $n)), $body, $utf8)
    [void]$whole.Append("==== [$Id p.$n] ====`n").Append($body).Append("`n")
    $lines = @($body.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $first = if ($lines.Count) { $lines[0] } else { '' }
    $last = if ($lines.Count) { $lines[-1] } else { '' }
    $chars = ($body -replace '\s', '').Length
    $f1 = ($first -replace "`t", ' '); if ($f1.Length -gt 120) { $f1 = $f1.Substring(0, 120) }
    $l1 = ($last -replace "`t", ' '); if ($l1.Length -gt 120) { $l1 = $l1.Substring(0, 120) }
    [void]$stats.Append("$n`t$chars`t$f1`t$l1`n")
}
[System.IO.File]::WriteAllText((Join-Path $out "$Id.txt"), $whole.ToString(), $utf8)
[System.IO.File]::WriteAllText((Join-Path $out "$Id.pages.tsv"), $stats.ToString(), $utf8)
"$Id`tpages=$n"
