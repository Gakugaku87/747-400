# Make the custom acf's ND origin and destination airport images (5-2 step
# 5c, FCOM p.1149: white), in cockpit_3d/generic/CRT Displays/ND:
#  - apt_w: the airport symbol, a circle as the ARPT one (nd_icons frame 2:
#    12 pixels across the middle of a 3-pixel line), 29 x 29;
#  - apt_line: the line along the selected runway from the symbol (80 NM
#    and more), 2 x 30;
#  - rwy_dash: a dash of the runway's centrelines (10 to 40 NM), 2 x 12;
#  - rwy_outline: the runway to scale, its two sides 8 pixels apart, 40
#    frames side by side (the panel's DIGITS 40) of 16 x 164, frame i the
#    runway 4 (i + 1) pixels long (B747.61.nd_data.lua's rwy_frame).
# The sizes are estimates (FCOM's figure). Nothing needs installing: Windows
# PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_nd_apt_images.ps1
#
# Each image is written as <name>-1.png, shown centred on its POS, and a
# transparent <name>.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$nd = Join-Path $root 'cockpit_3d\generic\CRT Displays\ND'

$WHITE = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$name) {
    $bmp.Save((Join-Path $nd "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $clear.Save((Join-Path $nd "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height))"
}

function New-Canvas([int]$w, [int]$h) {
    $b = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    return @($b, $g)
}

# the airport symbol
$b, $g = New-Canvas 29 29
$pen = New-Object System.Drawing.Pen $WHITE, 2.5
$g.DrawEllipse($pen, 2.5, 2.5, 24, 24)
$g.Dispose(); $pen.Dispose()
Save-Pair $b 'apt_w'; $b.Dispose()

# the runway line and a centreline's dash: solid white
foreach ($s in @(@('apt_line', 2, 30), @('rwy_dash', 2, 12))) {
    $b, $g = New-Canvas $s[1] $s[2]
    $brush = New-Object System.Drawing.SolidBrush $WHITE
    $g.FillRectangle($brush, 0, 0, $s[1], $s[2])
    $g.Dispose(); $brush.Dispose()
    Save-Pair $b $s[0]; $b.Dispose()
}

# the runway outline's frames
$FRAMES = 40; $FW = 16; $FH = 164
$b, $g = New-Canvas ($FRAMES * $FW) $FH
$brush = New-Object System.Drawing.SolidBrush $WHITE
for ($i = 0; $i -lt $FRAMES; $i++) {
    $len = 4 * ($i + 1)
    $top = [int]($FH / 2 - $len / 2)
    $g.FillRectangle($brush, $i * $FW + 3, $top, 2, $len)
    $g.FillRectangle($brush, $i * $FW + 11, $top, 2, $len)
}
$g.Dispose(); $brush.Dispose()
Save-Pair $b 'rwy_outline'; $b.Dispose()
