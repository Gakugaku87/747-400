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
-- transition's and restriction's speeds in level flight. T/C, T/D, S/C and
-- each waypoint's altitude, time and fuel. Estimates: the level
-- accelerations and decelerations, no wind but each phase's headwind, the
-- descent's weight the predicted one at the T/D.
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
-- constraints the path has to keep), at idle above the first; level
-- decelerations to the schedule's speeds (estimates), where each starts in
-- decel {x, h} (step 8d3: the ND's deceleration points, FCOM p.1149).
-- (step 9e4) gps: the legs with a glide path angle {x0, x1 (the leg's
-- start and end), tan (the angle's), con (the start's constraint)}: on
-- such a leg the line over the ground at its angle back from the leg's end
-- (FCOM p.1262, p.1405), level back to the start from where a lower
-- constraint there is met (the level flight until the path: p.1262); no
-- deceleration on it
local function descent_path(s, kg, cons, xed, hed, gps)
    local P, t, isa0 = s.P, s.t, s.isa or 0
    local drag, ne = perf_eo(s)
    local hw0 = (s.wind and s.wind.des) or 0
    local xs, hs, ts, fs = {xed}, {hed}, {0}, {0}
    -- each point's segment (from the point before, back toward the E/D):
    -- "idle" (the idle path, a level deceleration, a line steeper than
    -- idle) or "spd" (a line too shallow for idle: the A/T's SPD, FCOM
    -- p.1258; step 9b)
    local ks = {"idle"}
    local kind = "idle"
    local decel = {}
    local x, h, tt, ff = xed, hed, 0, 0
    local cas = M.schedule(P, s.des, h)
    local ci = #cons    -- the constraints in route order; going back from the last
    local CEIL = 45100
    local function push() xs[#xs + 1] = x; hs[#hs + 1] = h; ts[#ts + 1] = tt; fs[#fs + 1] = ff; ks[#ks + 1] = kind end
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
        local anchor = nil
        if ci >= 1 then
            -- where the idle path from here reaches the constraint's x: a
            -- straight line to the constraint when it must keep to it
            local c = cons[ci]
            local a = con_alt(c.c, h + (x - c.x) * 300)
            if a and a > h then anchor = {x = c.x, h = a} end
        end
        local tgt, m, machMode = M.schedule(P, s.des, h)
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
            -- (back in time) a level deceleration to cas: idle, the model's
            -- drag (less the idle thrust) slows it
            local mm = P.cas_to_mach(cas, h)
            local a = drag(kg, h, mm) / kg
            local dt = 5
            local dv = a * dt / KT                     -- kt TAS
            local tas = P.tas(mm, h, isa) + dv
            cas = math.min(tgt, P.mach_to_cas(tas / P.tas(1, h, isa), h))
            x = x - gs * dt / NM
            tt = tt + dt
            ff = ff + ne * P.idle_ff(t, h, mm, isa) * dt / 3600
            if cas >= tgt - 0.5 then decel[#decel + 1] = {x = x, h = h} end
            kind = "idle"
        else
            cas = tgt
            local dh = 250
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
            local dt = dxa / v
            -- the thrust above idle a shallower path needs
            local need = drag(kg, h, m) - kg * G * sinG * energy(P, h, cas, m, machMode, isa)
            local f = P.idle_ff(t, h, m, isa)
            if need > 0 then f = math.max(f, P.thrust_ff(t, need / ne, h, m, isa)) end
            kind = (anchor and need > 0) and "spd" or "idle"
            h = h + dh
            x = x - dxa * gs / v / NM
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
    return {x = xs, h = hs, t = ts, f = fs, k = ks, decel = decel}
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
--               9e4: the leg's glide path angle, degrees down) or nil}
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
        for i, l in ipairs(legs) do
            if l.con and i > clbLast and lx[i] > xfrom and lx[i] < xed - 0.01 then cons[#cons + 1] = {x = lx[i], c = l.con} end
        end
        return cons
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
        return descent_path(s, wkg, des_cons(xfrom), xed, hed, des_gps(xfrom))
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

    local function cruise_until(xstop, hcur)
        -- level at hcur to xstop (or the T/D, a step point)
        while x < xstop - 1e-6 and guard < 200000 do
            guard = guard + 1
            local m = crz_mach(P, s.crzspd, hcur, kg)
            local isa, hw = isa, wind.crz or 0
            if s.field then isa, hw = s.field.isa(x, hcur), s.field.wind(x, hcur, "crz") end
            local v = P.tas(m, hcur, isa) * KT
            local gs = math.max(v - hw * KT, 50)
            local ff = s.eo and ne * P.eo_cruise_ff(t, s.eo, kg, hcur, m, isa) or 4 * P.cruise_ff(t, kg, hcur, m, isa)
            local dt = 60
            local dx = gs * dt / NM
            local lim = xstop
            if dp then lim = math.min(lim, (path_at_h(dp, hcur))) end
            if x + dx > lim then dx = lim - x; dt = dx * NM / gs end
            if dx <= 0 then break end
            step_state(dx, 0, dt, ff * dt / 3600)
            if dp and x >= (path_at_h(dp, hcur)) - 1e-6 then return "des" end
            if s.steps and phase == "crz" then
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
                        local r2 = cruise_until(xcap, h)
                        if r2 == "des" then phase = "des" break end
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
                    sc[#sc + 1], scT[#sc + 1] = x, tt
                    phase = "sc"
                    local rr = climb_to(to)
                    phase = "crz"
                    hcur = h
                    if rr == "des" then phase = "des" break end
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
                if x < xtd then x = xtd end
                td, tdT = x, tt
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
    -- each waypoint's speed by where it is
    local inClb = (s.phase or "clb") == "clb"
    for _, p in ipairs(R.pts) do
        local cas, mach, mm
        if inClb and ((tc and p.x < tc - 0.01) or (not tc and td and p.x < td - 0.01)) then
            cas, mach, mm = M.schedule(P, s.clb, p.h)
        elseif td and p.x > td + 0.01 or (startDes and xed and p.x <= xed) then
            cas, mach, mm = M.schedule(P, s.des, p.h)
        else
            mach = crz_mach(P, s.crzspd, p.h, s.gw - (fuel0 - p.fuel))
            cas, mm = P.mach_to_cas(mach, p.h), not s.crzspd.cas
            if s.crzspd.cas then cas = s.crzspd.cas end
        end
        p.cas, p.mach, p.machMode = cas, mach, mm
    end
    R.dest = {x = xEnd, t = tt, fuel = fuel0 - burnt}
    R.dp = dp
    return R
end

return M
