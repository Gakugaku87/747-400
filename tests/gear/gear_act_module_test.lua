-- Run from the repository root with LuaJIT: luajit tests/gear/gear_act_module_test.lua
-- The gear actuation glue (B747.10.xt.gear_act.lua, 4-2 step 1) in the gear
-- module as XTLua runs it (tests/lib/xtlua.lua): the lever put where X-Plane
-- has the gear after the first 3 s, X-Plane's gear moved by the model
-- (acf_gear_deploy, in X-Plane's order 0 nose, 1 right body, 2 left body,
-- 3 right wing, 4 left wing), X-Plane's handle, the lever lock (the mock does
-- not run the init script's lever handler: the lock is checked on its
-- dataref), the EICAS indication, GEAR DISAGREE with system 4 lost, the WING
-- alternate extension and X-Plane's emergency gear command. The model itself
-- is tested in gear_model_test.lua.
local T = dofile("tests/lib/check.lua")("gear_act_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.xt.gear.lua")
local DEPLOY, ACF = "sim/flightmodel2/gear/deploy_ratio", "sim/aircraft/parts/acf_gear_deploy"
local G, LEVER, CAUTION = "laminar/B747/gear/", "laminar/B747/actuator/gear_handle", "laminar/B747/CAS/caution_status"

-- an air start: X-Plane has put the gear up; trucks tilted, hydraulics and buses on
for i = 0, 4 do
    rt:set(DEPLOY, i, 0)
    rt:set(ACF, i, 0)
    rt:set("sim/flightmodel2/gear/on_ground", i, 0)
end
for i, a in ipairs({8, 8, 58, 58}) do rt:set("sim/flightmodel2/gear/eagle_claw_angle_deg", i, a) end
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
rt:set("laminar/B747/hydraulics/pressure_4", 3000)
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set(LEVER, 0)                    -- left DN by the last flight
rt:callout("flight_start")
-- X-Plane follows what the plugin writes
local function run(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do
        rt:frame(1 / 30)
        for i = 0, 4 do rt:set(DEPLOY, i, rt:get(ACF, i)) end
    end
end

run(2)
T.equal(rt:get(LEVER), 0, "first 2 s: the lever left alone")
run(1.5)
T.equal(rt:get(LEVER), 2, "after 3 s: the lever UP, where X-Plane has the gear")
T.equal(rt:get(G .. "lever_lock"), 0, "trucks tilted, DC bus 2: the lever unlocked")
T.equal(rt:get("sim/cockpit2/controls/gear_handle_down"), 0, "X-Plane's handle up")
T.equal(rt:get(G .. "EICAS1_display_status"), 0, "all up at the start: no indication")

-- lever DN: the doors first, then the gear (2 s, then 7-12 s)
rt:set(LEVER, 0)
run(1)
T.equal(rt:get("sim/cockpit2/controls/gear_handle_down"), 1, "lever DN: X-Plane's handle down")
T.equal(rt:get(ACF, 0), 0, "1 s: the nose gear still up")
T.check(rt:get(G .. "door", 0) > 0.3, "its door opening")
run(5)
local lw = rt:get(ACF, 4)
T.check(lw > 0.3 and lw < 1, "6 s: the left wing gear (X-Plane 4) travelling (" .. lw .. ")")
T.equal(rt:get(G .. "gear_position/annun_status"), 2, "the transit box")
run(10)
T.equal(rt:get(ACF, 0), 1, "16 s: the nose gear down (2 + 12 s)")
T.equal(rt:get(G .. "gear_position/annun_status"), 1, "DOWN")
T.equal(rt:get(G .. "EICAS1_display_status"), 1, "the normal display")

-- up again, then system 4 lost and DN: the wing gear (X-Plane 3, 4) stays up;
-- GEAR DISAGREE 30 s after the lever, the expanded display
rt:set(LEVER, 2)
run(25)
T.equal(rt:get(ACF, 3), 0, "gear up")
rt:set("laminar/B747/hydraulics/pressure_4", 0)
rt:set(LEVER, 0)
run(20)
T.equal(rt:get(ACF, 1), 1, "system 1: the right body gear (X-Plane 1) down")
T.equal(rt:get(ACF, 3), 0, "no system 4: the right wing gear (X-Plane 3) up")
T.equal(rt:get(CAUTION, 38), 0, "20 s: no GEAR DISAGREE yet")
run(11)
T.equal(rt:get(CAUTION, 38), 1, "31 s: GEAR DISAGREE")
T.equal(rt:get(G .. "EICAS1_display_status"), 2, "the expanded display")
T.equal(rt:get(G .. "gear_position/annun_gear", 3), 0, "the left wing gear's box UP (order nose, LB, RB, LW, RW)")
T.equal(rt:get(G .. "gear_position/annun_gear", 1), 1, "the left body gear's box DN")

-- X-Plane's emergency extension pushes both ALTN switches through the
-- manipulators' commands (another module)
rt.command_log = {}
rt.commands["sim/flight_controls/landing_gear_emer_on"].handler(0, 0)
local pushed = {}
for _, c in ipairs(rt.command_log) do pushed[c.name] = c.phase end
T.equal(pushed["laminar/B747/button_switch/altn_nose_gear_extend"], "once", "emergency gear: ALTN NOSE/BODY pushed")
T.equal(pushed["laminar/B747/button_switch/altn_wing_gear_extend"], "once", "and ALTN WING")
-- the switches (the manipulators would turn the WING one on)
rt:set("laminar/B747/button_switch/position", 2, 1)
run(21)
T.equal(rt:get(ACF, 4), 1, "ALTN WING: the left wing gear down in about 20 s")
T.equal(rt:get(CAUTION, 38), 0, "all down: GEAR DISAGREE goes")
T.equal(rt:get(G .. "door", 3), 1, "the wing gear doors stay open")
T.equal(rt:get("laminar/B747/CAS/advisory_status", 180), 0, "no GEAR DOOR after an alternate extension")

-- on the ground the trucks are level: the lever locked
for i = 0, 4 do rt:set("sim/flightmodel2/gear/on_ground", i, 1) end
for i = 1, 4 do rt:set("sim/flightmodel2/gear/eagle_claw_angle_deg", i, 0.9) end
run(0.2)
T.equal(rt:get(G .. "lever_lock"), 1, "on the ground: the lever locked")
rt:set(LEVER, 2)
run(20)
T.equal(rt:get(ACF, 0), 1, "lever UP anyway (LOCK OVRD): a gear carrying weight stays down")
T.done()
