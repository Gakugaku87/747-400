-- Run from the repository root with LuaJIT: luajit tests/warning/takeoff_inhibit_glue_test.lua
-- (2026-11-12 review SF-1, SF-6; REVIEW_2026-11-12.md case 16) The takeoff
-- inhibits with the airspeed the warning module really gets: the air data
-- module's PFD airspeed, held at 30 kt at the least (B747.34.xt.airdata.lua's
-- MIN_IAS). FCOM p.1594-1595: from 80 kt to 400 ft no master CAUTION
-- light and no beeper, from V1 to 400 ft no master WARNING light and no
-- fire bell; what came up meanwhile announces at 400 ft.
-- Before: the inhibits armed below 30 kt only, so never (the PFD's 30 at
-- rest is not below 30): a caution in the takeoff roll lit the light and
-- beeped at once. And a master reset in an inhibit put the lights out and
-- dropped what was waiting (no announcement at 400 ft). Now the inhibits
-- arm at 30 kt or less, and the reset does nothing within the takeoff's
-- inhibits (the landing's as before).
local T = dofile("tests/lib/check.lua")("takeoff_inhibit_glue")
local xtlua = dofile("tests/lib/xtlua.lua")

local G = "sim/cockpit2/gauges/indicators/"
local PFD = "laminar/B747/gauges/indicators/airspeed_kts_pilot"
local CAUTION, WARNING = "laminar/B747/CAS/caution_status", "laminar/B747/CAS/warning_status"
local MC, MW = "laminar/B747/warning/master_caution", "laminar/B747/warning/master_warning"
local BEEP, BELL = "laminar/B747/warning/master_caution_audio", "laminar/B747/warning/warning_bell"
local RESET = "laminar/B747/warning/master_reset_count"

-- the warning and the navigation modules on the ground, the engines
-- running, V1 150; returns the runtime and its helpers
local function setup()
    local rt = xtlua.new()
    rt:load("plugins/xtlua/scripts/B747.87.xt.warning/B747.87.xt.warning.lua")
    rt:load("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.nav.lua")
    rt:set("sim/operation/prefs/startup_running", 1)
    for _, b in ipairs({"stby_main", "xfr_capt", "xfr_fo"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
    for _, s in ipairs({"pilot", "copilot", "stby"}) do
        rt:set("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_" .. s, 29.92)
    end
    rt:set("laminar/B747/flt_inst/air_data_src/fo/sel_dial_pos", 1)
    rt:callout("flight_start")
    local function ias(v)
        for _, s in ipairs({"pilot", "copilot", "stby"}) do rt:set(G .. "airspeed_kts_" .. s, v) end
    end
    local function frames(seconds) for _ = 1, math.floor(seconds * 50 + 0.5) do rt:frame(0.02) end end
    for i = 0, 3 do rt:set("laminar/B747/fuel/fuel_control/toggle_sw_pos", i, 1) end
    rt:set("laminar/B747/gear/air_ground/pri_air", 0)
    rt:set("laminar/B747/gear/air_ground/ng_compressed", 1)
    rt:set("laminar/B747/airspeed/V1", 150)
    rt:set(G .. "radio_altimeter_height_ft_pilot", 0)
    ias(0)
    frames(10)          -- the EIUs (4 s) and the air data model (3 s) up, standing
    return rt, ias, frames
end
local function lift_off(rt, ias, frames)
    rt:set("laminar/B747/gear/air_ground/ng_compressed", 0)
    frames(1)
    rt:set("laminar/B747/gear/air_ground/pri_air", 1)
    rt:set(G .. "radio_altimeter_height_ft_pilot", 200)
    ias(170)
    frames(2)
end

-- the takeoff: a caution at 120 kt, a warning past V1
local rt, ias, frames = setup()
T.equal(rt:get(PFD), 30, "the PFD's airspeed at rest: 30 kt (the air data's least)")
for v = 0, 120, 2 do ias(v) frames(0.2) end
rt:set(CAUTION, 42, 1)          -- HYD PRESS SYS 3 at 120 kt
frames(1)
T.equal(rt:get(MC), 0, "a caution at 120 kt: no master CAUTION light (FCOM p.1594)")
T.equal(rt:get(BEEP), 0, "and no beeper")
for v = 120, 160, 2 do ias(v) frames(0.2) end
rt:set(WARNING, 11, 1)          -- FIRE ENG 1 at 160 kt, past V1
frames(1)
T.equal(rt:get(MW), 0, "a warning past V1: no master WARNING light (FCOM p.1595)")
T.equal(rt:get(BELL), 0, "and no fire bell")
lift_off(rt, ias, frames)
T.check(rt:get(MC) == 0 and rt:get(MW) == 0, "200 ft: still inhibited")
rt:set(G .. "radio_altimeter_height_ft_pilot", 450)
frames(1)
T.equal(rt:get(MC), 1, "400 ft: the caution announced, master CAUTION")
T.equal(rt:get(MW), 1, "and the warning, master WARNING")

-- a master reset in the inhibit: the lights lit before stay, what came up
-- meanwhile still announces at 400 ft
rt, ias, frames = setup()
for v = 0, 50, 2 do ias(v) frames(0.2) end
rt:set(CAUTION, 42, 1)          -- before 80 kt: announced at once
frames(1)
T.equal(rt:get(MC), 1, "a caution at 50 kt (before the inhibit): master CAUTION")
for v = 50, 120, 2 do ias(v) frames(0.2) end
rt:set(CAUTION, 43, 1)          -- another at 120 kt: waits
frames(1)
rt:set(RESET, (rt:get(RESET) or 0) + 1)   -- the crew pushes the master CAUTION light
frames(1)
T.equal(rt:get(MC), 1, "a reset within the takeoff's inhibit: the light lit before stays (FCOM p.1594)")
lift_off(rt, ias, frames)
rt:set(G .. "radio_altimeter_height_ft_pilot", 450)
frames(1)
T.equal(rt:get(MC), 1, "400 ft: master CAUTION on (the waiting caution announced)")
T.check(rt:get(BEEP) == 1 or rt:get(BEEP) == true, "and the beeper for the waiting caution")
T.done()
