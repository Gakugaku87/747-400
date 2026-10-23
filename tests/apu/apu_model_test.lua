-- Run from the repository root with LuaJIT: luajit tests/apu/apu_model_test.lua
-- The APU model (plugins/xtlua/scripts/B747.03.xt.electrical/B747.49.apu_model.lua)
-- against FCOM 7.14, 7.30 and 7.40 (p.867-869, p.895-897, p.902): the start
-- by START and back to ON (SP.6.2, p.180), the door before the starter, the
-- run, the unloaded cooldown, the automatic shutdowns and the messages. A
-- stand-in for X-Plane's APU spins N1 as the starter command says.
local T = dofile("tests/lib/check.lua")("apu_model")
local A = dofile("plugins/xtlua/scripts/B747.03.xt.electrical/B747.49.apu_model.lua")

local DT = 1 / 30
-- X-Plane's APU as seen from outside: 2 spins it up (to 100 % in 50 s),
-- 1 holds it, 0 runs it down (100 to 0 in 20 s); stuck = it ignores 0
local xp = {n1 = 0, stuck = false, dead = false}
local function xplane(starter, dt)
    if xp.dead then
        xp.n1 = math.max(0, xp.n1 - 5 * dt)
    elseif starter == 2 then
        xp.n1 = math.min(100, xp.n1 + 2 * dt)
    elseif starter == 1 and xp.n1 >= 90 then
        xp.n1 = 100
    elseif starter == 0 and not xp.stuck then
        xp.n1 = math.max(0, xp.n1 - 5 * dt)
    end
end
local function run(s, inp, seconds, watch)
    local out = s.out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do
        inp.n1, inp.running = xp.n1, xp.n1 >= 90
        out = A.update(s, inp, DT)
        inp.start_pushed = false
        xplane(out.starter, DT)
        if watch then watch(out) end
    end
    return out
end
local function fresh()
    xp.n1, xp.stuck, xp.dead = 0, false, false
    return A.new(), A.inputs()
end
-- turn the selector to START and let it go back to ON (FCOM p.180)
local function start(inp)
    inp.selector, inp.start_pushed = 1, true
end

-- cold: selector OFF, door closed, nothing commanded, no messages
do
    local s, inp = fresh()
    local out = run(s, inp, 2)
    T.equal(out.state, A.OFF, "cold: OFF")
    T.equal(out.door, 0, "cold: inlet door closed")
    T.equal(out.starter, 0, "cold: X-Plane's APU starter off")
    T.check(not (out.adv_apu or out.adv_door or out.memo_running or out.gen_ready), "cold: no messages, no generator")
    T.equal(out.oil, 1.00, "cold: oil 1.00 (estimate)")
end

-- selector ON only: the door opens and the APU waits; neither APU nor APU
-- DOOR (APU-03, APU-04)
do
    local s, inp = fresh()
    inp.selector = 1
    local alerts = false
    local out = run(s, inp, 60, function(o) alerts = alerts or o.adv_apu or o.adv_door end)
    T.equal(out.door, 1, "ON: inlet door open")
    T.equal(out.state, A.OFF, "ON: no start without START")
    T.equal(out.starter, 0, "ON: starter off")
    T.check(not alerts, "ON: no APU or APU DOOR while it waits (APU-03, APU-04)")
end

-- the FCOM start: START and straight back to ON; the starter engages only
-- with the door fully open (APU-07, APU-13), then RUNNING at 95 %
do
    local s, inp = fresh()
    start(inp)
    local engaged_door, alerts = nil, false
    local out = run(s, inp, 100, function(o)
        if o.starter == 2 and not engaged_door then engaged_door = o.door end
        alerts = alerts or o.adv_apu or o.adv_door
    end)
    T.equal(engaged_door, 1, "start: the starter engages with the door fully open (FCOM p.896)")
    T.equal(out.state, A.RUNNING, "start: RUNNING after START and back to ON (APU-13)")
    T.equal(out.starter, 1, "start: X-Plane's APU held running")
    T.check(out.memo_running, "start: APU RUNNING memo (selector ON, N1 > 95 %)")
    T.check(out.gen_ready, "start: generators ready")
    T.check(not alerts, "start: no APU or APU DOOR on the way")
    T.near(out.n2, 92.6, 0.1, "start: N2 92.6 at N1 100 (FCOM p.868 figure, estimate)")
    out = run(s, inp, 300)
    T.near(out.oil, 0.92, 0.01, "start: oil 0.92 while running (estimate)")

    -- OFF: 60 s unloaded cooldown (generators and bleed off at once), then
    -- shutdown, the door closes once it has run down (FCOM p.897)
    inp.selector = 0
    out = run(s, inp, 1)
    T.equal(out.state, A.COOLDOWN, "OFF: cooldown")
    T.check(not out.gen_ready, "OFF: generators off in the unloaded cooldown (estimate)")
    T.check(not out.memo_running, "OFF: no APU RUNNING with the selector OFF")
    T.equal(out.starter, 1, "OFF: still running in the cooldown")
    local advisory = false
    out = run(s, inp, 57, function(o) advisory = advisory or o.adv_apu end)
    T.equal(out.state, A.COOLDOWN, "OFF: still cooling down at 58 s")
    out = run(s, inp, 3, function(o) advisory = advisory or o.adv_apu end)
    T.equal(out.starter, 0, "OFF: shut down after 60 s")
    out = run(s, inp, 30, function(o) advisory = advisory or o.adv_apu end)
    T.equal(out.state, A.OFF, "OFF: OFF once run down")
    T.equal(out.door, 0, "OFF: inlet door closed")
    T.check(not advisory, "OFF: no APU advisory in a normal shutdown")
end

-- back ON in the cooldown: it keeps running; BATTERY OFF in the cooldown
-- stops it at once (FCOM p.897)
do
    local s, inp = fresh()
    start(inp)
    run(s, inp, 100)
    inp.selector = 0
    run(s, inp, 20)
    inp.selector = 1
    local out = run(s, inp, 1)
    T.equal(out.state, A.RUNNING, "back ON in the cooldown: running again")
    T.check(out.gen_ready, "back ON in the cooldown: generators ready")
    inp.selector = 0
    run(s, inp, 10)
    inp.battery = false
    out = run(s, inp, 0.1)
    T.equal(out.starter, 0, "BATTERY OFF in the cooldown: shut down at once")
    T.check(not out.fault, "BATTERY OFF: no fault")
end

-- a fire stops it at once and latches the fault: the APU advisory with the
-- selector ON, no restart until the selector goes OFF (FCOM p.867, p.897, p.902)
do
    local s, inp = fresh()
    start(inp)
    run(s, inp, 100)
    inp.fire = true
    local out = run(s, inp, 0.1)
    T.equal(out.starter, 0, "fire: shut down at once")
    T.check(out.fault and out.adv_apu, "fire: fault and APU advisory (selector ON)")
    T.check(not out.gen_ready, "fire: generators off")
    inp.fire = false
    start(inp)
    out = run(s, inp, 60)
    T.equal(out.state, A.OFF, "fire: START does nothing before the selector goes OFF")
    T.equal(out.door, 0, "fire: the door closes once it has run down")
    T.check(out.adv_apu, "fire: APU advisory stays")
    inp.selector = 0
    out = run(s, inp, 1)
    T.check(not out.fault and not out.adv_apu, "fire: selector OFF clears the fault and the advisory")
    start(inp)
    out = run(s, inp, 100)
    T.equal(out.state, A.RUNNING, "fire: starts again after OFF")
end

-- no fuel in main tank 2: it flames out (estimate)
do
    local s, inp = fresh()
    start(inp)
    run(s, inp, 100)
    inp.fuel = false
    local out = run(s, inp, 0.1)
    T.check(out.fault and out.adv_apu and out.starter == 0, "no fuel: shut down, APU advisory")
end

-- a start that does not reach 95 % in 120 s from the starter engaging (the
-- door takes 12 s first) is shut down (estimate)
do
    local s, inp = fresh()
    xp.dead = true
    start(inp)
    local out = run(s, inp, 125)
    T.check(not out.fault, "hung start: still trying 113 s after the starter engaged")
    out = run(s, inp, 10)
    T.check(out.fault and out.adv_apu, "hung start: shut down after 120 s with the APU advisory")
    T.equal(out.starter, 0, "hung start: starter off")
end

-- selector OFF but X-Plane's APU keeps running at 100 %: the APU advisory
-- once the cooldown is over (FCOM p.902)
do
    local s, inp = fresh()
    start(inp)
    run(s, inp, 100)
    xp.stuck = true
    inp.selector = 0
    local out = run(s, inp, 65)
    T.check(not out.adv_apu, "stuck: no APU advisory just after the cooldown")
    out = run(s, inp, 10)
    T.check(out.adv_apu, "stuck: APU advisory with the selector OFF above 95 %")
end

-- a flight that starts with the APU running and the selector ON: taken over
do
    local s, inp = fresh()
    xp.n1 = 100
    inp.selector = 1
    local out = run(s, inp, 0.1)
    T.equal(out.state, A.RUNNING, "taken over: RUNNING")
    T.check(out.gen_ready and out.starter == 1, "taken over: generators ready, kept running")
end

T.done()
