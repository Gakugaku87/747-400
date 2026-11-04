-- Run from the repository root with LuaJIT: luajit tests/fltctrls/tocw_model_test.lua
-- The takeoff configuration warning (plugins/xtlua/scripts/B747.45.xt.fltCtrls/
-- B747.45.tocw_model.lua) against FCOM p.1557, p.1603-1604, ATA27 p.729-730
-- and ATA31 p.180, p.188-194: armed on the ground below V1 with three FUEL
-- CONTROL switches in RUN and engine 2 or 3 at takeoff thrust (N1 by the
-- engine type), each message while its configuration is wrong, 10 s more
-- after the takeoff thrust goes, at once gone when put right.
local T = dofile("tests/lib/check.lua")("tocw_model")
local W = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.tocw_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = W.update(s, inp, DT) end
    return out
end
local function ready()
    local s, inp = W.new(), W.inputs()
    inp.fuel_run, inp.v1_kt, inp.ias_kt = 4, 150, 0
    return s, inp
end

-- the flaps wrong; engine 2 alone at takeoff thrust (P&W 66.5)
do
    local s, inp = ready()
    inp.flaps_to = false
    inp.n1[2] = 60
    local out = run(s, inp, 1)
    T.check(not out.flaps, "N1 60: below takeoff thrust, no CONFIG FLAPS")
    inp.n1[2] = 70
    out = run(s, inp, 0.2)
    T.check(out.armed and out.flaps, "engine 2 at N1 70 (P&W 66.5): CONFIG FLAPS")
    T.check(not out.park_brk and not out.stab, "only the wrong configuration's message")
    -- the takeoff thrust goes: 10 s more (ATA27 p.730)
    inp.n1[2] = 30
    out = run(s, inp, 9.5)
    T.check(out.flaps, "thrust back, 9.5 s: CONFIG FLAPS stays")
    out = run(s, inp, 1)
    T.check(not out.flaps, "10 s after: gone")
    -- put right: at once
    inp.n1[3] = 80
    out = run(s, inp, 0.2)
    T.check(out.flaps, "engine 3 alone at takeoff thrust: CONFIG FLAPS (2 or 3)")
    inp.flaps_to = true
    out = run(s, inp, DT)
    T.check(not out.flaps, "flaps put right: gone at once")
end

-- the engine type's thresholds: GE 75.0, RR 66.7
do
    local s, inp = ready()
    inp.park_brake = true
    inp.engine_type = 1
    inp.n1[2] = 72
    local out = run(s, inp, 0.2)
    T.check(not out.park_brk, "GE at N1 72: not takeoff thrust (75.0)")
    inp.n1[2] = 76
    out = run(s, inp, 0.2)
    T.check(out.park_brk, "GE at N1 76: CONFIG PARK BRK")
    inp.engine_type, inp.n1[2] = 2, 66.6
    out = run(s, inp, 11)
    T.check(not out.park_brk, "RR at N1 66.6: not takeoff thrust (66.7)")
end

-- V1: armed below it only; without a V1, until 5 degrees of pitch
do
    local s, inp = ready()
    inp.speedbrake_not_down, inp.n1[2] = true, 90
    local out = run(s, inp, 0.2)
    T.check(out.spoilers, "speedbrake lever not down: CONFIG SPOILERS")
    inp.ias_kt = 150
    out = run(s, inp, DT)
    T.check(not out.spoilers, "at V1: gone")
    inp.ias_kt, inp.v1_kt = 160, 999
    out = run(s, inp, 0.2)
    T.check(out.spoilers, "no V1 (the FMC's 999), 160 kt, pitch 0: CONFIG SPOILERS")
    inp.v1_kt = 0
    out = run(s, inp, 0.2)
    T.check(out.spoilers, "V1 0: none either, still armed")
    inp.pitch_deg = 6
    out = run(s, inp, DT)
    T.check(not out.spoilers, "no V1, rotated past 5 degrees: gone (ATA31 p.180)")
    inp.pitch_deg, inp.on_ground = 0, false
    out = run(s, inp, DT)
    T.check(not out.spoilers, "in the air: none")
end

-- the other messages and the conditions
do
    local s, inp = ready()
    inp.body_unlocked, inp.stab_in_band, inp.n1[3] = true, false, 95
    local out = run(s, inp, 0.2)
    T.check(out.gear_ctr, "body gear unlocked: CONFIG GEAR CTR")
    T.check(out.stab, "stabilizer out of the greenband: CONFIG STAB")
    inp.fuel_run = 2
    out = run(s, inp, DT)
    T.check(not out.gear_ctr and not out.stab, "two FUEL CONTROL switches in RUN: none")
    inp.fuel_run, inp.reverse = 4, true
    out = run(s, inp, 0.2)
    T.check(not out.armed, "a reverser out: not takeoff thrust (estimate)")
end

T.done()
