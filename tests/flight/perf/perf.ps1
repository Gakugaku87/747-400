# Performance measurement mode of the flight-test kit (PERF_SIMBRIEF.md in the
# repository's root; docs/overhaul/TESTING.md 4.7): the custom acf measured for
# a SimBrief custom airframe on the B744 base. Unattended: one run a script,
# its files read afterwards.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\perf\perf.ps1 -Suite check|cruise|climb [-StartXPlane] [-Only <ids>]
#
# -StartXPlane starts X-Plane when it is not running (tools\xp_restart.ps1:
# the custom acf on RJAA 34L once, the throwaway first flight after a start).
# -Only runs the suite's levels (cruise, e.g. crz_l15_fl390), tests (climb,
# e.g. cel_l15) or points (check) listed, comma-separated, in the suite's
# order; the run's folder ends in _part and meta.json's only lists them (a
# re-measure after an aircraft fix: 2026-11-07, the 15 t FL390 points after
# the fuel per thrust above FL370, notes/AERO.md 3.18).
#
# Suites
#   check  phase 0. Two air starts over the sea east of Choshi (35.40N 141.30E,
#          090 true) in still ISA air, 40 t of payload: 78 % of the MTOW
#          (the FCOM's, below) at FL350 and 90 % at FL310, both M.85. Each: the
#          engines burning; the payload and every tank read back against the
#          flight's weights; the A/P in ALT and the A/T in SPD on the MCP's
#          Mach; held within 30 ft, M.003 and 100 fpm for 60 s (in 6 min);
#          then 180 s of the fuel's weight going down against the FF gauges'
#          sum; the payload, the zero fuel weight and the fuel watched for
#          writes by the aircraft from the logger's start to the end.
#   cruise phase 1 (plan A). The same place and air: an air start for each
#          weight and level, the Machs .85, .86, .87 in place (Get-PerfLevels:
#          11 levels, 33 points, the weights 238.5 t, 78 % and 90 % of the
#          MTOW at FL310-390 below the FCOM's maximum altitude). Each point:
#          60 s within the limits (in 6 min, else unstable, or hold_unable
#          below its Mach with the A/T in SPD), then 180 s averaged. First
#          the CI 200's economy cruise Mach off the CDU at 78 % and FL350; at
#          the end 78 % FL350 M.85 again (the flows within 1 %).
#   climb  phase 2. The same place and air, the same three weights
#          (Get-PerfClimbTests). Climbs: an air start at 10,000 ft and 250
#          kt, level there, then FLCH to FL350 (90 %: FL330) on the
#          schedule 250/340/84 (340 kt, Mach .84 once the Mach reaches it);
#          the time, fuel and distance at every 5,000 ft and at the top.
#          Descents: from those tops at M.84, FLCH (idle) to 10,000 ft on
#          84/340/250 (M.84, then 340 kt once that is M.84's CAS); the same
#          at every 5,000 ft and at 10,000 ft.
#          Ceilings: an air start at FL310 and M.85, then FLCH to 45,000 ft at
#          M.85 until the climb rate (60 s of pressure altitude) falls below
#          100 fpm or the aircraft reaches the FCOM's 1.30 g altitude at its
#          weight, whichever first (the FCOM's criteria): that altitude.
#
# PERF_SIMBRIEF.md's rules: the custom acf only; no file of the aircraft,
# X-Plane or a plugin written (a flight's datarefs and commands only); no time
# acceleration (rows with sim_speed or ground_speed not 1, or paused, left
# out of the means); the flows on sim time (sim/time/total_running_time_sec);
# the burn from the fuel's weight (m_fuel_total), the FF gauges
# (fuel_flow_kg_sec) beside it; a run's folder never overwritten.
#
# Output: tests\flight\perf\runs\<yyyyMMdd_HHmmss>_<suite>[_part]\ (local only)
#   meta.json        the aircraft's commit, the acf's SHA-256, X-Plane's
#                    version, the date, the suite, the points, the aircraft's
#                    weights and where they come from
#   init_<id>.json   each point's flight init
#   raw\<id>.csv     1 s rows: the means (states: the last value) of the
#                    WebSocket's samples (about 10 Hz, changed values only,
#                    each held) in each second of sim time; wall_s, samples
#   points.csv       a row a point (PERF_SIMBRIEF.md's columns)
#   climb.csv        (climb) a row a mark: every 5,000 ft of a climb, every
#                    1,000 ft of a ceiling's; ceiling.csv a row a ceiling
#   check.json       the checks; check.md the same as tables
#   events.txt       the run's notes; log_excerpt.txt Log.txt's lines of the
#                    run that look like errors; xtlua_errors.txt if any
param(
    [ValidateSet('check', 'cruise', 'climb')][string]$Suite = 'check',
    [switch]$StartXPlane,
    [string]$RunsDir,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\xp.ps1')

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
# (2026-11-12) the aircraft folder this kit is in, whatever its name (xp.ps1);
# before, Aircraft/747-400-master by name
$acfRel = Get-XPAircraftRel 'custom'
$acfFile = Join-Path $repo (Split-Path -Leaf $acfRel)
$LB = 0.45359237
$inv = [Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object Text.UTF8Encoding($false)

# PERF_SIMBRIEF.md's fill-in table (the user, 2026-11-06): the typical payload
$PayloadKg = 40000.0
# the maximum takeoff weight, for the points' gross weights and SimBrief: the
# FCOM's for the 109 (PW4056), 394,625 kg (FCOM p.78, L.10.2; the user,
# 2026-11-06). Until 2026-11-14 not the acf's maximum weight (acf_m_max,
# 850,000 lb); since then the custom acf's is the same, 870,000 lb (the
# user asked for the acf's maximum weight to be the source's)
$MtowKg = 394625.0
$MtowSource = 'FCOM p.78 (L.10.2), airplane 109 (the user, 2026-11-06)'
# the maximum zero fuel and landing weights: none in the aircraft; the FCOM's
# for the 109 too (FCOM p.78, L.10.2; the user, 2026-11-06)
$MzfwKg = 244939.0
$MlwKg = 285763.0
# over the sea, no terrain near (the kit's cruise measurements' area)
$StartLat = 35.40
$StartLon = 141.30
$StartHdgTrue = 90.0
# the MCP altitude written before an air start: the FMC's in-flight start sets
# it to the altitude then (B747.68.xt.fms.lua fin_activate_inflightAP), so a
# value other than this one says that start has run
$McpAltMark = 49000

$points = @(switch ($Suite) {
    'check' {
        [ordered]@{ id = 'chk_078_fl350_m085'; gw_pct = 78; fl = 350; mach = 0.85; measure_s = 180 }
        [ordered]@{ id = 'chk_090_fl310_m085'; gw_pct = 90; fl = 310; mach = 0.85; measure_s = 180 }
    }
})

# PERF_SIMBRIEF.md phase 1 (suite cruise). The light weight: the empty
# weight, the typical payload and 15 t of reserve fuel (238.5 t, 60 % of the
# MTOW); 78 % and 90 % of the MTOW. Each point averaged over 180 s.
$LightFuelKg = 15000.0
$MeasureS = 180
# The fill-in table's usual cruise, CI 200. Its economy cruise Mach, by the
# FMC's own function (B747.68.perf_db.lua econ_cruise; the FMC's
# update_econ, B747.68.xt.fms.lua 1133-1155), is M.858 at 307.8 t and FL350
# and M.855-.861 at 238-355 t and FL310-390: the Machs .85-.87 bracket it
# (the run reads it off the CDU too).
$CruiseCi = 200
$CruiseMachs = @(0.85, 0.86, 0.87)
# The levels: an air start each, the Machs in place (phase 1: the fuel used
# meanwhile in each point's own mean weight). Left out above the FCOM's
# maximum operating altitude (PI.11.1, p.267; ISA+10 and colder, 1.30 g, 39
# degrees of bank; B747.68.perf_db.lua max_alt the same): 307.8 t 37,600 ft
# (FL390 out), 355.2 t 34,600 ft (FL350-390 out); 238.5 t 42,900 ft. First
# 78 % at FL350 with the CI's Mach; at the end its M.85 again, the repeat
# (phase 1: the two flows within 1 %).
function Get-PerfLevels {
    $l = New-Object System.Collections.ArrayList
    [void]$l.Add([ordered]@{ id = 'crz_078_fl350'; gw_pct = 78; fl = 350; machs = $CruiseMachs; ci_check = $true })
    foreach ($fl in 310, 330, 370) { [void]$l.Add([ordered]@{ id = "crz_078_fl$fl"; gw_pct = 78; fl = $fl; machs = $CruiseMachs }) }
    foreach ($fl in 310, 330, 350, 370, 390) { [void]$l.Add([ordered]@{ id = "crz_l15_fl$fl"; fuel_kg = $LightFuelKg; fl = $fl; machs = $CruiseMachs }) }
    foreach ($fl in 310, 330) { [void]$l.Add([ordered]@{ id = "crz_090_fl$fl"; gw_pct = 90; fl = $fl; machs = $CruiseMachs }) }
    [void]$l.Add([ordered]@{ id = 'rep_078_fl350'; gw_pct = 78; fl = 350; machs = @(0.85); repeat_of = 'crz_078_fl350_m850' })
    return ,$l.ToArray()
}
function Get-PerfPointId([string]$Level, [double]$Mach) { return ('{0}_m{1:D3}' -f $Level, [int][math]::Round($Mach * 1000)) }
$levels = @()
if ($Suite -eq 'cruise') { $levels = Get-PerfLevels }

# PERF_SIMBRIEF.md phase 2 (suite climb). The climbs and the descents fly the
# comparison OFPs' schedules: those of the user's latest B744 OFP (fetched
# 2026-11-07: the climb 250/340/84, the descent 84/340/250; the user: match
# the OFP and measure the descent too; before that 250/300/78). The climbs: 250 kt below
# 10,000 ft (the start), 340 kt above, Mach .84 once 340 kt reaches it (about
# 27,250 ft in ISA; the aircraft's own climb changeover to Mach is at M.84
# too, B747.70.xt.autopilot.lua 2484-2495, FCOM p.643). The marks every 5,000
# ft and the top: FL350, for 90 % (355.2 t) FL330 under its maximum operating
# altitude 34,590 ft (FCOM PI.11.1 p.267, 1.30 g)
$ClimbStartFt = 10000
$ClimbStartKias = 250
$ClimbKias = 340
$ClimbMach = 0.84
$ClimbMarksFt = @(15000, 20000, 25000, 30000)
# the top's mark this far below it, the bottom's above (the capture's last
# feet left out)
$ClimbTopMarginFt = 30
# The descents (optional in PERF_SIMBRIEF.md; the user, 2026-11-07): from the
# climbs' tops at M.84, FLCH (idle) to 10,000 ft on 84/340/250: M.84 while
# its CAS is under 340 kt, then 340 kt (250 below 10,000 ft, not flown). Above
# 310 kt in a descent the aircraft puts the MCP from Mach into IAS
# (B747.70.xt.autopilot.lua 2496-2507; FCOM p.643): from then the kit keeps
# the IAS window on M.84's CAS (whole knots) until that is 340 kt. The marks
# every 5,000 ft and 30 ft above 10,000 ft.
$DescentMach = 0.84
$DescentKias = 340
$DescentEndFt = 10000
$DescentMarksFt = @(30000, 25000, 20000, 15000)
# The ceilings (PERF_SIMBRIEF.md phase 2; the FCOM's criteria since
# 2026-11-08, the user): from FL310 at M.85 in FLCH (the climb thrust) until
# the climb rate falls below 100 fpm (the thrust-limited altitude's residual
# climb, FCOM p.267, PI.11.1; the FMC's MAX ALT's default, p.1350, 11.42.6)
# or the aircraft reaches the FCOM's 1.30 g altitude at its weight (below),
# whichever first. Before, 300 fpm: that was where M.85 met the amber band's
# top and the AFDS's speed protection (p.675) took the speed up, not where
# the thrust ran out (the 2026-11-08 ceilings climbed on at 250-310 fpm on
# the band's top). The rate: a straight line through 60 s of pressure
# altitude, at the window's middle (the light weights' ALT HOLD swung 10.5 s,
# 130 fpm: phase 1), once over 600 fpm and then under 100 for 10 s. The MCP
# at 45,000 ft, under the FCOM's maximum operating altitude 45,100 ft (p.77,
# L.10.1). Marks every 1,000 ft.
$CeilingStartFt = 31000
$CeilingMach = 0.85
$CeilingRateFpm = 100
$CeilingArmFpm = 600
$CeilingWinS = 60
$CeilingHoldS = 10
$CeilingTopFt = 45000
$CeilingMarksFt = @(32..44 | ForEach-Object { 1000.0 * $_ })
# FCOM p.267 (PI.11.1, the long range cruise maximum operating altitude, max
# climb thrust, ISA+10 and colder): the altitude with 1.30 g to initial
# buffet (39 degrees of bank) by the weight (t); B747.68.perf_db.lua max_alt
# (the FMC's MAX ALT) has the same table. At every weight it is below the
# thrust-limited altitude (the starred 1.20 g column, 100 fpm). Linear
# between the weights, the ends beyond them.
$FcomBuffet130T = @(400, 380, 360, 340, 320, 300, 280, 260, 240, 220, 200, 180)
$FcomBuffet130Ft = @(32100, 33200, 34300, 35500, 36800, 38100, 39600, 41100, 42800, 44600, 45000, 45000)
function Get-PerfFcomBuffet130Ft([double]$GwKg) {
    $wt = $GwKg / 1000
    $tw = $FcomBuffet130T; $ta = $FcomBuffet130Ft
    if ($wt -ge $tw[0]) { return [double]$ta[0] }
    for ($i = 1; $i -lt $tw.Count; $i++) {
        if ($wt -ge $tw[$i]) { return $ta[$i - 1] + ($tw[$i - 1] - $wt) / ($tw[$i - 1] - $tw[$i]) * ($ta[$i] - $ta[$i - 1]) }
    }
    return [double]$ta[$tw.Count - 1]
}
function Get-PerfClimbTests {
    $l = New-Object System.Collections.ArrayList
    [void]$l.Add([ordered]@{ id = 'clb_l15'; kind = 'climb'; fuel_kg = $LightFuelKg; top_ft = 35000 })
    [void]$l.Add([ordered]@{ id = 'clb_078'; kind = 'climb'; gw_pct = 78; top_ft = 35000 })
    [void]$l.Add([ordered]@{ id = 'clb_090'; kind = 'climb'; gw_pct = 90; top_ft = 33000 })
    [void]$l.Add([ordered]@{ id = 'des_l15'; kind = 'descent'; fuel_kg = $LightFuelKg; from_ft = 35000 })
    [void]$l.Add([ordered]@{ id = 'des_078'; kind = 'descent'; gw_pct = 78; from_ft = 35000 })
    [void]$l.Add([ordered]@{ id = 'des_090'; kind = 'descent'; gw_pct = 90; from_ft = 33000 })
    [void]$l.Add([ordered]@{ id = 'cel_l15'; kind = 'ceiling'; fuel_kg = $LightFuelKg })
    [void]$l.Add([ordered]@{ id = 'cel_078'; kind = 'ceiling'; gw_pct = 78 })
    [void]$l.Add([ordered]@{ id = 'cel_090'; kind = 'ceiling'; gw_pct = 90 })
    return ,$l.ToArray()
}
$tests = @()
if ($Suite -eq 'climb') { $tests = Get-PerfClimbTests }

# -Only: the suite's items with those ids, in the suite's order. Commas split
# them (powershell -File hands "a,b" over as one string); an id not in the
# suite stops the run before X-Plane is touched.
function Select-PerfOnly($Items, [string[]]$Ids) {
    $want = @($Ids | ForEach-Object { ([string]$_) -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($want.Count -eq 0) { return ,@($Items) }
    $have = @($Items | ForEach-Object { [string]$_.id })
    $unknown = @($want | Where-Object { $have -notcontains $_ })
    if ($unknown.Count -gt 0) { throw ('-Only: not in the suite: {0} (its ids: {1})' -f ($unknown -join ', '), ($have -join ', ')) }
    return ,@($Items | Where-Object { $want -contains [string]$_.id })
}

$wall = [Diagnostics.Stopwatch]::StartNew()
$events = New-Object System.Collections.ArrayList
function Note([string]$Level, [string]$Text) {
    $s = $wall.Elapsed.TotalSeconds
    $line = '[{0,7}s] {1,-4} {2}' -f $s.ToString('0.0', $inv), $Level.ToUpper(), $Text
    Write-Host $line
    [void]$events.Add($line)
}
# plain data for the JSON files: dictionaries, lists, custom objects, strings,
# numbers and booleans; anything else becomes its string. PowerShell 5.1's
# ConvertTo-Json walks every property of what it is given: a line read with
# Get-Content carries PSDrive and PSProvider, and at -Depth 30 that took it
# through the type system without end (the check run of 2026-11-06 grew to
# 79 GB, 3.5 hours writing meta.json)
function ConvertTo-PlainData($V, [int]$Depth = 0) {
    if ($null -eq $V) { return $null }
    $b = $V.PSObject.BaseObject
    if ($b -is [string] -or $b -is [char]) { return [string]$b }
    if ($b -is [decimal] -or $b.GetType().IsPrimitive) { return $b }
    if ($Depth -ge 20) { return [string]$b }
    if ($b -is [Collections.IDictionary]) {
        $o = [ordered]@{}
        foreach ($k in @($b.Keys)) { $o[[string]$k] = ConvertTo-PlainData $b[$k] ($Depth + 1) }
        return $o
    }
    if ($b -is [Management.Automation.PSCustomObject]) {
        # the properties are the wrapper's (the base is one shared instance)
        $o = [ordered]@{}
        foreach ($p in $V.PSObject.Properties) { $o[$p.Name] = ConvertTo-PlainData $p.Value ($Depth + 1) }
        return $o
    }
    if ($b -is [Collections.IEnumerable]) {
        $l = New-Object Collections.ArrayList
        foreach ($e in $b) { [void]$l.Add((ConvertTo-PlainData $e ($Depth + 1))) }
        return ,$l.ToArray()
    }
    if ($b -is [datetime]) { return $b.ToString('o', $inv) }
    return [string]$b
}
function Save-Json([string]$Path, $Obj) { [IO.File]::WriteAllText($Path, (ConvertTo-Json (ConvertTo-PlainData $Obj) -Depth 30), $utf8) }
function F([double]$V, [string]$Fmt = '0.###') {
    if ([double]::IsNaN($V) -or [double]::IsInfinity($V)) { return 'NaN' }
    return $V.ToString($Fmt, $inv)
}
function Get-FileLength([string]$Path) { if (Test-Path $Path) { return (Get-Item $Path).Length } return 0 }
function Get-FileTail([string]$Path, [long]$From) {
    if (-not (Test-Path $Path)) { return @() }
    $fs = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try {
        if ($fs.Length -le $From) { return @() }
        [void]$fs.Seek($From, 'Begin')
        $text = (New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)).ReadToEnd()
    } finally { $fs.Dispose() }
    return @($text -split "`r?`n" | Where-Object { $_ -ne '' })
}
# a file's first line as a plain string (Get-Content's carries PSDrive and PSProvider)
function Get-FirstLine([string]$Path) {
    if (-not (Test-Path $Path)) { return $null }
    $fs = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try { return (New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)).ReadLine() } finally { $fs.Dispose() }
}

# ---------------------------------------------------------------- the run's record

function Get-GitInfo {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $head = ((& git -C $repo rev-parse HEAD 2>$null) | Out-String).Trim()
        $branch = ((& git -C $repo rev-parse --abbrev-ref HEAD 2>$null) | Out-String).Trim()
        $changed = @(& git -C $repo status --porcelain --untracked-files=no 2>$null)
        $acfCommit = ((& git -C $repo log -1 '--format=%H %ad' -- 747-400_custom.acf 2>$null) | Out-String).Trim()
    } finally { $ErrorActionPreference = $eap }
    return [ordered]@{ commit = $head; branch = $branch; tracked_changes = $changed.Count; changed = @($changed); acf_last_commit = $acfCommit }
}

# X-Plane's four points of the fuel per thrust: the acf's _jet_SFC_<point>
# (lb/lbf/h), the datarefs sim/aircraft/overflow/jet_SFC_<point> in kg/(N s)
# (1 lb/lbf/h = 1 / (3600 x 9.80665) kg/(N s), as tests/eec's). Since
# 2026-11-07 the aircraft writes those each frame as the acf's x (1 + a table
# by pressure altitude: 0 to FL370, FL390 +1.8 %; B747.42.xt.sfc_corr.lua,
# notes/AERO.md 3.18): the logger records them, a window their factor.
$SfcPoints = @('takeoff', 'climb', 'locrz', 'hicrz')
$SfcKgNsPerLbLbfH = 1 / 3600 / 9.80665
function Get-PerfAcfSfc($Keys) {
    $s = [ordered]@{}
    foreach ($k in $SfcPoints) {
        $s[$k] = $null
        if ($Keys.Contains("_jet_SFC_$k")) { $s[$k] = [double]::Parse($Keys["_jet_SFC_$k"].value, $inv) * $SfcKgNsPerLbLbfH }
    }
    return $s
}
$script:acfSfc = $null

# the acf's lines for the weights (pounds in the file), the payload stations,
# the tanks and the fuel per thrust (lb/lbf/h): key -> @{ line; value }
function Read-AcfKeys([string]$File) {
    $want = @{}
    foreach ($k in '_m_empty', '_m_max', '_m_fuel_max_tot') { $want[$k] = $true }
    foreach ($i in 0..8) { foreach ($k in '_fixed_max', '_fixed_name', '_tank_rat', '_tank_name') { $want["$k/$i"] = $true } }
    foreach ($k in $SfcPoints) { $want["_jet_SFC_$k"] = $true }
    $found = [ordered]@{}
    $n = 0
    foreach ($line in [IO.File]::ReadLines($File)) {
        $n++
        if (-not $line.StartsWith('P acf/')) { continue }
        $sp = $line.IndexOf(' ', 6)
        if ($sp -lt 0) { continue }
        $k = $line.Substring(6, $sp - 6)
        if ($want.ContainsKey($k)) { $found[$k] = [ordered]@{ line = $n; value = $line.Substring($sp + 1) } }
    }
    return $found
}

# the loaded aircraft's settings, read from X-Plane (CLAUDE.md: not fixed values)
function Get-PerfAircraft {
    $c = [ordered]@{}
    $c.acf_path = [string](Get-XPDataref 'sim/aircraft/view/acf_relative_path')
    $c.livery_path = [string](Get-XPDataref 'sim/aircraft/view/acf_livery_path')
    $c.engine_type = [int](Get-XPDataref 'laminar/B747/engines/type')
    $c.simconfig_engines = $null
    $c.simconfig_std_pax_weight = $null
    try {
        $sc = [string](Get-XPDataref 'laminar/B747/simconfig')
        if ($sc) {
            $j = $sc | ConvertFrom-Json
            $c.simconfig_engines = $j.PLANE.engines
            $c.simconfig_std_pax_weight = $j.SIM.std_pax_weight
        }
    } catch { }
    $c.num_engines = [int](Get-XPDataref 'sim/aircraft/engine/acf_num_engines')
    $c.m_empty_kg = [double](Get-XPDataref 'sim/aircraft/weight/acf_m_empty')
    $c.m_max_kg = [double](Get-XPDataref 'sim/aircraft/weight/acf_m_max')
    $c.m_fuel_tot_kg = [double](Get-XPDataref 'sim/aircraft/weight/acf_m_fuel_tot')
    $c.tank_rat = @(Get-XPDataref 'sim/aircraft/overflow/acf_tank_rat' | ForEach-Object { [double]$_ })
    return $c
}

# ---------------------------------------------------------------- the flight

# the fuel by X-Plane's tank (0 centre, 1-4 mains, 5-6 reserves 2 and 3, 7
# stabilizer) in the aircraft's own load order (B747.25.xt.fuel.lua
# fuel_distribution): mains 1-4 evenly, the overflow of mains 1 and 4 to 2 and
# 3, theirs to the reserves, theirs to the centre, its to the stabilizer
function Get-FuelByTank([double]$Total, [double[]]$Cap) {
    $m1 = $Total / 4; $m2 = $m1; $m3 = $m1; $m4 = $m1
    $r2 = 0.0; $r3 = 0.0; $ctr = 0.0; $stab = 0.0
    if ($m1 -gt $Cap[1]) { $m2 += $m1 - $Cap[1]; $m1 = $Cap[1] }
    if ($m4 -gt $Cap[4]) { $m3 += $m4 - $Cap[4]; $m4 = $Cap[4] }
    if ($m2 -gt $Cap[2]) { $r2 = $m2 - $Cap[2]; $m2 = $Cap[2] }
    if ($m3 -gt $Cap[3]) { $r3 = $m3 - $Cap[3]; $m3 = $Cap[3] }
    if ($r2 -gt $Cap[5]) { $ctr = $r2 - $Cap[5]; $r2 = $Cap[5] }
    if ($r3 -gt $Cap[6]) { $ctr += $r3 - $Cap[6]; $r3 = $Cap[6] }
    if ($ctr -gt $Cap[0]) { $stab = $ctr - $Cap[0]; $ctr = $Cap[0] }
    return ,([double[]]@($ctr, $m1, $m2, $m3, $m4, $r2, $r3, $stab, 0.0))
}

function Get-IsaTempK([double]$Ft) {
    $h = $Ft * 0.3048
    if ($h -le 11000) { return 288.15 - 0.0065 * $h }
    return 216.65
}
function Get-IsaC([double]$Ft) { return (Get-IsaTempK $Ft) - 273.15 }
# ISA pressure (Pa) at a pressure altitude: the troposphere, then the
# isothermal layer from 11 km
function Get-IsaPressurePa([double]$Ft) {
    $h = $Ft * 0.3048
    if ($h -le 11000) { return 101325 * [math]::Pow(1 - 2.25577e-5 * $h, 5.25588) }
    return 22632.06 * [math]::Exp(-1.576885e-4 * ($h - 11000))
}
# the Mach of a calibrated airspeed (kt) at a pressure altitude (subsonic:
# the impact pressure at sea level's speed of sound, 661.4786 kt)
function Get-MachFromCas([double]$Kcas, [double]$Ft) {
    $qc = 101325 * ([math]::Pow(1 + 0.2 * [math]::Pow($Kcas / 661.4786, 2), 3.5) - 1)
    return [math]::Sqrt(5 * ([math]::Pow($qc / (Get-IsaPressurePa $Ft) + 1, 1 / 3.5) - 1))
}
# the calibrated airspeed (kt) of a Mach at a pressure altitude (subsonic)
function Get-CasFromMach([double]$Mach, [double]$Ft) {
    $qc = (Get-IsaPressurePa $Ft) * ([math]::Pow(1 + 0.2 * $Mach * $Mach, 3.5) - 1)
    return 661.4786 * [math]::Sqrt(5 * ([math]::Pow($qc / 101325 + 1, 1 / 3.5) - 1))
}
# the descent's speed at a pressure altitude on 84/340/250 (to 10,000 ft):
# M.84 while its CAS is under 340 kt (mach_phase, cas_kt its CAS), else 340 kt
function Get-PerfDescentSpeed([double]$Ft) {
    $cas = Get-CasFromMach $DescentMach $Ft
    if ($cas -lt $DescentKias) { return [ordered]@{ mach_phase = $true; cas_kt = $cas } }
    return [ordered]@{ mach_phase = $false; cas_kt = [double]$DescentKias }
}

function New-PerfInit($Pt, [double[]]$Payload, [double[]]$Tanks) {
    $ft = [double]$Pt.fl * 100
    $tas = [double]$Pt.mach * [math]::Sqrt(1.4 * 287.05287 * (Get-IsaTempK $ft))
    # still air at every layer, no turbulence (PERF_SIMBRIEF.md)
    $winds = @()
    foreach ($a in 0, 1000, 3000, 6000, 10000, 15000, 20000, 25000, 30000, 34000, 38000, 42000, 46000) {
        $winds += [ordered]@{ altitude_in_feet_msl = $a; speed_in_knots = 0; direction_in_degrees_true = 0
            gust_increase_in_knots = 0; shear_in_degrees = 0; turbulence_ratio = 0 }
    }
    return [ordered]@{
        aircraft = [ordered]@{ path = $acfRel }
        lle_air_start = [ordered]@{ latitude = $StartLat; longitude = $StartLon
            elevation_in_meters = [math]::Round($ft * 0.3048, 1); heading_true = $StartHdgTrue
            speed_in_meters_per_second = [math]::Round($tas, 2) }
        engine_status = [ordered]@{ all_engines = [ordered]@{ running = $true } }
        local_time = [ordered]@{ day_of_year = 295; time_in_24_hours = 10.0 }
        weight = [ordered]@{
            payload_weight_in_kilograms = @($Payload | ForEach-Object { [math]::Round($_, 1) })
            fueltank_weight_in_kilograms = @($Tanks | ForEach-Object { [math]::Round($_, 1) })
        }
        weather = [ordered]@{
            # ISA: 15 C and 1013.25 hPa at the sea (the defaults, written out)
            definition = [ordered]@{ latitude_in_degrees = $StartLat; longitude_in_degrees = $StartLon
                elevation_in_meters = 0; visibility_in_kilometers = 40
                temperature_in_degrees_celsius = 15; altimeter_setting_in_hpa = 1013.25
                precipitation_ratio = 0; clouds = @(); wind = $winds }
            vertical_speed_in_thermal_in_feet_per_minute = 0
            wave_height_in_meters = 0.5
            wave_direction_in_degrees = 0
            terrain_state = 'dry'
            variation_across_region_percentage = 0
            evolution_over_time_enum = 'static'
        }
    }
}

# POST /flight; an HTTP error (a rejected init) stops the run, a timeout while
# X-Plane loads does not (xp.ps1's Start-XPFlight warns on both, and a
# rejected init would leave the old flight running)
function Invoke-PerfFlight($Init, [int]$TimeoutSec = 600) {
    $json = ConvertTo-Json $Init -Depth 30 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    try {
        [void](Invoke-WebRequest -UseBasicParsing -Method POST -Uri ($script:XPBase + '/flight') `
            -ContentType 'application/json' -Body $bytes -TimeoutSec $TimeoutSec)
    } catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if ($null -ne $resp) {
            $body = ''
            try { $body = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd() } catch { }
            throw ('POST /flight: HTTP {0} {1}' -f [int]$resp.StatusCode, $body)
        }
        Write-Warning "POST /flight: $($_.Exception.Message) (the wait below decides)"
    }
    $script:XPDrefs = @{}
    $script:XPCmds = @{}
    return (Wait-XPSimRunning -TimeoutSec $TimeoutSec)
}

# The air start as the kit's runner does it (run_scenario.ps1
# Confirm-AirStartEngines): 8 s on, every engine burning fuel, else again;
# with all burning, once more for the point's own start. The MCP altitude
# mark before each start (above).
function Start-PerfAirStart($Init) {
    $crashed = 0
    try { $crashed = [int](Get-XPDataref 'sim/flightmodel2/misc/has_crashed') } catch { }
    if ($crashed -eq 1) { throw 'the flight before crashed (has_crashed 1): an air start would fall (TESTING.md 4.6)' }
    Set-PerfMcpMark
    $t = Invoke-PerfFlight $Init
    Note info ('air start (sim time {0} s)' -f (F $t '0.0'))
    for ($try = 1; $try -le 3; $try++) {
        Start-Sleep -Seconds 8
        $burning = @(Get-XPDataref 'sim/flightmodel2/engines/engine_is_burning_fuel')
        $off = @(0..3 | Where-Object { [int]$burning[$_] -ne 1 } | ForEach-Object { $_ + 1 })
        Set-PerfMcpMark
        $t = Invoke-PerfFlight $Init
        if ($off.Count -eq 0) {
            Note info ('every engine burning 8 s on: the air start once more for the point (sim time {0} s)' -f (F $t '0.0'))
            Set-PerfSimOptionsOff
            return $t
        }
        Note warn ('engines {0} not burning 8 s after the air start: the air start again (sim time {1} s)' -f ($off -join ','), (F $t '0.0'))
    }
    Set-PerfSimOptionsOff
    return $t
}
# The aircraft's native plugin's sim options (Plugins > 747-400: the
# automatic step climb and the pause before the T/D), read from the user's
# preferences (Output/preferences/B747-400_options.prf) at each load: off
# for the measurement, not saved (a write does not save them; the kit's
# runner does the same, run_scenario.ps1, 2026-11-08). The step climb acts
# only in VNAV (B747.68.simopts_model.lua M.step), which the kit does not
# fly, so the runs of 11-06 to 11-08 (the user's step climb on) were not
# touched by it. The options as the run first found them are put back at
# its end (2026-11-09): left zeroed in memory, the FMS bridge's next save
# (its menu, an option's command, a Pilot ID) would write them over the
# user's file (the fuel session's note).
$script:perfOptsWas = $null
function Set-PerfSimOptionsOff {
    if ($null -eq $script:perfOptsWas) {
        $script:perfOptsWas = [ordered]@{}
        foreach ($k in 'auto_step_climb', 'pause_at_td', 'auto_fuel_mgmt') {
            try { $script:perfOptsWas[$k] = [int](Get-XPDataref ('laminar/B747/options/' + $k)) } catch { }
        }
    }
    foreach ($opt in 'laminar/B747/options/auto_step_climb', 'laminar/B747/options/pause_at_td') {
        try {
            if ([int](Get-XPDataref $opt) -ne 0) {
                Set-XPDataref $opt 0
                Note info ('{0} was on: off for the measurement (not saved)' -f $opt)
            }
        } catch { Note warn ('{0}: not read or written ({1})' -f $opt, $_.Exception.Message) }
    }
    # the Auto fuel management option (the fuel session's, 2026-11-09;
    # default off) off too, as the earlier runs flew; before it is in, no
    # such dataref: nothing
    try {
        if ([int](Get-XPDataref 'laminar/B747/options/auto_fuel_mgmt') -ne 0) {
            Set-XPDataref 'laminar/B747/options/auto_fuel_mgmt' 0
            Note info 'laminar/B747/options/auto_fuel_mgmt was on: off for the measurement (not saved)'
        }
    } catch { }
}
function Set-PerfMcpMark {
    try { Set-XPDataref 'laminar/B747/autopilot/heading/altitude_dial_ft' $McpAltMark } catch { }
}

function Get-PerfWeights {
    return [ordered]@{
        sim_t = [double](Get-XPDataref 'sim/time/total_running_time_sec')
        payload_kg = [double](Get-XPDataref 'sim/flightmodel/weight/m_fixed')
        tanks_kg = @(Get-XPDataref 'sim/flightmodel/weight/m_fuel' | ForEach-Object { [double]$_ })
        fuel_kg = [double](Get-XPDataref 'sim/flightmodel/weight/m_fuel_total')
        gw_kg = [double](Get-XPDataref 'sim/flightmodel/weight/m_total')
    }
}

function Push-Button([string]$Name) {
    # a push button held 0.2 s (TESTING.md 4.6: a 0 s press may miss phase 2)
    Invoke-XPCommand $Name 0.2
    Start-Sleep -Milliseconds 450
}
function Get-Int([string]$Name) { return [int](Get-XPDataref $Name) }
function Get-Num([string]$Name) { return [double](Get-XPDataref $Name) }

# The MCP's speed in Mach, through IAS, as a pilot would (the 2026-11-06 check:
# FL310 held M.899). After an air start the aircraft's auto-switch puts the MCP
# in Mach (B747.70.xt.autopilot.lua 2484-2495), and the FMC's in-flight start
# winds the window in knots (259, read as M2.59). The A/P target then sits at
# the limit, Vmo - 10 kt (2550-2564; above 28,620 ft Vmo falls from 365 kt,
# B747.60.xt.fltInst02.lua 2327), and while it is there the window's Mach is
# not taken (2567). In IAS the target becomes the window's IAS (2545). Back in
# Mach, the window shows the Mach now (1963-1972) and the target follows the
# window. The IAS/MACH button acts only above M.40 (1996).
function Set-PerfMcpMach([double]$Mach) {
    $dial = [int][math]::Round($Mach * 100)
    for ($try = 1; $try -le 3; $try++) {
        if ((Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 1) {
            Push-Button 'sim/autopilot/knots_mach_toggle'
            [void](Wait-XP { (Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 0 } 5 250)
            Start-Sleep -Milliseconds 800   # the window follows 0.25 s on (1963-1972)
        }
        # (the auto-switch may have put it back in Mach already: the target is the IAS's then)
        if ((Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 0) {
            Push-Button 'sim/autopilot/knots_mach_toggle'
            if ($null -eq (Wait-XP { (Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 1 } 5 250)) { throw 'the MCP did not change to Mach' }
            Start-Sleep -Milliseconds 800
        }
        Set-XPDataref 'laminar/B747/autopilot/ias_dial_value' $dial
        $hit = { (Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 1 -and
            [math]::Abs((Get-Num 'sim/cockpit2/autopilot/airspeed_dial_kts_mach') - $Mach) -lt 0.0005 }
        if ($null -ne (Wait-XP $hit 5 250)) {
            # still so 2 s on (the auto-switch acts on the V/S: 2484-2507)
            Start-Sleep -Seconds 2
            if (& $hit) { return $try }
        }
        Note warn ('the A/P Mach target {0} after the window''s {1} (try {2})' -f (F (Get-Num 'sim/cockpit2/autopilot/airspeed_dial_kts_mach') '0.0000'), $dial, $try)
    }
    throw ('the A/P Mach target is {0}, not {1}' -f (Get-Num 'sim/cockpit2/autopilot/airspeed_dial_kts_mach'), $Mach)
}

# The MCP's speed in IAS (phase 2: the climbs' 250 and 300 kt): out of Mach
# (the IAS/MACH button, above M.40), the window in knots. In IAS the A/P
# target is the window's, at least Vmc + 10 kt (B747.70.xt.autopilot.lua
# 2502, 2526-2532); the AFDS and A/T protections act on their own (the
# minimum maneuvering speed), so a target other than the window's is noted,
# not refused. The tries, still so 2 s on.
function Set-PerfMcpIas([double]$Kias) {
    $kt = [int][math]::Round($Kias)
    for ($try = 1; $try -le 3; $try++) {
        if ((Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 1) {
            Push-Button 'sim/autopilot/knots_mach_toggle'
            if ($null -eq (Wait-XP { (Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 0 } 5 250)) { throw 'the MCP did not change to IAS' }
            Start-Sleep -Milliseconds 800   # the window follows 0.25 s on (1963-1972)
        }
        Set-XPDataref 'laminar/B747/autopilot/ias_dial_value' $kt
        $hit = { (Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 0 -and (Get-Int 'laminar/B747/autopilot/ias_dial_value') -eq $kt }
        if ($null -ne (Wait-XP $hit 5 250)) {
            Start-Sleep -Seconds 2
            if (& $hit) {
                $tgt = Get-Num 'sim/cockpit2/autopilot/airspeed_dial_kts_mach'
                if ([math]::Abs($tgt - $kt) -ge 0.5) { Note warn ('the A/P speed target {0} kt with the window''s {1}' -f (F $tgt '0.0'), $kt) }
                return $try
            }
        }
        Note warn ('the MCP window {0}, IAS mode {1}, after {2} kt (try {3})' -f (Get-Num 'laminar/B747/autopilot/ias_dial_value'),
            (1 - (Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach')), $kt, $try)
    }
    throw ('the MCP is not on {0} kt in IAS' -f $kt)
}

# The MCP back on $Mach once a FLCH climb is under way (phase 2's ceilings).
# FLCH's push sinks a moment (some -400 fpm: the AFDS's speed law), and with
# the A/P target over 310 kt (M.85 at FL310 is 318 kt) the aircraft's
# auto-switch puts the MCP in IAS (B747.70.xt.autopilot.lua 2532-2543), then
# back in Mach once climbing past M.84 (2520-2531) with the window at the
# Mach then (the fix session's note, 2026-11-08). Waits up to 60 s for the
# climb (over 300 fpm, in Mach); then the window to $Mach (Mach x 100) if in
# Mach and off it, else Set-PerfMcpMach. Back: what it found and did (set:
# none, window, mcp_mach, or failed and why).
function Set-PerfMcpMachClimbing([double]$Mach) {
    $r = [ordered]@{ climbing_after_s = $null; is_mach = $null; target = $null; set = 'none'; tries = 0; on_target = $false }
    $r.climbing_after_s = Wait-XP { (Get-Num 'sim/cockpit2/gauges/indicators/vvi_fpm_pilot') -gt 300 -and
        (Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 1 } 60 500
    Start-Sleep -Milliseconds 800   # the window follows 0.25 s on (1963-1972)
    $r.is_mach = Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach'
    $r.target = Get-Num 'sim/cockpit2/autopilot/airspeed_dial_kts_mach'
    $hit = { (Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 1 -and
        [math]::Abs((Get-Num 'sim/cockpit2/autopilot/airspeed_dial_kts_mach') - $Mach) -lt 0.0005 }
    if (& $hit) { $r.on_target = $true; return $r }
    if ($r.is_mach -eq 1) {
        Set-XPDataref 'laminar/B747/autopilot/ias_dial_value' ([int][math]::Round($Mach * 100))
        if ($null -ne (Wait-XP $hit 5 250)) {
            Start-Sleep -Seconds 2
            if (& $hit) { $r.set = 'window'; $r.on_target = $true; return $r }
        }
    }
    $r.set = 'mcp_mach'
    try { $r.tries = Set-PerfMcpMach $Mach; $r.on_target = $true } catch { $r.set = 'failed: ' + $_.Exception.Message }
    return $r
}

# The A/P and A/T on a level at $Ft and Mach $Mach: after the FMC's in-flight
# start (F/D, A/T ARM, the MCP speed wound to the airspeed, ALT HOLD and CMD L:
# B747.68.xt.fms.lua activate_inflightAP), the MCP in Mach (Set-PerfMcpMach:
# Mach x 100 in its window, B747.70.xt.autopilot.lua 2547-2567), BARO STD, HDG SEL on the
# heading, FLCH to the altitude when off it, then SPD. With $Kias (phase 2's
# climbs at 10,000 ft) the MCP in IAS on it instead (Set-PerfMcpIas).
function Set-PerfCruise([double]$Ft, [double]$Mach, [double]$Kias = 0) {
    $r = [ordered]@{}
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $init = Wait-XP {
        ((Get-Num 'laminar/B747/autopilot/heading/altitude_dial_ft') -ne $McpAltMark) -and
        ((Get-Num 'laminar/B747/autopilot/altitude/target') -eq -1) -and
        ((Get-Num 'laminar/B747/autopilot/speed/target') -eq -1) -and
        ((Get-Num 'laminar/B747/autopilot/cmd_L_mode/status') -gt 0.5) -and
        ((Get-Int 'laminar/B747/autopilot/servos_on') -eq 1)
    } 90 500
    if ($null -eq $init) {
        Note warn 'the FMC in-flight start did not finish within 90 s: CMD L pressed'
        Push-Button 'laminar/B747/autopilot/button_switch/cmd_L'
        if ($null -eq (Wait-XP { (Get-Int 'laminar/B747/autopilot/servos_on') -eq 1 } 15 500)) { throw 'no A/P servos' }
        $r.fmc_inflight_start = $false
    } else {
        Note info ('the FMC in-flight start done: CMD L, MCP {0} ft, {1} kt ({2} s)' -f `
            (Get-Num 'laminar/B747/autopilot/heading/altitude_dial_ft'), (Get-Num 'laminar/B747/autopilot/ias_dial_value'), (F $init '0.0'))
        $r.fmc_inflight_start = $true
    }
    Set-XPDataref 'laminar/B747/autopilot/heading/altitude_dial_ft' ([int]$Ft)
    if ($Kias -gt 0) { $r.ias_tries = Set-PerfMcpIas $Kias } else { $r.mach_tries = Set-PerfMcpMach $Mach }
    # BARO STD (the AFDS holds the altimeter's altitude; still ISA air at 1013.25 hPa)
    $baro = Get-Num 'sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot'
    if ([math]::Abs($baro - 29.92) -gt 0.005) {
        Note info ('altimeter {0} in Hg: BARO STD' -f (F $baro '0.00'))
        Push-Button 'laminar/B747/efis/baro_std/capt/switch'
        $baro = Get-Num 'sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot'
    }
    $r.baro_inhg = $baro
    # the heading now (magnetic, the MCP's)
    $hdg = [int][math]::Round((Get-Num 'sim/flightmodel/position/mag_psi')) % 360
    if ($hdg -eq 0) { $hdg = 360 }
    Set-XPDataref 'laminar/B747/autopilot/heading/degrees' $hdg
    Push-Button 'laminar/B747/autopilot/button_switch/heading_select'
    # the altitude
    $alt = Get-Num 'sim/cockpit2/gauges/indicators/altitude_ft_pilot'
    $r.alt_after_start_ft = $alt
    if ([math]::Abs($alt - $Ft) -gt 30) {
        Note info ('FLCH from {0} ft to {1} ft' -f (F $alt '0'), $Ft)
        Push-Button 'laminar/B747/autopilot/button_switch/flch_mode'
        # FLCH (8) first, unless it captures at once; then ALT (9) near the
        # altitude. A small change is slow: the A/T's THR holds the V/S that
        # makes the change in 125 s from where FLCH began (ATA34_2 p.670), so
        # 89 ft above at 10,000 ft and 250 kt (2026-11-08 clb_078, the air
        # start's rise to 187 ft above then) took 355 s; within 900 s
        [void](Wait-XP { (Get-Int 'laminar/B747/autopilot/FMA/active_pitch_mode') -eq 8 } 5 200)
        if ($null -eq (Wait-XP { (Get-Int 'laminar/B747/autopilot/FMA/active_pitch_mode') -eq 9 -and
                [math]::Abs((Get-Num 'sim/cockpit2/gauges/indicators/altitude_ft_pilot') - $Ft) -lt 50 } 900 1000)) {
            throw "no ALT at $Ft ft within 900 s of FLCH"
        }
        $r.flch = $true
    } elseif ((Get-Int 'laminar/B747/autopilot/FMA/active_pitch_mode') -ne 9) {
        Push-Button 'laminar/B747/autopilot/button_switch/alt_hold_mode'
        $r.flch = $false
    } else { $r.flch = $false }
    # the Mach once more on the level: in a descent (V/S below -250 fpm) above
    # 310 kt the aircraft's auto-switch puts the MCP in IAS
    # (B747.70.xt.autopilot.lua 2496-2507; the 2026-11-06 third check: M.85 at
    # FL310 is 318 kt, and the FLCH from 31,125 ft left the A/P on 305 kt); in
    # a climb (above 250 fpm) past M.84 it puts it in Mach with the window at
    # the Mach then (2484-2495). So first level: the capture still descends
    # at 250-670 fpm for some 15 s with ALT on the FMA
    $r.mach_tries_level = 0
    if ($null -eq (Wait-XP { [math]::Abs((Get-Num 'sim/cockpit2/gauges/indicators/vvi_fpm_pilot')) -lt 150 } 90 500)) {
        Note warn ('not level 90 s after the level change: V/S {0} fpm' -f (F (Get-Num 'sim/cockpit2/gauges/indicators/vvi_fpm_pilot') '0'))
    }
    if ($Kias -gt 0) {
        if ((Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -ne 0 -or (Get-Int 'laminar/B747/autopilot/ias_dial_value') -ne [int][math]::Round($Kias)) {
            Note info ('on the level the MCP is not on {0} kt in IAS: again' -f $Kias)
            $r.ias_tries_level = Set-PerfMcpIas $Kias
        }
    } elseif ((Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -ne 1 -or
        [math]::Abs((Get-Num 'sim/cockpit2/autopilot/airspeed_dial_kts_mach') - $Mach) -ge 0.0005) {
        Note info ('on the level the MCP is {0} {1}: Mach {2} again' -f $(if ((Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 1) { 'Mach' } else { 'IAS' }),
            (F (Get-Num 'sim/cockpit2/autopilot/airspeed_dial_kts_mach') '0.000'), $Mach)
        $r.mach_tries_level = Set-PerfMcpMach $Mach
    }
    # A/T SPD
    Push-Button 'laminar/B747/autopilot/button_switch/speed_mode'
    if ($null -eq (Wait-XP { (Get-Int 'laminar/B747/autopilot/FMA/autothrottle_mode') -eq 3 } 10 500)) {
        Note warn 'no A/T SPD: A/T ARM, then SPD'
        Push-Button 'laminar/B747/authrottle_arm'
        Push-Button 'laminar/B747/autopilot/button_switch/speed_mode'
        if ($null -eq (Wait-XP { (Get-Int 'laminar/B747/autopilot/FMA/autothrottle_mode') -eq 3 } 10 500)) { throw 'no A/T SPD' }
    }
    $r.fma_pitch = Get-Int 'laminar/B747/autopilot/FMA/active_pitch_mode'
    $r.fma_roll = Get-Int 'laminar/B747/autopilot/FMA/active_roll_mode'
    $r.fma_at = Get-Int 'laminar/B747/autopilot/FMA/autothrottle_mode'
    $r.servos_on = Get-Int 'laminar/B747/autopilot/servos_on'
    $r.is_mach = Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach'
    $r.ap_mach_target = Get-Num 'sim/cockpit2/autopilot/airspeed_dial_kts_mach'
    $r.mcp_alt_ft = Get-Num 'laminar/B747/autopilot/heading/altitude_dial_ft'
    $r.mcp_hdg = $hdg
    $r.setup_wall_s = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    Note info ('A/P set: FMA pitch {0} roll {1} A/T {2}, {3} target {4}, MCP {5} ft, hdg {6} ({7} s)' -f `
        $r.fma_pitch, $r.fma_roll, $r.fma_at, $(if ($r.is_mach -eq 1) { 'Mach' } else { 'IAS' }), (F $r.ap_mach_target '0.000'),
        $r.mcp_alt_ft, $hdg, $r.setup_wall_s)
    return $r
}

# ---------------------------------------------------------------- the CDU

# The Captain's CDU (keys fms1, lines fms3): the key names and typing of the
# kit's scenarios (run_scenario.ps1 step cdu: MENU the FIX command, INITREF
# the INDEX one, VNAV the DES one; the same key again 250 ms on, as a key
# twice in one frame is taken once)
function Invoke-PerfCdu([string[]]$Keys) {
    $names = @{ MENU = 'func_key/fix'; INITREF = 'func_key/index'; VNAV = 'func_key/des'; PREV = 'func_key/prev_pg'
        NEXT = 'func_key/next_pg'; EXEC = 'key/execute'; CLR = 'key/clear' }
    foreach ($k in $Keys) {
        if ($k -cmatch '^[LR][1-6]$') {
            Invoke-XPCommand "laminar/B747/fms1/ls_key/$k"
            Start-Sleep -Milliseconds 500
        } elseif ($names.ContainsKey($k)) {
            Invoke-XPCommand "laminar/B747/fms1/$($names[$k])" $(if ($k -ceq 'EXEC') { 0.2 } else { 0 })
            Start-Sleep -Milliseconds 500
        } else {
            $prev = $null
            foreach ($ch in $k.ToCharArray()) {
                $c = [string]$ch
                if ($c -cnotmatch '^[A-Z0-9]$') { throw "cdu: no key for '$c'" }
                if ($c -ceq $prev) { Start-Sleep -Milliseconds 250 }
                Invoke-XPCommand "laminar/B747/fms1/alphanum_key/$c"
                Start-Sleep -Milliseconds 70
                $prev = $c
            }
            Start-Sleep -Milliseconds 100
        }
    }
}
function Get-PerfCduLines { return ,[string[]]@(1..14 | ForEach-Object { [string](Get-XPDataref ('laminar/B747/fms3/Line{0:D2}_L' -f $_)) }) }

# the VNAV CRZ page's speed (B744.fms.pages.vnav.lua 523-538): the title in
# line 1 (ECON for the economy speed), the speed in line 5 (2L), a Mach .XXX
function Get-PerfCrzMach([string[]]$Lines) {
    if ($Lines.Count -lt 5 -or $Lines[0] -notmatch 'CRZ') { return $null }
    if ($Lines[4] -match '^\s*\.(\d{3})') { return [double]('0.' + $Matches[1]) }
    return $null
}

# The economy cruise Mach the FMC flies at a cost index (PERF_SIMBRIEF.md
# phase 1: before the points, at 78 % and FL350, with the fill-in table's
# CI): the FMC's IDENT once its data is in (the scenarios' MENU <FMC), PERF
# INIT's COST INDEX (5L) and CRZ ALT (1R; the gross weight X-Plane's without
# a ZFW: B747_fms_gw_kg), then the VNAV CRZ page's ECON SPD. The FMC puts
# the economy speeds every 5 s (update_econ, B747.68.xt.fms.lua 1133-1155).
function Measure-PerfCiMach([int]$Ci, [double]$Ft) {
    $r = [ordered]@{ ci = $Ci; crz_alt_ft = $Ft; mach = $null; title = $null; note = $null; lines = $null }
    Invoke-PerfCdu @('CLR', 'MENU', 'L1')
    if ($null -eq (Wait-XP { ([string](Get-XPDataref 'laminar/B747/fms3/Line05_L')) -match 'AIRAC' } 120 1000)) {
        $r.note = 'no AIRAC on the IDENT page within 120 s'
    }
    Invoke-PerfCdu @('INITREF', 'L6', 'L3', [string]$Ci, 'L5', [string][int]($Ft / 100), 'R1')
    Start-Sleep -Seconds 12
    Invoke-PerfCdu @('VNAV')
    for ($k = 0; $k -lt 3; $k++) {
        $lines = Get-PerfCduLines
        if ($lines[0] -match 'CRZ') { break }
        Invoke-PerfCdu @('NEXT')
    }
    $lines = Get-PerfCduLines
    $r.lines = $lines
    $r.title = $lines[0].Trim()
    $r.mach = Get-PerfCrzMach $lines
    if ($null -eq $r.mach -and -not $r.note) { $r.note = 'no Mach on the VNAV CRZ page' }
    return $r
}

# ---------------------------------------------------------------- the logger

# column, dataref, index (-1 a scalar), 'mean' or 'last' (states) in the second
$colSpec = @(
    @('sim_t', 'sim/time/total_running_time_sec', -1, 'mean'),
    @('paused', 'sim/time/paused', -1, 'last'),
    @('sim_speed', 'sim/time/sim_speed', -1, 'last'),
    @('ground_speed_x', 'sim/time/ground_speed', -1, 'last'),
    @('sim_speed_actual', 'sim/time/sim_speed_actual', -1, 'mean'),
    @('frame_period', 'sim/operation/misc/frame_rate_period', -1, 'mean'),
    @('alt', 'sim/cockpit2/gauges/indicators/altitude_ft_pilot', -1, 'mean'),
    @('press_alt_ft', 'sim/flightmodel2/position/pressure_altitude', -1, 'mean'),
    @('ias', 'sim/flightmodel/position/indicated_airspeed', -1, 'mean'),
    @('vs', 'sim/flightmodel/position/vh_ind_fpm', -1, 'mean'),
    @('pitch', 'sim/flightmodel/position/theta', -1, 'mean'),
    @('aoa', 'sim/flightmodel/position/alpha', -1, 'mean'),
    @('roll', 'sim/flightmodel/position/phi', -1, 'mean'),
    @('mach', 'sim/flightmodel/misc/machno', -1, 'mean'),
    @('tas_ms', 'sim/flightmodel/position/true_airspeed', -1, 'mean'),
    @('gs_ms', 'sim/flightmodel/position/groundspeed', -1, 'mean'),
    @('hdg_mag', 'sim/flightmodel/position/mag_psi', -1, 'mean'),
    @('lat', 'sim/flightmodel/position/latitude', -1, 'mean'),
    @('lon', 'sim/flightmodel/position/longitude', -1, 'mean'),
    @('elev_m', 'sim/flightmodel/position/elevation', -1, 'mean'),
    @('oat_c', 'sim/weather/aircraft/temperature_ambient_deg_c', -1, 'mean'),
    @('wind_kt', 'sim/cockpit2/gauges/indicators/wind_speed_kts', -1, 'mean'),
    @('wind_dir_mag', 'sim/cockpit2/gauges/indicators/wind_heading_deg_mag', -1, 'last'),
    @('baro_inhg', 'sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot', -1, 'last'),
    @('weight', 'sim/flightmodel/weight/m_total', -1, 'mean'),
    @('fuel_kg', 'sim/flightmodel/weight/m_fuel_total', -1, 'mean'),
    # FUEL USED (the engines' flow x SIM_PERIOD, B747.25.xt.fuel.lua 1355-1362):
    # which time the tanks' burn follows. (X-Plane's own totalizer stays 0: the
    # aircraft sets its start to the tanks' total, 1550.)
    @('fuel_used_kg', 'laminar/B747/fuel/totaliser', 4, 'mean'),
    @('payload_kg', 'sim/flightmodel/weight/m_fixed', -1, 'mean'),
    @('cg_mac', 'sim/flightmodel2/misc/cg_offset_z_mac', -1, 'mean')
)
foreach ($i in 0..8) { $colSpec += , @("tank$i", 'sim/flightmodel/weight/m_fuel', $i, 'mean') }
foreach ($e in 0..3) {
    $n = $e + 1
    $colSpec += , @("ff_$n", 'sim/cockpit2/engine/indicators/fuel_flow_kg_sec', $e, 'mean')
    $colSpec += , @("n1_$n", 'sim/cockpit2/engine/indicators/N1_percent', $e, 'mean')
    $colSpec += , @("n2_$n", 'sim/cockpit2/engine/indicators/N2_percent', $e, 'mean')
    $colSpec += , @("epr_$n", 'sim/cockpit2/engine/indicators/EPR_ratio', $e, 'mean')
    $colSpec += , @("depr_$n", 'laminar/B747/engines/display_EPR', $e, 'mean')
    $colSpec += , @("thrust_$n", 'sim/flightmodel/engine/POINT_thrust', $e, 'mean')
    $colSpec += , @("thro_$n", 'sim/flightmodel/engine/ENGN_thro_use', $e, 'mean')
    $colSpec += , @("burning_$n", 'sim/flightmodel2/engines/engine_is_burning_fuel', $e, 'last')
}
$colSpec += @(
    @('flap', 'sim/cockpit2/controls/flap_ratio', -1, 'last'),
    @('gear', 'sim/cockpit2/controls/gear_handle_down', -1, 'last'),
    @('on_ground', 'sim/flightmodel/failures/onground_any', -1, 'last'),
    @('crashed', 'sim/flightmodel2/misc/has_crashed', -1, 'last'),
    @('tgt', 'sim/cockpit2/autopilot/airspeed_dial_kts_mach', -1, 'last'),
    @('is_mach', 'sim/cockpit2/autopilot/airspeed_is_mach', -1, 'last'),
    @('mcp_spd', 'laminar/B747/autopilot/ias_dial_value', -1, 'last'),
    @('mcp_alt', 'laminar/B747/autopilot/heading/altitude_dial_ft', -1, 'last'),
    @('window', 'laminar/B747/autopilot/ap_monitor/alt_capture_window', -1, 'last'),
    @('fma', 'laminar/B747/autopilot/FMA/active_pitch_mode', -1, 'last'),
    @('fma_roll', 'laminar/B747/autopilot/FMA/active_roll_mode', -1, 'last'),
    @('fma_at', 'laminar/B747/autopilot/FMA/autothrottle_mode', -1, 'last'),
    @('servos_on', 'laminar/B747/autopilot/servos_on', -1, 'last'),
    @('cmd_l', 'laminar/B747/autopilot/cmd_L_mode/status', -1, 'last'),
    # (phase 2) the reference thrust limit (B747.68.xt.fms.lua 2408: 10 x
    # THRLIM_CODE's TO 1, CLB 2, CRZ 3, CON 4, GA 5, plus the derate 1 or 2,
    # plus 100 for D-TO: CLB 20, CLB 1 21, CRZ 30; an air start's CLB,
    # thrlim_model.lua 143; the phase 1 runs logged 20 in their cruises) and
    # the speeds the AFDS and A/T protect (the PFD's amber band's top and the
    # maximum)
    @('thrlim', 'laminar/B747/fms/thrlim/code', -1, 'last'),
    @('vminm', 'laminar/B747/airspeed/Vminm', -1, 'mean'),
    @('vmax', 'laminar/B747/airspeed/Vmax', -1, 'mean')
)
# (2026-11-07) X-Plane's fuel per thrust as the aircraft writes it (kg/(N s),
# $SfcPoints) and the correction's switch (1: the acf's own; a dataref of the
# aircraft from that day: left out before)
foreach ($k in $SfcPoints) { $colSpec += , @("sfc_$k", "sim/aircraft/overflow/jet_SFC_$k", -1, 'mean') }
$colSpec += , @('sfc_corr_off', 'laminar/B747/debug/sfc_corr_off', -1, 'last')

# the WebSocket's reader, in a runspace of its own: every update a sample of
# every column (held values), a row each second of sim time
$LoggerBlock = {
    param($sync, [string]$uri, [string[]]$colIds, [int[]]$colPos, [bool[]]$colLast, [int]$simCol,
        [string]$subsJson, [string]$csvPath, [string]$header)
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $w = $null
    $ws = $null
    try {
        $w = New-Object IO.StreamWriter($csvPath, $false, (New-Object Text.UTF8Encoding($false)))
        $w.AutoFlush = $true
        $w.WriteLine($header)
        $ws = New-Object Net.WebSockets.ClientWebSocket
        $none = [Threading.CancellationToken]::None
        if (-not $ws.ConnectAsync([Uri]$uri, $none).Wait(15000)) { throw "no WebSocket to $uri" }
        $req = [Text.Encoding]::UTF8.GetBytes($subsJson)
        if (-not $ws.SendAsync([ArraySegment[byte]]::new($req), [Net.WebSockets.WebSocketMessageType]::Text, $true, $none).Wait(15000)) {
            throw 'the subscription was not sent'
        }
        $buf = New-Object byte[] 1048576
        $ms = New-Object IO.MemoryStream
        $cur = @{}
        $n = $colIds.Length
        $sum = New-Object double[] $n
        $last = New-Object double[] $n
        $cnt = 0
        $bin = [double]::NaN
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while (-not $sync.stop) {
            $ms.SetLength(0)
            $done = $false
            while (-not $done) {
                $task = $ws.ReceiveAsync([ArraySegment[byte]]::new($buf), $none)
                while (-not $task.Wait(500)) { if ($sync.stop) { break } }
                if ($sync.stop) { break }
                $res = $task.Result
                if ($res.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { throw 'the Web API closed the WebSocket' }
                $ms.Write($buf, 0, $res.Count)
                $done = $res.EndOfMessage
            }
            if ($sync.stop) { break }
            $msg = ConvertFrom-Json ([Text.Encoding]::UTF8.GetString($ms.ToArray()))
            if ($msg.type -eq 'result') {
                if (-not $msg.success) { throw ('subscription: {0} {1}' -f $msg.error_code, $msg.error_message) }
                $sync.subscribed = $true
                continue
            }
            if ($msg.type -ne 'dataref_update_values') { continue }
            foreach ($p in $msg.data.PSObject.Properties) { $cur[$p.Name] = $p.Value }
            $sync.msgs = $sync.msgs + 1
            $sync.lastUtc = [DateTime]::UtcNow
            $vals = New-Object double[] $n
            for ($i = 0; $i -lt $n; $i++) {
                $v = $cur[$colIds[$i]]
                if ($null -eq $v) { $vals[$i] = [double]::NaN; continue }
                if ($colPos[$i] -ge 0) { $v = @($v)[$colPos[$i]] }
                $vals[$i] = [double]$v
            }
            $t = $vals[$simCol]
            if ([double]::IsNaN($t)) { continue }
            $b = [math]::Floor($t)
            if (-not [double]::IsNaN($bin) -and $b -ne $bin -and $cnt -gt 0) {
                $row = New-Object double[] ($n + 2)
                for ($i = 0; $i -lt $n; $i++) {
                    if ($colLast[$i]) { $row[$i] = $last[$i] } else { $row[$i] = $sum[$i] / $cnt }
                }
                $row[$n] = $sw.Elapsed.TotalSeconds
                $row[$n + 1] = $cnt
                [void]$sync.rows.Add($row)
                $sb = New-Object Text.StringBuilder
                for ($i = 0; $i -lt $row.Length; $i++) {
                    if ($i -gt 0) { [void]$sb.Append(',') }
                    [void]$sb.Append($row[$i].ToString('R', $inv))
                }
                $w.WriteLine($sb.ToString())
                [Array]::Clear($sum, 0, $n)
                $cnt = 0
            }
            $bin = $b
            for ($i = 0; $i -lt $n; $i++) { $sum[$i] += $vals[$i]; $last[$i] = $vals[$i] }
            $cnt++
        }
    } catch {
        # the innermost exception too (a task's AggregateException hides it)
        $e = $_.Exception
        $text = $e.Message
        while ($null -ne $e.InnerException) { $e = $e.InnerException; $text += ' <- ' + $e.GetType().Name + ': ' + $e.Message }
        $sync.error = $text
    } finally {
        if ($null -ne $w) { $w.Dispose() }
        if ($null -ne $ws) { try { $ws.Abort() } catch { }; $ws.Dispose() }
    }
}

$script:logger = $null
$script:ix = @{}
$script:drefInfo = [ordered]@{}
function Start-PerfLogger([string]$CsvPath) {
    $cols = New-Object System.Collections.ArrayList
    $idx = @{}
    $missing = New-Object System.Collections.ArrayList
    foreach ($c in $colSpec) {
        $name = $c[1]
        if (-not $script:drefInfo.Contains($name)) {
            try {
                $info = Get-XPDatarefInfo $name
                $script:drefInfo[$name] = [ordered]@{ id = [long]$info.id; value_type = [string]$info.value_type }
            } catch { $script:drefInfo[$name] = $null }
        }
        $info = $script:drefInfo[$name]
        if ($null -eq $info) { if (-not $missing.Contains($name)) { [void]$missing.Add($name) }; continue }
        [void]$cols.Add([ordered]@{ col = $c[0]; dref = $name; index = [int]$c[2]; last = ($c[3] -eq 'last'); id = $info.id; pos = -1 })
        if ([int]$c[2] -ge 0) {
            if (-not $idx.ContainsKey($name)) { $idx[$name] = New-Object 'System.Collections.Generic.SortedSet[int]' }
            [void]$idx[$name].Add([int]$c[2])
        }
    }
    foreach ($c in $cols) { if ($c.index -ge 0) { $c.pos = [array]::IndexOf([int[]]@($idx[$c.dref]), $c.index) } }
    $subs = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($c in $cols) {
        if ($seen.ContainsKey($c.dref)) { continue }
        $seen[$c.dref] = $true
        if ($c.index -ge 0) { [void]$subs.Add([ordered]@{ id = $c.id; index = [int[]]@($idx[$c.dref]) }) }
        else { [void]$subs.Add([ordered]@{ id = $c.id }) }
    }
    $n = $cols.Count
    $script:ix = @{}
    for ($i = 0; $i -lt $n; $i++) { $script:ix[$cols[$i].col] = $i }
    $script:ix['wall_s'] = $n
    $script:ix['samples'] = $n + 1
    $header = (@($cols | ForEach-Object { $_.col }) + @('wall_s', 'samples')) -join ','
    $colIds = [string[]]@($cols | ForEach-Object { [string]$_.id })
    $colPos = [int[]]@($cols | ForEach-Object { [int]$_.pos })
    $colLast = [bool[]]@($cols | ForEach-Object { [bool]$_.last })
    $sync = [hashtable]::Synchronized(@{ stop = $false; error = $null; msgs = 0; subscribed = $false
        lastUtc = [DateTime]::UtcNow; rows = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList)) })
    $subsJson = ConvertTo-Json ([ordered]@{ req_id = 1; type = 'dataref_subscribe_values'; params = [ordered]@{ datarefs = @($subs) } }) -Depth 10 -Compress
    $wsUri = $script:XPBase -replace '^http', 'ws'
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript($LoggerBlock)
    [void]$ps.AddArgument($sync)
    [void]$ps.AddArgument($wsUri)
    [void]$ps.AddArgument($colIds)
    [void]$ps.AddArgument($colPos)
    [void]$ps.AddArgument($colLast)
    [void]$ps.AddArgument([int]$script:ix['sim_t'])
    [void]$ps.AddArgument($subsJson)
    [void]$ps.AddArgument($CsvPath)
    [void]$ps.AddArgument($header)
    $handle = $ps.BeginInvoke()
    $script:logger = @{ ps = $ps; handle = $handle; sync = $sync; csv = $CsvPath; missing = @($missing); columns = $n; header = $header }
    if ($missing.Count -gt 0) { Note warn ('datarefs not found, columns left out: ' + ($missing -join ', ')) }
    $ok = Wait-XP { $sync.error -or $sync.rows.Count -ge 2 } 30 250
    if ($sync.error) { throw "logger: $($sync.error)" }
    if ($null -eq $ok) { throw 'logger: no rows within 30 s' }
    Note info ('logger: {0} columns, {1} datarefs subscribed -> {2}' -f $n, $subs.Count, (Split-Path -Leaf $CsvPath))
}
function Stop-PerfLogger {
    if ($null -eq $script:logger) { return }
    $script:logger.sync.stop = $true
    try { [void]$script:logger.ps.EndInvoke($script:logger.handle) } catch { }
    $script:logger.ps.Dispose()
    $script:logger = $null
}
function Get-PerfRows { return ,($script:logger.sync.rows.ToArray()) }
# rows $From..$To of the logger to a CSV of their own (a point's: PERF_SIMBRIEF.md
# raw/*.csv), with the logger's header and number format
function Save-PerfRows([string]$Path, $Rows, [int]$From, [int]$To) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add([string]$script:logger.header)
    $sb = New-Object Text.StringBuilder
    for ($k = [math]::Max(0, $From); $k -le [math]::Min($To, $Rows.Count - 1); $k++) {
        [void]$sb.Clear()
        $row = $Rows[$k]
        for ($i = 0; $i -lt $row.Length; $i++) {
            if ($i -gt 0) { [void]$sb.Append(',') }
            [void]$sb.Append(([double]$row[$i]).ToString('R', $inv))
        }
        $lines.Add($sb.ToString())
    }
    [IO.File]::WriteAllLines($Path, [string[]]$lines.ToArray(), $utf8)
}
function Assert-PerfLogger {
    $s = $script:logger.sync
    if ($s.error) { throw "logger: $($s.error)" }
    if (([DateTime]::UtcNow - $s.lastUtc).TotalSeconds -gt 20) { throw 'logger: no WebSocket update for 20 s (X-Plane stopped?)' }
}

# ---------------------------------------------------------------- the rows

function Get-Col($Rows, [string]$Name) {
    $a = New-Object double[] $Rows.Count
    $i = $script:ix[$Name]
    for ($k = 0; $k -lt $Rows.Count; $k++) { if ($null -eq $i) { $a[$k] = [double]::NaN } else { $a[$k] = $Rows[$k][$i] } }
    return ,$a
}
function Get-Mean([double[]]$A) {
    if ($A.Length -eq 0) { return [double]::NaN }
    $s = 0.0
    foreach ($v in $A) { $s += $v }
    return $s / $A.Length
}
function Get-Range([double[]]$A) {
    if ($A.Length -eq 0) { return [double]::NaN }
    $mn = $A[0]; $mx = $A[0]
    foreach ($v in $A) { if ($v -lt $mn) { $mn = $v }; if ($v -gt $mx) { $mx = $v } }
    return $mx - $mn
}
function Get-MaxAbs([double[]]$A) {
    $m = 0.0
    foreach ($v in $A) { if ([math]::Abs($v) -gt $m) { $m = [math]::Abs($v) } }
    return $m
}
# least squares slope of y on x
function Get-Slope([double[]]$X, [double[]]$Y) {
    $n = $X.Length
    if ($n -lt 2) { return [double]::NaN }
    $mx = (Get-Mean $X); $my = (Get-Mean $Y)
    $sxy = 0.0; $sxx = 0.0
    for ($i = 0; $i -lt $n; $i++) { $dx = $X[$i] - $mx; $sxy += $dx * ($Y[$i] - $my); $sxx += $dx * $dx }
    if ($sxx -eq 0) { return [double]::NaN }
    return $sxy / $sxx
}
# rows in real time only (PERF_SIMBRIEF.md rule 3)
function Select-RealTime($Rows) {
    $p = $script:ix['paused']; $s = $script:ix['sim_speed']; $g = $script:ix['ground_speed_x']
    return ,@($Rows | Where-Object { $_[$p] -eq 0 -and $_[$s] -eq 1 -and $_[$g] -eq 1 })
}
function Get-FfSum($Row) {
    $s = 0.0
    foreach ($e in 1..4) { $s += $Row[$script:ix["ff_$e"]] }
    return $s
}
# the level's limits over the last $Secs rows (PERF_SIMBRIEF.md phase 1)
function Test-Stable($Rows, [double]$Ft, [double]$Mach, [int]$Secs) {
    if ($Rows.Count -lt $Secs) { return $false }
    for ($k = $Rows.Count - $Secs; $k -lt $Rows.Count; $k++) {
        $r = $Rows[$k]
        if ([math]::Abs($r[$script:ix['alt']] - $Ft) -gt 30) { return $false }
        if ([math]::Abs($r[$script:ix['mach']] - $Mach) -gt 0.003) { return $false }
        if ([math]::Abs($r[$script:ix['vs']]) -ge 100) { return $false }
        if ($r[$script:ix['paused']] -ne 0 -or $r[$script:ix['sim_speed']] -ne 1 -or $r[$script:ix['ground_speed_x']] -ne 1) { return $false }
    }
    return $true
}

# not level within the limits in 6 min (PERF_SIMBRIEF.md phase 1): below its
# Mach at the end, the A/T in SPD and the level held, the thrust could not
# hold it ("hold_unable"); else "unstable". Over the last 60 rows.
function Get-PerfUnsettled($Rows, [double]$Ft, [double]$Mach) {
    $n = [math]::Min(60, $Rows.Count)
    if ($n -lt 2) { return [ordered]@{ status = 'unstable'; detail = "$n rows" } }
    $last = @($Rows[($Rows.Count - $n)..($Rows.Count - 1)])
    $t = Get-Col $last 'sim_t'
    $mc = Get-Col $last 'mach'
    $m = Get-Mean $mc
    $alt = Get-Mean (Get-Col $last 'alt')
    $vs = Get-Mean (Get-Col $last 'vs')
    $at = $last[$last.Count - 1][$script:ix['fma_at']]
    $n1 = 0.0; foreach ($e in 1..4) { $n1 += Get-Mean (Get-Col $last "n1_$e") }
    $slope = (Get-Slope $t $mc) * 60
    $status = if ($m -lt $Mach - 0.003 -and $at -eq 3 -and [math]::Abs($alt - $Ft) -le 100) { 'hold_unable' } else { 'unstable' }
    $detail = 'last {0} s: alt {1} ft, Mach {2} ({3} a minute), V/S {4} fpm, A/T {5}, N1 {6} %' -f $n, (F $alt '0'), (F $m '0.0000'),
        (F $slope '+0.0000;-0.0000'), (F $vs '0'), $at, (F ($n1 / 4) '0.0')
    return [ordered]@{ status = $status; detail = $detail; mach = $m; alt_ft = $alt; vs_fpm = $vs; mach_per_min = $slope }
}

# a window's means and flows
function Measure-PerfWindow($Rows) {
    $rt = Select-RealTime $Rows
    $m = [ordered]@{ rows = $Rows.Count; rows_real_time = $rt.Count }
    if ($rt.Count -lt 10) { return $m }
    $t = Get-Col $rt 'sim_t'; $wl = Get-Col $rt 'wall_s'; $f = Get-Col $rt 'fuel_kg'
    $m.sim_s = $t[$t.Length - 1] - $t[0]
    $m.wall_s = $wl[$wl.Length - 1] - $wl[0]
    $m.sim_per_wall = $m.sim_s / $m.wall_s
    $m.ff_fuelmass_kgph = -(Get-Slope $t $f) * 3600
    $m.ff_fuelmass_wall_kgph = -(Get-Slope $wl $f) * 3600
    $ffs = New-Object double[] $rt.Count
    for ($k = 0; $k -lt $rt.Count; $k++) { $ffs[$k] = Get-FfSum $rt[$k] }
    $m.ff_gauge_kgph = (Get-Mean $ffs) * 3600
    $m.ff_diff_pct = ($m.ff_fuelmass_kgph / $m.ff_gauge_kgph - 1) * 100
    $m.ff_wall_diff_pct = ($m.ff_fuelmass_wall_kgph / $m.ff_gauge_kgph - 1) * 100
    # FUEL USED (laminar/B747/fuel/totaliser[4]): the aircraft adds each
    # engine's flow x SIM_PERIOD to it in the frame that takes that flow from
    # the tanks (B747.25.xt.fuel.lua 1355-1362, 1417-1418). Its rate on wall
    # time over the gauges is the share of the wall time that the frames'
    # SIM_PERIOD covered (with the flow steady)
    $m.ff_totaliser_kgph = [double]::NaN; $m.ff_totaliser_wall_kgph = [double]::NaN
    $m.sim_period_share = [double]::NaN
    if ($script:ix.ContainsKey('fuel_used_kg')) {
        $u = Get-Col $rt 'fuel_used_kg'
        $m.ff_totaliser_kgph = (Get-Slope $t $u) * 3600
        $m.ff_totaliser_wall_kgph = (Get-Slope $wl $u) * 3600
        $m.sim_period_share = $m.ff_totaliser_wall_kgph / $m.ff_gauge_kgph
    }
    # the tanks' sum against m_fuel_total
    $tankSum = New-Object double[] $rt.Count
    for ($k = 0; $k -lt $rt.Count; $k++) { $s = 0.0; foreach ($i in 0..8) { $s += $rt[$k][$script:ix["tank$i"]] }; $tankSum[$k] = $s - $f[$k] }
    $m.tanks_minus_total_kg = Get-MaxAbs $tankSum
    foreach ($c in 'weight', 'press_alt_ft', 'alt', 'mach', 'ias', 'oat_c', 'wind_kt', 'pitch', 'aoa', 'cg_mac', 'frame_period', 'sim_speed_actual') {
        $m[$c] = Get-Mean (Get-Col $rt $c)
    }
    $m.tas_kt = (Get-Mean (Get-Col $rt 'tas_ms')) * 3600 / 1852
    $m.isa_dev_c = $m.oat_c - (Get-IsaC $m.press_alt_ft)
    $m.alt_range_ft = Get-Range (Get-Col $rt 'alt')
    $m.mach_range = Get-Range (Get-Col $rt 'mach')
    $m.vs_max_abs = Get-MaxAbs (Get-Col $rt 'vs')
    $n1 = 0.0; $epr = 0.0; $depr = 0.0
    foreach ($e in 1..4) { $n1 += Get-Mean (Get-Col $rt "n1_$e"); $epr += Get-Mean (Get-Col $rt "epr_$e"); $depr += Get-Mean (Get-Col $rt "depr_$e") }
    $m.n1_avg_pct = $n1 / 4
    $m.epr_avg = $epr / 4
    $m.display_epr_avg = $depr / 4
    $m.fps = 1 / $m.frame_period
    # the fuel per thrust ($SfcPoints, kg/(N s)): each point's mean, and over
    # the acf's own ($script:acfSfc) the factor on them, the four's mean and
    # spread (the aircraft puts one factor on all four: spread 0; none
    # without the columns or the acf's); the correction's switch at the end
    $m.sfc_kgns = [ordered]@{}
    $fs = New-Object System.Collections.ArrayList
    foreach ($k in $SfcPoints) {
        $v = Get-Mean (Get-Col $rt "sfc_$k")
        $m.sfc_kgns[$k] = $v
        if ($null -ne $script:acfSfc -and $script:acfSfc[$k] -gt 0 -and -not [double]::IsNaN($v)) { [void]$fs.Add($v / $script:acfSfc[$k]) }
    }
    $m.sfc_factor = [double]::NaN; $m.sfc_factor_spread = [double]::NaN
    if ($fs.Count -eq $SfcPoints.Count) { $m.sfc_factor = Get-Mean ([double[]]$fs.ToArray()); $m.sfc_factor_spread = Get-Range ([double[]]$fs.ToArray()) }
    $m.sfc_corr_off = $null
    if ($script:ix.ContainsKey('sfc_corr_off')) { $m.sfc_corr_off = $rt[$rt.Count - 1][$script:ix['sfc_corr_off']] }
    return $m
}

# writes by the aircraft over the rows: the payload, the zero fuel weight
# (total less fuel), the fuel's second-to-second fall against the gauges
function Measure-PerfWrites($Rows) {
    $m = [ordered]@{ rows = $Rows.Count }
    if ($Rows.Count -lt 3) { return $m }
    $m.payload_range_kg = Get-Range (Get-Col $Rows 'payload_kg')
    $gw = Get-Col $Rows 'weight'; $f = Get-Col $Rows 'fuel_kg'; $t = Get-Col $Rows 'sim_t'
    $zfw = New-Object double[] $Rows.Count
    for ($k = 0; $k -lt $Rows.Count; $k++) { $zfw[$k] = $gw[$k] - $f[$k] }
    $m.zfw_range_kg = Get-Range $zfw
    $res = New-Object double[] ($Rows.Count - 1)
    $tankJump = 0.0
    for ($k = 1; $k -lt $Rows.Count; $k++) {
        $dt = $t[$k] - $t[$k - 1]
        $burn = ((Get-FfSum $Rows[$k - 1]) + (Get-FfSum $Rows[$k])) / 2 * $dt
        $res[$k - 1] = ($f[$k - 1] - $f[$k]) - $burn
        foreach ($i in 0..8) {
            $d = [math]::Abs($Rows[$k][$script:ix["tank$i"]] - $Rows[$k - 1][$script:ix["tank$i"]])
            if ($dt -gt 0) { $d = $d / $dt }
            if ($d -gt $tankJump) { $tankJump = $d }
        }
    }
    $m.fuel_step_residual_max_kg = Get-MaxAbs $res
    $m.fuel_step_residual_mean_kg = Get-Mean $res
    $m.tank_rate_max_kg_s = $tankJump
    $m.fuel_used_kg = $f[0] - $f[$f.Length - 1]
    $m.sim_s = $t[$t.Length - 1] - $t[0]
    $acc = 0
    foreach ($r in $Rows) { if ($r[$script:ix['sim_speed']] -ne 1 -or $r[$script:ix['ground_speed_x']] -ne 1) { $acc++ } }
    $m.rows_time_accelerated = $acc
    return $m
}

function Add-Check($Res, [string]$Name, $Pass, [string]$Value, [string]$Limit) {
    $Res.checks[$Name] = [ordered]@{ pass = $Pass; value = $Value; limit = $Limit }
    $mark = if ($null -eq $Pass) { 'INFO' } elseif ($Pass) { 'PASS' } else { 'FAIL' }
    Note $mark ('{0} {1}: {2} ({3})' -f $Res.id, $Name, $Value, $Limit)
}

# a stopped flight's error: its message and where it was thrown, the script
# and the line (2026-11-08 the first climb's "the array index evaluated to
# null" came without one)
function Format-PerfError($E) {
    $where = $E.InvocationInfo
    if ($null -eq $where -or $where.ScriptLineNumber -le 0) { return [string]$E.Exception.Message }
    $file = if ([string]::IsNullOrEmpty($where.ScriptName)) { 'script' } else { [IO.Path]::GetFileName($where.ScriptName) }
    return ('{0} ({1} line {2})' -f $E.Exception.Message, $file, $where.ScriptLineNumber)
}

# ---------------------------------------------------------------- a point

# The flight for a check point or a cruise level ($Pt: id, fl, mach, and
# gw_pct or fuel_kg), into $Res: the weights (the payload by the stations'
# maximum, the fuel in the aircraft's load order), the flight's init, the MCP
# back to IAS, the air start, the read-back checks, the logger
# (raw\<id>.csv), the engines 8 s on and the aircraft's engine type
function Start-PerfFlight($Res, $Pt, $Acf, [double[]]$StationKg) {
    $cap = [double[]]@(0..8 | ForEach-Object { $Acf.tank_rat[$_] * $Acf.m_fuel_tot_kg })
    if ($null -ne $Pt.fuel_kg) { $fuelReq = [double]$Pt.fuel_kg }
    else { $fuelReq = $MtowKg * $Pt.gw_pct / 100 - $Acf.m_empty_kg - $PayloadKg }
    $tanks = Get-FuelByTank $fuelReq $cap
    $sumSt = 0.0
    foreach ($v in $StationKg) { $sumSt += $v }
    $payload = [double[]]@($StationKg | ForEach-Object { $PayloadKg * $_ / $sumSt })
    $init = New-PerfInit $Pt $payload $tanks
    Save-Json (Join-Path $out "init_$($Pt.id).json") $init
    $payReq = 0.0; foreach ($v in $init.weight.payload_weight_in_kilograms) { $payReq += $v }
    $tankReq = [double[]]@($init.weight.fueltank_weight_in_kilograms)
    $fuelReq = 0.0; foreach ($v in $tankReq) { $fuelReq += $v }
    $Res.request = [ordered]@{ gw_kg = $Acf.m_empty_kg + $payReq + $fuelReq; payload_kg = $payReq; fuel_kg = $fuelReq
        tanks_kg = $tankReq; stations_kg = @($init.weight.payload_weight_in_kilograms)
        tas_ms = $init.lle_air_start.speed_in_meters_per_second; elevation_m = $init.lle_air_start.elevation_in_meters }
    $Res.request.zfw_kg = $Acf.m_empty_kg + $payReq
    $Res.request.gw_pct = $Res.request.gw_kg / $MtowKg * 100
    if ($Res.request.zfw_kg -gt $MzfwKg) { Note warn ('{0}: zero fuel weight {1} kg above the MZFW {2}' -f $Pt.id, (F $Res.request.zfw_kg '0'), (F $MzfwKg '0')) }
    Note info ('{0}: gross {1} kg ({2} % of the MTOW {3}), payload {4} kg, fuel {5} kg, FL{6}, M{7} (true {8} m/s)' -f $Pt.id,
        (F $Res.request.gw_kg '0'), (F $Res.request.gw_pct '0.#'), (F $MtowKg '0'), (F $payReq '0'), (F $fuelReq '0'), $Pt.fl, $Pt.mach,
        $Res.request.tas_ms)

    # the MCP back to IAS before the start (a Mach window would be wound in knots)
    try {
        if ((Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 1 -and (Get-Num 'sim/flightmodel/misc/machno') -gt 0.4) {
            Push-Button 'sim/autopilot/knots_mach_toggle'
        }
    } catch { }
    $tStart = Start-PerfAirStart $init
    $wStart = $wall.Elapsed.TotalSeconds
    # read back at once (a few seconds of burn since the start)
    $rb = Get-PerfWeights
    $Res.readback = $rb
    $dPay = $rb.payload_kg - $payReq
    $dTank = New-Object double[] 9
    for ($i = 0; $i -lt 9; $i++) { $dTank[$i] = $rb.tanks_kg[$i] - $tankReq[$i] }
    $dFuel = $rb.fuel_kg - $fuelReq
    $dGw = $rb.gw_kg - $Res.request.gw_kg
    Add-Check $Res 'readback_payload' ([math]::Abs($dPay) -le 1) ('{0} kg, {1} kg off' -f (F $rb.payload_kg '0.0'), (F $dPay '0.0')) '|off| <= 1 kg'
    Add-Check $Res 'readback_tanks' ((Get-MaxAbs $dTank) -le 30) ('largest tank off {0} kg ({1} s after the start)' -f (F (Get-MaxAbs $dTank) '0.0'),
        (F ($rb.sim_t - $tStart) '0.0')) '<= 30 kg (a few seconds of burn)'
    Add-Check $Res 'readback_fuel' (($dFuel -le 1) -and ($dFuel -ge -60)) ('{0} kg, {1} kg off' -f (F $rb.fuel_kg '0'), (F $dFuel '0.0')) '-60 to +1 kg'
    Add-Check $Res 'readback_gross' ([math]::Abs($dGw) -le 60) ('{0} kg, {1} kg off' -f (F $rb.gw_kg '0'), (F $dGw '0.0')) '|off| <= 60 kg'

    Start-PerfLogger (Join-Path $out "raw\$($Pt.id).csv")
    $Res.rows0 = (Get-PerfRows).Count

    # the engines 8 s after the start
    $left = 8 - ($wall.Elapsed.TotalSeconds - $wStart)
    if ($left -gt 0) { Start-Sleep -Milliseconds ([int]($left * 1000)) }
    $burning = @(Get-XPDataref 'sim/flightmodel2/engines/engine_is_burning_fuel')
    $n2 = @(Get-XPDataref 'sim/cockpit2/engine/indicators/N2_percent')
    $off = @(0..3 | Where-Object { [int]$burning[$_] -ne 1 -or [double]$n2[$_] -lt 60 } | ForEach-Object { $_ + 1 })
    Add-Check $Res 'engines_running' ($off.Count -eq 0) ('N2 {0} %; not burning or below 60 % N2: {1}' -f
        ((@(0..3 | ForEach-Object { F ([double]$n2[$_]) '0.0' })) -join '/'), $(if ($off.Count) { $off -join ',' } else { 'none' })) 'all 4 burning, N2 > 60 %'

    $ac = Get-PerfAircraft
    $Res.aircraft = $ac
    Add-Check $Res 'engine_type_pw4056' (($ac.engine_type -eq 0) -and ($ac.simconfig_engines -eq 'PW4056')) `
        ('engines/type {0}, simconfig "{1}", livery "{2}"' -f $ac.engine_type, $ac.simconfig_engines, $ac.livery_path) 'type 0 (PW), PW4056'
}

# the A/P and A/T after Set-PerfCruise: ALT, SPD, Mach on the point's Mach, servos
function Add-PerfSetupCheck($Res, [double]$Mach) {
    $s = $Res.setup
    Add-Check $Res 'ap_alt_spd_mach' (($s.fma_pitch -eq 9) -and ($s.fma_at -eq 3) -and ($s.is_mach -eq 1) -and
        ([math]::Abs($s.ap_mach_target - $Mach) -lt 0.0005) -and ($s.servos_on -eq 1)) `
        ('pitch {0}, A/T {1}, Mach mode {2}, target {3}, servos {4}' -f $s.fma_pitch, $s.fma_at, $s.is_mach,
        (F $s.ap_mach_target '0.000'), $s.servos_on) 'ALT (9), SPD (3), Mach, the point''s Mach, servos on'
}

# level within the limits for 60 s, in 6 min of sim time from now
# (PERF_SIMBRIEF.md phase 1): the row it was so at, or none and why
# (Get-PerfUnsettled); from the row count now
function Wait-PerfStable([double]$Ft, [double]$Mach) {
    $from = (Get-PerfRows).Count
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        Start-Sleep -Seconds 2
        Assert-PerfLogger
        $rows = Get-PerfRows
        $since = $rows.Count - $from
        if ($since -ge 60 -and (Test-Stable $rows $Ft $Mach 60)) {
            return [ordered]@{ from = $from; stable_at = $rows.Count; after_s = $since; status = 'stable'; detail = $null }
        }
        if ($since -ge 360 -or $sw.Elapsed.TotalSeconds -gt 480) { break }
    }
    $rows = Get-PerfRows
    $u = Get-PerfUnsettled $rows $Ft $Mach
    return [ordered]@{ from = $from; stable_at = $null; after_s = $rows.Count - $from; status = $u.status; detail = $u.detail; end = $u }
}

# the window: the $Secs rows from $StableAt
function Measure-PerfAt([int]$StableAt, [int]$Secs) {
    $need = $StableAt + $Secs
    while ((Get-PerfRows).Count -lt $need) { Start-Sleep -Seconds 2; Assert-PerfLogger }
    $rows = Get-PerfRows
    return Measure-PerfWindow @($rows[$StableAt..($need - 1)])
}
# the window held within the limits, in real time
function Test-PerfHeld($W) {
    return (($null -ne $W.ff_fuelmass_kgph) -and ($W.alt_range_ft -le 60) -and ($W.mach_range -le 0.006) -and
        ($W.vs_max_abs -lt 100) -and ($W.rows_real_time -eq $W.rows))
}
function Format-PerfHeld($W) {
    if ($null -eq $W.ff_fuelmass_kgph) { return ('{0} of {1} rows in real time' -f $W.rows_real_time, $W.rows) }
    return ('alt range {0} ft, Mach range {1}, V/S max {2} fpm, real-time rows {3}/{4}' -f (F $W.alt_range_ft '0'), (F $W.mach_range '0.0000'),
        (F $W.vs_max_abs '0'), $W.rows_real_time, $W.rows)
}
function Format-PerfFlows($W) {
    return ('fuel weight {0} kg/h, gauges {1} kg/h: {2} %; on wall time {3} kg/h ({4} %); FUEL USED {5} kg/h, on wall time {6} kg/h (SIM_PERIOD covered {7} of the wall time); sim/wall {8}, {9} fps' -f
        (F $W.ff_fuelmass_kgph '0'), (F $W.ff_gauge_kgph '0'), (F $W.ff_diff_pct '0.00'), (F $W.ff_fuelmass_wall_kgph '0'),
        (F $W.ff_wall_diff_pct '0.00'), (F $W.ff_totaliser_kgph '0'), (F $W.ff_totaliser_wall_kgph '0'), (F $W.sim_period_share '0.0000'),
        (F $W.sim_per_wall '0.0000'), (F $W.fps '0')) +
        $(if ($null -ne $W.sfc_factor -and -not [double]::IsNaN([double]$W.sfc_factor)) { '; fuel per thrust x{0} the acf''s' -f (F $W.sfc_factor '0.0000') } else { '' })
}

# writes by the aircraft from the logger's start (3 s on) to now, and the
# modes at the end (the pitch mode, the A/T's modes, their names; phase 2's
# ceilings end climbing in FLCH)
function Add-PerfWritesChecks($Res, [int]$Pitch = 9, [int[]]$At = @(3), [string]$Modes = 'ALT, SPD') {
    $rows = Get-PerfRows
    $from = [math]::Min($Res.rows0 + 3, $rows.Count - 1)
    $wr = Measure-PerfWrites @($rows[$from..($rows.Count - 1)])
    $Res.writes = $wr
    Add-Check $Res 'payload_unchanged' ($wr.payload_range_kg -le 0.5) ('range {0} kg over {1} s' -f (F $wr.payload_range_kg '0.00'), (F $wr.sim_s '0')) '<= 0.5 kg'
    Add-Check $Res 'zfw_unchanged' ($wr.zfw_range_kg -le 1.0) ('range {0} kg' -f (F $wr.zfw_range_kg '0.00')) '<= 1 kg'
    Add-Check $Res 'fuel_no_jumps' ($wr.fuel_step_residual_max_kg -le 5) ('largest second-to-second fall off the gauges {0} kg (mean {1} kg), fastest tank {2} kg/s, used {3} kg' -f
        (F $wr.fuel_step_residual_max_kg '0.00'), (F $wr.fuel_step_residual_mean_kg '0.000'), (F $wr.tank_rate_max_kg_s '0.00'), (F $wr.fuel_used_kg '0')) '<= 5 kg a second'
    Add-Check $Res 'no_time_acceleration' ($wr.rows_time_accelerated -eq 0) ('{0} rows with sim_speed or ground_speed not 1' -f $wr.rows_time_accelerated) '0'
    $last = $rows[$rows.Count - 1]
    $Res.end = [ordered]@{ fma_pitch = $last[$script:ix['fma']]; fma_at = $last[$script:ix['fma_at']]; servos_on = $last[$script:ix['servos_on']]
        burning = @(1..4 | ForEach-Object { $last[$script:ix["burning_$_"]] }) }
    Add-Check $Res 'modes_at_end' (($Res.end.fma_pitch -eq $Pitch) -and (@($At) -contains [int]$Res.end.fma_at) -and ($Res.end.servos_on -eq 1) -and
        (@($Res.end.burning | Where-Object { $_ -ne 1 }).Count -eq 0)) ('pitch {0}, A/T {1}, servos {2}, burning {3}' -f $Res.end.fma_pitch,
        $Res.end.fma_at, $Res.end.servos_on, ($Res.end.burning -join '/')) "$Modes, servos on, all burning"
}

# A check point (suite check): the flight, the A/P, 60 s level, the window
function Invoke-PerfCheckPoint($Pt, $Acf, [double[]]$StationKg) {
    $res = [ordered]@{ id = $Pt.id; target = $Pt; status = 'done'; checks = [ordered]@{} }
    try {
        $ft = [double]$Pt.fl * 100
        Start-PerfFlight $res $Pt $Acf $StationKg
        $res.setup = Set-PerfCruise $ft ([double]$Pt.mach)
        Add-PerfSetupCheck $res ([double]$Pt.mach)
        $st = Wait-PerfStable $ft ([double]$Pt.mach)
        $res.settle = $st
        if ($null -eq $st.stable_at) {
            Add-Check $res 'stable_in_6_min' $false $st.detail '30 ft, M.003, 100 fpm for 60 s'
            $res.status = $st.status
        } else {
            Add-Check $res 'stable_in_6_min' $true ('{0} s of sim time after the setup' -f $st.after_s) '30 ft, M.003, 100 fpm for 60 s'
            $res.window = Measure-PerfAt $st.stable_at ([int]$Pt.measure_s)
            $w = $res.window
            Add-Check $res 'held_through_window' (Test-PerfHeld $w) (Format-PerfHeld $w) 'within the limits, no time acceleration'
            if ($null -eq $w.ff_fuelmass_kgph) { $res.status = 'no_window' }
            else { Add-Check $res 'fuel_flow_agreement' ([math]::Abs($w.ff_diff_pct) -le 2) (Format-PerfFlows $w) '|diff| <= 2 % (PERF_SIMBRIEF.md phase 0.3)' }
        }
        Add-PerfWritesChecks $res
    } catch {
        $res.status = 'aborted'
        $res.error = Format-PerfError $_
        Note fail "$($Pt.id): $($res.error)"
    } finally {
        $res.raw_file = "raw/$($Pt.id).csv"
        if ($null -ne $script:logger) { $res.columns_missing = $script:logger.missing }
        Stop-PerfLogger
    }
    return $res
}

# A cruise level (suite cruise): the flight at its first Mach, the CI's Mach
# when asked (the CDU), then each Mach in place: 60 s level in 6 min, then
# $MeasureS s averaged; each point's rows, from its Mach's setting to its
# window's end, in raw\<point>.csv. A Mach not held (hold_unable) leaves the
# level's faster ones untried.
function Invoke-PerfLevel($Lv, $Acf, [double[]]$StationKg) {
    $res = [ordered]@{ id = $Lv.id; target = $Lv; status = 'done'; checks = [ordered]@{}; points = New-Object System.Collections.ArrayList }
    try {
        $ft = [double]$Lv.fl * 100
        $machs = [double[]]@($Lv.machs)
        $pt = [ordered]@{ id = $Lv.id; fl = $Lv.fl; mach = $machs[0]; gw_pct = $Lv.gw_pct; fuel_kg = $Lv.fuel_kg }
        Start-PerfFlight $res $pt $Acf $StationKg
        $res.setup = Set-PerfCruise $ft $machs[0]
        Add-PerfSetupCheck $res $machs[0]
        if ($Lv.ci_check) {
            $ci = Measure-PerfCiMach $CruiseCi $ft
            $res.ci = $ci
            $pass = $null
            if ($null -ne $ci.mach) { $pass = ($ci.mach -ge $machs[0]) -and ($ci.mach -le $machs[$machs.Length - 1]) }
            Add-Check $res 'ci_mach' $pass ('CI {0}: {1} on the VNAV CRZ page ("{2}"){3}' -f $ci.ci,
                $(if ($null -ne $ci.mach) { F $ci.mach '0.000' } else { 'no Mach' }), $ci.title, $(if ($ci.note) { '; ' + $ci.note } else { '' })) `
                ('within the Machs {0}-{1}' -f (F $machs[0] '0.00'), (F $machs[$machs.Length - 1] '0.00'))
            # the CDU's entries leave the MCP alone; to be sure
            if ((Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -ne 1 -or
                [math]::Abs((Get-Num 'sim/cockpit2/autopilot/airspeed_dial_kts_mach') - $machs[0]) -ge 0.0005) {
                Note warn 'the MCP changed during the CDU entries: its Mach again'
                [void](Set-PerfMcpMach $machs[0])
            }
        }
        $held = $true
        foreach ($m in $machs) {
            # (aborted until it is measured or found unsettled)
            $p = [ordered]@{ id = (Get-PerfPointId $Lv.id $m); level = $Lv.id; target_mach = $m; status = 'aborted'; detail = $null; raw_file = $null }
            [void]$res.points.Add($p)
            if (-not $held) {
                $p.status = 'hold_unable'
                $p.detail = 'not tried: a slower Mach was not held'
                Note warn "$($p.id): $($p.detail)"
                continue
            }
            if ($m -ne $machs[0]) { $p.mach_tries = Set-PerfMcpMach $m }
            $st = Wait-PerfStable $ft $m
            $p.settle = $st
            $to = (Get-PerfRows).Count - 1
            if ($null -eq $st.stable_at) {
                $p.status = $st.status
                $p.detail = $st.detail
                if ($st.status -eq 'hold_unable') { $held = $false }
                Note warn ('{0}: {1}, {2}' -f $p.id, $p.status, $p.detail)
            } else {
                $p.window = Measure-PerfAt $st.stable_at $MeasureS
                $to = $st.stable_at + $MeasureS - 1
                $w = $p.window
                $p.status = 'done'
                if (-not (Test-PerfHeld $w)) {
                    $p.status = $(if ($null -eq $w.ff_fuelmass_kgph) { 'no_window' } else { 'not_held' })
                    $p.detail = Format-PerfHeld $w
                }
                Note $(if ($p.status -eq 'done') { 'pass' } else { 'warn' }) ('{0}: {1} t, {2} ft, M{3}, level after {4} s: {5}' -f $p.id,
                    (F ($w.weight / 1000) '0.0'), (F $w.press_alt_ft '0'), (F $w.mach '0.0000'), $st.after_s, (Format-PerfFlows $w))
            }
            $p.raw_file = "raw/$($p.id).csv"
            Save-PerfRows (Join-Path $out $p.raw_file) (Get-PerfRows) $st.from $to
        }
        Add-PerfWritesChecks $res
    } catch {
        $res.status = 'aborted'
        $res.error = Format-PerfError $_
        Note fail "$($Lv.id): $($res.error)"
    } finally {
        $res.raw_file = "raw/$($Lv.id).csv"
        if ($null -ne $script:logger) { $res.columns_missing = $script:logger.missing }
        Stop-PerfLogger
    }
    return $res
}

# the repeat (PERF_SIMBRIEF.md phase 1): the first and the last window of the
# same point, their flows' difference (report over 1 %)
function Compare-PerfRepeat($First, $Last) {
    if ($null -eq $First -or $null -eq $Last -or $null -eq $First.ff_fuelmass_kgph -or $null -eq $Last.ff_fuelmass_kgph) { return $null }
    $d = ($Last.ff_fuelmass_kgph / $First.ff_fuelmass_kgph - 1) * 100
    return [ordered]@{ first_kgph = $First.ff_fuelmass_kgph; last_kgph = $Last.ff_fuelmass_kgph; diff_pct = $d
        gauge_first_kgph = $First.ff_gauge_kgph; gauge_last_kgph = $Last.ff_gauge_kgph
        gauge_diff_pct = ($Last.ff_gauge_kgph / $First.ff_gauge_kgph - 1) * 100
        first_weight_kg = $First.weight; last_weight_kg = $Last.weight; within_1_pct = ([math]::Abs($d) -le 1) }
}

# ---------------------------------------------------------------- the climbs (phase 2)

# a mark between the rows $K - 1 and $K at the fraction $F (1: the row $K):
# the values there, the time since $T0 (sim time), the fuel used since $F0
# (the fuel's weight), the FF gauges' integral and the distances to there
# ($Ffu, $Air, $Gnd: running sums by row)
function New-PerfMark($Rows, [int]$K, [double]$F, [string]$Label, [double]$T0, [double]$F0, [double[]]$Air, [double[]]$Gnd, [double[]]$Ffu) {
    $ix = $script:ix
    $j = [math]::Max($K - 1, 0)
    $a = $Rows[$j]; $b = $Rows[$K]
    $lerp = { param([string]$c) $a[$ix[$c]] + $F * ($b[$ix[$c]] - $a[$ix[$c]]) }
    $n1a = 0.0; $n1b = 0.0
    foreach ($e in 1..4) { $n1a += $a[$ix["n1_$e"]]; $n1b += $b[$ix["n1_$e"]] }
    return [ordered]@{ mark = $Label; row = $K; press_alt_ft = (& $lerp 'press_alt_ft'); t_s = (& $lerp 'sim_t') - $T0
        fuel_used_kg = $F0 - (& $lerp 'fuel_kg'); ff_gauge_used_kg = $Ffu[$j] + $F * ($Ffu[$K] - $Ffu[$j])
        dist_air_nm = $Air[$j] + $F * ($Air[$K] - $Air[$j]); dist_gnd_nm = $Gnd[$j] + $F * ($Gnd[$K] - $Gnd[$j])
        gw_kg = (& $lerp 'weight'); ias_kt = (& $lerp 'ias'); mach = (& $lerp 'mach'); n1_avg_pct = ($n1a + $F * ($n1b - $n1a)) / 4
        vminm_kt = (& $lerp 'vminm'); thrlim = $b[$ix['thrlim']]; fma = $b[$ix['fma']]; fma_at = $b[$ix['fma_at']]
        seg_vs_fpm = [double]::NaN }
}

# A climb's marks from the row $From (the FLCH push; PERF_SIMBRIEF.md phase 2:
# every 5,000 ft the time, the fuel used and the distance flown): the start
# row, then the first crossing of each of $MarksFt and, with $TopFt, of the
# top less $ClimbTopMarginFt, each between its two rows (pressure
# altitude). The fuel from the fuel's weight, the FF gauges' integral beside
# it; the air and the ground distance from the TAS and the ground speed (the
# same in still air); each mark's segment's mean climb rate. The rows to the
# last mark in real time, and the thrust limit's codes over them. $Dir -1: a
# descent, the marks crossed going down and the bottom's $ClimbTopMarginFt
# above $TopFt (top_reached: the end reached).
function Measure-PerfClimb($Rows, [int]$From, [double[]]$MarksFt, $TopFt, [int]$Dir = 1) {
    $ix = $script:ix
    $n = $Rows.Count
    $m = [ordered]@{ from = $From; marks = New-Object System.Collections.ArrayList; top_reached = $false
        rows_to_end = 0; rows_real_time = 0; thrlim_codes = '' }
    if ($n - $From -lt 2) { return $m }
    $iT = $ix['sim_t']; $iA = $ix['press_alt_ft']
    $t0 = $Rows[$From][$iT]; $f0 = $Rows[$From][$ix['fuel_kg']]
    $air = New-Object double[] $n; $gnd = New-Object double[] $n; $ffu = New-Object double[] $n
    for ($k = $From + 1; $k -lt $n; $k++) {
        $dt = $Rows[$k][$iT] - $Rows[$k - 1][$iT]
        $air[$k] = $air[$k - 1] + ($Rows[$k][$ix['tas_ms']] + $Rows[$k - 1][$ix['tas_ms']]) / 2 * $dt / 1852
        $gnd[$k] = $gnd[$k - 1] + ($Rows[$k][$ix['gs_ms']] + $Rows[$k - 1][$ix['gs_ms']]) / 2 * $dt / 1852
        $ffu[$k] = $ffu[$k - 1] + ((Get-FfSum $Rows[$k]) + (Get-FfSum $Rows[$k - 1])) / 2 * $dt
    }
    [void]$m.marks.Add((New-PerfMark $Rows $From 1.0 'start' $t0 $f0 $air $gnd $ffu))
    $targets = New-Object System.Collections.ArrayList
    foreach ($ft in $MarksFt) { [void]$targets.Add(@([double]$ft, ([string][int]$ft))) }
    if ($null -ne $TopFt) {
        $endLabel = $(if ($Dir -gt 0) { 'top ' } else { 'bottom ' }) + [int]$TopFt
        [void]$targets.Add(@(([double]$TopFt - $Dir * $ClimbTopMarginFt), $endLabel))
    }
    $k = $From + 1
    $lastRow = $From
    foreach ($tg in $targets) {
        $ft = [double]$tg[0]
        # (a mark the start is at or past: none)
        if ($Dir * ($Rows[$From][$iA] - $ft) -ge 0) { continue }
        while ($k -lt $n -and $Dir * ($Rows[$k][$iA] - $ft) -lt 0) { $k++ }
        if ($k -ge $n) { break }
        $a0 = $Rows[$k - 1][$iA]; $a1 = $Rows[$k][$iA]
        $f = 1.0
        if ($a1 -ne $a0) { $f = [math]::Min(1.0, [math]::Max(0.0, ($ft - $a0) / ($a1 - $a0))) }
        $mk = New-PerfMark $Rows $k $f ([string]$tg[1]) $t0 $f0 $air $gnd $ffu
        $prev = $m.marks[$m.marks.Count - 1]
        if ($mk.t_s -gt $prev.t_s) { $mk.seg_vs_fpm = ($mk.press_alt_ft - $prev.press_alt_ft) / ($mk.t_s - $prev.t_s) * 60 }
        [void]$m.marks.Add($mk)
        $lastRow = $k
        if (([string]$tg[1]) -match '^(top|bottom) ') { $m.top_reached = $true }
    }
    $rt = 0
    $codes = [ordered]@{}
    for ($j = $From; $j -le $lastRow; $j++) {
        $r = $Rows[$j]
        if ($r[$ix['paused']] -eq 0 -and $r[$ix['sim_speed']] -eq 1 -and $r[$ix['ground_speed_x']] -eq 1) { $rt++ }
        $c = [string][int]$r[$ix['thrlim']]
        $codes[$c] = 1 + [int]$codes[$c]
    }
    $m.rows_to_end = $lastRow - $From + 1
    $m.rows_real_time = $rt
    $m.thrlim_codes = (@($codes.Keys | ForEach-Object { '{0}: {1} rows' -f $_, $codes[$_] })) -join ', '
    # (CLB without a derate: 20; before 2026-11-08 the kit looked for 2, the
    # code's old form, and would have failed every climb)
    $m.thrlim_clb_only = ($codes.Count -eq 1 -and $codes.Contains('20'))
    return $m
}

# The climb rate (fpm) of a straight line through each $Win rows of pressure
# altitude on sim time from the row $From, put at the window's middle row:
# @{ row; t_s (the window's mean time since the row $From); alt_ft (its mean
# altitude); rate_fpm } each (running sums, the window sliding a row a time)
function Get-PerfClimbRates($Rows, [int]$From, [int]$Win) {
    $ix = $script:ix; $iT = $ix['sim_t']; $iA = $ix['press_alt_ft']
    $n = $Rows.Count
    $out = New-Object System.Collections.ArrayList
    if ($Win -lt 3 -or $n - $From -lt $Win) { return ,$out.ToArray() }
    $t0 = $Rows[$From][$iT]; $y0 = $Rows[$From][$iA]
    $st = 0.0; $sy = 0.0; $stt = 0.0; $sty = 0.0
    for ($k = $From; $k -lt $From + $Win; $k++) {
        $t = $Rows[$k][$iT] - $t0; $y = $Rows[$k][$iA] - $y0
        $st += $t; $sy += $y; $stt += $t * $t; $sty += $t * $y
    }
    $half = [int][math]::Floor($Win / 2)
    for ($j = $From; $j + $Win -le $n; $j++) {
        if ($j -gt $From) {
            $t = $Rows[$j - 1][$iT] - $t0; $y = $Rows[$j - 1][$iA] - $y0
            $st -= $t; $sy -= $y; $stt -= $t * $t; $sty -= $t * $y
            $t = $Rows[$j + $Win - 1][$iT] - $t0; $y = $Rows[$j + $Win - 1][$iA] - $y0
            $st += $t; $sy += $y; $stt += $t * $t; $sty += $t * $y
        }
        $d = $Win * $stt - $st * $st
        $rate = [double]::NaN
        if ($d -gt 0) { $rate = ($Win * $sty - $st * $sy) / $d * 60 }
        [void]$out.Add([ordered]@{ row = $j + $half; t_s = $st / $Win; alt_ft = $y0 + $sy / $Win; rate_fpm = $rate })
    }
    return ,$out.ToArray()
}

# The ceiling (PERF_SIMBRIEF.md phase 2: the climb thrust, M.85; the FCOM's
# criteria since 2026-11-08), the first of
#   thrust  from the rates (Get-PerfClimbRates): once a rate has been
#           $ArmFpm or more (the climb under way), the first one under
#           $RateFpm that stays under it for the $HoldN rates on; the altitude
#           and time where the rate crossed $RateFpm, between that rate and
#           the one before;
#   buffet  the first row at or over the FCOM's 1.30 g altitude at its weight
#           (Get-PerfFcomBuffet130Ft) after one under it; the altitude and
#           time of the crossing, between the two rows.
# limit says which; fcom_ft is the FCOM's 1.30 g altitude at the ceiling's
# row's weight (none found: the last row's). found false while there is none
# (yet).
function Get-PerfCeiling($Rows, [int]$From, [double]$RateFpm, [int]$Win, [double]$ArmFpm, [int]$HoldN) {
    $rates = Get-PerfClimbRates $Rows $From $Win
    $c = [ordered]@{ found = $false; limit = $null; ceiling_ft = [double]::NaN; t_s = [double]::NaN; row = $null; armed = $false
        max_rate_fpm = [double]::NaN; last_rate_fpm = [double]::NaN; last_alt_ft = [double]::NaN; fcom_ft = [double]::NaN; rates = $rates.Count }
    $max = [double]::NegativeInfinity
    $armed = $false
    for ($j = 0; $j -lt $rates.Count; $j++) {
        $r = $rates[$j].rate_fpm
        if ($r -gt $max) { $max = $r }
        if (-not $armed) { if ($r -ge $ArmFpm) { $armed = $true }; continue }
        if ($r -ge $RateFpm) { continue }
        if ($j + $HoldN -ge $rates.Count) { break }
        $held = $true
        for ($h = 1; $h -le $HoldN; $h++) { if ($rates[$j + $h].rate_fpm -ge $RateFpm) { $held = $false; break } }
        if (-not $held) { continue }
        # (the rate before is at or over $RateFpm: else it had been held first)
        $p = $rates[$j - 1]; $q = $rates[$j]
        $f = 1.0
        if ($p.rate_fpm -ne $q.rate_fpm) { $f = ($p.rate_fpm - $RateFpm) / ($p.rate_fpm - $q.rate_fpm) }
        $c.found = $true
        $c.limit = 'thrust'
        $c.ceiling_ft = $p.alt_ft + $f * ($q.alt_ft - $p.alt_ft)
        $c.t_s = $p.t_s + $f * ($q.t_s - $p.t_s)
        $c.row = $q.row
        break
    }
    $c.armed = $armed
    if ($rates.Count -gt 0) {
        $c.max_rate_fpm = $max
        $c.last_rate_fpm = $rates[$rates.Count - 1].rate_fpm
        $c.last_alt_ft = $rates[$rates.Count - 1].alt_ft
    }
    # the buffet: the rows against the FCOM's 1.30 g altitude at their weight,
    # until the thrust's ceiling if that came first
    $ix = $script:ix; $iT = $ix['sim_t']; $iA = $ix['press_alt_ft']; $iW = $ix['weight']
    if ($Rows.Count -gt $From + 1) {
        $t0 = $Rows[$From][$iT]
        $capP = Get-PerfFcomBuffet130Ft $Rows[$From][$iW]
        for ($k = $From + 1; $k -lt $Rows.Count; $k++) {
            $p = $Rows[$k - 1]; $q = $Rows[$k]
            if ($c.found -and $p[$iT] - $t0 -ge $c.t_s) { break }
            $capQ = Get-PerfFcomBuffet130Ft $q[$iW]
            if ($p[$iA] -lt $capP -and $q[$iA] -ge $capQ) {
                $dp = $capP - $p[$iA]; $dq = $q[$iA] - $capQ
                $f = if ($dp + $dq -gt 0) { $dp / ($dp + $dq) } else { 1.0 }
                $bt = $p[$iT] - $t0 + $f * ($q[$iT] - $p[$iT])
                if (-not $c.found -or $bt -lt $c.t_s) {
                    $c.found = $true
                    $c.limit = 'buffet'
                    $c.ceiling_ft = $p[$iA] + $f * ($q[$iA] - $p[$iA])
                    $c.t_s = $bt
                    $c.row = $k
                }
                break
            }
            $capP = $capQ
        }
    }
    if ($Rows.Count -gt 0) {
        $wr = if ($c.found) { [math]::Min([int]$c.row, $Rows.Count - 1) } else { $Rows.Count - 1 }
        $c.fcom_ft = Get-PerfFcomBuffet130Ft $Rows[$wr][$iW]
    }
    return $c
}

# level at $Ft for $HoldS rows within 50 ft, 300 fpm and the speed (3 kt of
# $Kias, else M.005 of $Mach), in $MaxS s of sim time from now (phase 2's
# starts, wider than phase 1's limits: the climbs begin there)
function Wait-PerfLevelAt([double]$Ft, [double]$Kias, [double]$Mach, [int]$HoldS, [int]$MaxS) {
    $ix = $script:ix
    $from = (Get-PerfRows).Count
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        Start-Sleep -Seconds 2
        Assert-PerfLogger
        $rows = Get-PerfRows
        $since = $rows.Count - $from
        if ($since -ge $HoldS) {
            $ok = $true
            for ($k = $rows.Count - $HoldS; $k -lt $rows.Count; $k++) {
                $r = $rows[$k]
                if ([math]::Abs($r[$ix['alt']] - $Ft) -gt 50 -or [math]::Abs($r[$ix['vs']]) -ge 300) { $ok = $false; break }
                if ($Kias -gt 0) { if ([math]::Abs($r[$ix['ias']] - $Kias) -gt 3) { $ok = $false; break } }
                elseif ([math]::Abs($r[$ix['mach']] - $Mach) -gt 0.005) { $ok = $false; break }
            }
            if ($ok) { return [ordered]@{ ok = $true; row = $rows.Count - 1; after_s = $since; detail = $null } }
        }
        if ($since -ge $MaxS -or $sw.Elapsed.TotalSeconds -gt $MaxS + 120) { break }
    }
    $rows = Get-PerfRows
    $r = $rows[$rows.Count - 1]
    return [ordered]@{ ok = $false; row = $rows.Count - 1; after_s = $rows.Count - $from
        detail = ('alt {0} ft, IAS {1} kt, Mach {2}, V/S {3} fpm' -f (F $r[$ix['alt']] '0'), (F $r[$ix['ias']] '0.0'), (F $r[$ix['mach']] '0.000'),
            (F $r[$ix['vs']] '0')) }
}

# FLCH to the MCP altitude (set first), the pitch in FLCH (8) and the A/T in
# one of $At 3 s on (a climb's THR 4 or THR REF 5; a descent's THR, IDLE 2 or
# HOLD 1): the logger's row at the push
function Start-PerfFlch($Res, [double]$McpFt, [int[]]$At = @(4, 5), [string]$AtNames = 'THR (4) or THR REF (5)') {
    Set-XPDataref 'laminar/B747/autopilot/heading/altitude_dial_ft' ([int]$McpFt)
    Start-Sleep -Milliseconds 500
    $from = (Get-PerfRows).Count
    Push-Button 'laminar/B747/autopilot/button_switch/flch_mode'
    [void](Wait-XP { (Get-Int 'laminar/B747/autopilot/FMA/active_pitch_mode') -eq 8 } 10 200)
    Start-Sleep -Seconds 3
    $pm = Get-Int 'laminar/B747/autopilot/FMA/active_pitch_mode'
    $atm = Get-Int 'laminar/B747/autopilot/FMA/autothrottle_mode'
    Add-Check $Res 'flch_engaged' (($pm -eq 8) -and (@($At) -contains $atm)) ('pitch {0}, A/T {1}, MCP {2} ft' -f $pm, $atm,
        (Get-Num 'laminar/B747/autopilot/heading/altitude_dial_ft')) "FLCH (8), A/T $AtNames"
    return $from
}

# the climb's checks on its marks: the rows in real time, the thrust limit CLB
function Add-PerfClimbChecks($Res) {
    $c = $Res.climb
    Add-Check $Res 'climb_real_time' ($c.rows_real_time -eq $c.rows_to_end) ('{0} of {1} rows to the last mark' -f $c.rows_real_time, $c.rows_to_end) 'all (no time acceleration, not paused)'
    Add-Check $Res 'climb_thrust_clb' $c.thrlim_clb_only $c.thrlim_codes 'the reference thrust CLB (20, no derate) all the way'
}

# A climb (suite climb; PERF_SIMBRIEF.md phase 2): an air start at 10,000 ft
# and 250 kt, level there (20 s within the limits, in 3 min), then FLCH to
# the top and 340 kt; the MCP in Mach .84 once the Mach reaches it (the
# schedule 250/340/84); the marks (Measure-PerfClimb) from the FLCH push to
# the top; 60 s on for the capture (ALT and SPD at the end). Not at the top
# in 45 min of sim time: timeout, with the marks reached.
function Invoke-PerfClimb($T, $Acf, [double[]]$StationKg) {
    $res = [ordered]@{ id = $T.id; kind = 'climb'; target = $T; status = 'done'; checks = [ordered]@{} }
    try {
        $m0 = Get-MachFromCas $ClimbStartKias $ClimbStartFt
        $pt = [ordered]@{ id = $T.id; fl = $ClimbStartFt / 100; mach = $m0; gw_pct = $T.gw_pct; fuel_kg = $T.fuel_kg }
        Start-PerfFlight $res $pt $Acf $StationKg
        # the logger's columns once it runs: Start-PerfLogger makes a new
        # table, and one taken before is the last flight's, or a run's first
        # flight's empty one (2026-11-08 the first climb stopped on it: "the
        # array index evaluated to null")
        $ix = $script:ix
        $res.setup = Set-PerfCruise $ClimbStartFt $m0 $ClimbStartKias
        $s = $res.setup
        Add-Check $res 'ap_alt_spd_ias' (($s.fma_pitch -eq 9) -and ($s.fma_at -eq 3) -and ($s.is_mach -eq 0) -and ($s.servos_on -eq 1)) `
            ('pitch {0}, A/T {1}, Mach mode {2}, target {3} kt, servos {4}' -f $s.fma_pitch, $s.fma_at, $s.is_mach, (F $s.ap_mach_target '0.0'), $s.servos_on) `
            'ALT (9), SPD (3), IAS, servos on'
        $lv = Wait-PerfLevelAt $ClimbStartFt $ClimbStartKias 0 20 180
        $res.start = $lv
        Add-Check $res 'level_at_start' $lv.ok $(if ($lv.ok) { '{0} s of sim time after the setup' -f $lv.after_s } else { $lv.detail }) `
            '50 ft, 3 kt, 300 fpm for 20 s (in 3 min)'
        # 340 kt in the window (the MCP in IAS since the setup), then FLCH at
        # once: the climb's start (the A/T in SPD meanwhile, a second)
        Set-XPDataref 'laminar/B747/autopilot/ias_dial_value' ([int]$ClimbKias)
        $from = Start-PerfFlch $res $T.top_ft
        $res.ias_tries = Set-PerfMcpIas $ClimbKias
        $crossed = $false
        $top = $null
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($true) {
            Start-Sleep -Seconds 2
            Assert-PerfLogger
            $rows = Get-PerfRows
            $last = $rows[$rows.Count - 1]
            if (-not $crossed -and $last[$ix['mach']] -ge $ClimbMach) {
                $crossed = $true
                $res.crossover = [ordered]@{ row = $rows.Count - 1; press_alt_ft = $last[$ix['press_alt_ft']]; ias_kt = $last[$ix['ias']]; mach = $last[$ix['mach']] }
                Note info ('{0}: M{1} at {2} ft and {3} kt: the MCP to M{4}' -f $T.id, (F $last[$ix['mach']] '0.000'), (F $last[$ix['press_alt_ft']] '0'),
                    (F $last[$ix['ias']] '0'), $ClimbMach)
                $res.crossover.mach_tries = Set-PerfMcpMach $ClimbMach
                continue
            }
            if ($last[$ix['press_alt_ft']] -ge $T.top_ft - $ClimbTopMarginFt) { $top = $rows.Count - 1; break }
            if ($last[$ix['servos_on']] -ne 1) { throw 'the A/P servos went off in the climb' }
            if (($last[$ix['sim_t']] - $rows[$from][$ix['sim_t']]) -gt 2700 -or $sw.Elapsed.TotalSeconds -gt 3300) { break }
        }
        if ($null -eq $top) {
            $res.status = 'timeout'
            Note warn ('{0}: not at {1} ft in 45 min' -f $T.id, $T.top_ft)
        } else {
            # 60 s on: the capture, ALT and SPD
            $sw2 = [Diagnostics.Stopwatch]::StartNew()
            while ((Get-PerfRows).Count -lt $top + 60 -and $sw2.Elapsed.TotalSeconds -lt 120) { Start-Sleep -Seconds 2; Assert-PerfLogger }
        }
        $rows = Get-PerfRows
        $res.climb = Measure-PerfClimb $rows $from $ClimbMarksFt $T.top_ft
        Add-PerfClimbChecks $res
        # (every top is above 340 kt's M.84, about 27,250 ft: at the top a pass
        # needs it; short of the top, information)
        $xPass = if ($null -ne $top) { $crossed } else { $null }
        Add-Check $res 'crossover' $xPass $(if ($crossed) { 'M{0} at {1} ft and {2} kt' -f (F $res.crossover.mach '0.000'),
            (F $res.crossover.press_alt_ft '0'), (F $res.crossover.ias_kt '0') } else { 'not reached' }) ('the MCP to M{0} once the Mach reached it' -f $ClimbMach)
        $mk = $res.climb.marks[$res.climb.marks.Count - 1]
        Note $(if ($res.climb.top_reached) { 'pass' } else { 'warn' }) ('{0}: {1} at {2} ft: {3} s, fuel {4} kg (gauges {5}), {6} NM in the air ({7} over the ground), {8} t' -f $T.id,
            $mk.mark, (F $mk.press_alt_ft '0'), (F $mk.t_s '0'), (F $mk.fuel_used_kg '0'), (F $mk.ff_gauge_used_kg '0'), (F $mk.dist_air_nm '0.0'),
            (F $mk.dist_gnd_nm '0.0'), (F ($mk.gw_kg / 1000) '0.0'))
        Add-PerfWritesChecks $res
    } catch {
        $res.status = 'aborted'
        $res.error = Format-PerfError $_
        Note fail "$($T.id): $($res.error)"
    } finally {
        $res.raw_file = "raw/$($T.id).csv"
        if ($null -ne $script:logger) { $res.columns_missing = $script:logger.missing }
        Stop-PerfLogger
    }
    return $res
}

# A descent (suite climb; PERF_SIMBRIEF.md phase 2, optional; the user
# 2026-11-07): an air start at the top ($T.from_ft) and M.84, level there (30
# s within the limits, in 4 min), then FLCH to 10,000 ft (idle) on
# 84/340/250: the MCP's Mach .84 until the aircraft puts it in IAS (above
# 310 kt), from then its window on M.84's CAS (whole knots, each 2 s) until
# that is 340 kt, then 340 kt (Get-PerfDescentSpeed); the marks
# (Measure-PerfClimb down) from the FLCH push to 30 ft above 10,000 ft; 60 s
# on for the capture (ALT and SPD at the end). Not down in 30 min of sim
# time: timeout, with the marks reached.
function Invoke-PerfDescent($T, $Acf, [double[]]$StationKg) {
    $res = [ordered]@{ id = $T.id; kind = 'descent'; target = $T; status = 'done'; checks = [ordered]@{} }
    try {
        $pt = [ordered]@{ id = $T.id; fl = $T.from_ft / 100; mach = $DescentMach; gw_pct = $T.gw_pct; fuel_kg = $T.fuel_kg }
        Start-PerfFlight $res $pt $Acf $StationKg
        $ix = $script:ix   # the logger's columns once it runs (Invoke-PerfClimb)
        $res.setup = Set-PerfCruise $T.from_ft $DescentMach
        Add-PerfSetupCheck $res $DescentMach
        $lv = Wait-PerfLevelAt $T.from_ft 0 $DescentMach 30 240
        $res.start = $lv
        Add-Check $res 'level_at_start' $lv.ok $(if ($lv.ok) { '{0} s of sim time after the setup' -f $lv.after_s } else { $lv.detail }) `
            '50 ft, M.005, 300 fpm for 30 s (in 4 min)'
        $from = Start-PerfFlch $res $DescentEndFt @(4, 2, 1) 'THR (4), IDLE (2) or HOLD (1)'
        $res.speed = [ordered]@{ ias_from_ft = $null; cas_from_ft = $null; dial_writes = 0 }
        $inIas = $false; $onCas = $false; $dial = 0
        $bottom = $null
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($true) {
            Start-Sleep -Seconds 2
            Assert-PerfLogger
            $rows = Get-PerfRows
            $last = $rows[$rows.Count - 1]
            $alt = $last[$ix['press_alt_ft']]
            if ($alt -le $DescentEndFt + $ClimbTopMarginFt) { $bottom = $rows.Count - 1; break }
            if ($last[$ix['servos_on']] -ne 1) { throw 'the A/P servos went off in the descent' }
            if (($last[$ix['sim_t']] - $rows[$from][$ix['sim_t']]) -gt 1800 -or $sw.Elapsed.TotalSeconds -gt 2400) { break }
            $sp = Get-PerfDescentSpeed $alt
            if (-not $sp.mach_phase) {
                if (-not $onCas) {
                    $onCas = $true
                    $res.speed.cas_from_ft = $alt
                    Note info ('{0}: M{1} is {2} kt at {3} ft: the MCP to {2} kt' -f $T.id, $DescentMach, $DescentKias, (F $alt '0'))
                    $res.speed.cas_tries = Set-PerfMcpIas $DescentKias
                }
                continue
            }
            # in IAS (the aircraft's changeover above 310 kt): the window on M.84's CAS
            if ((Get-Int 'sim/cockpit2/autopilot/airspeed_is_mach') -eq 0) {
                if (-not $inIas) {
                    $inIas = $true
                    $res.speed.ias_from_ft = $alt
                    Note info ('{0}: the MCP in IAS at {1} ft and {2} kt: its window on M{3}''s CAS from here' -f $T.id, (F $alt '0'),
                        (F $last[$ix['ias']] '0'), $DescentMach)
                }
                $kt = [int][math]::Round($sp.cas_kt)
                if ($kt -ne $dial) {
                    Set-XPDataref 'laminar/B747/autopilot/ias_dial_value' $kt
                    $dial = $kt
                    $res.speed.dial_writes = $res.speed.dial_writes + 1
                }
            }
        }
        if ($null -eq $bottom) {
            $res.status = 'timeout'
            Note warn ('{0}: not down at {1} ft in 30 min' -f $T.id, $DescentEndFt)
        } else {
            $sw2 = [Diagnostics.Stopwatch]::StartNew()
            while ((Get-PerfRows).Count -lt $bottom + 60 -and $sw2.Elapsed.TotalSeconds -lt 120) { Start-Sleep -Seconds 2; Assert-PerfLogger }
        }
        $rows = Get-PerfRows
        $res.climb = Measure-PerfClimb $rows $from $DescentMarksFt $DescentEndFt -1
        $c = $res.climb
        Add-Check $res 'climb_real_time' ($c.rows_real_time -eq $c.rows_to_end) ('{0} of {1} rows to the last mark' -f $c.rows_real_time, $c.rows_to_end) 'all (no time acceleration, not paused)'
        $sPass = if ($null -ne $bottom) { $onCas } else { $null }
        Add-Check $res 'speed_schedule' $sPass ('IAS from {0} ft, {1} kt from {2} ft ({3} window writes)' -f $(if ($null -ne $res.speed.ias_from_ft) { F $res.speed.ias_from_ft '0' } else { '-' }),
            $DescentKias, $(if ($null -ne $res.speed.cas_from_ft) { F $res.speed.cas_from_ft '0' } else { '-' }), $res.speed.dial_writes) `
            ('M{0}, then {1} kt once that is its CAS (84/340/250)' -f $DescentMach, $DescentKias)
        # the A/T's modes over the descent (FLCH's idle: THR, then IDLE or HOLD)
        $am = [ordered]@{}
        for ($j = $from; $j -lt $rows.Count; $j++) { $a = [string][int]$rows[$j][$ix['fma_at']]; $am[$a] = 1 + [int]$am[$a] }
        Add-Check $res 'at_modes' $null ((@($am.Keys | ForEach-Object { '{0}: {1} rows' -f $_, $am[$_] })) -join ', ') 'THR 4, IDLE 2, HOLD 1, SPD 3 (after the capture)'
        $mk = $c.marks[$c.marks.Count - 1]
        Note $(if ($c.top_reached) { 'pass' } else { 'warn' }) ('{0}: {1} at {2} ft: {3} s, fuel {4} kg (gauges {5}), {6} NM in the air ({7} over the ground), {8} t' -f $T.id,
            $mk.mark, (F $mk.press_alt_ft '0'), (F $mk.t_s '0'), (F $mk.fuel_used_kg '0'), (F $mk.ff_gauge_used_kg '0'), (F $mk.dist_air_nm '0.0'),
            (F $mk.dist_gnd_nm '0.0'), (F ($mk.gw_kg / 1000) '0.0'))
        Add-PerfWritesChecks $res
    } catch {
        $res.status = 'aborted'
        $res.error = Format-PerfError $_
        Note fail "$($T.id): $($res.error)"
    } finally {
        $res.raw_file = "raw/$($T.id).csv"
        if ($null -ne $script:logger) { $res.columns_missing = $script:logger.missing }
        Stop-PerfLogger
    }
    return $res
}

# A ceiling (suite climb; PERF_SIMBRIEF.md phase 2): an air start at FL310
# and M.85, level there (30 s within the limits, in 4 min), then FLCH to
# 45,000 ft at M.85 (the climb thrust: the reference CLB) until the climb
# rate stays under 100 fpm or the aircraft reaches the FCOM's 1.30 g
# altitude at its weight (Get-PerfCeiling); at most 45,000 ft ("top") and 40
# min of sim time ("timeout"). The marks every 1,000 ft, and at the ceiling
# the time, fuel and distance from FL310 (Measure-PerfClimb).
function Invoke-PerfCeiling($T, $Acf, [double[]]$StationKg) {
    $res = [ordered]@{ id = $T.id; kind = 'ceiling'; target = $T; status = 'done'; checks = [ordered]@{} }
    try {
        $pt = [ordered]@{ id = $T.id; fl = $CeilingStartFt / 100; mach = $CeilingMach; gw_pct = $T.gw_pct; fuel_kg = $T.fuel_kg }
        Start-PerfFlight $res $pt $Acf $StationKg
        $ix = $script:ix   # the logger's columns once it runs (Invoke-PerfClimb)
        $res.setup = Set-PerfCruise $CeilingStartFt $CeilingMach
        Add-PerfSetupCheck $res $CeilingMach
        $lv = Wait-PerfLevelAt $CeilingStartFt 0 $CeilingMach 30 240
        $res.start = $lv
        Add-Check $res 'level_at_start' $lv.ok $(if ($lv.ok) { '{0} s of sim time after the setup' -f $lv.after_s } else { $lv.detail }) `
            '50 ft, M.005, 300 fpm for 30 s (in 4 min)'
        $from = Start-PerfFlch $res $CeilingTopFt
        # the MCP on M.85 again once climbing (the auto-switch's IAS and back:
        # Set-PerfMcpMachClimbing)
        $mcc = Set-PerfMcpMachClimbing $CeilingMach
        $res.mcp_climbing = $mcc
        Add-Check $res 'mcp_mach_climbing' ($mcc.on_target -and $null -ne $mcc.climbing_after_s) ('climbing {0} s after the push; the MCP then {1} {2}; set {3}' -f
            $(if ($null -ne $mcc.climbing_after_s) { F $mcc.climbing_after_s '0.0' } else { '-' }), $(if ($mcc.is_mach -eq 1) { 'Mach' } else { 'IAS' }),
            (F $mcc.target '0.000'), $mcc.set) ('M{0} in the climb (over 300 fpm in 60 s)' -f $CeilingMach)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($true) {
            Start-Sleep -Seconds 2
            Assert-PerfLogger
            $rows = Get-PerfRows
            $last = $rows[$rows.Count - 1]
            if ((Get-PerfCeiling $rows $from $CeilingRateFpm $CeilingWinS $CeilingArmFpm $CeilingHoldS).found) { break }
            if ($last[$ix['press_alt_ft']] -ge $CeilingTopFt - 100) { $res.status = 'top'; break }
            if ($last[$ix['servos_on']] -ne 1) { throw 'the A/P servos went off in the climb' }
            if (($last[$ix['sim_t']] - $rows[$from][$ix['sim_t']]) -gt 2400 -or $sw.Elapsed.TotalSeconds -gt 3000) { $res.status = 'timeout'; break }
        }
        $rows = Get-PerfRows
        $c = Get-PerfCeiling $rows $from $CeilingRateFpm $CeilingWinS $CeilingArmFpm $CeilingHoldS
        $res.ceiling = $c
        $res.climb = Measure-PerfClimb $rows $from $CeilingMarksFt $null
        $res.at_ceiling = $null
        if ($c.found) {
            $at = Measure-PerfClimb $rows $from @($c.ceiling_ft) $null
            if ($at.marks.Count -ge 2) { $res.at_ceiling = $at.marks[1] }
        }
        $ac = $res.at_ceiling
        Add-Check $res 'ceiling' $c.found $(if ($c.found -and $null -ne $ac) { '{0} ft ({1}) after {2} s: {3} t, M{4}, {5} kt (the amber band''s top {6} kt), fuel {7} kg; the FCOM''s 1.30 g altitude {8} ft' -f
            (F $c.ceiling_ft '0'), $c.limit, (F $c.t_s '0'), (F ($ac.gw_kg / 1000) '0.0'), (F $ac.mach '0.000'), (F $ac.ias_kt '0'), (F $ac.vminm_kt '0'),
            (F $ac.fuel_used_kg '0'), (F $c.fcom_ft '0') } else { '{0}: the rate last {1} fpm at {2} ft, at most {3} fpm; the FCOM''s 1.30 g altitude {4} ft' -f
            $res.status, (F $c.last_rate_fpm '0'), (F $c.last_alt_ft '0'), (F $c.max_rate_fpm '0'), (F $c.fcom_ft '0') }) `
            ('the climb rate under {0} fpm (a {1} s line) for {2} s, once over {3} (thrust); or the FCOM''s 1.30 g altitude at the weight, p.267 (buffet)' -f
            $CeilingRateFpm, $CeilingWinS, $CeilingHoldS, $CeilingArmFpm)
        Add-PerfClimbChecks $res
        # the Mach held (the AFDS's FLCH on the MCP's M.85; its speed protection
        # would hold the amber band's top above it)
        $mc = Get-Col @($rows[$from..($rows.Count - 1)]) 'mach'
        $lo = ($mc | Measure-Object -Minimum).Minimum; $hi = ($mc | Measure-Object -Maximum).Maximum
        Add-Check $res 'mach_held' $null ('M{0} to M{1} over the climb' -f (F $lo '0.000'), (F $hi '0.000')) ('M{0} (FLCH)' -f $CeilingMach)
        Add-PerfWritesChecks $res 8 @(4, 5) 'FLCH, THR or THR REF'
    } catch {
        $res.status = 'aborted'
        $res.error = Format-PerfError $_
        Note fail "$($T.id): $($res.error)"
    } finally {
        $res.raw_file = "raw/$($T.id).csv"
        if ($null -ne $script:logger) { $res.columns_missing = $script:logger.missing }
        Stop-PerfLogger
    }
    return $res
}

# ---------------------------------------------------------------- the run

# The run's files (the points' rows to points.csv in PERF_SIMBRIEF.md's
# columns, check.json and check.md, the Log.txt and XTLua error excerpts,
# events.txt): the summary line back (plan, or the points done)
function Write-PerfFiles([string]$RunOut, [string]$RunSuite, $RunResults, $RunMeta, $RunAborted, $RunPoints, $RunLevels,
        [string]$LogFile, [long]$LogFrom, [string]$XtFile, [long]$XtFrom) {
    # the points' rows (points.csv, PERF_SIMBRIEF.md's columns): each check point,
    # or each cruise level's Machs (those not reached: not_run)
    $prow = New-Object System.Collections.ArrayList
    $items = if ($RunSuite -eq 'check') { @($RunResults) } else { @($RunLevels) }
    foreach ($it in $items) {
        if ($RunSuite -eq 'check') {
            $r = $it
            [void]$prow.Add([ordered]@{ id = $r.id; gw_pct = $r.target.gw_pct; fl = $r.target.fl; mach = $r.target.mach; w = $r.window
                status = $r.status; raw = $r.raw_file; after_s = $r.settle.after_s; detail = $null })
            continue
        }
        # a cruise level and its result (none: not run)
        $r = $null
        foreach ($x in $RunResults) { if ($x.id -eq $it.id) { $r = $x } }
        $pct = if ($null -ne $r -and $null -ne $r.request) { $r.request.gw_pct } else { $it.gw_pct }
        foreach ($m in @($it.machs)) {
            $p = $null
            if ($null -ne $r) { foreach ($x in $r.points) { if ([math]::Abs($x.target_mach - $m) -lt 1e-9) { $p = $x } } }
            if ($null -eq $p) {
                [void]$prow.Add([ordered]@{ id = (Get-PerfPointId $it.id $m); gw_pct = $pct; fl = $it.fl; mach = $m; w = $null
                    status = 'not_run'; raw = $null; after_s = $null; detail = $null })
            } else {
                [void]$prow.Add([ordered]@{ id = $p.id; gw_pct = $pct; fl = $it.fl; mach = $m; w = $p.window
                    status = $p.status; raw = $p.raw_file; after_s = $p.settle.after_s; detail = $p.detail })
            }
        }
    }

    # the repeat (suite cruise): the first and the last window of its point
    $repeat = $null
    $repLv = $null
    foreach ($lv in $RunLevels) { if ($lv.repeat_of) { $repLv = $lv } }
    if ($null -ne $repLv) {
        $firstW = $null; $lastW = $null
        $lastId = Get-PerfPointId $repLv.id $repLv.machs[0]
        foreach ($q in $prow) { if ($q.id -eq $repLv.repeat_of) { $firstW = $q.w }; if ($q.id -eq $lastId) { $lastW = $q.w } }
        $repeat = Compare-PerfRepeat $firstW $lastW
        if ($null -ne $repeat) {
            $repeat.first = $repLv.repeat_of
            $repeat.last = $lastId
            Note $(if ($repeat.within_1_pct) { 'pass' } else { 'warn' }) ('repeat {0} and {1}: fuel weight {2} and {3} kg/h ({4} %; over 1 %: to report), gauges {5} %' -f
                $repeat.first, $repeat.last, (F $repeat.first_kgph '0'), (F $repeat.last_kgph '0'), (F $repeat.diff_pct '0.00'), (F $repeat.gauge_diff_pct '0.00'))
        }
    }

    Save-Json (Join-Path $RunOut 'meta.json') $RunMeta
    if ($RunSuite -eq 'check') { Save-Json (Join-Path $RunOut 'check.json') ([ordered]@{ suite = $RunSuite; aborted = $RunAborted; points = @($RunResults) }) }
    else { Save-Json (Join-Path $RunOut 'check.json') ([ordered]@{ suite = $RunSuite; aborted = $RunAborted; levels = @($RunResults); repeat = $repeat }) }

    $pc = New-Object System.Collections.ArrayList
    [void]$pc.Add('point_id,plan,target_gw_pct,target_fl,target_mach,gw_kg,press_alt_ft,mach,tas_kt,oat_c,isa_dev_c,ff_fuelmass_kgph,ff_gauge_kgph,n1_avg_pct,pitch_deg,aoa_deg,status,raw_file')
    foreach ($q in $prow) {
        $w = $q.w
        $pctT = if ($null -ne $q.gw_pct) { F ([double]$q.gw_pct) '0.#' } else { '' }
        if ($null -eq $w -or $null -eq $w.ff_fuelmass_kgph) {
            [void]$pc.Add(('{0},A,{1},{2},{3},,,,,,,,,,,,{4},{5}' -f $q.id, $pctT, $q.fl, (F ([double]$q.mach) '0.00'), $q.status, $q.raw))
            continue
        }
        [void]$pc.Add((@($q.id, 'A', $pctT, $q.fl, (F ([double]$q.mach) '0.00'), (F $w.weight '0'), (F $w.press_alt_ft '0'),
            (F $w.mach '0.0000'), (F $w.tas_kt '0.0'), (F $w.oat_c '0.00'), (F $w.isa_dev_c '0.00'), (F $w.ff_fuelmass_kgph '0.0'),
            (F $w.ff_gauge_kgph '0.0'), (F $w.n1_avg_pct '0.00'), (F $w.pitch '0.00'), (F $w.aoa '0.00'), $q.status, $q.raw)) -join ',')
    }
    [IO.File]::WriteAllLines((Join-Path $RunOut 'points.csv'), [string[]]$pc, $utf8)

    $md = New-Object System.Collections.ArrayList
    [void]$md.Add("# Perf $RunSuite $(Split-Path -Leaf $RunOut)")
    [void]$md.Add('')
    [void]$md.Add(('X-Plane {0}; {1} {2} ({3} tracked files changed); acf SHA-256 {4}' -f $RunMeta.xplane.version, $RunMeta.git.branch, $RunMeta.git.commit,
        $RunMeta.git.tracked_changes, $RunMeta.acf.sha256))
    if ($RunMeta.only) { [void]$md.Add(''); [void]$md.Add(('Only (-Only): {0}' -f (@($RunMeta.only) -join ', '))) }
    if ($RunAborted) { [void]$md.Add(''); [void]$md.Add("**Stopped:** $RunAborted") }
    $count = [ordered]@{}
    foreach ($q in $prow) { $count[$q.status] = 1 + [int]$count[$q.status] }
    if ($RunSuite -eq 'cruise') {
        foreach ($r in $RunResults) {
            if ($null -eq $r.ci) { continue }
            [void]$md.Add('')
            [void]$md.Add(('CI {0}: the economy cruise Mach {1} on the VNAV CRZ page ("{2}") at {3} % and FL{4}{5}; the Machs {6}' -f $r.ci.ci,
                $(if ($null -ne $r.ci.mach) { F $r.ci.mach '0.000' } else { 'not read' }), $r.ci.title, (F ([double]$r.request.gw_pct) '0.#'), $r.target.fl,
                $(if ($r.ci.note) { ' (' + $r.ci.note + ')' } else { '' }), ((@($r.target.machs) | ForEach-Object { F $_ '0.00' }) -join ', ')))
        }
        [void]$md.Add('')
        if ($null -ne $repeat) {
            [void]$md.Add(('Repeat ({0}, {1}): fuel weight {2} and {3} kg/h, {4} %; gauges {5} and {6} kg/h, {7} % (over 1 %: to report): {8}' -f
                $repeat.first, $repeat.last, (F $repeat.first_kgph '0'), (F $repeat.last_kgph '0'), (F $repeat.diff_pct '0.00'),
                (F $repeat.gauge_first_kgph '0'), (F $repeat.gauge_last_kgph '0'), (F $repeat.gauge_diff_pct '0.00'),
                $(if ($repeat.within_1_pct) { 'within' } else { 'OVER' })))
        } else { [void]$md.Add('Repeat: not measured') }
        [void]$md.Add('')
        [void]$md.Add(('Points: {0} of {1} done{2}' -f [int]$count['done'], $prow.Count,
            $(if ($count.Count -gt 1) { '; ' + ((@($count.Keys | Where-Object { $_ -ne 'done' }) | ForEach-Object { "$_ $($count[$_])" }) -join ', ') } else { '' })))
    }
    $planA = ($RunSuite -eq 'check') -and ($RunResults.Count -eq $RunPoints.Count)
    foreach ($r in $RunResults) {
        [void]$md.Add('')
        [void]$md.Add("## $($r.id) ($($r.status))")
        if ($r.error) { [void]$md.Add(''); [void]$md.Add("Error: $($r.error)") }
        [void]$md.Add('')
        [void]$md.Add('| check | pass | value | limit |')
        [void]$md.Add('|---|---|---|---|')
        foreach ($k in $r.checks.Keys) {
            $c = $r.checks[$k]
            $p = if ($null -eq $c.pass) { '-' } elseif ($c.pass) { 'yes' } else { 'NO' }
            [void]$md.Add("| $k | $p | $($c.value) | $($c.limit) |")
            if ($k -ne 'fuel_flow_agreement' -and $c.pass -eq $false) { $planA = $false }
        }
        if ($r.status -ne 'done') { $planA = $false }
        if ($RunSuite -ne 'cruise') { continue }
        [void]$md.Add('')
        [void]$md.Add('| point | status | gross t | press alt ft | Mach | TAS kt | ISA dev C | FF fuel weight kg/h | FF gauges kg/h | diff % | N1 % | pitch | AoA | level after s |')
        [void]$md.Add('|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
        foreach ($q in $prow) {
            if (-not $q.id.StartsWith($r.id + '_')) { continue }
            $w = $q.w
            if ($null -eq $w -or $null -eq $w.ff_fuelmass_kgph) {
                [void]$md.Add("| $($q.id) | $($q.status) | | | | | | | | | | | | $($q.after_s) |")
                continue
            }
            [void]$md.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} | {13} |' -f $q.id, $q.status,
                (F ($w.weight / 1000) '0.0'), (F $w.press_alt_ft '0'), (F $w.mach '0.0000'), (F $w.tas_kt '0.0'), (F $w.isa_dev_c '0.00'),
                (F $w.ff_fuelmass_kgph '0'), (F $w.ff_gauge_kgph '0'), (F $w.ff_diff_pct '0.00'), (F $w.n1_avg_pct '0.00'), (F $w.pitch '0.00'),
                (F $w.aoa '0.00'), $q.after_s))
        }
        foreach ($q in $prow) {
            if ($q.id.StartsWith($r.id + '_') -and $q.detail) { [void]$md.Add(''); [void]$md.Add("- $($q.id): $($q.detail)") }
        }
    }
    if ($RunSuite -eq 'check') {
        [void]$md.Add('')
        [void]$md.Add(('Air start checks (all but the fuel flow agreement): {0}' -f $(if ($planA) { 'all passed -> plan A' } else { 'not all passed -> plan B' })))
    }
    [IO.File]::WriteAllLines((Join-Path $RunOut 'check.md'), [string[]]$md, $utf8)
    Write-PerfLogFiles $RunOut $LogFile $LogFrom $XtFile $XtFrom
    if ($RunSuite -eq 'check') { return ('plan: {0}' -f $(if ($planA) { 'A' } else { 'B' })) }
    return ('points: {0} of {1} done' -f [int]$count['done'], $prow.Count)
}

# the run's Log.txt lines that look like errors, the XTLua errors if any, the notes
function Write-PerfLogFiles([string]$RunOut, [string]$LogFile, [long]$LogFrom, [string]$XtFile, [long]$XtFrom) {
    $ex = @(Get-FileTail $LogFile $LogFrom | Where-Object { $_ -match '(?i)error|exception|fail|assert|crash' })
    [IO.File]::WriteAllLines((Join-Path $RunOut 'log_excerpt.txt'), [string[]]$ex, $utf8)
    $xt = @(Get-FileTail $XtFile $XtFrom)
    if ($xt.Count -gt 0) { [IO.File]::WriteAllLines((Join-Path $RunOut 'xtlua_errors.txt'), [string[]]$xt, $utf8) }
    [IO.File]::WriteAllLines((Join-Path $RunOut 'events.txt'), [string[]]$events, $utf8)
}

# a CSV field: a number in the invariant culture, blank for none or NaN
function Format-PerfCsv($V, [string]$Fmt) {
    if ($null -eq $V) { return '' }
    $d = [double]$V
    if ([double]::IsNaN($d) -or [double]::IsInfinity($d)) { return '' }
    return $d.ToString($Fmt, $inv)
}

# The climb suite's files (phase 2): climb.csv a row a mark (each climb's
# start, every 5,000 ft and its top; each ceiling's start and every 1,000
# ft), ceiling.csv a row a ceiling, check.json, check.md (the climbs' and the
# ceilings' tables, then each test's checks and marks), the logs. The
# summary line back.
function Write-PerfClimbFiles([string]$RunOut, $RunResults, $RunMeta, $RunAborted, $RunTests,
        [string]$LogFile, [long]$LogFrom, [string]$XtFile, [long]$XtFrom) {
    Save-Json (Join-Path $RunOut 'meta.json') $RunMeta
    Save-Json (Join-Path $RunOut 'check.json') ([ordered]@{ suite = 'climb'; aborted = $RunAborted; tests = @($RunResults) })
    $byId = @{}
    foreach ($r in $RunResults) { $byId[$r.id] = $r }
    $pctOf = {
        param($T, $R)
        if ($null -ne $R -and $null -ne $R.request) { return F ([double]$R.request.gw_pct) '0.#' }
        if ($null -ne $T.gw_pct) { return F ([double]$T.gw_pct) '0.#' }
        return ''
    }

    $cl = New-Object System.Collections.ArrayList
    [void]$cl.Add('test_id,kind,plan,target_gw_pct,gw_start_kg,mark,press_alt_ft,t_s,fuel_used_kg,ff_gauge_used_kg,dist_air_nm,dist_gnd_nm,gw_kg,ias_kt,mach,seg_vs_fpm,n1_avg_pct,thrlim,status,raw_file')
    $cc = New-Object System.Collections.ArrayList
    [void]$cc.Add('test_id,plan,target_gw_pct,gw_start_kg,ceiling_ft,t_s,fuel_used_kg,dist_air_nm,gw_kg,mach,ias_kt,vminm_kt,max_rate_fpm,limit,fcom_130g_ft,status,raw_file')
    $count = [ordered]@{}
    foreach ($t in $RunTests) {
        $r = $byId[$t.id]
        $status = if ($null -ne $r) { $r.status } else { 'not_run' }
        $count[$status] = 1 + [int]$count[$status]
        $pct = & $pctOf $t $r
        $gw0 = if ($null -ne $r -and $null -ne $r.request) { Format-PerfCsv $r.request.gw_kg '0' } else { '' }
        $raw = if ($null -ne $r) { $r.raw_file } else { '' }
        $marks = @()
        if ($null -ne $r -and $null -ne $r.climb) { $marks = @($r.climb.marks) }
        if ($marks.Count -eq 0) {
            [void]$cl.Add(('{0},{1},A,{2},{3},,,,,,,,,,,,,,{4},{5}' -f $t.id, $t.kind, $pct, $gw0, $status, $raw))
        }
        foreach ($mk in $marks) {
            [void]$cl.Add((@($t.id, $t.kind, 'A', $pct, $gw0, $mk.mark, (Format-PerfCsv $mk.press_alt_ft '0'), (Format-PerfCsv $mk.t_s '0.0'),
                (Format-PerfCsv $mk.fuel_used_kg '0.0'), (Format-PerfCsv $mk.ff_gauge_used_kg '0.0'), (Format-PerfCsv $mk.dist_air_nm '0.00'),
                (Format-PerfCsv $mk.dist_gnd_nm '0.00'), (Format-PerfCsv $mk.gw_kg '0'), (Format-PerfCsv $mk.ias_kt '0.0'), (Format-PerfCsv $mk.mach '0.0000'),
                (Format-PerfCsv $mk.seg_vs_fpm '0'), (Format-PerfCsv $mk.n1_avg_pct '0.00'), (Format-PerfCsv $mk.thrlim '0'), $status, $raw)) -join ',')
        }
        if ($t.kind -eq 'ceiling') {
            $c = if ($null -ne $r) { $r.ceiling } else { $null }
            $ac = if ($null -ne $r) { $r.at_ceiling } else { $null }
            if ($null -ne $c -and $c.found -and $null -ne $ac) {
                [void]$cc.Add((@($t.id, 'A', $pct, $gw0, (Format-PerfCsv $c.ceiling_ft '0'), (Format-PerfCsv $ac.t_s '0.0'), (Format-PerfCsv $ac.fuel_used_kg '0.0'),
                    (Format-PerfCsv $ac.dist_air_nm '0.00'), (Format-PerfCsv $ac.gw_kg '0'), (Format-PerfCsv $ac.mach '0.0000'), (Format-PerfCsv $ac.ias_kt '0.0'),
                    (Format-PerfCsv $ac.vminm_kt '0.0'), (Format-PerfCsv $c.max_rate_fpm '0'), $c.limit, (Format-PerfCsv $c.fcom_ft '0'), $status, $raw)) -join ',')
            } else {
                $mx = if ($null -ne $c) { Format-PerfCsv $c.max_rate_fpm '0' } else { '' }
                $fc = if ($null -ne $c) { Format-PerfCsv $c.fcom_ft '0' } else { '' }
                [void]$cc.Add(('{0},A,{1},{2},,,,,,,,,{3},,{4},{5},{6}' -f $t.id, $pct, $gw0, $mx, $fc, $status, $raw))
            }
        }
    }
    [IO.File]::WriteAllLines((Join-Path $RunOut 'climb.csv'), [string[]]$cl, $utf8)
    [IO.File]::WriteAllLines((Join-Path $RunOut 'ceiling.csv'), [string[]]$cc, $utf8)

    $md = New-Object System.Collections.ArrayList
    [void]$md.Add("# Perf climb $(Split-Path -Leaf $RunOut)")
    [void]$md.Add('')
    [void]$md.Add(('X-Plane {0}; {1} {2} ({3} tracked files changed); acf SHA-256 {4}' -f $RunMeta.xplane.version, $RunMeta.git.branch, $RunMeta.git.commit,
        $RunMeta.git.tracked_changes, $RunMeta.acf.sha256))
    if ($RunMeta.only) { [void]$md.Add(''); [void]$md.Add(('Only (-Only): {0}' -f (@($RunMeta.only) -join ', '))) }
    if ($RunAborted) { [void]$md.Add(''); [void]$md.Add("**Stopped:** $RunAborted") }
    [void]$md.Add('')
    [void]$md.Add(('Climbs: from {0} ft and {1} kt, FLCH at {2} kt, then M{3} (the schedule {1}/{2}/{4}); the top''s mark {5} ft below it. Descents: from the top at M{6}, FLCH (idle) to {7} ft, {8} kt once that is M{6}''s CAS (the schedule {9}/{8}/250); the bottom''s mark {5} ft above it. Ceilings: from {10} ft at M{11}, FLCH until the climb rate (a {12} s line) stays under {13} fpm (thrust) or the aircraft reaches the FCOM''s 1.30 g altitude at its weight (buffet; FCOM p.267, PI.11.1), whichever first.' -f
        $ClimbStartFt, $ClimbStartKias, $ClimbKias, $ClimbMach, [int][math]::Round($ClimbMach * 100), $ClimbTopMarginFt, $DescentMach, $DescentEndFt,
        $DescentKias, [int][math]::Round($DescentMach * 100), $CeilingStartFt, $CeilingMach, $CeilingWinS, $CeilingRateFpm))
    [void]$md.Add('')
    [void]$md.Add(('| climb | status | start t | top ft | time s | fuel kg | gauges kg | air NM | ground NM | M{0} at ft |' -f $ClimbMach))
    [void]$md.Add('|---|---|---|---|---|---|---|---|---|---|')
    foreach ($t in @($RunTests | Where-Object { $_.kind -eq 'climb' })) {
        $r = $byId[$t.id]
        if ($null -eq $r -or $null -eq $r.climb -or $r.climb.marks.Count -eq 0) {
            [void]$md.Add(('| {0} | {1} | | {2} | | | | | | |' -f $t.id, $(if ($null -ne $r) { $r.status } else { 'not_run' }), $t.top_ft))
            continue
        }
        $m0 = $r.climb.marks[0]; $mk = $r.climb.marks[$r.climb.marks.Count - 1]
        $x = if ($null -ne $r.crossover) { F $r.crossover.press_alt_ft '0' } else { '' }
        [void]$md.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} |' -f $t.id, $r.status, (F ($m0.gw_kg / 1000) '0.0'),
            $(if ($r.climb.top_reached) { $t.top_ft } else { 'not reached (' + $mk.mark + ')' }), (F $mk.t_s '0'), (F $mk.fuel_used_kg '0'),
            (F $mk.ff_gauge_used_kg '0'), (F $mk.dist_air_nm '0.0'), (F $mk.dist_gnd_nm '0.0'), $x))
    }
    [void]$md.Add('')
    [void]$md.Add(('| descent | status | start t | from ft | time s | fuel kg | gauges kg | air NM | ground NM | IAS from ft | {0} kt from ft |' -f $DescentKias))
    [void]$md.Add('|---|---|---|---|---|---|---|---|---|---|---|')
    foreach ($t in @($RunTests | Where-Object { $_.kind -eq 'descent' })) {
        $r = $byId[$t.id]
        if ($null -eq $r -or $null -eq $r.climb -or $r.climb.marks.Count -eq 0) {
            [void]$md.Add(('| {0} | {1} | | {2} | | | | | | | |' -f $t.id, $(if ($null -ne $r) { $r.status } else { 'not_run' }), $t.from_ft))
            continue
        }
        $m0 = $r.climb.marks[0]; $mk = $r.climb.marks[$r.climb.marks.Count - 1]
        $sIas = if ($null -ne $r.speed -and $null -ne $r.speed.ias_from_ft) { F $r.speed.ias_from_ft '0' } else { '' }
        $sCas = if ($null -ne $r.speed -and $null -ne $r.speed.cas_from_ft) { F $r.speed.cas_from_ft '0' } else { '' }
        [void]$md.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} |' -f $t.id, $r.status, (F ($m0.gw_kg / 1000) '0.0'),
            $(if ($r.climb.top_reached) { $t.from_ft } else { 'not down (' + $mk.mark + ')' }), (F $mk.t_s '0'), (F $mk.fuel_used_kg '0'),
            (F $mk.ff_gauge_used_kg '0'), (F $mk.dist_air_nm '0.0'), (F $mk.dist_gnd_nm '0.0'), $sIas, $sCas))
    }
    [void]$md.Add('')
    [void]$md.Add('| ceiling | status | start t | ceiling ft | limit | time s | fuel kg | t there | Mach | IAS kt | amber band kt | max rate fpm | FCOM 1.30 g ft |')
    [void]$md.Add('|---|---|---|---|---|---|---|---|---|---|---|---|---|')
    foreach ($t in @($RunTests | Where-Object { $_.kind -eq 'ceiling' })) {
        $r = $byId[$t.id]
        $c = if ($null -ne $r) { $r.ceiling } else { $null }
        $ac = if ($null -ne $r) { $r.at_ceiling } else { $null }
        $g0 = if ($null -ne $r -and $null -ne $r.request) { F ($r.request.gw_kg / 1000) '0.0' } else { '' }
        if ($null -eq $c -or -not $c.found -or $null -eq $ac) {
            [void]$md.Add((('| {0} | {1} | {2} |' + (' |' * 8) + ' {3} | {4} |') -f $t.id, $(if ($null -ne $r) { $r.status } else { 'not_run' }), $g0,
                $(if ($null -ne $c) { F $c.max_rate_fpm '0' } else { '' }), $(if ($null -ne $c) { F $c.fcom_ft '0' } else { '' })))
            continue
        }
        [void]$md.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} |' -f $t.id, $r.status, $g0, (F $c.ceiling_ft '0'),
            $c.limit, (F $ac.t_s '0'), (F $ac.fuel_used_kg '0'), (F ($ac.gw_kg / 1000) '0.0'), (F $ac.mach '0.000'), (F $ac.ias_kt '0'), (F $ac.vminm_kt '0'),
            (F $c.max_rate_fpm '0'), (F $c.fcom_ft '0')))
    }
    [void]$md.Add('')
    [void]$md.Add(('Tests: {0} of {1} done{2}' -f [int]$count['done'], @($RunTests).Count,
        $(if ($count.Count -gt 1 -or -not $count.Contains('done')) { '; ' + ((@($count.Keys | Where-Object { $_ -ne 'done' }) | ForEach-Object { "$_ $($count[$_])" }) -join ', ') } else { '' })))
    foreach ($r in $RunResults) {
        [void]$md.Add('')
        [void]$md.Add("## $($r.id) ($($r.status))")
        if ($r.error) { [void]$md.Add(''); [void]$md.Add("Error: $($r.error)") }
        [void]$md.Add('')
        [void]$md.Add('| check | pass | value | limit |')
        [void]$md.Add('|---|---|---|---|')
        foreach ($k in $r.checks.Keys) {
            $c = $r.checks[$k]
            $p = if ($null -eq $c.pass) { '-' } elseif ($c.pass) { 'yes' } else { 'NO' }
            [void]$md.Add("| $k | $p | $($c.value) | $($c.limit) |")
        }
        if ($null -eq $r.climb -or $r.climb.marks.Count -eq 0) { continue }
        [void]$md.Add('')
        [void]$md.Add('| mark | press alt ft | time s | fuel kg | gauges kg | air NM | ground NM | gross t | IAS kt | Mach | V/S fpm | N1 % | thrust limit |')
        [void]$md.Add('|---|---|---|---|---|---|---|---|---|---|---|---|---|')
        foreach ($mk in $r.climb.marks) {
            [void]$md.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} |' -f $mk.mark, (F $mk.press_alt_ft '0'), (F $mk.t_s '0'),
                (F $mk.fuel_used_kg '0'), (F $mk.ff_gauge_used_kg '0'), (F $mk.dist_air_nm '0.0'), (F $mk.dist_gnd_nm '0.0'), (F ($mk.gw_kg / 1000) '0.0'),
                (F $mk.ias_kt '0'), (F $mk.mach '0.000'), $(if ([double]::IsNaN([double]$mk.seg_vs_fpm)) { '' } else { F $mk.seg_vs_fpm '0' }),
                (F $mk.n1_avg_pct '0.0'), (F $mk.thrlim '0')))
        }
    }
    [IO.File]::WriteAllLines((Join-Path $RunOut 'check.md'), [string[]]$md, $utf8)
    Write-PerfLogFiles $RunOut $LogFile $LogFrom $XtFile $XtFrom
    return ('tests: {0} of {1} done' -f [int]$count['done'], @($RunTests).Count)
}
# dot-sourced (tests/flight/perf/perf_offline_test.ps1): the functions only
if ($MyInvocation.InvocationName -eq '.') { return }

$onlyIds = $null
if ($Only) {
    if ($Suite -eq 'check') { $points = Select-PerfOnly $points $Only; $onlyIds = @($points | ForEach-Object { $_.id }) }
    elseif ($Suite -eq 'cruise') { $levels = Select-PerfOnly $levels $Only; $onlyIds = @($levels | ForEach-Object { $_.id }) }
    else { $tests = Select-PerfOnly $tests $Only; $onlyIds = @($tests | ForEach-Object { $_.id }) }
}

if (-not $RunsDir) { $RunsDir = Join-Path $PSScriptRoot 'runs' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$out = Join-Path $RunsDir ("${stamp}_$Suite" + $(if ($null -ne $onlyIds) { '_part' } else { '' }))
if (Test-Path $out) { throw "the run's folder exists: $out" }
New-Item -ItemType Directory -Force -Path (Join-Path $out 'raw') | Out-Null

$results = New-Object System.Collections.ArrayList
$payloadAtStart = $null
$meta = [ordered]@{ suite = $Suite; plan = 'A'; started = (Get-Date).ToString('o'); out = $out; only = $onlyIds; points = $points; levels = $levels
    measure_s = $MeasureS; cruise_ci = $CruiseCi; light_fuel_kg = $LightFuelKg; tests = $tests }
if ($Suite -eq 'climb') {
    $meta.climb = [ordered]@{ schedule = ('{0}/{1}/{2}' -f $ClimbStartKias, $ClimbKias, [int][math]::Round($ClimbMach * 100)); start_ft = $ClimbStartFt
        start_kias = $ClimbStartKias; kias = $ClimbKias; mach = $ClimbMach; marks_ft = $ClimbMarksFt; top_margin_ft = $ClimbTopMarginFt }
    $meta.descent = [ordered]@{ schedule = ('{0}/{1}/250' -f [int][math]::Round($DescentMach * 100), $DescentKias); mach = $DescentMach
        kias = $DescentKias; end_ft = $DescentEndFt; marks_ft = $DescentMarksFt; bottom_margin_ft = $ClimbTopMarginFt }
    $meta.ceiling = [ordered]@{ start_ft = $CeilingStartFt; mach = $CeilingMach; rate_fpm = $CeilingRateFpm; arm_fpm = $CeilingArmFpm
        window_s = $CeilingWinS; hold_s = $CeilingHoldS; mcp_top_ft = $CeilingTopFt; marks_ft = $CeilingMarksFt
        criteria = 'FCOM p.267 (PI.11.1): the lower of the 1.30 g altitude and the climb rate under rate_fpm (the user, 2026-11-08; before, 300 fpm)'
        fcom_130g = [ordered]@{ source = 'FCOM p.267 (PI.11.1), ISA+10 and colder, max climb thrust, 1.30 g (39 degrees of bank)'; weight_t = $FcomBuffet130T; alt_ft = $FcomBuffet130Ft } }
}
$xpLog = Join-Path $script:XPRoot 'Log.txt'
$xtErr = Join-Path $script:XPRoot 'Output\B747_xtlua_errors.txt'
$aborted = $null
$logFrom = Get-FileLength $xpLog
$xtFrom = Get-FileLength $xtErr
try {
    if ($StartXPlane -and -not (Get-Process -Name 'X-Plane' -ErrorAction SilentlyContinue)) {
        Note info 'starting X-Plane (tools\xp_restart.ps1)'
        $up = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '..\tools\xp_restart.ps1'))
        if ($up.Count -eq 0 -or $up[$up.Count - 1] -ne 'up') { throw "X-Plane did not come up: $($up -join ' ')" }
        Note info 'X-Plane up, the custom acf loaded on RJAA 34L'
        # X-Plane's start wrote Log.txt anew
        $logFrom = 0
    }
    $caps = Get-XPCapabilities
    $meta.xplane = [ordered]@{ version = $caps.'x-plane'.version; api = @($caps.api.versions)
        log_first_line = (Get-FirstLine $xpLog) }
    # the payload as the run finds it, put back at the end: the last point's
    # 40 t stays in X-Plane through a later flight's reload (the fix
    # session's s108 ran at 310 t after the 2026-11-06 cruise run, its own
    # 270 t before). The fuel is left: the aircraft's fuel model owns the tanks
    try { $payloadAtStart = Get-Num 'sim/flightmodel/weight/m_fixed' } catch { $payloadAtStart = $null }
    $meta.payload_at_start_kg = $payloadAtStart
    $meta.git = Get-GitInfo
    $meta.acf = [ordered]@{ file = '747-400_custom.acf'; sha256 = (Get-FileHash -Algorithm SHA256 $acfFile).Hash.ToLower()
        last_commit = $meta.git.acf_last_commit }
    $c8 = [string]$meta.git.commit
    if ($c8.Length -gt 8) { $c8 = $c8.Substring(0, 8) }
    Note info ('X-Plane {0}; {1} {2}{3}; acf {4}' -f $meta.xplane.version, $meta.git.branch, $c8,
        $(if ($meta.git.tracked_changes) { " (+$($meta.git.tracked_changes) changed)" } else { '' }), $meta.acf.sha256.Substring(0, 12))

    # the acf's own lines (the weights' sources), the payload stations, the
    # fuel per thrust (the windows' factor over it)
    $keys = Read-AcfKeys $acfFile
    $meta.acf_lines = $keys
    $script:acfSfc = Get-PerfAcfSfc $keys
    $meta.acf_sfc_kgns = $script:acfSfc
    $stationKg = New-Object double[] 9
    foreach ($i in 0..8) { if ($keys.Contains("_fixed_max/$i")) { $stationKg[$i] = [double]::Parse($keys["_fixed_max/$i"].value, $inv) * $LB } }

    # the aircraft must be loaded for its datarefs; otherwise the first point's start loads it
    $acf = $null
    try {
        if (([string](Get-XPDataref 'sim/aircraft/view/acf_relative_path')) -like '*747-400_custom.acf') { $acf = Get-PerfAircraft }
    } catch { }
    if ($null -eq $acf) {
        Note info 'the custom acf is not loaded: an air start without weights loads it first'
        $p0 = if ($points.Count -gt 0) { $points[0] }
            elseif ($levels.Count -gt 0) { [ordered]@{ id = 'probe'; fl = $levels[0].fl; mach = $levels[0].machs[0] } }
            else { [ordered]@{ id = 'probe'; fl = $CeilingStartFt / 100; mach = $CeilingMach } }
        $probe = New-PerfInit $p0 (New-Object double[] 9) (New-Object double[] 9)
        $probe.Remove('weight')
        [void](Start-PerfAirStart $probe)
        $acf = Get-PerfAircraft
    }
    $meta.aircraft = $acf
    $meta.weights = [ordered]@{
        oew_kg = $acf.m_empty_kg; mtow_kg = $MtowKg; mzfw_kg = $MzfwKg; mlw_kg = $MlwKg
        mtow_mzfw_mlw_source = $MtowSource; acf_max_kg = $acf.m_max_kg
        fuel_capacity_kg = $acf.m_fuel_tot_kg
        tank_capacity_kg = @(0..8 | ForEach-Object { $acf.tank_rat[$_] * $acf.m_fuel_tot_kg })
        station_max_kg = @($stationKg); payload_kg = $PayloadKg
        acf_file_empty_kg = [double]::Parse($keys['_m_empty'].value, $inv) * $LB
        sources = 'datarefs sim/aircraft/weight/acf_m_empty, acf_m_max, acf_m_fuel_tot, sim/aircraft/overflow/acf_tank_rat; the stations from the acf lines (_fixed_max, lb)'
    }
    Save-Json (Join-Path $out 'meta.json') $meta

    $todo = if ($Suite -eq 'check') { $points } elseif ($Suite -eq 'cruise') { $levels } else { $tests }
    foreach ($item in $todo) {
        if ($Suite -eq 'check') { [void]$results.Add((Invoke-PerfCheckPoint $item $acf $stationKg)) }
        elseif ($Suite -eq 'cruise') { [void]$results.Add((Invoke-PerfLevel $item $acf $stationKg)) }
        elseif ($item.kind -eq 'climb') { [void]$results.Add((Invoke-PerfClimb $item $acf $stationKg)) }
        elseif ($item.kind -eq 'descent') { [void]$results.Add((Invoke-PerfDescent $item $acf $stationKg)) }
        else { [void]$results.Add((Invoke-PerfCeiling $item $acf $stationKg)) }
        $e = @(Get-FileTail $xtErr $xtFrom)
        if ($e.Count -gt 0) { Note fail ('XTLua errors: ' + $e[0]); break }
    }
} catch {
    $aborted = $_.Exception.Message
    Note fail "run stopped: $aborted"
    Stop-PerfLogger
} finally {
    try { Invoke-XPCommand 'sim/operation/pause_on' } catch { }
    if ($null -ne $payloadAtStart) {
        try {
            Set-XPDataref 'sim/flightmodel/weight/m_fixed' $payloadAtStart
            $meta.payload_at_end_kg = Get-Num 'sim/flightmodel/weight/m_fixed'
            Note info ('the payload back to {0} kg, as the run found it (now {1} kg)' -f (F $payloadAtStart '0.0'), (F $meta.payload_at_end_kg '0.0'))
        } catch { Note warn ('the payload not put back to {0} kg: {1}' -f (F $payloadAtStart '0.0'), $_.Exception.Message) }
    }
    if ($null -ne $script:perfOptsWas -and $script:perfOptsWas.Count -gt 0) {
        foreach ($k in @($script:perfOptsWas.Keys)) {
            try { Set-XPDataref ('laminar/B747/options/' + $k) $script:perfOptsWas[$k] } catch { Note warn ('the option {0} not put back: {1}' -f $k, $_.Exception.Message) }
        }
        Note info ('the sim options back as the run found them: {0}' -f ((@($script:perfOptsWas.Keys) | ForEach-Object { '{0} {1}' -f $_, $script:perfOptsWas[$_] }) -join ', '))
    }
}

# ---------------------------------------------------------------- the files

$meta.finished = (Get-Date).ToString('o')
$meta.wall_s = [math]::Round($wall.Elapsed.TotalSeconds, 0)
$meta.aborted = $aborted
if ($Suite -eq 'climb') { $summary = Write-PerfClimbFiles $out @($results) $meta $aborted $tests $xpLog $logFrom $xtErr $xtFrom }
else { $summary = Write-PerfFiles $out $Suite @($results) $meta $aborted $points $levels $xpLog $logFrom $xtErr $xtFrom }
Write-Host "done: $out"
Write-Host $summary
