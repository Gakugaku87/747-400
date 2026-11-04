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
-- (2026-11-05) the user's tiller (another PC, X-Plane 12.4.4) did not
-- steer, the pedals did: the hardware axis assigned the nosewheel tiller
-- (joystick_axis_assignments 37) read raw when joy_mapped_axis gives
-- nothing, over the range seen, reversed as set, with a 5 % null zone
local AX = 6
local RAW = "sim/joystick/joystick_axis_values"
rt:set("sim/joystick/joy_mapped_axis_avail", 37, 0)
rt:set("sim/joystick/joystick_axis_assignments", AX, 37)
rt:set("sim/joystick/joystick_axis_minimum", AX, 0.1)
rt:set("sim/joystick/joystick_axis_maximum", AX, 0.9)
rt:set(RAW, AX, 0.5)
rt:set(PT, 1)
rt:set(PEDAL, 1)
run(6)
T.near(rt:get(CMD, 0), 7, 1e-6, "a tiller on axis 6, centred: full pedal 7 degrees (a tiller axis: not the pedals as the tiller)")
rt:set(PEDAL, 0)
rt:set(RAW, AX, 0.9)
run(6)
T.near(rt:get(CMD, 0), 70, 1e-6, "axis 6 at the top of its range: full right, 70")
rt:set(RAW, AX, 0.3)
run(6)
local part = 70 * (0.5 - 0.05) / 0.95
T.near(rt:get(CMD, 0), -part, 1e-6, "a quarter of its range: half left, less the null zone")
rt:set("sim/joystick/joystick_axis_reverse", AX, 1)
run(6)
T.near(rt:get(CMD, 0), part, 1e-6, "reversed: half right")
rt:set("sim/joystick/joystick_axis_reverse", AX, 0)
rt:set(RAW, AX, 0.52)
run(6)
T.near(rt:get(CMD, 0), 0, 1e-6, "just off its centre: the null zone")
rt:set("sim/joystick/joy_mapped_axis_avail", 37, 1)
rt:set("sim/joystick/joy_mapped_axis_value", 37, -0.5)
rt:set(RAW, AX, 0.9)
run(6)
T.near(rt:get(CMD, 0), -35, 1e-6, "joy_mapped_axis moving: it first (X-Plane's own null zone and response)")
-- the hardware axis unassigned (X-Plane's axis 37 again, centred, as before)
rt:set("sim/joystick/joy_mapped_axis_value", 37, 0)
rt:set("sim/joystick/joystick_axis_assignments", AX, 0)
rt:set(RAW, AX, 0.5)
rt:set(PT, 0)
run(6)
T.near(rt:get(CMD, 0), 0, 1e-6, "the raw axis gone: centred")
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
