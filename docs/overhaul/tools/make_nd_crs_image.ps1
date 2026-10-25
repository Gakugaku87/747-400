# Make the custom acf's ND course line image (5-2 step 5c, FCOM p.1145: a
# manually tuned VOR's course and reciprocal), in
# cockpit_3d/generic/CRT Displays/ND:
#  - crs_dash: a dash of the course line, 2 x 12, in the ND fonts' green
#    (estimate: the tuned navaid's colour; the runway centrelines' dash).
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_nd_crs_image.ps1
#
# The image is written as crs_dash-1.png, shown centred on its POS, and a
# transparent crs_dash.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$nd = Join-Path $root 'cockpit_3d\generic\CRT Displays\ND'

$GREEN = [System.Drawing.Color]::FromArgb(255, 0, 255, 0)     # the ND fonts' green (TXT.2.28.green)

$b = New-Object System.Drawing.Bitmap 2, 12
$g = [System.Drawing.Graphics]::FromImage($b)
$g.Clear([System.Drawing.Color]::Transparent)
$brush = New-Object System.Drawing.SolidBrush $GREEN
$g.FillRectangle($brush, 0, 0, 2, 12)
$g.Dispose(); $brush.Dispose()
$b.Save((Join-Path $nd 'crs_dash-1.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$clear = New-Object System.Drawing.Bitmap 2, 12
$clear.Save((Join-Path $nd 'crs_dash.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$clear.Dispose(); $b.Dispose()
Write-Host 'crs_dash (2 x 12)'
