# Make the custom acf's PFD barometric setting images for the amber box at
# the transition (5-2 step 4b; FCOM p.995 (10.10.33): "Display is boxed and
# changes to amber"), in cockpit_3d/generic/CRT Displays/PFD:
#  - Baro/STDlabelA and Annunciators/BAROrefA: the stock green STD label and
#    IN./HPA labels recoloured amber (each pixel's coverage kept);
#  - Baro/BaroBoxA: a 2-pixel amber box round the setting and its units
#    (the digits and IN. cover panel x 512-602, y 493-510 on the Captain's
#    outboard PFD, measured on a screenshot: 4 pixels of room each side,
#    10 on the right);
#  - Baro/BaroBoxStdA: the same round STD (x 535-569, y 496-514).
# The digits themselves use the stock amber LED font (LED_2.18R.xx###0.amber).
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_pfd_baro_images.ps1
#
# Each image is written as <name>-1.png, which a gen_rotary shows centred on
# its POS, and a transparent <name>.png of the same size, as the stock
# instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$pfd = Join-Path $root 'cockpit_3d\generic\CRT Displays\PFD'
$baro = Join-Path $pfd 'Baro'
$ann = Join-Path $pfd 'Annunciators'

$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 179, 0)

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$dir, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $clear.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $clear.Dispose()
    Write-Host "$name ($($bmp.Width) x $($bmp.Height))"
}

# a stock green image recoloured amber: the alpha stays, the colour is amber
# scaled by how green the pixel was (the anti-aliased edges keep their shade)
function Convert-Amber([string]$dir, [string]$src, [string]$dst) {
    $in = New-Object System.Drawing.Bitmap (Join-Path $dir "$src-1.png")
    $out = New-Object System.Drawing.Bitmap $in.Width, $in.Height
    for ($y = 0; $y -lt $in.Height; $y++) {
        for ($x = 0; $x -lt $in.Width; $x++) {
            $c = $in.GetPixel($x, $y)
            if ($c.A -gt 0) {
                $k = $c.G / 255.0
                $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c.A, [int](255 * $k), [int](179 * $k), 0))
            }
        }
    }
    $in.Dispose()
    Save-Pair $out $dir $dst
    $out.Dispose()
}

# a box with a 2-pixel amber border
function New-Box([int]$w, [int]$h) {
    $b = New-Object System.Drawing.Bitmap $w, $h
    for ($x = 0; $x -lt $w; $x++) { for ($y = 0; $y -lt 2; $y++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel($x, $h - 1 - $y, $AMBER) } }
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt 2; $x++) { $b.SetPixel($x, $y, $AMBER); $b.SetPixel($w - 1 - $x, $y, $AMBER) } }
    return $b
}

Convert-Amber $baro 'STDlabel' 'STDlabelA'
Convert-Amber $ann 'BAROref' 'BAROrefA'
# round the setting: ink 90 x 17 plus 4 pixels and the border each side,
# and 6 more on the right (the first box touched IN.'s full stop)
$b = New-Box 108 29; Save-Pair $b $baro 'BaroBoxA'; $b.Dispose()
# round STD: ink 34 x 18 plus the same
$b = New-Box 46 30; Save-Pair $b $baro 'BaroBoxStdA'; $b.Dispose()
