-- 747-400 FMC trajectory predictions without X-Plane (6-1/6-2 step 8c;
-- docs/overhaul/notes/ATA-34-61-FMC.md §47): the flight along the route
-- simulated with the performance database's models, as the FMC's
-- trajectory prediction does with the equations of motion and the
-- airplane's and engines' models (ATA34_2 p.610-611): the climb at max
-- climb thrust on the climb speeds, levelling at the climb's AT and AT OR
-- BELOW constraints; the cruise at its speed, with step climbs where the
-- glue's steps function says; the descent built back from the end of
-- descent (E/D), straight between the descent's altitude constraints and
-- at idle above the first (FCOM p.1258), at a leg's glide path angle on its
-- leg (FCOM p.1262: step 9e4), with the decelerations to the
-- transition's and restriction's speeds about DECEL_VS down before their
-- altitudes (FCOM p.1264's descent deceleration phase: step LF1), and at
-- the T/D level from the cruise speed to the descent's (p.1264's level
-- deceleration phase: step LF1). (FMC-08) The waypoints' speed
-- constraints (FCOM p.1332: at or below; p.1329, p.1393: the slower of the
-- constraint's and the performance speed): the climb's until passing their
-- waypoints (FMSPG p.3.3-17), not under VREF + 100 (FCOM p.1326); the
-- descent's at and after them (FMSPG p.3.5-3: the descent's speed line
-- above all waypoint speed constraints), with the deceleration to each
-- ending at its waypoint (FCOM p.1258: the path based on the airspeed
-- constraints too) on the constraints' line, else about DECEL_VS down.
-- Estimates there: the floor's reading, the descent's on to the E/D, the
-- deceleration's DECEL_VS without a line. T/C, T/D, S/C and each waypoint's
-- altitude, time and fuel. Estimates: the level accelerations, the
-- decelerations at idle, no wind but each phase's headwind, the descent's
-- weight the predicted one at the T/D.
--
--   local R = B747_pred_model.predict(s)   -- s: see predict
--
-- Distances in NM along the route from the present position, altitudes in
-- ft, speeds in kt (CAS) and Mach, weights and fuel in kg, times in s.

local M = setmetatable({}, {})
B747_pred_model = M

local G, KT, FT = 9.80665, 0.514444, 0.3048
local NM = 1852
-- (step 9h4b) the cruise descent's rate (fpm: VNAV's, B747.68.vnav_model.lua
-- EARLY_VS) and the engine-out driftdown's least (its EO_DD_VS)
M.CRZ_DES_VS, M.DD_VS = 1250, 300
-- (2026-11-05 review 4) the T/D's level deceleration made again when the
-- weight differs this much from the one it was made at (kg; estimate)
M.TD_KG = 5000
-- (6-1/6-2 step LF1; notes/LINE_FLIGHTS.md §1) the descent deceleration's
-- rate (fpm: FCOM p.1264, about 500)
M.DECEL_VS = 500

-- a climb or descent speed schedule at an altitude: the CAS and the Mach
-- (s: cas, mach, trans_cas below trans_alt, restr_cas below restr_alt; the
-- CAS up to the Mach, the Mach above)
function M.schedule(P, s, ft)
    local cas = s.cas
    if s.restr_cas and s.restr_alt and ft < s.restr_alt then cas = math.min(cas, s.restr_cas) end
    if s.trans_cas and s.trans_alt and ft < s.trans_alt then cas = math.min(cas, s.trans_cas) end
    local m = P.cas_to_mach(cas, ft)
    if s.mach and m > s.mach then return P.mach_to_cas(s.mach, ft), s.mach, true end
    return cas, m, false
end
-- (step LF1) the lowest of the schedule's speed limits' altitudes above ft
-- (the restriction's, the transition's), nil without one
function M.schedule_limit(s, ft)
    local lim = nil
    local function consider(c, a)
        if c and a and a > ft + 1e-6 and (not lim or a < lim) then lim = a end
    end
    consider(s.restr_cas, s.restr_alt)
    consider(s.trans_cas, s.trans_alt)
    return lim
end

-- 1 + (V/g) dV/dh at a constant CAS or Mach: the share of the energy the
-- speed takes in a climb or descent
local function energy(P, ft, cas, mach, machMode, isa)
    local function v(h)
        local m = machMode and mach or P.cas_to_mach(cas, h)
        return P.tas(m, h, isa) * KT
    end
    return 1 + v(ft) / G * (v(ft + 250) - v(ft - 250)) / (500 * FT)
end

-- the cruise's Mach at an altitude and weight: its function's (ECON, LRC:
-- they change with the weight), its CAS's, or its Mach
local function crz_mach(P, c, ft, kg)
    if c.fn then return c.fn(ft, kg) end
    if c.cas then return P.cas_to_mach(c.cas, ft) end
    return c.mach
end
M.crz_mach = crz_mach

-- (FMC-08, 2026-11-09) the descent's waypoint speed constraints in force
-- on the way to x (NM): the lowest of the one passed (sp.base) and those
-- of the waypoints before x, with incl x's own too (each at or below its
-- speed at its waypoint and after it: FCOM p.1332; FMSPG p.3.5-3); sp =
-- {base = CAS or nil, {x, spd}...} or nil, nil without one
local function spd_in_force(sp, x, incl)
    if not sp then return nil end
    local lim = sp.base
    for _, c in ipairs(sp) do
        if (c.x < x - 1e-6 or (incl and c.x <= x + 1e-6)) and (not lim or c.spd < lim) then lim = c.spd end
    end
    return lim
end
-- the nearest waypoint speed constraint before x (its x, NM), nil without
-- one
local function spd_back(sp, x)
    if not sp then return nil end
    local best = nil
    for _, c in ipairs(sp) do
        if c.x < x - 1e-6 and (not best or c.x > best) then best = c.x end
    end
    return best
end

-- the constraint's altitude a path at h keeps to it: an AT's, a window's
-- nearer bound, an AT OR ABOVE's when below it, an AT OR BELOW's when above
local function con_alt(c, h)
    if c.kind == "AT" then return c.a end
    if c.kind == "W" then return math.max(c.b, math.min(c.a, h)) end
    if c.kind == "A" and h < c.a then return c.a end
    if c.kind == "B" and h > c.a then return c.a end
    return nil
end

-- (6-1/6-2 step 9h4b) the drag (N) at a weight (kg), altitude (ft) and
-- Mach, and the operating engines: with s.eo (the engines inoperative)
-- the engine-out drag (the windmilling and trim drag) and 4 - s.eo of
-- them (two out at most: the tables')
local function perf_eo(s)
    local P, t, n = s.P, s.t, s.eo
    if not n then return function(kg, h, m) return (P.drag(t, kg, h, m)) end, 4 end
    return function(kg, h, m) return (P.eo_drag(t, n, kg, h, m)) end, 4 - math.min(n, 2)
end

-- the descent path built back from the E/D at weight kg: arrays from the
-- E/D up to the ceiling of x (NM from now), h, the time (s) and fuel (kg)
-- from there to the E/D. Straight from anchor to anchor (the E/D and the
-- constraints the path has to keep), at idle above the first; the
-- decelerations to the schedule's speeds about DECEL_VS down before their
-- altitudes at idle (step LF1: FCOM p.1264; before, level at the altitude,
-- which VNAV PTH from an idle descent overshot: s198 at 291 kt through
-- 10,000 ft), where each starts in decel {x, h} (step 8d3: the ND's
-- deceleration points, FCOM p.1149); c: each segment's target CAS on a
-- deceleration (the speed it ends at: FCOM p.1264, the target before the
-- altitude), 0 elsewhere.
-- (step 9e4) gps: the legs with a glide path angle {x0, x1 (the leg's
-- start and end), tan (the angle's), con (the start's constraint)}: on
-- such a leg the line over the ground at its angle back from the leg's end
-- (FCOM p.1262, p.1405), level back to the start from where a lower
-- constraint there is met (the level flight until the path: p.1262); no
-- deceleration on it.
-- (FMC-08, 2026-11-09) sp: the descent's waypoint speed constraints
-- (spd_in_force), each in force at and after its waypoint, the
-- deceleration to it ending there (the steps going back end at its
-- waypoint); s: each point's CAS
local function descent_path(s, kg, cons, xed, hed, gps, sp)
    local P, t, isa0 = s.P, s.t, s.isa or 0
    local drag, ne = perf_eo(s)
    local hw0 = (s.wind and s.wind.des) or 0
    local xs, hs, ts, fs = {xed}, {hed}, {0}, {0}
    -- each point's segment (from the point before, back toward the E/D):
    -- "idle" (the idle path, a line steeper than idle), "spd" (a line too
    -- shallow for idle: the A/T's SPD, FCOM p.1258; step 9b) or "decel"
    -- (step LF1: a deceleration, its target in cs)
    local ks, cs = {"idle"}, {0}
    local kind = "idle"
    local decel = {}
    local x, h, tt, ff = xed, hed, 0, 0
    -- the target at h for the way back from x: the schedule's within the
    -- waypoint speed constraints in force on the way to x (incl: x's own
    -- too, the E/D's)
    local function des_tgt(hq, xq, incl)
        local tgt, m, mm = M.schedule(P, s.des, hq)
        local lim = spd_in_force(sp, xq, incl)
        if lim and lim < tgt then return lim, P.cas_to_mach(lim, hq), false end
        return tgt, m, mm
    end
    local cas = des_tgt(h, x, true)
    local ss = {cas}
    local decelCas = 0
    local ci = #cons    -- the constraints in route order; going back from the last
    local CEIL = 45100
    local function push()
        xs[#xs + 1] = x; hs[#hs + 1] = h; ts[#ts + 1] = tt; fs[#fs + 1] = ff; ks[#ks + 1] = kind
        cs[#cs + 1] = kind == "decel" and decelCas or 0
        ss[#ss + 1] = cas
    end
    -- the glide path angle's leg x is on (its end included), or nil
    local function gp_at()
        for _, g in ipairs(gps or {}) do
            if g.x0 < x - 1e-6 and x <= g.x1 + 1e-6 then return g end
        end
        return nil
    end
    local steps = 0
    while h < CEIL and steps < 20000 do
        steps = steps + 1
        -- the next anchor going back: a constraint the idle path would miss
        while ci >= 1 and cons[ci].x >= x do ci = ci - 1 end
        local anchor, level = nil, nil
        if ci >= 1 then
            -- where the idle path from here reaches the constraint's x: a
            -- straight line to the constraint when it must keep to it;
            -- (2026-11-09) one that keeps it at this altitude (an AT, an AT
            -- OR BELOW, a window's top here: not an AT OR ABOVE) level back
            -- to it. Before, no anchor at the same altitude: KLAX's DAHJR
            -- AT 6,000 crossed at 6,963 ft on the idle path back from
            -- GADDO AT 6,000 (offline; FCOM p.1258: the path keeps the
            -- constraints)
            local c = cons[ci]
            local a = con_alt(c.c, h + (x - c.x) * 300)
            if a and a > h + 1 then
                anchor = {x = c.x, h = a}
            elseif a and a > h - 1 and c.c.kind ~= "A" and x - c.x > 1e-6 then
                level = {x = c.x}
            end
        end
        local tgt, m, machMode = des_tgt(h, x)
        -- the wind and temperature here (step 8e3: the field's), else the
        -- descent's headwind and the ISA deviation now
        local isa, hw = isa0, hw0
        if s.field then isa, hw = s.field.isa(x, h), s.field.wind(x, h, "des") end
        local v = P.tas(machMode and m or P.cas_to_mach(cas, h), h, isa) * KT
        local gs = math.max(v - hw * KT, 50)
        local gpl = gp_at()
        if gpl then
            -- (step 9e4) a glide path angle's leg: its line back, then level;
            -- where the line ends going back (the leg's start, or a lower
            -- constraint's altitude there met) found as it starts
            cas = tgt
            if not gpl.xs then
                local top = h + (x - gpl.x0) * NM / FT * gpl.tan
                gpl.xs, gpl.hs = gpl.x0, top
                local a = gpl.con and con_alt(gpl.con, top)
                if a and a < top and a > h then
                    gpl.xs, gpl.hs = x - (a - h) * FT / gpl.tan / NM, a
                end
            end
            local need, dt
            if h < gpl.hs - 1e-6 then
                local dh = math.min(250, gpl.hs - h)
                local dxg = dh * FT / gpl.tan               -- m over the ground
                dt = dxg / gs
                need = drag(kg, h, m) - kg * G * (dh * FT / (dt * v)) * energy(P, h, cas, m, machMode, isa)
                h = h + dh
                x = x - dxg / NM
                if h >= gpl.hs - 1e-6 then h, x = gpl.hs, gpl.xs end
            else
                dt = (x - gpl.x0) * NM / gs
                need = drag(kg, h, m)
                x = gpl.x0
            end
            local f = P.idle_ff(t, h, m, isa)
            if need > 0 then f = math.max(f, P.thrust_ff(t, need / ne, h, m, isa)) end
            kind = need > 0 and "spd" or "idle"
            tt = tt + dt
            ff = ff + ne * f * dt / 3600
        elseif cas < tgt - 0.5 then
            -- (back in time) a deceleration to cas, DECEL_VS down at idle
            -- (step LF1: FCOM p.1264): the model's drag (less the idle
            -- thrust) slows it less the descent's share; level when that
            -- leaves too little (estimate). (FMC-08, 2026-11-09's review)
            -- Along a constraint's line (anchor: FCOM p.1258, straight point
            -- to point after the first constraint) or level at a
            -- constraint's altitude (level), the step ending at its point;
            -- on a line too steep to slow at idle the speed kept on it.
            -- Before, DECEL_VS whatever the constraints: an AT inside a
            -- deceleration was passed off its altitude (the review's AT 6,000
            -- at 6,607 ft, AT 7,000 at 6,609 ft)
            if kind ~= "decel" then decelCas = cas end
            local mm = P.cas_to_mach(cas, h)
            local a = drag(kg, h, mm) / kg
            local dt = 5
            local v0 = P.tas(mm, h, isa) * KT          -- m/s
            local vs = M.DECEL_VS
            local xl = nil
            if level then
                vs, xl = 0, level.x
            elseif anchor then
                xl = anchor.x
                vs = (anchor.h - h) / math.max((x - xl) * NM / gs, 1) * 60
            end
            local ae = a - G * (vs * FT / 60) / math.max(v0, 1)
            if not xl and ae < 0.1 then ae, vs = a, 0 end
            if ae < 0 then ae = 0 end
            local dx = gs * dt / NM
            if xl and x - dx < xl then
                dt = (x - xl) * NM / gs
                dx = x - xl
            end
            local dv = ae * dt / KT                    -- kt TAS
            local tas = P.tas(mm, h, isa) + dv
            x = x - dx
            h = h + vs * dt / 60
            tt = tt + dt
            ff = ff + ne * P.idle_ff(t, h, mm, isa) * dt / 3600
            if xl and x <= xl + 1e-9 then
                x = xl
                if anchor then h = anchor.h end
                ci = ci - 1
            end
            -- (2026-11-09) the CAS of that true airspeed at the step's
            -- altitude, after the step (going back up, a lower CAS). Before,
            -- at the altitude before it: on a line down the true airspeed's
            -- fall at a constant CAS was taken as the drag's, about 0.08
            -- m/s2 more deceleration at 1,650 fpm (s273's second run: SYMON's
            -- 280 to 250 kt planned in 15.4 NM, which the model's drag takes
            -- to 266 kt; X-Plane 263.6 kt, MUPTT 287 for 289). Not lower
            -- than the CAS after it: where the line is too steep for the CAS
            -- to fall at idle, the CAS kept on it (as before; an estimate)
            cas = math.min(tgt, math.max(cas, P.mach_to_cas(tas / P.tas(1, h, isa), h)))
            if cas >= tgt - 0.5 then decel[#decel + 1] = {x = x, h = h} end
            kind = "decel"
        elseif level then
            -- (2026-11-09) level back to the constraint at this altitude:
            -- the drag's thrust (the A/T's SPD: FCOM p.1258); (FMC-08) to a
            -- waypoint speed constraint before it first
            cas = tgt
            local xe = level.x
            local xsp = spd_back(sp, x)
            if xsp and xsp > xe + 1e-6 then xe = xsp end
            local dist = (x - xe) * NM                -- m over the ground
            local dt = dist / gs
            local f = math.max(P.idle_ff(t, h, m, isa), P.thrust_ff(t, drag(kg, h, m) / ne, h, m, isa))
            kind = "spd"
            x = xe
            tt = tt + dt
            ff = ff + ne * f * dt / 3600
            if xe == level.x then ci = ci - 1 end
        else
            cas = tgt
            local dh = 250
            -- (step LF1) up to the schedule's next speed limit's altitude,
            -- its deceleration ending there
            local lim = M.schedule_limit(s.des, h)
            if lim and h + dh > lim then dh = math.max(lim - h, 1) end
            local sinG
            if anchor then
                -- straight to the anchor
                local dist = (x - anchor.x) * NM
                sinG = (anchor.h - h) * FT / math.max(dist, 1)
                if anchor.h - h < dh then dh = anchor.h - h end
            else
                sinG = drag(kg, h, m) / (kg * G) / energy(P, h, cas, m, machMode, isa)
            end
            sinG = math.max(sinG, 1e-4)
            local dxa = dh * FT / sinG                -- m along the air path
            local dx = dxa * gs / v / NM
            -- (FMC-08) the step ending at a waypoint speed constraint going
            -- back (its deceleration ends there; an anchor there its own end)
            local xsp = spd_back(sp, x)
            if xsp and x - dx < xsp - 1e-6 and not (anchor and math.abs(anchor.x - xsp) < 1e-6) then
                local f = math.max((x - xsp) / dx, 0)
                dh, dxa, dx = dh * f, dxa * f, x - xsp
            end
            local dt = dxa / v
            -- the thrust above idle a shallower path needs
            local need = drag(kg, h, m) - kg * G * sinG * energy(P, h, cas, m, machMode, isa)
            local f = P.idle_ff(t, h, m, isa)
            if need > 0 then f = math.max(f, P.thrust_ff(t, need / ne, h, m, isa)) end
            kind = (anchor and need > 0) and "spd" or "idle"
            h = h + dh
            x = x - dx
            tt = tt + dt
            ff = ff + ne * f * dt / 3600
            if anchor and h >= anchor.h - 1 then
                h = anchor.h
                x = anchor.x
                ci = ci - 1
            end
        end
        push()
    end
    return {x = xs, h = hs, t = ts, f = fs, k = ks, c = cs, s = ss, decel = decel}
end

-- on the descent path (index i up, arrays going back from the E/D), the x
-- where it is at altitude h, and the time and fuel from there to the E/D
local function path_at_h(dp, h)
    local hs = dp.h
    if h <= hs[1] then return dp.x[1], 0, 0 end
    for i = 2, #hs do
        if hs[i] >= h then
            local f = (h - hs[i - 1]) / math.max(hs[i] - hs[i - 1], 1e-9)
            return dp.x[i - 1] + (dp.x[i] - dp.x[i - 1]) * f, dp.t[i - 1] + (dp.t[i] - dp.t[i - 1]) * f,
                dp.f[i - 1] + (dp.f[i] - dp.f[i - 1]) * f
        end
    end
    return dp.x[#hs], dp.t[#hs], dp.f[#hs]
end

-- on the descent path, the altitude at x, and the time and fuel from x to
-- the E/D
local function path_at_x(dp, x)
    local xs = dp.x
    if x >= xs[1] then return dp.h[1], 0, 0 end
    for i = 2, #xs do
        if xs[i] <= x then
            local f = (x - xs[i - 1]) / math.min(xs[i] - xs[i - 1], -1e-9)
            return dp.h[i - 1] + (dp.h[i] - dp.h[i - 1]) * f, dp.t[i - 1] + (dp.t[i] - dp.t[i - 1]) * f,
                dp.f[i - 1] + (dp.f[i] - dp.f[i - 1]) * f
        end
    end
    return dp.h[#xs], dp.t[#xs], dp.f[#xs]
end

-- (FMC-08, 2026-11-09) on the descent path, the planned CAS at x; nil
-- after the E/D or without the path's speeds
local function path_cas_at(dp, x)
    local xs = dp and dp.s and dp.x
    if not xs or x > xs[1] + 1e-6 then return nil end
    for i = 2, #xs do
        if xs[i] <= x then
            local f = (x - xs[i - 1]) / math.min(xs[i] - xs[i - 1], -1e-9)
            return dp.s[i - 1] + (dp.s[i] - dp.s[i - 1]) * f
        end
    end
    return nil
end

-- the predictions. s:
--   P, t        the performance database and the engine type's tables
--   isa         the ISA deviation (degrees C)
--   gw, fuel    the gross weight and fuel (kg)
--   alt         the present altitude (ft)
--   cas         the present CAS (kt; the climb speed's if nil)
--   phase       "clb", "crz" or "des"
--   crz         the cruise altitude (ft)
--   clb, des    the climb's and descent's schedules {cas, mach, trans_cas,
--               trans_alt, restr_cas, restr_alt}
--   crzspd      the cruise speed {mach}, {cas} or {fn = function(h, kg) ->
--               Mach} (ECON, LRC)
--   legs        the waypoints ahead {name, dist (NM from the one before, the
--               first from the present position), con = {kind "AT", "A",
--               "B" or "W", a, b (the window's lower)} or nil, gp (step
--               9e4: the leg's glide path angle, degrees down) or nil, spd
--               (FMC-08: the waypoint's speed constraint, CAS kt) or nil}
--   ed          the E/D's index in legs (nil: none, the cruise to the end)
--   clb_last    the last leg whose constraint the climb keeps to (nil:
--               those before half the distance to the E/D or the end)
--   steps       function(h, kg) -> STEP TO (ft), the step point's weight
--               (kg), or nil: the step climbs (nil: none)
--   wind        {clb, crz, des} headwinds (kt)
--   field       nil, or the winds and temperatures along the route (step
--               8e3: B747.68.wind_model.lua's field): wind(x, h, phase) the
--               headwind (kt), isa(x, h) the ISA deviation, in place of
--               wind and isa
--   eo          (step 9h4b) nil, or the engines inoperative for the
--               engine-out data (ENG OUT active): the engine-out drag, the
--               fuel of the 4 - eo operating engines (the cruise's the
--               tables' E/O fuel flow, the climb at their share of the climb
--               thrust: CON as it, estimate)
--   crz_des     (step 9h4b) nil, or the cruise descent to the cruise
--               altitude under way (VNAV's, the airplane above it): "des"
--               at 1,250 fpm, or "dd" the engine-out driftdown (DD_VS at
--               least, CON at most), at the cruise speed
--   behind      (2026-11-09) nil, or the waypoint passed last in the
--               descent: {x (NM, 0 or less: behind the airplane), con} (its
--               constraint kept in the descent path)
--   behind_list (2026-11-11) nil, or the waypoints passed in the descent
--               with their constraints, the nearest first, each as behind:
--               all kept in the descent path (in place of behind)
--   spd_behind  (FMC-08) nil, or the lowest speed constraint (CAS kt) of
--               the waypoints passed in the descent: in force on to the E/D
--   clb_floor   (FMC-08) nil, or the least a climb's waypoint speed
--               constraint is flown at (VREF + 100: FCOM p.1326)
-- returns {pts = per leg {x, h, t, fuel, cas, mach, machMode (the speed
--   there: the climb's before the T/C, the descent's after the T/D, else
--   the cruise's)}, tc = x or nil, td = x or nil,
--   ed = x or nil, sc = {x...}, their times tc_t, td_t, ed_t, sc_t = {t...},
--   ed_i the E/D's leg, dest = {x, t, fuel}, crz = the last cruise altitude,
--   decel = {x...} the descent's decelerations ahead (where each starts),
--   lvl = x or nil, lvl_t, lvl_dd (step 9h4b: where the cruise descent
--   levels at the cruise altitude, its time; true for the driftdown's:
--   LEVEL AT)}
function M.predict(s)
    local P, t, isa = s.P, s.t, s.isa or 0
    local drag, ne = perf_eo(s)
    local wind = s.wind or {}
    local legs = s.legs
    local lx = {}
    local acc = 0
    for i, l in ipairs(legs) do acc = acc + (l.dist or 0); lx[i] = acc end
    local xEnd = acc
    local R = {pts = {}, sc = {}}
    -- (2026-11-05) the crew's planned step climbs (RTE LEGS "XXXS": FCOM
    -- p.1332), at their waypoints; they override the FMC's step climb
    -- predictions (FCOM p.1257): `steps` not used while there is one
    local plan = {}
    for i, l in ipairs(legs) do
        if l.step then plan[#plan + 1] = {x = lx[i], to = l.step} end
    end

    -- the E/D and the descent's constraints: those after the highest
    -- constraint at or above the cruise altitude ... and before the E/D
    local xed, hed
    if s.ed and legs[s.ed] and legs[s.ed].con then
        xed, hed = lx[s.ed], legs[s.ed].con.a
        if legs[s.ed].con.kind == "W" then hed = legs[s.ed].con.b end
    end

    -- the state
    local x, h, kg, tt, fuel0 = 0, s.alt, s.gw, 0, s.fuel or 0
    local burnt = 0
    local cas = s.cas or (M.schedule(P, s.clb, h))
    local phase = s.phase or (h < s.crz - 500 and "clb" or "crz")
    local crzAlt = s.crz
    local dp = nil
    local tc, td, sc = nil, nil, {}
    local tcT, tdT, scT = nil, nil, {}

    -- the climb's legs: those whose constraints the climb keeps to
    local clbLast = s.clb_last
    if not clbLast then
        local half = (xed or xEnd) / 2
        clbLast = 0
        for i = 1, #legs do if lx[i] <= half then clbLast = i end end
    end

    -- the descent's constraints: after the climb's legs and the T/C (or
    -- now), before the E/D
    local function des_cons(xfrom)
        local cons = {}
        if not xed then return cons end
        -- (2026-11-09) the waypoint passed last and its constraint behind
        -- the airplane (s.behind: the glue's, in the descent), so the path
        -- it is on stays the line from it (FCOM p.1258: point to point from
        -- the first constraint; the path fixed to the ground). Before, the
        -- leg flown became the idle path back from the next constraint at
        -- each sequencing, 229 to 469 ft higher on IRNMN2 (the perf
        -- session's KSEA-KLAX flight: the A/T's SPD at each waypoint).
        -- (2026-11-11) every waypoint passed in the descent with its
        -- constraint (s.behind_list, the glue's, the nearest first; here
        -- the farthest first, in route order): with the last one only, the
        -- path built back past a waypoint without a constraint (nothing
        -- behind then) or past the one that bent it took another shape (300
        -- random STARs offline: 126 of 1,178 sequencings moved it over 100
        -- ft, up to 26,104 ft; with all of them none of 4,658 on 1,200)
        local b = s.behind
        if s.behind_list then
            for j = #s.behind_list, 1, -1 do
                local e = s.behind_list[j]
                if e.con and e.x and e.x <= 0 then cons[#cons + 1] = {x = e.x, c = e.con} end
            end
        elseif b and b.con and b.x and b.x <= 0 then cons[1] = {x = b.x, c = b.con} end
        for i, l in ipairs(legs) do
            if l.con and i > clbLast and lx[i] > xfrom and lx[i] < xed - 0.01 then cons[#cons + 1] = {x = lx[i], c = l.con} end
        end
        return cons
    end
    -- (FMC-08) the descent's waypoint speed constraints (spd_in_force):
    -- the one passed in the descent (s.spd_behind, the glue's), those after
    -- the climb's legs and the T/C (or now) to the E/D (its own too)
    local function des_spds(xfrom)
        local sp = {base = s.spd_behind}
        if not xed then return sp end
        for i, l in ipairs(legs) do
            if l.spd and i > clbLast and lx[i] > xfrom and lx[i] <= xed + 0.01 then sp[#sp + 1] = {x = lx[i], spd = l.spd} end
        end
        return sp
    end
    local spNow = nil
    -- (FMC-08) the climb's waypoint speed constraint in force at xq: the
    -- lowest of the climb's legs' not passed there (until passing each:
    -- FMSPG p.3.3-17), not under s.clb_floor (VREF + 100: FCOM p.1326),
    -- nil without one
    local function clb_spd_at(xq)
        local lim = nil
        for i = 1, math.min(clbLast, #legs) do
            local l = legs[i]
            if l.spd and lx[i] > xq - 1e-6 and (not lim or l.spd < lim) then lim = l.spd end
        end
        if lim and s.clb_floor then lim = math.max(lim, s.clb_floor) end
        return lim
    end
    -- (step 9e4) the descent's legs with a glide path angle (from the
    -- waypoint before), to the E/D
    local function des_gps(xfrom)
        local gps = {}
        if not xed then return gps end
        for i, l in ipairs(legs) do
            if l.gp and l.gp > 0.5 and i > clbLast and lx[i] > xfrom and lx[i] <= xed + 0.01 then
                gps[#gps + 1] = {x0 = i > 1 and lx[i - 1] or 0, x1 = lx[i], tan = math.tan(math.rad(l.gp)),
                    con = i > 1 and legs[i - 1].con or nil}
            end
        end
        return gps
    end

    -- record each waypoint as the state passes it
    local nextLeg = 1
    local function passed(x0, h0, t0, b0, x1, h1, t1, b1)
        while nextLeg <= #legs and lx[nextLeg] <= x1 + 1e-9 do
            local f = (lx[nextLeg] - x0) / math.max(x1 - x0, 1e-9)
            f = math.max(0, math.min(1, f))
            R.pts[nextLeg] = {x = lx[nextLeg], h = h0 + (h1 - h0) * f, t = t0 + (t1 - t0) * f,
                fuel = fuel0 - (b0 + (b1 - b0) * f)}
            nextLeg = nextLeg + 1
        end
    end

    -- climb: the next level-off (an AT or AT OR BELOW ahead), the climb's
    -- speeds; to CRZ ALT (T/C) or into the descent path (a short flight)
    local function cap_ahead()
        for i = 1, math.min(clbLast, #legs) do
            local l = legs[i]
            if lx[i] > x and l.con and (l.con.kind == "AT" or l.con.kind == "B" or l.con.kind == "W") then
                local a = l.con.a
                if a < crzAlt and a > h - 1 then return a, lx[i] end
            end
        end
        return nil
    end

    local function step_state(dx, dh, dt, f)
        local x0, h0, t0, b0 = x, h, tt, burnt
        x, h, tt, burnt = x + dx, h + dh, tt + dt, burnt + f
        kg = s.gw - burnt
        passed(x0, h0, t0, b0, x, h, tt, burnt)
    end

    -- the descent path (once, at the weight reaching it: two passes)
    local function build_dp(wkg, xfrom)
        if not xed then return nil end
        spNow = des_spds(xfrom)
        return descent_path(s, wkg, des_cons(xfrom), xed, hed, des_gps(xfrom), spNow)
    end
    local estKg = s.gw * 0.85
    local guard = 0

    local function climb_to(target)
        -- climb at max climb thrust to target, stopping where the descent
        -- path is reached; "unable" where the climb ends below it
        while h < target - 1 and guard < 200000 do
            guard = guard + 1
            if dp then
                local xtd = path_at_h(dp, h)
                if x >= xtd then return "des" end
            end
            local tgt, m, machMode = M.schedule(P, s.clb, h)
            -- (FMC-08) within the climb's waypoint speed constraint here
            local lim = clb_spd_at(x)
            if lim and lim < tgt then tgt, m, machMode = lim, P.cas_to_mach(lim, h), false end
            local mm = machMode and m or P.cas_to_mach(cas, h)
            local isa, hw = isa, wind.clb or 0
            if s.field then isa, hw = s.field.isa(x, h), s.field.wind(x, h, "clb") end
            local v = P.tas(mm, h, isa) * KT
            local gs = math.max(v - hw * KT, 50)
            local thr = P.climb_thrust(t, h) * ne / 4
            local dr = drag(kg, h, mm)
            local ffl = ne * P.thrust_ff(t, thr / ne, h, mm, isa)
            if cas < tgt - 0.5 then
                -- a level acceleration to the schedule's CAS
                local dt = 5
                local tas = P.tas(mm, h, isa) + (thr - dr) / kg * dt / KT
                cas = math.min(tgt, P.mach_to_cas(tas / P.tas(1, h, isa), h))
                step_state(gs * dt / NM, 0, dt, ffl * dt / 3600)
            else
                cas = tgt
                local sinG = (thr - dr) / (kg * G) / energy(P, h, cas, mm, machMode, isa)
                if sinG <= 1e-4 then return "unable" end
                local dh = math.min(250, target - h)
                local dxa = dh * FT / sinG
                local dt = dxa / v
                step_state(dxa * gs / v / NM, dh, dt, ffl * dt / 3600)
            end
        end
        return "level"
    end

    -- (6-1/6-2 step LF1) the T/D's level deceleration from the cruise speed
    -- at hc to the descent's (FCOM p.1264's level deceleration phase): its
    -- distance (NM), time (s) and fuel (kg) at idle; none when the cruise is
    -- not faster. The T/D that much before where the path reaches hc
    -- (before, the descent from the T/D at the cruise speed: s198)
    local function td_decel(hc, xref)
        local m = crz_mach(P, s.crzspd or {mach = 0.84}, hc, kg)
        local cas0 = P.mach_to_cas(m, hc)
        local cas1 = M.schedule(P, s.des, hc)
        -- (FMC-08) a waypoint speed constraint in force at the path's top;
        -- (2026-11-09's review) the path's planned CAS there too, where a
        -- deceleration to a constraint just after the T/D reaches back up
        -- to the cruise altitude (before, the schedule's: the airplane at
        -- the path 17 kt over its plan, the target the constraint's)
        local lim = spd_in_force(spNow, xref, false)
        if lim and lim < cas1 then cas1 = lim end
        local pc = path_cas_at(dp, xref)
        if pc and pc < cas1 then cas1 = pc end
        if cas0 <= cas1 + 0.5 then return 0, 0, 0 end
        -- the wind and temperature at the path's top (step 8e3: the
        -- field's), else the cruise's headwind and the ISA deviation now
        local isa, hw = isa, wind.crz or 0
        if s.field then isa, hw = s.field.isa(xref, hc), s.field.wind(xref, hc, "crz") end
        local dx, dt, f, c, n = 0, 0, 0, cas0, 0
        while c > cas1 + 0.5 and n < 400 do
            n = n + 1
            local mm = P.cas_to_mach(c, hc)
            local tas = P.tas(mm, hc, isa)              -- kt
            local gs = math.max((tas - hw) * KT, 50)
            local step = 2
            dx, dt = dx + gs * step / NM, dt + step
            f = f + ne * P.idle_ff(t, hc, mm, isa) * step / 3600
            tas = tas - drag(kg, hc, mm) / kg * step / KT
            c = P.mach_to_cas(tas / P.tas(1, hc, isa), hc)
        end
        return dx, dt, f
    end
    -- the deceleration kept for the altitude and the weight within TD_KG
    -- (2026-11-05 review 4: before, the first weight's for the whole cruise:
    -- its drag over the weight)
    local tdCache = {}
    local function td_x(hc)
        local xp = path_at_h(dp, hc)
        local c = tdCache[hc]
        if not c or math.abs(c.kg - kg) > M.TD_KG then
            c = {kg = kg, d = (td_decel(hc, xp))}
            tdCache[hc] = c
        end
        return xp - c.d
    end

    -- (2026-11-05 review 3) DES NOW below the path: level to the path,
    -- no step climbs
    local desNow = false
    -- (2026-11-05 review 4) a step the airplane could not fly (its climb
    -- "unable"): no more steps this cruise
    local noStep = false
    local function cruise_until(xstop, hcur, clbLevel)
        -- level at hcur to xstop (or the T/D, a step point)
        -- the next planned step ahead above hcur (2026-11-05)
        local pnext = nil
        for _, p in ipairs(plan) do
            if p.x > x + 1e-6 and p.to > hcur + 1 then pnext = p break end
        end
        while x < xstop - 1e-6 and guard < 200000 do
            guard = guard + 1
            local m
            local isa, hw = isa, wind.crz or 0
            if clbLevel then
                -- (2026-11-09's review) a climb's level segment at an
                -- altitude constraint: VNAV PTH holds the climb's command
                -- speed there (FCOM p.1255), within the climb's waypoint
                -- constraints (FMC-08), in the climb's wind. Before, the
                -- cruise's Mach at that altitude (M.85 at 5,000 ft: 519 kt
                -- CAS): the ETAs after it early, its fuel high
                local cas, mc, machMode = M.schedule(P, s.clb, hcur)
                local lim = clb_spd_at(x)
                if lim and lim < cas then cas, machMode = lim, false end
                m = machMode and mc or P.cas_to_mach(cas, hcur)
                hw = wind.clb or 0
                if s.field then isa, hw = s.field.isa(x, hcur), s.field.wind(x, hcur, "clb") end
            else
                m = crz_mach(P, s.crzspd, hcur, kg)
                if s.field then isa, hw = s.field.isa(x, hcur), s.field.wind(x, hcur, "crz") end
            end
            local v = P.tas(m, hcur, isa) * KT
            local gs = math.max(v - hw * KT, 50)
            local ff = s.eo and ne * P.eo_cruise_ff(t, s.eo, kg, hcur, m, isa) or 4 * P.cruise_ff(t, kg, hcur, m, isa)
            local dt = 60
            local dx = gs * dt / NM
            local lim = xstop
            if dp then lim = math.min(lim, td_x(hcur)) end
            if pnext and phase == "crz" and not desNow then lim = math.min(lim, pnext.x) end
            if x + dx > lim then dx = lim - x; dt = dx * NM / gs end
            if dx <= 0 then
                -- (2026-11-11 review) the T/D for this altitude at or behind
                -- x: the descent starts here. Before, "end" without moving,
                -- and the climb's level segment at an AT OR BELOW repeated
                -- it forever: the FMC's plugin froze (a SID's FL150 at 55 NM
                -- on a 92 NM route, CRZ FL250)
                if dp and x >= td_x(hcur) - 1e-6 then return "des" end
                break
            end
            step_state(dx, 0, dt, ff * dt / 3600)
            if dp and x >= td_x(hcur) - 1e-6 then return "des" end
            if pnext and phase == "crz" and not desNow and x >= pnext.x - 1e-6 then return "step", pnext.to end
            if s.steps and phase == "crz" and not desNow and not noStep and #plan == 0 then
                local to, w = s.steps(hcur, kg)
                local xtd = dp and path_at_h(dp, hcur) or math.huge
                if to and to > hcur and w and kg <= w and xtd - x > 200 then return "step", to end
            end
        end
        return "end"
    end

    -- (step 9h4b) the cruise descent under way down to crzAlt (s.crz_des):
    -- at the cruise speed, 1,250 fpm with the thrust it needs, at least
    -- idle (VNAV's: FCOM p.1257, FMSPG p.3.5-5); the driftdown the speed
    -- at crzAlt as a Mach and CON on the operating engines, at least DD_VS
    -- down (FCOM p.1268): CON the climb thrust's share (estimate) scaled to
    -- the drag at crzAlt, where the driftdown levels at the maximum (the
    -- tables' level off: estimate). Stopping where the descent path is
    -- reached
    local function crz_descent()
        local dd = s.crz_des == "dd"
        local mDD = dd and crz_mach(P, s.crzspd, crzAlt, kg) or nil
        local scale = dd and drag(kg, crzAlt, mDD) / (P.climb_thrust(t, crzAlt) * ne / 4) or 1
        local machMode = dd or not s.crzspd.cas
        while h > crzAlt + 1 and guard < 200000 do
            guard = guard + 1
            if dp and x >= (path_at_h(dp, h)) - 1e-6 then return "des" end
            local dh = math.min(250, h - crzAlt)
            local hm = h - dh / 2
            local m = mDD or crz_mach(P, s.crzspd, hm, kg)
            local isa, hw = isa, wind.crz or 0
            if s.field then isa, hw = s.field.isa(x, hm), s.field.wind(x, hm, "crz") end
            local v = P.tas(m, hm, isa) * KT
            local gs = math.max(v - hw * KT, 50)
            local ef = energy(P, hm, P.mach_to_cas(m, hm), m, machMode, isa)
            local d = drag(kg, hm, m)
            -- the rate down (m/s) and the thrust it takes (N)
            local down = M.CRZ_DES_VS * FT / 60
            if dd then
                local con = P.climb_thrust(t, hm) * ne / 4 * scale
                down = math.max((d - con) * v / (kg * G * ef), M.DD_VS * FT / 60)
            end
            local thr = d - kg * G * ef * down / v
            local f = P.idle_ff(t, hm, m, isa)
            if thr > 0 then f = math.max(f, P.thrust_ff(t, thr / ne, hm, m, isa)) end
            local dt = dh * FT / down
            step_state(gs * dt / NM, -dh, dt, ne * f * dt / 3600)
        end
        return "level"
    end

    local tcPrev = 0
    local startDes = false
    local lvl, lvlT = nil, nil
    for pass = 1, 2 do
        x, h, kg, tt, burnt, nextLeg = 0, s.alt, s.gw, 0, 0, 1
        cas = s.cas or (M.schedule(P, s.clb, h))
        phase = s.phase or (h < s.crz - 500 and "clb" or "crz")
        R.pts, sc, tc, td = {}, {}, nil, nil
        scT, tcT, tdT = {}, nil, nil
        lvl, lvlT = nil, nil
        crzAlt = s.crz
        guard = 0
        dp = build_dp(estKg, tcPrev)
        startDes = phase == "des" and dp ~= nil
        -- (2026-11-05 review 3) the descent phase below the path with its
        -- T/D still ahead (DES NOW before the T/D: the path ahead is above
        -- the airplane, up to its ceiling): level at the present altitude to
        -- where the path comes down to it (the T/D), then the path; within
        -- the descent (the T/D behind) along the path as before. Before, the path's
        -- altitudes and times from here (FL451 at the next waypoints, the
        -- destination 13 min early from FL350, T/D 130 NM ahead). DES NOW's
        -- shallow descent to the path (FCOM: about 1,250 fpm) is not
        -- modelled: level to the path (estimate)
        desNow, noStep = false, false
        if startDes and (path_at_x(dp, 0)) > h + 50 and td_x(h) > 1 then
            startDes = false
            phase = "crz"
            desNow = true
        end
        if startDes then
            -- on the descent path now: from here to the E/D along it
        else
            if phase == "clb" then
                while true do
                    local cap, xcap = cap_ahead()
                    local target = cap or crzAlt
                    local r = climb_to(target)
                    if r == "des" then phase = "des" break end
                    if r == "unable" then crzAlt = h break end
                    if cap and h >= cap - 1 and h < crzAlt - 1 then
                        -- level at the constraint to its waypoint
                        local x0 = x
                        local r2 = cruise_until(xcap, h, true)
                        if r2 == "des" then phase = "des" break end
                        -- (2026-11-11 review) no way forward: out of the
                        -- climb rather than the same segment again
                        if x <= x0 + 1e-6 then break end
                    else
                        break
                    end
                end
                if phase ~= "des" then tc, tcT = x, tt; phase = "crz" end
            end
            -- (step 9h4b) the cruise descent under way first, to its level
            -- off at crzAlt (LEVEL AT)
            if phase == "crz" and s.crz_des and h > crzAlt + 50 then
                if crz_descent() == "des" then phase = "des" else lvl, lvlT = x, tt end
            end
            local hcur = h
            while phase == "crz" and guard < 200000 do
                local r, to = cruise_until(xEnd, hcur)
                if r == "step" then
                    local n, h0 = #sc + 1, h
                    sc[n], scT[n] = x, tt
                    phase = "sc"
                    local rr = climb_to(to)
                    phase = "crz"
                    hcur = h
                    if rr == "des" then phase = "des" break end
                    -- (2026-11-05 review 4) a step the airplane cannot fly
                    -- (no climb's thrust left below STEP TO): no more steps
                    -- this cruise, no S/C where it did not climb. Before,
                    -- tried again at every minute of the cruise, an S/C each
                    if rr == "unable" then
                        noStep = true
                        if h < h0 + 1 then sc[n], scT[n] = nil, nil end
                    end
                elseif r == "des" then
                    phase = "des"
                else
                    break
                end
            end
            crzAlt = hcur
        end
        local kgTD = kg
        if dp and phase == "des" then
            -- the T/D, then the descent path to the E/D
            if not startDes then
                local xtd = path_at_h(dp, h)
                -- (step LF1) from the cruise: the T/D at the level
                -- deceleration's start, the deceleration on to where the
                -- path leaves the cruise altitude
                local dxd, dtd, fd = 0, 0, 0
                if math.abs(h - crzAlt) < 50 then dxd, dtd, fd = td_decel(h, xtd) end
                R.td_decel = dxd
                if x < xtd - dxd then x = xtd - dxd end
                td, tdT = x, tt
                if x < xtd and dxd > 0 then
                    local frac = (xtd - x) / dxd
                    step_state(xtd - x, 0, dtd * frac, fd * frac)
                end
            end
            local _, t0, f0 = path_at_x(dp, x)
            local tbase, bbase = tt, burnt
            for i = nextLeg, #legs do
                if lx[i] <= xed + 1e-9 then
                    local hh, ti, fi = path_at_x(dp, lx[i])
                    R.pts[i] = {x = lx[i], h = hh, t = tbase + (t0 - ti), fuel = fuel0 - (bbase + (f0 - fi))}
                    nextLeg = i + 1
                end
            end
            tt, burnt = tbase + t0, bbase + f0
            x, h = xed, hed
            kg = s.gw - burnt
        end
        estKg = kgTD
        tcPrev = tc or 0
        if not dp then break end
    end
    -- after the E/D (or without one): the rest as the last state
    for i = nextLeg, #legs do
        R.pts[i] = {x = lx[i], h = h, t = tt, fuel = fuel0 - burnt}
    end
    R.tc, R.td, R.ed, R.sc, R.crz = tc, td, xed, sc, crzAlt
    R.tc_t, R.td_t, R.sc_t = tcT, tdT, scT
    R.lvl, R.lvl_t, R.lvl_dd = lvl, lvlT, (lvl and s.crz_des == "dd") or nil
    -- the deceleration points ahead on the descent (after the T/D or now)
    R.decel = {}
    if dp and xed then
        for _, d in ipairs(dp.decel) do
            if d.h < crzAlt - 1 and d.x > math.max(td or 0, 0) and d.x <= xed then R.decel[#R.decel + 1] = d.x end
        end
    end
    R.ed_t = xed and tt or nil
    R.ed_i = xed and s.ed or nil
    -- each waypoint's speed by where it is; (FMC-08) within the waypoint
    -- speed constraints in force there (the climb's until passing, the
    -- descent's at and after: a waypoint's own there too)
    local inClb = (s.phase or "clb") == "clb"
    for _, p in ipairs(R.pts) do
        local cas, mach, mm
        local lim = nil
        if inClb and ((tc and p.x < tc - 0.01) or (not tc and td and p.x < td - 0.01)) then
            cas, mach, mm = M.schedule(P, s.clb, p.h)
            lim = clb_spd_at(p.x)
        elseif td and p.x > td + 0.01 or (startDes and xed and p.x <= xed) then
            cas, mach, mm = M.schedule(P, s.des, p.h)
            -- (to the E/D: not the missed approach's)
            if xed and p.x <= xed + 1e-6 then
                lim = spd_in_force(spNow, p.x, true)
                -- (2026-11-09) inside a deceleration the path's planned
                -- CAS there, where slower (a waypoint on the way to a
                -- constraint's speed, the transition's)
                local ps = path_cas_at(dp, p.x)
                if ps and ps < math.min(lim or cas, cas) - 0.5 then lim = ps end
            end
        else
            mach = crz_mach(P, s.crzspd, p.h, s.gw - (fuel0 - p.fuel))
            cas, mm = P.mach_to_cas(mach, p.h), not s.crzspd.cas
            if s.crzspd.cas then cas = s.crzspd.cas end
        end
        if lim and lim < cas then cas, mach, mm = lim, P.cas_to_mach(lim, p.h), false end
        p.cas, p.mach, p.machMode = cas, mach, mm
    end
    R.dest = {x = xEnd, t = tt, fuel = fuel0 - burnt}
    R.dp = dp
    return R
end

-- (FIX INFO's ETA, ALT and PRED ETA-ALT, 2026-11-04: FCOM p.1358-1359,
-- FMSPG p.168-169) the predictions as a profile along the route: {x, h, t}
-- (NM from the present position, ft, s from now) by x, from the present
-- position (s.alt), the T/C at CRZ ALT (s.crz), each S/C at the altitude of
-- the waypoint before it, the T/D at the last cruise altitude, the E/D and
-- each waypoint ahead; straight between them (estimate: the climbs and
-- descents between those points are not straight)
function M.profile(R, s)
    local pts = {{x = 0, h = s.alt or 0, t = 0}}
    local function add(x, h, t) if x and h and t then pts[#pts + 1] = {x = x, h = h, t = t} end end
    for _, p in pairs(R.pts or {}) do add(p.x, p.h, p.t) end
    local function h_before(x)
        local best
        for _, p in pairs(R.pts or {}) do
            if p.x <= x and (not best or p.x > best.x) then best = p end
        end
        return best and best.h
    end
    if R.tc then add(R.tc, s.crz, R.tc_t) end
    for k, x in ipairs(R.sc or {}) do
        local h = h_before(x)
        if R.tc and h and x > R.tc then add(x, h, R.sc_t and R.sc_t[k]) end
    end
    if R.td then add(R.td, R.crz, R.td_t) end
    table.sort(pts, function(a, b) return a.x < b.x end)
    local out = {}
    for _, p in ipairs(pts) do
        local q = out[#out]
        if not q or p.x > q.x + 1e-6 then out[#out + 1] = p end
    end
    return out
end
-- the altitude and the time at x along the profile, nil past its end
function M.profile_at(prof, x)
    for i = 2, #prof do
        local a, b = prof[i - 1], prof[i]
        if x <= b.x then
            local f = (b.x > a.x) and (x - a.x) / (b.x - a.x) or 1
            if f < 0 then f = 0 end
            return a.h + (b.h - a.h) * f, a.t + (b.t - a.t) * f
        end
    end
    return nil
end
-- where the profile first reaches altitude h ahead (climbing or
-- descending), nil if it does not
function M.profile_alt(prof, h)
    for i = 2, #prof do
        local a, b = prof[i - 1], prof[i]
        if a.h ~= b.h and (a.h - h) * (b.h - h) <= 0 and not (i == 2 and a.h == h) then
            return a.x + (b.x - a.x) * (h - a.h) / (b.h - a.h)
        end
    end
    return nil
end
-- where the profile reaches the time t (s from now) ahead, nil if it does
-- not
function M.profile_time(prof, t)
    if t <= 0 then return nil end
    for i = 2, #prof do
        local a, b = prof[i - 1], prof[i]
        if t <= b.t and b.t > a.t then
            return a.x + (b.x - a.x) * (t - a.t) / (b.t - a.t)
        end
    end
    return nil
end


-- (OFFPATH DES, 2026-11-04: FCOM p.1398-1399; FMSPG p.191-194) the
-- distance (NM) an idle descent direct to a fix needs from altitude h0
-- down to the fix's altitude hf, on the DES page's speeds (s.des: the
-- schedule, its transition and restriction) with the fix's speed (cas_f)
-- as the speed below just above it (FMSPG p.193: crossing the fix at its
-- speed and altitude), in the descent's headwind (s.wind.des; not the
-- route's winds: the descent is off the route), at weight kg; clean, or
-- with full speedbrakes (sb: the drag SB_DRAG times, estimate from FCTM
-- p.138-139's idle descent rates with and without them: 2,800/4,300 fpm at
-- .83/340 kt, 1,300/2,100 at 250 kt, 1,200/1,900 at VREF30+100, 1.5 to 1.6
-- times). nil when h0 is not above hf
M.SB_DRAG = 1.58
local OFFPATH_X = 2000
function M.offpath(s, kg, h0, hf, cas_f, sb)
    if not (s and h0 and hf) or h0 <= hf + 1 then return nil end
    local o = {}
    for k, v in pairs(s) do o[k] = v end
    o.field = nil
    if sb then
        local P0 = s.P
        o.P = setmetatable({
            drag = function(t, w, h, m) return P0.drag(t, w, h, m) * M.SB_DRAG end,
            eo_drag = function(t, n, w, h, m) return P0.eo_drag(t, n, w, h, m) * M.SB_DRAG end,
        }, {__index = P0})
    end
    if cas_f and cas_f > 0 and s.des then
        local d = {}
        for k, v in pairs(s.des) do d[k] = v end
        d.restr_cas, d.restr_alt = cas_f, hf + 1
        o.des = d
    end
    local dp = descent_path(o, kg, {}, OFFPATH_X, hf, nil)
    local x = path_at_h(dp, h0)
    if not x then return nil end
    return OFFPATH_X - x
end

return M
