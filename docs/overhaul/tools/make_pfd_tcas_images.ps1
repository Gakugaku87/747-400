# Make the custom acf's PFD TCAS RA images (5-1 step 5d; ACF_DIFF.md
# section 5), the 570 PFD's vertical guidance (FCOM p.1536-1537):
#  - CRT Displays/PFD/Artificial Horizon/tcas_ra_up, tcas_ra_down: the red
#    outlined RA pitch regions above and below the airplane symbol, drawn as
#    on FCOM p.1536 and scaled to the stock pitch scale (10 deg = 68 px:
#    6.811 px/deg, the horizon's DEFLECT_PIX 613 per 90 deg). The region's
#    edge at the airplane symbol's centre (the notch's top above, the point
#    below) is the image's centre. Above: the bottom corners 31.5 px out and
#    11.9 px below the edge, the sides opening upwards 0.281 px per px;
#    below: the corners 31.2 px out and 22.1 px below the point, the sides
#    opening downwards 0.363 px per px. 3-px red lines. Each reaches 470 px
#    from its edge: the pointer moves it at most 232 px (34 deg) and clips it
#    to 464 x 464 round the attitude display's centre (the base image).
#  - CRT Displays/PFD/VSI/tcas_ra_vs_up, tcas_ra_vs_down: the red RA
#    vertical speed regions, 7 px wide (the scale's tick column): red above
#    (below) the image's centre, 294 px long; the base image (7 x 294, the
#    scale from -6,000 to +6,000 fpm) clips them.
#  - CRT Displays/PFD/VSI/VSIspdPtrR: the stock vertical speed pointer
#    (VSIspdPtr) in red, for "present vertical speed does not ensure traffic
#    is avoided" (FCOM p.1537).
# The red is the stock PFD warnings' (pull_up, windshear: 255, 0, 0).
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_pfd_tcas_images.ps1
#
# Each image is written as <name>-1.png, which the instrument moves, and a
# transparent <name>.png, whose size is the instrument's clip rectangle
# round its POS (as the stock HrznGSpointer and VSIspdPtr have).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$horizon = Join-Path $root 'cockpit_3d\generic\CRT Displays\PFD\Artificial Horizon'
$vsi = Join-Path $root 'cockpit_3d\generic\CRT Displays\PFD\VSI'

$RED = [System.Drawing.Color]::FromArgb(255, 255, 0, 0)

function Save-Pointer([System.Drawing.Bitmap]$bmp, [string]$dir, [string]$name, [int]$cw, [int]$ch) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clip = New-Object System.Drawing.Bitmap $cw, $ch
    $clip.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clip.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height), clip $cw x $ch)"
}

function New-Graphics([System.Drawing.Bitmap]$b, [bool]$smooth) {
    $g = [System.Drawing.Graphics]::FromImage($b)
    if ($smooth) {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    }
    return $g
}

function P([double]$x, [double]$y) { return New-Object System.Drawing.PointF ([single]$x), ([single]$y) }

# the pitch regions: the outline as a polyline from beyond one image edge,
# round the corners and the edge's point, to beyond the same edge
$REACH = 470                        # px from the edge to the image's far end
$CLIP = 464
function Region([string]$name, [bool]$up, [double]$cornerX, [double]$cornerDy, [double]$slope) {
    $far = $REACH + 8
    $half = $cornerX + $slope * ($far + $cornerDy) + 4
    $w = 2 * [int][math]::Ceiling($half)
    $h = 2 * $REACH
    $cx = $w / 2; $cy = $h / 2
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = New-Graphics $bmp $true
    $pen = New-Object System.Drawing.Pen $RED, 3
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Miter
    if ($up) {
        # the corners below the edge, the sides going up to beyond the top
        $yc = $cy + $cornerDy; $ye = -8
    } else {
        # the corners below the point, the sides going down to beyond the bottom
        $yc = $cy + $cornerDy; $ye = $h + 8
    }
    $spread = $cornerX + $slope * [math]::Abs($ye - $yc)
    $pts = [System.Drawing.PointF[]]@(
        (P ($cx - $spread) $ye), (P ($cx - $cornerX) $yc), (P $cx $cy),
        (P ($cx + $cornerX) $yc), (P ($cx + $spread) $ye))
    $g.DrawLines($pen, $pts)
    $pen.Dispose(); $g.Dispose()
    Save-Pointer $bmp $horizon $name $CLIP $CLIP
    $bmp.Dispose()
}
Region 'tcas_ra_up' $true 31.5 11.9 0.281
Region 'tcas_ra_down' $false 31.2 22.1 0.363

# the vertical speed regions: 7 x 588, red in the upper or lower half
$BW = 7; $BH = 294
foreach ($side in @('up', 'down')) {
    $bmp = New-Object System.Drawing.Bitmap $BW, (2 * $BH)
    $y0 = if ($side -eq 'up') { 0 } else { $BH }
    for ($y = $y0; $y -lt $y0 + $BH; $y++) { for ($x = 0; $x -lt $BW; $x++) { $bmp.SetPixel($x, $y, $RED) } }
    Save-Pointer $bmp $vsi "tcas_ra_vs_$side" $BW $BH
    $bmp.Dispose()
}

# the red vertical speed pointer: the stock one's opaque pixels in red
$src = New-Object System.Drawing.Bitmap (Join-Path $vsi 'VSIspdPtr-1.png')
$clipSrc = New-Object System.Drawing.Bitmap (Join-Path $vsi 'VSIspdPtr.png')
$bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height
for ($y = 0; $y -lt $src.Height; $y++) {
    for ($x = 0; $x -lt $src.Width; $x++) {
        $a = $src.GetPixel($x, $y).A
        if ($a -gt 0) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, 255, 0, 0)) }
    }
}
Save-Pointer $bmp $vsi 'VSIspdPtrR' $clipSrc.Width $clipSrc.Height
$src.Dispose(); $clipSrc.Dispose(); $bmp.Dispose()
