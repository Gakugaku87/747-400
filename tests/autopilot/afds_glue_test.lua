-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_glue_test.lua
-- The FCCs' mode logic, step 1a (6-3: docs/overhaul/notes/ATA-22.md §10), in
-- the autopilot module (B747.70.xt.autopilot.lua with B747.70.afds_model.lua),
-- with step 1b's roll modes and step 2a's roll laws (their command, not
-- X-Plane's HDG SEL):
-- the CMD switches, the disengage bar and the control wheel switches through
-- the model to the CMD channels, the servos and AUTOPILOT DISC
-- (laminar/B747/CAS/warning_status[0]); the defaults on the old code's state
-- (V/S synced to the present vertical speed, HDG HOLD, ATT's bank); 1b:
-- HDG SEL, LNAV's arm and engage, HDG HOLD (X-Plane's command replaced) and
-- its heading after 2 s, on the roll law's command;
-- the F/D switches (their positions); everything off; the MCP's IAS 200;
-- 1c: the pitch modes (V/S synced, ALT HOLD, FLCH, SPD, VNAV's arm and,
-- from the FMC's step 9c, its engage on the FMC's VNAV: its laws, speed,
-- A/T and path pointer, the FMC's VNAV lost); 1d: APP and LOC, the captures within the
-- course's angles (LOC's by the roll laws' geometry, step 2b, and its law),
-- the MCP's heading at LOC's capture, the old state; 1e:
-- TO/GA (the engines module's push count, G/A and its conditions, the old
-- go-around, the F/Ds shown with their switches OFF and FD, T/O). Steps 3a
-- and 3b: V/S, ALT, FLCH (20 kt slow: the command down), G/A (under 600
-- fpm: up) and T/O on the ground (8 degrees) on the pitch laws.
local T = dofile("tests/lib/check.lua")("afds_glue")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local CMD = "laminar/B747/autopilot/button_switch/"
local SERVOS, DISC = "laminar/B747/autopilot/servos_on", "laminar/B747/CAS/warning_status"
local VS_STATUS, VS_DIAL = "laminar/B747/autopilot/vvi_status", "sim/cockpit2/autopilot/vvi_dial_fpm"
local FD = "laminar/B747/toggle_switch/position"
local ATT = "laminar/B747/autopilot/att_rate"

local rt = xtlua.new()
rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
-- in the air at 10,000 ft, the hydraulics up, climbing 1,234 fpm
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 9000)
for i = 1, 3 do rt:set("laminar/B747/hydraulics/pressure_" .. i, 3000) end
-- the engage interlocks (6-3 step 5a) satisfied: the FCCs' AC and DC buses,
-- the battery bus, the IRUs' attitude, the ADCs, both SRMs' autotrim valid
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/electrical/bus/bat_main", 1)
-- (the A/T's servo: the F/O transfer bus, the FMC's step 9f3)
rt:set("laminar/B747/electrical/bus/xfr_fo", 1)
for i = 0, 2 do
    rt:set("laminar/B747/irs/att_valid", i, 1)
    rt:set("laminar/B747/airdata/valid", i, 1)
    -- (step 5c: the IRUs' heading and NAV for the roll modes' outer loop)
    rt:set("laminar/B747/irs/hdg_valid", i, 1)
    rt:set("laminar/B747/irs/nav_valid", i, 1)
end
local ATV = "laminar/B747/flt_ctrls/stab_trim/autotrim_valid"
rt:set(ATV, 0, 1)
rt:set(ATV, 1, 1)
-- (step 5b: the SRMs valid for the autoland capability)
rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", 0, 1)
rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", 1, 1)
rt:set("sim/cockpit2/gauges/indicators/vvi_fpm_pilot", 1234)
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 2)
rt:callout("flight_start")
for _ = 1, 30 do rt:frame(1 / 30) end
T.equal(rt:get("laminar/B747/autopilot/ias_dial_value"), 200, "the MCP's IAS 200 at power-up (FCOM p.643)")
T.equal(rt:get(SERVOS), 0, "nothing engaged")

local function sent(name)
    for _, c in ipairs(rt.command_log) do if c.name == name then return true end end
    return false
end
local function frames(n) for _ = 1, n or 3 do rt:frame(1 / 30) end end

-- CMD C with both F/Ds OFF: engaged on the push, V/S at the present 1,200
-- fpm, HDG HOLD (the roll law's, not X-Plane's HDG SEL: 6-3 step 2a)
local ROLL_LAW, ROLL_CMD = "laminar/B747/autopilot/roll_law", "laminar/B747/autopilot/roll_cmd"
rt.command_log = {}
rt:command(CMD .. "cmd_C")
frames()
T.equal(rt:get("laminar/B747/autopilot/cmd_C_mode/status"), 1, "CMD C: the centre channel engaged")
T.equal(rt:get(SERVOS), 1, "the servos on")
T.equal(rt:get(VS_STATUS), 2, "the default V/S")
T.equal(rt:get(VS_DIAL), 1200, "V/S synced to the present vertical speed (1,234 fpm: 1,200)")
T.equal(rt:get("laminar/B747/autopilot/FMA/active_roll_mode"), 7, "the FMA's HDG HOLD")
T.equal(rt:get(ROLL_LAW), 1, "the roll law flies it")
T.check(rt:get(ROLL_CMD) < 2 and rt:get(ROLL_CMD) > 0, "rolling out from 2 degrees: wings level")
T.check(not sent("sim/autopilot/heading"), "not X-Plane's HDG SEL")
rt:command(CMD .. "cmd_L")
frames()
T.equal(rt:get("laminar/B747/autopilot/cmd_L_mode/status"), 0, "CMD L with C engaged: no second channel")

-- the control wheel switch: disengaged with AUTOPILOT DISC, the second push
-- resets it
rt:command(CMD .. "yoke_disengage_capt")
frames()
T.equal(rt:get(SERVOS), 0, "the wheel switch: disengaged")
T.equal(rt:get(DISC, 0), 1, "AUTOPILOT DISC")
rt:command(CMD .. "yoke_disengage_fo")
frames()
T.equal(rt:get(DISC, 0), 0, "the second push resets it")

-- the bar: no engage while down, the warning stays when it is lifted
rt:command(CMD .. "cmd_R")
frames()
T.equal(rt:get("laminar/B747/autopilot/cmd_R_mode/status"), 1, "CMD R engaged")
rt:command("laminar/B747/autopilot/slide_switch/disengage_bar")
frames()
T.equal(rt:get(SERVOS), 0, "the bar down: disengaged")
T.equal(rt:get(DISC, 0), 1, "AUTOPILOT DISC")
rt:command(CMD .. "cmd_L")
frames()
T.equal(rt:get(SERVOS), 0, "CMD L with the bar down: nothing")
rt:command("laminar/B747/autopilot/slide_switch/disengage_bar")
frames()
T.equal(rt:get(DISC, 0), 1, "the bar lifted: AUTOPILOT DISC stays (ATA22 p.380)")
rt:command(CMD .. "cmd_L")
frames()
T.equal(rt:get(SERVOS), 1, "CMD L: engaged")
T.equal(rt:get(DISC, 0), 0, "the engage resets AUTOPILOT DISC")

-- 6-3 step 5a: the engage interlocks through the glue (ATA22 p.302-322).
-- SRM L's autotrim valid lost: L alone (on SRM L's) disengages with
-- AUTOPILOT DISC, CMD L does not engage, CMD C does (SRM R's); the battery
-- bus (the 28V DC STBY bus) lost once engaged: still engaged; AC bus 1
-- (C's FCC) lost: out; no engage without the battery bus or with the
-- control wheel at 30 degrees
rt:set(ATV, 0, 0)
frames()
T.check(rt:get(SERVOS) == 0 and rt:get(DISC, 0) == 1, "5a: SRM L's autotrim valid lost: L out, AUTOPILOT DISC")
rt:command(CMD .. "cmd_L")
frames()
T.equal(rt:get(SERVOS), 0, "CMD L without SRM L's: not engaged")
rt:command(CMD .. "cmd_C")
frames()
T.equal(rt:get("laminar/B747/autopilot/cmd_C_mode/status"), 1, "CMD C on SRM R's: engaged")
rt:set("laminar/B747/electrical/bus/bat_main", 0)
frames()
T.equal(rt:get("laminar/B747/autopilot/cmd_C_mode/status"), 1, "the battery bus lost: still engaged (ATA22 p.304)")
rt:set("laminar/B747/electrical/bus/ac", 0, 0)
frames()
T.check(rt:get(SERVOS) == 0 and rt:get(DISC, 0) == 1, "AC bus 1 lost: C's FCC off, disengaged, AUTOPILOT DISC")
rt:set("laminar/B747/electrical/bus/ac", 0, 1)
rt:set(ATV, 0, 1)
rt:command(CMD .. "cmd_C")
frames()
T.equal(rt:get(SERVOS), 0, "the battery bus off: no engage")
rt:set("laminar/B747/electrical/bus/bat_main", 1)
rt:set("laminar/B747/cablecontrols/wheel", 30)
rt:command(CMD .. "cmd_C")
frames()
T.equal(rt:get(SERVOS), 0, "the control wheel at 30 degrees: no engage (ATA22 p.314)")
rt:set("laminar/B747/cablecontrols/wheel", 0)
rt:command(CMD .. "cmd_L")
frames()
T.check(rt:get(SERVOS) == 1 and rt:get(DISC, 0) == 0, "CMD L: engaged again")

-- the hydraulics of the left channel (system 3) lost: out, the warning
rt:set("laminar/B747/hydraulics/pressure_3", 400)
frames()
T.equal(rt:get(SERVOS), 0, "system 3 lost: the left channel out")
T.equal(rt:get(DISC, 0), 1, "AUTOPILOT DISC")
rt:set("laminar/B747/hydraulics/pressure_3", 3000)
rt:command(CMD .. "yoke_disengage_capt")
frames()
-- the disengage with both F/Ds OFF turned everything off
T.equal(rt:get(VS_STATUS), 0, "everything off with neither the A/P nor a F/D (FCOM p.660)")
T.check(sent("sim/autopilot/servos_fdir_off"), "X-Plane's heading modes off too")
-- and nothing shows near the MCP altitude (the old capture window showed
-- ALT without a mode: s99 in X-Plane)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 10000)
rt:set("laminar/B747/autopilot/altitude_dial_ft", 10000)
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 10000)
frames(10)
T.equal(rt:get("laminar/B747/autopilot/FMA/active_pitch_mode"), 0, "no pitch mode at the MCP altitude with everything off")
T.equal(rt:get("laminar/B747/autopilot/FMA/active_roll_mode"), 0, "no roll mode")

-- away from the MCP altitude (there V/S captures ALT at once: 1c)
rt:set("laminar/B747/autopilot/altitude_dial_ft", 20000)
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 20000)
-- the first F/D ON at 15 degrees of bank: V/S and ATT
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 15)
rt:set("sim/cockpit2/gauges/indicators/vvi_fpm_pilot", -640)
rt:set(FD, 23, 1)
frames()
T.equal(rt:get(VS_STATUS), 2, "the first F/D ON in the air: V/S")
T.equal(rt:get(VS_DIAL), -600, "synced to -640 fpm: -600")
T.near(rt:get(ATT), 15, 0.01, "ATT holding 15 degrees (PW)")
rt:set(FD, 24, 1)
frames()
T.near(rt:get(ATT), 15, 0.01, "the second F/D ON: nothing new")

-- 1b: the roll modes through the model. HDG SEL: the roll law to the MCP's
-- heading (2a); LNAV armed with HDG SEL active, then engaged by the FMC's
-- steering above 50 ft, the law on it; HDG HOLD (X-Plane's command,
-- replaced): wings level until the roll stays under 3 degrees for 2 s,
-- then the heading there
local ROLL, ROLL_ARMED = "laminar/B747/autopilot/FMA/active_roll_mode", "laminar/B747/autopilot/FMA/armed_roll_mode"
local LNAV_STATE = "laminar/B747/autopilot/lnav_state"
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 0)
rt:set("sim/flightmodel/position/mag_psi", 95)
rt:set("laminar/B747/autopilot/heading/degrees", 120)
rt.command_log = {}
rt:command(CMD .. "heading_select")
frames()
T.equal(rt:get(ROLL), 6, "HDG SEL: the FMA's HDG SEL")
T.check(rt:get(ROLL_LAW) == 1 and rt:get(ROLL_CMD) > 0, "the MCP's 120 right of 095: banking right")
T.check(not sent("sim/autopilot/heading"), "not X-Plane's HDG SEL mode")
rt:command(CMD .. "LNAV")
frames()
T.equal(rt:get(LNAV_STATE), 1, "LNAV armed")
T.equal(rt:get(ROLL), 6, "HDG SEL still active")
T.equal(rt:get(ROLL_ARMED), 2, "the FMA's LNAV armed")
rt:command(CMD .. "heading_select")
frames()
T.equal(rt:get(LNAV_STATE), 1, "HDG SEL again: LNAV stays armed")
rt:set("laminar/B747/fms/lnav/valid", 1)
frames()
T.equal(rt:get(LNAV_STATE), 2, "the FMC's steering valid above 50 ft: LNAV engaged")
T.equal(rt:get(ROLL), 2, "the FMA's LNAV")
rt:set("laminar/B747/fms/lnav/roll", -10)
frames(300)
T.near(rt:get(ROLL_CMD), -10, 1e-6, "the law on the FMC's steering")
rt:command(CMD .. "LNAV")
frames()
T.equal(rt:get(LNAV_STATE), 2, "a push while active: still engaged")
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 12)
rt:command("sim/autopilot/heading_hold")
frames()
T.equal(rt:get(ROLL), 7, "HDG HOLD (X-Plane's command, the 3D's button): the FMA's HDG HOLD at once")
T.equal(rt:get(LNAV_STATE), 0, "LNAV off")
local c0 = rt:get(ROLL_CMD)
frames(30)
T.near(rt:get(ROLL_CMD), math.min(0, c0 + 3), 0.2, "rolling out at 3 degrees a second")
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 1)
rt:set("sim/flightmodel/position/mag_psi", 101)
frames(70)
rt:set("sim/flightmodel/position/mag_psi", 104)
frames(5)
T.check(rt:get(ROLL_CMD) < 0, "2 s under 3 degrees: the heading then held (101), back left from 104")

-- 1c: the pitch modes through the model. V/S synced to the present
-- vertical speed (the old one set 0); ALT HOLD at the altitude then; FLCH
-- with the speed window open as it is; SPD inactive in FLCH SPD; VNAV
-- (below, from the FMC's step 9c): PERF/VNAV UNAVAILABLE without the
-- FMC's performance data, armed below 400 ft with the active mode kept (the
-- old arm forced ALT HOLD), the second push, engaged above it on the FMC's
-- valid, the climb, level-offs, cruise and descent on the FMC's VNAV, lost
-- with it, a push while active, V/S ends it
local PITCH, PITCH_ARMED = "laminar/B747/autopilot/FMA/active_pitch_mode", "laminar/B747/autopilot/FMA/armed_pitch_mode"
local AT_FMA_ST = "laminar/B747/autopilot/FMA/autothrottle_mode"
local ALT_STATUS, FLCH_STATUS = "laminar/B747/autopilot/altitude_hold_status", "laminar/B747/autopilot/speed_status"
local NOTIFY, VNAV_STATE = "laminar/B747/fms/notification", "laminar/B747/autopilot/vnav_state"
local RA = "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot"
-- the FMC's data the old VNAV reads (its speeds: the FMS module's defaults,
-- the CRZ ALT FL350)
rt:set("laminar/B747/fms/data", '{"clbspd":"340","transpd":"250","spdtransalt":"10000","transalt":"18000",'
    .. '"clbrestspd":"---","clbrestalt":"-----","crzalt":"FL350","crzspd":"810","desspdmach":"805",'
    .. '"desspd":"270","destranspd":"240","desspdtransalt":"10000","desrestspd":"---","desrestalt":"-----",'
    .. '"costindex":"100"}')
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 12000)
rt:set("laminar/B747/autopilot/altitude_dial_ft", 20000)
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 20000)
rt:set("sim/cockpit2/gauges/indicators/vvi_fpm_pilot", 1840)
rt:command(CMD .. "vs_mode")
frames()
T.equal(rt:get(VS_STATUS), 2, "V/S")
T.equal(rt:get(VS_DIAL), 1800, "synced to the present 1,840 fpm: 1,800 (the old switch set 0)")
T.equal(rt:get(PITCH), 7, "the FMA's V/S")
-- the pitch laws (step 3a): V/S flown by the new law's command (the
-- airplane here does not answer it: the command's way only); 1,000 fpm
-- more than flown: the command up
local PITCH_LAW, PITCH_CMD = "laminar/B747/autopilot/pitch_law", "laminar/B747/autopilot/pitch_cmd"
rt:set("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot", 5)
rt:set("sim/flightmodel/position/vh_ind_fpm", 1840)
rt:set("sim/cockpit2/gauges/indicators/true_airspeed_kts_pilot", 300)
frames(150)
T.equal(rt:get(PITCH_LAW), 1, "V/S: the pitch law")
rt:set("sim/cockpit2/autopilot/vvi_dial_fpm", 2800)
local p0 = rt:get(PITCH_CMD)
frames(30)
T.check(rt:get(PITCH_CMD) > p0 + 0.1, "1,000 fpm more asked: the command up")
rt:set("sim/cockpit2/autopilot/vvi_dial_fpm", 1800)
rt:command(CMD .. "alt_hold_mode")
frames()
T.equal(rt:get(ALT_STATUS), 2, "ALT HOLD")
T.near(rt:get("laminar/B747/autopilot/altitude_hold_ft"), 12000, 0.5, "at the altitude then")
T.equal(rt:get(PITCH), 9, "the FMA's ALT")
T.equal(rt:get(PITCH_LAW), 1, "ALT: the pitch law")
-- the capture by the 0.05 g level-off and 10 s (step 3a; before, the old
-- window): V/S at 2,000 fpm 700 ft below the MCP altitude 12,700 is not
-- yet, 600 ft below it is (678 ft)
rt:command(CMD .. "vs_mode")
frames()
rt:set("laminar/B747/autopilot/altitude_dial_ft", 12700)
rt:set("sim/flightmodel/position/vh_ind_fpm", 2000)
frames(3)
T.equal(rt:get(PITCH), 7, "700 ft below at 2,000 fpm: V/S")
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 12100)
frames()
T.equal(rt:get(PITCH), 9, "600 ft below: ALT, the capture")
T.near(rt:get("laminar/B747/autopilot/altitude_hold_ft"), 12700, 0.5, "to the MCP altitude")
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 12000)
rt:set("laminar/B747/autopilot/altitude_dial_ft", 20000)
rt:set("sim/flightmodel/position/vh_ind_fpm", 0)
rt:command(CMD .. "vs_mode")
frames()
T.equal(rt:get(VS_DIAL), 0, "V/S after ALT: 000 (ATA22 p.282)")
local IAS = "laminar/B747/gauges/indicators/airspeed_kts_pilot"
rt:set(IAS, 200)
rt:command(CMD .. "flch_mode")
frames()
T.equal(rt:get(FLCH_STATUS), 2, "FLCH SPD")
T.equal(rt:get(PITCH), 8, "the FMA's FLCH SPD")
T.equal(rt:get(VS_STATUS), 0, "V/S off")
-- the speed law (step 3b): at the window's 200 kt, then 20 kt slower:
-- the command down (after the step's rate has gone)
T.equal(rt:get(PITCH_LAW), 1, "FLCH: the pitch law (step 3b)")
rt:set(IAS, 180)
frames(200)
local p1 = rt:get(PITCH_CMD)
frames(30)
T.check(rt:get(PITCH_CMD) < p1 - 0.1, "20 kt slow: the command down")
rt:set(IAS, 0)
rt:command(CMD .. "speed_mode")
frames()
T.equal(rt:get(PITCH), 8, "SPD in FLCH SPD: nothing (FCOM p.642; the old one went to V/S)")
-- VNAV (6-1/6-2 step 9c: the FMC's VNAV flies it; laminar/B747/fms/vnav/*
-- are the FMS module's, set here): PERF/VNAV UNAVAILABLE without the FMC's
-- gross weight, cost index or CRZ ALT (FCOM p.1433; flag 30:
-- B744.notifications.lua's DRindex + 1; before, CRZ ALT only)
local FVN = "laminar/B747/fms/vnav/"
local function fvn(t) for k, v in pairs(t) do rt:set(FVN .. k, v) end end
fvn({perf = 0, valid = 0})
rt:command(CMD .. "VNAV")
frames()
T.equal(rt:get(NOTIFY, 30), 1, "VNAV without the performance data: PERF/VNAV UNAVAILABLE (flag 30)")
T.equal(rt:get(VNAV_STATE), 0, "not armed")
-- the data entered, the FMC's VNAV valid: the climb to CRZ ALT FL350 in
-- VNAV SPD at 300 kt with THR REF; the A/T's ARM switch on (the engines
-- running: the old monitor fails the A/T with two out), Vmo 365 kt.
-- Below 400 ft VNAV stays armed (FCOM p.645: it activates at 400 ft)
rt:set(NOTIFY, 30, 0)
fvn({perf = 1, valid = 1, phase = 1, mode = 1, cas = 300, mach = 0.84, mach_mode = 0, alt = 35000,
    vs = 0, path_dev = 0, at = 5})
for i = 0, 3 do rt:set("laminar/B747/engines/display_N1", i, 90) end
rt:set("laminar/B747/engines/autothrottle_fail", 0)
rt:set(FD, 29, 1)
rt:set("laminar/B747/autothrottle/armed", 1)
rt:set("laminar/B747/airspeed/Vmo", 365)
rt:set(RA, 300)
rt:command(CMD .. "VNAV")
frames(30)
T.equal(rt:get(VNAV_STATE), 1, "VNAV armed")
T.equal(rt:get(NOTIFY, 30), 0, "no PERF/VNAV UNAVAILABLE")
T.equal(rt:get(PITCH), 8, "FLCH SPD still active (the old arm forced ALT HOLD)")
T.equal(rt:get(PITCH_ARMED), 4, "the FMA's VNAV armed")
rt:command(CMD .. "VNAV")
frames()
T.equal(rt:get(VNAV_STATE), 0, "the second push disarms")
T.equal(rt:get(PITCH_ARMED), 0, "the FMA's arm goes")
rt:command(CMD .. "VNAV")
frames()
T.equal(rt:get(VNAV_STATE), 1, "armed again")
-- above 400 ft it engages on the FMC's valid (ATA22 p.341; before, the old
-- VNAV engaged it): VNAV SPD, the old laws' flags off, the A/T active in
-- the FMC's THR REF, the FMC's 300 kt on the dial (X-Plane's too) with
-- the window shut, the climb's phase (the EEC's CLB)
local WINDOW, DIAL = "laminar/B747/autopilot/ias_mach/window_open", "laminar/B747/autopilot/ias_dial_value"
local AT_ACTIVE, PHASE = "laminar/B747/engines/autothrottle_active", "laminar/B747/autopilot/flightPhase"
local AFTER_TOD, FPE = "laminar/B747/autopilot/vnav/after_tod", "laminar/B747/autopilot/dist/flight_path_error"
rt:set(RA, 9000)
frames(30)
T.equal(rt:get(VNAV_STATE), 2, "engaged above 400 ft on the FMC's valid")
T.equal(rt:get(PITCH), 4, "the FMA's VNAV SPD")
T.equal(rt:get(PITCH_ARMED), 0, "no arm")
T.equal(rt:get(FLCH_STATUS), 0, "the old laws' flags off")
T.equal(rt:get(AT_ACTIVE), 1, "the A/T active (its ARM switch on: FCOM p.645)")
T.equal(rt:get(AT_FMA_ST), 5, "the A/T's THR REF (the FMC's)")
T.equal(rt:get(WINDOW), 0, "the IAS/MACH window shut")
T.equal(rt:get(DIAL), 300, "the FMC's 300 kt on the dial")
T.equal(rt:get("sim/cockpit2/autopilot/airspeed_dial_kts"), 300, "and X-Plane's (the speed law's reference)")

T.equal(rt:get(PHASE), 1, "the climb's phase")
T.equal(rt:get(AFTER_TOD), 0, "no path pointer in the climb")
-- 6-1/6-2 step 9a: climbing in VNAV SPD to the MCP altitude, VNAV levels
-- there (VNAV ALT: FCOM p.645, ATA22 p.280; before, the rebuilt AFDS flew
-- the old VNAV's FLCH on through it: s137); a new MCP altitude, VNAV SPD
local ALT_IND, VSI = "sim/cockpit2/gauges/indicators/altitude_ft_pilot", "sim/flightmodel/position/vh_ind_fpm"
local MCP_ALT = "laminar/B747/autopilot/heading/altitude_dial_ft"
local a0 = rt:get(ALT_IND)
local mcp0 = rt:get(MCP_ALT)
rt:set(VSI, 1500)
rt:set(MCP_ALT, a0 + 60)
frames(3)
T.equal(rt:get(PITCH), 5, string.format("climbing 60 ft below the MCP altitude: VNAV ALT (%d)", rt:get(PITCH)))
T.equal(rt:get(AT_FMA_ST), 3, "the A/T SPD while level (FCOM p.645)")
rt:set(MCP_ALT, a0 + 3000)
frames(3)
-- (step 9d1) a new MCP altitude alone: VNAV ALT still; the selector's
-- push: VNAV SPD again (FCOM p.645, p.1256; before, the new altitude
-- alone), the push counted for the FMC
T.equal(rt:get(PITCH), 5, "a new MCP altitude above, no push: VNAV ALT still")
local PUSHES = "laminar/B747/autopilot/alt_sel_pushes"
local np = rt:get(PUSHES)
rt:command("laminar/B747/button_switch/press_altitude")
frames(3)
T.equal(rt:get(PUSHES), np + 1, "the push counted")
T.equal(rt:get(PITCH), 4, "the selector pushed: VNAV SPD again")
T.equal(rt:get(AT_FMA_ST), 5, "THR REF again")
-- (step 9c) the climb's FMC altitude below the MCP's (a constraint): VNAV
-- PTH level there (ATA22 p.280); the next FMC altitude, VNAV SPD again
rt:set(MCP_ALT, mcp0)
fvn({alt = a0 + 60})
frames(3)
T.equal(rt:get(PITCH), 6, "the FMC altitude 60 ft above: VNAV PTH")
T.equal(rt:get(AT_FMA_ST), 3, "the A/T SPD while level")
fvn({alt = 35000})
frames(3)
T.equal(rt:get(PITCH), 4, "the next FMC altitude: VNAV SPD again")
-- (step 9d1) the FMC altitude the MCP's too (s139's cruise climb to CRZ
-- ALT FL190 with the MCP at FL190): VNAV PTH, no conflict (FCOM p.645;
-- before, VNAV ALT); the FMC's next above, the MCP's then: VNAV ALT
rt:set(MCP_ALT, a0 + 60)
fvn({alt = a0 + 60})
frames(3)
T.equal(rt:get(PITCH), 6, "the FMC and the MCP altitude both 60 ft above: VNAV PTH")
fvn({alt = 35000})
frames(3)
T.equal(rt:get(PITCH), 5, "the FMC's next above: the MCP altitude's VNAV ALT")
rt:set(MCP_ALT, mcp0)
rt:command("laminar/B747/button_switch/press_altitude")
frames(3)
T.equal(rt:get(PITCH), 4, "the MCP set back and pushed: VNAV SPD")
-- the cruise (the FMC's phase 2): VNAV PTH at CRZ ALT, the A/T SPD, the
-- FMC's Mach on the dial in Mach (.845: 84.5) with the units changed, the
-- cruise's phase (the EEC's CRZ)
rt:set(VSI, 0)
fvn({phase = 2, mode = 2, alt = a0, at = 3, mach_mode = 1, mach = 0.845})
frames(30)
T.equal(rt:get(PITCH), 6, "the cruise: VNAV PTH")
T.equal(rt:get(AT_FMA_ST), 3, "the A/T SPD")
T.equal(rt:get("sim/cockpit2/autopilot/airspeed_is_mach"), 1, "the dial in Mach")
T.near(rt:get(DIAL), 84.5, 1e-6, "the FMC's .845")
T.equal(rt:get(PHASE), 2, "the cruise's phase")
-- (step 9d2a) a cruise descent (the FMC's cruise phase in VNAV SPD with
-- THR at 1,250 fpm down to a lower CRZ ALT: FCOM p.1261): VNAV SPD, the
-- A/T's THR on the FMC's V/S (the levers less from level; before, FLCH's
-- V/S to the MCP altitude); the hand: HOLD; 60 ft above the new CRZ ALT
-- descending: VNAV PTH, the FMC altitude captured in
-- VNAV SPD (before, in the climb only), the A/T SPD
local LEVER_CMD = "laminar/B747/autothrottle/lever_cmd"
-- the levers where the A/T has them (the EEC puts them at its command;
-- off it by 8 degrees in THR is the hand: HOLD)
local c0 = rt:get(LEVER_CMD)
for e = 0, 3 do rt:set("laminar/B747/engine/throttle", e, c0) end
rt:set(MCP_ALT, a0 - 4000)
fvn({mode = 1, alt = a0 - 4000, at = 4, vs = -1250})
frames(3)
T.equal(rt:get(PITCH), 4, "the cruise descent: VNAV SPD")
T.equal(rt:get(AT_FMA_ST), 4, "the A/T's THR")
T.check(rt:get(LEVER_CMD) < c0, string.format("the levers less for 1,250 fpm down: %.4f from %.4f", rt:get(LEVER_CMD), c0))
-- the hand 8 degrees off the A/T's command: HOLD (the crew sets the rate:
-- FCOM p.1260; the settled HOLD at the rate is the A/T model's test's: here
-- the speed stays 0, a jump of it would read as a dive)
for e = 0, 3 do rt:set("laminar/B747/engine/throttle", e, rt:get(LEVER_CMD) + 0.2) end
frames()
T.equal(rt:get(AT_FMA_ST), 1, "the levers 8 degrees off: HOLD")
rt:set(VSI, -1200)

fvn({alt = a0 - 60})
frames(3)
T.equal(rt:get(PITCH), 6, "60 ft above the new CRZ ALT: VNAV PTH (the FMC altitude captured)")
T.equal(rt:get(AT_FMA_ST), 3, "the A/T SPD while level")
rt:set(VSI, 0)
rt:set("sim/cockpit2/gauges/indicators/vvi_fpm_pilot", 0)
fvn({mode = 2, alt = a0, at = 3, vs = 0})
frames(3)
T.equal(rt:get(PITCH), 6, "the cruise again: VNAV PTH")
-- the descent (phase 3) on the FMC's path below the MCP altitude 3,000 ft:
-- VNAV PTH on the path's vertical speed (-2,000 fpm: the pitch law's
-- command down from level), the A/T IDLE, the FMC's 280 kt in knots
-- again, the ND's VNAV path pointer (after_tod; 120 ft above the path:
-- FCOM p.1149)
rt:set(MCP_ALT, 3000)
local LEVER = "laminar/B747/engine/throttle"
for e = 0, 3 do rt:set(LEVER, e, 0.5) end
fvn({phase = 3, mode = 2, alt = 10000, vs = -2000, path_dev = 120, at = 2, mach_mode = 0, cas = 280})
local p2 = rt:get(PITCH_CMD)
frames(30)
T.equal(rt:get(PITCH), 6, "the descent: VNAV PTH")
T.equal(rt:get(AT_FMA_ST), 2, "the A/T IDLE")
-- (step 9f1) the levers at the aft stop: HOLD (ATA34_2 p.666)
for e = 0, 3 do rt:set(LEVER, e, 0) end
frames()
T.equal(rt:get(AT_FMA_ST), 1, "the levers at the aft stop: HOLD")
-- (step 9f3) THRUST REQUIRED (FCOM p.1434: flag 45): the descent asking
-- the A/T for speed with the A/T off; not while it asks for idle
rt:command(CMD .. "autothrottle_disco_L")
fvn({at = 3})
frames()
T.equal(rt:get(NOTIFY, 45), 1, "the A/T off, SPD asked: THRUST REQUIRED")
fvn({at = 2})
frames()
T.equal(rt:get(NOTIFY, 45), 0, "IDLE asked: none")
rt:command(CMD .. "autothrottle_disco_R")
frames()
T.check(rt:get(PITCH_CMD) < p2 - 0.1, "-2,000 fpm asked from level: the command down")
T.equal(rt:get("sim/cockpit2/autopilot/airspeed_is_mach"), 0, "the dial in knots")
T.equal(rt:get(DIAL), 280, "the FMC's 280 kt")
T.equal(rt:get(PHASE), 3, "the descent's phase")
T.equal(rt:get(AFTER_TOD), 1, "the ND's path pointer shown")
T.near(rt:get(FPE), 120, 1e-6, "120 ft above the path")
-- the FMC's VNAV not valid: VNAV ends into ALT HOLD at the altitude then
-- (ATA22 p.338), the path pointer off; the arm without it ends at once (no
-- DESTINATION NOT SET, flag 54: the old cancel posted it)
fvn({valid = 0})
frames()
T.equal(rt:get(VNAV_STATE), 0, "not valid: VNAV ends")
T.equal(rt:get(PITCH), 9, "into ALT HOLD")
T.near(rt:get("laminar/B747/autopilot/altitude_hold_ft"), a0, 0.5, "at the altitude then")
T.equal(rt:get(AFTER_TOD), 0, "the path pointer off")
rt:set(NOTIFY, 54, 0)
rt:command(CMD .. "VNAV")
frames()
T.equal(rt:get(VNAV_STATE), 0, "not valid: VNAV's arm ends at once")
T.equal(rt:get(PITCH_ARMED), 0, "no arm in the FMA")
T.equal(rt:get(PITCH), 9, "ALT stays")
T.equal(rt:get(NOTIFY, 54), 0, "no DESTINATION NOT SET")
-- valid again: armed and engaged; a push while engaged does nothing (the
-- old one disengaged it); V/S ends it
fvn({valid = 1})
rt:command(CMD .. "VNAV")
frames(3)
T.equal(rt:get(VNAV_STATE), 2, "valid again: armed and engaged")
rt:command(CMD .. "VNAV")
frames()
T.equal(rt:get(VNAV_STATE), 2, "a push while engaged: nothing")
rt:command(CMD .. "vs_mode")
frames()
T.equal(rt:get(VNAV_STATE), 0, "V/S ends VNAV (FCOM p.645)")
T.equal(rt:get(PITCH), 7, "the FMA's V/S")
T.equal(rt:get(VS_STATUS), 2, "the old law's V/S")
-- (the FMC's step 9f1) the A/T through the glue: SPD after VNAV into V/S
-- (ATA34_2 p.654); a disconnect push: off, >AUTOTHROT DISC (caution 5);
-- a second: the message off (FCOM p.657); the SPD switch: SPD
local DISC_ST = "laminar/B747/CAS/caution_status"
T.equal(rt:get(AT_FMA_ST), 3, "VNAV into V/S: the A/T's SPD")
rt:command(CMD .. "autothrottle_disco_L")
frames()
T.equal(rt:get(AT_FMA_ST), 0, "a disconnect push: the A/T off")
T.equal(rt:get(AT_ACTIVE), 0, "not active")
T.equal(rt:get(DISC_ST, 5), 1, ">AUTOTHROT DISC")
rt:command(CMD .. "autothrottle_disco_R")
frames()
T.equal(rt:get(DISC_ST, 5), 0, "a second push: the message off")
rt:command(CMD .. "speed_mode")
frames()
T.equal(rt:get(AT_FMA_ST), 3, "the SPD switch in V/S: SPD")
T.equal(rt:get(AT_ACTIVE), 1, "active")
-- (step 9f3) the F/O transfer bus lost (the servo's power: ATA34_2 p.450):
-- off with >AUTOTHROT DISC; the SPD switch nothing until it is back
local XFR = "laminar/B747/electrical/bus/xfr_fo"
rt:set(XFR, 0)
frames()
T.equal(rt:get(AT_ACTIVE), 0, "the F/O transfer bus lost: the A/T off")
T.equal(rt:get(DISC_ST, 5), 1, ">AUTOTHROT DISC")
rt:command(CMD .. "speed_mode")
frames()
T.equal(rt:get(AT_ACTIVE), 0, "the SPD switch unpowered: nothing")
rt:set(XFR, 1)
rt:command(CMD .. "speed_mode")
frames()
T.check(rt:get(AT_ACTIVE) == 1 and rt:get(DISC_ST, 5) == 0, "powered again: SPD, the message reset")
-- 1d: the approach modes through the model. APP arms LOC and G/S (with no
-- ILS too: the old one posted RW/ILS CRS ERROR, flag 40); the captures by
-- the pitch and roll laws' geometry (steps 2b and 3c: both receivers'
-- signals, the distance from the beam and its closing) with the track
-- within 120 and 80 degrees of the course (the old monitor no longer
-- captures by itself); the MCP's heading to the course at LOC's capture
-- (the old APP switch set it at once); the old state written
-- (approach_mode, nav and G/S status) for the old laws, lights and autoland
local NAV, NAV_ACT = "laminar/B747/autopilot/nav_status", "laminar/B747/autopilot/actual_nav_status"
local GS, GS_ACT = "laminar/B747/autopilot/glideslope_status", "laminar/B747/autopilot/actual_glideslope_status"
local APPM = "laminar/B747/autopilot/approach_mode"
local ROLL, ROLL_ARMED = "laminar/B747/autopilot/FMA/active_roll_mode", "laminar/B747/autopilot/FMA/armed_roll_mode"
local RI = "sim/cockpit2/radios/indicators/"
local function ils(loc, gs)
    rt:set(RI .. "nav1_display_horizontal", loc and 1 or 0)
    rt:set(RI .. "nav2_display_horizontal", loc and 1 or 0)
    rt:set(RI .. "nav1_display_vertical", gs and 1 or 0)
    rt:set(RI .. "nav2_display_vertical", gs and 1 or 0)
    rt:set(RI .. "nav1_flag_glideslope", gs and 0 or 1)
    rt:set(RI .. "nav2_flag_glideslope", gs and 0 or 1)
    rt:set(RI .. "nav1_vdef_dots_pilot", gs and -0.3 or -2.5)
end
ils(false, false)
rt:set("laminar/B747/autopilot/ils_dots", 0)
rt:set("sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot", 0, 336)
rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_pilot", 160)
rt:set("laminar/B747/autopilot/heading/degrees", 100)
rt:set(RA, 3000)
rt:set(NOTIFY, 40, 0)
rt:command(CMD .. "alt_hold_mode")
frames()
rt:command("laminar/B747/autopilot/approach")
frames()
T.equal(rt:get(NOTIFY, 40), 0, "APP with no ILS: armed, no RW/ILS CRS ERROR")
T.equal(rt:get(APPM), 1, "the approach mode APP")
T.check(rt:get(NAV) == 1 and rt:get(NAV_ACT) == 1, "LOC armed (the old status 1)")
T.check(rt:get(GS) == 1 and rt:get(GS_ACT) == 1, "G/S armed")
T.equal(rt:get(ROLL_ARMED), 3, "the FMA's LOC armed")
T.equal(rt:get(PITCH_ARMED), 2, "the FMA's G/S armed")
T.equal(rt:get("laminar/B747/autopilot/heading/degrees"), 100, "the MCP's heading not yet the course")
-- both receivers' signals with the track 176 degrees off the course: no
-- capture (the old monitor captured on the signals alone)
ils(true, false)
frames(10)
T.equal(rt:get(NAV), 1, "no LOC capture 176 degrees off the course")
-- the capture by the roll laws' geometry (step 2b): the track 26 degrees
-- off from the beam's right at 200 kt, 2 dots (2.82 degrees, 866 m at the
-- radio altimeter's 2,500 ft) closing: not yet (the turn takes 414 m);
-- 0.8 dot (346 m): captured, the MCP's heading to the course
rt:set("sim/flightmodel/position/groundspeed", 200 * 1852 / 3600)
rt:set(RI .. "nav1_hdef_dots_pilot", -2)
rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_pilot", 310)
frames(10)
T.equal(rt:get(NAV), 1, "2 dots right closing at 26 degrees: not yet captured")
rt:set(RI .. "nav1_hdef_dots_pilot", -0.8)
frames()
T.check(rt:get(NAV) == 2 and rt:get(NAV_ACT) == 2, "0.8 dot: LOC captured (the old status 2)")
T.equal(rt:get(ROLL), 3, "the FMA's LOC")
T.equal(rt:get("laminar/B747/autopilot/heading/degrees"), 336, "the MCP's heading to the course at LOC's capture")
-- LOC's law: right of the beam closing from the right at 26 degrees,
-- rolling right to come onto the course (from the command it had: the
-- airplane here does not answer it)
local r0 = rt:get("laminar/B747/autopilot/roll_cmd")
frames(60)
T.check(rt:get("laminar/B747/autopilot/roll_law") == 1 and rt:get("laminar/B747/autopilot/roll_cmd") > r0 + 3,
    "LOC's law: rolling right onto the course (not X-Plane's HDG SEL)")
-- G/S's capture by the pitch laws (step 3c): level under the beam at 200
-- kt, its 1,061 fpm closing (17.7 ft/s: 203 ft to turn onto it at 0.05 g
-- with the 6 s lead), at the radio altimeter's 2,500 ft (47,702 ft out):
-- 2 dots (0.54 degree, 453 ft) not yet, 0.3 dot (68 ft) captured
ils(true, true)
rt:set(RI .. "nav1_vdef_dots_pilot", -2)
frames(10)
T.equal(rt:get(GS), 1, "2 dots under the beam, level: not yet captured")
rt:set(RI .. "nav1_vdef_dots_pilot", -0.3)
frames()
T.check(rt:get(GS) == 2 and rt:get(GS_ACT) == 2, "0.3 dot: G/S captured")
T.equal(rt:get(PITCH), 2, "the FMA's G/S")
T.equal(rt:get(PITCH_ARMED), 0, "nothing armed in pitch")
-- G/S's law (not the old one): under the beam level, down onto it
local gs_p0 = rt:get(PITCH_CMD)
frames(150)
T.check(rt:get(PITCH_LAW) == 1 and rt:get(PITCH_CMD) < gs_p0 - 0.5, "G/S's law: the nose down onto the beam (" .. gs_p0 .. " to " .. rt:get(PITCH_CMD) .. ")")
-- the signals lost: LOC stays engaged (its latch; the old monitor armed it
-- again)
ils(false, false)
frames(10)
T.equal(rt:get(NAV), 2, "LOC stays engaged without the signals")
-- HDG SEL after G/S: not taken (table p.351)
rt:command(CMD .. "heading_select")
frames()
T.equal(rt:get(ROLL), 3, "HDG SEL with LOC and G/S engaged: still LOC")
-- everything off: the approach too
rt:command(CMD .. "yoke_disengage_capt")
rt:command(CMD .. "yoke_disengage_capt")
rt:set(FD, 23, 0)
rt:set(FD, 24, 0)
frames()
T.check(rt:get(APPM) == 0 and rt:get(NAV) == 0 and rt:get(GS) == 0, "everything off: no approach")
-- LOC alone: armed, the second push disarms
rt:set(FD, 23, 1)
frames()
rt:command(CMD .. "loc_mode")
frames()
T.check(rt:get(APPM) == -1 and rt:get(NAV) == 1 and rt:get(GS) == 0, "LOC armed alone (approach mode -1)")
rt:command(CMD .. "loc_mode")
frames()
T.check(rt:get(APPM) == 0 and rt:get(NAV) == 0, "the second LOC push disarms")
-- 4a: multi-channel through the model. CMD L, APP: C and R armed (their
-- CMD lights: laminar/B747/autopilot/cmd_armed), not engaged; LOC and G/S
-- captured at 1,400 ft with the track on the course: all three engaged 5 s
-- later, LAND 3 (the AFDS status 4) with three FCC power sources (AC and
-- DC 3, 1, 2), IRUs, radio altimeters and ILS receivers valid; FLARE and
-- ROLLOUT armed on the FMA; a radio altimeter lost: LAND 2 (3)
local ARMED, STATUS_P = "laminar/B747/autopilot/cmd_armed", "laminar/B747/autopilot/AFDS/status_annun_pilot"
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
for i = 0, 2 do
    rt:set("laminar/B747/irs/nav_valid", i, 1)
    rt:set("laminar/B747/ra/valid", i, 1)
end
rt:command(CMD .. "cmd_L")
frames()
T.equal(rt:get(STATUS_P), 2, "CMD L: the status CMD")
rt:set(RA, 3000)
rt:set(RI .. "nav1_hdef_dots_pilot", 0)
rt:set(RI .. "nav1_vdef_dots_pilot", 0)
rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_pilot", 336)
ils(true, true)
rt:set(RI .. "nav1_vdef_dots_pilot", 0)
frames()
local ILS_INH, RA_INH = "laminar/B747/autopilot/ils_tune_inhibit", "laminar/B747/autopilot/ra_test_inhibit"
T.check(rt:get(ILS_INH) == 0 and rt:get(RA_INH) == 0, "5d: the A/P, nothing captured: no ILS TUNE or RA TEST INHIBIT")
rt:command("laminar/B747/autopilot/approach")
frames()
T.check(rt:get(ARMED, 1) == 1 and rt:get(ARMED, 2) == 1 and rt:get(ARMED, 0) == 0, "APP with L engaged: C and R armed")
T.check(rt:get("laminar/B747/autopilot/cmd_C_mode/status") == 0 and rt:get("laminar/B747/autopilot/cmd_R_mode/status") == 0,
    "armed, not engaged (before, all three engaged at once)")
-- ELEC-18: the bus isolation request from the APP's multi-channel arm
-- (ATA22 p.192); the electrical module's BUS ISOLATED back (as it would)
local BUS_REQ, BUS_ISO = "laminar/B747/autopilot/bus_isolate_req", "laminar/B747/electrical/bus_isolated"
T.equal(rt:get(BUS_REQ), 1, "ELEC-18: APP, C and R armed: the bus isolation request")
rt:set(BUS_ISO, 1)
frames(30)
T.check(rt:get(NAV) == 2 and rt:get(GS) == 2, "LOC and G/S captured")
T.check(rt:get(ILS_INH) == 1 and rt:get(RA_INH) == 1, "5d: the A/P with LOC and G/S captured: ILS TUNE and RA TEST INHIBIT (ATA22 p.212)")
T.equal(rt:get("laminar/B747/autopilot/cmd_C_mode/status"), 0, "at 3,000 ft: not engaged")
rt:set(RA, 1400)
frames(30 * 4)
T.equal(rt:get("laminar/B747/autopilot/cmd_C_mode/status"), 0, "4 s below 1,500 ft: not yet")
frames(30 * 1.2)
T.check(rt:get("laminar/B747/autopilot/cmd_C_mode/status") == 1 and rt:get("laminar/B747/autopilot/cmd_R_mode/status") == 1,
    "5 s below 1,500 ft: C and R engaged")
T.check(rt:get(ARMED, 1) == 0 and rt:get(ARMED, 2) == 0, "no arms left")
T.equal(rt:get(STATUS_P), 4, "LAND 3")
T.equal(rt:get(ROLL_ARMED), 4, "the FMA's ROLLOUT armed")
T.equal(rt:get(PITCH_ARMED), 3, "the FMA's FLARE armed")
local CAUTION, ADVISORY = "laminar/B747/CAS/caution_status", "laminar/B747/CAS/advisory_status"
T.check(rt:get(CAUTION, 50) == 0 and rt:get(ADVISORY, 248) == 0 and rt:get(ADVISORY, 246) == 0,
    "5b: LAND 3, all there: no NO LAND 3 or NO AUTOLAND")
rt:set("laminar/B747/ra/valid", 2, 0)
frames()
T.equal(rt:get(STATUS_P), 3, "a radio altimeter lost: LAND 2")
T.check(rt:get(CAUTION, 50) == 1 and rt:get(ADVISORY, 248) == 0, "5b: after LAND 3: NO LAND 3, the caution [50]")
rt:set("laminar/B747/ra/valid", 2, 1)
frames()
T.equal(rt:get(STATUS_P), 4, "LAND 3 again")
T.equal(rt:get(CAUTION, 50), 0, "NO LAND 3 gone")
-- ELEC-18: BUS ISOLATED gone (a second generator channel lost above
-- 200 ft): LAND 2, and NO LAND 3 after 4 s (ATA22 p.384)
rt:set(BUS_ISO, 0)
frames()
T.equal(rt:get(STATUS_P), 3, "ELEC-18: BUS ISOLATED gone: LAND 2")
frames(30 * 4.2)
T.equal(rt:get(CAUTION, 50), 1, "not isolated for 4 s: NO LAND 3, the caution [50]")
rt:set(BUS_ISO, 1)
frames()
T.check(rt:get(STATUS_P) == 4 and rt:get(CAUTION, 50) == 0, "isolated again: LAND 3, NO LAND 3 gone")
-- 4d: runway align with LAND 3 in LOC (FCOM p.670): the wings held level
-- with the rudder, LOC asking for a right bank (the track 2 degrees left of
-- the course, as a left engine out yaws it) asking for right rudder; none
-- before the multi-channel engage (above)
rt:set("sim/flightmodel/position/mag_psi", 336)
rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_pilot", 334)
frames(30 * 2)
T.check(rt:get("laminar/B747/autopilot/rudder_cmd") > 0, "4d: LAND 3, LOC banking right: the A/P's rudder right")
rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_pilot", 336)
-- 4b: FLARE in LAND 3 through the glue: the pitch FMA's FLARE (3) at the
-- flare height on the gear altitude (the radio altitude less 2.3 ft and 10
-- ft x sin pitch) for the sink rate (13 ft/s: 50 ft), the A/T's IDLE (2) at 25 ft;
-- on the ground FLARE off, IDLE kept (FCOM p.671). Before, the old
-- autoland froze the pitch FMA and the A/T's at the LAND's engage
local AT_FMA = "laminar/B747/autopilot/FMA/autothrottle_mode"
local ONGND = "sim/flightmodel/failures/onground_any"
rt:set("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot", 3.3)
rt:set("sim/flightmodel/position/vh_ind_fpm", -790)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 145)  -- (the old autoland's disconnect is under 65 kt on the ground)
rt:set(RA, 60)
frames()
T.equal(rt:get(PITCH), 2, "LAND 3 at 60 ft: G/S")
rt:set(RA, 53)
frames()
T.equal(rt:get(PITCH), 2, "53 ft (the gear 50.1 ft) at 13 ft/s: not yet")
rt:set(RA, 51)
frames()
T.equal(rt:get(PITCH), 3, "51 ft (the gear 48.1 ft): FLARE on the FMA")
T.equal(rt:get(PITCH_LAW), 1, "FLARE: the pitch law's")
T.check(rt:get(AT_FMA) ~= 2, "FLARE above 25 ft: no IDLE yet")
-- (4c) the glide slope flagged in FLARE, as X-Plane's in the last feet:
-- LAND 3 kept, the receivers count on their localizer from FLARE (G/S ends
-- there: ATA22 p.342)
rt:set(RI .. "nav1_flag_glideslope", 1)
rt:set(RI .. "nav2_flag_glideslope", 1)
frames()
T.equal(rt:get(STATUS_P), 4, "the glide slope flagged in FLARE: LAND 3 kept")
T.equal(rt:get(ROLL_ARMED), 4, "ROLLOUT still armed")
rt:set(RA, 20)
frames()
T.equal(rt:get(AT_FMA), 2, "20 ft: the A/T's IDLE")
rt:set(ONGND, 1)
rt:set(RA, 3)
frames()
T.equal(rt:get(PITCH), 0, "on the ground: FLARE off")
T.equal(rt:get(AT_FMA), 2, "on the ground: IDLE kept")
T.equal(rt:get(PITCH_LAW), 1, "NOSE LETDOWN: the pitch law's on the ground")
-- 4c: ROLLOUT below 5 ft RA on the FMA (FCOM p.664), the rudder with three
-- channels (FCOM p.659: the hydraulics module adds it to the pedals), the
-- SRMs' autoland in LAND 3 (ATA27 p.636); at 40 kt the A/P still engaged
-- (no disconnect at 65 kt: FCTM p.159), ROLLOUT until it is disengaged
T.equal(rt:get(ROLL), 4, "on the ground: ROLLOUT active")
T.equal(rt:get(ROLL_ARMED), 0, "ROLLOUT no more armed")
T.equal(rt:get("laminar/B747/autopilot/autoland"), 1, "LAND 3: the SRMs' autoland")
rt:set(RI .. "nav1_hdef_dots_pilot", 0.05)
frames(15)
T.check(rt:get("laminar/B747/autopilot/rudder_cmd") > 0, "left of the centreline: the A/P's rudder right")
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 40)
frames(30)
T.equal(rt:get("laminar/B747/autopilot/cmd_L_mode/status"), 1, "40 kt on the ground: the A/P still engaged")
T.equal(rt:get(ROLL), 4, "40 kt: still ROLLOUT")
rt:set(RI .. "nav1_hdef_dots_pilot", 0)
rt:set(RI .. "nav1_flag_glideslope", 0)
rt:set(RI .. "nav2_flag_glideslope", 0)
rt:set(ONGND, 0)
rt:command(CMD .. "yoke_disengage_capt")
rt:command(CMD .. "yoke_disengage_capt")
rt:set(FD, 23, 0)
rt:set(FD, 24, 0)
frames()
T.equal(rt:get(STATUS_P), 0, "all off: no status")
rt:set(FD, 23, 1)
frames()
rt:set(RA, 9000)
-- 1e: TO/GA. A push counted by the engines module (laminar/B747/autopilot/
-- toga_pushes): G/A in the air with the flaps out of up, the old code's
-- go-around (its autoland -2 with the A/P engaged), its TO/GA flag, the
-- FMA's TO/GA; with both F/D switches OFF above 80 kt the F/Ds shown and
-- FD on both PFDs until a switch is cycled ON and OFF (FCOM p.657,
-- p.661); T/O by the first F/D ON on the ground
local PUSHES, TOGA_FLAG = "laminar/B747/autopilot/toga_pushes", "laminar/B747/autopilot/TOGA_status"
local SHOWN_C, SHOWN_F = "laminar/B747/autopilot/fd/capt/shown", "laminar/B747/autopilot/fd/fo/shown"
local AFDS_C, AFDS_F = "laminar/B747/autopilot/AFDS/status_annun_pilot", "laminar/B747/autopilot/AFDS/status_annun_copilot"
local FLAPS = "sim/cockpit2/controls/flap_ratio"
local function push() rt:set(PUSHES, (rt:get(PUSHES) or 0) + 1) frames() end
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 160)
rt:set(RA, 1000)                                                   -- below 1,500 ft (the old code ends its go-around above)
rt:command(CMD .. "cmd_L")
frames()
T.equal(rt:get(SERVOS), 1, "the A/P engaged in the F/D's modes")
rt:set(FLAPS, 0)
push()
T.check(rt:get(ROLL) ~= 1 and rt:get(TOGA_FLAG) == 0, "flaps up, no G/S: no G/A")
rt:set(FLAPS, 0.668)
push()
T.check(rt:get(ROLL) == 1 and rt:get(PITCH) == 1, "the flaps out of up: G/A, the FMA's TO/GA")
T.equal(rt:get(PITCH_LAW), 1, "G/A: the pitch law (step 3b)")
rt:set("sim/flightmodel/position/vh_ind_fpm", 0)
local g0 = rt:get(PITCH_CMD)
frames(10)
T.check(rt:get(PITCH_CMD) > g0 + 0.1, "G/A under 600 fpm: up toward 15 degrees (FCOM p.674)")
T.equal(rt:get(TOGA_FLAG), 1, "the old code's TO/GA flag")
T.equal(rt:get("laminar/B747/autopilot/autoland"), -2, "the old autoland's go-around")
T.check(rt:get(SHOWN_C) == 1 and rt:get(SHOWN_F) == 0, "the F/Ds shown: the Captain's switch ON")
rt:command(CMD .. "yoke_disengage_capt")
rt:command(CMD .. "yoke_disengage_capt")
rt:set(FD, 23, 0)
frames()
T.check(rt:get(ROLL) == 0 and rt:get(TOGA_FLAG) == 0, "the A/P off and both F/Ds OFF: everything off")
push()
T.check(rt:get(ROLL) == 1 and rt:get(PITCH) == 1, "both switches OFF: G/A")
T.check(rt:get(SHOWN_C) == 1 and rt:get(SHOWN_F) == 1, "the F/Ds shown on both sides")
frames(10)
T.check(rt:get(AFDS_C) == 1 and rt:get(AFDS_F) == 1, "FD on both PFDs")
rt:set(FD, 24, 1)
frames()
T.equal(rt:get(ROLL), 1, "the F/O's switch ON: G/A kept")
rt:set(FD, 24, 0)
frames()
T.check(rt:get(ROLL) == 0 and rt:get(SHOWN_C) == 0 and rt:get(SHOWN_F) == 0, "and OFF: everything off, nothing shown")
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set(RA, 0)
frames()
rt:set(FD, 23, 1)
frames()
T.check(rt:get(ROLL) == 1 and rt:get(PITCH) == 1 and rt:get(TOGA_FLAG) == 1, "the first F/D ON on the ground: T/O")
T.equal(rt:get(PITCH_LAW), 1, "T/O on the ground: the pitch law (step 3b)")
T.equal(rt:get(PITCH_CMD), 8, "8 degrees (FCOM p.666)")
rt:set(FD, 23, 0)
frames()
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set(RA, 9000)

-- 6-3 step 5c: a mode failure through the glue (ATA22 p.382; FCOM p.660).
-- CMD L in HDG HOLD and V/S: both F/D bars, no AUTOPILOT; two IRUs'
-- headings lost: HDG HOLD failed, the FMA's amber line, the roll bar gone
-- (the 109: the pitch bar stays; the 570: both), AUTOPILOT [4], the roll
-- law holding the bank; the headings back and HDG SEL: none of it
local RB, PB = "laminar/B747/autopilot/fd/roll_bar", "laminar/B747/autopilot/fd/pitch_bar"
local RFAIL = "laminar/B747/autopilot/FMA/roll_fail"
rt:set(FD, 23, 1)
frames()
rt:command(CMD .. "cmd_L")
frames()
T.check(rt:get("laminar/B747/autopilot/cmd_L_mode/status") == 1 and rt:get(ROLL) == 7, "5c: (CMD L in HDG HOLD)")
T.check(rt:get(RB) == 1 and rt:get(PB) == 1 and rt:get(RFAIL) == 0, "5c: both F/D bars, no amber line")
T.equal(rt:get(CAUTION, 4), 0, "no AUTOPILOT")
rt:set("laminar/B747/irs/hdg_valid", 0, 0)
rt:set("laminar/B747/irs/hdg_valid", 1, 0)
frames()
T.check(rt:get(RFAIL) == 1 and rt:get(ROLL) == 7, "two headings lost: HDG HOLD failed, its amber line")
T.check(rt:get(RB) == 0 and rt:get(PB) == 1, "the roll bar gone, the pitch bar stays (the 109)")
T.equal(rt:get(CAUTION, 4), 1, "AUTOPILOT")
T.equal(rt:get(ROLL_LAW), 1, "the roll law holds the bank")
rt:set("laminar/B747/engines/type", 1)
frames()
T.check(rt:get(RB) == 0 and rt:get(PB) == 0, "the 570: both bars gone")
rt:set("laminar/B747/engines/type", 0)
rt:set("laminar/B747/irs/hdg_valid", 0, 1)
rt:set("laminar/B747/irs/hdg_valid", 1, 1)
rt:command(CMD .. "heading_select")
frames()
T.check(rt:get(RFAIL) == 0 and rt:get(RB) == 1 and rt:get(CAUTION, 4) == 0, "the headings back, HDG SEL: no failure, the bar, no AUTOPILOT")
T.done()
