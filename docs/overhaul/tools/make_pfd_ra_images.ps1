# Make the custom acf's PFD radio altimeter flag (5-1 step 4; ACF_DIFF.md
# section 5) in cockpit_3d/generic/CRT Displays/PFD/Failure Flags: the amber
# RA flag (ATA34_2 p.96: invalid radio altitude), a horizontal box as the
# stock ATT and HDG flags (30 high, a 3-pixel border, letters about 12 x 21
# from y 4). The letters are drawn with Windows' Bahnschrift SemiBold
# SemiCondensed, as make_pfd_airdata_images.ps1 does, scaled to the stock
# letters' size. Nothing needs installing: Windows PowerShell 5.1 and
# System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_pfd_ra_images.ps1
#
# The image is written as raX-1.png, which a gen_rotary shows centred on its
# POS, and a transparent raX.png of the same size, as the stock instruments
# have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$flags = Join-Path $root 'cockpit_3d\generic\CRT Displays\PFD\Failure Flags'

$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)
$FACE = 'Bahnschrift SemiBold SemiConden'

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$dir, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $clear.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height))"
}

# a letter: drawn large in white, its ink cropped and scaled to w x h; the
# red channel is its coverage
function New-Glyph([string]$ch, [int]$w, [int]$h) {
    $big = New-Object System.Drawing.Bitmap 400, 400
    $g = [System.Drawing.Graphics]::FromImage($big)
    $g.Clear([System.Drawing.Color]::Black)
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $font = New-Object System.Drawing.Font $FACE, 280, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
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

# a horizontal flag as the stock ATT: 30 high, a 3-pixel border, the
# letters 12 x 21 from y 4, 2 pixels apart, 13 pixels in from each side
function New-HFlag([string]$text) {
    $n = $text.Length
    $GW = 12; $GH = 21; $GAP = 2; $IN = 13
    $W = 2 * $IN + $n * $GW + ($n - 1) * $GAP
    $H = 30
    $b = New-Object System.Drawing.Bitmap $W, $H
    for ($x = 0; $x -lt $W; $x++) { for ($y = 0; $y -lt 3; $y++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel($x, $H - 1 - $y, $AMBER) } }
    for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt 3; $x++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel($W - 1 - $x, $y, $AMBER) } }
    for ($i = 0; $i -lt $n; $i++) {
        $gl = New-Glyph $text.Substring($i, 1) $GW $GH
        $tx = $IN + $i * ($GW + $GAP)
        for ($y = 0; $y -lt $GH; $y++) {
            for ($x = 0; $x -lt $GW; $x++) {
                $a = $gl.GetPixel($x, $y).R
                if ($a -gt 8) { $b.SetPixel($tx + $x, 4 + $y, [System.Drawing.Color]::FromArgb($a, 255, 179, 0)) }
            }
        }
        $gl.Dispose()
    }
    return $b
}

$b = New-HFlag 'RA'; Save-Pair $b $flags 'raX'; $b.Dispose()
