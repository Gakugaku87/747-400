# Make the 5-digit red LED font of the ECS data block's cabin altitude
# (AIR-18, ACF_DIFF.md section 5) in cockpit_3d/generic/CRT Displays/LED:
#  - LED_3.26B.x####0.red-4.png: the stock 4-row red font
#    (LED_3.26B.xx###0.red) made into 5 rows, as the stock 5-row white font
#    (x####0.white) is built: each row is one digit, and only the last row
#    draws a 0 for a leading zero. The glyphs are the stock ones, pixel for
#    pixel. Each row is 26 pixels: 3 blank, the 22 of the glyphs, 1 blank
#    (the stock rows are 23: the glyphs and 1 blank). With the stock rows the
#    tops of the next row's glyphs showed as faint lines under the digits
#    (s25_data_block); the blank rows above each glyph keep them apart, and
#    the glyph keeps its 1 blank row below, so it sits where it did.
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_led_fonts.ps1
#
# The font is written as <name>-4.png, which a gen_LED draws, and the
# transparent <name>.png the stock fonts have beside it (50 x 24).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\LED'
$ROW_IN = 23            # the stock rows
$PAD = 3                # blank rows added above each glyph
$ROW = $ROW_IN + $PAD   # 26

$src = New-Object System.Drawing.Bitmap (Join-Path $dir 'LED_3.26B.xx###0.red-4.png')
if ($src.Height -ne 4 * $ROW_IN) { throw "LED_3.26B.xx###0.red-4.png is not 4 rows of $ROW_IN" }
$out = New-Object System.Drawing.Bitmap $src.Width, (5 * $ROW), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
# rows 0-3 from the stock rows 0-3, row 0 once more on top: the first four
# rows blank a leading zero, the last draws it
$from_row = @(0, 0, 1, 2, 3)
for ($r = 0; $r -lt 5; $r++) {
    for ($y = 0; $y -lt $ROW_IN; $y++) {
        $sy = $from_row[$r] * $ROW_IN + $y
        $dy = $r * $ROW + $PAD + $y
        for ($x = 0; $x -lt $src.Width; $x++) { $out.SetPixel($x, $dy, $src.GetPixel($x, $sy)) }
    }
}
$name = 'LED_3.26B.x####0.red'
$out.Save((Join-Path $dir "$name-4.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$blank = New-Object System.Drawing.Bitmap 50, 24
$blank.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$blank.Dispose()
"$name ($($out.Width)x$($out.Height))"
$out.Dispose()
$src.Dispose()
