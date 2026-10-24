-- Run from the repository root with LuaJIT: luajit tests/nav/airdata_module_test.lua
-- The air data glue (B747.34.xt.airdata.lua, 5-1 step 1) in the navigation
-- sensors module (B747.34.xt.nav) as XTLua runs it
-- (tests/lib/xtlua.lua): X-Plane's pilot, copilot and standby air data, the
-- buses, X-Plane's ADC failures and the AIR DATA knobs in; each PFD's
-- airspeed, the sources and validity, OVERSPEED, IAS and ALT DISAGREE,
-- >SOURCE SEL ADC, the altitude alert and >AOA RIGHT out. The model is tested
-- in airdata_model_test.lua; this checks the wiring.
local T = dofile("tests/lib/check.lua")("airdata_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.nav.lua")
local G = "sim/cockpit2/gauges/indicators/"
local function frames(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end
local function air(ias_p, ias_c, alt_p, alt_c)
    rt:set(G .. "airspeed_kts_pilot", ias_p)
    rt:set(G .. "airspeed_kts_copilot", ias_c)
    rt:set(G .. "airspeed_kts_stby", ias_p)
    rt:set(G .. "altitude_ft_pilot", alt_p)
    rt:set(G .. "altitude_ft_copilot", alt_c)
    rt:set(G .. "altitude_ft_stby", alt_p)
end
for _, b in ipairs({"stby_main", "xfr_capt", "xfr_fo"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
for _, s in ipairs({"pilot", "copilot", "stby"}) do rt:set("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_" .. s, 29.92) end
rt:set("laminar/B747/flt_inst/air_data_src/fo/sel_dial_pos", 1)
air(250, 252, 10000, 10000)
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 10000)
rt:callout("flight_start")
local PFD_C, PFD_F = "laminar/B747/gauges/indicators/airspeed_kts_pilot", "laminar/B747/gauges/indicators/airspeed_kts_copilot"
local CAUT, ADV, WARN = "laminar/B747/CAS/caution_status", "laminar/B747/CAS/advisory_status", "laminar/B747/CAS/warning_status"
frames(1)
T.equal(rt:get(PFD_C), 250, "before the model starts (3 s): the captain's PFD from the pilot side")
T.equal(rt:get(PFD_F), 252, "and the first officer's from the copilot side")
frames(3)
T.equal(rt:get(PFD_C), 250, "the captain's PFD: ADC L (X-Plane's pilot side)")
T.equal(rt:get(PFD_F), 252, "the first officer's: ADC R (copilot)")
T.equal(rt:get("laminar/B747/airdata/src_capt"), 1, "the captain on L")
T.equal(rt:get("laminar/B747/airdata/src_fo"), 3, "the first officer on R")
T.equal(rt:get("laminar/B747/airdata/valid_capt"), 1, "valid")
T.equal(rt:get(ADV, 267), 0, "no >SOURCE SEL ADC")
-- each PFD's altitude and Mach (the custom acf's panel) from the selected ADC
air(250, 252, 10000, 10150)
rt:set(G .. "mach_pilot", 0.60)
rt:set(G .. "mach_copilot", 0.61)
frames(0.2)
T.near(rt:get("laminar/B747/airdata/alt_capt"), 10000, 0.5, "the captain's PFD altitude: ADC L")
T.near(rt:get("laminar/B747/airdata/alt_fo"), 10150, 0.5, "the first officer's: ADC R")
T.near(rt:get("laminar/B747/airdata/mach_capt"), 0.60, 1e-6, "the captain's Mach: ADC L")
-- the captain's knob to its second position: R
rt:set("laminar/B747/flt_inst/air_data_src/capt/sel_dial_pos", 1)
frames(0.2)
T.equal(rt:get(PFD_C), 252, "captain on R: R's speed on the captain's PFD")
T.near(rt:get("laminar/B747/airdata/alt_capt"), 10150, 0.5, "and R's altitude")
T.near(rt:get("laminar/B747/airdata/mach_capt"), 0.61, 1e-6, "and R's Mach")
T.equal(rt:get(ADV, 267), 1, "both on R: >SOURCE SEL ADC")
rt:set("laminar/B747/flt_inst/air_data_src/capt/sel_dial_pos", 0)
-- the bottom of the tape
air(10, 10, 100, 100)
frames(0.2)
T.equal(rt:get(PFD_C), 30, "on the ground: 30 kt (ATA34_1 p.126)")
-- IAS DISAGREE after five seconds
air(250, 258, 10000, 10000)
frames(4)
T.equal(rt:get(CAUT, 44), 0, "8 kt apart for 4 s: no IAS DISAGREE yet")
frames(1.5)
T.equal(rt:get(CAUT, 44), 1, "IAS DISAGREE (FCOM p.1198)")
air(250, 250, 10000, 10300)
frames(6)
T.equal(rt:get(CAUT, 44), 0, "agreeing: gone")
T.equal(rt:get(CAUT, 1), 1, "300 ft apart: ALT DISAGREE (FCOM p.1197)")
air(250, 250, 10000, 10000)
-- OVERSPEED: Vmo 365 kt, not the placards
air(366, 300, 10000, 10000)
frames(0.2)
T.equal(rt:get(WARN, 22), 1, "366 kt: OVERSPEED")
air(300, 300, 10000, 10000)
frames(0.2)
T.equal(rt:get(WARN, 22), 0, "300 kt: none")
-- the altitude alert: captured at 10,000 ft, departing by 400 ft
frames(2)
air(300, 300, 10400, 10400)
frames(0.2)
T.equal(rt:get(CAUT, 2), 1, ">ALTITUDE ALERT (FCOM p.1559)")
T.equal(rt:get("laminar/B747/airdata/alt_alert"), 1, "the amber box")
air(300, 300, 10100, 10100)
frames(0.2)
T.equal(rt:get(CAUT, 2), 0, "back within 300 ft: gone")
-- ADC L failed (X-Plane's ADC 1): the captain's air data invalid
rt:set("sim/operation/failures/rel_adc_comp", 6)
frames(0.2)
T.equal(rt:get("laminar/B747/airdata/valid", 0), 0, "ADC L invalid")
T.equal(rt:get("laminar/B747/airdata/valid_capt"), 0, "the captain's air data invalid (the PFD flags)")
rt:set("sim/operation/failures/rel_adc_comp", 0)
-- >AOA RIGHT: the right vane
rt:set("sim/operation/failures/rel_cop_AOA", 6)
frames(0.2)
T.equal(rt:get(ADV, 12), 1, "the copilot's AOA failed: >AOA RIGHT (NAV-07)")
rt:set("sim/operation/failures/rel_cop_AOA", 0)
rt:set("sim/operation/failures/rel_AOA", 6)
frames(0.2)
T.equal(rt:get(ADV, 12), 0, "the pilot's: not >AOA RIGHT")
T.done()
