# Make the custom acf's ND TCAS images (5-1 step 5b; ACF_DIFF.md section 5)
# in cockpit_3d/generic/CRT Displays/ND:
#  - tcas_symbols: 13 frames side by side, 37 x 43 each as nd_icons: 0 none,
#    then other (hollow white diamond), proximate (filled white diamond), TA
#    (filled amber circle), RA (filled red square) (FCOM p.1534), each
#    without, with an up and with a down arrow on its right (traffic climbing
#    or descending at 500 fpm or more). The symbol's centre is the frame's.
#  - tcas_traffic, tcas_offscale: 3 frames each, 0 none, 1 amber, 2 red
#    (TRAFFIC and OFFSCALE, FCOM p.1535);
#  - tcas_taonly (TA ONLY, cyan) and tcas_fail (TCAS FAIL, amber).
# The letters are Windows' Bahnschrift SemiBold SemiCondensed, as
# make_pfd_ra_images.ps1 draws them, 9 x 15 with 2 pixels between them, the
# size of the stock TFC. The colours are the stock ND's: amber and cyan of
# tcasX and TFC, the red of nd_icons. Nothing needs installing: Windows
# PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_nd_tcas_images.ps1
#
# Each image is written as <name>-1.png and a transparent <name>.png of the
# same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\ND'

$WHITE = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)
$RED = [System.Drawing.Color]::FromArgb(255, 236, 28, 36)
$CYAN = [System.Drawing.Color]::FromArgb(255, 0, 189, 255)
$FACE = 'Bahnschrift SemiBold SemiConden'

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $clear.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height))"
}

function New-Graphics([System.Drawing.Bitmap]$b) {
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    return $g
}

# the symbols: frame k at x = 37 k; centre (18.5, 21.5)
$FW = 37; $FH = 43
$sym = New-Object System.Drawing.Bitmap ($FW * 13), $FH
$g = New-Graphics $sym
function Arrow($g, [System.Drawing.Color]$c, [double]$x, [bool]$up) {
    $pen = New-Object System.Drawing.Pen $c, 2
    $g.DrawLine($pen, [single]$x, [single]14, [single]$x, [single]29)
    $pen.Dispose()
    $br = New-Object System.Drawing.SolidBrush $c
    if ($up) { $tip = 11; $base = 17 } else { $tip = 32; $base = 26 }
    $pts = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF ([single]$x), ([single]$tip)),
        (New-Object System.Drawing.PointF ([single]($x - 4)), ([single]$base)),
        (New-Object System.Drawing.PointF ([single]($x + 4)), ([single]$base)))
    $g.FillPolygon($br, $pts)
    $br.Dispose()
}
for ($t = 0; $t -lt 4; $t++) {
    for ($a = 0; $a -lt 3; $a++) {
        $k = 1 + 3 * $t + $a
        $cx = $FW * $k + 18.5; $cy = 21.5
        switch ($t) {
            0 { $c = $WHITE }
            1 { $c = $WHITE }
            2 { $c = $AMBER }
            3 { $c = $RED }
        }
        $br = New-Object System.Drawing.SolidBrush $c
        if ($t -le 1) {
            # the diamond: 8 pixels from the centre to each point
            $r = 8
            $pts = [System.Drawing.PointF[]]@(
                (New-Object System.Drawing.PointF ([single]$cx), ([single]($cy - $r))),
                (New-Object System.Drawing.PointF ([single]($cx + $r)), ([single]$cy)),
                (New-Object System.Drawing.PointF ([single]$cx), ([single]($cy + $r))),
                (New-Object System.Drawing.PointF ([single]($cx - $r)), ([single]$cy)))
            if ($t -eq 0) {
                $pen = New-Object System.Drawing.Pen $c, 2
                $g.DrawPolygon($pen, $pts); $pen.Dispose()
            } else { $g.FillPolygon($br, $pts) }
        } elseif ($t -eq 2) {
            $g.FillEllipse($br, [single]($cx - 7), [single]($cy - 7), [single]14, [single]14)
        } else {
            $g.FillRectangle($br, [single]($cx - 6.5), [single]($cy - 6.5), [single]13, [single]13)
        }
        $br.Dispose()
        if ($a -eq 1) { Arrow $g $c ($cx + 13) $true }
        if ($a -eq 2) { Arrow $g $c ($cx + 13) $false }
    }
}
$g.Dispose()
Save-Pair $sym 'tcas_symbols'
$sym.Dispose()

# a letter: drawn large in white, its ink cropped and scaled to h high and at
# most w wide (a narrow letter such as I keeps its width, centred); the red
# channel is its coverage (as make_pfd_ra_images.ps1)
function New-Glyph([string]$ch, [int]$w, [int]$h) {
    $big = New-Object System.Drawing.Bitmap 400, 400
    $bg = [System.Drawing.Graphics]::FromImage($big)
    $bg.Clear([System.Drawing.Color]::Black)
    $bg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $font = New-Object System.Drawing.Font $FACE, 280, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    if ($font.Name -ne $FACE) { throw "the font $FACE is not installed" }
    $bg.DrawString($ch, $font, [System.Drawing.Brushes]::White, 20, 0)
    $bg.Dispose(); $font.Dispose()
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
    $sw = [Math]::Min($w, [int][Math]::Round($crop.Width * $h / $crop.Height))
    $sg.DrawImage($crop, (New-Object System.Drawing.Rectangle ([int](($w - $sw) / 2)), 0, $sw, $h))
    $sg.Dispose(); $crop.Dispose(); $big.Dispose()
    return $small
}
$glyphs = @{}
function Glyph([string]$ch) {
    if (-not $glyphs.ContainsKey($ch)) { $glyphs[$ch] = New-Glyph $ch 9 15 }
    return $glyphs[$ch]
}
# text in a frame: letters 9 x 15, 2 apart, a space 6 wide, 3 pixels around
$GW = 9; $GH = 15; $GAP = 2; $SP = 6; $PAD = 3
function Text-Width([string]$s) {
    $w = 0
    for ($i = 0; $i -lt $s.Length; $i++) {
        if ($i -gt 0) { $w += $GAP }
        if ($s[$i] -eq ' ') { $w += $SP } else { $w += $GW }
    }
    return $w
}
function Draw-Text([System.Drawing.Bitmap]$b, [string]$s, [int]$x0, [System.Drawing.Color]$c) {
    $x = $x0
    for ($i = 0; $i -lt $s.Length; $i++) {
        if ($i -gt 0) { $x += $GAP }
        if ($s[$i] -eq ' ') { $x += $SP; continue }
        $gl = Glyph $s.Substring($i, 1)
        for ($y = 0; $y -lt $GH; $y++) {
            for ($xx = 0; $xx -lt $GW; $xx++) {
                $a = $gl.GetPixel($xx, $y).R
                if ($a -gt 8) { $b.SetPixel($x + $xx, $PAD + $y, [System.Drawing.Color]::FromArgb($a, $c.R, $c.G, $c.B)) }
            }
        }
        $x += $GW
    }
}
# frames side by side: frame 0 empty, then one per colour
function Save-Message([string]$name, [string]$s, [System.Drawing.Color[]]$colours) {
    $w = (Text-Width $s) + 2 * $PAD
    $h = $GH + 2 * $PAD
    if ($colours.Count -eq 1) {
        $b = New-Object System.Drawing.Bitmap $w, $h
        Draw-Text $b $s $PAD $colours[0]
    } else {
        $b = New-Object System.Drawing.Bitmap ($w * ($colours.Count + 1)), $h
        for ($k = 0; $k -lt $colours.Count; $k++) { Draw-Text $b $s ($w * ($k + 1) + $PAD) $colours[$k] }
    }
    Save-Pair $b $name
    $b.Dispose()
}
Save-Message 'tcas_traffic' 'TRAFFIC' @($AMBER, $RED)
Save-Message 'tcas_offscale' 'OFFSCALE' @($AMBER, $RED)
Save-Message 'tcas_taonly' 'TA ONLY' @($CYAN)
Save-Message 'tcas_fail' 'TCAS FAIL' @($AMBER)
foreach ($k in @($glyphs.Keys)) { $glyphs[$k].Dispose() }
