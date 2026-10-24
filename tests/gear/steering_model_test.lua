-- Run from the repository root with LuaJIT: luajit tests/gear/steering_model_test.lua
-- The steering model (plugins/xtlua/scripts/B747.10.xt.gear/B747.10.steering_model.lua)
-- against FCOM 14.20 and ATA29_32 32-50 (docs/overhaul/notes/ATA-32.md §4.9):
-- the pedals' 7 degrees and the tillers' 70, the tillers over the pedals, the
-- centring cams in the air, no steering without system 1's gear down
-- pressure, the body gear's arming (10 s on the ground, 15/20 kt, IRU 40 kt)
-- and its 13 degrees the other way, the trucks' locks, >BODY GEAR STRG,
-- PEDAL STEERING, and the pedals as the tiller for users without one.
local T = dofile("tests/lib/check.lua")("steering_model")
local M = dofile("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.steering_model.lua")

local DT = 0.05
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = M.update(s, inp, DT) end
    return out
end

-- the nose wheels
local s, inp = M.new(), M.inputs()
local out = run(s, inp, 1)
T.equal(out.nose, 0, "no input: straight ahead")
inp.pedal = 1
out = run(s, inp, 1)
T.near(out.nose, 7, 1e-9, "full pedal: 7 degrees (FCOM p.1513)")
inp.pedal = -0.5
out = run(s, inp, 1)
T.near(out.nose, -3.5, 1e-9, "half left pedal: -3.5")
inp.tiller = 1
out = run(s, inp, 1)
T.check(out.nose > 10 and out.nose < 70, "the tiller: turning at its rate (" .. out.nose .. ")")
out = run(s, inp, 4)
T.near(out.nose, 70, 1e-9, "full tiller over the left pedal: 70 degrees (p.578)")
inp.tiller = -0.5
out = run(s, inp, 6)
T.near(out.nose, -35, 1e-9, "half left tiller: -35")
-- no gear down pressure (the lever not DN, or system 1 lost): no steering, held
inp.down_psi = 0
inp.tiller = 1
out = run(s, inp, 2)
T.near(out.nose, -35, 1e-9, "no pressure: the nose wheels stay (estimate)")
inp.down_psi = 3000
inp.tiller, inp.pedal = 0, 0
out = run(s, inp, 3)
T.near(out.nose, 0, 1e-9, "tiller and pedals let go: centred (p.595)")
-- in the air the cams centre the nose wheels; the pedals do not steer
inp.pedal = 1
run(s, inp, 1)
inp.ng_compressed = false
out = run(s, inp, 1)
T.near(out.nose, 0, 1e-9, "strut extended: centred by the cams (p.570)")
inp.tiller = 1
out = run(s, inp, 1)
T.near(out.nose, 0, 1e-9, "strut extended: the tiller does not steer")
inp.ng_compressed, inp.tiller, inp.pedal = true, 0, 0

-- not the aircraft: the pedals as the tiller with no tiller axis
s, inp = M.new(), M.inputs()
inp.pedal_tiller = true
inp.pedal = 1
out = run(s, inp, 4)
T.near(out.nose, 70, 1e-9, "pedal tiller, stopped: 70")
inp.iru_kt = 20
out = run(s, inp, 2)
T.near(out.nose, 38.5, 1e-9, "pedal tiller at 20 kt: half way to the pedals' 7")
inp.iru_kt = 35
out = run(s, inp, 2)
T.near(out.nose, 7, 1e-9, "pedal tiller over 30 kt: the pedals' 7")
inp.iru_kt, inp.tiller_avail = 0, true
out = run(s, inp, 4)
T.near(out.nose, 7, 1e-9, "with a tiller axis: the pedals' 7 only")

-- the body gear
s, inp = M.new(), M.inputs()
inp.tiller = 1
out = run(s, inp, 5)
T.near(out.nose, 70, 1e-9, "full tiller: 70")
T.check(not out.armed, "5 s on the ground: not armed (p.622)")
T.equal(out.body[1], 0, "not armed: the trucks centred")
out = run(s, inp, 5.5)
T.check(out.armed, "10 s on the ground, stopped: armed")
T.check(out.commanded, "nose over 20 degrees: the solenoid valves (p.622)")
T.check(out.body[1] < 0 and out.body[1] > -13, "the trucks turning the other way (" .. out.body[1] .. ")")
out = run(s, inp, 3)
T.near(out.body[1], -13, 1e-9, "70 degrees right: the left truck 13 degrees left (p.604)")
T.near(out.body[2], -13, 1e-9, "and the right truck")
T.check(out.unlocked, "the trucks unlocked")
inp.tiller = -45 / 70
out = run(s, inp, 8)
T.near(out.body[1], 6.5, 1e-9, "45 degrees left: 6.5 degrees right (in proportion: estimate)")
T.check(not out.body_gear_strg, "commanded: no >BODY GEAR STRG")
-- back under 20 degrees: centred and locked
inp.tiller = -15 / 70
out = run(s, inp, 0.5)
T.check(out.commanded and out.unlocked, "on the way back: still commanded, unlocked")
out = run(s, inp, 2)
T.check(not out.commanded, "15 degrees: not commanded")
T.near(out.body[1], 0, 1e-9, "centred (the trucks follow the nose wheels down)")
T.check(not out.unlocked and not out.body_gear_strg, "locked, no message")
-- the speeds: disarmed over 20 kt of wheel speed, armed again under 15 kt
inp.tiller = 1
inp.wheel_kt, inp.iru_kt = 21, 21
out = run(s, inp, 4)
T.check(not out.armed, "21 kt: disarmed (p.622)")
T.equal(out.body[1], 0, "disarmed: no body gear steering (FCOM p.1513)")
inp.wheel_kt, inp.iru_kt = 17, 17
out = run(s, inp, 1)
T.check(not out.armed, "17 kt: still disarmed")
inp.wheel_kt, inp.iru_kt = 14, 14
out = run(s, inp, 1)
T.check(out.armed, "14 kt: armed again")
inp.wheel_kt, inp.iru_kt = 14, 41
out = run(s, inp, 1)
T.check(not out.armed, "IRU groundspeed over 40 kt: disarmed")
-- air mode disarms and starts the 10 s again
inp.wheel_kt, inp.iru_kt = 0, 0
run(s, inp, 1)
inp.gnd_both, inp.air = false, true
out = run(s, inp, 1)
T.check(not out.armed, "air mode: disarmed")
inp.gnd_both, inp.air = true, false
out = run(s, inp, 5)
T.check(not out.armed, "back on the ground: 10 s again")
-- no pressure: the trucks stay
out = run(s, inp, 8)
T.near(out.body[1], -13, 1e-9, "armed again: 13 degrees")
inp.down_psi = 0
inp.tiller = 0
out = run(s, inp, 5)
T.near(out.body[1], -13, 1e-9, "no pressure: the trucks stay (estimate)")
inp.down_psi = 3000
out = run(s, inp, 4)
T.near(out.body[1], 0, 1e-9, "pressure back: centred")

-- failures: a truck's actuator unlocked; a pedal steering actuator
inp.fail_body = true
out = run(s, inp, 4)
T.check(out.unlocked and not out.body_gear_strg, "an actuator unlocked: 4 s, no message yet")
out = run(s, inp, 1.5)
T.check(out.body_gear_strg, ">BODY GEAR STRG and BODY GR STRG SYS (p.626, p.630)")
inp.fail_body = false
out = run(s, inp, 0.1)
T.check(not out.body_gear_strg, "locked: no message")
inp.fail_pedal = true
out = run(s, inp, 0.1)
T.check(out.pedal_steering, "PEDAL STEERING (p.600)")
inp.pedal = 1
out = run(s, inp, 1)
T.near(out.nose, 7, 1e-9, "one actuator failed: the pedals still steer (p.580)")
T.done()
