-- Run from the repository root with LuaJIT: luajit tests/engines/engine_display_model_test.lua
-- The engine indication model (plugins/xtlua/scripts/B747.40.xt.engines/
-- B747.40.engine_display_model.lua) against FCOM p.837-838, p.872, p.879 and
-- ATA70_80 p.356-357, p.395: the EGT colours, the amber inhibit after a
-- TO/GA push (5 minutes; P&W 10 with an engine out) and the start limit line.
local T = dofile("tests/lib/check.lua")("engine_display_model")
local D = dofile("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_display_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.floor(seconds / DT + 0.5) do
        out = D.update(s, inp, DT)
        inp.toga = false
    end
    return out
end
local function all(t, v)
    for n = 1, 4 do if t[n] ~= v then return false end end
    return true
end

-- the limits: CF6-80C2 from ATA70_80 p.395
T.equal(D.EGT.GE.red, 960, "CF6 EGT takeoff limit 960 °C")
T.equal(D.EGT.GE.amber, 925, "CF6 EGT continuous limit 925 °C")
T.equal(D.EGT.GE.start, 750, "CF6 EGT start limit 750 °C")

-- running engines: white below the amber band, amber in it, red at the red line
do
    local s, inp = D.new(), D.inputs()
    inp.type = "GE"
    inp.cutoff = {false, false, false, false}
    inp.running = {true, true, true, true}
    inp.egt = {800, 925, 959, 960}
    local o = D.update(s, inp, DT)
    T.check(all(o.start_limit, false), "running: no start limit line")
    T.check(o.white[1] and not o.amber[1] and not o.red[1], "EGT 800: white")
    T.check(o.amber[2] and not o.white[2], "EGT 925 (the continuous limit): amber")
    T.check(o.amber[3], "EGT 959: amber")
    T.check(o.red[4] and not o.amber[4] and not o.white[4], "EGT 960 (the takeoff limit): red")
    -- TO/GA pushed: amber held off for 5 minutes, red is not
    inp.toga = true
    o = run(s, inp, 1)
    T.check(o.inhibit, "TO/GA: inhibit on")
    T.check(o.white[2] and o.white[3], "TO/GA: white in the amber band")
    T.check(o.red[4], "TO/GA: still red at the red line")
    o = run(s, inp, 298)
    T.check(o.white[2], "TO/GA: white just before 5 minutes")
    o = run(s, inp, 2)
    T.check(o.amber[2] and not o.inhibit, "amber again 5 minutes after the TO/GA push")
    -- GE: an engine out does not lengthen it
    inp.toga = true
    inp.running[4] = false
    run(s, inp, 1)
    o = run(s, inp, 300)
    T.check(o.amber[2], "GE: 5 minutes even with an engine out")
end

-- P&W: 10 minutes with an engine failed or shut down
do
    local s, inp = D.new(), D.inputs()
    inp.type = "PW"
    inp.cutoff = {false, false, false, false}
    inp.running = {true, true, true, true}
    inp.egt = {640, 640, 640, 640}
    local o = D.update(s, inp, DT)
    T.check(all(o.amber, true), "P&W EGT 640: amber (continuous limit 629)")
    inp.toga = true
    o = run(s, inp, 100)
    inp.running[2] = false                 -- engine 2 fails during the takeoff
    o = run(s, inp, 250)
    T.check(o.white[1] and o.inhibit, "P&W, engine out: still white after 6 minutes")
    o = run(s, inp, 260)
    T.check(o.amber[1] and not o.inhibit, "P&W, engine out: amber after 10 minutes")
    -- a second push starts the window again
    inp.toga = true
    o = run(s, inp, 1)
    T.check(o.white[1], "a second TO/GA push holds amber off again")
end

-- the start limit line (FCOM p.838, p.879): at CUTOFF and until the start
-- settles at idle; the EGT turns red at the start limit while it shows
do
    local s, inp = D.new(), D.inputs()
    inp.type = "PW"
    local o = D.update(s, inp, DT)
    T.check(all(o.start_limit, true), "CUTOFF: start limit line shown")
    inp.egt = {534, 535, 20, 20}
    o = D.update(s, inp, DT)
    T.check(o.white[1] and o.red[2], "start limit 535: red from 535 (P&W)")
    inp.cutoff[1], inp.starting[1] = false, true   -- RUN, the start under way
    inp.egt[1] = 540
    o = D.update(s, inp, DT)
    T.check(o.start_limit[1] and o.red[1], "RUN during the start: the line stays, red past the start limit")
    inp.starting[1], inp.running[1] = false, true  -- the start settled at idle
    inp.egt[1] = 540
    o = D.update(s, inp, DT)
    T.check(not o.start_limit[1] and o.white[1], "after the start: no line, 540 is white")
    inp.type = "GE"
    inp.egt = {760, 760, 760, 760}
    inp.cutoff = {false, true, true, true}
    o = D.update(s, inp, DT)
    T.check(o.white[1] and o.red[2], "GE: 760 is white running, red at the 750 start limit")
end

T.done()
