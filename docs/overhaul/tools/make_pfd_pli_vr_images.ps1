# Make the custom acf's PFD images for 5-2 step 4c, in cockpit_3d/generic/
# CRT Displays/PFD:
#  - Artificial Horizon/HrznPLI: the pitch limit indication (FCOM p.974
#    (10.10.12), 109 and 405): two brackets over the inner part of the
#    airplane symbol's wings, each a bar with three slanted ticks above it
#    and a short leg down at its inner end; the image is as wide as the
#    airplane symbol (255, its centre on the symbol's) and 480 high with the
#    bars on its middle row: a CLIP pointer shows only what stays inside its
#    image's place, so it must be tall like the RA's pitch images (a 40-high
#    first try did not show at all). Amber (the FCOM's figure is grey:
#    estimate);
#  - Vspeeds/VrR: the VR bug with R only (FCOM p.972: "displays R when VR
#    within 4 knots of V1"): the stock image with the V removed and the R
#    moved up to the bug line.
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_pfd_pli_vr_images.ps1
#
# Each image is written as <name>-1.png, which a gen_pointer or gen_rotary
# shows centred on its POS, and a transparent <name>.png of the same size,
# as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$pfd = Join-Path $root 'cockpit_3d\generic\CRT Displays\PFD'
$hrzn = Join-Path $pfd 'Artificial Horizon'
$vsp = Join-Path $pfd 'Vspeeds'

$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$dir, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $clear.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height))"
}

# the PLI: the airplane symbol's wings span x 4-72 and 182-250 of its 255,
# their inner legs at x 61-72 and 182-193 (HrznArplnSymbol-1.png). In the
# FCOM's figure each bracket covers the inner 38 % of a wing (26 pixels),
# its ticks half the bar's length high (12), its leg a fifth (5)
$W, $H, $MID = 255, 480, 240
$b = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$pen = New-Object System.Drawing.Pen $AMBER, 2
foreach ($side in @(-1, 1)) {
    # x of the bar's inner end and the direction outwards
    $inner = if ($side -lt 0) { 72 } else { 182 }
    $out = $inner + $side * 26
    $g.DrawLine($pen, $inner, $MID, $out, $MID)
    $g.DrawLine($pen, $inner, $MID, $inner, $MID + 5)
    foreach ($k in 0..2) {
        $base = $out - $side * (4 + 7 * $k)
        $g.DrawLine($pen, $base, $MID, $base + $side * 6, $MID - 12)
    }
}
$pen.Dispose(); $g.Dispose()
Save-Pair $b $hrzn 'HrznPLI'; $b.Dispose()

# VR -> R: the dash is columns 17-30, the V 31-40, the R 41-50
$in = New-Object System.Drawing.Bitmap (Join-Path $vsp 'Vr-1.png')
$b = New-Object System.Drawing.Bitmap $in.Width, $in.Height
for ($y = 0; $y -lt $in.Height; $y++) {
    for ($x = 0; $x -le 30; $x++) { $b.SetPixel($x, $y, $in.GetPixel($x, $y)) }
    for ($x = 41; $x -le 50; $x++) { $b.SetPixel($x - 10, $y, $in.GetPixel($x, $y)) }
}
$in.Dispose()
Save-Pair $b $vsp 'VrR'; $b.Dispose()
