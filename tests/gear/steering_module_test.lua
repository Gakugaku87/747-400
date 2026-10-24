-- Run from the repository root with LuaJIT: luajit tests/gear/steering_module_test.lua
-- The steering glue (B747.10.xt.steering.lua, 4-2 step 4) in the gear module
-- as XTLua runs it (tests/lib/xtlua.lua): X-Plane's wheel steering
-- overridden, the rudder pedals with the rudder trim
-- (laminar/B747/flt_ctrls/rudder_input) and the tillers (X-Plane's tiller
-- axis 37, else laminar/B747/gear/steering/tiller) on the nose wheels, the
-- pedals as the tiller without a tiller axis (on at the aircraft's load),
-- system 1 with the gear lever DN, the body gear the other way after 10 s
-- on the ground, the trucks' locks, >BODY GEAR STRG, BODY GR STRG SYS,
-- PEDAL STEERING. The model is tested in steering_model_test.lua.
local T = dofile("tests/lib/check.lua")("steering_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.xt.gear.lua")
local CMD = "sim/flightmodel2/gear/tire_steer_command_deg"
local PEDAL, TILLER = "laminar/B747/flt_ctrls/rudder_input", "laminar/B747/gear/steering/tiller"
local PT = "laminar/B747/gear/steering/pedal_tiller"
local UNLOCKED = "laminar/B747/gear/steering/body_unlocked"
local GS = "sim/flightmodel/position/groundspeed"
-- on the ground: the PSEU in ground mode with the nose gear compressed;
-- system 1 pressurised, the gear lever DN
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
rt:set("laminar/B747/hydraulics/pressure_4", 3000)
for i = 0, 4 do
    rt:set("sim/flightmodel2/gear/on_ground", i, 1)
    rt:set("sim/flightmodel2/gear/deploy_ratio", i, 1)
end
for i = 1, 4 do rt:set("sim/flightmodel2/gear/eagle_claw_angle_deg", i, 0.9) end
rt:callout("aircraft_load")
rt:callout("flight_start")
local function run(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end

run(1)
T.equal(rt:get("laminar/B747/gear/air_ground/ng_compressed"), 1, "the PSEU: nose gear compressed")
T.equal(rt:get("laminar/B747/actuator/gear_handle"), 0, "the gear lever DN")
T.equal(rt:get("sim/operation/override/override_wheel_steer"), 1, "X-Plane's wheel steering overridden")
T.equal(rt:get(PT), 1, "the aircraft's load: the pedals as the tiller on")
-- the pedals as the tiller (no tiller axis), stopped: 70 degrees
rt:set(PEDAL, 1)
run(4)
T.near(rt:get(CMD, 0), 70, 1e-6, "full pedal, no tiller axis, stopped: 70 degrees (not the aircraft)")
-- the pedals as the aircraft's: 7 degrees
rt:set(PT, 0)
run(4)
T.near(rt:get(CMD, 0), 7, 1e-6, "pedal tiller off: full pedal 7 degrees (FCOM p.1513)")
-- the tiller (the dataref; X-Plane's tiller axis would take its place)
rt:set(TILLER, -1)
run(1)
T.check(rt:get(CMD, 0) < 0, "the tiller over the pedals")
run(4)
T.near(rt:get(CMD, 0), -70, 1e-6, "full left tiller: -70")
-- 10 s on the ground: the body gear the other way, 13 degrees
run(6)
T.near(rt:get(CMD, 2), 13, 1e-6, "left body gear (X-Plane's gear 2): 13 degrees right")
T.near(rt:get(CMD, 1), 13, 1e-6, "right body gear (X-Plane's gear 1)")
T.equal(rt:get(CMD, 3), 0, "the wing gear: none")
T.equal(rt:get(UNLOCKED), 1, "the trucks unlocked")
T.equal(rt:get("laminar/B747/CAS/advisory_status", 43), 0, "commanded: no >BODY GEAR STRG")
-- X-Plane's tiller axis: joy_mapped_axis index 37
rt:set("sim/joystick/joy_mapped_axis_avail", 37, 1)
rt:set("sim/joystick/joy_mapped_axis_value", 37, 0.5)
run(6)
T.near(rt:get(CMD, 0), 35, 1e-6, "X-Plane's tiller axis at 0.5: 35 degrees")
T.near(rt:get(CMD, 2), -3.9, 1e-6, "the body gear 3.9 degrees left")
rt:set("sim/joystick/joy_mapped_axis_value", 37, 0)
rt:set(PEDAL, 0)
run(4)
T.near(rt:get(CMD, 0), 0, 1e-6, "tiller and pedals centred")
T.equal(rt:get(UNLOCKED), 0, "the trucks centred and locked")
-- the gear lever not DN: no gear down pressure, no steering
rt:set("sim/joystick/joy_mapped_axis_value", 37, 1)
rt:set("laminar/B747/actuator/gear_handle", 1)
run(2)
T.near(rt:get(CMD, 0), 0, 1e-6, "lever OFF: no steering (system 1's gear down pressure)")
rt:set("laminar/B747/actuator/gear_handle", 0)
rt:set("laminar/B747/hydraulics/pressure_1", 0)
run(2)
T.near(rt:get(CMD, 0), 0, 1e-6, "system 1 lost: no steering")
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
rt:set("sim/joystick/joy_mapped_axis_value", 37, 0)
-- over 20 kt: the body gear disarmed
rt:set(GS, 11)
rt:set("sim/joystick/joy_mapped_axis_value", 37, 1)
run(5)
T.near(rt:get(CMD, 0), 70, 1e-6, "21 kt, full tiller: 70")
T.equal(rt:get(CMD, 2), 0, "21 kt: no body gear steering (FCOM p.1513)")
rt:set("sim/joystick/joy_mapped_axis_value", 37, 0)
rt:set(GS, 0)
run(4)
-- failures
rt:set("laminar/B747/gear/fail/body_steering", 1)
run(5.5)
T.equal(rt:get(UNLOCKED), 1, "a truck's actuator unlocked")
T.equal(rt:get("laminar/B747/CAS/advisory_status", 43), 1, ">BODY GEAR STRG (FCOM p.1521)")
T.equal(rt:get("laminar/B747/CAS/status_status", 95), 1, "BODY GR STRG SYS (ATA29_32 p.630)")
rt:set("laminar/B747/gear/fail/body_steering", 0)
rt:set("laminar/B747/gear/fail/pedal_steering", 1)
run(0.2)
T.equal(rt:get("laminar/B747/CAS/advisory_status", 43), 0, "locked: no >BODY GEAR STRG")
T.equal(rt:get("laminar/B747/CAS/status_status", 96), 1, "PEDAL STEERING (p.600)")
rt:set("laminar/B747/gear/fail/pedal_steering", 0)
-- in the air: centred by the cams
rt:set("sim/joystick/joy_mapped_axis_value", 37, 1)
run(2)
for i = 0, 4 do rt:set("sim/flightmodel2/gear/on_ground", i, 0) end
for i = 1, 4 do rt:set("sim/flightmodel2/gear/eagle_claw_angle_deg", i, 8) end
run(5)
T.equal(rt:get("laminar/B747/gear/air_ground/ng_compressed"), 0, "airborne: the nose gear extended")
T.near(rt:get(CMD, 0), 0, 1e-6, "airborne: centred, the tiller does nothing (ATA29_32 p.570)")
T.done()
