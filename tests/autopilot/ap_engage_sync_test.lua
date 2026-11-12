-- Run from the repository root with LuaJIT: luajit tests/autopilot/ap_engage_sync_test.lua
-- (2026-11-12 review AFDS-5) The A/P's engagement and the pitch law's
-- command: the pitch attitude integrator synchronizes to the pitch attitude
-- while the A/P is disengaged (ATA22 p.332), so an engagement starts from
-- the attitude. Before, the law's command, an integrator, wound up during
-- F/D-only flight nobody followed (30 s of V/S +1,000: 6 degrees above the
-- attitude) and the engagement flew to it (1.83 g in X-Plane). The F/D's
-- bars themselves are not changed. Through the real glue
-- (B747.70.xt.autopilot.lua) on the XTLua mock.
local xtlua = dofile("tests/lib/xtlua.lua")
local T = dofile("tests/lib/check.lua")("ap_engage_sync")
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local CMD = "laminar/B747/autopilot/button_switch/"
local rt = xtlua.new()
rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 5000)
for i = 1, 3 do rt:set("laminar/B747/hydraulics/pressure_" .. i, 3000) end
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/electrical/bus/bat_main", 1)
rt:set("laminar/B747/electrical/bus/xfr_fo", 1)
for i = 0, 2 do
    rt:set("laminar/B747/irs/att_valid", i, 1)
    rt:set("laminar/B747/airdata/valid", i, 1)
    rt:set("laminar/B747/irs/hdg_valid", i, 1)
    rt:set("laminar/B747/irs/nav_valid", i, 1)
end
for i = 0, 1 do
    rt:set("laminar/B747/flt_ctrls/stab_trim/autotrim_valid", i, 1)
    rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", i, 1)
    rt:set("laminar/B747/fms/fmc_ok", i, 1)
end
-- level at 5,200 ft, 250 kt, pitch 2 degrees
rt:set("sim/cockpit2/gauges/indicators/vvi_fpm_pilot", 0)
rt:set("sim/flightmodel/position/vh_ind_fpm", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 5200)
rt:set("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot", 2)
rt:set("sim/cockpit2/gauges/indicators/true_airspeed_kts_pilot", 270)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 250)
rt:callout("flight_start")
local function frames(n, dt) for _ = 1, n do rt:frame(dt or 1 / 30) end end
frames(30)
local PC = "laminar/B747/autopilot/pitch_cmd"
local SERVOS = "laminar/B747/autopilot/servos_on"

-- F/D L on in the air: V/S (synced to 0) and HDG HOLD; the crew selects
-- V/S +1,000 on the MCP and does not follow the bars
rt:set("laminar/B747/toggle_switch/position", 23, 1)
frames(5)
T.equal(rt:get("laminar/B747/autopilot/FMA/active_pitch_mode"), 7, "F/D L on in the air: V/S")
rt:set("sim/cockpit2/autopilot/vvi_dial_fpm", 1000)
frames(30 * 30)
T.check(rt:get(PC) > 6, string.format("30 s of V/S +1,000 not followed: the F/D's command wound up to %.2f (the attitude 2)", rt:get(PC)))
-- CMD L: the A/P engaged; the law starts from the attitude
rt:command(CMD .. "cmd_L")
frames(1)
T.equal(rt:get(SERVOS), 1, "CMD L: the A/P engaged")
T.near(rt:get(PC), 2, 0.5, "the frame after the engagement: the command at the attitude (ATA22 p.332)")
-- then the law flies the mode from there at its own rate (0.05 g)
frames(30)
local c1 = rt:get(PC)
T.check(c1 > 2 and c1 < 4, string.format("1 s later: %.2f, on its way up from the attitude", c1))

-- a second channel engaging (multi-channel) does not sync again
rt:set("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot", 3)
frames(30)
local c2 = rt:get(PC)
rt:command(CMD .. "cmd_C")
frames(1)
T.check(math.abs(rt:get(PC) - c2) < 0.2, string.format("CMD C with CMD L engaged: the command goes on (%.2f from %.2f)", rt:get(PC), c2))

T.done()
