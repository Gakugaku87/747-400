-- Run from the repository root with LuaJIT: luajit tests/fms/pred_model_test.lua
-- The FMC's trajectory predictions (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.pred_model.lua; 6-1/6-2 step 8c, notes/
-- ATA-34-61-FMC.md §47) with the performance database's models: the speed
-- schedules; the idle descent against PI.11.5 (.84/290/250: its increments,
-- the table's straight-in approach allowance apart); the cruise and descent
-- against PI.11.4's enroute fuel and time (LRC); the climb's level-off at
-- an AT OR BELOW, a descent's AT constraint, T/C, T/D, E/D; step climbs;
-- a short flight; the predictions from within the descent.
local T = dofile("tests/lib/check.lua")("pred_model")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")
local PM = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.pred_model.lua")
local pw = P.tables(0)

-- the climb and descent speeds and the max climb thrust and idle
local clb = {cas = 340, mach = 0.85, trans_cas = 250, trans_alt = 10000}
local des = {cas = 290, mach = 0.84, trans_cas = 250, trans_alt = 10000}
local cas, mach, mm = PM.schedule(P, clb, 5000)
T.check(cas == 250 and not mm, "climb below 10,000 ft: the transition's 250 kt")
cas, mach, mm = PM.schedule(P, clb, 20000)
T.check(cas == 340 and not mm, "FL200: 340 kt")
cas, mach, mm = PM.schedule(P, clb, 35000)
T.check(mach == 0.85 and mm, "FL350: M.85 (above the crossover)")
cas = PM.schedule(P, {cas = 340, mach = 0.85, trans_cas = 250, trans_alt = 10000, restr_cas = 220, restr_alt = 6000}, 4000)
T.equal(cas, 220, "a restriction below its altitude: 220 kt")
T.check(P.climb_thrust(pw, 0) > P.climb_thrust(pw, 20000) and P.climb_thrust(pw, 20000) > P.climb_thrust(pw, 40000), "max climb thrust lapses with altitude")
T.check(P.idle_ff(pw, 35000, 0.84) < P.idle_ff(pw, 10000, 0.5), "idle fuel flow lower up high")

-- the idle descent from a cruise to an E/D at 1,500 ft: its distance, time
-- and fuel from the T/D; PI.11.5's increments (the table's distances and
-- times include a straight-in approach at the outer marker)
local function from_td(fl)
    local r = PM.predict{P = P, t = pw, gw = 250000, fuel = 60000, alt = fl * 100, phase = "crz", crz = fl * 100,
        clb = clb, des = des, crzspd = {mach = 0.84},
        legs = {{name = "TD", dist = 0}, {name = "RW", dist = 800, con = {kind = "AT", a = 1500}}}, ed = 2}
    -- the time and fuel of the descent: the path's at the T/D
    local dp = r.dp
    for i = 2, #dp.h do
        if dp.h[i] >= fl * 100 then return r.ed - dp.x[i], dp.t[i] / 60, dp.f[i], r end
    end
end
local d27, t27 = from_td(270)
local d35, t35, f35, r35 = from_td(350)
local d41, t41 = from_td(410)
T.near(d35 - d27, 124 - 96, 3, string.format("FL350 less FL270: %.1f NM (PI.11.5: 28)", d35 - d27))
T.near(t35 - t27, 23 - 19, 1, string.format("and %.1f min (4)", t35 - t27))
T.near(d41 - d35, 140 - 124, 3, string.format("FL410 less FL350: %.1f NM (16)", d41 - d35))
T.check(d35 < 124 and d35 > 124 - 25, string.format("FL350 to 1,500 ft: %.0f NM, less than the table's 124 (its approach allowance)", d35))
T.check(f35 > 300 and f35 < 1500, string.format("its fuel at idle: %.0f kg (an estimate)", f35))
T.near(r35.td, r35.ed - d35, 1, "the T/D where the cruise meets the path")

-- the enroute fuel and time from a check point at the cruise altitude,
-- 300 t, LRC and .84/290/250 (PI.11.4)
local lrc = {fn = function(h, kg) return (P.lrc(pw, kg, h)) end}
for _, c in ipairs({{33000, 3000, 56.3, 6 * 60 + 20}, {37000, 3000, 55.2, 6 * 60 + 13}, {29000, 5000, 95.0, 11 * 60 + 1}}) do
    local r = PM.predict{P = P, t = pw, gw = 300000, fuel = 120000, alt = c[1], phase = "crz", crz = c[1],
        clb = clb, des = des, crzspd = lrc, legs = {{name = "RW", dist = c[2], con = {kind = "AT", a = 0}}}, ed = 1}
    local fuel = (120000 - r.dest.fuel) / 1000
    T.near(fuel, c[3], c[3] * 0.015, string.format("%d NM at FL%d: %.1f t (PI.11.4: %.1f)", c[2], c[1] / 100, fuel, c[3]))
    T.near(r.dest.t / 60, c[4], 8, string.format("and %.0f min (%d)", r.dest.t / 60, c[4]))
end

-- a climb from 2,000 ft with an AT OR BELOW 15,000 at 40 NM (the SID's),
-- to FL350; a descent with AT 10,000 30 NM before the runway (AT 50 ft)
local legs = {{name = "C1", dist = 40, con = {kind = "B", a = 15000}}, {name = "C2", dist = 60}, {name = "MID", dist = 600},
    {name = "D1", dist = 300}, {name = "D2", dist = 100, con = {kind = "AT", a = 10000}}, {name = "RW", dist = 30, con = {kind = "AT", a = 50}}}
local r = PM.predict{P = P, t = pw, gw = 350000, fuel = 100000, alt = 2000, phase = "clb", crz = 35000, clb = clb, des = des,
    crzspd = {mach = 0.85}, legs = legs, ed = 6, clb_last = 2}
T.near(r.pts[1].h, 15000, 1, "C1: level at its AT OR BELOW 15,000")
T.check(r.pts[2].h > 15000 and r.pts[2].h < 35000, "C2: climbing on after it")
T.check(r.tc and r.tc > 100 and r.tc < 250, string.format("T/C at %.0f NM", r.tc or -1))
T.check(r.pts[3].h == 35000 and r.pts[4].h == 35000, "MID, D1: at FL350")
T.near(r.pts[5].h, 10000, 1, "D2: its AT 10,000")
T.near(r.pts[6].h, 50, 1, "the runway: the E/D")
T.check(r.td and r.td > 1000 and r.td < 1100, string.format("T/D at %.0f NM", r.td or -1))
T.equal(r.ed, 1130, "E/D at the runway")
local prev = 0
local mono = true
for i = 1, #r.pts do
    if r.pts[i].t < prev then mono = false end
    prev = r.pts[i].t
end
T.check(mono and r.pts[6].fuel < r.pts[1].fuel, "times growing, fuel going down along the route")
T.near(r.dest.t, r.pts[6].t, 1e-6, "the destination's time: the E/D's")
T.check(r.tc_t and r.td_t and r.ed_t and r.tc_t < r.td_t and r.td_t < r.ed_t, "the times of the T/C, T/D and E/D in order")
T.near(r.ed_t, r.dest.t, 1e-6, "the E/D's time: the destination's")
T.check(r.tc_t > r.pts[2].t - 1e-6 and r.tc_t < r.pts[3].t, "the T/C between C2 and MID in time")
-- the deceleration to 250 kt at 10,000 ft (step 8d3: the ND's deceleration
-- point, FCOM p.1149): one, after the T/D, just before D2 (AT 10,000)
T.check(#r.decel == 1 and r.decel[1] > r.td and r.decel[1] < 1100 and r.decel[1] > 1100 - 15,
    string.format("one deceleration point, %.1f NM before D2", 1100 - (r.decel[1] or 0)))
-- (step LF1) the deceleration about 500 fpm down before 10,000 ft (FCOM
-- p.1264's descent deceleration phase; before, level at 10,000), its
-- target the 250 kt it ends at
do
    local dp = r.dp
    local lo, hi, ok = nil, nil, true
    for i = 2, #dp.x do
        if dp.k[i] == "decel" then
            lo = lo or i
            hi = i
            if dp.c[i] ~= 250 then ok = false end
        end
    end
    T.check(lo ~= nil and ok, "the deceleration's segments with their target 250 kt")
    if lo then
        T.near(dp.h[lo - 1], 10000, 1, "it ends at 10,000 ft")
        local fpm = (dp.h[hi] - dp.h[lo - 1]) / (dp.t[hi] - dp.t[lo - 1]) * 60
        T.near(fpm, 500, 1, string.format("about 500 fpm down: %.0f fpm over %.1f NM", fpm, dp.x[lo - 1] - dp.x[hi]))
        T.check(dp.h[hi] > 10200 and dp.h[hi] < 11500, string.format("from %.0f ft", dp.h[hi]))
        -- (2026-11-09) as the model's drag slows it at idle down the path,
        -- the CAS at each step's altitude: from its second point (the
        -- first is the step that reached 290 kt, capped) with the path's
        -- CAS there, 250 kt at its end within 1 kt. Before, the CAS at the
        -- altitude before each step: about 5 % more deceleration than the
        -- drag gives (+1.7 kt here)
        local G, FT, KT, NM = 9.80665, 0.3048, 0.514444, 1852
        local kg = 350000 - 100000 + r.pts[5].fuel
        local c = dp.s[hi - 1]
        for i = hi - 1, lo, -1 do
            local n = 20
            for k = 0, n - 1 do
                local h1 = dp.h[i] + (dp.h[i - 1] - dp.h[i]) * k / n
                local h2 = dp.h[i] + (dp.h[i - 1] - dp.h[i]) * (k + 1) / n
                local dx = (dp.x[i - 1] - dp.x[i]) / n * NM
                local mm = P.cas_to_mach(c, h1)
                local v = P.tas(mm, h1) * KT
                local a = P.drag(pw, kg, h1, mm) / kg
                local v2 = v + (-a - G * (h2 - h1) * FT / math.max(dx, 1e-6)) * dx / v
                c = P.mach_to_cas(v2 / KT / P.tas(1, h2), h2)
            end
        end
        T.near(c, 250, 1, string.format("the model's drag slows it to %.1f kt at 10,000 ft (from %.1f kt)", c, dp.s[hi - 1]))
    end
end
T.check(r.td_decel < 1.5, string.format("M.85 at FL350 to the descent's M.84: a short level deceleration (%.1f NM)", r.td_decel))
-- each waypoint's speed: the climb's, the cruise's Mach, the descent's
T.check(r.pts[1].cas == 340 and not r.pts[1].machMode, "C1 in the climb: 340 kt")
T.check(r.pts[3].machMode and r.pts[3].mach == 0.85, "MID in the cruise: M.85")
-- (2026-11-09) D2 (AT 10,000) where the deceleration to the transition's
-- 250 kt ends: the path's speed there (before, the schedule's 290 above
-- the transition's altitude)
T.near(r.pts[5].cas, 250, 0.5, string.format("D2 in the descent at 10,000 ft: %.1f kt, the deceleration's end", r.pts[5].cas))
T.check(not r.pts[5].machMode, "D2: a CAS")
T.check(r.pts[6].cas == 250, "the runway below 10,000 ft: 250 kt")

-- (step LF1) the T/D's level deceleration (FCOM p.1264): cruising at M.80
-- at FL250 (about 333 kt, s198's) to the descent's 290 kt, idle at FL250
-- before the path leaves it, the T/D at its start
do
    local legsL = {{name = "A", dist = 200}, {name = "RW", dist = 120, con = {kind = "AT", a = 50}}}
    local rl = PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 25000, phase = "crz", crz = 25000, clb = clb, des = des,
        crzspd = {mach = 0.80}, legs = legsL, ed = 2}
    local dp = rl.dp
    -- where the path crosses FL250, between its points (2026-11-09: the
    -- first point at or above it was up to a step's 0.9 NM off)
    local top
    for i = 2, #dp.x do
        if dp.h[i] >= 25000 - 1 then
            local f = (25000 - dp.h[i - 1]) / math.max(dp.h[i] - dp.h[i - 1], 1e-9)
            top = dp.x[i - 1] + (dp.x[i] - dp.x[i - 1]) * math.min(math.max(f, 0), 1)
            break
        end
    end
    T.check(rl.td_decel and rl.td_decel > 3 and rl.td_decel < 10, string.format("a level deceleration of %.1f NM", rl.td_decel or -1))
    T.check(top and math.abs(rl.td - (top - rl.td_decel)) < 0.05,
        string.format("the T/D at its start: %.1f NM, the path leaving FL250 at %.1f", rl.td or -1, top or -1))
    -- (2026-11-05 review 4) after a long cruise (a heavy start, about 80 t
    -- burnt) too, the cruise flown to the T/D: its time the distance at
    -- M.86's TAS (no wind). Before, the deceleration kept from the first
    -- weight (longer: 11.2 NM at 390 t, 10.3 at the T/D's) stopped the
    -- cruise short and the T/D was moved on without its time and fuel
    local legsLong = {{name = "A", dist = 4000}, {name = "RW", dist = 120, con = {kind = "AT", a = 50}}}
    local rlong = PM.predict{P = P, t = pw, gw = 390000, fuel = 150000, alt = 25000, phase = "crz", crz = 25000, clb = clb,
        des = des, crzspd = {mach = 0.86}, legs = legsLong, ed = 2}
    local tdWant = rlong.td and rlong.td / P.tas(0.86, 25000) * 3600 or 0
    T.check(rlong.td_t and math.abs(rlong.td_t - tdWant) < 1,
        string.format("after 4,000 NM: the T/D at %.1f s, its distance at M.86 %.1f s", rlong.td_t or -1, tdWant))
end

-- step climbs where the steps function says: at 300 t to FL350, at 280 t to
-- FL390
local legs3 = {{name = "A", dist = 1000}, {name = "B", dist = 1500}, {name = "RW", dist = 500, con = {kind = "AT", a = 50}}}
local function steps(h, kg) if h < 39000 then return h + 4000, 300000 - (h - 31000) / 4000 * 20000 end end
r = PM.predict{P = P, t = pw, gw = 320000, fuel = 110000, alt = 31000, phase = "crz", crz = 31000, clb = clb, des = des,
    crzspd = {mach = 0.85}, legs = legs3, ed = 3, steps = steps}
T.equal(#r.sc, 2, "two step climbs")
T.check(#r.sc_t == 2 and r.sc_t[1] < r.sc_t[2], "their times in order")
T.equal(r.crz, 39000, "to FL390")
T.check(r.pts[1].h == 35000 and r.pts[2].h == 39000, "A at FL350, B at FL390")
-- a step's extra fuel, as the FCTM's 225-300 kg for 4,000 ft (p.4.8): with
-- and without the first step, 50 NM after it
local r0 = PM.predict{P = P, t = pw, gw = 320000, fuel = 110000, alt = 31000, phase = "crz", crz = 31000, clb = clb, des = des,
    crzspd = {mach = 0.85}, legs = {{name = "S", dist = r.sc[1] + 50}, {name = "E", dist = 100}}}
local r1 = PM.predict{P = P, t = pw, gw = 320000, fuel = 110000, alt = 31000, phase = "crz", crz = 31000, clb = clb, des = des,
    crzspd = {mach = 0.85}, legs = {{name = "S", dist = r.sc[1] + 50}, {name = "E", dist = 100}},
    steps = function(h, kg) if h < 35000 then return 35000, 300000 end end}
local extra = r0.pts[1].fuel - r1.pts[1].fuel
T.check(extra > 100 and extra < 500, string.format("a 4,000 ft step's extra fuel, 50 NM after it: %.0f kg (FCTM: 225-300)", extra))

-- (2026-11-05) the crew's planned step climbs (RTE LEGS "XXXS": FCOM
-- p.1332) at their waypoints, overriding the FMC's steps (FCOM p.1257):
-- FL350 at A (1,000 NM), FL370 at B; the steps function's points not used
do
    local legsP = {{name = "A", dist = 1000, step = 35000}, {name = "B", dist = 1500, step = 37000},
        {name = "RW", dist = 500, con = {kind = "AT", a = 50}}}
    local rp = PM.predict{P = P, t = pw, gw = 320000, fuel = 110000, alt = 31000, phase = "crz", crz = 31000, clb = clb, des = des,
        crzspd = {mach = 0.85}, legs = legsP, ed = 3, steps = steps}
    T.equal(#rp.sc, 2, "two planned steps")
    T.near(rp.sc[1], 1000, 0.01, "the first at A (1,000 NM)")
    T.near(rp.sc[2], 2500, 0.01, "the second at B (2,500 NM)")
    T.equal(rp.pts[1].h, 31000, "A still at FL310 (the step starts there)")
    T.equal(rp.crz, 37000, "to FL370 (not the steps function's FL390)")
    T.check(rp.pts[2].h > 35000 - 1, "B at FL350 or above")
    -- a planned step below the cruise altitude: none
    local rl = PM.predict{P = P, t = pw, gw = 320000, fuel = 110000, alt = 31000, phase = "crz", crz = 31000, clb = clb, des = des,
        crzspd = {mach = 0.85}, legs = {{name = "A", dist = 500, step = 29000}, {name = "RW", dist = 500, con = {kind = "AT", a = 50}}},
        ed = 2}
    T.equal(#rl.sc, 0, "a step below FL310: none")
end

-- (2026-11-05 review 4) a step the airplane cannot fly (FL490 at 380 t,
-- above its thrust ceiling): tried once, an S/C only where it climbed, no
-- more steps; before, tried again at every minute of the cruise, an S/C
-- each (21 here)
do
    local ru = PM.predict{P = P, t = pw, gw = 380000, fuel = 110000, alt = 35000, phase = "crz", crz = 35000, clb = clb,
        des = des, crzspd = {mach = 0.85}, legs = legs3, ed = 3,
        steps = function(h, kg) return 49000, 999999 end}
    T.check(#ru.sc <= 1, string.format("an unflyable step: at most one S/C (before: one a minute): %d", #ru.sc))
    T.check(ru.crz < 49000 and (#ru.sc == 1) == (ru.crz > 35000 + 1),
        string.format("the cruise where its climb ended (%.0f ft), an S/C only if it climbed (%d)", ru.crz, #ru.sc))
end

-- a short flight: the climb meets the descent below CRZ ALT
local legs2 = {{name = "X", dist = 60}, {name = "RW", dist = 60, con = {kind = "AT", a = 50}}}
r = PM.predict{P = P, t = pw, gw = 300000, fuel = 50000, alt = 1500, phase = "clb", crz = 35000, clb = clb, des = des,
    crzspd = {mach = 0.85}, legs = legs2, ed = 2}
T.check(r.tc == nil and r.td and r.td < 60 and r.crz < 35000, string.format("120 NM: no T/C, the T/D at %.0f NM below FL350 (%.0f ft)", r.td or -1, r.crz))
T.near(r.pts[2].h, 50, 1, "to the runway")

-- within the descent: along the path from here
local legs4 = {{name = "D", dist = 40}, {name = "RW", dist = 40, con = {kind = "AT", a = 50}}}
r = PM.predict{P = P, t = pw, gw = 250000, fuel = 20000, alt = 25000, phase = "des", crz = 35000, clb = clb, des = des,
    crzspd = {mach = 0.85}, legs = legs4, ed = 2}
T.check(r.td == nil and r.pts[1].h > 5000 and r.pts[1].h < 25000 and r.pts[2].h == 50, "in the descent: no T/D, D between, the runway")
T.check(r.dest.t > 10 * 60 and r.dest.t < 20 * 60, string.format("80 NM: %.1f min", r.dest.t / 60))
T.check(#r.decel == 1 and r.decel[1] > 0 and r.decel[1] < 80, "the deceleration at 10,000 ft ahead")

-- no E/D: the cruise to the route's end
r = PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 35000, phase = "crz", crz = 35000, clb = clb, des = des,
    crzspd = {mach = 0.85}, legs = {{name = "A", dist = 500}, {name = "B", dist = 500}}}
T.check(r.td == nil and r.pts[2].h == 35000, "without an E/D: no T/D, at FL350 to the end")
T.equal(#r.decel, 0, "nor deceleration points")
T.near(r.dest.t / 3600, 1000 / P.tas(0.85, 35000), 0.01, "1,000 NM at M.85's TAS")

-- step 8e3: a field (the winds and temperatures along the route) in place
-- of the phases' headwinds and the ISA deviation now
local function const_field(hw, dev) return {wind = function() return hw end, isa = function() return dev end} end
local base = {P = P, t = pw, gw = 300000, fuel = 80000, alt = 35000, phase = "crz", crz = 35000, clb = clb, des = des,
    crzspd = {mach = 0.85}, legs = {{name = "A", dist = 500}, {name = "RW", dist = 500, con = {kind = "AT", a = 50}}}, ed = 2}
local function with(extra)
    local s = {}
    for key, v in pairs(base) do s[key] = v end
    for key, v in pairs(extra) do s[key] = v end
    return s
end
local rw = PM.predict(with{wind = {clb = 50, crz = 50, des = 50}, isa = 5})
local rf = PM.predict(with{field = const_field(50, 5)})
T.near(rf.dest.t, rw.dest.t, 1e-6, "a field of a 50 kt headwind and ISA+5: as the phases' 50 kt and ISA+5")
T.near(rf.dest.fuel, rw.dest.fuel, 1e-6, "the fuel too")
local rt = PM.predict(with{field = const_field(-50, 5)})
T.check(rt.dest.t < rf.dest.t - 600, string.format("a 50 kt tailwind: %.0f min sooner over 1,000 NM", (rf.dest.t - rt.dest.t) / 60))
-- the field's wind by where and how high: a headwind only in the descent
-- below FL200 makes the descent longer in time, not the cruise
local rd = PM.predict(with{field = {wind = function(x, h, phase) return (phase == "des" and h < 20000) and 60 or 0 end,
    isa = function() return 0 end}})
local r0 = PM.predict(with{field = const_field(0, 0)})
T.check(rd.dest.t > r0.dest.t + 60 and math.abs(rd.td - r0.td) < 20, string.format("a headwind low in the descent: %.1f min later, the T/D %.1f NM apart",
    (rd.dest.t - r0.dest.t) / 60, rd.td - r0.td))

-- (step 9e4) a leg's glide path angle (FCOM p.1262, p.1405): the path over
-- the ground at its angle back from the leg's end, two such legs one line
-- (the FAF's AT OR ABOVE 4,000 under it); an AT constraint at such a leg's
-- start under the line: level back from where the line meets it (the
-- level flight until the path, p.1262), thrust on it
local FT_NM = 1852 / 0.3048
local G3 = FT_NM * math.tan(math.rad(3))
local function gp_pred(legs)
    return PM.predict{P = P, t = pw, gw = 250000, fuel = 20000, alt = 20000, phase = "des", crz = 35000, clb = clb, des = des,
        crzspd = {mach = 0.85}, legs = legs, ed = #legs}
end
-- the path's altitude x NM ahead (its arrays from the E/D back)
local function dp_h(dp, x)
    for i = 2, #dp.x do
        if dp.x[i] <= x + 1e-9 then
            local f = (x - dp.x[i]) / math.max(dp.x[i - 1] - dp.x[i], 1e-9)
            return dp.h[i] + (dp.h[i - 1] - dp.h[i]) * f, dp.k[i - 1]
        end
    end
end
r = gp_pred{{name = "A", dist = 40}, {name = "IF", dist = 10}, {name = "FAF", dist = 6, con = {kind = "A", a = 4000}, gp = 3},
    {name = "RW", dist = 12.6, con = {kind = "AT", a = 50}, gp = 3}}
local hFaf = 50 + 12.6 * G3
T.near(r.pts[3].h, hFaf, 1, string.format("the FAF on the runway's 3-degree line: %.0f ft (over its 4,000 A)", hFaf))
T.near(r.pts[2].h, hFaf + 6 * G3, 1, string.format("the IF on the FAF's 3-degree line: %.0f ft", hFaf + 6 * G3))
T.near(dp_h(r.dp, 50 + 6 + 6.3), 50 + 6.3 * G3, 1, "halfway to the runway on the line")
T.check(r.pts[1].h > r.pts[2].h + 1000, string.format("before the IF the idle path above: %.0f ft at A", r.pts[1].h))
r = gp_pred{{name = "A", dist = 40}, {name = "IF", dist = 10, con = {kind = "AT", a = 5000}}, {name = "FAF", dist = 6, gp = 3},
    {name = "RW", dist = 12.6, con = {kind = "AT", a = 50}, gp = 3}}
local meet = (5000 - hFaf) / G3
T.near(r.pts[2].h, 5000, 1, "AT 5,000 at the IF under the line: the IF at 5,000")
local hLevel, kLevel = dp_h(r.dp, 50 + 6 - meet - 1)
T.check(math.abs(hLevel - 5000) < 1 and kLevel == "spd", string.format("level at 5,000 from the IF until the line, %.1f NM before the FAF (the A/T on speed)", meet))
T.near(dp_h(r.dp, 50 + 6 - meet + 1), 5000 - G3, 1, "1 NM past the meeting point down the line")
T.near(r.pts[3].h, hFaf, 1, "the FAF on the line still")

-- (step 9h4b) the cruise descent under way (VNAV's: crz_des "des"): from
-- FL350 down to CRZ ALT FL310 at 1,250 fpm first, its level off (lvl, its
-- time), then the cruise there
local long = {{name = "A", dist = 500}, {name = "B", dist = 500}}
local rdes = PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 35000, phase = "crz", crz = 31000, clb = clb,
    des = des, crzspd = {mach = 0.85}, legs = long, crz_des = "des"}
T.near(rdes.lvl_t, 4000 / PM.CRZ_DES_VS * 60, 1, string.format("4,000 ft at 1,250 fpm: level in %.0f s", rdes.lvl_t or -1))
T.near(rdes.lvl, P.tas(0.85, 33000) * rdes.lvl_t / 3600, 1, string.format("%.1f NM on (M.85's TAS)", rdes.lvl or -1))
T.check(rdes.lvl_dd == nil and rdes.pts[1].h == 31000 and rdes.crz == 31000, "not the driftdown's; A at FL310")
local rlvl = PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 35000, phase = "crz", crz = 31000, clb = clb,
    des = des, crzspd = {mach = 0.85}, legs = long}
T.check(rlvl.lvl == nil and rlvl.pts[1].h == 35000, "without crz_des: the cruise where the airplane is, as before")
-- the engine-out driftdown (crz_des "dd", eo 1; FCOM p.1268): from FL350
-- to the E/O MAX FL320 at 300 t at E/O LRC at FL320, CON at most, 300 fpm
-- at least: LEVEL AT; slower than the cruise descent, at most 300 fpm's
local eoLrc = {fn = function(h, kg) return (P.eo_lrc(pw, 1, kg, h)) end}
local rdd = PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 35000, phase = "crz", crz = 32000, clb = clb,
    des = des, crzspd = eoLrc, legs = long, crz_des = "dd", eo = 1}
T.check(rdd.lvl_dd and rdd.lvl and rdd.lvl_t, "the driftdown's level off (LEVEL AT)")
T.check(rdd.lvl_t > 3000 / PM.CRZ_DES_VS * 60 and rdd.lvl_t <= 3000 / PM.DD_VS * 60 + 1,
    string.format("3,000 ft in %.1f min: slower than 1,250 fpm, at least 300 fpm", rdd.lvl_t / 60))
local mdd = P.eo_lrc(pw, 1, 300000, 32000)
T.check(rdd.lvl > P.tas(mdd, 35000) * rdd.lvl_t / 3600 * 0.98 and rdd.lvl < P.tas(mdd, 32000) * rdd.lvl_t / 3600 * 1.02,
    string.format("%.1f NM on at M%.3f (E/O LRC at FL320)", rdd.lvl, mdd))
-- higher over the maximum: steeper at first (CON short of the drag), so
-- 5,000 ft in less than 5/3 of the time
local rdd2 = PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 37000, phase = "crz", crz = 32000, clb = clb,
    des = des, crzspd = eoLrc, legs = long, crz_des = "dd", eo = 1}
T.check(rdd2.lvl_t < rdd.lvl_t * 5 / 3 - 30, string.format("from FL370: %.1f min (from FL350 %.1f)", rdd2.lvl_t / 60, rdd.lvl_t / 60))
-- the engine-out fuel (eo): the cruise at E/O LRC on three engines, the
-- tables' fuel flow (PI.13.4: 300 t, 25,000 ft, 3593 kg/h an engine)
local reo = PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 25000, phase = "crz", crz = 25000, clb = clb,
    des = des, crzspd = {mach = .743}, legs = {{name = "A", dist = 100}}, eo = 1}
local hrs = 100 / P.tas(.743, 25000)
T.near((80000 - reo.dest.fuel) / hrs, 3 * 3593, 3 * 3593 * 0.01,
    string.format("E/O LRC on three engines: %.0f kg/h (3 x 3593)", (80000 - reo.dest.fuel) / hrs))
local rall = PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 25000, phase = "crz", crz = 25000, clb = clb,
    des = des, crzspd = {mach = .743}, legs = {{name = "A", dist = 100}}}
T.check(80000 - reo.dest.fuel > 80000 - rall.dest.fuel, "more than with all four (the windmilling and trim drag)")
-- the engine-out descent path steeper (the drag), the climb slower (three
-- engines' share)
local rte = {{name = "A", dist = 300}, {name = "RW", dist = 200, con = {kind = "AT", a = 50}}}
local rpa = PM.predict{P = P, t = pw, gw = 280000, fuel = 60000, alt = 25000, phase = "crz", crz = 25000, clb = clb,
    des = des, crzspd = {mach = .74}, legs = rte, ed = 2}
local rpe = PM.predict{P = P, t = pw, gw = 280000, fuel = 60000, alt = 25000, phase = "crz", crz = 25000, clb = clb,
    des = des, crzspd = {mach = .74}, legs = rte, ed = 2, eo = 1}
T.check(rpe.td > rpa.td + 2, string.format("the engine-out T/D nearer the E/D: %.0f NM from it (all engines %.0f)", 500 - rpe.td, 500 - rpa.td))
local rca = PM.predict{P = P, t = pw, gw = 280000, fuel = 60000, alt = 10000, phase = "clb", crz = 25000, clb = clb,
    des = des, crzspd = {mach = .74}, legs = long}
local rce = PM.predict{P = P, t = pw, gw = 280000, fuel = 60000, alt = 10000, phase = "clb", crz = 25000, clb = clb,
    des = des, crzspd = {mach = .74}, legs = long, eo = 1}
T.check(rce.tc > rca.tc * 1.3, string.format("the engine-out climb to FL250: T/C %.0f NM (all engines %.0f)", rce.tc, rca.tc))

-- (FIX INFO, 2026-11-04) the profile along the route: the present position,
-- the T/C at CRZ ALT, the waypoints, the T/D at the cruise's; the altitude
-- and time at a distance, where an altitude or a time is reached
local pr = {pts = {{x = 50, h = 20000, t = 600}, {x = 300, h = 35000, t = 2700}, {x = 500, h = 12000, t = 4500}},
    tc = 120, tc_t = 1200, td = 380, td_t = 3300, crz = 35000, sc = {}}
local prof = PM.profile(pr, {alt = 5000, crz = 35000})
T.equal(#prof, 6, "the profile: start, 3 waypoints, T/C, T/D")
T.equal(prof[1].x, 0, "it starts at the present position")
T.equal(prof[3].x, 120, "the T/C in its place")
local h, t = PM.profile_at(prof, 85)
T.near(h, 20000 + (35000 - 20000) * 35 / 70, 1e-6, "the altitude between a waypoint and the T/C")
T.near(t, 600 + 600 * 35 / 70, 1e-6, "the time there")
T.check(PM.profile_at(prof, 600) == nil, "past the end: nil")
local xa = PM.profile_alt(prof, 20000)
T.near(xa, 50, 1e-6, "FL200 reached at the first waypoint (climbing)")
local xd = PM.profile_alt(prof, 25000)
T.check(xd and xd < 120, ("25,000 ft: the first crossing, in the climb (%.1f)"):format(xd or -1))
T.near(PM.profile_alt({{x = 0, h = 35000, t = 0}, {x = 100, h = 35000, t = 900}, {x = 200, h = 15000, t = 2100}}, 25000), 150, 1e-6,
    "a descent's crossing")
T.check(PM.profile_alt(prof, 40000) == nil, "an altitude never reached: nil")
T.near(PM.profile_time(prof, 1200), 120, 1e-6, "20 minutes ahead: the T/C")
T.check(PM.profile_time(prof, 9999) == nil, "a time past the end: nil")
T.check(PM.profile_time(prof, -60) == nil, "a time passed: nil")
local prs = PM.profile({pts = {{x = 100, h = 31000, t = 900}, {x = 400, h = 35000, t = 3500}}, tc = 60, tc_t = 500,
    sc = {200}, sc_t = {1700}, td = 450, td_t = 4000, crz = 35000}, {alt = 20000, crz = 31000})
local hs = PM.profile_at(prs, 200)
T.near(hs, 31000, 1e-6, "an S/C at the altitude of the waypoint before it")

-- (2026-11-05 review 3) DES NOW before the T/D (the descent phase at the
-- cruise altitude, the T/D ahead): level to the path, then the path; as the
-- cruise's prediction (before, the path's altitudes from here: FL451 at the
-- next waypoint, the destination 13 min early)
do
    local legsDN = {{name = "A", dist = 30}, {name = "B", dist = 100}, {name = "C", dist = 70},
        {name = "RW", dist = 60, con = {kind = "AT", a = 50}}}
    local function dn(phase)
        return PM.predict{P = P, t = pw, gw = 250000, fuel = 30000, alt = 35000, phase = phase, crz = 35000,
            clb = clb, des = des, crzspd = {mach = 0.84}, legs = legsDN, ed = 4}
    end
    local rc, rd = dn("crz"), dn("des")
    T.check(rc.td and rc.td > 100, string.format("the cruise: the T/D %.0f NM ahead", rc.td or -1))
    T.check(rd.pts[1].h <= 35050, string.format("DES NOW: A (30 NM) at %.0f ft, not above FL350", rd.pts[1].h))
    T.check(rd.td and math.abs(rd.td - rc.td) < 1, string.format("DES NOW: the T/D where the path meets FL350 (%.0f NM)", rd.td or -1))
    T.near(rd.dest.t, rc.dest.t, 30, string.format("DES NOW: at the runway in %.1f min, as the cruise's %.1f",
        rd.dest.t / 60, rc.dest.t / 60))
end

-- (2026-11-09) a waypoint sequenced in the descent: its constraint kept
-- behind the airplane (s.behind), the path the airplane is on the same
-- line from it as before the sequencing (IRNMN2's windows; without it the
-- path 229 to 469 ft higher there: the idle path back from the next one)
do
    local cons = {{kind = "W", a = 29000, b = 26000}, {kind = "W", a = 27000, b = 23000}, {kind = "W", a = 24000, b = 20000},
        {kind = "W", a = 23000, b = 19000}, {kind = "W", a = 20000, b = 16000}, {kind = "AT", a = 12000}}
    local gaps = {12.3, 7.3, 6.4, 9.1, 30}
    local function seq_path(first, before, behind)
        -- the airplane `before` NM before waypoint `first` (or past it with behind)
        local legs = {{name = "PPOS", dist = 0}}
        if before then legs[2] = {name = "W" .. first, dist = before, con = cons[first]} end
        for k = first + 1, #cons do
            legs[#legs + 1] = {name = "W" .. k, dist = gaps[k - 1] - ((k == first + 1 and not before) and 0.2 or 0), con = cons[k]}
        end
        local r = PM.predict{P = P, t = pw, gw = 230000, fuel = 10000, alt = 25000, phase = "des", crz = 37000,
            clb = clb, des = des, crzspd = {mach = 0.84}, legs = legs, ed = #legs, clb_last = 0,
            behind = behind and {x = -0.2, con = cons[first]} or nil}
        return r
    end
    -- the path's altitude at the distance e to go to the E/D
    local function h_at(r, e)
        local dp = r.dp
        for i = 2, #dp.x do
            local e0, e1 = r.ed - dp.x[i - 1], r.ed - dp.x[i]
            if e1 >= e then return dp.h[i - 1] + (dp.h[i] - dp.h[i - 1]) * (e - e0) / math.max(e1 - e0, 1e-9) end
        end
    end
    for first = 1, 4 do
        local rest = 0
        for k = first, #gaps do rest = rest + gaps[k] end
        local e = rest - 0.2     -- 0.2 NM past waypoint `first`
        local hb = h_at(seq_path(first, 0.5, false), e)
        local hk = h_at(seq_path(first, nil, true), e)
        local hn = h_at(seq_path(first, nil, false), e)
        T.near(hk, hb, 20, string.format("past W%d: the path %.0f ft with it kept behind, %.0f before (%.0f without)", first, hk, hb, hn))
    end
end

-- (2026-11-09) two AT constraints at one altitude (KLAX's DAHJR and GADDO
-- at 6,000 ft): the path level between them (before: DAHJR at 6,963 ft on
-- the idle path back from GADDO); an AT OR ABOVE there not levelled
do
    local function lv(kind)
        local legs = {{name = "PPOS", dist = 0}, {name = "CLIFY", dist = 10, con = {kind = "W", a = 8000, b = 7000}},
            {name = "DAHJR", dist = 5, con = {kind = kind, a = 6000}}, {name = "GADDO", dist = 3, con = {kind = "AT", a = 6000}},
            {name = "FAF", dist = 12, con = {kind = "AT", a = 2000}}, {name = "RW", dist = 6, con = {kind = "AT", a = 178}}}
        local r = PM.predict{P = P, t = pw, gw = 230000, fuel = 10000, alt = 9000, phase = "des", crz = 37000,
            clb = clb, des = des, crzspd = {mach = 0.84}, legs = legs, ed = #legs, clb_last = 0}
        return r.pts[3].h, r.pts[2].h
    end
    local hAt, hClify = lv("AT")
    T.near(hAt, 6000, 1, string.format("DAHJR AT 6,000 after it: at %.0f ft, level to GADDO", hAt))
    T.check(hClify >= 7000 - 1 and hClify <= 8000 + 1, string.format("CLIFY within its window: %.0f ft", hClify))
    local hB = lv("B")
    T.near(hB, 6000, 1, string.format("an AT OR BELOW 6,000 there too: %.0f ft", hB))
    local hA = lv("A")
    T.check(hA > 6100, string.format("an AT OR ABOVE 6,000: the idle path above it (%.0f ft)", hA))
end

-- (FMC-08, 2026-11-09) the waypoints' speed constraints (FCOM p.1332: at
-- or below; p.1393: the slower of the constraint's and the performance
-- speed). The descent's at and after their waypoints (FMSPG p.3.5-3), as
-- on KLAX's IRNMN2 (MUPTT 280, SYMON 250, BAYST 240, CLIFY 210): the path's
-- deceleration to each about 500 fpm down ending at its waypoint (FCOM
-- p.1258, p.1264), the ND's deceleration points, each waypoint's predicted
-- speed (LEGS: the constraint's after it), none for the transition's
-- 240 kt at 10,000 ft (BAYST's 240 before it); the descent longer
do
    local des2 = {cas = 290, mach = 0.84, trans_cas = 240, trans_alt = 10000}
    local function star(withSpd, behind)
        local function sp(v) return withSpd and v or nil end
        local legs = {{name = "CRZ", dist = 250},
            {name = "B", dist = 60, con = {kind = "W", a = 27000, b = 23000}, spd = sp(280)},
            {name = "B2", dist = 20, con = {kind = "W", a = 24000, b = 20000}},
            {name = "C", dist = 50, con = {kind = "W", a = 13000, b = 12000}, spd = sp(250)},
            {name = "D", dist = 15, con = {kind = "A", a = 9000}, spd = sp(240)},
            {name = "D2", dist = 8, con = {kind = "W", a = 9000, b = 8000}},
            {name = "E", dist = 12, con = {kind = "AT", a = 6000}, spd = sp(210)},
            {name = "E2", dist = 6, con = {kind = "AT", a = 6000}},
            {name = "RW", dist = 18, con = {kind = "AT", a = 150}}}
        return PM.predict{P = P, t = pw, gw = 250000, fuel = 40000, alt = 37000, phase = "crz", crz = 37000,
            clb = clb, des = des2, crzspd = {mach = 0.85}, legs = legs, ed = #legs, spd_behind = behind}
    end
    local r0, r = star(false), star(true)
    -- the path's CAS and altitude at x (its points going back from the E/D)
    local function at(rr, x)
        local dp = rr.dp
        for i = 2, #dp.x do
            if dp.x[i] <= x + 1e-9 then
                local f = (x - dp.x[i]) / math.max(dp.x[i - 1] - dp.x[i], 1e-9)
                return dp.s[i] + (dp.s[i - 1] - dp.s[i]) * f, dp.h[i] + (dp.h[i - 1] - dp.h[i]) * f
            end
        end
    end
    -- the decelerations: {from x, to x, target}
    local function decels(rr)
        local dp, out, from = rr.dp, {}, nil
        for i = 2, #dp.x do
            if dp.k[i] == "decel" and not from then from = i - 1 end
            if dp.k[i] ~= "decel" and from then
                out[#out + 1] = {x0 = dp.x[i - 1], x1 = dp.x[from], h0 = dp.h[i - 1], h1 = dp.h[from], c = dp.c[i - 1]}
                from = nil
            end
        end
        return out
    end
    -- (2026-11-09, s273's second run) a deceleration as the model's drag
    -- slows it at idle along the path from its start, the CAS at each
    -- step's altitude (down a line the true airspeed's fall at a constant
    -- CAS is not the drag's): the CAS at its end at kg
    local G, FT, KT, NM = 9.80665, 0.3048, 0.514444, 1852
    local function fwd(rr, d, kg)
        local cas = at(rr, d.x0)
        local x = d.x0
        while x < d.x1 - 1e-9 do
            local dx = math.min(0.05, d.x1 - x)
            local _, h1 = at(rr, x)
            local _, h2 = at(rr, x + dx)
            local mm = P.cas_to_mach(cas, h1)
            local v = P.tas(mm, h1) * KT
            local a = P.drag(pw, kg, h1, mm) / kg
            local v2 = v + (-a - G * (h2 - h1) * FT / (dx * NM)) * dx * NM / v
            cas = P.mach_to_cas(v2 / KT / P.tas(1, h2), h2)
            x = x + dx
        end
        return cas
    end
    for _, w in ipairs({{2, 280}, {4, 250}, {5, 240}, {7, 210}}) do
        local p = r.pts[w[1]]
        local cas = at(r, p.x)
        T.near(cas, w[2], 0.5, string.format("the path at its waypoint (%.0f NM, %.0f ft): %.1f kt (%d)", p.x, p.h, cas, w[2]))
        T.near(p.cas, w[2], 0.5, string.format("its predicted speed %.0f", p.cas))
        local d = nil
        for _, e in ipairs(decels(r)) do if math.abs(e.x1 - p.x) < 0.05 then d = e end end
        T.check(d ~= nil and d.c == w[2] and d.x1 - d.x0 > 0.5 and d.x1 - d.x0 < 15,
            string.format("a deceleration to %d ending there: from %.1f NM before, %.0f ft above", w[2],
            d and d.x1 - d.x0 or -1, d and d.h0 - d.h1 or -1))
        if d then
            local cf = fwd(r, d, 250000 - 40000 + r.pts[2].fuel)
            T.near(cf, w[2], 1.5, string.format("the model's drag slows it to %.1f kt there (from %.1f kt)", cf, at(r, d.x0)))
        end
        local nd = false
        for _, x in ipairs(r.decel) do if d and math.abs(x - d.x0) < 0.05 then nd = true end end
        T.check(nd, "its start an ND deceleration point")
    end
    T.equal(#r.decel, 4, "four deceleration points (none for the transition's 240 kt: BAYST's before it)")
    T.check(#r0.decel == 1, "without the constraints the transition's one")
    T.near(r.pts[3].cas, 280, 0.5, "B2 after B: 280 kt (B's in force)")
    T.near(r.pts[6].cas, 240, 0.5, "D2 after D: 240 kt")
    T.near(r.pts[9].cas, 210, 0.5, "the runway (the E/D) after E: 210 kt")
    T.near(r0.pts[3].cas, 290, 0.5, "(without: 290 kt at B2)")
    local cB = at(r, r.pts[2].x - 2.5)
    T.check(cB > 289.5, string.format("2.5 NM before B the schedule's 290 (%.1f kt)", cB))
    T.check(r.pts[9].t > r0.pts[9].t + 60, string.format("the E/D %.0f s later", r.pts[9].t - r0.pts[9].t))
    -- a speed constraint passed in the descent (spd_behind: the glue's) in
    -- force on to the E/D
    local rb = star(true, 250)
    local mx = 0
    for i = 1, #rb.dp.s do if rb.dp.s[i] > mx then mx = rb.dp.s[i] end end
    T.near(mx, 250, 0.5, string.format("250 kt passed: the path at most %.1f kt", mx))
    -- (2026-11-09, s273's second run) a steep line of windows (KLAX's
    -- IRNMN2: about 300 ft/NM, 1,650 fpm, MUPTT's 280 kt to SYMON's 250
    -- kt): the deceleration the model's drag gives at idle there, far
    -- longer; the earlier waypoint passed slower than its constraint (at or
    -- below it). Before, 15.4 NM planned where the drag took it to 266 kt
    do
        local steep = {{name = "CRZ", dist = 250},
            {name = "M", dist = 60, con = {kind = "W", a = 27000, b = 23000}, spd = 280},
            {name = "R", dist = 30, con = {kind = "W", a = 17000, b = 14000}},
            {name = "S", dist = 13.4, con = {kind = "W", a = 13000, b = 12000}, spd = 250},
            {name = "E", dist = 25, con = {kind = "AT", a = 6000}},
            {name = "RW", dist = 18, con = {kind = "AT", a = 150}}}
        -- (the transition's 250 kt: no deceleration after S)
        local des3 = {cas = 290, mach = 0.84, trans_cas = 250, trans_alt = 10000}
        local rs = PM.predict{P = P, t = pw, gw = 250000, fuel = 40000, alt = 37000, phase = "crz", crz = 37000,
            clb = clb, des = des3, crzspd = {mach = 0.85}, legs = steep, ed = #steep}
        local pS, pM, pR = rs.pts[4], rs.pts[2], rs.pts[3]
        local cS = at(rs, pS.x)
        T.near(cS, 250, 0.5, string.format("steep: the path at S %.1f kt (%.0f ft)", cS, pS.h))
        local d = nil
        for _, e in ipairs(decels(rs)) do if math.abs(e.x1 - pS.x) < 0.05 then d = e end end
        T.check(d ~= nil and d.c == 250, "steep: a deceleration to 250 ending at S")
        if d then
            local grad = (pR.h - pS.h) / (pS.x - pR.x)
            T.check(grad > 250 and grad < 350, string.format("steep: the line R to S %.0f ft/NM", grad))
            T.check(d.x1 - d.x0 > 20, string.format("steep: the deceleration %.1f NM long (from %.0f ft)", d.x1 - d.x0, d.h0))
            local cf = fwd(rs, d, 250000 - 40000 + pM.fuel)
            T.near(cf, 250, 1.5, string.format("steep: the model's drag slows it to %.1f kt at S (from %.1f kt)", cf, at(rs, d.x0)))
        end
        local cM = at(rs, pM.x)
        T.check(cM <= 280.5, string.format("steep: M passed at %.1f kt (at or below 280)", cM))
        -- (LEGS) the waypoints' predicted speeds inside it the path's
        T.near(pM.cas, cM, 0.5, string.format("steep: M's predicted speed %.1f kt, the path's", pM.cas))
        T.near(pR.cas, at(rs, pR.x), 0.5, string.format("steep: R's %.1f kt", pR.cas))
        -- a line steeper than idle (450 ft/NM) down to a 250 kt constraint:
        -- the CAS kept on it (going back up it would fall at a true
        -- airspeed), the deceleration before it; one deceleration ending
        -- at the constraint, its CAS not rising on the way, the T/D before
        -- it
        local vsteep = {{name = "CRZ", dist = 250},
            {name = "A", dist = 80, con = {kind = "W", a = 25000, b = 24000}},
            {name = "B", dist = 20, con = {kind = "W", a = 16000, b = 15000}, spd = 250},
            {name = "RW", dist = 50, con = {kind = "AT", a = 150}}}
        local rv = PM.predict{P = P, t = pw, gw = 250000, fuel = 40000, alt = 37000, phase = "crz", crz = 37000,
            clb = clb, des = des3, crzspd = {mach = 0.85}, legs = vsteep, ed = #vsteep}
        local pB = rv.pts[3]
        T.near(at(rv, pB.x), 250, 0.5, string.format("very steep: the path at B %.1f kt", at(rv, pB.x)))
        local dv = nil
        for _, e in ipairs(decels(rv)) do if math.abs(e.x1 - pB.x) < 0.05 then dv = e end end
        T.check(dv ~= nil and dv.c == 250, "very steep: a deceleration to 250 ending at B")
        local mono = true
        for i = 2, #rv.dp.x do
            if rv.dp.k[i] == "decel" and rv.dp.s[i] < rv.dp.s[i - 1] - 1e-6 then mono = false end
        end
        T.check(mono, "very steep: no CAS rising on the way in a deceleration")
        T.check(rv.td and dv and rv.td < dv.x0 and dv.h0 < 37000,
            string.format("very steep: the T/D (%.1f NM) before the deceleration (from %.1f NM, %.0f ft)", rv.td or -1, dv and dv.x0 or -1, dv and dv.h0 or -1))
        -- (2026-11-09's review) a 250 kt constraint just under the cruise
        -- altitude (AT 32,900 at FL330), its deceleration reaching back up
        -- to FL330: the T/D's level deceleration on to the path's planned
        -- CAS at its top (before, to the schedule's: the airplane at the
        -- path 17 kt over its plan)
        local function crzX(spd)
            local lx = {{name = "CRZ", dist = 200}, {name = "X", dist = 100, con = {kind = "AT", a = 32900}, spd = spd},
                {name = "RW", dist = 120, con = {kind = "AT", a = 150}}}
            return PM.predict{P = P, t = pw, gw = 250000, fuel = 40000, alt = 33000, phase = "crz", crz = 33000,
                clb = clb, des = des3, crzspd = {mach = 0.85}, legs = lx, ed = #lx}
        end
        local rX, rN = crzX(250), crzX(nil)
        local xt = nil
        for i = 2, #rX.dp.x do
            if rX.dp.h[i] >= 33000 - 1 then
                local f = (33000 - rX.dp.h[i - 1]) / math.max(rX.dp.h[i] - rX.dp.h[i - 1], 1e-9)
                xt = rX.dp.x[i - 1] + (rX.dp.x[i] - rX.dp.x[i - 1]) * math.min(math.max(f, 0), 1)
                break
            end
        end
        local pcTop = xt and at(rX, xt)
        local sched = PM.schedule(P, des3, 33000)
        T.check(pcTop and pcTop < sched - 5, string.format("near the cruise: the path at FL330 %.1f kt (the schedule's %.1f)", pcTop or -1, sched))
        -- the level deceleration from M.85 at FL330 to it, at idle
        local kgX = 250000 - 40000 + rX.pts[1].fuel
        local tas, dxs = P.tas(0.85, 33000), 0
        local c = P.mach_to_cas(0.85, 33000)
        while pcTop and c > pcTop + 0.5 do
            dxs = dxs + tas * KT * 2 / NM
            tas = tas - P.drag(pw, kgX, 33000, P.cas_to_mach(c, 33000)) / kgX * 2 / KT
            c = P.mach_to_cas(tas / P.tas(1, 33000), 33000)
        end
        T.near(rX.td_decel or -1, dxs, 0.3, string.format("the T/D's level deceleration %.2f NM to it (%.2f by the drag; without the constraint %.2f)",
            rX.td_decel or -1, dxs, rN.td_decel or -1))
    end
    -- (2026-11-09's review) a deceleration keeps the altitude constraints
    -- inside it: along a constraint's line, or level at its altitude
    -- (before, DECEL_VS whatever them). AT 6,000, 210 kt alone 4 NM after
    -- it, AT 6,000 again: level at 6,000 (before, 6,607 ft at the first);
    -- AT 7,000 with 210 kt 3 NM after it: 7,000 (before, 6,609 ft)
    local function run2(legs)
        return PM.predict{P = P, t = pw, gw = 250000, fuel = 40000, alt = 37000, phase = "crz", crz = 37000,
            clb = clb, des = des2, crzspd = {mach = 0.85}, legs = legs, ed = #legs}
    end
    local rA = run2({{name = "CRZ", dist = 250}, {name = "C", dist = 80, con = {kind = "W", a = 13000, b = 12000}},
        {name = "E", dist = 30, con = {kind = "AT", a = 6000}}, {name = "M", dist = 4, spd = 210},
        {name = "E2", dist = 6, con = {kind = "AT", a = 6000}}, {name = "RW", dist = 18, con = {kind = "AT", a = 150}}})
    T.near(rA.pts[3].h, 6000, 1, string.format("AT 6,000, 210 kt 4 NM on, AT 6,000: the first at %.0f ft", rA.pts[3].h))
    T.near(rA.pts[4].h, 6000, 1, string.format("the 210 kt's point level at %.0f ft", rA.pts[4].h))
    T.near(at(rA, rA.pts[4].x), 210, 0.5, "its 210 kt there")
    local lvl = true
    for i = 1, #rA.dp.x do
        if rA.dp.x[i] >= rA.pts[3].x - 1e-6 and rA.dp.x[i] <= rA.pts[5].x + 1e-6 and math.abs(rA.dp.h[i] - 6000) > 1 then lvl = false end
    end
    T.check(lvl, "the deceleration level between the two AT 6,000")
    local rB = run2({{name = "CRZ", dist = 250}, {name = "C", dist = 80, con = {kind = "W", a = 13000, b = 12000}},
        {name = "E", dist = 30, con = {kind = "AT", a = 7000}}, {name = "M", dist = 3, spd = 210},
        {name = "RW", dist = 24, con = {kind = "AT", a = 150}}})
    T.near(rB.pts[3].h, 7000, 1, string.format("AT 7,000 with 210 kt 3 NM on: at %.0f ft", rB.pts[3].h))
    T.near(at(rB, rB.pts[4].x), 210, 0.5, "210 kt at its point")
end

-- (FMC-08) the climb's: until passing its waypoint (FMSPG p.3.3-17), not
-- under clb_floor (VREF + 100: FCOM p.1326); the climb faster after it
do
    local function sid(spd, floor)
        local legs = {{name = "S1", dist = 30, con = {kind = "A", a = 5000}, spd = spd},
            {name = "S2", dist = 30}, {name = "CRZ", dist = 400}, {name = "RW", dist = 150, con = {kind = "AT", a = 50}}}
        return PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 1500, cas = 220, phase = "clb", crz = 35000,
            clb = clb, des = des, crzspd = {mach = 0.85}, legs = legs, ed = 4, clb_last = 2, clb_floor = floor}
    end
    local r0, r1, r2 = sid(nil), sid(230, 220), sid(230, 245)
    T.near(r1.pts[1].cas, 230, 0.5, string.format("S1 230 kt: its predicted speed %.0f", r1.pts[1].cas))
    T.near(r2.pts[1].cas, 245, 0.5, string.format("under VREF + 100 (245): %.0f", r2.pts[1].cas))
    T.check(r0.pts[1].cas >= 250, string.format("(without: the schedule's %.0f at %.0f ft)", r0.pts[1].cas, r0.pts[1].h))
    T.check(r1.pts[1].t > r0.pts[1].t + 5, string.format("S1 %.0f s later at 230 kt", r1.pts[1].t - r0.pts[1].t))
    T.near(r1.pts[2].cas, r0.pts[2].cas, 0.5, string.format("S2 after it: %.0f kt as without", r1.pts[2].cas))
end

-- (2026-11-09's review) a climb's level segment at an altitude constraint
-- at the climb's speed (FCOM p.1255: VNAV PTH holds the climb's command
-- speed there), within the climb's waypoint constraint: AT 5,000 at S1 40
-- NM out from 1,500 ft. Before, the cruise's Mach at 5,000 ft (M.85, 519
-- kt CAS): S1 at 467 kt on average
do
    local function sid(spd)
        return PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 1500, cas = 200, phase = "clb", crz = 35000,
            clb = clb, des = des, crzspd = {mach = 0.85}, legs = {{name = "S1", dist = 40, con = {kind = "AT", a = 5000}, spd = spd},
            {name = "S2", dist = 30}, {name = "CRZ", dist = 400}, {name = "RW", dist = 150, con = {kind = "AT", a = 50}}}, ed = 4, clb_last = 2}
    end
    local r220, r0 = sid(220), sid(nil)
    local tas220, tas250 = P.tas(P.cas_to_mach(220, 5000), 5000), P.tas(P.cas_to_mach(250, 5000), 5000)
    local gs220, gs0 = 40 / r220.pts[1].t * 3600, 40 / r0.pts[1].t * 3600
    T.check(r220.pts[1].h == 5000 and gs220 > 200 and gs220 < tas220 + 2,
        string.format("level at 5,000 ft with 220 kt: S1 at %.0f kt on average (220 kt's TAS %.0f)", gs220, tas220))
    T.check(gs0 > gs220 and gs0 < tas250 + 2,
        string.format("without the constraint the climb's 250 kt below 10,000 ft: %.0f kt (TAS %.0f)", gs0, tas250))
end

-- (2026-11-11 review) a climb's level segment at an AT OR BELOW whose T/D
-- for that altitude is already behind: the descent starts there. Before,
-- the segment returned without moving and the climb repeated it forever
-- (in XTLua the FMC's plugin froze): a SID's AT OR BELOW FL150 at 55 NM on
-- a 92 NM route, CRZ FL250 (the review's case). An instruction-count hook
-- (the JIT off) ends a run that does not
do
    local rest = 92 - 55
    local legs = {{name = "SID1", dist = 55, con = {kind = "B", a = 15000}, proc = "SID"},
        {name = "ENR", dist = rest * 0.6}, {name = "IAF", dist = rest * 0.3, con = {kind = "AT", a = 3000}, proc = "STAR"},
        {name = "RW", dist = rest * 0.1, con = {kind = "AT", a = 50}, proc = "APPR"}}
    local jitWas = jit and jit.status and jit.status()
    if jit then jit.off() end
    local ticks = 0
    debug.sethook(function()
        ticks = ticks + 1
        if ticks > 400 then error("the prediction did not end", 0) end
    end, "", 1000000)
    local ok, r = pcall(PM.predict, {P = P, t = pw, gw = 330000, fuel = 50000, alt = 30, phase = "clb", crz = 25000,
        clb = clb, des = {cas = 300, mach = 0.84, trans_cas = 240, trans_alt = 10000},
        crzspd = {fn = function(h, kg) return (P.lrc(pw, kg, h)) end}, legs = legs, ed = 4, clb_last = 1})
    debug.sethook()
    if jit and jitWas then jit.on() end
    T.check(ok, "a climb's level segment past its T/D: the prediction ends (" .. tostring(ok and "" or r) .. ")")
    if ok then
        -- up to FL150, then down from its T/D (about 34 NM): SID1 crossed
        -- descending, the runway reached
        T.check(r.tc == nil and r.td ~= nil and r.td < 55 and r.pts[1].h <= 15001 and r.pts[4].h <= 60,
            string.format("no T/C, the descent from FL150 at its T/D %.0f NM: SID1 at %.0f ft, the runway at %.0f",
                r.td or -1, r.pts[1].h or -1, r.pts[4].h or -1))
    end
end

T.done()
