-- Run from the repository root with LuaJIT: luajit tests/engines/reverser_model_test.lua
-- The thrust reverser model (plugins/xtlua/scripts/B747.40.xt.engines/
-- B747.40.reverser_model.lua) against FCOM p.893-894, p.901, ATA70_80
-- p.473-475 and ATA29_32 p.299: the power (P&W hydraulic, GE bleed from its
-- own engine), the ground relays, an unpowered reverser staying where it is,
-- and ENG n REVERSER. A stand-in reverser moves as X-Plane's did (deploys in
-- about 4 s, stows in about 3 s).
local T = dofile("tests/lib/check.lua")("reverser_model")
local R = dofile("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.reverser_model.lua")

local DT = 0.1
-- one step of the stand-in reverser: X-Plane moves it while the prop mode
-- asks (reverse: out, else in)
local function move(pos, reverse)
    if reverse then return math.min(1, pos + DT / 4) end
    return math.max(0, pos - DT / 3)
end
local function run(s, inp, seconds)
    local out
    for _ = 1, math.floor(seconds / DT + 0.5) do
        out = R.update(s, inp, DT)
        for n = 1, 4 do inp.position[n] = move(inp.position[n], out.reverse[n]) end
    end
    return out
end
local function all(t, v)
    for n = 1, 4 do if t[n] ~= v then return false end end
    return true
end

-- normal reverse on the ground: all deploy, no message; levers down: all stow
do
    local s, inp = R.new(), R.inputs()
    inp.want = {true, true, true, true}
    local o = run(s, inp, 5)
    T.check(all(o.reverse, true), "on the ground, powered: all four may reverse")
    T.check(inp.position[1] >= 0.99, "the reverser deploys")
    T.check(all(o.message, false), "no ENG REVERSER in normal use")
    inp.want = {false, false, false, false}
    o = run(s, inp, 4)
    T.check(all(o.reverse, false) and inp.position[1] == 0, "levers down: stowed")
    T.check(all(o.message, false), "no ENG REVERSER after stowing")
end

-- P&W: hydraulic system 1 without pressure: reverser 1 stays stowed, ENG 1 REVERSER
do
    local s, inp = R.new(), R.inputs()
    inp.type = "PW"
    inp.hyd_psi = {500, 3000, 3000, 3000}
    inp.want = {true, true, true, true}
    local o = run(s, inp, 1.5)
    T.check(not o.reverse[1] and o.reverse[2], "P&W, system 1 low: reverser 1 does not move, 2 does")
    T.check(not o.message[1], "ENG 1 REVERSER not yet (2 s)")
    o = run(s, inp, 1)
    T.check(o.message[1] and not o.message[2], "ENG 1 REVERSER after 2 s asked out and still stowed")
    inp.want = {false, false, false, false}
    o = run(s, inp, 0.2)
    T.check(not o.message[1], "the message goes when the levers go down")
    -- deployed, then the pressure goes: it stays out when stowed, ENG REVERSER
    inp.hyd_psi = {3000, 3000, 3000, 3000}
    inp.want = {true, true, true, true}
    run(s, inp, 5)
    inp.hyd_psi[3] = 0
    inp.want = {false, false, false, false}
    o = run(s, inp, 3)
    T.check(o.reverse[3] and inp.position[3] >= 0.99, "P&W, system 3 lost while deployed: reverser 3 stays out")
    T.check(o.message[3], "ENG 3 REVERSER: asked in, still out")
    T.check(inp.position[2] < 0.01, "the others stow")
end

-- the commands may keep an unpowered engine out of reverse altogether; the
-- crew still asks for it, and the message still shows
do
    local s, inp = R.new(), R.inputs()
    inp.hyd_psi = {3000, 0, 3000, 3000}
    inp.want = {true, false, true, true}
    inp.asked = {true, true, true, true}
    local o = run(s, inp, 2.5)
    T.check(not o.reverse[2] and inp.position[2] == 0, "asked but not put in reverse: reverser 2 stays in")
    T.check(o.message[2] and not o.message[1], "ENG 2 REVERSER: asked out, still stowed")
    inp.want = {false, false, false, false}
    inp.asked = {false, false, false, false}
    o = run(s, inp, 4)
    T.check(not o.message[2], "not asked any more: the message goes")
end

-- GE: pneumatic from its own engine; a stopped engine's reverser does not move
do
    local s, inp = R.new(), R.inputs()
    inp.type = "GE"
    inp.running = {true, true, true, false}
    inp.hyd_psi = {0, 0, 0, 0}             -- GE does not need hydraulics
    inp.want = {true, true, true, true}
    local o = run(s, inp, 5)
    T.check(o.reverse[1] and inp.position[1] >= 0.99, "GE: running engine's reverser deploys without hydraulics")
    T.check(not o.reverse[4] and inp.position[4] == 0, "GE: engine 4 stopped, its reverser does not move")
    T.check(o.message[4], "ENG 4 REVERSER")
end

-- the ground relays (ATA29_32 p.299): 1 and 4 primary, 2 and 3 alternate
do
    local s, inp = R.new(), R.inputs()
    inp.pri_gnd, inp.alt_gnd = true, false
    inp.want = {true, true, true, true}
    local o = run(s, inp, 5)
    T.check(o.reverse[1] and o.reverse[4] and not o.reverse[2] and not o.reverse[3],
        "primary relays on the ground only: reversers 1 and 4")
    T.check(not o.message[2], "no ENG REVERSER for a reverser locked out in the air (not asked)")
    -- in the air a deployed reverser is a fault
    inp.pri_gnd = false
    inp.want = {false, false, false, false}
    inp.position[1] = 1
    inp.hyd_psi[1] = 0                     -- and cannot stow
    o = run(s, inp, 2.5)
    T.check(o.message[1], "ENG 1 REVERSER: deployed in the air")
end

-- X-Plane's reverser failure shows the message
do
    local s, inp = R.new(), R.inputs()
    inp.xp_fail[2] = true
    local o = R.update(s, inp, DT)
    T.check(o.message[2] and not o.message[1], "X-Plane's failure: ENG 2 REVERSER")
end

T.done()
