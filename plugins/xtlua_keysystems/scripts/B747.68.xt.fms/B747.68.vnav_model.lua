-- 747-400 FMC VNAV without X-Plane (6-1/6-2 step 9b; docs/overhaul/notes/
-- ATA-34-61-FMC.md §56): the vertical guidance the FMC gives the AFDS and
-- the A/T (ATA34_2 p.597, p.610-617, p.621; ATA22 p.206, p.279-280; FCOM
-- p.645, p.1253-1262):
--   the phase: the climb (to CRZ ALT), the cruise, the descent (past the
--   T/D, where the descent path here comes down to the airplane, from the
--   cruise or a climb without a T/C, with the MCP altitude set below);
--   the sub-mode asked for: VNAV SPD in the climb (the target speed on the
--   elevator, the A/T on thrust: THR REF), VNAV PTH in the cruise (the FMC
--   altitude on the elevator, the A/T on speed: SPD) and the descent (the
--   path on the elevator, the A/T at IDLE, or SPD where a line between
--   constraints is too shallow for idle: FCOM p.1258);
--   the target speed: the climb's, the cruise's or the descent's schedule
--   (B747.68.pred_model.lua's), the crew's MCP speed in speed intervention,
--   within the flap placard less 5 kt and the minimum maneuvering speed
--   plus 5 kt (FCOM p.663, p.1255: the FMC's margin); after takeoff V2 +
--   10 to V2 + 25 until the acceleration height (FCOM p.1255; step 9c);
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
-- the descent slower than the target by more than SLOW_KT (SLOW_KT_LOW
-- below the speed transition: the first speed constraint): the A/T from
-- IDLE or HOLD to SPD until back within SLOW_BACK_KT (FCOM p.1259-1260;
-- the A/T's step 9f2; the way back: estimate)
M.SLOW_KT, M.SLOW_KT_LOW, M.SLOW_BACK_KT = 15, 10, 5
-- the descent starts past the T/D with the MCP altitude this far below
-- (estimate: FCOM p.665 holds the altitude, RESET MCP ALT, while the MCP
-- altitude stays at the cruise altitude)
M.MCP_BELOW = 200

function M.new()
    return {phase = "CLB", out = {}}
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
-- retraction; nil after it (or an air start: the climb's schedule)
local function takeoff_speed(s, inp)
    local t = inp.takeoff
    if inp.ground then
        s.to = (t and t.v2 and t.v2 > 0) and {v2 = t.v2, flaps = t.flaps} or nil
    end
    local to = s.to
    if not (to and t) then return nil end
    if (t.accel_alt and inp.alt >= t.accel_alt) or (t.flaps and to.flaps and t.flaps < to.flaps - M.TO_FLAPS) then
        s.to = nil
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
-- the takeoff's), within the margins
local function target_speed(P, sched, crz, inp, phase, to_cas)
    local cas, mach, mm
    if not inp.spd_int and to_cas and phase == "CLB" then
        return to_cas, P.cas_to_mach(to_cas, inp.alt), false
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
            mach = crz(P, inp.crzspd or {mach = 0.84}, inp.alt, inp.kg)
            cas, mm = P.mach_to_cas(mach, inp.alt), true
        end
    else
        cas, mach, mm = sched(P, phase == "DES" and inp.des or inp.clb, inp.alt)
    end
    local lim = nil
    if inp.flaps_placard then lim = inp.flaps_placard - M.PLACARD_MARGIN end
    if lim and cas > lim then cas, mach, mm = lim, P.cas_to_mach(lim, inp.alt), false end
    if inp.vmin and inp.vmin > 0 and cas < inp.vmin + M.VMIN_MARGIN then
        cas = inp.vmin + M.VMIN_MARGIN
        mach, mm = P.cas_to_mach(cas, inp.alt), false
    end
    return cas, mach, mm
end

-- inp:
--   P            the performance database (cas_to_mach, mach_to_cas)
--   sched, crz   B747_pred_model.schedule and crz_mach
--   alt, vs, gs  the altitude (ft), vertical speed (fpm), ground speed (kt)
--   ground       on the ground
--   active       an active route; kg the FMC's gross weight (kg) or nil
--   crz_alt      CRZ ALT (ft) or nil; mcp_alt the MCP altitude
--   clb, des     the climb's and descent's schedules (the predictions');
--                crzspd the cruise speed ({mach}, {cas} or {fn})
--   flaps_placard  the flap placard speed (kt) or nil (flaps up)
--   vmin         the minimum maneuvering speed (kt) or nil
--   spd_int      the MCP speed in speed intervention ({cas} or {mach})
--   takeoff      {v2 (nil: none), accel_alt (the acceleration height's
--                altitude, ft), flaps (the handle's ratio)}; ias the
--                airspeed (kt); engaged VNAV engaged (the AFDS's)
--   clb_alt      the climb's next AT or AT OR BELOW constraint below CRZ
--                ALT ahead (ft) or nil; des_alt the descent's next
--                constraint ahead or the E/D's (ft) or nil
--   path         the descent path ({e, h, k}: see path_at) or nil;
--                d_ed the distance to go to the E/D (NM) or nil
-- out: valid, phase ("CLB", "CRZ", "DES"), mode ("SPD", "PTH"), cas,
--   mach, mach_mode, alt (the FMC altitude), vs (PTH's vertical speed, nil
--   level), path_alt, path_dev (ft above the path), at (the A/T mode)
function M.update(s, inp)
    local out = s.out
    local P = inp.P
    local path_h, g, kind = nil, nil, nil
    if inp.path and inp.d_ed then path_h, g, kind = M.path_at(inp.path, inp.d_ed) end

    -- the phase
    local ph = s.phase
    if inp.ground or not inp.active then
        ph = "CLB"
    else
        if ph == "CLB" and inp.crz_alt and inp.alt >= inp.crz_alt - 50 then ph = "CRZ" end
        -- a higher CRZ ALT: the climb again (FCOM p.1257's cruise climb)
        if ph == "CRZ" and inp.crz_alt and inp.crz_alt > inp.alt + 500 then ph = "CLB" end
        -- past the T/D: the descent path here at or below the airplane (the
        -- T/D where the cruise, or a climb without a T/C, meets it), the MCP
        -- altitude below CRZ ALT and the airplane (step 9d1: before, below
        -- the airplane alone; s143's air start climbed 250 ft over the MCP
        -- at FL310 past the T/D, the descent at once)
        if ph ~= "DES" then
            local ref = inp.crz_alt and math.min(inp.alt, inp.crz_alt) or inp.alt
            local mcpBelow = inp.mcp_alt and inp.mcp_alt < ref - M.MCP_BELOW
            if path_h and path_h <= inp.alt + 50 and mcpBelow then ph = "DES" end
        end
    end
    s.phase = ph
    out.phase = ph

    out.cas, out.mach, out.mach_mode = target_speed(P, inp.sched, inp.crz, inp, ph, takeoff_speed(s, inp))
    out.path_alt, out.path_dev, out.vs = nil, nil, nil
    if ph == "CLB" then
        out.mode = "SPD"
        out.alt = inp.clb_alt or inp.crz_alt
        out.at = M.AT_THR_REF
    elseif ph == "CRZ" then
        out.mode = "PTH"
        out.alt = inp.crz_alt
        out.at = M.AT_SPD
    else
        out.mode = "PTH"
        out.alt = inp.des_alt
        out.at = M.AT_IDLE
        if path_h then
            out.path_alt = path_h
            out.path_dev = inp.alt - path_h
            local rate = -g * math.max(inp.gs or 0, 0) / 60
            local vs = rate - M.K_PATH * out.path_dev
            vs = math.max(math.min(vs, 0), rate - M.VS_STEEPER)
            out.vs = vs
            -- a line too shallow for idle, or below the path (levelling to
            -- meet it): the A/T on speed
            if kind == "spd" or out.path_dev < -M.MCP_BELOW then out.at = M.AT_SPD end
        end
        -- too slow: the A/T on speed until near the target again
        if inp.ias and out.cas then
            local tr = inp.des and inp.des.trans_alt or 10000
            local slow = inp.alt < tr and M.SLOW_KT_LOW or M.SLOW_KT
            if inp.ias < out.cas - slow then
                s.slow = true
            elseif inp.ias >= out.cas - M.SLOW_BACK_KT then
                s.slow = false
            end
            if s.slow then out.at = M.AT_SPD end
        end
    end
    -- valid: an active route, CRZ ALT and the gross weight (ATA34_2 p.621:
    -- the performance data entered), a path in the descent (FCOM p.645:
    -- PERF/VNAV UNAVAILABLE without an E/D)
    out.valid = (inp.active and inp.crz_alt and inp.kg and (ph ~= "DES" or path_h ~= nil)) and true or false
    return out
end

return M
