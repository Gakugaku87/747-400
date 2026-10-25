# Make the custom acf's PFD ILS images (5-2 step 4e), in
# cockpit_3d/generic/CRT Displays/PFD:
#  - Artificial Horizon/HrznGSscaleAmb, HrznLOCscaleAmb and HrznLOCscaleExAmb:
#    the stock glideslope, localizer and expanded localizer scales in amber,
#    for the deviation warnings (ATA34_1 p.468: "the scale to turn yellow";
#    FCOM p.987: amber), each pixel's brightness and coverage kept;
#  - Failure Flags/gsX: the G/S flag (FCOM p.999 (10.10.37), ATA31 p.13),
#    boxed and upright like the stock ALT flag (30 x 96, a 3-pixel border,
#    letters 13 x 23 at x 8 and y 8, 37, 66 as the stock A, L, T);
#  - Failure Flags/locX: the LOC flag, boxed like the stock ATT flag (70 x 30,
#    three letters 12 x 21 from y 4, as make_pfd_fpv_images.ps1's FPV flag).
# The letters: Windows' Bahnschrift SemiBold SemiCondensed, bold (the FPV
# flag's). Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_pfd_ils_images.ps1
#
# Each image is written as <name>-1.png, shown centred on its POS, and a
# transparent <name>.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$pfd = Join-Path $root 'cockpit_3d\generic\CRT Displays\PFD'
$hrzn = Join-Path $pfd 'Artificial Horizon'
$flags = Join-Path $pfd 'Failure Flags'

$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)
$FACE = 'Bahnschrift SemiBold SemiConden'

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$dir, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $clear.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height))"
}

# the amber scales: white (240-255) becomes amber at the same brightness
foreach ($n in @('HrznGSscale', 'HrznLOCscale', 'HrznLOCscaleEx')) {
    $src = [System.Drawing.Bitmap]::FromFile((Join-Path $hrzn "$n-1.png"))
    $b = New-Object System.Drawing.Bitmap $src.Width, $src.Height
    for ($y = 0; $y -lt $src.Height; $y++) {
        for ($x = 0; $x -lt $src.Width; $x++) {
            $p = $src.GetPixel($x, $y)
            if ($p.A -gt 0) {
                $l = [Math]::Max($p.R, [Math]::Max($p.G, $p.B)) / 255.0
                $b.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($p.A, [int](255 * $l), [int](179 * $l), 0))
            }
        }
    }
    $src.Dispose()
    Save-Pair $b $hrzn "${n}Amb"; $b.Dispose()
}

# a letter: drawn large in white, its ink cropped and scaled to w x h; the
# red channel is its coverage (as make_pfd_fpv_images.ps1)
function New-Glyph([string]$ch, [int]$w, [int]$h) {
    $big = New-Object System.Drawing.Bitmap 400, 400
    $g = [System.Drawing.Graphics]::FromImage($big)
    $g.Clear([System.Drawing.Color]::Black)
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $font = New-Object System.Drawing.Font $FACE, 280, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    if ($font.Name -ne $FACE) { throw "the font $FACE is not installed" }
    $g.DrawString($ch, $font, [System.Drawing.Brushes]::White, 20, 0)
    $g.Dispose(); $font.Dispose()
    $x0 = 400; $x1 = -1; $y0 = 400; $y1 = -1
    for ($y = 0; $y -lt 400; $y++) {
        for ($x = 0; $x -lt 400; $x++) {
            if ($big.GetPixel($x, $y).R -gt 100) {
                if ($x -lt $x0) { $x0 = $x }; if ($x -gt $x1) { $x1 = $x }
                if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y }
            }
        }
    }
    $crop = $big.Clone((New-Object System.Drawing.Rectangle $x0, $y0, ($x1 - $x0 + 1), ($y1 - $y0 + 1)), $big.PixelFormat)
    $small = New-Object System.Drawing.Bitmap $w, $h
    $sg = [System.Drawing.Graphics]::FromImage($small)
    $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $sg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $sg.DrawImage($crop, (New-Object System.Drawing.Rectangle 0, 0, $w, $h))
    $sg.Dispose(); $crop.Dispose(); $big.Dispose()
    return $small
}

# a boxed flag: w x h, a 3-pixel amber border, the letters at their places
function New-Flag([int]$w, [int]$h, [string]$text, [int]$lw, [int]$lh, $places) {
    $b = New-Object System.Drawing.Bitmap $w, $h
    for ($x = 0; $x -lt $w; $x++) { for ($y = 0; $y -lt 3; $y++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel($x, $h - 1 - $y, $AMBER) } }
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt 3; $x++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel($w - 1 - $x, $y, $AMBER) } }
    for ($i = 0; $i -lt $text.Length; $i++) {
        $gl = New-Glyph $text.Substring($i, 1) $lw $lh
        $px, $py = $places[$i]
        for ($y = 0; $y -lt $lh; $y++) {
            for ($x = 0; $x -lt $lw; $x++) {
                $a = $gl.GetPixel($x, $y).R
                if ($a -gt 8) { $b.SetPixel($px + $x, $py + $y, [System.Drawing.Color]::FromArgb($a, 255, 179, 0)) }
            }
        }
        $gl.Dispose()
    }
    return $b
}

$b = New-Flag 30 96 'G/S' 13 23 @(@(8, 8), @(8, 37), @(8, 66))
Save-Pair $b $flags 'gsX'; $b.Dispose()
$x0 = [int]((70 - 3 * 12) / 2)
$b = New-Flag 70 30 'LOC' 12 21 @(@($x0, 4), @(($x0 + 12), 4), @(($x0 + 24), 4))
Save-Pair $b $flags 'locX'; $b.Dispose()
