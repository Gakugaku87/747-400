# Phase 4 of PERF_SIMBRIEF.md (docs/overhaul/TESTING.md 4.7): records a flight
# flown on a SimBrief plan made with the custom airframe, for
# flight_report.ps1. Start it with the aircraft at the gate (X-Plane running;
# it waits up to 10 min for the Web API). It only reads X-Plane: the kit's
# 1 s logger (perf.ps1's columns) to raw\flight_<part>.csv, a new part when
# the WebSocket drops. It ends by itself once the aircraft has flown and then
# stood on the ground below 1 kt for 2 min, at -MaxHours, or when the run's
# folder holds a file named STOP; then it writes report.md
# (flight_report.ps1). No time acceleration in the flight: the aircraft's
# fuel system burns by real time (XTLua's SIM_PERIOD).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\perf\flight_log.ps1 -SimbriefUser <name> [-MaxHours 20]
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\perf\flight_log.ps1 -OfpFile <ofp.json>
#
# Output: tests\flight\perf\runs\<yyyyMMdd_HHmmss>_flight\ (local only, as the
# runs: the OFP holds the user's SimBrief account): ofp.json, meta.json,
# raw\flight_<part>.csv, events.txt, report.md, compare.json.
param(
    [string]$SimbriefUser,
    [string]$OfpFile,
    [double]$MaxHours = 20,
    [string]$FlightOut
)
$ErrorActionPreference = 'Stop'
$flArgs = @{ SimbriefUser = $SimbriefUser; OfpFile = $OfpFile; MaxHours = $MaxHours; FlightOut = $FlightOut }
. (Join-Path $PSScriptRoot 'flight_report.ps1')

# the end: airborne for 60 rows running at least once, then on the ground
# below 1 kt (0.5 m/s) for the last 120 rows. $Airborne carries over a
# logger's restart.
function Test-FlightEnded($Rows, $Ix, [ref]$Airborne) {
    $n = $Rows.Count
    $iG = $Ix['on_ground']; $iS = $Ix['gs_ms']
    if (-not $Airborne.Value) {
        $run = 0
        for ($k = 0; $k -lt $n; $k++) { if ($Rows[$k][$iG] -eq 0) { $run++; if ($run -ge 60) { $Airborne.Value = $true; break } } else { $run = 0 } }
        if (-not $Airborne.Value) { return $false }
    }
    if ($n -lt 120) { return $false }
    for ($k = $n - 120; $k -lt $n; $k++) { if ($Rows[$k][$iG] -eq 0 -or -not ($Rows[$k][$iS] -lt 0.5)) { return $false } }
    return $true
}

# dot-sourced (tests/flight/perf/flight_offline_test.ps1): the functions only
if ($MyInvocation.InvocationName -eq '.') { return }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$fout = if ($flArgs.FlightOut) { $flArgs.FlightOut } else { Join-Path $PSScriptRoot "runs\${stamp}_flight" }
if (Test-Path $fout) { throw "the run's folder exists: $fout" }
New-Item -ItemType Directory -Force -Path (Join-Path $fout 'raw') | Out-Null
$ofpPath = Join-Path $fout 'ofp.json'
if ($flArgs.OfpFile) { Copy-Item $flArgs.OfpFile $ofpPath }
elseif ($flArgs.SimbriefUser) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $uri = 'https://www.simbrief.com/api/xml.fetcher.php?username={0}&json=1' -f [Uri]::EscapeDataString($flArgs.SimbriefUser)
    Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $ofpPath -TimeoutSec 60
} else { throw 'give -SimbriefUser <name> or -OfpFile <ofp.json>' }
$ofp = Read-PerfOfp $ofpPath
Note info ('OFP {0}: {1} ({2}), fuel factor {3}, CI {4}, trip {5:0} kg, {6} takeoff to landing' -f $ofp.route, $ofp.airframe, $(if ($ofp.custom -eq '1') { 'custom' } else { 'standard' }),
    (Format-PerfFactor ((Get-OfpFactor $ofp.fuelfact) - 1)), $ofp.ci, $ofp.trip, (Format-FlightHm $ofp.time_s))
if ($ofp.custom -ne '1') { Note warn 'the OFP is not on a custom airframe' }

$caps = $null
$wait = [Diagnostics.Stopwatch]::StartNew()
while ($null -eq $caps) {
    try { $caps = Get-XPCapabilities } catch {
        if ($wait.Elapsed.TotalMinutes -ge 10) { throw 'no X-Plane Web API in 10 min' }
        Start-Sleep -Seconds 10
    }
}
$meta = [ordered]@{ kind = 'flight'; started = (Get-Date).ToString('o'); out = $fout
    ofp = [ordered]@{ route = $ofp.route; airframe = $ofp.airframe; custom = $ofp.custom; fuelfact = $ofp.fuelfact; ci = $ofp.ci; generated = $ofp.generated
        trip_kg = $ofp.trip; time_s = $ofp.time_s; zfw_kg = $ofp.zfw; tow_kg = $ofp.tow; takeoff_fuel_kg = $ofp.takeoff_fuel }
    xplane = [ordered]@{ version = $caps.'x-plane'.version }; git = (Get-GitInfo)
    acf = [ordered]@{ file = '747-400_custom.acf'; sha256 = (Get-FileHash -Algorithm SHA256 $acfFile).Hash.ToLower() } }
Save-Json (Join-Path $fout 'meta.json') $meta
Note info ('X-Plane {0}; {1} {2}; logging to {3}' -f $meta.xplane.version, $meta.git.branch, ([string]$meta.git.commit).Substring(0, [math]::Min(8, ([string]$meta.git.commit).Length)), $fout)

$part = 0; $airborne = $false; $endReason = $null
$stopFile = Join-Path $fout 'STOP'
while ($null -eq $endReason) {
    $part++
    $csv = Join-Path $fout ('raw\flight_{0:00}.csv' -f $part)
    try { Start-PerfLogger $csv } catch {
        Note warn "logger (part $part): $($_.Exception.Message)"
        Stop-PerfLogger
        if ($part -ge 50) { $endReason = 'the logger failed 50 times'; break }
        Start-Sleep -Seconds 30
        continue
    }
    $quietNoted = $false
    while ($true) {
        Start-Sleep -Seconds 5
        $s = $script:logger.sync
        if ($s.error) { Note warn "logger: $($s.error); a new part"; break }
        $quiet = ([DateTime]::UtcNow - $s.lastUtc).TotalSeconds
        if ($quiet -gt 60 -and -not $quietNoted) { Note warn ('no update for {0:0} s (X-Plane paused, loading or gone?)' -f $quiet); $quietNoted = $true }
        if ($quiet -le 60) { $quietNoted = $false }
        if (Test-Path $stopFile) { $endReason = 'the STOP file'; break }
        if ($wall.Elapsed.TotalHours -ge $flArgs.MaxHours) { $endReason = 'MaxHours'; break }
        $was = $airborne
        if (Test-FlightEnded (Get-PerfRows) $script:ix ([ref]$airborne)) { $endReason = 'landed and stood still for 2 min'; break }
        if ($airborne -and -not $was) { Note info 'airborne' }
    }
    Stop-PerfLogger
    if ($null -eq $endReason) {
        if ($part -ge 50) { $endReason = 'the logger restarted 50 times' } else { Start-Sleep -Seconds 10 }
    }
}
Note info "end: $endReason"
$meta.finished = (Get-Date).ToString('o'); $meta.end_reason = $endReason; $meta.parts = $part
Save-Json (Join-Path $fout 'meta.json') $meta
try {
    $c = Invoke-FlightReport $fout
    if ($c.ok) { Note info ('trip fuel {0:+0.00;-0.00} % ({1:0} of {2:0} kg planned); report.md' -f (100 * $c.trip_err), $c.burn, $ofp.trip) }
    else { Note warn ('not compared: ' + ($c.notes -join '; ')) }
} catch { Note fail "report: $($_.Exception.Message)" }
[IO.File]::WriteAllLines((Join-Path $fout 'events.txt'), [string[]]$events, $utf8)
"flight: $fout"
