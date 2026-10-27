-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_glue_test.lua
-- The FCCs' mode logic, step 1a (6-3: docs/overhaul/notes/ATA-22.md §10), in
-- the autopilot module (B747.70.xt.autopilot.lua with B747.70.afds_model.lua),
-- with step 1b's roll modes:
-- the CMD switches, the disengage bar and the control wheel switches through
-- the model to the CMD channels, the servos and AUTOPILOT DISC
-- (laminar/B747/CAS/warning_status[0]); the defaults on the old code's state
-- (V/S synced to the present vertical speed, HDG HOLD on X-Plane's HDG SEL,
-- ATT's bank); 1b: HDG SEL, LNAV's arm and engage, HDG HOLD (X-Plane's
-- command replaced) and its heading after 2 s;
-- the F/D switches (their positions); everything off; the MCP's IAS 200.
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
-- fpm, HDG HOLD (flown by X-Plane's HDG SEL until 6-3 step 2)
rt.command_log = {}
rt:command(CMD .. "cmd_C")
frames()
T.equal(rt:get("laminar/B747/autopilot/cmd_C_mode/status"), 1, "CMD C: the centre channel engaged")
T.equal(rt:get(SERVOS), 1, "the servos on")
T.equal(rt:get(VS_STATUS), 2, "the default V/S")
T.equal(rt:get(VS_DIAL), 1200, "V/S synced to the present vertical speed (1,234 fpm: 1,200)")
T.equal(rt:get("laminar/B747/autopilot/FMA/active_roll_mode"), 7, "the FMA's HDG HOLD")
T.check(sent("sim/autopilot/heading"), "X-Plane's HDG SEL flies it")
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

-- 1b: the roll modes through the model. HDG SEL: X-Plane's HDG SEL to the
-- MCP's heading; LNAV armed with HDG SEL active, then engaged by the FMC's
-- steering above 50 ft; HDG HOLD (X-Plane's command, replaced): the
-- present heading until the roll stays under 3 degrees for 2 s
local ROLL, ROLL_ARMED = "laminar/B747/autopilot/FMA/active_roll_mode", "laminar/B747/autopilot/FMA/armed_roll_mode"
local LNAV_STATE, HDG_TARGET = "laminar/B747/autopilot/lnav_state", "sim/cockpit/autopilot/heading_mag"
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 0)
rt:set("sim/flightmodel/position/mag_psi", 95)
rt:set("laminar/B747/autopilot/heading/degrees", 120)
rt.command_log = {}
rt:command(CMD .. "heading_select")
frames()
T.equal(rt:get(ROLL), 6, "HDG SEL: the FMA's HDG SEL")
T.near(rt:get(HDG_TARGET), 120, 0.01, "X-Plane's HDG SEL to the MCP's heading 120")
T.check(sent("sim/autopilot/heading"), "X-Plane's HDG SEL mode")
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
rt:command(CMD .. "LNAV")
frames()
T.equal(rt:get(LNAV_STATE), 2, "a push while active: still engaged")
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 12)
rt:command("sim/autopilot/heading_hold")
frames()
T.equal(rt:get(ROLL), 7, "HDG HOLD (X-Plane's command, the 3D's button): the FMA's HDG HOLD at once")
T.equal(rt:get(LNAV_STATE), 0, "LNAV off")
T.near(rt:get(HDG_TARGET), 95, 0.01, "rolling out: the present heading")
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 1)
rt:set("sim/flightmodel/position/mag_psi", 101)
frames(70)
rt:set("sim/flightmodel/position/mag_psi", 104)
frames(5)
T.near(rt:get(HDG_TARGET), 101, 0.01, "2 s under 3 degrees: the heading then held (101)")

T.done()
