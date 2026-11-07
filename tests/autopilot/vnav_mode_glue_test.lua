-- Run from the repository root with LuaJIT: luajit tests/autopilot/vnav_mode_glue_test.lua
-- VNAV's engagement and sub-modes (6-1/6-2 step 9i; notes/ATA-34-61-FMC.md
-- §150) in the autopilot module as XTLua runs it (tests/lib/xtlua.lua),
-- B747.70.vnav_mode_model.lua through the glue, the FMC's VNAV
-- (laminar/B747/fms/vnav/*) set here: the arm waiting for FMC DATA VALID
-- (ATA22 p.340-341), the MCP altitude below in the climb and above in the
-- descent (VNAV ALT at the altitude then: FCOM p.665), on approach (FCOM
-- p.1261), a climb constraint below (VNAV PTH: FMSPG p.128 (3.3-19)), past the
-- T/D held by the MCP altitude (VNAV ALT: FMSPG p.34 (2-22)) until it is reset
-- and pushed, the FMC's data lost (VNAV still: its PTH level on the ALT
-- law), the A/T's SPD while levelled (FCOM p.645). The MCP altitude VNAV
-- goes by settled (3 s after the window's last change, at once with the
-- selector's push): the knob's 100 ft steps through the airplane's altitude
-- not captured nor taken as conflicts, on approach (the missed approach
-- altitude set as FCTM p.187 (5.41) has it: VNAV PTH on, FCOM p.1261) and in
-- the descent (ATC's stop just under the airplane: VNAV ALT at the knob's
-- last altitude); on approach VNAV ALT 250 ft under the MCP altitude goes on
-- down once it is 300 ft or more above (FCOM p.1261). A first patch of step
-- 9i failed these four.
local T = dofile("tests/lib/check.lua")("vnav_mode_glue")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local CMD = "laminar/B747/autopilot/button_switch/"
local PITCH = "laminar/B747/autopilot/FMA/active_pitch_mode"
local PITCH_ARMED = "laminar/B747/autopilot/FMA/armed_pitch_mode"
local AT_FMA = "laminar/B747/autopilot/FMA/autothrottle_mode"
local VNAV_STATE = "laminar/B747/autopilot/vnav_state"
local PITCH_CMD = "laminar/B747/autopilot/pitch_cmd"
local PITCH_LAW = "laminar/B747/autopilot/pitch_law"
local NOTIFY = "laminar/B747/fms/notification"
local RA = "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot"
local ALT_IND, VSI = "sim/cockpit2/gauges/indicators/altitude_ft_pilot", "sim/flightmodel/position/vh_ind_fpm"
local MCP_ALT = "laminar/B747/autopilot/heading/altitude_dial_ft"
local PUSH = "laminar/B747/button_switch/press_altitude"
local KNOB_UP = "sim/autopilot/altitude_up"

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
local ATV = "laminar/B747/flt_ctrls/stab_trim/autotrim_valid"
rt:set(ATV, 0, 1)
rt:set(ATV, 1, 1)
rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", 0, 1)
rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", 1, 1)
rt:set("laminar/B747/fms/fmc_ok", 0, 1)
rt:set("laminar/B747/fms/fmc_ok", 1, 1)
rt:set(ALT_IND, 1500)
rt:callout("flight_start")
local function frames(n) for _ = 1, n or 3 do rt:frame(1 / 30) end end
-- the MCP altitude settled: a new one waited for past VNAV's 3 s
local function settle() frames(95) end
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

-- the arm without the FMC's data (no route yet): armed, waiting (ATA22
-- p.340; before, cancelled at once), the message only for missing
-- performance data (here entered); the data valid at 300 ft: armed still
-- (400 ft: FCOM p.645); above it: VNAV SPD with THR REF, the climb
fvn({perf = 1, valid = 0, phase = 1, mode = 1, cas = 250, mach = 0.5, mach_mode = 0, alt = 35000,
    vs = 0, path_dev = 0, at = 5, td_hold = 0, on_app = 0})
rt:set(MCP_ALT, 15000)
rt:command(CMD .. "VNAV")
frames(90)
T.equal(rt:get(VNAV_STATE), 1, "no FMC data: VNAV armed, waiting 3 s on")
T.equal(rt:get(PITCH_ARMED), 4, "the FMA's VNAV armed")
T.equal(rt:get(NOTIFY, 30), 0, "the climb with the performance data: no PERF/VNAV UNAVAILABLE")
fvn({valid = 1})
frames()
T.equal(rt:get(VNAV_STATE), 1, "valid at 300 ft: armed still")
rt:set(RA, 1000)
rt:set(ALT_IND, 2000)
rt:set(VSI, 2000)
frames()
T.equal(rt:get(VNAV_STATE), 2, "above 400 ft: engaged")
T.equal(rt:get(PITCH), 4, "VNAV SPD")
T.equal(rt:get(AT_FMA), 5, "THR REF")

-- climbing, the MCP set below the airplane: VNAV ALT at the altitude then
-- once settled, the A/T SPD; set above again: still, no push; pushed: VNAV
-- SPD
rt:set(RA, 9000)
rt:set(ALT_IND, 8000)
rt:set(VSI, 1500)
frames()
rt:set(MCP_ALT, 6000)
frames()
T.equal(rt:get(PITCH), 4, "the MCP just set below: VNAV SPD still (not settled)")
settle()
T.equal(rt:get(PITCH), 5, "settled below in the climb: VNAV ALT (FCOM p.665)")
T.equal(rt:get(AT_FMA), 3, "the A/T SPD")
local c0 = rt:get(PITCH_CMD)
frames(30)
T.check(rt:get(PITCH_CMD) < c0, "climbing 1,500 fpm at the altitude it holds: the command down")
rt:set(MCP_ALT, 15000)
settle()
T.equal(rt:get(PITCH), 5, "set above, no push: VNAV ALT still")
rt:command(PUSH)
frames()
T.equal(rt:get(PITCH), 4, "pushed: VNAV SPD")
T.equal(rt:get(AT_FMA), 5, "THR REF")
-- a climb constraint below (entered, its waypoint ahead): VNAV PTH where it
-- is until the FMC altitude moves on
fvn({alt = 6000})
frames()
T.equal(rt:get(PITCH), 6, "the FMC altitude 2,000 ft below in the climb: VNAV PTH (FMSPG p.128 (3.3-19))")
T.equal(rt:get(AT_FMA), 3, "the A/T SPD")
fvn({alt = 35000})
frames()
T.equal(rt:get(PITCH), 4, "the next above: VNAV SPD")

-- the cruise at FL350 in VNAV PTH; past the T/D with the MCP at FL350 (the
-- FMC's td_hold): VNAV ALT; pushed without the reset: still; the MCP reset
-- below (the FMC's descent, its path under the airplane): still, the push
-- wanted; pushed: VNAV PTH, IDLE
rt:set(ALT_IND, 35000)
rt:set(VSI, 0)
rt:set(MCP_ALT, 35000)
fvn({phase = 2, mode = 2, alt = 35000, at = 3, mach_mode = 1, mach = 0.85})
settle()
T.equal(rt:get(PITCH), 6, "the cruise: VNAV PTH")
fvn({td_hold = 1})
frames()
T.equal(rt:get(PITCH), 5, "past the T/D held by the MCP: VNAV ALT (before: VNAV PTH)")
T.equal(rt:get(AT_FMA), 3, "the A/T SPD")
rt:command(PUSH)
frames()
T.equal(rt:get(PITCH), 5, "pushed with the MCP at FL350: VNAV ALT still")
rt:set(MCP_ALT, 10000)
fvn({td_hold = 0, phase = 3, mode = 2, alt = 10000, vs = -2500, path_dev = 600, at = 2, mach_mode = 0, cas = 290})
settle()
T.equal(rt:get(PITCH), 5, "the MCP reset below, the FMC descending: VNAV ALT, the push wanted")
rt:command(PUSH)
frames()
T.equal(rt:get(PITCH), 6, "pushed: VNAV PTH")
T.check(rt:get(AT_FMA) == 2 or rt:get(AT_FMA) == 1, "the A/T IDLE (HOLD: the levers here at the aft stop): " .. rt:get(AT_FMA))

-- the descent with the MCP altitude set above: VNAV ALT at the altitude
-- then; on approach 300 ft or more above: the descent goes on (FCOM
-- p.1261)
rt:set(ALT_IND, 20000)
rt:set(VSI, -2500)
frames()
rt:set(MCP_ALT, 24000)
settle()
T.equal(rt:get(PITCH), 5, "the MCP set above in the descent: VNAV ALT (FCOM p.665)")
rt:set(MCP_ALT, 10000)
rt:command(PUSH)
frames()
T.equal(rt:get(PITCH), 6, "reset below and pushed: VNAV PTH")
rt:set(ALT_IND, 1500)
fvn({on_app = 1, alt = 1300})
rt:set(MCP_ALT, 3000)
settle()
T.equal(rt:get(PITCH), 6, "on approach, the missed approach's 3,000 ft above: VNAV PTH, the descent on")

-- the FMC's data lost: VNAV still engaged, VNAV PTH level at the altitude
-- then on the ALT law (200 ft above it: the command down), the A/T SPD
fvn({on_app = 0})
rt:set(MCP_ALT, 1000)
rt:set(ALT_IND, 5000)
rt:set(VSI, 0)
settle()
fvn({valid = 0})
frames()
T.equal(rt:get(VNAV_STATE), 2, "not valid: VNAV still engaged (before: ALT HOLD)")
T.equal(rt:get(PITCH), 6, "VNAV PTH")
T.equal(rt:get(AT_FMA), 3, "the A/T SPD")
T.equal(rt:get(PITCH_LAW), 1, "on the pitch law")
rt:set(ALT_IND, 5200)
local c1 = rt:get(PITCH_CMD)
frames(30)
T.check(rt:get(PITCH_CMD) < c1, "200 ft above the altitude it holds: the command down")
fvn({valid = 1})
frames()
T.check(rt:get(AT_FMA) == 2 or rt:get(AT_FMA) == 1, "valid again: the FMC's IDLE (or its HOLD): " .. rt:get(AT_FMA))

-- (the knob) on approach in VNAV PTH, 1,500 ft and 800 fpm down on the
-- path, the MCP altitude at the DA (500 ft): the missed approach altitude
-- 3,000 ft set with the knob, 100 ft a click, a click a frame, through the
-- airplane's altitude (FCTM p.187 (5.41)): VNAV PTH all the way, the
-- descent on (FCOM p.1261; a first patch of step 9i captured the click at
-- 1,400 ft and held it in VNAV ALT, as steps 9a-9e did)
fvn({phase = 3, mode = 2, alt = 200, vs = -800, path_dev = 0, at = 2, on_app = 1, valid = 1})
rt:set(RA, 1500)
rt:set(ALT_IND, 1500)
rt:set(VSI, -800)
rt:set(MCP_ALT, 500)
rt:command(PUSH)
frames()
T.equal(rt:get(PITCH), 6, "on approach on the path: VNAV PTH")
local alt = 1500
local always = true
for _ = 1, 25 do
    rt:command(KNOB_UP)
    alt = alt - 800 / 60 / 30
    rt:set(ALT_IND, alt)
    frames(1)
    if rt:get(PITCH) ~= 6 then always = false end
end
T.equal(rt:get(MCP_ALT), 3000, "the knob at 3,000 ft")
T.check(always, "the knob through the airplane's altitude: VNAV PTH all the way")
for _ = 1, 95 do alt = alt - 800 / 60 / 30; rt:set(ALT_IND, alt); frames(1) end
T.equal(rt:get(PITCH), 6, "3,000 ft settled, 1,500 ft above: VNAV PTH, the descent on (FCOM p.1261)")
-- the MCP altitude settled 250 ft above on approach: VNAV ALT where the
-- airplane is (less than 300 ft above: FCOM p.1261); 350 ft above: on down
-- in VNAV PTH without the push (FCOM p.1261: VNAV continues to command a
-- descent; a first patch of step 9i held VNAV ALT until the push)
rt:set(ALT_IND, 1500)
rt:set(MCP_ALT, 1750)
settle()
T.equal(rt:get(PITCH), 5, "the MCP 250 ft above on approach: VNAV ALT")
rt:set(MCP_ALT, 1850)
settle()
T.equal(rt:get(PITCH), 6, "350 ft above: VNAV PTH, the descent on (no push)")
-- in the descent at 21,000 ft and 2,500 fpm down, the MCP altitude at
-- 10,000 ft, ATC's stop at FL205: the knob 100 ft a click a frame up to
-- 20,500, through 20,000 and the capture's distance: VNAV ALT at 20,500
-- (a first patch of step 9i captured the click at 20,000 and held it)
fvn({phase = 3, mode = 2, alt = 6000, vs = -2500, path_dev = 0, at = 2, on_app = 0})
rt:set(RA, 21000)
rt:set(ALT_IND, 21000)
rt:set(VSI, -2500)
rt:set(MCP_ALT, 10000)
rt:command(PUSH)
frames()
T.equal(rt:get(PITCH), 6, "the descent on the path: VNAV PTH")
alt = 21000
for _ = 1, 105 do
    rt:command(KNOB_UP)
    alt = alt - 2500 / 60 / 30
    rt:set(ALT_IND, alt)
    frames(1)
end
T.equal(rt:get(MCP_ALT), 20500, "the knob at 20,500 ft")
for _ = 1, 95 do
    alt = alt - 2500 / 60 / 30
    rt:set(ALT_IND, alt)
    frames(1)
end
T.check(alt > 20500, string.format("still above 20,500 ft (%.0f)", alt))
T.equal(rt:get(PITCH), 5, "settled under the airplane, captured: VNAV ALT")
-- the altitude it holds 20,500 ft, not 20,000: at 20,300 ft and level (the
-- vertical speed's filter settled first), the command up
rt:set(ALT_IND, 20300)
rt:set(VSI, 0)
frames(150)
local c2 = rt:get(PITCH_CMD)
frames(30)
T.equal(rt:get(PITCH), 5, "VNAV ALT still")
T.check(rt:get(PITCH_CMD) > c2, string.format("200 ft under the 20,500 ft it holds: the command up (%.2f from %.2f)", rt:get(PITCH_CMD), c2))
-- (2026-11-07, the step's review's finding 4) VNAV armed, waiting for the
-- FMC's data (the MCP's speed flown): the IAS/MACH window changes its units
-- by itself as with VNAV off (FCOM p.643, 4.10.4: climbing through about
-- .840, to Mach). Before, only with VNAV off, and step 9i's arm can last
local IS_MACH = "sim/cockpit2/autopilot/airspeed_is_mach"
local DIAL = "laminar/B747/autopilot/ias_dial_value"
local VVI = "sim/cockpit2/gauges/indicators/vvi_fpm_pilot"
rt:command(CMD .. "vs_mode")
frames()
fvn({valid = 0, phase = 1, mode = 1, alt = 35000})
rt:set(MCP_ALT, 35000)
rt:command(CMD .. "VNAV")
frames(5)
T.equal(rt:get(VNAV_STATE), 1, "V/S, the FMC's data lost, VNAV pushed: armed, waiting")
rt:set(IS_MACH, 0)
rt:set(DIAL, 310)
rt:set(ALT_IND, 32000)
rt:set("sim/flightmodel2/position/pressure_altitude", 32000)
rt:set("sim/flightmodel/misc/machno", 0.842)
rt:set(VVI, 600)
rt:set("laminar/B747/autopilot/ap_monitor/switchingIASMode", 0)
frames(15)
T.equal(rt:get(VNAV_STATE), 1, "armed still")
T.equal(rt:get(IS_MACH), 1, "VNAV armed, climbing through M.840: the window in Mach")
T.done()
