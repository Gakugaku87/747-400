# Make the upper EICAS gear images of the custom acf (ACF_DIFF.md section 5)
# from the stock art in cockpit_3d/generic/CRT Displays/EICAS Upper:
#  - the expanded gear position indication (FCOM p.1505-1506 (14.10.7-8)):
#    a small box for each gear, DN (green), crosshatched (white), UP (white)
#    and the amber X of a lost indication. The letters and the stripes are
#    cut from the stock DOWN, UP and transit boxes, so they keep their font
#    and colours; the box is 39 x 30 (the FCOM's expanded boxes are a little
#    over half as wide as the DOWN box and as high);
#  - the empty box of the normal display (all position indications lost).
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_gear_images.ps1
#
# Each image is written as <name>-1.png, which a gen_rotary shows centred on
# its POS, and a transparent <name>.png of the same size, as the stock
# instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\EICAS Upper'

$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)

$down = New-Object System.Drawing.Bitmap (Join-Path $dir 'gear_annun_down-1.png')
$up = New-Object System.Drawing.Bitmap (Join-Path $dir 'gear_annun_up-1.png')
$transit = New-Object System.Drawing.Bitmap (Join-Path $dir 'gear_annun_transit-1.png')

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $clear.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height))"
}

# the stock boxes: 79 x 35, a 2-pixel border at 2-3 and 75-76 (x), 2-3 and
# 31-32 (y); the letters 22 pixels high from row 6 (DOWN: D 10-21, N 55-66;
# UP: U 25-36, P 40-52)
$W, $H = 43, 34                   # the small box: border 2-40 x 2-31, inside 4-38 x 4-29
function New-Box([System.Drawing.Color]$border) {
    $b = New-Object System.Drawing.Bitmap $W, $H
    for ($x = 2; $x -le 40; $x++) { foreach ($y in 2, 3, 30, 31) { $b.SetPixel($x, $y, $border) } }
    for ($y = 2; $y -le 31; $y++) { foreach ($x in 2, 3, 39, 40) { $b.SetPixel($x, $y, $border) } }
    return $b
}
function Copy-Block([System.Drawing.Bitmap]$from, [int]$x0, [int]$x1, [int]$y0, [int]$y1, [System.Drawing.Bitmap]$to, [int]$tx, [int]$ty) {
    for ($y = $y0; $y -le $y1; $y++) {
        for ($x = $x0; $x -le $x1; $x++) {
            $c = $from.GetPixel($x, $y)
            if ($c.A -gt 0) { $to.SetPixel($tx + $x - $x0, $ty + $y - $y0, $c) }
        }
    }
}

# DN, green: D and N of DOWN, 27 pixels wide, centred
$b = New-Box ($down.GetPixel(2, 17))
Copy-Block $down 10 21 6 27 $b 8 6
Copy-Block $down 55 66 6 27 $b 23 6
Save-Pair $b 'gear_box_dn'; $b.Dispose()

# UP, white: 28 pixels wide
$b = New-Box ($up.GetPixel(2, 17))
Copy-Block $up 25 36 6 27 $b 7 6
Copy-Block $up 40 52 6 27 $b 22 6
Save-Pair $b 'gear_box_up'; $b.Dispose()

# crosshatched, white: the left part of the stock stripes
$b = New-Box ($transit.GetPixel(2, 17))
Copy-Block $transit 4 38 4 29 $b 4 4
Save-Pair $b 'gear_box_transit'; $b.Dispose()

# X, amber: the box and its diagonals, 2 pixels wide
$b = New-Box $AMBER
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$pen = New-Object System.Drawing.Pen $AMBER, 2
$g.DrawLine($pen, 4.5, 4.5, 38.5, 29.5)
$g.DrawLine($pen, 4.5, 29.5, 38.5, 4.5)
$pen.Dispose(); $g.Dispose()
Save-Pair $b 'gear_box_x'; $b.Dispose()

# the normal display's empty box: the stock UP box without its letters
$b = New-Object System.Drawing.Bitmap $up.Width, $up.Height
$white = $up.GetPixel(2, 17)
for ($x = 2; $x -le 76; $x++) { foreach ($y in 2, 3, 31, 32) { $b.SetPixel($x, $y, $white) } }
for ($y = 2; $y -le 32; $y++) { foreach ($x in 2, 3, 75, 76) { $b.SetPixel($x, $y, $white) } }
Save-Pair $b 'gear_annun_box'; $b.Dispose()

$down.Dispose(); $up.Dispose(); $transit.Dispose()
