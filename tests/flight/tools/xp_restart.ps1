param([switch]$Mem, [int]$TimeoutSec = 300)
# For tests/flight/tools/run_all.sh (docs/overhaul/TESTING.md §4.6):
#   -Mem   prints X-Plane's private memory in GB (an integer), -1 when it is
#          not running
#   (none) starts X-Plane again: its processes stopped (a crash report's too),
#          X-Plane.exe started, the Web API waited for, then a flight on RJAA
#          34L with the engines running loads the 747 once (the first load
#          after a start differs: a throwaway); prints "up" or "down"
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path   # X-Plane's folder

if ($Mem) {
    $p = Get-Process -Name X-Plane -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) { [int]($p.PrivateMemorySize64 / 1GB) } else { -1 }
    return
}

Get-Process -Name X-Plane -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$deadline = (Get-Date).AddSeconds(90)
while ((Get-Process -Name X-Plane -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
Start-Process -FilePath (Join-Path $root 'X-Plane.exe') -WorkingDirectory $root
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$up = $false
while (-not $up -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    try { Invoke-RestMethod -Uri 'http://localhost:8086/api/capabilities' -TimeoutSec 3 | Out-Null; $up = $true } catch { }
}
if (-not $up) { 'down'; return }
. (Join-Path $PSScriptRoot '..\xp.ps1')
$init = @{
    aircraft = @{ path = 'Aircraft/747-400-master/747-400_custom.acf' }
    runway_start = @{ airport_id = 'RJAA'; runway = '34L' }
    engine_status = @{ all_engines = @{ running = $true } }
} | ConvertTo-Json -Depth 5
# (2026-11-02: once the flight loaded but X-Plane stayed on its Flight
# Configuration screen, paused at time 0, and pause_off did not help: a new
# flight's load is sent again)
foreach ($try in 1..2) {
    try {
        [void](Start-XPFlight $init 420)
        Start-Sleep -Seconds 20
        'up'
        return
    } catch { }
}
'down'
