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
-- each waypoint's speed: the climb's, the cruise's Mach, the descent's
T.check(r.pts[1].cas == 340 and not r.pts[1].machMode, "C1 in the climb: 340 kt")
T.check(r.pts[3].machMode and r.pts[3].mach == 0.85, "MID in the cruise: M.85")
T.check(r.pts[5].cas == 290 and not r.pts[5].machMode, "D2 in the descent at 10,000 ft: 290 kt")
T.check(r.pts[6].cas == 250, "the runway below 10,000 ft: 250 kt")

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

T.done()
