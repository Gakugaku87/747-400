# Make the custom acf's MAP CTR track line and range scale image (5-2,
# 2026-10-28; FCOM p.1143: MAP CTR, p.1009's figure), in
# cockpit_3d/generic/EFIS/Maps/Centered:
#  - track_line_ctr: 10 x 456, centred on the compass rose's centre (its
#    outer edge 228 pixels each way). Through the airplane symbol along the
#    track both ways to the rose's edge, broken from a third of the range on
#    either side (the figure: about 0.35 of the rose), a mark at half the
#    range each way. The selected range is 232.5 pixels from the map's
#    origin (the airplane), 6.5 above the rose's centre on this panel. The
#    stock expanded track line's colour (190 grey), 2-pixel line and 10 x 2
#    marks.
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_nd_ctr_image.ps1
#
# The image is written as track_line_ctr-1.png, shown centred on its POS,
# and a transparent track_line_ctr.png of the same size, as the stock
# instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\EFIS\Maps\Centered'

$GREY = [System.Drawing.Color]::FromArgb(255, 190, 190, 190)   # the stock track line's
$W, $H = 10, 456
$ROSE = 228                 # the rose's outer edge from its centre (roseM_S)
$ORIGIN = 6.5               # the map's origin above the rose's centre
$RANGE = 232.5              # the selected range in MAP CTR
$GAP = $RANGE / 3           # the line broken within this of the airplane
# rows from the image's top for a height above the rose's centre
function Row([double]$up) { return $H / 2 - $up }

$b = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($b)
$g.Clear([System.Drawing.Color]::Transparent)
$brush = New-Object System.Drawing.SolidBrush $GREY
# the line above and below the airplane, 2 pixels wide in the middle
$top = 0
$upper = [math]::Round((Row ($ORIGIN + $GAP)))
$g.FillRectangle($brush, 4, $top, 2, $upper - $top)
$lower = [math]::Round((Row ($ORIGIN - $GAP)))
$g.FillRectangle($brush, 4, $lower, 2, $H - $lower)
# the half range's marks, 10 x 2, centred on their heights
foreach ($m in @(($ORIGIN + $RANGE / 2), ($ORIGIN - $RANGE / 2))) {
    $r = [math]::Round((Row $m) - 1)
    $g.FillRectangle($brush, 0, $r, $W, 2)
    Write-Host ("mark at {0:F2} above the rose's centre: rows {1}-{2}" -f $m, $r, ($r + 1))
}
$g.Dispose(); $brush.Dispose()
$b.Save((Join-Path $dir 'track_line_ctr-1.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$clear = New-Object System.Drawing.Bitmap $W, $H
$clear.Save((Join-Path $dir 'track_line_ctr.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$clear.Dispose(); $b.Dispose()
Write-Host ("track_line_ctr ({0} x {1}): the line rows 0-{2} and {3}-{4}" -f $W, $H, ($upper - 1), $lower, ($H - 1))
