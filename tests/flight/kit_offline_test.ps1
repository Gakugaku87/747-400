# The flight-test kit's pieces without X-Plane (2026-11-12; docs/overhaul/
# TESTING.md 4.2, 4.6): the aircraft folder and its acf whatever the
# folder's name, X-Plane's folder above it, the user's X-Plane settings
# taken for a run and put back (a run that died, a setting X-Plane does not
# take), the memory's limit, the state file's lines, run_all.sh's choice of
# scenarios and xp_restart.ps1's memory line, and a scenario that does not
# start for too little commit left. (2026-11-13) A scenario with a step key
# the kit does not read does not start either, and the Log.txt lines about
# the aircraft are picked out of a sample.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\kit_offline_test.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'xp.ps1')

$fails = New-Object System.Collections.ArrayList
$count = 0
function Check([bool]$Ok, [string]$What) {
    $script:count++
    if (-not $Ok) { [void]$fails.Add($What); Write-Host "FAIL $What" }
}
function Equal($A, $B, [string]$What) { Check ($A -eq $B) ("$What`: got '$A', want '$B'") }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("b747_kit_test_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {

# --- the aircraft folder and its acf -------------------------------------
$xp = Join-Path $tmp 'X-Plane 12'
$dev = Join-Path $xp 'Aircraft\747-400-master'
$rel = Join-Path $xp 'Aircraft\747-400-test-pr34'
$deep = Join-Path $xp 'Aircraft\Heavy Metal\747-400 (custom)'
foreach ($d in $dev, $rel, $deep, (Join-Path $xp 'Resources\plugins')) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
foreach ($f in (Join-Path $dev '747-400.acf'), (Join-Path $dev '747-400_custom.acf'), (Join-Path $rel '747-400.acf'),
        (Join-Path $deep '747-400_custom.acf'), (Join-Path $deep '747-400.acf')) { Set-Content -LiteralPath $f -Value 'acf' }
Equal (Get-XPAircraftRel 'custom' $dev $xp) 'Aircraft/747-400-master/747-400_custom.acf' 'the development tree: its custom acf'
Equal (Get-XPAircraftRel 'stock' $dev $xp) 'Aircraft/747-400-master/747-400.acf' 'the development tree: the stock acf'
Equal (Get-XPAircraftRel 'custom' $rel $xp) 'Aircraft/747-400-test-pr34/747-400.acf' 'a release''s copy under another name: its 747-400.acf is the custom acf'
Equal (Get-XPAircraftRel 'stock' $rel $xp) 'Aircraft/747-400-test-pr34/747-400.acf' 'a release''s copy: stock is the same file'
Equal (Get-XPAircraftRel 'custom' $deep $xp) 'Aircraft/Heavy Metal/747-400 (custom)/747-400_custom.acf' 'a folder a level deeper, with spaces and brackets'
Equal (Get-XPAircraftRel 'custom' ($rel + '\') ($xp + '\')) 'Aircraft/747-400-test-pr34/747-400.acf' 'trailing separators'
Equal (Get-XPAircraftRel 'Aircraft/Other/747-400.acf' $dev $xp) 'Aircraft/Other/747-400.acf' 'a path given: as it is'
$err = ''
try { [void](Get-XPAircraftRel 'custom' (Join-Path $tmp 'elsewhere') $xp) } catch { $err = $_.Exception.Message }
Check ($err -match 'not under X-Plane') "an aircraft folder outside X-Plane's: an error ($err)"
New-Item -ItemType Directory -Force -Path (Join-Path $xp 'Aircraft\empty') | Out-Null
$err = ''
try { [void](Get-XPAircraftRel 'custom' (Join-Path $xp 'Aircraft\empty') $xp) } catch { $err = $_.Exception.Message }
Check ($err -match 'no 747-400.acf') "a folder without an acf: an error ($err)"
# X-Plane's folder: the first above the aircraft folder with X-Plane.exe or Resources\plugins
$saved = $env:XPLANE_ROOT
$env:XPLANE_ROOT = $null
Equal (Find-XPRoot $dev) $xp "X-Plane's folder two above the aircraft folder (Resources\plugins)"
Equal (Find-XPRoot $deep) $xp "X-Plane's folder three above a deeper aircraft folder"
$bare = Join-Path $tmp 'nowhere\Aircraft\747'
New-Item -ItemType Directory -Force -Path $bare | Out-Null
Equal (Find-XPRoot $bare) (Join-Path $tmp 'nowhere') 'no X-Plane above: two above the aircraft folder, as before'
$env:XPLANE_ROOT = $xp
Equal (Find-XPRoot $bare) $xp 'XPLANE_ROOT overrides'
$env:XPLANE_ROOT = $saved
# this kit's own folder
Check ($script:XPAircraftDir -eq (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path.TrimEnd('\')) 'the kit''s aircraft folder: two above tests\flight'

# --- the user's settings for a run -----------------------------------------
# a stand-in X-Plane: datarefs in a table; a write to a name in $refuse fails
# (as the Web API's 403 for a read-only dataref), any write is counted
$sim = @{ 'sim/joystick/has_joystick' = 1; 'sim/operation/prefs/startup_running' = 0 }
$refuse = @{}
$writes = New-Object System.Collections.ArrayList
function Get-XPDataref([string]$Name, [int]$Index = -1) {
    if (-not $sim.ContainsKey($Name)) { throw "dataref not found: $Name (is a flight loaded?)" }
    return $sim[$Name]
}
function Set-XPDataref([string]$Name, $Value, [int]$Index = -1) {
    [void]$writes.Add("$Name=$Value")
    if ($refuse.ContainsKey($Name)) { throw "The remote server returned an error: (403) Forbidden." }
    if (-not $sim.ContainsKey($Name)) { throw "dataref not found: $Name (is a flight loaded?)" }
    $sim[$Name] = [int]$Value
}
$state = Join-Path $tmp 'out\kit_settings.txt'
$notes = @(Enter-XPTestSettings $state)
Equal $sim['sim/joystick/has_joystick'] 0 'the run: the user''s hardware off (an X-Plane that takes the write)'
Equal $sim['sim/operation/prefs/startup_running'] 1 'the run: start with the engines running'
Check (Test-Path -LiteralPath $state) 'the user''s values kept in the file (its folder made)'
Equal ((Get-Content -LiteralPath $state) -join '|') 'sim/joystick/has_joystick 1|sim/operation/prefs/startup_running 0' 'the file: the user''s values'
Check ($notes.Count -eq 2 -and $notes[0] -match "has_joystick: the user's 1, 0 for the test" -and $notes[1] -match "startup_running: the user's 0, 1 for the test") "the notes for the result ($($notes -join ' / '))"
# X-Plane finds the hardware again with a flight's start: off again
$sim['sim/joystick/has_joystick'] = 1
$notes = @(Confirm-XPTestSettings $state)
Equal $sim['sim/joystick/has_joystick'] 0 'after a flight''s start: off again'
Check ($notes.Count -eq 1 -and $notes[0] -match 'has_joystick: 1 after the flight''s start, 0 again') "its note ($($notes -join ' / '))"
Equal (@(Confirm-XPTestSettings $state)).Count 0 'nothing changed: no note'
$notes = @(Exit-XPTestSettings $state)
Equal $sim['sim/joystick/has_joystick'] 1 'the end: the user''s hardware back'
Equal $sim['sim/operation/prefs/startup_running'] 0 'the end: the user''s start setting back'
Check (-not (Test-Path -LiteralPath $state)) 'the file removed'
Check ($notes.Count -eq 2 -and $notes[1] -match "startup_running: the user's 0 again") "the notes ($($notes -join ' / '))"
Equal (@(Exit-XPTestSettings $state)).Count 0 'nothing to put back: no note, no error'

# a run that died: X-Plane holds the test's values, the file the user's
[void](Enter-XPTestSettings $state)
$notes = @(Enter-XPTestSettings $state)       # the next run
Equal ((Get-Content -LiteralPath $state) -join '|') 'sim/joystick/has_joystick 1|sim/operation/prefs/startup_running 0' 'the next run keeps the user''s values, not the test''s'
Check ($notes[0] -match 'from a run that did not put it back') "and says so ($($notes[0]))"
[void](Exit-XPTestSettings $state)
Equal ("$($sim['sim/joystick/has_joystick'])$($sim['sim/operation/prefs/startup_running'])") '10' 'put back to the user''s after it'

# X-Plane 12.4.4: has_joystick is read-only (the Web API's 403). With the
# hardware connected: a warning, nothing to put back; the other setting as before
$refuse['sim/joystick/has_joystick'] = $true
$notes = @(Enter-XPTestSettings $state)
Equal $sim['sim/joystick/has_joystick'] 1 'a read-only has_joystick: the hardware stays'
Check ($notes[0] -match '^!sim/joystick/has_joystick is 1 and X-Plane does not take 0 \(.*403.*\): the user''s hardware is connected .* unplug it') "a warning for the result ($($notes[0]))"
Equal $sim['sim/operation/prefs/startup_running'] 1 'the start setting taken all the same'
Equal ((Get-Content -LiteralPath $state) -join '|') 'sim/joystick/has_joystick refused|sim/operation/prefs/startup_running 0' 'the file: refused, and the user''s start setting'
$writes.Clear()
Equal (@(Confirm-XPTestSettings $state)).Count 0 'after a flight''s start: no second warning'
Equal $writes.Count 0 'and no write tried again'
$notes = @(Exit-XPTestSettings $state)
Check ($notes.Count -eq 1 -and $notes[0] -match "startup_running: the user's 0 again") "the end: the start setting back, nothing said of the hardware ($($notes -join ' / '))"
Check (-not (Test-Path -LiteralPath $state)) 'the file removed'
Check (@($writes | Where-Object { $_ -match 'has_joystick' }).Count -eq 0) 'no write to has_joystick at the end'
# without hardware (0 already): no write to the read-only dataref at all, no warning
$sim['sim/joystick/has_joystick'] = 0
$writes.Clear()
$notes = @(Enter-XPTestSettings $state)
Check (@($notes | Where-Object { $_.StartsWith('!') }).Count -eq 0) "no hardware: no warning ($($notes -join ' / '))"
$notes = @(Exit-XPTestSettings $state)
Check (@($writes | Where-Object { $_ -match 'has_joystick' }).Count -eq 0) 'no hardware: has_joystick never written'
Check (@($notes | Where-Object { $_.StartsWith('!') }).Count -eq 0 -and -not (Test-Path -LiteralPath $state)) 'and the end without a warning, the file removed'
$refuse = @{}

# the user's values already the test's: nothing written, still as they were at the end
$sim['sim/joystick/has_joystick'] = 0; $sim['sim/operation/prefs/startup_running'] = 1
$writes.Clear()
[void](Enter-XPTestSettings $state)
[void](Exit-XPTestSettings $state)
Equal $writes.Count 0 'the user''s values already the test''s: no write'
Equal ("$($sim['sim/joystick/has_joystick'])$($sim['sim/operation/prefs/startup_running'])") '01' 'and as they were at the end'

# before a first flight the Web API has no datarefs: a note, no file; taken after the flight's start
$sim = @{}
$notes = @(Enter-XPTestSettings $state)
Check ($notes.Count -eq 2 -and $notes[1] -match 'startup_running: not set \(dataref not found') "no datarefs yet: not set, said ($($notes[1]))"
Check (-not (Test-Path -LiteralPath $state)) 'no file for nothing kept'
$sim = @{ 'sim/joystick/has_joystick' = 1; 'sim/operation/prefs/startup_running' = 0 }
$notes = @(Confirm-XPTestSettings $state)
Equal ("$($sim['sim/joystick/has_joystick'])$($sim['sim/operation/prefs/startup_running'])") '01' 'after the flight''s start: taken then'
Check ($notes.Count -eq 2 -and ($notes -join ' ') -match "startup_running: the user's 0, 1 for the test") "with its notes ($($notes -join ' / '))"
# one setting reached, the other not: the next Confirm takes the other alone
[void](Exit-XPTestSettings $state)
$sim = @{ 'sim/joystick/has_joystick' = 1 }
[void](Enter-XPTestSettings $state)
$sim['sim/operation/prefs/startup_running'] = 0
$notes = @(Confirm-XPTestSettings $state)
Check ($notes.Count -eq 1 -and $notes[0] -match "startup_running: the user's 0, 1 for the test$") "a setting reached later: its note alone ($($notes -join ' / '))"
# X-Plane does not answer at the end (gone): the file stays for "xp.ps1 restore"
$refuse['sim/operation/prefs/startup_running'] = $true
$notes = @(Exit-XPTestSettings $state)
Equal $sim['sim/joystick/has_joystick'] 1 'the one X-Plane took is back'
Check (($notes -join ' ') -match '!sim/operation/prefs/startup_running: NOT put back') "the other said, as a warning ($($notes -join ' / '))"
Equal ((Get-Content -LiteralPath $state) -join '|') 'sim/operation/prefs/startup_running 0' 'and kept in the file'
$refuse = @{}
[void](Exit-XPTestSettings $state)
Equal $sim['sim/operation/prefs/startup_running'] 0 'put back by the next restore'
Check (-not (Test-Path -LiteralPath $state)) 'the file removed then'

# an X-Plane just started, no flight yet: no datarefs (the Web API's 404)
# until the flight loads. The load is begun and left after 5 s, the settings
# written when the datarefs are there (here at the 5th read), then the sim
# waited for
$sim = @{}
$posts = New-Object System.Collections.ArrayList
$script:gets = 0
function Invoke-XPApi([string]$Method, [string]$Path, $Body = $null, [int]$TimeoutSec = 30) {
    [void]$posts.Add("$Method $Path $TimeoutSec")
    if ($Method -eq 'POST') { throw 'The operation has timed out.' }
}
function Get-XPDataref([string]$Name, [int]$Index = -1) {
    $script:gets++
    if ($script:gets -eq 5) {
        $sim['sim/joystick/has_joystick'] = 0; $sim['sim/operation/prefs/startup_running'] = 0
        $sim['sim/time/paused'] = 0; $sim['sim/time/total_running_time_sec'] = 100.0
    }
    if (-not $sim.ContainsKey($Name)) { throw "The remote server returned an error: (404) Not Found." }
    if ($Name -eq 'sim/time/total_running_time_sec') { $sim[$Name] += 5.0 }
    return $sim[$Name]
}
$notes = @(Enter-XPTestSettings $state)
Check (@($notes | Where-Object { $_ -match ': not set \(.*404' }).Count -eq 2 -and -not (Test-Path -LiteralPath $state)) "before the first flight: neither setting reached ($($notes -join ' / '))"
$t = Start-XPFlightLate '{"aircraft":{"path":"x"}}' 30 $state
Equal $posts[0] 'POST /flight 5' 'the load begun, its request left after 5 s'
Equal $sim['sim/operation/prefs/startup_running'] 1 'the start setting written while the flight loads'
Check (($script:XPLateNotes -join ' ') -match "startup_running: the user's 0, 1 for the test") "its notes ($($script:XPLateNotes -join ' / '))"
Equal ((Get-Content -LiteralPath $state) -join '|') 'sim/joystick/has_joystick 0|sim/operation/prefs/startup_running 0' 'the user''s values kept'
Check ($t -gt 100) "then the sim running ($t s)"
[void](Exit-XPTestSettings $state)
Equal $sim['sim/operation/prefs/startup_running'] 0 'put back at the end'

# --- the memory ------------------------------------------------------------
$savedMin = $env:XP_MIN_COMMIT_FREE_GB; $savedFlight = $env:XP_FLIGHT_GB
$env:XP_MIN_COMMIT_FREE_GB = $null; $env:XP_FLIGHT_GB = $null
$m = [ordered]@{ private_gb = 14.2; commit_used_gb = 40.0; commit_limit_gb = 51.9; commit_free_gb = 11.9 }
Equal (Get-XPMemoryNeed $m) 8.0 'the least commit left: 8 GB'
Check ($null -eq (Test-XPMemory $m)) '11.9 GB left: a scenario starts'
$m.commit_free_gb = 7.9
$why = Test-XPMemory $m
Check ($why -match '^7\.9 GB of commit left, under the 8 GB a scenario needs' -and $why -match 'X-Plane private 14\.2 GB; commit 40 of 51\.9 GB, 7\.9 GB left') "7.9 GB left: it does not, with the numbers ($why)"
Check ($null -eq (Test-XPMemory $m 0)) 'a least of 0: no check'
Check ($null -eq (Test-XPMemory $m 4)) 'a least given'
$env:XP_MIN_COMMIT_FREE_GB = '12'
Equal (Get-XPMemoryNeed $m) 12.0 'XP_MIN_COMMIT_FREE_GB'
$env:XP_MIN_COMMIT_FREE_GB = '0'
Equal (Get-XPMemoryNeed $m) 0.0 'XP_MIN_COMMIT_FREE_GB 0: no check'
$env:XP_MIN_COMMIT_FREE_GB = $null
# with what X-Plane with a flight takes on this PC: an X-Plane still under it needs that growth too
$env:XP_FLIGHT_GB = '28'
$m.private_gb = 5.0; $m.commit_free_gb = 25.0
Equal (Get-XPMemoryNeed $m) 31.0 'XP_FLIGHT_GB 28, X-Plane at 5 GB: 8 and 23 GB of growth'
Check ((Test-XPMemory $m) -match 'under the 31 GB') 'a fresh X-Plane before a 28 GB flight with 25 GB left: not started'
$m.private_gb = 27.0
Equal (Get-XPMemoryNeed $m) 9.0 'X-Plane at 27 GB: 1 GB of growth'
$m.private_gb = 30.0
Equal (Get-XPMemoryNeed $m) 8.0 'X-Plane over it: the least alone'
$m.private_gb = -1
Equal (Get-XPMemoryNeed $m) 36.0 'no X-Plane yet: all of it'
$env:XP_MIN_COMMIT_FREE_GB = $savedMin; $env:XP_FLIGHT_GB = $savedFlight
$m.private_gb = -1; $m.commit_free_gb = 11.9
Check ((Format-XPMemory $m) -match '^X-Plane private - GB; ') 'no X-Plane: a dash'
$real = Get-XPMemory
Check ($real.commit_limit_gb -gt 1 -and $real.commit_used_gb -gt 0 -and [math]::Abs($real.commit_limit_gb - $real.commit_used_gb - $real.commit_free_gb) -lt 0.2) "this PC's commit charge: used and left make the limit ($(Format-XPMemory $real))"

# --- the state file --------------------------------------------------------
$status = Join-Path $tmp 'runs\STATUS.md'
Add-XPStatus 'start s000_test (747-400_custom): the first' $status
Add-XPStatus 'end s000_test (747-400_custom): pass 3, fail 0, warn 0' $status
$lines = @(Get-Content -LiteralPath $status)
Equal $lines.Count 6 'the file: four first lines and a line a call'
Check ($lines[0] -match '^# Flight tests: the state' -and $lines[2] -match 'xp\.ps1 restore') 'its first lines: what it is, how to put the settings back'
Check ($lines[4] -match '^- \d{4}-\d\d-\d\d \d\d:\d\d:\d\d start s000_test \(747-400_custom\): the first$') "a line: the time and the text ($($lines[4]))"
Check ($lines[5] -match ' end s000_test ') 'the newest last'

# --- run_all.sh's scenarios (RUN_ALL_DRY) and xp_restart.ps1's memory line --
# (Git for Windows' bash: on the PATH, or beside git's cmd folder)
$bash = (Get-Command bash -ErrorAction SilentlyContinue).Source
if (-not $bash) {
    $git = (Get-Command git -ErrorAction SilentlyContinue).Source
    if ($git) {
        $beside = Join-Path (Split-Path -Parent (Split-Path -Parent $git)) 'bin\bash.exe'
        if (Test-Path -LiteralPath $beside) { $bash = $beside }
    }
}
if ($bash) {
    Set-Alias -Name bash -Value $bash -Scope Script
    $sh = (Join-Path $PSScriptRoot 'tools\run_all.sh') -replace '\\', '/'
    $env:RUN_ALL_DRY = '1'
    $ErrorActionPreference = 'Continue'
    $got = @(& bash $sh --only s285 s172_proc_msgs tests/flight/scenarios/s01_ap_basic.json 2>$null)
    Equal ($got -join '|') 'tests/flight/scenarios/s285_vnav_spd_trans_accel_heavy.json|tests/flight/scenarios/s172_proc_msgs.json|tests/flight/scenarios/s01_ap_basic.json' '--only: by number, by name, by file, in the order given'
    $got = @(& bash $sh --only s28 2>$null)
    Equal ($got -join '|') 'tests/flight/scenarios/s28_stab_trim.json' 'a number is the whole number (s28 is not s285)'
    $list = Join-Path $tmp 'list.txt'
    [IO.File]::WriteAllText($list, "s286   # the descent`r`n# a comment`r`n`r`ns287 s109`n")
    $got = @(& bash $sh --list ($list -replace '\\', '/') 2>$null)
    Equal ($got -join '|') 'tests/flight/scenarios/s286_flch_descent_decel.json|tests/flight/scenarios/s287_vnav_spd_trans_accel_light.json|tests/flight/scenarios/s109_afds_takeoff.json' '--list: a file''s names, comments and CRLF'
    $all = @(& bash $sh 2>$null)
    $n = @(Get-ChildItem (Join-Path $PSScriptRoot 'scenarios') -Filter *.json).Count
    Equal $all.Count $n 'no argument: every scenario'
    $from = @(& bash $sh s99_afds_engage 2>$null)
    Check ($from.Count -ge 1 -and $from[0] -eq 'tests/flight/scenarios/s99_afds_engage.json' -and $from.Count -lt $all.Count) 'a name: from that scenario on'
    [void](& bash $sh --only s285 s99999 2>$null); Equal $LASTEXITCODE 2 'a scenario not there: nothing runs (exit status 2)'
    [void](& bash $sh --only 2>$null); Equal $LASTEXITCODE 2 '--only without a name: exit status 2'
    [void](& bash $sh --list (($list -replace '\\', '/') + '.none') 2>$null); Equal $LASTEXITCODE 2 '--list without its file: exit status 2'
    $ErrorActionPreference = 'Stop'
    $env:RUN_ALL_DRY = $null
} else {
    Write-Host 'no bash: run_all.sh not checked'
}
$memLine = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tools\xp_restart.ps1') -Mem | Select-Object -Last 1)
Check ($memLine -match '^-?\d+ \d+ \d+$') "xp_restart.ps1 -Mem: private, commit left and needed, whole GB ($memLine)"

# --- a scenario that does not start: too little commit left -----------------
$runs = Join-Path $tmp 'runs2'
$env:XP_MIN_COMMIT_FREE_GB = '100000'
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run_scenario.ps1') `
    -Scenario (Join-Path $PSScriptRoot 'scenarios\s172_proc_msgs.json') -Acf custom -RunsDir $runs 2>&1
$code = $LASTEXITCODE
$env:XP_MIN_COMMIT_FREE_GB = $savedMin
Equal $code 3 'too little commit left: exit status 3'
Check ((@($out) -join "`n") -match 'FAIL memory the scenario not started: .* GB of commit left, under the 100000 GB') 'and says why'
Check ((@($out) -join "`n") -match 'result: .*\(pass 0, fail 1, warn 0\)') 'the result line: one failure'
$dir = @(Get-ChildItem $runs -Directory)
Check ($dir.Count -eq 1 -and (Test-Path (Join-Path $dir[0].FullName 'result.json')) -and (Test-Path (Join-Path $dir[0].FullName 'result.md'))) 'its result files written'
$st = @(Get-Content -LiteralPath (Join-Path $runs 'STATUS.md'))
Check ($st[-1] -match 'not started s172_proc_msgs \(747-400_custom\): ') "the state file: not started, why ($($st[-1]))"
Check (-not (Test-Path -LiteralPath (Join-Path $tmp 'out\kit_settings.txt'))) 'no setting touched'

# --- a scenario that does not start: a key the kit does not read (2026-11-13) --
$runs3 = Join-Path $tmp 'runs3'
$bad = Join-Path $tmp 's000_bad_keys.json'
[IO.File]::WriteAllText($bad, '{ "name": "s000_bad_keys", "description": "d", "flight": {}, "steps": [' +
    '{ "do": "cmd", "name": "laminar/B747/fms1/key/clear", "seconds": 1.5 },' +
    '{ "do": "watch", "dref": "a/b", "mx": 1 },' +
    '{ "do": "check", "dref": "a/b", "op": "=", "value": 1 },' +
    '{ "do": "wiat", "dref": "a/b" },' +
    '{ "do": "view", "the": 10 },' +
    '{ "do": "sleep", "seconds": 2 } ] }')
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run_scenario.ps1') `
    -Scenario $bad -Acf custom -RunsDir $runs3 2>&1
$code = $LASTEXITCODE
$text = @($out) -join "`n"
Equal $code 4 'a key the kit does not read: exit status 4'
Check ($text -match "FAIL scenario step 1 \(cmd\): unknown key 'seconds'") "the cmd's seconds (s256, s257) named"
Check ($text -match "FAIL scenario step 2 \(watch\): unknown key 'mx'") 'a misspelt max named'
Check ($text -match "FAIL scenario step 3 \(check\): unknown op '='") 'an op the kit does not know'
Check ($text -match "FAIL scenario step 4: unknown step type 'wiat'") 'a step type the kit does not know'
Check ($text -match "FAIL scenario step 5 \(view\): needs name, or the and psi") 'a view without its preset nor its angles'
Check ($text -notmatch 'step 6') 'the good step: nothing said'
Check ($text -match 'result: .*\(pass 0, fail 5, warn 0\)') "the result line: five failures ($(($text -split "`n" | Select-String 'result:') -join ''))"
$st = @(Get-Content -LiteralPath (Join-Path $runs3 'STATUS.md'))
Check ($st[-1] -match "not started s000_bad_keys \(747-400_custom\): the scenario's steps: step 1 \(cmd\): unknown key 'seconds'") "the state file: not started, why ($($st[-1]))"
Check (-not (Test-Path -LiteralPath (Join-Path $tmp 'out\kit_settings.txt'))) 'no setting touched'

# --- Log.txt: the lines about the aircraft (2026-11-13) ----------------------
$sample = @(
    ([char]0xFEFF + '0:58:58.141 E/SCN: Failed to find resource ''Exterior_Wiper.png'', referenced from file ''Aircraft/747-400-master/objects/747_exterior/''.'),
    '1:42:58.244 E/SOUN: Warning: unknown line EVENT_START_END sim/weather/precipitation_on_aircraft_ratio == 0',
    '1:43:00.000 E/GFX/VK: Memory heap 0 has overstepped its budget!',
    '1:43:01.000 W/TEX: Aircraft/747-400-master/objects/747_exterior/Exterior_Gear_NML.dds cannot be compressed',
    '1:43:02.000 E/SCN: Failed to find resource ''Cockpit_Main.png'', referenced from file ''Aircraft/747-400-master/objects/747_cockpit/''.',
    '1:43:03.000 E/APT: the airport KXYZ has a broken taxiway',
    '1:43:04.000 E/OBJ: bad object Custom Scenery/x/y.obj',
    '1:43:05.000 E/SCN: Failed to find resource ''a.png'', referenced from file ''Aircraft/Other/objects/''.'
)
$got = @(Get-XPAircraftLogErrors $sample 'Aircraft/747-400-master/')
Equal $got.Count 3 "the aircraft's lines of the sample ($($got -join ' / '))"
Check (($got -join "`n") -match 'E/SOUN: Warning: unknown line EVENT_START_END') 'the .snd''s E/SOUN (the rain sound, 2026-11-11)'
Check (($got -join "`n") -match "Cockpit_Main\.png") 'an E/ line naming the aircraft''s folder'
Check (($got -join "`n") -match 'E/OBJ: bad object') 'an E/OBJ'
Check (($got -join "`n") -notmatch 'Exterior_Wiper') 'the exterior''s textures allowed'
Check (($got -join "`n") -notmatch 'GFX|W/TEX|E/APT|Aircraft/Other') 'X-Plane''s graphics, a W/ line, the scenery''s and another aircraft''s lines left out'
Equal @(Get-XPAircraftLogErrors @() 'Aircraft/747-400-master/').Count 0 'no line: none'

} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($fails.Count -gt 0) { Write-Host "kit_offline: $($fails.Count) of $count checks failed"; exit 1 }
Write-Host "kit_offline: $count checks passed"
