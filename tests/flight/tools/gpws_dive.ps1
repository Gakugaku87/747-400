# A hand-flown dive for GPWS mode 1 (SINK RATE, PULL UP) on the flight that
# is loaded (docs/overhaul/TESTING.md). The AFDS's V/S does not go much
# beyond 2,300 fpm down (s43_gpws, 2026-10-25), short of the mode 1 lines
# above 800 ft, so this takes the A/P and A/T off, closes the thrust levers
# and pushes the yoke (written every 0.2 s, as landing.sh does for the flare)
# until the airplane sinks fast, then pulls up at RA 1,000 ft or 3 s after
# PULL UP, and gives the airplane back to the A/P (V/S up to 2,500 ft).
# It logs the radio altitude, the vertical speed and the GPWS outputs, and
# prints where SINK RATE and PULL UP began with the model's lines there.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\tools\gpws_dive.ps1
#
# Start it level above RA 2,000 ft over flat ground (s43_gpws ends at 2,000 ft
# MSL near RJAA, about 1,870 ft RA).
param([double]$Push = -0.35, [double]$PullAtRa = 1000, [string]$Log, [string]$Shot)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\xp.ps1')

$ra0 = Get-XPDataref 'laminar/B747/ra/gpwc'
if ($ra0 -lt 1800) { throw "start above RA 1,800 ft (now $ra0)" }
if ($Shot) {
    # the captain's PFD (as the scenarios' view)
    Set-XPDataref 'sim/graphics/view/field_of_view_deg' 24
    Set-XPDataref 'sim/graphics/view/pilots_head_the' -24
    Set-XPDataref 'sim/graphics/view/pilots_head_psi' -1
}
$lines = New-Object System.Collections.Generic.List[string]
function Say([string]$s) { $lines.Add($s); Write-Host $s }

# the model's lines (B747.34.gpws_model.lua): alert 998-5,007 fpm, warning
# 1,710-7,125 fpm (estimate), 30-2,450 ft
function Line([double]$ra, [double]$lo, [double]$hi) {
    $r = [math]::Min([math]::Max($ra, 30), 2450)
    return $lo + ($hi - $lo) * ($r - 30) / 2420
}

Invoke-XPCommand 'laminar/B747/autopilot/button_switch/yoke_disengage_capt' 0.2
Invoke-XPCommand 'laminar/B747/authrottle_disarm'
Start-Sleep -Milliseconds 1500
# the second push of the disconnect switch ends AUTOPILOT DISC (FCOM p.655),
# the master reset puts the master lights out: master WARNING is then the GPWS's
Invoke-XPCommand 'laminar/B747/autopilot/button_switch/yoke_disengage_capt' 0.2
Start-Sleep -Milliseconds 500
Invoke-XPCommand 'laminar/B747/button_switch/warn_caut_capt' 0.2
Start-Sleep -Milliseconds 500
Set-XPDataref 'sim/cockpit2/engine/actuators/throttle_ratio_all' 0
Say ("start: RA {0:N0} ft, master WARNING {1}" -f $ra0, (Get-XPDataref 'laminar/B747/warning/master_warning'))

$t0 = Get-Date
$state = 'push'; $sinkAt = $null; $pullAt = $null; $warnAt = $null; $pullSeen = $null
while ($true) {
    $t = ((Get-Date) - $t0).TotalSeconds
    $ra = Get-XPDataref 'laminar/B747/ra/gpwc'
    $vs = Get-XPDataref 'sim/flightmodel/position/vh_ind_fpm'
    $voice = Get-XPDataref 'laminar/B747/gpws/voice'
    $pu = Get-XPDataref 'laminar/B747/gpws/pull_up'
    $mw = Get-XPDataref 'laminar/B747/warning/master_warning'
    $gp = Get-XPDataref 'laminar/B747/gpws/gnd_prox_light'
    Say ("{0,5:N1} s  RA {1,6:N0}  VS {2,6:N0}  voice {3}  pull_up {4}  master_warning {5}  gnd_prox {6}  {7}" -f $t, $ra, $vs, $voice, $pu, $mw, $gp, $state)
    if (-not $sinkAt -and $voice -eq 1) { $sinkAt = @($ra, $vs) }
    if (-not $pullAt -and $pu -eq 1) {
        $pullAt = @($ra, $vs); $pullSeen = $t
        # -Shot: the captain's PFD with PULL UP (the view is set at the start)
        if ($Shot) { [void](Save-XPScreenshot $Shot) }
    }
    if (-not $warnAt -and $mw -eq 1) { $warnAt = $t }
    switch ($state) {
        'push' {
            Set-XPDataref 'sim/cockpit2/controls/yoke_pitch_ratio' $Push
            if ($ra -lt $PullAtRa -or ($pullSeen -and $t - $pullSeen -gt 3)) { $state = 'pull' }
        }
        'pull' {
            Set-XPDataref 'sim/cockpit2/controls/yoke_pitch_ratio' 0.6
            Set-XPDataref 'sim/cockpit2/engine/actuators/throttle_ratio_all' 0.9
            if ($vs -gt 500) { $state = 'level' }
        }
        'level' {
            Set-XPDataref 'sim/cockpit2/controls/yoke_pitch_ratio' 0
            break
        }
    }
    if ($state -eq 'level' -or $t -gt 90) { break }
    Start-Sleep -Milliseconds 200
}
Set-XPDataref 'sim/cockpit2/controls/yoke_pitch_ratio' 0
# back to the A/P: V/S up to 2,500 ft, A/T SPD
Set-XPDataref 'laminar/B747/autopilot/heading/altitude_dial_ft' 2500
Invoke-XPCommand 'laminar/B747/authrottle_arm'
Invoke-XPCommand 'laminar/B747/autopilot/button_switch/cmd_L'
Start-Sleep -Milliseconds 500
Invoke-XPCommand 'laminar/B747/autopilot/button_switch/vs_mode'
Start-Sleep -Milliseconds 500
Set-XPDataref 'sim/cockpit2/autopilot/vvi_dial_fpm' 1500
Set-XPDataref 'laminar/B747/cockpit2/autopilot/vvi_dial_fpm' 1500

if ($sinkAt) {
    Say ("SINK RATE from RA {0:N0} ft at {1:N0} fpm (the alert line there: {2:N0} fpm)" -f $sinkAt[0], -$sinkAt[1], (Line $sinkAt[0] 998 5007))
} else { Say 'no SINK RATE' }
if ($pullAt) {
    Say ("PULL UP from RA {0:N0} ft at {1:N0} fpm (the warning line there: {2:N0} fpm)" -f $pullAt[0], -$pullAt[1], (Line $pullAt[0] 1710 7125))
} else { Say 'no PULL UP' }
if ($warnAt) { Say ("master WARNING lit at {0:N1} s" -f $warnAt) } else { Say 'no master WARNING' }
if ($Log) { $lines | Out-File -Encoding utf8 $Log }
