-- Run from the repository root with LuaJIT: luajit tests/nav/wxr_module_test.lua
-- The weather radar glue (B747.34.xt.wxr.lua, 5-1 step 5c) in the navigation
-- sensors module (B747.34.xt.nav) as XTLua runs it (tests/lib/xtlua.lua): the
-- 570 panel's commands (this aircraft's TFR, TEST, LR/T, RR/T and X-Plane's
-- replaced radar commands), the EFIS WXR switches (X-Plane's weather on), the
-- buses, the IRUs and the ND ranges in; X-Plane's radar for each ND and the
-- panel's lamps out. Then the ND's annunciations (B747.61.xt.nd.lua) and the
-- lamps in the lighting module. The model is tested in wxr_model_test.lua;
-- this checks the wiring.
local T = dofile("tests/lib/check.lua")("wxr_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.nav.lua")
local function frames(seconds, dt)
    dt = dt or 1 / 30
    for _ = 1, math.floor(seconds / dt + 0.5) do rt:frame(dt) end
end
local E = "sim/cockpit2/EFIS/EFIS_weather_"
local B = "laminar/B747/wxr/buttons/"
local L = "laminar/B747/wxr/lamp/"
local function cmd(name) rt:command("sim/instruments/EFIS_wxr_" .. name) frames(0.1) end
local function button(name) rt:command(B .. name) frames(0.1) end
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
for _, b in ipairs({"stby_main", "xfr_capt", "xfr_fo", "hot_bat_apu", "gnd_svc"}) do
    rt:set("laminar/B747/electrical/bus/" .. b, 1)
end
for i = 0, 2 do rt:set("laminar/B747/flt_mgmt/iru/mode_sel_dial_pos", i, 2) end   -- NAV
rt:set("laminar/B747/flt_inst/irs_src/capt/sel_dial_pos", 0)
rt:set("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos", 2)
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 1)              -- 20 nm
rt:set("laminar/B747/nd/range/fo/sel_dial_pos", 1)
-- X-Plane's radar as the last flight left it
rt:set(E .. "mode", 3)
rt:set(E .. "mode_copilot", 3)
rt:set(E .. "tilt", 3.1)
rt:set(E .. "tilt_copilot", -1)
rt:set(E .. "gain", 1)
rt:set(E .. "gain_copilot", 1)
rt:callout("flight_start")
rt:command("laminar/B747/irs/align_now")
frames(4)
T.equal(rt:get("laminar/B747/irs/att_valid", 0), 1, "the IRUs aligned (quick start)")

-- off until an EFIS WXR switch: the R/T on (FCOM p.1040)
T.equal(rt:get(E .. "mode"), 0, "no EFIS WXR: X-Plane's radar off (Captain)")
T.equal(rt:get(E .. "mode_copilot"), 0, "and F/O")
T.equal(rt:get(L .. "rt"), 0, "the panel dark without the R/T")
T.equal(rt:get(E .. "sector_width"), 90, "the antenna scans 90 deg each side (ATA34_1 p.231)")
T.equal(rt:get(E .. "antenna_limit"), 90, "antenna limit 90 deg")
rt:set(E .. "on", 1)
frames(0.1)
T.equal(rt:get(E .. "mode"), 3, "the Captain's WXR: WX+T as X-Plane's radar was left")
T.equal(rt:get(E .. "mode_copilot"), 3, "the F/O's ND too (the R/T is on)")
T.near(rt:get(E .. "tilt"), 3.1, 1e-6, "the Captain's tilt kept")
T.near(rt:get(E .. "tilt_copilot"), -1, 1e-6, "the F/O's tilt kept")
T.equal(rt:get(L .. "sel", 0), 2, "WX+T lit (Captain)")
T.equal(rt:get(L .. "rt"), 1, "LR/T lit")
T.equal(rt:get(E .. "stab"), 1, "stabilized (IRU L)")

-- X-Plane's radar commands move the model's panel
cmd("radar_map")
T.equal(rt:get(E .. "mode"), 4, "MAP (Captain)")
T.equal(rt:get(E .. "mode_copilot"), 3, "the F/O's side keeps WX+T")
cmd("gain_down")
cmd("gain_down")
T.near(rt:get(E .. "gain"), 0.8, 1e-6, "MAP: the MAP GAIN knob")
cmd("tilt_up")
T.near(rt:get(E .. "tilt"), 3.2, 1e-6, "tilt up 0.1 deg")
cmd("radar_wx")
T.near(rt:get(E .. "gain"), 1, 1e-6, "WX: calibrated gain")
cmd("gcs_tog_copilot")
T.equal(rt:get(E .. "gcs_copilot"), 1, "GCS on the F/O's side")
T.equal(rt:get(L .. "gcs", 1), 1, "the F/O's GCS lit")
cmd("radar_map_copilot")
cmd("gain_down_copilot")
rt:set(E .. "on_copilot", 1)

-- TFR and TEST (FCOM p.1223-1224)
button("cpt_ftr")
T.equal(rt:get(E .. "mode"), 4, "the Captain's TFR: the F/O's MAP")
T.near(rt:get(E .. "tilt"), -1, 1e-6, "with the F/O's tilt")
T.near(rt:get(E .. "gain"), 0.9, 1e-6, "and gain")
T.equal(rt:get(E .. "gcs"), 1, "and GCS")
T.equal(rt:get(L .. "sel", 0), 4, "TFR lit")
button("fo_ftr")
T.equal(rt:get(E .. "mode"), 1, "both TFR: TEST")
T.equal(rt:get(L .. "test"), 1, "TEST lit")
cmd("radar_wx")
cmd("radar_wx_copilot")
button("test")
T.equal(rt:get(E .. "mode"), 1, "TEST: the Captain's ND")
T.equal(rt:get(E .. "mode_copilot"), 1, "and the F/O's")
cmd("radar_wxt")
T.equal(rt:get(E .. "mode"), 3, "the Captain's WX+T ends the test there")
T.equal(rt:get(E .. "mode_copilot"), 1, "the F/O's ND still in TEST")
cmd("radar_wx_copilot")

-- WX+T beyond 40 nm (FCOM p.1224)
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 3)              -- 80 nm
frames(0.1)
T.equal(rt:get(E .. "mode"), 2, "80 nm: WX")
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 1)

-- the R/T and its stabilization (ATA34_1 p.210, p.242)
button("rr")
T.equal(rt:get(L .. "rt"), 2, "RR/T lit")
rt:set("laminar/B747/electrical/bus/ac", 1, 0)
frames(0.1)
T.equal(rt:get(E .. "mode"), 0, "the R R/T without AC bus 2: no radar (estimate)")
rt:set("laminar/B747/electrical/bus/ac", 1, 1)
rt:set("laminar/B747/irs/fail/iru", 2, 1)
frames(0.1)
T.equal(rt:get(E .. "stab"), 0, "IRU R failed: unstabilized")
T.equal(rt:get(E .. "stab_copilot"), 0, "both NDs (one antenna)")
rt:set("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos", 1)
frames(0.1)
T.equal(rt:get(E .. "stab"), 1, "the F/O's IRS selector at C: IRU C")
rt:set("sim/operation/failures/rel_wxr_radar", 6)
frames(0.1)
T.equal(rt:get(E .. "mode"), 0, "X-Plane's radar failure: no radar")
rt:set("sim/operation/failures/rel_wxr_radar", 0)
button("lr")
frames(0.1)
T.equal(rt:get(E .. "mode"), 2, "LR/T: the radar back")

-- the ND's annunciations (FCOM p.1155)
rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
rt:set("laminar/B747/debug/nd", -3)     -- stop after the annunciations (no navigation data files here)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)               -- MAP
rt:set("laminar/B747/nd/mode/fo/sel_dial_pos", 2)
rt:callout("flight_start")
rt:command("laminar/B747/irs/align_now")
frames(4)
local ND = "laminar/B747/nd/"
T.equal(rt:get(ND .. "capt/text/wxr"), "WXR", "the Captain's ND: WXR")
T.equal(rt:get(ND .. "capt/text/tilt"), "+3", "tilt +3 in whole degrees (FCOM p.1013)")
T.equal(rt:get(ND .. "fo/text/tilt"), "-1", "the F/O's -1")
button("test")
frames(1)
T.equal(rt:get(ND .. "capt/text/wxr"), "TEST", "TEST")
T.equal(rt:get(ND .. "capt/text/tilt"), " ", "the tilt field left for faults in TEST (FCOM p.1224)")
cmd("radar_map")
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 3)               -- PLN
frames(1)
T.equal(rt:get(ND .. "capt/text/wxr"), " ", "PLN: no weather radar annunciations")
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 1)               -- VOR
rt:set("laminar/B747/nd/map_center/capt", 1)
frames(1)
T.equal(rt:get(ND .. "capt/text/wxr"), " ", "VOR centred: none (ATA34_1 p.244)")
rt:set("laminar/B747/nd/map_center/capt", 0)
frames(1)
T.equal(rt:get(ND .. "capt/text/wxr"), "MAP", "VOR expanded: MAP")
T.equal(rt:get(ND .. "capt/text/wxr_color", 0), 1, "the mode in cyan")
T.equal(rt:get(ND .. "capt/text/wxr3"), "CAL", "MAP at the calibrated gain: CAL (estimate)")
T.equal(rt:get(ND .. "capt/text/wxr_color", 2), 1, "in cyan")
cmd("gain_down")
frames(1)
T.equal(rt:get(ND .. "capt/text/wxr3"), "VAR", "the gain turned down: VAR (ATA34_1 p.244)")
-- the faults (5-1 step 5d: FCOM p.1155, p.1224; ATA34_1 p.246)
rt:set("laminar/B747/wxr/fail", 0, 1)                            -- the antenna
frames(1)
T.equal(rt:get("laminar/B747/wxr/nd_fail", 0), 1, "the antenna: WXR FAIL")
T.equal(rt:get(E .. "mode"), 0, "no returns")
T.equal(rt:get(ND .. "capt/text/wxr"), "WXR", "WXR")
T.equal(rt:get(ND .. "capt/text/tilt"), "FAIL", "FAIL")
T.equal(rt:get(ND .. "capt/text/wxr_color", 0), 2, "in amber")
T.equal(rt:get(ND .. "capt/text/wxr_color", 1), 2, "both lines")
T.equal(rt:get(ND .. "capt/text/wxr3"), " ", "no third line")
button("test")
frames(1)
T.equal(rt:get(ND .. "capt/text/wxr"), "TEST", "TEST")
T.equal(rt:get(ND .. "capt/text/tilt"), "ANT", "the fault source in the tilt field (FCOM p.1224)")
T.equal(rt:get(ND .. "capt/text/wxr_color", 1), 2, "in amber")
cmd("radar_wx")
cmd("radar_wx_copilot")
rt:set("laminar/B747/wxr/fail", 0, 0)
rt:set("laminar/B747/wxr/fail", 2, 1)                            -- the calibration
frames(1)
T.equal(rt:get(ND .. "capt/text/wxr"), "WXR", "WEAK: the mode stays")
T.equal(rt:get(ND .. "capt/text/wxr3"), "WEAK", "WEAK on the third line")
T.equal(rt:get(ND .. "capt/text/wxr_color", 2), 2, "in amber")
T.equal(rt:get(E .. "mode"), 2, "the returns stay")
rt:set("laminar/B747/wxr/fail", 2, 0)
frames(1)
T.equal(rt:get(ND .. "capt/text/wxr3"), " ", "WX: no gain shown")
rt:set(E .. "on", 0)
rt:set(E .. "on_copilot", 0)
frames(1)
T.equal(rt:get(ND .. "capt/text/wxr"), " ", "the R/T off: no mode (before, RT)")

T.done()
