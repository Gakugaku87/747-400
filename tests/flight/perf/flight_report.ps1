# Phase 4 of PERF_SIMBRIEF.md (the repository's root; docs/overhaul/TESTING.md
# 4.7): a flight flown on a SimBrief plan made with the custom airframe,
# against that plan, offline, from a run of flight_log.ps1 (its ofp.json and
# raw\flight_*.csv):
#   - each of the OFP's fixes at the track's closest approach (passed within
#     -PassNm): the time from takeoff, the fuel on board and the fuel used,
#     planned and flown;
#   - the climb (takeoff to the plan's T/C), the cruise (T/C to T/D) and the
#     descent (T/D to touchdown) at the plan's T/C and T/D positions;
#   - the trip fuel (takeoff to touchdown; the spec: within +-2 %), the
#     weights, the winds, time acceleration (the aircraft's fuel system
#     burns by real time: a flight with it is not a measure).
# The fuel from the fuel's weight (m_fuel_total), the FF gauges' integral
# beside it.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\perf\flight_report.ps1 -Run <tests\flight\perf\runs\<stamp>_flight>
param(
    [string]$Run,
    [double]$PassNm = 5.0
)
$ErrorActionPreference = 'Stop'
$frArgs = @{ Run = $Run; PassNm = $PassNm }
. (Join-Path $PSScriptRoot 'compare.ps1')

# the great circle distance (NM) between two points (degrees)
function Get-GcNm([double]$Lat1, [double]$Lon1, [double]$Lat2, [double]$Lon2) {
    $r = [math]::PI / 180
    $dLat = ($Lat2 - $Lat1) * $r; $dLon = ($Lon2 - $Lon1) * $r
    $a = [math]::Sin($dLat / 2) * [math]::Sin($dLat / 2) + [math]::Cos($Lat1 * $r) * [math]::Cos($Lat2 * $r) * [math]::Sin($dLon / 2) * [math]::Sin($dLon / 2)
    return 2 * 3440.065 * [math]::Asin([math]::Min(1.0, [math]::Sqrt($a)))
}

# the flight's track: the columns used, from the logger's CSVs in order (a
# logger restarted in flight writes another part)
$FlightCols = @('sim_t', 'lat', 'lon', 'press_alt_ft', 'alt', 'fuel_kg', 'weight', 'payload_kg', 'gs_ms', 'tas_ms', 'mach', 'on_ground', 'paused',
    'sim_speed', 'ground_speed_x', 'ff_1', 'ff_2', 'ff_3', 'ff_4', 'fuel_used_kg', 'oat_c', 'vs')
function Read-FlightTrack([string[]]$Files) {
    $lists = @{}; foreach ($c in $FlightCols) { $lists[$c] = New-Object 'System.Collections.Generic.List[double]' }
    foreach ($f in $Files) {
        $lines = [IO.File]::ReadAllLines($f)
        if ($lines.Count -lt 2) { continue }
        $hdr = $lines[0].Split(',')
        $pos = @{}; for ($i = 0; $i -lt $hdr.Count; $i++) { $pos[$hdr[$i]] = $i }
        for ($k = 1; $k -lt $lines.Count; $k++) {
            $cells = $lines[$k].Split(',')
            foreach ($c in $FlightCols) {
                $v = [double]::NaN
                if ($pos.ContainsKey($c) -and $pos[$c] -lt $cells.Count) { [void][double]::TryParse($cells[$pos[$c]], [Globalization.NumberStyles]::Float, $inv, [ref]$v) }
                $lists[$c].Add($v)
            }
        }
    }
    $col = @{}; foreach ($c in $FlightCols) { $col[$c] = $lists[$c].ToArray() }
    return [pscustomobject]@{ n = $col['sim_t'].Length; col = $col; files = $Files }
}

# takeoff: the first row airborne that stays so for 30 s, at 60 kt or more
# over the ground; touchdown: the first row on the ground after the last
# airborne stretch that stays on the ground for 30 s. -1 when none.
function Get-FlightTakeoffLanding($Tr) {
    $g = $Tr.col['on_ground']; $gs = $Tr.col['gs_ms']; $n = $Tr.n
    $to = -1; $ld = -1
    for ($k = 1; $k -lt $n; $k++) {
        if ($g[$k] -eq 0 -and $g[$k - 1] -ne 0 -and $gs[$k] * 1.943844 -ge 60) {
            $ok = $true; for ($j = $k; $j -lt [math]::Min($n, $k + 30); $j++) { if ($g[$j] -ne 0) { $ok = $false; break } }
            if ($ok -and $k + 30 -le $n) { $to = $k; break }
        }
    }
    if ($to -lt 0) { return [pscustomobject]@{ takeoff = -1; touchdown = -1 } }
    for ($k = $n - 1; $k -gt $to; $k--) {
        if ($g[$k] -ne 0 -and $g[$k - 1] -eq 0) {
            $ok = $true; for ($j = $k; $j -lt [math]::Min($n, $k + 30); $j++) { if ($g[$j] -eq 0) { $ok = $false; break } }
            if ($ok) { $ld = $k; break }
        }
    }
    return [pscustomobject]@{ takeoff = $to; touchdown = $ld }
}

# each fix's closest approach along the track, in the OFP's order: from the
# last fix passed on, the nearest row until the track is 60 NM farther than
# that; between the rows around it the minimum of a parabola through the
# squared distances. Passed when within $PassNm (else the next fix looks
# from the last one passed).
function Find-FlightPassages($Tr, $Legs, [int]$From, [int]$To, [double]$PassNm) {
    $la = $Tr.col['lat']; $lo = $Tr.col['lon']
    $out = New-Object System.Collections.ArrayList
    $k0 = $From
    foreach ($lg in $Legs) {
        $best = [double]::PositiveInfinity; $kb = -1
        for ($k = $k0; $k -le $To; $k++) {
            $d = Get-GcNm $la[$k] $lo[$k] $lg.lat $lg.lon
            if ($d -lt $best) { $best = $d; $kb = $k } elseif ($kb -ge 0 -and $d -gt $best + 60) { break }
        }
        if ($kb -lt 0) { [void]$out.Add([pscustomobject]@{ leg = $lg; k = -1; u = 0.0; dist_nm = [double]::NaN; passed = $false }); continue }
        $u = 0.0
        if ($kb -gt $From -and $kb -lt $To) {
            $d0 = [math]::Pow((Get-GcNm $la[$kb - 1] $lo[$kb - 1] $lg.lat $lg.lon), 2); $d1 = $best * $best; $d2 = [math]::Pow((Get-GcNm $la[$kb + 1] $lo[$kb + 1] $lg.lat $lg.lon), 2)
            $den = $d0 - 2 * $d1 + $d2
            if ($den -gt 0) { $u = [math]::Max(-1.0, [math]::Min(1.0, ($d0 - $d2) / (2 * $den))) }
        }
        $passed = $best -le $PassNm
        [void]$out.Add([pscustomobject]@{ leg = $lg; k = $kb; u = $u; dist_nm = $best; passed = $passed })
        if ($passed) { $k0 = $kb }
    }
    return ,$out.ToArray()
}
# a column's value at row $K plus the fraction $U toward the next row (or the one before)
function Get-FlightAt($Tr, [string]$Name, [int]$K, [double]$U) {
    $a = $Tr.col[$Name]
    if ($U -ge 0) { if ($K + 1 -ge $a.Length) { return $a[$K] }; return $a[$K] + $U * ($a[$K + 1] - $a[$K]) }
    if ($K -lt 1) { return $a[$K] }
    return $a[$K] + $U * ($a[$K] - $a[$K - 1])
}

# the flight against its OFP
function Get-FlightCompare($Ofp, $Tr, [double]$PassNm) {
    $tl = Get-FlightTakeoffLanding $Tr
    $res = [ordered]@{ route = $Ofp.route; takeoff_row = $tl.takeoff; touchdown_row = $tl.touchdown; ok = $false; notes = New-Object System.Collections.ArrayList }
    if ($tl.takeoff -lt 0 -or $tl.touchdown -lt 0) { [void]$res.notes.Add('離陸か着陸が記録に無い'); return $res }
    $t = $Tr.col['sim_t']; $fu = $Tr.col['fuel_kg']; $wt = $Tr.col['weight']
    $kTo = $tl.takeoff; $kLd = $tl.touchdown
    $t0 = $t[$kTo]; $f0 = $fu[$kTo]
    $res.takeoff = [ordered]@{ t = $t0; fuel = $f0; weight = $wt[$kTo]; zfw = $wt[$kTo] - $f0 }
    $res.touchdown = [ordered]@{ t = $t[$kLd]; fuel = $fu[$kLd]; weight = $wt[$kLd] }
    $res.flight_s = $t[$kLd] - $t0
    $res.burn = $f0 - $fu[$kLd]
    $res.trip_err = $res.burn / $Ofp.trip - 1
    $res.time_err_s = $res.flight_s - $Ofp.time_s
    # the FF gauges' integral, takeoff to touchdown
    $ffi = 0.0
    for ($k = $kTo + 1; $k -le $kLd; $k++) {
        $dt = $t[$k] - $t[$k - 1]
        $s1 = 0.0; $s0 = 0.0; foreach ($e in 1..4) { $s1 += $Tr.col["ff_$e"][$k]; $s0 += $Tr.col["ff_$e"][$k - 1] }
        if (-not [double]::IsNaN($s1 + $s0)) { $ffi += ($s1 + $s0) / 2 * $dt }
    }
    $res.burn_gauges = $ffi
    # time acceleration and pause between takeoff and touchdown
    $acc = 0; $pz = 0
    for ($k = $kTo; $k -le $kLd; $k++) {
        if ($Tr.col['paused'][$k] -ne 0) { $pz++ }
        elseif ($Tr.col['sim_speed'][$k] -ne 1 -or $Tr.col['ground_speed_x'][$k] -ne 1) { $acc++ }
    }
    $res.accel_rows = $acc; $res.paused_rows = $pz
    # the fixes (the destination's own point: the touchdown)
    $legs = @($Ofp.legs)
    $pass = Find-FlightPassages $Tr @($legs[0..($legs.Count - 2)]) $kTo $kLd $PassNm
    $fixes = New-Object System.Collections.ArrayList
    foreach ($p in $pass) {
        $lg = $p.leg
        $row = [ordered]@{ ident = $lg.ident; stage = $lg.stage; plan_alt = $lg.alt; plan_t = $lg.t_tot; plan_used = $lg.f_used; plan_onb = $lg.f_onb
            dist_nm = $p.dist_nm; passed = $p.passed; t = [double]::NaN; used = [double]::NaN; onb = [double]::NaN; alt = [double]::NaN }
        if ($p.k -ge 0) {
            $row.t = (Get-FlightAt $Tr 'sim_t' $p.k $p.u) - $t0
            $row.onb = Get-FlightAt $Tr 'fuel_kg' $p.k $p.u
            $row.used = $f0 - $row.onb
            $row.alt = Get-FlightAt $Tr 'press_alt_ft' $p.k $p.u
        }
        [void]$fixes.Add($row)
    }
    $last = $legs[$legs.Count - 1]
    [void]$fixes.Add([ordered]@{ ident = $last.ident; stage = $last.stage; plan_alt = $last.alt; plan_t = $last.t_tot; plan_used = $last.f_used; plan_onb = $last.f_onb
        dist_nm = 0.0; passed = $true; t = $res.flight_s; used = $res.burn; onb = $fu[$kLd]; alt = $Tr.col['press_alt_ft'][$kLd] })
    $res.fixes = $fixes.ToArray()
    # the arrival: from the last fix passed before the destination to the
    # touchdown. The flight there is ATC's (radar vectors: the first flight
    # of 2026-11-08 flew 14 minutes from GADDO, the plan's last leg 15 NM in
    # 6), so the trip to that fix beside the whole trip's.
    $iLast = -1
    for ($i = $pass.Count - 1; $i -ge 0; $i--) { if ($pass[$i].passed) { $iLast = $i; break } }
    if ($iLast -ge 0 -and $res.fixes[$iLast].plan_used -gt 0) {
        $lf = $res.fixes[$iLast]; $kF = $pass[$iLast].k
        $la = $Tr.col['lat']; $lo = $Tr.col['lon']
        $nm = 0.0; for ($k = $kF + 1; $k -le $kLd; $k++) { $nm += Get-GcNm $la[$k - 1] $lo[$k - 1] $la[$k] $lo[$k] }
        $planNm = 0.0; foreach ($lg in $legs) { if ($lg.i -gt $pass[$iLast].leg.i) { $planNm += $lg.dist } }
        $res.arrival = [ordered]@{ fix = $lf.ident; plan_nm = $planNm; plan_t = $Ofp.time_s - $lf.plan_t; plan_f = $Ofp.trip - $lf.plan_used
            flown_nm = $nm; flown_t = $res.flight_s - $lf.t; flown_f = $res.burn - $lf.used; err_to_fix = $lf.used / $lf.plan_used - 1 }
    }
    # the phases at the plan's T/C and T/D
    $toc = @($res.fixes | Where-Object { $_.ident -eq 'TOC' })[0]; $tod = @($res.fixes | Where-Object { $_.ident -eq 'TOD' })[0]
    if ($null -eq $toc -or $null -eq $tod -or -not $toc.passed -or -not $tod.passed) {
        [void]$res.notes.Add('計画の T/C か T/D の近くを通っていない（区間に分けられない）')
    } else {
        $res.phases = [ordered]@{
            climb = [ordered]@{ plan = $toc.plan_used; flown = $toc.used; plan_t = $toc.plan_t; flown_t = $toc.t }
            cruise = [ordered]@{ plan = $tod.plan_used - $toc.plan_used; flown = $tod.used - $toc.used; plan_t = $tod.plan_t - $toc.plan_t; flown_t = $tod.t - $toc.t }
            descent = [ordered]@{ plan = $Ofp.trip - $tod.plan_used; flown = $res.burn - $tod.used; plan_t = $Ofp.time_s - $tod.plan_t; flown_t = $res.flight_s - $tod.t } }
    }
    # the cruise's wind: the plan's (its cruise legs, time-weighted) and the
    # flight's (GS - TAS, between the plan's T/C and T/D)
    $crz = @($legs | Where-Object { $_.stage -eq 'CRZ' })
    $tw = 0.0; $ww = 0.0; foreach ($lg in $crz) { $tw += $lg.t_leg; $ww += $lg.wind * $lg.t_leg }
    $res.wind_plan_kt = if ($tw -gt 0) { $ww / $tw } else { [double]::NaN }
    $res.wind_flown_kt = [double]::NaN
    if ($res.Contains('phases')) {
        $kA = @($pass | Where-Object { $_.leg.ident -eq 'TOC' })[0].k; $kB = @($pass | Where-Object { $_.leg.ident -eq 'TOD' })[0].k
        $s = 0.0; $m = 0
        for ($k = $kA; $k -le $kB; $k++) { $v = ($Tr.col['gs_ms'][$k] - $Tr.col['tas_ms'][$k]) * 1.943844; if (-not [double]::IsNaN($v)) { $s += $v; $m++ } }
        if ($m -gt 0) { $res.wind_flown_kt = $s / $m }
    }
    $res.ok = $true
    return $res
}

# the OFP's fuel factor as a multiplier: its fuelfact ("1" for P00; a
# multiplier, or the P/M form) else 1
function Get-OfpFactor([string]$S) {
    if ($S -match '^\s*([PM])(\d+(\.\d+)?)\s*$') { $p = [double]::Parse($Matches[2], $inv) / 100; return $(if ($Matches[1] -eq 'M') { 1 - $p } else { 1 + $p }) }
    $v = 0.0
    if ([double]::TryParse($S, [Globalization.NumberStyles]::Float, $inv, [ref]$v) -and $v -gt 0.5 -and $v -lt 1.5) { return $v }
    return 1.0
}
# the proposal when the trip is off by more than 2 %: the airframe's factor
# times the flown / planned trip
function Get-FlightFactorProposal($Ofp, [double]$TripErr) {
    $cur = Get-OfpFactor $Ofp.fuelfact
    $new = $cur * (1 + $TripErr)
    return [pscustomobject]@{ current = $cur; current_text = (Format-PerfFactor ($cur - 1)); proposed = $new; proposed_text = (Format-PerfFactor ($new - 1)) }
}

function Format-FlightHm([double]$S) { if ([double]::IsNaN($S)) { return '' }; $m = [int][math]::Round($S / 60); return ('{0}:{1:00}' -f [math]::Floor($m / 60), ($m % 60)) }

# the report (Japanese)
function Write-FlightReport([string]$Path, [string]$RunName, $Ofp, $Tr, $C) {
    $md = New-Object System.Collections.ArrayList
    $add = { param([string]$S) [void]$md.Add($S) }
    & $add "# PERF_SIMBRIEF.md フェーズ4：実際の飛行と計画（$RunName）"
    & $add ''
    & $add ('OFP：{0}、機体 {1}（{2}）、Fuel Factor {3}、CI {4}。記録 {5} 行。' -f $Ofp.route, $Ofp.airframe, $(if ($Ofp.custom -eq '1') { 'カスタム' } else { '標準' }),
        (Format-PerfFactor ((Get-OfpFactor $Ofp.fuelfact) - 1)), $Ofp.ci, $Tr.n)
    & $add ''
    if (-not $C.ok) { & $add '## 比べられなかった'; & $add ''; foreach ($n in $C.notes) { & $add "- $n" }; [IO.File]::WriteAllLines($Path, [string[]]$md, $utf8); return }
    $verdict = if ([math]::Abs($C.trip_err) -le 0.02) { '±2 % の内：仕様の完成の目安に入った' } else { '±2 % を超えた' }
    & $add '## 結果'
    & $add ''
    & $add ('- **Trip Fuel**：計画 {0:#,0} kg、実際 {1:#,0} kg → **{2:+0.0;-0.0} %**（{3}）。' -f $Ofp.trip, $C.burn, (100 * $C.trip_err), $verdict)
    & $add ('- 飛行時間（離陸〜接地）：計画 {0}、実際 {1}（{2:+0;-0} 分）。' -f (Format-FlightHm $Ofp.time_s), (Format-FlightHm $C.flight_s), ($C.time_err_s / 60))
    & $add ('- 重量：計画の ZFW {0:0.0} t・TOW {1:0.0} t、実際の ZFW {2:0.0} t・TOW {3:0.0} t。' -f ($Ofp.zfw / 1000), ($Ofp.tow / 1000), ($C.takeoff.zfw / 1000), ($C.takeoff.weight / 1000))
    & $add ('- 燃料の計り方：燃料重量の減り {0:#,0} kg、FF 計器の積分 {1:#,0} kg（{2:+0.0;-0.0} %）。' -f $C.burn, $C.burn_gauges, (100 * ($C.burn_gauges / $C.burn - 1)))
    if ($C.accel_rows -gt 0) { & $add ('- **時間加速あり**（{0} 秒分）：機体の燃料系は時間加速を数えないので、この飛行の燃料は比べられない。' -f $C.accel_rows) } else { & $add '- 時間加速：なし。' }
    if (-not [double]::IsNaN($C.wind_flown_kt)) { & $add ('- 巡航の風（追い風が正）：計画 {0:+0;-0} kt、実際（GS − TAS）{1:+0;-0} kt。' -f $C.wind_plan_kt, $C.wind_flown_kt) }
    foreach ($n in $C.notes) { & $add "- $n" }
    & $add ''
    if ($C.Contains('phases')) {
        & $add '## 区間ごと（計画の T/C・T/D の位置で区切る）'
        & $add ''
        & $add '| 区間 | 計画 kg | 実際 kg | 差 kg | 差 | 計画 分 | 実際 分 |'
        & $add '|---|---|---|---|---|---|---|'
        foreach ($ph in @(@('climb', '上昇（離陸〜T/C）'), @('cruise', '巡航（T/C〜T/D）'), @('descent', '降下（T/D〜接地）'))) {
            $v = $C.phases[$ph[0]]
            & $add ('| {0} | {1:#,0} | {2:#,0} | {3:+#,0;-#,0} | {4:+0.0;-0.0} % | {5:0.0} | {6:0.0} |' -f $ph[1], $v.plan, $v.flown, ($v.flown - $v.plan), (100 * ($v.flown / $v.plan - 1)), ($v.plan_t / 60), ($v.flown_t / 60))
        }
        & $add ('| 合計 | {0:#,0} | {1:#,0} | {2:+#,0;-#,0} | {3:+0.0;-0.0} % | {4:0.0} | {5:0.0} |' -f $Ofp.trip, $C.burn, ($C.burn - $Ofp.trip), (100 * $C.trip_err), ($Ofp.time_s / 60), ($C.flight_s / 60))
        & $add ''
    }
    if ($C.Contains('arrival')) {
        $a = $C.arrival
        & $add ('## 到着（{0} から接地まで）' -f $a.fix)
        & $add ''
        & $add '| | 計画 | 実際 | 差 |'
        & $add '|---|---|---|---|'
        & $add ('| 距離 NM | {0:0} | {1:0} | {2:+0;-0} |' -f $a.plan_nm, $a.flown_nm, ($a.flown_nm - $a.plan_nm))
        & $add ('| 時間 分 | {0:0.0} | {1:0.0} | {2:+0.0;-0.0} |' -f ($a.plan_t / 60), ($a.flown_t / 60), (($a.flown_t - $a.plan_t) / 60))
        & $add ('| 燃料 kg | {0:#,0} | {1:#,0} | {2:+#,0;-#,0} |' -f $a.plan_f, $a.flown_f, ($a.flown_f - $a.plan_f))
        & $add ''
        & $add ('{0} までの消費の差：{1:+0.0;-0.0} %。この先はレーダー誘導（管制）で変わり、計画の最後の脚は SimBrief の見込み。' -f $a.fix, (100 * $a.err_to_fix))
        & $add ''
    }
    & $add '## フィックスごと'
    & $add ''
    & $add ('最接近の距離が {0:0} NM を超えた所は「通らず」（近道やレーダー誘導）。時刻は離陸から。' -f $frArgs.PassNm)
    & $add ''
    & $add '| フィックス | 区分 | 最接近 NM | 計画 時刻 | 実際 時刻 | 計画 残燃料 kg | 実際 残燃料 kg | 残燃料の差 kg | 消費の差 | 高度 ft（計画／実際） |'
    & $add '|---|---|---|---|---|---|---|---|---|---|'
    foreach ($f in $C.fixes) {
        if ([double]::IsNaN($f.t)) { & $add ('| {0} | {1} | – | {2} | | {3:#,0} | | | | {4:0} / |' -f $f.ident, $f.stage, (Format-FlightHm $f.plan_t), $f.plan_onb, $f.plan_alt); continue }
        $usedErr = if ($f.plan_used -gt 0) { '{0:+0.0;-0.0} %' -f (100 * ($f.used / $f.plan_used - 1)) } else { '' }
        $mark = if ($f.passed) { '{0:0.0}' -f $f.dist_nm } else { '通らず（{0:0.0}）' -f $f.dist_nm }
        & $add ('| {0} | {1} | {2} | {3} | {4} | {5:#,0} | {6:#,0} | {7:+#,0;-#,0} | {8} | {9:0} / {10:0} |' -f $f.ident, $f.stage, $mark, (Format-FlightHm $f.plan_t), (Format-FlightHm $f.t),
            $f.plan_onb, $f.onb, ($f.onb - $f.plan_onb), $usedErr, $f.plan_alt, $f.alt)
    }
    & $add ''
    & $add '## 判定と修正案'
    & $add ''
    if ([math]::Abs($C.trip_err) -le 0.02) {
        & $add ('- Trip Fuel の差 {0:+0.0;-0.0} % は ±2 % の内。この機体の値はこのままでよい（仕様：計画と実績の差が ±2 % 以内なら完成）。' -f (100 * $C.trip_err))
    } else {
        $pr = Get-FlightFactorProposal $Ofp $C.trip_err
        $worst = $null
        if ($C.Contains('phases')) { foreach ($ph in 'climb', 'cruise', 'descent') { $d = $C.phases[$ph].flown - $C.phases[$ph].plan; if ($null -eq $worst -or [math]::Abs($d) -gt [math]::Abs($worst.d)) { $worst = [pscustomobject]@{ ph = $ph; d = $d } } } }
        & $add ('- Trip Fuel の差 {0:+0.0;-0.0} % が ±2 % を超えた。' -f (100 * $C.trip_err))
        if ($null -ne $worst) { & $add ('- いちばん大きくずれた区間：{0}（{1:+#,0;-#,0} kg）。' -f (Format-PerfPhaseJa $worst.ph), $worst.d) }
        & $add ('- Fuel Factor の案：今の {0} から {1}（実際 ÷ 計画を掛けた値）。風・気温の予報との違いや、計画と違う重量でもずれるので、それを見てから決める。' -f $pr.current_text, $pr.proposed_text)
        if ($C.Contains('arrival')) {
            $pa = Get-FlightFactorProposal $Ofp $C.arrival.err_to_fix
            & $add ('- {0} まで（到着の {1:+#,0;-#,0} kg を除く）の差は {2:+0.0;-0.0} %。こちらに合わせる Fuel Factor の案：{3}。' -f $C.arrival.fix, ($C.arrival.flown_f - $C.arrival.plan_f), (100 * $C.arrival.err_to_fix), $pa.proposed_text)
        }
    }
    [IO.File]::WriteAllLines($Path, [string[]]$md, $utf8)
}
function Format-PerfPhaseJa([string]$P) { switch ($P) { 'climb' { '上昇' } 'cruise' { '巡航' } 'descent' { '降下' } default { $P } } }

# a run of flight_log.ps1: its OFP and CSVs to report.md and compare.json
function Invoke-FlightReport([string]$RunDir, [double]$PassNm = 5.0) {
    $ofp = Read-PerfOfp (Join-Path $RunDir 'ofp.json')
    $files = @(Get-ChildItem (Join-Path $RunDir 'raw') -Filter 'flight_*.csv' | Sort-Object Name | ForEach-Object { $_.FullName })
    if ($files.Count -eq 0) { throw "no raw\flight_*.csv in $RunDir" }
    $tr = Read-FlightTrack $files
    $c = Get-FlightCompare $ofp $tr $PassNm
    Save-Json (Join-Path $RunDir 'compare.json') $c
    Write-FlightReport (Join-Path $RunDir 'report.md') (Split-Path -Leaf $RunDir) $ofp $tr $c
    return $c
}

# dot-sourced (flight_log.ps1, tests/flight/perf/flight_offline_test.ps1): the functions only
if ($MyInvocation.InvocationName -eq '.') { return }
if (-not $frArgs.Run) { throw 'give -Run <runs\..._flight>' }
$c = Invoke-FlightReport ((Resolve-Path $frArgs.Run).Path) $frArgs.PassNm
if ($c.ok) { 'trip fuel {0:+0.00;-0.00} % ({1:0} of {2:0} kg); report.md written' -f (100 * $c.trip_err), $c.burn, ($c.burn / (1 + $c.trip_err)) } else { 'not compared: ' + ($c.notes -join '; ') }
