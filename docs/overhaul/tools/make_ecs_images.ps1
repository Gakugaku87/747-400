# Make the ECS synoptic images of the custom acf (3-1 step 3, ACF_DIFF.md
# section 5) in cockpit_3d/generic/CRT Displays/EICAS Lower/ECS:
#  - outflow_pointer: the outflow valve pointer, a white bar from the pivot
#    to the left; the pivot is the image's centre, as a turning group turns
#    an image about its POS (FCOM p.577-578);
#  - press_mode_man_amber: the stock MAN in amber (MAN amber, AUTO white:
#    ATA21 p.420), its coverage kept, the amber of ptr_left_amber-1.png.
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_ecs_images.ps1
#
# Each image is written as <name>-1.png, which a gen_rotary shows centred on
# its POS, and a transparent <name>.png of the same size, as the stock
# instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\EICAS Lower\ECS'

$AMBER = @(255, 179, 0)

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $blank = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $blank.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $blank.Dispose()
    "$name ($($bmp.Width)x$($bmp.Height))"
}

# the pointer: 72 x 6 with the pivot at x 36; the bar from x 3 to x 35, 4
# pixels thick (the gauge's radius is about 34: background-1.png)
$ptr = New-Object System.Drawing.Bitmap 72, 6
for ($x = 3; $x -le 35; $x++) {
    for ($y = 1; $y -le 4; $y++) { $ptr.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 255, 255, 255)) }
}
Save-Pair $ptr 'outflow_pointer'
$ptr.Dispose()

# the amber MAN: the stock white MAN's coverage (alpha) in amber
$src = New-Object System.Drawing.Bitmap (Join-Path $dir 'press_mode_man-1.png')
$man = New-Object System.Drawing.Bitmap $src.Width, $src.Height
for ($y = 0; $y -lt $src.Height; $y++) {
    for ($x = 0; $x -lt $src.Width; $x++) {
        $a = $src.GetPixel($x, $y).A
        if ($a -gt 0) { $man.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $AMBER[0], $AMBER[1], $AMBER[2])) }
    }
}
$src.Dispose()
Save-Pair $man 'press_mode_man_amber'
$man.Dispose()
