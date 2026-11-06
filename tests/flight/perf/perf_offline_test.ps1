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
                switch ($name) {
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
                }
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

if ($fails.Count -gt 0) { throw ("{0} of {1} checks failed" -f $fails.Count, $count) }
Write-Host ("perf offline: {0} checks passed" -f $count)
