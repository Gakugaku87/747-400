# Make the custom acf's ND position trend vector image (5-2 step 5e, FCOM
# p.1147: white), in cockpit_3d/generic/CRT Displays/ND:
#  - tv_piece: a straight piece of the trend vector's dashes, 40 frames side
#    by side (the panel's DIGITS 40) of 4 x 64, frame i a 2-pixel line
#    1.5 (i + 1) pixels long in the middle (B747.60.nd_model.lua's
#    TV_FRAME_PX, TV_FRAMES).
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_nd_tv_image.ps1
#
# The image is written as tv_piece-1.png, shown centred on its POS, and a
# transparent tv_piece.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$nd = Join-Path $root 'cockpit_3d\generic\CRT Displays\ND'

$FRAMES = 40; $FW = 4; $FH = 64
$b = New-Object System.Drawing.Bitmap ($FRAMES * $FW), $FH
$g = [System.Drawing.Graphics]::FromImage($b)
$g.Clear([System.Drawing.Color]::Transparent)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
for ($i = 0; $i -lt $FRAMES; $i++) {
    $len = 1.5 * ($i + 1)
    $g.FillRectangle($brush, [single]($i * $FW + 1), [single]($FH / 2 - $len / 2), [single]2, [single]$len)
}
$g.Dispose(); $brush.Dispose()
$b.Save((Join-Path $nd 'tv_piece-1.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$clear = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$clear.Save((Join-Path $nd 'tv_piece.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$clear.Dispose(); $b.Dispose()
Write-Host "tv_piece ($($FRAMES * $FW) x $FH)"
