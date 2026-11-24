-- Run from the repository root with LuaJIT: luajit tests/fms/to_ref_alt_test.lua
-- The takeoff's reference altitude (2026-11-24, review FMC-8; notes/
-- ATA-34-61-FMC.md §179): the barometric altitude the FMC records as the
-- airplane accelerates through 100 kt on the ground (FCOM p.667 (4.20.9)),
-- above which THR REDUCTION's, ACCEL HT's and E/O ACCEL HT's heights count
-- (FCOM p.1318-1319 (11.40.42-43): the runway elevation added); none
-- before (an air start) or on the ground below 100 kt: the origin's
-- elevation. Before, always the origin airport's elevation from the
-- navigation data, off by the altimeter setting's error and the runway's
-- height on the airport (KDEN RW26 -140 ft).
local T = dofile("tests/lib/check.lua")("to_ref_alt")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["laminar/B747/options/cdu_sim_values"] = "number"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
types["laminar/B747/engines/ref_thr_limit_mode"] = "string"
types["laminar/B747/fms/thrlim/eicas"] = "string"
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
rt:set("sim/weather/temperature_ambient_c", 15)
rt:set("laminar/B747/irs/mode", 0, 2)
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local ns = fms.ns
local ALT, IAS = "sim/cockpit2/gauges/indicators/altitude_ft_pilot", "laminar/B747/gauges/indicators/airspeed_kts_pilot"
local LIM = "laminar/B747/engines/ref_thr_limit_mode"

-- the runway 500 ft on the altimeter (no route: the origin's elevation 0)
rt:set(ALT, 500)
rt:set(IAS, 0)
frames(0.2)
T.equal(ns.B747_fms_to_ref_alt(), 0, "on the ground before 100 kt: the origin's elevation (none: 0)")
rt:set(IAS, 99)
frames(0.2)
T.equal(ns.B747_fms_to_ref_alt(), 0, "99 kt: not yet")
rt:set(IAS, 101)
frames(0.2)
T.equal(ns.B747_fms_to_ref_alt(), 500, "through 100 kt: the altimeter's 500 ft recorded (FCOM p.667)")
rt:set(ALT, 510)
frames(0.2)
T.equal(ns.B747_fms_to_ref_alt(), 500, "the record kept as the altitude moves")
-- THR REDUCTION 1000 ft (FCOM p.1319: above the runway) with VNAV; the
-- takeoff's flaps 10 set on the ground (2026-11-24, review FMC-7 (c): flaps
-- out of UP in the air are GA's, from TO too)
ns.fmsModules["data"].thrred = "1000"
rt:set("sim/cockpit2/controls/flap_ratio", 3 / 6)
frames(0.2)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 600)
rt:set("laminar/B747/autopilot/vnav_state", 2)
rt:set(IAS, 170)
rt:set(ALT, 1400)
frames(0.2)
T.equal(rt:get(LIM), "TO", "1,400 ft: 900 ft above the record, TO still (before, 1,400 above the origin's 0: CLB)")
rt:set(ALT, 1510)
frames(0.2)
T.equal(rt:get(LIM), "CLB", "1,510 ft: 1,010 ft above the record, the armed CLB (FCOM p.667)")
-- the landing: below 100 kt on the ground the record goes
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set(IAS, 120)
frames(0.2)
T.equal(ns.B747_fms_to_ref_alt(), 500, "on the ground above 100 kt (the landing roll): the record kept")
rt:set(IAS, 60)
frames(0.2)
T.equal(ns.B747_fms_to_ref_alt(), 0, "below 100 kt: gone, the origin's elevation")
T.done()
