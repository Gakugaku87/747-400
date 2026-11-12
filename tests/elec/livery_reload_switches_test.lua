-- Run from the repository root with LuaJIT: luajit tests/elec/livery_reload_switches_test.lua
-- (2026-11-12 review SM-5; REVIEW_2026-11-12.md case 15) A livery loaded in
-- flight (X-Plane's next or previous livery, its menu: XTLua's livery_load)
-- reads the livery's type again and leaves the switches where the crew put
-- them. Before, livery_load ran setACFType, which put every switch back to
-- its start position 1 s later: with X-Plane's startup_running 0 the
-- airplane went cold and dark in flight (BATTERY, GEN CONT, HYD PUMP, FUEL
-- PUMP and YAW DAMPER off), with 1 the lights the crew had set went back.
-- The flight start still sets them (B747_flight_start_manip).
local T = dofile("tests/lib/check.lua")("livery_reload_switches")
local xtlua = dofile("tests/lib/xtlua.lua")

local BS, TS = "laminar/B747/button_switch/position", "laminar/B747/toggle_switch/position"
for _, startup in ipairs({0, 1}) do
    local rt = xtlua.new({types = {["sim/aircraft/view/acf_livery_path"] = "string"}})
    local m = rt:load("plugins/xtlua/scripts/B747.01.xt.manipulators/B747.01.xt.manipulators.lua")
    rt:set("sim/operation/prefs/startup_running", 1)        -- the flight started with the engines running
    rt:callout("flight_start")
    for _ = 1, 30 * 3 do rt:frame(1 / 30) end
    T.equal(rt:get(BS, 13), 1, "the flight start (engines running): BATTERY ON")
    -- in flight the crew turns the landing lights on (0 = ON)
    for _, c in ipairs({"OBL", "OBR", "IBL", "IBR"}) do rt:command("laminar/B747/toggle_switch/landing_light_" .. c) end
    for _ = 1, 30 do rt:frame(1 / 30) end
    T.equal(rt:get(TS, 1), 0, "landing light OBL ON")
    rt:set("sim/operation/prefs/startup_running", startup)
    m.env.n = m.ns
    m.env.do_callout("livery_load")
    for _ = 1, 30 * 2 do rt:frame(1 / 30) end
    local tag = " (startup_running " .. startup .. ")"
    T.equal(rt:get(BS, 13), 1, "2 s after a livery load: BATTERY still ON" .. tag)
    T.equal(rt:get(BS, 22), 1, "GEN CONT 1 still ON" .. tag)
    T.equal(rt:get(BS, 30), 1, "HYD PUMP 1 still ON" .. tag)
    T.equal(rt:get(BS, 82), 1, "YAW DAMPER UPR still ON" .. tag)
    T.equal(rt:get(TS, 1), 0, "landing light OBL still ON" .. tag)
end
T.done()
