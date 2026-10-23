-- Run from the repository root with LuaJIT: luajit tests/engines/exceedance_model_test.lua
-- The engine exceedance boxes (plugins/xtlua/scripts/B747.40.xt.engines/
-- B747.40.exceedance_model.lua) against FCOM p.873 and ATA70_80 p.345-346,
-- p.355-356: a box stays red after its parameter is back to normal, CANC
-- turns it white once the readout is white, RCL turns it red again; a CF6 N2
-- above its red line for more than 20 s stays red.
local T = dofile("tests/lib/check.lua")("exceedance_model")
local X = dofile("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.exceedance_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.floor(seconds / DT + 0.5) do
        out = X.update(s, inp, DT)
        inp.cancel, inp.recall = 0, 0
    end
    return out
end

-- an EGT exceedance: red box while red and after, CANC white, RCL red again
do
    local s, inp = X.new(), X.inputs()
    local o = run(s, inp, 0.5)
    T.check(not o.box_red.egt[1], "no exceedance: white box")
    inp.red.egt[1] = true
    o = run(s, inp, 1)
    T.check(o.box_red.egt[1] and o.red.egt[1], "EGT at its limit: red readout, red box")
    inp.cancel = 1
    o = run(s, inp, 0.1)
    T.check(o.box_red.egt[1], "CANC while still red: the box stays red")
    inp.red.egt[1] = false
    o = run(s, inp, 1)
    T.check(o.box_red.egt[1] and not o.red.egt[1], "back to normal: the box stays red as a reminder")
    T.check(not o.box_red.egt[2], "the other engines' boxes white")
    inp.cancel = 1
    o = run(s, inp, 0.1)
    T.check(not o.box_red.egt[1], "CANC with the readout white: white box")
    inp.recall = 1
    o = run(s, inp, 0.1)
    T.check(o.box_red.egt[1], "RCL: the stored exceedance shows red again")
    inp.recall = 1
    o = run(s, inp, 0.1)
    T.check(not o.box_red.egt[2], "RCL: nothing stored for engine 2, white")
    -- a new exceedance after a CANC shows red again
    inp.cancel = 1
    run(s, inp, 0.1)
    inp.red.egt[1] = true
    o = run(s, inp, 0.1)
    T.check(o.box_red.egt[1], "a new exceedance after CANC: red box")
end

-- a new flight clears what is stored
do
    local s, inp = X.new(), X.inputs()
    inp.red.n1[3] = true
    run(s, inp, 0.5)
    inp.red.n1[3] = false
    local o = run(s, inp, 0.5)
    T.check(o.box_red.n1[3], "N1 3 stored: red box")
    s = X.new()
    o = run(s, inp, 0.1)
    T.check(not o.box_red.n1[3], "a new flight: white box")
end

-- the CF6's N2: more than 20 s above the red line stays red (ATA70_80 p.345)
do
    local s, inp = X.new(), X.inputs()
    inp.type = "GE"
    inp.red.n2[2] = true
    run(s, inp, 15)
    inp.red.n2[2] = false
    local o = run(s, inp, 0.5)
    T.check(not o.red.n2[2], "15 s over: the readout turns white again")
    T.check(o.box_red.n2[2], "15 s over: red box (stored)")
    inp.red.n2[2] = true
    run(s, inp, 21)
    inp.red.n2[2] = false
    o = run(s, inp, 0.5)
    T.check(o.red.n2[2], "21 s over: N2 stays red")
    inp.cancel = 1
    o = run(s, inp, 0.1)
    T.check(o.box_red.n2[2], "N2 held red: CANC leaves the box red")
    -- P&W: no such rule in the manuals
    s = X.new()
    inp.type = "PW"
    inp.red.n2[2] = true
    run(s, inp, 21)
    inp.red.n2[2] = false
    o = run(s, inp, 0.5)
    T.check(not o.red.n2[2], "P&W, 21 s over: the readout turns white again")
end

T.done()
