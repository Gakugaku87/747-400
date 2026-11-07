# The performance mode's pieces without X-Plane (tests/flight/perf/perf.ps1):
# the acf's lines, the fuel by tank in the aircraft's load order, the flight
# init, and the WebSocket logger against a stand-in Web API (an HttpListener
# that answers the subscription and sends 25 s of updates, changed values
# only), then the window's flows and the write checks on its rows.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\perf\perf_offline_test.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'perf.ps1')

$fails = New-Object System.Collections.ArrayList
$count = 0
function Check([bool]$Ok, [string]$What) {
    $script:count++
    if (-not $Ok) { [void]$fails.Add($What); Write-Host "FAIL $What" }
}
function Near([double]$A, [double]$B, [double]$Tol, [string]$What) { Check ([math]::Abs($A - $B) -le $Tol) ("$What`: $A, expected $B +- $Tol") }

# the acf's lines (pounds)
$keys = Read-AcfKeys $acfFile
Check ($keys.Contains('_m_empty')) 'acf _m_empty found'
Near ([double]::Parse($keys['_m_empty'].value, $inv) * $LB) 183523.4 0.5 'acf empty weight (kg)'
Near ([double]::Parse($keys['_m_max'].value, $inv) * $LB) 385553.5 0.5 'acf maximum weight (kg)'
Near ([double]::Parse($keys['_m_fuel_max_tot'].value, $inv) * $LB) 173069.1 0.5 'acf fuel capacity (kg)'
Check ($keys['_tank_name/7'].value -eq 'Horizontal stab') 'acf tank 7 the stabilizer'
$stations = New-Object double[] 9
foreach ($i in 0..8) { if ($keys.Contains("_fixed_max/$i")) { $stations[$i] = [double]::Parse($keys["_fixed_max/$i"].value, $inv) * $LB } }
$sumSt = 0.0; foreach ($v in $stations) { $sumSt += $v }
Near $sumSt (194800 * $LB) 0.5 'payload stations (kg)'
# the fuel per thrust (lb/lbf/h in the file, ACF_DIFF.md; the datarefs kg/(N s))
Near ([double]::Parse($keys['_jet_SFC_hicrz'].value, $inv)) 0.535 1e-9 'acf _jet_SFC_hicrz (lb/lbf/h)'
$script:acfSfc = Get-PerfAcfSfc $keys
Check ((@($script:acfSfc.Keys) -join ',') -eq 'takeoff,climb,locrz,hicrz') 'the acf''s fuel per thrust: its four points'
Near $script:acfSfc.takeoff (0.300 / 3600 / 9.80665) 1e-15 'the acf''s takeoff fuel per thrust (kg/(N s))'
Near $script:acfSfc.hicrz 1.51541e-5 1e-9 'the acf''s high cruise fuel per thrust (kg/(N s))'

# the points' gross weights: the FCOM's MTOW for the 109 (p.78), not the acf's
Near $MtowKg 394625 0.01 'MTOW (FCOM p.78, 109)'
Near ($MtowKg * 0.78) 307807.5 0.01 'gross weight at 78 % of the MTOW'
Near $MzfwKg 244939 0.01 'MZFW (FCOM p.78, 109)'
Near $MlwKg 285763 0.01 'MLW (FCOM p.78, 109)'
Check ((183523.4 + $PayloadKg) -le $MzfwKg) 'the empty weight and the typical payload within the MZFW'

# the fuel by tank: the acf's ratios of its capacity
$total = [double]::Parse($keys['_m_fuel_max_tot'].value, $inv) * $LB
$cap = [double[]]@(0..8 | ForEach-Object { if ($keys.Contains("_tank_rat/$_")) { [double]::Parse($keys["_tank_rat/$_"].value, $inv) * $total } else { 0.0 } })
foreach ($case in @(@(77208.3, 'mains only'), @(123475.2, 'reserves full, centre'), @(15000.0, 'light'), @($total, 'full'))) {
    $f = Get-FuelByTank $case[0] $cap
    $s = 0.0; foreach ($v in $f) { $s += $v }
    Near $s $case[0] 0.01 "fuel by tank sums ($($case[1]))"
    foreach ($i in 0..8) { Check ($f[$i] -le $cap[$i] + 0.01) "tank $i within its capacity ($($case[1]))" }
    Near $f[1] $f[4] 0.001 "mains 1 and 4 alike ($($case[1]))"
    Near $f[2] $f[3] 0.001 "mains 2 and 3 alike ($($case[1]))"
}
$f = Get-FuelByTank 77208.3 $cap
Near $f[1] $cap[1] 0.01 'main 1 full at 77 t'
Near $f[0] 0 0.001 'no centre fuel at 77 t'
$f = Get-FuelByTank 123475.2 $cap
Near $f[5] $cap[5] 0.01 'reserve 2 full at 123 t'
Near $f[0] (123475.2 - 2 * $cap[1] - 2 * $cap[2] - 2 * $cap[5]) 0.01 'the centre takes the rest at 123 t'

# the flight init
$pt = [ordered]@{ id = 't'; gw_pct = 78; fl = 350; mach = 0.85; measure_s = 180 }
$init = New-PerfInit $pt (New-Object double[] 9) (Get-FuelByTank 77208.3 $cap)
$json = ConvertTo-Json $init -Depth 30 -Compress
Check ($json.Contains('"clouds":[]')) 'init: no clouds'
Check ($json.Contains('"evolution_over_time_enum":"static"')) 'init: static weather'
Check (@($init.weather.definition.wind).Count -eq 13) 'init: 13 wind layers'
Check ($json.Contains('"payload_weight_in_kilograms":[0,0,0,0,0,0,0,0,0]')) 'init: 9 payload stations'
Near $init.lle_air_start.elevation_in_meters 10668 0.1 'init: FL350 in metres'
Near $init.lle_air_start.speed_in_meters_per_second 252.06 0.02 'init: M.85 true at FL350 ISA (m/s)'
Near (Get-IsaC 35000) -54.34 0.01 'ISA at FL350 (C)'
Near (Get-IsaC 41000) -56.5 0.001 'ISA above the tropopause (C)'

# ---------------------------------------------------------------- the JSON files

# a line read with Get-Content carries PSDrive and PSProvider; ConvertTo-Json at
# -Depth 30 walked those without end (the check run of 2026-11-06), so Save-Json
# writes plain data only
$tmpBase = Join-Path $env:TEMP ('perf_offline_test_' + [guid]::NewGuid().ToString('N'))
$tmpTxt = "$tmpBase.txt"
$tmpJson = "$tmpBase.json"
[IO.File]::WriteAllText($tmpTxt, "first line`r`nsecond line`r`n")
$gc = Get-Content $tmpTxt -TotalCount 1
Check ($null -ne $gc.PSObject.Properties['PSProvider']) 'a Get-Content line carries PSProvider (the case to strip)'
$obj = [ordered]@{ line = $gc; first = (Get-FirstLine $tmpTxt); n = 1.5; i = 3; yes = $true; none = $null
    two = @(1, 2); one = @(7); empty = @(); doubles = (New-Object double[] 2); dict = [ordered]@{ x = 'y' }
    custom = ('{"a":1,"b":[1,2]}' | ConvertFrom-Json); file = (Get-Item $tmpTxt) }
$sw = [Diagnostics.Stopwatch]::StartNew()
Save-Json $tmpJson $obj
Check ($sw.Elapsed.TotalSeconds -lt 5) "Save-Json done in $([math]::Round($sw.Elapsed.TotalSeconds, 2)) s"
$text = [IO.File]::ReadAllText($tmpJson)
Check (-not $text.Contains('PSProvider')) 'Save-Json: no PSProvider in the file'
Check ($text.Length -lt 2000) "Save-Json: a small file ($($text.Length) characters)"
$back = $text | ConvertFrom-Json
Check ($back.line -eq 'first line') 'Save-Json: the Get-Content line as its string'
Check ($back.first -eq 'first line') 'Get-FirstLine: the first line'
Check ($back.file -is [string] -and $back.file.EndsWith([IO.Path]::GetFileName($tmpTxt))) 'Save-Json: an object of another kind as its string (a FileInfo: its path)'
Check ($back.n -eq 1.5 -and $back.i -eq 3 -and $back.yes -eq $true -and $null -eq $back.none) 'Save-Json: numbers, true, null'
Check ((@($back.two) -join ',') -eq '1,2' -and (@($back.doubles) -join ',') -eq '0,0') 'Save-Json: lists'
Check ($text -match '"one":\s*\[\s*7\s*\]' -and $text -match '"empty":\s*\[\s*\]') 'Save-Json: a list of one and an empty list stay lists'
Check ($back.dict.x -eq 'y' -and $back.custom.a -eq 1 -and (@($back.custom.b) -join ',') -eq '1,2') 'Save-Json: dictionaries and custom objects'
Remove-Item $tmpTxt, $tmpJson -ErrorAction SilentlyContinue

# ---------------------------------------------------------------- the cruise suite

# PERF_SIMBRIEF.md phase 1: 3 weights x FL310-390 x M.85-.87 below the FCOM's
# maximum operating altitude (PI.11.1, 1.30 g; B747.68.perf_db.lua max_alt at
# these weights: 42,933, 37,593 and 34,590 ft), the repeat at the end
$lvs = Get-PerfLevels
Check ($lvs.Count -eq 12) "cruise: 12 levels (got $($lvs.Count))"
$pids = @(foreach ($lv in $lvs) { foreach ($m in $lv.machs) { Get-PerfPointId $lv.id $m } })
Check ($pids.Count -eq 34) "cruise: 33 points and the repeat (got $($pids.Count))"
Check (@($pids | Sort-Object -Unique).Count -eq $pids.Count) 'cruise: the points'' ids unique'
Check ((Get-PerfPointId 'crz_078_fl350' 0.85) -eq 'crz_078_fl350_m850' -and (Get-PerfPointId 'x' 0.87) -eq 'x_m870') 'cruise: a point''s id'
Check ($lvs[0].id -eq 'crz_078_fl350' -and $lvs[0].ci_check) 'cruise: first 78 % FL350 with the CI''s Mach'
Check ($lvs[11].id -eq 'rep_078_fl350' -and $lvs[11].repeat_of -eq 'crz_078_fl350_m850' -and @($lvs[11].machs).Count -eq 1) 'cruise: the repeat at the end'
$maxFt = @{ light = 42933; medium = 37593; heavy = 34590 }
foreach ($lv in $lvs) {
    $kind = if ($null -ne $lv.fuel_kg) { 'light' } elseif ($lv.gw_pct -eq 78) { 'medium' } else { 'heavy' }
    Check ($lv.fl * 100 -le $maxFt[$kind]) "cruise: $($lv.id) below the maximum altitude ($($maxFt[$kind]) ft)"
    if ($lv.id -ne 'rep_078_fl350') { Check ((@($lv.machs) -join ',') -eq '0.85,0.86,0.87') "cruise: $($lv.id) M.85-.87" }
}
Check (@($lvs | Where-Object { $null -ne $_.fuel_kg }).Count -eq 5 -and @($lvs | Where-Object { $null -ne $_.fuel_kg -and $_.fuel_kg -ne 15000 }).Count -eq 0) 'cruise: the light weight at 5 levels, 15 t of fuel'
Check (@($lvs | Where-Object { $_.gw_pct -eq 90 }).Count -eq 2) 'cruise: 90 % at FL310 and FL330 only'
Near ((183523.4 + $PayloadKg + $LightFuelKg) / $MtowKg * 100) 60.44 0.01 'cruise: the light weight 60 % of the MTOW'

# -Only: the levels, tests or points listed, in the suite's order
$o1 = Select-PerfOnly $lvs @('crz_l15_fl390')
Check (@($o1).Count -eq 1 -and $o1[0].id -eq 'crz_l15_fl390' -and (@($o1[0].machs) -join ',') -eq '0.85,0.86,0.87') '-Only: a level and its three Machs'
$o2 = Select-PerfOnly $lvs @('crz_l15_fl390,crz_078_fl350 ')
Check ((@($o2 | ForEach-Object { $_.id }) -join ',') -eq 'crz_078_fl350,crz_l15_fl390') '-Only: "a,b" as one string (powershell -File), in the suite''s order'
$o3 = Select-PerfOnly $lvs @('rep_078_fl350', 'crz_l15_fl390')
Check ((@($o3 | ForEach-Object { $_.id }) -join ',') -eq 'crz_l15_fl390,rep_078_fl350') '-Only: two ids, in the suite''s order'
$err = $null
try { [void](Select-PerfOnly $lvs @('crz_l15_fl410')) } catch { $err = $_.Exception.Message }
Check ($null -ne $err -and $err.StartsWith('-Only: not in the suite: crz_l15_fl410 (its ids: crz_078_fl350,')) "-Only: an id not in the suite stops the run ($err)"
$o0 = Select-PerfOnly $lvs @('', ',')
Check (@($o0).Count -eq 12) "-Only: no ids, the whole suite (got $(@($o0).Count))"
$o4 = Select-PerfOnly (Get-PerfClimbTests) @('cel_l15')
Check (@($o4).Count -eq 1 -and $o4[0].kind -eq 'ceiling') '-Only: a climb suite''s test'
$o5 = Select-PerfOnly $points @('chk_090_fl310_m085')
Check (@($o5).Count -eq 1 -and $o5[0].fl -eq 310) '-Only: a check suite''s point'

# ---------------------------------------------------------------- the run's files

# Write-PerfFiles with stand-in results: a cruise run stopped in its second
# level (the first: M.85 measured, M.86 not held, M.87 so not tried), the repeat
$points0 = $points   # the check suite's (dot-sourced with its default suite)
function New-Win([double]$Ff, [double]$Gauge) {
    return [ordered]@{ rows = 180; rows_real_time = 180; ff_fuelmass_kgph = $Ff; ff_gauge_kgph = $Gauge; ff_diff_pct = ($Ff / $Gauge - 1) * 100
        weight = 306922.0; press_alt_ft = 35002.0; mach = 0.8522; tas_kt = 489.8; oat_c = -55.63; isa_dev_c = -1.28; n1_avg_pct = 86.05
        pitch = 2.89; aoa = 3.03; alt_range_ft = 5.0; mach_range = 0.0004; vs_max_abs = 59.0 }
}
$meta0 = [ordered]@{ xplane = [ordered]@{ version = '12.4.4' }; git = [ordered]@{ branch = 'overhaul'; commit = 'abc'; tracked_changes = 0 }; acf = [ordered]@{ sha256 = 'f00' } }
$runDir = "$tmpBase.run"
New-Item -ItemType Directory -Path $runDir | Out-Null
$l1 = [ordered]@{ id = 'crz_078_fl350'; target = $lvs[0]; status = 'done'; checks = [ordered]@{}; request = [ordered]@{ gw_pct = 78.0 }
    ci = [ordered]@{ ci = 200; mach = 0.858; title = 'ACT ECON CRZ'; note = $null }
    points = @([ordered]@{ id = 'crz_078_fl350_m850'; target_mach = 0.85; status = 'done'; window = (New-Win 10389.0 11000.0); settle = [ordered]@{ after_s = 148 }; raw_file = 'raw/crz_078_fl350_m850.csv' },
        [ordered]@{ id = 'crz_078_fl350_m860'; target_mach = 0.86; status = 'hold_unable'; detail = 'last 60 s: Mach .855'; settle = [ordered]@{ after_s = 360 }; raw_file = 'raw/crz_078_fl350_m860.csv' },
        [ordered]@{ id = 'crz_078_fl350_m870'; target_mach = 0.87; status = 'hold_unable'; detail = 'not tried: a slower Mach was not held' }) }
$l2 = [ordered]@{ id = 'crz_078_fl310'; target = $lvs[1]; status = 'aborted'; error = 'no A/P servos'; checks = [ordered]@{}; request = [ordered]@{ gw_pct = 78.0 }
    points = @([ordered]@{ id = 'crz_078_fl310_m850'; target_mach = 0.85; status = 'aborted' }) }
$l12 = [ordered]@{ id = 'rep_078_fl350'; target = $lvs[11]; status = 'done'; checks = [ordered]@{}; request = [ordered]@{ gw_pct = 78.0 }
    points = @([ordered]@{ id = 'rep_078_fl350_m850'; target_mach = 0.85; status = 'done'; window = (New-Win 10449.0 11010.0); settle = [ordered]@{ after_s = 150 }; raw_file = 'raw/rep_078_fl350_m850.csv' }) }
$sum = Write-PerfFiles $runDir 'cruise' @($l1, $l2, $l12) $meta0 $null @() $lvs "$runDir\none.txt" 0 "$runDir\none2.txt" 0
Check ($sum -eq 'points: 2 of 34 done') "files: the summary ($sum)"
$pcl = @(Get-Content "$runDir\points.csv")
Check ($pcl.Count -eq 35) "files: points.csv a row a point (got $($pcl.Count - 1))"
Check ($pcl[1] -match '^crz_078_fl350_m850,A,78,350,0\.85,306922,35002,0\.8522,489\.8,-55\.63,-1\.28,10389\.0,11000\.0,86\.05,2\.89,3\.03,done,raw/crz_078_fl350_m850\.csv$') "files: a measured point's row ($($pcl[1]))"
Check ($pcl[2] -match '^crz_078_fl350_m860,A,78,350,0\.86(,){12}hold_unable,raw/crz_078_fl350_m860\.csv$') "files: a point not held, its 11 values blank ($($pcl[2]))"
Check (@($pcl | ForEach-Object { ($_ -split ',', -1).Count } | Sort-Object -Unique) -join ',' -eq '18') 'files: points.csv 18 columns in every row'
Check ($pcl[4] -match ',aborted,$' -and $pcl[5] -match ',not_run,$') 'files: the stopped level''s point aborted, the next not run'
Check (@($pcl | Where-Object { $_ -match '^crz_l15_fl310_m850,A,,310,' }).Count -eq 1) 'files: a level not run, the light weight''s percentage blank'
Check ($pcl[34] -match '^rep_078_fl350_m850,A,78,350,0\.85,') 'files: the repeat last'
$mdl = [IO.File]::ReadAllText("$runDir\check.md")
Check ($mdl.Contains('CI 200: the economy cruise Mach 0.858 on the VNAV CRZ page ("ACT ECON CRZ") at 78 % and FL350; the Machs 0.85, 0.86, 0.87')) 'files: check.md the CI''s Mach'
Check ($mdl -match 'Repeat \(crz_078_fl350_m850, rep_078_fl350_m850\): fuel weight 10389 and 10449 kg/h, 0\.58 %.*: within') 'files: check.md the repeat'
Check ($mdl.Contains('Points: 2 of 34 done; hold_unable 2, aborted 1, not_run 29')) 'files: check.md the points'' count'
Check ($mdl.Contains('| crz_078_fl350_m850 | done | 306.9 | 35002 | 0.8522 |') -and $mdl.Contains('- crz_078_fl350_m860: last 60 s: Mach .855')) 'files: check.md a level''s points and details'
Check ($mdl.Contains('Error: no A/P servos')) 'files: check.md a stopped level''s error'
$cj = Get-Content -Raw "$runDir\check.json" | ConvertFrom-Json
Check (@($cj.levels).Count -eq 3 -and $cj.repeat.within_1_pct -eq $true) 'files: check.json the levels and the repeat'
# a part run (-Only crz_l15_fl390): its level's points only, no repeat, the ids in check.md
$r5 = [ordered]@{ id = 'crz_l15_fl390'; target = $o1[0]; status = 'done'; checks = [ordered]@{}; request = [ordered]@{ gw_pct = 60.4 }
    points = @([ordered]@{ id = 'crz_l15_fl390_m850'; target_mach = 0.85; status = 'done'; window = (New-Win 8100.0 8110.0); settle = [ordered]@{ after_s = 150 }; raw_file = 'raw/crz_l15_fl390_m850.csv' }) }
$meta5 = [ordered]@{ xplane = $meta0.xplane; git = $meta0.git; acf = $meta0.acf; only = @('crz_l15_fl390') }
$runDir5 = "$tmpBase.run5"; New-Item -ItemType Directory -Path $runDir5 | Out-Null
$sum5 = Write-PerfFiles $runDir5 'cruise' @($r5) $meta5 $null @() $o1 "$runDir\none.txt" 0 "$runDir\none2.txt" 0
Check ($sum5 -eq 'points: 1 of 3 done') "-Only files: the summary ($sum5)"
$pcl5 = @(Get-Content "$runDir5\points.csv")
Check ($pcl5.Count -eq 4 -and $pcl5[1].StartsWith('crz_l15_fl390_m850,A,60.4,390,0.85,306922,') -and $pcl5[3] -match '^crz_l15_fl390_m870,A,60\.4,390,0\.87,(,){11}not_run,$') "-Only files: points.csv the level's three points ($($pcl5[3]))"
$md5 = [IO.File]::ReadAllText("$runDir5\check.md")
Check ($md5.Contains('Only (-Only): crz_l15_fl390') -and $md5.Contains('Repeat: not measured') -and $md5.Contains('Points: 1 of 3 done; not_run 2')) '-Only files: check.md the ids, no repeat, the count'
Check (-not $mdl.Contains('Only (-Only)')) 'files: a whole run''s check.md without the -Only line'
Remove-Item -Recurse -Force $runDir5 -ErrorAction SilentlyContinue
# a check run: plan A with only the fuel flow failing, B with another check failing
$c1 = [ordered]@{ id = 'chk_078_fl350_m085'; target = $points0[0]; status = 'done'; window = (New-Win 10389.0 11000.0); settle = [ordered]@{ after_s = 148 }
    checks = [ordered]@{ readback_payload = [ordered]@{ pass = $true; value = 'x'; limit = 'y' }; fuel_flow_agreement = [ordered]@{ pass = $false; value = '-5.55 %'; limit = '2 %' } } }
$c2 = [ordered]@{ id = 'chk_090_fl310_m085'; target = $points0[1]; status = 'done'; window = (New-Win 12631.0 13406.0); settle = [ordered]@{ after_s = 184 }; checks = [ordered]@{} }
$runDir2 = "$tmpBase.run2"; New-Item -ItemType Directory -Path $runDir2 | Out-Null
Check ((Write-PerfFiles $runDir2 'check' @($c1, $c2) $meta0 $null $points0 @() "$runDir\none.txt" 0 "$runDir\none2.txt" 0) -eq 'plan: A') 'files: a check run, only the fuel flow failing: plan A'
$c2.checks.engines_running = [ordered]@{ pass = $false; value = 'N2 40 %'; limit = '60 %' }
$runDir3 = "$tmpBase.run3"; New-Item -ItemType Directory -Path $runDir3 | Out-Null
Check ((Write-PerfFiles $runDir3 'check' @($c1, $c2) $meta0 $null $points0 @() "$runDir\none.txt" 0 "$runDir\none2.txt" 0) -eq 'plan: B') 'files: a check run, an engine check failing: plan B'
Check ((@(Get-Content "$runDir2\points.csv"))[1] -match '^chk_078_fl350_m085,A,78,350,0\.85,306922,') 'files: a check run''s points.csv'
Remove-Item -Recurse -Force $runDir, $runDir2, $runDir3 -ErrorAction SilentlyContinue

# ---------------------------------------------------------------- the logger

$port = 18000 + (Get-Random -Maximum 900)
$script:XPBase = "http://localhost:$port/api/v3"
# stand-in dataref ids
$script:drefInfo = [ordered]@{}
$names = @{}
$k = 1000
foreach ($c in $colSpec) {
    if (-not $script:drefInfo.Contains($c[1])) {
        $script:drefInfo[$c[1]] = [ordered]@{ id = [long]$k; value_type = 'float' }
        $names[[string]$k] = $c[1]
        $k++
    }
}
$state = [hashtable]::Synchronized(@{ listening = $false; done = $false; error = $null; sub = $null; sent = 0 })
# the fuel per thrust as the aircraft writes it at FL390: the acf's x 1.018
$state.sfc = @{}
foreach ($k in $SfcPoints) { $state.sfc["sim/aircraft/overflow/jet_SFC_$k"] = $script:acfSfc[$k] * 1.018 }
$server = {
    param($prefix, $names, $state)
    $l = $null
    try {
        $l = New-Object Net.HttpListener
        $l.Prefixes.Add($prefix)
        $l.Start()
        $state.listening = $true
        $ctx = $l.GetContext()
        # [NullString]: PowerShell passes $null to a string parameter as ''
        $ws = $ctx.AcceptWebSocketAsync([NullString]::Value).Result.WebSocket
        $none = [Threading.CancellationToken]::None
        $buf = New-Object byte[] 65536
        $r = $ws.ReceiveAsync([ArraySegment[byte]]::new($buf), $none).Result
        $state.sub = [Text.Encoding]::UTF8.GetString($buf, 0, $r.Count)
        $sub = $state.sub | ConvertFrom-Json
        $send = {
            param($text)
            $b = [Text.Encoding]::UTF8.GetBytes($text)
            $ws.SendAsync([ArraySegment[byte]]::new($b), [Net.WebSockets.WebSocketMessageType]::Text, $true, $none).Wait()
        }
        & $send '{"req_id":1,"type":"result","success":true}'
        $inv = [Globalization.CultureInfo]::InvariantCulture
        for ($m = 0; $m -lt 250; $m++) {
            $t = 100 + $m / 10
            $fuel = 80000 - 2.6 * ($t - 100)
            $parts = New-Object System.Collections.ArrayList
            foreach ($d in $sub.params.datarefs) {
                $name = $names[[string]$d.id]
                $v = $null
                if ($state.sfc.ContainsKey($name)) { if ($m -eq 0) { $v = $state.sfc[$name] } }
                else { switch ($name) {
                    'sim/time/total_running_time_sec' { $v = $t }
                    'sim/flightmodel/weight/m_fuel_total' { $v = $fuel }
                    'sim/flightmodel/weight/m_total' { $v = 223523.4 + $fuel }
                    'sim/flightmodel/weight/m_fuel' { $v = @($d.index | ForEach-Object { if ($_ -ge 1 -and $_ -le 4) { $fuel / 4 } else { 0 } }) }
                    'laminar/B747/fuel/totaliser' { $v = @($d.index | ForEach-Object { 1000 + 2.47 * ($t - 100) }) }
                    'sim/cockpit2/engine/indicators/fuel_flow_kg_sec' { if ($m -eq 0) { $v = @(0.65, 0.65, 0.65, 0.65) } }
                    'sim/cockpit2/gauges/indicators/altitude_ft_pilot' { $v = 35000 + 5 * [math]::Sin($t) }
                    'sim/flightmodel/misc/machno' { $v = 0.85 + 0.0005 * [math]::Sin($t) }
                    'sim/flightmodel/position/vh_ind_fpm' { $v = 20 * [math]::Sin($t) }
                    'sim/flightmodel/weight/m_fixed' { if ($m -eq 0) { $v = 40000 } }
                    'sim/time/sim_speed' { if ($m -eq 0) { $v = 1 } }
                    'sim/time/ground_speed' { if ($m -eq 0) { $v = 1 } }
                    'sim/operation/misc/frame_rate_period' { if ($m -eq 0) { $v = 0.025 } }
                    default {
                        if ($m -eq 0) {
                            if ($null -ne $d.index) { $v = @($d.index | ForEach-Object { 0 }) } else { $v = 0 }
                        }
                    }
                } }
                if ($null -eq $v) { continue }
                if ($v -is [array]) { $vt = '[' + ((@($v | ForEach-Object { ([double]$_).ToString('R', $inv) })) -join ',') + ']' }
                else { $vt = ([double]$v).ToString('R', $inv) }
                [void]$parts.Add(('"{0}":{1}' -f $d.id, $vt))
            }
            & $send ('{"type":"dataref_update_values","data":{' + ($parts -join ',') + '}}')
            $state.sent = $state.sent + 1
            Start-Sleep -Milliseconds 20
        }
        $state.done = $true
        Start-Sleep -Seconds 3
        try { $ws.Abort() } catch { }
    } catch {
        $state.error = $_.Exception.ToString()
        $state.done = $true
    } finally {
        if ($null -ne $l) { $l.Stop(); $l.Close() }
    }
}
$sp = [PowerShell]::Create()
[void]$sp.AddScript($server)
[void]$sp.AddArgument("http://localhost:$port/")
[void]$sp.AddArgument($names)
[void]$sp.AddArgument($state)
$sh = $sp.BeginInvoke()
$sw = [Diagnostics.Stopwatch]::StartNew()
while (-not $state.listening -and -not $state.error -and $sw.Elapsed.TotalSeconds -lt 15) { Start-Sleep -Milliseconds 100 }
if ($state.error -or -not $state.listening) { throw "stand-in Web API: $($state.error)" }

$csv = Join-Path $env:TEMP "perf_offline_test_$port.csv"
Start-PerfLogger $csv
$sw = [Diagnostics.Stopwatch]::StartNew()
while (-not $state.done -and $sw.Elapsed.TotalSeconds -lt 30) { Start-Sleep -Milliseconds 200 }
Start-Sleep -Milliseconds 500
$rows = Get-PerfRows
Stop-PerfLogger
[void]$sp.EndInvoke($sh); $sp.Dispose()
if ($state.error) { Check $false "stand-in Web API: $($state.error)" }

$sub = $state.sub | ConvertFrom-Json
Check ($sub.type -eq 'dataref_subscribe_values') 'the subscription request'
$fuelSub = @($sub.params.datarefs | Where-Object { $names[[string]$_.id] -eq 'sim/flightmodel/weight/m_fuel' })
Check ($fuelSub.Count -eq 1 -and (@($fuelSub[0].index) -join ',') -eq '0,1,2,3,4,5,6,7,8') 'm_fuel subscribed once with its 9 indices'
$ffSub = @($sub.params.datarefs | Where-Object { $names[[string]$_.id] -eq 'sim/cockpit2/engine/indicators/fuel_flow_kg_sec' })
Check ($ffSub.Count -eq 1 -and (@($ffSub[0].index) -join ',') -eq '0,1,2,3') 'the FF gauges subscribed with indices 0-3'
$totSub = @($sub.params.datarefs | Where-Object { $names[[string]$_.id] -eq 'laminar/B747/fuel/totaliser' })
Check ($totSub.Count -eq 1 -and (@($totSub[0].index) -join ',') -eq '4') 'FUEL USED subscribed with its index 4 only'
# 25 s of sim time: a row a second, the last one still open
Check ($rows.Count -ge 23 -and $rows.Count -le 25) "rows: $($rows.Count)"
$lines = @(Get-Content $csv)
Check ($lines.Count -eq $rows.Count + 1) 'the CSV has the header and every row'
Check ($lines[0].StartsWith('sim_t,paused,sim_speed')) 'the CSV header'
$r = $rows[5]
Near $r[$script:ix['fuel_kg']] (80000 - 2.6 * (105.45 - 100)) 0.01 'a row: the mean fuel of its second'
Near $r[$script:ix['tank1']] ((80000 - 2.6 * (105.45 - 100)) / 4) 0.01 'a row: an indexed element (main 1)'
Near $r[$script:ix['ff_3']] 0.65 1e-9 'a row: a value held since the first update'
Near $r[$script:ix['payload_kg']] 40000 1e-9 'a row: the payload held'
Check ($r[$script:ix['samples']] -eq 10) "a row: 10 samples (got $($r[$script:ix['samples']]))"
$w = Measure-PerfWindow @($rows[1..($rows.Count - 1)])
Near $w.ff_fuelmass_kgph (2.6 * 3600) 0.5 'window: the burn from the fuel weight (kg/h)'
Near $w.ff_gauge_kgph (2.6 * 3600) 0.01 'window: the gauges sum (kg/h)'
Near $w.ff_diff_pct 0 0.01 'window: the two agree'
Near $r[$script:ix['fuel_used_kg']] (1000 + 2.47 * (105.45 - 100)) 0.01 'a row: a single index (FUEL USED [4])'
Near $w.ff_totaliser_kgph (2.47 * 3600) 0.5 'window: the FUEL USED rate (kg/h)'
Check (-not [double]::IsNaN($w.sim_period_share) -and $w.sim_period_share -gt 0) 'window: the share of the wall time SIM_PERIOD covered'
Near $w.mach 0.85 0.0005 'window: Mach'
Near $w.isa_dev_c (0 - (Get-IsaC $w.press_alt_ft)) 1e-6 'window: ISA deviation from the OAT column'
Near $w.sfc_kgns.hicrz ($script:acfSfc.hicrz * 1.018) 1e-15 'window: the fuel per thrust (high cruise, kg/(N s))'
Near $w.sfc_factor 1.018 1e-9 'window: the fuel per thrust x1.018 the acf''s'
Near $w.sfc_factor_spread 0 1e-9 'window: one factor on the four points'
Check ($w.sfc_corr_off -eq 0) 'window: the correction''s switch at the end (0: on)'
Check ((Format-PerfFlows $w).EndsWith('; fuel per thrust x1.0180 the acf''s')) 'window: the flows'' note with the factor'
$keep = $script:acfSfc; $script:acfSfc = $null
$w0 = Measure-PerfWindow @($rows[1..($rows.Count - 1)])
Check ([double]::IsNaN($w0.sfc_factor) -and -not (Format-PerfFlows $w0).Contains('fuel per thrust')) 'window: no factor without the acf''s'
$script:acfSfc = $keep
Check (Test-Stable $rows 35000 0.85 20) 'stable within 30 ft, M.003 and 100 fpm'
Check (-not (Test-Stable $rows 35100 0.85 20)) 'not stable 100 ft off'
$wr = Measure-PerfWrites $rows
Near $wr.payload_range_kg 0 1e-9 'writes: the payload unchanged'
Near $wr.zfw_range_kg 0 0.05 'writes: the zero fuel weight unchanged'
Near $wr.fuel_step_residual_max_kg 0 0.01 'writes: the fuel falls as the gauges say'
Check ($wr.rows_time_accelerated -eq 0) 'writes: no time acceleration'

# a point's rows to a CSV of their own: the logger's header and numbers
$script:logger = @{ header = $lines[0] }
$pcsv = "$tmpBase.point.csv"
Save-PerfRows $pcsv $rows 2 5
$pl = @(Get-Content $pcsv)
Check ($pl.Count -eq 5 -and $pl[0] -eq $lines[0]) 'a point''s CSV: the header and rows 2-5'
Check ($pl[1] -eq $lines[3] -and $pl[4] -eq $lines[6]) 'a point''s CSV: the logger''s rows as the logger wrote them'
Remove-Item $pcsv -ErrorAction SilentlyContinue
$script:logger = $null

# not level in 6 min: the thrust could not hold the Mach, or unstable
function New-Rows([double]$Mach, [double]$Swing, [int]$At) {
    $out = New-Object System.Collections.ArrayList
    for ($k = 0; $k -lt 80; $k++) {
        $r = New-Object double[] ($script:ix['samples'] + 1)
        $r[$script:ix['sim_t']] = 1000 + $k; $r[$script:ix['alt']] = 35000; $r[$script:ix['vs']] = 0
        $r[$script:ix['mach']] = $Mach + $Swing * [math]::Sin($k / 3.0); $r[$script:ix['fma_at']] = $At
        foreach ($e in 1..4) { $r[$script:ix["n1_$e"]] = 92.5 }
        [void]$out.Add($r)
    }
    return ,$out.ToArray()
}
$u = Get-PerfUnsettled (New-Rows 0.842 0.0005 3) 35000 0.85
Check ($u.status -eq 'hold_unable') "below the Mach, A/T SPD, the level held: hold_unable (got $($u.status))"
Check ($u.detail -match 'Mach 0\.84' -and $u.detail -match 'N1 92\.5') "the detail: $($u.detail)"
Check ((Get-PerfUnsettled (New-Rows 0.85 0.006 3) 35000 0.85).status -eq 'unstable') 'about the Mach but swinging: unstable'
Check ((Get-PerfUnsettled (New-Rows 0.842 0.0005 0) 35000 0.85).status -eq 'unstable') 'below the Mach without A/T SPD: unstable'
Check ((Get-PerfUnsettled (New-Rows 0.842 0.0005 3) 35300 0.85).status -eq 'unstable') 'below the Mach 300 ft off the level: unstable'

# the VNAV CRZ page's speed
$crz = [string[]]@('     ACT ECON CRZ', '', 'FL350', '', '.858              ', '', '1.25    ', '', '', '', '', '', '', '')
Near (Get-PerfCrzMach $crz) 0.858 1e-9 'the CRZ page: ECON SPD .858'
$crz[4] = '310               '
Check ($null -eq (Get-PerfCrzMach $crz)) 'the CRZ page: a CAS, no Mach'
$crz[0] = '      ECON CLB'; $crz[4] = '.858'
Check ($null -eq (Get-PerfCrzMach $crz)) 'not the CRZ page: no Mach'

# the repeat's flows
$rp = Compare-PerfRepeat ([ordered]@{ ff_fuelmass_kgph = 10000.0; ff_gauge_kgph = 10500.0; weight = 306000.0 }) ([ordered]@{ ff_fuelmass_kgph = 10050.0; ff_gauge_kgph = 10500.0; weight = 306100.0 })
Near $rp.diff_pct 0.5 1e-9 'the repeat: 0.5 %'
Check ($rp.within_1_pct) 'the repeat: within 1 %'
$rp = Compare-PerfRepeat ([ordered]@{ ff_fuelmass_kgph = 10000.0; ff_gauge_kgph = 1.0 }) ([ordered]@{ ff_fuelmass_kgph = 10150.0; ff_gauge_kgph = 1.0 })
Check (-not $rp.within_1_pct) 'the repeat: 1.5 % over 1 %'
Check ($null -eq (Compare-PerfRepeat $null ([ordered]@{ ff_fuelmass_kgph = 1.0 }))) 'the repeat: none without both windows'
Remove-Item $csv -ErrorAction SilentlyContinue

# ---------------------------------------------------------------- the climb suite (phase 2)

# the atmosphere: ISA pressure, a CAS's Mach (250 kt at 10,000 ft, the
# climbs' start; 340 kt's M.84 near 27,250 ft, the schedules 250/340/84 and
# 84/340/250) and a Mach's CAS
Near (Get-IsaPressurePa 0) 101325 0.01 'ISA pressure at sea level (Pa)'
Near (Get-IsaPressurePa 35000) 23842 5 'ISA pressure at FL350 (Pa)'
Near (Get-IsaPressurePa (11000 / 0.3048)) 22632 2 'ISA pressure at 11 km (Pa)'
Near (Get-IsaPressurePa 45000) 14748 5 'ISA pressure at FL450 (Pa)'
Near (Get-MachFromCas 250 0) (250 / 661.4786) 1e-6 'a CAS''s Mach at sea level (the speed of sound)'
Near (Get-MachFromCas 250 10000) 0.4522 0.0005 'M of 250 kt at 10,000 ft'
$lo = 20000.0; $hi = 35000.0
for ($i = 0; $i -lt 40; $i++) { $mid = ($lo + $hi) / 2; if ((Get-MachFromCas 340 $mid) -lt 0.84) { $lo = $mid } else { $hi = $mid } }
Near $lo 27250 150 '340 kt reaches M.84 near 27,250 ft'
Near (Get-CasFromMach (250 / 661.4786) 0) 250 1e-6 'a Mach''s CAS at sea level'
Near (Get-CasFromMach (Get-MachFromCas 250 10000) 10000) 250 1e-6 'a Mach''s CAS: the CAS''s Mach back'
Near (Get-MachFromCas (Get-CasFromMach 0.84 30000) 30000) 0.84 1e-9 'a CAS''s Mach: the Mach''s CAS back'
Near (Get-CasFromMach 0.84 35000) 287.1 0.3 'M.84 at FL350 is 287 kt'
# the descent's speed on 84/340/250: M.84 above the crossover, 340 kt below
$sp = Get-PerfDescentSpeed 35000
Check ($sp.mach_phase -and [math]::Abs($sp.cas_kt - 287.1) -lt 0.3) "descent speed: M.84 at FL350 ($($sp.cas_kt) kt)"
$sp = Get-PerfDescentSpeed ($lo + 50)
Check ($sp.mach_phase -and $sp.cas_kt -lt 340) 'descent speed: M.84 just above the crossover'
$sp = Get-PerfDescentSpeed ($lo - 50)
Check (-not $sp.mach_phase -and $sp.cas_kt -eq 340) 'descent speed: 340 kt just below the crossover'
Check (-not (Get-PerfDescentSpeed 15000).mach_phase) 'descent speed: 340 kt at 15,000 ft'

# the tests: three climbs, three descents and three ceilings at the phase 1 weights
$ct = Get-PerfClimbTests
Check ($ct.Count -eq 9) "climb: 9 tests (got $($ct.Count))"
Check (@($ct | ForEach-Object { $_.id } | Sort-Object -Unique).Count -eq 9) 'climb: the ids unique'
Check ((@($ct | ForEach-Object { $_.kind }) -join ',') -eq 'climb,climb,climb,descent,descent,descent,ceiling,ceiling,ceiling') 'climb: the climbs, the descents, then the ceilings'
Check ((@($ct | Where-Object { $_.kind -eq 'climb' } | ForEach-Object { $_.top_ft }) -join ',') -eq '35000,35000,33000') 'climb: the tops FL350, FL350, FL330'
Check ((@($ct | Where-Object { $_.kind -eq 'descent' } | ForEach-Object { $_.from_ft }) -join ',') -eq '35000,35000,33000') 'descent: from FL350, FL350, FL330'
foreach ($t in $ct) {
    $kind = if ($null -ne $t.fuel_kg) { 'light' } elseif ($t.gw_pct -eq 78) { 'medium' } else { 'heavy' }
    if ($t.kind -eq 'climb') { Check ($t.top_ft -le $maxFt[$kind]) "climb: $($t.id)'s top below the maximum altitude ($($maxFt[$kind]) ft)" }
    if ($t.kind -eq 'descent') { Check ($t.from_ft -le $maxFt[$kind]) "descent: $($t.id)'s start below the maximum altitude ($($maxFt[$kind]) ft)" }
}
Check (@($ct | Where-Object { $null -ne $_.fuel_kg -and $_.fuel_kg -eq $LightFuelKg }).Count -eq 3 -and @($ct | Where-Object { $_.gw_pct -eq 78 }).Count -eq 3 -and
    @($ct | Where-Object { $_.gw_pct -eq 90 }).Count -eq 3) 'climb: each weight three times'
Check ($ClimbStartFt -eq 10000 -and $ClimbStartKias -eq 250 -and $ClimbKias -eq 340 -and $ClimbMach -eq 0.84) 'climb: the schedule 250/340/84 from 10,000 ft (the latest B744 OFP)'
Check ($DescentMach -eq 0.84 -and $DescentKias -eq 340 -and $DescentEndFt -eq 10000) 'descent: the schedule 84/340/250 to 10,000 ft (the latest B744 OFP)'
Check ((@($ClimbMarksFt) -join ',') -eq '15000,20000,25000,30000') 'climb: the marks every 5,000 ft'
Check ((@($DescentMarksFt) -join ',') -eq '30000,25000,20000,15000') 'descent: the marks every 5,000 ft down'
Check ($CeilingStartFt -eq 31000 -and $CeilingMach -eq 0.85 -and $CeilingRateFpm -eq 300) 'ceiling: from FL310 at M.85 to 300 fpm'
Check ($CeilingTopFt -le 45100) 'ceiling: the MCP under the maximum operating altitude 45,100 ft (FCOM p.77)'
Check (@($CeilingMarksFt).Count -eq 13 -and $CeilingMarksFt[0] -eq 32000 -and $CeilingMarksFt[12] -eq 44000) 'ceiling: the marks every 1,000 ft, 32,000-44,000'

# a climb's rows (1 s): the altitude by $Alt, the TAS and ground speed, the
# fuel going at $FuelRate kg/s by the weight and by the gauges
function New-ClimbRows([int]$N, [scriptblock]$Alt, [double]$Tas = 250.0, [double]$FuelRate = 3.0) {
    $out = New-Object System.Collections.ArrayList
    for ($k = 0; $k -lt $N; $k++) {
        $r = New-Object double[] ($script:ix['samples'] + 1)
        $t = [double]$k
        $r[$script:ix['sim_t']] = 5000 + $t
        $r[$script:ix['press_alt_ft']] = & $Alt $t
        $r[$script:ix['alt']] = $r[$script:ix['press_alt_ft']]
        $r[$script:ix['tas_ms']] = $Tas; $r[$script:ix['gs_ms']] = $Tas
        $r[$script:ix['fuel_kg']] = 100000 - $FuelRate * $t
        $r[$script:ix['weight']] = 300000 - $FuelRate * $t
        foreach ($e in 1..4) { $r[$script:ix["ff_$e"]] = $FuelRate / 4; $r[$script:ix["n1_$e"]] = 95.0 }
        $r[$script:ix['sim_speed']] = 1; $r[$script:ix['ground_speed_x']] = 1
        $r[$script:ix['thrlim']] = 2; $r[$script:ix['ias']] = 300; $r[$script:ix['mach']] = 0.78; $r[$script:ix['vminm']] = 230
        [void]$out.Add($r)
    }
    return ,$out.ToArray()
}

# the marks: 1,950 fpm from 10,000 ft, the crossings between rows
$rowsC = New-ClimbRows 820 { param($t) [math]::Min(35000.0, 10000 + 32.5 * $t) }
$mc = Measure-PerfClimb $rowsC 0 $ClimbMarksFt 35000
Check ($mc.marks.Count -eq 6 -and $mc.top_reached) "climb marks: the start, 4 marks and the top (got $($mc.marks.Count))"
Check ((@($mc.marks | ForEach-Object { $_.mark }) -join ',') -eq 'start,15000,20000,25000,30000,top 35000') 'climb marks: their names'
Near $mc.marks[0].t_s 0 1e-9 'climb marks: the start at 0 s'
Near $mc.marks[1].t_s (5000 / 32.5) 0.001 'climb marks: 15,000 ft between rows (153.85 s)'
Near $mc.marks[1].fuel_used_kg (3.0 * 5000 / 32.5) 0.01 'climb marks: the fuel used by the weight'
Near $mc.marks[1].ff_gauge_used_kg (3.0 * 5000 / 32.5) 0.01 'climb marks: the gauges'' integral'
Near $mc.marks[1].dist_air_nm (250 * 5000 / 32.5 / 1852) 0.0001 'climb marks: the air distance (NM)'
Near $mc.marks[1].dist_gnd_nm $mc.marks[1].dist_air_nm 1e-9 'climb marks: the ground distance in still air'
Near $mc.marks[1].press_alt_ft 15000 0.001 'climb marks: the mark''s altitude'
Near $mc.marks[2].seg_vs_fpm 1950 0.01 'climb marks: the segment''s climb rate'
Near $mc.marks[5].press_alt_ft (35000 - $ClimbTopMarginFt) 0.001 'climb marks: the top''s mark 30 ft below it'
Near $mc.marks[5].t_s ((25000 - $ClimbTopMarginFt) / 32.5) 0.001 'climb marks: the top''s time'
Near $mc.marks[5].gw_kg (300000 - 3.0 * (25000 - $ClimbTopMarginFt) / 32.5) 0.01 'climb marks: the weight there'
Check ($mc.rows_real_time -eq $mc.rows_to_end -and $mc.rows_to_end -eq 770) "climb marks: 770 rows to the top, all in real time (got $($mc.rows_to_end), $($mc.rows_real_time))"
Check ($mc.thrlim_clb_only) "climb marks: the thrust limit CLB ($($mc.thrlim_codes))"
$rowsC[100][$script:ix['thrlim']] = 3; $rowsC[101][$script:ix['sim_speed']] = 2
$mc2 = Measure-PerfClimb $rowsC 0 $ClimbMarksFt 35000
Check (-not $mc2.thrlim_clb_only -and $mc2.thrlim_codes -match '3: 1 rows') "climb marks: a row in CRZ ($($mc2.thrlim_codes))"
Check ($mc2.rows_real_time -eq 769) 'climb marks: a row time-accelerated'
$rowsC[100][$script:ix['thrlim']] = 2; $rowsC[101][$script:ix['sim_speed']] = 1
$mc3 = Measure-PerfClimb @($rowsC[0..400]) 0 $ClimbMarksFt 35000
Check ($mc3.marks.Count -eq 3 -and -not $mc3.top_reached) "climb marks: cut short, the marks reached only (got $($mc3.marks.Count))"
$mc4 = Measure-PerfClimb $rowsC 200 $ClimbMarksFt 35000
Check ($mc4.marks[1].mark -eq '20000') 'climb marks: from a later row, the marks below its altitude left out'

# a descent's marks: 2,470 fpm down from 35,000 ft, the crossings between rows
$rowsD = New-ClimbRows 700 { param($t) [math]::Max(10000.0, 35000 - 2470 / 60 * $t) }
$md = Measure-PerfClimb $rowsD 0 $DescentMarksFt $DescentEndFt -1
Check ($md.marks.Count -eq 6 -and $md.top_reached) "descent marks: the start, 4 marks and the bottom (got $($md.marks.Count))"
Check ((@($md.marks | ForEach-Object { $_.mark }) -join ',') -eq 'start,30000,25000,20000,15000,bottom 10000') 'descent marks: their names'
Near $md.marks[1].t_s (5000 / (2470 / 60)) 0.001 'descent marks: 30,000 ft between rows (121.46 s)'
Near $md.marks[1].press_alt_ft 30000 0.001 'descent marks: the mark''s altitude'
Near $md.marks[2].seg_vs_fpm -2470 0.01 'descent marks: the segment''s rate, down'
Near $md.marks[5].press_alt_ft ($DescentEndFt + $ClimbTopMarginFt) 0.001 'descent marks: the bottom''s mark 30 ft above 10,000 ft'
Near $md.marks[5].t_s ((25000 - $ClimbTopMarginFt) / (2470 / 60)) 0.001 'descent marks: the bottom''s time'
Near $md.marks[5].fuel_used_kg (3.0 * (25000 - $ClimbTopMarginFt) / (2470 / 60)) 0.01 'descent marks: the fuel used there'
$md2 = Measure-PerfClimb $rowsD 200 $DescentMarksFt $DescentEndFt -1
Check ($md2.marks[1].mark -eq '25000') 'descent marks: from a later row, the marks above its altitude left out'
$md3 = Measure-PerfClimb @($rowsD[0..300]) 0 $DescentMarksFt $DescentEndFt -1
Check ($md3.marks.Count -eq 3 -and -not $md3.top_reached) "descent marks: cut short, the marks reached only (got $($md3.marks.Count))"

# the ceiling: 40 s level, then a climb from 1,500 fpm falling to 0 in 600 s
# with ALT HOLD's swing (4 ft, 10.5 s: 144 fpm); 300 fpm at 520 s, 38,200 ft
# (a 60 s window's mean 6.25 ft lower)
$alt = { param($t) if ($t -lt 40) { 31000.0 } else { $u = $t - 40; 31000 + 25 * ($u - $u * $u / 1200) + 4 * [math]::Sin(2 * [math]::PI * $t / 10.5) } }
$rowsK = New-ClimbRows 600 $alt
$rk = Get-PerfClimbRates $rowsK 0 60
Check ($rk.Count -eq 541) "ceiling: a rate a window (got $($rk.Count))"
Near $rk[200].rate_fpm (1500 * (1 - (200 + 29.5 - 40) / 600)) 3 'ceiling: a window''s rate (the swing averaged out)'
$ck = Get-PerfCeiling $rowsK 0 $CeilingRateFpm $CeilingWinS $CeilingArmFpm $CeilingHoldS
Check ($ck.found -and $ck.armed) 'ceiling: found'
Near $ck.ceiling_ft 38193.75 10 'ceiling: the altitude where the rate crossed 300 fpm'
Near $ck.t_s 520 1 'ceiling: its time'
Near $ck.max_rate_fpm (1500 * (1 - 29.5 / 600)) 3 'ceiling: the most climb rate (the first window all in the climb)'
$ckEarly = Get-PerfCeiling @($rowsK[0..554]) 0 $CeilingRateFpm $CeilingWinS $CeilingArmFpm $CeilingHoldS
Check (-not $ckEarly.found -and $ckEarly.armed) 'ceiling: not yet, under 300 fpm for less than 10 s'
$rowsW = New-ClimbRows 300 { param($t) 31000 + 400 / 60 * $t }
$ckW = Get-PerfCeiling $rowsW 0 $CeilingRateFpm $CeilingWinS $CeilingArmFpm $CeilingHoldS
Check (-not $ckW.found -and -not $ckW.armed) 'ceiling: never 600 fpm, never armed'
Near $ckW.max_rate_fpm 400 1 'ceiling: never armed, its most rate'
$atK = (Measure-PerfClimb $rowsK 0 @($ck.ceiling_ft) $null).marks[1]
Near $atK.press_alt_ft $ck.ceiling_ft 0.01 'ceiling: the mark at the ceiling'

# the climb suite's files: a climb done, one stopped, a descent done, a
# ceiling done, one at the top, four not run
$runDir4 = "$tmpBase.run4"; New-Item -ItemType Directory -Path $runDir4 | Out-Null
$rc1 = [ordered]@{ id = 'clb_l15'; kind = 'climb'; target = $ct[0]; status = 'done'; request = [ordered]@{ gw_kg = 238523.4; gw_pct = 60.44 }
    checks = [ordered]@{ climb_thrust_clb = [ordered]@{ pass = $true; value = '2: 770 rows'; limit = 'CLB' } }; climb = $mc
    crossover = [ordered]@{ press_alt_ft = 27260.0; ias_kt = 340.2; mach = 0.8401 }; raw_file = 'raw/clb_l15.csv' }
$rc2 = [ordered]@{ id = 'clb_078'; kind = 'climb'; target = $ct[1]; status = 'aborted'; error = 'no A/P servos'; checks = [ordered]@{}
    request = [ordered]@{ gw_kg = 307807.5; gw_pct = 78.0 }; raw_file = 'raw/clb_078.csv' }
$rd1 = [ordered]@{ id = 'des_l15'; kind = 'descent'; target = $ct[3]; status = 'done'; checks = [ordered]@{}; request = [ordered]@{ gw_kg = 238523.4; gw_pct = 60.44 }
    climb = $md; speed = [ordered]@{ ias_from_ft = 31480.0; cas_from_ft = 27250.0; dial_writes = 40 }; raw_file = 'raw/des_l15.csv' }
$rk1 = [ordered]@{ id = 'cel_l15'; kind = 'ceiling'; target = $ct[6]; status = 'done'; checks = [ordered]@{}; request = [ordered]@{ gw_kg = 238523.4; gw_pct = 60.44 }
    ceiling = $ck; climb = (Measure-PerfClimb $rowsK 0 $CeilingMarksFt $null); at_ceiling = $atK; raw_file = 'raw/cel_l15.csv' }
$rk2 = [ordered]@{ id = 'cel_078'; kind = 'ceiling'; target = $ct[7]; status = 'top'; checks = [ordered]@{}; request = [ordered]@{ gw_kg = 307807.5; gw_pct = 78.0 }
    ceiling = $ckW; climb = (Measure-PerfClimb $rowsW 0 $CeilingMarksFt $null); at_ceiling = $null; raw_file = 'raw/cel_078.csv' }
$sum = Write-PerfClimbFiles $runDir4 @($rc1, $rc2, $rd1, $rk1, $rk2) $meta0 $null $ct "$runDir4\none.txt" 0 "$runDir4\none2.txt" 0
Check ($sum -eq 'tests: 3 of 9 done') "climb files: the summary ($sum)"
$cll = @(Get-Content "$runDir4\climb.csv")
Check ($cll[0] -eq 'test_id,kind,plan,target_gw_pct,gw_start_kg,mark,press_alt_ft,t_s,fuel_used_kg,ff_gauge_used_kg,dist_air_nm,dist_gnd_nm,gw_kg,ias_kt,mach,seg_vs_fpm,n1_avg_pct,thrlim,status,raw_file') 'climb files: climb.csv''s header'
Check (@($cll | ForEach-Object { ($_ -split ',', -1).Count } | Sort-Object -Unique) -join ',' -eq '20') 'climb files: climb.csv 20 columns in every row'
Check (@($cll | Where-Object { $_ -match '^clb_l15,' }).Count -eq 6) 'climb files: a climb''s six marks'
Check ($cll[2] -match '^clb_l15,climb,A,60\.4,238523,15000,15000,153\.8,461\.5,461\.5,20\.77,20\.77,299538,300\.0,0\.7800,1950,95\.00,2,done,raw/clb_l15\.csv$') "climb files: a mark's row ($($cll[2]))"
Check ($cll[1] -match '^clb_l15,climb,A,60\.4,238523,start,10000,0\.0,0\.0,0\.0,0\.00,0\.00,300000,300\.0,0\.7800,,95\.00,2,done,') "climb files: the start's row, its rate blank ($($cll[1]))"
Check (@($cll | Where-Object { $_ -match '^clb_078,climb,A,78,307808,(,){13}aborted,raw/clb_078\.csv$' }).Count -eq 1) 'climb files: a stopped climb, its values blank'
Check (@($cll | Where-Object { $_ -match '^clb_090,climb,A,90,(,){14}not_run,$' }).Count -eq 1) 'climb files: a climb not run'
Check (@($cll | Where-Object { $_ -match '^cel_l15,ceiling,' }).Count -eq 8) 'climb files: a ceiling''s marks to 38,000 ft'
Check (@($cll | Where-Object { $_ -match '^des_l15,descent,' }).Count -eq 6) 'climb files: a descent''s six marks'
Check (@($cll | Where-Object { $_ -match '^des_l15,descent,A,60\.4,238523,30000,30000,121\.5,364\.4,364\.4,16\.40,16\.40,299636,300\.0,0\.7800,-2470,95\.00,2,done,raw/des_l15\.csv$' }).Count -eq 1) 'climb files: a descent mark''s row, its rate down'
Check (@($cll | Where-Object { $_ -match '^des_0[79][80],descent,A,[79][80],(,){14}not_run,$' }).Count -eq 2) 'climb files: two descents not run'
$ccl = @(Get-Content "$runDir4\ceiling.csv")
Check ($ccl.Count -eq 4 -and $ccl[0] -eq 'test_id,plan,target_gw_pct,gw_start_kg,ceiling_ft,t_s,fuel_used_kg,dist_air_nm,gw_kg,mach,ias_kt,vminm_kt,max_rate_fpm,status,raw_file') 'climb files: ceiling.csv a row a ceiling'
Check (@($ccl | ForEach-Object { ($_ -split ',', -1).Count } | Sort-Object -Unique) -join ',' -eq '15') 'climb files: ceiling.csv 15 columns in every row'
Check ($ccl[1] -match '^cel_l15,A,60\.4,238523,3819[0-9],5[12][0-9]\.[0-9],15[0-9]{2}\.[0-9],[0-9]+\.[0-9]{2},29[0-9]{4},0\.7800,300\.0,230\.0,142[0-9],done,raw/cel_l15\.csv$') "climb files: a ceiling's row ($($ccl[1]))"
Check ($ccl[2] -match '^cel_078,A,78,307808,(,){8}400,top,raw/cel_078\.csv$') "climb files: a ceiling at the top, its most rate ($($ccl[2]))"
Check ($ccl[3] -match '^cel_090,A,90,(,){10}not_run,$') "climb files: a ceiling not run ($($ccl[3]))"
$mdc = [IO.File]::ReadAllText("$runDir4\check.md")
Check ($mdc.Contains('| climb | status | start t | top ft | time s | fuel kg | gauges kg | air NM | ground NM | M0.84 at ft |')) 'climb files: check.md the climbs'' table''s head'
Check ($mdc.Contains('| clb_l15 | done | 300.0 | 35000 | 768 | 2305 | 2305 | 103.7 | 103.7 | 27260 |')) 'climb files: check.md the climbs'' table'
Check ($mdc.Contains('| des_l15 | done | 300.0 | 35000 | 607 | 1820 | 1820 | 81.9 | 81.9 | 31480 | 27250 |')) 'climb files: check.md the descents'' table'
Check ($mdc.Contains('| des_090 | not_run | | 33000 | | | | | | | |')) 'climb files: check.md a descent not run'
Check ($mdc -match '\| cel_l15 \| done \| 238\.5 \| 3819[0-9] \|') 'climb files: check.md the ceilings'' table'
Check ($mdc.Contains('Tests: 3 of 9 done; aborted 1, not_run 4, top 1')) 'climb files: check.md the tests'' count'
Check ($mdc.Contains('the schedule 84/340/250') -and $mdc.Contains('the schedule 250/340/84')) 'climb files: check.md the schedules'
Check ($mdc.Contains('| top 35000 | 34970 | 768 |') -and $mdc.Contains('Error: no A/P servos')) 'climb files: check.md a climb''s marks and a stopped one''s error'
$cjc = Get-Content -Raw "$runDir4\check.json" | ConvertFrom-Json
Check (@($cjc.tests).Count -eq 5 -and $cjc.suite -eq 'climb') 'climb files: check.json the tests'
Remove-Item -Recurse -Force $runDir4 -ErrorAction SilentlyContinue

if ($fails.Count -gt 0) { throw ("{0} of {1} checks failed" -f $fails.Count, $count) }
Write-Host ("perf offline: {0} checks passed" -f $count)
