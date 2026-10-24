# Make the custom acf's PFD air data images (5-1 step 1b; ACF_DIFF.md
# section 5) in cockpit_3d/generic/CRT Displays/PFD:
#  - the amber SPD and ALT flags (FCOM p.1000 (10.10.38)): boxed letters
#    down the speed and altitude tapes, the size and spacing of the stock
#    VERT flag (30 wide, a 3-pixel border, letters 13 x 23 every 29 pixels).
#    The stock flags have no S, P or L at that size, so the letters are drawn
#    with Windows' Bahnschrift SemiBold SemiCondensed (a DIN face, close to
#    the stock letters) and scaled to the stock letters' size;
#  - the altitude alert's highlighted boxes (FCOM p.992 (10.10.30)): the
#    current altitude window's outline (the stock window's 3-pixel border)
#    widened by 3 pixels outwards, in white and in amber, and a white box
#    round the selected altitude.
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_pfd_airdata_images.ps1
#
# Each image is written as <name>-1.png, which a gen_rotary shows centred on
# its POS, and a transparent <name>.png of the same size, as the stock
# instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$pfd = Join-Path $root 'cockpit_3d\generic\CRT Displays\PFD'
$flags = Join-Path $pfd 'Failure Flags'
$alt = Join-Path $pfd 'Altimeter'

$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)
$WHITE = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
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

# a vertical flag as the stock VERT: 30 wide, a 3-pixel border, the letters
# 13 x 23 from x 8 and y 8, every 29 pixels, 4 pixels below the last
function New-Flag([string]$text) {
    $n = $text.Length
    $H = 3 + 5 + $n * 23 + ($n - 1) * 6 + 4 + 3
    $b = New-Object System.Drawing.Bitmap 30, $H
    for ($x = 0; $x -lt 30; $x++) { for ($y = 0; $y -lt 3; $y++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel($x, $H - 1 - $y, $AMBER) } }
    for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt 3; $x++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel(29 - $x, $y, $AMBER) } }
    for ($i = 0; $i -lt $n; $i++) {
        $gl = New-Glyph $text.Substring($i, 1) 13 23
        $ty = 8 + $i * 29
        for ($y = 0; $y -lt 23; $y++) {
            for ($x = 0; $x -lt 13; $x++) {
                $a = $gl.GetPixel($x, $y).R
                if ($a -gt 8) { $b.SetPixel(8 + $x, $ty + $y, [System.Drawing.Color]::FromArgb($a, 255, 179, 0)) }
            }
        }
        $gl.Dispose()
    }
    return $b
}

$b = New-Flag 'SPD'; Save-Pair $b $flags 'spdX'; $b.Dispose()
$b = New-Flag 'ALT'; Save-Pair $b $flags 'altX'; $b.Dispose()

# the current altitude window's highlight: the stock window (117 x 74, a
# white 3-pixel border with the pointer at the left) with its border and a
# 3-pixel band outside it in one colour, the inside clear; 3 pixels larger
# on each side, so it is centred on the window's POS too
$win = New-Object System.Drawing.Bitmap (Join-Path $alt 'ALTrollingDigits\ALTcrntWndw-1.png')
$M = 3
$W = $win.Width + 2 * $M; $H = $win.Height + 2 * $M
$inside = New-Object 'bool[,]' $W, $H
$border = New-Object 'bool[,]' $W, $H
for ($y = 0; $y -lt $win.Height; $y++) {
    for ($x = 0; $x -lt $win.Width; $x++) {
        $c = $win.GetPixel($x, $y)
        if ($c.A -ge 30) {
            $inside[($x + $M), ($y + $M)] = $true
            if ($c.R -gt 60) { $border[($x + $M), ($y + $M)] = $true }
        }
    }
}
$win.Dispose()
# the band: within 3 pixels (8-neighbour steps) of the window, outside it
$grown = $inside.Clone()
for ($step = 0; $step -lt $M; $step++) {
    $next = $grown.Clone()
    for ($y = 0; $y -lt $H; $y++) {
        for ($x = 0; $x -lt $W; $x++) {
            if (-not $grown[$x, $y]) { continue }
            for ($dy = -1; $dy -le 1; $dy++) {
                for ($dx = -1; $dx -le 1; $dx++) {
                    $nx = $x + $dx; $ny = $y + $dy
                    if ($nx -ge 0 -and $nx -lt $W -and $ny -ge 0 -and $ny -lt $H) { $next[$nx, $ny] = $true }
                }
            }
        }
    }
    $grown = $next
}
foreach ($pair in @(@('ALTcrntWndwHiW', $WHITE), @('ALTcrntWndwHiA', $AMBER))) {
    $b = New-Object System.Drawing.Bitmap $W, $H
    for ($y = 0; $y -lt $H; $y++) {
        for ($x = 0; $x -lt $W; $x++) {
            if ($border[$x, $y] -or ($grown[$x, $y] -and -not $inside[$x, $y])) { $b.SetPixel($x, $y, $pair[1]) }
        }
    }
    Save-Pair $b (Join-Path $alt 'ALTrollingDigits') $pair[0]; $b.Dispose()
}

# the selected altitude's highlight: a white 3-pixel box, the width of the
# altitude tape (87) and a little over the digits' height
$SW, $SH = 93, 38
$b = New-Object System.Drawing.Bitmap $SW, $SH
for ($x = 0; $x -lt $SW; $x++) { for ($y = 0; $y -lt 3; $y++) { $b.SetPixel($x, $y, $WHITE); $b.SetPixel($x, $SH - 1 - $y, $WHITE) } }
for ($y = 0; $y -lt $SH; $y++) { for ($x = 0; $x -lt 3; $x++) { $b.SetPixel($x, $y, $WHITE); $b.SetPixel($SW - 1 - $x, $y, $WHITE) } }
Save-Pair $b $alt 'SelAltBoxHiW'; $b.Dispose()
