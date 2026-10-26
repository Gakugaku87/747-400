# Run one flight-test scenario in X-Plane through the Web API and record it.
# docs/overhaul/TESTING.md describes the kit.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\run_scenario.ps1 `
#       -Scenario tests\flight\scenarios\s00_baseline_start.json -Acf custom
#
# -Acf custom|stock picks 747-400_custom.acf or 747-400.acf (or give a path
# relative to the X-Plane root). -NoFlight runs the steps on the flight that
# is already loaded. -Reload reloads the aircraft (without art) after the
# flight starts: X-Plane keeps the loaded aircraft, plugins and their state
# when a new flight uses the same aircraft, so use -Reload for a clean start.
# Output goes to tests\flight\runs\<time>_<scenario>_<acf>\.
#
# Scenario file (JSON): { "name", "description", "flight": {init without
# "aircraft"}, ["reload": true], ["livery": "<folder>"], "steps": [ ... ] }.
# "reload" asks for -Reload (the scenario needs the aircraft's systems
# fresh); "livery" picks a livery, and with it the engine type. Step types ("do"):
#   record_start | record_stop | mark            the FlyWithLua recorder
#   traffic {targets: [...]} | traffic_stop      TCAS test traffic (FlyWithLua
#                                                B747_traffic.lua): each target a
#                                                "key=value" line of traffic.txt
#   route {entries: [...]} | route_clear        a flight plan in X-Plane's FMS
#                                                (FlyWithLua B747_route.lua): each
#                                                entry an "IDENT LAT LON ALT [ACTIVE]"
#                                                line of route.txt
#   cmd     {name, [duration], [async]}          run a command; with a duration it is
#                                                held that long and the step waits,
#                                                unless async (then the next steps run
#                                                while it is held)
#   set     {dref, value, [rel], [round]}        write a dataref (with "rel": "<as>",
#                                                the remembered value plus value;
#                                                "round": n, to a multiple of n)
#   switch  {dref, value, cmd, [cmd_down]}       press cmd (or cmd_down when the
#                                                value must go down) until dref
#                                                equals value (up to 6 presses)
#   wait    {dref, op, value, timeout}           wait for a condition
#   watch   {dref, [abs], [max], [min],          sample dref every 0.25 s until the
#            [until: {dref, op, value}],         condition (else for the timeout);
#            timeout, [level]}                   pass when the condition came and
#                                                the largest value (absolute with
#                                                abs) is at most max, the least at
#                                                least min
#   check   {dref, op, value, [cite], [level]}   record pass/fail (level fail|warn)
#   remember {dref, as}                          keep a value: a wait or check with
#                                                "rel": "<as>" adds it to its value(s)
#   sleep   {seconds}
#   snapshot {drefs: [...]}                      log values
#   cas                                          log the EICAS message lines
#   view    {name} | {the, psi, [fov]}           turn the pilot's head: a preset
#                                                (forward, panel, overhead, eicas, bleed)
#                                                or pitch/heading, with a field of view
#                                                for a close look (bleed: the P5 bleed
#                                                panel at 25 deg); the user's comes back
#                                                with the next view and at the end
#   shot    {name}                               screenshot
#   cdu     {keys: [...], [cdu]}                 keys on a CDU (cdu "fms1", the
#                                                Captain's, unless given): a line
#                                                select key L1..R6; a key by its name
#                                                (RTE, LEGS, DEPARR, HOLD, MENU,
#                                                INITREF, PROG, NAVRAD, PREV, NEXT,
#                                                EXEC, DEL, CLR); ?SEL: on SELECT DESIRED WPT the
#                                                first (the nearest) candidate, else
#                                                nothing (the Captain's CDU); else text
#                                                typed on its keyboard (A-Z, 0-9,
#                                                / . - and space; "=" first types text
#                                                that reads as a key)
# Every step may carry "note" (shown in the report) and "cite" (source page).
param(
    [Parameter(Mandatory = $true)][string]$Scenario,
    [string]$Acf = 'custom',
    [switch]$NoFlight,
    [switch]$Reload,
    [string]$RunsDir
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'xp.ps1')

$spec = Get-Content -Raw -Encoding UTF8 $Scenario | ConvertFrom-Json
$acfPath = switch ($Acf) {
    'custom' { 'Aircraft/747-400-master/747-400_custom.acf' }
    'stock'  { 'Aircraft/747-400-master/747-400.acf' }
    default  { $Acf }
}
$acfTag = [IO.Path]::GetFileNameWithoutExtension($acfPath)
if (-not $RunsDir) { $RunsDir = Join-Path $PSScriptRoot 'runs' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$out = Join-Path $RunsDir "${stamp}_$($spec.name)_$acfTag"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$recDir = Join-Path $script:XPRoot 'Output\B747_flighttest'
New-Item -ItemType Directory -Force -Path $recDir | Out-Null
$logPath = Join-Path $script:XPRoot 'Log.txt'

$results = New-Object System.Collections.ArrayList
$wall = [Diagnostics.Stopwatch]::StartNew()
function Add-Result($step, [string]$status, [string]$detail, $value = $null) {
    $simT = $null
    try { $simT = [math]::Round((Get-XPDataref 'sim/time/total_running_time_sec'), 2) } catch { }
    $r = [ordered]@{
        n = $results.Count + 1; do = $step.do; status = $status; detail = $detail
        value = $value; note = $step.note; cite = $step.cite
        wall_s = [math]::Round($wall.Elapsed.TotalSeconds, 1); sim_t = $simT
    }
    [void]$results.Add($r)
    $mark = switch ($status) { 'pass' { 'PASS' } 'fail' { 'FAIL' } 'warn' { 'WARN' } default { '----' } }
    Write-Host ("[{0,6:N1}s] {1} {2} {3}" -f $wall.Elapsed.TotalSeconds, $mark, $step.do, $detail)
}
function Test-Op($actual, [string]$op, $expected) {
    switch ($op) {
        '=='      { return $actual -eq $expected }
        '!='      { return $actual -ne $expected }
        '>'       { return $actual -gt $expected }
        '>='      { return $actual -ge $expected }
        '<'       { return $actual -lt $expected }
        '<='      { return $actual -le $expected }
        'between' { return ($actual -ge $expected[0]) -and ($actual -le $expected[1]) }
        'outside' { return ($actual -lt $expected[0]) -or ($actual -gt $expected[1]) }
        'contains' { return ([string]$actual).Contains([string]$expected) }
        'in'      { return @($expected) -contains $actual }
        default   { throw "unknown op $op" }
    }
}
# a step's expected value(s); with "rel", offsets from a remembered value
$script:mem = @{}
function Get-Expected($step) {
    if (-not $step.rel) { return $step.value }
    $base = $script:mem[$step.rel]
    if ($null -eq $base) { throw "nothing remembered as $($step.rel)" }
    if ($step.value -is [array]) { return @(($base + $step.value[0]), ($base + $step.value[1])) }
    return $base + $step.value
}
# X-Plane can hang with the Web API still answering: the sim clock stops.
# Test-XPStuck says so once the clock has not moved for 30 s of wall time.
$script:clock = @{ sim = $null; wall = 0.0 }
function Test-XPStuck {
    $t = Get-XPDataref 'sim/time/total_running_time_sec'
    $now = $wall.Elapsed.TotalSeconds
    if ($null -eq $script:clock.sim -or $t -ne $script:clock.sim) {
        $script:clock.sim = $t
        $script:clock.wall = $now
        return $false
    }
    return ($now - $script:clock.wall) -gt 30
}
function Get-StuckMessage {
    $p = Get-Process -Name 'X-Plane' -ErrorAction SilentlyContinue | Select-Object -First 1
    return "X-Plane stopped: the sim clock has not moved for {0:N0} s (process responding: {1})" -f `
        ($wall.Elapsed.TotalSeconds - $script:clock.wall), $(if ($p) { $p.Responding } else { 'no process' })
}

function Get-CasLines {
    $lines = @()
    foreach ($level in 'warning', 'caution', 'advisory', 'memo') {
        for ($i = 0; $i -lt 22; $i++) {
            $name = 'laminar/B747/CAS/gen_{0}_msg_{1:D3}' -f $level, $i
            try { $t = Get-XPDataref $name } catch { break }
            if ($t -and $t.Trim()) { $lines += "${level}: $($t.Trim())" }
        }
    }
    return $lines
}

# the first Log.txt line of this run, for the excerpt at the end
$logStart = if (Test-Path $logPath) { (Get-Content $logPath).Count } else { 0 }

$freshLoad = $false
if (-not $NoFlight) {
    $init = $spec.flight | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $aircraft = @{ path = $acfPath }
    # a livery (its folder name under liveries/) picks the engine type: B747-400_simconfig.dat
    if ($spec.livery) { $aircraft.livery = $spec.livery }
    $init | Add-Member -NotePropertyName aircraft -NotePropertyValue $aircraft -Force
    Write-Host "starting flight: $acfPath"
    $loadsBefore = Get-XPAircraftLoads
    $t = Start-XPFlight $init
    $freshLoad = (Get-XPAircraftLoads) -gt $loadsBefore
    Add-Result @{ do = 'flight' } 'info' ("flight running (sim time {0} s){1}" -f [math]::Round($t, 1), $(if ($freshLoad) { ', aircraft loaded' } else { '' }))
}
if ($spec.reload -eq $true -and -not $NoFlight) { $Reload = $true }
# Reloading right after X-Plane has loaded the aircraft hung X-Plane twice
# (2026-10-23, docs/overhaul/TESTING.md §4.6); a freshly loaded aircraft
# needs no reload anyway.
if ($Reload -and $freshLoad) {
    Add-Result @{ do = 'reload' } 'info' 'no reload: the flight start loaded the aircraft'
    $Reload = $false
}
if ($Reload) {
    # let the aircraft's plugins settle before unloading them
    $since = Get-XPDataref 'sim/time/total_running_time_sec'
    Wait-XP { (Get-XPDataref 'sim/time/total_running_time_sec') -gt $since + 20 } 120 1000 | Out-Null
    # X-Plane drops the command while it is still settling after a flight
    # load, so wait for the new load in Log.txt and try again if none comes.
    $loads = Get-XPAircraftLoads
    $reloaded = $false
    for ($try = 1; $try -le 3 -and -not $reloaded; $try++) {
        Invoke-XPCommand 'sim/operation/reload_aircraft_no_art'
        $reloaded = $null -ne (Wait-XP { (Get-XPAircraftLoads) -gt $loads } 60 1000)
    }
    if (-not $reloaded) { throw 'the aircraft did not reload' }
    $script:XPDrefs = @{}
    $script:XPCmds = @{}
    $t = Wait-XPSimRunning -TimeoutSec 600
    Add-Result @{ do = 'reload' } 'info' "aircraft reloaded (sim time $([math]::Round($t,1)) s)"
    # An air start flies on the scenario before's systems until the reload
    # and comes back from it where it got to (s15: 41,000 ft and 80 kt, not
    # FL350 and M0.85, then a stall with the custom acf's stall of
    # 2026-10-25), so the reloaded aircraft gets the air start again (the
    # same aircraft: X-Plane keeps it and its reloaded plugins).
    if ($init.lle_air_start) {
        $t = Start-XPFlight $init
        Add-Result @{ do = 'flight' } 'info' ("the air start again on the reloaded aircraft (sim time {0} s)" -f [math]::Round($t, 1))
    }
}
$loaded = Get-XPDataref 'sim/aircraft/view/acf_relative_path'
Add-Result @{ do = 'aircraft' } 'info' $loaded
$fov0 = Get-XPDataref 'sim/graphics/view/field_of_view_deg'

$stopped = $false
foreach ($step in $spec.steps) {
    if ($stopped) { break }
    try {
        if (Test-XPStuck) { throw 'stuck' }
        switch ($step.do) {
            'record_start' { Invoke-XPCommand 'FlyWithLua/B747_flighttest/start'; Add-Result $step 'info' 'recorder started' }
            'record_stop'  { Invoke-XPCommand 'FlyWithLua/B747_flighttest/stop'; Start-Sleep -Seconds 2; Add-Result $step 'info' 'recorder stopped' }
            'mark'         { Invoke-XPCommand 'FlyWithLua/B747_flighttest/mark'; Add-Result $step 'info' 'mark' }
            'traffic' {
                @($step.targets) -join "`n" | Out-File -Encoding ascii (Join-Path $recDir 'traffic.txt')
                Invoke-XPCommand 'FlyWithLua/B747_traffic/start'
                Add-Result $step 'info' ("traffic: " + (@($step.targets) -join ' | '))
            }
            'traffic_stop' { Invoke-XPCommand 'FlyWithLua/B747_traffic/stop'; Add-Result $step 'info' 'traffic stopped' }
            'route' {
                @($step.entries) -join "`n" | Out-File -Encoding ascii (Join-Path $recDir 'route.txt')
                Invoke-XPCommand 'FlyWithLua/B747_route/load'
                Add-Result $step 'info' ("route: " + (@($step.entries) -join ' | '))
            }
            'route_clear' { Invoke-XPCommand 'FlyWithLua/B747_route/clear'; Add-Result $step 'info' 'route cleared' }
            'cmd' {
                $d = if ($step.duration) { [double]$step.duration } else { 0 }
                Invoke-XPCommand $step.name $d
                if ($d -gt 0 -and -not $step.async) { Start-Sleep -Milliseconds ([int]($d * 1000) + 200) }
                Add-Result $step 'info' $step.name
            }
            'set' {
                $v = Get-Expected $step
                if ($step.round) { $v = [math]::Round($v / [double]$step.round) * [double]$step.round }
                Set-XPDataref $step.dref $v; Add-Result $step 'info' "$($step.dref) = $v"
            }
            'switch' {
                $v = Get-XPDataref $step.dref
                $n = 0
                while ([math]::Abs($v - [double]$step.value) -gt 0.01 -and $n -lt 6) {
                    $c = if ($v -gt $step.value -and $step.cmd_down) { $step.cmd_down } else { $step.cmd }
                    Invoke-XPCommand $c
                    Start-Sleep -Milliseconds 600
                    $v = Get-XPDataref $step.dref
                    $n++
                }
                $ok = [math]::Abs($v - [double]$step.value) -le 0.01
                Add-Result $step $(if ($ok) { 'pass' } else { 'fail' }) "$($step.dref) -> $v after $n press(es)" $v
            }
            'wait' {
                $timeout = if ($step.timeout) { [double]$step.timeout } else { 60 }
                $want = Get-Expected $step
                $last = $null
                $script:stuck = $false
                $sec = Wait-XP {
                    if (Test-XPStuck) { $script:stuck = $true; return $true }
                    $script:lastValue = Get-XPDataref $step.dref; Test-Op $script:lastValue $step.op $want
                } $timeout 500
                if ($script:stuck) { throw 'stuck' }
                $last = $script:lastValue
                if ($null -ne $sec) { Add-Result $step 'pass' ("{0} {1} {2} after {3:N1} s" -f $step.dref, $step.op, ($want -join '..'), $sec) $last }
                else { Add-Result $step $(if ($step.level -eq 'warn') { 'warn' } else { 'fail' }) ("{0} {1} {2} not reached in {3} s (last {4})" -f $step.dref, $step.op, ($want -join '..'), $timeout, $last) $last }
            }
            'watch' {
                $timeout = if ($step.timeout) { [double]$step.timeout } else { 60 }
                $u = $step.until
                $uwant = if ($u) { Get-Expected $u } else { $null }
                $hi = $null; $lo = $null; $n = 0; $met = $false
                $t0 = Get-Date
                while (((Get-Date) - $t0).TotalSeconds -lt $timeout) {
                    if (Test-XPStuck) { throw 'stuck' }
                    $v = [double](Get-XPDataref $step.dref)
                    if ($step.abs) { $v = [math]::Abs($v) }
                    if ($null -eq $hi -or $v -gt $hi) { $hi = $v }
                    if ($null -eq $lo -or $v -lt $lo) { $lo = $v }
                    $n++
                    if ($u -and (Test-Op (Get-XPDataref $u.dref) $u.op $uwant)) { $met = $true; break }
                    Start-Sleep -Milliseconds 250
                }
                $ok = $met -or -not $u
                if ($null -ne $step.max -and $hi -gt [double]$step.max) { $ok = $false }
                if ($null -ne $step.min -and $lo -lt [double]$step.min) { $ok = $false }
                $status = if ($ok) { 'pass' } elseif ($step.level -eq 'warn') { 'warn' } else { 'fail' }
                $why = if (-not $u) { '' } elseif ($met) { " until {0} {1} {2}" -f $u.dref, $u.op, ($uwant -join '..') } else { " ({0} {1} {2} not reached in {3} s)" -f $u.dref, $u.op, ($uwant -join '..'), $timeout }
                Add-Result $step $status ("{0}{1}: {2} samples, {3:N3} .. {4:N3} (max {5}, min {6}){7}" -f $(if ($step.abs) { '|' + $step.dref + '|' } else { $step.dref }), '', $n, $lo, $hi, $step.max, $step.min, $why) $hi
            }
            'check' {
                $want = Get-Expected $step
                $v = Get-XPDataref $step.dref
                $ok = Test-Op $v $step.op $want
                $status = if ($ok) { 'pass' } elseif ($step.level -eq 'warn') { 'warn' } else { 'fail' }
                Add-Result $step $status ("{0} = {1} (want {2} {3})" -f $step.dref, $v, $step.op, ($want -join '..')) $v
            }
            'remember' {
                $v = Get-XPDataref $step.dref
                $script:mem[$step.as] = $v
                Add-Result $step 'info' ("{0} = {1} = {2}" -f $step.as, $step.dref, $v) $v
            }
            'sleep' { Start-Sleep -Milliseconds ([int]([double]$step.seconds * 1000)); Add-Result $step 'info' "slept $($step.seconds) s" }
            'snapshot' {
                $vals = [ordered]@{}
                foreach ($d in $step.drefs) { try { $vals[$d] = Get-XPDataref $d } catch { $vals[$d] = 'ERROR' } }
                Add-Result $step 'info' (($vals.Keys | ForEach-Object { "$_=$($vals[$_])" }) -join '; ') $vals
            }
            'cas' { $lines = Get-CasLines; Add-Result $step 'info' ("{0} line(s): {1}" -f $lines.Count, ($lines -join ' | ')) $lines }
            'view' {
                # head pitch/heading in degrees from the captain's eye point, and
                # a field of view for a close look (back to the user's after)
                $presets = @{ forward = @(0, 0); panel = @(-28, 20); overhead = @(58, 48); eicas = @(-22, 29)
                    bleed = @(19, 70, 25) }
                $v = if ($step.name) { $presets[$step.name] } else { @($step.the, $step.psi, $step.fov) }
                if (-not $v) { throw "unknown view preset $($step.name)" }
                $fov = if ($v.Count -gt 2 -and $v[2]) { $v[2] } else { $fov0 }
                Set-XPDataref 'sim/graphics/view/field_of_view_deg' $fov
                Set-XPDataref 'sim/graphics/view/pilots_head_the' $v[0]
                Set-XPDataref 'sim/graphics/view/pilots_head_psi' $v[1]
                Start-Sleep -Seconds 1
                Add-Result $step 'info' ("view pitch {0} heading {1} fov {2}" -f $v[0], $v[1], $fov)
            }
            'cdu' {
                # FCOM's key names to the CDU's commands (MENU is the FIX
                # command, DEP ARR the CLB one, HOLD the DEP_ARR one:
                # B744.createfms.lua); EXEC held 0.2 s like the scenarios' own
                # EXEC steps
                $id = if ($step.cdu) { $step.cdu } else { 'fms1' }
                $names = @{ RTE = 'func_key/fpln'; LEGS = 'func_key/legs'; DEPARR = 'func_key/clb'; HOLD = 'func_key/dep_arr'; MENU = 'func_key/fix'
                    INITREF = 'func_key/index'; PROG = 'func_key/prog'; NAVRAD = 'func_key/navrad'
                    PREV = 'func_key/prev_pg'; NEXT = 'func_key/next_pg'; EXEC = 'key/execute'; DEL = 'key/del'; CLR = 'key/clear' }
                $chars = @{ '/' = 'key/slash'; '.' = 'key/period'; '-' = 'key/minus'; ' ' = 'key/space' }
                foreach ($k in @($step.keys)) {
                    $k = [string]$k
                    if ($k -cmatch '^[LR][1-6]$') {
                        Invoke-XPCommand "laminar/B747/$id/ls_key/$k"
                        Start-Sleep -Milliseconds 500
                    } elseif ($k -cmatch '^[A-Z]+$' -and $names.ContainsKey($k)) {
                        $d = if ($k -ceq 'EXEC') { 0.2 } else { 0 }
                        Invoke-XPCommand "laminar/B747/$id/$($names[$k])" $d
                        Start-Sleep -Milliseconds 500
                    } elseif ($k -ceq '?SEL') {
                        # the Captain's CDU shows its lines in fms3 (§4.6)
                        if ($id -ne 'fms1') { throw "cdu: ?SEL on the Captain's CDU (fms1) only" }
                        if ([string](Get-XPDataref 'laminar/B747/fms3/Line01_L') -match 'SELECT DESIRED WPT') {
                            Invoke-XPCommand "laminar/B747/$id/ls_key/L1"
                            Start-Sleep -Milliseconds 500
                        }
                    } else {
                        $text = if ($k.StartsWith('=')) { $k.Substring(1) } else { $k }
                        foreach ($ch in $text.ToCharArray()) {
                            $c = [string]$ch
                            $cmd = if ($chars.ContainsKey($c)) { $chars[$c] } elseif ($c -cmatch '^[A-Z0-9]$') { "alphanum_key/$c" } else { throw "cdu: no key for '$c'" }
                            Invoke-XPCommand "laminar/B747/$id/$cmd"
                            # a key twice in one frame is taken once (EDDF typed EDF)
                            Start-Sleep -Milliseconds 70
                        }
                        Start-Sleep -Milliseconds 100
                    }
                }
                Add-Result $step 'info' ("cdu {0}: {1}" -f $id, (@($step.keys) -join ' '))
            }
            'shot' {
                $f = Save-XPScreenshot (Join-Path $out ("shot_{0:D2}_{1}.png" -f ($results.Count + 1), $step.name))
                Add-Result $step 'info' (Split-Path -Leaf $f)
            }
            default { throw "unknown step type: $($step.do)" }
        }
    } catch {
        if ($_.Exception.Message -eq 'stuck') {
            Add-Result $step 'fail' (Get-StuckMessage)
            $stopped = $true
        } else {
            Add-Result $step 'fail' "error: $($_.Exception.Message)"
        }
    }
}
if (-not $stopped) { try { Set-XPDataref 'sim/graphics/view/field_of_view_deg' $fov0 } catch { } }

# collect the recorder output and the Log.txt lines of this run
foreach ($f in 'session.csv', 'events.csv', 'summary.txt') {
    $p = Join-Path $recDir $f
    if (Test-Path $p) { Copy-Item $p (Join-Path $out $f) -Force }
}
if (Test-Path $logPath) {
    $log = Get-Content $logPath
    $log[$logStart..($log.Count - 1)] | Out-File -Encoding utf8 (Join-Path $out 'log_full.txt')
    $log[$logStart..($log.Count - 1)] | Where-Object { $_ -match '(?i)\bE/|error|LUA|xtlua|fail|missing|cannot|unable|replaced' } |
        Out-File -Encoding utf8 (Join-Path $out 'log_errors.txt')
}

$summary = [ordered]@{
    scenario = $spec.name; description = $spec.description; acf = $acfPath; loaded = $loaded
    started = $stamp; wall_s = [math]::Round($wall.Elapsed.TotalSeconds, 1)
    pass = @($results | Where-Object { $_.status -eq 'pass' }).Count
    fail = @($results | Where-Object { $_.status -eq 'fail' }).Count
    warn = @($results | Where-Object { $_.status -eq 'warn' }).Count
    steps = $results
}
$summary | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 (Join-Path $out 'result.json')
$md = @("# $($spec.name) ($acfTag)", '', "$($spec.description)", '',
    "- 開始: $stamp、所要 $($summary.wall_s) s、PASS $($summary.pass) / FAIL $($summary.fail) / WARN $($summary.warn)", '',
    '| # | 種類 | 結果 | 内容 | メモ | 出典 | sim 時刻 |', '|---|---|---|---|---|---|---|')
foreach ($r in $results) {
    $md += "| $($r.n) | $($r.do) | $($r.status) | $(($r.detail -replace '\|', '\|')) | $($r.note) | $($r.cite) | $($r.sim_t) |"
}
$md | Out-File -Encoding utf8 (Join-Path $out 'result.md')
Write-Host "result: $out  (pass $($summary.pass), fail $($summary.fail), warn $($summary.warn))"
