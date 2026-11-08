# X-Plane-free tests of auto_flight.ps1 (PERF_SIMBRIEF.md phase 4 flown by
# the kit; TESTING.md 4.7): the acf's numbers, the plan from a made-up OFP
# (the runways, weights, stations, tanks, flaps, procedures, transition
# levels, steps, units, the checks), the flight init, the maneuver speeds,
# the distance to lower the MCP, the QNH, a fix passed, and the CDU's pages
# (words, marks, keys, discontinuities, page numbers) as the FMC draws them.
# No run folder is read.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\perf\auto_flight_offline_test.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'auto_flight.ps1')
$fails = New-Object System.Collections.ArrayList
$count = 0
function Check([bool]$Ok, [string]$What) { $script:count++; if (-not $Ok) { [void]$fails.Add($What); Write-Host "FAIL $What" } }
function Near([double]$A, [double]$B, [double]$Tol, [string]$What) { Check ([math]::Abs($A - $B) -le $Tol) ('{0} (got {1}, want {2} +- {3})' -f $What, $A, $B, $Tol) }
function Sum($A) { $s = 0.0; foreach ($v in $A) { $s += [double]$v }; return $s }
function Throws([scriptblock]$Do, [string]$Like, [string]$What) {
    $msg = $null
    try { & $Do } catch { $msg = $_.Exception.Message }
    Check ($null -ne $msg -and $msg -like $Like) ('{0} (threw: {1})' -f $What, $msg)
}

# ---------------------------------------------------------------- the acf
$acf = Get-AutoAcf $acfFile
Check ($acf.oew_kg -gt 170000 -and $acf.oew_kg -lt 200000) ('acf: the empty weight {0:0} kg' -f $acf.oew_kg)
Check ($acf.station_max_kg.Count -eq 9 -and $acf.tank_cap_kg.Count -eq 9) 'acf: 9 stations, 9 tanks'
Check ((Sum $acf.station_max_kg) -gt 50000) ('acf: the stations'' maxima {0:0} kg' -f (Sum $acf.station_max_kg))
Near (Sum $acf.tank_cap_kg) $acf.fuel_max_kg (0.01 * $acf.fuel_max_kg) 'acf: the tanks make the total capacity'
Check ($acf.tank_cap_kg[0] -gt 0 -and $acf.tank_cap_kg[1] -gt 0 -and $acf.tank_cap_kg[7] -gt 0) 'acf: the centre, main 1 and the stabilizer tanks'

# ---------------------------------------------------------------- a made-up OFP
# KLAX 25R to EDDF 25L, FL330 with steps at ELVEL (FL350) and 62N050W
# (FL370), the SID SIDA1, the STAR STARB2 ending at BBB02
function New-TestFix($Id, $Stage, $Alt, $Via, $Ss, $Lat, $Lon) {
    return [pscustomobject]@{ ident = $Id; stage = $Stage; altitude_feet = "$Alt"; via_airway = $Via; is_sid_star = "$Ss"; pos_lat = "$Lat"; pos_long = "$Lon"; type = 'wpt' }
}
function New-TestOfp([string]$Units = 'kgs', [string]$Zfw = '223500', [string]$Fuel = '150000') {
    $nav = @((New-TestFix 'AAA01' 'CLB' 3000 'SIDA1' 1 34.0 -118.6), (New-TestFix 'AAA02' 'CLB' 9000 'SIDA1' 1 34.3 -118.9),
        (New-TestFix 'TOC' 'CLB' 33000 'SIDA1' 1 35.0 -117.0), (New-TestFix 'ELVEL' 'CRZ' 33000 'DCT' 0 50.0 -100.0),
        (New-TestFix '56N080W' 'CRZ' 35000 'DCT' 0 56.0 -80.0), (New-TestFix '62N050W' 'CRZ' 35000 'DCT' 0 62.0 -50.0),
        (New-TestFix '6230N04000W' 'CRZ' 37000 'DCT' 0 62.5 -40.0), (New-TestFix 'BBB00' 'CRZ' 37000 'STARB2' 1 51.0 7.5),
        (New-TestFix 'TOD' 'CRZ' 37000 'STARB2' 1 51.0 8.0), (New-TestFix 'BBB01' 'DSC' 20000 'STARB2' 1 50.5 8.3),
        (New-TestFix 'BBB02' 'DSC' 10500 'STARB2' 1 50.2 8.5), (New-TestFix 'EDDF' 'DSC' 2900 'STARB2' 1 50.03 8.57))
    return [pscustomobject]@{
        params = [pscustomobject]@{ units = $Units }
        origin = [pscustomobject]@{ icao_code = 'KLAX'; plan_rwy = '25R'; elevation = '125'; trans_alt = '18000'; trans_level = '18000' }
        destination = [pscustomobject]@{ icao_code = 'EDDF'; plan_rwy = '25L'; elevation = '364'; trans_alt = '5000'; trans_level = '7000' }
        weights = [pscustomobject]@{ est_zfw = $Zfw }
        fuel = [pscustomobject]@{ plan_takeoff = $Fuel; reserve = '4422'; alternate_burn = '3640'; enroute_burn = '130000' }
        general = [pscustomobject]@{ initial_altitude = '33000'; costindex = '200'; stepclimb_string = 'KLAX/0330/ELVEL/0350/62N050W/0370' }
        times = [pscustomobject]@{ est_time_enroute = '39600' }
        aircraft = [pscustomobject]@{ is_custom = '1' }
        tlr = [pscustomobject]@{ takeoff = [pscustomobject]@{ runway = @([pscustomobject]@{ identifier = '25L'; flap_setting = '20' }, [pscustomobject]@{ identifier = '25R'; flap_setting = '10' }) } }
        navlog = [pscustomobject]@{ fix = $nav }
    }
}
$ofp = New-TestOfp
$p = Get-AutoPlan $ofp $acf
Check ($p.route -eq 'KLAX-EDDF' -and $p.origin -eq 'KLAX' -and $p.origin_rwy -eq '25R' -and $p.dest -eq 'EDDF' -and $p.dest_rwy -eq '25L') 'plan: the route and runways'
Near $p.origin_elev_ft 125 1e-9 'plan: the origin''s elevation'
Near $p.zfw_kg 223500 1e-6 'plan: ZFW'
Near $p.payload_kg (223500 - $acf.oew_kg) 1e-6 'plan: the payload is ZFW less the acf''s empty weight'
Near (Sum $p.stations_kg) $p.payload_kg 0.01 'plan: the stations hold the payload'
$share = @(0..8 | Where-Object { $acf.station_max_kg[$_] -gt 0 } | ForEach-Object { $p.stations_kg[$_] / $acf.station_max_kg[$_] })
Check ((($share | Measure-Object -Maximum).Maximum - ($share | Measure-Object -Minimum).Minimum) -lt 1e-9) 'plan: each station the same share of its maximum'
Near (Sum $p.tanks_kg) 150000 0.01 'plan: the tanks hold the takeoff fuel'
Near $p.tanks_kg[1] $p.tanks_kg[4] 1e-6 'plan: mains 1 and 4 alike'
Near $p.tow_kg 373500 1e-6 'plan: the takeoff weight'
Near $p.reserves_kg 8062 1e-6 'plan: reserves (the reserve and the alternate fuel)'
Near $p.crz_ft 33000 1e-9 'plan: the initial level'
Check ($p.ci -eq 200) 'plan: CI 200'
Check ($p.takeoff_flaps -eq 10) 'plan: the TLR''s flaps 10 for 25R (not 25L''s 20)'
Check ($p.sid -eq 'SIDA1' -and $p.star -eq 'STARB2') ('plan: SID {0}, STAR {1}' -f $p.sid, $p.star)
Check ($p.star_end -eq 'BBB02') ('plan: the STAR''s last fix BBB02 (not TOD, not the airport): {0}' -f $p.star_end)
Check ($p.approach -eq 'ILS25L') 'plan: the approach ILS25L'
Near $p.app_mcp_ft 3400 1e-9 'plan: the MCP''s approach altitude 3,364 ft up to 3,400'
Near $p.origin_trans_alt_ft 18000 1e-9 'plan: the origin''s transition altitude'
Near $p.dest_trans_level_ft 7000 1e-9 'plan: the destination''s transition level'
Check ($p.steps.Count -eq 2) ('plan: two steps ({0})' -f $p.steps.Count)
if ($p.steps.Count -eq 2) {
    Check ($p.steps[0].fix -eq 'ELVEL' -and $p.steps[0].ft -eq 35000 -and $p.steps[0].lat -eq 50.0 -and $p.steps[0].lon -eq -100.0) 'plan: the step at ELVEL to FL350 and its place'
    Check ($p.steps[1].fix -eq '62N050W' -and $p.steps[1].ft -eq 37000 -and $p.steps[1].lat -eq 62.0) 'plan: the step at 62N050W to FL370'
}
Near $p.trip_kg 130000 1e-6 'plan: the trip fuel'
Check ($p.custom -eq '1') 'plan: the custom airframe'
# pounds
$pl = Get-AutoPlan (New-TestOfp 'lbs' '492000' '330000') $acf
Near $pl.zfw_kg (492000 * $LB) 1e-6 'plan (lbs): ZFW in kg'
Near (Sum $pl.tanks_kg) (330000 * $LB) 0.01 'plan (lbs): the fuel in kg'
Near $pl.reserves_kg (8062 * $LB) 1e-6 'plan (lbs): reserves in kg'
# the TLR without the runway, a flap setting other than 10 or 20, no transition altitude
$o2 = New-TestOfp
$o2.origin.plan_rwy = '24L'; $o2.origin.trans_alt = ''; $o2.destination.trans_level = $null
Check ((Get-AutoPlan $o2 $acf).takeoff_flaps -eq 20) 'plan: no TLR runway, flaps 20'
Near (Get-AutoPlan $o2 $acf).origin_trans_alt_ft 18000 1e-9 'plan: no transition altitude, 18,000 ft'
Near (Get-AutoPlan $o2 $acf).dest_trans_level_ft 18000 1e-9 'plan: no transition level, 18,000 ft'
$o3 = New-TestOfp
$o3.tlr.takeoff.runway[1].flap_setting = '5'
Check ((Get-AutoPlan $o3 $acf).takeoff_flaps -eq 20) 'plan: the TLR''s flaps 5, flaps 20'
# no STAR, no steps
$o4 = New-TestOfp
$o4.navlog.fix = @($o4.navlog.fix | Where-Object { $_.via_airway -ne 'STARB2' })
$o4.general.stepclimb_string = 'KLAX/0330'
$p4 = Get-AutoPlan $o4 $acf
Check ($null -eq $p4.star -and $null -eq $p4.star_end) 'plan: no STAR'
Check ($p4.steps.Count -eq 0) 'plan: no steps'
# a step fix not on the navlog
$o5 = New-TestOfp
$o5.general.stepclimb_string = 'KLAX/0330/NOFIX/0350'
$s5 = Get-AutoSteps $o5
Check ($s5.Count -eq 1 -and $s5[0].fix -eq 'NOFIX' -and $null -eq $s5[0].lat) 'steps: a fix not on the navlog has no place'
# the checks
Throws { Get-AutoPlan (New-TestOfp 'kgs' '150000') $acf } '*below the acf*' 'plan: ZFW below the empty weight'
Throws { Get-AutoPlan (New-TestOfp 'kgs' ('{0}' -f ($acf.oew_kg + (Sum $acf.station_max_kg) + 1000))) $acf } '*above the stations*' 'plan: a payload above the stations'' maxima'
Throws { Get-AutoPlan (New-TestOfp 'kgs' '223500' ('{0}' -f ($acf.fuel_max_kg + 1000))) $acf } '*above the tanks*' 'plan: fuel above the tanks'' capacity'

# ---------------------------------------------------------------- the flight init
$i = Get-AutoInit $p $true
Check ($i.aircraft.path -eq $acfRel) 'init: the custom acf'
Check ($i.runway_start.airport_id -eq 'KLAX' -and $i.runway_start.runway -eq '25R') 'init: the runway start'
Check ($i.engine_status.all_engines.running -eq $true) 'init: the engines running'
Check ($i.use_system_time -eq $true -and $i.weather -eq 'use_real_weather') 'init: the system''s time, real weather'
Check (@($i.weight.payload_weight_in_kilograms).Count -eq 9 -and @($i.weight.fueltank_weight_in_kilograms).Count -eq 9) 'init: 9 stations, 9 tanks'
Near (Sum $i.weight.payload_weight_in_kilograms) $p.payload_kg 0.5 'init: the payload'
Near (Sum $i.weight.fueltank_weight_in_kilograms) 150000 0.5 'init: the fuel'
$js = ConvertTo-Json $i -Depth 10 -Compress
Check ($js -like '*"runway_start":{"airport_id":"KLAX","runway":"25R"}*') 'init: the JSON''s runway start'
Check ($js -like '*"use_system_time":true*' -and $js -like '*"weather":"use_real_weather"*') 'init: the JSON''s time and weather'

# ---------------------------------------------------------------- speeds and distances
$sp = Get-AutoSpeeds 146
Check ($sp.up -eq 226 -and $sp.f1 -eq 206 -and $sp.f5 -eq 186 -and $sp.f10 -eq 166 -and $sp.f20 -eq 156 -and $sp.f30 -eq 146 -and $sp.app -eq 151) 'speeds: FCOM PI.10.3''s maneuver speeds from VREF 30 146'
Near (Get-AutoLowerNm 37000 128) ((37000 - 128) / 1000 * 3.3 + 40) 1e-9 'lower: FL370 to a field at 128 ft'
Check ((Get-AutoLowerNm 37000 128) -gt 140 -and (Get-AutoLowerNm 25000 0) -lt (Get-AutoLowerNm 37000 0)) 'lower: some 160 NM from FL370, less from lower'
Near (Get-AutoQnhInHg 101325) 29.92 1e-9 'QNH: 101,325 Pa'
Near (Get-AutoQnhInHg (29.5 * 3386.389)) 29.5 1e-9 'QNH: 29.50 in Hg'
Check ($null -eq (Get-AutoQnhInHg 0) -and $null -eq (Get-AutoQnhInHg $null) -and $null -eq (Get-AutoQnhInHg 120000) -and $null -eq (Get-AutoQnhInHg 80000)) 'QNH: none, 0 and out of range'
# a fix passed
$st = @{ min = $null }
$seq = @(@(100, $false), @(50, $false), @(30, $false), @(10, $false), @(5, $false), @(5.3, $false), @(5.6, $true))
$ok = $true
foreach ($e in $seq) { if ((Test-AutoPassed $st $e[0]) -ne $e[1]) { $ok = $false } }
Check $ok 'passed: 0.5 NM past the closest (5 NM)'
$st = @{ min = $null }
Check ((Test-AutoPassed $st 30) -eq $false -and (Test-AutoPassed $st 1.5) -eq $true) 'passed: within 2 NM'
$st = @{ min = $null }
Check ((Test-AutoPassed $st 60) -eq $false -and (Test-AutoPassed $st 45) -eq $false -and (Test-AutoPassed $st 50) -eq $false) 'passed: not when never within 40 NM'

# ---------------------------------------------------------------- the CDU's pages
# B744.fms.pages.deparr.lua's lines: lr(l, r) on 24 columns, the left
# column's mark after it, the right's before it
function Lr([string]$L, [string]$R) { return $L + (' ' * [math]::Max(1, 24 - $L.Length - $R.Length)) + $R }
$row1 = Lr 'DIXA2A<ACT>' '<SEL>ILS25L'
Check ($row1.Length -eq 24) 'cdu: a row of 24 columns'
$it = Get-CduItems $row1
Check ($it.Count -eq 2) 'cdu: two words'
Check ($it[0].text -eq 'DIXA2A' -and $it[0].side -eq 'L' -and $it[0].mark -eq '<ACT>' -and $it[0].col -eq 0) 'cdu: the left word and its mark after it'
Check ($it[1].text -eq 'ILS25L' -and $it[1].side -eq 'R' -and $it[1].mark -eq '<SEL>' -and $it[1].col -eq 18) 'cdu: the right word and its mark before it'
$it2 = Get-CduItems (Lr 'ROLIS1A' 'ILS07R')
Check ($it2.Count -eq 2 -and $null -eq $it2[0].mark -and $null -eq $it2[1].mark -and $it2[1].side -eq 'R') 'cdu: no marks'
$page = [string[]]@('   EDDF ARRIVALS', '', (Lr 'DIXA2A' 'ILS25LZ'), '', (Lr 'ROLIS1A' 'ILS25LY'), '', (Lr 'SPESA2A' 'ILS25L'), '',
    (Lr 'UNOKO1A' 'ILS25LZZ'), '', (Lr 'KERAX3A' 'ILS25L1'), '------------------------', (Lr '<INDEX' 'ROUTE>'), '')
Check ($page.Count -eq 14) 'cdu: 14 lines'
$h = Find-CduText $page 'ILS25L' 'R' -Prefix
Check ($null -ne $h -and $h.key -eq 'R3' -and $h.text -eq 'ILS25L') 'cdu: the word itself (R3) before a longer one (R1)'
$h = Find-CduText ([string[]]@($page[0], '', $page[2], '', $page[4], '', '', '', $page[8], '', $page[10], '', $page[12], '')) 'ILS25L' 'R' -Prefix
Check ($null -ne $h -and $h.key -eq 'R1' -and $h.text -eq 'ILS25LZ') 'cdu: without the word itself, the first with one letter more'
Check ($null -eq (Find-CduText ([string[]]@($page[0], '', $page[2], '', $page[4], '', '', '', $page[8], '', $page[10], '', $page[12], '')) 'ILS25L' 'R')) 'cdu: without -Prefix, none'
Check ($null -eq (Find-CduText ([string[]]@('', '', '', '', '', '', '', '', $page[8], '', $page[10], '', '', '')) 'ILS25L' 'R' -Prefix)) 'cdu: not two letters more, not a digit more'
Check ((Find-CduText $page 'ROUTE>' 'R').key -eq 'R6') 'cdu: LSK 6 at Line13'
Check ((Find-CduText $page 'SPESA2A' 'L').key -eq 'L3') 'cdu: a left word'
Check ($null -eq (Find-CduText $page 'SPESA2A' 'R')) 'cdu: not on the other side'
Check ($null -eq (Find-CduText $page 'EDDF')) 'cdu: not the title'
$marked = [string[]]@('   EDDF ARRIVALS', '', (Lr 'DIXA2A' 'ILS25LZ'), '', (Lr 'ROLIS1A' '<SEL>ILS25LY'), '', '', '', '', '', '', '', '', '')
$h = Find-CduText $marked 'ILS25L' 'R' -Prefix -Marked
Check ($null -ne $h -and $h.key -eq 'R2' -and $h.text -eq 'ILS25LY' -and $h.mark -eq '<SEL>') 'cdu: -Marked, the one with <SEL>'
Check ($null -eq (Find-CduText $page 'ILS25L' 'R' -Prefix -Marked)) 'cdu: -Marked, none marked'
# the narrowed view: the approach and its transitions (TRANS)
$narrow = [string[]]@('   EDDF ARRIVALS', '', (Lr 'DIXA2A' '<SEL>ILS25L'), '', (Lr 'ROLIS1A' 'DF426'), '', (Lr '' 'RAMOB'), '', '', '', '', '', '', '')
Check ((Find-CduText $narrow 'DF426' 'R').key -eq 'R2' -and (Find-CduText $narrow 'RAMOB' 'R').key -eq 'R3') 'cdu: the transitions'' keys'
# LEGS's small lines (B744.fms.pages.legs.lua legs_small): the page number,
# each leg's title above it
$small = [string[]]@('                    3/7 ', (' 102' + (' ' * 20)), '', (' 095' + (' ' * 20)), '', (' THEN' + (' ' * 19)), '', '-- ROUTE DISCONTINUITY -', '', (' 088' + (' ' * 20)), '', '', '', '')
Check ($small.Count -eq 14) 'legs: 14 small lines'
$d = Find-CduDiscontinuity $small
Check ($null -ne $d -and $d.box -eq 'L3' -and $d.next -eq 'L4') 'legs: the box at L3, the next waypoint L4'
$small5 = [string[]]@('                    3/7 ', '', '', '', '', '', '', '', '', ' THEN', '', '', '', '')
$d5 = Find-CduDiscontinuity $small5
Check ($null -ne $d5 -and $d5.box -eq 'L5' -and $null -eq $d5.next) 'legs: the box at L5, the next waypoint on the next page'
Check ($null -eq (Find-CduDiscontinuity ([string[]]@('1/7', ' 102', '', '-- ROUTE DISCONTINUITY -', '', '', '', '', '', '', '', '', '', '')))) 'legs: the next leg''s title alone is no box'
$pg = Get-CduPageNo '                    3/7 '
Check ($null -ne $pg -and $pg[0] -eq 3 -and $pg[1] -eq 7) 'page: 3/7'
$pg = Get-CduPageNo '                  12/14 '
Check ($null -ne $pg -and $pg[0] -eq 12 -and $pg[1] -eq 14) 'page: 12/14'
Check ($null -eq (Get-CduPageNo '') -and $null -eq (Get-CduPageNo '   ACT RTE 1 LEGS')) 'page: none'

# ---------------------------------------------------------------- the end
Write-Host ('{0} checks, {1} failed' -f $count, $fails.Count)
if ($fails.Count -gt 0) { exit 1 }
