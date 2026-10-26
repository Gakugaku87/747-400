# Make the custom acf's compact EICAS labels (5-2 step 6b-2, FCOM p.855-856):
# EPR, N1 and EGT cut out of the primary EICAS engine background
# (cockpit_3d/generic/CRT Displays/EICAS Upper/EICAS_eng_bgnd-1.png, the
# labels' rows 3-17, 199-218 and 372-386 of its 33 x 388), each its own
# image, so that the compact format can put them on the rows of its boxes:
#  - eicas_cmp_epr, eicas_cmp_n1, eicas_cmp_egt (33 x 20, the label in the
#    middle), in the same folder.
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_eicas_cmp_images.ps1
#
# Each image is written as <name>-1.png, shown centred on its POS, and a
# transparent <name>.png of the same size, as the stock instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\EICAS Upper'
$src = [System.Drawing.Bitmap]::FromFile((Join-Path $dir 'EICAS_eng_bgnd-1.png'))
$H = 20
foreach ($l in @(@('eicas_cmp_epr', 3, 17), @('eicas_cmp_n1', 199, 218), @('eicas_cmp_egt', 372, 386))) {
    $name, $top, $bottom = $l
    $rows = $bottom - $top + 1
    $b = New-Object System.Drawing.Bitmap $src.Width, $H
    $y0 = [int][math]::Floor(($H - $rows) / 2)
    for ($y = 0; $y -lt $rows; $y++) {
        for ($x = 0; $x -lt $src.Width; $x++) { $b.SetPixel($x, $y0 + $y, $src.GetPixel($x, $top + $y)) }
    }
    $b.Save((Join-Path $dir ($name + '-1.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $clear.Save((Join-Path $dir ($name + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose(); $b.Dispose()
    Write-Host "$name ($($src.Width) x $H, rows $top-$bottom)"
}
$src.Dispose()
