-- Run from the repository root with LuaJIT: luajit tests/displays/speedtape_model_test.lua
-- The PFD speed tape model (plugins/xtlua_keysystems/scripts/
-- B747.60.xt.fltInst/B747.60.speedtape_model.lua, 5-2 step 3a) without
-- X-Plane: the flap maneuver speeds (FCOM PI.10.3), VREF25 (FCOM PI.10.2),
-- which bugs show (FCOM p.972) and when the minimum maneuvering speed band
-- shows (FCOM p.973).
local T = dofile("tests/lib/check.lua")("speedtape_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.speedtape_model.lua")

local s, inp, out
local function run() out = M.update(s, inp) end
local function lever(detent) inp.flap_ratio = detent / 6 end
local function shown()
    local t = {}
    for k = M.UP, M.F30 do if out.show_vf[k] then t[#t + 1] = k end end
    return table.concat(t, ",")
end

-- VREF25 (FCOM PI.10.2)
T.near(M.vref25(300000, 0), 164, 1e-9, "300 t: 164 kt")
T.near(M.vref25(310000, 0), 167, 1e-9, "310 t: halfway between 164 and 170")
T.near(M.vref25(400000, 4000), 193, 1e-9, "400 t at 4,000 ft: 192 + 1")
T.near(M.vref25(150000, 0), 132, 1e-9, "below the table: its lightest weight")

-- the maneuver speeds (FCOM PI.10.3)
s, inp = M.new(), M.inputs()
inp.vref30, inp.weight_kg, inp.alt_ft, inp.air = 150, 300000, 0, true
run()
T.equal(out.vf[M.UP], 230, "UP: VREF30 + 80")
T.equal(out.vf[M.F1], 210, "1: + 60")
T.equal(out.vf[M.F5], 190, "5: + 40")
T.equal(out.vf[M.F10], 170, "10: + 20")
T.equal(out.vf[M.F20], 160, "20: + 10")
T.equal(out.vf[M.F25], 164, "25: VREF25 (before VREF30 + 5)")
T.equal(out.vf[M.F30], 150, "30: VREF30")

-- the bugs: the current flap setting and the next lesser one (FCOM p.972)
lever(M.UP); run()
T.equal(shown(), "0", "flaps up: UP")
lever(M.F5); run()
T.equal(shown(), "1,2", "flaps 5: 5 and 1")
lever(M.F20); run()
T.equal(shown(), "3,4", "flaps 20: 20 and 10 (before, 20 stayed shown at 30)")
lever(M.F30); run()
T.equal(shown(), "5,6", "flaps 30, no landing flaps selected: 30 and 25")
inp.land_flap = M.LAND_30
run()
T.equal(shown(), "5", "landing flaps 30 selected: the REF bug is VREF30, 25 stays")
inp.land_flap = M.LAND_25
lever(M.F25); run()
T.equal(shown(), "4", "flaps 25 with landing flaps 25: 20 (25 is the REF bug)")
inp.land_flap = M.LAND_NONE

-- the minimum maneuvering speed band (FCOM p.973)
s, inp = M.new(), M.inputs()
inp.vref30 = 150
lever(M.F20)
run()
T.check(not out.show_mins, "on the ground: not shown")
inp.air = true
run()
T.check(not out.show_mins, "after lift-off at flaps 20: not yet")
lever(M.F10); run()
T.check(out.show_mins, "the first flap retraction: shown")
lever(M.F20); run()
T.check(out.show_mins, "stays with flaps extended again")
inp.air = false
run()
T.check(not out.show_mins, "landed: cleared")
s, inp = M.new(), M.inputs()
inp.air = true
run()
T.check(out.show_mins, "a flight started in the air: shown (estimate)")

T.done()
