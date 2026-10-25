# Make the custom acf's ND POS switch images (5-2 step 5c), in
# cockpit_3d/generic/CRT Displays/ND:
#  - pos_iru: an IRU position (FCOM p.1150: a white five-armed star, one arm
#    up), 21 x 21, arms 9 pixels, 2-pixel lines;
#  - pos_gps: the GPS position (FCOM p.1150: a white circle with a short line
#    each side ending in an outward fork), 41 x 17, the circle 13 across;
#  - pos_seg: a VOR raw data radial's segment (FCOM p.1145: green), 3 x 24,
#    the panel's segments drawn end to end along the radial;
#  - pos_tick: its tick mark at the DME distance, 17 x 3, across the line.
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_nd_pos_images.ps1
#
# Each image is written as <name>-1.png, shown centred on its POS, and a
# transparent <name>.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$nd = Join-Path $root 'cockpit_3d\generic\CRT Displays\ND'

$WHITE = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$GREEN = [System.Drawing.Color]::FromArgb(255, 0, 255, 0)     # the ND fonts' green (TXT.2.28.green)

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

# the IRU position: five arms from the centre, one up
$b, $g = New-Canvas 21 21
$pen = New-Object System.Drawing.Pen $WHITE, 2
for ($k = 0; $k -lt 5; $k++) {
    $a = [Math]::PI / 2 + $k * 2 * [Math]::PI / 5
    $g.DrawLine($pen, 10.5, 10.5, [float](10.5 + 9 * [Math]::Cos($a)), [float](10.5 - 9 * [Math]::Sin($a)))
}
$g.Dispose(); $pen.Dispose()
Save-Pair $b 'pos_iru'; $b.Dispose()

# the GPS position: the circle, the lines and their forks
$b, $g = New-Canvas 41 17
$pen = New-Object System.Drawing.Pen $WHITE, 2
$g.DrawEllipse($pen, 14, 2, 13, 13)
$g.DrawLine($pen, 6, 8.5, 14, 8.5)
$g.DrawLine($pen, 27, 8.5, 35, 8.5)
$g.DrawLine($pen, 6, 8.5, 2, 3)
$g.DrawLine($pen, 6, 8.5, 2, 14)
$g.DrawLine($pen, 35, 8.5, 39, 3)
$g.DrawLine($pen, 35, 8.5, 39, 14)
$g.Dispose(); $pen.Dispose()
Save-Pair $b 'pos_gps'; $b.Dispose()

# a radial's segment and its tick mark: solid green
foreach ($s in @(@('pos_seg', 3, 24), @('pos_tick', 17, 3))) {
    $b, $g = New-Canvas $s[1] $s[2]
    $brush = New-Object System.Drawing.SolidBrush $GREEN
    $g.FillRectangle($brush, 0, 0, $s[1], $s[2])
    $g.Dispose(); $brush.Dispose()
    Save-Pair $b $s[0]; $b.Dispose()
}
