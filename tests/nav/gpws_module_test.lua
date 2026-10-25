-- Run from the repository root with LuaJIT: luajit tests/nav/gpws_module_test.lua
-- The radio altimeter and GPWS glues (B747.34.xt.ra.lua, B747.34.xt.gpws.lua,
-- 5-1 step 4) in the navigation sensors module (B747.34.xt.nav) as XTLua runs
-- it (tests/lib/xtlua.lua): X-Plane's radio altimeters, the buses, the EIU
-- selectors, the failures, the air data and IRS of the module, the gear
-- lever, the FCU's flaps, the GND PROX panel, the CDU's sound options in;
-- each PFD's radio altitude, the GPWS's voice, callout, lights and EICAS
-- messages out. The models are tested in ra_model_test.lua and
-- gpws_model_test.lua; this checks the wiring.
local T = dofile("tests/lib/check.lua")("gpws_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.nav.lua")
local function frames(seconds, dt)
    dt = dt or 1 / 30
    for _ = 1, math.floor(seconds / dt + 0.5) do rt:frame(dt) end
end
local I = "sim/cockpit2/gauges/indicators/"
local RA, GP = "laminar/B747/ra/", "laminar/B747/gpws/"
local ADV = "laminar/B747/CAS/advisory_status"
local function ra(ft)
    -- X-Plane's radio altimeters read 8 ft more than the PFD shows
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
for _, s in ipairs({"pilot", "copilot", "stby"}) do rt:set("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_" .. s, 29.92) end
for _, s in ipairs({"pilot", "copilot", "stby"}) do
    rt:set(I .. "airspeed_kts_" .. s, 160)
    rt:set(I .. "altitude_ft_" .. s, 3000)
end
rt:set("sim/flightmodel/position/indicated_airspeed", 160)
rt:set("laminar/B747/flt_inst/air_data_src/fo/sel_dial_pos", 1)
rt:set("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos", 2)
rt:set("laminar/B747/flt_inst/eiu_src/capt/sel_dial_pos", 1)      -- AUTO
rt:set("laminar/B747/flt_inst/eiu_src/fo/sel_dial_pos", 2)        -- AUTO
rt:set("laminar/B747/gear/air_ground/pri_air", 1)
rt:set("sim/cockpit2/controls/gear_handle_down", 1)
for i = 0, 3 do rt:set("laminar/B747/flt_ctrls/fcu/te_deg", i, 30) end
rt:set("sim/flightmodel/position/elevation", 3000 / 3.28084)
ra(3000)
for i = 0, 2 do rt:set("laminar/B747/flt_mgmt/iru/mode_sel_dial_pos", i, 2) end
rt:callout("flight_start")
rt:command("laminar/B747/irs/align_now")
frames(4)
T.equal(rt:get("laminar/B747/irs/nav_valid", 0), 1, "the IRUs at NAV (quick start)")

-- the radio altimeters and each PFD
T.equal(rt:get(RA .. "capt/show"), 0, "3,000 ft: blank (above 2,500 ft)")
T.equal(rt:get(RA .. "capt/flag"), 0, "no RA flag")
ra(1234)
frames(0.2)
T.equal(rt:get(RA .. "capt/show"), 1, "1,234 ft: shown")
T.equal(rt:get("laminar/B747/efis/radio_altitude"), 1240, "the Captain's digits: 20 ft steps")
T.equal(rt:get("laminar/B747/efis/radio_altitude_fo"), 1240, "the F/O's")
T.near(rt:get(RA .. "capt/value"), 1234, 0.01, "the radio altitude (X-Plane less 8 ft)")
ra(87)
frames(0.2)
T.equal(rt:get("laminar/B747/efis/radio_altitude"), 88, "below 100 ft: 2 ft steps")
rt:set(I .. "radio_altimeter_height_ft_copilot", 300 + 8)
frames(0.2)
T.equal(rt:get("laminar/B747/efis/radio_altitude_fo"), 300, "the F/O's from R (X-Plane's copilot side)")
T.equal(rt:get("laminar/B747/efis/radio_altitude"), 88, "the Captain's from L")
rt:set("laminar/B747/flt_inst/eiu_src/capt/sel_dial_pos", 3)      -- R
frames(0.2)
T.equal(rt:get("laminar/B747/efis/radio_altitude"), 300, "Captain's EIU on R: R")
rt:set("laminar/B747/flt_inst/eiu_src/capt/sel_dial_pos", 1)
rt:set("sim/operation/failures/rel_cop_radalt", 6)
frames(0.2)
T.equal(rt:get(RA .. "valid", 2), 0, "X-Plane's copilot radio altimeter failed: R")
T.equal(rt:get("laminar/B747/efis/radio_altitude_fo"), 88, "the F/O's AUTO takes C (X-Plane's pilot side)")
rt:set(RA .. "fail", 0, 1)
rt:set(RA .. "fail", 1, 1)
frames(0.2)
T.equal(rt:get(RA .. "capt/flag"), 1, "all three failed: the RA flag")
T.equal(rt:get(RA .. "capt/show"), 0, "no digits")
T.equal(rt:get(RA .. "gpwc_valid"), 0, "the GPWC has no radio altitude")
T.equal(rt:get(ADV, 6), 1, ">ALT CALLOUTS")
T.equal(rt:get(ADV, 181), 1, "GND PROX SYS")
rt:set(RA .. "fail", 0, 0)
rt:set(RA .. "fail", 1, 0)
rt:set("sim/operation/failures/rel_cop_radalt", 0)
rt:set("laminar/B747/electrical/bus/ac", 2, 0)
frames(0.2)
T.equal(rt:get(RA .. "valid", 0), 0, "AC bus 3 off: L unpowered")
T.equal(rt:get(ADV, 181), 1, "the GPWC unpowered too (AC bus 3): GND PROX SYS")
rt:set("laminar/B747/electrical/bus/ac", 2, 1)
frames(0.2)
T.equal(rt:get(ADV, 181), 0, "back: no GND PROX SYS")

-- the GPWS: an approach in landing configuration from 1,200 ft, callouts
ra(1200)
frames(1)
local heard, last = {}, 0
local h = 1200
for _ = 1, 30 * 140 do
    h = h - 600 / 60 / 30
    ra(math.max(h, -8))
    rt:set("sim/flightmodel/position/vh_ind_fpm", -600)
    rt:set("sim/flightmodel/position/elevation", math.max(h, 0) / 3.28084)
    rt:frame(1 / 30)
    local c = rt:get(GP .. "callout")
    if c ~= 0 and c ~= last then heard[#heard + 1] = c end
    last = c
end
T.equal(table.concat(heard, ","), "1000,500,100,50,40,30,20,10", "the callouts of the 405 (no minimums set)")
T.equal(rt:get(GP .. "last_callout"), 10, "the last callout held (for the flight tests)")
-- the CDU's options in the sound bank's order: gpws[3] is 500
rt:set("laminar/B747/gear/air_ground/pri_air", 1)
ra(1200)
rt:set("sim/flightmodel/position/vh_ind_fpm", 0)
frames(2)
rt:set("laminar/B747/fmod/options/gpws", 3, 1)
rt:set("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_pilot", 200)
heard, last, h = {}, 0, 1200
for _ = 1, 30 * 67 do
    h = h - 1000 / 60 / 30
    ra(h)
    rt:set("sim/flightmodel/position/vh_ind_fpm", -1000)
    rt:frame(1 / 30)
    local c = rt:get(GP .. "callout")
    if c ~= 0 and c ~= last then heard[#heard + 1] = c end
    last = c
end
T.equal(table.concat(heard, ","), "1000,1,2,100", "500 off; APPROACHING MINIMUMS (1), MINIMUMS (2) at the Captain's DH 200")
rt:set("laminar/B747/fmod/options/gpws", 3, 0)

-- mode 1: SINK RATE, PULL UP, the lights
ra(1000)
rt:set("sim/flightmodel/position/vh_ind_fpm", 0)
frames(2)
rt:set("sim/flightmodel/position/vh_ind_fpm", -3000)
frames(0.2)
T.equal(rt:get(GP .. "voice"), 1, "3,000 fpm at 1,000 ft: SINK RATE (voice 1)")
T.equal(rt:get(GP .. "gnd_prox_light"), 1, "GND PROX light")
T.equal(rt:get(GP .. "pull_up"), 0, "no PULL UP")
rt:set("sim/flightmodel/position/vh_ind_fpm", -4500)
frames(0.2)
T.equal(rt:get(GP .. "voice"), 2, "4,500 fpm: PULL UP (voice 2)")
T.equal(rt:get(GP .. "pull_up"), 1, "PULL UP on the PFDs")
T.equal(rt:get(GP .. "warning"), 1, "the warning (master WARNING)")
rt:set("sim/flightmodel/position/vh_ind_fpm", 0)
frames(0.2)
T.equal(rt:get(GP .. "warning"), 0, "over")

-- mode 5 from NAV 1: X-Plane's deflection is negative below the glide slope
-- (s43_gpws), the localizer within 2 dots, the gear down, below 1,000 ft
rt:set("sim/cockpit2/radios/indicators/nav1_display_vertical", 1)
rt:set("sim/cockpit2/radios/indicators/nav1_display_horizontal", 1)
rt:set("sim/cockpit2/radios/indicators/nav1_hdef_dots_pilot", 0.3)
rt:set("sim/cockpit2/radios/indicators/nav1_vdef_dots_pilot", 1.6)
ra(1100)
frames(0.5)
h = 1100
for _ = 1, 30 * 10 do
    h = h - 1000 / 60 / 30
    ra(h)
    rt:frame(1 / 30)
end
T.equal(rt:get(GP .. "voice"), 0, "1.6 dots above the glide slope (X-Plane +1.6): no GLIDE SLOPE")
rt:set("sim/cockpit2/radios/indicators/nav1_vdef_dots_pilot", -1.6)
frames(0.2)
T.equal(rt:get(GP .. "voice"), 8, "1.6 dots below (X-Plane -1.6): GLIDE SLOPE (voice 8)")
-- G/S INHB: the GPWS counts the pushes (the manipulators add one each)
rt:set(GP .. "gs_inhb_pushes", 1)
frames(0.2)
T.equal(rt:get(GP .. "gs_inhibited"), 1, "a push below 1,000 ft: the glide slope alert inhibited")
T.equal(rt:get(GP .. "voice"), 0, "GLIDE SLOPE cancelled")
rt:set("sim/cockpit2/radios/indicators/nav1_vdef_dots_pilot", 0)
ra(1100)
frames(0.2)
T.equal(rt:get(GP .. "gs_inhibited"), 0, "above 1,000 ft: over")

-- the GND PROX panel: TERR OVRD, FLAP OVRD
rt:set("laminar/B747/button_switch/position", 6, 1)
frames(0.2)
T.equal(rt:get(ADV, 289), 1, ">TERR OVRD")
rt:set("laminar/B747/button_switch/position", 6, 0)
frames(0.2)
T.equal(rt:get(ADV, 289), 0, "off")
T.equal(rt:get(ADV, 288), 0, "GPS: no TERR POS")
-- windshear (X-Plane's reactive detection)
rt:set("sim/cockpit2/annunciators/windshear_warning_systems", 5)
frames(0.2)
T.equal(rt:get(GP .. "windshear"), 1, "WINDSHEAR on the PFDs")
T.equal(rt:get(GP .. "voice"), 10, "the voice (10)")
rt:set("sim/cockpit2/annunciators/windshear_warning_systems", 0)
frames(6)
T.equal(rt:get(GP .. "windshear"), 0, "over after 5 s")
T.done()
