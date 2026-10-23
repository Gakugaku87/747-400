-- Run from the repository root with LuaJIT: luajit tests/air/eqcool_model_test.lua
-- The equipment cooling model (plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.eqcool_model.lua)
-- against FCOM 2.10-2.50 and ATA21 21-58: NORM on the ground by the skin
-- temperature, the flight configuration, STBY, the closed loop with a
-- failed fan and its reset, OVRD and cargo fire ARM, and EQUIP COOLING.
local T = dofile("tests/lib/check.lua")("eqcool_model")
local Q = dofile("plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.eqcool_model.lua")

local DT = 1 / 30
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = Q.update(s, inp, DT) end
    return out
end

-- NORM on the ground, engines off: overboard above 45°F, into the forward
-- cargo below (FCOM p.605; ATA21 p.512)
do
    local s, inp = Q.new(), Q.inputs()
    inp.skin_c = 20
    local out = run(s, inp, 1)
    T.equal(out.config, Q.OVERBOARD, "NORM, ground, 20 °C: overboard")
    T.check(out.ground_exhaust and not out.inboard_exhaust and out.fans, "overboard: ground exhaust open, fans on")
    inp.skin_c = 5
    out = run(s, inp, 1)
    T.equal(out.config, Q.CARGO, "NORM, ground, 5 °C: into the forward cargo")
    T.check(not out.ground_exhaust and out.inboard_exhaust and out.cargo_warm, "cargo: inboard exhaust open")
    -- an engine running on each side: the flight configuration
    inp.skin_c = 20
    inp.engine_left = true
    out = run(s, inp, 1)
    T.equal(out.config, Q.OVERBOARD, "one side's engine only: still overboard")
    inp.engine_right = true
    out = run(s, inp, 1)
    T.equal(out.config, Q.CARGO, "an engine each side: the flight configuration (FCOM p.603)")
    -- STBY: the ground exhaust closed whatever the temperature (FCOM p.557)
    inp.engine_left, inp.engine_right, inp.selector = false, false, Q.STBY
    out = run(s, inp, 1)
    T.equal(out.config, Q.CARGO, "STBY on the ground, 20 °C: ground exhaust closed")
    -- in the air
    inp.selector, inp.on_ground = Q.NORM, false
    out = run(s, inp, 1)
    T.equal(out.config, Q.CARGO, "NORM in the air: the flight configuration")
end

-- a fan not turning for 10 s: the closed loop, no message; OVRD 30 s resets
-- (FCOM p.605; ATA21 p.524, p.552-556)
do
    local s, inp = Q.new(), Q.inputs()
    inp.on_ground = false
    inp.fan_failed[1] = true
    local out = run(s, inp, 9)
    T.equal(out.config, Q.CARGO, "supply fan failed 9 s: not yet")
    out = run(s, inp, 1.5)
    T.equal(out.config, Q.CLOSED_LOOP, "supply fan failed 10 s: closed loop")
    T.check(out.bypass and not out.inboard_supply and not out.inboard_exhaust, "closed loop: bypass open, inboard valves closed")
    T.check(not out.alert, "closed loop: no EQUIP COOLING")
    inp.fan_failed[1] = false
    inp.selector = Q.OVRD
    run(s, inp, 31)
    inp.selector = Q.NORM
    out = run(s, inp, 1)
    T.equal(out.config, Q.CARGO, "OVRD for 30 s and back: reset")
end

-- OVRD: fans off, smoke/override valve open, the cabin's air overboard;
-- without the differential pressure EQUIP COOLING after 55 s (FCOM p.558,
-- p.604, p.619; ATA21 p.580-584, p.594-598)
do
    local s, inp = Q.new(), Q.inputs()
    inp.selector = Q.OVRD
    local out = run(s, inp, 1)
    T.equal(out.config, Q.OVERRIDE, "OVRD: override")
    T.check(not out.fans and out.smoke_override and not out.ground_exhaust, "OVRD: fans off, smoke/override valve open")
    out = run(s, inp, 53)
    T.check(not out.alert, "OVRD on the ground 54 s: not yet")
    out = run(s, inp, 2)
    T.check(out.alert, "OVRD on the ground 56 s: EQUIP COOLING (no differential pressure)")
    inp.on_ground, inp.dp = false, 8.8
    out = run(s, inp, 1)
    T.check(not out.alert, "OVRD in cruise: no EQUIP COOLING")
    T.near(out.overboard_kg_s, Q.OVRD_KG_S, 1e-9, "OVRD in cruise: the cabin's air overboard (estimate)")
end

-- cargo fire ARM: the override configuration (FCOM p.908; ATA21 p.580)
do
    local s, inp = Q.new(), Q.inputs()
    inp.on_ground, inp.dp = false, 8
    inp.cargo_fire_arm = true
    local out = run(s, inp, 1)
    T.equal(out.config, Q.OVERRIDE, "cargo fire ARM: override")
end

-- overheat, low flow, smoke: EQUIP COOLING in NORM (FCOM p.619)
do
    local s, inp = Q.new(), Q.inputs()
    inp.smoke = true
    local out = run(s, inp, 1)
    T.check(out.alert, "smoke: EQUIP COOLING")
end

T.done()
