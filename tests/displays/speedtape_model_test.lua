-- Run from the repository root with LuaJIT: luajit tests/displays/speedtape_model_test.lua
-- The PFD speed tape model (plugins/xtlua_keysystems/scripts/
-- B747.60.xt.fltInst/B747.60.speedtape_model.lua, 5-2 step 3a) without
-- X-Plane: the flap maneuver speeds (FCOM PI.10.3) from the FMC's VREFs,
-- which bugs show (FCOM p.972) and when the minimum maneuvering speed band
-- shows (FCOM p.973).
local T = dofile("tests/lib/check.lua")("speedtape_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.speedtape_model.lua")

local s, inp, out
local DT = 0.25                         -- exact in binary: the ground time adds up exactly
local function run() out = M.update(s, inp, DT) end
local function hold(seconds) for _ = 1, seconds / DT do run() end end
local function lever(detent) inp.flap_ratio = detent / 6 end
local function shown()
    local t = {}
    for k = M.UP, M.F30 do if out.show_vf[k] then t[#t + 1] = k end end
    return table.concat(t, ",")
end

-- the maneuver speeds (FCOM PI.10.3) from the FMC's VREF 30 and 25 (6-1/6-2
-- step 3d: the tables in tests/fms/vref_model_test.lua)
s, inp = M.new(), M.inputs()
inp.vref30, inp.vref25, inp.alt_ft, inp.air = 150, 164, 0, true
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
-- (2026-11-24, review PERF-5) a FLAP/SPEED above the FMC's VREF for its
-- flaps raises the flap speed schedule by the difference (FCOM p.1412
-- (11.43.24)): UP to 20; the 25 and 30 bugs stay the FMC's VREFs
inp.land_flap, inp.vref_sel = M.LAND_30, 158
run()
T.check(out.vf[M.UP] == 238 and out.vf[M.F1] == 218 and out.vf[M.F5] == 198 and out.vf[M.F10] == 178
    and out.vf[M.F20] == 168, "30/158 over VREF30 150: UP to 20 up 8 kt")
T.check(out.vf[M.F25] == 164 and out.vf[M.F30] == 150, "the 25 and 30 bugs the FMC's VREFs")
inp.land_flap, inp.vref_sel = M.LAND_25, 170
run()
T.equal(out.vf[M.UP], 236, "25/170 over VREF25 164: up 6 kt")
inp.vref_sel = 160
run()
T.equal(out.vf[M.UP], 230, "25/160 under VREF25 164: as VREF30's")
inp.land_flap, inp.vref_sel = M.LAND_NONE, 170
run()
T.equal(out.vf[M.F10], 170, "no landing flaps selected (deleted): as VREF30's")
inp.vref_sel = 0
inp.land_flap = M.LAND_NONE
lever(M.UP); inp.alt_ft = 21000; run()
T.equal(shown(), "", "above about 20,000 ft: no bugs (FCOM p.972)")
inp.alt_ft = 19000; run()
T.equal(shown(), "0", "below: the UP bug again")
inp.alt_ft = 0

-- the minimum maneuvering speed band (FCOM p.973)
s, inp = M.new(), M.inputs()
inp.vref30 = 150
lever(M.F20)
run()
T.check(not out.show_mins, "on the ground: not shown")
hold(M.GROUND_S)
inp.air = true
run()
T.check(not out.show_mins, "after lift-off at flaps 20: not yet")
lever(M.F10); run()
T.check(out.show_mins, "the first flap retraction: shown")
lever(M.F20); run()
T.check(out.show_mins, "stays with flaps extended again")
inp.air = false
run()
T.check(out.show_mins, "touchdown: still shown")
hold(M.GROUND_S)
T.check(not out.show_mins, "landed: cleared")
s, inp = M.new(), M.inputs()
inp.air = true
run()
T.check(out.show_mins, "a flight started in the air: shown (estimate)")
-- an air start that reads ground for a moment at 200 kt
s, inp = M.new(), M.inputs()
inp.air, inp.ias = false, 200
run()
inp.air = true
lever(M.F20); run()
T.check(out.show_mins, "air start with a moment of ground at 200 kt: still shown")
-- the aircraft reloaded in the air: ground and 0 kt for a moment
s, inp = M.new(), M.inputs()
inp.air, inp.ias = false, 0
hold(2)
T.check(not out.show_mins, "reloaded in the air, the first 2 s read ground at 0 kt: not yet")
inp.air, inp.ias = true, 170
run()
T.check(out.show_mins, "then air: shown")
-- the landing rollout: cleared after GROUND_S below 100 kt
inp.air, inp.ias = false, 130
hold(M.GROUND_S + 1)
T.check(out.show_mins, "rolling out at 130 kt: still shown")
inp.ias = 90
hold(M.GROUND_S - 1)
T.check(out.show_mins, "4 s below 100 kt: still shown")
hold(1)
T.check(not out.show_mins, "5 s below 100 kt on the ground: cleared")

-- (2026-11-24, DSP-4) the 570's (GE) V2 bug: for the takeoff, removed on
-- the climb-out as the flap retraction begins (FCOM p.972 (10.10.10)); the
-- 109 and 405 show none; none without a V2 selected (999)
s, inp = M.new(), M.inputs()
inp.vref30, inp.v2, inp.v2_bug = 150, 165, true
lever(M.F20)
hold(M.GROUND_S)
T.check(out.show_v2, "570: V2 selected, on the ground before takeoff: shown")
inp.ias = 150
run()
T.check(out.show_v2, "570: the takeoff roll: shown")
inp.air, inp.ias = true, 170
run()
T.check(out.show_v2, "570: after lift-off at flaps 20: still shown (V1 and VR go at lift-off)")
lever(M.F10); run()
T.check(not out.show_v2, "570: the flap retraction begins: removed")
lever(M.F20); run()
T.check(not out.show_v2, "570: flaps out again: stays removed")
s, inp = M.new(), M.inputs()
inp.v2, inp.v2_bug = 999, true
hold(M.GROUND_S)
T.check(not out.show_v2, "570: no V2 selected (999): none")
s, inp = M.new(), M.inputs()
inp.v2, inp.v2_bug = 165, false
lever(M.F20)
hold(M.GROUND_S)
T.check(not out.show_v2, "109 (P&W) and 405: no V2 on the speed tape")
s, inp = M.new(), M.inputs()
inp.v2, inp.v2_bug, inp.air, inp.ias = 165, true, true, 250
run()
T.check(not out.show_v2, "570: a flight started in the air: none")

T.done()
