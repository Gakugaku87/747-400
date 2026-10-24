-- Run from the repository root with LuaJIT: luajit tests/gear/wheels_module_test.lua
-- The wheels' glue (B747.10.xt.wheels.lua, 4-2 step 5) in the gear module as
-- XTLua runs it (tests/lib/xtlua.lua): X-Plane's absorbed brake energy shared
-- by each truck's four brakes, the temperatures and indications
-- (laminar/B747/gear/brake_temp, brake_temp_ind), BRAKE TEMP, the tires'
-- pressures with the weight on them and X-Plane's tire failure,
-- >TIRE PRESSURE, BRAKE TEMP SYS and TIRE PRESS SYS. The models are tested
-- in btms_model_test.lua and tpis_model_test.lua.
local T = dofile("tests/lib/check.lua")("wheels_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.xt.gear.lua")
local TEMP, IND, PSI = "laminar/B747/gear/brake_temp", "laminar/B747/gear/brake_temp_ind", "laminar/B747/gear/tire_pressure"
local ADV, STATUS = "laminar/B747/CAS/advisory_status", "laminar/B747/CAS/status_status"
local J = "sim/flightmodel2/gear/brake_absorbed_J"
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15)
for i = 0, 4 do
    rt:set("sim/flightmodel2/gear/on_ground", i, 1)
    rt:set("sim/flightmodel2/gear/deploy_ratio", i, 1)
end
for i = 1, 4 do rt:set("sim/flightmodel2/gear/eagle_claw_angle_deg", i, 0.9) end
rt:callout("flight_start")
local function run(seconds, step)
    step = step or 1 / 30
    for _ = 1, math.floor(seconds / step + 0.5) do rt:frame(step) end
end

run(4)
T.near(rt:get(TEMP, 0), 15, 1e-6, "the brakes at the outside air")
T.equal(rt:get(IND, 0), 0, "indication 0")
local p = rt:get(PSI, 4)
T.check(p >= 208 and p <= 220, "a loaded main tire: as serviced plus 10 psi (" .. p .. ")")
T.equal(rt:get(ADV, 290), 0, "no >TIRE PRESSURE")

-- the left body truck (X-Plane's gear 2) absorbs 4 x 60 MJ: brakes 5-8
-- (indices 4-7) heat, the others do not
rt:set(J, 2, 240e6)
run(1)
run(600, 1)
local t5 = rt:get(TEMP, 4)
T.check(t5 > 482, "brake 5, 10 min after 60 MJ: over 482 °C (" .. t5 .. ")")
T.equal(rt:get(TEMP, 7), t5, "brakes 5-8 alike")
T.near(rt:get(TEMP, 8), 15, 0.01, "the right body truck's brakes cold")
T.check(rt:get(IND, 4) >= 5, "indication 5 or more")
T.equal(rt:get(ADV, 46), 1, "BRAKE TEMP (FCOM p.1521)")
T.near(rt:get(TEMP, 16), 15, 1e-6, "the nose wheels: no brakes")
-- X-Plane cools its own figure: that is not heat
rt:set(J, 2, 100e6)
run(1)
T.check(rt:get(TEMP, 4) < t5 + 1, "X-Plane's figure falling: no heat (only the thermocouples catching up)")
-- X-Plane's tire failure on the left body gear (rel_tire3): flat, >TIRE PRESSURE
rt:set("sim/operation/failures/rel_tire3", 6)
run(6)
T.near(rt:get(PSI, 5), 5, 1e-6, "the left body tires flat")
T.check(rt:get(PSI, 9) > 150, "the right body tires as they were")
T.equal(rt:get(ADV, 290), 1, ">TIRE PRESSURE")
rt:set("sim/operation/failures/rel_tire3", 0)
-- the systems failed
rt:set("laminar/B747/gear/fail/btms", 1)
rt:set("laminar/B747/gear/fail/tpis", 1)
run(0.2)
T.equal(rt:get(STATUS, 97), 1, "BRAKE TEMP SYS (ATA29_32 p.428)")
T.equal(rt:get(ADV, 46), 0, "no BRAKE TEMP")
T.equal(rt:get(STATUS, 98), 1, "TIRE PRESS SYS (ATA29_32 p.376)")
T.equal(rt:get(ADV, 290), 0, "no >TIRE PRESSURE with the channels failed")
T.done()
