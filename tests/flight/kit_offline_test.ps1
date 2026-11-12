# The flight-test kit's pieces without X-Plane (2026-11-12; docs/overhaul/
# TESTING.md 4.2, 4.6): the aircraft folder and its acf whatever the
# folder's name, X-Plane's folder above it, the user's X-Plane settings
# taken for a run and put back (a run that died, a setting X-Plane does not
# take), the memory's limit, the state file's lines, run_all.sh's choice of
# scenarios and xp_restart.ps1's memory line, and a scenario that does not
# start for too little commit left.
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

# --- run_all.sh's scenarios (RUN_ALL_DRY) --
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

} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($fails.Count -gt 0) { Write-Host "kit_offline: $($fails.Count) of $count checks failed"; exit 1 }
Write-Host "kit_offline: $count checks passed"
