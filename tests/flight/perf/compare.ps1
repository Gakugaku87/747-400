# Phase 3 of PERF_SIMBRIEF.md (the repository's root; docs/overhaul/TESTING.md
# 4.7): the comparison OFPs (SimBrief's standard B744, Fuel Factor P00)
# against the measured custom acf, offline. No X-Plane.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\perf\compare.ps1 [-CruiseRun <dir>] [-ClimbRun <dir>] [-CeilingRun <dir>] [-OfpDir <dir>]
#
# The aircraft's fuel along each OFP's own route, winds, temperatures,
# weights, levels, steps and Machs, from 10,000 ft in the climb to 10,000 ft
# in the descent (the OFP's first fix at or above 10,000 ft climbing, A, and
# its last one descending, B; below them the OFP's own fuel on both sides,
# the spec's "0-10,000 ft left out of the comparison"):
#   climb    phase 2's climbs (10,000 ft to FL350, FL330 at 90 %) between the
#            two weights around the OFP's at A; above FL350 the ceilings'
#            climbs (FL310 up at M.85) between the two weights around the
#            climb's at FL350 (M.85, not the schedule's M.84: estimate)
#   descent  phase 2's descents (FL350, FL330 at 90 %, to 10,000 ft) between
#            the two weights around the aircraft's at its T/D; above FL350
#            the 33,000-31,000 ft band's increments a foot (estimate)
#   cruise   phase 1's points (Get-PerfCruiseFf) on the OFP's legs between
#            the aircraft's own T/C and T/D, each leg's level, Mach (its
#            thousandths), ISA deviation and ground speed; where the
#            aircraft cruises over the OFP's climb or descent legs, the
#            first or the last cruise leg's; a step: the ceilings' climb
#            between the two levels less the cruise for that time
#            (estimate)
# The climb and the descent in the OFP's mean wind over those legs (ground
# distance = air distance + wind x time); the cruise fills what is left of
# the route's ground distance A-B. The error (PERF_SIMBRIEF.md phase 3):
# the measure-based trip fuel / SimBrief's - 1, a route; the Fuel Factor the
# distance bands' weighted mean.
#
# Output: tests\flight\perf\runs\<yyyyMMdd_HHmmss>_compare\ (local only, as
# the runs): report.md, simbrief_airframe.md, compare.json, legs_<route>.csv.
param(
    [string]$CruiseRun,
    [string]$ClimbRun,
    [string]$CeilingRun,
    [string]$OfpDir,
    [string[]]$Routes = @('KSEA-KLAX', 'EDDF-OMDB', 'KLAX-EDDF'),
    [double[]]$BandShares = @(0.2, 0.2, 0.6),
    [string]$CompareOut,
    [string]$LuaJit = 'C:\Users\gakug\tools\luajit\bin\luajit.exe'
)
$ErrorActionPreference = 'Stop'
# (perf.ps1's param block runs here too: none of its names is used above)
$cmpArgs = @{ CruiseRun = $CruiseRun; ClimbRun = $ClimbRun; CeilingRun = $CeilingRun; OfpDir = $OfpDir; Routes = $Routes
    BandShares = $BandShares; CompareOut = $CompareOut; LuaJit = $LuaJit }
. (Join-Path $PSScriptRoot 'perf.ps1')
$inv = [Globalization.CultureInfo]::InvariantCulture

# the standard atmosphere: the pressure ratio and the temperature (K) at a
# pressure altitude (ft)
function Get-IsaDelta([double]$Ft) {
    if ($Ft -le 36089.24) { return [math]::Pow(1 - 6.8755856e-6 * $Ft, 5.2558797) }
    return 0.2233609 * [math]::Exp(-($Ft - 36089.24) / 20805.8)
}
function Get-IsaTempK([double]$Ft) { if ($Ft -le 36089.24) { return 288.15 - 0.0019812 * $Ft } else { return 216.65 } }

# least squares by the normal equations ($X rows of the terms, $Y the values)
function Get-LsqFit($X, $Y) {
    $n = $X[0].Count
    $A = New-Object 'double[,]' $n, ($n + 1)
    for ($r = 0; $r -lt $X.Count; $r++) {
        for ($i = 0; $i -lt $n; $i++) {
            for ($k = 0; $k -lt $n; $k++) { $A[$i, $k] += $X[$r][$i] * $X[$r][$k] }
            $A[$i, $n] += $X[$r][$i] * $Y[$r]
        }
    }
    for ($i = 0; $i -lt $n; $i++) {
        $p = $A[$i, $i]
        for ($k = $i; $k -le $n; $k++) { $A[$i, $k] /= $p }
        for ($r = 0; $r -lt $n; $r++) {
            if ($r -eq $i) { continue }
            $g = $A[$r, $i]
            for ($k = $i; $k -le $n; $k++) { $A[$r, $k] -= $g * $A[$i, $k] }
        }
    }
    return ,[double[]]@(0..($n - 1) | ForEach-Object { $A[$_, $n] })
}

# piecewise linear through ($Xs, $Ys) (sorted by x), the end segments
# extended; $Clamp: the ends' values beyond them instead
function Get-Lerp([double[]]$Xs, [double[]]$Ys, [double]$X, [switch]$Clamp) {
    $n = $Xs.Count
    if ($n -eq 1) { return $Ys[0] }
    if ($Clamp) { if ($X -le $Xs[0]) { return $Ys[0] }; if ($X -ge $Xs[$n - 1]) { return $Ys[$n - 1] } }
    $i = 1
    while ($i -lt $n - 1 -and $X -gt $Xs[$i]) { $i++ }
    $x0 = $Xs[$i - 1]; $x1 = $Xs[$i]
    if ($x1 -eq $x0) { return $Ys[$i] }
    return $Ys[$i - 1] + ($X - $x0) / ($x1 - $x0) * ($Ys[$i] - $Ys[$i - 1])
}

# ---- the cruise model (phase 1's points) ----
# The points' corrected fuel flow FFc = FF / (delta sqrt(theta)) (theta from
# the point's own air) against x = W/delta (1000 t). The shape: a fit a
# target Mach, c0 + c1 x + c2 x^2 + c3 (h - 35,000)/1000 (the corrected
# flows do not fall on one W/delta line: rms 0.7-0.9 % with h). The values:
# at each level and weight class (light, 78 %, 90 %) the class's three
# Machs moved to the class's mean weight by the shape, piecewise linear in
# the actual Mach; at a level the ratio to the shape linear in the weight
# between the classes (the ends' beyond); linear in the level between the
# levels at the same W/delta. The model returns the measured points.
function New-PerfCruiseModel([string]$PointsCsv) {
    $pts = New-Object System.Collections.ArrayList
    foreach ($p in @(Import-Csv $PointsCsv)) {
        if ($p.status -ne 'done' -or $p.point_id -like 'rep_*') { continue }
        $h = [double]::Parse($p.press_alt_ft, $inv)
        $dl = Get-IsaDelta $h
        $th = ([double]::Parse($p.oat_c, $inv) + 273.15) / 288.15
        $ff = [double]::Parse($p.ff_fuelmass_kgph, $inv)
        $gw = [double]::Parse($p.gw_kg, $inv)
        $cls = if ($p.point_id -like '*_l15_*') { 'l15' } else { 'w' + $p.target_gw_pct }
        [void]$pts.Add([pscustomobject]@{ id = $p.point_id; cls = $cls; level = 100 * [int]$p.target_fl; mt = [double]::Parse($p.target_mach, $inv)
            mach = [double]::Parse($p.mach, $inv); h = $h; gw = $gw; x = $gw / $dl / 1e6; ffc = $ff / ($dl * [math]::Sqrt($th)); ff = $ff; theta = $th })
    }
    $mts = @($pts | ForEach-Object { $_.mt } | Sort-Object -Unique)
    $shape = @{}
    foreach ($mt in $mts) {
        $r = @($pts | Where-Object { $_.mt -eq $mt })
        $X = @($r | ForEach-Object { , [double[]]@(1.0, $_.x, ($_.x * $_.x), (($_.h - 35000) / 1000)) })
        $Y = [double[]]@($r | ForEach-Object { $_.ffc })
        $shape[[string]$mt] = Get-LsqFit $X $Y
    }
    $model = [pscustomobject]@{ points = $pts.ToArray(); machs = [double[]]$mts; shape = $shape; levels = $null; grid = @{} }
    $model.levels = [double[]]@($pts | ForEach-Object { $_.level } | Sort-Object -Unique)
    foreach ($lv in $model.levels) {
        $classes = New-Object System.Collections.ArrayList
        foreach ($cl in @($pts | Where-Object { $_.level -eq $lv } | ForEach-Object { $_.cls } | Sort-Object -Unique)) {
            $r = @($pts | Where-Object { $_.level -eq $lv -and $_.cls -eq $cl } | Sort-Object mach)
            $wref = ($r | Measure-Object gw -Average).Average
            $dl = Get-IsaDelta $lv
            $ms = New-Object System.Collections.ArrayList; $fs = New-Object System.Collections.ArrayList
            foreach ($q in $r) {
                $s0 = Get-PerfShapeFfc $model $q.x $q.h $q.mach
                $s1 = Get-PerfShapeFfc $model ($wref / $dl / 1e6) $q.h $q.mach
                [void]$ms.Add($q.mach); [void]$fs.Add($q.ffc * $s1 / $s0)
            }
            [void]$classes.Add([pscustomobject]@{ cls = $cl; gw = $wref; machs = [double[]]$ms.ToArray(); ffcs = [double[]]$fs.ToArray() })
        }
        $model.grid[[string]$lv] = @($classes | Sort-Object gw)
    }
    return $model
}
# the shape's FFc at x (W/delta, 1000 t), h and a Mach (linear between the
# target Machs' fits, the end ones extended)
function Get-PerfShapeFfc($Model, [double]$X, [double]$H, [double]$Mach) {
    $vals = New-Object System.Collections.ArrayList
    foreach ($mt in $Model.machs) {
        $c = $Model.shape[[string]$mt]
        [void]$vals.Add($c[0] + $c[1] * $X + $c[2] * $X * $X + $c[3] * ($H - 35000) / 1000)
    }
    return Get-Lerp $Model.machs ([double[]]$vals.ToArray()) $Mach
}
# FFc at a level of the grid, a weight (kg) and a Mach
function Get-PerfLevelFfc($Model, [double]$Level, [double]$GwKg, [double]$Mach) {
    $dl = Get-IsaDelta $Level
    $ws = New-Object System.Collections.ArrayList; $ks = New-Object System.Collections.ArrayList
    foreach ($c in $Model.grid[[string]$Level]) {
        $v = Get-Lerp $c.machs $c.ffcs $Mach
        [void]$ws.Add($c.gw); [void]$ks.Add($v / (Get-PerfShapeFfc $Model ($c.gw / $dl / 1e6) $Level $Mach))
    }
    $k = Get-Lerp ([double[]]$ws.ToArray()) ([double[]]$ks.ToArray()) $GwKg -Clamp
    return $k * (Get-PerfShapeFfc $Model ($GwKg / $dl / 1e6) $Level $Mach)
}
# the fuel flow (kg/h, four engines) at a weight (kg), pressure altitude
# (ft), Mach and ISA deviation (C); outside the levels the nearest level's
# ratio to the shape (the shape carries the altitude: estimate)
function Get-PerfCruiseFf($Model, [double]$GwKg, [double]$Ft, [double]$Mach, [double]$IsaDev) {
    $lv = $Model.levels
    $dl = Get-IsaDelta $Ft
    if ($Ft -le $lv[0] -or $Ft -ge $lv[$lv.Count - 1]) {
        $l0 = if ($Ft -le $lv[0]) { $lv[0] } else { $lv[$lv.Count - 1] }
        $k = (Get-PerfLevelFfc $Model $l0 ($GwKg * (Get-IsaDelta $l0) / $dl) $Mach) / (Get-PerfShapeFfc $Model ($GwKg / $dl / 1e6) $l0 $Mach)
        $ffc = $k * (Get-PerfShapeFfc $Model ($GwKg / $dl / 1e6) $Ft $Mach)
    } else {
        # between two levels: each at the same W/delta, linear in the altitude
        $i = 1; while ($Ft -gt $lv[$i]) { $i++ }
        $a = Get-PerfLevelFfc $Model $lv[$i - 1] ($GwKg * (Get-IsaDelta $lv[$i - 1]) / $dl) $Mach
        $b = Get-PerfLevelFfc $Model $lv[$i] ($GwKg * (Get-IsaDelta $lv[$i]) / $dl) $Mach
        $ffc = $a + ($Ft - $lv[$i - 1]) / ($lv[$i] - $lv[$i - 1]) * ($b - $a)
    }
    $th = ((Get-IsaTempK $Ft) + $IsaDev) / 288.15
    return $ffc * $dl * [math]::Sqrt($th)
}

# ---- the climbs, descents and ceilings (phase 2's records) ----
# a raw CSV's rows (doubles; text cells NaN) and its columns ($script:ix set)
function Read-PerfRawRows([string]$File) {
    $lines = [IO.File]::ReadAllLines($File)
    $hdr = $lines[0].Split(',')
    $ixl = @{}; for ($i = 0; $i -lt $hdr.Count; $i++) { $ixl[$hdr[$i]] = $i }
    $list = New-Object System.Collections.ArrayList
    for ($k = 1; $k -lt $lines.Count; $k++) {
        $c = $lines[$k].Split(',')
        $r = New-Object double[] $hdr.Count
        for ($i = 0; $i -lt $hdr.Count -and $i -lt $c.Count; $i++) {
            $v = 0.0
            if ([double]::TryParse($c[$i], [Globalization.NumberStyles]::Float, $inv, [ref]$v)) { $r[$i] = $v } else { $r[$i] = [double]::NaN }
        }
        [void]$list.Add($r)
    }
    $script:ix = $ixl
    return [pscustomobject]@{ ix = $ixl; rows = $list.ToArray() }
}
# A record's profile every 100 ft from its FLCH push (the row before the
# first one in FLCH, pitch mode 8, with the MCP at $McpFt): altitude,
# time, fuel used, air distance and weight at each (Measure-PerfClimb, $Dir
# 1 up, -1 down), to $EndFt less (up) or plus (down) the kit's top margin
function Get-PerfProfile([string]$File, [double]$McpFt, [double]$EndFt, [int]$Dir) {
    $rec = Read-PerfRawRows $File
    $iF = $rec.ix['fma']; $iM = $rec.ix['mcp_alt']
    $first = -1
    for ($k = 0; $k -lt $rec.rows.Count; $k++) { if ($rec.rows[$k][$iF] -eq 8 -and [math]::Abs($rec.rows[$k][$iM] - $McpFt) -le 1) { $first = $k; break } }
    if ($first -lt 1) { throw "no FLCH push to $McpFt ft in $File" }
    $from = $first - 1
    $h0 = $rec.rows[$from][$rec.ix['press_alt_ft']]
    $marks = New-Object System.Collections.ArrayList
    if ($Dir -gt 0) { $a = 100 * [math]::Ceiling(($h0 + 1) / 100); while ($a -lt $EndFt - $ClimbTopMarginFt) { [void]$marks.Add([double]$a); $a += 100 } }
    else { $a = 100 * [math]::Floor(($h0 - 1) / 100); while ($a -gt $EndFt + $ClimbTopMarginFt) { [void]$marks.Add([double]$a); $a -= 100 } }
    $mc = Measure-PerfClimb $rec.rows $from ([double[]]$marks.ToArray()) $EndFt $Dir
    $mk = @($mc.marks)
    return [pscustomobject]@{ file = $File; dir = $Dir; alt = [double[]]@($mk | ForEach-Object { $_.press_alt_ft }); t = [double[]]@($mk | ForEach-Object { $_.t_s })
        fuel = [double[]]@($mk | ForEach-Object { $_.fuel_used_kg }); dair = [double[]]@($mk | ForEach-Object { $_.dist_air_nm }); gw = [double[]]@($mk | ForEach-Object { $_.gw_kg })
        end_reached = $mc.top_reached }
}
# a profile's time, fuel, air distance and weight at an altitude it passes
function Get-PerfProfileAt($P, [double]$Ft) {
    $xs = if ($P.dir -gt 0) { $P.alt } else { [double[]]@($P.alt | ForEach-Object { -$_ }) }
    $x = if ($P.dir -gt 0) { $Ft } else { -$Ft }
    return [pscustomobject]@{ t = (Get-Lerp $xs $P.t $x -Clamp); fuel = (Get-Lerp $xs $P.fuel $x -Clamp); dair = (Get-Lerp $xs $P.dair $x -Clamp); gw = (Get-Lerp $xs $P.gw $x -Clamp) }
}
# the increments (t, fuel, air distance) between two altitudes at a weight
# (kg) at the first one, between the two profiles around it (the nearest one
# beyond them); the profiles must pass both altitudes (within 60 ft: a
# start's level, a top's margin)
function Get-PerfSegment($Profiles, [double]$FromFt, [double]$ToFt, [double]$GwKg) {
    $ok = @($Profiles | Where-Object {
        $lo = ($_.alt | Measure-Object -Minimum).Minimum; $hi = ($_.alt | Measure-Object -Maximum).Maximum
        [math]::Min($FromFt, $ToFt) -ge $lo - 60 -and [math]::Max($FromFt, $ToFt) -le $hi + 60 })
    if ($ok.Count -eq 0) { throw "no profile passes $FromFt-$ToFt ft" }
    $seg = foreach ($p in $ok) {
        $a = Get-PerfProfileAt $p $FromFt; $b = Get-PerfProfileAt $p $ToFt
        [pscustomobject]@{ gw = $a.gw; t = $b.t - $a.t; fuel = $b.fuel - $a.fuel; dair = $b.dair - $a.dair; file = $p.file }
    }
    $seg = @($seg | Sort-Object gw)
    $ws = [double[]]@($seg | ForEach-Object { $_.gw })
    return [pscustomobject]@{ t = (Get-Lerp $ws ([double[]]@($seg | ForEach-Object { $_.t })) $GwKg -Clamp)
        fuel = (Get-Lerp $ws ([double[]]@($seg | ForEach-Object { $_.fuel })) $GwKg -Clamp)
        dair = (Get-Lerp $ws ([double[]]@($seg | ForEach-Object { $_.dair })) $GwKg -Clamp)
        from_gw = $ws; extrapolated = ($GwKg -lt $ws[0] - 1 -or $GwKg -gt $ws[$ws.Count - 1] + 1) }
}

# ---- an OFP ----
function Read-PerfOfp([string]$File) {
    $j = [IO.File]::ReadAllText($File, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $fx = @($j.navlog.fix)
    $legs = New-Object System.Collections.ArrayList
    $s = 0.0
    for ($i = 0; $i -lt $fx.Count; $i++) {
        $x = $fx[$i]
        $s += [double]$x.distance
        [void]$legs.Add([pscustomobject]@{ i = $i; ident = [string]$x.ident; stage = [string]$x.stage; alt = [double]$x.altitude_feet; s = $s
            dist = [double]$x.distance; mach = [double]$x.mach_thousandths; tas = [double]$x.true_airspeed; gs = [double]$x.groundspeed
            wind = [double]$x.wind_component; isa = [double]$x.oat_isa_dev; t_leg = [double]$x.time_leg; t_tot = [double]$x.time_total
            f_leg = [double]$x.fuel_leg; f_used = [double]$x.fuel_totalused; f_onb = [double]$x.fuel_plan_onboard })
    }
    return [pscustomobject]@{ file = $File; route = ('{0}-{1}' -f $j.origin.icao_code, $j.destination.icao_code); base = [string]$j.aircraft.base_type
        custom = [string]$j.aircraft.is_custom; fuelfact = [string]$j.aircraft.fuelfact; ci = [string]$j.general.costindex
        climb = [string]$j.general.climb_profile; descent = [string]$j.general.descent_profile; cruise = [string]$j.general.cruise_profile
        steps = [string]$j.general.stepclimb_string; initial_ft = [double]$j.general.initial_altitude; air_nm = [double]$j.general.air_distance
        zfw = [double]$j.weights.est_zfw; tow = [double]$j.weights.est_tow; ldw = [double]$j.weights.est_ldw; trip = [double]$j.fuel.enroute_burn
        time_s = [double]$j.times.est_time_enroute; generated = [string]$j.params.time_generated; legs = $legs.ToArray() }
}

# The aircraft along an OFP from A to B ($Mach: $null the legs' own, else
# a scriptblock { param($Leg, $GwKg) Mach } for each cruise step). Samples
# (s ground NM from A, t s, fuel kg, gw kg, alt) and the phases' sums.
function Invoke-PerfAlongOfp($Ofp, $Model, $Climbs, $Descents, $Ceilings, $Mach = $null, [double]$StepNm = 5.0) {
    $L = $Ofp.legs
    $iA = -1; for ($i = 0; $i -lt $L.Count; $i++) { if ($L[$i].stage -eq 'CLB' -and $L[$i].alt -ge 10000) { $iA = $i; break } }
    $iB = -1; for ($i = $L.Count - 1; $i -ge 0; $i--) { if ($L[$i].stage -eq 'DSC' -and $L[$i].alt -ge 10000) { $iB = $i; break } }
    $iToc = -1; $iTod = -1
    for ($i = 0; $i -lt $L.Count; $i++) { if ($L[$i].ident -eq 'TOC') { $iToc = $i }; if ($L[$i].ident -eq 'TOD') { $iTod = $i } }
    if ($iA -lt 0 -or $iB -le $iA -or $iToc -lt $iA -or $iTod -gt $iB) { throw "$($Ofp.route): no A, T/C, T/D or B" }
    $crz = @($L | Where-Object { $_.stage -eq 'CRZ' })
    $sA = $L[$iA].s; $sAB = $L[$iB].s - $sA
    $sToc = $L[$iToc].s - $sA; $sTod = $L[$iTod].s - $sA
    $hA = $L[$iA].alt; $hB = $L[$iB].alt
    $hToc = $L[$iToc].alt; $hTod = $crz[$crz.Count - 1].alt
    $gwA = $Ofp.zfw + $L[$iA].f_onb
    # the winds over the OFP's climb (A to T/C) and descent (T/D to B), time-weighted
    $wc = 0.0; $tc = 0.0; for ($i = $iA + 1; $i -le $iToc; $i++) { $wc += $L[$i].wind * $L[$i].t_leg; $tc += $L[$i].t_leg }
    $windClb = if ($tc -gt 0) { $wc / $tc } else { 0.0 }
    $wd = 0.0; $td = 0.0; for ($i = $iTod + 1; $i -le $iB; $i++) { $wd += $L[$i].wind * $L[$i].t_leg; $td += $L[$i].t_leg }
    $windDes = if ($td -gt 0) { $wd / $td } else { 0.0 }
    $res = [ordered]@{ route = $Ofp.route; a = $L[$iA].ident; a_ft = $hA; b = $L[$iB].ident; b_ft = $hB; toc_ft = $hToc; tod_ft = $hTod; gw_a = $gwA
        s_ab = $sAB; s_toc_sb = $sToc; s_tod_sb = $sTod; wind_clb = $windClb; wind_des = $windDes; notes = New-Object System.Collections.ArrayList }
    $samples = New-Object System.Collections.ArrayList
    # the climb: phase 2's to FL350 (FL330 at 90 %), the ceilings' above
    # (to the climbs' top marks, the kit's margin below their tops: the
    # capture's last feet left out)
    $clbTop = 35000.0
    $c1To = [math]::Min($hToc, $clbTop) - $ClimbTopMarginFt
    $seg1 = Get-PerfSegment $Climbs $hA $c1To $gwA
    if ($seg1.extrapolated) { [void]$res.notes.Add(('climb: {0:0.0} t at {1:0} ft outside the climbs'' weights' -f ($gwA / 1000), $hA)) }
    $clb = [ordered]@{ t = $seg1.t; fuel = $seg1.fuel; dair = $seg1.dair }
    # (the profile's samples for the along-track sums: every 1,000 ft)
    $pts = New-Object System.Collections.ArrayList
    $hh = $hA; while ($hh -lt $c1To) { [void]$pts.Add($hh); $hh = 1000 * [math]::Floor($hh / 1000) + 1000 }; [void]$pts.Add($c1To)
    foreach ($h1 in $pts) {
        $sg = if ($h1 -le $hA) { [pscustomobject]@{ t = 0.0; fuel = 0.0; dair = 0.0 } } else { Get-PerfSegment $Climbs $hA $h1 $gwA }
        [void]$samples.Add([pscustomobject]@{ s = $sg.dair + $windClb * $sg.t / 3600; t = $sg.t; fuel = $sg.fuel; gw = $gwA - $sg.fuel; alt = $h1; phase = 'climb' })
    }
    if ($hToc -gt $c1To + $ClimbTopMarginFt + 1) {
        $gw35 = $gwA - $clb.fuel
        $seg2 = Get-PerfSegment $Ceilings $c1To $hToc $gw35
        if ($seg2.extrapolated) { [void]$res.notes.Add(('climb above FL350: {0:0.0} t outside the ceilings'' weights' -f ($gw35 / 1000))) }
        $hh = 1000 * [math]::Floor($c1To / 1000) + 1000
        while ($hh -le $hToc) {
            $sg = Get-PerfSegment $Ceilings $c1To $hh $gw35
            [void]$samples.Add([pscustomobject]@{ s = $clb.dair + $sg.dair + $windClb * ($clb.t + $sg.t) / 3600; t = $clb.t + $sg.t; fuel = $clb.fuel + $sg.fuel
                gw = $gwA - $clb.fuel - $sg.fuel; alt = $hh; phase = 'climb' })
            $hh += 1000
        }
        $clb.t += $seg2.t; $clb.fuel += $seg2.fuel; $clb.dair += $seg2.dair
        [void]$res.notes.Add(('climb {0:0}-{1:0} ft from the ceilings (M.85; estimate)' -f $c1To, $hToc))
    }
    $clb.s = $clb.dair + $windClb * $clb.t / 3600
    $res.climb = $clb
    # the descent, from the final level to B, at the weight at T/D (iterated)
    $desTop = 35000.0
    $getDes = {
        param([double]$GwTod)
        $d = [ordered]@{ t = 0.0; fuel = 0.0; dair = 0.0; ext_ft = 0.0 }
        $top = [math]::Min($hTod, $desTop)
        if ($hTod -gt $desTop) {
            # above the descents' top: the 33,000-31,000 ft band's increments a foot
            $band = Get-PerfSegment $Descents 33000 31000 $GwTod
            $k = ($hTod - $desTop) / 2000
            $d.t = $band.t * $k; $d.fuel = $band.fuel * $k; $d.dair = $band.dair * $k; $d.ext_ft = $hTod - $desTop
        }
        $sg = Get-PerfSegment $Descents $top $hB $GwTod
        $d.t += $sg.t; $d.fuel += $sg.fuel; $d.dair += $sg.dair
        $d.extrapolated = $sg.extrapolated
        $d.s = $d.dair + $windDes * $d.t / 3600
        return $d
    }
    $gwTod = $Ofp.zfw + $L[$iTod].f_onb
    $des = & $getDes $gwTod
    for ($iter = 0; $iter -lt 3; $iter++) {
        $crzSamples = New-Object System.Collections.ArrayList
        $sEnd = $sAB - $des.s
        $s = $clb.s; $t = $clb.t; $fuel = $clb.fuel; $gw = $gwA - $clb.fuel
        $lastAlt = $hToc; $steps = 0.0; $stepList = New-Object System.Collections.ArrayList
        if ($sEnd -le $s) { throw "$($Ofp.route): no cruise left (climb $($clb.s) NM, descent $($des.s) NM of $sAB)" }
        while ($s -lt $sEnd - 1e-6) {
            $ds = [math]::Min($StepNm, $sEnd - $s)
            $sm = $s + $ds / 2
            # the OFP's leg there (A-relative distances)
            $leg = $null
            for ($i = $iA + 1; $i -le $iB; $i++) { if ($L[$i].s - $sA -ge $sm) { $leg = $L[$i]; break } }
            if ($null -eq $leg) { $leg = $L[$iB] }
            $cond = $leg
            if ($leg.stage -eq 'CLB') { $cond = $crz[0] } elseif ($leg.stage -eq 'DSC') { $cond = $crz[$crz.Count - 1] }
            if ($cond.alt -ne $lastAlt) {
                if ($cond.alt -gt $lastAlt) {
                    # a step: the ceilings' climb less the cruise for its time
                    $st = Get-PerfSegment $Ceilings $lastAlt $cond.alt $gw
                    $ffc = Get-PerfCruiseFf $Model $gw $lastAlt ($cond.mach) $cond.isa
                    $extra = $st.fuel - $ffc * $st.t / 3600
                    $fuel += $extra; $gw -= $extra; $steps += $extra
                    # (named by the fix it starts at, as the OFP's step string)
                    [void]$stepList.Add([pscustomobject]@{ at = $L[$cond.i - 1].ident; from = $lastAlt; to = $cond.alt; gw = $gw; climb_t = $st.t; climb_fuel = $st.fuel; extra = $extra })
                }
                $lastAlt = $cond.alt
            }
            $m = if ($null -eq $Mach) { $cond.mach } else { & $Mach $cond $gw }
            # the ground speed: the leg's own, its TAS moved to this Mach
            $gs = $cond.gs + ($m / $cond.mach - 1) * $cond.tas
            $dt = $ds / $gs * 3600
            $ff = Get-PerfCruiseFf $Model $gw $cond.alt $m $cond.isa
            $fuel += $ff * $dt / 3600; $gw -= $ff * $dt / 3600; $t += $dt; $s += $ds
            [void]$crzSamples.Add([pscustomobject]@{ s = $s; t = $t; fuel = $fuel; gw = $gw; alt = $cond.alt; phase = 'cruise'; mach = $m; ff = $ff })
        }
        $newDes = & $getDes $gw
        $conv = [math]::Abs($newDes.s - $des.s) -lt 0.01
        $des = $newDes
        if ($conv) { break }
    }
    $res.descent = $des
    if ($des.ext_ft -gt 0) { [void]$res.notes.Add(('descent {0:0}-{1:0} ft by the 33,000-31,000 ft band (estimate)' -f $hTod, $desTop)) }
    $res.steps = $stepList.ToArray(); $res.steps_fuel = $steps
    foreach ($q in $crzSamples) { [void]$samples.Add($q) }
    $crzFuel = $fuel - $clb.fuel - $steps
    $res.cruise = [ordered]@{ fuel = $crzFuel; t = $t - $clb.t; s = $sEnd - $clb.s; gw_tod = $gw }
    # the descent's samples every 1,000 ft
    $hh = 1000 * [math]::Floor($hTod / 1000)
    $tod = [pscustomobject]@{ s = $sEnd; t = $t; fuel = $fuel; gw = $gw }
    while ($hh -ge $hB) {
        $part = if ($hh -ge $hTod) { [pscustomobject]@{ t = 0.0; fuel = 0.0; dair = 0.0 } } else {
            if ($hh -ge $desTop) { $band = Get-PerfSegment $Descents 33000 31000 $tod.gw; $k = ($hTod - $hh) / 2000; [pscustomobject]@{ t = $band.t * $k; fuel = $band.fuel * $k; dair = $band.dair * $k } }
            else {
                $up = if ($hTod -gt $desTop) { $band = Get-PerfSegment $Descents 33000 31000 $tod.gw; $k = ($hTod - $desTop) / 2000; [pscustomobject]@{ t = $band.t * $k; fuel = $band.fuel * $k; dair = $band.dair * $k } } else { [pscustomobject]@{ t = 0.0; fuel = 0.0; dair = 0.0 } }
                $sg = Get-PerfSegment $Descents ([math]::Min($hTod, $desTop)) $hh $tod.gw
                [pscustomobject]@{ t = $up.t + $sg.t; fuel = $up.fuel + $sg.fuel; dair = $up.dair + $sg.dair }
            } }
        [void]$samples.Add([pscustomobject]@{ s = $tod.s + $part.dair + $windDes * $part.t / 3600; t = $tod.t + $part.t; fuel = $tod.fuel + $part.fuel; gw = $tod.gw - $part.fuel; alt = $hh; phase = 'descent' })
        $hh -= 1000
    }
    [void]$samples.Add([pscustomobject]@{ s = $sAB; t = $tod.t + $des.t; fuel = $tod.fuel + $des.fuel; gw = $tod.gw - $des.fuel; alt = $hB; phase = 'descent' })
    $res.samples = @($samples | Sort-Object s)
    $res.total = [ordered]@{ fuel = $tod.fuel + $des.fuel; t = $tod.t + $des.t }
    # the OFP's own, A to B and its phases
    $res.sb = [ordered]@{ fuel = $L[$iB].f_used - $L[$iA].f_used; t = $L[$iB].t_tot - $L[$iA].t_tot
        climb_fuel = $L[$iToc].f_used - $L[$iA].f_used; cruise_fuel = $L[$iTod].f_used - $L[$iToc].f_used; descent_fuel = $L[$iB].f_used - $L[$iTod].f_used
        climb_t = $L[$iToc].t_tot - $L[$iA].t_tot; cruise_t = $L[$iTod].t_tot - $L[$iToc].t_tot; descent_t = $L[$iB].t_tot - $L[$iTod].t_tot
        below_a_fuel = $L[$iA].f_used; below_b_fuel = $Ofp.trip - $L[$iB].f_used; trip = $Ofp.trip }
    # the aircraft's fuel and time at the OFP's T/C and T/D distances (the same spans)
    $at = {
        param([double]$S)
        $sv = [double[]]@($res.samples | ForEach-Object { $_.s })
        return [pscustomobject]@{ fuel = (Get-Lerp $sv ([double[]]@($res.samples | ForEach-Object { $_.fuel })) $S -Clamp); t = (Get-Lerp $sv ([double[]]@($res.samples | ForEach-Object { $_.t })) $S -Clamp) }
    }
    $atToc = & $at $sToc; $atTod = & $at $sTod
    $res.spans = [ordered]@{ climb_fuel = $atToc.fuel; cruise_fuel = $atTod.fuel - $atToc.fuel; descent_fuel = $res.total.fuel - $atTod.fuel
        climb_t = $atToc.t; cruise_t = $atTod.t - $atToc.t; descent_t = $res.total.t - $atTod.t }
    $res.trip = $res.sb.below_a_fuel + $res.total.fuel + $res.sb.below_b_fuel
    $res.err_ab = $res.total.fuel / $res.sb.fuel - 1
    $res.err_trip = $res.trip / $res.sb.trip - 1
    return $res
}

# the FMC's economy cruise Mach (B747.68.perf_db.lua econ_cruise: the
# FMC's update_econ) at CI $Ci for each (kg, ft, headwind kt, ISA C), by
# LuaJIT; $null without it
function Get-PerfFmcEcon([object[]]$Conds, [int]$Ci) {
    if (-not (Test-Path $cmpArgs.LuaJit)) { return $null }
    $tmp = Join-Path $env:TEMP ('perf_econ_' + [guid]::NewGuid().ToString('N'))
    $lua = "$tmp.lua"; $csv = "$tmp.csv"
    [IO.File]::WriteAllLines($csv, [string[]]@($Conds | ForEach-Object { '{0},{1},{2},{3}' -f $_.kg.ToString($inv), $_.ft.ToString($inv), $_.headwind.ToString($inv), $_.isa.ToString($inv) }), $utf8)
    $db = (Join-Path $repo 'plugins\xtlua_keysystems\scripts\B747.68.xt.fms\B747.68.perf_db.lua') -replace '\\', '/'
    $src = @"
local P = dofile("$db")
local pw = P.tables(0)
for line in io.lines("$($csv -replace '\\', '/')") do
  local kg, ft, hw, isa = line:match("([^,]+),([^,]+),([^,]+),([^,]+)")
  print(string.format("%.5f", P.econ_cruise(pw, tonumber(kg), tonumber(ft), $Ci, tonumber(hw), tonumber(isa))))
end
"@
    [IO.File]::WriteAllText($lua, $src, $utf8)
    try { $out = & $cmpArgs.LuaJit $lua } finally { Remove-Item $lua, $csv -ErrorAction SilentlyContinue }
    return [double[]]@($out | ForEach-Object { [double]::Parse($_, $inv) })
}

# the FCOM's 1.30 g altitude (p.267) at the weights the OFP reaches its
# levels: its initial level at T/C and each step's level there
function Get-PerfLevelChecks($Ofp, $Along) {
    $out = New-Object System.Collections.ArrayList
    $gwToc = $Along.gw_a - $Along.climb.fuel
    [void]$out.Add([pscustomobject]@{ what = 'T/C'; ft = $Along.toc_ft; gw = $gwToc; ceiling = (Get-PerfFcomBuffet130Ft $gwToc) })
    foreach ($st in $Along.steps) { [void]$out.Add([pscustomobject]@{ what = ('step at ' + $st.at); ft = $st.to; gw = $st.gw; ceiling = (Get-PerfFcomBuffet130Ft $st.gw) }) }
    return $out.ToArray()
}

# SimBrief's Fuel Factor from an error (-0.0205: M02; P with 0)
function Format-PerfFactor([double]$E) { $p = [int][math]::Round($E * 100, [MidpointRounding]::AwayFromZero); return ('{0}{1:00}' -f $(if ($p -lt 0) { 'M' } else { 'P' }), [math]::Abs($p)) }

# dot-sourced (tests/flight/perf/compare_offline_test.ps1): the functions only
if ($MyInvocation.InvocationName -eq '.') { return }

$here = $PSScriptRoot
function Resolve-PerfRun([string]$P, [string]$Default) { if ($P) { return (Resolve-Path $P).Path }; return (Join-Path $here $Default) }
$cruiseDir = Resolve-PerfRun $cmpArgs.CruiseRun 'runs\20261108_114312_cruise'
$climbDir = Resolve-PerfRun $cmpArgs.ClimbRun 'runs\20261108_092734_climb_part'
$ceilDir = Resolve-PerfRun $cmpArgs.CeilingRun 'runs\20261108_110001_climb_part'
$ofpDir = Resolve-PerfRun $cmpArgs.OfpDir 'runs\simbrief_ofp_20261108'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$out = if ($cmpArgs.CompareOut) { $cmpArgs.CompareOut } else { Join-Path $here "runs\${stamp}_compare" }
if (Test-Path $out) { throw "the folder exists: $out" }
New-Item -ItemType Directory -Force -Path $out | Out-Null

$model = New-PerfCruiseModel (Join-Path $cruiseDir 'points.csv')
$climbs = @(
    (Get-PerfProfile (Join-Path $climbDir 'raw\clb_l15.csv') 35000 35000 1),
    (Get-PerfProfile (Join-Path $climbDir 'raw\clb_078.csv') 35000 35000 1),
    (Get-PerfProfile (Join-Path $climbDir 'raw\clb_090.csv') 33000 33000 1))
$descents = @(
    (Get-PerfProfile (Join-Path $climbDir 'raw\des_l15.csv') 10000 10000 -1),
    (Get-PerfProfile (Join-Path $climbDir 'raw\des_078.csv') 10000 10000 -1),
    (Get-PerfProfile (Join-Path $climbDir 'raw\des_090.csv') 10000 10000 -1))
# the ceilings to where they stopped (no top: their last row)
$ceilings = foreach ($id in 'cel_l15', 'cel_078', 'cel_090') {
    $f = Join-Path $ceilDir "raw\$id.csv"
    $rec = Read-PerfRawRows $f
    $lastFt = ($rec.rows | ForEach-Object { $_[$rec.ix['press_alt_ft']] } | Measure-Object -Maximum).Maximum
    Get-PerfProfile $f 45000 ([math]::Floor($lastFt / 100) * 100) 1
}
$ceilings = @($ceilings)

$results = New-Object System.Collections.ArrayList
foreach ($rt in $cmpArgs.Routes) {
    $ofp = Read-PerfOfp (Join-Path $ofpDir "$rt.json")
    $along = Invoke-PerfAlongOfp $ofp $model $climbs $descents $ceilings
    # the FMC's ECON CI 200 Mach on the cruise legs, and the cruise flown at it
    $crzLegs = @($ofp.legs | Where-Object { $_.stage -eq 'CRZ' })
    $conds = foreach ($lg in $crzLegs) { [pscustomobject]@{ kg = $ofp.zfw + $lg.f_onb + $lg.f_leg / 2; ft = $lg.alt; headwind = -$lg.wind; isa = $lg.isa } }
    $econ = Get-PerfFmcEcon @($conds) 200
    $alongEcon = $null
    if ($null -ne $econ) {
        $byIdent = @{}; for ($i = 0; $i -lt $crzLegs.Count; $i++) { $byIdent[[string]$crzLegs[$i].i] = $econ[$i] }
        $mFn = { param($Leg, $GwKg) $v = $byIdent[[string]$Leg.i]; if ($null -eq $v) { $Leg.mach } else { $v } }.GetNewClosure()
        $alongEcon = Invoke-PerfAlongOfp $ofp $model $climbs $descents $ceilings $mFn
    }
    [void]$results.Add([pscustomobject]@{ ofp = $ofp; along = $along; econ = $econ; crz_legs = $crzLegs; along_econ = $alongEcon; levels = (Get-PerfLevelChecks $ofp $along) })
    # the legs' file: the OFP's and the aircraft's fuel used from A at each fix
    $sv = [double[]]@($along.samples | ForEach-Object { $_.s })
    $fv = [double[]]@($along.samples | ForEach-Object { $_.fuel })
    $iA = @($ofp.legs | Where-Object { $_.ident -eq $along.a -and $_.stage -eq 'CLB' })[0].i
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('ident,stage,alt_ft,s_from_a_nm,ofp_fuel_from_a_kg,aircraft_fuel_from_a_kg,diff_kg,mach_ofp')
    foreach ($lg in $ofp.legs) {
        if ($lg.i -lt $iA) { continue }
        $sA = $lg.s - $ofp.legs[$iA].s
        if ($sA -gt $along.s_ab + 0.01) { break }
        $fo = $lg.f_used - $ofp.legs[$iA].f_used
        $fa = Get-Lerp $sv $fv $sA -Clamp
        [void]$lines.Add(('{0},{1},{2:0},{3:0.0},{4:0},{5:0},{6:0},{7:0.000}' -f $lg.ident, $lg.stage, $lg.alt, $sA, $fo, $fa, ($fa - $fo), $lg.mach))
    }
    [IO.File]::WriteAllLines((Join-Path $out "legs_$rt.csv"), [string[]]$lines, $utf8)
}

# ---- the values ----
$shares = $cmpArgs.BandShares
$wErr = 0.0; $wErrEcon = 0.0; $wSum = 0.0
for ($i = 0; $i -lt $results.Count; $i++) {
    $wErr += $shares[$i] * $results[$i].along.err_trip; $wSum += $shares[$i]
    if ($null -ne $results[$i].along_econ) { $wErrEcon += $shares[$i] * $results[$i].along_econ.err_trip }
}
$wErr /= $wSum; $wErrEcon /= $wSum
$meta = Get-Content -Raw -Encoding UTF8 (Join-Path $cruiseDir 'meta.json') | ConvertFrom-Json
$wts = $meta.weights

$summary = [ordered]@{ created = (Get-Date).ToString('o'); cruise_run = $cruiseDir; climb_run = $climbDir; ceiling_run = $ceilDir; ofp_dir = $ofpDir
    band_shares = $shares; fuel_factor = [ordered]@{ weighted_err = $wErr; integer = (Format-PerfFactor $wErr); one_decimal = [math]::Round($wErr * 100, 1)
        weighted_err_fmc_econ = $wErrEcon; integer_fmc_econ = (Format-PerfFactor $wErrEcon); one_decimal_fmc_econ = [math]::Round($wErrEcon * 100, 1) }
    routes = @($results | ForEach-Object {
        $r = $_; $a = $r.along
        [ordered]@{ route = $a.route; a = $a.a; a_ft = $a.a_ft; b = $a.b; b_ft = $a.b_ft; toc_ft = $a.toc_ft; tod_ft = $a.tod_ft; gw_a = $a.gw_a; s_ab = $a.s_ab
            sb = $a.sb; aircraft = [ordered]@{ ab_fuel = $a.total.fuel; ab_t = $a.total.t; trip = $a.trip; climb = $a.climb; cruise = $a.cruise; descent = $a.descent
                steps_fuel = $a.steps_fuel; spans = $a.spans }
            err_ab = $a.err_ab; err_trip = $a.err_trip; steps = $a.steps; notes = $a.notes; levels = $r.levels
            econ = $(if ($null -ne $r.econ) { [ordered]@{ fmc_ci200_mach_min = ($r.econ | Measure-Object -Minimum).Minimum; fmc_ci200_mach_max = ($r.econ | Measure-Object -Maximum).Maximum
                    ofp_mach_min = ($r.crz_legs | Measure-Object mach -Minimum).Minimum; ofp_mach_max = ($r.crz_legs | Measure-Object mach -Maximum).Maximum
                    ab_fuel = $r.along_econ.total.fuel; ab_t = $r.along_econ.total.t; trip = $r.along_econ.trip; err_trip = $r.along_econ.err_trip } } else { $null }) }
    }) }
Save-Json (Join-Path $out 'compare.json') $summary

# ---- report.md ----
$md = New-Object System.Collections.ArrayList
function Add-Md([string]$S) { [void]$md.Add($S) }
Add-Md "# PERF_SIMBRIEF.md phase 3: the comparison ($(Split-Path -Leaf $out))"
Add-Md ''
Add-Md ('Inputs: cruise `{0}`, climbs and descents `{1}`, ceilings `{2}`, OFPs `{3}` (kept local).' -f (Split-Path -Leaf $cruiseDir), (Split-Path -Leaf $climbDir), (Split-Path -Leaf $ceilDir), (Split-Path -Leaf $ofpDir))
Add-Md ''
Add-Md '## The cruise model'
Add-Md ''
Add-Md 'The fuel flow is the fuel weight''s fall (kg/h, four engines). The corrected flow FFc = FF / (delta sqrt(theta)), theta from each point''s own air; x = W/delta (1000 t). A fit a target Mach gives the shape: c0 + c1 x + c2 x^2 + c3 (h - 35,000)/1000. The values come from the points:'
Add-Md ''
Add-Md '- each level and weight class: its three Machs moved to the class''s mean weight by the shape, then piecewise linear in the actual Mach;'
Add-Md '- between the classes, the ratio to the shape is linear in the weight (outside them, the end ratio is kept);'
Add-Md '- between the levels, linear in altitude at the same W/delta;'
Add-Md '- FF = FFc x delta x sqrt(theta), with theta from the OFP leg''s ISA deviation.'
Add-Md ''
Add-Md 'The model returns the measured points. The shape alone fits them within the rms below.'
Add-Md ''
Add-Md '| target Mach | c0 | c1 | c2 | c3 | rms of the shape alone |'
Add-Md '|---|---|---|---|---|---|'
foreach ($mt in $model.machs) {
    $c = $model.shape[[string]$mt]
    $r = @($model.points | Where-Object { $_.mt -eq $mt })
    $s2 = 0.0; foreach ($q in $r) { $e = $q.ffc / (Get-PerfShapeFfc $model $q.x $q.h $q.mach) - 1; $s2 += $e * $e }
    Add-Md ('| {0:0.00} | {1:0} | {2:0} | {3:0} | {4:0.0} | {5:0.00} % |' -f $mt, $c[0], $c[1], $c[2], $c[3], (100 * [math]::Sqrt($s2 / $r.Count)))
}
$maxDev = 0.0; foreach ($q in $model.points) { $e = [math]::Abs((Get-PerfCruiseFf $model $q.gw $q.h $q.mach (288.15 * $q.theta - (Get-IsaTempK $q.h))) / $q.ff - 1); if ($e -gt $maxDev) { $maxDev = $e } }
Add-Md ''
Add-Md ('Check: at the 33 points, the model is within {0:0.000} % of the measured flows.' -f (100 * $maxDev))
Add-Md ''
Add-Md '## The routes'
Add-Md ''
Add-Md 'Both sides use the OFP''s own fuel below 10,000 ft:'
Add-Md ''
Add-Md '- from takeoff to A (the first fix at or above 10,000 ft in the climb);'
Add-Md '- from B (the last such fix in the descent) to landing.'
Add-Md ''
Add-Md 'Between A and B, the aircraft flies the OFP''s route, winds, temperatures, levels, steps and Machs. Its climb and descent are its own (phase 2), in the OFP''s mean wind. Its cruise fills the rest of the ground distance.'
Add-Md ''
Add-Md '| route | A | B | A-B NM | OFP A-B kg | aircraft A-B kg | A-B error | OFP trip kg | aircraft trip kg | trip error |'
Add-Md '|---|---|---|---|---|---|---|---|---|---|'
foreach ($r in $results) {
    $a = $r.along
    Add-Md ('| {0} | {1} {2:0} ft | {3} {4:0} ft | {5:0} | {6:0} | {7:0} | {8:+0.00;-0.00} % | {9:0} | {10:0} | {11:+0.00;-0.00} % |' -f $a.route, $a.a, $a.a_ft, $a.b, $a.b_ft, $a.s_ab, $a.sb.fuel, $a.total.fuel, (100 * $a.err_ab), $a.sb.trip, $a.trip, (100 * $a.err_trip))
}
Add-Md ''
Add-Md '### The phases on the OFP''s spans'
Add-Md ''
Add-Md 'These are the aircraft''s fuel and time over the OFP''s own spans of the route: A to the OFP''s T/C, T/C to T/D, and T/D to B.'
Add-Md ''
Add-Md '| route | phase | OFP kg | aircraft kg | error | OFP min | aircraft min |'
Add-Md '|---|---|---|---|---|---|---|'
foreach ($r in $results) {
    $a = $r.along
    foreach ($ph in 'climb', 'cruise', 'descent') {
        $fo = $a.sb["${ph}_fuel"]; $fa = $a.spans["${ph}_fuel"]
        Add-Md ('| {0} | {1} | {2:0} | {3:0} | {4:+0.0;-0.0} % | {5:0.0} | {6:0.0} |' -f $a.route, $ph, $fo, $fa, (100 * ($fa / $fo - 1)), ($a.sb["${ph}_t"] / 60), ($a.spans["${ph}_t"] / 60))
    }
}
Add-Md ''
Add-Md '### The aircraft''s own climb and descent'
Add-Md ''
Add-Md '| route | climb | climb min | climb kg | climb NM (ground) | OFP climb NM | descent | descent min | descent kg | descent NM (ground) | OFP descent NM | steps kg |'
Add-Md '|---|---|---|---|---|---|---|---|---|---|---|---|'
foreach ($r in $results) {
    $a = $r.along
    Add-Md ('| {0} | {1:0}-{2:0} ft | {3:0.0} | {4:0} | {5:0.0} | {6:0.0} | {7:0}-{8:0} ft | {9:0.0} | {10:0} | {11:0.0} | {12:0.0} | {13:0} |' -f $a.route, $a.a_ft, $a.toc_ft, ($a.climb.t / 60), $a.climb.fuel, $a.climb.s, $a.s_toc_sb,
        $a.tod_ft, $a.b_ft, ($a.descent.t / 60), $a.descent.fuel, $a.descent.s, ($a.s_ab - $a.s_tod_sb), $a.steps_fuel)
}
Add-Md ''
foreach ($r in $results) {
    foreach ($st in $r.along.steps) { Add-Md ('- {0}: the step at {1} from {2:0} to {3:0} ft, {4:0.0} t: the climb {5:0} s and {6:0} kg; {7:+0;-0} kg more than cruising.' -f $r.along.route, $st.at, $st.from, $st.to, ($st.gw / 1000), $st.climb_t, $st.climb_fuel, $st.extra) }
    foreach ($n in $r.along.notes) { Add-Md ('- {0}: {1}' -f $r.along.route, $n) }
}
Add-Md ''
Add-Md '## Fuel Factor'
Add-Md ''
Add-Md ('The trip errors are weighted by the distance bands: short {0:0} %, medium {1:0} %, long {2:0} %.' -f (100 * $shares[0]), (100 * $shares[1]), (100 * $shares[2]))
Add-Md ''
Add-Md ('- At the OFPs'' own Machs: {0:+0.00;-0.00} %, so **{1}** (one decimal: {2:+0.0;-0.0}).' -f (100 * $wErr), (Format-PerfFactor $wErr), [math]::Round($wErr * 100, 1))
if ($results[0].along_econ) {
    Add-Md ('- At the FMC''s ECON CI 200 Mach on each cruise leg (what the aircraft flies with CI 200 in the FMC): {0:+0.00;-0.00} %, so {1} (one decimal: {2:+0.0;-0.0}).' -f (100 * $wErrEcon), (Format-PerfFactor $wErrEcon), [math]::Round($wErrEcon * 100, 1))
}
Add-Md ''
Add-Md '## Machs (Default CI)'
Add-Md ''
Add-Md '| route | OFP cruise Mach | FMC ECON CI 200 Mach | aircraft A-B min at the OFP''s Mach | at the FMC''s | trip error at the FMC''s |'
Add-Md '|---|---|---|---|---|---|'
foreach ($r in $results) {
    if ($null -eq $r.econ) { continue }
    $mo = $r.crz_legs | Measure-Object mach -Minimum -Maximum
    $me = $r.econ | Measure-Object -Minimum -Maximum
    Add-Md ('| {0} | {1:0.000}-{2:0.000} | {3:0.000}-{4:0.000} | {5:0.0} | {6:0.0} | {7:+0.00;-0.00} % |' -f $r.along.route, $mo.Minimum, $mo.Maximum, $me.Minimum, $me.Maximum, ($r.along.total.t / 60), ($r.along_econ.total.t / 60), (100 * $r.along_econ.err_trip))
}
Add-Md ''
Add-Md '## Levels (Cruise Level Offset)'
Add-Md ''
Add-Md '| route | where | level ft | weight t | ceiling ft (the FCOM''s 1.30 g) | margin ft |'
Add-Md '|---|---|---|---|---|---|'
foreach ($r in $results) { foreach ($lc in $r.levels) { Add-Md ('| {0} | {1} | {2:0} | {3:0.0} | {4:0} | {5:+0;-0} |' -f $r.along.route, $lc.what, $lc.ft, ($lc.gw / 1000), $lc.ceiling, ($lc.ceiling - $lc.ft)) } }
[IO.File]::WriteAllLines((Join-Path $out 'report.md'), [string[]]$md, $utf8)

# ---- simbrief_airframe.md (the input sheet) ----
$off = 0
foreach ($r in $results) { foreach ($lc in $r.levels) { if ($lc.what -eq 'T/C' -and $lc.ft -gt $lc.ceiling) { $off = [math]::Max($off, 500 * [math]::Ceiling(($lc.ft - $lc.ceiling) / 500)) } } }
$sheet = New-Object System.Collections.ArrayList
[void]$sheet.Add('| SimBriefの欄 | 値 | 単位 | 根拠 |')
[void]$sheet.Add('| --- | --- | --- | --- |')
[void]$sheet.Add('| Base Type | B744 | – | 仕様 |')
[void]$sheet.Add(('| Empty Weight | {0:0} | KG | `{1}` の meta.json（acf の空虚重量） |' -f $wts.oew_kg, (Split-Path -Leaf $cruiseDir)))
[void]$sheet.Add(('| Max Zero Fuel Weight | {0:0} | KG | FCOM p.78（L.10.2）、機番 109 |' -f $wts.mzfw_kg))
[void]$sheet.Add(('| Max Takeoff Weight | {0:0} | KG | FCOM p.78（L.10.2）、機番 109 |' -f $wts.mtow_kg))
[void]$sheet.Add(('| Max Landing Weight | {0:0} | KG | FCOM p.78（L.10.2）、機番 109 |' -f $wts.mlw_kg))
[void]$sheet.Add(('| Max Fuel Capacity | {0:0} | KG | acf のタンクの合計（meta.json） |' -f $wts.fuel_capacity_kg))
[void]$sheet.Add('| Passenger / Baggage Weight | 95 / 25 | KG | 機体の 1 人 120 kg（simconfig の std_pax_weight）を乗客と手荷物に分けた（2026-11-06 利用者） |')
[void]$sheet.Add(('| Fuel Factor | {0}（{1:+0.0;-0.0} %） | P/M ％ | 3 本の Trip Fuel の誤差を距離帯の割合で重みづけ（OFP の Mach。report.md） |' -f (Format-PerfFactor $wErr), [math]::Round($wErr * 100, 1)))
[void]$sheet.Add('| Service Ceiling | 43000 | ft | 軽い段の上限高度（FCOM の決め方）を 1,000 ft 単位で切り下げ（2026-11-08 の記録） |')
[void]$sheet.Add(('| Cruise Level Offset | {0} | ft（M/P表記） | 3 本の初期巡航高度が、その重量の上限高度に届いている（report.md） |' -f $(if ($off -eq 0) { '0' } else { 'M{0:0000}' -f $off })))
[void]$sheet.Add('| Default Cost Index | （利用者と決める） | – | report.md の Mach の表 |')
[void]$sheet.Add('| 計画時に選ぶ巡航プロファイル | （利用者と決める） | – | report.md の Mach の表 |')
[IO.File]::WriteAllLines((Join-Path $out 'simbrief_airframe.md'), [string[]]$sheet, $utf8)
"compare: $out"
'Fuel Factor {0} ({1:+0.00;-0.00} %); at the FMC ECON: {2} ({3:+0.00;-0.00} %)' -f (Format-PerfFactor $wErr), (100 * $wErr), (Format-PerfFactor $wErrEcon), (100 * $wErrEcon)
foreach ($r in $results) { '{0}: A-B {1:+0.00;-0.00} %, trip {2:+0.00;-0.00} %' -f $r.along.route, (100 * $r.along.err_ab), (100 * $r.along.err_trip) }
