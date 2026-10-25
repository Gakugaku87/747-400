# Make the custom acf's ND VOR mode images (5-2 step 5b), in
# cockpit_3d/generic:
#  - CRT Displays/ND/vorLX and vorRX: the VOR flags (FCOM p.1034 (10.10.72):
#    "VORL", "VORR"), boxed like the PFD's LOC flag (70 x 30, a 3-pixel amber
#    border, four letters 12 x 21 from y 4: make_pfd_ils_images.ps1);
#  - CRT Displays/ND/Ref Rcvr/to_lbl and from_lbl: the TO/FROM indication's
#    words (FCOM p.1145, white), letters 6 x 11 spaced 7 like the stock CRS
#    label (crs_bkgnd: its ink 20 x 11 from x 4, y 3);
#  - EFIS/Maps/Centered/to_from_ptr: the VOR CTR TO/FROM pointer (FCOM
#    p.1144: an open triangle near the airplane symbol), 20 x 16 with a
#    2-pixel white outline, its centre 65 pixels above the image's centre
#    (FCOM p.1024's figure: about a tenth of the display's width ahead of the
#    airplane symbol), so that a needle turning about the rose centre puts
#    it on the course line.
# The letters: Windows' Bahnschrift SemiBold SemiCondensed, bold. Nothing
# needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_nd_vor_images.ps1
#
# Each image is written as <name>-1.png, shown centred on its POS, and a
# transparent <name>.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$generic = Join-Path $root 'cockpit_3d\generic'
$nd = Join-Path $generic 'CRT Displays\ND'
$rcvr = Join-Path $nd 'Ref Rcvr'
$centered = Join-Path $generic 'EFIS\Maps\Centered'

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

# the VOR flags: boxed, four letters
foreach ($f in @(@('vorLX', 'VORL'), @('vorRX', 'VORR'))) {
    $b = New-Object System.Drawing.Bitmap 70, 30
    for ($x = 0; $x -lt 70; $x++) { for ($y = 0; $y -lt 3; $y++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel($x, 29 - $y, $AMBER) } }
    for ($y = 0; $y -lt 30; $y++) { for ($x = 0; $x -lt 3; $x++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel(69 - $x, $y, $AMBER) } }
    $x0 = [int]((70 - 4 * 12) / 2)
    Add-Letters $b $f[1] 12 21 @(@($x0, 4), @(($x0 + 12), 4), @(($x0 + 24), 4), @(($x0 + 36), 4)) 255 179 0
    Save-Pair $b $nd $f[0]; $b.Dispose()
}

# TO and FROM in white, letters 6 x 11 spaced 7, from x 4 and y 3
foreach ($w in @(@('to_lbl', 'TO'), @('from_lbl', 'FROM'))) {
    $n = $w[1].Length
    $b = New-Object System.Drawing.Bitmap (8 + 7 * $n - 1), 17
    $places = @()
    for ($i = 0; $i -lt $n; $i++) { $places += , @((4 + 7 * $i), 3) }
    Add-Letters $b $w[1] 6 11 $places 255 255 255
    Save-Pair $b $rcvr $w[0]; $b.Dispose()
}

# the TO/FROM pointer: an open triangle, apex up, centred 65 px above the
# image's centre (24 x 170: the centre at y 85, the triangle from y 12 to 27)
$b = New-Object System.Drawing.Bitmap 24, 170
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 2
$pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Miter
$pts = @((New-Object System.Drawing.PointF 12, 12), (New-Object System.Drawing.PointF 21, 27), (New-Object System.Drawing.PointF 3, 27))
$g.DrawPolygon($pen, [System.Drawing.PointF[]]$pts)
$pen.Dispose(); $g.Dispose()
Save-Pair $b $centered 'to_from_ptr'; $b.Dispose()
