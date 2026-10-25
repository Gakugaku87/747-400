-- Run from the repository root with LuaJIT: luajit tests/nav/tcas_module_test.lua
-- The transponder and TCAS glue (B747.34.xt.tcas.lua, 5-1 step 5) in the
-- navigation sensors module (B747.34.xt.nav) as XTLua runs it
-- (tests/lib/xtlua.lua): the 570 panel, the buses, the failures, the radio
-- altitude, the displays' power, the EFIS panels and X-Plane's TCAS in;
-- X-Plane's transponder mode, the voice, the ND symbols and messages, the
-- PFD values and the EICAS messages out. Then the switches in
-- xtlua_keysystems (the mode selector, the TFC switches). The model is
-- tested in tcas_model_test.lua; this checks the wiring.
local T = dofile("tests/lib/check.lua")("tcas_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.nav.lua")
local function frames(seconds, dt)
    dt = dt or 1 / 30
    for _ = 1, math.floor(seconds / dt + 0.5) do rt:frame(dt) end
end
local I = "sim/cockpit2/gauges/indicators/"
local TC, TG, TI = "laminar/B747/tcas/", "sim/cockpit2/tcas/targets/", "sim/cockpit2/tcas/indicators/"
local ADV = "laminar/B747/CAS/advisory_status"
local XPDR_MODE = "sim/cockpit2/radios/actuators/transponder_mode"
local function ra(ft)
    rt:set(I .. "radio_altimeter_height_ft_pilot", ft + 8)
    rt:set(I .. "radio_altimeter_height_ft_copilot", ft + 8)
end
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
for _, b in ipairs({"stby_main", "xfr_capt", "xfr_fo", "hot_bat_apu", "gnd_svc"}) do
    rt:set("laminar/B747/electrical/bus/" .. b, 1)
end
for i = 0, 7 do rt:set("laminar/B747/electrical/display_has_power", i, 1) end
rt:set("laminar/B747/gear/air_ground/pri_air", 1)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)               -- MAP
rt:set("laminar/B747/nd/mode/fo/sel_dial_pos", 2)
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 1)              -- 20 nm
rt:set("laminar/B747/nd/range/fo/sel_dial_pos", 1)
rt:set("laminar/B747/flt_inst/eiu_src/capt/sel_dial_pos", 1)      -- AUTO
rt:set("laminar/B747/flt_inst/eiu_src/fo/sel_dial_pos", 2)
rt:set("sim/flightmodel/position/true_airspeed", 165)
for j = 0, 63 do rt:set(TG .. "threat", j, -1) end
ra(3000)
rt:callout("flight_start")
frames(4)

-- the 570 panel: X-Plane's transponder mode (FCOM p.1218)
local function sel(pos)
    rt:set("laminar/B747/flt_mgmt/txpdr/mode_sel_pos", pos)
    frames(0.1)
end
sel(0)
T.equal(rt:get(XPDR_MODE), 1, "STBY: X-Plane standby")
T.equal(rt:get(ADV, 279), 1, ">TCAS OFF in the air above 400 ft (FCOM p.1605)")
sel(1)
T.equal(rt:get(XPDR_MODE), 2, "ALT RPTG OFF: mode A")
sel(2)
T.equal(rt:get(XPDR_MODE), 3, "XPDR: altitude reporting")
sel(3)
T.equal(rt:get(XPDR_MODE), 6, "TA ONLY")
T.equal(rt:get("laminar/B747/nd/capt/ta_only"), 1, "TA ONLY on the ND")
sel(4)
T.equal(rt:get(XPDR_MODE), 7, "TA/RA above 2,500 ft")
T.equal(rt:get(ADV, 279), 0, "no >TCAS OFF")
T.equal(rt:get(TC .. "operating"), 1, "the TCAS works")
T.equal(rt:get(TC .. "ra_mode"), 1, "RAs available")
ra(900)
frames(0.1)
T.equal(rt:get(XPDR_MODE), 6, "900 ft: TA only (FCOM p.1600)")
ra(3000)
frames(0.1)

-- a TA from X-Plane's TCAS
rt:set(TG .. "threat", 1, 2)
rt:set(TG .. "ssr_mode", 1, 3)
rt:set(TI .. "relative_distance_mtrs", 1, 6 * 1852)
rt:set(TI .. "relative_altitude_mtrs", 1, 150)
rt:set(TI .. "tcas_active_advisory", 1)
rt:set(TI .. "tcas_message", 14)
frames(0.1)
T.equal(rt:get(TC .. "sym", 1), 3, "target 1: TA")
T.equal(rt:get(TC .. "voice"), 1, "TRAFFIC, TRAFFIC")
T.equal(rt:get(TC .. "traffic"), 1, "amber TRAFFIC")
T.equal(rt:get("laminar/B747/nd/capt/tfc"), 1, "TFC on the Captain's ND automatically")
T.equal(rt:get("laminar/B747/nd/fo/tfc"), 1, "and the F/O's")
T.equal(rt:get("laminar/B747/nd/capt/tcas_show"), 1, "traffic drawn")
T.equal(rt:get("laminar/B747/nd/capt/traffic"), 1, "the ND's TRAFFIC amber")
frames(0.7)
T.equal(rt:get(TC .. "voice"), 0, "the voice code back to 0")
T.equal(rt:get(TC .. "last_voice"), 1, "the last voice held")
-- an RA: descend from traffic above
rt:set(TG .. "threat", 1, 4)
rt:set(TI .. "tcas_active_advisory", 2)
rt:set(TI .. "tcas_message", 6)
local B = 3.4e38
for k, v in ipairs({-2000, -2000, -2000, -1500, -1500, B}) do rt:set(TI .. "tcas_vs_bands", k - 1, v) end
frames(0.1)
T.equal(rt:get(TC .. "sym", 1), 4, "target 1: RA")
T.equal(rt:get(TC .. "voice"), 6, "DESCEND, DESCEND")
T.equal(rt:get("laminar/B747/nd/capt/traffic"), 2, "red TRAFFIC")
T.equal(rt:get(TC .. "pfd/ra"), 1, "RA guidance")
T.equal(rt:get(TC .. "pfd/hi_on"), 1, "a red region above")
T.equal(rt:get(TC .. "pfd/lo_on"), 0, "none below")
T.near(rt:get(TC .. "pfd/vs_hi"), -1500, 0.01, "red above -1,500 fpm")
local tas_fpm = 165 * 1.943844 * 6076.12 / 60
T.near(rt:get(TC .. "pfd/pitch_hi"), math.deg(math.asin(-1500 / tas_fpm)), 0.01,
    "level: the upper region's edge below the airplane symbol (the path of -1,500 fpm)")
T.equal(rt:get(TC .. "pfd/vs_red"), 1, "level is in the red region: the pointer red")
rt:set("sim/flightmodel/position/vh_ind_fpm", -1800)
frames(0.1)
T.equal(rt:get(TC .. "pfd/vs_red"), 0, "descending at 1,800 fpm: white")
T.check(rt:get(TC .. "pfd/pitch_hi") > 0, "the region above the airplane symbol")
rt:set("sim/flightmodel/position/vh_ind_fpm", 0)
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 0)             -- 10 nm
rt:set(TI .. "relative_distance_mtrs", 1, 12 * 1852)
frames(0.1)
T.equal(rt:get("laminar/B747/nd/capt/offscale"), 2, "beyond 10 nm: red OFFSCALE on the Captain's ND")
T.equal(rt:get("laminar/B747/nd/fo/offscale"), 0, "not on the F/O's (20 nm)")
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 1)
-- the RA ends
rt:set(TG .. "threat", 1, 1)
rt:set(TI .. "relative_distance_mtrs", 1, 1852)
rt:set(TI .. "tcas_active_advisory", 0)
rt:set(TI .. "tcas_message", 5)
frames(0.1)
T.equal(rt:get(TC .. "voice"), 5 + 9, "CLEAR OF CONFLICT")
T.equal(rt:get(TC .. "sym", 1), 2, "proximate")
T.equal(rt:get(TC .. "pfd/ra"), 0, "no RA guidance")
frames(1)

-- the selector away from TA ONLY, TA/RA: nothing shown, TCAS OFF on the NDs
sel(2)
T.equal(rt:get(TC .. "sym", 1), 0, "XPDR: no symbols")
T.equal(rt:get("laminar/B747/nd/capt/tcas_off"), 1, "TCAS OFF on the ND (TFC selected)")
T.equal(rt:get("laminar/B747/nd/capt/tfc"), 0, "no TFC")
T.equal(rt:get(ADV, 279), 1, ">TCAS OFF")
sel(4)

-- failures and power
rt:set("laminar/B747/xpdr/fail", 0, 1)
frames(0.1)
T.equal(rt:get(XPDR_MODE), 0, "L failed and selected: no transponder")
T.equal(rt:get(ADV, 292), 1, ">TRANSPONDER L")
T.equal(rt:get(ADV, 282), 1, ">TCAS SYSTEM")
T.equal(rt:get("laminar/B747/nd/capt/tcas_fail"), 1, "TCAS FAIL on the ND")
rt:set("laminar/B747/flt_mgmt/transponder/sel_dial_pos", 1)       -- R
frames(0.1)
T.equal(rt:get(XPDR_MODE), 7, "R selected: TA/RA")
T.equal(rt:get(ADV, 282), 0, "no >TCAS SYSTEM")
T.equal(rt:get(ADV, 292), 1, ">TRANSPONDER L stays")
rt:set("laminar/B747/electrical/bus/ac", 1, 0)                    -- AC bus 2: transponder R
frames(0.1)
T.equal(rt:get(ADV, 293), 1, "AC bus 2 off: >TRANSPONDER R (estimate)")
rt:set("laminar/B747/electrical/bus/ac", 1, 1)
rt:set("laminar/B747/xpdr/fail", 0, 0)
rt:set("laminar/B747/flt_mgmt/transponder/sel_dial_pos", 0)
frames(0.1)
T.equal(rt:get(ADV, 292) + rt:get(ADV, 293), 0, "both transponders back")
rt:set("sim/operation/failures/rel_xpndr", 6)
frames(0.1)
T.equal(rt:get(ADV, 292), 1, "X-Plane's transponder failure: >TRANSPONDER L")
rt:set("sim/operation/failures/rel_xpndr", 0)
rt:set("laminar/B747/electrical/bus/ac", 2, 0)                    -- AC bus 3: the TCAS
frames(0.1)
T.equal(rt:get(ADV, 282), 1, "AC bus 3 off: >TCAS SYSTEM")
rt:set("laminar/B747/electrical/bus/ac", 2, 1)
rt:set("laminar/B747/electrical/display_has_power", 0, 0)
frames(0.1)
T.equal(rt:get(ADV, 280), 1, "the Captain's PFD off: >TCAS RA CAPTAIN")
T.equal(rt:get(ADV, 281), 0, "not F/O")
rt:set("laminar/B747/electrical/display_has_power", 0, 1)
frames(0.1)
T.equal(rt:get(ADV, 280) + rt:get(ADV, 282), 0, "messages clear")

-- after a start X-Plane's mode follows the selector once the first reads are in
rt:set(XPDR_MODE, 3)
rt:callout("flight_start")
frames(4)
T.equal(rt:get(XPDR_MODE), 7, "after a start: TA/RA")

-- the switches in xtlua_keysystems
local ks = xtlua.new()
ks:load("plugins/xtlua_keysystems/scripts/B747.30.xt.fltMgmt/B747.30.xt.fltMgmt.lua")
ks:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
ks:set("sim/flightmodel/failures/onground_any", 1)
ks:callout("flight_start")
for _ = 1, 10 do ks:frame(1 / 30) end
T.equal(ks:get("laminar/B747/flt_mgmt/txpdr/mode_sel_pos"), 0, "on the ground: STBY")
ks:set(XPDR_MODE, 9)
ks:command("laminar/B747/flt_mgmt/transponder/mode_sel_dial_up")
ks:frame(1 / 30)
T.equal(ks:get("laminar/B747/flt_mgmt/txpdr/mode_sel_pos"), 1, "the selector turns")
T.equal(ks:get(XPDR_MODE), 9, "the selector no longer writes X-Plane's mode")
ks:command("laminar/B747/nd/traffic/capt/switch")
ks:frame(1 / 30)
T.equal(ks:get("laminar/B747/nd/traffic/capt/pushes"), 1, "the Captain's TFC switch counts its pushes")
ks:command("laminar/B747/nd/traffic/fo/switch")
ks:frame(1 / 30)
T.equal(ks:get("laminar/B747/nd/traffic/fo/pushes"), 1, "the F/O's")
T.equal(ks:get(ADV, 279), 0, "fltMgmt no longer writes >TCAS OFF")
ks:set("sim/flightmodel/failures/onground_any", 0)
ks:set("sim/operation/prefs/startup_running", 1)
ks:callout("flight_start")
for _ = 1, 10 do ks:frame(1 / 30) end
T.equal(ks:get("laminar/B747/flt_mgmt/txpdr/mode_sel_pos"), 4, "started in the air with the engines running: TA/RA (estimate)")

T.done()
