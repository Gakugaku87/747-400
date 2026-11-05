-- Run from the repository root with LuaJIT: luajit tests/elec/elec_flight_start_test.lua
-- (2026-11-05 review 3) a new flight starts the electrical system anew, in
-- the electrical module as XTLua runs it (tests/lib/xtlua.lua). Before, its
-- state was made once when the module loaded: a new flight without a
-- reload kept the batteries' charge, the GCRs' trips, the IDGs'
-- disconnects, the load shedding (a flat battery after a cold and dark on
-- the batteries).
local T = dofile("tests/lib/check.lua")("elec_flight_start")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.03.xt.electrical/B747.03.xt.electrical.lua")
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/operation/prefs/startup_running", 0)
rt:callout("flight_start")
local function frames(seconds, dt)
    dt = dt or 1 / 30
    for _ = 1, math.floor(seconds / dt + 0.5) do rt:frame(dt) end
end
local SW = "laminar/B747/button_switch/position"
local VOLTS = "laminar/B747/electrical/battery/volts"

frames(0.1)
-- BATTERY ON (switch 13), STANDBY POWER AUTO: the battery alone
rt:set(SW, 13, 1)
rt:set("laminar/B747/electrical/standby_power/sel_dial_pos", 1)
frames(1)
local v0 = rt:get(VOLTS, 0)
T.check(v0 > 20, "the battery on: " .. v0 .. " V")
frames(3600, 0.2)
local v1 = rt:get(VOLTS, 0)
T.check(v1 < v0 - 0.2, "an hour on the battery alone: " .. v1 .. " V (from " .. v0 .. ")")

-- a new flight (no reload): the battery charged again, as at a load
rt:callout("flight_start")
frames(0.1)
rt:set(SW, 13, 1)
rt:set("laminar/B747/electrical/standby_power/sel_dial_pos", 1)
frames(1)
local v2 = rt:get(VOLTS, 0)
T.check(math.abs(v2 - v0) < 0.05, "the new flight: " .. v2 .. " V, as at the load (before, the hour's " .. v1 .. ")")
T.done()
