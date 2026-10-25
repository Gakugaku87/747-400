-- Run from the repository root with LuaJIT: luajit tests/nav/wxr_model_test.lua
-- The weather radar model (plugins/xtlua/scripts/B747.34.xt.nav/
-- B747.34.wxr_model.lua, 5-1 step 5c) without X-Plane: the 570 panel (modes,
-- TFR, TEST, tilt and MAP gain, GCS, R/T selection), the R/T's power and
-- failure, the stabilization IRU, the 40 nm limit of WX+T and the panel's
-- lamps. Sources: FCOM p.1040, p.1223-1224; ATA34_1 p.210, p.242, p.253-256,
-- p.260.
local T = dofile("tests/lib/check.lua")("wxr_model")
local M = dofile("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.wxr_model.lua")

local s, inp, out
local function run() out = M.update(s, inp) end
local function fresh()
    s, inp = M.new(), M.inputs()
    inp.on[1], inp.on[2] = true, true
    run()
end

-- off until an EFIS WXR switch turns the R/T on (FCOM p.1040)
s, inp = M.new(), M.inputs()
run()
T.equal(out.operating, false, "no EFIS WXR: the R/T is off")
T.equal(out.xp_mode[1], M.XP_OFF, "X-Plane's radar off (Captain)")
T.equal(out.xp_mode[2], M.XP_OFF, "and F/O")
T.equal(out.lamp_sel[1], 0, "the panel unlit without the R/T (ATA34_1 p.210)")
inp.on[2] = true
run()
T.equal(out.operating, true, "the F/O's WXR turns the R/T on")
T.equal(out.xp_mode[1], M.XP_WX, "both sides in WX")
T.equal(out.xp_mode[2], M.XP_WX, "F/O WX")
T.equal(out.lamp_sel[1], M.SEL_WX, "WX lit")
T.equal(out.lamp_rt, M.RT_L, "LR/T lit (the L R/T at the start)")

-- modes and the automatic gain (FCOM p.1223, ATA34_1 p.260)
fresh()
M.gain(s, 1, -1)
M.gain(s, 1, -1)
run()
T.near(out.gain[1], 1, 1e-9, "WX: calibrated gain whatever the MAP GAIN knob")
M.mode(s, 1, M.SEL_MAP)
run()
T.equal(out.xp_mode[1], M.XP_MAP, "MAP")
T.near(out.gain[1], 0.8, 1e-9, "MAP: the MAP GAIN knob")
T.equal(out.xp_mode[2], M.XP_WX, "the F/O's side keeps WX")
for _ = 1, 10 do M.gain(s, 1, 1) end
run()
T.near(out.gain[1], 1, 1e-9, "the knob stops at CAL")
for _ = 1, 20 do M.gain(s, 1, -1) end
run()
T.near(out.gain[1], 0, 1e-9, "and at zero")
M.mode(s, 1, M.SEL_WXT)
run()
T.equal(out.xp_mode[1], M.XP_WXT, "WX+T at 40 nm")
T.near(out.gain[1], 1, 1e-9, "WX+T: calibrated gain")

-- WX+T beyond 40 nm becomes WX (FCOM p.1224)
inp.range_nm[1] = 80
run()
T.equal(out.xp_mode[1], M.XP_WX, "80 nm: WX")
inp.range_nm[1] = 40
run()
T.equal(out.xp_mode[1], M.XP_WX, "back at 40 nm it stays WX")
T.equal(out.lamp_sel[1], M.SEL_WX, "the WX switch lit")
M.mode(s, 1, M.SEL_WXT)
inp.range_nm[2] = 160
run()
T.equal(out.xp_mode[1], M.XP_WXT, "the Captain's WX+T with the F/O's ND at 160 nm")

-- tilt and GCS
fresh()
for _ = 1, 30 do M.tilt(s, 1, 1) end
run()
T.near(out.tilt[1], 3, 1e-9, "tilt +3 in 0.1 deg steps")
T.near(out.tilt[2], 0, 1e-9, "the F/O's tilt apart")
for _ = 1, 300 do M.tilt(s, 1, 1) end
run()
T.near(out.tilt[1], 15, 1e-9, "tilt up to +15 (FCOM p.1223)")
for _ = 1, 400 do M.tilt(s, 1, -1) end
run()
T.near(out.tilt[1], -15, 1e-9, "and down to -15")
M.toggle_gcs(s, 2)
run()
T.equal(out.gcs[2], true, "GCS on the F/O's side")
T.equal(out.gcs[1], false, "not the Captain's")
T.equal(out.lamp_gcs[2], true, "the GCS switch lit")

-- TFR: the other side's display; both TFR is TEST (FCOM p.1223)
fresh()
M.mode(s, 2, M.SEL_MAP)
for _ = 1, 25 do M.tilt(s, 2, -1) end
M.gain(s, 2, -1)
M.toggle_gcs(s, 2)
M.mode(s, 1, M.SEL_TFR)
run()
T.equal(out.xp_mode[1], M.XP_MAP, "the Captain's TFR shows the F/O's MAP")
T.near(out.tilt[1], -2.5, 1e-9, "with the F/O's tilt")
T.near(out.gain[1], 0.9, 1e-9, "and gain")
T.equal(out.gcs[1], true, "and GCS")
T.equal(out.lamp_sel[1], M.SEL_TFR, "TFR lit")
M.mode(s, 2, M.SEL_TFR)
run()
T.equal(out.xp_mode[1], M.XP_TEST, "both TFR: TEST on the Captain's ND")
T.equal(out.xp_mode[2], M.XP_TEST, "and the F/O's")
T.equal(out.lamp_test, true, "TEST lit")
M.mode(s, 1, M.SEL_WX)
run()
T.equal(out.xp_mode[1], M.XP_WX, "the Captain back to WX")
T.equal(out.xp_mode[2], M.XP_WX, "the F/O's TFR now shows the Captain's WX")

-- TEST: both NDs until a mode switch or the WXR off on that side (FCOM p.1224)
fresh()
M.test(s)
run()
T.equal(out.xp_mode[1], M.XP_TEST, "TEST on the Captain's ND")
T.equal(out.xp_mode[2], M.XP_TEST, "and the F/O's")
T.near(out.gain[1], 1, 1e-9, "TEST: calibrated gain")
M.mode(s, 1, M.SEL_WXT)
run()
T.equal(out.xp_mode[1], M.XP_WXT, "a mode switch ends the test on that side")
T.equal(out.xp_mode[2], M.XP_TEST, "the F/O's ND still in TEST")
inp.on[2] = false
run()
T.equal(out.xp_mode[1], M.XP_WXT, "the Captain's side goes on")
inp.on[2] = true
run()
T.equal(out.xp_mode[2], M.XP_WX, "the F/O's WXR off and on ended its test")
s, inp = M.new(), M.inputs()
run()
M.test(s)
inp.on[1] = true
run()
T.equal(out.xp_mode[1], M.XP_WX, "TEST with the R/T off does nothing")

-- the R/T: selection, power, failure (ATA34_1 p.210, p.253, p.256)
fresh()
inp.power[1] = false
run()
T.equal(out.operating, false, "the L R/T without power: no radar")
T.equal(out.xp_mode[1], M.XP_OFF, "X-Plane's radar off")
T.equal(out.lamp_rt, 0, "the panel dark")
M.select_rt(s, M.RT_R)
run()
T.equal(out.operating, true, "RR/T: the R R/T works")
T.equal(out.lamp_rt, M.RT_R, "RR/T lit")
inp.failed = true
run()
T.equal(out.operating, false, "X-Plane's radar failure: no radar")

-- the stabilization IRU (ATA34_1 p.242)
fresh()
inp.att_valid = {false, true, true}
run()
T.equal(out.stab, false, "L R/T, Captain's IRS selector at L, IRU L without attitude: unstabilized")
inp.irs_src[1] = 1
run()
T.equal(out.stab, true, "the selector at C: IRU C")
inp.irs_src[1] = 2
run()
T.equal(out.stab, true, "at R: still IRU C (not R)")
inp.att_valid = {true, false, true}
run()
T.equal(out.stab, false, "IRU C without attitude")
M.select_rt(s, M.RT_R)
inp.irs_src[2] = 2
run()
T.equal(out.stab, true, "R R/T with the F/O's selector at R: IRU R")
inp.irs_src[2] = 0
run()
T.equal(out.stab, false, "the F/O's selector at L: IRU C")

T.done()
