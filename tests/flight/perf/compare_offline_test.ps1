# X-Plane-free tests of compare.ps1 (PERF_SIMBRIEF.md phase 3; TESTING.md
# 4.7): the atmosphere, the interpolation, the cruise model on made-up points,
# the profiles, an OFP read, the aircraft along a made-up OFP (the distances
# kept, a step, a descent above the descents' top), the Fuel Factor's form.
# No run folder is read.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\perf\compare_offline_test.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'compare.ps1')
$fails = New-Object System.Collections.ArrayList
$count = 0
function Check([bool]$Ok, [string]$What) { $script:count++; if (-not $Ok) { [void]$fails.Add($What); Write-Host "FAIL $What" } }
function Near([double]$A, [double]$B, [double]$Tol, [string]$What) { Check ([math]::Abs($A - $B) -le $Tol) ('{0} (got {1}, want {2} +- {3})' -f $What, $A, $B, $Tol) }
$tmpBase = Join-Path $env:TEMP ('compare_offline_test_' + [guid]::NewGuid().ToString('N'))

# the atmosphere (ISA: delta 0.2353 at 35,000 ft, 238.4 hPa; 0.1942 at
# 39,000 ft, 196.8 hPa)
Near (Get-IsaDelta 0) 1.0 1e-9 'ISA: delta at sea level'
Near (Get-IsaDelta 35000) 0.23530 2e-5 'ISA: delta at 35,000 ft'
Near (Get-IsaDelta 39000) 0.19420 2e-5 'ISA: delta at 39,000 ft'
Near (Get-IsaDelta 36089.24) (Get-IsaDelta 36089.25) 1e-6 'ISA: delta continuous at the tropopause'
Near (Get-IsaTempK 0) 288.15 1e-9 'ISA: 288.15 K at sea level'
Near (Get-IsaTempK 30000) 228.714 0.01 'ISA: the lapse rate'
Near (Get-IsaTempK 41000) 216.65 1e-9 'ISA: 216.65 K above the tropopause'

# the interpolation and the fit
$xs = [double[]]@(0, 10, 20); $ys = [double[]]@(0, 10, 40)
Near (Get-Lerp $xs $ys 5) 5 1e-9 'lerp: inside'
Near (Get-Lerp $xs $ys 15) 25 1e-9 'lerp: the second segment'
Near (Get-Lerp $xs $ys 25) 55 1e-9 'lerp: beyond, the end segment extended'
Near (Get-Lerp $xs $ys -5) -5 1e-9 'lerp: before, the first segment extended'
Near (Get-Lerp $xs $ys 25 -Clamp) 40 1e-9 'lerp: clamped beyond'
Near (Get-Lerp $xs $ys -5 -Clamp) 0 1e-9 'lerp: clamped before'
Near (Get-Lerp ([double[]]@(3)) ([double[]]@(7)) 100) 7 1e-9 'lerp: one point'
# (the loop's variable not $x: PowerShell's $x is $X)
$fitRows = @(foreach ($v in -2, -1, 0, 1, 2, 3) { , [double[]]@(1.0, $v, ($v * $v)) })
$fitVals = [double[]]@(foreach ($v in -2, -1, 0, 1, 2, 3) { 2 + 3 * $v + 0.5 * $v * $v })
$c = Get-LsqFit $fitRows $fitVals
Check ([math]::Abs($c[0] - 2) -lt 1e-9 -and [math]::Abs($c[1] - 3) -lt 1e-9 -and [math]::Abs($c[2] - 0.5) -lt 1e-9) "fit: 2 + 3x + 0.5x^2 (got $($c -join ', '))"

# the cruise model on made-up points: FFc = 30000 + 20000 (x-1) + 5000 (x-1)^2
# + 300 (h-35000)/1000 + 200000 (M-0.86) (the shape's form, linear in the
# Mach), x = W/delta (1000 t); ISA-1 at each level; the actual Machs .0015
# over the targets, the weights 0.8 t lighter a Mach
$ffcTrue = { param([double]$GwKg, [double]$Ft, [double]$Mach) $x = $GwKg / (Get-IsaDelta $Ft) / 1e6; 30000 + 20000 * ($x - 1) + 5000 * ($x - 1) * ($x - 1) + 300 * ($Ft - 35000) / 1000 + 200000 * ($Mach - 0.86) }
$ffTrue = { param([double]$GwKg, [double]$Ft, [double]$Mach, [double]$Isa) (& $ffcTrue $GwKg $Ft $Mach) * (Get-IsaDelta $Ft) * [math]::Sqrt(((Get-IsaTempK $Ft) + $Isa) / 288.15) }
$csv = New-Object System.Collections.ArrayList
[void]$csv.Add('point_id,plan,target_gw_pct,target_fl,target_mach,gw_kg,press_alt_ft,mach,tas_kt,oat_c,isa_dev_c,ff_fuelmass_kgph,ff_gauge_kgph,n1_avg_pct,pitch_deg,aoa_deg,status,raw_file')
foreach ($fl in 330, 350, 370) {
    $classes = @(@('l15', 60.4, 238000.0), @('078', 78, 307000.0))
    if ($fl -eq 330) { $classes += , @('090', 90, 354000.0) }
    foreach ($cl in $classes) {
        for ($j = 0; $j -lt 3; $j++) {
            $mt = 0.85 + 0.01 * $j; $ma = $mt + 0.0015; $gw = $cl[2] - 800 * $j; $ft = 100.0 * $fl
            $ff = & $ffTrue $gw $ft $ma -1.0
            [void]$csv.Add(('crz_{0}_fl{1}_m{2},A,{3},{4},{5},{6},{7},{8},490,{9},-1,{10},{10},90,2,2,done,raw/x.csv' -f $cl[0], $fl, [int](1000 * $mt), $cl[1], $fl, $mt.ToString($inv), $gw.ToString($inv),
                $ft.ToString($inv), $ma.ToString($inv), ((Get-IsaTempK $ft) - 1 - 273.15).ToString($inv), $ff.ToString($inv)))
        }
    }
}
[void]$csv.Add(('rep_078_fl350_m850,A,78,350,0.85,306000,35000,0.8515,490,{0},-1,99999,99999,90,2,2,done,raw/y.csv' -f ((Get-IsaTempK 35000) - 1 - 273.15).ToString($inv)))
[IO.File]::WriteAllLines("$tmpBase.points.csv", [string[]]$csv, $utf8)
$model = New-PerfCruiseModel "$tmpBase.points.csv"
Check ($model.points.Count -eq 21) "model: 21 points, the repeat left out (got $($model.points.Count))"
Check ((@($model.levels) -join ',') -eq '33000,35000,37000') 'model: the levels'
Check (@($model.grid['33000']).Count -eq 3 -and @($model.grid['35000']).Count -eq 2) 'model: three classes at FL330, two at FL350'
$s85 = $model.shape['0.85']
Near $s85[1] 10000 1e-3 'model: the shape''s x term'
Near $s85[2] 5000 1e-3 'model: the shape''s x^2 term'
Near $s85[3] 300 1e-3 'model: the shape''s altitude term'
$maxDev = 0.0
foreach ($q in $model.points) { $e = [math]::Abs((Get-PerfCruiseFf $model $q.gw $q.h $q.mach -1.0) / $q.ff - 1); if ($e -gt $maxDev) { $maxDev = $e } }
Check ($maxDev -lt 1e-4) "model: returns its points (worst $($maxDev * 100) %)"
$cases = @(@(270000.0, 35000.0, 0.855, 5.0, 5e-4, 'between the weights and the Machs, ISA+5'), @(345000.0, 33000.0, 0.865, -3.0, 5e-4, 'between the 78 % and 90 % classes'),
    @(300000.0, 34000.0, 0.86, 0.0, 5e-4, 'between two levels (the same W/delta)'), @(250000.0, 39000.0, 0.85, 0.0, 1e-3, 'above the levels (the shape''s altitude)'),
    @(225000.0, 37000.0, 0.85, 0.0, 1e-3, 'lighter than the classes'))
foreach ($cs in $cases) {
    $got = Get-PerfCruiseFf $model $cs[0] $cs[1] $cs[2] $cs[3]; $want = & $ffTrue $cs[0] $cs[1] $cs[2] $cs[3]
    Check ([math]::Abs($got / $want - 1) -le $cs[4]) ('model: {0} ({1:0.000} % off)' -f $cs[5], (100 * ($got / $want - 1)))
}
$a = Get-PerfCruiseFf $model 270000 35000 0.855 0; $b = Get-PerfCruiseFf $model 270000 35000 0.855 10
Near ($b / $a) ([math]::Sqrt(((Get-IsaTempK 35000) + 10) / (Get-IsaTempK 35000))) 1e-9 'model: the temperature by sqrt(theta)'

# the profiles: made-up climbs (240 and 300 t: the time with the weight),
# descents (from 35,000 ft) and ceilings (from 31,000 ft)
function New-TestProfile([double]$From, [double]$To, [int]$Dir, [double]$Gw, [double]$SecPerFt, [double]$KgPerS, [double]$Kt) {
    $alt = New-Object System.Collections.ArrayList
    $h = $From
    while ($Dir * ($To - $h) -ge -1e-9) { [void]$alt.Add($h); $h += $Dir * 100 }
    $al = [double[]]$alt.ToArray()
    $t = [double[]]@($al | ForEach-Object { [math]::Abs($_ - $From) * $SecPerFt })
    return [pscustomobject]@{ file = 'made-up'; dir = $Dir; alt = $al; t = $t; fuel = [double[]]@($t | ForEach-Object { $_ * $KgPerS })
        dair = [double[]]@($t | ForEach-Object { $_ * $Kt / 3600 }); gw = [double[]]@($t | ForEach-Object { $Gw - $_ * $KgPerS }); end_reached = $true }
}
$climbs = @((New-TestProfile 10000 35000 1 240000 0.03 4.5 470), (New-TestProfile 10000 35000 1 300000 0.0375 4.5 470))
$descents = @((New-TestProfile 35000 10000 -1 240000 0.02 0.4 400), (New-TestProfile 35000 10000 -1 300000 0.02 0.4 400))
$ceilings = @((New-TestProfile 31000 41000 1 240000 0.04 4.0 480), (New-TestProfile 31000 41000 1 300000 0.05 4.0 480))
# (between the profiles' weights at 15,000 ft: 240 t less 675 kg, 300 t less 843.75 kg)
$sg = Get-PerfSegment $climbs 15000 30000 270000
$spf = 0.03 + 0.0075 * (270000 - 239325) / (299156.25 - 239325)
Near $sg.t (15000 * $spf) 1e-6 'segment: between the weights at its first altitude'
Near $sg.fuel (15000 * $spf * 4.5) 1e-6 'segment: its fuel'
Check (-not $sg.extrapolated) 'segment: inside the weights'
$sgx = Get-PerfSegment $climbs 15000 30000 320000
Near $sgx.t (15000 * 0.0375) 1e-6 'segment: heavier than the profiles, the heaviest'
Check $sgx.extrapolated 'segment: heavier, flagged'
$sgd = Get-PerfSegment $descents 33000 31000 250000
Near $sgd.t 40 1e-6 'segment: down a descent''s profile'
$err = $null; try { [void](Get-PerfSegment $climbs 15000 37000 250000) } catch { $err = $_.Exception.Message }
Check ($err -match 'no profile passes') 'segment: none passes, an error'
Near (Get-PerfProfileAt $descents[0] 20000).t 300 1e-6 'profile: a descent''s time at an altitude'

# a profile from a raw CSV: the FLCH push (pitch mode 8 with the MCP at the
# top) and the marks every 100 ft
$cols = @('sim_t', 'press_alt_ft', 'fuel_kg', 'weight', 'tas_ms', 'gs_ms', 'ff_1', 'ff_2', 'ff_3', 'ff_4', 'n1_1', 'n1_2', 'n1_3', 'n1_4', 'ias', 'mach', 'vminm',
    'thrlim', 'fma', 'fma_at', 'mcp_alt', 'paused', 'sim_speed', 'ground_speed_x')
$rawLines = New-Object System.Collections.ArrayList
[void]$rawLines.Add($cols -join ',')
for ($k = 0; $k -le 400; $k++) {
    $climbing = $k -ge 20
    $alt = if ($climbing) { [math]::Min(15000.0, 10000 + 25 * ($k - 20)) } else { 10000.0 }
    $vals = @((1000 + $k), $alt, (80000 - 3 * $k), (300000 - 3 * $k), 250, 250, 0.75, 0.75, 0.75, 0.75, 90, 90, 90, 90, 300, 0.6, 220, 20,
        $(if ($climbing) { 8 } else { 9 }), 3, $(if ($k -ge 19) { 15000 } else { 10000 }), 0, 1, 1)
    [void]$rawLines.Add((@($vals | ForEach-Object { ([double]$_).ToString($inv) }) -join ','))
}
[IO.File]::WriteAllLines("$tmpBase.raw.csv", [string[]]$rawLines, $utf8)
$pr = Get-PerfProfile "$tmpBase.raw.csv" 15000 15000 1
Near $pr.alt[0] 10000 1e-6 'raw profile: the start at the push''s row'
Near (Get-PerfProfileAt $pr 12500).t 101 1e-6 'raw profile: the time at 12,500 ft (100 s of climb from the row before)'
Near (Get-PerfProfileAt $pr 12500).fuel 303 1e-6 'raw profile: the fuel by the fuel''s weight'
Near (Get-PerfProfileAt $pr 12500).dair (250 * 101 / 1852) 1e-6 'raw profile: the air distance from the TAS'
Check $pr.end_reached 'raw profile: the top reached'

# an OFP's JSON read
$ofpJson = '{"params":{"time_generated":"1"},"origin":{"icao_code":"AAAA"},"destination":{"icao_code":"BBBB"},"aircraft":{"base_type":"B744","is_custom":"0","fuelfact":"1"},' +
    '"general":{"costindex":"200","climb_profile":"250/340/84","descent_profile":"84/340/250","cruise_profile":"CI 200","stepclimb_string":"AAAA/0350","initial_altitude":"35000","air_distance":"840"},' +
    '"weights":{"est_zfw":"200000","est_tow":"260000","est_ldw":"245000"},"fuel":{"enroute_burn":"15000"},"times":{"est_time_enroute":"6000"},' +
    '"navlog":{"fix":[{"ident":"P1","stage":"CLB","altitude_feet":"5000","distance":"10","mach_thousandths":"0.4","true_airspeed":"260","groundspeed":"260","wind_component":"0","oat_isa_dev":"0","time_leg":"120","time_total":"120","fuel_leg":"1500","fuel_totalused":"1500","fuel_plan_onboard":"58500"},' +
    '{"ident":"P2","stage":"CLB","altitude_feet":"12000","distance":"12","mach_thousandths":"0.6","true_airspeed":"380","groundspeed":"370","wind_component":"-10","oat_isa_dev":"1","time_leg":"90","time_total":"210","fuel_leg":"700","fuel_totalused":"2200","fuel_plan_onboard":"57800"}]}}'
[IO.File]::WriteAllText("$tmpBase.ofp.json", $ofpJson, $utf8)
$o = Read-PerfOfp "$tmpBase.ofp.json"
Check ($o.route -eq 'AAAA-BBBB' -and $o.base -eq 'B744' -and $o.ci -eq '200') 'OFP: the route, the base type, the CI'
Check ($o.legs.Count -eq 2 -and $o.legs[1].s -eq 22 -and $o.legs[1].wind -eq -10 -and $o.legs[1].f_onb -eq 57800) 'OFP: the legs, the distance summed'
Near $o.zfw 200000 1e-9 'OFP: the zero fuel weight'

# the aircraft along a made-up OFP: A at 10,000 ft, T/C at FL350, cruise at
# M.855 in still air (490 kt), T/D, B at 10,000 ft
function New-TestLeg($I, $Ident, $Stage, $Alt, $S, $Dist, $TLeg, $TTot, $FLeg, $FUsed) {
    return [pscustomobject]@{ i = $I; ident = $Ident; stage = $Stage; alt = [double]$Alt; s = [double]$S; dist = [double]$Dist; mach = 0.855; tas = 490.0; gs = 490.0; wind = 0.0; isa = 0.0
        t_leg = [double]$TLeg; t_tot = [double]$TTot; f_leg = [double]$FLeg; f_used = [double]$FUsed; f_onb = 60000.0 - $FUsed }
}
function New-TestOfp([double]$Crz2Alt) {
    $legs = @((New-TestLeg 0 'DEP1' 'CLB' 5000 10 10 120 120 1500 1500), (New-TestLeg 1 'A' 'CLB' 10000 20 10 60 180 600 2100),
        (New-TestLeg 2 'P1' 'CLB' 25000 60 40 330 510 2400 4500), (New-TestLeg 3 'TOC' 'CLB' 35000 90 30 240 750 1500 6000),
        (New-TestLeg 4 'C1' 'CRZ' 35000 390 300 2204 2954 5000 11000), (New-TestLeg 5 'C2' 'CRZ' $Crz2Alt 690 300 2204 5158 5000 16000),
        (New-TestLeg 6 'TOD' 'CRZ' $Crz2Alt 740 50 367 5525 800 16800), (New-TestLeg 7 'D1' 'DSC' 20000 780 40 360 5885 200 17000),
        (New-TestLeg 8 'B' 'DSC' 10000 810 30 300 6185 150 17150), (New-TestLeg 9 'ARR' 'DSC' 0 840 30 600 6785 400 17550))
    return [pscustomobject]@{ route = 'TEST'; zfw = 200000.0; trip = 17550.0; legs = $legs }
}
$ofp = New-TestOfp 35000
$al = Invoke-PerfAlongOfp $ofp $model $climbs $descents $ceilings
$gwA = 200000 + 60000 - 2100
$kw = 1 + 0.25 * ($gwA - 240000) / 60000
Check ($al.a -eq 'A' -and $al.b -eq 'B' -and $al.s_ab -eq 790) 'along: A, B and the distance between'
Near $al.gw_a $gwA 1e-6 'along: the weight at A from the OFP''s fuel on board'
Near $al.climb.t (24970 * 0.03 * $kw) 1e-6 'along: the climb to the climbs'' top mark (34,970 ft)'
Near $al.climb.fuel (24970 * 0.03 * $kw * 4.5) 1e-6 'along: the climb''s fuel'
Near $al.descent.t (25000 * 0.02) 1e-6 'along: the descent from FL350 to B'
Near $al.descent.s (25000 * 0.02 * 400 / 3600) 1e-6 'along: the descent''s distance'
# the cruise by hand, 0.5 NM at a time over what the climb and the descent leave
$s0 = $al.climb.s; $s1 = 790 - $al.descent.s; $gw = $gwA - $al.climb.fuel; $f = 0.0; $tc = 0.0
$n = [int][math]::Ceiling(($s1 - $s0) / 0.5); $ds = ($s1 - $s0) / $n
for ($i = 0; $i -lt $n; $i++) { $ff = Get-PerfCruiseFf $model $gw 35000 0.855 0; $dt = $ds / 490 * 3600; $f += $ff * $dt / 3600; $gw -= $ff * $dt / 3600; $tc += $dt }
Near $al.cruise.fuel $f ($f * 5e-4) 'along: the cruise over the distance left'
Near $al.cruise.s ($s1 - $s0) 1e-6 'along: the cruise''s distance'
Near $al.total.fuel ($al.climb.fuel + $f + $al.descent.fuel) ($f * 5e-4) 'along: A-B the climb, the cruise and the descent'
Near ($al.spans.climb_fuel + $al.spans.cruise_fuel + $al.spans.descent_fuel) $al.total.fuel 1e-6 'along: the OFP''s spans add up'
Near $al.sb.fuel (17150 - 2100) 1e-9 'along: the OFP''s A-B fuel'
Near $al.trip (2100 + $al.total.fuel + (17550 - 17150)) 1e-6 'along: the trip with the OFP''s fuel below 10,000 ft'
Near $al.err_trip ($al.trip / 17550 - 1) 1e-12 'along: the trip''s error'
Check ($al.steps.Count -eq 0) 'along: no step'
# a 10 kt tailwind in the climb legs: the climb's ground distance longer
$ofpW = New-TestOfp 35000
foreach ($i in 2, 3) { $ofpW.legs[$i].wind = 10 }
$alW = Invoke-PerfAlongOfp $ofpW $model $climbs $descents $ceilings
Near $alW.climb.s ($al.climb.dair + 10 * $al.climb.t / 3600) 1e-6 'along: the climb''s ground distance with the OFP''s climb wind'
# a step to FL370 at C2 (and T/D at FL370): the ceilings' climb less the cruise
$ofpS = New-TestOfp 37000
$alS = Invoke-PerfAlongOfp $ofpS $model $climbs $descents $ceilings
Check ($alS.steps.Count -eq 1 -and $alS.steps[0].at -eq 'C1' -and $alS.steps[0].from -eq 35000 -and $alS.steps[0].to -eq 37000) 'along: the step at C1 (the fix it starts at; the leg to C2 at FL370)'
$st = $alS.steps[0]; $gwBefore = $st.gw + $st.extra
# (the ceilings' weights at 35,000 ft: 240 t less 640 kg, 300 t less 800 kg)
$tStep = 2000 * (0.04 + 0.01 * ($gwBefore - 239360) / 59840)
Near $st.climb_t $tStep 1e-6 'along: the step''s climb time from the ceilings'
Near $st.extra ($tStep * 4.0 - (Get-PerfCruiseFf $model $gwBefore 35000 0.855 0) * $tStep / 3600) 1e-6 'along: the step''s fuel over the cruise''s'
Near $alS.descent.t (25000 * 0.02 + 2000 * 0.02) 1e-6 'along: from FL370, the 33,000-31,000 ft band''s time a foot above FL350'
Check (@($alS.notes | Where-Object { $_ -match 'band' }).Count -eq 1) 'along: the descent''s estimate noted'
# the levels: the FCOM's 1.30 g altitude at T/C and at the step
$lc = Get-PerfLevelChecks $ofpS $alS
Check ($lc.Count -eq 2 -and $lc[0].what -eq 'T/C' -and $lc[1].what -eq 'step at C1') 'levels: T/C and the step'
Near $lc[0].ceiling (Get-PerfFcomBuffet130Ft ($gwA - $alS.climb.fuel)) 1e-9 'levels: the FCOM''s altitude at the T/C''s weight'

# the Fuel Factor's form
Check ((Format-PerfFactor -0.0205) -eq 'M02') 'factor: -2.05 % is M02'
Check ((Format-PerfFactor -0.0128) -eq 'M01') 'factor: -1.28 % is M01'
Check ((Format-PerfFactor 0.004) -eq 'P00') 'factor: +0.4 % is P00'
Check ((Format-PerfFactor 0.025) -eq 'P03') 'factor: +2.5 % is P03 (half away from zero)'
Check ((Format-PerfFactor -0.025) -eq 'M03') 'factor: -2.5 % is M03'

# the FMC's ECON Mach by LuaJIT (when there is one): 307.8 t at FL350 is M.858
# at CI 200 (phase 1)
if (Test-Path $cmpArgs.LuaJit) {
    $e = Get-PerfFmcEcon @([pscustomobject]@{ kg = 307807.5; ft = 35000.0; headwind = 0.0; isa = -1.3 }) 200
    Near $e[0] 0.858 0.0015 'FMC ECON: M.858 at 307.8 t, FL350, CI 200'
}

Remove-Item "$tmpBase.points.csv", "$tmpBase.raw.csv", "$tmpBase.ofp.json" -ErrorAction SilentlyContinue
if ($fails.Count -gt 0) { Write-Host ('compare offline: {0} of {1} checks failed' -f $fails.Count, $count); exit 1 }
Write-Host ('compare offline: {0} checks passed' -f $count)
