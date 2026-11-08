# Phase 4 of PERF_SIMBRIEF.md (docs/overhaul/TESTING.md 4.7), flown by the kit
# (the user, 2026-11-08: the aircraft placed on the departure runway and flown
# from there to a stop on the destination's runway with no one at the
# controls): the user's latest SimBrief OFP (made with the custom airframe),
# flight_log.ps1 recording beside it (its report.md compares the flight with
# the plan).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\perf\auto_flight.ps1 -SimbriefUser <name> [-PilotId <id>] [-Steps ofp|fmc] [-StartXPlane] [-DryRun]
#
#   start    X-Plane's flight initialization (the Web API): the OFP's origin
#            and runway, its zero fuel weight (the payload over the stations
#            by their maxima) and takeoff fuel (the aircraft's load order:
#            perf.ps1's Get-FuelByTank), real weather, the system's time, the
#            engines running (a start from cold: a later version); a flight
#            on an aircraft already loaded reloaded (fresh systems) and
#            placed again, as run_scenario.ps1 does
#   FMC      the IDENT; the sim options (Plugins > 747-400): pause before T/D
#            off, Auto step climb on with -Steps fmc only; FMC DATALINK on;
#            the route by the company datalink (RTE REQUEST: the bridge fetches
#            the latest OFP by the SIMBRIEF PILOT ID, notes/ATA-34-61-FMC.md
#            131), LOAD; the destination runway's ILS approach (with the
#            STAR's last fix as its transition when listed) when the uplink
#            has none; ACTIVATE, EXEC; route discontinuities closed (the next
#            waypoint into the box, EXEC); PERF INIT (ZFW, reserves: the OFP's
#            reserve and alternate fuel, CRZ ALT, CI); TAKEOFF REF (the TLR's
#            flaps 10 or 20, the FMC's V speeds)
#   takeoff  s198_line_flight_rjaa_rjbb's procedure (notes/LINE_FLIGHTS.md)
#            with the FlyWithLua helpers in tests/flight/fwl: the runway
#            heading held by the pedals (B747_rudder_hold.lua) in the roll,
#            full thrust, at the FMC's VR the FCTM's rotation
#            (B747_rotate.lua), after liftoff the F/D's pitch bar
#            (B747_fd_follow.lua), CMD L at 300 ft RA, VNAV and LNAV; the
#            flaps up on the FCOM's schedule (NP.21.38, p.132: at each
#            maneuver speed, PI.10.3, p.229)
#   cruise   the altimeters STD above the origin's transition altitude; the
#            OFP's step climbs at its fixes (-Steps ofp, the default: the MCP
#            altitude to the step's level, then the altitude selector pushed,
#            FCOM p.649 and p.1257) or the FMC's own (-Steps fmc: the sim's
#            Auto step climb); the MCP down to 3,000 ft above the destination
#            before T/D (by the distance to E/D), the selector pushed when VNAV
#            holds past T/D; QNH below the destination's transition level
#   landing  from 28 NM to E/D s198's approach on the FCOM's maneuver speeds:
#            speed intervention, flaps 1 and 5, APP, CMD C and R, gear and
#            flaps 20 at G/S alive, flaps 30 and VREF 30 + 5 at the G/S's
#            capture, LAND 3 or 2, the flare, reverse thrust, the rollout,
#            the parking brake below 60 kt, the A/P off once stopped
# The engines' fuel burns by real time (XTLua's SIM_PERIOD): no time
# acceleration. Waits count X-Plane's time (a pause stops them). It stops on
# an XTLua error (Output/B747_xtlua_errors.txt), a sim clock stopped for 60 s,
# a wait's limit in a step the flight cannot go on without, or -MaxHours; in
# the air flight_log.ps1 records on until the aircraft has stood on the
# ground. The payload is put back as the run found it after the end (the
# fix session's scenarios without a weight inherit it). Not started while
# another flight (a scenario runner, a run list, perf.ps1) is running.
#
# Output: tests\flight\perf\runs\<yyyyMMdd_HHmmss>_autoflight\ (local only:
# the OFP holds the user's SimBrief account): ofp.json, plan.json, events.txt,
# status.txt (the latest phase), flight\ (flight_log.ps1's run: report.md).
param(
    [string]$SimbriefUser,
    [string]$OfpFile,
    [long]$PilotId = 0,
    [ValidateSet('ofp', 'fmc')][string]$Steps = 'ofp',
    [double]$MaxHours = 20,
    [switch]$StartXPlane,
    [switch]$DryRun,
    [switch]$NoLog,
    [switch]$Force,
    [string]$AutoOut
)
$ErrorActionPreference = 'Stop'
# (the dot-sourced scripts' params share this scope: kept here first)
$afArgs = @{ SimbriefUser = $SimbriefUser; OfpFile = $OfpFile; PilotId = $PilotId; Steps = $Steps; MaxHours = $MaxHours
    StartXPlane = [bool]$StartXPlane; DryRun = [bool]$DryRun; NoLog = [bool]$NoLog; Force = [bool]$Force; AutoOut = $AutoOut }
. (Join-Path $PSScriptRoot 'flight_report.ps1')

# ---------------------------------------------------------------- the plan

# the custom acf's own numbers (pounds in the file): the empty weight, the
# payload stations' maxima, the tanks' capacities (kg)
function Get-AutoAcf([string]$File) {
    $k = Read-AcfKeys $File
    $num = { param($Key) if ($k.Contains($Key)) { [double]::Parse($k[$Key].value, $inv) } else { 0.0 } }
    $total = (& $num '_m_fuel_max_tot') * $LB
    $tanks = [double[]]@(0..8 | ForEach-Object { (& $num "_tank_rat/$_") * $total })
    $st = [double[]]@(0..8 | ForEach-Object { (& $num "_fixed_max/$_") * $LB })
    return [pscustomobject]@{ oew_kg = (& $num '_m_empty') * $LB; station_max_kg = $st; tank_cap_kg = $tanks; fuel_max_kg = $total }
}

# the OFP's step climbs (general.stepclimb_string, "KLAX/0330/ELVEL/0350/
# 62N050W/0370": the initial level, then each step's fix and level) with the
# fixes' places from the navlog (none found: lat $null)
function Get-AutoSteps($Json) {
    $parts = @(([string]$Json.general.stepclimb_string).Split('/') | Where-Object { $_ -ne '' })
    $fixes = @($Json.navlog.fix)
    $out = New-Object System.Collections.ArrayList
    for ($i = 2; $i + 1 -lt $parts.Count; $i += 2) {
        $lv = $parts[$i + 1] -replace '[^0-9]', ''
        if (-not $lv) { continue }
        $id = $parts[$i]
        $f = $fixes | Where-Object { [string]$_.ident -eq $id } | Select-Object -First 1
        [void]$out.Add([pscustomobject]@{ fix = $id; ft = 100 * [double]$lv
            lat = $(if ($f) { [double]$f.pos_lat } else { $null }); lon = $(if ($f) { [double]$f.pos_long } else { $null }) })
    }
    return ,($out.ToArray())
}

# the plan from the OFP's JSON and the acf: the runways, the weights (the
# payload: the OFP's zero fuel weight less the acf's empty weight), the
# levels, the takeoff flaps (the TLR's for the planned runway: 10 or 20, else
# 20), the SID and STAR (the navlog's procedures) and the STAR's last fix,
# the transition altitude and level, the MCP's approach altitude (3,000 ft
# above the field, up to 100 ft: the G/S met from below)
function Get-AutoPlan($Json, $Acf) {
    $u = if ([string]$Json.params.units -eq 'lbs') { $LB } else { 1.0 }
    $origRwy = [string]$Json.origin.plan_rwy; $destRwy = [string]$Json.destination.plan_rwy
    $origElev = [double]$Json.origin.elevation; $destElev = [double]$Json.destination.elevation
    $zfw = [double]$Json.weights.est_zfw * $u; $toFuel = [double]$Json.fuel.plan_takeoff * $u
    $payload = $zfw - $Acf.oew_kg
    $sum = 0.0; foreach ($v in $Acf.station_max_kg) { $sum += $v }
    if ($payload -lt 0) { throw ('the OFP''s ZFW {0:0} kg is below the acf''s empty weight {1:0} kg' -f $zfw, $Acf.oew_kg) }
    if ($payload -gt $sum) { throw ('the payload {0:0} kg is above the stations'' maxima {1:0} kg' -f $payload, $sum) }
    if ($toFuel -gt $Acf.fuel_max_kg) { throw ('the takeoff fuel {0:0} kg is above the tanks'' {1:0} kg' -f $toFuel, $Acf.fuel_max_kg) }
    $flaps = 20
    $tr = @($Json.tlr.takeoff.runway) | Where-Object { [string]$_.identifier -eq $origRwy } | Select-Object -First 1
    if ($null -ne $tr -and @('10', '20') -contains [string]$tr.flap_setting) { $flaps = [int]$tr.flap_setting }
    $fixes = @($Json.navlog.fix)
    $procs = @($fixes | Where-Object { [string]$_.is_sid_star -eq '1' -and @('TOC', 'TOD') -notcontains [string]$_.ident })
    $sid = $null; $star = $null; $starEnd = $null
    $clb = @($procs | Where-Object { [string]$_.stage -eq 'CLB' })
    if ($clb.Count -gt 0) { $sid = [string]$clb[0].via_airway }
    $dsc = @($procs | Where-Object { [string]$_.stage -eq 'DSC' })
    if ($dsc.Count -gt 0) {
        $star = [string]$dsc[$dsc.Count - 1].via_airway
        $sf = @($procs | Where-Object { [string]$_.via_airway -eq $star -and [string]$_.ident -ne [string]$Json.destination.icao_code })
        if ($sf.Count -gt 0) { $starEnd = [string]$sf[$sf.Count - 1].ident }
    }
    $ta = [double]$Json.origin.trans_alt; if (-not ($ta -gt 0)) { $ta = 18000 }
    $tl = [double]$Json.destination.trans_level; if (-not ($tl -gt 0)) { $tl = 18000 }
    $appFt = 100 * [math]::Ceiling(($destElev + 3000) / 100)
    $stations = [double[]]@($Acf.station_max_kg | ForEach-Object { $payload * $_ / $sum })
    return [pscustomobject]@{ route = ('{0}-{1}' -f $Json.origin.icao_code, $Json.destination.icao_code)
        origin = [string]$Json.origin.icao_code; origin_rwy = $origRwy; origin_elev_ft = $origElev; origin_trans_alt_ft = $ta
        dest = [string]$Json.destination.icao_code; dest_rwy = $destRwy; dest_elev_ft = $destElev; dest_trans_level_ft = $tl
        zfw_kg = $zfw; payload_kg = $payload; takeoff_fuel_kg = $toFuel; tow_kg = $zfw + $toFuel
        reserves_kg = ([double]$Json.fuel.reserve + [double]$Json.fuel.alternate_burn) * $u
        crz_ft = [double]$Json.general.initial_altitude; ci = [int]$Json.general.costindex; takeoff_flaps = $flaps
        sid = $sid; star = $star; star_end = $starEnd; approach = ('ILS' + $destRwy); app_mcp_ft = $appFt
        steps = (Get-AutoSteps $Json); stations_kg = $stations; tanks_kg = (Get-FuelByTank $toFuel $Acf.tank_cap_kg)
        trip_kg = [double]$Json.fuel.enroute_burn * $u; time_s = [double]$Json.times.est_time_enroute; custom = [string]$Json.aircraft.is_custom }
}

# X-Plane's flight initialization for the plan (the Flight Initialization
# API: runway_start, engine_status, use_system_time, real weather, weight)
function Get-AutoInit($Plan, [bool]$Running = $true) {
    return [ordered]@{
        aircraft = [ordered]@{ path = $acfRel }
        runway_start = [ordered]@{ airport_id = $Plan.origin; runway = $Plan.origin_rwy }
        engine_status = [ordered]@{ all_engines = [ordered]@{ running = $Running } }
        use_system_time = $true
        weather = 'use_real_weather'
        weight = [ordered]@{
            payload_weight_in_kilograms = @($Plan.stations_kg | ForEach-Object { [math]::Round($_, 1) })
            fueltank_weight_in_kilograms = @($Plan.tanks_kg | ForEach-Object { [math]::Round($_, 1) }) }
    }
}

# the flap maneuver speeds (FCOM p.229, PI.10.3): UP VREF 30 + 80, 1 + 60,
# 5 + 40, 10 + 20, 20 + 10, 30 VREF 30; the approach VREF 30 + 5 (FCTM p.161,
# as s198)
function Get-AutoSpeeds([double]$Vref30) {
    return [pscustomobject]@{ up = $Vref30 + 80; f1 = $Vref30 + 60; f5 = $Vref30 + 40; f10 = $Vref30 + 20; f20 = $Vref30 + 10; f30 = $Vref30; app = $Vref30 + 5 }
}
# the MCP down before T/D at this distance to E/D (NM): 3.3 NM a 1,000 ft
# above the field and 40 NM more, some minutes before the T/D (estimate)
function Get-AutoLowerNm([double]$CrzFt, [double]$DestElevFt) { return ($CrzFt - $DestElevFt) / 1000 * 3.3 + 40 }
# X-Plane's QNH (Pa) in inches of mercury to 0.01; out of 27.5-31.5: $null
function Get-AutoQnhInHg($Pa) {
    if ($null -eq $Pa -or -not ([double]$Pa -gt 0)) { return $null }
    $v = [math]::Round([double]$Pa / 3386.389, 2)
    if ($v -lt 27.5 -or $v -gt 31.5) { return $null }
    return $v
}
# a fix passed: within 2 NM, or 0.5 NM farther than the closest so far once
# that was within 40 NM ($State.min kept)
function Test-AutoPassed($State, [double]$Nm) {
    if ($null -eq $State.min -or $Nm -lt $State.min) { $State.min = $Nm }
    return ($Nm -lt 2) -or ($State.min -lt 40 -and $Nm -gt $State.min + 0.5)
}

# ---------------------------------------------------------------- the CDU's pages

# a CDU line's words: each with its column, side (L or R by its middle on the
# 24 columns) and mark (<SEL> or <ACT> beside it: after a left one, before a
# right one; B744.fms.pages.deparr.lua draw)
function Get-CduItems([string]$Line) {
    $clean = $Line.Replace('<SEL>', '     ').Replace('<ACT>', '     ')
    $out = New-Object System.Collections.ArrayList
    foreach ($m in [regex]::Matches($clean, '\S+')) {
        $mark = $null
        $end = $m.Index + $m.Length
        if ($Line.Length -ge $end + 5) { $a = $Line.Substring($end, 5); if ($a -ceq '<SEL>' -or $a -ceq '<ACT>') { $mark = $a } }
        if ($m.Index -ge 5) { $b = $Line.Substring($m.Index - 5, 5); if ($b -ceq '<SEL>' -or $b -ceq '<ACT>') { $mark = $b } }
        [void]$out.Add([pscustomobject]@{ text = $m.Value; col = $m.Index; side = $(if ($m.Index + $m.Length / 2.0 -ge 12) { 'R' } else { 'L' }); mark = $mark })
    }
    return ,($out.ToArray())
}
# a word on a page's large lines (Line01-Line14 as $Large[0..13]; LSK k at
# Line(2k+1)): its key, text and mark; the word itself first, then (-Prefix)
# the word and one letter more (ILS06L: ILS06LZ); -Marked: only one with a
# mark; none: $null
function Find-CduText([string[]]$Large, [string]$Text, [string]$Side = '', [switch]$Prefix, [switch]$Marked) {
    foreach ($exact in @($true, $false)) {
        if (-not $exact -and -not $Prefix) { break }
        for ($k = 1; $k -le 6; $k++) {
            foreach ($it in (Get-CduItems ([string]$Large[2 * $k]))) {
                if ($Side -and $it.side -ne $Side) { continue }
                if ($Marked -and -not $it.mark) { continue }
                $hit = if ($exact) { $it.text -ceq $Text } else { $it.text.Length -eq $Text.Length + 1 -and $it.text.StartsWith($Text) -and ([string]$it.text[-1]) -cmatch '^[A-Z]$' }
                if ($hit) { return [pscustomobject]@{ key = "$($it.side)$k"; text = $it.text; mark = $it.mark } }
            }
        }
    }
    return $null
}
# a LEGS page's route discontinuity (B744.fms.pages.legs.lua legs_small: the
# box's title " THEN", the next leg's "-- ROUTE DISCONTINUITY -"): the box's
# key and the next leg's (on the next page's L1 when the box is L5: $null);
# $Small the page's small lines as $Small[0..13]
function Find-CduDiscontinuity([string[]]$Small) {
    for ($k = 1; $k -le 5; $k++) {
        if (([string]$Small[2 * $k - 1]).Trim() -ceq 'THEN') { return [pscustomobject]@{ box = "L$k"; next = $(if ($k -lt 5) { "L$($k + 1)" } else { $null }) } }
    }
    return $null
}
# the page number "p/n" at Line01_S's end: @(p, n); none: $null
function Get-CduPageNo([string]$Line) {
    if ($Line -match '(\d+)/(\d+)\s*$') { return ,([int[]]@([int]$Matches[1], [int]$Matches[2])) }
    return $null
}

# ---------------------------------------------------------------- X-Plane

$script:afXtErr = Join-Path $script:XPRoot 'Output\B747_xtlua_errors.txt'
$script:afXtFrom = 0
$script:afClock = @{ sim = $null; wall = 0.0; checked = -1e9 }
$script:autoOut = $null

function Note-Status([string]$Phase, [string]$Text) {
    Note info "[$Phase] $Text"
    if ($script:autoOut) { [IO.File]::WriteAllText((Join-Path $script:autoOut 'status.txt'), ('{0} {1}: {2}' -f (Get-Date).ToString('s'), $Phase, $Text), $utf8) }
}
# a Web API call tried again on an error (X-Plane busy loading scenery), up
# to 4 times
function Invoke-AutoTry([scriptblock]$Do, [string]$What) {
    for ($n = 1; ; $n++) {
        try { return (& $Do) } catch {
            if ($n -ge 4) { throw }
            Note warn ('{0}: {1} (again)' -f $What, $_.Exception.Message)
            Start-Sleep -Seconds (2 * $n)
        }
    }
}
function Get-N([string]$Name) { return [double](Invoke-AutoTry { Get-XPDataref $Name } $Name) }
function Get-S([string]$Name) { return [string](Invoke-AutoTry { Get-XPDataref $Name } $Name) }
function Set-N([string]$Name, $Value) { [void](Invoke-AutoTry { Set-XPDataref $Name $Value } $Name) }
function Send-Cmd([string]$Name, [double]$Sec = 0) { [void](Invoke-AutoTry { Invoke-XPCommand $Name $Sec } $Name) }
# a push button held 0.2 s (TESTING.md 4.6: a 0 s press may miss phase 2)
function Push-Auto([string]$Name) { Send-Cmd $Name 0.2; Start-Sleep -Milliseconds 450 }
function Set-Mcp([string]$What, [double]$Value) {
    if ($What -eq 'alt') { Set-N 'laminar/B747/autopilot/heading/altitude_dial_ft' ([int]$Value); Set-N 'laminar/B747/autopilot/altitude_dial_ft' ([int]$Value) }
    else { Set-N 'laminar/B747/autopilot/ias_dial_value' ([int][math]::Round($Value)) }
}
$FlapRatio = @{ 0 = 0.0; 1 = 0.168; 5 = 0.34; 10 = 0.5; 20 = 0.668; 30 = 1.0 }
function Set-Flaps([int]$Deg) { Set-N 'sim/cockpit2/controls/flap_ratio' $FlapRatio[$Deg]; Note info "flaps $Deg" }
# press $Cmd until $Dref is $Value, up to 6 presses ($Down when it must go
# down; run_scenario.ps1's switch step)
function Set-AutoSwitch([string]$Dref, [double]$Value, [string]$Cmd, [string]$Down = '') {
    for ($n = 0; $n -lt 6; $n++) {
        $v = Get-N $Dref
        if ([math]::Abs($v - $Value) -le 0.01) { return $true }
        Send-Cmd $(if ($v -gt $Value -and $Down) { $Down } else { $Cmd })
        Start-Sleep -Milliseconds 600
    }
    $ok = [math]::Abs((Get-N $Dref) - $Value) -le 0.01
    if (-not $ok) { Note warn ('{0} not {1} after 6 presses' -f $Dref, $Value) }
    return $ok
}
# an XTLua error, the sim clock stopped (not paused) for 60 s or -MaxHours:
# the flight cannot go on (checked every 5 s at most)
function Assert-AutoAlive {
    $now = $wall.Elapsed.TotalSeconds
    if ($now - $script:afClock.checked -lt 5) { return }
    $script:afClock.checked = $now
    if ((Get-FileLength $script:afXtErr) -gt $script:afXtFrom) {
        $e = @(Get-FileTail $script:afXtErr $script:afXtFrom)
        throw ('XTLua stopped the aircraft''s modules on a Lua error: {0}' -f ($e | Select-Object -First 1))
    }
    if ($afArgs.MaxHours -gt 0 -and $wall.Elapsed.TotalHours -ge $afArgs.MaxHours) { throw ('-MaxHours {0} reached' -f $afArgs.MaxHours) }
    $t = $null; $paused = $false
    try { $t = [double](Get-XPDataref 'sim/time/total_running_time_sec'); $paused = (Get-XPDataref 'sim/time/paused') -eq 1 } catch { return }
    if ($paused -or $null -eq $script:afClock.sim -or $t -ne $script:afClock.sim) { $script:afClock.sim = $t; $script:afClock.wall = $now; return }
    if ($now - $script:afClock.wall -gt 60) {
        $p = Get-Process -Name 'X-Plane' -ErrorAction SilentlyContinue | Select-Object -First 1
        throw ('X-Plane stopped: the sim clock has not moved for {0:0} s (process responding: {1})' -f ($now - $script:afClock.wall), $(if ($p) { $p.Responding } else { 'no process' }))
    }
}
# wait for a condition up to $Sec seconds of X-Plane's time (a pause stops
# the count): the seconds, or $null
function Wait-AutoCond([scriptblock]$Cond, [double]$Sec, [int]$Ms = 500) {
    $t0 = Get-N 'sim/time/total_running_time_sec'
    while ($true) {
        Assert-AutoAlive
        $ok = $false
        try { $ok = [bool](& $Cond) } catch { $ok = $false }
        $el = (Get-N 'sim/time/total_running_time_sec') - $t0
        if ($ok) { return [math]::Max(0.0, $el) }
        if ($el -ge $Sec) { return $null }
        Start-Sleep -Milliseconds $Ms
    }
}
function Wait-AutoDref([string]$Dref, [string]$Op, [double]$Value, [double]$Sec, [string]$What, [switch]$Must, [int]$Ms = 500) {
    $script:afLast = $null
    $s = Wait-AutoCond { $v = [double](Get-XPDataref $Dref); $script:afLast = $v
        switch ($Op) { '>' { $v -gt $Value } '<' { $v -lt $Value } '==' { [math]::Abs($v - $Value) -lt 0.001 } default { throw "op $Op" } } } $Sec $Ms
    if ($null -eq $s) {
        $msg = '{0}: {1} {2} {3} not in {4} s (last {5})' -f $What, $Dref, $Op, $Value, $Sec, $script:afLast
        if ($Must) { throw $msg }
        Note warn $msg
        return $false
    }
    Note info ('{0} ({1:0} s)' -f $What, $s)
    return $true
}

# the Captain's CDU (fms1; its lines in fms3): run_scenario.ps1's cdu step's
# keys (LSK L1-R6, the function keys by FCOM's names, text typed; a repeated
# character 250 ms after the one before)
$CduNames = @{ RTE = 'func_key/fpln'; LEGS = 'func_key/legs'; DEPARR = 'func_key/clb'; HOLD = 'func_key/dep_arr'; MENU = 'func_key/fix'
    INITREF = 'func_key/index'; PROG = 'func_key/prog'; NAVRAD = 'func_key/navrad'; VNAV = 'func_key/des'
    PREV = 'func_key/prev_pg'; NEXT = 'func_key/next_pg'; EXEC = 'key/execute'; DEL = 'key/del'; CLR = 'key/clear'
    ATC = 'func_key/crz'; FMCCOMM = 'func_key/hold' }
function Send-Cdu([string[]]$Keys) {
    $chars = @{ '/' = 'key/slash'; '.' = 'key/period'; '-' = 'key/minus'; ' ' = 'key/space' }
    foreach ($k in $Keys) {
        if ($k -cmatch '^[LR][1-6]$') { Send-Cmd "laminar/B747/fms1/ls_key/$k"; Start-Sleep -Milliseconds 500; continue }
        if ($k -cmatch '^[A-Z]+$' -and $CduNames.ContainsKey($k)) {
            Send-Cmd "laminar/B747/fms1/$($CduNames[$k])" $(if ($k -ceq 'EXEC') { 0.2 } else { 0 })
            Start-Sleep -Milliseconds 500; continue
        }
        $prev = $null
        foreach ($ch in $k.ToCharArray()) {
            $c = [string]$ch
            $cmd = if ($chars.ContainsKey($c)) { $chars[$c] } elseif ($c -cmatch '^[A-Z0-9]$') { "alphanum_key/$c" } else { throw "cdu: no key for '$c'" }
            if ($c -ceq $prev) { Start-Sleep -Milliseconds 250 }
            Send-Cmd "laminar/B747/fms1/$cmd"
            Start-Sleep -Milliseconds 70
            $prev = $c
        }
        Start-Sleep -Milliseconds 100
    }
}
function Get-CduLines([string]$Kind = 'L') { return ,([string[]]@(1..14 | ForEach-Object { Get-S ('laminar/B747/fms3/Line{0:D2}_{1}' -f $_, $Kind) })) }
function Get-CduTitle { return (Get-S 'laminar/B747/fms3/Line01_L') }
function Set-CduFirstPage {
    for ($i = 0; $i -lt 40; $i++) {
        $pg = Get-CduPageNo (Get-S 'laminar/B747/fms3/Line01_S')
        if (-not $pg -or $pg[0] -le 1) { return }
        Send-Cdu @('PREV')
    }
}
# each page's large lines from the first (after $Open) to the last
function Read-CduPages([scriptblock]$Open, [int]$Max = 12) {
    & $Open
    $pg = Get-CduPageNo (Get-S 'laminar/B747/fms3/Line01_S')
    $n = if ($pg) { [math]::Min($pg[1], $Max) } else { 1 }
    $pages = New-Object System.Collections.ArrayList
    for ($p = 1; $p -le $n; $p++) {
        [void]$pages.Add((Get-CduLines 'L'))
        if ($p -lt $n) { Send-Cdu @('NEXT') }
    }
    return ,($pages.ToArray())
}
# a word on the pages (the word itself on any page first): opened again,
# its page, its key pressed; the hit, or $null
function Select-CduItem([scriptblock]$Open, [string]$Text, [string]$Side, [switch]$Prefix) {
    $pages = Read-CduPages $Open
    foreach ($exact in @($true, $false)) {
        if (-not $exact -and -not $Prefix) { break }
        for ($p = 0; $p -lt $pages.Count; $p++) {
            $hit = Find-CduText $pages[$p] $Text $Side -Prefix:(-not $exact)
            if ($hit) {
                & $Open
                for ($i = 0; $i -lt $p; $i++) { Send-Cdu @('NEXT') }
                Send-Cdu @($hit.key)
                return $hit
            }
        }
    }
    return $null
}

# ---------------------------------------------------------------- the start

# other flights on this X-Plane (the fix session's scenario runner and run
# lists, the perf kit's measurements, another auto flight): "pid name"; this
# process and the ones that started it (a shell whose command line names
# this script) left out
function Get-AutoOtherRunners {
    $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    $byId = @{}
    foreach ($p in $all) { $byId[[int]$p.ProcessId] = $p }
    $mine = @{}
    $id = $PID
    for ($n = 0; $n -lt 30 -and $byId.ContainsKey($id) -and -not $mine.ContainsKey($id); $n++) { $mine[$id] = $true; $id = [int]$byId[$id].ParentProcessId }
    return @($all | Where-Object {
        -not $mine.ContainsKey([int]$_.ProcessId) -and $_.CommandLine -and ($_.CommandLine -match 'run_scenario\.ps1|run_all\.sh|run_list|perf\\perf\.ps1|auto_flight\.ps1')
    } | ForEach-Object { '{0} {1}' -f $_.ProcessId, $_.Name })
}

# the flight started, a flight on the aircraft already loaded reloaded (fresh
# systems; not right after X-Plane's own load, which hung X-Plane twice:
# TESTING.md 4.6) and started again (the weights); every engine burning
function Start-AutoFlight($Init) {
    Note-Status 'start' ('{0} runway {1}' -f $Init.runway_start.airport_id, $Init.runway_start.runway)
    # a fresh load: the aircraft's option turned over before the start stays
    # turned over on an aircraft not loaded again (run_scenario.ps1)
    $markRef = 'laminar/B747/options/auto_step_climb'
    $markWas = $null; $mark = $null
    try {
        $markWas = [int](Get-XPDataref $markRef); $mark = 1 - $markWas
        Set-XPDataref $markRef $mark
        if ([int](Get-XPDataref $markRef) -ne $mark) { $markWas = $null }
    } catch { $markWas = $null }
    $loadsBefore = Get-XPAircraftLoads
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $t = Invoke-PerfFlight $Init
    $fresh = $true
    if ($null -ne $markWas) {
        $now = $null
        try { $now = [int](Get-XPDataref $markRef) } catch { $now = $null }
        $fresh = ($now -ne $mark) -or ((Get-XPAircraftLoads) -gt $loadsBefore)
        if (-not $fresh) { Set-XPDataref $markRef $markWas }
    } else {
        $fresh = ((Get-XPAircraftLoads) -gt $loadsBefore) -or ($sw.Elapsed.TotalSeconds -gt 45)
    }
    $script:XPDrefs = @{}; $script:XPCmds = @{}
    Note info ('flight running (sim time {0:0.0} s){1}' -f $t, $(if ($fresh) { ', the aircraft loaded' } else { '' }))
    $since = Get-N 'sim/time/total_running_time_sec'
    [void](Wait-XP { (Get-XPDataref 'sim/time/total_running_time_sec') -gt $since + 20 } 180 1000)
    if (-not $fresh) {
        $loads = Get-XPAircraftLoads
        $ok = $false
        for ($try = 1; $try -le 3 -and -not $ok; $try++) {
            Invoke-XPCommand 'sim/operation/reload_aircraft_no_art'
            $ok = $null -ne (Wait-XP { (Get-XPAircraftLoads) -gt $loads } 60 1000)
        }
        if (-not $ok) { throw 'the aircraft did not reload' }
        $script:XPDrefs = @{}; $script:XPCmds = @{}
        $t = Wait-XPSimRunning -TimeoutSec 600
        Note info ('the aircraft reloaded (sim time {0:0.0} s)' -f $t)
        $t = Invoke-PerfFlight $Init
        Note info ('placed again on the reloaded aircraft (sim time {0:0.0} s)' -f $t)
        $since = Get-N 'sim/time/total_running_time_sec'
        [void](Wait-XP { (Get-XPDataref 'sim/time/total_running_time_sec') -gt $since + 20 } 180 1000)
    }
    for ($try = 1; $try -le 3; $try++) {
        $burning = @(Get-XPDataref 'sim/flightmodel2/engines/engine_is_burning_fuel')
        $off = @(0..3 | Where-Object { [int]$burning[$_] -ne 1 } | ForEach-Object { $_ + 1 })
        if ($off.Count -eq 0) { break }
        if ($try -eq 3) { throw ('engines {0} not burning after three starts' -f ($off -join ',')) }
        Note warn ('engines {0} not burning: the flight started again' -f ($off -join ','))
        $t = Invoke-PerfFlight $Init
        $since = Get-N 'sim/time/total_running_time_sec'
        [void](Wait-XP { (Get-XPDataref 'sim/time/total_running_time_sec') -gt $since + 10 } 120 1000)
    }
    Set-N 'laminar/B747/flt_ctrls/parking_brake_ratio' 1
    $w = Get-PerfWeights
    Note info ('weights: gross {0:0.0} t, payload {1:0.0} t, fuel {2:0.0} t' -f ($w.gw_kg / 1000), ($w.payload_kg / 1000), ($w.fuel_kg / 1000))
    return $w
}

# ---------------------------------------------------------------- the FMC

function Set-AutoFmc($Plan) {
    Note-Status 'fmc' 'IDENT, the sim options, FMC DATALINK'
    Send-Cdu @('MENU', 'L1')
    if ($null -eq (Wait-AutoCond { ([string](Get-XPDataref 'laminar/B747/fms3/Line05_L')).Contains('AIRAC') } 180 1000)) { throw 'the FMC''s navigation data did not load (IDENT)' }
    # (not saved: a write does not save them)
    Set-N 'laminar/B747/options/pause_at_td' 0
    Set-N 'laminar/B747/options/auto_step_climb' $(if ($afArgs.Steps -eq 'fmc') { 1 } else { 0 })
    # MENU, SIM CONFIG (6R), NEXT: FMC DATALINK (4L: AUTO, ON, OFF) and the
    # SIMBRIEF PILOT ID (5L), as s218_simbrief_fetch
    Send-Cdu @('MENU', 'R6', 'NEXT')
    for ($n = 0; $n -lt 3 -and -not (Get-S 'laminar/B747/fms3/Line09_L').Contains('FMC DATALINK         ON'); $n++) { Send-Cdu @('L4') }
    if (-not (Get-S 'laminar/B747/fms3/Line09_L').Contains('FMC DATALINK         ON')) { throw ('FMC DATALINK not ON: ' + (Get-S 'laminar/B747/fms3/Line09_L')) }
    $id = Get-N 'laminar/B747/options/simbrief_id'
    if ($afArgs.PilotId -gt 0 -and $id -ne $afArgs.PilotId) {
        Send-Cdu @([string]$afArgs.PilotId, 'L5')
        $id = Get-N 'laminar/B747/options/simbrief_id'
        if ($id -ne $afArgs.PilotId) { throw ('the SIMBRIEF PILOT ID not taken: {0}' -f $id) }
    }
    if ($id -le 0) { throw 'no SIMBRIEF PILOT ID in the aircraft (give -PilotId)' }
    Note-Status 'fmc' 'RTE REQUEST (the latest OFP by the Pilot ID)'
    $req = Get-N 'laminar/B747/fms/company/simbrief_fetch'
    Send-Cdu @('FMCCOMM', 'NEXT', 'L1')
    if ($null -eq (Wait-AutoCond { (Get-XPDataref 'laminar/B747/fms/company/simbrief_done') -ge $req + 1 } 90 1000)) { throw 'the bridge did not fetch the OFP' }
    if ((Get-N 'laminar/B747/fms/company/simbrief_status') -ne 2) { throw ('the fetch failed (simbrief_status {0})' -f (Get-N 'laminar/B747/fms/company/simbrief_status')) }
    $fms = Get-S 'laminar/B747/fms/company/fms_file'
    if (-not $fms.Contains($Plan.origin + $Plan.dest)) { throw "the fetched plan is not $($Plan.route): $fms (the latest OFP changed?)" }
    if ($null -eq (Wait-AutoCond { ([string](Get-XPDataref 'laminar/B747/fms3/Line02_S')) -match '^ +CO ROUTE$' } 60 1000)) { throw 'no route uplink' }
    # FMC COMM 1/2, <RTE 1, <LOAD
    Send-Cdu @('PREV', 'L1')
    Start-Sleep -Seconds 1
    Send-Cdu @('L4')
    Start-Sleep -Seconds 4
    $l3 = Get-S 'laminar/B747/fms3/Line03_L'
    if (-not ($l3 -match ('^\s*{0}\s+{1}\s*$' -f $Plan.origin, $Plan.dest))) { throw "the loaded route is not $($Plan.route): '$l3'" }
    Note info ('the route loaded: ' + $l3.Trim())
    # the approach on the route before it is active (a change itself, no MOD)
    Set-AutoApproach $Plan
    Send-Cdu @('RTE', 'R6', 'EXEC')
    Start-Sleep -Seconds 1
    $t1 = Get-CduTitle
    if (-not $t1.Contains('ACT RTE 1')) { throw "RTE 1 not active: '$t1'" }
    Close-AutoDiscontinuities
    Note-Status 'fmc' ('PERF INIT: ZFW {0:0.0} t, reserves {1:0.0} t, CRZ ALT FL{2:000}, CI {3}' -f ($Plan.zfw_kg / 1000), ($Plan.reserves_kg / 1000), ($Plan.crz_ft / 100), $Plan.ci)
    Send-Cdu @('INITREF', 'L6', 'L3')
    if (-not (Get-CduTitle).Contains('PERF INIT')) { throw ('no PERF INIT: ' + (Get-CduTitle)) }
    Send-Cdu @(('{0:0.0}' -f ($Plan.zfw_kg / 1000)), 'L3', ('{0:0.0}' -f ($Plan.reserves_kg / 1000)), 'L4', ('{0:0}' -f ($Plan.crz_ft / 100)), 'R1', ([string]$Plan.ci), 'L5')
    Start-Sleep -Seconds 1
    $crz = Get-N 'laminar/B747/autopilot/dist/cruise_alt'
    if ([math]::Abs($crz - $Plan.crz_ft) -gt 1) { throw ('the FMC''s cruise altitude is {0} (entered {1})' -f $crz, $Plan.crz_ft) }
    Note-Status 'fmc' ('TAKEOFF REF: flaps {0}, the V speeds' -f $Plan.takeoff_flaps)
    Send-Cdu @('L6', 'L5')
    if (-not (Get-CduTitle).Contains('TAKEOFF')) { throw ('no TAKEOFF REF: ' + (Get-CduTitle)) }
    Send-Cdu @([string]$Plan.takeoff_flaps, 'L1', 'R1', 'R2', 'R3')
    Start-Sleep -Seconds 1
    $v2 = Get-N 'laminar/B747/airspeed/V2'
    if ($v2 -ge 900) { throw 'no V speeds (TAKEOFF REF)' }
    Note info ('V1 {0} VR {1} V2 {2}; VNAV valid {3}' -f (Get-N 'laminar/B747/airspeed/V1'), (Get-N 'laminar/B747/airspeed/Vr'), $v2, (Get-N 'laminar/B747/fms/vnav/valid'))
}

# the destination runway's ILS approach on DEP/ARR's ARRIVALS (the inactive
# route's: the DEP ARR key shows the INDEX, B744.fms.pages.deparr.lua
# B747_cdu_deparr_page) unless the uplink has one there (<SEL> beside it),
# with the STAR's last fix as its transition when listed
function Set-AutoApproach($Plan) {
    $open = {
        Send-Cdu @('DEPARR')
        Start-Sleep -Milliseconds 500
        $t = Get-CduTitle
        if ($t.Contains('DEPARTURES')) { Send-Cdu @('L6'); $t = Get-CduTitle }
        if ($t.Contains('DEP/ARR INDEX')) { Send-Cdu @('R2') }
    }
    $pages = Read-CduPages $open
    if (-not ([string]$pages[0][0]).Contains("$($Plan.dest) ARRIVALS")) { Note warn ('DEP/ARR: no {0} ARRIVALS ({1})' -f $Plan.dest, $pages[0][0]); Send-Cdu @('RTE'); return }
    foreach ($pg in $pages) {
        $have = Find-CduText $pg $Plan.approach 'R' -Prefix -Marked
        if ($have) { Note info ('the uplink''s approach {0} ({1})' -f $have.text, $have.mark); Send-Cdu @('RTE'); return }
        $any = @(foreach ($k in 1..6) { Get-CduItems ([string]$pg[2 * $k]) | Where-Object { $_.side -eq 'R' -and $_.mark } })
        if ($any.Count -gt 0) { Note warn ('the uplink''s approach {0}, not {1}: kept' -f $any[0].text, $Plan.approach); Send-Cdu @('RTE'); return }
    }
    $hit = Select-CduItem $open $Plan.approach 'R' -Prefix
    if (-not $hit) { Note warn ('no approach {0} at {1}: the route without one' -f $Plan.approach, $Plan.dest); Send-Cdu @('RTE'); return }
    Start-Sleep -Milliseconds 500
    Set-CduFirstPage
    $msg = 'the approach {0}' -f $hit.text
    if ($Plan.star_end) {
        $pg = Get-CduPageNo (Get-S 'laminar/B747/fms3/Line01_S')
        $n = if ($pg) { $pg[1] } else { 1 }
        $tk = $null
        for ($p = 1; $p -le $n -and -not $tk; $p++) {
            $tk = Find-CduText (Get-CduLines 'L') $Plan.star_end 'R'
            if ($tk) { Send-Cdu @($tk.key) } elseif ($p -lt $n) { Send-Cdu @('NEXT') }
        }
        $msg += $(if ($tk) { ' via ' + $Plan.star_end } else { ', no transition ' + $Plan.star_end })
    }
    Note info $msg
    Send-Cdu @('RTE')
}

# every ROUTE DISCONTINUITY on the active route's LEGS closed: the next
# waypoint into the box, EXEC (one that stays: left, with a warning)
function Close-AutoDiscontinuities {
    $last = $null
    for ($round = 0; $round -lt 8; $round++) {
        Send-Cdu @('LEGS')
        Start-Sleep -Milliseconds 500
        Set-CduFirstPage
        $pg = Get-CduPageNo (Get-S 'laminar/B747/fms3/Line01_S')
        $n = if ($pg) { [math]::Min($pg[1], 40) } else { 1 }
        $found = $null; $at = 0
        for ($p = 1; $p -le $n; $p++) {
            $d = Find-CduDiscontinuity (Get-CduLines 'S')
            if ($d) { $found = $d; $at = $p; break }
            if ($p -lt $n) { Send-Cdu @('NEXT') }
        }
        if (-not $found) { Note info 'LEGS: no route discontinuity'; return }
        $where = '{0}/{1}' -f $at, $found.box
        if ($where -eq $last) { Note warn "LEGS: the route discontinuity at page $where stays"; return }
        $last = $where
        if ($found.next) { Send-Cdu @($found.next, $found.box) } else { Send-Cdu @('NEXT', 'L1', 'PREV', $found.box) }
        Send-Cdu @('EXEC')
        Start-Sleep -Seconds 1
        Note info "LEGS: the route discontinuity at page $where closed"
    }
}

# ---------------------------------------------------------------- the flight

function Set-AutoStd {
    foreach ($side in 'capt', 'fo') {
        if ((Get-N "laminar/B747/efis/baro_std/$side/switch_pos") -eq 0) { Push-Auto "laminar/B747/efis/baro_std/$side/switch" }
    }
    Note info ('altimeters STD at {0:0} ft' -f (Get-N 'sim/cockpit2/gauges/indicators/altitude_ft_pilot'))
}
# the altimeters to X-Plane's QNH at the aircraft (out of STD first: the
# switch back gives the preselected setting, B747.60.xt.fltInst02.lua)
function Set-AutoQnh([string]$Where) {
    $q = $null
    foreach ($d in 'sim/weather/aircraft/qnh_pas', 'sim/weather/region/sealevel_pressure_pas') {
        try { $q = Get-AutoQnhInHg (Get-XPDataref $d) } catch { $q = $null }
        if ($null -ne $q) { break }
    }
    if ($null -eq $q) { Note warn "no QNH ($Where): the altimeters left"; return }
    foreach ($side in 'capt', 'fo') {
        if ((Get-N "laminar/B747/efis/baro_std/$side/switch_pos") -eq 1) { Push-Auto "laminar/B747/efis/baro_std/$side/switch" }
    }
    Set-N 'sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot' $q
    Set-N 'sim/cockpit2/gauges/actuators/barometer_setting_in_hg_copilot' $q
    Note info ('altimeters QNH {0:0.00} in Hg ({1})' -f $q, $Where)
}

function Invoke-AutoTakeoff($Plan) {
    Note-Status 'takeoff' 'flaps, the MCP, trim, F/D, A/T ARM, LNAV and VNAV'
    Set-AutoQnh 'departure'
    Set-Flaps $Plan.takeoff_flaps
    Set-Mcp 'alt' $Plan.crz_ft
    # the takeoff trim: the alternate trim nose down 5.2 s (s109, s141, s198)
    Send-Cmd 'laminar/B747/flt_ctrls/altn_stab_trim_dn' 5.2
    Start-Sleep -Seconds 6
    foreach ($v in 0, 1) {
        [void](Set-AutoSwitch 'laminar/B747/toggle_switch/position[23]' $v 'laminar/B747/toggle_switch/flight_dir_L')
        [void](Set-AutoSwitch 'laminar/B747/toggle_switch/position[24]' $v 'laminar/B747/toggle_switch/flight_dir_R')
        Start-Sleep -Seconds 1
    }
    if ((Get-N 'laminar/B747/autopilot/FMA/active_pitch_mode') -ne 1) { Note warn 'the F/D not in TO/GA' }
    [void](Set-AutoSwitch 'laminar/B747/toggle_switch/position[29]' 1 'laminar/B747/authrottle_arm')
    Push-Auto 'laminar/B747/autopilot/button_switch/LNAV'
    Push-Auto 'laminar/B747/autopilot/button_switch/VNAV'
    Start-Sleep -Seconds 1
    if ((Get-N 'laminar/B747/autopilot/FMA/armed_pitch_mode') -ne 4) { Note warn 'VNAV not armed' }
    $vr = Get-N 'laminar/B747/airspeed/Vr'
    if ($vr -lt 100 -or $vr -gt 220) { throw "no VR ($vr)" }
    Set-N 'laminar/B747/flt_ctrls/parking_brake_ratio' 0
    Start-Sleep -Seconds 3
    Note-Status 'takeoff' ('the takeoff roll on {0} (VR {1:0})' -f $Plan.origin_rwy, $vr)
    Send-Cmd 'FlyWithLua/B747_rudder_hold/start'
    Set-N 'sim/cockpit2/engine/actuators/throttle_ratio_all' 1
    [void](Wait-AutoDref 'laminar/B747/gauges/indicators/airspeed_kts_pilot' '>' $vr 150 'VR' -Must -Ms 200)
    Send-Cmd 'FlyWithLua/B747_rotate/start'
    [void](Wait-AutoDref 'sim/flightmodel/failures/onground_any' '==' 0 30 'liftoff' -Must -Ms 200)
    Send-Cmd 'FlyWithLua/B747_rotate/stop'
    Send-Cmd 'FlyWithLua/B747_fd_follow/start'
    Send-Cmd 'FlyWithLua/B747_rudder_hold/stop'
    Send-Cmd 'sim/flight_controls/landing_gear_up'
    [void](Wait-AutoDref 'sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot' '>' 300 60 'RA 300 ft')
    Send-Cmd 'FlyWithLua/B747_fd_follow/stop'
    Push-Auto 'laminar/B747/autopilot/button_switch/cmd_L'
    [void](Wait-AutoDref 'laminar/B747/autopilot/servos_on' '==' 1 5 'A/P CMD L' -Must)
    Set-N 'sim/cockpit2/controls/yoke_pitch_ratio' 0
    [void](Wait-AutoDref 'laminar/B747/autopilot/FMA/active_pitch_mode' '==' 4 60 'VNAV SPD')
    [void](Wait-AutoDref 'laminar/B747/autopilot/FMA/active_roll_mode' '==' 2 60 'LNAV')
    # the flaps up on the schedule from the acceleration height (1,000 ft)
    [void](Wait-AutoDref 'sim/cockpit2/gauges/indicators/altitude_ft_pilot' '>' ($Plan.origin_elev_ft + 1000) 180 'the acceleration height')
    $sp = Get-AutoSpeeds (Get-N 'laminar/B747/fms/vref30')
    foreach ($s in @(@(10, $sp.f10), @(5, $sp.f5), @(1, $sp.f1), @(0, $sp.up))) {
        if ($s[0] -ge $Plan.takeoff_flaps) { continue }
        [void](Wait-AutoDref 'laminar/B747/gauges/indicators/airspeed_kts_pilot' '>' $s[1] 240 ('the flaps {0} speed {1:0} kt' -f $s[0], $s[1]))
        Set-Flaps $s[0]
    }
    Note-Status 'climb' ('flaps up; {0:0} ft' -f (Get-N 'sim/cockpit2/gauges/indicators/altitude_ft_pilot'))
}

# the climb and the cruise to 28 NM to E/D in the descent
function Watch-AutoCruise($Plan) {
    $std = $false; $qnh = $false; $lowered = $false; $phaseSeen = -1; $fails = 0
    $steps = @($Plan.steps | Where-Object { $null -ne $_.lat })
    foreach ($s in @($Plan.steps | Where-Object { $null -eq $_.lat })) { Note warn ('the step at {0} not on the navlog: left out' -f $s.fix) }
    $si = 0; $stepState = @{ min = $null }; $stepWarned = $false
    $lastLog = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        Start-Sleep -Seconds 5
        Assert-AutoAlive
        try {
            $ed = [double](Get-XPDataref 'laminar/B747/fms/vnav/dist'); $ph = [int](Get-XPDataref 'laminar/B747/fms/vnav/phase')
            $alt = [double](Get-XPDataref 'sim/cockpit2/gauges/indicators/altitude_ft_pilot')
            $gnd = [int](Get-XPDataref 'sim/flightmodel/failures/onground_any'); $hold = [int](Get-XPDataref 'laminar/B747/fms/vnav/td_hold')
            $fails = 0
        } catch {
            $fails++
            if ($fails -ge 60) { throw ('the Web API failed for 5 min: {0}' -f $_.Exception.Message) }
            continue
        }
        if ($gnd -eq 1) { throw 'on the ground before the approach' }
        if ($ph -ne $phaseSeen) { Note-Status $(switch ($ph) { 1 { 'climb' } 2 { 'cruise' } 3 { 'descent' } default { "phase $ph" } }) ('{0:0} ft, E/D {1:0} NM' -f $alt, $ed); $phaseSeen = $ph }
        if (-not $std -and $ph -le 2 -and $alt -gt $Plan.origin_trans_alt_ft + 100) { Set-AutoStd; $std = $true }
        # the OFP's step at its fix: once passed, in the cruise
        if ($afArgs.Steps -eq 'ofp' -and -not $lowered -and $si -lt $steps.Count) {
            $st = $steps[$si]
            $nm = Get-GcNm (Get-N 'sim/flightmodel/position/latitude') (Get-N 'sim/flightmodel/position/longitude') $st.lat $st.lon
            if (Test-AutoPassed $stepState $nm) {
                if ($ph -eq 2) {
                    $before = Get-N 'laminar/B747/autopilot/dist/cruise_alt'
                    Set-Mcp 'alt' $st.ft
                    Start-Sleep -Milliseconds 1500
                    Push-Auto 'laminar/B747/button_switch/press_altitude'
                    Start-Sleep -Seconds 3
                    if ((Get-N 'laminar/B747/autopilot/dist/cruise_alt') -eq $before) { Push-Auto 'laminar/B747/button_switch/press_altitude'; Start-Sleep -Seconds 3 }
                    Note-Status 'cruise' ('the step at {0} to FL{1:000} ({2:0.0} NM from it; CRZ ALT {3})' -f $st.fix, ($st.ft / 100), $nm, (Get-N 'laminar/B747/autopilot/dist/cruise_alt'))
                    $si++; $stepState = @{ min = $null }; $stepWarned = $false
                } elseif (-not $stepWarned) { Note warn ('the step fix {0} passed before the cruise: the step once in it' -f $st.fix); $stepWarned = $true }
            }
        }
        # the MCP down before T/D
        if (-not $lowered -and $ph -ge 2 -and $ed -gt 0 -and $ed -lt (Get-AutoLowerNm (Get-N 'laminar/B747/autopilot/dist/cruise_alt') $Plan.dest_elev_ft)) {
            Set-Mcp 'alt' $Plan.app_mcp_ft; $lowered = $true
            Note-Status 'cruise' ('MCP {0} ft at {1:0} NM to E/D (before T/D)' -f $Plan.app_mcp_ft, $ed)
        }
        if ($hold -eq 1) {
            if (-not $lowered) { Set-Mcp 'alt' $Plan.app_mcp_ft; $lowered = $true; Start-Sleep -Milliseconds 1500 }
            Push-Auto 'laminar/B747/button_switch/press_altitude'
            Note warn ('VNAV held past T/D: the altitude selector pushed ({0:0} NM to E/D)' -f $ed)
            Start-Sleep -Seconds 10
        }
        if (-not $qnh -and $ph -eq 3 -and $alt -lt $Plan.dest_trans_level_ft) { Set-AutoQnh 'destination'; $qnh = $true }
        if ($lastLog.Elapsed.TotalMinutes -ge 10) {
            Note info ('{0:0} ft, M{1:0.000}, {2:0} kt, phase {3}, E/D {4:0} NM, fuel {5:0} kg' -f $alt, (Get-N 'sim/flightmodel/misc/machno'),
                (Get-N 'laminar/B747/gauges/indicators/airspeed_kts_pilot'), $ph, $ed, (Get-N 'sim/flightmodel/weight/m_fuel_total'))
            $lastLog.Restart()
        }
        if ($ph -eq 3 -and $ed -gt 0 -and $ed -lt 28) { break }
    }
    if (-not $qnh) { Set-AutoQnh 'destination' }
}

# from 28 NM to E/D (s198's 4th run on: about 9,000 ft, notes/LINE_FLIGHTS.md
# 3) the approach on the FCOM's maneuver speeds (flaps out at or below the
# speed of the flaps before), the autoland and the stop
function Invoke-AutoApproach($Plan) {
    $v = Get-N 'laminar/B747/fms/vref30'
    $sp = Get-AutoSpeeds $v
    Note-Status 'approach' ('VREF 30 {0:0}: speed intervention {1:0} kt, speedbrake FLT DETENT' -f $v, $sp.f1)
    Push-Auto 'laminar/B747/button_switch/press_airspeed'
    Set-Mcp 'spd' $sp.f1
    [void](Set-AutoSwitch 'laminar/B747/flt_ctrls/speedbrake_lever' 0.53 'sim/flight_controls/speed_brakes_down_one' 'sim/flight_controls/speed_brakes_up_one')
    [void](Wait-AutoDref 'laminar/B747/gauges/indicators/airspeed_kts_pilot' '<' $sp.up 300 ('below the flaps UP speed {0:0} kt' -f $sp.up))
    Set-Flaps 1
    [void](Set-AutoSwitch 'laminar/B747/flt_ctrls/speedbrake_lever' 0 'sim/flight_controls/speed_brakes_down_one' 'sim/flight_controls/speed_brakes_up_one')
    [void](Wait-AutoDref 'laminar/B747/fms/vnav/on_app' '==' 1 1500 'on approach')
    Set-Mcp 'spd' $sp.f5
    [void](Wait-AutoDref 'laminar/B747/gauges/indicators/airspeed_kts_pilot' '<' ($sp.f1 + 5) 240 ('below the flaps 1 speed {0:0} kt' -f $sp.f1))
    Set-Flaps 5
    Push-Auto 'laminar/B747/autopilot/approach'
    Push-Auto 'laminar/B747/autopilot/button_switch/cmd_C'
    Push-Auto 'laminar/B747/autopilot/button_switch/cmd_R'
    Note info ('APP armed (roll {0}, pitch {1}); NAV1 {2}' -f (Get-N 'laminar/B747/autopilot/FMA/armed_roll_mode'), (Get-N 'laminar/B747/autopilot/FMA/armed_pitch_mode'),
        (Get-N 'sim/cockpit2/radios/actuators/nav1_frequency_hz'))
    [void](Wait-AutoDref 'laminar/B747/autopilot/FMA/active_roll_mode' '==' 3 900 'LOC captured' -Must)
    [void](Wait-AutoDref 'sim/cockpit2/radios/indicators/nav1_vdef_dots_pilot' '>' -2.0 900 'G/S alive')
    Set-Flaps 20
    Set-Mcp 'spd' $sp.f20
    Send-Cmd 'sim/flight_controls/landing_gear_down'
    Set-N 'laminar/B747/gear/autobrakes/sel_dial_pos' 4
    Send-Cmd 'sim/flight_controls/speed_brakes_down_one'
    Note-Status 'approach' ('gear down, flaps 20, {0:0} kt, autobrake 2, speedbrake ARM' -f $sp.f20)
    [void](Wait-AutoDref 'laminar/B747/autopilot/FMA/active_pitch_mode' '==' 2 600 'G/S captured' -Must)
    Set-Flaps 30
    Set-Mcp 'spd' $sp.app
    Set-Mcp 'alt' $Plan.app_mcp_ft
    [void](Wait-AutoCond { $a = [int](Get-XPDataref 'laminar/B747/autopilot/AFDS/status_annun_pilot'); $a -eq 3 -or $a -eq 4 } 400 1000)
    $land = [int](Get-N 'laminar/B747/autopilot/AFDS/status_annun_pilot')
    if ($land -eq 4) { Note info 'LAND 3' } elseif ($land -eq 3) { Note warn 'LAND 2' } else { Note warn ('no LAND 3 or 2 (AFDS status {0})' -f $land) }
    Note-Status 'landing' ('{0:0} ft RA, {1:0} kt' -f (Get-N 'sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot'), (Get-N 'laminar/B747/gauges/indicators/airspeed_kts_pilot'))
    [void](Wait-AutoDref 'laminar/B747/autopilot/FMA/active_pitch_mode' '==' 3 600 'FLARE')
    [void](Wait-AutoDref 'sim/flightmodel/failures/onground_any' '==' 1 90 'touchdown' -Must -Ms 200)
    Note info ('touchdown {0:0} fpm, {1:0} kt' -f (Get-N 'sim/flightmodel/position/vh_ind_fpm'), (Get-N 'laminar/B747/gauges/indicators/airspeed_kts_pilot'))
    Send-Cmd 'sim/engines/thrust_reverse_hold' 8
    Start-Sleep -Milliseconds 8200
    [void](Wait-AutoDref 'laminar/B747/gauges/indicators/airspeed_kts_pilot' '<' 60 120 'below 60 kt')
    Set-N 'laminar/B747/flt_ctrls/parking_brake_ratio' 1
    [void](Wait-AutoDref 'sim/flightmodel/position/groundspeed' '<' 0.3 120 'stopped')
    Push-Auto 'laminar/B747/autopilot/button_switch/yoke_disengage_capt'
    Start-Sleep -Seconds 1
    Push-Auto 'laminar/B747/autopilot/button_switch/yoke_disengage_capt'
    Note-Status 'stopped' ('on {0} {1}, fuel {2:0} kg' -f $Plan.dest, $Plan.dest_rwy, (Get-N 'sim/flightmodel/weight/m_fuel_total'))
}

# dot-sourced (tests/flight/perf/auto_flight_offline_test.ps1): the functions only
if ($MyInvocation.InvocationName -eq '.') { return }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:autoOut = if ($afArgs.AutoOut) { $afArgs.AutoOut } else { Join-Path $PSScriptRoot "runs\${stamp}_autoflight" }
if (Test-Path $script:autoOut) { throw "the run's folder exists: $($script:autoOut)" }
New-Item -ItemType Directory -Force -Path $script:autoOut | Out-Null
$ofpPath = Join-Path $script:autoOut 'ofp.json'
if ($afArgs.OfpFile) { Copy-Item $afArgs.OfpFile $ofpPath }
elseif ($afArgs.SimbriefUser) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri ('https://www.simbrief.com/api/xml.fetcher.php?username={0}&json=1' -f [Uri]::EscapeDataString($afArgs.SimbriefUser)) -OutFile $ofpPath -TimeoutSec 60
} else { throw 'give -SimbriefUser <name> or -OfpFile <ofp.json>' }
$json = [IO.File]::ReadAllText($ofpPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$plan = Get-AutoPlan $json (Get-AutoAcf $acfFile)
$init = Get-AutoInit $plan $true
Save-Json (Join-Path $script:autoOut 'plan.json') ([ordered]@{ args = $afArgs; plan = $plan; init = $init })
Note-Status 'plan' ('{0} {1} to {2} {3}: ZFW {4:0.0} t, fuel {5:0.0} t, FL{6:000}, CI {7}, flaps {8}, SID {9}, STAR {10} (to {11}), {12}, steps {13}' -f $plan.origin, $plan.origin_rwy,
    $plan.dest, $plan.dest_rwy, ($plan.zfw_kg / 1000), ($plan.takeoff_fuel_kg / 1000), ($plan.crz_ft / 100), $plan.ci, $plan.takeoff_flaps, $plan.sid, $plan.star, $plan.star_end,
    $plan.approach, $(if ($plan.steps.Count -gt 0) { ($plan.steps | ForEach-Object { '{0} FL{1:000}' -f $_.fix, ($_.ft / 100) }) -join ', ' } else { 'none' }))
if ($plan.custom -ne '1') { Note warn 'the OFP is not on a custom airframe' }
if ($afArgs.DryRun) { [IO.File]::WriteAllLines((Join-Path $script:autoOut 'events.txt'), [string[]]$events, $utf8); "dry run: $($script:autoOut)"; return }

$others = @(Get-AutoOtherRunners)
if ($others.Count -gt 0 -and -not $afArgs.Force) { throw ('another flight runs on X-Plane ({0}): not started (-Force to start anyway)' -f ($others -join '; ')) }
$logProc = $null
$result = 'aborted'
$payloadAtStart = $null
try {
    if ($afArgs.StartXPlane -and -not (Get-Process -Name 'X-Plane' -ErrorAction SilentlyContinue)) {
        Note info 'starting X-Plane (tools\xp_restart.ps1)'
        $up = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '..\tools\xp_restart.ps1'))
        if ($up.Count -eq 0 -or $up[$up.Count - 1] -ne 'up') { throw "X-Plane did not come up: $($up -join ' ')" }
    }
    $caps = Get-XPCapabilities
    Note info ('X-Plane {0}' -f $caps.'x-plane'.version)
    $script:afXtFrom = Get-FileLength $script:afXtErr
    try { $payloadAtStart = Get-N 'sim/flightmodel/weight/m_fixed' } catch { $payloadAtStart = $null }
    [void](Start-AutoFlight $init)
    foreach ($c in 'FlyWithLua/B747_rudder_hold/start', 'FlyWithLua/B747_rotate/start', 'FlyWithLua/B747_fd_follow/start') {
        try { [void](Get-XPCommandId $c) } catch { throw "no $c (tests/flight/fwl into FlyWithLua's Scripts)" }
    }
    if (-not $afArgs.NoLog) {
        $flightDir = Join-Path $script:autoOut 'flight'
        $logProc = Start-Process -PassThru -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
            ('"{0}"' -f (Join-Path $PSScriptRoot 'flight_log.ps1')), '-OfpFile', ('"{0}"' -f $ofpPath), '-FlightOut', ('"{0}"' -f $flightDir), '-MaxHours', [string]$afArgs.MaxHours)
        Note info "flight_log.ps1 recording (pid $($logProc.Id)): $flightDir"
        Start-Sleep -Seconds 15
        if ($logProc.HasExited) { throw "flight_log.ps1 ended at once (exit $($logProc.ExitCode))" }
    }
    Set-AutoFmc $plan
    Invoke-AutoTakeoff $plan
    Watch-AutoCruise $plan
    Invoke-AutoApproach $plan
    $result = 'stopped on the runway'
} catch {
    Note fail ('auto flight: {0}' -f $_.Exception.Message)
    Note-Status 'failed' $_.Exception.Message
    $gnd = $null
    try { $gnd = Get-N 'sim/flightmodel/failures/onground_any' } catch { }
    if ($null -ne $logProc -and -not $logProc.HasExited -and $gnd -eq 1) {
        New-Item -ItemType File -Force -Path (Join-Path $script:autoOut 'flight\STOP') | Out-Null
        Note info 'flight_log.ps1 told to stop (on the ground)'
    }
} finally {
    [IO.File]::WriteAllLines((Join-Path $script:autoOut 'events.txt'), [string[]]$events, $utf8)
}
if ($null -ne $logProc) {
    Note info 'waiting for flight_log.ps1 (it ends 2 min after the stop)'
    try { $logProc | Wait-Process -Timeout 900 } catch { Note warn 'flight_log.ps1 still running' }
}
if ($null -ne $payloadAtStart) {
    try {
        if ((Get-N 'sim/flightmodel/failures/onground_any') -eq 1) {
            Set-N 'sim/flightmodel/weight/m_fixed' $payloadAtStart
            Note info ('the payload back to {0:0.0} kg, as the run found it' -f $payloadAtStart)
        }
    } catch { Note warn ('the payload not put back: {0}' -f $_.Exception.Message) }
}
[IO.File]::WriteAllLines((Join-Path $script:autoOut 'events.txt'), [string[]]$events, $utf8)
"auto flight: $result; $($script:autoOut)"
