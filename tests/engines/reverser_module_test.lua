-- Run from the repository root with LuaJIT: luajit tests/engines/reverser_module_test.lua
-- The thrust reversers in the engine module as XTLua runs it
-- (tests/lib/xtlua.lua): the reverse toggle command, the PSEU, the hydraulic
-- pressures and the running engines in; X-Plane's prop mode and ENG n
-- REVERSER out, through the glue (B747.40.xt.reverser.lua). The model's
-- behaviour is tested in reverser_model_test.lua; this checks the wiring.
-- A stand-in for X-Plane moves each reverser out while its prop mode is
-- reverse and in otherwise, at once.
local T = dofile("tests/lib/check.lua")("reverser_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.xt.engines.lua")
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 0)
rt:callout("flight_start")

local MODE = "sim/cockpit2/engine/actuators/prop_mode"
local DEPLOY = "sim/flightmodel2/engines/thrust_reverser_deploy_ratio"
local ADV = "laminar/B747/CAS/advisory_status"
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do
        rt:frame(1 / 30)
        for i = 0, 3 do rt:set(DEPLOY, i, rt:get(MODE, i) == 3 and 1 or 0) end
    end
end
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("laminar/B747/gear/air_ground/alt_gnd", 1)
for n = 1, 4 do
    rt:set("laminar/B747/hydraulics/pressure_" .. n, 3000)
    rt:set("sim/flightmodel/engine/ENGN_running", n - 1, 1)
    rt:set(MODE, n - 1, 1)
end
frames(1)

-- P&W, all powered: the toggle asks for reverse, all four reverse; again: all stow
rt:command("sim/engines/thrust_reverse_toggle")
frames(3)
for i = 0, 3 do T.equal(rt:get(MODE, i), 3, "toggle: engine " .. (i + 1) .. " in reverse") end
for i = 0, 3 do T.equal(rt:get(ADV, 126 + i), 0, "deployed: no ENG " .. (i + 1) .. " REVERSER") end
rt:command("sim/engines/thrust_reverse_toggle")
frames(5)
for i = 0, 3 do T.equal(rt:get(MODE, i), 1, "toggle again: engine " .. (i + 1) .. " stowed") end
T.equal(rt:get(ADV, 126), 0, "stowed: no ENG 1 REVERSER")

-- hydraulic system 1 without pressure: reverser 1 kept stowed, ENG 1 REVERSER
rt:set("laminar/B747/hydraulics/pressure_1", 0)
rt:command("sim/engines/thrust_reverse_toggle")
frames(1)
T.equal(rt:get(MODE, 0), 1, "P&W, system 1 low: engine 1 kept out of reverse")
T.equal(rt:get(MODE, 1), 3, "engine 2 in reverse")
T.equal(rt:get(ADV, 126), 0, "ENG 1 REVERSER not yet")
frames(2)
T.equal(rt:get(ADV, 126), 1, "ENG 1 REVERSER: asked out, still stowed")
T.equal(rt:get(ADV, 127), 0, "no ENG 2 REVERSER")
rt:command("sim/engines/thrust_reverse_toggle")
frames(5)
T.equal(rt:get(ADV, 126), 0, "levers down: ENG 1 REVERSER goes")

-- GE: engine 4 stopped, its reverser does not move; hydraulics do not matter
rt:set("laminar/B747/engines/type", 1)
rt:set("sim/flightmodel/engine/ENGN_running", 3, 0)
rt:command("sim/engines/thrust_reverse_toggle")
frames(1)
T.equal(rt:get(MODE, 0), 3, "GE: engine 1 in reverse with system 1 low")
T.equal(rt:get(MODE, 3), 1, "GE: engine 4 stopped, kept out of reverse")

T.done()
