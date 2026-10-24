-- Run from the repository root with LuaJIT: luajit tests/gear/brake_model_test.lua
-- The wheel brake model (plugins/xtlua/scripts/B747.10.xt.gear/B747.10.brake_model.lua)
-- against FCOM 14.20 and ATA29_32 32-41, 32-42 (docs/overhaul/notes/ATA-32.md
-- §4.6-§4.7): the pressure of the brake source, the parking brake's valve and
-- trapped pressure, the lever released by both pedals, the antiskid and the
-- messages.
local T = dofile("tests/lib/check.lua")("brake_model")
local M = dofile("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.brake_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = M.update(s, inp, DT) end
    return out
end

-- the pedals: torque in proportion to the source's pressure (estimate)
do
    local s, inp = M.new(), M.inputs()
    inp.pedal = {1, 0.4}
    local out = run(s, inp, 0.1)
    T.equal(out.brake[1], 1, "system 4 at 3000 psi: full brake on the left")
    T.near(out.brake[2], 0.4, 1e-9, "the right pedal 0.4")
    inp.source, inp.psi = 1, 1500
    out = run(s, inp, 0.1)
    T.near(out.brake[1], 0.5, 1e-9, "the alternate brakes at 1500 psi: half")
    inp.source, inp.psi = 0, 0
    out = run(s, inp, 0.1)
    T.equal(out.brake[1], 0, "no source, the accumulator empty: no brakes")
    -- the autobrakes' pressure: the larger of it and the pedals, within the source's
    inp.source, inp.psi, inp.pedal = 4, 3000, {0.2, 0}
    inp.auto = 0.4
    out = run(s, inp, 0.1)
    T.near(out.brake[1], 0.4, 1e-9, "autobrake 0.4 over the pedal 0.2")
    T.near(out.brake[2], 0.4, 1e-9, "on both sides")
    inp.psi = 900
    out = run(s, inp, 0.1)
    T.near(out.brake[2], 0.3, 1e-9, "not more than the source's 900 psi")
end

-- the parking brake: the valve closes on the battery bus and traps the
-- pressure; PARK BRAKE SET with the lever set and the valve closed (ATA29_32
-- p.416-421); the trapped pressure holds after the systems go
do
    local s, inp = M.new(), M.inputs()
    inp.lever = 1
    local out = run(s, inp, 0.5)
    T.check(out.valve > 0 and out.valve < 1, "0.5 s: the valve closing")
    T.check(not out.park_brake_set, "not closed: no PARK BRAKE SET")
    T.equal(out.park, 0, "nothing trapped yet")
    out = run(s, inp, 0.6)
    T.equal(out.valve, 1, "closed")
    T.check(out.park_brake_set, "PARK BRAKE SET")
    T.equal(out.park, 1, "3000 psi trapped: full hold")
    inp.source, inp.psi = 0, 0
    out = run(s, inp, 5)
    T.equal(out.park, 1, "the systems and the accumulator gone: the trapped pressure still holds")
    -- both pedals release the lever (FCOM p.1516)
    inp.pedal = {0.95, 0.5}
    out = run(s, inp, 0.1)
    T.check(not out.release_lever, "one pedal: the lever stays")
    inp.pedal = {0.95, 0.95}
    out = run(s, inp, 0.1)
    T.check(out.release_lever, "both pedals: the lever released")
    inp.pedal, inp.lever = {0, 0}, 0
    out = run(s, inp, 1.1)
    T.equal(out.valve, 0, "lever off: the valve opens")
    T.equal(out.park, 0, "the pressure let go")
    T.check(not out.park_brake_set and not out.brake_limiter, "no memo, no BRAKE LIMITER")
end

-- set with only the accumulator at its precharge: a weak hold; no battery
-- bus: the valve does not move
do
    local s, inp = M.new(), M.inputs()
    inp.source, inp.psi = 0, 750
    inp.lever = 1
    local out = run(s, inp, 2)
    T.near(out.park, 0.25, 1e-9, "750 psi trapped: a quarter of the hold")
    local s2, inp2 = M.new(), M.inputs()
    inp2.bat_bus = false
    inp2.lever = 1
    out = run(s2, inp2, 3)
    T.equal(out.valve, 0, "no battery bus: the valve stays open")
    T.check(not out.park_brake_set, "no PARK BRAKE SET")
end

-- the valve stuck closed after the lever's release, or closed in air mode:
-- BRAKE LIMITER and ANTISKID OFF after 2 s (ATA29_32 p.420)
do
    local s, inp = M.new(), M.inputs()
    inp.lever = 1
    run(s, inp, 2)
    inp.fail_valve, inp.lever = true, 0
    local out = run(s, inp, 1.9)
    T.check(not out.brake_limiter, "1.9 s: not yet")
    out = run(s, inp, 0.2)
    T.check(out.brake_limiter and out.antiskid_off, "2 s: BRAKE LIMITER and ANTISKID OFF")
    T.check(not out.abs, "X-Plane's antiskid off")
    local s2, inp2 = M.new(), M.inputs()
    inp2.lever = 1
    run(s2, inp2, 2)
    inp2.air = true
    out = run(s2, inp2, 2.1)
    T.check(out.brake_limiter and out.antiskid_off, "the valve closed in air mode: both messages")
end

-- the antiskid in use: normal with system 4, alternate with 1, 2 and the
-- accumulator; the power of the wheel cards and the BSCU
do
    local s, inp = M.new(), M.inputs()
    inp.fail_antiskid[1] = true
    local out = run(s, inp, 0.1)
    T.check(out.antiskid and not out.abs, "normal antiskid failed on the normal brakes: ANTISKID, no X-Plane antiskid")
    inp.source = 1
    out = run(s, inp, 0.1)
    T.check(not out.antiskid and out.abs, "on the alternate brakes the normal antiskid's failure does not count")
    inp.source = 4
    inp.dc = {false, false, false, false}
    out = run(s, inp, 0.1)
    T.check(out.antiskid_off and not out.antiskid, "all DC buses off: ANTISKID OFF, ANTISKID inhibited")
    inp.dc = {true, false, true, false}
    out = run(s, inp, 0.1)
    T.check(out.antiskid_off and out.brake_limiter, "DC 2 and 4 off (the BSCU): ANTISKID OFF and BRAKE LIMITER")
    inp.dc = {true, true, true, true}
    inp.fail_antiskid[1], inp.fail_limiter = false, true
    out = run(s, inp, 0.1)
    T.check(out.brake_limiter and not out.antiskid_off, "torque limiters failed: BRAKE LIMITER only")
end

-- the chocks hold; a flight start with the lever set has the valve closed
do
    local s, inp = M.new(), M.inputs()
    inp.chocked = true
    local out = run(s, inp, 0.1)
    T.equal(out.park, 1, "chocked: held")
    local s2, inp2 = M.new(), M.inputs()
    inp2.lever = 1
    M.set_to(s2, inp2)
    out = M.update(s2, inp2, DT)
    T.check(out.park_brake_set, "set_to with the lever set: PARK BRAKE SET at once")
    T.equal(out.park, 1, "and held")
end

T.done()
