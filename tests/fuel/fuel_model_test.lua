-- Run from the repository root with LuaJIT: luajit tests/fuel/fuel_model_test.lua
-- The fuel model (plugins/xtlua/scripts/B747.25.xt.fuel/B747.28.fuel_model.lua)
-- against FCOM 12.20-12.30 (p.1453-1479, airplane 109) and ATA26_28: the
-- normal flows (preflight, CWT fuel, takeoff, after takeoff, tank to
-- engine), suction feed, crossfeed balancing (SP.12), reserve, scavenge and
-- stabilizer transfer, jettison, the EICAS messages and the lights.
local T = dofile("tests/lib/check.lua")("fuel_model")
local F = dofile("plugins/xtlua/scripts/B747.25.xt.fuel/B747.28.fuel_model.lua")

local DT = 1 / 30
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = F.update(s, inp, DT) end
    return out
end
-- powered on the ground, the tanks as given, crossfeed switches ON
local function aircraft(qty)
    local s, inp = F.new(), F.inputs()
    for n = 1, 4 do inp.ac[n], inp.util[n], inp.dc[n] = true, true, true end
    inp.main_bat, inp.hot_bat, inp.gs_bus = true, true, true
    for t, kg in pairs(qty) do s.qty[t] = kg end
    return s, inp
end
local FULL = {ctr = 40000, m1 = 12000, m2 = 36000, m3 = 36000, m4 = 12000, r2 = 4000, r3 = 4000, stab = 8000}
local function copy(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
local function pumps_on(inp, list)
    for _, id in ipairs(list) do inp.sw[id] = true end
end
local MAINS = {"m1_fwd", "m1_aft", "m2_fwd", "m2_aft", "m3_fwd", "m3_aft", "m4_fwd", "m4_aft"}
local OJS = {"oj2_fwd", "oj2_aft", "oj3_fwd", "oj3_aft"}
local function engines_running(inp)
    for n = 1, 4 do inp.fuel_control[n], inp.running[n], inp.ff[n] = true, true, 0.6 end
end
local function from(out, n) -- the one tank engine n draws from (or "shared")
    local t, count = nil, 0
    for k, share in pairs(out.feed[n]) do if share > 0 then t, count = k, count + 1 end end
    return (count == 1) and t or ((count > 1) and "shared" or nil)
end

-- preflight (FCOM p.1465): pump switches OFF: the main pump PRESS lights on,
-- the override and CWT lights off; crossfeed valves open with their switches
do
    local s, inp = aircraft(FULL)
    local out = run(s, inp, 6)
    for _, id in ipairs(MAINS) do T.check(out.light[id], "preflight: PRESS light " .. id) end
    for _, id in ipairs({"oj2_fwd", "oj3_aft", "ctr_l", "ctr_r"}) do T.check(not out.light[id], "preflight: no PRESS light " .. id) end
    for n = 1, 4 do T.equal(out.valve["x" .. n], 1, "preflight: crossfeed " .. n .. " open") end
    T.check(out.cas.m1_fwd and out.cas.m4_aft, "preflight: FUEL PUMP messages with the pumps low (FCOM p.1477)")
    T.check(out.cas.oj2_fwd, "preflight: FUEL OVRD 2 FWD with its switch OFF before tank to engine (FCOM p.1474)")
    T.check(out.cas.ovd_ctr_l and out.cas.ovd_ctr_r, "preflight: >FUEL OVD CTR with 40 t in the CWT and the switches OFF")
    T.check(not out.cas.press_eng1, "preflight: no FUEL PRESS ENG with the engines stopped")
end

-- before start with fuel in the CWT (FCOM p.1465, NP p.119): main, override
-- and CTR pumps ON: the CWT feeds all four engines through the open crossfeeds
do
    local s, inp = aircraft(FULL)
    pumps_on(inp, MAINS); pumps_on(inp, OJS); pumps_on(inp, {"ctr_l", "ctr_r"})
    engines_running(inp)
    local out = run(s, inp, 6)
    for n = 1, 4 do T.equal(from(out, n), "ctr", "CWT: engine " .. n .. " from the CWT") end
    for _, id in ipairs(OJS) do T.check(not out.pump[id], "CWT: " .. id .. " held off by both CWT pumps (FCOM p.1465)") end
    T.check(not out.cas.ovd_ctr_l and not out.cas.low_ctr_l, "CWT: no CTR messages")
    for _, id in ipairs(MAINS) do T.check(not out.cas[id], "CWT: no FUEL PUMP " .. id) end
    -- takeoff flaps on the ground: crossfeeds 2 and 3 close after 40 s
    -- (ATA26_28 p.461); CWT to engines 1 and 4, mains 2 and 3 to theirs
    inp.flap_lever = 0.5
    out = run(s, inp, 30)
    T.equal(out.valve.x2, 1, "takeoff flaps: crossfeed 2 still open at 30 s")
    out = run(s, inp, 16)
    T.equal(out.valve.x2, 0, "takeoff flaps: crossfeed 2 closed after 40 s")
    T.equal(out.valve.x3, 0, "takeoff flaps: crossfeed 3 closed")
    T.equal(from(out, 1), "ctr", "takeoff: engine 1 from the CWT")
    T.equal(from(out, 2), "m2", "takeoff: engine 2 from main 2 (FCOM p.1465)")
    T.equal(from(out, 3), "m3", "takeoff: engine 3 from main 3")
    T.equal(from(out, 4), "ctr", "takeoff: engine 4 from the CWT")
    T.check(not out.cas.xfeed_config, "takeoff: no >X FEED CONFIG with the flaps in the takeoff range")
    -- airborne with the flaps still at 10: held closed; flaps up: open (FCOM p.1466)
    inp.on_ground = false
    out = run(s, inp, 10)
    T.equal(out.valve.x2, 0, "air, flaps 10: crossfeed 2 held closed")
    inp.flap_lever = 0
    out = run(s, inp, 6)
    T.equal(out.valve.x2, 1, "air, flaps up: crossfeed 2 open")
    for n = 1, 4 do T.equal(from(out, n), "ctr", "after takeoff: engine " .. n .. " from the CWT (FCOM p.1466)") end
end

-- less than 7,700 kg in the CWT, CTR OFF (FCOM p.1466): override/jettison 2
-- to engine 1, 3 to engine 4 on takeoff; then 2 to engines 1 and 2, 3 to 3 and 4
do
    local q = copy(FULL); q.ctr = 5000
    local s, inp = aircraft(q)
    pumps_on(inp, MAINS); pumps_on(inp, OJS)
    engines_running(inp)
    inp.flap_lever = 0.667
    local out = run(s, inp, 45)
    T.check(out.pump.oj2_fwd and out.pump.oj3_aft, "CTR OFF: override/jettison 2 and 3 run (FCOM p.1467)")
    T.equal(from(out, 1), "m2", "CTR OFF takeoff: engine 1 from main 2 (override/jettison 2)")
    T.equal(from(out, 4), "m3", "CTR OFF takeoff: engine 4 from main 3")
    T.equal(from(out, 2), "m2", "CTR OFF takeoff: engine 2 from main 2")
    inp.on_ground, inp.flap_lever = false, 0
    out = run(s, inp, 6)
    T.equal(from(out, 2), "m2", "CTR OFF after takeoff: engine 2 from main 2")
    T.equal(from(out, 3), "m3", "CTR OFF after takeoff: engine 3 from main 3")
    T.equal(from(out, 1), "m2", "CTR OFF after takeoff: engine 1 still from main 2 (left side)")
    T.check(out.cas.ovd_ctr_l and not out.cas.low_ctr_l, "CTR OFF in cruise (pitch 0) with 5 t: >FUEL OVD CTR (1,800 kg or more)")
    inp.pitch = 8
    out = run(s, inp, 1)
    T.check(not out.cas.ovd_ctr_l, "CTR OFF in climb (pitch 8): no >FUEL OVD CTR")
end

-- a CWT pump low with its switch ON starts override/jettison 2 and 3 (FCOM p.1467)
do
    local s, inp = aircraft(FULL)
    pumps_on(inp, MAINS); pumps_on(inp, OJS); pumps_on(inp, {"ctr_l", "ctr_r"})
    inp.util[2] = false                                   -- CTR L's bus (estimate) lost
    local out = run(s, inp, 2)
    T.check(out.pump.oj2_aft and out.pump.oj3_aft, "CTR L low: override/jettison pumps run")
    T.check(out.light.ctr_l, "CTR L low: its PRESS light (switch ON)")
    T.check(out.cas.press_ctr_l, "CTR L low: FUEL PRESS CTR L (low pump with the switch ON)")
end

-- tank to engine (FCOM p.1467, NP p.135): >FUEL TANK/ENG when main 2 is down
-- to main 1; override OFF and crossfeeds 1 and 4 OFF: each engine its own tank
do
    local q = {ctr = 0, m1 = 9000, m2 = 9000, m3 = 9500, m4 = 9000, r2 = 0, r3 = 0, stab = 0}
    local s, inp = aircraft(q)
    pumps_on(inp, MAINS); pumps_on(inp, OJS)
    engines_running(inp)
    inp.on_ground = false
    local out = run(s, inp, 2)
    T.check(out.cas.tank_eng, ">FUEL TANK/ENG with main 2 down to main 1 and crossfeed 1 open")
    T.check(not out.cas.oj2_fwd, "no FUEL OVRD with the switches ON")
    for _, id in ipairs(OJS) do inp.sw[id] = false end
    inp.xfeed[1], inp.xfeed[4] = false, false
    out = run(s, inp, 6)
    T.check(not out.cas.tank_eng, "tank to engine: >FUEL TANK/ENG gone with crossfeeds 1 and 4 closed")
    for n = 1, 4 do T.equal(from(out, n), "m" .. n, "tank to engine: engine " .. n .. " from main " .. n) end
    T.check(not out.cas.oj2_fwd, "tank to engine: no FUEL OVRD with the switch OFF after tank to engine")
    T.check(not out.cas.xfeed_config, "tank to engine: no >X FEED CONFIG")
end

-- suction feed (FCOM p.1455, p.1477): both main pumps of a tank lost with its
-- crossfeed closed: the engine keeps running from its tank, FUEL PRESS ENG
do
    local q = {ctr = 0, m1 = 9000, m2 = 9000, m3 = 9000, m4 = 9000, r2 = 0, r3 = 0, stab = 0}
    local s, inp = aircraft(q)
    pumps_on(inp, MAINS)
    engines_running(inp)
    inp.xfeed[1], inp.xfeed[4] = false, false
    inp.ac[1] = false                                     -- main 1's pumps (estimate)
    local out = run(s, inp, 6)
    T.check(out.suction[1] and out.has_fuel[1], "suction: engine 1 still fed from main 1")
    T.check(out.cas.press_eng1, "suction: FUEL PRESS ENG 1")
    T.check(not out.cas.m1_fwd and not out.cas.m1_aft, "suction: FUEL PUMP 1 messages give way to it")
    inp.xfeed[1] = true
    out = run(s, inp, 6)
    T.check(not out.suction[1] and from(out, 1) ~= "m1", "crossfeed 1 opened: engine 1 fed under pressure from another tank")
end

-- crossfeed balancing (SP.12, FCOM p.199): crossfeeds 1 and 4 open, main 1
-- pumps OFF: engine 1 feeds from main 4 and main 1 keeps its fuel
do
    local q = {ctr = 0, m1 = 7000, m2 = 9000, m3 = 9000, m4 = 9000, r2 = 0, r3 = 0, stab = 0}
    local s, inp = aircraft(q)
    pumps_on(inp, MAINS)
    engines_running(inp)
    inp.xfeed[2], inp.xfeed[3] = false, false
    inp.sw.m1_fwd, inp.sw.m1_aft = false, false
    F.settle(s, inp)
    local out = run(s, inp, 60)
    T.equal(from(out, 1), "m4", "balancing: engine 1 from main 4")
    T.equal(s.qty.m1, 7000, "balancing: main 1 unchanged")
    T.near(s.qty.m4, 9000 - 2 * 0.6 * 60, 1, "balancing: main 4 feeds engines 1 and 4")
end

-- reserve transfer (FCOM p.1464, p.1467): in the air at 18,200 kg in main 2
-- or 3, all four valves open; closed on the ground
do
    local q = {ctr = 0, m1 = 9000, m2 = 18300, m3 = 19000, m4 = 9000, r2 = 4000, r3 = 4000, stab = 0}
    local s, inp = aircraft(q)
    pumps_on(inp, MAINS)
    engines_running(inp)
    inp.on_ground = false
    local out = run(s, inp, 2)
    T.check(not out.res_open, "reserve: shut above 18,200 kg")
    s.qty.m2 = 18150
    out = run(s, inp, 6)
    T.check(out.res_open and out.valve.res3a == 1, "reserve: all four valves open at 18,200 kg in main 2")
    out = run(s, inp, 60)
    T.check(s.qty.r3 < 4000 and s.qty.r2 < 4000, "reserve: both reserve tanks drain into mains 2 and 3")
    T.check(not out.cas.res_xfr, "reserve: no FUEL RES XFR")
    inp.dc[1] = false                                     -- the valves' bus lost on the ground: they cannot close
    inp.on_ground = true
    out = run(s, inp, 15)
    T.check(out.cas.res_xfr, "reserve: FUEL RES XFR when the valves cannot close (10 s, ATA26_28 p.498)")
end

-- scavenge (FCOM p.1454, ATA26_28 p.512): below 27,200 kg in main 2 and with
-- the CWT under its float level, two jet pumps into main 2
do
    local q = {ctr = 1500, m1 = 9000, m2 = 25000, m3 = 30000, m4 = 9000, r2 = 4000, r3 = 4000, stab = 0}
    local s, inp = aircraft(q)
    pumps_on(inp, MAINS)
    inp.on_ground = false
    run(s, inp, 3600)
    T.near(s.qty.ctr, 1500 - 272, 2, "scavenge: 272 kg in an hour into main 2 only (main 3 above 27,200 kg)")
end

-- stabilizer transfer (109, FCOM p.1455, p.1466): in flight, flaps up, CWT
-- under 36,470 kg; >FUEL PMP STB on the ground with the switch ON
do
    local q = copy(FULL); q.ctr = 30000
    local s, inp = aircraft(q)
    pumps_on(inp, MAINS); pumps_on(inp, {"stab_l", "stab_r"})
    local out = run(s, inp, 2)
    T.check(out.cas.pmp_stab_l and out.cas.pmp_stab_r, "stab: >FUEL PMP STB on the ground with the switches ON")
    T.check(not out.pump.stab_l, "stab: no transfer on the ground")
    inp.on_ground = false
    out = run(s, inp, 60)
    T.check(out.pump.stab_l and out.pump.stab_r, "stab: pumps run in flight with the flaps up")
    T.check(s.qty.stab < 8000 and s.qty.ctr > 30000, "stab: fuel moves to the CWT")
    s.qty.stab = 0
    out = run(s, inp, 2)
    T.check(out.cas.pres_stab_l, "stab: FUEL PRES STB L when empty and still commanded")
    out = run(s, inp, 31)
    T.check(not out.pump.stab_l, "stab: the pump stops itself after the delay (estimate 30 s)")
end

-- jettison (FCOM p.1468-1470): selector A, a nozzle ON: override/jettison
-- pumps and CWT pumps run, valves open, fuel goes overboard; at the fuel to
-- remain everything stops, FUEL OVRD for the pumps that ran until OFF
do
    local q = copy(FULL); q.stab = 0
    local s, inp = aircraft(q)
    pumps_on(inp, MAINS); pumps_on(inp, OJS); pumps_on(inp, {"ctr_l", "ctr_r"})
    engines_running(inp)
    inp.on_ground = false
    inp.jett_sel, inp.ftr = 1, 125000
    local out = run(s, inp, 2)
    T.check(out.armed and not out.jett, "jettison: armed, not yet with the nozzles OFF")
    T.check(out.jett_min > 0, "jettison: a time to go on the synoptic")
    inp.nozzle[1], inp.nozzle[2] = true, true
    out = run(s, inp, 10)
    T.check(out.jett, "jettison: running")
    T.check(out.pump.oj2_fwd and out.pump.oj3_aft, "jettison: override/jettison pumps run")
    T.check(out.valve.jett_m2 == 1 and out.valve.noz_l == 1, "jettison: valves open")
    T.check(out.cas.jett_noz and not out.cas.jett_noz_l, ">JETT NOZ ON (both), not L alone")
    local before = out.total
    out = run(s, inp, 60)
    T.check(out.total < before - 1000, "jettison: fuel goes overboard")
    for _ = 1, 600 do
        out = run(s, inp, 10)
        if out.jett_done then break end
    end
    T.check(out.jett_done and out.total <= 125000 + 500, "jettison: stops at the fuel to remain")
    T.check(not out.pump.oj2_fwd and not out.pump.ctr_l, "jettison done: override/jettison and CWT pumps off")
    T.check(out.cas.oj2_fwd, "jettison done: FUEL OVRD 2 FWD until the selector is OFF (FCOM p.1469)")
    inp.jett_sel = 0
    inp.nozzle[1], inp.nozzle[2] = false, false
    out = run(s, inp, 6)
    T.check(not out.cas.oj2_fwd, "selector OFF: FUEL OVRD gone")
end

-- imbalance messages and their hysteresis (FCOM p.1473)
do
    local q = {ctr = 0, m1 = 9000, m2 = 20000, m3 = 20000, m4 = 7600, r2 = 0, r3 = 0, stab = 0}
    local s, inp = aircraft(q)
    local out = run(s, inp, 1)
    T.check(out.cas.imbal14, "FUEL IMBAL 1-4 at 1,400 kg")
    s.qty.m4 = 8000
    out = run(s, inp, 1)
    T.check(out.cas.imbal14, "FUEL IMBAL 1-4 stays above 450 kg")
    s.qty.m4 = 8600
    out = run(s, inp, 1)
    T.check(not out.cas.imbal14, "FUEL IMBAL 1-4 gone under 450 kg")
    s.qty.m2 = 23000
    out = run(s, inp, 1)
    T.check(out.cas.imbal23, "FUEL IMBAL 2-3 at 3,000 kg")
end

-- CWT messages (FCOM p.1475-1476): low before start with the switches ON,
-- FUEL PRESS CTR after 60 s
do
    local q = copy(FULL); q.ctr = 6000
    local s, inp = aircraft(q)
    pumps_on(inp, {"ctr_l", "ctr_r"})
    local out = run(s, inp, 2)
    T.check(out.cas.low_ctr_l and out.cas.low_ctr_r, ">FUEL LOW CTR before start under 7,700 kg")
    T.check(not out.cas.press_ctr_l, "no FUEL PRESS CTR yet")
    out = run(s, inp, 60)
    T.check(out.cas.press_ctr_l, "FUEL PRESS CTR after 60 s of FUEL LOW CTR")
end

-- valves without power hold their place; the spar valves follow the FUEL
-- CONTROL switches and the fire switches (ATA26_28 p.454, p.464, p.466)
do
    local s, inp = aircraft(FULL)
    pumps_on(inp, MAINS)
    engines_running(inp)
    local out = run(s, inp, 6)
    T.check(out.has_fuel[1] and out.valve.s1 == 1, "spar valve 1 open with FUEL CONTROL RUN")
    inp.main_bat = false
    inp.xfeed[1] = false
    out = run(s, inp, 6)
    T.equal(out.valve.x1, 1, "no main battery bus: crossfeed 1 stays open")
    out = run(s, inp, 6)
    T.check(out.cas.xfeed1, "FUEL X FEED 1 after 10 s in disagreement")
    T.check(out.light.x1, "crossfeed 1 VALVE light")
    inp.fire_out[2] = true
    out = run(s, inp, 6)
    T.check(out.valve.s2 == 0 and not out.has_fuel[2], "fire switch 2: spar valve 2 closed, no fuel to engine 2")
end

-- the APU from main 2: main 2 and 3 AFT run for it on the ground service bus (FCOM p.1465)
do
    local s, inp = aircraft(FULL)
    inp.apu_fuel = true
    local out = run(s, inp, 6)
    T.check(out.pump.m2_aft and out.pump.m3_aft and not out.pump.m2_fwd, "APU: main 2 and 3 AFT run")
    T.check(out.valve.apu == 1, "APU: fuel valve open")
    run(s, inp, 3600)
    T.near(s.qty.m2, 36000 - 150, 1, "APU: 150 kg in an hour from main 2 (estimate)")
end

T.done()
