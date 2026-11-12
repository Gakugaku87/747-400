param([switch]$Mem, [int]$TimeoutSec = 300)
# For tests/flight/tools/run_all.sh (docs/overhaul/TESTING.md 4.6):
#   -Mem   prints three whole numbers of GB: X-Plane's private memory (-1
#          when it is not running), the system's commit left, and the commit
#          a scenario needs to start (xp.ps1: XP_MIN_COMMIT_FREE_GB, 8; with
#          XP_FLIGHT_GB the growth of an X-Plane still under it as well)
#   (none) starts X-Plane again: its processes stopped (a crash report's too),
#          X-Plane.exe started, the Web API waited for, then a flight on RJAA
#          34L with the engines running loads the 747 once (the first load
#          after a start differs: a throwaway); prints "up" or "down"
# The aircraft is the folder this kit is in, whatever its name (2026-11-12;
# before, Aircraft/747-400-master by name). The throwaway load is made with
# the test's X-Plane settings (the user's hardware off, "start with the
# engines running" on), put back at its end (xp.ps1).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\xp.ps1')
$root = $script:XPRoot   # X-Plane's folder

if ($Mem) {
    $m = Get-XPMemory
    '{0} {1} {2}' -f [int][math]::Floor([double]$m.private_gb), [int][math]::Floor([double]$m.commit_free_gb),
        [int][math]::Ceiling((Get-XPMemoryNeed $m))
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
if (-not $up) { Add-XPStatus 'restart: X-Plane down (the Web API did not answer)'; 'down'; return }
# X-Plane loads its last flight behind the main menu at its start; a load
# sent right as the Web API answers sometimes left the menus up (below):
# some time for that first (estimate)
Start-Sleep -Seconds 30
$init = @{
    aircraft = @{ path = (Get-XPAircraftRel 'custom') }
    runway_start = @{ airport_id = 'RJAA'; runway = '34L' }
    engine_status = @{ all_engines = @{ running = $true } }
} | ConvertTo-Json -Depth 5
# (2026-11-02/03: twice of four the flight loaded but X-Plane stayed on its
# Flight Configuration screen and main menu, paused at time 0: neither
# pause_off, close_windows, toggle_main_menu nor a second load moved it, only
# a click on Resume. "down" then: run_all.sh starts X-Plane again)
$state = 'down'
$notes = @()
try {
    # (2026-11-12) "start with the engines running" before the aircraft's
    # scripts start: at the user's 0 it comes up as on a cold airplane. An
    # X-Plane just started has no datarefs until a flight loads, so they
    # are written while this one loads (xp.ps1's Start-XPFlightLate)
    $notes = @(Enter-XPTestSettings)
    if (@($notes | Where-Object { $_ -match ': not set \(' }).Count -gt 0) {
        [void](Start-XPFlightLate $init 300)
        $notes = @($script:XPLateNotes)
        if ($notes.Count -eq 0) { $notes = @('!the settings were not reached while the flight loaded: the aircraft came up at the user''s') }
    } else {
        [void](Start-XPFlight $init 300)
    }
    $notes += @(Confirm-XPTestSettings)
    Start-Sleep -Seconds 20
    $state = 'up'
} catch {
    $notes += "the throwaway flight: $($_.Exception.Message)"
} finally {
    $notes += @(Exit-XPTestSettings)
}
Add-XPStatus ("restart: X-Plane {0}, {1}; {2}" -f $state, (Format-XPMemory (Get-XPMemory)),
    (@($notes | Where-Object { $_ } | ForEach-Object { $_ -replace '^!', 'WARNING: ' }) -join '; '))
$state
