-- 747-400 FMC trajectory predictions without X-Plane (6-1/6-2 step 8c;
-- docs/overhaul/notes/ATA-34-61-FMC.md §47): the flight along the route
-- simulated with the performance database's models, as the FMC's
-- trajectory prediction does with the equations of motion and the
-- airplane's and engines' models (ATA34_2 p.610-611): the climb at max
-- climb thrust on the climb speeds, levelling at the climb's AT and AT OR
-- BELOW constraints; the cruise at its speed, with step climbs where the
-- glue's steps function says; the descent built back from the end of
-- descent (E/D), straight between the descent's altitude constraints and
-- at idle above the first (FCOM p.1258), with the decelerations to the
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

-- the constraint's altitude a path at h keeps to it: an AT's, a window's
-- nearer bound, an AT OR ABOVE's when below it, an AT OR BELOW's when above
local function con_alt(c, h)
    if c.kind == "AT" then return c.a end
    if c.kind == "W" then return math.max(c.b, math.min(c.a, h)) end
    if c.kind == "A" and h < c.a then return c.a end
    if c.kind == "B" and h > c.a then return c.a end
    return nil
end

-- the descent path built back from the E/D at weight kg: arrays from the
-- E/D up to the ceiling of x (NM from now), h, the time (s) and fuel (kg)
-- from there to the E/D. Straight from anchor to anchor (the E/D and the
-- constraints the path has to keep), at idle above the first; level
-- decelerations to the schedule's speeds (estimates)
local function descent_path(s, kg, cons, xed, hed)
    local P, t, isa = s.P, s.t, s.isa or 0
    local hw = (s.wind and s.wind.des) or 0
    local xs, hs, ts, fs = {xed}, {hed}, {0}, {0}
    local x, h, tt, ff = xed, hed, 0, 0
    local cas = M.schedule(P, s.des, h)
    local ci = #cons    -- the constraints in route order; going back from the last
    local CEIL = 45100
    local function push() xs[#xs + 1] = x; hs[#hs + 1] = h; ts[#ts + 1] = tt; fs[#fs + 1] = ff end
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
        local v = P.tas(machMode and m or P.cas_to_mach(cas, h), h, isa) * KT
        local gs = math.max(v - hw * KT, 50)
        if cas < tgt - 0.5 then
            -- (back in time) a level deceleration to cas: idle, the model's
            -- drag (less the idle thrust) slows it
            local mm = P.cas_to_mach(cas, h)
            local a = P.drag(t, kg, h, mm) / kg
            local dt = 5
            local dv = a * dt / KT                     -- kt TAS
            local tas = P.tas(mm, h, isa) + dv
            cas = math.min(tgt, P.mach_to_cas(tas / P.tas(1, h, isa), h))
            x = x - gs * dt / NM
            tt = tt + dt
            ff = ff + 4 * P.idle_ff(t, h, mm, isa) * dt / 3600
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
                sinG = P.drag(t, kg, h, m) / (kg * G) / energy(P, h, cas, m, machMode, isa)
            end
            sinG = math.max(sinG, 1e-4)
            local dxa = dh * FT / sinG                -- m along the air path
            local dt = dxa / v
            -- the thrust above idle a shallower path needs
            local need = P.drag(t, kg, h, m) - kg * G * sinG * energy(P, h, cas, m, machMode, isa)
            local f = P.idle_ff(t, h, m, isa)
            if need > 0 then f = math.max(f, P.thrust_ff(t, need / 4, h, m, isa)) end
            h = h + dh
            x = x - dxa * gs / v / NM
            tt = tt + dt
            ff = ff + 4 * f * dt / 3600
            if anchor and h >= anchor.h - 1 then
                h = anchor.h
                x = anchor.x
                ci = ci - 1
            end
        end
        push()
    end
    return {x = xs, h = hs, t = ts, f = fs}
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
--               "B" or "W", a, b (the window's lower)} or nil}
--   ed          the E/D's index in legs (nil: none, the cruise to the end)
--   clb_last    the last leg whose constraint the climb keeps to (nil:
--               those before half the distance to the E/D or the end)
--   steps       function(h, kg) -> STEP TO (ft), the step point's weight
--               (kg), or nil: the step climbs (nil: none)
--   wind        {clb, crz, des} headwinds (kt)
-- returns {pts = per leg {x, h, t, fuel, cas, mach, machMode (the speed
--   there: the climb's before the T/C, the descent's after the T/D, else
--   the cruise's)}, tc = x or nil, td = x or nil,
--   ed = x or nil, sc = {x...}, their times tc_t, td_t, ed_t, sc_t = {t...},
--   ed_i the E/D's leg, dest = {x, t, fuel}, crz = the last cruise altitude}
function M.predict(s)
    local P, t, isa = s.P, s.t, s.isa or 0
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
        return descent_path(s, wkg, des_cons(xfrom), xed, hed)
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
            local v = P.tas(mm, h, isa) * KT
            local gs = math.max(v - (wind.clb or 0) * KT, 50)
            local thr = P.climb_thrust(t, h)
            local drag = P.drag(t, kg, h, mm)
            local ffl = 4 * P.thrust_ff(t, thr / 4, h, mm, isa)
            if cas < tgt - 0.5 then
                -- a level acceleration to the schedule's CAS
                local dt = 5
                local tas = P.tas(mm, h, isa) + (thr - drag) / kg * dt / KT
                cas = math.min(tgt, P.mach_to_cas(tas / P.tas(1, h, isa), h))
                step_state(gs * dt / NM, 0, dt, ffl * dt / 3600)
            else
                cas = tgt
                local sinG = (thr - drag) / (kg * G) / energy(P, h, cas, mm, machMode, isa)
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
            local v = P.tas(m, hcur, isa) * KT
            local gs = math.max(v - (wind.crz or 0) * KT, 50)
            local ff = 4 * P.cruise_ff(t, kg, hcur, m, isa)
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

    local tcPrev = 0
    local startDes = false
    for pass = 1, 2 do
        x, h, kg, tt, burnt, nextLeg = 0, s.alt, s.gw, 0, 0, 1
        cas = s.cas or (M.schedule(P, s.clb, h))
        phase = s.phase or (h < s.crz - 500 and "clb" or "crz")
        R.pts, sc, tc, td = {}, {}, nil, nil
        scT, tcT, tdT = {}, nil, nil
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
