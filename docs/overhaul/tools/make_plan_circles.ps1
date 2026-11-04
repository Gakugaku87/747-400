# docs/overhaul/tools/make_plan_circles.ps1 (2026-11-05, notes/ATA-31.md §46,
# ACF_DIFF.md §5): the ND's PLAN range circles image for the custom acf's
# panel (FCOM p.1027-1028), 600 x 600 pixels centred on PLAN's centre:
# EFIS/Maps/plan_circles.png (transparent: the panel's size, as the stock's
# images) and plan_circles-1.png (the drawing). Two white circles, the
# selected range's (232.5 px, MAP CTR's rose) and its half's, broken at the
# top and the bottom for the numbers (the panel's gen_LEDs); W, E and S
# outside; the true north up arrow at the top's middle in green (FCOM
# p.1151). Run from the repository root:
#   powershell -NoProfile -ExecutionPolicy Bypass -File docs/overhaul/tools/make_plan_circles.ps1
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Get-Location) 'cockpit_3d\generic\EFIS\Maps'
$W = 600; $c = 300.0
$base = New-Object System.Drawing.Bitmap $W, $W, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gb = [System.Drawing.Graphics]::FromImage($base); $gb.Clear([System.Drawing.Color]::Transparent); $gb.Dispose()
$base.Save((Join-Path $dir 'plan_circles.png'), [System.Drawing.Imaging.ImageFormat]::Png); $base.Dispose()
$bmp = New-Object System.Drawing.Bitmap $W, $W, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$white = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$green = [System.Drawing.Color]::FromArgb(255, 0, 255, 0)
$pen = New-Object System.Drawing.Pen $white, 2.0
foreach ($r in 232.5, 116.25) {
  # a gap at the top and the bottom for the range's number (24 px each side)
  $gap = [Math]::Asin(24.0 / $r) * 180.0 / [Math]::PI
  $rect = New-Object System.Drawing.RectangleF ([single]($c - $r)), ([single]($c - $r)), ([single](2 * $r)), ([single](2 * $r))
  $g.DrawArc($pen, $rect, [single](270 + $gap), [single](180 - 2 * $gap))
  $g.DrawArc($pen, $rect, [single](90 + $gap), [single](180 - 2 * $gap))
}
$font = New-Object System.Drawing.Font 'Arial', 19, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
$wb = New-Object System.Drawing.SolidBrush $white
$g.DrawString('W', $font, $wb, (New-Object System.Drawing.PointF ([single]($c - 232.5 - 22)), ([single]$c)), $sf)
$g.DrawString('E', $font, $wb, (New-Object System.Drawing.PointF ([single]($c + 232.5 + 22)), ([single]$c)), $sf)
# S clear of the bottom range number (s254's first photo: 28 px touched it)
$g.DrawString('S', $font, $wb, (New-Object System.Drawing.PointF ([single]$c), ([single]($c + 232.5 + 37))), $sf)
$gb2 = New-Object System.Drawing.SolidBrush $green
$ny = $c - 232.5 - 28
$g.DrawString('N', $font, $gb2, (New-Object System.Drawing.PointF ([single]($c - 7)), ([single]$ny)), $sf)
$gp = New-Object System.Drawing.Pen $green, 2.0
$ax = $c + 9
$g.DrawLine($gp, [single]$ax, [single]($ny + 10), [single]$ax, [single]($ny - 10))
$g.DrawLine($gp, [single]$ax, [single]($ny - 10), [single]($ax - 4), [single]($ny - 4))
$g.DrawLine($gp, [single]$ax, [single]($ny - 10), [single]($ax + 4), [single]($ny - 4))
$g.Dispose()
$bmp.Save((Join-Path $dir 'plan_circles-1.png'), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
'saved plan_circles.png and plan_circles-1.png'
