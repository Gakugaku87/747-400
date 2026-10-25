# Make the custom acf's ND EXCESS DATA message (5-2 step 5c), in
# cockpit_3d/generic/CRT Displays/ND/excess_data: FCOM p.1030-1031, p.1111
# (more map information than the display can show), in amber (estimate:
# the sources' figure is grey; the ND's failure messages, WXR FAIL), letters
# 12 x 19 spaced 14 from x 4, y 3 (the ND flags' letters: make_nd_vor_images.ps1).
# The letters: Windows' Bahnschrift SemiBold SemiCondensed, bold. Nothing
# needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_nd_excess_image.ps1
#
# The image is written as excess_data-1.png, shown centred on its POS, and a
# transparent excess_data.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$nd = Join-Path $root 'cockpit_3d\generic\CRT Displays\ND'
$FACE = 'Bahnschrift SemiBold SemiConden'
function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$dir, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $clear.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height))"
}

# a letter: drawn large in white, its ink cropped and scaled to w x h; the
# red channel is its coverage (as make_pfd_ils_images.ps1)
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

# letters into a bitmap in a colour at their places
function Add-Letters([System.Drawing.Bitmap]$b, [string]$text, [int]$lw, [int]$lh, $places, [int]$r, [int]$gr, [int]$bl) {
    for ($i = 0; $i -lt $text.Length; $i++) {
        $gl = New-Glyph $text.Substring($i, 1) $lw $lh
        $px, $py = $places[$i]
        for ($y = 0; $y -lt $lh; $y++) {
            for ($x = 0; $x -lt $lw; $x++) {
                $a = $gl.GetPixel($x, $y).R
                if ($a -gt 8) { $b.SetPixel($px + $x, $py + $y, [System.Drawing.Color]::FromArgb($a, $r, $gr, $bl)) }
            }
        }
        $gl.Dispose()
    }
}

$text = 'EXCESS DATA'
$b = New-Object System.Drawing.Bitmap (8 + 14 * $text.Length - 2), 25
$places = @()
for ($i = 0; $i -lt $text.Length; $i++) { $places += , @((4 + 14 * $i), 3) }
$letters = $text.Replace(' ', '')
$pl = @()
for ($i = 0; $i -lt $text.Length; $i++) { if ($text[$i] -ne ' ') { $pl += , $places[$i] } }
Add-Letters $b $letters 12 19 $pl 255 179 0
Save-Pair $b $nd 'excess_data'; $b.Dispose()
