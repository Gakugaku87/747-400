# Make the custom acf's PFD flight path vector images (5-2 step 4d), in
# cockpit_3d/generic/CRT Displays/PFD:
#  - Artificial Horizon/HrznFPVbody and HrznFPVfeet: the CRT's flight path
#    vector (FCOM p.979 (10.10.17), 109 and 405; p.980: "Arms are parallel
#    to the horizon line and feet are parallel to the airplane symbol"): a
#    circle with an arm each side (the body, which turns with the bank) and
#    two feet slanting down and out from the circle's bottom, then level
#    (they stay level with the airplane symbol). White, as the airplane
#    symbol's outline. Sizes in the proportions of the FCOM's figure: the
#    circle 12 across, an arm 12, a foot 8 down and out then 8 level;
#  - Failure Flags/fpvX: the FPV flag (FCOM p.999 (10.10.37)), boxed like
#    the stock ATT flag (70 x 30, a 3-pixel border), its letters drawn with
#    Windows' Bahnschrift SemiBold SemiCondensed at the stock letters' size
#    (13 x 23), as make_pfd_airdata_images.ps1 does.
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_pfd_fpv_images.ps1
#
# Each image is written as <name>-1.png, shown centred on its POS, and a
# transparent <name>.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$pfd = Join-Path $root 'cockpit_3d\generic\CRT Displays\PFD'
$hrzn = Join-Path $pfd 'Artificial Horizon'
$flags = Join-Path $pfd 'Failure Flags'

$WHITE = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)
$FACE = 'Bahnschrift SemiBold SemiConden'

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$dir, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $clear.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height))"
}

# both FPV images 64 x 64 with the circle's centre at their middle (32, 32)
$S, $C, $R = 64, 32, 6
$b = New-Object System.Drawing.Bitmap $S, $S
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$pen = New-Object System.Drawing.Pen $WHITE, 2
$g.DrawEllipse($pen, $C - $R, $C - $R, 2 * $R, 2 * $R)
$g.DrawLine($pen, $C - $R - 12, $C, $C - $R, $C)
$g.DrawLine($pen, $C + $R, $C, $C + $R + 12, $C)
$pen.Dispose(); $g.Dispose()
Save-Pair $b $hrzn 'HrznFPVbody'; $b.Dispose()

$b = New-Object System.Drawing.Bitmap $S, $S
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$pen = New-Object System.Drawing.Pen $WHITE, 2
foreach ($side in @(-1, 1)) {
    # from the circle's lower side, 8 down and out, then 8 level outwards
    $x0 = $C + $side * 4; $y0 = $C + 5
    $x1 = $x0 + $side * 8; $y1 = $y0 + 8
    $g.DrawLine($pen, $x0, $y0, $x1, $y1)
    $g.DrawLine($pen, $x1, $y1, $x1 + $side * 8, $y1)
}
$pen.Dispose(); $g.Dispose()
Save-Pair $b $hrzn 'HrznFPVfeet'; $b.Dispose()

# a letter: drawn large in white, its ink cropped and scaled to w x h; the
# red channel is its coverage (as make_pfd_airdata_images.ps1)
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

# the FPV flag: 70 x 30, a 3-pixel border, three letters 12 x 21 from y 4,
# side by side and centred, bold (the stock ATT's letters: x 16-52, y 4-24,
# strokes 4 pixels)
$FW, $FH = 70, 30
$b = New-Object System.Drawing.Bitmap $FW, $FH
for ($x = 0; $x -lt $FW; $x++) { for ($y = 0; $y -lt 3; $y++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel($x, $FH - 1 - $y, $AMBER) } }
for ($y = 0; $y -lt $FH; $y++) { for ($x = 0; $x -lt 3; $x++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel($FW - 1 - $x, $y, $AMBER) } }
$text = 'FPV'
$x0 = [int](($FW - 3 * 12) / 2)
for ($i = 0; $i -lt 3; $i++) {
    $gl = New-Glyph $text.Substring($i, 1) 12 21
    for ($y = 0; $y -lt 21; $y++) {
        for ($x = 0; $x -lt 12; $x++) {
            $a = $gl.GetPixel($x, $y).R
            if ($a -gt 8) { $b.SetPixel($x0 + $i * 12 + $x, 4 + $y, [System.Drawing.Color]::FromArgb($a, 255, 179, 0)) }
        }
    }
    $gl.Dispose()
}
Save-Pair $b $flags 'fpvX'; $b.Dispose()
