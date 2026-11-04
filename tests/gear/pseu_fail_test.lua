-- Run from the repository root with LuaJIT: luajit tests/gear/pseu_fail_test.lua
-- The air/ground sensing model's failures (2026-11-04; docs/overhaul/notes/
-- ATA-32.md §17): a landing gear subsystem (primary, alternate) failed to
-- the air position: AIR/GND SYSTEM (FCOM p.1521; QRH 14.1), and the
-- primary and alternate disagreeing for 10 s: STATUS A/G DISAGREE,
-- inhibited without the battery bus or AC bus 2 or 4 (ATA29_32 p.338,
-- p.341).
local T = dofile("tests/lib/check.lua")("pseu_fail")
local P = dofile("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.pseu_model.lua")

local IN_AIR = {58, 8, 8, 58}
local LEVEL = {0, 0, 0, 0}
local DT = 1 / 30
local function state(tilt, nose_on_ground, psi)
    local inp = P.inputs()
    inp.tilt_deg = {tilt[1], tilt[2], tilt[3], tilt[4]}
    inp.nose_on_ground = nose_on_ground
    inp.hyd_psi = {psi, psi, psi, psi}
    return inp
end
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = P.update(inp, s, DT) end
    return out
end

-- without the state (the existing callers) nothing changes
do
    local out = P.update(state(LEVEL, true, 3000))
    T.check(out.pri_gnd and out.alt_gnd and not out.air_gnd_alert and not out.ag_disagree,
        "no state: ground, no messages")
end

-- parked, hydraulics on: the alternate subsystem failed to air: its outputs
-- air, the primary ground; AIR/GND SYSTEM; A/G DISAGREE after 10 s
do
    local s, inp = P.new(), state(LEVEL, true, 3000)
    local out = run(s, inp, 1)
    T.check(out.pri_gnd and out.alt_gnd and not out.air_gnd_alert and not out.ag_disagree, "parked: ground, no messages")
    inp.failed_air[2] = true
    out = run(s, inp, 1)
    T.check(out.pri_gnd and not out.pri_air, "alternate failed to air: the primary still ground")
    T.check(out.alt_air and not out.alt_gnd, "alternate failed to air: the alternate air")
    T.check(out.air_gnd_alert, "alternate failed to air: AIR/GND SYSTEM")
    T.check(not out.ag_disagree, "A/G DISAGREE not before 10 s")
    out = run(s, inp, 9.5)
    T.check(out.ag_disagree, "the subsystems disagree 10 s: STATUS A/G DISAGREE (ATA29_32 p.338)")
    -- inhibited without the battery bus or AC bus 2 or 4 (p.341)
    inp.power = false
    out = run(s, inp, 0.1)
    T.check(not out.ag_disagree, "without its buses: A/G DISAGREE inhibited")
    inp.power = true
    out = run(s, inp, 0.1)
    T.check(out.ag_disagree, "buses back: A/G DISAGREE")
    -- both failed: both air, they agree; AIR/GND SYSTEM stays
    inp.failed_air[1] = true
    out = run(s, inp, 1)
    T.check(out.pri_air and not out.pri_gnd and out.alt_air and not out.alt_gnd, "both failed to air: air on the ground")
    T.check(out.air_gnd_alert and not out.ag_disagree, "both failed: AIR/GND SYSTEM, no A/G DISAGREE")
    inp.failed_air[1], inp.failed_air[2] = false, false
    out = run(s, inp, 0.1)
    T.check(out.pri_gnd and out.alt_gnd and not out.air_gnd_alert and not out.ag_disagree, "repaired: ground, no messages")
end

-- in flight a subsystem failed to air changes nothing but AIR/GND SYSTEM
-- (the PSEU's monitors find it: QRH 14.1 prepares the landing)
do
    local s, inp = P.new(), state(IN_AIR, false, 3000)
    inp.down = {1, 1, 1, 1}
    inp.failed_air[1] = true
    local out = run(s, inp, 12)
    T.check(out.pri_air and out.alt_air and not out.pri_gnd and not out.alt_gnd, "in flight: both air")
    T.check(out.air_gnd_alert and not out.ag_disagree, "in flight: AIR/GND SYSTEM, no A/G DISAGREE")
    -- the touchdown: the trucks level, the nose on the ground: the primary
    -- stays air, the alternate goes ground
    inp.tilt_deg = {0, 0, 0, 0}
    inp.nose_on_ground = true
    out = run(s, inp, 1)
    T.check(out.pri_air and not out.pri_gnd and out.alt_gnd, "touchdown: the primary stays air, the alternate ground")
end

T.done()
