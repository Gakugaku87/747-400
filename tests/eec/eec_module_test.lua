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
T.near(get(ENG .. "TRA", 0), 1.51, 0.005, "P&W: full forward commands the max EPR")
T.near(get(ENG .. "TRA", 3), 1.51, 0.005, "P&W: 48° TLA commands the max EPR")
T.near(get(ENG .. "TRA", 1), 0.95 + (1.51 - 0.95) * 0.5, 0.01, "P&W: 24° TLA commands half way from the idle end")
T.near(get(ENG .. "TRA", 2), 0.95, 0.005, "P&W: idle lever commands the idle end")

-- packs off and engine anti-ice on engine 1
rt:set("laminar/B747/air/packs_operating", 0)
frames(0.2)
T.near(get(ENG .. "display_EPR_max", 0), 1.53, 0.005, "P&W: 3 packs off raise the max EPR by 0.02")
rt:set("laminar/B747/air/packs_operating", 3)    -- the pack model (B747.55.xt.packs.lua)

-- in the climb above 25,000 ft the lever reaches the climb rating at 35°
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/flightmodel2/position/pressure_altitude", 30000)
rt:set("sim/cockpit2/temperature/outside_air_LE_temp_degc", -20)
rt:set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", 280)
rt:set("laminar/B747/antiice/nacelle/valve_pos", 0, 1)
for i = 0, 3 do rt:set(USER, i, 0.7) end
frames(3)
T.near(get(ENG .. "display_EPR_max", 1), 1.57, 0.005, "P&W: max climb EPR at 30,000 ft, TAT -20")
T.near(get(ENG .. "display_EPR_max", 0), 1.53, 0.005, "P&W: engine 1's anti-ice lowers its max EPR")
T.near(get(ENG .. "TRA", 1), 1.57, 0.005, "P&W: 35° TLA commands the climb rating above 25,000 ft")
rt:set("laminar/B747/antiice/nacelle/valve_pos", 0, 0)

-- idle: X-Plane's one idle setting is approach idle while any engine selects
-- it (in the air: anti-ice, landing flaps), minimum idle by the outside air
-- temperature otherwise, 5 s after the conditions end
local IDLE = "sim/aircraft2/engine/high_idle_ratio"
local ADV = "laminar/B747/CAS/advisory_status"
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", -20)
frames(6)
T.near(get(IDLE), 1.00 + 0.07 * 55 / 89.99, 0.001, "idle: minimum idle in the air (-20 °C)")
rt:set("sim/cockpit2/controls/flap_ratio", 5 / 6)          -- flaps 25
frames(0.5)
T.near(get(IDLE), 2.625, 0.001, "idle: approach idle with landing flaps")
rt:set("sim/cockpit2/controls/flap_ratio", 4 / 6)          -- flaps 20
frames(4.5)
T.near(get(IDLE), 2.625, 0.001, "idle: approach idle kept 5 s")
frames(1)
T.near(get(IDLE), 1.00 + 0.07 * 55 / 89.99, 0.001, "idle: minimum idle after 5 s")
rt:set("laminar/B747/antiice/nacelle/valve_pos", 2, 1)
frames(0.5)
T.near(get(IDLE), 2.625, 0.001, "idle: engine 3's anti-ice selects approach idle (X-Plane has one setting)")
rt:set("laminar/B747/antiice/nacelle/valve_pos", 2, 0)
for n = 0, 3 do T.equal(get(ADV, 309 + n), 0, "idle: no ENG " .. (n + 1) .. " LOW IDLE") end
T.equal(get(ADV, 223), 0, "idle: no >IDLE DISAGREE")
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15)
rt:set("sim/cockpit2/controls/flap_ratio", 0)
frames(6)
T.near(get(IDLE), 1.071, 0.001, "idle: minimum idle on the ground (15 °C), 5 s after touchdown")

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
T.equal(get("laminar/B747/engines/autothrottle_fail"), 1, "ALTN: the A/T disconnects")
T.equal(get("laminar/B747/engines/autothrottle_active"), 0, "ALTN: the A/T is off")
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

-- the thrust control drives X-Plane's throttle (ecc_spd): engines running,
-- forward thrust, in the air; the stand-in engine gives no thrust, so the
-- EPR stays low and full forward opens the throttle fully, idle closes it
local THRO = "sim/flightmodel/engine/ENGN_thro_use"
rt:set("sim/flightmodel/failures/onground_any", 0)
for i = 0, 3 do
    rt:set("sim/flightmodel/engine/ENGN_running", i, 1)
    rt:set("sim/cockpit2/engine/actuators/prop_mode", i, 1)
end
for i = 0, 3 do rt:set(USER, i, 1.0) end
frames(3)
T.near(get(THRO, 0), 1, 1e-6, "thrust control: full forward, EPR short of the command: full throttle")
T.equal(get("sim/operation/override/override_throttles"), 1, "thrust control: X-Plane's throttles are overridden")
for i = 0, 3 do rt:set(USER, i, 0.0) end
frames(3)                                                   -- the levers come back
T.equal(get(THRO, 0), 0, "thrust control: idle lever: throttle 0")
rt:set("sim/cockpit2/engine/actuators/prop_mode", 1, 3)       -- engine 2 in reverse
frames(0.2)
T.equal(get(THRO, 1), 0, "thrust control: reverser not deployed: no thrust")
rt:set("sim/cockpit2/engine/actuators/prop_mode", 1, 1)
rt:set("sim/flightmodel/failures/onground_any", 1)

-- GE at sea level, 15 °C
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"CF6-80C2B1F"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
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

T.done()
