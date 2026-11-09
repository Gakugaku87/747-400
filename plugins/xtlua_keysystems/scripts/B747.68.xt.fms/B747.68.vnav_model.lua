-- 747-400 FMC VNAV without X-Plane (6-1/6-2 step 9b; docs/overhaul/notes/
-- ATA-34-61-FMC.md §56): the vertical guidance the FMC gives the AFDS and
-- the A/T (ATA34_2 p.597, p.610-617, p.621; ATA22 p.206, p.279-280; FCOM
-- p.645, p.1253-1262):
--   the phase: the climb (to CRZ ALT), the cruise, the descent (past the
--   T/D, where the descent path here comes down to the airplane, from the
--   cruise or a climb without a T/C, with the MCP altitude set below; or
--   DES NOW's early descent before it: step 9d2a); in the cruise a cruise
--   climb or descent to a new CRZ ALT (step 9d2a); the climb again at a
--   missed approach (the glue's: step 9e3);
--   the sub-mode asked for: VNAV SPD in the climb (the target speed on the
--   elevator, the A/T on thrust: THR REF), VNAV PTH in the cruise (the FMC
--   altitude on the elevator, the A/T on speed: SPD) and the descent (the
--   path on the elevator, the A/T at IDLE, or SPD where a line between
--   constraints is too shallow for idle: FCOM p.1258); VNAV SPD with THR
--   at about 1,250 fpm in the early descent until the path (FCOM
--   p.1260-1261); VNAV PTH at about 1,250 fpm with SPD in the cruise
--   descent (FCOM p.1268-1269: step 9h4c); VNAV SPD with IDLE in the
--   descent in speed intervention (FCOM p.643: step 9d3);
--   the target speed: the climb's, the cruise's or the descent's schedule
--   (B747.68.pred_model.lua's; FMC-08: the climb's and the descent's
--   within the waypoints' speed constraints, CLB_SPD_VREF_ADD), the
--   crew's MCP speed in speed intervention,
--   within the flap placard less 5 kt and the minimum maneuvering speed
--   plus 5 kt (FCOM p.663, p.1255: the FMC's margin); after takeoff V2 +
--   10 to V2 + 25 until the acceleration height (FCOM p.1255; step 9c);
--   (step 9h3b) with an engine failure sensed in the takeoff V2 + 10 until
--   the E/O acceleration height or the flaps' retraction, then VREF + 100
--   within the flap placard (FCOM p.1265-1266); the title's LIM SPD while
--   the flap placard or the minimum speed limits it (FCOM p.1265's note,
--   FMSPG p.3.3-3), VREF + 100 for that climb;
--   in the cruise after a missed approach the most restrictive of the
--   speed transition, the best holding speed and ECON cruise (FCOM
--   p.1262; step 9e3);
--   the FMC altitude: the climb's next AT or AT OR BELOW constraint (the
--   glue's), CRZ ALT, the descent's next constraint or the E/D's;
--   the descent path: the trajectory predictions' (B747.68.pred_model.lua),
--   fixed to the ground by the distance to go to the E/D (FCOM p.1258, ATA34_2
--   p.563: a geographically fixed path), its altitude here, the deviation
--   from it and the vertical speed to fly it: the path's own (its gradient
--   at the ground speed) and K_PATH of the deviation back (an estimate: the
--   sources give no gains), never up, at most VS_STEEPER steeper.
-- The AFDS captures the FMC and MCP altitudes (VNAV PTH, VNAV ALT: ATA22
-- p.280) and engages on the FMC's valid (ATA34_2 p.621).
--
--   local V = B747_vnav_model
--   local s = V.new()
--   local out = V.update(s, inp)       -- inp: see update; out the same table
--
-- Altitudes in ft, speeds in kt (CAS) and Mach, distances in NM, vertical
-- speeds in fpm.

local M = setmetatable({}, {})
B747_vnav_model = M

-- the A/T modes asked for (the FMA's numbers: laminar/B747/autopilot/FMA/
-- autothrottle_mode)
M.AT_HOLD, M.AT_IDLE, M.AT_SPD, M.AT_THR, M.AT_THR_REF = 1, 2, 3, 4, 5
-- the speed margins (FCOM p.663, p.1255)
M.PLACARD_MARGIN, M.VMIN_MARGIN = 5, 5
-- the path's correction (fpm a foot off it) and the most it may fly
-- steeper than the path (estimates; step 9c: 3 and 1,500 before, s140 went
-- from 1,424 ft above the path to 860 ft below it: the AFDS's V/S law
-- changes the vertical speed some 50 fpm a second at cruise speeds, so
-- the path is closed over a minute)
M.K_PATH, M.VS_STEEPER = 1, 1000
-- the takeoff's target speed (FCOM p.1255): V2 + TO_ADD_MIN to V2 +
-- TO_ADD_MAX; the flaps' retraction from the takeoff's by TO_FLAPS of the
-- handle's ratio (estimate)
M.TO_ADD_MIN, M.TO_ADD_MAX, M.TO_FLAPS = 10, 25, 0.02
-- (step 9h3b) the engine-out takeoff's VREF + EO_VREF_ADD (FCOM p.1266)
M.EO_VREF_ADD = 100
-- (step 9h4b) the engine-out driftdown (FCOM p.1268; FCTM p.4.11; FMSPG
-- p.3.4-2): ENG OUT active, the cruise descent with the airplane over the
-- engine-out maximum by EO_DD_ABOVE (the CRZ page's E/O LRC D/D): VNAV SPD
-- at the cruise speed at CRZ ALT (the CRZ page's LRC SPD, E/O SPD or SEL
-- SPD) and the A/T's THR to EO_DD_VS down at least, CON the most (the A/T's
-- limit); to CRZ ALT or the maximum at its start, below which the cruise
-- descent's law (E/O CRZ DES: estimate)
M.EO_DD_VS, M.EO_DD_ABOVE = 300, 200
-- the descent slower than the target by more than SLOW_KT (SLOW_KT_LOW
-- below the speed transition: the first speed constraint): the A/T from
-- IDLE or HOLD to SPD until back within SLOW_BACK_KT (FCOM p.1259-1260;
-- the A/T's step 9f2; the way back: estimate)
M.SLOW_KT, M.SLOW_KT_LOW, M.SLOW_BACK_KT = 15, 10, 5
-- the descent starts past the T/D with the MCP altitude this far below
-- (estimate: FCOM p.665 holds the altitude, RESET MCP ALT, while the MCP
-- altitude stays at the cruise altitude)
M.MCP_BELOW = 200
-- (step 9d2a) the early descent's vertical speed (FCOM p.1393, FMSPG
-- p.3.5-5: about 1,250 fpm), the cruise descent's the same (FCOM p.1268's
-- condition 3, p.1269: step 9h4c); the early descent's path met once the airplane was
-- EARLY_BELOW under it and is up to it again (estimate); a cruise climb or
-- descent for CRZ ALT this far off (the climb's since step 9b)
M.EARLY_VS, M.EARLY_BELOW = 1250, 100
M.CRZ_CHG = 500
-- (step 9e1) the descent's speed on the path (FCOM p.1259-1260): above the
-- first speed constraint DRAG REQUIRED over VMO/MMO less 16 kt and at most
-- MAX_ADD_KT more; below it DRAG REQUIRED over the target plus DRAG_LOW_KT,
-- at most plus MAX_LOW_KT and the transition speed plus 5 (the SPD TRANS's
-- speed plus TRANS_ADD_KT: it is the transition's less 10); DRAG REQUIRED
-- gone DRAG_OFF_KT under its speed (estimate). Past them, the path given up
-- to PATH_TOL ft, SPD_VS fpm a kt of the speed's excess (estimate); further
-- the speed reversion, the slow side's 5 kt over the higher of the best
-- holding and the minimum maneuvering speed (REV_SLOW_ADD)
M.MAX_ADD_KT, M.DRAG_LOW_KT, M.MAX_LOW_KT, M.TRANS_ADD_KT = 5, 10, 15, 15
M.DRAG_OFF_KT = 2
M.PATH_TOL, M.SPD_VS = 150, 100
M.REV_SLOW_ADD = 5
-- (6-1/6-2 step 11c2b) CHECK ALT TGT: "between" the MCP and FMC altitudes
-- with both this far away (estimate)
M.CHECK_BAND_FT = 100
-- (FMC-08, 2026-11-09) the waypoints' speed constraints (FCOM p.1332: at
-- or below the speed; p.1329, p.1393: the slower of the constraint's and
-- the performance speed): the climb's waypoints ahead until passing each
-- (inp.clb_spd: FMSPG p.3.3-17), not under VREF + CLB_SPD_VREF_ADD (FCOM
-- p.1326: they take priority provided they are greater than VREF + 100;
-- the floor is how that is read here: an estimate); the descent's passed
-- (inp.des_spd: at and after the waypoint, FMSPG p.3.5-3; on to the E/D:
-- an estimate), the deceleration to it the path's (B747.68.pred_model.lua)
M.CLB_SPD_VREF_ADD = 100

function M.new()
    return {phase = "CLB", out = {},
        early = false, early_below = false,  -- the early descent, under the path in it
        crz_chg = nil,                       -- the cruise climb ("CLB") or descent ("DES")
        crz_last = nil,                      -- CRZ ALT the update before
        drag = false,                        -- DRAG REQUIRED (step 9e1)
        rev = nil, rev_cas = nil,            -- the speed reversion ("fast", "slow") and its speed
        dd = nil,                            -- the driftdown's floor: the maximum at its start (step 9h4b)
        check = nil, was_engaged = false}    -- CHECK ALT TGT's altitude, VNAV engaged before (step 11c2b)
end

-- DES NOW (step 9d2a; FCOM p.1260, p.1389, p.1393; FMSPG p.3.5-5): the
-- descent phase before the T/D, an early descent (VNAV SPD at the
-- descent's speeds, about 1,250 fpm by the A/T's THR, then its HOLD) until
-- the path comes down to the airplane; false in the descent already. The
-- glue asks it with a T/D (DES NOW's prompt, the altitude selector's push)
function M.des_now(s)
    if s.phase == "DES" then return false end
    s.phase, s.early, s.early_below, s.crz_chg = "DES", true, false, nil
    return true
end

-- (step 9e3) the missed approach (FCOM p.1262, p.1264): the climb phase
-- to the new CRZ ALT (VNAV SPD, then VNAV PTH at it), the descent's states
-- gone. The glue asks it at the AFDS's go-around in the descent or on
-- approach (ATA34_2 p.472)
function M.missed(s)
    s.phase, s.early, s.early_below, s.crz_chg = "CLB", false, false, nil
    s.drag, s.rev, s.rev_cas, s.slow = false, nil, nil, false
end

-- the descent path at e NM to go to the E/D: its altitude, gradient (ft a
-- NM), the segment's kind ("idle", "spd" or "decel"), (step LF1) a
-- deceleration's target CAS and (FMC-08) the path's planned CAS there
-- (nil without path.s); nil without a path.
-- path = {e = {...}, h = {...}, k = {...}, c = {...}, s = {...}} with e
-- rising from the E/D's 0
function M.path_at(path, e)
    if not path or not path.e or #path.e < 2 then return nil end
    local es, hs = path.e, path.h
    if e <= es[1] then return hs[1], 0, path.k[2] or "idle" end
    local n = #es
    if e > es[n] then return hs[n], 0, path.k[n] or "idle" end
    local lo, hi = 1, n
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if es[mid] <= e then lo = mid else hi = mid end
    end
    local de = es[hi] - es[lo]
    local f = de > 1e-9 and (e - es[lo]) / de or 0
    local g = de > 1e-9 and (hs[hi] - hs[lo]) / de or 0
    local c = path.c and path.c[hi]
    local ss = path.s
    local planned = (ss and ss[lo] and ss[hi]) and ss[lo] + (ss[hi] - ss[lo]) * f or nil
    return hs[lo] + g * (e - es[lo]), g, path.k[hi] or "idle", (c and c > 0) and c or nil, planned
end

-- the takeoff (FCOM p.1255): from the ground (with V2 selected) the
-- target follows the airspeed between V2 + 10 and V2 + 25 until VNAV
-- engages, then stays there until the acceleration height or the flaps'
-- retraction; nil after it (or an air start: the climb's schedule).
-- (step 9h3b) An engine failure sensed below the E/O acceleration height
-- (FCOM p.1265-1266; also past the all-engine acceleration height when the
-- E/O one is higher): V2 + 10 until the E/O acceleration height or the
-- flaps' retraction, then VREF + 100 on (the second return "VREF + 100")
-- until the climb ends or ENG OUT (step 9h4)
local function takeoff_speed(s, inp)
    local t = inp.takeoff
    if inp.ground then
        s.to = (t and t.v2 and t.v2 > 0) and {v2 = t.v2, flaps = t.flaps} or nil
    end
    local to = s.to
    if not (to and t) then return nil end
    local retracting = t.flaps and to.flaps and t.flaps < to.flaps - M.TO_FLAPS
    if (inp.eo or 0) >= 1 then to.eo = true end
    if to.eo then
        if not to.vref100 and ((t.eo_accel_alt and inp.alt >= t.eo_accel_alt) or retracting) then to.vref100 = true end
        if to.vref100 then
            if not (inp.vref and inp.vref > 0) then return nil end
            return inp.vref + M.EO_VREF_ADD, "VREF + 100"
        end
        return to.v2 + M.TO_ADD_MIN
    end
    if to.accel or (t.accel_alt and inp.alt >= t.accel_alt) or retracting then
        -- the all-engine takeoff over; kept for an engine failure until the
        -- E/O acceleration height
        to.accel = true
        if not (t.eo_accel_alt and inp.alt < t.eo_accel_alt) then s.to = nil end
        return nil
    end
    if not (inp.engaged and to.cas) then
        to.cas = math.max(to.v2 + M.TO_ADD_MIN, math.min(to.v2 + M.TO_ADD_MAX, inp.ias or 0))
    end
    return to.cas
end

-- (step LF1) the T/D's distance to go to the E/D: where the path reaches
-- the cruise altitude and the level deceleration before it (FCOM p.1264;
-- path.td_decel NM: B747.68.pred_model.lua)
function M.td_e(path, crz_alt)
    local e = M.path_e_at(path, crz_alt)
    return e and e + (path.td_decel or 0) or nil
end

-- the distance to go to the E/D where the path first reaches altitude h
-- from the E/D up (its T/D at the cruise altitude: step 9d1's RESET MCP
-- ALT); nil when it does not
function M.path_e_at(path, h)
    if not path or not path.e or #path.e < 2 then return nil end
    local es, hs = path.e, path.h
    for i = 2, #es do
        if hs[i] >= h then
            local dh = hs[i] - hs[i - 1]
            if dh <= 1e-9 then return es[i - 1] end
            return es[i - 1] + (es[i] - es[i - 1]) * (h - hs[i - 1]) / dh
        end
    end
    return nil
end

-- (step LF2; notes/ATA-34-61-FMC.md §127) the distance to go through a
-- turn flown over its fix (the predictions count the turn's path in the
-- leg after it: B747.68.lnav_model.lua's transition; the great circles from
-- the airplane to the next fix do not while it turns): tr = {d (NM to go
-- as the fix was sequenced), t (s)}, the distance flown since taken off it
-- at the ground speed gs (kt) until the great circles' distance d_geo is
-- back up to it or LNAV is on the leg (on_leg); then the difference left
-- blended out over TURN_BLEND_S (estimate). Returns the distance to go and
-- whether the turn still counts. The glue counts turns adding more than
-- TURN_MIN_NM, TURN_MAX_S at most, LNAV on the leg from TURN_LNAV_S on
-- (estimates)
M.TURN_BLEND_S = 30
M.TURN_MIN_NM = 0.5
M.TURN_MAX_S = 600
M.TURN_LNAV_S = 2
function M.turn_dist(tr, d_geo, gs, now, on_leg)
    if not tr.off then
        tr.d = tr.d - math.max(gs, 0) * (now - tr.t) / 3600
        tr.t = now
        if d_geo < tr.d and not on_leg then return tr.d, true end
        tr.off, tr.t0 = tr.d - d_geo, now
    end
    local k = 1 - (now - tr.t0) / M.TURN_BLEND_S
    if k <= 0 then return d_geo, false end
    return d_geo + tr.off * k, true
end

-- (FMC-08) the waypoint speed constraint in force in the phase (see
-- CLB_SPD_VREF_ADD), nil without one
local function wpt_spd(inp, phase)
    if phase == "DES" then return inp.des_spd end
    if phase ~= "CLB" or not inp.clb_spd then return nil end
    if inp.vref and inp.vref > 0 then return math.max(inp.clb_spd, inp.vref + M.CLB_SPD_VREF_ADD) end
    return inp.clb_spd
end

-- the target speed: the schedule's (or the MCP's in speed intervention,
-- the takeoff's), within the margins; and whether a margin limits it
-- (step 9h3b: the title's LIM SPD). The cruise's by its function at crz_ft
-- (step 9h4b: the driftdown's at CRZ ALT), else here. (FMC-08) The
-- climb's and descent's within the waypoint speed constraint in force
-- (wpt_spd), the fifth return its speed where it sets the target
local function target_speed(P, sched, crz, inp, phase, to_cas, crz_ft)
    local cas, mach, mm
    local wkt = nil
    if not inp.spd_int and to_cas and phase == "CLB" then
        -- (step 9h3b) within the flap placard less 5 (the engine-out
        -- takeoff's VREF + 100: FCOM p.1266)
        local placard = inp.flaps_placard and inp.flaps_placard - M.PLACARD_MARGIN
        if placard and to_cas > placard then return placard, P.cas_to_mach(placard, inp.alt), false, true end
        return to_cas, P.cas_to_mach(to_cas, inp.alt), false, false
    end
    if inp.spd_int then
        if inp.spd_int.mach then
            mach, mm = inp.spd_int.mach, true
            cas = P.mach_to_cas(mach, inp.alt)
        else
            cas = inp.spd_int.cas
            mach, mm = P.cas_to_mach(cas, inp.alt), false
        end
    elseif phase == "CRZ" then
        if inp.crzspd and inp.crzspd.cas then
            cas = inp.crzspd.cas
            mach, mm = P.cas_to_mach(cas, inp.alt), false
        else
            mach = crz(P, inp.crzspd or {mach = 0.84}, crz_ft or inp.alt, inp.kg)
            cas, mm = P.mach_to_cas(mach, inp.alt), true
        end
    else
        cas, mach, mm = sched(P, phase == "DES" and inp.des or inp.clb, inp.alt)
        local w = wpt_spd(inp, phase)
        if w and w < cas then cas, mach, mm, wkt = w, P.cas_to_mach(w, inp.alt), false, w end
    end
    local lim, limited = nil, false
    if inp.flaps_placard then lim = inp.flaps_placard - M.PLACARD_MARGIN end
    if lim and cas > lim then cas, mach, mm, limited = lim, P.cas_to_mach(lim, inp.alt), false, true end
    if inp.vmin and inp.vmin > 0 and cas < inp.vmin + M.VMIN_MARGIN then
        cas, limited = inp.vmin + M.VMIN_MARGIN, true
        mach, mm = P.cas_to_mach(cas, inp.alt), false
    end
    return cas, mach, mm, limited, (not limited) and wkt or nil
end

-- (step 9e1) the descent's speed limits on the path at the target cas:
-- lo the minimum maneuvering speed, hi the most, drag DRAG REQUIRED's;
-- above the first speed constraint or below it (below); the transition's
-- speed plus 5 the most below its altitude (below_tr: FCOM p.1260).
-- (FMC-08) The first speed constraint the transition's altitude or a
-- descent waypoint's speed constraint passed (before, the transition's
-- alone: a waypoint's speed was none)
local function speed_limits(P, inp, cas, below, below_tr)
    if not cas then return nil, nil, nil end
    local lo = (inp.vmin and inp.vmin > 0) and inp.vmin or nil
    -- (step 9e2) on approach with the flaps out: the path held up to the
    -- flap placard less 5 (FCOM p.1262)
    if inp.on_app and inp.flaps_placard then
        return lo, inp.flaps_placard - M.PLACARD_MARGIN, cas + M.DRAG_LOW_KT
    end
    if not below then
        local _, lim = P.econ_limit(inp.alt)
        return lo, lim + M.MAX_ADD_KT, lim
    end
    local hi = cas + M.MAX_LOW_KT
    local tc = inp.des and inp.des.trans_cas
    if tc and below_tr then hi = math.min(hi, tc + M.TRANS_ADD_KT) end
    if inp.flaps_placard then hi = math.min(hi, inp.flaps_placard - M.PLACARD_MARGIN) end
    return lo, hi, cas + M.DRAG_LOW_KT
end

-- (step 9e1) the speed reversion ("fast" or "slow") and its speed: fast,
-- VMO/MMO less 16 kt above the first speed constraint, the SPD TRANS's speed
-- (the transition's less 10) below; slow, REV_SLOW_ADD over the higher of
-- the best holding speed and the minimum maneuvering speed above, the SPD
-- TRANS's (not under the minimum maneuvering speed) below. On approach
-- (step 9e2) the fast side's the target's (FCOM p.1262 names none: estimate).
-- SPD TRANS deleted (FCOM p.1392: ECON or the selected speed then), no
-- transition: above's speeds at every altitude (2026-11-05 review 4:
-- before, 240 kt below 10,000 ft still). (FMC-08) Past a descent
-- waypoint's speed constraint: below the transition's altitude the
-- transition's not over the target (the constraint's when lower:
-- 2026-11-09's review, 240 for 210 before), elsewhere the target, not
-- under the minimum maneuvering speed either way (estimates: FCOM
-- p.1259-1260 names the transition's, for the first speed constraint at
-- the transition's altitude)
local function reversion(s, P, inp, kind, tr, target)
    if s.rev then return end
    local tc = inp.des and inp.des.trans_cas
    local below = tc ~= nil and inp.alt < tr
    local vmin = (inp.vmin and inp.vmin > 0) and inp.vmin or 0
    local cas
    if kind == "fast" and inp.on_app then
        cas = target
    elseif inp.des_spd ~= nil then
        cas = math.max(below and math.min(tc, target) or target, vmin)
    elseif kind == "fast" then
        if below then
            cas = tc
        else
            local _, lim = P.econ_limit(inp.alt)
            cas = lim
        end
    elseif below then
        cas = math.max(tc, vmin)
    else
        cas = math.max(inp.hold_cas or 0, vmin) + M.REV_SLOW_ADD
    end
    s.rev, s.rev_cas = kind, cas
end

-- (6-1/6-2 step 9i) the descent's FMC altitude (VNAV SPD captures it,
-- B747.70.vnav_mode_model.lua levels under it once behind: its "far"): the
-- next constraint's (an AT's, an AT OR ABOVE's, a window's lower) or the
-- E/D's; an AT OR BELOW the lower of it and the path at its point (FMSPG
-- p.227 (4-16): in the descent the FMC descends until reaching an AT OR
-- BELOW constraint or the descent path altitude, whichever is lowest; the
-- page's holding pattern, the same elsewhere an estimate). An AT OR BELOW's
-- altitude itself, the path under it, would level VNAV SPD in speed
-- intervention or the speed reversion under it (FCOM p.643: VNAV SPD until
-- the airplane intercepts an altitude constraint); before step 9i, the AFDS
-- did not level under the FMC altitude
function M.des_target(inp)
    local a = inp.des_alt
    if a and inp.des_kind == "B" and inp.path and inp.des_e then
        local h = M.path_at(inp.path, inp.des_e)
        if h and h < a then a = h end
    end
    return a
end

-- inp:
--   P            the performance database (cas_to_mach, mach_to_cas,
--                econ_limit)
--   sched, crz   B747_pred_model.schedule and crz_mach
--   alt, vs, gs  the altitude (ft), vertical speed (fpm), ground speed (kt)
--   ground       on the ground
--   active       an active route; kg the FMC's gross weight (kg) or nil
--   crz_alt      CRZ ALT (ft) or nil; mcp_alt the MCP altitude
--   clb, des     the climb's and descent's schedules (the predictions');
--                crzspd the cruise speed ({mach}, {cas} or {fn})
--   flaps_placard  the flap placard speed (kt) or nil (flaps up)
--   vmin         the minimum maneuvering speed (kt) or nil; hold_cas the
--                best holding speed (kt) or nil (step 9e1)
--   spd_int      the MCP speed in speed intervention ({cas} or {mach})
--   on_app       on approach (the glue's: FCOM p.1261; step 9e2); end_des
--                the E/D passed (END OF DES: FCOM p.1391; step 9e2)
--   missed       after a missed approach, its CRZ ALT still (step 9e3)
--   takeoff      {v2 (nil: none), accel_alt (the acceleration height's
--                altitude, ft), eo_accel_alt (the E/O acceleration
--                height's), flaps (the handle's ratio)}; ias the
--                airspeed (kt); engaged VNAV engaged (the AFDS's)
--   eo, vref     (step 9h3b) the engines inoperative (their number), VREF
--                30 (kt)
--   eo_max       (step 9h4b) ENG OUT active: the engine-out maximum
--                altitude (ft; the CRZ page's MAX), else nil
--   clb_alt      the climb's next AT or AT OR BELOW constraint below CRZ
--                ALT ahead (ft) or nil; des_alt the descent's next
--                constraint ahead or the E/D's (ft) or nil; (step 9i)
--                des_kind its kind ("AT", "A", "B", "W": des_alt a
--                window's lower) and des_e its point's distance to go to
--                the E/D (NM), or nil (see des_target)
--   path         the descent path ({e, h, k}: see path_at) or nil;
--                d_ed the distance to go to the E/D (NM) or nil
--   clb_spd      (FMC-08) the lowest speed constraint (CAS kt) of the
--                climb's waypoints ahead, nil without one; des_spd the
--                lowest of the waypoints passed in the descent, nil
--                without one (see CLB_SPD_VREF_ADD)
-- out: valid, phase ("CLB", "CRZ", "DES"), crz_chg (the cruise climb's
--   "CLB" or descent's "DES", else nil), mode ("SPD", "PTH"), cas, mach,
--   mach_mode, alt (the FMC altitude), vs (PTH's vertical speed, nil level,
--   the cruise descent's too; THR's in the early descent and the
--   driftdown), path_alt, path_dev (ft
--   above the path), at (the A/T mode), msg ("DRAG" for DRAG REQUIRED,
--   "THRUST" for THRUST REQUIRED, else nil: step 9e1), end_des (END OF DES:
--   step 9e2), title ("LIM SPD", "VREF + 100" or nil: step 9h3b), dd (the
--   driftdown: step 9h4b), check_alt (CHECK ALT TGT: step 11c2b), td_hold
--   (step 9i: past the T/D, the cruise kept by the MCP altitude), spd_kt
--   (FMC-08: the target's CAS where a waypoint's speed constraint or the
--   descent's deceleration into a speed segment sets it, for the titles'
--   XXXKT; nil else)
function M.update(s, inp)
    local out = s.out
    local P = inp.P
    local path_h, g, kind, decelCas, plannedCas = nil, nil, nil, nil, nil
    local etd = nil
    if inp.path and inp.d_ed then
        path_h, g, kind, decelCas, plannedCas = M.path_at(inp.path, inp.d_ed)
        -- (step 9d2a) the T/D where the path reaches CRZ ALT (its top
        -- without), the path level at CRZ ALT before it: the predictions'
        -- goes on up to the ceiling (s144's early descent kept 13,000 ft
        -- under it there and never met it); (step LF1) the level
        -- deceleration before it (FCOM p.1264)
        etd = inp.crz_alt and M.td_e(inp.path, inp.crz_alt) or inp.path.e[#inp.path.e]
        if path_h and inp.crz_alt and path_h > inp.crz_alt then path_h, g = inp.crz_alt, 0 end
    end

    -- the phase
    local ph = s.phase
    local tdHold = false
    if inp.ground or not inp.active then
        ph = "CLB"
        s.early, s.crz_chg = false, nil
    else
        if ph == "CLB" and inp.crz_alt and inp.alt >= inp.crz_alt - 50 then ph, s.crz_chg = "CRZ", nil end
        -- a CRZ ALT above in the cruise, or set lower below the airplane:
        -- the cruise climb (the climb's phase: its guidance and thrust) or
        -- descent to it (FCOM p.1257; the CRZ page's CRZ CLB, CRZ DES:
        -- p.1347; step 9d2a), the descent's over within 50 ft of it. Not
        -- the airplane above CRZ ALT alone (an air start's climb over it:
        -- VNAV PTH to it, s144)
        if ph == "CRZ" and inp.crz_alt then
            if inp.crz_alt > inp.alt + M.CRZ_CHG then
                ph, s.crz_chg = "CLB", "CLB"
            elseif s.crz_last and inp.crz_alt < s.crz_last - 50 and inp.crz_alt < inp.alt - M.CRZ_CHG then
                s.crz_chg = "DES"
            elseif s.crz_chg == "DES" and inp.alt <= inp.crz_alt + 50 then
                s.crz_chg = nil
            end
        end
        -- past the T/D (step 9d2a: the path level at CRZ ALT before it),
        -- the path here at or below the airplane (the T/D where the cruise,
        -- or a climb without a T/C, meets it), the MCP altitude below CRZ
        -- ALT and the airplane (step 9d1: before, below the airplane alone;
        -- s143's air start climbed 250 ft over the MCP at FL310 past the
        -- T/D, the descent at once)
        if ph ~= "DES" then
            local ref = inp.crz_alt and math.min(inp.alt, inp.crz_alt) or inp.alt
            local mcpBelow = inp.mcp_alt and inp.mcp_alt < ref - M.MCP_BELOW
            local past = path_h and etd and inp.d_ed <= etd + 1e-6
            if past and path_h <= inp.alt + 50 then
                if mcpBelow then
                    ph, s.crz_chg = "DES", nil
                elseif ph == "CRZ" and not s.crz_chg then
                    -- (step 9i) the cruise kept by the MCP altitude where the
                    -- descent would begin: the AFDS's VNAV ALT there
                    -- (FMSPG p.34 (2-22); B747.70.vnav_mode_model.lua)
                    tdHold = true
                end
            end
        end
        -- the early descent until the path comes down to the airplane (at
        -- once on or above it where it descends: past the T/D)
        if ph == "DES" and s.early and path_h then
            local dev = inp.alt - path_h
            if dev < -M.EARLY_BELOW then s.early_below = true end
            if dev >= 0 and (s.early_below or g > 0) then s.early = false end
        end
    end
    s.phase = ph
    s.crz_last = inp.crz_alt
    out.phase = ph
    out.crz_chg = s.crz_chg
    out.td_hold = tdHold
    -- (step 9h4b) the driftdown: from the cruise descent's start over the
    -- engine-out maximum (or ENG OUT's execution in it), until CRZ ALT or
    -- under the maximum at its start
    if ph == "CRZ" and s.crz_chg == "DES" and inp.eo_max then
        if not s.dd and inp.alt > inp.eo_max + M.EO_DD_ABOVE then s.dd = inp.eo_max end
        if s.dd and inp.alt < s.dd - 50 then s.dd = nil end
    else
        s.dd = nil
    end
    out.dd = s.dd ~= nil

    -- the cruise climb's and descent's speed the cruise's (FCOM p.1261:
    -- economy cruise)
    local spd_ph = s.crz_chg and "CRZ" or ph
    -- (step 9h3b) the takeoff's over with the climb (the engine-out VREF +
    -- 100 lasted till then); the title: LIM SPD where a margin limits the
    -- target (FCOM p.1265's note; FMSPG p.3.3-3), else the VREF + 100 climb's
    if ph ~= "CLB" then s.to = nil end
    local to_cas, to_title = takeoff_speed(s, inp)
    local limited, wkt
    out.cas, out.mach, out.mach_mode, limited, wkt = target_speed(P, inp.sched, inp.crz, inp, spd_ph, to_cas,
        s.dd and inp.crz_alt or nil)
    -- (step LF1) on a deceleration of the path before a speed limit's
    -- altitude, its speed the target (FCOM p.1264: "Before the speed
    -- restriction altitude, FMC commands the target descent airspeed";
    -- before, the target changed only below it: s198); (FMC-08) the same
    -- before a waypoint's speed constraint; not under the minimum
    -- maneuvering speed plus 5 (LIM SPD; before, the deceleration's speed
    -- under it too: a waypoint's 210 kt clean at 235 t, 230 the least)
    if ph == "DES" and kind == "decel" and decelCas and not inp.spd_int and out.cas and decelCas < out.cas then
        local c = decelCas
        local vm = (inp.vmin and inp.vmin > 0) and inp.vmin + M.VMIN_MARGIN or nil
        if vm and c < vm then c, limited = vm, true end
        if c < out.cas then
            out.cas, out.mach, out.mach_mode = c, P.cas_to_mach(c, inp.alt), false
            wkt = (not limited) and c or nil
        end
    end
    -- (FMC-08) the titles' fixed speed (FCOM p.1391-1392, FMSPG p.3.3-3:
    -- XXXKT for a waypoint's speed constraint, and for the descent's
    -- deceleration into a speed segment)
    out.spd_kt = (wkt and not limited and not inp.spd_int) and wkt or nil
    out.title = limited and "LIM SPD" or ((spd_ph == "CLB" and not inp.spd_int) and to_title or nil)
    -- (step 9e3) the cruise after a missed approach (FCOM p.1262): the most
    -- restrictive of the speed transition (the descent's, the destination
    -- airport's, below its altitude: estimate, p.1262 names none), the best
    -- holding speed and ECON cruise; not under the minimum maneuvering
    -- speed plus 5
    if inp.missed and ph == "CRZ" and not inp.spd_int and out.cas then
        local cas = out.cas
        local d = inp.des
        if d and d.trans_cas and inp.alt < (d.trans_alt or 10000) then cas = math.min(cas, d.trans_cas) end
        if inp.hold_cas then cas = math.min(cas, inp.hold_cas) end
        if inp.vmin and inp.vmin > 0 then cas = math.max(cas, inp.vmin + M.VMIN_MARGIN) end
        if cas < out.cas then out.cas, out.mach, out.mach_mode = cas, P.cas_to_mach(cas, inp.alt), false end
    end
    out.path_alt, out.path_dev, out.vs, out.msg = nil, nil, nil, nil
    -- (step 9i) the descent's FMC altitude: an AT OR BELOW's the lower of it
    -- and the path at its point (des_target)
    local desAlt = M.des_target(inp)
    -- (step 9e2) on approach speed intervention keeps the path; END OF DES
    local int = inp.spd_int and not inp.on_app
    out.end_des = (ph == "DES" and inp.end_des) and true or nil
    -- (step 9e1) DRAG REQUIRED and the speed reversion only in the descent
    -- on its path (not the early descent's, nor in speed intervention)
    if ph ~= "DES" or s.early or int or out.end_des then s.drag, s.rev = false, nil end
    if ph == "CLB" then
        out.mode = "SPD"
        out.alt = inp.clb_alt or inp.crz_alt
        out.at = M.AT_THR_REF
    elseif ph == "CRZ" then
        out.alt = inp.crz_alt
        if s.dd then
            -- (step 9h4b) the driftdown: the A/T's THR to at least EO_DD_VS
            -- down, CON its most (FCOM p.1268)
            out.mode, out.at, out.vs = "SPD", M.AT_THR, -M.EO_DD_VS
        elseif s.crz_chg == "DES" then
            -- (step 9h4c) the cruise descent at about 1,250 fpm with the A/T
            -- keeping the cruise speed (FCOM p.1268's condition 3, p.1269):
            -- VNAV PTH on that rate with SPD, the AFDS capturing CRZ ALT
            -- (before, the early descent's VNAV SPD and THR to HOLD: step
            -- 9d2a's estimate)
            out.mode, out.at, out.vs = "PTH", M.AT_SPD, -M.EARLY_VS
        else
            out.mode, out.at = "PTH", M.AT_SPD
        end
    elseif s.early then
        -- the early descent: VNAV SPD, the A/T's THR to the rate (speed/
        -- thrust: ATA34_2 p.615)
        out.mode, out.at, out.vs = "SPD", M.AT_THR, -M.EARLY_VS
        out.alt = desAlt
        if path_h then out.path_alt, out.path_dev = path_h, inp.alt - path_h end
    elseif out.end_des then
        -- (step 9e2) END OF DES (FCOM p.1391: the E/D passed, no climb after
        -- it): level where the airplane is (V/S 0), the A/T on speed
        -- (estimate: the sources say no more)
        out.mode, out.at = "PTH", M.AT_SPD
        out.alt = inp.alt
    elseif int then
        -- (step 9d3) speed intervention in the descent (FCOM p.643): VNAV
        -- SPD, the MCP speed on the elevator and the A/T at IDLE, down to the
        -- next constraint, where the AFDS levels in VNAV PTH (its FMC
        -- altitude captured in VNAV SPD); the path's deviation for the ND.
        -- On approach VNAV PTH stays with the A/T on speed (p.643, p.1261:
        -- step 9e2, below)
        out.mode, out.at = "SPD", M.AT_IDLE
        out.alt = desAlt
        if path_h then out.path_alt, out.path_dev = path_h, inp.alt - path_h end
    else
        out.mode = "PTH"
        out.alt = desAlt
        out.at = M.AT_IDLE
        local tr = inp.des and inp.des.trans_alt or 10000
        local ias = inp.ias
        -- below the transition only with one (SPD TRANS deleted: none);
        -- (FMC-08) below the first speed constraint also past a descent
        -- waypoint's (FCOM p.1259-1260), with SPD TRANS deleted too
        local trans = inp.des ~= nil and inp.des.trans_cas ~= nil
        local belowTr = trans and inp.alt < tr
        local below = belowTr or inp.des_spd ~= nil
        -- (FMC-08) on a deceleration the limits around the path's planned
        -- speed there, not under the target (an estimate: the sources give
        -- the limits around the target; 2026-11-09, s273: from 280
        -- toward SYMON's 250 past MUPTT, the target plus 15 at once 15 kt
        -- under the airplane; the path given up, 813 ft above it and the
        -- speed reversion)
        local band = out.cas
        if kind == "decel" and plannedCas and band and plannedCas > band then band = plannedCas end
        local lo, hi, drag = speed_limits(P, inp, band, below, belowTr)
        if path_h then
            out.path_alt = path_h
            out.path_dev = inp.alt - path_h
            local dev = out.path_dev
            local rate = -g * math.max(inp.gs or 0, 0) / 60
            local vs = rate - M.K_PATH * dev
            vs = math.max(math.min(vs, 0), rate - M.VS_STEEPER)
            -- (step 9e1) past the speed's limits the path given up to
            -- PATH_TOL (the less steep fast, the steeper slow), further the
            -- speed reversion
            if ias and hi and ias > hi then
                vs = math.min(0, math.max(vs, rate + M.SPD_VS * (ias - hi)))
                if dev > M.PATH_TOL then reversion(s, P, inp, "fast", tr, out.cas) end
            elseif ias and lo and ias < lo then
                vs = math.min(vs, rate - M.SPD_VS * (lo - ias))
                if dev < -M.PATH_TOL then reversion(s, P, inp, "slow", tr, out.cas) end
            end
            out.vs = vs
            -- a line too shallow for idle, or below the path (levelling to
            -- meet it): the A/T on speed
            if kind == "spd" or dev < -M.MCP_BELOW then out.at = M.AT_SPD end
        end
        -- too slow: the A/T on speed until near the target again ((FMC-08)
        -- the low limit below the first speed constraint: the transition's
        -- altitude or a descent waypoint's speed constraint passed)
        if ias and out.cas then
            local slow = (inp.alt < tr or inp.des_spd ~= nil) and M.SLOW_KT_LOW or M.SLOW_KT
            if ias < out.cas - slow then
                s.slow = true
            elseif ias >= out.cas - M.SLOW_BACK_KT then
                s.slow = false
            end
            if s.slow then out.at = M.AT_SPD end
        end
        -- (step 9e2) on approach in speed intervention: VNAV PTH, the A/T
        -- on the set speed (FCOM p.643, p.1261)
        if inp.on_app and inp.spd_int then out.at = M.AT_SPD end
        -- DRAG REQUIRED over its speed, gone DRAG_OFF_KT under it
        if ias and drag then
            if ias > drag then s.drag = true elseif ias < drag - M.DRAG_OFF_KT then s.drag = false end
        end
        if s.drag then out.msg = "DRAG" end
        -- the speed reversion: VNAV SPD at its speed until the path is met
        -- (the airplane at it from above, fast, or from below, slow)
        if s.rev then
            if out.path_dev and ((s.rev == "fast" and out.path_dev <= 0) or (s.rev == "slow" and out.path_dev >= 0)) then
                s.rev = nil
            else
                -- (FMC-08) past a waypoint's speed constraint not over the
                -- target since (a lower constraint passed, the deceleration
                -- to one), not under the minimum maneuvering speed
                -- (2026-11-09, s273: 250 kept past BAYST's 240)
                if inp.des_spd and out.cas and out.cas < s.rev_cas then
                    s.rev_cas = math.max(out.cas, (inp.vmin and inp.vmin > 0) and inp.vmin or 0)
                end
                out.mode, out.at, out.vs = "SPD", M.AT_IDLE, nil
                out.cas, out.mach, out.mach_mode = s.rev_cas, P.cas_to_mach(s.rev_cas, inp.alt), false
                out.msg = s.rev == "fast" and "DRAG" or "THRUST"
            end
        end
    end
    -- (6-1/6-2 step 11c2b) CHECK ALT TGT (FCOM p.1431): VNAV engaged with
    -- the airplane between the MCP altitude and the FMC altitude: level
    -- where it engaged (VNAV PTH, the A/T on speed) while they stay on two
    -- sides of it; once one side (the MCP altitude reset, or the FMC's
    -- moved) the profile again. Estimates: CHECK_BAND_FT; the end
    local tgt = out.alt
    local between = inp.engaged and tgt and inp.mcp_alt
        and (tgt - inp.alt) * (inp.mcp_alt - inp.alt) < 0
        and math.abs(tgt - inp.alt) > M.CHECK_BAND_FT and math.abs(inp.mcp_alt - inp.alt) > M.CHECK_BAND_FT
    if not between then
        s.check = nil
    elseif not s.was_engaged then
        s.check = inp.alt
    end
    s.was_engaged = inp.engaged and true or false
    out.check_alt = s.check ~= nil or nil
    if s.check then
        out.mode, out.at, out.vs, out.msg = "PTH", M.AT_SPD, nil, nil
        out.alt = s.check
    end
    -- valid: an active route, CRZ ALT and the gross weight (ATA34_2 p.621:
    -- the performance data entered), a path in the descent (FCOM p.645:
    -- PERF/VNAV UNAVAILABLE without an E/D) or END OF DES (step 9e2)
    out.valid = (inp.active and inp.crz_alt and inp.kg and (ph ~= "DES" or path_h ~= nil or out.end_des)) and true or false
    return out
end

-- (2026-11-05) the climb's next AT, AT OR BELOW or block constraint, VNAV's
-- target (`clb_alt` above): `list` the climb's constraints in route order
-- ({a = feet, p = its waypoint or nil, keep = a climb constraint's: see
-- clb_keep}), `passed(p)` true once a waypoint is passed. Its waypoint not
-- passed, and kept up to CLB_HOLD_FT under the airplane (a level-off's
-- overshoot; estimate): VNAV PTH remains within the departure's
-- constraints (FCOM p.1255). One without a waypoint 100 ft under, as
-- before. Under CRZ ALT; nil without one. Before, any constraint 100 ft
-- under the airplane was taken as passed: s253 (GE, FAOR's EXOB1C) went
-- 104 ft over FL090B short of OR390 in the level-off, the target became
-- the next constraint, and VNAV SPD climbed on to the MCP's 15,000 ft (the
-- user's report there, "LNAV and VNAV in a mess", flew the GE: perhaps
-- this). (Step 9i) A climb constraint (`keep`) with a waypoint is kept at
-- any altitude until the waypoint is passed (FMSPG p.128 (3.3-19): a climb
-- constraint entered below the airplane, VNAV engaged levels and holds the
-- altitude until sequencing the waypoint): below the airplane it is the
-- AFDS's level (B747.70.vnav_mode_model.lua's "far", or CHECK ALT TGT at
-- the engage). The others in the list (the predictions' climb by the half
-- of the way, an estimate, can hold an arrival's constraints on a short
-- route) as before: one more than CLB_HOLD_FT under the airplane missed,
-- the climb on (kept at any altitude, an arrival's AT OR BELOW the airplane
-- had climbed over would stop the climb until its waypoint, in the descent)
M.CLB_HOLD_FT = 300
function M.clb_target(list, alt, crz_alt, passed)
    for _, e in ipairs(list) do
        local under = (e.p and e.keep) or e.a > alt - (e.p and M.CLB_HOLD_FT or 100)
        if under and (not crz_alt or e.a < crz_alt) and not (e.p and passed(e.p)) then
            return e.a
        end
    end
    return nil
end

-- (step 9i) a constraint of the climb's list a climb constraint (`keep`
-- above): a departure's (the SID's legs: FCOM p.1255, "departure or
-- waypoint constraints"), or an enroute leg's (no procedure: the crew's
-- entry, FMSPG p.114 (3.3-5) and p.128 (3.3-19)) before the predictions'
-- T/C `tc` (NM ahead; nil: none, the cruise). Not an arrival's or an
-- approach's (FCOM p.1258: their waypoints are the descent's) nor one after
-- the T/C (FCOM p.1258: entered in the cruise on a downstream waypoint, an
-- E/D). The line at the T/C, for an enroute leg: estimate. `proc` the leg's
-- procedure ("SID", "STAR", "APPR" or nil), `x` its distance ahead (NM)
function M.clb_keep(proc, x, tc)
    if proc == "SID" then return true end
    return proc == nil and tc ~= nil and x ~= nil and x <= tc + 0.01
end

-- (2026-11-08, step 9i's review, finding 3) the climb's legs ahead, by the
-- same rule as clb_keep: the last one's index in `legs` (each {proc}, the
-- first ahead first; `lx[i]` its distance ahead, NM), 0 none. They are a
-- prefix: the SID's legs; in the climb (`phase` "clb") the enroute legs (no
-- procedure) on to the predictions' T/C or a short flight's T/D (`line`,
-- NM ahead), or before one is known those within `half` (half the way to
-- the end: an estimate, as before); never an arrival's or an approach's leg
-- nor one after it (FCOM p.1258: their waypoints the descent's; FMSPG
-- p.114 (3.3-5): the climb's constraints the procedure's or the crew's in
-- the climb). In the cruise and the descent the SID's legs still ahead
-- only. Before, without a SID, the legs before half the way in any phase:
-- an arrival's or approach's constraint there was the climb's, out of the
-- descent's path and its FMC altitude (in the descent at 20,000 ft an AT
-- 15,000 20 NM ahead not in the path, the predictions there 20,000 ft)
function M.clb_last(legs, lx, phase, line, half)
    local last = 0
    for i, l in ipairs(legs) do
        if l.proc == "SID" then
            last = i
        elseif l.proc == nil then
            local lim = line or half
            if phase ~= "clb" or not lim or not lx[i] or lx[i] > lim + 0.01 then break end
            last = i
        else
            break
        end
    end
    return last
end

return M
