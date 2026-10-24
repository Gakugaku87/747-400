-- Run from the repository root with LuaJIT: luajit tests/nav/gps_model_test.lua
-- The GPS model (plugins/xtlua/scripts/B747.34.xt.nav/B747.34.gps_model.lua,
-- 5-1 step 2) without X-Plane: power, the first fix, failures, the messages.
-- Sources: ATA34_2 p.378-379; FCOM p.1429.
local T = dofile("tests/lib/check.lua")("gps_model")
local G = dofile("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.gps_model.lua")

local s, inp, out = G.new(), G.inputs(), nil
inp.power = {false, false}
local function run(seconds) for _ = 1, seconds do out = G.update(s, inp, 1) end end
run(1)
T.check(not out.valid[1] and not out.valid[2], "unpowered: no GPS")
T.check(out.msg_both and not out.msg_l and not out.msg_r, ">GPS (both)")
inp.power[1] = true
run(1)
T.check(out.msg_r and not out.msg_both and not out.msg_l, "L powered: >GPS RIGHT")
T.check(not out.valid[1], "L acquiring")
run(72)
T.check(not out.valid[1], "not before 75 s")
run(3)
T.check(out.valid[1], "the first fix within 75 s (ATA34_2 p.378)")
inp.power[2] = true
run(76)
T.check(out.valid[2] and not out.msg_r, "R too")
inp.fail[1] = true
run(1)
T.check(not out.valid[1] and out.msg_l, "L failed: >GPS LEFT")
inp.fail[1] = false
run(1)
T.check(not out.valid[1] and not out.msg_l, "repaired: acquiring again, no message")
-- a start with the GPS working
s = G.new()
inp.power = {true, true}
G.fix_now(s, inp)
run(1)
T.check(out.valid[1] and out.valid[2], "fix_now: both navigating")
T.done()
