-- Run from the repository root with LuaJIT: luajit tests/eec/eec_module_test.lua
-- The EEC module as XTLua runs it (tests/lib/xtlua.lua): the EEC model
-- through its glue (B747.42.xt.eec_thrust.lua) in B747.42.xt.EEC.lua. The
-- levers, air data, packs, anti-ice and rotor speeds in; the lever command
-- (TRA), the thrust control's target, the max line and the EEC messages
-- out, for P&W and GE. The model's numbers themselves are tested in
-- eec_model_test.lua; this checks the wiring.
local T = dofile("tests/lib/check.lua")("eec_module")
local xtlua = dofile("tests/lib/xtlua.lua")

math.randomseed(1)
local rt = xtlua.new()
local ns = rt:load("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.xt.EEC.lua").ns
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local ENG = "laminar/B747/engines/"
local USER = "sim/cockpit2/engine/actuators/throttle_ratio"

-- P&W at sea level, 15 °C, three packs operating, on the ground, the EEC MODE
-- switches at NORM
for i = 7, 10 do rt:set("laminar/B747/button_switch/position", i, 1) end
rt:set("laminar/B747/engines/type", 0)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel2/position/pressure_altitude", 0)
rt:set("sim/cockpit2/temperature/outside_air_LE_temp_degc", 15)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15)
rt:set("laminar/B747/air/packs_operating", 3)    -- the pack model (B747.55.xt.packs.lua)
-- the user's throttle moves the levers (manipulate_throttle_axis)
local LEVERS = {1.0, 0.48, 0.0, 0.96}
for i = 0, 3 do rt:set(USER, i, LEVERS[i + 1]) end
frames(3)
for i = 0, 3 do
    T.near(get("laminar/B747/engine/throttle", i), LEVERS[i + 1], 0.01, "P&W: lever " .. (i + 1) .. " follows the user's throttle")
end
T.near(get(ENG .. "display_EPR_max", 0), 1.51, 0.005, "P&W: max EPR line is the EEC's rating (go-around EPR, sea level, 15 °C)")
-- (the FMC's step 9g3) the reference: the FMC's mode's (TO: the takeoff
-- rating, the go-around table's), the A/T's target the same
T.near(get(ENG .. "display_EPR_ref", 0), 1.51, 0.005, "P&W: TO's reference 1.51 (B747.42.ref_thrust_model.lua)")
T.near(get("sim/cockpit2/engine/actuators/EPR_target_bug", 0), 1.51, 0.005, "the target bug the same")
T.near(get(ENG .. "TRA", 0), 1.51, 0.005, "P&W: full forward commands the max EPR")
T.near(get(ENG .. "TRA", 3), 1.51, 0.005, "P&W: 48° TLA commands the max EPR")
-- the idle end the EPR of no net thrust at the Mach (2026-10-31; before
-- 0.95 at any Mach): standing, 1.00
T.near(get(ENG .. "TRA", 1), 1.0 + (1.51 - 1.0) * 0.5, 0.01, "P&W: 24° TLA commands half way from the idle end")
T.near(get(ENG .. "TRA", 2), 1.0, 0.005, "P&W: idle lever commands the idle end (no net thrust standing: 1.00)")
rt:set("sim/flightmodel/misc/machno", 0.78)
frames(0.2)
-- (2026-11-05) at M.78 the EPR model's idle command, under X-Plane's idle
-- (B747_epr_model.idle_command; before, no net thrust's 0.669)
T.near(get(ENG .. "TRA", 2), 0.634, 0.002, "P&W: at M.78 the idle end 0.634 (under X-Plane's idle, the lever's travel from there up)")
rt:set("sim/flightmodel/misc/machno", 0)
frames(0.2)

-- packs off and engine anti-ice on engine 1
rt:set("laminar/B747/air/packs_operating", 0)
frames(0.2)
T.near(get(ENG .. "display_EPR_max", 0), 1.53, 0.005, "P&W: 3 packs off raise the max EPR by 0.02")
rt:set("laminar/B747/air/packs_operating", 3)    -- the pack model (B747.55.xt.packs.lua)

-- in the climb above 25,000 ft the lever reaches the climb rating at 35°
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/flightmodel2/position/pressure_altitude", 30000)
rt:set("sim/cockpit2/temperature/outside_air_LE_temp_degc", -20)
rt:set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", 280)
rt:set("laminar/B747/antiice/nacelle/valve_pos", 0, 1)
for i = 0, 3 do rt:set(USER, i, 0.7) end
frames(3)
T.near(get(ENG .. "display_EPR_max", 1), 1.622, 0.005, "P&W: max EPR at 30,000 ft, TAT -20: the maximum continuous (2026-11-02; before the climb's 1.57)")
T.near(get(ENG .. "display_EPR_max", 0), 1.582, 0.005, "P&W: engine 1's anti-ice lowers its max EPR")
T.near(get(ENG .. "TRA", 1), 1.622, 0.005, "P&W: 35° TLA commands the max EPR above 25,000 ft")
-- (step 9g3) CLB's reference the maximum climb table's; CLB 2 at 30,000 ft
-- still 4 % less thrust (the 109's washout to 35,000 ft)
rt:set(ENG .. "ref_thr_limit_mode", "CLB")
frames(0.2)
T.near(get(ENG .. "display_EPR_ref", 1), 1.57, 0.005, "P&W: CLB's reference 1.57 at 30,000 ft, TAT -20")
T.check(get(ENG .. "display_EPR_ref", 1) < get(ENG .. "display_EPR_max", 1) - 0.01, "P&W: CLB's reference under the max EPR, its digits white at CLB thrust (FCOM p.834; before, red)")
T.near(get("sim/cockpit2/engine/actuators/EPR_target_bug", 1), 1.57, 0.005, "its target bug the same")
rt:set(ENG .. "ref_thr_limit_mode", "CLB 2")
frames(0.2)
T.check(get(ENG .. "display_EPR_ref", 1) < 1.565 and get(ENG .. "display_EPR_ref", 1) > 1.53,
    string.format("CLB 2 at 30,000 ft: a little less, %.3f", get(ENG .. "display_EPR_ref", 1)))
-- the FMS's mode as a number (the other plugin's string writes do not
-- reach the EEC: s152, s141): 22 CLB 2, the EEC's text and reference from it
rt:set(ENG .. "ref_thr_limit_mode", "")
rt:set("laminar/B747/fms/thrlim/code", 22)
frames(0.2)
T.check(get(ENG .. "ref_thr_limit_mode") == "CLB 2" and get(ENG .. "display_EPR_ref", 1) < 1.565,
    "the number 22: CLB 2 for the EEC, its reference " .. get(ENG .. "display_EPR_ref", 1))
-- (2026-11-05 review) CRZ, the number 30, for P&W, GE and RR: a reference
-- in range and no Lua error. A reviewer read P&W's and RR's cruise table
-- lookups (find_closest_weight/altitude) as raising one every frame; they
-- do not under XTLua: the table, a global, is a namespace whose pairs()
-- gives its "values" and "functions" tables first, the level the lookups
-- skip (tested with the real init.lua). Kept as the CRZ case no test had
for _, ty in ipairs({0, 1, 2}) do
    rt:set("laminar/B747/engines/type", ty)
    rt:set("laminar/B747/fms/thrlim/code", 30)
    frames(0.5)
    T.equal(get(ENG .. "ref_thr_limit_mode"), "CRZ", "type " .. ty .. ": the number 30, CRZ for the EEC")
    local ref = get(ENG .. "display_EPR_ref", 1)
    T.check(ref > 1.0 and ref <= 1.71, string.format("type %d at CRZ: a reference %.3f, no Lua error", ty, ref))
end
T.equal(ns.find_closest_weight(ns.P85M_epr_PW4062, 270), 260, "the cruise table (a namespace): the nearest weight, the lower on a tie: 260 t for 270")
T.equal(ns.find_closest_altitude(ns.P85M_epr_PW4062, 35), 35, "its nearest altitude: 35 kft")
T.equal(ns.find_closest_altitude(ns.P85M_epr_PW4062, 36), 35, "on a tie the lower one")
rt:set("laminar/B747/engines/type", 0)
rt:set("laminar/B747/fms/thrlim/code", 0)
rt:set(ENG .. "ref_thr_limit_mode", "")
-- (step 9g4) the target cursor magenta (ATA34_2 p.652): with the A/T arm
-- switch off; armed, in the climb with VNAV; not without VNAV. In VNAV's
-- idle descent with anti-ice: magenta at idle, the target bug the
-- reference still; no 0.90 in a descent's THR REF (ATHR-17)
local MAG, BUG = ENG .. "display_ref_line_magenta", "sim/cockpit2/engine/actuators/EPR_target_bug"
rt:set("laminar/B747/antiice/nacelle/valve_pos", 0, 0)
rt:set("laminar/B747/autothrottle/armed", 0)
frames(0.2)
T.equal(get(MAG), 1, "the A/T arm switch off: magenta")
rt:set("laminar/B747/autothrottle/armed", 1)
frames(0.2)
T.equal(get(MAG), 0, "armed, no VNAV: green")
rt:set("laminar/B747/autopilot/vnav_state", 2)
rt:set("laminar/B747/fms/vnav/phase", 1)
frames(0.2)
T.equal(get(MAG), 1, "VNAV in the climb: magenta")
rt:set("laminar/B747/fms/vnav/phase", 3)
rt:set("laminar/B747/fms/vnav/at", 2)
frames(0.2)
T.equal(get(MAG), 0, "VNAV's idle descent without anti-ice: green")
rt:set("laminar/B747/antiice/nacelle/valve_pos", 1, 1)
frames(0.2)
T.check(get(MAG) == 1 and get(ENG .. "display_EPR_ref", 1) <= 1.0001 and get(BUG, 1) > 1.4,
    string.format("with anti-ice: magenta at idle (standing 1.00) %.3f, the bug the reference %.3f", get(ENG .. "display_EPR_ref", 1), get(BUG, 1)))
rt:set("laminar/B747/antiice/nacelle/valve_pos", 1, 0)
rt:set("laminar/B747/autopilot/FMA/autothrottle_mode", 5)
rt:set("laminar/B747/autopilot/flightPhase", 3)
frames(0.2)
T.check(get(BUG, 1) > 1.4, string.format("THR REF in a descent: the bug the reference %.3f (before 0.90)", get(BUG, 1)))
rt:set("laminar/B747/autopilot/FMA/autothrottle_mode", 0)
rt:set("laminar/B747/autopilot/flightPhase", 0)
rt:set("laminar/B747/autopilot/vnav_state", 0)
rt:set("laminar/B747/fms/vnav/phase", 0)
rt:set("laminar/B747/fms/vnav/at", 0)
rt:set("laminar/B747/antiice/nacelle/valve_pos", 0, 0)

-- idle: X-Plane's one idle setting is approach idle while any engine selects
-- it (in the air: anti-ice, landing flaps), minimum idle otherwise (in the
-- air by pressure altitude, here 30,000 ft), 5 s after the conditions end
local IDLE = "sim/aircraft2/engine/high_idle_ratio"
local ADV = "laminar/B747/CAS/advisory_status"
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", -20)
frames(6)
T.near(get(IDLE), 4.1, 0.001, "idle: minimum idle in the air (30,000 ft)")
rt:set("sim/cockpit2/controls/flap_ratio", 5 / 6)          -- flaps 25
frames(0.5)
T.near(get(IDLE), 4.6, 0.001, "idle: approach idle with landing flaps")
rt:set("sim/cockpit2/controls/flap_ratio", 4 / 6)          -- flaps 20
frames(4.5)
T.near(get(IDLE), 4.6, 0.001, "idle: approach idle kept 5 s")
frames(1)
T.near(get(IDLE), 4.1, 0.001, "idle: minimum idle after 5 s")
rt:set("laminar/B747/antiice/nacelle/valve_pos", 2, 1)
frames(0.5)
T.near(get(IDLE), 4.6, 0.001, "idle: engine 3's anti-ice selects approach idle (X-Plane has one setting)")
rt:set("laminar/B747/antiice/nacelle/valve_pos", 2, 0)
for n = 0, 3 do T.equal(get(ADV, 309 + n), 0, "idle: no ENG " .. (n + 1) .. " LOW IDLE") end
T.equal(get(ADV, 223), 0, "idle: no >IDLE DISAGREE")
-- (2026-11-04) the idle faults (laminar/B747/engines/fail/idle_min,
-- idle_approach; notes/ATA-70-80.md §12): landing flaps, engine 2 stuck at
-- minimum idle: ENG 2 LOW IDLE (310)
rt:set(ENG .. "fail/idle_min", 1, 1)
rt:set("sim/cockpit2/controls/flap_ratio", 5 / 6)
frames(0.5)
T.equal(get(ADV, 310), 1, "idle_min 2, landing flaps: ENG 2 LOW IDLE")
T.equal(get(ADV, 309), 0, "no ENG 1 LOW IDLE")
rt:set(ENG .. "fail/idle_min", 1, 0)
rt:set("sim/cockpit2/controls/flap_ratio", 0)
frames(6)
rt:set(ENG .. "fail/idle_approach", 3, 1)
frames(0.5)
T.equal(get(ADV, 223), 1, "idle_approach 4, minimum idle selected: >IDLE DISAGREE")
rt:set(ENG .. "fail/idle_approach", 3, 0)
frames(0.5)
T.equal(get(ADV, 223), 0, "repaired: no >IDLE DISAGREE")
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15)
rt:set("sim/cockpit2/controls/flap_ratio", 0)
frames(6)
T.near(get(IDLE), 1.07, 0.001, "idle: minimum idle on the ground, 5 s after touchdown")

-- alternate mode: EEC MODE 2 to ALTN with the A/T on
local CAUTION = "laminar/B747/CAS/caution_status"
rt:set("sim/flightmodel2/position/pressure_altitude", 0)
rt:set("sim/cockpit2/temperature/outside_air_LE_temp_degc", 15)
for i = 0, 3 do rt:set(USER, i, 1.0) end
frames(3)
rt:set("laminar/B747/engines/autothrottle_active", 1)
rt:set("laminar/B747/engines/autothrottle_fail", 0)
frames(0.2)
T.equal(get(ADV, 314), 0, "ALTN: no ENG 2 EEC MODE in the normal mode")
T.equal(get("laminar/B747/engines/autothrottle_fail"), 0, "ALTN: the A/T is not touched in the normal mode")
rt:set("laminar/B747/button_switch/position", 8, 0)
frames(0.2)
T.equal(get(ADV, 314), 1, "ALTN: ENG 2 EEC MODE")
T.equal(get(ADV, 313), 0, "ALTN: no ENG 1 EEC MODE")
T.equal(get("laminar/B747/engines/autothrottle_fail"), 1, "ALTN: the A/T disconnects (its fail: the A/T model in the autopilot module takes it off, the FMC's step 9f1)")
T.equal(get(CAUTION, 76), 1, ">ENG 2 LIM PROT: P&W full forward in the alternate mode")
T.equal(get(CAUTION, 75), 0, "no >ENG 1 LIM PROT in the normal mode")
rt:set("laminar/B747/engines/autothrottle_fail", 0)       -- the crew re-arms the A/T
frames(0.2)
T.equal(get("laminar/B747/engines/autothrottle_fail"), 1, "ALTN: P&W A/T not usable while an EEC is in the alternate mode")
rt:set("laminar/B747/button_switch/position", 8, 1)
rt:set("laminar/B747/engines/autothrottle_fail", 0)
frames(0.2)
T.equal(get(ADV, 314), 0, "ALTN: back in the normal mode")
T.equal(get(CAUTION, 76), 0, "no LIM PROT in the normal mode")
T.equal(get("laminar/B747/engines/autothrottle_fail"), 0, "the A/T can be armed again with all EECs normal")

-- overspeed protection: the thrust control aims at the command until a rotor
-- nears its red line; >ENG n RPM LIM from the EEC. N2 is set for one frame
-- (the display code gives the EEC its N2 again every frame)
local RPM_LIM = 134
for i = 0, 3 do
    T.near(ns.B747_eec_target(i), get(ENG .. "TRA", i), 1e-9, "overspeed: target " .. (i + 1) .. " is the command far from the limits")
    T.equal(get(ADV, RPM_LIM + i), 0, "no >ENG " .. (i + 1) .. " RPM LIM")
end
ns.B747_eec_set_n2(0, 111.4)
rt:frame(1 / 30)
T.check(ns.B747_eec_target(0) < get(ENG .. "TRA", 0) - 0.005, "overspeed: P&W N2 at its red line holds the target below the command")
T.equal(get(ADV, RPM_LIM), 1, ">ENG 1 RPM LIM: P&W from the EEC")
T.equal(get(ADV, RPM_LIM + 1), 0, "no >ENG 2 RPM LIM")
rt:frame(1 / 30)
T.equal(get(ADV, RPM_LIM), 0, "RPM LIM goes with N2 back below its limit")

-- (2026-11-03) the display's N1 at high power from the EPR (the FCOM's Alt
-- Mode %N1, B747_epr_model.n1): at the go-around rating's thrust on a 30 °C
-- day's takeoff run (M.25) and at max EPR at 10,600 ft (the full run's s10)
-- N1 and N2 stay under the N2 limit's band (111.4 - 0.5 - 2), no RPM LIM.
-- Before, the regression on thrust / density ratio: N1 112 and 109, N2 121
-- and 116, the EEC held the thrust with RPM LIM
local P = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.epr_model.lua")
local SCALARS = {"sim/flightmodel/failures/onground_any", "laminar/B747/gear/air_ground/pri_gnd",
    "sim/flightmodel2/position/pressure_altitude",
    "sim/cockpit2/gauges/indicators/altitude_ft_pilot", "sim/weather/aircraft/barometer_current_pas",
    "sim/flightmodel/misc/machno", "sim/cockpit2/gauges/indicators/true_airspeed_kts_pilot",
    "sim/cockpit2/temperature/outside_air_temp_degc", "sim/cockpit2/temperature/outside_air_LE_temp_degc"}
local ARRAYS = {"sim/flightmodel/engine/ENGN_running", "sim/cockpit2/engine/indicators/engine_speed_rpm",
    "sim/cockpit2/engine/indicators/thrust_dry_n"}
local saved = {}
for _, n in ipairs(SCALARS) do saved[n] = get(n) end
for _, n in ipairs(ARRAYS) do saved[n] = {} for i = 0, 3 do saved[n][i] = get(n, i) end end
local function high_power(alt_ft, mach, oat, tat, epr, what)
    local d = (1 - 6.87559e-6 * alt_ft) ^ 5.25588
    rt:set("sim/flightmodel/failures/onground_any", alt_ft == 0 and 1 or 0)
    rt:set("laminar/B747/gear/air_ground/pri_gnd", alt_ft == 0 and 1 or 0)
    rt:set("sim/flightmodel2/position/pressure_altitude", alt_ft)
    rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", alt_ft)
    rt:set("sim/weather/aircraft/barometer_current_pas", 101325 * d)
    rt:set("sim/flightmodel/misc/machno", mach)
    rt:set("sim/cockpit2/gauges/indicators/true_airspeed_kts_pilot", mach * math.sqrt(1.4 * 287 * (oat + 273.15)) * 1.943844)
    rt:set("sim/cockpit2/temperature/outside_air_temp_degc", oat)
    rt:set("sim/cockpit2/temperature/outside_air_LE_temp_degc", tat)
    for i = 0, 3 do
        rt:set("sim/flightmodel/engine/ENGN_running", i, 1)
        rt:set("sim/cockpit2/engine/indicators/engine_speed_rpm", i, 3500)
        rt:set("sim/cockpit2/engine/indicators/thrust_dry_n", i, P.thrust(epr, d, mach) * 1000)
    end
    frames(1)
    local n1, n2 = get(ENG .. "display_N1", 0), get(ENG .. "display_N2", 0)
    T.check(n1 > 101 and n1 < 106, string.format("%s: N1 %.1f (the EPR's)", what, n1))
    T.check(n2 < 108.9, string.format("%s: N2 %.1f under the N2 limit's band", what, n2))
    for i = 0, 3 do T.equal(get(ADV, RPM_LIM + i), 0, what .. ": no >ENG " .. (i + 1) .. " RPM LIM") end
end
high_power(0, 0.25, 30, 34, 1.51, "the takeoff run at EPR 1.51, 30 °C")
high_power(10600, 0.45, 18, 28, 1.573, "max EPR at 10,600 ft, M.45, TAT 28 °C")
for _, n in ipairs(SCALARS) do rt:set(n, saved[n]) end
for _, n in ipairs(ARRAYS) do for i = 0, 3 do rt:set(n, i, saved[n][i]) end end
frames(1)

-- the thrust control drives X-Plane's throttle (ecc_spd): engines running,
-- forward thrust, in the air; the stand-in engine gives no thrust, so the
-- EPR stays low and full forward opens the throttle fully, idle closes it
local THRO = "sim/flightmodel/engine/ENGN_thro_use"
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
-- (2026-11-10) air data in the air (10,000 ft, M.45): the thrust control's
-- slope comes from the EPR model at the pressure ratio and Mach (with none
-- the pressure ratio is held at 0.1); the fast descent below sets its own
rt:set("sim/weather/aircraft/barometer_current_pas", 101325 * (1 - 6.87559e-6 * 10000) ^ 5.25588)
rt:set("sim/flightmodel/misc/machno", 0.45)
for i = 0, 3 do
    rt:set("sim/flightmodel/engine/ENGN_running", i, 1)
    rt:set("sim/cockpit2/engine/actuators/prop_mode", i, 1)
end
for i = 0, 3 do rt:set(USER, i, 1.0) end
-- (2026-11-10: the gains for the plant, slower than before: 6 s, was 3)
frames(6)
T.near(get(THRO, 0), 1, 1e-6, "thrust control: full forward, EPR short of the command: full throttle")
T.equal(get("sim/operation/override/override_throttles"), 1, "thrust control: X-Plane's throttles are overridden")
for i = 0, 3 do rt:set(USER, i, 0.0) end
frames(3)                                                   -- the levers come back
T.equal(get(THRO, 0), 0, "thrust control: idle lever: throttle 0")
rt:set("sim/cockpit2/engine/actuators/prop_mode", 1, 3)       -- engine 2 in reverse
frames(0.2)
T.equal(get(THRO, 1), 0, "thrust control: reverser not deployed: no thrust")
rt:set("sim/cockpit2/engine/actuators/prop_mode", 1, 1)

-- (2026-11-10) the open-loop test (laminar/B747/engines/eec/test_open and
-- test_step_pm; tests/flight/measure/eec_steps_*.json): the throttle held at
-- its value when the test began plus the step (per mille), whatever the
-- lever; after it the control takes the throttle up from there
local TEST_OPEN, TEST_STEP = "laminar/B747/engines/eec/test_open", "laminar/B747/engines/eec/test_step_pm"
rt:set(TEST_OPEN, 1)
rt:set(TEST_STEP, 300)
frames(0.5)
T.near(get(THRO, 0), 0.3, 1e-9, "open-loop test: the throttle when it began (0) plus 300 per mille, the lever at idle")
for i = 0, 3 do rt:set(USER, i, 1.0) end
frames(3)
T.near(get(THRO, 2), 0.3, 1e-9, "open-loop test: the lever full forward does not move it")
rt:set(TEST_STEP, -100)
frames(0.2)
T.equal(get(THRO, 0), 0, "open-loop test: not under 0")
rt:set(TEST_STEP, 0)
rt:set(TEST_OPEN, 0)
rt:frame(1 / 30)
T.check(get(THRO, 0) < 0.1, string.format("after the test: the control starts again from X-Plane's throttle (%.3f, not 1 at once)", get(THRO, 0)))
frames(6)
T.near(get(THRO, 0), 1, 1e-6, "after the test: full forward, the EPR short: full throttle again")
for i = 0, 3 do rt:set(USER, i, 0.0) end
frames(3)
T.equal(get(THRO, 0), 0, "after the test: idle lever: throttle 0")

-- (2026-11-10) the takeoff roll (B747.42.eec_model.lua, M.RAMP_W): on the
-- PSEU's ground above 30 kt the control also learns the throttle's rate, so
-- with the same small steady error (the EPR 0.01 under the command) the
-- throttle rises faster than at rest
do
    local P = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.epr_model.lua")
    rt:set("sim/flightmodel/failures/onground_any", 1)
    rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
    rt:set("sim/weather/aircraft/barometer_current_pas", 101325)
    rt:set("sim/flightmodel/misc/machno", 0.06)
    -- running engines (on the ground the fuel is cut below a shown N2 of 60 %;
    -- the shown N2 follows X-Plane's slowly)
    for i = 0, 3 do rt:set("sim/flightmodel/engine/ENGN_N2_", i, 90) end
    frames(90)
    -- from idle to a lever part forward, the stand-in engine's thrust held
    -- so that the EPR stays about 0.014 under the command; the control
    -- learns once its reference has settled within 0.002 (about 8 s)
    local function run(gs)
        for i = 0, 3 do rt:set(USER, i, 0.0) end
        rt:set("sim/cockpit2/engine/indicators/thrust_dry_n", 0, 0)
        frames(1)
        rt:set("sim/flightmodel/position/groundspeed", gs)
        for i = 0, 3 do rt:set(USER, i, 0.6) end
        frames(1)
        local command = get(ENG .. "TRA", 0)
        rt:set("sim/cockpit2/engine/indicators/thrust_dry_n", 0, P.thrust(command - 0.01, 1.0, 0.06) * 1000)
        frames(20)
        return get(THRO, 0), command
    end
    run(0)                                  -- the first one settles the display's filters
    local still, command = run(0)
    local rolling = run(20)                 -- 39 kt
    T.check(command > 1.1 and still > 0 and still < 1, string.format("the roll: at rest the PI alone (throttle %.3f, command EPR %.3f)", still, command))
    T.check(rolling > still + 0.01, string.format("the roll: above 30 kt on the ground the throttle rises faster (%.3f, at rest %.3f)", rolling, still))
    rt:set("sim/flightmodel/position/groundspeed", 0)
    for i = 0, 3 do rt:set(USER, i, 0.0) end
    rt:set("sim/cockpit2/engine/indicators/thrust_dry_n", 0, 0)
    rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
    rt:set("sim/flightmodel/failures/onground_any", 0)
    rt:set("sim/weather/aircraft/barometer_current_pas", 101325 * (1 - 6.87559e-6 * 10000) ^ 5.25588)
    rt:set("sim/flightmodel/misc/machno", 0.45)
    frames(3)
end

-- (2026-11-05) a fast descent at X-Plane's idle (M.66, 12,600 ft; its net
-- thrust -3.3 kN an engine, under no net thrust): with the lever a hair
-- above idle (the A/T's HOLD at 0.0013) the throttle stays closed, the EPR
-- shown under that of no net thrust. A lever a little further, its command
-- between X-Plane's idle and no net thrust, opens the throttle: the EEC can
-- set the thrust in between. Before, the shown EPR stopped at no net
-- thrust's: the lever at 0.0013 had the throttle wind up to 0.42, 2 kN an
-- engine over idle (s148, 2026-11-03), and nothing in between could be set
local d126 = (1 - 6.87559e-6 * 12600) ^ 5.25588
rt:set("sim/flightmodel2/position/pressure_altitude", 12600)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 12600)
rt:set("sim/weather/aircraft/barometer_current_pas", 101325 * d126)
rt:set("sim/flightmodel/misc/machno", 0.66)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", -10)
rt:set("sim/cockpit2/temperature/outside_air_LE_temp_degc", 13)
for i = 0, 3 do
    rt:set("sim/cockpit2/engine/indicators/thrust_dry_n", i, -3300)
    rt:set("sim/cockpit2/engine/indicators/engine_speed_rpm", i, 3500)   -- running: the display's N1 about 39 %
end
-- the A/T's servo brings the levers back to 0.0013 from above and lets go
-- (HOLD; the user's throttle does not move them under 0.01)
local LEVER, AT_CMD, AT_SERVO = "laminar/B747/engine/throttle", "laminar/B747/autothrottle/lever_cmd", "laminar/B747/autothrottle/servo"
rt:set(AT_CMD, 0.05)
rt:set(AT_SERVO, 1)
frames(2)
rt:set(AT_CMD, 0.0013)
frames(3)
rt:set(AT_SERVO, 0)
frames(5)
T.near(get(LEVER, 0), 0.0013, 1e-4, "fast descent: the A/T's HOLD left the lever at 0.0013")
local epr_idle = get(ENG .. "display_EPR", 0)
T.check(epr_idle < P.zero(0.66) - 0.004, string.format("fast descent at X-Plane's idle: EPR %.4f under no net thrust's %.4f",
    epr_idle, P.zero(0.66)))
T.equal(get(THRO, 0), 0, "fast descent: the lever at 0.0013 keeps the throttle closed (X-Plane's idle)")
-- the servo's lever a little further, its command between X-Plane's idle
-- and no net thrust
local lever = 0.0013
rt:set(AT_SERVO, 1)
while ns.B747_eec_command(0) < epr_idle + 0.002 and lever < 0.3 do
    lever = lever + 0.002
    rt:set(AT_CMD, lever)
    frames(0.5)
end
local cmd = ns.B747_eec_command(0)
T.check(cmd > epr_idle and cmd < P.zero(0.66), string.format("fast descent: the lever at %.4f commands %.4f, between X-Plane's idle and no net thrust",
    get(LEVER, 0), cmd))
frames(5)
T.check(get(THRO, 0) > 0.03, string.format("fast descent: that command opens the throttle (%.3f)", get(THRO, 0)))
rt:set(AT_CMD, 0)
frames(3)
rt:set(AT_SERVO, 0)
for i = 0, 3 do
    rt:set("sim/cockpit2/engine/indicators/thrust_dry_n", i, saved["sim/cockpit2/engine/indicators/thrust_dry_n"][i])
    rt:set("sim/cockpit2/engine/indicators/engine_speed_rpm", i, saved["sim/cockpit2/engine/indicators/engine_speed_rpm"][i])
end
for _, n in ipairs({"sim/flightmodel2/position/pressure_altitude", "sim/cockpit2/gauges/indicators/altitude_ft_pilot",
        "sim/weather/aircraft/barometer_current_pas", "sim/flightmodel/misc/machno",
        "sim/cockpit2/temperature/outside_air_temp_degc", "sim/cockpit2/temperature/outside_air_LE_temp_degc"}) do
    rt:set(n, saved[n])
end
frames(1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)

-- GE at sea level, 15 °C
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"CF6-80C2B1F"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel2/position/pressure_altitude", 0)
rt:set("sim/cockpit2/temperature/outside_air_LE_temp_degc", 15)
rt:set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", 0)
for i = 0, 3 do rt:set(USER, i, 1.0) end
frames(3)
T.near(get(ENG .. "display_N1_max", 0), 103.8, 0.05, "GE: max N1 line is the EEC's rating (go-around N1, sea level, 15 °C)")
T.near(get(ENG .. "TRA", 0), 103.8, 0.05, "GE: full forward commands the max N1")
T.near(ns.B747_eec_target(0), get(ENG .. "TRA", 0), 1e-9, "GE: the target is the command far from the limits")
ns.B747_eec_set_n2(2, 112.5)
rt:frame(1 / 30)
T.check(ns.B747_eec_target(2) < get(ENG .. "TRA", 2) - 0.2, "overspeed: GE N2 at its red line holds the target below the command")
T.equal(get(ADV, RPM_LIM + 2), 1, ">ENG 3 RPM LIM: GE from the EEC")
rt:frame(1 / 30)
T.equal(get(ADV, RPM_LIM + 2), 0, "GE: RPM LIM goes with N2 back below its limit")

-- (ENG-31) GE in reverse: X-Plane's maximum reverse throttle 1, the
-- reverse throttle the ECU's share of the maximum rated thrust (0.9 at full
-- reverse, half at half), none at reverse idle or with the reverser moving
local REVL, DEPLOY = "laminar/B747/engine/throttle_reversor", "sim/flightmodel2/engines/thrust_reverser_deploy_ratio"
local REVMAX = "sim/aircraft/engine/acf_throtmax_REV"
for i = 0, 3 do
    rt:set("sim/flightmodel/engine/ENGN_running", i, 1)
    rt:set("sim/cockpit2/engine/actuators/prop_mode", i, 1)
end
rt:set("sim/cockpit2/engine/actuators/prop_mode", 1, 3)       -- engine 2 in reverse
rt:set(DEPLOY, 1, 1)
rt:set(REVL, 1, -1)                                             -- full reverse
frames(3)
T.near(get(REVMAX), 1.0, 1e-6, "GE: X-Plane's maximum reverse throttle 1")
T.near(get(THRO, 1), 0.9, 1e-6, "GE: full reverse: 90 % of the maximum rated thrust (ATA70_80 p.208)")
rt:set(REVL, 1, -0.5)
frames(0.2)
T.near(get(THRO, 1), 0.45, 1e-6, "GE: half the reverse lever: half of it (a direct function of TLA)")
rt:set(REVL, 1, 0)                                              -- reverse idle
frames(1)
T.equal(get(THRO, 1), 0, "GE: reverse idle: throttle 0")
rt:set(REVL, 1, -1)
rt:set(DEPLOY, 1, 0.5)                                          -- the cowls moving
frames(0.2)
T.equal(get(THRO, 1), 0, "GE: the reverser in transit: idle (p.208)")
rt:set(DEPLOY, 1, 1)
-- P&W: the lever as before, X-Plane's maximum 0.8 (the custom acf's)
rt:set("laminar/B747/engines/type", 0)
rt:set(REVL, 1, -0.6)
frames(0.5)
T.near(get(REVMAX), 0.8, 1e-6, "P&W: X-Plane's maximum reverse throttle back to the acf's 0.8")
T.near(get(THRO, 1), 0.6, 1e-6, "P&W: the reverse throttle the lever's (no sources)")
rt:set("laminar/B747/engines/type", 1)
rt:set(REVL, 1, 0)
rt:set(DEPLOY, 1, 0)
rt:set("sim/cockpit2/engine/actuators/prop_mode", 1, 1)
for i = 0, 3 do rt:set("sim/flightmodel/engine/ENGN_running", i, 0) end
frames(0.2)

-- the engine type strings: CF6-80C2-B1F1 is not taken for the B1F (ENG-30)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"CF6-80C2-B1F1"}}')
frames(0.2)
T.equal(ns.engine_max_thrust_n, 276000, "CF6-80C2-B1F1: its own max thrust (it used to match B1F first)")
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"CF6-80C2-B1F"}}')
frames(0.2)
T.equal(ns.engine_max_thrust_n, 258000, "CF6-80C2-B1F: 258,000 N")

-- RR: no source, its RPM LIM stays with B747.40.xt.engines.lua
rt:set("laminar/B747/engines/type", 2)
rt:set(ADV, RPM_LIM, 1)
ns.B747_eec_set_n2(0, 50)
rt:frame(1 / 30)
T.equal(get(ADV, RPM_LIM), 1, "RR: the EEC leaves RPM LIM alone")

-- (the FMC's step 9f2) the A/T's servo excited: the levers to its command
-- at 10 degrees a second (5 s the travel); the hand moving one: it follows
-- the hand, a second after it stops back to the command; the servo off:
-- the levers stay
local LEV = "laminar/B747/engine/throttle"
for i = 0, 3 do rt:set(USER, i, 0.2) end
frames(2)
local l0 = get(LEV, 0)
rt:set("laminar/B747/autothrottle/lever_cmd", l0 + 0.4)
rt:set("laminar/B747/autothrottle/servo", 1)
frames(1)
T.near(get(LEV, 0) - l0, 0.2, 0.03, "the servo: 0.2 of the lever in a second (10 degrees)")
frames(2)
T.near(get(LEV, 0), l0 + 0.4, 0.01, "at the command")
rt:set(USER, 1, 0.9)
frames(0.5)
T.check(get(LEV, 1) > l0 + 0.4 + 0.1, "the hand on lever 2: it follows the hand")
T.near(get(LEV, 0), l0 + 0.4, 0.01, "lever 1 stays at the command")
frames(3)
T.near(get(LEV, 1), l0 + 0.4, 0.01, "the hand still a second: back to the command")
rt:set("laminar/B747/autothrottle/servo", 0)
frames(1)
T.near(get(LEV, 0), l0 + 0.4, 0.01, "the servo off: the levers stay (no hand)")

-- (2026-11-04) the failures (laminar/B747/engines/fail/*; notes/ATA-70-80.md
-- §10): EEC 2 reverts by itself: ENG 2 EEC MODE (advisory 314), the ALTN
-- light's dataref; EEC faults on the ground: >ENG n CONTROL (110-113), three
-- of them >ENG CONTROLS (323)
local ADV = "laminar/B747/CAS/advisory_status"
for i = 0, 3 do rt:set("laminar/B747/engines/display_N2", i, 70) end
rt:set(ENG .. "fail/eec_altn", 1, 1)
frames(0.5)
T.equal(get(ADV, 314), 1, "EEC 2 reverted by itself: ENG 2 EEC MODE")
T.equal(get(ENG .. "eec/altn_light", 1), 1, "EEC 2 reverted: the ALTN light's dataref")
T.equal(get(ENG .. "eec/altn_light", 0), 0, "EEC 1 normal: no ALTN light")
T.equal(get(ADV, 111), 1, "EEC 2 reverted on the ground: >ENG 2 CONTROL")
rt:set(ENG .. "fail/eec_fault", 0, 1)
rt:set(ENG .. "fail/eec_fault", 2, 1)
frames(0.5)
T.equal(get(ADV, 110) + get(ADV, 112), 2, "EEC 1, 3 faults: >ENG 1, 3 CONTROL")
T.equal(get(ADV, 323), 1, "three EECs degraded: >ENG CONTROLS")
rt:set(ENG .. "fail/eec_altn", 1, 0)
rt:set(ENG .. "fail/eec_fault", 0, 0)
rt:set(ENG .. "fail/eec_fault", 2, 0)
frames(0.5)
T.equal(get(ADV, 314) + get(ADV, 111) + get(ADV, 323), 0, "repaired: no messages")
T.equal(get(ENG .. "eec/altn_light", 1), 0, "repaired: no ALTN light")

-- (2026-11-07) the fuel per thrust above FL370 (B747.42.xt.sfc_corr.lua,
-- 補正, notes/AERO.md §3.18): X-Plane's four jet SFC figures (kg/(N s)),
-- the acf's own (read once, the first frame they are there) times the
-- altitude's factor (B747.42.sfc_corr_model.lua), the P&W only
local SC = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.sfc_corr_model.lua")
local SFC = "sim/aircraft/overflow/jet_SFC_"
local KGNS = 1 / 3600 / 9.80665        -- lb/lbf/h to kg/(N s): 2.8325e-5
local ACF = {takeoff = 0.300, climb = 0.440, locrz = 0.470, hicrz = 0.535}
local function sfc(k) return get(SFC .. k) end
rt:set("laminar/B747/engines/type", 0)
rt:set("sim/flightmodel2/position/pressure_altitude", 39000)
for k, v in pairs(ACF) do rt:set(SFC .. k, v * KGNS) end
frames(0.2)
for k, v in pairs(ACF) do
    T.near(sfc(k), v * KGNS * 1.018, 1e-12, "P&W at FL390: " .. k .. " the acf's +1.8 %")
end
frames(1)
T.near(sfc("hicrz"), ACF.hicrz * KGNS * 1.018, 1e-12, "the frames after: the same, not compounded")
rt:set("sim/flightmodel2/position/pressure_altitude", 35000)
frames(0.2)
T.near(sfc("hicrz"), ACF.hicrz * KGNS, 1e-12, "FL350: the acf's own")
rt:set("sim/flightmodel2/position/pressure_altitude", 42000)
frames(0.2)
T.near(sfc("climb"), ACF.climb * KGNS * SC.factor(42000), 1e-12, "FL420: between FL410's and FL430's")
-- GE: the acf's own (the factor is the PW4056's)
rt:set("laminar/B747/engines/type", 1)
frames(0.2)
T.near(sfc("hicrz"), ACF.hicrz * KGNS, 1e-12, "GE at FL420: the acf's own")
rt:set("laminar/B747/engines/type", 0)
frames(0.2)
T.near(sfc("hicrz"), ACF.hicrz * KGNS * SC.factor(42000), 1e-12, "P&W again: corrected")
-- sfc_corr_off: the acf's own back once, then left alone (an SFC sweep's
-- writes stay)
rt:set("laminar/B747/debug/sfc_corr_off", 1)
frames(0.2)
T.near(sfc("hicrz"), ACF.hicrz * KGNS, 1e-12, "sfc_corr_off 1: the acf's own back")
rt:set(SFC .. "hicrz", 0.6 * KGNS)
frames(0.5)
T.near(sfc("hicrz"), 0.6 * KGNS, 1e-12, "sfc_corr_off 1: another writer's figure stays")
rt:set(SFC .. "hicrz", ACF.hicrz * KGNS)
rt:set("laminar/B747/debug/sfc_corr_off", 0)
frames(0.2)
T.near(sfc("hicrz"), ACF.hicrz * KGNS * SC.factor(42000), 1e-12, "sfc_corr_off 0: corrected again from the acf's own")
rt:set("sim/flightmodel2/position/pressure_altitude", 0)

-- (2026-11-10, ENG-33) the EGT shown from the engine's state (B747.42.
-- egt_model.lua through B747.42.xt.egt.lua): the P&W's display_EGT from the
-- EPR shown, the GE's display_GE_EGT from the N1 shown, the RB211's
-- X-Plane's EGT x 785/960 through egt_thermal_profile as before. X-Plane's
-- EGT (its spikes) no longer reaches the P&W's and the GE's. Before, the
-- P&W's was X-Plane's x 654/960: about 250 °C in the cruise
local G = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.egt_model.lua")
local XEGT, BURN, XN2 = "sim/flightmodel/engine/ENGN_EGT_c", "sim/flightmodel2/engines/engine_is_burning_fuel", "sim/flightmodel/engine/ENGN_N2_"
local STARTER = "sim/flightmodel2/engines/starter_is_running"
local function cruise(tat)
    local d = (1 - 6.87559e-6 * 35000) ^ 5.25588
    rt:set("sim/flightmodel/failures/onground_any", 0)
    rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
    rt:set("sim/flightmodel2/position/pressure_altitude", 35000)
    rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 35000)
    rt:set("sim/weather/aircraft/barometer_current_pas", 101325 * d)
    rt:set("sim/flightmodel/misc/machno", 0.84)
    rt:set("sim/cockpit2/temperature/outside_air_temp_degc", tat - 35)
    rt:set("sim/cockpit2/temperature/outside_air_LE_temp_degc", tat)
    rt:set("sim/cockpit2/gauges/indicators/true_airspeed_kts_pilot", 0.84 * math.sqrt(1.4 * 287 * (tat - 35 + 273.15)) * 1.943844)
    for i = 0, 3 do
        rt:set("sim/flightmodel/engine/ENGN_running", i, 1)
        rt:set("sim/cockpit2/engine/actuators/prop_mode", i, 1)
        rt:set("sim/cockpit2/engine/indicators/engine_speed_rpm", i, 3500)
        rt:set("sim/cockpit2/engine/indicators/thrust_dry_n", i, P.thrust(1.38, d, 0.84) * 1000)
        rt:set(BURN, i, 1)
        rt:set(XN2, i, 90)
        rt:set(XEGT, i, 300)
    end
end
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 0)
cruise(-14)
frames(20)
T.near(get(ENG .. "display_EPR", 0), 1.38, 0.002, "EGT: the P&W in the cruise at the FCOM's EPR 1.38")
for i = 0, 3 do
    T.near(get(ENG .. "display_EGT", i), 462, 3, "EGT: P&W engine " .. (i + 1) .. " in the cruise, EPR 1.38, TAT -14: 462 °C (FCOM p.830; before about 250)")
end
rt:set(XEGT, 0, 1951)
frames(0.5)
T.near(get(ENG .. "display_EGT", 0), 462, 3, "EGT: X-Plane's EGT spiking to 1951 °C does not reach the P&W's")
rt:set(XEGT, 0, 300)
-- engine 1 shut down in the air: cooling with the 60 s lag toward the
-- windmilling engine's (57 °C at TAT -8, FCOM p.840: 49.5 at TAT -14)
rt:set(BURN, 0, 0)
rt:set(XN2, 0, 25)
frames(60)
local wm = G.windmill(-14)
T.near(get(ENG .. "display_EGT", 0), wm + (462 - wm) * math.exp(-1), 5,
    string.format("EGT: P&W engine 1 shut down in the air, a minute later (toward the windmill's %.1f)", wm))
T.near(get(ENG .. "display_EGT", 1), 462, 3, "EGT: the others running at 462")
rt:set(BURN, 0, 1)
rt:set(XN2, 0, 90)
-- a new flight: the EGT at its target at once (B747_egt_flight_start: 2 s)
for i = 0, 3 do rt:set(ENG .. "display_EGT", i, 0) end
rt:callout("flight_start")
rt:frame(1 / 30)
T.near(get(ENG .. "display_EGT", 0), 462, 3, "EGT: a new flight in the cruise: 462 °C from the first frame")
-- (2026-11-10) the failure window's EGT failures reach the model (engines/
-- fail/egt_high and fail/hot_start, B747.42.xt.egt.lua): EGT OVERTEMP on
-- engine 2 in the cruise adds theta x 3 K/s x the share by the N1 shown
-- (its corrected N1 near the FCOM figure's, the share near 1), about 155 °C
-- in a minute (less the 2 s lag), the others as they were; cleared, back.
-- HOT START on engine 3 lit below the idle's N2 (30 %): its target, 557 °C
-- at TAT -14
frames(3)
rt:set(ENG .. "fail/egt_high", 1, 1)
frames(60)
local egt2 = get(ENG .. "display_EGT", 1)
local th14 = G.theta(-14)
local share2 = G.excess_share("PW", get(ENG .. "display_N1", 1) / math.sqrt(th14))
local want2 = 462 + th14 * G.EGT_HIGH_RATE * (60 - G.TAU_UP) * share2
T.check(share2 > 0.8 and math.abs(egt2 - want2) < 8,
    string.format("EGT OVERTEMP on engine 2, a minute: %.1f °C (about %.1f, the share %.3f at the N1 shown %.1f)",
        egt2, want2, share2, get(ENG .. "display_N1", 1)))
T.near(get(ENG .. "display_EGT", 0), 462, 3, "EGT OVERTEMP on engine 2: engine 1 at 462")
rt:set(ENG .. "fail/egt_high", 1, 0)
frames(150)
T.near(get(ENG .. "display_EGT", 1), 462, 3, "EGT OVERTEMP cleared: engine 2 back at 462 in 150 s")
rt:set(ENG .. "fail/hot_start", 2, 1)
rt:set(XN2, 2, 30)
frames(15)
T.near(get(ENG .. "display_EGT", 2), G.hot_target("PW", -14), 3,
    string.format("HOT START on engine 3 starting (N2 30 %%): its target %.1f °C", G.hot_target("PW", -14)))
rt:set(ENG .. "fail/hot_start", 2, 0)
rt:set(XN2, 2, 90)
frames(20)
T.near(get(ENG .. "display_EGT", 2), 462, 3, "HOT START: engine 3 running again, 462")
-- GE in the same cruise (the CRZ reference: the N1 from the thrust): its
-- own dataref, from the N1 shown
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"CF6-80C2B1F"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 1)
rt:set("laminar/B747/fms/thrlim/code", 30)
frames(30)
local n1 = get(ENG .. "display_N1", 0)
T.check(n1 > 60 and n1 < 110, string.format("EGT: the GE's N1 shown in the cruise %.1f", n1))
-- (2026-11-10) the module's Mach stays the cruise's through the GE's frame
-- (take_off_N1_GE's own Mach is local now; before, it set the module's to
-- 0 every frame and the N1 shown in the air came from the corrected
-- thrust's polynomial at Mach 0)
T.check(ns.mach > 0.8, string.format("GE: the module's Mach after a frame %.3f (the cruise's, not 0)", ns.mach))
T.near(n1, ns.B747_ge_n1_of_thrust(get("sim/cockpit2/engine/indicators/thrust_dry_n", 0)), 0.06,
    string.format("GE: the N1 shown (%.1f) the corrected thrust's polynomial at the cruise's Mach", n1))
T.near(get(ENG .. "display_GE_EGT", 0), G.steady("GE", n1, -14), 2,
    string.format("EGT: the GE's display_GE_EGT the model's at the N1 shown (%.1f)", n1))
-- (2026-11-11 review) the GE's N1 for a thrust from the static pressure and
-- the Mach (as the P&W's EPR), not the captain's altimeter and TAS: those
-- off (a static and a pitot failure: 10,000 ft and 300 kt TAS) leave it.
-- Before, 10,000 ft took the pressure ratio from 0.235 to 0.688
do
    local F = get("sim/cockpit2/engine/indicators/thrust_dry_n", 0)
    local GN = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.ge_n1_model.lua")
    local d35 = (1 - 6.87559e-6 * 35000) ^ 5.25588
    local want = GN.n1(F, get("sim/weather/aircraft/barometer_current_pas") / 101325, 0.84, (-49 + 273.15) / 288.15)
    rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 10000)
    rt:set("sim/cockpit2/gauges/indicators/true_airspeed_kts_pilot", 300)
    frames(1)
    T.near(ns.B747_ge_n1_of_thrust(F), want, 0.05,
        string.format("GE: the captain's altimeter and TAS off: the N1 for the thrust %.1f (the static pressure's, δ %.3f, M.84)", want, d35))
    T.near(get(ENG .. "display_N1", 0), n1, 0.3, "GE: the N1 shown as before")
    rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 35000)
    rt:set("sim/cockpit2/gauges/indicators/true_airspeed_kts_pilot", 0.84 * math.sqrt(1.4 * 287 * (-49 + 273.15)) * 1.943844)
    frames(1)
end
-- (2026-11-11 review) an engine short of its target at full throttle raises
-- X-Plane's maximum thrust by 200 N a frame up to 1.1 times the rated
-- (258,000 N); a shut down one not at all. Before, without a top, and a shut
-- down engine at full throttle raised it for good
do
    local TMAX = "sim/aircraft/engine/acf_tmax"
    T.near(ns.B747_eec_boosted_max(258000, 258000), 258200, 1e-6, "the raise: 200 N a frame")
    T.near(ns.B747_eec_boosted_max(283700, 258000), 283800, 1e-6, "up to 1.1 times the rated (283,800 N)")
    T.near(ns.B747_eec_boosted_max(283800, 258000), 283800, 1e-6, "not past it")
    T.near(ns.B747_eec_boosted_max(300000, 258000), 300000, 1e-6, "one already above: not lowered here")
    rt:set("sim/flightmodel/engine/ENGN_running", 3, 0)
    rt:set("sim/flightmodel/engine/ENGN_thro_use", 3, 1)
    rt:set(ENG .. "display_N1", 3, 20)
    T.check(not ns.B747_eec_thrust_short(), "engine 4 shut down at full throttle: not short")
    rt:set("sim/flightmodel/engine/ENGN_running", 3, 1)
    frames(1)
end
rt:set(XEGT, 0, 1951)
frames(0.5)
T.near(get(ENG .. "display_GE_EGT", 0), G.steady("GE", get(ENG .. "display_N1", 0), -14), 3, "EGT: X-Plane's EGT spike does not reach the GE's")
rt:set("laminar/B747/fms/thrlim/code", 0)
rt:set(ENG .. "ref_thr_limit_mode", "")
-- RB211: X-Plane's EGT x 785/960 as before (egt_thermal_profile)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"RB211-524G"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 2)
for i = 0, 3 do
    rt:set(XEGT, i, 600)
    rt:set("sim/flightmodel/engine/ENGN_N1_", i, 90)
end
frames(20)
T.near(get(ENG .. "display_EGT", 0), 600 * 785 / 960, 1, "EGT: the RB211's X-Plane's EGT x 785/960 as before")
-- (ENG-19) a stopped engine's N2 on the ground held at 0 for every type
-- (B747_eec_hold_stopped_n2, every frame; before inside egt_thermal_profile)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
for _, ty in ipairs({0, 1, 2}) do
    rt:set("laminar/B747/engines/type", ty)
    rt:set(BURN, 1, 0)
    rt:set(STARTER, 1, 0)
    rt:set(XN2, 1, 15)
    rt:frame(1 / 30)
    T.equal(get(XN2, 1), 0, "ENG-19: type " .. ty .. ", engine 2 stopped on the ground: N2 held at 0")
    rt:set(STARTER, 1, 1)
    rt:set(XN2, 1, 15)
    rt:frame(1 / 30)
    T.equal(get(XN2, 1), 15, "ENG-19: type " .. ty .. ", the starter turning: N2 left")
    rt:set(STARTER, 1, 0)
end
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set(XN2, 1, 15)
rt:frame(1 / 30)
T.equal(get(XN2, 1), 15, "ENG-19: in the air it windmills: N2 left")
rt:set("laminar/B747/engines/type", 0)

T.done()
