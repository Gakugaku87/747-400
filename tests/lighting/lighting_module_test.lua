-- Run from the repository root with LuaJIT: luajit tests/lighting/lighting_module_test.lua
-- The lighting module as XTLua runs it (tests/lib/xtlua.lua).
local T = dofile("tests/lib/check.lua")("lighting_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.90.xt.lighting/B747.90.xt.lighting.lua")
rt:callout("flight_start")
rt:frame(1 / 30)

-- the generic light 63 powers the display brightness; X-Plane sets it back to
-- 0 when a new flight starts without reloading the aircraft
local LIGHT_POWER = "sim/cockpit2/switches/generic_lights_switch"
T.equal(rt:get(LIGHT_POWER, 63), 1, "flight start: generic light 63 on")
rt:set(LIGHT_POWER, 63, 0)
rt:frame(1 / 30)
T.equal(rt:get(LIGHT_POWER, 63), 1, "new flight without reload: generic light 63 back on")

-- the fuel panel lights come from the fuel model (laminar/B747/fuel/light/*):
-- each to its annunciator (brightness 0.8 with IND LTS BRT and bus power)
rt:set("sim/flightmodel2/lights/generic_lights_brightness_ratio", 63, 1)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
local ANNUN = "laminar/B747/annunciator/brightness_ratio"
local PRESS = "laminar/B747/fuel/light/pump_press"
local function only(name, i)
    for k = 0, 15 do rt:set(PRESS, k, 0) end
    for k = 0, 3 do rt:set("laminar/B747/fuel/light/xfeed_valve", k, 0) end
    for k = 0, 1 do rt:set("laminar/B747/fuel/light/nozzle_valve", k, 0) end
    rt:set(name, i, 1)
    rt:frame(1 / 30)
end
-- light index of the model (B747_fuel_model.PUMPS order) -> annunciator
local PRESS_ANNUN = {[0] = 48, 52, 49, 53, 50, 54, 51, 55, 56, 58, 57, 59, 44, 45, 46, 47}
for i = 0, 15 do
    only(PRESS, i)
    T.near(rt:get(ANNUN, PRESS_ANNUN[i]), 0.8, 0.01, "fuel PRESS light " .. i .. " -> annunciator " .. PRESS_ANNUN[i])
    T.near(rt:get(ANNUN, 40), 0, 0.01, "fuel PRESS light " .. i .. ": X FEED 1 VALVE off")
end
only("laminar/B747/fuel/light/xfeed_valve", 2)
T.near(rt:get(ANNUN, 42), 0.8, 0.01, "X FEED 3 VALVE light -> annunciator 42")
only("laminar/B747/fuel/light/nozzle_valve", 1)
T.near(rt:get(ANNUN, 39), 0.8, 0.01, "NOZZLE R VALVE light -> annunciator 39")
T.near(rt:get(ANNUN, 38), 0, 0.01, "NOZZLE L VALVE light off")

T.done()
