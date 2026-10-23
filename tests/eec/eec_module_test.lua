-- Run from the repository root with LuaJIT: luajit tests/eec/eec_module_test.lua
-- The EEC module as XTLua runs it (tests/lib/xtlua.lua): the EEC model
-- through its glue (B747.42.xt.eec_thrust.lua) in B747.42.xt.EEC.lua. The
-- levers, air data, packs and anti-ice in; the lever command (TRA) and the
-- max line out, for P&W and GE. The model's numbers themselves are tested
-- in eec_model_test.lua; this checks the wiring.
local T = dofile("tests/lib/check.lua")("eec_module")
local xtlua = dofile("tests/lib/xtlua.lua")

math.randomseed(1)
local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.xt.EEC.lua")
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local ENG = "laminar/B747/engines/"
local USER = "sim/cockpit2/engine/actuators/throttle_ratio"

-- P&W at sea level, 15 °C, three packs on, on the ground
rt:set("laminar/B747/engines/type", 0)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/flightmodel2/position/pressure_altitude", 0)
rt:set("sim/cockpit2/temperature/outside_air_LE_temp_degc", 15)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15)
for i = 0, 2 do rt:set("laminar/B747/air/pack_ctrl/sel_dial_pos", i, 1) end
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
for i = 0, 2 do rt:set("laminar/B747/air/pack_ctrl/sel_dial_pos", i, 0) end
frames(0.2)
T.near(get(ENG .. "display_EPR_max", 0), 1.53, 0.005, "P&W: 3 packs off raise the max EPR by 0.02")
for i = 0, 2 do rt:set("laminar/B747/air/pack_ctrl/sel_dial_pos", i, 1) end

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

T.done()
