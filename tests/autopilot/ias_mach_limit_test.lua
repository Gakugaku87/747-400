-- Run from the repository root with LuaJIT: luajit tests/autopilot/ias_mach_limit_test.lua
-- (2026-11-06, the perf kit's report: PERF_SIMBRIEF phase 0) the MCP's Mach
-- in the autopilot module as XTLua runs it (tests/lib/xtlua.lua):
--  - the window's Mach is the command speed, and the maximum speed only
--    limits it (FCOM p.642, p.675). Before, once the target was at the
--    limit (Vmo - 10 kt) a lower Mach was never taken again;
--  - the in-flight set-up's speed (kt) is wound into the window as a Mach
--    with the MCP in Mach. Before, in knots: 291 kt became M2.91.
local T = dofile("tests/lib/check.lua")("ias_mach_limit")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local I = "sim/cockpit2/gauges/indicators/"
local DIAL = "laminar/B747/autopilot/ias_dial_value"
local KTS, MACH = "sim/cockpit2/autopilot/airspeed_dial_kts", "sim/cockpit2/autopilot/airspeed_dial_kts_mach"

local rt = xtlua.new()
rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set(I .. "radio_altimeter_height_ft_pilot", 2500)
-- in cruise at FL350, M.85 (291 kt), level: Vmo as the flight instruments
-- make it there (B747.60.xt.fltInst02.lua: 365 kt at 28,620 ft to 252.35 at
-- 45,000), the limit Vmo - 10 = 311.1 kt (M.902)
rt:set(I .. "altitude_ft_pilot", 35000)
rt:set("sim/flightmodel2/position/pressure_altitude", 35000)
rt:set(I .. "airspeed_kts_pilot", 291)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 291)
rt:set("sim/flightmodel/misc/machno", 0.85)
rt:set(I .. "vvi_fpm_pilot", 0)
rt:set("laminar/B747/airspeed/Vmo", 321.1)
rt:set("laminar/B747/airspeed/Mms", 0.92)
rt:set("laminar/B747/airspeed/Vmc", 200)
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/fms/fmc_ok", 0, 1)
rt:set("laminar/B747/fms/fmc_ok", 1, 1)
rt:callout("flight_start")
local function frames(n) for _ = 1, n or 3 do rt:frame(1 / 30) end end
frames(30)
rt:set("sim/cockpit2/autopilot/airspeed_is_mach", 1)
rt:set("laminar/B747/autopilot/ap_monitor/switchingIASMode", 0)

-- above the limit: the limit
rt:set(DIAL, 91)
frames(5)
T.near(rt:get(KTS), 311.1, 0.01, "M.91 (315 kt) above Vmo - 10: the target the limit, 311.1 kt")
T.near(rt:get("laminar/B747/autopilot/ias_bug_value"), 311.1, 0.01, "the bug at the limit")
-- below it again: that Mach
rt:set(MACH, 0)
rt:set(DIAL, 85)
frames(5)
T.near(rt:get(MACH), 0.85, 1e-6, "M.85 below the limit: the target M.85 (before: kept at the limit)")
T.near(rt:get(KTS), 311.1, 0.01, "the knots not written again")
rt:set(DIAL, 90)
frames(5)
T.near(rt:get(MACH), 0.90, 1e-6, "M.90 (310.3 kt), just below the limit: M.90")

-- FLCH: the original's 20 kt margin
rt:set("laminar/B747/autopilot/speed_status", 1)
frames(5)
T.near(rt:get(KTS), 301.1, 0.01, "FLCH, M.90 above Vmo - 20: the limit, 301.1 kt")
rt:set(MACH, 0)
rt:set(DIAL, 85)
frames(5)
T.near(rt:get(MACH), 0.85, 1e-6, "FLCH, M.85: the target M.85")
rt:set("laminar/B747/autopilot/speed_status", 0)

-- the in-flight set-up (the FMC's activate_inflightAP): the airspeed now in
-- knots, wound into the window as a Mach with the MCP in Mach
rt:set(DIAL, 80)
rt:set("laminar/B747/autopilot/speed/target", 291)
frames(30)
T.equal(rt:get(DIAL), 85, "the set-up's 291 kt in Mach: the window wound to 85 (before: toward 291, M2.91)")
T.equal(rt:get("laminar/B747/autopilot/speed/target"), -1, "the set-up's target done")
T.near(rt:get(MACH), 0.85, 1e-6, "and the target M.85")
-- in IAS, the knots as before
rt:set("sim/cockpit2/autopilot/airspeed_is_mach", 0)
rt:set(DIAL, 240)
rt:set("laminar/B747/autopilot/speed/target", 250)
frames(30)
T.equal(rt:get(DIAL), 250, "in IAS: the window wound to 250 kt")
T.done()
