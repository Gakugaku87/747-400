-- Run from the repository root with LuaJIT: luajit tests/autopilot/flch_repush_test.lua
-- (2026-11-13) The FL CH switch pushed again in FLCH: the A/T in THR (FCOM
-- p.646: each push selects FLCH SPD and the A/T operates in THR, then HOLD
-- in a descent). Before, the A/T model engaged only on a change of the
-- pitch mode: in FLCH's descent HOLD, a new MCP altitude above and the push
-- kept the levers at idle while the pitch climbed for the speed (s331).
-- Through the real glue (B747.70.xt.autopilot.lua) on the XTLua mock; the
-- levers follow the A/T's command (the EEC's).
local xtlua = dofile("tests/lib/xtlua.lua")
-- (2026-11-13) the IRU's inertial V/S is X-Plane's vertical velocity
-- (local_vy, m/s: B747_afds_ivs); before, its vh_ind_fpm (fpm)
local FPM = 196.850394
local T = dofile("tests/lib/check.lua")("flch_repush")
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local CMD = "laminar/B747/autopilot/button_switch/"
local PITCH = "laminar/B747/autopilot/FMA/active_pitch_mode"
local AT_FMA = "laminar/B747/autopilot/FMA/autothrottle_mode"
local LEVER_CMD = "laminar/B747/autothrottle/lever_cmd"
local MCP_X, MCP = "laminar/B747/autopilot/altitude_dial_ft", "laminar/B747/autopilot/heading/altitude_dial_ft"

local rt = xtlua.new()
rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 2500)
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
-- level at FL350, 280 kt; the engines running, the A/T's ARM switch on
rt:set("laminar/B747/airdata/alt_capt", 35000)
rt:set("sim/flightmodel/position/local_vy", 0 / FPM)
rt:set("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot", 2)
-- (2026-11-13) the TAS 480 kt: the FCC's ADC's Mach at 15 degrees C (B747_afds_tas)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15)
rt:set("laminar/B747/airdata/mach_capt", 480 / 661.47)
rt:set("laminar/B747/airdata/mach_fo", 480 / 661.47)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 280)
rt:set("sim/flightmodel/misc/machno", 0.84)
rt:set("laminar/B747/airspeed/Vmo", 365)
for e = 0, 3 do
    rt:set("laminar/B747/engines/display_N1", e, 90)
    rt:set("laminar/B747/engine/throttle", e, 0.5)
end
rt:set("laminar/B747/engines/autothrottle_fail", 0)
rt:callout("flight_start")
rt:set(MCP_X, 30000)
rt:set(MCP, 30000)
rt:set("laminar/B747/autothrottle/armed", 1)
local function frames(n)
    for _ = 1, n do
        rt:frame(1 / 30)
        local c = rt:get(LEVER_CMD)
        for e = 0, 3 do rt:set("laminar/B747/engine/throttle", e, c) end
    end
end
frames(30)
rt:command(CMD .. "cmd_L")
frames(5)
T.equal(rt:get("laminar/B747/autopilot/servos_on"), 1, "CMD L: the A/P engaged")

-- FL CH down to FL300: THR, the levers to the aft stop, HOLD
rt:command(CMD .. "flch_mode")
frames(3)
T.equal(rt:get(PITCH), 8, "FLCH SPD")
T.equal(rt:get(AT_FMA), 4, "the A/T's THR (FCOM p.646)")
local held
for i = 1, 30 * 60 do
    frames(1)
    if rt:get(AT_FMA) == 1 then held = i / 30; break end
end
T.check(held ~= nil, "the levers at the aft stop: HOLD (after " .. tostring(held and math.floor(held)) .. " s)")
T.check(rt:get(LEVER_CMD) <= 0.001, string.format("the levers at idle (%.3f)", rt:get(LEVER_CMD)))

-- a new MCP altitude above (FL360) and the FL CH switch again: THR, the
-- levers up for the climb
rt:set(MCP_X, 36000)
rt:set(MCP, 36000)
frames(3)
T.equal(rt:get(AT_FMA), 1, "the MCP altitude turned, no push: HOLD")
rt:command(CMD .. "flch_mode")
frames(3)
T.equal(rt:get(PITCH), 8, "FLCH SPD still")
T.equal(rt:get(AT_FMA), 4, "the push again in FLCH: THR (before: HOLD)")
frames(30 * 5)
local l5 = rt:get(LEVER_CMD)
T.check(l5 > 0.01, string.format("5 s later the levers up from idle for 1,000 ft up (%.3f)", l5))
frames(30 * 5)
T.check(rt:get(LEVER_CMD) > l5, string.format("and on up (%.3f at 10 s)", rt:get(LEVER_CMD)))

T.done()
