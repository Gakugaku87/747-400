-- Run from the repository root with LuaJIT: luajit tests/gear/brakes_module_test.lua
-- The wheel brake glue (B747.10.xt.brakes.lua, 4-2 step 2) in the gear module
-- as XTLua runs it (tests/lib/xtlua.lua): X-Plane's brake commands as the
-- pilots' pedals, the toe brakes overridden, the parking brake lever -> valve
-- -> X-Plane's parking brake and PARK BRAKE SET, both pedals releasing the
-- lever, the brake source's pressure, X-Plane's parking brake commands, the
-- antiskid and the chocks. The model is tested in brake_model_test.lua.
local T = dofile("tests/lib/check.lua")("brakes_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.xt.gear.lua")
local L, R, PARK = "sim/cockpit2/controls/left_brake_ratio", "sim/cockpit2/controls/right_brake_ratio", "sim/cockpit2/controls/parking_brake_ratio"
local LEVER = "laminar/B747/flt_ctrls/parking_brake_ratio"
rt:set("laminar/B747/hydraulics/brake_source", 4)
rt:set("laminar/B747/hydraulics/brake_psi", 3000)
rt:set("laminar/B747/electrical/bus/bat_main", 1)
for i = 0, 3 do rt:set("laminar/B747/electrical/bus/dc", i, 1) end
rt:callout("flight_start")
local function run(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end
local function cmd(name, phase) rt.commands["sim/flight_controls/" .. name].handler(phase, 0) end

run(3.5)
T.equal(rt:get(PARK), 1, "a cold and dark start: chocked")
rt:set("laminar/B747/gear/chocked", 0)
run(0.1)
T.equal(rt:get(PARK), 0, "chocks away, the lever off: no parking brake")
T.equal(rt:get("sim/operation/override/override_toe_brakes"), 1, "the toe brakes overridden")
T.equal(rt:get(L), 0, "no pedals")

-- regular brakes held: both pedals at 0.5 in 0.25 s (estimate); let go
cmd("brakes_regular", 0)
run(0.4)
T.near(rt:get(L), 0.5, 1e-6, "brakes_regular: left 0.5")
T.near(rt:get(R), 0.5, 1e-6, "and right")
cmd("brakes_regular", 2)
run(0.4)
T.equal(rt:get(L), 0, "let go: 0")
cmd("left_brake", 0)
run(0.4)
T.equal(rt:get(L), 1, "left_brake: left 1")
T.equal(rt:get(R), 0, "right 0")
cmd("left_brake", 2)
run(0.4)

-- the parking brake: lever -> valve (1 s) -> the hold and PARK BRAKE SET
rt:set(LEVER, 1)
run(0.5)
T.equal(rt:get("laminar/B747/CAS/memo_status", 26), 0, "0.5 s: the valve closing, no memo")
run(0.7)
T.equal(rt:get("laminar/B747/gear/brakes/park_valve"), 1, "the valve closed")
T.equal(rt:get(PARK), 1, "X-Plane's parking brake: 3000 psi trapped")
T.equal(rt:get("laminar/B747/CAS/memo_status", 26), 1, "PARK BRAKE SET")
-- both pedals (brakes_max) release the lever (FCOM p.1516)
cmd("brakes_max", 0)
run(0.5)
T.equal(rt:get(LEVER), 0, "both pedals: the lever released")
cmd("brakes_max", 2)
run(1.2)
T.equal(rt:get(PARK), 0, "the valve open: no parking brake")
T.equal(rt:get("laminar/B747/CAS/memo_status", 26), 0, "no memo")
-- X-Plane's parking brake command moves the 747's lever
rt.commands["sim/flight_controls/park_brake_toggle"].handler(0, 0)
run(0.1)
T.equal(rt:get(LEVER), 1, "park_brake_toggle: the lever set")
rt.commands["sim/flight_controls/park_brake_release"].handler(0, 0)
run(1.2)
T.equal(rt:get(LEVER), 0, "park_brake_release: off")

-- the accumulator at 1500 psi: half the torque
rt:set("laminar/B747/hydraulics/brake_source", 0)
rt:set("laminar/B747/hydraulics/brake_psi", 1500)
cmd("brakes_toggle_max", 0)
run(0.4)
T.near(rt:get(L), 0.5, 1e-6, "brakes_toggle_max on the accumulator at 1500 psi: 0.5")
cmd("brakes_toggle_max", 0)
run(0.4)
T.equal(rt:get(L), 0, "toggled off")

-- the antiskid: the normal antiskid failed on the normal brakes
rt:set("laminar/B747/hydraulics/brake_source", 4)
rt:set("laminar/B747/hydraulics/brake_psi", 3000)
rt:set("laminar/B747/gear/fail/antiskid", 0, 1)
run(0.1)
T.equal(rt:get("laminar/B747/CAS/advisory_status", 10), 1, "ANTISKID")
T.equal(rt:get("sim/aircraft/gear/acf_has_abs"), 0, "X-Plane's antiskid off")
rt:set("laminar/B747/gear/fail/antiskid", 0, 0)
run(0.1)
T.equal(rt:get("sim/aircraft/gear/acf_has_abs"), 1, "back on")
-- the autobrakes (4-2 step 3): X-Plane's own stay off; its commands move the
-- selector; armed on the ground at idle with the captain's IRS; applied on the
-- ground over 60 kt for 3 s; the pedals disarm
T.equal(rt:get("sim/cockpit2/switches/auto_brake_level"), 1, "X-Plane's autobrakes off")
rt:set("laminar/B747/flt_mgmt/iru/status", 0, 2)
rt:set("laminar/B747/flt_mgmt/iru/mode_sel_dial_pos", 0, 2)
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
rt:set("laminar/B747/hydraulics/pressure_4", 3000)
for i = 0, 4 do rt:set("sim/flightmodel2/gear/on_ground", i, 1) end
for i = 1, 4 do rt:set("sim/flightmodel2/gear/eagle_claw_angle_deg", i, 0.9) end
rt.commands["sim/flight_controls/brakes_3_auto"].handler(0, 0)
run(0.2)
T.equal(rt:get("laminar/B747/gear/autobrakes/sel_dial_pos"), 5, "brakes_3_auto: AUTOBRAKES 3")
T.equal(rt:get("laminar/B747/CAS/memo_status", 4), 1, "armed: the memo AUTOBRAKES 3")
rt:set("sim/flightmodel/position/groundspeed", 40)            -- 78 kt, not slowing
run(2.5)
T.equal(rt:get(L), 0, "2.5 s over 60 kt: not spun up yet")
run(4)
local l = rt:get(L)
T.check(l > 0.3 and l <= 1750 / 3000 + 1e-6, "applying, within its 1750 psi (" .. l .. ")")
cmd("brakes_max", 0)
run(0.3)
T.equal(rt:get("laminar/B747/gear/autobrakes/sel_dial_pos"), 2, "the pedals: DISARM")
T.equal(rt:get("laminar/B747/CAS/advisory_status", 17), 1, "AUTOBRAKES")
T.equal(rt:get("laminar/B747/CAS/memo_status", 4), 0, "no memo")
cmd("brakes_max", 2)

-- the chocks hold
rt:set("laminar/B747/gear/chocked", 1)
run(0.1)
T.equal(rt:get(PARK), 1, "chocked: X-Plane's parking brake")
T.done()
