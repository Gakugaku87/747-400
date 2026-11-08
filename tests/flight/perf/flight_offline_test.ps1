# X-Plane-free tests of flight_report.ps1 and flight_log.ps1 (PERF_SIMBRIEF.md
# phase 4; TESTING.md 4.7): the distance, the OFP's factor, a made-up flight
# east along the equator against a made-up OFP (takeoff, touchdown, each
# fix's closest approach, a fix off the track, the phases, the trip, the
# gauges, time acceleration, the proposal), the report's files, the end of a
# flight. No run folder is read.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\perf\flight_offline_test.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flight_log.ps1')
$fails = New-Object System.Collections.ArrayList
$count = 0
function Check([bool]$Ok, [string]$What) { $script:count++; if (-not $Ok) { [void]$fails.Add($What); Write-Host "FAIL $What" } }
function Near([double]$A, [double]$B, [double]$Tol, [string]$What) { Check ([math]::Abs($A - $B) -le $Tol) ('{0} (got {1}, want {2} +- {3})' -f $What, $A, $B, $Tol) }
$tmpBase = Join-Path $env:TEMP ('flight_offline_test_' + [guid]::NewGuid().ToString('N'))

# the distance (a minute of arc on the equator is 1.0001 NM at 3440.065 NM)
Near (Get-GcNm 0 0 0 1) 60.0405 0.001 'distance: a degree of longitude on the equator'
Near (Get-GcNm 10 20 10 20) 0 1e-9 'distance: none'
Near (Get-GcNm 0 0 1 0) 60.0405 0.001 'distance: a degree of latitude'
# the OFP's factor
Near (Get-OfpFactor '1') 1.0 1e-12 'factor: 1 (P00)'
Near (Get-OfpFactor '0.99') 0.99 1e-12 'factor: a multiplier'
Near (Get-OfpFactor 'M01') 0.99 1e-12 'factor: M01'
Near (Get-OfpFactor 'P02') 1.02 1e-12 'factor: P02'
Near (Get-OfpFactor '') 1.0 1e-12 'factor: none, 1'

# a made-up OFP east along the equator from 0 E to 10 E: its fixes every
# degree or so (one, OFF, 20 NM north of the track), T/C at 2 E, T/D at 8 E;
# the plan 3 kg/s and 0.0025 degrees a second (about 540 kt), its trip
# 12,120 kg in 4,000 s
function New-TestFix($Ident, $Stage, $Lat, $Lon, $Alt) {
    $t = $Lon / 0.0025
    return [ordered]@{ ident = $Ident; stage = $Stage; pos_lat = "$Lat"; pos_long = "$Lon"; altitude_feet = "$Alt"; distance = '60'; mach_thousandths = '0.85'
        true_airspeed = '490'; groundspeed = '540'; wind_component = '50'; oat_isa_dev = '0'; time_leg = '400'; time_total = "$t"; fuel_leg = '1212'
        fuel_totalused = ('{0}' -f (3.03 * $t)); fuel_plan_onboard = ('{0}' -f (60000 - 3.03 * $t)) }
}
$fixes = @((New-TestFix 'F1' 'CLB' 0 1 20000), (New-TestFix 'TOC' 'CLB' 0 2 35000), (New-TestFix 'C1' 'CRZ' 0 4 35000), (New-TestFix 'OFF' 'CRZ' 0.3333 5 35000),
    (New-TestFix 'C2' 'CRZ' 0 6 35000), (New-TestFix 'TOD' 'CRZ' 0 8 35000), (New-TestFix 'D1' 'DSC' 0 9 15000), (New-TestFix 'BBBB' 'DSC' 0 10 0))
function New-TestOfpJson([double]$Trip, [string]$FuelFact) {
    return (ConvertTo-Json ([ordered]@{ params = [ordered]@{ time_generated = '1' }; origin = [ordered]@{ icao_code = 'AAAA' }; destination = [ordered]@{ icao_code = 'BBBB' }
        aircraft = [ordered]@{ base_type = 'B744'; is_custom = '1'; fuelfact = $FuelFact; name = 'B747-400 PW'; reg = 'JA0000' }
        general = [ordered]@{ costindex = '200'; climb_profile = '250/340/84'; descent_profile = '84/340/250'; cruise_profile = 'CI 200'; stepclimb_string = 'AAAA/0350'; initial_altitude = '35000'; air_distance = '600' }
        weights = [ordered]@{ est_zfw = '223500'; est_tow = '283500'; est_ldw = '271380' }; fuel = [ordered]@{ enroute_burn = "$Trip"; plan_takeoff = '60000' }
        times = [ordered]@{ est_time_enroute = '4000' }; navlog = [ordered]@{ fix = $fixes } }) -Depth 10)
}
# the flight: 60 s on the ground (1 kg/s), takeoff at row 60 (0 E, 80 m/s),
# then 0.0025 degrees and 3 kg/s a second to the touchdown at 10 E (row
# 4060), the roll and 200 s standing; X-Plane's 4x time acceleration for 50 s
# in the cruise when $Accel
function Write-TestFlightCsv([string]$Path, [switch]$Accel) {
    $cols = @('sim_t', 'lat', 'lon', 'press_alt_ft', 'alt', 'fuel_kg', 'weight', 'payload_kg', 'gs_ms', 'tas_ms', 'mach', 'on_ground', 'paused', 'sim_speed',
        'ground_speed_x', 'ff_1', 'ff_2', 'ff_3', 'ff_4', 'fuel_used_kg', 'oat_c', 'vs', 'wall_s', 'samples')
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add($cols -join ',')
    for ($k = 0; $k -le 4300; $k++) {
        $air = $k -ge 60 -and $k -lt 4060
        # (the fuel: 60,000 kg at takeoff, 48,000 kg at the touchdown)
        $fuel = if ($k -le 60) { 60060.0 - $k } elseif ($k -le 4060) { 60000.0 - 3 * ($k - 60) } else { 48000.0 - 0.5 * ($k - 4060) }
        if ($k -lt 60) { $lon = -0.001 * (60 - $k); $gs = 10.0 }
        elseif ($air) { $lon = 0.0025 * ($k - 60); $gs = 80.0 }
        else { $lon = 10.0 + 0.0001 * [math]::Min(150, $k - 4060); $gs = [math]::Max(0.0, 60 - 0.5 * ($k - 4060)) }
        $tasMs = if ($air) { 250.0 } else { $gs }
        $gsMs = if ($air) { 278.0 } else { $gs }
        $alt = if ($air) { [math]::Min(35000.0, 50 * ($k - 60)) } else { 0.0 }
        $acc = if ($Accel -and $k -ge 2000 -and $k -lt 2050) { 4 } else { 1 }
        $vals = @((1000 + $k), 0.0, $lon, $alt, $alt, $fuel, (223500 + $fuel), 40000, $gsMs, $tasMs, 0.85, $(if ($air) { 0 } else { 1 }), 0, $acc, 1,
            0.75, 0.75, 0.75, 0.75, 0, -50, 0, $k, 10)
        [void]$lines.Add((@($vals | ForEach-Object { ([double]$_).ToString('R', $inv) }) -join ','))
    }
    [IO.File]::WriteAllLines($Path, [string[]]$lines, $utf8)
}
$runDir = "$tmpBase.run"
New-Item -ItemType Directory -Force -Path (Join-Path $runDir 'raw') | Out-Null
[IO.File]::WriteAllText((Join-Path $runDir 'ofp.json'), (New-TestOfpJson 12120 '0.99'), $utf8)
Write-TestFlightCsv (Join-Path $runDir 'raw\flight_01.csv')
$ofp = Read-PerfOfp (Join-Path $runDir 'ofp.json')
Check ($ofp.legs.Count -eq 8 -and $ofp.legs[3].lat -gt 0.3 -and $ofp.legs[2].lon -eq 4) 'OFP: the fixes with their positions'
$tr = Read-FlightTrack @((Join-Path $runDir 'raw\flight_01.csv'))
Check ($tr.n -eq 4301) "track: every row (got $($tr.n))"
$tl = Get-FlightTakeoffLanding $tr
Check ($tl.takeoff -eq 60 -and $tl.touchdown -eq 4060) "track: takeoff at row 60, touchdown at 4060 (got $($tl.takeoff), $($tl.touchdown))"
$c = Get-FlightCompare $ofp $tr 5.0
Check $c.ok 'compare: done'
Near $c.burn 12000 1e-6 'compare: the burn takeoff to touchdown (3 kg/s for 4,000 s)'
Near $c.trip_err (12000 / 12120 - 1) 1e-12 'compare: the trip''s error'
Near $c.flight_s 4000 1e-9 'compare: the flight time'
Near $c.takeoff.zfw 223500 1e-6 'compare: the zero fuel weight at takeoff'
Near $c.burn_gauges 12000 1e-6 'compare: the FF gauges'' integral'
Check ($c.accel_rows -eq 0) 'compare: no time acceleration'
$f1 = @($c.fixes | Where-Object { $_.ident -eq 'F1' })[0]
Check $f1.passed 'fix: F1 passed'
Near $f1.t 400 0.6 'fix: F1 at 400 s from takeoff'
Near $f1.used 1200 2 'fix: F1''s fuel used'
Near $f1.plan_used 1212 1e-6 'fix: F1''s plan'
$off = @($c.fixes | Where-Object { $_.ident -eq 'OFF' })[0]
Check (-not $off.passed) 'fix: OFF, 20 NM off the track, not passed'
Near $off.dist_nm 20.01 0.05 'fix: OFF''s closest approach'
$c2 = @($c.fixes | Where-Object { $_.ident -eq 'C2' })[0]
Check $c2.passed 'fix: the next fix after one not passed'
Near $c2.t 2400 0.6 'fix: C2 at 2,400 s'
$dest = $c.fixes[$c.fixes.Count - 1]
Check ($dest.ident -eq 'BBBB' -and $dest.t -eq 4000) 'fix: the destination at the touchdown'
Near $c.phases.climb.flown 2400 2 'phases: the climb to the plan''s T/C (800 s)'
Near $c.phases.cruise.flown 7200 2 'phases: the cruise T/C to T/D (2,400 s)'
Near $c.phases.descent.flown 2400 2 'phases: the descent T/D to touchdown'
Near ($c.phases.climb.plan + $c.phases.cruise.plan + $c.phases.descent.plan) 12120 1e-6 'phases: the plan''s add up to its trip'
Near $c.wind_plan_kt 50 1e-9 'wind: the plan''s cruise wind'
Near $c.wind_flown_kt ((278 - 250) * 1.943844) 1e-6 'wind: GS - TAS'
# with time acceleration
Write-TestFlightCsv "$tmpBase.acc.csv" -Accel
$ca = Get-FlightCompare $ofp (Read-FlightTrack @("$tmpBase.acc.csv")) 5.0
Check ($ca.accel_rows -eq 50) "compare: 50 rows of time acceleration (got $($ca.accel_rows))"
# the proposal past 2 %: the plan 11,500 kg at M01 (0.99)
$pr = Get-FlightFactorProposal $ofp (12000 / 11500 - 1)
Near $pr.proposed (0.99 * 12000 / 11500) 1e-12 'proposal: the factor times flown / planned'
Check ($pr.current_text -eq 'M01' -and $pr.proposed_text -eq 'P03') "proposal: M01 to P03 (got $($pr.current_text), $($pr.proposed_text))"

# the run's files
$cr = Invoke-FlightReport $runDir
Check ($cr.ok -and (Test-Path (Join-Path $runDir 'report.md')) -and (Test-Path (Join-Path $runDir 'compare.json'))) 'report: report.md and compare.json'
$rep = [IO.File]::ReadAllText((Join-Path $runDir 'report.md'), [Text.Encoding]::UTF8)
Check ($rep.Contains('12,120') -and $rep.Contains('12,000') -and $rep.Contains('-1.0 %')) 'report: the trip, planned and flown, and its error'
Check ($rep -match '\| F1 \| CLB \| 0\.0 \| 0:07 \| 0:07 \|') 'report: a fix''s row'
Check ($rep -match '\| OFF \| CRZ \| [^|]*20\.0') 'report: the fix not passed, its distance'
[IO.File]::WriteAllText((Join-Path $runDir 'ofp.json'), (New-TestOfpJson 11500 '0.99'), $utf8)
$cr2 = Invoke-FlightReport $runDir
$rep2 = [IO.File]::ReadAllText((Join-Path $runDir 'report.md'), [Text.Encoding]::UTF8)
Check ($rep2.Contains('+4.3 %') -and $rep2.Contains('P03')) 'report: past 2 %, the error and the proposed factor'

# the end of a flight: airborne for 60 rows, then still on the ground for 120
$ixT = @{ on_ground = 0; gs_ms = 1 }
function New-TestRows([int[]]$Ground, [double[]]$Gs) { $r = New-Object System.Collections.ArrayList; for ($k = 0; $k -lt $Ground.Count; $k++) { [void]$r.Add([double[]]@($Ground[$k], $Gs[$k])) }; return ,$r.ToArray() }
$ab = $false
$rows = New-TestRows (@(1) * 300) (@(5.0) * 300)
Check (-not (Test-FlightEnded $rows $ixT ([ref]$ab)) -and -not $ab) 'end: never airborne, not ended'
$g = @(1) * 50 + @(0) * 100 + @(1) * 150; $s = @(80.0) * 150 + @(20.0) * 30 + @(0.0) * 120
$ab = $false
Check (Test-FlightEnded (New-TestRows $g $s) $ixT ([ref]$ab)) 'end: flown, then still for 120 rows'
Check $ab 'end: airborne noted'
$s2 = @(80.0) * 150 + @(20.0) * 40 + @(0.0) * 110
$ab = $false
Check (-not (Test-FlightEnded (New-TestRows $g $s2) $ixT ([ref]$ab))) 'end: still for 110 rows only, not ended'
$ab = $true
Check (Test-FlightEnded (New-TestRows (@(1) * 130) (@(0.0) * 130)) $ixT ([ref]$ab)) 'end: airborne in an earlier part, still now'
$g3 = @(1) * 50 + @(0) * 40 + @(1) * 210
$ab = $false
Check (-not (Test-FlightEnded (New-TestRows $g3 (@(0.0) * 300)) $ixT ([ref]$ab))) 'end: 40 rows off the ground only (a hop), not ended'

Remove-Item -Recurse -Force $runDir, "$tmpBase.acc.csv" -ErrorAction SilentlyContinue
if ($fails.Count -gt 0) { Write-Host ('flight offline: {0} of {1} checks failed' -f $fails.Count, $count); exit 1 }
Write-Host ('flight offline: {0} checks passed' -f $count)
