-- Run from the repository root with LuaJIT: luajit tests/nav/baro_std_test.lua
-- The EFIS control panels' BARO STD push (B747.60.xt.fltInst02.lua, NAV-06;
-- FCOM p.1037 (10.10.75)): STD sets 29.92; the next push brings back the
-- setting before STD, or the value preselected meanwhile with the knob.
local T = dofile("tests/lib/check.lua")("baro_std")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
rt:callout("flight_start")
local function frames(n) for _ = 1, n do rt:frame(1 / 30) end end
frames(10)
local BARO_C = "sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot"
local BARO_F = "sim/cockpit2/gauges/actuators/barometer_setting_in_hg_copilot"

for _, side in ipairs({{"capt", BARO_C}, {"fo", BARO_F}}) do
    local name, baro = side[1], side[2]
    rt:set("laminar/B747/efis/baro_std/" .. name .. "/switch_pos", 0)
    rt:set(baro, 29.50)
    frames(1)
    rt:command("laminar/B747/efis/baro_std/" .. name .. "/switch")
    frames(1)
    T.near(rt:get(baro), 29.92, 1e-6, name .. ": STD: 29.92")
    rt:command("laminar/B747/efis/baro_std/" .. name .. "/switch")
    frames(1)
    T.near(rt:get(baro), 29.50, 1e-6, name .. ": STD again: back to 29.50 (was left at 29.92)")
    -- a preselect turned in STD comes back instead
    rt:command("laminar/B747/efis/baro_std/" .. name .. "/switch")
    rt:command("laminar/B747/efis/baro_set/" .. name .. "/sel_dial_up")
    rt:command("laminar/B747/efis/baro_set/" .. name .. "/sel_dial_up")
    frames(1)
    T.near(rt:get(baro), 29.92, 1e-6, name .. ": still STD while preselecting")
    rt:command("laminar/B747/efis/baro_std/" .. name .. "/switch")
    frames(1)
    T.near(rt:get(baro), 29.52, 1e-6, name .. ": the preselected 29.52")
end
T.done()
