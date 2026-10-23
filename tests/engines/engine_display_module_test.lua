-- Run from the repository root with LuaJIT: luajit tests/engines/engine_display_module_test.lua
-- The engine indications in the engine module as XTLua runs it
-- (tests/lib/xtlua.lua): the displayed EGT, FUEL CONTROL, the running
-- engines and the TO/GA command in; the EGT flags the upper EICAS draws with
-- out, through the glue (B747.40.xt.engine_display.lua). The model's
-- behaviour is tested in engine_display_model_test.lua; this checks the
-- wiring.
local T = dofile("tests/lib/check.lua")("engine_display_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.xt.engines.lua")
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 0)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local EGT = "laminar/B747/engines/EGT/"
local FUEL_CONTROL = "laminar/B747/fuel/fuel_control/toggle_sw_pos"
local function flags(i)
    return {white = rt:get(EGT .. "white_on", i), amber = rt:get(EGT .. "amber_on", i),
        red = rt:get(EGT .. "red_on", i), line = rt:get(EGT .. "start_limit_on", i)}
end

-- P&W, all four at CUTOFF: the start limit line, red from 535 °C
for i = 0, 3 do rt:set(FUEL_CONTROL, i, 0) end
rt:set("laminar/B747/engines/display_EGT", 0, 300)
rt:set("laminar/B747/engines/display_EGT", 1, 540)
frames(1)
local f = flags(0)
T.equal(f.line, 1, "CUTOFF: start limit line")
T.equal(f.white, 1, "CUTOFF, EGT 300: white")
T.equal(flags(1).red, 1, "CUTOFF, EGT 540: red at the P&W start limit")
T.equal(rt:get(EGT .. "amber_inhibit", 0), 0, "the amber band is always shown")

-- running at RUN: no line; amber in the band, white after a TO/GA push, red at the red line
for i = 0, 3 do
    rt:set(FUEL_CONTROL, i, 1)
    rt:set("sim/flightmodel/engine/ENGN_running", i, 1)
end
rt:set("laminar/B747/engines/display_EGT", 0, 640)
rt:set("laminar/B747/engines/display_EGT", 1, 660)
frames(1)
f = flags(0)
T.equal(f.line, 0, "running at RUN: no start limit line")
T.equal(f.amber, 1, "EGT 640: amber (P&W continuous limit)")
T.equal(f.white, 0, "EGT 640: not white")
T.equal(flags(1).red, 1, "EGT 660: red (P&W takeoff limit)")
rt:command("sim/engines/TOGA_power")
frames(1)
T.equal(flags(0).white, 1, "after the TO/GA switch: white in the amber band")
T.equal(flags(0).amber, 0, "after the TO/GA switch: no amber")
T.equal(flags(1).red, 1, "after the TO/GA switch: still red at the red line")

-- GE reads its own EGT (display_GE_EGT) and limits; a new flight clears the inhibit
rt:set("laminar/B747/engines/type", 1)
rt:callout("flight_start")
rt:set("laminar/B747/engines/display_GE_EGT", 0, 930)
rt:set("laminar/B747/engines/display_GE_EGT", 1, 900)
rt:set("laminar/B747/engines/display_EGT", 1, 900)
frames(1)
T.equal(flags(0).amber, 1, "GE EGT 930: amber (continuous limit 925)")
T.equal(flags(1).white, 1, "GE EGT 900: white (the P&W limits do not apply)")

T.done()
