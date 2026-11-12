# X-Plane Web API (v3) client for the 747-400 flight-test kit.
# docs/overhaul/TESTING.md describes the kit.
#
# Library use (from another PowerShell script):
#   . "$PSScriptRoot\xp.ps1"
#   Get-XPDataref 'laminar/B747/engines/type'
#   Set-XPDataref 'sim/cockpit2/controls/flap_ratio' 0.5
#   Invoke-XPCommand 'laminar/B747/button_switch/elec_battery'
#
# Command line:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\xp.ps1 <verb> [args]
#   verbs: caps | get <name[index]> | set <name[index]> <value> | cmd <name> [seconds]
#          flight <init.json> | shot [file.png] | find <text>
#          acf [custom|stock]   the acf's path from X-Plane's folder
#          mem                  X-Plane's memory and the system's commit charge
#          restore              the user's X-Plane settings back after a run that died
param([string]$Verb, [string]$Arg1, [string]$Arg2)

$ErrorActionPreference = 'Stop'
$script:XPBase = if ($env:XP_WEBAPI) { $env:XP_WEBAPI } else { 'http://localhost:8086/api/v3' }

# The aircraft folder is the one this kit is in (tests\flight two levels
# down), whatever its name (2026-11-12: a release's copy in
# Aircraft/747-400-test-pr34 on a PC without the working tree needed the
# acf's path by hand). X-Plane's folder is the first one above it that holds
# X-Plane.exe or Resources\plugins (XPLANE_ROOT overrides, as for the
# regression tests), else the fourth above tests\flight as before.
function Find-XPRoot([string]$AircraftDir) {
    if ($env:XPLANE_ROOT -and (Test-Path -LiteralPath $env:XPLANE_ROOT)) { return (Resolve-Path -LiteralPath $env:XPLANE_ROOT).Path.TrimEnd('\') }
    $d = Split-Path -Parent $AircraftDir
    while ($d) {
        if ((Test-Path -LiteralPath (Join-Path $d 'X-Plane.exe')) -or (Test-Path -LiteralPath (Join-Path $d 'Resources\plugins'))) { return $d.TrimEnd('\') }
        $d = Split-Path -Parent $d
    }
    return (Split-Path -Parent (Split-Path -Parent $AircraftDir)).TrimEnd('\')
}
# The acf for X-Plane's flight API, a path from X-Plane's folder with "/":
# "custom" is the aircraft folder's 747-400_custom.acf, or its 747-400.acf
# where there is no such file (a release: its 747-400.acf is the custom
# acf); "stock" its 747-400.acf; anything else is taken as that path.
function Get-XPAircraftRel([string]$Acf = 'custom', [string]$AircraftDir = $script:XPAircraftDir, [string]$Root = $script:XPRoot) {
    if ($Acf -ne 'custom' -and $Acf -ne 'stock') { return $Acf }
    $dir = $AircraftDir.TrimEnd('\')
    $rootDir = $Root.TrimEnd('\')
    if (-not $dir.StartsWith($rootDir + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "the aircraft folder $dir is not under X-Plane's folder $rootDir`: give -Acf a path from X-Plane's folder"
    }
    $file = '747-400.acf'
    if ($Acf -eq 'custom' -and (Test-Path -LiteralPath (Join-Path $dir '747-400_custom.acf'))) { $file = '747-400_custom.acf' }
    if (-not (Test-Path -LiteralPath (Join-Path $dir $file))) { throw "no $file in $dir" }
    return ($dir.Substring($rootDir.Length + 1) -replace '\\', '/') + '/' + $file
}
$script:XPAircraftDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path.TrimEnd('\')
$script:XPRoot = Find-XPRoot $script:XPAircraftDir
$script:XPDrefs = @{}
$script:XPCmds = @{}

function Invoke-XPApi([string]$Method, [string]$Path, $Body = $null, [int]$TimeoutSec = 30) {
    $uri = $script:XPBase + $Path
    if ($null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { ConvertTo-Json $Body -Depth 30 -Compress }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Method $Method -Uri $uri -ContentType 'application/json' -Body $bytes -TimeoutSec $TimeoutSec
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -TimeoutSec $TimeoutSec
}

function Get-XPCapabilities {
    $root = $script:XPBase -replace '/api/v\d+$', ''
    Invoke-RestMethod -Uri "$root/api/capabilities" -TimeoutSec 10
}

# "name[3]" -> @('name', 3); "name" -> @('name', -1)
function Split-XPName([string]$Name) {
    if ($Name -match '^(.*)\[(\d+)\]$') { return @($Matches[1], [int]$Matches[2]) }
    return @($Name, -1)
}

function Get-XPDatarefInfo([string]$Name) {
    if ($script:XPDrefs.ContainsKey($Name)) { return $script:XPDrefs[$Name] }
    $q = [uri]::EscapeDataString($Name)
    $r = Invoke-XPApi GET "/datarefs?filter[name]=$q&fields=id,name,value_type"
    if (-not $r.data -or $r.data.Count -eq 0) { throw "dataref not found: $Name (is a flight loaded?)" }
    $info = $r.data[0]
    $script:XPDrefs[$Name] = $info
    return $info
}

function ConvertFrom-XPData($Value) {
    # 'data' datarefs come back base64; the 747's string datarefs are NUL-padded
    $bytes = [Convert]::FromBase64String([string]$Value)
    return ([System.Text.Encoding]::UTF8.GetString($bytes)).TrimEnd([char]0)
}

function Get-XPDataref([string]$Name, [int]$Index = -1) {
    $n = Split-XPName $Name
    if ($n[1] -ge 0) { $Name = $n[0]; $Index = $n[1] }
    $info = Get-XPDatarefInfo $Name
    $path = "/datarefs/$($info.id)/value"
    if ($Index -ge 0) { $path += "?index=$Index" }
    $v = (Invoke-XPApi GET $path).data
    if ($info.value_type -eq 'data') { return ConvertFrom-XPData $v }
    return $v
}

function Set-XPDataref([string]$Name, $Value, [int]$Index = -1) {
    $n = Split-XPName $Name
    if ($n[1] -ge 0) { $Name = $n[0]; $Index = $n[1] }
    $info = Get-XPDatarefInfo $Name
    $path = "/datarefs/$($info.id)/value"
    if ($Index -ge 0) { $path += "?index=$Index" }
    if ($info.value_type -eq 'data') {
        $Value = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string]$Value))
    } elseif ($info.value_type -match '^(int|int_array)$') {
        $Value = [int]$Value
    } elseif ($Value -is [string]) {
        $Value = [double]$Value
    }
    [void](Invoke-XPApi PATCH $path @{ data = $Value })
}

function Get-XPCommandId([string]$Name) {
    if ($script:XPCmds.ContainsKey($Name)) { return $script:XPCmds[$Name] }
    $q = [uri]::EscapeDataString($Name)
    $r = Invoke-XPApi GET "/commands?filter[name]=$q&fields=id,name"
    if (-not $r.data -or $r.data.Count -eq 0) { throw "command not found: $Name" }
    $script:XPCmds[$Name] = $r.data[0].id
    return $r.data[0].id
}

# Duration 0 presses and releases at once; a duration holds the command (max 10 s).
function Invoke-XPCommand([string]$Name, [double]$Duration = 0) {
    $id = Get-XPCommandId $Name
    [void](Invoke-XPApi POST "/command/$id/activate" @{ duration = $Duration })
}

# Start a flight from an init object or a JSON file path. Loading the 747 takes
# minutes, so wait long; then wait for the sim clock to run.
function Start-XPFlight($Init, [int]$TimeoutSec = 600) {
    if ($Init -is [string] -and (Test-Path $Init)) { $Init = Get-Content -Raw -Encoding UTF8 $Init }
    $script:XPDrefs = @{}
    $script:XPCmds = @{}
    try { [void](Invoke-XPApi POST '/flight' $Init $TimeoutSec) } catch {
        # the request can time out while X-Plane is still loading; the wait below decides
        Write-Warning "POST /flight: $($_.Exception.Message)"
    }
    Wait-XPSimRunning -TimeoutSec $TimeoutSec
}

function Wait-XPSimRunning([int]$TimeoutSec = 600) {
    # running = the sim clock moves. Its value alone says nothing: it does not
    # restart with a new flight, and it stops when X-Plane hangs while the Web
    # API still answers.
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $unpaused = $false
    $last = $null
    while ((Get-Date) -lt $deadline) {
        try {
            $t = Get-XPDataref 'sim/time/total_running_time_sec'
            if (-not $unpaused -and (Get-XPDataref 'sim/time/paused') -eq 1) {
                Invoke-XPCommand 'sim/operation/pause_off'
                $unpaused = $true
            }
            if ($null -ne $last -and $t -gt $last + 1) { return $t }
            $last = $t
        } catch { $script:XPDrefs = @{}; $last = $null }
        Start-Sleep -Seconds 3
    }
    throw "the sim did not start running within $TimeoutSec s"
}

# The number of aircraft loads in Log.txt so far ("Loading airplane number 0").
function Get-XPAircraftLoads {
    $log = Join-Path $script:XPRoot 'Log.txt'
    if (-not (Test-Path $log)) { return 0 }
    return @(Select-String -Path $log -SimpleMatch 'Loading airplane number 0 with').Count
}

# Wait until the script block returns true; returns the elapsed seconds.
function Wait-XP([scriptblock]$Condition, [double]$TimeoutSec = 60, [int]$IntervalMs = 250) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
        try { if (& $Condition) { return $sw.Elapsed.TotalSeconds } } catch { }
        Start-Sleep -Milliseconds $IntervalMs
    }
    return $null
}

# Take an X-Plane screenshot and copy it to $Dest. X-Plane writes it to
# Output/screenshots on a later frame, so wait for the new file.
function Save-XPScreenshot([string]$Dest, [int]$TimeoutSec = 30) {
    $dir = Join-Path $script:XPRoot 'Output\screenshots'
    $before = @{}
    if (Test-Path $dir) { Get-ChildItem $dir -Filter *.png | ForEach-Object { $before[$_.Name] = $true } }
    Invoke-XPCommand 'sim/operation/screenshot'
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        if (-not (Test-Path $dir)) { continue }
        $new = Get-ChildItem $dir -Filter *.png | Where-Object { -not $before.ContainsKey($_.Name) } |
            Sort-Object LastWriteTime | Select-Object -Last 1
        if ($new) {
            # wait until X-Plane has finished writing it
            $size = -1
            while ($new.Length -ne $size) { $size = $new.Length; Start-Sleep -Milliseconds 500; $new.Refresh() }
            if ($Dest) {
                $destDir = Split-Path -Parent $Dest
                if ($destDir) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
                Copy-Item $new.FullName $Dest -Force
                return $Dest
            }
            return $new.FullName
        }
    }
    throw 'no screenshot appeared'
}

function Find-XPDataref([string]$Text) {
    $r = Invoke-XPApi GET '/datarefs?fields=name' $null 60
    $r.data | Where-Object { $_.name -like "*$Text*" } | ForEach-Object { $_.name }
}

# --- the user's X-Plane settings a test changes, and puts back ------------
# (2026-11-12, docs/overhaul/TESTING.md 4.6)
#   sim/joystick/has_joystick 0: with the user's hardware connected the
#     levers follow its levers and its yoke axis overwrites the pitch a
#     scenario writes every frame (s109's first run on the user's PC).
#     X-Plane 12.4.4 does not take the write (the dataref is read-only: the
#     Web API answers 403): then the result says so, as a warning, and the
#     hardware is to be unplugged for the run;
#   sim/operation/prefs/startup_running 1: at 0 (the user's last flight began
#     cold and dark) a loaded or reloaded aircraft comes up with its electrics
#     as on a cold airplane even when the flight starts with the engines
#     running (2026-11-11: s01, s101, s142 and s00 failed on it).
# Enter-XPTestSettings writes the test's values and keeps the user's in a
# file; Exit-XPTestSettings writes the user's back and removes the file. A
# run that died leaves the file: the next Enter takes the user's values from
# it (what X-Plane holds then is the test's), and "xp.ps1 restore" puts them
# back by hand. Both return lines for the result; a line that begins with
# "!" is a warning. A value is written only where X-Plane's differs.
$script:XPTestSettings = @(
    @{ dref = 'sim/joystick/has_joystick'; value = 0
        refused = "the user's hardware is connected and its levers and yoke axis may overwrite what the scenario writes: unplug it for the run" },
    @{ dref = 'sim/operation/prefs/startup_running'; value = 1
        refused = 'a loaded or reloaded aircraft comes up as on a cold airplane' }
)
# (the file is X-Plane's, not a run folder's: one X-Plane, whichever copy of
# the kit runs on it)
function Get-XPSettingsFile { Join-Path $script:XPRoot 'Output\B747_flighttest\kit_settings.txt' }
# name -> the user's value, or 'refused' (X-Plane did not take the test's:
# nothing to put back)
function Read-XPSettingsFile([string]$File) {
    $saved = [ordered]@{}
    if (Test-Path -LiteralPath $File) {
        foreach ($line in [IO.File]::ReadAllLines($File)) {
            if ($line -match '^(\S+) (-?\d+)$') { $saved[$Matches[1]] = [int]$Matches[2] }
            elseif ($line -match '^(\S+) refused$') { $saved[$Matches[1]] = 'refused' }
        }
    }
    return $saved
}
function Write-XPSettingsFile([string]$File, $Saved) {
    if ($Saved.Count -eq 0) {
        if (Test-Path -LiteralPath $File) { Remove-Item -LiteralPath $File -Force }
        return
    }
    $dir = Split-Path -Parent $File
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::WriteAllLines($File, [string[]]@($Saved.Keys | ForEach-Object { "$_ $($Saved[$_])" }))
}
# $Only: these datarefs alone (Confirm-XPTestSettings: those not reached before)
function Enter-XPTestSettings([string]$File = (Get-XPSettingsFile), [string[]]$Only = @()) {
    $notes = @()
    $saved = Read-XPSettingsFile $File
    foreach ($s in $script:XPTestSettings) {
        if ($Only.Count -gt 0 -and $Only -notcontains $s.dref) { continue }
        $now = $null
        try { $now = [int](Get-XPDataref $s.dref) } catch {
            $notes += "$($s.dref): not set ($($_.Exception.Message))"
            continue
        }
        $left = $saved.Contains($s.dref) -and $saved[$s.dref] -ne 'refused'
        $user = if ($left) { $saved[$s.dref] } else { $now }
        if ($now -ne $s.value) {
            try { Set-XPDataref $s.dref $s.value } catch {
                $saved[$s.dref] = 'refused'
                $notes += "!$($s.dref) is $now and X-Plane does not take $($s.value) ($($_.Exception.Message)): $($s.refused)"
                continue
            }
        }
        $saved[$s.dref] = $user
        $notes += "$($s.dref): the user's $user, $($s.value) for the test" + $(if ($left) { ' (the user''s value from a run that did not put it back)' } else { '' })
    }
    Write-XPSettingsFile $File $saved
    return $notes
}
# after a flight's start or the aircraft's reload: the test's values again
# where X-Plane changed them, the settings not reached before a first flight
# loaded (the Web API has no datarefs until then) taken now
function Confirm-XPTestSettings([string]$File = (Get-XPSettingsFile)) {
    $saved = Read-XPSettingsFile $File
    $notes = @()
    $missing = @()
    foreach ($s in $script:XPTestSettings) {
        if (-not $saved.Contains($s.dref)) { $missing += $s.dref; continue }
        if ($saved[$s.dref] -eq 'refused') { continue }
        try {
            $now = [int](Get-XPDataref $s.dref)
            if ($now -ne $s.value) {
                Set-XPDataref $s.dref $s.value
                $notes += "$($s.dref): $now after the flight's start, $($s.value) again"
            }
        } catch { }
    }
    if ($missing.Count -gt 0) { $notes += @(Enter-XPTestSettings $File $missing) }
    return $notes
}
# A flight's start on an X-Plane that has no flight yet (just started): the
# Web API has no datarefs until one loads (404), so Enter-XPTestSettings
# could not reach them, and an aircraft loaded at the user's "start with the
# engines running" 0 comes up as on a cold airplane. The load is begun (the
# request left after 5 s: X-Plane goes on loading) and the test's settings
# are written as soon as the datarefs are there, while it loads - before
# the aircraft's scripts read them at the flight's start (2026-11-12: a
# write 50 s into the load was in time). Returns the sim's time; the
# settings' notes in $script:XPLateNotes (none: not reached)
function Start-XPFlightLate($Init, [int]$TimeoutSec = 600, [string]$File = (Get-XPSettingsFile)) {
    if ($Init -is [string] -and (Test-Path $Init)) { $Init = Get-Content -Raw -Encoding UTF8 $Init }
    $script:XPDrefs = @{}
    $script:XPCmds = @{}
    $script:XPLateNotes = @()
    try { [void](Invoke-XPApi POST '/flight' $Init 5) } catch { }
    $deadline = (Get-Date).AddSeconds([math]::Min($TimeoutSec, 300))
    while ((Get-Date) -lt $deadline) {
        $script:XPDrefs = @{}
        $notes = @(Confirm-XPTestSettings $File)
        if (@($notes | Where-Object { $_ -match ': not set \(' }).Count -eq 0) { $script:XPLateNotes = $notes; break }
        Start-Sleep -Milliseconds 500
    }
    Wait-XPSimRunning -TimeoutSec $TimeoutSec
}
function Exit-XPTestSettings([string]$File = (Get-XPSettingsFile)) {
    $notes = @()
    $saved = Read-XPSettingsFile $File
    $kept = [ordered]@{}
    foreach ($name in @($saved.Keys)) {
        if ($saved[$name] -eq 'refused') { continue }
        try {
            if ([int](Get-XPDataref $name) -ne $saved[$name]) { Set-XPDataref $name $saved[$name] }
            $notes += "$name`: the user's $($saved[$name]) again"
        } catch {
            $kept[$name] = $saved[$name]
            $notes += "!$name`: NOT put back to the user's $($saved[$name]) ($($_.Exception.Message)); 'xp.ps1 restore' once X-Plane answers"
        }
    }
    Write-XPSettingsFile $File $kept
    return $notes
}

# --- memory (2026-11-12, TESTING.md 4.6) ----------------------------------
# On a PC with much scenery X-Plane with a flight takes 23-28 GB; a flight's
# load that reaches the system's commit limit ends X-Plane (twice on the
# user's PC, 2026-11-12). X-Plane's private memory and the system's commit
# charge, in GB (private -1 without X-Plane)
function Get-XPMemory {
    $p = Get-Process -Name X-Plane -ErrorAction SilentlyContinue | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem
    $limit = [double]$os.TotalVirtualMemorySize / 1MB       # KB to GB
    $free = [double]$os.FreeVirtualMemory / 1MB
    return [ordered]@{
        private_gb = $(if ($p) { [math]::Round($p.PrivateMemorySize64 / 1GB, 1) } else { -1 })
        commit_used_gb = [math]::Round($limit - $free, 1)
        commit_limit_gb = [math]::Round($limit, 1)
        commit_free_gb = [math]::Round($free, 1)
    }
}
# The least commit left for a scenario to start: XP_MIN_COMMIT_FREE_GB (8;
# 0 for no check). With XP_FLIGHT_GB (what X-Plane with a flight takes on
# this PC, e.g. 28 with much scenery; 0, not known) an X-Plane still under
# it needs that growth as well.
function Get-XPMemoryNeed($Mem, [double]$MinFreeGb = -1, [double]$FlightGb = -1) {
    if ($MinFreeGb -lt 0) { $MinFreeGb = if ($env:XP_MIN_COMMIT_FREE_GB) { [double]$env:XP_MIN_COMMIT_FREE_GB } else { 8 } }
    if ($FlightGb -lt 0) { $FlightGb = if ($env:XP_FLIGHT_GB) { [double]$env:XP_FLIGHT_GB } else { 0 } }
    if ($MinFreeGb -le 0) { return 0.0 }
    $grow = 0.0
    if ($FlightGb -gt 0) { $grow = [math]::Max(0.0, $FlightGb - [math]::Max(0.0, [double]$Mem.private_gb)) }
    return $MinFreeGb + $grow
}
function Format-XPMemory($Mem) {
    "X-Plane private {0} GB; commit {1} of {2} GB, {3} GB left" -f $(if ($Mem.private_gb -lt 0) { '-' } else { $Mem.private_gb }),
        $Mem.commit_used_gb, $Mem.commit_limit_gb, $Mem.commit_free_gb
}
# $null when the commit left is enough, else why not
function Test-XPMemory($Mem, [double]$MinFreeGb = -1, [double]$FlightGb = -1) {
    $need = Get-XPMemoryNeed $Mem $MinFreeGb $FlightGb
    if ($need -gt 0 -and [double]$Mem.commit_free_gb -lt $need) {
        return "{0} GB of commit left, under the {1} GB a scenario needs ({2}): close other programs, enlarge the page file or start X-Plane again" -f `
            $Mem.commit_free_gb, $need, (Format-XPMemory $Mem)
    }
    return $null
}

# --- the state of a long test (2026-11-12, TESTING.md 4.6) ----------------
# A line a run in the runs folder's STATUS.md (tests\flight\runs): what ran
# and how it ended, what the kit changed in X-Plane and put back, the
# memory. A session that takes over (X-Plane gone, another model) reads
# where the work stands.
$script:XPRunsDir = Join-Path $PSScriptRoot 'runs'
function Add-XPStatus([string]$Text, [string]$File = (Join-Path $script:XPRunsDir 'STATUS.md')) {
    try {
        $dir = Split-Path -Parent $File
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $new = -not (Test-Path -LiteralPath $File)
        $lines = @()
        if ($new) {
            $lines += '# Flight tests: the state (the kit adds a line a run; the newest last)'
            $lines += ''
            $lines += 'If a run died: `powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\xp.ps1 restore` puts the user''s X-Plane settings back (X-Plane''s Output\B747_flighttest\kit_settings.txt holds them).'
            $lines += ''
        }
        $lines += ('- {0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text)
        [IO.File]::AppendAllLines($File, [string[]]$lines)
    } catch { }
}

if ($MyInvocation.InvocationName -ne '.' -and $Verb) {
    switch ($Verb) {
        'caps'   { Get-XPCapabilities | ConvertTo-Json -Depth 5 }
        'get'    { Get-XPDataref $Arg1 | ConvertTo-Json -Compress }
        'set'    { Set-XPDataref $Arg1 $Arg2; 'ok' }
        'cmd'    { $d = if ($Arg2) { [double]$Arg2 } else { 0 }; Invoke-XPCommand $Arg1 $d; 'ok' }
        'flight' { Start-XPFlight $Arg1 }
        'shot'   { Save-XPScreenshot $Arg1 }
        'find'   { Find-XPDataref $Arg1 }
        'acf'    { Get-XPAircraftRel $(if ($Arg1) { $Arg1 } else { 'custom' }) }
        'mem'    { Format-XPMemory (Get-XPMemory) }
        'restore' {
            $notes = @(Exit-XPTestSettings)
            if ($notes.Count -eq 0) { "nothing to put back (no $(Get-XPSettingsFile))" } else { $notes }
            Add-XPStatus ("restore by hand: " + $(if ($notes.Count) { $notes -join '; ' } else { 'nothing to put back' }))
        }
        default  { throw "unknown verb: $Verb" }
    }
}
