-- Run from the repository root with LuaJIT: luajit tests/autopilot/xplane_vs_flch_test.lua
-- X-Plane's V/S and FLCH commands (sim/autopilot/vertical_speed and
-- level_change, B747.01.xt.manipulators.lua's replacements) as XTLua runs
-- them (tests/lib/xtlua.lua): each pushes the MCP's switch (laminar/B747/
-- autopilot/button_switch/vs_mode, flch_mode: the AFDS model's) once and
-- writes no mode flag. 2026-11-09's audit: before, they wrote vvi_status
-- (2), speed_status (2), altitude_hold_status and thrust_mode themselves:
-- the V/S light and window with no mode, nothing flown with the A/P off.
local T = dofile("tests/lib/check.lua")("xplane_vs_flch")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.01.xt.manipulators/B747.01.xt.manipulators.lua")
rt:callout("flight_start")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(1)
local mark = 0
local function sent()
    local t = {}
    for i = mark + 1, #rt.command_log do
        local c = rt.command_log[i]
        if c.phase == "once" then t[c.name] = (t[c.name] or 0) + 1 end
    end
    mark = #rt.command_log
    return t
end
local AP = "laminar/B747/autopilot/"
sent()
rt:command("sim/autopilot/vertical_speed", 0.3)
frames(0.2)
T.equal(sent()[AP .. "button_switch/vs_mode"], 1, "vertical_speed: the MCP's V/S switch pushed once (held 0.3 s)")
T.equal(rt:get(AP .. "vvi_status"), 0, "no vvi_status written")
T.equal(rt:get(AP .. "altitude_hold_status"), 0, "no altitude_hold_status written")
rt:command("sim/autopilot/level_change", 0.1)
frames(0.2)
T.equal(sent()[AP .. "button_switch/flch_mode"], 1, "level_change: the MCP's FLCH SPD switch pushed once")
T.equal(rt:get(AP .. "speed_status"), 0, "no speed_status written")
T.equal(rt:get(AP .. "thrust_mode"), 0, "no thrust_mode written")

T.done()
