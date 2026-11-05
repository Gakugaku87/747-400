-- Run from the repository root with LuaJIT: luajit tests/autopilot/old_vnav_descent_test.lua
-- (2026-11-05 review 4) the old VNAV's descent (setDescentVSpeed, B747.70.
-- xt.autopilot.vnav.lua) no longer runs with VNAV off after the T/D, in the
-- autopilot module as XTLua runs it (tests/lib/xtlua.lua). Before, every
-- 0.2 s it decoded the old profile and wrote its V/B and its own path
-- deviation (the FMC's written after it), and below 10 ft X-Plane's V/S
-- -250 with "End Descent" in the log.
local T = dofile("tests/lib/check.lua")("old_vnav_descent")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local FPE = "laminar/B747/autopilot/dist/flight_path_error"
local VS_DIAL = "sim/cockpit2/autopilot/vvi_dial_fpm"
local I = "sim/cockpit2/gauges/indicators/"

local rt = xtlua.new()
rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set(I .. "radio_altimeter_height_ft_pilot", 4000)
rt:set(I .. "altitude_ft_pilot", 15000)                  -- above the MCP's 10,000 ft
rt:set(I .. "airspeed_kts_pilot", 250)
rt:set("sim/flightmodel/position/groundspeed", 130)
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/fms/fmc_ok", 0, 1)
rt:set("laminar/B747/fms/fmc_ok", 1, 1)
-- the FMC's descent (after the T/D) 150 ft above its path, VNAV off
rt:set("laminar/B747/fms/vnav/valid", 1)
rt:set("laminar/B747/fms/vnav/phase", 3)
rt:set("laminar/B747/fms/vnav/path_dev", 150)
-- the old VNAV's inputs: 20 NM to go, its target 10 NM ahead
rt:set("laminar/B747/autopilot/dist/remaining_distance", 20)
rt:set("laminar/B747/autopilot/ap_monitor/fmstargetDistance", 10)
rt:callout("flight_start")
local function frames(n) for _ = 1, n or 3 do rt:frame(1 / 30) end end
frames(60)
T.equal(rt:get("laminar/B747/autopilot/vnav_state"), 0, "VNAV off")
T.equal(rt:get("laminar/B747/autopilot/vnav/after_tod"), 1, "after the T/D (the FMC's descent)")
T.near(rt:get(FPE), 150, 1e-6, "the ND's path deviation the FMC's")
T.equal(rt:get("laminar/B747/autopilot/navadata/vb"), 0, "the old V/B not written (before: 14 degrees)")
-- below 10 ft: X-Plane's V/S dial left alone
rt:set(VS_DIAL, 0)
rt:set(I .. "radio_altimeter_height_ft_pilot", 5)
frames(30)
T.equal(rt:get(VS_DIAL), 0, "below 10 ft: X-Plane's V/S not set to -250 (before)")
local ended = false
for _, line in ipairs(rt.log) do
    if line:find("End Descent", 1, true) then ended = true end
end
T.check(not ended, "no \"End Descent\" in the log")
T.done()
