# Make the lower EICAS images of the custom acf (ACF_DIFF.md section 5) from
# the stock art in cockpit_3d/generic/CRT Displays/EICAS Lower:
#  - HYD: pump symbols in the colour of their state (ATA29_32 p.105-106: the
#    circle has the colour of the indication inside), cut from the background
#    so that they cover its white symbols pixel for pixel; the inoperative
#    items of each lost system and of each set of lost systems (FCOM p.1490
#    (13.20.2), p.1487 (13.10.5)), in the font of text_failures.png, the strip
#    the stock pictures were made from;
#  - ELEC: UTILITY and GALLEY of each bus apart (FCOM p.790 (6.10.12));
#  - STAT: the background without its fixed DIS, and CHG and DIS (FCOM p.793
#    (6.10.15)).
# Nothing needs installing: Windows PowerShell 5.1 and System.Drawing.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File make_synoptic_images.ps1
#
# Each image is written as <name>-1.png, which a gen_rotary shows centred on
# its POS, and a transparent <name>.png of the same size, as the stock
# instruments have.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\EICAS Lower\HYD'

$AMBER = @(255, 179, 0)
$CYAN = @(0, 189, 255)
$WHITE = @(255, 255, 255)

function Read-Alpha([System.Drawing.Bitmap]$bmp, [int]$x0, [int]$y0, [int]$w, [int]$h) {
    $a = New-Object 'int[]' ($w * $h)
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $a[$y * $w + $x] = $bmp.GetPixel($x0 + $x, $y0 + $y).A } }
    return , $a
}

function Save-Pair([System.Drawing.Bitmap]$bmp, [string]$name) {
    $bmp.Save((Join-Path $dir "$name-1.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $blank = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
    $blank.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $blank.Dispose()
    "$name ($($bmp.Width)x$($bmp.Height))"
}

# colour times coverage, opaque (the display behind is black)
function Get-Shade($rgb, [double]$t) {
    return [System.Drawing.Color]::FromArgb(255, [int]($rgb[0] * $t), [int]($rgb[1] * $t), [int]($rgb[2] * $t))
}

$bg = New-Object System.Drawing.Bitmap (Join-Path $dir 'background-1.png')

# --- pump symbols -----------------------------------------------------------

# The demand pump circles (background x 23/170/316/462, y 239) and the AUX
# circle (x 599) are the same pixels. The double line of the system box runs
# through the circle; the ring is what is left without it (the line pixels
# are ring only where the ring crosses the channel, rows 2-5 and 50-53).
$CW, $CH = 56, 57
$ring = Read-Alpha $bg 23 239 $CW $CH
foreach ($c in 22, 23, 24, 32, 33, 34) {
    for ($r = 0; $r -lt $CH; $r++) {
        if ($r -le 1 -or $r -ge 54 -or ($r -ge 6 -and $r -le 49)) { $ring[$r * $CW + $c] = 0 }
    }
}
# the inside of the circle: from the centre up to the solid ring
$inside = New-Object 'bool[]' ($CW * $CH)
$stack = New-Object System.Collections.Stack
$stack.Push(28 * $CW + 28)
while ($stack.Count -gt 0) {
    $i = $stack.Pop()
    if ($inside[$i] -or $ring[$i] -ge 128) { continue }
    $inside[$i] = $true
    $x = $i % $CW; $y = [math]::Floor($i / $CW)
    if ($x -gt 0) { $stack.Push($i - 1) }; if ($x -lt $CW - 1) { $stack.Push($i + 1) }
    if ($y -gt 0) { $stack.Push($i - $CW) }; if ($y -lt $CH - 1) { $stack.Push($i + $CW) }
}

# the words of the stock symbols as coverage: AUTO (d_auto-1, cyan on black)
# and OFF (d_off-1, white on black), centred on the circle (28.0, 28.5)
function Get-Word([string]$file, [int]$channel) {
    $b = New-Object System.Drawing.Bitmap (Join-Path $dir $file)
    $t = New-Object 'double[]' ($b.Width * $b.Height)
    $x0 = $b.Width; $x1 = -1; $y0 = $b.Height; $y1 = -1
    for ($y = 0; $y -lt $b.Height; $y++) {
        for ($x = 0; $x -lt $b.Width; $x++) {
            $p = $b.GetPixel($x, $y)
            $v = @($p.R, $p.G, $p.B)[$channel] / 255.0
            $t[$y * $b.Width + $x] = $v
            if ($v -ge 0.5) { if ($x -lt $x0) { $x0 = $x }; if ($x -gt $x1) { $x1 = $x }; if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y } }
        }
    }
    $word = @{ w = $b.Width; h = $b.Height; t = $t
        dx = [int][math]::Round(28.0 - ($x0 + $x1 + 1) / 2.0); dy = [int][math]::Round(28.5 - ($y0 + $y1 + 1) / 2.0) }
    $b.Dispose()
    return $word
}
$AUTO = Get-Word 'd_auto-1.png' 2
$OFF = Get-Word 'd_off-1.png' 0

function New-Circle([string]$name, $rgb, $word) {
    $bmp = New-Object System.Drawing.Bitmap $CW, $CH
    for ($i = 0; $i -lt $CW * $CH; $i++) {
        $x = $i % $CW; $y = [math]::Floor($i / $CW)
        if ($ring[$i] -gt 0) { $bmp.SetPixel($x, $y, (Get-Shade $rgb ($ring[$i] / 255.0))) }
        elseif ($word -and $inside[$i]) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::Black) }
    }
    if ($word) {
        for ($y = 0; $y -lt $word.h; $y++) {
            for ($x = 0; $x -lt $word.w; $x++) {
                $t = $word.t[$y * $word.w + $x]
                $cx = $x + $word.dx; $cy = $y + $word.dy
                if ($t -le 0 -or $cx -lt 0 -or $cy -lt 0 -or $cx -ge $CW -or $cy -ge $CH) { continue }
                if (-not $inside[$cy * $CW + $cx]) { continue }
                $bmp.SetPixel($cx, $cy, (Get-Shade $rgb $t))
            }
        }
    }
    Save-Pair $bmp $name
    $bmp.Dispose()
}

New-Circle 'syn_ring_amber' $AMBER $null     # demand pump ON amber, AUX ON amber
New-Circle 'syn_ring_cyan' $CYAN $null       # AUX ON cyan (standing by)
New-Circle 'syn_auto_cyan' $CYAN $AUTO
New-Circle 'syn_auto_amber' $AMBER $AUTO
New-Circle 'syn_off_amber' $AMBER $OFF
New-Circle 'syn_off_white' $WHITE $OFF       # AUX OFF

# The engine pump box (background x 98/245/391/537, y 188): its 3-pixel border
# in amber, open inside so the double line and the flow show through.
$box = Read-Alpha $bg 98 188 43 43
$bmp = New-Object System.Drawing.Bitmap 43, 43
for ($y = 0; $y -lt 43; $y++) {
    for ($x = 0; $x -lt 43; $x++) {
        $edge = $y -le 2 -or $y -ge 40 -or $x -le 2 -or $x -ge 40
        if ($edge -and $box[$y * 43 + $x] -gt 0) { $bmp.SetPixel($x, $y, (Get-Shade $AMBER ($box[$y * 43 + $x] / 255.0))) }
    }
}
Save-Pair $bmp 'syn_edp_amber'
$bmp.Dispose()

# --- inoperative items ------------------------------------------------------

# The glyph strip: 0-9, A-Z and some signs, centres at 14.49 + 9.772 k
# (fitted to the strip); a glyph is the 22-row column band of its cell.
$strip = New-Object System.Drawing.Bitmap (Join-Path $dir 'text_failures.png')
$CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ%()-_+=|:<.>,/'
$C0, $ADV = 14.49, 9.772
$glyph = @{}
for ($k = 0; $k -lt $CHARS.Length; $k++) {
    $c = $C0 + $ADV * $k
    $j0 = [int][math]::Ceiling($c - $ADV / 2 - 0.5); $j1 = [int][math]::Ceiling($c + $ADV / 2 - 0.5) - 1
    $j1 = [math]::Min($j1, $strip.Width - 1)
    $glyph[[string]$CHARS[$k]] = @{ j0 = $j0; c = $c; a = (Read-Alpha $strip $j0 0 ($j1 - $j0 + 1) $strip.Height); w = $j1 - $j0 + 1 }
}
$GH = $strip.Height
# the stock pictures set the characters closer than the strip does (9.2 to
# 9.35 pixels fitted on their lines) and the lines 16 rows apart
$STEP, $PITCH = 9.25, 16

# draw lines of text with the first character's centre at x, cell tops at y
# (rows of the canvas less its row0); returns the ink columns (alpha 128 and up)
function Add-Text($canvas, [string[]]$lines, [double]$x, [int]$y) {
    $ink0 = 99999; $ink1 = -1
    for ($n = 0; $n -lt $lines.Count; $n++) {
        $s = $lines[$n]
        for ($i = 0; $i -lt $s.Length; $i++) {
            $chr = [string]$s[$i]
            if ($chr -eq ' ') { continue }
            $g = $glyph[$chr]
            if (-not $g) { throw "no glyph for '$chr'" }
            $shift = [int][math]::Round($x + $STEP * $i - $g.c)
            for ($r = 0; $r -lt $GH; $r++) {
                for ($q = 0; $q -lt $g.w; $q++) {
                    $a = $g.a[$r * $g.w + $q]
                    if ($a -le 0) { continue }
                    $cx = $g.j0 + $q + $shift
                    if ($canvas) {
                        $cy = $y + $canvas.row0 + $PITCH * $n + $r
                        if ($cx -lt 0 -or $cx -ge $canvas.w -or $cy -lt 0 -or $cy -ge $canvas.h) { throw "text outside the canvas: '$s'" }
                        $k2 = $cy * $canvas.w + $cx
                        if ($a -gt $canvas.text[$k2]) { $canvas.text[$k2] = $a }
                    }
                    if ($a -ge 128) { if ($cx -lt $ink0) { $ink0 = $cx }; if ($cx -gt $ink1) { $ink1 = $cx } }
                }
            }
        }
    }
    return @($ink0, $ink1)
}

# place a block of text so that its ink starts at column left
function Add-Block($canvas, [string[]]$lines, [int]$left, [int]$y) {
    $m = Add-Text $null $lines 100 $y
    $x = 100 + $left - $m[0]
    return Add-Text $canvas $lines $x $y
}

# a canvas w x h whose row row0 is y 0 of the places given to it
function New-Canvas([int]$w, [int]$h, [int]$row0) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    return @{ bmp = $bmp; g = $g; text = (New-Object 'int[]' ($w * $h)); w = $w; h = $h; row0 = $row0 }
}

$LINE = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, $CYAN[0], $CYAN[1], $CYAN[2]))
$GAP = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0, 0, 0))
# a cyan rectangle between columns x0..x1 and rows y0..y1
function Add-Rect($canvas, [int]$x0, [int]$x1, [int]$y0, [int]$y1, $brush = $LINE) {
    $a = [math]::Min($x0, $x1); $b = [math]::Max($x0, $x1); $c = [math]::Min($y0, $y1); $d = [math]::Max($y0, $y1)
    $canvas.g.FillRectangle($brush, $a, $c + $canvas.row0, $b - $a + 1, $d - $c + 1)
}

# the text in the colour rgb where no line is
function Save-Canvas($canvas, [string]$name, $rgb = $AMBER) {
    $canvas.g.Dispose()
    for ($i = 0; $i -lt $canvas.w * $canvas.h; $i++) {
        $a = $canvas.text[$i]
        if ($a -le 0) { continue }
        $x = $i % $canvas.w; $y = [math]::Floor($i / $canvas.w)
        if ($canvas.bmp.GetPixel($x, $y).A -gt 0) { continue }
        $canvas.bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $rgb[0], $rgb[1], $rgb[2]))
    }
    Save-Pair $canvas.bmp $name
    $canvas.bmp.Dispose()
}

# The canvas of the inoperative pictures: 672 x 242, its row r is background
# y r - 100 (POS 1704, 327 puts the background's top at row 100).
$IW, $IH, $ROW0 = 672, 242, 100

# The lists of the single systems hang from a bar at the same rows for every
# engine type, so the lines of the sets meet them the same way; the P&W
# list ends just above the stems (background y 140). Items as the stock
# pictures, plus THRUST REV with P&W engines (FCOM p.1490, p.1491: each
# system powers its engine's reverser; GE reversers use bleed air, FCOM
# p.893; RR: no source, as GE, estimate).
$LISTS = @(
    @{ n = 1; left = 35; top = 23; items = @('INBD TE FLAPS', 'BODY GEAR', 'AUTOPILOT C', 'L OUTBD ELEV', 'NOSE GEAR', 'STEERING') },
    @{ n = 2; left = 181; top = 71; items = @('AUTOPILOT R', 'SPLR 2,3,10,11', 'YAW DAMPER LWR') },
    @{ n = 3; left = 319; top = 71; items = @('AUTOPILOT L', 'SPLR 1,4,9,12', 'YAW DAMPER UPR') },
    @{ n = 4; left = 490; top = 55; items = @('OUTBD TE FLAPS', 'R OUTBD ELEV', 'SPLR 5,6,7,8', 'WING GEAR') }
)
foreach ($l in $LISTS) {
    foreach ($variant in 'ge', 'pw') {
        $items = $l.items
        if ($variant -eq 'pw') { $items = $items + 'THRUST REV' }
        $cv = New-Canvas $IW $IH $ROW0
        $ink = Add-Block $cv $items $l.left $l.top
        Add-Rect $cv $ink[0] $ink[1] ($l.top - 2) ($l.top - 1)
        Save-Canvas $cv ("inop{0}_{1}" -f $l.n, $variant)
    }
}

# The lines down to the lists: two columns per system and the bar each ends on.
$BUS = @{ 1 = 89; 2 = 244; 3 = 376; 4 = 550 }
$BAR = @{ 1 = 22; 2 = 70; 3 = 70; 4 = 54 }

# A set of lost systems: its items in brackets, a line out of each bracket to
# the first and last system, down to their lists, and down to any system in
# between (BRAKES). Where its line crosses the line of another set, that
# line is cut on both sides of it (bridge), so they do not look joined.
function New-Set([string]$name, [string[]]$items, [double]$centre, [int]$top, [int[]]$systems, [int[]]$bridges = @()) {
    $cv = New-Canvas $IW $IH $ROW0
    $m = Add-Text $null $items 100 $top
    $width = $m[1] - $m[0] + 1
    $left = [int][math]::Round($centre - $width / 2)
    $ink = Add-Block $cv $items $left $top
    $rows = $top + $PITCH * ($items.Count - 1)
    $mid = $top + 8 * ($items.Count - 1) + 9
    $bl = $ink[0] - 6; $br = $ink[1] + 5
    Add-Rect $cv $bl ($bl + 1) ($top + 1) ($rows + 20)
    Add-Rect $cv $br ($br + 1) ($top + 1) ($rows + 20)
    $first = $systems[0]; $last = $systems[-1]
    Add-Rect $cv $BUS[$first] $bl $mid ($mid + 1)
    Add-Rect $cv ($br + 1) ($BUS[$last] + 1) $mid ($mid + 1)
    foreach ($s in $systems) { Add-Rect $cv $BUS[$s] ($BUS[$s] + 1) $mid $BAR[$s] }
    foreach ($s in $bridges) {
        Add-Rect $cv $BUS[$s] ($BUS[$s] + 1) ($mid - 2) ($mid - 1) $GAP
        Add-Rect $cv $BUS[$s] ($BUS[$s] + 1) ($mid + 2) ($mid + 3) $GAP
    }
    Save-Canvas $cv $name
}

# Items powered only by the systems of a set (FCOM p.1490-1491 and the load
# table in notes/ATA-29.md section 2.4); the stock pictures mixed the sets. Places:
# the short sets just above their lists, the long ones higher, so that only
# the sets 1+3 and 2+4 (all four lost) cross.
New-Set 'inop23' @('ELEV FEEL', 'STAB TRIM') 310.5 29 @(2, 3)
New-Set 'inop34' @('R OUTBD AIL', 'R INBD ELEV') 463.5 13 @(3, 4)
New-Set 'inop12' @('L OUTBD AIL', 'L INBD ELEV') 167.5 -18 @(1, 2)
New-Set 'inop124' @('BRAKES') 167.5 -80 @(1, 2, 4)
New-Set 'inop13' @('L INBD AIL', 'UPR RUDDER') 167.5 -57 @(1, 3) @(2)
New-Set 'inop24' @('R INBD AIL', 'LWR RUDDER') 463.5 -26 @(2, 4) @(3)

$strip.Dispose()
$bg.Dispose()

# --- ELEC synoptic: UTILITY and GALLEY --------------------------------------

# Each bus has a UTILITY and a GALLEY label with a line of its own to the bus,
# green while that bus is powered, amber while not (FCOM p.790, 109); the
# stock images draw both on one line in one colour (93 x 61: the line in
# columns 0-2 or 90-92 from row 15 down, ticks at rows 15-17 and 39-41, the
# words beside them). UTILITY keeps the line and the upper tick; GALLEY gets
# an inner line of its own from the lower tick down, as the FCOM draws it.
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\EICAS Lower\ELEC'
function Split-Bus([string]$src, [string]$side, [string]$colour) {
    $b = New-Object System.Drawing.Bitmap (Join-Path $dir "$src-1.png")
    if ($side -eq 'l') { $outer = 0..2; $inner = 6..8; $tick = 0..12; $tick2 = 6..12; $words = 13..92 }
    else { $outer = 90..92; $inner = 84..86; $tick = 80..92; $tick2 = 80..86; $words = 0..79 }
    $colourLine = $b.GetPixel($outer[0], 50)
    $u = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    for ($y = 0; $y -lt $b.Height; $y++) {
        for ($x = 0; $x -lt $b.Width; $x++) {
            $p = $b.GetPixel($x, $y)
            if ($p.A -eq 0) { continue }
            if ($words -contains $x) { if ($y -le 28) { $u.SetPixel($x, $y, $p) } else { $g.SetPixel($x, $y, $p) } }
            elseif ($y -ge 15 -and $y -le 17 -and $tick -contains $x) { $u.SetPixel($x, $y, $p) }
            elseif ($y -ge 15 -and $outer -contains $x) { $u.SetPixel($x, $y, $p) }
            elseif ($y -ge 39 -and $y -le 41 -and $tick2 -contains $x) { $g.SetPixel($x, $y, $p) }
        }
    }
    foreach ($x in $inner) { for ($y = 42; $y -lt $b.Height; $y++) { $g.SetPixel($x, $y, $colourLine) } }
    Save-Pair $u "utility_${side}_$colour"
    Save-Pair $g "galley_${side}_$colour"
    $u.Dispose(); $g.Dispose(); $b.Dispose()
}
Split-Bus 'busgreenl' 'l' 'green'
Split-Bus 'busamberl' 'l' 'amber'
Split-Bus 'busgreenr' 'r' 'green'
Split-Bus 'busamberr' 'r' 'amber'

# --- STAT page: battery CHG and DIS -----------------------------------------

# CHG or DIS beside each battery's current, blank at zero (FCOM p.793); the
# stock background has a fixed cyan DIS on the main battery line (x 471-494,
# y 246-261). The words are data, white as the values (the FCOM draws them
# as it draws the values), in the page's font (the same as the strip's).
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\EICAS Lower\STAT'
$sb = New-Object System.Drawing.Bitmap (Join-Path $dir 'background-1.png')
$clean = New-Object System.Drawing.Bitmap $sb.Width, $sb.Height
for ($y = 0; $y -lt $sb.Height; $y++) {
    for ($x = 0; $x -lt $sb.Width; $x++) {
        if ($x -ge 469 -and $x -le 496 -and $y -ge 244 -and $y -le 263) { continue }
        $p = $sb.GetPixel($x, $y)
        if ($p.A -gt 0) { $clean.SetPixel($x, $y, $p) }
    }
}
Save-Pair $clean 'background_nodis'
$clean.Dispose(); $sb.Dispose()
# 36 x 20 from background x 469, y 244: the words start where DIS did
foreach ($word in 'CHG', 'DIS') {
    $cv = New-Canvas 36 20 0
    [void](Add-Block $cv @($word) 2 0)
    Save-Canvas $cv ("bat_" + $word.ToLower()) $WHITE
}

# --- ELEC synoptic: inhibited for autoland -----------------------------------

# "ELECTRICAL SYNOPTIC INHIBITED FOR AUTOLAND" in place of the synoptic while
# the buses are isolated for autoland (ELEC-18; FCOM p.789 (6.10.11), p.802
# (6.20.8)). In the page's font (the strip's), on a canvas of the
# background's size (672 x 680: the same POS), each line centred, white (the
# colour and the two lines are estimates: the FCOM gives only the words)
$dir = Join-Path $root 'cockpit_3d\generic\CRT Displays\EICAS Lower\ELEC'
$cv = New-Canvas 672 680 0
foreach ($ln in @(@{ t = 'ELECTRICAL SYNOPTIC'; y = 312 }, @{ t = 'INHIBITED FOR AUTOLAND'; y = 336 })) {
    $m = Add-Text $null @($ln.t) 100 0
    $left = [int][math]::Round((672 - ($m[1] - $m[0] + 1)) / 2)
    [void](Add-Block $cv @($ln.t) $left $ln.y)
}
Save-Canvas $cv 'synoptic_inhibited' $WHITE
