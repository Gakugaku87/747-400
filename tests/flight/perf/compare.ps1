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
# The user's choices (2026-11-08, "1番で"): SimBrief and the FMC both at CI
# 200, the Fuel Factor from the cruise at the FMC's ECON CI 200 Mach
# (-FactorBasis fmc_econ; ofp: at the OFPs' own Machs), Default CI 200, the
# cruise profile CI 200. The Service Ceiling from the light ceiling
# (Get-PerfLightCeiling, the FCOM's criteria).
#
# Output: tests\flight\perf\runs\<yyyyMMdd_HHmmss>_compare\ (local only, as
# the runs): report.md, simbrief_airframe.md, compare.json, legs_<route>.csv;
# report.md and simbrief_airframe.md also to tests\flight\perf\ (the spec's
# deliverables, tracked; -NoPublish: not).
param(
    [string]$CruiseRun,
    [string]$ClimbRun,
    [string]$CeilingRun,
    [string]$OfpDir,
    [string[]]$Routes = @('KSEA-KLAX', 'EDDF-OMDB', 'KLAX-EDDF'),
    [double[]]$BandShares = @(0.2, 0.2, 0.6),
    [ValidateSet('fmc_econ', 'ofp')][string]$FactorBasis = 'fmc_econ',
    [int]$DefaultCi = 200,
    [string]$CruiseProfile = 'CI 200',
    [string]$CompareOut,
    [switch]$NoPublish,
    [string]$LuaJit = 'C:\Users\gakug\tools\luajit\bin\luajit.exe'
)
$ErrorActionPreference = 'Stop'
# (perf.ps1's param block runs here too: none of its names is used above)
$cmpArgs = @{ CruiseRun = $CruiseRun; ClimbRun = $ClimbRun; CeilingRun = $CeilingRun; OfpDir = $OfpDir; Routes = $Routes
    BandShares = $BandShares; FactorBasis = $FactorBasis; DefaultCi = $DefaultCi; CruiseProfile = $CruiseProfile; CompareOut = $CompareOut
    NoPublish = [bool]$NoPublish; LuaJit = $LuaJit }
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
            lat = [double]$x.pos_lat; lon = [double]$x.pos_long
            dist = [double]$x.distance; mach = [double]$x.mach_thousandths; tas = [double]$x.true_airspeed; gs = [double]$x.groundspeed
            wind = [double]$x.wind_component; isa = [double]$x.oat_isa_dev; t_leg = [double]$x.time_leg; t_tot = [double]$x.time_total
            f_leg = [double]$x.fuel_leg; f_used = [double]$x.fuel_totalused; f_onb = [double]$x.fuel_plan_onboard })
    }
    return [pscustomobject]@{ file = $File; route = ('{0}-{1}' -f $j.origin.icao_code, $j.destination.icao_code); base = [string]$j.aircraft.base_type
        custom = [string]$j.aircraft.is_custom; fuelfact = [string]$j.aircraft.fuelfact; ci = [string]$j.general.costindex
        climb = [string]$j.general.climb_profile; descent = [string]$j.general.descent_profile; cruise = [string]$j.general.cruise_profile
        steps = [string]$j.general.stepclimb_string; initial_ft = [double]$j.general.initial_altitude; air_nm = [double]$j.general.air_distance
        zfw = [double]$j.weights.est_zfw; tow = [double]$j.weights.est_tow; ldw = [double]$j.weights.est_ldw; trip = [double]$j.fuel.enroute_burn
        takeoff_fuel = [double]$j.fuel.plan_takeoff; airframe = [string]$j.aircraft.name; reg = [string]$j.aircraft.reg
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
    if ($seg1.extrapolated) { [void]$res.notes.Add(('上昇：{1:0} ft の {0:0.0} t は、上昇の記録の重量の外（いちばん近い記録の値）' -f ($gwA / 1000), $hA)) }
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
        if ($seg2.extrapolated) { [void]$res.notes.Add(('FL350 より上の上昇：{0:0.0} t は、上限高度の記録の重量の外（いちばん近い記録の値）' -f ($gw35 / 1000))) }
        $hh = 1000 * [math]::Floor($c1To / 1000) + 1000
        while ($hh -le $hToc) {
            $sg = Get-PerfSegment $Ceilings $c1To $hh $gw35
            [void]$samples.Add([pscustomobject]@{ s = $clb.dair + $sg.dair + $windClb * ($clb.t + $sg.t) / 3600; t = $clb.t + $sg.t; fuel = $clb.fuel + $sg.fuel
                gw = $gwA - $clb.fuel - $sg.fuel; alt = $hh; phase = 'climb' })
            $hh += 1000
        }
        $clb.t += $seg2.t; $clb.fuel += $seg2.fuel; $clb.dair += $seg2.dair
        [void]$res.notes.Add(('上昇の {0:0}〜{1:0} ft は、上限高度の試験の上昇から（M.85。推定）' -f $c1To, $hToc))
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
    if ($des.ext_ft -gt 0) { [void]$res.notes.Add(('降下の {0:0}〜{1:0} ft は、33,000〜31,000 ft の区間の 1 ft あたりの値で（推定）' -f $hTod, $desTop)) }
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

# The light ceiling (PERF_SIMBRIEF.md: the Service Ceiling from the lightest
# test weight) by the kit's own Get-PerfCeiling (the FCOM's criteria: under
# $CeilingRateFpm or the FCOM's 1.30 g altitude) on its raw CSV, from the
# FLCH push to $CeilingTopFt. None found (a record of the 300 fpm days that
# stopped while climbing): the highest altitude reached, under the FCOM's
# 1.30 g altitude at the last weight. The Service Ceiling: that, down to
# 1,000 ft.
function Get-PerfLightCeiling([string]$File) {
    $rec = Read-PerfRawRows $File
    $iF = $rec.ix['fma']; $iM = $rec.ix['mcp_alt']; $iA = $rec.ix['press_alt_ft']; $iW = $rec.ix['weight']
    $first = -1
    for ($k = 0; $k -lt $rec.rows.Count; $k++) { if ($rec.rows[$k][$iF] -eq 8 -and [math]::Abs($rec.rows[$k][$iM] - $CeilingTopFt) -le 1) { $first = $k; break } }
    if ($first -lt 1) { throw "no FLCH push to $CeilingTopFt ft in $File" }
    $from = $first - 1
    $c = Get-PerfCeiling $rec.rows $from $CeilingRateFpm $CeilingWinS $CeilingArmFpm $CeilingHoldS
    $maxFt = 0.0; for ($k = $from; $k -lt $rec.rows.Count; $k++) { if ($rec.rows[$k][$iA] -gt $maxFt) { $maxFt = $rec.rows[$k][$iA] } }
    $value = if ($c.found) { $c.ceiling_ft } else { [math]::Min($maxFt, $c.fcom_ft) }
    return [pscustomobject]@{ file = $File; found = $c.found; limit = $c.limit; ceiling_ft = $c.ceiling_ft; max_ft = $maxFt; fcom_ft = $c.fcom_ft
        last_rate_fpm = $c.last_rate_fpm; gw_kg = $rec.rows[$rec.rows.Count - 1][$iW]; value_ft = $value; service_ft = 1000 * [math]::Floor($value / 1000) }
}

# The input sheet (PERF_SIMBRIEF.md's form): the lines of simbrief_airframe.md
function Get-PerfAirframeSheet($Weights, [string]$CruiseRunName, [string]$CeilingRunName, [double]$FactorErr, [string]$FactorBasis, [double]$OtherErr,
        $Light, [int]$OffsetFt, [int]$DefaultCi, [string]$CruiseProfile) {
    $basisText = if ($FactorBasis -eq 'fmc_econ') { 'FMC の CI 200 の ECON の Mach で巡航したときの' } else { 'OFP の Mach で巡航したときの' }
    $otherText = if ($FactorBasis -eq 'fmc_econ') { 'OFP の Mach なら' } else { 'FMC の CI 200 の ECON の Mach なら' }
    $l = New-Object System.Collections.ArrayList
    [void]$l.Add('| SimBriefの欄 | 値 | 単位 | 根拠 |')
    [void]$l.Add('| --- | --- | --- | --- |')
    [void]$l.Add('| Base Type | B744 | – | 仕様（作成後は変えられない） |')
    [void]$l.Add(('| Empty Weight | {0:0} | KG | acf の空虚重量（`{1}` の meta.json） |' -f $Weights.oew_kg, $CruiseRunName))
    [void]$l.Add(('| Max Zero Fuel Weight | {0:0} | KG | FCOM p.78（L.10.2）、機番 109（2026-11-06 利用者） |' -f $Weights.mzfw_kg))
    [void]$l.Add(('| Max Takeoff Weight | {0:0} | KG | FCOM p.78（L.10.2）、機番 109（2026-11-06 利用者） |' -f $Weights.mtow_kg))
    [void]$l.Add(('| Max Landing Weight | {0:0} | KG | FCOM p.78（L.10.2）、機番 109（2026-11-06 利用者） |' -f $Weights.mlw_kg))
    [void]$l.Add(('| Max Fuel Capacity | {0:0} | KG | acf のタンクの合計（`{1}` の meta.json） |' -f $Weights.fuel_capacity_kg, $CruiseRunName))
    [void]$l.Add('| Passenger / Baggage Weight | 95 / 25 | KG | 機体の 1 人 120 kg（simconfig の std_pax_weight）を、乗客と手荷物に分けた（2026-11-06 利用者） |')
    [void]$l.Add(('| Fuel Factor | {0}（{1:+0.0;-0.0} %） | P/M ％ | {2}、3 本の Trip Fuel の誤差を距離帯の割合で重みづけた値（2026-11-08 利用者）。{3} {4}（{5:+0.0;-0.0} %）。report.md |' -f
        (Format-PerfFactor $FactorErr), [math]::Round($FactorErr * 100, 1), $basisText, $otherText, (Format-PerfFactor $OtherErr), [math]::Round($OtherErr * 100, 1)))
    $how = if ($Light.found) { '記録では {0:#,0} ft（{1}）' -f $Light.ceiling_ft, $Light.limit } else { '記録では {0:#,0} ft でもまだ上昇中（FCOM の 1.30 g の高さ {1:#,0} ft の下）' -f $Light.max_ft, $Light.fcom_ft }
    [void]$l.Add(('| Service Ceiling | {0:0} | ft | 軽い段の上限高度を 1,000 ft 単位で切り下げ。{1}。決め方は FCOM（1.30 g の高さと、上昇推力で 100 fpm を切る高さの低い方。2026-11-08 利用者）。`{2}` |' -f $Light.service_ft, $how, $CeilingRunName))
    [void]$l.Add(('| Cruise Level Offset | {0} | ft（M/P表記） | 3 本の T/C と段階上昇の高さが、その重量の上限高度（FCOM の 1.30 g の高さ）に届いている。report.md |' -f $(if ($OffsetFt -eq 0) { '0' } else { 'M{0:0000}' -f $OffsetFt })))
    [void]$l.Add(('| Default Cost Index | {0} | – | ふだんの CI（2026-11-08 利用者：SimBrief も FMC も CI 200）。機体の FMC の CI 200 は SimBrief の CI 200 より速く、その分は Fuel Factor に入れた。report.md |' -f $DefaultCi))
    [void]$l.Add(('| 計画時に選ぶ巡航プロファイル | {0} | – | 同上 |' -f $CruiseProfile))
    [void]$l.Add('| Engine Type | PW4056 | – | 表示だけ（B744 の既定は RB211-524H。2026-11-08 利用者） |')
    [void]$l.Add('| T/O Thrust | 56740 | LBF | PW4056 の定格推力 252.4 kN（ICAO のエンジンの排出データ。B744 の既定は 60,600 lbf）。SimBrief の離陸の計算に使う（2026-11-08 利用者） |')
    return ,[string[]]$l.ToArray()
}

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
$wErr = 0.0; $wErrEcon = 0.0; $wSum = 0.0; $haveEcon = $true
for ($i = 0; $i -lt $results.Count; $i++) {
    $wErr += $shares[$i] * $results[$i].along.err_trip; $wSum += $shares[$i]
    if ($null -ne $results[$i].along_econ) { $wErrEcon += $shares[$i] * $results[$i].along_econ.err_trip } else { $haveEcon = $false }
}
$wErr /= $wSum; $wErrEcon /= $wSum
$basis = $cmpArgs.FactorBasis
if ($basis -eq 'fmc_econ' -and -not $haveEcon) { $basis = 'ofp'; Write-Warning 'no LuaJIT: the Fuel Factor at the OFPs'' own Machs' }
$fErr = if ($basis -eq 'fmc_econ') { $wErrEcon } else { $wErr }
$oErr = if ($basis -eq 'fmc_econ') { $wErr } else { $wErrEcon }
$meta = Get-Content -Raw -Encoding UTF8 (Join-Path $cruiseDir 'meta.json') | ConvertFrom-Json
$wts = $meta.weights
$light = Get-PerfLightCeiling (Join-Path $ceilDir 'raw\cel_l15.csv')
$off = 0
foreach ($r in $results) { foreach ($lc in $r.levels) { if ($lc.what -eq 'T/C' -and $lc.ft -gt $lc.ceiling) { $off = [math]::Max($off, 500 * [math]::Ceiling(($lc.ft - $lc.ceiling) / 500)) } } }
# the FMC's CI nearest each OFP's cruise Mach (time-weighted over its cruise legs)
$ciList = @(0, 50, 80, 100, 120, 150, 200, 250, 300)
foreach ($r in $results) {
    $r | Add-Member -NotePropertyName ci_match -NotePropertyValue $null
    if ($null -eq $r.econ) { continue }
    $tw = 0.0; $mo = 0.0; foreach ($lg in $r.crz_legs) { $tw += $lg.t_leg; $mo += $lg.mach * $lg.t_leg }
    $conds = @(foreach ($lg in $r.crz_legs) { [pscustomobject]@{ kg = $r.ofp.zfw + $lg.f_onb + $lg.f_leg / 2; ft = $lg.alt; headwind = -$lg.wind; isa = $lg.isa } })
    $best = $null
    foreach ($ci in $ciList) {
        $e = Get-PerfFmcEcon $conds $ci
        $me = 0.0; for ($i = 0; $i -lt $r.crz_legs.Count; $i++) { $me += $e[$i] * $r.crz_legs[$i].t_leg }
        $d = [math]::Abs($me / $tw - $mo / $tw)
        if ($null -eq $best -or $d -lt $best.d) { $best = [pscustomobject]@{ ci = $ci; mach = $me / $tw; d = $d } }
    }
    $r.ci_match = [pscustomobject]@{ ofp_mach = $mo / $tw; ci = $best.ci; fmc_mach = $best.mach }
}

$summary = [ordered]@{ created = (Get-Date).ToString('o'); cruise_run = $cruiseDir; climb_run = $climbDir; ceiling_run = $ceilDir; ofp_dir = $ofpDir
    band_shares = $shares; fuel_factor = [ordered]@{ basis = $basis; value = (Format-PerfFactor $fErr); err = $fErr; one_decimal = [math]::Round($fErr * 100, 1)
        at_ofp_mach = [ordered]@{ err = $wErr; value = (Format-PerfFactor $wErr) }; at_fmc_econ = [ordered]@{ err = $wErrEcon; value = (Format-PerfFactor $wErrEcon) } }
    service_ceiling = $light; cruise_level_offset_ft = $off; default_ci = $cmpArgs.DefaultCi; cruise_profile = $cmpArgs.CruiseProfile
    routes = @($results | ForEach-Object {
        $r = $_; $a = $r.along
        [ordered]@{ route = $a.route; a = $a.a; a_ft = $a.a_ft; b = $a.b; b_ft = $a.b_ft; toc_ft = $a.toc_ft; tod_ft = $a.tod_ft; gw_a = $a.gw_a; s_ab = $a.s_ab
            sb = $a.sb; aircraft = [ordered]@{ ab_fuel = $a.total.fuel; ab_t = $a.total.t; trip = $a.trip; climb = $a.climb; cruise = $a.cruise; descent = $a.descent
                steps_fuel = $a.steps_fuel; spans = $a.spans }
            err_ab = $a.err_ab; err_trip = $a.err_trip; steps = $a.steps; notes = $a.notes; levels = $r.levels; ci_match = $r.ci_match
            econ = $(if ($null -ne $r.econ) { [ordered]@{ fmc_ci200_mach_min = ($r.econ | Measure-Object -Minimum).Minimum; fmc_ci200_mach_max = ($r.econ | Measure-Object -Maximum).Maximum
                    ofp_mach_min = ($r.crz_legs | Measure-Object mach -Minimum).Minimum; ofp_mach_max = ($r.crz_legs | Measure-Object mach -Maximum).Maximum
                    ab_fuel = $r.along_econ.total.fuel; ab_t = $r.along_econ.total.t; trip = $r.along_econ.trip; err_trip = $r.along_econ.err_trip } } else { $null }) }
    }) }
Save-Json (Join-Path $out 'compare.json') $summary

# ---- report.md ----
$md = New-Object System.Collections.ArrayList
function Add-Md([string]$S) { [void]$md.Add($S) }
function Format-PerfPhaseJa([string]$P) { switch ($P) { 'climb' { '上昇' } 'cruise' { '巡航' } 'descent' { '降下' } default { $P } } }
Add-Md "# PERF_SIMBRIEF.md フェーズ3：SimBrief との突き合わせ（$(Split-Path -Leaf $out)）"
Add-Md ''
Add-Md ('入力：巡航 `{0}`、上昇と降下 `{1}`、上限高度 `{2}`、OFP `{3}`（個人の情報を含むので、リポジトリの外）。OFP は SimBrief の標準の B744・P00・ZFW 手入力・CI 200・高度 AUTO。' -f (Split-Path -Leaf $cruiseDir), (Split-Path -Leaf $climbDir), (Split-Path -Leaf $ceilDir), (Split-Path -Leaf $ofpDir))
Add-Md ''
Add-Md '## 入力シートの値'
Add-Md ''
$basisJa = if ($basis -eq 'fmc_econ') { 'FMC の CI 200 の ECON の Mach で巡航したとき' } else { 'OFP の Mach で巡航したとき' }
$otherJa = if ($basis -eq 'fmc_econ') { 'OFP の Mach なら' } else { 'FMC の CI 200 の ECON の Mach なら' }
Add-Md ('- Fuel Factor **{0}**（{1:+0.0;-0.0} %）：{2}の Trip Fuel の誤差を、距離帯の割合（短 {3:0} %・中 {4:0} %・長 {5:0} %）で重みづけた値。{6} {7}（{8:+0.0;-0.0} %）。' -f (Format-PerfFactor $fErr), [math]::Round($fErr * 100, 1), $basisJa,
    (100 * $shares[0]), (100 * $shares[1]), (100 * $shares[2]), $otherJa, (Format-PerfFactor $oErr), [math]::Round($oErr * 100, 1))
$lightJa = if ($light.found) { '（{0:#,0} ft、{1}）' -f $light.ceiling_ft, $light.limit } else { '（記録は {0:#,0} ft でもまだ上昇中。最後の 60 秒の率 {1:0} fpm、FCOM の 1.30 g の高さ {2:#,0} ft の下）' -f $light.max_ft, $light.last_rate_fpm, $light.fcom_ft }
Add-Md ('- Service Ceiling **{0:#,0} ft**：軽い段の上限高度{1}を、1,000 ft 単位で切り下げた（FCOM の決め方：1.30 g の高さと、上昇推力で 100 fpm を切る高さの低い方）。' -f $light.service_ft, $lightJa)
Add-Md ('- Cruise Level Offset **{0}**：下の「高度」の表。' -f $(if ($off -eq 0) { '0' } else { 'M{0:0000}' -f $off }))
Add-Md ('- Default Cost Index **{0}**、巡航プロファイル **{1}**（2026-11-08 利用者：SimBrief も FMC も CI 200）。' -f $cmpArgs.DefaultCi, $cmpArgs.CruiseProfile)
Add-Md '- 重量の欄は `simbrief_airframe.md`。'
Add-Md ''
Add-Md '## 巡航の燃料流量の模型'
Add-Md ''
Add-Md '燃料流量は燃料重量の減り（kg/h、4 発）。補正燃料流量 FFc ＝ FF ÷ (δ√θ)（θ は各点の気温から）、x ＝ W/δ（1000 t）。目標の Mach ごとに c0 ＋ c1 x ＋ c2 x² ＋ c3 (h − 35,000)/1000 を最小二乗で当て、形にした。値は測った点から取る。'
Add-Md ''
Add-Md '- 高さと重量の段ごとに、3 つの Mach を段の平均の重量へ形で移し、実際の Mach で区分的に線形。'
Add-Md '- 段の間は、形との比を重量で線形（段の外は端の比のまま）。'
Add-Md '- 高さの間は、同じ W/δ で高さに線形。'
Add-Md '- FF ＝ FFc × δ × √θ（θ は OFP の区間の ISA 偏差から）。'
Add-Md ''
Add-Md '| 目標の Mach | c0 | c1 | c2 | c3 | 形だけの rms |'
Add-Md '|---|---|---|---|---|---|'
foreach ($mt in $model.machs) {
    $c = $model.shape[[string]$mt]
    $r = @($model.points | Where-Object { $_.mt -eq $mt })
    $s2 = 0.0; foreach ($q in $r) { $e = $q.ffc / (Get-PerfShapeFfc $model $q.x $q.h $q.mach) - 1; $s2 += $e * $e }
    Add-Md ('| {0:0.00} | {1:0} | {2:0} | {3:0} | {4:0.0} | {5:0.00} % |' -f $mt, $c[0], $c[1], $c[2], $c[3], (100 * [math]::Sqrt($s2 / $r.Count)))
}
$maxDev = 0.0; foreach ($q in $model.points) { $e = [math]::Abs((Get-PerfCruiseFf $model $q.gw $q.h $q.mach (288.15 * $q.theta - (Get-IsaTempK $q.h))) / $q.ff - 1); if ($e -gt $maxDev) { $maxDev = $e } }
Add-Md ''
Add-Md ('確かめ：模型は、測った {0} 点に {1:0.000} % 以内で戻る。補正燃料流量は W/δ の 1 本の線には乗らない（形だけでは上の rms）。' -f $model.points.Count, (100 * $maxDev))
Add-Md ''
Add-Md '## ルートごと'
Add-Md ''
Add-Md '10,000 ft より下は、両方とも OFP の燃料にした（離陸から A まで、B から着陸まで）。A は上昇で最初に 10,000 ft 以上になる点、B は降下で最後に 10,000 ft 以上の点。'
Add-Md ''
Add-Md 'A〜B は、機体が OFP の経路・風・気温・高度・段階上昇・Mach の上を、自分の上昇と降下（フェーズ2。OFP のその区間の平均の風で）と巡航で飛ぶ。巡航は、A〜B の対地距離の残りを飛ぶ。'
Add-Md ''
Add-Md '| ルート | A | B | A〜B NM | OFP A〜B kg | 機体 A〜B kg | A〜B の誤差 | OFP Trip kg | 機体 Trip kg | Trip の誤差 |'
Add-Md '|---|---|---|---|---|---|---|---|---|---|'
foreach ($r in $results) {
    $a = $r.along
    Add-Md ('| {0} | {1} {2:0} ft | {3} {4:0} ft | {5:0} | {6:0} | {7:0} | {8:+0.00;-0.00} % | {9:0} | {10:0} | {11:+0.00;-0.00} % |' -f $a.route, $a.a, $a.a_ft, $a.b, $a.b_ft, $a.s_ab, $a.sb.fuel, $a.total.fuel, (100 * $a.err_ab), $a.sb.trip, $a.trip, (100 * $a.err_trip))
}
Add-Md ''
Add-Md '### OFP の区間ごと'
Add-Md ''
Add-Md 'OFP の A〜T/C、T/C〜T/D、T/D〜B の道のりの上での、機体の燃料と時間。機体の上昇や降下が OFP より短いところは、機体は巡航している。'
Add-Md ''
Add-Md '| ルート | 区間 | OFP kg | 機体 kg | 誤差 | OFP 分 | 機体 分 |'
Add-Md '|---|---|---|---|---|---|---|'
foreach ($r in $results) {
    $a = $r.along
    foreach ($ph in 'climb', 'cruise', 'descent') {
        $fo = $a.sb["${ph}_fuel"]; $fa = $a.spans["${ph}_fuel"]
        Add-Md ('| {0} | {1} | {2:0} | {3:0} | {4:+0.0;-0.0} % | {5:0.0} | {6:0.0} |' -f $a.route, (Format-PerfPhaseJa $ph), $fo, $fa, (100 * ($fa / $fo - 1)), ($a.sb["${ph}_t"] / 60), ($a.spans["${ph}_t"] / 60))
    }
}
Add-Md ''
Add-Md '### 機体の上昇と降下'
Add-Md ''
Add-Md '| ルート | 上昇 | 分 | kg | 対地 NM | OFP の上昇 NM | 降下 | 分 | kg | 対地 NM | OFP の降下 NM | 段階上昇 kg |'
Add-Md '|---|---|---|---|---|---|---|---|---|---|---|---|'
foreach ($r in $results) {
    $a = $r.along
    Add-Md ('| {0} | {1:0}〜{2:0} ft | {3:0.0} | {4:0} | {5:0.0} | {6:0.0} | {7:0}〜{8:0} ft | {9:0.0} | {10:0} | {11:0.0} | {12:0.0} | {13:0} |' -f $a.route, $a.a_ft, $a.toc_ft, ($a.climb.t / 60), $a.climb.fuel, $a.climb.s, $a.s_toc_sb,
        $a.tod_ft, $a.b_ft, ($a.descent.t / 60), $a.descent.fuel, $a.descent.s, ($a.s_ab - $a.s_tod_sb), $a.steps_fuel)
}
Add-Md ''
foreach ($r in $results) {
    foreach ($st in $r.along.steps) { Add-Md ('- {0}：{1} からの段階上昇（{2:0}→{3:0} ft、{4:0.0} t）。上昇 {5:0} 秒・{6:0} kg で、巡航より {7:+0;-0} kg 多い（推定）。' -f $r.along.route, $st.at, $st.from, $st.to, ($st.gw / 1000), $st.climb_t, $st.climb_fuel, $st.extra) }
    foreach ($n in $r.along.notes) { Add-Md ('- {0}：{1}' -f $r.along.route, $n) }
}
Add-Md ''
Add-Md '## Fuel Factor'
Add-Md ''
Add-Md ('Trip Fuel の誤差を、距離帯の割合（短 {0:0} %・中 {1:0} %・長 {2:0} %）で重みづけた。' -f (100 * $shares[0]), (100 * $shares[1]), (100 * $shares[2]))
Add-Md ''
Add-Md ('- OFP の Mach で巡航したとき：{0:+0.00;-0.00} % → {1}（小数 1 桁 {2:+0.0;-0.0}）。' -f (100 * $wErr), (Format-PerfFactor $wErr), [math]::Round($wErr * 100, 1))
if ($haveEcon) {
    Add-Md ('- FMC の CI 200 の ECON の Mach（`B747.68.perf_db.lua` の `econ_cruise`）で巡航したとき：{0:+0.00;-0.00} % → {1}（小数 1 桁 {2:+0.0;-0.0}）。' -f (100 * $wErrEcon), (Format-PerfFactor $wErrEcon), [math]::Round($wErrEcon * 100, 1))
}
Add-Md ('- 入力シートは{0}（2026-11-08 利用者：SimBrief も FMC も CI 200）。' -f $(if ($basis -eq 'fmc_econ') { '後者' } else { '前者' }))
Add-Md ''
Add-Md '## Mach（Default CI）'
Add-Md ''
Add-Md '| ルート | OFP の巡航 Mach | FMC の CI 200 の ECON の Mach | 機体 A〜B 分（OFP の Mach） | 同（FMC の Mach） | Trip の誤差（FMC の Mach） | OFP の Mach に近い FMC の CI |'
Add-Md '|---|---|---|---|---|---|---|'
foreach ($r in $results) {
    if ($null -eq $r.econ) { continue }
    $mo = $r.crz_legs | Measure-Object mach -Minimum -Maximum
    $me = $r.econ | Measure-Object -Minimum -Maximum
    Add-Md ('| {0} | {1:0.000}〜{2:0.000} | {3:0.000}〜{4:0.000} | {5:0.0} | {6:0.0} | {7:+0.00;-0.00} % | CI {8}（M{9:0.0000}、OFP は M{10:0.0000}） |' -f $r.along.route, $mo.Minimum, $mo.Maximum, $me.Minimum, $me.Maximum,
        ($r.along.total.t / 60), ($r.along_econ.total.t / 60), (100 * $r.along_econ.err_trip), $r.ci_match.ci, $r.ci_match.fmc_mach, $r.ci_match.ofp_mach)
}
Add-Md ''
Add-Md '## 高度（巡航高度オフセット）'
Add-Md ''
Add-Md '| ルート | 場所 | 高度 ft | 重量 t | 上限高度 ft（FCOM の 1.30 g） | 余裕 ft |'
Add-Md '|---|---|---|---|---|---|'
foreach ($r in $results) {
    foreach ($lc in $r.levels) {
        $where = if ($lc.what -like 'step at *') { '{0} からの段階上昇' -f $lc.what.Substring(8) } else { $lc.what }
        Add-Md ('| {0} | {1} | {2:0} | {3:0.0} | {4:0} | {5:+0;-0} |' -f $r.along.route, $where, $lc.ft, ($lc.gw / 1000), $lc.ceiling, ($lc.ceiling - $lc.ft))
    }
}
Add-Md ''
Add-Md '## 推定の部分'
Add-Md ''
Add-Md '- FL350 より上の上昇：上限高度の試験の上昇（FL310 から M.85。上昇のスケジュールは M.84）。'
Add-Md '- FL350 より上の降下：降下の試験の 33,000〜31,000 ft の区間の、1 ft あたりの時間・燃料・距離。'
Add-Md '- 段階上昇：上限高度の試験の上昇の燃料から、その時間の巡航の燃料を引いた分。'
Add-Md '- 上昇と降下の対地距離：OFP のその区間の、時間で重みづけた平均の風。'
Add-Md ''
Add-Md '## 気づいたこと'
Add-Md ''
$clbErr = @($results | ForEach-Object { 100 * ($_.along.spans.climb_fuel / $_.along.sb.climb_fuel - 1) } | Measure-Object -Minimum -Maximum)
Add-Md ('- 上昇：OFP の上昇の区間で、機体の燃料は {0:+0.0;-0.0}〜{1:+0.0;-0.0} %。1 つの係数では吸収しきれない（上昇の分は、上昇の割合が大きい短い路線ほど Trip に効く）。2026-11-08 の記録では、機体の上昇率は FCOM PI.10.38（p.264。290/.84・最大上昇推力）と、どちらも M.84 の FL350 で合っていた（306 t で 1,114 対 1,116 fpm）。FCOM には上昇の燃料の表が無いので、上昇の燃料流量がどちらに近いかは確かめられない。' -f $clbErr.Minimum, $clbErr.Maximum)
Add-Md '- 降下：OFP の降下は、FCOM PI.11.5（p.271。.84/290/250 で FL370 から着陸まで 129 NM・23 分）に近い。機体の 84/340/250 のアイドルの降下は、それよりずっと急（上の「機体の上昇と降下」の表）。道のりをそろえて比べたので、燃料への響きは小さい。'
[IO.File]::WriteAllLines((Join-Path $out 'report.md'), [string[]]$md, $utf8)

# ---- simbrief_airframe.md (the input sheet) ----
$sheet = Get-PerfAirframeSheet $wts (Split-Path -Leaf $cruiseDir) (Split-Path -Leaf $ceilDir) $fErr $basis $oErr $light $off $cmpArgs.DefaultCi $cmpArgs.CruiseProfile
$sheetLines = @("# SimBrief 入力シート（PERF_SIMBRIEF.md。$(Split-Path -Leaf $out)）", '', 'カスタム機体は B744 をベースに作る。値は SimBrief の単位（KGS）。根拠の詳細は report.md。', '') + $sheet
[IO.File]::WriteAllLines((Join-Path $out 'simbrief_airframe.md'), [string[]]$sheetLines, $utf8)
if (-not $cmpArgs.NoPublish) {
    Copy-Item (Join-Path $out 'report.md') (Join-Path $here 'report.md') -Force
    Copy-Item (Join-Path $out 'simbrief_airframe.md') (Join-Path $here 'simbrief_airframe.md') -Force
}
"compare: $out"
'Fuel Factor {0} ({1}, {2:+0.00;-0.00} %); at the OFPs'' Machs {3} ({4:+0.00;-0.00} %), at the FMC ECON {5} ({6:+0.00;-0.00} %)' -f (Format-PerfFactor $fErr), $basis, (100 * $fErr),
    (Format-PerfFactor $wErr), (100 * $wErr), (Format-PerfFactor $wErrEcon), (100 * $wErrEcon)
'Service Ceiling {0} ft; Cruise Level Offset {1}' -f $light.service_ft, $off
foreach ($r in $results) { '{0}: A-B {1:+0.00;-0.00} %, trip {2:+0.00;-0.00} %' -f $r.along.route, (100 * $r.along.err_ab), (100 * $r.along.err_trip) }
