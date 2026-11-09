-- Run from the repository root with LuaJIT: luajit tests/elec/battery_switch_test.lua
-- The BATTERY switch's push (B747.01.xt.manipulators.lua) as XTLua runs it
-- (tests/lib/xtlua.lua): both pilots' minimums left alone (the switch's
-- position animates in after_physics, not run here). 2026-11-09's audit:
-- the upstream handler set the RA minimums to -1 and the BARO references
-- to -101 on every push whatever the power (the EFIS control panels stay
-- powered from the AC transfer buses with the generators on); the display
-- module sets them at its start
local T = dofile("tests/lib/check.lua")("battery_switch")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.01.xt.manipulators/B747.01.xt.manipulators.lua")
rt:callout("flight_start")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(1)
local RA_C, RA_F = "sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_pilot", "sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_copilot"
local BARO_C, BARO_F = "laminar/B747/efis/baro_ref/capt", "laminar/B747/efis/baro_ref/fo"
rt:set(RA_C, 200)
rt:set(RA_F, 210)
rt:set(BARO_C, 1200)
rt:set(BARO_F, 1250)
rt:command("laminar/B747/button_switch/elec_battery", 0.1)
frames(1)
T.equal(rt:get(RA_C), 200, "the captain's RA minimums kept")
T.equal(rt:get(RA_F), 210, "the first officer's RA minimums kept")
T.equal(rt:get(BARO_C), 1200, "the captain's BARO reference kept")
T.equal(rt:get(BARO_F), 1250, "the first officer's BARO reference kept")
rt:command("laminar/B747/button_switch/elec_battery", 0.1)
frames(1)
T.equal(rt:get(RA_C), 200, "and the minimums still kept")

T.done()
