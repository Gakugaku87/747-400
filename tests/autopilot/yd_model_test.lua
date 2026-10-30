-- Run from the repository root with LuaJIT: luajit tests/autopilot/yd_model_test.lua
-- The yaw damper model (plugins/xtlua_keysystems/scripts/
-- B747.19.xt.hydraulicsmodel/B747.19.yd_model.lua) against ATA22 22-21
-- (docs/overhaul/notes/ATA-22.md §4.7, §39): the power-up test on the
-- ground, the ground operation, the fade-in and fade-out, the power-up in
-- the air, the fault INOP mode with its autorecovery (an IRU into NAV, a
-- fault under 5 s) and the switch cycled, the IRUs off, the power, and the
-- authority by the valid IRUs and ADCs.
local T = dofile("tests/lib/check.lua")("yd_model")
local Y = dofile("plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.yd_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = Y.update(s, inp, DT) end
    return out
end
-- both switches ON, powered, the IRUs in NAV, both ADCs
local function ready(air)
    local s, inp = Y.new(), Y.inputs()
    inp.switch[1], inp.switch[2] = true, true
    inp.power[1], inp.power[2] = true, true
    inp.iru, inp.iru_nav, inp.adc = 3, 3, 2
    inp.air = air or false
    return s, inp
end
local UPR, LWR = Y.UPR, Y.LWR

-- off: the switch OFF, INOP (FCOM p.931)
do
    local s, inp = Y.new(), Y.inputs()
    local out = run(s, inp, 1)
    T.check(out.mode[UPR] == Y.OFF and out.inop[UPR] and out.inop[LWR], "switches OFF: off, INOP")
end
-- the power-up test on the ground: INOP 5 s, then the ground operation
-- (engaged, no command); in the air the fade-in over 5 s to the flight
-- mode; on the ground the fade-out to the ground operation (ATA22 p.83-85)
do
    local s, inp = ready(false)
    local out = run(s, inp, 0.1)
    T.check(out.mode[UPR] == Y.TEST and out.inop[UPR] and out.inop[LWR], "powered on the ground: the power-up test, INOP")
    out = run(s, inp, 4.5)
    T.check(out.mode[UPR] == Y.TEST and out.inop[UPR], "4.6 s: still testing")
    out = run(s, inp, 0.5)
    T.check(out.mode[UPR] == Y.GROUND and out.engaged[UPR] and not out.inop[UPR], "5 s: the ground operation, engaged, no INOP")
    T.check(out.fade[UPR] == 0 and out.authority[UPR] == 4, "on the ground no command (fade 0), the authority 4 degrees")
    inp.air = true
    out = run(s, inp, 2.5)
    T.check(out.mode[UPR] == Y.FADE_IN and math.abs(out.fade[UPR] - 0.5) < 0.03, "in the air: the fade-in, half after 2.5 s")
    out = run(s, inp, 2.6)
    T.check(out.mode[UPR] == Y.FLIGHT and out.fade[UPR] == 1, "after 5 s: the flight mode, the whole command")
    inp.air = false
    out = run(s, inp, 2)
    T.check(out.mode[LWR] == Y.FADE_OUT and out.fade[LWR] > 0.5 and out.fade[LWR] < 0.7 and not out.inop[LWR], "landed: the fade-out, no INOP")
    inp.air = true
    out = run(s, inp, 0.1)
    T.check(out.mode[LWR] == Y.FADE_IN and out.fade[LWR] > 0.55, "airborne again in the fade-out: the fade-in from there")
    inp.air = false
    out = run(s, inp, 6)
    T.check(out.mode[LWR] == Y.GROUND and out.fade[LWR] == 0, "on the ground: the ground operation again")
end
-- powered in the air: no test, the fade-in (p.83)
do
    local s, inp = ready(true)
    local out = run(s, inp, 0.1)
    T.check(out.mode[UPR] == Y.FADE_IN and not out.inop[UPR], "powered in the air: the fade-in, no test")
    out = run(s, inp, 5.1)
    T.equal(out.mode[UPR], Y.FLIGHT, "then the flight mode")
end
-- a fault: disengaged, INOP; under 5 s it recovers by itself (p.84), in the
-- air through the fade-in; longer, it stays until its switch is cycled or
-- an IRU goes into NAV
do
    local s, inp = ready(true)
    run(s, inp, 6)
    inp.fault[UPR] = true
    local out = run(s, inp, 0.1)
    T.check(out.mode[UPR] == Y.FAULT and out.inop[UPR] and out.fade[UPR] == 0, "upper fault: the fault INOP mode, no command")
    T.check(out.mode[LWR] == Y.FLIGHT and not out.inop[LWR], "the lower one goes on")
    out = run(s, inp, 2)
    inp.fault[UPR] = false
    out = run(s, inp, 0.1)
    T.check(out.mode[UPR] == Y.FADE_IN and not out.inop[UPR], "a 2 s fault: autorecovery, the fade-in")
    out = run(s, inp, 5.1)
    T.equal(out.mode[UPR], Y.FLIGHT, "then the flight mode")
    inp.fault[UPR] = true
    run(s, inp, 6)
    inp.fault[UPR] = false
    out = run(s, inp, 1)
    T.check(out.mode[UPR] == Y.FAULT and out.inop[UPR], "a 6 s fault: still INOP after it clears")
    inp.switch[UPR] = false
    out = run(s, inp, 0.2)
    T.check(out.mode[UPR] == Y.OFF and out.inop[UPR], "the switch OFF: off")
    inp.switch[UPR] = true
    out = run(s, inp, 0.1)
    T.check(out.mode[UPR] == Y.FADE_IN and not out.inop[UPR], "and ON: powered up again, in the air the fade-in")
end
-- the IRUs off or aligning: INOP (FCOM p.958); an IRU into NAV recovers
-- it (p.84); back in ATT only after 5 s, it stays INOP
do
    local s, inp = ready(false)
    inp.iru, inp.iru_nav = 0, 0
    local out = run(s, inp, 1)
    T.check(out.mode[UPR] == Y.FAULT and out.inop[UPR] and out.inop[LWR], "the IRUs aligning: INOP")
    out = run(s, inp, 600)
    inp.iru, inp.iru_nav = 1, 1
    out = run(s, inp, 0.1)
    T.check(out.mode[UPR] == Y.GROUND and not out.inop[UPR], "an IRU into NAV after 10 min: autorecovery, the ground operation")
    inp.air = true
    run(s, inp, 6)
    inp.iru, inp.iru_nav = 0, 0
    run(s, inp, 10)
    inp.iru = 1
    out = run(s, inp, 1)
    T.check(out.mode[UPR] == Y.FAULT and out.inop[UPR], "the IRUs lost 10 s, one back in ATT: still INOP")
    inp.iru_nav = 1
    out = run(s, inp, 0.1)
    T.check(out.mode[UPR] == Y.FADE_IN, "it goes into NAV: autorecovery in the air")
end
-- power: each module on its own (p.60-62)
do
    local s, inp = ready(true)
    run(s, inp, 6)
    inp.power[UPR] = false
    local out = run(s, inp, 0.1)
    T.check(out.mode[UPR] == Y.OFF and out.inop[UPR] and out.mode[LWR] == Y.FLIGHT, "the upper's power lost: off, INOP; the lower goes on")
    inp.power[UPR] = true
    out = run(s, inp, 0.1)
    T.equal(out.mode[UPR], Y.FADE_IN, "power back in the air: the fade-in")
end
-- the authority (p.87): 3 or 2 IRUs 4 degrees; one IRU with both ADCs
-- "variable", with fewer 1 degree
T.equal(Y.authority(3, 2), 4, "3 IRUs, 2 ADCs: 4 degrees")
T.equal(Y.authority(2, 0), 4, "2 IRUs, no ADC: 4 degrees")
T.equal(Y.authority(1, 2), Y.AUTH_VAR, "1 IRU, 2 ADCs: variable (estimate)")
T.equal(Y.authority(1, 1), 1, "1 IRU, 1 ADC: 1 degree")
T.equal(Y.authority(1, 0), 1, "1 IRU, no ADC: 1 degree")
T.equal(Y.authority(0, 2), 0, "no IRU: none")
do
    local s, inp = ready(true)
    run(s, inp, 6)
    inp.iru = 1
    inp.adc = 1
    local out = run(s, inp, 0.1)
    T.check(out.authority[UPR] == 1 and out.mode[UPR] == Y.FLIGHT, "in flight, 1 IRU and 1 ADC: 1 degree, still engaged")
end
-- 6b: the command (ATA22 p.86-87; ATA27 p.656, p.760): the rudder against
-- the sideslip rate (X-Plane's sign: the nose swinging right of the path
-- plus) computed from the lateral acceleration, the yaw and roll rates,
-- the bank, the AOA and the true airspeed; the gain inversely with the
-- impact pressure, 2.0 at 150 kt (fitted to the custom acf: an estimate)
T.near(Y.gain(150), 2.0, 1e-9, "6b: the gain at 150 kt: 2.0 degrees per degree a second")
T.near(Y.gain(250), 0.704, 0.005, "at 250 kt: 0.70 (the impact pressure 2.84 times)")
T.equal(Y.gain(100), Y.K_MAX, "at 100 kt: the most, 3.0")
T.check(Y.gain(350) >= Y.K_MIN and Y.gain(350) < 0.4, "at 350 kt: 0.2 to 0.4")
do
    local inp = Y.inputs()
    local v = 80
    -- a steady level turn at 20 degrees of bank: the yaw rate g sin(bank) / V
    inp.roll, inp.r = 20, math.deg(9.80665 * math.sin(math.rad(20)) / v)
    T.near(Y.sideslip_rate(inp, v), 0, 1e-9, "a coordinated level turn: no sideslip rate (the turn coordination)")
    inp.roll, inp.r = 0, 1
    T.near(Y.sideslip_rate(inp, v), 1, 1e-9, "wings level, yawing right 1 degree a second: +1")
    inp.r, inp.ny = 0, 0.01
    T.near(Y.sideslip_rate(inp, v), -math.deg(0.0980665 / v), 1e-9, "a side force to the right: the path swings right, -")
    inp.ny, inp.alpha, inp.p = 0, 10, 1
    T.near(Y.sideslip_rate(inp, v), -math.sin(math.rad(10)), 1e-9, "rolling right at 10 degrees of AOA: - sin(alpha)")
end
do
    local s, inp = ready(true)
    inp.cas, inp.tas, inp.gs = 150, 80, 80
    run(s, inp, 6)
    inp.r = 1
    local out = run(s, inp, 0.1)
    T.near(out.cmd[UPR], -2.0, 1e-9, "flight mode at 150 kt, yawing right 1 deg/s: the upper rudder 2 degrees left")
    T.near(out.cmd[LWR], -2.0, 1e-9, "the lower the same")
    inp.r = 5
    out = run(s, inp, 0.1)
    T.equal(out.cmd[UPR], -4, "5 deg/s: within the authority, 4 degrees")
    inp.iru, inp.adc = 1, 1
    out = run(s, inp, 0.1)
    T.equal(out.cmd[UPR], -1, "1 IRU and 1 ADC: 1 degree")
    inp.iru, inp.adc, inp.r = 3, 0, 1
    inp.gs = 100
    out = run(s, inp, 0.1)
    T.near(out.cmd[UPR], -Y.gain(Y.K_NO_ADC_KT), 1e-9, "no ADC: the gain at 250 kt (estimate)")
    inp.adc, inp.air = 2, false
    out = run(s, inp, 2.5)
    T.check(out.mode[UPR] == Y.FADE_OUT and math.abs(out.cmd[UPR] + 1.0) < 0.05, "landed: the fade-out, half the command after 2.5 s")
    out = run(s, inp, 3)
    T.check(out.mode[UPR] == Y.GROUND and out.cmd[UPR] == 0, "the ground operation: no command")
    inp.fault[LWR] = true
    inp.air = true
    out = run(s, inp, 1)
    T.check(out.cmd[LWR] == 0 and out.cmd[UPR] < 0, "the lower's fault: no command from it, the upper fading in")
end

T.done()
