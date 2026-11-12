-- Run from the repository root with LuaJIT: luajit tests/gear/autobrake_irs_test.lua
-- (2026-11-12 review FG-6; REVIEW_2026-11-12.md case 25) The autobrakes'
-- reference is the IRU the captain selects (FCOM p.1044 (10.10.82): "IRU
-- selected by Captain provides autobrake reference"). With IRU L failed
-- and the captain's IRS source selector on C (IRU C in NAV), the selector
-- set to 3 stays there, no AUTOBRAKES. Before, IRU L always: the selector
-- sprang to DISARM and AUTOBRAKES came up, RTO could not arm.
local T = dofile("tests/lib/check.lua")("autobrake_irs")
local xtlua = dofile("tests/lib/xtlua.lua")
local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.xt.gear.lua")
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("laminar/B747/hydraulics/brake_source", 4)
rt:set("laminar/B747/hydraulics/brake_psi", 3000)
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
rt:set("laminar/B747/hydraulics/pressure_4", 3000)
rt:set("laminar/B747/electrical/bus/bat_main", 1)
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
end
for i = 0, 4 do
    rt:set("sim/flightmodel2/gear/deploy_ratio", i, 1)
    rt:set("sim/flightmodel2/gear/on_ground", i, 1)
    rt:set("sim/flightmodel2/gear/eagle_claw_angle_deg", i, -1)
end
local function run(s) for _ = 1, math.floor(s * 50 + 0.5) do rt:frame(0.02) end end
local DIAL = "laminar/B747/gear/autobrakes/sel_dial_pos"
local ADV = "laminar/B747/CAS/advisory_status"
rt:callout("flight_start")
-- in the air on the approach: the trucks tilted, the gear down
for i = 1, 4 do rt:set("sim/flightmodel2/gear/eagle_claw_angle_deg", i, i <= 2 and 8 or 58) end
for i = 0, 4 do rt:set("sim/flightmodel2/gear/on_ground", i, 0) end
for i = 0, 2 do
    rt:set("laminar/B747/flt_mgmt/iru/status", i, 2)
    rt:set("laminar/B747/flt_mgmt/iru/mode_sel_dial_pos", i, 2)
end
run(4)
rt:set(DIAL, 5)
run(1)
T.equal(rt:get(DIAL), 5, "every IRU in NAV, the captain's IRS on L: autobrakes 3 stays")
rt:set(DIAL, 1)
run(0.5)
rt:set("laminar/B747/flt_mgmt/iru/status", 0, 5)               -- IRU L failed
rt:set("laminar/B747/flt_inst/irs_src/capt/sel_dial_pos", 1)    -- the captain's IRS source to C
run(1)
rt:set(DIAL, 5)
run(1)
T.equal(rt:get(DIAL), 5, "IRU L failed, the captain's IRS on C (in NAV): autobrakes 3 stays (FCOM p.1044)")
T.equal(rt:get(ADV, 17), 0, "and no AUTOBRAKES")
rt:set("laminar/B747/flt_inst/irs_src/capt/sel_dial_pos", 0)    -- back to the failed L
run(1)
T.check(rt:get(DIAL) ~= 5, "the captain's IRS back on the failed L: autobrakes disarmed")
T.done()
