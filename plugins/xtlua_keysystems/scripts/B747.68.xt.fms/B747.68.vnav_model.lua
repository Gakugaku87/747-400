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
--   at about 1,250 fpm in the early descent until the path and in the
--   cruise descent (FCOM p.1260-1261); VNAV SPD with IDLE in the descent in
--   speed intervention (FCOM p.643: step 9d3);
--   the target speed: the climb's, the cruise's or the descent's schedule
--   (B747.68.pred_model.lua's), the crew's MCP speed in speed intervention,
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
-- p.3.5-5: about 1,250 fpm), the cruise descent's the same (estimate: the
-- sources give none); the early descent's path met once the airplane was
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

function M.new()
    return {phase = "CLB", out = {},
        early = false, early_below = false,  -- the early descent, under the path in it
        crz_chg = nil,                       -- the cruise climb ("CLB") or descent ("DES")
        crz_last = nil,                      -- CRZ ALT the update before
        drag = false,                        -- DRAG REQUIRED (step 9e1)
        rev = nil, rev_cas = nil,            -- the speed reversion ("fast", "slow") and its speed
        dd = nil}                            -- the driftdown's floor: the maximum at its start (step 9h4b)
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
-- NM) and the segment's kind ("idle" or "spd"); nil without a path.
-- path = {e = {...}, h = {...}, k = {...}} with e rising from the E/D's 0
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
    local g = de > 1e-9 and (hs[hi] - hs[lo]) / de or 0
    return hs[lo] + g * (e - es[lo]), g, path.k[hi] or "idle"
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

-- the target speed: the schedule's (or the MCP's in speed intervention,
-- the takeoff's), within the margins; and whether a margin limits it
-- (step 9h3b: the title's LIM SPD). The cruise's by its function at crz_ft
-- (step 9h4b: the driftdown's at CRZ ALT), else here
local function target_speed(P, sched, crz, inp, phase, to_cas, crz_ft)
    local cas, mach, mm
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
    end
    local lim, limited = nil, false
    if inp.flaps_placard then lim = inp.flaps_placard - M.PLACARD_MARGIN end
    if lim and cas > lim then cas, mach, mm, limited = lim, P.cas_to_mach(lim, inp.alt), false, true end
    if inp.vmin and inp.vmin > 0 and cas < inp.vmin + M.VMIN_MARGIN then
        cas, limited = inp.vmin + M.VMIN_MARGIN, true
        mach, mm = P.cas_to_mach(cas, inp.alt), false
    end
    return cas, mach, mm, limited
end

-- (step 9e1) the descent's speed limits on the path at the target cas:
-- lo the minimum maneuvering speed, hi the most, drag DRAG REQUIRED's;
-- above the first speed constraint (the speed transition's altitude here)
-- or below it (below)
local function speed_limits(P, inp, cas, below)
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
    if tc then hi = math.min(hi, tc + M.TRANS_ADD_KT) end
    if inp.flaps_placard then hi = math.min(hi, inp.flaps_placard - M.PLACARD_MARGIN) end
    return lo, hi, cas + M.DRAG_LOW_KT
end

-- (step 9e1) the speed reversion ("fast" or "slow") and its speed: fast,
-- VMO/MMO less 16 kt above the first speed constraint, the SPD TRANS's speed
-- (the transition's less 10) below; slow, REV_SLOW_ADD over the higher of
-- the best holding speed and the minimum maneuvering speed above, the SPD
-- TRANS's (not under the minimum maneuvering speed) below. On approach
-- (step 9e2) the fast side's the target's (FCOM p.1262 names none: estimate)
local function reversion(s, P, inp, kind, tr, target)
    if s.rev then return end
    local below = inp.alt < tr
    local tc = inp.des and inp.des.trans_cas or 240
    local vmin = (inp.vmin and inp.vmin > 0) and inp.vmin or 0
    local cas
    if kind == "fast" and inp.on_app then
        cas = target
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
--                constraint ahead or the E/D's (ft) or nil
--   path         the descent path ({e, h, k}: see path_at) or nil;
--                d_ed the distance to go to the E/D (NM) or nil
-- out: valid, phase ("CLB", "CRZ", "DES"), crz_chg (the cruise climb's
--   "CLB" or descent's "DES", else nil), mode ("SPD", "PTH"), cas, mach,
--   mach_mode, alt (the FMC altitude), vs (PTH's vertical speed, nil level;
--   THR's in the early and the cruise descent), path_alt, path_dev (ft
--   above the path), at (the A/T mode), msg ("DRAG" for DRAG REQUIRED,
--   "THRUST" for THRUST REQUIRED, else nil: step 9e1), end_des (END OF DES:
--   step 9e2), title ("LIM SPD", "VREF + 100" or nil: step 9h3b), dd (the
--   driftdown: step 9h4b)
function M.update(s, inp)
    local out = s.out
    local P = inp.P
    local path_h, g, kind = nil, nil, nil
    local etd = nil
    if inp.path and inp.d_ed then
        path_h, g, kind = M.path_at(inp.path, inp.d_ed)
        -- (step 9d2a) the T/D where the path reaches CRZ ALT (its top
        -- without), the path level at CRZ ALT before it: the predictions'
        -- goes on up to the ceiling (s144's early descent kept 13,000 ft
        -- under it there and never met it)
        etd = inp.crz_alt and M.path_e_at(inp.path, inp.crz_alt) or inp.path.e[#inp.path.e]
        if path_h and inp.crz_alt and path_h > inp.crz_alt then path_h, g = inp.crz_alt, 0 end
    end

    -- the phase
    local ph = s.phase
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
            if past and path_h <= inp.alt + 50 and mcpBelow then ph, s.crz_chg = "DES", nil end
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
    local limited
    out.cas, out.mach, out.mach_mode, limited = target_speed(P, inp.sched, inp.crz, inp, spd_ph, to_cas,
        s.dd and inp.crz_alt or nil)
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
            out.mode, out.at, out.vs = "SPD", M.AT_THR, -M.EARLY_VS
        else
            out.mode, out.at = "PTH", M.AT_SPD
        end
    elseif s.early then
        -- the early descent: VNAV SPD, the A/T's THR to the rate (speed/
        -- thrust: ATA34_2 p.615)
        out.mode, out.at, out.vs = "SPD", M.AT_THR, -M.EARLY_VS
        out.alt = inp.des_alt
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
        out.alt = inp.des_alt
        if path_h then out.path_alt, out.path_dev = path_h, inp.alt - path_h end
    else
        out.mode = "PTH"
        out.alt = inp.des_alt
        out.at = M.AT_IDLE
        local tr = inp.des and inp.des.trans_alt or 10000
        local ias = inp.ias
        local lo, hi, drag = speed_limits(P, inp, out.cas, inp.alt < tr)
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
        -- too slow: the A/T on speed until near the target again
        if ias and out.cas then
            local slow = inp.alt < tr and M.SLOW_KT_LOW or M.SLOW_KT
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
                out.mode, out.at, out.vs = "SPD", M.AT_IDLE, nil
                out.cas, out.mach, out.mach_mode = s.rev_cas, P.cas_to_mach(s.rev_cas, inp.alt), false
                out.msg = s.rev == "fast" and "DRAG" or "THRUST"
            end
        end
    end
    -- valid: an active route, CRZ ALT and the gross weight (ATA34_2 p.621:
    -- the performance data entered), a path in the descent (FCOM p.645:
    -- PERF/VNAV UNAVAILABLE without an E/D) or END OF DES (step 9e2)
    out.valid = (inp.active and inp.crz_alt and inp.kg and (ph ~= "DES" or path_h ~= nil or out.end_des)) and true or false
    return out
end

return M
