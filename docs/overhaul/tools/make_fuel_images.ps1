# Make the FUEL synoptic's suction feed images of the custom acf (FUEL-24,
# ACF_DIFF.md section 5) from the stock art in
# cockpit_3d/generic/CRT Displays/EICAS Lower/FUEL: in suction feed the engine
# symbol and the flow segment between it and its tank are amber (ATA26_28
# p.422). The stock white engine symbol and green flow bar, recoloured to the
# synoptic's amber (255, 179, 0, as main_OB_tank_amber and pump-ON_amber),
# pixel for pixel: the same alpha, the colour scaled by the pixel's intensity.
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_fuel_images.ps1
#
# Each image is written as <name>-1.png, which a gen_rotary shows centred on
# its POS, and a transparent <name>.png of the same size, as the stock
# instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\EICAS Lower\FUEL'

$AMBER = @(255, 179, 0)

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $blank = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $blank.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $blank.Dispose()
    "$name ($($bmp.Width)x$($bmp.Height))"
}

# the stock image in amber: the intensity of its brightest channel (white:
# all three, the green bar: green) times amber, its alpha kept
function New-Amber([string]$from, [string]$name) {
    $src = New-Object System.Drawing.Bitmap (Join-Path $dir "$from-1.png")
    $bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height
    for ($y = 0; $y -lt $src.Height; $y++) {
        for ($x = 0; $x -lt $src.Width; $x++) {
            $p = $src.GetPixel($x, $y)
            if ($p.A -eq 0) { continue }
            $t = [math]::Max($p.R, [math]::Max($p.G, $p.B)) / 255.0
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($p.A,
                [int]($AMBER[0] * $t), [int]($AMBER[1] * $t), [int]($AMBER[2] * $t)))
        }
    }
    $src.Dispose()
    Save-Pair $bmp $name
    $bmp.Dispose()
}

New-Amber 'engine' 'engine_amber'                         # the engine symbol
New-Amber 'flow_std\MnToEng' 'flow_std\MnToEng_amber'      # main tank to engine
