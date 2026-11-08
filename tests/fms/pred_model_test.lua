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
    end
end
T.check(r.td_decel < 1.5, string.format("M.85 at FL350 to the descent's M.84: a short level deceleration (%.1f NM)", r.td_decel))
-- each waypoint's speed: the climb's, the cruise's Mach, the descent's
T.check(r.pts[1].cas == 340 and not r.pts[1].machMode, "C1 in the climb: 340 kt")
T.check(r.pts[3].machMode and r.pts[3].mach == 0.85, "MID in the cruise: M.85")
T.check(r.pts[5].cas == 290 and not r.pts[5].machMode, "D2 in the descent at 10,000 ft: 290 kt")
T.check(r.pts[6].cas == 250, "the runway below 10,000 ft: 250 kt")

-- (step LF1) the T/D's level deceleration (FCOM p.1264): cruising at M.80
-- at FL250 (about 333 kt, s198's) to the descent's 290 kt, idle at FL250
-- before the path leaves it, the T/D at its start
do
    local legsL = {{name = "A", dist = 200}, {name = "RW", dist = 120, con = {kind = "AT", a = 50}}}
    local rl = PM.predict{P = P, t = pw, gw = 300000, fuel = 80000, alt = 25000, phase = "crz", crz = 25000, clb = clb, des = des,
        crzspd = {mach = 0.80}, legs = legsL, ed = 2}
    local dp = rl.dp
    local top
    for i = 1, #dp.x do if dp.h[i] >= 25000 - 1 then top = dp.x[i] break end end
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

T.done()
