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

T.done()
