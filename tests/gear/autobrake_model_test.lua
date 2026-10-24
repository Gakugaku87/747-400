-- Run from the repository root with LuaJIT: luajit tests/gear/autobrake_model_test.lua
-- The autobrake model (plugins/xtlua/scripts/B747.10.xt.gear/B747.10.autobrake_model.lua)
-- against FCOM 14.20 and ATA29_32 32-42 (docs/overhaul/notes/ATA-32.md §4.8):
-- the selector's latch, the landing arm, application, deceleration and
-- disarm, the level's pressure limit, RTO, the memo and AUTOBRAKES. A simple
-- airplane: the deceleration in ft/s² is X-Plane's brake ratio times a
-- braking power, plus the reversers.
local T = dofile("tests/lib/check.lua")("autobrake_model")
local M = dofile("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.autobrake_model.lua")

local DT = 0.05
local function flight(power, reverse)
    -- one step of the simple airplane, then the model
    return function(s, inp)
        local out = M.update(s, inp, DT)
        inp.dial = out.dial                     -- the selector moves, as the glue writes it
        local decel = out.cmd * power + (reverse or 0)
        inp.gs_kt = math.max(0, inp.gs_kt - decel / 1.68781 * DT)
        return out
    end
end
local function run(s, inp, seconds, step)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do
        if step then out = step(s, inp)
        else
            out = M.update(s, inp, DT)
            inp.dial = out.dial
        end
    end
    return out
end
local function landing(dial)
    local s, inp = M.new(), M.inputs()
    inp.air, inp.gnd, inp.gnd_both = true, false, false
    inp.levers = {0.4, 0.4, 0.4, 0.4}
    inp.gs_kt = 145
    inp.dial = dial
    local out = run(s, inp, 1)
    inp.dial = out.dial
    return s, inp, out
end
local function touchdown(inp)
    inp.air, inp.gnd, inp.gnd_both = false, true, true
    inp.levers = {0, 0, 0, 0}
end

-- arming in the air with approach thrust; application after touchdown at
-- idle once the wheels spin up (3 s over 60 kt); the deceleration held
do
    local s, inp, out = landing(6)               -- AUTOBRAKES 4: 7.5 ft/s²
    T.check(out.armed, "AUTOBRAKES 4 in the air: armed")
    T.equal(out.dial, 6, "the selector stays (latched)")
    T.equal(out.memo, 6, "the memo AUTOBRAKES 4")
    T.check(not out.autobrakes, "no AUTOBRAKES advisory")
    touchdown(inp)
    out = run(s, inp, 2.5, flight(30))
    T.equal(out.cmd, 0, "2.5 s on the ground: the wheels not spun up yet")
    out = run(s, inp, 6, flight(30))
    T.near(out.decel, 7.5, 0.4, "AUTOBRAKES 4 holds 7.5 ft/s² (" .. string.format("%.2f", out.decel) .. ")")
    T.check(out.cmd < M.MAX_PSI[6] / 3000 + 1e-9, "within the level's 2050 psi")
    -- the reversers add 3 ft/s²: the autobrake lets the pressure down to keep the decel
    local before = out.cmd
    out = run(s, inp, 4, flight(30, 3))
    T.near(out.decel, 7.5, 0.4, "with the reversers still 7.5")
    T.check(out.cmd < before - 0.05, "less pressure with the reversers (" .. string.format("%.3f -> %.3f", before, out.cmd) .. ")")
    -- the pedals disarm: DISARM, AUTOBRAKES, the pressure let go slowly
    inp.pedal = {0.3, 0}
    out = run(s, inp, 0.05, flight(30))
    T.equal(out.dial, M.DISARM, "pedal over 750 psi: DISARM")
    T.check(out.autobrakes, "AUTOBRAKES")
    T.equal(out.memo, nil, "no memo")
    T.check(out.cmd > 0.05, "the pressure bleeding, not gone at once")
    out = run(s, inp, 3, flight(30))
    T.equal(out.cmd, 0, "gone after the orifice's time")
end

-- the level's pressure limit: AUTOBRAKES 1 (1300 psi) on weak brakes falls short
do
    local s, inp = landing(3)
    touchdown(inp)
    local out = run(s, inp, 10, flight(5))
    T.near(out.cmd, 1300 / 3000, 1e-6, "AUTOBRAKES 1 capped at 1300 psi")
    T.check(out.decel < 4.0 - 1, "short of its 4.0 ft/s²")
end

-- the disarms: a thrust lever advanced after idle on the ground; the
-- speedbrakes stowed after their deployment; the normal pressure lost while
-- applying with the decel short; but not losing system 4 armed in the air
do
    local s, inp = landing(5)
    touchdown(inp)
    run(s, inp, 1, flight(30))
    inp.levers[2] = 0.3
    local out = run(s, inp, 0.1, flight(30))
    T.equal(out.dial, M.DISARM, "lever 2 advanced after touchdown: DISARM")
    s, inp = landing(5)
    touchdown(inp)
    inp.speedbrake = 1
    run(s, inp, 1, flight(30))
    inp.speedbrake = 0
    out = run(s, inp, 0.1, flight(30))
    T.equal(out.dial, M.DISARM, "speedbrakes stowed on the ground: DISARM")
    s, inp = landing(5)
    inp.normal = false
    out = run(s, inp, 1)
    T.equal(out.dial, 5, "system 4 lost in the air: the selector stays armed")
    T.check(out.autobrakes, "armed but disabled: AUTOBRAKES")
    touchdown(inp)
    out = run(s, inp, 5, flight(30))
    T.equal(out.cmd, 0, "no normal brakes: no autobraking")
    s, inp = landing(5)
    touchdown(inp)
    run(s, inp, 5, flight(30))
    inp.normal = false
    out = run(s, inp, 1, flight(30))
    T.equal(out.dial, M.DISARM, "the normal pressure lost while applying, the decel short: DISARM")
end

-- the latch: selected on the ground with thrust above idle, or with the
-- pedals pushed, the selector springs to DISARM
do
    local s, inp = M.new(), M.inputs()
    inp.levers = {0.5, 0.5, 0.5, 0.5}
    inp.dial = 4
    local out = run(s, inp, 0.1)
    T.equal(out.dial, M.DISARM, "on the ground with thrust: not latched, DISARM")
    s, inp = M.new(), M.inputs()
    inp.dial = 4
    out = run(s, inp, 0.1)
    T.check(out.armed and out.dial == 4, "on the ground at idle: armed")
    s, inp = M.new(), M.inputs()
    inp.irs = false
    inp.dial = 7
    out = run(s, inp, 0.1)
    T.equal(out.dial, M.DISARM, "no IRS: DISARM")
end

-- RTO: armed on the ground; maximum pressure when the levers come back above
-- 85 kt; nothing below 85 kt; the pedals disable it (the selector stays);
-- airborne it trips to OFF
do
    local s, inp = M.new(), M.inputs()
    inp.dial = M.RTO
    local out = run(s, inp, 0.1)
    T.check(out.armed, "RTO armed on the ground")
    T.equal(out.memo, M.RTO, "the memo AUTOBRAKES RTO")
    inp.levers = {0.9, 0.9, 0.9, 0.9}
    inp.gs_kt = 70
    run(s, inp, 1)
    inp.levers = {0, 0, 0, 0}
    out = run(s, inp, 0.5)
    T.equal(out.cmd, 0, "rejected at 70 kt: no RTO braking")
    s, inp = M.new(), M.inputs()
    inp.dial = M.RTO
    inp.levers = {0.9, 0.9, 0.9, 0.9}
    inp.gs_kt = 100
    run(s, inp, 1)
    inp.levers = {0, 0, 0, 0}
    out = run(s, inp, 0.1, flight(20))
    T.equal(out.cmd, 1, "rejected at 100 kt: maximum pressure")
    inp.pedal = {0.8, 0.8}
    out = run(s, inp, 3, flight(20))
    T.equal(out.cmd, 0, "the pedals: RTO disabled")
    T.equal(out.dial, M.RTO, "the selector stays at RTO")
    s, inp = M.new(), M.inputs()
    inp.dial = M.RTO
    run(s, inp, 0.1)
    inp.air, inp.gnd, inp.gnd_both = true, false, false
    out = run(s, inp, 0.1)
    T.equal(out.dial, M.OFF, "airborne: the selector trips to OFF")
    T.check(not out.autobrakes and out.memo == nil, "no indication")
end

T.done()
