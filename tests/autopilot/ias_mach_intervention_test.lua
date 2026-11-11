-- Run from the repository root with LuaJIT: luajit tests/autopilot/ias_mach_intervention_test.lua
-- (2026-11-11 review) the IAS/MACH window's change of units by itself in
-- VNAV's speed intervention (FCOM p.643, 4.10.5: in climb from IAS to Mach at
-- about .840 Mach, in descent from Mach to IAS at about 310 knots; the
-- selector's push with VNAV active opens the window, its speed flown), in
-- the autopilot module as XTLua runs it (tests/lib/xtlua.lua). Before, only
-- with VNAV off or armed: in the intervention the window stayed in IAS
-- climbing through M.86. The mock does not convert the target between knots
-- and Mach as X-Plane does: the test sets the knots X-Plane would give.
local T = dofile("tests/lib/check.lua")("ias_mach_intervention")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local CMD = "laminar/B747/autopilot/button_switch/"
local VNAV_STATE = "laminar/B747/autopilot/vnav_state"
local RA = "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot"
local ALT_IND, VSI = "sim/cockpit2/gauges/indicators/altitude_ft_pilot", "sim/flightmodel/position/vh_ind_fpm"
local VVI = "sim/cockpit2/gauges/indicators/vvi_fpm_pilot"
local MCP_ALT = "laminar/B747/autopilot/heading/altitude_dial_ft"
local IS_MACH = "sim/cockpit2/autopilot/airspeed_is_mach"
local DIAL = "laminar/B747/autopilot/ias_dial_value"
local KTS = "sim/cockpit2/autopilot/airspeed_dial_kts"
local OPEN = "laminar/B747/autopilot/ias_mach/window_open"
local SPD_INT = "laminar/B747/autopilot/spd_intervention"

local rt = xtlua.new()
rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set(RA, 300)
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
rt:set(ALT_IND, 1500)
rt:callout("flight_start")
local function frames(n) for _ = 1, n or 3 do rt:frame(1 / 30) end end
frames(30)
local FVN = "laminar/B747/fms/vnav/"
local function fvn(t) for k, v in pairs(t) do rt:set(FVN .. k, v) end end
rt:set("laminar/B747/airspeed/Vmo", 365)
rt:set("laminar/B747/airspeed/Mms", 0.92)
rt:command(CMD .. "cmd_C")
frames()
-- the climb in VNAV SPD to FL370
fvn({perf = 1, valid = 1, phase = 1, mode = 1, cas = 310, mach = 0.84, mach_mode = 0, alt = 37000,
    vs = 0, path_dev = 0, at = 5, td_hold = 0, on_app = 0})
rt:set(MCP_ALT, 37000)
rt:set(RA, 9000)
rt:set(ALT_IND, 20000)
rt:set(VSI, 2000)
rt:command(CMD .. "VNAV")
frames(10)
T.equal(rt:get(VNAV_STATE), 2, "VNAV engaged")
-- speed intervention: the IAS/MACH selector pushed, 320 kt set
rt:command("laminar/B747/button_switch/press_airspeed")
frames(10)
T.check(rt:get(OPEN) == 1 and rt:get(SPD_INT) == 1, "the selector pushed: the window open, speed intervention")
rt:set(IS_MACH, 0)
rt:set(DIAL, 320)
rt:set("laminar/B747/autopilot/ap_monitor/switchingIASMode", 0)
frames(5)

-- 1. climbing through M.840 at FL320 (320 kt, M.86): the window in Mach,
-- the intervention on
rt:set(ALT_IND, 32000)
rt:set("sim/flightmodel2/position/pressure_altitude", 32000)
rt:set("sim/flightmodel/misc/machno", 0.86)
rt:set(VVI, 1500)
frames(30)
T.equal(rt:get(VNAV_STATE), 2, "VNAV still engaged")
T.equal(rt:get(IS_MACH), 1, "climbing through M.840 in speed intervention: the window in Mach (before: IAS)")
T.check(rt:get(OPEN) == 1 and rt:get(SPD_INT) == 1, "the window open again, the intervention on")

-- 2. descending at 330 kt's Mach (more than 310 kt): the window in IAS
rt:set(KTS, 330)                -- X-Plane's knots of the Mach target
rt:set("sim/flightmodel/misc/machno", 0.80)
rt:set(VVI, -1500)
frames(30)
T.equal(rt:get(IS_MACH), 0, "descending with more than 310 kt in speed intervention: the window in IAS")
T.check(rt:get(OPEN) == 1 and rt:get(SPD_INT) == 1, "the window open, the intervention on")

-- 3. the window closed (the FMC's speed): the units left to the FMC's target
rt:command("laminar/B747/button_switch/press_airspeed")
frames(10)
T.check(rt:get(OPEN) == 0 and rt:get(SPD_INT) == 0, "pushed again: the window blank, no intervention")
rt:set("sim/flightmodel/misc/machno", 0.86)
rt:set(VVI, 1500)
local before = rt:get(IS_MACH)
frames(30)
T.equal(rt:get(IS_MACH), before, "the window blank: no change of units by itself")
T.done()
