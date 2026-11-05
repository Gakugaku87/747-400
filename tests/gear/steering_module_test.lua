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

local MAIN = "plugins/xtlua/scripts/B747.10.xt.gear/B747.10.xt.gear.lua"
local CMD = "sim/flightmodel2/gear/tire_steer_command_deg"
local PEDAL, TILLER = "laminar/B747/flt_ctrls/rudder_input", "laminar/B747/gear/steering/tiller"
local PT = "laminar/B747/gear/steering/pedal_tiller"
local UNLOCKED = "laminar/B747/gear/steering/body_unlocked"
local GS = "sim/flightmodel/position/groundspeed"
local AVAIL, VALUE = "sim/joystick/joy_mapped_axis_avail", "sim/joystick/joy_mapped_axis_value"
local ASSIGN, RAW = "sim/joystick/joystick_axis_assignments", "sim/joystick/joystick_axis_values"
local REVERSE = "sim/joystick/joystick_axis_reverse"

-- on the ground: the PSEU in ground mode with the nose gear compressed;
-- system 1 pressurised, the gear lever DN
local function on_ground(r)
    r:set("laminar/B747/hydraulics/pressure_1", 3000)
    r:set("laminar/B747/hydraulics/pressure_4", 3000)
    for i = 0, 4 do
        r:set("sim/flightmodel2/gear/on_ground", i, 1)
        r:set("sim/flightmodel2/gear/deploy_ratio", i, 1)
    end
    for i = 1, 4 do r:set("sim/flightmodel2/gear/eagle_claw_angle_deg", i, 0.9) end
    r:callout("aircraft_load")
    r:callout("flight_start")
end
local function run_on(r, seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do r:frame(1 / 30) end end

local rt = xtlua.new()
rt:load(MAIN)
on_ground(rt)
local function run(seconds) run_on(rt, seconds) end

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
rt:set(AVAIL, 37, 1)
rt:set(VALUE, 37, 0.5)
run(6)
T.near(rt:get(CMD, 0), 35, 1e-6, "X-Plane's tiller axis at 0.5: 35 degrees")
T.near(rt:get(CMD, 2), -3.9, 1e-6, "the body gear 3.9 degrees left")
rt:set(VALUE, 37, 0)
rt:set(PEDAL, 0)
run(4)
T.near(rt:get(CMD, 0), 0, 1e-6, "tiller and pedals centred")
T.equal(rt:get(UNLOCKED), 0, "the trucks centred and locked")
-- the gear lever not DN: no gear down pressure, no steering
rt:set(VALUE, 37, 1)
rt:set("laminar/B747/actuator/gear_handle", 1)
run(2)
T.near(rt:get(CMD, 0), 0, 1e-6, "lever OFF: no steering (system 1's gear down pressure)")
rt:set("laminar/B747/actuator/gear_handle", 0)
rt:set("laminar/B747/hydraulics/pressure_1", 0)
run(2)
T.near(rt:get(CMD, 0), 0, 1e-6, "system 1 lost: no steering")
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
rt:set(VALUE, 37, 0)
-- over 20 kt: the body gear disarmed
rt:set(GS, 11)
rt:set(VALUE, 37, 1)
run(5)
T.near(rt:get(CMD, 0), 70, 1e-6, "21 kt, full tiller: 70")
T.equal(rt:get(CMD, 2), 0, "21 kt: no body gear steering (FCOM p.1513)")
rt:set(VALUE, 37, 0)
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
rt:set(VALUE, 37, 1)
run(2)
for i = 0, 4 do rt:set("sim/flightmodel2/gear/on_ground", i, 0) end
for i = 1, 4 do rt:set("sim/flightmodel2/gear/eagle_claw_angle_deg", i, 8) end
run(5)
T.equal(rt:get("laminar/B747/gear/air_ground/ng_compressed"), 0, "airborne: the nose gear extended")
T.near(rt:get(CMD, 0), 0, 1e-6, "airborne: centred, the tiller does nothing (ATA29_32 p.570)")

-- (2026-11-05) the user's tiller (another PC, X-Plane 12.4.4): a hardware
-- axis (28) assigned the nosewheel tiller (37), X-Plane's processed value in
-- joy_mapped_axis_value[37] with joy_mapped_axis_avail[37] kept at 0. The
-- raw axis until X-Plane's value moves (a ratio, reversed as set, a 5 % null
-- zone), then X-Plane's value
local report = {}
local real_open = io.open
io.open = function(path, mode)
    if path == "Output/B747_steering.txt" then
        return {write = function(_, ...) for _, s in ipairs({...}) do report[#report + 1] = s end end,
            close = function() end}
    end
    return real_open(path, mode)
end
local AX = 28
local r2 = xtlua.new()
r2:load(MAIN)
r2:set(ASSIGN, 2, 3)
r2:set(ASSIGN, AX, 37)
r2:set(RAW, 2, 0.5)
r2:set(RAW, AX, 0.5)
on_ground(r2)
r2:set(PEDAL, 1)
run_on(r2, 6)
T.near(r2:get(CMD, 0), 7, 1e-6, "a tiller on axis 28, centred: full pedal 7 degrees (a tiller axis: not the pedals as the tiller)")
r2:set(PEDAL, 0)
r2:set(RAW, AX, 1)
run_on(r2, 6)
T.near(r2:get(CMD, 0), 70, 1e-6, "axis 28 at its stop, X-Plane's value still: full right, 70")
r2:set(RAW, AX, 0.25)
run_on(r2, 6)
local part = 70 * (0.5 - 0.05) / 0.95
T.near(r2:get(CMD, 0), -part, 1e-6, "a quarter: half left, less the null zone")
r2:set(REVERSE, AX, AX)
run_on(r2, 6)
T.near(r2:get(CMD, 0), part, 1e-6, "reversed by the axis's number (FlyWithLua's sample: above 0): half right")
r2:set(REVERSE, AX, 0)
-- the range seen is not used (a ratio already; 9.9e9 before calibrating)
r2:set("sim/joystick/joystick_axis_minimum", AX, 9.9e9)
r2:set("sim/joystick/joystick_axis_maximum", AX, -9.9e9)
run_on(r2, 6)
T.near(r2:get(CMD, 0), -part, 1e-6, "min/max not calibrated: the ratio as it is")
r2:set(RAW, AX, 0.52)
run_on(r2, 6)
T.near(r2:get(CMD, 0), 0, 1e-6, "just off its centre: the null zone")
-- X-Plane's value moving with avail 0 (12.4.4, the user's 0.717 at 0.859)
r2:set(RAW, AX, 0.859)
r2:set(VALUE, 37, 0.717)
run_on(r2, 6)
T.near(r2:get(CMD, 0), 0.717 * 70, 1e-6, "X-Plane's value moving, avail 0: its 0.717, 50.2 degrees")
r2:set(RAW, AX, 0.416)
r2:set(VALUE, 37, -0.078)
run_on(r2, 6)
T.near(r2:get(CMD, 0), -0.078 * 70, 1e-6, "then X-Plane's value (its null zone and response), not the raw axis's -0.125")
r2:set(VALUE, 37, 0)
r2:set(RAW, AX, 0.9)
run_on(r2, 6)
T.near(r2:get(CMD, 0), 0, 1e-6, "X-Plane's value centred: centred, the raw axis no longer read")
-- the report: the assignments when they change, nothing else
r2:set(ASSIGN, 2, 0)
run_on(r2, 3)
io.open = real_open
local text = table.concat(report)
T.check(text:find("joystick axes (axis=assignment): 2=3 28=37; the tiller (37) on axis 28\n", 1, true) ~= nil,
    "the report: the assignments and the tiller's axis")
T.check(text:find("joystick axes (axis=assignment): 28=37; the tiller (37) on axis 28\n", 1, true) ~= nil,
    "a line when the assignments change")
T.check(select(2, text:gsub("joystick axes", "")) == 2, "only those two lines")

-- no hardware axis seen (a tiller X-Plane processes from a device the
-- assignments do not show): the pedals as the tiller until X-Plane's value
-- moves, then the tiller and the pedals as the aircraft's
local r3 = xtlua.new()
r3:load(MAIN)
on_ground(r3)
r3:set(PEDAL, 1)
run_on(r3, 6)
T.near(r3:get(CMD, 0), 70, 1e-6, "no tiller seen: the pedals as the tiller, 70")
r3:set(PEDAL, 0)
r3:set(VALUE, 37, 0.5)
run_on(r3, 6)
T.near(r3:get(CMD, 0), 35, 1e-6, "X-Plane's tiller value moving, no axis assigned: 35")
r3:set(VALUE, 37, 0)
r3:set(PEDAL, 1)
run_on(r3, 6)
T.near(r3:get(CMD, 0), 7, 1e-6, "a tiller seen: the pedals as the aircraft's, 7")
r3:set(PEDAL, 0)
r3:set(TILLER, 1)
run_on(r3, 6)
T.near(r3:get(CMD, 0), 0, 1e-6, "a tiller seen: the tiller dataref not read")
T.done()
