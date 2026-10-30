# Make the custom acf's FMA mode failure line (6-3 step 5c; ACF_DIFF.md
# section 5) in cockpit_3d/generic/CRT Displays/PFD/Flight Mode Annun: the
# amber horizontal line drawn through a failed active roll or pitch mode
# (FCOM p.653, p.660), 104 x 3 pixels (the widest mode, VNAV PATH, is 103
# across; the letters 19 high), in the amber of the PFD's other amber
# images. Nothing needs installing: Windows PowerShell 5.1 and
# System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_fma_fail_images.ps1
#
# The image is written as mode_fail-1.png, which a gen_rotary shows centred
# on its POS (docs/overhaul/tools/panel_fma_fail.lua), and a transparent
# mode_fail.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\PFD\Flight Mode Annun'

$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)
$W, $H = 104, 3

$bmp = New-Object System.Drawing.Bitmap $W, $H
for ($x = 0; $x -lt $W; $x++) {
    for ($y = 0; $y -lt $H; $y++) { $bmp.SetPixel($x, $y, $AMBER) }
}
$bmp.Save((Join-Path $dir 'mode_fail-1.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$clear = New-Object System.Drawing.Bitmap $W, $H
$clear.Save((Join-Path $dir 'mode_fail.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$clear.Dispose()
Write-Host "mode_fail ($W x $H)"
