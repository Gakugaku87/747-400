# Make the expanded and alternate flap display's images of the custom acf
# (FCTL-12; ACF_DIFF.md section 5) in cockpit_3d/generic/CRT Displays/EICAS
# Upper, from the stock flap art there (FCOM p.937-938; ATA27 p.320-322,
# p.398-400):
#  - flaps_le_box_L, flaps_le_box_R: an LE flap group's box, 7 frames side
#    by side for the left and right wing (the boxes' top and bottom edges
#    rise towards the fuselage, as the leading edge): 0 white outline
#    (retracted), 1 white stripes (in transit), 2 solid green (extended),
#    3-5 the same amber (the drive unit inoperative), 6 white outline with
#    an amber X (no position data);
#  - flaps_tape_amber, flaps_tape_bgnd_amber: the stock TE tape's outline
#    and fill in amber (asymmetry or drive failure in the group), the black
#    cover image as it is;
#  - flaps_tape_frame: the stock tape's white outline alone, and flaps_te_x:
#    the amber X drawn inside it (a TE panel without position data);
#  - flaps_altn_scale_L, flaps_altn_scale_R: the alternate display's flap
#    scale on the outer side of the outboard tapes: ticks at UP, 5, 10, 20,
#    25 and 30 of the stock tape's scale, and 5 and 25 in white, the stock
#    lever numbers' figures.
# The colours are the stock ones: white, green (0, 255, 0: flaps05_green),
# amber (255, 179, 0: gear_box_x). Nothing needs installing: Windows
# PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_flap_images.ps1
#
# Each image is written as <name>-1.png (a gen_tape also <name>-2.png), and a
# transparent <name>.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\EICAS Upper'

$WHITE = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$GREEN = [System.Drawing.Color]::FromArgb(255, 0, 255, 0)
$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)

function Save-Blank([string]$name, [int]$w, [int]$h) {
    $blank = New-Object System.Drawing.Bitmap $w, $h
    $blank.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $blank.Dispose()
}
function Save-Image([System.Drawing.Bitmap]$bmp, [string]$file) {
    $bmp.Save((Join-Path $dir $file), [System.Drawing.Imaging.ImageFormat]::Png)
    "$file ($($bmp.Width)x$($bmp.Height))"
}
# a stock image with its colour replaced, the alpha kept (white: the
# intensity of the brightest channel times the new colour)
function Get-Recoloured([string]$file, [System.Drawing.Color]$c) {
    $src = New-Object System.Drawing.Bitmap (Join-Path $dir $file)
    $bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height
    for ($y = 0; $y -lt $src.Height; $y++) {
        for ($x = 0; $x -lt $src.Width; $x++) {
            $p = $src.GetPixel($x, $y)
            if ($p.A -eq 0) { continue }
            $t = [math]::Max($p.R, [math]::Max($p.G, $p.B)) / 255.0
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($p.A, [int]($c.R * $t), [int]($c.G * $t), [int]($c.B * $t)))
        }
    }
    $src.Dispose()
    return , $bmp
}
function Copy-Stock([string]$from, [string]$to) {
    Copy-Item -Force (Join-Path $dir $from) (Join-Path $dir $to)
    "$to (copy of $from)"
}

# --- LE boxes -----------------------------------------------------------------

$FW, $FH = 17, 16          # a frame
$BW, $BH, $SLANT = 13, 10, 3   # the box: width, its vertical sides, the rise across it
function Get-BoxPoints([int]$x0, [bool]$left) {
    # the left wing's box rises to the right (towards the fuselage)
    $l = $x0 + 2.0; $r = $l + $BW - 1
    $bottomL = 2.0 + $SLANT + $BH - 1; $bottomR = $bottomL - $SLANT
    if (-not $left) { $t = $bottomL; $bottomL = $bottomR; $bottomR = $t }
    return @(
        (New-Object System.Drawing.PointF $l, ($bottomL - $BH + 1)),
        (New-Object System.Drawing.PointF $r, ($bottomR - $BH + 1)),
        (New-Object System.Drawing.PointF $r, $bottomR),
        (New-Object System.Drawing.PointF $l, $bottomL))
}
function New-LeBoxes([bool]$left, [string]$name) {
    $bmp = New-Object System.Drawing.Bitmap ($FW * 7), $FH
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $frames = @(@('outline', $WHITE), @('stripes', $WHITE), @('solid', $GREEN),
        @('outline', $AMBER), @('stripes', $AMBER), @('solid', $AMBER), @('x', $WHITE))
    for ($k = 0; $k -lt 7; $k++) {
        $kind = $frames[$k][0]; $c = $frames[$k][1]
        $pts = Get-BoxPoints ($FW * $k) $left
        $pen = New-Object System.Drawing.Pen $c, 1.6
        $brush = New-Object System.Drawing.SolidBrush $c
        if ($kind -eq 'solid') { $g.FillPolygon($brush, $pts); $g.DrawPolygon($pen, $pts) }
        else { $g.DrawPolygon($pen, $pts) }
        if ($kind -eq 'stripes') {
            # stripes from bottom left to top right, 4 px apart, inside the box
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddPolygon($pts)
            $g.SetClip($path)
            $thin = New-Object System.Drawing.Pen $c, 1.2
            for ($d = -$FH; $d -lt $FW + $FH; $d += 4) {
                $g.DrawLine($thin, ($FW * $k + $d), $FH, ($FW * $k + $d + $FH), 0)
            }
            $g.ResetClip(); $thin.Dispose(); $path.Dispose()
        }
        if ($kind -eq 'x') {
            $xp = New-Object System.Drawing.Pen $AMBER, 1.6
            $cx = ($pts[0].X + $pts[1].X) / 2; $cy = ($pts[0].Y + $pts[3].Y + $pts[1].Y + $pts[2].Y) / 4
            $g.DrawLine($xp, ($cx - 3.5), ($cy - 3.5), ($cx + 3.5), ($cy + 3.5))
            $g.DrawLine($xp, ($cx - 3.5), ($cy + 3.5), ($cx + 3.5), ($cy - 3.5))
            $xp.Dispose()
        }
        $pen.Dispose(); $brush.Dispose()
    }
    $g.Dispose()
    Save-Image $bmp "$name-1.png"
    Save-Blank $name $bmp.Width $bmp.Height
    $bmp.Dispose()
}
New-LeBoxes $true 'flaps_le_box_L'
New-LeBoxes $false 'flaps_le_box_R'

# --- TE tapes -----------------------------------------------------------------

$b = Get-Recoloured 'flaps_tape_bgnd-1.png' $AMBER; Save-Image $b 'flaps_tape_bgnd_amber-1.png'; $b.Dispose()
Copy-Stock 'flaps_tape_bgnd.png' 'flaps_tape_bgnd_amber.png'
Copy-Stock 'flaps_tape-1.png' 'flaps_tape_amber-1.png'
$b = Get-Recoloured 'flaps_tape-2.png' $AMBER; Save-Image $b 'flaps_tape_amber-2.png'; $b.Dispose()
Copy-Stock 'flaps_tape.png' 'flaps_tape_amber.png'
# the outline alone (the gen_tape's frame) for a gen_rotary
Copy-Stock 'flaps_tape-2.png' 'flaps_tape_frame-1.png'
$s = New-Object System.Drawing.Bitmap (Join-Path $dir 'flaps_tape-2.png'); Save-Blank 'flaps_tape_frame' $s.Width $s.Height; $s.Dispose()
# the amber X: two strokes 2 px wide, 11 x 15, inside the 17 px tape
$b = New-Object System.Drawing.Bitmap 15, 19
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$pen = New-Object System.Drawing.Pen $AMBER, 2.0
$g.DrawLine($pen, 2, 2, 12, 16); $g.DrawLine($pen, 2, 16, 12, 2)
$pen.Dispose(); $g.Dispose()
Save-Image $b 'flaps_te_x-1.png'; Save-Blank 'flaps_te_x' $b.Width $b.Height; $b.Dispose()

# --- the alternate display's flap scale ---------------------------------------

# the stock tape's scale (the gen_tape's key frames): UP 68, 1 63, 5 46,
# 10 24, 20 -22, 25 -44, 30 -68 pixels from its centre, up
$TICKS = @(68, 46, 24, -22, -44, -68)
$SW, $SH, $CY = 40, 140, 70      # the image; its row 70 is the tape's centre
$TICK = 6
# a stock figure's pixels (its bounding box), in white
function Get-Figure([string]$file) {
    $src = New-Object System.Drawing.Bitmap (Join-Path $dir $file)
    $x0 = $src.Width; $x1 = -1; $y0 = $src.Height; $y1 = -1
    for ($y = 0; $y -lt $src.Height; $y++) { for ($x = 0; $x -lt $src.Width; $x++) {
        if ($src.GetPixel($x, $y).A -gt 0) { if ($x -lt $x0) { $x0 = $x }; if ($x -gt $x1) { $x1 = $x }; if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y } } } }
    $fig = @{ w = $x1 - $x0 + 1; h = $y1 - $y0 + 1; px = @() }
    for ($y = $y0; $y -le $y1; $y++) { for ($x = $x0; $x -le $x1; $x++) {
        $p = $src.GetPixel($x, $y)
        if ($p.A -gt 0) { $t = [math]::Max($p.R, [math]::Max($p.G, $p.B)) / 255.0; $fig.px += , @(($x - $x0), ($y - $y0), $p.A, $t) } } }
    $src.Dispose()
    return $fig
}
$FIVE = Get-Figure 'flaps05_green-1.png'
$TWENTYFIVE = Get-Figure 'flaps25_green-1.png'
function New-Scale([bool]$left, [string]$name) {
    $bmp = New-Object System.Drawing.Bitmap $SW, $SH
    foreach ($o in $TICKS) {
        $row = $CY - $o
        for ($dy = -1; $dy -le 0; $dy++) {
            for ($i = 0; $i -lt $TICK; $i++) {
                $x = if ($left) { $SW - $TICK + $i } else { $i }
                $bmp.SetPixel($x, $row + $dy, $WHITE)
            }
        }
    }
    foreach ($lab in @(@($FIVE, 46), @($TWENTYFIVE, -44))) {
        $fig = $lab[0]; $row = $CY - $lab[1]
        $fx = if ($left) { $SW - $TICK - 3 - $fig.w } else { $TICK + 3 }
        $fy = $row - [math]::Floor($fig.h / 2)
        foreach ($p in $fig.px) {
            $v = [int](255 * $p[3])
            $bmp.SetPixel($fx + $p[0], $fy + $p[1], [System.Drawing.Color]::FromArgb($p[2], $v, $v, $v))
        }
    }
    Save-Image $bmp "$name-1.png"
    Save-Blank $name $SW $SH
    $bmp.Dispose()
}
New-Scale $true 'flaps_altn_scale_L'
New-Scale $false 'flaps_altn_scale_R'
