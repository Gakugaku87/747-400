-- Run from the repository root with LuaJIT: luajit tests/fuel/fuel_fail_test.lua
-- The fuel model's failures (2026-11-04; docs/overhaul/notes/ATA-28.md §11):
-- a pump (its low pressure: FUEL PUMP, the PRESS light, suction feed with
-- both main pumps of a tank and the crossfeed closed: FUEL PRESS ENG), a
-- valve stuck (FUEL X FEED, >JETT NOZZLE, FUEL RES XFR from the existing
-- disagreement logic), the temperature sensor (FUEL TEMP SYS), FJCC A and B
-- (>FUEL JETT A, B; both: FUEL JETT SYS). FCOM p.1473-1479.
local T = dofile("tests/lib/check.lua")("fuel_fail")
local F = dofile("plugins/xtlua/scripts/B747.25.xt.fuel/B747.28.fuel_model.lua")

local DT = 1 / 30
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = F.update(s, inp, DT) end
    return out
end
local MAINS = {"m1_fwd", "m1_aft", "m2_fwd", "m2_aft", "m3_fwd", "m3_aft", "m4_fwd", "m4_aft"}
-- in cruise, tank to engine (no CWT fuel), main pumps ON, crossfeeds open
local function cruise()
    local s, inp = F.new(), F.inputs()
    for n = 1, 4 do
        inp.ac[n], inp.util[n], inp.dc[n] = true, true, true
        inp.fuel_control[n], inp.running[n], inp.ff[n] = true, true, 0.6
    end
    inp.main_bat, inp.hot_bat, inp.gs_bus = true, true, true
    inp.on_ground = false
    for t, kg in pairs({ctr = 0, m1 = 10000, m2 = 20000, m3 = 20000, m4 = 10000, r2 = 0, r3 = 0, stab = 0}) do
        s.qty[t] = kg
    end
    for _, id in ipairs(MAINS) do inp.sw[id] = true end
    run(s, inp, 6)
    return s, inp
end

-- nothing failed
do
    local s, inp = cruise()
    local out = run(s, inp, 1)
    for _, id in ipairs(MAINS) do T.check(not out.cas[id] and not out.light[id], "(normal: no FUEL PUMP or PRESS light " .. id .. ")") end
    T.check(not out.cas.temp_sys and not out.cas.jett_a and not out.cas.jett_b and not out.cas.jett_sys,
        "normal: no FUEL TEMP SYS, FUEL JETT A, B or SYS")
end

-- a main pump: its low pressure, FUEL PUMP 2 AFT and the PRESS light; both
-- pumps of main 2 with crossfeed 2 closed: suction feed, FUEL PRESS ENG 2,
-- which hides the FUEL PUMP messages (FCOM p.1477, p.1582)
do
    local s, inp = cruise()
    inp.fail.pump.m2_aft = true
    local out = run(s, inp, 1)
    T.check(not out.pump.m2_aft and out.low.m2_aft, "pump 2 AFT failed: not running, low pressure")
    T.check(out.cas.m2_aft and out.light.m2_aft, "FUEL PUMP 2 AFT, PRESS light (FCOM p.1477)")
    T.check(not out.cas.press_eng2, "one pump: no FUEL PRESS ENG 2")
    inp.fail.pump.m2_fwd = true
    inp.xfeed[2] = false
    out = run(s, inp, 10)
    T.check(out.suction[2] and out.cas.press_eng2, "both main 2 pumps and crossfeed 2 closed: suction feed, FUEL PRESS ENG 2")
    T.check(not out.cas.m2_aft and not out.cas.m2_fwd, "FUEL PRESS ENG 2 hides FUEL PUMP 2 FWD and AFT")
    inp.fail.pump.m2_aft, inp.fail.pump.m2_fwd = false, false
    out = run(s, inp, 1)
    T.check(not out.cas.press_eng2 and not out.cas.m2_aft, "the pumps back: the messages go")
end

-- a crossfeed valve stuck: commanded closed it stays open, FUEL X FEED 2
-- after the disagreement time (FCOM p.1479); the X FEED VALVE light
do
    local s, inp = cruise()
    inp.fail.valve.x2 = true
    inp.xfeed[2] = false
    local out = run(s, inp, 2)
    T.equal(out.valve.x2, 1, "crossfeed 2 stuck: still open")
    out = run(s, inp, 30)
    T.check(out.cas.xfeed2, "FUEL X FEED 2 (FCOM p.1479)")
    T.check(out.light.x2, "the X FEED 2 VALVE light")
    inp.fail.valve.x2 = false
    out = run(s, inp, 10)
    T.equal(out.valve.x2, 0, "unstuck: crossfeed 2 closes")
    T.check(not out.cas.xfeed2, "FUEL X FEED 2 goes")
end

-- a nozzle valve stuck closed: >JETT NOZZLE L with the switch ON (FCOM p.1479)
do
    local s, inp = cruise()
    inp.fail.valve.noz_l = true
    inp.nozzle[1] = true
    local out = run(s, inp, 30)
    T.equal(out.valve.noz_l, 0, "nozzle L stuck: closed")
    T.check(out.cas.jett_nozzle_l, ">JETT NOZZLE L")
end

-- the temperature sensor: FUEL TEMP SYS, and no FUEL TEMP LOW from it
do
    local s, inp = cruise()
    inp.temp = -40
    local out = run(s, inp, 1)
    T.check(out.cas.temp_low and not out.cas.temp_sys, "(-40 degrees: FUEL TEMP LOW)")
    inp.fail.temp = true
    out = run(s, inp, 1)
    T.check(out.cas.temp_sys, "the sensor failed: FUEL TEMP SYS (FCOM p.1478)")
    T.check(not out.cas.temp_low, "no FUEL TEMP LOW from the failed sensor (estimate)")
end

-- the FJCCs: A failed, >FUEL JETT A; selector at A: not armed, at B:
-- armed; both failed: FUEL JETT SYS, which hides >FUEL JETT A and B
do
    local s, inp = cruise()
    inp.fail.fjcc[1] = true
    local out = run(s, inp, 1)
    T.check(out.cas.jett_a and not out.cas.jett_b and not out.cas.jett_sys, "FJCC A: >FUEL JETT A (FCOM p.1474)")
    inp.jett_sel = 1
    out = run(s, inp, 1)
    T.check(not out.armed, "selector A with FJCC A failed: not armed (estimate)")
    inp.jett_sel = 2
    out = run(s, inp, 1)
    T.check(out.armed, "selector B: armed")
    inp.fail.fjcc[2] = true
    out = run(s, inp, 1)
    T.check(out.cas.jett_sys, "both FJCCs: FUEL JETT SYS (FCOM p.1474)")
    T.check(not out.cas.jett_a and not out.cas.jett_b, "FUEL JETT SYS hides >FUEL JETT A and B")
end

T.done()
