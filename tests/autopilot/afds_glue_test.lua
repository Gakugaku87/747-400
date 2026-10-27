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
-- 1c: the pitch modes (V/S synced, ALT HOLD, FLCH, SPD, VNAV's arm and the
-- old VNAV's engage, no route); 1d: APP and LOC, the captures within the
-- course's angles (LOC's by the roll laws' geometry, step 2b, and its law),
-- the MCP's heading at LOC's capture, the old state; 1e:
-- TO/GA (the engines module's push count, G/A and its conditions, the old
-- go-around, the F/Ds shown with their switches OFF and FD, T/O).
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
-- with the speed window open as it is; SPD inactive in FLCH SPD; VNAV: no
-- cruise altitude, PERF/VNAV UNAVAILABLE (flag 30: B744.notifications.lua's
-- DRindex + 1); armed below 400 ft with the active mode kept (the old arm
-- forced ALT HOLD), the second push; engaged by the old VNAV above 400 ft
-- (its sub-mode in the FMA), a push while active, V/S ends it; no route
-- ends the arm without DESTINATION NOT SET (flag 54)
local PITCH, PITCH_ARMED = "laminar/B747/autopilot/FMA/active_pitch_mode", "laminar/B747/autopilot/FMA/armed_pitch_mode"
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
rt:command(CMD .. "alt_hold_mode")
frames()
T.equal(rt:get(ALT_STATUS), 2, "ALT HOLD")
T.near(rt:get("laminar/B747/autopilot/altitude_hold_ft"), 12000, 0.5, "at the altitude then")
T.equal(rt:get(PITCH), 9, "the FMA's ALT")
rt:command(CMD .. "vs_mode")
frames()
T.equal(rt:get(VS_DIAL), 0, "V/S after ALT: 000 (ATA22 p.282)")
rt:command(CMD .. "flch_mode")
frames()
T.equal(rt:get(FLCH_STATUS), 2, "FLCH SPD")
T.equal(rt:get(PITCH), 8, "the FMA's FLCH SPD")
T.equal(rt:get(VS_STATUS), 0, "V/S off")
rt:command(CMD .. "speed_mode")
frames()
T.equal(rt:get(PITCH), 8, "SPD in FLCH SPD: nothing (FCOM p.642; the old one went to V/S)")
rt:set("laminar/B747/autopilot/dist/cruise_alt", 0)
rt:command(CMD .. "VNAV")
frames()
T.equal(rt:get(NOTIFY, 30), 1, "VNAV without a cruise altitude: PERF/VNAV UNAVAILABLE (flag 30)")
T.equal(rt:get(VNAV_STATE), 0, "not armed")
-- a route on X-Plane's FMS ([2] the type, 1 an airport; [5] [6] the
-- position; [9] the altitude): the old VNAV cancels itself without one.
-- Below 400 ft VNAV stays armed (FCOM p.645: it activates at 400 ft)
rt:set("xtlua/fms", '[[1,1,0,0,35.76,140.39,0,"RJAA",0,false],[2,512,0,0,35.0,139.5,0,"XAC",0,true],'
    .. '[3,1,0,0,34.43,135.24,0,"RJBB",0,false]]')
rt:set("laminar/B747/autopilot/dist/cruise_alt", 35000)
rt:set("laminar/B747/autopilot/dist/remaining_distance", 500)
rt:set(RA, 300)
rt:command(CMD .. "VNAV")
frames(30)
T.equal(rt:get(VNAV_STATE), 1, "VNAV armed")
T.equal(rt:get(PITCH), 8, "FLCH SPD still active (the old arm forced ALT HOLD)")
T.equal(rt:get(PITCH_ARMED), 4, "the FMA's VNAV armed")
rt:command(CMD .. "VNAV")
frames()
T.equal(rt:get(VNAV_STATE), 0, "the second push disarms")
T.equal(rt:get(PITCH_ARMED), 0, "the FMA's arm goes")
rt:command(CMD .. "VNAV")
frames()
T.equal(rt:get(VNAV_STATE), 1, "armed again")
-- above 400 ft the old VNAV engages it (until the FMC's step 9): VNAV SPD
-- on FLCH's law
rt:set(RA, 9000)
frames(30)
T.check(rt:get(VNAV_STATE) >= 2, "engaged by the old VNAV above 400 ft")
T.equal(rt:get(PITCH), 4, "the FMA's VNAV SPD")
T.equal(rt:get(PITCH_ARMED), 0, "no arm")
rt:command(CMD .. "VNAV")
frames()
T.check(rt:get(VNAV_STATE) >= 2, "a push while active: nothing (the old one disengaged it)")
rt:command(CMD .. "vs_mode")
frames()
T.equal(rt:get(VNAV_STATE), 0, "V/S ends VNAV (FCOM p.645)")
T.equal(rt:get(PITCH), 7, "the FMA's V/S")
T.equal(rt:get(VS_STATUS), 2, "the old law's V/S")
-- no route: VNAV pushed in the air ends through the model at once, no
-- DESTINATION NOT SET (the old monitor's VNAV read the route's entry 0, a
-- Lua error before the cancel)
rt:set(NOTIFY, 54, 0)
rt:set("xtlua/fms", "[]")
frames()
rt:command(CMD .. "VNAV")
frames()
T.equal(rt:get(VNAV_STATE), 0, "no route: VNAV's arm ends at once")
T.equal(rt:get(PITCH_ARMED), 0, "no arm in the FMA")
T.equal(rt:get(PITCH), 7, "V/S stays")
frames()
T.equal(rt:get(VNAV_STATE), 0, "not armed again by the model")
T.equal(rt:get(NOTIFY, 54), 0, "no DESTINATION NOT SET (the old cancel posted it)")
-- 1d: the approach modes through the model. APP arms LOC and G/S (with no
-- ILS too: the old one posted RW/ILS CRS ERROR, flag 40); the captures by
-- the old detectors' conditions (both receivers' signals; G/S under 1.5
-- dots) with the track within 120 and 80 degrees of the course (the old
-- monitor no longer captures by itself); the MCP's heading to the course at
-- LOC's capture (the old APP switch set it at once); the old state written
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
    rt:set(RI .. "hsi_vdef_dots_pilot", gs and 0.4 or 2.5)
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
-- rolling right to come onto the course
frames(60)
T.check(rt:get("laminar/B747/autopilot/roll_law") == 1 and rt:get("laminar/B747/autopilot/roll_cmd") > 3,
    "LOC's law: rolling right onto the course (not X-Plane's HDG SEL)")
-- G/S captured under 1.5 dots
ils(true, true)
frames()
T.check(rt:get(GS) == 2 and rt:get(GS_ACT) == 2, "G/S captured")
T.equal(rt:get(PITCH), 2, "the FMA's G/S")
T.equal(rt:get(PITCH_ARMED), 0, "nothing armed in pitch")
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
rt:set(FD, 23, 0)
frames()
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set(RA, 9000)
T.done()
