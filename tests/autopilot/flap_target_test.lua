-- Run from the repository root with LuaJIT: luajit tests/autopilot/flap_target_test.lua
-- The autopilot module's flap target (laminar/B747/autopilot/flaps/target):
-- a helper for external tools that moves the flap handle to the flaps asked
-- for and then goes back to -1 (nothing to do). The dataref is made at 0,
-- which the helper took as flaps UP: right after every load it moved the
-- handle of a flight starting with flaps out (X-Plane's runway start: 10) to
-- UP, after the FCU had taken the flaps where the handle was. In a cold and
-- dark start nothing can move the flaps, so the FCU stopped the drives and
-- showed FLAPS DRIVE (correct for a lever moved without power: FCTM p.283).
-- flight_start now sets the target to -1.
local T = dofile("tests/lib/check.lua")("ap_flap_target")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local TARGET, HANDLE = "laminar/B747/autopilot/flaps/target", "sim/cockpit2/controls/flap_ratio"

local rt = xtlua.new()
rt:load(AP)
T.equal(rt:get(TARGET), 0, "the dataref is made at 0 (flaps UP to the helper)")
-- the module's after_physics waits for the simulator config (the FMS's) and
-- decodes XTLua's flight plan (no legs here)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set(HANDLE, 0.5)                                 -- the runway start's flaps 10
rt:callout("flight_start")
T.equal(rt:get(TARGET), -1, "flight_start: no flap target")
for _ = 1, 300 do rt:frame(1 / 30) end
T.equal(rt:get(HANDLE), 0.5, "10 s on, the handle is still at flaps 10")

-- an external tool asks for flaps 20: the helper still moves the handle, at
-- an eighth of the travel a second, and is done within 0.01 of the detent
rt:set(TARGET, 20)
for _ = 1, 15 do rt:frame(1 / 30) end
local h = rt:get(HANDLE)
T.check(h > 0.5 and h < 0.667, "half a second on, the handle on its way to flaps 20 (" .. h .. ")")
for _ = 1, 300 do rt:frame(1 / 30) end
T.near(rt:get(HANDLE), 0.667, 0.01, "the handle at flaps 20")
T.equal(rt:get(TARGET), -1, "the target done")
T.done()
