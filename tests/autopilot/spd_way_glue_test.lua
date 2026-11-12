-- Run from the repository root with LuaJIT: luajit tests/autopilot/spd_way_glue_test.lua
-- The speed law's way through the glue (2026-11-12; docs/overhaul/notes/
-- ATA-22.md §62): the autopilot module as XTLua runs it (tests/lib/
-- xtlua.lua) gives B747.70.afds_pitch_model.lua its `way` and `way_fpm`, so
-- that VNAV SPD and FLCH SPD do not go past near level for a speed change
-- against their way. The FMC's VNAV (laminar/B747/fms/vnav/*) is set here;
-- the airplane does not answer the command, its speed is moved by hand (a
-- kt/s), and the command's way over a second is what is checked:
--  - VNAV SPD's climb (the FMC's phase 1) 68 kt under its target, the
--    user's flight (272 kt for 340 at 10,000 ft): climbing 1,500 fpm the
--    command down for the speed at the law's own rate; at 600 fpm down to
--    near level, slower; at 100 fpm and gaining 0.5 kt/s held (before, down
--    at the law's rate: the airplane went down 300 ft); the speed not
--    gaining there, on down to level flight and held there;
--  - VNAV SPD in the descent (speed intervention: the FMC's phase 3) 50 kt
--    over its target: descending 2,000 fpm the command up; at 100 fpm of
--    descent and slowing held (before, up: a climb); the early descent's
--    V/S (-1,250, no driftdown) is not the near-level rate;
--  - the FMC's driftdown (its dd, its V/S -300: FCOM p.1268, the rate of
--    descent decreases to a minimum of 300 fpm): at 100 fpm of descent the
--    command down to its 300 fpm, held there;
--  - FLCH by the MCP altitude: above, held near level; below, down.
local T = dofile("tests/lib/check.lua")("spd_way_glue")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local CMD = "laminar/B747/autopilot/button_switch/"
local PITCH = "laminar/B747/autopilot/FMA/active_pitch_mode"
local PITCH_CMD = "laminar/B747/autopilot/pitch_cmd"
local PITCH_TARGET = "laminar/B747/autopilot/pitch_target"
local RA = "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot"
local ALT_IND, VSI = "sim/cockpit2/gauges/indicators/altitude_ft_pilot", "sim/flightmodel/position/vh_ind_fpm"
local IAS = "laminar/B747/gauges/indicators/airspeed_kts_pilot"
local TAS = "sim/cockpit2/gauges/indicators/true_airspeed_kts_pilot"
local MCP_ALT, SIM_ALT = "laminar/B747/autopilot/heading/altitude_dial_ft", "laminar/B747/autopilot/altitude_dial_ft"
local PUSH = "laminar/B747/button_switch/press_altitude"

local rt = xtlua.new()
rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set(RA, 9000)
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
local ATV = "laminar/B747/flt_ctrls/stab_trim/autotrim_valid"
rt:set(ATV, 0, 1)
rt:set(ATV, 1, 1)
rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", 0, 1)
rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", 1, 1)
rt:set("laminar/B747/fms/fmc_ok", 0, 1)
rt:set("laminar/B747/fms/fmc_ok", 1, 1)
rt:set(ALT_IND, 10000)
rt:set("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot", 5)
rt:set(TAS, 316)
rt:callout("flight_start")
local ias = 272
rt:set(IAS, ias)
-- n frames, the speed moved `rate` kt/s
local function frames(n, rate)
    for _ = 1, n or 3 do
        ias = ias + (rate or 0) / 30
        rt:set(IAS, ias)
        rt:frame(1 / 30)
    end
end
-- the command's change over a second, after 8 s for the rates' filters (a
-- vertical speed set anew is a step to them)
local function moved(rate)
    frames(240, rate)
    local c = rt:get(PITCH_CMD)
    frames(30, rate)
    return rt:get(PITCH_CMD) - c
end
frames(30)

local FVN = "laminar/B747/fms/vnav/"
local function fvn(t) for k, v in pairs(t) do rt:set(FVN .. k, v) end end
for i = 0, 3 do rt:set("laminar/B747/engines/display_N1", i, 90) end
rt:set("laminar/B747/engines/autothrottle_fail", 0)
rt:set("laminar/B747/toggle_switch/position", 29, 1)
rt:set("laminar/B747/autothrottle/armed", 1)
rt:set("laminar/B747/airspeed/Vmo", 365)
rt:command(CMD .. "cmd_C")
frames()

-- VNAV SPD's climb: the FMC's 340 kt, the airplane at 272 kt and 10,000 ft
fvn({perf = 1, valid = 1, phase = 1, mode = 1, cas = 340, mach = 0.6, mach_mode = 0, alt = 35000,
    vs = 0, path_dev = 0, at = 5, td_hold = 0, on_app = 0, dd = 0})
rt:set(MCP_ALT, 35000)
rt:set(VSI, 1500)
rt:command(CMD .. "VNAV")
frames(30)
T.equal(rt:get(PITCH), 4, "VNAV SPD")
T.near(rt:get(PITCH_TARGET), 340, 0.5, "the speed law's target the FMC's 340 kt")
-- the law's own rate: 0.1 g at 316 kt of TAS, 0.345 degree a second; near
-- level's step for the speed's gain: a quarter of 0.18 degree a second
local d = moved(0)
T.check(d < -0.3, string.format("VNAV SPD's climb at 1,500 fpm, 68 kt under: the command down at the law's own rate (%.3f in a second)", d))
rt:set(VSI, 100)
d = moved(0.5)
T.check(math.abs(d) < 0.01, string.format("at 100 fpm and gaining 0.5 kt/s: held (%.3f; before, down 0.35)", d))
d = moved(0)
T.check(d < -0.02 and d > -0.06, string.format("the speed not gaining there: on down to level flight, slowly (%.3f)", d))
rt:set(VSI, 0)
d = moved(0)
T.check(math.abs(d) < 0.01, string.format("level and not gaining: held, no altitude for the speed (%.3f)", d))
rt:set(VSI, 600)
d = moved(0.5)
T.check(d < -0.1 and d > -0.3, string.format("at 600 fpm: down to near level, slower than the law's own rate (%.3f)", d))

-- VNAV SPD in the descent (speed intervention): the FMC's 250 kt, the
-- airplane 50 kt over it
ias = 300
rt:set(MCP_ALT, 5000)
rt:command(PUSH)
fvn({phase = 3, mode = 1, cas = 250, alt = 5000, at = 2})
rt:set(VSI, -2000)
frames(30)
T.equal(rt:get(PITCH), 4, "VNAV SPD in the descent")
T.near(rt:get(PITCH_TARGET), 250, 0.5, "the target the FMC's 250 kt")
d = moved(0)
T.check(d > 0.3, string.format("descending 2,000 fpm, 50 kt over: the command up at the law's own rate (%.3f)", d))
rt:set(VSI, -100)
d = moved(-0.5)
T.check(math.abs(d) < 0.01, string.format("at 100 fpm of descent and slowing 0.5 kt/s: held (%.3f; before, up 0.35: a climb)", d))
-- the early descent (VNAV SPD with THR to the FMC's -1,250 fpm, no
-- driftdown): its V/S is not the near-level rate; at 600 fpm of descent
-- and slowing, up to near level (with it for the rate, down to 1,250)
fvn({vs = -1250, at = 4})
rt:set(VSI, -600)
d = moved(-0.5)
T.check(d > 0.1 and d < 0.3, string.format("the early descent at 600 fpm, slowing: up to near level, not down to its 1,250 fpm (%.3f)", d))
fvn({vs = 0, at = 2})

-- the FMC's driftdown (the cruise phase's VNAV SPD with THR, its dd and
-- its V/S -300): 100 fpm of descent is under its least rate
ias = 300
fvn({phase = 2, mode = 1, cas = 250, alt = 5000, at = 4, vs = -300, dd = 1})
rt:set(VSI, -100)
frames(30)
T.equal(rt:get(PITCH), 4, "the driftdown: VNAV SPD")
d = moved(-0.5)
T.check(d < -0.05 and d > -0.2, string.format("the driftdown at 100 fpm of descent, slowing: down to its 300 fpm (%.3f; FCOM p.1268)", d))
rt:set(VSI, -300)
d = moved(-0.5)
T.check(math.abs(d) < 0.01, string.format("at 300 fpm of descent: held (%.3f)", d))
fvn({dd = 0, at = 2, vs = 0, phase = 3})

-- FLCH by the MCP altitude it flies to: above, 28 kt under the MCP speed
-- at 100 fpm and gaining: held; below: down for the speed as before
ias = 272
rt:set(IAS, ias)
rt:set(MCP_ALT, 20000)
rt:set(SIM_ALT, 20000)
rt:set(VSI, 100)
rt:command(CMD .. "flch_mode")
frames(30)
T.equal(rt:get(PITCH), 8, "FLCH SPD")
rt:set("laminar/B747/autopilot/ias_dial_value", 300)
frames(30)
T.near(rt:get(PITCH_TARGET), 300, 0.5, "the target the MCP's 300 kt")
d = moved(0.5)
T.check(math.abs(d) < 0.01, string.format("FLCH up to the MCP altitude at 100 fpm, gaining: held (%.3f)", d))
rt:set(MCP_ALT, 5000)
rt:set(SIM_ALT, 5000)
d = moved(0.5)
T.check(d < -0.1, string.format("the MCP altitude below: down for the speed (%.3f)", d))
T.equal(rt:get(PITCH), 8, "FLCH SPD still")
T.done()
