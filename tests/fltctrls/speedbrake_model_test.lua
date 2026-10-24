-- Run from the repository root with LuaJIT: luajit tests/fltctrls/speedbrake_model_test.lua
-- The speedbrake model (plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.speedbrake_model.lua)
-- against FCOM p.951-952, p.958 and ATA27 p.170-184, p.740
-- (docs/overhaul/notes/ATA-27.md §4.2): the auto speedbrake's extension
-- (armed, or reverse lever 2 or 4) and retraction (thrust lever 1 or 3),
-- its ground and power conditions, SPEEDBRAKE AUTO and >SPEEDBRAKES EXT.
local T = dofile("tests/lib/check.lua")("speedbrake_model")
local M = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.speedbrake_model.lua")

local DT = 0.1
-- the glue writes the lever back while the actuator drives it
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do
        out = M.update(s, inp, DT)
        inp.lever = out.lever
    end
    return out
end
-- on the ground, systems 1 and 4 pressurized, thrust levers idle
local function ground(lever)
    local s, inp = M.new(), M.inputs()
    inp.hyd_psi[1], inp.hyd_psi[2] = 3000, 3000
    inp.pri_gnd, inp.alt_gnd = true, true
    inp.lever = lever or M.DN
    return s, inp
end

-- landing with the lever armed: driven to UP (FCOM p.951)
do
    local s, inp = ground(M.ARM)
    inp.pri_gnd, inp.alt_gnd = false, false
    local out = run(s, inp, 1)
    T.check(out.armed, "lever at ARM: SPEEDBRAKE ARMED")
    T.equal(out.lever, M.ARM, "in the air: stays at ARM")
    inp.pri_gnd, inp.alt_gnd = true, true
    out = run(s, inp, 0.5)
    T.check(out.extend and out.driving == 1, "touchdown, thrust levers 1 and 3 idle: extending")
    out = run(s, inp, 2)
    T.equal(out.lever, M.UP, "driven to UP")
    T.check(not out.armed, "no SPEEDBRAKE ARMED at UP")
    -- go-around: thrust lever 1 advanced drives it to DN (FCOM p.951)
    inp.tla[1] = 20
    out = run(s, inp, 0.5)
    T.check(out.retract and out.driving == -1, "thrust lever 1 advanced: retracting")
    out = run(s, inp, 2)
    T.equal(out.lever, M.DN, "driven to DN")
    T.check(not out.speedbrake_auto, "no SPEEDBRAKE AUTO")
end

-- not armed: reverse lever 2 or 4 raised with thrust levers 1 and 3 idle
-- extends them (refused takeoff, the unarmed landing); reverse 1 or 3 does not
do
    local s, inp = ground(M.DN)
    inp.reverse[1], inp.reverse[3] = true, true
    local out = run(s, inp, 3)
    T.equal(out.lever, M.DN, "reverse levers 1 and 3 only: no extension (S861 is 2 or 4)")
    inp.reverse[4] = true
    out = run(s, inp, 2.5)
    T.equal(out.lever, M.UP, "reverse lever 4: driven to UP")
end

-- the conditions: thrust lever 3 not idle, the air, no hydraulics, no DC 1
do
    local s, inp = ground(M.ARM)
    inp.tla[3] = 10
    local out = run(s, inp, 3)
    T.equal(out.lever, M.ARM, "thrust lever 3 advanced: no extension, and the lever at ARM is not driven")
    inp.tla[3] = 6
    out = run(s, inp, 3)
    T.equal(out.lever, M.UP, "thrust lever 3 within 7 degrees of idle: extends")
    s, inp = ground(M.ARM)
    inp.hyd_psi[1], inp.hyd_psi[2] = 1500, 1500
    out = run(s, inp, 3)
    T.equal(out.lever, M.ARM, "systems 1 and 4 below 1600 psi: no extension (ATA27 p.182)")
    inp.hyd_psi[2] = 3000
    out = run(s, inp, 3)
    T.equal(out.lever, M.UP, "system 4 alone: extends")
    s, inp = ground(M.ARM)
    inp.dc1 = false
    out = run(s, inp, 3)
    T.equal(out.lever, M.ARM, "DC bus 1 off: no auto speedbrake")
end

-- by hand: on the ground thrust lever 1 or 3 drives the ground spoilers down
-- however they were extended; in flight the speedbrake stays
do
    local s, inp = ground(M.UP)
    inp.tla[3] = 15
    local out = run(s, inp, 2.5)
    T.equal(out.lever, M.DN, "on the ground by hand at UP, thrust lever 3 advanced: driven to DN")
    s, inp = ground(M.DETENT)
    inp.pri_gnd, inp.alt_gnd = false, false
    inp.ra = 5000
    inp.tla[1], inp.tla[3] = 25, 25
    out = run(s, inp, 3)
    T.equal(out.lever, M.DETENT, "in flight at the flight detent: stays (the actuator is retracted)")
end

-- SPEEDBRAKE AUTO (ATA27 p.184): the lever DN with the actuator out (it is
-- stuck); the ground sensing disagreeing. The actuator going back after the
-- pilot's DN: none
do
    local s, inp = ground(M.ARM)
    local out = run(s, inp, 2.5)
    T.equal(out.lever, M.UP, "extended")
    inp.lever = M.DN
    out = run(s, inp, 5)
    T.check(not out.speedbrake_auto, "the pilot's DN: the actuator retracts, no SPEEDBRAKE AUTO")
    s, inp = ground(M.ARM)
    run(s, inp, 2.5)
    inp.actuator_stuck = true
    inp.lever = M.DN
    out = run(s, inp, 2)
    T.check(not out.speedbrake_auto, "stuck out, 2 s: not yet")
    out = run(s, inp, 1.5)
    T.check(out.speedbrake_auto, "the lever DN with the actuator stuck out: SPEEDBRAKE AUTO")
    s, inp = ground(M.DN)
    inp.alt_gnd = false
    out = run(s, inp, 3.5)
    T.check(out.speedbrake_auto, "primary and alternate ground sensing disagreeing: SPEEDBRAKE AUTO")
end

-- >SPEEDBRAKES EXT (FCOM p.958; ATA27 p.740)
do
    local s, inp = M.new(), M.inputs()
    inp.lever, inp.ra = M.DETENT, 5000
    local out = M.update(s, inp, DT)
    T.check(not out.speedbrakes_ext, "5000 ft, flaps up, thrust idle: none")
    inp.ra = 700
    T.check(M.update(s, inp, DT).speedbrakes_ext, "at or below 800 ft: >SPEEDBRAKES EXT")
    inp.ra = 10
    T.check(not M.update(s, inp, DT).speedbrakes_ext, "below 15 ft: none")
    inp.ra = 5000
    inp.landing_flaps = true
    T.check(M.update(s, inp, DT).speedbrakes_ext, "flaps 25 or 30: >SPEEDBRAKES EXT")
    inp.landing_flaps = false
    inp.tla[1] = 10
    T.check(not M.update(s, inp, DT).speedbrakes_ext, "one thrust lever forward: none")
    inp.tla[2] = 10
    T.check(M.update(s, inp, DT).speedbrakes_ext, "two thrust levers above the speedbrake power level: >SPEEDBRAKES EXT")
    inp.tla[1], inp.tla[2] = 4, 4
    T.check(not M.update(s, inp, DT).speedbrakes_ext, "two levers just off idle (below 5.1 degrees): none")
    inp.lever, inp.ra = M.ARM, 500
    T.check(not M.update(s, inp, DT).speedbrakes_ext, "lever at ARM: none")
end

T.done()
