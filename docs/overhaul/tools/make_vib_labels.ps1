# Make the secondary EICAS vibration source labels (N1, N2, FAN, LPT) in the
# style of the panel's existing BB label (cockpit_3d/generic/CRT Displays/
# EICAS Lower/vib_BB_label.png and -1.png: 17 px high, white bold letters
# about 8 px wide and 12 px high with soft edges, a transparent base image
# and the letters in the -1 lit image). The letters are drawn four times
# larger in Arial Bold, squeezed into the BB label's letter box and scaled
# down, which gives edges like the BB label's. 2-3 step 3 (ENG-29, FCOM
# p.849-850).
#   powershell -NoProfile -ExecutionPolicy Bypass -File docs\overhaul\tools\make_vib_labels.ps1 [-Out <folder>]
param([string]$Out = (Join-Path $PSScriptRoot "..\..\..\cockpit_3d\generic\CRT Displays\EICAS Lower"))
Add-Type -AssemblyName System.Drawing
$Out = (Resolve-Path $Out).Path
$k = 4                                  # drawing scale
$h = 17                                 # image height, as the BB label
$letterW, $letterH, $gap = 7.5, 12.0, 1.0   # the BB label's letters, px
foreach ($text in @("N1", "N2", "FAN", "LPT")) {
    $n = $text.Length
    $boxW = $n * $letterW + ($n - 1) * $gap
    $w = [int][math]::Ceiling($boxW + 5)        # margins as BB (21 px for 2 letters)
    $big = New-Object Drawing.Bitmap ($w * $k), ($h * $k)
    $g = [Drawing.Graphics]::FromImage($big)
    $g.Clear([Drawing.Color]::Transparent)
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $font = New-Object Drawing.FontFamily "Arial"
    $path.AddString($text, $font, [int][Drawing.FontStyle]::Bold, 100, (New-Object Drawing.PointF 0, 0), [Drawing.StringFormat]::GenericTypographic)
    $bounds = $path.GetBounds()
    # squeeze the letters into the box, centred, the tops 2.5 px down as BB's
    $sx = ($boxW * $k) / $bounds.Width
    $sy = ($letterH * $k) / $bounds.Height
    $m = New-Object Drawing.Drawing2D.Matrix
    $m.Translate((($w - $boxW) / 2) * $k, 2.5 * $k)
    $m.Scale($sx, $sy)
    $m.Translate(-$bounds.X, -$bounds.Y)
    $path.Transform($m)
    # a soft halo, then the letters
    $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(70, 255, 255, 255)), (1.4 * $k)
    $pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($pen, $path)
    $g.FillPath([Drawing.Brushes]::White, $path)
    $small = New-Object Drawing.Bitmap $w, $h
    $s = [Drawing.Graphics]::FromImage($small)
    $s.Clear([Drawing.Color]::Transparent)
    $s.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $s.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $s.DrawImage($big, (New-Object Drawing.Rectangle 0, 0, $w, $h))
    $lit = Join-Path $Out ("vib_" + $text + "_label-1.png")
    $small.Save($lit, [Drawing.Imaging.ImageFormat]::Png)
    $base = New-Object Drawing.Bitmap $w, $h
    $base.Save((Join-Path $Out ("vib_" + $text + "_label.png")), [Drawing.Imaging.ImageFormat]::Png)
    "made $lit ($w x $h)"
}
