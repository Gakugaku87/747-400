# Make the custom acf's heading reference labels (5-2 step 5d), side by side
# frames for one panel instrument each (B747.60.hdg_ref_model.lua):
#  - EFIS/Maps/hdg_ref_nd, the ND's: 5 frames of 41 x 25 (the stock
#    label_MAG's 35 x 21 in the middle): MAG; TRU in a white box; TRU in an
#    amber box; TRU (the amber box's flash off; PLAN's TRU); MAG in a white
#    box (FCOM p.1110, p.1142). Letters 9 x 14, 11 apart, as label_MAG's.
#  - CRT Displays/PFD/Heading Track/hdg_ref_pfd, the PFD's: 2 frames of
#    32 x 15 (HdgTrackMagLabel's 28 x 13 in the middle): MAG; TRU in a white
#    box (FCOM p.998). Letters 6 x 10, 7 apart.
# Green letters as the stock labels' (0, 255, 0), the boxes 1.5-pixel lines,
# white or amber (255, 179, 0: the ND's amber, make_nd_excess_image.ps1).
# The letters: Windows' Bahnschrift SemiBold SemiCondensed, bold, cropped
# and scaled to the stock letters' size (estimate: the stock labels' face is
# not known). Nothing needs installing: Windows PowerShell 5.1 and
# System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_hdg_ref_images.ps1
#
# Each image is written as <name>-1.png, shown centred on its POS, and a
# transparent <name>.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$generic = Join-Path $root 'cockpit_3d\generic'
$FACE = 'Bahnschrift SemiBold SemiConden'
function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$dir, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $clear.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height))"
}

# a letter: drawn large in white, its ink cropped and scaled to w x h; the
# red channel is its coverage (as make_nd_excess_image.ps1)
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

# a word's letters into a bitmap in green from x, y, each lw x lh, step apart
function Add-Word([System.Drawing.Bitmap]$b, [string]$text, [int]$x, [int]$y, [int]$lw, [int]$lh, [int]$step) {
    for ($i = 0; $i -lt $text.Length; $i++) {
        $gl = New-Glyph $text.Substring($i, 1) $lw $lh
        for ($yy = 0; $yy -lt $lh; $yy++) {
            for ($xx = 0; $xx -lt $lw; $xx++) {
                $a = $gl.GetPixel($xx, $yy).R
                if ($a -gt 8) { $b.SetPixel($x + $step * $i + $xx, $y + $yy, [System.Drawing.Color]::FromArgb($a, 0, 255, 0)) }
            }
        }
        $gl.Dispose()
    }
}

# a box round a frame
function Add-Box([System.Drawing.Bitmap]$b, [int]$x, [int]$w, [int]$h, [System.Drawing.Color]$c) {
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $pen = New-Object System.Drawing.Pen $c, 1.5
    $g.DrawRectangle($pen, [single]($x + 1), [single]1, [single]($w - 3), [single]($h - 3))
    $g.Dispose(); $pen.Dispose()
}

$WHITE = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)

# the ND's: MAG, TRU white box, TRU amber box, TRU, MAG white box
$FW, $FH = 41, 25
$frames = @(@('MAG', $null), @('TRU', $WHITE), @('TRU', $AMBER), @('TRU', $null), @('MAG', $WHITE))
$b = New-Object System.Drawing.Bitmap ($FW * $frames.Count), $FH
for ($k = 0; $k -lt $frames.Count; $k++) {
    Add-Word $b $frames[$k][0] ($FW * $k + 3 + 2) (2 + 3) 9 14 11
    if ($frames[$k][1]) { Add-Box $b ($FW * $k) $FW $FH $frames[$k][1] }
}
Save-Pair $b (Join-Path $generic 'EFIS\Maps') 'hdg_ref_nd'; $b.Dispose()

# the PFD's: MAG, TRU white box
$FW, $FH = 32, 15
$frames = @(@('MAG', $null), @('TRU', $WHITE))
$b = New-Object System.Drawing.Bitmap ($FW * $frames.Count), $FH
for ($k = 0; $k -lt $frames.Count; $k++) {
    Add-Word $b $frames[$k][0] ($FW * $k + 2 + 2) (1 + 1) 6 10 7
    if ($frames[$k][1]) { Add-Box $b ($FW * $k) $FW $FH $frames[$k][1] }
}
Save-Pair $b (Join-Path $generic 'CRT Displays\PFD\Heading Track') 'hdg_ref_pfd'; $b.Dispose()
