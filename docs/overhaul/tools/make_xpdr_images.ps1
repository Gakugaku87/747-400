# Make the custom acf's transponder display label (5-1 step 5d; ACF_DIFF.md
# section 5) in cockpit_3d/generic/Radios: atc_lr, two frames side by side,
# 60 x 20 each: 0 "ATC L", 1 "ATC R" (the 570 panel's code display shows
# the selected transponder above the code: FCOM p.1218). The letters are
# Windows' Bahnschrift SemiBold SemiCondensed, 13 pixels high, left-aligned,
# in the orange of the stock radio displays (FreqLCD: 255, 108, 0).
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_xpdr_images.ps1
#
# The image is written as atc_lr-1.png and a transparent atc_lr.png of the
# same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\Radios'

$ORANGE = [System.Drawing.Color]::FromArgb(255, 255, 108, 0)
$FACE = 'Bahnschrift SemiBold SemiConden'
$FW = 60; $FH = 20; $CAP = 13

$bmp = New-Object System.Drawing.Bitmap ($FW * 2), $FH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
# a font size whose capital H is $CAP pixels high
$size = 10.0
do {
    $size += 0.25
    $font = New-Object System.Drawing.Font $FACE, ([single]$size), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $ascent = $font.FontFamily.GetCellAscent($font.Style) * $font.Size / $font.FontFamily.GetEmHeight($font.Style)
    $capH = 0.7 * $font.Size
    if ($capH -lt $CAP) { $font.Dispose() }
} while ($capH -lt $CAP)
$brush = New-Object System.Drawing.SolidBrush $ORANGE
$labels = @('ATC L', 'ATC R')
for ($k = 0; $k -lt 2; $k++) {
    # the capitals' baseline at the frame's middle plus half the cap height
    $y = ($FH + $CAP) / 2.0 - $ascent
    $g.DrawString($labels[$k], $font, $brush, [single]($FW * $k + 2), [single]$y)
}
$brush.Dispose(); $font.Dispose(); $g.Dispose()
$bmp.Save((Join-Path $dir 'atc_lr-1.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
$clear.Save((Join-Path $dir 'atc_lr.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$clear.Dispose()
Write-Host "atc_lr ($($bmp.Width) x $($bmp.Height), font $size px)"
$bmp.Dispose()
